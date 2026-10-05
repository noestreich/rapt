import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = GameSettings.shared

    var body: some View {
        Form {
            Section("Ton") {
                Toggle("Soundeffekte", isOn: $settings.soundEnabled)
                Slider(value: $settings.soundVolume, in: 0...1) { Text("Lautstärke Effekte") }
                    .disabled(!settings.soundEnabled)
                Toggle("Hintergrundmusik", isOn: $settings.musicEnabled)
                Slider(value: $settings.musicVolume, in: 0...1) { Text("Lautstärke Musik") }
                    .disabled(!settings.musicEnabled)
            }
            #if os(iOS)
            Section("Gefühl") {
                Toggle("Haptik", isOn: $settings.hapticsEnabled)
            }
            #endif
        }
    }
}
