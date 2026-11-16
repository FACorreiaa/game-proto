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
/// A lever standing on a floor. A hero's swing throws it. With `holdFrames` above zero it springs back after that
/// long, and a gate it opens closes again: the time to get through.
public struct Lever: Sendable, Equatable {
    public var id: Int
    /// The foot of the lever, on the floor.
    public var pos: Vec2
    public var holdFrames: Int
    /// A lamp: while it is on, its light reaches this far either side. Zero for a plain lever.
    public var glow: Double

    public init(id: Int, at pos: Vec2, holdFrames: Int = 0, glow: Double = 0) {
        self.id = id
        self.pos = pos
        self.holdFrames = holdFrames
        self.glow = glow
    }

    public var box: Box { Box(minX: pos.x - 14, minY: pos.y, maxX: pos.x + 14, maxY: pos.y + 56) }
}

/// A plate set into a floor. It is down while someone on the heroes' side stands on it (a decoy counts).
public struct Plate: Sendable, Equatable {
    public var id: Int
    public var x0: Double
    public var x1: Double
    /// The floor it is set into.
    public var top: Double

    public init(id: Int, x0: Double, x1: Double, top: Double = 0) {
        self.id = id
        self.x0 = x0
        self.x1 = x1
        self.top = top
    }
}

/// A gate: solid while shut. It opens while every lever and plate in `opensWith` is on, or, if `inverted`, while
/// any of them is off. It slides up into the wall above as it opens.
public struct Gate: Sendable, Equatable {
    public var id: Int
    public var box: Box
    public var opensWith: [Int]
    public var inverted: Bool

