import RaptCore
import SpriteKit
#if os(iOS)
import UIKit
#endif

struct ScreenInsets: Equatable {
    var top: CGFloat = 0
    var left: CGFloat = 0
    var bottom: CGFloat = 0
    var right: CGFloat = 0
}

/// Spielszene im Neo-Pixel-Stil. Alles wird in einem festen Design-Raster von 200×373 Kunst-Pixeln
/// gebaut und ganzzahlig auf echte Bildschirmpixel hochskaliert. Weiches Licht rendert SpriteKit
/// dabei automatisch in voller Auflösung.
final class GameScene: SKScene {
    private enum Layout {
        static let width: CGFloat = 200
        static let height: CGFloat = 373
        static let tile = GemArt.tile
        static let count = 8
        static let boardX = 12
        static let boardY = 96
        static var boardSize: Int { tile * count }
        static var planY: Int { boardY + boardSize + 10 }
        static var slotY: Int { planY + 10 }
        static let slotSize = 20
        static func slotX(_ i: Int) -> Int { boardX + i * (slotSize + 2) }
    }

    private enum Palette {
        static let amber = RGBA(hex: 0xFFB347)
        static let red = RGBA(hex: 0xE0452B)
        static let label = RGBA(hex: 0x9A9CAB)
        static let cream = RGBA(hex: 0xFFF3D6)
    }

    var safeInsets = ScreenInsets() {
        didSet { if safeInsets != oldValue { layoutWorld() } }
    }

    private var game = Game(seed: UInt64.random(in: 0...UInt64.max), mode: GameScene.savedMode)
    private let audio = AudioCenter.shared.effects
    private let haptics = Haptics.shared
    private let fx = Effects()

    private let world = SKNode()
    private let shaker = SKNode()
    private let backLayer = SKNode()
    private let hudLayer = SKNode()
    private let boardCrop = SKCropNode()
    private let gemLayer = SKNode()
    private let glowLayer = SKNode()
    private let overlayLayer = SKNode()
    private let cursor = SKNode()
    private let hintCursor = SKNode()

    private let nebula = SKSpriteNode()
    private let skyline = SKSpriteNode()
    private let beacon = SKSpriteNode(color: SKColor(red: 1, green: 0.23, blue: 0.16, alpha: 1), size: CGSize(width: 1, height: 1))
    private var beaconGlow: SKSpriteNode?
    private var stars: [SKSpriteNode] = []

    private let scoreLabel = SKSpriteNode()
    private let comboLabel = SKSpriteNode()
    private let recordLabel = SKSpriteNode()
    private let planLabel = SKSpriteNode()
    private var planSegments: [SKSpriteNode] = []

    private var sprites: [Gem: GemArt.Sprite] = [:]
    private var glowTexture = SKTexture()
    private var gems: [Pos: GemNode] = [:]

    private var displayedScore = 0.0
    private var shownScore = -1
    private var shownPlan = 0
    private var lastCombo = 1
    private var mode = GameScene.savedMode
    private var highscore = Highscore.load(GameScene.savedMode)
    private var busy = false
    private var selected: Pos?
    private var pointerStart: (pos: Pos, point: CGPoint)?
    private var idleTime: TimeInterval = 0
    private var lastUpdate: TimeInterval = 0
    private var clock: TimeInterval = 0
    private var backdropKey = ""
    private var isBuilt = false

    // Power-ups
    private enum Armed { case bomb, atom, purge }

    private struct Direction: Equatable {
        let dc: Int
        let dr: Int
    }

    private struct FresserState {
        let round: FresserRound
        let node: SKSpriteNode
        var pos: Pos
        var dir = Direction(dc: 1, dr: 0)
        var queued: Direction?
        var eaten: Set<Pos> = []
        var timeLeft = FresserRound.duration
        var stepTimer = 0.2
        var shownSeconds = -1
    }

    private var lineOverlays: [Bool: SKTexture] = [:]
    private var lineFlames: [String: [SKTexture]] = [:]
    private var bombOverlay = SKTexture()
    private var hyperFrames: [SKTexture] = []
    private var splash: SplashPresenter!
    private var settingsPanel: SettingsPanel!
    private var helpPanel: HelpPanel!
    /// Roter Rahmen am Bildschirmrand bei Absturzgefahr (in Bildschirmkoordinaten, nicht skaliert).
    private let edgeGlow = SKNode()
    private var edgeSprites: [SKSpriteNode] = []
    private var musicDuck: Float = 1
    /// Zahnrad auf der Punkteplatte (Design-Koordinaten, großzügige Trefferfläche).
    private let gearRect = CGRect(x: 172, y: 4, width: 22, height: 20)
    private var armed: Armed?
    private var armedSlot = 0
    private var fresser: FresserState?
    private var swipeStart: CGPoint?
    private var stoneTextures: [Gem: SKTexture] = [:]
    private var iconTextures: [PowerUp: SKTexture] = [:]
    private var chomperFrames: [SKTexture] = []
    private var slotIcons: [SKSpriteNode] = []
    private let armedBracket = SKNode()
    private let statusLabel = SKSpriteNode()
    private let countdownLabel = SKSpriteNode()
    private var statusText = ""

    // Figur auf den Dächern
    private let figure = SKSpriteNode()
    private var figureIdle: [SKTexture] = []
    private var figureJump = SKTexture()
    private let dangerAura = SKSpriteNode()
    private var figureJumping = false
    /// Haus, auf dem die Figur sichtbar steht. Die Spiellogik springt sofort, die Szene erst mit der Animation.
    private var shownBuilding = 0
    private var figureFalling = false
    private var wasInDanger = false

    // Stadt
    private var buildingSprites: [Int: SKSpriteNode] = [:]
    private var visibleLeft: CGFloat = 0
    private var visibleRight: CGFloat = Layout.width
    private var skyBottom: CGFloat = Layout.height
    private var visibleTop: CGFloat = 0
    private var windowTimer: TimeInterval = 4
    private var shootingStarTimer: TimeInterval = 15

    // Menü (Moduswahl, Spielende)
    private var menuButtons: [(rect: CGRect, mode: GameMode)] = []
    private var menuSettingsRect = CGRect.zero
    private var menuVisible = false
    private var slotFrames: [SKSpriteNode] = []
    /// Power-ups, die schon im Lager sind, aber noch per Übergabe einfliegen.
    private var pendingDeliveries = 0

    private static var savedMode: GameMode {
        GameMode(rawValue: UserDefaults.standard.string(forKey: "rapt.mode") ?? "") ?? .endless
    }
    // MARK: Lebenszyklus

