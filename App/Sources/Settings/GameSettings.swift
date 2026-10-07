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
    @Published var hintsEnabled: Bool { didSet { save(hintsEnabled, "hintsEnabled") } }
    /// Plasma-Feuer am linken Rand im Dächerlauf.
    @Published var fireEnabled: Bool { didSet { save(fireEnabled, "fireEnabled") } }
    /// Gewähltes App-Icon: 0 = Standard (rote Kugel), 1 = Porträt, 2 = R-Logo.
    @Published var appIcon: Int {
        didSet {
            save(appIcon, "appIcon")
            AppIconSwitcher.apply(appIcon)
        }
    }
    /// Debug-Regler (Tempo, Beschleunigung) sichtbar. Beim Ausblenden gelten wieder die Standardwerte.
    @Published var debugVisible: Bool {
        didSet {
            save(debugVisible, "debugVisible")
            if !debugVisible {
                debugCitySpeed = City.baseSpeed
                debugCityAcceleration = City.defaultAccelerationPerMinute
            }
        }
    }
    /// Debug-Zeile in den Einstellungen freigeschaltet (5 s auf die Überschrift). Nur bis zum Beenden der App.
    var debugUnlocked = false
    /// Debug: Beschleunigung der Stadt pro Spielminute (0,1 = +10 %).
    @Published var debugCityAcceleration: Double { didSet { save(debugCityAcceleration, "debugCityAcceleration") } }
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
            "rapt.hintsEnabled": false,
            "rapt.fireEnabled": true,
            "rapt.debugCityAcceleration": City.defaultAccelerationPerMinute,
            "rapt.debugVisible": false,
            "rapt.appIcon": 0,
        ])
        soundEnabled = defaults.bool(forKey: "rapt.soundEnabled")
        soundVolume = defaults.double(forKey: "rapt.soundVolume")
        musicEnabled = defaults.bool(forKey: "rapt.musicEnabled")
        musicVolume = defaults.double(forKey: "rapt.musicVolume")
        hapticsEnabled = defaults.bool(forKey: "rapt.hapticsEnabled")
        splashesEnabled = defaults.bool(forKey: "rapt.splashesEnabled")
        debugCitySpeed = defaults.double(forKey: "rapt.debugCitySpeed")
        hintsEnabled = defaults.bool(forKey: "rapt.hintsEnabled")
        fireEnabled = defaults.bool(forKey: "rapt.fireEnabled")
        // Debug-Regler starten immer aus; sie sind nur nach dem Freischalten erreichbar
        debugVisible = false
        debugCityAcceleration = defaults.double(forKey: "rapt.debugCityAcceleration")
        appIcon = defaults.integer(forKey: "rapt.appIcon")
    }

    /// Grundgeschwindigkeit, mit der das Spiel tatsächlich läuft: im Debug-Build vom Schieber, sonst der Standard.
    var citySpeed: Double { debugVisible ? debugCitySpeed : City.baseSpeed }

    /// Beschleunigung pro Minute, mit der das Spiel tatsächlich läuft.
    var cityAcceleration: Double { debugVisible ? debugCityAcceleration : City.defaultAccelerationPerMinute }

    private func save(_ value: Any, _ key: String) {
        UserDefaults.standard.set(value, forKey: "rapt." + key)
    }
}
