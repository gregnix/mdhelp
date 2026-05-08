#!/usr/bin/env wish
# demo_mdhelp_pdf.tcl -- Demo fuer mdhelp_pdf-0.3.tm
#
# Zeigt beide Export-Wege:
#   1. exportFromWidget  -- Text-Widget -> PDF
#   2. exportFromFile    -- .md-Datei -> PDF
#
# Start: wish demo_mdhelp_pdf.tcl

package require Tk

set scriptDir [file dirname [file normalize [info script]]]
::tcl::tm::path add [file join $scriptDir .. lib tm]

package require mdhelp_pdf 0.3

wm title . "mdhelp_pdf Demo"
wm geometry . 750x600

# ── Demo-Markdown ──────────────────────────────────────────
set demoMd {# mdhelp_pdf Demo

Dieses Dokument testet den PDF-Export aus einem Tk Text-Widget.

## Textformatierung

Normaler Fliesstext mit Umlauten: ä ö ü ß Ä Ö Ü
Und Sonderzeichen: € → ← ✓ • …

## Code-Block

    package require mdhelp_pdf 0.3
    mdhelp_pdf::exportFromWidget .t output.pdf -title "Test"

## Liste

- Erster Punkt
- Zweiter Punkt mit laengerem Text der eventuell umbrochen wird
- Dritter Punkt

## Tabelle

| Spalte A  | Spalte B  | Spalte C  |
|-----------|-----------|-----------|
| Wert 1    | Wert 2    | Wert 3    |
| Alpha     | Beta      | Gamma     |

## Zweite Seite (langer Text)

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod
tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam,
quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo.

### Unterabschnitt

Weiterer Text nach dem Unterabschnitt. pdf4tcllib uebernimmt Unicode-Handling,
Seitenumbruch und Font-Management automatisch.

## Abschluss

Export-Datum wird nicht eingebettet -- das PDF bleibt deterministisch.
}

# ── Layout ────────────────────────────────────────────────
ttk::frame .top
pack .top -fill x -padx 8 -pady 6

# Optionen
ttk::labelframe .top.opts -text "Optionen"
pack .top.opts -fill x

ttk::label .top.opts.ltitle -text "Titel:"
ttk::entry .top.opts.etitle -textvariable ::optTitle -width 30
set optTitle "mdhelp_pdf Demo-Export"

ttk::label .top.opts.lfont -text "Fontgrösse:"
ttk::spinbox .top.opts.sfont -textvariable ::optFontsize \
    -from 8 -to 16 -width 4
set optFontsize 11

ttk::label .top.opts.lmargin -text "Rand (pt):"
ttk::spinbox .top.opts.smargin -textvariable ::optMargin \
    -from 20 -to 80 -width 4
set optMargin 50

ttk::label .top.opts.lsize -text "Papier:"
ttk::combobox .top.opts.csize -textvariable ::optPagesize \
    -values {A4 Letter} -width 8 -state readonly
set optPagesize A4

ttk::checkbutton .top.opts.landscape -text "Querformat" \
    -variable ::optLandscape
set optLandscape 0

ttk::checkbutton .top.opts.debug -text "Debug" \
    -variable ::optDebug
set optDebug 0

grid .top.opts.ltitle   .top.opts.etitle   -sticky w -padx 4 -pady 2
grid .top.opts.lfont    .top.opts.sfont    -sticky w -padx 4 -pady 2
grid .top.opts.lmargin  .top.opts.smargin  -sticky w -padx 4 -pady 2
grid .top.opts.lsize    .top.opts.csize    -sticky w -padx 4 -pady 2
grid .top.opts.landscape - -sticky w -padx 4 -pady 2
grid .top.opts.debug    - -sticky w -padx 4 -pady 2

# Buttons
ttk::frame .top.btns
pack .top.btns -fill x -pady 4

ttk::button .top.btns.bwidget -text "Export aus Widget" \
    -command doExportWidget
ttk::button .top.btns.bfile -text "Export aus Datei" \
    -command doExportFile
