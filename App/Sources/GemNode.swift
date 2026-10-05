import RaptCore
import SpriteKit

/// Ein Stein auf dem Brett. Die Knotenposition ist die logische Position;
/// `body` kann für den Warp-Effekt kurz verschoben werden, ohne laufende Fall-Animationen zu stören.
final class GemNode: SKNode {
    let gem: Gem
    let body: SKSpriteNode
    let glow: SKSpriteNode
    var isDying = false

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

    func removeWithGlow() {
        removeFromParent()
        glow.removeFromParent()
    }
}
