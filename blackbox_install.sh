#!/bin/bash

set -e

VERSION="0.26.0"
USER="blackbox_exporter"
BIN_DIR="/usr/local/bin"
CONFIG_DIR="/etc/blackbox_exporter"
SERVICE_FILE="/etc/systemd/system/blackbox_exporter.service"
ARCHIVE="blackbox_exporter-${VERSION}.linux-amd64.tar.gz"
EXTRACT_DIR="blackbox_exporter-${VERSION}.linux-amd64"
DOWNLOAD_URL="https://github.com/prometheus/blackbox_exporter/releases/download/v${VERSION}/${ARCHIVE}"

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
  echo -e "\n${GREEN}[$1/11] $2${NC}"
}

# Header
echo -e "\n\033[1;35m✨ Starting Blackbox Exporter $VERSION automated install wizard...\033[0m"

step 1 "Checking if system update is requested"
if [ "$UPDATE_SYSTEM" = true ]; then
  echo -e "${GREEN}Updating system packages...${NC}"
  sudo apt update && sudo apt upgrade -y
else
  echo -e "${GREEN}Skipping system package update.${NC}"
fi

step 2 "Downloading Blackbox Exporter archive"
wget "$DOWNLOAD_URL"

step 3 "Extracting archive"
tar -xvzf "$ARCHIVE"

step 4 "Installing binary to $BIN_DIR"
cd "$EXTRACT_DIR"
sudo mv blackbox_exporter "$BIN_DIR/"
sudo chmod +x "$BIN_DIR/blackbox_exporter"

step 5 "Creating system user: $USER"
sudo useradd --no-create-home --shell /bin/false "$USER" || echo "User $USER already exists"

step 6 "Creating configuration directory"
sudo mkdir -p "$CONFIG_DIR"

step 7 "Moving bundled config to $CONFIG_DIR/config.yml"
sudo mv blackbox.yml "$CONFIG_DIR/config.yml"
sudo chown -R $USER:$USER "$CONFIG_DIR"

step 8 "Creating systemd service file"
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Prometheus Blackbox Exporter
After=network.target
[Service]
User=$USER
Group=$USER
Type=simple
ExecStart=$BIN_DIR/blackbox_exporter --config.file=$CONFIG_DIR/config.yml
Restart=always
[Install]
WantedBy=multi-user.target
EOF

step 9 "Enabling and starting systemd service"
sudo systemctl daemon-reload
sudo systemctl enable blackbox_exporter
sudo systemctl start blackbox_exporter

cd ..

step 10 "Cleaning up temporary files"
rm -rf "$ARCHIVE" "$EXTRACT_DIR"

step 11 "Verifying service status"
sudo systemctl status blackbox_exporter --no-pager

echo -e "\n\033[1;35m✅ Blackbox Exporter is installed!"
echo -e "${GREEN}\nCheck status:      ${NC}sudo systemctl status blackbox_exporter --no-pager"
echo -e "${GREEN}Binary path:       ${NC}$BIN_DIR/blackbox_exporter"
echo -e "${GREEN}Config path:       ${NC}$CONFIG_DIR/config.yml"
echo -e "${GREEN}Service file path: ${NC}$SERVICE_FILE\n"