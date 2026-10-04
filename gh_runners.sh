#!/usr/bin/env bash
set -euo pipefail

COUNT=""
URL=""
TOKEN="${RUNNER_TOKEN:-}"
PREFIX="$(hostname -s)"
LABELS=""
GROUP=""
RUNNER_USER="runner"
BASE_DIR=""
VERSION=""
TARBALL=""
SKIP_DEPS=0
MODE="install"

log()  { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: $0 -n COUNT -u URL [-t TOKEN] [options]
       $0 --remove -u URL [-t TOKEN] [options]

Required:
  -n, --count N         number of instances (1..N)
  -u, --url URL         https://github.com/<org> or https://github.com/<org>/<repo>
  -t, --token TOKEN     registration token (or RUNNER_TOKEN env variable)

Optional:
  -p, --prefix NAME     runner name prefix (default: hostname) -> NAME-1, NAME-2, ...
  -l, --labels LIST     extra comma-separated labels, e.g. docker,heavy
  -g, --group NAME      runner group (org/enterprise only)
      --user NAME       system user for runners (default: runner)
      --dir PATH        base directory (default: user's home directory)
      --version X.Y.Z   runner version (default: latest release)
      --tarball PATH    use a local archive instead of downloading
      --skip-deps       do not run installdependencies.sh
      --remove          stop, uninstall services and unregister all instances
  -h, --help            show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--count)   COUNT="$2"; shift 2 ;;
    -u|--url)     URL="$2"; shift 2 ;;
    -t|--token)   TOKEN="$2"; shift 2 ;;
    -p|--prefix)  PREFIX="$2"; shift 2 ;;
    -l|--labels)  LABELS="$2"; shift 2 ;;
    -g|--group)   GROUP="$2"; shift 2 ;;
    --user)       RUNNER_USER="$2"; shift 2 ;;
    --dir)        BASE_DIR="$2"; shift 2 ;;
    --version)    VERSION="${2#v}"; shift 2 ;;
    --tarball)    TARBALL="$2"; shift 2 ;;
    --skip-deps)  SKIP_DEPS=1; shift ;;
    --remove)     MODE="remove"; shift ;;
    -h|--help)    usage; exit 0 ;;
    *)            usage; die "Unknown argument: $1" ;;
  esac
done

[[ $EUID -eq 0 ]] || die "Must be run as root: the script creates a user and systemd services."
[[ -n "$URL" ]]   || { usage; die "--url is required"; }
[[ -n "$TOKEN" ]] || { usage; die "--token (or RUNNER_TOKEN) is required"; }

if ! id "$RUNNER_USER" &>/dev/null; then
  [[ "$MODE" == "install" ]] || die "User $RUNNER_USER does not exist"
  log "Creating user $RUNNER_USER"
  useradd -m -s /bin/bash "$RUNNER_USER"
fi
USER_HOME="$(getent passwd "$RUNNER_USER" | cut -d: -f6)"
BASE_DIR="${BASE_DIR:-$USER_HOME}"

as_runner() {
  local dir="$1"; shift
  ( cd "$dir" && runuser -u "$RUNNER_USER" -- env HOME="$USER_HOME" "$@" )
}

