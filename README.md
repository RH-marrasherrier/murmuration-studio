# Glow studio

A local tuning studio for the Renew Home house-build animation — an isometric
home that opens up, gains devices, then has energy travel between them along
dashed arches.

The illustration is inline SVG, exported from the Everyday Brand Kit file and
split into layers, so it is crisp at any size and the fills can be recoloured
directly. `assets/house-anim-v3/` keeps the house layer sources and
`assets/house-anim-v2/` the devices; nothing in either is loaded at runtime.

`house-outro.html` is the same animation without the controls, plus an outro
and a timeline bar for scheduling it. `handoff/` is the packaged version for
web — see its own README.

Sliders change the animation live in the browser; the export button runs the
real render pipeline at full quality with whatever is on screen.

![controls](docs/panel.png)

## Run it

```bash
./studio-setup.sh          # stages a working copy into /tmp (see note below)
python3 /tmp/glow-studio/studio-server.py
```

Then open <http://127.0.0.1:3477/>.

Requires `python3`, `ffmpeg`, and Google Chrome at the standard macOS path.

## The house

Every moving piece is the **same artwork in both keyframes**, repositioned —
so the whole thing is pure vertical translation. There are no art swaps, no
clipping and no staged states, which is what made earlier versions of this
fight back. Eight layers: one `static` group that never moves (base, lawn,
floor, trees) and seven that rise.

| piece | rise, art units |
|---|---|
| top roof 3 | 456.7 |
| bottom roof 3 | 421.7 |
| top roof 2 | 380.9 |
| bottom roof 2 | 332.0 |
| box 3 | 317.2 |
| top roof 1 | 293.5 |
| bottom roof 1 | 230.5 |

Read straight off the two frames' layer coordinates rather than measured. The
four devices fade in one at a time on the closed house, then rise on the same
lift as the roof.

**House pace** and **energy pace** scale their halves of the timeline
independently, each off the authored values, so retiming the house never
changes how long the energy runs. **Lift ease** is the exponent of the lift's
ease-in-out; 3 is a plain cubic.

As the arches arrive the house steps back by shifting its line colour to
`#5D6876` rather than dropping opacity, so the linework keeps its weight and
the fills stay solid occluders.

## Presets

Three looks ship on the versions bar along the top, and the studio opens on
**glow**:

| preset | energy | arches |
|---|---|---|
| **glow** | pulses, 70px long, 75% soft, every 0.8s | 66% arch, effectively solid (60/1) |
| **dots** | the dashes flow at 90px/s | 58% arch, 0.5px dots on 10.5px gaps, 1.5px line |
| **dot pulse** | pulses, 20px long, every 1.5s, 10px halo | 58% arch, 0.5px dots on 6.5px gaps |

They are built into the file rather than stored in the browser, so they cannot
be deleted and they travel with the studio. Loading one returns every other
control to its default, so clicking between presets always lands on the same
look. Versions you save yourself appear after them and are removable; **back up
versions** writes them to `glow-versions.json` when the studio runs locally, or
copies them to the clipboard otherwise.

## Controls

### Circuit line

The devices are joined by five arches, in a ring: thermostat, HVAC, car,
battery, solar, back to the thermostat. Each arch is a quadratic Bezier lifted
above the straight line between two device centres, and **arch height** is that
lift as a share of the chord.

**Dash length** and **dash gap** set the dash pattern, and **line weight** its
thickness. Line weight also drives the bright core of a travelling pulse, so a
pulse reads as riding the arch rather than sitting beside it.

An arch is built centre-to-centre, so it aims at the middle of each device,
then trimmed back to where it crosses that device's outline. A bounding box is
not enough: the solar panel is a tilted parallelogram, so its box edge sits in
empty space and the arch stops short of the visible art. Each device's
silhouette is measured as the x range its art covers in every 2px band, and the
curve is trimmed to that.

### Energy flow

