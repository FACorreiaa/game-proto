@testable import ActionCore
import Testing

private func run(_ world: inout World, frames: Int, input: InputFrame = .neutral) -> [GameEvent] {
    var events: [GameEvent] = []
    for _ in 0..<frames { events += world.step(input) }
    return events
}

private func room(heroX: Double = 400) -> World {
    var world = World(seed: 1)
    world.control(world.spawn(.caelen, x: heroX, facing: 1))
    return world
}

private func still(_ kind: FighterKind) -> FighterSpec {
    var spec = Tuning().spec(for: kind)
    spec.brain = nil
    return spec
}

private func index(_ world: World, _ id: Int) -> Int { world.fighters.firstIndex { $0.id == id }! }

/// Makes a brainless fighter use one attack now.
private func attack(_ world: inout World, _ id: Int, _ which: Int = 0) {
    let i = index(world, id)
    world.fighters[i].nextAttack = which
    world.fighters[i].attackBuffer = 3
}

// MARK: Ratborn

@Test func theRatbornBitesThenBacksOff() {
    var world = room()
    let rat = world.spawn(.ratborn, x: 700, facing: -1)
    var closest = 1000.0, bit = false, after = 0.0
    for _ in 0..<600 {
        let events = world.step(.neutral)
        let x = world.fighter(rat)!.pos.x
        if !bit { closest = min(closest, x) }
        if events.contains(where: { if case .hit(let by, _, _, _) = $0 { by == rat } else { false } }) { bit = true }
        if bit { after = max(after, x) }
        if bit, after > closest + 60 { break }
    }
    #expect(bit, "it should get a bite in")
    #expect(after > closest + 60, "after a bite it should back off")
}

// MARK: Lantern Gunner

@Test func theGunnersLanternLandsUnderTheHeroWarnsThenBurns() {
    var world = room()
    let gunner = world.spawn(.lanternGunner, x: 700, facing: -1, spec: still(.lanternGunner))
    attack(&world, gunner)
    let thrown = run(&world, frames: 40)
    let landed = thrown.compactMap { if case .lobbed(_, .fire, let at) = $0 { at } else { nil } }.first
    #expect(landed.map { abs($0.x - 400) < 1 } == true)
    let fire = try! #require(world.strikes.first)
    #expect(fire.kind == .fire && fire.isWarning)

    // Standing in it once it burns costs health; it catches a hero only once.
    let before = world.controlled!.hp
    _ = run(&world, frames: 120)
    #expect(world.controlled!.hp == before - Tuning().lanternGunner.attacks[0].effectDamage)
    #expect(world.strikes.isEmpty, "it burns out")
}

@Test func walkingOutOfTheWarningAvoidsTheFire() {
    var world = room()
    let gunner = world.spawn(.lanternGunner, x: 700, facing: -1, spec: still(.lanternGunner))
    attack(&world, gunner)
    _ = run(&world, frames: 40)
    let before = world.controlled!.hp
    _ = run(&world, frames: 150, input: InputFrame(moveX: -1))
    #expect(world.controlled!.hp == before)
}

@Test func theGunnerKeepsItsThrowingDistance() {
    var world = room()
    let gunner = world.spawn(.lanternGunner, x: 480)
    _ = run(&world, frames: 120)
    #expect(abs(world.fighter(gunner)!.pos.x - 400) >= Tuning().gunnerNear - 5)
}

// MARK: Smuggler Brute

@Test func theBrutesSlamHitsBothSides() {
    var world = room(heroX: 600)
    let brute = world.spawn(.smugglerBrute, x: 500, facing: -1, spec: still(.smugglerBrute))
    let other = world.spawn(.orion, x: 410, facing: 1)
    attack(&world, brute, 1)
    let events = run(&world, frames: 70)
    let struck = Set(events.compactMap { if case .hit(let by, let target, _, _) = $0, by == brute { target } else { nil } })
    #expect(struck == [world.controlledID, other], "the hero behind it and the one in front are both hit")
}

@Test func hittingTheBruteDoesNotStopItsSwing() {
    var world = room()
    let brute = world.spawn(.smugglerBrute, x: 470, facing: -1, spec: still(.smugglerBrute))
    attack(&world, brute, 0)
    _ = run(&world, frames: 4)
    world.fighters[index(world, world.controlledID)].attackBuffer = 3
    _ = run(&world, frames: 10)
    #expect(world.fighter(brute)!.hp < Tuning().smugglerBrute.maxHP, "the hero's hit lands")
    #expect(world.fighter(brute)!.currentAttack != nil, "but the swing carries on")
}

// MARK: Night Weaver

@Test func theNightWeaverSendsImagesThatBreakInOneHitAndFade() {
    var world = room()
    let weaver = world.spawn(.nightWeaver, x: 700, facing: -1, spec: still(.nightWeaver))
    attack(&world, weaver, 0)
    _ = run(&world, frames: 45)
    let images = world.fighters.filter { $0.kind == .weaverImage }
    #expect(images.count == 2)
    #expect(images.allSatisfy { $0.spec.maxHP == 1 })

    // Unbroken images fade on their own.
    var fading = world
    // Hit-stop pauses the count, so allow for some.
    let events = run(&fading, frames: Tuning().weaverImage.lifetime + 120)
    #expect(fading.fighters.allSatisfy { $0.kind != .weaverImage })
    #expect(events.filter { if case .faded = $0 { true } else { false } }.count >= 1)
}

@Test func theWeaverCallsNoMoreImagesThanItKeeps() {
    var world = room()
    let weaver = world.spawn(.nightWeaver, x: 700, facing: -1, spec: still(.nightWeaver))
    for _ in 0..<3 {
        attack(&world, weaver, 0)
        _ = run(&world, frames: 80)
    }
    #expect(world.fighters.filter { $0.kind == .weaverImage }.count <= Tuning().maxSummoned)
}

@Test func aSnareSlowsTheHeroWhoStepsInIt() {
    var world = room()
    let weaver = world.spawn(.nightWeaver, x: 700, facing: -1, spec: still(.nightWeaver))
    attack(&world, weaver, 1)
    let events = run(&world, frames: 70)
    #expect(world.strikes.first?.kind == .snare)
    #expect(events.contains(.slowed(id: world.controlledID)))
    _ = run(&world, frames: 10, input: InputFrame(moveX: 1))
    #expect(world.controlled!.vel.x == world.controlled!.spec.runSpeed * Tuning().slowFactor)
}

@Test func theWeaverAlternatesImagesAndSnares() {
    var world = room()
    _ = world.spawn(.nightWeaver, x: 700, facing: -1)
    let events = run(&world, frames: 60 * 12)
    #expect(events.contains { if case .spawned(_, .weaverImage) = $0 { true } else { false } })
    #expect(events.contains { if case .lobbed(_, .snare, _) = $0 { true } else { false } })
}

private extension AttackSpec {
    var effectDamage: Double { if case .lob(let lob) = effect { lob.damage } else { damage } }
}
