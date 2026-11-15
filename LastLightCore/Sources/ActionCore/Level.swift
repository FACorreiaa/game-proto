/// A piece of ground. `box` is where it rests; a moving platform slides from there to `box + travel` and back.
public struct Platform: Sendable, Equatable {
    public var box: Box
    /// Can be jumped through from below and landed on from above.
    public var oneWay: Bool
    public var travel: Vec2
    /// Frames for a full there-and-back trip. Zero means it does not move.
    public var period: Int

    public init(_ box: Box, oneWay: Bool = false, travel: Vec2 = .zero, period: Int = 0) {
        self.box = box
        self.oneWay = oneWay
        self.travel = travel
        self.period = period
    }

    public var moves: Bool { period > 0 && travel != .zero }

    /// Where it is on a given frame. The motion eases in and out at both ends.
    public func box(at frame: Int) -> Box {
        guard moves else { return box }
        let phase = Double(frame % period) / Double(period)
        let t = phase < 0.5 ? phase * 2 : (1 - phase) * 2
        let eased = t * t * (3 - 2 * t)
        return box.offset(by: Vec2(travel.x * eased, travel.y * eased))
    }
}

/// Something that hurts heroes who touch it. A timed hazard switches on and off.
public struct Hazard: Sendable, Equatable {
    public var box: Box
    public var damage: Double
    /// Frames for one on-and-off cycle. Zero means always on.
    public var period: Int
    public var onFrames: Int
    /// Shifts the cycle, so two hazards with the same period can alternate.
    public var phase: Int
    /// Frames of warning shown before it switches on.
    public var warning: Int

    public init(_ box: Box, damage: Double, period: Int = 0, onFrames: Int = 0, phase: Int = 0, warning: Int = 30) {
        self.box = box
        self.damage = damage
        self.period = period
        self.onFrames = onFrames
        self.phase = phase
        self.warning = warning
    }

    public func isOn(at frame: Int) -> Bool {
        period == 0 || (frame + phase) % period < onFrames
    }

    public func isWarning(at frame: Int) -> Bool {
        period > 0 && !isOn(at: frame) && (frame + phase) % period >= period - warning
    }

    /// Frames until it next switches on. Zero while it is on.
    public func framesUntilOn(at frame: Int) -> Int {
        isOn(at: frame) ? 0 : period - (frame + phase) % period
    }
}

public struct Pickup: Sendable, Equatable {
    public var id: Int
    public var pos: Vec2
    /// Off the main route; counted separately.
    public var secret: Bool

    public init(id: Int, at pos: Vec2, secret: Bool = false) {
        self.id = id
        self.pos = pos
        self.secret = secret
    }
}

public struct Placement: Sendable, Equatable {
    public var kind: FighterKind
    public var pos: Vec2

    public init(_ kind: FighterKind, x: Double, y: Double = 0) {
        self.kind = kind
        self.pos = Vec2(x, y)
    }
}

/// Everything a level is made of. Pure data: a level can be written by hand here or loaded from a file later.
public struct Level: Sendable, Equatable {
    public var name: String
    public var width: Double
    public var start: Vec2
    public var platforms: [Platform] = []
    public var hazards: [Hazard] = []
    /// Where the hero comes back after falling or after a retry, in the order they are reached.
    public var checkpoints: [Vec2] = []
    public var pickups: [Pickup] = []
    public var enemies: [Placement] = []
    /// The companion. Placed next to the start it fights from the first step; placed further in, it
    /// waits there and joins when the hero reaches it.
    public var partner: Placement?
    /// A level with a boss has no exit: it ends when the boss falls.
    public var boss: Placement?
    /// Story scenes and what sets each one off.
    public var scenes: [SceneTrigger] = []
    /// Reaching this x on the ground finishes the level.
    public var exitX: Double
    /// Falling below this is falling out of the level.
    public var killY = -260.0

    public init(name: String, width: Double, start: Vec2, exitX: Double) {
        self.name = name
        self.width = width
        self.start = start
        self.exitX = exitX
    }

