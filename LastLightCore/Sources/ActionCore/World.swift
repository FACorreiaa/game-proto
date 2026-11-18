import LastLightCore

/// Where and what to spawn. `x` is a fraction of the arena width.
public struct Spawn: Sendable, Equatable {
    public var kind: FighterKind
    public var x: Double

    public init(_ kind: FighterKind, x: Double) {
        self.kind = kind
        self.x = x
    }
}

/// The whole game state. `step` advances it by one sixtieth of a second and is fully deterministic:
/// the same seed and the same inputs always give the same events.
public struct World: Sendable {
    public internal(set) var fighters: [Fighter] = []
    public private(set) var controlledID = -1
    public private(set) var frame = 0
    public private(set) var hitStop = 0
    public private(set) var isOver = false
    public private(set) var waveNumber = 0
    public let tuning: Tuning
    public let arena: ClosedRange<Double>
    /// Nil in the training room, which is one flat floor.
    public let level: Level?
    /// Where every platform is on this frame, in the same order as `platforms`.
    public private(set) var platformBoxes: [Box]
    public let platforms: [Platform]
    public private(set) var checkpointIndex = -1
    public private(set) var collected: Set<Int> = []
    public private(set) var isComplete = false
    public private(set) var bossID: Int?
    /// The boss sworn to the first one, in a level with a pair.
    public private(set) var twinID: Int?
    /// Frames one of a sworn pair has lain down while the other stands. At the tuning's limit it is raised.
    public private(set) var vowFrames = 0
    var bossDownFrames = 0
    var firedScenes: Set<String> = []
    /// Columns of light a boss has called down.
    public private(set) var strikes: [Strike] = []
    var platformDeltas: [Vec2]
    /// Levers and plates that are on, by id.
    public private(set) var signals: Set<Int> = []
    public private(set) var leverTimers: [Int: Int] = [:]
    /// How far each gate is open, from 0 (shut) to 1, by gate id.
    public private(set) var gateOpen: [Int: Double] = [:]
    /// Index into `platforms` of each gate's block, by gate id.
    public private(set) var gatePlatform: [Int: Int] = [:]

    var waves: [[Spawn]] = []
    var waveLive = false
    var waveDelay = 0
    var switchCooldown = 0
    var rng: SeededRandom
    var nextID = 1

    public init(tuning: Tuning = Tuning(), seed: UInt64, arena: ClosedRange<Double> = 0...1400) {
        self.tuning = tuning
        self.arena = arena
        self.rng = SeededRandom(seed: seed)
        level = nil
        platforms = [Platform(Box(minX: arena.lowerBound - 2000, minY: -600, maxX: arena.upperBound + 2000, maxY: 0))]
        platformBoxes = platforms.map(\.box)
        platformDeltas = platforms.map { _ in .zero }
    }

    /// A world built from level data. `fromCheckpoint` and `collected` carry progress across a retry.
    public init(
        level: Level, hero: FighterKind = .caelen, tuning: Tuning = Tuning(), seed: UInt64,
        fromCheckpoint: Int = -1, collected: Set<Int> = []
    ) {
        self.tuning = tuning
        self.level = level
        arena = 0...level.width
        rng = SeededRandom(seed: seed)
        // Gates are solid blocks that move; they go after the level's own platforms.
        platforms = level.platforms + level.gates.map { Platform($0.box) }
        for (n, g) in level.gates.enumerated() {
            gatePlatform[g.id] = level.platforms.count + n
            // Nothing is on at the start, so an inverted gate starts open.
            gateOpen[g.id] = g.inverted ? 1 : 0
        }
        platformBoxes = platforms.map { $0.box(at: 0) }
        for g in level.gates where g.inverted {
            if let p = gatePlatform[g.id] { platformBoxes[p] = g.box.offset(by: Vec2(0, g.box.maxY - g.box.minY + 20)) }
        }
        platformDeltas = platforms.map { _ in .zero }
        self.collected = collected
        checkpointIndex = min(fromCheckpoint, level.checkpoints.count - 1)
        let origin = checkpointIndex >= 0 ? level.checkpoints[checkpointIndex] : level.start
        control(spawn(hero, x: origin.x, y: origin.y, facing: 1))
        if let p = level.partner {
            let joined = p.pos.x <= origin.x + 130
            spawn(p.kind, x: joined ? origin.x - 50 : p.pos.x, y: joined ? origin.y : p.pos.y, facing: 1)
            fighters[fighters.count - 1].awake = joined
        }
        // After a retry, what was behind the checkpoint stays gone.
        for e in level.enemies where checkpointIndex < 0 || e.pos.x > origin.x - 100 || tuning.spec(for: e.kind).immortal {
            spawn(e.kind, x: e.pos.x, y: e.pos.y, facing: -1)
            fighters[fighters.count - 1].awake = tuning.spec(for: e.kind).brain == nil
        }
        if let b = level.boss {
            bossID = spawn(b.kind, x: b.pos.x, y: b.pos.y, facing: -1)
            fighters[fighters.count - 1].awake = false
        }
        if let t = level.twin {
            twinID = spawn(t.kind, x: t.pos.x, y: t.pos.y, facing: -1)
            fighters[fighters.count - 1].awake = false
        }
    }

    public var controlled: Fighter? { fighter(controlledID) }
    public var boss: Fighter? { bossID.flatMap(fighter) }
    public var twin: Fighter? { twinID.flatMap(fighter) }

    /// The other one of a sworn pair, for either of them.
    public func swornPartner(of id: Int) -> Int? {
        guard let bossID, let twinID else { return nil }
        return id == bossID ? twinID : (id == twinID ? bossID : nil)
    }

    public func fighter(_ id: Int) -> Fighter? {
        fighters.first { $0.id == id }
    }

    // MARK: Setup

    @discardableResult
    public mutating func spawn(
        _ kind: FighterKind, x: Double, y: Double = 0, facing: Double? = nil, spec: FighterSpec? = nil
    ) -> Int {
        let id = nextID
        nextID += 1
        let mid = (arena.lowerBound + arena.upperBound) / 2
        fighters.append(Fighter(
            id: id, kind: kind, team: kind.team, spec: spec ?? tuning.spec(for: kind),
            pos: Vec2(x, y), facing: facing ?? (x <= mid ? 1 : -1)))
        if fighters[fighters.count - 1].spec.lifetime > 0 {
            fighters[fighters.count - 1].expires = fighters[fighters.count - 1].spec.lifetime
        }
        return id
    }

    public mutating func control(_ id: Int) {
        controlledID = id
    }

    public mutating func setWaves(_ waves: [[Spawn]], firstDelay: Int) {
        self.waves = waves
        waveDelay = firstDelay
    }

    // MARK: Step

