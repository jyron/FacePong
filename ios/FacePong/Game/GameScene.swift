// GameScene.swift — the whole pong court rendered in SpriteKit, in court units
// (390x844, origin bottom-left, y-up). The physics engine runs in court space
// with y DOWN, so every engine position is flipped (sceneY = Court.H - y) when
// it drives a node. Faithful port of PongCourt.tsx: additive comet trail,
// 5-layer neon ball, rally heat, impact rings, confetti, screen shake, face pops.
import SpriteKit

enum GameMode { case attract, localCPU, frozen, online }

protocol GameSceneDelegate: AnyObject {
    func gameDidScore(_ slot: Slot, rally: Int, p1: Int, p2: Int)
    func gamePaddleHit(_ slot: Slot, rally: Int)
    func gameWallHit()
}

final class GameScene: SKScene {
    weak var gameDelegate: GameSceneDelegate?
    var mode: GameMode = .attract
    var demo = false   // when true, the scene self-plays CPU-vs-CPU (dev/preview)

    // Faces (cutout images) for each paddle. nil → default coin.
    var p1Face: UIImage? { didSet { paddle1.setFace(p1Face) } }
    var p2Face: UIImage? { didSet { paddle2.setFace(p2Face) } }

    // ---- simulation ----
    private var engine = PongEngine()
    var currentDifficulty = Difficulty.fair   // the active CPU opponent (localCPU only)
    private var cpuBrain = CPUBrain()
    private var inputX: CGFloat = Court.W / 2
    private var acc: Double = 0
    private var lastTime: TimeInterval = 0
    private var running = false
    private(set) var rally = 0

    // Promo capture mode (FP_PROMO=1): cranks every effect to the marketing-art
    // "storm" — long bright comet, ambient sparkle field, denser confetti, and a
    // never-miss hot rally — so a screen-recording matches appstore/enhance.py.
    // Off → the tasteful shipping look (the gameplay improvements still apply).
    let promo = ProcessInfo.processInfo.environment["FP_PROMO"] == "1"

    // ---- trail ring buffer (court space) ---- longer + brighter = a real comet
    private let trailLen = 48
    private var trail: [CGPoint] = []
    private static let TRAIL_DOTS = 96
    private static let trailR: [CGFloat] = (0..<TRAIL_DOTS).map { i in
        let f = CGFloat(i) / CGFloat(TRAIL_DOTS - 1)
        return 11.5 * pow(1 - f, 1.12) + 0.9   // a touch narrower
    }
    private static let trailO: [CGFloat] = (0..<TRAIL_DOTS).map { i in
        let f = CGFloat(i) / CGFloat(TRAIL_DOTS - 1)
        return 0.6 * pow(1 - f, 1.12) + 0.04    // a touch dimmer
    }
    private static let trailWhite: [CGFloat] = (0..<TRAIL_DOTS).map { i in
        let f = CGFloat(i) / CGFloat(TRAIL_DOTS - 1)
        return pow(max(0, 1 - f * 3.0), 1.7)
    }

    // ---- nodes ----
    private var bg = SKSpriteNode()
    private let fxLayer = SKNode()        // additive group (trail + ball)
    private var trailDots: [SKSpriteNode] = []
    private var ballWideGlow = SKSpriteNode()
    private var ballGlow = SKSpriteNode()
    private var ballCore = SKSpriteNode()
    private var ballWhite = SKSpriteNode()
    private var ballHi = SKSpriteNode()
    private let paddle1 = FacePaddleNode(slot: .p1)
    private let paddle2 = FacePaddleNode(slot: .p2)
    private var ring1 = SKShapeNode()
    private var ring2 = SKShapeNode()
    private let confettiLayer = SKNode()
    private var confetti1: [SKSpriteNode] = []
    private var confetti2: [SKSpriteNode] = []
    private var confCount: Int { promo ? 40 : 14 }   // confetti specks per smash
    private static let splashColors = [Palette.cyan, Palette.magenta, Palette.lime,
                                       Palette.amber, SKColor.white, Palette.lime,
                                       Palette.magenta, Palette.cyan]

    // ---- impact flash (additive burst at the struck paddle) ----
    private var flash1 = SKSpriteNode()
    private var flash2 = SKSpriteNode()

