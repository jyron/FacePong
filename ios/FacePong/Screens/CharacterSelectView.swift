// CharacterSelectView.swift — the VS COMPUTER rival picker. A scrollable grid of
// famous-face lookalikes, ordered easiest → hardest, each showing its threat level,
// whether you've CONQUERED it, and whether it's LOCKED (a premium unlock). Tapping
// routes through model.play(), which raises the unlock/refill paywall when gated.
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
                        RivalCard(character: c,
                                  locked: !model.store.isUnlocked(c),
                                  conquered: model.hasBeaten(c)) { model.play(c) }
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
            VStack(spacing: 3) {
                Text("CHOOSE YOUR RIVAL")
                    .font(.display(20)).foregroundStyle(Color(hex: "#ff2e88"))
                    .neonGlow(Color(hex: "#ff2e88"), radius: 16, strong: true)
                Text("\(model.rivalsBeatenCount)/\(Rival.roster.count) CONQUERED")
                    .font(.bodyBold(10)).tracking(1.5).foregroundStyle(Color(hex: "#d4ff3d"))
            }
            HStack {
                Button { model.route = .start } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: "#a59fce"))
                        .padding(11)
                        .background(Circle().fill(Color(hex: "#14122a")))
                }
                Spacer()
                HeartChip(hearts: model.hearts, onTap: { model.openStore() })
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
    }
}

/// Compact live hearts indicator (count + regen countdown). When `onTap` is set it becomes a
/// button — with a lime "+" — into the always-available hearts & store sheet (the discoverable
/// way to buy hearts / unlock everything).
struct HeartChip: View {
    @ObservedObject var hearts: HeartBank
    var onTap: (() -> Void)? = nil
    var body: some View {
        if let onTap {
            Button(action: onTap) { chip }.buttonStyle(PressDownStyle())
        } else {
            chip
        }
    }
    private var chip: some View {
        HStack(spacing: 6) {
            Image(systemName: "heart.fill").font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(hex: "#ff2e88")).neonGlow(Color(hex: "#ff2e88"), radius: 5)
            if hearts.unlimited {
                Image(systemName: "infinity").font(.system(size: 13, weight: .bold)).foregroundStyle(Color(hex: "#d4ff3d"))
            } else {
                Text("\(hearts.hearts)").font(.bodyBold(15)).foregroundStyle(Color(hex: "#f3f1ff"))
                if !hearts.countdownString.isEmpty {
                    Text(hearts.countdownString).font(.body(10)).foregroundStyle(Color(hex: "#6a6496"))
                }
            }
            if onTap != nil {
                Image(systemName: "plus.circle.fill").font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: "#d4ff3d"))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Capsule().fill(Color(hex: "#14122a")))
        .overlay(Capsule().stroke(Color(hex: "#ff2e88").opacity(0.35), lineWidth: 1))
    }
}

private struct RivalCard: View {
    let character: Rival
    var locked: Bool
    var conquered: Bool
    var action: () -> Void

    private var threat: Color {
        switch character.level {
        case ...3: return Color(hex: "#d4ff3d")
        case 4...7: return Color(hex: "#ffb02e")
        default:   return Color(hex: "#ff4d2e")
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    FaceCoin(image: character.face, slot: .p2, size: 92)
                        .saturation(locked ? 0.25 : 1)
                        .opacity(locked ? 0.8 : 1)
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 26, weight: .black))
                            .foregroundStyle(.white)
                            .shadow(color: .black, radius: 4)
                    }
                    if conquered {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color(hex: "#d4ff3d"))
                            .background(Circle().fill(Color(hex: "#07070f")).frame(width: 22, height: 22))
                            .offset(x: 34, y: 34)
                    }
                }
                .padding(.top, 4)

                Text(character.name)
                    .font(.display(13)).tracking(0.5)
                    .foregroundStyle(Color(hex: "#f3f1ff"))
                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.6)
                    .frame(height: 34)
                ThreatMeter(level: character.level, color: threat)
                Text(character.difficulty.name)
                    .font(.bodyBold(10)).tracking(1.5).foregroundStyle(threat)

                if locked {
                    Text("UNLOCK")
                        .font(.bodyBold(10)).tracking(1.5)
                        .foregroundStyle(Color(hex: "#07070f"))
                        .padding(.horizontal, 14).padding(.vertical, 5)
                        .background(Capsule().fill(Color(hex: "#d4ff3d")))
                } else {
                    Text(conquered ? "PLAY AGAIN" : "CHALLENGE")
                        .font(.bodyBold(10)).tracking(1.5)
                        .foregroundStyle(conquered ? Color(hex: "#d4ff3d") : Color(hex: "#19e7ff"))
                        .frame(height: 24)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color(hex: "#14122a")))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke((conquered ? Color(hex: "#d4ff3d") : threat).opacity(locked ? 0.3 : 0.5), lineWidth: 1.5)
            )
        }
        .buttonStyle(PressDownStyle())
    }
}

/// Pips showing the rival's difficulty level (out of the full roster), filled up to `level`.
private struct ThreatMeter: View {
    let level: Int
    let color: Color
    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<Rival.roster.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < level ? color : Color(hex: "#3a3658"))
                    .frame(width: 6, height: 7)
                    .neonGlow(i < level ? color : .clear, radius: 2.5)
            }
        }
    }
}
