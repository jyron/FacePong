// FacePaddleNode.swift — a player's paddle. Your FACE is the paddle.
//
// A real Vision cutout (transparent silhouette) is rendered as a deformable mesh
// via SKWarpGeometryGrid so the face OUTLINE squashes WIDE-and-short on contact
// then rebounds through a wobble — the whole point of the game. Behind it sit a
// soft neon aura and a tight bright rim, both shaped exactly like the face
// (baked once from the cutout's alpha) and warped on the same grid, so the face
// reads as a glowing game piece on the dark court. No cutout (CPU/opponent) →
// the stylized coin avatar, which squashes uniformly.
import SpriteKit
import SceneKit
import simd

final class FacePaddleNode: SKNode {
    let slot: Slot
    private let size: CGFloat = GC.paddle
    private var half: CGFloat { size / 2 }
    private var maxR: CGFloat { half * CGFloat(2).squareRoot() }
    private var amp: CGFloat { size * 0.10 }   // subtle jiggle ripple (keep the face readable)

    // mesh grid (8x8 cells → 9x9 = 81 vertices), matching the original FacePaddle.
    private static let grid = 8
    private let sourcePositions: [SIMD2<Float>]

    // silhouette sub-tree
    private let silhouette = SKNode()
    private let auraSprite = SKSpriteNode()
    private let rimSprite = SKSpriteNode()
    private let faceSprite = SKSpriteNode()

    // coin sub-tree
    private let coin = SKNode()
    private let coinGlow = SKSpriteNode(texture: TextureFactory.softDot)
    private let coinFace = SKSpriteNode()
    private let coinRing = SKShapeNode(circleOfRadius: GC.paddleR)

    // 3D head sub-tree (the disembodied floating-head look) — a SceneKit scene
    // rendered inside SpriteKit via SK3DNode, with a soft neon halo behind it.
    private let headHolder = SKNode()
    private let headGlow = SKSpriteNode(texture: TextureFactory.softDot)
    private var head3D: SK3DNode?
    private var headNode: SCNNode?

    private var isSilhouette = false
    private var isHead = false
    private var idleT: Double = 0
    private var popT: Double = 9   // settled

    init(slot: Slot) {
        self.slot = slot
        // identity source grid (normalized [0,1], bottom-left origin), row-major
        var src: [SIMD2<Float>] = []
        let n = FacePaddleNode.grid
        for r in 0...n {
            for c in 0...n {
                src.append(SIMD2<Float>(Float(c) / Float(n), Float(r) / Float(n)))
            }
        }
        sourcePositions = src
        super.init()

        // --- coin ---
        addChild(coin)
        let ringColor = Palette.ring(slot)
        coinGlow.colorBlendFactor = 1; coinGlow.color = ringColor; coinGlow.blendMode = .add
        coinGlow.alpha = 0.5; coinGlow.size = CGSize(width: size * 1.9, height: size * 1.9)
        coinGlow.zPosition = 1; coin.addChild(coinGlow)
        coinFace.size = CGSize(width: size, height: size)
        coinFace.texture = defaultCoinTexture(slot: slot)
        coinFace.zPosition = 2; coin.addChild(coinFace)
        let ringW = max(2, size * 0.045)
        coinRing.strokeColor = ringColor; coinRing.lineWidth = ringW
        coinRing.fillColor = .clear; coinRing.glowWidth = 1.0
        coinRing.zPosition = 3; coin.addChild(coinRing)

        // --- silhouette --- explicit z so the FACE always draws on top of its
        // glow layers (SpriteView uses .ignoresSiblingOrder, which ignores child
        // insertion order for equal zPosition).
        addChild(silhouette)
        silhouette.isHidden = true
        for s in [auraSprite, rimSprite, faceSprite] { s.size = CGSize(width: size, height: size); silhouette.addChild(s) }
        auraSprite.blendMode = .add; auraSprite.zPosition = 1
        rimSprite.blendMode = .add; rimSprite.zPosition = 2
        faceSprite.zPosition = 3

        // --- 3D head holder + neon halo (the SK3DNode itself is built on setFace) ---
        addChild(headHolder)
        headHolder.isHidden = true
        headGlow.colorBlendFactor = 1; headGlow.color = ringColor; headGlow.blendMode = .add
        headGlow.alpha = 0.42; headGlow.size = CGSize(width: size * 2.1, height: size * 2.1)
        headGlow.zPosition = 0; headHolder.addChild(headGlow)
    }

    required init?(coder: NSCoder) { fatalError() }

