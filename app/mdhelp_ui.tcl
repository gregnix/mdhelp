# mdhelp_ui.tcl -- UI-Updates und Darstellung
#
# Ausgelagert aus mdhelp.tcl (Prio 12).
# 13 Procs: TOC, Breadcrumb, Buttons, Status, Meta, Theme, Tabs.
#
# Wird via source eingebunden, gleicher Namespace app::.


# ============================================================
# TOC (Inhaltsverzeichnis)
# ============================================================
proc app::updateToc {} {
    variable currentDoc
    .left.toc delete [.left.toc children {}]

    if {$currentDoc eq ""} return

    foreach h [mdstack::model::headings $currentDoc] {
        set level  [dict get $h level]
        set text   [dict get $h text]
        set anchor [dict get $h anchor]

        set indent [string repeat "  " [expr {$level - 1}]]
        .left.toc insert {} end -text "${indent}${text}" \
            -values [list $anchor $level]
    }
}


proc app::onTocSelect {} {
    set sel [.left.toc selection]
    if {$sel eq ""} return

    set vals [.left.toc item $sel -values]
    set anchor [lindex $vals 0]
    if {$anchor ne ""} {
        mdstack::viewer::gotoAnchor $::app::viewerPath $anchor
    }
}


# ============================================================
# Breadcrumb
# ============================================================
proc app::updateBreadcrumb {} {
    variable currentFile
    variable docsRoot

    if {$currentFile eq "" || $docsRoot eq ""} {
        set ::app::breadcrumb ""
        return
    }

    set rel [app::_relPath $currentFile $docsRoot]
    set parts [file split $rel]
    set ::app::breadcrumb [join $parts " > "]
}


proc app::_relPath {file root} {
    set file [file normalize $file]
    set root [file normalize [string trimright $root "/\\"]]

    if {[string first $root $file] == 0} {
        set rel [string range $file [string length $root] end]
        set rel [string trimleft $rel "/\\"]
        if {$rel eq ""} { return [file tail $file] }
        return $rel
    }
    return [file tail $file]
}


# ============================================================
# UI-Updates
# ============================================================
proc app::updateButtons {} {
    set t [mdstack::viewer::widget $::app::viewerPath]

    if {[mdhelp_history::canBack $t]} {
        .toolbar.back state !disabled
    } else {
        .toolbar.back state disabled
    }

    if {[mdhelp_history::canForward $t]} {
        .toolbar.fwd state !disabled
    } else {
        .toolbar.fwd state disabled
    }
}


proc app::updateStatus {} {
    variable currentFile
    variable currentAst
    variable docsRoot
    if {$currentFile eq ""} return

    set name [file tail $currentFile]
    set rel [app::_relPath $currentFile $docsRoot]
    set ::app::statusText $rel

    # Display YAML frontmatter in title
    set title "mdhelp 4 - $name"
    if {$currentAst ne "" && [dict exists $currentAst meta]} {
        set meta [dict get $currentAst meta]
        if {[dict exists $meta title]} {
            set title "mdhelp 4 - [dict get $meta title]"
            if {[dict exists $meta section]} {
                append title " ([dict get $meta section])"
            }
        }
    }
    wm title . $title

    # Frontmatter-Panel aktualisieren
    app::updateMetaPanel
}


proc app::updateMetaPanel {} {
    variable currentAst

    set ::app::metaTitle ""
    set ::app::metaSection ""
    set ::app::metaVersion ""

    if {$currentAst ne "" && [dict exists $currentAst meta]} {
        set meta [dict get $currentAst meta]
        if {[dict exists $meta title]} {
            set ::app::metaTitle [dict get $meta title]
        }
        if {[dict exists $meta section]} {
            set ::app::metaSection "([dict get $meta section])"
        }
        if {[dict exists $meta version]} {
            set ::app::metaVersion "v[dict get $meta version]"
        } elseif {[dict exists $meta manual-section]} {
            set ::app::metaVersion [dict get $meta manual-section]
        }
    }

    # Panel ein-/ausblenden
    if {$::app::metaTitle ne ""} {
        pack .right.nb.vtab.meta -before .right.nb.vtab.viewer \
            -fill x -padx 2 -pady {2 0}
    } else {
        pack forget .right.nb.vtab.meta
    }
}


# ============================================================
# TIP-700-Styling (Span-Farben + Div-Hintergruende)
# ============================================================
proc app::setTheme {name} {
    variable theme
    set theme $name
    mdstack::theme::activate $name

    # Update viewer
    mdstack::theme::applyToViewer $::app::viewerPath
    app::applyTip700Styling

    # Seite neu rendern damit alle Tags stimmen
    app::reload

    # Save setting
    app::saveSettings
}


proc app::applyTip700Styling {} {
    variable fontSize
    set t [mdstack::viewer::widget $::app::viewerPath]

    # Span-Klassen: Farben aus Theme
    foreach {cls styleType} {
        cmd bold  sub bold  lit bold  optlit bold
        arg italic  optarg italic  optdot italic
        ins italic  ccmd bold  cargs italic  ret {}
    } {
        set tag "span_${cls}"
        set fg [mdstack::theme::color "span_${cls}"]
        if {$styleType ne ""} {
            $t tag configure $tag -foreground $fg \
                -font [list {} $fontSize $styleType]
        } else {
            $t tag configure $tag -foreground $fg
        }
        $t tag raise $tag
    }

    # Div-Klassen: Hintergrundfarben aus Theme
    foreach cls {synopsis example arguments note warning} {
        set bg [mdstack::theme::color "div_${cls}"]
        $t tag configure "div_${cls}" -background $bg \
            -lmargin1 12 -lmargin2 12 -rmargin 12 \
            -spacing1 4 -spacing3 4
    }
}


# ============================================================
proc app::changeFontSize {delta} {
    variable fontSize

    set newSize [expr {$fontSize + $delta}]
    if {$newSize < 8 || $newSize > 24} return

    set fontSize $newSize
    mdstack::viewer::setFontSize $::app::viewerPath $newSize
    set ::app::statusText "Font size: ${newSize}pt"
}


proc app::onTabChanged {} {
    # Wird aufgerufen wenn der Notebook-Tab wechselt.
    # Setzt den Fenstertitel passend.
    variable notebook
    set sel [$notebook select]
    if {$sel eq ".right.nb.vtab"} {
        # Viewer-Tab: normaler Titel
        variable currentFile
        app::updateStatus
    }
}


proc app::syncTree {} {
    # Mark current file in file tree.
    variable currentFile
    if {$currentFile eq ""} return

    set norm [file normalize $currentFile]

    # Binding temporaer entfernen (verhindert Endlosschleife)
    bind .left.tree <<TreeviewSelect>> {}
    app::_syncTreeItem {} $norm
    bind .left.tree <<TreeviewSelect>> app::onTreeSelect
}


proc app::_syncTreeItem {parent norm} {
    foreach id [.left.tree children $parent] {
        set vals [.left.tree item $id -values]
        lassign $vals path type

        if {$type eq "file" && [file normalize $path] eq $norm} {
            # Gefunden: selektieren und sichtbar machen
            .left.tree selection set $id
            .left.tree see $id
            # Eltern-Knoten oeffnen
            set p [.left.tree parent $id]
            while {$p ne {}} {
                .left.tree item $p -open 1
                set p [.left.tree parent $p]
            }
            return 1
        }

        # Rekursiv in Kinder suchen
        if {[app::_syncTreeItem $id $norm]} {
            return 1
        }
    }
    return 0
}

