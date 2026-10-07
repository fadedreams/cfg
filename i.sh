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
#   - Installs the CLI toolset used by the tmux/vim config: xclip, fzf, fd,
#     ripgrep and sesh (package manager first, GitHub release binary as fallback)
#   - Safe to re-run (idempotent)

set -euo pipefail

# Fully non-interactive apt installs (no debconf prompts, no confirmation)
export DEBIAN_FRONTEND=noninteractive

# ~/.local/bin holds the sesh binary. Make sure it's on PATH for the rest of
# this script's run, so `command -v` and verify() actually find it.
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

TMUX_CONF_URL="https://raw.githubusercontent.com/fadedreams/tmux/refs/heads/main/tmux.conf"
VIMRC_URL="https://raw.githubusercontent.com/fadedreams/vimrc/refs/heads/main/.vimrc"
BASHRC_URL="https://raw.githubusercontent.com/fadedreams/bashrc/refs/heads/main/bashrc"

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

# ---- package manager detection ------------------------------------------
PM=""
detect_pm() {
    local pm
    for pm in apt-get dnf yum pacman zypper apk xbps-install emerge eopkg nix-env brew; do
        if command -v "$pm" >/dev/null 2>&1; then
            PM="$pm"
            return 0
        fi
    done
    return 1
}

# Install one or more packages with the detected package manager.
# Returns non-zero on failure (does not exit), so callers can fall back.
_pm_install() { # _pm_install <pkg>...
    [ -n "$PM" ] || detect_pm || return 1
    case "$PM" in
        apt-get)      $SUDO apt-get install -y "$@" ;;
        dnf)          $SUDO dnf install -y "$@" ;;
        yum)          $SUDO yum install -y "$@" ;;
        pacman)       $SUDO pacman -S --noconfirm --needed "$@" ;;
        zypper)       $SUDO zypper --non-interactive install "$@" ;;
        apk)          $SUDO apk add --no-cache "$@" ;;
        xbps-install) $SUDO xbps-install -y "$@" ;;
        emerge)       $SUDO emerge --ask=n "$@" ;;
        eopkg)        $SUDO eopkg install -y "$@" ;;
        nix-env)      nix-env -iA $(printf 'nixpkgs.%s ' "$@") ;;
        brew)         brew install "$@" ;;
        *)            return 1 ;;
    esac
}

# Same, but aborts the script on failure (used for essentials like git/tmux/vim)
install_pkg() { # install_pkg <pkg-name>
    if ! _pm_install "$@"; then
        err "Could not install '$*' (package manager: ${PM:-none detected})."
        exit 1
    fi
}

# Map a tool name to the package name used by the current package manager.
tool_pkg() { # tool_pkg <xclip|fd|fzf|rg>
    case "$1:$PM" in
        xclip:emerge)        echo "x11-misc/xclip" ;;
        fd:apt-get)          echo "fd-find" ;;
        fd:dnf|fd:yum)       echo "fd-find" ;;
        fd:emerge)           echo "sys-apps/fd" ;;
        fzf:emerge)          echo "app-shells/fzf" ;;
        rg:emerge)           echo "sys-apps/ripgrep" ;;
        rg:*)                echo "ripgrep" ;;
        *)                   echo "$1" ;;
    esac
}

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

