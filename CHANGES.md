# mdhelp 4 — Changelog

All notable changes to mdhelp 4 are documented here.
The format is loosely based on [Keep a Changelog](https://keepachangelog.com/).

## 2026-05-13 -- Migrate tools_external to tcldocs::launcher

**Affected consumers:** keine User-API-Aenderung. Build/Install:
zusaetzliche Dependency `tcldocs-launcher 0.1` (siehe Repo
`tcldocs-launcher/`).

### Removed

- **`app/tools_external.tcl`** (267 LOC) -- Logik in eigenes Mini-Repo
  `tcldocs-launcher` extrahiert. Identische API (`::tools::findApp`,
  `::tools::launchApp`, `::tools::buildToolsMenu`, ...), jetzt via
  `package require tcldocs::launcher`. War vorher in man-viewer und
  mdhelp4 parallel gepflegt (echte Duplikation).

### Changed

- **`app/mdhelp.tcl`** -- Zeile 922 (`source tools_external.tcl`)
  ersetzt durch `package require tcldocs::launcher`.
- **`build.tcl`** -- `tcldocs-launcher` in die Liste der externen Repos
  aufgenommen die ins VFS kopiert werden. ENV-Override:
  `TCLDOCS_LAUNCHER_HOME`.

## 2026-05-13 -- Migrate shared_config to tcldocs::config

**Affected consumers:** keine User-API-Aenderung. Apps die mdhelp4
extern aufrufen brauchen nichts anzupassen. Build/Install: zusaetzliche
Dependency `tcldocs-config 0.1` (siehe Repo `tcldocs-config/`).

### Removed

- **`app/shared_config.tcl`** (132 LOC) -- Logik in eigenes Mini-Repo
  `tcldocs-config` extrahiert. Identische API (`::tcldocs::path`,
  `::tcldocs::loadShared`, `::tcldocs::saveShared`, `::tcldocs::getShared`,
  `::tcldocs::setShared`), jetzt via `package require tcldocs::config`
  geladen.

### Changed

- **`app/mdhelp.tcl`** -- Zeile 912 (`source shared_config.tcl`)
  ersetzt durch `package require tcldocs::config`.
- **`build.tcl`** -- `tcldocs-config` in die Liste der externen Repos
  aufgenommen die ins VFS kopiert werden (`apptm/tcldocs/config-0.1.tm`).
  ENV-Override: `TCLDOCS_CONFIG_HOME`.

### Konsumenten der API innerhalb mdhelp4

Unveraendert: `app/mdhelp_settings.tcl` (theme/fontSize),
`app/deepl_helper.tcl` (deeplApiKey, deeplUsePro). Direktzugriff auf
`::tcldocs::cache` in `deepl_helper.tcl::47` funktioniert weiterhin
(Namespace-Variable im Modul).

### Build-Hinweis

Beim Build aus dem Source-Tree muss `tcldocs-config` als Sibling-Repo
verfuegbar sein (oder via `TCLDOCS_CONFIG_HOME` Env-Override). Default-
Suchpfad: `../tcldocs-config/lib/tm/`.

### Hintergrund

Die Migration ist Teil von Phase 1 der Ökosystem-Aufräumung
(siehe `reviews/2026-05-13-markdown-gesamtbegutachtung.md` und Top-Level
`README.md` im Markdown-Baum). Ziel: cross-app shared settings als
einmaliges Modul, nicht in jeder App separat. Naechste Schritte:
gleiche Migration in `tcltk-glossary` und `man-viewer`.

## 2026-05-13

### Changed

- **TOC-Sync-Suppress-Dauer konfigurierbar.** Die 500 ms Hardcoded-Wert in
  `mdhelp_ui.tcl::onTocSelect` ist jetzt eine Namespace-Variable
  `::app::tocSyncSuppressMs` (Default 500). Persistiert via
  `~/.mdhelp.rc` -- Bounds 0..5000 (0 = Suppress deaktiviert).
  Hintergrund: siehe `reviews/2026-05-13-mdhelp4-toc-selection-sync.md`.

### Added

- **`tests/test_toc_suppress.tcl`** -- Logik-Test fuer TOC-Sync-Suppress.
  Verifiziert: (1) Suppress unterdrueckt Sync sofort nach TOC-Klick,
  (2) Sync laeuft nach Ablauf des Fensters wieder, (3) `SuppressMs=0`
  deaktiviert Suppress (Legacy-Verhalten), (4) Bounds-Check 0..5000,
  (5) Source-Code-Strukturen sind weiterhin vorhanden (white-box).
  10 Tests, keine UI-Deps -- laeuft ohne Tk/mdstack/docir.

- **`tests/run_all_tests.tcl` Dep-Vorpruefung.** Pruefen ob `mdstack::parser`,
  `docir`, `pdf4tcl` verfuegbar sind, **bevor** die Test-Suites einzeln
  starten. Bei fehlenden required-Deps: klare Meldung mit Install-Hinweis
  und exit code 2 (statt 6x "child process exited abnormally"-Trace).
  Optional via `--skip-dep-check` ueberspringbar.

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
