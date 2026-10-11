import SpriteKit

/// Seltene Ereignisse in der Stadt, rein zur Stimmung: ein Nachtzug fährt hinter der vorderen Häuserreihe durch
/// (sichtbar in den Lücken und über niedrigen Dächern), oder es regnet eine Weile mit Wetterleuchten.
/// Koordinaten wie in der Szene: Design-Pixel (y nach unten) über `design`.
final class CityEvents {
    /// Sichtbarer Bereich und Boden der Stadt in Design-Pixeln.
    struct Frame {
        var left: CGFloat
        var right: CGFloat
        var top: CGFloat
        var ground: CGFloat
    }

    private let layer: SKNode
    private let glowTexture: SKTexture
    private let design: (CGFloat, CGFloat) -> CGPoint
    private let sound: (SoundSlot, Float, Double) -> Void
    private var timer = Double.random(in: 45...90)
    private var rain: SKEmitterNode?
    private(set) var isRaining = false

    init(layer: SKNode, glowTexture: SKTexture, design: @escaping (CGFloat, CGFloat) -> CGPoint,
         sound: @escaping (SoundSlot, Float, Double) -> Void) {
        self.layer = layer
        self.glowTexture = glowTexture
        self.design = design
        self.sound = sound
    }

    /// Läuft nur, solange gespielt wird.
    func update(_ dt: Double, frame: Frame) {
        timer -= dt
        guard timer <= 0 else { return }
        timer = Double.random(in: 70...150)
        if !isRaining && Int.random(in: 0..<10) < 3 {
            startRain(frame: frame)
        } else {
            train(frame: frame)
        }
    }

    // MARK: Nachtzug

    private static func car(front: Bool) -> PixelCanvas {
        let w = 30, h = 8
        var c = PixelCanvas(width: w, height: h)
        let body = RGBA(hex: 0x2C2B3A), roof = RGBA(hex: 0x3E3D4E), stripe = RGBA(hex: 0xB8321F)
        let window = RGBA(hex: 0xFFD27A), dimWindow = RGBA(hex: 0x8A6A3A)
        c.fillRect(1, 1, w - 2, h - 2, body)
        c.fillRect(2, 0, w - 4, 1, roof)
        c.fillRect(1, h - 3, w - 2, 1, stripe)
        // Fensterband: einzelne Fenster, manche dunkler
        var x = 3
        var i = 0
        while x + 2 < w - 2 {
            c.fillRect(x, 2, 2, 2, i % 5 == 3 ? dimWindow : window)
            x += 4
            i += 1
        }
        if front {
            c.fillRect(0, 2, 1, 4, body)
            c.set(0, 4, RGBA(hex: 0xFFF3D6))
        }
        // Drehgestelle
        c.fillRect(4, h - 1, 4, 1, RGBA(hex: 0x14141A))
        c.fillRect(w - 8, h - 1, 4, 1, RGBA(hex: 0x14141A))
        return c
    }

    /// S-Bahn aus drei bis vier Wagen; fährt in zufälliger Richtung durchs Bild, leises Schienenklacken.
    func train(frame: Frame) {
        let cars = Int.random(in: 3...4)
        let length = CGFloat(cars * 31)
        let leftToRight = Bool.random()
        let node = SKNode()
        node.zPosition = 3.2
        for i in 0..<cars {
            let front = leftToRight ? i == cars - 1 : i == 0
            let canvas = Self.car(front: front)
            let sprite = SKSpriteNode(texture: canvas.texture(), size: canvas.size)
            sprite.anchorPoint = CGPoint(x: 0, y: 0)
            sprite.position = CGPoint(x: CGFloat(i * 31), y: 0)
            if leftToRight && front { sprite.xScale = -1; sprite.position.x += 30 }
            node.addChild(sprite)
        }
        // Scheinwerfer und Funken am Stromabnehmer
        let head = SKSpriteNode(texture: glowTexture, color: RGBA(hex: 0xFFE2B0).skColor, size: CGSize(width: 16, height: 10))
        head.colorBlendFactor = 1
        head.blendMode = .add
        head.alpha = 0.7
        head.position = CGPoint(x: leftToRight ? length + 2 : -2, y: 4)
        node.addChild(head)
        let spark = SKSpriteNode(texture: glowTexture, color: RGBA(hex: 0x7AF0FF).skColor, size: CGSize(width: 8, height: 8))
        spark.colorBlendFactor = 1
        spark.blendMode = .add
        spark.alpha = 0
        spark.position = CGPoint(x: length / 2, y: 9)
        node.addChild(spark)
        spark.run(.repeatForever(.sequence([
            .wait(forDuration: 0.4, withRange: 0.6),
            .fadeAlpha(to: 1, duration: 0), .wait(forDuration: 0.05), .fadeAlpha(to: 0.2, duration: 0.04),
            .fadeAlpha(to: 0.9, duration: 0), .wait(forDuration: 0.03), .fadeAlpha(to: 0, duration: 0.1),
        ])))

        // Hochbahn: Unterkante 34 Pixel über dem Boden, hinter den vorderen Häusern
        let y = design(0, frame.ground - 34).y
        let startX = leftToRight ? frame.left - length - 10 : frame.right + 10
        let endX = leftToRight ? frame.right + 10 : frame.left - length - 10
        node.position = CGPoint(x: startX, y: y)
        layer.addChild(node)
        let duration = Double(abs(endX - startX) / 85)
        node.run(.sequence([.moveTo(x: endX, duration: duration), .removeFromParent()]))
        // Schienenstöße: ta-tamm … ta-tamm
        let clack = SKAction.sequence([
            .run { [weak self] in self?.sound(.march, 0.1, -14) },
            .wait(forDuration: 0.09),
            .run { [weak self] in self?.sound(.march, 0.08, -16) },
            .wait(forDuration: 0.5),
        ])
        node.run(.repeat(clack, count: max(1, Int(duration / 0.59))))
    }

