import RaptCore
import SpriteKit

/// Hintergründe, Beton-Flächen und Effekt-Texturen, alle prozedural.
enum Backdrop {
    private static let purple: [RGBA] = [0x07060D, 0x140C22, 0x2A1238, 0x4A1A46, 0x7A2648].map { RGBA(hex: $0) }
    private static let teal: [RGBA] = [0x07060D, 0x0B1626, 0x0F2A3A, 0x16485A, 0x2A7A7C].map { RGBA(hex: $0) }
    private static let concrete: [RGBA] = [0x2B2C33, 0x383943, 0x474854, 0x585A67].map { RGBA(hex: $0) }

    /// Gedithterter Nebel. (originX, originY) ist die linke obere Ecke in Design-Pixeln,
    /// damit der Nebel bei jeder Fenstergröße an derselben Stelle liegt.
    static func nebula(width: Int, height: Int, originX: Int, originY: Int) -> PixelCanvas {
        var c = PixelCanvas(width: width, height: height)
        for y in 0..<height {
            for x in 0..<width {
                let wx = x + originX, wy = y + originY
                let n1 = Noise.fbm(Double(wx) / 60, Double(wy) / 60, seed: 21, octaves: 5)
                let n2 = Noise.fbm(Double(wx) / 38, Double(wy) / 38, seed: 33, octaves: 4)
                let b = Noise.bayer(wx, wy)
                let density = pow(clamp((n1 - 0.36) * 2.3, 0, 1), 1.3)
                let level = clamp(Int(floor(density * 4.4 + b)), 0, 4)
                var col = (n2 + (b - 0.5) * 0.08) > 0.5 ? purple[level] : teal[level]
                let star = Noise.hash(wx, wy, 7)
                if star < 0.004 { col = RGBA(hex: 0xCDD6FF) } else if star < 0.006 { col = RGBA(hex: 0x786EAA) }
                c.set(x, y, col)
            }
        }
        return c
    }

    struct Skyline {
        let canvas: PixelCanvas
        let beacon: (x: Int, y: Int)
    }

    /// Hintere Häuserreihe und Fernsehturm, unten bündig. Die vordere Reihe wandert und entsteht über `building`.
    static func skyline(width: Int, seed: UInt64) -> Skyline {
        let height = 96
        var c = PixelCanvas(width: width, height: height)
        var rng = SplitMix64(seed: seed)
        func ri(_ n: Int) -> Int { Int(rng.unit() * Double(n)) }

        var x = -6
        while x < width {
            let w = 14 + ri(16)
            let h = 40 + ri(30)
            c.fillRect(x, height - h, w, h, RGBA(hex: 0x14131C))
            c.fillRect(x, height - h, w, 1, RGBA(hex: 0x1B1A25))
            x += w + ri(6)
        }
        // Fernsehturm
        let tx = Int(Double(width) * 0.86)
        let tower = RGBA(hex: 0x191822)
        c.fillRect(tx, 23, 3, height - 23, tower)
        c.fillRect(tx - 4, 41, 11, 4, tower)
        c.fillRect(tx + 1, 13, 1, 10, tower)
        return Skyline(canvas: c, beacon: (tx + 1, 12))
    }

    /// Ein Plattenbau der vorderen Reihe mit Fensterraster. `lights` sind erleuchtete Fenster für weiches Licht.
    /// `dark`: alle Fenster aus (Stromausfall).
    static func building(width: Int, height: Int, seed: Int, dark: Bool = false) -> (canvas: PixelCanvas, lights: [(x: Int, y: Int)]) {
        var c = PixelCanvas(width: width, height: height)
        var lights: [(x: Int, y: Int)] = []
        c.fillRect(0, 0, width, height, RGBA(hex: 0x232330))
        c.fillRect(0, 0, width, 1, RGBA(hex: 0x33333F))
        c.fillRect(width - 2, 1, 2, height - 1, RGBA(hex: 0x1B1B26))
        var wy = 4
        while wy < height - 3 {
            var wx = 3
            while wx < width - 4 {
                let h = Noise.hash(wx, wy, seed)
                let lit = !dark && h < 0.26
                let color: UInt32 = lit ? (Noise.hash(wx, wy, seed + 1) < 0.85 ? 0xE8A94A : 0x9FB4FF) : 0x121119
                c.fillRect(wx, wy, 2, 2, RGBA(hex: color))
                if lit && Noise.hash(wx, wy, seed + 2) < 0.3 { lights.append((wx + 1, wy + 1)) }
                wx += 4
            }
            wy += 5
        }
        return (c, lights)
    }

