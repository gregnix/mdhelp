# mdhelp 4 -- Build Guide

Standalone-Binaries für Linux und Windows erzeugen.

## Voraussetzungen

- `tclsh` 8.6+ (Linux oder Windows mit BAWT)
- **Modul-Setup wie in `README.md` beschrieben** — `~/lib/tcltk/<repo>/`
  oder Sibling-Layout. `build.tcl` greift auf die gleichen Pfade zu wie
  der Laufzeit-Bootstrap und kopiert von dort ins VFS.
- Build-Runtimes in `../runtimes/` (ein Verzeichnis über dem Projekt) —
  **einmalig manuell beschaffen**, wird von allen Projekten gemeinsam genutzt.
  Siehe Setup-Anleitung unten.

## Schnellstart

```bash
# Einmalig: runtimes/ befüllen (siehe runtimes/README.md)

# Bauen
tclsh build.tcl             # Linux + Windows
tclsh build.tcl linux       # nur Linux
tclsh build.tcl windows     # nur Windows
tclsh build.tcl clean       # Artefakte löschen
```

Ergebnis in `dist/`:

```
dist/
  mdhelp-linux-x86_64          # Linux Binary  (~5-8 MB)
  mdhelp-windows-x86_64.exe    # Windows Binary (~5-8 MB)
```

## Wie funktioniert das?

Ein **Starpack** ist eine einzelne ausführbare Datei:

```
[Tclkit-Runtime] + [VFS mit App-Code] = [Standalone-Binary]
```

`build.tcl` baut das VFS, dann wrappen sdx.kit + Tclkit alles zu einer Datei.
Das Windows-Binary wird **cross-compiled** auf Linux erzeugt.

## VFS-Inhalt (wird von build.tcl generiert)

```
mdhelp.vfs/
  main.tcl                   # Einstiegspunkt
  mdhelp_app.tcl             # App (aus app/mdhelp.tcl, Bootstrap-Zeilen entfernt)
  mdhelp_editor.tcl          # (aus app/)
  mdhelp_nav.tcl
  mdhelp_ui.tcl
  mdhelp_search_ui.tcl
  mdhelp_settings.tcl
  applib/                    # mdhelp-eigene Module (aus lib/tm/)
  apptm/                     # docir + mdstack + pdf4tcllib (aus User-Install
                             # ~/lib/tcltk/<repo>/, ueber den mdhelp-bootstrap
                             # ermittelt)
  vendors/pkg/pdf4tcl0.9.4.x/  # 3rd-party pdf4tcl (aus ~/lib/tcltk/pdf4tcl/)
  docs/                      # Eingebettete Dokumentation
```

## Runtimes einrichten (einmalig)

`build.tcl` erwartet `../runtimes/` (ein Verzeichnis über dem Projekt).
Dieses Verzeichnis wird von allen Projekten gemeinsam genutzt.

```bash
mkdir -p ../runtimes
cd ../runtimes

# sdx.kit
wget https://chiselapp.com/user/aspect/repository/sdx/uv/sdx.kit

# BAWT Tclkits herunterladen und entpacken
# Von https://www.tcl3d.org/bawt/apps.html
wget https://www.tcl3d.org/bawt/files/Apps/Tclkits/tclkits-8.6.17.7z
7z e tclkits-8.6.17.7z "*Linux*tk" "*win*tk*"
rm tclkits-8.6.17.7z
chmod +x tclkit-Linux64-tk
```

Ergebnis:
```
../runtimes/
  sdx.kit
  tclkit-Linux64-tk
  tclkit-win64-tk.exe
```

## Hinweise

- **aspell/hunspell**: Kann nicht eingepackt werden (C-Binary + Wörterbücher).
  Muss auf dem Zielsystem installiert sein. Rechtschreibprüfung wird automatisch
  deaktiviert wenn kein Checker verfügbar ist.
- **Tcl 9**: `build.tcl` patcht `package require Tk 8.6` → `8.6-` automatisch.
- **Windows testen**: `wine dist/mdhelp-windows-x86_64.exe`
- **Direktstart** (ohne Build, Tcl/Tk muss installiert sein):
  `wish app/mdhelp.tcl` (Linux) oder `wish app\mdhelp.tcl` (Windows mit BAWT)
