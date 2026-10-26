# mdhelp 5: Einzeldatei bauen

mdhelp 5 läuft als **eine Datei** je Plattform, ohne installiertes Tcl:

| Plattform | Ergebnis | Grundlage |
|---|---|---|
| Linux x86_64 | `dist/mdhelp-linux-x86_64` | statisches `wish` 9 mit zipfs (Zipkit) |
| Windows x64 | `dist/mdhelp-windows-x86_64.exe` | dasselbe für Windows, auch unter Linux baubar |
| macOS | `dist/mdhelp.app` | App-Bündel mit dem BAWT-`wish9.0`, nur auf dem Mac |

Bis mdhelp 4 entstanden die Dateien als Starpack aus Tclkit 8.6 und
`sdx.kit`. Mit Tcl 9 ist das Einpacken eingebaut (`zipfs mkimg`); sdx,
Tclkit und Metakit entfallen. Hintergrund: Buch *Tcl ausliefern*, Kapitel
„Zipkits bauen und füllen“, und *Tcl/Tk unter macOS*, Kapitel „Programm
als App weitergeben“.

## Voraussetzungen

Ein `tclsh9.0` zum Bauen (das eigene `/opt/tcl9` oder das tclsh-Kit) und
neben dem mdhelp-Ordner:

```
../runtimes/
    zipkit-9_0_4-linux-x64-wish        statisches wish 9 (BAWT oder selbst gebaut)
    zipkit-9_0_4-win64-wish.exe        dasselbe für Windows
    app-bauen.sh                        nur macOS, aus book-macos-tcltk/beispiele/
../libs/common/
    docir/ mdstack/ pdf4tcllib/ pdf4tcl/ tclutils/ tkutils/
    tcldocs-config/ tcldocs-launcher/
    man-viewer/      optional: Manpages (.n) anzeigen
    tablelist7.12/   optional: braucht tkutils (Dialoge, Tooltips)
    fonts/           optional: DejaVu*.ttf, sonst /usr/share/fonts/truetype/dejavu
../libs/linux-tcl9.0/  ../libs/windows-tcl9.0/  ../libs/macos-tcl9.0/
    Img*/ imgtools*/ tclpdfium/ …   binäre Pakete je Plattform (optional)
```

Die Kits werden am **Inhalt** erkannt, nicht am Namen allein: Der Name
muss `linux` bzw. `win…​.exe` enthalten, und die Datei muss ein ZIP mit
`tcl_library/init.tcl` und `tk_library/tk.tcl` tragen. Ein altes Tclkit
8.6 oder ein `tclsh`-Kit ohne Tk wird übergangen. Ausdrücklich angeben:
`-kit DATEI` oder `MDHELP_KIT_LINUX` / `MDHELP_KIT_WINDOWS`.

Jede Bibliothek lässt sich einzeln umlenken: `DOCIR_HOME`,
`MDSTACK_HOME`, `PDF4TCLLIB_HOME`, `PDF4TCL_HOME`, `TCLUTILS_HOME`,
`TKUTILS_HOME`, `TCLDOCS_CONFIG_HOME`, `TCLDOCS_LAUNCHER_HOME`,
`MANVIEWER_HOME`, `TABLELIST_HOME`; die Plattformschicht mit
`MDHELP_LIBS`, die Schriften mit `MDHELP_FONTS`.

## Bauen

```bash
tclsh9.0 build.tcl              # alles, wofür ein Kit da ist
tclsh9.0 build.tcl linux
tclsh9.0 build.tcl windows
tclsh9.0 build.tcl macos        # auf Linux: nur Stage + Aufruf für den Mac
tclsh9.0 build.tcl stage linux  # nur build/stage-linux/ anlegen, nicht packen
tclsh9.0 build.tcl clean
```

Gemessen am 2026-10-22 (Linux, selbst gebautes statisches wish 9.0.4):
Stage 1 289 Dateien, 14 MB; Datei 8,8 MB.

## Was in der Datei steckt

```
main.tcl                 Einstieg: Suchpfade nur aus dem Bundle
tcl_library/ tk_library/ aus dem Kit (zipfs mkimg ersetzt dessen ZIP)
app/                     wie im Quellbaum
lib/tm/                  mdhelp-eigene Module (ohne mdhelp_search 0.1)
lib/ext/                 docir, mdstack, pdf4tcllib, tclutils, tkutils,
                         tcldocs, nroffparser -- nur .tm, keine Tests/Demos
lib/pkg/pdf4tcl/         nur die Laufzeitdateien von pdf4tcl
lib/pkg/tablelist7.12/   ohne doc/ und demos/
lib/bin/                 binäre Pakete NUR dieser Plattform
lib/fonts/               DejaVu für den PDF-Export
docs/ styles/
```

Gegenüber mdhelp 4:

