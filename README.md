# mdhelp

Markdown Help Viewer with integrated editor, PDF export, and full-text search.

Built on [mdstack](https://github.com/gregnix/mdstack) (Tcl/Tk).

## Quick Start

```bash
wish app/mdhelp.tcl              # open docs/ in current directory
wish app/mdhelp.tcl /path/to/md  # open specific directory
```

Requires Tcl/Tk 8.6+ or 9.x. On Windows with BAWT: `wish app\mdhelp.tcl`.

## Features

- Markdown viewer with live preview
- Integrated editor with syntax highlighting
- PDF export (pdf4tcl backend)
- Full-text search across all documents
- Tabs, themes (light/dark/solarized), document outline
- TIP-700: definition lists, fenced divs, footnotes, spans
- Keyboard shortcuts, bookmarks, history

## Demo

```bash
tclsh demo/demo_mdhelp_pdf.tcl   # PDF export demo
tclsh demo/demo_search.tcl       # search demo
tclsh demo/demo_history.tcl      # history demo
tclsh demo/demo_clipboard.tcl    # clipboard demo
```

## Tests

```bash
tclsh tests/run_all_tests.tcl    # all test suites
```

6 suites, 179 tests. Requires pdf4tcl for PDF tests.

## Building Standalone Binaries

```bash
tclsh build.tcl                  # Linux + Windows
tclsh build.tcl linux            # Linux only
```

Requires `../runtimes/` — see [BUILD.md](BUILD.md).

## Documentation

Built-in: `docs/en/` — opened automatically in the app.

## Dependencies

| Dependency | Version | Source |
|------------|---------|--------|
| Tcl/Tk | 8.6+ / 9.x | https://www.tcl-lang.org |
| mdstack | 0.3.4 | https://github.com/gregnix/mdstack |
| pdf4tcllib | 0.2 | https://github.com/gregnix/pdf4tcllib |
| pdf4tcl | 0.9.4.25 | https://sourceforge.net/projects/pdf4tcl |
| DejaVu fonts | 2.37 | https://dejavu-fonts.github.io |

## License

MIT — see [LICENSE](LICENSE).
Third-party licenses: [THIRD-PARTY-LICENSES.md](THIRD-PARTY-LICENSES.md).
