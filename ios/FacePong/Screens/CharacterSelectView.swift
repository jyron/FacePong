// CharacterSelectView.swift — the VS COMPUTER rival picker. A scrollable grid of
// famous-face lookalikes, ordered easiest → hardest, each showing its threat level.
// Tapping one starts the match against that rival at its difficulty tier.
import SwiftUI

struct CharacterSelectView: View {
    @ObservedObject var model: GameModel

    private let cols = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: cols, spacing: 14) {
                    ForEach(Rival.roster) { c in
                        RivalCard(character: c) { model.startCPU(c) }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 28)
            }
        }
        .padding(.top, 12)
    }

    private var header: some View {
        ZStack {
            Text("CHOOSE YOUR RIVAL")
                .font(.display(22)).foregroundStyle(Color(hex: "#ff2e88"))
                .neonGlow(Color(hex: "#ff2e88"), radius: 16, strong: true)
            HStack {
                Button { model.route = .start } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: "#a59fce"))
                        .padding(11)
                        .background(Circle().fill(Color(hex: "#14122a")))
                }
                Spacer()
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
    }
}

private struct RivalCard: View {
    let character: Rival
    var action: () -> Void

    // Threat color ramps lime → amber → hot with the rival's level (1…9).
    private var threat: Color {
        switch character.level {
        case ...3: return Color(hex: "#d4ff3d")
        case 4...6: return Color(hex: "#ffb02e")
        default:   return Color(hex: "#ff4d2e")
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                FaceCoin(image: character.face, slot: .p2, size: 92)
                    .padding(.top, 4)
                Text(character.name)
                    .font(.display(13)).tracking(0.5)
                    .foregroundStyle(Color(hex: "#f3f1ff"))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .frame(height: 34)
                ThreatMeter(level: character.level, color: threat)
                Text(character.difficulty.name)
                    .font(.bodyBold(10)).tracking(1.5).foregroundStyle(threat)
                Text(character.blurb)
                    .font(.body(10)).foregroundStyle(Color(hex: "#8a83b8"))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 28, alignment: .top)
                    .padding(.horizontal, 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18).fill(Color(hex: "#14122a"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(threat.opacity(0.45), lineWidth: 1.5)
            )
        }
        .buttonStyle(PressDownStyle())
    }
}

/// Nine pips showing the rival's difficulty level, filled up to `level`.
private struct ThreatMeter: View {
    let level: Int
    let color: Color
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<9, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < level ? color : Color(hex: "#3a3658"))
                    .frame(width: 7, height: 7)
                    .neonGlow(i < level ? color : .clear, radius: 3)
            }
        }
    }
}
