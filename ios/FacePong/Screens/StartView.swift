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

            NeonPill(text: "🏓  YOUR FACE IS THE PADDLE")

            faceColumn(.p1)
                .padding(.vertical, 6)

            HeartChip(hearts: model.hearts, onTap: { model.openStore() })

            VStack(spacing: 14) {
                NeonButton(title: "VS COMPUTER", kind: .lime) { model.route = .characters }
                NeonButton(title: "QUICK MATCH", kind: .cyan) { model.quickMatch() }
                NeonButton(title: "PLAY A FRIEND", kind: .ghost) { model.route = .friend }
            }
            .padding(.horizontal, 28)

            HStack(spacing: 18) {
                stat("RIVALS BEATEN", "\(model.rivalsBeatenCount)/\(Rival.roster.count)", Color(hex: "#d4ff3d"))
                stat("LONGEST RALLY", "\(model.longestRally)", Color(hex: "#ffb02e"))
            }
            Spacer(minLength: 8)
        }
        .padding(.top, 30)
        .overlay(alignment: .topTrailing) { MuteButton().padding(.trailing, 16).padding(.top, 6) }
        .overlay(alignment: .topLeading) {
            Text(buildLabel).font(.body(10)).tracking(1).foregroundStyle(Color(hex: "#6a6496"))
                .padding(.leading, 16).padding(.top, 16)
        }
        .overlay { if model.processingFace { ProcessingOverlay() } }
        .confirmationDialog("Set your face",
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

    /// Version + build (from the bundle, so it always matches the uploaded build) — shown on the
    /// home screen so each TestFlight build is identifiable at a glance.
    private var buildLabel: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "v\(v) · BUILD \(b)"
    }

    @ViewBuilder private func stat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.bodyBold(16)).foregroundStyle(color)
            Text(label).font(.body(10)).tracking(1).foregroundStyle(Color(hex: "#6a6496"))
        }
    }

    @ViewBuilder private func faceColumn(_ slot: Slot) -> some View {
        VStack(spacing: 10) {
            FaceCard(image: model.p1Face, slot: slot, size: 150)
                .onTapGesture { pickingSlot = slot; showSource = true }
            Text(model.p1Face == nil ? "TAP TO ADD YOUR FACE" : "tap to change your face")
                .font(.bodyBold(12)).tracking(1).foregroundStyle(Color(hex: "#a59fce"))
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
