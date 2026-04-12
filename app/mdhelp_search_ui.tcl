# mdhelp_search_ui.tcl -- Such-UI (Prio 12: aus mdhelp.tcl extrahiert)
#
# Enthaelt: toggleSearch, doSearch, doSearchPage, doSearchGlobal,
#           showSearchResults, hideSearchResults, onResultSelect,
#           searchNext, searchPrev.
#
# Wird von mdhelp.tcl via source geladen.

if {![namespace exists ::app]} {
    error "mdhelp_search_ui.tcl muss von mdhelp.tcl geladen werden (namespace app fehlt)"
}

# Suche
# ============================================================
proc app::toggleSearch {} {
    variable searchVisible

    if {$searchVisible} {
        pack forget .searchbar
        app::hideSearchResults
        set searchVisible 0
        mdhelp_search::clear [mdviewer::widget $::app::viewerPath]
        set ::app::searchStatus ""
    } else {
        pack .searchbar -after .toolbar -fill x -padx 2 -pady 2
        set searchVisible 1
        focus .searchbar.entry
        .searchbar.entry selection range 0 end
    }
}

proc app::doSearch {} {
    variable searchMode
    if {$searchMode eq "global"} {
        app::doSearchGlobal
    } else {
        app::doSearchPage
    }
}

proc app::doSearchPage {} {
    app::hideSearchResults
    set t [mdviewer::widget $::app::viewerPath]
    set n [mdhelp_search::find $t $::app::searchPattern]
    if {$n > 0} {
        set idx [expr {[mdhelp_search::current $t] + 1}]
        set ::app::searchStatus "$idx / $n matches"
    } else {
        set ::app::searchStatus "No matches"
    }
}

proc app::doSearchGlobal {} {
    variable docsRoot
    variable globalResults

    if {$docsRoot eq ""} {
        set ::app::searchStatus "No document directory"
        return
    }

    set pattern $::app::searchPattern
    if {$pattern eq ""} return

    # Reset widget search
    mdhelp_search::clear [mdviewer::widget $::app::viewerPath]

    # Search all files
    set results [mdhelp_search::searchAll $docsRoot $pattern]
    set totalHits [mdhelp_search::countAllHits $results]
    set totalFiles [llength $results]

    if {$totalHits == 0} {
        set ::app::searchStatus "No matches"
        app::hideSearchResults
        return
    }

    set ::app::searchStatus "$totalHits matches in $totalFiles files"

    # Format and display results
    set formatted [mdhelp_search::formatResults $results $docsRoot]
    set globalResults $formatted
    app::showSearchResults $formatted
}

proc app::showSearchResults {formatted} {
    # Show panel
    pack .left.results_frame -fill both -expand 1 -padx 2 -pady 2 \
        -after .left.toc_frame

    # Delete old entries
    .left.results delete [.left.results children {}]

    # Insert results
    foreach item $formatted {
        lassign $item file lineno display
        .left.results insert {} end -text $display \
            -values [list $file $lineno]
    }
}

proc app::hideSearchResults {} {
    variable globalResults
    catch {pack forget .left.results_frame}
    catch {.left.results delete [.left.results children {}]}
    set globalResults {}
}

proc app::onResultSelect {} {
    set sel [.left.results selection]
    if {$sel eq ""} return

    set vals [.left.results item $sel -values]
    lassign $vals file lineno

    if {$file ne "" && [file exists $file]} {
        app::openFile $file 1
        # Nach dem Oeffnen: Seitensuche ausfuehren
        # damit die Treffer im Viewer hervorgehoben werden
        set t [mdviewer::widget $::app::viewerPath]
        mdhelp_search::find $t $::app::searchPattern
    }
}

proc app::searchNext {} {
    set t [mdviewer::widget $::app::viewerPath]
    mdhelp_search::next $t
    set n [mdhelp_search::count $t]
    if {$n > 0} {
        set idx [expr {[mdhelp_search::current $t] + 1}]
        set ::app::searchStatus "$idx / $n matches"
    }
}

proc app::searchPrev {} {
    set t [mdviewer::widget $::app::viewerPath]
    mdhelp_search::prev $t
    set n [mdhelp_search::count $t]
    if {$n > 0} {
        set idx [expr {[mdhelp_search::current $t] + 1}]
        set ::app::searchStatus "$idx / $n matches"
    }
}

# ============================================================
# Font Size
