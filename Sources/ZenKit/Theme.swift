import AppKit

// 配色テーマ。config.json の "theme" で切り替える。
// clear-light はマナブの Terminal.app「Clear Light」プロファイルの実測値を移植したもの。
public struct Theme {
    public let name: String
    public let background: NSColor
    public let foreground: NSColor
    public let cursor: NSColor
    public var selection: NSColor? = nil
    public var ansi: [NSColor]? = nil        // ANSI 16色（通常8 + 明るい8）
    public var backgroundAlpha: CGFloat = 1.0
    public var blur: Bool = false            // 半透明背景にすりガラスのぼかしをかける

    public init(name: String, background: NSColor, foreground: NSColor, cursor: NSColor,
                selection: NSColor? = nil, ansi: [NSColor]? = nil,
                backgroundAlpha: CGFloat = 1.0, blur: Bool = false) {
        self.name = name
        self.background = background
        self.foreground = foreground
        self.cursor = cursor
        self.selection = selection
        self.ansi = ansi
        self.backgroundAlpha = backgroundAlpha
        self.blur = blur
    }

    private static func rgb(_ hex: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1.0)
    }

    public static let all: [Theme] = [
        Theme(name: "clear-light",
              background: rgb(0xFFFFFF),
              foreground: rgb(0x111E25),
              cursor: rgb(0x919191),
              selection: rgb(0xB7D6FF),
              ansi: [
                rgb(0x0E161C), rgb(0xB35547), rgb(0x6CAA70), rgb(0xC4AB62),
                rgb(0x5685A7), rgb(0xAC63BD), rgb(0x69C5C8), rgb(0xC1C8CC),
                rgb(0x0B1319), rgb(0xDF6C59), rgb(0x78BD7D), rgb(0xE5C871),
                rgb(0x48A1E1), rgb(0xD389E5), rgb(0x77E1E5), rgb(0xD7E1E6),
              ],
              backgroundAlpha: 0.93,
              blur: true),
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

    public static func named(_ name: String) -> Theme {
        all.first { $0.name == name } ?? all[0]
    }
}
