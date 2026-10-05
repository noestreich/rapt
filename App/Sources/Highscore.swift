import Foundation
import RaptCore

/// Rekord pro Spielmodus.
enum Highscore {
    private static func key(_ mode: GameMode) -> String {
        mode == .endless ? "rapt.highscore" : "rapt.highscore.\(mode.rawValue)"
    }

    static func load(_ mode: GameMode) -> Int {
        UserDefaults.standard.integer(forKey: key(mode))
    }

    static func save(_ value: Int, for mode: GameMode) {
        UserDefaults.standard.set(value, forKey: key(mode))
    }
}
