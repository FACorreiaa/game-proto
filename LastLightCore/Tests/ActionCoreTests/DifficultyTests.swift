@testable import ActionCore
import Testing

/// The first damage the hero takes from a soldier, in a room where the hero stands still.
private func firstHeroDamage(scale: Double) -> Double? {
    var tuning = Tuning()
    tuning.heroDamageScale = scale
    var world = World(tuning: tuning, seed: 3)
    let hero = world.spawn(.caelen, x: 400, facing: 1)
    world.control(hero)
    _ = world.spawn(.forgedSoldier, x: 470, facing: -1)
    for _ in 0..<900 {
        for event in world.step(.neutral) {
            if case .hit(_, let target, let damage, _) = event, target == hero { return damage }
        }
    }
    return nil
}

@Test func difficultyScalesDamageTakenByHeroes() throws {
    let normal = try #require(firstHeroDamage(scale: 1))
    let story = try #require(firstHeroDamage(scale: 0.5))
    #expect(abs(story - normal * 0.5) < 0.0001)
}

@Test func difficultyLeavesDamageDealtByHeroesAlone() {
    for scale in [0.5, 1.5] {
        var tuning = Tuning()
        tuning.heroDamageScale = scale
        var world = World(tuning: tuning, seed: 1)
        world.control(world.spawn(.caelen, x: 400, facing: 1))
        var spec = Tuning().spec(for: .dummy)
        spec.brain = nil
        let dummy = world.spawn(.dummy, x: 450, facing: -1, spec: spec)
        var press = InputFrame()
        press.attack = true
        var dealt: Double?
        var events = world.step(press)
        for _ in 0..<60 where dealt == nil {
            events += world.step(.neutral)
            for event in events {
                if case .hit(_, let target, let damage, _) = event, target == dummy { dealt = damage }
            }
        }
        #expect(dealt == Tuning().spec(for: .caelen).attacks[0].damage)
    }
}