    /// A block of ground from `x0` to `x1` whose top is at `top`.
    public mutating func ground(_ x0: Double, _ x1: Double, top: Double = 0) {
        platforms.append(Platform(Box(minX: x0, minY: killY - 200, maxX: x1, maxY: top)))
    }

    public mutating func ledge(_ x0: Double, _ x1: Double, top: Double, travel: Vec2 = .zero, period: Int = 0) {
        platforms.append(Platform(Box(minX: x0, minY: top - 18, maxX: x1, maxY: top), oneWay: true,
                                  travel: travel, period: period))
    }
}

extension Level {
    /// Phase 1 movement yard: every basic of running, jumping, dodging and fighting once, in order,
    /// with room to repeat each. Jump reach with default tuning is about 114 high and 170 across.
    public static let foundryYard: Level = {
        var l = Level(name: "Foundry Yard", width: 4400, start: Vec2(120, 0), exitX: 4300)
        l.partner = Placement(.orion, x: 60)

        // Run, and a dummy to hit.
        l.ground(-200, 900)
        l.enemies.append(Placement(.dummy, x: 430))
        // Two steps up, then a drop.
        l.ground(640, 760, top: 50)
        l.ground(760, 900, top: 100)

        // A staircase of ledges to a secret, above the main path.
        l.ground(900, 1500)
        l.ledge(1010, 1130, top: 90)
        l.ledge(1180, 1300, top: 175)
        l.ledge(1350, 1470, top: 260)
        l.pickups.append(Pickup(id: 1, at: Vec2(1070, 130)))
        l.pickups.append(Pickup(id: 2, at: Vec2(1410, 305), secret: true))

        // First gap.
        l.ground(1610, 2300)
        l.pickups.append(Pickup(id: 3, at: Vec2(1555, 95)))
        l.enemies.append(Placement(.scrapDrone, x: 1960))
        // A wall to clear.
        l.ground(2180, 2240, top: 84)

        // A wide pit crossed on a moving platform.
        l.ledge(2320, 2440, top: 0, travel: Vec2(240, 0), period: 260)
        l.ground(2700, 3400)
        l.checkpoints.append(Vec2(2770, 0))

        // An arc that switches on and off: wait for it, or dodge through.
        l.hazards.append(Hazard(Box(minX: 2960, minY: 0, maxX: 2996, maxY: 150), damage: 12,
                                period: 150, onFrames: 80))
        l.pickups.append(Pickup(id: 4, at: Vec2(3080, 40)))
        // A lift.
        l.ledge(3180, 3290, top: 0, travel: Vec2(0, 170), period: 240)
        l.ground(3300, 3400, top: 150)
        l.pickups.append(Pickup(id: 5, at: Vec2(3350, 195)))

        // The fight.
        l.ground(3400, 4600)
        l.checkpoints.append(Vec2(3580, 0))
        l.enemies.append(Placement(.scrapDrone, x: 3760))
        l.enemies.append(Placement(.scrapDrone, x: 3880))
        l.enemies.append(Placement(.forgedSoldier, x: 4080))
        return l
    }()
}

extension Level {
    /// Chapter 1, segment A. No words: the floor teaches running, the step teaches jumping, the gap
    /// teaches distance. Orion is found standing dormant halfway, and the first machine comes after.
    public static let awakening: Level = {
        var l = Level(name: "Awakening", width: 3500, start: Vec2(120, 0), exitX: 3380)

        l.ground(-200, 1100)
        l.ground(520, 700, top: 60)
        l.pickups.append(Pickup(id: 1, at: Vec2(470, 95)))

        // First gap, with a shard hanging where the jump should peak.
        l.ground(1200, 1800)
        l.pickups.append(Pickup(id: 2, at: Vec2(1150, 90)))
        // Optional climb.
        l.ledge(1300, 1420, top: 85)
        l.ledge(1470, 1590, top: 165)
        l.pickups.append(Pickup(id: 3, at: Vec2(1530, 210)))

        // Up onto the gantry where Orion waits.
        l.ground(1700, 1800, top: 90)
        l.ground(1800, 2400, top: 180)
        l.partner = Placement(.orion, x: 2080, y: 180)
        l.scenes.append(SceneTrigger("awakening.orion", on: .partnerJoins))
        l.checkpoints.append(Vec2(1900, 180))

        // Down to the lower floor and the first machine.
        l.ground(2520, 3700)
        l.pickups.append(Pickup(id: 4, at: Vec2(2460, 150)))
        l.checkpoints.append(Vec2(2620, 0))
        l.enemies.append(Placement(.scrapDrone, x: 3000))
        return l
    }()

