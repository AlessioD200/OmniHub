#!/usr/bin/env bash
set -euo pipefail

print_usage(){
  cat <<EOF
Usage: $0 [--host user@host] [--path /remote/repo/path] [--branch BRANCH] [--service SYSTEMD_SERVICE]

Environment variables supported as defaults:
  RPI_HOST      SSH destination (user@host)
  RPI_PATH      Remote repository path
  RPI_BRANCH    Branch name to deploy (default: current branch)
  RPI_SERVICE   (optional) systemd service name to restart on remote

Examples:
  RPI_HOST=pi@raspberry.local RPI_PATH=/home/pi/OmniHub RPI_SERVICE=homehub.service ./scripts/deploy_to_rpi.sh
  ./scripts/deploy_to_rpi.sh --host pi@raspberry.local --path /home/pi/OmniHub --branch main --service homehub.service
EOF
}

# parse args
HOST="${RPI_HOST:-}"
PATH_REMOTE="${RPI_PATH:-}"
BRANCH="${RPI_BRANCH:-}"
SERVICE="${RPI_SERVICE:-}"

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --host) HOST="$2"; shift 2;;
    --path) PATH_REMOTE="$2"; shift 2;;
    --branch) BRANCH="$2"; shift 2;;
    --service) SERVICE="$2"; shift 2;;
    -h|--help) print_usage; exit 0;;
    *) echo "Unknown arg: $1"; print_usage; exit 2;;
  esac
done

if [ -z "$HOST" ] || [ -z "$PATH_REMOTE" ]; then
  echo "Error: host and path are required. See usage." >&2
  print_usage
  exit 2
fi

# determine current branch if not provided
if [ -z "$BRANCH" ]; then
  BRANCH=$(git rev-parse --abbrev-ref HEAD)
fi

echo "Deploying branch '$BRANCH' to $HOST:$PATH_REMOTE"

echo "-> Pushing local commits to origin/$BRANCH..."
git push origin "$BRANCH"

echo "-> Running remote update..."

# Pass remote variables into the remote shell and run a script there
ssh "$HOST" "RPI_PATH='$PATH_REMOTE' RPI_BRANCH='$BRANCH' RPI_SERVICE='$SERVICE' bash -s" <<'REMOTE_SCRIPT'
set -e

echo "Remote: change to path $RPI_PATH"
cd "$RPI_PATH" || { echo "Remote path not found: $RPI_PATH"; exit 2; }

if [ ! -d .git ]; then
  echo "Not a git repository at $RPI_PATH"; exit 3
fi

echo "Remote: fetch and reset to origin/$RPI_BRANCH"
git fetch --all --prune
git reset --hard "origin/$RPI_BRANCH"

if [ -f requirements.txt ]; then
  echo "Remote: requirements.txt found — ensuring virtualenv and installing deps"
  if [ ! -d .venv ]; then
    python3 -m venv .venv
  fi
  # shellcheck disable=SC1091
  . .venv/bin/activate
  pip install --upgrade pip
  pip install -r requirements.txt
fi

if [ -f docker-compose.yml ] || [ -f docker-compose.yaml ]; then
  echo "Remote: docker compose file present — pulling and restarting containers"
  if command -v docker >/dev/null 2>&1; then
    docker compose pull || true
    docker compose up -d --build
  else
    echo "Remote: docker not installed; skipping docker steps"
  fi
fi

if [ -n "$RPI_SERVICE" ]; then
  echo "Remote: restarting systemd service: $RPI_SERVICE"
  sudo systemctl daemon-reload || true
  sudo systemctl restart "$RPI_SERVICE"
  sudo systemctl status "$RPI_SERVICE" --no-pager || true
fi

echo "Remote: done"
REMOTE_SCRIPT

echo "Deploy completed."
