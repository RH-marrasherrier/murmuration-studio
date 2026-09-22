# Animation studios

Local tuning studios for the Renew Home house-build animation — an isometric
home that opens up, gains devices, and then has energy flow around a circuit.

Two endings share the same build-up:

- **Glow studio** (`house-animation-glow.html`) — energy travels the circuit as
  pulses, each device emitting in turn.
- **Murmuration studio** (`house-animation-murmuration.html`) — energy travels
  as a swarm of drifting dots.

Sliders change the animation live in the browser; the export button runs the
real render pipeline at full quality with whatever is on screen.

![controls](docs/panel.png)

## Run it

```bash
./studio-setup.sh          # stages a working copy into /tmp (see note below)
python3 /tmp/murm-studio/studio-server.py
```

Then open <http://127.0.0.1:3477/> and pick a studio.

Requires `python3`, `ffmpeg`, and Google Chrome at the standard macOS path.

## Glow studio controls

**Circuit opacity after pulses start** — the line draws itself in at full
strength, then settles to this level once the pulses begin, so the pulses read
as the event and the line as the wiring.

**Pulses come from** — *Devices* or *Loop*. In Devices mode the five devices
take turns emitting, in the order HVAC, solar, car, battery, thermostat. Each
emission travels out along the circuit in **both** directions and stops at the
next device, where it is absorbed: the head halts on arrival while the tail
keeps closing, so a pulse grows out of the sender and shrinks into the
receiver. Loop mode instead sends evenly spaced pulses around the whole
circuit.

Device positions were measured against the circuit rather than estimated —
every device sits within 3.7px of the path, so pulses genuinely appear to leave
the device. The legs they travel:

| leg | length | travelled by |
|---|---|---|
| thermostat ↔ HVAC | 210px | HVAC, backward |
| HVAC ↔ car | 343px | HVAC, forward |
| car ↔ battery | 244px | car, forward |
| battery ↔ solar | 272px | battery, forward |
| solar ↔ thermostat | 372px | solar, forward |

**Pulse speed**, **take turns every**, and **pulse length** set the pacing.
Reach is not a control — the geometry above decides it.

Solar's forward leg crosses the point where the circuit path opens. SVG dashes
do not wrap across that seam, so a pulse spanning it is drawn as two dashes
that together total the right length.

## Murmuration studio controls

**Dots** — density (500–24,000), size (1–5px), opacity, and colour (white or
`#9BB8FA` powder blue). Size 1 matches the house wireframe, which measures 1px
nominal: 55% of its cross-sections render as 1px and 40% spill to 2px from
antialiasing.

**Motion** — speed along the path, speed *spread* (how much particles bunch as
they drift apart), and perpendicular wobble.

**Shape of the swarm** — band width, number of travelling clumps, clumpiness,
and a seed that reshuffles the whole arrangement.

Clumpiness is the one that matters most. Every dot shares a single size and
opacity, so brightness cannot signal anything — density is the only channel
left to carry the sense of flow. Clumps are what make it read as energy moving
rather than a static dotted line.

**Sequence** — devices arrive one by one, or start all present. "All present"
also opens the house on frame one, because devices that sit on walls would
otherwise float over a closed roof, and it moves the swarm sweep to the start so
the clip is almost entirely energy flow.

**Export** — name, format (GIF / MP4 / both), frame rate, and playback length.
Progress is reported frame by frame. Each export also writes a
`<name>.params.json` sidecar, so any file you keep carries the settings that
produced it.

Note that playback length *time-scales* the whole sequence rather than trimming
it — 12s is the authored pace.

## How it works

Each studio is one self-contained file. Its `render(t)` is a pure function of
`t` in `[0,1]`: no timers, no CSS transitions, no dependence on frame history.
That is what makes headless capture reproducible — each frame is rendered by a
separate Chrome process, and identical input must give identical output.

The same file serves the live studio and the renderer:

| URL | effect |
|---|---|
| `/` | live studio with the controls panel |
| `?t=0.42` | one static frame, panel suppressed |
| `?ui=0` | suppress the panel |
| `?from=&to=` | render a slice of the timeline |
| `?bg=%23060606` / `?bg=none` | backdrop, or transparent |
| `?count=&dotSize=&speed=…` | every swarm parameter (murmuration) |
| `?source=&showLine=&lineDim=…` | every pulse parameter (glow) |

Parameters no longer shown in the glow panel — line weight, colour, glow
spread and weight, pulse weight, house fade — are baked to their chosen values
but still accept a URL override, so a render can deviate without the panel
growing back.

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
- **Dots are snapped to whole pixels.** At fractional positions a 1px dot
  spreads across two pixels at partial coverage, so dots differ in apparent
  size *and* brightness. Snapping makes every dot render at exactly the same
  value.

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