    public init(id: Int, box: Box, opensWith: [Int], inverted: Bool = false) {
        self.id = id
        self.box = box
        self.opensWith = opensWith
        self.inverted = inverted
    }
}

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
    public var levers: [Lever] = []
    public var plates: [Plate] = []
    public var gates: [Gate] = []
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

    /// A gate standing on a floor at `top`, `height` tall and 24 wide, centred on `x`.
    public mutating func gate(_ id: Int, x: Double, top: Double = 0, height: Double = 170, opensWith: [Int],
                              inverted: Bool = false) {
        gates.append(Gate(id: id, box: Box(minX: x - 12, minY: top, maxX: x + 12, maxY: top + height),
                          opensWith: opensWith, inverted: inverted))
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
        l.scenes.append(SceneTrigger("hall.enter", on: .start))

        l.ground(-200, 800)
        l.enemies.append(Placement(.scrapDrone, x: 520))
        l.enemies.append(Placement(.scrapDrone, x: 640))

        // A pit crossed on a moving platform.
        l.ledge(820, 940, top: 0, travel: Vec2(240, 0), period: 260)
        l.ground(1200, 2600)
        l.checkpoints.append(Vec2(1270, 0))
        l.enemies.append(Placement(.forgedSoldier, x: 1600))
        // The first Sentry Core, floating behind the soldier.
        l.enemies.append(Placement(.sentryCore, x: 1780, y: 40))

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
        // A Dogma Frame shields the guard: it has to go first.
        l.enemies.append(Placement(.dogmaFrame, x: 5040))
        l.enemies.append(Placement(.scrapDrone, x: 5120))
        l.enemies.append(Placement(.scrapDrone, x: 5260))
        l.pickups.append(Pickup(id: 5, at: Vec2(5500, 40)))
        return l
    }()

    /// Chapter 1's puzzle level: the Foundry's locks. A lever and its gate; a plate Orion has to hold while the
    /// lead goes on; a timed lever and a race; a fight; then a gate that needs both a plate and a timed lever,
    /// with a Soldier between them while Orion is busy holding.
    public static let lockWorks: Level = {
        var l = Level(name: "The Lock Works", width: 5300, start: Vec2(120, 0), exitX: 5150)
        l.partner = Placement(.orion, x: 60)
        l.scenes.append(SceneTrigger("locks.arrive", on: .start))

        // 1. A lever and its gate.
        l.ground(-200, 2700)
        l.pickups.append(Pickup(id: 1, at: Vec2(500, 40)))
        l.enemies.append(Placement(.scrapDrone, x: 650))
        l.scenes.append(SceneTrigger("locks.lever", on: .reach(780)))
        l.levers.append(Lever(id: 1, at: Vec2(900, 0)))
        l.gate(10, x: 1050, opensWith: [1])

        // 2. A plate: Orion holds it while the lead goes through.
        l.checkpoints.append(Vec2(1150, 0))
        l.enemies.append(Placement(.forgedSoldier, x: 1400))
        l.pickups.append(Pickup(id: 2, at: Vec2(1550, 40)))
        l.scenes.append(SceneTrigger("locks.plate", on: .reach(1600)))
        l.plates.append(Plate(id: 2, x0: 1700, x1: 1770))
        l.gate(11, x: 2000, opensWith: [2])

        // 3. A lever that springs back, and a race over a gap and a step to its gate.
        l.checkpoints.append(Vec2(2300, 0))
        l.scenes.append(SceneTrigger("locks.race", on: .reach(2350)))
        l.levers.append(Lever(id: 3, at: Vec2(2420, 0), holdFrames: 330))
        l.ground(2800, 2950)
        l.ground(2950, 3100, top: 70)
        l.ground(3100, 4300)
        l.gate(12, x: 3400, opensWith: [3])

        // A fight in the cooling hall, and the secret up the pipes.
        l.checkpoints.append(Vec2(3550, 0))
        // Far enough past the race gate that nothing wakes while the lead is still racing for it.
        l.enemies.append(Placement(.sentryCore, x: 4180, y: 150))
        l.enemies.append(Placement(.scrapDrone, x: 4060))
        l.enemies.append(Placement(.scrapDrone, x: 4130))
        l.ledge(3650, 3770, top: 95)
        l.ledge(3800, 3920, top: 180)
        l.ledge(3950, 4070, top: 265)
        l.pickups.append(Pickup(id: 3, at: Vec2(4010, 310), secret: true))
        l.pickups.append(Pickup(id: 4, at: Vec2(4200, 40)))

        // 4. Both at once: Orion on the plate, the lead to the timed lever past a Soldier, then the gate.
        l.ground(4300, 5500)
        l.checkpoints.append(Vec2(4330, 0))
        l.plates.append(Plate(id: 4, x0: 4400, x1: 4470))
        l.enemies.append(Placement(.forgedSoldier, x: 4620))
        l.levers.append(Lever(id: 5, at: Vec2(4720, 0), holdFrames: 240))
        l.gate(13, x: 4850, opensWith: [4, 5])
        l.pickups.append(Pickup(id: 5, at: Vec2(5000, 40)))
        return l
    }()

    /// Chapter 1's mid-boss: the gate between the Machine Hall and the Protocol, held by the Line Warden.
    public static let wardensGate: Level = {
        var l = Level(name: "The Warden's Gate", width: 1500, start: Vec2(140, 0), exitX: .infinity)
        l.partner = Placement(.orion, x: 80)
        l.scenes.append(SceneTrigger("warden.wake", on: .bossWakes))
        l.ground(-200, 1700)
        l.boss = Placement(.lineWarden, x: 1050)
        return l
    }()

    /// Chapter 1, segment C. One room, one machine far larger than the hero.
    public static let theProtocol: Level = {
        var l = Level(name: "The Protocol", width: 1700, start: Vec2(140, 0), exitX: .infinity)
        l.partner = Placement(.orion, x: 80)
        l.scenes.append(SceneTrigger("protocol.wake", on: .bossWakes))
        l.scenes.append(SceneTrigger("protocol.end", on: .complete))
        l.ground(-200, 1900)
        l.boss = Placement(.theProtocol, x: 1180)
        return l
    }()

    /// Seraphine's opening. She comes into the Foundry from outside, up its outer works to the gauges where it
    /// measures the light. A Sentry Core watches the climb; Orion is found holding the gauge floor.
    public static let sunGauges: Level = {
        var l = Level(name: "The Sun Gauges", width: 3900, start: Vec2(120, 0), exitX: 3700)
        l.scenes.append(SceneTrigger("gauges.arrive", on: .start))

        // Up the outer wall in two steps.
        l.ground(-200, 900)
        l.ground(560, 700, top: 60)
        l.ground(700, 900, top: 120)
        l.pickups.append(Pickup(id: 1, at: Vec2(630, 105)))

        // Across to the gauge walk, watched from above.
        l.ground(1030, 1700, top: 120)
        l.pickups.append(Pickup(id: 2, at: Vec2(965, 200)))
        l.enemies.append(Placement(.sentryCore, x: 1560, y: 160))
        // The secret sits on the gauges themselves.
        l.ledge(1150, 1270, top: 205)
        l.ledge(1320, 1440, top: 290)
        l.pickups.append(Pickup(id: 3, at: Vec2(1380, 335), secret: true))

        // Down to the gauge floor, where Orion is.
        l.ground(1700, 4100)
        l.checkpoints.append(Vec2(1790, 0))
        l.partner = Placement(.orion, x: 2150)
        l.scenes.append(SceneTrigger("gauges.orion", on: .partnerJoins))
        l.enemies.append(Placement(.scrapDrone, x: 2500))
        l.enemies.append(Placement(.scrapDrone, x: 2600))

        // The gauge keeper, then the lift to the inner gate.
        l.checkpoints.append(Vec2(2760, 0))
        l.enemies.append(Placement(.forgedSoldier, x: 3000))
        l.pickups.append(Pickup(id: 4, at: Vec2(3250, 40)))
        l.ledge(3390, 3490, top: 0, travel: Vec2(0, 170), period: 240)
        l.ground(3500, 4100, top: 150)
        return l
    }()

    /// Nimue's opening. Her smuggling route runs under the Foundry: drains with arcs that take turns, a pit,
    /// and drones in numbers. Orion is found down there, the way out of the line.
    public static let undercroft: Level = {
        var l = Level(name: "The Undercroft", width: 4000, start: Vec2(120, 0), exitX: 3800)
        l.scenes.append(SceneTrigger("undercroft.arrive", on: .start))

        l.ground(-200, 1500)
        l.pickups.append(Pickup(id: 1, at: Vec2(420, 40)))
        // Two arcs that take turns.
        l.hazards.append(Hazard(Box(minX: 900, minY: 0, maxX: 932, maxY: 150), damage: 12, period: 140, onFrames: 70))
        l.hazards.append(Hazard(Box(minX: 1060, minY: 0, maxX: 1092, maxY: 150), damage: 12, period: 140, onFrames: 70,
                                phase: 70))
        l.pickups.append(Pickup(id: 2, at: Vec2(996, 40)))
        // A pair of drones: the place for a decoy.
        l.enemies.append(Placement(.scrapDrone, x: 1300))
        l.enemies.append(Placement(.scrapDrone, x: 1390))

        // A pit crossed on a moving platform.
        l.ledge(1520, 1640, top: 0, travel: Vec2(240, 0), period: 260)
        l.ground(1900, 4200)
        l.checkpoints.append(Vec2(1970, 0))
        // A climb off the route to a secret.
        l.ledge(2050, 2170, top: 90)
        l.ledge(2220, 2340, top: 175)
        l.pickups.append(Pickup(id: 3, at: Vec2(2280, 220), secret: true))
        l.partner = Placement(.orion, x: 2450)
        l.scenes.append(SceneTrigger("undercroft.orion", on: .partnerJoins))

        // The way up to the line.
        l.checkpoints.append(Vec2(2700, 0))
        l.enemies.append(Placement(.scrapDrone, x: 2950))
        l.enemies.append(Placement(.scrapDrone, x: 3050))
        l.enemies.append(Placement(.scrapDrone, x: 3150))
        l.enemies.append(Placement(.forgedSoldier, x: 3400))
        l.hazards.append(Hazard(Box(minX: 3550, minY: 0, maxX: 3582, maxY: 150), damage: 12, period: 150, onFrames: 80))
        l.pickups.append(Pickup(id: 4, at: Vec2(3680, 40)))
        return l
    }()

    /// Every level once: Chapter 1's three openings and the levels all three share, then Chapter 2.
    public static let all: [Level] = [.awakening, .sunGauges, .undercroft, .foundryYard, .machineHall, .lockWorks, .wardensGate,
                                      .theProtocol,
                                      .emberMarket, .lanternRoofs, .lampRow, .cinderDocks, .cinderVault,
                                      .pilgrimRoad, .sunCloister, .choirStair, .oracleTerrace]

    /// The Dawnfaith's boss room: the terrace at the top of the Choir Stair, where the Last Oracle waits.
    public static let oracleTerrace: Level = {
        var l = Level(name: "The Oracle's Terrace", width: 1700, start: Vec2(140, 0), exitX: .infinity)
        l.partner = Placement(.orion, x: 80)
        l.scenes.append(SceneTrigger("oracle.wake", on: .bossWakes))
        l.scenes.append(SceneTrigger("oracle.end", on: .complete))
        l.ground(-200, 1900)
        l.boss = Placement(.lastOracle, x: 1200)
        return l
    }()

    // MARK: Chapter 3, The Dawnfaith

    /// Ivory road through the Dawnfaith's farmland: the first Zealots and Acolytes, a Solar Guard, a pilgrim ferry.
    public static let pilgrimRoad: Level = {
        var l = Level(name: "The Pilgrim Road", width: 4800, start: Vec2(120, 0), exitX: 4700)
        l.partner = Placement(.orion, x: 60)
        l.scenes.append(SceneTrigger("road.arrive", on: .start))

        l.ground(-200, 1500)
        l.pickups.append(Pickup(id: 1, at: Vec2(700, 40)))
        l.enemies.append(Placement(.zealot, x: 900))
        // Shrine steps beside the road.
        l.ledge(1100, 1220, top: 90)
        l.ledge(1260, 1380, top: 175)
        l.pickups.append(Pickup(id: 2, at: Vec2(1320, 220)))

        l.ground(1600, 2900)
        l.checkpoints.append(Vec2(1700, 0))
        l.enemies.append(Placement(.zealot, x: 2000))
        l.enemies.append(Placement(.zealot, x: 2080))
        l.enemies.append(Placement(.radiantAcolyte, x: 2600))
        // Up the bell frame to the secret.
        l.ledge(2200, 2320, top: 90)
        l.ledge(2360, 2480, top: 175)
        l.ledge(2520, 2640, top: 260)
        l.pickups.append(Pickup(id: 3, at: Vec2(2580, 305), secret: true))

        // A wayside wall, and down again.
        l.ground(2900, 3020, top: 70)
        l.ground(3020, 3900)
        l.checkpoints.append(Vec2(3100, 0))
        l.enemies.append(Placement(.zealot, x: 3150))
        l.enemies.append(Placement(.solarGuard, x: 3350))
        l.enemies.append(Placement(.radiantAcolyte, x: 3520))
        l.pickups.append(Pickup(id: 4, at: Vec2(3450, 40)))

        // The river, crossed on a pilgrim ferry.
        l.ledge(3920, 4040, top: 0, travel: Vec2(240, 0), period: 260)
        l.ground(4300, 5000)
        l.checkpoints.append(Vec2(4370, 0))
        // Only an Acolyte past the river, so nothing rushes the landing.
        l.enemies.append(Placement(.radiantAcolyte, x: 4760))
        l.pickups.append(Pickup(id: 5, at: Vec2(4500, 40)))
        return l
    }()

    /// Galleries round a sunlit court: Halo Disciples overhead, and Solar Guards shielding the Acolytes behind them.
    public static let sunCloister: Level = {
        var l = Level(name: "The Sun Cloister", width: 5200, start: Vec2(120, 0), exitX: 5000)
        l.partner = Placement(.orion, x: 60)
        l.scenes.append(SceneTrigger("cloister.arrive", on: .start))
        l.scenes.append(SceneTrigger("cloister.halo", on: .reach(650)))

        l.ground(-200, 1400)
        l.pickups.append(Pickup(id: 1, at: Vec2(500, 40)))
        l.enemies.append(Placement(.haloDisciple, x: 1000, y: 150))
        l.ledge(1080, 1260, top: 110)
        l.pickups.append(Pickup(id: 2, at: Vec2(1170, 155)))

        l.ground(1500, 2900)
        l.checkpoints.append(Vec2(1600, 0))
        l.enemies.append(Placement(.solarGuard, x: 2000))
        l.enemies.append(Placement(.radiantAcolyte, x: 2250))
        l.enemies.append(Placement(.haloDisciple, x: 2450, y: 150))
        // The upper gallery, out over the gap.
        l.ledge(2550, 2670, top: 95)
        l.ledge(2700, 2820, top: 185)
        l.ledge(2850, 2970, top: 270)
        l.pickups.append(Pickup(id: 3, at: Vec2(2910, 315), secret: true))

        l.ground(3000, 4100)
        l.checkpoints.append(Vec2(3100, 0))
        l.enemies.append(Placement(.zealot, x: 3400))
        l.enemies.append(Placement(.zealot, x: 3480))
        l.enemies.append(Placement(.haloDisciple, x: 3800, y: 150))
        l.pickups.append(Pickup(id: 4, at: Vec2(3600, 40)))

        // The court's fountain, crossed on a turning bridge.
        l.ledge(4120, 4240, top: 0, travel: Vec2(240, 0), period: 260)
        l.ground(4500, 5400)
        l.checkpoints.append(Vec2(4570, 0))
        l.enemies.append(Placement(.radiantAcolyte, x: 4850))
        l.pickups.append(Pickup(id: 5, at: Vec2(4700, 40)))
        return l
    }()

    /// A long stair up the hill, terrace after terrace, with everything the Dawnfaith fields so far.
    public static let choirStair: Level = {
        var l = Level(name: "The Choir Stair", width: 5600, start: Vec2(120, 0), exitX: 5450)
        l.partner = Placement(.orion, x: 60)
        l.scenes.append(SceneTrigger("stair.arrive", on: .start))
        l.scenes.append(SceneTrigger("stair.listen", on: .reach(4200)))

        l.ground(-200, 1200)
        l.pickups.append(Pickup(id: 1, at: Vec2(500, 40)))
        l.enemies.append(Placement(.zealot, x: 800))
        l.enemies.append(Placement(.radiantAcolyte, x: 1050))

        // The first flight.
        l.ground(1200, 1350, top: 70)
        l.ground(1350, 1500, top: 140)
        l.ground(1500, 2700, top: 210)
        l.pickups.append(Pickup(id: 2, at: Vec2(1420, 185)))
        l.checkpoints.append(Vec2(1600, 210))
        l.enemies.append(Placement(.solarGuard, x: 1900, y: 210))
        l.enemies.append(Placement(.zealot, x: 2200, y: 210))
        l.enemies.append(Placement(.haloDisciple, x: 2450, y: 360))
        l.ledge(2300, 2420, top: 300)
        l.ledge(2450, 2570, top: 385)
        l.pickups.append(Pickup(id: 3, at: Vec2(2510, 430), secret: true))

        // A landing across a broken step.
        l.ground(2800, 4000, top: 210)
        l.checkpoints.append(Vec2(2900, 210))
        l.enemies.append(Placement(.solarGuard, x: 3200, y: 210))
        l.enemies.append(Placement(.radiantAcolyte, x: 3450, y: 210))
        l.enemies.append(Placement(.zealot, x: 3650, y: 210))
        l.enemies.append(Placement(.zealot, x: 3720, y: 210))
        l.pickups.append(Pickup(id: 4, at: Vec2(3350, 250)))

        // The last flight to the top terrace.
        l.ground(4000, 4150, top: 280)
        l.ground(4150, 5800, top: 350)
        l.checkpoints.append(Vec2(4300, 350))
        l.enemies.append(Placement(.haloDisciple, x: 4600, y: 500))
        l.enemies.append(Placement(.solarGuard, x: 4900, y: 350))
        l.enemies.append(Placement(.radiantAcolyte, x: 5150, y: 350))
        l.pickups.append(Pickup(id: 5, at: Vec2(4450, 390)))
        return l
    }()

    /// Chapter 1 as one lead plays it: their own opening, then the Foundry levels everyone shares.
    public static func chapter1(for lead: FighterKind) -> [Level] {
        [Faction(lead: lead).opening, .foundryYard, .machineHall, .lockWorks, .wardensGate, .theProtocol]
    }
}

