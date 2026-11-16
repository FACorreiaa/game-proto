@testable import ActionCore
import Testing

private func run(_ world: inout World, frames: Int, input: InputFrame = .neutral) -> [GameEvent] {
    var events: [GameEvent] = []
    for _ in 0..<frames { events += world.step(input) }
    return events
}

/// The vault with a brainless king, awake and ready, and a hero who can't fall.
private func vault(heroX: Double = 900) -> (World, Int) {
    var tuning = Tuning()
    tuning.caelen.maxHP = 100_000
    tuning.cinderKing.brain = nil
    tuning.cinderKing.wakeDelay = 0
    var world = World(level: .cinderVault, hero: .caelen, tuning: tuning, seed: 1)
    let king = world.bossID!
    let i = world.fighters.firstIndex { $0.id == king }!
    world.fighters[i].awake = true
    world.fighters[i].stateFrame = 0
    let h = world.fighters.firstIndex { $0.id == world.controlledID }!
    world.fighters[h].pos.x = heroX
    // Orion out of the way.
    if let p = world.fighters.firstIndex(where: { $0.kind == .orion }) { world.fighters[p].pos.x = 100 }
    return (world, king)
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

@Test func theCinderKingChangesPhaseAtItsThresholdsAndNeverFlies() {
    var (world, king) = vault(heroX: 1110)
    var phases: [Int] = []
    for _ in 0..<2000 {
        let i = world.fighters.firstIndex { $0.id == world.controlledID }!
        world.fighters[i].attackBuffer = world.frame % 10 == 0 ? 3 : 0
        // Clear any debtors so the king stays open.
        world.fighters.removeAll { $0.kind == .ratborn }
        for e in world.step(.neutral) { if case .bossPhase(_, let p) = e { phases.append(p) } }
        #expect(world.fighter(king).map { !$0.flying } ?? true)
        if world.isComplete { break }
    }
    #expect(phases == [2, 3])
}

@Test func hisDebtorsShieldHimUntilTheyFall() {
    var (world, king) = vault(heroX: 1100)
    setPhase(&world, king, 2)
    use(&world, king, CinderKingBrain.debtors)
    let called = run(&world, frames: 60)
    #expect(called.filter { if case .spawned(_, .ratborn) = $0 { true } else { false } }.count == 2)
    #expect(world.isWarded(king))

    // A hit while they live does nothing.
    let before = world.fighter(king)!.hp
    let h = world.fighters.firstIndex { $0.id == world.controlledID }!
    world.fighters[h].pos.x = 1110
    world.fighters[h].facing = 1
    world.fighters[h].attackBuffer = 3
    let blocked = run(&world, frames: 20)
    #expect(world.fighter(king)!.hp == before)
    #expect(blocked.contains { if case .blocked(_, let t, _) = $0 { t == king } else { false } })

    // Once they are gone, he can be hurt again.
    for i in world.fighters.indices where world.fighters[i].kind == .ratborn { world.fighters[i].hp = 0; world.fighters[i].enter(.dead) }
    #expect(!world.isWarded(king))
}

@Test func fireBurstsUpUnderTheHeroAfterAWarning() {
    var (world, king) = vault(heroX: 700)
    setPhase(&world, king, 2)
    use(&world, king, CinderKingBrain.vents)
    _ = run(&world, frames: 45)
    let columns = world.strikes.filter { $0.kind == .fire }
    #expect(columns.count == 3)
    #expect(columns.contains { $0.box.minX <= 700 && 700 <= $0.box.maxX && $0.isWarning })
    // Tall enough that jumping doesn't clear it: step out of it instead.
    #expect(columns.allSatisfy { $0.box.maxY >= 170 })
}

@Test func theSweepInThePriceHitsBothSides() {
    var (world, king) = vault(heroX: 1290)
    setPhase(&world, king, 3)
    // A second hero who stands still, behind him.
    var still = Tuning().seraphine
    still.brain = nil
    let behind = world.spawn(.seraphine, x: 1110, facing: 1, spec: still)
    world.fighters[world.fighters.count - 1].awake = true
    // Orion would take it on his guard and stagger the king; this is about the sweep alone.
    world.fighters.removeAll { $0.kind == .orion }
    use(&world, king, CinderKingBrain.sweep)
    let events = run(&world, frames: 60)
    let struck = Set(events.compactMap { if case .hit(let by, let t, _, _) = $0, by == king { t } else { nil } })
    #expect(struck == [world.controlledID, behind])
}

@Test func inTheDebtHeCallsDebtorsWhenNoneAreLeft() {
    var tuning = Tuning()
    tuning.caelen.maxHP = 100_000
    var world = World(level: .cinderVault, hero: .caelen, tuning: tuning, seed: 2)
    let king = world.bossID!
    let i = world.fighters.firstIndex { $0.id == king }!
    world.fighters[i].phase = 2
    world.fighters[i].hp = world.fighters[i].spec.maxHP * 0.5
    world.fighters[i].awake = true
    var called = false
    for _ in 0..<(60 * 20) {
        for e in world.step(.neutral) { if case .spawned(_, .ratborn) = e { called = true } }
        if called { break }
    }
    #expect(called)
}
