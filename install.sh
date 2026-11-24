#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || pwd)"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Error: not31 requires macOS." >&2
    exit 1
fi

BIN_PATH=""
TMP_DIR=""
cleanup() {
    if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT

# 1. If a prebuilt binary is bundled alongside install.sh (e.g. from release archive), use it directly.
if [[ -x "$SCRIPT_DIR/not31" ]]; then
    BIN_PATH="$SCRIPT_DIR/not31"
elif [[ -d "$SCRIPT_DIR/Sources/not31" ]]; then
    # 2. Running from a local source checkout: compile with swiftc
    if ! command -v swiftc >/dev/null 2>&1; then
        echo "Error: swiftc not found. Install Xcode Command Line Tools ('xcode-select --install') or download the prebuilt universal release archive." >&2
        exit 1
    fi
    TMP_DIR="$(mktemp -d)"
    echo "Compiling not31..."
    swiftc -O \
        "$SCRIPT_DIR/Sources/not31/Glyphs.swift" \
        "$SCRIPT_DIR/Sources/not31/AppDetector.swift" \
        "$SCRIPT_DIR/Sources/not31/main.swift" \
        -o "$TMP_DIR/not31"
    codesign --force --sign - "$TMP_DIR/not31" >/dev/null 2>&1 || true
    BIN_PATH="$TMP_DIR/not31"
else
    # 3. Piped via curl | bash: download latest universal release or compile from main
    REPO="${NOT31_REPO:-vcdx71/not31}"
    TMP_DIR="$(mktemp -d)"
    echo "Downloading not31 from github.com/$REPO..."
    if curl -fsSL "https://github.com/$REPO/releases/latest/download/not31-macos-universal.tar.gz" -o "$TMP_DIR/release.tar.gz" 2>/dev/null; then
        tar -xzf "$TMP_DIR/release.tar.gz" -C "$TMP_DIR"
        BIN_PATH="$TMP_DIR/not31"
    else
        curl -fsSL "https://github.com/$REPO/archive/refs/heads/main.tar.gz" -o "$TMP_DIR/src.tar.gz"
        tar -xzf "$TMP_DIR/src.tar.gz" -C "$TMP_DIR" --strip-components=1
        swiftc -O \
            "$TMP_DIR/Sources/not31/Glyphs.swift" \
            "$TMP_DIR/Sources/not31/AppDetector.swift" \
            "$TMP_DIR/Sources/not31/main.swift" \
            -o "$TMP_DIR/not31"
        codesign --force --sign - "$TMP_DIR/not31" >/dev/null 2>&1 || true
        BIN_PATH="$TMP_DIR/not31"
    fi
fi

# Strip Gatekeeper quarantine xattr if downloaded from a browser
xattr -d com.apple.quarantine "$BIN_PATH" 2>/dev/null || true

"$BIN_PATH" install "$@"

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo ""
    echo "Note: Add ~/.local/bin to your PATH to run 'not31' from anywhere:"
    echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc"
fi
