# mdhelp 4 — Changelog

All notable changes to mdhelp 4 are documented here.
The format is loosely based on [Keep a Changelog](https://keepachangelog.com/).

## 2026-05-14 — Cross-app context menu (Phase 3)

**Affected consumers:** UI extension, no API change.

### Added

- **Right-click in the viewer** now shows cross-app entries in the
  context menu:
    - "Look up in glossary" — opens tcltk-glossary with the
      selected word (or the word at the cursor) as a search term.
    - "Search in man-viewer" — analogous for nroffide (once
      man-viewer supports a `--search` option).
- Items are only shown when the target app is found via
  `tcldocs::launcher::findApp`. If the module is missing, the menu
  shows a disabled hint.

### Implementation

- New procs in `app/mdhelp_ui.tcl`:
  `app::extendViewerContextMenu`, `app::_pickContextTerm`,
  `app::_lookupInGlossary`, `app::_lookupInManViewer`.
- `app/mdhelp.tcl` calls `app::extendViewerContextMenu` after the
  existing `mdhelp_clipboard::setupContextMenu` — extending the
  existing menu with new items rather than binding a parallel menu.

### Requirements

- `tcldocs::launcher 0.1` — already a dependency since the Phase-2
  migration.
- `tcltk-glossary` with the `--search TERM` CLI — supported in
  `glossary_gui.tcl` since 2026-05-14.

## 2026-05-14 — Test stabilization (skip-on-missing, TMPDIR)

**Affected consumers:** no user-API change. Test behavior: some
suites that were previously red now skip cleanly with exit code 2.

### Fixed

- **`tests/test_mdindexgen.tcl`** — skip-on-missing when the optional
  package `mdindexgen` is not installed. Instead of a hard failure,
  exit code 2 with an explanatory message.
- **`tests/test_mdpdf.tcl`** — skip-on-missing when `pdf4tcl` is
  absent. Plus: temp directory now uses `$TMPDIR` (fallback `/tmp`,
  then `[pwd]`) instead of `~/_test_mdpdf_$pid/`. Previously a
  permission error in restricted environments with a non-writable
  `$HOME`.
- **`tests/test_mdindexgen.tcl`** — same TMPDIR logic as
  `test_mdpdf`, for the case the package is installed later.

### Changed

- **`tests/run_all_tests.tcl`** — the test runner now distinguishes
  exit code 2 (skip) from real failures. Statistics show
  `Total: N passed, M skipped, K failed`.

### Background

The 2026-05-14 test-runner report showed two mdhelp suites red:
`test_mdindexgen` (package missing) and `test_mdpdf` (temp path
under HOME). Both were environment issues, not real bugs.

## 2026-05-13 — Migrate `tools_external` to `tcldocs::launcher`

**Affected consumers:** no user-API change. Build / install: an
additional dependency `tcldocs-launcher 0.1` (see the
`tcldocs-launcher/` repository).

### Removed

- **`app/tools_external.tcl`** (267 LOC) — logic extracted into its
  own mini-repository `tcldocs-launcher`. Identical API
  (`::tools::findApp`, `::tools::launchApp`,
  `::tools::buildToolsMenu`, …), now loaded via
  `package require tcldocs::launcher`. Previously maintained in
  parallel in man-viewer and mdhelp (true duplication).

### Changed

- **`app/mdhelp.tcl`** — line 922 (`source tools_external.tcl`)
  replaced by `package require tcldocs::launcher`.
- **`build.tcl`** — `tcldocs-launcher` added to the list of external
  repositories copied into the VFS. ENV override:
  `TCLDOCS_LAUNCHER_HOME`.

## 2026-05-13 — Migrate `shared_config` to `tcldocs::config`

**Affected consumers:** no user-API change. Apps that call mdhelp
externally need no adjustments. Build / install: an additional
dependency `tcldocs-config 0.1` (see the `tcldocs-config/`
repository).

### Removed

- **`app/shared_config.tcl`** (132 LOC) — logic extracted into its
  own mini-repository `tcldocs-config`. Identical API
  (`::tcldocs::path`, `::tcldocs::loadShared`, `::tcldocs::saveShared`,
  `::tcldocs::getShared`, `::tcldocs::setShared`), now loaded via
  `package require tcldocs::config`.

### Changed

- **`app/mdhelp.tcl`** — line 912 (`source shared_config.tcl`)
  replaced by `package require tcldocs::config`.
- **`build.tcl`** — `tcldocs-config` added to the list of external
  repositories copied into the VFS (`apptm/tcldocs/config-0.1.tm`).
  ENV override: `TCLDOCS_CONFIG_HOME`.

### Consumers of the API inside mdhelp

Unchanged: `app/mdhelp_settings.tcl` (theme / fontSize),
`app/deepl_helper.tcl` (deeplApiKey, deeplUsePro). Direct access to
`::tcldocs::cache` in `deepl_helper.tcl:47` continues to work
(namespace variable in the module).

### Build note

When building from the source tree, `tcldocs-config` must be
available as a sibling repository (or via the
`TCLDOCS_CONFIG_HOME` env override). Default search path:
`../tcldocs-config/lib/tm/`.

### Background

This migration is part of Phase 1 of the ecosystem cleanup
(see the 2026-05-13 review and the top-level `README.md`). Goal:
cross-app shared settings as a single module rather than duplicated
in each app. Next steps: the same migration in `tcltk-glossary` and
`man-viewer`.

## 2026-05-13

### Changed

- **TOC-sync suppress duration is configurable.** The 500 ms
  hardcoded value in `mdhelp_ui.tcl::onTocSelect` is now a namespace
  variable `::app::tocSyncSuppressMs` (default 500). Persisted via
  `~/.mdhelp.rc` — bounds 0..5000 (0 = suppress disabled).
  Background: see the 2026-05-13 review of TOC-selection sync.

### Added

- **`tests/test_toc_suppress.tcl`** — logic test for TOC-sync
  suppress. Verifies: (1) suppress blocks sync immediately after a
  TOC click, (2) sync resumes after the window elapses,
  (3) `SuppressMs=0` disables suppress (legacy behavior),
  (4) bounds check 0..5000, (5) source-code structures are still
  present (white box). 10 tests, no UI dependencies — runs without
  Tk / mdstack / docir.

- **`tests/run_all_tests.tcl` dependency pre-check.** Verifies
  whether `mdstack::parser`, `docir`, `pdf4tcl` are available
  **before** the test suites start individually. With missing
  required deps: a clear message with install hints and exit code 2
  (instead of six "child process exited abnormally" traces).
  Optionally skipped via `--skip-dep-check`.

## 2026-05-08

### Added

- **Multi-format reader.** nroff manpages can now be opened alongside
  Markdown (`.n`, `.1`, `.3tcl`, `.man`, `.1`–`.9`). Uses the
  `nroffparser` and `nroffrenderer` modules from the man-viewer
  project when available; falls back to plain text otherwise.
- **DeepL translation helper** (`Tools → Translate selection (DeepL)`).
  Reads the API key from `$DEEPL_API_KEY` or `~/.tcldocs.rc`,
  preserves Markdown markup during translation, and presents the
  result in an editable dialog. Free and Pro endpoints auto-detected.
- **Side-by-side mode** (`Tools → Open original side-by-side`, F11).
  Opens a second window with synchronised scrolling between two
  read-only panes. Auto-pairs translated documents with their
  originals via the `original:` frontmatter field.
- **Cross-app integration with nroffide** through a new `Tools` menu.
  Auto-detects nroffide via `$NROFFIDE_PATH`, `~/.mdhelp.rc`, or
  sibling-repo locations.
- **Library panel tree filter.** Case-insensitive glob match on file
  basename, 200 ms debounce, auto-expand of matching directories.
- **Recent files** menu (up to 15 entries, persistent in `~/.mdhelp.rc`).
- **Tab close** via `Ctrl+W`, middle-click on the tab header, or the
  toolbar button.
- **Search history dropdowns** for the Search and Replace fields
  (15 entries each, persistent across sessions).
- **Incremental search** in the Find bar (page mode, 250 ms debounce).
- **TOC sync while scrolling.** The Contents panel highlights the
  heading whose anchor is currently at the top of the viewer.
- **Persistent scroll positions** per file (up to 200 entries).
- **Auto-save for editor tabs.** Every 30 s the dirty content is
  written to a hidden `.<basename>.autosave` file. Restore prompt
  appears when reopening a file with a newer auto-save than the
  original.
- **Search & Replace** (`Ctrl+H`) with three option toggles:
  case-sensitive (Aa), whole-word (W), regex (`.\*`).
- **Goto line** dialog (`Ctrl+G`).
- **Word and character counter** in the status bar.
- **German Tcl 9 documentation corpus** scaffolding under
  `docs/tcl9-de/` (template, conventions, terminology glossary,
  category subdirectories, one example translation).

### Changed

- Search results are highlighted in the result panel and the document
  with distinct colours (gold for matches, orange for the active
  match). Search highlights are now also visible inside fenced code
  blocks and highlighted div blocks (synopsis / example / note /
  warning).
- Code blocks are visually more distinct (lighter blue-grey background,
  24 px left indent). Inline code uses a darker background as well.

### Internal

- **Module layout standardised** to the `/usr/local/lib/tcltk/<repo>/`
  convention with explicit `pkgIndex.tcl` per module directory.
  `bootstrap.tcl` and `_paths.tcl` helpers removed in favour of plain
  `package require` against `auto_path` and `tcl::tm::path`.
- **Makefile per repository** with `install`, `install-user`,
  `pkgindex`, `uninstall`, `test`, `help` targets.
- **Generator tool** `tools/generate-pkgindex.tcl` for auto-generating
  `pkgIndex.tcl` files.
- Imports updated to the new namespace hierarchy
  (`mdstack::parser`, `mdstack::viewer`, …) following the refactor
  in docir and mdstack.

## 2026-05-07

### Internal

- **Vendoring cleanup.** The `vendors/` directory was removed
  entirely. External modules (docir, mdstack, pdf4tcl, pdf4tcllib)
  are now resolved at runtime via `package require` from a
  user-local install path (`~/lib/tcltk/<repo>/`) or a sibling
  development checkout. Self-contained distribution is still
  available through the starpack build, which pulls the modules
  into the VFS at build time.
- Three mdhelp-owned modules (`mdeditor`, `mdeditwidget`,
  `mdhelp_pdf`) moved from `vendors/tm/` to `lib/tm/`.
- All entry points (app, tests, demos) reduced to a single line of
  `tcl::tm::path add` for own modules; everything else goes through
  standard `package require`. Missing dependencies produce the
  standard Tcl error `can't find package …` rather than silent
  fallbacks.
