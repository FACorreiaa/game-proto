/// Plays a level by reading its geometry: runs right, jumps the walls and gaps it can clear, and waits
/// for platforms and for hazards to switch off. It is how a level is proven finishable in tests, and how
/// the app is watched without hands. With `fights` on it also swings at whatever stands in its way.
public struct Autopilot: Sendable {
    public var fights: Bool
    private var jumpHeld = 0

    public init(fights: Bool = false) {
        self.fights = fights
    }

    public mutating func input(for world: World) -> InputFrame {
        guard let me = world.controlled, let level = world.level else { return .neutral }
        let half = me.spec.width / 2
        var inp = InputFrame(moveX: 1, jumpHeld: jumpHeld > 0)
        if jumpHeld > 0 { jumpHeld -= 1 }

        if let special = kitSpecial(me, world: world) { return special }
        if let boss = world.boss {
            // A sworn pair has to fall together: wear down whichever has more left, so neither lies down long alone.
            let pair = [boss, world.twin].compactMap { $0 }.filter(\.isAlive)
            let share = { (f: Fighter) in f.hp / f.spec.maxHP }
            let target = pair.max { a, b in
                abs(share(a) - share(b)) < 0.08
                    ? abs(a.pos.x - me.pos.x) > abs(b.pos.x - me.pos.x)
                    : share(a) < share(b)
            }
            return target.map { bossInput(me, $0, world: world) } ?? .neutral
        }

        // A long attack about to land from further away, such as a Sentry Core's beam: dodge it.
        let beam = world.fighters.contains { foe in
            guard foe.team == .enemy, foe.isAlive, foe.awake, let attack = foe.currentAttack, attack.reach > 150,
                  foe.attackPhase == .windup, attack.windup - foe.stateFrame <= 4 else { return false }
            let ahead = (me.pos.x - foe.pos.x) * foe.facing
            return ahead >= 0 && ahead <= foe.spec.width / 2 + attack.reach + half
                && me.pos.y < foe.pos.y + attack.yOffset + attack.height && me.pos.y + me.spec.height > foe.pos.y + attack.yOffset
        }
        if beam, me.onGround { return InputFrame(moveX: 1, dodge: true) }

        if fights {
            let nearby = world.fighters
                .filter { $0.team == .enemy && $0.isAlive && !$0.spec.immortal && abs($0.pos.y - me.pos.y) < 70 }
            // A shielded machine cannot be hurt: go for the Dogma Frame that shields it.
            let foe = nearby.filter { !world.isWarded($0.id) }
                .min { abs($0.pos.x - me.pos.x) < abs($1.pos.x - me.pos.x) }
            if let foe, abs(foe.pos.x - me.pos.x) < 96 {
                let dir: Double = foe.pos.x >= me.pos.x ? 1 : -1
                if foe.state == .fuse { return InputFrame(moveX: -dir) }
                // Dodges through a shield to get behind it, and through a swing it sees coming.
                let swingComing = foe.attackPhase == .windup
                    && (foe.currentAttack.map { $0.windup - foe.stateFrame <= 5 } ?? false)
                let shielded = foe.isGuarding && (me.pos.x - foe.pos.x) * foe.facing >= 0
                if swingComing || (shielded && world.frame % 40 == 0) { return InputFrame(moveX: dir, dodge: true) }
                return InputFrame(moveX: dir * 0.02, attack: world.frame % 8 == 0)
            }
        }
        guard me.onGround else { return inp }
        if let step = puzzleInput(me, world: world, level: level) { return step }

        // A hazard just ahead that is on, or will be before the hero is through.
        let waitForHazard = level.hazards.contains { h in
            let ahead = h.box.minX - (me.pos.x + half)
            guard ahead > -(h.box.maxX - h.box.minX) - me.spec.width, ahead < 50 else { return false }
            return h.isOn(at: world.frame) || h.framesUntilOn(at: world.frame) < 45
        }
        if waitForHazard {
            inp.moveX = 0
            return inp
        }

        // A wall ahead: jump it if it is low enough, otherwise wait on the lift beside it.
        let solids = zip(world.platforms, world.platformBoxes)
        let wall = solids.first { p, b in
            !p.oneWay && b.minX >= me.pos.x && b.minX - (me.pos.x + half) < 34 && b.maxY > me.pos.y + 1
                && b.minY < me.pos.y + me.spec.height
        }
        if let wall {
            if wall.1.maxY - me.pos.y <= 105 {
                jump(&inp)
            } else if let lift = solids.first(where: { p, b in
                p.moves && p.travel.y != 0 && abs(b.maxX - wall.1.minX) < 80
            }) {
                let riding = me.groundIndex.map { world.platforms[$0].moves } ?? false
                let centre = (lift.1.minX + lift.1.maxX) / 2
                inp.moveX = riding ? 0 : max(-1, min(1, (centre - me.pos.x) / 20))
            }
            return inp
        }

        // An edge ahead: jump only when there is somewhere to land.
        func surface(from x0: Double, to x1: Double, above: Double, below: Double) -> Bool {
            world.platformBoxes.contains {
                $0.maxX > x0 && $0.minX < x1 && $0.maxY <= me.pos.y + above && $0.maxY >= me.pos.y - below
            }
        }
        let probe = me.pos.x + half + 26
        let footing = world.platformBoxes.contains { $0.minX <= probe && probe <= $0.maxX && abs($0.maxY - me.pos.y) < 2 }
        if !footing {
            if surface(from: me.pos.x + 70, to: me.pos.x + 165, above: 60, below: 200) {
                jump(&inp)
            } else if !surface(from: me.pos.x + half, to: me.pos.x + 60, above: 1, below: 400) {
                inp.moveX = 0
            }
        }
        return inp
    }

