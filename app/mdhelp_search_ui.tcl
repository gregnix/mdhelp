# mdhelp_search_ui.tcl -- Such-/Ersetzungs-UI (v2)
#
# Neu in dieser Version:
#   - Ergebnis-Panel verwendet Text-Widget statt Treeview, damit der
#     gefundene Text direkt im Kontext gelb hervorgehoben wird.
#   - Optionen "Aa" (Case) und "W" (Word).
#   - Replace-Modus (Toggle "Replace" oder Ctrl+H), zweite Zeile mit
#     Replace-Feld + Buttons "Replace", "Replace All", "Replace + Next".
#   - searchHit/searchCurrent-Tags werden nach jedem Render neu
#     ueber alle anderen Tags gehoben (raiseTags).
#
# Wird von mdhelp.tcl via source geladen.

if {![namespace exists ::app]} {
    error "mdhelp_search_ui.tcl muss von mdhelp.tcl geladen werden (namespace app fehlt)"
}

# Such-/Ersetz-Status
set ::app::searchPattern  ""
set ::app::replacePattern ""
set ::app::searchCase     0
set ::app::searchWord     0
set ::app::searchRegex    0
set ::app::searchReplace  0   ;# 1 = Replace-Zeile sichtbar
set ::app::searchStatus   ""

# Such-/Replace-Historie (max 15 Eintraege, neueste zuerst)
set ::app::searchHistory  {}
set ::app::replaceHistory {}
set ::app::_historyMax    15

proc app::_pushHistory {listVar value} {
    upvar #0 $listVar L
    if {$value eq ""} return
    # Duplikat raus
    set L [lsearch -all -inline -not -exact $L $value]
    # Vorne einfuegen
    set L [linsert $L 0 $value]
    # Auf max kuerzen
    set L [lrange $L 0 [expr {$::app::_historyMax - 1}]]
    # Combobox-Werte aktualisieren
    if {$listVar eq "::app::searchHistory"} {
        catch { .searchbar.f.entry configure -values $L }
    } elseif {$listVar eq "::app::replaceHistory"} {
        catch { .searchbar.r.entry configure -values $L }
    }
}

proc app::rememberSearch {} {
    app::_pushHistory ::app::searchHistory $::app::searchPattern
}

proc app::rememberReplace {} {
    app::_pushHistory ::app::replaceHistory $::app::replacePattern
}

# Inkrementelle Suche: Debounce-Konfiguration
set ::app::incrementalSearch 1     ;# 1 = beim Tippen suchen
set ::app::_searchDebounceMs 250
set ::app::_searchDebounceId ""

# ============================================================
# Inkrementelle Suche (Trace mit Debounce)
# ============================================================

proc app::_onSearchPatternChange {args} {
    # Wird via "trace add variable" aufgerufen sobald sich
    # ::app::searchPattern aendert. Debounced danach doSearchPage.
    if {!$::app::incrementalSearch} return
    if {!$::app::searchVisible}     return
    if {$::app::searchMode eq "global"} return  ;# Global ist zu teuer

    # Vorherigen pending-call abbrechen
    if {$::app::_searchDebounceId ne ""} {
        catch {after cancel $::app::_searchDebounceId}
    }
    set ::app::_searchDebounceId [after $::app::_searchDebounceMs \
        app::_runIncrementalSearch]
}

proc app::_runIncrementalSearch {} {
    set ::app::_searchDebounceId ""
    if {!$::app::searchVisible} return
    # Bei sehr kurzen Patterns (1 Zeichen) und Page-Mode: ok.
    # Bei leerem Pattern: clear.
    set t [app::_activeSearchText]
    if {$::app::searchPattern eq ""} {
        catch {mdhelp_search::clear $t}
        set ::app::searchStatus ""
        return
    }
    if {[catch {
        set n [mdhelp_search::find $t $::app::searchPattern \
            {*}[app::_searchOpts]]
    } err]} {
        # Bei Regex-Tippfehlern (z.B. unfertiger Klammer): nicht
        # nervig melden, erst beim expliziten Find/Enter.
        return
    }
    if {$n > 0} {
        set idx [expr {[mdhelp_search::current $t] + 1}]
        set ::app::searchStatus "$idx / $n Treffer"
    } else {
        set ::app::searchStatus "Keine Treffer"
    }
}

