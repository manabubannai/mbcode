import AppKit

// ============================================================
// mbcode 設定
// ~/.mbcode/config.json を編集してカスタマイズする。
// ファイルが無ければ初回起動時にサンプルを自動生成する。
// Zen Code / Zen Launcher の両方から共用する（ZenKit）。
// ============================================================

public struct QuickCommand: Codable {
    public var keyword: String          // パレットで打つ短いキーワード（例: "cc"）
    public var title: String            // 表示名
    public var directory: String        // 実行ディレクトリ（~ 展開可）
    public var command: String          // 実行コマンド

    public init(keyword: String, title: String, directory: String, command: String) {
        self.keyword = keyword
        self.title = title
        self.directory = directory
        self.command = command
    }

    public var expandedDirectory: String {
        (directory as NSString).expandingTildeInPath
    }
}

// ランチャーから Finder で開くフォルダ
public struct FolderShortcut: Codable {
    public var keyword: String          // パレットで打つ短いキーワード（例: "dl"）
    public var title: String            // 表示名
    public var path: String             // フォルダパス（~ 展開可）

    public init(keyword: String, title: String, path: String) {
        self.keyword = keyword
        self.title = title
        self.path = path
    }

    public var expandedPath: String {
        (path as NSString).expandingTildeInPath
    }
}

// ランチャーからブラウザで開くリンク
public struct WebLink: Codable {
    public var keyword: String          // パレットで打つ名前（例: "Gmail"）
    public var url: String
    public var alias: String?           // 検索だけに使う別名（例: "メール mail"）

    public init(keyword: String, url: String, alias: String? = nil) {
        self.keyword = keyword
        self.url = url
        self.alias = alias
    }
}

struct ConfigFile: Codable {
    var fontName: String?
    var fontSize: CGFloat?
    var theme: String?
    var lineSpacing: CGFloat?
    var padding: CGFloat?
    var shell: String?
    var windowWidth: CGFloat?
    var windowHeight: CGFloat?
    var hotkey: String?
    var launcherHotkey: String?
    var launcherCommand: String?
    var projectsDir: String?
    var commands: [QuickCommand]?
    var folders: [FolderShortcut]?
    var links: [WebLink]?
    var mouseReporting: Bool?
    var confirmClose: Bool?
}

public enum Config {
    public static let dir = (NSHomeDirectory() as NSString).appendingPathComponent(".mbcode")
    public static let path = (dir as NSString).appendingPathComponent("config.json")

    // デフォルトはマナブの Terminal.app「Clear Light」プロファイルと同じ見た目
    public private(set) static var fontName: String? = "PlemolJPConsoleNF-Regular"
    public private(set) static var fontSize: CGFloat = 13
    public private(set) static var themeName: String = "clear-light"
    public private(set) static var lineSpacing: CGFloat = 1.29   // Terminal.app の FontHeightSpacing 相当
    public private(set) static var padding: CGFloat = 14         // 文字とウィンドウ端の余白（Terminal.app 相当）
    public private(set) static var shell: String? = nil
    public private(set) static var windowWidth: CGFloat = 980
    public private(set) static var windowHeight: CGFloat = 640
    public private(set) static var commands: [QuickCommand] = defaultCommands
    // Quakeターミナルのグローバルホットキー（例: "option-space", "control-option-space", "f12"）
    public private(set) static var hotkey: String = "option-space"
    // どこでもランチャー（⇧⌘Space）。プロジェクトを選んでターミナルを開く
    public private(set) static var launcherHotkey: String = "shift-command-space"
    // 自動検出したプロジェクトを開くときに実行するコマンド
    public private(set) static var launcherCommand: String = "claude"
    // gitリポジトリを自動検出するフォルダ
    public private(set) static var projectsDir: String = "~/Documents"
    // ランチャーから Finder で開くフォルダ
    public private(set) static var folders: [FolderShortcut] = defaultFolders
    // ランチャーからブラウザで開くリンク
    public private(set) static var links: [WebLink] = defaultLinks
    // マウス操作をターミナル内のアプリ（vim/lessなど）に渡すか。
    // true にすると Claude Code 実行中はドラッグでの文字選択ができなくなるため既定は false
    public static var mouseReporting: Bool = false
    // 実行中のプロセスがあるウィンドウを閉じるとき確認する（Terminal.app と同じ）
    public private(set) static var confirmClose: Bool = true

    public static let shellArgs: [String] = ["-l"]

    public static var theme: Theme { Theme.named(themeName) }

    public static var font: NSFont {
        if let name = fontName, let f = NSFont(name: name, size: fontSize) {
            return f
        }
        return NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }

    public static var resolvedShell: String {
        shell ?? ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    }

