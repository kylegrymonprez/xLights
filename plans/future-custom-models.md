# Future — Custom Model + Face / State + DMX Authoring

The model-authoring stack: Custom Model editor, SubModels,
Face / State authoring, DMX model deep authoring (servo, skull,
position-zones), and the Wiring view. Every serious xLights
user hits at least one of these dialogs; on iPad, none are
reachable.

Source: §2.4 + §2.5 + §2.7 + §2.6 of the 2026-04-23 gap analysis
(Phases T + U + V + W).

## Status

**Not started.** All authoring is desktop-only today; iPad's
`XLSequenceDocument` exposes the *use* side of these surfaces
(model state persistence per G8+, MH inspector tabs per G3+)
but no authoring entry points.

## Custom Model authoring (Phase T)

| # | Dialog | Severity | Effort |
|---|---|---|---|
| MA-1 | **CustomModelDialog** — 3D node-grid editor, ~40 ops (cut/copy/paste/find-replace/rotate/flip/reverse/shift/insert/delete row/column/compress/trim/shrink/expand/copy-layer-fwd/back/all/wire-cells-h/v/auto-number/background image overlay/zoom/wiring view/output to lights/import/export/import from controller) | P2 | XL |
| MA-2 | **GenerateCustomModelDialog** — 6-step wizard (Prepare → Choose Media → Start Frame → Manual Identify → Bulb Identify with sensitivity/blur/despeckle/contrast/gamma/saturation → Custom Model) | P3 | XL |
| MA-3 | **ModelRemap** — load original + new wiring → generate remap | P3 | S |
| MA-4 | **SubModelsDialog** — list CRUD + node-ranges grid + sub-buffer panel + buffer style + vertical buffer + live 3D preview | P2 | L |
| MA-5 | SubModelGenerateDialog — base name + type + count → auto-generate N sub-models | P3 | S |
| MA-6 | EditSubmodelAliasesDialog — alias listbox + add/delete/move | P3 | S |
| MA-7 | NodeSelectGrid — ordered toggle, select all/none/invert/load-from-model, zoom, background-image overlay, find/search, output to lights | P2 | M |
| MA-8 | ChannelLayoutDialog — HTML window with channel breakdown table; Print + View in Browser | P3 | S |

## Face / State / Aliases authoring (Phase U)

| # | Dialog | Severity | Effort |
|---|---|---|---|
| MA-9 | **ModelFaceDialog** — Face type (Single Nodes / Node Ranges / Matrix); per-phoneme node selection (10 phonemes: AI, E, ETC, FV, L, MBP, O, REST, U, WQ) + Eyes Open / Closed / Open3 / Closed3 + Mouth variants; Force Custom Colors; Output to Lights live preview; Image Placement (Centered / Scaled / Aspect / Crop); MatrixFaceDownload integration; per-face Add / Import / Copy / Rename / Delete / Shift; embedded ModelPreview | P2 | XL |
| MA-10 | **ModelStateDialog** — State type (Single Nodes / Node Ranges); per-state name + nodes + colour grid (200 rows); Force Custom Colors; Output to Lights; SevenSegmentDialog integration; Add / Import / Copy / Rename / Shift / Reverse / Clear / Export / Download; Color Draw Mode (All Colors / White Only); embedded preview | P2 | XL |
| MA-11 | **ModelDimmingCurveDialog** — 4 modes (Single Brightness/Gamma, Single Curve File, RGB Brightness/Gamma per channel, RGB Curve Files); load curve files; per-channel visualisation | P2 | L |
| MA-12 | EditAliasesDialog — model alias listbox + move / add / delete | P3 | S |
| MA-13 | StrandNodeNamesDialog — 2-column grids (strand names / node names); conditional Generate Node Names button (DMX models only) | P3 | M |
| MA-14 | SevenSegmentDialog — 6 segment checkboxes (Thousands / Hundreds / Colon / Tens / Decimal / Ones) + reference image | P3 | S |
| MA-15 | **MatrixFaceDownloadDialog** — tree navigator (categories / artists), search, image preview (256×128), face details, Insert Face. HTTP catalog from `nutcracker123.com/xlights/faces/xlights_faces.xml`; ZIP download with per-phoneme PNGs | P3 | XL |

## DMX models deep authoring (Phase V)

