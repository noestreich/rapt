import CoreImage

/// Spielbrett kurzzeitig ohne Farbe: Steine und ihr Leuchten werden grau (Pixel-Art bleibt erhalten) oder
/// hart schwarz-weiß (1-Bit). Stadt, Läufer und Anzeige bleiben farbig. Ein- und Ausblenden über `amount`.
///
/// Noch ohne festen Einsatz im Spiel; zum Ausprobieren in den Debug-Reglern (TEST: GRAU, 1BIT).
final class BoardMonoFilter: CIFilter {
    @objc dynamic var inputImage: CIImage?
    /// 1-Bit statt Graustufen.
    var oneBit = false
    /// 0 = volle Farbe, 1 = ganz ohne Farbe. Beim 1-Bit erst grau (bis 0,5), dann hart schwarz-weiß.
    var amount: CGFloat = 1

    override var outputImage: CIImage? {
        guard let image = inputImage else { return nil }
        let k = max(0, min(1, amount))
        if !oneBit || k < 0.5 {
            let saturation = oneBit ? 1 - 2 * k : 1 - k
            return image.applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: saturation, kCIInputContrastKey: 1 + 0.1 * k, kCIInputBrightnessKey: 0,
            ])
        }
        let gray = image.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0, kCIInputContrastKey: 1.3, kCIInputBrightnessKey: 0.04,
        ])
        // Nur dort zeichnen, wo auch vorher etwas war (die Ebene ist sonst durchsichtig)
        return gray.applyingFilter("CIColorThreshold", parameters: ["inputThreshold": 0.3])
            .applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: image])
    }
}
