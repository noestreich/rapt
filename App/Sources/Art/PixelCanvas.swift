import CoreGraphics
import Foundation
import SpriteKit

/// Farbe mit 8 Bit pro Kanal, nicht vormultipliziert.
struct RGBA: Hashable {
    var r: UInt8
    var g: UInt8
    var b: UInt8
    var a: UInt8

    init(r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 255) {
        func c(_ v: Double) -> UInt8 { UInt8(max(0, min(255, v.rounded()))) }
        self.init(r: c(r), g: c(g), b: c(b), a: c(a))
    }

    init(hex: UInt32, alpha: UInt8 = 255) {
        self.init(r: UInt8((hex >> 16) & 0xFF), g: UInt8((hex >> 8) & 0xFF), b: UInt8(hex & 0xFF), a: alpha)
    }

    static let clear = RGBA(r: 0, g: 0, b: 0, a: 0)
    static let white = RGBA(hex: 0xFFFFFF)

    var skColor: SKColor {
        SKColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}

/// Pixelpuffer, Ursprung oben links. Daraus werden Texturen mit hartem Pixelraster.
struct PixelCanvas {
    let width: Int
    let height: Int
    private(set) var data: [UInt8]

    init(width: Int, height: Int, fill: RGBA = .clear) {
        self.width = max(1, width)
        self.height = max(1, height)
        data = [UInt8](repeating: 0, count: self.width * self.height * 4)
        if fill != .clear { fillRect(0, 0, self.width, self.height, fill) }
    }

    func get(_ x: Int, _ y: Int) -> RGBA {
        guard x >= 0, y >= 0, x < width, y < height else { return .clear }
        let i = (y * width + x) * 4
        return RGBA(r: data[i], g: data[i + 1], b: data[i + 2], a: data[i + 3])
    }

    mutating func set(_ x: Int, _ y: Int, _ c: RGBA) {
        guard x >= 0, y >= 0, x < width, y < height else { return }
        let i = (y * width + x) * 4
        data[i] = c.r
        data[i + 1] = c.g
        data[i + 2] = c.b
        data[i + 3] = c.a
    }

    mutating func fillRect(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: RGBA) {
        for yy in max(0, y)..<max(max(0, y), min(height, y + h)) {
            for xx in max(0, x)..<max(max(0, x), min(width, x + w)) {
                set(xx, yy, c)
            }
        }
    }

    /// Kopiert `other` deckend an (x, y); vollständig transparente Pixel bleiben aus.
    mutating func draw(_ other: PixelCanvas, at x: Int, _ y: Int) {
        for yy in 0..<other.height {
            for xx in 0..<other.width {
                let c = other.get(xx, yy)
                if c.a > 0 { set(x + xx, y + yy, c) }
            }
        }
    }

    func makeCGImage() -> CGImage? {
        var pre = data
        for i in stride(from: 0, to: pre.count, by: 4) {
            let a = UInt16(pre[i + 3])
            if a < 255 {
                pre[i] = UInt8(UInt16(pre[i]) * a / 255)
                pre[i + 1] = UInt8(UInt16(pre[i + 1]) * a / 255)
                pre[i + 2] = UInt8(UInt16(pre[i + 2]) * a / 255)
            }
        }
        guard let provider = CGDataProvider(data: Data(pre) as CFData),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGImage(
            width: width, height: height,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: space,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }

    /// Pixel-Art bekommt `.nearest`, weiches Licht `.linear`.
    func texture(smooth: Bool = false) -> SKTexture {
        let texture = makeCGImage().map { SKTexture(cgImage: $0) } ?? SKTexture()
        texture.filteringMode = smooth ? .linear : .nearest
        return texture
    }

    var size: CGSize { CGSize(width: width, height: height) }
}
