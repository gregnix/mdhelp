
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


proc app::_addTreeDir {parent dir} {
    variable docsRoot

    # Directories
    foreach d [lsort [glob -nocomplain -directory $dir -types d *]] {
        set name [file tail $d]
        if {[string match .* $name]} continue
        set id [.left.tree insert $parent end -text $name -open 0 \
            -values [list $d "dir"]]
        app::_addTreeDir $id $d
    }

    # Markdown files
    foreach f [lsort [glob -nocomplain -directory $dir -types f *.md]] {
        set name [file tail $f]
        # index.md ausblenden (wird automatisch angezeigt)
        if {$name eq "index.md"} continue
        set display [file rootname $name]
        .left.tree insert $parent end -text $display \
            -values [list $f "file"]
    }
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
        set t [mdviewer::widget $::app::viewerPath]
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

    # Parsen + Rendern
    set tokens [mdparser::parse $markdown]
    set currentDoc [mdmodel::new $tokens]
    set currentAst [mdmodel::ast $currentDoc]

    mdviewer::configure $::app::viewerPath -root [file dirname $file]
    mdviewer::render $::app::viewerPath $currentAst

    # TIP-700-Styling (Span-Farben + Div-Hintergruende)
    app::applyTip700Styling

    set currentFile $file

    # History
    if {$pushHistory} {
        set t [mdviewer::widget $::app::viewerPath]
        mdhelp_history::push $t $file
    }

    # Reset search
    mdhelp_search::clear [mdviewer::widget $::app::viewerPath]
    set ::app::searchStatus ""

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
    if {[mdviewer::isAbsUrl $url]} {
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
        mdviewer::gotoAnchor $::app::viewerPath [string range $url 1 end]
        return
    }

    # Relative URL aufloesen
    set baseDir [file dirname $currentFile]
    set target [file normalize [file join $baseDir $url]]

    if {[file exists $target]} {
        app::openFile $target 1
        if {$anchor ne ""} {
            mdviewer::gotoAnchor $::app::viewerPath $anchor
        }
    } else {
        set ::app::statusText "Link target not found: $url"
    }
}


proc app::goBack {} {
    set t [mdviewer::widget $::app::viewerPath]
    mdhelp_history::back $t
    app::updateButtons
}


proc app::goForward {} {
    set t [mdviewer::widget $::app::viewerPath]
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
    set t [mdviewer::widget $::app::viewerPath]
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
        set t [mdviewer::widget $::app::viewerPath]
        $t yview moveto $scrollPos($file)
    }
}

