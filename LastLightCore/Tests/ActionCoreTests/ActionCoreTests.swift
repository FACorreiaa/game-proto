import LastLightCore
import Testing
@testable import ActionCore

/// Attacks on the frames listed, counting from its first frame alive. Stands still otherwise.
private struct ScriptBrain: Brain {
    var attackOn: Set<Int>

    func think(me: inout Fighter, foes: [Fighter], tuning: Tuning, rng: inout SeededRandom) -> InputFrame {
        defer { me.aiAux += 1 }
        return InputFrame(attack: attackOn.contains(me.aiAux))
    }
}

private func spec(_ kind: FighterKind, brain: (any Brain)? = nil) -> FighterSpec {
    var s = Tuning().spec(for: kind)
    s.brain = brain
    return s
}

/// A world holding Caelen, controlled, and nothing else.
private func duel(heroX: Double = 330) -> (World, hero: Int) {
    var world = World(seed: 1)
    let hero = world.spawn(.caelen, x: heroX, facing: 1)
    world.control(hero)
    return (world, hero)
}

/// Steps the world, applying each input on the frame it is keyed by.
private func run(_ world: inout World, frames: Int, inputs: [Int: InputFrame] = [:]) -> [GameEvent] {
    var events: [GameEvent] = []
    for f in 0..<frames {
        events += world.step(inputs[f] ?? .neutral)
    }
    return events
}

private let attack = InputFrame(attack: true)

private func hits(on id: Int, in events: [GameEvent]) -> [Double] {
    events.compactMap { if case .hit(_, id, let damage, _) = $0 { damage } else { nil } }
}

@Test func sameSeedAndInputsGiveTheSameGame() {
    func play() -> ([GameEvent], [Vec2]) {
        var world = World.feelSlice(seed: 7)
        var events: [GameEvent] = []
        for f in 0..<2400 {
            var inp = InputFrame(moveX: (f / 90) % 2 == 0 ? 1 : -1)
            inp.attack = f % 23 == 0
            inp.dodge = f % 131 == 0
            inp.jump = f % 97 == 0
            events += world.step(inp)
        }
        return (events, world.fighters.map(\.pos))
    }
    let a = play(), b = play()
    #expect(a.0 == b.0)
    #expect(a.1 == b.1)
    #expect(a.0.contains { if case .waveStarted = $0 { true } else { false } })
}

@Test func aSwingHitsATargetOnlyOnce() {
    var (world, _) = duel(heroX: 300)
    let dummy = world.spawn(.dummy, x: 360)
    let events = run(&world, frames: 40, inputs: [0: attack])
    #expect(hits(on: dummy, in: events) == [10])
}

@Test func threePressesChainThreeSwings() {
    var (world, hero) = duel()
    let events = run(&world, frames: 90, inputs: [0: attack, 8: attack, 16: attack])
    let swings = events.compactMap { if case .swing(hero, let i) = $0 { i } else { nil } }
    #expect(swings == [0, 1, 2])
    #expect(world.fighter(hero)?.state == .idle)
}

@Test func anUndodgedSlashHurtsAndGrantsBriefSafety() {
    var (world, hero) = duel()
    world.spawn(.forgedSoldier, x: 400, facing: -1, spec: spec(.forgedSoldier, brain: ScriptBrain(attackOn: [0])))
    let events = run(&world, frames: 32)
    #expect(hits(on: hero, in: events) == [18])
    #expect(world.fighter(hero)?.hp == 82)
    #expect((world.fighter(hero)?.invulnerable ?? 0) > 0)
}

@Test func dodgingThroughASlashAvoidsIt() {
    var (world, hero) = duel()
    world.spawn(.forgedSoldier, x: 400, facing: -1, spec: spec(.forgedSoldier, brain: ScriptBrain(attackOn: [0])))
    let events = run(&world, frames: 60, inputs: [27: InputFrame(dodge: true)])
    #expect(events.contains(.evaded(id: hero)))
    #expect(world.fighter(hero)?.hp == 100)
}

@Test func dodgeHasACooldown() {
    var (world, hero) = duel()
    let events = run(&world, frames: 30, inputs: [0: InputFrame(dodge: true), 18: InputFrame(dodge: true)])
    #expect(events.filter { $0 == .dodged(id: hero) }.count == 1)
}

@Test func swingingJustBeforeAHitLandsParriesIt() {
    var (world, hero) = duel()
    let soldier = world.spawn(
        .forgedSoldier, x: 400, facing: -1, spec: spec(.forgedSoldier, brain: ScriptBrain(attackOn: [0])))
    let events = run(&world, frames: 32, inputs: [27: attack])
    #expect(events.contains { if case .parried(hero, soldier, _) = $0 { true } else { false } })
    #expect(world.fighter(hero)?.hp == 100)
    #expect(world.fighter(soldier)?.state == .staggered)
}

