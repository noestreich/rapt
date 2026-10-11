import Foundation
import GameKit
import RaptCore
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Game Center: Bestenlisten und Erfolge. Die IDs müssen in App Store Connect angelegt sein (siehe README);
/// solange sie fehlen oder niemand angemeldet ist, passiert einfach nichts.
/// Zum Abschalten `enabled` auf `false` setzen.
enum GameCenter {
    static let enabled = true

    enum Board: String {
        case rooftop = "de.ncls.rapt.rooftop"
        case endless = "de.ncls.rapt.endless"
        /// Wiederkehrende Bestenliste, täglich neu.
        case daily = "de.ncls.rapt.daily"
    }

    enum Achievement: String, CaseIterable {
        case jump10 = "de.ncls.rapt.jump10"
        case jump25 = "de.ncls.rapt.jump25"
        case cascade5 = "de.ncls.rapt.cascade5"
        case orders10 = "de.ncls.rapt.orders10"
        case minigames = "de.ncls.rapt.minigames"
        case album = "de.ncls.rapt.album"
        case streak7 = "de.ncls.rapt.streak7"
    }

    static var isAuthenticated: Bool { enabled && GKLocalPlayer.local.isAuthenticated }

    /// Beim Start anmelden; zeigt bei Bedarf einmal das Anmeldefenster von Game Center.
    static func authenticate(onChange: @escaping () -> Void = {}) {
        guard enabled else { return }
        GKLocalPlayer.local.authenticateHandler = { controller, _ in
            if let controller { present(controller) }
            onChange()
        }
    }

    static func submit(_ score: Int, to board: Board) {
        guard isAuthenticated, score > 0 else { return }
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [board.rawValue]) { _ in }
    }

    // MARK: Erfolge

    private static let doneKey = "rapt.gc.done"

    /// Meldet Fortschritt (0…100). Vollständige Erfolge werden nur einmal gemeldet.
    static func report(_ achievement: Achievement, percent: Double = 100) {
        guard isAuthenticated else { return }
        let done = Set(UserDefaults.standard.stringArray(forKey: doneKey) ?? [])
        guard !done.contains(achievement.rawValue) else { return }
        let a = GKAchievement(identifier: achievement.rawValue)
        a.percentComplete = min(100, max(0, percent))
        a.showsCompletionBanner = true
        GKAchievement.report([a]) { error in
            guard error == nil, percent >= 100 else { return }
            DispatchQueue.main.async {
                var stored = Set(UserDefaults.standard.stringArray(forKey: doneKey) ?? [])
                stored.insert(achievement.rawValue)
                UserDefaults.standard.set(Array(stored), forKey: doneKey)
            }
        }
    }

    // Zähler über alle Spiele hinweg
    private static let ordersKey = "rapt.gc.orders"
    private static let minigamesKey = "rapt.gc.minigames"
    /// Alle Minispiele samt Sternenbahn.
    static let minigameKinds = PowerUp.allCases.filter(\.isArcade).map(\.rawValue) + ["sternenbahn"]

    static func orderCompleted() {
        let n = UserDefaults.standard.integer(forKey: ordersKey) + 1
        UserDefaults.standard.set(n, forKey: ordersKey)
        report(.orders10, percent: Double(n) / 10 * 100)
    }

    static func minigamePlayed(_ key: String) {
        var played = Set(UserDefaults.standard.stringArray(forKey: minigamesKey) ?? [])
        guard played.insert(key).inserted else { return }
        UserDefaults.standard.set(Array(played), forKey: minigamesKey)
        let known = played.intersection(minigameKinds).count
        report(.minigames, percent: Double(known) / Double(minigameKinds.count) * 100)
    }

    // MARK: Oberfläche

    #if os(iOS)
    private final class Dismisser: NSObject, GKGameCenterControllerDelegate {
        func gameCenterViewControllerDidFinish(_ controller: GKGameCenterViewController) {
            controller.dismiss(animated: true)
        }
    }
    private static let dismisser = Dismisser()

    private static func present(_ controller: UIViewController) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        var top = scenes.flatMap(\.windows).first { $0.isKeyWindow }?.rootViewController
        while let next = top?.presentedViewController { top = next }
        top?.present(controller, animated: true)
    }
    #else
    private final class Dismisser: NSObject, GKGameCenterControllerDelegate {
        func gameCenterViewControllerDidFinish(_ controller: GKGameCenterViewController) {
            GKDialogController.shared().dismiss(controller)
        }
    }
    private static let dismisser = Dismisser()

    private static func present(_ controller: NSViewController) {
        let window = NSApp.keyWindow ?? NSApp.windows.first
        if let gameKit = controller as? NSViewController & GKViewController {
            let dialog = GKDialogController.shared()
            dialog.parentWindow = window
            dialog.present(gameKit)
        } else {
            window?.contentViewController?.presentAsSheet(controller)
        }
    }
    #endif

    /// Bestenlisten von Game Center zeigen.
    static func showLeaderboards() {
        guard isAuthenticated else { return }
        let controller = GKGameCenterViewController(state: .leaderboards)
        controller.gameCenterDelegate = dismisser
        present(controller)
    }
}
