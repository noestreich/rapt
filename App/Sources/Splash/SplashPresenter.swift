import RaptCore
import SpriteKit

/// Kurze Funk-Einblendung über der Punkteplatte: ein Kontakt reicht dem Spieler einen Spezialstein
/// oder ein Power-up. Läuft ohne das Spiel anzuhalten, etwa 1,3 Sekunden.
final class SplashPresenter {
    /// Kontakt plus das Bild des übergebenen Gegenstands.
    struct Delivery {
        let contact: Contact
        let item: SKTexture
    }

    let node = SKNode()
    /// Mindestabstand zwischen freiwilligen Einblendungen (Linien- und Bomben-Steine).
    var cooldown: TimeInterval = 20

    private let origin: CGPoint
    private let width: CGFloat
    private let height: CGFloat
    private var portraits: [String: SKTexture] = [:]
    private var queue: [Delivery] = []
    private var isShowing = false
    private var lastShown: TimeInterval = -1000
    private var rng = SystemRandomNumberGenerator()
    var onSpeak: (Contact) -> Void = { _ in }

    /// `topLeft`: linke obere Ecke der Einblendung in Weltkoordinaten.
    init(topLeft: CGPoint, width: CGFloat, height: CGFloat) {
        origin = topLeft
        self.width = width
        self.height = height
        node.zPosition = 60
        for contact in Contact.all { portraits[contact.id] = PortraitArt.texture(for: contact) }
    }

    /// `force`: immer zeigen (Power-ups, Hyperstein), sonst nur nach Ablauf der Sperre.
    func present(_ delivery: Delivery, at time: TimeInterval, force: Bool) {
        guard GameSettings.shared.splashesEnabled else { return }
        guard force || time - lastShown > cooldown else { return }
        if isShowing {
            if force && queue.count < 2 { queue.append(delivery) }
            return
        }
        lastShown = time
        show(delivery, time: time)
    }

    private func show(_ delivery: Delivery, time: TimeInterval) {
        isShowing = true
        let panel = makePanel(delivery)
        panel.position = CGPoint(x: origin.x + width + 20, y: origin.y)
        node.addChild(panel)
        onSpeak(delivery.contact)

        let slideIn = SKAction.move(to: origin, duration: 0.14)
        slideIn.timingMode = .easeOut
        let slideOut = SKAction.move(to: CGPoint(x: origin.x - width - 20, y: origin.y), duration: 0.18)
        slideOut.timingMode = .easeIn
        let glitch = SKAction.sequence([
            .fadeAlpha(to: 0.4, duration: 0), .wait(forDuration: 0.04),
            .fadeAlpha(to: 1, duration: 0), .wait(forDuration: 0.03),
            .fadeAlpha(to: 0.6, duration: 0), .wait(forDuration: 0.03),
            .fadeAlpha(to: 1, duration: 0),
        ])
        panel.run(.sequence([
            .group([slideIn, glitch]),
            .wait(forDuration: 0.95),
            .group([slideOut, glitch]),
            .removeFromParent(),
            .run { [weak self] in self?.finished(at: time + 1.3) },
        ]))
    }

    private func finished(at time: TimeInterval) {
        isShowing = false
        if !queue.isEmpty {
            let next = queue.removeFirst()
            lastShown = time
            show(next, time: time)
        }
    }

    private func pixel(_ canvas: PixelCanvas, at p: CGPoint, scale: CGFloat = 1) -> SKSpriteNode {
        let sprite = SKSpriteNode(texture: canvas.texture(), size: CGSize(width: CGFloat(canvas.width) * scale, height: CGFloat(canvas.height) * scale))
        sprite.anchorPoint = CGPoint(x: 0, y: 1)
        sprite.position = p
        return sprite
    }

    private func makePanel(_ delivery: Delivery) -> SKNode {
        if let texture = portraits[delivery.contact.id], texture.size().width > CGFloat(PortraitArt.size) {
            return makeWidePanel(delivery, portrait: texture)
        }
        return makeSquarePanel(delivery)
    }

