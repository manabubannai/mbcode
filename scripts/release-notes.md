# Zen Code v1.4.0

どこでもランチャー搭載 + 1版に統一。

- **どこでもランチャー（⇧⌘Space）**: どのアプリからでも呼び出せるAlfred風のプロジェクトランチャー。`cc` と打って Enter で該当フォルダにClaude Code入りターミナルが開く
  - 候補 = `config.json` の commands + `~/Documents` 直下のgitリポジトリ（自動検出・設定不要）
  - あいまい検索＋よく使う順（使用履歴で自動学習）
  - 同じプロジェクトのウィンドウが既にあれば新規ではなくそれにフォーカス
  - ⌘Enter でコマンドを実行せずシェルだけ開く。キーは `launcherHotkey`、自動検出リポジトリの起動コマンドは `launcherCommand`（既定 claude）、検出フォルダは `projectsDir` で変更可
- **エディション統一**: Lite/Standard/Pro を廃止し「Zen Code」1本に（タブ・ランチャー・⌥Space常駐ターミナルすべて入り）
- v1.3.x までの内容を含む: マイク修正・Clear Lightデザイン・余白14px・バグ報告メニュー

## ダウンロード

`ZenCode.zip` をダウンロード → 解凍してアプリケーションフォルダへ。Developer ID 署名 + Apple 公証済み。

## 動作環境

macOS 13 Ventura 以降