@Test func aStaggeredEnemyTakesExtraDamage() {
    var (world, hero) = duel()
    let soldier = world.spawn(
        .forgedSoldier, x: 400, facing: -1, spec: spec(.forgedSoldier, brain: ScriptBrain(attackOn: [0])))
    // Parry with the first swing, then land the second on the staggered soldier.
    let events = run(&world, frames: 60, inputs: [27: attack, 36: attack])
    #expect(hits(on: soldier, in: events).contains(18))
    _ = hero
}

@Test func theShieldBlocksTheFrontButNotTheBack() {
    var (front, _) = duel(heroX: 330)
    let guarded = front.spawn(.forgedSoldier, x: 400, facing: -1, spec: spec(.forgedSoldier))
    let frontEvents = run(&front, frames: 30, inputs: [0: attack])
    #expect(frontEvents.contains { if case .blocked(_, guarded, _) = $0 { true } else { false } })
    #expect(front.fighter(guarded)?.hp == 90)

    var (back, _) = duel(heroX: 330)
    let exposed = back.spawn(.forgedSoldier, x: 400, facing: 1, spec: spec(.forgedSoldier))
    let backEvents = run(&back, frames: 30, inputs: [0: attack])
    #expect(hits(on: exposed, in: backEvents) == [10])
}

@Test func aWoundedDroneLightsItsFuseAndExplodes() {
    var (world, hero) = duel()
    let drone = world.spawn(.scrapDrone, x: 390, facing: -1, spec: spec(.scrapDrone))
    let events = run(&world, frames: 140, inputs: [0: attack, 8: attack])
    #expect(events.contains(.fuseLit(id: drone)))
    #expect(events.contains { if case .exploded(drone, _, _) = $0 { true } else { false } })
    #expect(world.fighter(hero)?.hp == 84)
}

@Test func killingADroneBeforeTheFuseEndsPreventsTheBlast() {
    var (world, hero) = duel()
    let drone = world.spawn(.scrapDrone, x: 390, facing: -1, spec: spec(.scrapDrone))
    let events = run(&world, frames: 140, inputs: [0: attack, 8: attack, 18: attack])
    #expect(events.contains(.fuseLit(id: drone)))
    #expect(events.contains(.died(id: drone)))
    #expect(!events.contains { if case .exploded = $0 { true } else { false } })
    #expect(world.fighter(hero)?.hp == 100)
}

@Test func holdingJumpGoesHigherThanTappingIt() {
    func peak(held: Bool) -> Double {
        var (world, hero) = duel()
        var top = 0.0
        for f in 0..<90 {
            _ = world.step(InputFrame(jump: f == 0, jumpHeld: held))
            top = max(top, world.fighter(hero)!.pos.y)
        }
        #expect(world.fighter(hero)!.onGround)
        return top
    }
    let tap = peak(held: false), hold = peak(held: true)
    #expect(tap > 20)
    #expect(hold > tap * 1.5)
}

@Test func wavesStartClearAndHeal() {
    var world = World.feelSlice(seed: 3)
    var events = run(&world, frames: 260)
    #expect(events.contains(.waveStarted(number: 1)))
    #expect(world.fighters.filter { $0.kind == .scrapDrone }.count == 2)

    let hero = world.controlledID
    world.fighters[world.fighters.firstIndex { $0.id == hero }!].hp = 50
    world.fighters.removeAll { $0.kind == .scrapDrone }
    events = run(&world, frames: 2)
    #expect(events.contains(.waveCleared(number: 1)))
    #expect(world.fighter(hero)?.hp == 70)
}

@Test func theGameEndsWhenTheHeroFalls() {
    var (world, hero) = duel()
    world.spawn(.forgedSoldier, x: 400, facing: -1, spec: spec(.forgedSoldier, brain: ScriptBrain(attackOn: [0])))
    world.fighters[0].hp = 5
    let events = run(&world, frames: 40)
    #expect(events.contains(.heroDown))
    #expect(world.isOver)
    #expect(world.fighter(hero)?.state == .dead)
    #expect(world.step(attack).isEmpty)
}

@Test func enemiesHuntAnIdleHero() {
    var world = World.feelSlice(seed: 11)
    let hero = world.controlledID
    let events = run(&world, frames: 1500)
    #expect(!hits(on: hero, in: events).isEmpty)
}
