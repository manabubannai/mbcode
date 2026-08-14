# mbcode v1.0.0

Claude Code 時代の、自分専用ミニマルターミナル。

「ターミナルを開いて、cd して、`claude --dangerously-skip-permissions` と打つ」を、**`cc` + Enter だけ**にしました。

## ダウンロード（3エディション）

| ファイル | 内容 |
|---|---|
| `mbcode.zip` | **Standard（おすすめ）** — タブ + ⌘K コマンドパレット |
| `mbcode-lite.zip` | Lite — 最小構成（クイックコマンドはメニュー/⌘1〜9のみ） |
| `mbcode-pro.zip` | Pro — Standard + ⌥Space でどこからでも呼び出せるターミナル |

すべて Developer ID 署名 + Apple 公証済み。解凍してアプリケーションフォルダへ入れるだけで動きます。

## 主な機能

- **クイックコマンド**: `~/.mbcode/config.json` に「キーワード・ディレクトリ・コマンド」を書くと、⌘K パレット（Standard/Pro）や ⌘1〜⌘9 から一発起動
- タブ（⌘T）・テーマ4種・フォントサイズ調整（⌘+/-）
- Pro はグローバルホットキー（デフォルト ⌥Space、`config.json` で変更可。Alfred 使いは `control-option-space` 推奨）

## 動作環境

macOS 13 Ventura 以降
