// FaceHead3D.swift — turns a flat 2D face cutout into a disembodied, floating 3D
// head (the "Rick & Morty giant head" look) rendered with SceneKit inside the
// SpriteKit court.
//
// How it gets 3D out of a single photo (no ML, works on ANY image):
//   1. Sample the cutout's alpha (the head silhouette) + luminance into a grid.
//   2. DISTANCE TRANSFORM the silhouette → for every interior point, how far it is
//      from the edge. That field, shaped into a hemisphere profile, INFLATES the flat
//      silhouette into a rounded dome that follows the head's actual outline (the
//      "puffy sticker" trick). The face photo maps onto this bulging front.
//   3. A second, darker shell is inflated backward to close the head into a solid,
//      rounded form. Front + back meet at the silhouette (inflation → 0 at the edge).
//   4. Light it, give it a neon rim, and frame it with a perspective camera so it
//      reads as a real head floating off the screen.
import SceneKit
import SpriteKit
import UIKit
import simd

enum FaceHead3D {

    struct Built {
        let scene: SCNScene
        let head: SCNNode     // animate this node (idle float + impact lunge)
        let camera: SCNNode
    }

    // ---- tunables ----
    private static let gridN = 76          // mesh resolution per axis
    private static let frontDepth: Float = 0.54   // forward bulge (head spans ~1 unit)
    private static let backDepth: Float  = 0.34   // rear shell bulge
    private static let featureDepth: Float = 0.0  // luminance micro-relief — OFF: it makes
                                                   // noisy normals and blotchy shading. The
                                                   // smooth dome is the whole look.

    static func make(image: UIImage, tint: UIColor) -> Built {
        let n = gridN
        let (alpha, lum) = sample(image, n: n)
        let infl = inflationField(alpha: alpha, n: n)

        let head = SCNNode()
        head.addChildNode(makeSheet(n: n, alpha: alpha, infl: infl, lum: lum,
                                    isFront: true, image: image))
        head.addChildNode(makeSheet(n: n, alpha: alpha, infl: infl, lum: lum,
                                    isFront: false, image: image))

        let scene = SCNScene()
        scene.background.contents = UIColor.clear
        scene.rootNode.addChildNode(head)

        // camera — perspective so the bulge reads as depth
        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.camera!.fieldOfView = 30
        cam.camera!.zNear = 0.01
        cam.camera!.zFar = 100
        cam.position = SCNVector3(0, 0, 3.2)
        scene.rootNode.addChildNode(cam)

        // lights: soft ambient so shadows aren't black, a key light from upper-front,
        // and a slot-tinted rim for the neon edge.
        // Soft, even lighting: high ambient so the photo reads true, a gentle key for
        // the rounded gradient across the dome, and a tinted rim for the neon edge.
        let ambient = SCNNode(); ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.color = UIColor(white: 1, alpha: 1)
        ambient.light!.intensity = 720
        scene.rootNode.addChildNode(ambient)

        let key = SCNNode(); key.light = SCNLight()
        key.light!.type = .directional
        key.light!.intensity = 480
        key.light!.color = UIColor(white: 1, alpha: 1)
        key.eulerAngles = SCNVector3(-0.5, -0.5, 0)   // from upper-left-front
        scene.rootNode.addChildNode(key)

        let rim = SCNNode(); rim.light = SCNLight()
        rim.light!.type = .omni
        rim.light!.intensity = 620
        rim.light!.color = tint
        rim.position = SCNVector3(1.8, -0.6, -1.4)   // behind/side → glowing edge
        scene.rootNode.addChildNode(rim)

        return Built(scene: scene, head: head, camera: cam)
    }

    // MARK: geometry

    private static func makeSheet(n: Int, alpha: [Float], infl: [Float], lum: [Float],
                                  isFront: Bool, image: UIImage) -> SCNNode {
        let size: Float = 1
        let depth = isFront ? frontDepth : backDepth
        let sign: Float = isFront ? 1 : -1

        func height(_ i: Int, _ j: Int) -> Float {
            let i2 = min(max(i, 0), n - 1), j2 = min(max(j, 0), n - 1)
            let idx = j2 * n + i2
            if alpha[idx] < 0.5 { return 0 }
            var z = infl[idx] * depth
            if isFront { z += lum[idx] * featureDepth }
            return z * sign
        }

        var verts = [SCNVector3](); verts.reserveCapacity(n * n)
        var norms = [SCNVector3](); norms.reserveCapacity(n * n)
        var uvs = [CGPoint]();       uvs.reserveCapacity(n * n)
        let span = size / Float(n - 1)

        for j in 0..<n {
            for i in 0..<n {
                let u = Float(i) / Float(n - 1)
                let v = Float(j) / Float(n - 1)
                let x = (u - 0.5) * size
                let y = (0.5 - v) * size          // flip so the photo is upright
                verts.append(SCNVector3(x, y, height(i, j)))

                // normal from the height gradient (finite differences)
                let dzdx = (height(i + 1, j) - height(i - 1, j)) / (2 * span)
                let dzdy = (height(i, j + 1) - height(i, j - 1)) / (2 * span)
                // surface z=h(x,y) with y flipped vs j → +dzdy along -y
                var nrm = simd_normalize(simd_float3(-dzdx, dzdy, 1))
                if !isFront { nrm = -nrm }
                norms.append(SCNVector3(nrm.x, nrm.y, nrm.z))
                uvs.append(CGPoint(x: CGFloat(u), y: CGFloat(v)))
            }
        }

        var idx = [Int32](); idx.reserveCapacity((n - 1) * (n - 1) * 6)
        for j in 0..<(n - 1) {
            for i in 0..<(n - 1) {
                let a = Int32(j * n + i)
                let b = Int32(j * n + i + 1)
                let c = Int32((j + 1) * n + i)
                let d = Int32((j + 1) * n + i + 1)
                if isFront { idx += [a, c, b, b, c, d] }
                else       { idx += [a, b, c, b, d, c] }   // reversed winding
            }
        }

        let geo = SCNGeometry(
            sources: [SCNGeometrySource(vertices: verts),
                      SCNGeometrySource(normals: norms),
                      SCNGeometrySource(textureCoordinates: uvs)],
            elements: [SCNGeometryElement(indices: idx, primitiveType: .triangles)])

        let mat = SCNMaterial()
        mat.diffuse.contents = isFront ? image : darken(image, by: 0.55)
        mat.diffuse.wrapS = .clamp; mat.diffuse.wrapT = .clamp
        mat.transparencyMode = .aOne          // silhouette from the cutout's alpha
        mat.lightingModel = .lambert          // pure diffuse → smooth rounded shading, no specular blotches
        mat.isDoubleSided = true              // robust against winding; closes thin edges
        geo.materials = [mat]
        return SCNNode(geometry: geo)
    }

