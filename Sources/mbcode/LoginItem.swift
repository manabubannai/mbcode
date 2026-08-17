import AppKit
import ServiceManagement

// ログイン時の自動起動（システム設定 > ログイン項目 に登録される）。
// 初回起動時に一度だけ自動で有効化し、以降はメニューやシステム設定での
// オン/オフを尊重して勝手に再登録しない。
enum LoginItem {
    private static let didAutoEnableKey = "didAutoEnableLoginItem"

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func setupOnLaunch() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: didAutoEnableKey) else { return }
        defaults.set(true, forKey: didAutoEnableKey)
        try? SMAppService.mainApp.register()
    }

    static func toggle() {
        if isEnabled {
            try? SMAppService.mainApp.unregister()
        } else {
            try? SMAppService.mainApp.register()
        }
    }
}