// MARK: Chapter 2: The Lantern Cities

extension Level {
    /// The way into the Cities: a market street under awnings. Ratborn one at a time, then in pairs, and the first
    /// Lantern Gunner. A secret up on the awnings.
    public static let emberMarket: Level = {
        var l = Level(name: "The Ember Market", width: 4900, start: Vec2(120, 0), exitX: 4800)
        l.partner = Placement(.orion, x: 60)
        l.scenes.append(SceneTrigger("market.arrive", on: .start))

        l.scenes.append(SceneTrigger("market.ratborn", on: .reach(700)))

        l.ground(-200, 1300)
        // Awnings: one-way, so they can be jumped up through.
        l.ledge(500, 640, top: 95)
        l.ledge(700, 840, top: 180)
        l.pickups.append(Pickup(id: 1, at: Vec2(770, 225)))
        l.enemies.append(Placement(.ratborn, x: 950))

        // A gap between stalls.
        l.ground(1400, 2500)
        l.pickups.append(Pickup(id: 2, at: Vec2(1360, 90)))
        l.checkpoints.append(Vec2(1500, 0))
        l.enemies.append(Placement(.ratborn, x: 1750))
        l.enemies.append(Placement(.ratborn, x: 1830))
        l.enemies.append(Placement(.lanternGunner, x: 2300))
        // Up the awnings to the secret.
        l.ledge(1980, 2100, top: 90)
        l.ledge(2150, 2270, top: 175)
        l.ledge(2320, 2440, top: 260)
        l.pickups.append(Pickup(id: 3, at: Vec2(2380, 305), secret: true))

        // A step up onto the square, and down again.
        l.ground(2500, 2620, top: 70)
        l.ground(2620, 3900)
        l.checkpoints.append(Vec2(2700, 0))
        l.enemies.append(Placement(.ratborn, x: 3000))
        l.enemies.append(Placement(.ratborn, x: 3080))
        l.enemies.append(Placement(.lanternGunner, x: 3350))
        l.pickups.append(Pickup(id: 4, at: Vec2(3200, 40)))

        // The canal, crossed on a moving barge.
        l.ledge(3920, 4040, top: 0, travel: Vec2(240, 0), period: 260)
        l.ground(4300, 5100)
        l.checkpoints.append(Vec2(4370, 0))
        // Only a Gunner past the canal, and out of throwing range of the landing.
        l.enemies.append(Placement(.lanternGunner, x: 4760))
        l.pickups.append(Pickup(id: 5, at: Vec2(4650, 40)))
        return l
    }()

