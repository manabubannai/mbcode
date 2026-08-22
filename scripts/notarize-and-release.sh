#!/bin/bash
# notaryプロファイルが使えるようになったら 3エディションを公証→staple→zip→GitHub Release。
# バックグラウンド実行前提。ログ: $DIST/notarize.log（DIST未指定なら dist）
set -u
cd "$(dirname "$0")/.."
DIST="${DIST:-dist}"   # 使用中の dist を避けたいときは DIST=dist-next
LOG="$DIST/notarize.log"
VERSION=$(awk -F"= *" '/^VERSION/ {print $2; exit}' Makefile)
APPS=("Zen Code:ZenCode" "Zen Launcher:ZenLauncher")   # 配布は各アプリ1版のみ（マナブ方針）

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }

log "=== 公証待機開始 ==="
for i in $(seq 1 480); do
  if xcrun notarytool history --keychain-profile notary >/dev/null 2>&1; then
    log "notaryプロファイル検出（${i}分待ち）"
    break
  fi
  if [ "$i" -eq 480 ]; then
    log "TIMEOUT: 8時間待ってもnotaryプロファイルが現れず"
    exit 2
  fi
  sleep 60
done

mkdir -p "$DIST/upload"
FAIL=0
for pair in "${APPS[@]}"; do
  name="${pair%%:*}"; zipname="${pair##*:}"
  APP="$DIST/${name}.app"
  ZIP="$DIST/upload/${zipname}.zip"    # バージョン無し名で releases/latest リンクを恒久化
  rm -f "$ZIP"
  ditto -c -k --keepParent "$APP" "$ZIP"
  log "submit: $name"
  OUT=$(xcrun notarytool submit "$ZIP" --keychain-profile notary --wait 2>&1)
  echo "$OUT" >> "$LOG"
  if ! echo "$OUT" | grep -q "status: Accepted"; then
    log "ERROR: $name の公証が Accepted にならず"
    FAIL=1
    continue
  fi
  xcrun stapler staple "$APP" >> "$LOG" 2>&1
  rm -f "$ZIP"
  ditto -c -k --keepParent "$APP" "$ZIP"   # staple済みで作り直し
  spctl -a -vv "$APP" >> "$LOG" 2>&1
  log "OK: $name 公証+staple完了"
done

[ "$FAIL" -eq 1 ] && { log "一部失敗のためRelease作成を中止"; exit 3; }

log "GitHub Release作成"
gh release create "v${VERSION}" \
  "$DIST/upload/ZenCode.zip" "$DIST/upload/ZenLauncher.zip" \
  --title "Zen Code v${VERSION}" \
  --notes-file scripts/release-notes.md >> "$LOG" 2>&1 || { log "ERROR: gh release create 失敗"; exit 4; }

log "=== 完了: https://github.com/manabubannai/mbcode/releases/tag/v${VERSION} ==="
