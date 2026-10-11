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
    private static let dailyKey = "rapt.savedGame.daily"

    /// `daily`: Tag des Tageslaufs, sonst `nil`.
    static func save(_ game: Game, daily: String?) {
        guard let data = try? JSONEncoder().encode(game.snapshot) else { return }
        UserDefaults.standard.set(data, forKey: key)
        UserDefaults.standard.set(daily, forKey: dailyKey)
    }

    static func load() -> (game: Game, daily: String?)? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(GameSnapshot.self, from: data),
              let game = Game(snapshot: snapshot) else { return nil }
        return (game, UserDefaults.standard.string(forKey: dailyKey))
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: dailyKey)
    }
}

/// Tageslauf: ein Dächerlauf mit festem Brett und fester Stadt pro Kalendertag (für alle gleich),
/// eigener Tagesbestwert und eine Serie aufeinanderfolgender Spieltage.
enum DailyRun {
    private static let lastKey = "rapt.daily.last"
    private static let streakKey = "rapt.daily.streak"

    private static func formatter() -> DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    /// Heutiger Tag als „2026-10-11“ (Ortszeit).
    static func today(_ date: Date = Date()) -> String {
        formatter().string(from: date)
    }

    private static func dayBefore(_ day: String) -> String? {
        let f = formatter()
        guard let date = f.date(from: day), let before = Calendar(identifier: .gregorian).date(byAdding: .day, value: -1, to: date)
        else { return nil }
        return f.string(from: before)
    }

    /// Fester Seed für den Tag (FNV-1a über den Text), auf jedem Gerät gleich.
    static func seed(for day: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in "rapt-tageslauf-\(day)".utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        return hash
    }

    static func best(_ day: String) -> Int {
        UserDefaults.standard.integer(forKey: "rapt.daily.best.\(day)")
    }

    static func saveBest(_ score: Int, day: String) {
        guard score > best(day) else { return }
        UserDefaults.standard.set(score, forKey: "rapt.daily.best.\(day)")
    }

    /// Serie: zählt, solange zuletzt heute oder gestern gespielt wurde.
    static var streak: Int {
        let defaults = UserDefaults.standard
        let today = DailyRun.today()
        guard let last = defaults.string(forKey: lastKey), last == today || last == dayBefore(today) else { return 0 }
        return defaults.integer(forKey: streakKey)
    }

    /// Beim Start eines Tageslaufs: Serie fortsetzen, neu beginnen oder (heute schon gespielt) stehen lassen.
    static func markPlayed(_ day: String) {
        let defaults = UserDefaults.standard
        let last = defaults.string(forKey: lastKey)
        guard last != day else { return }
        let next = last != nil && last == dayBefore(day) ? defaults.integer(forKey: streakKey) + 1 : 1
        defaults.set(next, forKey: streakKey)
        defaults.set(day, forKey: lastKey)
    }
}
