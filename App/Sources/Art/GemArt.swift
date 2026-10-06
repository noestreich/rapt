import RaptCore
import SpriteKit

/// Prozedurale Pixel-Steine (22 px). Die Form kommt aus einem Distanzfeld, die Facetten aus dessen Steigung.
enum GemArt {
    static let tile = 22
    /// Der Stein `.zahnrad` wird als pinkes Herz gezeichnet. `true` holt das alte orange Zahnrad zurück.
    static let useGear = false

    struct Look {
        let hue: Double
        let sat: Double
        let light: Double
    }

    struct Sprite {
        let texture: SKTexture
        /// Fünf Farbstufen von dunkel nach hell, z. B. für Splitter in der Steinfarbe.
        let ramp: [RGBA]
    }

    static func look(_ gem: Gem) -> Look {
        switch gem {
        case .orden: return Look(hue: 356, sat: 82, light: 52)
        case .zahnrad: return useGear ? Look(hue: 24, sat: 88, light: 54) : Look(hue: 334, sat: 85, light: 62)
        case .signal: return Look(hue: 47, sat: 92, light: 56)
        case .uranglas: return Look(hue: 96, sat: 75, light: 48)
        case .kristall: return Look(hue: 200, sat: 85, light: 54)
        case .roehre: return Look(hue: 286, sat: 62, light: 58)
        case .niete: return Look(hue: 215, sat: 10, light: 72)
        }
    }

    static func glowColor(_ gem: Gem) -> SKColor {
        let l = look(gem)
        return hsl(l.hue, l.sat, min(70, l.light + 8)).skColor
    }

    private static func poly(_ u: Double, _ v: Double, _ n: Int, _ r: Double, _ rot: Double) -> Double {
        var m = -Double.greatestFiniteMagnitude
        for i in 0..<n {
            let a = rot + 2 * .pi * Double(i) / Double(n)
            m = max(m, u * cos(a) + v * sin(a))
        }
        return m - r
    }

    /// d < 0 heißt innen; h ist die Höhe der Facette (0 am Rand, 1 auf dem Plateau).
    static func field(_ gem: Gem, _ u: Double, _ v: Double) -> (d: Double, h: Double) {
        let l = (u * u + v * v).squareRoot()
        let tau = 2 * Double.pi
        let d: Double
        switch gem {
        case .orden:
            d = poly(u, v, 8, 0.8, tau / 16)
        case .zahnrad where useGear:
            let tooth = clamp(cos(atan2(v, u) * 8) * 2.5, -1, 1) * 0.5 + 0.5
            d = max(l - (0.6 + 0.24 * tooth), 0.2 - l)
        case .zahnrad:
            // Herz: zwei Kreise oben, nach unten spitz zulaufende Raute
            let left = ((u + 0.32) * (u + 0.32) + (v + 0.22) * (v + 0.22)).squareRoot() - 0.42
            let right = ((u - 0.32) * (u - 0.32) + (v + 0.22) * (v + 0.22)).squareRoot() - 0.42
            d = min(left, right, poly(u, v - 0.02, 4, 0.56, tau / 8))
        case .signal:
            d = poly(u, v * 0.85, 4, 0.56, tau / 8)
        case .uranglas:
            d = max(poly(u, v, 4, 0.66, 0), poly(u, v, 4, 0.85, tau / 8))
        case .kristall:
            d = poly(u, v - 0.25, 3, 0.5, tau / 4)
        case .roehre:
            let vv = v - clamp(v, -0.42, 0.42)
            d = (u * u + vv * vv).squareRoot() - 0.38
        case .niete:
            d = poly(u, v, 6, 0.76, 0)
        }
        var h = clamp(-d / 0.3, 0, 1)
        if gem == .niete { h -= 0.55 * clamp((0.32 - l) / 0.07, 0, 1) }
        return (d, h)
    }

    /// `petrified`: graue Steinversion für den Fresser.
    static func makeSprite(_ gem: Gem, size: Int = tile, petrified: Bool = false) -> Sprite {
        let style = petrified ? Look(hue: 30, sat: 6, light: 40) : look(gem)
        let steps = 5
        let ramp: [RGBA] = (0..<steps).map { i in
            let k = Double(i) / Double(steps - 1)
            return hsl(style.hue + (0.5 - k) * 24,
                       style.sat * (1 - 0.25 * k * k),
                       clamp(style.light * (0.36 + 0.95 * k) + (k > 0.9 ? 12 : 0), 0, 95))
        }
        var canvas = PixelCanvas(width: size, height: size)
        var inside = [Bool](repeating: false, count: size * size)
        let pad = 1.06
        let e = 2.0 / Double(size) * pad
        let light = normalize(-0.55, -0.7, 0.75)
        let half = normalize(light.0, light.1, light.2 + 1)

        for py in 0..<size {
            for px in 0..<size {
                let u = ((Double(px) + 0.5) / Double(size) * 2 - 1) * pad
                let v = ((Double(py) + 0.5) / Double(size) * 2 - 1) * pad
                guard field(gem, u, v).d < 0 else { continue }
                inside[py * size + px] = true
                let hx = (field(gem, u + e * 0.5, v).h - field(gem, u - e * 0.5, v).h) / e
                let hy = (field(gem, u, v + e * 0.5).h - field(gem, u, v - e * 0.5).h) / e
                let n = normalize(-hx * 0.32, -hy * 0.32, 1)
                let diffuse = max(0, dot(n, light))
                let spec = pow(max(0, dot(n, half)), 28)
                let emissive = gem == .roehre ? exp(-u * u / 0.008) * clamp((0.5 - abs(v)) / 0.1, 0, 1) * 0.9 : 0
                let q = 0.15 + 0.95 * diffuse - 0.12 * v + spec * 0.9 + emissive
                let idx = Int(clamp((q - 0.3) / 1.1, 0, 0.999) * Double(steps))
                canvas.set(px, py, ramp[idx])
            }
        }
        let outline = hsl(style.hue, style.sat * 0.7, 7)
        for py in 0..<size {
            for px in 0..<size where !inside[py * size + px] {
                let near = (px > 0 && inside[py * size + px - 1])
                    || (px < size - 1 && inside[py * size + px + 1])
                    || (py > 0 && inside[(py - 1) * size + px])
                    || (py < size - 1 && inside[(py + 1) * size + px])
                if near { canvas.set(px, py, outline) }
            }
        }
        return Sprite(texture: canvas.texture(), ramp: ramp)
    }

    private static func normalize(_ x: Double, _ y: Double, _ z: Double) -> (Double, Double, Double) {
        let l = (x * x + y * y + z * z).squareRoot()
        return (x / l, y / l, z / l)
    }

    private static func dot(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> Double {
        a.0 * b.0 + a.1 * b.1 + a.2 * b.2
    }
}
