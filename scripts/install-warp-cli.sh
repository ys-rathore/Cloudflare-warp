#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "This script needs root. It should be run via pkexec/sudo." >&2
    exit 1
fi

if command -v warp-cli >/dev/null 2>&1; then
    echo "warp-cli already installed, skipping."
    exit 0
fi

install_apt() {
    local keyring=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
    local list=/etc/apt/sources.list.d/cloudflare-client.list
    local codename
    codename="$(. /etc/os-release && echo "${VERSION_CODENAME:-}")"
    [ -z "$codename" ] && codename="$(lsb_release -cs 2>/dev/null || echo jammy)"

    command -v curl >/dev/null 2>&1 || apt-get install -y curl
    command -v gpg >/dev/null 2>&1 || apt-get install -y gnupg

    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output "$keyring"
    echo "deb [signed-by=$keyring] https://pkg.cloudflareclient.com/ ${codename} main" > "$list"

    dpkg --configure -a || true
    apt-get update
    apt-get install -y cloudflare-warp
}

install_dnf() {
    local pm=dnf
    command -v dnf >/dev/null 2>&1 || pm=yum
    curl -fsSL https://pkg.cloudflareclient.com/cloudflare-warp-ascii.repo -o /etc/yum.repos.d/cloudflare-warp.repo
    rpm --import https://pkg.cloudflareclient.com/pubkey.gpg || true
    "$pm" install -y cloudflare-warp
}

if command -v apt-get >/dev/null 2>&1; then
    install_apt
elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
    install_dnf
else
    echo "Unsupported package manager. Install cloudflare-warp manually from pkg.cloudflareclient.com" >&2
    exit 2
fi

command -v warp-cli >/dev/null 2>&1 || { echo "Install finished but warp-cli still not found." >&2; exit 3; }
systemctl enable --now warp-svc >/dev/null 2>&1 || true
echo "warp-cli installed."
