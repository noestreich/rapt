import SpriteKit
import SwiftUI

struct GameView: View {
    @State private var scene: GameScene = {
        let scene = GameScene(size: CGSize(width: 390, height: 844))
        scene.scaleMode = .resizeFill
        return scene
    }()
    @State private var showsSettings = false

    var body: some View {
        GeometryReader { geo in
            SpriteView(scene: scene, preferredFramesPerSecond: 120)
                .ignoresSafeArea()
                .onAppear { scene.safeInsets = ScreenInsets(geo.safeAreaInsets) }
                .onChange(of: geo.safeAreaInsets) { _, insets in scene.safeInsets = ScreenInsets(insets) }
        }
        .background(Color.black)
        #if os(iOS)
        .overlay(alignment: .topTrailing) {
            Button {
                showsSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(red: 1, green: 0.7, blue: 0.28).opacity(0.85))
                    .padding(12)
            }
            .accessibilityLabel("Einstellungen")
        }
        .onChange(of: showsSettings) { _, open in scene.isPaused = open }
        .sheet(isPresented: $showsSettings) {
            NavigationStack {
                SettingsView()
                    .navigationTitle("Einstellungen")
                    .toolbar { Button("Fertig") { showsSettings = false } }
            }
            .presentationDetents([.medium])
        }
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
