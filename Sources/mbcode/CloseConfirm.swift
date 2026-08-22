import AppKit
import Darwin
import ZenKit

// ウィンドウを閉じる前の確認（Terminal.app と同じ挙動）。
// シェルの上で何かが動いているときだけ聞く。プロンプトに戻っていれば黙って閉じる。
enum CloseConfirm {
    // シェル（pid）の子プロセス名を返す。空 = 何も動いていない
    static func runningProcesses(shellPid: pid_t) -> [String] {
        guard shellPid > 0 else { return [] }
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        guard sysctl(&mib, 4, nil, &size, nil, 0) == 0, size > 0 else { return [] }
        let stride = MemoryLayout<kinfo_proc>.stride
        // 取得の合間にプロセスが増えても溢れないよう少し多めに確保する
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: size / stride + 32)
        size = procs.count * stride
        guard sysctl(&mib, 4, &procs, &size, nil, 0) == 0 else { return [] }

        var names: [String] = []
        for i in 0 ..< (size / stride) where procs[i].kp_eproc.e_ppid == shellPid {
            var comm = procs[i].kp_proc.p_comm
            let length = MemoryLayout.size(ofValue: comm)
            let name = withUnsafePointer(to: &comm) {
                $0.withMemoryRebound(to: CChar.self, capacity: length) { String(cString: $0) }
            }
            if !name.isEmpty && !names.contains(name) { names.append(name) }
        }
        return names
    }

    // 実行中プロセスがあることを伝えるシート。「終了」を押したときだけ onClose を呼ぶ
    static func ask(window: NSWindow, processes: [String], onClose: @escaping () -> Void) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "このウインドウで実行中のプロセスを終了しますか？"
        alert.informativeText = "このウインドウを閉じると、実行中の以下のプロセスが終了します：\n"
            + processes.joined(separator: "、")
        // 既定は「キャンセル」。⌘W のあとに Return を押しても閉じない
        alert.addButton(withTitle: "キャンセル")
        alert.addButton(withTitle: "終了")
        alert.beginSheetModal(for: window) { response in
            guard response == .alertSecondButtonReturn else { return }
            onClose()
        }
    }
}
