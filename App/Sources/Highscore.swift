import Foundation

enum Highscore {
    private static let key = "rapt.highscore"

    static func load() -> Int {
        UserDefaults.standard.integer(forKey: key)
    }

    static func save(_ value: Int) {
        UserDefaults.standard.set(value, forKey: key)
    }
}
