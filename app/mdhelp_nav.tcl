
# ============================================================
# File tree
# ============================================================
proc app::loadTree {root} {
    variable docsRoot
    set docsRoot [file normalize $root]

    # Remember last folders
    app::addRecentDir $docsRoot

    .left.tree delete [.left.tree children {}]
    app::_addTreeDir {} $docsRoot
}


namespace eval app {
    variable nroffExts {.n .1 .2 .3 .4 .5 .6 .7 .8 .9 .3tcl .ntcl .man}
}

proc app::_isVisibleDocFile {file} {
    set ext [string tolower [file extension $file]]
    if {$ext eq ".md"} { return 1 }
    if {$ext in $::app::nroffExts} { return 1 }
    return 0
}


proc app::_addTreeDir {parent dir} {
    variable docsRoot

    # Wenn Filter gesetzt: nur Dateien zeigen, die matchen ODER deren
    # Vater-Dir matchende Kinder hat.
    set filt ""
    if {[info exists ::app::treeFilter]} {
        set filt [string trim $::app::treeFilter]
    }

    # Alle relevanten Doku-Dateien einsammeln (md + nroff)
    set allFiles [list]
    foreach f [glob -nocomplain -directory $dir -types f *] {
        if {[app::_isVisibleDocFile $f]} { lappend allFiles $f }
    }
    set allFiles [lsort $allFiles]

    if {$filt eq ""} {
        # Standardverhalten ohne Filter
        foreach d [lsort [glob -nocomplain -directory $dir -types d *]] {
            set name [file tail $d]
            if {[string match .* $name]} continue
            set id [.left.tree insert $parent end -text $name -open 0 \
                -values [list $d "dir"]]
            app::_addTreeDir $id $d
        }
        foreach f $allFiles {
            set name [file tail $f]
            if {$name eq "index.md"} continue
            # Anzeige-Name: für .md ohne Extension, für .n MIT Extension
            set ext [string tolower [file extension $name]]
            if {$ext eq ".md"} {
                set display [file rootname $name]
            } else {
                set display $name  ;# nroff-Files mit Extension zeigen
            }
            .left.tree insert $parent end -text $display \
                -values [list $f "file"]
        }
        return
    }

    # Mit Filter: rekursiv prüfen ob ein Match unterhalb existiert
    foreach d [lsort [glob -nocomplain -directory $dir -types d *]] {
        set name [file tail $d]
        if {[string match .* $name]} continue
        if {[app::_dirHasMatch $d $filt]} {
            set id [.left.tree insert $parent end -text $name -open 1 \
                -values [list $d "dir"]]
            app::_addTreeDir $id $d
        }
    }
    foreach f $allFiles {
        set name [file tail $f]
        if {$name eq "index.md"} continue
        set ext [string tolower [file extension $name]]
        if {$ext eq ".md"} {
            set display [file rootname $name]
        } else {
            set display $name
        }
        if {[string match -nocase "*${filt}*" $display]} {
            .left.tree insert $parent end -text $display \
                -values [list $f "file"]
        }
    }
}

proc app::_dirHasMatch {dir filt} {
    foreach f [glob -nocomplain -directory $dir -types f *] {
        if {![app::_isVisibleDocFile $f]} continue
        set name [file tail $f]
        if {$name eq "index.md"} continue
        set ext [string tolower [file extension $name]]
        if {$ext eq ".md"} {
            set checkName [file rootname $name]
        } else {
            set checkName $name
        }
        if {[string match -nocase "*${filt}*" $checkName]} { return 1 }
    }
    foreach d [glob -nocomplain -directory $dir -types d *] {
        if {[string match .* [file tail $d]]} continue
        if {[app::_dirHasMatch $d $filt]} { return 1 }
    }
    return 0
}


proc app::onTreeSelect {} {
    set sel [.left.tree selection]
    if {$sel eq ""} return

    set vals [.left.tree item $sel -values]
    lassign $vals path type

    if {$type eq "file"} {
        # Same file? Skip re-rendering
        if {[file normalize $path] eq [file normalize $::app::currentFile]} return
        app::openFile $path 1
    } elseif {$type eq "dir"} {
        # Directory: show index.md if present
        set idx [file join $path index.md]
        if {[file exists $idx]} {
            if {[file normalize $idx] eq [file normalize $::app::currentFile]} return
            app::openFile $idx 1
        }
    }
}


