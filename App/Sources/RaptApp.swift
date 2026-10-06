import SwiftUI

@main
struct RaptApp: App {
    #if os(macOS)
    init() {
        // Dock-Symbol gilt auf dem Mac nur zur Laufzeit, daher beim Start erneut setzen
        AppIconSwitcher.apply(GameSettings.shared.appIcon)
    }
    #endif

    var body: some Scene {
        WindowGroup {
            GameView()
        }
        #if os(macOS)
        .defaultSize(width: 440, height: 800)
        #endif
        #if os(macOS) && DEBUG
        .commands { DeveloperCommands() }
        #endif

        #if os(macOS) && DEBUG
        Window("Sound-Labor", id: SoundLabView.windowID) {
            SoundLabView()
        }
        .defaultSize(width: 760, height: 720)
        #endif
    }
}

#if os(macOS) && DEBUG
/// Menü „Entwickler“, nur in Debug-Builds auf dem Mac.
struct DeveloperCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("Entwickler") {
            Button("Sound-Labor öffnen") { openWindow(id: SoundLabView.windowID) }
                .keyboardShortcut("l", modifiers: [.command, .shift])
        }
    }
}
#endif
