import ActionCore
import SpriteKit
import UIKit

/// Draws the simulation and feeds it input. It never decides an outcome: it steps `World` at a fixed 60 Hz
/// and reacts to the events that come back.
final class GameScene: SKScene {
    private let demo: Bool
    private var world: World
    private var hardware = HardwareInput()
    private let controls = TouchControls()
    private let hud = HUD()

    private let farLayer = SKNode()
    private let midLayer = SKNode()
    private let worldNode = SKNode()
    private var nodes: [Int: FighterNode] = [:]

    private var lastTime: TimeInterval = 0
    private var accumulator = 0.0
    private var cameraX: CGFloat = 0
    private var shake: CGFloat = 0
    private var run = 0
    private var kills = 0

    private let groundY: CGFloat = 104
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)

    init(demo: Bool) {
        self.demo = demo
        world = World.partnerSlice(seed: 1)
        super.init(size: CGSize(width: 874, height: 402))
        scaleMode = .resizeFill
        backgroundColor = Palette.sky
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        view.ignoresSiblingOrder = true
        guard worldNode.parent == nil else { return }
        farLayer.zPosition = -30
        midLayer.zPosition = -20
        worldNode.zPosition = 0
        addChild(farLayer)
        addChild(midLayer)
        addChild(worldNode)
        addChild(hud)
        if !demo { addChild(controls) }
        buildRoom()
        layout()
        hud.showHint(demo ? "DEMO" : "Parry: attack just as the red flash comes.  Dodge passes through.  ⇄ switches hero.")
        if let hero = world.controlled { cameraX = hero.pos.x }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        layout()
    }

    private func layout() {
        let insets = view?.safeAreaInsets ?? .zero
        controls.layout(size: size, insets: insets)
        hud.layout(size: size, insets: insets)
    }

    private func restart() {
        run += 1
        kills = 0
        world = World.partnerSlice(seed: UInt64(run + 1))
        nodes.values.forEach { $0.removeFromParent() }
        nodes = [:]
        hud.hideMessage()
        if let hero = world.controlled { cameraX = hero.pos.x }
    }

    // MARK: Room

    private func buildRoom() {
        let arena = world.arena
        let width = arena.upperBound - arena.lowerBound

        // Far: tall cathedral windows glowing faintly.
        var x = -200.0
        while x < width + 400 {
            let window = SKShapeNode(rect: CGRect(x: x, y: 60, width: 46, height: 300), cornerRadius: 23)
            window.fillColor = Palette.far
            window.strokeColor = Palette.cyan.withAlphaComponent(0.12)
            window.lineWidth = 2
            farLayer.addChild(window)
            x += 150
        }
        // Mid: pillars and pipework.
        x = -100.0
        while x < width + 300 {
            let pillar = SKShapeNode(rect: CGRect(x: x, y: -10, width: 54, height: 520))
            pillar.fillColor = Palette.mid
            pillar.strokeColor = .clear
            midLayer.addChild(pillar)
            let strip = SKShapeNode(rect: CGRect(x: x + 25, y: 40, width: 3, height: 150))
            strip.fillColor = Palette.cyan.withAlphaComponent(0.35)
            strip.strokeColor = .clear
            strip.glowWidth = 2
            midLayer.addChild(strip)
            x += 310
        }

        let floor = SKShapeNode(rect: CGRect(x: arena.lowerBound - 600, y: -300, width: width + 1200, height: 300))
        floor.fillColor = Palette.floor
        floor.strokeColor = .clear
        floor.zPosition = -5
        worldNode.addChild(floor)
        let edge = SKShapeNode(rect: CGRect(x: arena.lowerBound - 600, y: -2, width: width + 1200, height: 2))
        edge.fillColor = Palette.cyan.withAlphaComponent(0.5)
        edge.strokeColor = .clear
        edge.glowWidth = 1
        edge.zPosition = -4
        worldNode.addChild(edge)
        for bound in [arena.lowerBound, arena.upperBound] {
            let wall = SKShapeNode(rect: CGRect(x: bound - 2, y: 0, width: 4, height: 420))
            wall.fillColor = Palette.cyan.withAlphaComponent(0.25)
            wall.strokeColor = .clear
            wall.glowWidth = 3
            wall.zPosition = -4
            worldNode.addChild(wall)
        }
    }

    // MARK: Loop

    override func update(_ currentTime: TimeInterval) {
        let elapsed = lastTime == 0 ? 0 : min(currentTime - lastTime, 0.1)
        lastTime = currentTime
        accumulator += elapsed

        let reading = hardware.poll()
        var presses = controls.takePresses()
        if reading.restart || (world.isOver && (!presses.isEmpty || reading.attack || reading.jump)) {
            restart()
            presses = []
        } else if world.isOver, demo {
            restart()
        }

        var input = InputFrame()
        input.moveX = reading.moveX != 0 ? reading.moveX : controls.moveX
        input.jumpHeld = reading.jumpHeld || controls.jumpHeld
        input.jump = reading.jump || presses.contains(.jump)
        input.attack = reading.attack || presses.contains(.attack)
        input.dodge = reading.dodge || presses.contains(.dodge)
        input.switchHero = reading.switchHero || presses.contains(.switchHero)

        let step = 1 / Tuning.framesPerSecond
        var steps = 0
        while accumulator >= step, steps < 4 {
            let frameInput = demo ? DemoBot.input(for: world) : input
            react(to: world.step(frameInput))
            // A press belongs to one simulation frame only.
            input.jump = false
            input.attack = false
            input.dodge = false
            input.switchHero = false
            accumulator -= step
            steps += 1
        }
        if steps == 4 { accumulator = 0 }

        draw()
    }

    private func draw() {
        var seen: Set<Int> = []
        for f in world.fighters {
            seen.insert(f.id)
            let node = nodes[f.id] ?? {
                let created = FighterNode(kind: f.kind)
                created.zPosition = f.team == .hero ? 10 : 5
                worldNode.addChild(created)
                nodes[f.id] = created
                return created
            }()
            node.sync(f, frame: world.frame, controlled: f.id == world.controlledID)
        }
        for (id, node) in nodes where !seen.contains(id) {
            node.removeFromParent()
            nodes[id] = nil
        }

        if let hero = world.controlled {
            let half = size.width / 2
            let low = world.arena.lowerBound + half - 60
            let high = world.arena.upperBound - half + 60
            let target = min(max(hero.pos.x + hero.facing * 40, low), max(low, high))
            cameraX += (target - cameraX) * 0.12
            let partner = world.fighters.first { $0.team == .hero && $0.id != hero.id }
            hud.setHeroes(
                lead: (hero.kind.rawValue.uppercased(), hero.hp / hero.spec.maxHP),
                partner: partner.map { ($0.kind.rawValue.uppercased(), $0.hp / $0.spec.maxHP) })
        }
        shake *= 0.86
        let jolt = shake < 0.3 ? CGPoint.zero : CGPoint(
            x: CGFloat.random(in: -shake...shake), y: CGFloat.random(in: -shake...shake))
        worldNode.position = CGPoint(x: size.width / 2 - cameraX + jolt.x, y: groundY + jolt.y)
        midLayer.position = CGPoint(x: -cameraX * 0.55, y: groundY - 20)
        farLayer.position = CGPoint(x: -cameraX * 0.25, y: groundY - 10)
        hud.setStatus(wave: world.waveNumber, kills: kills)
    }

    // MARK: Events

    private func react(to events: [GameEvent]) {
        for event in events {
            switch event {
            case .hit(let attacker, let target, let damage, let at):
                nodes[target]?.flash()
                let heroHurt = world.fighter(target)?.team == .hero
                sparks(at: at, color: heroHurt ? Palette.red : Palette.cyan, count: heroHurt ? 10 : Int(4 + damage / 3))
                if heroHurt {
                    shake = max(shake, 9)
                    heavy.impactOccurred()
                    hud.flashDamage()
                } else {
                    shake = max(shake, damage >= 20 ? 6 : 2)
                    light.impactOccurred(intensity: damage >= 20 ? 1 : 0.6)
                }
                _ = attacker
            case .blocked(_, _, let at):
                sparks(at: at, color: Palette.steel, count: 4)
                popup("BLOCKED", at: at, color: Palette.steel, size: 13)
                rigid.impactOccurred(intensity: 0.5)
            case .parried(_, let attacker, let at):
                ring(at: at, radius: 70, color: Palette.white)
                sparks(at: at, color: Palette.white, count: 14)
                popup("PARRY", at: at, color: Palette.cyan, size: 20)
                nodes[attacker]?.flash()
                shake = max(shake, 5)
                rigid.impactOccurred()
            case .exploded(let id, let at, let radius):
                ring(at: at, radius: radius, color: Palette.ember)
                sparks(at: at, color: Palette.ember, count: 18)
                shake = max(shake, 10)
                nodes[id]?.vanish()
                heavy.impactOccurred()
            case .fuseLit(let id):
                if let f = world.fighter(id) {
                    popup("!", at: Vec2(f.pos.x, f.pos.y + 60), color: Palette.red, size: 22)
                }
            case .died(let id):
                if world.fighter(id)?.team == .enemy { kills += 1 }
            case .waveStarted(let number):
                hud.announce("WAVE \(number)")
            case .waveCleared:
                hud.announce("CLEAR")
            case .controlChanged(let id):
                if let f = world.fighter(id) {
                    ring(at: Vec2(f.pos.x, f.pos.y + f.spec.height / 2), radius: 60, color: Palette.cyan)
                }
                light.impactOccurred()
            case .revived(let id):
                if let f = world.fighter(id) {
                    ring(at: Vec2(f.pos.x, f.pos.y + f.spec.height / 2), radius: 80, color: Palette.white)
                    popup("BACK UP", at: Vec2(f.pos.x, f.pos.y + f.spec.height), color: Palette.cyan, size: 14)
                }
            case .heroDown:
                hud.showMessage(demo ? "DOWN" : "DOWN\ntap to try again")
            case .spawned, .swing, .evaded, .jumped, .landed, .dodged:
                break
            }
        }
    }

    private func sparks(at point: Vec2, color: SKColor, count: Int) {
        for _ in 0..<count {
            let spark = SKShapeNode(rect: CGRect(x: -4, y: -1, width: 8, height: 2))
            spark.fillColor = color
            spark.strokeColor = .clear
            spark.glowWidth = 1
            spark.position = CGPoint(x: point.x, y: point.y)
            spark.zPosition = 20
            let angle = CGFloat.random(in: 0..<(2 * .pi))
            let distance = CGFloat.random(in: 24...70)
            spark.zRotation = angle
            worldNode.addChild(spark)
            spark.run(.sequence([
                .group([
                    .moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: 0.22),
                    .fadeOut(withDuration: 0.22),
                ]),
                .removeFromParent(),
            ]))
        }
    }

    private func ring(at point: Vec2, radius: CGFloat, color: SKColor) {
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.strokeColor = color
        ring.fillColor = color.withAlphaComponent(0.18)
        ring.lineWidth = 4
        ring.glowWidth = 4
        ring.position = CGPoint(x: point.x, y: point.y)
        ring.zPosition = 19
        ring.setScale(0.25)
        worldNode.addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 1, duration: 0.18), .fadeOut(withDuration: 0.26)]),
            .removeFromParent(),
        ]))
    }

    private func popup(_ text: String, at point: Vec2, color: SKColor, size: CGFloat) {
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = size
        label.fontColor = color
        label.position = CGPoint(x: point.x, y: point.y + 30)
        label.zPosition = 25
        worldNode.addChild(label)
        label.run(.sequence([
            .group([.moveBy(x: 0, y: 34, duration: 0.5), .sequence([.wait(forDuration: 0.25), .fadeOut(withDuration: 0.25)])]),
            .removeFromParent(),
        ]))
    }

    // MARK: Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { controls.began(touch, at: touch.location(in: self)) }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { controls.moved(touch, to: touch.location(in: self)) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { controls.ended(touch) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { controls.ended(touch) }
    }
}
