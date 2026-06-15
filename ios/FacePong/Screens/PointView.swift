// PointView.swift — between-points overlay on the frozen court.
import SwiftUI

struct PointView: View {
    @ObservedObject var model: GameModel
    private var localScored: Bool { model.lastScorer == .p1 }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()
                FaceCoin(image: localScored ? model.p1Face : model.p2Face,
                         slot: localScored ? .p1 : .p2, size: 84)

                Text(localScored ? "POINT!" : "OUCH!")
                    .font(.display(56))
                    .foregroundStyle(localScored ? Color(hex: "#d4ff3d") : Color(hex: "#ff2e88"))
                    .neonGlow(localScored ? Color(hex: "#d4ff3d") : Color(hex: "#ff2e88"), radius: 26, strong: true)

                HStack(spacing: 10) {
                    Text(localScored ? "YOU" : "CPU").font(.bodyBold(14)).foregroundStyle(Color(hex: "#a59fce"))
                    Text("+1").font(.display(16)).foregroundStyle(localScored ? Color(hex: "#19e7ff") : Color(hex: "#ff2e88"))
                }

                HStack(spacing: 14) {
                    FaceCoin(image: model.p1Face, slot: .p1, size: 34)
                    Text("\(model.score1) · \(model.score2)").font(.display(28)).foregroundStyle(Color(hex: "#f3f1ff"))
                    FaceCoin(image: model.p2Face, slot: .p2, size: 34)
                }

                Text(serveText).font(.body(13)).foregroundStyle(Color(hex: "#6a6496"))

                VStack(spacing: 12) {
                    NeonButton(title: "NEXT POINT", kind: .cyan) { model.nextPoint() }
                    NeonButton(title: "JUMP TO MATCH END", kind: .ghost) { model.route = .match }
                }
                .padding(.horizontal, 28)
                Spacer()
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            if model.route == .point { model.nextPoint() }
        }
    }

    private var serveText: String {
        let nextLeaderClose = max(model.score1, model.score2) == GC.targetScore - 1
        if nextLeaderClose { return "Match point next" }
        return localScored ? "YOU serve next" : "CPU serves next"
    }
}
