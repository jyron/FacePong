// FaceCutout.swift — turns a selfie into a head-only paddle texture.
//
// PRIMARY path: MODNet (a portrait-matting CNN, bundled as MODNetMatte.mlmodelc)
// produces a true alpha matte with hair-strand detail. We crop to the head first
// (Vision face rectangle) so the head fills MODNet's 512px frame at full
// resolution, then matte, then feather the sides/bottom into the dark court.
//
// FALLBACK path: Apple's VNGenerateForegroundInstanceMaskRequest (subject lift).
// Used only if the Core ML model can't load or run. NOTE: that request requires a
// real device. MODNet (Core ML) runs in the Simulator too, so the primary path is
// testable in the Simulator via FP_VISION_TEST=1.
//
// Usage:
//   let paddle = try await FaceCutout.cutout(from: selfieImage)

import UIKit
import Vision
import CoreML
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Error

/// Errors thrown by `FaceCutout.cutout(from:)`.
public enum FaceCutoutError: Error, CustomStringConvertible {
    /// No face was detected in the source image.
    case noFace
    /// Vision produced no foreground instance mask.
    case noForeground
    /// The MODNet Core ML model could not be loaded or run — caller falls back.
    case modelUnavailable
    /// A Vision request failed. The wrapped error carries the underlying cause.
    case visionFailed(Error)

    public var description: String {
        switch self {
        case .noFace:        return "FaceCutout: no face detected — prompt user to retake"
        case .noForeground:  return "FaceCutout: foreground instance mask unavailable (real device required)"
        case .modelUnavailable: return "FaceCutout: MODNet Core ML model unavailable — falling back"
        case .visionFailed(let e): return "FaceCutout: Vision request failed — \(e)"
        }
    }
}

// MARK: - Public API

/// Provides on-device face segmentation for FacePong's head-as-paddle mechanic.
public enum FaceCutout {

    /// Produces a ~512 px square, transparent-background UIImage of the largest
    /// detected face, head-focused and feathered on the bottom and sides so the
    /// silhouette dissolves into the dark court.
    ///
    /// Tries MODNet first (best edges, runs in Simulator + device). If the model
    /// is unavailable, falls back to Apple's subject-lift matte (device only).
    ///
    /// - Throws: `FaceCutoutError` on any failure. There is no silent fallback to
    ///   a placeholder; the caller must surface a retake prompt on error.
    public static func cutout(from image: UIImage) async throws -> UIImage {
        try await Task.detached(priority: .userInitiated) {
            do {
                return try _cutoutMODNet(from: image)
            } catch FaceCutoutError.modelUnavailable {
                NSLog("FaceCutout: MODNet unavailable, using Apple foreground mask")
                return try _cutoutApple(from: image)
            }
        }.value
    }
}

// MARK: - MODNet (cached model)

private enum MODNet {
    /// Loaded once, lazily. nil if the compiled model isn't in the bundle.
    static let vnModel: VNCoreMLModel? = {
        guard let url = Bundle.main.url(forResource: "MODNetMatte", withExtension: "mlmodelc") else {
            NSLog("FaceCutout: MODNetMatte.mlmodelc not found in bundle")
            return nil
        }
        let cfg = MLModelConfiguration()
        cfg.computeUnits = .all
        do {
            let model = try MLModel(contentsOf: url, configuration: cfg)
            return try VNCoreMLModel(for: model)
        } catch {
            NSLog("FaceCutout: failed to load MODNet — \(error)")
            return nil
        }
    }()
}

// MARK: - Primary implementation (MODNet, off main thread)

private func _cutoutMODNet(from image: UIImage) throws -> UIImage {
    guard let cgNorm = normalisedCGImage(from: image) else { throw FaceCutoutError.noFace }
    let W = CGFloat(cgNorm.width), H = CGFloat(cgNorm.height)

    // 1. Find the head to frame the crop. Distinguish two failure modes:
    //    - detection can't RUN (e.g. Simulator has no Vision inference context, or
    //      a transient infra error) → fall back to a centered crop rather than
    //      blocking a valid selfie;
    //    - detection runs but finds NO face → .noFace so the caller prompts a retake.
    let faceReq = VNDetectFaceRectanglesRequest()
    let handler = VNImageRequestHandler(cgImage: cgNorm, orientation: .up, options: [:])
    var detectionRan = true
    do { try handler.perform([faceReq]) } catch { detectionRan = false }

    // 2. Head-focused square crop (Vision bbox is normalised, bottom-left origin).
    let crop: CGRect
    if detectionRan {
        guard let face = (faceReq.results ?? []).max(by: {
            $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height
        }) else { throw FaceCutoutError.noFace }
        let fb = face.boundingBox
        let fx = fb.minX * W, fy = fb.minY * H, fw = fb.width * W, fh = fb.height * H
        let side = max(fw, fh) * 1.6
        let cx = fx + fw / 2
        let cy = (fy + fh / 2) + fh * 0.14        // nudge up toward the hair
        crop = CGRect(x: cx - side / 2, y: cy - side / 2, width: side, height: side)
    } else {
        // Centered square biased slightly toward the top (where a head usually sits).
        let side = min(W, H)
        crop = CGRect(x: W / 2 - side / 2, y: H * 0.55 - side / 2, width: side, height: side)
    }
    let side = crop.width

    let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    let original = CIImage(cgImage: cgNorm)
    // The head crop, translated to the origin. Out-of-bounds areas have no data.
    let headCI = original
        .cropped(to: crop)
        .transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
    let squareRect = CGRect(x: 0, y: 0, width: side, height: side)

    // 3. Render the square head to a CGImage to feed MODNet.
    guard let headCG = ciContext.createCGImage(headCI, from: squareRect) else {
        throw FaceCutoutError.modelUnavailable
    }

    // 4. Run MODNet → 512×512 grayscale alpha matte (white = keep).
    guard let vnModel = MODNet.vnModel else { throw FaceCutoutError.modelUnavailable }
    let req = VNCoreMLRequest(model: vnModel)
    req.imageCropAndScaleOption = .scaleFill       // square in → square out, no distortion
    let mh = VNImageRequestHandler(cgImage: headCG, orientation: .up, options: [:])
    do { try mh.perform([req]) } catch { throw FaceCutoutError.modelUnavailable }
    guard let obs = req.results?.first as? VNPixelBufferObservation else {
        throw FaceCutoutError.modelUnavailable
    }

    // 5. Apply the matte as alpha (scale the 512 matte back to the crop size).
    var matteCI = CIImage(cvPixelBuffer: obs.pixelBuffer)
    let me = matteCI.extent
    matteCI = matteCI.transformed(by: CGAffineTransform(scaleX: side / me.width, y: side / me.height))
    let masked = headCI.applyingFilter("CIBlendWithMask", parameters: [
        kCIInputBackgroundImageKey: CIImage.empty(),
        kCIInputMaskImageKey: matteCI,
    ])

    return try featherAndRender(masked, side: side, ctx: ciContext)
}

