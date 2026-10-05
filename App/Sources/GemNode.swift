import RaptCore
import SpriteKit

/// Ein Stein auf dem Brett. Die Knotenposition ist die logische Position;
/// `body` kann für den Warp-Effekt kurz verschoben werden, ohne laufende Fall-Animationen zu stören.
final class GemNode: SKNode {
    let gem: Gem
    let body: SKSpriteNode
    let glow: SKSpriteNode
    var isDying = false
    /// Während einer Fresser-Runde versteinert.
    var isPetrified = false
    private(set) var special: Special?
    private var overlay: SKSpriteNode?
    private var endGlows: [SKSpriteNode] = []

    init(gem: Gem, texture: SKTexture, glowTexture: SKTexture) {
        self.gem = gem
        body = SKSpriteNode(texture: texture, size: CGSize(width: GemArt.tile, height: GemArt.tile))
        glow = SKSpriteNode(texture: glowTexture, color: GemArt.glowColor(gem), size: CGSize(width: 42, height: 42))
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        glow.alpha = 0.16
        super.init()
        addChild(body)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) wird nicht verwendet")
    }

    /// Sichtbare Position inklusive Warp-Versatz.
    var visualPosition: CGPoint {
        CGPoint(x: position.x + body.position.x, y: position.y + body.position.y)
    }

    /// Macht aus dem Stein einen Spezialstein. Linie und Bombe bekommen ein Overlay, der Hyperstein eigene Bilder.
    func setSpecial(_ special: Special?, overlay texture: SKTexture?, lineFrames: [SKTexture], hyperFrames: [SKTexture]) {
        self.special = special
        overlay?.removeFromParent()
        overlay = nil
        endGlows.forEach { $0.removeFromParent() }
        endGlows = []
        body.removeAction(forKey: "hyper")
        guard let special else { return }
        switch special {
        case .line(let horizontal):
            // Flammen hinter dem Stein, pulsierendes Leuchten an beiden Enden
            let long = CGFloat(GemArt.tile + 12), short = CGFloat(GemArt.tile)
            let flames = SKSpriteNode(texture: lineFrames.first, size: horizontal ? CGSize(width: long, height: short) : CGSize(width: short, height: long))
            flames.zPosition = -1
            flames.run(.repeatForever(.animate(with: lineFrames, timePerFrame: 0.07)))
            body.addChild(flames)
            overlay = flames
            for side: CGFloat in [-1, 1] {
                let end = SKSpriteNode(texture: glow.texture, color: glow.color, size: CGSize(width: 18, height: 18))
                end.colorBlendFactor = 1
                end.blendMode = .add
                end.position = horizontal ? CGPoint(x: side * 13, y: 0) : CGPoint(x: 0, y: side * 13)
                end.zPosition = 2
                end.alpha = 0.7
                end.run(.repeatForever(.sequence([
                    .fadeAlpha(to: 1, duration: 0.18), .fadeAlpha(to: 0.45, duration: 0.22),
                ])))
                body.addChild(end)
                endGlows.append(end)
            }
            glow.size = CGSize(width: 50, height: 50)
        case .hyper:
            body.texture = hyperFrames.first
            body.run(.repeatForever(.animate(with: hyperFrames, timePerFrame: 0.08)), withKey: "hyper")
            glow.color = .white
            glow.size = CGSize(width: 54, height: 54)
        case .bomb:
            let node = SKSpriteNode(texture: texture, size: body.size)
            node.zPosition = 1
            node.run(.repeatForever(.sequence([.fadeAlpha(to: 0.55, duration: 0.35), .fadeAlpha(to: 1, duration: 0.35)])))
            body.addChild(node)
            overlay = node
            glow.size = CGSize(width: 50, height: 50)
        }
    }

    func removeWithGlow() {
        removeFromParent()
        glow.removeFromParent()
    }
}
