import RaptCore
import SpriteKit

/// Pixel-Grafik für Power-ups, den Fressautomaten und die Figur auf den Dächern.
enum PowerUpArt {
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

    // MARK: Figur

    private static let figurePalette: [Character: UInt32] = [
        "H": 0x4A4468, "h": 0x7A70A8, "V": 0x3FD8FF, "v": 0xD8FAFF, "f": 0xD9A27A, "J": 0x3A3552, "j": 0x564E78,
        "N": 0xFF4FA8, "C": 0x3FD8FF, "P": 0x2E2C44, "B": 0x14121C, "G": 0x8E94AA, "S": 0x3FD8FF,
    ]

    /// Cyberpunk-Läufer mit Kapuze, Leuchtvisier, Neon-Saum und Lichtsohlen. Blickrichtung rechts;
    /// gespiegelt (xScale -1) schaut er zurück. Zwei Stehbilder (Atmen) und ein Sprungbild.
    static func figureFrames() -> (idle: [SKTexture], jump: SKTexture) {
        let stand1 = [
            "..HHh..", ".HHHHh.", ".HHVvVC", "..Hff..", ".jNJJj.",
            "G.JJJ.G", "..JCJ..", "..P.P..", "..P.P..", ".BS.BS.",
        ]
        let stand2 = [
            ".......", "..HHh..", ".HHHHh.", ".HHVvVC", "..Hff..",
            "GjNJJjG", "..JJJ..", "..JCJ..", "..P.P..", ".BS.BS.",
        ]
        let jump = [
            "G.HHh.G", "jHHHHhj", ".HHVvVC", "..Hff..", ".jNJJj.",
            "..JJJ..", "..JCJ..", ".P...P.", "P.....P", "B.....B",
        ]
        return ([sprite(stand1, figurePalette).texture(), sprite(stand2, figurePalette).texture()],
                sprite(jump, figurePalette).texture())
    }

    // MARK: Fresser

    /// Runder Fressautomat mit Stahlkiefer, Maul nach rechts. `mouth` ist der halbe Öffnungswinkel in Grad.
    static func chomper(mouth: Double, size: Int = 18) -> SKTexture {
        var c = PixelCanvas(width: size, height: size)
        let r = Double(size) / 2 - 1
        let mid = Double(size) / 2
        let ramp: [RGBA] = [0x7A2A10, 0xC8501F, 0xF08A2A, 0xFFD27A].map { RGBA(hex: $0) }
        var inside = [Bool](repeating: false, count: size * size)
        for y in 0..<size {
            for x in 0..<size {
                let dx = Double(x) + 0.5 - mid, dy = Double(y) + 0.5 - mid
                guard (dx * dx + dy * dy).squareRoot() <= r else { continue }
                let angle = abs(atan2(dy, dx)) * 180 / .pi
                if angle < mouth { continue }
                inside[y * size + x] = true
                let light = (-dx - dy) / (r * 2) + 0.5 - (dx * dx + dy * dy) / (r * r) * 0.25
                var color = ramp[clamp(Int(light * 4), 0, 3)]
                // Stahlkiefer an der Maulkante
                if mouth > 1, angle < mouth + 9, (dx * dx + dy * dy).squareRoot() > 2 {
                    color = Noise.hash(x, y, 4) < 0.5 ? RGBA(hex: 0xC9CEDD) : RGBA(hex: 0x8E94AA)
                }
                c.set(x, y, color)
            }
        }
        for y in 0..<size {
            for x in 0..<size where !inside[y * size + x] {
                let near = (x > 0 && inside[y * size + x - 1]) || (x < size - 1 && inside[y * size + x + 1])
                    || (y > 0 && inside[(y - 1) * size + x]) || (y < size - 1 && inside[(y + 1) * size + x])
                if near { c.set(x, y, RGBA(hex: 0x1A0A06)) }
            }
        }
        // Nietenauge
        c.set(size / 2 + 1, size / 2 - 5, RGBA(hex: 0x1A0A06))
        c.set(size / 2 + 2, size / 2 - 5, RGBA(hex: 0x1A0A06))
        c.set(size / 2 + 1, size / 2 - 6, RGBA(hex: 0xFFF3D6))
        return c.texture()
    }

    static func chomperFrames() -> [SKTexture] {
        [chomper(mouth: 0), chomper(mouth: 22), chomper(mouth: 42), chomper(mouth: 22)]
    }

    // MARK: Symbole fürs Lager (16×16)