    /// Betonfläche mit Dithering; helle Oberkante, dunkle Unter- und Rechtskante.
    static func concreteSlab(width: Int, height: Int, seed: Int, originX: Int, originY: Int) -> PixelCanvas {
        var c = PixelCanvas(width: width, height: height)
        for y in 0..<height {
            for x in 0..<width {
                let n = Noise.fbm(Double(originX + x) / 9, Double(originY + y) / 9, seed: seed, octaves: 3)
                var idx = Int(clamp((n - 0.3) / 0.4 + (Noise.bayer(x, y) - 0.5) * 0.3, 0, 0.999) * 4)
                if y == 0 { idx = 3 }
                if y == height - 1 || x == width - 1 { idx = 0 }
                c.set(x, y, concrete[idx])
            }
        }
        return c
    }

    /// Betonplatte für die Punkteanzeige (184×68), liegt bei Design (8, 10).
    static func hudPlate() -> PixelCanvas {
        var c = concreteSlab(width: 184, height: 68, seed: 71, originX: 8, originY: 10)
        c.fillRect(0, 0, 5, 5, .clear)
        c.fillRect(179, 0, 5, 5, .clear)
        c.fillRect(10, 16, 164, 34, RGBA(hex: 0x0B0A11))
        c.fillRect(10, 16, 164, 1, RGBA(hex: 0x050409))
        c.fillRect(10, 49, 164, 1, RGBA(hex: 0x4A4B56))
        for y in 56..<62 {
            for x in 0..<184 {
                c.set(x, y, ((x + y) >> 2) & 1 == 1 ? RGBA(hex: 0xB8321F) : RGBA(hex: 0x1A1418))
            }
        }
        // Spielname als Logo: 2-fach, mit Schatten
        var logo = PixelCanvas(width: PixelFont.width("RAPT"), height: PixelFont.lineHeight)
        PixelFont.draw("RAPT", into: &logo, x: 0, y: 0, color: .white)
        for y in 0..<logo.height * 2 {
            for x in 0..<logo.width * 2 where logo.get(x / 2, y / 2).a > 0 {
                c.set(12 + x + 1, 3 + y + 1, RGBA(hex: 0x3A0E08))
            }
        }
        for y in 0..<logo.height * 2 {
            for x in 0..<logo.width * 2 where logo.get(x / 2, y / 2).a > 0 {
                c.set(12 + x, 3 + y, y < 5 ? RGBA(hex: 0xFF6A3D) : RGBA(hex: 0xD8341E))
            }
        }
        return c
    }

    /// Betonrahmen um das Brett mit dunklem Innenfeld und Raster.
    static func boardFrame(tile: Int, count: Int) -> PixelCanvas {
        let inner = tile * count
        let size = inner + 12
        var c = concreteSlab(width: size, height: size, seed: 83, originX: 0, originY: 0)
        for (x, y) in [(0, 0), (size - 3, 0), (0, size - 3), (size - 3, size - 3)] {
            c.fillRect(x, y, 3, 3, .clear)
        }
        c.fillRect(5, 5, inner + 2, inner + 2, RGBA(hex: 0x0A0912))
        for i in 1..<count {
            c.fillRect(6 + i * tile, 6, 1, inner, RGBA(hex: 0x13111E))
            c.fillRect(6, 6 + i * tile, inner, 1, RGBA(hex: 0x13111E))
        }
        return c
    }

    // MARK: Effekt-Texturen

    /// Weiche, weiße Lichtkugel; wird per Farbe eingefärbt und additiv gezeichnet.
    static func glow(size: Int = 64) -> SKTexture {
        var c = PixelCanvas(width: size, height: size)
        let r = Double(size) / 2
        for y in 0..<size {
            for x in 0..<size {
                let d = ((Double(x) + 0.5 - r) * (Double(x) + 0.5 - r) + (Double(y) + 0.5 - r) * (Double(y) + 0.5 - r)).squareRoot() / r
                guard d < 1 else { continue }
                let a = d < 0.35 ? 1 - d / 0.35 * 0.65 : 0.35 * pow(1 - (d - 0.35) / 0.65, 2)
                c.set(x, y, RGBA(255, 255, 255, a * 255))
            }
        }
        return c.texture(smooth: true)
    }

