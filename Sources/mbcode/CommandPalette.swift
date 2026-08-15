#if FEATURE_PALETTE
import AppKit

// どこでもランチャー。⌘K（アプリ内）と ⇧⌘Space（グローバル）で開く。
// Alfred のように "cc" と打って Enter で該当ディレクトリにターミナルを開く。
// 候補 = config.json の commands + projectsDir 直下のgitリポジトリ（自動検出）。
// 同じディレクトリのウィンドウが既にあればそれにフォーカスする。⌘Enter はコマンド無しのシェルだけ開く。
final class CommandPalette: NSObject, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
    static let shared = CommandPalette()

    struct LaunchItem {
        let keyword: String      // 一致優先度の高い短い名前（コマンドのkeyword or フォルダ名）
        let title: String
        let directory: String    // ~展開済み
        let command: String
    }

    private var panel: NSPanel!
    private var field: NSTextField!
    private var table: NSTableView!
    private var all: [LaunchItem] = []
    private var filtered: [LaunchItem] = []

    // 使用履歴（frecency）: ディレクトリごとの回数と最終使用時刻
    private let historyPath = (Config.dir as NSString).appendingPathComponent("launcher-history.json")
    private var history: [String: [String: Double]] = [:]

    func registerGlobalHotKey() {
        HotKeys.register(id: 2, spec: Config.launcherHotkey) { CommandPalette.shared.toggle() }
    }

    func toggle() {
        if panel?.isVisible == true {
            close()
        } else {
            show()
        }
    }

    func show() {
        if panel == nil { build() }
        loadHistory()
        all = buildItems()
        filtered = sorted(all, query: "")
        field.stringValue = ""
        table.reloadData()
        selectRow(0)
        layoutPanel()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(field)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        panel?.orderOut(nil)
    }

    // MARK: - 候補の構築

    private func buildItems() -> [LaunchItem] {
        var items: [LaunchItem] = []
        var seenDirs = Set<String>()
        for cmd in Config.commands {
            items.append(LaunchItem(keyword: cmd.keyword, title: cmd.title,
                                    directory: cmd.expandedDirectory, command: cmd.command))
            seenDirs.insert(cmd.expandedDirectory)
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
                items.append(LaunchItem(keyword: name, title: name,
                                        directory: dir, command: Config.launcherCommand))
            }
        }
        return items
    }

    // MARK: - 検索（あいまい一致 + frecency）

    private func score(_ item: LaunchItem, query q: String) -> Int {
        var s = 0
        if q.isEmpty {
            s = 1
        } else {
            let kw = item.keyword.lowercased()
            let title = item.title.lowercased()
            if kw == q { s = 200 }
            else if kw.hasPrefix(q) { s = 120 }
            else if title.hasPrefix(q) { s = 80 }
            else if kw.contains(q) || title.contains(q) { s = 60 }
            else if isSubsequence(q, of: kw) || isSubsequence(q, of: title) { s = 30 }
            else { return 0 }
        }
        // よく使う・最近使ったものを上へ
        if let h = history[item.directory] {
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

    private func recordUse(_ item: LaunchItem) {
        var h = history[item.directory] ?? [:]
        h["count"] = (h["count"] ?? 0) + 1
        h["last"] = Date().timeIntervalSince1970
        history[item.directory] = h
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
        panel.hidesOnDeactivate = true

        field = NSTextField(frame: .zero)
        field.font = NSFont.monospacedSystemFont(ofSize: 20, weight: .regular)
        field.placeholderString = "プロジェクトを検索…（例: cc）"
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
        // 同じプロジェクトのウィンドウが既にあればフォーカスするだけ
        if let existing = TermWindowController.controller(forDirectory: item.directory) {
            existing.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let qc = QuickCommand(keyword: item.keyword, title: item.title,
                              directory: item.directory,
                              command: plainShell ? "" : item.command)
        TermWindowController(command: qc).showCentered()
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        filter(field.stringValue)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
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

    func numberOfRows(in tableView: NSTableView) -> Int { filtered.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = filtered[row]
        let cell = NSView()
        let keyword = NSTextField(labelWithString: item.keyword)
        keyword.font = NSFont.monospacedSystemFont(ofSize: 15, weight: .bold)
        keyword.textColor = paletteAccent
        keyword.lineBreakMode = .byTruncatingTail
        keyword.frame = NSRect(x: 8, y: 10, width: 110, height: 20)
        let title = NSTextField(labelWithString: item.title == item.keyword ? shortPath(item.directory) : item.title)
        title.font = NSFont.systemFont(ofSize: 14)
        title.textColor = item.title == item.keyword ? paletteMuted : paletteText
        title.lineBreakMode = .byTruncatingTail
        title.frame = NSRect(x: 126, y: 10, width: 400, height: 20)
        cell.addSubview(keyword)
        cell.addSubview(title)
        return cell
    }

    private func shortPath(_ path: String) -> String {
        (path as NSString).abbreviatingWithTildeInPath
    }
}
#endif
