# HTML Export

mdhelp exports the current document as a stand-alone HTML file.
Since 2026-05, **referenced images are automatically copied** to
the output directory, so the exported HTML works as a portable
package.

## Steps

1. Open document in mdhelp
2. `File > Export HTML...`
3. Choose output file
4. `Save`

mdhelp writes the `.html` file and copies all locally-referenced
images into the same output directory, preserving their relative
sub-folder structure.

## What is exported

- Complete HTML document with embedded CSS
- Table of contents (TOC) automatically generated from headings
- Title from YAML frontmatter or first H1 heading
- All inline formatting (bold, italic, code, links, strike-through)
- Tables, lists, code blocks, blockquotes, footnotes
- **Referenced images** (since 2026-05) with sub-directory structure preserved

## Asset Copy Behavior

When you have a markdown file like:

```markdown
# My Document

![Logo](logo.png)

See ![icon](icons/star.png) and the [reference manual](https://...)
```

…and export to `/some/output/manual.html`, you get:

```
/some/output/
├── manual.html
├── logo.png             ← copied from source
└── icons/
    └── star.png         ← copied with sub-directory preserved
```

External URLs (`https://...`) are left as-is in the HTML — no
download attempted.

### Rules

| Image source | What happens |
|---|---|
| `![](file.png)` (relative) | Copied to output dir |
| `![](sub/file.png)` (relative w/ subdir) | Copied, sub-dir created if needed |
| `![](/abs/path.png)` (absolute) | NOT copied (assumed already placed) |
| `![](https://...)` | NOT copied (external URL) |
| `![](file://...)` | NOT copied (treated as external) |

If a referenced image file is missing in the source directory,
the export prints a warning to stderr but continues — the HTML
still has the `<img>` tag, but the image won't load when viewed.

### Idempotency

Re-running the export overwrites only files whose size has
changed. Identical files are skipped, so re-exports are fast.

## Differences from PDF export

| Feature | HTML | PDF |
|---|---|---|
| Format | Browser-readable | Printable |
| Images | linked, **copied automatically** | embedded in PDF |
| Links | clickable | clickable (PDF annotations) |
| Pages | none (single scrolling document) | with page numbers |
| TOC | automatic (linked headings) | rendered as plain content |
| Self-contained | only if no relative images | fully self-contained |

## Usage

The exported `.html` file (plus copied assets) can be:

- Opened in a browser directly
- Served by a web server (e.g. mdserver)
- Zipped up and emailed (HTML + images travel together)
- Embedded in other systems
- Used as a basis for further processing

## Batch conversion

For converting multiple files, use `md2out.tcl` (in mdstack
`tools/`):

```bash
tclsh md2out.tcl --batch docs/ out/ --format html
```

The batch tool also benefits from the asset-copy logic.

See mdstack documentation for details.

## Disabling asset copy

If for some reason you want the old behavior (HTML only,
no asset copy), use the API directly:

```tcl
mdstack::html::export $ast $outFile -copyImages 0
```

This is rarely needed in normal use.

Back to [Home](../index.md).
