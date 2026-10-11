import RaptCore
import SpriteKit

// Weitere Minispiele aus Power-ups: Flak (nach Missile Command, der Läufer bemannt eine rostige Flakstellung),
// Katana (nach Fruit Ninja, der Läufer schneidet auf einem Schwebebrett durch die Steine) und Kurzschluss
// (nach SameGame, ein Blitz aus der Tesla-Spule springt über zusammenhängende Steine einer Farbe).

// MARK: - Flak

/// Die Flakstellung steht mittig unter dem Brett. Antippen schickt eine Rakete zum Ziel; dort zerlegt eine
/// Explosion alle Steine im Umkreis. Begrenzte Munition, das Rohr dreht sich zum Finger.
final class FlakRound: ArcadeBase, ArcadeRound {
    let kind = PowerUp.flak
    let title = "FLAK"
    var hint: String { tr("TIPPEN: RAKETE ABFEUERN", "TAP: FIRE A ROCKET") }
    var isFinished: Bool { timeLeft <= 0 || remaining == 0 || (ammo == 0 && rockets.isEmpty && settle <= 0) }

    private static let maxAmmo = 7
    private static var words: [String] {
        GameSettings.shared.isGerman ? ["BUMM!", "WUMMS!", "KAWUMM!", "KRAWUMM!"] : ["BOOM!", "WHUMP!", "KABOOM!", "KRABOOM!"]
    }

    private struct Rocket {
        let sprite: SKSpriteNode
        var pos: CGPoint
        let target: CGPoint
        let direction: CGVector
    }

    private let barrel: SKSpriteNode
    private let rocketTexture = ArcadeArt.flakRocket()
    private var rockets: [Rocket] = []
    private var ammo = FlakRound.maxAmmo
    private var reload = 0.0
    private var trailTimer = 0.0
    /// Kurze Nachlaufzeit nach der letzten Rakete, damit die Explosion noch zu sehen ist.
    private var settle = 0.0
    private var pips: [SKSpriteNode] = []
    private let speed: CGFloat = 340
    private var radius: CGFloat { host.tile * 1.5 }

    init(host: ArcadeHost) {
        let spec = ArcadeCraft.Spec(texture: ArcadeArt.flakTurret(), size: CGSize(width: 25, height: 14), runnerRow: 3,
                                    nozzleRow: 9, hoverX: [-8, 8], neon: false)
        barrel = SKSpriteNode(texture: ArcadeArt.flakBarrel(), size: CGSize(width: 3, height: 10))
        super.init(host: host, duration: PowerUp.flak.arcadeDuration, craft: spec, hover: 3)
        barrel.anchorPoint = CGPoint(x: 0.5, y: 0.1)
        barrel.position = CGPoint(x: 0, y: spec.size.height - 1)
        barrel.zPosition = 2
        craft.node.addChild(barrel)
        // Munitionsanzeige: kleine Raketen links und rechts der Stellung
        for i in 0..<Self.maxAmmo {
            let pip = SKSpriteNode(texture: rocketTexture, size: CGSize(width: 1, height: 4))
            let side: CGFloat = i % 2 == 0 ? -1 : 1
            pip.position = CGPoint(x: side * (16 + CGFloat(i / 2) * 3), y: 4)
            craft.node.addChild(pip)
            pips.append(pip)
        }
    }

    /// Die Stellung bleibt in der Mitte; gezielt wird mit Antippen.
    override func pointer(_ px: CGFloat) {}

    func release() {}

