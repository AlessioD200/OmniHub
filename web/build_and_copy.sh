#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(dirname "$0")
cd "$ROOT_DIR"

echo "Building web app with parcel..."
npm run build

DIST_DIR="$ROOT_DIR/dist"
TARGET_DIR="$(dirname "$ROOT_DIR")/server/static"

echo "Copying built assets to $TARGET_DIR"
rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"
cp -r "$DIST_DIR"/* "$TARGET_DIR/"

echo "Done. You can now serve the UI from server/static (restart backend if necessary)."
