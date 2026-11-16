import ImageIO
import ActionCore
import Observation
import SpriteKit
import SwiftUI

@main
struct LastLightApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
        }
    }
}

/// The scene, the story and the menus around them. The SwiftUI menus call these methods; the scene asks
/// for the pause menu through `onPause`.
@MainActor
@Observable
final class Game {
    enum Screen: Equatable {
        case title
        case playing
        case paused
        /// New Game: choose a faction, which chooses the lead and their opening.
        case factionPick
        case results(LevelResult)
    }

    enum Panel {
        case settings
        case chapters
    }

    var screen: Screen {
        didSet { scene.frozen = screen != .playing }
    }
    var panel: Panel?
    var settings: Settings {
        didSet {
            settings.save()
            scene.apply(settings)
        }
    }
    let story = StoryPresenter()
    @ObservationIgnored let scene: GameScene

    init() {
        let args = ProcessInfo.processInfo.arguments
        let demo = args.contains("-demo")
        scene = GameScene(demo: demo, mode: args.contains("-room") ? .room : .level, story: story)
        settings = Settings.load()
        // Launch arguments used for checking a level skip the title.
        let direct = demo || args.contains("-level") || args.contains("-room") || args.contains("-scene")
        screen = direct ? .playing : .title
        scene.apply(settings)
        scene.frozen = screen != .playing
        scene.onPause = { [weak self] in self?.pause() }
        scene.demoShowsResults = args.contains("-results")
        scene.onComplete = { [weak self] result in
            // A moment for the clear sound and the last effects before the screen comes up.
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1.2))
                // A closing scene plays first.
                while self?.story.isActive == true { try? await Task.sleep(for: .seconds(0.2)) }
                guard let self, self.screen == .playing else { return }
                if self.scene.demoShowsResults { FileHandle.standardError.write(Data("RESULTS \(result)\n".utf8)) }
                self.screen = .results(result)
            }
        }
        // `-menu paused`, `-menu settings` or `-menu chapters` opens that menu, for checking it by screenshot.
        if let i = args.firstIndex(of: "-menu"), i + 1 < args.count {
            switch args[i + 1] {
            case "paused": screen = .paused
            case "factions": screen = .factionPick
            case "settings": panel = .settings
            case "chapters": panel = .chapters
            case "results", "chapter":
                screen = .results(LevelResult(
                    name: args[i + 1] == "chapter" ? "The Protocol" : "The Machine Hall", index: 2,
                    isLast: args[i + 1] == "chapter", seconds: 263, defeated: 14, downs: 1, found: 3, hidden: 5))
            default: break
            }
        }
    }

    /// The title offers Continue once a level past the first was reached or a story scene was played.
    var hasProgress: Bool { scene.currentLevel > 0 || !story.state.seen.isEmpty }
    var levelNames: [String] { scene.levelNames }

    func continueGame() {
        panel = nil
        scene.play(levelAt: scene.currentLevel)
        screen = .playing
    }

    func newGame() {
        panel = nil
        screen = .factionPick
    }

    /// Starts a new run as this faction: every story choice is forgotten.
    func begin(_ faction: Faction) {
        panel = nil
        story.resetAll(lead: faction.lead)
        scene.begin(as: faction.lead)
        screen = .playing
    }

    /// Who is leading and where, for the Continue button.
    var continueDetail: String {
        let name = scene.lead.rawValue.capitalized
        return scene.levelNames.indices.contains(scene.currentLevel) ? "\(name) · \(scene.levelNames[scene.currentLevel])" : name
    }

    func play(chapter index: Int) {
        panel = nil
        scene.play(levelAt: index)
        screen = .playing
    }

    func trainingRoom() {
        panel = nil
        scene.playTrainingRoom()
        screen = .playing
    }

    func pause() {
        guard screen == .playing, !story.isActive else { return }
        screen = .paused
    }

    func resume() {
        panel = nil
        screen = .playing
    }

    func retryFromCheckpoint() {
        scene.retry()
        resume()
    }

    func restartLevel() {
        scene.restartLevel()
        resume()
    }

    /// From the results screen: on to the next level.
    func nextLevel() {
        scene.advance()
        screen = .playing
    }

    /// From the chapter's last results screen: back to the start of the chapter.
    func replayChapter() {
        scene.play(levelAt: 0)
        screen = .playing
    }

    func finishChapter() {
        scene.play(levelAt: 0)
        quitToTitle()
    }

    func quitToTitle() {
        panel = nil
        // Leaving a results screen still counts the level as done, so Continue goes to the next one.
        if case .results(let result) = screen, !result.isLast { scene.play(levelAt: result.index + 1) }
        screen = .title
    }
}

struct GameView: View {
    /// Launching with `-demo` lets a simple bot play, which is how the scene is checked without hands.
    /// `-room` starts in the training room instead of the level.
    @State private var game = Game()

    var body: some View {
        SpriteView(scene: game.scene, debugOptions: debugOptions)
            .ignoresSafeArea()
            .overlay { DialogueView(story: game.story) }
            .overlay { MenuOverlay(game: game) }
            .animation(.easeOut(duration: 0.15), value: game.story.isActive)
            .animation(.easeOut(duration: 0.2), value: game.screen)
            .animation(.easeOut(duration: 0.15), value: game.panel)
            #if DEBUG
            .task { await renderMenuIfAsked() }
            #endif
            #if os(iOS)
            .statusBarHidden()
            .persistentSystemOverlays(.hidden)
            #else
            .frame(minWidth: 800, minHeight: 450)
            #endif
    }

    #if DEBUG
    /// `-render` saves the menu layer as an image to the app's temporary folder, so menus can be checked without
    /// a screen capture. The live hero figures inside cards don't render this way. Debug builds only.
    @MainActor
    private func renderMenuIfAsked() async {
        guard ProcessInfo.processInfo.arguments.contains("-render") else { return }
        try? await Task.sleep(for: .seconds(1.5))
        let view = ZStack {
            Color(red: 0.03, green: 0.06, blue: 0.11)
            MenuOverlay(game: game)
        }
        .frame(width: 874, height: ProcessInfo.processInfo.arguments.contains("-short") ? 360 : 402)
        .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.cgImage else { return }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("snapshots")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("menu.png")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }
    #endif

    private var debugOptions: SpriteView.DebugOptions {
        #if DEBUG
        [.showsFPS, .showsNodeCount]
        #else
        []
        #endif
    }
}