    public mutating func step(_ input: InputFrame) -> [GameEvent] {
        guard !isOver else { return [] }
        if let i = index(of: controlledID) { latch(&fighters[i], input) }
        if hitStop > 0 {
            hitStop -= 1
            return []
        }

        var events: [GameEvent] = []
        var explosions: [Int] = []
        if switchCooldown > 0 { switchCooldown -= 1 }
        if input.switchHero, switchCooldown == 0, let other = otherHero() {
            passControl(to: other, &events)
        }
        for i in platforms.indices where platforms[i].moves {
            let next = platforms[i].box(at: frame + 1)
            platformDeltas[i] = Vec2(next.minX - platformBoxes[i].minX, next.minY - platformBoxes[i].minY)
            platformBoxes[i] = next
        }
        let snapshot = fighters
        for i in fighters.indices {
            var f = fighters[i]
            var inp = InputFrame.neutral
            if f.id == controlledID {
                inp = input
            } else if f.isAlive, !f.awake, f.team == .hero {
                // A companion waiting to be found.
                if let lead = snapshot.first(where: { $0.id == controlledID }), lead.isAlive,
                   abs(lead.pos.x - f.pos.x) <= tuning.joinRange, abs(lead.pos.y - f.pos.y) <= 120 {
                    f.awake = true
                    f.facing = lead.facing
                    events.append(.joined(id: f.id))
                }
            } else if f.isAlive, !f.awake {
                let noticed = snapshot.contains {
                    $0.team == .hero && $0.isAlive && $0.awake && abs($0.pos.x - f.pos.x) <= tuning.wakeRange
                        && abs($0.pos.y - f.pos.y) <= tuning.wakeHeight
                }
                if noticed {
                    f.awake = true
                    f.aiAux = 0
                    if f.spec.wakeDelay > 0 { f.aiCooldown = f.spec.wakeDelay }
                    events.append(.woke(id: f.id))
                } else if f.spec.runSpeed > 0, !f.spec.rooted, !f.spec.boss {
                    // Paces back and forth until a hero comes close.
                    f.patrolFrames += 1
                    if f.patrolFrames >= tuning.patrolTurnFrames {
                        f.patrolFrames = 0
                        f.facing = -f.facing
                    }
                    inp = InputFrame(moveX: f.facing * tuning.patrolSpeed)
                }
            } else if f.isAlive, f.holding, f.team == .hero {
                // Holding a plate: stays put, facing the way the lead went.
                if let lead = snapshot.first(where: { $0.id == controlledID }) {
                    inp = InputFrame(moveX: (lead.pos.x >= f.pos.x ? 1 : -1) * 0.02)
                }
            } else if f.isAlive, let brain = f.spec.brain {
                // A boss sees the whole room, even from the air.
                let sight = f.team == .enemy && !f.spec.boss ? tuning.enemySightHeight : .infinity
                let foes = snapshot.filter {
                    $0.team != f.team && $0.isAlive && !$0.spec.immortal && abs($0.pos.y - f.pos.y) <= sight
                        && ($0.team == .enemy || $0.awake)
                }
                // A decoy is nobody's ally: the partner neither follows it nor counts it.
                let allies = snapshot.filter { $0.team == f.team && $0.isAlive && !$0.spec.isDecoy }
                inp = brain.think(me: &f, foes: foes, allies: allies, tuning: tuning, rng: &rng)
                if f.team == .hero, level != nil {
                    navigate(&f, &inp, leader: snapshot.first { $0.id == controlledID })
                }
                latch(&f, inp)
            }
            if update(&f, inp, &events) { explosions.append(f.id) }
            integrate(&f, inp, &events)
            if f.descending, f.onGround {
                f.descending = false
                f.enter(.staggered, duration: tuning.protocolLandOpen)
                events.append(.bossLanded(id: f.id))
            }
            fighters[i] = f
        }

        resolveCommands(&events)
        resolveSpecials(&events)
        fadeSummons(&events)
        resolveHits(&events)
        applyEffects(&events)
        updateStrikes(&events)
        for id in explosions { explode(id, &events) }
        puzzleRules(&events)
        levelRules(&events)
        housekeeping(&events)
        cueScenes(&events)
        frame += 1
        return events
    }

    /// Announces each story scene once, when what sets it off happens.
    private mutating func cueScenes(_ events: inout [GameEvent]) {
        guard let level, firedScenes.count < level.scenes.count else { return }
        for trigger in level.scenes where !firedScenes.contains(trigger.scene) {
            let due: Bool = switch trigger.cue {
            case .start: true
            case .reach(let x): (controlled?.pos.x ?? -.infinity) >= x
            case .partnerJoins: events.contains { if case .joined = $0 { true } else { false } }
            case .bossWakes: bossID.map { events.contains(.woke(id: $0)) } ?? false
            case .raised: events.contains { if case .raised = $0 { true } else { false } }
            case .complete: events.contains(.levelComplete)
            }
            if due {
                firedScenes.insert(trigger.scene)
                events.append(.scene(id: trigger.scene))
            }
        }
    }

    private func index(of id: Int) -> Int? {
        fighters.firstIndex { $0.id == id }
    }

    /// The living hero the player is not controlling, if there is one.
    private func otherHero() -> Int? {
        fighters.first { $0.team == .hero && $0.isAlive && $0.awake && !$0.spec.isDecoy && $0.id != controlledID }?.id
    }

    private mutating func passControl(to id: Int, _ events: inout [GameEvent]) {
        // Whoever is left standing on a plate stays to hold it.
        if let old = index(of: controlledID), fighters[old].isAlive, plate(under: fighters[old]) != nil {
            fighters[old].holding = true
            events.append(.holding(id: fighters[old].id))
        }
        if let new = index(of: id) { fighters[new].holding = false }
        controlledID = id
        switchCooldown = tuning.switchCooldown
        events.append(.controlChanged(id: id))
    }

    /// Remembers a press for a few frames, so pressing slightly early still counts.
    private func latch(_ f: inout Fighter, _ inp: InputFrame) {
        if inp.attack { f.attackBuffer = tuning.attackBuffer }
        if inp.jump { f.jumpBuffer = tuning.jumpBuffer }
        if inp.dodge { f.dodgeBuffer = tuning.dodgeBuffer }
        if inp.special { f.specialBuffer = tuning.specialBuffer }
    }

    // MARK: State machine

