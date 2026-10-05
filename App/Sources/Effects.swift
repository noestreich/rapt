import SpriteKit

/// Alle kurzlebigen Effekte. Pixel-Effekte liegen in `pixelLayer` (hartes Raster),
/// Licht in `lightLayer` (additiv, weich in voller Bildschirmauflösung).
final class Effects {
    let pixelLayer = SKNode()
    let lightLayer = SKNode()
    /// Untere Brettkante in Weltkoordinaten; dort prallen Splitter ab.
    var floorY: CGFloat = 0

    private let glowTexture = Backdrop.glow()
    private let ringTexture = Backdrop.ring()
    private let beamTexture = Backdrop.beam()
    private let explosionSets = [Backdrop.explosionFrames(seed: 3), Backdrop.explosionFrames(seed: 11), Backdrop.explosionFrames(seed: 29)]
    private let steamSets = [Backdrop.steamFrames(seed: 5), Backdrop.steamFrames(seed: 9)]
    private var particles: [Particle] = []

    private struct Particle {
        let node: SKSpriteNode
        let glow: SKSpriteNode?
        var x, y, vx, vy, spin: CGFloat
        var life: CGFloat
        let maxLife: CGFloat
        let gravity: CGFloat
        var bounced = false
    }

    init() {
        lightLayer.zPosition = 1
    }

