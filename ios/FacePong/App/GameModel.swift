// GameModel.swift — the app state machine + bridge between the SwiftUI screens
// and the SpriteKit scene. Owns one persistent GameScene, routes between screens,
// tracks score/rally stats, drives sound, and persists faces + best rally.
import SwiftUI
import SpriteKit
import Combine

enum Route { case start, characters, friend, round, play, point, match, share, online }

@MainActor
final class GameModel: ObservableObject, GameSceneDelegate {
    @Published var route: Route = .start
    @Published var p1Face: UIImage?     // local player (cyan, bottom)
    @Published var p2Face: UIImage?     // opponent / CPU (magenta, top)
    @Published var score1 = 0
    @Published var score2 = 0
    @Published var roundNum = 1
    @Published var lastScorer: Slot?
    @Published var longestRally = 0     // persisted "best"
    @Published var topRally = 0         // this match
    @Published var aces = 0             // this match
    @Published var liveRally = 0
    @Published var processingFace = false
    @Published var pickError: String?

    // online
    @Published var online = false
    @Published var netStatus = "connecting"   // connecting | waiting | live | error
    @Published var netPhase = "waiting"
    @Published var netError = ""
    @Published var oppName = ""
    @Published var oppFace: UIImage?
    @Published var hostCode = ""
    @Published var isHost = false
    @Published var serverCountdown = 0
    @Published var scorerIsMe = false
    @Published var showOnlineShare = false

    let scene = GameScene()
    var cpuDifficulty: Difficulty = .fair   // active VS COMPUTER opponent strength
    @Published var selectedCharacter: Rival?   // the chosen famous-face rival (VS COMPUTER)

    // Monetization + progression
    let store = Store()                       // StoreKit 2 (unlocks + heart refill)
    let hearts = HeartBank()                  // global hearts energy
    @Published var beatenRivalIDs: Set<String> = []   // rivals you've defeated (persisted)
    @Published var justConqueredRival = false         // this match was a brand-new conquest
    @Published var paywall: PaywallKind?              // active paywall sheet, if any
    private var bag = Set<AnyCancellable>()

    private var pendingServe: Slot = .p2
    private var matchStart = Date()

    private var client: ColyseusClient?
    private var room: ColyseusRoom?
    private var inputTimer: Timer?
    private var sentFace = false
    private var oppFaceData = ""
    private var lastNetPhase = "waiting"
    private var lastCountdown = -1
    private let myName = "Player"