    /// Returns true when the fighter explodes on this frame.
    private func update(_ f: inout Fighter, _ inp: InputFrame, _ events: inout [GameEvent]) -> Bool {
        var explodes = false
        f.stateFrame += 1
        f.sinceHit += 1
        if f.dodgeCooldown > 0 { f.dodgeCooldown -= 1 }
        if f.invulnerable > 0 { f.invulnerable -= 1 }
        if f.specialCooldown > 0 { f.specialCooldown -= 1 }
        if f.markedFrames > 0 { f.markedFrames -= 1 }
        if f.slowFrames > 0 { f.slowFrames -= 1 }

        switch f.state {
        case .dead:
            if f.onGround { f.vel.x = 0 }

        case .hitstun:
            if f.onGround { f.vel.x *= tuning.hitstunFriction }
            if f.stateFrame >= f.stateDuration { f.enter(.idle) }

        case .staggered:
            if f.onGround { f.vel.x *= tuning.hitstunFriction }
            if f.stateFrame >= f.stateDuration { f.enter(.idle) }

        case .phaseShift:
            f.vel.x = 0
            if f.stateFrame >= f.stateDuration { f.enter(f.onGround ? .idle : .air) }

        case .guardStance:
            if f.onGround { f.vel.x = 0 }
            if f.stateFrame >= f.stateDuration { f.enter(f.onGround ? .idle : .air) }

        case .fuse:
            let sd = f.spec.selfDestruct!
            f.vel.x = inp.moveX * f.spec.runSpeed * sd.speedFactor
            if abs(inp.moveX) > 0.01 { f.facing = inp.moveX > 0 ? 1 : -1 }
            if f.stateFrame >= sd.fuse { explodes = true }

        case .dodge:
            let d = f.spec.dodge!
            f.vel.x = f.facing * d.speed
            if f.stateFrame >= d.duration {
                f.dodgeCooldown = d.cooldown
                f.vel.x = 0
                f.enter(f.onGround ? .idle : .air)
            }

        case .attack(let i):
            let a = f.spec.attacks[i]
            if f.onGround {
                let moving = f.stateFrame < a.windup + a.active && !(a.holdsStill && f.stateFrame < a.windup)
                f.vel.x = moving ? f.facing * a.lunge : 0
            } else if f.flying {
                f.vel.x = 0
            }
            if f.stateFrame == a.windup, a.effect != .strike { f.pendingEffect = i }
            if !f.spec.boss, f.stateFrame >= a.chainFrom, f.attackBuffer > 0, i + 1 < f.spec.attacks.count, f.onGround {
                startAttack(&f, i + 1, inp, &events)
            } else if f.stateFrame >= a.windup + a.active, canDodge(f) {
                startDodge(&f, inp, &events)
            } else if f.stateFrame >= a.total {
                f.enter(f.onGround ? .idle : .air)
            }

        case .idle, .run, .air:
            if abs(inp.moveX) > 0.01 { f.facing = inp.moveX > 0 ? 1 : -1 }
            let target = inp.moveX * f.spec.runSpeed * (f.onGround || f.spec.hovers || f.flying ? 1 : tuning.airControl)
                * (f.slowFrames > 0 ? tuning.slowFactor : 1)
            let rate: Double
            if abs(inp.moveX) <= 0.01 {
                rate = f.onGround ? tuning.groundDecel : tuning.airDecel
            } else if target * f.vel.x < 0 {
                rate = tuning.turnAccel
            } else {
                rate = f.onGround ? tuning.groundAccel : tuning.airAccel
            }
            // Momentum is for the hand on the stick. Brains steer in small corrections and get exact speed.
            let change = f.id == controlledID ? rate / Tuning.framesPerSecond : .infinity
            f.vel.x += max(-change, min(change, target - f.vel.x))
            if f.specialBuffer > 0, f.specialCooldown == 0, let special = f.spec.special {
                f.specialBuffer = 0
                switch special {
                case .command:
                    // Marking needs the other fighters, so the world does it after everyone has moved.
                    f.wantsCommand = true
                case .adapt(let window, _, _, let cooldown):
                    if abs(inp.moveX) > 0.01 { f.facing = inp.moveX > 0 ? 1 : -1 }
                    f.specialCooldown = cooldown
                    f.enter(.guardStance, duration: window)
                    events.append(.guarded(id: f.id))
                case .heal, .decoy:
                    f.wantsSpecial = true
                }
            } else if canDodge(f) {
                startDodge(&f, inp, &events)
            } else if f.attackBuffer > 0, !f.spec.attacks.isEmpty {
                startAttack(&f, f.spec.boss || f.spec.choosesAttacks ? min(f.nextAttack, f.spec.attacks.count - 1) : 0, inp, &events)
            } else {
                if f.jumpBuffer > 0, f.spec.jumpSpeed > 0, f.onGround || f.coyote > 0 {
                    f.jumpBuffer = 0
                    f.coyote = 0
                    f.vel.y = f.spec.jumpSpeed
                    f.onGround = false
                    events.append(.jumped(id: f.id))
                }
                let next: FighterState = !f.onGround ? .air : (abs(inp.moveX) > 0.1 ? .run : .idle)
                if next != f.state { f.enter(next) }
            }
        }

        if f.attackBuffer > 0 { f.attackBuffer -= 1 }
        if f.jumpBuffer > 0 { f.jumpBuffer -= 1 }
        if f.dodgeBuffer > 0 { f.dodgeBuffer -= 1 }
        if f.specialBuffer > 0 { f.specialBuffer -= 1 }
        return explodes
    }

    private func canDodge(_ f: Fighter) -> Bool {
        f.dodgeBuffer > 0 && f.spec.dodge != nil && f.dodgeCooldown == 0 && f.onGround
    }

    private func startAttack(_ f: inout Fighter, _ index: Int, _ inp: InputFrame, _ events: inout [GameEvent]) {
        if abs(inp.moveX) > 0.01 { f.facing = inp.moveX > 0 ? 1 : -1 }
        f.attackBuffer = 0
        f.hitIDs = []
        f.swingScale = 1
        f.enter(.attack(index))
        events.append(.swing(id: f.id, index: index))
    }

    private func startDodge(_ f: inout Fighter, _ inp: InputFrame, _ events: inout [GameEvent]) {
        if abs(inp.moveX) > 0.01 { f.facing = inp.moveX > 0 ? 1 : -1 }
        f.dodgeBuffer = 0
        f.enter(.dodge)
        events.append(.dodged(id: f.id))
    }

    private func integrate(_ f: inout Fighter, _ inp: InputFrame, _ events: inout [GameEvent]) {
        let dt = 1 / Tuning.framesPerSecond
        let half = f.spec.width / 2
        let height = f.spec.height

        // A moving platform carries whoever stands on it.
        if f.onGround, let g = f.groundIndex {
            f.pos.x += platformDeltas[g].x
            f.pos.y += platformDeltas[g].y
        }
        if f.flying, f.isAlive {
            f.vel.y = max(-320, min(320, (tuning.protocolFlightHeight - f.pos.y) * 4))
        } else if f.state == .dodge || (f.spec.hovers && f.isAlive) {
            f.vel.y = 0
        } else if !f.onGround {
            let cut = f.vel.y > 0 && f.id == controlledID && !inp.jumpHeld
            f.vel.y = max(f.vel.y - tuning.gravity * (cut ? tuning.jumpCutGravity : 1) * dt, -tuning.maxFallSpeed)
        }

        // Machines do not walk off an edge by themselves. A hit can still knock them off.
        var blocked = false
        if f.team == .enemy, f.onGround, f.vel.x != 0, f.state != .hitstun, f.state != .dead {
            let probe = f.pos.x + (f.vel.x > 0 ? 1 : -1) * (half + 6)
            if !hasGround(atX: probe, y: f.pos.y) {
                f.vel.x = 0
                blocked = true
            }
        }

        // Sideways, stopped by walls.
        let fromX = f.pos.x
        f.pos.x += f.vel.x * dt
        for (i, b) in platformBoxes.enumerated() where !platforms[i].oneWay {
            guard f.pos.y < b.maxY - 0.5, f.pos.y + height > b.minY + 0.5,
                  f.pos.x + half > b.minX, f.pos.x - half < b.maxX else { continue }
            let fromLeft = fromX <= b.minX || (fromX < b.maxX && fromX < (b.minX + b.maxX) / 2)
            f.pos.x = fromLeft ? b.minX - half : b.maxX + half
            f.vel.x = 0
            blocked = true
        }
        let clamped = min(max(f.pos.x, arena.lowerBound + half), arena.upperBound - half)
        if clamped != f.pos.x {
            f.pos.x = clamped
            blocked = true
        }
        if blocked, !f.awake {
            f.facing = -f.facing
            f.patrolFrames = 0
        }

        // Up and down: land on the highest surface crossed, bump the head on solid undersides.
        let fromY = f.pos.y
        f.pos.y += f.vel.y * dt
        var support: Int?
        var supportTop = -Double.infinity
        for (i, b) in platformBoxes.enumerated() where f.pos.x + half > b.minX + 0.5 && f.pos.x - half < b.maxX - 0.5 {
            if f.vel.y <= 0, fromY >= b.maxY - 0.5, f.pos.y <= b.maxY + 0.01 {
                if b.maxY > supportTop || (b.maxY == supportTop && platforms[i].moves) {
                    support = i
                    supportTop = b.maxY
                }
            } else if !platforms[i].oneWay, f.vel.y > 0, fromY + height <= b.minY + 0.5, f.pos.y + height >= b.minY {
                f.pos.y = b.minY - height
                f.vel.y = 0
            }
        }
        if let support {
            f.pos.y = supportTop
            f.vel.y = 0
            f.groundIndex = support
            if !f.onGround {
                f.onGround = true
                events.append(.landed(id: f.id))
            }
            if f.team == .hero, f.isAlive, !platforms[support].moves { f.lastSafe = f.pos }
        } else {
            f.onGround = false
            f.groundIndex = nil
        }
        if f.onGround {
            f.coyote = tuning.coyoteFrames
        } else if f.coyote > 0 {
            f.coyote -= 1
        }
    }

