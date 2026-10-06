import CoreImage
import RaptCore
import SpriteKit

// Minispiele, die ein Power-up auslöst: Invasion (nach Space Invaders) und Abrissbirne (nach Arkanoid,
// mit einer Metallstange im Raptor-Look als Schläger). In beiden steuert man den Läufer von den Dächern. Die Runden kennen die Szene nur über `ArcadeHost`;
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
    /// Läufer fällt von oben in die Bahn (Endlos). Im Dächerlauf springt er vorher selbst vom Dach hinein.
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
    /// Wo der Läufer gerade steht (für den Rücksprung aufs Dach).
    var runnerPosition: CGPoint { get }
}

/// Gemeinsames: Treffer zählen, Schüsse von unten, Lautmalerei-Einblendungen.
class ArcadeBase {
    let host: ArcadeHost
    let node = SKNode()
    private(set) var cleared: Set<Pos> = []
    var timeLeft: Double
    var elapsed = 0.0
    var hits = 0

    /// Der Läufer in der Bahn; `runnerX` ist seine Position, `runnerTarget` die des Fingers.
    let runner: SKSpriteNode
    var runnerX: CGFloat
    var runnerTarget: CGFloat
    var runnerPosition: CGPoint { runner.position }

    struct Shot {
        let sprite: SKSpriteNode
        var x: CGFloat
        var y: CGFloat
        let speed: CGFloat
    }

    var shots: [Shot] = []

    init(host: ArcadeHost, duration: Double) {
        self.host = host
        timeLeft = duration
        let mid = host.board.midX
        runnerX = mid
        runnerTarget = mid
        runner = SKSpriteNode(texture: host.figure.idle[0], size: CGSize(width: 7, height: 10))
        runner.anchorPoint = CGPoint(x: 0.5, y: 0)
        runner.zPosition = 2
        let aura = glowSprite(RGBA(hex: 0x3FD8FF).skColor, size: 20, alpha: 0.45)
        aura.position = CGPoint(x: 0, y: 6)
        aura.zPosition = -1
        runner.addChild(aura)
        node.addChild(runner)
        runner.position = CGPoint(x: mid, y: host.groundY)
        if host.entrance {
            runner.position.y = host.groundY + 40
            runner.run(.move(to: CGPoint(x: mid, y: host.groundY), duration: 0.2))
            host.fx.steam(at: CGPoint(x: mid, y: host.groundY + 2))
        }
    }

    func pointer(_ px: CGFloat) {
        runnerTarget = min(host.board.maxX - 4, max(host.board.minX + 4, px))
    }

