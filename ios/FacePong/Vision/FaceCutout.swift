// FaceCutout.swift — ported from tools/facecutout.swift (macOS harness).
//
// Runs Apple Vision's face-rectangle detection and foreground-instance-mask
// request to produce a square, feathered head cutout suitable for use as an
// SKSpriteNode texture (the paddle).
//
// NOTE: VNGenerateForegroundInstanceMaskRequest requires a real device; it is
// not available in the iOS Simulator and will throw there. That is expected.
//
// Usage:
//   let paddle = try await FaceCutout.cutout(from: selfieImage)

import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Error

/// Errors thrown by `FaceCutout.cutout(from:)`.
public enum FaceCutoutError: Error, CustomStringConvertible {
    /// No face was detected in the source image.
    case noFace
    /// Vision produced no foreground instance mask.
    case noForeground
    /// A Vision request failed. The wrapped error carries the underlying cause.
    case visionFailed(Error)

    public var description: String {
        switch self {
        case .noFace:        return "FaceCutout: no face detected — prompt user to retake"
        case .noForeground:  return "FaceCutout: foreground instance mask unavailable (real device required)"
        case .visionFailed(let e): return "FaceCutout: Vision request failed — \(e)"
        }
    }
}

// MARK: - Public API

/// Provides on-device face segmentation for FacePong's head-as-paddle mechanic.
public enum FaceCutout {

    /// Produces a ~512 px square, transparent-background UIImage of the
    /// largest detected face, head-focused and feathered on the bottom and
    /// sides so the silhouette dissolves into the dark court.
    ///
    /// - Parameter image: A UIImage from the camera or photo library.
    ///   Any orientation is accepted; it is normalised to `.up` internally.
    /// - Returns: A square UIImage with a transparent background, ready to
    ///   pass to `SKTexture(image:)`.
    /// - Throws: `FaceCutoutError` on any failure. There is no silent fallback;
    ///   the caller must surface a retake prompt on error.
    public static func cutout(from image: UIImage) async throws -> UIImage {
        try await Task.detached(priority: .userInitiated) {
            try _cutout(from: image)
        }.value
    }
}

// MARK: - Implementation (off main thread)

private func _cutout(from image: UIImage) throws -> UIImage {
    // 1. Normalise orientation — Vision expects the pixel data to read top-left.
    //    Drawing into a new CGContext bakes the UIImage orientation transforms in.
    guard let cgNorm = normalisedCGImage(from: image) else {
        throw FaceCutoutError.noFace  // can't decode → nothing to work with
    }
    let W = CGFloat(cgNorm.width)
    let H = CGFloat(cgNorm.height)

    // 2. Build Vision requests.
    let faceReq = VNDetectFaceRectanglesRequest()
    guard #available(iOS 17.0, *) else {
        throw FaceCutoutError.visionFailed(
            NSError(domain: "FaceCutout", code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "iOS 17+ required for VNGenerateForegroundInstanceMaskRequest"])
        )
    }
    let maskReq = VNGenerateForegroundInstanceMaskRequest()

    let handler = VNImageRequestHandler(cgImage: cgNorm, orientation: .up, options: [:])
    do {
        try handler.perform([faceReq, maskReq])
    } catch {
        throw FaceCutoutError.visionFailed(error)
    }

    // 3. Extract results — throw on missing data; no silent fallback.
    let faces = faceReq.results ?? []
    guard let maskObs = maskReq.results?.first else {
        throw FaceCutoutError.noForeground
    }
    guard let face = faces.max(by: {
        $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height
    }) else {
        throw FaceCutoutError.noFace
    }

    // 4. Generate the scaled foreground matte (white = foreground, black = bg).
    let maskPixelBuffer: CVPixelBuffer
    do {
        maskPixelBuffer = try maskObs.generateScaledMaskForImage(
            forInstances: maskObs.allInstances, from: handler)
    } catch {
        throw FaceCutoutError.visionFailed(error)
    }

    // 5. Build CIImage pipeline.
    //    CIImage + Vision both use bottom-left origin, so normalised Vision coords
    //    map directly to CIImage pixel coords after multiplying by image dimensions.
    let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    let original = CIImage(cgImage: cgNorm)

    var maskCI = CIImage(cvPixelBuffer: maskPixelBuffer)
    // Scale mask to exactly match the original extent (can differ by a pixel).
    let ms = maskCI.extent
    if ms.width != W || ms.height != H {
        maskCI = maskCI.transformed(
            by: CGAffineTransform(scaleX: W / ms.width, y: H / ms.height))
    }

    // Apply the matte as alpha: foreground preserved, background → transparent.
    let masked = original.applyingFilter("CIBlendWithMask", parameters: [
        kCIInputBackgroundImageKey: CIImage.empty(),
        kCIInputMaskImageKey: maskCI,
    ])

    // 6. Compute head-focused square crop (same multipliers as the macOS tool).
    //    Vision bounding box is normalised, bottom-left origin — convert to pixels.
    let fb = face.boundingBox
    let fx = fb.minX * W
    let fy = fb.minY * H
    let fw = fb.width  * W
    let fh = fb.height * H

    // Square side: face box covers roughly the face; head + a bit of shoulder ≈ 1.6×.
    let side = max(fw, fh) * 1.6
    // Centre horizontally on the face; nudge up toward hair (+y = up in CIImage).
    let cx = fx + fw / 2
    let cy = (fy + fh / 2) + fh * 0.14
    let crop = CGRect(x: cx - side / 2, y: cy - side / 2, width: side, height: side)

    // Crop and translate to origin (out-of-bounds areas become transparent).
    let cropped = masked
        .cropped(to: crop)
        .transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
    let squareRect = CGRect(x: 0, y: 0, width: side, height: side)

    // 7. Feather mask: bottom + sides fade to black, top stays crisp.
    //    Blending the three linear gradients with .darken gives per-pixel min so
    //    corners fade correctly. feather = side * 0.13 (matches macOS tool).
    let featherCG = makeFeatherMask(side: side, feather: side * 0.13)
    let featherCI = CIImage(cgImage: featherCG)
    let headImg = cropped.applyingFilter("CIBlendWithMask", parameters: [
        kCIInputBackgroundImageKey: CIImage.empty(),
        kCIInputMaskImageKey: featherCI,
    ])

    // 8. Scale to the desired output size (~512 px) and render to UIImage.
    let outputSize: CGFloat = 512
    let scale = outputSize / side
    let scaled = headImg.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    let outputRect = CGRect(x: 0, y: 0, width: outputSize, height: outputSize)

    guard let outCG = ciContext.createCGImage(scaled, from: outputRect) else {
        throw FaceCutoutError.visionFailed(
            NSError(domain: "FaceCutout", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "CIContext render failed"]))
    }
    return UIImage(cgImage: outCG)
}

