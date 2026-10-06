import AVFoundation

/// Hintergrundmusik: pro Spiel ein zufälliger Track aus dem Bundle (`music_*.m4a`), nahtlos in Schleife.
/// Liegt im Sound-Labor eine eigene Datei auf dem Platz `.music`, läuft stattdessen diese.
final class MusicPlayer {
    private let library: SoundLibrary
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let playlist: [URL]
    private var current: URL?
    private var isPlaying = false
    private var fadeTimer: Timer?

    var isEnabled = true {
        didSet { apply() }
    }

    var volume: Float = 0.6 {
        didSet { if fadeTimer == nil { player.volume = effectiveVolume } }
    }

    /// Absenkung, z. B. bei Absturzgefahr (1 = normal).
    var duck: Float = 1 {
        didSet { if fadeTimer == nil && isPlaying { player.volume = effectiveVolume } }
    }

    private var effectiveVolume: Float { volume * duck * Float(library.gain(for: .music)) }

    init(library: SoundLibrary) {
        self.library = library
        playlist = (Bundle.main.urls(forResourcesWithExtension: "m4a", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("music_") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
        // Wechselt der Audio-Modus (z. B. Musik an/aus), hält iOS die Engine an: dann neu starten
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            guard let self, self.isEnabled, let url = self.current else { return }
            self.isPlaying = false
            self.start(url)
        }
        reload()
    }

    /// Titel der Bundle-Tracks, z. B. für Credits.
    var trackNames: [String] { playlist.map { $0.deletingPathExtension().lastPathComponent } }

    /// Eigene Datei aus dem Sound-Labor geändert: neu laden.
    func reload() {
        current = nil
        nextTrack()
    }

    /// Wechselt zu einem anderen, zufälligen Track (eigene Datei hat Vorrang).
    func nextTrack() {
        let custom = library.source(for: .music) != .synth ? library.url(for: .music) : nil
        let choice = custom ?? playlist.filter { $0 != current }.randomElement() ?? playlist.first
        guard let url = choice else { return }
        guard isEnabled else {
            current = url
            return
        }
        fade(to: 0, duration: isPlaying ? 0.6 : 0) { [weak self] in
            self?.start(url)
        }
    }

    private func start(_ url: URL) {
        player.stop()
        isPlaying = false
        current = url
        guard let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil else { return }
        // Format des Tracks an den Mischer anpassen
        engine.disconnectNodeOutput(player)
        engine.connect(player, to: engine.mainMixerNode, format: buffer.format)
        if !engine.isRunning { try? engine.start() }
        guard engine.isRunning else { return }
        player.volume = 0
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        player.play()
        isPlaying = true
        fade(to: effectiveVolume, duration: 1.2)
    }

    private func apply() {
        if isEnabled {
            if !isPlaying {
                if let url = current { start(url) } else { nextTrack() }
            }
        } else if isPlaying {
            fade(to: 0, duration: 0.4) { [weak self] in
                self?.player.pause()
                self?.isPlaying = false
            }
        }
    }

    private func fade(to target: Float, duration: TimeInterval, then completion: (() -> Void)? = nil) {
        fadeTimer?.invalidate()
        guard duration > 0 else {
            player.volume = target
            fadeTimer = nil
            completion?()
            return
        }
        let start = player.volume
        let began = Date()
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            let t = min(1, Date().timeIntervalSince(began) / duration)
            self.player.volume = start + (target - start) * Float(t)
            if t >= 1 {
                timer.invalidate()
                self.fadeTimer = nil
                completion?()
            }
        }
    }
}
