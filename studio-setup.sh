#!/bin/bash
# Stage the animation studios into /tmp and report readiness.
#
# Why /tmp: macOS blocks the app's dev-server process from reading anything
# under ~/Desktop ("Operation not permitted" / "No permission to list
# directory"), so the server and the files it serves have to live outside it.
# /tmp is cleared on reboot, so re-run this before starting the studio again.
#
#   ./studio-setup.sh      then start the "murmuration-studio" server (port 3477)
#
# Serves both studios:
#   /house-animation-glow.html          the drawn circuit
#   /house-animation-murmuration.html   the particle swarm

set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DST=/tmp/murm-studio

mkdir -p "$DST/assets/house-anim/layers"
for f in house-animation-glow.html house-animation-murmuration.html \
         studio-server.py render-gif.sh; do
  cp "$SRC/$f" "$DST/"
done
cp "$SRC"/assets/house-anim/layers/*.png "$DST/assets/house-anim/layers/"
chmod +x "$DST/render-gif.sh" "$DST/studio-server.py"

echo "staged $DST"
echo "  studios: glow, murmuration"
echo "  layers:  $(ls "$DST/assets/house-anim/layers" | wc -l | tr -d ' ') files"
echo
echo "Now start the 'murmuration-studio' server, then open http://127.0.0.1:3477/"
echo "Exports land in $DST and are offered as downloads in the page."
