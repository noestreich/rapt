import SpriteKit

/// Experiment: Plasma-Feuer am linken Bildschirmrand hinter den Häusern. Es zeigt, wovor die Figur davonläuft.
/// Rückgängig machen: `enabled` auf `false` setzen (oder diese Datei und die mit „FireWall“ markierten Zeilen in GameScene löschen).
/// Spieler können es zusätzlich in den Einstellungen („FEUER“) abschalten.
final class FireWall {
    static let enabled = true

    /// Breite und Höhe der Flammen in Design-Pixeln.
    static let width = 18
    static let height = 120

    let node = SKNode()
    private let flames = SKSpriteNode()
    private let light: SKSpriteNode
    private let smokeFrames: [SKTexture]
    private var smokeTimer: TimeInterval = 1.5
    /// Faktor, um den die Flammen beim Kontakt hochlodern (bis zur Bildschirmmitte), aus `layout`.
    private var flareScale: CGFloat = 2.5
    private var contact = false

    init(glowTexture: SKTexture) {
        let frames = Self.flameFrames()
        flames.texture = frames.first
        flames.size = CGSize(width: Self.width, height: Self.height)
        flames.anchorPoint = CGPoint(x: 0, y: 0)
        flames.run(.repeatForever(.animate(with: frames, timePerFrame: 0.08)))
        node.addChild(flames)

        light = SKSpriteNode(texture: glowTexture, color: RGBA(hex: 0xC04FFF).skColor, size: CGSize(width: 46, height: CGFloat(Self.height) * 1.3))
        light.colorBlendFactor = 1
        light.blendMode = .add
        light.alpha = 0.22
        light.position = CGPoint(x: 2, y: CGFloat(Self.height) * 0.38)
        light.zPosition = 1
        light.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.3, duration: 0.25), .fadeAlpha(to: 0.18, duration: 0.35),
            .fadeAlpha(to: 0.26, duration: 0.2), .fadeAlpha(to: 0.2, duration: 0.3),
        ])))
        node.addChild(light)

        smokeFrames = Backdrop.steamFrames(seed: 41)
    }

    /// `left`: linker Bildschirmrand, `bottom`: unterer Bildschirmrand, beides in Weltkoordinaten.
    /// `left`/`bottom`: linker und unterer Bildschirmrand, `middle`: Bildschirmmitte (Höhe), alles in Weltkoordinaten.
    func layout(left: CGFloat, bottom: CGFloat, middle: CGFloat) {
        node.position = CGPoint(x: left, y: bottom)
        flareScale = max(1.2, (middle - bottom) / CGFloat(Self.height))
    }

    /// `danger` 0…1: je näher die Figur, desto breiter lodert es.
    /// `touching`: die Figur steht im Feuer, dann züngelt es bis zur Bildschirmmitte.
    func update(_ dt: TimeInterval, danger: Float, touching: Bool) {
        if touching && !contact { burst() }
        contact = touching
        let width = touching ? 2.2 : 1 + CGFloat(danger) * 0.7
        let height = touching ? flareScale : 1
        let speed = CGFloat(min(1, dt * (touching ? 6 : 2)))
        flames.xScale += (width - flames.xScale) * speed
        flames.yScale += (height - flames.yScale) * speed
        light.yScale = flames.yScale
        light.xScale = flames.xScale
        smokeTimer -= dt
        if smokeTimer <= 0 {
            smokeTimer = touching ? Double.random(in: 0.15...0.35) : Double.random(in: 1.2...3)
            puff(big: touching)
            if Double.random(in: 0...1) < 0.35 { puff(big: touching) }
        }
    }

    /// Kurzer, kräftiger Ausbruch (beim ersten Kontakt und beim Absturz).
    func burst() {
        flames.yScale = flareScale
        flames.xScale = 2.4
        for _ in 0..<6 { puff(big: true) }
    }

    /// Rauchwolke, die nach oben rechts abzieht.
    private func puff(big: Bool) {
        let size: CGFloat = big ? CGFloat.random(in: 34...46) : CGFloat.random(in: 26...34)
        let smoke = SKSpriteNode(texture: smokeFrames.first, size: CGSize(width: size, height: size))
        smoke.color = RGBA(hex: 0x3A2A4A).skColor
        smoke.colorBlendFactor = 0.65
        smoke.alpha = big ? 0.65 : 0.5
        smoke.xScale = Bool.random() ? 1 : -1
        let top = CGFloat(Self.height) * flames.yScale
        smoke.position = CGPoint(x: CGFloat.random(in: 4...14) * flames.xScale, y: top * CGFloat.random(in: 0.5...0.9))
        smoke.zPosition = 2
        node.addChild(smoke)
        let rise: CGFloat = big ? 70 : 48
        smoke.run(.sequence([
            .group([
                .animate(with: smokeFrames, timePerFrame: 0.25),
                .moveBy(x: CGFloat.random(in: 10...22), y: rise, duration: 2.5),
                .scale(by: 1.4, duration: 2.5),
                .sequence([.wait(forDuration: 1.3), .fadeOut(withDuration: 1.2)]),
            ]),
            .removeFromParent(),
        ]))
    }

    /// Plasma-Flammen: am Rand heiß (weiß/cyan), nach außen blau und magenta, oben ausfransend.
    private static func flameFrames(count: Int = 8) -> [SKTexture] {
        let palette: [RGBA] = [0x5A1F6A, 0xFF4FA8, 0x3A6BFF, 0x3FD8FF, 0xE8FBFF].map { RGBA(hex: $0) }
        return (0..<count).map { f in
            var c = PixelCanvas(width: width, height: height)
            for y in 0..<height {
                let rise = Double(height - 1 - y) / Double(height)   // 0 unten, 1 oben
                for x in 0..<width {
                    let edge = pow(1 - Double(x) / Double(width), 1.1)
                    let n = Noise.fbm(Double(x) / 4, (Double(y) + Double(f) * 7) / 12, seed: 77, octaves: 3)
                    // aufsteigende Flammenzungen
                    let tongue = pow(max(0, sin((Double(y) + Double(f) * 7) * 0.22 + Double(x) * 0.15)), 3) * (1 - Double(x) / Double(width)) * 0.45
                    let heat = edge * (1.1 - rise) + (n - 0.5) * 0.8 + tongue + (Noise.bayer(x, y) - 0.5) * 0.1
                    let level: Int
                    if heat > 0.95 { level = 4 } else if heat > 0.78 { level = 3 } else if heat > 0.6 { level = 2 } else if heat > 0.45 { level = 1 } else if heat > 0.36 { level = 0 } else { continue }
                    c.set(x, y, palette[level])
                }
            }
            return c.texture()
        }
    }
}
