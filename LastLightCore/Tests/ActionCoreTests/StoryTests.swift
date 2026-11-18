@testable import ActionCore
import Foundation
import Testing

private let sample = """
{ "scenes": { "meet": { "start": "a", "lines": {
  "a": { "speaker": "ORION", "text": "Hello.", "next": "b" },
  "b": { "speaker": "ORION", "text": "Well?", "choices": [
    { "text": "Yes", "next": "yes", "set": { "answer": "yes" } },
    { "text": "No", "set": { "answer": "no" } },
    { "text": "Again", "next": "yes", "requires": { "met": "before" } } ] },
  "yes": { "speaker": "ORION", "text": "Good." }
} },
"later": { "start": "glad", "lines": {
  "glad": { "speaker": "ORION", "text": "You said yes.", "requires": { "answer": "yes" }, "otherwise": "sad" },
  "sad": { "speaker": "ORION", "text": "You said no." }
} } } }
"""

private func library() throws -> StoryLibrary {
    try StoryLibrary(json: Data(sample.utf8))
}

/// The story file the app ships.
private func shipped() throws -> StoryLibrary {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    var scenes: [String: StoryScene] = [:]
    for chapter in Chapter.all {
        let file = root.appendingPathComponent("LastLight/LastLight/Story/\(chapter.id).json")
        let library = try StoryLibrary(json: Data(contentsOf: file))
        for (id, scene) in library.scenes {
            precondition(scenes[id] == nil, "scene \(id) is in two chapter files")
            scenes[id] = scene
        }
    }
    return StoryLibrary(scenes: scenes)
}

@Test func aSceneIsReadFromDataAndPlayedLineByLine() throws {
    var runner = try #require(StoryRunner(sceneID: "meet", library: library(), state: StoryState()))
    #expect(runner.line?.text == "Hello.")
    #expect(runner.choices.isEmpty)
    runner.advance()
    #expect(runner.line?.text == "Well?")
    #expect(runner.choices.map(\.text) == ["Yes", "No"])
}

@Test func aLineWithChoicesWaitsForOne() throws {
    var runner = try #require(StoryRunner(sceneID: "meet", library: library(), state: StoryState()))
    runner.advance()
    runner.advance()
    #expect(runner.line?.text == "Well?")
}

@Test func aChoiceIsRecordedAndLeadsToItsOwnLine() throws {
    var runner = try #require(StoryRunner(sceneID: "meet", library: library(), state: StoryState()))
    runner.advance()
    runner.choose(0)
    #expect(runner.state.flags["answer"] == "yes")
    #expect(runner.line?.text == "Good.")
    runner.advance()
    #expect(runner.isFinished)
    #expect(runner.state.seen.contains("meet"))
}

@Test func aChoiceWithNoNextLineEndsTheScene() throws {
    var runner = try #require(StoryRunner(sceneID: "meet", library: library(), state: StoryState()))
    runner.advance()
    runner.choose(1)
    #expect(runner.isFinished)
    #expect(runner.state.flags["answer"] == "no")
}

@Test func aLaterSceneSpeaksDifferentlyAfterEachDecision() throws {
    for (answer, text) in [("yes", "You said yes."), ("no", "You said no.")] {
        var state = StoryState()
        state.flags["answer"] = answer
        let runner = try #require(StoryRunner(sceneID: "later", library: library(), state: state))
        #expect(runner.line?.text == text)
    }
}

@Test func aChoiceCanDependOnAnEarlierDecision() throws {
    var state = StoryState()
    state.flags["met"] = "before"
    var runner = try #require(StoryRunner(sceneID: "meet", library: library(), state: state))
    runner.advance()
    #expect(runner.choices.map(\.text) == ["Yes", "No", "Again"])
}

@Test func decisionsSurviveBeingSavedAndLoaded() throws {
    var state = StoryState()
    state.flags["orion"] = "trusted"
    state.seen.insert("awakening.orion")
    let loaded = try JSONDecoder().decode(StoryState.self, from: JSONEncoder().encode(state))
    #expect(loaded == state)
}

@Test func anUnknownSceneGivesNoRunner() throws {
    #expect(StoryRunner(sceneID: "nothing", library: try library(), state: StoryState()) == nil)
}