// MARK: - Fallback implementation (Apple subject lift, device only)

private func _cutoutApple(from image: UIImage) throws -> UIImage {
    guard let cgNorm = normalisedCGImage(from: image) else { throw FaceCutoutError.noFace }
    let W = CGFloat(cgNorm.width)
    let H = CGFloat(cgNorm.height)

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

    let faces = faceReq.results ?? []
    guard let maskObs = maskReq.results?.first else {
        throw FaceCutoutError.noForeground
    }
    guard let face = faces.max(by: {
        $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height
    }) else {
        throw FaceCutoutError.noFace
    }

    let maskPixelBuffer: CVPixelBuffer
    do {
        maskPixelBuffer = try maskObs.generateScaledMaskForImage(
            forInstances: maskObs.allInstances, from: handler)
    } catch {
        throw FaceCutoutError.visionFailed(error)
    }

    let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    let original = CIImage(cgImage: cgNorm)

    var maskCI = CIImage(cvPixelBuffer: maskPixelBuffer)
    let ms = maskCI.extent
    if ms.width != W || ms.height != H {
        maskCI = maskCI.transformed(
            by: CGAffineTransform(scaleX: W / ms.width, y: H / ms.height))
    }

    let masked = original.applyingFilter("CIBlendWithMask", parameters: [
        kCIInputBackgroundImageKey: CIImage.empty(),
        kCIInputMaskImageKey: maskCI,
    ])

    let fb = face.boundingBox
    let fx = fb.minX * W
    let fy = fb.minY * H
    let fw = fb.width  * W
    let fh = fb.height * H

    let side = max(fw, fh) * 1.6
    let cx = fx + fw / 2
    let cy = (fy + fh / 2) + fh * 0.14
    let crop = CGRect(x: cx - side / 2, y: cy - side / 2, width: side, height: side)

    let cropped = masked
        .cropped(to: crop)
        .transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))

    return try featherAndRender(cropped, side: side, ctx: ciContext)
}

// MARK: - Shared tail: feather + scale to 512

/// Feathers the sides+bottom of a `side`×`side` masked head and renders it to a
/// 512 px square UIImage. The top edge stays crisp (the hair is already matted).
private func featherAndRender(_ headImg: CIImage, side: CGFloat, ctx: CIContext) throws -> UIImage {
    let featherCG = makeFeatherMask(side: side, feather: side * 0.13)
    let featherCI = CIImage(cgImage: featherCG)
    let feathered = headImg.applyingFilter("CIBlendWithMask", parameters: [
        kCIInputBackgroundImageKey: CIImage.empty(),
        kCIInputMaskImageKey: featherCI,
    ])

    let outputSize: CGFloat = 512
    let scale = outputSize / side
    let scaled = feathered.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    let outputRect = CGRect(x: 0, y: 0, width: outputSize, height: outputSize)

    guard let outCG = ctx.createCGImage(scaled, from: outputRect) else {
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

    ctx.translateBy(x: 0, y: CGFloat(h))
    ctx.scaleBy(x: 1, y: -1)
    UIGraphicsPushContext(ctx)
    image.draw(in: CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))
    UIGraphicsPopContext()
    return ctx.makeImage()
}

/// Builds a grayscale CGImage (white = keep, black = fade) with linear gradients
/// fading the left, right, and bottom edges to black within `feather` points.
/// The top edge stays fully white (crisp).
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

    ctx.drawLinearGradient(grad(),
                           start: CGPoint(x: 0,            y: side / 2),
                           end:   CGPoint(x: feather,      y: side / 2),
                           options: opts)
    ctx.drawLinearGradient(grad(),
                           start: CGPoint(x: side,         y: side / 2),
                           end:   CGPoint(x: side - feather, y: side / 2),
                           options: opts)
    ctx.drawLinearGradient(grad(),
                           start: CGPoint(x: side / 2, y: 0),
                           end:   CGPoint(x: side / 2, y: feather),
                           options: opts)

    return ctx.makeImage()!
}