    // ---- ambient sparkle field (the marketing "storm"; promo only) ----
    private struct Spark { var x, y, vx, vy, size, phase, tw, rot: CGFloat; var rect: Bool }
    private let sparkLayer = SKNode()
    private var sparks: [Spark] = []
    private var sparkNodes: [SKSpriteNode] = []
    private var ambientT: Double = 0

    // ---- juice state (elapsed-time driven) ----
    private var pulseT: Double = 99      // ball squash-pulse
    private var flareT: Double = 99      // comet flare
    private var shakeAmp: CGFloat = 0
    private var shakeT: Double = 99
    private var ring1T: Double = 99, ring2T: Double = 99
    private var ring1X: CGFloat = 0, ring2X: CGFloat = 0
    private var conf1T: Double = 99, conf2T: Double = 99
    private var conf1Seed: CGFloat = 1, conf2Seed: CGFloat = 2

    // score
    private(set) var score1 = 0
    private(set) var score2 = 0

    // This scene is a SINGLE persistent instance (GameModel.scene) reused for the app's
    // whole life. SwiftUI tears down and recreates the SpriteView as the user moves
    // between the menu and a court screen, and each presentation calls didMove(to:).
    // buildCourt() must therefore run EXACTLY ONCE — re-adding nodes that already have a
    // parent makes SKNode.addChild throw an NSException (SIGABRT). This guard was the
    // crash behind the App Store rejection + TestFlight crashes.
    private var courtBuilt = false

    override func didMove(to view: SKView) {
        backgroundColor = Palette.bg
        scaleMode = .aspectFit
        anchorPoint = .zero
        size = CGSize(width: Court.W, height: Court.H)
        if !courtBuilt { buildCourt(); courtBuilt = true }
        if demo { serveAttract() } else { prepareReady() }
    }

    /// Court at rest: paddles centered, ball frozen at center (used during the
    /// pre-round countdown; the local paddle still follows the finger).
    func prepareReady() {
        mode = .frozen
        running = false
        engine.s = EngineState()
        engine.resetTuning()
        engine.s.p1x = inputX
        rally = 0
        primeTrail(at: Court.center)
    }

    // MARK: build

