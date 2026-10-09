import AVFoundation
import Combine
import Foundation
#if os(iOS)
import UIKit
#endif

/// Gemeinsamer Zugang zu Effekten, Musik und Dateizuordnung, damit Spiel und Sound-Labor
/// dieselben Instanzen nutzen und Änderungen sofort im laufenden Spiel ankommen.
final class AudioCenter {
    static let shared = AudioCenter()

    let library = SoundLibrary()
    let effects: SoundBank
    let music: MusicPlayer
    private var subscriptions: Set<AnyCancellable> = []

    private init() {
        // Zuerst den Audio-Modus setzen und darauf warten: Die Effekt-Engine startet gleich beim Anlegen, und ohne
        // gesetzten Modus nimmt iOS den Standard (nur diese App), der Musik oder Podcasts anderer Apps anhält.
        Self.configureSession(musicOn: GameSettings.shared.musicEnabled, wait: true)
        effects = SoundBank(library: library)
        music = MusicPlayer(library: library)

        NotificationCenter.default.publisher(for: SoundLibrary.didChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.effects.reload()
                self?.music.reload()
            }
            .store(in: &subscriptions)

        let settings = GameSettings.shared
        settings.$soundEnabled.sink { [weak self] value in self?.effects.isEnabled = value }.store(in: &subscriptions)
        settings.$soundVolume.sink { [weak self] value in self?.effects.masterVolume = Float(value) }.store(in: &subscriptions)
        settings.$musicEnabled.sink { [weak self] value in
            Self.configureSession(musicOn: value)
            self?.music.isEnabled = value
        }.store(in: &subscriptions)
        settings.$musicVolume.sink { [weak self] value in self?.music.volume = Float(value) }.store(in: &subscriptions)

        effects.onStartFailure = { [weak self] in self?.resumeAfterInterruption() }

        #if os(iOS)
        // Hat eine andere App den Ton übernommen (z. B. Spracheingabe, Anruf), stoppt iOS unsere Engines. Danach die
        // Audio-Sitzung neu aktivieren und die Effekte sicher neu starten – sonst bleibt nur die Musik hörbar.
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      AVAudioSession.InterruptionType(rawValue: raw) == .ended else { return }
                self?.resumeAfterInterruption()
            }
            .store(in: &subscriptions)
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.resumeAfterInterruption() }
            .store(in: &subscriptions)
        #endif
    }

    /// Audio-Sitzung wieder aktivieren (im Hintergrund), danach die Effekt-Engine neu starten.
    private func resumeAfterInterruption() {
        Self.configureSession(musicOn: GameSettings.shared.musicEnabled) { [weak self] in
            self?.effects.resume()
        }
    }

    /// iPhone: Mit Spielmusik spielt nur das Spiel. Ohne Spielmusik mischen sich die Effekte mit Musik oder
    /// Podcasts aus anderen Apps, die dann ungestört weiterlaufen.
    /// Läuft im Hintergrund: Apple warnt, dass diese Aufrufe im Haupt-Thread die Oberfläche blockieren können.
    private static let sessionQueue = DispatchQueue(label: "de.ncls.rapt.audiosession", qos: .userInitiated)

    /// `wait`: die Kategorie sofort setzen (beim Start, bevor eine Engine läuft). Das Aktivieren läuft immer im
    /// Hintergrund, denn `setActive` im Haupt-Thread kann die Oberfläche blockieren (Warnung von iOS).
    /// `then`: läuft danach im Haupt-Thread (z. B. Engine neu starten, sobald die Sitzung aktiv ist).
    private static func configureSession(musicOn: Bool, wait: Bool = false, then completion: (() -> Void)? = nil) {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        let setCategory = {
            if musicOn {
                try? session.setCategory(.soloAmbient)
            } else {
                try? session.setCategory(.ambient, options: [.mixWithOthers])
            }
        }
        if wait { setCategory() }
        sessionQueue.async {
            if !wait { setCategory() }
            try? session.setActive(true)
            if let completion { DispatchQueue.main.async(execute: completion) }
        }
        #else
        completion?()
        #endif
    }

    /// Probehören im Sound-Labor. Treffer werden als kleine Kaskade vorgespielt.
    func preview(_ slot: SoundSlot) {
        switch slot {
        case .music:
            music.isEnabled.toggle()
        case .danger:
            effects.setDanger(1)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in self?.effects.setDanger(0) }
        case .match:
            for step in 0..<4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * 0.28) { [weak self] in
                    self?.effects.match(step: step)
                }
            }
        default:
            if slot.isVoice, let contact = Contact.all.first(where: { $0.voiceSlot == slot }) {
                speak(contact)
            } else {
                effects.play(slot)
            }
        }
    }

    func speak(_ contact: Contact) {
        effects.voice(contact.voiceSlot, spec: contact.voice)
    }
}
