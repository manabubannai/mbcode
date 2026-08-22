import AppKit

// 複数ターミナルをグリッド状に並べて表示するタイルモード。
// 先頭スロット（画面左上）は「AIの作業が最後に完了したターミナル」。
// タブグループは1枚として数える（グループごと動く）。
enum TileLayout {
    private static let defaultsKey = "tileMode"

    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: defaultsKey)
            if newValue { retile() }
        }
    }

    private static let gap: CGFloat = 10

    private struct WeakWindow { weak var window: NSWindow? }
    // 表示順（先頭 = 左上）。閉じたウィンドウは compactMap で自然に消える
    private static var order: [WeakWindow] = []

    private static func representative(_ window: NSWindow) -> NSWindow {
        window.tabGroup?.windows.first ?? window
    }

    private static func visibleWindows() -> [NSWindow] {
        var seen = Set<ObjectIdentifier>()
        var result: [NSWindow] = []
        for wc in TermWindowController.allControllers {
            guard let w = wc.window, w.isVisible, !w.isMiniaturized else { continue }
            let rep = representative(w)
            if seen.insert(ObjectIdentifier(rep)).inserted { result.append(rep) }
        }
        return result
    }

    // AIの作業が完了したターミナルを左上スロットへ
    static func promote(_ wc: TermWindowController) {
        guard enabled, let win = wc.window.map(representative) else { return }
        var ordered = order.compactMap(\.window)
        ordered.removeAll { $0 === win }
        ordered.insert(win, at: 0)
        order = ordered.map { WeakWindow(window: $0) }
        retile()
    }

    static func retile(force: Bool = false) {
        guard enabled || force else { return }
        let wins = visibleWindows()
        // 既存順を保ちつつ、新規ウィンドウは末尾へ
        var ordered = order.compactMap(\.window).filter { w in wins.contains { $0 === w } }
        for w in wins where !ordered.contains(where: { $0 === w }) { ordered.append(w) }
        order = ordered.map { WeakWindow(window: $0) }
        // 1枚だけなら並べない（通常の中央表示のまま）
        guard ordered.count > 1 else { return }

        let screen = NSApp.keyWindow?.screen ?? ordered[0].screen ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }

        let n = ordered.count
        let cols = Int(ceil(sqrt(Double(n))))
        let rows = Int(ceil(Double(n) / Double(cols)))
        let w = (frame.width - gap * CGFloat(cols + 1)) / CGFloat(cols)
        let h = (frame.height - gap * CGFloat(rows + 1)) / CGFloat(rows)
        for (i, win) in ordered.enumerated() {
            let row = i / cols
            let col = i % cols
            let x = frame.minX + gap + CGFloat(col) * (w + gap)
            let y = frame.maxY - (gap + h) * CGFloat(row + 1)
            win.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true, animate: true)
        }
    }
}
