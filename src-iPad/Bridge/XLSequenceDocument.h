#pragma once

#import <Foundation/Foundation.h>

// ObjC bridge for iPadRenderContext — callable from Swift.
// Manages show folder loading and sequence access.

@interface XLSequenceDocument : NSObject

// Show folder
- (BOOL)loadShowFolder:(NSString*)path;
- (BOOL)loadShowFolder:(NSString*)path mediaFolders:(NSArray<NSString*>*)mediaFolders;

// Register/refresh a persistent security-scoped bookmark for a folder path.
// Call this whenever the user picks a folder via UIDocumentPicker so the
// bookmark is stored in UserDefaults and access survives app restart.
+ (BOOL)obtainAccessToPath:(NSString*)path enforceWritable:(BOOL)enforceWritable;

// Show / media folder accessors — needed by the file-relocation logic
// so Swift can tell whether a picked URL is already inside the
// enforced roots.
- (NSString*)showFolderPath;
- (NSArray<NSString*>*)mediaFolderPaths;

// Copy `sourcePath` into `<showFolder>/<subdirectory>`, appending `_N`
// to the basename on collision. Returns the destination absolute path
// on success, nil on failure (no show folder loaded, copy error).
- (NSString*)moveFileToShowFolder:(NSString*)sourcePath
                        subdirectory:(NSString*)subdirectory;

// Copy `sourcePath` into `<mediaFolderPath>/<subdirectory>`.
// `mediaFolderPath` must already be in `mediaFolderPaths`; unknown
// paths are rejected so the "media always lives in a configured root"
// invariant isn't broken.
- (NSString*)copyFileToMediaFolder:(NSString*)sourcePath
                       mediaFolderPath:(NSString*)mediaFolderPath
                        subdirectory:(NSString*)subdirectory;

// True iff `path` is under the show folder or any configured media
// folder. Used to decide whether a picked file needs copying.
- (BOOL)pathIsInShowOrMediaFolder:(NSString*)path;

// Compute a show-folder-relative path (e.g. `Images/foo.png`). Absolute
// paths outside the show folder round-trip unchanged so media-folder
// files aren't clobbered.
- (NSString*)makeRelativePath:(NSString*)path;

// Sequence
- (BOOL)openSequence:(NSString*)path;
- (void)closeSequence;
- (BOOL)isSequenceLoaded;

// Save the currently-open sequence back to its on-disk path. Returns
// NO if there's no sequence loaded, the path is empty, or the XML
// write fails. Marks the sequence clean on success.
- (BOOL)saveSequence;

// Save to a new path (Save As / Export). `path` must end in `.xsq`;
// the caller is responsible for obtaining security-scoped access
// to the destination via `-obtainAccessToPath:…` before calling.
// On success updates the sequence's internal path so subsequent
// `-saveSequence` writes to the new location.
- (BOOL)saveSequenceAs:(NSString*)path;

// Absolute on-disk path the sequence was opened from (or last
// saved to). Empty when no sequence is loaded.
- (NSString*)currentSequencePath;

// Dirty tracking (E-1). `SequenceElements` increments a change
// counter on every mutation; the bridge records the counter
// snapshot taken at load / save, and `isSequenceDirty` compares the
// live counter against that snapshot. Call `markSequenceClean`
// after a save-via-non-bridge-path (e.g. a save-as through Swift
// that writes out-of-band).
- (BOOL)isSequenceDirty;
- (void)markSequenceClean;

// Sequence metadata
- (int)sequenceDurationMS;
- (int)frameIntervalMS;
- (NSString*)sequenceName;

// Elements & rows
- (int)visibleRowCount;
- (NSString*)rowDisplayNameAtIndex:(int)index;
- (int)rowLayerIndexAtIndex:(int)index;
- (BOOL)rowIsCollapsedAtIndex:(int)index;
// Model name for a row (element->GetName()). Empty for non-model rows (e.g. timings).
- (NSString*)rowModelNameAtIndex:(int)index;

// Timing-row queries (rows whose Element is TIMING). Returns indices into
// the visible-row list used by effectCountForRow: and friends.
- (NSArray<NSNumber*>*)timingRowIndices;
- (BOOL)timingRowIsActiveAtIndex:(int)rowIndex;
- (void)setTimingRowActive:(BOOL)active atIndex:(int)rowIndex;
// Color index assigned sequentially to each timing element (0..4, cycles).
// Layers within the same timing element share the same color index.
- (int)timingRowColorIndexAtIndex:(int)rowIndex;
// Name of the timing element the row belongs to (stable across layers).
- (NSString*)timingRowElementNameAtIndex:(int)rowIndex;
// Effect layer's own label, e.g. "Phrases", "Words", "Phonemes" for
// lyric tracks. Empty if the layer has no explicit name.
- (NSString*)rowLayerNameAtIndex:(int)rowIndex;

