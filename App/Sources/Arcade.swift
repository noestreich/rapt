import CoreImage
import RaptCore
import SpriteKit

// Minispiele, die ein Power-up auslöst: Invasion (nach Space Invaders) und Abrissbirne (nach Arkanoid,
// mit einem rostigen Glider als Schläger). In beiden sitzt der Läufer von den Dächern in einem Fluggerät. Die Runden kennen die Szene nur über `ArcadeHost`;
// am Ende gibt die Szene `cleared` an die Spiellogik (`Game.finishArcade`).

/// Was ein Minispiel von der Szene braucht. Koordinaten sind Weltkoordinaten der Effekt-Ebene (y nach oben).
struct ArcadeHost {
    let fx: Effects
    let glowTexture: SKTexture
    let tile: CGFloat
    let cols: Int
    let rows: Int
    /// Brett in Weltkoordinaten.
    let board: CGRect
    /// Boden der Bahn unter dem Brett, auf der der Läufer rennt (Welt-y).
    let groundY: CGFloat
    let figure: PowerUpArt.FigureFrames
    /// Fluggerät kommt mit Läufer an Bord herein (wenn er auf keinem Dach steht, von dem er einsteigen kann).
    let entrance: Bool
    let center: (Pos) -> CGPoint
    /// Steht dort noch ein Stein?
    let occupied: (Pos) -> Bool
    let gemColor: (Pos) -> RGBA?
    /// Zerschlägt einen Stein mit Splittern und Glow; `heavy` mit Explosion. `false`, wenn dort keiner mehr ist.
    let smash: (Pos, Bool) -> Bool
    /// Verschiebt alle Steine waagerecht (Marschtakt der Invasion).
    let march: (CGFloat) -> Void
    let shake: (Int) -> Void
    let warp: (CGPoint, CGFloat, SKColor) -> Void
    let sound: (SoundSlot, Float, Double) -> Void
    let tick: () -> Void
    let boom: () -> Void
}

protocol ArcadeRound: AnyObject {
    var kind: PowerUp { get }
    var node: SKNode { get }
    var cleared: Set<Pos> { get }
    var timeLeft: Double { get }
    var isFinished: Bool { get }
    /// Statuszeile während der Runde.
    var hint: String { get }
    func update(_ dt: Double)
    /// Finger oder Maus (Welt-x), beim Drücken und Ziehen.
    func pointer(_ x: CGFloat)
    func release()
    func teardown()
    /// Sitzplatz des Läufers in der Kabine (Weltkoordinaten, Fußpunkt): Ziel des Einstiegs, Start des Rücksprungs.
    var seat: CGPoint { get }
    /// Läufer ist in die Kabine gesprungen.
    func board()
}

/// Fluggerät mit Kabine für den Läufer: gleitet mit Trägheit, Seitendüsen zeigen die Schubrichtung,
/// Schwebeflammen unten, leichtes Schweben, kurzes Eintauchen bei Aufprall.
final class ArcadeCraft {
    struct Spec {
        let texture: SKTexture
        let size: CGSize
        /// Zeile (von oben), auf der der Kopf des Läufers sitzt.
        let runnerRow: Int
        /// Zeile (von oben) der Seitendüsen.
        let nozzleRow: CGFloat
        /// Waagerechte Lage der Schwebedüsen relativ zur Mitte.
        let hoverX: [CGFloat]
        let neon: Bool
    }

    let node = SKNode()
    let runner: SKSpriteNode
    let spec: Spec
    private let leftFlame: SKSpriteNode
    private let rightFlame: SKSpriteNode
    private(set) var x: CGFloat
    private(set) var velocity: CGFloat = 0
    private var kick: CGFloat = 0
    private var clock = 0.0
    /// Unterkante des Geräts (Welt-y), ohne Schweben und Eintauchen.
    let baseY: CGFloat

