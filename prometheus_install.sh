#!/bin/bash

set -e

VERSION="3.4.1"
USER="prometheus"
BIN_DIR="/usr/local/bin"
CONFIG_DIR="/etc/prometheus"
DATA_DIR="/var/lib/prometheus"
SERVICE_FILE="/etc/systemd/system/prometheus.service"
ARCHIVE="prometheus-${VERSION}.linux-amd64.tar.gz"
EXTRACT_DIR="prometheus-${VERSION}.linux-amd64"
DOWNLOAD_URL="https://github.com/prometheus/prometheus/releases/download/v${VERSION}/${ARCHIVE}"

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

echo -e "\n\033[1;35m✨ Starting Prometheus $VERSION automated install wizard...\033[0m"

step 1 "Checking if system update is requested"
if [ "$UPDATE_SYSTEM" = true ]; then
  echo -e "${GREEN}Updating system packages...${NC}"
  sudo apt update && sudo apt upgrade -y
else
  echo -e "${GREEN}Skipping system package update.${NC}"
fi

step 2 "Downloading Prometheus archive"
wget "$DOWNLOAD_URL"

step 3 "Extracting archive"
tar -xvzf "$ARCHIVE"

step 4 "Installing binaries to $BIN_DIR"
cd "$EXTRACT_DIR"
sudo mv prometheus promtool "$BIN_DIR/"
sudo chmod +x "$BIN_DIR/prometheus" "$BIN_DIR/promtool"

step 5 "Creating Prometheus user and directories"
sudo useradd --no-create-home --shell /bin/false "$USER" || echo "User $USER already exists"
sudo mkdir -p "$CONFIG_DIR" "$DATA_DIR"
sudo chown -R "$USER:$USER" "$CONFIG_DIR" "$DATA_DIR"
sudo mkdir -p "$CONFIG_DIR/rules"
sudo chown -R "$USER:$USER" "$CONFIG_DIR/rules"

step 6 "Copying default configuration"
sudo cp prometheus.yml "$CONFIG_DIR/"
sudo chown -R "$USER:$USER" "$CONFIG_DIR"

step 7 "Creating systemd service file"
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Prometheus Monitoring
Wants=network-online.target
After=network-online.target
[Service]
User=$USER
Group=$USER
Type=simple
ExecStart=$BIN_DIR/prometheus \\
  --config.file=$CONFIG_DIR/prometheus.yml \\
  --storage.tsdb.path=$DATA_DIR \\
  --storage.tsdb.retention.time=60d
Restart=always
[Install]
WantedBy=multi-user.target
EOF

step 8 "Reloading systemd and enabling service"
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus

cd ..

step 9 "Cleaning up temporary files"
rm -rf "$ARCHIVE" "$EXTRACT_DIR"

step 10 "Allowing firewall port 9090 (optional)"
sudo ufw allow 9090/tcp || true

step 11 "Verifying service status"
sudo systemctl status prometheus --no-pager

echo -e "\n\033[1;35m✅ Prometheus is installed!"
echo -e "${GREEN}\nCheck status:      ${NC}sudo systemctl status prometheus --no-pager"
echo -e "${GREEN}Binary path:       ${NC}$BIN_DIR/prometheus"
echo -e "${GREEN}Config path:       ${NC}$CONFIG_DIR/prometheus.yml"
echo -e "${GREEN}Rules path:        ${NC}$CONFIG_DIR/rules"
echo -e "${GREEN}Service file path: ${NC}$SERVICE_FILE\n"