// Model-row queries used by row headers.
- (BOOL)rowIsModelGroupAtIndex:(int)rowIndex;
- (int)rowLayerCountAtIndex:(int)rowIndex;
- (BOOL)rowIsElementCollapsedAtIndex:(int)rowIndex;
- (void)toggleElementCollapsedAtIndex:(int)rowIndex;

// Submodel / strand / node row metadata (mirrors
// `Row_Information_Struct.submodel`, `nestDepth`, `strandIndex`,
// `nodeIndex`). `nestDepth` drives visual indent on the left
// column; `strandIndex >= 0` and `nodeIndex >= 0` identify
// strand/node rows for the disclosure affordances below.
- (BOOL)rowIsSubmodelAtIndex:(int)rowIndex;
- (int)rowNestDepthAtIndex:(int)rowIndex;
- (int)rowStrandIndexAtIndex:(int)rowIndex;
- (int)rowNodeIndexAtIndex:(int)rowIndex;

// Submodel / strand disclosure. A row "has submodels" if its
// element is a ModelElement with strand/submodel children (desktop
// `ModelElement::ShowStrands` target); a row "has nodes" if it's a
// StrandElement with at least one node layer
// (`StrandElement::ShowNodes` target). Toggle helpers flip the
// state and repopulate row information so the caller only needs to
// refresh its row cache afterwards.
- (BOOL)rowHasSubmodelsAtIndex:(int)rowIndex;
- (BOOL)rowShowsSubmodelsAtIndex:(int)rowIndex;
- (void)toggleRowShowSubmodelsAtIndex:(int)rowIndex;
- (BOOL)rowHasNodesAtIndex:(int)rowIndex;
- (BOOL)rowShowsNodesAtIndex:(int)rowIndex;
- (void)toggleRowShowNodesAtIndex:(int)rowIndex;

// Layer management on a model / submodel / strand row. Mirrors
// the "Insert Layer Above/Below" and "Delete Layer" entries in
// desktop's `RowHeading` right-click menu
// (`RowHeading.cpp:751-801`). `insertAbove` / `insertBelow` key
// off the row's own `layerIndex`; `remove` returns NO if the
// element is down to its last layer (desktop disables the item in
// that case too). Repopulates row info on success.
- (BOOL)insertEffectLayerAboveAtIndex:(int)rowIndex;
- (BOOL)insertEffectLayerBelowAtIndex:(int)rowIndex;
- (BOOL)removeEffectLayerAtIndex:(int)rowIndex;

// Timing track rename / delete. `renameTiming…` wires through
// `SequenceElements::RenameTimingTrack` so effect references to
// the old name update in-place. `deleteTiming…` goes through
// `SequenceElements::DeleteElement` (which repopulates row info).
// Both return NO if the row isn't a timing row. `renameTiming…`
// also returns NO if `newName` collides with an existing timing
// track.
- (BOOL)renameTimingTrackAtIndex:(int)rowIndex newName:(NSString*)newName;
- (BOOL)deleteTimingTrackAtIndex:(int)rowIndex;

// B73: add a new variable (user-editable) timing track with the given
// name. The new track is made active (`DeactivateAllTimingElements` +
// active=true on the new one). Returns NO if `name` is empty; a
// unique suffix is auto-appended (Timing -> Timing_1) if the name
// collides with an existing track.
- (BOOL)addTimingTrackNamed:(NSString*)name;

// B67 / B69: timing-mark primitives. Marks are stored as `Effect`
// entries on the timing row's `EffectLayer`; these wrap the existing
// `addEffectToRow:...` / `deleteEffectInRow:atIndex:` but add a
// rowIsTiming guard and a range-overlap check. `addTimingMark` sets
// the effect name to `label` (the phrase/word/phoneme text on
// lyric tracks; empty string for plain timing marks). Returns the
// new mark's index, or -1 on failure (row isn't a timing row,
// overlap, or sequence end overlap).
- (int)addTimingMarkAtRow:(int)rowIndex
                  startMS:(int)startMS
                    endMS:(int)endMS
                    label:(NSString*)label;
- (BOOL)deleteTimingMarkAtRow:(int)rowIndex atIndex:(int)markIndex;

// B70: rename a timing mark's label in-place. `label` may be empty
// (clearing the label). Returns NO if the row isn't a timing row
// or the index is out of range. No overlap/validation — labels are
// free text.
- (BOOL)setTimingMarkLabelAtRow:(int)rowIndex
                        atIndex:(int)markIndex
                          label:(NSString*)label
    NS_SWIFT_NAME(setTimingMarkLabel(atRow:at:label:));

