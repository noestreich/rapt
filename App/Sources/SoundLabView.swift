#if os(macOS) && DEBUG
import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Entwickler-Werkzeug: Audiodateien per Drag & Drop auf Spielaktionen legen, live im Spiel hören
/// und die Zuordnung als Ordner mit `manifest.json` exportieren.
struct SoundLabView: View {
    static let windowID = "sound-lab"

    @ObservedObject private var library = AudioCenter.shared.library
    @State private var message: String?
    @State private var isError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Sound-Labor").font(.title2.bold())
                Text("Zieh eine WAV-, MP3-, M4A-, AIFF- oder CAF-Datei auf eine Zeile. Sie gilt sofort im laufenden Spiel. Spiel im Hauptfenster weiter, um sie in echten Situationen zu hören. Mit „Exportieren …“ bekommst du einen Ordner mit allen Dateien und einer manifest.json, die du an Claude zurückgibst.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Exportieren …", action: export)
                        .keyboardShortcut("e", modifiers: [.command])
                    Button("Ordner im Finder zeigen") {
                        if let dir = library.overrideDirectory { NSWorkspace.shared.activateFileViewerSelecting([dir]) }
                    }
                    Spacer()
                    Button("Alle zurücksetzen", role: .destructive) {
                        library.resetAll()
                        show("Alle Plätze nutzen wieder die eingebauten Sounds.")
                    }
                    .disabled(!library.hasCustomFiles)
                }
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(SoundSlot.allCases) { slot in
                        SoundSlotRow(slot: slot, library: library, onMessage: show)
                    }
                }
                .padding(12)
            }

            if let message {
                Divider()
                Text(message)
                    .font(.callout)
                    .foregroundStyle(isError ? Color.red : Color.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
    }

    private func show(_ text: String, error: Bool = false) {
        message = text
        isError = error
    }

    private func export() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Hierhin exportieren"
        panel.message = "Wähle einen Ordner. Darin entsteht „Rapt-Sounds-…“ mit allen Dateien und der manifest.json."
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        do {
            let target = try library.export(to: folder)
            NSWorkspace.shared.activateFileViewerSelecting([target.appendingPathComponent("manifest.json")])
            show("Exportiert nach \(target.path). Gib Claude diesen Ordner, z. B. als ZIP oder per Commit.")
        } catch {
            show("Export fehlgeschlagen: \(error.localizedDescription)", error: true)
        }
    }
}

private struct SoundSlotRow: View {
    let slot: SoundSlot
    @ObservedObject var library: SoundLibrary
    let onMessage: (String, Bool) -> Void
    @State private var isTargeted = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(slot.title).font(.headline)
                    Text(slot.rawValue).font(.caption.monospaced()).foregroundStyle(.tertiary)
                }
                Text(slot.trigger).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            sourceBadge
                .frame(width: 150, alignment: .leading)

            Slider(value: Binding(
                get: { library.gain(for: slot) },
                set: { library.setGain($0, for: slot) }
            ), in: 0...2)
            .frame(width: 90)
            .help("Lautstärke dieses Platzes (1 = unverändert)")

            Button { AudioCenter.shared.preview(slot) } label: {
                Image(systemName: slot.isMusic ? "playpause.fill" : "play.fill")
            }
            .help(slot.isMusic ? "Musik an/aus" : "Probehören")

            Button("Datei …", action: choose)

            Button {
                library.reset(slot)
                onMessage("\(slot.title) nutzt wieder den eingebauten Sound.", false)
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .help("Eigene Datei entfernen")
            .disabled(!isCustom)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isTargeted ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isTargeted ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            assign(url)
            return true
        } isTargeted: { isTargeted = $0 }
    }

    private var isCustom: Bool {
        if case .custom = library.source(for: slot) { return true }
        return false
    }

    @ViewBuilder private var sourceBadge: some View {
        switch library.source(for: slot) {
        case .synth:
            Label("Eingebaut", systemImage: "waveform").foregroundStyle(.secondary)
        case .bundled(let name):
            Label(name, systemImage: "shippingbox").foregroundStyle(.secondary)
        case .custom(let name):
            Label(name, systemImage: "doc.fill").foregroundStyle(Color.accentColor)
        }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.prompt = "Zuweisen"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        assign(url)
    }

    private func assign(_ url: URL) {
        do {
            try library.assign(url, to: slot)
            onMessage("„\(url.lastPathComponent)“ ist jetzt \(slot.title).", false)
            AudioCenter.shared.preview(slot)
        } catch {
            onMessage(error.localizedDescription, true)
        }
    }
}
#endif