    private func buildCourt() {
        bg = SKSpriteNode(texture: TextureFactory.makeCourtBackground(size: CGSize(width: Court.W * 2, height: Court.H * 2)))
        bg.size = CGSize(width: Court.W, height: Court.H)
        bg.position = CGPoint(x: Court.W / 2, y: Court.H / 2)
        bg.zPosition = -10
        addChild(bg)

        // center line + circle (subtle)
        let line = SKShapeNode(rect: CGRect(x: Court.W * 0.08, y: Court.H / 2 - 1, width: Court.W * 0.84, height: 2))
        line.fillColor = SKColor.white.withAlphaComponent(0.12)
        line.strokeColor = .clear
        line.zPosition = -5
        addChild(line)
        let circle = SKShapeNode(circleOfRadius: 48)
        circle.position = CGPoint(x: Court.W / 2, y: Court.H / 2)
        circle.strokeColor = SKColor.white.withAlphaComponent(0.10)
        circle.lineWidth = 2
        circle.zPosition = -5
        addChild(circle)

        // additive fx layer (trail + ball) — additivity is per-sprite below
        fxLayer.zPosition = 5
        addChild(fxLayer)

        // trail dots (back to front so the head draws on top)
        for _ in 0..<GameScene.TRAIL_DOTS {
            let d = SKSpriteNode(texture: TextureFactory.softDot)
            d.blendMode = .add
            d.colorBlendFactor = 1
            d.isHidden = true
            fxLayer.addChild(d)
            trailDots.append(d)
        }

        // ball layers
        ballWideGlow = makeFXSprite(TextureFactory.softDot)
        ballGlow = makeFXSprite(TextureFactory.softDot)
        ballCore = makeFXSprite(TextureFactory.solidDot)
        ballWhite = makeFXSprite(TextureFactory.softDot)
        ballHi = makeFXSprite(TextureFactory.solidDot)
        [ballWideGlow, ballGlow, ballCore, ballWhite, ballHi].forEach { fxLayer.addChild($0) }

        // paddles
        paddle1.position = courtPoint(x: Court.W / 2, y: GC.botY)
        paddle2.position = courtPoint(x: Court.W / 2, y: GC.topY)
        paddle1.zPosition = 4
        paddle2.zPosition = 4
        addChild(paddle1)
        addChild(paddle2)

        // impact rings
        ring1.strokeColor = Palette.cyan; ring1.fillColor = .clear; ring1.zPosition = 3; ring1.isHidden = true
        ring2.strokeColor = Palette.magenta; ring2.fillColor = .clear; ring2.zPosition = 3; ring2.isHidden = true
        addChild(ring1); addChild(ring2)

        // ambient sparkle field (promo storm) — drifts up + twinkles behind the ball
        sparkLayer.zPosition = 2
        addChild(sparkLayer)
        let sparkN = promo ? 120 : 0
        for i in 0..<sparkN {
            let rect = Bool.random()
            sparks.append(Spark(x: CGFloat.random(in: 14...(Court.W - 14)),
                                y: CGFloat.random(in: 150...830),
                                vx: CGFloat.random(in: -6...6),
                                vy: CGFloat.random(in: -11 ... -2),
                                size: CGFloat.random(in: 6...17),
                                phase: CGFloat.random(in: 0...6.28),
                                tw: CGFloat.random(in: 1.4...3.6),
                                rot: CGFloat.random(in: 0...3.14), rect: rect))
            let node = SKSpriteNode(texture: rect ? TextureFactory.crispDot : TextureFactory.softDot)
            node.blendMode = .add; node.colorBlendFactor = 1
            node.color = GameScene.splashColors[i % GameScene.splashColors.count]
            node.isHidden = true
            sparkLayer.addChild(node); sparkNodes.append(node)
        }

        // impact flash bursts (one per paddle)
        for f in [flash1, flash2] {
            f.texture = TextureFactory.softDot; f.blendMode = .add; f.colorBlendFactor = 1
            f.isHidden = true; f.zPosition = 5; addChild(f)
        }

        // confetti
        confettiLayer.zPosition = 6
        addChild(confettiLayer)
        let pal = GameScene.splashColors.count
        for i in 0..<confCount {
            let a = SKSpriteNode(texture: TextureFactory.crispDot)
            a.colorBlendFactor = 1; a.color = GameScene.splashColors[i % pal]; a.isHidden = true
            confettiLayer.addChild(a); confetti1.append(a)
            let b = SKSpriteNode(texture: TextureFactory.crispDot)
            b.colorBlendFactor = 1; b.color = GameScene.splashColors[i % pal]; b.isHidden = true
            confettiLayer.addChild(b); confetti2.append(b)
        }
    }

    private func makeFXSprite(_ tex: SKTexture) -> SKSpriteNode {
        let s = SKSpriteNode(texture: tex)
        s.blendMode = .add
        s.colorBlendFactor = 1
        return s
    }

    // court (y-down) → scene (y-up)
    @inline(__always) private func courtPoint(x: CGFloat, y: CGFloat) -> CGPoint {
        CGPoint(x: x, y: Court.H - y)
    }

    // MARK: control

    func startLocalCPU(toward: Slot = .p2, difficulty: Difficulty = .fair) {
        mode = .localCPU
        currentDifficulty = difficulty
        cpuBrain.difficulty = difficulty
        cpuBrain.reset()
        // Apply the opponent's ball pressure to THIS engine instance only.
        engine.maxSpeed = GC.maxSpeed * difficulty.maxSpeedMul
        engine.rallyRamp = 1 + (GC.rallyRamp - 1) * difficulty.rampMul
        engine.serveVY = GC.serveVY * difficulty.serveVYMul
        engine.serveVXSpread = GC.serveVXSpread * difficulty.serveVXSpreadMul
        engine.p2CoverR = GC.paddleR * difficulty.coverage
        engine.serve(toward: toward)
        engine.s.p1x = inputX
        rally = 0
        running = true
        primeTrail(at: Court.center)
    }

    private func serveAttract() {
        mode = .attract
        engine.resetTuning()
        engine.serve(toward: Bool.random() ? .p1 : .p2)
        running = true
        primeTrail(at: Court.center)
    }

