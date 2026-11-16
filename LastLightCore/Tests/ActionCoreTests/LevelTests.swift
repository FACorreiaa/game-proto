@testable import ActionCore
import Testing

private func run(_ world: inout World, frames: Int, input: InputFrame = .neutral) -> [GameEvent] {
    var events: [GameEvent] = []
    for _ in 0..<frames { events += world.step(input) }
    return events
}

private func hero(_ world: World) -> Fighter { world.controlled! }

/// Flat ground from 0 to `width`, with whatever the test adds.
private func flat(width: Double = 2000, _ build: (inout Level) -> Void = { _ in }) -> Level {
    var level = Level(name: "test", width: width, start: Vec2(100, 0), exitX: width + 1000)
    level.ground(-200, width + 200)
    build(&level)
    return level
}

// MARK: Momentum

@Test func theHeroSpeedsUpAndSlowsDownInsteadOfSnapping() {
    var world = World(level: flat(), seed: 1)
    let top = hero(world).spec.runSpeed
    _ = run(&world, frames: 2, input: InputFrame(moveX: 1))
    #expect(hero(world).vel.x > 0)
    #expect(hero(world).vel.x < top)
    _ = run(&world, frames: 10, input: InputFrame(moveX: 1))
    #expect(hero(world).vel.x == top)
    _ = run(&world, frames: 2)
    #expect(hero(world).vel.x > 0)
    #expect(hero(world).vel.x < top)
    _ = run(&world, frames: 8)
    #expect(hero(world).vel.x == 0)
}

@Test func turningAroundIsQuickerThanStartingFromRest() {
    var fromRest = World(level: flat(), seed: 1)
    _ = run(&fromRest, frames: 3, input: InputFrame(moveX: -1))
    var turning = World(level: flat(), seed: 1)
    _ = run(&turning, frames: 12, input: InputFrame(moveX: 1))
    let before = hero(turning).vel.x
    _ = run(&turning, frames: 3, input: InputFrame(moveX: -1))
    #expect(before - hero(turning).vel.x > abs(hero(fromRest).vel.x))
}

// MARK: Collisions

@Test func aLedgeIsJumpedThroughFromBelowAndLandedOnFromAbove() {
    var world = World(level: flat { $0.ledge(40, 160, top: 90) }, seed: 1)
    _ = world.step(InputFrame(jump: true, jumpHeld: true))
    _ = run(&world, frames: 80, input: InputFrame(jumpHeld: true))
    #expect(hero(world).pos.y == 90)
    #expect(hero(world).onGround)
}

@Test func aWallStopsTheHero() {
    var world = World(level: flat { $0.ground(300, 360, top: 300) }, seed: 1)
    _ = run(&world, frames: 120, input: InputFrame(moveX: 1))
    #expect(hero(world).pos.x == 300 - hero(world).spec.width / 2)
    #expect(hero(world).onGround)
}

@Test func aSolidUndersideStopsAJump() {
    let level = flat { $0.platforms.append(Platform(Box(minX: 0, minY: 130, maxX: 300, maxY: 170))) }
    var world = World(level: level, seed: 1)
    _ = world.step(InputFrame(jump: true, jumpHeld: true))
    var highest = 0.0
    for _ in 0..<60 {
        _ = world.step(InputFrame(jumpHeld: true))
        highest = max(highest, hero(world).pos.y + hero(world).spec.height)
    }
    #expect(highest <= 130)
    #expect(hero(world).onGround)
}

@Test func aMovingPlatformCarriesWhoeverStandsOnIt() {
    var level = Level(name: "test", width: 2000, start: Vec2(100, 0), exitX: 5000)
    level.ledge(40, 160, top: 0, travel: Vec2(240, 0), period: 260)
    var world = World(level: level, seed: 1)
    _ = run(&world, frames: 130)
    #expect(abs(hero(world).pos.x - 340) < 0.1)
    #expect(hero(world).onGround)
    _ = run(&world, frames: 130)
    #expect(abs(hero(world).pos.x - 100) < 0.1)
}

