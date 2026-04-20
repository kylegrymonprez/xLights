# Cross-phase follow-ups

Small items left over from phases that otherwise landed. No new
phase home; catalogued here so they don't fall off.

## Phase A — Core-path hardening

- **Re-prompt on failed `ObtainAccessToURL`.** Desktop re-prompts
  the user with `UIDocumentPickerViewController` when a stale
  security-scoped bookmark fails to resolve; iPad currently
  ignores the return value, so a stale bookmark leads to silent
  lookup failure. Minimum version: check the return, log, and
  drop the failed folder from `_mediaFolders` before handing it
  to `FileUtils`. Full re-prompt UX needs a Swift callback +
  `UIDocumentPickerViewController` hook.
