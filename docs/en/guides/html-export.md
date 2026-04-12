# HTML Export

mdhelp exports the current document as an HTML file.

## Steps

1. Open document in mdhelp
2. `File > Export HTML...`
3. Choose output file
4. `Save`

## What is exported

- Complete HTML document with embedded CSS
- Table of contents (TOC) automatically generated from headings
- Title from YAML frontmatter or first H1 heading
- All inline formatting (bold, italic, code, links)
- Tables, lists, code blocks, blockquotes
- Footnotes

## Differences from PDF export

| Feature | HTML | PDF |
|---------|------|-----|
| Format | Browser-readable | Printable |
| Images | linked (relative) | embedded |
| Links | clickable | clickable |
| Pages | none | with page numbers |
| TOC | automatic | automatic |

## Usage

The exported `.html` file can be:

- Opened in a browser
- Served by mdserver
- Embedded in other systems
- Used as a basis for further processing

## Batch conversion

For converting multiple files, use `md2out.tcl` (in mdstack `tools/`):

```bash
tclsh md2out.tcl --batch docs/ out/ --format html
```

See mdstack documentation for details.
