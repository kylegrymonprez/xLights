# Future — Audio-Driven Authoring

Audio-analysis features that turn the waveform from a *display*
into an *authoring* surface. Engine pieces are partly in place;
the gap is mostly UI wiring.

Source: §2.13 of the 2026-04-23 gap analysis (Phase J).

## What's already in place

- Waveform with the four standard filter modes (LUFS, VOCALS,
  NONVOCALS, STEM_*) and the 2026-04-22 alt-track switch (B43).
- Audio scrub during ruler drag (B40).
- VAMP analysis is *unreachable* on iPad — `vamp-hostsdk` is
  desktop-only and there's no iOS replacement.
- B79 "AI Speech 2 Lyrics" tracked separately in
  [`phase-b-grid-parity.md`](phase-b-grid-parity.md) — it's
  effectively the speech-recognition slice of this surface.

## Gap (still open)

| # | Item | Severity | Effort |
|---|---|---|---|
| A-1 | Generate timing track from audio onsets — UI on top of the existing onset-detection engine | P1 | M |
| A-2 | Generate timing track from beats / tempo | P1 | M |
| A-3 | Onset markers overlaid on waveform | P1 | S |
| A-8 | Incompatible-video warning at sequence load (also in [`followups.md`](followups.md)) | P1 | S |
| A-9 | Spectrogram view (waveform context menu toggle) | P2 | M |
| A-10 | Pitch-contour view | P2 | M |
| A-11 | Show-onsets toggle (View menu / waveform context menu) | P2 | S |
| A-12 | Music Generator (procedural) — gap analysis flagged from B79 reference; verify whether this is a real desktop feature before planning | — | — |

## Hard misses (no iOS path)

- **A-7** Polyphonic transcription. VAMP-only on desktop; no
  iOS-native equivalent. CoreML-based replacement is XXL and
  doesn't cover user-installed VAMP plugins.
- **A-13** VAMPPluginDialog. Same blocker.

## Why deferred

- The four standard waveform filters cover most real authoring
  workflows. Onset-driven timing-mark generation is a power-user
  tool and the desktop equivalent is also tucked behind a Tools
  menu.
- A-1 and A-2 are the highest-value pieces — they replace 5–10
  minutes of manual mark-tapping with a single button. But
  they're not blocking any current tester use-case.

## When to come back

- After Phase H ships and the analytics show whether testers are
  using onset-based timing on desktop and asking for it on iPad.
- A-3 / A-11 (the toggle-only items) are easy wins that could be
  pulled into a small polish PR alongside an MVP+ batch (see
  [`followups.md`](followups.md) "TestFlight quality").
