import SpriteKit

/// 3×5-Pixelschrift: Großbuchstaben mit Umlauten, Ziffern und ein paar Zeichen.
/// Texte immer in Großbuchstaben übergeben; „ß“ als „SS“ schreiben.
enum PixelFont {
    static let lineHeight = 5

    private static let glyphs: [Character: [String]] = [
        "0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
        "2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "011", "001", "111"],
        "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
        "6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
        "8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
        "A": ["010", "101", "111", "101", "101"], "B": ["110", "101", "110", "101", "110"],
        "C": ["011", "100", "100", "100", "011"], "D": ["110", "101", "101", "101", "110"],
        "E": ["111", "100", "110", "100", "111"], "F": ["111", "100", "110", "100", "100"],
        "G": ["011", "100", "101", "101", "011"], "H": ["101", "101", "111", "101", "101"],
        "I": ["111", "010", "010", "010", "111"], "J": ["001", "001", "001", "101", "010"],
        "K": ["101", "110", "100", "110", "101"], "L": ["100", "100", "100", "100", "111"],
        "M": ["10001", "11011", "10101", "10001", "10001"], "N": ["1001", "1101", "1011", "1001", "1001"],
        "O": ["010", "101", "101", "101", "010"], "P": ["110", "101", "110", "100", "100"],
        "Q": ["010", "101", "101", "110", "011"], "R": ["110", "101", "110", "101", "101"],
        "S": ["011", "100", "010", "001", "110"], "T": ["111", "010", "010", "010", "010"],
        "U": ["101", "101", "101", "101", "111"], "V": ["101", "101", "101", "101", "010"],
        "W": ["10001", "10001", "10101", "11011", "10001"], "X": ["101", "101", "010", "101", "101"],
        "Y": ["101", "101", "010", "010", "010"], "Z": ["111", "001", "010", "100", "111"],
        // Umlaute: Punkte in der obersten Zeile, Buchstabe darunter gestaucht
        "Ä": ["101", "010", "101", "111", "101"], "Ö": ["101", "010", "101", "101", "010"],
        "Ü": ["101", "000", "101", "101", "111"],
        "x": ["000", "101", "010", "101", "000"], "+": ["000", "010", "111", "010", "000"],
        "-": ["000", "000", "111", "000", "000"], ":": ["0", "1", "0", "1", "0"],
        ".": ["0", "0", "0", "0", "1"], "!": ["1", "1", "1", "0", "1"], "/": ["001", "001", "010", "100", "100"],
        "%": ["101", "001", "010", "100", "101"],
        " ": ["0", "0", "0", "0", "0"],
    ]

    private static func glyph(_ ch: Character) -> [String] {
        glyphs[ch] ?? glyphs[" "]!
    }

    static func width(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        return text.reduce(0) { $0 + glyph($1)[0].count + 1 } - 1
    }

    static func draw(_ text: String, into canvas: inout PixelCanvas, x: Int, y: Int, color: RGBA) {
        var cx = x
        for ch in text {
            let g = glyph(ch)
            for (row, line) in g.enumerated() {
                for (col, bit) in line.enumerated() where bit == "1" {
                    canvas.set(cx + col, y + row, color)
                }
            }
            cx += g[0].count + 1
        }
    }

    /// Text als Pixelbild, optional mit 1-px-Schatten nach rechts unten.
    static func render(_ text: String, color: RGBA, shadow: RGBA? = nil) -> PixelCanvas {
        let extra = shadow == nil ? 0 : 1
        var canvas = PixelCanvas(width: width(text) + extra, height: lineHeight + extra)
        if let shadow { draw(text, into: &canvas, x: 1, y: 1, color: shadow) }
        draw(text, into: &canvas, x: 0, y: 0, color: color)
        return canvas
    }
}
