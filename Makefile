APP_NAME := Nameplate
BUNDLE_ID ?= com.pranavbansal.Nameplate
SIGNING_IDENTITY ?= -
VERSION ?= $(shell tr -d '\n' < version.txt)
BUILD_DIR = $(shell swift build -c release --show-bin-path)
DIST_DIR := dist
APP := $(DIST_DIR)/$(APP_NAME).app
ZIP := $(DIST_DIR)/$(APP_NAME)-$(VERSION)-macos-arm64.zip

.PHONY: test release clean-release

test:
	swift test

release: test
	@test -n "$(VERSION)" || (echo "VERSION is required" >&2; exit 1)
	swift build -c release --product $(APP_NAME)
	rm -rf "$(APP)" "$(ZIP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp "$(BUILD_DIR)/$(APP_NAME)" "$(APP)/Contents/MacOS/$(APP_NAME)"
	cp -R "$(BUILD_DIR)/Nameplate_Nameplate.bundle" "$(APP)/Contents/Resources/"
	/usr/libexec/PlistBuddy -c 'Add :CFBundleIdentifier string $(BUNDLE_ID)' \
		-c 'Add :CFBundleName string $(APP_NAME)' \
		-c 'Add :CFBundleDisplayName string $(APP_NAME)' \
		-c 'Add :CFBundleExecutable string $(APP_NAME)' \
		-c 'Add :CFBundlePackageType string APPL' \
		-c 'Add :CFBundleShortVersionString string $(VERSION)' \
		-c 'Add :CFBundleVersion string $(VERSION)' \
		-c 'Add :LSMinimumSystemVersion string 26.0' \
		-c 'Add :LSUIElement bool true' \
		"$(APP)/Contents/Info.plist"
	@if [ "$(SIGNING_IDENTITY)" = "-" ]; then \
		codesign --force --deep --sign - "$(APP)"; \
	else \
		codesign --force --deep --options runtime --timestamp --sign "$(SIGNING_IDENTITY)" "$(APP)"; \
	fi
	codesign --verify --deep --strict "$(APP)"
	cd "$(DIST_DIR)" && ditto -c -k --sequesterRsrc --keepParent "$(APP_NAME).app" "$(notdir $(ZIP))"
	@echo "Built $(ZIP)"

clean-release:
	rm -rf "$(DIST_DIR)"
