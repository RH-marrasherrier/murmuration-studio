# House explode animation — paused, ready to resume

Figma source: file `idgtQhuf6FdL1JpgpKSjXz`, canvas `536:1191`, keyframes named **0–6**
(`636:8252`, `636:6495`, `636:6714`, `636:6933`, `636:7152`, `636:7591`, `636:7812`).
Each keyframe is **995 × 1066**, background `#060606`.

## Status

Groundwork is **done**: every moving element is extracted as a keyed transparent
PNG in `layers/`, and every position is measured. The layered composite was
validated against Figma keyframe 5 at **RMSE 10.43**, with "extra" and "missing"
pixels balanced (2058 / 1927) — that balance means the residual is subpixel line
phase, not misalignment. Devices overlay pixel-exactly.

**Not yet built:** the timeline HTML and the render.

## Layers

`layers/x_*.png` are the **exploded** house parts (keyframes 1–6).
`layers/base|lawn|floor1|floor2|roof1|roof2.png` are the **closed** `home` parts,
needed only for keyframe 0.

Draw order, back to front:
`x_base, x_lawn, x_floor1, x_floor2, x_roof1, x_roof2, solar, battery, car, ac, thermostat`

## Positions (frame-local, from `pos_final.json`)

| layer | x | y |
|---|---|---|
| x_base | 64 | 481 |
| x_lawn | 96 | 661 |
| x_floor1 | 205 | 453 |
| x_floor2 | 341 | 194 |
| x_roof1 | 199 | 278 |
| x_roof2 | 325 | 77 |
| solar | 315 | 400 |
| battery | 223 | 569 |
| car | 400 | 676 |
| ac | 741 | 615 |
| thermostat | 714 | 526 |

Closed-house y values for the pieces that move in transition 0→1:
Floor 2 **374.3**, Roof 1 **494.9**, Roof 2 **337.0** (they rise to 194 / 278 / 77).

## Transitions (Marra's notes)

| | what happens |
|---|---|
| 0→1 | roof comes off; HVAC + thermostat appear |
| 1→2 | EV drives in along the isometric grid |
| 2→3 | solar panels come in from top, land on roof |
| 3→4 | batteries come in isometrically from the side |
| 4→5 | devices float up/down in a straight line onto one plane |
| 5→6 | home fades opacity; blue glowing line appears, starts at the HVAC and wraps around |

Measured kf4→kf5 moves: battery −119y, car −55y, a/c −108y, thermostat −86y,
solar +18x +27y (solar settles **down** while the rest rise).

## Three traps already hit — don't repeat them

1. **Export house parts from keyframe 5, not 6.** In keyframe 6 the house group
   is already faded, so exports come back dim (alpha caps at ~168, never 255).
2. **`contentsOnly: true` renders on pure black**, which destroys the fill /
   background distinction below. Use the default (`false`) and accept that
   overlapping content is included — it ends up hidden behind fills anyway.
   Tested: `contentsOnly` gave RMSE 19.12 vs 10.43 for the default.
3. **Keep the `#000000` fills opaque.** Figma renders each shape's own fill as
   pure black and the area outside it as `#060606`, so a three-zone key works:
   `lum<=3` → opaque black occluder, `4..9` → transparent, `>=10` → line art
   (alpha ramp, unpremultiplied). Keying the fills away lets lines show through
   roof planes that should hide them.

## Blue circuit (transition 5→6)

`layers/line.svg` — node `638:8673`, viewBox 661.1 × 401.054, placed at frame-local
inset `-4.07% / -2.39%` of a node at (201.05, 398.07) size 630.9 × 370.85.
Tokens: stroke **Primary/Powder `#9BB8FA`**, glow drop-shadow `#749EFF` radius 15.1.
It must draw **starting at the HVAC end** — find the path end nearest the A/C at
(741, 615) and animate `stroke-dashoffset` from that end.

## Remaining work

1. Write `house-animation.html` on the existing rig pattern: deterministic
   `render(t)`, `?t=` for one frame, `?from=`/`?to=` for clip slices, `?bg=`.
2. Cross-fade closed→exploded roof pieces during 0→1 (the exploded Roof 1 and
   Roof 2 are taller — 284 vs 241, 215 vs 200 — so they are not the same art;
   fade between them while translating).
3. Confirm timings with Marra. Untested guess: ~1.2s per transition with short
   holds at each keyframe and a 2s tail, ≈ 10s total.
4. Render with `render-gif.sh` at `W=995 H=1066 SCALE=1 BG='#060606'`.
