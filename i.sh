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
#   - Refreshes the package index (no upgrades) with the right package manager
#     (apt, dnf, yum, pacman, zypper, apk)
#   - Installs tmux and vim
#   - Downloads .tmux.conf, .vimrc, .bashrc from their respective repos
#   - Backs up any existing dotfiles to <file>.bak.<timestamp>
#   - Installs the CLI toolset used by the tmux/vim config: xclip, fzf, fd,
#     ripgrep and sesh (package manager first, GitHub release binary as fallback)
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

# ---- sudo helper ------------------------------------------------------
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if have sudo; then
    SUDO="sudo"
  else
    err "Not running as root and sudo is not installed. Re-run as root."
    exit 1
  fi
fi

# ---- downloader -------------------------------------------------------
# fetch <url> <dest>
fetch() {
  if have curl; then
    curl -fsSL "$1" -o "$2"
  elif have wget; then
    wget -qO "$2" "$1"
  else
    err "Neither curl nor wget is available."
    return 1
  fi
}

# fetch_stdout <url>
fetch_stdout() {
  if have curl; then
    curl -fsSL "$1"
  elif have wget; then
    wget -qO- "$1"
  else
    return 1
  fi
}

# ---- package manager detection ---------------------------------------
PM=""
detect_pm() {
  if   have apt-get; then PM="apt"
  elif have dnf;     then PM="dnf"
  elif have yum;     then PM="yum"
  elif have pacman;  then PM="pacman"
  elif have zypper;  then PM="zypper"
  elif have apk;     then PM="apk"
  else
    err "No supported package manager found (apt, dnf, yum, pacman, zypper, apk)."
    exit 1
  fi
  log "Detected package manager: $PM"
}

# ---- refresh package index (no upgrades) ------------------------------
pm_update() {
  log "Refreshing package index ($PM) — no upgrades..."
  case "$PM" in
    apt)
      $SUDO apt-get update -y
      ;;
    dnf)
      # `dnf check-update` returns exit code 100 when updates exist, so use makecache
      $SUDO dnf -y makecache
      ;;
    yum)
      $SUDO yum -y makecache
      ;;
    pacman)
      $SUDO pacman -Sy --noconfirm
      ;;
    zypper)
      $SUDO zypper --non-interactive refresh
      ;;
    apk)
      $SUDO apk update
      ;;
  esac
  return 0
}

# ---- install a single package ----------------------------------------
# pm_install <pkg> ; returns non-zero if it fails (so callers can fall back)
pm_install() {
  case "$PM" in
    apt)    $SUDO apt-get install -y --no-install-recommends "$@" ;;
    dnf)    $SUDO dnf install -y "$@" ;;
    yum)    $SUDO yum install -y "$@" ;;
    pacman) $SUDO pacman -S --noconfirm --needed "$@" ;;
    zypper) $SUDO zypper --non-interactive install "$@" ;;
    apk)    $SUDO apk add "$@" ;;
  esac
}

# Map a logical tool name to the distro's package name
pkg_name() {
  case "$1" in
    vim)
      case "$PM" in
        dnf|yum) echo "vim-enhanced" ;;
        *)       echo "vim" ;;
      esac ;;
    fd)
      case "$PM" in
        apt|dnf|yum) echo "fd-find" ;;
        *)           echo "fd" ;;
      esac ;;
    *) echo "$1" ;;
  esac
}

# ---- architecture ----------------------------------------------------
UNAME_M="$(uname -m)"
case "$UNAME_M" in
  x86_64|amd64)  UNAME_M="x86_64";  GOARCH="amd64" ;;
  aarch64|arm64) UNAME_M="aarch64"; GOARCH="arm64" ;;
  *)             GOARCH="$UNAME_M" ;;
esac

# ---- GitHub release fallback -----------------------------------------
# gh_asset_url <owner/repo> <ERE pattern>
gh_asset_url() {
  fetch_stdout "https://api.github.com/repos/$1/releases/latest" 2>/dev/null \
    | grep -o '"browser_download_url": *"[^"]*"' \
    | sed 's/.*: *"//; s/"$//' \
    | grep -E "$2" \
    | head -n1
}

