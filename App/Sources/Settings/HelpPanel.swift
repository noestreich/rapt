import RaptCore
import SpriteKit

/// Zweites Fenster über den Einstellungen: welche Power-ups es gibt, wie oft sie kommen und was sie tun,
/// dazu die Spezialsteine. Gleicher Pixel-Stil wie die Einstellungen.
final class HelpPanel {
    struct Entry {
        let icon: SKNode
        let title: String
        /// Häufigkeit, z. B. "32%"; leer bei Spezialsteinen.
        let badge: String
        let lines: [String]
    }

    let node = SKNode()
    var onClose: () -> Void = {}
    private(set) var isVisible = false

    private static let amber = RGBA(hex: 0xFFB347)
    private static let cream = RGBA(hex: 0xFFF3D6)
    private static let gray = RGBA(hex: 0x9A9CAB)
    private static let dim = RGBA(hex: 0x4A4B56)

    private let designHeight: CGFloat
    private let x0 = 8, y0 = 10, width = 184, height = 300
    private var closeRect = CGRect.zero

    init(designHeight: CGFloat, powerUps: [Entry], specials: [Entry], footnote: String) {
        self.designHeight = designHeight
        node.isHidden = true
        build(powerUps: powerUps, specials: specials, footnote: footnote)
    }

    private func world(_ x: Int, _ y: Int) -> CGPoint {
        CGPoint(x: CGFloat(x), y: designHeight - CGFloat(y))
    }

    private func sprite(_ canvas: PixelCanvas, at x: Int, _ y: Int, scale: CGFloat = 1) -> SKSpriteNode {
        let s = SKSpriteNode(texture: canvas.texture(), size: CGSize(width: CGFloat(canvas.width) * scale, height: CGFloat(canvas.height) * scale))
        s.anchorPoint = CGPoint(x: 0, y: 1)
        s.position = world(x, y)
        return s
    }

    private func build(powerUps: [Entry], specials: [Entry], footnote: String) {
        var back = PixelCanvas(width: width, height: height, fill: RGBA(hex: 0x0B0A11, alpha: 248))
        for y in stride(from: 1, to: height, by: 2) { back.fillRect(1, y, width - 2, 1, RGBA(hex: 0x14121C, alpha: 248)) }
        for (x, y, w, h) in [(0, 0, width, 1), (0, height - 1, width, 1), (0, 0, 1, height), (width - 1, 0, 1, height)] {
            back.fillRect(x, y, w, h, Self.amber)
        }
        node.addChild(sprite(back, at: x0, y0))
        let title = PixelFont.render("HILFE", color: Self.amber, shadow: RGBA(hex: 0x050409))
        node.addChild(sprite(title, at: x0 + (width - title.width * 2) / 2, y0 + 6, scale: 2))

        var y = y0 + 22
        func section(_ text: String) {
            var c = PixelCanvas(width: width - 16, height: 7)
            PixelFont.draw(text, into: &c, x: 0, y: 1, color: Self.gray)
            c.fillRect(PixelFont.width(text) + 4, 3, width - 20 - PixelFont.width(text), 1, Self.dim)
            node.addChild(sprite(c, at: x0 + 8, y))
            y += 10
        }
        func entry(_ e: Entry) {
            // Symbol links, mittig in einem 22-px-Feld
            e.icon.position = world(x0 + 8 + 11, y + 10)
            node.addChild(e.icon)
            let textX = x0 + 8 + 26
            var head = PixelCanvas(width: width - 16 - 26, height: 5)
            PixelFont.draw(e.title, into: &head, x: 0, y: 0, color: Self.cream)
            if !e.badge.isEmpty {
                PixelFont.draw(e.badge, into: &head, x: head.width - PixelFont.width(e.badge), y: 0, color: Self.amber)
            }
            node.addChild(sprite(head, at: textX, y + 1))
            for (i, line) in e.lines.enumerated() {
                node.addChild(sprite(PixelFont.render(line, color: Self.gray), at: textX, y + 9 + i * 7))
            }
            y += max(24, 10 + e.lines.count * 7 + 4)
        }

        section("POWER-UPS IM DÄCHERLAUF")
        powerUps.forEach(entry)
        node.addChild(sprite(PixelFont.render(footnote, color: Self.dim), at: x0 + 8, y - 2))
        y += 8
        section("SPEZIALSTEINE IN BEIDEN MODI")
        specials.forEach(entry)

        // Knopf ZURÜCK unten
        let w = 120, h = 18
        let bx = x0 + (width - w) / 2, by = y0 + height - h - 6
        var button = PixelCanvas(width: w, height: h, fill: RGBA(hex: 0x1B1A24))
        for (x, yy, ww, hh) in [(0, 0, w, 1), (0, h - 1, w, 1), (0, 0, 1, h), (w - 1, 0, 1, h)] {
            button.fillRect(x, yy, ww, hh, Self.amber)
        }
        let label = PixelFont.render("ZURÜCK", color: Self.cream)
        for yy in 0..<label.height * 2 {
            for xx in 0..<label.width * 2 where label.get(xx / 2, yy / 2).a > 0 {
                button.set((w - label.width * 2) / 2 + xx, 4 + yy, Self.cream)
            }
        }
        node.addChild(sprite(button, at: bx, by))
        closeRect = CGRect(x: bx, y: by, width: w, height: h)
    }

    func show() {
        isVisible = true
        node.isHidden = false
        node.alpha = 0
        node.run(.fadeIn(withDuration: 0.12))
    }

    func hide() {
        isVisible = false
        node.run(.sequence([.fadeOut(withDuration: 0.1), .hide()]))
    }

    /// Design-Koordinaten. Jeder Tipp außerhalb des Fensters oder auf ZURÜCK schließt.
    func pointerDown(_ p: CGPoint) {
        let panel = CGRect(x: x0, y: y0, width: width, height: height)
        if closeRect.insetBy(dx: -4, dy: -4).contains(p) || !panel.contains(p) {
            onClose()
        }
    }
}
