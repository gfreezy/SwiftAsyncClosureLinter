BINARY_NAME = async-closure-lint
BUILD_DIR = .build
DIST_DIR = dist

.PHONY: build build-release build-universal test clean install uninstall dist

# Debug build
build:
	swift build

# Release build (current architecture)
build-release:
	swift build -c release

# Build universal binary (arm64 + x86_64)
build-universal:
	swift build -c release --arch arm64
	swift build -c release --arch x86_64
	mkdir -p $(DIST_DIR)
	lipo -create \
		$(BUILD_DIR)/arm64-apple-macosx/release/$(BINARY_NAME) \
		$(BUILD_DIR)/x86_64-apple-macosx/release/$(BINARY_NAME) \
		-output $(DIST_DIR)/$(BINARY_NAME)
	chmod +x $(DIST_DIR)/$(BINARY_NAME)

# Run tests
test:
	swift test

# Clean build artifacts
clean:
	swift package clean
	rm -rf $(DIST_DIR)

# Install to /usr/local/bin
install: build-release
	mkdir -p /usr/local/bin
	cp $(BUILD_DIR)/release/$(BINARY_NAME) /usr/local/bin/$(BINARY_NAME)
	chmod +x /usr/local/bin/$(BINARY_NAME)

# Uninstall from /usr/local/bin
uninstall:
	rm -f /usr/local/bin/$(BINARY_NAME)

# Create distribution archive
dist: build-universal
	cd $(DIST_DIR) && tar -czvf $(BINARY_NAME)-macos.tar.gz $(BINARY_NAME)
	cd $(DIST_DIR) && shasum -a 256 $(BINARY_NAME)-macos.tar.gz > $(BINARY_NAME)-macos.tar.gz.sha256
	@echo "Distribution created in $(DIST_DIR)/"
