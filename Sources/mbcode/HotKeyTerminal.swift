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
    private var hotKeyRef: EventHotKeyRef?

    func register() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ -> OSStatus in
            DispatchQueue.main.async { HotKeyTerminal.shared.toggle() }
            return noErr
        }, 1, &eventType, nil, nil)

        let hotKeyID = EventHotKeyID(signature: OSType(0x6D62_6364), id: 1) // "mbcd"
        let (keyCode, modifiers) = Self.parse(Config.hotkey)
        RegisterEventHotKey(keyCode, modifiers,
                            hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    // "option-space" のような文字列を (keyCode, modifiers) に変換
    static func parse(_ spec: String) -> (UInt32, UInt32) {
        let keyCodes: [String: Int] = [
            "space": kVK_Space, "grave": kVK_ANSI_Grave, "escape": kVK_Escape,
            "f12": kVK_F12, "f11": kVK_F11,
            "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D,
            "e": kVK_ANSI_E, "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H,
            "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
            "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P,
            "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
            "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
            "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
        ]
        var mods: UInt32 = 0
        var key: UInt32 = UInt32(kVK_Space)
        for part in spec.lowercased().split(separator: "-").map(String.init) {
            switch part {
            case "command", "cmd": mods |= UInt32(cmdKey)
            case "option", "opt", "alt": mods |= UInt32(optionKey)
            case "control", "ctrl": mods |= UInt32(controlKey)
            case "shift": mods |= UInt32(shiftKey)
            default:
                if let code = keyCodes[part] { key = UInt32(code) }
            }
        }
        // Fキー以外の修飾キー無しは通常入力を乗っ取ってしまうので保険をかける
        if mods == 0 && key != UInt32(kVK_F12) && key != UInt32(kVK_F11) {
            mods = UInt32(optionKey)
        }
        return (key, mods)
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

        let terminal = LocalProcessTerminalView(frame: panel.contentLayoutRect)
        terminal.processDelegate = self
        terminal.applyTheme(theme)
        terminal.autoresizingMask = [.width, .height]
        panel.contentView = terminal
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
