import AppKit

/// バグ報告ウィンドウ。メニュー「バグを報告…」から開く。
/// 「メールでバグを報告」ボタンで既定メールクライアントを mailto で起動する。
final class BugReport: NSObject {
    static let shared = BugReport()
    private var window: NSWindow?

    static let supportAddress = "manablog.ai@gmail.com"

    static var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "?"
    }

    /// mailto URL は URLComponents で組み立てて正しくエンコードする
    static var mailtoURL: URL? {
        let body = """
        ■ どんな不具合ですか？
        （ここに書いてください）

        ■ 直前に何をしましたか？（再現手順）
        （ここに書いてください）

        ---
        アプリ: Zen Code v\(appVersion)
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        """
        var comps = URLComponents()
        comps.scheme = "mailto"
        comps.path = supportAddress
        comps.queryItems = [
            URLQueryItem(name: "subject", value: "【バグ報告】Zen Code v\(appVersion)"),
            URLQueryItem(name: "body", value: body),
        ]
        return comps.url
    }

    @objc func openMail(_ sender: Any?) {
        if let url = Self.mailtoURL {
            NSWorkspace.shared.open(url)
        }
    }

    func show() {
        if let win = window {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let intro = NSTextField(wrappingLabelWithString:
            "不具合を見つけたら、下のボタンからメールでお知らせください。\n再現手順のテンプレートが入ったメールが開きます。")
        intro.font = .systemFont(ofSize: 13)

        let button = NSButton(title: "メールでバグを報告",
                              target: self, action: #selector(openMail(_:)))
        button.bezelStyle = .rounded
        button.keyEquivalent = "\r"

        let note = NSTextField(wrappingLabelWithString:
            "メールが開かない場合は \(Self.supportAddress) へ直接お送りください。")
        note.font = .systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor
        note.isSelectable = true   // アドレスを選択コピーできるように

        let stack = NSStackView(views: [intro, button, note])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            content.widthAnchor.constraint(equalToConstant: 380),
        ])

        let win = NSWindow(contentRect: .zero,
                           styleMask: [.titled, .closable],
                           backing: .buffered, defer: false)
        win.title = "バグを報告"
        win.contentView = content
        win.isReleasedWhenClosed = false
        win.setContentSize(content.fittingSize)
        win.center()
        window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