    // ダウンロード/デスクトップ/書類などの標準フォルダはランチャーに内蔵しているので、
    // ここは「追加で登録したいフォルダ」だけを持つ
    public static let defaultFolders: [FolderShortcut] = []

    public static let defaultLinks: [WebLink] = [
        WebLink(keyword: "Gmail", url: "https://mail.google.com/", alias: "メール mail gmail"),
        WebLink(keyword: "Google Drive", url: "https://drive.google.com/",
                alias: "グーグルドライブ ドライブ gdrive drive"),
        WebLink(keyword: "Google Calendar", url: "https://calendar.google.com/",
                alias: "カレンダー 予定 calendar"),
    ]

    public static let defaultCommands: [QuickCommand] = [
        QuickCommand(keyword: "cc", title: "Claude Code（全権限モード）",
                     directory: "~", command: "claude --dangerously-skip-permissions"),
        QuickCommand(keyword: "cl", title: "Claude Code",
                     directory: "~", command: "claude"),
    ]

    // ホットキー変更をアプリ間（Zen Code ⇄ Zen Launcher）で伝えるための通知
    public static let hotkeysChangedNote = Notification.Name("com.manabu.zencode.hotkeysChanged")

    // config.json の1キーだけを書き換える（他のキーはそのまま残す）
    private static func patch(_ key: String, _ value: Any) {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let url = URL(fileURLWithPath: path)
        var root = (try? JSONSerialization.jsonObject(with: (try? Data(contentsOf: url)) ?? Data()))
            as? [String: Any] ?? [:]
        if root.isEmpty, let sample = try? JSONSerialization.jsonObject(with: sampleJSON.data(using: .utf8)!)
            as? [String: Any] {
            root = sample
        }
        root[key] = value
        if let data = try? JSONSerialization.data(withJSONObject: root,
                                                  options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: url)
        }
    }

    // メニューの「マウス操作をアプリに渡す」を次回起動にも引き継ぐ
    public static func saveMouseReporting(_ on: Bool) {
        mouseReporting = on
        patch("mouseReporting", on)
    }

    // 設定画面からホットキーを保存する。config.json の他のキーはそのまま残す
    public static func saveHotkeys(quake: String, launcher: String) {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let url = URL(fileURLWithPath: path)
        var root = (try? JSONSerialization.jsonObject(with: (try? Data(contentsOf: url)) ?? Data()))
            as? [String: Any] ?? [:]
        if root.isEmpty, let sample = try? JSONSerialization.jsonObject(with: sampleJSON.data(using: .utf8)!)
            as? [String: Any] {
            root = sample
        }
        root["hotkey"] = quake
        root["launcherHotkey"] = launcher
        if let data = try? JSONSerialization.data(withJSONObject: root,
                                                  options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: url)
        }
        hotkey = quake
        launcherHotkey = launcher
        DistributedNotificationCenter.default().post(name: hotkeysChangedNote, object: nil)
    }

    // 起動時に一度だけ呼ぶ。設定ファイルが無ければサンプルを書き出す。
    public static func load() {
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
        lineSpacing = file.lineSpacing ?? lineSpacing
        padding = file.padding ?? padding
        shell = file.shell ?? shell
        windowWidth = file.windowWidth ?? windowWidth
        windowHeight = file.windowHeight ?? windowHeight
        hotkey = file.hotkey ?? hotkey
        launcherHotkey = file.launcherHotkey ?? launcherHotkey
        launcherCommand = file.launcherCommand ?? launcherCommand
        projectsDir = file.projectsDir ?? projectsDir
        commands = file.commands ?? commands
        folders = file.folders ?? folders
        links = file.links ?? links
        mouseReporting = file.mouseReporting ?? mouseReporting
        confirmClose = file.confirmClose ?? confirmClose
    }

    static let sampleJSON = """
    {
      "fontName": "PlemolJPConsoleNF-Regular",
      "fontSize": 13,
      "theme": "clear-light",
      "lineSpacing": 1.29,
      "padding": 14,
      "hotkey": "option-space",
      "launcherHotkey": "shift-command-space",
      "launcherCommand": "claude",
      "projectsDir": "~/Documents",
      "mouseReporting": false,
      "confirmClose": true,
      "commands": [
        { "keyword": "cc", "title": "Claude Code（全権限モード）",
          "directory": "~", "command": "claude --dangerously-skip-permissions" },
        { "keyword": "cl", "title": "Claude Code",
          "directory": "~", "command": "claude" }
      ],
      "links": [
        { "keyword": "Gmail", "url": "https://mail.google.com/", "alias": "メール mail gmail" },
        { "keyword": "Google Drive", "url": "https://drive.google.com/",
          "alias": "グーグルドライブ ドライブ gdrive drive" },
        { "keyword": "Google Calendar", "url": "https://calendar.google.com/",
          "alias": "カレンダー 予定 calendar" }
      ]
    }
    """
}
