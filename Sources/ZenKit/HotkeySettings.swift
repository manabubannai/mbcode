import AppKit

// ============================================================
// ホットキー設定ウィンドウ（Zen Code / Zen Launcher 共用）
// ボタンをクリック → 新しいキーの組み合わせをそのまま押すと即保存。
// 保存すると DistributedNotification で両アプリに反映される。
// ============================================================

public final class HotkeySettings: NSObject, NSWindowDelegate {
    public static let shared = HotkeySettings()

    private var window: NSWindow?
    private var launcherRecorder: RecorderButton?
    private var quakeRecorder: RecorderButton?

    public func show() {
        if window == nil { build() }
        refresh()
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    private func build() {
        let launcher = RecorderButton(spec: Config.launcherHotkey) { spec in
            Config.saveHotkeys(quake: Config.hotkey, launcher: spec)
        }
        let quake = RecorderButton(spec: Config.hotkey) { spec in
            Config.saveHotkeys(quake: spec, launcher: Config.launcherHotkey)
        }
        launcherRecorder = launcher
        quakeRecorder = quake

        func label(_ text: String) -> NSTextField {
            let l = NSTextField(labelWithString: text)
            l.font = .systemFont(ofSize: 13)
            return l
        }
        func resetButton(_ action: Selector) -> NSButton {
            let b = NSButton(title: "標準に戻す", target: self, action: action)
            b.bezelStyle = .rounded
            b.controlSize = .small
            b.font = .systemFont(ofSize: 11)
            return b
        }

        let grid = NSGridView(views: [
            [label("ランチャーを開く"), launcher, resetButton(#selector(resetLauncher))],
            [label("Quake ターミナル"), quake, resetButton(#selector(resetQuake))],
        ])
        grid.rowSpacing = 12
        grid.columnSpacing = 12
        grid.column(at: 0).xPlacement = .trailing
        for row in 0..<grid.numberOfRows { grid.row(at: row).yPlacement = .center }

        let hint = NSTextField(wrappingLabelWithString:
            "ボタンをクリックして、新しいキーの組み合わせをそのまま押してください（esc で取消）。\n" +
            "変更はすぐに保存され、Zen Code と Zen Launcher の両方に反映されます。")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.preferredMaxLayoutWidth = 360

        let stack = NSStackView(views: [grid, hint])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let win = NSWindow(contentRect: .zero,
                           styleMask: [.titled, .closable],
                           backing: .buffered, defer: false)
        win.title = "ホットキー設定"
        win.isReleasedWhenClosed = false
        win.delegate = self
        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
        ])
        win.contentView = content
        win.setContentSize(content.fittingSize)
        window = win

        // 別アプリ側で変更された時も表示を追従させる
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(externalChange),
            name: Config.hotkeysChangedNote, object: nil)
    }

    private func refresh() {
        launcherRecorder?.spec = Config.launcherHotkey
        quakeRecorder?.spec = Config.hotkey
    }

    @objc private func externalChange() {
        Config.load()
        refresh()
    }

    @objc private func resetLauncher() {
        Config.saveHotkeys(quake: Config.hotkey, launcher: "shift-command-space")
        refresh()
    }

    @objc private func resetQuake() {
        Config.saveHotkeys(quake: "option-space", launcher: Config.launcherHotkey)
        refresh()
    }

    public func windowWillClose(_ notification: Notification) {
        launcherRecorder?.cancelRecording()
        quakeRecorder?.cancelRecording()
    }
}

// クリックで録画モードに入り、押されたキーの組み合わせを捕まえるボタン
final class RecorderButton: NSButton {
    var spec: String {
        didSet { if !recording { title = HotKeys.displayName(spec) } }
    }
    private let onChange: (String) -> Void
    private var recording = false
    private var monitor: Any?

    init(spec: String, onChange: @escaping (String) -> Void) {
        self.spec = spec
        self.onChange = onChange
        super.init(frame: .zero)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        title = HotKeys.displayName(spec)
        font = .systemFont(ofSize: 13)
        target = self
        action = #selector(clicked)
        widthAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func clicked() {
        recording ? cancelRecording() : startRecording()
    }

    private func startRecording() {
        recording = true
        title = "キーを押してください…"
        // 現在のホットキー自体も録画中は打てるよう、グローバル登録を一時停止
        HotKeys.pauseAll()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self, self.recording else { return event }
            if event.keyCode == 53 && event.modifierFlags.intersection(
                [.command, .option, .control, .shift]).isEmpty {
                self.cancelRecording()   // esc で取消
                return nil
            }
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard let newSpec = HotKeys.spec(keyCode: event.keyCode, flags: flags) else {
                NSSound.beep()
                return nil
            }
            self.spec = newSpec
            self.endRecording()
            self.onChange(newSpec)
            return nil
        }
    }

    private func endRecording() {
        recording = false
        title = HotKeys.displayName(spec)
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
        HotKeys.resumeAll()
    }

    func cancelRecording() {
        guard recording else { return }
        endRecording()
    }
}
