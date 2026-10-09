import RaptCore
import SpriteKit

/// Sternenbahn (jeder 10. Sprung im Dächerlauf): Aus einem Kristall wird ein graues Raumschiff, der Läufer
/// steigt ein, von oben schiebt sich eine Rennbahn ins Brett. Ziehen lenkt nach links und rechts; goldene
/// Münzen einsammeln. Die Banden schubsen nur zurück, abstürzen kann man nicht.
/// Die Szene blendet dafür die Steine aus und am Ende wieder ein; das Brett selbst bleibt unverändert.
final class StarRunRound: ArcadeBase, ArcadeRound {
    static let duration = 12.0
    let title = "STERNENBAHN"
    var hint: String { "ZIEHEN ZUM STEUERN" }
    var isFinished: Bool { timeLeft <= 0 }

    /// Eingesammelte und verpasste Münzen (nur solche, die schon am Schiff vorbei sind).
    private(set) var collected = 0
    private(set) var missed = 0
    var total: Int { collected + missed }

    /// Mitte des Schiffs (Welt), z. B. für die Rückverwandlung in den Kristall.
    var shipCenter: CGPoint { CGPoint(x: craft.node.position.x, y: craft.node.position.y + 10) }

    private struct Coin {
        let sprite: SKSpriteNode
        /// Bahnmeter (0 = Bahnanfang).
        let s: CGFloat
        /// Abstand von der linken Brettkante.
        let x: CGFloat
    }

    /// Höchsttempo der Bahn (Pixel pro Sekunde).
    private static let maxSpeed: CGFloat = 196
    /// Lang genug, dass auch bei Höchsttempo bis zum Ende Bahn im Bild ist (12 s × 196 px/s plus Brett und Reserve).
    private static let length = 2800
    /// Auf dieser Strecke wird die Bahn von 80 auf 52 Pixel schmaler, danach bleibt sie so.
    private static let narrowing = 1400.0
    private static let halfShip: CGFloat = 10
    private static let gold = RGBA(hex: 0xFFC247)
    /// Schwert-Laute wie im Samurai-Manga: Klingenklirren, Schnitt, Stich, Kiai.
    private static let words = ["カキーン!", "キン!", "キリ!", "ツキ!", "カタナ!", "ハッ!", "サッ!"]

    /// Mitte und halbe Breite der Fahrbahn je Bahnmeter, relativ zur linken Brettkante.
    private let centers: [Double]
    private let halfWidths: [Double]
    private let crop = SKCropNode()
    private let track: SKSpriteNode
    private var coins: [Coin] = []
    /// Wie weit die Bahn schon durchgelaufen ist; negativ, solange sie noch von oben hereinkommt.
    private var scroll: CGFloat = 0
    /// Die Bahn gleitet während des Manga-Auftakts von oben ins Brett.
    private var slidingIn = true
    private var streak = 0
    private var bumpCooldown = 0.0