# Trace einmalig installieren (idempotent)
if {[lsearch -index 1 [trace info variable ::app::searchPattern] \
        app::_onSearchPatternChange] < 0} {
    trace add variable ::app::searchPattern write \
        app::_onSearchPatternChange
}
# Auch bei Optionen-Wechsel neu suchen
foreach _v {::app::searchCase ::app::searchWord ::app::searchRegex} {
    if {[lsearch -index 1 [trace info variable $_v] \
            app::_onSearchPatternChange] < 0} {
        trace add variable $_v write app::_onSearchPatternChange
    }
}
unset -nocomplain _v

# ============================================================
# Toggle Suchleiste
# ============================================================

proc app::toggleSearch {{withReplace 0}} {
    variable searchVisible

    if {$searchVisible && !$withReplace} {
        pack forget .searchbar
        app::hideSearchResults
        set searchVisible 0
        # Sowohl Viewer als auch evtl. aktives Editor-Text-Widget aufraeumen
        catch { mdhelp_search::clear [mdstack::viewer::widget $::app::viewerPath] }
        set te [app::_currentEditorText]
        if {$te ne ""} {
            catch { mdhelp_search::clear $te }
        }
        set ::app::searchStatus ""
    } elseif {$searchVisible && $withReplace} {
        # bereits offen → Replace-Modus toggeln
        set ::app::searchReplace [expr {!$::app::searchReplace}]
        app::_applySearchReplaceMode
        focus .searchbar.f.entry
    } else {
        if {$withReplace} {
            set ::app::searchReplace 1
        }
        pack .searchbar -after .toolbar -fill x -padx 2 -pady 2
        app::_applySearchReplaceMode
        set searchVisible 1
        focus .searchbar.f.entry
        .searchbar.f.entry selection range 0 end
    }
}

proc app::toggleReplace {} {
    app::toggleSearch 1
}

proc app::_applySearchReplaceMode {} {
    # Zeigt/versteckt die Replace-Zeile.
    if {$::app::searchReplace} {
        if {[winfo exists .searchbar.r] && ![winfo ismapped .searchbar.r]} {
            pack .searchbar.r -fill x -padx 0 -pady {2 0}
        }
        catch { .searchbar.btnReplace configure -text "Find/Replace -" }
    } else {
        catch {pack forget .searchbar.r}
        catch { .searchbar.btnReplace configure -text "Replace +" }
    }
}

# ============================================================
# Such-Aktionen
# ============================================================

proc app::doSearch {} {
    variable searchMode
    # In die Historie merken (auch bei leerem Resultat)
    catch { app::rememberSearch }
    if {$searchMode eq "global"} {
        app::doSearchGlobal
    } else {
        app::doSearchPage
    }
}

proc app::_searchOpts {} {
    return [list \
        -case  $::app::searchCase \
        -word  $::app::searchWord \
        -regex $::app::searchRegex]
}

proc app::_activeSearchText {} {
    # Liefert das aktuell zu durchsuchende Text-Widget zurueck:
    # - Im Viewer-Tab: das Viewer-Text-Widget
    # - In einem Editor-Tab: das Editor-Text-Widget
    set tab [$::app::notebook select]
    if {$tab eq ".right.nb.vtab"} {
        return [mdstack::viewer::widget $::app::viewerPath]
    }
    if {[info exists ::app::edKit($tab)]} {
        set ed [mdstack::editorkit::editor $::app::edKit($tab)]
        return [mdstack::text::_t $ed]
    }
    # Fallback
    return [mdstack::viewer::widget $::app::viewerPath]
}

proc app::doSearchPage {} {
    app::hideSearchResults
    set t [app::_activeSearchText]
    if {[catch {
        set n [mdhelp_search::find $t $::app::searchPattern {*}[app::_searchOpts]]
    } err]} {
        set ::app::searchStatus "Regex-Fehler: $err"
        return
    }
    if {$n > 0} {
        set idx [expr {[mdhelp_search::current $t] + 1}]
        set ::app::searchStatus "$idx / $n Treffer"
    } else {
        set ::app::searchStatus "Keine Treffer"
    }
}

proc app::doSearchGlobal {} {
    variable docsRoot
    variable globalResults

    if {$docsRoot eq ""} {
        set ::app::searchStatus "Kein Dokument-Verzeichnis"
        return
    }

    set pattern $::app::searchPattern
    if {$pattern eq ""} return

    # Widget-Suche zuruecksetzen
    mdhelp_search::clear [mdstack::viewer::widget $::app::viewerPath]

    if {[catch {
        set results [mdhelp_search::searchAll $docsRoot $pattern \
            {*}[app::_searchOpts]]
    } err]} {
        set ::app::searchStatus "Regex-Fehler"
        return
    }
    set totalHits  [mdhelp_search::countAllHits $results]
    set totalFiles [llength $results]

    if {$totalHits == 0} {
        set ::app::searchStatus "Keine Treffer"
        app::hideSearchResults
        return
    }

    set ::app::searchStatus "$totalHits Treffer in $totalFiles Dateien"

    set formatted [mdhelp_search::formatResults $results $docsRoot]
    set globalResults $formatted
    app::showSearchResults $formatted $pattern
}

