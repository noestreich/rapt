import Foundation

/// Stimmcharakter eines Funkers.
struct VoiceSpec: Equatable {
    enum Style: Equatable { case human, dog, cat, robot }

    var style: Style = .human
    /// Grundtonhöhe in Hz.
    var pitch: Double
    /// 1 = normal, größer = schneller.
    var speed: Double = 1
    /// Tonhöhenschwankung pro Silbe (0 = monoton).
    var melody: Double = 0.15
    var vibrato: Double = 0
    /// Formant-Verschiebung: 0,9 tiefe Männerstimme, 1,15 Frau, 1,3 Mädchen.
    var formant: Double = 1
    /// Hauchanteil 0 … 1.
    var breath: Double = 0.1
    /// Ringmodulation für metallischen Klang.
    var ring: Double = 0
}

/// Unverständliche Funksprüche: Silben aus Vokal-Formanten (Mensch), Bellen und Knurren (Hund), Miauen und Schnurren (Katze) oder
/// Tonstufen mit Piepsern (Roboter), danach Walkie-Talkie-Klang
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

    static func babble(_ voice: VoiceSpec, sampleRate: Double, seed: UInt64) -> [Float] {
        var rng = SplitMix64Local(seed: seed)
        switch voice.style {
        case .human: return human(voice, sampleRate: sampleRate, rng: &rng)
        case .dog: return dog(voice, sampleRate: sampleRate, rng: &rng)
        case .cat: return cat(voice, sampleRate: sampleRate, rng: &rng)
        case .robot: return robot(voice, sampleRate: sampleRate, rng: &rng)
        }
    }

    /// Normalisiert ein Stück auf `level` und hängt es an.
    private static func append(_ part: [Double], to out: inout [Float], level: Double) {
        let peak = max(0.0001, part.map(abs).max() ?? 1)
        out.append(contentsOf: part.map { Float($0 / peak * level) })
    }

    private static func silence(_ seconds: Double, _ sampleRate: Double) -> [Float] {
        [Float](repeating: 0, count: Int(seconds * sampleRate))
    }

    private static func human(_ voice: VoiceSpec, sampleRate: Double, rng: inout SplitMix64Local) -> [Float] {
        var out: [Float] = []
        var phase = 0.0
        var f1 = Resonator(), f2 = Resonator(), f3 = Resonator()
        let syllables = 5 + Int(rng.unit() * 5)
        for s in 0..<syllables {
            let length = (0.07 + rng.unit() * 0.06) / voice.speed
            let n = Int(length * sampleRate)
            let vowel = vowels[Int(rng.unit() * Double(vowels.count)) % vowels.count]
            let contour = 1 + voice.melody * (rng.unit() - 0.5) * 2 - 0.08 * Double(s) / Double(syllables)
            let consonant = rng.unit() < 0.6
            f1.tune(vowel.0 * voice.formant, bandwidth: 90 * voice.formant, sampleRate: sampleRate)
            f2.tune(vowel.1 * voice.formant, bandwidth: 120 * voice.formant, sampleRate: sampleRate)
            f3.tune(2600 * voice.formant, bandwidth: 200, sampleRate: sampleRate)
            var part: [Double] = []
            part.reserveCapacity(n)
            for i in 0..<n {
                let t = Double(i) / sampleRate
                let f0 = voice.pitch * contour * (1 + voice.vibrato * sin(t * 2 * .pi * 6))
                phase += f0 / sampleRate
                // Sägezahn, bei hohen Stimmen weicher (Dreieck-Anteil)
                let saw = 2 * (phase - floor(phase)) - 1
                let tri = 4 * abs(phase - floor(phase + 0.5)) - 1
                let soft = min(1, max(0, (voice.formant - 1) * 3))
                let source = saw * (1 - soft * 0.6) + tri * soft * 0.6 + (rng.unit() * 2 - 1) * voice.breath
                var x = f1.process(source) + f2.process(source) * 0.6 + f3.process(source) * 0.25
                if consonant && t < 0.018 { x = (rng.unit() * 2 - 1) * 0.35 * (1 - t / 0.018) }
                part.append(x * min(1, t / 0.01) * min(1, (length - t) / 0.02))
            }
            append(part, to: &out, level: 0.55 + rng.unit() * 0.25)
            out.append(contentsOf: silence((rng.unit() < 0.25 ? 0.07 : 0.015) / voice.speed, sampleRate))
        }
        return out
    }

    /// Hund: Bellen mit fallender Tonhöhe, Knurren mit rauer Modulation, manchmal Winseln.
    private static func dog(_ voice: VoiceSpec, sampleRate: Double, rng: inout SplitMix64Local) -> [Float] {
        var out: [Float] = []
        var f1 = Resonator(), f2 = Resonator()
        let sounds = 3 + Int(rng.unit() * 3)
        for _ in 0..<sounds {
            let pick = rng.unit()
            var part: [Double] = []
            var phase = 0.0
            if pick < 0.55 {
                // Bellen „Wuff“
                let length = 0.1 + rng.unit() * 0.06
                let start = voice.pitch * (2.6 + rng.unit() * 0.8)
                f1.tune(650, bandwidth: 180, sampleRate: sampleRate)
                f2.tune(1400, bandwidth: 260, sampleRate: sampleRate)
                for i in 0..<Int(length * sampleRate) {
                    let t = Double(i) / sampleRate
                    phase += start * (1 - 0.45 * t / length) / sampleRate
                    let saw = 2 * (phase - floor(phase)) - 1
                    let source = saw * 0.7 + (rng.unit() * 2 - 1) * 0.5
                    let x = f1.process(source) + f2.process(source) * 0.7
                    part.append(x * min(1, t / 0.004) * exp(-t * 14))
                }
                append(part, to: &out, level: 0.85)
                out.append(contentsOf: silence(0.06 + rng.unit() * 0.08, sampleRate))
            } else if pick < 0.85 {
                // Knurren
                let length = 0.25 + rng.unit() * 0.2
                f1.tune(380, bandwidth: 150, sampleRate: sampleRate)
                f2.tune(900, bandwidth: 250, sampleRate: sampleRate)
                for i in 0..<Int(length * sampleRate) {
                    let t = Double(i) / sampleRate
                    phase += voice.pitch * 0.65 * (1 + 0.1 * sin(t * 40)) / sampleRate
                    let saw = 2 * (phase - floor(phase)) - 1
                    let rough = 0.55 + 0.45 * sin(t * 2 * .pi * 27)
                    let source = (saw + (rng.unit() * 2 - 1) * 0.3) * rough
                    let x = f1.process(source) + f2.process(source) * 0.5
                    part.append(x * min(1, t / 0.03) * min(1, (length - t) / 0.05))
                }
                append(part, to: &out, level: 0.6)
                out.append(contentsOf: silence(0.04, sampleRate))
            } else {
                // Winseln
                let length = 0.22 + rng.unit() * 0.1
                for i in 0..<Int(length * sampleRate) {
                    let t = Double(i) / sampleRate
                    phase += (voice.pitch * 5 + 300 * sin(.pi * t / length)) / sampleRate
                    part.append(sin(2 * .pi * phase) * sin(.pi * t / length))
                }
                append(part, to: &out, level: 0.5)
                out.append(contentsOf: silence(0.05, sampleRate))
            }
        }
        return out
    }

    /// Katze: Miauen (Formanten gleiten von „i“ über „a“ zu „u“, Tonhöhe steigt und fällt),
    /// kurzes „Mrrp“ und Schnurren.
    private static func cat(_ voice: VoiceSpec, sampleRate: Double, rng: inout SplitMix64Local) -> [Float] {
        var out: [Float] = []
        var f1 = Resonator(), f2 = Resonator()
        let sounds = 2 + Int(rng.unit() * 3)
        for _ in 0..<sounds {
            let pick = rng.unit()
            var part: [Double] = []
            var phase = 0.0
            if pick < 0.6 {
                // „Miau“
                let length = 0.3 + rng.unit() * 0.25
                let base = voice.pitch * (0.9 + rng.unit() * 0.3)
                let n = Int(length * sampleRate)
                for i in 0..<n {
                    let t = Double(i) / sampleRate
                    let u = t / length
                    // Formanten: i (300/2300) → a (900/1500) → u (400/900)
                    let a = sin(.pi * min(1, u * 1.6))
                    let formant1 = u < 0.6 ? 350 + 650 * a : 900 - 500 * (u - 0.6) / 0.4
                    let formant2 = u < 0.6 ? 2400 - 900 * a : 1500 - 600 * (u - 0.6) / 0.4
                    if i % 64 == 0 {
                        f1.tune(formant1 * 1.2, bandwidth: 140, sampleRate: sampleRate)
                        f2.tune(formant2 * 1.2, bandwidth: 200, sampleRate: sampleRate)
                    }
                    phase += base * (1 + 0.45 * sin(.pi * min(1, u * 1.3))) / sampleRate
                    let saw = 2 * (phase - floor(phase)) - 1
                    let source = saw * 0.8 + (rng.unit() * 2 - 1) * voice.breath
                    let x = f1.process(source) + f2.process(source) * 0.7
                    part.append(x * min(1, t / 0.02) * min(1, (length - t) / 0.08))
                }
                append(part, to: &out, level: 0.75)
                out.append(contentsOf: silence(0.08 + rng.unit() * 0.1, sampleRate))
            } else if pick < 0.8 {
                // „Mrrp“: kurzer, rollender Triller nach oben
                let length = 0.14 + rng.unit() * 0.05
                f1.tune(500, bandwidth: 160, sampleRate: sampleRate)
                f2.tune(1300, bandwidth: 220, sampleRate: sampleRate)
                for i in 0..<Int(length * sampleRate) {
                    let t = Double(i) / sampleRate
                    phase += voice.pitch * (0.8 + 0.6 * t / length) / sampleRate
                    let saw = 2 * (phase - floor(phase)) - 1
                    let roll = 0.5 + 0.5 * sin(t * 2 * .pi * 32)
                    let x = f1.process(saw * roll) + f2.process(saw * roll) * 0.6
                    part.append(x * min(1, t / 0.01) * min(1, (length - t) / 0.03))
                }
                append(part, to: &out, level: 0.6)
                out.append(contentsOf: silence(0.06, sampleRate))
            } else {
                // Schnurren: tiefes, pulsierendes Rauschen
                let length = 0.45 + rng.unit() * 0.2
                f1.tune(220, bandwidth: 120, sampleRate: sampleRate)
                for i in 0..<Int(length * sampleRate) {
                    let t = Double(i) / sampleRate
                    let pulse = pow(max(0, sin(t * 2 * .pi * 24)), 3)
                    let x = f1.process((rng.unit() * 2 - 1) * pulse)
                    part.append(x * sin(.pi * t / length))
                }
                append(part, to: &out, level: 0.5)
                out.append(contentsOf: silence(0.05, sampleRate))
            }
        }
        return out
    }

    /// Roboter: monotone Tonstufen aus einer Rechteckwelle, Ringmodulation, Piepser zwischen Wörtern.
    private static func robot(_ voice: VoiceSpec, sampleRate: Double, rng: inout SplitMix64Local) -> [Float] {
        var out: [Float] = []
        var f1 = Resonator(), f2 = Resonator()
        let steps: [Double] = [1, 1, 1.5, 2, 0.75]
        let syllables = 6 + Int(rng.unit() * 5)
        var ringPhase = 0.0
        for s in 0..<syllables {
            let length = 0.09 / voice.speed
            let f0 = voice.pitch * steps[Int(rng.unit() * Double(steps.count)) % steps.count]
            let vowel = vowels[Int(rng.unit() * Double(vowels.count)) % vowels.count]
            f1.tune(vowel.0, bandwidth: 60, sampleRate: sampleRate)
            f2.tune(vowel.1, bandwidth: 80, sampleRate: sampleRate)
            var part: [Double] = []
            var phase = 0.0
            for i in 0..<Int(length * sampleRate) {
                let t = Double(i) / sampleRate
                phase += f0 / sampleRate
                let square = phase - floor(phase) < 0.5 ? 1.0 : -1.0
                var x = f1.process(square) + f2.process(square) * 0.7
                ringPhase += 330 / sampleRate
                x *= (1 - voice.ring) + voice.ring * sin(2 * .pi * ringPhase)
                // harte Kanten wie ein Sprachchip
                part.append(t < length * 0.85 ? x : 0)
            }
            append(part, to: &out, level: 0.7)
            if s % 3 == 2 || rng.unit() < 0.2 {
                // Piepser
                var beep: [Double] = []
                let freq = 1200 + rng.unit() * 900
                for i in 0..<Int(0.04 * sampleRate) {
                    beep.append(sin(2 * .pi * freq * Double(i) / sampleRate))
                }
                append(beep, to: &out, level: 0.45)
            }
            out.append(contentsOf: silence(0.02 / voice.speed, sampleRate))
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
