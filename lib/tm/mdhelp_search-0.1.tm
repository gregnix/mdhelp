# mdhelp_search-0.1.tm
#
# Search module for mdhelp — Widget search and cross-document search.
# Extracted from mdhelp_render-0.3.2, standalone without renderer dependency.
#
# Requirements:
#   Tcl 8.6+ (9.x compatible)
#   Tk (for text widget operations)
#
# Widget search (in text widget):
#   mdhelp_search::init $t               → Set up tags
#   mdhelp_search::find $t $pattern      → Search, highlight matches
#   mdhelp_search::clear $t              → Remove highlights
#   mdhelp_search::next $t               → Next match
#   mdhelp_search::prev $t               → Previous match
#   mdhelp_search::count $t              → Number of matches
#   mdhelp_search::current $t            → Current index
#   mdhelp_search::highlightCurrent $t   → Highlight current
#   mdhelp_search::scrollToCurrent $t    → Scroll to current
#   mdhelp_search::copyAll $t            → Copy all matches
#
# Global search (across files):
#   mdhelp_search::scanFiles $root              → Find .md files
#   mdhelp_search::searchFile $file $pattern    → Search one file
#   mdhelp_search::searchAll $root $pattern     → Search all files
#   mdhelp_search::countAllHits $results        → Count hits
#   mdhelp_search::formatResults $results ?root? → Format results

package require Tcl 8.6-

package provide mdhelp_search 0.1

namespace eval mdhelp_search {
    namespace export init find clear next prev count current \
                     highlightCurrent scrollToCurrent copyAll \
                     scanFiles searchFile searchAll countAllHits formatResults

    variable state
    # state($t,pattern)  - Search pattern
    # state($t,matches)  - List of {start end}
    # state($t,current)  - Current match index (-1 = none)
}

proc mdhelp_search::init {t} {
    # Initializes search tags for the widget.
    # Called automatically on first find.
    variable state

    # Match highlighting (yellow)
    $t tag configure searchHit \
        -background "#ffe066" \
        -foreground black

    # Current match (orange, highlighted)
    $t tag configure searchCurrent \
        -background "#ff9933" \
        -foreground black

    # Tag priority: searchCurrent above searchHit
    $t tag raise searchCurrent searchHit

    # Initialize state
    set state($t,pattern) ""
    set state($t,matches) {}
    set state($t,current) -1
}

proc mdhelp_search::find {t pattern} {
    # Searches for pattern in text widget.
    # Returns number of matches.
    #
    # - Case-insensitive
    # - Plain text (no regex)
    # - Marks all matches

    variable state

    # Initialize tags if needed
    if {![info exists state($t,pattern)]} {
        mdhelp_search::init $t
    }

    # Remove old highlights
    $t tag remove searchHit 1.0 end
    $t tag remove searchCurrent 1.0 end

    # Empty search = reset
    if {$pattern eq ""} {
        set state($t,pattern) ""
        set state($t,matches) {}
        set state($t,current) -1
        return 0
    }

    # Perform search
    set matches {}
    set idx "1.0"
    set patLen [string length $pattern]

    while {1} {
        set pos [$t search -nocase -- $pattern $idx end]
        if {$pos eq ""} break

        set endPos [$t index "$pos + $patLen chars"]
        lappend matches [list $pos $endPos]

        # Weiter nach diesem Treffer
        set idx $endPos
    }

    # State aktualisieren
    set state($t,pattern) $pattern
    set state($t,matches) $matches

    # Alle Treffer markieren
    foreach m $matches {
        lassign $m s e
        $t tag add searchHit $s $e
    }

    # Zum ersten Treffer springen (falls vorhanden)
    if {[llength $matches] > 0} {
        set state($t,current) 0
        mdhelp_search::highlightCurrent $t
        mdhelp_search::scrollToCurrent $t
    } else {
        set state($t,current) -1
    }

    return [llength $matches]
}

proc mdhelp_search::clear {t} {
    # Entfernt alle Such-Markierungen.
    variable state

    $t tag remove searchHit 1.0 end
    $t tag remove searchCurrent 1.0 end

    if {[info exists state($t,pattern)]} {
        set state($t,pattern) ""
        set state($t,matches) {}
        set state($t,current) -1
    }
}

proc mdhelp_search::next {t} {
    # Jumps to next match.
    # Wrap-around am Ende.
    variable state

    if {![info exists state($t,matches)] || [llength $state($t,matches)] == 0} {
        return -1
    }

    incr state($t,current)
    if {$state($t,current) >= [llength $state($t,matches)]} {
        set state($t,current) 0
    }

    mdhelp_search::highlightCurrent $t
    mdhelp_search::scrollToCurrent $t

    return $state($t,current)
}

proc mdhelp_search::prev {t} {
    # Springt zum vorherigen Treffer.
    # Wrap-around am Anfang.
    variable state

    if {![info exists state($t,matches)] || [llength $state($t,matches)] == 0} {
        return -1
    }

    incr state($t,current) -1
    if {$state($t,current) < 0} {
        set state($t,current) [expr {[llength $state($t,matches)] - 1}]
    }

    mdhelp_search::highlightCurrent $t
    mdhelp_search::scrollToCurrent $t

    return $state($t,current)
}