    /// Eigenes Porträt im Querformat: füllt die ganze Breite, Name und Funkspruch auf einem Band unten.
    /// Der Gegenstand ist schon im Bild, deshalb gibt es kein Overlay.
    private func makeWidePanel(_ delivery: Delivery, portrait texture: SKTexture) -> SKNode {
        let panel = SKNode()
        let w = Int(width)
        let h = Int((texture.size().height * width / texture.size().width).rounded())
        let accent = RGBA(hex: delivery.contact.accent)

        let image = SKSpriteNode(texture: texture, size: CGSize(width: w, height: h))
        image.anchorPoint = CGPoint(x: 0, y: 1)
        panel.addChild(image)

        // Scanlines, Rahmen und Band
        var overlay = PixelCanvas(width: w, height: h)
        for y in stride(from: 1, to: h, by: 2) { overlay.fillRect(0, y, w, 1, RGBA(hex: 0x000000, alpha: 46)) }
        let band = 27
        for y in (h - band)..<h {
            let a = y < h - band + 4 ? 120 + (y - (h - band)) * 25 : 215
            overlay.fillRect(0, y, w, 1, RGBA(hex: 0x0B0A11, alpha: UInt8(a)))
        }
        overlay.fillRect(0, 0, w, 1, accent)
        overlay.fillRect(0, h - 1, w, 1, accent)
        overlay.fillRect(0, 0, 1, h, accent)
        overlay.fillRect(w - 1, 0, 1, h, accent)
        let overlayNode = pixel(overlay, at: .zero)
        overlayNode.zPosition = 1
        panel.addChild(overlayNode)

        // Bildrauschen beim Einschalten des Funks
        var staticCanvas = PixelCanvas(width: w, height: h)
        for y in 0..<h {
            for x in 0..<w where Noise.hash(x, y, Int.random(in: 0...9999)) < 0.55 {
                let v = UInt8(Int.random(in: 60...230))
                staticCanvas.set(x, y, RGBA(r: v, g: v, b: v, a: 200))
            }
        }
        let noise = pixel(staticCanvas, at: .zero)
        noise.zPosition = 3
        noise.run(.sequence([.wait(forDuration: 0.08), .fadeOut(withDuration: 0.12), .removeFromParent()]))
        panel.addChild(noise)

        // Name und Funkspruch
        let name = pixel(PixelFont.render(delivery.contact.name, color: accent, shadow: RGBA(hex: 0x050409)), at: CGPoint(x: 5, y: -(h - band + 4)))
        name.zPosition = 2
        panel.addChild(name)
        addTypewriter(Contact.gibberish(using: &rng), to: panel, x: 5, y: CGFloat(-(h - band + 12)), lineHeight: 7)
        addSignalBars(to: panel, x: CGFloat(w - 16), y: -10, accent: accent)
        return panel
    }

    private func addTypewriter(_ lines: [String], to panel: SKNode, x: CGFloat, y: CGFloat, lineHeight: CGFloat) {
        for (i, line) in lines.enumerated() {
            let label = SKSpriteNode()
            label.anchorPoint = CGPoint(x: 0, y: 1)
            label.position = CGPoint(x: x, y: y - CGFloat(i) * lineHeight)
            label.zPosition = 2
            panel.addChild(label)
            var actions: [SKAction] = [.wait(forDuration: 0.08 + Double(i) * 0.25)]
            for n in stride(from: 1, through: line.count, by: 2) {
                let part = String(line.prefix(n))
                actions.append(.run {
                    let canvas = PixelFont.render(part, color: RGBA(hex: 0xFFF3D6), shadow: RGBA(hex: 0x050409))
                    label.texture = canvas.texture()
                    label.size = canvas.size
                })
                actions.append(.wait(forDuration: 0.03))
            }
            actions.append(.run {
                let canvas = PixelFont.render(line, color: RGBA(hex: 0xFFF3D6), shadow: RGBA(hex: 0x050409))
                label.texture = canvas.texture()
                label.size = canvas.size
            })
            label.run(.sequence(actions))
        }
    }

    private func addSignalBars(to panel: SKNode, x: CGFloat, y: CGFloat, accent: RGBA) {
        for i in 0..<4 {
            let bar = SKSpriteNode(color: accent.skColor, size: CGSize(width: 2, height: 2 + i * 2))
            bar.anchorPoint = CGPoint(x: 0, y: 0)
            bar.position = CGPoint(x: x + CGFloat(i * 3), y: y)
            bar.zPosition = 2
            bar.run(.repeatForever(.sequence([
                .fadeAlpha(to: 1, duration: 0), .wait(forDuration: Double.random(in: 0.05...0.15)),
                .fadeAlpha(to: 0.25, duration: 0), .wait(forDuration: Double.random(in: 0.05...0.12)),
            ])))
            panel.addChild(bar)
        }
    }

