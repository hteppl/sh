#!/bin/bash

set -e

CRON_FILE="/etc/cron.d/journal_cleaner"
JOURNALCTL_PATH=$(command -v journalctl)
APT_PATH=$(command -v apt)
CRON_CMD="$JOURNALCTL_PATH --vacuum-time=1s && $APT_PATH clean && $APT_PATH autoremove -y"

CRON_SCHEDULE="0 0 * * * root $CRON_CMD"

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

echo -e "\n\033[1;35m✨ Starting 'journal_cleaner' cron job installer...\033[0m"

step 1 "Removing existing cron job if present"
if [ -f "$CRON_FILE" ]; then
  sudo rm -f "$CRON_FILE"
else
  echo -e "${GREEN}No existing cron job found, skipping removal.${NC}"
fi

step 2 "Creating new cron job file"
{
  echo "# journal_cleaner cron job"
  echo "$CRON_SCHEDULE"
  echo ""  # Ensures newline at end of file
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

echo -e "\n\033[1;35m✅ 'journal_cleaner' cron job installed successfully!${NC}"
echo -e "${GREEN}Runs daily at 00:00 with the following command:${NC}"
echo -e "${CRON_CMD}\n"