import ActionCore
import SpriteKit

/// Draws the simulation and feeds it input. It never decides an outcome: it steps `World` at a fixed 60 Hz
/// and reacts to the events that come back.
final class GameScene: SKScene {
    enum Mode {
        /// The level: platforms, hazards, checkpoints, a way out.
        case level
        /// The flat training room with waves, and Orion at Caelen's side.
        case room
    }

    private let demo: Bool
    private var mode: Mode
    private var world: World
    private var pilot = Autopilot(fights: true)
    private var showDebug = true
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
    private var cameraY: CGFloat = 0
    private var platformNodes: [Int: SKNode] = [:]
    private var hazardNodes: [SKShapeNode] = []
    private var checkpointNodes: [SKShapeNode] = []
    private var pickupNodes: [Int: SKNode] = [:]
    private var shake: CGFloat = 0
    private var run = 0
    private var kills = 0

    private let groundY: CGFloat = 104
    private let haptics = Haptics()
    private let levels = Level.all
    /// Which level is being played. Remembered between launches.
    private var levelIndex: Int {
        didSet { UserDefaults.standard.set(levelIndex, forKey: "levelIndex") }
    }
    private var level: Level { levels[levelIndex] }

    /// World units are scaled so about the same slice of the level shows on a phone, a tablet and a Mac window.
    /// A boss room is seen from further back, so the boss fits under the bars at the top.
    private var zoom: CGFloat {
        max(0.5, min(size.height / 402, size.width / 700)) * (mode == .level && level.boss != nil ? 0.8 : 1)
    }

    init(demo: Bool, mode: Mode = .level) {
        self.demo = demo
        self.mode = mode
        // `-level 2` starts on the third level, for checking one without playing up to it.
        let args = ProcessInfo.processInfo.arguments
        let asked = args.firstIndex(of: "-level").flatMap { $0 + 1 < args.count ? Int(args[$0 + 1]) : nil }
        let saved = asked ?? (demo ? 0 : UserDefaults.standard.integer(forKey: "levelIndex"))
        levelIndex = min(max(saved, 0), Level.all.count - 1)
        world = mode == .level ? World(level: Level.all[levelIndex], seed: 1) : World.partnerSlice(seed: 1)
        super.init(size: CGSize(width: 874, height: 402))
        scaleMode = .resizeFill
        backgroundColor = Palette.sky
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        #if os(iOS)
        view.isMultipleTouchEnabled = true
        #endif
        view.ignoresSiblingOrder = true
        guard worldNode.parent == nil else { return }
        farLayer.zPosition = -30
        midLayer.zPosition = -20
        worldNode.zPosition = 0
        addChild(farLayer)
        addChild(midLayer)
        addChild(worldNode)
        addChild(hud)
        #if os(iOS)
        if !demo { addChild(controls) }
        #endif
        buildScenery()
        layout()
        showHint()
        if let hero = world.controlled { cameraX = hero.pos.x }
    }

    private let bossHint = "Strike only when the core opens.  Jump the surge.  Dodge the charge."

    private func showHint() {
        if demo {
            hud.showHint("DEMO")
            return
        }
        #if os(iOS)
        hud.showHint(mode == .level
            ? "Reach the gate.  Dodge passes through the arc.  ⇄ switches hero.  MODE changes level."
            : "Parry: attack just as the red flash comes.  Dodge passes through.  ⇄ switches hero.")
        #else
        hud.showHint("A/D move   Space jump   J attack   K dodge   L switch   R restart   M mode   P debug")
        #endif
    }

    override func didChangeSize(_ oldSize: CGSize) {
        layout()
    }

    private func layout() {
        let insets = view?.insets ?? .zero
        controls.layout(size: size, insets: insets)
        hud.layout(size: size, insets: insets)
    }

    /// A retry after falling in battle resumes from the last checkpoint; anything else starts over.
    private func restart(fresh: Bool = false) {
        run += 1
        let seed = UInt64(run + 1)
        switch mode {
        case .room:
            kills = 0
            world = World.partnerSlice(seed: seed)
        case .level:
            // Clearing a level moves on to the next one; the last one loops back to the first.
            if !fresh, world.isComplete { levelIndex = (levelIndex + 1) % levels.count }
            let resume = !fresh && world.level != nil && !world.isComplete
            if !resume { kills = 0 }
            world = World(level: level, seed: seed, fromCheckpoint: resume ? world.checkpointIndex : -1,
                          collected: resume ? world.collected : [])
            pilot = Autopilot(fights: true)
        }
        nodes.values.forEach { $0.removeFromParent() }
        nodes = [:]
        hud.hideMessage()
        buildScenery()
        if let hero = world.controlled {
            cameraX = hero.pos.x
            cameraY = max(-40, hero.pos.y - 70)
        }
        if mode == .level, world.checkpointIndex < 0 { hud.announce(level.name.uppercased()) }
    }

