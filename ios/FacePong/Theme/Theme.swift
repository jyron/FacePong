// Theme.swift — the neon-arcade palette + color helpers, ported from tokens.ts.
import SpriteKit
import SwiftUI

extension SKColor {
    convenience init(hex: String) {
        var h = hex
        if h.hasPrefix("#") { h.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        let r, g, b, a: CGFloat
        if h.count == 8 {
            r = CGFloat((v >> 24) & 0xff) / 255
            g = CGFloat((v >> 16) & 0xff) / 255
            b = CGFloat((v >> 8) & 0xff) / 255
            a = CGFloat(v & 0xff) / 255
        } else {
            r = CGFloat((v >> 16) & 0xff) / 255
            g = CGFloat((v >> 8) & 0xff) / 255
            b = CGFloat(v & 0xff) / 255
            a = 1
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

enum Palette {
    static let bg = SKColor(hex: "#07070f")
    static let bg2 = SKColor(hex: "#0d0c1a")
    static let surface = SKColor(hex: "#14122a")
    static let surface2 = SKColor(hex: "#1d1b3a")
    static let ink = SKColor(hex: "#f3f1ff")
    static let inkDim = SKColor(hex: "#a59fce")
    static let inkFaint = SKColor(hex: "#6a6496")

    static let cyan = SKColor(hex: "#19e7ff")    // player 1 (bottom / local)
    static let magenta = SKColor(hex: "#ff2e88") // player 2 (top / opponent)
    static let lime = SKColor(hex: "#d4ff3d")    // ball / highlight
    static let purple = SKColor(hex: "#7b3bff")
    static let amber = SKColor(hex: "#ffb02e")
    static let hot = SKColor(hex: "#ff4d2e")     // rally-15+ ball heat

    static let grid = SKColor(red: 123/255, green: 59/255, blue: 255/255, alpha: 0.16)

    static func ring(_ slot: Slot) -> SKColor { slot == .p1 ? cyan : magenta }
}

extension Color {
    init(hex: String) {
        let c = SKColor(hex: hex)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

enum FontName {
    static let display = "Bungee-Regular"
    static let body = "SpaceGrotesk-Medium"
    static let bodyBold = "SpaceGrotesk-Bold"
}

// Linear RGB lerp between two SKColors.
func lerpColor(_ a: SKColor, _ b: SKColor, _ t: CGFloat) -> SKColor {
    let tt = max(0, min(1, t))
    var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
    var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
    a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
    b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
    return SKColor(red: ar + (br - ar) * tt, green: ag + (bg - ag) * tt,
                   blue: ab + (bb - ab) * tt, alpha: aa + (ba - aa) * tt)
}

// Rally heat: lime → amber → #ff4d2e across rally [0, 7, 14], matching the speed ramp.
func heatColor(rally: Int) -> SKColor {
    let r = CGFloat(min(rally, 14))
    if r <= 7 { return lerpColor(Palette.lime, Palette.amber, r / 7) }
    return lerpColor(Palette.amber, Palette.hot, (r - 7) / 7)
}
