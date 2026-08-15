# Kurogane v1.2.1

デザイン刷新リリース。macOS標準ターミナルの見やすさをそのまま移植しました。

- v1.2.1: 文字とウィンドウ端の余白を追加（デフォルト14px、`config.json` の `padding` で調整可）

- 新デフォルトテーマ「clear-light」: 白の半透明背景（すりガラスぼかし付き）+ ANSI16色フルパレット。Terminal.app の「Clear Light」プロファイル実測値ベース
- 行間を約1.3倍に（Terminal.app 同等）。`config.json` の `lineSpacing` で調整可
- フォント指定に対応（デフォルトは PlemolJP Console NF があれば使用、無ければ等幅システムフォント）
- 選択色・カーソル色もテーマに追従。従来のダーク系テーマ（manabu-dark 等）も `config.json` の `theme` で選択可
- v1.1.1 のマイク修正（Claude Code 音声入力対応）も同梱。初回マイク使用時は macOS の許可ダイアログで「許可」を押してください

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