    func setInput(sceneX: CGFloat) {
        // touch already in court units (scene is in court units)
        inputX = clampPaddleX(sceneX)
    }

    // MARK: online (server-authoritative; interpolate toward server targets)

    private var netTgtBallX = Court.W / 2
    private var netTgtBallY = Court.H / 2
    private var netTgtP2x = Court.W / 2
    private var netPrevPhase = "waiting"
    private var netPrevRally = 0
    private var inWallZone = false

    var inputXValue: CGFloat { inputX }

    func startOnline() {
        mode = .online
        running = false
        engine.s = EngineState()
        engine.resetTuning()
        netPrevPhase = "waiting"; netPrevRally = 0
        inWallZone = false
        rally = 0
        primeTrail(at: Court.center)
    }

    /// Apply an authoritative state update from the room (called on the main thread).
    func applyNet(_ s: NetState, mySessionId: String) {
        let me = s.players[mySessionId]
        let flip = (me?.slot ?? "p1") == "p2"   // a p2 client flips Y to sit at the bottom
        var opp: NetPlayer?
        for (k, p) in s.players where k != mySessionId { opp = p }

        let bx = s.ballX
        let by = flip ? Court.H - s.ballY : s.ballY
        netTgtBallX = bx
        netTgtBallY = by
        netTgtP2x = opp?.x ?? Court.W / 2

        // On a phase change the server teleports the ball (e.g. to center) — snap
        // instead of lerping across the court.
        if s.phase != netPrevPhase {
            engine.s.ballX = bx; engine.s.ballY = by
            primeTrail(at: CGPoint(x: bx, y: by))
            inWallZone = true
        }
        netPrevPhase = s.phase
        rally = s.rally
        if s.rally > netPrevRally {
            onPaddleHit(by >= Court.H / 2 ? .p1 : .p2, rally: s.rally)
            engine.s.ballX = bx; engine.s.ballY = by   // snap to post-bounce position
        }
        netPrevRally = s.rally
    }

    private func onlineTick() {
        let lo = GC.paddleMargin, hi = Court.W - GC.paddleMargin
        engine.s.p1x = min(max(inputX, lo), hi)                  // my paddle, predicted
        engine.s.p2x += (netTgtP2x - engine.s.p2x) * 0.35        // opponent, interpolated
        engine.s.ballX += (netTgtBallX - engine.s.ballX) * 0.4
        engine.s.ballY += (netTgtBallY - engine.s.ballY) * 0.4
        let nearWall = engine.s.ballX < GC.ballR + GC.wallPad + 12 || engine.s.ballX > Court.W - GC.ballR - GC.wallPad - 12
        if nearWall && !inWallZone { onWallHit() }
        inWallZone = nearWall
        for i in stride(from: trailLen - 1, to: 0, by: -1) { trail[i] = trail[i - 1] }
        trail[0] = CGPoint(x: engine.s.ballX, y: engine.s.ballY)
    }

    private func primeTrail(at p: CGPoint) {
        // Safe even if called before didMove populates the buffer.
        if trail.count < trailLen { trail = Array(repeating: p, count: trailLen) }
        else { for i in 0..<trailLen { trail[i] = p } }
    }

    // MARK: loop

