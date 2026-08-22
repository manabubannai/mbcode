import AppKit
import SwiftTerm
import ZenKit

// Terminal.app の「背景ぼかし」相当（プライベートAPI・失敗しても無害）
private typealias CGSConnectionID = UInt32
@_silgen_name("CGSDefaultConnectionForThread")
private func CGSDefaultConnectionForThread() -> CGSConnectionID
@discardableResult
@_silgen_name("CGSSetWindowBackgroundBlurRadius")
private func CGSSetWindowBackgroundBlurRadius(_ cid: CGSConnectionID, _ wid: Int32, _ radius: Int32) -> Int32

extension LocalProcessTerminalView {
    // テーマの全属性（フォント・行間・ANSI16色・選択色・半透明背景）をまとめて反映する
    func applyTheme(_ theme: Theme) {
        font = FontState.current
        // ドラッグでの文字選択を最優先にする（詳細は MouseState）
        allowMouseReporting = Config.mouseReporting
        lineSpacing = Config.lineSpacing
        nativeForegroundColor = theme.foreground
        caretColor = theme.cursor
        if let sel = theme.selection {
            selectedTextBackgroundColor = sel
        }
        if let ansi = theme.ansi {
            installColors(ansi.map { c in
                let s = c.usingColorSpace(.sRGB) ?? c
                return SwiftTerm.Color(red: UInt16(s.redComponent * 65535),
                                       green: UInt16(s.greenComponent * 65535),
                                       blue: UInt16(s.blueComponent * 65535))
            })
        }
        // 半透明テーマでは背景塗りをウィンドウ側に一本化する
        // （ここでも塗ると二重合成になり、余白との濃さが揃わない）
        nativeBackgroundColor = theme.backgroundAlpha < 1.0
            ? theme.background.withAlphaComponent(0)
            : theme.background
    }
}

// 表示済みウィンドウにテーマの半透明・ぼかしを反映する（windowNumber は表示後に確定）
func applyWindowChrome(_ window: NSWindow, theme: Theme) {
    if theme.backgroundAlpha < 1.0 {
        window.isOpaque = false
        // 余白部分もターミナル本体と同じ半透明色で塗る
        window.backgroundColor = theme.background.withAlphaComponent(theme.backgroundAlpha)
    } else {
        window.isOpaque = true
        window.backgroundColor = theme.background
    }
    if window.windowNumber > 0 {
        let radius: Int32 = theme.blur && theme.backgroundAlpha < 1.0 ? 26 : 0
        CGSSetWindowBackgroundBlurRadius(CGSDefaultConnectionForThread(),
                                         Int32(window.windowNumber), radius)
    }
}

// ターミナル本体は余白（padding）の分だけ内側に置いてあるため、
// 端の文字を選ぼうとして余白からドラッグを始めると何も選択できなかった。
// 余白のクリック・ドラッグはターミナル本体に転送する。
final class PaddedContainerView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        if hit === self, let terminal = subviews.first { return terminal }
        return hit
    }

    // 余白の上でもカーソルはI字のまま（選択できることが見た目でわかる）
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .iBeam)
    }
}