restore_latest_backup() { # restore_latest_backup <path>
    local latest
    latest="$(ls -1t "${1}".bak.* 2>/dev/null | head -n1 || true)"
    if [ -n "$latest" ] && [ ! -f "$1" ]; then
        cp "$latest" "$1"
    fi
    return 0
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

# Download a dotfile to a temp file first; only replace the real one (after a
# backup) if the download succeeded. A 404 warns instead of aborting the script.
install_dotfile() { # install_dotfile <url> <dest>
    local url="$1" dest="$2" tmp
    tmp="$(mktemp)"
    if fetch "$url" "$tmp"; then
        backup_if_exists "$dest"
        mv "$tmp" "$dest"
        log "Installed ${dest}"
    else
        rm -f "$tmp"
        warn "Could not download $url; leaving ${dest} untouched"
    fi
}

# ---- dotfile installers -------------------------------------------------
install_tmux_conf() {
    install_dotfile "${TMUX_CONF_URL}" "${HOME}/.tmux.conf"
}

#── tmux plugins (TPM) ───────────────────────────────────────────
TPM_DIR="${HOME}/.tmux/plugins/tpm"
install_tpm() {
    if [ -d "$TPM_DIR" ]; then
        log "TPM already installed, updating..."
        git -C "$TPM_DIR" pull --ff-only >/dev/null 2>&1 || warn "Could not update TPM (non-fatal)"
    else
        log "Installing TPM (tmux plugin manager)..."
        git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
    fi
}
install_tmux_plugins() {
    install_tpm

    # TPM ships a headless installer script that doesn't need a running
    # tmux session or the prefix+I keypress — perfect for a bootstrap script.
    if [ -x "${TPM_DIR}/bin/install_plugins" ]; then
        log "Installing tmux plugins listed in ~/.tmux.conf..."
        "${TPM_DIR}/bin/install_plugins" || warn "Some tmux plugins may have failed to install"
    else
        err "TPM install script not found at ${TPM_DIR}/bin/install_plugins"
    fi
}

install_vimrc() {
    install_dotfile "${VIMRC_URL}" "${HOME}/.vimrc"
}

install_bashrc() {
    install_dotfile "${BASHRC_URL}" "${HOME}/.bashrc"
}


#── FZF & Friends ────────────────────────────────────────────────
#
# Strategy for xclip, fd, fzf, ripgrep (each handled independently so one
# missing package never blocks the others):
#   1. Install from the distro's package manager (apt, dnf, yum, pacman,
#      zypper, apk, xbps, emerge, eopkg, nix, brew)
#   2. Fix up Debian/Ubuntu's `fdfind` -> `fd` naming
#   3. For anything still missing (old/minimal distros, RHEL without EPEL,
#      unknown package managers), download the official GitHub release binary

# Prints the latest release version of a GitHub repo (without a leading "v"),
# or the given fallback version if the API is unreachable / rate-limited.
github_latest() { # github_latest <owner/repo> <fallback>
    local v="" tmp
    tmp="$(mktemp)"
    if fetch "https://api.github.com/repos/$1/releases/latest" "$tmp" 2>/dev/null; then
        v="$(grep -m1 '"tag_name"' "$tmp" | sed -E 's/.*"v?([^"]+)".*/\1/' || true)"
    fi
    rm -f "$tmp"
    echo "${v:-$2}"
}

# Download a .tar.gz, find <bin> inside it, and install to /usr/local/bin
install_release_binary() { # install_release_binary <bin> <url>
    local bin="$1" url="$2" tmp found
    tmp="$(mktemp -d)"
    log "Downloading $url"
    if fetch "$url" "$tmp/a.tar.gz" && tar -xzf "$tmp/a.tar.gz" -C "$tmp"; then
        found="$(find "$tmp" -type f -name "$bin" | head -n1)"
        if [ -n "$found" ]; then
            $SUDO mkdir -p /usr/local/bin
            $SUDO install -m 0755 "$found" "/usr/local/bin/$bin"
            rm -rf "$tmp"
            log "$bin installed to /usr/local/bin/$bin"
            return 0
        fi
    fi
    rm -rf "$tmp"
    return 1
}

# Fallback installers: GitHub release binaries (Linux x86_64 / arm64)
install_fallback_binary() { # install_fallback_binary <fzf|rg|fd>
    local tool="$1" arch_gnu arch_go libc v
    case "$(uname -m)" in
        x86_64|amd64)  arch_gnu="x86_64";  arch_go="amd64"; libc="musl" ;;
        aarch64|arm64) arch_gnu="aarch64"; arch_go="arm64"; libc="gnu"  ;;
        *) warn "No prebuilt $tool binary for architecture $(uname -m)"; return 1 ;;
    esac

    case "$tool" in
        fzf)
            v="$(github_latest junegunn/fzf 0.60.3)"
            install_release_binary fzf "https://github.com/junegunn/fzf/releases/download/v${v}/fzf-${v}-linux_${arch_go}.tar.gz"
            ;;
        rg)
            v="$(github_latest BurntSushi/ripgrep 14.1.1)"
            install_release_binary rg "https://github.com/BurntSushi/ripgrep/releases/download/${v}/ripgrep-${v}-${arch_gnu}-unknown-linux-${libc}.tar.gz"
            ;;
        fd)
            v="$(github_latest sharkdp/fd 10.2.0)"
            install_release_binary fd "https://github.com/sharkdp/fd/releases/download/v${v}/fd-v${v}-${arch_gnu}-unknown-linux-${libc}.tar.gz"
            ;;
        *) return 1 ;;
    esac
}

