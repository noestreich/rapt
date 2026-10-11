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

/// Laufendes Spiel zum Fortsetzen nach einem Neustart der App (JSON in den UserDefaults).
enum SavedGame {
    private static let key = "rapt.savedGame"

    static func save(_ game: Game) {
        guard let data = try? JSONEncoder().encode(game.snapshot) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> Game? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(GameSnapshot.self, from: data) else { return nil }
        return Game(snapshot: snapshot)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