    override func didMove(to view: SKView) {
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.027, green: 0.024, blue: 0.05, alpha: 1)
        if !isBuilt {
            build()
            isBuilt = true
            startNewGame(mode: mode, animated: true)
            showMenu(gameOver: false)
        }
        layoutWorld()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        layoutWorld()
    }

    // MARK: Koordinaten

    /// Design-Koordinate (oben links, y nach unten) → Weltkoordinate (y nach oben).
    private func design(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x, y: Layout.height - y)
    }

    private func design(_ x: Int, _ y: Int) -> CGPoint {
        design(CGFloat(x), CGFloat(y))
    }

    private func center(of p: Pos) -> CGPoint {
        let half = CGFloat(Layout.tile) / 2
        return design(CGFloat(Layout.boardX + p.col * Layout.tile) + half, CGFloat(Layout.boardY + p.row * Layout.tile) + half)
    }

    private func cell(at point: CGPoint) -> Pos? {
        let x = point.x - CGFloat(Layout.boardX)
        let y = (Layout.height - point.y) - CGFloat(Layout.boardY)
        let p = Pos(Int(floor(x / CGFloat(Layout.tile))), Int(floor(y / CGFloat(Layout.tile))))
        return game.board.contains(p) ? p : nil
    }

    private var pixelScale: CGFloat {
        #if os(iOS)
        let scale = view?.traitCollection.displayScale ?? 3
        return scale > 0 ? scale : 3
        #else
        return view?.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        #endif
    }

    // MARK: Aufbau

    private func pixelSprite(_ canvas: PixelCanvas, topLeft: CGPoint) -> SKSpriteNode {
        let node = SKSpriteNode(texture: canvas.texture(), size: canvas.size)
        node.anchorPoint = CGPoint(x: 0, y: 1)
        node.position = topLeft
        return node
    }

    private func setText(_ node: SKSpriteNode, _ text: String, color: RGBA, scale: CGFloat = 1) {
        let canvas = PixelFont.render(text, color: color)
        node.texture = canvas.texture()
        node.size = CGSize(width: CGFloat(canvas.width) * scale, height: CGFloat(canvas.height) * scale)
    }

    private func build() {
        for gem in Gem.allCases {
            sprites[gem] = GemArt.makeSprite(gem)
            stoneTextures[gem] = GemArt.makeSprite(gem, petrified: true).texture
        }
        for kind in PowerUp.allCases { iconTextures[kind] = PowerUpArt.icon(kind) }
        lineOverlays = [true: SpecialArt.lineOverlay(horizontal: true), false: SpecialArt.lineOverlay(horizontal: false)]
        bombOverlay = SpecialArt.bombOverlay()
        hyperFrames = SpecialArt.hyperFrames()
        chomperFrames = PowerUpArt.chomperFrames()
        let frames = PowerUpArt.figureFrames()
        figureIdle = frames.idle
        figureJump = frames.jump
        glowTexture = Backdrop.glow()

        addChild(world)
        world.addChild(shaker)
        let layers: [(SKNode, CGFloat)] = [
            (backLayer, 0), (hudLayer, 10), (boardCrop, 20), (glowLayer, 25),
            (fx.pixelLayer, 30), (fx.lightLayer, 40), (hintCursor, 44), (cursor, 45), (overlayLayer, 50),
        ]
        for (layer, z) in layers {
            layer.zPosition = z
            shaker.addChild(layer)
        }

        // Hintergrund (Inhalt entsteht in rebuildBackdrop, sobald die Fenstergröße feststeht)
        nebula.anchorPoint = CGPoint(x: 0, y: 1)
        skyline.anchorPoint = CGPoint(x: 0, y: 0)
        skyline.zPosition = 2
        beacon.anchorPoint = CGPoint(x: 0, y: 1)
        beacon.zPosition = 3
        backLayer.addChild(nebula)
        backLayer.addChild(skyline)
        backLayer.addChild(beacon)
        figure.texture = figureIdle[0]
        figure.size = CGSize(width: 7, height: 10)
        figure.anchorPoint = CGPoint(x: 0.5, y: 0)
        figure.zPosition = 4
        let aura = SKSpriteNode(texture: glowTexture, color: RGBA(hex: 0x3FD8FF).skColor, size: CGSize(width: 18, height: 18))
        aura.colorBlendFactor = 1
        aura.blendMode = .add
        aura.alpha = 0.35
        aura.position = CGPoint(x: 0, y: 6)
        aura.zPosition = 1
        aura.run(.repeatForever(.sequence([.fadeAlpha(to: 0.5, duration: 0.8), .fadeAlpha(to: 0.25, duration: 0.8)])))
        figure.addChild(aura)
        dangerAura.texture = glowTexture
        dangerAura.color = Palette.red.skColor
        dangerAura.colorBlendFactor = 1
        dangerAura.blendMode = .add
        dangerAura.size = CGSize(width: 30, height: 30)
        dangerAura.position = CGPoint(x: 0, y: 5)
        dangerAura.zPosition = 2
        dangerAura.alpha = 0
        figure.addChild(dangerAura)
        backLayer.addChild(figure)
        startFigureIdle()
        let blink = SKAction.repeatForever(.sequence([
            .fadeAlpha(to: 1, duration: 0), .wait(forDuration: 0.7),
            .fadeAlpha(to: 0.2, duration: 0), .wait(forDuration: 0.7),
        ]))
        beacon.run(blink)

        // Punkteanzeige und Brett
        hudLayer.addChild(pixelSprite(Backdrop.hudPlate(), topLeft: design(8, 10)))
        hudLayer.addChild(pixelSprite(Backdrop.boardFrame(tile: Layout.tile, count: Layout.count),
                                      topLeft: design(Layout.boardX - 6, Layout.boardY - 6)))
        let planY = Layout.planY
        let labels: [(SKSpriteNode, CGPoint, CGPoint)] = [
            (scoreLabel, CGPoint(x: 0, y: 1), design(24, 33)),
            (comboLabel, CGPoint(x: 1, y: 1), design(176, 33)),
            (recordLabel, CGPoint(x: 1, y: 1), design(177, 17)),
            (planLabel, CGPoint(x: 0, y: 1), design(Layout.boardX, planY)),
        ]
        for (label, anchor, position) in labels {
            label.anchorPoint = anchor
            label.position = position
            label.zPosition = 1
            hudLayer.addChild(label)
        }
        let scoreGlow = SKSpriteNode(texture: glowTexture, color: Palette.amber.skColor, size: CGSize(width: 110, height: 34))
        scoreGlow.colorBlendFactor = 1
        scoreGlow.blendMode = .add
        scoreGlow.alpha = 0.28
        scoreGlow.position = design(55, 38)
        glowLayer.addChild(scoreGlow)

        // Plan-Leiste
        let barStart = Layout.boardX + PixelFont.width("SPRUNG 00") + 5
        let barEnd = Layout.boardX + Layout.boardSize
        let bar = SKSpriteNode(color: RGBA(hex: 0x0B0A11).skColor, size: CGSize(width: barEnd - barStart, height: 7))
        bar.anchorPoint = CGPoint(x: 0, y: 1)
        bar.position = design(barStart, planY - 1)
        hudLayer.addChild(bar)
        var x = barStart + 1
        while x + 3 <= barEnd - 1 {
            let seg = SKSpriteNode(color: RGBA(hex: 0x221E2A).skColor, size: CGSize(width: 3, height: 5))
            seg.anchorPoint = CGPoint(x: 0, y: 1)
            seg.position = design(x, planY)
            seg.zPosition = 1
            hudLayer.addChild(seg)
            planSegments.append(seg)
            x += 4
        }

        // Steine liegen in einer Maske, damit nachrutschende Steine hinter der Brettkante auftauchen
        let mask = SKSpriteNode(color: .white, size: CGSize(width: Layout.boardSize, height: Layout.boardSize))
        mask.anchorPoint = CGPoint(x: 0, y: 1)
        mask.position = design(Layout.boardX, Layout.boardY)
        boardCrop.maskNode = mask
        boardCrop.addChild(gemLayer)
        fx.floorY = Layout.height - CGFloat(Layout.boardY + Layout.boardSize)

        // Lager für Power-ups unter der Plan-Leiste
        let frameTexture = PowerUpArt.slotFrame().texture()
        for i in 0..<Game.maxPowerUps {
            let frame = SKSpriteNode(texture: frameTexture, size: CGSize(width: Layout.slotSize, height: Layout.slotSize))
            frame.anchorPoint = CGPoint(x: 0, y: 1)
            frame.position = design(Layout.slotX(i), Layout.slotY)
            hudLayer.addChild(frame)
            slotFrames.append(frame)
            let icon = SKSpriteNode()
            icon.size = CGSize(width: 16, height: 16)
            icon.anchorPoint = CGPoint(x: 0, y: 1)
            icon.position = design(Layout.slotX(i) + 2, Layout.slotY + 2)
            icon.zPosition = 1
            icon.isHidden = true
            hudLayer.addChild(icon)
            slotIcons.append(icon)
        }
        statusLabel.anchorPoint = CGPoint(x: 0, y: 1)
        statusLabel.position = design(Layout.slotX(Game.maxPowerUps) + 3, Layout.slotY + 8)
        statusLabel.zPosition = 1
        hudLayer.addChild(statusLabel)
        countdownLabel.anchorPoint = CGPoint(x: 0.5, y: 1)
        countdownLabel.position = design(Layout.boardX + Layout.boardSize / 2, Layout.boardY + 6)
        countdownLabel.isHidden = true
        overlayLayer.addChild(countdownLabel)

        buildBracket(cursor, color: RGBA(hex: 0xFFD27A).skColor)
        buildBracket(hintCursor, color: RGBA(hex: 0x9FB4FF).skColor)
        splash = SplashPresenter(topLeft: design(8, 10), width: 184, height: 68)
        splash.onSpeak = { [weak self] contact in
            AudioCenter.shared.speak(contact)
            self?.haptics.select()
        }
        shaker.addChild(splash.node)

        // Einstellungen als Pixel-Ansicht, Zahnrad auf der Punkteplatte
        settingsPanel = SettingsPanel(designHeight: Layout.height)
        settingsPanel.node.zPosition = 80
        settingsPanel.onClose = { [weak self] in self?.settingsPanel.hide() }
        settingsPanel.onNewGame = { [weak self] in
            guard let self else { return }
            self.settingsPanel.hide()
            self.showMenu(gameOver: false)
        }
        settingsPanel.onChange = { [weak self] in
            guard let self else { return }
            self.audio.play(.select, volume: 0.5)
            self.game.citySpeed = GameSettings.shared.citySpeed
            self.game.cityAcceleration = GameSettings.shared.cityAcceleration
            if !GameSettings.shared.hintsEnabled { self.place(self.hintCursor, at: nil) }
        }
        shaker.addChild(settingsPanel.node)
        helpPanel = makeHelpPanel()
        helpPanel.node.zPosition = 85
        helpPanel.onClose = { [weak self] in
            self?.audio.play(.select, volume: 0.5)
            self?.helpPanel.hide()
        }
        settingsPanel.onHelp = { [weak self] in self?.helpPanel.show() }
        shaker.addChild(helpPanel.node)

        // Roter Rahmen um das ganze Display
        let horizontal = Backdrop.edgeGradient(vertical: false), vertical = Backdrop.edgeGradient(vertical: true)
        for (texture, flip) in [(horizontal, false), (horizontal, true), (vertical, false), (vertical, true)] {
            let edge = SKSpriteNode(texture: texture)
            edge.color = Palette.red.skColor
            edge.colorBlendFactor = 1
            edge.blendMode = .add
            if texture === horizontal {
                edge.anchorPoint = CGPoint(x: 0, y: 0.5)
                if flip { edge.xScale = -1 }
            } else {
                edge.anchorPoint = CGPoint(x: 0.5, y: 0)
                if flip { edge.yScale = -1 }
            }
            edgeGlow.addChild(edge)
            edgeSprites.append(edge)
        }
        edgeGlow.zPosition = 200
        edgeGlow.alpha = 0
        addChild(edgeGlow)
        // Zahnrad mittig auf der Zeile der Hochpunkte (Text 5 px ab y 17, Zahnrad 7 px ab y 16)
        let gear = pixelSprite(Self.gearCanvas(Palette.label), topLeft: design(182, 16))
        gear.zPosition = 2
        hudLayer.addChild(gear)

        buildBracket(armedBracket, color: RGBA(hex: 0xFF6A3D).skColor, size: Layout.slotSize)
        armedBracket.zPosition = 46
        shaker.addChild(armedBracket)
    }

    private func buildBracket(_ node: SKNode, color: SKColor, size: Int = Layout.tile) {
        let t = size
        let rects: [(Int, Int, Int, Int)] = [
            (0, 0, 3, 1), (0, 0, 1, 3), (t - 3, 0, 3, 1), (t - 1, 0, 1, 3),
            (0, t - 1, 3, 1), (0, t - 3, 1, 3), (t - 3, t - 1, 3, 1), (t - 1, t - 3, 1, 3),
        ]
        for r in rects {
            let s = SKSpriteNode(color: color, size: CGSize(width: r.2, height: r.3))
            s.anchorPoint = CGPoint(x: 0, y: 1)
            s.position = CGPoint(x: r.0, y: -r.1)
            node.addChild(s)
        }
        node.isHidden = true
        node.run(.repeatForever(.sequence([
            .fadeAlpha(to: 1, duration: 0), .wait(forDuration: 0.14),
            .fadeAlpha(to: 0.3, duration: 0), .wait(forDuration: 0.14),
        ])))
    }

    private func place(_ node: SKNode, at p: Pos?) {
        guard let p else {
            node.isHidden = true
            return
        }
        node.position = design(Layout.boardX + p.col * Layout.tile, Layout.boardY + p.row * Layout.tile)
        node.isHidden = false
    }

    // MARK: Layout

    /// Skaliert das Design-Raster ganzzahlig auf echte Pixel und zentriert es im sicheren Bereich.
    private func layoutWorld() {
        guard isBuilt, size.width > 1, size.height > 1 else { return }
        // Roter Rahmen: links, rechts, unten, oben
        let band = min(size.width, size.height) * 0.14
        if edgeSprites.count == 4 {
            edgeSprites[0].size = CGSize(width: band, height: size.height)
            edgeSprites[0].position = CGPoint(x: 0, y: size.height / 2)
            edgeSprites[1].size = CGSize(width: band, height: size.height)
            edgeSprites[1].position = CGPoint(x: size.width, y: size.height / 2)
            edgeSprites[2].size = CGSize(width: size.width, height: band)
            edgeSprites[2].position = CGPoint(x: size.width / 2, y: 0)
            edgeSprites[3].size = CGSize(width: size.width, height: band)
            edgeSprites[3].position = CGPoint(x: size.width / 2, y: size.height)
        }
        let px = pixelScale
        let availW = max(1, size.width - safeInsets.left - safeInsets.right)
        let availH = max(1, size.height - safeInsets.top - safeInsets.bottom)
        let k = max(1, floor(min(availW * px / Layout.width, availH * px / Layout.height)))
        let scale = k / px
        world.setScale(scale)
        let ox = safeInsets.left + (availW - Layout.width * scale) / 2
        let oy = safeInsets.bottom + (availH - Layout.height * scale) / 2
        world.position = CGPoint(x: (ox * px).rounded() / px, y: (oy * px).rounded() / px)

        // Sichtbarer Bereich in Design-Pixeln
        let left = Int(floor(-world.position.x / scale)) - 1
        let right = Int(ceil((size.width - world.position.x) / scale)) + 1
        let top = Int(floor(Layout.height - (size.height - world.position.y) / scale)) - 1
        let bottom = Int(ceil(Layout.height + world.position.y / scale)) + 1
        let key = "\(left),\(right),\(top),\(bottom)"
        guard key != backdropKey else { return }
        backdropKey = key

        // Beim Ziehen am Fensterrand nicht bei jedem Schritt neu rechnen
        let rebuild = SKAction.run { [weak self] in
            self?.rebuildBackdrop(left: left, right: right, top: top, bottom: bottom)
        }
        removeAction(forKey: "backdrop")
        if nebula.texture == nil {
            rebuildBackdrop(left: left, right: right, top: top, bottom: bottom)
        } else {
            run(.sequence([.wait(forDuration: 0.15), rebuild]), withKey: "backdrop")
        }
    }

    private func rebuildBackdrop(left: Int, right: Int, top: Int, bottom: Int) {
        let w = right - left, h = bottom - top
        let neb = Backdrop.nebula(width: w, height: h, originX: left, originY: top)
        nebula.texture = neb.texture()
        nebula.size = neb.size
        nebula.position = design(left, top)

        let sky = Backdrop.skyline(width: w, seed: 5)
        let skyTop = bottom - sky.canvas.height
        skyline.texture = sky.canvas.texture()
        skyline.size = sky.canvas.size
        skyline.position = design(left, bottom)
        beacon.position = design(left + sky.beacon.x, skyTop + sky.beacon.y)

        // Vordere Häuserreihe: wird in updateCity() laufend positioniert
        visibleLeft = CGFloat(left)
        visibleRight = CGFloat(right)
        visibleTop = CGFloat(top)
        skyBottom = CGFloat(bottom)
        game.extendCity(toScreenX: Double(right) + 40)
        updateCity()

        beaconGlow?.removeFromParent()
        let glow = SKSpriteNode(texture: glowTexture, color: SKColor(red: 1, green: 0.25, blue: 0.15, alpha: 1), size: CGSize(width: 22, height: 22))
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        glow.position = CGPoint(x: beacon.position.x + 0.5, y: beacon.position.y - 0.5)
        glow.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.9, duration: 0), .wait(forDuration: 0.7),
            .fadeAlpha(to: 0.1, duration: 0), .wait(forDuration: 0.7),
        ])))
        glowLayer.addChild(glow)
        beaconGlow = glow

        // Funkelnde Sterne über dem Brett
        stars.forEach { $0.removeFromParent() }
        stars = (0..<16).map { _ in
            let star = SKSpriteNode(color: RGBA(hex: 0xE8ECFF).skColor, size: CGSize(width: 1, height: 1))
            star.anchorPoint = CGPoint(x: 0, y: 1)
            star.zPosition = 1
            star.position = design(Int.random(in: left..<max(left + 1, right)), Int.random(in: top..<max(top + 1, Layout.boardY - 12)))
            star.alpha = 0
            let on = Double.random(in: 0.4...1.6)
            star.run(.repeatForever(.sequence([
                .wait(forDuration: Double.random(in: 0.5...4)),
                .fadeAlpha(to: 1, duration: 0.25), .wait(forDuration: on), .fadeAlpha(to: 0, duration: 0.4),
            ])))
            backLayer.addChild(star)
            return star
        }
    }

    // MARK: Spielablauf

    private func startNewGame(mode newMode: GameMode, animated: Bool) {
        if menuVisible == false && isBuilt && game.score > 0 { AudioCenter.shared.music.nextTrack() }
        mode = newMode
        UserDefaults.standard.set(newMode.rawValue, forKey: "rapt.mode")
        highscore = Highscore.load(newMode)
        game = Game(seed: UInt64.random(in: 0...UInt64.max), mode: newMode)
        game.citySpeed = GameSettings.shared.citySpeed
        game.cityAcceleration = GameSettings.shared.cityAcceleration
        game.extendCity(toScreenX: Double(visibleRight) + 40)
        buildingSprites.values.forEach { $0.removeFromParent() }
        buildingSprites = [:]
        figure.removeAllActions()
        figure.zRotation = 0
        figure.alpha = 1
        figureJumping = false
        figureFalling = false
        wasInDanger = false
        shownBuilding = game.city.figureIndex
        startFigureIdle()
        let rooftop = newMode == .rooftop
        figure.isHidden = !rooftop
        if rooftop && animated { dropFigureIn(after: 0.5) }
        slotFrames.forEach { $0.isHidden = !rooftop }
        gems.values.forEach { $0.removeWithGlow() }
        gems = [:]
        overlayLayer.children.filter { $0 !== countdownLabel }.forEach { $0.removeFromParent() }
        countdownLabel.isHidden = true
        fresser?.node.removeFromParent()
        fresser = nil
        armed = nil
        armedBracket.isHidden = true
        pendingDeliveries = 0
        updateCity()
        updateSlots()
        refreshStatus()
        selected = nil
        place(cursor, at: nil)
        place(hintCursor, at: nil)
        displayedScore = 0
        shownScore = -1
        lastCombo = 1
        idleTime = 0
        shownPlan = game.plan
        updateHUD()

        var longest = 0.0
        for p in game.board.positions {
            guard let gem = game.board[p] else { continue }
            let node = makeGem(gem, at: animated ? Pos(p.col, p.row - Layout.count - 1) : p)
            gems[p] = node
            if animated {
                let delay = Double(p.col) * 0.035 + Double(Layout.count - 1 - p.row) * 0.02
                longest = max(longest, drop(node, to: p, rows: Layout.count + 1, delay: delay) + delay)
            }
        }
        busy = animated
        if animated {
            run(.sequence([.wait(forDuration: longest), .run { [weak self] in
                self?.audio.play(.land, volume: 0.5)
                self?.busy = false
            }]))
        }
    }

    private func makeGem(_ gem: Gem, at p: Pos, special: Special? = nil) -> GemNode {
        let node = GemNode(gem: gem, texture: sprites[gem]!.texture, glowTexture: glowTexture)
        applySpecial(special, to: node)
        node.position = center(of: p)
        gemLayer.addChild(node)
        glowLayer.addChild(node.glow)
        return node
    }

    private func applySpecial(_ special: Special?, to node: GemNode) {
        var overlay: SKTexture?
        var flames: [SKTexture] = []
        switch special {
        case .line(let horizontal)?:
            let key = "\(node.gem.rawValue)-\(horizontal)"
            if lineFlames[key] == nil {
                lineFlames[key] = SpecialArt.lineFlames(ramp: sprites[node.gem]!.ramp, horizontal: horizontal)
            }
            flames = lineFlames[key] ?? []
        case .bomb?: overlay = bombOverlay
        default: overlay = nil
        }
        node.setSpecial(special, overlay: overlay, lineFrames: flames, hyperFrames: hyperFrames)
    }

    private func itemTexture(for special: Special) -> SKTexture {
        switch special {
        case .hyper: return hyperFrames.first ?? SKTexture()
        case .bomb: return iconTextures[.bombe] ?? SKTexture()
        case .line: return lineOverlays[true] ?? SKTexture()
        }
    }

    /// Fall mit Erdbeschleunigung (52 Felder/s²) und 1-px-Nachfedern.
    @discardableResult
    private func drop(_ node: GemNode, to p: Pos, rows: Int, delay: TimeInterval = 0) -> TimeInterval {
        let duration = (2 * Double(max(rows, 1)) / 52).squareRoot()
        let move = SKAction.move(to: center(of: p), duration: duration)
        move.timingMode = .easeIn
        node.removeAllActions()
        node.run(.sequence([
            .wait(forDuration: delay), move,
            .moveBy(x: 0, y: 1, duration: 0.04), .moveBy(x: 0, y: -1, duration: 0.05),
        ]))
        return duration
    }

    private func setSelected(_ p: Pos?) {
        selected = p
        place(cursor, at: p)
        if p != nil {
            audio.play(.select, volume: 0.4)
            haptics.select()
        }
    }

    private func attemptSwap(_ a: Pos, _ b: Pos) {
        guard let na = gems[a], let nb = gems[b] else { return }
        busy = true
        idleTime = 0
        place(hintCursor, at: nil)
        let ca = center(of: a), cb = center(of: b)

        func slide(_ node: GemNode, to p: CGPoint) -> SKAction {
            let action = SKAction.move(to: p, duration: 0.14)
            action.timingMode = .easeInEaseOut
            return action
        }

        let result = game.swap(a, b)
        guard result.isValid else {
            audio.play(.invalid, volume: 0.45)
            haptics.invalid()
            na.run(.sequence([slide(na, to: cb), slide(na, to: ca)]))
            nb.run(.sequence([slide(nb, to: ca), slide(nb, to: cb)]))
            run(.sequence([.wait(forDuration: 0.3), .run { [weak self] in self?.busy = false }]))
            return
        }
        audio.play(.swap, volume: 0.5)
        na.run(slide(na, to: cb))
        nb.run(slide(nb, to: ca))
        gems[a] = nb
        gems[b] = na
        run(.sequence([.wait(forDuration: 0.15), .run { [weak self] in
            self?.play(result, index: 0)
        }]))
    }

    private func play(_ result: SwapResult, index: Int) {
        guard index < result.steps.count else {
            finish(result)
            return
        }
        let step = result.steps[index]
        lastCombo = step.combo
        explode(step)
        run(.sequence([.wait(forDuration: 0.17), .run { [weak self] in
            self?.collapse(step) { self?.play(result, index: index + 1) }
        }]))
    }

    private func collapse(_ step: CascadeStep, then next: @escaping () -> Void) {
        var moved: [Pos: GemNode] = [:]
        var longest = 0.0
        for fall in step.falls {
            guard let node = gems.removeValue(forKey: fall.from) else { continue }
            moved[fall.to] = node
            longest = max(longest, drop(node, to: fall.to, rows: fall.to.row - fall.from.row))
        }
        for spawn in step.spawns {
            let node = makeGem(spawn.gem, at: spawn.from)
            moved[spawn.to] = node
            longest = max(longest, drop(node, to: spawn.to, rows: spawn.to.row - spawn.from.row))
        }
        for (p, node) in moved { gems[p] = node }
        run(.sequence([
            .wait(forDuration: longest),
            .run { [weak self] in self?.audio.play(.land, volume: 0.35) },
            .wait(forDuration: 0.06),
            .run(next),
        ]))
    }

    private func finish(_ result: SwapResult) {
        if game.score > highscore {
            highscore = game.score
            Highscore.save(highscore, for: mode)
        }
        updateHUD()
        pendingDeliveries += result.rewards.filter { $0.powerUp != nil }.count
        updateSlots()
        for (i, reward) in result.rewards.enumerated() {
            run(.sequence([.wait(forDuration: Double(i) * 1.4), .run { [weak self] in self?.celebrate(reward) }]))
        }
        if result.isGameOver {
            showGameOver()
        } else {
            busy = false
        }
        refreshStatus()
    }

    // MARK: Effekte

    private func explode(_ step: CascadeStep) {
        let combo = step.combo
        guard !step.runs.isEmpty else {
            explodeCells(step)
            playDetonations(step.detonations)
            return
        }
        playDetonations(step.detonations)
        for creation in step.created {
            guard let node = gems[creation.pos] else { continue }
            applySpecial(creation.special, to: node)
            let c = center(of: creation.pos)
            fx.warpRing(at: c, color: GemArt.glowColor(creation.gem), radius: 26)
            fx.flash(at: c, color: .white)
            audio.play(.powerUp, volume: 0.45)
            if creation.special == .hyper {
                var delivery = SplashPresenter.Delivery(contact: Contact.random(for: Contact.contact(for: creation.special)), item: itemTexture(for: creation.special))
                delivery.onHandover = { [weak self, weak node] start in
                    guard let self, let node else { return }
                    self.flyItem(self.itemTexture(for: .hyper), from: start, to: { [weak node] in node?.position }) { [weak self, weak node] in
                        guard let self, let node else { return }
                        self.fx.flash(at: node.position, color: .white)
                        self.fx.warpRing(at: node.position, color: .white, radius: 22)
                    }
                }
                splash.present(delivery, at: clock, force: true)
            }
        }
        for p in step.cleared {
            if let node = gems.removeValue(forKey: p) { pop(node) }
        }

        var big = false
        let boardMid = design(Layout.boardX + Layout.boardSize / 2, Layout.boardY + Layout.boardSize / 2)
        for (i, match) in step.runs.enumerated() {
            let color = GemArt.glowColor(match.gem)
            let shards = sprites[match.gem]!.ramp.suffix(3).map(\.skColor)
            run(.sequence([.wait(forDuration: Double(i) * 0.05), .run { [weak self] in
                self?.audio.match(step: combo - 1 + i)
            }]))
            for p in match.cells {
                let c = center(of: p)
                fx.flash(at: c, color: color)
                fx.explosion(at: c, scale: 0.55)
                fx.shrapnel(at: c, colors: shards, count: 7 + combo * 2, power: 1 + CGFloat(combo - 1) * 0.15)
            }
            let mid = center(of: match.center)
            fx.steam(at: mid)
            if combo >= 2 { fx.steam(at: center(of: match.cells[0])) }
            if match.length >= 4 {
                big = true
                let beamCenter = match.isHorizontal ? CGPoint(x: boardMid.x, y: mid.y) : CGPoint(x: mid.x, y: boardMid.y)
                fx.beam(horizontal: match.isHorizontal, center: beamCenter, length: CGFloat(Layout.boardSize), color: color)
                fx.explosion(at: mid, scale: 1.3)
                warp(at: mid, strength: 6, color: color)
            }
        }
        if combo >= 3 && !big {
            warp(at: center(of: step.runs[0].center), strength: 4, color: .white)
        }

        let anchor = center(of: step.runs[0].center)
        fx.popup("+\(step.points)", at: CGPoint(x: anchor.x, y: anchor.y + 6), color: Palette.cream)
        if combo >= 2 {
            fx.popup("KASKADE x\(combo)", at: design(100, Layout.boardY + 24), color: Palette.amber, scale: 2)
        }

        audio.play(.shrapnel, volume: Float(min(1, 0.35 + 0.1 * Double(combo))))
        if combo >= 2 { audio.play(.steam, volume: 0.4) }
        if combo >= 2 { audio.play(.cascade, volume: 0.5) }
        if big {
            audio.play(.explosion, volume: 0.9)
            audio.play(.warp, volume: 0.6)
            shake(strength: 2)
            haptics.explosion()
        } else if combo >= 3 {
            audio.play(.warp, volume: 0.5)
            shake(strength: 1)
            haptics.warp()
        } else {
            haptics.match(combo: combo)
        }
        setText(comboLabel, "x\(lastCombo)", color: Palette.red, scale: 2)
    }

    /// Wirkung ausgelöster Spezialsteine: Strahlen, Explosionen, Blitze.
    private func playDetonations(_ detonations: [Detonation]) {
        guard !detonations.isEmpty else { return }
        let boardMid = design(Layout.boardX + Layout.boardSize / 2, Layout.boardY + Layout.boardSize / 2)
        for (i, d) in detonations.enumerated() {
            let c = center(of: d.pos)
            let color = GemArt.glowColor(d.gem)
            let delay = Double(i) * 0.06
            run(.sequence([.wait(forDuration: delay), .run { [weak self] in
                guard let self else { return }
                switch d.special {
                case .line(let horizontal):
                    let beamCenter = horizontal ? CGPoint(x: boardMid.x, y: c.y) : CGPoint(x: c.x, y: boardMid.y)
                    self.fx.beam(horizontal: horizontal, center: beamCenter, length: CGFloat(Layout.boardSize), color: color)
                    self.audio.play(.warp, volume: 0.45)
                case .bomb:
                    self.fx.explosion(at: c, scale: 1.6)
                    self.warp(at: c, strength: 5, color: SKColor(red: 1, green: 0.55, blue: 0.2, alpha: 1))
                    self.audio.play(.bomb, volume: 0.7)
                    self.shake(strength: 2)
                case .hyper:
                    self.fx.warpRing(at: c, color: .white, radius: 80)
                    for (k, q) in d.cells.enumerated() where q != d.pos {
                        self.fx.lightning(from: c, to: self.center(of: q), color: color, delay: Double(k) * 0.015)
                    }
                    self.audio.play(.purge, volume: 0.8)
                    self.shake(strength: 2)
                }
            }]))
        }
        audio.play(.explosion, volume: min(1, 0.5 + 0.1 * Float(detonations.count)))
        haptics.explosion()
    }

    /// Stufe ohne Reihen: Steine, die ein Power-up entfernt (Bombe, Farbtilger, Fresser).
    private func explodeCells(_ step: CascadeStep) {
        var sum = CGPoint.zero
        for p in step.cleared {
            let c = center(of: p)
            sum.x += c.x
            sum.y += c.y
            guard let node = gems.removeValue(forKey: p) else { continue }
            fx.flash(at: c, color: GemArt.glowColor(node.gem))
            fx.explosion(at: c, scale: 0.5)
            fx.shrapnel(at: c, colors: sprites[node.gem]!.ramp.suffix(3).map(\.skColor), count: 6)
            pop(node)
        }
        guard !step.cleared.isEmpty else { return }
        let n = CGFloat(step.cleared.count)
        fx.popup("+\(step.points)", at: CGPoint(x: (sum.x / n).rounded(), y: (sum.y / n).rounded() + 6), color: Palette.cream, scale: 2)
        audio.match(step: 0)
        audio.play(.shrapnel, volume: 0.7)
        setText(comboLabel, "x\(lastCombo)", color: Palette.red, scale: 2)
    }

    private func pop(_ node: GemNode) {
        node.isDying = true
        let flash = SKSpriteNode(color: .white, size: CGSize(width: 18, height: 18))
        flash.alpha = 0.85
        flash.zPosition = 1
        node.body.addChild(flash)
        flash.run(.fadeOut(withDuration: 0.16))
        node.glow.run(.group([.scale(to: 1.8, duration: 0.16), .fadeAlpha(to: 0.9, duration: 0.06)]))
        node.run(.sequence([.wait(forDuration: 0.16), .run { node.removeWithGlow() }]))
    }

    /// Schockwelle: Ringe mit Farbsaum, dazu werden die Steine kurz nach außen gedrückt.
    private func warp(at p: CGPoint, strength: CGFloat, color: SKColor) {
        fx.warpRing(at: p, color: color, radius: 90)
        let flash = fx.glow(at: p, color: color, size: 260, alpha: 0.22)
        flash.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
        for node in gems.values where !node.isDying {
            let dx = node.position.x - p.x, dy = node.position.y - p.y
            let d = max(1, (dx * dx + dy * dy).squareRoot())
            let push = strength * exp(-d / 45)
            guard push > 0.5 else { continue }
            let offset = CGPoint(x: (dx / d * push).rounded(), y: (dy / d * push).rounded())
            let out = SKAction.move(to: offset, duration: 0.07)
            out.timingMode = .easeOut
            let back = SKAction.move(to: .zero, duration: 0.3)
            back.timingMode = .easeInEaseOut
            node.body.removeAction(forKey: "warp")
            node.body.run(.sequence([.wait(forDuration: Double(d / 320)), out, back]), withKey: "warp")
        }
    }

    private func shake(strength: Int) {
        var steps: [SKAction] = (0..<7).map { _ in
            .move(to: CGPoint(x: Int.random(in: -strength...strength), y: Int.random(in: -strength...strength)), duration: 0.035)
        }
        steps.append(.move(to: .zero, duration: 0.04))
        shaker.removeAction(forKey: "shake")
        shaker.run(.sequence(steps), withKey: "shake")
    }

    // MARK: Anzeige

    private func updateHUD() {
        setText(recordLabel, "HOCHPUNKTE " + String(format: "%08d", highscore), color: Palette.label)
        setText(comboLabel, "x\(lastCombo)", color: Palette.red, scale: 2)
        let plan = game.plan
        setText(planLabel, "SPRUNG " + String(format: "%02d", min(plan, 99)), color: RGBA(hex: 0xB8B0A2))
        let filled = Int((game.planProgress * Double(planSegments.count)).rounded(.down))
        for (i, seg) in planSegments.enumerated() {
            seg.color = (i < filled ? Palette.amber : RGBA(hex: 0x221E2A)).skColor
        }
        shownPlan = plan
    }

    private func showGameOver() {
        audio.play(.gameOver, volume: 0.7)
        busy = true
        run(.sequence([.wait(forDuration: 0.5), .run { [weak self] in self?.showMenu(gameOver: true) }]))
    }

    /// Moduswahl über dem Brett: beim Start und nach jedem Spielende.
    private func showMenu(gameOver: Bool) {
        overlayLayer.children.filter { $0 !== countdownLabel }.forEach { $0.removeFromParent() }
        menuButtons = []
        menuVisible = true
        busy = true
        setArmed(nil)
        setSelected(nil)

        let shade = SKSpriteNode(color: SKColor(red: 0.03, green: 0.02, blue: 0.06, alpha: 0.86),
                                 size: CGSize(width: Layout.boardSize, height: Layout.boardSize))
        shade.anchorPoint = CGPoint(x: 0, y: 1)
        shade.position = design(Layout.boardX, Layout.boardY)
        shade.alpha = 0
        overlayLayer.addChild(shade)
        shade.run(.fadeIn(withDuration: 0.3))

        func text(_ string: String, color: RGBA, scale: CGFloat, y: Int) {
            let canvas = PixelFont.render(string, color: color, shadow: RGBA(hex: 0x050409))
            let node = SKSpriteNode(texture: canvas.texture(),
                                    size: CGSize(width: CGFloat(canvas.width) * scale, height: CGFloat(canvas.height) * scale))
            node.anchorPoint = CGPoint(x: 0, y: 1)
            let width = Int(CGFloat(canvas.width) * scale)
            node.position = design(Layout.boardX + (Layout.boardSize - width) / 2, Layout.boardY + y)
            node.zPosition = 1
            overlayLayer.addChild(node)
        }

        var buttonY = 56
        if gameOver {
            text(game.hasFallen ? "ABGESTÜRZT" : "KEINE ZÜGE", color: Palette.amber, scale: 2, y: 18)
            text("PUNKTE " + String(game.score), color: Palette.cream, scale: 1, y: 36)
            buttonY = 64
            text("NOCHMAL:", color: Palette.label, scale: 1, y: buttonY - 12)
        } else {
            text("SPIELMODUS", color: Palette.amber, scale: 2, y: 22)
            text("HOCHPUNKTE " + String(format: "%08d", Highscore.load(.endless)) + " / " + String(format: "%08d", Highscore.load(.rooftop)),
                 color: Palette.label, scale: 1, y: 40)
        }
        let options: [(GameMode, String, String)] = [
            (.endless, "ENDLOS", "KLASSISCH - OHNE ZEITDRUCK"),
            (.rooftop, "DÄCHERLAUF", "STADT WANDERT - POWER-UPS"),
        ]
        for (i, option) in options.enumerated() {
            let w = 150, h = 28
            let x = Layout.boardX + (Layout.boardSize - w) / 2
            let y = Layout.boardY + buttonY + i * (h + 8)
            let selected = option.0 == mode
            var canvas = PixelCanvas(width: w, height: h, fill: RGBA(hex: selected ? 0x2A1A14 : 0x1B1A24))
            let border = selected ? Palette.amber : RGBA(hex: 0x4A4B56)
            canvas.fillRect(0, 0, w, 1, border)
            canvas.fillRect(0, h - 1, w, 1, border)
            canvas.fillRect(0, 0, 1, h, border)
            canvas.fillRect(w - 1, 0, 1, h, border)
            let title = PixelFont.render(option.1, color: selected ? Palette.amber : Palette.cream)
            for yy in 0..<title.height * 2 {
                for xx in 0..<title.width * 2 where title.get(xx / 2, yy / 2).a > 0 {
                    canvas.set((w - title.width * 2) / 2 + xx, 5 + yy, title.get(xx / 2, yy / 2))
                }
            }
            PixelFont.draw(option.2, into: &canvas, x: (w - PixelFont.width(option.2)) / 2, y: 19, color: Palette.label)
            let node = SKSpriteNode(texture: canvas.texture(), size: canvas.size)
            node.anchorPoint = CGPoint(x: 0, y: 1)
            node.position = design(x, y)
            node.zPosition = 1
            node.alpha = 0
            node.run(.sequence([.wait(forDuration: 0.1 + Double(i) * 0.08), .fadeIn(withDuration: 0.2)]))
            overlayLayer.addChild(node)
            menuButtons.append((CGRect(x: x, y: y, width: w, height: h), option.0))
        }
        // Direkter Weg in die Einstellungen
        let label = "EINSTELLUNGEN"
        let linkWidth = 7 + 4 + PixelFont.width(label)
        var link = PixelCanvas(width: linkWidth, height: 7)
        link.draw(Self.gearCanvas(Palette.cream), at: 0, 0)
        PixelFont.draw(label, into: &link, x: 11, y: 1, color: Palette.cream)
        let linkX = Layout.boardX + (Layout.boardSize - linkWidth) / 2
        let linkY = Layout.boardY + buttonY + 2 * 36 + 4
        let linkNode = pixelSprite(link, topLeft: design(linkX, linkY))
        linkNode.zPosition = 1
        overlayLayer.addChild(linkNode)
        menuSettingsRect = CGRect(x: linkX, y: linkY, width: linkWidth, height: 7).insetBy(dx: -8, dy: -6)
    }

    private static func gearCanvas(_ color: RGBA) -> PixelCanvas {
        let rows = ["..X.X..", ".XXXXX.", "XXX.XXX", "XX...XX", "XXX.XXX", ".XXXXX.", "..X.X.."]
        var c = PixelCanvas(width: 7, height: 7)
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() where ch == "X" { c.set(x, y, color) }
        }
        return c
    }

    private func handleMenu(_ point: CGPoint) {
        let p = CGPoint(x: point.x, y: Layout.height - point.y)
        if menuSettingsRect.contains(p) {
            audio.play(.select, volume: 0.5)
            settingsPanel.show()
            return
        }
        guard let choice = menuButtons.first(where: { $0.rect.contains(p) }) else { return }
        menuVisible = false
        menuButtons = []
        audio.play(.select, volume: 0.6)
        startNewGame(mode: choice.mode, animated: true)
    }

    // MARK: Stadt

    /// Positioniert die Plattenbauten der vorderen Reihe und die Figur.
    private func updateCity() {
        let city = game.city
        var visible = Set<Int>()
        for (i, b) in city.buildings.enumerated() {
            let x = CGFloat(city.screenX(b.x)).rounded()
            guard x + CGFloat(b.width) >= visibleLeft - 4, x <= visibleRight + 4 else { continue }
            visible.insert(i)
            let sprite = buildingSprites[i] ?? makeBuilding(b, index: i)
            sprite.position = design(x, skyBottom)
        }
        for (i, sprite) in buildingSprites where !visible.contains(i) {
            sprite.removeFromParent()
            buildingSprites[i] = nil
        }
        if !figureJumping && !figureFalling {
            let b = city.buildings[min(shownBuilding, city.buildings.count - 1)]
            figure.position = design(CGFloat(city.screenX(b.center)).rounded(), skyBottom - CGFloat(b.height))
        }
    }

    private func makeBuilding(_ b: Building, index: Int) -> SKSpriteNode {
        let art = Backdrop.building(width: b.width, height: b.height, seed: index * 7 + 3)
        let sprite = SKSpriteNode(texture: art.canvas.texture(), size: art.canvas.size)
        sprite.anchorPoint = CGPoint(x: 0, y: 0)
        sprite.zPosition = 3.5
        for light in art.lights.prefix(6) {
            let g = SKSpriteNode(texture: glowTexture, color: RGBA(hex: 0xE8A94A).skColor, size: CGSize(width: 9, height: 9))
            g.colorBlendFactor = 1
            g.blendMode = .add
            g.alpha = 0.18
            g.position = CGPoint(x: CGFloat(light.x) + 0.5, y: CGFloat(b.height - light.y) - 0.5)
            sprite.addChild(g)
        }
        backLayer.addChild(sprite)
        buildingSprites[index] = sprite
        return sprite
    }

    /// Musik weich absenken (z. B. bei Absturzgefahr) und wieder anheben.
    private func duckMusic(_ target: Float, dt: TimeInterval) {
        var next = musicDuck + (target - musicDuck) * Float(min(1, dt * 3))
        if abs(next - target) < 0.002 { next = target }
        guard next != musicDuck else { return }
        musicDuck = next
        AudioCenter.shared.music.duck = next
    }

    private func makeHelpPanel() -> HelpPanel {
        let total = Game.rewardWeights.values.reduce(0, +)
        func percent(_ kind: PowerUp) -> String {
            "\(Int(((Game.rewardWeights[kind] ?? 0) / total * 100).rounded()))%"
        }
        func icon(_ kind: PowerUp) -> SKNode {
            SKSpriteNode(texture: iconTextures[kind], size: CGSize(width: 16, height: 16))
        }
        func radio(_ contact: Contact, _ item: SKTexture?) -> () -> Void {
            { [weak self] in
                guard let self else { return }
                let delivery = SplashPresenter.Delivery(contact: Contact.random(for: contact), item: item ?? SKTexture())
                self.splash.present(delivery, at: self.clock, force: true, ignoreSettings: true)
            }
        }
        func radioFor(_ kind: PowerUp) -> () -> Void { radio(Contact.contact(for: kind), iconTextures[kind]) }
        let powerUps: [HelpPanel.Entry] = [
            .init(icon: icon(.bombe), title: "BOMBE", badge: percent(.bombe),
                  lines: ["FELD ANTIPPEN: SPRENGT 3X3."], onTap: radioFor(.bombe)),
            .init(icon: icon(.farbtilger), title: "FARBTILGER", badge: percent(.farbtilger),
                  lines: ["STEIN ANTIPPEN: ALLE STEINE", "DIESER FARBE VERSCHWINDEN."], onTap: radioFor(.farbtilger)),
            .init(icon: icon(.strudel), title: "STRUDEL", badge: percent(.strudel),
                  lines: ["MISCHT DAS BRETT NEU. DANACH", "IST IMMER EIN ZUG MÖGLICH."], onTap: radioFor(.strudel)),
            .init(icon: icon(.atom), title: "ATOMBOMBE", badge: percent(.atom),
                  lines: ["FELD ANTIPPEN: SPRENGT 5X5."], onTap: radioFor(.atom)),
            .init(icon: icon(.fresser), title: "FRESSER", badge: percent(.fresser),
                  lines: ["ZWEI FARBEN VERSTEINERN. 10 SEK.", "WISCHEN UND ALLES ANDERE FRESSEN."], onTap: radioFor(.fresser)),
        ]

        let lineStone = SKNode()
        let flames = SKSpriteNode(texture: SpecialArt.lineFlames(ramp: sprites[.kristall]!.ramp, horizontal: true).first)
        flames.size = CGSize(width: 28, height: 18)
        lineStone.addChild(flames)
        lineStone.addChild(SKSpriteNode(texture: sprites[.kristall]!.texture, size: CGSize(width: 18, height: 18)))
        let bombStone = SKSpriteNode(texture: sprites[.orden]!.texture, size: CGSize(width: 22, height: 22))
        bombStone.addChild(SKSpriteNode(texture: bombOverlay, size: CGSize(width: 22, height: 22)))
        let hyper = SKSpriteNode(texture: hyperFrames.first, size: CGSize(width: 22, height: 22))
        hyper.run(.repeatForever(.animate(with: hyperFrames, timePerFrame: 0.08)))
        let specials: [HelpPanel.Entry] = [
            .init(icon: lineStone, title: "LINIEN-STEIN", badge: "",
                  lines: ["4 IN EINER REIHE. RÄUMT DIE", "GANZE ZEILE ODER SPALTE AB."],
                  onTap: radio(Contact.contact(for: .line(horizontal: true)), nil)),
            .init(icon: bombStone, title: "BOMBEN-STEIN", badge: "",
                  lines: ["L- ODER T-FORM. SPRENGT 3X3."], onTap: radio(Contact.contact(for: .bomb), nil)),
            .init(icon: hyper, title: "HYPERSTEIN", badge: "",
                  lines: ["5 IN EINER REIHE. TAUSCHEN", "LÖSCHT EINE GANZE FARBE."], onTap: radio(Contact.contact(for: .hyper), nil)),
        ]
        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.1.0"
        let info: [HelpPanel.Block] = [
            .init(title: "SO GEHT DER DÄCHERLAUF", lines: [
                "DIE HÄUSER WANDERN LANGSAM NACH LINKS.",
                "PUNKTE FÜLLEN DEN SPRUNG-BALKEN UNTER",
                "DEM BRETT. IST ER VOLL SPRINGT DIE",
                "FIGUR AUFS NÄCHSTE DACH UND BRINGT",
                "EIN POWER-UP. WIRD SIE LINKS AUS DEM",
                "BILD GESCHOBEN STÜRZT SIE AB.",
            ]),
            .init(title: "PUNKTE", lines: [
                "JEDER STEIN IN EINER REIHE: 50",
                "JEDER STEIN ÜBER 3 IN DER REIHE: +100",
                "KASKADEN: STUFE 2 DOPPELT - 3 DREIFACH",
                "SPEZIALSTEIN AUSGELÖST: +200 JE STUFE",
                "SPRUNG 1 BRAUCHT 1500 PUNKTE. JEDER",
                "WEITERE SPRUNG 1500 MEHR ALS DER LETZTE.",
            ]),
            .init(title: "MACHER", lines: [
                "SPIEL: NICOLAS OESTREICH",
                "MUSIK: LUIS ZUNO - ANSIMUZ.COM",
                "RAPT " + version,
            ], highlight: true),
        ]
        return HelpPanel(designHeight: Layout.height, powerUps: powerUps, specials: specials,
                         footnote: "JEDER 6. SPRUNG: FRESSER ODER ATOM.", info: info)
    }

    /// Ein Fenster in einem sichtbaren Plattenbau geht an oder aus. Sehr dezent, nur gelegentlich.
    private func toggleRandomWindow() {
        guard let sprite = buildingSprites.values.randomElement() else { return }
        let w = Int(sprite.size.width), h = Int(sprite.size.height)
        let cols = max(1, (w - 7) / 4), rows = max(1, (h - 7) / 5)
        let wx = 3 + 4 * Int.random(in: 0..<cols), wy = 4 + 5 * Int.random(in: 0..<rows)
        guard wx + 2 <= w - 4, wy + 2 <= h - 3 else { return }
        let turnOn = Bool.random()
        let pane = SKSpriteNode(color: RGBA(hex: turnOn ? 0xE8A94A : 0x121119).skColor, size: CGSize(width: 2, height: 2))
        pane.anchorPoint = CGPoint(x: 0, y: 1)
        pane.position = CGPoint(x: wx, y: h - wy)
        pane.zPosition = 1
        sprite.addChild(pane)
        if turnOn {
            // Leuchtstoffröhre: kurz flackern, dann an
            pane.alpha = 0
            pane.run(.sequence([
                .fadeAlpha(to: 1, duration: 0), .wait(forDuration: 0.06),
                .fadeAlpha(to: 0, duration: 0), .wait(forDuration: 0.1),
                .fadeAlpha(to: 1, duration: 0),
            ]))
            let g = SKSpriteNode(texture: glowTexture, color: RGBA(hex: 0xE8A94A).skColor, size: CGSize(width: 9, height: 9))
            g.colorBlendFactor = 1
            g.blendMode = .add
            g.alpha = 0
            g.position = CGPoint(x: 1, y: -1)
            pane.addChild(g)
            g.run(.sequence([.wait(forDuration: 0.16), .fadeAlpha(to: 0.18, duration: 0.2)]))
        }
    }

    /// Sternschnuppe über dem oberen oder unteren Himmel.
    private func shootingStar() {
        let top = Bool.random()
        let yDesign = top
            ? CGFloat.random(in: (visibleTop + 4)...max(visibleTop + 5, 40))
            : CGFloat.random(in: CGFloat(Layout.slotY + 26)...max(CGFloat(Layout.slotY + 27), skyBottom - 75))
        let fromLeft = Bool.random()
        let startX = fromLeft ? CGFloat.random(in: visibleLeft...(visibleLeft + 80)) : CGFloat.random(in: (visibleRight - 80)...visibleRight)
        let start = design(startX, yDesign)
        let dx = CGFloat.random(in: 70...120) * (fromLeft ? 1 : -1)
        let dy = -CGFloat.random(in: 20...40)
        let head = SKSpriteNode(color: .white, size: CGSize(width: 1, height: 1))
        head.position = start
        head.zPosition = 1.5
        let light = SKSpriteNode(texture: glowTexture, color: RGBA(hex: 0xCDD6FF).skColor, size: CGSize(width: 10, height: 10))
        light.colorBlendFactor = 1
        light.blendMode = .add
        light.alpha = 0.8
        head.addChild(light)
        backLayer.addChild(head)
        let duration: CGFloat = 0.75
        var lastPixel = CGPoint(x: -999, y: -999)
        let layer = backLayer
        let flight = SKAction.customAction(withDuration: TimeInterval(duration)) { node, elapsed in
            let t = elapsed / duration
            let p = CGPoint(x: (start.x + dx * t).rounded(), y: (start.y + dy * t).rounded())
            node.position = p
            node.alpha = t < 0.15 ? t / 0.15 : (t > 0.8 ? (1 - t) / 0.2 : 1)
            if p != lastPixel {
                lastPixel = p
                let trail = SKSpriteNode(color: RGBA(hex: 0xCDD6FF).skColor, size: CGSize(width: 1, height: 1))
                trail.position = p
                trail.zPosition = 1.4
                trail.alpha = node.alpha * 0.8
                layer.addChild(trail)
                trail.run(.sequence([.fadeOut(withDuration: 0.35), .removeFromParent()]))
            }
        }
        head.run(.sequence([flight, .removeFromParent()]))
    }

    /// Figur wird links aus dem Bild geschoben und stürzt ab.
    private func figureFall() {
        figureFalling = true
        fresser?.node.removeFromParent()
        fresser = nil
        countdownLabel.isHidden = true
        setArmed(nil)
        stopFigureIdle()
        figure.texture = figureJump
        audio.play(.jump, volume: 0.6)
        haptics.explosion()
        let start = figure.position
        let fall = SKAction.customAction(withDuration: 1.2) { node, elapsed in
            let t = elapsed
            node.position = CGPoint(x: (start.x - 14 * t).rounded(), y: (start.y + 30 * t - 160 * t * t).rounded())
            node.zRotation = -t * 5
        }
        figure.run(.sequence([fall, .fadeOut(withDuration: 0.1)]))
        fx.popup("ABSTURZ!", at: CGPoint(x: max(30, start.x + 20), y: start.y + 16), color: Palette.red, scale: 2)
        showGameOver()
    }

    // MARK: Power-ups

    private static func name(_ kind: PowerUp) -> String {
        switch kind {
        case .bombe: return "BOMBE"
        case .farbtilger: return "FARBTILGER"
        case .fresser: return "FRESSER"
        case .strudel: return "STRUDEL"
        case .atom: return "ATOMBOMBE"
        }
    }

    private func slotIndex(at point: CGPoint) -> Int? {
        let x = Int(floor(point.x)), y = Int(floor(Layout.height - point.y))
        guard y >= Layout.slotY, y < Layout.slotY + Layout.slotSize else { return nil }
        for i in 0..<Game.maxPowerUps where x >= Layout.slotX(i) && x < Layout.slotX(i) + Layout.slotSize {
            return i
        }
        return nil
    }

    private func updateSlots() {
        for (i, icon) in slotIcons.enumerated() {
            if mode == .rooftop && i < game.powerUps.count - pendingDeliveries {
                icon.texture = iconTextures[game.powerUps[i]]
                icon.isHidden = false
            } else {
                icon.isHidden = true
            }
        }
    }

    /// Übergabe eines Power-ups: per Funk-Einblendung aus der Hand des Kontakts, sonst von der Figur aus.
    private func deliver(_ kind: PowerUp) {
        let icon = iconTextures[kind] ?? SKTexture()
        let land: (CGPoint) -> Void = { [weak self] start in
            guard let self else { return }
            let index = max(0, min(Game.maxPowerUps - 1, self.game.powerUps.count - self.pendingDeliveries))
            let target = self.design(Layout.slotX(index) + Layout.slotSize / 2, Layout.slotY + Layout.slotSize / 2)
            self.flyItem(icon, from: start, to: { target }) { [weak self] in
                guard let self else { return }
                self.pendingDeliveries = max(0, self.pendingDeliveries - 1)
                self.updateSlots()
                self.flashSlot(index)
                self.audio.play(.powerUp, volume: 0.7)
                self.haptics.select()
            }
        }
        var delivery = SplashPresenter.Delivery(contact: Contact.random(for: Contact.contact(for: kind)), item: icon)
        delivery.onHandover = land
        if !splash.present(delivery, at: clock, force: true) {
            land(CGPoint(x: figure.position.x, y: figure.position.y + 6))
        }
    }

    /// Gegenstand fliegt im Bogen mit Leuchtspur zu einem Ziel, das sich unterwegs bewegen darf.
    private func flyItem(_ texture: SKTexture, from start: CGPoint, to target: @escaping () -> CGPoint?, completion: @escaping () -> Void) {
        let item = SKSpriteNode(texture: texture, size: texture.size())
        item.position = start
        item.zPosition = 90
        let light = SKSpriteNode(texture: glowTexture, color: Palette.amber.skColor, size: CGSize(width: 30, height: 30))
        light.colorBlendFactor = 1
        light.blendMode = .add
        light.alpha = 0.7
        item.addChild(light)
        shaker.addChild(item)
        let duration: CGFloat = 0.5
        var last = start
        let flight = SKAction.customAction(withDuration: TimeInterval(duration)) { [weak self] node, elapsed in
            guard let self else { return }
            let end = target() ?? last
            last = end
            let t = min(1, elapsed / duration)
            let e = t * t
            let lift = sin(.pi * t) * 30
            node.position = CGPoint(x: (start.x + (end.x - start.x) * e).rounded(),
                                    y: (start.y + (end.y - start.y) * e + lift).rounded())
            if Int(elapsed * 60) % 3 == 0 {
                self.fx.glow(at: node.position, color: Palette.amber.skColor, size: 10, alpha: 0.5)
                    .run(.sequence([.fadeOut(withDuration: 0.25), .removeFromParent()]))
            }
        }
        item.run(.sequence([flight, .removeFromParent(), .run(completion)]))
    }

    private func flashSlot(_ i: Int) {
        guard i >= 0, i < slotIcons.count else { return }
        let p = design(Layout.slotX(i) + Layout.slotSize / 2, Layout.slotY + Layout.slotSize / 2)
        fx.flash(at: p, color: Palette.amber.skColor)
        fx.shrapnel(at: p, colors: [Palette.amber.skColor, .white, Palette.red.skColor], count: 10, power: 0.6, bounces: false)
    }

    private func setStatus(_ text: String, color: RGBA = Palette.label, blink: Bool = false) {
        statusLabel.removeAction(forKey: "blink")
        statusLabel.alpha = 1
        guard text != statusText || blink else { return }
        statusText = text
        if text.isEmpty {
            statusLabel.isHidden = true
            return
        }
        statusLabel.isHidden = false
        setText(statusLabel, text, color: color)
        if blink {
            statusLabel.run(.repeatForever(.sequence([
                .fadeAlpha(to: 1, duration: 0), .wait(forDuration: 0.5),
                .fadeAlpha(to: 0.3, duration: 0), .wait(forDuration: 0.3),
            ])), withKey: "blink")
        }
    }

    private func refreshStatus() {
        if mode == .rooftop && !game.isOver && game.city.isInDanger {
            setStatus("ABSTURZGEFAHR!", color: Palette.red, blink: true)
        } else if fresser != nil {
            setStatus("WISCHEN ZUM LENKEN", color: Palette.amber)
        } else if armed == .bomb {
            setStatus("BOMBE: ZIEL WÄHLEN", color: Palette.amber)
        } else if armed == .atom {
            setStatus("ATOMBOMBE: ZIEL WÄHLEN", color: Palette.amber)
        } else if armed == .purge {
            setStatus("FARBTILGER: FARBE WÄHLEN", color: Palette.amber)
        } else if !game.isOver && !game.hasValidMove {
            setStatus("KEINE ZÜGE: POWER-UP!", color: Palette.red, blink: true)
        } else if mode == .rooftop && !game.powerUps.isEmpty {
            setStatus("POWER-UP ANTIPPEN")
        } else {
            setStatus("")
        }
    }

    private func setArmed(_ mode: Armed?, slot: Int = 0) {
        armed = mode
        armedSlot = slot
        if mode == nil {
            armedBracket.isHidden = true
        } else {
            armedBracket.position = design(Layout.slotX(slot), Layout.slotY)
            armedBracket.isHidden = false
            setSelected(nil)
        }
        refreshStatus()
    }

    private func handleSlot(_ i: Int) {
        guard !busy, fresser == nil, i < game.powerUps.count else { return }
        let kind = game.powerUps[i]
        switch kind {
        case .bombe:
            setArmed(armed == .bomb && armedSlot == i ? nil : .bomb, slot: i)
        case .farbtilger:
            setArmed(armed == .purge && armedSlot == i ? nil : .purge, slot: i)
        case .atom:
            setArmed(armed == .atom && armedSlot == i ? nil : .atom, slot: i)
        case .strudel:
            setArmed(nil)
            shuffleBoard()
        case .fresser:
            setArmed(nil)
            startFresser()
        }
        if armed != nil { audio.play(.select, volume: 0.5) }
    }

    private func fire(_ mode: Armed, at p: Pos) {
        setArmed(nil)
        let c = center(of: p)
        switch mode {
        case .bomb:
            let result = game.useBomb(at: p)
            guard result.isValid else { return }
            busy = true
            updateSlots()
            audio.play(.bomb, volume: 0.9)
            audio.play(.explosion, volume: 1)
            haptics.explosion()
            fx.explosion(at: c, scale: 2.2)
            warp(at: c, strength: 8, color: SKColor(red: 1, green: 0.55, blue: 0.2, alpha: 1))
            shake(strength: 3)
            run(.sequence([.wait(forDuration: 0.12), .run { [weak self] in self?.play(result, index: 0) }]))

        case .atom:
            let result = game.useAtom(at: p)
            guard result.isValid else { return }
            busy = true
            updateSlots()
            audio.play(.bomb, volume: 1)
            audio.play(.explosion, volume: 1)
            audio.play(.warp, volume: 0.8)
            haptics.explosion()
            fx.explosion(at: c, scale: 3.4)
            for _ in 0..<6 {
                fx.explosion(at: CGPoint(x: c.x + CGFloat.random(in: -40...40), y: c.y + CGFloat.random(in: -40...40)), scale: 1.2)
            }
            let flash = fx.glow(at: c, color: .white, size: 400, alpha: 0.6)
            flash.run(.sequence([.fadeOut(withDuration: 0.5), .removeFromParent()]))
            warp(at: c, strength: 12, color: SKColor(red: 0.95, green: 0.85, blue: 0.3, alpha: 1))
            shake(strength: 4)
            run(.sequence([.wait(forDuration: 0.18), .run { [weak self] in self?.play(result, index: 0) }]))

        case .purge:
            guard let color = game.board.color(at: p) else { return }
            let targets = game.board.positions.filter { game.board.color(at: $0) == color }
            let result = game.usePurge(color)
            guard result.isValid else { return }
            busy = true
            updateSlots()
            audio.play(.purge, volume: 0.9)
            haptics.warp()
            let tint = GemArt.glowColor(color)
            fx.warpRing(at: c, color: tint, radius: 70)
            for (i, q) in targets.enumerated() where q != p {
                fx.lightning(from: c, to: center(of: q), color: tint, delay: Double(i) * 0.025)
            }
            run(.sequence([.wait(forDuration: 0.4), .run { [weak self] in self?.play(result, index: 0) }]))
        }
    }

    /// Strudel: alle Steine wirbeln an neue Plätze.
    private func shuffleBoard() {
        guard !busy else { return }
        let result = game.useShuffle()
        guard result.isValid else { return }
        busy = true
        setSelected(nil)
        updateSlots()
        audio.play(.warp, volume: 0.8)
        audio.play(.steam, volume: 0.5)
        haptics.warp()
        let mid = design(Layout.boardX + Layout.boardSize / 2, Layout.boardY + Layout.boardSize / 2)
        fx.warpRing(at: mid, color: SKColor(red: 0.7, green: 0.35, blue: 0.9, alpha: 1), radius: 120)

        if result.replacedBoard {
            gems.values.forEach { node in
                fx.steam(at: node.position)
                node.removeWithGlow()
            }
            gems = [:]
            var longest = 0.0
            for p in game.board.positions {
                guard let tile = game.board[tile: p] else { continue }
                let node = makeGem(tile.gem, at: Pos(p.col, p.row - Layout.count - 1), special: tile.special)
                gems[p] = node
                let delay = Double(p.col) * 0.03
                longest = max(longest, drop(node, to: p, rows: Layout.count + 1, delay: delay) + delay)
            }
            run(.sequence([.wait(forDuration: longest + 0.05), .run { [weak self] in self?.afterShuffle(result.isGameOver) }]))
            return
        }

        var moved: [Pos: GemNode] = [:]
        for (from, to) in result.moves {
            guard let node = gems[from] else { continue }
            moved[to] = node
            // Bogen über die Brettmitte
            let start = node.position, end = center(of: to)
            let swirl = SKAction.customAction(withDuration: 0.55) { n, elapsed in
                let t = elapsed / 0.55
                let e = t * t * (3 - 2 * t)
                let angle = (1 - e) * .pi * 1.2
                let base = CGPoint(x: start.x + (end.x - start.x) * e, y: start.y + (end.y - start.y) * e)
                let pull = sin(.pi * e) * 0.35
                let dx = base.x - mid.x, dy = base.y - mid.y
                n.position = CGPoint(x: (mid.x + (dx * cos(angle) - dy * sin(angle)) * (1 - pull)).rounded(),
                                     y: (mid.y + (dx * sin(angle) + dy * cos(angle)) * (1 - pull)).rounded())
            }
            node.removeAllActions()
            node.run(.sequence([swirl, .move(to: end, duration: 0.05)]))
        }
        gems = moved
        run(.sequence([.wait(forDuration: 0.65), .run { [weak self] in self?.afterShuffle(result.isGameOver) }]))
    }

    private func afterShuffle(_ isGameOver: Bool) {
        audio.play(.land, volume: 0.5)
        if isGameOver {
            showGameOver()
        } else {
            busy = false
        }
        refreshStatus()
    }

    // MARK: Fresser

    private func startFresser() {
        guard !busy, let round = game.startFresser() else { return }
        busy = true
        setSelected(nil)
        updateSlots()
        for node in gems.values where node.special != .hyper && round.stones.contains(node.gem) {
            node.isPetrified = true
            node.body.texture = stoneTextures[node.gem]
            fx.flash(at: node.position, color: SKColor(white: 0.7, alpha: 1))
        }
        let chomper = SKSpriteNode(texture: chomperFrames[0], size: CGSize(width: 18, height: 18))
        chomper.position = center(of: round.start)
        chomper.zPosition = 5
        chomper.run(.repeatForever(.animate(with: chomperFrames, timePerFrame: 0.06)))
        let light = SKSpriteNode(texture: glowTexture, color: Palette.amber.skColor, size: CGSize(width: 44, height: 44))
        light.colorBlendFactor = 1
        light.blendMode = .add
        light.alpha = 0.45
        chomper.addChild(light)
        fx.pixelLayer.addChild(chomper)

        fresser = FresserState(round: round, node: chomper, pos: round.start)
        eat(at: round.start)
        countdownLabel.isHidden = false
        audio.play(.powerUp, volume: 0.7)
        audio.play(.warp, volume: 0.5)
        haptics.warp()
        fx.warpRing(at: chomper.position, color: Palette.amber.skColor, radius: 60)
        refreshStatus()
    }

    private func passable(_ p: Pos, _ round: FresserRound) -> Bool {
        guard let gem = game.board.contains(p) ? game.board.color(at: p) : nil else { return false }
        return !round.stones.contains(gem)
    }

    private func eat(at p: Pos) {
        guard let f = fresser, !f.eaten.contains(p), let node = gems[p], !node.isPetrified else { return }
        fresser?.eaten.insert(p)
        gems.removeValue(forKey: p)
        let c = center(of: p)
        fx.flash(at: c, color: GemArt.glowColor(node.gem))
        fx.shrapnel(at: c, colors: sprites[node.gem]!.ramp.suffix(3).map(\.skColor), count: 5, power: 0.7)
        node.removeWithGlow()
        audio.chomp(count: f.eaten.count)
        if f.eaten.count % 3 == 0 { haptics.select() }
    }

    private func orient(_ node: SKSpriteNode, _ d: Direction) {
        node.xScale = d.dc < 0 ? -1 : 1
        node.zRotation = d.dr == 0 ? 0 : (d.dr < 0 ? .pi / 2 : -.pi / 2)
    }

    private func updateFresser(_ dt: TimeInterval) {
        guard let current = fresser, !settingsPanel.isVisible else { return }
        fresser?.timeLeft -= dt
        fresser?.stepTimer -= dt
        if current.stepTimer - dt <= 0 {
            fresser?.stepTimer += 0.13
            for d in [current.queued, current.dir].compactMap({ $0 }) {
                let next = Pos(current.pos.col + d.dc, current.pos.row + d.dr)
                guard passable(next, current.round) else { continue }
                fresser?.dir = d
                if d == current.queued { fresser?.queued = nil }
                fresser?.pos = next
                current.node.run(.move(to: center(of: next), duration: 0.12))
                orient(current.node, d)
                eat(at: next)
                break
            }
        }
        guard let f = fresser else { return }
        let seconds = max(0, Int(ceil(f.timeLeft)))
        if seconds != f.shownSeconds {
            fresser?.shownSeconds = seconds
            setText(countdownLabel, "FRESSER \(seconds)", color: seconds <= 3 ? Palette.red : Palette.amber, scale: 2)
            if seconds <= 3 && seconds > 0 { audio.play(.select, volume: 0.5) }
        }
        let edible = game.board.positions.filter { passable($0, f.round) }.count
        if f.timeLeft <= 0 || f.eaten.count >= edible {
            endFresser()
        }
    }

    private func endFresser() {
        guard let f = fresser else { return }
        fresser = nil
        countdownLabel.isHidden = true
        fx.steam(at: f.node.position)
        f.node.run(.sequence([.fadeOut(withDuration: 0.25), .removeFromParent()]))
        for node in gems.values where node.isPetrified {
            node.isPetrified = false
            node.body.texture = sprites[node.gem]!.texture
            applySpecial(node.special, to: node)
            fx.flash(at: node.position, color: GemArt.glowColor(node.gem))
        }
        audio.play(.cascade, volume: 0.6)
        refreshStatus()
        let result = game.finishFresser(f.round, eaten: f.eaten)
        run(.sequence([.wait(forDuration: 0.3), .run { [weak self] in self?.play(result, index: 0) }]))
    }

    // MARK: Plan, Figur, Belohnungen

    /// Atmen und hin und wieder ein Blick zurück.
    private func startFigureIdle() {
        figure.texture = figureIdle[0]
        figure.xScale = 1
        figure.run(.repeatForever(.animate(with: figureIdle, timePerFrame: 0.5)), withKey: "idle")
        let figure = self.figure
        figure.run(.repeatForever(.sequence([
            .wait(forDuration: 6, withRange: 6),
            .run { figure.xScale = -1 },
            .wait(forDuration: 0.9, withRange: 0.6),
            .run { figure.xScale = 1 },
        ])), withKey: "look")
    }

    private func stopFigureIdle() {
        figure.removeAction(forKey: "idle")
        figure.removeAction(forKey: "look")
        figure.xScale = 1
    }

    /// Spielstart: die Figur fällt aus dem Nichts auf ihr erstes Dach.
    private func dropFigureIn(after delay: TimeInterval) {
        figureJumping = true
        stopFigureIdle()
        figure.texture = figureJump
        figure.alpha = 0
        let duration: CGFloat = 0.55
        let fall = SKAction.customAction(withDuration: TimeInterval(duration)) { [weak self] node, elapsed in
            guard let self else { return }
            let b = self.game.city.buildings[min(self.shownBuilding, self.game.city.buildings.count - 1)]
            let target = self.design(CGFloat(self.game.city.screenX(b.center)).rounded(), self.skyBottom - CGFloat(b.height))
            let t = min(1, elapsed / duration)
            node.alpha = min(1, t * 4)
            node.position = CGPoint(x: target.x, y: (target.y + 80 * (1 - t * t)).rounded())
        }
        figure.run(.sequence([.wait(forDuration: delay), fall, .run { [weak self] in
            guard let self else { return }
            self.figureJumping = false
            self.updateCity()
            self.startFigureIdle()
            self.audio.play(.land, volume: 0.6)
            self.fx.steam(at: self.figure.position)
            self.fx.shrapnel(at: self.figure.position, colors: [RGBA(hex: 0x3FD8FF).skColor, .white], count: 8, power: 0.4, bounces: false)
        }]))
    }

    /// Sprung auf das Haus mit Index `building`. Das Ziel wandert während des Sprungs mit.
    private func jumpFigure(to building: Int, then completion: @escaping () -> Void) {
        guard building < game.city.buildings.count, !figureFalling else {
            shownBuilding = min(building, game.city.buildings.count - 1)
            completion()
            return
        }
        figureJumping = true
        audio.play(.jump, volume: 0.6)
        stopFigureIdle()
        figure.texture = figureJump
        let from = figure.position
        fx.steam(at: CGPoint(x: from.x, y: from.y + 3))
        let duration: CGFloat = 0.7
        let arc = SKAction.customAction(withDuration: TimeInterval(duration)) { [weak self] node, elapsed in
            guard let self else { return }
            let b = self.game.city.buildings[building]
            let to = self.design(CGFloat(self.game.city.screenX(b.center)), self.skyBottom - CGFloat(b.height))
            // Halbe Sinuskurve: deutlich über beide Dächer hinweg
            let height = 26 + abs(to.y - from.y) / 2
            let t = min(1, elapsed / duration)
            node.position = CGPoint(x: (from.x + (to.x - from.x) * t).rounded(),
                                    y: (from.y + (to.y - from.y) * t + sin(.pi * t) * height).rounded())
        }
        figure.run(.sequence([arc, .run { [weak self] in
            guard let self else { return }
            self.shownBuilding = building
            self.figureJumping = false
            self.updateCity()
            self.startFigureIdle()
            self.audio.play(.land, volume: 0.5)
            self.fx.steam(at: self.figure.position)
            self.refreshStatus()
            completion()
        }]))
    }

    /// Plan erfüllt: Fanfare und Konfetti. Im Dächerlauf springt die Figur und bringt ein Power-up.
    private func celebrate(_ reward: PlanReward) {
        audio.play(.plan, volume: 0.7)
        haptics.plan()
        let mid = design(Layout.boardX + Layout.boardSize / 2, Layout.boardY + Layout.boardSize / 2)
        fx.warpRing(at: mid, color: Palette.amber.skColor, radius: 130)
        fx.popup("SPRUNG \(reward.plan - 1) GESCHAFFT!", at: CGPoint(x: mid.x, y: mid.y + 10), color: Palette.amber, scale: 2)
        for (i, gem) in Gem.allCases.enumerated() {
            let x = CGFloat(Layout.boardX) + CGFloat(i) / 6 * CGFloat(Layout.boardSize)
            fx.shrapnel(at: design(x, CGFloat(Layout.boardY)), colors: sprites[gem]!.ramp.suffix(3).map(\.skColor), count: 14, power: 1.3)
        }
        guard let building = reward.building else { return }
        jumpFigure(to: building) { [weak self] in
            guard let self else { return }
            let slotLabel = self.design(Layout.slotX(1), Layout.slotY - 6)
            if let kind = reward.powerUp {
                self.fx.popup("+ " + Self.name(kind), at: slotLabel, color: Palette.amber)
                self.deliver(kind)
            } else if reward.bonusPoints > 0 {
                self.fx.popup("LAGER VOLL +\(reward.bonusPoints)", at: slotLabel, color: Palette.cream)
            }
            if reward.reachedTop { self.heroFireworks() }
        }
    }

    /// Ende eines Belohnungszyklus: Feuerwerk über der Stadt.
    private func heroFireworks() {
        let top = figure.position
        fx.popup("HELD DER ARBEIT!", at: CGPoint(x: min(max(top.x, 50), Layout.width - 50), y: top.y + 22), color: Palette.amber)
        let colors = Gem.allCases.map { GemArt.glowColor($0) }
        for i in 0..<6 {
            let p = CGPoint(x: top.x + CGFloat.random(in: -60...40), y: top.y + CGFloat.random(in: 25...70))
            run(.sequence([.wait(forDuration: Double(i) * 0.22), .run { [weak self] in
                self?.fx.firework(at: p, colors: colors)
                self?.audio.play(.shrapnel, volume: 0.5)
            }]))
        }
    }

    // MARK: Eingabe

    private func pointerDown(_ point: CGPoint) {
        idleTime = 0
        place(hintCursor, at: nil)
        let d = CGPoint(x: point.x, y: Layout.height - point.y)
        if helpPanel.isVisible {
            helpPanel.pointerDown(d)
            return
        }
        if settingsPanel.isVisible {
            settingsPanel.pointerDown(d)
            return
        }
        if gearRect.contains(d) && fresser == nil {
            pointerStart = nil
            setArmed(nil)
            setSelected(nil)
            audio.play(.select, volume: 0.5)
            settingsPanel.show()
            return
        }
        if menuVisible {
            handleMenu(point)
            return
        }
        if fresser != nil {
            swipeStart = point
            return
        }
        if game.isOver { return }
        if let slot = slotIndex(at: point) {
            pointerStart = nil
            handleSlot(slot)
            return
        }
        if let mode = armed {
            pointerStart = nil
            guard !busy else { return }
            if let p = cell(at: point) {
                fire(mode, at: p)
            } else {
                setArmed(nil)
            }
            return
        }
        guard !busy, let p = cell(at: point) else {
            pointerStart = nil
            return
        }
        pointerStart = (p, point)
    }

    private func pointerMoved(_ point: CGPoint) {
        if helpPanel.isVisible { return }
        if settingsPanel.isVisible {
            settingsPanel.pointerMoved(CGPoint(x: point.x, y: Layout.height - point.y))
            return
        }
        if fresser != nil {
            guard let start = swipeStart else { return }
            let dx = point.x - start.x, dy = point.y - start.y
            guard max(abs(dx), abs(dy)) >= 6 else { return }
            fresser?.queued = abs(dx) > abs(dy)
                ? Direction(dc: dx > 0 ? 1 : -1, dr: 0)
                : Direction(dc: 0, dr: dy > 0 ? -1 : 1)
            swipeStart = point
            return
        }
        guard let start = pointerStart, !busy else { return }
        let dx = point.x - start.point.x, dy = point.y - start.point.y
        guard max(abs(dx), abs(dy)) >= 7 else { return }
        pointerStart = nil
        // Welt-y zeigt nach oben, Zeilen zählen nach unten
        let target = abs(dx) > abs(dy)
            ? Pos(start.pos.col + (dx > 0 ? 1 : -1), start.pos.row)
            : Pos(start.pos.col, start.pos.row + (dy > 0 ? -1 : 1))
        guard game.board.contains(target) else { return }
        setSelected(nil)
        attemptSwap(start.pos, target)
    }

    private func pointerUp(_ point: CGPoint) {
        swipeStart = nil
        if helpPanel.isVisible { return }
        if settingsPanel.isVisible {
            settingsPanel.pointerUp()
            return
        }
        guard let start = pointerStart else { return }
        pointerStart = nil
        guard let current = selected else {
            setSelected(start.pos)
            return
        }
        if current == start.pos {
            setSelected(nil)
        } else if current.isAdjacent(to: start.pos) {
            setSelected(nil)
            attemptSwap(current, start.pos)
        } else {
            setSelected(start.pos)
        }
    }

    #if os(iOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let t = touches.first { pointerDown(t.location(in: shaker)) }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let t = touches.first { pointerMoved(t.location(in: shaker)) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let t = touches.first { pointerUp(t.location(in: shaker)) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        pointerStart = nil
    }
    #else
    override func mouseDown(with event: NSEvent) {
        pointerDown(event.location(in: shaker))
    }

    override func mouseDragged(with event: NSEvent) {
        pointerMoved(event.location(in: shaker))
    }

    override func mouseUp(with event: NSEvent) {
        pointerUp(event.location(in: shaker))
    }
    #endif

    // MARK: Bildaufbau

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate == 0 ? 1.0 / 60 : min(0.05, currentTime - lastUpdate)
        lastUpdate = currentTime
        clock += dt
        fx.update(CGFloat(dt))

        let boardTop = Layout.height - CGFloat(Layout.boardY)
        for case let gem as GemNode in gemLayer.children {
            let v = gem.visualPosition
            gem.glow.position = v
            if gem.isDying { continue }
            gem.glow.isHidden = gem.position.y > boardTop || gem.isPetrified
            gem.glow.alpha = CGFloat(0.16 + 0.05 * sin(clock * 2.2 + Double(v.x) / 22 * 0.9 + Double(v.y) / 22 * 1.3))
        }

        let target = Double(game.score)
        displayedScore += (target - displayedScore) * min(1, dt * 6)
        if abs(target - displayedScore) < 0.5 { displayedScore = target }
        let shown = Int(displayedScore.rounded())
        if shown != shownScore {
            shownScore = shown
            setText(scoreLabel, String(format: "%08d", shown), color: Palette.amber, scale: 2)
        }

        updateFresser(dt)

        // Lebendige Stadt: Fensterlicht und Sternschnuppen
        windowTimer -= dt
        if windowTimer <= 0 {
            windowTimer = Double.random(in: 2.5...7)
            toggleRandomWindow()
        }
        shootingStarTimer -= dt
        if shootingStarTimer <= 0 {
            shootingStarTimer = Double.random(in: 14...40)
            shootingStar()
        }

        if mode == .rooftop && !menuVisible && !figureFalling && !settingsPanel.isVisible {
            if game.tick(dt) {
                busy = true
                figureFall()
            }
            updateCity()
            let danger = game.city.isInDanger && !game.isOver
            if danger != wasInDanger {
                wasInDanger = danger
                refreshStatus()
            }
            // Je näher am Rand, desto lauter brummt der Alarm
            let level = danger ? Float(1 - max(0, game.city.figureX) / City.dangerX) : 0
            audio.setDanger(level)
            // Roter Glow um die Figur, pulsiert mit dem Brummen und wird stärker, je näher der Rand
            let pulse = 0.75 + 0.25 * sin(clock * 2 * .pi * 1.5)
            dangerAura.alpha = CGFloat(Double(level) * 0.85 * pulse)
            dangerAura.setScale(CGFloat(0.9 + 0.5 * Double(level)))
            // Rahmen sofort sichtbar, sobald Gefahr besteht, und stärker je näher der Rand
            edgeGlow.alpha = danger ? CGFloat((0.35 + 0.55 * Double(level)) * pulse) : 0
            duckMusic(danger ? 0.45 : 1, dt: dt)
        } else {
            audio.setDanger(0)
            dangerAura.alpha = 0
            edgeGlow.alpha = 0
            duckMusic(1, dt: dt)
        }

        if !busy && !game.isOver && pointerStart == nil && armed == nil && game.hasValidMove {
            idleTime += dt
            if idleTime > 7, hintCursor.isHidden, GameSettings.shared.hintsEnabled, let move = game.hint() {
                place(hintCursor, at: move.a)
            }
        }
    }
}
