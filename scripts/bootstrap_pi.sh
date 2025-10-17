#!/usr/bin/env bash
set -euo pipefail

# HomeHub Raspberry Pi bootstrap script
# - Installs system packages
# - Creates homehub user (if missing)
# - Clones/updates the repo under /home/${HOMEHUB_USER}/OmniHub
# - Sets up Python virtualenv and installs backend deps
# - Installs and enables systemd units for backend
#
# Usage (run as root on a fresh Raspberry Pi OS Lite install):
#   curl -sSL https://raw.githubusercontent.com/AlessioD200/OmniHub/main/scripts/bootstrap_pi.sh | sudo bash
# or copy this file onto the Pi and execute `sudo bash bootstrap_pi.sh`

HOMEHUB_USER=${HOMEHUB_USER:-homehub}
REPO_URL=${REPO_URL:-https://github.com/AlessioD200/OmniHub.git}
REPO_DIR=/home/${HOMEHUB_USER}/OmniHub
BACKEND_DIR="${REPO_DIR}/server"
VENV_DIR="${BACKEND_DIR}/.venv"

log() {
  echo "[bootstrap] $*"
}

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "This script must be run as root (or with sudo)." >&2
    exit 1
  fi
}

create_user_if_needed() {
  if id "${HOMEHUB_USER}" >/dev/null 2>&1; then
    log "User ${HOMEHUB_USER} exists"
    return
  fi
  log "Creating user ${HOMEHUB_USER}"
  adduser --disabled-password --gecos '' "${HOMEHUB_USER}"
}

install_packages() {
  log "Updating apt repositories"
  apt update
  log "Installing required packages"
  DEBIAN_FRONTEND=noninteractive apt install -y \
    git python3-venv python3-pip python3-dev \
    ffmpeg curl jq \
    build-essential libssl-dev libffi-dev
}

clone_repo() {
  if [[ -d "${REPO_DIR}" ]]; then
    log "Repository already exists, fetching latest changes"
    sudo -u "${HOMEHUB_USER}" -H bash -c "cd '${REPO_DIR}' && git fetch --all && git reset --hard origin/main"
  else
    log "Cloning repository"
    sudo -u "${HOMEHUB_USER}" -H git clone "${REPO_URL}" "${REPO_DIR}"
  fi
}

setup_venv() {
  log "Setting up Python virtual environment"
  sudo -u "${HOMEHUB_USER}" -H bash -c "
    cd '${BACKEND_DIR}' && \
    python3 -m venv '${VENV_DIR}' && \
    source '${VENV_DIR}/bin/activate' && \
    pip install --upgrade pip && \
    if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
  " 2>&1
}

install_systemd_units() {
  log "Installing systemd units"
  if [[ -d "${BACKEND_DIR}/systemd" ]]; then
    cp "${BACKEND_DIR}/systemd/homehub.service" /etc/systemd/system/homehub.service || true
    cp "${BACKEND_DIR}/systemd/homehub-agent.service" /etc/systemd/system/homehub-agent.service || true
    systemctl daemon-reload
    systemctl enable --now homehub.service || true
  fi
}

main() {
  require_root
  create_user_if_needed
  install_packages
  clone_repo
  setup_venv
  install_systemd_units
  log "Bootstrap complete. Tail logs with:"
  log "  sudo journalctl -u homehub.service -f"
}

main "$@"
