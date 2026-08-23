#!/usr/bin/env bash
set -euo pipefail

URL="https://raw.githubusercontent.com/fadedreams/cfg/refs/heads/main/.bashrc"
DEST="$HOME/.bashrc"
BACKUP="$HOME/.bashrc.bak.$(date +%Y%m%d%H%M%S)"

# Back up existing .bashrc if present
if [ -f "$DEST" ]; then
    cp "$DEST" "$BACKUP"
    echo "Backed up existing $DEST to $BACKUP"
fi

# Download and install
if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$URL" -o "$DEST"
elif command -v wget >/dev/null 2>&1; then
    wget -q "$URL" -O "$DEST"
else
    echo "Error: need curl or wget installed." >&2
    exit 1
fi

echo "Installed new .bashrc to $DEST"

# Auto-source (only works if this script is sourced, e.g. 'source install_bashrc.sh')
if [ -n "${BASH_SOURCE:-}" ] && [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    source "$DEST"
    echo "Sourced $DEST into the current shell."
else
    echo "Note: to apply changes in THIS shell, run the script with 'source', e.g.:"
    echo "  source install_bashrc.sh"
    exec bash
fi
