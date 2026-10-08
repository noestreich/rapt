import CoreImage
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Bildstörungen kurz vor dem Absturz im Dächerlauf: Farbversatz, Rasterpunkte, verschobene Zeilen und
/// Helligkeitsflackern, je 60–150 ms, immer häufiger, je näher die Figur am Rand steht. Bei „Bewegung
/// reduzieren“ nur das Flackern.
///
/// Zum Abschalten `enabled` auf `false` setzen; zum vollständigen Entfernen diese Datei löschen und die
/// mit `// GlitchFX` markierten Zeilen in GameScene.swift entfernen (dazu `.glitch` in SoundSlot/SoundBank).
enum GlitchFX {
    static let enabled = true

    /// Ab diesem Gefahrenlevel (0 = Gefahr beginnt, 1 = Absturz) treten Störungen auf.
    static let threshold: Float = 0.5

    /// Abstand bis zur nächsten Störung: anfangs 2–3 s, kurz vor dem Absturz etwa 0,5 s.
    static func interval(level: Float) -> TimeInterval {
        let k = Double(max(0, min(1, (level - threshold) / (1 - threshold))))
        let base = 2.5 - 2.0 * k
        return base * Double.random(in: 0.8...1.2)
    }

    static var reduceMotion: Bool {
        #if os(iOS)
        return UIAccessibility.isReduceMotionEnabled
        #else
        return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #endif
    }

    /// Stellt eine zufällige Kombination für eine Störung ein; `strength` 0…1 steigt mit der Gefahr.
    static func randomize(_ filter: GlitchFilter, strength: Float) {
        filter.dim = Float.random(in: 0.08...0.18) * (0.6 + 0.4 * strength)
        if reduceMotion {
            filter.rgbShift = 0
            filter.halftone = false
            filter.tear = 0
            return
        }
        filter.rgbShift = Bool.random() ? CGFloat.random(in: 1...2) : 0
        filter.halftone = Double.random(in: 0...1) < 0.3
        filter.tear = Bool.random() ? CGFloat.random(in: 2...5) * (Bool.random() ? 1 : -1) : 0
        filter.tearY = CGFloat.random(in: 0.1...0.9)
        filter.tearHeight = CGFloat.random(in: 0.015...0.05)
        if filter.rgbShift == 0 && !filter.halftone && filter.tear == 0 { filter.rgbShift = 1 }
    }
}

/// Core-Image-Filter für die Bildstörung. Versätze sind in Design-Pixeln angegeben und werden über
/// `designWidth` auf die Bildgröße umgerechnet, damit das Brett lesbar bleibt.
final class GlitchFilter: CIFilter {
    @objc dynamic var inputImage: CIImage?
    /// Sichtbare Breite der Szene in Design-Pixeln (daraus folgt die Größe eines Design-Pixels im Bild).
    var designWidth: CGFloat = 200
    /// Seitlicher Versatz von Rot und Blau in Design-Pixeln (0 = aus).
    var rgbShift: CGFloat = 0
    /// Grobes Raster aus Druckpunkten, leicht beigemischt.
    var halftone = false
    /// Seitliche Verschiebung eines waagerechten Streifens in Design-Pixeln (0 = aus).
    var tear: CGFloat = 0
    /// Lage (0 unten … 1 oben) und Höhe des Streifens, relativ zur Bildhöhe.
    var tearY: CGFloat = 0.5
    var tearHeight: CGFloat = 0.03
    /// Abdunkeln (0 = aus).
    var dim: Float = 0

    override var outputImage: CIImage? {
        guard let image = inputImage else { return nil }
        let extent = image.extent
        guard !extent.isInfinite, !extent.isEmpty else { return image }
        let pixelScale = extent.width / max(1, designWidth)
        var result = image

        if rgbShift > 0 {
            let d = rgbShift * pixelScale
            func channel(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CIImage {
                result.applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: r, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: g, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: b, w: 0),
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                ])
            }
            let red = channel(1, 0, 0).transformed(by: CGAffineTransform(translationX: d, y: 0))
            let green = channel(0, 1, 0)
            let blue = channel(0, 0, 1).transformed(by: CGAffineTransform(translationX: -d, y: 0))
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

        if tear != 0 {
            let h = max(2 * pixelScale, extent.height * tearHeight)
            let band = CGRect(x: extent.minX, y: extent.minY + extent.height * tearY - h / 2, width: extent.width, height: h)
            let shifted = result.cropped(to: band)
                .transformed(by: CGAffineTransform(translationX: tear * pixelScale, y: 0))
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
