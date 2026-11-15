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
    @State private var scene = GameScene(demo: ProcessInfo.processInfo.arguments.contains("-demo"))

    var body: some View {
        SpriteView(scene: scene, debugOptions: debugOptions)
            .ignoresSafeArea()
            .statusBarHidden()
            .persistentSystemOverlays(.hidden)
    }

    private var debugOptions: SpriteView.DebugOptions {
        #if DEBUG
        [.showsFPS, .showsNodeCount]
        #else
        []
        #endif
    }
}