Flow is the default. **Pulses** — the five devices take turns emitting, in the order HVAC, solar,
car, battery, thermostat. Each emission travels out along every arch that
device touches and stops at the far device, where it is absorbed: the head
halts on arrival while the tail keeps closing, so a pulse grows out of the
sender and shrinks into the receiver. **Pulse speed**, **take turns every**,
**pulse length** and **pulse width** set the pacing and weight.

**Flow** — the dashes themselves travel, so the line reads as moving along the
ring. Beware of aliasing here: a dash pattern that advances more than half its
repeat between frames reads as drifting *backwards*. The panel computes this
live from the dash length, gap, speed and export frame rate, and names the
maximum safe speed when you cross the line. At the default 7.5/8 dashes, 25fps
and 90px/s the pattern moves 3.6px a frame against a 15.5px repeat, which is
fine; at 7px dots and 230px/s it measured −2.5px a frame, i.e. backwards.

**Off** — the arches draw in and stay put. Both Flow and Off hold the circuit
at full opacity, since there are no pulses for it to step back behind.

### The roof lift

Closed and exploded roof art are different shapes, not the same shape moved:
the closed roof is a gable with hip faces, the exploded one a detached plane
showing its underside. Roof 1 is 425 art units tall closed and 500 exploded.
Switching between two states put that whole change on one frame, and because
`easeInOut` holds the lift at zero for the first frames it landed on a
completely stationary roof — which read as the roof dropping before it rose.

Three source keyframes fix it. Keyframe 2 supplies an intermediate roof 1 at
458 units, so the change is staged:

| piece | states | at lift |
|---|---|---|
| roof 1 | closed 425 → mid 458 → exploded 500 | 0, 12.5%, 35% |
| roof 2 | closed 352 → exploded 379 | 0, 8.3% |
| floor 2 | one state, 428 throughout | translate only |

The 12.5% and 8.3% figures are where keyframe 2 actually sits (roof 1 has risen
47.8 of its 381, roof 2 38.0 of its 456.7), so the art changes at the lift it
was drawn for. Each state's position comes from its own bounding box rather
than being tracked by hand, so the piece's on-screen top runs continuously from
735 to 354 with no discontinuity at either handover.

Measured on the render: the two changeover frames alter 4,984 and 5,624 pixels,
against a mean of 1,949 and a maximum of 5,624 across the lift — so they sit
inside the range of ordinary fast motion rather than standing out as pops. The
top edge never moves down on any of the 62 frames.

Each exploded piece is also clipped at its closed bottom edge, which hides the
underside it gains until the piece has risen past the line.

### Scene

**Background** takes any hex, with or without the `#`, plus `none` for a
transparent render. The house fills follow it: the layers are pure greyscale, so
an SVG filter ramps each channel from the background at 0 to the stroke colour
at 1, which keeps the fills opaque occluders — a blend mode would let lower
layers show through the roof planes. Above 50% background luminance the stroke
end flips dark, or the house would dissolve into a light backdrop.

On a transparent render there is no background for the fills to follow, so they
stay the last colour they had and the house keeps a near-black body sitting on
the alpha. `?fill=` and `?stroke=` set those two independently of `?bg=`:

| | fill | stroke | reads as |
|---|---|---|---|
| any backdrop | `none` | — | hollow wireframe, no occlusion |
| light slide | `#ffffff` | `#2B3138` | solid line drawing |

`?fill=none` is the only genuinely background-independent option, but it costs
the occlusion: the staircase and the lower walls show straight through the roof
planes, so the layers stop reading as stacked. Filling in the destination's own
colour keeps the depth and still leaves nothing outside the silhouette — that
is the better trade whenever the background colour is known.

**Device heights** — *Keyframe* raises each device its own amount, read off the
two source frames (solar 289, A/C 305, battery 248, car 175 art units). *One
plane* raises them all by the same amount instead, set by **plane height**, so
the set keeps its isometric relationship and reads as one level. The devices do
not start coplanar — solar is on the roof, battery and A/C on the ground, the
car on the driveway — so a shared screen height would scramble the arrangement.
The arches follow the devices in both modes.

