// TextureFactory.swift — procedural textures generated once and reused.
// The radial "soft dot" is the workhorse: a white blob with a smooth alpha
// falloff. Drawn with SKBlendMode.add and a color blend it becomes every glow,
// every comet-trail dot, and every confetti speck — overlapping additive copies
// stack into the blown-out white-hot cores the art calls for.
import SpriteKit
import UIKit

enum TextureFactory {
    // A soft radial dot: alpha 1 at center → 0 at edge with a gaussian-ish curve.
    static let softDot: SKTexture = makeSoftDot(diameter: 128, falloff: 1.0)
    // A harder dot (smaller bright core) for crisp specks.
    static let crispDot: SKTexture = makeSoftDot(diameter: 96, falloff: 2.2)
    // A near-solid filled disc with a 2px feathered edge — the actual ball body.
    static let solidDot: SKTexture = makeSolidDot(diameter: 96)

    static func makeSolidDot(diameter: Int) -> SKTexture {
        let size = CGSize(width: diameter, height: diameter)
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            let c = ctx.cgContext
            let r = CGFloat(diameter) / 2
            let center = CGPoint(x: r, y: r)
            // solid white core to ~88% radius, then a quick feather to 0 for AA.
            let colors = [SKColor.white.cgColor,
                          SKColor.white.cgColor,
                          SKColor.white.withAlphaComponent(0).cgColor] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            guard let grad = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.86, 1]) else { return }
            c.drawRadialGradient(grad, startCenter: center, startRadius: 0,
                                 endCenter: center, endRadius: r, options: [])
        }
        let tex = SKTexture(image: img)
        tex.filteringMode = .linear
        return tex
    }

    static func makeSoftDot(diameter: Int, falloff: CGFloat) -> SKTexture {
        let size = CGSize(width: diameter, height: diameter)
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            let c = ctx.cgContext
            let r = CGFloat(diameter) / 2
            let center = CGPoint(x: r, y: r)
            let colors = [SKColor.white.withAlphaComponent(1).cgColor,
                          SKColor.white.withAlphaComponent(0).cgColor] as CFArray
            // A two-stop gradient with an eased midpoint for a soft, photographic falloff.
            let space = CGColorSpaceCreateDeviceRGB()
            let locations: [CGFloat] = [0, 1]
            guard let grad = CGGradient(colorsSpace: space, colors: colors, locations: locations) else { return }
            // Apply falloff by drawing the gradient into a clipped, gamma-shaped mask.
            c.drawRadialGradient(grad, startCenter: center, startRadius: 0,
                                 endCenter: center, endRadius: r,
                                 options: [.drawsAfterEndLocation])
            _ = falloff
        }
        let tex = SKTexture(image: img)
        tex.filteringMode = .linear
        return tex
    }

    // A stroked ring texture (for impact rings if we want texture-based; we use
    // SKShapeNode for those, so this is just here for completeness/glow rings).
    static func makeRing(diameter: Int, lineWidth: CGFloat) -> SKTexture {
        let size = CGSize(width: diameter, height: diameter)
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            let c = ctx.cgContext
            c.setStrokeColor(SKColor.white.cgColor)
            c.setLineWidth(lineWidth)
            let inset = lineWidth / 2 + 1
            c.strokeEllipse(in: CGRect(x: inset, y: inset,
                                       width: CGFloat(diameter) - inset * 2,
                                       height: CGFloat(diameter) - inset * 2))
        }
        return SKTexture(image: img)
    }

    // The arcade backdrop: a subtle purple grid fading into a vignette over the
    // near-black background, generated at court resolution.
    static func makeCourtBackground(size: CGSize, spacing: CGFloat = 39) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            let c = ctx.cgContext
            // base fill
            c.setFillColor(Palette.bg.cgColor)
            c.fill(CGRect(origin: .zero, size: size))
            // grid lines
            c.setStrokeColor(Palette.grid.cgColor)
            c.setLineWidth(1)
            var x: CGFloat = 0
            while x <= size.width {
                c.move(to: CGPoint(x: x, y: 0)); c.addLine(to: CGPoint(x: x, y: size.height)); x += spacing
            }
            var y: CGFloat = 0
            while y <= size.height {
                c.move(to: CGPoint(x: 0, y: y)); c.addLine(to: CGPoint(x: size.width, y: y)); y += spacing
            }
            c.strokePath()
            // vignette: radial dark gradient fading the edges to black
            let space = CGColorSpaceCreateDeviceRGB()
            let colors = [SKColor.clear.cgColor,
                          SKColor(red: 0.02, green: 0.02, blue: 0.05, alpha: 0.9).cgColor] as CFArray
            if let grad = CGGradient(colorsSpace: space, colors: colors, locations: [0.45, 1]) {
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                c.drawRadialGradient(grad, startCenter: center, startRadius: 0,
                                     endCenter: center, endRadius: max(size.width, size.height) * 0.75,
                                     options: [.drawsAfterEndLocation])
            }
        }
        return SKTexture(image: img)
    }
}
