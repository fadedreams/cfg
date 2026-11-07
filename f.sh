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
#   - Installs tmux and vim with the right package manager
#     (apt, dnf, yum, pacman, zypper, apk). No index refresh, no upgrades.
#   - Installs a /usr/local/bin/nano wrapper so typing `nano` launches vi
#     (the real nano package is left installed, just shadowed)
#   - Downloads .tmux.conf, .vimrc, .bashrc from their respective repos
#   - Backs up any existing dotfiles to <file>.bak.<timestamp>
#   - Installs the CLI toolset used by the tmux/vim config: xclip, fzf, fd,
#     ripgrep, sesh and starship (package manager first, GitHub release
#     binary as fallback), then wires starship into ~/.bashrc
#   - Safe to re-run (idempotent)

set -euo pipefail

# Fully non-interactive apt installs (no debconf prompts, no confirmation)
export DEBIAN_FRONTEND=noninteractive

# ~/.local/bin holds fallback binaries (sesh, etc). Make sure it's on PATH for
# the rest of this script's run, so `command -v` and verify() actually find it.
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

TMUX_CONF_URL="https://raw.githubusercontent.com/fadedreams/tmux/refs/heads/main/tmux.conf"
VIMRC_URL="https://raw.githubusercontent.com/fadedreams/vimrc/refs/heads/main/.vimrc"
BASHRC_URL="https://raw.githubusercontent.com/fadedreams/bashrc/refs/heads/main/.bashrc"

TS="$(date +%Y%m%d-%H%M%S)"

log()  { printf '\033[1;32m[+] %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*"; }
err()  { printf '\033[1;31m[x] %s\033[0m\n' "$*" >&2; }

have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
# Privileges
# ---------------------------------------------------------------------------
if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
elif have sudo; then
  SUDO="sudo"
else
  SUDO=""
  warn "Not root and sudo not found; package installs will likely fail."
fi

# ---------------------------------------------------------------------------
# Package manager detection
# ---------------------------------------------------------------------------
PM=""
if   have apt-get; then PM="apt"
elif have dnf;     then PM="dnf"
elif have yum;     then PM="yum"
elif have pacman;  then PM="pacman"
elif have zypper;  then PM="zypper"
elif have apk;     then PM="apk"
else
  warn "No supported package manager found; will only use binary fallbacks."
fi

pkg_install() {
  case "$PM" in
    apt)    $SUDO apt-get install -y --no-install-recommends "$@" </dev/null ;;
    dnf)    $SUDO dnf install -y "$@" </dev/null ;;
    yum)    $SUDO yum install -y "$@" </dev/null ;;
    pacman) $SUDO pacman -S --noconfirm --needed "$@" </dev/null ;;
    zypper) $SUDO zypper --non-interactive install "$@" </dev/null ;;
    apk)    $SUDO apk add "$@" </dev/null ;;
    *)      return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Downloader
# ---------------------------------------------------------------------------
fetch() {  # fetch <url> <dest>
  local url="$1" dest="$2"
  if have curl; then
    curl -fsSL "$url" -o "$dest"
  elif have wget; then
    wget -qO "$dest" "$url"
  else
    err "Neither curl nor wget is available."
    return 1
  fi
}

fetch_stdout() {  # fetch_stdout <url>
  if have curl; then
    curl -fsSL "$1"
  elif have wget; then
    wget -qO- "$1"
  else
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Architecture
# ---------------------------------------------------------------------------
case "$(uname -m)" in
  x86_64|amd64)   ARCH_GO="amd64"; ARCH_RUST="x86_64";  ARCH_SESH="x86_64" ;;
  aarch64|arm64)  ARCH_GO="arm64"; ARCH_RUST="aarch64"; ARCH_SESH="arm64"  ;;
  *)              ARCH_GO="";      ARCH_RUST="";        ARCH_SESH=""       ;;
esac