- **Nur die eigene Plattform.** Das VFS von mdhelp 4 trug alle vier
  Schichten (Linux und Windows, je 8.6 und 9.0) und den ganzen
  pdf4tcl-Checkout samt `nogit/`, Demos und Tests (14 MB). Jetzt kommen
  nur die Laufzeitdateien hinein.
- **Kein fremdes Paket.** Tcl-9-Zipkits übernehmen `TCLLIBPATH` und
  `TCL9_0_TM_PATH` des Rechners und den Installationspfad des Kits.
  `main.tcl` lässt nur Pfade unter `//zipfs:/` (und im macOS-Bündel
  unter `mdhelp.app/Contents`) stehen. Gemessen: Start mit `env -i`, also
  ganz ohne Umgebung, läuft.
- **Schriften im Bundle.** Windows und macOS haben kein DejaVu;
  pdf4tcllib findet die Schriften unter `lib/fonts`
  (`<modul>/../fonts`). Gemessen: `TTF faces loaded from
  //zipfs:/app/lib/ext/../fonts`.
- **tkutils, tclutils und Manpages sind dabei.** mdhelp 4 packte sie
  nicht ein; Systeminfo, Dialoge, Tooltips und `.n`-Dateien fehlten in
  der Einzeldatei.

## Prüfen: `--selftest`

```bash
./mdhelp-linux-x86_64 --selftest            # Bericht im aktuellen Ordner
mdhelp-windows-x86_64.exe --selftest C:\temp
mdhelp.app/Contents/MacOS/mdhelp --selftest ~/Desktop
```

Startet mdhelp, öffnet die eingebaute Hilfe, exportiert ein PDF und
schreibt `mdhelp-selftest.txt` und `mdhelp-selftest.pdf`. Exit-Status 0,
wenn alle nötigen Teile da sind. Der Bericht nennt Tcl/Tk, Plattform,
jedes Paket mit Version (optionale mit dem Grund, warum sie fehlen), die
Schrift im PDF und ersetzte Zeichen. Unter Windows hat `wish` keine
Konsole, deshalb die Datei.

## macOS

Ein Zipkit ist auf dem Mac keine gute Lösung: Der Finder startet eine
nackte Datei nicht als App, und das angehängte ZIP liegt außerhalb des
Mach-O, sodass `codesign` nicht sauber signieren kann. mdhelp kommt
deshalb als App-Bündel nach dem gemessenen Weg aus dem macOS-Buch:

1. `/opt/tcl9` (BAWT) umhängen, Buch *Tcl/Tk unter macOS*, Kapitel 105.
2. `beispiele/app-bauen.sh` aus dem Buch nach `../runtimes/` kopieren
   (oder `MDHELP_APPBAUEN=/pfad/app-bauen.sh`).
3. Auf dem Mac `tclsh9.0 build.tcl macos`. Das baut `build/stage-macos/`
   und ruft

   ```bash
   zsh app-bauen.sh -n mdhelp -d build/stage-macos -m main.tcl \
       -p "Img imgtools" -b de.gregnix.mdhelp -v 5.0 -o dist -t "md markdown txt"
   ```

   `app-bauen.sh` kopiert die Stage nach `Resources/app`, holt Tcl, Tk,
   Img und imgtools samt dylibs, schreibt `AppMain.tcl` und `Info.plist`
   und signiert ad hoc.
4. `dist/mdhelp.app/Contents/MacOS/mdhelp --selftest ~/Desktop`

Ist `icons/mdhelp.icns` vorhanden, bekommt die App das Symbol. Dateien,
die im Finder auf mdhelp gezogen werden, öffnet `::tk::mac::OpenDocument`.

**Nicht gemessen** (Stand 2026-10-22): der ganze macOS-Weg mit mdhelp.
`app-bauen.sh` ist mit einem kleineren Programm gemessen; ob mdhelp so
startet, zeigt erst `--selftest` auf dem Mac. tclpdfium für macOS gibt
es noch nicht; ohne sie fehlt nur die PDF-Vorschau.

## Windows

Unter Linux gebaut, aber hier nicht ausgeführt. Bekannt aus dem Tcl-Wiki
(*Single file applications in Tcl 9*): Binäre Pakete (Img, imgtools,
tclpdfium, sqlite3) kopiert Tcl bei jedem Start in den Temp-Ordner und
räumt sie nicht weg. Prüfen: nach ein paar Starts `%TEMP%` ansehen.

## Fallen

- **Kit nicht statisch.** `ldd` auf dem Kit darf kein `libtcl9.0.so`
  zeigen. Ein dynamisch gebautes wish läuft nur, wo Tcl installiert ist.
- **`file copy` in ein vorhandenes Verzeichnis** legt die Kopie darin ab.
  `build.tcl` löscht die Stage deshalb vor jedem Lauf ganz.
- **Punktdateien.** `zipfs mkimg` packt auch `.git` und `.svn`; die
  Stage enthält keine.
- **Icon unter Windows** erst *vor* `mkimg` setzen, sonst ist das ZIP
  abgeschnitten (Buch *Tcl ausliefern*, Kapitel 100).
