import SpriteKit

/// Einstellungen als Pixel-Ansicht über dem Spiel: gleicher Hintergrund, Pixelschrift,
/// Schalter (AN/AUS) und Schieberegler aus Segmenten. Koordinaten in Design-Pixeln (oben links, y nach unten).
final class SettingsPanel {
    let node = SKNode()
    var onClose: () -> Void = {}
    var onNewGame: () -> Void = {}
    var onHelp: () -> Void = {}
    /// Debug: legt Invasion und Abrissbirne ins Lager.
    var onTestArcade: () -> Void = {}
    var onChange: () -> Void = {}
    private(set) var isVisible = false

    private enum Kind {
        case section
        case toggle(get: () -> Bool, set: (Bool) -> Void)
        case slider(get: () -> Double, set: (Double) -> Void)
        case choice(options: [String], get: () -> Int, set: (Int) -> Void)
        case button(action: () -> Void)
    }

    private struct Row {
        let label: () -> String
        let kind: Kind
        let y: Int
        let sprite: SKSpriteNode
    }

    private static let amber = RGBA(hex: 0xFFB347)
    private static let cream = RGBA(hex: 0xFFF3D6)
    private static let gray = RGBA(hex: 0x9A9CAB)
    private static let dim = RGBA(hex: 0x4A4B56)

    private let designHeight: CGFloat
    private let x0 = 8, y0 = 10, width = 184, height = 338
    private let rowWidth = 168
    private let trackX = 62, trackWidth = 104
    private var rows: [Row] = []
    private var dragging: Int?

    init(designHeight: CGFloat) {
        self.designHeight = designHeight
        node.isHidden = true
        build()
    }

    private func world(_ x: Int, _ y: Int) -> CGPoint {
        CGPoint(x: CGFloat(x), y: designHeight - CGFloat(y))
    }

    private func sprite(_ canvas: PixelCanvas, at x: Int, _ y: Int, scale: CGFloat = 1) -> SKSpriteNode {
        let s = SKSpriteNode(texture: canvas.texture(), size: CGSize(width: CGFloat(canvas.width) * scale, height: CGFloat(canvas.height) * scale))
        s.anchorPoint = CGPoint(x: 0, y: 1)
        s.position = world(x, y)
        return s
    }

    private func build() {
        // Hintergrund: dunkle Platte mit Scanlines, Rahmen und Warnstreifen
        var back = PixelCanvas(width: width, height: height, fill: RGBA(hex: 0x0B0A11, alpha: 236))
        for y in stride(from: 1, to: height, by: 2) { back.fillRect(1, y, width - 2, 1, RGBA(hex: 0x14121C, alpha: 236)) }
        for (x, y, w, h) in [(0, 0, width, 1), (0, height - 1, width, 1), (0, 0, 1, height), (width - 1, 0, 1, height)] {
            back.fillRect(x, y, w, h, Self.amber)
        }
        for y in 21..<25 {
            for x in 1..<(width - 1) {
                back.set(x, y, ((x + y) >> 2) & 1 == 1 ? RGBA(hex: 0xB8321F) : RGBA(hex: 0x1A1418))
            }
        }
        node.addChild(sprite(back, at: x0, y0))
        let title = PixelFont.render("EINSTELLUNGEN", color: Self.amber, shadow: RGBA(hex: 0x050409))
        node.addChild(sprite(title, at: x0 + (width - title.width * 2) / 2, y0 + 6, scale: 2))

        buildRows()
    }

