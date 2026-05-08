# Changelog

## mdhelp 0.2 (2026-05-06, even later) — About-Dialog erweitert

Der "About mdhelp 4"-Dialog (Help -> About) zeigt jetzt detaillierten
Status der Stack-Komponenten und macht erkennbar, welche Variante
gerade aktiv ist:

- mdpdf: Adapter (-> docir-pdf) oder Legacy (Standalone)
- mdhtml: Adapter (-> docir-html, mit Asset-Copy) oder reine 0.1
- docir: welche Pipeline-Pakete geladen sind (md-source, pdf, html)
- Backend: pdf4tcl-Version, pdf4tcllib-Version (lazy-loaded)
- Tcl/Tk-Version

Erkennt automatisch via info commands welche Implementation
aktiv ist - kein Konfig-Eintrag nötig.


## mdhelp 0.2 (2026-05-06, later) — HTML/PDF Image-Bugs gefixt

Greg meldete: HTML-Export kopiert keine Bilder, PDF-Export zeigt
keine Bilder. Beide Bugs behoben:

### HTML-Export

`mdstack::html::exportFile` kopiert jetzt automatisch alle Bilder ins
Zielverzeichnis (mit erhaltener Pfad-Struktur). `app::exportHtml`
in mdhelp.tcl reicht `-root` durch. Externe URLs (http/https)
werden übersprungen.

### PDF-Export

`docir-pdf` löst jetzt relative Image-Pfade gegen die `root`-Option
auf. mdpdf-Adapter reicht `-root` durch. `app::exportPdf` setzte
das schon korrekt — der Bug war eine Stufe darunter.

PDF-Image-Embedding nutzt jetzt `pdf4tcl::addImage` (Tk-frei,
PNG/JPG werden direkt von Disk geladen statt über Tk-photo).

### Tests
- mdhelp: 179 Tests passing (commonmark 83, mdindexgen 12, mdmodel 22,
  mdpdf 29, mdvalidator 21, pdf_features 12)


## mdhelp 0.2 (2026-05-06, later) — mdpdf-Adapter + docir Phase 3

Re-Vendor mit:
- mdpdf-0.2.tm: jetzt Adapter zu docir-pdf (177 Zeilen statt 1786)
- vendors/docir/: alle docir-Module aktualisiert auf Phase-3-Stand

### Was sich für mdhelp ändert

- TTF-Embedding für Markdown-Export (vorher: nur Standard-PDF-Fonts)
- Hyperlinks in exportierten PDFs sind anklickbar
- Per-Inline-Style: Bold/Italic/Code/Strike sichtbar unterscheidbar
- Header/Footer mit %p-Substitution

### Status
- 179 Tests passing (commonmark 83, mdindexgen 12, mdmodel 22,
  mdpdf 29, mdvalidator 21, pdf_features 12)
- Verifiziert mit testmd.md → 59 KB PDF, 1 Link-Annotation,
  4 Font-Descriptors


## mdhelp 0.2 (2026-05-06, later) — mdpdf-Pin lifted

Following the fix of `mdstack::pdf::_renderBlock` API inconsistency in
upstream mdstack 0.3.4 (same day), the mdpdf-0.2.tm has been
re-vendored with the latest fix.

### Status
- All 179 tests still passing
- mdpdf-Pin from April 2026 lifted
- vendors/tm/README.md updated accordingly


## mdhelp 0.2 (2026-05-06) — Re-Vendor mit DocIR-Bridge

### Was sich geändert hat

mdhelp wurde gegen die aktuelle mdstack-Codebasis re-vendored.
Hauptänderung: **mdhtml ist jetzt ein Adapter zur DocIR-Pipeline**.

### Re-Vendor

15 Module aus mdstack wurden aktualisiert (vendors/tm/):
- mdcontextmenu, mdeditorkit, mdmodel, mdparser, mdsearch,
  mdstack, mdtext, mdtheme, mdvalidator, mdviewer, uicontextmenu
  und mdhtml.

**Bewusst NICHT mit-aktualisiert:** mdpdf-0.2.tm bleibt bei der
April-Version. Grund: in mdstack 0.3.4 (jetziger Stand) hat
mdstack::pdf::_renderBlock interne Aufruf-Inkonsistenzen — drei Aufrufer
(Zeilen 667, 736, 1128) übergeben falsche Argumentanzahl. Das
bricht die test_mdpdf.tcl- und test_pdf_features.tcl-Tests.
Sobald mdstack diesen Bug gefixt hat, kann beim nächsten
Re-Vendor auch mdpdf mitziehen.

### Neue DocIR-Bridge

- `vendors/docir/` — komplettes docir-Repo gevendored (10 Module)
- `lib/docir-loader.tcl` — findet docir-Repo zur Runtime

mdhtml-0.1.tm wurde durch einen Adapter ersetzt der intern die
DocIR-Pipeline nutzt:

```
mdparser → mdstack::html::render → docir-md-source::fromAst
                          → docir-html::render → HTML
```

Public API von mdhtml ist 1:1 erhalten — kein Aufrufer in
mdhelp braucht eine Anpassung.

### Markdown-Vollabdeckung im HTML-Export

Über die DocIR-Pipeline kommt der mdhelp-HTML-Export nun mit
allen Markdown-Features klar:

- `~~strike~~` → `<s>strike</s>`
- Hard line break → `<br/>`
- `![alt](url)` → `<figure><img/><figcaption>` (Block-Image)
- `[^1]`-Footnotes → bidirektional verlinkt mit Back-Link
- TIP-700 `:::div` und `[span]{.class}` Container

Im April-Stand der mdhtml-V0.1 waren mehrere dieser Features
degraded oder gecrashed (siehe demo/test-complete.md im
mdstack-Repo).

### Test-Status nach Re-Vendor

| Test | April | Mai (jetzt) |
|---|---|---|
| test_commonmark.tcl | 83 ✓ | 83 ✓ |
| test_mdindexgen.tcl | 12 ✓ | 12 ✓ |
| test_mdmodel.tcl | 22 ✓ | 22 ✓ |
| test_mdpdf.tcl | 29 ✓ | 29 ✓ |
| test_mdvalidator.tcl | 21 ✓ | 21 ✓ |
| test_pdf_features.tcl | 12 ✓ | 12 ✓ |

**Alle 179 Tests grün** wie zuvor — keine Regressionen.

### Interner Sync

Wer mdhelp re-vendored: das aktualisierte vendors/tm/README.md
listet jetzt die DocIR-Bridge plus den mdpdf-Pin.

# Changelog

## mdhelp 0.1 (2026-04-12)

Initial public release.

### Features

- Markdown viewer with live preview (mdviewer 0.3)
- Integrated editor with syntax highlighting
- PDF export via pdf4tcl (mdpdf 0.2)
- Full-text search across all documents
- Tabs, themes (light/dark/solarized)
- Document outline panel
- TIP-700 support: definition lists, fenced divs, footnotes, spans
- YAML frontmatter panel (title/section/version)
- Keyboard shortcuts, bookmarks, navigation history
- Index generator (mdindexgen)

### Built on

- mdstack 0.3.4 (parser, viewer, PDF renderer)
- pdf4tcllib 0.2
- pdf4tcl 0.9.4.25
- DejaVu Sans Condensed fonts
