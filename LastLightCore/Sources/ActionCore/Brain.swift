import LastLightCore

/// Decides what a fighter wants to do this frame. Enemies use it now; the AI partner will use the same
/// interface, so handing control to the player is only a matter of whose input a fighter reads.
public protocol Brain: Sendable {
    func think(
        me: inout Fighter, foes: [Fighter], allies: [Fighter], tuning: Tuning, rng: inout SeededRandom
    ) -> InputFrame
}

/// A tiny stick push: enough to turn and face a target without really moving.
private let facingNudge = 0.02

private func nearest(_ foes: [Fighter], to me: Fighter) -> Fighter? {
    // A decoy in sight is too tempting to ignore.
    let decoy = foes.filter { $0.spec.isDecoy && abs($0.pos.x - me.pos.x) <= decoyLure }
        .min { abs($0.pos.x - me.pos.x) < abs($1.pos.x - me.pos.x) }
    return decoy ?? foes.min { abs($0.pos.x - me.pos.x) < abs($1.pos.x - me.pos.x) }
}

/// How far away a decoy still draws an enemy.
let decoyLure = 600.0

private func strikeDistance(_ me: Fighter, _ target: Fighter) -> Double {
    guard let attack = me.spec.attacks.first else { return 0 }
    return me.spec.width / 2 + attack.reach + target.spec.width / 2 - 6
}

/// Scrap Drone: rushes in, bites, and chases the hero once its fuse is lit.
public struct DroneBrain: Brain {
    public init() {}

    public func think(
        me: inout Fighter, foes: [Fighter], allies: [Fighter], tuning: Tuning, rng: inout SeededRandom
    ) -> InputFrame {
        guard let target = nearest(foes, to: me) else { return .neutral }
        let dx = target.pos.x - me.pos.x
        let dir: Double = dx >= 0 ? 1 : -1
        if me.aiCooldown > 0 { me.aiCooldown -= 1 }
        if me.state == .fuse { return InputFrame(moveX: dir) }

        // The bite lunges forward, so it can start from further out than its reach.
        let range = strikeDistance(me, target) + 40
        if abs(dx) > range { return InputFrame(moveX: dir) }
        if me.aiCooldown == 0, me.isActionable {
            me.aiCooldown = Int.random(in: tuning.droneAttackGap, using: &rng)
            return InputFrame(moveX: dir * facingNudge, attack: true)
        }
        return InputFrame(moveX: dir * facingNudge)
    }
}

/// Forged Soldier: walks the hero down behind its shield and is slow to turn around.
public struct SoldierBrain: Brain {
    public init() {}

    public func think(
        me: inout Fighter, foes: [Fighter], allies: [Fighter], tuning: Tuning, rng: inout SeededRandom
    ) -> InputFrame {
        guard let target = nearest(foes, to: me) else { return .neutral }
        let dx = target.pos.x - me.pos.x
        let dir: Double = dx >= 0 ? 1 : -1
        if me.aiCooldown > 0 { me.aiCooldown -= 1 }

        if dir != me.facing, me.isActionable {
            me.aiAux += 1
            if me.aiAux < tuning.soldierTurnDelay { return .neutral }
        }
        me.aiAux = 0

        if abs(dx) > strikeDistance(me, target) { return InputFrame(moveX: dir) }
        if me.aiCooldown == 0, me.isActionable {
            me.aiCooldown = Int.random(in: tuning.soldierAttackGap, using: &rng)
            return InputFrame(moveX: dir * facingNudge, attack: true)
        }
        return InputFrame(moveX: dir * facingNudge)
    }
}

/// Sentry Core: holds its distance, turns to face its target, and fires when the target is level with it.
public struct SentryBrain: Brain {
    public init() {}

    public func think(
        me: inout Fighter, foes: [Fighter], allies: [Fighter], tuning: Tuning, rng: inout SeededRandom
    ) -> InputFrame {
        guard let target = nearest(foes, to: me) else { return .neutral }
        if me.aiCooldown > 0 { me.aiCooldown -= 1 }
        let dx = target.pos.x - me.pos.x
        let dir: Double = dx >= 0 ? 1 : -1
        if abs(dx) < tuning.sentryNear { return InputFrame(moveX: -dir) }
        if abs(dx) > tuning.sentryFar { return InputFrame(moveX: dir) }
        if me.aiCooldown == 0, me.isActionable {
            me.aiCooldown = Int.random(in: tuning.sentryAttackGap, using: &rng)
            return InputFrame(moveX: dir * facingNudge, attack: true)
        }
        return InputFrame(moveX: dir * facingNudge)
    }
}

