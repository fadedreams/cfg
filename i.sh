#!/usr/bin/env bash
#
# install.sh — bootstrap tmux, vim, and shell configs on (almost) any Linux box
#
# Usage (one-liner, on any fresh server):
#   curl -fsSL https://raw.githubusercontent.com/fadedreams/cfg/refs/heads/main/install.sh | bash
# or:
#   wget -qO- https://raw.githubusercontent.com/fadedreams/cfg/refs/heads/main/install.sh | bash
#
# What it does:
#   - Installs tmux and vim via the right package manager for your distro
#   - Downloads .tmux.conf, .vimrc, .bashrc from their respective repos
#   - Backs up any existing dotfiles to <file>.bak.<timestamp>
#   - Safe to re-run (idempotent)

set -euo pipefail

# Fully non-interactive apt installs (no debconf prompts, no confirmation)
export DEBIAN_FRONTEND=noninteractive

TMUX_CONF_URL="https://raw.githubusercontent.com/fadedreams/tmux/refs/heads/main/tmux.conf"
VIMRC_URL="https://raw.githubusercontent.com/fadedreams/vimrc/refs/heads/main/.vimrc"
BASHRC_URL="https://raw.githubusercontent.com/fadedreams/bashrc/refs/heads/main/.bashrc"

log()  { printf '\033[1;32m[+] %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*"; }
err()  { printf '\033[1;31m[x] %s\033[0m\n' "$*" >&2; }

# ---- sudo helper ------------------------------------------------------
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        err "Not running as root and 'sudo' is not available. Please run as root or install sudo."
        exit 1
    fi
fi

# ---- downloader helper -------------------------------------------------
DOWNLOADER=""
pick_downloader() {
    if command -v curl >/dev/null 2>&1; then
        DOWNLOADER="curl"
    elif command -v wget >/dev/null 2>&1; then
        DOWNLOADER="wget"
    else
        warn "Neither curl nor wget found; attempting to install curl..."
        install_pkg curl
        DOWNLOADER="curl"
    fi
}

fetch() { # fetch <url> <dest>
    if [ "$DOWNLOADER" = "curl" ]; then
        curl -fsSL "$1" -o "$2"
    else
        wget -q "$1" -O "$2"
    fi
}

backup_if_exists() { # backup_if_exists <path>
    if [ -f "$1" ]; then
        local b="${1}.bak.$(date +%Y%m%d%H%M%S)"
        warn "Existing $1 found. Backing up to $b"
        cp "$1" "$b"
    fi
}

# ---- generic package install across distros ----------------------------
install_pkg() { # install_pkg <pkg-name>
    local pkg="$1"
    if command -v apt-get >/dev/null 2>&1; then
        $SUDO apt-get install -y "$pkg"
    elif command -v dnf >/dev/null 2>&1; then
        $SUDO dnf install -y "$pkg"
    elif command -v yum >/dev/null 2>&1; then
        $SUDO yum install -y "$pkg"
    elif command -v pacman >/dev/null 2>&1; then
        $SUDO pacman -S --noconfirm --needed "$pkg"
    elif command -v zypper >/dev/null 2>&1; then
        $SUDO zypper --non-interactive install "$pkg"
    elif command -v apk >/dev/null 2>&1; then
        $SUDO apk add --no-cache "$pkg"
    elif command -v xbps-install >/dev/null 2>&1; then
        $SUDO xbps-install -y "$pkg"
    elif command -v emerge >/dev/null 2>&1; then
        $SUDO emerge --ask=n "$pkg" || $SUDO emerge "$pkg"
    elif command -v eopkg >/dev/null 2>&1; then
        $SUDO eopkg install -y "$pkg"
    elif command -v nix-env >/dev/null 2>&1; then
        nix-env -iA "nixpkgs.${pkg}"
    else
        err "Could not detect a supported package manager for '$pkg'."
        exit 1
    fi
}

ensure_installed() { # ensure_installed <bin> <pkg>
    local bin="$1" pkg="$2"
    if command -v "$bin" >/dev/null 2>&1; then
        log "$bin already installed ($($bin --version 2>&1 | head -n1))."
    else
        log "Installing $pkg..."
        install_pkg "$pkg"
        if command -v "$bin" >/dev/null 2>&1; then
            log "$pkg installed successfully."
        else
            err "$pkg install ran, but '$bin' still isn't on PATH."
            exit 1
        fi
    fi
}

# ---- dotfile installers -------------------------------------------------
install_tmux_conf() {
    local dest="${HOME}/.tmux.conf"
    backup_if_exists "$dest"
    fetch "${TMUX_CONF_URL}" "$dest"
    log "Installed ${dest}"
}

install_vimrc() {
    local dest="${HOME}/.vimrc"
    backup_if_exists "$dest"
    fetch "${VIMRC_URL}" "$dest"
    log "Installed ${dest}"
}

install_bashrc() {
    local dest="${HOME}/.bashrc"
    backup_if_exists "$dest"
    fetch "${BASHRC_URL}" "$dest"
    log "Installed ${dest}"
}


#── FZF & Friends ────────────────────────────────────────────────

# Cross-distro installer for fd, fzf, ripgrep
install_fzf_tools() {
    echo "=== Installing fd, fzf, ripgrep, eza ==="
    if command -v apt &>/dev/null; then
        sudo apt install -y fd-find fzf ripgrep eza
        # Debian/Ubuntu ship these under different binary names
        mkdir -p ~/.local/bin
        [ -x /usr/bin/fdfind ] && [ ! -e ~/.local/bin/fd ] && ln -s "$(command -v fdfind)" ~/.local/bin/fd
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y fd-find fzf ripgrep eza
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --needed --noconfirm fd fzf ripgrep eza
    elif command -v apk &>/dev/null; then
        sudo apk add fd fzf ripgrep eza
    elif command -v brew &>/dev/null; then
        brew install fd fzf ripgrep eza
    else
        echo "✗ No supported package manager found (apt/dnf/pacman/apk/brew)"
        echo "  Falling back to fzf git install..."
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
        ~/.fzf/install --all
        return
    fi
    echo "✓ Done. Restart your shell or run 'reload'."
}

#── nano shim ────────────────────────────────────────────────────

# Replace 'nano' with a thin wrapper that just execs vi
install_nano_shim() {
    log "Installing /usr/local/bin/nano shim (exec vi)..."
    $SUDO bash -c 'cat << '"'"'EOF'"'"' > /usr/local/bin/nano
#!/bin/bash
exec vi "$@"
EOF
chmod +x /usr/local/bin/nano'
    log "Installed /usr/local/bin/nano -> vi"
}

main() {
    pick_downloader

    ensure_installed tmux tmux
    ensure_installed vim vim

    install_tmux_conf
    install_vimrc
    install_bashrc

    install_fzf_tools
    install_nano_shim

    log "Done."
    log "Start a new shell (or run: exec bash) and 'tmux' to pick everything up."
}

main "$@"
