#!/usr/bin/env tclsh
# tools/glossary-export.tcl
#
# Exportiert das Glossar aus docs/tcl9-de/README.md als CSV-Dateien
# zum Upload bei DeepL.
#
# Master-Quelle:  docs/tcl9-de/README.md  (Markdown-Tabelle)
# Output:
#   docs/tcl9-de/glossary-en-de.csv  (Englisch -> Deutsch)
#   docs/tcl9-de/glossary-de-en.csv  (Deutsch -> Englisch)  [optional]
#
# Aufruf:
#   tclsh tools/glossary-export.tcl                  # nur en->de
#   tclsh tools/glossary-export.tcl --both           # beide Richtungen
#   tclsh tools/glossary-export.tcl --readme PATH    # eigener README-Pfad
#
# CSV-Format: Header "source,target", danach Zeilen src,tgt mit
# Doppel-Quote-Quoting falls noetig (DeepL-Standardformat).

# ============================================================
# CLI-Parsing
# ============================================================
set scriptDir [file dirname [file normalize [info script]]]
set repoRoot  [file dirname $scriptDir]

set opt(readme)  [file join $repoRoot docs tcl9-de README.md]
set opt(outDir)  [file join $repoRoot docs tcl9-de]
set opt(both)    0
set opt(verbose) 0

set i 0
while {$i < [llength $argv]} {
    set arg [lindex $argv $i]
    switch -- $arg {
        --both    { set opt(both) 1 }
        --verbose -
        -v        { set opt(verbose) 1 }
        --readme  { incr i ; set opt(readme) [lindex $argv $i] }
        --out-dir { incr i ; set opt(outDir) [lindex $argv $i] }
        --help -
        -h {
            puts "Usage: glossary-export.tcl ?--both? ?--readme PATH? ?--out-dir DIR?"
            exit 0
        }
        default {
            puts stderr "Unbekannte Option: $arg"
            exit 2
        }
    }
    incr i
}

if {![file exists $opt(readme)]} {
    puts stderr "README nicht gefunden: $opt(readme)"
    exit 1
}

# ============================================================
# Markdown-Glossar-Tabelle parsen
# ============================================================
proc parseGlossary {readmePath} {
    set fh [open $readmePath r]
    fconfigure $fh -encoding utf-8
    set content [read $fh]
    close $fh

    set inGlossary 0
    set rows {}

    foreach line [split $content "\n"] {
        # Sektion erkennen: erste H2/H3 mit "Glossar" im Titel
        if {[regexp -nocase {^##+ .*glossar} $line]} {
            set inGlossary 1
            continue
        }
        # Verlassen bei naechster Sektion
        if {$inGlossary && [regexp {^##+ } $line]} {
            break
        }
        if {!$inGlossary} continue

        # Tabellen-Zeilen erkennen: |...|...|...|
        if {![regexp {^\|} [string trim $line]]} continue

        # Separator-Zeile: |---|---|
        if {[regexp {^\|[\s\-:|]+\|?\s*$} $line]} continue

        # In Spalten splitten
        set raw [string trim $line "|"]
        set raw [string trim $raw]
        set cols [split $raw "|"]
        if {[llength $cols] < 2} continue

        set src [string trim [lindex $cols 0]]
        set tgt [string trim [lindex $cols 1]]

        # Header-Zeile (Englisch / Deutsch / English / German) ueberspringen
        if {[string equal -nocase $src "Englisch"] \
                || [string equal -nocase $src "English"] \
                || [string equal -nocase $src "Source"]} continue

        # Leere Eintraege ignorieren
        if {$src eq "" || $tgt eq ""} continue

        lappend rows [list $src $tgt]
    }
    return $rows
}

# ============================================================
# CSV-Quoting (RFC 4180-Stil, kompatibel mit DeepL-Import)
# ============================================================
proc csvQuote {field} {
    if {[string match "*,*" $field] \
            || [string match "*\"*" $field] \
            || [string match "*\n*" $field]} {
        set escaped [string map {\" \"\"} $field]
        return "\"$escaped\""
    }
    return $field
}

# ============================================================
# CSV schreiben
# ============================================================
proc writeCsv {path rows reverse header} {
    set fh [open $path w]
    fconfigure $fh -encoding utf-8 -translation lf
    puts $fh $header
    foreach pair $rows {
        lassign $pair s t
        if {$reverse} {
            puts $fh "[csvQuote $t],[csvQuote $s]"
        } else {
            puts $fh "[csvQuote $s],[csvQuote $t]"
        }
    }
    close $fh
}

# ============================================================
# Main
# ============================================================
set rows [parseGlossary $opt(readme)]

if {[llength $rows] == 0} {
    puts stderr "Keine Glossar-Eintraege in $opt(readme) gefunden."
    exit 1
}

if {$opt(verbose)} {
    puts "Geparste Eintraege: [llength $rows]"
    foreach r $rows {
        puts "  [lindex $r 0] -> [lindex $r 1]"
    }
}

# Englisch -> Deutsch
set out1 [file join $opt(outDir) glossary-en-de.csv]
writeCsv $out1 $rows 0 "source,target"
puts "Geschrieben: $out1 ([llength $rows] Eintraege)"

# Optional: andere Richtung
if {$opt(both)} {
    set out2 [file join $opt(outDir) glossary-de-en.csv]
    writeCsv $out2 $rows 1 "source,target"
    puts "Geschrieben: $out2 ([llength $rows] Eintraege)"
}

puts ""
puts "Hinweis: Diese CSVs koennen in DeepL Pro Starter unter"
puts "        Account -> Glossare -> Importieren  hochgeladen werden."
puts "        Format-Auswahl beim Upload: 'Source: EN, Target: DE'"
puts "        (oder umgekehrt fuer glossary-de-en.csv)"