/// Dogma Frame: walks beside the nearest other machine so its shield covers it. It never attacks.
public struct DogmaBrain: Brain {
    public init() {}

    public func think(
        me: inout Fighter, foes: [Fighter], allies: [Fighter], tuning: Tuning, rng: inout SeededRandom
    ) -> InputFrame {
        let others = allies.filter { $0.id != me.id && !$0.spec.immortal && $0.spec.wardRadius == 0 }
        guard let ward = nearest(others, to: me) else { return .neutral }
        let dx = ward.pos.x - me.pos.x
        if abs(dx) <= tuning.dogmaFollowDistance { return .neutral }
        return InputFrame(moveX: dx > 0 ? 1 : -1)
    }
}

/// Ratborn: rushes in, bites, then backs off for a moment, and now and then breaks off its approach.
public struct RatbornBrain: Brain {
    public init() {}

    public func think(
        me: inout Fighter, foes: [Fighter], allies: [Fighter], tuning: Tuning, rng: inout SeededRandom
    ) -> InputFrame {
        guard let target = nearest(foes, to: me) else { return .neutral }
        let dx = target.pos.x - me.pos.x
        let dir: Double = dx >= 0 ? 1 : -1
        if me.aiCooldown > 0 { me.aiCooldown -= 1 }
        // Backing off, after a bite or a feint.
        if me.aiAux > 0 {
            me.aiAux -= 1
            return InputFrame(moveX: -dir)
        }
        let range = strikeDistance(me, target) + 40
        if abs(dx) > range {
            if Double.random(in: 0..<1, using: &rng) < tuning.ratbornFeintChance {
                me.aiAux = 20
                return InputFrame(moveX: -dir, jump: true)
            }
            return InputFrame(moveX: dir)
        }
        if me.aiCooldown == 0, me.isActionable {
            me.aiCooldown = Int.random(in: tuning.ratbornAttackGap, using: &rng)
            // Starts backing off once the bite is over.
            me.aiAux2 = 1
            return InputFrame(moveX: dir * facingNudge, attack: true)
        }
        if me.aiAux2 == 1, me.isActionable {
            me.aiAux2 = 0
            me.aiAux = Int.random(in: tuning.ratbornRetreat, using: &rng)
        }
        return InputFrame(moveX: dir * facingNudge)
    }
}

/// Lantern Gunner: holds a throwing distance and lobs lanterns at the hero.
public struct GunnerBrain: Brain {
    public init() {}

    public func think(
        me: inout Fighter, foes: [Fighter], allies: [Fighter], tuning: Tuning, rng: inout SeededRandom
    ) -> InputFrame {
        guard let target = nearest(foes, to: me) else { return .neutral }
        if me.aiCooldown > 0 { me.aiCooldown -= 1 }
        let dx = target.pos.x - me.pos.x
        let dir: Double = dx >= 0 ? 1 : -1
        if abs(dx) < tuning.gunnerNear { return InputFrame(moveX: -dir) }
        if abs(dx) > tuning.gunnerFar { return InputFrame(moveX: dir) }
        if me.aiCooldown == 0, me.isActionable {
            me.aiCooldown = Int.random(in: tuning.gunnerAttackGap, using: &rng)
            return InputFrame(moveX: dir * facingNudge, attack: true)
        }
        return InputFrame(moveX: dir * facingNudge)
    }
}

/// Smuggler Brute: lumbers in, slow to turn. Up close it often slams, which reaches behind it too.
public struct BruteBrain: Brain {
    public init() {}

    public func think(
        me: inout Fighter, foes: [Fighter], allies: [Fighter], tuning: Tuning, rng: inout SeededRandom
    ) -> InputFrame {
        guard let target = nearest(foes, to: me) else { return .neutral }
        let dx = target.pos.x - me.pos.x
        let dir: Double = dx >= 0 ? 1 : -1
        if me.aiCooldown > 0 { me.aiCooldown -= 1 }
        // Anyone behind it is close enough to slam without turning.
        let behind = dir != me.facing && abs(dx) < me.spec.width / 2 + me.spec.attacks[1].reach
        if dir != me.facing, me.isActionable, !behind {
            me.aiAux += 1
            if me.aiAux < tuning.bruteTurnDelay { return .neutral }
        }
        me.aiAux = 0
        if !behind, abs(dx) > strikeDistance(me, target) { return InputFrame(moveX: dir) }
        if me.aiCooldown == 0, me.isActionable {
            me.aiCooldown = Int.random(in: tuning.bruteAttackGap, using: &rng)
            me.nextAttack = behind || Double.random(in: 0..<1, using: &rng) < tuning.bruteSlamChance ? 1 : 0
            return InputFrame(moveX: behind ? 0 : dir * facingNudge, attack: true)
        }
        return InputFrame(moveX: behind ? 0 : dir * facingNudge)
    }
}

