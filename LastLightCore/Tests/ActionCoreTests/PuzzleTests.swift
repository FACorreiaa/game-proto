@testable import ActionCore
import Testing

private func run(_ world: inout World, frames: Int, input: InputFrame = .neutral) -> [GameEvent] {
    var events: [GameEvent] = []
    for _ in 0..<frames { events += world.step(input) }
    return events
}

/// A flat test room: a lever at 300, a plate from 500 to 560, and gates at 800 and 1000.
private func room(hero: FighterKind = .caelen, partner: Bool = true, holdFrames: Int = 0,
                  gateA: [Int] = [1], gateB: [Int] = [2], invertB: Bool = false) -> World {
    var l = Level(name: "Puzzle Room", width: 2000, start: Vec2(200, 0), exitX: 1900)
    l.ground(-200, 2200)
    l.levers.append(Lever(id: 1, at: Vec2(300, 0), holdFrames: holdFrames))
    l.plates.append(Plate(id: 2, x0: 500, x1: 560))
    l.gate(10, x: 800, opensWith: gateA)
    l.gate(11, x: 1000, opensWith: gateB, inverted: invertB)
    if partner { l.partner = Placement(.orion, x: 150) }
    return World(level: l, hero: hero, seed: 1)
}

private func put(_ world: inout World, _ id: Int, x: Double, facing: Double = 1) {
    let i = world.fighters.firstIndex { $0.id == id }!
    world.fighters[i].pos.x = x
    world.fighters[i].facing = facing
}

private func swing(_ world: inout World) -> [GameEvent] {
    let i = world.fighters.firstIndex { $0.id == world.controlledID }!
    world.fighters[i].attackBuffer = 3
    return run(&world, frames: 30)
}

private func gateBox(_ world: World, _ id: Int) -> Box { world.platformBoxes[world.gatePlatform[id]!] }

@Test func aSwingThrowsALeverAndItsGateSlidesOpen() {
    var world = room(partner: false)
    put(&world, world.controlledID, x: 260)
    let events = swing(&world)
    #expect(events.contains(.lever(id: 1, on: true)))
    #expect(events.contains(.gate(id: 10, opening: true)))
    _ = run(&world, frames: 40)
    #expect(world.gateOpen[10] == 1)
    // Open, the gate sits above head height, out of the way.
    #expect(gateBox(world, 10).minY > 150)
}

@Test func aTimedLeverSpringsBackAndItsGateShuts() {
    var world = room(partner: false, holdFrames: 120)
    put(&world, world.controlledID, x: 260)
    _ = swing(&world)
    let events = run(&world, frames: 200)
    #expect(events.contains(.lever(id: 1, on: false)))
    #expect(events.contains(.gate(id: 10, opening: false)))
    #expect(world.gateOpen[10] == 0)
}

@Test func aGateWillNotShutOnSomeoneStandingInIt() {
    var world = room(partner: false, holdFrames: 60)
    put(&world, world.controlledID, x: 260)
    _ = swing(&world)
    _ = run(&world, frames: 40)
    put(&world, world.controlledID, x: 800)
    _ = run(&world, frames: 120)
    #expect(world.gateOpen[10]! > 0.5)
    put(&world, world.controlledID, x: 1300)
    _ = run(&world, frames: 60)
    #expect(world.gateOpen[10] == 0)
}

@Test func aPlateIsDownOnlyWhileSomeoneStandsOnIt() {
    var world = room(partner: false)
    put(&world, world.controlledID, x: 530)
    var events = run(&world, frames: 40)
    #expect(events.contains(.plate(id: 2, down: true)))
    #expect(world.gateOpen[11] == 1)
    put(&world, world.controlledID, x: 700)
    events = run(&world, frames: 40)
    #expect(events.contains(.plate(id: 2, down: false)))
    #expect(world.gateOpen[11] == 0)
}

@Test func aPartnerLeftOnAPlateHoldsItWhileTheLeadGoesOn() {
    var world = room()
    let lead = world.controlledID
    _ = run(&world, frames: 5)
    // Take Orion to the plate and hand control back.
    let events = run(&world, frames: 1, input: InputFrame(switchHero: true))
    let orion = world.controlledID
    #expect(orion != lead && events.contains(.controlChanged(id: orion)))
    put(&world, orion, x: 530)
    _ = run(&world, frames: 40)
    let handed = run(&world, frames: 1, input: InputFrame(switchHero: true))
    #expect(handed.contains(.holding(id: orion)))
    // The lead walks through the open gate; Orion stays on the plate.
    put(&world, lead, x: 940)
    _ = run(&world, frames: 25, input: InputFrame(moveX: 1))
    #expect(world.fighter(orion)!.holding)
    #expect(abs(world.fighter(orion)!.pos.x - 530) < 30)
    #expect(world.gateOpen[11] == 1)
    #expect(world.controlled!.pos.x > 1000)
}

