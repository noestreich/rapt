import Foundation
import RaptCore
import SpriteKit

/// Wer sich schon einmal per Funk gemeldet hat (UserDefaults, über alle Spiele hinweg).
enum ContactAlbum {
    private static let key = "rapt.album.seen"

    static var seen: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    /// Merkt sich den Kontakt; `true`, wenn er neu im Album ist.
    @discardableResult
    static func markSeen(_ contact: Contact) -> Bool {
        var ids = seen
        guard !ids.contains(contact.id) else { return false }
        ids.insert(contact.id)
        UserDefaults.standard.set(Array(ids).sorted(), forKey: key)
        return true
    }

    /// Alle Funker, die im Spiel tatsächlich auftauchen können: Porträts aus `portraits.json` je Teil,
    /// ohne Zuordnung der zuständige Kontakt. Reihenfolge wie in den Teilen, ohne Doppelte.
    static let everyone: [Contact] = {
        var keys: [(String, Contact)] = PowerUp.allCases.map { ($0.rawValue, Contact.contact(for: $0)) }
        for special in [Special.line(horizontal: true), .bomb, .hyper] {
            keys.append((Contact.itemKey(special), Contact.contact(for: special)))
        }
        keys.append(("sternenbahn", .zora))
        var out: [Contact] = []
        for (key, fallback) in keys {
            for contact in Contact.everyone(holding: key, fallback: fallback) where !out.contains(where: { $0.id == contact.id }) {
                out.append(contact)
            }
        }
        return out
    }()
}

/// Funker-Album: alle Porträts im Raster, noch nicht getroffene nur als Rauschen mit „KEIN SIGNAL“.
/// Antippen eines bekannten Funkers spielt seinen Funkspruch. Gleicher Pixel-Stil wie die Hilfe.
final class AlbumPanel {
    let node = SKNode()
    var onClose: () -> Void = {}
    /// Funkspruch des angetippten Kontakts abspielen.
    var onPlay: (Contact) -> Void = { _ in }
    private(set) var isVisible = false

    private static let amber = RGBA(hex: 0xFFB347)
    private static let cream = RGBA(hex: 0xFFF3D6)
    private static let gray = RGBA(hex: 0x9A9CAB)
    private static let dim = RGBA(hex: 0x4A4B56)

    private let designHeight: CGFloat
    private let x0 = 8, y0 = 10, width = 184, height = 300
    private let columns = 3, rowsPerPage = 5
    private let cellWidth = 56, imageHeight = 37, pitch = 48
    private var closeRect = CGRect.zero
    private var pageRect = CGRect.zero
    private var cells: [(page: Int, rect: CGRect, contact: Contact)] = []
    private var pages: [SKNode] = []
    private var page = 0
    private let pageLabel = SKSpriteNode()
    private let countLabel = SKSpriteNode()
    private let content = SKNode()
    private var portraits: [String: SKTexture] = [:]

