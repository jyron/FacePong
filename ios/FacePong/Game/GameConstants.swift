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

    static let maxSpeed: CGFloat = 10.6      // max ball speed (units/tick)
    static let rallyRamp: CGFloat = 1.06     // ball speeds up this much per paddle hit
    static let serveVY: CGFloat = 6.2        // vertical serve speed
    static let serveVXSpread: CGFloat = 2.4  // random horizontal spread on serve
    static let paddleBounce: CGFloat = 5.2   // how much paddle hit offset bends vx

    static let targetScore = 5               // first to this score wins the match
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
