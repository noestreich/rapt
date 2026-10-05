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
    func setSpecial(_ special: Special?, overlay texture: SKTexture?, hyperFrames: [SKTexture]) {
        self.special = special
        overlay?.removeFromParent()
        overlay = nil
        body.removeAction(forKey: "hyper")
        guard let special else { return }
        switch special {
        case .hyper:
            body.texture = hyperFrames.first
            body.run(.repeatForever(.animate(with: hyperFrames, timePerFrame: 0.08)), withKey: "hyper")
            glow.color = .white
            glow.size = CGSize(width: 54, height: 54)
        case .line, .bomb:
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
