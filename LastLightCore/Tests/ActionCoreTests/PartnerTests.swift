import LastLightCore
import Testing
@testable import ActionCore

private func run(_ world: inout World, frames: Int, inputs: [Int: InputFrame] = [:]) -> [GameEvent] {
    var events: [GameEvent] = []
    for f in 0..<frames {
        events += world.step(inputs[f] ?? .neutral)
    }
    return events
}

private func id(_ kind: FighterKind, in world: World) -> Int {
    world.fighters.first { $0.kind == kind }!.id
}

private let switchPress = InputFrame(switchHero: true)

@Test func switchingHandsControlToTheOtherHero() {
    var world = World.partnerSlice(seed: 5)
    let caelen = id(.caelen, in: world), orion = id(.orion, in: world)
    #expect(world.controlledID == caelen)
    let events = run(&world, frames: 3, inputs: [0: switchPress])
    #expect(events.contains(.controlChanged(id: orion)))
    #expect(world.controlledID == orion)
}

@Test func switchingHasAShortCooldown() {
    var world = World.partnerSlice(seed: 5)
    let orion = id(.orion, in: world)
    _ = run(&world, frames: 6, inputs: [0: switchPress, 3: switchPress])
    #expect(world.controlledID == orion)
    _ = run(&world, frames: 30, inputs: [25: switchPress])
    #expect(world.controlledID == id(.caelen, in: world))
}

@Test func thePartnerFollowsAnIdleLeader() {
    var world = World(seed: 2)
    let caelen = world.spawn(.caelen, x: 900, facing: 1)
    let orion = world.spawn(.orion, x: 200, facing: 1)
    world.control(caelen)
    _ = run(&world, frames: 240)
    let gap = abs(world.fighter(orion)!.pos.x - world.fighter(caelen)!.pos.x)
    #expect(gap < 140)
}

@Test func thePartnerFightsAndHitsSofterThanThePlayerWould() {
    var world = World(seed: 2)
    let caelen = world.spawn(.caelen, x: 300, facing: 1)
    let orion = world.spawn(.orion, x: 380, facing: 1)
    var dummySpec = Tuning().dummy
    dummySpec.immortal = false
    dummySpec.maxHP = 500
    let target = world.spawn(.dummy, x: 470, spec: dummySpec)
    world.control(caelen)
    let events = run(&world, frames: 240)
    let damages = events.compactMap { if case .hit(orion, target, let d, _) = $0 { d } else { nil } }
    #expect(!damages.isEmpty)
    // Orion's swings do 7 and 11 in the player's hands; under AI they are scaled by 0.6.
    #expect(damages.allSatisfy { abs($0 - 4.2) < 0.001 || abs($0 - 6.6) < 0.001 })
}

@Test func controlPassesWhenTheControlledHeroFalls() {
    var world = World.partnerSlice(seed: 5)
    let caelen = id(.caelen, in: world), orion = id(.orion, in: world)
    world.fighters[world.fighters.firstIndex { $0.id == caelen }!].hp = 0
    world.fighters[world.fighters.firstIndex { $0.id == caelen }!].enter(.dead)
    let events = run(&world, frames: 2)
    #expect(events.contains(.controlChanged(id: orion)))
    #expect(!world.isOver)
}

@Test func theGameEndsOnlyWhenBothHeroesAreDown() {
    var world = World.partnerSlice(seed: 5)
    for i in world.fighters.indices where world.fighters[i].team == .hero {
        world.fighters[i].hp = 0
        world.fighters[i].enter(.dead)
    }
    let events = run(&world, frames: 2)
    #expect(events.contains(.heroDown))
    #expect(world.isOver)
}

@Test func aFallenHeroGetsUpWhenTheWaveIsCleared() {
    var world = World.partnerSlice(seed: 5)
    _ = run(&world, frames: 260)
    let orion = id(.orion, in: world)
    let i = world.fighters.firstIndex { $0.id == orion }!
    world.fighters[i].hp = 0
    world.fighters[i].enter(.dead)
    world.fighters.removeAll { $0.kind == .scrapDrone }
    let events = run(&world, frames: 2)
    #expect(events.contains(.revived(id: orion)))
    #expect(world.fighter(orion)?.hp == 36)
    #expect(world.fighter(orion)?.isAlive == true)
}

/// A leader who stands still and cannot be worn down, so the outcome is the partner's work.
private func stoicLeader() -> FighterSpec {
    var spec = Tuning().caelen
    spec.maxHP = 100_000
    return spec
}

@Test func thePartnerClearsDronesOnItsOwn() {
    for seed in 1...5 {
        var world = World(seed: UInt64(seed))
        world.control(world.spawn(.caelen, x: 300, facing: 1, spec: stoicLeader()))
        world.spawn(.orion, x: 380, facing: 1)
        world.spawn(.scrapDrone, x: 800)
        world.spawn(.scrapDrone, x: 900)
        _ = run(&world, frames: 3600)
        #expect(!world.fighters.contains { $0.team == .enemy && $0.isAlive }, "seed \(seed)")
        #expect(world.fighters.contains { $0.kind == .orion && $0.isAlive }, "seed \(seed)")
    }
}

@Test func thePartnerPunishesAShieldedSoldierThatIsBusyWithTheLeader() {
    for seed in 1...5 {
        var world = World(seed: UInt64(seed))
        world.control(world.spawn(.caelen, x: 300, facing: 1, spec: stoicLeader()))
        let orion = world.spawn(.orion, x: 250, facing: 1)
        let soldier = world.spawn(.forgedSoldier, x: 520)
        let events = run(&world, frames: 5400)
        #expect(world.fighter(soldier)?.isAlive != true, "seed \(seed)")
        // It waits for openings rather than hammering the shield.
        let blocked = events.filter { if case .blocked(orion, _, _) = $0 { true } else { false } }.count
        #expect(blocked <= 3, "seed \(seed): \(blocked) blocked hits")
    }
}

@Test func thePartnerSliceIsDeterministic() {
    func play() -> [GameEvent] {
        var world = World.partnerSlice(seed: 9)
        var events: [GameEvent] = []
        for f in 0..<3000 {
            events += world.step(InputFrame(
                moveX: (f / 80) % 2 == 0 ? 1 : -1, attack: f % 19 == 0, dodge: f % 113 == 0,
                switchHero: f % 400 == 399))
        }
        return events
    }
    #expect(play() == play())
}
