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
    # Programmatische Selektion aus syncTocFromScroll ueberspringen, damit das
    # verzoegerte <<TreeviewSelect>> hier kein gotoAnchor ausloest.
    if {$::app::_suppressTocSelect} {
        set ::app::_suppressTocSelect 0
        return
    }
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
    # Sichtbare Top-Zeile als Index ermitteln.
    # WICHTIG: nicht @0,0 nehmen, sondern @0,5 -- gibt 5 Pixel Toleranz.
    # Sonst wandert die Selektion nach gotoAnchor "nach oben", weil der
    # Anchor-Mark durch Font-Hoehe-Offset oft 1-2 Pixel ueber der ersten
    # sichtbaren Pixelzeile steht und damit als "vorausgehender Abschnitt"
    # gilt.
    if {[catch {set topIdx [$t index "@0,5"]} _]} { return "" }

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
            # Selektion programmatisch setzen. Das <<TreeviewSelect>> wird von
            # Tk verzoegert (queued) geliefert — ein temporaeres bind {}/rebind
            # faengt es NICHT zuverlaessig ab (in 8.6 und 9.0 nachgewiesen).
            # Darum ein Flag, das onTocSelect prueft: sonst wuerde das Event
            # gotoAnchor ausloesen und den Viewer 1-2 Zeilen zurueckscrollen.
            set ::app::_suppressTocSelect 1
            .left.toc selection set $id
            .left.toc see $id
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
    app::applyChromeTheme

    # Update viewer
    mdstack::theme::applyToViewer $::app::viewerPath
    app::applyTip700Styling

    # Seite neu rendern damit alle Tags stimmen
    app::reload

    # Save setting
    app::saveSettings
}

