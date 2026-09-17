#!/bin/bash
# Render an animation HTML to a GIF.
#
#   ./render-gif.sh arc-animation.html arc.gif
#
# The HTML must accept ?t=<0..1> and draw exactly one deterministic frame.
# Override any of these inline:  FPS=30 DUR=4 ./render-gif.sh ...

set -euo pipefail

HTML="${1:-arc-animation.html}"
OUT="${2:-out.gif}"
W="${W:-724}"          # CSS pixel width of the stage
H="${H:-772}"          # CSS pixel height
FPS="${FPS:-25}"
DUR="${DUR:-2.8}"      # seconds of GIF playback
SCALE="${SCALE:-2}"    # capture device scale factor
LOOP="${LOOP:-0}"      # 0 = loop forever
BG="${BG:-}"           # empty = use the HTML default; "none" = transparent;
                       # or any CSS color, e.g. BG='#ffffff'
# Final pixel width. Defaults to the full captured resolution (W*SCALE) —
# downscaling thin strokes throws away detail for no benefit, so only set
# this when you specifically need smaller output. Height follows the ratio.
OUT_W="${OUT_W:-$((W * SCALE))}"

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
DIR="$(cd "$(dirname "$0")" && pwd)"

# FRAMES_DIR keeps the captured PNGs so several encodes can share one capture
# (a 240-frame 1080p capture takes minutes — never pay for it twice). If the
# directory already holds the right number of frames, capture is skipped.
if [ -n "${FRAMES_DIR:-}" ]; then
  TMP="$FRAMES_DIR"; mkdir -p "$TMP"
else
  TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fi

FRAMES=$(python3 -c "print(round($FPS*$DUR))")

# URL-encode the '#' in a hex color, or it becomes a URL fragment
QBG=""
[ -n "$BG" ] && QBG="&bg=$(printf '%s' "$BG" | sed 's/#/%23/')"

# Extra query params appended to every frame URL, e.g.
#   URLEXTRA='&from=4.0&to=8.7'   to render one slice of a longer timeline
QBG="$QBG${URLEXTRA:-}"

HAVE=$(ls "$TMP" 2>/dev/null | grep -c '\.png$' || true)
if [ "$HAVE" -eq "$FRAMES" ]; then
  echo "Reusing $FRAMES captured frames in $TMP"
else
  echo "Rendering $FRAMES frames at ${W}x${H} (capture ${SCALE}x, bg=${BG:-html default})..."
  for i in $(seq 0 $((FRAMES - 1))); do
    T=$(python3 -c "print($i/$FRAMES)")
    "$CHROME" --headless --disable-gpu --hide-scrollbars --no-first-run \
      --force-device-scale-factor="$SCALE" \
      --window-size="$W,$H" \
      --virtual-time-budget=1500 \
      --default-background-color=00000000 \
      --screenshot="$TMP/$(printf '%04d' "$i").png" \
      "file://$DIR/$HTML?t=$T$QBG" >/dev/null 2>&1
    printf '\r  frame %d/%d' "$((i + 1))" "$FRAMES"
  done
  echo
fi

OUT_H=$(python3 -c "print(round($OUT_W*$H/$W))")

# ---- MP4 branch: no palette limit, so no dither question at all. Much
# smaller than GIF at this resolution, and holds full colour fidelity.
if [ "${OUT##*.}" = "mp4" ]; then
  # even dimensions are required by yuv420p; crf 16 keeps the small saturated
  # dots clean despite 4:2:0 chroma subsampling
  EW=$(python3 -c "print($OUT_W - $OUT_W % 2)")
  EH=$(python3 -c "print($OUT_H - $OUT_H % 2)")
  echo "Encoding MP4 at ${EW}x${EH}..."
  ffmpeg -y -framerate "$FPS" -i "$TMP/%04d.png" \
    -vf "scale=$EW:$EH:flags=lanczos" \
    -c:v libx264 -preset slow -crf 16 -pix_fmt yuv420p \
    -movflags +faststart "$DIR/$OUT" 2>/dev/null
  echo "Wrote $DIR/$OUT ($(du -h "$DIR/$OUT" | cut -f1))"
  exit 0
fi

echo "Assembling GIF at ${OUT_W}x${OUT_H}..."

# NEVER dither this kind of artwork. Flat vector frames use only a couple of
# hundred distinct colors, so they fit inside the 256-color table losslessly
# and there is nothing for a dither pattern to approximate — it just sprays
# noise across the flat background. Measured on the arc animation:
# bayer = RMSE 3.54, dither=none = RMSE 0.08, and the file is smaller too.
SCALE_F="scale=$OUT_W:$OUT_H:flags=lanczos"
[ "$OUT_W" = "$((W * SCALE))" ] && SCALE_F="null"   # no resample at all

if [ "$BG" = "none" ]; then
  # GIF alpha is 1-bit: reserve a palette slot for transparency and cut every
  # pixel below the threshold. Partial coverage cannot survive, so edges are
  # harder than on a solid background — rendering large helps a lot.
  ffmpeg -y -framerate "$FPS" -i "$TMP/%04d.png" \
    -filter_complex "[0:v]$SCALE_F,split[a][b];\
[a]palettegen=stats_mode=full:reserve_transparent=1:max_colors=255[p];\
[b][p]paletteuse=dither=none:alpha_threshold=96" \
    -gifflags -offsetting -loop "$LOOP" "$DIR/$OUT" 2>/dev/null
else
  ffmpeg -y -framerate "$FPS" -i "$TMP/%04d.png" \
    -filter_complex "[0:v]$SCALE_F,split[a][b];\
[a]palettegen=stats_mode=full:max_colors=256[p];\
[b][p]paletteuse=dither=none" \
    -loop "$LOOP" "$DIR/$OUT" 2>/dev/null
fi

echo "Wrote $DIR/$OUT ($(du -h "$DIR/$OUT" | cut -f1))"