    override func update(_ currentTime: TimeInterval) {
        var dt = lastTime == 0 ? GC.tickMs : (currentTime - lastTime) * 1000
        lastTime = currentTime
        if dt > 100 { dt = 100 }

        if mode == .online {
            onlineTick()
        } else if running {
            acc += dt
            let lo = GC.paddleMargin, hi = Court.W - GC.paddleMargin
            while acc >= GC.tickMs {
                acc -= GC.tickMs
                // ---- bottom paddle (p1) ----
                if mode == .localCPU {
                    var np1 = engine.s.p1x + (inputX - engine.s.p1x) * GC.inputFollow
                    np1 = min(max(np1, lo), hi)
                    engine.s.p1x = np1
                } else if promo { // promo: weave-track -> angled hits -> curved comet, never miss
                    let off = sin(ambientT * 1.7) * 30      // < paddleR(44) so it always connects
                    engine.s.p1x = min(max(engine.s.ballX + off, lo), hi)
                } else { // attract: bottom paddle is also AI
                    let k1: CGFloat = engine.s.vy > 0 ? GC.easeToward : GC.easeAway
                    var np1 = engine.s.p1x + (engine.s.ballX - engine.s.p1x) * k1
                    np1 = min(max(np1, lo), hi)
                    engine.s.p1x = np1
                }
                // ---- top paddle (p2 / the CPU opponent) ----
                if promo {
                    let off = sin(ambientT * 1.9 + 2.1) * 30
                    engine.s.p2x = min(max(engine.s.ballX + off, lo), hi)
                } else if mode == .localCPU {
                    // Difficulty-driven brain: react with lag, predict the bounce, aim with
                    // a per-rally error, and ease at the tier's track gain.
                    cpuBrain.record(engine.s)
                    let target = cpuBrain.target(engine.s)
                    let k2: CGFloat = engine.s.vy < 0 ? currentDifficulty.trackGain : currentDifficulty.trackGainAway
                    engine.s.p2x = min(max(engine.s.p2x + (target - engine.s.p2x) * k2, lo), hi)
                } else { // attract: top paddle is the simple chaser
                    let k2: CGFloat = engine.s.vy < 0 ? GC.easeToward * 0.9 : GC.easeAway
                    var np2 = engine.s.p2x + (engine.s.ballX - engine.s.p2x) * k2
                    np2 = min(max(np2, lo), hi)
                    engine.s.p2x = np2
                }

                let r = engine.step()
                if let hit = r.paddleHit { onPaddleHit(hit, rally: engine.s.rally) }
                if r.wallHit { onWallHit() }
                if let sc = r.scored { onScore(sc); break }
            }
            rally = engine.s.rally
            // trail shift (newest at index 0)
            for i in stride(from: trailLen - 1, to: 0, by: -1) { trail[i] = trail[i - 1] }
            trail[0] = CGPoint(x: engine.s.ballX, y: engine.s.ballY)
        } else if mode == .frozen {
            // countdown: let the player pre-position the paddle, ball stays put.
            engine.s.p1x = clampPaddleX(inputX)
        }

        advanceJuice(dt: dt / 1000)
        updateSparks(dt: dt / 1000)
        paddle1.advance(dt: dt / 1000)
        paddle2.advance(dt: dt / 1000)
        render()
    }

    private func onPaddleHit(_ slot: Slot, rally hitRally: Int) {
        pulseT = 0
        flareT = 0
        if slot == .p1 { paddle1.pop(); ring1T = 0; ring1X = engine.s.ballX; conf1T = 0; conf1Seed = CGFloat(score1 + hitRally) + 0.13 }
        else { paddle2.pop(); ring2T = 0; ring2X = engine.s.ballX; conf2T = 0; conf2Seed = CGFloat(score2 + hitRally) + 0.61 }
        if hitRally >= 4 {
            shakeAmp = min(2 + CGFloat(hitRally) * 0.2, 5.5)
            shakeT = 0
        }
        gameDelegate?.gamePaddleHit(slot, rally: hitRally)
    }

    private func onWallHit() {
        pulseT = 0
        gameDelegate?.gameWallHit()
    }

    private func onScore(_ slot: Slot) {
        running = false
        if slot == .p1 { score1 += 1 } else { score2 += 1 }
        if mode == .attract {
            // keep the attract demo alive
            score1 = 0; score2 = 0
            run(.sequence([.wait(forDuration: 0.6), .run { [weak self] in self?.serveAttract() }]))
        } else {
            gameDelegate?.gameDidScore(slot, rally: engine.s.rally, p1: score1, p2: score2)
        }
    }

    func resetScores() { score1 = 0; score2 = 0 }
    func stop() { running = false }

    // MARK: juice timing

    private func advanceJuice(dt: Double) {
        pulseT += dt; flareT += dt; shakeT += dt
        ring1T += dt; ring2T += dt; conf1T += dt; conf2T += dt
        ambientT += dt
    }

