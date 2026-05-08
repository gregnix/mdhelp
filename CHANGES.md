## 2026-05-07 (later4) – Standard-Tcl pkgIndex.tcl-Konvention

### Was sich aendert

Setup-Code in Apps/Tests/Demos auf reines Standard-Tcl reduziert:

- **bootstrap.tcl / _paths.tcl Helper komplett entfernt** in allen Repos
- **pkgIndex.tcl** in jedes Modul-Verzeichnis (auto-generiert via
  `tools/generate-pkgindex.tcl`)
- **Programm-Code minimal**: nur `tcl::tm::path add` fuer eigene
  Module, externe ueber Standard `package require`

### Verzeichnis-Layout (Standard-Tcl-Konvention)

```
/usr/local/lib/tcltk/<repo>/        ← Standard-Pfad in Tcls auto_path
├── pkgIndex.tcl                    ← package ifneeded fuer alle Module
├── <repo>-X.Y.tm                   ← Hub-Modul direkt
└── <repo>/                         ← Sub-Namespace-Modules
    ├── sub1-X.Y.tm
    └── ...
```

### pkgIndex.tcl-Stil (explicit `package ifneeded`)

```tcl
package ifneeded docir            0.1  [list source -encoding utf-8 [file join $dir docir-0.1.tm]]
package ifneeded docir::roff      0.1  [list source -encoding utf-8 [file join $dir docir roff-0.1.tm]]
package ifneeded docir::html      0.1  [list source -encoding utf-8 [file join $dir docir html-0.1.tm]]
# ...
```

Lazy-Load (Tcl sourct erst bei `package require`), explizit, keine
State-Mutation der `tcl::tm::path`-Liste.

### make install / make install-user

Jedes Repo hat jetzt Makefile mit:

- `make install` → `/usr/local/lib/tcltk/<repo>/` (sudo evtl. noetig)
- `make install-user` → `~/lib/tcltk/<repo>/` (mit Hinweis auf TCLLIBPATH)
- `make pkgindex` → pkgIndex.tcl neu generieren
- `make uninstall`, `make test`, `make help`

### Generator-Tool

`tools/generate-pkgindex.tcl` scannt ein Modul-Verzeichnis und schreibt
oder gibt eine pkgIndex.tcl aus. Pattern: `<dir>/foo-X.Y.tm` und
`<dir>/foo/bar-X.Y.tm` (ein-Ebene-tief Sub-Namespaces).

### Programm-Code-Beispiele

**App (mdhelp.tcl):**
```tcl
package require Tk 8.6-

# Eigene Module aus lib/tm/ (Entwicklungs-Modus; im Starpack im VFS)
set appDir [file dirname [file normalize [info script]]]
::tcl::tm::path add [file join $appDir .. lib tm]

# Externe Module via auto_path (/usr/local/lib/tcltk/...)
package require mdstack::parser
package require docir
# ... fertig.
```

**Tests (test_xyz.tcl):**
```tcl
::tcl::tm::path add [file join [file dirname [info script]] .. lib tm]
package require mdhelp_search
# ...
```

Wenn ein Modul fehlt → Standard-Tcl-Fehler `can't find package X`.
Keine Magic-Fallbacks, keine "ich-suche-an-5-Stellen"-Logik.

### Geaenderte Files

**Geloescht:**
- `mdhelp4/lib/bootstrap.tcl`
- `mdstack/tests/_paths.tcl`
- `mdstack/demo/_paths.tcl`
- `man-viewer/bin/_paths.tcl`

**Vereinfacht:**
- `mdhelp4/app/mdhelp.tcl` (1 Zeile statt 3)
- `mdhelp4/build.tcl` (ENV-Variablen statt bootstrap)
- `mdstack/tests/*.tcl` (1-Zeile auto_path-Setup)
- `mdstack/demo/*.tcl` (analog)
- `man-viewer/app/man-viewer.tcl` (Helper-proc raus)
- `man-viewer/app/mdviewer-docir-demo.tcl` (analog)
- `man-viewer/tests/test-setup.tcl` (analog)
- `man-viewer/bin/*` (Helper-source raus)
- `docir/tests/test-setup.tcl` (Sibling-Such-Logik raus)

**Neu:**
- `tools/generate-pkgindex.tcl` (in jedem Repo)
- `pkgIndex.tcl` (in jedem Modul-Verzeichnis)
- `Makefile` (in jedem Repo)

### Tests

Alle 4 Repos gruen:
- docir 559/559
- mdstack 569+
- mdhelp4 6/6 Suites
- man-viewer 67/67

### Lessons

54. **`tclsh script.tcl` liest `~/.tclshrc` NICHT** — nur interaktiv.
    Greg's anfaenglicher Vorschlag mit User-tm-path in `~/.tclshrc`
    funktioniert nicht out-of-the-box fuer nicht-interaktive Skripte.

