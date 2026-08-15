#if FEATURE_HOTKEY
import AppKit
import Carbon.HIToolbox
import SwiftTerm

// ⌥Space でどのアプリからでも呼び出せる Quake スタイルターミナル。
// 画面上部から降りてきて、もう一度 ⌥Space で隠れる。シェルは常駐。
final class HotKeyTerminal: NSObject, NSWindowDelegate, LocalProcessTerminalViewDelegate {
    static let shared = HotKeyTerminal()

    private var panel: NSPanel?
    private var terminal: LocalProcessTerminalView?

    func register() {
        HotKeys.register(id: 1, spec: Config.hotkey) { HotKeyTerminal.shared.toggle() }
    }

    func toggle() {
        if panel == nil { build() }
        guard let panel, let terminal else { return }
        if panel.isVisible && panel.isKeyWindow {
            panel.orderOut(nil)
        } else {
            position(panel)
            panel.makeKeyAndOrderFront(nil)
            panel.makeFirstResponder(terminal)
            NSApp.activate(ignoringOtherApps: true)
            applyWindowChrome(panel, theme: Config.theme)
        }
    }

    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let sf = screen.visibleFrame
        let height = sf.height * 0.45
        panel.setFrame(NSRect(x: sf.minX, y: sf.maxY - height, width: sf.width, height: height),
                       display: true)
    }

    private func build() {
        let theme = Config.theme
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 500),
            styleMask: [.titled, .fullSizeContentView, .resizable, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        panel.isReleasedWhenClosed = false

        let container = NSView(frame: panel.contentLayoutRect)
        let terminal = LocalProcessTerminalView(frame: container.bounds.insetBy(dx: Config.padding, dy: Config.padding))
        terminal.processDelegate = self
        terminal.applyTheme(theme)
        terminal.autoresizingMask = [.width, .height]
        container.addSubview(terminal)
        panel.contentView = container
        terminal.startProcess(executable: Config.resolvedShell, args: Config.shellArgs)

        self.panel = panel
        self.terminal = terminal
    }

    // MARK: - LocalProcessTerminalViewDelegate

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        // シェルが終了したら次回の ⌥Space で作り直す
        panel?.orderOut(nil)
        panel = nil
        terminal = nil
    }
}
#endif