// ファイル/スクリーンショットのドロップでパスを入力欄に流し込むターミナル。
// スクショのサムネイル・プレビューからのドラッグは実ファイルではなく
// 「ファイルプロミス」で届くため、一時フォルダに実体化してからパスを送る。
final class DropTerminalView: LocalProcessTerminalView {
    private static let promiseQueue = OperationQueue()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        var types: [NSPasteboard.PasteboardType] = [.fileURL]
        types += NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }
        registerForDraggedTypes(types)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard
        if let receivers = pb.readObjects(forClasses: [NSFilePromiseReceiver.self]) as? [NSFilePromiseReceiver],
           !receivers.isEmpty {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("ZenCodeDrops/\(UUID().uuidString)", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            for receiver in receivers {
                receiver.receivePromisedFiles(atDestination: dir, options: [:],
                                              operationQueue: Self.promiseQueue) { url, error in
                    guard error == nil else { return }
                    DispatchQueue.main.async { [weak self] in self?.sendPath(url) }
                }
            }
            return true
        }
        if let urls = pb.readObjects(forClasses: [NSURL.self],
                                     options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            for url in urls { sendPath(url) }
            return true
        }
        return false
    }

    private func sendPath(_ url: URL) {
        send(txt: "'" + url.path.replacingOccurrences(of: "'", with: "'\\''") + "' ")
    }

    // ── 文字選択とコピー ──
    // SwiftTerm は「押した位置」を選択の起点にしておらず、最初のドラッグイベントの
    // 位置を起点にする。そのため素早くドラッグすると何も選択されず、ゆっくり
    // ドラッグしても先頭の1〜数文字が欠けていた。また選択範囲の終わりが常に
    // セルの左端で切られるため、最後の1文字が入らなかった。
    // ここでは押した点・離した点をどちらも「セルの境界」（右半分なら次の境界）に
    // 丸めて選択し直し、macOS の他のターミナルと同じ挙動にする。
    private var characterDrag = false

    private var cellSize: CGSize {
        let t = getTerminal()
        let optimal = getOptimalFrameSize()
        let hasScroller = subviews.contains { ($0 as? NSScroller)?.isHidden == false }
        let reserved = hasScroller
            ? NSScroller.scrollerWidth(for: .regular, scrollerStyle: scrollerStyle) : 0
        return CGSize(width: max(1, (optimal.width - reserved) / CGFloat(max(1, t.cols))),
                      height: max(1, optimal.height / CGFloat(max(1, t.rows))))
    }

    private func edgeHit(_ event: NSEvent) -> (edge: Int, row: Int) {
        let t = getTerminal()
        let p = convert(event.locationInWindow, from: nil)
        let cs = cellSize
        let edge = min(max(0, Int((p.x / cs.width + 0.5).rounded(.down))), t.cols)
        let row = min(max(0, Int((frame.height - p.y) / cs.height)), t.rows - 1)
        return (edge, row)
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        // マウス操作をアプリに渡す設定のとき、ダブルクリックの単語選択、
        // shift+クリックの範囲拡張は SwiftTerm の処理をそのまま使う
        guard !allowMouseReporting, event.clickCount == 1, !selectionActive else {
            characterDrag = false
            return
        }
        let h = edgeHit(event)
        selection.setSoftStart(row: h.row, col: h.edge)
        characterDrag = true
    }

    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        guard characterDrag, !allowMouseReporting, selectionActive else { return }
        let h = edgeHit(event)
        selection.dragExtend(row: h.row, col: h.edge)
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        characterDrag = false
    }

    // 選択していないときの ⌘C で「前に選んだ文字列」がコピーされていた
    // （SwiftTerm が選択の有無を見ずに範囲の中身を返すため）。
    // 選択が無いときはクリップボードを触らない。
    override func copy(_ sender: Any) {
        guard let text = getSelection(), !text.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    // ── AI作業の完了検知 ──
    // 「まとまった出力（10KB以上・5秒以上）が続いた後、2秒静止」で完了とみなす。
    // Claude Code が完了時に鳴らすベル（BEL）は即時に完了扱い。
    var onWorkCompleted: (() -> Void)?
    private var burstStart: TimeInterval = 0
    private var burstBytes = 0
    private var lastOutputAt: TimeInterval = 0
    private var quietTimer: Timer?

    override func dataReceived(slice: ArraySlice<UInt8>) {
        super.dataReceived(slice: slice)
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastOutputAt > 5 { burstStart = now; burstBytes = 0 }
        lastOutputAt = now
        burstBytes += slice.count
        quietTimer?.invalidate()
        guard burstBytes >= 10_000, now - burstStart >= 5 else { return }
        quietTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.onWorkCompleted?()
        }
    }

    override func bell(source: Terminal) {
        super.bell(source: source)
        quietTimer?.invalidate()
        onWorkCompleted?()
    }
}

