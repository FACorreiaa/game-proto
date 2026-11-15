import ActionCore
import SpriteKit

/// Placeholder figure for one fighter, drawn from shapes. Origin is the centre of the feet, facing right.
/// Art made later replaces this class without touching the simulation.
final class FighterNode: SKNode {
    let kind: FighterKind
    private let figure = SKNode()
    private var bodyParts: [SKShapeNode] = []
    private var legs: [SKShapeNode] = []
    private let weaponPivot = SKNode()
    private var weapon: SKShapeNode?
    private var eye: SKShapeNode?
    private var shield: SKShapeNode?
    private var core: SKShapeNode?
    /// The Protocol shows where its next attack will land.
    private let zone = SKShapeNode()
    private var zoneAttack = -1
    private var flashFrames = 0
    /// One arc per swing, even while hit-stop holds the same frame on screen.
    private var arcDrawn = false
    private var rim: SKColor
    private var baseFill = Palette.body
    private let marker = SKShapeNode()
    private var gone = false

    init(kind: FighterKind) {
        self.kind = kind
        rim = kind.team == .hero ? Palette.cyan : (kind == .dummy ? Palette.steel : Palette.red)
        if kind == .orion { baseFill = Palette.plate }
        super.init()
        addChild(figure)
        buildMarker()
        switch kind {
        case .caelen: buildCaelen()
        case .orion: buildOrion()
        case .dummy: buildDummy()
        case .scrapDrone: buildDrone()
        case .forgedSoldier: buildSoldier()
        case .theProtocol: buildProtocol()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: Building

    private func part(_ path: CGPath, z: CGFloat = 0) -> SKShapeNode {
        let node = SKShapeNode(path: path)
        node.fillColor = baseFill
        node.strokeColor = rim.withAlphaComponent(0.45)
        node.lineWidth = 1.5
        node.zPosition = z
        figure.addChild(node)
        bodyParts.append(node)
        return node
    }

    private func leg(x: CGFloat, hipY: CGFloat, length: CGFloat, width: CGFloat) {
        let node = part(CGPath(rect: CGRect(x: -width / 2, y: -length, width: width, height: length), transform: nil), z: -1)
        node.position = CGPoint(x: x, y: hipY)
        legs.append(node)
    }

    private func light(_ node: SKShapeNode, color: SKColor, glow: CGFloat) {
        node.fillColor = color
        node.strokeColor = color
        node.glowWidth = glow
        node.zPosition = 2
    }

    private func blade(length: CGFloat, color: SKColor, at pivot: CGPoint) {
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: 0, y: length))
        let node = SKShapeNode(path: path)
        node.strokeColor = color
        node.lineWidth = 3
        node.glowWidth = 3
        node.lineCap = .round
        weaponPivot.position = pivot
        weaponPivot.zPosition = 3
        weaponPivot.addChild(node)
        figure.addChild(weaponPivot)
        weapon = node
    }

    private func buildCaelen() {
        leg(x: -6, hipY: 32, length: 32, width: 8)
        leg(x: 6, hipY: 32, length: 32, width: 8)
        let coat = CGMutablePath()
        coat.addLines(between: [
            CGPoint(x: -11, y: 64), CGPoint(x: 12, y: 64), CGPoint(x: 13, y: 30),
            CGPoint(x: 8, y: 16), CGPoint(x: -26, y: 12), CGPoint(x: -15, y: 40),
        ])
        coat.closeSubpath()
        _ = part(coat)
        _ = part(CGPath(ellipseIn: CGRect(x: -8, y: 64, width: 20, height: 20), transform: nil), z: 1)
        let collar = SKShapeNode(rect: CGRect(x: 2, y: 58, width: 9, height: 3))
        light(collar, color: Palette.cyan, glow: 2)
        figure.addChild(collar)
        let dot = SKShapeNode(circleOfRadius: 1.8)
        dot.position = CGPoint(x: 8, y: 75)
        light(dot, color: Palette.cyan, glow: 2)
        figure.addChild(dot)
        eye = dot
        blade(length: 60, color: Palette.cyan, at: CGPoint(x: 6, y: 54))
    }

