import ActionCore
import Foundation
import Observation

/// Holds the story file, the saved decisions and the scene being played. The game scene starts scenes;
/// the SwiftUI dialogue panel shows them and sends back "continue" or a choice.
@MainActor
@Observable
final class StoryPresenter {
    private(set) var runner: StoryRunner?
    private(set) var state = StoryState()
    private let library: StoryLibrary
    private let saveURL: URL

    init() {
        let file = Bundle.main.url(forResource: "chapter1", withExtension: "json")
            ?? Bundle.main.url(forResource: "chapter1", withExtension: "json", subdirectory: "Story")
        library = file.flatMap { try? Data(contentsOf: $0) }.flatMap { try? StoryLibrary(json: $0) } ?? StoryLibrary()

        let folder = (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory).appendingPathComponent("LastLight", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        saveURL = folder.appendingPathComponent("story.json")
        if let data = try? Data(contentsOf: saveURL), let saved = try? JSONDecoder().decode(StoryState.self, from: data) {
            state = saved
        }
    }

    var isActive: Bool { runner != nil }
    var sceneCount: Int { library.scenes.count }

    /// Starts a scene unless it was already played. Returns whether it started.
    @discardableResult
    func begin(_ id: String) -> Bool {
        guard runner == nil, !state.seen.contains(id),
              let started = StoryRunner(sceneID: id, library: library, state: state) else { return false }
        runner = started
        settle()
        return runner != nil
    }

    func advance() {
        runner?.advance()
        settle()
    }

    func choose(_ index: Int) {
        runner?.choose(index)
        settle()
    }

    /// Playing a level again from its start plays its scenes again, so a decision can be made differently.
    func forget(_ scenes: [String]) {
        guard scenes.contains(where: state.seen.contains) else { return }
        state.seen.subtract(scenes)
        save()
    }

    /// A new game: every decision and every scene played is forgotten.
    /// Forgets every choice. With a lead, remembers who is leading, so shared scenes can speak to them.
    func resetAll(lead: FighterKind? = nil) {
        runner = nil
        state = StoryState()
        if let lead { state.flags["lead"] = lead.rawValue }
        save()
    }

    private func settle() {
        guard let runner, runner.isFinished else { return }
        state = runner.state
        self.runner = nil
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: saveURL, options: .atomic)
    }
}
