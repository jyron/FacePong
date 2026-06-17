// GameConstants.swift — SINGLE SOURCE OF TRUTH for game geometry + physics.
// Ported verbatim from the original shared/constants.ts so the native game,
// the (future) netcode, and the Colyseus server all agree on the simulation.
// Court space is a fixed logical 390 x 844 grid, ORIGIN TOP-LEFT, +y DOWN —
// identical to the TS engine. The SpriteKit scene flips y for rendering only.
import CoreGraphics

enum Slot: String { case p1, p2 }

enum Court {
    static let W: CGFloat = 390
    static let H: CGFloat = 844
    static var center: CGPoint { CGPoint(x: W / 2, y: H / 2) }
    static let aspect: CGFloat = 390.0 / 844.0
}

enum GC {
    static let paddle: CGFloat = 88          // paddle (face coin) diameter
    static let paddleR: CGFloat = 44
    static let ballR: CGFloat = 10

    static let topY: CGFloat = 168           // top paddle center y (opponent)
    static let botY: CGFloat = 676           // bottom paddle center y (local player)

    static let wallPad: CGFloat = 6          // ball inset from left/right walls
    static let paddleMargin: CGFloat = 44 + 8 // clamp for paddle center x (PADDLE_R + 8)

    static let maxSpeed: CGFloat = 14.0      // max ball speed (units/tick) — a long rally gets genuinely fast
    static let rallyRamp: CGFloat = 1.085    // ball speeds up this much per paddle hit (compounds over the rally)
    static let serveVY: CGFloat = 6.2        // vertical serve speed
    static let serveVXSpread: CGFloat = 2.4  // random horizontal spread on serve
    static let paddleBounce: CGFloat = 5.2   // how much paddle hit offset bends vx

    // HEARTS: each player starts with this many hearts; you lose one each time you
    // concede a point, and the first to zero hearts loses. Mechanically identical to
    // "first to startingHearts points", but the HUD shows it as draining hearts so the
    // match state is legible at a glance. targetScore is kept as the win threshold the
    // engine checks (you reach it = the opponent's last heart pops).
    static let startingHearts = 5
    static let targetScore = startingHearts  // reaching this many points drains the rival to 0 hearts
    static let countdownFrom = 3

    static let tickHz: Double = 60
    static let tickMs: Double = 1000.0 / 60.0

    // Paddle smoothing.
    static let easeToward: CGFloat = 0.09    // AI tracks faster when ball approaches
    static let easeAway: CGFloat = 0.03
    static let inputFollow: CGFloat = 0.45   // local paddle follows finger this much per tick
}

@inline(__always)
func clampPaddleX(_ x: CGFloat) -> CGFloat {
    let lo = GC.paddleMargin
    let hi = Court.W - GC.paddleMargin
    return x < lo ? lo : (x > hi ? hi : x)
}

// Difficulty — the full definition of how hard one CPU opponent plays. The old CPU
// was a single hidden constant (a 0.081/tick low-pass chasing the ball's CURRENT x,
// with zero reaction lag, zero error, no prediction) which is why it felt "too easy
// and vague". Every axis below is a real, named knob threaded per-match into the live
// loop. A famous-face opponent is just one of these profiles wearing a face.
//
// Speed knobs are MULTIPLIERS on the global GC bases and are applied PER-INSTANCE on
// the engine, so the Colyseus server (which constructs its own engine and never sets
// them) plays byte-identical online.
struct Difficulty {
    var name: String
    var reactionTicks: Int       // frames of lag before the AI reacts to a ball change (ring buffer; 60Hz → ticks≈ms/16.7)
    var trackGain: CGFloat       // per-tick lerp toward its target when the ball is approaching (replaces the hardcoded 0.081)
    var trackGainAway: CGFloat   // per-tick lerp when the ball is receding (replaces 0.03)
    var predict: CGFloat         // 0…1 blend between chasing current ballX (0) and the wall-mirrored intercept (1)
    var aimErrorUnits: CGFloat   // x-offset error added to the AI target, re-rolled ONCE per rally (so it mispositions, not jitters)
    var coverage: CGFloat        // scales the CPU's effective paddle half-width (its reach); <1 leaves gaps, >1 = superhuman reach
    var maxSpeedMul: CGFloat     // × GC.maxSpeed — the per-instance ball speed cap
    var rampMul: CGFloat         // scales the per-hit speed-up: effective ramp = 1 + (GC.rallyRamp-1) × rampMul
    var serveVYMul: CGFloat      // × GC.serveVY — opening serve speed
    var serveVXSpreadMul: CGFloat// × GC.serveVXSpread — opening serve angle randomness