    init(spec: Spec, figure: PowerUpArt.FigureFrames, glow: SKTexture, x: CGFloat, baseY: CGFloat) {
        self.spec = spec
        self.x = x
        self.baseY = baseY
        let body = SKSpriteNode(texture: spec.texture, size: spec.size)
        body.anchorPoint = CGPoint(x: 0.5, y: 0)
        body.zPosition = 1
        node.addChild(body)
        runner = SKSpriteNode(texture: figure.idle[0], size: CGSize(width: 7, height: 10))
        runner.anchorPoint = CGPoint(x: 0.5, y: 0)
        runner.position = CGPoint(x: 0, y: spec.size.height - CGFloat(spec.runnerRow) - 10)
        runner.isHidden = true
        node.addChild(runner)
        let underGlow = SKSpriteNode(texture: glow, color: spec.neon ? RGBA(hex: 0xFF4FA8).skColor : RGBA(hex: 0xFFB347).skColor,
                                     size: CGSize(width: spec.size.width + 14, height: 16))
        underGlow.colorBlendFactor = 1
        underGlow.blendMode = .add
        underGlow.alpha = 0.45
        underGlow.position = CGPoint(x: 0, y: 1)
        underGlow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.6, duration: 0.09), .fadeAlpha(to: 0.38, duration: 0.11)])))
        node.addChild(underGlow)
        let flameFrames = ArcadeArt.sideFlames(neon: spec.neon)
        let nozzleY = spec.size.height - spec.nozzleRow - 0.5
        leftFlame = SKSpriteNode(texture: flameFrames[0], size: CGSize(width: 7, height: 3))
        leftFlame.anchorPoint = CGPoint(x: 1, y: 0.5)
        leftFlame.position = CGPoint(x: -spec.size.width / 2, y: nozzleY)
        rightFlame = SKSpriteNode(texture: flameFrames[0], size: CGSize(width: 7, height: 3))
        rightFlame.anchorPoint = CGPoint(x: 1, y: 0.5)
        rightFlame.xScale = -1
        rightFlame.position = CGPoint(x: spec.size.width / 2, y: nozzleY)
        for flame in [leftFlame, rightFlame] {
            flame.alpha = 0
            flame.run(.repeatForever(.animate(with: flameFrames.shuffled(), timePerFrame: 0.05)))
            node.addChild(flame)
        }
        let hoverFrames = ArcadeArt.hoverFlames(neon: spec.neon)
        for hx in spec.hoverX {
            let flame = SKSpriteNode(texture: hoverFrames[0], size: CGSize(width: 1, height: 3))
            flame.anchorPoint = CGPoint(x: 0.5, y: 1)
            flame.position = CGPoint(x: hx, y: 0)
            flame.run(.repeatForever(.animate(with: hoverFrames.shuffled(), timePerFrame: 0.06)))
            node.addChild(flame)
        }
        node.position = CGPoint(x: x.rounded(), y: baseY)
    }

    /// Oberkante des Geräts gerade jetzt (mit Schweben und Eintauchen).
    var top: CGFloat { node.position.y + spec.size.height }

    /// Sitzplatz (Fußpunkt des Läufers) in Weltkoordinaten.
    var seat: CGPoint { CGPoint(x: node.position.x, y: node.position.y + runner.position.y) }

    func dip(_ pixels: CGFloat = 2) { kick = max(kick, pixels) }

    /// Gleitet zum Ziel: weich beschleunigen und abbremsen.
    /// `stiffness` und `response` bestimmen, wie direkt das Gerät folgt (klein = träge, groß = präzise).
    func update(_ dt: Double, target: CGFloat, maxSpeed: CGFloat, stiffness: CGFloat = 9, response: CGFloat = 10) {
        clock += dt
        let t = CGFloat(dt)
        let desired = max(-maxSpeed, min(maxSpeed, (target - x) * stiffness))
        velocity += (desired - velocity) * min(1, t * response)
        x += velocity * t
        kick = max(0, kick - 24 * t)
        let hover: CGFloat = sin(clock * 3.2) > 0.6 ? 1 : 0
        node.position = CGPoint(x: x.rounded(), y: baseY + hover - kick.rounded())
        // Schub zur Seite: Düse gegenüber der Fahrtrichtung feuert
        let push = min(1, abs(velocity) / (maxSpeed * 0.5))
        leftFlame.alpha = velocity > 8 ? push : 0
        rightFlame.alpha = velocity < -8 ? push : 0
        leftFlame.xScale = 0.6 + 0.4 * push
        rightFlame.xScale = -(0.6 + 0.4 * push)
        // Der Läufer schaut in Fahrtrichtung
        if abs(velocity) > 8 { runner.xScale = velocity > 0 ? 1 : -1 }
    }
}