// B84: break every phrase mark on a timing element into per-word
// sub-marks on layer 1. Rejects rows that aren't the phrase layer
// (layer 0) of a timing element. Discards any existing word + phoneme
// layers on the element and adds a fresh word layer. Rejects when
// any existing word/phoneme effect is locked (matches desktop
// safety check in RowHeading::BreakdownTimingPhrases).
// Returns NO on rejection.
- (BOOL)breakdownPhrasesAtRow:(int)rowIndex
    NS_SWIFT_NAME(breakdownPhrases(atRow:));

// Views (view picker).
- (NSArray<NSString*>*)availableViews;
- (int)currentViewIndex;
- (void)setCurrentViewIndex:(int)viewIndex;

// dynamicOptions sources for JSON `choice` properties. Mirrors the desktop
// repopulate lambdas in JsonEffectPanel (file:1777-1884). Empty arrays on
// lookup failure — never nil. See EffectPropertyView for dispatch.

// All timing tracks in the sequence with <= 1 effect layer (i.e. not lyric).
- (NSArray<NSString*>*)timingTrackNames;
// Timing tracks with exactly 3 layers (phrase / word / phoneme).
- (NSArray<NSString*>*)lyricTimingTrackNames;

// Per-preview cameras available for `B_CHOICE_PerPreviewCamera`:
// always starts with "2D", followed by each 3D camera name from the
// show's `ViewpointMgr` (loaded from `<Viewpoints>` in
// `xlights_rgbeffects.xml` during Phase D-3). Mirrors desktop's
// `BufferPanel::OnBufferStyleChoiceSelect` population.
- (NSArray<NSString*>*)perPreviewCameraNames;

// Per-effect ColorCurve mode availability (G16 — C5). Some
// effects only make sense with linear time-curves, others only
// radial, a handful support both. Desktop calls
// `RenderableEffect::SupportsLinearColorCurves` /
// `SupportsRadialColorCurves` with the current effect's settings
// map; iPad's ColorCurve editor uses the same flags to grey out
// unavailable mode groups in the time/spatial picker.
//
// Returns @{@"linear": NSNumber (BOOL), @"radial": NSNumber (BOOL)}
// for the selected effect. Nil (empty dict) when no effect is
// selected. Always returns linear+radial true for now on iPad
// because the iPad doesn't track an "active palette slot" yet.
- (NSDictionary<NSString*, NSNumber*>*)colorCurveModeSupportForRow:(int)rowIndex
                                                            atIndex:(int)effectIndex;

// Palette save / load / import / export (G17 — C5). Palette files
// are plain-text `.xpalette` under `<showFolder>/Palettes/` plus
// any bundled-in-resources `palettes/` folder. The serialised
// format is the 8-slot comma-separated string that desktop's
// `ColorPanel::GetCurrentPalette` produces: each slot is either a
// `#RRGGBB` hex colour or an `Active=TRUE|…` ColorCurve blob.
// Round-trips byte-for-byte with desktop.

// List every saved palette visible to the app. Each entry is
// @{@"filename": <basename>.xpalette, @"palette": <8-slot string>}.
// Scans `<showFolder>/Palettes/` first, then app-bundled
// `palettes/` in Resources. Duplicates (same palette string
// already loaded) are dropped.
- (NSArray<NSDictionary<NSString*, NSString*>*>*)savedPalettes;

// Write `paletteString` to `<showFolder>/Palettes/<name>.xpalette`.
// `name` is sanitized for filesystem safety. Pass nil / empty to
// auto-generate `PAL001.xpalette` (incrementing to avoid collisions).
// Returns the on-disk filename on success, nil on failure (no
// show folder, unwritable, invalid input).
- (NSString*)savePaletteString:(NSString*)paletteString
                        asName:(NSString*)name;

// Remove a previously-saved palette file. `filename` is the
// basename returned by `savedPalettes`. Only removes files under
// the show folder — bundled palettes are read-only. Returns YES
// on successful delete.
- (BOOL)deleteSavedPalette:(NSString*)filename;

// Assemble the current 8-slot palette for the effect at row/index
// into the desktop-compatible serialised string
// ("#RRGGBB,#RRGGBB,...," or with `Active=TRUE|…` blobs for curve
// slots). Reads directly from the effect's settings map so the
// output matches what the renderer sees. Empty string if no effect
// is selected.
- (NSString*)currentPaletteStringForRow:(int)rowIndex
                                atIndex:(int)effectIndex;

// Apply a serialised palette string to the effect at row/index:
// parses slots and writes `C_BUTTON_Palette1..8` — mirrors
// desktop's `LoadColorsToButtons`. Leaves the per-slot enable
// checkboxes (`C_CHECKBOX_Palette1..8`) untouched, same as desktop.
// Returns YES on successful parse + apply.
- (BOOL)applyPaletteString:(NSString*)paletteString
                     toRow:(int)rowIndex
                   atIndex:(int)effectIndex;

