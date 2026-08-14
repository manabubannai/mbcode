import AppKit

// ============================================================
// mbcode 設定
// ~/.mbcode/config.json を編集してカスタマイズする。
// ファイルが無ければ初回起動時にサンプルを自動生成する。
// ============================================================

struct QuickCommand: Codable {
    var keyword: String          // パレットで打つ短いキーワード（例: "cc"）
    var title: String            // 表示名
    var directory: String        // 実行ディレクトリ（~ 展開可）
    var command: String          // 実行コマンド

    var expandedDirectory: String {
        (directory as NSString).expandingTildeInPath
    }
}

struct ConfigFile: Codable {
    var fontName: String?
    var fontSize: CGFloat?
    var theme: String?
    var shell: String?
    var windowWidth: CGFloat?
    var windowHeight: CGFloat?
    var hotkey: String?
    var commands: [QuickCommand]?
}

enum Config {
    static let dir = (NSHomeDirectory() as NSString).appendingPathComponent(".mbcode")
    static let path = (dir as NSString).appendingPathComponent("config.json")

    private(set) static var fontName: String? = nil
    private(set) static var fontSize: CGFloat = 14
    private(set) static var themeName: String = "manabu-dark"
    private(set) static var shell: String? = nil
    private(set) static var windowWidth: CGFloat = 980
    private(set) static var windowHeight: CGFloat = 640
    private(set) static var commands: [QuickCommand] = defaultCommands
    // Pro のグローバルホットキー（例: "option-space", "control-option-space", "command-shift-t", "f12"）
    private(set) static var hotkey: String = "option-space"

    static let shellArgs: [String] = ["-l"]

    static var theme: Theme { Theme.named(themeName) }

    static var font: NSFont {
        if let name = fontName, let f = NSFont(name: name, size: fontSize) {
            return f
        }
        return NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }

    static var resolvedShell: String {
        shell ?? ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    }

    static let defaultCommands: [QuickCommand] = [
        QuickCommand(keyword: "cc", title: "Claude Code（全権限モード）",
                     directory: "~", command: "claude --dangerously-skip-permissions"),
        QuickCommand(keyword: "cl", title: "Claude Code",
                     directory: "~", command: "claude"),
    ]

    // 起動時に一度だけ呼ぶ。設定ファイルが無ければサンプルを書き出す。
    static func load() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: path) {
            try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? sampleJSON.data(using: .utf8)?.write(to: URL(fileURLWithPath: path))
            return
        }
        guard let data = fm.contents(atPath: path),
              let file = try? JSONDecoder().decode(ConfigFile.self, from: data) else {
            NSLog("mbcode: config.json の読み込みに失敗（JSONが壊れている可能性）。デフォルト設定で起動します")
            return
        }
        fontName = file.fontName ?? fontName
        fontSize = file.fontSize ?? fontSize
        themeName = file.theme ?? themeName
        shell = file.shell ?? shell
        windowWidth = file.windowWidth ?? windowWidth
        windowHeight = file.windowHeight ?? windowHeight
        hotkey = file.hotkey ?? hotkey
        commands = file.commands ?? commands
    }

    static let sampleJSON = """
    {
      "fontSize": 14,
      "theme": "manabu-dark",
      "hotkey": "option-space",
      "commands": [
        { "keyword": "cc", "title": "Claude Code（全権限モード）",
          "directory": "~", "command": "claude --dangerously-skip-permissions" },
        { "keyword": "cl", "title": "Claude Code",
          "directory": "~", "command": "claude" }
      ]
    }
    """
}
