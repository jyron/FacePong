// SoundManager.swift — audio + haptics for FacePong. Matches sfx.ts behaviour
// exactly: pitch-ramping paddle blips, randomised wall bounce, success/error
// notification haptics on score events, and selection haptic on countdown ticks.
//
// Architecture:
//   AVAudioEngine with one AVAudioPlayerNode + AVAudioUnitVarispeed pair per
//   logical sound. The paddle channel uses two such pairs round-robined so
//   rapid p1/p2 exchanges never cut each other off (mirrors the two-player
//   array in sfx.ts). All nodes are wired to the engine's mainMixerNode so
//   the whole graph shares one output tap.
//
//   Every public call is fire-and-forget and silently no-ops if the engine
//   or a buffer is missing — gameplay continues muted rather than crashing.

import AVFoundation
import UIKit

// MARK: - Internal channel

private final class SoundChannel {
    let player = AVAudioPlayerNode()
    let varispeed = AVAudioUnitVarispeed()
    var buffer: AVAudioPCMBuffer?
}

// MARK: - SoundManager

enum Sound {

    // MARK: public API

    /// Configure the AVAudioSession and preload all buffers. Call once at app
    /// start (e.g. in FacePongApp.init or scene(_:willConnectTo:)).
    static func prepare() {
        configureSession()
        buildEngine()
        prepareHaptics()
        installObservers()
        activateAndStart()   // best-effort now; re-tried on first sound + on becoming active
        #if DEBUG
        let s = AVAudioSession.sharedInstance()
        print("FPAUDIO ready engineRunning=\(engine.isRunning) shep=\(shepFrames.count) " +
              "voices=\(paddleChannels.count) mixWithOthers=\(s.categoryOptions.contains(.mixWithOthers)) muted=\(isMuted)")
        #endif
    }

    /// Paddle hit. The rally climbs an *endless* pentatonic SHEPARD scale: one precomputed
    /// frame is played per hit, so the pitch rises a note every contact, but each frame is
    /// stacked across octaves with a fixed spectral envelope — the spectrum one octave up is
    /// identical, so the octave wrap is inaudible and a long rally never hits a ceiling or
    /// audibly resets. Pitch is baked into the frame (play at rate 1.0); a tiny level jitter
    /// + per-frame timbre keep repeats fresh; `pan` (-1…+1) places the hit at the ball's x.
    static func paddle(_ slot: Slot, rally: Int, pan: Float = 0) {
        let frame = max(0, rally - 1) % shepFrames.count   // climb one Shepard step per hit
        // Trim level: the vibe frames ring ~1.25s and overlap heavily in a fast rally, so keep
        // headroom on the mixer (many simultaneous voices) to avoid output clipping.
        let vol = 0.62 * (1 + Float.random(in: -0.08...0.08))
        play(channel: nextPaddleChannel(), override: shepFrames[frame], rate: 1.0, volume: vol, pan: pan)
        switch slot {
        case .p1: impactMedium.impactOccurred()
        case .p2: impactLight.impactOccurred()
        }
    }

    /// Wall bounce. A soft, duller "tok" (no rally pitch — a calm fixed reference under the
    /// climbing rally); slight pitch randomisation + pan to the ball's x.
    static func wall(pan: Float = 0) {
        let rate = Float.random(in: 0.9 ..< 1.15)
        play(channel: wallChannel, rate: rate, volume: 0.7, pan: pan)
    }

    /// Local player scored a point.
    static func score() {
        play(channel: scoreChannel, rate: 1.0, volume: 1.0)
        notificationSuccess.notificationOccurred(.success)
    }

    /// Local player lost a point.
    static func lose() {
        play(channel: loseChannel, rate: 1.0, volume: 1.0)
        notificationError.notificationOccurred(.error)
    }

    /// Milestone reached (e.g. match point).
    static func milestone() {
        play(channel: milestoneChannel, rate: 1.0, volume: 1.0)
        impactHeavy.impactOccurred()
    }

    /// Countdown tick. `go` plays the blip a fifth up (rate 1.5).
    static func tick(go: Bool) {
        play(channel: tickChannel, rate: go ? 1.5 : 1.0, volume: 1.0)
        selectionFeedback.selectionChanged()
    }