# install_from_release <binary> <owner/repo> <ERE pattern>
install_from_release() {
  local bin="$1" repo="$2" pattern="$3" url tmp found
  log "Falling back to GitHub release for $bin ($repo)..."
  url="$(gh_asset_url "$repo" "$pattern" || true)"
  if [ -z "$url" ]; then
    warn "Could not find a release asset for $bin (arch: $UNAME_M). Skipping."
    return 1
  fi
  tmp="$(mktemp -d)"
  if ! fetch "$url" "$tmp/asset.tar.gz"; then
    warn "Download failed for $bin."
    rm -rf "$tmp"
    return 1
  fi
  tar -xzf "$tmp/asset.tar.gz" -C "$tmp" 2>/dev/null || {
    warn "Could not extract archive for $bin."
    rm -rf "$tmp"
    return 1
  }
  found="$(find "$tmp" -type f -name "$bin" | head -n1)"
  if [ -z "$found" ]; then
    warn "Binary '$bin' not found inside the archive."
    rm -rf "$tmp"
    return 1
  fi
  mkdir -p "$HOME/.local/bin"
  install -m 0755 "$found" "$HOME/.local/bin/$bin"
  rm -rf "$tmp"
  log "Installed $bin to ~/.local/bin/$bin"
}

# ---- tool installers -------------------------------------------------
install_base() {
  # curl is needed for the release fallbacks; tar/gzip for extraction
  for t in curl tar gzip; do
    have "$t" || pm_install "$t" || warn "Could not install $t"
  done
  for t in tmux vim; do
    if have "$t"; then
      log "$t already installed"
    else
      log "Installing $t..."
      pm_install "$(pkg_name "$t")" || err "Failed to install $t"
    fi
  done
}

install_xclip() {
  if have xclip; then log "xclip already installed"; return; fi
  log "Installing xclip..."
  pm_install xclip || warn "xclip not available; clipboard integration may not work"
}

install_fzf() {
  if have fzf; then log "fzf already installed"; return; fi
  log "Installing fzf..."
  pm_install fzf && return 0
  install_from_release fzf "junegunn/fzf" "linux_${GOARCH}\.tar\.gz$" || true
}

install_fd() {
  if have fd; then log "fd already installed"; return; fi
  if have fdfind; then
    log "fd-find already installed, linking fdfind -> fd"
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    return
  fi
  log "Installing fd..."
  if pm_install "$(pkg_name fd)"; then
    # Debian/Ubuntu ship the binary as `fdfind`
    if ! have fd && have fdfind; then
      mkdir -p "$HOME/.local/bin"
      ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    fi
    return 0
  fi
  install_from_release fd "sharkdp/fd" "${UNAME_M}-unknown-linux-(musl|gnu)\.tar\.gz$" || true
}

install_ripgrep() {
  if have rg; then log "ripgrep already installed"; return; fi
  log "Installing ripgrep..."
  pm_install ripgrep && return 0
  install_from_release rg "BurntSushi/ripgrep" "${UNAME_M}-unknown-linux-(musl|gnu)\.tar\.gz$" || true
}

install_sesh() {
  if have sesh; then log "sesh already installed"; return; fi
  install_from_release sesh "joshmedeski/sesh" "[Ll]inux_(${UNAME_M}|${GOARCH})\.tar\.gz$" || true
}

# ---- dotfiles --------------------------------------------------------
# install_dotfile <url> <dest>
install_dotfile() {
  local url="$1" dest="$2" tmp
  tmp="$(mktemp)"
  if ! fetch "$url" "$tmp"; then
    err "Failed to download $url"
    rm -f "$tmp"
    return 1
  fi
  if [ -f "$dest" ]; then
    if cmp -s "$tmp" "$dest"; then
      log "$dest is already up to date"
      rm -f "$tmp"
      return 0
    fi
    cp -p "$dest" "$dest.bak.$TS"
    warn "Backed up existing $dest -> $dest.bak.$TS"
  fi
  mv "$tmp" "$dest"
  chmod 644 "$dest"
  log "Installed $dest"
}

