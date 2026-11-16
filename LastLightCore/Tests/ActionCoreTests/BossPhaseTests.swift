@testable import ActionCore
import Testing

private func run(_ world: inout World, frames: Int, input: InputFrame = .neutral) -> [GameEvent] {
    var events: [GameEvent] = []
    for _ in 0..<frames { events += world.step(input) }
    return events
}

private func hero(_ world: World) -> Fighter { world.controlled! }

/// Flat ground 0 to 2000, Caelen at `heroX`, The Protocol at `bossX` with no brain.
private func arena(heroX: Double = 400, bossX: Double = 600, facing: Double = -1) -> (World, Int) {
    var level = Level(name: "test", width: 2000, start: Vec2(heroX, 0), exitX: 5000)
    level.ground(-200, 2200)
    var world = World(level: level, seed: 1)
    var spec = Tuning().theProtocol
    spec.brain = nil
    let id = world.spawn(.theProtocol, x: bossX, facing: facing, spec: spec)
    return (world, id)
}

private func index(_ world: World, _ id: Int) -> Int { world.fighters.firstIndex { $0.id == id }! }

private func start(_ world: inout World, _ id: Int, _ attack: Int) {
    let i = index(world, id)
    world.fighters[i].nextAttack = attack
    world.fighters[i].attackBuffer = 3
}

private func hits(on id: Int, in events: [GameEvent]) -> Int {
    events.filter { if case .hit(_, let target, _, _) = $0 { target == id } else { false } }.count
}

/// Leaves the boss open and on `hp`, so the next sword hit lands.
private func expose(_ world: inout World, _ id: Int, hp: Double) {
    let i = index(world, id)
    world.fighters[i].hp = hp
    world.fighters[i].enter(.staggered, duration: 900)
}

private let summon = 3, rain = 4, pulse = 5, beam = 6

// MARK: Phases

@Test func aHitCannotCarryItPastAPhase() {
    var (world, boss) = arena(heroX: 480)
    let max = world.fighter(boss)!.spec.maxHP
    expose(&world, boss, hp: max * 0.6 + 2)
    let events = run(&world, frames: 12, input: InputFrame(attack: true))
    #expect(events.contains(.bossPhase(id: boss, phase: 2)))
    #expect(world.fighter(boss)!.hp == max * 0.6)
    #expect(world.fighter(boss)!.phase == 2)
    #expect(world.fighter(boss)!.state == .phaseShift)
}

@Test func itCannotBeHurtWhileChangingPhase() {
    var (world, boss) = arena(heroX: 480)
    let max = world.fighter(boss)!.spec.maxHP
    expose(&world, boss, hp: max * 0.6 + 2)
    _ = run(&world, frames: 12, input: InputFrame(attack: true))
    let during = run(&world, frames: 60, input: InputFrame(attack: true))
    #expect(hits(on: boss, in: during) == 0)
    #expect(world.fighter(boss)!.hp == max * 0.6)
}

@Test func itOnlyFallsInItsLastPhase() {
    var (world, boss) = arena(heroX: 480)
    expose(&world, boss, hp: 1)
    let events = run(&world, frames: 12, input: InputFrame(attack: true))
    #expect(world.fighter(boss)!.isAlive)
    #expect(!events.contains(.bossDefeated(id: boss)))
    #expect(world.fighter(boss)!.phase == 2)
}

@Test func ascensionTakesItIntoTheAir() {
    var (world, boss) = arena(heroX: 480)
    expose(&world, boss, hp: world.fighter(boss)!.spec.maxHP * 0.6 + 2)
    _ = run(&world, frames: 12, input: InputFrame(attack: true))
    _ = run(&world, frames: 150)
    #expect(world.fighter(boss)!.flying)
    #expect(abs(world.fighter(boss)!.pos.y - Tuning().protocolFlightHeight) < 5)
    // A hero on the floor cannot reach it.
    #expect(world.fighter(boss)!.hurtbox.minY > hero(world).spec.attacks.map { $0.yOffset + $0.height }.max()!)
}

@Test func itCrashesDownOpen() {
    var (world, boss) = arena(heroX: 300)
    let i = index(world, boss)
    world.fighters[i].flying = true
    _ = run(&world, frames: 150)
    world.fighters[i].flying = false
    world.fighters[i].descending = true
    var events: [GameEvent] = []
    for _ in 0..<120 where !events.contains(.bossLanded(id: boss)) { events += world.step(.neutral) }
    #expect(events.contains(.bossLanded(id: boss)))
    #expect(world.fighter(boss)!.onGround)
    #expect(world.fighter(boss)!.isOpen)
}

@Test func theExecutionPhaseStaysOnTheGround() {
    var (world, boss) = arena(heroX: 480)
    let i = index(world, boss)
    world.fighters[i].phase = 2
    world.fighters[i].flying = true
    _ = run(&world, frames: 120)
    expose(&world, boss, hp: world.fighter(boss)!.spec.maxHP * 0.3 + 2)
    world.fighters[i].pos.y = 0
    world.fighters[i].onGround = true
    let events = run(&world, frames: 12, input: InputFrame(attack: true))
    #expect(events.contains(.bossPhase(id: boss, phase: 3)))
    _ = run(&world, frames: 120)
    #expect(!world.fighter(boss)!.flying)
    #expect(world.fighter(boss)!.onGround)
}