    /// Win fanfare at match end.
    static func fanfare() {
        play(channel: fanfareChannel, rate: 1.0, volume: 1.0)
        notificationSuccess.notificationOccurred(.success)
    }

    // MARK: - engine

    private static let engine = AVAudioEngine()

    /// Two paddle channels round-robined — mirrors the JS paddle array so a p1
    /// blip and a p2 return never cancel each other during fast rallies.
    private static var paddleChannels: [SoundChannel] = []
    private static var paddleIdx = 0
    /// 5 humanised "pock" variants, round-robined no-immediate-repeat to kill ear fatigue.
    private static var paddleVariants: [AVAudioPCMBuffer] = []
    private static var lastVariant = -1
    /// 2-octave vibraphone Shepard rally cycle (shep_0…9): one frame per hit, octave-seamless
    /// so the rally pitch climbs endlessly. Falls back to the plain pock variants if unavailable.
    private static var shepFrames: [AVAudioPCMBuffer] = []

    private static var wallChannel     = SoundChannel()
    private static var scoreChannel    = SoundChannel()
    private static var loseChannel     = SoundChannel()
    private static var milestoneChannel = SoundChannel()
    private static var tickChannel     = SoundChannel()
    private static var fanfareChannel  = SoundChannel()

    private static var engineReady = false

    // MARK: - haptic generators (pre-warmed for low latency)

    private static let impactLight   = UIImpactFeedbackGenerator(style: .light)
    private static let impactMedium  = UIImpactFeedbackGenerator(style: .medium)
    private static let impactHeavy   = UIImpactFeedbackGenerator(style: .heavy)
    private static let notificationSuccess = UINotificationFeedbackGenerator()
    private static let notificationError   = UINotificationFeedbackGenerator()
    private static let selectionFeedback   = UISelectionFeedbackGenerator()

    // MARK: - session

    /// Player's in-app mute (persisted). Mutes ONLY this game's audio; other apps' audio is
    /// never affected — the session mixes with others rather than interrupting them.
    static var isMuted: Bool {
        get { UserDefaults.standard.bool(forKey: "facepong.muted") }
        set { UserDefaults.standard.set(newValue, forKey: "facepong.muted") }
    }

    private static func configureSession() {
        // .playback so audio plays through the iOS ring/silent switch; .mixWithOthers so opening
        // the game does NOT silence music/podcasts already playing — the game's sounds layer on
        // top (and the player can mute the game independently via isMuted). Activation + engine
        // start are done in activateAndStart() rather than here, so a launch-time activation
        // that fails (app not yet foreground) — or a session later stolen by another component
        // — self-heals on the next sound / on becoming active instead of going permanently silent.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
    }

    private static var observersInstalled = false

