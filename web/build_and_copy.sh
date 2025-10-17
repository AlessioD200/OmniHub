#!/usr/bin/env bash
set -euo pipefail
# Resolve script directory to an absolute path so this script works whether run
# directly as the current user or with sudo. This avoids copying into
# ./server/static underneath the web folder.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$SCRIPT_DIR"

echo "Building web app with parcel..."
npm run build

DIST_DIR="$SCRIPT_DIR/dist"
# target is repo_root/server/static
TARGET_DIR="$SCRIPT_DIR/../server/static"

echo "Copying built assets to $TARGET_DIR"
rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"
cp -r "$DIST_DIR"/* "$TARGET_DIR/"

# Ensure files are owned by the homehub user so the service can read them
if id -u homehub >/dev/null 2>&1; then
	chown -R homehub:homehub "$TARGET_DIR" || true
fi

echo "Done. You can now serve the UI from server/static (restart backend if necessary)."
