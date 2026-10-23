#if os(iOS)
import UIKit

/// Ausrichtung nach Fenstergröße statt nach Gerät: Kleine Fenster (iPhone, Außendisplay der iPhone Duo) bleiben im
/// Hochformat, große (aufgeklappte iPhone Duo, iPad) drehen frei. Die Szene passt sich jeder Größe an und zeigt
/// das Spiel mittig, links und rechts füllt die Stadt den Platz.
enum ScreenFit {
    /// Ab dieser kürzeren Fensterseite (Punkte) gilt das Display als groß.
    static let largeSide: CGFloat = 600

    static func orientations(for size: CGSize?) -> UIInterfaceOrientationMask {
        guard let size, min(size.width, size.height) >= largeSide else { return .portrait }
        return .all
    }

    /// Nach Auf- oder Zuklappen bzw. Größenwechsel die erlaubten Ausrichtungen neu abfragen lassen.
    static func refresh() {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows {
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        ScreenFit.orientations(for: window?.bounds.size)
    }
}
#endif
