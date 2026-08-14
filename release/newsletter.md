# メルマガ用リリース文（mbcode v1.0.0）

---

## 「cc」と打つだけでAIが立ち上がるターミナル「mbcode」を作りました（無料・Macアプリ）

自分用のターミナルアプリを作りました。ターミナルというのは、Macに入っている「黒い画面」のことです。最近はここでClaude CodeのようなAIを動かすのが自分の仕事場になっているのですが、毎回「ターミナルを開く → 作業フォルダに移動 → 起動コマンドを打つ」を繰り返すのが地味に面倒でした。

mbcodeはそれを1動作にしたターミナルです。⌘Kを押して「cc」と打ってEnter。これだけでClaude Codeが立ち上がります。よく使うコマンドは設定ファイルに好きなだけ登録できて、どれも2〜3文字のキーワードで呼び出せます。AIを使わない人でも「よく使うコマンドのランチャー内蔵ターミナル」として使えます。

3つのバージョンを用意しました。迷ったら真ん中のStandardをどうぞ。

**ダウンロード（無料）**
- Standard（おすすめ。タブ+コマンドパレット付き）
  https://github.com/manabubannai/mbcode/releases/latest/download/mbcode.zip
- Lite(最小構成)
  https://github.com/manabubannai/mbcode/releases/latest/download/mbcode-lite.zip
- Pro（Standard+⌥Spaceでどの画面からでも呼び出せる）
  https://github.com/manabubannai/mbcode/releases/latest/download/mbcode-pro.zip

zipを解凍して、出てきたアプリをアプリケーションフォルダに入れるだけです。Appleの公証を通してあるので、そのままダブルクリックで開けます。初回起動で設定ファイル（~/.mbcode/config.json）が自動で作られるので、コマンドを足したくなったら⌘,で開いて編集してください。

**コードも全部公開しています**
https://github.com/manabubannai/mbcode

中身が気になる人、自分で改造したい人はどうぞ。Swift製で、ファイルは実質5つしかありません。AIに「このコードを解説して」と投げると、Macアプリがどう作られているかの良い教材になると思います。

こんな感じで、毎日1つ、道具を作って配っていきます。「こういうのが欲しい」があれば、このメールに返信してください。次の題材にします。

---

※ダウンロードリンクは公証完了・Release作成後に有効になる