@Test func onceTheLeadIsFarAheadTheHoldingPartnerCatchesUp() {
    var world = room()
    let lead = world.controlledID
    _ = run(&world, frames: 5)
    _ = run(&world, frames: 1, input: InputFrame(switchHero: true))
    let orion = world.controlledID
    put(&world, orion, x: 530)
    _ = run(&world, frames: 40)
    _ = run(&world, frames: 1, input: InputFrame(switchHero: true))
    put(&world, lead, x: 1700)
    let events = run(&world, frames: 60)
    #expect(events.contains { if case .regrouped(let id, _) = $0 { id == orion } else { false } })
    #expect(!world.fighter(orion)!.holding)
    #expect(events.contains(.plate(id: 2, down: false)))
}

@Test func nimuesDecoyCanHoldAPlate() {
    var world = room(hero: .nimue, partner: false)
    put(&world, world.controlledID, x: 530)
    _ = run(&world, frames: 10)
    let i = world.fighters.firstIndex { $0.id == world.controlledID }!
    world.fighters[i].specialBuffer = 3
    _ = run(&world, frames: 5)
    put(&world, world.controlledID, x: 900)
    _ = run(&world, frames: 40)
    #expect(world.fighters.contains { $0.spec.isDecoy })
    #expect(world.signals.contains(2))
    #expect(world.gateOpen[11] == 1)
}

@Test func anInvertedGateShutsWhileItsPlateIsDown() {
    var world = room(partner: false, invertB: true)
    _ = run(&world, frames: 40)
    #expect(world.gateOpen[11] == 1)
    put(&world, world.controlledID, x: 530)
    _ = run(&world, frames: 40)
    #expect(world.gateOpen[11] == 0)
}

@Test func enemiesNeitherPressPlatesNorThrowLevers() {
    var world = room(partner: false)
    put(&world, world.controlledID, x: 100)
    _ = world.spawn(.forgedSoldier, x: 530, facing: -1)
    let soldier = world.spawn(.forgedSoldier, x: 330, facing: -1)
    let i = world.fighters.firstIndex { $0.id == soldier }!
    world.fighters[i].attackBuffer = 3
    _ = run(&world, frames: 60)
    #expect(world.signals.isEmpty)
}

@Test func aShutGateStopsTheHero() {
    var world = room(partner: false)
    put(&world, world.controlledID, x: 700)
    _ = run(&world, frames: 120, input: InputFrame(moveX: 1))
    #expect(world.controlled!.pos.x < 800)
}

@Test func theLockWorksCanBeSolvedByEveryLeadWithAndWithoutFighting() {
    for fights in [false, true] {
        for lead in [FighterKind.caelen, .seraphine, .nimue] {
            var world = World(level: .lockWorks, hero: lead, seed: 1)
            var pilot = Autopilot(fights: fights)
            var opened: Set<Int> = []
            var held = false
            while !world.isOver, world.frame < 60 * 180 {
                for e in world.step(pilot.input(for: world)) {
                    if case .gate(let id, true) = e { opened.insert(id) }
                    if case .holding = e { held = true }
                }
            }
            #expect(world.isComplete, "\(lead) fights: \(fights)")
            // Every gate had to be opened, and Orion had to hold a plate.
            #expect(opened == [10, 11, 12, 13], "\(lead) fights: \(fights)")
            #expect(held, "\(lead) fights: \(fights)")
        }
    }
}

@Test func anInvertedGateStartsOpenWithoutMoving() {
    var world = room(partner: false, invertB: true)
    #expect(world.gateOpen[11] == 1)
    let events = run(&world, frames: 5)
    #expect(!events.contains { if case .gate(11, _) = $0 { true } else { false } })
}

@Test func theTollCanalCanBeSolvedByEveryLeadAndTheTollLeavesOrionBehind() {
    for fights in [false, true] {
        for lead in [FighterKind.caelen, .seraphine, .nimue] {
            var world = World(level: .tollCanal, hero: lead, seed: 1)
            var pilot = Autopilot(fights: fights)
            var opened: Set<Int> = []
            var tollShut = false
            while !world.isOver, world.frame < 60 * 180 {
                for e in world.step(pilot.input(for: world)) {
                    if case .gate(let id, true) = e { opened.insert(id) }
                    if case .gate(12, false) = e { tollShut = true }
                }
            }
            #expect(world.isComplete, "\(lead) fights: \(fights)")
            #expect(opened.isSuperset(of: [10, 11, 12, 13]), "\(lead) fights: \(fights)")
            // Orion on the plate shut the toll gate before it let the lead through.
            #expect(tollShut, "\(lead) fights: \(fights)")
        }
    }
}