    // MARK: Regen

    private func rainTexture() -> SKTexture {
        var c = PixelCanvas(width: 1, height: 4)
        for y in 0..<4 { c.set(0, y, RGBA(hex: 0xA8B8D8, alpha: UInt8(90 + y * 40))) }
        return c.texture()
    }

    /// Regen für 20–35 Sekunden: schräge Striche vor den Häusern, ein- und ausgeblendet, dazu ein- bis zweimal
    /// Wetterleuchten mit fernem Donner.
    func startRain(frame: Frame) {
        guard !isRaining else { return }
        isRaining = true
        let width = frame.right - frame.left
        let height = frame.ground - frame.top
        let emitter = SKEmitterNode()
        emitter.particleTexture = rainTexture()
        emitter.particleSize = CGSize(width: 1, height: 4)
        emitter.particleBirthRate = 0
        emitter.particleLifetime = height / 200 + 0.3
        emitter.particleSpeed = 210
        emitter.particleSpeedRange = 30
        emitter.emissionAngle = -.pi / 2 - 0.22
        emitter.particleRotation = -0.22
        emitter.particleAlpha = 0.55
        emitter.particleAlphaRange = 0.25
        emitter.particlePositionRange = CGVector(dx: width + 60, dy: 0)
        emitter.position = design(frame.left + width / 2 + 20, frame.top - 4)
        emitter.zPosition = 4.5
        emitter.targetNode = layer
        layer.addChild(emitter)
        rain = emitter
        let peak = width * 0.9
        let duration = Double.random(in: 20...35)
        emitter.run(.sequence([
            .customAction(withDuration: 3) { node, t in (node as? SKEmitterNode)?.particleBirthRate = peak * t / 3 },
            .wait(forDuration: duration),
            .customAction(withDuration: 4) { node, t in (node as? SKEmitterNode)?.particleBirthRate = peak * (1 - t / 4) },
            .wait(forDuration: Double(emitter.particleLifetime)),
            .run { [weak self] in self?.stopRain() },
        ]))
        // Wetterleuchten
        let flashes = Int.random(in: 1...2)
        for _ in 0..<flashes {
            let at = Double.random(in: 5...(duration - 2))
            layer.run(.sequence([.wait(forDuration: at), .run { [weak self] in self?.lightning(frame: frame) }]))
        }
    }

    private func lightning(frame: Frame) {
        guard isRaining else { return }
        let width = frame.right - frame.left, height = frame.ground - frame.top
        let flash = SKSpriteNode(color: RGBA(hex: 0xC8D8FF).skColor, size: CGSize(width: width, height: height))
        flash.anchorPoint = CGPoint(x: 0, y: 1)
        flash.position = design(frame.left, frame.top)
        flash.zPosition = 1.5
        flash.blendMode = .add
        flash.alpha = 0
        layer.addChild(flash)
        flash.run(.sequence([
            .fadeAlpha(to: 0.22, duration: 0), .wait(forDuration: 0.06), .fadeAlpha(to: 0.05, duration: 0.05),
            .fadeAlpha(to: 0.3, duration: 0), .wait(forDuration: 0.08), .fadeOut(withDuration: 0.5), .removeFromParent(),
        ]))
        layer.run(.sequence([.wait(forDuration: Double.random(in: 0.6...1.4)), .run { [weak self] in
            self?.sound(.explosion, 0.18, -12)
        }]))
    }

    func stopRain() {
        rain?.removeAllActions()
        rain?.removeFromParent()
        rain = nil
        isRaining = false
    }

    /// Neues Spiel: laufende Ereignisse sofort beenden.
    func reset() {
        stopRain()
        timer = Double.random(in: 45...90)
    }
}