    /// Chapter 1, segment B. Machines in numbers, arcs that alternate, platforms over pits, one secret.
    public static let machineHall: Level = {
        var l = Level(name: "The Machine Hall", width: 5900, start: Vec2(120, 0), exitX: 5780)
        l.partner = Placement(.orion, x: 60)

        l.ground(-200, 800)
        l.enemies.append(Placement(.scrapDrone, x: 520))
        l.enemies.append(Placement(.scrapDrone, x: 640))

        // A pit crossed on a moving platform.
        l.ledge(820, 940, top: 0, travel: Vec2(240, 0), period: 260)
        l.ground(1200, 2600)
        l.checkpoints.append(Vec2(1270, 0))
        l.enemies.append(Placement(.forgedSoldier, x: 1600))

        // Two arcs that take turns.
        l.hazards.append(Hazard(Box(minX: 1830, minY: 0, maxX: 1862, maxY: 150), damage: 12, period: 160, onFrames: 80))
        l.hazards.append(Hazard(Box(minX: 1940, minY: 0, maxX: 1972, maxY: 150), damage: 12, period: 160, onFrames: 80,
                                phase: 80))
        l.pickups.append(Pickup(id: 1, at: Vec2(1900, 40)))

        // A raised walkway, and above it the secret.
        l.ground(2080, 2600, top: 80)
        l.ledge(2200, 2320, top: 165)
        l.ledge(2380, 2500, top: 250)
        l.pickups.append(Pickup(id: 2, at: Vec2(2440, 295), secret: true))

        // The swarm.
        l.ground(2720, 3500)
        l.checkpoints.append(Vec2(2790, 0))
        l.enemies.append(Placement(.scrapDrone, x: 2980))
        l.enemies.append(Placement(.scrapDrone, x: 3080))
        l.enemies.append(Placement(.scrapDrone, x: 3180))
        l.pickups.append(Pickup(id: 3, at: Vec2(3250, 40)))

        // Up the lift, then over the long pit on a slow platform.
        l.ledge(3390, 3490, top: 0, travel: Vec2(0, 170), period: 240)
        l.ground(3500, 3700, top: 150)
        l.pickups.append(Pickup(id: 4, at: Vec2(3600, 195)))
        l.ledge(3720, 3840, top: 150, travel: Vec2(340, 0), period: 320)
        l.ground(4200, 4400, top: 150)

        // The gate guard.
        l.ground(4400, 6100)
        l.checkpoints.append(Vec2(4300, 150))
        l.hazards.append(Hazard(Box(minX: 4640, minY: 0, maxX: 4672, maxY: 150), damage: 12, period: 150, onFrames: 80))
        l.enemies.append(Placement(.forgedSoldier, x: 4950))
        l.enemies.append(Placement(.scrapDrone, x: 5120))
        l.enemies.append(Placement(.scrapDrone, x: 5260))
        l.pickups.append(Pickup(id: 5, at: Vec2(5500, 40)))
        return l
    }()

    /// Chapter 1, segment C. One room, one machine far larger than the hero.
    public static let theProtocol: Level = {
        var l = Level(name: "The Protocol", width: 1700, start: Vec2(140, 0), exitX: .infinity)
        l.partner = Placement(.orion, x: 80)
        l.scenes.append(SceneTrigger("protocol.wake", on: .bossWakes))
        l.ground(-200, 1900)
        l.boss = Placement(.theProtocol, x: 1180)
        return l
    }()

    /// Every level, in play order. The yard is the movement test; the rest is Chapter 1.
    public static let all: [Level] = [.foundryYard, .awakening, .machineHall, .theProtocol]
}
