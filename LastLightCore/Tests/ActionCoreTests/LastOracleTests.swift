@testable import ActionCore
import Testing

private func run(_ world: inout World, frames: Int, input: InputFrame = .neutral) -> [GameEvent] {
    var events: [GameEvent] = []
    for _ in 0..<frames { events += world.step(input) }
    return events
}

/// The terrace with the Oracle awake at x 1200 facing left, a hero who can't fall, and Orion out of the way.
private func terrace(heroX: Double = 1000, brain: Bool = false) -> (World, Int) {
    var tuning = Tuning()
    tuning.caelen.maxHP = 100_000
    if !brain { tuning.lastOracle.brain = nil }
    tuning.lastOracle.wakeDelay = 0
    var world = World(level: .oracleTerrace, hero: .caelen, tuning: tuning, seed: 1)
    let oracle = world.bossID!
    let o = world.fighters.firstIndex { $0.id == oracle }!
    world.fighters[o].awake = true
    world.fighters[o].facing = -1
    let h = world.fighters.firstIndex { $0.id == world.controlledID }!
    world.fighters[h].pos.x = heroX
    world.fighters[h].facing = 1
    world.fighters.removeAll { $0.kind == .orion }
    return (world, oracle)
}

private func use(_ world: inout World, _ id: Int, _ attack: Int) {
    let i = world.fighters.firstIndex { $0.id == id }!
    world.fighters[i].nextAttack = attack
    world.fighters[i].attackBuffer = 3
}

private func setPhase(_ world: inout World, _ id: Int, _ phase: Int) {
    let i = world.fighters.firstIndex { $0.id == id }!
    world.fighters[i].phase = phase
    world.fighters[i].hp = world.fighters[i].spec.maxHP * (phase == 2 ? 0.5 : 0.2)
}

private func heroDazed(_ events: [GameEvent], _ world: World) -> Bool {
    events.contains { if case .dazed(let id) = $0 { id == world.controlledID } else { false } }
}

@Test func theOracleChangesPhaseTwiceAndNeverFlinches() {
    var (world, oracle) = terrace(heroX: 1110)
    var phases: [Int] = []
    for _ in 0..<6000 {
        // Pinned in front of her, swinging.
        let i = world.fighters.firstIndex { $0.id == world.controlledID }!
        world.fighters[i].pos.x = 1110
        world.fighters[i].facing = 1
        world.fighters[i].attackBuffer = world.frame % 10 == 0 ? 3 : 0
        for e in world.step(.neutral) { if case .bossPhase(_, let p) = e { phases.append(p) } }
        if let o = world.fighter(oracle) {
            #expect(o.state != .hitstun)
            #expect(!o.flying)
        }
        if world.isComplete { break }
    }
    #expect(phases == [2, 3])
}

@Test func herFlareDazesThoseWhoLookAndHerEclipseThoseWhoLookAway() {
    for (attack, dazesFacing) in [(OracleBrain.flare, true), (OracleBrain.eclipse, false)] {
        for facing in [1.0, -1.0] {
            var (world, oracle) = terrace(heroX: 1000)
            let h = world.fighters.firstIndex { $0.id == world.controlledID }!
            world.fighters[h].facing = facing
            use(&world, oracle, attack)
            let events = run(&world, frames: 80)
            #expect(heroDazed(events, world) == ((facing > 0) == dazesFacing), "attack \(attack) facing \(facing)")
        }
    }
}

@Test func aProphecyLandsWhereTheHeroIsHeading() {
    var (world, oracle) = terrace(heroX: 600)
    use(&world, oracle, OracleBrain.prophecy)
    let windup = world.fighter(oracle)!.spec.attacks[OracleBrain.prophecy].windup
    var placed: Strike?
    for _ in 0..<(windup + 5) {
        _ = world.step(InputFrame(moveX: 1))
        if placed == nil, let s = world.strikes.first { placed = s }
    }
    let strike = try! #require(placed)
    let hero = world.controlled!
    // Laid ahead of where the hero stood when it was cast, toward where they are going.
    #expect(strike.box.center.x > hero.pos.x + 20)
    #expect(strike.kind == .light)
}

@Test func theDarkRisesFromTheFloorAfterAWarning() {
    var (world, oracle) = terrace(heroX: 700)
    setPhase(&world, oracle, 2)
    use(&world, oracle, OracleBrain.dark)
    _ = run(&world, frames: 50)
    let dark = world.strikes.filter { $0.kind == .dark }
    #expect(dark.count == 4)
    #expect(dark.contains { $0.box.minX <= 700 && 700 <= $0.box.maxX })
    #expect(dark.allSatisfy { $0.box.minY <= 0 && $0.box.maxY >= 170 })
}

@Test func atDuskSheCallsTheFaithfulWhenNoneAreLeft() {
    var (world, oracle) = terrace(heroX: 700, brain: true)
    setPhase(&world, oracle, 2)
    let events = run(&world, frames: 200)
    #expect(events.filter { if case .spawned(_, .zealot) = $0 { true } else { false } }.count == 2)
}

@Test func inTheEndingHerLightAndDarkTakeTurns() {
    var (world, oracle) = terrace(heroX: 1100, brain: true)
    setPhase(&world, oracle, 3)
    var gazes: [Int] = []
    for _ in 0..<2400 {
        // Keep the hero close and out of harm's way so she keeps choosing between staff and gaze.
        let h = world.fighters.firstIndex { $0.id == world.controlledID }!
        world.fighters[h].pos.x = world.fighter(oracle)!.pos.x - 150
        world.fighters[h].hp = world.fighters[h].spec.maxHP
        for e in world.step(.neutral) {
            if case .swing(let id, let i) = e, id == oracle, i == OracleBrain.flare || i == OracleBrain.eclipse { gazes.append(i) }
        }
    }
    #expect(gazes.contains(OracleBrain.flare) && gazes.contains(OracleBrain.eclipse))
    let repeats = zip(gazes, gazes.dropFirst()).filter { $0 == $1 }.count
    #expect(repeats == 0, "\(gazes)")
}
