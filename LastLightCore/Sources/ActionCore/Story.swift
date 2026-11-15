import Foundation

/// What the player has decided and seen. It is the part of the save the story reads and writes.
public struct StoryState: Codable, Sendable, Equatable {
    /// Decisions, by name: `"orion": "trusted"`.
    public var flags: [String: String] = [:]
    /// Scenes already played, so they do not repeat on a retry.
    public var seen: Set<String> = []

    public init() {}

    public func meets(_ conditions: [String: String]?) -> Bool {
        (conditions ?? [:]).allSatisfy { flags[$0.key] == $0.value }
    }
}

/// One answer the player can give.
public struct StoryChoice: Codable, Sendable, Equatable {
    public var text: String
    /// The line that follows. Nil ends the scene.
    public var next: String?
    /// Decisions recorded when this answer is picked.
    public var set: [String: String]?
    /// The answer is offered only when these decisions were made earlier.
    public var requires: [String: String]?
}

/// One line of a scene.
public struct StoryLine: Codable, Sendable, Equatable {
    public var speaker: String
    public var text: String
    public var next: String?
    public var choices: [StoryChoice]?
    public var set: [String: String]?
    /// The line is spoken only when these decisions were made; otherwise the scene goes to `otherwise`.
    public var requires: [String: String]?
    public var otherwise: String?
}

/// A conversation: lines by name, and where it starts.
public struct StoryScene: Codable, Sendable, Equatable {
    public var start: String
    public var lines: [String: StoryLine]
}

/// Every scene of the game, loaded from JSON. Writing a scene is editing a data file, not code.
public struct StoryLibrary: Codable, Sendable, Equatable {
    public var scenes: [String: StoryScene]

    public init(scenes: [String: StoryScene] = [:]) {
        self.scenes = scenes
    }

    public init(json: Data) throws {
        self = try JSONDecoder().decode(StoryLibrary.self, from: json)
    }

    /// Mistakes a writer can make in the data: a line that points nowhere, a scene with no way through.
    public func problems() -> [String] {
        var found: [String] = []
        for (id, scene) in scenes.sorted(by: { $0.key < $1.key }) {
            if scene.lines[scene.start] == nil { found.append("\(id): start '\(scene.start)' does not exist") }
            for (name, line) in scene.lines.sorted(by: { $0.key < $1.key }) {
                let targets = [line.next, line.otherwise] + (line.choices ?? []).map(\.next)
                for target in targets.compactMap({ $0 }) where scene.lines[target] == nil {
                    found.append("\(id).\(name): points to '\(target)', which does not exist")
                }
                if line.requires != nil, line.otherwise == nil {
                    found.append("\(id).\(name): has a condition but nowhere to go when it fails")
                }
                if line.choices?.isEmpty == true { found.append("\(id).\(name): empty list of choices") }
            }
        }
        return found
    }
}

/// Plays one scene: gives the current line, takes "continue" or a choice, and records decisions.
public struct StoryRunner: Sendable, Equatable {
    public let sceneID: String
    public private(set) var state: StoryState
    public private(set) var line: StoryLine?
    private let scene: StoryScene

    /// Nil when the library has no such scene.
    public init?(sceneID: String, library: StoryLibrary, state: StoryState) {
        guard let scene = library.scenes[sceneID] else { return nil }
        self.sceneID = sceneID
        self.scene = scene
        self.state = state
        go(to: scene.start)
    }

    public var isFinished: Bool { line == nil }

    /// The answers on offer for the current line; empty when the line only needs "continue".
    public var choices: [StoryChoice] {
        (line?.choices ?? []).filter { state.meets($0.requires) }
    }

    /// Moves past a line that has no choices.
    public mutating func advance() {
        guard let line, choices.isEmpty else { return }
        go(to: line.next)
    }

    public mutating func choose(_ index: Int) {
        let offered = choices
        guard offered.indices.contains(index) else { return }
        for (key, value) in offered[index].set ?? [:] { state.flags[key] = value }
        go(to: offered[index].next)
    }

    private mutating func go(to name: String?) {
        var target = name
        // Skip lines whose conditions are not met. The hop limit stops a loop written into the data.
        for _ in 0..<64 {
            guard let key = target, let next = scene.lines[key] else { break }
            if state.meets(next.requires) {
                for (flag, value) in next.set ?? [:] { state.flags[flag] = value }
                line = next
                return
            }
            target = next.otherwise
        }
        line = nil
        state.seen.insert(sceneID)
    }
}

/// When a scene plays inside a level.
public enum SceneCue: Sendable, Equatable {
    case start
    /// The hero reaches this x.
    case reach(Double)
    case partnerJoins
    case bossWakes
    case complete
}

public struct SceneTrigger: Sendable, Equatable {
    public var scene: String
    public var cue: SceneCue

    public init(_ scene: String, on cue: SceneCue) {
        self.scene = scene
        self.cue = cue
    }
}