/// Night Weaver: keeps away, sends images when it has none, and otherwise lays snares in the hero's path.
public struct WeaverBrain: Brain {
    public init() {}

    public func think(
        me: inout Fighter, foes: [Fighter], allies: [Fighter], tuning: Tuning, rng: inout SeededRandom
    ) -> InputFrame {
        guard let target = nearest(foes, to: me) else { return .neutral }
        if me.aiCooldown > 0 { me.aiCooldown -= 1 }
        let dx = target.pos.x - me.pos.x
        let dir: Double = dx >= 0 ? 1 : -1
        if abs(dx) < tuning.weaverNear { return InputFrame(moveX: -dir) }
        if abs(dx) > tuning.weaverFar { return InputFrame(moveX: dir) }
        if me.aiCooldown == 0, me.isActionable {
            me.aiCooldown = Int.random(in: tuning.weaverAttackGap, using: &rng)
            let images = allies.filter { $0.kind == .weaverImage && $0.isAlive }.count
            me.nextAttack = images == 0 ? 0 : 1
            return InputFrame(moveX: dir * facingNudge, attack: true)
        }
        return InputFrame(moveX: dir * facingNudge)
    }
}

/// The Cinder King, in three phases.
/// Offer: walks the hero down; cane up close, lanterns from further off.
/// Debt: calls Ratborn whenever none are left, who shield him; between calls, fire from the floor and lanterns.
/// Price: no more debtors. Faster, a sweep on both sides up close, wide eruptions from afar.
public struct CinderKingBrain: Brain {
    public init() {}

    static let cane = 0, lantern = 1, debtors = 2, vents = 3, sweep = 4, wideVents = 5

    public func think(
        me: inout Fighter, foes: [Fighter], allies: [Fighter], tuning: Tuning, rng: inout SeededRandom
    ) -> InputFrame {
        guard let target = nearest(foes, to: me) else { return .neutral }
        if me.aiCooldown > 0 { me.aiCooldown -= 1 }
        guard me.isActionable else { return .neutral }
        let dx = target.pos.x - me.pos.x
        let dir: Double = dx >= 0 ? 1 : -1
        if dir != me.facing {
            me.aiAux += 1
            if me.aiAux < tuning.cinderTurnDelay { return .neutral }
        }
        me.aiAux = 0

        let gap = abs(dx) - me.spec.width / 2 - target.spec.width / 2
        let close = gap < me.spec.attacks[Self.cane].reach - 10
        let debtorsLeft = allies.contains { $0.kind == .ratborn && $0.isAlive }
        // While his debtors fight he keeps back and lets them.
        let approach: Double = me.phase == 2 && debtorsLeft ? (gap < 220 ? -dir : 0) : (gap > 40 ? dir : dir * 0.02)
        guard me.aiCooldown == 0 else { return InputFrame(moveX: approach) }

        let wait = Double(Int.random(in: tuning.cinderAttackGap, using: &rng))
        me.aiCooldown = Int(wait * (me.phase >= 3 ? tuning.cinderPriceGapScale : 1))
        let roll = Double.random(in: 0..<1, using: &rng)
        switch me.phase {
        case 1:
            me.nextAttack = close && roll < tuning.cinderCloseChance ? Self.cane : Self.lantern
        case 2:
            if !debtorsLeft {
                me.nextAttack = Self.debtors
            } else {
                me.nextAttack = close ? Self.cane : (roll < 0.5 ? Self.vents : Self.lantern)
            }
        default:
            if close {
                me.nextAttack = roll < tuning.cinderCloseChance ? Self.sweep : Self.cane
            } else {
                me.nextAttack = roll < 0.5 ? Self.wideVents : Self.lantern
            }
        }
        return InputFrame(moveX: dir * facingNudge, attack: true)
    }
}

