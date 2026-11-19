SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

APP_NAME := Nameplate
BUNDLE_ID ?= com.pranavbansal.Nameplate
SIGNING_IDENTITY ?= -
SIGNING_KEYCHAIN_FLAG = $(if $(SIGNING_KEYCHAIN),--keychain "$(SIGNING_KEYCHAIN)",)
VERSION ?= $(shell tr -d '\n' < version.txt)
BUILD_DIR = $(shell swift build -c release --show-bin-path)
DIST_DIR := dist
APP := $(DIST_DIR)/$(APP_NAME).app
ZIP := $(DIST_DIR)/$(APP_NAME)-$(VERSION)-macos-arm64.zip
DMG := $(DIST_DIR)/$(APP_NAME)-$(VERSION)-macos-arm64.dmg
DMG_STAGE := $(DIST_DIR)/dmg-stage

.PHONY: test release clean-release

test:
	swift test

release: test
	@test -n "$(VERSION)" || (echo "VERSION is required" >&2; exit 1)
	@command -v create-dmg >/dev/null || (echo "Install create-dmg with: brew install create-dmg" >&2; exit 1)
	swift build -c release --product $(APP_NAME)
	rm -rf "$(APP)" "$(ZIP)" "$(DMG)" "$(DMG_STAGE)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp "$(BUILD_DIR)/$(APP_NAME)" "$(APP)/Contents/MacOS/$(APP_NAME)"
	cp "Assets/Nameplate.icns" "$(APP)/Contents/Resources/Nameplate.icns"
	cp -R "$(BUILD_DIR)/Nameplate_Nameplate.bundle" "$(APP)/Contents/Resources/"
	/usr/libexec/PlistBuddy -c 'Add :CFBundleIdentifier string $(BUNDLE_ID)' \
		-c 'Add :CFBundleName string $(APP_NAME)' \
		-c 'Add :CFBundleDisplayName string $(APP_NAME)' \
		-c 'Add :CFBundleExecutable string $(APP_NAME)' \
		-c 'Add :CFBundlePackageType string APPL' \
		-c 'Add :CFBundleIconFile string Nameplate'  \
		-c 'Add :CFBundleShortVersionString string $(VERSION)' \
		-c 'Add :CFBundleVersion string $(VERSION)' \
		-c 'Add :LSMinimumSystemVersion string 26.0' \
		-c 'Add :LSUIElement bool true' \
		"$(APP)/Contents/Info.plist"
	@if [ "$(SIGNING_IDENTITY)" = "-" ]; then \
		codesign --force --deep --sign - "$(APP)"; \
	else \
		codesign --force --deep --options runtime --timestamp $(SIGNING_KEYCHAIN_FLAG) --sign "$(SIGNING_IDENTITY)" "$(APP)"; \
	fi
	codesign --verify --deep --strict "$(APP)"
	@if [ -n "$(NOTARY_KEYCHAIN_PROFILE)" ] && [ "$(SIGNING_IDENTITY)" = "-" ]; then echo "Notarization requires Developer ID signing" >&2; exit 1; fi
	cd "$(DIST_DIR)" && ditto -c -k --sequesterRsrc --keepParent "$(APP_NAME).app" "$(notdir $(ZIP))"
	@if [ -n "$(NOTARY_KEYCHAIN_PROFILE)" ]; then \
		bash scripts/notarize-release.sh "$(ZIP)" "$(APP)"; \
		rm -f "$(ZIP)"; \
		cd "$(DIST_DIR)" && ditto -c -k --sequesterRsrc --keepParent "$(APP_NAME).app" "$(notdir $(ZIP))"; \
	fi
	mkdir -p "$(DMG_STAGE)"
	ditto "$(APP)" "$(DMG_STAGE)/$(APP_NAME).app"
	create-dmg \
		--volname "$(APP_NAME)" \
		--volicon "Assets/Nameplate.icns" \
		--window-size 600 360 \
		--icon-size 128 \
		--icon "$(APP_NAME).app" 150 175 \
		--hide-extension "$(APP_NAME).app" \
		--app-drop-link 450 175 \
		"$(DMG)" "$(DMG_STAGE)"
	@if [ -n "$(NOTARY_KEYCHAIN_PROFILE)" ]; then \
		codesign --timestamp $(SIGNING_KEYCHAIN_FLAG) --sign "$(SIGNING_IDENTITY)" "$(DMG)"; \
		bash scripts/notarize-release.sh "$(DMG)" "$(DMG)"; \
		spctl --assess --type execute --verbose "$(APP)"; \
	fi
	hdiutil verify "$(DMG)"
	rm -rf "$(DMG_STAGE)"
	@echo "Built $(ZIP) and $(DMG)"

clean-release:
	rm -rf "$(DIST_DIR)"