    // MARK: silhouette → inflation field

    /// Two-pass chamfer distance transform of the silhouette, shaped into a hemisphere
    /// profile in 0…1. Center of the head → ~1 (max bulge), edge → 0.
    private static func inflationField(alpha: [Float], n: Int) -> [Float] {
        let big: Float = 1e9
        var d = [Float](repeating: 0, count: n * n)
        for k in 0..<(n * n) { d[k] = alpha[k] >= 0.5 ? big : 0 }
        let dg: Float = 1.4142
        // forward
        for j in 0..<n {
            for i in 0..<n {
                let k = j * n + i
                if d[k] == 0 { continue }
                var m = d[k]
                if i > 0 { m = min(m, d[k - 1] + 1) }
                if j > 0 { m = min(m, d[k - n] + 1) }
                if i > 0 && j > 0 { m = min(m, d[k - n - 1] + dg) }
                if i < n - 1 && j > 0 { m = min(m, d[k - n + 1] + dg) }
                d[k] = m
            }
        }
        // backward
        for j in stride(from: n - 1, through: 0, by: -1) {
            for i in stride(from: n - 1, through: 0, by: -1) {
                let k = j * n + i
                if d[k] == 0 { continue }
                var m = d[k]
                if i < n - 1 { m = min(m, d[k + 1] + 1) }
                if j < n - 1 { m = min(m, d[k + n] + 1) }
                if i < n - 1 && j < n - 1 { m = min(m, d[k + n + 1] + dg) }
                if i > 0 && j < n - 1 { m = min(m, d[k + n - 1] + dg) }
                d[k] = m
            }
        }
        var maxD: Float = 0.0001
        for k in 0..<(n * n) where d[k] < big { maxD = max(maxD, d[k]) }
        // hemisphere profile: z = sqrt(t*(2-t)), t = normalized distance
        var out = [Float](repeating: 0, count: n * n)
        for k in 0..<(n * n) {
            let t = min(1, d[k] / maxD)
            out[k] = (t <= 0) ? 0 : (t * (2 - t)).squareRoot()
        }
        return out
    }

    // MARK: image sampling

    /// Render the image into an n×n RGBA grid and read per-cell alpha + luminance.
    private static func sample(_ image: UIImage, n: Int) -> (alpha: [Float], lum: [Float]) {
        var alpha = [Float](repeating: 0, count: n * n)
        var lum = [Float](repeating: 0, count: n * n)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8,
                                  bytesPerRow: n * 4, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let cg = image.cgImage else { return (alpha, lum) }
        ctx.clear(CGRect(x: 0, y: 0, width: n, height: n))
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: n, height: n))
        guard let buf = ctx.data else { return (alpha, lum) }
        let p = buf.bindMemory(to: UInt8.self, capacity: n * n * 4)
        for j in 0..<n {
            // CGContext origin is bottom-left; our grid j=0 is top → flip rows
            let srcRow = (n - 1 - j)
            for i in 0..<n {
                let o = (srcRow * n + i) * 4
                let a = Float(p[o + 3]) / 255
                let k = j * n + i
                alpha[k] = a
                if a > 0.01 {
                    // un-premultiply for true luminance
                    let r = Float(p[o + 0]) / 255 / a
                    let g = Float(p[o + 1]) / 255 / a
                    let b = Float(p[o + 2]) / 255 / a
                    lum[k] = min(1, 0.299 * r + 0.587 * g + 0.114 * b)
                }
            }
        }
        return (alpha, lum)
    }

    /// A darkened copy of the cutout (same alpha) for the rear shell of the head.
    private static func darken(_ image: UIImage, by f: CGFloat) -> UIImage {
        let s = image.size
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: s, format: fmt).image { ctx in
            image.draw(in: CGRect(origin: .zero, size: s))
            ctx.cgContext.setBlendMode(.sourceAtop)
            UIColor(white: 0.04, alpha: f).setFill()
            ctx.cgContext.fill(CGRect(origin: .zero, size: s))
        }
    }
}
