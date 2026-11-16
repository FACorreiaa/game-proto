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
    foes.min { abs($0.pos.x - me.pos.x) < abs($1.pos.x - me.pos.x) }
}

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