# ---------------------------------------------------------------------------
# GitHub release binary fallback
#   gh_install <owner/repo> <asset-regex> <binary-name>
# ---------------------------------------------------------------------------
gh_install() {
  local repo="$1" pattern="$2" bin="$3"
  local api="https://api.github.com/repos/${repo}/releases/latest"
  local url tmp found

  url="$(fetch_stdout "$api" 2>/dev/null \
    | grep -Eo '"browser_download_url": *"[^"]+"' \
    | cut -d'"' -f4 \
    | grep -E "$pattern" \
    | head -n1 || true)"

  if [ -z "$url" ]; then
    warn "Could not find a release asset for $bin ($repo)."
    return 1
  fi

  tmp="$(mktemp -d)"
  if ! fetch "$url" "$tmp/asset"; then
    rm -rf "$tmp"
    return 1
  fi

  mkdir -p "$HOME/.local/bin"
  case "$url" in
    *.tar.gz|*.tgz) tar -xzf "$tmp/asset" -C "$tmp" ;;
    *.zip)          unzip -q "$tmp/asset" -d "$tmp" ;;
    *)              cp "$tmp/asset" "$tmp/$bin" ;;
  esac

  found="$(find "$tmp" -type f -name "$bin" | head -n1 || true)"
  if [ -z "$found" ]; then
    warn "Binary '$bin' not found inside downloaded archive."
    rm -rf "$tmp"
    return 1
  fi

  install -m 0755 "$found" "$HOME/.local/bin/$bin"
  rm -rf "$tmp"
  log "Installed $bin to ~/.local/bin"
}

# ---------------------------------------------------------------------------
# Dotfile install with backup
# ---------------------------------------------------------------------------
install_dotfile() {  # install_dotfile <url> <dest>
  local url="$1" dest="$2" tmp
  tmp="$(mktemp)"
  if ! fetch "$url" "$tmp"; then
    warn "Failed to download $url"
    rm -f "$tmp"
    return 1
  fi

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if cmp -s "$tmp" "$dest" 2>/dev/null; then
      log "$dest already up to date"
      rm -f "$tmp"
      return 0
    fi
    mv "$dest" "${dest}.bak.${TS}"
    log "Backed up existing $dest -> ${dest}.bak.${TS}"
  fi

  mv "$tmp" "$dest"
  chmod 644 "$dest"
  log "Installed $dest"
}

# ---------------------------------------------------------------------------
# nano -> vi wrapper
#   /usr/local/bin precedes /usr/bin in PATH on all major distros, so this
#   shadows the real nano (the real package is left untouched).
# ---------------------------------------------------------------------------
install_nano_wrapper() {
  local dest="/usr/local/bin/nano" tmp
  tmp="$(mktemp)"
  cat > "$tmp" <<'EOF'
#!/bin/sh
# nano -> vi wrapper (installed by install.sh)
if command -v vi >/dev/null 2>&1; then
  exec vi "$@"
else
  exec vim "$@"
fi
EOF

  if [ -f "$dest" ] && cmp -s "$tmp" "$dest"; then
    log "nano wrapper already up to date"
  elif $SUDO mkdir -p /usr/local/bin && $SUDO install -m 0755 "$tmp" "$dest"; then
    log "Installed $dest -> vi"
  else
    warn "Could not write $dest (need root?)"
  fi
  rm -f "$tmp"

  hash -r 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# 1. Core packages: tmux, vim
# ---------------------------------------------------------------------------
log "Installing tmux and vim..."
for p in tmux vim; do
  if have "$p"; then
    log "$p already installed"
  else
    pkg_install "$p" || warn "Failed to install $p via $PM"
  fi
done

# ---------------------------------------------------------------------------
# 1b. nano -> vi (after vim is installed, so the wrapper has a target)
# ---------------------------------------------------------------------------
log "Replacing nano with vi..."
install_nano_wrapper

# ---------------------------------------------------------------------------
# 2. Dotfiles
# ---------------------------------------------------------------------------
log "Installing dotfiles..."
install_dotfile "$TMUX_CONF_URL" "$HOME/.tmux.conf"
install_dotfile "$VIMRC_URL"     "$HOME/.vimrc"
install_dotfile "$BASHRC_URL"    "$HOME/.bashrc"

# ---------------------------------------------------------------------------
# 3. CLI toolset: xclip, fzf, fd, ripgrep, sesh, starship
# ---------------------------------------------------------------------------
log "Installing CLI toolset..."

# xclip (package manager only; needs an X server anyway)
if have xclip; then
  log "xclip already installed"
else
  pkg_install xclip || warn "Could not install xclip"
fi

# fzf
if have fzf; then
  log "fzf already installed"
else
  if ! pkg_install fzf; then
    warn "Package install of fzf failed; trying GitHub release..."
    if [ -n "$ARCH_GO" ]; then
      gh_install "junegunn/fzf" "linux_${ARCH_GO}\.tar\.gz$" "fzf" \
        || warn "Could not install fzf"
    fi
  fi
fi

# fd (Debian/Ubuntu ship it as 'fdfind')
if have fd; then
  log "fd already installed"
else
  case "$PM" in
    apt|dnf|yum) FD_PKG="fd-find" ;;
    *)           FD_PKG="fd" ;;
  esac
  if ! pkg_install "$FD_PKG"; then
    warn "Package install of fd failed; trying GitHub release..."
    if [ -n "$ARCH_RUST" ]; then
      gh_install "sharkdp/fd" "${ARCH_RUST}-unknown-linux-musl\.tar\.gz$" "fd" \
        || warn "Could not install fd"
    fi
  fi
  if ! have fd && have fdfind; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    log "Linked fdfind -> ~/.local/bin/fd"
  fi
