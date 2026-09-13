#!/usr/bin/env python3
import gi
import os
import shutil
import subprocess
import threading

gi.require_version('Gtk', '3.0')
try:
    gi.require_version('AppIndicator3', '0.1')
    from gi.repository import AppIndicator3 as AppIndicator
except (ValueError, ImportError):
    gi.require_version('AyatanaAppIndicator3', '0.1')
    from gi.repository import AyatanaAppIndicator3 as AppIndicator

from gi.repository import Gtk, GLib

APP_ID = 'warp-tray'
HERE = os.path.dirname(os.path.abspath(__file__))
INSTALL_SCRIPT = os.path.join(HERE, 'scripts', 'install-warp-cli.sh')
UNINSTALL_SCRIPT = os.path.join(HERE, 'uninstall.sh')

ICON_CONNECTED = 'network-vpn'
ICON_DISCONNECTED = 'network-vpn-disabled'
ICON_MISSING = 'network-error'


def notify(title, body):
    if shutil.which('notify-send'):
        subprocess.Popen(['notify-send', title, body])
    else:
        print(f'{title}: {body}')


def warp_installed():
    return shutil.which('warp-cli') is not None


def run_bg(cmd, on_done=None):
    def worker():
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
            if on_done:
                GLib.idle_add(on_done, result.returncode, result.stdout, result.stderr)
        except Exception as e:
            if on_done:
                GLib.idle_add(on_done, 1, '', str(e))
    threading.Thread(target=worker, daemon=True).start()


class WarpTray:
    def __init__(self):
        self.indicator = AppIndicator.Indicator.new(
            APP_ID, ICON_MISSING, AppIndicator.IndicatorCategory.APPLICATION_STATUS
        )
        self.indicator.set_status(AppIndicator.IndicatorStatus.ACTIVE)
        self.menu = Gtk.Menu()
        self.build_menu()
        self.indicator.set_menu(self.menu)
        self.refresh_status()
        GLib.timeout_add_seconds(8, self.periodic_refresh)

    def build_menu(self):
        self.status_item = Gtk.MenuItem(label='Checking status...')
        self.status_item.set_sensitive(False)
        self.menu.append(self.status_item)
        self.menu.append(Gtk.SeparatorMenuItem())

        self.connect_item = Gtk.MenuItem(label='Connect')
        self.connect_item.connect('activate', lambda w: self.run_cli(['connect']))
        self.menu.append(self.connect_item)

        self.disconnect_item = Gtk.MenuItem(label='Disconnect')
        self.disconnect_item.connect('activate', lambda w: self.run_cli(['disconnect']))
        self.menu.append(self.disconnect_item)

        self.menu.append(Gtk.SeparatorMenuItem())

        self.doh_item = Gtk.MenuItem(label='Mode: DNS-Only (DoH)')
        self.doh_item.connect('activate', lambda w: self.run_cli(['mode', 'doh']))
        self.menu.append(self.doh_item)

        self.full_item = Gtk.MenuItem(label='Mode: Full VPN (WARP)')
        self.full_item.connect('activate', lambda w: self.run_cli(['mode', 'warp']))
        self.menu.append(self.full_item)

        self.menu.append(Gtk.SeparatorMenuItem())

        self.install_item = Gtk.MenuItem(label='Install Cloudflare WARP')
        self.install_item.connect('activate', lambda w: self.install_warp())
        self.menu.append(self.install_item)

        self.uninstall_item = Gtk.MenuItem(label='Uninstall WARP + This Tray App')
        self.uninstall_item.connect('activate', lambda w: self.confirm_uninstall())
        self.menu.append(self.uninstall_item)

        self.menu.append(Gtk.SeparatorMenuItem())

        refresh_item = Gtk.MenuItem(label='Refresh')
        refresh_item.connect('activate', lambda w: self.refresh_status())
        self.menu.append(refresh_item)

        quit_item = Gtk.MenuItem(label='Quit (keeps WARP running)')
        quit_item.connect('activate', lambda w: Gtk.main_quit())
        self.menu.append(quit_item)

        self.menu.show_all()

    def set_sensitivity(self, installed):
        self.install_item.set_visible(not installed)
        for item in (self.connect_item, self.disconnect_item, self.doh_item, self.full_item):
            item.set_sensitive(installed)

    def periodic_refresh(self):
        self.refresh_status()
        return True

    def refresh_status(self):
        installed = warp_installed()
        self.set_sensitivity(installed)

        if not installed:
            self.indicator.set_icon_full(ICON_MISSING, 'WARP not installed')
            self.status_item.set_label('WARP is not installed')
            return

        def done(code, out, err):
            connected = 'connected' in out.lower() and 'disconnected' not in out.lower()
            if connected:
                self.indicator.set_icon_full(ICON_CONNECTED, 'WARP connected')
                self.status_item.set_label('WARP: Connected')
            else:
                self.indicator.set_icon_full(ICON_DISCONNECTED, 'WARP disconnected')
                self.status_item.set_label('WARP: Disconnected')

        run_bg(['warp-cli', '--accept-tos', 'status'], done)

    def run_cli(self, args):
        def done(code, out, err):
            if code != 0:
                notify('WARP', f'Command failed: {err.strip() or out.strip()}')
            self.refresh_status()
        run_bg(['warp-cli', '--accept-tos'] + args, done)

    def install_warp(self):
        if not os.path.exists(INSTALL_SCRIPT):
            notify('WARP', 'install-warp-cli.sh not found next to this app.')
            return
        notify('WARP', 'Asking for permission to install...')

        def done(code, out, err):
            if code == 0:
                notify('WARP', 'Installed successfully.')
            else:
                notify('WARP', f'Install failed: {err.strip()[:200]}')
            self.refresh_status()

        run_bg(['pkexec', 'bash', INSTALL_SCRIPT], done)

    def confirm_uninstall(self):
        dialog = Gtk.MessageDialog(
            flags=0,
            message_type=Gtk.MessageType.WARNING,
            buttons=Gtk.ButtonsType.YES_NO,
            text='Remove Cloudflare WARP and this tray app completely?',
        )
        dialog.format_secondary_text('This removes the app, autostart entry, and the warp-cli package.')
        response = dialog.run()
        dialog.destroy()
        if response == Gtk.ResponseType.YES:
            self.run_uninstall()

    def run_uninstall(self):
        notify('WARP', 'Uninstalling...')

        def done(code, out, err):
            if code == 0:
                notify('WARP Tray', 'Uninstalled. Closing now.')
            else:
                notify('WARP Tray', f'Uninstall had issues: {err.strip()[:200]}')
            Gtk.main_quit()

        run_bg(['bash', UNINSTALL_SCRIPT], done)


def main():
    WarpTray()
    Gtk.main()


if __name__ == '__main__':
    main()