    init() {
        scene.gameDelegate = self
        scene.scaleMode = .aspectFit
        scene.size = CGSize(width: Court.W, height: Court.H)
        loadPersisted()
        // A heart refill purchase fills the pool; an all-access purchase grants unlimited
        // hearts. Keep the heart bank's `unlimited` flag mirrored to the entitlement.
        store.onHeartsRefill = { [weak self] in self?.hearts.refillFull() }
        hearts.unlimited = store.hasAllAccess
        store.onEntitlementsChanged = { [weak self] in
            guard let self else { return }
            self.hearts.unlimited = self.store.hasAllAccess
            self.objectWillChange.send()
        }
        store.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &bag)
        hearts.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &bag)
        // Defer audio engine + buffer loading off the synchronous launch path (8 WAV
        // loads + AVAudioEngine.start) so nothing heavy runs before the first frame.
        DispatchQueue.main.async { Sound.prepare() }
        #if DEBUG
        #if targetEnvironment(simulator)
        // The Simulator can't run Vision, so preload a bundled cutout as the player's
        // face to exercise the screens visually. On device we start clean to test the
        // real camera flow. The opponent face comes from the chosen Character.
        if p1Face == nil, let url = Bundle.main.url(forResource: "char_player", withExtension: "png") {
            p1Face = UIImage(contentsOfFile: url.path)
        }
        if selectedCharacter == nil { selectedCharacter = .default; p2Face = Rival.default.face }
        syncFaces()
        #endif
        // QA: FP_NOFACES=1 clears both faces to verify the default robot coin.
        if ProcessInfo.processInfo.environment["FP_NOFACES"] == "1" { p1Face = nil; p2Face = nil; syncFaces() }
        // QA: store/hearts hooks for verifying the paywalls in the simulator.
        if ProcessInfo.processInfo.environment["FP_RESET_IAP"] == "1" {
            Store.debugResetUnlocks(); beatenRivalIDs = []; persistBeaten()
            Task { await store.refreshEntitlements() }
        }
        if let h = ProcessInfo.processInfo.environment["FP_HEARTS"], let n = Int(h) { hearts.debugSet(n) }
        if let b = ProcessInfo.processInfo.environment["FP_BEATEN"] {
            beatenRivalIDs = Set(b.split(separator: ",").map(String.init)); persistBeaten()
        }
        // QA: FP_RIVAL=<id> forces a specific rival for the round/play/auto paths.
        if let rid = ProcessInfo.processInfo.environment["FP_RIVAL"],
           let r = Rival.roster.first(where: { $0.id == rid }) {
            selectedCharacter = r; cpuDifficulty = r.difficulty; p2Face = r.face; syncFaces()
        }
        // Jump to a given screen for visual QA: launch with FP_ROUTE=match|point|…
        if let r = ProcessInfo.processInfo.environment["FP_ROUTE"] {
            score1 = 5; score2 = 3; roundNum = 3; topRally = 85; aces = 2; lastScorer = .p1; liveRally = 12
            switch r {
            case "match": route = .match; justConqueredRival = true   // show the CONQUERED stamp
            case "matchlose": score1 = 3; score2 = 5; route = .match
            case "point": score1 = 3; route = .point
            case "share": route = .share
            case "friend": route = .friend
            case "characters": route = .characters
            case "round": route = .round
            case "play": scene.demo = true; route = .play; score1 = 0; score2 = 0; topRally = 0; liveRally = 0
            case "auto": score1 = 0; score2 = 0; topRally = 0; aces = 0
                DispatchQueue.main.async { [weak self] in self?.startCPU() }
            default: break
            }
        }
        if let o = ProcessInfo.processInfo.environment["FP_ONLINE"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                switch o { case "quick": self?.quickMatch(); case "host": self?.hostFriend(); default: break }
            }
        }
        // On-device Vision self-test: run the REAL in-app cutout on a bundled raw
        // photo (Vision runs on device, not simulator) and show it as the paddle.
        if ProcessInfo.processInfo.environment["FP_VISION_TEST"] == "1",
           let p = Bundle.main.path(forResource: "rawface", ofType: "jpg"),
           let raw = UIImage(contentsOfFile: p) {
            Task { [weak self] in
                do {
                    let cut = try await FaceCutout.cutout(from: raw)
                    NSLog("FP_VISION_TEST: cutout OK size=\(cut.size)")
                    await MainActor.run { self?.setFace(.p1, cut); self?.setFace(.p2, cut) }
                } catch {
                    NSLog("FP_VISION_TEST: FAILED \(error)")
                }
            }
        }
        #endif
    }

    // The opponent (online = the networked rival; offline = the CPU pick).
    var opponentFace: UIImage? { online ? oppFace : p2Face }
    var opponentName: String {
        if online { return oppName.isEmpty ? "RIVAL" : oppName }
        return selectedCharacter?.name ?? cpuDifficulty.name
    }

    var elapsed: TimeInterval { Date().timeIntervalSince(matchStart) }
    var elapsedString: String {
        let s = Int(elapsed); return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func syncFaces() { scene.p1Face = p1Face; scene.p2Face = p2Face }

    // MARK: faces

    // The user only ever sets THEIR OWN face (p1). The opponent face (p2) is the chosen
    // CPU character or the networked rival — never user-uploaded — so only p1 persists.
    func setFace(_ slot: Slot, _ img: UIImage?) {
        if slot == .p1 { p1Face = img } else { p2Face = img }
        if slot == .p1, let img, let d = img.pngData() {
            UserDefaults.standard.set(d, forKey: "facepong.p1")
        }
        syncFaces()
    }

    private func loadPersisted() {
        longestRally = UserDefaults.standard.integer(forKey: "facepong.best")
        if let d = UserDefaults.standard.data(forKey: "facepong.p1"), let i = UIImage(data: d) { p1Face = i }
        beatenRivalIDs = Set(UserDefaults.standard.stringArray(forKey: "facepong.beaten") ?? [])
    }
    private func persistBest() { UserDefaults.standard.set(longestRally, forKey: "facepong.best") }
    private func persistBeaten() { UserDefaults.standard.set(Array(beatenRivalIDs), forKey: "facepong.beaten") }

    var rivalsBeatenCount: Int { beatenRivalIDs.count }
    func hasBeaten(_ rival: Rival) -> Bool { beatenRivalIDs.contains(rival.id) }

    // MARK: monetization gates

    /// The single entry point for "I want to play this rival" — applies the unlock and
    /// hearts gates, raising a paywall instead of starting the match when blocked.
    /// Records the target first so a refill/unlock purchase resumes into the RIGHT rival.
    func play(_ rival: Rival) {
        selectedCharacter = rival
        if !store.isUnlocked(rival) { paywall = .unlock(rival); return }
        if rival.premium && !hearts.hasHeart { paywall = .refill; return }
        startCPU(rival)
    }

    /// "TRY AGAIN" from the defeat screen — re-runs the gates for the same rival.
    func retry() {
        guard let r = selectedCharacter else { return }
        play(r)
    }

    /// Called by a paywall after a successful purchase to continue into the match.
    /// Starts directly (the player just paid — don't re-gate them).
    func proceedAfterPurchase() {
        let kind = paywall
        paywall = nil
        switch kind {
        case .unlock(let r): startCPU(r)
        case .refill: if let r = selectedCharacter { startCPU(r) }
        case .none: break
        }
    }

    // MARK: flow

    /// Start (or restart) a VS COMPUTER match against a famous-face rival. Passing nil
    /// reuses the current pick (rematch) or falls back to the default rival.
    func startCPU(_ character: Rival? = nil) {
        let rival = character ?? selectedCharacter ?? .default
        selectedCharacter = rival
        cpuDifficulty = rival.difficulty
        online = false
        justConqueredRival = false
        p2Face = rival.face          // opponent paddle = the rival's cutout (in-memory, not persisted)
        scene.resetScores()
        score1 = 0; score2 = 0; roundNum = 1; topRally = 0; aces = 0
        matchStart = Date()
        syncFaces()
        beginRound(serveTo: .p2)
    }

    func beginRound(serveTo: Slot) {
        pendingServe = serveTo
        scene.prepareReady()
        liveRally = 0
        route = .round
    }

    /// Called by RoundView when the 3-2-1 countdown finishes.
    func beginPlay() {
        scene.startLocalCPU(toward: pendingServe, difficulty: cpuDifficulty)
        route = .play
    }

    func nextPoint() {
        roundNum += 1
        let serveTo: Slot = lastScorer == .p1 ? .p2 : .p1   // loser serves next
        beginRound(serveTo: serveTo)
    }

    func rematch() { startCPU() }

    func toMenu() {
        scene.stop()
        scene.prepareReady()
        route = .start
    }

    // MARK: GameSceneDelegate (invoked on the main thread from scene.update)

    func gameDidScore(_ slot: Slot, rally: Int, p1: Int, p2: Int) {
        lastScorer = slot
        score1 = p1; score2 = p2
        topRally = max(topRally, rally)
        if slot == .p1 && rally == 0 { aces += 1 }
        scene.stop()
        if p1 >= GC.targetScore || p2 >= GC.targetScore {
            let youWon = p1 >= GC.targetScore
            if !online, let rival = selectedCharacter {
                if youWon {
                    justConqueredRival = !beatenRivalIDs.contains(rival.id)
                    if justConqueredRival { beatenRivalIDs.insert(rival.id); persistBeaten() }
                } else if rival.premium {
                    hearts.spendOnLoss()   // losing to a premium rival burns a heart
                }
            }
            youWon ? Sound.fanfare() : Sound.lose()
            route = .match
        } else {
            slot == .p1 ? Sound.score() : Sound.lose()
            route = .point
        }
    }

    func gamePaddleHit(_ slot: Slot, rally: Int) {
        Sound.paddle(slot, rally: rally)
        if rally > 0 && rally % 5 == 0 { Sound.milestone() }
        liveRally = rally
        topRally = max(topRally, rally)
        if rally > longestRally { longestRally = rally; persistBest() }
    }

    func gameWallHit() { Sound.wall() }

    // MARK: online

    func quickMatch() {
        isHost = false
        beginOnline { c in try await c.joinOrCreate("pong", options: ["code": "", "mode": "quick", "name": self.myName]) }
    }
    func hostFriend() {
        let code = randomCode(); hostCode = code; isHost = true
        beginOnline { c in try await c.create("pong", options: ["code": code, "mode": "friend", "name": self.myName]) }
    }
    func joinFriend(_ code: String) {
        isHost = false
        beginOnline { c in try await c.join("pong", options: ["code": code.uppercased(), "mode": "friend", "name": self.myName]) }
    }

    private func beginOnline(_ make: @escaping (ColyseusClient) async throws -> ColyseusRoom) {
        online = true; netStatus = "connecting"; netError = ""; netPhase = "waiting"
        sentFace = false; oppFaceData = ""; oppFace = nil; lastNetPhase = "waiting"; lastCountdown = -1
        score1 = 0; score2 = 0; topRally = 0; liveRally = 0; aces = 0
        matchStart = Date()
        scene.startOnline(); scene.p1Face = p1Face; scene.p2Face = nil
        route = .online
        let c = ColyseusClient(endpoint: NetConfig.serverURL); client = c
        Task { @MainActor in
            do {
                let r = try await make(c)
                room = r
                r.onState = { [weak self] s in DispatchQueue.main.async { self?.applyNet(s) } }
                r.onError = { [weak self] e in DispatchQueue.main.async { if self?.netStatus != "error" { self?.netStatus = "error"; self?.netError = e } } }
                r.onLeave = { [weak self] in DispatchQueue.main.async { if self?.netStatus != "error" { self?.netStatus = "error"; self?.netError = "Disconnected" } } }
                r.connect()
                startInputLoop()
            } catch {
                netStatus = "error"; netError = "Could not connect"
            }
        }
    }

    private func startInputLoop() {
        inputTimer?.invalidate()
        inputTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self, let room = self.room else { return }
            room.sendInput(self.scene.inputXValue)
        }
    }

    private func applyNet(_ s: NetState) {
        guard let room else { return }
        let me = s.players[room.sessionId]
        let mySlot = me?.slot ?? "p1"
        var opp: NetPlayer?
        for (k, p) in s.players where k != room.sessionId { opp = p }

        netPhase = s.phase
        netStatus = s.players.count < 2 ? "waiting" : "live"
        if !s.code.isEmpty { hostCode = s.code }
        oppName = opp?.name ?? ""
        serverCountdown = s.countdown
        liveRally = s.rally
        topRally = s.topRally
        score1 = me?.score ?? 0
        score2 = opp?.score ?? 0
        scorerIsMe = !s.scorerSlot.isEmpty && s.scorerSlot == mySlot

        if let opp, !opp.faceData.isEmpty, opp.faceData != oppFaceData {
            oppFaceData = opp.faceData
            if let img = Self.decodeDataURI(opp.faceData) { oppFace = img; scene.p2Face = img }
        }
        if !sentFace, let dataURI = Self.encodeDataURI(p1Face) { room.sendFace(dataURI); sentFace = true }

        if s.phase == "countdown" && s.countdown != lastCountdown && s.countdown > 0 {
            Sound.tick(go: s.countdown == 1); lastCountdown = s.countdown
        }
        if s.phase != lastNetPhase {
            if s.phase == "point" && !s.scorerSlot.isEmpty { scorerIsMe ? Sound.score() : Sound.lose() }
            if s.phase == "match" { (score1 > score2) ? Sound.fanfare() : Sound.lose() }
            lastNetPhase = s.phase
        }

        scene.applyNet(s, mySessionId: room.sessionId)
    }

    func leaveOnline() {
        inputTimer?.invalidate(); inputTimer = nil
        room?.leave(); room = nil; client = nil
        online = false; showOnlineShare = false
        scene.stop(); scene.prepareReady()
        scene.p2Face = p2Face
        route = .start
    }

    static func encodeDataURI(_ img: UIImage?) -> String? {
        // Downscale to keep the cutout well under the server's 1.5MB cap before
        // base64 (a transparent PNG balloons otherwise).
        guard let img else { return nil }
        let maxDim: CGFloat = 384
        let scale = min(1, maxDim / max(img.size.width, img.size.height))
        let target = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.scale = 1 // render at 1x — otherwise the device's 3x scale triples the pixels (and the bytes)
        let small = UIGraphicsImageRenderer(size: target, format: fmt).image { _ in img.draw(in: CGRect(origin: .zero, size: target)) }
        guard let d = small.pngData() else { return nil }
        return "data:image/png;base64," + d.base64EncodedString()
    }
    static func decodeDataURI(_ uri: String) -> UIImage? {
        guard let comma = uri.firstIndex(of: ","),
              let d = Data(base64Encoded: String(uri[uri.index(after: comma)...])) else { return nil }
        return UIImage(data: d)
    }
    private func randomCode() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<4).map { _ in chars.randomElement()! })
    }
}