    /// Over the rooftops: gaps, a cargo line to ride, a lift, and the first Night Weaver.
    public static let lanternRoofs: Level = {
        var l = Level(name: "The Lantern Roofs", width: 5300, start: Vec2(120, 0), exitX: 5050)
        l.partner = Placement(.orion, x: 60)
        l.scenes.append(SceneTrigger("roofs.arrive", on: .start))

        l.ground(-200, 900)
        l.pickups.append(Pickup(id: 1, at: Vec2(300, 40)))
        // Roof to roof, then up.
        l.ground(1000, 1700)
        l.checkpoints.append(Vec2(1060, 0))
        l.enemies.append(Placement(.ratborn, x: 1450))
        l.ground(1620, 1700, top: 70)
        l.ground(1700, 2500, top: 150)
        l.pickups.append(Pickup(id: 2, at: Vec2(1660, 115)))
        // The first Night Weaver waits on the high roof, away from the edge.
        l.enemies.append(Placement(.nightWeaver, x: 2250, y: 150))

        // A cargo line across the alley.
        l.ledge(2520, 2640, top: 150, travel: Vec2(300, 0), period: 300)
        l.ground(2950, 3700, top: 100)
        l.checkpoints.append(Vec2(3020, 100))
        l.enemies.append(Placement(.ratborn, x: 3200, y: 100))
        l.enemies.append(Placement(.lanternGunner, x: 3550, y: 100))
        // Chimneys to a secret.
        l.ledge(3100, 3220, top: 185)
        l.ledge(3270, 3390, top: 270)
        l.pickups.append(Pickup(id: 3, at: Vec2(3330, 315), secret: true))

        // Down to a lower roof.
        l.ground(3700, 4400)
        l.pickups.append(Pickup(id: 4, at: Vec2(3760, 40)))
        l.checkpoints.append(Vec2(3800, 0))
        l.enemies.append(Placement(.nightWeaver, x: 4150))
        l.enemies.append(Placement(.ratborn, x: 4250))

        // A lift up to the high roof and the stairs down to the docks.
        l.ledge(4400, 4500, top: 0, travel: Vec2(0, 170), period: 240)
        l.ground(4510, 5500, top: 150)
        l.enemies.append(Placement(.lanternGunner, x: 4850, y: 150))
        l.pickups.append(Pickup(id: 5, at: Vec2(4950, 195)))
        return l
    }()

