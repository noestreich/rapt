#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Wechselt zwischen Standard-Icon (rote Kugel) und alternativem Icon (Porträt).
/// iOS: echtes Alternativ-Icon auf dem Home-Bildschirm. Mac: nur das Dock-Symbol, solange Rapt läuft.
enum AppIconSwitcher {
    static let alternateName = "AppIconAlt"

    static func apply(_ choice: Int) {
        DispatchQueue.main.async {
            #if os(iOS)
            let wanted = choice == 1 ? alternateName : nil
            guard UIApplication.shared.supportsAlternateIcons,
                  UIApplication.shared.alternateIconName != wanted else { return }
            UIApplication.shared.setAlternateIconName(wanted) { error in
                if let error { print("App-Icon nicht gewechselt: \(error.localizedDescription)") }
            }
            #else
            NSApplication.shared.applicationIconImage = choice == 1 ? NSImage(named: "IconAltImage") : nil
            #endif
        }
    }
}
