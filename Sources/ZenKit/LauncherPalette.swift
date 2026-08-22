import AppKit

// どこでもランチャーの共通実装（UI + あいまい検索 + frecency）。
// Zen Launcher（⇧⌘Space・選択を zencode:// で Zen Code に渡す）と
// Zen Code（⌘K・選択を自アプリの新規タブで開く）の両方から使う。
// 選択時の挙動は onOpen コールバックに委ねる。
public final class LauncherPalette: NSObject, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate {

    public struct LaunchItem {
        public enum Kind {
            case command    // config.json の commands
            case project    // projectsDir から自動検出した git リポジトリ
            case folder     // Finder で開くフォルダ
            case app        // macOS アプリ
            case settings   // システム設定のパネル
            case link       // ブラウザで開くリンク
        }

        public let kind: Kind
        public let keyword: String      // 一致優先度の高い短い名前（表示もこれ）
        public let title: String        // 表示用の副題（空ならパスを出す）
        public let directory: String    // ~展開済み。app は .app のパス
        public let command: String      // 実行コマンド。settings は x-apple.systempreferences URL
        public let alias: String        // 検索だけに使う別名（英語名・日本語名など・表示しない）

        public var isConfigCommand: Bool { kind == .command }

        init(kind: Kind, keyword: String, title: String, directory: String,
             command: String, alias: String = "") {
            self.kind = kind
            self.keyword = keyword
            self.title = title
            self.directory = directory
            self.command = command
            self.alias = alias
        }
    }

    private let onOpen: (LaunchItem, _ plainShell: Bool) -> Void

    private var panel: NSPanel!
    private var field: NSTextField!
    private var table: NSTableView!
    private var all: [LaunchItem] = []
    private var filtered: [LaunchItem] = []

    // 使用履歴（frecency）: ディレクトリごとの回数と最終使用時刻
    private let historyPath = (Config.dir as NSString).appendingPathComponent("launcher-history.json")
    private var history: [String: [String: Double]] = [:]

    public init(onOpen: @escaping (LaunchItem, _ plainShell: Bool) -> Void) {
        self.onOpen = onOpen
        super.init()
    }

    public func toggle() {
        if panel?.isVisible == true {
            close()
        } else {
            show()
        }
    }

    public func show() {
        if panel == nil { build() }
        loadHistory()
        all = buildItems()
        filtered = sorted(all, query: "")
        field.stringValue = ""
        table.reloadData()
        selectRow(0)
        layoutPanel()
        // アプリが背面常駐（accessory・非アクティブ）の時は NSApp.activate が
        // 効かないことがあるため、activate には頼らない。nonactivatingPanel は
        // アプリをアクティブ化せずに自力で key を取れる。
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(field)
    }

    public func windowDidResignKey(_ notification: Notification) {
        close()
    }

    public func close() {
        panel?.orderOut(nil)
    }

    // MARK: - 候補の構築

