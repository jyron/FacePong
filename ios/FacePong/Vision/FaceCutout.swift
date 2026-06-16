// FaceCutout.swift — turns a selfie into a head paddle texture.
//
// The MODNet portrait-matting model (Core ML, bundled as MODNetMatte.mlmodelc)
// does ALL the work. There is no face detection, no feathering, and no fallback:
//
//   PASS 1 — matte the whole photo to locate the subject. The matte's own bounding
//            box frames the crop (NOT a hardcoded face rectangle), so nothing real
//            — beard, jaw, hair — gets clipped.
//   PASS 2 — re-matte that crop at full 512px resolution for crisp edges, then
//            composite the matte straight onto a transparent square. The matte's
//            soft alpha (hair/beard strands) IS the edge — we don't feather it.
//
// If the model is missing or fails, cutout() THROWS. No silent fallback — so a
// bad result always means the model, never a hidden code path.
//
// Usage:
//   let paddle = try await FaceCutout.cutout(from: selfieImage)

import UIKit
import Vision
import CoreML
import CoreImage

// MARK: - Error

/// Errors thrown by `FaceCutout.cutout(from:)`.
public enum FaceCutoutError: Error, CustomStringConvertible {
    /// The MODNet Core ML model could not be loaded or run.
    case modelUnavailable
    /// The matte found no subject (empty photo / nothing salient).
    case noSubject
    /// A Core Image render step failed.
    case renderFailed

    public var description: String {
        switch self {
        case .modelUnavailable: return "FaceCutout: MODNet model unavailable or inference failed"
        case .noSubject:        return "FaceCutout: matte found no subject — prompt user to retake"
        case .renderFailed:     return "FaceCutout: Core Image render failed"
        }
    }
}

// MARK: - Public API

/// On-device portrait matting for FacePong's head-as-paddle mechanic.
public enum FaceCutout {

    /// Produces a 512 px square, transparent-background UIImage of the matted
    /// subject, framed by the matte itself (full beard/hair preserved).
    ///
    /// - Throws: `FaceCutoutError` on any failure. No fallback — the caller
    ///   surfaces a retake prompt.
    public static func cutout(from image: UIImage) async throws -> UIImage {
        try await Task.detached(priority: .userInitiated) {
            try _cutout(from: image)
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
            return try VNCoreMLModel(for: try MLModel(contentsOf: url, configuration: cfg))
        } catch {
            NSLog("FaceCutout: failed to load MODNet — \(error)")
            return nil
        }
    }()
}

// MARK: - Implementation (off main thread)

private func _cutout(from image: UIImage) throws -> UIImage {
    guard let vnModel = MODNet.vnModel else { throw FaceCutoutError.modelUnavailable }
    guard let cgNorm = normalisedCGImage(from: image) else { throw FaceCutoutError.renderFailed }
    let W = CGFloat(cgNorm.width), H = CGFloat(cgNorm.height)
    let ctx = CIContext(options: [.useSoftwareRenderer: false])

    // PASS 1 — matte the whole photo, then let the matte frame the crop.
    let matte1 = try runMODNet(vnModel, on: cgNorm, ctx: ctx)
    guard let bbox = subjectBoundingBox(matte1, threshold: 24) else { throw FaceCutoutError.noSubject }

    // Expand a touch for breathing room, clamp to the image (top-left, normalised).
    let m: CGFloat = 0.05
    let bx = max(0, bbox.minX - m), by = max(0, bbox.minY - m)
    let bw = min(1 - bx, bbox.width + m * 2), bh = min(1 - by, bbox.height + m * 2)
    let cropRect = CGRect(x: floor(bx * W), y: floor(by * H),
                          width: ceil(bw * W), height: ceil(bh * H))
    guard cropRect.width >= 1, cropRect.height >= 1,
          let headCG = cgNorm.cropping(to: cropRect) else { throw FaceCutoutError.noSubject }

    // PASS 2 — re-matte the crop at full resolution for crisp beard/hair edges.
    let matte2 = try runMODNet(vnModel, on: headCG, ctx: ctx)
    let hw = CGFloat(headCG.width), hh = CGFloat(headCG.height)
    let headCI = CIImage(cgImage: headCG)
    // Scale the 512 matte back to the crop's exact dimensions (this inverts the
    // model's scaleFill, so the matte lines up pixel-for-pixel — no distortion).
    let me = CIImage(cgImage: matte2).extent
    let matteCI = CIImage(cgImage: matte2)
        .transformed(by: CGAffineTransform(scaleX: hw / me.width, y: hh / me.height))

    // Composite: the matte IS the alpha. No feather.
    let masked = headCI.applyingFilter("CIBlendWithMask", parameters: [
        kCIInputBackgroundImageKey: CIImage.empty(),
        kCIInputMaskImageKey: matteCI,
    ])

    // Center the matted subject on a transparent square and scale to 512.
    let side = max(hw, hh)
    let centered = masked.transformed(
        by: CGAffineTransform(translationX: (side - hw) / 2, y: (side - hh) / 2))
    let outSize: CGFloat = 512
    let scaled = centered.transformed(by: CGAffineTransform(scaleX: outSize / side, y: outSize / side))

    guard let outCG = ctx.createCGImage(scaled, from: CGRect(x: 0, y: 0, width: outSize, height: outSize)) else {
        throw FaceCutoutError.renderFailed
    }
    return UIImage(cgImage: outCG)
}