@Test func aLiftCarriesTheHeroUp() {
    var world = World(level: flat { $0.ledge(40, 160, top: 0, travel: Vec2(0, 170), period: 240) }, seed: 1)
    _ = run(&world, frames: 120)
    #expect(abs(hero(world).pos.y - 170) < 0.1)
    #expect(hero(world).onGround)
}

@Test func aJumpStillWorksJustAfterRunningOffAnEdge() {
    var level = Level(name: "test", width: 2000, start: Vec2(100, 0), exitX: 5000)
    level.ground(-200, 200)
    var world = World(level: level, seed: 1)
    while hero(world).onGround { _ = world.step(InputFrame(moveX: 1)) }
    _ = run(&world, frames: 3, input: InputFrame(moveX: 1))
    let events = world.step(InputFrame(moveX: 1, jump: true, jumpHeld: true))
    #expect(events.contains(.jumped(id: world.controlledID)))
}

// MARK: Level rules

@Test func fallingOutCostsHealthAndPutsTheHeroBackOnSafeGround() {
    var level = Level(name: "test", width: 2000, start: Vec2(100, 0), exitX: 5000)
    level.ground(-200, 300)
    var world = World(level: level, seed: 1)
    var events: [GameEvent] = []
    for _ in 0..<200 where !events.contains(.respawned(id: world.controlledID)) {
        events += world.step(InputFrame(moveX: 1))
    }
    #expect(events.contains(.fell(id: world.controlledID)))
    #expect(hero(world).hp == hero(world).spec.maxHP - world.tuning.fallDamage)
    _ = run(&world, frames: 30)
    #expect(hero(world).onGround)
    #expect(hero(world).pos.x < 320)
}

@Test func aHazardHurtsAndADodgePassesThroughIt() {
    let level = flat { $0.hazards.append(Hazard(Box(minX: 300, minY: 0, maxX: 336, maxY: 150), damage: 12)) }

    var walking = World(level: level, seed: 1)
    let walked = run(&walking, frames: 60, input: InputFrame(moveX: 1))
    #expect(walked.contains { if case .hit(-1, _, 12, _) = $0 { true } else { false } })

    var tuning = Tuning()
    tuning.caelen.runSpeed = 0
    var level2 = level
    level2.start = Vec2(270, 0)
    var dodging = World(level: level2, tuning: tuning, seed: 1)
    var events = dodging.step(InputFrame(moveX: 1, dodge: true))
    events += run(&dodging, frames: 20)
    #expect(!events.contains { if case .hit = $0 { true } else { false } })
    #expect(hero(dodging).pos.x > 354)
}

@Test func aTimedHazardIsSafeWhileItIsOff() {
    let hazard = Hazard(Box(minX: 0, minY: 0, maxX: 10, maxY: 10), damage: 1, period: 150, onFrames: 80)
    #expect(hazard.isOn(at: 0))
    #expect(hazard.isOn(at: 79))
    #expect(!hazard.isOn(at: 80))
    #expect(!hazard.isWarning(at: 100))
    #expect(hazard.isWarning(at: 125))
    #expect(hazard.isOn(at: 150))
}

@Test func checkpointsPickupsAndTheExitAreReported() {
    var level = flat(width: 1000) {
        $0.checkpoints.append(Vec2(300, 0))
        $0.pickups.append(Pickup(id: 7, at: Vec2(500, 40), secret: true))
    }
    level.exitX = 800
    var world = World(level: level, seed: 1)
    let events = run(&world, frames: 400, input: InputFrame(moveX: 1))
    #expect(events.contains(.checkpoint(index: 0)))
    #expect(events.contains(.collected(id: 7, secret: true, at: Vec2(500, 40))))
    #expect(events.contains(.levelComplete))
    #expect(world.isComplete)
    #expect(world.collected == [7])

    let retry = World(level: level, seed: 2, fromCheckpoint: world.checkpointIndex, collected: world.collected)
    #expect(hero(retry).pos == Vec2(300, 0))
    #expect(retry.collected == [7])
}

