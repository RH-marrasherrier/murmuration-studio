#!/bin/bash
# Stage the murmuration studio into /tmp and report readiness.
#
# Why /tmp: macOS blocks the app's dev-server process from reading anything
# under ~/Desktop ("Operation not permitted" / "No permission to list
# directory"), so the server and the files it serves have to live outside it.
# This copies the canonical files out; /tmp is cleared on reboot, so re-run
# this before starting the studio again.
#
#   ./studio-setup.sh      then start the "murmuration-studio" server

set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DST=/tmp/murm-studio

mkdir -p "$DST/assets/house-anim/layers"
cp "$SRC/house-animation-murmuration.html" "$DST/"
cp "$SRC/studio-server.py"                 "$DST/"
cp "$SRC/render-gif.sh"                    "$DST/"
cp "$SRC"/assets/house-anim/layers/*.png   "$DST/assets/house-anim/layers/"
chmod +x "$DST/render-gif.sh" "$DST/studio-server.py"

echo "staged $DST"
echo "  layers: $(ls "$DST/assets/house-anim/layers" | wc -l | tr -d ' ') files"
echo
echo "Now start the 'murmuration-studio' server (port 3477)."
echo "Exports land in $DST and are offered as downloads in the page."
