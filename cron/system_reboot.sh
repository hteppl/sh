#!/bin/bash

set -e

CRON_FILE="/etc/cron.d/system_reboot"
SYSTEMCTL_PATH=$(command -v systemctl)
CRON_CMD="$SYSTEMCTL_PATH reboot"
CRON_SCHEDULE="0 0 */3 * * root $CRON_CMD"

# Optional flags
RELOAD_AFTER_INSTALL=false

# Parse command-line arguments
for arg in "$@"; do
  case $arg in
    --reload)
      RELOAD_AFTER_INSTALL=true
      shift
      ;;
    *)
      echo "Unknown option: $arg"
      echo "Usage: $0 [--reload]"
      exit 1
      ;;
  esac
done

# Colors
GREEN='\033[1;32m'
NC='\033[0m'

step() {
  echo -e "\n${GREEN}[$1/5] $2${NC}"
}

echo -e "\n\033[1;35m✨ Starting 'system_reboot' cron job installer...\033[0m"

step 1 "Removing existing cron job if present"
if [ -f "$CRON_FILE" ]; then
  sudo rm -f "$CRON_FILE"
else
  echo -e "${GREEN}No existing cron job found, skipping removal.${NC}"
fi

step 2 "Creating new cron job file"
{
  echo "# system_reboot cron job"
  echo "$CRON_SCHEDULE"
  echo ""  # Ensure newline at end of file
} | sudo tee "$CRON_FILE" > /dev/null
sudo chmod 644 "$CRON_FILE"

step 3 "Setting permissions"
echo -e "${GREEN}Permissions set to 644 for $CRON_FILE${NC}"

step 4 "Reloading cron service (optional)"
if [ "$RELOAD_AFTER_INSTALL" = true ]; then
  service cron reload
  echo -e "${GREEN}✅ Cron service reloaded.${NC}"
else
  echo -e "\033[1;33mSkipped cron reload. Use 'sudo systemctl reload cron' to apply changes.${NC}"
fi

step 5 "Verifying cron job installation"
echo -e "${GREEN}Installed cron job contents:${NC}"
cat "$CRON_FILE"

echo -e "\n\033[1;35m✅ 'system_reboot' cron job installed successfully!${NC}"
echo -e "${GREEN}Runs every 3 days at 00:00 with the following command:${NC}"
echo -e "${CRON_CMD}\n"