import CoreImage
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Bildstörungen kurz vor dem Absturz im Dächerlauf: Farbversatz, Rasterpunkte, verschobene Zeilen und
/// Helligkeitsflackern, je etwa 280 ms (220–340). Genau drei Störungen auf dem Weg zum Rand (bei Standardtempo
/// etwa alle 8–10 s), jede etwas stärker. Bei „Bewegung reduzieren“ nur das Flackern.
///
/// Zum Abschalten `enabled` auf `false` setzen; zum vollständigen Entfernen diese Datei löschen und die
/// mit `// GlitchFX` markierten Zeilen in GameScene.swift entfernen (dazu `.glitch` in SoundSlot/SoundBank).
enum GlitchFX {
    static let enabled = true

    /// Ab diesem Gefahrenlevel (0 = Gefahr beginnt, 1 = Absturz) treten Störungen auf.
    static let threshold: Float = 0.5

    /// Gefahrenlevel, an denen je eine Störung kommt (einmal pro Annäherung an den Rand). Die letzte liegt
    /// bei Standardtempo etwa 4 s vor dem Absturz.
    static let marks: [Float] = [0.6, 0.8, 0.93]

    /// Wie lange eine Störung sichtbar bleibt: etwa 280 ms, leicht gestreut.
    static func duration() -> TimeInterval {
        debugActive ? debugDuration : Double.random(in: 0.22...0.34)
    }

    // MARK: Debug (nur bei eingeblendeten Debug-Reglern, wird nicht gespeichert)

    /// Effekte einzeln: Farbversatz, Raster, Zeile, Flackern.
    static let debugNames = ["RGB", "RAS", "ZEI", "FLA"]
    static var debugEffects = [true, true, true, true]
    /// Feste Dauer einer Störung, 50 … 1000 ms.
    static var debugDuration: TimeInterval = 0.28
    static let debugDurationRange: ClosedRange<TimeInterval> = 0.05...1.0
    /// Dauertest: Störungen laufen ständig, auch ohne Absturzgefahr.
    static var debugLoop = false
    static var debugActive: Bool { GameSettings.shared.debugVisible }

    static var reduceMotion: Bool {
        #if os(iOS)
        return UIAccessibility.isReduceMotionEnabled
        #else
        return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #endif
    }

    /// Versatz um `length` Design-Pixel in zufälliger Richtung.
    private static func randomOffset(_ length: CGFloat) -> CGVector {
        let angle = CGFloat.random(in: 0..<(2 * .pi))
        return CGVector(dx: (cos(angle) * length).rounded(), dy: (sin(angle) * length).rounded())
    }

    /// Farbversatz: Rot und Blau unabhängig voneinander in zufällige Richtungen, 1–2 Design-Pixel.
    private static func shiftColors(_ filter: GlitchFilter) {
        filter.redShift = randomOffset(CGFloat.random(in: 1...2.2))
        filter.blueShift = randomOffset(CGFloat.random(in: 1...2.2))
        // Nie beide auf derselben Stelle wie das Grün
        if filter.redShift == .zero { filter.redShift = CGVector(dx: 1, dy: 0) }
    }

    /// Zwei verschobene Zeilen, eine im oberen, eine im unteren Bereich, je in eigene Richtung.
    private static func tearLines(_ filter: GlitchFilter, strength: Float) {
        let reach = 2 + 3 * CGFloat(strength)
        filter.tears = [CGFloat.random(in: 0.6...0.88), CGFloat.random(in: 0.12...0.4)].map { y in
            GlitchFilter.Tear(y: y, height: CGFloat.random(in: 0.015...0.045),
                              shift: CGFloat.random(in: 2...reach) * (Bool.random() ? 1 : -1))
        }
    }

