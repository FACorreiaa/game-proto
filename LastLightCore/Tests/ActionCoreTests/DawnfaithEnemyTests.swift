@testable import ActionCore
import Testing

private func run(_ world: inout World, frames: Int, input: InputFrame = .neutral) -> [GameEvent] {
    var events: [GameEvent] = []
    for _ in 0..<frames { events += world.step(input) }
    return events
}

/// A flat room with Caelen at `heroX`, facing right, too tough to fall.
private func room(heroX: Double = 400) -> World {
    var world = World(seed: 1)
    var spec = Tuning().caelen
    spec.maxHP = 100_000
    world.control(world.spawn(.caelen, x: heroX, facing: 1, spec: spec))
    return world
}

private func still(_ kind: FighterKind) -> FighterSpec {
    var spec = Tuning().spec(for: kind)
    spec.brain = nil
    return spec
}

private func index(_ world: World, _ id: Int) -> Int { world.fighters.firstIndex { $0.id == id }! }

private func attack(_ world: inout World, _ id: Int, _ which: Int = 0) {
    let i = index(world, id)
    world.fighters[i].nextAttack = which
    world.fighters[i].attackBuffer = 3
}

private func heroSwings(_ world: inout World) -> [GameEvent] {
    let h = index(world, world.controlledID)
    world.fighters[h].attackBuffer = 3
    return run(&world, frames: 30)
}

// MARK: Zealot

@Test func aZealotCutsThreeTimesInOneFlurry() {
    var world = room()
    let zealot = world.spawn(.zealot, x: 520, facing: -1)
    var cuts: [Int] = []
    for _ in 0..<240 {
        for e in world.step(.neutral) { if case .swing(let id, let i) = e, id == zealot { cuts.append(i) } }
        if cuts.count >= 3 { break }
    }
    #expect(cuts.prefix(3) == [0, 1, 2])
}

@Test func aHurtZealotPressesHarder() {
    func flurries(hurt: Bool) -> Int {
        var world = room()
        let zealot = world.spawn(.zealot, x: 520, facing: -1)
        if hurt { world.fighters[index(world, zealot)].hp = 10 }
        return run(&world, frames: 900).filter { if case .swing(let id, 0) = $0 { id == zealot } else { false } }.count
    }
    #expect(flurries(hurt: true) > flurries(hurt: false))
}

// MARK: Radiant Acolyte

@Test func anAcolyteMendsHurtAlliesInReachButNotItself() {
    var world = room(heroX: 100)
    let acolyte = world.spawn(.radiantAcolyte, x: 700, facing: -1, spec: still(.radiantAcolyte))
    let near = world.spawn(.zealot, x: 900, facing: -1, spec: still(.zealot))
    let far = world.spawn(.zealot, x: 1400, facing: -1, spec: still(.zealot))
    for id in [acolyte, near, far] { world.fighters[index(world, id)].hp = 10 }
    attack(&world, acolyte, AcolyteBrain.mend)
    let events = run(&world, frames: 80)
    let healed = events.compactMap { if case .healed(let id, _) = $0 { id } else { nil } }
    #expect(healed == [near])
    #expect(world.fighter(near)!.hp > 10)
    #expect(world.fighter(far)!.hp == 10)
    #expect(world.fighter(acolyte)!.hp == 10)
}

@Test func anAcolyteCallsLightDownWhenNoOneNeedsMending() {
    var world = room(heroX: 400)
    _ = world.spawn(.radiantAcolyte, x: 720, facing: -1)
    let events = run(&world, frames: 200)
    #expect(events.contains { if case .lobbed(_, .light, _) = $0 { true } else { false } })
    #expect(!events.contains { if case .healed = $0 { true } else { false } })
}

// MARK: Solar Guard

@Test func aSolarGuardAnswersABlowOnItsShieldWithABash() {
    var world = room(heroX: 400)
    let guardID = world.spawn(.solarGuard, x: 500, facing: -1, spec: still(.solarGuard))
    let events = heroSwings(&world)
    #expect(events.contains { if case .blocked(_, let t, _) = $0 { t == guardID } else { false } })
    #expect(events.contains { if case .swing(let id, 1) = $0 { id == guardID } else { false } })
    #expect(world.fighter(guardID)!.hp == world.fighter(guardID)!.spec.maxHP)
}

@Test func fromBehindASolarGuardIsHurtAndDoesNotAnswer() {
    var world = room(heroX: 400)
    let guardID = world.spawn(.solarGuard, x: 500, facing: 1, spec: still(.solarGuard))
    let events = heroSwings(&world)
    #expect(world.fighter(guardID)!.hp < world.fighter(guardID)!.spec.maxHP)
    #expect(!events.contains { if case .swing(let id, _) = $0 { id == guardID } else { false } })
}

// MARK: Halo Disciple

@Test func aFlareDazesOnlyTheHeroLookingAtIt() {
    for facing in [1.0, -1.0] {
        var world = room(heroX: 400)
        let h = index(world, world.controlledID)
        world.fighters[h].facing = facing
        let disciple = world.spawn(.haloDisciple, x: 600, y: 150, facing: -1, spec: still(.haloDisciple))
        attack(&world, disciple, DiscipleBrain.flare)
        let events = run(&world, frames: 70)
        #expect(events.contains { if case .flared = $0 { true } else { false } })
        let dazed = events.contains { if case .dazed(let id) = $0 { id == world.controlledID } else { false } }
        #expect(dazed == (facing > 0), "facing \(facing)")
    }
}

@Test func aDodgeThroughTheFlareIsNotDazed() {
    var world = room(heroX: 400)
    let disciple = world.spawn(.haloDisciple, x: 600, y: 150, facing: -1, spec: still(.haloDisciple))
    attack(&world, disciple, DiscipleBrain.flare)
    let windup = world.fighter(disciple)!.spec.attacks[DiscipleBrain.flare].windup
    _ = run(&world, frames: windup - 4)
    let events = run(&world, frames: 20, input: InputFrame(moveX: 1, dodge: true))
    #expect(!events.contains { if case .dazed = $0 { true } else { false } })
}

@Test func aHaloDiscipleStaysAloft() {
    var world = room(heroX: 100)
    let disciple = world.spawn(.haloDisciple, x: 600, y: 150, facing: -1)
    _ = run(&world, frames: 300)
    #expect(world.fighter(disciple)!.pos.y == 150)
}