    // damped spring closed-form for the face pop (after a 40ms punch).
    // zeta≈0.25, wn≈20rad/s from damping6/stiff240/mass0.6 → one big overshoot.
    static func springPop(_ t: Double) -> CGFloat {
        if t < 0.05 { return CGFloat(t / 0.05) }          // quick punch
        let tt = t - 0.05
        if tt > 1.0 { return 0 }
        // Springy "boing" — no flat hold; bounces through a few decaying wobbles.
        return CGFloat(exp(-3.4 * tt) * cos(13.0 * tt))
    }

    // MARK: render

    private func render() {
        let bx = engine.s.ballX, by = engine.s.ballY
        let heat = heatColor(rally: rally)
        let flareDur = 0.42
        let flareV: CGFloat = flareT < flareDur ? (1 - CGFloat(easeOutCubic01(flareT / flareDur))) : 0

        // ---- trail ----
        for i in 0..<trailLen {
            let A = (i == 0) ? CGPoint(x: bx, y: by) : trail[i - 1]
            let B = trail[i]
            for half in 0..<2 {
                let f: CGFloat = half == 0 ? 0.5 : 1.0
                let idx = i * 2 + half
                let dot = trailDots[idx]
                let cx = A.x + (B.x - A.x) * f
                let cy = A.y + (B.y - A.y) * f
                let baseR = GameScene.trailR[idx]
                let cr = baseR * (1 + flareV * 0.9)
                let co = min(0.9, GameScene.trailO[idx] * (1 + flareV * 2.6))
                dot.isHidden = false
                dot.position = courtPoint(x: cx, y: cy)
                // soft texture: size ≈ 2*r*softScale so the bright core ≈ r
                let s = cr * 2.0 * 1.14
                dot.size = CGSize(width: s, height: s)
                dot.alpha = co
                dot.color = lerpColor(heat, .white, GameScene.trailWhite[idx])
            }
        }

        // ---- ball ----
        let pulse = pulseT < 0.24 ? ballPulse(pulseT) : 0
        let ballRr = GC.ballR * (1 + pulse * 0.5)
        let glowR = (GC.ballR + 6) * (1 + pulse * 0.9)
        let wideR = GC.ballR * 2.6 * (1 + pulse * 0.6)
        let coreR = GC.ballR * 0.6 * (1 + pulse * 0.4)
        setFX(ballWideGlow, x: bx, y: by, radius: wideR, color: heat, alpha: 0.4)
        setFX(ballGlow, x: bx, y: by, radius: glowR * 1.1, color: heat, alpha: 0.9)
        setFX(ballCore, x: bx, y: by, radius: ballRr * 1.1, color: heat, alpha: 1)
        setFX(ballWhite, x: bx, y: by, radius: coreR * 1.6, color: .white, alpha: 0.95)
        setFX(ballHi, x: bx - 3, y: by - 3, radius: 2.6, color: .white, alpha: 1)

        // ---- paddles ---- (pop advanced in update via advance(dt:))
        paddle1.position = courtPoint(x: engine.s.p1x, y: GC.botY)
        paddle2.position = courtPoint(x: engine.s.p2x, y: GC.topY)

        // ---- impact rings ----
        updateRing(ring1, t: ring1T, x: ring1X, y: GC.botY - GC.paddleR, color: Palette.cyan)
        updateRing(ring2, t: ring2T, x: ring2X, y: GC.topY + GC.paddleR, color: Palette.magenta)

        // ---- confetti ----
        updateConfetti(confetti1, t: conf1T, seed: conf1Seed, x: ring1X, y: GC.botY - GC.paddleR, dir: -1)
        updateConfetti(confetti2, t: conf2T, seed: conf2Seed, x: ring2X, y: GC.topY + GC.paddleR, dir: 1)

        // ---- impact flash ----
        updateFlash(flash1, t: ring1T, x: ring1X, y: GC.botY - GC.paddleR, color: Palette.cyan)
        updateFlash(flash2, t: ring2T, x: ring2X, y: GC.topY + GC.paddleR, color: Palette.magenta)

        // ---- screen shake ----
        if shakeT < 0.28 {
            let a = shakeAmp * CGFloat(1 - shakeT / 0.28)
            let ox = sin(a * 47) * a
            let oy = cos(a * 31) * a * 0.6
            position = CGPoint(x: ox, y: oy)
        } else if position != .zero {
            position = .zero
        }
    }