    /// Gets the AI partner over the level: it jumps the walls and gaps it can clear, waits for hazards,
    /// and does not step into a pit. What it cannot cross it skips by regrouping.
    private func navigate(_ f: inout Fighter, _ inp: inout InputFrame, leader: Fighter?) {
        guard let level, f.onGround, f.isActionable else { return }
        let half = f.spec.width / 2
        let y = f.pos.y

        // The leader is on a floor just above: try to jump up to it.
        if let leader, leader.onGround, leader.pos.y - y > 40, abs(leader.pos.x - f.pos.x) < 140, f.spec.jumpSpeed > 0 {
            inp.jump = true
            return
        }
        guard abs(inp.moveX) > 0.1 else { return }
        let dir: Double = inp.moveX > 0 ? 1 : -1

        for h in level.hazards {
            let near = dir > 0 ? h.box.minX - (f.pos.x + half) : (f.pos.x - half) - h.box.maxX
            guard near > -(h.box.maxX - h.box.minX) - f.spec.width, near < 50 else { continue }
            if h.isOn(at: frame) || h.framesUntilOn(at: frame) < 45 {
                inp.moveX = 0
                return
            }
        }

        for (i, b) in platformBoxes.enumerated() where !platforms[i].oneWay && b.maxY > y + 1 && b.minY < y + f.spec.height {
            let gap = dir > 0 ? b.minX - (f.pos.x + half) : (f.pos.x - half) - b.maxX
            guard gap >= -1, gap < 34 else { continue }
            if b.maxY - y <= 105, f.spec.jumpSpeed > 0 { inp.jump = true } else { inp.moveX = 0 }
            return
        }

        func surface(_ near: Double, _ far: Double, above: Double, below: Double) -> Bool {
            let x0 = min(f.pos.x + dir * near, f.pos.x + dir * far)
            let x1 = max(f.pos.x + dir * near, f.pos.x + dir * far)
            return platformBoxes.contains { $0.maxX > x0 && $0.minX < x1 && $0.maxY <= y + above && $0.maxY >= y - below }
        }
        if !hasGround(atX: f.pos.x + dir * (half + 26), y: y) {
            if surface(70, 165, above: 60, below: 200), f.spec.jumpSpeed > 0 {
                inp.jump = true
            } else if !surface(half, 60, above: 1, below: 400) {
                inp.moveX = 0
            }
        }
    }

    /// Puts a partner that was left behind next to the leader.
    private mutating func regroupPartner(_ events: inout [GameEvent]) {
        guard let lead = controlled, lead.isAlive, lead.onGround, let spot = lead.lastSafe else { return }
        for i in fighters.indices where fighters[i].team == .hero && fighters[i].id != controlledID
            && fighters[i].isAlive && fighters[i].awake && !fighters[i].spec.isDecoy {
            var f = fighters[i]
            let apart = abs(f.pos.y - lead.pos.y) > tuning.partnerStrandedHeight && f.onGround
            f.strandedFrames = apart ? f.strandedFrames + 1 : 0
            // A partner holding a plate is only fetched once the lead has gone well on.
            let lost = abs(f.pos.x - lead.pos.x) > tuning.partnerRegroupDistance
                || (!f.holding && f.strandedFrames >= tuning.partnerStrandedFrames) || f.pos.y < (level?.killY ?? -.infinity) + 40
            if lost {
                f.holding = false
                f.pos = spot
                f.vel = .zero
                f.onGround = false
                f.groundIndex = nil
                f.strandedFrames = 0
                if f.state != .hitstun { f.enter(.idle) }
                f.invulnerable = max(f.invulnerable, 30)
                events.append(.regrouped(id: f.id, at: Vec2(spot.x, spot.y + f.spec.height / 2)))
            }
            fighters[i] = f
        }
    }

    // MARK: Puzzles

    /// True while a fighter stands in the glow of a lit lamp.
    public func isLit(_ f: Fighter) -> Bool {
        guard let level else { return false }
        return level.levers.contains { $0.glow > 0 && signals.contains($0.id) && abs($0.pos.x - f.pos.x) <= $0.glow }
    }

    /// The plate a fighter is standing on, if any.
    public func plate(under f: Fighter) -> Plate? {
        guard f.onGround, let level else { return nil }
        return level.plates.first { f.pos.x >= $0.x0 && f.pos.x <= $0.x1 && abs(f.pos.y - $0.top) < 2 }
    }

    /// True when a gate's levers and plates would have it open.
    public func wantsOpen(_ gate: Gate) -> Bool {
        let all = gate.opensWith.allSatisfy { signals.contains($0) }
        return gate.inverted ? !all : all
    }

    /// Levers thrown by heroes' swings and springing back; plates under heroes; gates sliding toward what their
    /// inputs ask. A gate will not shut on someone standing in its way.
    private mutating func puzzleRules(_ events: inout [GameEvent]) {
        guard let level else { return }
        for lever in level.levers {
            if let left = leverTimers[lever.id] {
                if left <= 1 {
                    leverTimers[lever.id] = nil
                    signals.remove(lever.id)
                    events.append(.lever(id: lever.id, on: false))
                } else {
                    leverTimers[lever.id] = left - 1
                }
            }
            let tag = -1000 - lever.id
            let bells = level.gates.filter { $0.inOrder && $0.opensWith.contains(lever.id) }
            for i in fighters.indices where fighters[i].team == .hero && fighters[i].isAlive && !fighters[i].spec.isDecoy {
                guard let box = fighters[i].hitbox, box.intersects(lever.box), !fighters[i].hitIDs.contains(tag) else { continue }
                // Only the lead rings a bell.
                if !bells.isEmpty, fighters[i].id != controlledID { continue }
                fighters[i].hitIDs.insert(tag)
                if !signals.contains(lever.id) {
                    if let gate = bells.first(where: { g in
                        g.opensWith.firstIndex(of: lever.id).map { $0 > 0 && !signals.contains(g.opensWith[$0 - 1]) } ?? false
                    }) {
                        // Out of order: the bells of that gate fall silent.
                        for id in gate.opensWith where signals.contains(id) {
                            signals.remove(id)
                            leverTimers[id] = nil
                            events.append(.lever(id: id, on: false))
                        }
                        events.append(.discord(gate: gate.id))
                        continue
                    }
                    signals.insert(lever.id)
                    events.append(.lever(id: lever.id, on: true))
                }
                if lever.holdFrames > 0 { leverTimers[lever.id] = lever.holdFrames }
            }
        }
        for i in fighters.indices where fighters[i].spec.needsLight {
            fighters[i].inLight = isLit(fighters[i])
        }
        for plate in level.plates {
            let down = fighters.contains { $0.team == .hero && $0.isAlive && self.plate(under: $0)?.id == plate.id }
            if down != signals.contains(plate.id) {
                if down { signals.insert(plate.id) } else { signals.remove(plate.id) }
                events.append(.plate(id: plate.id, down: down))
            }
        }
        for gate in level.gates {
            guard let p = gatePlatform[gate.id], let open = gateOpen[gate.id] else { continue }
            let target: Double = wantsOpen(gate) ? 1 : 0
            guard open != target else { platformDeltas[p] = .zero; continue }
            // Someone under it holds a closing gate up.
            if target < open, fighters.contains(where: { $0.isAlive && $0.hurtbox.intersects(gate.box) }) {
                platformDeltas[p] = .zero
                continue
            }
            if open == 0 || open == 1 { events.append(.gate(id: gate.id, opening: target > open)) }
            let next = target > open ? min(1, open + tuning.gateSpeed) : max(0, open - tuning.gateSpeed)
            gateOpen[gate.id] = next
            let lift = next * (gate.box.maxY - gate.box.minY + 20)
            let moved = gate.box.offset(by: Vec2(0, lift))
            platformDeltas[p] = Vec2(0, moved.minY - platformBoxes[p].minY)
            platformBoxes[p] = moved
        }
    }

