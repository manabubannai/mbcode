import AppKit
import ZenKit

// 新しいターミナルを既存ウィンドウのタブとして開く（タブ機能が無ければ新規ウィンドウ）。
// メニューの Commands と zencode:// URLハンドラから使う。
func openInTab(_ command: QuickCommand) {
    // 新しいコントローラを作る前にタブの親ウィンドウを決めておく
    // （生成後だと live.last が自分自身を指してしまう）
    let host = TermWindowController.frontmost?.window
    let wc = TermWindowController(command: command)
    #if FEATURE_TABS
    if let host, let win = wc.window {
        host.addTabbedWindow(win, ordered: .above)
        win.makeKeyAndOrderFront(nil)
        win.makeFirstResponder(wc.terminal)
        NSApp.activate(ignoringOtherApps: true)
        applyWindowChrome(win, theme: Config.theme)
        return
    }
    #endif
    wc.showCentered()
}