    // image == nil → coin avatar. A transparent Vision cutout → a disembodied 3D head.
    func setFace(_ image: UIImage?) {
        guard let image else {
            isHead = false; isSilhouette = false
            coin.isHidden = false; silhouette.isHidden = true; headHolder.isHidden = true
            coinFace.texture = defaultCoinTexture(slot: slot)
            return
        }
        // Inflate the cutout into a floating 3D head and render it via SK3DNode.
        let built = FaceHead3D.make(image: image, tint: Palette.ring(slot))
        headNode = built.head
        let vp = size * 2.0   // viewport bigger than the paddle so the head + its lunge fit
        let node = head3D ?? SK3DNode(viewportSize: CGSize(width: vp, height: vp))
        node.viewportSize = CGSize(width: vp, height: vp)
        node.scnScene = built.scene
        node.pointOfView = built.camera
        node.autoenablesDefaultLighting = false
        node.isPlaying = true
        node.zPosition = 1
        if head3D == nil { headHolder.addChild(node); head3D = node }
        isHead = true; isSilhouette = false
        coin.isHidden = true; silhouette.isHidden = true; headHolder.isHidden = false
    }

    private var wobbleDir: CGFloat = 1
    func pop() { popT = 0; wobbleDir = -wobbleDir }   // alternate the rock direction each hit

    func advance(dt: Double) {
        popT += dt
        let p = GameScene.springPop(popT)

        // 3D head: idle float (gentle turn + bob) plus an impact LUNGE toward the
        // camera with squash + rock — the head jumps off the screen on a slap.
        if isHead, let headNode {
            idleT += dt
            let pf = Float(p)
            let yaw = Float(sin(idleT * 0.8) * 0.34)     // ±~19° turn so the 3D roundness reads
            let pitch = Float(sin(idleT * 0.55) * 0.09)
            let bob = Float(sin(idleT * 0.9) * 0.02)
            headNode.simdPosition = simd_float3(Float(sin(popT * 40)) * pf * 0.06,
                                                bob - pf * 0.04,
                                                pf * 0.55)
            headNode.simdScale = simd_float3(1 + pf * 0.20, 1 - pf * 0.14, 1 + pf * 0.20)
            headNode.simdEulerAngles = simd_float3(pitch,
                                                   yaw + pf * 0.12 * Float(wobbleDir),
                                                   pf * 0.10 * Float(wobbleDir))
            headGlow.alpha = 0.4 + CGFloat(pf) * 0.35
            let g = size * (2.1 + CGFloat(pf) * 0.5)
            headGlow.size = CGSize(width: g, height: g)
            return
        }

        // Funny impact reaction: a springy squash-&-stretch + a knockback recoil +
        // a tilt rock, all applied to the face as ONE unit so it stays a face.
        let node: SKNode = isSilhouette ? silhouette : coin
        let dir: CGFloat = slot == .p1 ? -1 : 1            // jolt outward (away from the ball)
        let shimmy = sin(popT * 40) * p * size * 0.05      // fast little side-to-side shake
        node.position = CGPoint(x: shimmy, y: dir * p * size * 0.14)
        node.zRotation = p * 0.27 * wobbleDir              // bigger ~15° rock that springs back
        if isSilhouette {
            applyWarp(pop: p)
        } else {
            coin.xScale = 1 + p * 0.34
            coin.yScale = 1 - p * 0.24
        }
    }

    // Deform every mesh vertex: anisotropic squash + a radial ripple that rides
    // `pop` (springs through zero) — a cartoon impact, not a nudge. Identical math
    // to the original FacePaddle silhouette deform.
    private func applyWarp(pop p: CGFloat) {
        let sx = 1 + p * 0.36   // gentle, readable squash (the face stays a face)
        let sy = 1 - p * 0.26
        var dst = sourcePositions
        for i in 0..<dst.count {
            let u = CGFloat(dst[i].x), v = CGFloat(dst[i].y)
            let vx = (u - 0.5) * size
            let vy = (v - 0.5) * size
            var nx = vx * sx
            var ny = vy * sy
            let d = (vx * vx + vy * vy).squareRoot()
            if d > 0.001 {
                let rr = d / maxR
                let k = p * amp * sin(rr * 7.0 - p * 5.0)
                nx += (vx / d) * k
                ny += (vy / d) * k
            }
            dst[i] = SIMD2<Float>(Float(nx / size + 0.5), Float(ny / size + 0.5))
        }
        let geo = SKWarpGeometryGrid(columns: FacePaddleNode.grid, rows: FacePaddleNode.grid,
                                     sourcePositions: sourcePositions, destinationPositions: dst)
        faceSprite.warpGeometry = geo
        auraSprite.warpGeometry = geo
        rimSprite.warpGeometry = geo
    }
}

