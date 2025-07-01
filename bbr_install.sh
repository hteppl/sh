#!/bin/bash

set -e

UPDATE_SYSTEM=false

# Parse arguments
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
  echo -e "\n${GREEN}[$1/6] $2${NC}"
}

echo -e "\n\033[1;35m✨ Starting BBR TCP Congestion Control setup wizard...\033[0m"

step 1 "Checking if system update is requested"
if [ "$UPDATE_SYSTEM" = true ]; then
  echo -e "${GREEN}Updating system packages...${NC}"
  sudo apt update && sudo apt upgrade -y
else
  echo -e "${GREEN}Skipping system package update.${NC}"
fi

step 2 "Checking current kernel version"
uname -r

step 3 "Verifying BBR support in kernel"
if lsmod | grep -q bbr; then
  echo -e "${GREEN}BBR module is already loaded.${NC}"
else
  sudo modprobe tcp_bbr
  echo -e "${GREEN}BBR module loaded.${NC}"
fi

step 4 "Enabling BBR in sysctl config"
sudo tee /etc/sysctl.d/99-bbr.conf > /dev/null <<EOF
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF

sudo sysctl --system

step 5 "Validating settings"
sysctl net.ipv4.tcp_congestion_control
sysctl net.core.default_qdisc

if [[ "$(sysctl -n net.ipv4.tcp_congestion_control)" == "bbr" ]]; then
  echo -e "${GREEN}BBR is successfully enabled!${NC}"
else
  echo -e "\033[0;31m❌ Failed to enable BBR. Check your kernel version (needs 4.9+).\033[0m"
  exit 1
fi

step 6 "Ensuring module loads on boot"
echo "tcp_bbr" | sudo tee -a /etc/modules-load.d/bbr.conf > /dev/null

echo -e "\n\033[1;35m✅ BBR TCP congestion control is now enabled!"
echo -e "${GREEN}\nCheck status: ${NC}sysctl net.ipv4.tcp_congestion_control"
echo -e "${GREEN}Verify fq qdisc: ${NC}sysctl net.core.default_qdisc"
echo -e "${GREEN}Check module:   ${NC}lsmod | grep bbr\n"
