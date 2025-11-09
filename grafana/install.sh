#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_PATH=""
DOMAIN=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script MUST be run as root"
        print_error "Please run: sudo $0"
        exit 1
    fi
}

gather_user_inputs() {
    read -p "Enter installation path [default: /opt/grafana]: " user_path
    INSTALL_PATH="${user_path:-/opt/grafana}"

    read -p "Enter domain name without https:// for Grafana (example: domain.com): " user_domain
    DOMAIN="${user_domain}"

    echo ""
    echo "  Installation Path: $INSTALL_PATH"
    echo "  Domain: $DOMAIN"
    echo ""

    read -p "Continue with these settings? [Y/n]: " confirm
    if [[ $confirm =~ ^[Nn]$ ]]; then
        exit 0
    fi
}

create_directories() {
    mkdir -p "$INSTALL_PATH"
    cd "$INSTALL_PATH" || {
        print_error "Failed to change to directory $INSTALL_PATH"
        exit 1
    }

    mkdir -p {prometheus,grafana,blackbox,xray-checker,caddy}/data
    mkdir -p caddy/logs

    chown -R 472:472 grafana/data 2>/dev/null || true
    chown -R 65534:65534 prometheus/data 2>/dev/null || true
    chmod -R 755 {prometheus,blackbox,xray-checker,caddy}/data caddy/logs 2>/dev/null || true
}

create_prometheus_config() {
    if [ ! -f "prometheus/prometheus.yml" ]; then
        cat > prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'blackbox'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
        - https://google.com
        - https://github.com
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox_exporter:9115

  - job_name: 'xray-checker'
    static_configs:
      - targets: ['xray-checker:8080']
EOF
    fi
}

create_grafana_config() {
    if [ ! -f "grafana/grafana.ini" ]; then
        cat > grafana/grafana.ini << EOF
[server]
protocol = http
http_port = 3000
domain = ${DOMAIN}
root_url = https://${DOMAIN}
enforce_domain = true

[security]
admin_user = admin
admin_password = admin

[auth.anonymous]
enabled = false

[analytics]
reporting_enabled = false
check_for_updates = false

[log]
mode = console
level = info
EOF
    fi
}

create_blackbox_config() {
    if [ ! -f "blackbox/blackbox.yml" ]; then
        cat > blackbox/blackbox.yml << 'EOF'
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      valid_http_versions: ["HTTP/1.1", "HTTP/2.0"]
      valid_status_codes: []
      method: GET
      preferred_ip_protocol: "ip4"

  http_post_2xx:
    prober: http
    timeout: 5s
    http:
      method: POST

  tcp_connect:
    prober: tcp
    timeout: 5s

  icmp:
    prober: icmp
    timeout: 5s
    icmp:
      preferred_ip_protocol: "ip4"
EOF
    fi
}

create_caddy_config() {
    if [ ! -f "caddy/Caddyfile" ]; then
      cat > caddy/Caddyfile << EOF
${DOMAIN} {
	@websockets {
		header Connection *Upgrade*
		header Upgrade websocket
	}
	reverse_proxy @websockets grafana:3000
	reverse_proxy grafana:3000
}
EOF
    fi
}

create_env_file() {
    if [ ! -f ".env" ]; then
        cat > .env << EOF
XRAY_SUBSCRIPTION_URL=https://example.com/sub
EOF
    fi
}

install_docker() {
    if command -v docker &> /dev/null && command -v docker compose &> /dev/null; then
        return
    fi

    print_info "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl start docker
    systemctl enable docker
}

copy_docker_compose() {
    cp "$SCRIPT_DIR/docker-compose.yml" .
}

start_services() {
    print_info "Pulling Docker images..."
    docker compose pull
    print_info "Starting services..."
    docker compose up -d
}

show_status() {
    echo ""
    print_success "Installation completed!"
    echo ""
    print_info "Installation Summary:"
    echo "  Path: $INSTALL_PATH"
    echo "  Domain: $DOMAIN"
    echo ""

    docker compose ps

    echo ""
    echo -e "  ${GREEN}Grafana:${NC} https://$DOMAIN"
    echo -e "  ${GREEN}Username:${NC} admin"
    echo -e "  ${GREEN}Password:${NC} admin"
    echo ""
}

main() {
    check_root
    gather_user_inputs
    create_directories
    create_prometheus_config
    create_grafana_config
    create_blackbox_config
    create_caddy_config
    create_env_file
    copy_docker_compose
    install_docker
    start_services
    show_status
}

main