# ============================================================
# Ergebnis-Panel (Text-Widget statt Treeview)
# ============================================================

proc app::_ensureResultsPanel {} {
    # Wandelt das urspruenglich vorhandene Treeview-Panel in
    # ein Text-Widget-Panel um, falls noch nicht geschehen.
    if {[winfo exists .left.results_text]} return

    # alten Treeview entfernen
    catch { destroy .left.results }
    catch { destroy .left.results_sb }

    text .left.results_text -wrap none -cursor arrow \
        -font {TkDefaultFont 9} \
        -yscrollcommand {.left.results_sb set} \
        -xscrollcommand {.left.results_xsb set} \
        -state disabled -takefocus 0 -exportselection 0
    ttk::scrollbar .left.results_sb -orient vertical \
        -command {.left.results_text yview}
    ttk::scrollbar .left.results_xsb -orient horizontal \
        -command {.left.results_text xview}

    pack .left.results_xsb -in .left.results_frame -side bottom -fill x
    pack .left.results_sb  -in .left.results_frame -side right -fill y
    pack .left.results_text -in .left.results_frame -fill both -expand 1

    # Tags
    .left.results_text tag configure resFile \
        -foreground "#336699" -font {TkDefaultFont 9 bold}
    .left.results_text tag configure resLine \
        -foreground "#888888"
    .left.results_text tag configure resCtx \
        -foreground "#000000"
    .left.results_text tag configure resHit \
        -background "#ffd83d" -foreground "#000000"
    .left.results_text tag configure resRow
}

proc app::showSearchResults {formatted pattern} {
    pack .left.results_frame -fill both -expand 1 -padx 2 -pady 2 \
        -after .left.toc_frame

    app::_ensureResultsPanel
    set t .left.results_text
    $t configure -state normal
    $t delete 1.0 end

    # Pro Treffer eine Zeile
    set rowIdx 0
    foreach item $formatted {
        set file    [dict get $item file]
        set lineno  [dict get $item lineno]
        set display [dict get $item display]
        set context [dict get $item context]

        set rowTag "row$rowIdx"
        incr rowIdx

        $t insert end "${display}  " [list resFile $rowTag]

        # Snippet mit Hervorhebung
        set snip [mdhelp_search::snippet $context $pattern \
            -case  $::app::searchCase \
            -word  $::app::searchWord \
            -regex $::app::searchRegex]
        set pre   [dict get $snip pre]
        set match [dict get $snip match]
        set post  [dict get $snip post]

        if {$match ne ""} {
            $t insert end $pre   [list resCtx $rowTag]
            $t insert end $match [list resHit $rowTag]
            $t insert end $post  [list resCtx $rowTag]
        } else {
            $t insert end $context [list resCtx $rowTag]
        }
        $t insert end "\n"

        # Klick-Binding pro row-Tag
        $t tag bind $rowTag <Button-1> \
            [list app::_resultClick $file $lineno $pattern]
        $t tag bind $rowTag <Enter> \
            [list $t tag configure $rowTag -background "#e8f0fe"]
        $t tag bind $rowTag <Leave> \
            [list $t tag configure $rowTag -background ""]
    }
    $t configure -state disabled
}

proc app::_resultClick {file lineno pattern} {
    if {$file ne "" && [file exists $file]} {
        app::openFile $file 1
        # Auf der frisch geladenen Seite die Suche wiederholen,
        # damit alle Treffer hervorgehoben werden.
        set t [mdstack::viewer::widget $::app::viewerPath]
        catch {
            mdhelp_search::find $t $pattern {*}[app::_searchOpts]
        }
        # Such-Tags ueber alle anderen heben (sicherheitshalber).
        mdhelp_search::raiseTags $t
    }
}

proc app::hideSearchResults {} {
    variable globalResults
    catch {pack forget .left.results_frame}
    if {[winfo exists .left.results_text]} {
        .left.results_text configure -state normal
        .left.results_text delete 1.0 end
        .left.results_text configure -state disabled
    }
    set globalResults {}
}

# Kompatibilitaets-Stub: alte onResultSelect war fuer Treeview gedacht.
proc app::onResultSelect {} {
    return
}