    /// Weicher Ring für Schockwellen.
    static func ring(size: Int = 128) -> SKTexture {
        var c = PixelCanvas(width: size, height: size)
        let r = Double(size) / 2
        for y in 0..<size {
            for x in 0..<size {
                let d = ((Double(x) + 0.5 - r) * (Double(x) + 0.5 - r) + (Double(y) + 0.5 - r) * (Double(y) + 0.5 - r)).squareRoot() / r
                let a = exp(-pow((d - 0.85) / 0.07, 2)) + 0.25 * exp(-pow((d - 0.7) / 0.15, 2))
                c.set(x, y, RGBA(255, 255, 255, clamp(a, 0, 1) * 255))
            }
        }
        return c.texture(smooth: true)
    }

    /// Verlauf für den Bildschirmrand: links deckend, nach rechts ausblendend (oder unten → oben bei `vertical`).
    static func edgeGradient(vertical: Bool) -> SKTexture {
        let n = 48
        var c = vertical ? PixelCanvas(width: 1, height: n) : PixelCanvas(width: n, height: 1)
        for i in 0..<n {
            let a = pow(1 - Double(i) / Double(n - 1), 1.8)
            if vertical { c.set(0, n - 1 - i, RGBA(255, 255, 255, a * 255)) } else { c.set(i, 0, RGBA(255, 255, 255, a * 255)) }
        }
        return c.texture(smooth: true)
    }

    /// Senkrechter Verlauf, transparent – weiß – transparent. Für Strahlen quer übers Brett.
    static func beam() -> SKTexture {
        var c = PixelCanvas(width: 1, height: 32)
        for y in 0..<32 {
            let d = abs(Double(y) + 0.5 - 16) / 16
            c.set(0, y, RGBA(255, 255, 255, pow(1 - d, 2) * 255))
        }
        return c.texture(smooth: true)
    }

    /// Pixel-Explosion im Raptor-Stil: Feuerball, der in Glut und Rauch zerfällt.
    static func explosionFrames(seed: Int, frames: Int = 12, size: Int = 44) -> [SKTexture] {
        (0..<frames).map { f in
            var c = PixelCanvas(width: size, height: size)
            let a = Double(f) / Double(frames - 1)
            let radius = 3 + a * 18
            let mid = size / 2
            for dy in -mid..<mid {
                for dx in -mid..<mid {
                    let wobble = 0.85 + 0.3 * Noise.value(Double(dx) / 4, Double(dy) / 4, seed: seed)
                    let d = (Double(dx * dx + dy * dy)).squareRoot() / (radius * wobble)
                    guard d <= 1 else { continue }
                    let n = Noise.hash(dx + seed, dy, f * 7 + seed)
                    if n < a * 1.1 - 0.1 + d * 0.25 { continue }
                    var col: UInt32
                    if d < 0.4 && a < 0.35 { col = 0xFFF1B3 } else if d < 0.65 { col = 0xF5A02A } else if d < 0.85 { col = 0xCF4A1A } else { col = 0x4A1A0C }
                    if a > 0.55 { col = d < 0.6 ? 0x5B2A14 : 0x2A1712 }
                    c.set(mid + dx, mid + dy, RGBA(hex: col))
                }
            }
            return c.texture()
        }
    }

    /// Dampfwolke, die aufquillt und sich in Dither-Pixeln auflöst.
    static func steamFrames(seed: Int, frames: Int = 10, size: Int = 26) -> [SKTexture] {
        let shades: [RGBA] = [0x5E6378, 0x8E94AA, 0xC9CEDD].map { RGBA(hex: $0) }
        return (0..<frames).map { f in
            var c = PixelCanvas(width: size, height: size)
            let a = Double(f) / Double(frames - 1)
            let radius = 4 + a * 8
            let mid = Double(size) / 2
            for y in 0..<size {
                for x in 0..<size {
                    let dx = Double(x) + 0.5 - mid, dy = (Double(y) + 0.5 - mid) * 1.15
                    let n = Noise.fbm(Double(x) / 5, Double(y) / 5 - a * 2, seed: seed, octaves: 3)
                    let d = (dx * dx + dy * dy).squareRoot() / radius - (n - 0.5) * 0.8
                    guard d < 1 else { continue }
                    let fade = a * 1.15 + d * 0.35
                    if Noise.bayer(x, y) < fade - 0.25 { continue }
                    let lightness = clamp(Int((1 - d) * 2.2 + (0.5 - dy / radius / 2) * 0.8), 0, 2)
                    c.set(x, y, shades[lightness])
                }
            }
            return c.texture()
        }
    }
}
