import SpriteKit

/// Porträts der Funk-Kontakte. Liegt im Bundle `portrait_<id>.png` (Querformat, 184 × 121,
/// erzeugt mit tools/import_portraits.py), wird diese verwendet, sonst ein Platzhalter (48 × 48).
enum PortraitArt {
    static let size = 48

    static func texture(for contact: Contact) -> SKTexture {
        if let url = Bundle.main.url(forResource: "portrait_\(contact.id)", withExtension: "png"),
           let data = try? Data(contentsOf: url),
           let provider = CGDataProvider(data: data as CFData),
           let image = CGImage(pngDataProviderSource: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) {
            let texture = SKTexture(cgImage: image)
            texture.filteringMode = .nearest
            return texture
        }
        return placeholder(contact).texture()
    }

    private static func shade(_ hex: UInt32, _ factor: Double) -> RGBA {
        let c = RGBA(hex: hex)
        return RGBA(Double(c.r) * factor, Double(c.g) * factor, Double(c.b) * factor)
    }

    static func placeholder(_ contact: Contact) -> PixelCanvas {
        let s = size
        var c = PixelCanvas(width: s, height: s)
        // Nachthimmel mit Neon-Plattenbauten
        for y in 0..<s {
            for x in 0..<s {
                let t = Double(y) / Double(s)
                c.set(x, y, RGBA(12 + 30 * t, 8 + 10 * t, 30 + 40 * t))
            }
        }
        var x = 0
        var seed = contact.id.unicodeScalars.reduce(7) { $0 &* 31 &+ Int($1.value) }
        while x < s {
            seed = seed &* 1_103_515_245 &+ 12345
            let w = 6 + abs(seed >> 8) % 7
            let h = 14 + abs(seed >> 12) % 18
            c.fillRect(x, s - h, w - 1, h, RGBA(hex: 0x1A1630))
            var wy = s - h + 2
            while wy < s - 2 {
                var wx = x + 1
                while wx < x + w - 2 {
                    if Noise.hash(wx, wy, seed & 0xFFFF) < 0.3 {
                        c.set(wx, wy, Noise.hash(wx, wy, 3) < 0.5 ? RGBA(hex: contact.accent) : RGBA(hex: 0xFF4FA8))
                    }
                    wx += 2
                }
                wy += 3
            }
            x += w
        }

        let skin = contact.skin, hair = contact.hair
        let cx = 25.0, cy = 20.0
        // Schultern und Jacke
        for y in 30..<s {
            for x in 0..<s {
                let half = 11 + Double(y - 30) * 0.9
                let dx = abs(Double(x) + 0.5 - cx)
                if dx < half {
                    let edge = dx > half - 1.5
                    c.set(x, y, edge ? shade(contact.jacket, 0.55) : shade(contact.jacket, 1 - dx / half * 0.35))
                }
            }
        }
        c.fillRect(Int(cx) - 6, 30, 12, 2, RGBA(hex: contact.accent))
        // Hals
        c.fillRect(Int(cx) - 3, 26, 6, 5, shade(skin, 0.75))

        // Kopf
        let headW = contact.look == .bald ? 9.5 : (contact.look == .robot ? 9.0 : 8.0)
        let headH = contact.look == .dog ? 8.5 : 10.0
        for y in 8..<30 {
            for x in 10..<40 {
                let dx = (Double(x) + 0.5 - cx) / headW, dy = (Double(y) + 0.5 - cy) / headH
                let robot = contact.look == .robot
                let inside = robot ? (abs(dx) < 1 && abs(dy) < 1) : dx * dx + dy * dy < 1
                guard inside else { continue }
                let light = 1.05 - dx * 0.35 - dy * 0.2
                c.set(x, y, shade(skin, clamp(light, 0.5, 1.15)))
            }
        }

        // Frisur, Augen, Extras
        let eye = contact.look == .robot || contact.look == .dog ? RGBA(hex: contact.accent) : RGBA(hex: 0x15121C)
        switch contact.look {
        case .bob:
            for y in 8..<26 {
                for x in 14..<37 {
                    let dx = (Double(x) + 0.5 - cx) / 10, dy = (Double(y) + 0.5 - 17) / 10
                    if dx * dx + dy * dy < 1 && (y < 15 || abs(dx) > 0.62) { c.set(x, y, shade(hair, y < 11 ? 1.4 : 1)) }
                }
            }
            c.fillRect(13, 18, 2, 6, RGBA(hex: contact.accent))
        case .bald:
            c.fillRect(17, 25, 16, 5, shade(hair, 1))
            c.fillRect(19, 24, 12, 1, shade(hair, 1))
            c.fillRect(29, 13, 1, 5, shade(skin, 0.6))
        case .mohawk:
            for y in 3..<14 {
                let w = 3 - (y < 6 ? 1 : 0)
                c.fillRect(Int(cx) - w / 2 - 1, y, w + 1, 1, shade(hair, y < 6 ? 1.2 : 1))
            }
            c.fillRect(18, 11, 2, 9, shade(hair, 0.8))
        case .bun:
            for y in 3..<16 {
                for x in 14..<37 {
                    let bun = pow(Double(x) - cx, 2) + pow(Double(y) - 6, 2) < 16
                    let top = pow((Double(x) - cx) / 9, 2) + pow((Double(y) - 14) / 6, 2) < 1 && y < 14
                    if bun || top { c.set(x, y, shade(hair, bun ? 1.15 : 1)) }
                }
            }
            c.fillRect(18, 18, 6, 2, RGBA(hex: 0x15121C))
            c.fillRect(27, 18, 6, 2, RGBA(hex: 0x15121C))
            c.fillRect(24, 18, 3, 1, RGBA(hex: 0x15121C))
        case .dog:
            for i in 0..<6 {
                c.fillRect(15 + i / 2, 6 + i, 3, 1, shade(skin, 1.1))
                c.fillRect(33 - i / 2, 6 + i, 3, 1, shade(skin, 1.1))
            }
            c.fillRect(21, 23, 9, 5, shade(skin, 0.9))
            c.fillRect(24, 23, 3, 2, RGBA(hex: 0x050409))
            c.fillRect(16, 16, 18, 4, RGBA(hex: 0x24222C))
        case .robot:
            c.fillRect(15, 15, 20, 7, RGBA(hex: 0x1A1418))
            c.fillRect(24, 6, 2, 4, shade(skin, 0.8))
            c.set(24, 5, RGBA(hex: contact.accent))
            c.fillRect(19, 25, 12, 1, RGBA(hex: 0x1A1418))
        }
        switch contact.look {
        case .robot:
            c.fillRect(18, 17, 4, 3, eye)
            c.fillRect(28, 17, 4, 3, eye)
        case .dog:
            c.fillRect(18, 17, 14, 2, eye)
        case .bun:
            c.fillRect(20, 18, 2, 2, RGBA(hex: contact.accent))
            c.fillRect(29, 18, 2, 2, RGBA(hex: contact.accent))
        default:
            c.fillRect(20, 18, 2, 2, eye)
            c.fillRect(29, 18, 2, 2, eye)
            c.set(20, 18, RGBA(hex: contact.accent))
            c.set(29, 18, RGBA(hex: contact.accent))
        }

        // Rahmen
        for i in 0..<s {
            c.set(i, 0, RGBA(hex: 0x050409)); c.set(i, s - 1, RGBA(hex: 0x050409))
            c.set(0, i, RGBA(hex: 0x050409)); c.set(s - 1, i, RGBA(hex: 0x050409))
        }
        return c
    }
}