55. **`auto_path` hat ENV-Variable `TCLLIBPATH`, `tcl::tm::path` nicht.**
    Klassische pkgIndex.tcl-Packages koennen via Env-Var konfiguriert
    werden, reine TM-Module nur per Programm-Code oder System-Standard-Pfad.

56. **`/usr/local/lib/tcltk/` ist Standard in `auto_path` auf
    Linux/macOS** — fuer klassische Packages mit `pkgIndex.tcl`. Damit
    sind Repos die einer pkgIndex.tcl haben aus `/usr/local/lib/tcltk/<repo>/`
    automatisch via `package require` erreichbar, ohne Setup im Programm.

57. **pkgIndex.tcl und TM-Module koexistieren konfliktfrei**: pkgIndex.tcl
    sourct die `.tm`-Files via `package ifneeded` mit `source -encoding utf-8`.
    Die `.tm`-Files behalten ihre `package provide`-Konvention. TIP-189
    Sub-Namespace-Mapping (`docir::roff` → `docir/roff-X.Y.tm`) wird
    in der pkgIndex.tcl explizit aufgelistet.

58. **Greg's "keine stillen Fehler / keine Fallbacks"-Maxime**: Programm
    macht NUR explizite Pfad-Adds (eigene Module). Wenn etwas Fehlt:
    Standard-Tcl `can't find package`. Klar diagnostizierbar. Setup ist
    Verantwortung des User (via `make install` oder TCLLIBPATH).
## 2026-05-07 (later) – Konsumenten-Update fuer Tcl Module Namespace-Refactor

Folgereaktion auf docir + mdstack Major-Refactor desselben Tages:
beide Repos haben kanonisches Tcl Module System mit Namensraum-
Hierarchie eingefuehrt.

### Geaenderte Imports

`app/mdhelp.tcl` und alle Tests/Demos: `package require`-Zeilen
auf neue Modul-Namen umgestellt:

```
package require mdstack::parser     ->  mdstack::parser
package require mdstack::viewer     ->  mdstack::viewer
package require mdstack::model      ->  mdstack::model
package require mdstack::validator  ->  mdstack::validator
package require mdstack::html       ->  mdstack::html
package require mdstack::pdf        ->  mdstack::pdf
package require mdstack::theme      ->  mdstack::theme
package require mdstack::text       ->  mdstack::text
package require mdstack::outline    ->  mdstack::outline
package require mdstack::contextmenu ->  mdstack::contextmenu
package require mdstack::editorkit  ->  mdstack::editorkit
```

mdhelp-eigene Module (`mdhelp_search`, `mdhelp_history`,
`mdhelp_clipboard`, `mdhelp_pdf`, `mdindexgen`, `mdspellcheck`,
`mdeditor`, `mdeditwidget`) bleiben mit alten Namen — sie sind
nicht Teil des refactor-Scope.

### Bootstrap unveraendert

`lib/bootstrap.tcl` funktioniert weiter — die Pfad-Listen fuer
docir, mdstack, pdf4tcllib haben sich nicht geaendert. Nur was IN
diesen Pfaden liegt ist anders organisiert (Sub-Verzeichnisse).
Das Standard Tcl Module System findet alle Sub-Module automatisch.

### Tests

- 6/6 Suites gruen
# mdhelp 4 — Changelog

## 2026-05-07 – Vendoring-Cleanup (Phase 4 / Item 5)

### Architektur-Aenderung

mdhelp4 hatte bisher **alle externen Module** (docir, mdstack, pdf4tcl,
pdf4tcllib) als Kopien unter `vendors/` im Repo. Das war Quelle
permanenten Drift-Risikos: bei jeder API-Aenderung in docir oder mdstack
musste manuell synchronisiert werden, sonst lief mdhelp4 mit veralteten
Module-Kopien — was waehrend der Phase-4-Arbeiten **mehrfach** beinahe
zu Bugs gefuehrt hat.

Nach Diskussion mit dem Repo-Owner: **vendors/ komplett raus**. Externe
Module kommen ueber `package require` aus User-lokalem Install-Pfad
(`~/lib/tcltk/<repo>/`) oder als Sibling-Repo waehrend der Entwicklung.

### Neue Architektur

```
mdhelp4/
├── lib/
│   ├── bootstrap.tcl    NEU: Modul-Pfade konfigurieren
│   └── tm/              mdhelp-eigene Module (mdeditor, mdhelp_pdf, ...)
├── app/
├── tests/
├── demo/
└── (vendors/ ist weg)
```

### `lib/bootstrap.tcl`

Neue zentrale Stelle, die fuer alle mdhelp-Einstiegspunkte (App, Tests,
Demos) die Modul-Pfade konfiguriert:

```
docir       → ~/lib/tcltk/docir   oder ../docir/lib/tm
mdstack     → ~/lib/tcltk/mdstack oder ../mdstack[_VERSION]/lib
pdf4tcllib  → ~/lib/tcltk/pdf4tcllib oder ../pdf4tcllib/lib
pdf4tcl     → ~/lib/tcltk/pdf4tcl/ als auto_path (klassisches Tcl-Package)
mdhelp eigene → mdhelp4/lib/tm/
```

