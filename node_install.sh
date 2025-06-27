#!/bin/bash

set -e

VERSION="1.9.1"
USER="node_exporter"
BIN_DIR="/usr/local/bin"
SERVICE_FILE="/etc/systemd/system/node_exporter.service"
ARCHIVE="node_exporter-${VERSION}.linux-amd64.tar.gz"
EXTRACT_DIR="node_exporter-${VERSION}.linux-amd64"
DOWNLOAD_URL="https://github.com/prometheus/node_exporter/releases/download/v${VERSION}/${ARCHIVE}"

# Optional flags
UPDATE_SYSTEM=false

# Parse command-line arguments
for arg in "$@"; do
  case $arg in
    --update)
      UPDATE_SYSTEM=true
      shift
      ;;
    *)
      echo "Unknown option: $arg"
      echo "Usage: $0 [--update]"
      exit 1
      ;;
  esac
done

# Colors
GREEN='\033[1;32m'
NC='\033[0m'

step() {
  echo -e "\n${GREEN}[$1/9] $2${NC}"
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
wget "$DOWNLOAD_URL"

step 3 "Extracting archive"
tar -xvzf "$ARCHIVE"

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
sudo systemctl status node_exporter --no-pager

echo -e "\n\033[1;35m✅ Node Exporter is installed.${NC}"
echo -e "${GREEN}\nCheck status:      ${NC}sudo systemctl status node_exporter --no-pager"
echo -e "${GREEN}Binary path:       ${NC}$BIN_DIR/node_exporter"
echo -e "${GREEN}Service file path: ${NC}$SERVICE_FILE\n"