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
        # Scroll ausgelöst durch gotoAnchor triggert syncTocFromScroll,
        # das anhand der *obersten* sichtbaren Zeile oft noch den
        # vorherigen Abschnitt wählt — Selektion „wandert nach oben“.
        if {$::app::_scrollSyncId ne ""} {
            catch {after cancel $::app::_scrollSyncId}
            set ::app::_scrollSyncId ""
        }
        set ::app::tocSyncSuppressUntil \
            [expr {[clock milliseconds] + $::app::tocSyncSuppressMs}]
        mdstack::viewer::gotoAnchor $::app::viewerPath $anchor
    }
}


# ============================================================
# TOC-Sync beim Scrollen
# ============================================================
# Findet das letzte Heading-Anchor, dessen Position im Text-Widget
# noch oberhalb der aktuell sichtbaren Zeile liegt — und markiert es
# im TOC-Tree.
#
# Wird vom Viewer-yscrollcommand-Wrapper gerufen (siehe buildUI).

proc app::_findCurrentAnchor {} {
    set t [mdstack::viewer::widget $::app::viewerPath]
    # Sichtbare Top-Zeile als Index ermitteln
    if {[catch {set topIdx [$t index "@0,0"]} _]} { return "" }

    # Alle Anchor-Marks einsammeln und nach Position sortieren
    set anchors {}
    foreach m [$t mark names] {
        if {![string match "anchor_*" $m]} continue
        set pos [$t index $m]
        lappend anchors [list $pos [string range $m 7 end]]
    }
    if {[llength $anchors] == 0} { return "" }

    # Sortiere nach Text-Index (lexikografisch geht nicht, brauche
    # Tk-Vergleich)
    set anchors [lsort -command app::_cmpTextIdx -index 0 $anchors]

    # Letzte Marke <= topIdx finden
    set best ""
    foreach pair $anchors {
        lassign $pair pos name
        if {[$t compare $pos <= $topIdx]} {
            set best $name
        } else {
            break
        }
    }
    # Falls nichts vor der sichtbaren Zeile: ersten Anchor
    if {$best eq "" && [llength $anchors] > 0} {
        set best [lindex [lindex $anchors 0] 1]
    }
    return $best
}

proc app::_cmpTextIdx {a b} {
    set t [mdstack::viewer::widget $::app::viewerPath]
    if {[$t compare $a < $b]} { return -1 }
    if {[$t compare $a > $b]} { return 1 }
    return 0
}

proc app::syncTocFromScroll {} {
    # Wird vom yscrollcommand-Wrapper gerufen.
    # Markiert im TOC den naechstgelegenen vorausgehenden Anchor.
    if {![winfo exists .left.toc]} return
    if {[clock milliseconds] < $::app::tocSyncSuppressUntil} {
        return
    }
    set anchor [app::_findCurrentAnchor]
    if {$anchor eq ""} return

    # Item mit passendem -values 0 finden
    foreach id [.left.toc children {}] {
        set vals [.left.toc item $id -values]
        if {[lindex $vals 0] eq $anchor} {
            # nur aktualisieren wenn sich was geaendert hat
            if {[lindex [.left.toc selection] 0] eq $id} return
            # Selektion ohne erneutes Scroll-Event setzen:
            # binding temporaer abklemmen
            bind .left.toc <<TreeviewSelect>> {}
            .left.toc selection set $id
            .left.toc see $id
            bind .left.toc <<TreeviewSelect>> app::onTocSelect
            return
        }
    }
}

# Aktuelle Scroll-Position im scrollPos-Array festhalten,
# wird beim Quit gespeichert.
proc app::trackScrollPos {} {
    if {$::app::currentFile eq ""} return
    catch {
        set t [mdstack::viewer::widget $::app::viewerPath]
        set ::app::scrollPos($::app::currentFile) [lindex [$t yview] 0]
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

    # ── Code-Block Sichtbarkeit verbessern ──
    # Standardfarbe #e8e8e8 ist auf weissem Hintergrund kaum
    # erkennbar. Wir setzen einen klar abgesetzten Hintergrund und
    # geben dem Block eine deutliche linke Einrueckung.
    set codeBg [mdstack::theme::color code_bg]
    set codeFg [mdstack::theme::color fg]
    set codeInlBg [mdstack::theme::color code_inline_bg]
    # Falls Helltheme: stark abgesetztes Grau; Dunkeltheme: belassen
    if {$::app::theme eq "hell"} {
        set codeBg     "#e0e6ed"   ;# leicht blau-grau, klar sichtbar
        set codeInlBg  "#dde4ec"
    }
    catch {
        $t tag configure codeblock \
            -background $codeBg \
            -foreground $codeFg \
            -lmargin1 24 -lmargin2 24 -rmargin 20 \
            -spacing1 4 -spacing3 4 \
            -borderwidth 1 -relief flat
        $t tag configure codeinline \
            -background $codeInlBg \
            -foreground $codeFg \
            -borderwidth 1 -relief flat
    }
    catch {
        $t tag configure codelabel \
            -background [mdstack::theme::color code_label_bg] \
            -foreground [mdstack::theme::color code_label_fg] \
            -lmargin1 24 -lmargin2 24
    }

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

    # Such-Tags wieder nach oben heben (div_* / codeblock haben
    # gerade ggf. ihre Prioritaet erneuert).
    catch { mdhelp_search::raiseTags $t }
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


# ============================================================
# Viewer-Scrollcommand-Wrapper
# ============================================================
# Wird in buildUI als -yscrollcommand des Viewer-Text-Widgets
# eingehaengt. Ruft erst die Original-Scrollbar-Aktualisierung auf
# und triggert dann debounced TOC-Sync sowie Scroll-Position-Update.

set ::app::_scrollSyncId ""

proc app::_viewerOnScroll {origCmd args} {
    # Original (Scrollbar setzen) sofort aufrufen — damit die
    # Scrollbar nicht ruckelt.
    if {$origCmd ne ""} {
        catch { {*}$origCmd {*}$args }
    }
    # Debounced TOC-Sync + Position-Tracking
    if {$::app::_scrollSyncId ne ""} {
        catch {after cancel $::app::_scrollSyncId}
    }
    set ::app::_scrollSyncId [after 150 app::_scrollSyncTick]
}

proc app::_scrollSyncTick {} {
    set ::app::_scrollSyncId ""
    catch { app::syncTocFromScroll }
    catch { app::trackScrollPos }
}