    /// Against a boss: keep out of falling light, dodge each attack just before it lands, deal with what it
    /// summons, and strike only while it is open.
    private func bossInput(_ me: Fighter, _ boss: Fighter, world: World) -> InputFrame {
        let half = me.spec.width / 2
        let dx = boss.pos.x - me.pos.x
        let dir: Double = dx >= 0 ? 1 : -1
        let gap = abs(dx) - boss.spec.width / 2 - me.spec.width / 2
        guard boss.awake else { return InputFrame(moveX: dir) }

        if let strike = world.strikes.first(where: { $0.box.minX - 30 < me.pos.x + half && me.pos.x - half < $0.box.maxX + 30 }) {
            var away: Double = me.pos.x >= strike.box.center.x ? 1 : -1
            let room = away > 0 ? world.arena.upperBound - me.pos.x : me.pos.x - world.arena.lowerBound
            if room < strike.box.width + 60 { away = -away }
            return InputFrame(moveX: away)
        }

        // Either of a pair may be about to swing.
        let swinging = [boss, world.twin].compactMap { $0 }.first { $0.isAlive && $0.attackPhase == .windup }
        if let swinging, swinging.id != boss.id, let attack = swinging.currentAttack, attack.effect == .strike {
            let sdx = swinging.pos.x - me.pos.x
            let inFront = attack.bothSides || (me.pos.x - swinging.pos.x) * swinging.facing >= 0
            let travel = attack.holdsStill ? attack.lunge * Double(attack.active) / 60 : 0
            let reach = swinging.spec.width / 2 + attack.reach + travel + half
            if inFront, abs(sdx) <= reach, attack.windup - swinging.stateFrame <= 4 {
                return InputFrame(moveX: sdx >= 0 ? 1 : -1, dodge: true)
            }
        }
        if let attack = boss.currentAttack, boss.attackPhase == .windup, attack.effect == .strike {
            let inFront = attack.bothSides || (me.pos.x - boss.pos.x) * boss.facing >= 0
            let travel = attack.holdsStill ? attack.lunge * Double(attack.active) / 60 : 0
            let reach = boss.spec.width / 2 + attack.reach + travel + half
            if inFront, abs(dx) <= reach, attack.windup - boss.stateFrame <= 4 { return InputFrame(moveX: dir, dodge: true) }
            return InputFrame(moveX: gap > 30 ? dir : dir * 0.02)
        }

        let minion = world.fighters
            .filter { $0.team == .enemy && $0.isAlive && !$0.spec.boss && abs($0.pos.y - me.pos.y) < 70 }
            .min { abs($0.pos.x - me.pos.x) < abs($1.pos.x - me.pos.x) }
        if let minion, abs(minion.pos.x - me.pos.x) < 110 {
            let toward: Double = minion.pos.x >= me.pos.x ? 1 : -1
            if minion.state == .fuse { return InputFrame(moveX: -toward) }
            let biteComing = minion.attackPhase == .windup
                && (minion.currentAttack.map { $0.windup - minion.stateFrame <= 5 } ?? false)
            if biteComing { return InputFrame(moveX: toward, dodge: true) }
            return InputFrame(moveX: toward * 0.02, attack: world.frame % 8 == 0)
        }

        // A boss that needs light: light the lamp nearest it, or wait by a lit one for it to come.
        if boss.spec.needsLight, world.isWarded(boss.id), let level = world.level,
           let lamp = level.levers.filter({ $0.glow > 0 })
            .min(by: { abs($0.pos.x - boss.pos.x) < abs($1.pos.x - boss.pos.x) }) {
            let ldx = lamp.pos.x - me.pos.x
            if abs(ldx) > 30 { return InputFrame(moveX: ldx > 0 ? 1 : -1) }
            let lit = world.signals.contains(lamp.id)
            return InputFrame(moveX: (lit ? dir : (ldx >= 0 ? 1 : -1)) * 0.02, attack: !lit && world.frame % 8 == 0)
        }

        // Up in the air it cannot be reached: wait near it, out of its way.
        if boss.flying || boss.descending {
            return InputFrame(moveX: abs(dx) > 170 ? dir : (abs(dx) < 110 ? -dir : 0))
        }
        if boss.isOpen {
            let reach = me.spec.attacks.first?.reach ?? 0
            if gap > reach - 12 { return InputFrame(moveX: dir) }
            return InputFrame(moveX: dir * 0.02, attack: world.frame % 8 == 0)
        }
        // Between attacks: mark it when Command is ready.
        if case .command(let range, _, _, _)? = me.spec.special, me.specialCooldown == 0, boss.markedFrames == 0,
           abs(dx) <= range {
            return InputFrame(moveX: dir * 0.02, special: true)
        }
        return InputFrame(moveX: gap > 45 ? dir : (gap < 25 ? -dir : dir * 0.02))
    }

