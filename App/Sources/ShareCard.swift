import RaptCore
import SpriteKit
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Ergebniskarte zum Teilen nach Spielende: Pixelbild im Stil des Spiels (Logo, Punkte, Modus, Sprung,
/// Skyline mit Fernsehturm), sechsfach vergrößert, über das System-Teilen-Menü.
enum ShareCard {
    static let width = 160
    static let height = 100
    static let scale = 6

    struct Info {
        let score: Int
        /// „DÄCHERLAUF“, „ENDLOS“ oder „TAGESLAUF 2026-10-11“.
        let mode: String
        let plan: Int
        let isRecord: Bool
    }

    static func canvas(_ info: Info) -> PixelCanvas {
        var c = PixelCanvas(width: width, height: height, fill: RGBA(hex: 0x0B0A11))
        // Himmel mit leichtem Verlauf und ein paar Sternen
        for y in 0..<height {
            let k = Double(y) / Double(height)
            c.fillRect(0, y, width, 1, RGBA(11 + 14 * k, 10 + 6 * k, 17 + 22 * k))
        }
        for i in 0..<22 {
            let x = Int(Noise.hash(i, 3, 41) * Double(width)), y = 4 + Int(Noise.hash(i, 7, 43) * 46)
            let k = 0.35 + Noise.hash(i, 9, 47) * 0.65
            let bg = c.get(x, y)
            c.set(x, y, RGBA(Double(bg.r) + (232 - Double(bg.r)) * k, Double(bg.g) + (236 - Double(bg.g)) * k,
                             Double(bg.b) + (255 - Double(bg.b)) * k))
        }
        // Skyline unten
        let sky = Backdrop.skyline(width: width, seed: 5)
        c.draw(sky.canvas, at: 0, height - sky.canvas.height + 30)
        c.set(sky.beacon.x, height - sky.canvas.height + 30 + sky.beacon.y, RGBA(hex: 0xFF4030))
        // Warnstreifen oben
        for y in 0..<4 {
            for x in 0..<width {
                c.set(x, y, ((x + y) >> 2) & 1 == 1 ? RGBA(hex: 0xB8321F) : RGBA(hex: 0x1A1418))
            }
        }

        func big(_ text: String, color: RGBA, shade: RGBA, scale: Int, y: Int) {
            let glyphs = PixelFont.render(text, color: .white)
            let w = glyphs.width * scale
            let x0 = (width - w) / 2
            for yy in 0..<glyphs.height * scale {
                for xx in 0..<w where glyphs.get(xx / scale, yy / scale).a > 0 {
                    c.set(x0 + xx + 1, y + yy + 1, shade)
                }
            }
            for yy in 0..<glyphs.height * scale {
                for xx in 0..<w where glyphs.get(xx / scale, yy / scale).a > 0 {
                    c.set(x0 + xx, y + yy, yy < glyphs.height * scale / 2 ? color : shade.mixed(with: color))
                }
            }
        }
        func small(_ text: String, color: RGBA, y: Int) {
            let t = PixelFont.render(text, color: color, shadow: RGBA(hex: 0x050409))
            c.draw(t, at: (width - t.width) / 2, y)
        }

        big("RAPT", color: RGBA(hex: 0xFF6A3D), shade: RGBA(hex: 0x3A0E08), scale: 3, y: 9)
        big(String(info.score), color: RGBA(hex: 0xFFB347), shade: RGBA(hex: 0x4A2A0A), scale: 2, y: 32)
        small(tr("PUNKTE", "POINTS"), color: RGBA(hex: 0x9A9CAB), y: 45)
        small("\(info.mode) - " + tr("SPRUNG", "JUMP") + " \(info.plan)", color: RGBA(hex: 0xFFF3D6), y: 54)
        if info.isRecord { small(tr("NEUER REKORD!", "NEW RECORD!"), color: RGBA(hex: 0xFF4FA8), y: 62) }
        // Steine als kleine Reihe
        let gems: [Gem] = [.orden, .kristall, .uranglas, .roehre, .signal]
        let size = 9
        let start = (width - gems.count * (size + 2)) / 2
        for (i, gem) in gems.enumerated() {
            let art = GemArt.makeCanvas(gem, size: size, look: GemArt.look(gem)).canvas
            c.draw(art, at: start + i * (size + 2), info.isRecord ? 71 : 65)
        }
        return c
    }

    /// Vergrößert ohne Glättung, damit die Pixel scharf bleiben.
    static func image(_ info: Info) -> CGImage? {
        let small = canvas(info)
        var large = PixelCanvas(width: width * scale, height: height * scale)
        for y in 0..<large.height {
            for x in 0..<large.width { large.set(x, y, small.get(x / scale, y / scale)) }
        }
        return large.makeCGImage()
    }

    static func text(_ info: Info) -> String {
        tr("\(info.score) Punkte in RAPT (\(info.mode.capitalized), Sprung \(info.plan))",
           "\(info.score) points in RAPT (\(info.mode.capitalized), jump \(info.plan))")
    }

    /// Teilen-Menü über der Szene.
    static func present(_ info: Info, from view: SKView?) {
        guard let view, let cg = image(info) else { return }
        #if os(iOS)
        let picture = UIImage(cgImage: cg)
        let sheet = UIActivityViewController(activityItems: [picture, text(info)], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        var top = view.window?.rootViewController
        while let next = top?.presentedViewController { top = next }
        top?.present(sheet, animated: true)
        #else
        let picture = NSImage(cgImage: cg, size: NSSize(width: cg.width / 2, height: cg.height / 2))
        let picker = NSSharingServicePicker(items: [picture, text(info)])
        picker.show(relativeTo: CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1), of: view, preferredEdge: .minY)
        #endif
    }
}

private extension RGBA {
    func mixed(with other: RGBA) -> RGBA {
        RGBA((Double(r) + Double(other.r)) / 2, (Double(g) + Double(other.g)) / 2, (Double(b) + Double(other.b)) / 2)
    }
}
