VERSION   = 1.9.1
LVERSION  = 1.3.0
IDENTITY = Developer ID Application: Manabu Bannai (4WRDD55WT2)
# 出力先。使用中の dist/Zen Code.app を壊さずビルドしたいときは
# make OUT=dist-next のように差し替える
OUT      ?= dist
BIN      = .build/release/mbcode
LBIN     = .build/release/zenlauncher

FLAGS = -Xswiftc -DFEATURE_TABS -Xswiftc -DFEATURE_HOTKEY

.PHONY: all icon run clean

all: icon
	swift build -c release $(FLAGS)
	$(call assemble,Zen Code,com.manabu.mbcode,Zen Code)
	rm -rf "$(OUT)/Zen Launcher.app"
	mkdir -p "$(OUT)/Zen Launcher.app/Contents/MacOS" "$(OUT)/Zen Launcher.app/Contents/Resources"
	sed -e 's/@NAME@/Zen Launcher/g' -e 's/@BUNDLE_ID@/com.manabu.zenlauncher/g' -e 's/@VERSION@/$(LVERSION)/g' \
	    Resources/Info-launcher.plist.in > "$(OUT)/Zen Launcher.app/Contents/Info.plist"
	cp $(LBIN) "$(OUT)/Zen Launcher.app/Contents/MacOS/zenlauncher"
	cp $(OUT)/mbcode.icns "$(OUT)/Zen Launcher.app/Contents/Resources/mbcode.icns"
	codesign --force --options runtime --timestamp \
	    --sign "$(IDENTITY)" "$(OUT)/Zen Launcher.app"

icon:
	swift scripts/makeicon.swift $(OUT)
	iconutil -c icns $(OUT)/mbcode.iconset -o $(OUT)/mbcode.icns

# $(1)=アプリ名(表示) $(2)=bundle id $(3)=appファイル名
define assemble
	rm -rf "$(OUT)/$(3).app"
	mkdir -p "$(OUT)/$(3).app/Contents/MacOS" "$(OUT)/$(3).app/Contents/Resources"
	sed -e 's/@NAME@/$(1)/g' -e 's/@BUNDLE_ID@/$(2)/g' -e 's/@VERSION@/$(VERSION)/g' \
	    Resources/Info.plist.in > "$(OUT)/$(3).app/Contents/Info.plist"
	cp $(BIN) "$(OUT)/$(3).app/Contents/MacOS/mbcode"
	cp $(OUT)/mbcode.icns "$(OUT)/$(3).app/Contents/Resources/mbcode.icns"
	codesign --force --options runtime --timestamp \
	    --entitlements Resources/mbcode.entitlements \
	    --sign "$(IDENTITY)" "$(OUT)/$(3).app"
endef

run: all
	open "$(OUT)/Zen Code.app"

clean:
	rm -rf .build dist
