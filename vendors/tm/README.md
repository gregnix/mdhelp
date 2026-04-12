# vendors/tm — Tcl Module Dependencies

This directory contains all Tcl module (`.tm`) dependencies for mdhelp.

## Contents

### From mdstack (https://github.com/gregnix/mdstack)

These modules are vendored from **mdstack 0.3.4** and are updated in sync
with mdstack releases. Do not edit these files directly — apply changes
upstream in the mdstack repository and re-vendor.

| File | Description |
|------|-------------|
| `mdstack-0.1.tm` | Orchestrator / stack manager |
| `mdparser-0.2.tm` | Markdown → AST parser (CommonMark + TIP-700) |
| `mdmodel-0.1.tm` | Document model |
| `mdviewer-0.3.tm` | Tk text widget renderer |
| `mdpdf-0.2.tm` | Markdown → PDF export |
| `mdhtml-0.1.tm` | Markdown → HTML export |
| `mdtext-0.1.tm` | Editor widget |
| `mdsearch-0.1.tm` | Full-text search |
| `mdoutline-0.1.tm` | Document outline panel |
| `mdeditorkit-0.2.tm` | Editor kit |
| `mdcontextmenu-0.1.tm` | Markdown context menu |
| `uicontextmenu-0.1.tm` | Generic context menu |
| `mdtheme-0.1.tm` | Theme management |
| `mdvalidator-0.1.tm` | AST validator |
| `mdstacknoteskit-0.1.tm` | Notes kit |

**License:** MIT — see [LICENSE-mdstack.txt](LICENSE-mdstack.txt)

### From pdf4tcllib (https://github.com/gregnix/pdf4tcllib)

| File | Description |
|------|-------------|
| `pdf4tcllib-0.2.tm` | PDF helper library (fonts, unicode, tables, layout) |

**License:** BSD 2-Clause — see [LICENSE-pdf4tcllib.txt](LICENSE-pdf4tcllib.txt)

### mdhelp-specific (part of this repository)

These modules belong to mdhelp and are maintained here.

| File | Description |
|------|-------------|
| `mdhelp_pdf-0.3.tm` | Native PDF export for mdhelp (pdf4tcl backend) |
| `mdeditwidget-0.2.tm` | Edit widget for mdhelp |
| `mdeditor-0.1.tm` | Editor (legacy) |

**License:** MIT — see [../../LICENSE](../../LICENSE)

## Updating vendored modules

```bash
# After a new mdstack release, copy changed modules:
cp ~/Project/mdstack/lib/mdpdf-0.2.tm      vendors/tm/
cp ~/Project/mdstack/lib/mdviewer-0.3.tm   vendors/tm/
# ... etc.

# Run tests to verify:
tclsh tests/run_all_tests.tcl
```
