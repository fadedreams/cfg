chmod +x "$0" 2>/dev/null
install_blesh() {
    echo "=== Installing ble.sh ==="
    if ! command -v make &>/dev/null || ! command -v git &>/dev/null; then
        echo "Installing build deps (git, make, gawk)..."
        if command -v apt &>/dev/null; then
            sudo DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends git make gawk
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y git make gawk
        elif command -v pacman &>/dev/null; then
            sudo pacman -Sy --noconfirm --needed git make gawk
        elif command -v apk &>/dev/null; then
            sudo apk add --no-interactive git make gawk
        elif command -v brew &>/dev/null; then
            brew install git make gawk
        else
            echo "✗ Please install git, make, and gawk manually, then re-run this."
            return 1
        fi
    fi
    local src_dir="${TMPDIR:-/tmp}/ble.sh-build"
    rm -rf "$src_dir"
    git clone --recursive --depth 1 --shallow-submodules https://github.com/akinomyoga/ble.sh.git "$src_dir" \
        && make -C "$src_dir" install PREFIX=~/.local
    if [ -f ~/.local/share/blesh/ble.sh ]; then
        echo "✓ ble.sh installed to ~/.local/share/blesh/ble.sh"
        echo "  It will load automatically next time you start bash (already wired up in .bashrc)."
    else
        echo "✗ Install failed — check the output above."
        return 1
    fi
}
install_blesh