# True if the given #rrggbb colour is dark (low luminance).
proc app::_isDark {hex} {
    if {![regexp {^#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})$} $hex -> r g b]} {
        return 0
    }
    scan $r %x r ; scan $g %x g ; scan $b %x b
    return [expr {(0.299*$r + 0.587*$g + 0.114*$b) < 128}]
}

# Colour the ttk chrome (toolbar, tree, tabs, status, buttons) from the active
# viewer scheme, so the whole window matches the document area instead of the
# flat gray default -- and dark schemes look dark everywhere, not just in the
# viewer. Safe no-op if mdstack::theme isn't available yet.
proc app::applyChromeTheme {} {
    if {[catch {set th [mdstack::theme::theme [mdstack::theme::current]]}]} return
    if {![dict exists $th bg] || ![dict exists $th fg]} return
    set bg [dict get $th bg]
    set fg [dict get $th fg]
    set accent [expr {[dict exists $th link] ? [dict get $th link] : "#3a5a8c"}]
    set dark [app::_isDark $bg]
    set inactive [expr {$dark ? "#3a3a3a" : "#e8e8e8"}]
    set hover    [expr {$dark ? "#454545" : "#f2f2f2"}]
    set disabled [expr {$dark ? "#808080" : "#9a9a9a"}]

    ttk::style configure . -background $bg -foreground $fg -fieldbackground $bg
    ttk::style map . -background [list active $hover] \
                     -foreground [list disabled $disabled]

    ttk::style configure TButton -background $inactive -foreground $fg
    ttk::style map TButton \
        -background [list active $hover pressed $accent] \
        -foreground [list pressed white]

    ttk::style configure Treeview -background $bg -fieldbackground $bg -foreground $fg
    ttk::style map Treeview \
        -background [list selected $accent] -foreground [list selected white]

    ttk::style configure TNotebook -background $bg
    ttk::style configure TNotebook.Tab -background $inactive -foreground $fg
    ttk::style map TNotebook.Tab \
        -background [list selected $bg] -foreground [list selected $fg]

    ttk::style configure TEntry -fieldbackground $bg -foreground $fg
    ttk::style configure TCombobox -fieldbackground $bg -foreground $fg

    ttk::style configure TScrollbar -background $inactive \
        -troughcolor $bg -arrowcolor $fg
    ttk::style map TScrollbar -background [list active $hover]

    # Classic Tk menus don't follow ttk styling. Colour the existing menubar
    # and its cascades directly, and set option-DB defaults (priority 80) so
    # context menus created later (tree/editor popups) inherit the scheme too.
    set mabg $accent
    set mafg "white"
    option add *Menu.background $bg 80
    option add *Menu.foreground $fg 80
    option add *Menu.activeBackground $mabg 80
    option add *Menu.activeForeground $mafg 80
    option add *Menu.selectColor $fg 80
    foreach m [app::_allMenus .] {
        catch {$m configure -background $bg -foreground $fg \
            -activebackground $mabg -activeforeground $mafg \
            -selectcolor $fg -relief flat -borderwidth 0}
    }

    catch {. configure -background $bg}
}

# All classic menu widgets in the tree (menubar cascades + popups).
proc app::_allMenus {{root .}} {
    set out {}
    foreach w [winfo children $root] {
        if {[winfo class $w] eq "Menu"} { lappend out $w }
        lappend out {*}[app::_allMenus $w]
    }
    return $out
}

# ttk base theme: "" / "auto" -> clam on X11, native theme elsewhere.
proc app::_autoUiTheme {} {
    if {[tk windowingsystem] eq "x11"} { return "clam" }
    return [ttk::style theme use]
}
proc app::applyUiTheme {} {
    set name $::app::uiTheme
    set use [expr {($name eq "" || $name eq "auto") ? [app::_autoUiTheme] : $name}]
    if {$use ni [ttk::style theme names]} { set use [app::_autoUiTheme] }
    catch {ttk::style theme use $use}
    app::applyChromeTheme
}
proc app::setUiTheme {name} {
    set ::app::uiTheme $name
    app::applyUiTheme
    catch {app::saveSettings}
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
# Flag: das naechste <<TreeviewSelect>> stammt aus programmatischer Selektion
# (syncTocFromScroll) und darf onTocSelect/gotoAnchor NICHT ausloesen.
set ::app::_suppressTocSelect 0

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

# ============================================================
# Cross-App Kontextmenue (Phase-3)
# ============================================================
#
# Erweitert das bestehende Viewer-Kontextmenue (von mdhelp_clipboard)
# um Cross-App-Eintraege: "Im Glossar nachschlagen" und (sobald
# unterstuetzt) "Im Man-Viewer suchen". Nutzt tcldocs::launcher zur
# App-Suche und zum Starten.
#
# Wird einmalig nach mdhelp_clipboard::setupContextMenu aufgerufen.
# Items sind statisch im Menue; der Such-Term wird zur Klick-Zeit
# dynamisch ueber die aktuelle Selektion oder das Wort unter dem
# Cursor ermittelt.

proc app::extendViewerContextMenu {menuName textWidget} {
    if {![winfo exists $menuName]} return

    $menuName add separator

    # Cross-App: tcldocs::launcher ist Voraussetzung
    if {[catch {package present tcldocs::launcher}]} {
        $menuName add command \
            -label "Cross-App (tcldocs::launcher fehlt)" \
            -state disabled
        return
    }

    # Glossar
    set glossPath [::tools::findApp glossary]
    if {$glossPath ne ""} {
        $menuName add command \
            -label "Im Glossar nachschlagen" \
            -command [list app::_lookupInGlossary $textWidget]
    } else {
        $menuName add command \
            -label "Im Glossar nachschlagen (Glossary nicht gefunden)" \
            -state disabled
    }

    # nroffide / man-viewer (nutzt --search sobald nroffide das hat)
    set nroffPath [::tools::findApp nroffide]
    if {$nroffPath ne ""} {
        $menuName add command \
            -label "Im Man-Viewer suchen" \
            -command [list app::_lookupInManViewer $textWidget]
    }
}

# Term aus Selektion oder Wort am Cursor
proc app::_pickContextTerm {w} {
    # Selektion hat Vorrang
    if {![catch {$w get sel.first sel.last} sel] && [string trim $sel] ne ""} {
        return [string trim $sel]
    }
    # Fallback: Wort am insert-Cursor
    set idx [$w index insert]
    set wStart [$w index "${idx} wordstart"]
    set wEnd   [$w index "${idx} wordend"]
    set word [$w get $wStart $wEnd]
    return [string trim $word]
}

# In Glossar oeffnen
proc app::_lookupInGlossary {textWidget} {
    set term [app::_pickContextTerm $textWidget]
    if {$term eq ""} {
        set ::app::statusText "Glossar: kein Suchterm (markieren oder auf Wort klicken)"
        return
    }
    set glossPath [::tools::findApp glossary]
    if {$glossPath eq ""} {
        tk_messageBox -type ok -icon warning \
            -message "Glossary-App nicht gefunden."
        return
    }
    if {[catch {::tools::launchApp $glossPath --search $term} err]} {
        tk_messageBox -type ok -icon error \
            -message "Konnte Glossary nicht starten: $err"
        return
    }
    set ::app::statusText "Glossar geoeffnet mit: $term"
}

# In Man-Viewer / nroffide oeffnen
proc app::_lookupInManViewer {textWidget} {
    set term [app::_pickContextTerm $textWidget]
    if {$term eq ""} {
        set ::app::statusText "Man-Viewer: kein Suchterm"
        return
    }
    set nroffPath [::tools::findApp nroffide]
    if {$nroffPath eq ""} {
        tk_messageBox -type ok -icon warning \
            -message "Man-Viewer/nroffide nicht gefunden."
        return
    }
    if {[catch {::tools::launchApp $nroffPath --search $term} err]} {
        tk_messageBox -type ok -icon error \
            -message "Konnte Man-Viewer nicht starten: $err"
        return
    }
    set ::app::statusText "Man-Viewer geoeffnet mit: $term"
}
