# Kurogane v1.1.1

マイク修正リリース。ターミナル内で動かすツール（Claude Code の音声入力など）がマイクを使えるようになりました。

- 修正: hardened runtime のマイク entitlement と `NSMicrophoneUsageDescription` が無く、Claude Code のスペース押しっぱなし音声入力が「No audio detected from microphone」で失敗していた問題
- 初回にマイク使用時、macOS の許可ダイアログが出るので「許可」を押してください

## ダウンロード（3エディション）

| ファイル | 内容 |
|---|---|
| `Kurogane.zip` | **Standard（おすすめ）** — タブ + ⌘K コマンドパレット |
| `Kurogane-lite.zip` | Lite — 最小構成（クイックコマンドはメニュー/⌘1〜9のみ） |
| `Kurogane-pro.zip` | Pro — Standard + ⌥Space でどこからでも呼び出せるターミナル |

すべて Developer ID 署名 + Apple 公証済み。解凍してアプリケーションフォルダへ入れるだけで動きます。

## 主な機能

- **クイックコマンド**: `~/.mbcode/config.json` に「キーワード・ディレクトリ・コマンド」を書くと、⌘K パレット（Standard/Pro）や ⌘1〜⌘9 から一発起動
- タブ（⌘T）・テーマ4種・フォントサイズ調整（⌘+/-）
- Pro はグローバルホットキー（デフォルト ⌥Space、`config.json` で変更可。Alfred 使いは `control-option-space` 推奨）

## 動作環境

macOS 13 Ventura 以降