    /// Puzzles: throw a lever on the way past when its gate lies ahead (a timed one only once the gate's other
    /// inputs are on, so the clock isn't wasted); have Orion hold a plate a gate ahead needs (take him there, then
    /// hand control back); and wait for an opening gate rather than jump at it.
    private func puzzleInput(_ me: Fighter, world: World, level: Level) -> InputFrame? {
        let ahead = level.gates.filter { $0.box.minX > me.pos.x - 10 && (world.gateOpen[$0.id] ?? 1) < 1 }

        if me.kind == .orion {
            let leadX = world.fighters
                .first { $0.team == .hero && $0.kind != .orion && !$0.spec.isDecoy && $0.isAlive }?.pos.x ?? me.pos.x
            // A plate is worth holding while a shut gate it opens still stands ahead of the lead, and worth
            // leaving once all it does is hold shut an inverted gate ahead of the lead.
            let needed = { (id: Int) in
                level.gates.contains { !$0.inverted && $0.opensWith.contains(id) && $0.box.minX > leadX - 10 }
            }
            let blocking = { (id: Int) in
                level.gates.contains {
                    $0.inverted && $0.opensWith.contains(id) && $0.box.minX > leadX - 10 && (world.gateOpen[$0.id] ?? 1) < 1
                }
            }
            if let plate = world.plate(under: me) {
                if blocking(plate.id), !needed(plate.id) { return InputFrame(moveX: leadX >= me.pos.x ? -1 : 1) }
                return InputFrame(switchHero: world.frame % 20 == 0)
            }
            let wanted = ahead.filter { $0.box.minX - me.pos.x < 700 }
                .flatMap(\.opensWith)
                .compactMap { id in level.plates.first { $0.id == id && !world.signals.contains(id) && needed(id) } }
                .first
            guard let plate = wanted else { return InputFrame(switchHero: world.frame % 20 == 0) }
            let dx = (plate.x0 + plate.x1) / 2 - me.pos.x
            return InputFrame(moveX: dx > 0 ? 1 : -1)
        }

        for lever in level.levers where !world.signals.contains(lever.id)
            && abs(lever.pos.x - me.pos.x) < 34 && abs(lever.pos.y - me.pos.y) < 10 {
            guard let gate = ahead.first(where: { $0.opensWith.contains(lever.id) }) else { continue }
            // A bell rings only after the one before it.
            if gate.inOrder, gate.opensWith.first(where: { !world.signals.contains($0) }) != lever.id { continue }
            let othersOn = gate.opensWith.allSatisfy { input in
                input == lever.id || world.signals.contains(input) || level.levers.contains { $0.id == input }
            }
            if lever.holdFrames == 0 || othersOn {
                let dir: Double = lever.pos.x >= me.pos.x ? 1 : -1
                return InputFrame(moveX: dir * 0.02, attack: world.frame % 8 == 0)
            }
        }

        guard let gate = ahead.filter({ g in
            g.box.minX - me.pos.x < (g.inOrder ? 1000 : 260) && g.box.minY <= me.pos.y + 1 && g.box.maxY > me.pos.y + 1
        }).min(by: { $0.box.minX < $1.box.minX }) else { return nil }
        if world.wantsOpen(gate) {
            return gate.box.minX - (me.pos.x + me.spec.width / 2) < 40 ? InputFrame() : nil
        }
        if gate.inverted {
            // Shut because a plate is down: hand over to whoever holds it, to step off.
            let held = gate.opensWith.contains { id in level.plates.contains { $0.id == id } && world.signals.contains(id) }
            return held ? InputFrame(switchHero: world.frame % 20 == 0) : nil
        }
        guard let missing = gate.opensWith.first(where: { !world.signals.contains($0) }) else { return nil }
        if level.plates.contains(where: { $0.id == missing }) {
            // Hand over to Orion to put him on it.
            let orion = world.fighters.contains { $0.kind == .orion && $0.isAlive && $0.awake }
            return orion ? InputFrame(switchHero: world.frame % 20 == 0) : nil
        }
        if let lever = level.levers.first(where: { $0.id == missing }) {
            let dx = lever.pos.x - me.pos.x
            let dir: Double = dx >= 0 ? 1 : -1
            if abs(dx) > 34 { return InputFrame(moveX: dir) }
            return InputFrame(moveX: dir * 0.02, attack: world.frame % 8 == 0)
        }
        return nil
    }

    /// Seraphine heals when someone is low; Nimue leaves a decoy when crowded. Caelen's Command is used in
    /// the fights themselves.
    private func kitSpecial(_ me: Fighter, world: World) -> InputFrame? {
        guard me.specialCooldown == 0, me.isActionable else { return nil }
        switch me.spec.special {
        case .heal?:
            let low = world.fighters.contains {
                $0.team == .hero && $0.isAlive && $0.awake && !$0.spec.isDecoy && $0.hp < $0.spec.maxHP * 0.5
            }
            return low ? InputFrame(special: true) : nil
        case .decoy?:
            let crowd = world.fighters.filter {
                $0.team == .enemy && $0.isAlive && $0.awake && !$0.spec.immortal && abs($0.pos.x - me.pos.x) < 160
            }
            return crowd.count >= 2 ? InputFrame(special: true) : nil
        default:
            return nil
        }
    }

    private mutating func jump(_ inp: inout InputFrame) {
        inp.jump = true
        inp.jumpHeld = true
        jumpHeld = 30
    }
}