    /// Orion: pale plating, cyan eye and chest core, a torn cloak, a short blade.
    private func buildOrion() {
        leg(x: -6, hipY: 34, length: 34, width: 7)
        leg(x: 6, hipY: 34, length: 34, width: 7)
        let cloak = CGMutablePath()
        cloak.addLines(between: [
            CGPoint(x: -9, y: 68), CGPoint(x: 4, y: 68), CGPoint(x: -4, y: 40),
            CGPoint(x: -20, y: 20), CGPoint(x: -24, y: 34), CGPoint(x: -16, y: 52),
        ])
        cloak.closeSubpath()
        _ = part(cloak, z: -1)
        _ = part(CGPath(roundedRect: CGRect(x: -10, y: 32, width: 20, height: 36), cornerWidth: 6, cornerHeight: 6, transform: nil))
        _ = part(CGPath(ellipseIn: CGRect(x: -8, y: 68, width: 18, height: 18), transform: nil), z: 1)
        let core = SKShapeNode(circleOfRadius: 3.5)
        core.position = CGPoint(x: 4, y: 54)
        light(core, color: Palette.cyan, glow: 3)
        figure.addChild(core)
        let dot = SKShapeNode(circleOfRadius: 2.4)
        dot.position = CGPoint(x: 6, y: 78)
        light(dot, color: Palette.cyan, glow: 3)
        figure.addChild(dot)
        eye = dot
        blade(length: 44, color: Palette.cyan, at: CGPoint(x: 6, y: 52))
    }

    /// A small arrow over the hero the player is controlling.
    private func buildMarker() {
        let path = CGMutablePath()
        path.addLines(between: [CGPoint(x: -7, y: 8), CGPoint(x: 7, y: 8), CGPoint(x: 0, y: 0)])
        path.closeSubpath()
        marker.path = path
        marker.fillColor = Palette.cyan
        marker.strokeColor = .clear
        marker.glowWidth = 2
        marker.zPosition = 6
        marker.isHidden = true
        addChild(marker)
    }

    private func buildDummy() {
        _ = part(CGPath(rect: CGRect(x: -4, y: 0, width: 8, height: 70), transform: nil))
        _ = part(CGPath(rect: CGRect(x: -20, y: 50, width: 40, height: 8), transform: nil))
        _ = part(CGPath(ellipseIn: CGRect(x: -11, y: 68, width: 22, height: 22), transform: nil))
    }

    private func buildDrone() {
        for x in [-16.0, -6.0, 6.0, 16.0] {
            leg(x: x, hipY: 14, length: 14, width: 4)
        }
        _ = part(CGPath(ellipseIn: CGRect(x: -22, y: 8, width: 44, height: 28), transform: nil))
        let dot = SKShapeNode(circleOfRadius: 6)
        dot.position = CGPoint(x: 9, y: 22)
        light(dot, color: Palette.red, glow: 4)
        figure.addChild(dot)
        eye = dot
    }

    private func buildSoldier() {
        leg(x: -8, hipY: 40, length: 40, width: 11)
        leg(x: 8, hipY: 40, length: 40, width: 11)
        _ = part(CGPath(roundedRect: CGRect(x: -17, y: 38, width: 34, height: 44), cornerWidth: 5, cornerHeight: 5, transform: nil))
        _ = part(CGPath(roundedRect: CGRect(x: -9, y: 82, width: 20, height: 18), cornerWidth: 4, cornerHeight: 4, transform: nil), z: 1)
        let visor = SKShapeNode(rect: CGRect(x: 1, y: 90, width: 10, height: 3))
        light(visor, color: Palette.red, glow: 3)
        figure.addChild(visor)
        eye = visor
        blade(length: 74, color: Palette.red, at: CGPoint(x: 4, y: 70))
        let plate = SKShapeNode(rect: CGRect(x: 15, y: 16, width: 9, height: 70), cornerRadius: 3)
        plate.fillColor = Palette.body
        plate.strokeColor = Palette.steel
        plate.lineWidth = 2
        plate.zPosition = 4
        figure.addChild(plate)
        shield = plate
    }

    /// The Protocol: a tower of plate on two pillars, a red visor, and a core in its chest that opens.
    private func buildProtocol() {
        leg(x: -40, hipY: 96, length: 96, width: 34)
        leg(x: 40, hipY: 96, length: 96, width: 34)
        _ = part(CGPath(roundedRect: CGRect(x: -75, y: 84, width: 150, height: 120), cornerWidth: 14, cornerHeight: 14, transform: nil))
        let shoulders = CGMutablePath()
        shoulders.addLines(between: [
            CGPoint(x: -92, y: 176), CGPoint(x: -60, y: 214), CGPoint(x: 60, y: 214), CGPoint(x: 92, y: 176),
            CGPoint(x: 70, y: 160), CGPoint(x: -70, y: 160),
        ])
        shoulders.closeSubpath()
        _ = part(shoulders, z: 1)
        _ = part(CGPath(roundedRect: CGRect(x: -30, y: 204, width: 64, height: 46), cornerWidth: 8, cornerHeight: 8, transform: nil), z: 1)
        let arm = part(CGPath(roundedRect: CGRect(x: 52, y: 70, width: 30, height: 100), cornerWidth: 10, cornerHeight: 10, transform: nil), z: 2)
        arm.strokeColor = Palette.red.withAlphaComponent(0.6)
        let visor = SKShapeNode(rect: CGRect(x: -2, y: 226, width: 34, height: 6))
        light(visor, color: Palette.red, glow: 5)
        figure.addChild(visor)
        eye = visor
        let heart = SKShapeNode(circleOfRadius: 20)
        heart.position = CGPoint(x: 6, y: 138)
        heart.lineWidth = 3
        heart.zPosition = 3
        figure.addChild(heart)
        core = heart

        zone.lineWidth = 2
        zone.zPosition = -3
        zone.isHidden = true
        addChild(zone)
    }