// Value-curve preset load / save (G36 — C6). `.xvc` files are the
// same XML format desktop reads/writes
// (`<valuecurve data="<serialised>"/>`), stored under
// `<showFolder>/valuecurves/` plus any bundled `valuecurves/` in
// app resources.

// List every saved value curve visible to the app. Each entry is
// @{@"filename": <basename>.xvc, @"serialised": <VC string>}.
// Duplicates (same serialised body already loaded) are dropped.
- (NSArray<NSDictionary<NSString*, NSString*>*>*)savedValueCurves;

// Write `serialised` (a ValueCurve::Serialise() string) into an
// `.xvc` under `<showFolder>/valuecurves/<name>.xvc`. Name is
// sanitised to alphanumerics; pass nil / empty to auto-generate
// `VC001.xvc`. Returns the on-disk filename, or nil on failure.
- (NSString*)saveValueCurveSerialised:(NSString*)serialised
                                asName:(NSString*)name;

// Delete a saved value curve by basename. Only removes files
// under `<showFolder>/valuecurves/`; bundled presets are read-
// only. Returns YES on success.
- (BOOL)deleteSavedValueCurve:(NSString*)filename;

// Model-scoped sources. Uses the effect's parent element's ModelName to
// resolve a Model; ModelGroups are unwrapped to their first contained
// model, matching desktop (JsonEffectPanel.cpp:1815-1818). Empty on
// unresolvable model.
- (NSArray<NSString*>*)statesForRow:(int)rowIndex atIndex:(int)effectIndex;
- (NSArray<NSString*>*)facesForRow:(int)rowIndex atIndex:(int)effectIndex;
- (NSArray<NSString*>*)modelNodeNamesForRow:(int)rowIndex atIndex:(int)effectIndex;

// Effect-scoped: RenderableEffect::GetSettingOptions(settingId). Returns
// {} for most effects; SingleStrand overrides it to return the WLED FX /
// palette name lists (SingleStrandEffect.cpp:100-131). Matches desktop's
// "effect" dynamicOptions source.
- (NSArray<NSString*>*)effectSettingOptionsForRow:(int)rowIndex
                                          atIndex:(int)effectIndex
                                         settingId:(NSString*)settingId;

// Effects for a given row
- (int)effectCountForRow:(int)rowIndex;

// Effect data — returns arrays parallel to each other
- (NSArray<NSString*>*)effectNamesForRow:(int)rowIndex;
- (NSArray<NSNumber*>*)effectStartTimesForRow:(int)rowIndex;
- (NSArray<NSNumber*>*)effectEndTimesForRow:(int)rowIndex;

// Model preview — sets channel data on models for a given frame
- (void)setModelColorsAtMS:(int)frameMS;

// Opaque pointer to iPadRenderContext for Metal bridge
- (void*)renderContext;

// House Preview layout groups. "Default" (always first) + named groups
// from `<layoutGroups>` in xlights_rgbeffects.xml. Setting an unknown
// name falls back to "Default". Setter posts
// `XLLayoutGroupChanged` on NotificationCenter so preview panes can
// invalidate their background-texture caches.
- (NSArray<NSString*>*)layoutGroups;
- (NSString*)activeLayoutGroup;
- (void)setActiveLayoutGroup:(NSString*)name;

// Desktop's last-used House Preview 3D-vs-2D mode, read from
// `<settings><LayoutMode3D>` at show-folder load. Used as the initial
// value for the House Preview's is3D toggle; not written back since
// iPad layout editing stays desktop-only.
- (BOOL)layoutMode3D;

// Effect editing
- (BOOL)addEffectToRow:(int)rowIndex
                  name:(NSString*)effectName
               startMS:(int)startMS
                 endMS:(int)endMS;
- (BOOL)deleteEffectInRow:(int)rowIndex atIndex:(int)effectIndex;
- (BOOL)moveEffectInRow:(int)rowIndex
                atIndex:(int)effectIndex
              toStartMS:(int)newStartMS
                toEndMS:(int)newEndMS;
- (NSArray<NSString*>*)availableEffectNames;

// Effect settings for selected effect
- (NSDictionary<NSString*, NSString*>*)effectSettingsForRow:(int)rowIndex atIndex:(int)effectIndex;
- (NSDictionary<NSString*, NSString*>*)effectPaletteForRow:(int)rowIndex atIndex:(int)effectIndex;

// Effect metadata — returns JSON string as loaded from resources/effectmetadata/<Name>.json
// Empty string if no metadata is available for the effect.
- (NSString*)metadataJsonForEffectNamed:(NSString*)effectName;

// Shader dynamic properties — parses the .fs file at `shaderPath` and
// returns a JSON-encoded array of property entries that drop into
// `EffectPropertyView` using the same schema as static metadata. Empty
// string if the file isn't a parseable shader or the path is empty.
- (NSString*)shaderDynamicPropertiesJsonForPath:(NSString*)shaderPath;