# ---- optional shell extras (ble.sh / starship) ------------------------
# Only wires up what is actually installed. Must run AFTER the .bashrc
# dotfile is installed, since that step overwrites ~/.bashrc.
configure_shell_extras() {
  local rc="$HOME/.bashrc" tmp
  local blesh="$HOME/.local/share/blesh/ble.sh"
  local has_ble=0 has_starship=0

  [ -f "$blesh" ] && has_ble=1
  have starship && has_starship=1

  if [ "$has_ble" -eq 0 ] && [ "$has_starship" -eq 0 ]; then
    log "Neither ble.sh nor starship installed; leaving .bashrc as is"
    return 0
  fi
  [ -f "$rc" ] || { warn "$rc not found; skipping shell extras"; return 0; }

  # 1) ble.sh loader goes at the TOP (with --noattach)
  if [ "$has_ble" -eq 1 ] && ! grep -q '# >>> blesh-load >>>' "$rc"; then
    tmp="$(mktemp)"
    {
      cat <<'EOF'
# >>> blesh-load >>>
[[ $- == *i* && -f ~/.local/share/blesh/ble.sh ]] && source ~/.local/share/blesh/ble.sh --noattach
# <<< blesh-load <<<

EOF
      cat "$rc"
    } > "$tmp"
    mv "$tmp" "$rc"
    chmod 644 "$rc"
    log "Added ble.sh loader to top of $rc"
  fi

  # 2) starship init goes at the BOTTOM
  if [ "$has_starship" -eq 1 ] && ! grep -q 'starship init bash' "$rc"; then
    cat >> "$rc" <<'EOF'

# >>> starship >>>
export PATH="$HOME/.local/bin:$PATH"
eval "$(starship init bash)"
# <<< starship <<<
EOF
    log "Added starship init to $rc"
  fi

  # 3) ble-attach must be the very LAST thing (after starship)
  if [ "$has_ble" -eq 1 ] && ! grep -q '# >>> blesh-attach >>>' "$rc"; then
    cat >> "$rc" <<'EOF'

# >>> blesh-attach >>>
[[ ${BLE_VERSION-} ]] && ble-attach
# <<< blesh-attach <<<
EOF
    log "Added ble-attach to end of $rc"
  fi

  if [ "$has_starship" -eq 1 ] && [ ! -f "$HOME/.config/starship.toml" ]; then
    warn "starship is installed but ~/.config/starship.toml is missing (default prompt will be used)"
  fi
}

# ---- verify ----------------------------------------------------------
verify() {
  log "Verifying installation..."
  local missing=0
  for t in tmux vim xclip fzf fd rg sesh starship; do
    if have "$t"; then
      printf '  \033[1;32mok\033[0m   %s -> %s\n' "$t" "$(command -v "$t")"
    else
      printf '  \033[1;31mmiss\033[0m %s\n' "$t"
      missing=1
    fi
  done
  for f in "$HOME/.tmux.conf" "$HOME/.vimrc" "$HOME/.bashrc"; do
    if [ -f "$f" ]; then
      printf '  \033[1;32mok\033[0m   %s\n' "$f"
    else
      printf '  \033[1;31mmiss\033[0m %s\n' "$f"
      missing=1
    fi
  done
  if [ "$missing" -eq 1 ]; then
    warn "Some items are missing (see above)."
  else
    log "Everything is in place."
  fi
}

# ---- main ------------------------------------------------------------
main() {
  detect_pm
  pm_update
  install_base
  install_xclip
  install_fzf
  install_fd
  install_ripgrep
  install_sesh

  install_dotfile "$TMUX_CONF_URL" "$HOME/.tmux.conf"
  install_dotfile "$VIMRC_URL"     "$HOME/.vimrc"
  install_dotfile "$BASHRC_URL"    "$HOME/.bashrc"

  configure_shell_extras

  verify

  log "Done. Run 'source ~/.bashrc' or open a new shell, then start tmux."
}

main "$@"
