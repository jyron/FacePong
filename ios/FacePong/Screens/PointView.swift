// PointView.swift — between-points overlay on the frozen court.
import SwiftUI

struct PointView: View {
    @ObservedObject var model: GameModel
    private var localScored: Bool { model.lastScorer == .p1 }

    @State private var pop = false
    private var accent: Color { localScored ? Color(hex: "#d4ff3d") : Color(hex: "#ff2e88") }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer()
                FaceCoin(image: localScored ? model.p1Face : model.opponentFace,
                         slot: localScored ? .p1 : .p2, size: 84)
                    .scaleEffect(pop ? 1 : 0.5)
                    .rotationEffect(.degrees(pop ? 0 : (localScored ? -12 : 12)))

                Text(localScored ? "POINT!" : "POINT LOST")
                    .font(.display(localScored ? 58 : 46))
                    .foregroundStyle(accent)
                    .neonGlow(accent, radius: 28, strong: true)
                    .scaleEffect(pop ? 1 : 1.5)

                Text(localScored ? "You took the point." : "\(model.opponentName) took that one.")
                    .font(.bodyBold(13)).tracking(1).foregroundStyle(Color(hex: "#a59fce"))

                // The live scoreline — first to \(GC.targetScore) wins.
                VStack(spacing: 12) {
                    scoreRow(name: "YOU", face: model.p1Face, slot: .p1, score: model.score1, color: Color(hex: "#19e7ff"))
                    scoreRow(name: model.opponentName, face: model.opponentFace, slot: .p2, score: model.score2, color: Color(hex: "#ff2e88"))
                }
                .padding(.vertical, 4)

                Text(serveText).font(.body(13)).foregroundStyle(Color(hex: "#6a6496"))

                VStack(spacing: 12) {
                    NeonButton(title: "NEXT POINT", kind: .cyan) { model.nextPoint() }
                    NeonButton(title: "JUMP TO MATCH END", kind: .ghost) { model.route = .match }
                }
                .padding(.horizontal, 28)
                Spacer()
            }
        }
        .onAppear {
            pop = false
            withAnimation(.spring(response: 0.34, dampingFraction: 0.55)) { pop = true }
        }
        .task {
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            if model.route == .point { model.nextPoint() }
        }
    }

    @ViewBuilder private func scoreRow(name: String, face: UIImage?, slot: Slot, score: Int, color: Color) -> some View {
        HStack(spacing: 12) {
            FaceCoin(image: face, slot: slot, size: 32)
            Text(name).font(.bodyBold(12)).foregroundStyle(Color(hex: "#a59fce"))
                .frame(width: 130, alignment: .leading).lineLimit(1).minimumScaleFactor(0.6)
            Spacer(minLength: 0)
            ScorePips(score: score, color: color, size: 13)
        }
        .padding(.horizontal, 30)
    }

    private var serveText: String {
        let leader = max(model.score1, model.score2)
        if leader == GC.targetScore - 1 {
            return model.score1 > model.score2 ? "MATCH POINT — finish it" : "MATCH POINT against you — dig in"
        }
        return localScored ? "You serve next" : "\(model.opponentName) serves next"
    }
}