    /// Läufer rennt zum Finger. Gibt zurück, ob er sich bewegt hat und in welche Richtung.
    @discardableResult
    func moveRunner(_ dt: Double, speed: CGFloat, margin: CGFloat = 4) -> CGFloat {
        let target = min(host.board.maxX - margin, max(host.board.minX + margin, runnerTarget))
        let dx = target - runnerX
        let step = min(abs(dx), speed * CGFloat(dt))
        guard step > 0.01 else { return 0 }
        runnerX += dx > 0 ? step : -step
        runner.position.x = runnerX.rounded()
        return dx > 0 ? 1 : -1
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
        node.removeFromParent()
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
    private var stepTimer = 0.0
    private var frame = 0
    private var stun = 0.0
    private var marchTimer = 0.3
    private var marchStep = 0
    private var dropTimer = 1.2
    private var drops: [(sprite: SKSpriteNode, color: SKColor, x: CGFloat, y: CGFloat)] = []
    private var ufo: (sprite: SKSpriteNode, x: CGFloat, dir: CGFloat)?
    private var ufoTimes = [2.2, 5.6]
    private var ufoSoundTimer = 0.0

    init(host: ArcadeHost) {
        super.init(host: host, duration: PowerUp.invasion.arcadeDuration)
    }

    func release() {}

    func update(_ dt: Double) {
        elapsed += dt
        timeLeft -= dt

        // Läufer rennt zum Finger
        let dir = moveRunner(dt, speed: 150)
        if dir != 0 {
            runner.xScale = dir
            stepTimer -= dt
            if stepTimer <= 0 {
                stepTimer = 0.09
                frame = (frame + 1) % host.figure.idle.count
                runner.texture = host.figure.idle[frame]
            }
        }
        let x = runnerX

        // Lähmung nach Treffer: flackern, nicht schießen
        if stun > 0 {
            stun -= dt
            runner.alpha = Int(stun * 20) % 2 == 0 ? 0.3 : 1
            if stun <= 0 { runner.alpha = 1 }
        } else {
            fireTimer -= dt
            if fireTimer <= 0 {
                fireTimer = 0.16
                let muzzle = CGPoint(x: x, y: host.groundY + 11)
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
            if stun <= 0, abs(d.x - x) < 5, d.y < host.groundY + 10, d.y > host.groundY {
                stun = 0.8
                host.fx.flash(at: CGPoint(x: x, y: host.groundY + 5), color: RGBA(hex: 0xE0452B).skColor)
                host.fx.shrapnel(at: CGPoint(x: x, y: host.groundY + 5), colors: [.white, RGBA(hex: 0x3FD8FF).skColor], count: 8, power: 0.6, bounces: false)
                host.sound(.invalid, 0.5, 0)
                host.shake(1)
                onomatopoeia("AUA!", at: CGPoint(x: x, y: host.groundY + 22), color: RGBA(hex: 0xE0452B))
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

    private let bar: SKSpriteNode
    private let ball: SKSpriteNode
    private let tracer: SKTexture
    private var ballPos = CGPoint.zero
    private var velocity = CGVector.zero
    private var attached = true
    private var attachTimer = 0.7
    private var trailTimer = 0.0
    private var bobTimer = 0.0
    /// Die Stange federt nach einem Abpraller kurz nach unten.
    private var kick: CGFloat = 0
    private var streak = 0
    private let radius: CGFloat = 2.5
    private let halfWidth: CGFloat = 12
    /// Mitte der Stange: liegt auf den hochgereckten Händen des Läufers.
    private var barY: CGFloat { host.groundY + 12 }
    private var paddleTop: CGFloat { barY + 2 }
    private var speed: CGFloat { min(230, 125 + CGFloat(hits) * 3) }

    private static let words = ["KRACH!", "ZACK!", "BUMM!", "WUMMS!", "PENG!"]

    init(host: ArcadeHost) {
        let rod = SKSpriteNode(texture: ArcadeArt.bar(), size: CGSize(width: 24, height: 4))
        rod.zPosition = 3
        let orb = SKSpriteNode(texture: ArcadeArt.ball(), size: CGSize(width: 5, height: 5))
        orb.zPosition = 4
        var c = PixelCanvas(width: 1, height: 3)
        c.set(0, 0, .white)
        c.set(0, 1, RGBA(hex: 0xFFB347))
        c.set(0, 2, RGBA(hex: 0xE0452B))
        bar = rod
        ball = orb
        tracer = c.texture()
        super.init(host: host, duration: PowerUp.abriss.arcadeDuration)
        // Arme hoch: der Läufer stemmt die Stange
        runner.texture = host.figure.jump
        let stripGlow = glowSprite(RGBA(hex: 0x3FD8FF).skColor, size: 30, alpha: 0.4)
        stripGlow.yScale = 0.35
        stripGlow.zPosition = -1
        bar.addChild(stripGlow)
        let ballGlow = glowSprite(RGBA(hex: 0xFF8A3D).skColor, size: 24, alpha: 0.65)
        ballGlow.zPosition = -1
        ballGlow.run(.repeatForever(.sequence([.scale(to: 1.2, duration: 0.15), .scale(to: 1, duration: 0.15)])))
        ball.addChild(ballGlow)
        node.addChild(bar)
        node.addChild(ball)
        // Die Stange fällt dem Läufer von oben in die Hände
        bar.position = CGPoint(x: runnerX, y: barY + 30)
        bar.run(.move(to: CGPoint(x: runnerX, y: barY), duration: 0.2))
        attachBall()
    }

    func release() {
        if attached { launch() }
    }

    private func attachBall() {
        attached = true
        attachTimer = 0.7
        ballPos = CGPoint(x: runnerX, y: paddleTop + radius + 1)
        ball.position = ballPos
        ball.alpha = 1
    }

    private func launch() {
        attached = false
        let angle = CGFloat.random(in: -0.45...0.45)
        velocity = CGVector(dx: sin(angle) * speed, dy: cos(angle) * speed)
        host.sound(.paddle, 0.6, 0)
    }

    func update(_ dt: Double) {
        elapsed += dt
        timeLeft -= dt

        // Rennen mit leichtem Wippen; die Stange folgt dem Läufer
        let dir = moveRunner(dt, speed: 300, margin: halfWidth)
        var bob: CGFloat = 0
        if dir != 0 {
            runner.xScale = dir
            bobTimer += dt
            bob = Int(bobTimer * 12) % 2 == 0 ? 0 : 1
        }
        runner.position.y = host.groundY + bob
        kick = max(0, kick - 30 * CGFloat(dt))
        if !bar.hasActions() {
            bar.position = CGPoint(x: runnerX.rounded(), y: barY + bob - kick.rounded())
        }

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
            // Stange: glatte Oberseite
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
        kick = 2
        if Int.random(in: 0..<4) == 0 {
            onomatopoeia("カーン!", at: CGPoint(x: x, y: paddleTop + 16), color: RGBA(hex: 0x3FD8FF))
        }
        // Salve aus beiden Endkappen
        for side: CGFloat in [-11, 11] {
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