    /// Where the attack will land, drawn faint through the warning and bright on the strike.
    private func animateZone(_ f: Fighter) {
        guard kind == .theProtocol else { return }
        guard case .attack(let index) = f.state, let a = f.currentAttack, f.attackPhase != .recovery else {
            zone.isHidden = true
            zoneAttack = -1
            return
        }
        if zoneAttack != index {
            zoneAttack = index
            let travel = a.holdsStill ? a.lunge * Double(a.active) / Tuning.framesPerSecond : 0
            let far = f.spec.width / 2 + a.reach + travel
            zone.path = CGPath(rect: CGRect(x: 0, y: a.yOffset, width: far, height: a.height), transform: nil)
        }
        zone.isHidden = false
        let striking = f.attackPhase == .active
        let t = CGFloat(f.stateFrame) / CGFloat(max(a.windup, 1))
        let last = a.windup - f.stateFrame <= 8
        zone.fillColor = Palette.red.withAlphaComponent(striking ? 0.55 : (last ? 0.3 : 0.05 + 0.13 * t))
        zone.strokeColor = Palette.red.withAlphaComponent(striking ? 1 : 0.25 + 0.5 * t)
        zone.glowWidth = striking ? 6 : 0
    }

    private func animateCore(_ f: Fighter, frame: Int) {
        guard let core else { return }
        let open = f.isOpen && f.isAlive
        core.fillColor = open ? Palette.gold : Palette.body
        core.strokeColor = open ? Palette.white : Palette.red.withAlphaComponent(f.awake ? 0.7 : 0.2)
        core.glowWidth = open ? 10 : 0
        core.setScale(open ? 1.15 + 0.12 * sin(CGFloat(frame) * 0.4) : 1)
    }

    // MARK: Per-frame

    func flash() {
        flashFrames = 4
    }

    /// Used when the fighter vanishes at once, as a drone does when it explodes.
    func vanish() {
        gone = true
        removeFromParent()
    }

    func sync(_ f: Fighter, frame: Int, controlled: Bool = false) {
        guard !gone else { return }
        marker.isHidden = !controlled || !f.isAlive
        marker.position = CGPoint(x: 0, y: f.spec.height + 12 + 2 * sin(CGFloat(frame) * 0.12))
        position = CGPoint(x: f.pos.x, y: f.pos.y)
        xScale = f.facing >= 0 ? 1 : -1

        var tilt: CGFloat = 0
        var stretch = CGSize(width: 1, height: 1)
        var opacity: CGFloat = 1
        var offset = CGPoint.zero
        var tint: SKColor?

        switch f.state {
        case .idle:
            stretch.height = 1 + 0.015 * sin(CGFloat(frame) * 0.08)
        case .run:
            tilt = -0.08
        case .air:
            stretch = f.vel.y > 0 ? CGSize(width: 0.94, height: 1.06) : CGSize(width: 1.04, height: 0.97)
        case .attack:
            let lean: CGFloat = kind == .theProtocol ? 0.5 : 1
            tilt = (f.attackPhase == .windup ? 0.06 : -0.1) * lean
        case .dodge:
            stretch = CGSize(width: 1.3, height: 0.8)
            opacity = 0.55
        case .hitstun:
            tilt = 0.3
        case .staggered:
            tilt = (kind == .theProtocol ? 0.06 : 0.18) + 0.06 * sin(CGFloat(frame) * 0.5)
            tint = Palette.ember
        case .fuse:
            // Blinks faster as the fuse runs down.
            let period = max(4, 16 - f.stateFrame / 5)
            if (f.stateFrame / (period / 2)) % 2 == 0 { tint = Palette.red }
            let pulse = 1 + 0.12 * sin(CGFloat(f.stateFrame) * 0.6)
            stretch = CGSize(width: pulse, height: pulse)
        case .dead:
            if kind == .theProtocol {
                // Too heavy to tumble: it sinks to its knees and goes dark.
                let t = min(1, CGFloat(f.stateFrame) / 80)
                stretch.height = 1 - 0.3 * t
                tilt = 0.12 * t
                opacity = 1 - 0.5 * t
            } else {
                let t = min(1, CGFloat(f.stateFrame) / 30)
                tilt = 1.4 * t
                opacity = 1 - t
            }
        }

        if f.invulnerable > 0, f.team == .hero, f.state != .dead, (frame / 3) % 2 == 0 { opacity *= 0.4 }
        if kind == .scrapDrone, f.attackPhase == .windup {
            offset.x = -6
            stretch = CGSize(width: 1.1, height: 0.82)
        }

        figure.zRotation = tilt
        figure.xScale = stretch.width
        figure.yScale = stretch.height
        figure.position = offset
        figure.alpha = opacity

        animateLegs(f, frame: frame)
        animateWeapon(f)
        animateTelegraph(f)
        animateZone(f)
        animateCore(f, frame: frame)
        if kind == .theProtocol, !f.awake {
            // Dormant: slumped and dark until a hero comes near.
            figure.yScale = 0.88
            figure.alpha = 0.55
            eye?.alpha = 0.15
        } else if kind == .theProtocol {
            eye?.alpha = 1
        }

        if flashFrames > 0 { flashFrames -= 1 }
        let fill = flashFrames > 0 ? Palette.white : (tint ?? baseFill)
        for p in bodyParts where p.fillColor != fill { p.fillColor = fill }
        shield?.alpha = f.isGuarding ? 1 : 0.35
    }

