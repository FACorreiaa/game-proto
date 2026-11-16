@testable import ActionCore
import Testing

private func run(_ world: inout World, frames: Int, input: InputFrame = .neutral) -> [GameEvent] {
    var events: [GameEvent] = []
    for _ in 0..<frames { events += world.step(input) }
    return events
}

private func hero(_ world: World) -> Fighter { world.controlled! }

/// Flat ground, Caelen at `heroX`, and The Protocol at x 600 facing left with no brain, so each test
/// decides what it does.
private func arena(heroX: Double = 400) -> (World, Int) {
    var level = Level(name: "test", width: 2000, start: Vec2(heroX, 0), exitX: 5000)
    level.ground(-200, 2200)
    var world = World(level: level, seed: 1)
    var spec = Tuning().theProtocol
    spec.brain = nil
    let id = world.spawn(.theProtocol, x: 600, facing: -1, spec: spec)
    return (world, id)
}

private func index(_ world: World, _ id: Int) -> Int { world.fighters.firstIndex { $0.id == id }! }

private func startAttack(_ world: inout World, _ id: Int, _ attack: Int) {
    let i = index(world, id)
    world.fighters[i].nextAttack = attack
    world.fighters[i].attackBuffer = 3
}

private func hits(on id: Int, in events: [GameEvent]) -> Int {
    events.filter { if case .hit(_, let target, _, _) = $0 { target == id } else { false } }.count
}

private let slam = 0, charge = 1, surge = 2

// MARK: Armour and openings

@Test func theProtocolIsFarLargerThanTheHero() {
    let t = Tuning()
    #expect(t.theProtocol.height >= t.caelen.height * 2.5)
    #expect(t.theProtocol.width >= t.caelen.width * 3)
}

@Test func hitsDoNothingWhileItsArmourIsClosed() {
    var (world, boss) = arena(heroX: 480)
    let events = run(&world, frames: 30, input: InputFrame(attack: true))
    #expect(world.fighter(boss)!.hp == world.fighter(boss)!.spec.maxHP)
    #expect(events.contains { if case .blocked = $0 { true } else { false } })
    #expect(hits(on: boss, in: events) == 0)
}

@Test func itCanBeHurtWhileItRecoversFromItsOwnAttack() {
    // The hero stands behind it, where the slam does not reach.
    var (world, boss) = arena(heroX: 720)
    startAttack(&world, boss, slam)
    let spec = world.fighter(boss)!.spec.attacks[slam]
    _ = run(&world, frames: spec.windup + spec.active + 2)
    #expect(world.fighter(boss)!.isOpen)
    let events = run(&world, frames: 20, input: InputFrame(moveX: -0.02, attack: true))
    #expect(hits(on: boss, in: events) >= 1)
    #expect(world.fighter(boss)!.hp < world.fighter(boss)!.spec.maxHP)
    // It is never knocked back or interrupted.
    #expect(world.fighter(boss)!.state == .attack(slam))
    #expect(world.fighter(boss)!.pos.x == 600)
}

@Test func theArmourClosesAgainWhenTheRecoveryEnds() {
    var (world, boss) = arena(heroX: 720)
    startAttack(&world, boss, slam)
    _ = run(&world, frames: world.fighter(boss)!.spec.attacks[slam].total + 2)
    #expect(!world.fighter(boss)!.isOpen)
}

@Test func aParryStaggersItAndOpensItUp() {
    var (world, boss) = arena(heroX: 480)
    startAttack(&world, boss, slam)
    let windup = world.fighter(boss)!.spec.attacks[slam].windup
    _ = run(&world, frames: windup - 3)
    let events = run(&world, frames: 8, input: InputFrame(attack: true))
    #expect(events.contains { if case .parried = $0 { true } else { false } })
    #expect(world.fighter(boss)!.state == .staggered)
    #expect(world.fighter(boss)!.isOpen)
    #expect(hero(world).hp == hero(world).spec.maxHP)
}

// MARK: Its attacks

@Test func theSlamHurtsAHeroStandingInFrontOfIt() {
    var (world, boss) = arena(heroX: 480)
    startAttack(&world, boss, slam)
    let events = run(&world, frames: 70)
    #expect(hits(on: world.controlledID, in: events) == 1)
}

@Test func everyAttackGivesALongWarning() {
    for attack in Tuning().theProtocol.attacks {
        #expect(attack.windup >= 45)
        #expect(attack.recovery >= 60)
    }
}

