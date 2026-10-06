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

    struct FigureFrames {
        /// Zwei Stehbilder (Atmen).
        let idle: [SKTexture]
        /// Arme hoch: Sprung und Strecken.
        let jump: SKTexture
        let crouch: SKTexture
        /// Winken mit dem hinteren Arm, zwei Bilder im Wechsel.
        let wave: [SKTexture]
        /// Blick aufs Armband-Terminal.
        let wrist: SKTexture
    }

    /// Cyberpunk-Läufer mit Kapuze, Leuchtvisier, Neon-Saum und Lichtsohlen. Blickrichtung rechts;
    /// gespiegelt (xScale -1) schaut er zurück.
    static func figureFrames() -> FigureFrames {
        func t(_ rows: [String]) -> SKTexture { sprite(rows, figurePalette).texture() }
        return FigureFrames(
            idle: [
                t(["..HHh..", ".HHHHh.", ".HHVvVC", "..Hff..", ".jNJJj.",
                   "G.JJJ.G", "..JCJ..", "..P.P..", "..P.P..", ".BS.BS."]),
                t([".......", "..HHh..", ".HHHHh.", ".HHVvVC", "..Hff..",
                   "GjNJJjG", "..JJJ..", "..JCJ..", "..P.P..", ".BS.BS."]),
            ],
            jump: t(["G.HHh.G", "jHHHHhj", ".HHVvVC", "..Hff..", ".jNJJj.",
                     "..JJJ..", "..JCJ..", ".P...P.", "P.....P", "B.....B"]),
            crouch: t([".......", ".......", "..HHh..", ".HHHHh.", ".HHVvVC",
                       "..Hff..", "GjNJJjG", "..JCJ..", ".PP.PP.", ".BS.BS."]),
            wave: [
                t(["G.HHh..", "jHHHHh.", ".HHVvVC", "..Hff..", ".jNJJj.",
                   "..JJJ.G", "..JCJ..", "..P.P..", "..P.P..", ".BS.BS."]),
                t(["..HHh..", "GHHHHh.", "jHHVvVC", "..Hff..", ".jNJJj.",
                   "..JJJ.G", "..JCJ..", "..P.P..", "..P.P..", ".BS.BS."]),
            ],
            wrist: t(["..HHh..", ".HHHHh.", ".HHVvVC", "..Hff..", ".jNJJjG",
                      "G.JJJj.", "..JCJ..", "..P.P..", "..P.P..", ".BS.BS."])
        )
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
        case .invasion: return invaderIcon().texture()
        case .abriss: return wreckingBallIcon().texture()
        }
    }

    /// Pixel-Invader in Magenta mit dunklem Rand.
    private static func invaderIcon() -> PixelCanvas {
        var c = PixelCanvas(width: 16, height: 16)
        let rows = [
            "..X.....X..",
            "...X...X...",
            "..XXXXXXX..",
            ".XX.XXX.XX.",
            "XXXXXXXXXXX",
            "X.XXXXXXX.X",
            "X.X.....X.X",
            "...XX.XX...",
        ]
        let ox = 2, oy = 4
        var inside = Set<Int>()
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() where ch == "X" {
                inside.insert((oy + y) * 16 + ox + x)
                c.set(ox + x, oy + y, y < 3 ? RGBA(hex: 0xFFB0D8) : RGBA(hex: 0xFF4FA8))
            }
        }
        for y in 0..<16 {
            for x in 0..<16 where !inside.contains(y * 16 + x) {
                let near = [(1, 0), (-1, 0), (0, 1), (0, -1)].contains { inside.contains((y + $0.1) * 16 + x + $0.0) && (0..<16).contains(x + $0.0) }
                if near { c.set(x, y, RGBA(hex: 0x1A0A12)) }
            }
        }
        return c
    }

    /// Glühende Abrissbirne an einer Kette, mit Schwungstrichen.
    private static func wreckingBallIcon() -> PixelCanvas {
        var c = PixelCanvas(width: 16, height: 16)
        // Kette nach oben rechts
        for (i, (x, y)) in [(13, 0), (12, 1), (12, 2), (11, 3), (10, 4), (10, 5), (9, 6)].enumerated() {
            c.set(x, y, i % 2 == 0 ? RGBA(hex: 0xC9CEDD) : RGBA(hex: 0x6E6A80))
        }
        let ramp: [RGBA] = [0x7A2A10, 0xC8501F, 0xFFB070, 0xFFE2B0].map { RGBA(hex: $0) }
        let cx = 7.0, cy = 10.5, r = 5.2
        var inside = Set<Int>()
        for y in 0..<16 {
            for x in 0..<16 {
                let dx = Double(x) + 0.5 - cx, dy = Double(y) + 0.5 - cy
                let d = (dx * dx + dy * dy).squareRoot()
                guard d <= r else { continue }
                inside.insert(y * 16 + x)
                let light = 0.6 - (dx + dy) / (r * 2.6) - d / r * 0.3
                c.set(x, y, ramp[clamp(Int(light * 4), 0, 3)])
            }
        }
        for y in 0..<16 {
            for x in 0..<16 where !inside.contains(y * 16 + x) {
                let near = [(1, 0), (-1, 0), (0, 1), (0, -1)].contains { inside.contains((y + $0.1) * 16 + x + $0.0) && (0..<16).contains(x + $0.0) }
                if near { c.set(x, y, RGBA(hex: 0x1A0A06)) }
            }
        }
        c.set(5, 8, .white)
        // Schwungstriche links
        for (x, y) in [(0, 7), (0, 8), (1, 12), (0, 13)] { c.set(x, y, RGBA(hex: 0xFFB347)) }
        return c
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

    /// Rote Bombe mit Totenkopf, Metallkappe, Zündschnur und Funke.
    private static func bombIcon() -> PixelCanvas {
        var c = PixelCanvas(width: 16, height: 16)
        let ramp: [RGBA] = [0x6A1208, 0xA8200F, 0xD8341E, 0xFF6A4A].map { RGBA(hex: $0) }
        let cx = 7.0, cy = 9.5, r = 6.2
        var inside = [Bool](repeating: false, count: 256)
        for y in 0..<16 {
            for x in 0..<16 {
                let dx = Double(x) + 0.5 - cx, dy = Double(y) + 0.5 - cy
                let d = (dx * dx + dy * dy).squareRoot()
                guard d <= r else { continue }
                inside[y * 16 + x] = true
                let light = 0.55 - (dx + dy) / (r * 2.4) - d / r * 0.25
                c.set(x, y, ramp[clamp(Int(light * 4), 0, 3)])
            }
        }
        for y in 0..<16 {
            for x in 0..<16 where !inside[y * 16 + x] {
                let near = (x > 0 && inside[y * 16 + x - 1]) || (x < 15 && inside[y * 16 + x + 1])
                    || (y > 0 && inside[(y - 1) * 16 + x]) || (y < 15 && inside[(y + 1) * 16 + x])
                if near { c.set(x, y, RGBA(hex: 0x1A0A06)) }
            }
        }
        // Totenkopf
        let skull = [".WWW.", "WKWKW", "WWWWW", ".WKW.", ".W.W."]
        for (y, row) in skull.enumerated() {
            for (x, ch) in row.enumerated() {
                if ch == "W" { c.set(5 + x, 8 + y, RGBA(hex: 0xF3E6C8)) }
                if ch == "K" { c.set(5 + x, 8 + y, RGBA(hex: 0x1A0A06)) }
            }
        }
        // Glanzpunkt, Kappe, Zündschnur, Funke
        c.set(4, 6, RGBA(hex: 0xFFC0A8))
        c.set(5, 5, RGBA(hex: 0xFFC0A8))
        c.fillRect(8, 2, 3, 2, RGBA(hex: 0x8E94AA))
        c.fillRect(8, 2, 3, 1, RGBA(hex: 0xC9CEDD))
        c.set(11, 1, RGBA(hex: 0xC9B08A))
        c.set(12, 0, RGBA(hex: 0xFFD27A))
        c.set(13, 1, RGBA(hex: 0xFFD27A))
        c.set(12, 1, RGBA(hex: 0xFFFFFF))
        c.set(14, 0, RGBA(hex: 0xFF8A3D))
        return c
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