    func touchDown(_ p: CGPoint) {
        aim(at: p)
        guard !runner.isHidden, ammo > 0, reload <= 0 else {
            if ammo == 0 { host.sound(.invalid, 0.3, -4) }
            return
        }
        let b = host.board
        let goal = CGPoint(x: min(b.maxX - 2, max(b.minX + 2, p.x)), y: min(b.maxY - 2, max(b.minY + 2, p.y)))
        let muzzle = muzzlePoint
        let dx = goal.x - muzzle.x, dy = goal.y - muzzle.y
        let len = max(1, (dx * dx + dy * dy).squareRoot())
        let s = SKSpriteNode(texture: rocketTexture, size: CGSize(width: 1, height: 4))
        s.zRotation = -atan2(dx, dy)
        s.addChild(glowSprite(RGBA(hex: 0xFF8A3D).skColor, size: 10, alpha: 0.7))
        s.position = muzzle
        node.addChild(s)
        rockets.append(Rocket(sprite: s, pos: muzzle, target: goal, direction: CGVector(dx: dx / len, dy: dy / len)))
        ammo -= 1
        reload = 0.22
        if ammo < pips.count {
            let pip = pips[ammo]
            pip.run(.sequence([.group([.moveBy(x: 0, y: 4, duration: 0.15), .fadeOut(withDuration: 0.15)]), .removeFromParent()]))
        }
        host.sound(.laser, 0.45, -6)
        host.fx.flash(at: muzzle, color: RGBA(hex: 0xFFB347).skColor)
        craft.dip(2)
        // Zielmarke blinkt kurz auf
        let mark = SKSpriteNode(texture: host.glowTexture, color: RGBA(hex: 0xE0452B).skColor, size: CGSize(width: 10, height: 10))
        mark.colorBlendFactor = 1
        mark.blendMode = .add
        mark.position = goal
        mark.alpha = 0.8
        node.addChild(mark)
        mark.run(.sequence([.repeat(.sequence([.fadeAlpha(to: 0.2, duration: 0.06), .fadeAlpha(to: 0.8, duration: 0.06)]), count: 3),
                            .fadeOut(withDuration: 0.1), .removeFromParent()]))
    }

    func touchMoved(_ p: CGPoint) { aim(at: p) }

    private var muzzlePoint: CGPoint {
        let base = CGPoint(x: craft.node.position.x, y: craft.node.position.y + barrel.position.y)
        let a = barrel.zRotation
        return CGPoint(x: base.x - sin(a) * 9, y: base.y + cos(a) * 9)
    }

    private func aim(at p: CGPoint) {
        let base = CGPoint(x: craft.node.position.x, y: craft.node.position.y + barrel.position.y)
        let angle = -atan2(p.x - base.x, max(4, p.y - base.y))
        barrel.zRotation = max(-1.2, min(1.2, angle))
        if abs(p.x - base.x) > 6 { runner.xScale = p.x > base.x ? 1 : -1 }
    }

    func update(_ dt: Double) {
        elapsed += dt
        timeLeft -= dt
        reload -= dt
        if ammo == 0 && rockets.isEmpty { settle -= dt }
        moveCraft(dt, maxSpeed: 60)

        trailTimer -= dt
        let trail = trailTimer <= 0
        if trail { trailTimer = 0.02 }
        var keep: [Rocket] = []
        for var r in rockets {
            r.pos.x += r.direction.dx * speed * CGFloat(dt)
            r.pos.y += r.direction.dy * speed * CGFloat(dt)
            let ahead = (r.target.x - r.pos.x) * r.direction.dx + (r.target.y - r.pos.y) * r.direction.dy
            if ahead <= 0 {
                r.sprite.removeFromParent()
                explode(at: r.target)
                continue
            }
            r.sprite.position = CGPoint(x: r.pos.x.rounded(), y: r.pos.y.rounded())
            if trail {
                let puff = glowSprite(RGBA(hex: 0xB8BCC8).skColor, size: 6, alpha: 0.45)
                puff.position = r.pos
                node.addChild(puff)
                puff.run(.sequence([.group([.fadeOut(withDuration: 0.4), .scale(to: 1.8, duration: 0.4)]), .removeFromParent()]))
            }
            keep.append(r)
        }
        rockets = keep
    }

    private func explode(at p: CGPoint) {
        settle = 0.6
        host.fx.explosion(at: p, scale: 1.4)
        host.fx.warpRing(at: p, color: RGBA(hex: 0xFF8A3D).skColor, radius: radius + 8)
        host.warp(p, 8, RGBA(hex: 0xFF8A3D).skColor)
        host.sound(.explosion, 0.75, Double.random(in: -2...2))
        host.shake(2)
        host.boom()
        var count = 0
        for r in 0..<host.rows {
            for c in 0..<host.cols {
                let pos = Pos(c, r)
                guard host.occupied(pos) else { continue }
                let center = host.center(pos)
                let dx = center.x - p.x, dy = center.y - p.y
                guard dx * dx + dy * dy <= radius * radius else { continue }
                if hit(pos, heavy: false) { count += 1 }
            }
        }
        if count >= 7 {
            onomatopoeia(Self.words.randomElement()!, at: CGPoint(x: p.x, y: p.y + 16), color: RGBA(hex: 0xFFB347))
        } else if count == 0 {
            onomatopoeia(tr("DANEBEN", "MISSED"), at: CGPoint(x: p.x, y: p.y + 12), color: RGBA(hex: 0xB8BCC8))
        }
    }
}

