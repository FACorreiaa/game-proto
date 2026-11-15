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

    var waves: [[Spawn]] = []
    var waveLive = false
    var waveDelay = 0
    var rng: SeededRandom
    var nextID = 1

    public init(tuning: Tuning = Tuning(), seed: UInt64, arena: ClosedRange<Double> = 0...1400) {
        self.tuning = tuning
        self.arena = arena
        self.rng = SeededRandom(seed: seed)
    }

    public var controlled: Fighter? { fighter(controlledID) }

    public func fighter(_ id: Int) -> Fighter? {
        fighters.first { $0.id == id }
    }

    // MARK: Setup

    @discardableResult
    public mutating func spawn(_ kind: FighterKind, x: Double, facing: Double? = nil, spec: FighterSpec? = nil) -> Int {
        let id = nextID
        nextID += 1
        let team: Team = kind == .caelen ? .hero : .enemy
        let mid = (arena.lowerBound + arena.upperBound) / 2
        fighters.append(Fighter(
            id: id, kind: kind, team: team, spec: spec ?? tuning.spec(for: kind),
            pos: Vec2(x, 0), facing: facing ?? (x <= mid ? 1 : -1)))
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
        let snapshot = fighters
        for i in fighters.indices {
            var f = fighters[i]
            var inp = InputFrame.neutral
            if f.id == controlledID {
                inp = input
            } else if f.isAlive, let brain = f.spec.brain {
                let foes = snapshot.filter { $0.team != f.team && $0.isAlive && !$0.spec.immortal }
                inp = brain.think(me: &f, foes: foes, tuning: tuning, rng: &rng)
                latch(&f, inp)
            }
            if update(&f, inp, &events) { explosions.append(f.id) }
            integrate(&f, inp, &events)
            fighters[i] = f
        }

        resolveHits(&events)
        for id in explosions { explode(id, &events) }
        housekeeping(&events)
        frame += 1
        return events
    }

    private func index(of id: Int) -> Int? {
        fighters.firstIndex { $0.id == id }
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
                f.vel.x = f.stateFrame < a.windup + a.active ? f.facing * a.lunge : 0
            }
            if f.stateFrame >= a.chainFrom, f.attackBuffer > 0, i + 1 < f.spec.attacks.count, f.onGround {
                startAttack(&f, i + 1, inp, &events)
            } else if f.stateFrame >= a.windup + a.active, canDodge(f) {
                startDodge(&f, inp, &events)
            } else if f.stateFrame >= a.total {
                f.enter(f.onGround ? .idle : .air)
            }

        case .idle, .run, .air:
            if abs(inp.moveX) > 0.01 { f.facing = inp.moveX > 0 ? 1 : -1 }
            f.vel.x = inp.moveX * f.spec.runSpeed * (f.onGround ? 1 : tuning.airControl)
            if canDodge(f) {
                startDodge(&f, inp, &events)
            } else if f.attackBuffer > 0, !f.spec.attacks.isEmpty {
                startAttack(&f, 0, inp, &events)
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
        if f.state == .dodge {
            f.vel.y = 0
        } else if !f.onGround {
            let cut = f.vel.y > 0 && f.id == controlledID && !inp.jumpHeld
            f.vel.y -= tuning.gravity * (cut ? tuning.jumpCutGravity : 1) * dt
        }
        f.pos.x += f.vel.x * dt
        f.pos.y += f.vel.y * dt

        if f.pos.y <= 0 {
            f.pos.y = 0
            if !f.onGround {
                f.onGround = true
                events.append(.landed(id: f.id))
            }
            if f.vel.y < 0 { f.vel.y = 0 }
        } else {
            f.onGround = false
        }
        if f.onGround {
            f.coyote = tuning.coyoteFrames
        } else if f.coyote > 0 {
            f.coyote -= 1
        }

        let half = f.spec.width / 2
        f.pos.x = min(max(f.pos.x, arena.lowerBound + half), arena.upperBound - half)
    }

    // MARK: Hits

    private mutating func resolveHits(_ events: inout [GameEvent]) {
        for a in fighters.indices {
            guard let box = fighters[a].hitbox, let attack = fighters[a].currentAttack else { continue }
            for t in fighters.indices where t != a {
                guard fighters[t].team != fighters[a].team, fighters[t].isAlive,
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
        if target.isGuarding, fromFront {
            events.append(.blocked(attacker: attacker.id, target: target.id, at: contact))
            return
        }

        let push: Double = attacker.pos.x == target.pos.x ? attacker.facing : (target.pos.x > attacker.pos.x ? 1 : -1)
        hurt(t, damage: attack.damage, by: attacker.id, at: contact, push: push * attack.knockback,
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
        } else {
            if let sd = f.spec.selfDestruct, f.state != .fuse, f.hp <= f.spec.maxHP * sd.threshold {
                f.enter(.fuse)
                events.append(.fuseLit(id: f.id))
            } else if f.state == .fuse || f.state == .staggered || f.spec.rooted {
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

    // MARK: Waves and endings

    private mutating func housekeeping(_ events: inout [GameEvent]) {
        let corpseFrames = tuning.corpseFrames
        fighters.removeAll { $0.team == .enemy && $0.state == .dead && $0.stateFrame >= corpseFrames }
        for i in fighters.indices where fighters[i].spec.immortal && fighters[i].sinceHit > tuning.dummyRegenFrames {
            fighters[i].hp = fighters[i].spec.maxHP
        }

        if let hero = controlled, !hero.isAlive {
            isOver = true
            events.append(.heroDown)
            return
        }

        guard !waves.isEmpty else { return }
        let remaining = fighters.contains { $0.team == .enemy && $0.isAlive && !$0.spec.immortal }
        if waveLive, !remaining {
            waveLive = false
            waveDelay = tuning.waveDelay
            events.append(.waveCleared(number: waveNumber))
            for i in fighters.indices where fighters[i].team == .hero && fighters[i].isAlive {
                fighters[i].hp = min(fighters[i].spec.maxHP, fighters[i].hp + tuning.waveClearHeal)
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
}
