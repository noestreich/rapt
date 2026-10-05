import Foundation
import RaptCore

/// Einstellungen, die das Spiel über Neustarts behält.
final class GameSettings: ObservableObject {
    static let shared = GameSettings()

    @Published var soundEnabled: Bool { didSet { save(soundEnabled, "soundEnabled") } }
    @Published var soundVolume: Double { didSet { save(soundVolume, "soundVolume") } }
    @Published var musicEnabled: Bool { didSet { save(musicEnabled, "musicEnabled") } }
    @Published var musicVolume: Double { didSet { save(musicVolume, "musicVolume") } }
    @Published var hapticsEnabled: Bool { didSet { save(hapticsEnabled, "hapticsEnabled") } }
    @Published var splashesEnabled: Bool { didSet { save(splashesEnabled, "splashesEnabled") } }
    /// Debug: Grundgeschwindigkeit der Stadt im Dächerlauf (Design-Pixel pro Sekunde).
    @Published var debugCitySpeed: Double { didSet { save(debugCitySpeed, "debugCitySpeed") } }

    private init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            "rapt.soundEnabled": true,
            "rapt.soundVolume": 1.0,
            "rapt.musicEnabled": true,
            "rapt.musicVolume": 0.6,
            "rapt.hapticsEnabled": true,
            "rapt.splashesEnabled": true,
            "rapt.debugCitySpeed": City.baseSpeed,
        ])
        soundEnabled = defaults.bool(forKey: "rapt.soundEnabled")
        soundVolume = defaults.double(forKey: "rapt.soundVolume")
        musicEnabled = defaults.bool(forKey: "rapt.musicEnabled")
        musicVolume = defaults.double(forKey: "rapt.musicVolume")
        hapticsEnabled = defaults.bool(forKey: "rapt.hapticsEnabled")
        splashesEnabled = defaults.bool(forKey: "rapt.splashesEnabled")
        debugCitySpeed = defaults.double(forKey: "rapt.debugCitySpeed")
    }

    /// Grundgeschwindigkeit, mit der das Spiel tatsächlich läuft: im Debug-Build vom Schieber, sonst der Standard.
    var citySpeed: Double {
        #if DEBUG
        return debugCitySpeed
        #else
        return City.baseSpeed
        #endif
    }

    private func save(_ value: Any, _ key: String) {
        UserDefaults.standard.set(value, forKey: "rapt." + key)
    }
}
