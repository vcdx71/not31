#!/usr/bin/env bash
set -euo pipefail

if [[ -x "$HOME/.local/bin/not31" ]]; then
    "$HOME/.local/bin/not31" uninstall
elif command -v not31 >/dev/null 2>&1; then
    not31 uninstall
else
    UID_NUM="$(id -u)"
    launchctl bootout "gui/$UID_NUM/io.github.vcdx71.not31" 2>/dev/null || true
    rm -f "$HOME/Library/LaunchAgents/io.github.vcdx71.not31.plist"
    rm -rf "$HOME/.local/share/not31"
    echo "✓ Cleaned up LaunchAgent and state directory."
fi