    private static func installObservers() {
        guard !observersInstalled else { return }
        observersInstalled = true
        let nc = NotificationCenter.default
        // Becoming active covers the common case: the launch-time activation ran before the
        // app was foreground (throws on device) — re-activate once we're actually active.
        nc.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in activateAndStart() }
        nc.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { _ in activateAndStart() }
        nc.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { _ in activateAndStart() }
        nc.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { note in
            if let v = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
               AVAudioSession.InterruptionType(rawValue: v) == .ended { activateAndStart() }
        }
    }

    /// (Re)assert the playback category, activate the session, and (re)start the engine. Safe
    /// to call repeatedly — only does work when something isn't already in the desired state,
    /// so it's cheap on the audio hot path yet self-heals after interruptions, route changes,
    /// or a launch-time activation that failed because the app wasn't foreground yet.
    @discardableResult
    private static func activateAndStart() -> Bool {
        let session = AVAudioSession.sharedInstance()
        if session.category != .playback || !session.categoryOptions.contains(.mixWithOthers) {
            try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        }
        do { try session.setActive(true) } catch {
            #if DEBUG
            print("FPAUDIO setActive FAILED: \(error)")
            #endif
        }
        if !engine.isRunning {
            do { try engine.start() } catch {
                #if DEBUG
                print("FPAUDIO engine.start FAILED: \(error)")
                #endif
            }
        }
        engineReady = engine.isRunning
        return engineReady
    }

    // MARK: - engine setup

    private static func buildEngine() {
        // 8 paddle voices round-robined so the long-ringing vibe rally frames overlap
        // (a fast rally piles up many tails) instead of cutting each other off.
        paddleChannels = (0..<8).map { _ in SoundChannel() }

        let allChannels: [SoundChannel] = paddleChannels + [
            wallChannel, scoreChannel, loseChannel,
            milestoneChannel, tickChannel, fanfareChannel,
        ]

        let fileNames: [String] = Array(repeating: "paddle", count: paddleChannels.count) + [
            "wall", "score", "lose",
            "milestone", "tick", "fanfare",
        ]

        let mixer = engine.mainMixerNode

        for (idx, channel) in allChannels.enumerated() {
            // Load buffer first so we can connect with its native format.
            let name = fileNames[idx]
            channel.buffer = loadBuffer(named: name)

            // Attach nodes.
            engine.attach(channel.player)
            engine.attach(channel.varispeed)

            // Chain: player → varispeed → mixer, with the buffer's format on BOTH legs.
            // Passing nil on the varispeed→mixer leg makes the engine infer an output format
            // the output chain rejects (AUGraph error -10868 kAudioUnitErr_FormatNotSupported),
            // so engine.start() throws and the whole app goes silent. Using the explicit
            // (mono 44.1 kHz) buffer format on both legs starts the engine cleanly.
            let bufFormat = channel.buffer?.format
            engine.connect(channel.player,    to: channel.varispeed, format: bufFormat)
            engine.connect(channel.varispeed, to: mixer,             format: bufFormat)
        }

        // 5 humanised paddle "pock" variants (all share the paddle format), round-robined
        // per hit; fall back to the single paddle buffer if any are missing.
        paddleVariants = (0..<5).compactMap { loadBuffer(named: "paddle_\($0)") }
        if paddleVariants.isEmpty, let one = loadBuffer(named: "paddle") { paddleVariants = [one] }

        // 2-octave vibraphone Shepard rally frames (10); fall back to the plain pocks if missing.
        shepFrames = (0..<10).compactMap { loadBuffer(named: "shep_\($0)") }
        if shepFrames.isEmpty { shepFrames = paddleVariants }
        // The engine is started by activateAndStart() (called from prepare and re-tried on the
        // first sound / on becoming active), not here — so a launch-time start that fails recovers.
    }

    /// Load a wav from the app bundle into a PCM buffer.
    private static func loadBuffer(named name: String) -> AVAudioPCMBuffer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return nil }
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0,
              let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                        frameCapacity: frameCount) else { return nil }
        do {
            try file.read(into: buf)
        } catch {
            return nil
        }
        return buf
    }

    // MARK: - playback

    private static func nextPaddleChannel() -> SoundChannel {
        let ch = paddleChannels[paddleIdx]
        paddleIdx = (paddleIdx + 1) % paddleChannels.count
        return ch
    }

    /// A random paddle "pock" variant that is never the same as the immediately previous one.
    private static func nextPaddleVariant() -> AVAudioPCMBuffer? {
        guard !paddleVariants.isEmpty else { return nil }
        var i = Int.random(in: 0..<paddleVariants.count)
        if paddleVariants.count > 1 { while i == lastVariant { i = Int.random(in: 0..<paddleVariants.count) } }
        lastVariant = i
        return paddleVariants[i]
    }

    private static func play(channel: SoundChannel, override buf: AVAudioPCMBuffer? = nil,
                             rate: Float, volume: Float, pan: Float = 0) {
        guard !isMuted else { return }                // player muted the game (audio only; haptics still fire)
        if !engine.isRunning { activateAndStart() }   // self-heal: a dead session/engine revives here
        guard engine.isRunning, let buffer = buf ?? channel.buffer else { return }

        // Varispeed rate: 1.0 = normal, 2.0 = double speed / octave up.
        channel.varispeed.rate = rate
        channel.player.volume = volume
        channel.player.pan = max(-1, min(1, pan))   // intimate stereo: hit sits at the ball's x

        // Schedule buffer for immediate one-shot playback.
        // Using scheduleBuffer without a completion handler keeps this fire-and-
        // forget; interrupting a still-playing node is intentional for short SFX
        // (except paddle where two nodes prevent that).
        channel.player.stop()
        channel.player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        channel.player.play()
    }

    // MARK: - haptics warmup

    private static func prepareHaptics() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notificationSuccess.prepare()
        notificationError.prepare()
        selectionFeedback.prepare()
    }
}
