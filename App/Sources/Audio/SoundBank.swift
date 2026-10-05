import AVFoundation

/// Spielt Soundeffekte. Für jeden Platz gibt es einen synthetisierten Retro-Sound;
/// liegt in der `SoundLibrary` eine Datei, wird stattdessen diese gespielt.
/// Treffer in einer Kaskade steigen eine Moll-Pentatonik hinauf, damit Ketten hörbar „hochschaukeln“.
final class SoundBank {
    var isEnabled = true
    var masterVolume: Float = 1 {
        didSet { engine.mainMixerNode.outputVolume = masterVolume * 0.8 }
    }

    private static let sampleRate = 44_100.0
    private static let scale: [Double] = [0, 3, 5, 7, 10, 12, 15, 17, 19, 22, 24, 27]
    private let library: SoundLibrary
    private let engine = AVAudioEngine()
    private let format: AVAudioFormat
    private var voices: [(player: AVAudioPlayerNode, speed: AVAudioUnitVarispeed)] = []
    private var nextVoice = 0
    private var synth: [SoundSlot: AVAudioPCMBuffer] = [:]
    private var synthMatches: [AVAudioPCMBuffer] = []
    private var custom: [SoundSlot: AVAudioPCMBuffer] = [:]

    init(library: SoundLibrary) {
        self.library = library
        format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 2)!
        for _ in 0..<14 {
            let player = AVAudioPlayerNode()
            let speed = AVAudioUnitVarispeed()
            engine.attach(player)
            engine.attach(speed)
            engine.connect(player, to: speed, format: format)
            engine.connect(speed, to: engine.mainMixerNode, format: format)
            voices.append((player, speed))
        }
        engine.mainMixerNode.outputVolume = 0.8

        synthMatches = Self.scale.map { makeMatch(frequency: 392 * pow(2, $0 / 12)) }
        for slot in SoundSlot.allCases where !slot.isMusic && slot != .match {
            synth[slot] = make(slot)
        }
        reload()

