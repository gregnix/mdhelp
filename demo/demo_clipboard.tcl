#!/usr/bin/env wish
# demo_clipboard.tcl — Demo for mdhelp_clipboard-0.1.tm
#
# Shows Copy/SelectAll/context menu in a read-only text widget.
# Start: wish demo_clipboard.tcl

package require Tk

set scriptDir [file dirname [info script]]
::tcl::tm::path add [file join $scriptDir .. lib tm]
package require mdhelp_search 0.1
package require mdhelp_clipboard 0.1

wm title . "mdhelp_clipboard Demo"
wm geometry . 650x500

# ── Info Label ──
ttk::label .info -text "Right-click → Context menu  │  Ctrl+C = Copy  │  Ctrl+A = Select all" \
    -foreground gray
pack .info -fill x -padx 5 -pady 3

# ── Search bar (for "Copy all matches") ──
ttk::frame .search
pack .search -fill x -padx 5

ttk::label .search.lbl -text "Search:"
ttk::entry .search.entry -width 25 -textvariable ::searchPat
ttk::button .search.go -text "Find" -command {
    set n [mdhelp_search::find .t $::searchPat]
    set ::statusMsg "$n matches"
}
ttk::button .search.clear -text "Clear" -command {
    mdhelp_search::clear .t
    set ::statusMsg ""
}
ttk::label .search.status -textvariable ::statusMsg -foreground "#666"

pack .search.lbl .search.entry .search.go .search.clear -side left -padx 2
pack .search.status -side left -padx 10

bind .search.entry <Return> {.search.go invoke}

# ── Text Widget (Read-Only) ──
text .t -wrap word -font {Helvetica 11} -padx 10 -pady 10 \
    -yscrollcommand {.sb set}
ttk::scrollbar .sb -orient vertical -command {.t yview}
pack .sb -side right -fill y
pack .t -fill both -expand 1 -padx 5 -pady 5

# ── Beispielinhalt ──
.t insert end "Markdown-Viewer Dokumentation\n" {h1}
.t insert end "\n"
.t insert end "Der Markdown-Viewer rendert Markdown-Dateien in einem Tk Text-Widget.\n"
.t insert end "Er unterstützt Headings, Listen, Code-Blöcke und Tabellen.\n"
.t insert end "\n"
.t insert end "Features\n" {h2}
.t insert end "\n"
.t insert end "• Named Fonts — eine Stelle für Fontgrößen\n"
.t insert end "• Frame-Tabellen — Zebra, Alignment, Links\n"
.t insert end "• Tag-Priorität — korrekte Erstellungsreihenfolge\n"
.t insert end "• Spacing — keine Lücken in mehrzeiligen Blöcken\n"
.t insert end "\n"
.t insert end "Code-Beispiel\n" {h2}
.t insert end "\n"
.t insert end "    proc greet {name} {\n" {code}
.t insert end "        puts \"Hallo \$name\"\n" {code}
.t insert end "    }\n" {code}
.t insert end "\n"
.t insert end "Tabelle\n" {h2}
.t insert end "\n"
.t insert end "Name\tTyp\tStatus\n" {table_header}
.t insert end "mdviewer\tRenderer\tfertig\n" {table_row}
.t insert end "mdparser\tParser\tfertig\n" {table_row}
.t insert end "mdhelp_pdf\tExport\tfertig\n" {table_row}
.t insert end "\n"
.t insert end "Hinweise\n" {h2}
.t insert end "\n"
.t insert end "Wählen Sie Text aus und drücken Sie Ctrl+C zum Kopieren.\n"
.t insert end "Das Kontextmenü bietet zusätzlich 'Original kopieren' (mit Tabs).\n"
.t insert end "Nach einer Suche können Sie 'Alle Treffer kopieren' verwenden.\n"

# Tags konfigurieren
.t tag configure h1 -font {Helvetica 16 bold} -spacing1 5 -spacing3 5
.t tag configure h2 -font {Helvetica 13 bold} -spacing1 10 -spacing3 3
.t tag configure code -font {Courier 10} -background "#f5f5f5" -lmargin1 20 -lmargin2 20
.t tag configure table_header -font {Helvetica 11 bold} -background "#e0e0e0" -tabs {150 250}
.t tag configure table_row -tabs {150 250}

# Read-Only
.t configure -state disabled

# ── Clipboard + Search einrichten ──
mdhelp_clipboard::setupBindings .t
mdhelp_clipboard::setupContextMenu .t

# ── Paste-Ziel (zur Verifikation) ──
ttk::labelframe .paste -text "Zwischenablage (Ctrl+V hier einfügen)"
pack .paste -fill x -padx 5 -pady 5

text .paste.t -height 4 -font {Courier 9} -wrap word
pack .paste.t -fill x -padx 3 -pady 3

focus .t
