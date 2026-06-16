// StartView.swift — the menu: title, "your face is the paddle" pill, two face
// cards (tap to set your face via camera/library → Vision cutout), the three
// mode buttons, and the longest-rally best.
import SwiftUI
import UIKit

extension FacePickerSource: Identifiable {
    public var id: Int { self == .camera ? 0 : 1 }
}

struct StartView: View {
    @ObservedObject var model: GameModel
    @State private var pickingSlot: Slot = .p1
    @State private var showSource = false
    @State private var source: FacePickerSource?

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 12)

            VStack(spacing: -6) {
                Text("FACE").font(.display(56)).foregroundStyle(Color(hex: "#19e7ff")).neonGlow(Color(hex: "#19e7ff"), radius: 22, strong: true)
                Text("PONG").font(.display(56)).foregroundStyle(Color(hex: "#ff2e88")).neonGlow(Color(hex: "#ff2e88"), radius: 22, strong: true)
            }

            NeonPill(text: "🏓  5 HEARTS · YOUR FACE IS THE PADDLE")

            HStack(spacing: 18) {
                faceColumn(.p1)
                Circle().fill(Color(hex: "#d4ff3d")).frame(width: 16, height: 16)
                    .neonGlow(Color(hex: "#d4ff3d"), radius: 10)
                faceColumn(.p2)
            }
            .padding(.vertical, 8)

            VStack(spacing: 14) {
                NeonButton(title: "QUICK MATCH", kind: .lime) { model.quickMatch() }
                NeonButton(title: "PLAY A FRIEND", kind: .cyan) { model.route = .friend }
                NeonButton(title: "VS COMPUTER", kind: .ghost) { model.startCPU() }
            }
            .padding(.horizontal, 28)

            HStack(spacing: 6) {
                Text("Longest rally").font(.body(13)).foregroundStyle(Color(hex: "#6a6496"))
                Text("\(model.longestRally)").font(.bodyBold(14)).foregroundStyle(Color(hex: "#ffb02e"))
            }
            Spacer(minLength: 8)
        }
        .padding(.top, 30)
        .overlay { if model.processingFace { ProcessingOverlay() } }
        .confirmationDialog("Set \(pickingSlot == .p1 ? "your" : "the opponent's") face",
                            isPresented: $showSource, titleVisibility: .visible) {
            // Only offer the camera when one is actually available (it isn't on the
            // Simulator / Mac / camera-restricted review devices).
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take a selfie") { source = .camera }
            }
            Button("Choose a photo") { source = .library }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(item: $source) { src in
            FacePickerSheet(source: src) { img in
                source = nil
                process(img, for: pickingSlot)
            }
            .ignoresSafeArea()
        }
        .alert("No face found", isPresented: Binding(get: { model.pickError != nil }, set: { _ in model.pickError = nil })) {
            Button("OK", role: .cancel) {}
        } message: { Text(model.pickError ?? "") }
    }

    @ViewBuilder private func faceColumn(_ slot: Slot) -> some View {
        VStack(spacing: 8) {
            FaceCard(image: slot == .p1 ? model.p1Face : model.p2Face, slot: slot, size: 112)
                .onTapGesture { pickingSlot = slot; showSource = true }
            Text((slot == .p1 ? model.p1Face : model.p2Face) == nil ? "tap to add your face" : "tap to change")
                .font(.body(11)).foregroundStyle(Color(hex: "#6a6496"))
        }
    }

    private func process(_ img: UIImage, for slot: Slot) {
        model.processingFace = true
        Task {
            do {
                let cut = try await FaceCutout.cutout(from: img)
                model.setFace(slot, cut)
            } catch {
                model.pickError = "Couldn't find a face in that photo. Try again with your face centered."
            }
            model.processingFace = false
        }
    }
}

struct ProcessingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().tint(Color(hex: "#19e7ff")).scaleEffect(1.4)
                Text("CUTTING OUT YOUR FACE…").font(.bodyBold(12)).tracking(1.5)
                    .foregroundStyle(Color(hex: "#a59fce"))
            }
        }
    }
}