// MARK: Enemies in a level

@Test func aPlacedEnemyPatrolsUntilAHeroComesClose() {
    var world = World(level: flat { $0.enemies.append(Placement(.scrapDrone, x: 1200)) }, seed: 1)
    let drone = world.fighters.first { $0.kind == .scrapDrone }!.id
    let quiet = run(&world, frames: 200)
    #expect(world.fighter(drone)?.awake == false)
    #expect(world.fighter(drone)?.pos.x != 1200)
    #expect(!quiet.contains(.woke(id: drone)))

    var events: [GameEvent] = []
    for _ in 0..<400 where !events.contains(.woke(id: drone)) { events += world.step(InputFrame(moveX: 1)) }
    #expect(world.fighter(drone)?.awake == true)
}

@Test func aMachineDoesNotWalkOffAnEdgeAfterTheHero() {
    var level = Level(name: "test", width: 2000, start: Vec2(900, 0), exitX: 5000)
    level.ground(-200, 400)
    level.ground(800, 1200)
    level.enemies.append(Placement(.scrapDrone, x: 300))
    var world = World(level: level, seed: 1)
    let drone = world.fighters.first { $0.kind == .scrapDrone }!.id
    _ = run(&world, frames: 600, input: InputFrame(moveX: -0.2))
    let d = world.fighter(drone)
    #expect(d?.isAlive == true)
    #expect(d?.onGround == true)
    #expect((d?.pos.x ?? 999) <= 400)
}

@Test func aMachineKnockedIntoAPitIsDestroyed() {
    var level = Level(name: "test", width: 2000, start: Vec2(100, 0), exitX: 5000)
    level.ground(-200, 260)
    level.enemies.append(Placement(.scrapDrone, x: 215))
    var tuning = Tuning()
    tuning.scrapDrone.maxHP = 10_000
    tuning.scrapDrone.selfDestruct = nil
    tuning.caelen.maxHP = 10_000
    var world = World(level: level, tuning: tuning, seed: 1)
    let drone = world.fighters.first { $0.kind == .scrapDrone }!.id
    var events: [GameEvent] = []
    for frame in 0..<1200 where !events.contains(.died(id: drone)) {
        events += world.step(InputFrame(moveX: 0.02, attack: frame % 6 == 0))
    }
    #expect(events.contains(.died(id: drone)))
}

// MARK: The yard

/// The hero is given health to spare, so these are about the route, not the fights.
private func traverse(
    _ level: Level, seed: UInt64, frames: Int, fights: Bool = false, lead: FighterKind = .caelen
) -> (world: World, events: [GameEvent]) {
    var tuning = Tuning()
    tuning.caelen.maxHP = 100_000
    tuning.seraphine.maxHP = 100_000
    tuning.nimue.maxHP = 100_000
    var world = World(level: level, hero: lead, tuning: tuning, seed: seed)
    var pilot = Autopilot(fights: fights)
    var events: [GameEvent] = []
    for _ in 0..<frames where !world.isOver { events += world.step(pilot.input(for: world)) }
    return (world, events)
}

@Test func everyLevelCanBeFinishedWhileFighting() {
    for level in Level.all {
        for seed in 1...3 {
            let result = traverse(level, seed: UInt64(seed), frames: 60 * 240, fights: true)
            #expect(result.world.isComplete, "\(level.name) seed \(seed) stopped at x \(hero(result.world).pos.x)")
        }
    }
}

@Test(arguments: [FighterKind.caelen, .seraphine, .nimue])
func eachLeadsChapterCanBeFinishedWhileFighting(_ lead: FighterKind) {
    for level in Level.chapter1(for: lead) {
        let result = traverse(level, seed: 1, frames: 60 * 240, fights: true, lead: lead)
        #expect(result.world.isComplete, "\(lead) in \(level.name) stopped at x \(hero(result.world).pos.x)")
    }
}