    private func animateLegs(_ f: Fighter, frame: Int) {
        let moving = f.state == .run || (f.state == .fuse && abs(f.vel.x) > 1)
        let rate: CGFloat = kind == .scrapDrone ? 0.7 : 0.32
        let swing: CGFloat = moving ? 0.6 : (f.state == .air ? 0.25 : 0)
        for (i, leg) in legs.enumerated() {
            let phase = CGFloat(frame) * rate + CGFloat(i) * .pi
            leg.zRotation = moving ? swing * sin(phase) : (f.state == .air ? (i % 2 == 0 ? swing : -swing) : 0)
        }
    }

    /// Blade angles are measured from straight up; negative swings forward.
    private func animateWeapon(_ f: Fighter) {
        guard weapon != nil else { return }
        let rest: CGFloat = kind.team == .hero ? -2.5 : -2.75
        if f.attackPhase != .active { arcDrawn = false }
        guard case .attack(let index) = f.state, let a = f.currentAttack else {
            weaponPivot.zRotation = rest
            return
        }
        let sweeps: [(CGFloat, CGFloat)] = switch kind {
        case .caelen: [(0.9, -2.0), (-2.7, 0.2), (1.7, -2.5)]
        case .orion: [(-0.4, -2.2), (-2.6, 0.4)]
        default: [(1.1, -2.3)]
        }
        let (from, to) = sweeps[index % sweeps.count]
        let frame = CGFloat(f.stateFrame)
        switch f.attackPhase {
        case .windup:
            let t = frame / CGFloat(max(a.windup, 1))
            weaponPivot.zRotation = rest + (from - rest) * min(1, t * 1.6)
        case .active:
            let t = (frame - CGFloat(a.windup) + 1) / CGFloat(a.active)
            weaponPivot.zRotation = from + (to - from) * min(1, t)
            if !arcDrawn {
                arcDrawn = true
                drawArc(from: from, to: to, radius: weaponLength)
            }
        case .recovery, .none:
            let t = (frame - CGFloat(a.windup + a.active)) / CGFloat(max(a.recovery, 1))
            weaponPivot.zRotation = to + (rest - to) * t * t
        }
    }

    private var weaponLength: CGFloat { kind == .caelen ? 62 : (kind == .orion ? 46 : 76) }

    private func drawArc(from: CGFloat, to: CGFloat, radius: CGFloat) {
        let path = CGMutablePath()
        path.addArc(center: .zero, radius: radius, startAngle: from + .pi / 2, endAngle: to + .pi / 2, clockwise: to < from)
        let arc = SKShapeNode(path: path)
        arc.position = weaponPivot.position
        arc.strokeColor = kind.team == .hero ? Palette.cyan : Palette.red
        arc.lineWidth = 7
        arc.glowWidth = 5
        arc.lineCap = .round
        arc.zPosition = 5
        arc.alpha = 0.85
        figure.addChild(arc)
        arc.run(.sequence([.group([.fadeOut(withDuration: 0.16), .scale(to: 1.12, duration: 0.16)]), .removeFromParent()]))
    }

    /// Enemies warn before they strike: the eye swells through the windup and the body flashes just before the hit,
    /// which is the moment to parry or dodge.
    private func animateTelegraph(_ f: Fighter) {
        guard f.team == .enemy, let eye else { return }
        if let a = f.currentAttack, f.attackPhase == .windup {
            let t = CGFloat(f.stateFrame) / CGFloat(max(a.windup, 1))
            eye.setScale(1 + 1.2 * t)
            if a.windup - f.stateFrame <= 7 { flashFrames = max(flashFrames, 1) }
        } else {
            eye.setScale(1)
        }
    }
}
