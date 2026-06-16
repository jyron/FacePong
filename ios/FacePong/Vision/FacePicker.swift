// FacePicker.swift — SwiftUI-presentable face image source.
//
// Wraps UIImagePickerController (front camera) and PHPickerViewController
// (photo library) as UIViewControllerRepresentable views.
//
// Usage — present from any SwiftUI view:
//
//   .sheet(isPresented: $showCamera) {
//       FacePickerSheet(source: .camera) { raw in
//           Task { paddle = try await FaceCutout.cutout(from: raw) }
//       }
//   }
//
// The sheet just returns the raw UIImage. The caller is responsible for
// running FaceCutout.cutout(from:) and handling errors / retake prompts.

import SwiftUI
import UIKit
import PhotosUI

// MARK: - Source

/// Selects the image acquisition method shown by `FacePickerSheet`.
public enum FacePickerSource {
    /// Front-facing camera with edit crop (UIImagePickerController).
    case camera
    /// System photo library single-image picker (PHPickerViewController).
    case library
}

// MARK: - FacePickerSheet

/// A self-contained SwiftUI view that presents the appropriate system picker
/// and calls `onPicked` with the raw UIImage when the user confirms.
/// Dismiss is handled internally; embed in `.sheet` or `.fullScreenCover`.
public struct FacePickerSheet: View {
    public let source: FacePickerSource
    public let onPicked: (UIImage) -> Void

    public init(source: FacePickerSource, onPicked: @escaping (UIImage) -> Void) {
        self.source = source
        self.onPicked = onPicked
    }

    public var body: some View {
        switch source {
        case .camera:
            CameraPickerView(onPicked: onPicked)
                .ignoresSafeArea()
        case .library:
            LibraryPickerView(onPicked: onPicked)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Camera (UIImagePickerController, front camera)

/// UIViewControllerRepresentable for the front-facing camera.
/// `allowsEditing: true` gives the system crop UI so the user frames their face.
private struct CameraPickerView: UIViewControllerRepresentable {
    let onPicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        // Guard camera availability: presenting sourceType = .camera on a device with
        // no available camera (Simulator, "iPhone app on Mac", or a restricted review
        // device) throws NSInvalidArgumentException and crashes the app — the App Store
        // reviewer hits this the moment they try to add a face. Fall back to the library.
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraDevice = .front
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject,
                              UIImagePickerControllerDelegate,
                              UINavigationControllerDelegate {
        private let parent: CameraPickerView

        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            // Prefer the edited crop; fall back to the original.
            let image = (info[.editedImage] as? UIImage)
                     ?? (info[.originalImage] as? UIImage)
            parent.dismiss()
            if let image { parent.onPicked(image) }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Library (PHPickerViewController)

/// UIViewControllerRepresentable for the system photo library.
/// Filters to images, single selection.
private struct LibraryPickerView: UIViewControllerRepresentable {
    let onPicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: LibraryPickerView

        init(_ parent: LibraryPickerView) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            guard let result = results.first else { return }
            guard result.itemProvider.canLoadObject(ofClass: UIImage.self) else { return }
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let self, let image = object as? UIImage else { return }
                DispatchQueue.main.async { self.parent.onPicked(image) }
            }
        }
    }
}