@Test func everyLevelCanBeFinishedWithoutFalling() {
    for level in Level.all {
        let result = traverse(level, seed: 1, frames: 60 * 240)
        #expect(result.world.isComplete, "\(level.name) stopped at x \(hero(result.world).pos.x)")
        #expect(!result.events.contains(.fell(id: result.world.controlledID)), "\(level.name)")
        #expect(result.events.filter { if case .checkpoint = $0 { true } else { false } }.count == level.checkpoints.count,
                "\(level.name)")
    }
}

// MARK: The companion in a level

private func partner(_ world: World) -> Fighter {
    world.fighters.first { $0.team == .hero && $0.id != world.controlledID }!
}

@Test func aCompanionPlacedAtTheStartFightsFromTheFirstStep() {
    let world = World(level: .foundryYard, seed: 1)
    #expect(partner(world).kind == .orion)
    #expect(partner(world).awake)
}

@Test func aCompanionFurtherInWaitsAndJoinsWhenReached() {
    var world = World(level: flat { $0.partner = Placement(.orion, x: 600) }, seed: 1)
    let orion = partner(world).id
    _ = run(&world, frames: 60)
    #expect(world.fighter(orion)?.awake == false)
    #expect(world.fighter(orion)?.pos.x == 600)
    // It cannot be switched to before it has joined.
    let early = world.step(InputFrame(switchHero: true))
    #expect(!early.contains(.controlChanged(id: orion)))

    var events: [GameEvent] = []
    for _ in 0..<300 where !events.contains(.joined(id: orion)) { events += world.step(InputFrame(moveX: 1)) }
    #expect(world.fighter(orion)?.awake == true)
    _ = run(&world, frames: 30)
    #expect(world.step(InputFrame(switchHero: true)).contains(.controlChanged(id: orion)))
}

@Test func aWaitingCompanionIsLeftAloneByMachines() {
    let level = flat {
        $0.partner = Placement(.orion, x: 700)
        $0.enemies.append(Placement(.scrapDrone, x: 760))
    }
    var tuning = Tuning()
    tuning.wakeRange = 0
    var world = World(level: level, tuning: tuning, seed: 1)
    let orion = partner(world).id
    world.fighters[world.fighters.firstIndex { $0.kind == .scrapDrone }!].awake = true
    let events = run(&world, frames: 400)
    #expect(world.fighter(orion)?.hp == world.fighter(orion)?.spec.maxHP)
    #expect(!events.contains { if case .hit(_, orion, _, _) = $0 { true } else { false } })
}

@Test func theCompanionJumpsAGapToKeepUp() {
    var level = Level(name: "test", width: 3000, start: Vec2(200, 0), exitX: 9000)
    level.ground(-200, 600)
    level.ground(700, 2000)
    level.partner = Placement(.orion, x: 150)
    var world = World(level: level, seed: 1)
    var pilot = Autopilot()
    var events: [GameEvent] = []
    for _ in 0..<360 { events += world.step(pilot.input(for: world)) }
    #expect(hero(world).pos.x > 900)
    #expect(partner(world).pos.x > 700)
    #expect(partner(world).onGround)
    #expect(!events.contains { if case .regrouped = $0 { true } else { false } })
}

@Test func theCompanionCatchesUpWhenLeftOnAnotherFloor() {
    let level = flat {
        $0.ground(600, 2200, top: 300)
        $0.ledge(480, 590, top: 0, travel: Vec2(0, 320), period: 240)
        $0.partner = Placement(.orion, x: 60)
    }
    var tuning = Tuning()
    tuning.caelen.maxHP = 100_000
    var world = World(level: level, tuning: tuning, seed: 1)
    var pilot = Autopilot()
    var events: [GameEvent] = []
    for _ in 0..<(60 * 20) where hero(world).pos.x < 1200 { events += world.step(pilot.input(for: world)) }
    events += run(&world, frames: 240)
    #expect(hero(world).pos.y == 300)
    #expect(partner(world).pos.y == 300)
    #expect(abs(partner(world).pos.x - hero(world).pos.x) < 200)
}