    private func buildItems() -> [LaunchItem] {
        var items: [LaunchItem] = []
        var seenDirs = Set<String>()
        for cmd in Config.commands {
            items.append(LaunchItem(kind: .command, keyword: cmd.keyword, title: cmd.title,
                                    directory: cmd.expandedDirectory, command: cmd.command))
            seenDirs.insert(cmd.expandedDirectory)
        }
        // Finderで開くフォルダ（config.json の folders）
        for folder in Config.folders {
            items.append(LaunchItem(kind: .folder, keyword: folder.keyword, title: folder.title,
                                    directory: folder.expandedPath, command: ""))
            seenDirs.insert(folder.expandedPath)
        }
        // 標準フォルダ（「ダウンロード」「デスクトップ」などで引ける）
        for folder in LauncherPalette.standardFolders {
            let path = (folder.path as NSString).expandingTildeInPath
            guard !seenDirs.contains(path),
                  FileManager.default.fileExists(atPath: path) else { continue }
            seenDirs.insert(path)
            items.append(LaunchItem(kind: .folder, keyword: folder.name, title: "",
                                    directory: path, command: "", alias: folder.alias))
        }
        // projectsDir 直下のgitリポジトリを自動検出
        let root = (Config.projectsDir as NSString).expandingTildeInPath
        let fm = FileManager.default
        if let names = try? fm.contentsOfDirectory(atPath: root) {
            for name in names.sorted() where !name.hasPrefix(".") {
                let dir = (root as NSString).appendingPathComponent(name)
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: dir, isDirectory: &isDir), isDir.boolValue,
                      fm.fileExists(atPath: (dir as NSString).appendingPathComponent(".git")),
                      !seenDirs.contains(dir) else { continue }
                items.append(LaunchItem(kind: .project, keyword: name, title: name,
                                        directory: dir, command: Config.launcherCommand))
            }
        }
        for link in Config.links {
            items.append(LaunchItem(kind: .link, keyword: link.keyword, title: shortURL(link.url),
                                    directory: "", command: link.url, alias: link.alias ?? ""))
        }
        items.append(contentsOf: appItems())
        items.append(contentsOf: settingsItems())
        return items
    }

    // 日本語でも英語でも引ける標準フォルダ
    static let standardFolders: [(name: String, path: String, alias: String)] = [
        ("ダウンロード", "~/Downloads", "downloads dl"),
        ("デスクトップ", "~/Desktop", "desktop"),
        ("書類", "~/Documents", "documents ドキュメント doc"),
        ("ピクチャ", "~/Pictures", "pictures 写真 画像"),
        ("ミュージック", "~/Music", "music 音楽"),
        ("ムービー", "~/Movies", "movies 動画"),
        ("ホーム", "~", "home"),
        ("アプリケーション", "/Applications", "applications apps アプリ一覧"),
    ]

    // システム設定のパネル。表示は英語（システム設定の表示に合わせる）、
    // 日本語（サウンド・ディスプレイ…）でも引けるように別名を持たせる
    private static let settingsAliases: [String: String] = [
        "Sound": "サウンド 音 音量 スピーカー",
        "Displays": "ディスプレイ 画面 解像度",
        "Keyboard": "キーボード 入力",
        "Mouse": "マウス",
        "Trackpad": "トラックパッド",
        "Network": "ネットワーク",
        "Wi‑Fi": "wifi wi-fi ワイファイ 無線",
        "Bluetooth": "ブルートゥース",
        "Notifications": "通知",
        "Focus": "集中モード おやすみ",
        "Battery": "バッテリー 電源",
        "About": "情報 このMacについて",
        "Privacy & Security": "プライバシー セキュリティ",
        "Users & Groups": "ユーザ ユーザー グループ",
        "Date & Time": "日付 時刻 時計",
        "Language & Region": "言語 地域",
        "Software Update": "ソフトウェアアップデート 更新 アップデート",
        "Storage": "ストレージ 容量 ディスク",
        "Desktop & Dock": "デスクトップ ドック dock",
        "Wallpaper": "壁紙",
        "Screen Time": "スクリーンタイム",
        "Printers & Scanners": "プリンタ プリンター スキャナ 印刷",
        "Accessibility": "アクセシビリティ 支援",
        "Appearance": "外観 アピアランス ダークモード",
        "Spotlight": "スポットライト 検索",
        "Login Items": "ログイン項目 自動起動 スタートアップ",
        "Time Machine": "タイムマシン バックアップ",
        "Sharing": "共有 シェアリング",
        "Siri": "シリ",
        "Touch ID & Password": "タッチid 指紋 パスワード",
        "Menu Bar": "メニューバー コントロールセンター",
        "VPN": "vpn",
        "Lock Screen": "ロック画面 スクリーンセーバ",
        "Game Center": "ゲームセンター ゲーム",
        "Game Controllers": "ゲームコントローラ ゲーム",
        "Internet Accounts": "インターネットアカウント アカウント",
        "Apple Account": "アップルアカウント appleid",
        "Startup Disk": "起動ディスク",
        "Transfer or Reset": "転送 リセット 初期化",
        "Family": "ファミリー 家族",
        "Wallet & Apple Pay": "ウォレット applepay",
        "AirDrop & Continuity": "エアドロップ airdrop 連係",
        "Headphones": "ヘッドフォン イヤホン",
    ]

    // 表示名が内部名のままのパネルを読める名前に直す
    private static let settingsNameFixes: [String: String] = [
        "PowerPreferences": "Battery",
        "HeadphoneSettingsExtension": "Headphones",
    ]

    private static var settingsCache: [LaunchItem]?

    private func settingsItems() -> [LaunchItem] {
        if let cached = LauncherPalette.settingsCache { return cached }
        let dir = "/System/Library/ExtensionKit/Extensions"
        let fm = FileManager.default
        var items: [LaunchItem] = []
        for name in ((try? fm.contentsOfDirectory(atPath: dir)) ?? []).sorted()
        where name.hasSuffix(".appex") {
            let path = (dir as NSString).appendingPathComponent(name)
            guard let bundle = Bundle(path: path), let info = bundle.infoDictionary,
                  let attrs = info["EXAppExtensionAttributes"] as? [String: Any],
                  attrs["EXExtensionPointIdentifier"] as? String == "com.apple.Settings.extension.ui",
                  let bundleID = info["CFBundleIdentifier"] as? String else { continue }
            var display = (bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String)
                ?? (bundle.localizedInfoDictionary?["CFBundleName"] as? String)
                ?? (info["CFBundleDisplayName"] as? String)
                ?? (info["CFBundleName"] as? String) ?? ""
            if display.isEmpty { continue }
            display = LauncherPalette.settingsNameFixes[display] ?? display
            let alias = (LauncherPalette.settingsAliases[display] ?? "") + " 設定 システム設定 settings"
            items.append(LaunchItem(kind: .settings, keyword: display, title: "システム設定",
                                    directory: "", command: "x-apple.systempreferences:" + bundleID,
                                    alias: alias))
        }
        LauncherPalette.settingsCache = items
        return items
    }

    // インストール済みアプリ。空欄のときは出さず、文字を打った時だけ候補に混ぜる。
    private static var appCache: [LaunchItem]?

    private func appItems() -> [LaunchItem] {
        if let cached = LauncherPalette.appCache { return cached }
        let fm = FileManager.default
        let roots = ["/Applications", "/System/Applications",
                     (NSHomeDirectory() as NSString).appendingPathComponent("Applications")]
        var items: [LaunchItem] = []
        var seen = Set<String>()

        func scan(_ dir: String, depth: Int) {
            guard let names = try? fm.contentsOfDirectory(atPath: dir) else { return }
            for name in names.sorted() where !name.hasPrefix(".") {
                let path = (dir as NSString).appendingPathComponent(name)
                if name.hasSuffix(".app") {
                    let base = (name as NSString).deletingPathExtension
                    let display = fm.displayName(atPath: path)
                    let key = display.lowercased()
                    guard !seen.contains(key) else { continue }
                    seen.insert(key)
                    // ファイル名と、日本語のアプリ名（例: 英かな）の両方で引けるようにする
                    let info = Bundle(path: path)?.localizedInfoDictionary
                    let localized = (info?["CFBundleDisplayName"] as? String)
                        ?? (info?["CFBundleName"] as? String) ?? ""
                    let aliases = [base, localized]
                        .filter { !$0.isEmpty && $0 != display }
                        .joined(separator: " ")
                    items.append(LaunchItem(kind: .app, keyword: display, title: "アプリ",
                                            directory: path, command: "", alias: aliases))
                } else if depth > 0 {
                    var isDir: ObjCBool = false
                    if fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                        scan(path, depth: depth - 1)   // /Applications/Utilities など1階層だけ
                    }
                }
            }
        }
        for root in roots { scan(root, depth: 1) }
        LauncherPalette.appCache = items
        return items
    }

    // MARK: - 検索（あいまい一致 + frecency）

    private func score(_ item: LaunchItem, query q: String) -> Int {
        var s = 0
        if q.isEmpty {
            // 空欄のときはプロジェクトとフォルダだけ。アプリと設定は打ち始めてから出す
            if item.kind == .app || item.kind == .settings { return 0 }
            s = 1
        } else {
            let kw = item.keyword.lowercased()
            // 表示名（keyword）以外に、英語名・別名（alias）でも引けるようにする
            let title = (item.kind == .app ? item.alias : item.title + " " + item.alias)
                .trimmingCharacters(in: .whitespaces).lowercased()
            if kw == q { s = 200 }
            else if kw.hasPrefix(q) { s = 120 }
            else if !title.isEmpty && title.hasPrefix(q) { s = 80 }
            else if kw.contains(q) || (!title.isEmpty && title.contains(q)) { s = 60 }
            else if isSubsequence(q, of: kw) || (!title.isEmpty && isSubsequence(q, of: title)) { s = 30 }
            else { return 0 }
            // 同点ならプロジェクト・フォルダを上に
            if item.kind == .app { s -= 5 }
            if item.kind == .settings { s -= 8 }
        }
        // よく使う・最近使ったものを上へ
        if let h = history[historyKey(item)] {
            s += min(Int(h["count"] ?? 0), 10) * 4
            let last = h["last"] ?? 0
            let age = Date().timeIntervalSince1970 - last
            if age < 3600 * 24 { s += 25 } else if age < 3600 * 24 * 7 { s += 12 }
        }
        return s
    }

    private func isSubsequence(_ needle: String, of hay: String) -> Bool {
        var it = hay.makeIterator()
        outer: for ch in needle {
            while let h = it.next() { if h == ch { continue outer } }
            return false
        }
        return true
    }

    private func sorted(_ items: [LaunchItem], query: String) -> [LaunchItem] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        return items
            .map { ($0, score($0, query: q)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
    }

    private func loadHistory() {
        guard let data = FileManager.default.contents(atPath: historyPath),
              let h = try? JSONDecoder().decode([String: [String: Double]].self, from: data) else { return }
        history = h
    }

    private func historyKey(_ item: LaunchItem) -> String {
        item.directory.isEmpty ? item.command : item.directory
    }

    private func recordUse(_ item: LaunchItem) {
        var h = history[historyKey(item)] ?? [:]
        h["count"] = (h["count"] ?? 0) + 1
        h["last"] = Date().timeIntervalSince1970
        history[historyKey(item)] = h
        if let data = try? JSONEncoder().encode(history) {
            try? data.write(to: URL(fileURLWithPath: historyPath))
        }
    }

    // MARK: - UI

    private func build() {
        let width: CGFloat = 560
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: 240),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = paletteBackground
        // hidesOnDeactivate は使わない：アプリ非アクティブ（背面常駐）中は
        // orderFront しても画面に出ず、⇧⌘Space でランチャーが開けなくなる。
        // 代わりに key を失ったら閉じる（windowDidResignKey）。
        panel.delegate = self

        field = NSTextField(frame: .zero)
        field.font = NSFont.monospacedSystemFont(ofSize: 20, weight: .regular)
        field.placeholderString = "アプリ・フォルダ・設定・プロジェクトを検索…"
        field.isBordered = false
        field.focusRingType = .none
        field.backgroundColor = .clear
        field.textColor = paletteText
        field.delegate = self

        table = NSTableView(frame: .zero)
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("cmd"))
        col.width = width - 40
        table.addTableColumn(col)
        table.headerView = nil
        table.rowHeight = 40
        table.backgroundColor = .clear
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(runSelected)

        let scroll = NSScrollView(frame: .zero)
        scroll.documentView = table
        scroll.hasVerticalScroller = false
        scroll.drawsBackground = false

        let content = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 240))
        field.frame = NSRect(x: 20, y: 240 - 52, width: width - 40, height: 32)
        field.autoresizingMask = [.width, .minYMargin]
        scroll.frame = NSRect(x: 12, y: 12, width: width - 24, height: 240 - 72)
        scroll.autoresizingMask = [.width, .height]
        content.addSubview(field)
        content.addSubview(scroll)
        panel.contentView = content
    }

    // ライトテーマではライトなパレットにする
    private var isLight: Bool {
        Config.theme.background.usingColorSpace(.sRGB).map { $0.brightnessComponent > 0.5 } ?? false
    }
    private var paletteBackground: NSColor {
        isLight ? NSColor(calibratedWhite: 0.99, alpha: 0.98) : NSColor(calibratedWhite: 0.12, alpha: 0.98)
    }
    private var paletteText: NSColor { isLight ? NSColor(calibratedWhite: 0.1, alpha: 1) : .white }
    private var paletteMuted: NSColor { isLight ? NSColor(calibratedWhite: 0.45, alpha: 1) : NSColor(calibratedWhite: 0.7, alpha: 1) }
    private var paletteAccent: NSColor {
        isLight ? NSColor(srgbRed: 0.34, green: 0.52, blue: 0.65, alpha: 1)   // clear-light の青系
                : NSColor(calibratedRed: 0.35, green: 0.85, blue: 0.55, alpha: 1.0)
    }

    private func layoutPanel() {
        guard let screen = NSScreen.main else { return }
        let height = min(CGFloat(72 + filtered.count * 42), 400)
        let width: CGFloat = 560
        let x = screen.visibleFrame.midX - width / 2
        let y = screen.visibleFrame.midY + 80
        panel.setFrame(NSRect(x: x, y: y, width: width, height: max(height, 120)), display: true)
    }

    private func filter(_ query: String) {
        filtered = sorted(all, query: query)
        table.reloadData()
        selectRow(0)
        layoutPanel()
    }

    private func selectRow(_ row: Int) {
        guard filtered.indices.contains(row) else { return }
        table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        table.scrollRowToVisible(row)
    }

    @objc private func runSelected() {
        open(plainShell: false)
    }

    private func open(plainShell: Bool) {
        var row = table.selectedRow
        if row < 0 { row = 0 }
        guard filtered.indices.contains(row) else { return }
        let item = filtered[row]
        close()
        recordUse(item)
        switch item.kind {
        case .app:
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: item.directory),
                                               configuration: config)
        case .settings, .link:
            if let url = URL(string: item.command) { NSWorkspace.shared.open(url) }
        case .folder:
            // ターミナルではなく Finder で開く（Zen Launcher / Zen Code 共通）
            NSWorkspace.shared.open(URL(fileURLWithPath: item.directory, isDirectory: true))
        case .command, .project:
            onOpen(item, plainShell)
        }
    }

    // MARK: - NSTextFieldDelegate

    public func controlTextDidChange(_ obj: Notification) {
        filter(field.stringValue)
    }

    public func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            // ⌘Enter はコマンドを実行せずシェルだけ開く
            let cmdHeld = NSApp.currentEvent?.modifierFlags.contains(.command) ?? false
            open(plainShell: cmdHeld)
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            close()
            return true
        case #selector(NSResponder.moveDown(_:)):
            selectRow(min(table.selectedRow + 1, filtered.count - 1))
            return true
        case #selector(NSResponder.moveUp(_:)):
            selectRow(max(table.selectedRow - 1, 0))
            return true
        default:
            return false
        }
    }

    // MARK: - Table

    public func numberOfRows(in tableView: NSTableView) -> Int { filtered.count }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = filtered[row]
        let cell = NSView()
        let icon = NSImageView(frame: NSRect(x: 8, y: 10, width: 20, height: 20))
        icon.imageScaling = .scaleProportionallyUpOrDown
        if item.kind == .app {
            icon.image = NSWorkspace.shared.icon(forFile: item.directory)
        } else if item.kind == .settings,
                  let settings = NSWorkspace.shared.urlForApplication(
                      withBundleIdentifier: "com.apple.systempreferences") {
            icon.image = NSWorkspace.shared.icon(forFile: settings.path)
        } else {
            let symbol: String
            switch item.kind {
            case .folder: symbol = "folder"
            case .link:   symbol = "globe"
            default:      symbol = "chevron.right.square"
            }
            let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            image?.isTemplate = true
            icon.image = image
            icon.contentTintColor = paletteMuted
        }
        let keyword = NSTextField(labelWithString: item.keyword)
        keyword.font = NSFont.monospacedSystemFont(ofSize: 15, weight: .bold)
        keyword.textColor = paletteAccent
        keyword.lineBreakMode = .byTruncatingTail
        keyword.frame = NSRect(x: 36, y: 10, width: 200, height: 20)
        let subtitle: String
        if item.kind == .app {
            subtitle = shortPath((item.directory as NSString).deletingLastPathComponent)
        } else if item.kind == .settings || item.kind == .link {
            subtitle = item.title
        } else if item.title.isEmpty || item.title == item.keyword {
            subtitle = shortPath(item.directory)
        } else {
            subtitle = item.title
        }
        let title = NSTextField(labelWithString: subtitle)
        title.font = NSFont.systemFont(ofSize: 14)
        title.textColor = (item.kind == .app || item.kind == .settings || item.kind == .link
                           || item.title.isEmpty || item.title == item.keyword)
            ? paletteMuted : paletteText
        title.lineBreakMode = .byTruncatingTail
        title.frame = NSRect(x: 244, y: 10, width: 270, height: 20)
        cell.addSubview(icon)
        cell.addSubview(keyword)
        cell.addSubview(title)
        return cell
    }

    // https://mail.google.com/ → mail.google.com
    private func shortURL(_ url: String) -> String {
        URL(string: url)?.host ?? url
    }

    private func shortPath(_ path: String) -> String {
        (path as NSString).abbreviatingWithTildeInPath
    }
}
