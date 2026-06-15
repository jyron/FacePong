// ShareView.swift — the shareable victory card + share/save/copy actions.
import SwiftUI

struct ShareView: View {
    @ObservedObject var model: GameModel
    @State private var shareItems: [Any]?
    private let code = String((0..<4).map { _ in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".randomElement()! })
    private var link: String { "facepong.gg/r/\(code)" }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Button { if model.online { model.showOnlineShare = false } else { model.route = .match } } label: {
                    Label("Done", systemImage: "chevron.left").font(.body(15)).foregroundStyle(Color(hex: "#19e7ff"))
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 8)

            Text("SHARE THE WIN").font(.display(24)).foregroundStyle(Color(hex: "#d4ff3d"))
                .neonGlow(Color(hex: "#d4ff3d"), radius: 16)
            Text("Send your victory card to the group chat.")
                .font(.body(13)).foregroundStyle(Color(hex: "#a59fce"))

            VictoryCard(model: model, link: link).padding(.horizontal, 18)

            HStack(spacing: 14) {
                shareTile("💬", "Message"); shareTile("✨", "Story")
                shareTile("⬇️", "Save");    shareTile("•••", "More")
            }

            HStack(spacing: 10) {
                Text(link).font(.body(14)).foregroundStyle(Color(hex: "#a59fce"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { UIPasteboard.general.string = link } label: {
                    Text("COPY").font(.bodyBold(13)).foregroundStyle(Color(hex: "#07070f"))
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(Capsule().fill(Color(hex: "#19e7ff")))
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "#14122a")))
            .padding(.horizontal, 18)

            Spacer()
        }
        .sheet(isPresented: Binding(get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })) {
            if let items = shareItems { ShareSheet(items: items) }
        }
    }

    private func shareTile(_ emoji: String, _ label: String) -> some View {
        Button { share() } label: {
            VStack(spacing: 6) {
                Text(emoji).font(.system(size: 22))
                    .frame(width: 56, height: 56)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "#1d1b3a")))
                Text(label).font(.body(11)).foregroundStyle(Color(hex: "#a59fce"))
            }
        }
    }

    @MainActor private func share() {
        let card = VictoryCard(model: model, link: link).frame(width: 320, height: 200)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        var items: [Any] = ["I won \(model.score1)-\(model.score2) in FacePong! \(link)"]
        if let img = renderer.uiImage { items.insert(img, at: 0) }
        shareItems = items
    }
}

struct VictoryCard: View {
    @ObservedObject var model: GameModel
    let link: String
    private var youWon: Bool { model.score1 > model.score2 }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                HStack(spacing: 0) {
                    Text("FACE").font(.display(15)).foregroundStyle(Color(hex: "#19e7ff"))
                    Text("PONG").font(.display(15)).foregroundStyle(Color(hex: "#ff2e88"))
                }
                Spacer()
                Text(Self.stamp).font(.body(11)).foregroundStyle(Color(hex: "#6a6496"))
            }
            HStack(spacing: 20) {
                FaceCoin(image: model.p1Face, slot: .p1, size: 66)
                Text("VS").font(.display(14)).foregroundStyle(Color(hex: "#6a6496"))
                FaceCoin(image: model.opponentFace, slot: .p2, size: 66)
            }
            HStack(spacing: 6) {
                Text("👑").font(.system(size: 16))
                Text(youWon ? "YOU WIN" : "CPU WINS").font(.display(15)).foregroundStyle(Color(hex: "#d4ff3d"))
            }
            HStack(spacing: 8) {
                Text("\(model.score1)").font(.display(26)).foregroundStyle(Color(hex: "#19e7ff"))
                Text("·").font(.display(20)).foregroundStyle(Color(hex: "#6a6496"))
                Text("\(model.score2)").font(.display(26)).foregroundStyle(Color(hex: "#ff2e88"))
            }
            Text("\(link.uppercased()) · BEST OF 5").font(.body(10)).tracking(1)
                .foregroundStyle(Color(hex: "#6a6496"))
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: [Color(hex: "#1d1b3a"), Color(hex: "#14122a")], startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "#7b3bff").opacity(0.4), lineWidth: 1))
    }

    static var stamp: String {
        let f = DateFormatter(); f.dateFormat = "MMM d · h:mm a"
        return f.string(from: Date()).uppercased()
    }
}