    /// Zeilen neu aufbauen, z. B. wenn die Debug-Regler ein- oder ausgeblendet werden.
    private func buildRows() {
        rows.forEach { $0.sprite.removeFromParent() }
        rows = []
        let settings = GameSettings.shared
        func fixed(_ text: String) -> () -> String { { text } }
        var specs: [(() -> String, Kind)] = [
            (fixed("TON"), .section),
            (fixed("EFFEKTE"), .toggle(get: { settings.soundEnabled }, set: { settings.soundEnabled = $0 })),
            (fixed("LAUTST."), .slider(get: { settings.soundVolume }, set: { settings.soundVolume = $0 })),
            (fixed("MUSIK"), .toggle(get: { settings.musicEnabled }, set: { settings.musicEnabled = $0 })),
            (fixed("LAUTST."), .slider(get: { settings.musicVolume }, set: { settings.musicVolume = $0 })),
            (fixed("SPIEL"), .section),
            (fixed("FUNKSPRÜCHE"), .toggle(get: { settings.splashesEnabled }, set: { settings.splashesEnabled = $0 })),
            (fixed("HINWEISE"), .toggle(get: { settings.hintsEnabled }, set: { settings.hintsEnabled = $0 })),
        ]
        if FireWall.enabled {
            specs.append((fixed("FEUER"), .toggle(get: { settings.fireEnabled }, set: { settings.fireEnabled = $0 })))
        }
        #if os(iOS)
        specs.append((fixed("HAPTIK"), .toggle(get: { settings.hapticsEnabled }, set: { settings.hapticsEnabled = $0 })))
        #endif
        specs.append((fixed("APP-ICON"), .choice(options: ["1", "2"], get: { settings.appIcon }, set: { settings.appIcon = $0 })))
        specs.append((fixed("DEBUG-REGLER"), .toggle(get: { settings.debugVisible }, set: { [weak self] visible in
            settings.debugVisible = visible
            self?.buildRows()
        })))
        if settings.debugVisible {
            // Stadt-Tempo 0,2 … 4,0 Pixel pro Sekunde, Schieber 0 … 1
            let minSpeed = 0.2, maxSpeed = 4.0
            specs.append((fixed("DEBUG: STADT-TEMPO PX/S"), .section))
            specs.append(({ String(format: "%.2f", settings.debugCitySpeed) },
                          .slider(get: { (settings.debugCitySpeed - minSpeed) / (maxSpeed - minSpeed) },
                                  set: { settings.debugCitySpeed = minSpeed + $0 * (maxSpeed - minSpeed) })))
            // Beschleunigung 0 … 50 % pro Spielminute
            specs.append((fixed("DEBUG: BESCHLEUNIGUNG PRO MIN"), .section))
            specs.append(({ "+" + String(Int((settings.debugCityAcceleration * 100).rounded())) + "%" },
                          .slider(get: { settings.debugCityAcceleration / 0.5 },
                                  set: { settings.debugCityAcceleration = $0 * 0.5 })))
        }
        if settings.debugVisible {
            specs.append((fixed("MINISPIELE"), .button(action: { [weak self] in self?.onTestArcade() })))
        }
        specs.append((fixed("NEUES SPIEL"), .button(action: { [weak self] in self?.onNewGame() })))
        specs.append((fixed("HILFE"), .button(action: { [weak self] in self?.onHelp() })))
        specs.append((fixed("ZURÜCK"), .button(action: { [weak self] in self?.onClose() })))

        var y = y0 + 34
        for (label, kind) in specs {
            if case .section = kind, y > y0 + 40 { y += 4 }
            if case .button = kind, !rows.contains(where: { if case .button = $0.kind { return true }; return false }) { y += 3 }
            let s = SKSpriteNode()
            s.anchorPoint = CGPoint(x: 0, y: 1)
            s.position = world(x0 + 8, y)
            node.addChild(s)
            rows.append(Row(label: label, kind: kind, y: y, sprite: s))
            switch kind {
            case .section: y += 9
            case .button: y += 19
            default: y += 14
            }
        }
        render()
    }

