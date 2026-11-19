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
DMG := $(DIST_DIR)/$(APP_NAME)-$(VERSION)-macos-arm64.dmg
DMG_STAGE := $(DIST_DIR)/dmg-stage

.PHONY: test app package release clean-release

test:
	swift test

release: app
	$(MAKE) package

app: test
	@test -n "$(VERSION)" || (echo "VERSION is required" >&2; exit 1)
	swift build -c release --product $(APP_NAME)
	rm -rf "$(APP)" "$(DMG)" "$(DMG_STAGE)"
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

package:
	@command -v create-dmg >/dev/null || (echo "Install create-dmg with: brew install create-dmg" >&2; exit 1)
	rm -f "$(DMG)"
	rm -rf "$(DMG_STAGE)"
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
	@if [ "$(SIGNING_IDENTITY)" != "-" ]; then \
		codesign --timestamp $(SIGNING_KEYCHAIN_FLAG) --sign "$(SIGNING_IDENTITY)" "$(DMG)"; \
	fi
	hdiutil verify "$(DMG)"
	rm -rf "$(DMG_STAGE)"
	@echo "Built $(DMG)"

clean-release:
	rm -rf "$(DIST_DIR)"
