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

struct GameView: View {
    /// Launching with `-demo` lets a simple bot play, which is how the scene is checked without hands.
    /// `-room` starts in the training room instead of the level.
    @State private var scene = GameScene(
        demo: ProcessInfo.processInfo.arguments.contains("-demo"),
        mode: ProcessInfo.processInfo.arguments.contains("-room") ? .room : .level)

    var body: some View {
        SpriteView(scene: scene, debugOptions: debugOptions)
            .ignoresSafeArea()
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