fi

# ripgrep
if have rg; then
  log "ripgrep already installed"
else
  if ! pkg_install ripgrep; then
    warn "Package install of ripgrep failed; trying GitHub release..."
    if [ "$ARCH_RUST" = "x86_64" ]; then
      gh_install "BurntSushi/ripgrep" "x86_64-unknown-linux-musl\.tar\.gz$" "rg" \
        || warn "Could not install ripgrep"
    elif [ "$ARCH_RUST" = "aarch64" ]; then
      gh_install "BurntSushi/ripgrep" "aarch64-unknown-linux-gnu\.tar\.gz$" "rg" \
        || warn "Could not install ripgrep"
    fi
  fi
fi

# sesh (not in distro repos; GitHub release binary)
if have sesh; then
  log "sesh already installed"
else
  if [ -n "$ARCH_SESH" ]; then
    gh_install "joshmedeski/sesh" "Linux_${ARCH_SESH}\.tar\.gz$" "sesh" \
      || warn "Could not install sesh"
  else
    warn "Unsupported architecture for sesh: $(uname -m)"
  fi
fi

# starship (package manager first, then GitHub release binary)
if have starship; then
  log "starship already installed"
else
  if ! pkg_install starship; then
    warn "Package install of starship failed; trying GitHub release..."
    if [ -n "$ARCH_RUST" ]; then
      gh_install "starship/starship" "${ARCH_RUST}-unknown-linux-musl\.tar\.gz$" "starship" \
        || warn "Could not install starship"
    fi
  fi
fi

# Wire starship into ~/.bashrc. Must come AFTER the .bashrc dotfile step,
# since that step replaces ~/.bashrc. Idempotent.
if have starship; then
  if [ -f "$HOME/.bashrc" ] && ! grep -q 'starship init bash' "$HOME/.bashrc"; then
    cat >> "$HOME/.bashrc" <<'EOF'

# >>> starship >>>
export PATH="$HOME/.local/bin:$PATH"
eval "$(starship init bash)"
# <<< starship <<<
EOF
    log "Added starship init to ~/.bashrc"
  else
    log "starship init already present in ~/.bashrc (or no ~/.bashrc)"
  fi
  if [ ! -f "$HOME/.config/starship.toml" ]; then
    warn "starship.toml not found at ~/.config/starship.toml (default prompt will be used)"
  fi
fi

# ---------------------------------------------------------------------------
# 4. Verify
# ---------------------------------------------------------------------------
verify() {
  log "Verification:"
  local t
  for t in tmux vim xclip fzf fd rg sesh starship; do
    if have "$t"; then
      printf '    \033[1;32m✓\033[0m %-6s %s\n' "$t" "$(command -v "$t")"
    else
      printf '    \033[1;31m✗\033[0m %-6s not found\n' "$t"
    fi
  done
  if [ -x /usr/local/bin/nano ]; then
    printf '    \033[1;32m✓\033[0m %-6s %s (wrapper to vi)\n' "nano" "$(command -v nano)"
  else
    printf '    \033[1;31m✗\033[0m %-6s wrapper not installed\n' "nano"
  fi
}
verify

log "Done. Start a new shell or run: source ~/.bashrc"
case ":$PATH:" in
  *":$HOME/.local/bin:"*) : ;;
  *) warn "Add ~/.local/bin to your PATH if it isn't already (your .bashrc may handle this)." ;;
esac
