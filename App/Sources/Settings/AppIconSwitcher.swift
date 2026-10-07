#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Wechselt zwischen Standard-Icon (Frau mit Visor) und den alternativen Icons (rote Kugel, R-Logo).
/// iOS: echtes Alternativ-Icon auf dem Home-Bildschirm. Mac: nur das Dock-Symbol, solange Rapt läuft.
enum AppIconSwitcher {
    /// Index wie in den Einstellungen (0 = Standard): Name des Icon-Satzes und Bild fürs Mac-Dock.
    private static let alternates: [Int: (icon: String, dock: String)] = [
        1: ("AppIconAlt", "IconAltImage"),
        2: ("AppIconAlt2", "IconAlt2Image"),
    ]

    static func apply(_ choice: Int) {
        DispatchQueue.main.async {
            #if os(iOS)
            let wanted = alternates[choice]?.icon
            guard UIApplication.shared.supportsAlternateIcons,
                  UIApplication.shared.alternateIconName != wanted else { return }
            UIApplication.shared.setAlternateIconName(wanted) { error in
                if let error { print("App-Icon nicht gewechselt: \(error.localizedDescription)") }
            }
            #else
            NSApplication.shared.applicationIconImage = alternates[choice].flatMap { NSImage(named: $0.dock) }
            #endif
        }
    }
}
