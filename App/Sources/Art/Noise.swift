import Foundation

func clamp<T: Comparable>(_ x: T, _ lo: T, _ hi: T) -> T {
    min(max(x, lo), hi)
}

func hsl(_ hue: Double, _ sat: Double, _ light: Double) -> RGBA {
    let h = (hue.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    let s = sat / 100
    let l = light / 100
    let a = s * min(l, 1 - l)
    func f(_ n: Double) -> Double {
        let k = (n + h / 30).truncatingRemainder(dividingBy: 12)
        return l - a * max(-1, min(k - 3, 9 - k, 1))
    }
    return RGBA(f(0) * 255, f(8) * 255, f(4) * 255)
}

/// Wertrauschen und Dithering für prozedurale Pixel-Art.
enum Noise {
    static func hash(_ x: Int, _ y: Int, _ s: Int) -> Double {
        var h = UInt32(truncatingIfNeeded: x) &* 374_761_393
            &+ UInt32(truncatingIfNeeded: y) &* 668_265_263
            &+ UInt32(truncatingIfNeeded: s) &* 982_451_653
        h = (h ^ (h >> 13)) &* 1_274_126_177
        h ^= h >> 16
        return Double(h) / 4_294_967_296.0
    }

    static func value(_ x: Double, _ y: Double, seed: Int) -> Double {
        let xi = Int(floor(x)), yi = Int(floor(y))
        let xf = x - Double(xi), yf = y - Double(yi)
        let u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf)
        let a = hash(xi, yi, seed), b = hash(xi + 1, yi, seed)
        let c = hash(xi, yi + 1, seed), d = hash(xi + 1, yi + 1, seed)
        return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v
    }

    static func fbm(_ x: Double, _ y: Double, seed: Int, octaves: Int) -> Double {
        var total = 0.0, amp = 0.5, freq = 1.0, norm = 0.0
        for i in 0..<octaves {
            total += amp * value(x * freq, y * freq, seed: seed + i * 17)
            norm += amp
            amp *= 0.5
            freq *= 2
        }
        return total / norm
    }

    private static let bayerMatrix: [Double] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5].map { ($0 + 0.5) / 16 }

    /// Geordnetes 4×4-Dithering, Wert in 0..<1.
    static func bayer(_ x: Int, _ y: Int) -> Double {
        bayerMatrix[(y & 3) * 4 + (x & 3)]
    }
}