// MARK: - MODNet inference

/// Runs MODNet on a CGImage and returns the raw 512×512 grayscale matte
/// (white = keep). The caller scales it to the input's dimensions.
private func runMODNet(_ model: VNCoreMLModel, on cg: CGImage, ctx: CIContext) throws -> CGImage {
    let req = VNCoreMLRequest(model: model)
    req.imageCropAndScaleOption = .scaleFill
    let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
    do { try handler.perform([req]) } catch { throw FaceCutoutError.modelUnavailable }
    guard let obs = req.results?.first as? VNPixelBufferObservation else {
        throw FaceCutoutError.modelUnavailable
    }
    let ci = CIImage(cvPixelBuffer: obs.pixelBuffer)
    guard let out = ctx.createCGImage(ci, from: ci.extent) else { throw FaceCutoutError.renderFailed }
    return out
}

// MARK: - Helpers

/// Bounding box (normalised, top-left origin) of the matte's foreground —
/// every pixel brighter than `threshold`. nil if nothing crosses it.
private func subjectBoundingBox(_ cg: CGImage, threshold: UInt8) -> CGRect? {
    let w = cg.width, h = cg.height
    guard w > 0, h > 0 else { return nil }
    var buf = [UInt8](repeating: 0, count: w * h)
    let cs = CGColorSpaceCreateDeviceGray()
    guard let c = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8,
                            bytesPerRow: w, space: cs,
                            bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
    // Flip so buffer row 0 is the TOP of the image (top-left scan order).
    c.translateBy(x: 0, y: CGFloat(h)); c.scaleBy(x: 1, y: -1)
    c.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

    var minX = w, minY = h, maxX = -1, maxY = -1
    for y in 0..<h {
        let row = y * w
        for x in 0..<w where buf[row + x] > threshold {
            if x < minX { minX = x }
            if x > maxX { maxX = x }
            if y < minY { minY = y }
            if y > maxY { maxY = y }
        }
    }
    guard maxX >= 0 else { return nil }
    return CGRect(x: CGFloat(minX) / CGFloat(w),
                  y: CGFloat(minY) / CGFloat(h),
                  width: CGFloat(maxX - minX + 1) / CGFloat(w),
                  height: CGFloat(maxY - minY + 1) / CGFloat(h))
}

/// Draws the UIImage into a new RGBA CGContext to bake any orientation transform
/// into the pixel data, returning a `.up`-oriented CGImage.
private func normalisedCGImage(from image: UIImage) -> CGImage? {
    let size = image.size
    guard size.width > 0, size.height > 0 else { return nil }
    let w = Int(size.width), h = Int(size.height)
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