/// Gemeinsames: Treffer zählen, Schüsse von unten, Lautmalerei-Einblendungen.
class ArcadeBase {
    let host: ArcadeHost
    let node = SKNode()
    private(set) var cleared: Set<Pos> = []
    var timeLeft: Double
    var elapsed = 0.0
    var hits = 0

    /// Fluggerät mit dem Läufer; `target` ist die Fingerposition.
    let craft: ArcadeCraft
    var target: CGFloat
    var runnerX: CGFloat { craft.x }
    var seat: CGPoint { craft.seat }
    var runner: SKSpriteNode { craft.runner }

    struct Shot {
        let sprite: SKSpriteNode
        var x: CGFloat
        var y: CGFloat
        let speed: CGFloat
    }

    var shots: [Shot] = []

    init(host: ArcadeHost, duration: Double, craft spec: ArcadeCraft.Spec, hover: CGFloat) {
        self.host = host
        timeLeft = duration
        let mid = host.board.midX
        target = mid
        craft = ArcadeCraft(spec: spec, figure: host.figure, glow: host.glowTexture, x: mid, baseY: host.groundY + hover)
        craft.node.zPosition = 2
        node.addChild(craft.node)
        // Auftritt: steigt hinter den Häusern auf (die Szene hängt die Runde dafür kurz hinter die Häuser)
        let resting = craft.node.position
        craft.node.position.y = resting.y - 70
        let rise = SKAction.move(to: resting, duration: 0.5)
        rise.timingMode = .easeOut
        craft.node.run(rise)
        if host.entrance { board() }
    }

    func pointer(_ px: CGFloat) {
        target = px
    }

    /// Läufer sitzt jetzt in der Kabine.
    func board() {
        guard runner.isHidden else { return }
        runner.isHidden = false
        host.fx.flash(at: CGPoint(x: seat.x, y: seat.y + 6), color: RGBA(hex: 0x3FD8FF).skColor)
        craft.dip(2)
    }

    /// Bewegt das Gerät; `margin` hält es innerhalb des Bretts.
    func moveCraft(_ dt: Double, maxSpeed: CGFloat, stiffness: CGFloat = 9, response: CGFloat = 10) {
        let half = craft.spec.size.width / 2
        let goal = min(host.board.maxX - half, max(host.board.minX + half, target))
        craft.update(dt, target: goal, maxSpeed: maxSpeed, stiffness: stiffness, response: response)
    }

    var remaining: Int {
        var n = 0
        for r in 0..<host.rows {
            for c in 0..<host.cols where host.occupied(Pos(c, r)) { n += 1 }
        }
        return n
    }

    func column(at x: CGFloat) -> Int? {
        let c = Int(floor((x - host.board.minX) / host.tile))
        return (0..<host.cols).contains(c) ? c : nil
    }

    func cell(at p: CGPoint) -> Pos? {
        guard let c = column(at: p.x) else { return nil }
        let r = Int(floor((host.board.maxY - p.y) / host.tile))
        guard (0..<host.rows).contains(r) else { return nil }
        let pos = Pos(c, r)
        return host.occupied(pos) ? pos : nil
    }

    /// Unterster Stein einer Spalte (höchste Zeilennummer).
    func lowest(inColumn c: Int) -> Pos? {
        for r in stride(from: host.rows - 1, through: 0, by: -1) where host.occupied(Pos(c, r)) {
            return Pos(c, r)
        }
        return nil
    }

    @discardableResult
    func hit(_ p: Pos, heavy: Bool = false) -> Bool {
        guard !cleared.contains(p), host.smash(p, heavy) else { return false }
        cleared.insert(p)
        hits += 1
        if hits % 3 == 0 { host.tick() }
        return true
    }

    func glowSprite(_ color: SKColor, size: CGFloat, alpha: CGFloat) -> SKSpriteNode {
        let g = SKSpriteNode(texture: host.glowTexture, color: color, size: CGSize(width: size, height: size))
        g.colorBlendFactor = 1
        g.blendMode = .add
        g.alpha = alpha
        return g
    }

