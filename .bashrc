#── Aliases ────────────────────────────────────────────────

alias v="nvim"
alias py="python3"
alias docker-compose="docker compose"
alias reload='source ~/.zshrc'
alias c='clear'
alias ssh='TERM=xterm-256color ssh'

# ls
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias lls='du -sh * .* 2>/dev/null | sort -hr | column -t'

# Safety
alias rm='rm -I'
alias cp='cp -i'
alias mv='mv -i'
alias mkdir='mkdir -pv'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Quick directory bookmarks
alias mark='pwd > ~/.lastdir'
alias jump='cd $(cat ~/.lastdir 2>/dev/null || echo ~)'

# Grep
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Disk
alias df='df -h'

# Docker
alias dsa='docker stop $(docker ps -a -q)'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dlogs='docker logs -f'

# System
alias top10='ps aux --sort=-%mem | head -11'
alias ramcheck='watch -n 2 "free -h && echo && zramctl && echo && swapon --show"'

# Network
alias myip='curl -s ifconfig.me'
alias localip='ip -4 addr show | grep -oP "(?<=inet\s)\d+(\.\d+){3}" | grep -v 127.0.0.1'
alias ports='ss -tulanp'
alias lsof-port='lsof -i'

# Files
alias ff='find . -type f -name'
alias fdir='find . -type d -name'
alias tf='tail -f'
alias count='find . -maxdepth 1 -type f | wc -l'

# Misc
alias path='echo -e ${PATH//:/\\n}'
alias now='date +"%T"'
alias nowdate='date +"%Y-%m-%d"'
alias ping='ping -c 5'
alias diff='colordiff'
alias serve='python3 -m http.server 8000'
alias cwd='pwd | tr -d "\n" | xclip -selection clipboard && echo "PWD copied: $(pwd)"'
alias clast='fc -ln -1 | tr -d "\n" | xclip -selection clipboard && echo "Last command copied."'

# Git
alias gd='git diff'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --decorate --graph'
alias gla='git log --oneline --decorate --graph --all'

git_test() {
  ssh-add ~/.ssh/fd 2>/dev/null
  ssh -T git@github.com
}


alias tree="command tree -I 'node_modules|dist|.git|.next|.gitignore|.DS_Store|.env|.env.local|.cache|.vscode|.idea|coverage|build|out|tmp|.turbo|.eslintcache'"