    static func icon(_ kind: PowerUp) -> SKTexture {
        switch kind {
        case .bombe: return bombIcon().texture()
        case .farbtilger: return purgeIcon().texture()
        case .fresser: return chomper(mouth: 30, size: 16)
        case .strudel: return spiralIcon().texture()
        case .atom: return atomIcon().texture()
        }
    }

    /// Violetter Strudel.
    private static func spiralIcon() -> PixelCanvas {
        var c = PixelCanvas(width: 16, height: 16)
        let ramp: [RGBA] = [0x2A1238, 0x6A2A8A, 0xA858D8, 0xE0B0FF].map { RGBA(hex: $0) }
        for y in 0..<16 {
            for x in 0..<16 {
                let dx = Double(x) - 7.5, dy = Double(y) - 7.5
                let d = (dx * dx + dy * dy).squareRoot()
                guard d <= 7.4 else { continue }
                let arm = sin(atan2(dy, dx) * 2 + d * 0.9)
                let level = clamp(Int((arm * 0.5 + 0.5) * 3.2 + (1 - d / 7.4) * 1.2), 0, 3)
                c.set(x, y, d > 6.6 ? RGBA(hex: 0x120E18) : ramp[level])
            }
        }
        return c
    }

    /// Strahlenwarnzeichen.
    private static func atomIcon() -> PixelCanvas {
        var c = PixelCanvas(width: 16, height: 16)
        for y in 0..<16 {
            for x in 0..<16 {
                let dx = Double(x) - 7.5, dy = Double(y) - 7.5
                let d = (dx * dx + dy * dy).squareRoot()
                guard d <= 7.6 else { continue }
                var a = atan2(dy, dx) + .pi / 2 + .pi / 6
                a = (a.truncatingRemainder(dividingBy: 2 * .pi / 3) + 2 * .pi / 3).truncatingRemainder(dividingBy: 2 * .pi / 3)
                let blade = a < .pi / 3 && d > 2.6 && d < 6.4
                let color: UInt32 = d > 6.8 ? 0x120E18 : (d < 1.6 || blade ? 0x1A1418 : 0xF0C23A)
                c.set(x, y, RGBA(hex: color))
            }
        }
        return c
    }

    private static func bombIcon() -> PixelCanvas {
        sprite([
            "................",
            "............Y...",
            "...........YWY..",
            "..........w.Y...",
            ".........w......",
            "......KKw.......",
            ".....KMMKK......",
            "...KKKKKKKKK....",
            "..KKHHKKKKKKK...",
            "..KHHKKKKKKKK...",
            ".KKHKKKKKKKKKK..",
            ".KKKKKKKKKKKKK..",
            ".KKKKKKKKKKKKK..",
            "..KKKKKKKKKKK...",
            "...KKKKKKKKK....",
            ".....KKKKK......",
        ], ["K": 0x24222C, "H": 0x6E6E7A, "M": 0x585A67, "w": 0xC9B08A, "Y": 0xFFD27A, "W": 0xFFFFFF])
    }

    /// Prisma, dessen Streifen alle Steinfarben zeigen.
    private static func purgeIcon() -> PixelCanvas {
        var c = PixelCanvas(width: 16, height: 16)
        let colors = Gem.allCases.map { gem -> RGBA in
            let l = GemArt.look(gem)
            return hsl(l.hue, l.sat, l.light + 6)
        }
        for y in 0..<16 {
            for x in 0..<16 {
                let d = abs(Double(x) - 7.5) + abs(Double(y) - 7.5) * 0.9
                if d <= 7 {
                    let band = clamp((y - 1) * colors.count / 14, 0, colors.count - 1)
                    var color = colors[band]
                    if Double(x) < 7.5 - (7 - abs(Double(y) - 7.5) * 0.9) + 2 { color = RGBA(Double(color.r) * 1.2 + 30, Double(color.g) * 1.2 + 30, Double(color.b) * 1.2 + 30) }
                    c.set(x, y, color)
                } else if d <= 8 {
                    c.set(x, y, RGBA(hex: 0x120E18))
                }
            }
        }
        c.set(5, 4, .white)
        c.set(6, 3, .white)
        return c
    }

    /// Rahmen für einen Lagerplatz (20×20).
    static func slotFrame() -> PixelCanvas {
        var c = PixelCanvas(width: 20, height: 20, fill: RGBA(hex: 0x121110))
        c.fillRect(1, 1, 18, 18, RGBA(hex: 0x4A4641))
        c.fillRect(1, 1, 18, 1, RGBA(hex: 0x6E6A64))
        c.fillRect(2, 2, 16, 16, RGBA(hex: 0x1B1A19))
        return c
    }
}