    /// The docks: furnace vents that flare in turn, a barge, and the Smuggler Brute.
    public static let cinderDocks: Level = {
        var l = Level(name: "The Cinder Docks", width: 5700, start: Vec2(120, 0), exitX: 5450)
        l.partner = Placement(.orion, x: 60)
        l.scenes.append(SceneTrigger("docks.arrive", on: .start))

        l.ground(-200, 1200)
        l.pickups.append(Pickup(id: 1, at: Vec2(350, 40)))
        // A furnace vent: wait for it, or dodge through.
        l.hazards.append(Hazard(Box(minX: 700, minY: 0, maxX: 732, maxY: 150), damage: 12, period: 150, onFrames: 70))
        l.enemies.append(Placement(.ratborn, x: 950))

        // A barge across the slip.
        l.ledge(1220, 1340, top: 0, travel: Vec2(240, 0), period: 260)
        l.ground(1600, 2700)
        l.checkpoints.append(Vec2(1670, 0))
        // The first Smuggler Brute, with room to fight it.
        l.enemies.append(Placement(.smugglerBrute, x: 2000))
        l.enemies.append(Placement(.ratborn, x: 2200))
        l.enemies.append(Placement(.lanternGunner, x: 2350))
        l.pickups.append(Pickup(id: 2, at: Vec2(1800, 40)))
        // Crates up to a secret.
        l.ground(2400, 2520, top: 80)
        l.ledge(2560, 2680, top: 165)
        l.ledge(2730, 2850, top: 250)
        l.pickups.append(Pickup(id: 3, at: Vec2(2790, 295), secret: true))

        // The warehouse row: two vents that take turns.
        l.ground(2800, 3900)
        l.checkpoints.append(Vec2(3000, 0))
        l.hazards.append(Hazard(Box(minX: 3100, minY: 0, maxX: 3132, maxY: 150), damage: 12, period: 160, onFrames: 80))
        l.hazards.append(Hazard(Box(minX: 3220, minY: 0, maxX: 3252, maxY: 150), damage: 12, period: 160, onFrames: 80,
                                phase: 80))
        l.pickups.append(Pickup(id: 4, at: Vec2(3176, 40)))
        l.enemies.append(Placement(.smugglerBrute, x: 3500))
        l.enemies.append(Placement(.nightWeaver, x: 3720))

        // The last pier.
        l.ground(3900, 3980, top: 70)
        l.ground(3980, 5900)
        l.checkpoints.append(Vec2(4200, 0))
        l.enemies.append(Placement(.ratborn, x: 4550))
        l.enemies.append(Placement(.ratborn, x: 4620))
        l.enemies.append(Placement(.smugglerBrute, x: 4700))
        l.enemies.append(Placement(.lanternGunner, x: 4900))
        l.pickups.append(Pickup(id: 5, at: Vec2(5200, 40)))
        return l
    }()
}

