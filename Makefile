VERSION  = 1.1.1
IDENTITY = Developer ID Application: Manabu Bannai (4WRDD55WT2)
BIN      = .build/release/mbcode

STD_FLAGS = -Xswiftc -DFEATURE_TABS -Xswiftc -DFEATURE_PALETTE
PRO_FLAGS = $(STD_FLAGS) -Xswiftc -DFEATURE_HOTKEY

.PHONY: all lite standard pro icon run clean

all: lite standard pro

icon:
	swift scripts/makeicon.swift dist
	iconutil -c icns dist/mbcode.iconset -o dist/mbcode.icns

# $(1)=アプリ名(表示) $(2)=bundle id $(3)=appファイル名
define assemble
	rm -rf "dist/$(3).app"
	mkdir -p "dist/$(3).app/Contents/MacOS" "dist/$(3).app/Contents/Resources"
	sed -e 's/@NAME@/$(1)/g' -e 's/@BUNDLE_ID@/$(2)/g' -e 's/@VERSION@/$(VERSION)/g' \
	    Resources/Info.plist.in > "dist/$(3).app/Contents/Info.plist"
	cp $(BIN) "dist/$(3).app/Contents/MacOS/mbcode"
	cp dist/mbcode.icns "dist/$(3).app/Contents/Resources/mbcode.icns"
	codesign --force --options runtime --timestamp \
	    --entitlements Resources/mbcode.entitlements \
	    --sign "$(IDENTITY)" "dist/$(3).app"
endef

lite: icon
	swift build -c release
	$(call assemble,Kurogane Lite,com.manabu.mbcode.lite,Kurogane Lite)

standard: icon
	swift build -c release $(STD_FLAGS)
	$(call assemble,Kurogane,com.manabu.mbcode,Kurogane)

pro: icon
	swift build -c release $(PRO_FLAGS)
	$(call assemble,Kurogane Pro,com.manabu.mbcode.pro,Kurogane Pro)

run: standard
	open "dist/Kurogane.app"

clean:
	rm -rf .build dist
