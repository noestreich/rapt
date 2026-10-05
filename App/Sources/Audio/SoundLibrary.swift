import Foundation

/// Entscheidet, welche Audiodatei für welchen Platz gilt:
/// 1. eigene Datei aus dem Sound-Labor (nur Mac, liegt in Application Support),
/// 2. Datei im App-Bundle mit dem Namen des Platzes (z. B. `explosion.mp3`),
/// 3. sonst der eingebaute Synthesizer.
final class SoundLibrary: ObservableObject {
    static let didChange = Notification.Name("SoundLibraryDidChange")

    enum Source: Equatable {
        case synth
        case bundled(String)
        case custom(String)
    }

    struct FileEntry: Codable, Equatable {
        var file: String
        var originalName: String
    }

    private struct Store: Codable {
        var files: [String: FileEntry] = [:]
        var gains: [String: Double] = [:]
    }

    @Published private var store = Store()
    /// Ablage für eigene Dateien. Nur auf dem Mac gesetzt.
    let overrideDirectory: URL?

    init() {
        #if os(macOS)
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        overrideDirectory = support?.appendingPathComponent("Rapt/SoundLab", isDirectory: true)
        #else
        overrideDirectory = nil
        #endif
        if let dir = overrideDirectory {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            if let data = try? Data(contentsOf: dir.appendingPathComponent("library.json")),
               let saved = try? JSONDecoder().decode(Store.self, from: data) {
                store = saved
            }
        }
    }

    // MARK: Abfragen

    func url(for slot: SoundSlot) -> URL? {
        if let entry = store.files[slot.rawValue], let dir = overrideDirectory {
            let url = dir.appendingPathComponent(entry.file)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return bundledURL(for: slot)
    }

    func bundledURL(for slot: SoundSlot) -> URL? {
        for ext in SoundSlot.audioExtensions {
            if let url = Bundle.main.url(forResource: slot.rawValue, withExtension: ext) { return url }
        }
        return nil
    }

    func source(for slot: SoundSlot) -> Source {
        if let entry = store.files[slot.rawValue] { return .custom(entry.originalName) }
        if let url = bundledURL(for: slot) { return .bundled(url.lastPathComponent) }
        return .synth
    }

    func gain(for slot: SoundSlot) -> Double {
        store.gains[slot.rawValue] ?? 1
    }

    var hasCustomFiles: Bool { !store.files.isEmpty }

    // MARK: Ändern (Sound-Labor)

    enum LibraryError: LocalizedError {
        case unsupported(String)
        case noStorage

        var errorDescription: String? {
            switch self {
            case .unsupported(let ext):
                return "„.\(ext)“ wird nicht unterstützt. Erlaubt sind: \(SoundSlot.audioExtensions.joined(separator: ", "))."
            case .noStorage:
                return "Eigene Dateien gibt es nur in der Mac-App."
            }
        }
    }

    func assign(_ source: URL, to slot: SoundSlot) throws {
        guard let dir = overrideDirectory else { throw LibraryError.noStorage }
        let ext = source.pathExtension.lowercased()
        guard SoundSlot.audioExtensions.contains(ext) else { throw LibraryError.unsupported(ext) }
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        removeFile(for: slot)
        let name = "\(slot.rawValue).\(ext)"
        try FileManager.default.copyItem(at: source, to: dir.appendingPathComponent(name))
        store.files[slot.rawValue] = FileEntry(file: name, originalName: source.lastPathComponent)
        save()
    }

    func setGain(_ gain: Double, for slot: SoundSlot) {
        store.gains[slot.rawValue] = gain
        save(notify: false)
    }

    func reset(_ slot: SoundSlot) {
        removeFile(for: slot)
        store.files[slot.rawValue] = nil
        store.gains[slot.rawValue] = nil
        save()
    }

    func resetAll() {
        for slot in SoundSlot.allCases { removeFile(for: slot) }
        store = Store()
        save()
    }

    private func removeFile(for slot: SoundSlot) {
        guard let dir = overrideDirectory, let entry = store.files[slot.rawValue] else { return }
        try? FileManager.default.removeItem(at: dir.appendingPathComponent(entry.file))
    }

    private func save(notify: Bool = true) {
        if let dir = overrideDirectory, let data = try? JSONEncoder().encode(store) {
            try? data.write(to: dir.appendingPathComponent("library.json"))
        }
        if notify { NotificationCenter.default.post(name: Self.didChange, object: self) }
    }

    // MARK: Export

    struct Manifest: Codable {
        struct Slot: Codable {
            let slot: String
            let title: String
            let trigger: String
            let source: String
            let file: String?
            let originalName: String?
            let gain: Double
        }

        let app: String
        let exportedAt: String
        let slots: [Slot]
    }

    /// Legt in `folder` einen Unterordner mit allen eigenen Dateien und einer `manifest.json` an.
    func export(to folder: URL) throws -> URL {
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }

        let stamp = DateFormatter()
        stamp.dateFormat = "yyyyMMdd-HHmm"
        let target = folder.appendingPathComponent("Rapt-Sounds-\(stamp.string(from: Date()))", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)

        var slots: [Manifest.Slot] = []
        for slot in SoundSlot.allCases {
            var file: String?
            var original: String?
            var sourceName = "synth"
            if let entry = store.files[slot.rawValue], let dir = overrideDirectory {
                try? FileManager.default.removeItem(at: target.appendingPathComponent(entry.file))
                try FileManager.default.copyItem(at: dir.appendingPathComponent(entry.file),
                                                 to: target.appendingPathComponent(entry.file))
                file = entry.file
                original = entry.originalName
                sourceName = "datei"
            } else if let bundled = bundledURL(for: slot) {
                original = bundled.lastPathComponent
                sourceName = "bundle"
            }
            slots.append(Manifest.Slot(slot: slot.rawValue, title: slot.title, trigger: slot.trigger,
                                       source: sourceName, file: file, originalName: original, gain: gain(for: slot)))
        }
        let iso = ISO8601DateFormatter()
        let manifest = Manifest(app: "Rapt", exportedAt: iso.string(from: Date()), slots: slots)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(to: target.appendingPathComponent("manifest.json"))
        return target
    }
}
