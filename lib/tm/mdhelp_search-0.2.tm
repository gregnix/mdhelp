# mdhelp_search-0.2.tm
#
# Search/replace module for mdhelp.
# Erweitert 0.1 um:
#   - Optionen: -case (case-sensitive), -word (Wortgrenzen), -regex (Regex)
#   - Replace API:  replace, replaceAll, replaceCurrent, replaceNext
#   - Match-Laengen pro Treffer (fuer Regex/Word-Boundary)
#   - Snippet-Funktion: snippet $line $pattern -> {pre match post}
#     fuer das hervorgehobene Anzeigen in Ergebnislisten
#
# Backwards compatible mit 0.1: alle alten API-Calls funktionieren.
#
# Widget-Suche:
#   mdhelp_search::init     $t
#   mdhelp_search::find     $t $pattern ?-case 0|1? ?-word 0|1? ?-regex 0|1?
#   mdhelp_search::clear    $t
#   mdhelp_search::next     $t
#   mdhelp_search::prev     $t
#   mdhelp_search::count    $t
#   mdhelp_search::current  $t
#   mdhelp_search::raiseTags $t       <-- neu, raise nach jedem render
#
# Replace (nur fuer beschreibbare Widgets gedacht):
#   mdhelp_search::replaceCurrent $t $newText
#   mdhelp_search::replaceAll     $t $pattern $newText ?options?
#
# Globale Suche:
#   mdhelp_search::searchFile   $file $pattern ?options?
#   mdhelp_search::searchAll    $root $pattern ?options?
#   mdhelp_search::countAllHits $results
#   mdhelp_search::formatResults $results ?root?
#   mdhelp_search::snippet $line $pattern ?options?
#       -> dict {pre match post lineno}

package require Tcl 8.6-

package provide mdhelp_search 0.2

namespace eval mdhelp_search {
    namespace export init find clear next prev count current \
                     highlightCurrent scrollToCurrent copyAll raiseTags \
                     replaceCurrent replaceAll \
                     scanFiles searchFile searchAll countAllHits formatResults \
                     snippet

    variable state
    # state($t,pattern)   - Search pattern
    # state($t,matches)   - List of {start end}
    # state($t,current)   - current match index (-1 = none)
    # state($t,opts)      - dict mit -case -word -regex (last used)
}

# ============================================================
# Tag setup
# ============================================================

proc mdhelp_search::init {t} {
    variable state

    # Auffaelligere Treffer-Hervorhebung als 0.1:
    #   searchHit:     starkes Gelb mit dunkler Schrift
    #   searchCurrent: Orange mit weisser Schrift, fett-aehnlicher Effekt
    #                  ueber relief
    $t tag configure searchHit \
        -background "#ffd83d" \
        -foreground "#000000" \
        -borderwidth 0
    $t tag configure searchCurrent \
        -background "#ff6f00" \
        -foreground "#ffffff" \
        -borderwidth 1 \
        -relief raised

    # Priority: Current ueber Hit, beide ueber alle anderen Tags.
    # raiseTags wird zusaetzlich nach jedem Render aufgerufen, um
    # spaeter konfigurierte Tags (z.B. div_*) nicht zu vergessen.
    catch { $t tag raise searchHit }
    catch { $t tag raise searchCurrent }

    set state($t,pattern) ""
    set state($t,matches) {}
    set state($t,current) -1
    set state($t,opts)    [dict create -case 0 -word 0 -regex 0]
}

proc mdhelp_search::raiseTags {t} {
    # Nach jedem Render aufrufen, damit die Such-Tags ueber allen
    # gerade neu konfigurierten/erstellten Tags liegen (div_*, etc.).
    catch { $t tag raise searchHit }
    catch { $t tag raise searchCurrent }
}

# ============================================================
# Hilfsfunktionen
# ============================================================

proc mdhelp_search::_parseOpts {argList} {
    # gibt dict zurueck mit -case -word -regex (alle 0/1)
    set opts [dict create -case 0 -word 0 -regex 0]
    foreach {k v} $argList {
        switch -- $k {
            -case  { dict set opts -case  [expr {$v ? 1 : 0}] }
            -word  { dict set opts -word  [expr {$v ? 1 : 0}] }
            -regex { dict set opts -regex [expr {$v ? 1 : 0}] }
            default { error "mdhelp_search: unbekannte Option $k" }
        }
    }
    return $opts
}

proc mdhelp_search::_buildSearchArgs {opts} {
    # Baut die Argumente fuer "$t search ..." aus den Optionen.
    set args {}
    if {[dict get $opts -regex]} {
        lappend args -regexp
    }
    if {![dict get $opts -case]} {
        lappend args -nocase
    }
    lappend args -count ::__mdhelp_search_len
    return $args
}

