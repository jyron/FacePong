// PlayHUD.swift — in-play overlay on the live court: opponent + you coins, the
// score, the live rally pill, a quit button, and the "RALLY xN" milestone badge.
import SwiftUI

struct PlayHUD: View {
    @ObservedObject var model: GameModel
    @State private var milestone: Int?
    @State private var milestoneShown = false

    var body: some View {
        VStack {
            HStack(alignment: .top) {
                playerTag(slot: .p2, name: model.opponentName, trailing: false)
                Spacer()
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Text("\(model.score1)").font(.display(26)).foregroundStyle(Color(hex: "#19e7ff"))
                        Text("·").font(.display(22)).foregroundStyle(Color(hex: "#6a6496"))
                        Text("\(model.score2)").font(.display(26)).foregroundStyle(Color(hex: "#ff2e88"))
                    }
                    NeonPill(text: "RALLY · \(model.liveRally)")
                }
                Spacer()
                playerTag(slot: .p1, name: "YOU", trailing: true)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            Spacer()
        }
        .overlay(alignment: .topTrailing) {
            Button { model.online ? model.leaveOnline() : model.toMenu() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: "#a59fce"))
                    .padding(10)
                    .background(Circle().fill(Color(hex: "#14122a")))
            }
            .padding(.trailing, 16).padding(.top, 70)
        }
        .overlay { milestoneBadge }
        .onChange(of: model.liveRally) { _, r in
            if r > 0 && r % 5 == 0 { fireMilestone(r) }
        }
    }

    @ViewBuilder private func playerTag(slot: Slot, name: String, trailing: Bool) -> some View {
        let coin = FaceCoin(image: slot == .p1 ? model.p1Face : model.opponentFace, slot: slot, size: 38)
        HStack(spacing: 8) {
            if trailing { Text(name).font(.bodyBold(12)).foregroundStyle(Color(hex: "#a59fce")); coin }
            else { coin; Text(name).font(.bodyBold(12)).foregroundStyle(Color(hex: "#a59fce")) }
        }
    }

    private var milestoneColor: Color {
        guard let m = milestone else { return Color(hex: "#d4ff3d") }
        if m >= 15 { return Color(hex: "#ff4d2e") }
        if m >= 10 { return Color(hex: "#ffb02e") }
        return Color(hex: "#d4ff3d")
    }

    @ViewBuilder private var milestoneBadge: some View {
        if let m = milestone {
            Text("RALLY x\(m)")
                .font(.display(40))
                .foregroundStyle(milestoneColor)
                .neonGlow(milestoneColor, radius: 24, strong: true)
                .scaleEffect(milestoneShown ? 1 : 1.6)
                .opacity(milestoneShown ? 1 : 0)
                .offset(y: -120)
        }
    }

    private func fireMilestone(_ r: Int) {
        milestone = r
        milestoneShown = false
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { milestoneShown = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 0.3)) { milestoneShown = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { if milestone == r { milestone = nil } }
        }
    }
}
