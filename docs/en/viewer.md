# Viewer Guide

The viewer is the heart of mdhelp: it displays Markdown files
as formatted documents.

## Opening Files

**File Tree:** Click on a file in the left tree.
Folders can be expanded and collapsed. Clicking a folder
automatically opens the `index.md` inside it, if present.

**Links:** Click on a link in the document.
Relative links (e.g. `features.md`) open other Markdown files.
External links (e.g. `https://...`) open the system browser.
Anchor links (e.g. `#section`) jump to the heading.

**Change Folder:** Ctrl+O or File > Open Folder.
The new folder is loaded in the tree and the home page is shown.

**Recent Folders:** Via File > Recent Folders you can quickly
switch between up to 10 recently used directories.

## Navigation

**Back / Forward:** Like in a browser. Alt+Left goes back,
Alt+Right goes forward. mdhelp remembers the scroll position,
so you continue reading exactly where you left off.

**Home:** Alt+Home or the Home button opens the `index.md`
in the root directory.

**Reload:** F5 reloads the current file. Useful when you
have edited the file externally.

## Table of Contents

The table of contents (TOC) in the lower left shows all headings
of the current file. Indentation corresponds to the heading level:

```
Features                  <- H1 (no indentation)
  Markdown Rendering      <- H2 (slightly indented)
    Code Blocks           <- H3 (further indented)
  Tables                  <- H2
```

Clicking an entry scrolls to the corresponding position in the document.

## Search

Ctrl+F opens the search bar below the toolbar.

**Search Page:** In "Page" mode, only the current document is searched.
Matches are highlighted yellow, the current match orange.
F3 jumps to the next, Shift+F3 to the previous match.

**Search All Files:** In "All Files" mode, all `.md` files in the
document directory are searched. Results appear as a list in the
left sidebar with filename and line number. Clicking opens the file
and highlights the match.

The search bar is closed with Ctrl+F or Escape.

## Tree Context Menu

Right-clicking a file in the tree opens a context menu:

| Entry | Action |
|---|---|
| Open | Show file in viewer |
| Open in Editor | Edit file in integrated editor |
| Copy Path | Copy full file path to clipboard |

## Bookmarks

Bookmarks provide quick access to frequently visited pages.

**Add:** Ctrl+D or Bookmarks > Add remembers the current file.
It then appears in the Bookmarks menu.

**Remove:** Bookmarks > Remove deletes the bookmark
for the current file.

Bookmarks persist across sessions.

## Font Size

Ctrl+Plus and Ctrl+Minus change the font size (8 to 24 point).
The setting is saved automatically.

The current size is shown on the right side of the status bar.

## Breadcrumb

In the toolbar on the right, the breadcrumb path shows the relative
location of the current file, e.g. `docs > guides > custom-docs.md`.

## Link Tooltip

When hovering over a link, the status bar shows the target URL.
This lets you see where a link leads before clicking.

## Copy

Ctrl+C copies the selected text to the clipboard.
Ctrl+A selects all text.

## Next

- [Editor](editor.md) -- edit documents directly in mdhelp
- [Keyboard Shortcuts](shortcuts.md) -- all shortcuts at a glance
- [PDF Export](guides/pdf-export.md) -- save documents as PDF