proc mdhelp_search::_buildPattern {pattern opts} {
    # Wenn -word gesetzt: Wortgrenzen um pattern setzen.
    # In dem Fall wird der Modus auf -regexp gehoben.
    set rx 0
    if {[dict get $opts -regex]} {
        set rx 1
        set pat $pattern
    } else {
        set pat $pattern
    }

    if {[dict get $opts -word]} {
        if {!$rx} {
            # plain → escape pattern, then wrap with \m \M
            set escaped [string map {
                \\ \\\\  . \\.  ^ \\^  $ \\$  ( \\(  ) \\)  | \\|
                * \\*    + \\+  ? \\?  { \\\{ } \\\}  \[ \\\[
                \] \\\]
            } $pat]
            set pat "\\m${escaped}\\M"
            set rx 1
        } else {
            set pat "\\m(?:${pat})\\M"
        }
    }

    return [list $pat $rx]
}

# ============================================================
# Find
# ============================================================

proc mdhelp_search::find {t pattern args} {
    # Sucht pattern im Text-Widget mit den optionalen Schaltern.
    # Gibt Anzahl Treffer zurueck.
    variable state

    if {![info exists state($t,pattern)]} {
        mdhelp_search::init $t
    }

    # Alte Highlights entfernen
    $t tag remove searchHit 1.0 end
    $t tag remove searchCurrent 1.0 end

    if {$pattern eq ""} {
        set state($t,pattern) ""
        set state($t,matches) {}
        set state($t,current) -1
        return 0
    }

    set opts [mdhelp_search::_parseOpts $args]
    set state($t,opts) $opts

    lassign [mdhelp_search::_buildPattern $pattern $opts] pat rx
    set effOpts $opts
    if {$rx} { dict set effOpts -regex 1 }

    set sa [mdhelp_search::_buildSearchArgs $effOpts]

    set matches {}
    set idx "1.0"

    while {1} {
        set ::__mdhelp_search_len 0
        set rc [catch {$t search {*}$sa -- $pat $idx end} pos]
        if {$rc != 0 || $pos eq ""} break

        set len $::__mdhelp_search_len
        if {$len eq "" || $len <= 0} { set len 1 }
        set endPos [$t index "$pos + $len chars"]
        # Schutz gegen Endlos-Schleife (Regex die leeres Match liefert)
        if {[$t compare $endPos <= $pos]} {
            set endPos [$t index "$pos + 1 chars"]
        }
        lappend matches [list $pos $endPos]
        set idx $endPos
    }

    set state($t,pattern) $pattern
    set state($t,matches) $matches

    foreach m $matches {
        lassign $m s e
        $t tag add searchHit $s $e
    }
    # Sicherheitshalber auch hier raisen:
    mdhelp_search::raiseTags $t

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
    variable state
    if {![info exists state($t,matches)]} { return 0 }
    return [llength $state($t,matches)]
}

proc mdhelp_search::current {t} {
    variable state
    if {![info exists state($t,current)]} { return -1 }
    return $state($t,current)
}

proc mdhelp_search::highlightCurrent {t} {
    variable state
    $t tag remove searchCurrent 1.0 end
    set idx $state($t,current)
    if {$idx < 0 || $idx >= [llength $state($t,matches)]} return
    lassign [lindex $state($t,matches) $idx] s e
    $t tag add searchCurrent $s $e
    mdhelp_search::raiseTags $t
}

proc mdhelp_search::scrollToCurrent {t} {
    variable state
    set idx $state($t,current)
    if {$idx < 0 || $idx >= [llength $state($t,matches)]} return
    lassign [lindex $state($t,matches) $idx] s e
    $t see $s
}

proc mdhelp_search::copyAll {t} {
    variable state
    if {![info exists state($t,matches)] || [llength $state($t,matches)] == 0} {
        return 0
    }
    set parts {}
    foreach m $state($t,matches) {
        lassign $m s e
        set txt [$t get $s $e]
        regsub -all {\t+} $txt {  } txt
        regsub -all {\n{3,}} $txt "\n\n" txt
        regsub -all -line {^[ \t]+$} $txt {} txt
        set txt [string trim $txt]
        if {$txt ne ""} { lappend parts $txt }
    }
    if {[llength $parts] == 0} { return 0 }
    set out [join $parts "\n---\n"]
    clipboard clear
    clipboard append $out
    return [llength $parts]
}

# ============================================================
# Replace
# ============================================================