# ============================================================
# Next/Prev
# ============================================================

proc app::searchNext {} {
    set t [app::_activeSearchText]
    mdhelp_search::next $t
    set n [mdhelp_search::count $t]
    if {$n > 0} {
        set idx [expr {[mdhelp_search::current $t] + 1}]
        set ::app::searchStatus "$idx / $n Treffer"
    }
}

proc app::searchPrev {} {
    set t [app::_activeSearchText]
    mdhelp_search::prev $t
    set n [mdhelp_search::count $t]
    if {$n > 0} {
        set idx [expr {[mdhelp_search::current $t] + 1}]
        set ::app::searchStatus "$idx / $n Treffer"
    }
}

# ============================================================
# Replace
# ============================================================

proc app::doReplace {} {
    # Im Viewer-Tab gibt es nichts zu ersetzen — der Viewer ist
    # readonly. Wenn ein Editor-Tab aktiv ist, dorthin delegieren.
    set tab [$::app::notebook select]
    if {$tab eq ".right.nb.vtab"} {
        tk_messageBox -icon info -title "Replace" \
            -message "Replace funktioniert nur im Editor-Tab.\n\nOeffne die Datei mit \"Edit\" (Ctrl+E) zum Bearbeiten."
        return
    }
    set t [app::_currentEditorText]
    if {$t eq ""} return

    if {[mdhelp_search::count $t] == 0} {
        if {[catch {
            mdhelp_search::find $t $::app::searchPattern \
                {*}[app::_searchOpts]
        } err]} {
            set ::app::searchStatus "Regex-Fehler"
            return
        }
        if {[mdhelp_search::count $t] == 0} {
            set ::app::searchStatus "Keine Treffer"
            return
        }
    }

    set ok [mdhelp_search::replaceCurrent $t $::app::replacePattern]
    if {$ok} {
        catch { app::rememberSearch }
        catch { app::rememberReplace }
        set n [mdhelp_search::count $t]
        if {$n == 0} {
            set ::app::searchStatus "Ersetzt — keine weiteren Treffer"
        } else {
            set idx [expr {[mdhelp_search::current $t] + 1}]
            set ::app::searchStatus "Ersetzt -> $idx / $n Treffer"
        }
        app::_markEditorDirty $t
    } else {
        set ::app::searchStatus "Replace nicht moeglich"
    }
}

proc app::doReplaceAll {} {
    set tab [$::app::notebook select]
    if {$tab eq ".right.nb.vtab"} {
        tk_messageBox -icon info -title "Replace All" \
            -message "Replace funktioniert nur im Editor-Tab."
        return
    }
    set t [app::_currentEditorText]
    if {$t eq ""} return
    if {$::app::searchPattern eq ""} return

    if {[catch {
        set n [mdhelp_search::replaceAll $t \
            $::app::searchPattern $::app::replacePattern \
            {*}[app::_searchOpts]]
    } err]} {
        set ::app::searchStatus "Regex-Fehler"
        return
    }
    if {$n > 0} {
        catch { app::rememberSearch }
        catch { app::rememberReplace }
        set ::app::searchStatus "$n Vorkommen ersetzt"
        app::_markEditorDirty $t
    } else {
        set ::app::searchStatus "Keine Treffer"
    }
}

proc app::doReplaceNext {} {
    app::doReplace
    set tab [$::app::notebook select]
    if {$tab ne ".right.nb.vtab"} {
        set t [app::_currentEditorText]
        if {$t ne "" && [mdhelp_search::count $t] > 0} {
            mdhelp_search::next $t
        }
    }
}

# ============================================================
# Hilfsroutinen fuer Editor-Tab
# ============================================================

proc app::_currentEditorText {} {
    set tab [$::app::notebook select]
    if {$tab eq ".right.nb.vtab"} { return "" }
    if {![info exists ::app::edKit($tab)]} { return "" }
    set ed [mdstack::editorkit::editor $::app::edKit($tab)]
    return [mdstack::text::_t $ed]
}

proc app::_markEditorDirty {t} {
    foreach w $::app::editorTabs {
        if {![info exists ::app::edKit($w)]} continue
        set ed [mdstack::editorkit::editor $::app::edKit($w)]
        set tw [mdstack::text::_t $ed]
        if {$tw eq $t} {
            set ::app::edDirty($w) 1
            if {[info exists ::app::edFile($w)]} {
                catch {
                    $::app::notebook tab $w \
                        -text "* [file tail $::app::edFile($w)]"
                }
            }
            return
        }
    }
}

# ============================================================
# Font Size
# ============================================================