    /// Schuss nach oben; trifft den untersten Stein seiner Spalte.
    func fire(from p: CGPoint, texture: SKTexture, size: CGSize, glow: SKColor, speed: CGFloat = 300) {
        let s = SKSpriteNode(texture: texture, size: size)
        s.position = CGPoint(x: p.x.rounded(), y: p.y.rounded())
        s.addChild(glowSprite(glow, size: 9, alpha: 0.7))
        node.addChild(s)
        shots.append(Shot(sprite: s, x: p.x, y: p.y, speed: speed))
    }

    /// Bewegt alle Schüsse. `extra` darf einen Schuss oberhalb des Bretts abfangen (UFO) und gibt dann `true` zurück.
    func updateShots(_ dt: Double, extra: (Shot) -> Bool = { _ in false }) {
        var keep: [Shot] = []
        for var shot in shots {
            shot.y += shot.speed * CGFloat(dt)
            var done = false
            if let c = column(at: shot.x), let p = lowest(inColumn: c) {
                let bottom = host.center(p).y - host.tile / 2 + 3
                if shot.y >= bottom {
                    hit(p)
                    host.sound(.brick, 0.45, Double(hits % 12))
                    done = true
                }
            }
            if !done && shot.y > host.board.maxY { done = extra(shot) }
            if !done && shot.y > host.board.maxY + 40 { done = true }
            if done {
                shot.sprite.removeFromParent()
            } else {
                shot.sprite.position = CGPoint(x: shot.x.rounded(), y: shot.y.rounded())
                keep.append(shot)
            }
        }
        shots = keep
    }

    /// Manga-Lautmalerei, die kurz aufploppt und schräg steht.
    func onomatopoeia(_ text: String, at p: CGPoint, color: RGBA) {
        let canvas = PixelFont.render(text, color: color, shadow: RGBA(hex: 0x1A0A06))
        let label = SKSpriteNode(texture: canvas.texture(), size: CGSize(width: canvas.width * 2, height: canvas.height * 2))
        label.position = CGPoint(x: min(host.board.maxX - 20, max(host.board.minX + 20, p.x)).rounded(), y: p.y.rounded())
        label.zRotation = CGFloat.random(in: -0.25...0.25)
        label.zPosition = 6
        label.setScale(0.4)
        node.addChild(label)
        let pop = SKAction.scale(to: 1.15, duration: 0.07)
        pop.timingMode = .easeOut
        label.run(.sequence([
            pop, .scale(to: 1, duration: 0.06),
            .group([.moveBy(x: 0, y: 8, duration: 0.45), .sequence([.wait(forDuration: 0.25), .fadeOut(withDuration: 0.2)])]),
            .removeFromParent(),
        ]))
    }

    func teardown() {
        host.march(0)
        node.removeAllActions()
        runner.isHidden = true
        for child in node.children where child !== craft.node {
            child.run(.sequence([.fadeOut(withDuration: 0.1), .removeFromParent()]))
        }
        // Gerät sinkt leer hinter die Häuser
        let drop = SKAction.moveBy(x: 0, y: -80, duration: 0.7)
        drop.timingMode = .easeIn
        craft.node.run(drop)
        node.run(.sequence([.wait(forDuration: 0.75), .removeFromParent()]))
    }
}

// MARK: - Invasion

/// Der Läufer fährt unter dem Brett und schießt automatisch nach oben. Die Steine marschieren im Takt,
/// werfen Zickzack-Geschosse (Treffer lähmen kurz), und zweimal fliegt ein UFO vorbei: Abschuss → Blitze.
final class InvasionRound: ArcadeBase, ArcadeRound {
    let kind = PowerUp.invasion
    var hint: String { "ZIEHEN ZUM ZIELEN" }
    var isFinished: Bool { timeLeft <= 0 || remaining == 0 }

    private let boltTexture = ArcadeArt.bolt()
    private let ufoFrames = ArcadeArt.ufo()
    private var fireTimer = 0.35
    private var stun = 0.0
    private var marchTimer = 0.3
    private var marchStep = 0
    private var dropTimer = 1.2
    private var drops: [(sprite: SKSpriteNode, color: SKColor, x: CGFloat, y: CGFloat)] = []
    private var ufo: (sprite: SKSpriteNode, x: CGFloat, dir: CGFloat)?
    private var ufoTimes = [2.2, 5.6]
    private var ufoSoundTimer = 0.0

