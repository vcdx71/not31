VERSION := 1.0.0
APP_NAME := not31
SOURCES := Sources/not31/Glyphs.swift Sources/not31/AppDetector.swift Sources/not31/main.swift
BUILD_DIR := .build/universal
DIST_DIR := dist

.PHONY: all build universal install uninstall release pkg clean

all: universal

build:
	swift build -c release

universal: $(SOURCES)
	@mkdir -p $(BUILD_DIR)
	swiftc -O -target arm64-apple-macos13.0 $(SOURCES) -o $(BUILD_DIR)/$(APP_NAME)-arm64
	swiftc -O -target x86_64-apple-macos13.0 $(SOURCES) -o $(BUILD_DIR)/$(APP_NAME)-x86_64
	lipo -create -output $(BUILD_DIR)/$(APP_NAME) $(BUILD_DIR)/$(APP_NAME)-arm64 $(BUILD_DIR)/$(APP_NAME)-x86_64
	codesign --force --sign - $(BUILD_DIR)/$(APP_NAME)

install: universal
	$(BUILD_DIR)/$(APP_NAME) install

uninstall:
	./uninstall.sh

release: universal
	@mkdir -p $(DIST_DIR)/stage
	cp $(BUILD_DIR)/$(APP_NAME) $(DIST_DIR)/stage/$(APP_NAME)
	cp install.sh uninstall.sh README.md LICENSE $(DIST_DIR)/stage/
	chmod +x $(DIST_DIR)/stage/$(APP_NAME) $(DIST_DIR)/stage/install.sh $(DIST_DIR)/stage/uninstall.sh
	tar -czf $(DIST_DIR)/$(APP_NAME)-macos-universal.tar.gz -C $(DIST_DIR)/stage .
	@rm -rf $(DIST_DIR)/stage
	@echo "✓ Created $(DIST_DIR)/$(APP_NAME)-macos-universal.tar.gz"

pkg: universal
	@mkdir -p $(DIST_DIR)/pkgroot/usr/local/bin $(DIST_DIR)/pkgscripts
	cp $(BUILD_DIR)/$(APP_NAME) $(DIST_DIR)/pkgroot/usr/local/bin/$(APP_NAME)
	chmod 755 $(DIST_DIR)/pkgroot/usr/local/bin/$(APP_NAME)
	@printf '#!/bin/bash\nCONSOLE_USER=$$(stat -f "%%Su" /dev/console)\nCONSOLE_UID=$$(id -u "$$CONSOLE_USER" 2>/dev/null || echo "")\nif [[ -n "$$CONSOLE_USER" && "$$CONSOLE_USER" != "root" && -n "$$CONSOLE_UID" ]]; then\n  sudo -u "$$CONSOLE_USER" launchctl asuser "$$CONSOLE_UID" /usr/local/bin/not31 install || true\nfi\nexit 0\n' > $(DIST_DIR)/pkgscripts/postinstall
	chmod 755 $(DIST_DIR)/pkgscripts/postinstall
	pkgbuild \
		--root $(DIST_DIR)/pkgroot \
		--scripts $(DIST_DIR)/pkgscripts \
		--identifier io.github.vcdx71.not31.pkg \
		--version $(VERSION) \
		--install-location / \
		$(DIST_DIR)/not31-$(VERSION).pkg
	@rm -rf $(DIST_DIR)/pkgroot $(DIST_DIR)/pkgscripts
	@echo "✓ Created $(DIST_DIR)/not31-$(VERSION).pkg"

clean:
	rm -rf .build $(DIST_DIR)