extension Level {
    /// Chapter 2's mid-boss: a dark street of lamps, and the Lamplighter, who can be hurt only in their light. The
    /// lamps start out: he has put them out.
    public static let lampRow: Level = {
        var l = Level(name: "The Lamp Row", width: 1800, start: Vec2(140, 0), exitX: .infinity)
        l.partner = Placement(.orion, x: 80)
        l.scenes.append(SceneTrigger("lamp.wake", on: .bossWakes))
        l.ground(-200, 2000)
        for (n, x) in [420.0, 820, 1220, 1600].enumerated() {
            // Light here is paid for by the hour: a lamp burns out on its own.
            l.levers.append(Lever(id: n + 1, at: Vec2(x, 0), holdFrames: 480, glow: 150))
        }
        l.boss = Placement(.lamplighter, x: 1250)
        return l
    }()

    /// Chapter 2's last room: the Cinder King's vault behind the docks.
    public static let cinderVault: Level = {
        var l = Level(name: "The Cinder Vault", width: 1700, start: Vec2(140, 0), exitX: .infinity)
        l.partner = Placement(.orion, x: 80)
        l.scenes.append(SceneTrigger("vault.wake", on: .bossWakes))
        l.scenes.append(SceneTrigger("vault.end", on: .complete))
        l.ground(-200, 1900)
        l.boss = Placement(.cinderKing, x: 1200)
        return l
    }()
}