    init(designHeight: CGFloat) {
        self.designHeight = designHeight
        node.isHidden = true
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

    /// Rahmen, Titel und Knöpfe einmal; das Raster bei jedem Öffnen neu (neue Funker).
    private func buildFrame() {
        var back = PixelCanvas(width: width, height: height, fill: RGBA(hex: 0x0B0A11, alpha: 248))
        for y in stride(from: 1, to: height, by: 2) { back.fillRect(1, y, width - 2, 1, RGBA(hex: 0x14121C, alpha: 248)) }
        for (x, y, w, h) in [(0, 0, width, 1), (0, height - 1, width, 1), (0, 0, 1, height), (width - 1, 0, 1, height)] {
            back.fillRect(x, y, w, h, Self.amber)
        }
        node.addChild(sprite(back, at: x0, y0))
        let title = PixelFont.render("FUNKER-ALBUM", color: Self.amber, shadow: RGBA(hex: 0x050409))
        node.addChild(sprite(title, at: x0 + (width - title.width * 2) / 2, y0 + 6, scale: 2))
        countLabel.anchorPoint = CGPoint(x: 0, y: 1)
        node.addChild(countLabel)
        node.addChild(content)

        let w = 82
        let by = y0 + height - 18 - 6
        let px = x0 + 8, cx = x0 + width - 8 - w
        pageLabel.anchorPoint = CGPoint(x: 0, y: 1)
        pageLabel.position = world(px, by)
        node.addChild(pageLabel)
        node.addChild(sprite(button("ZURÜCK", width: w), at: cx, by))
        pageRect = CGRect(x: px, y: by, width: w, height: 18)
        closeRect = CGRect(x: cx, y: by, width: w, height: 18)
    }

    private func thumbnail(_ contact: Contact) -> SKTexture {
        if let t = portraits[contact.id] { return t }
        let t = PortraitArt.texture(for: contact)
        t.filteringMode = .linear
        portraits[contact.id] = t
        return t
    }

    /// Rauschen für unbekannte Funker.
    private func noise(seed: Int) -> PixelCanvas {
        var c = PixelCanvas(width: cellWidth, height: imageHeight, fill: RGBA(hex: 0x111018))
        for y in 0..<imageHeight {
            for x in 0..<cellWidth where Noise.hash(x, y, seed) < 0.35 {
                let v = UInt8(30 + Int(Noise.hash(x, y, seed + 1) * 60))
                c.set(x, y, RGBA(r: v, g: v, b: v + 8, a: 255))
            }
        }
        for (i, word) in ["KEIN", "SIGNAL"].enumerated() {
            PixelFont.draw(word, into: &c, x: (cellWidth - PixelFont.width(word)) / 2, y: 11 + i * 8, color: Self.dim)
        }
        return c
    }

    private func buildGrid() {
        content.removeAllChildren()
        cells = []
        pages = []
        let seen = ContactAlbum.seen
        let all = ContactAlbum.everyone
        let met = all.filter { seen.contains($0.id) }.count
        let count = PixelFont.render("\(met) VON \(all.count) GETROFFEN - ANTIPPEN!", color: Self.gray)
        countLabel.texture = count.texture()
        countLabel.size = count.size
        countLabel.position = world(x0 + (width - count.width) / 2, y0 + 22)

        let perPage = columns * rowsPerPage
        let pageCount = max(1, (all.count + perPage - 1) / perPage)
        for _ in 0..<pageCount {
            let p = SKNode()
            content.addChild(p)
            pages.append(p)
        }
        let gap = (width - 8 - columns * cellWidth) / (columns - 1)
        for (i, contact) in all.enumerated() {
            let pageIndex = i / perPage
            let slot = i % perPage
            let x = x0 + 4 + (slot % columns) * (cellWidth + gap)
            let y = y0 + 32 + (slot / columns) * pitch
            let parent = pages[pageIndex]
            let known = seen.contains(contact.id)
            if known {
                // Seitenverhältnis halten: breite Porträts füllen das Feld, quadratische stehen mittig
                let texture = thumbnail(contact)
                let ratio = texture.size().width / max(1, texture.size().height)
                let h = CGFloat(imageHeight)
                let w = min(CGFloat(cellWidth), h * ratio)
                let image = SKSpriteNode(texture: texture, size: CGSize(width: w, height: w / ratio))
                image.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                let mid = world(x + cellWidth / 2, y + imageHeight / 2)
                image.position = mid
                parent.addChild(image)
            } else {
                parent.addChild(sprite(noise(seed: 101 + i * 7), at: x, y))
            }
            // Rahmen in der Farbe des Funkers
            var frame = PixelCanvas(width: cellWidth, height: imageHeight)
            let color = known ? RGBA(hex: contact.accent) : Self.dim
            for (fx, fy, fw, fh) in [(0, 0, cellWidth, 1), (0, imageHeight - 1, cellWidth, 1), (0, 0, 1, imageHeight), (cellWidth - 1, 0, 1, imageHeight)] {
                frame.fillRect(fx, fy, fw, fh, color)
            }
            parent.addChild(sprite(frame, at: x, y))
            let name = known ? contact.name : "- - -"
            let label = PixelFont.render(name, color: known ? Self.cream : Self.dim)
            parent.addChild(sprite(label, at: x + (cellWidth - label.width) / 2, y + imageHeight + 2))
            if known {
                cells.append((pageIndex, CGRect(x: x, y: y, width: cellWidth, height: imageHeight + 9), contact))
            }
        }
    }

    private func showPage(_ index: Int) {
        page = min(index, pages.count - 1)
        for (i, p) in pages.enumerated() { p.isHidden = i != page }
        let canvas = button("SEITE \(page + 1)/\(pages.count)", width: 82)
        pageLabel.texture = canvas.texture()
        pageLabel.size = canvas.size
    }

    func show() {
        if node.children.isEmpty { buildFrame() }
        buildGrid()
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
            showPage((page + 1) % max(1, pages.count))
        } else if let cell = cells.first(where: { $0.page == page && $0.rect.contains(p) }) {
            onPlay(cell.contact)
        }
    }
}
