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

    /// Kastiger, verwitterter Glider (27 × 14) für die Abrissbirne: flaches Dach mit Nieten (davon prallt die
    /// Birne ab), offene Kabine für den Läufer, Rost, Warnstreifen, Seitendüsen und zwei Schwebedüsen unten.
    static func glider() -> SKTexture {
        let rows = [
            ".WWKWWWWKWWWWKWWWWKWWWWKWW.",
            ".HHHHHHHHHHHHHHHHHHHHHHHHH.",
            ".DDDDDDDDDDDDDDDDDDDDDDDDD.",
            "..HHHHHHK.........KHHHHHH..",
            ".HCHHHHHK.........KHHHHHCH.",
            "EHHHHHHHK.........KHHHHHHHE",
            "EHHHHHHHK.........KHHHHHHHE",
            ".HHHHHHHK.........KHHHHHHH.",
            ".DDDDDDDDDDDDDDDDDDDDDDDDD.",
            "..HrKrKHHHHHHHHHHHHHrKrKH..",
            "..HHrKrKHHHHHHHHHHHrKrKHH..",
            "...DDDDDDDDDDDDDDDDDDDDD...",
            ".....KKKEEKKKKKKKEEKKK.....",
            "........EE.......EE........",
        ]
        let palette: [Character: UInt32] = [
            "W": 0xB8BCC8, "H": 0x7E8494, "D": 0x4A4B56, "K": 0x22232B, "E": 0x14141A, "C": 0x3FD8FF, "r": 0xE0452B,
        ]
        let rust: [UInt32] = [0x5A2E1E, 0x8A4A2A, 0xB8642E]
        var c = PixelCanvas(width: 27, height: rows.count)
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() {
                guard var hex = palette[ch] else { continue }
                if ch == "H" || ch == "W" {
                    // Rostflecken in Gruppen, dazu vereinzelt dunklere Bleche
                    let n = Noise.hash(x / 2, y / 2, 7) * 0.6 + Noise.hash(x, y, 3) * 0.4
                    if n < 0.28 {
                        hex = rust[min(2, Int(Noise.hash(x, y, 9) * 3))]
                    } else if ch == "H" && Noise.hash(x, y, 5) < 0.12 {
                        hex = 0x6A6E7C
                    }
                }
                c.set(x, y, RGBA(hex: hex))
            }
        }
        return c.texture()
    }

    /// Dunkler Neon-Gleiter (23 × 12) für die Invasion: schwarzer Rumpf, magentafarbene Kanten und Unterleuchte,
    /// cyanfarbene Kanone oben (dort kommen die Schüsse heraus), offene Kanzel für den Läufer.
    static func pod() -> SKTexture {
        sprite([
            "...........V...........",
            "..........KCK..........",
            "......SSSSKCKSSSS......",
            ".....SSSSSKHKSSSSS.....",
            "....NSSS.......SSSN....",
            "...NSSSS.......SSSSN...",
            "..nSSSSS.......SSSSSn..",
            ".NSSSSSS.......SSSSSSN.",
            "ESSSSSSSDDDDDDDSSSSSSSE",
            ".SSNNNNNNNNNNNNNNNNNSS.",
            "..DDDDDDDDDDDDDDDDDDD..",
            "....KKKcKKKKKKKcKKK....",
        ], ["V": 0xD8FAFF, "C": 0x3FD8FF, "K": 0x0E0C14, "H": 0x3A3552, "S": 0x1E1A2A, "N": 0xFF4FA8,
            "n": 0x3FD8FF, "D": 0x2A2438, "E": 0x08070C, "c": 0x3FD8FF]).texture()
    }

    /// Seitlicher Schubstrahl (7 × 3), zeigt nach links; Ankerpunkt rechts an der Düse. Drei flackernde Bilder.
    /// `neon`: cyan-magenta statt Feuerfarben.
    static func sideFlames(neon: Bool) -> [SKTexture] {
        let palette: [Character: UInt32] = neon
            ? ["Y": 0xFFFFFF, "O": 0xD8FAFF, "R": 0x3FD8FF, "M": 0xFF4FA8]
            : ["Y": 0xFFF3D6, "O": 0xFFB347, "R": 0xE0452B, "M": 0xFF4FA8]
        return [
            ["....ROY", "..MROOY", "....ROY"],
            ["...RROY", ".MMROOY", "...RROY"],
            [".....OY", "...MROY", ".....OY"],
        ].map { sprite($0, palette).texture() }
    }

    /// Kleine Schwebeflammen unter den Düsen (1 × 3), flackernd.
    static func hoverFlames(neon: Bool) -> [SKTexture] {
        let palette: [Character: UInt32] = neon
            ? ["Y": 0xD8FAFF, "O": 0x3FD8FF, "M": 0xFF4FA8]
            : ["Y": 0xFFF3D6, "O": 0xFFB347, "M": 0xE0452B]
        return [["Y", "O", "M"], ["Y", "O", "."], ["Y", "M", "."]].map { sprite($0, palette).texture() }
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
