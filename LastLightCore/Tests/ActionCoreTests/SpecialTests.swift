@testable import ActionCore
import Testing

private func run(_ world: inout World, frames: Int, input: InputFrame = .neutral) -> [GameEvent] {
    var events: [GameEvent] = []
    for _ in 0..<frames { events += world.step(input) }
    return events
}

/// A flat room with one hero under the player's hand at x 400, facing right.
private func room(_ hero: FighterKind) -> World {
    var world = World(seed: 1)
    world.control(world.spawn(hero, x: 400, facing: 1))
    return world
}

/// An enemy that stands still and does nothing unless a test makes it.
private func still(_ kind: FighterKind) -> FighterSpec {
    var spec = Tuning().spec(for: kind)
    spec.brain = nil
    return spec
}

private func index(_ world: World, _ id: Int) -> Int { world.fighters.firstIndex { $0.id == id }! }

private func damage(to id: Int, in events: [GameEvent]) -> [Double] {
    events.compactMap { if case .hit(_, let target, let damage, _) = $0, target == id { damage } else { nil } }
}

// MARK: Command

@Test func commandMarksTheNearestEnemyInFront() {
    var world = room(.caelen)
    let behind = world.spawn(.forgedSoldier, x: 300, spec: still(.forgedSoldier))
    let near = world.spawn(.forgedSoldier, x: 600, spec: still(.forgedSoldier))
    let far = world.spawn(.forgedSoldier, x: 800, spec: still(.forgedSoldier))
    let events = run(&world, frames: 2, input: InputFrame(special: true))
    #expect(events.contains(.commanded(by: world.controlledID, target: near)))
    #expect(world.fighter(near)!.markedFrames > 0)
    #expect(world.fighter(behind)!.markedFrames == 0)
    #expect(world.fighter(far)!.markedFrames == 0)
}

@Test func commandIsNotSpentWhenNobodyIsThere() {
    var world = room(.caelen)
    let events = run(&world, frames: 5, input: InputFrame(special: true))
    #expect(!events.contains { if case .commanded = $0 { true } else { false } })
    #expect(world.controlled!.specialCooldown == 0)
}

@Test func aMarkedEnemyTakesMoreDamageUntilTheMarkRunsOut() {
    func firstHit(marked: Bool, wait: Int = 0) -> Double {
        var world = room(.caelen)
        var spec = still(.forgedSoldier)
        spec.frontalBlock = false
        let foe = world.spawn(.forgedSoldier, x: 470, spec: spec)
        if marked { _ = run(&world, frames: 2, input: InputFrame(special: true)) }
        _ = run(&world, frames: wait)
        return damage(to: foe, in: run(&world, frames: 12, input: InputFrame(attack: true))).first ?? 0
    }
    let plain = firstHit(marked: false)
    #expect(plain > 0)
    #expect(firstHit(marked: true) == plain * 1.4)
    #expect(firstHit(marked: true, wait: 430) == plain)
}

@Test func commandCannotBeUsedAgainUntilItHasCooledDown() {
    var world = room(.caelen)
    let first = world.spawn(.forgedSoldier, x: 600, spec: still(.forgedSoldier))
    _ = run(&world, frames: 2, input: InputFrame(special: true))
    #expect(world.controlled!.specialCooldown > 500)
    world.fighters[index(world, first)].markedFrames = 0
    let again = run(&world, frames: 30, input: InputFrame(special: true))
    #expect(!again.contains { if case .commanded = $0 { true } else { false } })
}

@Test func thePartnerGoesForTheMarkedEnemyRatherThanTheNearest() {
    var world = room(.caelen)
    let orion = world.spawn(.orion, x: 380, facing: 1)
    var soft = still(.forgedSoldier)
    soft.frontalBlock = false
    let nearLeft = world.spawn(.forgedSoldier, x: 250, spec: soft)
    let marked = world.spawn(.forgedSoldier, x: 640, spec: soft)
    world.fighters[index(world, marked)].markedFrames = 100_000
    world.fighters[index(world, marked)].markScale = 1
    let events = run(&world, frames: 240)
    #expect(!damage(to: marked, in: events).isEmpty)
    #expect(damage(to: nearLeft, in: events).isEmpty)
    #expect(world.fighter(orion)!.pos.x > 450)
}

