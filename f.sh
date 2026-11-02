#!/usr/bin/env bash
set -e
mkdir -p "$(pwd)/shared"

DOTFILES_URL="https://raw.githubusercontent.com/fadedreams/cfg/refs/heads/main/i.sh"
DESKTOP_IMAGES=(
  "lscr.io/linuxserver/webtop:ubuntu-xfce"
  "ghcr.io/linuxserver/webtop:ubuntu-xfce"
)

echo ">> Free disk space (webtop image needs a few GB):"
df -h / | tail -1

############ 1) Terminal-only (ttyd) on 8006 ############
docker rm -f ubuntu_server 2>/dev/null || true
docker run -d \
  --name ubuntu_server \
  --hostname ubuntu-server \
  --memory="4g" --cpus="2" \
  -p 8006:7681 \
  -v ubuntu_server_data:/root \
  -v "$(pwd)/shared":/shared \
  --restart unless-stopped \
  tsl0922/ttyd \
  ttyd -W -c admin:admin bash

############ 2) XFCE desktop (webtop) on 3000 only ############
docker rm -f ubuntu_desktop 2>/dev/null || true

# Pull the image, falling back to ghcr.io if lscr.io fails
DESKTOP_IMAGE=""
for img in "${DESKTOP_IMAGES[@]}"; do
  echo ">> Pulling $img"
  if docker pull "$img"; then DESKTOP_IMAGE="$img"; break; fi
  echo "!! Pull failed for $img, trying next..."
done
if [ -z "$DESKTOP_IMAGE" ]; then
  echo "!! Could not pull the webtop image. Check network and disk space (df -h /)."
  exit 1
fi

COMMON_ARGS=(
  -d
  --name ubuntu_desktop
  --security-opt seccomp=unconfined
  -p 3000:3000
  -e PUID=1000 -e PGID=1000
  -e TZ="Europe/Amsterdam"
  -e CUSTOM_USER="admin" -e PASSWORD="admin"
  --shm-size="2gb"
  -v ubuntu_desktop_config:/config
  --restart always
)

# First try with resource limits; if the host rejects them, retry without
if ! docker run "${COMMON_ARGS[@]}" --memory="4g" --cpus="2" "$DESKTOP_IMAGE"; then
  echo "!! docker run failed with --memory/--cpus, retrying without limits..."
  docker rm -f ubuntu_desktop 2>/dev/null || true
  docker run "${COMMON_ARGS[@]}" "$DESKTOP_IMAGE"
fi

############ 3) Tools, installed into both (as root) ############
TOOLS_CMD='
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends curl ca-certificates git nmap netcat-openbsd xz-utils jq

# stunnel/static-curl (musl build for this CPU arch). Release tags can look like
# 8.23.0 or 8.23.0-1, so the version part of the filename allows a "-N" suffix.
ARCH=$(uname -m)
URL=$(curl -fsSL https://api.github.com/repos/stunnel/static-curl/releases/latest \
  | jq -r ".assets[].browser_download_url" \
  | grep -E "curl-linux-${ARCH}-musl-[0-9][0-9.]*(-[0-9]+)?\.tar\.xz$" | head -1 || true)
rm -rf /tmp/sc && mkdir -p /tmp/sc
if [ -n "$URL" ] && curl -fsSL "$URL" | tar -xJ -C /tmp/sc; then
  BIN=$(find /tmp/sc -type f -name curl | head -1)
  if [ -n "$BIN" ]; then
    install -m 0755 "$BIN" /usr/local/bin/curl && echo ">> static curl installed: $URL"
  else
    echo "!! static-curl archive had no curl binary; keeping system curl"
  fi
else
  echo "!! static-curl skipped (no matching release asset or download failed); keeping system curl"
fi
rm -rf /tmp/sc
'

for c in ubuntu_server ubuntu_desktop; do
  until docker exec "$c" true 2>/dev/null; do sleep 1; done
  docker exec -u root "$c" bash -c "$TOOLS_CMD"
done

############ 4) Taskbar / panel in XFCE ############
docker exec -u root ubuntu_desktop bash -c '
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y xfce4-panel xfce4-goodies xfce4-whiskermenu-plugin

# Remove stale panel config so XFCE regenerates the default panel
rm -rf /config/.config/xfce4/panel \
       /config/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml

mkdir -p /config/.config/autostart
cat > /config/.config/autostart/xfce4-panel.desktop <<EOF
[Desktop Entry]
Type=Application
Name=XFCE Panel
Exec=sh -c "pgrep xfce4-panel || xfce4-panel"
X-GNOME-Autostart-enabled=true
EOF
chown -R 1000:1000 /config/.config
'

docker restart ubuntu_desktop
until docker exec ubuntu_desktop true 2>/dev/null; do sleep 1; done
sleep 5

############ 5) Dotfiles script (last), on both ############
# i.sh installs tmux/vim/etc with apt, so it needs root (or sudo). The webtop
# user "abc" has no sudo, which is why vim was missing. So run it as root in both
# containers. For the desktop, point HOME at /config (abc's home) so the dotfiles
# land in the right place, then give ownership back to abc.
RUN_DOTFILES="bash <(curl -fsSL $DOTFILES_URL) && source ~/.bashrc"

# ttyd container (root, HOME=/root, persisted in the volume)
docker exec -u root ubuntu_server bash -c "$RUN_DOTFILES" \
  || echo "!! dotfiles step reported an error in ubuntu_server"

# desktop container (root install, HOME=/config, then chown to abc)
docker exec -u root -e HOME=/config ubuntu_desktop bash -c "$RUN_DOTFILES" \
  || echo "!! dotfiles step reported an error in ubuntu_desktop"
docker exec -u root ubuntu_desktop chown -R abc:abc /config || true

echo
echo "Terminal: http://localhost:8006  (admin/admin)"
echo "Desktop:  http://localhost:3000  (admin/admin)"
echo "Run 'source ~/.bashrc' in a new terminal to load the dotfiles changes."
