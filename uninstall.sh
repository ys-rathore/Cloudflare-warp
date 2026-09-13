#!/usr/bin/env bash
set -uo pipefail

APP_DIR="$HOME/.local/share/cloudflare-warp"
AUTOSTART_FILE="$HOME/.config/autostart/cloudflare-warp.desktop"
BIN_FILE="$HOME/.local/bin/cloudflare-warp"

log() { echo "[cloudflare-warp] $*"; }

need_elevate() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command -v pkexec >/dev/null 2>&1; then
        pkexec "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        echo "[cloudflare-warp] Can't remove system package: no pkexec/sudo found." >&2
        return 1
    fi
}

log "Stopping tray if running..."
pkill -f "cloudflare_warp.py" 2>/dev/null || true

log "Disconnecting WARP if connected..."
command -v warp-cli >/dev/null 2>&1 && warp-cli --accept-tos disconnect >/dev/null 2>&1 || true

if command -v warp-cli >/dev/null 2>&1; then
    log "Removing cloudflare-warp package..."
    if command -v apt-get >/dev/null 2>&1; then
        need_elevate apt-get remove -y cloudflare-warp
        need_elevate rm -f /etc/apt/sources.list.d/cloudflare-client.list
        need_elevate rm -f /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
    elif command -v dnf >/dev/null 2>&1; then
        need_elevate dnf remove -y cloudflare-warp
        need_elevate rm -f /etc/yum.repos.d/cloudflare-warp.repo
    elif command -v yum >/dev/null 2>&1; then
        need_elevate yum remove -y cloudflare-warp
        need_elevate rm -f /etc/yum.repos.d/cloudflare-warp.repo
    else
        log "Unknown package manager, remove cloudflare-warp manually if needed."
    fi
fi

log "Removing tray files..."
rm -f "$AUTOSTART_FILE" "$BIN_FILE"
rm -rf "$APP_DIR"

log "Done. Cloudflare WARP and the tray app are removed."
