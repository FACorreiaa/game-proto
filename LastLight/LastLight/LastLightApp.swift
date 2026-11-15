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

/// The scene and the story it plays, made together so the scene can start dialogue.
@MainActor
final class Game {
    let story = StoryPresenter()
    let scene: GameScene

    init() {
        let args = ProcessInfo.processInfo.arguments
        scene = GameScene(demo: args.contains("-demo"), mode: args.contains("-room") ? .room : .level, story: story)
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
            .animation(.easeOut(duration: 0.15), value: game.story.isActive)
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
