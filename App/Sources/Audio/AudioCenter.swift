import Combine
import Foundation

/// Gemeinsamer Zugang zu Effekten, Musik und Dateizuordnung, damit Spiel und Sound-Labor
/// dieselben Instanzen nutzen und Änderungen sofort im laufenden Spiel ankommen.
final class AudioCenter {
    static let shared = AudioCenter()

    let library = SoundLibrary()
    let effects: SoundBank
    let music: MusicPlayer
    private var subscriptions: Set<AnyCancellable> = []

    private init() {
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
        settings.$musicEnabled.sink { [weak self] value in self?.music.isEnabled = value }.store(in: &subscriptions)
        settings.$musicVolume.sink { [weak self] value in self?.music.volume = Float(value) }.store(in: &subscriptions)
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