    init(host: ArcadeHost) {
        let spec = ArcadeCraft.Spec(texture: ArcadeArt.pod(), size: CGSize(width: 23, height: 12), runnerRow: 2,
                                    nozzleRow: 8, hoverX: [-4, 4], neon: true)
        super.init(host: host, duration: PowerUp.invasion.arcadeDuration, craft: spec, hover: 4)
    }

    func release() {}

    func update(_ dt: Double) {
        elapsed += dt
        timeLeft -= dt

        // Gleiter folgt dem Finger
        moveCraft(dt, maxSpeed: 170)
        let x = runnerX

        // Lähmung nach Treffer: flackern, nicht schießen
        if stun > 0 {
            stun -= dt
            craft.node.alpha = Int(stun * 20) % 2 == 0 ? 0.35 : 1
            if stun <= 0 { craft.node.alpha = 1 }
        } else {
            fireTimer -= dt
            if fireTimer <= 0 {
                fireTimer = 0.16
                let muzzle = CGPoint(x: x, y: craft.top)
                fire(from: muzzle, texture: boltTexture, size: CGSize(width: 1, height: 5), glow: RGBA(hex: 0x3FD8FF).skColor)
                host.sound(.laser, 0.3, Double.random(in: -1...1))
                let flash = glowSprite(.white, size: 8, alpha: 0.9)
                flash.position = muzzle
                node.addChild(flash)
                flash.run(.sequence([.fadeOut(withDuration: 0.08), .removeFromParent()]))
            }
        }

        updateShots(dt) { [weak self] shot in self?.shootUfo(shot) ?? false }
        updateMarch(dt)
        updateDrops(dt)
        updateUfo(dt)
    }

    // Marschtakt: wird schneller, je weniger Steine übrig sind
    private func updateMarch(_ dt: Double) {
        marchTimer -= dt
        guard marchTimer <= 0 else { return }
        let left = Double(remaining) / Double(host.cols * host.rows)
        marchTimer = 0.13 + 0.35 * left
        marchStep += 1
        let offsets: [CGFloat] = [0, 1, 2, 1, 0, -1, -2, -1]
        host.march(offsets[marchStep % offsets.count])
        let notes: [Double] = [0, -2, -3, -5]
        host.sound(.march, 0.5, notes[marchStep % notes.count])
    }

    // Steine werfen Zickzack-Geschosse
    private func updateDrops(_ dt: Double) {
        let x = runnerX
        dropTimer -= dt
        if dropTimer <= 0 {
            dropTimer = Double.random(in: 0.55...1.1)
            let columns = (0..<host.cols).compactMap { lowest(inColumn: $0) }
            if let p = columns.randomElement() {
                let color = host.gemColor(p) ?? .white
                let start = CGPoint(x: host.center(p).x, y: host.center(p).y - host.tile / 2)
                let s = SKSpriteNode(texture: ArcadeArt.enemyShot(color), size: CGSize(width: 3, height: 4))
                s.addChild(glowSprite(color.skColor, size: 9, alpha: 0.6))
                s.run(.repeatForever(.sequence([.wait(forDuration: 0.08), .run { s.xScale *= -1 }])))
                node.addChild(s)
                drops.append((s, color.skColor, start.x, start.y))
            }
        }
        var keep: [(sprite: SKSpriteNode, color: SKColor, x: CGFloat, y: CGFloat)] = []
        for var d in drops {
            d.y -= 70 * CGFloat(dt)
            if stun <= 0, abs(d.x - x) < 10, d.y < craft.top, d.y > craft.node.position.y {
                stun = 0.8
                craft.dip(3)
                let hitPoint = CGPoint(x: d.x, y: d.y)
                host.fx.flash(at: hitPoint, color: RGBA(hex: 0xE0452B).skColor)
                host.fx.shrapnel(at: hitPoint, colors: [.white, RGBA(hex: 0x3FD8FF).skColor, RGBA(hex: 0xFF4FA8).skColor], count: 10, power: 0.6, bounces: false)
                host.sound(.invalid, 0.5, 0)
                host.shake(1)
                onomatopoeia("AUA!", at: CGPoint(x: x, y: craft.top + 12), color: RGBA(hex: 0xE0452B))
                d.sprite.removeFromParent()
                continue
            }
            if d.y < host.groundY - 4 {
                host.fx.flash(at: CGPoint(x: d.x, y: d.y), color: d.color)
                d.sprite.removeFromParent()
                continue
            }
            d.sprite.position = CGPoint(x: d.x.rounded(), y: d.y.rounded())
            keep.append(d)
        }
        drops = keep
    }

