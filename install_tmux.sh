#!/usr/bin/env bash
#
# install_tmux.sh
#
# Installs tmux on most major Linux distros (Debian/Ubuntu, Fedora/RHEL/CentOS,
# Arch/Manjaro, openSUSE, Alpine, Void, Gentoo) and installs a shared
# ~/.tmux.conf downloaded from GitHub.
#
# Usage:
#   ./install_tmux.sh
#
# Notes:
#   - Uses sudo for package installation if not run as root.
#   - Backs up any existing ~/.tmux.conf to ~/.tmux.conf.bak.<timestamp>
#   - Safe to re-run.

set -euo pipefail

CONF_URL="https://raw.githubusercontent.com/fadedreams/cfg/refs/heads/main/tmux.conf"
CONF_DEST="${HOME}/.tmux.conf"

log()  { printf '\033[1;32m[+] %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*"; }
err()  { printf '\033[1;31m[x] %s\033[0m\n' "$*" >&2; }

# ---- sudo helper -----------------------------------------------------------
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        err "Not running as root and 'sudo' is not available. Please run as root or install sudo."
        exit 1
    fi
fi

# ---- detect distro / package manager and install tmux ---------------------
install_tmux() {
    if command -v tmux >/dev/null 2>&1; then
        log "tmux is already installed ($(tmux -V)). Skipping install."
        return
    fi

    if command -v apt-get >/dev/null 2>&1; then
        # Debian, Ubuntu, Mint, Pop!_OS, etc.
        log "Detected apt (Debian/Ubuntu family). Installing tmux..."
        $SUDO apt-get update -y
        $SUDO apt-get install -y tmux

    elif command -v dnf >/dev/null 2>&1; then
        # Fedora, RHEL 8+, CentOS Stream, Rocky, Alma
        log "Detected dnf (Fedora/RHEL family). Installing tmux..."
        $SUDO dnf install -y tmux

    elif command -v yum >/dev/null 2>&1; then
        # Older RHEL/CentOS
        log "Detected yum (RHEL/CentOS legacy). Installing tmux..."
        $SUDO yum install -y tmux

    elif command -v pacman >/dev/null 2>&1; then
        # Arch, Manjaro, EndeavourOS
        log "Detected pacman (Arch/Manjaro family). Installing tmux..."
        $SUDO pacman -Sy --noconfirm --needed tmux

    elif command -v zypper >/dev/null 2>&1; then
        # openSUSE
        log "Detected zypper (openSUSE). Installing tmux..."
        $SUDO zypper --non-interactive install tmux

    elif command -v apk >/dev/null 2>&1; then
        # Alpine
        log "Detected apk (Alpine). Installing tmux..."
        $SUDO apk add --no-cache tmux

    elif command -v xbps-install >/dev/null 2>&1; then
        # Void Linux
        log "Detected xbps (Void Linux). Installing tmux..."
        $SUDO xbps-install -Sy tmux

    elif command -v emerge >/dev/null 2>&1; then
        # Gentoo
        log "Detected emerge (Gentoo). Installing tmux..."
        $SUDO emerge --ask=n app-misc/tmux || $SUDO emerge app-misc/tmux

    elif command -v eopkg >/dev/null 2>&1; then
        # Solus
        log "Detected eopkg (Solus). Installing tmux..."
        $SUDO eopkg install -y tmux

    elif command -v nix-env >/dev/null 2>&1; then
        # NixOS / Nix package manager fallback
        log "Detected nix-env (Nix/NixOS). Installing tmux..."
        nix-env -iA nixpkgs.tmux

    else
        err "Could not detect a supported package manager."
        err "Please install tmux manually for your distro, then re-run this script to set up the config."
        exit 1
    fi

    if command -v tmux >/dev/null 2>&1; then
        log "tmux installed successfully ($(tmux -V))."
    else
        err "tmux install command ran, but 'tmux' still isn't on PATH. Check output above for errors."
        exit 1
    fi
}

# ---- fetch config -----------------------------------------------------------
install_config() {
    log "Fetching tmux config from: ${CONF_URL}"

    local downloader=""
    if command -v curl >/dev/null 2>&1; then
        downloader="curl"
    elif command -v wget >/dev/null 2>&1; then
        downloader="wget"
    else
        warn "Neither curl nor wget found; attempting to install curl..."
        install_tmux_deps_curl
        downloader="curl"
    fi

    if [ -f "$CONF_DEST" ]; then
        local backup="${CONF_DEST}.bak.$(date +%Y%m%d%H%M%S)"
        warn "Existing ${CONF_DEST} found. Backing up to ${backup}"
        cp "$CONF_DEST" "$backup"
    fi

    local tmp
    tmp="$(mktemp)"

    if [ "$downloader" = "curl" ]; then
        curl -fsSL "$CONF_URL" -o "$tmp"
    else
        wget -q "$CONF_URL" -O "$tmp"
    fi

    mv "$tmp" "$CONF_DEST"
    log "tmux config installed to ${CONF_DEST}"
}

install_tmux_deps_curl() {
    if command -v apt-get >/dev/null 2>&1; then $SUDO apt-get update -y && $SUDO apt-get install -y curl
    elif command -v dnf >/dev/null 2>&1; then $SUDO dnf install -y curl
    elif command -v yum >/dev/null 2>&1; then $SUDO yum install -y curl
    elif command -v pacman >/dev/null 2>&1; then $SUDO pacman -Sy --noconfirm --needed curl
    elif command -v zypper >/dev/null 2>&1; then $SUDO zypper --non-interactive install curl
    elif command -v apk >/dev/null 2>&1; then $SUDO apk add --no-cache curl
    else
        err "Could not install curl automatically. Please install curl or wget manually."
        exit 1
    fi
}

main() {
    install_tmux
    install_config
    log "Done. Start tmux with: tmux"
}

main "$@"