install_cli_tools() {
    log "Installing xclip, fd, fzf, ripgrep..."
    [ -n "$PM" ] || detect_pm || warn "No supported package manager detected; will use GitHub release binaries where possible"

    # --- 1. package manager -------------------------------------------
    if [ -n "$PM" ]; then
        case "$PM" in
            apt-get)
                $SUDO apt-get update -y >/dev/null 2>&1 || warn "apt-get update failed (continuing)"
                ;;
            dnf|yum)
                # RHEL/CentOS/Alma/Rocky ship fzf/ripgrep/fd in EPEL; harmless no-op elsewhere
                $SUDO "$PM" install -y epel-release >/dev/null 2>&1 || true
                ;;
        esac

        local tool pkg
        for tool in xclip fd fzf rg; do
            command -v "$tool" >/dev/null 2>&1 && continue
            pkg="$(tool_pkg "$tool")"
            _pm_install "$pkg" || warn "Package '$pkg' not available via $PM (will try fallback)"
        done
    fi

    # --- 2. Debian/Ubuntu install fd as 'fdfind' -----------------------
    if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
        $SUDO mkdir -p /usr/local/bin
        $SUDO ln -sf "$(command -v fdfind)" /usr/local/bin/fd
        log "Linked fdfind -> /usr/local/bin/fd"
    fi

    # --- 3. fallback: official release binaries ------------------------
    local t
    for t in fzf rg fd; do
        if ! command -v "$t" >/dev/null 2>&1; then
            warn "$t still missing; trying GitHub release binary..."
            install_fallback_binary "$t" || warn "Could not install $t automatically"
        fi
    done

    # xclip only exists as a package (needs X11); not fatal on headless boxes
    if ! command -v xclip >/dev/null 2>&1; then
        warn "xclip not installed (headless/Wayland systems may not need it; Wayland users: install wl-clipboard)"
    fi

    log "CLI tools step finished."
}

#── sesh ─────────────────────────────────────────────────────────

install_sesh() {
    if command -v sesh >/dev/null 2>&1; then
        log "sesh already installed"
        return
    fi
    install_sesh_binary
}

install_sesh_binary() {
    local os arch url tmpdir asset
    case "$(uname -s)" in
        Darwin) os="Darwin" ;;
        Linux)  os="Linux" ;;
        *) err "Unsupported OS for sesh binary install: $(uname -s)"; return 1 ;;
    esac
    case "$(uname -m)" in
        x86_64|amd64)  arch="x86_64" ;;
        aarch64|arm64) arch="arm64" ;;
        *) err "Unsupported architecture for sesh binary install: $(uname -m)"; return 1 ;;
    esac

    tmpdir="$(mktemp -d)"
    asset="sesh_${os}_${arch}.tar.gz"
    url="https://github.com/joshmedeski/sesh/releases/latest/download/${asset}"
    log "Downloading $url"
    if fetch "$url" "$tmpdir/sesh.tar.gz"; then
        tar -xzf "$tmpdir/sesh.tar.gz" -C "$tmpdir"
        mkdir -p "$HOME/.local/bin"
        mv "$tmpdir/sesh" "$HOME/.local/bin/sesh"
        chmod +x "$HOME/.local/bin/sesh"
        log "sesh installed to \$HOME/.local/bin/sesh"
    else
        err "Could not download sesh binary automatically."
        err "Grab it manually from https://github.com/joshmedeski/sesh/releases"
    fi
    rm -rf "$tmpdir"
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