proc mdhelp_search::replaceCurrent {t newText} {
    # Ersetzt den aktuellen Treffer durch newText.
    # Returnt 1 wenn ersetzt, 0 sonst.
    # Aktualisiert die match-Liste so, dass nachfolgende Treffer
    # auf den neuen Stand geshiftet werden — einfachster Weg:
    # nach Replace neu suchen.
    variable state
    if {![info exists state($t,matches)]} { return 0 }
    set idx $state($t,current)
    if {$idx < 0 || $idx >= [llength $state($t,matches)]} { return 0 }

    # Pruefen ob Widget editierbar
    set st [$t cget -state]
    if {$st ne "normal"} { return 0 }

    lassign [lindex $state($t,matches) $idx] s e
    $t delete $s $e
    $t insert $s $newText

    # Nach Replace ist die Match-Liste invalide. Suche neu starten.
    set pattern $state($t,pattern)
    set opts    $state($t,opts)
    set newIdx  $idx

    mdhelp_search::find $t $pattern \
        -case  [dict get $opts -case] \
        -word  [dict get $opts -word] \
        -regex [dict get $opts -regex]

    # Setze current auf den naechsten verfuegbaren Treffer (oder den
    # ersten falls am Ende).
    if {$state($t,current) < 0} { return 1 }
    if {[llength $state($t,matches)] == 0} {
        set state($t,current) -1
        return 1
    }
    if {$newIdx >= [llength $state($t,matches)]} {
        set newIdx 0
    }
    set state($t,current) $newIdx
    mdhelp_search::highlightCurrent $t
    mdhelp_search::scrollToCurrent  $t
    return 1
}

proc mdhelp_search::replaceAll {t pattern newText args} {
    # Ersetzt ALLE Treffer von pattern durch newText.
    # Returnt Anzahl Ersetzungen.
    variable state

    set st [$t cget -state]
    if {$st ne "normal"} { return 0 }

    if {$pattern eq ""} { return 0 }

    set opts [mdhelp_search::_parseOpts $args]
    lassign [mdhelp_search::_buildPattern $pattern $opts] pat rx
    set effOpts $opts
    if {$rx} { dict set effOpts -regex 1 }
    set sa [mdhelp_search::_buildSearchArgs $effOpts]

    # Erst alle Positionen einsammeln (von hinten nach vorn), dann
    # ersetzen — sonst verschieben sich die Indices.
    set positions {}
    set idx "1.0"
    while {1} {
        set ::__mdhelp_search_len 0
        set rc [catch {$t search {*}$sa -- $pat $idx end} pos]
        if {$rc != 0 || $pos eq ""} break
        set len $::__mdhelp_search_len
        if {$len eq "" || $len <= 0} { set len 1 }
        set endPos [$t index "$pos + $len chars"]
        if {[$t compare $endPos <= $pos]} {
            set endPos [$t index "$pos + 1 chars"]
        }
        lappend positions [list $pos $endPos]
        set idx $endPos
    }

    set n [llength $positions]
    if {$n == 0} { return 0 }

    # Von hinten nach vorn ersetzen
    for {set i [expr {$n - 1}]} {$i >= 0} {incr i -1} {
        lassign [lindex $positions $i] s e
        $t delete $s $e
        $t insert $s $newText
    }

    # State-cleanup: Suche neu, damit Highlights stimmen
    if {[info exists state($t,pattern)]} {
        mdhelp_search::find $t $state($t,pattern) \
            -case  [dict get $state($t,opts) -case] \
            -word  [dict get $state($t,opts) -word] \
            -regex [dict get $state($t,opts) -regex]
    }
    return $n
}

# ============================================================
# Globale Suche (cross-document)
# ============================================================

proc mdhelp_search::scanFiles {root} {
    set files {}
    set root [file normalize $root]
    mdhelp_search::_scanDir $root files
    return [lsort $files]
}

proc mdhelp_search::_scanDir {dir files_var} {
    upvar $files_var files
    foreach f [glob -nocomplain -directory $dir -types f *.md] {
        lappend files $f
    }
    foreach d [glob -nocomplain -directory $dir -types d *] {
        if {[string match .* [file tail $d]]} continue
        mdhelp_search::_scanDir $d files
    }
}

proc mdhelp_search::_lineMatches {line pattern opts} {
    # Prueft ob line den pattern matcht. Returnt 1/0.
    set caseSens [dict get $opts -case]
    set isWord   [dict get $opts -word]
    set isRegex  [dict get $opts -regex]

    if {!$isRegex && !$isWord} {
        if {$caseSens} {
            return [string match "*$pattern*" $line]
        } else {
            return [string match -nocase "*$pattern*" $line]
        }
    }

    # Regex / Word: regexp benutzen
    if {!$isRegex} {
        # plain → escape
        set escaped [string map {
            \\ \\\\  . \\.  ^ \\^  $ \\$  ( \\(  ) \\)  | \\|
            * \\*    + \\+  ? \\?  { \\\{ } \\\}  \[ \\\[
            \] \\\]
        } $pattern]
        set p $escaped
    } else {
        set p $pattern
    }
    if {$isWord} { set p "\\m(?:${p})\\M" }

    if {$caseSens} {
        return [regexp -- $p $line]
    } else {
        return [regexp -nocase -- $p $line]
    }
}

