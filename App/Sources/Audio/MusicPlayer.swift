import AVFoundation

/// Hintergrundmusik in Schleife. Quelle ist der Platz `.music` der `SoundLibrary`
/// (eigene Datei aus dem Sound-Labor oder `music.mp3` im Bundle). Ohne Datei bleibt es still.
final class MusicPlayer {
    private let library: SoundLibrary
    private var player: AVAudioPlayer?
    private var loadedURL: URL?

    var isEnabled = true {
        didSet { apply() }
    }

    var volume: Float = 0.6 {
        didSet { player?.volume = effectiveVolume }
    }

    private var effectiveVolume: Float { volume * Float(library.gain(for: .music)) }

    init(library: SoundLibrary) {
        self.library = library
        reload()
    }

    func reload() {
        let url = library.url(for: .music)
        if url != loadedURL {
            player?.stop()
            player = url.flatMap { try? AVAudioPlayer(contentsOf: $0) }
            player?.numberOfLoops = -1
            player?.prepareToPlay()
            loadedURL = url
        }
        player?.volume = effectiveVolume
        apply()
    }

    private func apply() {
        guard let player else { return }
        if isEnabled && !player.isPlaying {
            player.play()
        } else if !isEnabled && player.isPlaying {
            player.pause()
        }
    }
}
