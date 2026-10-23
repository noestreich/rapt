import SpriteKit
import SwiftUI

struct GameView: View {
    @Environment(\.scenePhase) private var scenePhase
    #if os(macOS)
    @State private var keyMonitor: Any?
    #endif
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
                #if os(iOS)
                // iPhone Duo auf- oder zugeklappt: erlaubte Ausrichtungen passen sich der neuen Größe an
                .onChange(of: geo.size) { _, _ in ScreenFit.refresh() }
                #endif
        }
        .overlay {   // LaunchSplash
            if showSplash { LaunchSplash { showSplash = false } }
        }
        .background(Color.black)
        // Laufendes Spiel sichern, sobald die App in den Hintergrund geht oder beendet wird
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { scene.saveProgress() }
        }
        #if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            scene.saveProgress()
        }
        // Tastatur: Pfeile, WASD, Leertaste, 1–4, Esc (siehe GameScene.handleKey). Kürzel mit ⌘ und
        // Texteingaben (Sound-Labor) bleiben unberührt.
        .onAppear {
            guard keyMonitor == nil else { return }
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
                if event.modifierFlags.contains(.command) || event.window?.firstResponder is NSText { return event }
                let handled = scene.handleKey(code: event.keyCode, characters: event.charactersIgnoringModifiers ?? "",
                                              shift: event.modifierFlags.contains(.shift), down: event.type == .keyDown)
                return handled ? nil : event
            }
        }
        .onDisappear {
            if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
            keyMonitor = nil
        }
        #endif
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
