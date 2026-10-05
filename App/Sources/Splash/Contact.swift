import RaptCore

/// Figuren, die dem Spieler per Funk Spezialsteine und Power-ups zustecken.
struct Contact: Equatable {
    enum Look: Equatable {
        case bob, bald, mohawk, bun, dog, robot
    }

    struct Voice: Equatable {
        /// Grundtonhöhe in Hz.
        let pitch: Double
        /// 1 = normal, größer = schneller.
        let speed: Double
        /// Tonhöhenschwankung pro Silbe (0 = monoton).
        let melody: Double
        let vibrato: Double
        /// Ringmodulation für metallische Stimmen.
        let ring: Double
    }

    let id: String
    let name: String
    let look: Look
    let skin: UInt32
    let hair: UInt32
    let jacket: UInt32
    let accent: UInt32
    let voice: Voice
    let voiceSlot: SoundSlot

    static let kira = Contact(id: "kira", name: "KIRA", look: .bob, skin: 0xE8B58A, hair: 0x15121C, jacket: 0x1E2236, accent: 0x3FD8FF,
                              voice: Voice(pitch: 230, speed: 1.25, melody: 0.18, vibrato: 0, ring: 0), voiceSlot: .voiceKira)
    static let boris = Contact(id: "boris", name: "BORIS", look: .bald, skin: 0xC98A66, hair: 0x2A1D18, jacket: 0x3A2A22, accent: 0xFF8A3D,
                               voice: Voice(pitch: 92, speed: 0.85, melody: 0.1, vibrato: 0, ring: 0), voiceSlot: .voiceBoris)
    static let juki = Contact(id: "juki", name: "JUKI", look: .mohawk, skin: 0xF0C8A8, hair: 0xFF4FA8, jacket: 0xE8C23A, accent: 0xFF4FA8,
                              voice: Voice(pitch: 275, speed: 1.4, melody: 0.25, vibrato: 0, ring: 0), voiceSlot: .voiceJuki)
    static let zora = Contact(id: "zora", name: "MAMA ZORA", look: .bun, skin: 0xD9A27A, hair: 0xB8B8C8, jacket: 0x2A1238, accent: 0xB070FF,
                              voice: Voice(pitch: 175, speed: 0.9, melody: 0.14, vibrato: 0.05, ring: 0), voiceSlot: .voiceZora)
    static let k9 = Contact(id: "k9", name: "K-9", look: .dog, skin: 0x2A2226, hair: 0x15121C, jacket: 0x3A3A46, accent: 0x7AF0FF,
                            voice: Voice(pitch: 140, speed: 1.15, melody: 0.3, vibrato: 0, ring: 0.3), voiceSlot: .voiceK9)
    static let robo = Contact(id: "robo", name: "ROBO-7", look: .robot, skin: 0x8E94AA, hair: 0x585A67, jacket: 0x474854, accent: 0xFFD23A,
                              voice: Voice(pitch: 118, speed: 1.0, melody: 0, vibrato: 0, ring: 0.8), voiceSlot: .voiceRobo)

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