ttk::button .top.btns.bopen -text "PDF öffnen" \
    -command doOpen -state disabled

pack .top.btns.bwidget .top.btns.bfile -side left -padx 4
pack .top.btns.bopen -side left -padx 4

# Status
ttk::label .status -textvariable ::statusMsg -foreground "#444"
pack .status -fill x -padx 8 -pady 2

# Trennlinie
ttk::separator .sep -orient horizontal
pack .sep -fill x -padx 8

# Text-Widget mit Demo-Inhalt
ttk::frame .tw
pack .tw -fill both -expand 1 -padx 8 -pady 6

text .tw.t -wrap word -font {TkDefaultFont 10} \
    -yscrollcommand {.tw.sb set}
ttk::scrollbar .tw.sb -orient vertical -command {.tw.t yview}
pack .tw.sb -side right -fill y
pack .tw.t  -fill both -expand 1

.tw.t insert end $demoMd
.tw.t configure -state normal

set lastPdf ""

# ── Prozeduren ────────────────────────────────────────────
proc buildOpts {} {
    return [list \
        -title     $::optTitle \
        -pagesize  $::optPagesize \
        -landscape $::optLandscape \
        -margin    $::optMargin \
        -fontsize  $::optFontsize \
        -debug     $::optDebug]
}

proc doExportWidget {} {
    set outFile [tk_getSaveFile \
        -title "PDF speichern" \
        -defaultextension .pdf \
        -filetypes {{PDF .pdf} {Alle *.*}} \
        -initialfile "demo_widget.pdf"]
    if {$outFile eq ""} return

    set opts [buildOpts]
    set ::statusMsg "Exportiere Widget -> PDF ..."
    update

    if {[catch {
        set pages [mdhelp_pdf::exportFromWidget .tw.t $outFile {*}$opts]
        set ::lastPdf $outFile
        set ::statusMsg "OK: $pages Seite(n) -> [file tail $outFile]"
        .top.btns.bopen configure -state normal
    } err]} {
        set ::statusMsg "FEHLER: $err"
        tk_messageBox -icon error -title "Export fehlgeschlagen" \
            -message $err
    }
}

proc doExportFile {} {
    # Demo-MD in temp-Datei schreiben, dann exportFromFile aufrufen.
    # `file tempfile` ist multiversion-fähig (Tcl 8.6 und 9). Es öffnet
    # gleich einen Schreib-Channel und liefert den Pfad in tmpMd.
    # Hinweis: NICHT `file tempdir` benutzen — das gibt es nur in Tcl 9.
    set fd [file tempfile tmpMd "mdhelp_pdf_demo"]
    fconfigure $fd -encoding utf-8
    puts $fd [.tw.t get 1.0 end-1c]
    close $fd

    set outFile [tk_getSaveFile \
        -title "PDF speichern" \
        -defaultextension .pdf \
        -filetypes {{PDF .pdf} {Alle *.*}} \
        -initialfile "demo_file.pdf"]
    if {$outFile eq ""} return

    set opts [buildOpts]
    set ::statusMsg "Exportiere Datei -> PDF ..."
    update

    if {[catch {
        set pages [mdhelp_pdf::exportFromFile $tmpMd $outFile {*}$opts]
        set ::lastPdf $outFile
        set ::statusMsg "OK: $pages Seite(n) -> [file tail $outFile]"
        .top.btns.bopen configure -state normal
    } err]} {
        set ::statusMsg "FEHLER: $err"
        tk_messageBox -icon error -title "Export fehlgeschlagen" \
            -message $err
    }

    catch {file delete $tmpMd}
}

proc doOpen {} {
    if {$::lastPdf eq "" || ![file exists $::lastPdf]} return
    switch $::tcl_platform(os) {
        Linux   { exec xdg-open $::lastPdf & }
        Darwin  { exec open $::lastPdf & }
        Windows { exec {*}[auto_execok start] "" $::lastPdf & }
    }
}
