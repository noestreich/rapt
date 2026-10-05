/// Ein Plattenbau der vorderen Häuserreihe. `x` ist die linke Kante in Stadtkoordinaten (Design-Pixel).
public struct Building: Equatable, Sendable {
    public let x: Double
    public let width: Int
    public let height: Int

    public var center: Double { x + Double(width) / 2 }
    public var right: Double { x + Double(width) }
}

/// Die Häuserzeile wandert langsam nach links; rechts entstehen laufend neue Häuser.
/// Die Figur steht auf einem Dach und springt mit jedem erfüllten Plan ein Haus weiter.
/// Wird sie links aus dem Bild geschoben, ist das Spiel verloren.
public struct City: Sendable {
    /// Grundgeschwindigkeit in Design-Pixeln pro Sekunde.
    public static let baseSpeed = 0.45
    /// Zusätzliche Geschwindigkeit pro erreichtem Plan.
    public static let speedPerPlan = 0.04
    /// Breite des Spielbereichs; links von 0 ist die Figur verloren.
    public static let viewWidth = 200.0
    /// Ab dieser Position (Figurmitte) warnt das Spiel.
    public static let dangerX = 40.0

    public private(set) var buildings: [Building] = []
    /// Wie weit die Stadt schon nach links gewandert ist.
    public private(set) var offset = 0.0
    public private(set) var figureIndex = 0
    private var rng: SplitMix64

    public init(seed: UInt64, startX: Double = 140) {
        rng = SplitMix64(seed: seed ^ 0xC17C_17C1)
        extend(to: Self.viewWidth + 80)
        figureIndex = buildings.indices.min { abs(buildings[$0].center - startX) < abs(buildings[$1].center - startX) } ?? 0
    }

    /// Bildschirmposition (Design-Pixel) einer Stadtkoordinate.
    public func screenX(_ x: Double) -> Double { x - offset }

    public var figureBuilding: Building { buildings[figureIndex] }

    /// Mitte des Dachs, auf dem die Figur steht, in Bildschirmkoordinaten.
    public var figureX: Double { screenX(figureBuilding.center) }

    public var isFigureLost: Bool { figureX < 0 }
    public var isInDanger: Bool { figureX < Self.dangerX }

    public static func speed(plan: Int) -> Double {
        baseSpeed + speedPerPlan * Double(max(0, plan - 1))
    }

    public mutating func advance(by seconds: Double, plan: Int) {
        offset += Self.speed(plan: plan) * seconds
        extend(to: offset + Self.viewWidth + 80)
    }

    /// Figur springt aufs nächste Haus rechts. Gibt dessen Index zurück.
    @discardableResult
    public mutating func jump() -> Int {
        figureIndex += 1
        extend(to: figureBuilding.right + Self.viewWidth)
        return figureIndex
    }

    /// Erzeugt Häuser, bis die Zeile mindestens bis `x` (Stadtkoordinate) reicht.
    public mutating func extend(to x: Double) {
        var next = buildings.last.map { $0.right + Double(2 + Int(rng.unit() * 4)) } ?? -8
        while next < x {
            let width = 22 + Int(rng.unit() * 18)
            let height = 26 + Int(rng.unit() * 34)
            buildings.append(Building(x: next, width: width, height: height))
            next += Double(width + 2 + Int(rng.unit() * 4))
        }
    }
}