// MARK: - Katana

/// Der Läufer steht auf einem Schwebebrett unter dem Brett und zieht das Schwert: Wischen über die Steine
/// zerschneidet sie. Jeder Schnitt trifft höchstens eine Handvoll Steine, die Zahl der Hiebe ist begrenzt.
final class KatanaRound: ArcadeBase, ArcadeRound {
    let kind = PowerUp.katana
    let title = "KATANA"
    var hint: String { tr("WISCHEN: STEINE ZERSCHNEIDEN", "SWIPE: SLICE THE STONES") }
    var isFinished: Bool { timeLeft <= 0 || remaining == 0 || (strokesLeft == 0 && stroke == nil) }

    private static let maxStrokes = 6
    private static let cutsPerStroke = 7
    private static var words: [String] { ["キリ!", "サッ!", "ハッ!", "カタナ!", tr("ZACK!", "SLASH!")] }

    private struct Stroke {
        var last: CGPoint
        var cuts = 0
        var length: CGFloat = 0
    }

    private let pixel: SKTexture = {
        var c = PixelCanvas(width: 1, height: 1)
        c.set(0, 0, .white)
        return c.texture()
    }()
    private var stroke: Stroke?
    private var strokesLeft = KatanaRound.maxStrokes
    private var pips: [SKSpriteNode] = []

    init(host: ArcadeHost) {
        let spec = ArcadeCraft.Spec(texture: ArcadeArt.hoverBoard(), size: CGSize(width: 21, height: 5), runnerRow: -10,
                                    nozzleRow: 2, hoverX: [-6, 6], neon: true)
        super.init(host: host, duration: PowerUp.katana.arcadeDuration, craft: spec, hover: 5)
        // Verbleibende Hiebe als kleine Klingen über dem Brett
        for i in 0..<Self.maxStrokes {
            let pip = SKSpriteNode(texture: pixel, color: RGBA(hex: 0xD8FAFF).skColor, size: CGSize(width: 1, height: 4))
            pip.colorBlendFactor = 1
            pip.zRotation = -0.5
            pip.position = CGPoint(x: CGFloat(i - Self.maxStrokes / 2) * 4 + 2, y: -3)
            craft.node.addChild(pip)
            pips.append(pip)
        }
    }

    /// Das Brett folgt nur beim Schneiden dem Finger (siehe `touchMoved`).
    override func pointer(_ px: CGFloat) {}

    func release() {}

    func touchDown(_ p: CGPoint) {
        if stroke != nil { touchUp(p) }
        guard !runner.isHidden, strokesLeft > 0 else { return }
        stroke = Stroke(last: p)
        target = p.x
        cut(at: p)
    }

    func touchMoved(_ p: CGPoint) {
        guard var s = stroke else { return }
        target = p.x
        let dx = p.x - s.last.x, dy = p.y - s.last.y
        let len = (dx * dx + dy * dy).squareRoot()
        guard len >= 1 else { return }
        if s.length == 0 && len >= 4 {
            host.sound(.swap, 0.5, Double.random(in: 2...5))
        }
        slash(from: s.last, to: p)
        // Kleine Schritte, damit kein Stein übersprungen wird
        let steps = max(1, Int(ceil(len / 3)))
        for i in 1...steps where s.cuts < Self.cutsPerStroke {
            let t = CGFloat(i) / CGFloat(steps)
            let q = CGPoint(x: s.last.x + dx * t, y: s.last.y + dy * t)
            if let pos = cell(at: q), hit(pos) {
                s.cuts += 1
                host.sound(.brick, 0.55, Double(min(s.cuts * 2, 12)))
                host.fx.flash(at: host.center(pos), color: .white)
            }
        }
        s.length += len
        s.last = p
        stroke = s
    }

