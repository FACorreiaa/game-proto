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

private func hits(on id: Int, in events: [GameEvent]) -> Int {
    events.filter { if case .hit(_, let target, _, _) = $0 { target == id } else { false } }.count
}

// MARK: Sentry Core

@Test func theSentryCoreFloatsWhereItWasPlaced() {
    var world = room()
    let sentry = world.spawn(.sentryCore, x: 900, y: 40, spec: still(.sentryCore))
    _ = run(&world, frames: 120)
    #expect(world.fighter(sentry)!.pos.y == 40)
}

@Test func theSentryCoreKeepsItsDistance() {
    var world = room()
    let sentry = world.spawn(.sentryCore, x: 480, y: 40)
    _ = run(&world, frames: 120)
    #expect(abs(world.fighter(sentry)!.pos.x - 400) >= Tuning().sentryNear - 5)

    var far = room()
    let other = far.spawn(.sentryCore, x: 1300, y: 40)
    _ = run(&far, frames: 300)
    #expect(abs(far.fighter(other)!.pos.x - 400) <= Tuning().sentryFar + 5)
}

@Test func itsBeamHurtsAndSlowsAHeroStandingInItsLine() {
    var world = room()
    let sentry = world.spawn(.sentryCore, x: 700, y: 40, facing: -1, spec: still(.sentryCore))
    world.fighters[index(world, sentry)].attackBuffer = 3
    let events = run(&world, frames: 70)
    #expect(hits(on: world.controlledID, in: events) == 1)
    #expect(events.contains(.slowed(id: world.controlledID)))

    // Slowed: half speed until it wears off.
    _ = run(&world, frames: 30, input: InputFrame(moveX: 1))
    #expect(world.controlled!.vel.x == world.controlled!.spec.runSpeed * Tuning().slowFactor)
    _ = run(&world, frames: 120, input: InputFrame(moveX: 1))
    #expect(world.controlled!.vel.x == world.controlled!.spec.runSpeed)
}

@Test func theBeamGivesWarningAndCanBeJumpedOrDodged() {
    #expect(Tuning().sentryCore.attacks[0].windup >= 45)
    for (early, answer) in [(12, InputFrame(jump: true, jumpHeld: true)), (4, InputFrame(moveX: 1, dodge: true))] {
        var world = room()
        let sentry = world.spawn(.sentryCore, x: 700, y: 40, facing: -1, spec: still(.sentryCore))
        world.fighters[index(world, sentry)].attackBuffer = 3
        _ = run(&world, frames: Tuning().sentryCore.attacks[0].windup - early)
        var events = run(&world, frames: 1, input: answer)
        events += run(&world, frames: 40, input: InputFrame(jumpHeld: true))
        #expect(hits(on: world.controlledID, in: events) == 0)
    }
}

@Test func aDestroyedSentryCoreDropsToTheFloor() {
    var world = room()
    let sentry = world.spawn(.sentryCore, x: 460, y: 40, spec: still(.sentryCore))
    var events: [GameEvent] = []
    for _ in 0..<200 where !events.contains(.died(id: sentry)) {
        events += world.step(InputFrame(attack: world.frame % 8 == 0))
    }
    #expect(events.contains(.died(id: sentry)))
    _ = run(&world, frames: 20)
    #expect((world.fighter(sentry)?.pos.y ?? 0) == 0)
}

// MARK: Dogma Frame

@Test func aMachineNearADogmaFrameCannotBeHurt() {
    var world = room()
    var soft = still(.forgedSoldier)
    soft.frontalBlock = false
    let soldier = world.spawn(.forgedSoldier, x: 470, spec: soft)
    _ = world.spawn(.dogmaFrame, x: 600, spec: still(.dogmaFrame))
    #expect(world.isWarded(soldier))
    let events = run(&world, frames: 40, input: InputFrame(attack: true))
    #expect(hits(on: soldier, in: events) == 0)
    #expect(events.contains { if case .blocked = $0 { true } else { false } })
}

@Test func theDogmaFrameItselfCanBeHurtAndItsShieldEndsWithIt() {
    var world = room()
    var soft = still(.forgedSoldier)
    soft.frontalBlock = false
    let frame = world.spawn(.dogmaFrame, x: 470, spec: still(.dogmaFrame))
    let soldier = world.spawn(.forgedSoldier, x: 600, spec: soft)
    #expect(!world.isWarded(frame))
    var events: [GameEvent] = []
    for _ in 0..<400 where !events.contains(.died(id: frame)) {
        events += world.step(InputFrame(attack: world.frame % 8 == 0))
    }
    #expect(events.contains(.died(id: frame)))
    #expect(!world.isWarded(soldier))
}

@Test func theShieldOnlyReachesSoFar() {
    var world = room()
    let soldier = world.spawn(.forgedSoldier, x: 470, spec: still(.forgedSoldier))
    _ = world.spawn(.dogmaFrame, x: 470 + Tuning().dogmaFrame.wardRadius + 40, spec: still(.dogmaFrame))
    #expect(!world.isWarded(soldier))
}

@Test func theDogmaFrameWalksAfterTheMachineItShields() {
    var world = room(heroX: 100)
    let soldier = world.spawn(.forgedSoldier, x: 1200, spec: still(.forgedSoldier))
    let frame = world.spawn(.dogmaFrame, x: 700)
    _ = run(&world, frames: 600)
    #expect(abs(world.fighter(frame)!.pos.x - world.fighter(soldier)!.pos.x) <= Tuning().dogmaFollowDistance + 5)
    #expect(Tuning().dogmaFrame.attacks.isEmpty)
}

@Test func thePartnerGoesForTheDogmaFrameFirst() {
    var world = room(heroX: 300)
    let orion = world.spawn(.orion, x: 340, facing: 1)
    let soldier = world.spawn(.forgedSoldier, x: 470, spec: still(.forgedSoldier))
    let frame = world.spawn(.dogmaFrame, x: 620, spec: still(.dogmaFrame))
    let events = run(&world, frames: 300)
    #expect(hits(on: frame, in: events) >= 1)
    #expect(hits(on: soldier, in: events) == 0)
    _ = orion
}

@Test func theProtocolIsNeverShieldedByADogmaFrame() {
    var world = room()
    let boss = world.spawn(.theProtocol, x: 600, spec: still(.theProtocol))
    _ = world.spawn(.dogmaFrame, x: 650, spec: still(.dogmaFrame))
    #expect(!world.isWarded(boss))
}
