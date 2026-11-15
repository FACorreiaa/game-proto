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
            guard let attack = foe.currentAttack, foe.attackPhase == .windup,
                  attack.windup - foe.stateFrame <= 6,
                  abs(dx) < me.spec.width / 2 + foe.spec.width / 2 + attack.reach + 50 else { continue }
            threatened = true
            // Decide once per incoming attack whether it sees this one coming.
            if me.aiAux != foe.id {
                me.aiAux = foe.id
                if Double.random(in: 0..<1, using: &rng) < tuning.partnerDodgeChance {
                    // Against a shield it dodges through, to come out behind it.
                    return InputFrame(moveX: foe.spec.frontalBlock ? -away : away, dodge: true)
                }
            }
        }
        if !threatened { me.aiAux = 0 }

        // Fight what is near the leader, or near itself when it is alone.
        let anchor = leader ?? me
        let target = foes
            .filter { abs($0.pos.x - anchor.pos.x) <= tuning.partnerEngageRange }
            .min { abs($0.pos.x - me.pos.x) < abs($1.pos.x - me.pos.x) }
        if let target {
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
