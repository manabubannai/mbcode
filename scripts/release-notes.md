# Zen Code v1.3.0

改名リリース。「Kurogane」→「Zen Code」になりました。中身は v1.2.1 と同じです。

- アプリ名を Zen Code に変更（Bundle ID は互換のため据え置き。マイク許可などの設定は引き継がれます）
- 配布を Standard 1版に統一（`ZenCode.zip`）
- v1.2.x の内容を含む: Claude Code 音声入力のマイク修正・Terminal.app「Clear Light」移植デザイン（半透明ぼかし背景・ANSI16色・行間1.3・余白14px）

## ダウンロード

`ZenCode.zip` をダウンロード → 解凍してアプリケーションフォルダへ。Developer ID 署名 + Apple 公証済み。

## 主な機能

- **クイックコマンド**: `~/.mbcode/config.json` に「キーワード・ディレクトリ・コマンド」を書くと、⌘K パレットや ⌘1〜⌘9 から一発起動（デフォルトで `cc` = Claude Code）
- タブ（⌘T）・フォントサイズ調整（⌘+/-）・テーマ/フォント/行間/余白を `config.json` で調整可

## 動作環境

macOS 13 Ventura 以降