    private func clampedPaddle(_ x: CGFloat) -> CGFloat { x }

    private func setFX(_ s: SKSpriteNode, x: CGFloat, y: CGFloat, radius: CGFloat, color: SKColor, alpha: CGFloat) {
        s.position = courtPoint(x: x, y: y)
        s.size = CGSize(width: radius * 2, height: radius * 2)
        s.color = color
        s.alpha = alpha
    }

    private func updateRing(_ ring: SKShapeNode, t: Double, x: CGFloat, y: CGFloat, color: SKColor) {
        if t >= 0.38 { ring.isHidden = true; return }
        let p = easeOutCubic01(t / 0.38)
        let r = 14 + CGFloat(p) * 64
        ring.isHidden = false
        ring.path = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2), transform: nil)
        ring.lineWidth = 0.5 + 3.5 * CGFloat(1 - p)
        ring.strokeColor = color
        ring.alpha = 0.85 * CGFloat(1 - p)
        ring.position = courtPoint(x: x, y: y)
    }

    private func updateConfetti(_ dots: [SKSpriteNode], t: Double, seed: CGFloat, x: CGFloat, y: CGFloat, dir: CGFloat) {
        let life = 0.92
        if t >= life { dots.forEach { $0.isHidden = true }; return }
        let tt = CGFloat(t / life)
        let e = 1 - pow(1 - tt, 3)
        for i in 0..<dots.count {
            let dot = dots[i]
            let a = dir * (.pi / 2) + (splashRnd(seed, i, 1) - 0.5) * 3.0   // wider blast
            let dist = (40 + splashRnd(seed, i, 2) * 110) * e               // farther
            let cx = x + cos(a) * dist
            let cy = y + sin(a) * dist + 38 * tt * tt   // gravity (court y-down)
            let r = (2.6 + splashRnd(seed, i, 3) * 3.0) * (1 - tt * 0.4)
            dot.isHidden = false
            dot.position = courtPoint(x: cx, y: cy)
            if i % 2 == 0 {   // paper rect
                dot.size = CGSize(width: r * 2 * 0.7, height: r * 2 * 1.9)
                dot.zRotation = a + CGFloat(t) * 6
            } else {          // round speck
                dot.size = CGSize(width: r * 2 * 1.35, height: r * 2 * 1.35)
                dot.zRotation = 0
            }
            dot.alpha = tt >= 1 ? 0 : 0.98 * (1 - tt * 0.85)
        }
    }

    // Additive burst at the struck paddle (drives off the impact-ring timer).
    private func updateFlash(_ s: SKSpriteNode, t: Double, x: CGFloat, y: CGFloat, color: SKColor) {
        let dur = 0.22
        if t >= dur { s.isHidden = true; return }
        let p = CGFloat(1 - t / dur)                 // 1 at impact → 0
        let r = CGFloat(150) * (0.55 + (1 - p) * 0.7)  // flares outward
        s.isHidden = false
        s.size = CGSize(width: r, height: r)
        s.position = courtPoint(x: x, y: y)
        s.color = lerpColor(color, .white, 0.6)
        s.alpha = p * (promo ? 0.9 : 0.55)
    }

    // Ambient sparkle field: slow upward drift + twinkle (promo capture only).
    private func updateSparks(dt: Double) {
        guard !sparkNodes.isEmpty else { return }
        let d = CGFloat(dt)
        for i in 0..<sparks.count {
            sparks[i].x += sparks[i].vx * d
            sparks[i].y += sparks[i].vy * d
            if sparks[i].x < 8 { sparks[i].x = Court.W - 8 } else if sparks[i].x > Court.W - 8 { sparks[i].x = 8 }
            if sparks[i].y < 140 { sparks[i].y = 836 }       // drifts up, wraps to bottom
            let s = sparks[i]
            let tw = 0.32 + 0.68 * abs(sin(ambientT * Double(s.tw) + Double(s.phase)))
            let node = sparkNodes[i]
            node.isHidden = false
            node.position = courtPoint(x: s.x, y: s.y)
            if s.rect {
                node.size = CGSize(width: s.size * 0.6, height: s.size * 1.85)
                node.zRotation = s.rot + CGFloat(ambientT) * 0.6
                node.alpha = CGFloat(tw) * 0.92
            } else {
                node.size = CGSize(width: s.size * 1.9, height: s.size * 1.9)
                node.alpha = CGFloat(tw) * 0.62
            }
        }
    }

    // MARK: touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { handleTouch(touches) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { handleTouch(touches) }
    private func handleTouch(_ touches: Set<UITouch>) {
        guard mode != .attract, let t = touches.first else { return }
        let p = t.location(in: self)
        setInput(sceneX: p.x)
    }
}

