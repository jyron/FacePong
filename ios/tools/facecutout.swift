// facecutout.swift — macOS test harness for FacePong's Apple Vision face-extraction.
//
// Mirrors EXACTLY what the iOS app will do, but runs on the Mac (where Vision's
// foreground-instance-mask request IS available — it is NOT on the iOS Simulator).
// Used to visually verify cutout quality on real faces before wiring it into the app.
//
// Build:  swiftc -O facecutout.swift -o facecutout \
//             -framework Vision -framework CoreImage -framework AppKit
// Run:    ./facecutout input.jpg out_prefix
//   -> writes  out_prefix_cutout.png  (square head cutout, transparent bg = the paddle)
//              out_prefix_matte.png   (full person cutout, for matte-quality inspection)

import Foundation
import Vision
import CoreImage
import AppKit

func die(_ msg: String) -> Never { FileHandle.standardError.write((msg + "\n").data(using: .utf8)!); exit(1) }

// Grayscale feather mask: white (keep) everywhere except a smooth fade to black
// within `feather` px of the LEFT, RIGHT and BOTTOM edges. Top stays crisp.
// .darken blending across the three edge gradients yields the per-pixel min,
// so corners fade correctly. (CGContext origin is bottom-left → y=0 is bottom.)
func makeFeatherMask(side: CGFloat, feather f: CGFloat) -> CGImage {
    let w = Int(side), h = Int(side)
    let cs = CGColorSpaceCreateDeviceGray()
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: cs, bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    ctx.setFillColor(gray: 1, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
    ctx.setBlendMode(.darken)
    let black = CGColor(gray: 0, alpha: 1), white = CGColor(gray: 1, alpha: 1)
    func grad() -> CGGradient { CGGradient(colorsSpace: cs, colors: [black, white] as CFArray, locations: [0, 1])! }
    let opts: CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    // left edge
    ctx.drawLinearGradient(grad(), start: CGPoint(x: 0, y: side / 2), end: CGPoint(x: f, y: side / 2), options: opts)
    // right edge
    ctx.drawLinearGradient(grad(), start: CGPoint(x: side, y: side / 2), end: CGPoint(x: side - f, y: side / 2), options: opts)
    // bottom edge
    ctx.drawLinearGradient(grad(), start: CGPoint(x: side / 2, y: 0), end: CGPoint(x: side / 2, y: f), options: opts)
    return ctx.makeImage()!
}

guard CommandLine.arguments.count >= 3 else { die("usage: facecutout <input> <out_prefix>") }
let inPath = CommandLine.arguments[1]
let outPrefix = CommandLine.arguments[2]

guard let nsImage = NSImage(contentsOfFile: inPath),
      let cg = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    die("could not load image: \(inPath)")
}
let W = CGFloat(cg.width), H = CGFloat(cg.height)
print("image: \(Int(W))x\(Int(H))")

let ciContext = CIContext(options: [.useSoftwareRenderer: false])
let original = CIImage(cgImage: cg)

let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])

// 1) Face rectangle — to frame the HEAD (not the whole torso) as the paddle.
let faceReq = VNDetectFaceRectanglesRequest()
// 2) Foreground instance mask — Apple's high-quality matte (hair detail, clean edges).
guard #available(macOS 14.0, *) else { die("needs macOS 14+") }
let maskReq = VNGenerateForegroundInstanceMaskRequest()

do { try handler.perform([faceReq, maskReq]) }
catch { die("vision perform failed: \(error)") }

let faces = (faceReq.results ?? [])
print("faces detected: \(faces.count)")
guard let maskObs = maskReq.results?.first else { die("no foreground instances found") }
print("foreground instances: \(maskObs.allInstances.count)")

// Generate the scaled grayscale mask (white = foreground) at full image resolution.
let maskPixelBuffer: CVPixelBuffer
do { maskPixelBuffer = try maskObs.generateScaledMaskForImage(forInstances: maskObs.allInstances, from: handler) }
catch { die("generateScaledMaskForImage failed: \(error)") }
var maskCI = CIImage(cvPixelBuffer: maskPixelBuffer)
// Scale mask to exactly match the original image extent (it can differ slightly).
let ms = maskCI.extent
if ms.width != W || ms.height != H {
    maskCI = maskCI.transformed(by: CGAffineTransform(scaleX: W / ms.width, y: H / ms.height))
}

// Apply the matte as the alpha channel: foreground kept, background -> transparent.
let masked = original.applyingFilter("CIBlendWithMask", parameters: [
    kCIInputBackgroundImageKey: CIImage.empty(),
    kCIInputMaskImageKey: maskCI,
])

func writePNG(_ image: CIImage, rect: CGRect, to path: String) {
    guard let out = ciContext.createCGImage(image, from: rect) else { die("render failed: \(path)") }
    let rep = NSBitmapImageRep(cgImage: out)
    guard let data = rep.representation(using: .png, properties: [:]) else { die("png encode failed: \(path)") }
    try? data.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)  (\(out.width)x\(out.height))")
}

// Full person cutout (matte inspection).
writePNG(masked, rect: original.extent, to: "\(outPrefix)_matte.png")

// Square HEAD crop, framed off the detected face box (CIImage + Vision are both
// bottom-left origin, so normalized coords map directly).
if let face = faces.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }) {
    let fb = face.boundingBox
    let fx = fb.minX * W, fy = fb.minY * H, fw = fb.width * W, fh = fb.height * H
    print("face box (px): x=\(Int(fx)) y=\(Int(fy)) w=\(Int(fw)) h=\(Int(fh))")
    let cx = fx + fw / 2
    let faceCenterY = fy + fh / 2
    // Head-focused square (face box ~ the face; head+a little shoulder ≈ 1.6x);
    // nudge up toward hair (+y is up in CIImage space).
    let side = max(fw, fh) * 1.6
    let cy = faceCenterY + fh * 0.14
    let crop = CGRect(x: cx - side / 2, y: cy - side / 2, width: side, height: side)
    // Crop, then translate to origin so the PNG is a clean square (out-of-bounds = transparent).
    let cropped = masked.cropped(to: crop).transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
    let squareRect = CGRect(x: 0, y: 0, width: side, height: side)

    // Feather the bottom + side edges (crisp at top) so the silhouette FADES into
    // the dark court instead of reading as a hard rectangular card — exactly the
    // trick the original segment.ts used. This is what makes the neon aura hug
    // the head outline rather than outlining a square.
    let featherCI = CIImage(cgImage: makeFeatherMask(side: side, feather: side * 0.13))
    let headImg = cropped.applyingFilter("CIBlendWithMask", parameters: [
        kCIInputBackgroundImageKey: CIImage.empty(),
        kCIInputMaskImageKey: featherCI,
    ])
    writePNG(headImg, rect: squareRect, to: "\(outPrefix)_cutout.png")

    // Composite over the actual near-black neon court (#07070f) to check the look.
    let court = CIImage(color: CIColor(red: 0x07/255.0, green: 0x07/255.0, blue: 0x0f/255.0)).cropped(to: squareRect)
    let onCourt = headImg.composited(over: court)
    writePNG(onCourt, rect: squareRect, to: "\(outPrefix)_oncourt.png")
} else {
    print("no face detected — would prompt user to retake (no silent fallback)")
}
