@testable import ActionCore
import Testing

private func run(_ world: inout World, frames: Int, input: InputFrame = .neutral) -> [GameEvent] {
    var events: [GameEvent] = []
    for _ in 0..<frames { events += world.step(input) }
    return events
}

/// The gate with the Warden awake at x 1050 facing left, and a hero who can't fall. Orion is out of the way.
private func gate(heroX: Double, brain: Bool = false) -> (World, Int) {
    var tuning = Tuning()
    tuning.caelen.maxHP = 100_000
    if !brain { tuning.lineWarden.brain = nil }
    tuning.lineWarden.wakeDelay = 0
    var world = World(level: .wardensGate, hero: .caelen, tuning: tuning, seed: 1)
    let warden = world.bossID!
    let w = world.fighters.firstIndex { $0.id == warden }!
    world.fighters[w].awake = true
    world.fighters[w].facing = -1
    let h = world.fighters.firstIndex { $0.id == world.controlledID }!
    world.fighters[h].pos.x = heroX
    world.fighters[h].facing = heroX < 1050 ? 1 : -1
    world.fighters.removeAll { $0.kind == .orion }
    return (world, warden)
}

private func swing(_ world: inout World) -> [GameEvent] {
    let h = world.fighters.firstIndex { $0.id == world.controlledID }!
    world.fighters[h].attackBuffer = 3
    return run(&world, frames: 24)
}

private func hits(_ events: [GameEvent], on id: Int) -> Int {
    events.filter { if case .hit(_, let t, _, _) = $0 { t == id } else { false } }.count
}

@Test func theWardensGuardStopsHitsFromTheFront() {
    var (world, warden) = gate(heroX: 950)
    let events = swing(&world)
    #expect(hits(events, on: warden) == 0)
    #expect(events.contains { if case .blocked(_, let t, _) = $0 { t == warden } else { false } })
    #expect(world.fighter(warden)!.hp == world.fighter(warden)!.spec.maxHP)
}

@Test func itKeepsItsGuardThroughItsWindupAndDropsItAsItRecovers() {
    var (world, warden) = gate(heroX: 950)
    let w = world.fighters.firstIndex { $0.id == warden }!
    world.fighters[w].enter(.attack(WardenBrain.cut))
    #expect(world.fighter(warden)!.isGuarding)
    world.fighters[w].stateFrame = world.fighters[w].spec.attacks[WardenBrain.cut].windup + 6
    #expect(world.fighter(warden)!.attackPhase == .recovery)
    #expect(!world.fighter(warden)!.isGuarding)
}

@Test func fromBehindItIsHurtAndDoesNotFlinch() {
    var (world, warden) = gate(heroX: 1150)
    let events = swing(&world)
    #expect(hits(events, on: warden) >= 1)
    #expect(world.fighter(warden)!.hp < world.fighter(warden)!.spec.maxHP)
    #expect(world.fighter(warden)!.state != .hitstun)
}

@Test func itTurnsSlowlySoThereIsTimeBehindIt() {
    var tuning = Tuning()
    let (start, warden) = gate(heroX: 1150, brain: true)
    var world = start
    let gap = tuning.wardenTurnDelay
    _ = run(&world, frames: gap - 5)
    #expect(world.fighter(warden)!.facing == -1)
    _ = run(&world, frames: 30)
    #expect(world.fighter(warden)!.facing == 1)
    tuning = Tuning()
    #expect(tuning.wardenFastTurnDelay < tuning.wardenTurnDelay)
}

@Test func lingeringBehindItBringsTheSpin() {
    var (world, warden) = gate(heroX: 1150, brain: true)
    var spun = false
    for _ in 0..<200 {
        // Keep the hero pinned behind it.
        let h = world.fighters.firstIndex { $0.id == world.controlledID }!
        let w = world.fighters.firstIndex { $0.id == warden }!
        world.fighters[h].pos.x = world.fighters[w].pos.x - world.fighters[w].facing * 70
        for e in world.step(.neutral) { if case .swing(let id, WardenBrain.spin) = e, id == warden { spun = true } }
        if spun { break }
    }
    #expect(spun)
    #expect(world.fighter(warden)!.spec.attacks[WardenBrain.spin].bothSides)
}

@Test func inOverdriveItCallsAForgedSoldierToTheLine() {
    var (world, warden) = gate(heroX: 700, brain: true)
    let w = world.fighters.firstIndex { $0.id == warden }!
    world.fighters[w].phase = 2
    world.fighters[w].hp = world.fighters[w].spec.maxHP * 0.4
    let events = run(&world, frames: 240)
    #expect(events.contains { if case .spawned(_, .forgedSoldier) = $0 { true } else { false } })
    #expect(world.fighters.filter { $0.kind == .forgedSoldier && $0.isAlive }.count == 1)
}

@Test func theWardensGateSitsBetweenTheHallAndTheProtocolForEveryLead() {
    for lead in [FighterKind.caelen, .seraphine, .nimue] {
        let names = Level.chapter1(for: lead).map(\.name)
        let i = names.firstIndex(of: "The Warden's Gate")
        #expect(i != nil && names[i! - 1] == "The Machine Hall" && names[i! + 1] == "The Protocol", "\(lead)")
    }
}