# ============================================================
# Load and render document
# ============================================================
proc app::openFile {file {pushHistory 1}} {
    variable currentFile
    variable currentDoc
    variable currentAst
    variable docsRoot
    variable scrollPos

    set file [file normalize $file]

    if {![file exists $file]} {
        set ::app::statusText "File not found: $file"
        return
    }

    # Scroll-Position des aktuellen Dokuments speichern
    if {$currentFile ne ""} {
        set t [mdstack::viewer::widget $::app::viewerPath]
        set scrollPos($currentFile) [lindex [$t yview] 0]
    }

    # Read file (UTF-8 with fallback to Latin-1 for Tcl 9 compatibility)
    set fh [open $file r]
    fconfigure $fh -encoding utf-8
    if {[catch {set markdown [read $fh]} err]} {
        # Ungueltige UTF-8-Bytes: erneut als Latin-1 lesen
        close $fh
        set fh [open $file r]
        fconfigure $fh -encoding iso8859-1
        set markdown [read $fh]
    }
    close $fh

    # Format-Erkennung: Markdown vs nroff
    set ext [string tolower [file extension $file]]
    set isNroff [expr {$ext in {.n .1 .2 .3 .4 .5 .6 .7 .8 .9 ".3tcl" ".ntcl" ".man"}}]

    if {$isNroff && ![info exists ::hasNroff]} { set ::hasNroff 0 }
    if {$isNroff && !$::hasNroff} {
        # nroff-Module nicht installiert → einfache Anzeige als Plaintext
        set t [mdstack::viewer::widget $::app::viewerPath]
        $t configure -state normal
        $t delete 1.0 end
        $t insert end "[Plain-Text-Anzeige — nroff-Renderer fehlt.\n"
        $t insert end "Installiere die Pakete nroffparser/nroffrenderer aus man-viewer.]\n\n"
        $t insert end $markdown
        $t configure -state disabled
        set currentDoc {}
        set currentAst {}
    } elseif {$isNroff} {
        # nroff via nroffparser+nroffrenderer rendern
        if {[catch {
            set ast [nroffparser::parse $markdown $file]
            set t [mdstack::viewer::widget $::app::viewerPath]
            mdstack::viewer::clear $::app::viewerPath
            $t configure -state normal
            nroffrenderer::render $ast $t \
                [dict create fontSize $::app::fontSize]
            $t configure -state disabled
            set currentDoc {}
            set currentAst {}
        } err]} {
            set ::app::statusText "nroff-Parse-Fehler: $err"
            set t [mdstack::viewer::widget $::app::viewerPath]
            $t configure -state normal
            $t delete 1.0 end
            $t insert end "Konnte nroff-Datei nicht parsen:\n\n$err"
            $t configure -state disabled
        }
    } else {
        # Markdown-Pfad (Standard)
        set tokens [mdstack::parser::parse $markdown]
        set currentDoc [mdstack::model::new $tokens]
        set currentAst [mdstack::model::ast $currentDoc]

        mdstack::viewer::configure $::app::viewerPath -root [file dirname $file]
        mdstack::viewer::render $::app::viewerPath $currentAst

        # TIP-700-Styling (Span-Farben + Div-Hintergruende)
        app::applyTip700Styling
    }

    # Such-Tags ueber alle anderen heben (sicherheitshalber, da
    # initTags / applyTip700Styling spaeter neue Tags erzeugen koennen).
    set t [mdstack::viewer::widget $::app::viewerPath]
    catch { mdhelp_search::raiseTags $t }

    set currentFile $file

    # History
    if {$pushHistory} {
        set t [mdstack::viewer::widget $::app::viewerPath]
        mdhelp_history::push $t $file
        # Recent Files aktualisieren (nur bei explizitem Open)
        catch {app::addRecentFile $file}
    }

    # Reset search
    mdhelp_search::clear [mdstack::viewer::widget $::app::viewerPath]
    set ::app::searchStatus ""

    # Scroll-Position wiederherstellen falls gespeichert.
    # render() scrollt selbst nach 1.0 — wir korrigieren danach.
    if {[info exists scrollPos($file)]} {
        # idle-call, damit Render und Geometry fertig sind
        after idle [list catch [list \
            [mdstack::viewer::widget $::app::viewerPath] yview moveto \
            $scrollPos($file)]]
    }

    # Update UI
    app::updateBreadcrumb
    app::updateToc
    app::updateButtons
    app::updateStatus
    app::syncTree
}


