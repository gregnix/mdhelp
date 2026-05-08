# Features

mdhelp is a Markdown Help Viewer with integrated editor.

## Markdown Rendering

The viewer (mdviewer 0.3) supports:

- **Headings** (H1 to H6) with named fonts
- **Bold**, *italic*, ~~strikethrough~~ and `inline code`
- Lists (ordered and unordered, nested)
- Code blocks with language label and **syntax highlighting**
- Blockquotes (nested)
- Horizontal rules
- Images (local and embedded)
- Links (internal, external, anchors)
- Definition lists (term/definition pairs)

## Syntax Highlighting

Code blocks with language annotation are color-coded.
For Tcl/Tk: keywords (blue), strings (green),
comments (gray), variables (red), options (purple).
Other languages: comments and strings.

Colors automatically adapt to the active color scheme.

## Color Schemes

Three color schemes under View > Color Scheme:

- **Light**: Default, light background
- **Dark**: Dark background (Catppuccin-inspired)
- **Solarized**: Ethan Schoonover color palette

All viewer colors, syntax highlighting and TIP-700 colors
adapt accordingly. The selection is saved in ~/.mdhelp.rc.

## Tab System

Editor windows open as tabs in the main window instead of
separate toplevel windows. The first tab "View" shows the
viewer. Tab labels show filenames, unsaved tabs with asterisk (*).
On exit, mdhelp checks all open tabs.

## Frontmatter Panel

Narrow info bar above the viewer. Automatically shows
title, section and version from the YAML frontmatter.
Hidden when the current file has no frontmatter.

## Footnotes

Markdown footnotes are fully supported:

    Text with footnote[^1] and another[^note].

    [^1]: First footnote.
    [^note]: Second footnote with
      continuation line.

In the viewer, footnotes appear as clickable references.
A footnote section with separator line is shown at the bottom.
Footnotes are also rendered in PDF export.

## TIP-700: Tcl Man Page Markup

Extended Pandoc Markdown syntax for Tcl/Tk documentation.

### Bracketed Spans

Semantic classes for command syntax with colored rendering:

| Class | Meaning | Display |
|---|---|---|
| .cmd | Command name | dark blue, bold |
| .sub | Subcommand | dark blue, bold |
| .arg | Argument (required) | dark green, italic |
| .optarg | Argument (optional) | light green, italic |
| .ins | Instance command | purple, italic |
| .ccmd | C API function | dark red, bold |
| .ret | C API return value | orange |

### Fenced Divs

Structural sections with colored background:

| Class | Background | Usage |
|---|---|---|
| .synopsis | light blue | Command overview |
| .example | light green | Example sections |
| .arguments | light yellow | Argument descriptions |
| .note | light orange | Notes |
| .warning | light red | Warnings |

### YAML Frontmatter

Metadata at the file beginning is recognized and shown in the window title.
Supported fields: title, section, manual-section, version, see-also.

## Definition Lists

Glossary-style entries with term and one or more definitions.
Term is displayed in bold, definitions are shown indented.

## Frame Tables

Tables are rendered as real GUI widgets with zebra stripes,
header highlighting and column alignment (left, center, right).

## Search

### Widget Search (Page)

Searches the currently displayed text. Ctrl+F opens the search bar.
F3/Shift+F3 navigate between matches. Matches are highlighted yellow,
the current match orange.

### File Search (All Files)

Searches all .md files in the document directory.
Results appear in the left sidebar with file:line reference.
Click on a result to open the file and jump to the match.

## Navigation

- **History**: Browser-like back/forward with scroll position saving
- **File Tree**: All Markdown files as tree. Index.md on directory click
- **Table of Contents (TOC)**: Headings indented by level, click to jump
- **Breadcrumb**: Relative path of current file in toolbar
- **Link Tooltip**: Target URL shown in status bar on hover

## Integrated Editor

Split view (editor + live preview). Access via Ctrl+E, toolbar or context menu.
Format toolbar, outline panel, smart editing (list continuation, tab indent,
checkbox toggle), context menu, three modes (split/editor/preview).

## PDF Export

Exports the current document as PDF using the **DocIR pipeline**
(since 2026-05). Features:

- TrueType fonts embedded (DejaVu) — full Unicode/umlauts support
- **Per-inline styling**: bold, italic, code, strike-through render
  with proper font switching (not flattened to plain text)
- **Clickable hyperlinks** as PDF link annotations
- **Block images** embedded as PNG/JPEG XObjects, with relative
  paths resolved against the markdown file's directory
- Theme-colored code-block backgrounds and link colors
- Configurable page header/footer with `%p` page-number substitution
- Headings, tables, lists, code blocks, blockquotes, footnotes

See [PDF Export Guide](guides/pdf-export.md) for details.

## HTML Export

Exports the current document as a stand-alone HTML file. Since
2026-05, **referenced images are automatically copied** to the
output directory along with the HTML — the export produces a
portable bundle ready to open, share, or serve.

External URLs (`https://...`) are left as-is. Sub-directory
structure is preserved. See [HTML Export Guide](guides/html-export.md)
for details.

## AST Validation

Help > Validate AST checks the current document against AST spec v0.3.
Normal and strict modes, regression detection.