    private static func snap(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x.rounded(), y: p.y.rounded())
    }

    @discardableResult
    func glow(at p: CGPoint, color: SKColor, size: CGFloat, alpha: CGFloat) -> SKSpriteNode {
        let node = SKSpriteNode(texture: glowTexture, color: color, size: CGSize(width: size, height: size))
        node.colorBlendFactor = 1
        node.blendMode = .add
        node.alpha = alpha
        node.position = p
        lightLayer.addChild(node)
        return node
    }

    /// Kurzes Aufblitzen in Steinfarbe.
    func flash(at p: CGPoint, color: SKColor) {
        let node = glow(at: p, color: color, size: 30, alpha: 1)
        node.run(.sequence([
            .group([.scale(to: 3.2, duration: 0.35), .fadeOut(withDuration: 0.35)]),
            .removeFromParent(),
        ]))
    }

    /// Pixel-Explosion mit heißem Kern.
    func explosion(at p: CGPoint, scale: CGFloat = 1) {
        let frames = explosionSets.randomElement()!
        let node = SKSpriteNode(texture: frames[0], size: CGSize(width: 44 * scale, height: 44 * scale))
        node.position = Self.snap(p)
        node.zRotation = CGFloat(Int.random(in: 0...3)) * .pi / 2
        pixelLayer.addChild(node)
        node.run(.sequence([.animate(with: frames, timePerFrame: 0.045), .removeFromParent()]))

        let core = glow(at: p, color: SKColor(red: 1, green: 0.62, blue: 0.25, alpha: 1), size: 40 * scale, alpha: 0.9)
        core.run(.sequence([.group([.scale(to: 2.2, duration: 0.4), .fadeOut(withDuration: 0.4)]), .removeFromParent()]))
        embers(at: p, count: Int(8 * scale))
    }

    /// Dampfwolke, die aufsteigt und zerfällt.
    func steam(at p: CGPoint) {
        let frames = steamSets.randomElement()!
        let node = SKSpriteNode(texture: frames[0], size: CGSize(width: 26, height: 26))
        node.position = Self.snap(p)
        node.alpha = 0.9
        node.xScale = Bool.random() ? 1 : -1
        pixelLayer.addChild(node)
        node.run(.sequence([
            .group([
                .animate(with: frames, timePerFrame: 0.07),
                .moveBy(x: CGFloat.random(in: -5...5), y: 18, duration: 0.7),
            ]),
            .removeFromParent(),
        ]))
    }

    /// Schrapnell-Konfetti in den Farben des Steins: kleine, rotierende Splitter, die am Brettboden abprallen.
    func shrapnel(at p: CGPoint, colors: [SKColor], count: Int, power: CGFloat = 1) {
        let shapes: [CGSize] = [CGSize(width: 1, height: 1), CGSize(width: 2, height: 1), CGSize(width: 2, height: 2), CGSize(width: 3, height: 1)]
        for i in 0..<count {
            let color = colors.randomElement() ?? .white
            let node = SKSpriteNode(color: color, size: shapes.randomElement()!)
            pixelLayer.addChild(node)
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 40...140) * power
            let light = i % 4 == 0 ? glow(at: p, color: color, size: 9, alpha: 0.7) : nil
            let life = CGFloat.random(in: 0.5...1.1)
            particles.append(Particle(node: node, glow: light, x: p.x, y: p.y,
                                      vx: cos(angle) * speed, vy: sin(angle) * speed + 45,
                                      spin: CGFloat.random(in: -18...18), life: life, maxLife: life, gravity: 230))
        }
    }

    /// Glühende Explosionspixel, die langsam aufsteigen und verlöschen.
    func embers(at p: CGPoint, count: Int) {
        let colors = [SKColor(red: 1, green: 0.95, blue: 0.7, alpha: 1), SKColor(red: 1, green: 0.63, blue: 0.16, alpha: 1), SKColor(red: 0.81, green: 0.29, blue: 0.1, alpha: 1)]
        for _ in 0..<count {
            let color = colors.randomElement()!
            let node = SKSpriteNode(color: color, size: CGSize(width: 1, height: 1))
            pixelLayer.addChild(node)
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 15...60)
            let life = CGFloat.random(in: 0.6...1.3)
            particles.append(Particle(node: node, glow: glow(at: p, color: color, size: 7, alpha: 0.8), x: p.x, y: p.y,
                                      vx: cos(angle) * speed, vy: sin(angle) * speed + 20,
                                      spin: 0, life: life, maxLife: life, gravity: -25))
        }
    }

    /// Lichtstrahl quer über das Brett (bei Reihen ab vier Steinen).
    func beam(horizontal: Bool, center: CGPoint, length: CGFloat, color: SKColor) {
        let light = SKSpriteNode(texture: beamTexture, color: color, size: CGSize(width: length, height: 22))
        light.colorBlendFactor = 1
        light.blendMode = .add
        light.position = center
        if !horizontal { light.zRotation = .pi / 2 }
        lightLayer.addChild(light)
        light.run(.sequence([.group([.scaleY(to: 0.2, duration: 0.4), .fadeOut(withDuration: 0.4)]), .removeFromParent()]))

        let core = SKSpriteNode(color: .white, size: horizontal ? CGSize(width: length, height: 2) : CGSize(width: 2, height: length))
        core.position = Self.snap(center)
        pixelLayer.addChild(core)
        core.run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()]))
    }

    /// Warp-Ring: zwei leicht versetzte Ringe (rot/cyan) für einen Farbsaum.
    func warpRing(at p: CGPoint, color: SKColor, radius: CGFloat) {
        let tints: [(SKColor, CGFloat)] = [(color, 0), (SKColor(red: 1, green: 0.2, blue: 0.3, alpha: 1), 1.5), (SKColor(red: 0.2, green: 0.85, blue: 1, alpha: 1), -1.5)]
        for (tint, offset) in tints {
            let ring = SKSpriteNode(texture: ringTexture, color: tint, size: CGSize(width: 8, height: 8))
            ring.colorBlendFactor = 1
            ring.blendMode = .add
            ring.alpha = offset == 0 ? 1 : 0.6
            ring.position = CGPoint(x: p.x + offset, y: p.y)
            lightLayer.addChild(ring)
            let grow = SKAction.scale(to: radius * 2 / 8, duration: 0.45)
            grow.timingMode = .easeOut
            ring.run(.sequence([.group([grow, .fadeOut(withDuration: 0.45)]), .removeFromParent()]))
        }
    }

    /// Aufsteigende Pixeltext-Einblendung, z. B. Punkte oder „КАСКАД x3“.
    func popup(_ text: String, at p: CGPoint, color: RGBA, scale: CGFloat = 1) {
        let canvas = PixelFont.render(text, color: color, shadow: RGBA(hex: 0x1A0A06))
        let node = SKSpriteNode(texture: canvas.texture(), size: CGSize(width: CGFloat(canvas.width) * scale, height: CGFloat(canvas.height) * scale))
        node.position = Self.snap(p)
        node.zPosition = 5
        pixelLayer.addChild(node)
        let rise = SKAction.moveBy(x: 0, y: 14, duration: 0.8)
        rise.timingMode = .easeOut
        node.run(.sequence([
            .group([rise, .sequence([.wait(forDuration: 0.45), .fadeOut(withDuration: 0.35)])]),
            .removeFromParent(),
        ]))
    }

    func update(_ dt: CGFloat) {
        for i in particles.indices {
            var p = particles[i]
            p.vy -= p.gravity * dt
            p.x += p.vx * dt
            p.y += p.vy * dt
            if p.gravity > 0, !p.bounced, p.y < floorY, p.vy < 0 {
                p.y = floorY
                p.vy = -p.vy * 0.35
                p.vx *= 0.6
                p.bounced = true
            }
            p.life -= dt
            p.node.position = CGPoint(x: p.x.rounded(), y: p.y.rounded())
            p.node.zRotation += p.spin * dt
            let fade = min(1, p.life / (p.maxLife * 0.35))
            p.node.alpha = fade
            p.glow?.position = CGPoint(x: p.x, y: p.y)
            p.glow?.alpha = fade * 0.7
            particles[i] = p
        }
        for p in particles where p.life <= 0 {
            p.node.removeFromParent()
            p.glow?.removeFromParent()
        }
        particles.removeAll { $0.life <= 0 }
    }
}
