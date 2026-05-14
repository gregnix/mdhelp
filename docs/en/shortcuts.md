# Keyboard Shortcuts

All keyboard shortcuts at a glance.

## Viewer

### File

| Shortcut | Action |
|---|---|
| Ctrl+O | Open folder |
| F5 | Reload current file |
| F1 | Help (quick start) |
| Ctrl+Q | Quit |
| Ctrl+W | Close current editor tab (Viewer tab is not closable) |

The **File** menu also has `Recent Folders` and `Recent Files` cascade
menus listing the last 10 folders / 15 files you opened.

### Navigation

| Shortcut | Action |
|---|---|
| Alt+Left | Back |
| Alt+Right | Forward |
| Alt+Home | Home page (index.md) |

### Search

| Shortcut | Action |
|---|---|
| Ctrl+F | Open/close search bar |
| Ctrl+H | Open search bar with Replace row |
| F3 | Next match |
| Shift+F3 | Previous match |
| Escape | Close search bar |

The search bar offers three options:

| Option | Effect |
|---|---|
| **Aa** | Case-sensitive search |
| **W**  | Match whole words only |
| **.\*** | Treat pattern as regular expression |

**Incremental search:** matches are highlighted while you type
(debounced to avoid thrashing). Disable via `::app::incrementalSearch 0`
in your settings file if you prefer manual `Find`.

Replace operations (`Replace`, `Replace + Next`, `Replace All`) require an
**editor tab** to be active — the viewer is read-only. Open the current
file with `Ctrl+E` to edit.

Search results in the **All Files** mode appear in the left panel with the
matched text highlighted in yellow.

### View

| Shortcut | Action |
|---|---|
| Ctrl+Plus | Font larger |
| Ctrl+Minus | Font smaller |

### Edit

| Shortcut | Action |
|---|---|
| Ctrl+C | Copy |
| Ctrl+A | Select all |
| Ctrl+E | Open current file in editor |
| Ctrl+D | Add bookmark |

## Editor

### File

| Shortcut | Action |
|---|---|
| Ctrl+S | Save |
| Ctrl+Z | Undo |
| Ctrl+Y | Redo |
| Ctrl+G | Goto line... |
| F7 | Start spellcheck |

### Search & Replace (Editor)

| Shortcut | Action |
|---|---|
| Ctrl+F | Open search bar (page mode) |
| Ctrl+H | Open search bar with Replace row |
| F3 | Next match |
| Shift+F3 | Previous match |

When the active tab is an editor tab, the search bar searches the
editor text directly and `Replace` / `Replace All` work on it.

### Input

| Shortcut | Action |
|---|---|
| Tab | Indent line |
| Shift+Tab | Outdent line |
| Return | Smart return (continue list) |
| Space | Toggle checkbox (on checkbox line) |

### Context Menu

| Shortcut | Action |
|---|---|
| Right-click | Context menu (cut/copy/paste, format, link, table) |

## Persistent State

Mdhelp remembers between sessions:

- The window geometry, font size, color scheme.
- The list of recent folders and bookmarks.
- The **scroll position** of every file you have looked at (max. 200
  files, oldest evicted; entries pointing to deleted files are pruned
  on next save).

When you re-open a file, the viewer restores the last scroll position
automatically.

## TOC Sync

The **Contents** panel on the left tracks the heading currently at the
top of the viewer. Scroll the document and the matching heading is
highlighted in the tree.

## Auto-Save

Editor tabs with unsaved changes are auto-saved every 30 seconds to a
hidden file `.<basename>.autosave` next to the original file:

- A regular `Save` (`Ctrl+S`) removes the auto-save file.
- A regular `Close` with `Discard changes` removes it as well.
- An app crash leaves the file in place. The next time you open the
  same file with `Edit File...`, mdhelp detects the newer auto-save
  and asks whether to recover.

The status bar of the editor tab shows `Auto-saved HH:MM:SS` after
each successful auto-save (only visible when the tab is clean).

## Library Filter

The **Library** panel on the left has a `Filter:` entry above the file
tree. Type any substring and the tree shrinks to just the files whose
name (without `.md`) contains it. Sub-directories without any matching
files are collapsed away. Click `X` to clear.

Match is case-insensitive and applies to the file basename only — not
the directory name and not the file content. Use `All Files` search
mode (`Ctrl+F`) when you need a content-based search.

## Search History

The Search and Replace fields are dropdown comboboxes. The last 15
search patterns and 15 replace patterns are kept across sessions.
Click the dropdown arrow to pick an old query.

## Closing Editor Tabs

| Action | How |
|---|---|
| Close current editor tab | `Ctrl+W` |
| Close a specific tab | Middle-click on its tab header |
| Save and close | `Save+Close` button in the editor toolbar |

The viewer tab cannot be closed.

## Tools — Cross-App Integration

The `Tools` menu provides quick access to **nroffide**, the companion
nroff IDE & debugger. The first time you use it, mdhelp searches for
`nroffide.tcl` in:

1. `$NROFFIDE_PATH` environment variable
2. User-configured path (set via `Tools → Configure path to nroffide...`)
3. `~/lib/tcltk/man-viewer/app/nroffide.tcl`
4. Sibling repo: `../man-viewer/app/nroffide.tcl` relative to mdhelp
5. Same parent dir: `../../man-viewer/app/nroffide.tcl`

Menu entries:

| Entry | What it does |
|---|---|
| `Edit in nroffide` | Opens the currently-viewed file in nroffide |
| `Browse Folder in nroffide` | Opens nroffide pointing at the current docs root |
| `Open File in nroffide...` | File dialog → opens the picked file in nroffide |
| `Open Folder in nroffide...` | Folder dialog |
| `Configure path to nroffide...` | Manually set the path to `nroffide.tcl` if auto-detection fails |

If nroffide can't be found, the first launch attempt offers to
configure the path manually.
