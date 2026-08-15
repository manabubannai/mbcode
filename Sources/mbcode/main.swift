import AppKit
import SwiftTerm

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        TermWindowController().showCentered()
        #if FEATURE_HOTKEY
        HotKeyTerminal.shared.register()
        #endif
        #if FEATURE_PALETTE
        CommandPalette.shared.registerGlobalHotKey()
        #endif
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        #if FEATURE_HOTKEY
        return false   // Pro は ⌥Space 常駐のため残す
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

    #if FEATURE_PALETTE
    @objc func togglePalette(_ sender: Any?) {
        CommandPalette.shared.toggle()
    }
    #endif

    @objc func runQuickCommand(_ sender: NSMenuItem) {
        guard Config.commands.indices.contains(sender.tag) else { return }
        TermWindowController(command: Config.commands[sender.tag]).showCentered()
    }

    @objc func openConfig(_ sender: Any?) {
        NSWorkspace.shared.open(URL(fileURLWithPath: Config.path))
    }

    @objc func reportBug(_ sender: Any?) {
        BugReport.shared.show()
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
        let pref = NSMenuItem(title: "設定を開く（config.json）", action: #selector(openConfig(_:)), keyEquivalent: ",")
        appMenu.addItem(pref)
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
        #if FEATURE_PALETTE
        cmdMenu.addItem(withTitle: "ランチャー", action: #selector(togglePalette(_:)), keyEquivalent: "k")
        let globalItem = NSMenuItem(title: "ランチャー（どこでも）", action: #selector(togglePalette(_:)), keyEquivalent: " ")
        globalItem.keyEquivalentModifierMask = [.command, .shift]
        cmdMenu.addItem(globalItem)
        cmdMenu.addItem(NSMenuItem.separator())
        #endif
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