    // The chess.com-style ladder: rung 1 is built to LOSE; rung 9 is near-unbeatable.
    // Each axis moves monotonically toward harder. Tier 4 (Sharp) ≈ today's tracking
    // gain (0.082) but with human lag/error + prediction, so it actually fights back.
    static let tiers: [Difficulty] = [
        //         name           reactTk  track  trackAway  predict  aimErr  cover  spdMul  rampMul  svYMul  svXMul
        .init(name: "WARM-UP",      reactionTicks: 19, trackGain: 0.040, trackGainAway: 0.015, predict: 0.00, aimErrorUnits: 34, coverage: 0.62, maxSpeedMul: 0.62, rampMul: 0.85, serveVYMul: 0.81, serveVXSpreadMul: 0.70),
        .init(name: "ROOKIE",       reactionTicks: 16, trackGain: 0.052, trackGainAway: 0.019, predict: 0.00, aimErrorUnits: 26, coverage: 0.72, maxSpeedMul: 0.70, rampMul: 0.90, serveVYMul: 0.84, serveVXSpreadMul: 0.80),
        .init(name: "REGULAR",      reactionTicks: 12, trackGain: 0.066, trackGainAway: 0.024, predict: 0.15, aimErrorUnits: 18, coverage: 0.82, maxSpeedMul: 0.80, rampMul: 0.95, serveVYMul: 0.87, serveVXSpreadMul: 0.90),
        .init(name: "SHARP",        reactionTicks: 9,  trackGain: 0.082, trackGainAway: 0.030, predict: 0.35, aimErrorUnits: 12, coverage: 0.90, maxSpeedMul: 0.90, rampMul: 1.00, serveVYMul: 0.90, serveVXSpreadMul: 1.00),
        .init(name: "PRO",          reactionTicks: 7,  trackGain: 0.100, trackGainAway: 0.037, predict: 0.55, aimErrorUnits: 8,  coverage: 0.96, maxSpeedMul: 1.00, rampMul: 1.06, serveVYMul: 0.94, serveVXSpreadMul: 1.10),
        .init(name: "ACE",          reactionTicks: 5,  trackGain: 0.125, trackGainAway: 0.046, predict: 0.72, aimErrorUnits: 5,  coverage: 1.00, maxSpeedMul: 1.12, rampMul: 1.10, serveVYMul: 0.97, serveVXSpreadMul: 1.20),
        .init(name: "CHAMPION",     reactionTicks: 3,  trackGain: 0.150, trackGainAway: 0.055, predict: 0.85, aimErrorUnits: 3,  coverage: 1.05, maxSpeedMul: 1.22, rampMul: 1.14, serveVYMul: 1.00, serveVXSpreadMul: 1.30),
        .init(name: "LEGEND",       reactionTicks: 2,  trackGain: 0.180, trackGainAway: 0.067, predict: 0.93, aimErrorUnits: 1.5,coverage: 1.10, maxSpeedMul: 1.32, rampMul: 1.18, serveVYMul: 1.05, serveVXSpreadMul: 1.40),
        .init(name: "GRANDMASTER",  reactionTicks: 1,  trackGain: 0.220, trackGainAway: 0.081, predict: 0.98, aimErrorUnits: 0.6,coverage: 1.15, maxSpeedMul: 1.45, rampMul: 1.22, serveVYMul: 1.19, serveVXSpreadMul: 1.50),
    ]

    // Default VS COMPUTER opponent: a genuine fight (≈ today's gain + lag/error + prediction),
    // not the old never-lose wall.
    static let fair = tiers[3]   // SHARP
}