    private func hasGround(atX x: Double, y: Double) -> Bool {
        platformBoxes.contains { $0.minX <= x && x <= $0.maxX && $0.maxY <= y + 1 && $0.maxY >= y - 8 }
    }

    /// True while a living Dogma Frame stands close enough to shield this machine.
    public func isWarded(_ id: Int) -> Bool {
        if let f = fighter(id), f.isAlive, f.spec.needsLight, !isLit(f) { return true }
        if let f = fighter(id), f.isAlive, let guardKind = f.spec.shieldedBy {
            return fighters.contains { $0.kind == guardKind && $0.isAlive && abs($0.pos.x - f.pos.x) <= tuning.debtorShieldRange }
        }
        guard let f = fighter(id), f.isAlive, f.spec.wardRadius == 0, !f.spec.boss else { return false }
        return fighters.contains {
            $0.spec.wardRadius > 0 && $0.isAlive && $0.awake && $0.team == f.team
                && abs($0.pos.x - f.pos.x) <= $0.spec.wardRadius && abs($0.pos.y - f.pos.y) <= tuning.wardHeight
        }
    }

    // MARK: Boss effects

    /// Summons and light called down by attacks whose active frames began this frame.
    private mutating func applyEffects(_ events: inout [GameEvent]) {
        for i in fighters.indices {
            guard let index = fighters[i].pendingEffect else { continue }
            fighters[i].pendingEffect = nil
            let me = fighters[i]
            switch me.spec.attacks[index].effect {
            case .strike:
                break
            case .summon(let kind, let count):
                // A boss counts everyone fighting beside it; anyone else counts only what it calls.
                let living = me.spec.boss
                    ? fighters.filter { $0.team == me.team && $0.isAlive && !$0.spec.boss && !$0.spec.immortal }.count
                    : fighters.filter { $0.kind == kind && $0.isAlive && abs($0.pos.x - me.pos.x) < 800 }.count
                let cap = me.spec.boss ? tuning.protocolMaxMinions : tuning.maxSummoned
                for n in 0..<max(0, min(count, cap - living)) {
                    let side: Double = n % 2 == 0 ? -1 : 1
                    let x = me.pos.x + side * (me.spec.width / 2 + 60 + Double(n / 2) * 60)
                    // Boss rooms have their floor at 0; elsewhere they appear on the summoner's floor.
                    let y = me.spec.boss ? 0 : me.pos.y
                    let id = spawn(kind, x: min(max(x, arena.lowerBound + 40), arena.upperBound - 40), y: y, facing: -side)
                    if let s = self.index(of: id) { fighters[s].onGround = me.onGround }
                    events.append(.spawned(id: id, kind: kind))
                }
            case .lob(let lob):
                lobbed(lob, from: me, &events)
            case .eruption(let columns, let width, let height, let warning, let active, let damage, let kind):
                var xs = fighters.filter { $0.team != me.team && $0.isAlive && $0.awake }.map(\.pos.x)
                var tries = 0
                while xs.count < columns, tries < 40 {
                    tries += 1
                    let x = Double.random(in: (arena.lowerBound + width)...(arena.upperBound - width), using: &rng)
                    if xs.allSatisfy({ abs($0 - x) > width * 1.5 }) { xs.append(x) }
                }
                for x in xs.prefix(columns) {
                    var strike = Strike(box: Box(minX: x - width / 2, minY: -4, maxX: x + width / 2, maxY: height),
                                        warning: warning, active: active, damage: damage)
                    strike.kind = kind
                    strikes.append(strike)
                }
            case .mend(let amount, let range):
                for t in fighters.indices where t != i && fighters[t].team == me.team && fighters[t].isAlive
                    && !fighters[t].spec.immortal && abs(fighters[t].pos.x - me.pos.x) <= range
                    && abs(fighters[t].pos.y - me.pos.y) <= 220 {
                    let gained = min(amount, fighters[t].spec.maxHP - fighters[t].hp)
                    guard gained > 0 else { continue }
                    fighters[t].hp += gained
                    events.append(.healed(id: fighters[t].id, amount: gained))
                }
            case .flare(let radius, let daze):
                dazzle(from: me, radius: radius, frames: daze, lookingAt: true, &events)
            case .eclipse(let radius, let daze):
                dazzle(from: me, radius: radius, frames: daze, lookingAt: false, &events)
            case .douse(let range):
                for lamp in level?.levers ?? [] where lamp.glow > 0 && signals.contains(lamp.id)
                    && abs(lamp.pos.x - me.pos.x) <= range {
                    signals.remove(lamp.id)
                    leverTimers[lamp.id] = nil
                    events.append(.lever(id: lamp.id, on: false))
                }
            case .prophecy(let width, let height, let warning, let active, let damage):
                for h in fighters where h.team != me.team && h.isAlive && h.awake && !h.spec.isDecoy {
                    // Where they will be when it lands, if they keep going.
                    let ahead = h.pos.x + h.vel.x * Double(warning) / Tuning.framesPerSecond
                    let x = min(max(ahead, arena.lowerBound + width / 2), arena.upperBound - width / 2)
                    var strike = Strike(box: Box(minX: x - width / 2, minY: -4, maxX: x + width / 2, maxY: height),
                                        warning: warning, active: active, damage: damage)
                    strike.kind = .light
                    strikes.append(strike)
                }
            case .rain(let columns, let width, let warning, let active, let damage):
                var xs = fighters.filter { $0.team != me.team && $0.isAlive && $0.awake }.map(\.pos.x)
                var tries = 0
                while xs.count < columns, tries < 40 {
                    tries += 1
                    let x = Double.random(in: (arena.lowerBound + width)...(arena.upperBound - width), using: &rng)
                    if xs.allSatisfy({ abs($0 - x) > width * 1.5 }) { xs.append(x) }
                }
                for x in xs.prefix(columns) {
                    strikes.append(Strike(
                        box: Box(minX: x - width / 2, minY: -50, maxX: x + width / 2, maxY: 600),
                        warning: warning, active: active, damage: damage))
                }
            }
        }
    }

    /// A flare (dazes those looking at it) or an eclipse (dazes those looking away), from the attacker's centre.
    private mutating func dazzle(from me: Fighter, radius: Double, frames: Int, lookingAt: Bool, _ events: inout [GameEvent]) {
        let centre = Vec2(me.pos.x, me.pos.y + me.spec.height / 2)
        events.append(lookingAt ? .flared(id: me.id, at: centre, radius: radius) : .eclipsed(id: me.id, at: centre, radius: radius))
        for t in fighters.indices where fighters[t].team != me.team && fighters[t].isAlive
            && !fighters[t].spec.isDecoy && !fighters[t].isDodgeInvulnerable {
            let h = fighters[t]
            let dx = me.pos.x - h.pos.x
            let dy = centre.y - (h.pos.y + h.spec.height / 2)
            guard dx * dx + dy * dy <= radius * radius else { continue }
            // Standing right on it counts as looking at it.
            let facing = dx * h.facing > 0 || abs(dx) < 8
            guard facing == lookingAt else { continue }
            fighters[t].vel.x = 0
            fighters[t].enter(.hitstun, duration: frames)
            events.append(.dazed(id: h.id))
        }
    }

