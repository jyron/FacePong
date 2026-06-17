// MatchView.swift — the big dramatic VICTORY / DEFEAT screen: slam-in title,
// glowing winner coin, a CONQUERED stamp when you beat a new rival, the final
// score, and the match stats.
import SwiftUI

struct MatchView: View {
    @ObservedObject var model: GameModel
    @State private var spin = false
    @State private var slam = false
    @State private var flash = true

    private var youWon: Bool { model.score1 > model.score2 }
    private var winnerFace: UIImage? { youWon ? model.p1Face : model.opponentFace }
    private var winnerSlot: Slot { youWon ? .p1 : .p2 }
    private var hero: Color { youWon ? Color(hex: "#d4ff3d") : Color(hex: "#ff2e88") }
    // A brand-new conquest (this rival wasn't beaten before this match) → show the stamp.
    private var freshConquest: Bool { youWon && !model.online && model.justConqueredRival }

    var body: some View {
        ZStack {
            // dramatic radial wash in the result color
            RadialGradient(colors: [hero.opacity(0.22), .clear], center: .center, startRadius: 10, endRadius: 360)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Spacer(minLength: 6)

                Text(youWon ? "🏆" : "💀").font(.system(size: 40))
                    .scaleEffect(slam ? 1 : 0.3)

                Text(youWon ? "VICTORY!" : "DEFEAT")
                    .font(.display(youWon ? 56 : 50))
                    .foregroundStyle(hero)
                    .neonGlow(hero, radius: 30, strong: true)
                    .scaleEffect(slam ? 1 : 1.7)
                    .opacity(slam ? 1 : 0)

                Text(youWon ? "You beat \(model.opponentName)!" : "\(model.opponentName) wins this one.")
                    .font(.bodyBold(13)).tracking(1).foregroundStyle(Color(hex: "#a59fce"))
                    .multilineTextAlignment(.center).padding(.horizontal, 24)

                ZStack {
                    Circle().fill(hero.opacity(0.18)).frame(width: 184, height: 184).blur(radius: 18)
                    Circle()
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [4, 8]))
                        .foregroundStyle(hero.opacity(0.6))
                        .frame(width: 168, height: 168)
                        .rotationEffect(.degrees(spin ? 360 : 0))
                        .animation(.linear(duration: 16).repeatForever(autoreverses: false), value: spin)
                    FaceCoin(image: winnerFace, slot: winnerSlot, size: 128)
                        .scaleEffect(slam ? 1 : 0.4)
                    if freshConquest {
                        Text("CONQUERED")
                            .font(.display(15)).tracking(1)
                            .foregroundStyle(Color(hex: "#07070f"))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(Color(hex: "#d4ff3d")))
                            .rotationEffect(.degrees(-14))
                            .offset(y: 64)
                            .scaleEffect(slam ? 1 : 0)
                    }
                }
                .padding(.vertical, 2)

                // final score
                HStack(spacing: 16) {
                    scoreSide("YOU", model.score1, Color(hex: "#19e7ff"))
                    Text("\(model.score1)–\(model.score2)").font(.display(22)).foregroundStyle(Color(hex: "#6a6496"))
                    scoreSide(model.opponentName, model.score2, Color(hex: "#ff2e88"))
                }

                HStack(spacing: 12) {
                    statCard("\(model.topRally)", "TOP RALLY", Color(hex: "#d4ff3d"))
                    statCard("\(model.aces)", "ACES", Color(hex: "#19e7ff"))
                    statCard(model.elapsedString, "TIME", Color(hex: "#ffb02e"))
                }
                .padding(.horizontal, 22)

                VStack(spacing: 12) {
                    NeonButton(title: youWon ? "SHARE THE WIN" : "SHARE", kind: .lime) {
                        if model.online { model.showOnlineShare = true } else { model.route = .share }
                    }
                    NeonButton(title: youWon ? "PLAY AGAIN" : "TRY AGAIN", kind: .cyan) {
                        if model.online { model.leaveOnline() } else { model.retry() }
                    }
                    NeonButton(title: "MAIN MENU", kind: .ghost) {
                        if model.online { model.leaveOnline() } else { model.toMenu() }
                    }
                }
                .padding(.horizontal, 28)
                Spacer(minLength: 6)
            }
            .padding(.top, 20)

            // one-shot impact flash
            if flash { hero.opacity(0.5).ignoresSafeArea().allowsHitTesting(false) }
        }
        .onAppear {
            spin = true
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { slam = true }
            withAnimation(.easeOut(duration: 0.45)) { flash = false }
        }
    }

    private func scoreSide(_ name: String, _ score: Int, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(score)").font(.display(26)).foregroundStyle(color).neonGlow(color, radius: 10)
            Text(name).font(.bodyBold(9)).tracking(0.5).foregroundStyle(Color(hex: "#6a6496"))
                .frame(width: 76).lineLimit(1).minimumScaleFactor(0.6)
        }
    }

    private func statCard(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.display(22)).foregroundStyle(color)
            Text(label).font(.bodyBold(10)).tracking(1).foregroundStyle(Color(hex: "#6a6496"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "#14122a")))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#1d1b3a"), lineWidth: 1))
    }
}
