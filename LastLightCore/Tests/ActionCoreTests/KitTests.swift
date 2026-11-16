@testable import ActionCore
import Testing

private func run(_ world: inout World, frames: Int, input: InputFrame = .neutral) -> [GameEvent] {
    var events: [GameEvent] = []
    for _ in 0..<frames { events += world.step(input) }
    return events
}

private func index(_ world: World, _ id: Int) -> Int { world.fighters.firstIndex { $0.id == id }! }

/// A fighter that stands still and does nothing.
private func still(_ kind: FighterKind) -> FighterSpec {
    var spec = Tuning().spec(for: kind)
    spec.brain = nil
    return spec
}

private let special = InputFrame(special: true)

// MARK: Seraphine

@Test func lightListensHealsHeroesInRangeOnly() {
    var world = World(seed: 1, arena: 0...2000)
    let seraphine = world.spawn(.seraphine, x: 400, facing: 1)
    world.control(seraphine)
    let near = world.spawn(.orion, x: 600, facing: 1, spec: still(.orion))
    let far = world.spawn(.orion, x: 1200, facing: 1, spec: still(.orion))
    let enemy = world.spawn(.forgedSoldier, x: 500, facing: -1, spec: still(.forgedSoldier))
    for id in [seraphine, near, far, enemy] { world.fighters[index(world, id)].hp = 20 }

    let events = run(&world, frames: 2, input: special)
    let healed = events.compactMap { if case .healed(let id, _) = $0 { id } else { nil } }
    #expect(Set(healed) == [seraphine, near])
    #expect(world.fighters[index(world, seraphine)].hp == 50)
    #expect(world.fighters[index(world, near)].hp == 50)
    #expect(world.fighters[index(world, far)].hp == 20)
    #expect(world.fighters[index(world, enemy)].hp == 20)
}

@Test func lightListensNeverHealsPastFullAndWaitsForItsCooldown() {
    var world = World(seed: 1)
    let seraphine = world.spawn(.seraphine, x: 400, facing: 1)
    world.control(seraphine)
    world.fighters[index(world, seraphine)].hp = 80
    _ = run(&world, frames: 2, input: special)
    #expect(world.fighters[index(world, seraphine)].hp == 90)

    world.fighters[index(world, seraphine)].hp = 10
    let again = run(&world, frames: 30, input: special)
    #expect(!again.contains { if case .healed = $0 { true } else { false } })
    #expect(world.fighters[index(world, seraphine)].hp == 10)
}

@Test func seraphinesBoltReachesAcrossTheRoom() {
    var world = World(seed: 1)
    let seraphine = world.spawn(.seraphine, x: 400, facing: 1)
    world.control(seraphine)
    let dummy = world.spawn(.dummy, x: 620, facing: -1, spec: still(.dummy))
    // Two presses: the swing, then the bolt chained after it.
    var events = run(&world, frames: 1, input: InputFrame(attack: true))
    events += run(&world, frames: 8)
    events += run(&world, frames: 1, input: InputFrame(attack: true))
    events += run(&world, frames: 40)
    let hits = events.filter { if case .hit(_, let t, _, _) = $0 { t == dummy } else { false } }
    #expect(hits.count == 1)
}

// MARK: Nimue

@Test func lanternTrickLeavesADecoyThatEnemiesChase() {
    var world = World(seed: 1, arena: 0...2000)
    let nimue = world.spawn(.nimue, x: 400, facing: 1)
    world.control(nimue)
    let events = run(&world, frames: 2, input: special)
    let decoy = events.compactMap { if case .decoyPlaced(let id, _) = $0 { id } else { nil } }.first
    #expect(decoy != nil)
    // Nimue runs off; a soldier arrives and goes for the decoy, not for her.
    world.fighters[index(world, nimue)].pos.x = 900
    let soldier = world.spawn(.forgedSoldier, x: 300, facing: 1)
    var hitDecoy = false
    for _ in 0..<170 {
        for event in world.step(.neutral) {
            if case .hit(let a, let t, _, _) = event, a == soldier { hitDecoy = hitDecoy || t == decoy }
        }
    }
    #expect(hitDecoy)
}

@Test func aDecoyRunsOutAndIsNeverAHero() {
    var world = World(seed: 1)
    let nimue = world.spawn(.nimue, x: 400, facing: 1)
    world.control(nimue)
    var events = run(&world, frames: 2, input: special)
    let decoy = events.compactMap { if case .decoyPlaced(let id, _) = $0 { id } else { nil } }.first!

    // It can't be switched to.
    events += run(&world, frames: 1, input: InputFrame(switchHero: true))
    #expect(world.controlledID == nimue)

    // With the only real hero gone, the game is over even while the decoy stands.
    world.fighters[index(world, nimue)].hp = 0
    world.fighters[index(world, nimue)].enter(.dead)
    events += run(&world, frames: 2)
    #expect(events.contains(.heroDown))

    var later = World(seed: 1)
    later.control(later.spawn(.nimue, x: 400, facing: 1))
    _ = run(&later, frames: 2, input: special)
    let gone = run(&later, frames: 200)
    #expect(gone.contains { if case .decoyGone = $0 { true } else { false } })
    #expect(!later.fighters.contains { $0.spec.isDecoy })
    _ = decoy
}

// MARK: Partner AI

@Test func partnerSeraphineHealsWhenHurt() {
    var world = World(seed: 1)
    let caelen = world.spawn(.caelen, x: 400, facing: 1)
    world.control(caelen)
    let seraphine = world.spawn(.seraphine, x: 340, facing: 1)
    world.fighters[index(world, caelen)].hp = 30
    let events = run(&world, frames: 10)
    #expect(events.contains { if case .healed(let id, _) = $0 { id == caelen } else { false } })
    _ = seraphine
}

@Test func partnerNimueLeavesADecoyWhenCrowded() {
    var world = World(seed: 1, arena: 0...2000)
    let caelen = world.spawn(.caelen, x: 300, facing: 1)
    world.control(caelen)
    _ = world.spawn(.nimue, x: 500, facing: 1)
    _ = world.spawn(.forgedSoldier, x: 580, facing: -1, spec: still(.forgedSoldier))
    _ = world.spawn(.forgedSoldier, x: 620, facing: -1, spec: still(.forgedSoldier))
    let events = run(&world, frames: 10)
    #expect(events.contains { if case .decoyPlaced = $0 { true } else { false } })
}
