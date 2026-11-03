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

install_starship() {
    echo "=== Installing Starship ==="
    mkdir -p ~/.local/bin ~/.config

    if ! command -v curl &>/dev/null; then
        echo "Installing curl..."
        if command -v apt &>/dev/null; then
            sudo DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends curl
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y curl
        elif command -v pacman &>/dev/null; then
            sudo pacman -Sy --noconfirm --needed curl
        elif command -v apk &>/dev/null; then
            sudo apk add --no-interactive curl
        elif command -v brew &>/dev/null; then
            brew install curl
        else
            echo "✗ Please install curl manually, then re-run this."
            return 1
        fi
    fi

    curl -sS https://starship.rs/install.sh | sh -s -- -y -b ~/.local/bin || {
        echo "✗ Starship install failed — check the output above."
        return 1
    }

    # Back up any existing config, then write ours
    [ -f ~/.config/starship.toml ] && cp ~/.config/starship.toml ~/.config/starship.toml.bak
    cat > ~/.config/starship.toml <<'EOF'
"$schema" = 'https://starship.rs/config-schema.json'
add_newline = true
format = "$directory$os$git_branch$git_status$nodejs$rust$golang$php$python$docker_context$cmd_duration$status$character"

[os]
disabled = true
format = "[$symbol](blue) "

[os.symbols]
Ubuntu = "󰕈"
Artix = "󰣇"
Arch = "󰣇"
CachyOS = "󰣇"
Macos = ""

[directory]
format = "[$path](bold cyan) "
truncation_length = 4
truncate_to_repo = true
style = "bold cyan"

[git_branch]
symbol = ""
format = "[$symbol $branch](bold purple) "
truncation_length = 20
truncation_symbol = "…"

[git_status]
format = "($ahead_behind$staged$modified$untracked$deleted$conflicted)"
ahead = "[⇡$count ](bold cyan)"
behind = "[⇣$count ](bold cyan)"
diverged = "[⇡$ahead_count⇣$behind_count ](bold cyan)"
staged = "[+$count ](bold green)"
modified = "[●$count ](bold yellow)"
untracked = "[?$count ](bold white)"
deleted = "[✘$count ](bold red)"
conflicted = "[⚡$count ](bold red)"

[nodejs]
symbol = "󰎙 "
format = "[$symbol$version](bold green) "

[rust]
symbol = "󱘗 "
format = "[$symbol$version](bold red) "

[golang]
symbol = "󰟓 "
format = "[$symbol$version](bold cyan) "

[php]
symbol = "󰌟 "
format = "[$symbol$version](bold purple) "

[python]
symbol = "󱔎 "
format = '[$symbol($virtualenv )](bold yellow)'

[docker_context]
symbol = "󰡨 "
format = "[$symbol$context](bold blue) "
only_with_files = true

[cmd_duration]
min_time = 3000
format = " [$duration](bold yellow) "

[status]
disabled = false
format = "[$status](bold red)"
recognize_signal_code = true
pipestatus = false

[character]
success_symbol = "[❯](green)"
error_symbol = "[❯](red)"
vimcmd_symbol = "[❮](blue)"
format = "$symbol "
EOF

    # Wire into .bashrc (idempotent)
    if ! grep -q 'starship init bash' ~/.bashrc 2>/dev/null; then
        cat >> ~/.bashrc <<'EOF'

# Starship prompt
export PATH="$HOME/.local/bin:$PATH"
eval "$(starship init bash)"
EOF
    fi

    if command -v starship &>/dev/null || [ -x ~/.local/bin/starship ]; then
        echo "✓ Starship installed. Config: ~/.config/starship.toml"
    else
        echo "✗ Install failed — check the output above."
        return 1
    fi
}
install_starship