    /// Lands a thrown thing under the nearest hero in range, or as far as it carries toward them, on the ground there.
    private mutating func lobbed(_ lob: Lob, from me: Fighter, _ events: inout [GameEvent]) {
        let heroes = fighters.filter { $0.team != me.team && $0.isAlive && $0.awake }
        let target = heroes.min { abs($0.pos.x - me.pos.x) < abs($1.pos.x - me.pos.x) }
        var x = me.pos.x + me.facing * lob.range
        var y = me.pos.y
        if let target, abs(target.pos.x - me.pos.x) <= lob.range {
            x = target.pos.x
            y = target.pos.y
        }
        // The highest floor at or below that point.
        let floors = platformBoxes.filter { $0.minX <= x && x <= $0.maxX && $0.maxY <= y + 1 }
        guard let floor = floors.max(by: { $0.maxY < $1.maxY })?.maxY else { return }
        var strike = Strike(box: Box(minX: x - lob.width / 2, minY: floor - 4, maxX: x + lob.width / 2, maxY: floor + lob.height),
                            warning: lob.warning, active: lob.active, damage: lob.damage)
        strike.kind = lob.kind
        strike.slowFrames = lob.slowFrames
        strikes.append(strike)
        events.append(.lobbed(id: me.id, kind: lob.kind, at: Vec2(x, floor)))
    }

    private mutating func updateStrikes(_ events: inout [GameEvent]) {
        guard !strikes.isEmpty else { return }
        for s in strikes.indices {
            strikes[s].age += 1
            if strikes[s].age == strikes[s].warning {
                events.append(.struck(at: Vec2(strikes[s].box.center.x, strikes[s].box.minY + 4), width: strikes[s].box.width,
                                      kind: strikes[s].kind))
            }
            guard strikes[s].isActive else { continue }
            for t in fighters.indices where fighters[t].team == .hero && fighters[t].isAlive && fighters[t].awake
                && !strikes[s].hit.contains(fighters[t].id) {
                let f = fighters[t]
                guard strikes[s].box.intersects(f.hurtbox) else { continue }
                strikes[s].hit.insert(f.id)
                if f.isDodgeInvulnerable {
                    events.append(.evaded(id: f.id))
                    continue
                }
                if f.invulnerable > 0 { continue }
                if f.state == .guardStance {
                    events.append(.absorbed(by: f.id, attacker: bossID ?? -1, at: f.hurtbox.center))
                    continue
                }
                if strikes[s].slowFrames > 0 {
                    fighters[t].slowFrames = strikes[s].slowFrames
                    events.append(.slowed(id: f.id))
                }
                guard strikes[s].damage > 0 else { continue }
                let push: Double = f.pos.x >= strikes[s].box.center.x ? 1 : -1
                hurt(t, damage: strikes[s].damage, by: bossID ?? -1, at: f.hurtbox.center, push: push * 220,
                     hitstun: 16, &events)
                hitStop = max(hitStop, tuning.heroHurtHitStop)
            }
        }
        strikes.removeAll(where: \.isDone)
    }

    // MARK: Specials

    /// Caelen's Command: marks the nearest enemy in front, or the nearest at all when none is in front.
    private mutating func resolveCommands(_ events: inout [GameEvent]) {
        for i in fighters.indices where fighters[i].wantsCommand {
            fighters[i].wantsCommand = false
            let me = fighters[i]
            guard case .command(let range, let frames, let scale, let cooldown)? = me.spec.special else { continue }
            let near = fighters.indices.filter {
                let f = fighters[$0]
                return f.team != me.team && f.isAlive && !f.spec.immortal && abs(f.pos.x - me.pos.x) <= range
                    && abs(f.pos.y - me.pos.y) <= 220
            }
            let ahead = near.filter { (fighters[$0].pos.x - me.pos.x) * me.facing >= 0 }
            let pick = (ahead.isEmpty ? near : ahead).min {
                abs(fighters[$0].pos.x - me.pos.x) < abs(fighters[$1].pos.x - me.pos.x)
            }
            // With nobody to mark the ability is not spent.
            guard let pick else { continue }
            for t in fighters.indices where fighters[t].team != me.team { fighters[t].markedFrames = 0 }
            fighters[pick].markedFrames = frames
            fighters[pick].markScale = scale
            fighters[i].specialCooldown = cooldown
            events.append(.commanded(by: me.id, target: fighters[pick].id))
        }
    }

    /// Seraphine's heal and Nimue's decoy, and the decoys' clocks.
    private mutating func resolveSpecials(_ events: inout [GameEvent]) {
        var newDecoys: [(owner: Int, frames: Int)] = []
        for i in fighters.indices where fighters[i].wantsSpecial {
            fighters[i].wantsSpecial = false
            let me = fighters[i]
            switch me.spec.special {
            case .heal(let amount, let range, let cooldown)?:
                fighters[i].specialCooldown = cooldown
                for t in fighters.indices where fighters[t].team == me.team && fighters[t].isAlive && fighters[t].awake
                    && !fighters[t].spec.isDecoy && abs(fighters[t].pos.x - me.pos.x) <= range
                    && abs(fighters[t].pos.y - me.pos.y) <= 220 {
                    let gained = min(amount, fighters[t].spec.maxHP - fighters[t].hp)
                    guard gained > 0 else { continue }
                    fighters[t].hp += gained
                    events.append(.healed(id: fighters[t].id, amount: gained))
                }
            case .decoy(let frames, let cooldown)?:
                fighters[i].specialCooldown = cooldown
                newDecoys.append((i, frames))
            default:
                break
            }
        }
        for (owner, frames) in newDecoys {
            let me = fighters[owner]
            // One at a time: a new decoy replaces the old one.
            for d in fighters.indices where fighters[d].spec.isDecoy { fighters[d].expires = 1 }
            let id = spawn(.decoy, x: me.pos.x, y: me.pos.y, facing: me.facing)
            if let d = index(of: id) {
                fighters[d].expires = frames + 1
                fighters[d].awake = true
                fighters[d].onGround = me.onGround
            }
            events.append(.decoyPlaced(id: id, at: me.pos))
        }
        for d in fighters.indices where fighters[d].spec.isDecoy {
            fighters[d].expires -= 1
            if fighters[d].expires <= 0 || !fighters[d].isAlive {
                events.append(.decoyGone(id: fighters[d].id, at: fighters[d].hurtbox.center))
            }
        }
        fighters.removeAll { $0.spec.isDecoy && ($0.expires <= 0 || !$0.isAlive) }
    }

    /// Things that last only a while, such as a Night Weaver's images, fade when their time is up.
    private mutating func fadeSummons(_ events: inout [GameEvent]) {
        for i in fighters.indices where fighters[i].spec.lifetime > 0 && !fighters[i].spec.isDecoy && fighters[i].isAlive {
            fighters[i].expires -= 1
            if fighters[i].expires <= 0 { events.append(.faded(id: fighters[i].id, at: fighters[i].hurtbox.center)) }
        }
        fighters.removeAll { $0.spec.lifetime > 0 && !$0.spec.isDecoy && $0.isAlive && $0.expires <= 0 }
    }

    // MARK: Hits

    private mutating func resolveHits(_ events: inout [GameEvent]) {
        for a in fighters.indices {
            guard let box = fighters[a].hitbox, let attack = fighters[a].currentAttack else { continue }
            for t in fighters.indices where t != a {
                guard fighters[t].team != fighters[a].team, fighters[t].isAlive, fighters[t].awake || fighters[t].team == .enemy,
                      !fighters[a].hitIDs.contains(fighters[t].id),
                      box.intersects(fighters[t].hurtbox) else { continue }
                fighters[a].hitIDs.insert(fighters[t].id)
                let contact = Vec2(
                    (max(box.minX, fighters[t].hurtbox.minX) + min(box.maxX, fighters[t].hurtbox.maxX)) / 2,
                    (max(box.minY, fighters[t].hurtbox.minY) + min(box.maxY, fighters[t].hurtbox.maxY)) / 2)
                land(attack, from: a, on: t, at: contact, &events)
                // A parry staggers the attacker and ends its swing.
                if fighters[a].hitbox == nil { break }
            }
        }
    }