// MARK: Ascension attacks

@Test func summonCallsDronesButNeverTooMany() {
    var (world, boss) = arena(heroX: 200, bossX: 1200)
    start(&world, boss, summon)
    _ = run(&world, frames: 60)
    let drones = { world.fighters.filter { $0.kind == .scrapDrone && $0.isAlive }.count }
    #expect(drones() == Tuning().protocolMaxMinions)
    _ = run(&world, frames: 100)
    start(&world, boss, summon)
    _ = run(&world, frames: 60)
    #expect(drones() == Tuning().protocolMaxMinions)
}

@Test func laserRainWarnsThenBurnsAColumnOverTheHero() {
    var (world, boss) = arena(heroX: 400, bossX: 1200)
    start(&world, boss, rain)
    _ = run(&world, frames: Tuning().theProtocol.attacks[rain].windup + 1)
    #expect(world.strikes.count == 4)
    #expect(world.strikes.contains { $0.box.minX < 400 && 400 < $0.box.maxX })
    let allWarning = world.strikes.allSatisfy { $0.isWarning }
    #expect(allWarning)
    let events = run(&world, frames: 80)
    #expect(hits(on: world.controlledID, in: events) == 1)
    #expect(events.contains { if case .struck = $0 { true } else { false } })
    #expect(world.strikes.isEmpty)
}

@Test func laserRainCanBeWalkedOutOf() {
    var (world, boss) = arena(heroX: 400, bossX: 1200)
    start(&world, boss, rain)
    _ = run(&world, frames: Tuning().theProtocol.attacks[rain].windup + 1)
    // A spot between the columns.
    let spot = stride(from: 120.0, through: 1100, by: 10).first { x in
        world.strikes.allSatisfy { x + 40 < $0.box.minX || x - 40 > $0.box.maxX }
    }!
    var events: [GameEvent] = []
    for _ in 0..<80 {
        let dx = spot - hero(world).pos.x
        events += world.step(InputFrame(moveX: abs(dx) < 6 ? 0 : (dx > 0 ? 1 : -1)))
    }
    #expect(hits(on: world.controlledID, in: events) == 0)
}

// MARK: Execution attacks

@Test func thePulseReachesBehindItAndCanBeJumped() {
    var (world, boss) = arena(heroX: 760)
    start(&world, boss, pulse)
    #expect(hits(on: world.controlledID, in: run(&world, frames: 80)) == 1)

    var (jumping, other) = arena(heroX: 760)
    start(&jumping, other, pulse)
    _ = run(&jumping, frames: Tuning().theProtocol.attacks[pulse].windup - 8)
    var events = run(&jumping, frames: 1, input: InputFrame(jump: true, jumpHeld: true))
    events += run(&jumping, frames: 40, input: InputFrame(jumpHeld: true))
    #expect(hits(on: jumping.controlledID, in: events) == 0)
}

@Test func theBeamCrossesTheRoomAndCanBeJumpedOrDodged() {
    var (world, boss) = arena(heroX: 400, bossX: 1300)
    start(&world, boss, beam)
    #expect(hits(on: world.controlledID, in: run(&world, frames: 90)) == 1)

    for (early, answer) in [(12, InputFrame(jump: true, jumpHeld: true)), (4, InputFrame(moveX: 1, dodge: true))] {
        var (w, b) = arena(heroX: 400, bossX: 1300)
        start(&w, b, beam)
        _ = run(&w, frames: Tuning().theProtocol.attacks[beam].windup - early)
        var events = run(&w, frames: 1, input: answer)
        events += run(&w, frames: 40, input: InputFrame(jumpHeld: true))
        #expect(hits(on: w.controlledID, in: events) == 0)
    }
}

// MARK: The whole fight

@Test func theWholeFightGoesThroughAllThreePhasesAndCanBeWon() {
    for seed in 1...3 {
        var world = World(level: .theProtocol, seed: UInt64(seed))
        var pilot = Autopilot(fights: true)
        var events: [GameEvent] = []
        for _ in 0..<(60 * 300) where !world.isOver { events += world.step(pilot.input(for: world)) }
        let boss = world.bossID!
        #expect(world.isComplete, "seed \(seed): boss hp \(world.boss!.hp), phase \(world.boss!.phase), hero hp \(hero(world).hp)")
        #expect(events.contains(.bossPhase(id: boss, phase: 2)), "seed \(seed)")
        #expect(events.contains(.bossPhase(id: boss, phase: 3)), "seed \(seed)")
        #expect(events.contains(.bossLanded(id: boss)), "seed \(seed)")
        let moves = Set(events.compactMap { if case .swing(let id, let n) = $0, id == boss { n } else { nil } })
        #expect(moves.contains(summon) || moves.contains(rain), "seed \(seed)")
        #expect(moves.contains(pulse) || moves.contains(beam), "seed \(seed)")
    }
}
