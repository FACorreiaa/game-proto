import LastLightCore

/// Decides what a fighter wants to do this frame. Enemies use it now; the AI partner will use the same
/// interface, so handing control to the player is only a matter of whose input a fighter reads.
public protocol Brain: Sendable {
    func think(me: inout Fighter, foes: [Fighter], tuning: Tuning, rng: inout SeededRandom) -> InputFrame
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

    public func think(me: inout Fighter, foes: [Fighter], tuning: Tuning, rng: inout SeededRandom) -> InputFrame {
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

    public func think(me: inout Fighter, foes: [Fighter], tuning: Tuning, rng: inout SeededRandom) -> InputFrame {
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