    /// Platzhalter-Porträt (48×48) links, Gegenstand als Overlay, Text rechts.
    private func makeSquarePanel(_ delivery: Delivery) -> SKNode {
        let panel = SKNode()
        let w = Int(width), h = Int(height)

        // Rahmen mit Scanlines
        var frame = PixelCanvas(width: w, height: h, fill: RGBA(hex: 0x0B0A11, alpha: 240))
        frame.fillRect(0, 0, w, 1, RGBA(hex: delivery.contact.accent))
        frame.fillRect(0, h - 1, w, 1, RGBA(hex: delivery.contact.accent))
        frame.fillRect(0, 0, 1, h, RGBA(hex: delivery.contact.accent))
        frame.fillRect(w - 1, 0, 1, h, RGBA(hex: delivery.contact.accent))
        for y in stride(from: 2, to: h - 1, by: 2) { frame.fillRect(1, y, w - 2, 1, RGBA(hex: 0x16141E, alpha: 240)) }
        panel.addChild(pixel(frame, at: .zero))

        // Porträt, darüber der übergebene Gegenstand „in der Hand“
        let portrait = SKSpriteNode(texture: portraits[delivery.contact.id], size: CGSize(width: PortraitArt.size, height: PortraitArt.size))
        portrait.anchorPoint = CGPoint(x: 0, y: 1)
        portrait.position = CGPoint(x: 6, y: -((CGFloat(h) - CGFloat(PortraitArt.size)) / 2).rounded())
        portrait.zPosition = 1
        panel.addChild(portrait)
        let item = SKSpriteNode(texture: delivery.item, size: delivery.item.size())
        item.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        item.position = CGPoint(x: portrait.position.x + 40, y: portrait.position.y - 38)
        item.zPosition = 2
        item.run(.sequence([.scale(to: 0.4, duration: 0), .scale(to: 1, duration: 0.18)]))
        panel.addChild(item)

        // Name, Funkspruch (Schreibmaschine), Signalbalken
        let textX: CGFloat = 6 + CGFloat(PortraitArt.size) + 6
        panel.addChild(pixel(PixelFont.render(delivery.contact.name, color: RGBA(hex: delivery.contact.accent)), at: CGPoint(x: textX, y: -7), scale: 1))
        let lines = Contact.gibberish(using: &rng)
        for (i, line) in lines.enumerated() {
            let label = SKSpriteNode()
            label.anchorPoint = CGPoint(x: 0, y: 1)
            label.position = CGPoint(x: textX, y: -18 - CGFloat(i) * 9)
            panel.addChild(label)
            let steps = line.count
            var actions: [SKAction] = [.wait(forDuration: 0.08 + Double(i) * 0.25)]
            for n in stride(from: 1, through: steps, by: 2) {
                let part = String(line.prefix(n))
                actions.append(.run {
                    let canvas = PixelFont.render(part, color: RGBA(hex: 0xFFF3D6))
                    label.texture = canvas.texture()
                    label.size = canvas.size
                })
                actions.append(.wait(forDuration: 0.03))
            }
            actions.append(.run {
                let canvas = PixelFont.render(line, color: RGBA(hex: 0xFFF3D6))
                label.texture = canvas.texture()
                label.size = canvas.size
            })
            label.run(.sequence(actions))
        }
        for i in 0..<4 {
            let bar = SKSpriteNode(color: RGBA(hex: delivery.contact.accent).skColor, size: CGSize(width: 2, height: 2 + i * 2))
            bar.anchorPoint = CGPoint(x: 0, y: 0)
            bar.position = CGPoint(x: CGFloat(w - 16 + i * 3), y: -12)
            bar.run(.repeatForever(.sequence([
                .fadeAlpha(to: 1, duration: 0), .wait(forDuration: Double.random(in: 0.05...0.15)),
                .fadeAlpha(to: 0.25, duration: 0), .wait(forDuration: Double.random(in: 0.05...0.12)),
            ])))
            panel.addChild(bar)
        }
        return panel
    }
}
