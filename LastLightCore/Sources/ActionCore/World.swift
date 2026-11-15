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
    var bossDownFrames = 0
    var firedScenes: Set<String> = []
    var platformDeltas: [Vec2]

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
        platforms = level.platforms
        platformBoxes = platforms.map { $0.box(at: 0) }
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
    }

    public var controlled: Fighter? { fighter(controlledID) }
    public var boss: Fighter? { bossID.flatMap(fighter) }

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
            } else if f.isAlive, let brain = f.spec.brain {
                let sight = f.team == .enemy ? tuning.enemySightHeight : .infinity
                let foes = snapshot.filter {
                    $0.team != f.team && $0.isAlive && !$0.spec.immortal && abs($0.pos.y - f.pos.y) <= sight
                        && ($0.team == .enemy || $0.awake)
                }
                let allies = snapshot.filter { $0.team == f.team && $0.isAlive }
                inp = brain.think(me: &f, foes: foes, allies: allies, tuning: tuning, rng: &rng)
                if f.team == .hero, level != nil {
                    navigate(&f, &inp, leader: snapshot.first { $0.id == controlledID })
                }
                latch(&f, inp)
            }
            if update(&f, inp, &events) { explosions.append(f.id) }
            integrate(&f, inp, &events)
            fighters[i] = f
        }

        resolveHits(&events)
        for id in explosions { explode(id, &events) }
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
        fighters.first { $0.team == .hero && $0.isAlive && $0.awake && $0.id != controlledID }?.id
    }

    private mutating func passControl(to id: Int, _ events: inout [GameEvent]) {
        controlledID = id
        switchCooldown = tuning.switchCooldown
        events.append(.controlChanged(id: id))
    }

    /// Remembers a press for a few frames, so pressing slightly early still counts.
    private func latch(_ f: inout Fighter, _ inp: InputFrame) {
        if inp.attack { f.attackBuffer = tuning.attackBuffer }
        if inp.jump { f.jumpBuffer = tuning.jumpBuffer }
        if inp.dodge { f.dodgeBuffer = tuning.dodgeBuffer }
    }

    // MARK: State machine

    /// Returns true when the fighter explodes on this frame.
    private func update(_ f: inout Fighter, _ inp: InputFrame, _ events: inout [GameEvent]) -> Bool {
        var explodes = false
        f.stateFrame += 1
        f.sinceHit += 1
        if f.dodgeCooldown > 0 { f.dodgeCooldown -= 1 }
        if f.invulnerable > 0 { f.invulnerable -= 1 }

        switch f.state {
        case .dead:
            if f.onGround { f.vel.x = 0 }

        case .hitstun:
            if f.onGround { f.vel.x *= tuning.hitstunFriction }
            if f.stateFrame >= f.stateDuration { f.enter(.idle) }

        case .staggered:
            if f.onGround { f.vel.x *= tuning.hitstunFriction }
            if f.stateFrame >= f.stateDuration { f.enter(.idle) }

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
            }
            if !f.spec.boss, f.stateFrame >= a.chainFrom, f.attackBuffer > 0, i + 1 < f.spec.attacks.count, f.onGround {
                startAttack(&f, i + 1, inp, &events)
            } else if f.stateFrame >= a.windup + a.active, canDodge(f) {
                startDodge(&f, inp, &events)
            } else if f.stateFrame >= a.total {
                f.enter(f.onGround ? .idle : .air)
            }

        case .idle, .run, .air:
            if abs(inp.moveX) > 0.01 { f.facing = inp.moveX > 0 ? 1 : -1 }
            let target = inp.moveX * f.spec.runSpeed * (f.onGround ? 1 : tuning.airControl)
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
            if canDodge(f) {
                startDodge(&f, inp, &events)
            } else if f.attackBuffer > 0, !f.spec.attacks.isEmpty {
                startAttack(&f, f.spec.boss ? min(f.nextAttack, f.spec.attacks.count - 1) : 0, inp, &events)
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
        return explodes
    }

    private func canDodge(_ f: Fighter) -> Bool {
        f.dodgeBuffer > 0 && f.spec.dodge != nil && f.dodgeCooldown == 0 && f.onGround
    }

    private func startAttack(_ f: inout Fighter, _ index: Int, _ inp: InputFrame, _ events: inout [GameEvent]) {
        if abs(inp.moveX) > 0.01 { f.facing = inp.moveX > 0 ? 1 : -1 }
        f.attackBuffer = 0
        f.hitIDs = []
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
        if f.state == .dodge {
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
            && fighters[i].isAlive && fighters[i].awake {
            var f = fighters[i]
            let apart = abs(f.pos.y - lead.pos.y) > tuning.partnerStrandedHeight && f.onGround
            f.strandedFrames = apart ? f.strandedFrames + 1 : 0
            let lost = abs(f.pos.x - lead.pos.x) > tuning.partnerRegroupDistance
                || f.strandedFrames >= tuning.partnerStrandedFrames || f.pos.y < (level?.killY ?? -.infinity) + 40
            if lost {
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

    private func hasGround(atX x: Double, y: Double) -> Bool {
        platformBoxes.contains { $0.minX <= x && x <= $0.maxX && $0.maxY <= y + 1 && $0.maxY >= y - 8 }
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

        if target.isParrying, attacker.team == .enemy {
            fighters[a].enter(.staggered, duration: tuning.parryStagger)
            fighters[a].vel.x = -attacker.facing * 120
            hitStop = max(hitStop, tuning.parryHitStop)
            events.append(.parried(by: target.id, attacker: attacker.id, at: contact))
            return
        }

        let fromFront = (attacker.pos.x - target.pos.x) * target.facing >= 0
        if !target.isOpen || (target.isGuarding && fromFront) {
            events.append(.blocked(attacker: attacker.id, target: target.id, at: contact))
            return
        }

        let push: Double = attacker.pos.x == target.pos.x ? attacker.facing : (target.pos.x > attacker.pos.x ? 1 : -1)
        let ai = attacker.team == .hero && attacker.id != controlledID
        hurt(t, damage: attack.damage * (ai ? tuning.partnerDamageScale : 1), by: attacker.id, at: contact, push: push * attack.knockback,
             hitstun: attack.hitstun, &events)
        hitStop = max(hitStop, target.team == .hero ? tuning.heroHurtHitStop : attack.hitStop)
    }

    private mutating func hurt(
        _ t: Int, damage base: Double, by attackerID: Int, at contact: Vec2, push: Double, hitstun: Int,
        _ events: inout [GameEvent]
    ) {
        var f = fighters[t]
        let damage = base * (f.state == .staggered ? tuning.staggerDamageBonus : 1)
        f.hp = f.spec.immortal ? max(1, f.hp - damage) : f.hp - damage
        f.sinceHit = 0
        events.append(.hit(attacker: attackerID, target: f.id, damage: damage, at: contact))

        if f.hp <= 0 {
            f.hp = 0
            f.vel.x = push
            f.enter(.dead)
            events.append(.died(id: f.id))
            if f.spec.boss { events.append(.bossDefeated(id: f.id)) }
        } else {
            if let sd = f.spec.selfDestruct, f.state != .fuse, f.hp <= f.spec.maxHP * sd.threshold {
                f.enter(.fuse)
                events.append(.fuseLit(id: f.id))
            } else if f.state == .fuse || f.state == .staggered || f.spec.rooted || f.spec.armored {
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

        for i in fighters.indices where fighters[i].pos.y < level.killY {
            var f = fighters[i]
            defer { fighters[i] = f }
            f.vel = .zero
            f.pos.y = level.killY
            guard f.isAlive else { continue }
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
            for i in fighters.indices where fighters[i].team == .hero && fighters[i].isAlive && fighters[i].awake {
                let f = fighters[i]
                guard f.invulnerable == 0, !f.isDodgeInvulnerable, hazard.box.intersects(f.hurtbox) else { continue }
                let push: Double = f.pos.x >= hazard.box.center.x ? 1 : -1
                hurt(i, damage: hazard.damage, by: -1, at: f.hurtbox.center, push: push * 260, hitstun: 16, &events)
                hitStop = max(hitStop, tuning.heroHurtHitStop)
            }
        }

        for i in fighters.indices where fighters[i].team == .hero && fighters[i].isAlive {
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
        if let bossID, let b = index(of: bossID), !fighters[b].isAlive {
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
