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
        /// Antippen spielt z. B. die Funk-Einblendung des zugehörigen Kontakts.
        var onTap: (() -> Void)?
    }

    /// Freier Textblock für Seite 2: Überschrift und Zeilen.
    struct Block {
        let title: String
        let lines: [String]
        var highlight = false
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
    private var pageRect = CGRect.zero
    private var tapTargets: [(page: Int, rect: CGRect, action: () -> Void)] = []
    private let pages = [SKNode(), SKNode(), SKNode()]
    private var page = 0
    private let pageLabel = SKSpriteNode()

    init(designHeight: CGFloat, powerUps: [Entry], specials: [Entry], footnote: String, info: [Block]) {
        self.designHeight = designHeight
        node.isHidden = true
        build(powerUps: powerUps, specials: specials, footnote: footnote, info: info)
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

    private func button(_ text: String, width w: Int) -> PixelCanvas {
        let h = 18
        var c = PixelCanvas(width: w, height: h, fill: RGBA(hex: 0x1B1A24))
        for (x, yy, ww, hh) in [(0, 0, w, 1), (0, h - 1, w, 1), (0, 0, 1, h), (w - 1, 0, 1, h)] {
            c.fillRect(x, yy, ww, hh, Self.amber)
        }
        let label = PixelFont.render(text, color: Self.cream)
        for yy in 0..<label.height * 2 {
            for xx in 0..<label.width * 2 where label.get(xx / 2, yy / 2).a > 0 {
                c.set((w - label.width * 2) / 2 + xx, 4 + yy, Self.cream)
            }
        }
        return c
    }

    private func build(powerUps: [Entry], specials: [Entry], footnote: String, info: [Block]) {
        var back = PixelCanvas(width: width, height: height, fill: RGBA(hex: 0x0B0A11, alpha: 248))
        for y in stride(from: 1, to: height, by: 2) { back.fillRect(1, y, width - 2, 1, RGBA(hex: 0x14121C, alpha: 248)) }
        for (x, y, w, h) in [(0, 0, width, 1), (0, height - 1, width, 1), (0, 0, 1, height), (width - 1, 0, 1, height)] {
            back.fillRect(x, y, w, h, Self.amber)
        }
        node.addChild(sprite(back, at: x0, y0))
        let title = PixelFont.render("HILFE", color: Self.amber, shadow: RGBA(hex: 0x050409))
        node.addChild(sprite(title, at: x0 + (width - title.width * 2) / 2, y0 + 6, scale: 2))

        pages.forEach { node.addChild($0) }
        var parent = pages[0]
        var pageIndex = 0
        var y = y0 + 22
        func section(_ text: String) {
            var c = PixelCanvas(width: width - 16, height: 7)
            PixelFont.draw(text, into: &c, x: 0, y: 1, color: Self.gray)
            c.fillRect(PixelFont.width(text) + 4, 3, width - 20 - PixelFont.width(text), 1, Self.dim)
            parent.addChild(sprite(c, at: x0 + 8, y))
            y += 10
        }
        func entry(_ e: Entry) {
            // Symbol links, mittig in einem 22-px-Feld
            e.icon.position = world(x0 + 8 + 11, y + 10)
            parent.addChild(e.icon)
            let textX = x0 + 8 + 26
            var head = PixelCanvas(width: width - 16 - 26, height: 5)
            PixelFont.draw(e.title, into: &head, x: 0, y: 0, color: Self.cream)
            if !e.badge.isEmpty {
                PixelFont.draw(e.badge, into: &head, x: head.width - PixelFont.width(e.badge), y: 0, color: Self.amber)
            }
            parent.addChild(sprite(head, at: textX, y + 1))
            for (i, line) in e.lines.enumerated() {
                parent.addChild(sprite(PixelFont.render(line, color: Self.gray), at: textX, y + 9 + i * 7))
            }
            let h = max(24, 10 + e.lines.count * 7 + 4)
            if let tap = e.onTap {
                tapTargets.append((pageIndex, CGRect(x: x0 + 4, y: y - 2, width: width - 8, height: h), tap))
            }
            y += h
        }

        // Seite 1: Power-ups (antippbar)
        section("POWER-UPS IM DÄCHERLAUF - ANTIPPEN!")
        powerUps.forEach(entry)
        if !footnote.isEmpty {
            parent.addChild(sprite(PixelFont.render(footnote, color: Self.dim), at: x0 + 8, y - 2))
        }

        // Seite 2: Spezialsteine (antippbar)
        parent = pages[1]
        pageIndex = 1
        y = y0 + 22
        section("SPEZIALSTEINE IN BEIDEN MODI - ANTIPPEN!")
        specials.forEach(entry)

        // Seite 3: Dächerlauf, Punkte, Macher
        parent = pages[2]
        pageIndex = 2
        y = y0 + 22
        for block in info {
            section(block.title)
            for line in block.lines {
                parent.addChild(sprite(PixelFont.render(line, color: block.highlight ? Self.cream : Self.gray), at: x0 + 8, y))
                y += 7
            }
            y += 6
        }

        // Knöpfe unten: Seite wechseln, Schließen
        let w = 82
        let by = y0 + height - 18 - 6
        let px = x0 + 8, cx = x0 + width - 8 - w
        pageLabel.anchorPoint = CGPoint(x: 0, y: 1)
        pageLabel.position = world(px, by)
        node.addChild(pageLabel)
        node.addChild(sprite(button("ZURÜCK", width: w), at: cx, by))
        pageRect = CGRect(x: px, y: by, width: w, height: 18)
        closeRect = CGRect(x: cx, y: by, width: w, height: 18)
        showPage(0)
    }

    private func showPage(_ index: Int) {
        page = index
        for (i, p) in pages.enumerated() { p.isHidden = i != index }
        let next = ["STEINE", "MEHR", "POWER-UPS"]
        let canvas = button(next[index], width: 82)
        pageLabel.texture = canvas.texture()
        pageLabel.size = canvas.size
    }

    func show() {
        showPage(0)
        isVisible = true
        node.isHidden = false
        node.alpha = 0
        node.run(.fadeIn(withDuration: 0.12))
    }

    func hide() {
        isVisible = false
        node.run(.sequence([.fadeOut(withDuration: 0.1), .hide()]))
    }

    /// Design-Koordinaten. Tipp außerhalb des Fensters oder auf ZURÜCK schließt.
    func pointerDown(_ p: CGPoint) {
        let panel = CGRect(x: x0, y: y0, width: width, height: height)
        if closeRect.insetBy(dx: -3, dy: -3).contains(p) || !panel.contains(p) {
            onClose()
        } else if pageRect.insetBy(dx: -3, dy: -3).contains(p) {
            showPage((page + 1) % pages.count)
        } else if let target = tapTargets.first(where: { $0.page == page && $0.rect.contains(p) }) {
            target.action()
        }
    }
}
