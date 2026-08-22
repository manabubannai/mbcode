import AppKit
import ZenKit

// Zen Launcher: メニューバー常駐の軽量ランチャー（Alfredスタイル）。
// ⇧⌘Space でパレットを開き、選んだプロジェクトを zencode:// URLで Zen Code に渡す。
// ターミナル本体（Zen Code）は常駐しない。常駐して待つのは数MBのこのアプリだけ。
final class LauncherAppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private var statusItem: NSStatusItem!

    private let palette = LauncherPalette { item, plainShell in
        var comps = URLComponents()
        comps.scheme = "zencode"
        comps.host = "open"
        var query: [URLQueryItem] = []
        if item.isConfigCommand {
            // config.json のコマンドは keyword だけ渡し、実行内容は Zen Code 側の
            // config で解決する（URL経由で任意コマンドを受け取らないため）
            query.append(URLQueryItem(name: "keyword", value: item.keyword))
        } else {
            query.append(URLQueryItem(name: "path", value: item.directory))
        }
        if plainShell { query.append(URLQueryItem(name: "plain", value: "1")) }
        comps.queryItems = query
        guard let url = comps.url else { return }
        if !NSWorkspace.shared.open(url) {
            let alert = NSAlert()
            alert.messageText = "Zen Code が見つかりません"
            alert.informativeText = "zencode:// を開けませんでした。Zen Code（v1.7.0以降）をインストールして一度起動してください。"
            alert.runModal()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // LSUIElement と二重の保険
        buildStatusItem()
        HotKeys.register(id: 2, spec: Config.launcherHotkey) { [palette] in palette.toggle() }
        LoginItem.setupOnLaunch()
        // 設定画面（Zen Code 側含む）でホットキーが変わったら追従する
        DistributedNotificationCenter.default().addObserver(
            forName: Config.hotkeysChangedNote, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Config.load()
            HotKeys.register(id: 2, spec: Config.launcherHotkey) { [palette = self.palette] in
                palette.toggle()
            }
            self.buildStatusItem()   // メニューのショートカット表示を更新
        }
    }

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "chevron.right.square.fill",
                                   accessibilityDescription: "Zen Launcher")
        }
        let menu = NSMenu()
        let openItem = NSMenuItem(title: "ランチャーを開く", action: #selector(openPalette(_:)), keyEquivalent: "")
        if let (key, mods) = HotKeys.menuKeyEquivalent(for: Config.launcherHotkey) {
            openItem.keyEquivalent = key
            openItem.keyEquivalentModifierMask = mods
        }
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(NSMenuItem.separator())
        let hotkeyItem = NSMenuItem(title: "ホットキー設定…", action: #selector(openHotkeySettings(_:)), keyEquivalent: "")
        hotkeyItem.target = self
        menu.addItem(hotkeyItem)
        let configItem = NSMenuItem(title: "設定を開く（config.json）", action: #selector(openConfig(_:)), keyEquivalent: "")
        configItem.target = self
        menu.addItem(configItem)
        let loginItem = NSMenuItem(title: "ログイン時に自動起動", action: #selector(toggleLoginItem(_:)), keyEquivalent: "")
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Zen Launcher を終了",
                     action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    @objc private func openPalette(_ sender: Any?) {
        palette.show()
    }

    @objc private func openConfig(_ sender: Any?) {
        NSWorkspace.shared.open(URL(fileURLWithPath: Config.path))
    }

    @objc private func openHotkeySettings(_ sender: Any?) {
        HotkeySettings.shared.show()
    }

    @objc private func toggleLoginItem(_ sender: NSMenuItem) {
        LoginItem.toggle()
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if item.action == #selector(toggleLoginItem(_:)) {
            item.state = LoginItem.isEnabled ? .on : .off
        }
        return true
    }
}

Config.load()
let app = NSApplication.shared
let delegate = LauncherAppDelegate()
app.delegate = delegate
app.run()