#── default editor ────────────────────────────────────────────────
set_default_editor() {
    if command -v update-alternatives >/dev/null 2>&1; then
        # Debian/Ubuntu: package may register vim as vim.basic, vim.tiny, or plain vim
        local vim_alt
        vim_alt="$(update-alternatives --list editor 2>/dev/null | grep -E '/vim(\.basic|\.tiny)?$' | head -n1)"
        if [ -n "$vim_alt" ]; then
            $SUDO update-alternatives --set editor "$vim_alt"
            log "Set default editor to $vim_alt (update-alternatives)"
        else
            warn "No vim alternative registered for 'editor'; skipping update-alternatives"
        fi
    elif command -v alternatives >/dev/null 2>&1; then
        # RHEL/Fedora/CentOS use 'alternatives' instead of 'update-alternatives'
        local vim_bin
        vim_bin="$(command -v vim || true)"
        if [ -n "$vim_bin" ] && alternatives --list 2>/dev/null | grep -q '^editor'; then
            $SUDO alternatives --set editor "$vim_bin"
            log "Set default editor to $vim_bin (alternatives)"
        else
            warn "No 'editor' alternative found via alternatives; skipping"
        fi
    else
        # Arch, Alpine, and others have no alternatives system for 'editor'
        warn "No alternatives system found for this distro; not setting a system-wide editor"
        warn "Relying on EDITOR/VISUAL in ~/.bashrc instead"
    fi
}

#── vim colorscheme ─────────────────────────────────────────────
install_habamax_colorscheme() {
    local dest="${HOME}/.vim/colors/habamax.vim"
    if [ -f "$dest" ]; then
        log "habamax colorscheme already installed"
        return
    fi
    mkdir -p "${HOME}/.vim/colors"
    if fetch "https://raw.githubusercontent.com/vim/colorschemes/master/colors/habamax.vim" "$dest"; then
        log "Installed ${dest}"
    else
        rm -f "$dest"
        warn "Could not download habamax colorscheme (non-fatal)"
    fi
}

#── verification ───────────────────────────────────────────────────

verify() {
    echo
    log "Verification:"
    for bin in tmux vim xclip fzf fd rg sesh; do
        if command -v "$bin" >/dev/null 2>&1; then
            printf '  \033[1;32m✓\033[0m %-8s %s\n' "$bin" "$(command -v "$bin")"
        else
            printf '  \033[1;31m✗\033[0m %-8s not found\n' "$bin"
        fi
    done
    if [ -f "${HOME}/.vim/colors/habamax.vim" ]; then
        printf '  \033[1;32m✓\033[0m %-8s %s\n' "habamax" "${HOME}/.vim/colors/habamax.vim"
    else
        printf '  \033[1;31m✗\033[0m %-8s not found\n' "habamax"
    fi
    echo
    warn "If any binaries show as 'not found' but were just installed, restart your shell or run: source ~/.bashrc"
    warn "\$HOME/.local/bin (sesh) and /usr/local/bin (fd, fzf, rg fallbacks) must be on your PATH."
    warn "Remember: the tmux config uses xclip. If you're on Wayland, swap the copy-mode-vi 'y' binding to use wl-copy instead."
}

main() {
    detect_pm || warn "No known package manager detected; only binary downloads will be attempted"
    pick_downloader

    ensure_installed git git
    ensure_installed tmux tmux
    ensure_installed vim vim

    install_cli_tools

    install_tmux_conf
    install_tmux_plugins
    install_vimrc
    install_habamax_colorscheme
    install_bashrc

    install_sesh
    install_nano_shim
    set_default_editor

    verify

    log "Done."
    log "Start a new shell (or run: exec bash) and 'tmux' to pick everything up."
}
main "$@"