User-lokaler Install hat Vorrang vor Sibling-Pfad. Wenn ein Repo nicht
gefunden wird, gibt der Bootstrap eine klare Fehlermeldung mit den
gesuchten Pfaden aus, bevor `package require` fehlschlaegt.

### Aenderungen im Detail

**Verschoben** — 3 mdhelp-eigene Module aus `vendors/tm/` nach `lib/tm/`:
- `mdeditor-0.1.tm`
- `mdeditwidget-0.2.tm`
- `mdhelp_pdf-0.3.tm`

**Geloescht** — `vendors/` komplett:
- `vendors/tm/` (15 mdstack-Kopien + 1 pdf4tcllib-Kopie)
- `vendors/docir/` (10 docir-Kopien)
- `vendors/pkg/pdf4tcl0.9.4.25/` (1 pdf4tcl-Kopie)
- `vendors/fonts/` (DejaVu-TTFs — pdf4tcllib findet System-Fonts)

**Geloescht** — toter Code:
- `lib/docir-loader.tcl` (alter Loader, nie integriert; durch `bootstrap.tcl` ersetzt)

**Umgestellt auf Bootstrap** — alle Einstiegspunkte:
- `app/mdhelp.tcl`
- `tests/test_commonmark.tcl`
- `tests/test_mdmodel.tcl`
- `tests/test_mdvalidator.tcl`
- `tests/test_mdpdf.tcl`
- `tests/test_pdf_features.tcl`
- `tests/test_mdindexgen.tcl`
- `demo/demo_clipboard.tcl`
- `demo/demo_history.tcl`
- `demo/demo_search.tcl`
- `demo/demo_mdhelp_pdf.tcl`

**Aufgeraeumt** — `lib/tm/mdhelp_pdf-0.3.tm`:
- entfernte den eigenen `vendors/tm/`-Pfad-Lookup-Block (Bootstrap macht das jetzt zentral)

**Build-Tool-Anpassung** — `build.tcl`:
- holt Module nicht mehr aus `vendors/` sondern aus den Bootstrap-Pfaden
  (`::mdhelp::bootstrap::loaded(<repo>)`)
- `mdhelp_app.tcl`-Filter erweitert: entfernt die Bootstrap-Source-Zeilen,
  damit das VFS-Starpack autark bleibt
- main.tcl-Template (im VFS) unveraendert: VFS hat seine eigene
  `applib/apptm/vendors/pkg/` Struktur

### README + BUILD.md Bauanleitung

Neue Sektion in `README.md`: **Setup**. Dokumentiert Schnell-Setup
(Symlinks aus `~/src/<repo>` nach `~/lib/tcltk/<repo>`), Sibling-Layout
fuer Entwicklung, Verifikations-Snippet.

`BUILD.md` aktualisiert: Voraussetzungen verweisen auf README's Setup,
VFS-Beschreibung erklaert woher `apptm/` und `vendors/pkg/` befuellt
werden.

### Testlauf nach Cleanup

| Repo | Tests | Status |
|------|-------|--------|
| docir | 533/533 | ✅ |
| mdstack | 569/569 | ✅ |
| mdhelp4 | 6 Suites | ✅ |
| man-viewer | 67/67 | ✅ |

### Lessons

46. **Vendoring war fuer mdhelp4 nie wirklich noetig.** Die gewollte
    Eigenstaendigkeit fuer Distribution bleibt erhalten ueber den
    **Starpack-Build** (build.tcl) — dort werden die Module beim Bauen
    aus dem User-Install ins VFS gezogen. Im laufenden Betrieb bei
    Entwicklung/Tests/Demos kommt alles via `package require`. Dieser
    Trennung von Build-Time- und Run-Time-Dependency-Handling war im
    alten Setup durchmischt: `vendors/` war beides gleichzeitig, was
    der wesentliche Grund fuer den Drift war.

47. **Bootstrap als zentrale Pfad-Wahrheit zahlt sich mehrfach aus.**
    Sobald man einen Bootstrap hat, kann auch `build.tcl` ihn nutzen —
    und das VFS-Build wird konsistent mit der Run-Time-Konfiguration.
    Vorher waren das zwei unabhaengige Pfad-Listen.

48. **`tcl::tm::path` und Sub-Verzeichnisse:** Tcl warnt wenn ein Pfad
    Sub-Verzeichnis eines anderen Pfads in `tcl::tm::path` ist. Heisst:
    Layout muss konsistent sein — alle Repos in eigenen Sub-Verzeichnissen
    oder direkt im selben flachen Verzeichnis, nicht gemischt. Ich hatte
    erst `~/lib/tcltk/` plus `~/lib/tcltk/docir/` parallel, das gab die
    Warnung. Loesung: nur Sub-Verzeichnisse, kein generischer
    `~/lib/tcltk/`-Eintrag.
