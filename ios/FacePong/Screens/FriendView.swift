// FriendView.swift — "play a friend" menu: host a new room (share a code) or
// join an existing one by code. Both route into the online flow.
import SwiftUI

struct FriendView: View {
    @ObservedObject var model: GameModel
    @State private var joinCode = ""
    @FocusState private var codeFocused: Bool

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Text("PLAY A FRIEND").font(.display(26)).foregroundStyle(Color(hex: "#d4ff3d"))
                .neonGlow(Color(hex: "#d4ff3d"), radius: 16)

            NeonButton(title: "CREATE A GAME", kind: .lime) { model.hostFriend() }
                .padding(.horizontal, 28)

            Text("— or join with a code —")
                .font(.body(13)).foregroundStyle(Color(hex: "#6a6496"))

            TextField("", text: $joinCode, prompt: Text("CODE").foregroundColor(Color(hex: "#6a6496")))
                .focused($codeFocused)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .multilineTextAlignment(.center)
                .font(.display(30))
                .foregroundStyle(.white)
                .tracking(6)
                .frame(height: 60)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "#14122a")))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#7b3bff").opacity(0.4), lineWidth: 1))
                .padding(.horizontal, 28)
                .onChange(of: joinCode) { _, v in joinCode = String(v.uppercased().prefix(4)) }

            NeonButton(title: "JOIN", kind: .cyan) {
                if joinCode.count >= 3 { model.joinFriend(joinCode) }
            }
            .padding(.horizontal, 28)

            NeonButton(title: "CANCEL", kind: .ghost) { model.route = .start }
                .padding(.horizontal, 28)
            Spacer()
        }
    }
}

// UIActivityViewController bridge for share sheets.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
