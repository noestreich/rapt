import Foundation
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
    /// Sound-Labor-Platz für eigene Aufnahmen. Varianten haben keinen und sprechen immer mit dem Synthesizer.
    let voiceSlot: SoundSlot?

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

    // MARK: Varianten

    /// Stimmvorlagen für Varianten, Schlüssel wie im Dateinamen.
    static let voicePresets: [String: VoiceSpec] = [
        "mann": VoiceSpec(pitch: 110, speed: 0.95, melody: 0.12, formant: 0.92, breath: 0.08),
        "mann-tief": VoiceSpec(pitch: 85, speed: 0.85, melody: 0.1, formant: 0.85, breath: 0.08),
        "frau": VoiceSpec(pitch: 210, speed: 1.0, melody: 0.18, formant: 1.15, breath: 0.2),
        "maedchen": VoiceSpec(pitch: 300, speed: 1.35, melody: 0.28, formant: 1.3, breath: 0.15),
        "junge": VoiceSpec(pitch: 250, speed: 1.3, melody: 0.25, formant: 1.22, breath: 0.12),
        "alt": VoiceSpec(pitch: 150, speed: 0.85, melody: 0.14, vibrato: 0.06, formant: 1.05, breath: 0.3),
        "hund": VoiceSpec(style: .dog, pitch: 150),
        "katze": VoiceSpec(style: .cat, pitch: 420, breath: 0.12),
        "roboter": VoiceSpec(style: .robot, pitch: 110, speed: 1, melody: 0, ring: 0.7),
    ]

    /// Alternative Porträts aus dem Bundle: `portrait_<kontakt>--<name>--<stimme>.png`,
    /// z. B. `portrait_boris--ivan--mann-tief.png`. Sie vertreten den Kontakt zufällig.
    static let variants: [String: [Contact]] = {
        var out: [String: [Contact]] = [:]
        let files = Bundle.main.urls(forResourcesWithExtension: "png", subdirectory: nil) ?? []
        for url in files {
            let stem = url.deletingPathExtension().lastPathComponent
            guard stem.hasPrefix("portrait_") else { continue }
            let parts = stem.dropFirst("portrait_".count).components(separatedBy: "--")
            guard parts.count == 3, let base = all.first(where: { $0.id == parts[0] }) else { continue }
            let voice = voicePresets[parts[2]] ?? base.voice
            let name = parts[1].replacingOccurrences(of: "-", with: " ").uppercased()
            let variant = Contact(id: String(stem.dropFirst("portrait_".count)), name: name, look: base.look,
                                  skin: base.skin, hair: base.hair, jacket: base.jacket, accent: base.accent,
                                  voice: voice, voiceSlot: nil)
            out[base.id, default: []].append(variant)
        }
        return out
    }()

    static var allWithVariants: [Contact] { all + all.flatMap { variants[$0.id] ?? [] } }

    /// Kontakt oder eine seiner Varianten, zufällig.
    static func random(for base: Contact) -> Contact {
        ([base] + (variants[base.id] ?? [])).randomElement() ?? base
    }

    // MARK: Wer hält was in der Hand

    /// Aus `portraits.json` (tools/import_portraits.py, ein Ordner je Teil): Schlüssel des Teils → Porträt-IDs.
    static let holders: [String: [String]] = {
        guard let url = Bundle.main.url(forResource: "portraits", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let map = try? JSONDecoder().decode([String: [String]].self, from: data) else { return [:] }
        return map
    }()

    static func itemKey(_ special: Special) -> String {
        switch special {
        case .line: return "linienstein"
        case .bomb: return "bombenstein"
        case .hyper: return "hyperstein"
        }
    }

    /// Zufälliges Porträt, das genau dieses Teil in der Hand hält; ohne Zuordnung der zuständige Kontakt.
    static func random(holding key: String, fallback: Contact) -> Contact {
        // Ohne eigene Porträts (z. B. neue Power-ups) spricht der zuständige Kontakt selbst
        guard let ids = holders[key] else { return fallback }
        return allWithVariants.filter { ids.contains($0.id) }.randomElement() ?? fallback
    }

    static func random(delivering special: Special) -> Contact {
        random(holding: itemKey(special), fallback: contact(for: special))
    }

    static func random(delivering powerUp: PowerUp) -> Contact {
        random(holding: powerUp.rawValue, fallback: contact(for: powerUp))
    }

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
        case .invasion: return kira
        case .abriss: return boris
        }
    }

    /// Ausgedachte Cyber-Funksprache in Katakana: zufällige Silbenfolgen, keine echten Sätze.
    static func gibberish<G: RandomNumberGenerator>(using rng: inout G) -> [String] {
        let kana = Array("カキコサシスタツトナニネノハマミユリレロイ")
        func word() -> String {
            var w = String((0..<Int.random(in: 2...3, using: &rng)).map { _ in kana.randomElement(using: &rng)! })
            if Int.random(in: 0..<4, using: &rng) == 0 { w += "ー" }
            if Int.random(in: 0..<4, using: &rng) == 0 { w += "ン" }
            return w
        }
        let endings = ["!", "...", "!!", ""]
        return [
            "\(word()) \(word())\(endings.randomElement(using: &rng)!)",
            "\(word()) \(word()) \(word())\(endings.randomElement(using: &rng)!)",
        ]
    }
}