# ============================================================
# Navigation
# ============================================================
proc app::onLink {url} {
    variable currentFile
    variable docsRoot

    # Open external URLs in browser
    if {[mdstack::viewer::isAbsUrl $url]} {
        app::openExternal $url
        return
    }

    # Separate anchor BEFORE normalize (# in path confuses normalize)
    set anchor ""
    if {[regexp {^(.+)#(.+)$} $url -> urlPath anchorPart]} {
        set url $urlPath
        set anchor $anchorPart
    } elseif {[string index $url 0] eq "#"} {
        # Pure anchor link: just jump
        mdstack::viewer::gotoAnchor $::app::viewerPath [string range $url 1 end]
        return
    }

    # Relative URL aufloesen
    set baseDir [file dirname $currentFile]
    set target [file normalize [file join $baseDir $url]]

    if {[file exists $target]} {
        app::openFile $target 1
        if {$anchor ne ""} {
            mdstack::viewer::gotoAnchor $::app::viewerPath $anchor
        }
    } else {
        set ::app::statusText "Link target not found: $url"
    }
}


proc app::goBack {} {
    set t [mdstack::viewer::widget $::app::viewerPath]
    mdhelp_history::back $t
    app::updateButtons
}


proc app::goForward {} {
    set t [mdstack::viewer::widget $::app::viewerPath]
    mdhelp_history::forward $t
    app::updateButtons
}


proc app::goHome {} {
    variable docsRoot
    if {$docsRoot eq ""} return

    set idx [file join $docsRoot index.md]
    if {[file exists $idx]} {
        app::openFile $idx 1
    } else {
        # Erste .md Datei nehmen
        set files [glob -nocomplain -directory $docsRoot *.md]
        if {[llength $files] > 0} {
            app::openFile [lindex [lsort $files] 0] 1
        }
    }
}


proc app::openFolder {} {
    # Dialog zum Auswaehlen eines Dokumenten-Verzeichnisses.
    variable docsRoot

    set initDir $docsRoot
    if {$initDir eq ""} {
        set initDir [pwd]
    }

    set dir [tk_chooseDirectory \
        -title "Open Document Folder" \
        -initialdir $initDir \
        -mustexist 1]

    if {$dir eq ""} return

    # Check if .md files are present
    set mdFiles [glob -nocomplain -directory $dir *.md]
    set subDirs [glob -nocomplain -directory $dir -types d *]
    if {[llength $mdFiles] == 0 && [llength $subDirs] == 0} {
        tk_messageBox -icon warning -title "No Documents" \
            -message "No Markdown files found in:\n$dir"
        return
    }

    # Load new tree
    app::loadTree $dir
    app::goHome
    set ::app::statusText "Opened: $dir"
}


proc app::reload {} {
    # Reload and render current file.
    variable currentFile
    if {$currentFile eq "" || ![file exists $currentFile]} return

    # Scroll-Position merken
    set t [mdstack::viewer::widget $::app::viewerPath]
    set ypos [lindex [$t yview] 0]

    app::openFile $currentFile 0

    # Scroll-Position wiederherstellen
    $t yview moveto $ypos

    set ::app::statusText "Neu geladen: [file tail $currentFile]"
}


proc app::openExternal {url} {
    # URL im Systembrowser oeffnen
    switch -- $::tcl_platform(os) {
        "Windows NT" { exec {*}[auto_execok start] {} $url & }
        "Darwin"     { exec open $url & }
        default      { catch {exec xdg-open $url &} }
    }
}


# ============================================================
# Link-Tooltip (Hover)
# ============================================================
proc app::onHover {url} {
    if {$url eq ""} {
        app::updateStatus
    } else {
        set ::app::statusText $url
    }
}


# ============================================================
# Baum-Kontextmenue
# ============================================================
proc app::treeContextMenu {x y rootX rootY} {
    set item [.left.tree identify item $x $y]
    if {$item eq ""} return

    set vals [.left.tree item $item -values]
    lassign $vals path type

    if {$type ne "file"} return

    .left.tree selection set $item

    # Kontextmenue
    if {![winfo exists .treemenu]} {
        menu .treemenu -tearoff 0
    }
    .treemenu delete 0 end

    .treemenu add command -label "Open" \
        -command [list app::openFile $path 1]
    .treemenu add command -label "Im Editor oeffnen" \
        -command [list app::openInEditor $path]
    .treemenu add separator
    .treemenu add command -label "Pfad kopieren" \
        -command "clipboard clear; clipboard append [list $path]"

    tk_popup .treemenu $rootX $rootY
}


proc app::restoreScroll {file} {
    # Stellt die Scroll-Position fuer eine Datei wieder her.
    variable scrollPos
    set file [file normalize $file]
    if {[info exists scrollPos($file)]} {
        set t [mdstack::viewer::widget $::app::viewerPath]
        $t yview moveto $scrollPos($file)
    }
}


# ============================================================
# Tree-Filter Trace (Debounced Reload)
# ============================================================

set ::app::treeFilter ""
set ::app::_treeFilterDebounceId ""
set ::app::_treeFilterDebounceMs 200

proc app::_onTreeFilterChange {args} {
    if {$::app::_treeFilterDebounceId ne ""} {
        catch {after cancel $::app::_treeFilterDebounceId}
    }
    set ::app::_treeFilterDebounceId [after \
        $::app::_treeFilterDebounceMs app::_runTreeFilter]
}

proc app::_runTreeFilter {} {
    set ::app::_treeFilterDebounceId ""
    if {$::app::docsRoot eq ""} return
    catch {.left.tree delete [.left.tree children {}]}
    catch {app::_addTreeDir {} $::app::docsRoot}
    # Falls eine Datei aktiv ist, syncTree wieder ausfuehren
    catch {app::syncTree}
}

if {[lsearch -index 1 [trace info variable ::app::treeFilter] \
        app::_onTreeFilterChange] < 0} {
    trace add variable ::app::treeFilter write \
        app::_onTreeFilterChange
}
