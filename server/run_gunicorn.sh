#!/usr/bin/env bash
# Helper to initialize DB once and exec gunicorn from the virtualenv
set -euo pipefail
ROOT_DIR="/home/homehub/OmniHub/server"
VENV="$ROOT_DIR/.venv"
GUNICORN="$VENV/bin/gunicorn"

cd "$ROOT_DIR"
source "$VENV/bin/activate"

python -c 'from app import init_db; init_db()'

exec "$GUNICORN" --worker-class eventlet -w 1 --bind 0.0.0.0:5000 "app:app"
