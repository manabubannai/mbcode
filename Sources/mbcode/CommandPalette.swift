#if FEATURE_PALETTE
import AppKit

// ⌘K で開くコマンドパレット。Alfred のように "cc" と打って Enter で
// 該当ディレクトリに移動してコマンドを実行する新規ウィンドウを開く。
final class CommandPalette: NSObject, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
    static let shared = CommandPalette()

    private var panel: NSPanel!
    private var field: NSTextField!
    private var table: NSTableView!
    private var filtered: [QuickCommand] = []

    func toggle() {
        if panel?.isVisible == true {
            close()
        } else {
            show()
        }
    }

    func show() {
        if panel == nil { build() }
        filtered = Config.commands
        field.stringValue = ""
        table.reloadData()
        selectRow(0)
        layoutPanel()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(field)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        panel?.orderOut(nil)
    }

    private func build() {
        let width: CGFloat = 560
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: 240),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 0.98)
        panel.hidesOnDeactivate = true

        field = NSTextField(frame: .zero)
        field.font = NSFont.monospacedSystemFont(ofSize: 20, weight: .regular)
        field.placeholderString = "コマンドを検索…（例: cc）"
        field.isBordered = false
        field.focusRingType = .none
        field.backgroundColor = .clear
        field.textColor = .white
        field.delegate = self

        table = NSTableView(frame: .zero)
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("cmd"))
        col.width = width - 40
        table.addTableColumn(col)
        table.headerView = nil
        table.rowHeight = 40
        table.backgroundColor = .clear
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(runSelected)

        let scroll = NSScrollView(frame: .zero)
        scroll.documentView = table
        scroll.hasVerticalScroller = false
        scroll.drawsBackground = false

        let content = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 240))
        field.frame = NSRect(x: 20, y: 240 - 52, width: width - 40, height: 32)
        field.autoresizingMask = [.width, .minYMargin]
        scroll.frame = NSRect(x: 12, y: 12, width: width - 24, height: 240 - 72)
        scroll.autoresizingMask = [.width, .height]
        content.addSubview(field)
        content.addSubview(scroll)
        panel.contentView = content
    }

    private func layoutPanel() {
        guard let screen = NSScreen.main else { return }
        let height = min(CGFloat(72 + filtered.count * 42), 400)
        let width: CGFloat = 560
        let x = screen.visibleFrame.midX - width / 2
        let y = screen.visibleFrame.midY + 80
        panel.setFrame(NSRect(x: x, y: y, width: width, height: max(height, 120)), display: true)
    }

    private func filter(_ query: String) {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        if q.isEmpty {
            filtered = Config.commands
        } else {
            filtered = Config.commands.filter {
                $0.keyword.lowercased().hasPrefix(q)
                    || $0.title.lowercased().contains(q)
                    || $0.command.lowercased().contains(q)
            }
        }
        table.reloadData()
        selectRow(0)
    }

    private func selectRow(_ row: Int) {
        guard filtered.indices.contains(row) else { return }
        table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        table.scrollRowToVisible(row)
    }

    @objc private func runSelected() {
        let row = table.selectedRow
        guard filtered.indices.contains(row >= 0 ? row : 0) else { return }
        let cmd = filtered[row >= 0 ? row : 0]
        close()
        TermWindowController(command: cmd).showCentered()
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        filter(field.stringValue)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            runSelected()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            close()
            return true
        case #selector(NSResponder.moveDown(_:)):
            selectRow(min(table.selectedRow + 1, filtered.count - 1))
            return true
        case #selector(NSResponder.moveUp(_:)):
            selectRow(max(table.selectedRow - 1, 0))
            return true
        default:
            return false
        }
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int { filtered.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cmd = filtered[row]
        let cell = NSView()
        let keyword = NSTextField(labelWithString: cmd.keyword)
        keyword.font = NSFont.monospacedSystemFont(ofSize: 15, weight: .bold)
        keyword.textColor = NSColor(calibratedRed: 0.35, green: 0.85, blue: 0.55, alpha: 1.0)
        keyword.frame = NSRect(x: 8, y: 10, width: 90, height: 20)
        let title = NSTextField(labelWithString: cmd.title)
        title.font = NSFont.systemFont(ofSize: 14)
        title.textColor = .white
        title.frame = NSRect(x: 104, y: 10, width: 420, height: 20)
        cell.addSubview(keyword)
        cell.addSubview(title)
        return cell
    }
}
#endif
