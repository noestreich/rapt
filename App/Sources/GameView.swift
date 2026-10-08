import SpriteKit
import SwiftUI

struct GameView: View {
    @State private var showSplash = LaunchSplash.enabled   // LaunchSplash
    @State private var scene: GameScene = {
        let scene = GameScene(size: CGSize(width: 390, height: 844))
        scene.scaleMode = .resizeFill
        return scene
    }()

    var body: some View {
        GeometryReader { geo in
            SpriteView(scene: scene, preferredFramesPerSecond: 120)
                .ignoresSafeArea()
                .onAppear { scene.safeInsets = ScreenInsets(geo.safeAreaInsets) }
                .onChange(of: geo.safeAreaInsets) { _, insets in scene.safeInsets = ScreenInsets(insets) }
        }
        .overlay {   // LaunchSplash
            if showSplash { LaunchSplash { showSplash = false } }
        }
        .background(Color.black)
        #if os(iOS)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        #endif
    }
}

extension ScreenInsets {
    init(_ insets: EdgeInsets) {
        self.init(top: insets.top, left: insets.leading, bottom: insets.bottom, right: insets.trailing)
    }
}