// Shared metadata — returns JSON string for Buffer/Color/Timing shared panels.
// name must be one of "Buffer", "Color", "Timing".
- (NSString*)sharedMetadataJsonNamed:(NSString*)name;

// Read a single effect setting value by key.
// Keys with C_ prefix come from palette map; everything else from settings map.
- (NSString*)effectSettingValueForKey:(NSString*)key
                                inRow:(int)rowIndex
                              atIndex:(int)effectIndex;

// Write a single effect setting value. Returns YES if the value changed.
// Does NOT trigger a re-render — caller should invoke renderEffectForRow after
// batching setting changes.
- (BOOL)setEffectSettingValue:(NSString*)value
                       forKey:(NSString*)key
                        inRow:(int)rowIndex
                      atIndex:(int)effectIndex;

// Remove a setting from the effect (used for properties with
// suppressIfDefault=true when the new value equals the default, so the
// settings map doesn't persist a redundant default). Returns YES if the
// key was present and was removed.
- (BOOL)removeEffectSettingForKey:(NSString*)key
                            inRow:(int)rowIndex
                          atIndex:(int)effectIndex;

// Fade in/out (seconds, stored as T_TEXTCTRL_Fadein / T_TEXTCTRL_Fadeout).
- (float)effectFadeInSecondsForRow:(int)rowIndex atIndex:(int)effectIndex;
- (float)effectFadeOutSecondsForRow:(int)rowIndex atIndex:(int)effectIndex;
- (BOOL)setEffectFadeInSeconds:(float)seconds
                          forRow:(int)rowIndex
                         atIndex:(int)effectIndex;
- (BOOL)setEffectFadeOutSeconds:(float)seconds
                           forRow:(int)rowIndex
                          atIndex:(int)effectIndex;

// Resize one edge of an effect. edge: 0 = left/start, 1 = right/end.
// Clamps to neighbors; returns NO if clamp would invert the range.
- (BOOL)resizeEffectEdgeInRow:(int)rowIndex
                       atIndex:(int)effectIndex
                          edge:(int)edge
                        toMS:(int)newMS;

// Lock / render-disable state.
- (BOOL)effectIsLockedInRow:(int)rowIndex atIndex:(int)effectIndex;
- (void)setEffectLocked:(BOOL)locked inRow:(int)rowIndex atIndex:(int)effectIndex;
- (BOOL)effectIsRenderDisabledInRow:(int)rowIndex atIndex:(int)effectIndex;
- (void)setEffectRenderDisabled:(BOOL)disabled inRow:(int)rowIndex atIndex:(int)effectIndex;

// Copy: returns full settings string (xLights legacy format) and the effect's
// palette as a separate string. Empty strings on failure.
- (NSString*)effectSettingsStringForRow:(int)rowIndex atIndex:(int)effectIndex;
- (NSString*)effectPaletteStringForRow:(int)rowIndex atIndex:(int)effectIndex;
- (NSString*)effectNameForRow:(int)rowIndex atIndex:(int)effectIndex;

// Paste / scripted add: insert a new effect with settings+palette pre-populated.
// Returns the index of the new effect, or -1 on failure.
- (int)addEffectToRow:(int)rowIndex
                 name:(NSString*)effectName
             settings:(NSString*)settings
              palette:(NSString*)palette
              startMS:(int)startMS
                endMS:(int)endMS;

// Kick off a background re-render for the range of a single effect's model.
- (void)renderEffectForRow:(int)rowIndex atIndex:(int)effectIndex;

// Re-render an arbitrary time range on a row's model (used after delete so
// the cleared output is refreshed).
- (void)renderRangeForRow:(int)rowIndex
                  startMS:(int)startMS
                    endMS:(int)endMS
                    clear:(BOOL)clear;

// Controller output
- (BOOL)startOutput;
- (void)stopOutput;
- (BOOL)isOutputting;
- (void)outputFrame:(int)frameMS;

// Rendering
- (void)renderAll;
- (BOOL)isRenderDone;
// Signal all in-flight render jobs to abort and block until they've
// completed (or `timeoutSeconds` elapses). Returns YES if the render
// is fully quiesced by the time the call returns. Call on shutdown /
// sequence-close paths before tearing down `SequenceElements` et al —
// the render workers hold pointers into those structures and would
// crash otherwise.
- (BOOL)abortRenderAndWait:(NSTimeInterval)timeoutSeconds;

// Memory pressure
- (void)handleMemoryWarning;
- (void)handleMemoryCritical;
+ (int64_t)availableMemoryMB;

// House preview pixel data at a given time
// Returns NSData containing packed float x, y and uint8 r, g, b per pixel
- (int)pixelCountAtMS:(int)frameMS;
- (NSData*)pixelDataAtMS:(int)frameMS;

