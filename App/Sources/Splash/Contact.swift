import RaptCore

/// Figuren, die dem Spieler per Funk Spezialsteine und Power-ups zustecken.
struct Contact: Equatable {
    enum Look: Equatable {
        case bob, bald, mohawk, bun, dog, robot
    }

    let id: String
    let name: String
    let look: Look
    let skin: UInt32
    let hair: UInt32
    let jacket: UInt32
    let accent: UInt32
    let voice: VoiceSpec
    let voiceSlot: SoundSlot

    static let kira = Contact(id: "kira", name: "KIRA", look: .bob, skin: 0xE8B58A, hair: 0x15121C, jacket: 0x1E2236, accent: 0x3FD8FF,
                              voice: VoiceSpec(pitch: 290, speed: 1.3, melody: 0.25, formant: 1.3, breath: 0.15), voiceSlot: .voiceKira)
    static let boris = Contact(id: "boris", name: "BORIS", look: .bald, skin: 0xC98A66, hair: 0x2A1D18, jacket: 0x3A2A22, accent: 0xFF8A3D,
                               voice: VoiceSpec(pitch: 95, speed: 0.85, melody: 0.1, formant: 0.88, breath: 0.08), voiceSlot: .voiceBoris)
    static let juki = Contact(id: "juki", name: "JUKI", look: .mohawk, skin: 0xF0C8A8, hair: 0xFF4FA8, jacket: 0xE8C23A, accent: 0xFF4FA8,
                              voice: VoiceSpec(pitch: 320, speed: 1.45, melody: 0.32, formant: 1.33, breath: 0.2), voiceSlot: .voiceJuki)
    static let zora = Contact(id: "zora", name: "MAMA ZORA", look: .bun, skin: 0xD9A27A, hair: 0xB8B8C8, jacket: 0x2A1238, accent: 0xB070FF,
                              voice: VoiceSpec(pitch: 215, speed: 0.95, melody: 0.16, vibrato: 0.04, formant: 1.16, breath: 0.25), voiceSlot: .voiceZora)
    static let k9 = Contact(id: "k9", name: "K-9", look: .dog, skin: 0x2A2226, hair: 0x15121C, jacket: 0x3A3A46, accent: 0x7AF0FF,
                            voice: VoiceSpec(style: .dog, pitch: 150), voiceSlot: .voiceK9)
    static let robo = Contact(id: "robo", name: "ROBO-7", look: .robot, skin: 0x8E94AA, hair: 0x585A67, jacket: 0x474854, accent: 0xFFD23A,
                              voice: VoiceSpec(style: .robot, pitch: 110, speed: 1, melody: 0, ring: 0.7), voiceSlot: .voiceRobo)

    static let all = [kira, boris, juki, zora, k9, robo]

    /// Wer welchen Spezialstein liefert.
    static func contact(for special: Special) -> Contact {
        switch special {
        case .line: return kira
        case .bomb: return boris
        case .hyper: return zora
        }
    }

    /// Wer welches Power-up liefert.
    static func contact(for powerUp: PowerUp) -> Contact {
        switch powerUp {
        case .bombe: return boris
        case .farbtilger: return juki
        case .strudel: return zora
        case .atom: return robo
        case .fresser: return k9
        }
    }

    /// Ausgedachte Cyber-Funksprache aus japanisch klingenden Silben.
    static func gibberish<G: RandomNumberGenerator>(using rng: inout G) -> [String] {
        let syllables = ["KA", "ZU", "RE", "MI", "NO", "TA", "SHI", "KO", "RI", "GA", "DO", "YU", "SE", "NE",
                         "TSU", "HA", "BI", "RO", "KYO", "ZEN", "MA", "TO", "JI", "SA"]
        func word() -> String {
            (0..<Int.random(in: 2...3, using: &rng)).map { _ in syllables.randomElement(using: &rng)! }.joined()
        }
        let endings = ["!", "...", "!!", ""]
        return [
            "\(word()) \(word())\(endings.randomElement(using: &rng)!)",
            "\(word())-\(word()) \(word())\(endings.randomElement(using: &rng)!)",
        ]
    }
}
