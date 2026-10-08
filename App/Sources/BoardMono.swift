import CoreImage

/// Spielbrett kurzzeitig in Graustufen: Steine und ihr Leuchten verlieren die Farbe, die Pixel-Art bleibt erhalten.
/// Stadt, Läufer, Anzeige und Turmlicht bleiben farbig. Ein- und Ausblenden über `amount`.
final class BoardMonoFilter: CIFilter {
    @objc dynamic var inputImage: CIImage?
    /// 0 = volle Farbe, 1 = ganz grau.
    var amount: CGFloat = 1

    override var outputImage: CIImage? {
        guard let image = inputImage else { return nil }
        let k = max(0, min(1, amount))
        return image.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 1 - k, kCIInputContrastKey: 1 + 0.1 * k, kCIInputBrightnessKey: 0,
        ])
    }
}

/// Stromausfall als Folge der Atombombe: Fenster flackern auf und gehen aus, das Spielbrett wird grau,
/// der Fernsehturm blinkt mit Notstrom rot weiter.
///
/// Zum Abschalten `enabled` auf `false` setzen.
enum PowerCut {
    static let enabled = true
    /// Wahrscheinlichkeit nach jeder Atombombe.
    static let chanceAfterAtomBomb = 1.0 / 3
    static let duration: TimeInterval = 5
}