// 1ウィンドウ = 1シェル。クイックコマンド指定があれば起動後に流し込む。
final class TermWindowController: NSWindowController, NSWindowDelegate, LocalProcessTerminalViewDelegate {
    private static var live: [TermWindowController] = []

    let terminal: LocalProcessTerminalView
    private let initialCommand: QuickCommand?
    // マナブが手動で付けたタブ名。設定中はシェルからのタイトル更新を無視する
    private var customTitle: String?
    // シェルから届いた最新の自動タイトル
    private var autoTitle: String?
    // AI作業完了バッジ（✅）表示中か。ウィンドウがキーになったら消す
    private var completed = false

    init(command: QuickCommand? = nil) {
        initialCommand = command
        let rect = NSRect(x: 0, y: 0, width: Config.windowWidth, height: Config.windowHeight)
        terminal = DropTerminalView(frame: rect)

        let window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = command?.title ?? "Zen Code"
        #if FEATURE_TABS
        window.tabbingMode = .preferred
        #else
        window.tabbingMode = .disallowed
        #endif

        super.init(window: window)
        window.delegate = self

        terminal.processDelegate = self
        applyAppearance()

        // 文字がウィンドウ端に張り付かないよう余白を入れる（余白部分はウィンドウ背景色が見える）
        let container = PaddedContainerView(frame: rect)
        terminal.frame = container.bounds.insetBy(dx: Config.padding, dy: Config.padding)
        terminal.autoresizingMask = [.width, .height]
        container.addSubview(terminal)
        window.contentView = container

        (terminal as? DropTerminalView)?.onWorkCompleted = { [weak self] in
            self?.markWorkCompleted()
        }

        let shell = Config.resolvedShell
        terminal.startProcess(executable: shell, args: Config.shellArgs)

        if let cmd = command {
            let dir = cmd.expandedDirectory.replacingOccurrences(of: "'", with: "'\\''")
            let line = cmd.command.isEmpty ? "cd '\(dir)'\n" : "cd '\(dir)' && \(cmd.command)\n"
            // シェルの初期化を待ってから流し込む
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.terminal.send(txt: line)
            }
        }