proc mdhelp_search::searchFile {file pattern args} {
    # Durchsucht eine Datei.
    # Gibt Liste {lineno context} zurueck.

    set hits {}

    if {[catch {open $file r} fh]} {
        return $hits
    }
    fconfigure $fh -encoding utf-8

    set opts [mdhelp_search::_parseOpts $args]

    set lineno 0
    while {[gets $fh line] >= 0} {
        incr lineno
        if {[mdhelp_search::_lineMatches $line $pattern $opts]} {
            set context [string range $line 0 199]
            if {[string length $line] > 200} {
                append context "..."
            }
            lappend hits [list $lineno $context]
        }
    }
    close $fh
    return $hits
}

proc mdhelp_search::searchAll {root pattern args} {
    set results {}
    if {$pattern eq ""} { return $results }
    foreach f [mdhelp_search::scanFiles $root] {
        set hits [mdhelp_search::searchFile $f $pattern {*}$args]
        if {[llength $hits] > 0} {
            lappend results [list $f $hits]
        }
    }
    return $results
}

proc mdhelp_search::countAllHits {results} {
    set total 0
    foreach r $results {
        lassign $r file hits
        incr total [llength $hits]
    }
    return $total
}

proc mdhelp_search::formatResults {results {root ""}} {
    # Formatiert Ergebnisse als Liste von dicts:
    #   {file ... lineno ... display ... context ...}
    # display = "filename:lineno"  context = bereinigter Zeilen-Text
    # Damit kann das UI den match-Snippet selbst hervorheben.
    set out {}
    foreach r $results {
        lassign $r file hits
        if {$root ne ""} {
            set name [mdhelp_search::_relPath $file $root]
        } else {
            set name [file tail $file]
        }
        foreach h $hits {
            lassign $h lineno context
            regsub -all {\s+} $context { } context
            set context [string trim $context]
            lappend out [list \
                file    $file \
                lineno  $lineno \
                display "${name}:${lineno}" \
                context $context]
        }
    }
    return $out
}

proc mdhelp_search::snippet {line pattern args} {
    # Sucht das erste Match von pattern in line und gibt
    # ein dict {pre match post} zurueck.
    # pre/post sind so gekuerzt, dass das Match in der Mitte
    # erscheint (max ~ 80 Zeichen Kontext).
    set opts [mdhelp_search::_parseOpts $args]
    set caseSens [dict get $opts -case]
    set isWord   [dict get $opts -word]
    set isRegex  [dict get $opts -regex]

    if {!$isRegex} {
        set escaped [string map {
            \\ \\\\  . \\.  ^ \\^  $ \\$  ( \\(  ) \\)  | \\|
            * \\*    + \\+  ? \\?  { \\\{ } \\\}  \[ \\\[
            \] \\\]
        } $pattern]
        set p $escaped
    } else {
        set p $pattern
    }
    if {$isWord} { set p "\\m(?:${p})\\M" }

    set rxCmd [list regexp -indices]
    if {!$caseSens} { lappend rxCmd -nocase }
    lappend rxCmd -- $p $line match

    if {[catch {{*}$rxCmd} ok] || !$ok} {
        # Kein Treffer → ganzen Text als pre, leeres match
        return [dict create pre $line match "" post ""]
    }

    lassign $match start end
    set matchStr [string range $line $start $end]
    set pre  [string range $line 0 [expr {$start - 1}]]
    set post [string range $line [expr {$end + 1}] end]

    # Kontext kuerzen
    set maxPre 60
    set maxPost 80
    if {[string length $pre] > $maxPre} {
        set pre "..[string range $pre [expr {[string length $pre] - $maxPre}] end]"
    }
    if {[string length $post] > $maxPost} {
        set post "[string range $post 0 [expr {$maxPost - 1}]].."
    }

    return [dict create pre $pre match $matchStr post $post]
}

proc mdhelp_search::_relPath {file root} {
    if {$root eq ""} { return $file }
    set file [file normalize $file]
    set root [file normalize $root]
    set root [string trimright $root "/\\"]
    if {[string first $root $file] == 0} {
        set rel [string range $file [string length $root] end]
        set rel [string trimleft $rel "/\\"]
        if {$rel eq ""} { return [file tail $file] }
        return $rel
    }
    return [file tail $file]
}
