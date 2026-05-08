# PDF Export

mdhelp exports the current document as a PDF file. As of 2026-05,
PDF export uses the **DocIR pipeline** (markdown → DocIR → PDF) for
consistent rendering across HTML and PDF outputs.

## Prerequisites

PDF export requires two Tcl packages:

- **pdf4tcl** 0.9.4+ — low-level PDF generation (in `vendors/pkg/`)
- **pdf4tcllib** 0.2+ — Unicode handling, TTF font embedding,
  page helpers (in `vendors/tm/`)

Both ship with mdhelp. If either is missing, the menu entry is
grayed out and the PDF button in the toolbar is disabled.

## Start Export

There are two ways:

- **Toolbar:** Click the "PDF" button
- **Menu:** File > Export PDF

A save dialog opens. The suggested filename corresponds to the
document name with `.pdf` extension.

## What is rendered

### Headings, paragraphs, lists, tables

Headings get larger font sizes (H1 has a horizontal rule below).
Paragraphs use proper line wrapping with measured font widths.
Tables get headers with theme-colored backgrounds and column
separators.

### Inline formatting (NEW since 2026-05)

Bold, italic, code-spans, links, and strike-through all render
distinctly with proper font switching:

- **Bold** uses DejaVu Sans Bold
- *Italic* uses DejaVu Sans Italic (or Bold-Italic when nested)
- `code` uses DejaVu Sans Mono
- ~~strike-through~~ has a line drawn over it
- [Links](https://example.com) appear in theme-color and
  are **clickable** in the PDF (real PDF link annotations)

This is a significant improvement over the previous version where
all inline content was flattened to plain text.

### Images

Block images (`![alt](path.png)` on its own line) are embedded
into the PDF as PNG/JPEG XObjects. Both relative and absolute
paths work:

- Relative paths are resolved against the markdown file's
  directory (mdhelp passes this automatically as `-root`)
- Absolute paths (`/full/path.png`) are used as-is
- HTTP/HTTPS URLs are NOT downloaded — they fall back to a
  text marker `[image: alt]`

Inline images (`text ![icon](pic.png) text`) currently render
as a text marker `[image: alt]`, not as actual embedded images.
This matches the behavior of older mdpdf versions.

### Fonts and Unicode

mdhelp embeds DejaVu TrueType fonts for proper Unicode support.
Umlauts (ä, ö, ü, ß), CJK characters, and emoji fallbacks all
render correctly.

### Header and Footer

Per-page headers and footers can be configured. mdhelp uses
default settings; if you want custom templates, look at the
`mdstack::pdf::configure -header` / `-footer` options. The token `%p`
is replaced with the current page number.

### Themes

The current viewer color theme influences PDF output:

- Code-block backgrounds use the theme's `code_bg` color
- Link text uses the theme's `link` color
- Font size honors the viewer's font size setting

## Limitations

The DocIR-based pipeline is feature-complete for typical
markdown documents. The following features from older mdpdf
versions are NOT included in the current adapter:

- **PDF/A compliance** — no archival format support
- **AES-128 encryption** — no user/owner passwords
- **Automatic TOC with PDF outlines** — table of contents is
  rendered as plain content, not as PDF bookmarks
- **External image download** — HTTP/HTTPS images are not fetched

If you need any of these, the legacy `mdpdf-0.2.tm.legacy` is
preserved in the source as a backup and can be reactivated.

## Verifying which export pipeline is active

`Help > About mdhelp 4` shows whether you're running the modern
adapter pipeline or the legacy standalone:

```
=== Stack-Komponenten ===
mdpdf:   0.2 (Adapter -> docir-pdf)    ← modern
mdhtml:  0.1 (Adapter -> docir-html, Asset-Copy)
docir:   md-source 0.1, pdf 0.1, html 0.1
```

If you see `0.2 (Legacy, Standalone)` instead, you're on the
older pipeline.

## Tips

- Check the result in the viewer before exporting — what you
  see is what you get
- For professional PDFs, adjust font size in `View > Font
  Larger/Smaller` before export
- Place all images in the same directory as the .md file (or
  in a sub-directory) for the relative path resolution to work
- H1 headings get a horizontal line below them; if you want
  page breaks, add them via blank pages in your markdown

Back to [Home](../index.md).
