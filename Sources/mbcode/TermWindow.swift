import AppKit
import SwiftTerm

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
        window.backgroundColor = Config.theme.background

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
        terminal.font = FontState.current
        terminal.nativeBackgroundColor = theme.background
        terminal.nativeForegroundColor = theme.foreground
        terminal.caretColor = theme.cursor
        window?.backgroundColor = theme.background
    }

    func showCentered() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(terminal)
        NSApp.activate(ignoringOtherApps: true)
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
