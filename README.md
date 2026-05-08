# mdhelp

Markdown Help Viewer with integrated editor, PDF export, and full-text search.

Built on [mdstack](https://github.com/gregnix/mdstack) (Tcl/Tk).

## Setup

mdhelp4 hat keine vendored Dependencies — alle externen Module werden
via `package require` ueber Tcls Standard-Mechanismus geladen.

### Voraussetzungen installieren

| Modul | Quelle | Install-Befehl |
|-------|--------|----------------|
| `docir` | https://github.com/gregnix/docir | `cd docir && sudo make install` |
| `mdstack` | https://github.com/gregnix/mdstack | `cd mdstack && sudo make install` |
| `pdf4tcllib` | https://github.com/gregnix/pdf4tcllib | `cd pdf4tcllib && sudo make install` |
| `pdf4tcl` (3rd-party) | https://github.com/gregnix/pdf4tcl | manuell — siehe unten |
| DejaVu fonts | OS package manager | `sudo apt install ttf-dejavu` |

`make install` legt die Module nach `/usr/local/lib/tcltk/<repo>/` ab.
Das ist Standard-Pfad in Tcls `auto_path` — kein weiteres Setup noetig.

### Schnell-Setup (Linux)

```bash
# Greg's Repos klonen
mkdir -p ~/src
git clone https://github.com/gregnix/docir       ~/src/docir
git clone https://github.com/gregnix/mdstack     ~/src/mdstack
git clone https://github.com/gregnix/pdf4tcllib  ~/src/pdf4tcllib

# Installieren (in /usr/local/lib/tcltk/<repo>/)
(cd ~/src/docir       && sudo make install)
(cd ~/src/mdstack     && sudo make install)
(cd ~/src/pdf4tcllib  && sudo make install)

# 3rd-party: pdf4tcl
# Download von https://sourceforge.net/projects/pdf4tcl/
sudo cp -r pdf4tcl-0.9.4.x /usr/local/lib/tcltk/pdf4tcl

# DejaVu-Schriften (fuer PDF-Export):
sudo apt install ttf-dejavu       # Debian/Ubuntu
sudo dnf install dejavu-fonts-all # Fedora
sudo pacman -S ttf-dejavu         # Arch
```

### User-Install (ohne sudo)

```bash
(cd ~/src/docir       && make install-user)   # ~/lib/tcltk/docir/
(cd ~/src/mdstack     && make install-user)
(cd ~/src/pdf4tcllib  && make install-user)
echo 'export TCLLIBPATH="$HOME/lib/tcltk/docir $HOME/lib/tcltk/mdstack $HOME/lib/tcltk/pdf4tcllib $HOME/lib/tcltk/pdf4tcl"' >> ~/.profile
```

### Verifikation

```bash
tclsh -c '
package require docir
package require docir::roff
package require mdstack::parser
puts "OK"
'
```

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

All demo scripts are Tk applications (`wish`) and load their modules
directly from `lib/tm/` — no extra setup needed beyond having the
listed dependencies installed.

```bash
wish demo/demo_mdhelp_pdf.tcl    # PDF export demo
wish demo/demo_search.tcl        # widget search with highlighting
wish demo/demo_history.tcl       # navigation history
wish demo/demo_clipboard.tcl     # clipboard helpers
```

| Demo | Required packages |
|------|-------------------|
| `demo_mdhelp_pdf.tcl` | `Tk`, `mdhelp_pdf` (transitively: `mdstack`, `pdf4tcl`, `pdf4tcllib`) |
| `demo_search.tcl`     | `Tk`, `mdhelp_search` |
| `demo_history.tcl`    | `Tk`, `mdhelp_history` |
| `demo_clipboard.tcl`  | `Tk`, `mdhelp_search`, `mdhelp_clipboard` |

The internal mdhelp modules (`mdhelp_search`, `mdhelp_history`,
`mdhelp_clipboard`, `mdhelp_pdf`) ship under `lib/tm/`. Each demo
adds that directory to `tcl::tm::path` itself — no manual `auto_path`
manipulation is required.

Note: the demos are Tk smoke tests. The headless test runner
(`tests/run_all_tests.tcl`) covers the underlying modules without
opening any GUI.

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