// Audio playback
- (BOOL)hasAudio;
- (void)audioPlay;
- (void)audioPause;
- (void)audioStop;
- (void)audioSeekToMS:(long)positionMS;
- (long)audioTellMS;
- (int)audioPlayingState;  // 0=PLAYING, 1=PAUSED, 2=STOPPED
- (void)setAudioVolume:(int)volume;
- (int)audioVolume;

// Waveform data — returns downsampled peaks for display
// Returns array of alternating min/max float values for the given time range
- (NSData*)waveformDataFromMS:(long)startMS
                         toMS:(long)endMS
                   numSamples:(int)numSamples;

// Effect-background batch append. Mirrors desktop's
// `EffectsGrid::DrawEffectBackground` helper — resolves the
// RenderableEffect + color mask, then calls
// `RenderableEffect::DrawEffectBackground` with the bridge's current
// effect-background accumulator. Caller must have wrapped the visible-
// effects loop in `-beginEffectBackgroundBatch` / `-flushEffectBackgroundBatch`
// on the bridge. Coordinates are in logical pixel space, top-left
// origin (matches the grid's coord system — desktop uses bottom-left
// but the accumulator just stores the numbers, so we stay consistent
// with the grid's other calls).
//
// Returns the draw-icon hint desktop uses:
//   0 — effect drew a full background, skip the icon
//   1 — show the normal-size icon
//   2 — show a smaller icon (leaves room for partial background)
// Bridge is declared `id` in the header so this file doesn't have to
// import `XLGridMetalBridge.h`; the .mm casts it back.
- (int)appendEffectBackgroundForRow:(int)rowIndex
                            atIndex:(int)effectIndex
                                 x1:(float)x1
                                 y1:(float)y1
                                 x2:(float)x2
                                 y2:(float)y2
                             bridge:(id)bridge
                          drawRamps:(BOOL)drawRamps;

// Media picker — sequence-wide enumeration + thumbnails.
// `mediaPathsInSequence` returns every media file referenced by effects
// in the currently-open sequence as a list of
// @{@"path": NSString, @"type": NSString (image|svg|shader|text|binary|video)}
// dictionaries. Backed by `SequenceMedia::GetAllMediaPaths()`, which
// walks the media cache — iPad renders once on sequence open, so every
// referenced file has landed there by the time the user opens a picker.
- (NSArray<NSDictionary<NSString*, NSString*>*>*)mediaPathsInSequence;

// Richer sequence-wide media inventory (G28 — C5). Every entry in
// the sequence's media cache with status flags + metadata the media
// manager view surfaces:
//
//   path         — the stored path (key used by settings maps)
//   type         — image|svg|shader|text|binary|video
//   resolvedPath — FixFile-resolved absolute path (empty if
//                  unresolvable)
//   isEmbedded   — NSNumber BOOL: data lives in the .xsq
//   isBroken     — NSNumber BOOL: not embedded AND resolved file
//                  doesn't exist on disk
//   widthPx      — NSNumber int, images only (0 otherwise)
//   heightPx     — NSNumber int, images only
//   frameCount   — NSNumber int, animated images / video (0 for
//                  single-frame / unknown)
//
// Missing entries (isBroken=YES) drive the E-4 open-time
// relocation sheet; the full list drives the media manager.
- (NSArray<NSDictionary<NSString*, id>*>*)mediaInventoryInSequence;

// Embed / extract for sequence-wide media management (G29 — C5).
// Embedding copies the file's binary content into the in-memory
// `MediaCacheEntry` so the next `saveSequence` writes base64 into
// the `.xsq`. Extracting writes the embedded data to disk at the
// entry's resolved path and flips the entry back to external.
// Videos and (on desktop) large binary files aren't embeddable —
// `IsEmbeddable()` on the base class gates both calls.
//
// Bumps the sequence dirty count so the toolbar Save affordance
// lights up. Returns YES if the operation actually changed the
// entry's embedded state.
- (BOOL)embedMediaAtPath:(NSString*)path;
- (BOOL)extractMediaAtPath:(NSString*)path;

// Embed / extract every embeddable cache entry. `typeFilter` nil
// or empty operates on all types; specifying "image" / "svg" /
// "shader" / "text" / "binary" scopes to that type (match the
// strings returned by `mediaInventoryInSequence`). Videos are
// never touched — they're un-embeddable. Returns the count that
// actually changed state.
- (int)embedAllMediaOfType:(NSString*)typeFilter;
- (int)extractAllMediaOfType:(NSString*)typeFilter;

