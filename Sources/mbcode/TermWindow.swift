import AppKit
import SwiftTerm

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
        nativeBackgroundColor = theme.backgroundAlpha < 1.0
            ? theme.background.withAlphaComponent(theme.backgroundAlpha)
            : theme.background
    }
}

// 表示済みウィンドウにテーマの半透明・ぼかしを反映する（windowNumber は表示後に確定）
func applyWindowChrome(_ window: NSWindow, theme: Theme) {
    if theme.backgroundAlpha < 1.0 {
        window.isOpaque = false
        window.backgroundColor = .clear
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

// 1ウィンドウ = 1シェル。クイックコマンド指定があれば起動後に流し込む。
final class TermWindowController: NSWindowController, NSWindowDelegate, LocalProcessTerminalViewDelegate {
    private static var live: [TermWindowController] = []

    let terminal: LocalProcessTerminalView
    private let initialCommand: QuickCommand?

    init(command: QuickCommand? = nil) {
        initialCommand = command
        let rect = NSRect(x: 0, y: 0, width: Config.windowWidth, height: Config.windowHeight)
        terminal = LocalProcessTerminalView(frame: rect)

        let window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = command?.title ?? "Kurogane"
        #if FEATURE_TABS
        window.tabbingMode = .preferred
        #else
        window.tabbingMode = .disallowed
        #endif

        super.init(window: window)
        window.delegate = self

        terminal.processDelegate = self
        applyAppearance()

        window.contentView = terminal

        let shell = Config.resolvedShell
        terminal.startProcess(executable: shell, args: Config.shellArgs)

        if let cmd = command {
            let dir = cmd.expandedDirectory.replacingOccurrences(of: "'", with: "'\\''")
            let line = "cd '\(dir)' && \(cmd.command)\n"
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
    }

    static var frontmost: TermWindowController? {
        NSApp.keyWindow?.windowController as? TermWindowController ?? live.last
    }

    static var allControllers: [TermWindowController] { live }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        Self.live.removeAll { $0 === self }
    }

    #if FEATURE_TABS
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
        window?.title = title.isEmpty ? (initialCommand?.title ?? "Kurogane") : title
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        window?.close()
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
