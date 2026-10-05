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
