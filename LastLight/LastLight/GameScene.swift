import ImageIO
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
    private let story: StoryPresenter
    private var mode: Mode
    private var world: World
    private var pilot = Autopilot(fights: true)
    private var showDebug = false
    private var settings = Settings()
    /// Asks for the pause menu.
    var onPause: (() -> Void)?
    /// Held still behind a menu. Time spent frozen is not simulated afterwards.
    var frozen = false {
        didSet {
            lastTime = 0
            accumulator = 0
            // Keys held while a menu was open do not count as new presses.
            if !frozen { _ = hardware.poll() }
            // Menus sit over a clean picture: no HUD, no on-screen buttons.
            hud.isHidden = frozen
            controls.isHidden = frozen
        }
    }
    private var hardware = HardwareInput()
    private let controls = TouchControls()
    private let hud = HUD()
    private let vignette = SKSpriteNode(texture: Effects.vignetteTexture)
    /// Darkens the room while the Last Oracle's dusk holds.
    private let dusk = SKSpriteNode(color: .black, size: .zero)

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
    /// Columns of light, reused frame to frame.
    private var strikeNodes: [SKShapeNode] = []
    private var shake: CGFloat = 0
    private var run = 0
    private var kills = 0
    /// Frames played and times the heroes went down in this level, kept across checkpoint retries.
    private var levelFrames = 0
    private var downs = 0
    /// Called when a level is cleared, with what the results screen shows.
    var onComplete: ((LevelResult) -> Void)?
    /// The bot normally loops levels; with this it stops on the results screen like a player would.
    var demoShowsResults = false

    private let groundY: CGFloat = 104
    private let haptics = Haptics()
    private let sound = Sound()
    /// The hero leading this run, chosen by faction. Remembered between launches.
    private(set) var lead: FighterKind {
        didSet { UserDefaults.standard.set(lead.rawValue, forKey: "progress.lead") }
    }
    /// The whole run as the lead plays it: every chapter's levels, in order.
    private var levels: [Level] { Self.route(for: lead) }
    /// Which level of the run is being played. Saved by the level's name, so adding a chapter never moves it.
    private var levelIndex: Int {
        didSet { UserDefaults.standard.set(levels[levelIndex].name, forKey: "progress.levelName") }
    }

    private static func route(for lead: FighterKind) -> [Level] {
        Chapter.all.flatMap { $0.levels(for: lead) }
    }

    /// The chapter a level of the run belongs to, and where that chapter starts in the run.
    private func chapter(at index: Int) -> (chapter: Chapter, start: Int) {
        var start = 0
        for chapter in Chapter.all {
            let count = chapter.levels(for: lead).count
            if index < start + count { return (chapter, start) }
            start += count
        }
        return (Chapter.all[Chapter.all.count - 1], start)
    }
    private var level: Level { levels[levelIndex] }

    /// World units are scaled so about the same slice of the level shows on a phone, a tablet and a Mac window.
    /// A boss room is seen from further back, so the boss fits under the bars at the top.
    private var zoom: CGFloat {
        max(0.5, min(size.height / 402, size.width / 700)) * (mode == .level && level.boss != nil ? 0.7 : 1)
    }

    /// The saved place in the chapter. Builds before the openings saved `levelIndex` in the old order (Foundry Yard
    /// first, then Awakening); that is read once and moved to Caelen's route.
    private static func savedLevel(in route: [Level]) -> Int {
        let defaults = UserDefaults.standard
        if let name = defaults.string(forKey: "progress.levelName") {
            return route.firstIndex { $0.name == name } ?? 0
        }
        if defaults.object(forKey: "progress.level") == nil, defaults.object(forKey: "levelIndex") != nil {
            let old = defaults.integer(forKey: "levelIndex")
            defaults.removeObject(forKey: "levelIndex")
            let moved = [1, 0, 2, 3][min(max(old, 0), 3)]
            defaults.set(moved, forKey: "progress.level")
            return moved
        }
        return defaults.integer(forKey: "progress.level")
    }

    init(demo: Bool, mode: Mode = .level, story: StoryPresenter) {
        self.demo = demo
        self.story = story
        self.mode = mode
        // `-level 2` starts on the third level, for checking one without playing up to it.
        let args = ProcessInfo.processInfo.arguments
        let asked = args.firstIndex(of: "-level").flatMap { $0 + 1 < args.count ? Int(args[$0 + 1]) : nil }
        // `-lead seraphine` or `-lead nimue` plays that faction's route, for checks.
        let askedLead = args.firstIndex(of: "-lead").flatMap { $0 + 1 < args.count ? FighterKind(rawValue: args[$0 + 1]) : nil }
        let savedLead = UserDefaults.standard.string(forKey: "progress.lead").flatMap(FighterKind.init(rawValue:))
        let lead = askedLead ?? (demo ? .caelen : savedLead ?? .caelen)
        self.lead = lead
        let route = Self.route(for: lead)
        let saved = asked ?? (demo ? 0 : Self.savedLevel(in: route))
        levelIndex = min(max(saved, 0), route.count - 1)
        world = mode == .level ? World(level: route[levelIndex], hero: lead, seed: 1) : World.partnerSlice(seed: 1)
        super.init(size: CGSize(width: 874, height: 402))
        scaleMode = .resizeFill
        if mode == .level { story.forget(route[levelIndex].scenes.map(\.scene)) }
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
        vignette.anchorPoint = .zero
        vignette.zPosition = 85
        addChild(vignette)
        dusk.anchorPoint = .zero
        dusk.zPosition = 84
        dusk.alpha = 0
        addChild(dusk)
        addChild(hud)
        #if os(iOS)
        if !demo { addChild(controls) }
        #endif
        buildScenery()
        layout()
        showHint()
        if let hero = world.controlled { cameraX = hero.pos.x }
        // `-scene awakening.orion 2` opens that scene two lines in, for checking the dialogue panel.
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-scene"), i + 1 < args.count {
            story.forget([args[i + 1]])
            story.begin(args[i + 1])
            for _ in 0..<(i + 2 < args.count ? Int(args[i + 2]) ?? 0 : 0) { story.advance() }
        }
    }

    /// What the screen calls each boss, its phases after the first, and the tip shown when it wakes.
    private func bossTitle(_ kind: FighterKind) -> (name: String, phases: [String], hint: String) {
        switch kind {
        case .cinderKing:
            ("THE CINDER KING", ["THE DEBT", "THE PRICE"],
             "Step out of the fire.  While his Ratborn live, he can't be hurt.")
        case .lineWarden:
            ("THE LINE WARDEN", ["OVERDRIVE"],
             "Its guard faces forward.  Get behind it, or parry to break its stance.")
        case .lastOracle:
            ("THE LAST ORACLE", ["THE DUSK", "THE ENDING"],
             "Gold light: look away.  Dark light: face her.")
        default:
            ("THE PROTOCOL", ["ASCENSION", "EXECUTION"], "Strike only when the core opens.  Jump the surge.  Dodge the charge.")
        }
    }

    private func showHint() {
        if demo {
            hud.showHint("DEMO")
            return
        }
        #if os(iOS)
        hud.showHint(mode == .level
            ? "Reach the gate.  Dodge passes through arcs.  ⇄ switches hero."
            : "Parry: attack just as the red flash comes.  Dodge passes through.  ⇄ switches hero.")
        #else
        hud.showHint("A/D move   Space jump   J attack   K dodge   I special   L switch   R restart   Esc pause")
        #endif
    }

    override func didChangeSize(_ oldSize: CGSize) {
        layout()
    }

    private func layout() {
        vignette.size = size
        dusk.size = size
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
            if !resume {
                kills = 0
                levelFrames = 0
                downs = 0
            }
            var tuning = Tuning()
            tuning.heroDamageScale = settings.difficulty.damageTaken
            world = World(level: level, hero: lead, tuning: tuning, seed: seed, fromCheckpoint: resume ? world.checkpointIndex : -1,
                          collected: resume ? world.collected : [])
            pilot = Autopilot(fights: true)
            // A level started over plays its scenes again; a retry from a checkpoint does not.
            if !resume { story.forget(level.scenes.map(\.scene)) }
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

    #if DEBUG
    /// `-snapshot <folder>` saves what the scene shows every two seconds, so it can be checked without a screen
    /// capture. Debug builds only.
    private var lastSnapshot: TimeInterval = 0
    private var snapshotCount = 0

    private func saveSnapshotIfAsked(_ time: TimeInterval) {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-snapshot"), i + 1 < args.count else { return }
        guard let view else { return }
        guard time - lastSnapshot >= 2 else { return }
        lastSnapshot = time
        // Only draws while the window is on screen; a hidden window saves nothing.
        guard let image = view.texture(from: self)?.cgImage() else { return }
        snapshotCount += 1
        // A sandboxed app can only write inside its own container, so the folder is the app's temporary one
        // when the one asked for isn't writable.
        var folder = URL(fileURLWithPath: args[i + 1])
        if !FileManager.default.isWritableFile(atPath: folder.path) {
            folder = FileManager.default.temporaryDirectory.appendingPathComponent("snapshots")
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if snapshotCount == 1 { FileHandle.standardError.write(Data("SNAPSHOTS \(folder.path)\n".utf8)) }
        }
        let url = folder.appendingPathComponent(String(format: "shot%03d.png", snapshotCount))
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }
    #endif

    // MARK: Menus

    var currentLevel: Int { levelIndex }
    var levelNames: [String] { levels.map(\.name) }
    /// The chapter the saved place is in.
    var currentChapter: Chapter { chapter(at: levelIndex).chapter }
    /// Each chapter with the run index of its first level and its level names, for the chapter list.
    var chapterList: [(chapter: Chapter, start: Int, names: [String])] {
        var start = 0
        return Chapter.all.map { chapter in
            let names = chapter.levels(for: lead).map(\.name)
            defer { start += names.count }
            return (chapter, start, names)
        }
    }

    func apply(_ settings: Settings) {
        self.settings = settings
        sound.volume = Float(settings.volume)
        haptics.enabled = settings.haptics
        showDebug = settings.debugOverlay
    }

    /// A new run as this faction's lead, from their opening.
    func begin(as lead: FighterKind) {
        self.lead = lead
        play(levelAt: 0)
    }

    func play(levelAt index: Int) {
        mode = .level
        levelIndex = min(max(index, 0), levels.count - 1)
        restart(fresh: true)
        showHint()
    }

    func playTrainingRoom() {
        mode = .room
        restart(fresh: true)
        showHint()
        hud.announce("TRAINING ROOM")
    }

    /// Back to the last checkpoint, as after a fall in battle.
    func retry() {
        if world.isComplete { restart(fresh: true) } else { restart() }
    }

    /// From the results screen: the next level.
    func advance() {
        restart()
    }

    func restartLevel() {
        restart(fresh: true)
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
        strikeNodes = []
        buildBackdrop()
        Effects.ambient(mid: midLayer, far: farLayer, width: CGFloat(world.arena.upperBound - world.arena.lowerBound))
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
        #if DEBUG
        saveSnapshotIfAsked(currentTime)
        #endif
        let elapsed = lastTime == 0 ? 0 : min(currentTime - lastTime, 0.1)
        lastTime = currentTime
        accumulator += elapsed

        guard !frozen else {
            draw()
            return
        }
        let reading = hardware.poll()
        var presses = controls.takePresses()
        if reading.pause, !story.isActive {
            onPause?()
            return
        }
        // While someone is speaking the game holds still. Attack or jump moves the scene on.
        if story.isActive {
            if reading.attack || reading.jump { story.advance() }
            accumulator = 0
            draw()
            return
        }
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
        input.special = reading.special || presses.contains(.special)
        input.switchHero = reading.switchHero || presses.contains(.switchHero)

        let step = 1 / Tuning.framesPerSecond
        var steps = 0
        while accumulator >= step, steps < 4, !story.isActive {
            let frameInput = !demo ? input : (mode == .level ? pilot.input(for: world) : DemoBot.input(for: world))
            if mode == .level, !world.isOver { levelFrames += 1 }
            react(to: world.step(frameInput))
            // A press belongs to one simulation frame only.
            input.jump = false
            input.attack = false
            input.dodge = false
            input.special = false
            input.switchHero = false
            accumulator -= step
            steps += 1
        }
        if steps == 4 { accumulator = 0 }

        sound.advance()
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
            node.sync(f, frame: world.frame, controlled: f.id == world.controlledID,
                      warded: f.team == .enemy && world.isWarded(f.id))
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
            var lift = max(-40, hero.pos.y - 70)
            // Rise with a boss that takes to the air, so it stays in view.
            if let boss = world.boss, boss.isAlive, !boss.onGround { lift = max(lift, 60) }
            cameraY += (lift - cameraY) * 0.08
            let partner = world.fighters.first { $0.team == .hero && $0.id != hero.id && $0.awake && !$0.spec.isDecoy }
            hud.setSpecial(hero.spec.special.map { ($0.name, hero.specialCooldown) })
            controls.setSpecial(ready: hero.spec.special != nil && hero.specialCooldown == 0)
            hud.setHeroes(
                lead: (hero.kind.rawValue.uppercased(), hero.hp / hero.spec.maxHP),
                partner: partner.map { ($0.kind.rawValue.uppercased(), $0.hp / $0.spec.maxHP) })
        }
        drawLevel()
        // The Oracle's dusk darkens the room; in the ending it lifts halfway.
        var duskTarget: CGFloat = 0
        if let boss = world.boss, boss.kind == .lastOracle, boss.isAlive {
            duskTarget = boss.phase == 2 ? 0.4 : (boss.phase >= 3 ? 0.18 : 0)
        }
        dusk.alpha += (duskTarget - dusk.alpha) * 0.04
        if let boss = world.boss, boss.awake, boss.isAlive {
            let title = bossTitle(boss.kind)
            let phase = boss.phase >= 2 ? " · " + title.phases[min(boss.phase - 2, title.phases.count - 1)] : ""
            hud.setBoss((title.name + phase, boss.hp / boss.spec.maxHP, boss.isOpen && !boss.isGuarding && !world.isWarded(boss.id)))
        } else {
            hud.setBoss(nil)
        }

        shake *= 0.86
        let jolt = shake < 0.3 || !settings.screenShake ? CGPoint.zero : CGPoint(
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
        drawStrikes()
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

    /// Faint and widening while a column warns, white-hot while it burns.
    private func drawStrikes() {
        while strikeNodes.count < world.strikes.count {
            let node = SKShapeNode()
            node.zPosition = 8
            node.lineWidth = 2
            worldNode.addChild(node)
            strikeNodes.append(node)
        }
        for (i, node) in strikeNodes.enumerated() {
            guard i < world.strikes.count else {
                node.isHidden = true
                continue
            }
            let s = world.strikes[i]
            node.isHidden = false
            if s.kind != .light {
                drawGroundStrike(node, s)
                continue
            }
            node.path = CGPath(rect: CGRect(x: s.box.minX, y: -20, width: s.box.width, height: 620), transform: nil)
            if s.isActive {
                node.fillColor = Palette.white.withAlphaComponent(0.85)
                node.strokeColor = Palette.red
                node.glowWidth = 12
            } else {
                let t = CGFloat(s.age) / CGFloat(max(s.warning, 1))
                let blink = s.warning - s.age <= 14 && (s.age / 3) % 2 == 0
                node.fillColor = Palette.red.withAlphaComponent(blink ? 0.4 : 0.06 + 0.2 * t)
                node.strokeColor = Palette.red.withAlphaComponent(0.3 + 0.6 * t)
                node.glowWidth = 0
            }
        }
    }

    /// A burning patch or a snare on the ground: an outline while it warns, then lit while it is live.
    private func drawGroundStrike(_ node: SKShapeNode, _ s: Strike) {
        let color = s.kind == .fire ? Palette.ember : Palette.violet
        let rect = CGRect(x: s.box.minX, y: s.box.minY + 4, width: s.box.width, height: s.box.maxY - s.box.minY - 4)
        if s.kind == .fire || s.kind == .dark, s.isActive {
            // Flames: a jagged top that moves.
            let path = CGMutablePath()
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            let peaks = max(3, Int(rect.width / 14))
            for n in 0...peaks {
                let x = rect.minX + rect.width * CGFloat(n) / CGFloat(peaks)
                let flicker = sin(CGFloat(s.age + n * 7) * 0.5) * 0.35 + 0.65
                path.addLine(to: CGPoint(x: x, y: rect.minY + rect.height * (n % 2 == 0 ? flicker : flicker * 0.45)))
            }
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.closeSubpath()
            node.path = path
            // The Oracle's dark is a black flame edged in violet.
            node.fillColor = s.kind == .dark ? Palette.body.withAlphaComponent(0.92) : color.withAlphaComponent(0.7)
            node.strokeColor = s.kind == .dark ? Palette.violet : Palette.gold
            node.glowWidth = 8
        } else if s.kind == .snare, s.isActive {
            // Threads pinned to the ground.
            let path = CGMutablePath()
            let strands = 4
            for n in 0...strands {
                let x = rect.minX + rect.width * CGFloat(n) / CGFloat(strands)
                path.move(to: CGPoint(x: x, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            }
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + 2))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + 2))
            node.path = path
            node.fillColor = .clear
            node.strokeColor = color.withAlphaComponent(0.85)
            node.glowWidth = 3
        } else {
            let t = CGFloat(s.age) / CGFloat(max(s.warning, 1))
            let blink = s.warning - s.age <= 14 && (s.age / 3) % 2 == 0
            node.path = CGPath(roundedRect: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 6),
                               cornerWidth: 3, cornerHeight: 3, transform: nil)
            node.fillColor = color.withAlphaComponent(blink ? 0.6 : 0.1 + 0.3 * t)
            node.strokeColor = color.withAlphaComponent(0.4 + 0.5 * t)
            node.glowWidth = 0
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
            text += String(format: "\nboss %.0f p%d  %@ f%d  %@", boss.hp, boss.phase, String(describing: boss.state), boss.stateFrame,
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
                sound.play(heroHurt ? .hurt : (damage >= 20 ? .heavyHit : .hit))
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
                sound.play(.blocked)
                haptics.rigid(0.5)
            case .parried(_, let attacker, let at):
                Effects.flash(self, color: Palette.white, alpha: 0.14)
                ring(at: at, radius: 70, color: Palette.white)
                sparks(at: at, color: Palette.white, count: 14)
                popup("PARRY", at: at, color: Palette.cyan, size: 20)
                sound.play(.parry)
                nodes[attacker]?.flash()
                shake = max(shake, 5)
                haptics.rigid()
            case .exploded(let id, let at, let radius):
                ring(at: at, radius: radius, color: Palette.ember)
                Effects.explosion(worldNode, at: CGPoint(x: at.x, y: at.y), radius: radius)
                sound.play(.explosion)
                shake = max(shake, 10)
                nodes[id]?.vanish()
                haptics.heavy()
            case .fuseLit(let id):
                sound.play(.fuse)
                if let f = world.fighter(id) {
                    popup("!", at: Vec2(f.pos.x, f.pos.y + 60), color: Palette.red, size: 22)
                }
            case .died(let id):
                if let f = world.fighter(id), f.team == .enemy {
                    kills += 1
                    // A drone that exploded is already gone; the boss has its own ending.
                    if nodes[id]?.parent != nil, !f.spec.boss {
                        Effects.breakApart(worldNode, at: CGPoint(x: f.pos.x, y: f.pos.y + f.spec.height / 2), size: f.spec.height)
                    }
                }
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
                sound.play(.down)
                downs += 1
                hud.showMessage(demo ? "DOWN" : "DOWN\ntap to try again")
            case .fell:
                sound.play(.fall)
                shake = max(shake, 8)
                haptics.heavy()
                hud.flashDamage()
            case .respawned(let id):
                if let f = world.fighter(id) {
                    ring(at: Vec2(f.pos.x, f.pos.y + f.spec.height / 2), radius: 60, color: Palette.white)
                }
            case .checkpoint(let index):
                if let c = world.level?.checkpoints[index] { Effects.motes(worldNode, at: CGPoint(x: c.x, y: c.y + 20), color: Palette.cyan, count: 26, width: 40) }
                if let c = world.level?.checkpoints[index] {
                    ring(at: Vec2(c.x, c.y + 78), radius: 50, color: Palette.cyan)
                    popup("CHECKPOINT", at: Vec2(c.x, c.y + 90), color: Palette.cyan, size: 13)
                }
                sound.play(.checkpoint)
                haptics.light()
            case .collected(let id, let secret, let at):
                Effects.motes(worldNode, at: CGPoint(x: at.x, y: at.y), color: secret ? Palette.gold : Palette.cyan)
                pickupNodes[id]?.removeFromParent()
                pickupNodes[id] = nil
                sparks(at: at, color: secret ? Palette.gold : Palette.cyan, count: 8)
                if secret { popup("SECRET", at: at, color: Palette.gold, size: 14) }
                sound.play(secret ? .secret : .pickup)
                haptics.light(0.7)
            case .woke(let id):
                if id == world.bossID {
                    let title = bossTitle(world.boss?.kind ?? .theProtocol)
                    hud.announce(title.name)
                    sound.play(.bossWake)
                    hud.showHint(title.hint)
                    shake = max(shake, 10)
                    haptics.heavy()
                } else if let f = world.fighter(id) {
                    popup("!", at: Vec2(f.pos.x, f.pos.y + f.spec.height), color: Palette.red, size: 16)
                }
            case .joined(let id):
                if let f = world.fighter(id) { Effects.motes(worldNode, at: CGPoint(x: f.pos.x, y: f.pos.y), color: Palette.cyan, count: 22, width: 30) }
                sound.play(.join)
                if let f = world.fighter(id) {
                    ring(at: Vec2(f.pos.x, f.pos.y + f.spec.height / 2), radius: 90, color: Palette.cyan)
                    popup("\(f.kind.rawValue.uppercased()) JOINS", at: Vec2(f.pos.x, f.pos.y + f.spec.height),
                          color: Palette.cyan, size: 16)
                }
                haptics.rigid()
            case .bossDefeated(let id):
                Effects.flash(self, color: Palette.white, alpha: 0.4, duration: 0.6)
                if let f = world.fighter(id) {
                    Effects.explosion(worldNode, at: CGPoint(x: f.pos.x, y: f.pos.y + f.spec.height / 2), radius: 140)
                    Effects.breakApart(worldNode, at: CGPoint(x: f.pos.x, y: f.pos.y + f.spec.height / 2), size: f.spec.height)
                }
                if let f = world.fighter(id) {
                    let centre = Vec2(f.pos.x, f.pos.y + f.spec.height / 2)
                    sparks(at: centre, color: Palette.gold, count: 30)
                    ring(at: centre, radius: 220, color: Palette.gold)
                    ring(at: centre, radius: 120, color: Palette.white)
                }
                shake = max(shake, 16)
                sound.play(.bossDown)
                haptics.heavy()
            case .regrouped(_, let at):
                ring(at: at, radius: 50, color: Palette.cyan)
            case .levelComplete:
                sound.play(.clear)
                let total = world.level?.pickups.count ?? 0
                let next = levelIndex + 1 < levels.count ? "tap to continue" : "tap to start over"
                haptics.rigid()
                if (demo && !demoShowsResults) || onComplete == nil {
                    hud.showMessage(demo ? "CLEAR" : "CLEAR   ◆ \(world.collected.count)/\(total)\n\(next)")
                } else {
                    let (chapter, start) = chapter(at: levelIndex)
                    let endsChapter = levelIndex + 1 == start + chapter.levels(for: lead).count
                    onComplete?(LevelResult(
                        name: level.name, index: levelIndex, chapterNumber: chapter.number, chapterTitle: chapter.title,
                        ending: endsChapter ? chapter.ending : nil, chapterStart: start,
                        isFinal: levelIndex + 1 == levels.count,
                        seconds: Double(levelFrames) / Tuning.framesPerSecond, defeated: kills, downs: downs,
                        found: world.collected.count, hidden: total))
                }
            case .swing(let id, let index):
                if id == world.bossID {
                    sound.play(.warning)
                } else if let f = world.fighter(id) {
                    let heavy = f.team == .enemy || index == f.spec.attacks.count - 1
                    sound.play(heavy ? .heavySwing : .swing, volume: f.id == world.controlledID ? 1 : 0.5)
                }
            case .jumped(let id):
                dust(id, amount: 6)
                if id == world.controlledID { sound.play(.jump) }
            case .landed(let id):
                dust(id, amount: 10, spread: 34)
                if id == world.controlledID { sound.play(.land) }
            case .dodged(let id):
                dust(id, amount: 9, spread: 40)
                sound.play(.dodge, volume: id == world.controlledID ? 1 : 0.5)
            case .commanded(_, let target):
                if let f = world.fighter(target) {
                    let centre = Vec2(f.pos.x, f.pos.y + f.spec.height / 2)
                    ring(at: centre, radius: 80, color: Palette.gold)
                    popup("MARKED", at: Vec2(f.pos.x, f.pos.y + f.spec.height), color: Palette.gold, size: 14)
                }
                sound.play(.checkpoint)
                haptics.rigid(0.7)
            case .guarded(let id):
                if let f = world.fighter(id) {
                    ring(at: Vec2(f.pos.x, f.pos.y + f.spec.height / 2), radius: 46, color: Palette.cyan)
                }
                sound.play(.dodge)
            case .absorbed(_, let attacker, let at):
                Effects.flash(self, color: Palette.cyan, alpha: 0.12)
                ring(at: at, radius: 80, color: Palette.cyan)
                sparks(at: at, color: Palette.cyan, count: 14)
                popup("ADAPT", at: at, color: Palette.cyan, size: 20)
                nodes[attacker]?.flash()
                shake = max(shake, 5)
                sound.play(.parry)
                haptics.rigid()
            case .slowed(let id):
                if let f = world.fighter(id) {
                    popup("SLOWED", at: Vec2(f.pos.x, f.pos.y + f.spec.height), color: Palette.ember, size: 14)
                }
            case .scene(let id):
                // The demo bot does not read.
                if !demo { story.begin(id) }
            case .flared(_, let at, let radius):
                ring(at: at, radius: radius, color: Palette.gold)
                Effects.burst(worldNode, at: CGPoint(x: at.x, y: at.y), color: Palette.gold, count: 26, speed: 260, life: 0.35, size: 10)
                sound.play(.bossWake, volume: 0.35)
            case .eclipsed(_, let at, let radius):
                ring(at: at, radius: radius, color: Palette.violet)
                Effects.burst(worldNode, at: CGPoint(x: at.x, y: at.y), color: Palette.violet, count: 26, speed: 260, life: 0.35, size: 10)
                sound.play(.bossWake, volume: 0.35)
            case .dazed(let id):
                if let f = world.fighter(id) {
                    popup("DAZED", at: Vec2(f.pos.x, f.pos.y + f.spec.height + 14), color: Palette.gold, size: 14)
                    if id == world.controlledID {
                        Effects.flash(self, color: Palette.white, alpha: 0.55, duration: 0.5)
                        haptics.heavy()
                    }
                }
            case .healed(let id, let amount):
                if let f = world.fighter(id) {
                    let at = CGPoint(x: f.pos.x, y: f.pos.y + f.spec.height / 2)
                    Effects.motes(worldNode, at: CGPoint(x: f.pos.x, y: f.pos.y + 10), color: Palette.gold, count: 18, width: 24)
                    ring(at: Vec2(at.x, at.y), radius: 60, color: Palette.gold)
                    popup("+\(Int(amount.rounded()))", at: Vec2(f.pos.x, f.pos.y + f.spec.height + 10), color: Palette.gold, size: 14)
                }
                sound.play(.checkpoint, volume: 0.7)
            case .decoyPlaced(_, let at):
                Effects.burst(worldNode, at: CGPoint(x: at.x, y: at.y + 40), color: Palette.violet, count: 18, speed: 120, life: 0.4, size: 12)
                sound.play(.dodge)
            case .decoyGone(_, let at):
                Effects.burst(worldNode, at: CGPoint(x: at.x, y: at.y), color: Palette.lantern, count: 22, speed: 180, life: 0.4, size: 12)
                Effects.dust(worldNode, at: CGPoint(x: at.x, y: at.y - 30), amount: 8)
                sound.play(.fuse, volume: 0.6)
            case .bossPhase(_, let phase):
                Effects.flash(self, color: Palette.gold, alpha: 0.3, duration: 0.4)
                if let b = world.boss { Effects.motes(worldNode, at: CGPoint(x: b.pos.x, y: b.pos.y + 40), color: Palette.gold, count: 40, width: 140) }
                let phases = bossTitle(world.boss?.kind ?? .theProtocol).phases
                hud.announce(phases[min(max(phase - 2, 0), phases.count - 1)])
                shake = max(shake, 12)
                sound.play(.bossWake)
                haptics.heavy()
            case .bossLanded(let id):
                dustCloud(id)
                if let f = world.fighter(id) {
                    let feet = Vec2(f.pos.x, f.pos.y + 10)
                    ring(at: feet, radius: 170, color: Palette.red)
                    sparks(at: feet, color: Palette.ember, count: 22)
                    popup("OPEN", at: Vec2(f.pos.x, f.pos.y + f.spec.height), color: Palette.gold, size: 20)
                }
                shake = max(shake, 14)
                sound.play(.explosion)
                haptics.heavy()
            case .struck(let at, let width, let kind):
                switch kind {
                case .light:
                    Effects.column(worldNode, at: CGPoint(x: at.x, y: at.y), width: width)
                    sparks(at: Vec2(at.x, at.y + 10), color: Palette.white, count: 10)
                    shake = max(shake, 4)
                    sound.play(.heavyHit, volume: 0.7)
                case .fire:
                    sparks(at: Vec2(at.x, at.y + 8), color: Palette.ember, count: 14)
                    Effects.dust(worldNode, at: CGPoint(x: at.x, y: at.y), amount: 6, spread: width / 2)
                    shake = max(shake, 2)
                    sound.play(.explosion, volume: 0.35)
                case .snare:
                    sparks(at: Vec2(at.x, at.y + 4), color: Palette.violet, count: 6)
                    sound.play(.warning, volume: 0.4)
                case .dark:
                    sparks(at: Vec2(at.x, at.y + 8), color: Palette.violet, count: 12)
                    Effects.dust(worldNode, at: CGPoint(x: at.x, y: at.y), amount: 6, spread: width / 2)
                    shake = max(shake, 3)
                    sound.play(.explosion, volume: 0.35)
                }
            case .lobbed(let id, let kind, let at):
                if let f = world.fighter(id) {
                    let from = CGPoint(x: f.pos.x + f.facing * 14, y: f.pos.y + f.spec.height * 0.55)
                    Effects.lob(worldNode, from: from, to: CGPoint(x: at.x, y: at.y + 6),
                                color: kind == .fire ? Palette.ember : Palette.violet)
                }
                sound.play(.dodge, volume: 0.6)
            case .faded(_, let at):
                Effects.motes(worldNode, at: CGPoint(x: at.x, y: at.y), color: Palette.violet, count: 8)
            case .spawned(let id, _):
                if world.bossID != nil, let f = world.fighter(id) {
                    ring(at: Vec2(f.pos.x, f.pos.y + f.spec.height / 2), radius: 50, color: Palette.red)
                }
            case .evaded:
                break
            }
        }
    }

    private func sparks(at point: Vec2, color: SKColor, count: Int) {
        Effects.burst(worldNode, at: CGPoint(x: point.x, y: point.y), color: color, count: count * 2, speed: 260,
                      life: 0.28, size: 9)
    }

    /// The boss hitting the floor from the air.
    private func dustCloud(_ id: Int) {
        guard let f = world.fighter(id) else { return }
        Effects.dust(worldNode, at: CGPoint(x: f.pos.x, y: f.pos.y), amount: 34, spread: f.spec.width * 1.4)
        Effects.flash(self, color: Palette.ember, alpha: 0.12)
    }

    /// Dust at a hero's feet.
    private func dust(_ id: Int, amount: Int, spread: CGFloat = 26) {
        guard let f = world.fighter(id), f.team == .hero, f.awake else { return }
        Effects.dust(worldNode, at: CGPoint(x: f.pos.x, y: f.pos.y), amount: amount, spread: spread)
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
            case .pause: onPause?()
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
        if hud.action(at: event.location(in: self)) == .pause { onPause?() }
    }
    #endif
}
