// NeonUI.swift — the neon-arcade SwiftUI design system: fonts, glow text,
// buttons, pills, the arcade backdrop, and the face coin/card. Ported from the
// original screens' look (Bungee display + Space Grotesk body, cyan/magenta/lime
// neon on near-black with a purple grid + vignette).
import SwiftUI

// MARK: fonts

extension Font {
    static func display(_ size: CGFloat) -> Font { .custom(FontName.display, size: size) }
    static func body(_ size: CGFloat) -> Font { .custom(FontName.body, size: size) }
    static func bodyBold(_ size: CGFloat) -> Font { .custom(FontName.bodyBold, size: size) }
}

// MARK: neon glow

extension View {
    /// Stacked soft shadows → a neon glow around text/shapes.
    func neonGlow(_ color: Color, radius: CGFloat = 16, strong: Bool = false) -> some View {
        self
            .shadow(color: color.opacity(strong ? 0.9 : 0.6), radius: radius)
            .shadow(color: color.opacity(strong ? 0.7 : 0.35), radius: radius * 0.5)
    }
}

// MARK: arcade backdrop

struct ArcadeBackground: View {
    var body: some View {
        ZStack {
            Color(hex: "#07070f")
            Canvas { ctx, size in
                let spacing: CGFloat = 39
                var path = Path()
                var x: CGFloat = 0
                while x <= size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += spacing }
                var y: CGFloat = 0
                while y <= size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += spacing }
                ctx.stroke(path, with: .color(Color(hex: "#7b3bff").opacity(0.16)), lineWidth: 1)
            }
            // vignette
            RadialGradient(colors: [.clear, Color(hex: "#05050c").opacity(0.95)],
                           center: .center, startRadius: 120, endRadius: 520)
        }
        .ignoresSafeArea()
    }
}

// MARK: buttons

enum NeonButtonKind { case lime, cyan, ghost }

struct NeonButton: View {
    let title: String
    var kind: NeonButtonKind = .lime
    var action: () -> Void

    private var fill: Color {
        switch kind { case .lime: return Color(hex: "#d4ff3d"); case .cyan: return Color(hex: "#19e7ff"); case .ghost: return .clear }
    }
    private var textColor: Color {
        switch kind { case .ghost: return Color(hex: "#a59fce"); default: return Color(hex: "#07070f") }
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.display(17))
                .tracking(1.5)
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Group {
                        if kind == .ghost {
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color(hex: "#6a6496").opacity(0.5), lineWidth: 1.5)
                        } else {
                            RoundedRectangle(cornerRadius: 18).fill(fill)
                        }
                    }
                )
                .if(kind != .ghost) { $0.neonGlow(fill, radius: 18) }
        }
        .buttonStyle(PressDownStyle())
    }
}

// little press-scale feedback
struct PressDownStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: pill

struct NeonPill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.bodyBold(12))
            .tracking(1.5)
            .foregroundStyle(Color(hex: "#a59fce"))
            .padding(.horizontal, 16).padding(.vertical, 9)
            .background(Capsule().fill(Color(hex: "#14122a")))
            .overlay(Capsule().stroke(Color(hex: "#7b3bff").opacity(0.35), lineWidth: 1))
    }
}

// MARK: face coin / card

/// Circular neon coin (HUD, point/match screens). Shows a cutout, or a default disc.
struct FaceCoin: View {
    var image: UIImage?
    var slot: Slot
    var size: CGFloat
    private var ring: Color { slot == .p1 ? Color(hex: "#19e7ff") : Color(hex: "#ff2e88") }
    var body: some View {
        ZStack {
            Circle().fill(Color(hex: slot == .p1 ? "#0c2b3a" : "#3a0c2a"))
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(ring, lineWidth: max(2, size * 0.05)))
        .neonGlow(ring, radius: size * 0.18)
    }
}

/// Rounded-rect face card (start screen). Cutout sits in a neon-bordered card.
struct FaceCard: View {
    var image: UIImage?
    var slot: Slot
    var size: CGFloat
    private var ring: Color { slot == .p1 ? Color(hex: "#19e7ff") : Color(hex: "#ff2e88") }
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(Color(hex: "#14122a"))
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "plus")
                    .font(.system(size: size * 0.28, weight: .bold))
                    .foregroundStyle(ring.opacity(0.8))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(ring, lineWidth: 2))
        .neonGlow(ring, radius: 14)
    }
}

// MARK: helpers

extension View {
    @ViewBuilder func `if`<T: View>(_ cond: Bool, _ transform: (Self) -> T) -> some View {
        if cond { transform(self) } else { self }
    }
}