@Test func theCompanionIsStillThereAtTheEndOfEveryLevel() {
    for level in Level.all {
        let result = traverse(level, seed: 2, frames: 60 * 240)
        let p = partner(result.world)
        #expect(p.awake, "\(level.name)")
        #expect(abs(p.pos.x - hero(result.world).pos.x) < 600, "\(level.name)")
    }
}

@Test func theYardCanBeFinishedFromStartToExit() {
    let result = traverse(.foundryYard, seed: 1, frames: 60 * 90)
    #expect(result.world.isComplete, "stopped at x \(hero(result.world).pos.x), y \(hero(result.world).pos.y)")
    #expect(result.events.contains(.checkpoint(index: 0)))
    #expect(result.events.contains(.checkpoint(index: 1)))
    #expect(!result.events.contains(.fell(id: result.world.controlledID)))
}

@Test func theYardSecretCanBeReached() {
    var world = World(level: .foundryYard, seed: 1)
    for _ in 0..<(60 * 30) where !world.collected.contains(2) {
        let me = hero(world)
        var inp = InputFrame(moveX: 1, jumpHeld: true)
        if me.onGround, me.pos.x <= 905 {
            // The two steps on the way in.
            inp.jump = me.pos.x > 600 && me.vel.x == 0
        } else if me.onGround {
            switch me.pos.y {
            // On the floor under the ledges: back up to the step, then jump.
            case 0: if me.pos.x > 925 { inp.moveX = -1 } else { inp.jump = true }
            case 90: inp.jump = me.pos.x >= 1100
            case 175: inp.jump = me.pos.x >= 1270
            default: break
            }
        }
        _ = world.step(inp)
    }
    #expect(world.collected.contains(2), "stopped at x \(hero(world).pos.x), y \(hero(world).pos.y)")
}

@Test func aLevelRunIsTheSameEveryTimeForTheSameSeed() {
    let a = traverse(.foundryYard, seed: 9, frames: 3000)
    let b = traverse(.foundryYard, seed: 9, frames: 3000)
    #expect(a.events == b.events)
    #expect(!a.events.isEmpty)
}

// MARK: Openings

@Test func eachFactionHasItsOwnOpeningAndSharesTheRest() {
    let routes = Faction.allCases.map { Level.chapter1(for: $0.lead) }
    #expect(Set(routes.map { $0[0].name }).count == 3)
    for route in routes {
        #expect(route.dropFirst().map(\.name) == ["Foundry Yard", "The Machine Hall", "The Protocol"])
    }
}

@Test func everyOpeningIntroducesOrionWithAScene() {
    for faction in Faction.allCases {
        let opening = faction.opening
        let world = World(level: opening, hero: faction.lead, seed: 1)
        let orion = world.fighters.first { $0.kind == .orion }
        #expect(orion?.awake == false, "\(opening.name): Orion should wait to be found")
        #expect(opening.scenes.contains { $0.cue == .partnerJoins }, "\(opening.name)")
    }
}

// MARK: Chapters

@Test(arguments: [FighterKind.caelen, .seraphine, .nimue])
func chapterTwoCanBeFinishedWhileFightingWithEachLead(_ lead: FighterKind) {
    for level in Chapter.lanternCities.levels(for: lead) {
        for seed in 1...3 {
            let result = traverse(level, seed: UInt64(seed), frames: 60 * 300, fights: true, lead: lead)
            #expect(result.world.isComplete, "\(level.name) as \(lead) seed \(seed) stopped at x \(hero(result.world).pos.x)")
        }
    }
}

@Test func chaptersHaveUniqueIDsAndEveryLevelBelongsToOne() {
    #expect(Set(Chapter.all.map(\.id)).count == Chapter.all.count)
    let used = Set(Chapter.all.flatMap { c in [FighterKind.caelen, .seraphine, .nimue].flatMap { c.levels(for: $0).map(\.name) } })
    #expect(used == Set(Level.all.map(\.name)))
}
