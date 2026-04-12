# mdspellcheck-0.1.tm -- Spell checking for text widgets
# Uses aspell or hunspell via pipe.
# Optional: if no spell checker installed, nothing happens.
#
# API:
#   mdspellcheck::available        -- 1 if checker available
#   mdspellcheck::lang ?newLang?   -- Query/set language
#   mdspellcheck::attach $t        -- Attach text widget
#   mdspellcheck::detach $t        -- Remove attachment
#   mdspellcheck::checkAll $t      -- Check entire text
#   mdspellcheck::checkLine $t ln  -- Check one line
#   mdspellcheck::suggest $word    -- Suggestions list
#   mdspellcheck::addWord $word    -- Add word to session whitelist
#   mdspellcheck::enabled $t ?b?   -- Enable/disable checking
#
# Tags: spellwrong (red underline)

package provide mdspellcheck 0.1

namespace eval mdspellcheck {
    namespace export available lang attach detach checkAll checkLine \
                     suggest addWord enabled getErrors showResults

    variable state
    variable checker ""
    variable checkerCmd ""
    variable language "de_DE"
    variable whitelist
    array set whitelist {}
    variable cache
    array set cache {}

    # Eingebaute Whitelist: Markdown, Tcl, Tech-Begriffe
    # Diese Woerter werden nie als Fehler markiert.
    foreach _w {
        md tcl tk htm html css js json xml svg png jpg gif pdf
        http https ftp url uri href src img alt
        nbsp br hr div span pre blockquote thead tbody
        utf ascii unicode iso
        proc namespace eval expr incr foreach lindex lrange lappend
        lsort lmap lassign lrepeat llength dict upvar uplevel
        concat regexp regsub subst glob exec puts gets open close
        fconfigure fileevent socket after vwait update info interp
        package require provide source catch try throw error return
        winfo wm bind event grid pack place destroy toplevel
        ttk frame label button entry text canvas scrollbar
        treeview panedwindow notebook combobox radiobutton checkbutton
        menubutton separator spinbox progressbar labelframe
        configure cget tag mark insert delete index search see
        xview yview
        mdhelp mdviewer mdparser mdmodel mdtext mdstack
        mdcontextmenu mdspellcheck mdindexgen mdeditor
        aspell hunspell ispell
        linux windows macos ubuntu debian fedora
        github gitlab npm pip apt sudo
        readme changelog todo fixme
        ok nein ja abbrechen
        bzw usw etc incl inkl bzgl ggf evtl ca nr
    } {
        set whitelist($_w) 1
    }
    unset _w
}

# ============================================================
# Detection
# ============================================================

proc mdspellcheck::_detect {} {
    variable checker
    variable checkerCmd

    # Prefer aspell
    if {[auto_execok aspell] ne ""} {
        set checker "aspell"
        set checkerCmd [auto_execok aspell]
        return
    }
    if {[auto_execok hunspell] ne ""} {
        set checker "hunspell"
        set checkerCmd [auto_execok hunspell]
        return
    }

    set checker ""
    set checkerCmd ""
}

# Execute once on package load
mdspellcheck::_detect

proc mdspellcheck::available {} {
    variable checker
    return [expr {$checker ne ""}]
}

proc mdspellcheck::lang {{newLang ""}} {
    variable language
    variable cache
    if {$newLang ne ""} {
        set language $newLang
        array unset cache
    }
    return $language
}

# ============================================================
# Pipe Communication
# ============================================================

proc mdspellcheck::_openPipe {} {
    # Opens an aspell/hunspell pipe in interactive mode.
    # Returns pipe handle or "" on error.
    variable checkerCmd
    variable language

    if {[catch {
        set pipe [open "|[list $checkerCmd] -a -l $language 2>/dev/null" r+]
        fconfigure $pipe -buffering line -blocking 1 -encoding utf-8
        # Read and discard version line
        gets $pipe
    } err]} {
        catch {close $pipe}
        return ""
    }
    return $pipe
}

