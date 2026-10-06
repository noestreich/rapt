import SpriteKit

/// Pixel-Grafik für die Minispiele Invasion und Abrissbirne.
enum ArcadeArt {
    /// Zeichnet ein Bild aus Zeichen-Zeilen; jedes Zeichen steht für eine Farbe, "." ist transparent.
    private static func sprite(_ rows: [String], _ palette: [Character: UInt32]) -> PixelCanvas {
        var c = PixelCanvas(width: rows.map(\.count).max() ?? 1, height: rows.count)
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() {
                if let hex = palette[ch] { c.set(x, y, RGBA(hex: hex)) }
            }
        }
        return c
    }

    // MARK: Abrissbirne

    private static let shipPalette: [Character: UInt32] = [
        "V": 0xD8FAFF, "C": 0x3FD8FF, "W": 0xC9CEDD, "H": 0x8E94AA, "D": 0x4A4B56, "R": 0xE0452B, "E": 0x2A2A33,
    ]

    /// Jäger im Stil alter Vertikal-Shooter (Raptor): Spitze nach oben, gepfeilte Flügel, zwei Triebwerke.
    static func ship() -> SKTexture {
        sprite([
            "...........V...........",
            "..........WCW..........",
            ".........WCVCW.........",
            ".........WCCCW.........",
            "R.......WHHHHHW.......R",
            "RW.....WHHDHDHHW.....WR",
            "WHW...WHHHDHDHHHW...WHW",
            "WHHWWWHHHHDHDHHHHWWWHHW",
            "DHHHHHHHHHDHDHHHHHHHHHD",
            ".DDHHRRHHDDEDDHHRRHHDD.",
            "......EE.......EE......",
        ], shipPalette).texture()
    }

    /// Triebwerksflammen unter den beiden Düsen, drei flackernde Bilder (23 × 5).
    static func shipFlames() -> [SKTexture] {
        let palette: [Character: UInt32] = ["Y": 0xFFF3D6, "O": 0xFFB347, "R": 0xE0452B, "M": 0xFF4FA8]
        return [
            ["......YY.......YY......", "......OO.......OO......", "......RO.......OR......", ".......R.......R.......", "......................."],
            ["......YY.......YY......", "......YO.......OY......", "......OR.......RO......", "......R.........R......", ".......M.......M......."],
            ["......YY.......YY......", "......OO.......OO......", "......OR.......RO......", "......RR.......RR......", "......M.........M......"],
        ].map { sprite($0, palette).texture() }
    }

    /// Glühende Abrissbirne (5 × 5).
    static func ball() -> SKTexture {
        sprite([
            ".hHh.",
            "hWHHd",
            "HHHHd",
            "hHHdd",
            ".ddd.",
        ], ["W": 0xFFFFFF, "h": 0xFFE2B0, "H": 0xFFB070, "d": 0xC8501F]).texture()
    }

    // MARK: Invasion

    /// UFO, zwei Bilder mit wechselnden Lichtern (13 × 5).
    static func ufo() -> [SKTexture] {
        let palette: [Character: UInt32] = ["C": 0x3FD8FF, "V": 0xD8FAFF, "M": 0xB0307A, "m": 0xFF4FA8, "Y": 0xFFF3D6]
        return [
            ["....CCCCC....", "..CCVVVVVCC..", ".mmmmmmmmmmm.", "MMYMMMMYMMMMY", "..MM.....MM.."],
            ["....CCCCC....", "..CCVVVVVCC..", ".mmmmmmmmmmm.", "MMMMYMMMMYMMM", "..MM.....MM.."],
        ].map { sprite($0, palette).texture() }
    }

    /// Laserschuss des Läufers (1 × 5): heller Kern, cyanfarbenes Ende.
    static func bolt() -> SKTexture {
        sprite(["V", "V", "C", "C", "c"], ["V": 0xFFFFFF, "C": 0x3FD8FF, "c": 0x1A6A88]).texture()
    }

    /// Zickzack-Geschoss der Steine (3 × 4) in Steinfarbe.
    static func enemyShot(_ color: RGBA) -> SKTexture {
        var c = PixelCanvas(width: 3, height: 4)
        for (x, y) in [(0, 0), (1, 1), (2, 2), (1, 3)] { c.set(x, y, color) }
        c.set(1, 1, .white)
        return c.texture()
    }

    // MARK: Manga-Auftakt

    /// Konzentrationslinien wie im Manga: weiße Strahlen auf transparentem Grund, die zur Mitte zeigen
    /// und dort eine Lücke lassen. Größe 150 × 280, wird hart hochskaliert.
    static func speedLines(seed: Int) -> SKTexture {
        let w = 150, h = 280
        let cx = Double(w) / 2, cy = Double(h) / 2
        var c = PixelCanvas(width: w, height: h)
        let rays = 56
        let step = 2 * Double.pi / Double(rays)
        // Pro Strahl: Winkelversatz, Breite, Abstand des inneren Endes
        let jitter = (0..<rays).map { (Noise.hash($0, 1, seed) - 0.5) * step * 0.8 }
        let width = (0..<rays).map { 0.008 + Noise.hash($0, 2, seed) * 0.024 }
        let inner = (0..<rays).map { 34 + Noise.hash($0, 3, seed) * 34 }
        for y in 0..<h {
            for x in 0..<w {
                let dx = Double(x) + 0.5 - cx, dy = (Double(y) + 0.5 - cy) * 0.62
                let d = (dx * dx + dy * dy).squareRoot()
                guard d > 30 else { continue }
                let a = atan2(dy, dx) + .pi
                let k = Int((a / step).rounded()) % rays
                for r in [k, (k + 1) % rays, (k + rays - 1) % rays] {
                    let center = Double(r) * step + jitter[r]
                    var diff = abs(a - center)
                    diff = min(diff, 2 * .pi - diff)
                    // Strahlen werden nach außen breiter und laufen nach innen spitz zu
                    let taper = min(1, (d - inner[r]) / 40)
                    if taper > 0, diff < width[r] * taper {
                        c.set(x, y, .white)
                        break
                    }
                }
            }
        }
        return c.texture()
    }
}