// Replace a missing / broken media file with a fresh pick from
// disk (E-4 — relocate). Copies the source file into the show
// folder at a path derived from the stored path's type + the
// picked file's basename, then either re-reads the cache entry
// in place (when the target path matches the stored path) or
// performs a full rename-with-reference-update (when the target
// path differs — typical when the stored path was an absolute
// cross-machine path).
//
// `sourcePath` must be an on-disk absolute path the caller has
// already obtained security-scoped access to. Returns the
// target show-relative path on success, nil on failure.
- (NSString*)replaceMissingMediaAtPath:(NSString*)storedPath
                        fromSourcePath:(NSString*)sourcePath;

// Rename a cache entry (G30 — C5). Works for both embedded
// entries (cache-key swap only) and external files (also moves
// the file on disk so the stored path resolves at the new
// location). For embedded entries the disk move is skipped.
// Walks every effect's settings + palette maps and rewrites
// values equal to `oldPath` to point at `newPath` so no effect
// ends up stranded.
//
// Fails if `newPath` already exists on disk (external) or in
// the media cache (either), if the on-disk rename fails, or if
// the old path isn't cached. Returns YES on success.
- (BOOL)renameMediaFromPath:(NSString*)oldPath
                      toPath:(NSString*)newPath;

// Remove cached media entries that aren't referenced by any
// effect in the sequence (G31 — C5). The set of "referenced"
// paths is computed by walking every effect's settings +
// palette map, so we don't have to wait for a full re-render
// the way `MarkAllUnused` + `RemoveUnusedMedia` would. Returns
// the count removed. Dirties the sequence when anything was
// removed.
- (int)removeUnusedMedia;

// Video compatibility check (G32 — C5). Wraps
// `MediaCompatibility::CheckVideoFile`: returns nil when the
// file is AVFoundation-decodable on iPad, or a human-readable
// reason string (e.g. "Unsupported video codec") when it isn't.
//
// iPad can't transcode — if AVFoundation can't decode the
// source, neither can the transcoder. The UI uses the reason
// in a warning alert pointing the user at Handbrake / ffmpeg
// on desktop. Desktop keeps its in-app convert flow via
// `VideoTranscoder`; that path is not exposed to iPad.
- (NSString*)videoCompatibilityIssueForPath:(NSString*)path;

// Ensure a preview-frame bundle exists for `path` at the requested
// thumbnail bounds. Loads the entry if not yet loaded and calls
// `GeneratePreview`; subsequent calls with matching bounds re-use the
// cached frames. Returns the frame count (>= 1 on success, 0 if the
// path can't be resolved or has no preview support).
//
// `mediaType` must match the value returned for this path in
// `mediaPathsInSequence` ("image" / "video" / "svg" / "shader" /
// "text" / "binary"). The bridge uses the type to look up the right
// cache; without it, the per-type `Get…` accessors (which
// create-on-access) would otherwise mint a fresh cache entry of the
// wrong type for the path and corrupt the media inventory.
- (int)ensureThumbnailPreviewForPath:(NSString*)path
                            mediaType:(NSString*)mediaType
                            maxWidth:(int)maxWidth
                           maxHeight:(int)maxHeight;

// PNG-encoded pixel data for one frame of a path's preview strip.
// Caller must have called `ensureThumbnailPreviewForPath` first so the
// frame exists. Returns nil if the path / index is invalid or PNG
// encoding fails. `mediaType` disambiguates the cache lookup (see
// above).
- (NSData*)thumbnailPNGForPath:(NSString*)path
                     mediaType:(NSString*)mediaType
                    frameIndex:(int)frameIndex;

// Duration of the frame at `frameIndex` in milliseconds. Driven by the
// underlying format: animated-GIF / WebP frame delays, video frame
// intervals from the container, SVG / still-image entries return 0
// (single-frame content).
- (long)thumbnailFrameTimeMSForPath:(NSString*)path
                          mediaType:(NSString*)mediaType
                         frameIndex:(int)frameIndex;

// Probe a video file's total duration in milliseconds. Resolves the
// path via `FileUtils::FixFile` (so relative / cross-machine paths
// relocate onto the current show/media folders) and goes through
// core `VideoReader::GetVideoLength` — the same code path the render
// engine uses successfully. Swift's direct `AVURLAsset` probe fails
// on iCloud-hosted files because it doesn't carry the security-
// scoped bookmark the show folder was opened with; routing through
// the bridge keeps everything on the sandboxed-access path that
// already works for playback. Returns 0 on failure.
- (long)videoDurationMSForPath:(NSString*)path;

// Effect icons. Returns BGRA-premultiplied pixel data (width*height*4
// bytes) plus the chosen bucket size — parsed directly from the
// RenderableEffect's compiled-in XPM data. `desiredSize` is rounded
// up to the nearest {16,24,32,48,64} bucket. Returns nil if the effect
// name is unknown or the XPM couldn't be parsed.
- (NSData*)iconBGRAForEffectNamed:(NSString*)effectName
                      desiredSize:(int)desiredSize
                        outputSize:(int*)outputSize;

