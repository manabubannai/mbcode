// アプリアイコン(icns)生成スクリプト
// 使い方: swift scripts/makeicon.swift <出力ディレクトリ>
// <出力ディレクトリ>/mbcode.iconset を作る。icns化は iconutil で行う。
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dist"
let iconsetPath = outDir + "/mbcode.iconset"
try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

func drawIcon(size: Int) -> NSBitmapImageRep {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // macOS標準アイコンのマージン（キャンバスの約10%）と角丸
    let margin = s * 0.10
    let rect = NSRect(x: margin, y: margin, width: s - margin * 2, height: s - margin * 2)
    let radius = rect.width * 0.225
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    // 背景: ダークネイビーのグラデーション
    let gradient = NSGradient(starting: NSColor(calibratedRed: 0.16, green: 0.16, blue: 0.20, alpha: 1),
                              ending: NSColor(calibratedRed: 0.07, green: 0.07, blue: 0.10, alpha: 1))!
    gradient.draw(in: path, angle: -90)

    // プロンプト "❯" + カーソル "▍"
    let fontSize = rect.width * 0.42
    let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
    let green = NSColor(calibratedRed: 0.35, green: 0.85, blue: 0.55, alpha: 1)
    let white = NSColor(calibratedWhite: 0.95, alpha: 1)

    let prompt = NSAttributedString(string: "❯", attributes: [.font: font, .foregroundColor: green])
    let cursor = NSAttributedString(string: "▍", attributes: [.font: font, .foregroundColor: white])

    let pSize = prompt.size()
    let cSize = cursor.size()
    let totalW = pSize.width + cSize.width * 0.7
    let baseX = rect.midX - totalW / 2
    let baseY = rect.midY - pSize.height / 2
    prompt.draw(at: NSPoint(x: baseX, y: baseY))
    cursor.draw(at: NSPoint(x: baseX + pSize.width + cSize.width * 0.05, y: baseY))

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func save(_ rep: NSBitmapImageRep, _ name: String) {
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: iconsetPath + "/" + name))
}

for base in [16, 32, 128, 256, 512] {
    save(drawIcon(size: base), "icon_\(base)x\(base).png")
    save(drawIcon(size: base * 2), "icon_\(base)x\(base)@2x.png")
}
print("iconset written to \(iconsetPath)")