// MARK: - Helpers

/// Draws the UIImage into a new RGBA CGContext to bake any orientation
/// transform into the pixel data, returning a `.up`-oriented CGImage.
private func normalisedCGImage(from image: UIImage) -> CGImage? {
    let size = image.size
    guard size.width > 0, size.height > 0 else { return nil }
    let w = Int(size.width)
    let h = Int(size.height)
    let space = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil, width: w, height: h,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    // UIKit coordinate system: origin top-left; flip to draw correctly.
    ctx.translateBy(x: 0, y: CGFloat(h))
    ctx.scaleBy(x: 1, y: -1)
    UIGraphicsPushContext(ctx)
    image.draw(in: CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))
    UIGraphicsPopContext()
    return ctx.makeImage()
}

/// Builds a grayscale CGImage (white = keep, black = fade) with linear gradients
/// fading the left, right, and bottom edges to black within `feather` points.
/// The top edge stays fully white (crisp). `.darken` blend mode means the three
/// gradients compete and the darkest wins — corners fade correctly without
/// multiplying two separate passes.
///
/// - Parameters:
///   - side: The pixel dimension of the square mask.
///   - feather: The width of the fade region on the left, right, and bottom edges.
private func makeFeatherMask(side: CGFloat, feather: CGFloat) -> CGImage {
    let w = Int(side)
    let h = Int(side)
    let cs = CGColorSpaceCreateDeviceGray()
    let ctx = CGContext(
        data: nil, width: w, height: h,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.none.rawValue
    )!

    // Fill solid white (full opacity).
    ctx.setFillColor(gray: 1, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))

    ctx.setBlendMode(.darken)
    let black = CGColor(gray: 0, alpha: 1)
    let white = CGColor(gray: 1, alpha: 1)
    let opts: CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]

    func grad() -> CGGradient {
        CGGradient(colorsSpace: cs,
                   colors: [black, white] as CFArray,
                   locations: [0, 1])!
    }

    // Left edge: black at x=0, white at x=feather.
    ctx.drawLinearGradient(grad(),
                           start: CGPoint(x: 0,            y: side / 2),
                           end:   CGPoint(x: feather,      y: side / 2),
                           options: opts)
    // Right edge: black at x=side, white at x=side-feather.
    ctx.drawLinearGradient(grad(),
                           start: CGPoint(x: side,         y: side / 2),
                           end:   CGPoint(x: side - feather, y: side / 2),
                           options: opts)
    // Bottom edge: black at y=0, white at y=feather.
    // (CGContext origin is bottom-left, so y=0 is the visual bottom.)
    ctx.drawLinearGradient(grad(),
                           start: CGPoint(x: side / 2, y: 0),
                           end:   CGPoint(x: side / 2, y: feather),
                           options: opts)

    return ctx.makeImage()!
}
