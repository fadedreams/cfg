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
#   - Detects the package manager (apt, dnf, yum, pacman, zypper, apk)
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

# ... REST OF YOUR SCRIPT GOES HERE ...
# Delete the refresh step: the apt-get update / dnf makecache / yum makecache /
# pacman -Sy / zypper refresh / apk update lines, plus the function that wraps
# them and the call to it.