@Test func brokenStoryDataIsReported() throws {
    let broken = """
    { "scenes": { "s": { "start": "a", "lines": {
      "a": { "speaker": "X", "text": "t", "next": "missing" },
      "b": { "speaker": "X", "text": "t", "requires": { "k": "v" } } } } } }
    """
    let problems = try StoryLibrary(json: Data(broken.utf8)).problems()
    #expect(problems.count == 2)
    #expect(try library().problems().isEmpty)
}

// MARK: The shipped story

@Test func theShippedStoryHasNoBrokenLinks() throws {
    #expect(try shipped().problems() == [])
}

@Test func everySceneALevelAsksForExistsInTheShippedStory() throws {
    let story = try shipped()
    for level in Level.all {
        for trigger in level.scenes {
            #expect(story.scenes[trigger.scene] != nil, "\(level.name): \(trigger.scene)")
        }
    }
}

@Test func theChoiceAboutOrionChangesWhatHeSaysBeforeTheBoss() throws {
    let story = try shipped()
    var lines: Set<String> = []
    for pick in 0...1 {
        var meeting = try #require(StoryRunner(sceneID: "awakening.orion", library: story, state: StoryState()))
        while meeting.choices.isEmpty, !meeting.isFinished { meeting.advance() }
        meeting.choose(pick)
        while !meeting.isFinished { meeting.advance() }
        let boss = try #require(StoryRunner(sceneID: "protocol.wake", library: story, state: meeting.state))
        lines.insert(try #require(boss.line?.text))
    }
    #expect(lines.count == 2)
    // Reaching the boss without having met him still gives a line.
    #expect(StoryRunner(sceneID: "protocol.wake", library: story, state: StoryState())?.line != nil)
}

// MARK: Cues in a level

@Test func meetingOrionCuesHisSceneOnce() {
    var world = World(level: .awakening, seed: 1)
    var pilot = Autopilot()
    var events: [GameEvent] = []
    for _ in 0..<(60 * 120) where !world.isOver { events += world.step(pilot.input(for: world)) }
    #expect(events.filter { $0 == .scene(id: "awakening.orion") }.count == 1)
    let joined = events.firstIndex { if case .joined = $0 { true } else { false } }!
    #expect(events.firstIndex(of: .scene(id: "awakening.orion"))! > joined)
}

@Test func theBossWakingCuesItsScene() {
    var world = World(level: .theProtocol, seed: 1)
    var events: [GameEvent] = []
    for _ in 0..<600 { events += world.step(InputFrame(moveX: 1)) }
    #expect(events.contains(.scene(id: "protocol.wake")))
}

@Test func aSceneCanBeCuedByReachingAPlace() {
    var level = Level(name: "test", width: 2000, start: Vec2(100, 0), exitX: 5000)
    level.ground(-200, 2200)
    level.scenes = [SceneTrigger("door", on: .reach(400)), SceneTrigger("hello", on: .start)]
    var world = World(level: level, seed: 1)
    #expect(world.step(.neutral).contains(.scene(id: "hello")))
    var events: [GameEvent] = []
    while world.controlled!.pos.x < 395 { events += world.step(InputFrame(moveX: 1)) }
    #expect(!events.contains(.scene(id: "door")))
    for _ in 0..<20 { events += world.step(InputFrame(moveX: 1)) }
    #expect(events.filter { $0 == .scene(id: "door") }.count == 1)
}

@Test func theSharedHallSpeaksToWhoeverLeads() throws {
    let story = try shipped()
    for lead in [FighterKind.caelen, .seraphine, .nimue] {
        var state = StoryState()
        state.flags["lead"] = lead.rawValue
        let runner = try #require(StoryRunner(sceneID: "hall.enter", library: story, state: state))
        #expect(runner.line?.speaker == lead.rawValue.uppercased())
    }
    // A save from before leads were remembered still gets a line.
    let old = try #require(StoryRunner(sceneID: "hall.enter", library: story, state: StoryState()))
    #expect(old.line?.speaker == "ORION")
}

@Test func everyOpeningAsksOrionTheSameQuestion() throws {
    let story = try shipped()
    for id in ["awakening.orion", "gauges.orion", "undercroft.orion"] {
        var runner = try #require(StoryRunner(sceneID: id, library: story, state: StoryState()))
        while runner.choices.isEmpty, runner.line != nil { runner.advance() }
        #expect(runner.choices.count == 2, "\(id)")
        runner.choose(0)
        while runner.line != nil { runner.advance() }
        #expect(runner.state.flags["orion"] == "trusted", "\(id)")
    }
}

@Test func theChapterEndsOnTheLeadThenOrionAnsweringTheirChoice() throws {
    let story = try shipped()
    for lead in [FighterKind.caelen, .seraphine, .nimue] {
        for (choice, words) in [("trusted", "beside you"), ("watched", "stop watching")] {
            var state = StoryState()
            state.flags = ["lead": lead.rawValue, "orion": choice]
            var runner = try #require(StoryRunner(sceneID: "protocol.end", library: story, state: state))
            #expect(runner.line?.speaker == lead.rawValue.uppercased())
            runner.advance()
            #expect(runner.line?.speaker == "ORION")
            #expect(runner.line?.text.contains(words) == true, "\(lead) \(choice)")
            runner.advance()
            #expect(runner.isFinished)
        }
    }
}

@Test func theEndingSceneIsCuedWhenTheProtocolFalls() {
    var tuning = Tuning()
    tuning.caelen.maxHP = 100_000
    var world = World(level: .theProtocol, hero: .caelen, tuning: tuning, seed: 1)
    var pilot = Autopilot(fights: true)
    var events: [GameEvent] = []
    for _ in 0..<(60 * 240) where !world.isOver { events += world.step(pilot.input(for: world)) }
    #expect(world.isComplete)
    #expect(events.contains(.scene(id: "protocol.end")))
}

@Test func everyChapterTwoSceneSpeaksToWhoeverLeads() throws {
    let story = try shipped()
    for id in ["market.arrive", "market.ratborn", "roofs.arrive", "docks.arrive"] {
        for lead in [FighterKind.caelen, .seraphine, .nimue] {
            var state = StoryState()
            state.flags["lead"] = lead.rawValue
            var runner = try #require(StoryRunner(sceneID: id, library: story, state: state))
            var speakers: Set<String> = []
            while let line = runner.line { speakers.insert(line.speaker); runner.advance() }
            #expect(speakers.isSubset(of: [lead.rawValue.uppercased(), "ORION"]), "\(id) as \(lead)")
        }
        // Saves from before leads were remembered still get a line.
        #expect(try #require(StoryRunner(sceneID: id, library: story, state: StoryState())).line != nil)
    }
}

@Test func theCinderKingSpeaksToEachLeadThenNamesHisPrice() throws {
    let story = try shipped()
    for lead in [FighterKind.caelen, .seraphine, .nimue] {
        var state = StoryState()
        state.flags["lead"] = lead.rawValue
        var runner = try #require(StoryRunner(sceneID: "vault.wake", library: story, state: state))
        #expect(runner.line?.speaker == "CINDER KING")
        var speakers: [String] = []
        var last = ""
        while let line = runner.line { speakers.append(line.speaker); last = line.text; runner.advance() }
        #expect(speakers.contains(lead.rawValue.uppercased()), "\(lead)")
        #expect(last.hasPrefix("Everything has a price"))
    }
}

@Test func afterTheVaultOrionAnswersTheChoiceMadeWhenTheyMet() throws {
    let story = try shipped()
    for (choice, words) in [("trusted", "He bought and sold"), ("watched", "watch me read")] {
        var state = StoryState()
        state.flags = ["lead": "nimue", "orion": choice]
        var runner = try #require(StoryRunner(sceneID: "vault.end", library: story, state: state))
        var last = ""
        while let line = runner.line { last = line.text; runner.advance() }
        #expect(last.contains(words), "\(choice)")
    }
}

@Test func atTheGateEachLeadSpeaksThenOrionNamesTheWardensWeakness() throws {
    let story = try shipped()
    for lead in [FighterKind.caelen, .seraphine, .nimue] {
        for choice in ["trusted", "watched"] {
            var state = StoryState()
            state.flags = ["lead": lead.rawValue, "orion": choice]
            var runner = try #require(StoryRunner(sceneID: "warden.wake", library: story, state: state))
            var speakers: [String] = []
            var last = ""
            while let line = runner.line { speakers.append(line.speaker); last = line.text; runner.advance() }
            #expect(speakers == [lead.rawValue.uppercased(), "ORION"], "\(lead) \(choice)")
            #expect(last.contains("behind") || last.contains("round"))
        }
    }
}

@Test func everyChapterThreeSceneSpeaksToWhoeverLeads() throws {
    let story = try shipped()
    for id in ["road.arrive", "cloister.arrive", "stair.arrive"] {
        for lead in [FighterKind.caelen, .seraphine, .nimue] {
            var state = StoryState()
            state.flags["lead"] = lead.rawValue
            var runner = try #require(StoryRunner(sceneID: id, library: story, state: state))
            #expect(runner.line?.speaker == lead.rawValue.uppercased(), "\(id) as \(lead)")
            var speakers: Set<String> = []
            while let line = runner.line { speakers.insert(line.speaker); runner.advance() }
            #expect(speakers.isSubset(of: [lead.rawValue.uppercased(), "ORION"]), "\(id) as \(lead)")
        }
        #expect(try #require(StoryRunner(sceneID: id, library: story, state: StoryState())).line != nil)
    }
}

@Test func orionWarnsAboutTheFlareBeforeTheFirstDisciple() throws {
    let story = try shipped()
    let runner = try #require(StoryRunner(sceneID: "cloister.halo", library: story, state: StoryState()))
    #expect(runner.line?.text.contains("turn your back") == true)
    let cue = try #require(Level.sunCloister.scenes.first { $0.scene == "cloister.halo" })
    let disciple = try #require(Level.sunCloister.enemies.first { $0.kind == .haloDisciple })
    if case .reach(let x) = cue.cue { #expect(x < disciple.pos.x - 300) } else { Issue.record("not a reach cue") }
}

@Test func theLastOracleHearsEachLeadThenNamesHerEnding() throws {
    let story = try shipped()
    for lead in [FighterKind.caelen, .seraphine, .nimue] {
        var state = StoryState()
        state.flags["lead"] = lead.rawValue
        var runner = try #require(StoryRunner(sceneID: "oracle.wake", library: story, state: state))
        var speakers: [String] = []
        var last = ""
        while let line = runner.line { speakers.append(line.speaker); last = line.text; runner.advance() }
        #expect(speakers == [lead.rawValue.uppercased(), "LAST ORACLE", "LAST ORACLE"], "\(lead)")
        #expect(last.contains("gentle"))
    }
}

@Test func afterTheTerraceOrionAnswersTheChoiceMadeWhenTheyMet() throws {
    let story = try shipped()
    for (choice, words) in [("trusted", "not the same as being right"), ("watched", "Watch the certain ones")] {
        var state = StoryState()
        state.flags = ["lead": "seraphine", "orion": choice]
        var runner = try #require(StoryRunner(sceneID: "oracle.end", library: story, state: state))
        var last = ""
        while let line = runner.line { last = line.text; runner.advance() }
        #expect(last.contains(words), "\(choice)")
    }
}

@Test func theLockWorksGreetsWhoeverLeadsAndOrionExplainsEachLock() throws {
    let story = try shipped()
    for lead in [FighterKind.caelen, .seraphine, .nimue] {
        var state = StoryState()
        state.flags = ["lead": lead.rawValue]
        var runner = try #require(StoryRunner(sceneID: "locks.arrive", library: story, state: state))
        #expect(runner.line?.speaker == lead.rawValue.uppercased())
        runner.advance()
        #expect(runner.isFinished)
    }
    for id in ["locks.lever", "locks.plate", "locks.race"] {
        let runner = try #require(StoryRunner(sceneID: id, library: story, state: StoryState()))
        #expect(runner.line?.speaker == "ORION", "\(id)")
    }
}

@Test func theLamplighterSpeaksFirstThenTheLeadThenOrionTellsHowToBeatHim() throws {
    let story = try shipped()
    for lead in [FighterKind.caelen, .seraphine, .nimue] {
        for choice in ["trusted", "watched"] {
            var state = StoryState()
            state.flags = ["lead": lead.rawValue, "orion": choice]
            var runner = try #require(StoryRunner(sceneID: "lamp.wake", library: story, state: state))
            var speakers: [String] = []
            var last = ""
            while let line = runner.line { speakers.append(line.speaker); last = line.text; runner.advance() }
            #expect(speakers == ["LAMPLIGHTER", lead.rawValue.uppercased(), "ORION"], "\(lead) \(choice)")
            #expect(last.contains("lamp"))
        }
    }
}
