# Installation

## Requirements

- Tcl/Tk 8.6 or newer (9.x compatible)
- pdf4tcl 0.9.4 (included in vendors/pkg/)

## Directory Structure

```
mdhelp/
+-- mdhelp.tcl             Main application
+-- lib/                   mdhelp modules
|   +-- mdhelp_search-0.1.tm
|   +-- mdhelp_history-0.1.tm
|   +-- mdhelp_clipboard-0.1.tm
|   +-- mdindexgen-0.1.tm
|   +-- mdspellcheck-0.1.tm
+-- vendors/tm/            mdstack + pdf4tcllib + editor modules
|   +-- mdparser-0.2.tm
|   +-- mdmodel-0.1.tm
|   +-- mdviewer-0.3.tm
|   +-- mdpdf-0.2.tm
|   +-- pdf4tcllib-0.2.tm
|   +-- mdtext-0.1.tm
|   +-- mdcontextmenu-0.1.tm
|   +-- uicontextmenu-0.1.tm
|   +-- mdstack-0.1.tm
|   +-- mdsearch-0.1.tm
|   +-- mdhelp_pdf-0.3.tm
+-- vendors/fonts/         DejaVu Sans Condensed (TTF)
+-- vendors/pkg/           pdf4tcl 0.9.4
+-- demo/                  Module demos
+-- docs/                  Documentation
```

## Launch

```
wish app/mdhelp.tcl
```

Without arguments, `docs/` in the program directory is used.
On subsequent launches, the last opened folder is restored.

## Settings

Settings are automatically saved in `~/.mdhelp.rc`:

- Font size (8-24pt, default: 11pt)
- Last folder
- Window size
- Bookmarks
- Recent folders (max 10)

## Keyboard Shortcuts

See [Keyboard Shortcuts](shortcuts.md) for the full list.