    func touchUp(_ p: CGPoint) {
        guard let s = stroke else { return }
        stroke = nil
        // Ein bloßes Antippen kostet keinen Hieb
        guard s.length >= 8 || s.cuts > 0 else { return }
        strokesLeft -= 1
        if strokesLeft < pips.count {
            pips[strokesLeft].run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
        }
        if s.cuts >= 3 {
            onomatopoeia(Self.words.randomElement()!, at: CGPoint(x: s.last.x, y: s.last.y + 12), color: RGBA(hex: 0xD8FAFF))
            host.shake(s.cuts >= 6 ? 2 : 1)
            host.tick()
        }
        if s.cuts == Self.cutsPerStroke {
            host.warp(s.last, 6, RGBA(hex: 0x3FD8FF).skColor)
        }
    }

    private func cut(at p: CGPoint) {
        guard var s = stroke, let pos = cell(at: p), hit(pos) else { return }
        s.cuts += 1
        stroke = s
        host.sound(.brick, 0.55, 0)
    }

    /// Weiße Klingenspur mit kaltem Leuchten, die schnell verblasst.
    private func slash(from a: CGPoint, to b: CGPoint) {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = (dx * dx + dy * dy).squareRoot()
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        let line = SKSpriteNode(texture: pixel, color: .white, size: CGSize(width: len + 1, height: 2))
        line.colorBlendFactor = 1
        line.position = mid
        line.zRotation = atan2(dy, dx)
        line.zPosition = 5
        node.addChild(line)
        line.run(.sequence([.group([.fadeOut(withDuration: 0.22), .scaleY(to: 0.3, duration: 0.22)]), .removeFromParent()]))
        let glow = glowSprite(RGBA(hex: 0x3FD8FF).skColor, size: 10, alpha: 0.5)
        glow.position = mid
        glow.zPosition = 4
        node.addChild(glow)
        glow.run(.sequence([.fadeOut(withDuration: 0.25), .removeFromParent()]))
    }

    func update(_ dt: Double) {
        elapsed += dt
        timeLeft -= dt
        moveCraft(dt, maxSpeed: 260, stiffness: 14, response: 18)
    }
}

// MARK: - Kurzschluss

/// Der Läufer fährt einen Tesla-Wagen unter dem Brett. Antippen eines Steins schickt einen Blitz aus der Kugel;
/// er springt von Stein zu Stein über alle Nachbarn derselben Farbe (auch schräg). Fünf Ladungen.
final class KurzschlussRound: ArcadeBase, ArcadeRound {
    let kind = PowerUp.kurzschluss
    var title: String { tr("KURZSCHLUSS", "OVERLOAD") }
    var hint: String { tr("STEIN ANTIPPEN: BLITZ!", "TAP A STONE: ZAP!") }
    var isFinished: Bool { timeLeft <= 0 || remaining == 0 || (charges == 0 && busy <= 0) }

    private static let maxCharges = 5
    /// Höchstens so viele Steine pro Blitz.
    private static let maxChain = 18
    private static var words: [String] { ["BZZZT!", tr("ZAPP!", "ZAP!"), tr("KNISTER!", "CRACKLE!"), "ZZZAP!"] }
    private static let blue = RGBA(hex: 0x3FD8FF)

    private var charges = KurzschlussRound.maxCharges
    private var reload = 0.0
    /// Solange ein Blitz noch springt, endet die Runde nicht.
    private var busy = 0.0
    private var arcTimer = 0.5
    private var pips: [SKSpriteNode] = []
    private let orb: SKSpriteNode