// MARK: - Moving Head fixture plumbing (G3 — C7)
//
// The Moving Head effect stores its actual renderable parameters
// as packed command strings in `E_TEXTCTRL_MH1_Settings` …
// `E_TEXTCTRL_MH8_Settings` (semicolon-separated `Key: value`
// pairs, with '@' as an escaped ';' inside VC blobs). A fixture
// is "active" iff its settings string is non-empty — desktop
// derives checkbox state the same way at open time
// (`MovingHeadPanel.cpp:1974-1985`).

/// Mask of which fixture slots (1..8) are active for the selected
/// Moving Head effect. Each bit: `1 << (fixture - 1)`. 0 when no
/// effect is selected, not a Moving Head effect, or no fixtures
/// are active.
- (int)movingHeadActiveFixturesForRow:(int)rowIndex
                               atIndex:(int)effectIndex;

/// Toggle a fixture slot active / inactive. Writes a seed
/// command string with the current slider values (Pan / Tilt /
/// offsets / groupings / cycles) when activating; clears
/// `E_TEXTCTRL_MH<fixture>_Settings` when deactivating. Also
/// rewrites every active fixture's `Heads:` list so it reflects
/// the new selection. Returns YES on change.
- (BOOL)setMovingHeadFixture:(int)fixture
                        active:(BOOL)active
                        forRow:(int)rowIndex
                       atIndex:(int)effectIndex;

/// Rewrite every active fixture's Pan / Tilt / offsets / groupings
/// / cycles commands from the current slider values, preserving
/// colour / path / dimmer / shutter settings untouched. Called
/// automatically by the view model whenever a slider the renderer
/// actually reads changes. Returns the count of fixtures updated.
- (int)syncMovingHeadPositionForRow:(int)rowIndex
                              atIndex:(int)effectIndex;

// MARK: - DMX state + remap plumbing (G8 — C7)
//
// Model states live on the `Model` object's in-memory
// `stateInfo` map. Desktop's Save-State writes a new entry then
// fires `EVT_RGBEFFECTS_CHANGED` to persist `xlights_rgbeffects.xml`;
// iPad v1 keeps the save in-memory for the session and does NOT
// persist (documented in the banner on the DMX panel). Loading
// desktop-authored states works across restarts because the
// states were already read out of the XML at show-folder open.

/// True iff a state with `stateName` already exists on the
/// effect's target model. Used for the save-overwrite prompt.
- (BOOL)dmxStateExistsForRow:(int)rowIndex
                      atIndex:(int)effectIndex
                     stateName:(NSString*)stateName;

/// Copy the current effect's `E_SLIDER_DMX1..48` values into a
/// new (or existing) state on the model. Builds the attribute
/// map matching desktop's `DMXPanel::OnSaveAsStateClick`
/// (CustomColors=1, Type=SingleNode, s<n>-Color="#XXXXXX"). In-
/// memory only — not persisted to disk in v1.
///
/// `overwrite=NO` aborts when the state already exists.
/// Returns YES on successful save.
- (BOOL)dmxSaveStateForRow:(int)rowIndex
                    atIndex:(int)effectIndex
                   stateName:(NSString*)stateName
                   overwrite:(BOOL)overwrite;

/// Pull a saved state's channel values back into the effect's
/// `E_SLIDER_DMX1..N` settings. Matches desktop's
/// `DMXPanel::OnLoadFromStateClick`: validates `Type=SingleNode`
/// and `CustomColors=1`, reads `s<n>-Color` hex, extracts the
/// red channel as the DMX byte, writes it via the settings map
/// (so the UI sliders pick up the change through the normal
/// observable path). Returns YES on successful apply, NO if the
/// state isn't present or doesn't match the expected shape.
- (BOOL)dmxLoadStateForRow:(int)rowIndex
                    atIndex:(int)effectIndex
                   stateName:(NSString*)stateName;

/// Preset channel remappings for the DMX effect. Smaller scope
/// than desktop's `RemapDMXChannelsDialog` — iPad v1 exposes a
/// handful of common transforms via a menu instead of the full
/// 48-row grid editor (deferred to post-v1).
///
///   0 = Shift +1     (channel n value → channel n+1, wrap)
///   1 = Shift -1     (channel n value → channel n-1, wrap)
///   2 = Reverse      (1↔48, 2↔47, …)
///   3 = Invert All   (each channel value = 255 - old)
///   4 = Double       (each channel value × 2, clamp to 255)
///   5 = Half         (each channel value / 2)
///
/// Returns YES when anything changed.
- (BOOL)dmxRemapChannelsForRow:(int)rowIndex
                        atIndex:(int)effectIndex
                         preset:(int)preset;

@end
