#!/bin/bash

set -e

VERSION="0.28.1"
USER="alertmanager"
BIN_DIR="/usr/local/bin"
CONFIG_DIR="/etc/alertmanager"
DATA_DIR="/var/lib/alertmanager"
SERVICE_FILE="/etc/systemd/system/alertmanager.service"
ARCHIVE="alertmanager-${VERSION}.linux-amd64.tar.gz"
EXTRACT_DIR="alertmanager-${VERSION}.linux-amd64"
DOWNLOAD_URL="https://github.com/prometheus/alertmanager/releases/download/v${VERSION}/${ARCHIVE}"

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

echo -e "\n\033[1;35m✨ Starting Alertmanager $VERSION automated install wizard...\033[0m"

step 1 "Checking if system update is requested"
if [ "$UPDATE_SYSTEM" = true ]; then
  echo -e "${GREEN}Updating system packages...${NC}"
  sudo apt update && sudo apt upgrade -y
else
  echo -e "${GREEN}Skipping system package update.${NC}"
fi

step 2 "Downloading Alertmanager archive"
wget "$DOWNLOAD_URL"

step 3 "Extracting archive"
tar -xvzf "$ARCHIVE"

step 4 "Installing binaries to $BIN_DIR"
cd "$EXTRACT_DIR"
sudo mv alertmanager amtool "$BIN_DIR/"
sudo chmod +x "$BIN_DIR/alertmanager" "$BIN_DIR/amtool"

step 5 "Creating Alertmanager user and directories"
sudo useradd --no-create-home --shell /bin/false "$USER" || echo "User $USER already exists"
sudo mkdir -p "$CONFIG_DIR" "$DATA_DIR"
sudo chown -R "$USER:$USER" "$CONFIG_DIR" "$DATA_DIR"

step 6 "Copying default configuration"
sudo cp alertmanager.yml "$CONFIG_DIR/" || echo "Default config not found, create manually if needed."
sudo chown -R "$USER:$USER" "$CONFIG_DIR"

step 7 "Creating systemd service file"
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Prometheus Alertmanager
Wants=network-online.target
After=network-online.target

[Service]
User=$USER
Group=$USER
Type=simple
ExecStart=$BIN_DIR/alertmanager \\
  --config.file=$CONFIG_DIR/alertmanager.yml \\
  --storage.path=$DATA_DIR \\
  --cluster.advertise-address=127.0.0.1:9094
Restart=always

[Install]
WantedBy=multi-user.target
EOF

step 8 "Reloading systemd and enabling service"
sudo systemctl daemon-reload
sudo systemctl enable alertmanager
sudo systemctl start alertmanager

cd ..

step 9 "Cleaning up temporary files"
rm -rf "$ARCHIVE" "$EXTRACT_DIR"

step 10 "Allowing firewall port 9093 (optional)"
sudo ufw allow 9093/tcp || true

step 11 "Verifying service status"
sudo systemctl status alertmanager --no-pager

echo -e "\n\033[1;35m✅ Alertmanager is installed!"
echo -e "${GREEN}\nCheck status:      ${NC}sudo systemctl status alertmanager --no-pager"
echo -e "${GREEN}Binary path:       ${NC}$BIN_DIR/alertmanager"
echo -e "${GREEN}Config path:       ${NC}$CONFIG_DIR/alertmanager.yml"
echo -e "${GREEN}Service file path: ${NC}$SERVICE_FILE\n"