    private mutating func land(_ attack: AttackSpec, from a: Int, on t: Int, at contact: Vec2, _ events: inout [GameEvent]) {
        let attacker = fighters[a]
        let target = fighters[t]

        if target.isDodgeInvulnerable {
            events.append(.evaded(id: target.id))
            return
        }
        if target.invulnerable > 0 { return }

        if target.state == .guardStance, case .adapt(_, let stagger, let counterScale, _)? = target.spec.special {
            // The hit is taken on the guard: the attacker reels and the counter starts at once.
            fighters[a].enter(.staggered, duration: stagger)
            fighters[a].vel.x = -attacker.facing * 120
            var me = target
            me.facing = attacker.pos.x >= me.pos.x ? 1 : -1
            me.hitIDs = []
            me.attackBuffer = 0
            me.enter(.attack(me.spec.attacks.count - 1))
            me.swingScale = counterScale
            me.invulnerable = max(me.invulnerable, me.spec.attacks.last?.total ?? 0)
            fighters[t] = me
            hitStop = max(hitStop, tuning.parryHitStop)
            events.append(.absorbed(by: target.id, attacker: attacker.id, at: contact))
            events.append(.swing(id: target.id, index: target.spec.attacks.count - 1))
            return
        }

        if target.isParrying, attacker.team == .enemy {
            fighters[a].enter(.staggered, duration: tuning.parryStagger)
            fighters[a].vel.x = -attacker.facing * 120
            hitStop = max(hitStop, tuning.parryHitStop)
            events.append(.parried(by: target.id, attacker: attacker.id, at: contact))
            return
        }

        let fromFront = (attacker.pos.x - target.pos.x) * target.facing >= 0
        if !target.isOpen || (target.isGuarding && fromFront) || isWarded(target.id) {
            events.append(.blocked(attacker: attacker.id, target: target.id, at: contact))
            if let r = target.spec.riposte, target.isGuarding, fromFront, target.isActionable {
                var g = fighters[t]
                startAttack(&g, r, .neutral, &events)
                fighters[t] = g
            }
            return
        }

        let push: Double = attacker.pos.x == target.pos.x ? attacker.facing : (target.pos.x > attacker.pos.x ? 1 : -1)
        let ai = attacker.team == .hero && attacker.id != controlledID
        hurt(t, damage: attack.damage * attacker.swingScale * (ai ? tuning.partnerDamageScale : 1), by: attacker.id, at: contact, push: push * attack.knockback,
             hitstun: attack.hitstun, &events)
        hitStop = max(hitStop, target.team == .hero ? tuning.heroHurtHitStop : attack.hitStop)
        if attack.slowFrames > 0, fighters[t].isAlive {
            fighters[t].slowFrames = attack.slowFrames
            events.append(.slowed(id: target.id))
        }
    }

    private mutating func hurt(
        _ t: Int, damage base: Double, by attackerID: Int, at contact: Vec2, push: Double, hitstun: Int,
        _ events: inout [GameEvent]
    ) {
        var f = fighters[t]
        let damage = base * (f.state == .staggered ? tuning.staggerDamageBonus : 1) * (f.markedFrames > 0 ? f.markScale : 1)
            * (f.team == .hero ? tuning.heroDamageScale : 1)
        f.hp = f.spec.immortal ? max(1, f.hp - damage) : f.hp - damage
        f.sinceHit = 0
        events.append(.hit(attacker: attackerID, target: f.id, damage: damage, at: contact))

        // A boss cannot be hurt past a phase threshold: it stops there and changes phase.
        if f.spec.boss, f.phase <= f.spec.phaseThresholds.count {
            let floor = f.spec.maxHP * f.spec.phaseThresholds[f.phase - 1]
            if f.hp <= floor {
                f.hp = floor
                f.phase += 1
                f.flying = f.spec.flightPhase > 0 && f.phase == f.spec.flightPhase
                f.descending = false
                f.aiAux2 = 0
                f.aiCooldown = 0
                f.vel.x = 0
                f.enter(.phaseShift, duration: tuning.bossPhaseShiftFrames)
                f.invulnerable = tuning.bossPhaseShiftFrames
                events.append(.bossPhase(id: f.id, phase: f.phase))
                fighters[t] = f
                return
            }
        }

        if f.hp <= 0 {
            f.hp = 0
            f.vel.x = push
            f.enter(.dead)
            events.append(.died(id: f.id))
            let partnerStands = swornPartner(of: f.id).flatMap(fighter)?.isAlive ?? false
            if f.spec.boss, !partnerStands { events.append(.bossDefeated(id: f.id)) }
        } else {
            if let sd = f.spec.selfDestruct, f.state != .fuse, f.hp <= f.spec.maxHP * sd.threshold {
                f.enter(.fuse)
                events.append(.fuseLit(id: f.id))
            } else if f.state == .fuse || f.state == .staggered || f.spec.rooted || f.spec.armored
                        || f.spec.unflinching {
                // Keeps doing what it was doing.
            } else if f.spec.poise, case .attack = f.state {
                // Finishes its swing.
            } else {
                f.vel.x = push
                f.enter(.hitstun, duration: hitstun)
            }
            f.invulnerable = f.spec.hurtInvulnerable
        }
        fighters[t] = f
    }

    private mutating func explode(_ id: Int, _ events: inout [GameEvent]) {
        guard let i = index(of: id), fighters[i].state == .fuse, let sd = fighters[i].spec.selfDestruct else { return }
        let source = fighters[i]
        let centre = Vec2(source.pos.x, source.pos.y + source.spec.height / 2)
        fighters[i].hp = 0
        fighters[i].enter(.dead)
        // It is gone at once, so it does not linger as a corpse.
        fighters[i].stateFrame = tuning.corpseFrames
        events.append(.exploded(id: id, at: centre, radius: sd.radius))
        events.append(.died(id: id))

        for t in fighters.indices where fighters[t].team != source.team && fighters[t].isAlive {
            let target = fighters[t]
            if target.team == .hero, !target.awake { continue }
            let box = target.hurtbox
            let dx = max(box.minX - centre.x, 0, centre.x - box.maxX)
            let dy = max(box.minY - centre.y, 0, centre.y - box.maxY)
            guard dx * dx + dy * dy <= sd.radius * sd.radius else { continue }
            if target.isDodgeInvulnerable {
                events.append(.evaded(id: target.id))
                continue
            }
            if target.invulnerable > 0 { continue }
            if target.state == .guardStance {
                events.append(.absorbed(by: target.id, attacker: id, at: box.center))
                continue
            }
            let push: Double = target.pos.x >= centre.x ? 1 : -1
            hurt(t, damage: sd.damage, by: id, at: box.center, push: push * 300, hitstun: 18, &events)
            hitStop = max(hitStop, tuning.heroHurtHitStop)
        }
    }

    // MARK: Level rules

