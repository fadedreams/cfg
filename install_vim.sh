#!/usr/bin/env bash
#
# install_vim.sh
# Installs vim on common Linux distributions and downloads a .vimrc
# from a remote URL into ~/.vimrc
#
# Usage: ./install_vim.sh
#        (run with sudo privileges available, or as root)

set -euo pipefail

VIMRC_URL="https://raw.githubusercontent.com/fadedreams/cfg/refs/heads/main/.vimrc"
VIMRC_DEST="${HOME}/.vimrc"

log()  { printf '\033[1;32m[+]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$1"; }
err()  { printf '\033[1;31m[x]\033[0m %s\n' "$1" >&2; }

# --- Determine if we need sudo ---
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        err "This script needs root privileges (sudo not found). Run as root."
        exit 1
    fi
fi

# --- Detect distro ---
detect_distro() {
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        echo "${ID_LIKE:-$ID}" "${ID}"
    else
        echo "unknown unknown"
    fi
}

read -r ID_LIKE ID <<< "$(detect_distro)"
DISTRO_STRING="${ID_LIKE} ${ID}"
log "Detected distro info: ID=${ID}, ID_LIKE=${ID_LIKE}"

install_vim() {
    case "$DISTRO_STRING" in
        *debian*|*ubuntu*)
            log "Installing vim via apt (Debian/Ubuntu family)..."
            $SUDO apt-get update -y
            $SUDO apt-get install -y vim
            ;;
        *fedora*|*rhel*|*centos*)
            if command -v dnf >/dev/null 2>&1; then
                log "Installing vim via dnf (Fedora/RHEL family)..."
                $SUDO dnf install -y vim
            else
                log "Installing vim via yum (older RHEL/CentOS)..."
                $SUDO yum install -y vim
            fi
            ;;
        *arch*|*manjaro*)
            log "Installing vim via pacman (Arch/Manjaro family)..."
            $SUDO pacman -Sy --noconfirm vim
            ;;
        *opensuse*|*suse*)
            log "Installing vim via zypper (openSUSE family)..."
            $SUDO zypper --non-interactive install vim
            ;;
        *alpine*)
            log "Installing vim via apk (Alpine)..."
            $SUDO apk add vim
            ;;
        *void*)
            log "Installing vim via xbps (Void Linux)..."
            $SUDO xbps-install -Sy vim
            ;;
        *gentoo*)
            log "Installing vim via emerge (Gentoo)..."
            $SUDO emerge --ask=n app-editors/vim
            ;;
        *)
            warn "Unrecognized distro (ID=${ID}, ID_LIKE=${ID_LIKE})."
            if command -v apt-get >/dev/null 2>&1; then
                log "Falling back to apt-get..."
                $SUDO apt-get update -y && $SUDO apt-get install -y vim
            elif command -v dnf >/dev/null 2>&1; then
                log "Falling back to dnf..."
                $SUDO dnf install -y vim
            elif command -v pacman >/dev/null 2>&1; then
                log "Falling back to pacman..."
                $SUDO pacman -Sy --noconfirm vim
            elif command -v zypper >/dev/null 2>&1; then
                log "Falling back to zypper..."
                $SUDO zypper --non-interactive install vim
            elif command -v apk >/dev/null 2>&1; then
                log "Falling back to apk..."
                $SUDO apk add vim
            else
                err "No known package manager found. Please install vim manually."
                exit 1
            fi
            ;;
    esac
}

download_vimrc() {
    log "Downloading .vimrc from ${VIMRC_URL} ..."

    if [ -f "$VIMRC_DEST" ]; then
        BACKUP="${VIMRC_DEST}.bak.$(date +%Y%m%d%H%M%S)"
        warn "Existing ~/.vimrc found, backing it up to ${BACKUP}"
        cp "$VIMRC_DEST" "$BACKUP"
    fi

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$VIMRC_URL" -o "$VIMRC_DEST"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$VIMRC_DEST" "$VIMRC_URL"
    else
        err "Neither curl nor wget is available to download .vimrc."
        exit 1
    fi

    log "Saved .vimrc to ${VIMRC_DEST}"
}

main() {
    install_vim

    if command -v vim >/dev/null 2>&1; then
        log "vim installed: $(vim --version | head -n1)"
    else
        err "vim installation appears to have failed."
        exit 1
    fi

    download_vimrc
    log "Done! Open a new shell or run 'vim' to use the new config."
}

main "$@"