    // UFO über dem Brett
    private var ufoY: CGFloat { host.board.maxY + 10 }

    private func updateUfo(_ dt: Double) {
        if ufo == nil, let next = ufoTimes.first, elapsed >= next {
            ufoTimes.removeFirst()
            let dir: CGFloat = ufoTimes.isEmpty ? -1 : 1
            let s = SKSpriteNode(texture: ufoFrames[0], size: CGSize(width: 13, height: 5))
            s.run(.repeatForever(.animate(with: ufoFrames, timePerFrame: 0.12)))
            s.addChild(glowSprite(RGBA(hex: 0xFF4FA8).skColor, size: 30, alpha: 0.5))
            s.zPosition = 3
            node.addChild(s)
            ufo = (s, dir > 0 ? host.board.minX - 16 : host.board.maxX + 16, dir)
        }
        guard var u = ufo else { return }
        u.x += u.dir * 58 * CGFloat(dt)
        u.sprite.position = CGPoint(x: u.x.rounded(), y: ufoY)
        ufo = u
        ufoSoundTimer -= dt
        if ufoSoundTimer <= 0 {
            ufoSoundTimer = 0.26
            host.sound(.ufo, 0.35, 0)
        }
        if u.x < host.board.minX - 24 || u.x > host.board.maxX + 24 {
            u.sprite.removeFromParent()
            ufo = nil
        }
    }

    private func shootUfo(_ shot: Shot) -> Bool {
        guard let u = ufo, abs(shot.x - u.x) <= 7, shot.y >= ufoY - 3 else { return false }
        ufo = nil
        u.sprite.removeFromParent()
        let p = CGPoint(x: u.x, y: ufoY)
        host.fx.explosion(at: p, scale: 1.6)
        host.fx.firework(at: p, colors: [RGBA(hex: 0xFF4FA8).skColor, RGBA(hex: 0x3FD8FF).skColor, .white])
        host.warp(p, 10, RGBA(hex: 0xFF4FA8).skColor)
        host.shake(3)
        host.boom()
        host.sound(.explosion, 0.9, 0)
        onomatopoeia("UFO!", at: CGPoint(x: p.x, y: p.y - 14), color: RGBA(hex: 0xFFF3D6))
        // Blitze schlagen in bis zu sechs Steine ein
        var targets: [Pos] = []
        for r in 0..<host.rows {
            for c in 0..<host.cols where host.occupied(Pos(c, r)) { targets.append(Pos(c, r)) }
        }
        for (i, t) in targets.shuffled().prefix(6).enumerated() {
            let delay = 0.08 * Double(i)
            host.fx.lightning(from: p, to: host.center(t), color: RGBA(hex: 0xFF4FA8).skColor, delay: delay)
            node.run(.sequence([.wait(forDuration: delay + 0.05), .run { [weak self] in
                guard let self else { return }
                if self.hit(t, heavy: true) { self.host.sound(.purge, 0.4, Double(i)) }
            }]))
        }
        return true
    }
}

// MARK: - Abrissbirne

/// Der Läufer rennt durch die Bahn und stemmt eine Metallstange über den Kopf; davon prallt eine glühende
/// Abrissbirne in die Steine. Jeder Abpraller feuert zwei Leuchtspur-Salven aus den Endkappen (Raptor-Gruß).
final class AbrissRound: ArcadeBase, ArcadeRound {
    let kind = PowerUp.abriss
    var hint: String { "ZIEHEN ZUM STEUERN" }
    var isFinished: Bool { timeLeft <= 0 || remaining == 0 }

    private let ball: SKSpriteNode
    private let tracer: SKTexture
    private var ballPos = CGPoint.zero
    private var velocity = CGVector.zero
    private var attached = true
    private var attachTimer = 0.9
    private var trailTimer = 0.0
    private var streak = 0
    private var ballShown = false
    private let radius: CGFloat = 2.5
    private let halfWidth: CGFloat = 13
    /// Flaches Dach des Gliders: davon prallt die Birne ab.
    private var paddleTop: CGFloat { craft.top }
    private var speed: CGFloat { min(230, 125 + CGFloat(hits) * 3) }

