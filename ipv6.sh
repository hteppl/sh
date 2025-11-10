#!/bin/bash

set -e

PURPLE='\033[1;35m'
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m'

CONFIG_FILE="/etc/sysctl.conf"
ACTION="status"

case "${1,,}" in
  on)
    ACTION="enable"
    ;;
  off)
    ACTION="disable"
    ;;
  ""|status)
    ACTION="status"
    ;;
  *)
    echo -e "Usage: $0 [on|off|status]"
    echo -e "  on     - Enable IPv6"
    echo -e "  off    - Disable IPv6"
    echo -e "  status - Show current IPv6 status"
    echo -e "If no argument is provided, current IPv6 status will be shown."
    exit 1
    ;;
esac

step() {
  echo -e "${GREEN}[$1/3] $2${NC}"
}

show_status() {
  if ip a | grep -q inet6; then
    echo -e "\nIPv6 addresses detected:"
    ip a | grep inet6
  else
    echo -e "\nNo IPv6 addresses found."
  fi

  local status
  status=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null || echo "unknown")
  if [ "$status" = "1" ]; then
    echo -e "IPv6: ${RED}Disabled${NC}"
  elif [ "$status" = "0" ]; then
    echo -e "IPv6: ${GREEN}Enabled${NC}"
  else
    echo -e "IPv6 status: ${RED}Unknown${NC}"
  fi
  echo
  echo -e "Usage: $0 [on|off|status]"
  echo -e " on     - Enable IPv6"
  echo -e " off    - Disable IPv6"
  echo -e " status - Show current IPv6 status"
  echo -e "If no argument is provided, current IPv6 status will be shown.\n"
}

disable_ipv6() {
  step 1 "Disabling IPv6 configuration in sysctl"
  sudo sed -i '/^net\.ipv6\.conf\.\(all\|default\|lo\)\.disable_ipv6/d' "$CONFIG_FILE"
  sudo tee -a "$CONFIG_FILE" > /dev/null <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

  step 2 "Applying sysctl configuration"
  sudo sysctl -p > /dev/null

  step 3 "Verifying configuration"
  if [ "$(sysctl -n net.ipv6.conf.all.disable_ipv6)" = "1" ]; then
    echo -e "${GREEN}IPv6 successfully disabled.${NC}"
  else
    echo -e "${RED}Failed to disable IPv6.${NC}"
    exit 1
  fi
}

enable_ipv6() {
  step 1 "Enabling IPv6 configuration in sysctl"
  sudo sed -i '/^net\.ipv6\.conf\.\(all\|default\|lo\)\.disable_ipv6/d' "$CONFIG_FILE"
  sudo tee -a "$CONFIG_FILE" > /dev/null <<EOF
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.lo.disable_ipv6 = 0
EOF

  step 2 "Applying sysctl configuration"
  sudo sysctl -p > /dev/null

  step 3 "Verifying configuration"
  if [ "$(sysctl -n net.ipv6.conf.all.disable_ipv6)" = "0" ]; then
    echo -e "${GREEN}IPv6 successfully enabled.${NC}"
  else
    echo -e "${RED}Failed to enable IPv6.${NC}"
    exit 1
  fi
}

if [ "$ACTION" != "status" ]; then
  echo -e "\n${PURPLE}✨ Starting IPv6 Management Wizard...${NC}"
fi

case "$ACTION" in
  enable)
    enable_ipv6
    ;;
  disable)
    disable_ipv6
    ;;
  status)
    show_status
    ;;
esac
