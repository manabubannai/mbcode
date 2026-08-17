VERSION  = 1.6.0
IDENTITY = Developer ID Application: Manabu Bannai (4WRDD55WT2)
BIN      = .build/release/mbcode

FLAGS = -Xswiftc -DFEATURE_TABS -Xswiftc -DFEATURE_PALETTE -Xswiftc -DFEATURE_HOTKEY

.PHONY: all icon run clean

all: icon
	swift build -c release $(FLAGS)
	$(call assemble,Zen Code,com.manabu.mbcode,Zen Code)

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

run: all
	open "dist/Zen Code.app"

clean:
	rm -rf .build dist