// MARK: Adapt

/// Orion at x 400 and a soldier in front of him about to swing.
private func duel() -> (World, Int) {
    var world = room(.orion)
    let foe = world.spawn(.forgedSoldier, x: 500, facing: -1, spec: still(.forgedSoldier))
    world.fighters[index(world, foe)].attackBuffer = 3
    return (world, foe)
}

@Test func adaptAbsorbsAHitStaggersTheAttackerAndCounters() {
    var (world, foe) = duel()
    let windup = world.fighter(foe)!.spec.attacks[0].windup
    _ = run(&world, frames: windup - 10)
    var events = run(&world, frames: 1, input: InputFrame(special: true))
    #expect(events.contains(.guarded(id: world.controlledID)))
    #expect(world.controlled!.state == .guardStance)
    events += run(&world, frames: 40)
    #expect(events.contains { if case .absorbed(let by, let attacker, _) = $0 { by == world.controlledID && attacker == foe } else { false } })
    #expect(world.controlled!.hp == world.controlled!.spec.maxHP)
    // The counter is the last swing of his chain, at more than double strength, on a staggered enemy.
    let orion = Tuning().orion
    let expected = orion.attacks.last!.damage * 2.2 * Tuning().staggerDamageBonus
    #expect(damage(to: foe, in: events) == [expected])
}

@Test func withoutAdaptTheSameHitHurts() {
    var (world, _) = duel()
    _ = run(&world, frames: 80)
    #expect(world.controlled!.hp < world.controlled!.spec.maxHP)
}

@Test func aGuardRaisedTooEarlyRunsOutAndTheHitLands() {
    var world = room(.orion)
    let foe = world.spawn(.forgedSoldier, x: 500, facing: -1, spec: still(.forgedSoldier))
    _ = run(&world, frames: 1, input: InputFrame(special: true))
    _ = run(&world, frames: 20)
    world.fighters[index(world, foe)].attackBuffer = 3
    let events = run(&world, frames: 80)
    #expect(!events.contains { if case .absorbed = $0 { true } else { false } })
    #expect(world.controlled!.hp < world.controlled!.spec.maxHP)
    #expect(world.controlled!.specialCooldown > 0)
}

@Test func adaptOpensTheProtocolsArmour() {
    var world = room(.orion)
    let spec = still(.theProtocol)
    let boss = world.spawn(.theProtocol, x: 520, facing: -1, spec: spec)
    world.fighters[index(world, boss)].nextAttack = 0
    world.fighters[index(world, boss)].attackBuffer = 3
    _ = run(&world, frames: spec.attacks[0].windup - 10)
    var events = run(&world, frames: 1, input: InputFrame(special: true))
    events += run(&world, frames: 40)
    #expect(events.contains { if case .absorbed = $0 { true } else { false } })
    #expect(!damage(to: boss, in: events).isEmpty)
    #expect(world.controlled!.hp == world.controlled!.spec.maxHP)
}

@Test func theAIPartnerSometimesGuardsInsteadOfDodging() {
    var guarded = 0
    for seed in 1...12 {
        var world = World(seed: UInt64(seed))
        world.control(world.spawn(.caelen, x: 100, facing: 1))
        let orion = world.spawn(.orion, x: 400, facing: 1)
        let foe = world.spawn(.forgedSoldier, x: 500, facing: -1, spec: still(.forgedSoldier))
        world.fighters[index(world, foe)].attackBuffer = 3
        if run(&world, frames: 60).contains(.guarded(id: orion)) { guarded += 1 }
    }
    #expect(guarded >= 2)
    #expect(guarded <= 10)
}