/// The Protocol, in three phases.
/// Judgement: turns slowly, walks the hero down, and picks one of three attacks, each with a long warning.
/// Ascension: takes to the air, summons drones and calls down light, then crashes down open; and again.
/// Execution: back on the ground for good, faster, with a pulse on both sides and a beam across the room.
public struct ProtocolBrain: Brain {
    public init() {}

    static let slam = 0, charge = 1, surge = 2, summon = 3, rain = 4, pulse = 5, beam = 6

    public func think(
        me: inout Fighter, foes: [Fighter], allies: [Fighter], tuning: Tuning, rng: inout SeededRandom
    ) -> InputFrame {
        guard let target = nearest(foes, to: me) else { return .neutral }
        if me.aiCooldown > 0 { me.aiCooldown -= 1 }
        guard me.isActionable, !me.descending else { return .neutral }
        if me.flying { return fly(&me, target: target, allies: allies, tuning: tuning, rng: &rng) }

        let dx = target.pos.x - me.pos.x
        let dir: Double = dx >= 0 ? 1 : -1
        if dir != me.facing {
            me.aiAux += 1
            if me.aiAux < tuning.protocolTurnDelay { return .neutral }
        }
        me.aiAux = 0

        let gap = abs(dx) - me.spec.width / 2 - target.spec.width / 2
        guard me.aiCooldown == 0 else { return InputFrame(moveX: gap > 50 ? dir : dir * facingNudge) }

        if me.phase == 2, me.aiAux2 >= tuning.protocolGroundActions {
            me.aiAux2 = 0
            me.flying = true
            me.aiCooldown = tuning.protocolTakeoffPause
            return .neutral
        }
        let wait = Double(Int.random(in: tuning.protocolAttackGap, using: &rng))
        me.aiCooldown = Int(wait * (me.phase >= 3 ? tuning.protocolExecutionGapScale : 1))
        me.aiAux2 += 1
        let close = gap < me.spec.attacks[Self.slam].reach - 15
        if me.phase >= 3 {
            let choices = close ? [Self.slam, Self.slam, Self.pulse] : [Self.charge, Self.surge, Self.pulse, Self.beam]
            me.nextAttack = choices[Int.random(in: 0..<choices.count, using: &rng)]
        } else if close, Double.random(in: 0..<1, using: &rng) < tuning.protocolSlamChance {
            // Up close it mostly slams, but not always, so standing at its feet is never one pattern.
            me.nextAttack = Self.slam
        } else {
            me.nextAttack = Bool.random(using: &rng) ? Self.charge : Self.surge
        }
        return InputFrame(moveX: dir * facingNudge, attack: true)
    }

    /// In the air it drifts over the hero, and after a few attacks drops back down.
    private func fly(
        _ me: inout Fighter, target: Fighter, allies: [Fighter], tuning: Tuning, rng: inout SeededRandom
    ) -> InputFrame {
        let move = max(-1, min(1, (target.pos.x - me.pos.x) / 120))
        guard me.aiCooldown == 0, abs(me.pos.y - tuning.protocolFlightHeight) < 20 else { return InputFrame(moveX: move) }
        if me.aiAux2 >= tuning.protocolAirActions {
            me.aiAux2 = 0
            me.flying = false
            me.descending = true
            return .neutral
        }
        me.aiAux2 += 1
        me.aiCooldown = Int.random(in: tuning.protocolAirGap, using: &rng)
        let minions = allies.filter { $0.id != me.id && !$0.spec.immortal }.count
        me.nextAttack = minions < tuning.protocolMaxMinions && Bool.random(using: &rng) ? Self.summon : Self.rain
        return InputFrame(moveX: move * facingNudge, attack: true)
    }
}

/// The hero the player is not controlling: stays near the leader, fights what is near the leader,
/// and gets out of the way of attacks it can see coming, most of the time.
public struct PartnerBrain: Brain {
    public init() {}

