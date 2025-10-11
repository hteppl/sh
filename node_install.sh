#!/bin/bash

set -e

VERSION="1.9.1"
USER="node_exporter"
BIN_DIR="/usr/local/bin"
SERVICE_FILE="/etc/systemd/system/node_exporter.service"
ARCHIVE="node_exporter-${VERSION}.linux-amd64.tar.gz"
EXTRACT_DIR="node_exporter-${VERSION}.linux-amd64"
DOWNLOAD_URL="https://github.com/prometheus/node_exporter/releases/download/v${VERSION}/${ARCHIVE}"
NODE_EXPORTER_PORT=9100

# Optional flags
UPDATE_SYSTEM=false
ALLOW_IP=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --update)
      UPDATE_SYSTEM=true
      shift
      ;;
    --ufw-allow-ip)
      ALLOW_IP="$2"
      if [[ -z "$ALLOW_IP" ]]; then
        echo "Error: --ufw-allow-ip requires an IP address argument"
        exit 1
      fi
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--update] [--ufw-allow-ip <IP>]"
      exit 1
      ;;
  esac
done

# Colors
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

step() {
  echo -e "\n${GREEN}[$1/10] $2${NC}"
}

# Header
echo -e "\n\033[1;35m✨ Starting Node Exporter $VERSION automated install wizard...\033[0m"

step 1 "Checking if system update is requested"
if [ "$UPDATE_SYSTEM" = true ]; then
  echo -e "${GREEN}Updating system packages...${NC}"
  sudo apt update && sudo apt upgrade -y
else
  echo -e "${GREEN}Skipping system package update.${NC}"
fi

step 2 "Downloading Node Exporter archive"
wget -q "$DOWNLOAD_URL"

step 3 "Extracting archive"
tar -xzf "$ARCHIVE"

step 4 "Installing binary to $BIN_DIR"
cd "$EXTRACT_DIR"
sudo mv node_exporter "$BIN_DIR/"
sudo chmod +x "$BIN_DIR/node_exporter"

step 5 "Creating system user: $USER"
sudo useradd --no-create-home --shell /bin/false "$USER" || echo "User $USER already exists"

step 6 "Creating systemd service file"
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
User=$USER
Group=$USER
Type=simple
ExecStart=$BIN_DIR/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

step 7 "Enabling and starting systemd service"
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter

cd ..

step 8 "Cleaning up temporary files"
rm -rf "$ARCHIVE" "$EXTRACT_DIR"

step 9 "Verifying service status"
sudo systemctl status node_exporter --no-pager || true

step 10 "Configuring firewall (UFW)"
if command -v ufw >/dev/null 2>&1; then
  if sudo ufw status | grep -q "Status: active"; then
    if [[ -n "$ALLOW_IP" ]]; then
      echo -e "${GREEN}UFW is active. Allowing port ${NODE_EXPORTER_PORT}/tcp from ${ALLOW_IP}...${NC}"
      sudo ufw allow from "$ALLOW_IP" to any port "$NODE_EXPORTER_PORT" proto tcp
    else
      echo -e "${YELLOW}UFW is active but no --ufw-allow-ip provided. Skipping port rule.${NC}"
    fi
  else
    echo -e "${YELLOW}UFW is installed but not enabled. Skipping.${NC}"
  fi
else
  echo -e "${YELLOW}UFW not installed. Skipping firewall configuration.${NC}"
fi

ufw status

echo -e "\n\033[1;35m✅ Node Exporter is installed.${NC}"
echo -e "${GREEN}\nCheck status:      ${NC}sudo systemctl status node_exporter --no-pager"
echo -e "${GREEN}Binary path:       ${NC}$BIN_DIR/node_exporter"
echo -e "${GREEN}Service file path: ${NC}$SERVICE_FILE"
echo -e "${GREEN}Port:              ${NC}${NODE_EXPORTER_PORT}"
if [[ -n "$ALLOW_IP" ]]; then
  echo -e "${GREEN}Allowed from IP:   ${NC}${ALLOW_IP}"
fi
echo