        Self.live.append(self)
    }

    required init?(coder: NSCoder) { fatalError() }

    func applyAppearance() {
        let theme = Config.theme
        terminal.applyTheme(theme)
        if let window { applyWindowChrome(window, theme: theme) }
    }

    func showCentered() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(terminal)
        NSApp.activate(ignoringOtherApps: true)
        if let window { applyWindowChrome(window, theme: Config.theme) }
        // 2枚以上あればグリッドに整列（1枚なら中央表示のまま）
        TileLayout.retile()
    }

    // 表示タイトル = バッジ + (手動タイトル > シェルの自動タイトル > コマンド名)
    private func refreshTitle() {
        let base = customTitle ?? autoTitle ?? initialCommand?.title ?? "Zen Code"
        window?.title = completed ? "✅ \(base)" : base
    }

    private func markWorkCompleted() {
        // 作業を見ているウィンドウ自体には付けない（気づく必要がないため）
        if window?.isKeyWindow != true {
            completed = true
            refreshTitle()
        }
        TileLayout.promote(self)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        guard completed else { return }
        completed = false
        refreshTitle()
    }

    static var frontmost: TermWindowController? {
        NSApp.keyWindow?.windowController as? TermWindowController ?? live.last
    }

    static var allControllers: [TermWindowController] { live }

    var projectDirectory: String? { initialCommand?.expandedDirectory }

    static func controller(forDirectory dir: String) -> TermWindowController? {
        live.first { $0.projectDirectory == dir && $0.window != nil }
    }

    // MARK: - NSWindowDelegate

    // Terminal.app と同じく、何かが動いているウィンドウは確認してから閉じる。
    // 確認後は close() で閉じる（close() はこのメソッドを呼ばない）
    private var forceClose = false

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard !forceClose, Config.confirmClose else { return true }
        let running = CloseConfirm.runningProcesses(shellPid: terminal.process.shellPid)
        guard !running.isEmpty else { return true }
        CloseConfirm.ask(window: sender, processes: running) { [weak self] in
            self?.forceClose = true
            self?.window?.close()
        }
        return false
    }

    func windowWillClose(_ notification: Notification) {
        Self.live.removeAll { $0 === self }
        // 閉じたあとの空きを詰め直す（close処理が終わってから）
        DispatchQueue.main.async { TileLayout.retile() }
    }

    #if FEATURE_TABS
    // タブバーのダブルクリックで名前編集を開く。
    // タブバーは非公開ビュー（NSTabButton）のため、クラス名のヒットテストで判定する
    private static var tabRenameMonitorInstalled = false
    static func installTabRenameMonitor() {
        guard !tabRenameMonitorInstalled else { return }
        tabRenameMonitorInstalled = true
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            guard event.clickCount == 2,
                  let root = event.window?.contentView?.superview,
                  let hit = root.hitTest(event.locationInWindow),
                  !hit.className.contains("Close") else { return event }
            var view: NSView? = hit
            while let v = view {
                if v.className.contains("NSTabButton") {
                    // 1クリック目でそのタブが選択済みなので、キーウィンドウが編集対象
                    DispatchQueue.main.async {
                        (NSApp.keyWindow?.windowController as? TermWindowController)?.renameTab(nil)
                    }
                    return nil
                }
                view = v.superview
            }
            return event
        }
    }

    @objc override func newWindowForTab(_ sender: Any?) {
        let wc = TermWindowController()
        if let win = wc.window, let current = window {
            current.addTabbedWindow(win, ordered: .above)
            win.makeKeyAndOrderFront(nil)
            win.makeFirstResponder(wc.terminal)
            applyWindowChrome(win, theme: Config.theme)
        }
    }
    #endif

    // MARK: - LocalProcessTerminalViewDelegate

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        autoTitle = title.isEmpty ? nil : title
        refreshTitle()
    }

    // タブ名（ウィンドウタイトル）を手動で変更する。空欄で自動タイトルに戻す
    @objc func renameTab(_ sender: Any?) {
        guard let window else { return }
        let alert = NSAlert()
        alert.messageText = "タブ名を変更"
        alert.informativeText = "空欄にすると自動タイトルに戻ります。"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "キャンセル")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = customTitle ?? window.title
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .alertFirstButtonReturn else { return }
            let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            self.customTitle = name.isEmpty ? nil : name
            self.refreshTitle()
        }
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        window?.close()
    }
}

// マウス操作の行き先を全ウィンドウで共有する。
// off（既定）= ドラッグは常に文字選択。Claude Code のように
// マウス報告を有効にするアプリの実行中でも選択が消えなくなる。
// on = vim/less などにマウスを渡す（そのぶん選択はできなくなる）
enum MouseState {
    static var reportingToApp: Bool {
        get { Config.mouseReporting }
        set {
            Config.saveMouseReporting(newValue)
            for wc in TermWindowController.allControllers {
                wc.terminal.allowMouseReporting = newValue
            }
            #if FEATURE_HOTKEY
            HotKeyTerminal.shared.terminalView?.allowMouseReporting = newValue
            #endif
        }
    }
}

// フォントサイズの拡大縮小（⌘+ / ⌘-）を全ウィンドウで共有
enum FontState {
    static var size: CGFloat = Config.fontSize
    static var current: NSFont {
        if let name = Config.fontName, let f = NSFont(name: name, size: size) {
            return f
        }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }
}
