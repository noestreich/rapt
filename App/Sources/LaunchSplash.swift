import SwiftUI

/// Kurzer Vorspann nach dem Kaltstart: übernimmt nahtlos den Startbildschirm (gleiches Bild, gleiche Größe),
/// lässt den Titel „RAPT“ einmal aufglühen und blendet nach knapp einer Sekunde ins Spiel über.
/// Antippen überspringt ihn.
///
/// Zum Abschalten `enabled` auf `false` setzen; zum vollständigen Entfernen diese Datei löschen und die
/// mit `// LaunchSplash` markierten Zeilen in GameView.swift entfernen.
struct LaunchSplash: View {
    static let enabled = false

    /// Wird nach dem Ausblenden aufgerufen.
    var onFinish: () -> Void

    @State private var glow = false
    @State private var fading = false
    @State private var finished = false

    /// Lage des Titels im Bild (Mitte, relativ zu Breite und Höhe).
    private let titleCenter = CGPoint(x: 0.5, y: 0.23)

    var body: some View {
        ZStack {
            Color("LaunchBackground")
            art
                .overlay {
                    GeometryReader { geo in
                        let w = geo.size.width, h = geo.size.height
                        Ellipse()
                            .fill(RadialGradient(
                                colors: [Color(red: 1, green: 0.62, blue: 0.25), Color(red: 1, green: 0.3, blue: 0.1).opacity(0.5), .clear],
                                center: .center, startRadius: 0, endRadius: w * 0.45))
                            .frame(width: w * 0.9, height: h * 0.2)
                            .position(x: w * titleCenter.x, y: h * titleCenter.y)
                            .blur(radius: w * 0.03)
                            .blendMode(.screen)
                            .opacity(glow ? 0.85 : 0)
                            .scaleEffect(glow ? 1.04 : 0.96)
                    }
                    .allowsHitTesting(false)
                }
        }
        // Bild mittig über den ganzen Bildschirm, Überstand abgeschnitten (wie beim Startbildschirm)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .ignoresSafeArea()
        .opacity(fading ? 0 : 1)
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .task {
            withAnimation(.easeOut(duration: 0.25)) { glow = true }
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.easeIn(duration: 0.4)) { glow = false }
            try? await Task.sleep(for: .milliseconds(500))
            finish()
        }
    }

    /// Bild wie auf dem Startbildschirm: auf iOS in natürlicher Größe mittig, auf dem Mac füllend.
    @ViewBuilder private var art: some View {
        #if os(iOS)
        Image("LaunchImage")
        #else
        Image("LaunchImage")
            .resizable()
            .scaledToFill()
        #endif
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        withAnimation(.easeOut(duration: 0.35)) { fading = true }
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            onFinish()
        }
    }
}
