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
    /// A Halo Disciple's halo, which swells as its flare gathers.
    private var halo: SKShapeNode?
    private var core: SKShapeNode?
    /// The Protocol shows where its next attack will land.
    private let zone = SKShapeNode()
    private var zoneAttack = -1
    /// Shown over an enemy carrying Caelen's mark.
    private let mark = SKShapeNode()
    /// Shown around a machine a Dogma Frame is shielding.
    private let ward = SKShapeNode()
    private var aura: SKShapeNode?
    private var thrusters: [SKShapeNode] = []
    /// The look of The Protocol's last phase has been applied.
    private var executionLook = false
    private var flashFrames = 0
    /// One arc per swing, even while hit-stop holds the same frame on screen.
    private var arcDrawn = false
    private var rim: SKColor
    private var baseFill = Palette.body
    private let marker = SKShapeNode()
    private var gone = false
    private var eyeGlow: SKSpriteNode?
    private var coreGlow: SKSpriteNode?
    private var lastGhostFrame = -1

    init(kind: FighterKind) {
        self.kind = kind
        rim = switch kind {
        case .seraphine: Palette.gold
        case .nimue, .decoy: Palette.violet
        // The Lantern Cities' people are lit by their lanterns, not by machine red.
        case .ratborn, .lanternGunner, .smugglerBrute, .nightWeaver, .weaverImage, .cinderKing: Palette.ember
        // The Dawnfaith's believers carry their own light: gold, not machine red.
        case .zealot, .radiantAcolyte, .solarGuard, .haloDisciple: Palette.gold
        default: kind.team == .hero ? Palette.cyan : (kind == .dummy ? Palette.steel : Palette.red)
        }
        if kind == .orion { baseFill = Palette.plate }
        if kind == .seraphine { baseFill = Palette.ivory }
        super.init()
        addChild(figure)
        buildMarker()
        buildMark()
        buildWard()
        switch kind {
        case .caelen: buildCaelen()
        case .orion: buildOrion()
        case .seraphine: buildSeraphine()
        case .nimue: buildNimue()
        case .decoy: buildDecoy()
        case .dummy: buildDummy()
        case .scrapDrone: buildDrone()
        case .forgedSoldier: buildSoldier()
        case .theProtocol: buildProtocol()
        case .sentryCore: buildSentry()
        case .dogmaFrame: buildDogma()
        case .ratborn: buildRatborn()
        case .lanternGunner: buildGunner()
        case .smugglerBrute: buildBrute()
        case .nightWeaver: buildWeaver()
        case .weaverImage: buildWeaverImage()
        case .cinderKing: buildCinderKing()
        case .lineWarden: buildWarden()
        case .zealot: buildZealot()
        case .radiantAcolyte: buildAcolyte()
        case .solarGuard: buildSolarGuard()
        case .haloDisciple: buildDisciple()
        }
        addGlows()
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

    private func buildMark() {
        let path = CGMutablePath()
        path.addLines(between: [CGPoint(x: 0, y: 10), CGPoint(x: 9, y: 0), CGPoint(x: 0, y: -10), CGPoint(x: -9, y: 0)])
        path.closeSubpath()
        mark.path = path
        mark.fillColor = .clear
        mark.strokeColor = Palette.gold
        mark.lineWidth = 2.5
        mark.glowWidth = 4
        mark.zPosition = 7
        mark.isHidden = true
        addChild(mark)
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

    /// The Line Warden: a tall soldier frame, a tower shield held forward and a long blade. The shield dims when it
    /// drops its guard, the same as a Forged Soldier's.
    private func buildWarden() {
        leg(x: -11, hipY: 52, length: 52, width: 14)
        leg(x: 11, hipY: 52, length: 52, width: 14)
        _ = part(CGPath(roundedRect: CGRect(x: -24, y: 50, width: 48, height: 58), cornerWidth: 6, cornerHeight: 6, transform: nil))
        // Shoulder plates and a narrow helm.
        _ = part(CGPath(roundedRect: CGRect(x: -30, y: 96, width: 60, height: 14), cornerWidth: 5, cornerHeight: 5, transform: nil), z: 1)
        _ = part(CGPath(roundedRect: CGRect(x: -10, y: 108, width: 22, height: 24), cornerWidth: 4, cornerHeight: 4, transform: nil), z: 1)
        let visor = SKShapeNode(rect: CGRect(x: 0, y: 120, width: 12, height: 3))
        light(visor, color: Palette.red, glow: 4)
        figure.addChild(visor)
        eye = visor
        // A line of red down its chest: the line it keeps.
        let seam = SKShapeNode(rect: CGRect(x: -1.5, y: 56, width: 3, height: 40))
        light(seam, color: Palette.red, glow: 2)
        figure.addChild(seam)
        blade(length: 96, color: Palette.red, at: CGPoint(x: 6, y: 88))
        let tower = SKShapeNode(rect: CGRect(x: 22, y: 14, width: 13, height: 104), cornerRadius: 4)
        tower.fillColor = Palette.body
        tower.strokeColor = Palette.steel
        tower.lineWidth = 2.5
        tower.zPosition = 4
        let boss = SKShapeNode(rect: CGRect(x: 26, y: 60, width: 5, height: 14), cornerRadius: 2)
        light(boss, color: Palette.red, glow: 2)
        tower.addChild(boss)
        figure.addChild(tower)
        shield = tower
    }

    /// A small gold sun on the chest: the Dawnfaith's mark.
    private func sunMark(at point: CGPoint, radius: CGFloat = 4) {
        let sun = SKShapeNode(circleOfRadius: radius)
        sun.position = point
        light(sun, color: Palette.gold, glow: 3)
        sun.zPosition = 2
        figure.addChild(sun)
    }

    /// Zealot: lean, hooded, a short tunic over bare legs, a curved blade held ready.
    private func buildZealot() {
        leg(x: -6, hipY: 38, length: 38, width: 8)
        leg(x: 6, hipY: 38, length: 38, width: 8)
        let tunic = CGMutablePath()
        tunic.addLines(between: [CGPoint(x: -10, y: 68), CGPoint(x: 10, y: 68), CGPoint(x: 14, y: 30), CGPoint(x: -14, y: 30)])
        tunic.closeSubpath()
        _ = part(tunic)
        let hood = CGMutablePath()
        hood.addLines(between: [CGPoint(x: -9, y: 66), CGPoint(x: 9, y: 68), CGPoint(x: 4, y: 86), CGPoint(x: -6, y: 84)])
        hood.closeSubpath()
        _ = part(hood, z: 1)
        let eyeDot = SKShapeNode(circleOfRadius: 1.8)
        eyeDot.position = CGPoint(x: 5, y: 76)
        light(eyeDot, color: Palette.gold, glow: 2)
        figure.addChild(eyeDot)
        eye = eyeDot
        sunMark(at: CGPoint(x: 0, y: 54))
        blade(length: 50, color: Palette.gold, at: CGPoint(x: 6, y: 56))
    }

    /// Radiant Acolyte: long robe, a small halo, a staff topped with a sun.
    private func buildAcolyte() {
        let robe = CGMutablePath()
        robe.addLines(between: [CGPoint(x: -8, y: 64), CGPoint(x: 9, y: 64), CGPoint(x: 15, y: 0), CGPoint(x: -15, y: 0)])
        robe.closeSubpath()
        _ = part(robe)
        _ = part(CGPath(ellipseIn: CGRect(x: -8, y: 62, width: 17, height: 17), transform: nil), z: 1)
        let ring = SKShapeNode(circleOfRadius: 10)
        ring.position = CGPoint(x: 0, y: 84)
        ring.fillColor = .clear
        ring.strokeColor = Palette.gold
        ring.lineWidth = 1.5
        ring.glowWidth = 3
        ring.yScale = 0.35
        ring.zPosition = 2
        figure.addChild(ring)
        let eyeDot = SKShapeNode(circleOfRadius: 1.8)
        eyeDot.position = CGPoint(x: 6, y: 71)
        light(eyeDot, color: Palette.gold, glow: 2)
        figure.addChild(eyeDot)
        eye = eyeDot
        blade(length: 54, color: Palette.ivory, at: CGPoint(x: 8, y: 44))
        let sun = SKShapeNode(circleOfRadius: 5)
        sun.position = CGPoint(x: 0, y: 54)
        light(sun, color: Palette.gold, glow: 6)
        weapon?.addChild(sun)
    }

    /// Solar Guard: broad armour, a round sun shield held forward, a short mace.
    private func buildSolarGuard() {
        leg(x: -10, hipY: 46, length: 46, width: 13)
        leg(x: 10, hipY: 46, length: 46, width: 13)
        _ = part(CGPath(roundedRect: CGRect(x: -21, y: 44, width: 42, height: 46), cornerWidth: 6, cornerHeight: 6, transform: nil))
        _ = part(CGPath(roundedRect: CGRect(x: -26, y: 82, width: 52, height: 12), cornerWidth: 5, cornerHeight: 5, transform: nil), z: 1)
        _ = part(CGPath(roundedRect: CGRect(x: -10, y: 92, width: 21, height: 20), cornerWidth: 6, cornerHeight: 6, transform: nil), z: 1)
        let visor = SKShapeNode(rect: CGRect(x: 1, y: 100, width: 9, height: 2.5))
        light(visor, color: Palette.gold, glow: 3)
        figure.addChild(visor)
        eye = visor
        blade(length: 58, color: Palette.gold, at: CGPoint(x: 4, y: 64))
        let disc = SKShapeNode(ellipseOf: CGSize(width: 16, height: 70))
        disc.position = CGPoint(x: 28, y: 58)
        disc.fillColor = Palette.body
        disc.strokeColor = Palette.gold
        disc.lineWidth = 2.5
        disc.zPosition = 4
        let boss = SKShapeNode(circleOfRadius: 4)
        light(boss, color: Palette.gold, glow: 4)
        disc.addChild(boss)
        figure.addChild(disc)
        shield = disc
    }

    /// Halo Disciple: a robed figure that floats, its robe trailing to a point, under a wide halo.
    private func buildDisciple() {
        let robe = CGMutablePath()
        robe.addLines(between: [CGPoint(x: -9, y: 54), CGPoint(x: 10, y: 54), CGPoint(x: 6, y: 6), CGPoint(x: -2, y: -10), CGPoint(x: -8, y: 8)])
        robe.closeSubpath()
        _ = part(robe)
        _ = part(CGPath(ellipseIn: CGRect(x: -7, y: 52, width: 16, height: 16), transform: nil), z: 1)
        let eyeDot = SKShapeNode(circleOfRadius: 1.8)
        eyeDot.position = CGPoint(x: 5, y: 61)
        light(eyeDot, color: Palette.gold, glow: 2)
        figure.addChild(eyeDot)
        eye = eyeDot
        let ring = SKShapeNode(circleOfRadius: 20)
        ring.position = CGPoint(x: 0, y: 62)
        ring.fillColor = .clear
        ring.strokeColor = Palette.gold
        ring.lineWidth = 3
        ring.glowWidth = 3
        ring.zPosition = -1
        figure.addChild(ring)
        halo = ring
        blade(length: 40, color: Palette.gold, at: CGPoint(x: 6, y: 40))
    }

    /// Sentry Core: a floating shell around one red lens.
    private func buildSentry() {
        _ = part(CGPath(ellipseIn: CGRect(x: -20, y: 0, width: 40, height: 40), transform: nil))
        let fin = CGMutablePath()
        fin.addLines(between: [CGPoint(x: -18, y: 30), CGPoint(x: -34, y: 46), CGPoint(x: -14, y: 38)])
        fin.closeSubpath()
        _ = part(fin, z: -1)
        let lens = SKShapeNode(circleOfRadius: 7)
        lens.position = CGPoint(x: 9, y: 20)
        light(lens, color: Palette.red, glow: 5)
        figure.addChild(lens)
        eye = lens
        zone.lineWidth = 1
        zone.zPosition = -3
        zone.isHidden = true
        addChild(zone)
    }

    /// Dogma Frame: a thin standing frame with a halo, and a faint circle showing how far its shield reaches.
    private func buildDogma() {
        leg(x: -7, hipY: 44, length: 44, width: 7)
        leg(x: 7, hipY: 44, length: 44, width: 7)
        _ = part(CGPath(roundedRect: CGRect(x: -11, y: 42, width: 22, height: 52), cornerWidth: 4, cornerHeight: 4, transform: nil))
        let halo = SKShapeNode(circleOfRadius: 17)
        halo.position = CGPoint(x: 0, y: 100)
        halo.fillColor = .clear
        halo.strokeColor = Palette.ember
        halo.lineWidth = 3
        halo.glowWidth = 4
        halo.zPosition = 2
        figure.addChild(halo)
        eye = halo
        let reach = SKShapeNode(circleOfRadius: CGFloat(Tuning().dogmaFrame.wardRadius))
        reach.position = CGPoint(x: 0, y: 55)
        reach.fillColor = Palette.ember.withAlphaComponent(0.04)
        reach.strokeColor = Palette.ember.withAlphaComponent(0.3)
        reach.lineWidth = 1
        reach.zPosition = -4
        addChild(reach)
        aura = reach
    }

    private func buildWard() {
        ward.fillColor = Palette.ember.withAlphaComponent(0.08)
        ward.strokeColor = Palette.ember
        ward.lineWidth = 2
        ward.glowWidth = 3
        ward.zPosition = 6
        ward.isHidden = true
        addChild(ward)
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

        // Flames under the feet, lit while it flies.
        for x in [-40.0, 40.0] {
            let path = CGMutablePath()
            path.addLines(between: [CGPoint(x: -14, y: 0), CGPoint(x: 14, y: 0), CGPoint(x: 0, y: -46)])
            path.closeSubpath()
            let flame = SKShapeNode(path: path)
            flame.position = CGPoint(x: x, y: 2)
            flame.fillColor = Palette.ember
            flame.strokeColor = Palette.gold
            flame.glowWidth = 8
            flame.zPosition = -2
            flame.isHidden = true
            figure.addChild(flame)
            thrusters.append(flame)
        }
    }

    /// Where the attack will land, drawn faint through the warning and bright on the strike.
    private func animateZone(_ f: Fighter) {
        guard kind == .theProtocol || kind == .sentryCore else { return }
        guard case .attack(let index) = f.state, let a = f.currentAttack, f.attackPhase != .recovery,
              a.effect == .strike else {
            zone.isHidden = true
            zoneAttack = -1
            return
        }
        if zoneAttack != index {
            zoneAttack = index
            let travel = a.holdsStill ? a.lunge * Double(a.active) / Tuning.framesPerSecond : 0
            let far = f.spec.width / 2 + a.reach + travel
            let from = a.bothSides ? -far : 0
            zone.path = CGPath(rect: CGRect(x: from, y: a.yOffset, width: far - from, height: a.height), transform: nil)
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

    /// Soft light around the eyes, and behind The Protocol's core.
    private func addGlows() {
        if let eye, kind != .dummy {
            let size: CGFloat = kind == .theProtocol ? 110 : (kind == .dogmaFrame ? 70 : 38)
            let color = kind == .dogmaFrame ? Palette.ember : rim
            let glow = Effects.glow(color: color, size: size, alpha: 0.45)
            glow.position = CGPoint(x: eye.frame.midX, y: eye.frame.midY)
            glow.zPosition = 1.5
            figure.addChild(glow)
            eyeGlow = glow
        }
        if let core {
            let glow = Effects.glow(color: Palette.gold, size: 190, alpha: 0)
            glow.position = core.position
            glow.zPosition = 2.5
            figure.addChild(glow)
            coreGlow = glow
        }
    }

    /// A fading copy of the figure, left behind by a dodge or a charge.
    private func leaveGhost(frame: Int) {
        guard frame != lastGhostFrame, frame % 3 == 0, let parent, let copy = figure.copy() as? SKNode else { return }
        lastGhostFrame = frame
        func tint(_ node: SKNode) {
            if let shape = node as? SKShapeNode, shape.fillColor != .clear {
                shape.fillColor = rim.withAlphaComponent(0.35)
                shape.strokeColor = rim.withAlphaComponent(0.6)
            }
            node.children.forEach(tint)
        }
        tint(copy)
        let ghost = SKNode()
        ghost.position = position
        ghost.xScale = xScale
        ghost.zPosition = zPosition - 1
        ghost.alpha = 0.5
        ghost.addChild(copy)
        parent.addChild(ghost)
        ghost.run(.sequence([.fadeOut(withDuration: 0.22), .removeFromParent()]))
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

    func sync(_ f: Fighter, frame: Int, controlled: Bool = false, warded: Bool = false) {
        guard !gone else { return }
        ward.isHidden = !warded
        if warded, ward.path == nil {
            let w = CGFloat(f.spec.width) + 22, h = CGFloat(f.spec.height) + 18
            ward.path = CGPath(roundedRect: CGRect(x: -w / 2, y: -6, width: w, height: h), cornerWidth: 12, cornerHeight: 12, transform: nil)
        }
        ward.alpha = 0.6 + 0.3 * sin(CGFloat(frame) * 0.15)
        aura?.isHidden = !f.isAlive || !f.awake
        marker.isHidden = !controlled || !f.isAlive
        marker.position = CGPoint(x: 0, y: f.spec.height + 12 + 2 * sin(CGFloat(frame) * 0.12))
        position = CGPoint(x: f.pos.x, y: f.pos.y)
        if let halo {
            // The flare gathers on the halo through its windup, the cue to look away.
            var gather: CGFloat = 0
            if case .attack(0) = f.state, let a = f.currentAttack, f.attackPhase == .windup {
                gather = CGFloat(f.stateFrame) / CGFloat(max(a.windup, 1))
            }
            halo.setScale(1 + gather * 0.9)
            halo.glowWidth = 3 + gather * 14
            halo.lineWidth = 3 + gather * 3
        }
        mark.isHidden = f.markedFrames == 0 || !f.isAlive
        mark.position = CGPoint(x: 0, y: f.spec.height + 22)
        mark.zRotation = CGFloat(frame) * 0.05
        // The mark blinks as it runs out.
        mark.alpha = f.markedFrames < 90 && (frame / 6) % 2 == 0 ? 0.3 : 1
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
        case .phaseShift:
            // Changing form: it shudders and flashes gold.
            stretch = CGSize(width: 1 + 0.03 * sin(CGFloat(frame) * 0.9), height: 1.02)
            if (frame / 4) % 2 == 0 { tint = Palette.gold }
        case .guardStance:
            // Braced: low, wide, lit.
            stretch = CGSize(width: 1.12, height: 0.92)
            tint = Palette.cyan
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
        if f.isAlive, f.state == .dodge || (f.currentAttack?.holdsStill == true && f.attackPhase == .active) {
            leaveGhost(frame: frame)
        }
        eyeGlow?.isHidden = !f.isAlive || (kind == .theProtocol && !f.awake)
        if let coreGlow {
            let open = f.isOpen && f.isAlive && f.awake
            coreGlow.alpha = open ? 0.55 + 0.15 * sin(CGFloat(frame) * 0.4) : 0
        }
        animateZone(f)
        animateCore(f, frame: frame)
        if kind == .theProtocol {
            let lit = f.isAlive && (f.flying || (!f.onGround && f.phase == 2))
            for (n, flame) in thrusters.enumerated() {
                flame.isHidden = !lit
                flame.yScale = 0.8 + 0.3 * abs(sin(CGFloat(frame + n * 7) * 0.5))
            }
            if f.phase >= 3, !executionLook {
                executionLook = true
                for p in bodyParts { p.strokeColor = Palette.gold.withAlphaComponent(0.85) }
                rim = Palette.gold
            }
        }
        if kind == .sentryCore, f.isAlive {
            figure.position.y += 4 * sin(CGFloat(frame) * 0.1)
        }
        if f.slowFrames > 0, f.isAlive, (frame / 4) % 2 == 0 {
            for p in bodyParts { p.strokeColor = Palette.ember }
        } else if f.team == .hero {
            for p in bodyParts where p.strokeColor != rim.withAlphaComponent(0.45) { p.strokeColor = rim.withAlphaComponent(0.45) }
        }
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

    /// Seraphine: an ivory gown, a crown of gold rays, a staff with a sun at its head.
    private func buildSeraphine() {
        let gown = CGMutablePath()
        gown.addLines(between: [
            CGPoint(x: -8, y: 66), CGPoint(x: 9, y: 66), CGPoint(x: 15, y: 0), CGPoint(x: -17, y: 0),
        ])
        gown.closeSubpath()
        _ = part(gown)
        _ = part(CGPath(ellipseIn: CGRect(x: -8, y: 66, width: 18, height: 18), transform: nil), z: 1)
        for i in 0..<5 {
            let angle = CGFloat.pi / 2 + CGFloat(i - 2) * 0.38
            let ray = SKShapeNode(rect: CGRect(x: -0.9, y: 0, width: 1.8, height: 8))
            ray.position = CGPoint(x: 1 + cos(angle) * 10, y: 75 + sin(angle) * 10)
            ray.zRotation = angle - .pi / 2
            light(ray, color: Palette.gold, glow: 2)
            figure.addChild(ray)
        }
        let dot = SKShapeNode(circleOfRadius: 1.8)
        dot.position = CGPoint(x: 7, y: 76)
        light(dot, color: Palette.gold, glow: 2)
        figure.addChild(dot)
        eye = dot
        blade(length: 64, color: Palette.gold, at: CGPoint(x: 6, y: 50))
        let sun = SKShapeNode(circleOfRadius: 5)
        sun.position = CGPoint(x: 0, y: 64)
        light(sun, color: Palette.gold, glow: 5)
        weapon?.addChild(sun)
    }

    /// Nimue: black and violet, long hair, a red lantern carried low, short throwing blades.
    private func buildNimue() {
        leg(x: -5, hipY: 30, length: 30, width: 7)
        leg(x: 5, hipY: 30, length: 30, width: 7)
        _ = part(CGPath(roundedRect: CGRect(x: -9, y: 28, width: 18, height: 34), cornerWidth: 5, cornerHeight: 5, transform: nil))
        let hair = CGMutablePath()
        hair.addLines(between: [
            CGPoint(x: -8, y: 78), CGPoint(x: 4, y: 80), CGPoint(x: -4, y: 66), CGPoint(x: -14, y: 40),
            CGPoint(x: -17, y: 50),
        ])
        hair.closeSubpath()
        _ = part(hair, z: -1)
        _ = part(CGPath(ellipseIn: CGRect(x: -7, y: 62, width: 17, height: 17), transform: nil), z: 1)
        let dot = SKShapeNode(circleOfRadius: 1.8)
        dot.position = CGPoint(x: 6, y: 72)
        light(dot, color: Palette.violet, glow: 2)
        figure.addChild(dot)
        eye = dot
        let lantern = SKShapeNode(rect: CGRect(x: -3, y: -4, width: 6, height: 8), cornerRadius: 2)
        lantern.position = CGPoint(x: -12, y: 22)
        light(lantern, color: Palette.lantern, glow: 5)
        figure.addChild(lantern)
        let glow = Effects.glow(color: Palette.lantern, size: 46, alpha: 0.5)
        glow.position = lantern.position
        glow.zPosition = 1.5
        figure.addChild(glow)
        blade(length: 30, color: Palette.violet, at: CGPoint(x: 6, y: 48))
    }

    // MARK: The Lantern Cities

    /// Ember eyes under a hood or brim.
    private func emberEyes(at point: CGPoint, gap: CGFloat = 5) {
        let pair = SKNode()
        for dx in [0, gap] {
            let dot = SKShapeNode(circleOfRadius: 1.6)
            dot.position = CGPoint(x: point.x + dx, y: point.y)
            light(dot, color: Palette.ember, glow: 2)
            pair.addChild(dot)
        }
        pair.zPosition = 2
        figure.addChild(pair)
    }

    /// Ratborn: small and hunched, hood forward, a short knife.
    private func buildRatborn() {
        leg(x: -6, hipY: 20, length: 20, width: 7)
        leg(x: 6, hipY: 20, length: 20, width: 7)
        let body = CGMutablePath()
        body.addLines(between: [
            CGPoint(x: -12, y: 18), CGPoint(x: 10, y: 18), CGPoint(x: 16, y: 40), CGPoint(x: 4, y: 50),
            CGPoint(x: -12, y: 42),
        ])
        body.closeSubpath()
        _ = part(body)
        let hood = CGMutablePath()
        hood.addLines(between: [CGPoint(x: -2, y: 44), CGPoint(x: 22, y: 50), CGPoint(x: 12, y: 60), CGPoint(x: -4, y: 56)])
        hood.closeSubpath()
        _ = part(hood, z: 1)
        emberEyes(at: CGPoint(x: 11, y: 51), gap: 4)
        blade(length: 22, color: Palette.ember, at: CGPoint(x: 10, y: 30))
    }

    /// Lantern Gunner: a long coat, a wide brim, a lantern held ready to throw.
    private func buildGunner() {
        leg(x: -6, hipY: 30, length: 30, width: 8)
        leg(x: 6, hipY: 30, length: 30, width: 8)
        let coat = CGMutablePath()
        coat.addLines(between: [CGPoint(x: -15, y: 14), CGPoint(x: 15, y: 14), CGPoint(x: 11, y: 62), CGPoint(x: -11, y: 62)])
        coat.closeSubpath()
        _ = part(coat)
        _ = part(CGPath(ellipseIn: CGRect(x: -8, y: 60, width: 16, height: 16), transform: nil), z: 1)
        _ = part(CGPath(rect: CGRect(x: -17, y: 72, width: 34, height: 4), transform: nil), z: 2)
        emberEyes(at: CGPoint(x: 3, y: 67))
        let lantern = SKShapeNode(rect: CGRect(x: -4, y: -5, width: 8, height: 10), cornerRadius: 2)
        lantern.position = CGPoint(x: 18, y: 40)
        light(lantern, color: Palette.ember, glow: 5)
        figure.addChild(lantern)
        let glow = Effects.glow(color: Palette.ember, size: 54, alpha: 0.5)
        glow.position = lantern.position
        glow.zPosition = 1.5
        figure.addChild(glow)
    }

    /// Smuggler Brute: a wall of a body, a small head, a cargo hook.
    private func buildBrute() {
        leg(x: -14, hipY: 40, length: 40, width: 16)
        leg(x: 14, hipY: 40, length: 40, width: 16)
        _ = part(CGPath(roundedRect: CGRect(x: -30, y: 36, width: 60, height: 52), cornerWidth: 14, cornerHeight: 14,
                        transform: nil))
        _ = part(CGPath(ellipseIn: CGRect(x: -9, y: 84, width: 20, height: 20), transform: nil), z: 1)
        emberEyes(at: CGPoint(x: 3, y: 94))
        // A strap of lanterns across the chest.
        for (n, x) in [-16.0, -4.0, 8.0].enumerated() {
            let lamp = SKShapeNode(circleOfRadius: 2.5)
            lamp.position = CGPoint(x: x, y: 70 - Double(n) * 6)
            light(lamp, color: Palette.ember, glow: 3)
            figure.addChild(lamp)
        }
        blade(length: 70, color: Palette.ember, at: CGPoint(x: 20, y: 70))
    }

    /// Night Weaver: tall and thin, a cloak that ends in threads.
    private func buildWeaver() {
        leg(x: -4, hipY: 26, length: 26, width: 6)
        leg(x: 4, hipY: 26, length: 26, width: 6)
        let cloak = CGMutablePath()
        cloak.addLines(between: [
            CGPoint(x: -16, y: 10), CGPoint(x: -8, y: 18), CGPoint(x: 0, y: 8), CGPoint(x: 8, y: 18), CGPoint(x: 16, y: 10),
            CGPoint(x: 9, y: 70), CGPoint(x: -9, y: 70),
        ])
        cloak.closeSubpath()
        _ = part(cloak)
        let hood = CGMutablePath()
        hood.addLines(between: [CGPoint(x: -9, y: 66), CGPoint(x: 9, y: 66), CGPoint(x: 6, y: 86), CGPoint(x: -2, y: 90)])
        hood.closeSubpath()
        _ = part(hood, z: 1)
        let eyes = SKShapeNode(rect: CGRect(x: 0, y: 77, width: 6, height: 2))
        light(eyes, color: Palette.violet, glow: 3)
        figure.addChild(eyes)
        eye = eyes
        // Threads of light between the hands.
        let thread = CGMutablePath()
        thread.move(to: CGPoint(x: -12, y: 44))
        thread.addQuadCurve(to: CGPoint(x: 14, y: 44), control: CGPoint(x: 1, y: 30))
        let line = SKShapeNode(path: thread)
        line.strokeColor = Palette.violet.withAlphaComponent(0.8)
        line.lineWidth = 1
        line.glowWidth = 2
        line.zPosition = 3
        figure.addChild(line)
    }

    /// The Cinder King: a long coat over a broad frame, a crown of embers, lanterns on chains, a long cane.
    private func buildCinderKing() {
        leg(x: -16, hipY: 50, length: 50, width: 16)
        leg(x: 16, hipY: 50, length: 50, width: 16)
        let coat = CGMutablePath()
        coat.addLines(between: [
            CGPoint(x: -40, y: 6), CGPoint(x: 40, y: 6), CGPoint(x: 34, y: 112), CGPoint(x: 46, y: 124),
            CGPoint(x: -46, y: 124), CGPoint(x: -34, y: 112),
        ])
        coat.closeSubpath()
        _ = part(coat)
        _ = part(CGPath(ellipseIn: CGRect(x: -13, y: 120, width: 26, height: 26), transform: nil), z: 1)
        emberEyes(at: CGPoint(x: 3, y: 134), gap: 6)
        // The crown: points of ember light.
        for (n, x) in [-12.0, -6.0, 0.0, 6.0, 12.0].enumerated() {
            let point = CGMutablePath()
            let tall = n == 2 ? 14.0 : 9.0
            point.addLines(between: [CGPoint(x: x - 3, y: 144), CGPoint(x: x + 3, y: 144), CGPoint(x: x, y: 144 + tall)])
            point.closeSubpath()
            let node = SKShapeNode(path: point)
            light(node, color: Palette.ember, glow: 4)
            figure.addChild(node)
        }
        // Lanterns hanging from the belt.
        for x in [-28.0, -10.0, 26.0] {
            let chain = SKShapeNode(rect: CGRect(x: x - 0.5, y: 52, width: 1, height: 14))
            chain.strokeColor = Palette.gold.withAlphaComponent(0.6)
            chain.zPosition = 2
            figure.addChild(chain)
            let lamp = SKShapeNode(rect: CGRect(x: x - 4, y: 42, width: 8, height: 10), cornerRadius: 2)
            light(lamp, color: Palette.ember, glow: 5)
            figure.addChild(lamp)
        }
        let glow = Effects.glow(color: Palette.ember, size: 120, alpha: 0.35)
        glow.position = CGPoint(x: 0, y: 50)
        glow.zPosition = -1.5
        figure.addChild(glow)
        blade(length: 110, color: Palette.gold, at: CGPoint(x: 30, y: 96))
    }

    /// A Weaver's image: the same figure, thinner, flickering.
    private func buildWeaverImage() {
        buildWeaver()
        for node in bodyParts {
            node.fillColor = Palette.violet.withAlphaComponent(0.12)
            node.strokeColor = Palette.violet.withAlphaComponent(0.7)
        }
        figure.alpha = 0.7
        figure.run(.repeatForever(.sequence([.fadeAlpha(to: 0.45, duration: 0.25), .fadeAlpha(to: 0.75, duration: 0.35)])))
    }

    /// Nimue's stand-in: her outline in lantern light, see-through.
    private func buildDecoy() {
        buildNimue()
        for node in bodyParts {
            node.fillColor = Palette.violet.withAlphaComponent(0.18)
            node.strokeColor = Palette.violet.withAlphaComponent(0.8)
        }
        figure.alpha = 0.75
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
        case .seraphine: [(0.4, -1.9), (-1.57, -1.57)]
        case .nimue: [(0.6, -1.8), (0.3, -1.9), (1.2, -2.2)]
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
                // Seraphine's second strike and all of Nimue's reach out past the weapon: draw how far.
                if (kind == .seraphine && index == 1) || kind == .nimue {
                    drawStreak(length: CGFloat(a.reach), y: CGFloat(a.yOffset + a.height / 2), width: kind == .nimue ? 3 : 6)
                } else {
                    drawArc(from: from, to: to, radius: weaponLength)
                }
            }
        case .recovery, .none:
            let t = (frame - CGFloat(a.windup + a.active)) / CGFloat(max(a.recovery, 1))
            weaponPivot.zRotation = to + (rest - to) * t * t
        }
    }

    private var weaponLength: CGFloat {
        switch kind {
        case .caelen: 62
        case .orion: 46
        case .seraphine: 64
        case .nimue: 30
        case .ratborn: 22
        case .smugglerBrute: 70
        case .cinderKing: 110
        case .lineWarden: 96
        case .zealot: 50
        case .radiantAcolyte: 54
        case .solarGuard: 58
        case .haloDisciple: 40
        default: 76
        }
    }

    /// A bolt of light or a thrown blade's path, straight out from the body.
    private func drawStreak(length: CGFloat, y: CGFloat, width: CGFloat) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 12, y: y))
        path.addLine(to: CGPoint(x: 12 + length, y: y))
        let streak = SKShapeNode(path: path)
        streak.strokeColor = rim
        streak.lineWidth = width
        streak.glowWidth = width
        streak.lineCap = .round
        streak.zPosition = 5
        figure.addChild(streak)
        streak.run(.sequence([.fadeOut(withDuration: 0.18), .removeFromParent()]))
    }

    private func drawArc(from: CGFloat, to: CGFloat, radius: CGFloat) {
        let path = CGMutablePath()
        path.addArc(center: .zero, radius: radius, startAngle: from + .pi / 2, endAngle: to + .pi / 2, clockwise: to < from)
        let arc = SKShapeNode(path: path)
        arc.position = weaponPivot.position
        arc.strokeColor = rim
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
