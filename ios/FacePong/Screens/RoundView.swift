// RoundView.swift — the pre-round 3·2·1·GO countdown over the ready court.
import SwiftUI

struct RoundView: View {
    @ObservedObject var model: GameModel
    @State private var count = 3
    @State private var go = false
    @State private var bump = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("ROUND \(model.roundNum)")
                .font(.bodyBold(15)).tracking(4).foregroundStyle(Color(hex: "#a59fce"))
            Text(go ? "GO" : "\(count)")
                .font(.display(110))
                .foregroundStyle(Color(hex: "#d4ff3d"))
                .neonGlow(Color(hex: "#d4ff3d"), radius: 30, strong: true)
                .scaleEffect(bump ? 1 : 0.6)
                .opacity(bump ? 1 : 0)
                .id(go ? -1 : count)
            Spacer()
        }
        .onAppear(perform: run)
    }

    private func run() {
        count = 3; go = false
        tickAnim()
        Sound.tick(go: false)
        step()
    }
    private func tickAnim() {
        bump = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { bump = true }
    }
    private func step() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            guard model.route == .round else { return }
            if count > 1 {
                count -= 1; tickAnim(); Sound.tick(go: false); step()
            } else {
                go = true; tickAnim(); Sound.tick(go: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if model.route == .round { model.beginPlay() }
                }
            }
        }
    }
}
