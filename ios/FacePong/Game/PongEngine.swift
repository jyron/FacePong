// PongEngine.swift — deterministic ball physics + collisions + scoring.
// Ported verbatim from shared/engine.ts. Pure value type, no rendering deps.
// All positions/velocities are in court units (390x844, y-down); velocities
// are per fixed 60Hz tick. Bounces MIRROR position across the contact plane
// (not clamp) so the ball keeps its full per-tick travel — a clamp eats the
// sub-tick remainder and reads as a one-frame stall at late-rally speeds.
import CoreGraphics

struct EngineState {
    var ballX: CGFloat = Court.W / 2
    var ballY: CGFloat = Court.H / 2
    var vx: CGFloat = 0
    var vy: CGFloat = 0
    var p1x: CGFloat = Court.W / 2   // bottom paddle center (local / cyan)
    var p2x: CGFloat = Court.W / 2   // top paddle center (opponent / magenta)
    var rally: Int = 0
}

struct StepResult {
    var scored: Slot? = nil      // which player won the point this tick
    var paddleHit: Slot? = nil   // which paddle returned the ball this tick
    var wallHit: Bool = false    // a left/right wall was hit this tick
}

struct PongEngine {
    var s = EngineState()

    mutating func serve(toward: Slot) {
        s.ballX = Court.W / 2
        s.ballY = Court.H / 2
        s.vx = (CGFloat.random(in: 0..<1) * 2 - 1) * GC.serveVXSpread
        s.vy = toward == .p1 ? GC.serveVY : -GC.serveVY
        s.rally = 0
    }

    func aiTargetX() -> CGFloat { clampPaddleX(s.ballX) }

    // Advance the ball exactly one fixed tick using the current paddle centers.
    mutating func step() -> StepResult {
        var r = StepResult()

        s.ballX += s.vx
        s.ballY += s.vy

        // left / right walls
        if s.ballX < GC.ballR + GC.wallPad {
            s.ballX = 2 * (GC.ballR + GC.wallPad) - s.ballX
            s.vx = abs(s.vx)
            r.wallHit = true
        } else if s.ballX > Court.W - GC.ballR - GC.wallPad {
            s.ballX = 2 * (Court.W - GC.ballR - GC.wallPad) - s.ballX
            s.vx = -abs(s.vx)
            r.wallHit = true
        }

        // top paddle (p2) — ball travelling up
        if s.vy < 0 && s.ballY - GC.ballR < GC.topY + GC.paddleR && s.ballY - GC.ballR > GC.topY - GC.paddleR {
            let dx = s.ballX - s.p2x
            if abs(dx) < GC.paddleR + GC.ballR {
                s.ballY = 2 * (GC.topY + GC.paddleR + GC.ballR) - s.ballY
                s.vy = abs(s.vy) * GC.rallyRamp
                s.vx = (dx / GC.paddleR) * GC.paddleBounce
                s.rally += 1
                r.paddleHit = .p2
            }
        }

        // bottom paddle (p1) — ball travelling down
        if s.vy > 0 && s.ballY + GC.ballR > GC.botY - GC.paddleR && s.ballY + GC.ballR < GC.botY + GC.paddleR {
            let dx = s.ballX - s.p1x
            if abs(dx) < GC.paddleR + GC.ballR {
                s.ballY = 2 * (GC.botY - GC.paddleR - GC.ballR) - s.ballY
                s.vy = -abs(s.vy) * GC.rallyRamp
                s.vx = (dx / GC.paddleR) * GC.paddleBounce
                s.rally += 1
                r.paddleHit = .p1
            }
        }

        // out of bounds -> the opposite player scores (24u grace past the paddle)
        if s.ballY < -GC.ballR - 24 {
            r.scored = .p1
        } else if s.ballY > Court.H + GC.ballR + 24 {
            r.scored = .p2
        }

        // clamp speed
        let sp = (s.vx * s.vx + s.vy * s.vy).squareRoot()
        if sp > GC.maxSpeed {
            s.vx *= GC.maxSpeed / sp
            s.vy *= GC.maxSpeed / sp
        }

        return r
    }
}