proc mdspellcheck::_checkWordsBatch {words} {
    # Checks a list of words.
    # Returns dict: word -> {ok suggestionsList}
    variable cache
    variable whitelist

    set result [dict create]
    set toCheck {}

    # Check cache and whitelist
    foreach w $words {
        set wl [string tolower $w]
        if {[info exists whitelist($wl)]} {
            dict set result $w {1 {}}
        } elseif {[info exists cache($wl)]} {
            dict set result $w $cache($wl)
        } else {
            lappend toCheck $w
        }
    }

    if {[llength $toCheck] == 0} {
        return $result
    }

    # Open pipe
    set pipe [_openPipe]
    if {$pipe eq ""} {
        foreach w $toCheck { dict set result $w {1 {}} }
        return $result
    }

    # Send word by word and read response (synchronous).
    # aspell protocol: ^word -> response line + blank line
    foreach w $toCheck {
        set wl [string tolower $w]

        if {[catch {
            puts $pipe "^$w"
            flush $pipe
        }]} {
            # Pipe broken -> mark rest as OK
            break
        }

        # Read response (one content line + one blank line)
        set ok 1
        set suggestions {}

        while {[gets $pipe line] >= 0} {
            # Blank line = end of response for this word
            if {$line eq ""} break

            if {$line eq "*" || $line eq "+"} {
                set ok 1
            } elseif {[string index $line 0] eq "&"} {
                set ok 0
                set colonPos [string first ":" $line]
                if {$colonPos >= 0} {
                    set sugStr [string range $line [expr {$colonPos + 2}] end]
                    set suggestions {}
                    foreach s [split $sugStr ","] {
                        set s [string trim $s]
                        if {$s ne ""} { lappend suggestions $s }
                    }
                }
            } elseif {[string index $line 0] eq "#"} {
                set ok 0
                set suggestions {}
            }
        }

        set val [list $ok $suggestions]
        dict set result $w $val
        set cache($wl) $val
    }

    catch {close $pipe}

    # Restliche Woerter (bei Pipe-Fehler) als OK markieren
    foreach w $toCheck {
        if {![dict exists $result $w]} {
            dict set result $w {1 {}}
        }
    }

    return $result
}

proc mdspellcheck::suggest {word} {
    variable cache
    set wl [string tolower $word]
    if {[info exists cache($wl)]} {
        return [lindex $cache($wl) 1]
    }
    set result [_checkWordsBatch [list $word]]
    if {[dict exists $result $word]} {
        return [lindex [dict get $result $word] 1]
    }
    return {}
}

proc mdspellcheck::addWord {word} {
    variable whitelist
    variable cache
    set wl [string tolower $word]
    set whitelist($wl) 1
    catch {unset cache($wl)}
}

# ============================================================
# Text-Widget-Anbindung
# ============================================================

proc mdspellcheck::attach {t} {
    variable state

    if {![available]} return

    # Tag einrichten: roter Unterstrich
    $t tag configure spellwrong -underline 1
    catch {
        # Tk 8.6.11+ hat -underlinecolor
        $t tag configure spellwrong -underlinecolor red
    }
    # Fallback: rote Schrift wenn kein underlinecolor
    if {[catch {$t tag cget spellwrong -underlinecolor}]} {
        $t tag configure spellwrong -foreground red
    }
    $t tag lower spellwrong

    set state($t,enabled) 1
    set state($t,afterid) ""

    # Rechtsklick auf markierte Woerter
    $t tag bind spellwrong <Button-3> \
        [list mdspellcheck::_contextMenu $t %X %Y %x %y]

    # Debounce-Check nach Eingabe
    bind $t <KeyRelease> +[list mdspellcheck::_scheduleCheck $t]
}

proc mdspellcheck::detach {t} {
    variable state
    if {[info exists state($t,afterid)] && $state($t,afterid) ne ""} {
        after cancel $state($t,afterid)
    }
    catch {$t tag remove spellwrong 1.0 end}
    catch {$t tag delete spellwrong}
    array unset state $t,*
}

proc mdspellcheck::enabled {t {val ""}} {
    variable state
    if {$val ne ""} {
        set state($t,enabled) $val
        if {!$val} {
            catch {$t tag remove spellwrong 1.0 end}
        } else {
            # Beim Einschalten: sofort pruefen
            after idle [list mdspellcheck::_checkVisible $t]
        }
    }
    if {[info exists state($t,enabled)]} {
        return $state($t,enabled)
    }
    return 0
}

# ============================================================
# Pruefung
# ============================================================

proc mdspellcheck::_scheduleCheck {t} {
    variable state
    if {![info exists state($t,enabled)] || !$state($t,enabled)} return

    if {[info exists state($t,afterid)] && $state($t,afterid) ne ""} {
        after cancel $state($t,afterid)
    }
    # 800ms Debounce
    set state($t,afterid) [after 800 [list mdspellcheck::_checkVisible $t]]
}