    init(host: ArcadeHost) {
        let b = host.board
        let width = Double(b.width)
        let length = Self.length
        let halfWidths = (0..<length).map { 40 - 14 * min(1, Double($0) / Self.narrowing) }
        // Knickpunkte der Bahn: erst gerade, dann eckig hin und her wie im Entwurf
        var bends: [(s: Double, x: Double)] = [(0, width / 2), (90, width / 2)]
        var s = 90.0, x = width / 2
        while s < Double(length) {
            s += Double.random(in: 70...110)
            let hw = halfWidths[min(length - 1, Int(s))]
            x = min(width - hw - 8, max(hw + 8, x + Double.random(in: -50...50)))
            bends.append((s, x))
        }
        var centers: [Double] = []
        var segment = 0
        for meter in 0..<length {
            let m = Double(meter)
            while segment + 1 < bends.count - 1, bends[segment + 1].s <= m { segment += 1 }
            let a = bends[segment], z = bends[segment + 1]
            let t = max(0, min(1, (m - a.s) / max(1, z.s - a.s)))
            centers.append(a.x + (z.x - a.x) * t)
        }
        self.centers = centers
        self.halfWidths = halfWidths
        let canvas = ArcadeArt.starTrack(width: Int(b.width), length: length,
                                         center: { centers[min(length - 1, max(0, Int($0)))] },
                                         halfWidth: { halfWidths[min(length - 1, max(0, Int($0)))] })
        track = SKSpriteNode(texture: canvas.texture(), size: canvas.size)
        track.anchorPoint = .zero
        let spec = ArcadeCraft.Spec(texture: ArcadeArt.starShip(), size: CGSize(width: 22, height: 21), runnerRow: 6,
                                    nozzleRow: 14, hoverX: [], neon: false)
        super.init(host: host, duration: Self.duration, craft: spec, hover: 0, baseY: b.minY + 4, rise: false)

        // Bahn und Münzen nur innerhalb des Bretts
        let mask = SKSpriteNode(color: .white, size: b.size)
        mask.position = CGPoint(x: b.midX, y: b.midY)
        crop.maskNode = mask
        crop.zPosition = 1
        node.addChild(crop)
        track.zPosition = 0
        crop.addChild(track)

        // Münzen in Bögen über die Fahrbahn, teils knapp an den Banden
        let coinTexture = ArcadeArt.coin()
        let phase = Double.random(in: 0...(2 * .pi))
        for meter in stride(from: 40, to: length - 20, by: 24) {
            let hw = halfWidths[meter]
            let offset = (hw - 12) * 0.85 * sin(Double(meter) / 65 + phase)
            let sprite = SKSpriteNode(texture: coinTexture, size: CGSize(width: 11, height: 11))
            sprite.zPosition = 1
            let glow = glowSprite(Self.gold.skColor, size: 18, alpha: 0.35)
            glow.zPosition = -1
            sprite.addChild(glow)
            crop.addChild(sprite)
            coins.append(Coin(sprite: sprite, s: CGFloat(meter), x: CGFloat(centers[meter] + offset)))
        }

        // Zwei Schubfeuer an den Heckdüsen
        let frames = ArcadeArt.thruster()
        for side: CGFloat in [-5, 5] {
            let flame = SKSpriteNode(texture: frames[0], size: CGSize(width: 2, height: 5))
            flame.anchorPoint = CGPoint(x: 0.5, y: 1)
            flame.position = CGPoint(x: side, y: 0)
            flame.zPosition = 0.5
            flame.run(.repeatForever(.animate(with: frames.shuffled(), timePerFrame: 0.05)))
            craft.node.addChild(flame)
        }
        // Während des Auftakts von oben hereingleiten, damit die Bahn zum Start das ganze Brett füllt
        let height = b.height
        scroll = -height
        layout()
        let slide: CGFloat = 0.9
        node.run(.sequence([
            .customAction(withDuration: TimeInterval(slide)) { [weak self] _, t in
                guard let self, self.slidingIn else { return }
                let k = min(1, t / slide)
                self.scroll = -height * (1 - k) * (1 - k)
                self.layout()
            },
            .run { [weak self] in self?.finishSlide() },
        ]), withKey: "slide")
    }

    private func finishSlide() {
        guard slidingIn else { return }
        slidingIn = false
        node.removeAction(forKey: "slide")
        scroll = 0
        layout()
    }

    func release() {}

    private func center(_ s: CGFloat) -> CGFloat {
        CGFloat(centers[min(centers.count - 1, max(0, Int(s)))])
    }

    private func halfWidth(_ s: CGFloat) -> CGFloat {
        CGFloat(halfWidths[min(halfWidths.count - 1, max(0, Int(s)))])
    }

    /// Bahn und Münzen an die aktuelle Durchlaufstrecke anpassen.
    private func layout() {
        let b = host.board
        track.position = CGPoint(x: b.minX, y: (b.minY - scroll).rounded())
        for coin in coins {
            coin.sprite.position = CGPoint(x: (b.minX + coin.x).rounded(), y: (b.minY + coin.s - scroll).rounded())
        }
    }

    func update(_ dt: Double) {
        elapsed += dt
        timeLeft -= dt
        bumpCooldown -= dt
        finishSlide()
        // Die Bahn wird mit der Zeit und mit jeder gesammelten Münze schneller
        let speed = min(Self.maxSpeed, 88 + 1.8 * CGFloat(elapsed) + 2.6 * CGFloat(collected))
        // Nie über das Bahnende hinaus: Banden und Abdunklung bleiben bis zum Schluss im Bild
        scroll = min(scroll + speed * CGFloat(dt), CGFloat(Self.length) - host.board.height - 1)
        moveCraft(dt, maxSpeed: 260, stiffness: 18, response: 22)
        layout()

        let b = host.board
        let shipY = shipCenter.y
        // Banden auf Höhe des Schiffs: zurückschubsen, kein Absturz
        let s = shipY - b.minY + scroll
        if s >= 0 && s < CGFloat(Self.length) {
            let m = center(s), hw = halfWidth(s)
            let left = b.minX + m - hw, right = b.minX + m + hw
            if craft.confine(left + Self.halfShip, right - Self.halfShip) {
                bump(at: CGPoint(x: runnerX < b.minX + m ? left : right, y: shipY))
            }
        }

        // Münzen einsammeln oder verpassen
        for i in coins.indices.reversed() {
            let coin = coins[i]
            let p = coin.sprite.position
            if abs(p.y - shipY) < 9 && abs(p.x - runnerX) < 11 {
                collect(i)
            } else if p.y < shipY - 12 {
                missed += 1
                streak = 0
                coin.sprite.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
                coins.remove(at: i)
            }
        }
    }

