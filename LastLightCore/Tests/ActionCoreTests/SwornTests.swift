@testable import ActionCore
import LastLightCore
import Testing

private func run(_ world: inout World, frames: Int, input: InputFrame = .neutral) -> [GameEvent] {
    var events: [GameEvent] = []
    for _ in 0..<frames { events += world.step(input) }
    return events
}

private func index(_ world: World, _ id: Int) -> Int { world.fighters.firstIndex { $0.id == id }! }

private func fell(_ world: inout World, _ id: Int) {
    let i = index(world, id)
    world.fighters[i].hp = 0
    world.fighters[i].enter(.dead)
}

/// A world in the Cloister Gate with both of the pair awake and the hero kept out of their way.
private func awakePair() -> World {
    var world = World(level: .cloisterGate, hero: .caelen, seed: 1)
    let h = index(world, world.controlledID)
    world.fighters[h].pos.x = 900
    _ = run(&world, frames: 2)
    world.fighters[index(world, world.controlledID)].pos.x = -150
    return world
}

@Test func theSwornWakeTogether() {
    var world = World(level: .cloisterGate, hero: .caelen, seed: 1)
    let h = index(world, world.controlledID)
    // Close to the Shield, too far from the Spear to wake it alone.
    world.fighters[h].pos.x = 900
    let events = run(&world, frames: 2)
    #expect(world.boss?.awake == true)
    #expect(world.twin?.awake == true)
    #expect(events.contains(.scene(id: "sworn.wake")))
}

@Test func oneOfThePairDownAloneIsRaisedByTheOther() {
    var world = awakePair()
    let spear = world.twinID!
    fell(&world, spear)
    var events = run(&world, frames: world.tuning.swornRiseFrames - 2)
    #expect(world.twin?.isAlive == false)
    events += run(&world, frames: 3)
    let raised = world.twin!
    #expect(raised.isAlive)
    #expect(raised.hp == raised.spec.maxHP * world.tuning.swornRiseShare)
    #expect(events.contains(.raised(id: spear, by: world.bossID!)))
    #expect(events.contains(.scene(id: "sworn.raised")))
    #expect(!events.contains { if case .bossDefeated = $0 { true } else { false } })
    #expect(!world.isComplete)
}

@Test func bothDownWithinTheVowEndsTheFight() {
    var world = awakePair()
    fell(&world, world.twinID!)
    _ = run(&world, frames: world.tuning.swornRiseFrames / 2)
    fell(&world, world.bossID!)
    _ = run(&world, frames: world.tuning.bossVictoryFrames + world.tuning.swornRiseFrames)
    #expect(world.isComplete)
    #expect(world.twin?.isAlive == false)
}

@Test func onlyTheLastOfThePairToFallCountsAsTheBossDefeated() {
    var world = World(level: .cloisterGate, hero: .caelen, seed: 1)
    let first = world.swornPartner(of: world.bossID!)
    #expect(first == world.twinID)
    #expect(world.swornPartner(of: world.twinID!) == world.bossID)
    #expect(world.swornPartner(of: world.controlledID) == nil)
}

@Test func aSwornOneFightsFasterWithTheOtherDown() {
    let tuning = Tuning()
    let world = World(level: .cloisterGate, hero: .caelen, seed: 1)
    let hero = world.controlled!
    let partner = world.boss!
    var gaps: [Bool: Int] = [:]
    for partnerUp in [true, false] {
        var me = world.twin!
        me.awake = true
        me.pos.x = hero.pos.x + 160
        var rng = SeededRandom(seed: 7)
        _ = SwornSpearBrain().think(me: &me, foes: [hero], allies: partnerUp ? [me, partner] : [me], tuning: tuning, rng: &rng)
        gaps[partnerUp] = me.aiCooldown
    }
    #expect(gaps[false]! > 0)
    #expect(gaps[false]! < gaps[true]!)
}

// MARK: Bells

