# Renew Home — house build animation, web handoff

Two pieces that play back to back:

| file | covers | duration |
|---|---|---|
| `house-build.json` | the build-up: devices arrive, then the house opens | 0 – 5.16s (129 frames @ 25fps) |
| `energy.mp4` / `energy.webm` | the arches drawing in and the energy pulsing | 5.125 – 11.725s (165 frames @ 25fps) |

`reference-full.mp4` is the whole thing in one piece — use it to check the
integration looks right, not as the deliverable.

Both pieces are authored at **1990 × 2090** (2× a 995 × 1045 layout) and share
the same frame, so they overlay exactly. Scale both to the same CSS size.

## Important: the background must be #121416

This is not a style preference. The house's interior fills are painted in the
background colour so that roof planes correctly hide what is behind them —
there is no alpha channel that could do that job. On any other background the
fills will read as the wrong colour.

If the site background changes, both pieces need re-exporting. `studio.html`
(included) has a Background field that does it; see "Re-exporting" below.

## Integrating

```html
<div id="house" style="position:relative;width:995px;background:#121416">
  <div id="lottie"></div>
  <video id="energy" src="energy.mp4" muted playsinline preload="auto"
         style="position:absolute;inset:0;width:100%;display:none"></video>
</div>
```

```js
const anim = lottie.loadAnimation({
  container: document.getElementById("lottie"),
  renderer: "svg",          // svg scales cleanly; canvas is faster on mobile
  loop: false, autoplay: false,
  path: "house-build.json"
});

const video = document.getElementById("energy");

// hand over on the Lottie's last frame
anim.addEventListener("complete", () => {
  video.style.display = "block";
  video.currentTime = 0;
  video.play();
});

// drive it from scroll, or just call anim.play() when it enters the viewport
anim.play();
```

The video's first frame is the Lottie's last frame — measured at RMSE 2.87,
i.e. identical bar video compression — so the cut is invisible. Keep the Lottie
visible underneath rather than removing it; the video's first frame covers it.

For a scroll-driven version, `anim.goToAndStop(progress * anim.totalFrames,
true)` for the build-up, then switch to setting `video.currentTime` once past
it. Note Safari throttles `currentTime` scrubbing on mobile — if scroll-scrub
has to work on iOS, ask and I will supply the energy phase as frames instead.

## What is in the Lottie

Twelve image layers, back to front: `static` (base, lawn, floor, trees — never
moves), then `box3`, `broof1`, `troof1`, `broof2`, `troof2`, `broof3`,
`troof3`, then `ac`, `battery`, `car`, `solar`.

Each moving piece is a pure vertical translation — the artwork is identical at
both ends, so nothing changes shape. Rises, in layout pixels at 1×:

| piece | rise |
|---|---|
| troof3 | 297.3 |
| broof3 | 274.4 |
| troof2 | 247.9 |
| broof2 | 216.1 |
| box3 | 206.4 |
| troof1 | 191.0 |
| broof1 | 150.0 |

The four devices fade in one at a time on the closed house (A/C 0.33–0.78s,
car 0.98–1.43s, solar 1.63–2.08s, battery 2.28–2.73s) and then rise on the same
lift as the roof.

Keyframes are baked one per frame with linear handles, and verified against the
source animation: worst positional error 0.001px across all twelve layers.

Assets are embedded as base64, so the `.json` is self-contained at ~1.05MB. If
you would rather have them as separate files to cache independently, they are
in `assets/` and `_offsets.json` gives each one's position — say the word and I
will emit a version that references them.

## Re-exporting

`studio.html` is the animation itself — one self-contained file, no build step.
Open it and every parameter is a live control; it is also what produced
everything here. Three presets sit along the top: **glow** (what this handoff
uses), **dots** and **dot pulse**.

Export from it needs `python3`, `ffmpeg` and Chrome, and only runs locally —
ask and I will re-export rather than setting that up.

Useful URL parameters for a quick look without the panel: `?ui=0` hides the
controls, `?t=0.42` renders one static frame, `?bg=%23ffffff` changes the
background, `?energy=flow` switches to the flowing-dash look.