// MARK: textures

// A neon-colored, blurred silhouette baked from the cutout's alpha: RGB = tint,
// alpha = the cutout's own (feathered) alpha, gaussian-blurred. Used for the
// aura/rim glow layers. We draw the face FIRST then tint with .sourceAtop so the
// color only lands where the face has alpha — never the padding (which would
// otherwise leave a solid rectangular frame).
private func tintedBlurred(_ image: UIImage, color: SKColor, blur: CGFloat) -> UIImage {
    let pad = blur * 3
    let s = CGSize(width: image.size.width + pad * 2, height: image.size.height + pad * 2)
    let faceRect = CGRect(x: pad, y: pad, width: image.size.width, height: image.size.height)
    let tinted = UIGraphicsImageRenderer(size: s).image { ctx in
        let cg = ctx.cgContext
        image.draw(in: faceRect)                         // lay down the cutout (with its alpha)
        cg.setBlendMode(.sourceAtop)                     // tint only where alpha > 0
        cg.setFillColor(color.cgColor)
        cg.fill(CGRect(origin: .zero, size: s))
    }
    guard let ci = CIImage(image: tinted) else { return tinted }
    let f = CIFilter(name: "CIGaussianBlur", parameters: [kCIInputImageKey: ci, kCIInputRadiusKey: blur])!
    guard let out = f.outputImage else { return tinted }
    let ctx = CIContext()
    guard let cg = ctx.createCGImage(out, from: ci.extent) else { return tinted }
    return UIImage(cgImage: cg)
}

private func circularCoin(_ image: UIImage, diameter: CGFloat) -> UIImage {
    let s = CGSize(width: diameter, height: diameter)
    return UIGraphicsImageRenderer(size: s).image { _ in
        UIBezierPath(ovalIn: CGRect(origin: .zero, size: s)).addClip()
        let imgAspect = image.size.width / max(1, image.size.height)
        var drawRect = CGRect(origin: .zero, size: s)
        if imgAspect > 1 {
            let w = diameter * imgAspect
            drawRect = CGRect(x: (diameter - w) / 2, y: 0, width: w, height: diameter)
        } else {
            let h = diameter / imgAspect
            drawRect = CGRect(x: 0, y: (diameter - h) / 2, width: diameter, height: h)
        }
        image.draw(in: drawRect)
    }
}

private func defaultCoinTexture(slot: Slot) -> SKTexture {
    let diameter: CGFloat = 256
    let s = CGSize(width: diameter, height: diameter)
    let img = UIGraphicsImageRenderer(size: s).image { ctx in
        let c = ctx.cgContext
        UIBezierPath(ovalIn: CGRect(origin: .zero, size: s)).addClip()
        let space = CGColorSpaceCreateDeviceRGB()
        let top = slot == .p1 ? SKColor(hex: "#0c2b3a") : SKColor(hex: "#3a0c2a")
        let bot = slot == .p1 ? SKColor(hex: "#0a1726") : SKColor(hex: "#260a1c")
        if let grad = CGGradient(colorsSpace: space, colors: [top.cgColor, bot.cgColor] as CFArray, locations: [0, 1]) {
            c.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: diameter), options: [])
        }
        let accent = (slot == .p1 ? Palette.cyan : Palette.magenta)
        let faceColor = slot == .p1 ? SKColor(hex: "#f1d4b8") : SKColor(hex: "#f0c9a0")
        c.setFillColor(faceColor.cgColor)
        let fr = diameter * 0.42
        c.fillEllipse(in: CGRect(x: diameter/2 - fr/2, y: diameter*0.30, width: fr, height: fr*1.15))
        c.setFillColor(accent.cgColor)
        let eye = diameter * 0.05
        c.fillEllipse(in: CGRect(x: diameter*0.40 - eye/2, y: diameter*0.50, width: eye, height: eye))
        c.fillEllipse(in: CGRect(x: diameter*0.60 - eye/2, y: diameter*0.50, width: eye, height: eye))
        c.setStrokeColor(accent.cgColor)
        c.setLineWidth(diameter*0.02)
        c.addArc(center: CGPoint(x: diameter/2, y: diameter*0.62), radius: diameter*0.10,
                 startAngle: .pi*0.15, endAngle: .pi*0.85, clockwise: false)
        c.strokePath()
    }
    return SKTexture(image: img)
}
