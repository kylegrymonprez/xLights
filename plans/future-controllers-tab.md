# Future — Controllers Tab on iPad

The single biggest desktop subsystem the iPad doesn't surface.
Engine is already in `src-core/` (wx-free, links into the iPad
library); the entire gap is UI.

Source: §2.1 of the 2026-04-23 gap analysis.

## What's already in place

- All 34 output protocols (E1.31, ArtNet, DDP, OPC, ZCPP, KiNet,
  Twinkly, OpenDMX, uDMX, Renard, LOR / LOROptimised, OpenPixelNet,
  …) compiled into the iPad lib.
- All 18 vendor controller handlers (Falcon F4–F96, FPP, WLED,
  Pixlite16, HinksPix, AlphaPix, Minleon, J1Sys, SanDevices,
  ESPixelStick, Experience, ILightThat, PowerDMX) compiled in.
- `iPadRenderContext` owns an `OutputManager`. Live output toggle
  shipped (lightbulb in the sequencer toolbar). Discovery / setup
  is unreachable from iPad UI today — testers must configure
  controllers in desktop xLights and copy the show folder over.

## Gap (still open)

### Phase R-min — Basic discovery + edit + drive lights

| # | Item | Severity | Effort |
|---|---|---|---|
| O-2 | Show-folder section UI extras — Recent show folders list (`L-1b` in [`followups.md`](followups.md)) and base-directory toggle (`L-10`). Path display + change already shipped via `FolderConfigView` (the `folder.badge.gearshape` toolbar button on the sequence picker). | P2 | S |
| O-3 | Controller list — 13 columns (Name/Protocol/Address/Universes/Channels/Vendor/Model/Variant/Active/AutoLayout/AutoSize/Description/Status), drag-reorder, multi-select, sort by 6 fields, status LED | P1 | M |
| O-4 | Toolbar — Add Ethernet / Serial / Null / Discover / FPP Connect / Save / Delete All | P1 | M |
| O-5 | Per-controller right-click — Insert Ethernet/Serial/Renard/LOR/DMX/NULL, Activate, Activate xLights Only, Inactivate, Delete, Unlink, Upload Output, Sort submenu (6 modes) | P1 | M |
| O-6 | Controller property grid — 20–40 props per type (Ethernet vs Serial vs Null differ; full list in gap analysis) | P1 | L |
| O-7 | Discover sheet — Bonjour (FPP), broadcast (ArtNet, DDP), HTTP scan (Falcon, Pixlite16, Twinkly); 3-way conflict dialogs; DiscoveryAuthDialog credentials | P1 | L |
| O-8 | ControllerConnectionDialog (legacy add wizard) | P2 | S |
| O-9 | IPEntryDialog (IP entry helper) | P2 | S |
| O-13 | Output-to-Lights status / fault notifications when a controller drops | P2 | M |
| O-16 | LED status column / async ping thread per controller | P2 | S |

### Phase R-pro — Heavy controller dialogs (separate)

| # | Item | Severity | Effort |
|---|---|---|---|
| O-10 | **ControllerModelDialog** — port-mapping diagram (~4795 lines on desktop), drag-drop layout of models onto pixel/serial/virtual ports; per-port String/DMX/Virtual Matrix; per-port protocol; per-port brightness/gamma/null pixels/colour order/group count; smart-remote A–F (cascade-down-port toggle); auto-layout flag; bank visualisation; Print + XLSX export with smart-remote colour coding; right-click context menus; validation warnings | P2 | XL |
| O-11 | **PixelTestDialog** — 12 standard tests (Off, Chase, Chase 1/3..1/5, Alternate, Twinkle 5/10/25/50%, Shimmer, Background); per-RGB tabs; 4 selection trees (Outputs / ModelGroups / Models / Controllers) cascade checkboxes; speed/highlight/background sliders; Save/Load presets; embedded preview; ChannelTracker overlap-merge | P2 | XL |
| O-12 | RemapDMXChannelsDialog — From/To/Scale/Offset/Invert grid (48 rows); .xdmxmap CSV load/save | P2 | M |
| O-14 | Visualise button → opens O-10 | P2 | (= O-10) |
| O-15 | Print Layout button | P3 | M |

### Controller upload (separate phase, depends on R-min)

| # | Item | Severity | Effort |
|---|---|---|---|
| EX-4 | **FPPConnectDialog** — FPP discovery (Bonjour + UDP); 13-column per-instance config; sequence + media file selection; HTTP REST API uploads | P2 | XL |
| EX-5 | FPPUploadProgressDialog — per-FPP gauges + cancel | P2 | S |
| EX-6 | MultiControllerUploadDialog — controller checklist + log + right-click filters; covers Falcon, WLED, PowerDMX, etc. | P2 | M |
| EX-7 | HinksPixExportDialog — vendor-specific HSEQ format, master+2 slaves, playlists, schedule grid, USB drive export | P3 | XL |

## Why deferred

- The desktop already does this well; users today configure
  controllers there and copy the show folder to iPad. That
  workflow is functional even if not native.
- R-min alone is L-effort across O-2..O-7; R-pro adds two XL
  dialogs (port-mapping and pixel-test) that would each justify
  a multi-week sprint.
- Live output (lightbulb toggle) covers the most common tester
  ask — "play the sequence to my actual lights" — without any
  controller-setup UI.

## When to come back

- After H-5 ships and external testers have lived with the
  current "configure on desktop, play on iPad" flow for a
  release cycle. If user feedback consistently asks for
  controller setup on the iPad, R-min is the next big push.
- R-pro / FPP Connect can wait until R-min is stable and there
  is a concrete upload-from-iPad use case.