#── Functions ────────────────────────────────────────────────
clip() {
    if [ $# -eq 0 ]; then
        echo "Usage: clip <file> | clip <command> [args...]"
        return 1
    fi

    local is_file=0
    if [ $# -eq 1 ] && [ -f "$1" ] && [ -r "$1" ]; then
        is_file=1
    elif [ $# -gt 1 ] && [ -e "$1" ]; then
        echo "Error: '$1' exists as a file, but you passed extra arguments ($*)." >&2
        echo "If the filename has spaces, quote it: clip \"$*\"" >&2
        return 1
    fi

    local content rc

    if [ "$is_file" -eq 1 ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            pbcopy < "$1"; rc=$?
        elif [ -n "$SSH_CONNECTION" ] || [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
            local b64
            b64=$(base64 < "$1" | tr -d '\n')
            rc=$?
            if [ -n "$TMUX" ]; then
                printf '\033Ptmux;\033\033]52;c;%s\a\033\\' "$b64" > /dev/tty
            else
                printf '\033]52;c;%s\a' "$b64" > /dev/tty
            fi
        elif command -v xclip &> /dev/null; then
            xclip -selection clipboard < "$1"; rc=$?
        elif command -v xsel &> /dev/null; then
            xsel --clipboard --input < "$1"; rc=$?
        elif command -v wl-copy &> /dev/null; then
            wl-copy < "$1"; rc=$?
        else
            echo "Error: No clipboard utility found" >&2
            return 1
        fi

        if [ "$rc" -ne 0 ]; then
            echo "Error: Failed to copy '$1'" >&2
            return 1
        fi
        echo "✓ Copied contents of '$1' to clipboard"
        return 0
    fi

    content=$("$@" 2>&1)
    rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "Error: Command failed" >&2
        echo "$content" >&2
        return 1
    fi

    if [[ "$OSTYPE" == "darwin"* ]]; then
        printf '%s' "$content" | pbcopy
    elif [ -n "$SSH_CONNECTION" ] || [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
        local b64
        b64=$(printf '%s' "$content" | base64 | tr -d '\n')
        if [ -n "$TMUX" ]; then
            printf '\033Ptmux;\033\033]52;c;%s\a\033\\' "$b64" > /dev/tty
        else
            printf '\033]52;c;%s\a' "$b64" > /dev/tty
        fi
    elif command -v xclip &> /dev/null; then
        printf '%s' "$content" | xclip -selection clipboard
    elif command -v xsel &> /dev/null; then
        printf '%s' "$content" | xsel --clipboard --input
    elif command -v wl-copy &> /dev/null; then
        printf '%s' "$content" | wl-copy
    else
        echo "Error: No clipboard utility found" >&2
        return 1
    fi

    echo "✓ Copied output of '$*' to clipboard"
}
#── PORT ────────────────────────────────────────────────

kill_port() {
    if [ -z "$1" ]; then
        echo "Usage: kill_port <port_number>"
        return 1
    fi
    local port=$1
    local info
    info=$(sudo ss -lptn "sport = :$port" 2>/dev/null)

    if [ -z "$(echo "$info" | tail -n +2)" ]; then
        echo "No process found listening on port $port"
        return 0
    fi

    echo "$info"
    sudo fuser -k "$port"/tcp 2>/dev/null
    sleep 0.5

    if sudo ss -lptn "sport = :$port" 2>/dev/null | grep -q LISTEN; then
        echo "⚠ Port $port may still be in use"
    else
        echo "✓ Port $port is now free"
    fi
}

kill9() {
  sudo fuser -k "$1"/tcp
}

check_port() {
    if [[ -z "$1" ]]; then
        echo "Usage: lp <port>"
        return 1
    fi
    local port="$1"
    if sudo ss -tuln | grep -q ":${port}[[:space:]]"; then
        echo "Port $port is OPEN"
        sudo ss -ltunp "( sport = :$port )"
        return 0
    else
        echo "Port $port is CLOSED"
        return 1
    fi
}

# ssh_port_forward local_port:remote_port m@5.161.157.120
# ssh_port_forward 8080:8080 m@5.161.157.120
ssh_port_forward() {
  local mapping="$1"
  local target="$2"

  if [[ -z "$mapping" || -z "$target" ]]; then
    echo "usage: ssh_port_forward local_port:remote_port user@host"
    return 1
  fi

  local local_port="${mapping%%:*}"
  local remote_port="${mapping##*:}"

  echo "forwarding localhost:$local_port → $target:$remote_port"
  ssh -L "${local_port}:localhost:${remote_port}" "$target" -N
}

#── PROCESS ────────────────────────────────────────────────

kill_process() {
    if [ -z "$1" ]; then
        echo "Usage: killprocess <process_name>"
        echo "Example: killprocess v2ray"
        return 1
    fi
    local process_name="$1"
    if ! pgrep -x "$process_name" > /dev/null && ! pgrep -f "$process_name" > /dev/null; then
        echo "No processes found matching: $process_name"
        return 0
    fi
    echo "Found processes matching '$process_name':"
    ps aux | grep -i "$process_name" | grep -v grep
    echo ""
    echo "Killing all processes matching '$process_name'..."
    killall -9 "$process_name" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✓ Successfully killed processes"
    else
        echo "✓ Processes killed"
    fi
}

find_process() {
    if [ -z "$1" ]; then
        echo "Usage: find_process <process_name>"
        echo "Example: find_process v2rayN"
        return 1
    fi
    local process_name="$1"
    local results=$(ps aux | grep "$process_name" | grep -v grep)
    if [ -z "$results" ]; then
        echo "No processes found matching: $process_name"
        return 0
    fi
    echo "Processes matching '$process_name':"
    echo ""
    ps aux | grep "$process_name" | grep -v grep
    echo ""
    local count=$(echo "$results" | wc -l)
    echo "Found $count process(es)"
}


#── PROXY ────────────────────────────────────────────────

# Shared helper: parses "user@host" into two space-separated values on stdout.
# Usage: read -r user host < <(_parse_userhost "$input") || return 1
_parse_userhost() {
    local input="$1"
    local user="${input%@*}"
    local host="${input#*@}"
    if [ -z "$user" ] || [ -z "$host" ] || [ "$user" = "$host" ]; then
        echo "Error: Invalid format. Use user@ip (e.g. root@1.2.3.4)" >&2
        return 1
    fi
    echo "$user" "$host"
}

# sudo pacman -S sshuttle
set_ssh_proxy() {
    local input="$1"
    if [ -z "$input" ]; then
        echo "Error: Please provide user@ip"
        echo "Usage: set_ssh_proxy <user@ip>"
        return 1
    fi

    if ! command -v sshuttle >/dev/null 2>&1; then
        echo "Error: sshuttle is not installed"
        return 1
    fi

    # Split user and host
    local user="${input%@*}"
    local host="${input#*@}"
    if [ -z "$user" ] || [ -z "$host" ] || [ "$user" = "$host" ]; then
        echo "Error: Invalid format. Use user@ip (e.g. root@1.2.3.4)"
        return 1
    fi

    sshuttle -r "${user}@${host}" \
        --dns --auto-hosts \
        --no-latency-control \
        --exclude "$host" \
        --exclude 127.0.0.0/8 \
        --exclude 10.0.0.0/8 \
        --exclude 172.16.0.0/12 \
        --exclude 192.168.0.0/16 \
        --method=auto \
        -e 'ssh -o Compression=no -o TCPKeepAlive=yes -o ServerAliveInterval=15 -o ServerAliveCountMax=4 -o "IPQoS=lowdelay throughput" -o Ciphers=chacha20-poly1305@openssh.com,aes128-gcm@openssh.com -o KexAlgorithms=curve25519-sha256' \
        0/0
}

# ssh -D 1080 -C root@95.182.92.67
set_ssh_proxy_port() {
    local port="$1"
    local input="$2"

    if [ -z "$port" ] || [ -z "$input" ]; then
        echo "Error: Please provide port and user@ip"
        echo "Usage: set_ssh_proxy_port <port> <user@ip>"
        return 1
    fi

    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo "Error: Invalid port '$port'"
        return 1
    fi

    # Split user and host
    local user="${input%@*}"
    local host="${input#*@}"
    if [ -z "$user" ] || [ -z "$host" ] || [ "$user" = "$host" ]; then
        echo "Error: Invalid format. Use user@ip (e.g. root@1.2.3.4)"
        return 1
    fi

    if ! command -v ssh >/dev/null 2>&1; then
        echo "Error: ssh is not installed"
        return 1
    fi

    echo "Starting SOCKS5 proxy on 127.0.0.1:${port} via ${user}@${host} ..."

    ssh -N -T -D "127.0.0.1:${port}" "${user}@${host}" \
        -o ExitOnForwardFailure=yes \
        -o Compression=no \
        -o TCPKeepAlive=yes \
        -o ServerAliveInterval=15 \
        -o ServerAliveCountMax=4 \
        -o IPQoS="lowdelay throughput" \
        -o Ciphers=chacha20-poly1305@openssh.com,aes128-gcm@openssh.com \
        -o KexAlgorithms=curve25519-sha256
}
set_ssh_proxy() {
    local input="$1"
    if [ -z "$input" ]; then
        echo "Error: Please provide user@ip"
        echo "Usage: set_ssh_proxy <user@ip>"
        return 1
    fi

    if ! command -v sshuttle >/dev/null 2>&1; then
        echo "Error: sshuttle is not installed"
        return 1
    fi

    local user host
    read -r user host < <(_parse_userhost "$input") || return 1

    echo "Starting sshuttle full-tunnel via ${user}@${host} (may prompt for sudo) ..."
    sshuttle -r "${user}@${host}" \
        --dns --auto-hosts \
        --no-latency-control \
        --exclude "$host" \
        --exclude 127.0.0.0/8 \
        --exclude 10.0.0.0/8 \
        --exclude 172.16.0.0/12 \
        --exclude 192.168.0.0/16 \
        --method=auto \
        -e 'ssh -o Compression=no -o TCPKeepAlive=yes -o ServerAliveInterval=15 -o ServerAliveCountMax=4 -o "IPQoS=lowdelay throughput" -o Ciphers=chacha20-poly1305@openssh.com,aes128-gcm@openssh.com -o KexAlgorithms=curve25519-sha256' \
        0/0
}

set_ssh_proxy_port() {
    local port="$1"
    local input="$2"
    if [ -z "$port" ] || [ -z "$input" ]; then
        echo "Error: Please provide port and user@ip"
        echo "Usage: set_ssh_proxy_port <port> <user@ip>"
        return 1
    fi

    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo "Error: Invalid port '$port'"
        return 1
    fi

    if ! command -v ssh >/dev/null 2>&1; then
        echo "Error: ssh is not installed"
        return 1
    fi

    local user host
    read -r user host < <(_parse_userhost "$input") || return 1

    # Check the local port isn't already bound
    if command -v lsof >/dev/null 2>&1; then
        if lsof -i ":${port}" >/dev/null 2>&1; then
            echo "Error: Port ${port} is already in use"
            return 1
        fi
    elif command -v ss >/dev/null 2>&1; then
        if ss -ltn "( sport = :${port} )" 2>/dev/null | grep -q ":${port}"; then
            echo "Error: Port ${port} is already in use"
            return 1
        fi
    fi

    echo "Starting SOCKS5 proxy on 127.0.0.1:${port} via ${user}@${host} ..."
    ssh -f -N -T -D "127.0.0.1:${port}" "${user}@${host}" \
        -o ExitOnForwardFailure=yes \
        -o Compression=no \
        -o TCPKeepAlive=yes \
        -o ServerAliveInterval=15 \
        -o ServerAliveCountMax=4 \
        -o IPQoS="lowdelay throughput" \
        -o Ciphers=chacha20-poly1305@openssh.com,aes128-gcm@openssh.com \
        -o KexAlgorithms=curve25519-sha256

    if [ $? -eq 0 ]; then
        echo "Proxy running in background on 127.0.0.1:${port}"
        echo "Stop it with: pkill -f 'ssh.*-D 127.0.0.1:${port}'"
    else
        echo "Error: Failed to start proxy"
        return 1
    fi
}
# jump
set_ssh_proxy_jump() {
    local vps1="$1"
    local vps2="$2"

    if [ -z "$vps1" ] || [ -z "$vps2" ]; then
        echo "Error: Please provide both VPS user@ip"
        echo "Usage: set_ssh_proxy <user1@vps1_ip> <user2@vps2_ip>"
        return 1
    fi

    local vps1_ip="${vps1##*@}"
    local vps2_ip="${vps2##*@}"

    sshuttle -r "$vps2" \
        --dns --to-ns 8.8.8.8 --to-ns 8.8.4.4 \
        --no-latency-control \
        --auto-hosts \
        --exclude "$vps1_ip" \
        --exclude "$vps2_ip" \
        --exclude 127.0.0.0/8 \
        --exclude 10.0.0.0/8 \
        --exclude 172.16.0.0/12 \
        --exclude 192.168.0.0/16 \
        --method=auto \
        -e "ssh -o Compression=no -o TCPKeepAlive=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=6 -o 'IPQoS=lowdelay throughput' -o Ciphers=chacha20-poly1305@openssh.com,aes128-gcm@openssh.com -o KexAlgorithms=curve25519-sha256 -o ProxyCommand='ssh -W %h:%p $vps1'" \
        0/0
}

# ssh -D 1080 -C root@95.182.81.164
# ssh jump
# ssh -D 1080 -C -o ProxyCommand="ssh -W %h:%p root@95.38.233.143" root@95.182.81.164
set_terminal_socks_port() {
    if [ -z "$1" ]; then
        echo "Usage: set_terminal_proxy_port <port>"
        echo "Example: set_terminal_proxy_port 1080"
        return 1
    fi

    local port=$1
    export http_proxy="socks5h://127.0.0.1:$port"
    export https_proxy="socks5h://127.0.0.1:$port"
    export ALL_PROXY="socks5h://127.0.0.1:$port"

    echo "✓ Terminal proxy set to socks5h://127.0.0.1:$port"
}


set_terminal_proxy_v2raya() {
    export http_proxy="http://127.0.0.1:20171"
    export https_proxy="http://127.0.0.1:20171"
    export all_proxy="socks5h://127.0.0.1:20170"
}

set_terminal_proxy_v2rayn() {
    export http_proxy="socks5://127.0.0.1:10808"
    export https_proxy="socks5://127.0.0.1:10808"
    export all_proxy="socks5://127.0.0.1:10808"
}

set_terminal_proxy_mhm() {
    export http_proxy="socks5://127.0.0.1:8085"
    export https_proxy="socks5://127.0.0.1:8085"
    export all_proxy="socks5://127.0.0.1:8085"
}

function ssh_proxy_v2rayn() {
    /usr/bin/ssh -o "ProxyCommand=nc -X 5 -x 127.0.0.1:10808 %h %p" "$1"
}

function ssh_proxy_v2raya() {
    /usr/bin/ssh -o "ProxyCommand=nc -X 5 -x 127.0.0.1:20170 %h %p" "$1"
}

function vnc-tunnel() {
    if [[ -z "$1" ]]; then
        echo "Usage: vnc-tunnel <ip>"
        echo "Example: vnc-tunnel 95.182.100.214"
        return 1
    fi
    echo "🔒 Starting VNC tunnel to $1..."
    echo "Then connect TigerVNC to localhost:1 (not the remote IP)."
    ssh -o ProxyCommand="nc -X 5 -x 127.0.0.1:1080 %h %p" \
        -L 5901:localhost:5901 \
        -N root@$1
}

function unset_terminal_proxy() {
    unset HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy NO_PROXY no_proxy
}


brave_proxy() {
    brave --proxy-server="socks5://127.0.0.1:10808" "$@" &
}

thorium_proxy() {
    thorium-browser --proxy-server="socks5://127.0.0.1:10808" "$@" &
}

#── WIFI ────────────────────────────────────────────────

wifi_me() {
    nmcli con show
}

wifi_list() {
    nmcli device wifi list
}

wifi_active() {
    nmcli connection show --active
}

wifi_on() {
    nmcli radio wifi on
}

wifi_off() {
    nmcli radio wifi off
}

wifi_connect() {
    local name="$1"
    if [ -z "$name" ]; then
        echo "Error: Please provide a wifi name"
        echo "Usage: wifi_connect <wifi_name>"
        return 1
    fi
    nmcli --ask device wifi connect "$name"
}

wifi_disconnect() {
    local name="$1"
    if [ -z "$name" ]; then
        echo "Error: Please provide a connection name"
        echo "Usage: wifi_disconnect <wifi_name>"
        return 1
    fi
    nmcli connection down "$name"
}

# bonus: rescan available networks
wifi_scan() {
    nmcli device wifi rescan && nmcli device wifi list
}

# bonus: show current signal/bitrate/channel for connected wifi
wifi_status() {
    nmcli -f IN-USE,SSID,SIGNAL,BARS,CHAN,RATE device wifi list | grep '^\*'
}


#── NET ────────────────────────────────────────────────

set_shecan_dns() {
    local conn_name="${1:-DialupInternet}"
    local dns_servers="${2:-178.22.122.101,185.51.200.1}"
    if [ $# -eq 1 ]; then
        dns_servers="$1"
        conn_name="DialupInternet"
    fi
    echo "=== Setting Shecan DNS ==="
    echo "Connection   : $conn_name"
    echo "DNS Servers  : $dns_servers"
    echo "--------------------------------"
    nmcli connection modify "$conn_name" ipv4.dns "$dns_servers"
    nmcli connection modify "$conn_name" ipv4.ignore-auto-dns yes
    echo "Restarting connection..."
    nmcli connection down "$conn_name" && nmcli connection up "$conn_name"
    echo "=== Done! Current resolv.conf ==="
    cat /etc/resolv.conf
}

unset_shecan_dns() {
    local conn_name="${1:-DialupInternet}"
    echo "=== Resetting DNS for: $conn_name ==="
    nmcli connection modify "$conn_name" ipv4.dns ""
    nmcli connection modify "$conn_name" ipv4.ignore-auto-dns no
    nmcli connection up "$conn_name"
    echo "=== DNS Reset Completed ==="
    cat /etc/resolv.conf
}


curl_test() {
    curl https://api.ipify.org
}

scan_ports() {
    if [[ -z "$1" ]]; then
        echo "Usage: scan_ports <IP>"
        return 1
    fi
    sudo nmap -sS -sU --top-ports 100 -T5 --open "$1"
}


bat_info() {
    cat /sys/class/power_supply/BAT*/{status,capacity}
}



#── flush ────────────────────────────────────────────────
#flush save
#flush restore

flush() {
    local ACTION="${1:-restore}"
    local STATE_DIR="$HOME/.config/net-state"

    save_state() {
        mkdir -p "$STATE_DIR"
        echo "[*] Saving clean network state..."
        ip route show default > "$STATE_DIR/default_route"
        nmcli -t -f NAME,STATE,DEVICE con show --active > "$STATE_DIR/active_connections"
        resolvectl status 2>/dev/null > "$STATE_DIR/dns_state"
        cp /etc/resolv.conf "$STATE_DIR/resolv.conf.bak" 2>/dev/null
        ip route | grep default | awk '{print $5}' | head -n1 > "$STATE_DIR/primary_iface"
        echo "[✓] State saved to $STATE_DIR"
        echo "    Primary interface : $(cat $STATE_DIR/primary_iface)"
        echo "    Active connections: $(awk -F: '{print $1}' $STATE_DIR/active_connections | tr '\n' ', ')"
    }

    restore_state() {
        echo "=== Network Hard Reset ==="

        echo "[1/7] Killing VPN/proxy processes..."
        sudo pkill -9 -f openvpn  2>/dev/null
        sudo pkill -9 -f sshuttle 2>/dev/null
        sudo pkill -9 -f v2ray    2>/dev/null
        sudo pkill -9 -f xray     2>/dev/null
        sudo pkill -9 -f v2rayA   2>/dev/null
        sleep 1

        echo "[2/7] Removing virtual interfaces..."
        for iface in $(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(tun|tap|wg|vpn)'); do
            echo "  ↳ removing $iface"
            sudo ip link set "$iface" down  2>/dev/null
            sudo ip link delete "$iface"    2>/dev/null
        done

        echo "[3/7] Resetting routing tables..."
        sudo ip route flush table main  2>/dev/null
        sudo ip route flush cache       2>/dev/null
        sudo ip rule flush              2>/dev/null
        sudo ip rule add priority 0     lookup local   2>/dev/null
        sudo ip rule add priority 32766 lookup main    2>/dev/null
        sudo ip rule add priority 32767 lookup default 2>/dev/null

        echo "[4/7] Restarting NetworkManager..."
        sudo systemctl stop NetworkManager
        sleep 2
        sudo systemctl start NetworkManager
        sleep 4

        echo "[5/7] Reconnecting..."
        if [[ -f "$STATE_DIR/active_connections" ]]; then
            while IFS=: read -r name state device; do
                echo "  ↳ bringing up: $name (was on $device)"
                nmcli con up "$name" 2>/dev/null && break
            done < "$STATE_DIR/active_connections"
        else
            echo "  ↳ no saved state, using nmcli networking cycle..."
            nmcli networking off
            sleep 2
            nmcli networking on
        fi
        sleep 3

        echo "[6/7] Checking default route..."
        if ! ip route | grep -q default; then
            echo "  ↳ default route missing, restoring..."
            [[ -f "$STATE_DIR/default_route" ]] && sudo ip route add $(cat "$STATE_DIR/default_route") 2>/dev/null
            PRIMARY=$(cat "$STATE_DIR/primary_iface" 2>/dev/null \
                      || ip -o link show | grep -v lo | awk -F': ' '{print $2}' | head -n1)
            nmcli dev connect "$PRIMARY" 2>/dev/null
        else
            echo "  ↳ default route OK: $(ip route | grep default | head -n1)"
        fi

        echo "[7/7] Resetting DNS..."
        sudo resolvectl flush-caches        2>/dev/null
        sudo systemctl restart systemd-resolved 2>/dev/null
        if [[ -f "$STATE_DIR/resolv.conf.bak" ]]; then
            grep -q "nameserver" /etc/resolv.conf 2>/dev/null || \
                sudo cp "$STATE_DIR/resolv.conf.bak" /etc/resolv.conf
        fi

        echo ""
        echo "=== Testing ==="
        sleep 2
        if ping -c 2 -W 3 8.8.8.8 &>/dev/null; then
            echo "✓ Internet OK"
            echo "  Route : $(ip route | grep default | head -n1)"
            echo "  DNS   : $(resolvectl status 2>/dev/null | grep 'DNS Servers' | head -n1 \
                              || grep nameserver /etc/resolv.conf | head -n1)"
        else
            echo "✗ Still no internet."
            echo "  1. sudo systemctl restart NetworkManager && nmcli networking off && nmcli networking on"
            echo "  2. sudo reboot"
        fi
    }

    status() {
        echo "=== Current Network State ==="
        echo "Default route : $(ip route | grep default | head -n1)"
        echo "Active cons   : $(nmcli -t -f NAME,STATE con show --active | head -n3)"
        echo "DNS           : $(resolvectl status 2>/dev/null | grep 'DNS Servers' | head -n1 \
                                || grep nameserver /etc/resolv.conf | head -n1)"
        echo "Interfaces    : $(ip -o link show up | awk -F': ' '{print $2}' | tr '\n' ' ')"
        echo ""
        [[ -d "$STATE_DIR" ]] \
            && echo "Saved state   : $STATE_DIR (clean state exists)" \
            || echo "Saved state   : none — run 'flush save' while network is clean"
    }

    case "$ACTION" in
        save)    save_state    ;;
        restore) restore_state ;;
        status)  status        ;;
        *)
            echo "Usage: flush save | restore | status"
            echo "  save     — snapshot current working network state"
            echo "  restore  — hard reset network back to saved state"
            echo "  status   — show current network + saved state info"
            ;;
    esac
}

#── FORMAT ────────────────────────────────────────────────

clean_claude() {
  local input="$1"
  local output="${2:-cleaned.txt}"

  if [ -z "$input" ]; then
    echo "Usage: clean_claude <input_file> [output_file]"
    return 1
  fi

  sed -e "s/<[^>]*>//g" \
      -e $'s/\xe2\x80\x98/\'/g' \
      -e $'s/\xe2\x80\x99/\'/g' \
      "$input" > "$output"
}



#── APPS ────────────────────────────────────────────────

# go
# export PATH=$PATH:/usr/local/go/bin
# export PATH=$PATH:~/go/bin

# rust

# Node / NVM
# export NVM_DIR="$HOME/.config/nvm"
# [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
# [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# linuxbrew
# eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"

# Environment
export TERM=xterm-256color

# SSH
# eval `ssh-agent -s`
# ssh-add -k ~/.ssh/fd

# bun completions
# [ -s "/home/m/.bun/_bun" ] && source "/home/m/.bun/_bun"

#── APPS TWEAKS────────────────────────────────────────────────
npm_no_cahe() {
  npm install "$@" --cache /tmp/npm-cache
}

[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# snap
export PATH="$PATH:/var/lib/snapd/snap/bin"

