// MatchView.swift — the victory/defeat screen with winner coin, score, stats.
import SwiftUI

struct MatchView: View {
    @ObservedObject var model: GameModel
    @State private var spin = false
    private var youWon: Bool { model.score1 > model.score2 }
    private var winnerFace: UIImage? { youWon ? model.p1Face : model.opponentFace }
    private var winnerSlot: Slot { youWon ? .p1 : .p2 }
    private var ringColor: Color { youWon ? Color(hex: "#19e7ff") : Color(hex: "#ff2e88") }

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 8)
            Text("👑").font(.system(size: 34))
            Text("GAME!").font(.display(48)).foregroundStyle(Color(hex: "#d4ff3d"))
                .neonGlow(Color(hex: "#d4ff3d"), radius: 24, strong: true)

            ZStack {
                Circle()
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [4, 8]))
                    .foregroundStyle(ringColor.opacity(0.6))
                    .frame(width: 168, height: 168)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .animation(.linear(duration: 16).repeatForever(autoreverses: false), value: spin)
                FaceCoin(image: winnerFace, slot: winnerSlot, size: 128)
            }
            .padding(.vertical, 4)

            Text(youWon ? "YOU WIN" : "YOU LOSE").font(.display(20))
                .foregroundStyle(youWon ? Color(hex: "#d4ff3d") : Color(hex: "#ff2e88"))
            HStack(spacing: 10) {
                Text("\(model.score1)").font(.display(34)).foregroundStyle(Color(hex: "#19e7ff"))
                Text("·").font(.display(28)).foregroundStyle(Color(hex: "#6a6496"))
                Text("\(model.score2)").font(.display(34)).foregroundStyle(Color(hex: "#ff2e88"))
            }

            HStack(spacing: 12) {
                statCard("\(model.topRally)", "TOP RALLY", Color(hex: "#d4ff3d"))
                statCard("\(model.aces)", "ACES", Color(hex: "#19e7ff"))
                statCard(model.elapsedString, "TIME", Color(hex: "#ffb02e"))
            }
            .padding(.horizontal, 22)

            VStack(spacing: 12) {
                NeonButton(title: "SHARE THE WIN", kind: .lime) {
                    if model.online { model.showOnlineShare = true } else { model.route = .share }
                }
                NeonButton(title: "REMATCH", kind: .cyan) {
                    if model.online { model.leaveOnline() } else { model.rematch() }
                }
                NeonButton(title: "MAIN MENU", kind: .ghost) {
                    if model.online { model.leaveOnline() } else { model.toMenu() }
                }
            }
            .padding(.horizontal, 28)
            Spacer(minLength: 8)
        }
        .padding(.top, 24)
        .onAppear { spin = true }
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
