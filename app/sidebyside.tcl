# sidebyside.tcl -- Original + Übersetzung nebeneinander
#
# Öffnet ein zweites Toplevel mit zwei Read-Only-Panes, links das
# englische Original (Markdown oder nroff), rechts die aktuelle
# deutsche Übersetzung.
#
# Auto-Pairing: aus dem Frontmatter `original: NAME.n` einer
# tcl9-de/-Datei wird der Pfad zum englischen .n gesucht in:
#
#   $::env(TCL_DOC_ROOT)/<NAME>.n
#   ~/lib/tcltk/tcl9.0/doc/<NAME>.n
#   ~/lib/tcltk/tcl-9.0/doc/<NAME>.n
#   $docsRoot/../tcl9.0/doc/<NAME>.n
#   $docsRoot/../tcl-9.0/doc/<NAME>.n
#   $docsRoot/../../tcl9.0/doc/<NAME>.n
#
# Wenn nichts gefunden wird: file dialog.

namespace eval ::sbs {
    variable win        ".sbs"
    variable leftFile   ""
    variable rightFile  ""
    variable searchPath {}
}

proc ::sbs::_initSearchPath {} {
    variable searchPath
    set searchPath {}
    if {[info exists ::env(TCL_DOC_ROOT)]} {
        lappend searchPath $::env(TCL_DOC_ROOT)
    }
    if {[info exists ::env(HOME)]} {
        foreach name {tcl9.0 tcl-9.0 tcl9.1 tcl-9.1 tcl8.6 tcl-8.6} {
            lappend searchPath \
                [file join $::env(HOME) lib tcltk $name doc]
        }
    }
    if {[info exists ::app::docsRoot] && $::app::docsRoot ne ""} {
        set parent [file dirname $::app::docsRoot]
        foreach name {tcl9.0 tcl-9.0 tcl9.1 tcl-9.1} {
            lappend searchPath [file join $parent $name doc]
            lappend searchPath [file join $parent .. $name doc]
        }
    }
}

proc ::sbs::_findOriginal {currentFile} {
    # Liest Frontmatter, sucht nach 'original: NAME'
    if {![file exists $currentFile]} { return "" }
    set fh [open $currentFile r]
    fconfigure $fh -encoding utf-8
    set head [read $fh 2000]
    close $fh

    set origName ""
    if {[regexp -line {^original:\s*(\S+)\s*$} $head _ origName]} {
        # ok
    }
    if {$origName eq ""} { return "" }

    ::sbs::_initSearchPath
    variable searchPath
    foreach dir $searchPath {
        set candidate [file normalize [file join $dir $origName]]
        if {[file exists $candidate]} { return $candidate }
    }
    return ""
}

proc ::sbs::open {currentFile} {
    variable win
    variable leftFile
    variable rightFile

    if {$currentFile eq "" || ![file exists $currentFile]} {
        tk_messageBox -icon info -title "Side-by-Side" \
            -message "Keine Datei aktiv."
        return
    }

    set rightFile $currentFile
    set leftFile  [::sbs::_findOriginal $currentFile]

    if {$leftFile eq ""} {
        # Manuell suchen lassen
        set leftFile [tk_getOpenFile -title "Englisches Original auswählen" \
            -filetypes {
                {"nroff" {.n .1 .3 .3tcl}}
                {"Markdown" {.md}}
                {"All" *}
            }]
        if {$leftFile eq ""} return
    }

    ::sbs::_buildWindow
    ::sbs::_loadInto .sbs.left.t  $leftFile
    ::sbs::_loadInto .sbs.right.t $rightFile
}