    private static let words = ["KRACH!", "ZACK!", "BUMM!", "WUMMS!", "PENG!"]

    init(host: ArcadeHost) {
        let orb = SKSpriteNode(texture: ArcadeArt.ball(), size: CGSize(width: 5, height: 5))
        orb.zPosition = 4
        var c = PixelCanvas(width: 1, height: 3)
        c.set(0, 0, .white)
        c.set(0, 1, RGBA(hex: 0xFFB347))
        c.set(0, 2, RGBA(hex: 0xE0452B))
        ball = orb
        tracer = c.texture()
        let spec = ArcadeCraft.Spec(texture: ArcadeArt.glider(), size: CGSize(width: 27, height: 14), runnerRow: 3,
                                    nozzleRow: 5.5, hoverX: [-5, -4, 4, 5], neon: false)
        super.init(host: host, duration: PowerUp.abriss.arcadeDuration, craft: spec, hover: 3)
        let ballGlow = glowSprite(RGBA(hex: 0xFF8A3D).skColor, size: 24, alpha: 0.65)
        ballGlow.zPosition = -1
        ballGlow.run(.repeatForever(.sequence([.scale(to: 1.2, duration: 0.15), .scale(to: 1, duration: 0.15)])))
        ball.addChild(ballGlow)
        node.addChild(ball)
        attachBall()
        ball.alpha = 0
    }

    func release() {
        if attached && !runner.isHidden { launch() }
    }

    private func attachBall() {
        attached = true
        attachTimer = 0.9
        ballPos = CGPoint(x: runnerX, y: paddleTop + radius + 1)
        ball.position = ballPos
        ball.alpha = 1
    }

    private func launch() {
        attached = false
        let angle = CGFloat.random(in: -0.45...0.45)
        velocity = CGVector(dx: sin(angle) * speed, dy: cos(angle) * speed)
        host.sound(.paddle, 0.6, 0)
        craft.dip(1)
    }

    func update(_ dt: Double) {
        elapsed += dt
        timeLeft -= dt
        // Die Birne erscheint erst, wenn die Runde läuft (nicht schon beim Aufsteigen)
        if !ballShown {
            ballShown = true
            ball.alpha = 1
        }
        moveCraft(dt, maxSpeed: 520, stiffness: 32, response: 45)

        if attached {
            ballPos = CGPoint(x: runnerX, y: paddleTop + radius + 1)
            attachTimer -= dt
            if attachTimer <= 0 { launch() }
        } else {
            moveBall(CGFloat(dt))
        }
        ball.position = CGPoint(x: ballPos.x.rounded(), y: ballPos.y.rounded())

        // Glühende Spur
        trailTimer -= dt
        if !attached && trailTimer <= 0 {
            trailTimer = 0.025
            let ghost = glowSprite(RGBA(hex: 0xFF4FA8).skColor, size: 9, alpha: 0.6)
            ghost.position = ballPos
            node.addChild(ghost)
            ghost.run(.sequence([.group([.fadeOut(withDuration: 0.3), .scale(to: 0.3, duration: 0.3)]), .removeFromParent()]))
        }
        updateShots(dt)
    }

    private func moveBall(_ dt: CGFloat) {
        let distance = (velocity.dx * velocity.dx + velocity.dy * velocity.dy).squareRoot() * dt
        let steps = max(1, Int(ceil(distance / 1.5)))
        let h = dt / CGFloat(steps)
        let b = host.board
        for _ in 0..<steps {
            var nx = ballPos.x + velocity.dx * h
            var ny = ballPos.y + velocity.dy * h
            // Wände links, rechts, oben
            if nx - radius < b.minX { nx = b.minX + radius; velocity.dx = abs(velocity.dx); wallSpark(CGPoint(x: b.minX, y: ny)) }
            if nx + radius > b.maxX { nx = b.maxX - radius; velocity.dx = -abs(velocity.dx); wallSpark(CGPoint(x: b.maxX, y: ny)) }
            if ny + radius > b.maxY { ny = b.maxY - radius; velocity.dy = -abs(velocity.dy); wallSpark(CGPoint(x: nx, y: b.maxY)) }
            // Steine: waagerecht und senkrecht getrennt prüfen, damit der Abprall stimmt
            var bounced = false
            if let p = cell(at: CGPoint(x: nx + (velocity.dx > 0 ? radius : -radius), y: ballPos.y)) {
                smashBrick(p)
                velocity.dx = -velocity.dx
                nx = ballPos.x
                bounced = true
            }
            if let p = cell(at: CGPoint(x: ballPos.x, y: ny + (velocity.dy > 0 ? radius : -radius))) {
                smashBrick(p)
                velocity.dy = -velocity.dy
                ny = ballPos.y
                bounced = true
            }
            if bounced { normalize() }
            // Glider: flaches Dach
            if velocity.dy < 0, ny - radius <= paddleTop, ny - radius >= paddleTop - 5, abs(nx - runnerX) <= halfWidth + radius {
                bounceOffBar(at: nx)
                ny = paddleTop + radius
            }
            ballPos = CGPoint(x: nx, y: ny)
            if ballPos.y < host.groundY - 6 {
                loseBall()
                return
            }
        }
    }

