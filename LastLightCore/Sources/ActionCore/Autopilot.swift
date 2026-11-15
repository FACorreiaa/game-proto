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

        if fights {
            let foe = world.fighters
                .filter { $0.team == .enemy && $0.isAlive && !$0.spec.immortal && abs($0.pos.y - me.pos.y) < 70 }
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

        // A hazard just ahead that is on, or will be before the hero is through.
        let waitForHazard = level.hazards.contains { h in
            let ahead = h.box.minX - (me.pos.x + half)
            guard ahead > -(h.box.maxX - h.box.minX) - me.spec.width, ahead < 50 else { return false }
            return h.isOn(at: world.frame) || h.period - world.frame % h.period < 45
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

    private mutating func jump(_ inp: inout InputFrame) {
        inp.jump = true
        inp.jumpHeld = true
        jumpHeld = 30
    }
}