// MARK: helpers

@inline(__always) func easeOutCubic01(_ t: Double) -> Double {
    let x = max(0, min(1, t))
    return 1 - pow(1 - x, 3)
}

// ball squash-pulse: punch to 1 in 40ms, ease to 0 over 200ms.
@inline(__always) func ballPulse(_ t: Double) -> CGFloat {
    if t < 0.04 { return CGFloat(t / 0.04) }
    let tt = (t - 0.04) / 0.20
    return CGFloat(max(0, 1 - tt))
}

// deterministic per-particle pseudo-random in [0,1), matching PongCourt.splashRnd.
@inline(__always) func splashRnd(_ seed: CGFloat, _ i: Int, _ k: CGFloat) -> CGFloat {
    let v = sin(seed * 12.9898 + CGFloat(i) * 78.233 + k * 37.719) * 43758.5453
    return v - floor(v)
}

// MARK: CPU brain

/// Drives the CPU (top) paddle's TARGET x from a Difficulty. Three things make it feel
/// human instead of a perfect wall: it reacts to where the ball was `reactionTicks` ago
/// (a ring buffer), it can predict the wall-mirrored intercept instead of just chasing
/// the live ball, and it mis-aims by a fixed offset re-rolled once per rally. The caller
/// eases the paddle toward this target at the tier's trackGain, and the engine's p2CoverR
/// decides whether a near-miss actually connects.
struct CPUBrain {
    var difficulty = Difficulty.fair
    private var hist: [EngineState] = []
    private let cap = 40
    private var lastRally = -999
    private var rallyError: CGFloat = 0

    mutating func reset() { hist.removeAll(keepingCapacity: true); lastRally = -999; rallyError = 0 }

    /// Push the current ball state and (re-)seed the aim error once per rally.
    mutating func record(_ s: EngineState) {
        if s.rally != lastRally {
            lastRally = s.rally
            let e = difficulty.aimErrorUnits
            rallyError = e <= 0 ? 0 : CGFloat.random(in: -e...e)
        }
        hist.append(s)
        if hist.count > cap { hist.removeFirst(hist.count - cap) }
    }

    /// The clamped x the paddle should move toward this tick.
    func target(_ now: EngineState) -> CGFloat {
        let s = delayed(now)
        var t = s.ballX
        if difficulty.predict > 0 && s.vy < 0 {
            t = s.ballX * (1 - difficulty.predict) + CPUBrain.interceptX(s) * difficulty.predict
        }
        return clampPaddleX(t + rallyError)
    }

    /// The ball state `reactionTicks` ago (or the oldest we have early in a rally).
    private func delayed(_ now: EngineState) -> EngineState {
        let d = difficulty.reactionTicks
        if d <= 0 || hist.isEmpty { return now }
        let i = hist.count - 1 - d
        return i >= 0 ? hist[i] : (hist.first ?? now)
    }

    /// Where the ball will cross the CPU's contact plane, mirroring off the side walls —
    /// the same wall geometry the engine uses, so the prediction is exact.
    static func interceptX(_ s: EngineState) -> CGFloat {
        let targetY = GC.topY + GC.paddleR
        guard s.vy < 0, s.ballY > targetY else { return s.ballX }
        let dt = (s.ballY - targetY) / (-s.vy)
        let x = s.ballX + s.vx * dt
        let lo = GC.ballR + GC.wallPad
        let hi = Court.W - GC.ballR - GC.wallPad
        let span = hi - lo
        guard span > 0 else { return clampPaddleX(x) }
        var t = (x - lo).truncatingRemainder(dividingBy: 2 * span)
        if t < 0 { t += 2 * span }
        if t > span { t = 2 * span - t }
        return lo + t
    }
}
