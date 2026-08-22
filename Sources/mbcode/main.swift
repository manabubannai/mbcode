import AppKit
import SwiftTerm
import ZenKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    // zencode:// 経由で起動された場合はデフォルトウィンドウを出さない
    private var openedViaURL = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        // application(_:open:) は didFinishLaunching より先に届くことがあるため
        // メニュー構築はここで済ませておく
        buildMenu()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if FEATURE_TABS
        TermWindowController.installTabRenameMonitor()
        #endif
        // v1.6.x が自動登録したログイン項目を解除（常駐は Zen Launcher へ移管）
        LoginItem.removeCompletely()
        if TermWindowController.allControllers.isEmpty && !openedViaURL {
            TermWindowController().showCentered()
        }
        NSApp.activate(ignoringOtherApps: true)
        #if FEATURE_HOTKEY
        HotKeyTerminal.shared.register()
        #endif
        // 設定画面（Zen Launcher 側含む）でホットキーが変わったら追従する
        DistributedNotificationCenter.default().addObserver(
            forName: Config.hotkeysChangedNote, object: nil, queue: .main) { _ in
            Config.load()
            #if FEATURE_HOTKEY
            HotKeyTerminal.shared.register()
            #endif
        }
    }

    // Zen Launcher からの zencode://open?keyword=cc / zencode://open?path=/dir[&plain=1]
    // セキュリティ: URLからは任意コマンドを受け取らない。実行するのは
    // config.json の commands（keyword一致）か launcherCommand だけ。
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "zencode" {
            guard url.host == "open",
                  let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { continue }
            func query(_ name: String) -> String? {
                comps.queryItems?.first { $0.name == name }?.value
            }
            let plain = query("plain") == "1"
            var qc: QuickCommand?
            if let kw = query("keyword"),
               let cmd = Config.commands.first(where: { $0.keyword == kw }) {
                qc = QuickCommand(keyword: cmd.keyword, title: cmd.title,
                                  directory: cmd.directory,
                                  command: plain ? "" : cmd.command)
            } else if let path = query("path") {
                let dir = (path as NSString).expandingTildeInPath
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: dir, isDirectory: &isDir),
                      isDir.boolValue else { continue }
                let name = (dir as NSString).lastPathComponent
                qc = QuickCommand(keyword: name, title: name, directory: dir,
                                  command: plain ? "" : Config.launcherCommand)
            }
            guard let qc else { continue }
            openedViaURL = true
            openInTab(qc)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // dist-next に新しいビルドがあれば、終了後に dist を差し替える
        SelfUpdate.installPendingBuildOnQuit()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        #if FEATURE_HOTKEY
        return false   // ⌥Space のQuakeターミナル（シェル常駐）を生かすため残す
        #else
        return true
        #endif
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { TermWindowController().showCentered() }
        return true
    }

    // MARK: - Actions

    @objc func newWindow(_ sender: Any?) {
        TermWindowController().showCentered()
    }

    #if FEATURE_TABS
    @objc func newTab(_ sender: Any?) {
        if let front = TermWindowController.frontmost {
            front.newWindowForTab(sender)
        } else {
            TermWindowController().showCentered()
        }
    }
    #endif

    @objc func runQuickCommand(_ sender: NSMenuItem) {
        guard Config.commands.indices.contains(sender.tag) else { return }
        TermWindowController(command: Config.commands[sender.tag]).showCentered()
    }

    @objc func openConfig(_ sender: Any?) {
        NSWorkspace.shared.open(URL(fileURLWithPath: Config.path))
    }

    @objc func openHotkeySettings(_ sender: Any?) {
        HotkeySettings.shared.show()
    }

    @objc func reportBug(_ sender: Any?) {
        BugReport.shared.show()
    }

    @objc func tileNow(_ sender: Any?) {
        TileLayout.retile(force: true)
    }

    @objc func toggleAutoTile(_ sender: NSMenuItem) {
        TileLayout.enabled.toggle()
    }

    // マウス操作をターミナル内のアプリに渡すか。ONにすると vim/less などで
    // マウスが使えるかわりに、ドラッグでの文字選択ができなくなる
    @objc func toggleMouseReporting(_ sender: NSMenuItem) {
        MouseState.reportingToApp.toggle()
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if item.action == #selector(toggleAutoTile(_:)) {
            item.state = TileLayout.enabled ? .on : .off
        }
        if item.action == #selector(toggleMouseReporting(_:)) {
            item.state = MouseState.reportingToApp ? .on : .off
        }
        return true
    }

    @objc func fontBigger(_ sender: Any?) { changeFont(by: +1) }
    @objc func fontSmaller(_ sender: Any?) { changeFont(by: -1) }
    @objc func fontReset(_ sender: Any?) {
        FontState.size = Config.fontSize
        applyFontToAll()
    }

    private func changeFont(by delta: CGFloat) {
        FontState.size = min(max(FontState.size + delta, 9), 32)
        applyFontToAll()
    }

    private func applyFontToAll() {
        for wc in TermWindowController.allControllers {
            wc.terminal.font = FontState.current
        }
    }

    // MARK: - Menu

    private func buildMenu() {
        let appName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? ProcessInfo.processInfo.processName
        let mainMenu = NSMenu()

        // App
        let appItem = NSMenuItem(); mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About \(appName)",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        let pref = NSMenuItem(title: "設定…", action: #selector(openHotkeySettings(_:)), keyEquivalent: ",")
        appMenu.addItem(pref)
        appMenu.addItem(withTitle: "設定を開く（config.json）", action: #selector(openConfig(_:)), keyEquivalent: "")
        appMenu.addItem(withTitle: "バグを報告…", action: #selector(reportBug(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        // Shell
        let shellItem = NSMenuItem(); mainMenu.addItem(shellItem)
        let shellMenu = NSMenu(title: "Shell")
        shellMenu.addItem(withTitle: "新規ウィンドウ", action: #selector(newWindow(_:)), keyEquivalent: "n")
        #if FEATURE_TABS
        shellMenu.addItem(withTitle: "新規タブ", action: #selector(newTab(_:)), keyEquivalent: "t")
        #endif
        let renameItem = NSMenuItem(title: "タブ名を変更…",
                                    action: #selector(TermWindowController.renameTab(_:)),
                                    keyEquivalent: "r")
        renameItem.keyEquivalentModifierMask = [.command, .shift]
        shellMenu.addItem(renameItem)
        shellMenu.addItem(NSMenuItem.separator())
        shellMenu.addItem(withTitle: "閉じる", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        shellItem.submenu = shellMenu

        // Edit
        let editItem = NSMenuItem(); mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu

        // Commands
        let cmdItem = NSMenuItem(); mainMenu.addItem(cmdItem)
        let cmdMenu = NSMenu(title: "Commands")
        for (i, cmd) in Config.commands.prefix(9).enumerated() {
            let item = NSMenuItem(title: "\(cmd.keyword) — \(cmd.title)",
                                  action: #selector(runQuickCommand(_:)),
                                  keyEquivalent: String(i + 1))
            item.tag = i
            cmdMenu.addItem(item)
        }
        cmdMenu.addItem(NSMenuItem.separator())
        cmdMenu.addItem(withTitle: "コマンドを編集…", action: #selector(openConfig(_:)), keyEquivalent: "")
        cmdItem.submenu = cmdMenu

        // View
        let viewItem = NSMenuItem(); mainMenu.addItem(viewItem)
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(withTitle: "フォントを大きく", action: #selector(fontBigger(_:)), keyEquivalent: "+")
        viewMenu.addItem(withTitle: "フォントを小さく", action: #selector(fontSmaller(_:)), keyEquivalent: "-")
        viewMenu.addItem(withTitle: "フォントをリセット", action: #selector(fontReset(_:)), keyEquivalent: "0")
        viewMenu.addItem(NSMenuItem.separator())
        let tileItem = NSMenuItem(title: "ターミナルを並べて表示", action: #selector(tileNow(_:)), keyEquivalent: "t")
        tileItem.keyEquivalentModifierMask = [.command, .option]
        viewMenu.addItem(tileItem)
        viewMenu.addItem(withTitle: "自動で並べる（タイル表示）",
                         action: #selector(toggleAutoTile(_:)), keyEquivalent: "")
        viewMenu.addItem(NSMenuItem.separator())
        let mouseItem = NSMenuItem(title: "マウス操作をアプリに渡す（文字選択は無効になる）",
                                   action: #selector(toggleMouseReporting(_:)), keyEquivalent: "m")
        mouseItem.keyEquivalentModifierMask = [.command, .option]
        viewMenu.addItem(mouseItem)
        viewItem.submenu = viewMenu

        // Window
        let winItem = NSMenuItem(); mainMenu.addItem(winItem)
        let winMenu = NSMenu(title: "Window")
        winMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        winItem.submenu = winMenu
        NSApp.windowsMenu = winMenu

        NSApp.mainMenu = mainMenu
    }
}

// Finder/Dockから起動すると cwd が "/" になるためホームへ
FileManager.default.changeCurrentDirectoryPath(NSHomeDirectory())
Config.load()
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
