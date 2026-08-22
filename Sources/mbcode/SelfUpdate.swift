import AppKit

// 開発機での自動差し替え。
// `…/dist/Zen Code.app` として動いているとき、隣の `…/dist-next/Zen Code.app`
// にバージョン違いのビルドがあれば、アプリ終了時に dist/ を置き換える。
// 次に起動したときには新しいビルドになっている（起動中の差し替えはしない）。
// 配布版は dist-next が無いので何も起きない。
enum SelfUpdate {
    private static let fm = FileManager.default

    private static func version(of bundle: URL) -> String? {
        guard let plist = NSDictionary(contentsOf: bundle
            .appendingPathComponent("Contents/Info.plist")) else { return nil }
        return plist["CFBundleShortVersionString"] as? String
    }

    /// アプリ終了時に呼ぶ。差し替えが必要なら、終了を待って実行する小さな
    /// シェルスクリプトを切り離して起動する。
    static func installPendingBuildOnQuit() {
        let current = Bundle.main.bundleURL                       // …/dist/Zen Code.app
        let dist = current.deletingLastPathComponent()            // …/dist
        guard dist.lastPathComponent == "dist" else { return }
        let next = dist.deletingLastPathComponent()
            .appendingPathComponent("dist-next")
        let nextApp = next.appendingPathComponent(current.lastPathComponent)
        guard fm.fileExists(atPath: nextApp.path),
              let newVersion = version(of: nextApp),
              newVersion != version(of: current) else { return }

        let appName = current.lastPathComponent                   // Zen Code.app
        let launcher = "Zen Launcher.app"
        let script = """
        #!/bin/sh
        log="$HOME/.mbcode/selfupdate.log"
        mkdir -p "$HOME/.mbcode"
        # 本体の終了を待つ（最長30秒）
        i=0
        while kill -0 \(getpid()) 2>/dev/null && [ $i -lt 300 ]; do sleep 0.1; i=$((i+1)); done
        sleep 0.5
        swap() {
          src="$1"; dst="$2"
          [ -d "$src" ] || return 0
          rm -rf "$dst.old"
          mv "$dst" "$dst.old" 2>/dev/null
          if ditto "$src" "$dst"; then
            rm -rf "$dst.old"
            echo "$(date '+%F %T') installed $src -> $dst" >> "$log"
          else
            rm -rf "$dst"; mv "$dst.old" "$dst"
            echo "$(date '+%F %T') FAILED $src -> $dst" >> "$log"
          fi
        }
        swap \(sh(next.appendingPathComponent(appName).path)) \(sh(dist.appendingPathComponent(appName).path))
        # Zen Launcher は常駐しているので、動いていないときだけ差し替える
        if ! pgrep -f 'Zen Launcher.app/Contents/MacOS/zenlauncher' > /dev/null 2>&1; then
          swap \(sh(next.appendingPathComponent(launcher).path)) \(sh(dist.appendingPathComponent(launcher).path))
        fi
        rm -f "$0"
        """
        let path = NSTemporaryDirectory() + "zencode-selfupdate-\(getpid()).sh"
        guard (try? script.write(toFile: path, atomically: true, encoding: .utf8)) != nil else { return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = [path]
        try? task.run()
    }

    // シェル用にシングルクォートで包む
    private static func sh(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
