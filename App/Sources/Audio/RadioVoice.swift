import Foundation

/// Unverständliche Funksprüche: Silben aus Vokal-Formanten, danach Walkie-Talkie-Klang
/// (Bandpass, Verzerrung, Bitreduktion, Rauschen, Rauschsperren-Klicken).
enum RadioVoice {
    private struct Resonator {
        var y1 = 0.0, y2 = 0.0
        var b1 = 0.0, b2 = 0.0, gain = 0.0

        mutating func tune(_ frequency: Double, bandwidth: Double, sampleRate: Double) {
            let r = exp(-.pi * bandwidth / sampleRate)
            b1 = 2 * r * cos(2 * .pi * frequency / sampleRate)
            b2 = -r * r
            gain = 1 - r
        }

        mutating func process(_ x: Double) -> Double {
            let y = gain * x + b1 * y1 + b2 * y2
            y2 = y1
            y1 = y
            return y
        }
    }

    /// Formanten (F1, F2) der Vokale a, e, i, o, u.
    private static let vowels: [(Double, Double)] = [(800, 1200), (450, 1900), (300, 2300), (500, 900), (350, 800)]

    static func babble(pitch: Double, speed: Double, melody: Double, vibrato: Double, ring: Double,
                       sampleRate: Double, seed: UInt64) -> [Float] {
        var rng = SplitMix64Local(seed: seed)
        var out: [Float] = []
        var phase = 0.0, ringPhase = 0.0
        var f1 = Resonator(), f2 = Resonator()
        let syllables = 5 + Int(rng.unit() * 5)
        for s in 0..<syllables {
            let length = (0.07 + rng.unit() * 0.06) / speed
            let n = Int(length * sampleRate)
            let vowel = vowels[Int(rng.unit() * Double(vowels.count)) % vowels.count]
            // Satzmelodie: leicht fallend, mit Sprüngen pro Silbe
            let contour = 1 + melody * (rng.unit() - 0.5) * 2 - 0.08 * Double(s) / Double(syllables)
            let consonant = rng.unit() < 0.6
            f1.tune(vowel.0, bandwidth: 90, sampleRate: sampleRate)
            f2.tune(vowel.1, bandwidth: 120, sampleRate: sampleRate)
            var syllable: [Double] = []
            syllable.reserveCapacity(n)
            for i in 0..<n {
                let t = Double(i) / sampleRate
                let f0 = pitch * contour * (1 + vibrato * sin(t * 2 * .pi * 6))
                phase += f0 / sampleRate
                let saw = 2 * (phase - floor(phase)) - 1
                var x = f1.process(saw) * 1.0 + f2.process(saw) * 0.6
                if consonant && t < 0.018 {
                    x = (rng.unit() * 2 - 1) * 0.35 * (1 - t / 0.018)
                }
                let env = min(1, t / 0.01) * min(1, (length - t) / 0.02)
                if ring > 0 {
                    ringPhase += 55 / sampleRate
                    x *= (1 - ring) + ring * sin(2 * .pi * ringPhase * 6)
                }
                syllable.append(x * env)
            }
            // Resonatoren verstärken je nach Vokal sehr unterschiedlich: pro Silbe normalisieren
            let peak = max(0.0001, syllable.map(abs).max() ?? 1)
            let level = 0.55 + rng.unit() * 0.25
            out.append(contentsOf: syllable.map { Float($0 / peak * level) })
            // kleine Pause zwischen Silben, manchmal länger (Wortgrenze)
            let gap = Int((rng.unit() < 0.25 ? 0.07 : 0.015) / speed * sampleRate)
            out.append(contentsOf: [Float](repeating: 0, count: gap))
        }
        return out
    }

    /// Walkie-Talkie-Klang. Davor und dahinter ein Rauschsperren-Klicken mit kurzem Rauschen.
    static func radio(_ input: [Float], sampleRate: Double = 44_100) -> [Float] {
        var rng = SplitMix64Local(seed: UInt64(input.count) &* 2_654_435_761)
        let squelch = Int(0.06 * sampleRate)
        var out = [Float](repeating: 0, count: squelch)
        // Klicken und Rauschstoß beim Drücken der Sendetaste
        for i in 0..<squelch {
            let t = Double(i) / Double(squelch)
            out[i] = Float((rng.unit() * 2 - 1) * 0.35 * (1 - t) + (i < 40 ? 0.6 : 0))
        }
        var hp = 0.0, lp1 = 0.0, lp2 = 0.0, last = 0.0
        let aHigh = exp(-2 * .pi * 450 / sampleRate)
        let aLow = 1 - exp(-2 * .pi * 2800 / sampleRate)
        var held = 0.0
        for (i, sample) in input.enumerated() {
            let x = Double(sample)
            hp = aHigh * (hp + x - last)
            last = x
            lp1 += aLow * (hp - lp1)
            lp2 += aLow * (lp1 - lp2)
            var y = tanh(lp2 * 2.6)
            if i % 3 == 0 { held = (y * 20).rounded() / 20 }
            y = held + (rng.unit() * 2 - 1) * 0.025
            out.append(Float(y * 0.8))
        }
        // Loslassen der Sendetaste
        for i in 0..<squelch {
            let t = Double(i) / Double(squelch)
            out.append(Float((rng.unit() * 2 - 1) * 0.3 * (1 - t) + (i < 30 ? -0.5 : 0)))
        }
        return out
    }
}

/// Kleiner Zufallsgenerator, damit diese Datei ohne Spiellogik-Import auskommt.
private struct SplitMix64Local {
    var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func unit() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return Double((z ^ (z >> 31)) >> 11) / Double(UInt64(1) << 53)
    }
}