    private func render() {
        for row in rows {
            var c: PixelCanvas
            switch row.kind {
            case .section:
                c = PixelCanvas(width: rowWidth, height: 7)
                let text = row.label()
                PixelFont.draw(text, into: &c, x: 0, y: 1, color: Self.gray)
                c.fillRect(PixelFont.width(text) + 4, 3, rowWidth - PixelFont.width(text) - 4, 1, Self.dim)

            case .toggle(let get, _):
                c = PixelCanvas(width: rowWidth, height: 11)
                PixelFont.draw(row.label(), into: &c, x: 0, y: 3, color: Self.cream)
                let on = get()
                let bx = rowWidth - 38
                for (i, text) in ["AN", "AUS"].enumerated() {
                    let active = (i == 0) == on
                    let x = bx + i * 19
                    c.fillRect(x, 0, 18, 11, active ? Self.amber : RGBA(hex: 0x1B1A24))
                    c.fillRect(x, 0, 18, 1, active ? Self.cream : Self.dim)
                    c.fillRect(x, 10, 18, 1, active ? RGBA(hex: 0xB4521C) : Self.dim)
                    PixelFont.draw(text, into: &c, x: x + (18 - PixelFont.width(text)) / 2, y: 3, color: active ? RGBA(hex: 0x1A0A06) : Self.dim)
                }

            case .choice(let options, let get, _):
                c = PixelCanvas(width: rowWidth, height: 11)
                PixelFont.draw(row.label(), into: &c, x: 0, y: 3, color: Self.cream)
                let selected = get()
                let bx = rowWidth - options.count * 19 + 1
                for (i, text) in options.enumerated() {
                    let active = i == selected
                    let x = bx + i * 19
                    c.fillRect(x, 0, 18, 11, active ? Self.amber : RGBA(hex: 0x1B1A24))
                    c.fillRect(x, 0, 18, 1, active ? Self.cream : Self.dim)
                    c.fillRect(x, 10, 18, 1, active ? RGBA(hex: 0xB4521C) : Self.dim)
                    PixelFont.draw(text, into: &c, x: x + (18 - PixelFont.width(text)) / 2, y: 3, color: active ? RGBA(hex: 0x1A0A06) : Self.dim)
                }

            case .slider(let get, _):
                c = PixelCanvas(width: rowWidth, height: 11)
                PixelFont.draw(row.label(), into: &c, x: 8, y: 3, color: Self.gray)
                let value = clamp(get(), 0, 1)
                let tx = trackX - 8 - x0
                c.fillRect(tx - 1, 2, trackWidth + 2, 7, RGBA(hex: 0x050409))
                let segments = trackWidth / 4
                let filled = Int((value * Double(segments)).rounded())
                for i in 0..<segments {
                    c.fillRect(tx + i * 4, 3, 3, 5, i < filled ? (i < 3 ? RGBA(hex: 0xE0452B) : Self.amber) : RGBA(hex: 0x221E2A))
                }
                let knob = tx + Int(value * Double(trackWidth - 3))
                c.fillRect(knob, 0, 3, 11, Self.cream)
                c.fillRect(knob, 10, 3, 1, RGBA(hex: 0xB8B0A2))

            case .button:
                c = PixelCanvas(width: rowWidth, height: 18)
                let w = 120, x = (rowWidth - w) / 2
                c.fillRect(x, 0, w, 18, RGBA(hex: 0x1B1A24))
                c.fillRect(x, 0, w, 1, Self.amber)
                c.fillRect(x, 17, w, 1, Self.amber)
                c.fillRect(x, 0, 1, 18, Self.amber)
                c.fillRect(x + w - 1, 0, 1, 18, Self.amber)
                // Beschriftung doppelt groß
                let label = PixelFont.render(row.label(), color: Self.cream)
                let lx = x + (w - label.width * 2) / 2
                for yy in 0..<label.height * 2 {
                    for xx in 0..<label.width * 2 where label.get(xx / 2, yy / 2).a > 0 {
                        c.set(lx + xx, 4 + yy, Self.cream)
                    }
                }
            }
            row.sprite.texture = c.texture()
            row.sprite.size = c.size
        }
    }

    // MARK: Sichtbarkeit

    func show() {
        render()
        isVisible = true
        node.isHidden = false
        node.alpha = 0
        node.run(.fadeIn(withDuration: 0.12))
    }

    func hide() {
        isVisible = false
        dragging = nil
        node.run(.sequence([.fadeOut(withDuration: 0.1), .hide()]))
    }

    // MARK: Eingabe (Design-Koordinaten)

    private func rowIndex(at p: CGPoint) -> Int? {
        rows.firstIndex { row in
            let h: Int
            switch row.kind {
            case .section: return false
            case .button: h = 18
            default: h = 11
            }
            return p.y >= CGFloat(row.y - 2) && p.y < CGFloat(row.y + h + 2) && p.x >= CGFloat(x0) && p.x < CGFloat(x0 + width)
        }
    }

    func pointerDown(_ p: CGPoint) {
        guard let i = rowIndex(at: p) else { return }
        switch rows[i].kind {
        case .toggle(let get, let set):
            set(!get())
            onChange()
            render()
        case .choice(let options, let get, let set):
            // Auf ein Feld getippt: dieses wählen; sonst (Beschriftung) weiterschalten
            let bx = CGFloat(x0 + 8 + rowWidth - options.count * 19 + 1)
            set(p.x >= bx ? min(Int((p.x - bx) / 19), options.count - 1) : (get() + 1) % options.count)
            onChange()
            render()
        case .slider:
            dragging = i
            slide(to: p)
        case .button(let action):
            onChange()
            action()
        case .section:
            break
        }
    }

    func pointerMoved(_ p: CGPoint) {
        guard dragging != nil else { return }
        slide(to: p)
    }

    func pointerUp() {
        if dragging != nil { onChange() }
        dragging = nil
    }

    private func slide(to p: CGPoint) {
        guard let i = dragging, case .slider(_, let set) = rows[i].kind else { return }
        let value = (Double(p.x) - Double(trackX)) / Double(trackWidth)
        set(clamp((value * 100).rounded() / 100, 0, 1))
        render()
    }
}