@Test func theChargeStandsStillThroughItsWarningThenCrossesTheRoom() {
    var (world, boss) = arena(heroX: 1500)
    let i = index(world, boss)
    world.fighters[i].facing = 1
    startAttack(&world, boss, charge)
    let spec = world.fighter(boss)!.spec.attacks[charge]
    _ = run(&world, frames: spec.windup - 1)
    #expect(world.fighter(boss)!.pos.x == 600)
    _ = run(&world, frames: spec.active + 2)
    #expect(world.fighter(boss)!.pos.x > 780)
}

@Test func theChargeCanBeDodgedThrough() {
    var (world, boss) = arena(heroX: 380)
    startAttack(&world, boss, charge)
    let windup = world.fighter(boss)!.spec.attacks[charge].windup
    _ = run(&world, frames: windup - 3)
    var events = run(&world, frames: 1, input: InputFrame(moveX: 1, dodge: true))
    events += run(&world, frames: 60)
    #expect(hits(on: world.controlledID, in: events) == 0)
    #expect(events.contains(.evaded(id: world.controlledID)))
}

@Test func theSurgeRunsAlongTheFloorAndCanBeJumped() {
    var (world, boss) = arena(heroX: 200)
    startAttack(&world, boss, surge)
    let windup = world.fighter(boss)!.spec.attacks[surge].windup
    _ = run(&world, frames: windup - 8)
    let events = run(&world, frames: 40, input: InputFrame(jump: true, jumpHeld: true))
    #expect(hits(on: world.controlledID, in: events) == 0)

    var (grounded, other) = arena(heroX: 200)
    startAttack(&grounded, other, surge)
    #expect(hits(on: grounded.controlledID, in: run(&grounded, frames: 90)) == 1)
}

@Test func standingBehindItIsSafeFromEveryAttackOfTheFirstPhase() {
    for attack in [slam, charge, surge] {
        var (world, boss) = arena(heroX: 760)
        startAttack(&world, boss, attack)
        #expect(hits(on: world.controlledID, in: run(&world, frames: 170)) == 0, "attack \(attack)")
    }
}

// MARK: The fight in its level

@Test func itSleepsUntilTheHeroComesCloseThenTakesTimeToRise() {
    var world = World(level: .theProtocol, seed: 1)
    let boss = world.bossID!
    _ = run(&world, frames: 60)
    #expect(!world.boss!.awake)
    #expect(world.boss!.pos.x == Level.theProtocol.boss!.pos.x)

    var events: [GameEvent] = []
    while !world.boss!.awake, world.frame < 600 { events += world.step(InputFrame(moveX: 1)) }
    #expect(events.contains(.woke(id: boss)))
    let rise = run(&world, frames: world.tuning.theProtocol.wakeDelay - 2)
    #expect(!rise.contains { if case .swing(let id, _) = $0 { id == boss } else { false } })
}

@Test func theBrainSlamsUpCloseAndUsesItsOtherAttacksFromAfar() {
    var seen: Set<Int> = []
    for seed in 1...6 {
        var world = World(level: .theProtocol, seed: UInt64(seed))
        var pilot = Autopilot()
        for _ in 0..<(60 * 60) where !world.isOver {
            for case .swing(let id, let attack) in world.step(pilot.input(for: world)) where id == world.bossID {
                seen.insert(attack)
            }
        }
    }
    #expect(seen.isSuperset(of: [slam, charge, surge]))
}

@Test func theLevelEndsWhenTheProtocolFalls() {
    var world = World(level: .theProtocol, seed: 3)
    var pilot = Autopilot()
    var events: [GameEvent] = []
    for _ in 0..<(60 * 240) where !world.isOver { events += world.step(pilot.input(for: world)) }
    #expect(world.isComplete)
    #expect(events.contains(.bossDefeated(id: world.bossID!)))
    #expect(events.last == .levelComplete)
    #expect(hero(world).isAlive)
}

@Test func aHeroWhoOnlySwingsLosesToIt() {
    // Mashing attack in front of it is not a way through: the armour holds and the attacks land.
    var world = World(level: .theProtocol, seed: 4)
    var events: [GameEvent] = []
    for _ in 0..<(60 * 180) where !world.isOver {
        let gap = world.boss!.pos.x - hero(world).pos.x
        events += world.step(InputFrame(moveX: gap > 160 ? 1 : 0.02, attack: world.frame % 20 == 0))
    }
    #expect(!world.isComplete)
}

@Test func theBossFightIsTheSameEveryTimeForTheSameSeed() {
    func play() -> [GameEvent] {
        var world = World(level: .theProtocol, seed: 7)
        var pilot = Autopilot()
        var events: [GameEvent] = []
        for _ in 0..<3000 where !world.isOver { events += world.step(pilot.input(for: world)) }
        return events
    }
    #expect(play() == play())
}