if [[ "$MODE" == "remove" ]]; then
  shopt -s nullglob
  dirs=( "$BASE_DIR"/actions-runner-[0-9]* )
  [[ ${#dirs[@]} -gt 0 ]] || die "No actions-runner-N instances found in $BASE_DIR"
  for dir in "${dirs[@]}"; do
    log "Removing $dir"
    if [[ -f "$dir/.service" ]]; then
      ( cd "$dir" && ./svc.sh stop || true; ./svc.sh uninstall || true )
    fi
    if [[ -f "$dir/.runner" ]]; then
      as_runner "$dir" ./config.sh remove --token "$TOKEN" \
        || warn "Failed to unregister $dir (remove the runner manually in GitHub settings)"
    fi
    rm -rf "$dir"
  done
  log "Done."
  exit 0
fi

[[ "$COUNT" =~ ^[1-9][0-9]*$ ]] || { usage; die "--count must be an integer >= 1"; }

case "$(uname -m)" in
  x86_64)        ARCH="x64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7l)        ARCH="arm" ;;
  *)             die "Unsupported architecture: $(uname -m)" ;;
esac

# git (actions/checkout clones without .git otherwise), tar/gzip/unzip (tool cache, artifacts), curl
REQUIRED_CMDS=( git curl tar gzip unzip )
missing=()
for cmd in "${REQUIRED_CMDS[@]}"; do
  command -v "$cmd" >/dev/null || missing+=( "$cmd" )
done
if [[ ${#missing[@]} -gt 0 ]]; then
  log "Installing missing packages: ${missing[*]}"
  pkgs=( "${missing[@]}" ca-certificates )
  if command -v apt-get >/dev/null; then
    apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${pkgs[@]}"
  elif command -v dnf >/dev/null; then
    dnf install -y -q "${pkgs[@]}"
  elif command -v yum >/dev/null; then
    yum install -y -q "${pkgs[@]}"
  elif command -v zypper >/dev/null; then
    zypper --non-interactive install "${pkgs[@]}"
  elif command -v apk >/dev/null; then
    apk add --no-cache "${pkgs[@]}"
  else
    die "Missing ${missing[*]} and no supported package manager found, install them manually"
  fi
  for cmd in "${missing[@]}"; do
    command -v "$cmd" >/dev/null || die "Failed to install $cmd"
  done
fi

if [[ -z "$TARBALL" ]]; then
  if [[ -z "$VERSION" ]]; then
    log "Detecting latest runner version"
    release="$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest)" \
      || die "Failed to query GitHub API, use --version"
    VERSION="$(sed -nE 's/.*"tag_name": *"v?([^"]+)".*/\1/p' <<<"$release" | head -n1)"
    [[ -n "$VERSION" ]] || die "Failed to detect version, use --version"
  fi
  CACHE_DIR="$BASE_DIR/.runner-cache"
  mkdir -p "$CACHE_DIR"
  TARBALL="$CACHE_DIR/actions-runner-linux-$ARCH-$VERSION.tar.gz"
  if [[ ! -s "$TARBALL" ]]; then
    log "Downloading runner v$VERSION ($ARCH)"
    curl -fL -o "$TARBALL.part" \
      "https://github.com/actions/runner/releases/download/v$VERSION/actions-runner-linux-$ARCH-$VERSION.tar.gz"
    mv "$TARBALL.part" "$TARBALL"
  fi
  chown -R "$RUNNER_USER:$RUNNER_USER" "$CACHE_DIR"
fi
[[ -f "$TARBALL" ]] || die "Archive not found: $TARBALL"

deps_done=$SKIP_DEPS
created=0; skipped=0

for i in $(seq 1 "$COUNT"); do
  name="${PREFIX}-${i}"
  dir="$BASE_DIR/actions-runner-$i"

  if [[ -f "$dir/.runner" ]]; then
    log "[$name] already configured, skipping"
    skipped=$((skipped + 1))
    continue
  fi

  log "[$name] extracting to $dir"
  rm -rf "$dir"
  mkdir -p "$dir"
  tar xzf "$TARBALL" -C "$dir"
  chown -R "$RUNNER_USER:$RUNNER_USER" "$dir"

  if [[ $deps_done -eq 0 ]]; then
    log "Installing runner system dependencies (once)"
    "$dir/bin/installdependencies.sh" || warn "installdependencies.sh failed, continuing"
    deps_done=1
  fi

  cfg=( --unattended --replace --url "$URL" --token "$TOKEN" --name "$name" --work _work )
  [[ -n "$LABELS" ]] && cfg+=( --labels "$LABELS" )
  [[ -n "$GROUP"  ]] && cfg+=( --runnergroup "$GROUP" )

  log "[$name] registering at $URL"
  as_runner "$dir" ./config.sh "${cfg[@]}"

  log "[$name] installing and starting service"
  ( cd "$dir" && ./svc.sh install "$RUNNER_USER" && ./svc.sh start )

  created=$((created + 1))
done

if [[ $deps_done -eq 0 ]]; then
  log "Installing runner system dependencies"
  "$BASE_DIR/actions-runner-1/bin/installdependencies.sh" || warn "installdependencies.sh failed, continuing"
fi

log "Done: $created created, $skipped skipped."
log "Service status: systemctl list-units 'actions.runner.*'"
