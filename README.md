# cloudflare-warp (Linux)

System tray control for Cloudflare WARP on Linux. Works on any desktop with
a tray/panel — GNOME (Ubuntu ships this out of the box), KDE Plasma, XFCE,
Cinnamon, MATE. WARP has no official Linux GUI, so this fills that gap:
status icon, connect/disconnect, mode switch, and one-click install/uninstall.

## Setup (one time)

```bash
git clone https://github.com/ys-rathore/cloudflare-warp.git
cd cloudflare-warp
bash install.sh
```

That's it. The script installs whatever system packages are missing, drops
the app into `~/.local/share/cloudflare-warp`, sets it to autostart on login, and
launches it immediately. Everything after this is done by clicking the tray
icon — no more terminal.

Tray menu: Connect, Disconnect, mode switch (DoH / full VPN), Install
Cloudflare WARP (if missing), and Uninstall WARP + This Tray App (removes
everything cleanly, including the apt/dnf repo it added).

## If the icon doesn't show up

Most desktops show it immediately. On stock GNOME without Ubuntu's extras
(e.g. Fedora Workstation, Arch + vanilla GNOME), GNOME hides tray icons by
default — install the "AppIndicator and KStatusNotifierItem Support"
extension from extensions.gnome.org, then log out and back in.

## Uninstall later

Either click "Uninstall WARP + This Tray App" in the tray menu, or run:

```bash
bash ~/.local/share/cloudflare-warp/uninstall.sh
```


4. Scroll down, click **Commit changes**.
5. Done — anyone can now run the `git clone` command above as-is.