    /// Steps through every level and then the training room.
    private func toggleMode() {
        if mode == .room {
            mode = .level
            levelIndex = 0
        } else if levelIndex + 1 < levels.count {
            levelIndex += 1
        } else {
            mode = .room
        }
        restart(fresh: true)
        showHint()
        if mode == .room { hud.announce("TRAINING ROOM") }
    }

    // MARK: Scenery

    private func buildScenery() {
        farLayer.removeAllChildren()
        midLayer.removeAllChildren()
        worldNode.removeAllChildren()
        platformNodes = [:]
        hazardNodes = []
        checkpointNodes = []
        pickupNodes = [:]
        buildBackdrop()
        if let level = world.level { build(level) } else { buildRoomFloor() }
    }

    private func build(_ level: Level) {
        for (i, platform) in world.platforms.enumerated() {
            let box = platform.box
            let w = box.maxX - box.minX
            let h = box.maxY - box.minY
            let node = SKNode()
            let body = SKShapeNode(rect: CGRect(x: 0, y: 0, width: w, height: h), cornerRadius: platform.oneWay ? 3 : 0)
            body.fillColor = platform.oneWay ? Palette.mid : Palette.floor
            body.strokeColor = platform.oneWay ? Palette.cyan.withAlphaComponent(0.25) : .clear
            node.addChild(body)
            let edge = SKShapeNode(rect: CGRect(x: 0, y: h - 2, width: w, height: 2))
            edge.fillColor = (platform.moves ? Palette.gold : Palette.cyan).withAlphaComponent(0.55)
            edge.strokeColor = .clear
            edge.glowWidth = 1
            node.addChild(edge)
            node.position = CGPoint(x: box.minX, y: box.minY)
            node.zPosition = platform.oneWay ? -3 : -5
            worldNode.addChild(node)
            platformNodes[i] = node
        }

        for hazard in level.hazards {
            let b = hazard.box
            let node = SKShapeNode(rect: CGRect(x: b.minX, y: b.minY, width: b.maxX - b.minX, height: b.maxY - b.minY),
                                   cornerRadius: 4)
            node.fillColor = Palette.red.withAlphaComponent(0.55)
            node.strokeColor = Palette.ember
            node.lineWidth = 2
            node.glowWidth = 5
            node.zPosition = 4
            worldNode.addChild(node)
            hazardNodes.append(node)
            // The emitters stay visible while the arc is off, so the danger can be read in advance.
            for y in [b.minY, b.maxY] {
                let emitter = SKShapeNode(rect: CGRect(x: b.minX - 8, y: y - 4, width: b.maxX - b.minX + 16, height: 8),
                                          cornerRadius: 2)
                emitter.fillColor = Palette.body
                emitter.strokeColor = Palette.red.withAlphaComponent(0.7)
                emitter.zPosition = 5
                worldNode.addChild(emitter)
            }
        }

        for point in level.checkpoints {
            let post = SKShapeNode(rect: CGRect(x: point.x - 2, y: point.y, width: 4, height: 70))
            post.fillColor = Palette.mid
            post.strokeColor = .clear
            post.zPosition = -2
            worldNode.addChild(post)
            let lamp = SKShapeNode(circleOfRadius: 9)
            lamp.position = CGPoint(x: point.x, y: point.y + 78)
            lamp.lineWidth = 2
            lamp.zPosition = -2
            worldNode.addChild(lamp)
            checkpointNodes.append(lamp)
        }

        for pickup in level.pickups where !world.collected.contains(pickup.id) {
            let shard = SKShapeNode(rectOf: CGSize(width: 12, height: 12), cornerRadius: 2)
            shard.zRotation = .pi / 4
            shard.fillColor = pickup.secret ? Palette.gold : Palette.cyan
            shard.strokeColor = Palette.white.withAlphaComponent(0.8)
            shard.glowWidth = 4
            shard.position = CGPoint(x: pickup.pos.x, y: pickup.pos.y)
            shard.zPosition = 6
            shard.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: 6, duration: 0.7), .moveBy(x: 0, y: -6, duration: 0.7),
            ])))
            worldNode.addChild(shard)
            pickupNodes[pickup.id] = shard
        }

        // A boss room has no way out until the boss falls.
        guard level.boss == nil else { return }
        let gate = SKShapeNode(rect: CGRect(x: level.exitX, y: 0, width: 70, height: 170), cornerRadius: 35)
        gate.fillColor = Palette.white.withAlphaComponent(0.12)
        gate.strokeColor = Palette.gold
        gate.lineWidth = 3
        gate.glowWidth = 8
        gate.zPosition = -2
        worldNode.addChild(gate)
    }

    private func buildBackdrop() {
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
    }

    private func buildRoomFloor() {
        let arena = world.arena
        let width = arena.upperBound - arena.lowerBound
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
        if reading.mode { toggleMode() }
        if reading.debug { showDebug.toggle() }
        if reading.restart {
            restart(fresh: true)
            presses = []
        } else if world.isOver && (!presses.isEmpty || reading.attack || reading.jump) {
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
            let frameInput = !demo ? input : (mode == .level ? pilot.input(for: world) : DemoBot.input(for: world))
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
            // A companion that has not joined yet stands dark.
            if f.team == .hero, !f.awake { node.alpha = 0.4 }
        }
        for (id, node) in nodes where !seen.contains(id) {
            node.removeFromParent()
            nodes[id] = nil
        }

        let zoom = zoom
        if let hero = world.controlled {
            let half = size.width / zoom / 2
            let low = world.arena.lowerBound + half - 60
            let high = world.arena.upperBound - half + 60
            let target = min(max(hero.pos.x + hero.facing * 40, low), max(low, high))
            cameraX += (target - cameraX) * 0.12
            // The camera only climbs once the hero is well off the floor, and never chases a fall into a pit.
            let lift = max(-40, hero.pos.y - 70)
            cameraY += (lift - cameraY) * 0.08
            let partner = world.fighters.first { $0.team == .hero && $0.id != hero.id && $0.awake }
            hud.setHeroes(
                lead: (hero.kind.rawValue.uppercased(), hero.hp / hero.spec.maxHP),
                partner: partner.map { ($0.kind.rawValue.uppercased(), $0.hp / $0.spec.maxHP) })
        }
        drawLevel()
        if let boss = world.boss, boss.awake, boss.isAlive {
            hud.setBoss((boss.kind == .theProtocol ? "THE PROTOCOL" : boss.kind.rawValue.uppercased(),
                         boss.hp / boss.spec.maxHP, boss.isOpen))
        } else {
            hud.setBoss(nil)
        }

        shake *= 0.86
        let jolt = shake < 0.3 ? CGPoint.zero : CGPoint(
            x: CGFloat.random(in: -shake...shake), y: CGFloat.random(in: -shake...shake))
        for (layer, depth, drop) in [(worldNode, 1.0, 0.0), (midLayer, 0.55, 20.0), (farLayer, 0.25, 10.0)] {
            layer.setScale(zoom)
            layer.position = CGPoint(
                x: size.width / 2 - (cameraX * depth + (depth == 1 ? 0 : size.width / zoom / 2)) * zoom + jolt.x * depth,
                y: (groundY - drop - cameraY * depth) * zoom + jolt.y * depth)
        }

        if let level = world.level {
            hud.setStatus("\(level.name.uppercased())   ◆ \(world.collected.count)/\(level.pickups.count)")
        } else {
            hud.setStatus(world.waveNumber == 0 ? "TRAINING" : "WAVE \(world.waveNumber)   KILLS \(kills)")
        }
        hud.setDebug(showDebug ? debugText() : nil)
    }

    private func drawLevel() {
        guard let level = world.level else { return }
        for (i, node) in platformNodes where world.platforms[i].moves {
            let box = world.platformBoxes[i]
            node.position = CGPoint(x: box.minX, y: box.minY)
        }
        for (hazard, node) in zip(level.hazards, hazardNodes) {
            if hazard.isOn(at: world.frame) {
                node.alpha = world.frame % 6 < 3 ? 1 : 0.75
            } else if hazard.isWarning(at: world.frame) {
                node.alpha = world.frame % 10 < 5 ? 0.35 : 0.1
            } else {
                node.alpha = 0.04
            }
        }
        for (i, lamp) in checkpointNodes.enumerated() {
            let lit = i <= world.checkpointIndex
            lamp.fillColor = lit ? Palette.cyan : Palette.body
            lamp.strokeColor = Palette.cyan.withAlphaComponent(lit ? 1 : 0.35)
            lamp.glowWidth = lit ? 6 : 0
        }
    }

    private func debugText() -> String {
        guard let f = world.controlled else { return "" }
        let ground = f.onGround ? "ground" + (f.groundIndex.map { " #\($0)" } ?? "") : "air"
        var text = String(
            format: "pos %6.0f %5.0f\nvel %6.0f %5.0f\n%@  coyote %d\n%@ f%d\nhitstop %d  frame %d",
            f.pos.x, f.pos.y, f.vel.x, f.vel.y, ground, f.coyote, String(describing: f.state), f.stateFrame,
            world.hitStop, world.frame)
        if let boss = world.boss {
            text += String(format: "\nboss %.0f  %@ f%d  %@", boss.hp, String(describing: boss.state), boss.stateFrame,
                           boss.isOpen ? "open" : "armoured")
        }
        return text
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
                    haptics.heavy()
                    hud.flashDamage()
                } else {
                    shake = max(shake, damage >= 20 ? 6 : 2)
                    haptics.light(damage >= 20 ? 1 : 0.6)
                }
                _ = attacker
            case .blocked(_, _, let at):
                sparks(at: at, color: Palette.steel, count: 4)
                popup("BLOCKED", at: at, color: Palette.steel, size: 13)
                haptics.rigid(0.5)
            case .parried(_, let attacker, let at):
                ring(at: at, radius: 70, color: Palette.white)
                sparks(at: at, color: Palette.white, count: 14)
                popup("PARRY", at: at, color: Palette.cyan, size: 20)
                nodes[attacker]?.flash()
                shake = max(shake, 5)
                haptics.rigid()
            case .exploded(let id, let at, let radius):
                ring(at: at, radius: radius, color: Palette.ember)
                sparks(at: at, color: Palette.ember, count: 18)
                shake = max(shake, 10)
                nodes[id]?.vanish()
                haptics.heavy()
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
                haptics.light()
            case .revived(let id):
                if let f = world.fighter(id) {
                    ring(at: Vec2(f.pos.x, f.pos.y + f.spec.height / 2), radius: 80, color: Palette.white)
                    popup("BACK UP", at: Vec2(f.pos.x, f.pos.y + f.spec.height), color: Palette.cyan, size: 14)
                }
            case .heroDown:
                hud.showMessage(demo ? "DOWN" : "DOWN\ntap to try again")
            case .fell:
                shake = max(shake, 8)
                haptics.heavy()
                hud.flashDamage()
            case .respawned(let id):
                if let f = world.fighter(id) {
                    ring(at: Vec2(f.pos.x, f.pos.y + f.spec.height / 2), radius: 60, color: Palette.white)
                }
            case .checkpoint(let index):
                if let c = world.level?.checkpoints[index] {
                    ring(at: Vec2(c.x, c.y + 78), radius: 50, color: Palette.cyan)
                    popup("CHECKPOINT", at: Vec2(c.x, c.y + 90), color: Palette.cyan, size: 13)
                }
                haptics.light()
            case .collected(let id, let secret, let at):
                pickupNodes[id]?.removeFromParent()
                pickupNodes[id] = nil
                sparks(at: at, color: secret ? Palette.gold : Palette.cyan, count: 8)
                if secret { popup("SECRET", at: at, color: Palette.gold, size: 14) }
                haptics.light(0.7)
            case .woke(let id):
                if id == world.bossID {
                    hud.announce("THE PROTOCOL")
                    hud.showHint(bossHint)
                    shake = max(shake, 10)
                    haptics.heavy()
                } else if let f = world.fighter(id) {
                    popup("!", at: Vec2(f.pos.x, f.pos.y + f.spec.height), color: Palette.red, size: 16)
                }
            case .joined(let id):
                if let f = world.fighter(id) {
                    ring(at: Vec2(f.pos.x, f.pos.y + f.spec.height / 2), radius: 90, color: Palette.cyan)
                    popup("\(f.kind.rawValue.uppercased()) JOINS", at: Vec2(f.pos.x, f.pos.y + f.spec.height),
                          color: Palette.cyan, size: 16)
                }
                haptics.rigid()
            case .bossDefeated(let id):
                if let f = world.fighter(id) {
                    let centre = Vec2(f.pos.x, f.pos.y + f.spec.height / 2)
                    sparks(at: centre, color: Palette.gold, count: 30)
                    ring(at: centre, radius: 220, color: Palette.gold)
                    ring(at: centre, radius: 120, color: Palette.white)
                }
                shake = max(shake, 16)
                haptics.heavy()
            case .regrouped(_, let at):
                ring(at: at, radius: 50, color: Palette.cyan)
            case .levelComplete:
                let total = world.level?.pickups.count ?? 0
                let next = levelIndex + 1 < levels.count ? "tap to continue" : "tap to start over"
                hud.showMessage(demo ? "CLEAR" : "CLEAR   ◆ \(world.collected.count)/\(total)\n\(next)")
                haptics.rigid()
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

    #if os(iOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)
            switch hud.action(at: point) {
            case .toggleMode: toggleMode()
            case .toggleDebug: showDebug.toggle()
            case nil: controls.began(ObjectIdentifier(touch), at: point)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { controls.moved(ObjectIdentifier(touch), to: touch.location(in: self)) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { controls.ended(ObjectIdentifier(touch)) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { controls.ended(ObjectIdentifier(touch)) }
    }
    #else
    override func mouseDown(with event: NSEvent) {
        switch hud.action(at: event.location(in: self)) {
        case .toggleMode: toggleMode()
        case .toggleDebug: showDebug.toggle()
        case nil: break
        }
    }
    #endif
}