    /// Stellt eine zufällige Kombination für eine Störung ein; `strength` 0…1 steigt mit der Gefahr.
    static func randomize(_ filter: GlitchFilter, strength: Float) {
        filter.redShift = .zero
        filter.blueShift = .zero
        filter.halftone = false
        filter.tears = []
        if debugActive {
            // Gewählte Effekte immer zeigen, damit man sie einzeln betrachten kann
            let on = debugEffects
            if on[0] { shiftColors(filter) }
            filter.halftone = on[1]
            if on[2] { tearLines(filter, strength: 1) }
            filter.dim = on[3] ? 0.15 : 0
            return
        }
        filter.dim = Float.random(in: 0.08...0.18) * (0.6 + 0.4 * strength)
        if reduceMotion { return }
        var picked = false
        if Bool.random() { shiftColors(filter); picked = true }
        if Double.random(in: 0...1) < 0.3 { filter.halftone = true; picked = true }
        if Bool.random() { tearLines(filter, strength: strength); picked = true }
        if !picked { shiftColors(filter) }
    }
}

/// Core-Image-Filter für die Bildstörung. Versätze sind in Design-Pixeln angegeben und werden über
/// `designWidth` auf die Bildgröße umgerechnet, damit das Brett lesbar bleibt.
final class GlitchFilter: CIFilter {
    /// Seitlich verschobener Streifen: Lage (0 unten … 1 oben) und Höhe relativ zur Bildhöhe, Versatz in Design-Pixeln.
    struct Tear {
        var y: CGFloat
        var height: CGFloat
        var shift: CGFloat
    }

    @objc dynamic var inputImage: CIImage?
    /// Sichtbare Breite der Szene in Design-Pixeln (daraus folgt die Größe eines Design-Pixels im Bild).
    var designWidth: CGFloat = 200
    /// Versatz von Rot und Blau in Design-Pixeln (.zero = aus).
    var redShift = CGVector.zero
    var blueShift = CGVector.zero
    /// Grobes Raster aus Druckpunkten, leicht beigemischt.
    var halftone = false
    /// Verschobene Streifen.
    var tears: [Tear] = []
    /// Abdunkeln (0 = aus).
    var dim: Float = 0

    override var outputImage: CIImage? {
        guard let image = inputImage else { return nil }
        let extent = image.extent
        guard !extent.isInfinite, !extent.isEmpty else { return image }
        let pixelScale = extent.width / max(1, designWidth)
        var result = image

        if redShift != .zero || blueShift != .zero {
            let source = result
            func channel(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ offset: CGVector) -> CIImage {
                source.applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: r, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: g, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: b, w: 0),
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                ]).transformed(by: CGAffineTransform(translationX: offset.dx * pixelScale, y: offset.dy * pixelScale))
            }
            let red = channel(1, 0, 0, redShift)
            let green = channel(0, 1, 0, .zero)
            let blue = channel(0, 0, 1, blueShift)
            result = red
                .applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: green])
                .applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: blue])
                .cropped(to: extent)
        }

        if halftone {
            let dots = result.applyingFilter("CICMYKHalftone", parameters: [
                kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
                kCIInputWidthKey: 3 * pixelScale,
                kCIInputAngleKey: 0.4,
                kCIInputSharpnessKey: 0.7,
                "inputGCR": 1,
                "inputUCR": 0.5,
            ]).cropped(to: extent)
            // Nur leicht beimischen, damit die Steine erkennbar bleiben
            result = dots.applyingFilter("CIDissolveTransition", parameters: [
                kCIInputTargetImageKey: result, kCIInputTimeKey: 0.6,
            ]).cropped(to: extent)
        }

        for tear in tears {
            let h = max(2 * pixelScale, extent.height * tear.height)
            let band = CGRect(x: extent.minX, y: extent.minY + extent.height * tear.y - h / 2, width: extent.width, height: h)
            let shifted = result.cropped(to: band)
                .transformed(by: CGAffineTransform(translationX: tear.shift * pixelScale, y: 0))
                .cropped(to: band)
            result = shifted.composited(over: result)
        }

        if dim > 0 {
            result = result.applyingFilter("CIColorControls", parameters: [
                kCIInputBrightnessKey: -dim, kCIInputSaturationKey: 1, kCIInputContrastKey: 1,
            ])
        }
        return result
    }
}