| # | Item | Severity | Effort |
|---|---|---|---|
| DM-1 | DmxMovingHead — Pan motor (16-bit coarse/fine, 540°), Tilt motor, RGB; basic property-grid | P2 | S |
| DM-2 | **DmxMovingHeadAdv** — 5 mesh files (base/yoke/head + textures), position zones (collision avoidance), 3D mesh import, advanced motor config | P2 | XL |
| DM-3 | DmxFloodlight — RGB-only basic | P2 | S |
| DM-4 | DmxFloodArea — extends floodlight with area beam | P3 | S |
| DM-5 | DmxGeneral — generic configurable channel layout | P3 | M |
| DM-6 | **DmxServo** — 1–25 servos, 1–24 static + motion meshes per servo, per-servo channel/range/style, 16-bit toggle, controller min/max pulse mapping | P3 | XL |
| DM-7 | **DmxServo3D** — 3D mesh + multi-servo puppet, mesh-to-servo / servo-to-mesh linking matrix | P3 | XL |
| DM-8 | DmxSkull — preset skull animatronic (Jaw / Pan / Tilt / Nod / EyeUD / EyeLR servos + RGB), Skulltronix preset | P3 | M |
| DM-9 | Color ability subsystems — RGB / RGBW / CMY / CMYW / ColorWheel (1 wheel + 1 dimmer + ≤25 custom colours with DMX value mapping) | P2 | M |
| DM-10 | Beam / Dimmer / Shutter / Preset abilities (mixin) | P2 | M |
| DM-11 | ServoConfigDialog — 3 spinners (servos 1–25 / static meshes 1–24 / motion meshes 1–24) + 16-bit toggle | P3 | S |
| DM-12 | SkullConfigDialog — 8 servo enable checkboxes + 16-bit + Skulltronix | P3 | S |
| DM-13 | PositionZoneDialog — 6-column grid (Pan Min/Max, Tilt Min/Max, Channel, Value); collision avoidance | P3 | M |
| DM-15 | ModelChainDialog — chain start channel after another model | P2 | S |
| DM-16 | StartChannelDialog — 6 modes (None / Universe / End of Model / Start of Model / Controller / Preview-only) | P2 | M |
| DM-17 | **DMXEffect channel grid** — 48 channels per effect (slider + value curve + invert per channel); Remap Channels button → opens RemapDMXChannelsDialog (O-12); Save State / Load State buttons | P2 | XL |
| DM-18 | MovingHeadEffect — 7 specialised value-curve domains (Pan / Tilt / Fan Pan / Fan Tilt / Pan Offset / Tilt Offset / Groupings / Time Offset / Path Scale) + shared color/wheel; partly covered by Phase C inspector | P2 | L (extra curves) |

## View Objects + Wiring view (Phase W)

| # | Item | Severity | Effort |
|---|---|---|---|
| VO-1 | ImageObject editing — file + transparency + brightness | iPad has D-7 read-only | S (add controls) |
| VO-2 | GridlinesObject editing — line spacing, width, height, color, axis labels, point-to-front | iPad has D-13 toggle | M |
| VO-3 | MeshObject — OBJ + MTL + textures, brightness, mesh-only flag, per-material color override | iPad has D-13 toggle | L |
| VO-4 | TerrainObject — heightmap image, parametric size, grid spacing/color, transparency, brightness, brush-paint heightmap edit-in-place | iPad has D-13 toggle | XL (paint tool) |
| VO-5 | RulerObject — singleton; length + units (m/cm/mm/feet/yards/inches); 2-point line | ✗ | M |
| VO-6 | ViewObjectPanel — tree, add/delete/reorder/rename/visibility/multi-select, alignment / distribute / flip / unlink-from-base | ✗ | L |
| WV-1 | **Wiring diagram view** — strand-by-strand, Standard (1 px / node) vs MultiLight (RGB), color-coded by string, channel labels, Dark/Gray/Light themes, Front/Rear, 90° rotations, mouse-wheel zoom + pan | P2 | L |
| WV-4 | PNG export (standard + large) | P2 | S |
| WV-5 | DXF vector export | P3 | M |
| WV-6 | Print | P3 | M |

## Why deferred

- All of this is XL+ work. The whole stack is collectively
  6+ months of dedicated engineering.
- 90% of users acquire models from VendorModelDialog (covered in
  the AI / vendor-downloader future plans) or build them in
  desktop xLights and copy the show folder over. Until that
  workflow proves insufficient, native iPad authoring isn't on
  the critical path.
- Some pieces (MA-2 GenerateCustomModelDialog video-pixel
  detection, MA-15 MatrixFaceDownloadDialog HTTP catalog,
  WV-1 wiring view, VO-4 TerrainObject heightmap painting)
  could each justify their own multi-week sub-plan once
  scheduled.

## When to come back

- After [`future-controllers-tab.md`](future-controllers-tab.md)
  is at least at R-min — controllers and models are the two
  desktop-only authoring surfaces, and bringing controllers first
  matches user need (live output > model authoring on iPad).
- MA-4 SubModels and MA-7 NodeSelectGrid are the two pieces
  most likely to be pulled forward as "single dialogs needed for
  a specific user request" rather than as part of a phase.