/// Rings the bell at `x` with a swing from whoever stands there.
private func ring(_ world: inout World, x: Double, by id: Int? = nil) -> [GameEvent] {
    let h = index(world, id ?? world.controlledID)
    world.fighters[h].pos.x = x - 30
    world.fighters[h].facing = 1
    world.fighters[h].attackBuffer = 3
    return run(&world, frames: 24)
}

@Test func bellsRungInTheOrderOfTheHoursOpenTheGate() {
    var world = World(level: .bellTower, hero: .caelen, seed: 1)
    let gate = world.level!.gates.first { $0.id == 10 }!
    _ = ring(&world, x: 680)
    _ = ring(&world, x: 480)
    _ = ring(&world, x: 880)
    #expect(world.signals.isSuperset(of: [1, 2, 3]))
    #expect(world.wantsOpen(gate))
}

@Test func aBellRungOutOfTurnSilencesTheRest() {
    var world = World(level: .bellTower, hero: .caelen, seed: 1)
    _ = ring(&world, x: 680)
    #expect(world.signals.contains(1))
    let events = ring(&world, x: 880)
    #expect(events.contains(.discord(gate: 10)))
    #expect(events.contains(.lever(id: 1, on: false)))
    #expect(world.signals.isDisjoint(with: [1, 2, 3]))
}

@Test func onlyTheLeadRingsABell() {
    var world = World(level: .bellTower, hero: .caelen, seed: 1)
    let orion = world.fighters.first { $0.kind == .orion }!.id
    let o = index(world, orion)
    world.fighters[o].awake = true
    _ = ring(&world, x: 680, by: orion)
    #expect(!world.signals.contains(1))
}

@Test func theLastBellsFallSilentOnTheirOwn() {
    var world = World(level: .bellTower, hero: .caelen, seed: 1)
    _ = ring(&world, x: 3300)
    #expect(world.signals.contains(8))
    // Hit-stop pauses the clock, so allow for the fight nearby.
    _ = run(&world, frames: 600)
    #expect(!world.signals.contains(8))
}

// MARK: The levels in play

@Test func chapterThreeRunsRoadBellsCloisterGateStairTerrace() {
    #expect(Chapter.dawnfaith.levels(for: .caelen).map(\.name) == [
        "The Pilgrim Road", "The Bell Tower", "The Sun Cloister", "The Cloister Gate", "The Choir Stair",
        "The Oracle's Terrace",
    ])
}

@Test func theBellTowerCanBeSolvedByEveryLead() {
    for fights in [false, true] {
        for lead in [FighterKind.caelen, .seraphine, .nimue] {
            var world = World(level: .bellTower, hero: lead, seed: 1)
            var pilot = Autopilot(fights: fights)
            var opened: Set<Int> = []
            while !world.isOver, world.frame < 60 * 180 {
                for e in world.step(pilot.input(for: world)) {
                    if case .gate(let id, true) = e { opened.insert(id) }
                }
            }
            #expect(world.isComplete, "\(lead) fights: \(fights) frame \(world.frame) x \(world.controlled?.pos.x ?? -1)")
            #expect(opened.isSuperset(of: [10, 11, 12]), "\(lead) fights: \(fights)")
        }
    }
}

@Test func everyLeadCanBeatTheSworn() {
    for lead in [FighterKind.caelen, .seraphine, .nimue] {
        var won = 0
        for seed in UInt64(1)...4 {
            var world = World(level: .cloisterGate, hero: lead, seed: seed)
            var pilot = Autopilot(fights: true)
            var raised = 0
            while !world.isOver, world.frame < 60 * 240 {
                for e in world.step(pilot.input(for: world)) { if case .raised = e { raised += 1 } }
            }
            print("SWORN \(lead) seed \(seed) complete \(world.isComplete) secs \(world.frame / 60) raised \(raised)",
                  "hp \(Int(world.boss!.hp))/\(Int(world.twin!.hp))")
            if world.isComplete { won += 1 }
        }
        #expect(won >= 2, "\(lead)")
    }
}