proc mdhelp_search::count {t} {
    # Returns the number of matches.
    variable state

    if {![info exists state($t,matches)]} {
        return 0
    }
    return [llength $state($t,matches)]
}

proc mdhelp_search::current {t} {
    # Returns the current match index (-1 if none).
    variable state

    if {![info exists state($t,current)]} {
        return -1
    }
    return $state($t,current)
}

proc mdhelp_search::highlightCurrent {t} {
    # Hebt den aktuellen Treffer hervor.
    variable state

    # Altes Current-Tag entfernen
    $t tag remove searchCurrent 1.0 end

    set idx $state($t,current)
    if {$idx < 0 || $idx >= [llength $state($t,matches)]} {
        return
    }

    lassign [lindex $state($t,matches) $idx] s e
    $t tag add searchCurrent $s $e
}

proc mdhelp_search::scrollToCurrent {t} {
    # Scrollt zum aktuellen Treffer.
    variable state

    set idx $state($t,current)
    if {$idx < 0 || $idx >= [llength $state($t,matches)]} {
        return
    }

    lassign [lindex $state($t,matches) $idx] s e
    $t see $s
}

proc mdhelp_search::copyAll {t} {
    # Kopiert alle Suchtreffer in die Zwischenablage.
    # Matches are cleaned and separated by "---" getrennt.
    # Returns number of copied matches.

    variable state

    if {![info exists state($t,matches)] || [llength $state($t,matches)] == 0} {
        return 0
    }

    set parts {}

    foreach m $state($t,matches) {
        lassign $m s e
        set txt [$t get $s $e]

        # Normalisierung
        regsub -all {\t+} $txt {  } txt
        regsub -all {\n{3,}} $txt "\n\n" txt
        regsub -all -line {^[ \t]+$} $txt {} txt
        set txt [string trim $txt]

        if {$txt ne ""} {
            lappend parts $txt
        }
    }

    if {[llength $parts] == 0} {
        return 0
    }

    set out [join $parts "\n---\n"]

    clipboard clear
    clipboard append $out

    return [llength $parts]
}

# ============================================================
# Global search (cross-document)
# ============================================================

proc mdhelp_search::scanFiles {root} {
    # Findet alle .md Dateien unter root (rekursiv).
    # Returns sorted list of file paths.

    set files {}
    set root [file normalize $root]
    mdhelp_search::_scanDir $root files
    return [lsort $files]
}

proc mdhelp_search::_scanDir {dir files_var} {
    # Recursive helper for scanFiles.
    upvar $files_var files

    foreach f [glob -nocomplain -directory $dir -types f *.md] {
        lappend files $f
    }

    foreach d [glob -nocomplain -directory $dir -types d *] {
        if {[string match .* [file tail $d]]} continue
        mdhelp_search::_scanDir $d files
    }
}

proc mdhelp_search::searchFile {file pattern} {
    # Durchsucht eine Datei nach pattern.
    # Returns list of {lineno context}.
    #
    # - Case-insensitive
    # - Context truncated to 120 characters

    set hits {}

    if {[catch {open $file r} fh]} {
        return $hits
    }

    fconfigure $fh -encoding utf-8
    set lineno 0

    while {[gets $fh line] >= 0} {
        incr lineno
        if {[string match -nocase "*$pattern*" $line]} {
            set context [string range $line 0 119]
            if {[string length $line] > 120} {
                append context "..."
            }
            lappend hits [list $lineno $context]
        }
    }

    close $fh
    return $hits
}

proc mdhelp_search::searchAll {root pattern} {
    # Durchsucht alle .md Dateien unter root.
    # Returns list of {file hits}.

    set results {}

    if {$pattern eq ""} {
        return $results
    }

    foreach f [mdhelp_search::scanFiles $root] {
        set hits [mdhelp_search::searchFile $f $pattern]
        if {[llength $hits] > 0} {
            lappend results [list $f $hits]
        }
    }

    return $results
}

proc mdhelp_search::countAllHits {results} {
    # Counts the total number of matches across all files.
    set total 0
    foreach r $results {
        lassign $r file hits
        incr total [llength $hits]
    }
    return $total
}

proc mdhelp_search::formatResults {results {root ""}} {
    # Formatiert Suchergebnisse als Liste von {file lineno display}.
    # Display format: "file.md:42  context..."

    set lines {}

    foreach r $results {
        lassign $r file hits

        if {$root ne ""} {
            set display [mdhelp_search::_relPath $file $root]
        } else {
            set display [file tail $file]
        }

        foreach h $hits {
            lassign $h lineno context
            regsub -all {\s+} $context { } context
            set context [string trim $context]
            lappend lines [list $file $lineno "$display:$lineno  $context"]
        }
    }

    return $lines
}

proc mdhelp_search::_relPath {file root} {
    # Berechnet relativen Pfad von root zu file.
    if {$root eq ""} {
        return $file
    }

    set file [file normalize $file]
    set root [file normalize $root]
    set root [string trimright $root "/\\"]

    if {[string first $root $file] == 0} {
        set rel [string range $file [string length $root] end]
        set rel [string trimleft $rel "/\\"]
        if {$rel eq ""} {
            return [file tail $file]
        }
        return $rel
    }

    return [file tail $file]
}
