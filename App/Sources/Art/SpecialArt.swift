import RaptCore
import SpriteKit

/// Pixel-Grafik für Spezialsteine. Linie und Bombe sind Overlays über dem normalen Stein,
/// der Hyperstein hat eigene, animierte Bilder.
enum SpecialArt {
    static let size = GemArt.tile

    /// Leuchtband quer über den Stein, mit Pfeilspitzen an den Enden.
    static func lineOverlay(horizontal: Bool) -> SKTexture {
        var c = PixelCanvas(width: size, height: size)
        let core = RGBA(hex: 0xFFFFFF), edge = RGBA(hex: 0xFFF3D6, alpha: 170)
        for i in 0..<size {
            for (offset, color) in [(9, edge), (10, core), (11, core), (12, edge)] {
                if horizontal { c.set(i, offset, color) } else { c.set(offset, i, color) }
            }
        }
        // Pfeilspitzen
        for k in 0..<3 {
            for d in -k...k {
                let a = 2 - k, b = size - 3 + k
                if horizontal {
                    c.set(a, 10 + d, core); c.set(a, 11 + d, core)
                    c.set(b, 10 + d, core); c.set(b, 11 + d, core)
                } else {
                    c.set(10 + d, a, core); c.set(11 + d, a, core)
                    c.set(10 + d, b, core); c.set(11 + d, b, core)
                }
            }
        }
        return c.texture()
    }

    /// Linien-Stein: flackernde Plasma-Flammen an beiden Enden in der Steinfarbe.
    /// Waagerecht 34×22 (links und rechts), senkrecht 22×34 (oben und unten). Liegt hinter dem Stein.
    static func lineFlames(ramp: [RGBA], horizontal: Bool, frames: Int = 6) -> [SKTexture] {
        let long = size + 12, short = size
        return (0..<frames).map { f in
            var c = horizontal ? PixelCanvas(width: long, height: short) : PixelCanvas(width: short, height: long)
            let mid = Double(short) / 2
            for side in 0..<2 {
                let length = 8.0 + 2.5 * Noise.hash(f, side, 11)
                for u in 0..<12 {
                    // u = 0 liegt 3 px im Stein, wächst nach außen
                    let out = Double(u) - 3
                    let fade = 1 - max(0, out) / length
                    guard fade > 0 else { continue }
                    let half = 4.6 * fade + 0.6
                    for v in 0..<short {
                        let dy = abs(Double(v) + 0.5 - mid)
                        let flicker = 0.7 + 0.5 * Noise.hash(u + side * 31, v, f * 7 + 3)
                        guard dy <= half * flicker else { continue }
                        let k = fade - dy / (half + 1) * 0.55
                        let color: RGBA
                        if k > 0.84 { color = .white } else if k > 0.48 { color = ramp[4] } else if k > 0.26 { color = ramp[3] } else { color = ramp[2] }
                        let along = side == 0 ? (6 + 2 - u) : (long - 6 - 3 + u)
                        if horizontal { c.set(along, v, color) } else { c.set(v, along, color) }
                    }
                }
                // Funken vor der Flamme
                for k in 0..<2 where Noise.hash(f, side * 5 + k, 23) < 0.6 {
                    let along = side == 0 ? Int(Noise.hash(f, k, 29) * 3) : long - 1 - Int(Noise.hash(f, k, 29) * 3)
                    let across = Int(mid) - 3 + Int(Noise.hash(f, k, 31) * 6)
                    if horizontal { c.set(along, across, ramp[4]) } else { c.set(across, along, ramp[4]) }
                }
            }
            return c.texture()
        }
    }

    /// Stachelring mit Zündfunke.
    static func bombOverlay() -> SKTexture {
        var c = PixelCanvas(width: size, height: size)
        let mid = Double(size) / 2
        for y in 0..<size {
            for x in 0..<size {
                let dx = Double(x) + 0.5 - mid, dy = Double(y) + 0.5 - mid
                let d = (dx * dx + dy * dy).squareRoot()
                let angle = atan2(dy, dx)
                let spike = abs(sin(angle * 4)) > 0.93
                if d >= 9.2 && d < 10.6 {
                    c.set(x, y, RGBA(hex: 0x24222C))
                } else if spike && d >= 10.6 && d < 11.6 {
                    c.set(x, y, RGBA(hex: 0xFF8A3D))
                }
            }
        }
        c.set(16, 3, RGBA(hex: 0xFFD27A))
        c.set(17, 2, RGBA(hex: 0xFFFFFF))
        c.set(18, 3, RGBA(hex: 0xFFD27A))
        c.set(17, 4, RGBA(hex: 0xFF8A3D))
        return c.texture()
    }

    /// Hyperstein: dunkle Chromkugel mit wirbelnden Regenbogen-Facetten. `frames` Bilder für eine Drehung.
    static func hyperFrames(frames: Int = 8) -> [SKTexture] {
        (0..<frames).map { f in
            var c = PixelCanvas(width: size, height: size)
            let mid = Double(size) / 2
            let r = 9.6
            var inside = [Bool](repeating: false, count: size * size)
            for y in 0..<size {
                for x in 0..<size {
                    let dx = Double(x) + 0.5 - mid, dy = Double(y) + 0.5 - mid
                    let d = (dx * dx + dy * dy).squareRoot()
                    guard d < r else { continue }
                    inside[y * size + x] = true
                    let angle = atan2(dy, dx) + Double(f) / Double(frames) * 2 * .pi + d * 0.35
                    let band = Int(floor((angle / (2 * .pi) + 1) * 7)) % 7
                    let look = GemArt.look(Gem.allCases[band])
                    let shade = 1 - d / r * 0.55 - (dy / r) * 0.15
                    var color = hsl(look.hue, look.sat, clamp(look.light * shade, 8, 80))
                    if d < 3.2 { color = RGBA(hex: 0x0B0A11) }
                    if d < 1.6 { color = RGBA(hex: 0xFFFFFF) }
                    c.set(x, y, color)
                }
            }
            for y in 0..<size {
                for x in 0..<size where !inside[y * size + x] {
                    let near = (x > 0 && inside[y * size + x - 1]) || (x < size - 1 && inside[y * size + x + 1])
                        || (y > 0 && inside[(y - 1) * size + x]) || (y < size - 1 && inside[(y + 1) * size + x])
                    if near { c.set(x, y, RGBA(hex: 0x050409)) }
                }
            }
            c.set(7, 6, .white)
            c.set(8, 5, .white)
            return c.texture()
        }
    }
}