    public func think(
        me: inout Fighter, foes: [Fighter], allies: [Fighter], tuning: Tuning, rng: inout SeededRandom
    ) -> InputFrame {
        if me.aiCooldown > 0 { me.aiCooldown -= 1 }
        let leader = allies.first { $0.id != me.id }

        // Threats first.
        var threatened = false
        for foe in foes {
            let dx = foe.pos.x - me.pos.x
            let away: Double = dx >= 0 ? -1 : 1
            if foe.state == .fuse, abs(dx) < 170 { return InputFrame(moveX: away) }
            guard let attack = foe.currentAttack, foe.attackPhase == .windup, attack.effect == .strike,
                  attack.windup - foe.stateFrame <= 6,
                  abs(dx) < me.spec.width / 2 + foe.spec.width / 2 + attack.reach + 50
                      + (attack.holdsStill ? attack.lunge * Double(attack.active) / 60 : 0) else { continue }
            threatened = true
            // Decide once per incoming attack whether it sees this one coming.
            if me.aiAux != foe.id {
                me.aiAux = foe.id
                if case .adapt? = me.spec.special, me.specialCooldown == 0, me.isActionable,
                   Double.random(in: 0..<1, using: &rng) < tuning.partnerGuardChance {
                    return InputFrame(moveX: -away * facingNudge, special: true)
                }
                if Double.random(in: 0..<1, using: &rng) < tuning.partnerDodgeChance {
                    // Against a shield it dodges through, to come out behind it.
                    return InputFrame(moveX: foe.spec.frontalBlock ? -away : away, dodge: true)
                }
            }
        }
        if !threatened { me.aiAux = 0 }

        // Under AI, Seraphine heals when either of them is badly hurt.
        if case .heal(_, let range, _)? = me.spec.special, me.specialCooldown == 0, me.isActionable {
            let hurt = ([me] + allies.filter { $0.id != me.id && abs($0.pos.x - me.pos.x) <= range })
                .contains { $0.hp < $0.spec.maxHP * 0.5 }
            if hurt { return InputFrame(special: true) }
        }
        // Under AI, Nimue leaves a decoy when she is crowded.
        if case .decoy? = me.spec.special, me.specialCooldown == 0, me.isActionable,
           foes.filter({ !$0.spec.isDecoy && abs($0.pos.x - me.pos.x) < 160 }).count >= 2 {
            return InputFrame(special: true)
        }

        // Fight what is near the leader, or near itself when it is alone.
        let anchor = leader ?? me
        let inReach = foes.filter { abs($0.pos.x - anchor.pos.x) <= tuning.partnerEngageRange }
        // The leader's mark comes before whatever happens to be nearest.
        let target = inReach.first { $0.markedFrames > 0 }
            ?? inReach.first { $0.spec.wardRadius > 0 }
            ?? { () -> Fighter? in
                // Something it can reach before something flying overhead.
                let grounded = inReach.filter { !$0.flying }
                return (grounded.isEmpty ? inReach : grounded).min { abs($0.pos.x - me.pos.x) < abs($1.pos.x - me.pos.x) }
            }()
        if let target {
            // Under AI, Caelen marks a tough enemy when nothing is marked yet.
            if case .command(let range, _, _, _)? = me.spec.special, me.specialCooldown == 0, me.isActionable,
               !foes.contains(where: { $0.markedFrames > 0 }), target.hp >= 60,
               abs(target.pos.x - me.pos.x) <= range {
                let toward: Double = target.pos.x >= me.pos.x ? 1 : -1
                return InputFrame(moveX: toward * facingNudge, special: true)
            }
            let dx = target.pos.x - me.pos.x
            let dir: Double = dx >= 0 ? 1 : -1
            // Hitting a raised shield does nothing, so it stands just out of reach and waits for an opening.
            let shielded = target.isGuarding && (me.pos.x - target.pos.x) * target.facing >= 0
            if shielded, let swing = target.spec.attacks.first {
                let standoff = target.spec.width / 2 + swing.reach + me.spec.width / 2 + 24
                if abs(dx) < standoff { return InputFrame(moveX: -dir) }
                if abs(dx) > standoff + 30 { return InputFrame(moveX: dir) }
                return InputFrame(moveX: dir * facingNudge)
            }
            if abs(dx) > strikeDistance(me, target) { return InputFrame(moveX: dir) }
            if me.aiCooldown == 0 {
                me.aiCooldown = Int.random(in: tuning.partnerAttackGap, using: &rng)
                return InputFrame(moveX: dir * facingNudge, attack: true)
            }
            return InputFrame(moveX: dir * facingNudge)
        }

        // Nothing to fight: fall in behind the leader.
        guard let leader else { return .neutral }
        let dx = leader.pos.x - leader.facing * tuning.partnerFollowDistance - me.pos.x
        if abs(dx) < 30 { return .neutral }
        return InputFrame(moveX: max(-1, min(1, dx / 60)))
    }
}