    /// Pits, hazards, checkpoints, pickups and the exit. Does nothing in the training room.
    private mutating func levelRules(_ events: inout [GameEvent]) {
        guard let level else { return }
        regroupPartner(&events)
        swornRules(&events)

        for i in fighters.indices where fighters[i].pos.y < level.killY {
            var f = fighters[i]
            defer { fighters[i] = f }
            f.vel = .zero
            f.pos.y = level.killY
            guard f.isAlive else { continue }
            // A decoy that falls is simply gone.
            if f.spec.isDecoy {
                f.hp = 0
                continue
            }
            if f.team == .enemy {
                f.hp = 0
                f.enter(.dead)
                f.stateFrame = tuning.corpseFrames
                events.append(.died(id: f.id))
                continue
            }
            events.append(.fell(id: f.id))
            f.hp -= tuning.fallDamage
            if f.hp <= 0 {
                f.hp = 0
                f.enter(.dead)
                events.append(.died(id: f.id))
            } else {
                f.pos = f.lastSafe ?? (checkpointIndex >= 0 ? level.checkpoints[checkpointIndex] : level.start)
                f.onGround = false
                f.groundIndex = nil
                f.enter(.idle)
                f.invulnerable = max(f.spec.hurtInvulnerable, 60)
                events.append(.respawned(id: f.id))
            }
        }

        for hazard in level.hazards where hazard.isOn(at: frame) {
            for i in fighters.indices where fighters[i].team == .hero && fighters[i].isAlive && fighters[i].awake
                && !fighters[i].spec.isDecoy {
                let f = fighters[i]
                guard f.invulnerable == 0, !f.isDodgeInvulnerable, hazard.box.intersects(f.hurtbox) else { continue }
                let push: Double = f.pos.x >= hazard.box.center.x ? 1 : -1
                hurt(i, damage: hazard.damage, by: -1, at: f.hurtbox.center, push: push * 260, hitstun: 16, &events)
                hitStop = max(hitStop, tuning.heroHurtHitStop)
            }
        }

        for i in fighters.indices where fighters[i].team == .hero && fighters[i].isAlive && !fighters[i].spec.isDecoy {
            let reach = tuning.pickupReach
            let box = fighters[i].hurtbox
            for p in level.pickups where !collected.contains(p.id)
                && p.pos.x >= box.minX - reach && p.pos.x <= box.maxX + reach
                && p.pos.y >= box.minY - reach && p.pos.y <= box.maxY + reach {
                collected.insert(p.id)
                events.append(.collected(id: p.id, secret: p.secret, at: p.pos))
            }
        }

        guard let i = index(of: controlledID), fighters[i].isAlive else { return }
        let hero = fighters[i]
        for (n, c) in level.checkpoints.enumerated() where n > checkpointIndex
            && abs(hero.pos.x - c.x) < 40 && abs(hero.pos.y - c.y) < 120 {
            checkpointIndex = n
            fighters[i].hp = min(hero.spec.maxHP, hero.hp + tuning.checkpointHeal)
            events.append(.checkpoint(index: n))
        }
        let twinDown = twinID.flatMap(fighter).map { !$0.isAlive } ?? true
        if let bossID, let b = index(of: bossID), !fighters[b].isAlive, twinDown {
            bossDownFrames += 1
            if bossDownFrames >= tuning.bossVictoryFrames {
                isComplete = true
                isOver = true
                events.append(.levelComplete)
            }
        } else if hero.onGround, hero.pos.x >= level.exitX {
            isComplete = true
            isOver = true
            events.append(.levelComplete)
        }
    }

    /// A sworn pair wakes together, and one left down alone too long is raised by the other.
    private mutating func swornRules(_ events: inout [GameEvent]) {
        guard let a = bossID.flatMap(index(of:)), let b = twinID.flatMap(index(of:)) else { return }
        for (me, other) in [(a, b), (b, a)] where fighters[me].awake && !fighters[other].awake {
            fighters[other].awake = true
            fighters[other].aiCooldown = fighters[other].spec.wakeDelay
            events.append(.woke(id: fighters[other].id))
        }
        let down = [a, b].filter { !fighters[$0].isAlive }
        guard down.count == 1, let fallen = down.first else {
            vowFrames = 0
            return
        }
        vowFrames += 1
        guard vowFrames >= tuning.swornRiseFrames else { return }
        vowFrames = 0
        let raiser = fallen == a ? b : a
        var f = fighters[fallen]
        f.hp = f.spec.maxHP * tuning.swornRiseShare
        f.vel = .zero
        f.aiCooldown = f.spec.wakeDelay
        f.enter(.phaseShift, duration: tuning.bossPhaseShiftFrames)
        f.invulnerable = tuning.bossPhaseShiftFrames
        fighters[fallen] = f
        events.append(.raised(id: f.id, by: fighters[raiser].id))
    }

    // MARK: Waves and endings

    private mutating func housekeeping(_ events: inout [GameEvent]) {
        guard !isComplete else { return }
        let corpseFrames = tuning.corpseFrames
        fighters.removeAll { $0.team == .enemy && $0.state == .dead && $0.stateFrame >= corpseFrames && !$0.spec.boss }
        for i in fighters.indices where fighters[i].spec.immortal && fighters[i].sinceHit > tuning.dummyRegenFrames {
            fighters[i].hp = fighters[i].spec.maxHP
        }

        if let hero = controlled, !hero.isAlive {
            if let other = otherHero() {
                passControl(to: other, &events)
            } else {
                isOver = true
                events.append(.heroDown)
                return
            }
        }

        guard !waves.isEmpty else { return }
        let remaining = fighters.contains { $0.team == .enemy && $0.isAlive && !$0.spec.immortal }
        if waveLive, !remaining {
            waveLive = false
            waveDelay = tuning.waveDelay
            events.append(.waveCleared(number: waveNumber))
            for i in fighters.indices where fighters[i].team == .hero {
                if fighters[i].isAlive {
                    fighters[i].hp = min(fighters[i].spec.maxHP, fighters[i].hp + tuning.waveClearHeal)
                } else {
                    fighters[i].hp = fighters[i].spec.maxHP * tuning.reviveFraction
                    fighters[i].enter(.idle)
                    fighters[i].invulnerable = fighters[i].spec.hurtInvulnerable
                    events.append(.revived(id: fighters[i].id))
                }
            }
        } else if !waveLive, !remaining {
            if waveDelay > 0 {
                waveDelay -= 1
            } else {
                let wave = waves[waveNumber % waves.count]
                waveNumber += 1
                waveLive = true
                events.append(.waveStarted(number: waveNumber))
                let width = arena.upperBound - arena.lowerBound
                for s in wave {
                    let id = spawn(s.kind, x: arena.lowerBound + s.x * width)
                    if let hero = controlled, let i = index(of: id) {
                        fighters[i].facing = hero.pos.x >= fighters[i].pos.x ? 1 : -1
                    }
                    events.append(.spawned(id: id, kind: s.kind))
                }
            }
        }
    }
}

extension World {
    /// Stage 1: Caelen alone in a grey-box room with a training dummy and looping waves.
    public static func feelSlice(seed: UInt64, tuning: Tuning = Tuning()) -> World {
        var world = World(tuning: tuning, seed: seed)
        world.spawn(.dummy, x: 150, facing: 1)
        world.control(world.spawn(.caelen, x: 380, facing: 1))
        world.setWaves([
            [Spawn(.scrapDrone, x: 0.92), Spawn(.scrapDrone, x: 0.99)],
            [Spawn(.forgedSoldier, x: 0.95)],
            [Spawn(.scrapDrone, x: 0.90), Spawn(.scrapDrone, x: 0.97), Spawn(.forgedSoldier, x: 0.99)],
            [Spawn(.forgedSoldier, x: 0.94), Spawn(.scrapDrone, x: 0.02), Spawn(.scrapDrone, x: 0.99),
             Spawn(.scrapDrone, x: 0.86)],
        ], firstDelay: 240)
        return world
    }

    /// Stage 2: the same room with Orion at Caelen's side. The player can switch between them.
    public static func partnerSlice(seed: UInt64, tuning: Tuning = Tuning()) -> World {
        var world = feelSlice(seed: seed, tuning: tuning)
        world.spawn(.orion, x: 290, facing: 1)
        return world
    }
}