**Devices** arrive one by one, or start all present.

Two retired options survive as URL parameters: `?layout=spokes` swaps the ring
for four arches radiating out of the solar panels, and `?layout=wires` restores
the original isometric perimeter circuit. `?source=loop` sends evenly spaced
pulses around the whole path instead of emitting them per device.

**Export** — name, format (GIF / MP4 / both), frame rate, and playback length.
Progress is reported frame by frame. Each export also writes a
`<name>.params.json` sidecar, so any file you keep carries the settings that
produced it.

Note that playback length *time-scales* the whole sequence rather than trimming
it — 12s is the authored pace.

## How it works

`house-animation-glow.html` is the whole animation. Its `render(t)` is a pure
function of `t` in `[0,1]`: no timers, no CSS transitions, no dependence on
frame history. That is what makes headless capture reproducible — each frame is
rendered by a separate Chrome process, and identical input must give identical
output.

The same file serves the live studio and the renderer:

| URL | effect |
|---|---|
| `/` | live studio with the controls panel |
| `?t=0.42` | one static frame, panel suppressed |
| `?ui=0` | suppress the panel |
| `?from=&to=` | render a slice of the timeline |
| `?bg=%23060606` / `?bg=none` | backdrop, or transparent |
| `?fill=%23ffffff` / `?fill=none` | house fills, independent of the backdrop |
| `?stroke=%232B3138` | house linework, overriding the light/dark flip |
| `?energy=pulses\|flow\|off` | how energy reads |
| `?layout=ring\|spokes\|wires` | connection geometry |
| `?arch=&dashLen=&dotGap=&pulseSpeed=…` | every line and pulse parameter |

Parameters not shown in the panel — line colour, glow spread and weight, the
post-pulse circuit opacity, house fade — are baked to their chosen values but
still accept a URL override, so a render can deviate without the panel growing
back.

`render-gif.sh` walks `?t=` across the timeline with headless Chrome, then
assembles the frames with ffmpeg. `FRAMES_DIR` caches one capture so the GIF and
MP4 encodes share it rather than capturing twice.

`studio-server.py` serves the page and exposes `POST /export`, which starts a
background render and reports progress on `GET /job/<id>`.

Two rendering details worth preserving:

- **Never dither this artwork.** Flat vector frames use only a few hundred
  distinct colours, so they fit GIF's 256-colour table losslessly and a dither
  pattern only sprays noise over the flat background. Measured: `dither=bayer`
  gave RMSE 3.54 against source, `dither=none` gave 0.08 — and a smaller file.
- **The arches grow by subdividing the curve, not by dashes.** The dash pattern
  already occupies `stroke-dasharray`, so the reveal cannot also use it. Each
  arch is a quadratic Bezier, which de Casteljau splits exactly, and the drawn
  curve is regrown each frame from 0 to the reveal fraction.
- **In `?layout=wires`, a pulse crossing the path's seam is drawn as two
  dashes.** That circuit is an open path and SVG dashes do not wrap across its
  ends, so a span over that point is written as two dash runs totalling the
  right length.

## Layers

The animation composites keyed PNG layers rather than redrawing the artwork.
`docs/EXTRACTION.md` records how they were pulled out of Figma and the three
traps involved — including that Figma renders each shape's own fill as pure
black against a `#060606` background, which is what makes keying possible at
all, and that `contentsOnly: true` destroys that distinction.

## Note on `/tmp`

The studio is staged into `/tmp` rather than run in place because macOS blocks
the host app's dev-server process from reading anything under `~/Desktop`
("Operation not permitted" / "No permission to list directory"). `/tmp` is
cleared on reboot, so re-run `studio-setup.sh` before starting the server again.

Exports land in the staged directory and are offered as download links in the
page, since that same restriction stops the server writing back to `~/Desktop`.