proc mdspellcheck::_checkVisible {t} {
    variable state
    if {[info exists state($t,afterid)]} {
        set state($t,afterid) ""
    }
    if {![winfo exists $t]} return
    if {![info exists state($t,enabled)] || !$state($t,enabled)} return

    # Sichtbaren Bereich ermitteln
    set firstLine [lindex [split [$t index @0,0] .] 0]
    set lastLine [lindex [split [$t index @0,[winfo height $t]] .] 0]

    # Sicherheit: mindestens bis Zeilenende
    set totalLines [lindex [split [$t index end] .] 0]
    if {$lastLine > $totalLines} { set lastLine $totalLines }

    # Alle sichtbaren Zeilen auf einmal sammeln und pruefen
    _checkRange $t $firstLine $lastLine
}

proc mdspellcheck::_checkRange {t fromLine toLine} {
    # Sammelt alle Woerter im Bereich und prueft sie in einem Batch.
    if {![available]} return

    # Tag im Bereich entfernen
    $t tag remove spellwrong "$fromLine.0" "$toLine.0 lineend"

    # Track in Code-Block?
    variable state
    set inCodeBlock 0

    # Alle Woerter sammeln mit Positionen
    set allWords {}    ;# Liste von {word line col_start col_end}

    for {set ln $fromLine} {$ln <= $toLine} {incr ln} {
        set lineText [$t get "$ln.0" "$ln.0 lineend"]

        # Code-Block Toggle
        if {[regexp {^\s*```} $lineText]} {
            set inCodeBlock [expr {!$inCodeBlock}]
            continue
        }
        if {$inCodeBlock} continue

        # Zeilen die mit 4 Spaces oder Tab beginnen = Code
        if {[regexp {^(\s{4}|\t)} $lineText]} continue

        # Tabellen-Trennzeilen ueberspringen: |---|---|
        if {[regexp {^\|[\s:|\-]+\|$} $lineText]} continue

        # Reine Markdown-Zeilen: ---, ***, ___
        if {[regexp {^[\s]*[-*_]{3,}\s*$} $lineText]} continue

        # Inline-Code-Bereiche ermitteln
        set skipRanges {}
        set idx 0
        while {[regexp -indices -start $idx {`[^`]+`} $lineText match]} {
            lappend skipRanges $match
            set idx [expr {[lindex $match 1] + 1}]
        }

        # Link-URL-Bereiche: ](url) und ![alt](url)
        set idx 0
        while {[regexp -indices -start $idx {\]\([^)]+\)} $lineText match]} {
            lappend skipRanges $match
            set idx [expr {[lindex $match 1] + 1}]
        }

        # Bild-Syntax: ![...] -- den Alt-Text pruefen wir, aber ! und [] nicht
        # HTML-Tags: <tag attr="val">
        set idx 0
        while {[regexp -indices -start $idx {<[^>]+>} $lineText match]} {
            lappend skipRanges $match
            set idx [expr {[lindex $match 1] + 1}]
        }

        # Heading-Marker ueberspringen: "## " am Anfang
        set textStart 0
        if {[regexp {^#{1,6}\s+} $lineText hdr]} {
            set textStart [string length $hdr]
        }

        # Woerter extrahieren
        set i $textStart
        set len [string length $lineText]

        while {$i < $len} {
            set ch [string index $lineText $i]
            if {[string is alpha $ch] || $ch eq "\u00e4" || $ch eq "\u00f6" ||
                $ch eq "\u00fc" || $ch eq "\u00df" || $ch eq "\u00c4" ||
                $ch eq "\u00d6" || $ch eq "\u00dc"} {
                set start $i
                while {$i < $len} {
                    set ch [string index $lineText $i]
                    if {[string is alpha $ch] || $ch eq "'" || $ch eq "-" ||
                        $ch eq "\u00e4" || $ch eq "\u00f6" || $ch eq "\u00fc" ||
                        $ch eq "\u00df" || $ch eq "\u00c4" || $ch eq "\u00d6" ||
                        $ch eq "\u00dc"} {
                        incr i
                    } else {
                        break
                    }
                }
                set word [string range $lineText $start [expr {$i - 1}]]
                # Trailing Sonderzeichen entfernen
                set word [string trim $word "'-"]
                set wordLen [string length $word]

                if {$wordLen >= 2} {
                    # In Skip-Bereich? (Code, Link-URL, HTML-Tag)
                    set skip 0
                    foreach sr $skipRanges {
                        if {$start >= [lindex $sr 0] && $start <= [lindex $sr 1]} {
                            set skip 1; break
                        }
                    }

                    if {!$skip} {
                        lappend allWords [list $word $ln $start $i]
                    }
                }
            } else {
                incr i
            }
        }
    }

    if {[llength $allWords] == 0} return

    # Unique Woerter sammeln
    set uniqueWords {}
    foreach entry $allWords {
        set w [lindex $entry 0]
        if {$w ni $uniqueWords} { lappend uniqueWords $w }
    }

    # Batch-Pruefung
    set result [_checkWordsBatch $uniqueWords]

    # Markieren
    foreach entry $allWords {
        lassign $entry word ln ws we
        if {[dict exists $result $word]} {
            lassign [dict get $result $word] ok suggestions
            if {!$ok} {
                $t tag add spellwrong "$ln.$ws" "$ln.$we"
            }
        }
    }
}

proc mdspellcheck::checkAll {t} {
    if {![available]} return
    $t tag remove spellwrong 1.0 end
    set lastLine [lindex [split [$t index end] .] 0]
    _checkRange $t 1 $lastLine
}

proc mdspellcheck::checkLine {t ln} {
    if {![available]} return
    _checkRange $t $ln $ln
}

# ============================================================
# Kontextmenue
# ============================================================

proc mdspellcheck::_contextMenu {t rootX rootY x y} {
    set idx [$t index @$x,$y]

    if {"spellwrong" ni [$t tag names $idx]} return

    # Wort-Grenzen
    set range [$t tag prevrange spellwrong "$idx + 1 char"]
    if {[llength $range] != 2} return
    lassign $range start end

    set word [$t get $start $end]

    # Vorschlaege
    set suggestions [suggest $word]

    set m .spellmenu
    catch {destroy $m}
    menu $m -tearoff 0

    if {[llength $suggestions] > 0} {
        set count 0
        foreach sug $suggestions {
            $m add command -label $sug \
                -command [list mdspellcheck::_replaceWord $t $start $end $sug]
            incr count
            if {$count >= 8} break
        }
        $m add separator
    } else {
        $m add command -label "(Keine Vorschlaege)" -state disabled
        $m add separator
    }

    $m add command -label "Ignore Word" \
        -command [list mdspellcheck::_ignoreWord $t $word]
    $m add command -label "Add Word" \
        -command [list mdspellcheck::_addWordFromMenu $t $word]

    tk_popup $m $rootX $rootY
}

proc mdspellcheck::_replaceWord {t start end replacement} {
    $t delete $start $end
    $t insert $start $replacement
}

proc mdspellcheck::_ignoreWord {t word} {
    addWord $word
    _removeWordMarks $t $word
}

proc mdspellcheck::_addWordFromMenu {t word} {
    addWord $word
    _removeWordMarks $t $word
}

proc mdspellcheck::_removeWordMarks {t word} {
    set idx 1.0
    while {1} {
        set range [$t tag nextrange spellwrong $idx end]
        if {[llength $range] != 2} break
        lassign $range start end
        set w [$t get $start $end]
        if {[string tolower $w] eq [string tolower $word]} {
            $t tag remove spellwrong $start $end
        }
        set idx "$end + 1 char"
    }
}

# ============================================================
# Fehlerliste
# ============================================================

proc mdspellcheck::getErrors {t} {
    # Gibt Liste aller Fehler zurueck.
    # Jeder Eintrag: {word line col start end suggestions}
    set errors {}
    set idx 1.0
    while {1} {
        set range [$t tag nextrange spellwrong $idx end]
        if {[llength $range] != 2} break
        lassign $range start end
        set word [$t get $start $end]
        set ln [lindex [split $start .] 0]
        set col [lindex [split $start .] 1]
        set sug [suggest $word]
        lappend errors [list $word $ln $col $start $end $sug]
        set idx "$end + 1 char"
    }
    return $errors
}

proc mdspellcheck::showResults {t {parent .}} {
    # Zeigt ein Fenster mit allen Fehlern und Vorschlaegen.
    variable state

    set win ${parent}.spellresults
    if {[winfo exists $win]} {
        raise $win
        return
    }

    set errors [getErrors $t]

    toplevel $win
    wm title $win "Spellcheck - [llength $errors] errors"
    wm geometry $win 550x400
    wm transient $win $parent

    # --- Oberer Bereich: Fehlerliste ---
    ttk::frame $win.top
    pack $win.top -fill both -expand 1 -padx 8 -pady 4

    ttk::label $win.top.lbl -text "Errors:"
    pack $win.top.lbl -anchor w

    ttk::frame $win.top.tf
    pack $win.top.tf -fill both -expand 1

    set tree [ttk::treeview $win.top.tf.tree \
        -columns {word line suggest} -show headings \
        -yscrollcommand [list $win.top.tf.sb set] \
        -selectmode browse -height 10]
    $tree heading word -text "Word"
    $tree heading line -text "Line"
    $tree heading suggest -text "Vorschlag"
    $tree column word -width 140 -minwidth 80
    $tree column line -width 50 -minwidth 40
    $tree column suggest -width 300 -minwidth 100

    ttk::scrollbar $win.top.tf.sb -orient vertical -command [list $tree yview]
    pack $tree -side left -fill both -expand 1
    pack $win.top.tf.sb -side right -fill y

    # Fehlerliste fuellen
    foreach err $errors {
        lassign $err word ln col start end sug
        set sugText [join [lrange $sug 0 4] ", "]
        if {[llength $sug] > 5} { append sugText " ..." }
        $tree insert {} end -values [list $word $ln $sugText] \
            -tags [list $start $end $word]
    }

    # --- Unterer Bereich: Buttons ---
    ttk::frame $win.bot
    pack $win.bot -fill x -padx 8 -pady 8

    ttk::button $win.bot.goto -text "Go to Word" \
        -command [list mdspellcheck::_resultsGoto $win $tree $t]
    ttk::button $win.bot.replace -text "Ersetzen..." \
        -command [list mdspellcheck::_resultsReplace $win $tree $t]
    ttk::button $win.bot.ignore -text "Ignorieren" \
        -command [list mdspellcheck::_resultsIgnore $win $tree $t]
    ttk::button $win.bot.close -text "Schliessen" \
        -command [list destroy $win]

    pack $win.bot.goto $win.bot.replace $win.bot.ignore \
         -side left -padx 4
    pack $win.bot.close -side right -padx 4

    # Doppelklick = Zum Wort springen
    bind $tree <Double-1> [list mdspellcheck::_resultsGoto $win $tree $t]

    set state(resultsWin) $win
    set state(resultsTree) $tree
    set state(resultsText) $t
}

proc mdspellcheck::_resultsGoto {win tree t} {
    set sel [$tree selection]
    if {$sel eq ""} return
    set tags [$tree item $sel -tags]
    lassign $tags start end word
    # Im Text-Widget markieren und hinspringen
    $t tag remove sel 1.0 end
    $t tag add sel $start $end
    $t see $start
    catch {focus $t}
}

proc mdspellcheck::_resultsReplace {win tree t} {
    set sel [$tree selection]
    if {$sel eq ""} return
    set tags [$tree item $sel -tags]
    lassign $tags start end word

    # Vorschlaege holen
    set sug [suggest $word]
    if {[llength $sug] == 0} {
        tk_messageBox -parent $win -icon info \
            -message "Keine Vorschlaege fuer \"$word\"."
        return
    }

    # Auswahl-Dialog
    set m ${win}.sugmenu
    catch {destroy $m}
    menu $m -tearoff 0
    foreach s $sug {
        $m add command -label $s \
            -command [list apply {{win tree t start end s item} {
                $t delete $start $end
                $t insert $start $s
                $tree delete $item
                wm title $win "Spellcheck - [llength [$tree children {}]] errors"
            }} $win $tree $t $start $end $s $sel]
    }
    # Menue unter dem Button anzeigen
    set x [winfo rootx $win.bot.replace]
    set y [expr {[winfo rooty $win.bot.replace] + [winfo height $win.bot.replace]}]
    tk_popup $m $x $y
}

proc mdspellcheck::_resultsIgnore {win tree t} {
    set sel [$tree selection]
    if {$sel eq ""} return
    set tags [$tree item $sel -tags]
    lassign $tags start end word

    addWord $word
    _removeWordMarks $t $word

    # Alle Eintraege mit diesem Wort aus der Liste entfernen
    foreach item [$tree children {}] {
        set itags [$tree item $item -tags]
        if {[lindex $itags 2] eq $word} {
            $tree delete $item
        }
    }
    wm title $win "Spellcheck - [llength [$tree children {}]] errors"
}
