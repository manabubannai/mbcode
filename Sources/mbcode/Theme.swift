import AppKit

// 配色テーマ。config.json の "theme" で切り替える。
struct Theme {
    let name: String
    let background: NSColor
    let foreground: NSColor
    let cursor: NSColor

    static let all: [Theme] = [
        Theme(name: "manabu-dark",
              background: NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.11, alpha: 1.0),
              foreground: NSColor(calibratedWhite: 0.92, alpha: 1.0),
              cursor: NSColor(calibratedRed: 0.35, green: 0.85, blue: 0.55, alpha: 1.0)),
        Theme(name: "solarized-dark",
              background: NSColor(calibratedRed: 0.00, green: 0.17, blue: 0.21, alpha: 1.0),
              foreground: NSColor(calibratedRed: 0.51, green: 0.58, blue: 0.59, alpha: 1.0),
              cursor: NSColor(calibratedRed: 0.71, green: 0.54, blue: 0.00, alpha: 1.0)),
        Theme(name: "gruvbox-dark",
              background: NSColor(calibratedRed: 0.16, green: 0.16, blue: 0.16, alpha: 1.0),
              foreground: NSColor(calibratedRed: 0.92, green: 0.86, blue: 0.70, alpha: 1.0),
              cursor: NSColor(calibratedRed: 0.98, green: 0.74, blue: 0.18, alpha: 1.0)),
        Theme(name: "light",
              background: NSColor(calibratedWhite: 0.99, alpha: 1.0),
              foreground: NSColor(calibratedWhite: 0.15, alpha: 1.0),
              cursor: NSColor(calibratedRed: 0.20, green: 0.45, blue: 0.95, alpha: 1.0)),
    ]

    static func named(_ name: String) -> Theme {
        all.first { $0.name == name } ?? all[0]
    }
}