    private func collect(_ i: Int) {
        let coin = coins.remove(at: i)
        let p = coin.sprite.position
        coin.sprite.removeFromParent()
        streak += 1
        collected += 1
        host.fx.flash(at: p, color: Self.gold.skColor)
        host.fx.shrapnel(at: p, colors: [Self.gold.skColor, .white], count: 6, power: 0.5, bounces: false)
        host.sound(.select, 0.55, Double(min(streak, 14)))
        if streak % 5 == 0 {
            // Serie: Kombo-Ruf wie im normalen Spiel, dazu ein Schwert-Laut
            host.tick()
            onomatopoeia(Self.words.randomElement()!, at: CGPoint(x: p.x, y: p.y + 18), color: Self.gold)
            let b = host.board
            host.fx.popup("\(GameScene.cheer(for: streak / 5 + 1)) x\(streak)", at: CGPoint(x: b.midX, y: b.maxY - 24),
                          color: RGBA(hex: 0xFFB347), scale: 2)
        }
    }

    private func bump(at p: CGPoint) {
        streak = 0
        guard bumpCooldown <= 0 else { return }
        bumpCooldown = 0.3
        craft.dip(2)
        host.fx.flash(at: p, color: RGBA(hex: 0xFF8A3D).skColor)
        host.fx.shrapnel(at: p, colors: [RGBA(hex: 0xFF8A3D).skColor, .white], count: 6, power: 0.5, bounces: false)
        host.sound(.paddle, 0.35, -7)
        host.shake(1)
        loseCoins(away: p.x < shipCenter.x ? 1 : -1)
    }

    /// Anteil der gesammelten Münzen, den ein Bandenkontakt kostet (10 → 2, 20 → 4; mindestens eine).
    private static let bumpLoss = 0.2

    /// Bandenkontakt kostet Münzen im Verhältnis zur Ausbeute: Sie springen aus dem Schiff davon und zählen als verpasst.
    private func loseCoins(away direction: CGFloat) {
        guard collected > 0 else { return }
        let lost = min(collected, max(1, Int((Double(collected) * Self.bumpLoss).rounded())))
        collected -= lost
        missed += lost
        let start = shipCenter
        // Höchstens acht fliegende Münzen, sonst wird es unübersichtlich
        for i in 0..<min(lost, 8) {
            let coin = SKSpriteNode(texture: ArcadeArt.coin(), size: CGSize(width: 11, height: 11))
            coin.position = start
            coin.zPosition = 3
            node.addChild(coin)
            let dx = direction * CGFloat.random(in: 18...34) + CGFloat(i) * direction * 5
            let arc = SKAction.customAction(withDuration: 0.5) { node, t in
                let k = t / 0.5
                node.position = CGPoint(x: (start.x + dx * k).rounded(), y: (start.y + sin(.pi * k) * 22 - 10 * k).rounded())
            }
            coin.run(.sequence([.group([arc, .sequence([.wait(forDuration: 0.3), .fadeOut(withDuration: 0.2)])]), .removeFromParent()]))
        }
        host.sound(.brick, 0.35, -5)
        host.fx.popup("-\(lost)", at: CGPoint(x: start.x, y: start.y + 18), color: RGBA(hex: 0xE0452B))
    }

    /// Ende: Schiff löst sich im Blitz auf (die Szene lässt dort den Kristall zurückgleiten).
    override func teardown() {
        node.removeAllActions()
        runner.isHidden = true
        for child in node.children where child !== craft.node {
            child.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
        }
        host.fx.flash(at: shipCenter, color: .white)
        craft.node.run(.fadeOut(withDuration: 0.15))
        node.run(.sequence([.wait(forDuration: 0.3), .removeFromParent()]))
    }
}
