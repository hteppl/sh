#!/bin/bash

BASE_DIR="/opt/remnawave"
COMPOSE_FILE="$BASE_DIR/docker-compose.yml"
BACKUP_FILE="$BASE_DIR/docker-compose.yml.old"
CONFIG_DIR="$BASE_DIR/sql_exporter"
SERVICE_NAME="sql_exporter"
IMAGE_NAME="burningalchemist/sql_exporter:latest"
CONFIG_FILE="sql_exporter.yml"
EXTRA_FILE="remnawave_data.collector.yml"

CONFIG_URL="https://raw.githubusercontent.com/hteppl/sh/refs/heads/master/grafana/sql_exporter/sql_exporter.yml"
EXTRA_URL="https://raw.githubusercontent.com/hteppl/sh/refs/heads/master/grafana/sql_exporter/remnawave_data.collector.yml"

# Colors
GREEN='\033[1;32m'
NC='\033[0m'

step() {
  echo -e "\n${GREEN}[$1/4] $2${NC}"
}

echo -e "\n\033[1;35m✨ Starting SQL Exporter Remnawave setup wizard...\033[0m"

if [ ! -f "$COMPOSE_FILE" ]; then
  echo "${GREEN}$COMPOSE_FILE not found.${NC}"
  exit 1
fi

if grep -q "$SERVICE_NAME:" "$COMPOSE_FILE"; then
  echo -e "${GREEN}Service '$SERVICE_NAME' already exists in $COMPOSE_FILE${NC}"
  read -rp "Restart docker compose now? [Y/n]: " answer
  answer=${answer:-Y}
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    cd "$BASE_DIR" || exit 1
    echo -e "${GREEN}Restarting docker compose...${NC}"
    docker compose down && docker compose up -d
    echo -e "${GREEN}Docker compose restarted.${NC}"
  fi
  docker ps
  exit 0
fi

step 1 "Creating backup: $BACKUP_FILE"
cp "$COMPOSE_FILE" "$BACKUP_FILE"

mkdir -p "$CONFIG_DIR"

step 2 "Downloading config files..."
curl -fsSL "$CONFIG_URL" -o "$CONFIG_DIR/$CONFIG_FILE" || { echo "Failed to download $CONFIG_URL"; exit 1; }
curl -fsSL "$EXTRA_URL" -o "$CONFIG_DIR/$EXTRA_FILE" || { echo "Failed to download $EXTRA_URL"; exit 1; }

INSERT_LINE=$(grep -n '^networks:' "$COMPOSE_FILE" | cut -d: -f1)
if [ -z "$INSERT_LINE" ]; then
  echo "'networks' section not found in $COMPOSE_FILE"
  exit 1
fi

step 3 "Inserting sql_exporter service"
DSN="postgresql://\${POSTGRES_USER}:\${POSTGRES_PASSWORD}@remnawave-db:5432/\${POSTGRES_DB}?sslmode=disable"
awk -v insert_line="$INSERT_LINE" -v indent="    " -v svc="$SERVICE_NAME" -v img="$IMAGE_NAME" -v conf_dir="sql_exporter" -v conf_file="$CONFIG_FILE" -v extra_file="$EXTRA_FILE" -v dsn="$DSN" '
NR == insert_line {
  print indent svc ":"
  print indent indent "image: " img
  print indent indent "container_name: sql_exporter"
  print indent indent "restart: always"
  print indent indent "ports:"
  print indent indent indent "- \"9399:9399\""
  print indent indent "env_file:"
  print indent indent indent "- .env"
  print indent indent "volumes:"
  print indent indent indent "- ./" conf_dir "/" conf_file ":/config/sql_exporter.yml"
  print indent indent indent "- ./" conf_dir "/" extra_file ":/config/remnawave_data.collector.yml"
  print indent indent "command:"
  print indent indent indent "- \"--config.file=/config/sql_exporter.yml\""
  print indent indent indent "- \"-config.data-source-name=" dsn "\""
  print indent indent "networks:"
  print indent indent indent "- remnawave-network"
  print indent indent "depends_on:"
  print indent indent indent "remnawave-db:"
  print indent indent indent indent "condition: service_healthy"

  print ""
}
{ print }
' "$COMPOSE_FILE" > "${COMPOSE_FILE}.tmp"

mv "${COMPOSE_FILE}.tmp" "$COMPOSE_FILE"

read -rp "Restart docker compose now? [Y/n]: " answer
answer=${answer:-Y}

if [[ "$answer" =~ ^[Yy]$ ]]; then
  cd "$BASE_DIR" || exit 1
  echo -e "${GREEN}Restarting docker compose...${NC}"
  docker compose down && docker compose up -d
  echo -e "${GREEN}Service added before networks and started.${NC}"
fi

step 4 "Verifying docker status"
docker ps

echo -e "\n\033[1;35m✅ SQL Exporter is installed.${NC}"
echo -e "${GREEN}\nCheck status:      ${NC}docker ps"
echo -e "${GREEN}Restore backup:    ${NC}mv /opt/remnawave/docker-compose.yml.old /opt/remnawave/docker-compose.yml\n"