        do {
            try engine.start()
            voices.forEach { $0.player.play() }
        } catch {
            isEnabled = false
        }
    }

    /// Lädt eigene Dateien neu, z. B. nachdem im Sound-Labor etwas zugewiesen wurde.
    func reload() {
        custom = [:]
        for slot in SoundSlot.allCases where !slot.isMusic {
            if let url = library.url(for: slot), let buffer = Self.load(url, as: format) {
                custom[slot] = buffer
            }
        }
    }

    func play(_ slot: SoundSlot, volume: Float = 1) {
        guard let buffer = custom[slot] ?? synth[slot] else { return }
        schedule(buffer, volume: volume * Float(library.gain(for: slot)), semitones: 0)
    }

    /// Bissen des Fressers; jeder weitere Bissen etwas höher.
    func chomp(count: Int, volume: Float = 0.5) {
        let semitones = Double(count % 12)
        guard let buffer = custom[.chomp] ?? synth[.chomp] else { return }
        schedule(buffer, volume: volume * Float(library.gain(for: .chomp)), semitones: semitones)
    }

    /// Trefferton; `step` 0 ist der erste Treffer, jede Kaskadenstufe klingt höher.
    func match(step: Int, volume: Float = 0.5) {
        let i = clamp(step, 0, Self.scale.count - 1)
        let gain = volume * Float(library.gain(for: .match))
        if let file = custom[.match] {
            schedule(file, volume: gain, semitones: Self.scale[i])
        } else {
            schedule(synthMatches[i], volume: gain, semitones: 0)
        }
    }

    private func schedule(_ buffer: AVAudioPCMBuffer, volume: Float, semitones: Double) {
        guard isEnabled else { return }
        if !engine.isRunning { try? engine.start() }
        guard engine.isRunning else { return }
        let voice = voices[nextVoice]
        nextVoice = (nextVoice + 1) % voices.count
        voice.player.volume = volume
        voice.speed.rate = Float(pow(2, semitones / 12))
        voice.player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !voice.player.isPlaying { voice.player.play() }
    }

    /// Liest eine Audiodatei und wandelt sie in das Format der Engine (44,1 kHz, Stereo).
    static func load(_ url: URL, as format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let source = file.processingFormat
        let frames = AVAudioFrameCount(file.length)
        guard frames > 0, let input = AVAudioPCMBuffer(pcmFormat: source, frameCapacity: frames) else { return nil }
        do { try file.read(into: input) } catch { return nil }
        if source == format { return input }

        guard let converter = AVAudioConverter(from: source, to: format) else { return nil }
        if source.channelCount == 1 { converter.channelMap = [0, 0] }
        let capacity = AVAudioFrameCount(Double(frames) * format.sampleRate / source.sampleRate) + 4096
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var delivered = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, outStatus in
            if delivered {
                outStatus.pointee = .endOfStream
                return nil
            }
            delivered = true
            outStatus.pointee = .haveData
            return input
        }
        return status == .error ? nil : output
    }

    // MARK: Synthese

    private func buffer(_ duration: Double, crush hold: Int = 3, _ sample: (Double) -> Double) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(duration * Self.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let left = buffer.floatChannelData![0]
        let right = buffer.floatChannelData![1]
        var held = 0.0
        for i in 0..<Int(frames) {
            let value = sample(Double(i) / Self.sampleRate)
            if hold <= 1 || i % hold == 0 { held = (clamp(value, -1, 1) * 24).rounded() / 24 }
            // kurzes Ausblenden gegen Knacken am Ende
            let tail = min(1, Double(Int(frames) - i) / 200)
            left[i] = Float(held * tail)
            right[i] = left[i]
        }
        return buffer
    }

    private struct Noise {
        var state: UInt32 = 0x1234_5678
        mutating func next() -> Double {
            state = state &* 1_664_525 &+ 1_013_904_223
            return Double(state >> 8) / Double(1 << 23) - 1
        }
    }

    private static func square(_ phase: Double) -> Double { phase - floor(phase) < 0.5 ? 1 : -1 }
    private static func triangle(_ phase: Double) -> Double { 4 * abs(phase - floor(phase + 0.5)) - 1 }

    private func makeMatch(frequency: Double) -> AVAudioPCMBuffer {
        var phase = 0.0, sub = 0.0
        var noise = Noise()
        let dt = 1 / Self.sampleRate
        return buffer(0.24) { t in
            let f = frequency * (1 + 0.06 * min(1, t / 0.03))
            phase += f * dt
            sub += f * 0.5 * dt
            let env = exp(-t * 16)
            let click = t < 0.012 ? noise.next() * (1 - t / 0.012) * 0.6 : 0
            return (Self.square(phase) * 0.35 + Self.triangle(sub) * 0.45) * env + click
        }
    }

    private func make(_ slot: SoundSlot) -> AVAudioPCMBuffer {
        let dt = 1 / Self.sampleRate
        var phase = 0.0
        var noise = Noise()
        var low = 0.0, low2 = 0.0

        switch slot {
        case .select:
            return buffer(0.05) { t in
                phase += 1500 * dt
                return Self.square(phase) * exp(-t * 70) * 0.25
            }

        case .cascade:
            return buffer(0.45) { t in
                // aufsteigendes „Hochladen“ mit Tremolo
                phase += (300 + 1400 * t * t * 4) * dt
                let tremolo = 0.6 + 0.4 * Self.square(t * 28)
                return Self.square(phase) * 0.22 * tremolo * min(1, t / 0.02) * exp(-t * 2.5)
            }

        case .match, .music:
            return buffer(0.01) { _ in 0 }

        case .jump:
            return buffer(0.2) { t in
                phase += (280 + 900 * t / 0.2) * dt
                return Self.square(phase) * 0.25 * exp(-t * 9)
            }

        case .powerUp:
            let notes: [Double] = [0, 7, 12, 19, 24, 31]
            return buffer(0.6) { t in
                let idx = min(notes.count - 1, Int(t / 0.05))
                let lt = t - Double(idx) * 0.05
                phase += 659.25 * pow(2, notes[idx] / 12) * dt
                let sparkle = noise.next() * 0.08 * exp(-lt * 30)
                let env = idx == notes.count - 1 ? exp(-lt * 4) : exp(-lt * 10)
                return (Self.square(phase) * 0.18 + Self.triangle(phase * 2) * 0.15) * env + sparkle
            }

        case .bomb:
            return buffer(0.35) { t in
                // Zündschnur-Zischen, dann Knall
                let fuse = t < 0.12 ? noise.next() * 0.25 * (0.5 + 0.5 * sin(t * 300)) : 0
                phase += (140 * exp(-t * 8) + 40) * dt
                let crack = t >= 0.12 ? (noise.next() * 0.7 + sin(2 * .pi * phase) * 0.6) * exp(-(t - 0.12) * 14) : 0
                return fuse + crack
            }

        case .purge:
            return buffer(0.55) { t in
                phase += (1800 * exp(-t * 5) + 120) * dt
                let zap = Self.square(phase) * (0.5 + 0.5 * Self.square(t * 40))
                return (zap * 0.22 + noise.next() * 0.12) * exp(-t * 4)
            }

        case .chomp:
            return buffer(0.1) { t in
                let f = 160 + 260 * sin(.pi * t / 0.1)
                phase += f * dt
                return Self.triangle(phase) * 0.45 * min(1, t / 0.005) * exp(-t * 12)
            }

        case .swap:
            return buffer(0.08) { t in
                phase += (600 + 2600 * t) * dt
                return sin(2 * .pi * phase) * exp(-t * 30) * 0.5
            }

        case .invalid:
            return buffer(0.2) { t in
                phase += (170 - 220 * t) * dt
                let gate = (t < 0.07 || (t > 0.1 && t < 0.17)) ? 1.0 : 0
                return Self.square(phase) * 0.3 * gate
            }

        case .land:
            return buffer(0.09) { t in
                phase += (110 - 400 * t) * dt
                return sin(2 * .pi * phase) * exp(-t * 45) * 0.6 + noise.next() * exp(-t * 120) * 0.1
            }

        case .explosion:
            return buffer(1.0, crush: 2) { t in
                // Rauschen mit sinkender Grenzfrequenz plus tiefer Schlag
                let cutoff = 2400 * exp(-t * 3.5) + 120
                low += (1 - exp(-2 * .pi * cutoff * dt)) * (noise.next() - low)
                phase += (75 * exp(-t * 4) + 30) * dt
                let thump = sin(2 * .pi * phase) * exp(-t * 6)
                let env = t < 0.005 ? t / 0.005 : exp(-t * 3.2)
                return (low * 1.6 + thump * 0.8) * env
            }

        case .warp:
            return buffer(0.7) { t in
                // Sinus fällt exponentiell, darüber ein gefiltertes Rauschen (Zischen der Schockwelle)
                let f = 60 + 1100 * exp(-t * 6)
                phase += f * (1 + 0.02 * sin(t * 90)) * dt
                low += (1 - exp(-2 * .pi * 1800 * dt)) * (noise.next() - low)
                low2 += (1 - exp(-2 * .pi * 500 * dt)) * (low - low2)
                let whoosh = (low - low2) * sin(.pi * min(1, t / 0.5)) * 1.5
                return sin(2 * .pi * phase) * exp(-t * 3) * 0.5 + whoosh
            }

        case .steam:
            return buffer(0.6, crush: 1) { t in
                let n = noise.next()
                low += (1 - exp(-2 * .pi * 3000 * dt)) * (n - low)
                let hiss = n - low
                let env = t < 0.03 ? t / 0.03 : exp(-(t - 0.03) * 5)
                return hiss * env * 0.5
            }

        case .shrapnel:
            let ticks: [(start: Double, pitch: Double)] = [(0, 1), (0.03, 1.3), (0.07, 0.85), (0.12, 1.15), (0.18, 0.95), (0.26, 1.25)]
            return buffer(0.4, crush: 1) { t in
                var sum = 0.0
                for tick in ticks where t >= tick.start {
                    let lt = t - tick.start
                    let env = exp(-lt * 90)
                    sum += (sin(2 * .pi * 2300 * tick.pitch * lt) + sin(2 * .pi * 3710 * tick.pitch * lt) * 0.6
                        + sin(2 * .pi * 5170 * tick.pitch * lt) * 0.4) * env
                }
                return sum * 0.18
            }

        case .plan:
            let notes: [Double] = [0, 4, 7, 12, 16, 19]
            return buffer(0.9) { t in
                let idx = min(notes.count - 1, Int(t / 0.07))
                let lt = t - Double(idx) * 0.07
                phase += 523.25 * pow(2, notes[idx] / 12) * dt
                let env = idx == notes.count - 1 ? exp(-lt * 3.5) : exp(-lt * 14)
                return Self.square(phase) * 0.28 * env
            }

        case .gameOver:
            let notes: [Double] = [12, 7, 3, 0, -5]
            return buffer(1.2) { t in
                let idx = min(notes.count - 1, Int(t / 0.17))
                let lt = t - Double(idx) * 0.17
                phase += 261.63 * pow(2, notes[idx] / 12) * (1 - 0.01 * sin(lt * 40)) * dt
                let env = idx == notes.count - 1 ? exp(-lt * 2.5) : exp(-lt * 6)
                return (Self.square(phase) * 0.25 + Self.triangle(phase * 0.5) * 0.3) * env
            }
        }
    }
}
