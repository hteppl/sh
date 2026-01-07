#!/bin/bash

set -e

GREEN='\033[1;32m'
PURPLE='\033[1;35m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

step() {
  echo -e "\n${GREEN}[$1/5] $2${NC}"
}

echo -e "\n${PURPLE}✨ Starting fail2ban installation and configuration wizard...${NC}"

step 1 "Updating package list"
apt update

step 2 "Installing fail2ban"
apt install -y fail2ban

step 3 "Creating jail.local configuration"
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = -1
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
bantime = -1
maxretry = 1
EOF

echo -e "${GREEN}Configuration file created at /etc/fail2ban/jail.local${NC}"

step 4 "Restarting and enabling fail2ban service"
systemctl restart fail2ban
systemctl enable fail2ban

step 5 "Verifying installation"
systemctl status fail2ban --no-pager | head -n 10

echo -e "\n${GREEN}Checking sshd jail status:${NC}"
fail2ban-client status sshd

echo -e "\n${PURPLE}✅ fail2ban is now configured and running!"
echo -e "${YELLOW}⚠️  WARNING: With maxretry=1 and permanent ban, one wrong password = permanent block!"
echo -e "${GREEN}\nUseful commands:"
echo -e "  Check status:    ${NC}fail2ban-client status sshd"
echo -e "${GREEN}  Unban an IP:     ${NC}fail2ban-client set sshd unbanip <IP>"
echo -e "${GREEN}  Check banned:    ${NC}fail2ban-client status sshd"
echo -e "${GREEN}  View logs:       ${NC}tail -f /var/log/fail2ban.log\n"