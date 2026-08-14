# mbcode

Claude Code 時代の、自分専用ミニマルターミナル。macOS 用。

Alfred でやっていた「`cc` と打つだけで Claude Code が全権限モードで立ち上がる」を、
ターミナル自体に内蔵しました。Swift + [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) 製、依存はこの1つだけ。

## 3つのエディション

| | Lite | Standard | Pro |
|---|---|---|---|
| ターミナル（複数ウィンドウ・テーマ・フォント調整） | ✅ | ✅ | ✅ |
| クイックコマンド（メニュー / ⌘1〜⌘9） | ✅ | ✅ | ✅ |
| タブ（⌘T） | — | ✅ | ✅ |
| コマンドパレット（⌘K で "cc" と打って Enter） | — | ✅ | ✅ |
| グローバルホットキーの呼び出しターミナル（⌥Space） | — | — | ✅ |

どれも署名・公証済みの .app です。[Releases](../../releases) から zip をダウンロードして、
解凍したアプリをアプリケーションフォルダに入れるだけ。

## 使い方

- 初回起動で `~/.mbcode/config.json` が生成されます（⌘, でいつでも開けます）
- **クイックコマンド**: `config.json` の `commands` に「キーワード・ディレクトリ・コマンド」を書くと、
  Commands メニュー（⌘1〜⌘9）と ⌘K パレットから一発起動できます

```json
{
  "fontSize": 14,
  "theme": "manabu-dark",
  "hotkey": "option-space",
  "commands": [
    { "keyword": "cc", "title": "Claude Code（全権限モード）",
      "directory": "~", "command": "claude --dangerously-skip-permissions" }
  ]
}
```

- `theme`: `manabu-dark` / `solarized-dark` / `gruvbox-dark` / `light`
- `fontName`: 好きな等幅フォント名（未指定ならシステム等幅）
- `hotkey`（Pro）: `option-space` がデフォルト。**Alfred の ⌥Space と被る人は**
  `control-option-space` や `f12` などに変更してください
- `shell`: 未指定ならログインシェル（`$SHELL -l`）

## 自分でビルドする

```sh
make standard   # dist/mbcode.app
make all        # Lite / Standard / Pro を全部
```

署名まわりは Makefile の `IDENTITY` を自分の Developer ID に書き換えてください
（ad-hoc でよければ `codesign -s -` に）。

## ライセンス

MIT
