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
    enum Screen {
        case title
        case playing
        case paused
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
        // `-menu paused`, `-menu settings` or `-menu chapters` opens that menu, for checking it by screenshot.
        if let i = args.firstIndex(of: "-menu"), i + 1 < args.count {
            switch args[i + 1] {
            case "paused": screen = .paused
            case "settings": panel = .settings
            case "chapters": panel = .chapters
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
        story.resetAll()
        scene.play(levelAt: 0)
        screen = .playing
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

    func quitToTitle() {
        panel = nil
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
            #if os(iOS)
            .statusBarHidden()
            .persistentSystemOverlays(.hidden)
            #else
            .frame(minWidth: 800, minHeight: 450)
            #endif
    }

    private var debugOptions: SpriteView.DebugOptions {
        #if DEBUG
        [.showsFPS, .showsNodeCount]
        #else
        []
        #endif
    }
}
