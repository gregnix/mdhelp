## 2026-05-16 — Build: fix tcldocs-config / tcldocs-launcher VFS layout

### Fixed

- **`build.tcl`** — `resolveRepo` matched `pkgIndex.tcl` at the
  repo root for `tcldocs-config` and `tcldocs-launcher`, so it
  returned the repo root and `glob $found/*.tm` found nothing.
  Result: built starpack crashed at runtime with
  `can't find package tcldocs::config`.

  Fix: use a marker that exists only inside `lib/tm/`, namely
  `tcldocs/config-0.1.tm` and `tcldocs/launcher-0.1.tm`
  respectively. `resolveRepo` then tries the repo root, fails,
  tries `$base/lib/tm`, succeeds, and the module is copied into
  the VFS under `apptm/tcldocs/`.