    /// Mindeststeigung, damit die Birne nicht ewig waagerecht pendelt; Tempo steigt mit den Treffern.
    private func normalize() {
        let s = speed
        var vx = velocity.dx, vy = velocity.dy
        let len = max(0.001, (vx * vx + vy * vy).squareRoot())
        vx /= len
        vy /= len
        if abs(vy) < 0.35 {
            vy = vy < 0 ? -0.35 : 0.35
            vx = (vx < 0 ? -1 : 1) * (1 - vy * vy).squareRoot()
        }
        velocity = CGVector(dx: vx * s, dy: vy * s)
    }

    private func smashBrick(_ p: Pos) {
        guard hit(p) else { return }
        streak += 1
        host.sound(.brick, 0.6, Double(min(streak, 12)))
        if streak % 4 == 0 {
            host.shake(2)
            onomatopoeia(Self.words.randomElement()!, at: host.center(p), color: RGBA(hex: 0xFFB347))
        }
    }

    private func wallSpark(_ p: CGPoint) {
        host.fx.flash(at: p, color: RGBA(hex: 0xFF8A3D).skColor)
        host.sound(.paddle, 0.25, -7)
    }

    private func bounceOffBar(at x: CGFloat) {
        let offset = max(-1, min(1, (x - runnerX) / halfWidth))
        let angle = offset * 1.05
        let s = speed
        velocity = CGVector(dx: sin(angle) * s, dy: cos(angle) * s)
        streak = 0
        host.sound(.paddle, 0.6, Double(offset * 4))
        host.fx.flash(at: CGPoint(x: x, y: paddleTop), color: RGBA(hex: 0x3FD8FF).skColor)
        host.tick()
        craft.dip(2)
        if Int.random(in: 0..<4) == 0 {
            onomatopoeia("カーン!", at: CGPoint(x: x, y: paddleTop + 16), color: RGBA(hex: 0x3FD8FF))
        }
        // Salve aus beiden Dachkanten
        for side: CGFloat in [-12, 12] {
            fire(from: CGPoint(x: runnerX + side, y: paddleTop + 1), texture: tracer, size: CGSize(width: 1, height: 3), glow: RGBA(hex: 0xFFB347).skColor, speed: 260)
        }
        host.sound(.laser, 0.25, -5)
    }

    private func loseBall() {
        host.fx.explosion(at: CGPoint(x: ballPos.x, y: host.groundY), scale: 0.8)
        host.sound(.invalid, 0.5, 0)
        host.shake(1)
        ball.alpha = 0
        attached = true
        attachTimer = 10
        streak = 0
        node.run(.sequence([.wait(forDuration: 0.5), .run { [weak self] in self?.attachBall() }]))
    }
}

// MARK: - Manga-Filter

/// Harter Schwarz-Weiß-Look (Graustufen, dann Schwelle), wahlweise invertiert. Für den Auftakt der Minispiele.
final class MangaFilter: CIFilter {
    @objc dynamic var inputImage: CIImage?
    var inverted = false

    override var outputImage: CIImage? {
        guard let image = inputImage else { return nil }
        let gray = image.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0, kCIInputContrastKey: 1.5, kCIInputBrightnessKey: 0.06,
        ])
        var result = gray.applyingFilter("CIColorThreshold", parameters: ["inputThreshold": 0.2])
        if inverted { result = result.applyingFilter("CIColorInvert") }
        return result
    }
}
