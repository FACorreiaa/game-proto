import SpriteKit

/// Visual effects made from code: particle bursts, dust, drifting embers, light shafts, screen flashes and the
/// vignette. Every texture is drawn once at launch, so there are no image files. Sprite art made later sits on
/// top of these without changing them.
@MainActor
enum Effects {
    /// A soft white dot, bright in the middle and fading to nothing. Particles and glows are tinted copies.
    static let dot: SKTexture = radial(size: 64, stops: [(0, 1), (0.35, 0.55), (1, 0)])

    /// Dark corners, clear middle.
    static let vignetteTexture: SKTexture = radial(size: 256, stops: [(0, 0), (0.55, 0), (1, 0.62)], dark: true)

    private static func radial(size: Int, stops: [(CGFloat, CGFloat)], dark: Bool = false) -> SKTexture {
        let space = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return SKTexture() }
        let shade: CGFloat = dark ? 0 : 1
        let colors = stops.map { CGColor(red: shade, green: shade, blue: shade, alpha: $0.1) } as CFArray
        let locations = stops.map(\.0)
        guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: locations) else { return SKTexture() }
        let centre = CGPoint(x: CGFloat(size) / 2, y: CGFloat(size) / 2)
        // The dark version reaches into the corners; the dot stays inside its circle.
        let radius = CGFloat(size) / 2 * (dark ? 1.42 : 1)
        context.drawRadialGradient(gradient, startCenter: centre, startRadius: 0, endCenter: centre, endRadius: radius,
                                   options: dark ? [.drawsAfterEndLocation] : [])
        guard let image = context.makeImage() else { return SKTexture() }
        return SKTexture(cgImage: image)
    }

    // MARK: Bursts

    /// A one-off spray of glowing particles. They stay where they were made even if the camera moves.
    static func burst(
        _ parent: SKNode, at point: CGPoint, color: SKColor, count: Int, speed: CGFloat = 220,
        life: CGFloat = 0.35, size: CGFloat = 10, angle: CGFloat = 0, spread: CGFloat = .pi * 2,
        gravity: CGFloat = 0, width: CGFloat = 0, additive: Bool = true, z: CGFloat = 20
    ) {
        guard count > 0 else { return }
        let emitter = SKEmitterNode()
        emitter.particleTexture = dot
        emitter.particleBirthRate = CGFloat(count) * 40
        emitter.numParticlesToEmit = count
        emitter.particleLifetime = life
        emitter.particleLifetimeRange = life * 0.5
        emitter.emissionAngle = angle
        emitter.emissionAngleRange = spread
        emitter.particleSpeed = speed
        emitter.particleSpeedRange = speed * 0.8
        emitter.particleAlpha = 1
        emitter.particleAlphaSpeed = -1 / life
        emitter.particleScale = size / 64
        emitter.particleScaleRange = size / 128
        emitter.particleScaleSpeed = -(size / 64) / life * 0.6
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = additive ? .add : .alpha
        emitter.yAcceleration = gravity
        emitter.particlePositionRange = CGVector(dx: width, dy: 0)
        emitter.position = point
        emitter.zPosition = z
        emitter.targetNode = parent
        parent.addChild(emitter)
        emitter.run(.sequence([.wait(forDuration: Double(life * 1.6 + 0.1)), .removeFromParent()]))
    }

    /// Grey puffs at the feet: a jump, a landing, a dodge.
    static func dust(_ parent: SKNode, at point: CGPoint, amount: Int = 8, spread: CGFloat = 26) {
        burst(parent, at: point, color: SKColor(white: 0.55, alpha: 1), count: amount, speed: 60, life: 0.45,
              size: 22, angle: .pi / 2, spread: .pi * 0.9, gravity: 40, width: spread, additive: false, z: 4)
    }

    /// Fire and smoke.
    static func explosion(_ parent: SKNode, at point: CGPoint, radius: CGFloat) {
        burst(parent, at: point, color: Palette.ember, count: 40, speed: radius * 2.6, life: 0.4, size: 20)
        burst(parent, at: point, color: Palette.gold, count: 14, speed: radius * 1.2, life: 0.25, size: 26)
        burst(parent, at: point, color: SKColor(white: 0.18, alpha: 1), count: 16, speed: 70, life: 0.9, size: 46,
              angle: .pi / 2, spread: .pi, gravity: 60, width: radius * 0.5, additive: false, z: 18)
    }

    /// A machine coming apart: embers that fall.
    static func breakApart(_ parent: SKNode, at point: CGPoint, size: CGFloat) {
        burst(parent, at: point, color: Palette.red, count: 18 + Int(size / 6), speed: 160, life: 0.6, size: 9,
              gravity: -420, width: size * 0.4)
        burst(parent, at: point, color: Palette.ember, count: 10, speed: 90, life: 0.8, size: 7, angle: .pi / 2,
              spread: .pi, gravity: -200)
    }

    /// Light rising out of a column as it burns.
    static func column(_ parent: SKNode, at point: CGPoint, width: CGFloat) {
        burst(parent, at: point, color: Palette.white, count: 26, speed: 420, life: 0.35, size: 12, angle: .pi / 2,
              spread: 0.25, width: width * 0.8)
        burst(parent, at: point, color: Palette.red, count: 14, speed: 140, life: 0.3, size: 14, angle: .pi / 2,
              spread: .pi * 0.8, width: width)
    }

    /// Motes that drift up and away, for checkpoints and pickups.
    static func motes(_ parent: SKNode, at point: CGPoint, color: SKColor, count: Int = 14, width: CGFloat = 30) {
        burst(parent, at: point, color: color, count: count, speed: 50, life: 0.9, size: 8, angle: .pi / 2,
              spread: 0.6, gravity: 60, width: width)
    }

    // MARK: Atmosphere

    /// Embers that float up through the Foundry, and dust in the far light. Already drifting when a level opens.
    static func ambient(mid: SKNode, far: SKNode, width: CGFloat) {
        let embers = SKEmitterNode()
        embers.particleTexture = dot
        embers.particleBirthRate = width / 260
        embers.particleLifetime = 9
        embers.particleLifetimeRange = 3
        embers.emissionAngle = .pi / 2
        embers.emissionAngleRange = 0.5
        embers.particleSpeed = 34
        embers.particleSpeedRange = 18
        embers.xAcceleration = 4
        embers.particleAlpha = 0.75
        embers.particleAlphaRange = 0.25
        embers.particleAlphaSpeed = -0.08
        embers.particleScale = 0.1
        embers.particleScaleRange = 0.06
        embers.particleColor = Palette.ember
        embers.particleColorBlendFactor = 1
        embers.particleBlendMode = .add
        embers.position = CGPoint(x: width / 2, y: -30)
        embers.particlePositionRange = CGVector(dx: width + 400, dy: 40)
        embers.zPosition = 2
        mid.addChild(embers)
        embers.advanceSimulationTime(10)

        let motes = SKEmitterNode()
        motes.particleTexture = dot
        motes.particleBirthRate = width / 500
        motes.particleLifetime = 14
        motes.emissionAngleRange = .pi * 2
        motes.particleSpeed = 6
        motes.particleSpeedRange = 4
        motes.particleAlpha = 0.35
        motes.particleAlphaSpeed = -0.02
        motes.particleScale = 0.07
        motes.particleScaleRange = 0.04
        motes.particleColor = Palette.cyan
        motes.particleColorBlendFactor = 1
        motes.particleBlendMode = .add
        motes.position = CGPoint(x: width / 2, y: 200)
        motes.particlePositionRange = CGVector(dx: width + 400, dy: 360)
        motes.zPosition = 1
        far.addChild(motes)
        motes.advanceSimulationTime(14)

        // Slanted light falling from the high windows.
        var x = -100.0
        while x < width + 300 {
            let shaft = SKSpriteNode(texture: dot, size: CGSize(width: 110, height: 820))
            shaft.color = Palette.cyan
            shaft.colorBlendFactor = 1
            shaft.alpha = 0.07
            shaft.blendMode = .add
            shaft.position = CGPoint(x: x, y: 230)
            shaft.zRotation = -0.32
            shaft.zPosition = 0.5
            far.addChild(shaft)
            x += 450
        }
    }

    // MARK: Screen

    /// A brief wash of colour over the whole screen.
    static func flash(_ scene: SKScene, color: SKColor, alpha: CGFloat, duration: TimeInterval = 0.18) {
        let wash = SKSpriteNode(color: color, size: scene.size)
        wash.anchorPoint = .zero
        wash.alpha = alpha
        wash.blendMode = .add
        wash.zPosition = 86
        scene.addChild(wash)
        wash.run(.sequence([.fadeOut(withDuration: duration), .removeFromParent()]))
    }

    /// A soft glow sprite, for lights on fighters.
    /// Something thrown: a lit ember arcing from the thrower to where it lands, with a short trail.
    static func lob(_ parent: SKNode, from: CGPoint, to: CGPoint, color: SKColor, duration: TimeInterval = 0.5) {
        let ball = SKShapeNode(circleOfRadius: 4)
        ball.fillColor = color
        ball.strokeColor = color
        ball.glowWidth = 5
        ball.zPosition = 9
        ball.position = from
        parent.addChild(ball)
        let peak = max(from.y, to.y) + 70 + abs(to.x - from.x) * 0.15
        let path = CGMutablePath()
        path.move(to: from)
        path.addQuadCurve(to: to, control: CGPoint(x: (from.x + to.x) / 2, y: peak))
        let fly = SKAction.follow(path, asOffset: false, orientToPath: false, duration: duration)
        fly.timingMode = .easeIn
        let trail = SKAction.repeat(.sequence([.run { [weak parent, weak ball] in
            guard let parent, let ball else { return }
            let mote = SKShapeNode(circleOfRadius: 2)
            mote.fillColor = color.withAlphaComponent(0.6)
            mote.strokeColor = .clear
            mote.position = ball.position
            mote.zPosition = 8
            parent.addChild(mote)
            mote.run(.sequence([.group([.fadeOut(withDuration: 0.25), .scale(to: 0.3, duration: 0.25)]), .removeFromParent()]))
        }, .wait(forDuration: 0.03)]), count: Int(duration / 0.03))
        ball.run(.sequence([.group([fly, trail]), .removeFromParent()]))
    }

    static func glow(color: SKColor, size: CGFloat, alpha: CGFloat) -> SKSpriteNode {
        let glow = SKSpriteNode(texture: dot, size: CGSize(width: size, height: size))
        glow.color = color
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        glow.alpha = alpha
        return glow
    }
}