proc ::sbs::_buildWindow {} {
    variable win
    catch {destroy $win}
    toplevel $win
    wm title $win "Side-by-Side: Original / Übersetzung"
    wm geometry $win 1400x800

    ttk::panedwindow $win.pw -orient horizontal
    pack $win.pw -fill both -expand 1

    # Linke Seite — Original
    ttk::labelframe $win.left -text "Original"
    $win.pw add $win.left -weight 1
    text $win.left.t -wrap word -font {TkDefaultFont 11} \
        -yscrollcommand [list ::sbs::_syncScroll $win.left $win.right $win.left.sb] \
        -state disabled
    ttk::scrollbar $win.left.sb -orient vertical \
        -command [list $win.left.t yview]
    pack $win.left.sb -side right -fill y
    pack $win.left.t  -fill both -expand 1

    # Rechte Seite — Übersetzung
    ttk::labelframe $win.right -text "Übersetzung"
    $win.pw add $win.right -weight 1
    text $win.right.t -wrap word -font {TkDefaultFont 11} \
        -yscrollcommand [list ::sbs::_syncScroll $win.right $win.left $win.right.sb] \
        -state disabled
    ttk::scrollbar $win.right.sb -orient vertical \
        -command [list $win.right.t yview]
    pack $win.right.sb -side right -fill y
    pack $win.right.t  -fill both -expand 1

    # Toolbar
    ttk::frame $win.bar
    pack $win.bar -side bottom -fill x -before $win.pw
    ttk::button $win.bar.swap -text "Tausch L↔R" \
        -command ::sbs::_swap
    ttk::button $win.bar.close -text "Schließen" \
        -command [list destroy $win]
    pack $win.bar.close -side right -padx 4 -pady 2
    pack $win.bar.swap  -side right -padx 4 -pady 2

    bind $win <Escape> [list destroy $win]
}

proc ::sbs::_loadInto {textWidget file} {
    if {![file exists $file]} {
        $textWidget configure -state normal
        $textWidget delete 1.0 end
        $textWidget insert end "Datei nicht gefunden: $file"
        $textWidget configure -state disabled
        return
    }

    set fh [open $file r]
    fconfigure $fh -encoding utf-8
    if {[catch {set content [read $fh]} err]} {
        close $fh
        set fh [open $file r]
        fconfigure $fh -encoding iso8859-1
        set content [read $fh]
    }
    close $fh

    set ext [string tolower [file extension $file]]
    set isNroff [expr {$ext in {.n .1 .2 .3 .4 .5 .6 .7 .8 .9 ".3tcl" ".ntcl" ".man"}}]

    $textWidget configure -state normal
    $textWidget delete 1.0 end

    if {$isNroff && [info exists ::hasNroff] && $::hasNroff} {
        if {[catch {
            set ast [nroffparser::parse $content $file]
            nroffrenderer::render $ast $textWidget \
                [dict create fontSize $::app::fontSize]
        } err]} {
            $textWidget insert end "nroff-Parse-Fehler: $err\n\n$content"
        }
    } else {
        # Markdown oder Plain-Text — einfach so anzeigen
        $textWidget insert end $content
    }

    $textWidget configure -state disabled
    set parent [winfo parent $textWidget]
    $parent configure -text "[file tail $file] — $file"
}

# Synchron-Scroll: wenn ein Pane scrollt, scrollt der andere mit
# (proportional). Vermeidet Endlos-Loops via flag.

namespace eval ::sbs {
    variable _syncing 0
}

proc ::sbs::_syncScroll {selfFrame otherFrame sbWidget args} {
    variable _syncing
    # erst die eigene Scrollbar aktualisieren
    catch { $sbWidget set {*}$args }
    # dann den anderen Pane mitziehen
    if {$_syncing} return
    if {[llength $args] >= 2} {
        set first [lindex $args 0]
        set _syncing 1
        catch { $otherFrame.t yview moveto $first }
        set _syncing 0
    }
}

proc ::sbs::_swap {} {
    variable leftFile
    variable rightFile
    set tmp $leftFile
    set leftFile $rightFile
    set rightFile $tmp
    ::sbs::_loadInto .sbs.left.t  $leftFile
    ::sbs::_loadInto .sbs.right.t $rightFile
}