    init(host: ArcadeHost) {
        let spec = ArcadeCraft.Spec(texture: ArcadeArt.teslaCoil(), size: CGSize(width: 23, height: 14), runnerRow: 4,
                                    nozzleRow: 10, hoverX: [-7, 7], neon: true)
        orb = SKSpriteNode(texture: host.glowTexture, color: KurzschlussRound.blue.skColor, size: CGSize(width: 18, height: 18))
        super.init(host: host, duration: PowerUp.kurzschluss.arcadeDuration, craft: spec, hover: 4)
        orb.colorBlendFactor = 1
        orb.blendMode = .add
        orb.alpha = 0.6
        orb.position = CGPoint(x: 0, y: spec.size.height - 2)
        orb.zPosition = 2
        orb.run(.repeatForever(.sequence([.fadeAlpha(to: 0.85, duration: 0.12), .fadeAlpha(to: 0.45, duration: 0.18)])))
        craft.node.addChild(orb)
        // Ladungen als kleine blaue Lichter unter dem Wagen
        for i in 0..<Self.maxCharges {
            let pip = SKSpriteNode(texture: host.glowTexture, color: Self.blue.skColor, size: CGSize(width: 5, height: 5))
            pip.colorBlendFactor = 1
            pip.blendMode = .add
            pip.position = CGPoint(x: CGFloat(i - Self.maxCharges / 2) * 4, y: -3)
            craft.node.addChild(pip)
            pips.append(pip)
        }
    }

    func release() {}

    private var sphere: CGPoint {
        CGPoint(x: craft.node.position.x, y: craft.node.position.y + craft.spec.size.height - 2)
    }

    func touchDown(_ p: CGPoint) {
        guard !runner.isHidden, charges > 0, reload <= 0, let start = cell(at: p), let color = host.gemColor(start) else { return }
        charges -= 1
        reload = 0.3
        if charges < pips.count {
            pips[charges].run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
        }

        // Breitensuche über gleichfarbige Nachbarn; jede Stufe springt etwas später
        var links: [(from: Pos, to: Pos, depth: Int)] = []
        var seen: Set<Pos> = [start]
        var frontier = [start]
        var depth = 0
        while !frontier.isEmpty, seen.count < Self.maxChain {
            depth += 1
            var next: [Pos] = []
            for a in frontier {
                for dr in -1...1 {
                    for dc in -1...1 where dr != 0 || dc != 0 {
                        let b = Pos(a.col + dc, a.row + dr)
                        guard seen.count < Self.maxChain, (0..<host.cols).contains(b.col), (0..<host.rows).contains(b.row),
                              !seen.contains(b), !cleared.contains(b), host.occupied(b), host.gemColor(b) == color else { continue }
                        seen.insert(b)
                        next.append(b)
                        links.append((a, b, depth))
                    }
                }
            }
            frontier = next
        }

        let step = 0.07
        host.fx.lightning(from: sphere, to: host.center(start), color: color.skColor)
        host.sound(.purge, 0.6, 0)
        host.fx.flash(at: sphere, color: Self.blue.skColor)
        craft.dip(2)
        hit(start, heavy: false)
        for link in links {
            let delay = step * Double(link.depth)
            host.fx.lightning(from: host.center(link.from), to: host.center(link.to), color: color.skColor, delay: delay)
            node.run(.sequence([.wait(forDuration: delay + 0.03), .run { [weak self] in
                guard let self, self.hit(link.to) else { return }
                self.host.sound(.brick, 0.4, Double(min(link.depth * 2, 12)))
            }]))
        }
        busy = step * Double(depth) + 0.4
        let total = links.count + 1
        if total >= 8 {
            node.run(.sequence([.wait(forDuration: busy - 0.3), .run { [weak self] in
                guard let self else { return }
                self.onomatopoeia(Self.words.randomElement()!, at: CGPoint(x: self.host.center(start).x, y: self.host.center(start).y + 14),
                                  color: Self.blue)
                self.host.shake(2)
                self.host.boom()
            }]))
        } else if total == 1 {
            onomatopoeia("PFFT", at: CGPoint(x: host.center(start).x, y: host.center(start).y + 12), color: RGBA(hex: 0xB8BCC8))
        }
    }

    func update(_ dt: Double) {
        elapsed += dt
        timeLeft -= dt
        reload -= dt
        busy -= dt
        moveCraft(dt, maxSpeed: 150)
        // Kleine Funken an der Kugel, solange noch Ladung da ist
        arcTimer -= dt
        if arcTimer <= 0, charges > 0, !runner.isHidden {
            arcTimer = Double.random(in: 0.25...0.6)
            let s = sphere
            let angle = CGFloat.random(in: 0.3...(CGFloat.pi - 0.3))
            let r = CGFloat.random(in: 6...10)
            host.fx.lightning(from: s, to: CGPoint(x: s.x + cos(angle) * r, y: s.y + sin(angle) * r), color: Self.blue.skColor)
        }
    }
}
