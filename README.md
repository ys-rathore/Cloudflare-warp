# Cloudflare WARP Tray

System tray control for Cloudflare WARP on Linux. Works on any desktop with
a tray/panel — GNOME (Ubuntu ships this out of the box), KDE Plasma, XFCE,
Cinnamon, MATE. WARP has no official Linux GUI, so this fills that gap:
status icon, connect/disconnect, mode switch, and one-click install/uninstall.

## Setup (one time)

```bash
git clone https://github.com/YOUR_USERNAME/warp-tray.git
cd warp-tray
bash install.sh
```

That's it. The script installs whatever system packages are missing, drops
the app into `~/.local/share/warp-tray`, sets it to autostart on login, and
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
bash ~/.local/share/warp-tray/uninstall.sh
```

---

## Uploading this to GitHub (dashboard, no terminal)

1. On GitHub, click **New repository**, name it e.g. `warp-tray`, keep it
   Public, don't add a README (you already have one) → **Create repository**.
2. On the empty repo page, click **uploading an existing file**.
3. Drag in these files/folders exactly as they are:
   - `install.sh`
   - `uninstall.sh`
   - `warp_tray.py`
   - `scripts/install-warp-cli.sh` (GitHub keeps the `scripts` folder
     automatically if you drag the folder itself, or drag the file and
     type `scripts/install-warp-cli.sh` as its path in the upload box)
   - `README.md`
   - `LICENSE`
4. Scroll down, click **Commit changes**.
5. Done — anyone can now run the `git clone ... && bash install.sh` command
   above using your repo's URL.

One thing to fix after upload: edit `README.md` on GitHub (pencil icon) and
replace `YOUR_USERNAME` with your actual GitHub username in the clone URL.
