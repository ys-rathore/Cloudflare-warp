#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$HOME/.local/share/warp-tray"
AUTOSTART_DIR="$HOME/.config/autostart"
BIN_DIR="$HOME/.local/bin"
DESKTOP_FILE="$AUTOSTART_DIR/warp-tray.desktop"

log() { echo "[warp-tray] $*"; }
die() { echo "[warp-tray] ERROR: $*" >&2; exit 1; }

detect_pm() {
    if command -v apt-get >/dev/null 2>&1; then echo apt
    elif command -v dnf >/dev/null 2>&1; then echo dnf
    elif command -v yum >/dev/null 2>&1; then echo yum
    elif command -v pacman >/dev/null 2>&1; then echo pacman
    elif command -v zypper >/dev/null 2>&1; then echo zypper
    else echo none
    fi
}

need_elevate() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command -v pkexec >/dev/null 2>&1; then
        pkexec "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        die "Need root to install packages but neither pkexec nor sudo is available."
    fi
}

install_dependencies() {
    local pm
    pm="$(detect_pm)"
    log "Detected package manager: $pm"

    case "$pm" in
        apt)
            need_elevate bash -c "dpkg --configure -a; apt-get update"
            local appind_pkg="gir1.2-ayatanaappindicator3-0.1"
            apt-cache show "$appind_pkg" >/dev/null 2>&1 || appind_pkg="gir1.2-appindicator3-0.1"
            need_elevate apt-get install -y python3 python3-gi gir1.2-gtk-3.0 "$appind_pkg" libnotify-bin curl gnupg policykit-1 \
                || die "Dependency install failed. Try: sudo apt-get update && sudo apt-get -f install"
            ;;
        dnf|yum)
            need_elevate "$pm" install -y python3 python3-gobject gtk3 libappindicator-gtk3 libnotify curl gnupg2 polkit \
                || die "Dependency install failed."
            ;;
        pacman)
            need_elevate pacman -Sy --noconfirm python-gobject gtk3 libappindicator-gtk3 libnotify curl gnupg polkit \
                || die "Dependency install failed. libappindicator-gtk3 may need an AUR helper on some Arch setups."
            ;;
        zypper)
            need_elevate zypper install -y python3-gobject gtk3 libappindicator3-1 libnotify-tools curl gpg2 polkit \
                || die "Dependency install failed."
            ;;
        none)
            die "No supported package manager found (apt/dnf/yum/pacman/zypper). Install PyGObject + AppIndicator3 manually."
            ;;
    esac
}

check_tray_support() {
    python3 - <<'PYEOF'
import sys
try:
    import gi
    gi.require_version('Gtk', '3.0')
    try:
        gi.require_version('AppIndicator3', '0.1')
        from gi.repository import AppIndicator3
    except (ValueError, ImportError):
        gi.require_version('AyatanaAppIndicator3', '0.1')
        from gi.repository import AyatanaAppIndicator3
except Exception as e:
    print(f"MISSING:{e}")
    sys.exit(1)
PYEOF
}

deploy_files() {
    log "Copying app to $APP_DIR"
    mkdir -p "$APP_DIR" "$AUTOSTART_DIR" "$BIN_DIR"
    cp -f "$SRC_DIR/warp_tray.py" "$APP_DIR/"
    cp -rf "$SRC_DIR/scripts" "$APP_DIR/"
    cp -f "$SRC_DIR/uninstall.sh" "$APP_DIR/"
    chmod +x "$APP_DIR/scripts/install-warp-cli.sh" "$APP_DIR/uninstall.sh"

    cat > "$BIN_DIR/warp-tray" <<EOF
#!/usr/bin/env bash
exec python3 "$APP_DIR/warp_tray.py"
EOF
    chmod +x "$BIN_DIR/warp-tray"

    cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Cloudflare WARP Tray
Exec=python3 $APP_DIR/warp_tray.py
Icon=network-vpn
X-GNOME-Autostart-enabled=true
NoDisplay=false
Comment=System tray control for Cloudflare WARP
EOF
}

start_now() {
    if pgrep -f "warp_tray.py" >/dev/null 2>&1; then
        log "Tray already running, restarting it."
        pkill -f "warp_tray.py" || true
        sleep 1
    fi
    nohup python3 "$APP_DIR/warp_tray.py" >/tmp/warp-tray.log 2>&1 &
    disown
    sleep 1
    if pgrep -f "warp_tray.py" >/dev/null 2>&1; then
        log "Tray started. Look for the icon in your panel/tray."
    else
        log "Tray did not stay running. Check /tmp/warp-tray.log for details."
    fi
}

main() {
    [ -f "$SRC_DIR/warp_tray.py" ] || die "Run this from inside the cloned repo."

    if ! command -v python3 >/dev/null 2>&1 || [ "$(check_tray_support)" != "" ]; then
        install_dependencies
    fi

    check_result="$(check_tray_support || true)"
    if [ -n "$check_result" ]; then
        die "Tray libraries still missing after install: $check_result"
    fi

    deploy_files
    start_now

    echo
    echo "Setup complete. The WARP icon will now also auto-start on every login."
    echo "If you don't see an icon and you're on plain GNOME (no Ubuntu extras),"
    echo "install the 'AppIndicator and KStatusNotifierItem Support' extension"
    echo "from extensions.gnome.org, then log out and back in."
}

main "$@"
