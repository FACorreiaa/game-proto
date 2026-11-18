@testable import ActionCore
import Testing

private func run(_ world: inout World, frames: Int, input: InputFrame = .neutral) -> [GameEvent] {
    var events: [GameEvent] = []
    for _ in 0..<frames { events += world.step(input) }
    return events
}

private func index(_ world: World, _ id: Int) -> Int { world.fighters.firstIndex { $0.id == id }! }

private func bossID(_ world: World) -> Int { world.fighters.first { $0.kind == .lamplighter }!.id }

/// Lights lamp `id` (at `x`) with a swing from the hero.
private func light(_ world: inout World, x: Double) -> [GameEvent] {
    let h = index(world, world.controlledID)
    world.fighters[h].pos.x = x - 30
    world.fighters[h].facing = 1
    world.fighters[h].attackBuffer = 3
    return run(&world, frames: 24)
}

@Test func inTheDarkNothingTouchesHimAndInALampsLightItDoes() {
    var world = World(level: .lampRow, hero: .caelen, seed: 1)
    let boss = bossID(world)
    #expect(world.isWarded(boss))
    _ = light(&world, x: 1220)
    #expect(world.signals.contains(3))
    let b = index(world, boss)
    world.fighters[b].pos.x = 1260
    #expect(!world.isWarded(boss))
    world.fighters[b].pos.x = 1450
    #expect(world.isWarded(boss))
}

@Test func heDousesALampHeStandsByThenNeedsAWhileBeforeTheNext() {
    var world = World(level: .lampRow, hero: .caelen, seed: 1)
    let boss = bossID(world)
    _ = light(&world, x: 1220)
    let b = index(world, boss)
    world.fighters[b].awake = true
    world.fighters[b].pos.x = 1240
    var events = run(&world, frames: 90)
    #expect(events.contains(.lever(id: 3, on: false)))
    // Light it again at once: he can't put it out straight away.
    events = light(&world, x: 1220)
    world.fighters[index(world, boss)].pos.x = 1240
    events += run(&world, frames: world.tuning.lamplighterDouseRest - 90)
    #expect(!events.contains(.lever(id: 3, on: false)))
    #expect(world.signals.contains(3))
}

@Test func aLampBurnsOutOnItsOwn() {
    var world = World(level: .lampRow, hero: .caelen, seed: 1)
    _ = light(&world, x: 420)
    #expect(world.signals.contains(1))
    let events = run(&world, frames: 500)
    #expect(events.contains(.lever(id: 1, on: false)))
}

@Test func inOverdriveHeSnuffsTheWholeRowAndCallsRatborn() {
    var world = World(level: .lampRow, hero: .caelen, seed: 1)
    let boss = bossID(world)
    var b = index(world, boss)
    world.fighters[b].awake = true
    world.fighters[b].hp = world.fighters[b].spec.maxHP * 0.5
    world.fighters[b].phase = 2
    var snuffed = false
    for _ in 0..<40 {
        // Keep the far lamps lit so a snuff has something to put out.
        _ = light(&world, x: 420)
        _ = light(&world, x: 1600)
        b = index(world, boss)
        world.fighters[b].pos.x = 1000
        let events = run(&world, frames: 60)
        if events.contains(.lever(id: 1, on: false)) && events.contains(.lever(id: 4, on: false)) { snuffed = true }
        if snuffed, world.fighters.contains(where: { $0.kind == .ratborn && $0.isAlive }) { break }
    }
    #expect(snuffed)
    #expect(world.fighters.contains { $0.kind == .ratborn })
}

@Test func theLampRowSitsBetweenTheRoofsAndTheDocksAndEveryLeadCanWinIt() {
    let names = Chapter.lanternCities.levels(for: .caelen).map(\.name)
    #expect(names == ["The Ember Market", "The Toll Canal", "The Lantern Roofs", "The Lamp Row", "The Cinder Docks", "The Cinder Vault"])
    for lead in [FighterKind.caelen, .seraphine, .nimue] {
        var world = World(level: .lampRow, hero: lead, seed: 2)
        var pilot = Autopilot(fights: true)
        var lit = 0
        while !world.isOver, world.frame < 60 * 180 {
            for e in world.step(pilot.input(for: world)) { if case .lever(_, true) = e { lit += 1 } }
        }
        #expect(world.isComplete, "\(lead)")
        #expect(lit >= 2, "\(lead): the fight is won by lighting lamps")
    }
}
