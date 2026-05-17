#!/usr/bin/env wish
# -*- coding: utf-8 -*-
# mdhelp.tcl — Markdown Help Viewer 0.1
#
# App shell for mdstack 2.0 + mdhelp modules.
#
# Directory structure:
#   mdhelp/
#   +-- app/                   this file
#   +-- lib/tm/                mdhelp-eigene Module (mdeditor, mdhelp_pdf, ...)
#   +-- demo/                  Demos for the modules
#   +-- docs/                  Markdown documentation
#
# Externe Module kommen via `package require` aus dem User-tm-Pfad
# (siehe README — typisch ~/.tclshrc mit `::tcl::tm::path add ...`).
# Eigene Module liegen in lib/tm/.
#
# Start:
#   wish mdhelp.tcl ?docs-directory?
#   tclsh mdhelp.tcl ?docs-directory?
package require Tk 8.6-

set appDir [file dirname [file normalize [info script]]]
::tcl::tm::path add [file join $appDir .. lib tm]

package require mdstack::parser     0.2
package require mdstack::model      0.1
package require mdstack::viewer     0.3
package require mdstack::validator  0.1
package require mdstack::editorkit  0.2
package require mdstack::outline    0.1
package require mdstack::theme      0.1
package require mdstack::html       0.1
package require mdstack::pdf        0.2
package require mdstack::text       0.1
package require mdstack::contextmenu 0.1
package require mdhelp_search    0.2
package require mdhelp_history   0.1
package require mdhelp_clipboard 0.1
# mdindexgen ist optional: nur fuer Search-Index. Skip-on-missing,
# damit mdhelp auch ohne dieses Modul startet.
set ::hasIndexgen 0
if {![catch {package require mdindexgen 0.1}]} {
    set ::hasIndexgen 1
}

# PDF optional (pdf4tcl not available everywhere)
set ::hasPdf 0
if {![catch {package require mdhelp_pdf 0.3}]} {
    set ::hasPdf 1
}

# nroff-Reader optional — erlaubt mdhelp das Anzeigen von .n/.1/.3tcl
# Manpages neben Markdown. Liegt im man-viewer-Repo.
set ::hasNroff 0
if {![catch {
    package require nroffparser   0.2
    package require nroffrenderer 0.1
}]} {
    set ::hasNroff 1
}

# ============================================================
# Global State
# ============================================================
namespace eval app {
    variable docsRoot ""       ;# Base directory
    variable currentFile ""    ;# Currently displayed file
    variable currentDoc  ""    ;# Current mdmodel document
    variable currentAst  ""    ;# Current AST
    variable fontSize 11       ;# Current font size
    variable searchVisible 0   ;# Search bar visible?
    variable searchMode "page" ;# "page" or "global"
    variable globalResults {}  ;# Results of global search
    variable scrollPos         ;# array: file -> yview-Position
    array set scrollPos {}
    variable settingsFile [file join [file normalize ~] .mdhelp.rc]
    variable recentDirs {}     ;# Last opened folders (max 10)
    variable hasSpellcheck 0   ;# Spell checking available?
    variable theme "hell"      ;# Active color scheme
    variable viewerPath ""     ;# Path to main viewer widget
    variable notebook ""       ;# ttk::notebook for tabs
    variable editorTabs {}     ;# List of open editor tab IDs
    # Nach Klick im TOC: syncTocFromScroll kurz unterdrücken (sonst
    # überschreibt die Scroll-Sync-Logik die Auswahl mit dem Abschnitt
    # *oberhalb* der sichtbaren Viewport-Zeile).
    variable tocSyncSuppressUntil 0
    # Konfigurierbar via Settings (Key: tocSyncSuppressMs). Werte 0..5000;
    # 0 = Sync nie unterdruecken (alte Verhalten).
    variable tocSyncSuppressMs 500
}

set ::app::metaTitle ""
set ::app::metaSection ""
set ::app::metaVersion ""

# Optional: Spell checking
if {![catch {package require mdspellcheck 0.1}]} {
    set ::app::hasSpellcheck [mdspellcheck::available]
}

# ============================================================
# Build window
# ============================================================
proc app::buildUI {} {
    wm title . "mdhelp 4"
    wm geometry . 1000x700
    wm minsize . 600 400

    # -- Menu bar --
    menu .menubar -tearoff 0
    . configure -menu .menubar

    menu .menubar.file -tearoff 0
    .menubar add cascade -label "File" -menu .menubar.file
    .menubar.file add command -label "Open Folder..." \
        -accelerator "Ctrl+O" -command app::openFolder
    .menubar.file add command -label "Reload" \
        -accelerator "F5" -command app::reload
    .menubar.file add separator
    menu .menubar.file.recent -tearoff 0
    .menubar.file add cascade -label "Recent Folders" \
        -menu .menubar.file.recent
    menu .menubar.file.recentFiles -tearoff 0
    .menubar.file add cascade -label "Recent Files" \
        -menu .menubar.file.recentFiles
    .menubar.file add separator
    .menubar.file add command -label "Generate Index" \
        -command app::generateIndex
    .menubar.file add command -label "Export PDF..." \
        -command app::exportPdf
    .menubar.file add command -label "Export HTML..." \
        -command app::exportHtml
    .menubar.file add separator
    .menubar.file add command -label "Quit" \
        -accelerator "Ctrl+Q" -command app::quit

    menu .menubar.edit -tearoff 0
    .menubar add cascade -label "Edit" -menu .menubar.edit
    .menubar.edit add command -label "Find..." \
        -accelerator "Ctrl+F" -command app::toggleSearch
    .menubar.edit add command -label "Find/Replace..." \
        -accelerator "Ctrl+H" -command app::toggleReplace
    .menubar.edit add command -label "Next Match" \
        -accelerator "F3" -command app::searchNext
    .menubar.edit add command -label "Previous Match" \
        -accelerator "Shift+F3" -command app::searchPrev
    .menubar.edit add separator
    .menubar.edit add command -label "Copy" \
        -accelerator "Ctrl+C" \
        -command {mdhelp_clipboard::copy [mdstack::viewer::widget [set ::app::viewerPath]]}
    .menubar.edit add command -label "Select All" \
        -accelerator "Ctrl+A" \
        -command {mdhelp_clipboard::selectAll [mdstack::viewer::widget [set ::app::viewerPath]]}
    .menubar.edit add separator
    .menubar.edit add command -label "Edit File..." \
        -accelerator "Ctrl+E" \
        -command app::editCurrentFile

    menu .menubar.view -tearoff 0
    .menubar add cascade -label "View" -menu .menubar.view
    .menubar.view add command -label "Font Larger" \
        -accelerator "Ctrl++" -command {app::changeFontSize 1}
    .menubar.view add command -label "Font Smaller" \
        -accelerator "Ctrl+-" -command {app::changeFontSize -1}
    .menubar.view add separator
    .menubar.view add command -label "Back" \
        -accelerator "Alt+Links" -command app::goBack
    .menubar.view add command -label "Forward" \
        -accelerator "Alt+Rechts" -command app::goForward
    .menubar.view add command -label "Home" \
        -accelerator "Alt+Home" -command app::goHome
    .menubar.view add separator

    menu .menubar.view.theme -tearoff 0
    .menubar.view add cascade -label "Color Scheme" \
        -menu .menubar.view.theme
    foreach tn [mdstack::theme::names] {
        set label [dict get [mdstack::theme::theme $tn] name]
        .menubar.view.theme add radiobutton -label $label \
            -variable ::app::theme -value $tn \
            -command [list app::setTheme $tn]
    }

    menu .menubar.bookmarks -tearoff 0
    .menubar add cascade -label "Bookmarks" -menu .menubar.bookmarks
    .menubar.bookmarks add command -label "Add" \
        -accelerator "Ctrl+D" -command app::addBookmark
    .menubar.bookmarks add command -label "Remove" \
        -command app::removeBookmark
    .menubar.bookmarks add separator

    # --- Tools (Cross-app) ---
    menu .menubar.tools -tearoff 0
    .menubar add cascade -label "Tools" -menu .menubar.tools
    # Inhalt wird durch tools_external.tcl gefuellt — kommt nach
    # Source-Block weiter unten.

    menu .menubar.help -tearoff 0
    .menubar add cascade -label "Help" -menu .menubar.help
    .menubar.help add command -label "Quick Start" \
        -accelerator "F1" -command {app::openHelpPage en/quickstart.md}
    .menubar.help add command -label "Viewer Guide" \
        -command {app::openHelpPage en/viewer.md}
    .menubar.help add command -label "Editor" \
        -command {app::openHelpPage en/editor.md}
    .menubar.help add command -label "Keyboard Shortcuts" \
        -command {app::openHelpPage en/shortcuts.md}
    .menubar.help add command -label "Markdown Syntax" \
        -command {app::openHelpPage en/markdown-syntax.md}
    .menubar.help add separator
    .menubar.help add command -label "Tips and Tricks" \
        -command {app::openHelpPage en/guides/tips.md}
    .menubar.help add command -label "PDF Export" \
        -command {app::openHelpPage en/guides/pdf-export.md}
    .menubar.help add command -label "Custom Documentation" \
        -command {app::openHelpPage en/guides/own-docs.md}
    .menubar.help add separator
    .menubar.help add command -label "Validate AST" \
        -command app::validateAst
    .menubar.help add command -label "About mdhelp 4" \
        -command app::showAbout

    # -- Toolbar --
    ttk::frame .toolbar
    pack .toolbar -fill x -padx 2 -pady 2

    ttk::button .toolbar.back -text "<- Back" -width 10 \
        -command app::goBack
    ttk::button .toolbar.fwd  -text "Forward ->" -width 8 \
        -command app::goForward
    ttk::button .toolbar.home -text "Start" -width 6 \
        -command app::goHome
    ttk::separator .toolbar.s0 -orient vertical
    ttk::button .toolbar.open -text "Open" -width 8 \
        -command app::openFolder
    ttk::separator .toolbar.s1 -orient vertical
    ttk::button .toolbar.search -text "Find" -width 7 \
        -command app::toggleSearch
    ttk::separator .toolbar.s2 -orient vertical
    ttk::button .toolbar.smaller -text "A-" -width 3 \
        -command {app::changeFontSize -1}
    ttk::button .toolbar.bigger  -text "A+" -width 3 \
        -command {app::changeFontSize 1}
    ttk::separator .toolbar.s3 -orient vertical
    ttk::button .toolbar.edit -text "Edit" -width 10 \
        -command app::editCurrentFile
    ttk::button .toolbar.pdf -text "PDF" -width 5 \
        -command app::exportPdf

    pack .toolbar.back .toolbar.fwd .toolbar.home \
         .toolbar.s0 .toolbar.open \
         .toolbar.s1 .toolbar.search \
         .toolbar.s2 .toolbar.smaller .toolbar.bigger \
         .toolbar.s3 .toolbar.edit .toolbar.pdf \
         -side left -padx 2

    # Breadcrumb right
    ttk::label .toolbar.crumb -textvariable ::app::breadcrumb \
        -foreground "#555555"
    pack .toolbar.crumb -side right -padx 5

    # -- Search bar (initially hidden) --
    ttk::frame .searchbar
    # pack is done only at toggleSearch

    # --- Erste Zeile: Suche ---
    ttk::frame .searchbar.f
    pack .searchbar.f -fill x

    ttk::label .searchbar.f.lbl -text "Search:"
    ttk::combobox .searchbar.f.entry -width 25 \
        -textvariable ::app::searchPattern \
        -values $::app::searchHistory
    ttk::button .searchbar.f.go -text "Find" -width 6 \
        -command app::doSearch
    ttk::button .searchbar.f.prev -text "<" -width 2 \
        -command app::searchPrev
    ttk::button .searchbar.f.next -text ">" -width 2 \
        -command app::searchNext
    ttk::separator .searchbar.f.sep1 -orient vertical
    ttk::checkbutton .searchbar.f.cCase  -text "Aa"   \
        -variable ::app::searchCase
    ttk::checkbutton .searchbar.f.cWord  -text "W"    \
        -variable ::app::searchWord
    ttk::checkbutton .searchbar.f.cRegex -text ".*"   \
        -variable ::app::searchRegex
    ttk::separator .searchbar.f.sep2 -orient vertical
    ttk::radiobutton .searchbar.f.rPage   -text "Page" \
        -variable ::app::searchMode -value "page"
    ttk::radiobutton .searchbar.f.rGlobal -text "All Files" \
        -variable ::app::searchMode -value "global"
    ttk::separator .searchbar.f.sep3 -orient vertical
    ttk::button .searchbar.btnReplace -text "Replace +" -width 11 \
        -command app::toggleReplace
    ttk::label .searchbar.f.status \
        -textvariable ::app::searchStatus \
        -foreground "#666666" -width 28
    ttk::button .searchbar.f.close -text "X" -width 2 \
        -command app::toggleSearch

    pack .searchbar.f.lbl .searchbar.f.entry \
         .searchbar.f.go .searchbar.f.prev .searchbar.f.next \
         .searchbar.f.sep1 \
         .searchbar.f.cCase .searchbar.f.cWord .searchbar.f.cRegex \
         .searchbar.f.sep2 \
         .searchbar.f.rPage .searchbar.f.rGlobal \
         .searchbar.f.sep3 \
         .searchbar.btnReplace \
         .searchbar.f.status -side left -padx 2
    pack .searchbar.f.close -side right -padx 2

    # --- Zweite Zeile: Replace (anfangs versteckt) ---
    ttk::frame .searchbar.r

    ttk::label .searchbar.r.lbl -text "Replace:"
    ttk::combobox .searchbar.r.entry -width 25 \
        -textvariable ::app::replacePattern \
        -values $::app::replaceHistory
    ttk::button .searchbar.r.do -text "Replace" -width 8 \
        -command app::doReplace
    ttk::button .searchbar.r.donext -text "Replace + Next" -width 14 \
        -command app::doReplaceNext
    ttk::button .searchbar.r.all -text "Replace All" -width 12 \
        -command app::doReplaceAll
    ttk::label .searchbar.r.hint \
        -text "(Replace nur im Editor-Tab)" -foreground "#888888"

    pack .searchbar.r.lbl .searchbar.r.entry \
         .searchbar.r.do .searchbar.r.donext .searchbar.r.all \
         .searchbar.r.hint -side left -padx 2

    bind .searchbar.f.entry <Return> app::doSearch
    bind .searchbar.f.entry <Escape> app::toggleSearch
    bind .searchbar.r.entry <Return> app::doReplace
    bind .searchbar.r.entry <Escape> app::toggleSearch

    # -- PanedWindow --
    ttk::panedwindow .pw -orient horizontal
    pack .pw -fill both -expand 1

    # -- Left side: Tree + TOC --
    ttk::frame .left
    .pw add .left -weight 0

    # File tree
    ttk::labelframe .left.tree_frame -text "Library"
    pack .left.tree_frame -fill both -expand 1 -padx 2 -pady 2

    # Filter-Eingabe
    ttk::frame .left.tree_filt
    pack .left.tree_filt -in .left.tree_frame -side top -fill x \
        -padx 2 -pady {2 2}
    ttk::label .left.tree_filt.l -text "Filter:"
    ttk::entry .left.tree_filt.e -textvariable ::app::treeFilter
    ttk::button .left.tree_filt.x -text "X" -width 2 \
        -command { set ::app::treeFilter "" }
    pack .left.tree_filt.l -side left -padx {2 2}
    pack .left.tree_filt.x -side right -padx {2 2}
    pack .left.tree_filt.e -side left -fill x -expand 1

    ttk::treeview .left.tree -show tree -selectmode browse \
        -yscrollcommand {.left.tree_sb set}
    ttk::scrollbar .left.tree_sb -orient vertical \
        -command {.left.tree yview}
    pack .left.tree_sb -in .left.tree_frame -side right -fill y
    pack .left.tree -in .left.tree_frame -fill both -expand 1

    bind .left.tree <<TreeviewSelect>> app::onTreeSelect
    bind .left.tree <Button-3> {app::treeContextMenu %x %y %X %Y}

    # TOC (Inhaltsverzeichnis)
    ttk::labelframe .left.toc_frame -text "Contents"
    pack .left.toc_frame -fill both -expand 1 -padx 2 -pady 2

    ttk::treeview .left.toc -show tree -selectmode browse \
        -yscrollcommand {.left.toc_sb set}
    ttk::scrollbar .left.toc_sb -orient vertical \
        -command {.left.toc yview}
    pack .left.toc_sb -in .left.toc_frame -side right -fill y
    pack .left.toc -in .left.toc_frame -fill both -expand 1

    bind .left.toc <<TreeviewSelect>> app::onTocSelect

    # Suchergebnisse (anfangs versteckt)
    ttk::labelframe .left.results_frame -text "Search Results"
    # pack wird bei globaler Suche aktiviert

    ttk::treeview .left.results -show tree -selectmode browse \
        -yscrollcommand {.left.results_sb set}
    ttk::scrollbar .left.results_sb -orient vertical \
        -command {.left.results yview}
    pack .left.results_sb -in .left.results_frame -side right -fill y
    pack .left.results -in .left.results_frame -fill both -expand 1

    bind .left.results <<TreeviewSelect>> app::onResultSelect

    # -- Right side: Notebook with tabs --
    ttk::frame .right
    .pw add .right -weight 1

    set ::app::notebook [ttk::notebook .right.nb]
    pack .right.nb -fill both -expand 1

    # First tab: Viewer
    ttk::frame .right.nb.vtab
    .right.nb add .right.nb.vtab -text "View"

    mdstack::viewer::create .right.nb.vtab.viewer \
        -fontsize $::app::fontSize \
        -tablemode frame \
        -onlink app::onLink

    set ::app::viewerPath .right.nb.vtab.viewer

    # onhover is optional (only from mdviewer 0.3+)
    catch {mdstack::viewer::configure $::app::viewerPath -onhover app::onHover}

    # Frontmatter panel (Priority 11)
    ttk::frame .right.nb.vtab.meta
    ttk::label .right.nb.vtab.meta.icon -text "\u2139" -width 2 \
        -font [list TkDefaultFont 10 bold] -foreground "#336699"
    ttk::label .right.nb.vtab.meta.title -textvariable ::app::metaTitle \
        -font [list TkDefaultFont 10 bold]
    ttk::label .right.nb.vtab.meta.section -textvariable ::app::metaSection \
        -foreground "#666666"
    ttk::label .right.nb.vtab.meta.version -textvariable ::app::metaVersion \
        -foreground "#999999"
    pack .right.nb.vtab.meta.icon -side left -padx {4 0}
    pack .right.nb.vtab.meta.title -side left -padx {4 0}
    pack .right.nb.vtab.meta.section -side left -padx {8 0}
    pack .right.nb.vtab.meta.version -side left -padx {8 0}
    # Panel only visible when frontmatter present

    pack .right.nb.vtab.viewer -fill both -expand 1

    # Viewer-Scrollcommand wrappen: zusaetzlich zur Scrollbar
    # auch TOC-Sync und Scrollpos-Tracking ausloesen.
    set _vt [mdstack::viewer::widget $::app::viewerPath]
    set _origSb [$_vt cget -yscrollcommand]
    $_vt configure -yscrollcommand [list app::_viewerOnScroll $_origSb]
    unset _vt _origSb

    # Tab change binding
    bind .right.nb <<NotebookTabChanged>> app::onTabChanged

    # Tab schliessen via Mittelklick (nur Editor-Tabs)
    bind .right.nb <Button-2> { app::tabCloseAt %x %y }
    # Ctrl+W = aktuellen Editor-Tab schliessen
    bind . <Control-w> app::closeCurrentTab
    bind . <Control-W> app::closeCurrentTab

    # -- Status bar --
    ttk::label .status -textvariable ::app::statusText \
        -relief sunken -anchor w -padding {5 2}
    pack .status -fill x -side bottom

    # -- Keyboard Shortcuts --
    bind . <Control-f> app::toggleSearch
    bind . <Control-F> app::toggleSearch
    bind . <Control-h> app::toggleReplace
    bind . <Control-H> app::toggleReplace
    bind . <Control-o> app::openFolder
    bind . <Control-O> app::openFolder
    bind . <Control-q> {app::quit}
    bind . <Control-Q> {app::quit}
    bind . <Control-d> app::addBookmark
    bind . <Control-D> app::addBookmark
    bind . <Control-e> app::editCurrentFile
    bind . <Control-E> app::editCurrentFile
    bind . <F1>        {app::openHelpPage en/quickstart.md}
    bind . <F3>        app::searchNext
    bind . <Shift-F3>  app::searchPrev
    bind . <F5>        app::reload
    bind . <Control-plus>  {app::changeFontSize 1}
    bind . <Control-minus> {app::changeFontSize -1}
    bind . <Alt-Left>  app::goBack
    bind . <Alt-Right> app::goForward
    bind . <Alt-Home>  app::goHome

    # History + Clipboard auf Viewer-Widget
    set t [mdstack::viewer::widget $::app::viewerPath]
    mdhelp_history::init $t
    mdhelp_history::setCallback $t {apply {{file anchor} {
        app::openFile $file 0
        if {$anchor ne ""} {
            mdstack::viewer::gotoAnchor $::app::viewerPath $anchor
        } else {
            app::restoreScroll $file
        }
    }}}
    mdhelp_history::setupBindings $t
    mdhelp_clipboard::setupBindings $t
    mdhelp_clipboard::setupContextMenu $t

    # Cross-App-Items ans Kontextmenue anhaengen (Phase-3).
    # Erlaubt "Im Glossar nachschlagen" etc. via tcldocs::launcher.
    app::extendViewerContextMenu ${t}_ctx $t

    # Disable PDF button if not available
    if {!$::hasPdf} {
        .toolbar.pdf state disabled
    }
}
proc app::editCurrentFile {} {
    variable currentFile
    if {$currentFile eq "" || ![file exists $currentFile]} {
        set ::app::statusText "No file to edit"
        return
    }
    app::openInEditor $currentFile
}

# Editor integration (extracted, Priority 12)
source [file join [file dirname [info script]] mdhelp_editor.tcl]

# Navigation and file operations (extracted, Priority 12)
source [file join [file dirname [info script]] mdhelp_nav.tcl]

# UI updates and display (extracted, Priority 12)
source [file join [file dirname [info script]] mdhelp_ui.tcl]

# ============================================================
# About dialog
# ============================================================
proc app::showAbout {} {
    set version     "0.2"
    set lastchanged "2026-05-06"

    # ============================================================
    # Stack-Komponenten erkennen: Adapter vs. Legacy
    # ============================================================

    # mdpdf: Adapter wenn _mapOptions vorhanden, Legacy wenn _renderBlock vorhanden
    if {[info commands ::mdstack::pdf::_mapOptions] ne ""} {
        set mdpdfStatus "0.2 (Adapter -> docir-pdf)"
    } elseif {[info commands ::mdstack::pdf::_renderBlock] ne ""} {
        set mdpdfStatus "0.2 (Legacy, Standalone)"
    } else {
        set mdpdfStatus "0.2 (unbekannt)"
    }

    # mdhtml: Adapter wenn die DocIR-Pipeline genutzt wird
    if {[info commands ::mdstack::html::_collectImageUrls] ne ""} {
        set mdhtmlStatus "0.1 (Adapter -> docir-html, Asset-Copy)"
    } elseif {[info commands ::mdstack::html::escapeHtml] ne ""} {
        set mdhtmlStatus "0.1 (geladen)"
    } else {
        set mdhtmlStatus "0.1 (unbekannt)"
    }

    # docir-Pipeline: prüfe die einzelnen Pakete (docir-pdf, docir-html, etc.)
    set docirParts {}
    foreach {pkg label} {
        docir-md-source "md-source"
        docir-pdf       "pdf"
        docir-html      "html"
    } {
        if {![catch {set v [package present $pkg]}]} {
            lappend docirParts "$label $v"
        }
    }
    if {[llength $docirParts] > 0} {
        set docirInfo [join $docirParts ", "]
    } else {
        set docirInfo "nicht geladen"
    }

    # pdf4tcl-Stack: aktiv probieren (lazy-loaded vom mdpdf-Adapter erst
    # beim ersten Export, daher hier vorab triggern)
    set pdf4tclVer "nicht installiert"
    if {![catch {package require pdf4tcl} v]} {
        set pdf4tclVer $v
    }
    set pdf4tcllibVer "nicht installiert"
    if {![catch {package require pdf4tcllib} v]} {
        set pdf4tcllibVer $v
    }

    # ============================================================
    # Modul-Liste (kompakt)
    # ============================================================
    set modules "  mdparser 0.2,  mdmodel 0.1,  mdviewer 0.3\n"
    append modules "  mdvalidator 0.1,  mdeditorkit 0.2,  mdoutline 0.1\n"
    append modules "  mdtheme 0.1,  mdtext 0.1,  mdcontextmenu 0.1\n"
    append modules "  mdindexgen 0.1\n"
    append modules "  mdhelp_search 0.1,  mdhelp_history 0.1,  mdhelp_clipboard 0.1"
    if {$::app::hasSpellcheck} {
        append modules "\n  mdspellcheck 0.1 ([mdspellcheck::lang])"
    }

    # ============================================================
    # Dialog
    # ============================================================
    set msg "mdhelp $version  (Stand: $lastchanged)\n"
    append msg "Markdown Help Viewer\n"
    append msg "\n"
    append msg "=== Stack-Komponenten ===\n"
    append msg "mdpdf:   $mdpdfStatus\n"
    append msg "mdhtml:  $mdhtmlStatus\n"
    append msg "docir:   $docirInfo\n"
    append msg "\n"
    append msg "=== Backend ===\n"
    append msg "pdf4tcl:    $pdf4tclVer\n"
    append msg "pdf4tcllib: $pdf4tcllibVer\n"
    append msg "Tcl/Tk:     [info patchlevel]\n"
    append msg "\n"
    append msg "=== Module ===\n"
    append msg "$modules"

    tk_messageBox -icon info -title "About mdhelp 4" -message $msg
}

proc app::openHelpPage {page} {
    # Oeffnet eine Hilfe-Seite aus dem eingebauten docs/-Verzeichnis.
    # Falls gerade ein anderer Ordner geladen ist, wird temporaer
    # auf das Hilfe-Verzeichnis umgeschaltet.
    variable docsRoot

    set helpDir [file join $::appDir docs]
    set helpFile [file join $helpDir $page]

    if {![file exists $helpFile]} {
        set ::app::statusText "Help page not found: $page"
        return
    }

    # Falls anderer Ordner geladen: umschalten auf Hilfe
    if {[file normalize $docsRoot] ne [file normalize $helpDir]} {
        app::loadTree $helpDir
    }

    app::openFile $helpFile 1
}

# ============================================================

# Such-UI (ausgelagert, Prio 12)
source [file join [file dirname [info script]] mdhelp_search_ui.tcl]
# ============================================================
# Generate index
# ============================================================
proc app::generateIndex {} {
    variable docsRoot

    if {$docsRoot eq ""} {
        tk_messageBox -icon warning -title "Index" \
            -message "No document directory loaded."
        return
    }

    if {!$::hasIndexgen} {
        tk_messageBox -icon info -title "Index" \
            -message "mdindexgen package not installed.\nIndex generation unavailable."
        return
    }

    if {[catch {
        mdindexgen::scan $docsRoot
    } err]} {
        tk_messageBox -icon error -title "Index Error" \
            -message "Index generation failed:\n$err"
        return
    }

    # Baum neu laden
    app::loadTree $docsRoot
    app::goHome

    set ::app::statusText "Index generated for: $docsRoot"
}

# ============================================================
# PDF Export
# ============================================================
proc app::exportPdf {} {
    variable currentFile
    variable currentAst

    if {!$::hasPdf} {
        tk_messageBox -icon warning -title "PDF" \
            -message "pdf4tcl ist nicht installiert."
        return
    }

    if {$currentFile eq "" || $currentAst eq ""} return

    set baseName [file rootname [file tail $currentFile]]
    set outFile [tk_getSaveFile \
        -title "Save PDF" \
        -defaultextension .pdf \
        -initialfile "${baseName}.pdf" \
        -filetypes {{"PDF Files" .pdf} {"All Files" *}}]

    if {$outFile eq ""} return

    # Titel aus YAML-Meta oder Dateiname
    set title $baseName
    if {[dict exists $currentAst meta title]} {
        set title [dict get $currentAst meta title]
    }

    if {[catch {
        set pages [mdstack::pdf::export $currentAst $outFile \
            -title $title \
            -fontsize $::app::fontSize \
            -root [file dirname $currentFile]]
        set ::app::statusText "PDF exported: $outFile ($pages pages)"
    } err]} {
        tk_messageBox -icon error -title "PDF Error" \
            -message "Export failed:\n$err"
    }
}
proc app::exportHtml {} {
    variable currentFile
    variable currentAst

    if {$currentFile eq "" || $currentAst eq ""} return

    # 1. Style-Auswahl
    set styleResult [app::_chooseHtmlStyle]
    if {$styleResult eq ""} return  ;# abgebrochen
    lassign $styleResult styleLabel cssPath

    # 2. Speicherort
    set baseName [file rootname [file tail $currentFile]]
    set outFile [tk_getSaveFile \
        -title "Save HTML ($styleLabel)" \
        -defaultextension .html \
        -initialfile "${baseName}.html" \
        -filetypes {{"HTML Files" .html} {"All Files" *}}]

    if {$outFile eq ""} return

    set title $baseName
    if {[dict exists $currentAst meta title]} {
        set title [dict get $currentAst meta title]
    }

    # 3. Export mit optionalem CSS und Math/Mermaid-Rendering
    set exportArgs [list \
        -title $title \
        -toc 1 \
        -root [file dirname $currentFile]]
    if {$cssPath ne ""} {
        lappend exportArgs -css $cssPath
    }
    # Math/Mermaid: aus dem Stylesheet-Dialog uebernommen.
    # Default ist an (Checkboxen waren angekreuzt). Wenn nicht
    # gesetzt: konservativ aus.
    set enableMath    [expr {[info exists ::_html_enable_math]    ? $::_html_enable_math    : 0}]
    set enableMermaid [expr {[info exists ::_html_enable_mermaid] ? $::_html_enable_mermaid : 0}]
    lappend exportArgs -enableMath    $enableMath
    lappend exportArgs -enableMermaid $enableMermaid

    if {[catch {
        mdstack::html::export $currentAst $outFile {*}$exportArgs
        set ::app::statusText "HTML exported: $outFile (style: $styleLabel)"
    } err]} {
        tk_messageBox -icon error -title "HTML Error" \
            -message "Export failed:\n$err"
    }
}

# ============================================================
# HTML-Style-Auswahl-Dialog
# ============================================================
# Liefert Liste {label cssPath} oder "" wenn abgebrochen.
# cssPath ist der absolute Pfad zur CSS-Datei oder "" fuer Default.
proc app::_chooseHtmlStyle {} {
    set ::_html_style_choice ""
    # Starpack: styles/ direkt unter appDir (VFS-Root).
    # Dev-Modus: styles/ ein Level über app/ (..)
    if {[file isdirectory [file join $::appDir styles]]} {
        set styleDir [file join $::appDir styles]
    } else {
        set styleDir [file join $::appDir .. styles]
    }

    # Verfuegbare Styles (Auto-Discovery + bekannte Namen)
    set styles [dict create]
    dict set styles "Default (mdstack)"        ""
    if {[file exists [file join $styleDir sticky-top.css]]} {
        dict set styles "Sticky Top (TOC scrollt mit)" \
            [file normalize [file join $styleDir sticky-top.css]]
    }
    if {[file exists [file join $styleDir sidebar.css]]} {
        dict set styles "Sidebar (TOC links, Body rechts)" \
            [file normalize [file join $styleDir sidebar.css]]
    }
    if {[file exists [file join $styleDir collapsible.css]]} {
        dict set styles "Collapsible (TOC zugeklappt)" \
            [file normalize [file join $styleDir collapsible.css]]
    }
    # Weitere CSS-Dateien im styles/-Ordner automatisch hinzufuegen
    if {[file isdirectory $styleDir]} {
        foreach f [glob -nocomplain -directory $styleDir *.css] {
            set base [file rootname [file tail $f]]
            if {$base ni {sticky-top sidebar collapsible}} {
                dict set styles "Custom: $base" [file normalize $f]
            }
        }
    }
    dict set styles "Custom file..." "__BROWSE__"

    set labels [dict keys $styles]
    set ::_html_style_label [lindex $labels 0]

    # Dialog
    toplevel .htmlstyle
    wm title .htmlstyle "HTML-Style waehlen"
    wm transient .htmlstyle .
    wm resizable .htmlstyle 0 0

    ttk::frame .htmlstyle.f -padding 12
    pack .htmlstyle.f -fill both -expand 1

    ttk::label .htmlstyle.f.lbl -text "Layout fuer das HTML-Inhaltsverzeichnis:" \
        -font {TkDefaultFont 10 bold}
    pack .htmlstyle.f.lbl -anchor w -pady {0 6}

    ttk::combobox .htmlstyle.f.cmb -textvariable ::_html_style_label \
        -values $labels -state readonly -width 42
    pack .htmlstyle.f.cmb -fill x -pady {0 4}

    ttk::label .htmlstyle.f.hint -text "Tip: weitere CSS-Dateien in styles/ werden automatisch erkannt." \
        -foreground "#666" -font {TkDefaultFont 8}
    pack .htmlstyle.f.hint -anchor w -pady {0 12}

    # Math + Mermaid Checkboxen (KaTeX/Mermaid CDN-Scripts einbinden).
    # Default an, weil Render-Markup im Body sowieso erzeugt wird;
    # ohne JS bleiben Math/Mermaid einfach Plain-Text statt grafisch.
    ttk::labelframe .htmlstyle.f.render -text "Inhalts-Rendering" \
        -padding 6
    pack .htmlstyle.f.render -fill x -pady {0 12}

    set ::_html_enable_math 1
    set ::_html_enable_mermaid 1

    ttk::checkbutton .htmlstyle.f.render.math \
        -text "Math-Formeln mit KaTeX rendern (\$E=mc^2\$, \$\$...\$\$)" \
        -variable ::_html_enable_math
    pack .htmlstyle.f.render.math -anchor w

    ttk::checkbutton .htmlstyle.f.render.mermaid \
        -text "Mermaid-Diagramme rendern (\`\`\`mermaid Bloecke)" \
        -variable ::_html_enable_mermaid
    pack .htmlstyle.f.render.mermaid -anchor w

    ttk::label .htmlstyle.f.render.hint \
        -text "Hinweis: Browser laedt KaTeX/Mermaid von CDN (Internet noetig)." \
        -foreground "#666" -font {TkDefaultFont 8}
    pack .htmlstyle.f.render.hint -anchor w -pady {4 0}

    ttk::frame .htmlstyle.f.btns
    pack .htmlstyle.f.btns -fill x

    ttk::button .htmlstyle.f.btns.ok -text "Weiter" -command {
        set ::_html_style_choice $::_html_style_label
        destroy .htmlstyle
    }
    ttk::button .htmlstyle.f.btns.cancel -text "Abbrechen" -command {
        set ::_html_style_choice ""
        destroy .htmlstyle
    }
    pack .htmlstyle.f.btns.cancel -side right -padx {4 0}
    pack .htmlstyle.f.btns.ok -side right

    bind .htmlstyle <Return> {
        set ::_html_style_choice $::_html_style_label
        destroy .htmlstyle
    }
    bind .htmlstyle <Escape> {
        set ::_html_style_choice ""
        destroy .htmlstyle
    }

    grab .htmlstyle
    tkwait window .htmlstyle

    if {$::_html_style_choice eq ""} {
        return ""
    }

    set cssPath [dict get $styles $::_html_style_choice]

    # Custom file: File-Dialog
    if {$cssPath eq "__BROWSE__"} {
        set cssPath [tk_getOpenFile \
            -title "CSS-Datei waehlen" \
            -filetypes {{"CSS" .css} {"All Files" *}}]
        if {$cssPath eq ""} return ""
    }

    return [list $::_html_style_choice $cssPath]
}

# ============================================================
# AST validation (Debug)
# ============================================================
proc app::validateAst {} {
    variable currentAst
    if {$currentAst eq ""} {
        tk_messageBox -icon info -message "No document loaded."
        return
    }
    set normal [mdstack::validator::report $currentAst]
    set strict [mdstack::validator::report $currentAst -strict]

    set meta [dict get $currentAst meta]
    set nBlocks [llength [dict get $currentAst blocks]]
    set nRefs [dict size [dict get $currentAst reflinks]]

    set msg "Bloecke: $nBlocks\nReflinks: $nRefs\n"
    if {[dict size $meta] > 0} {
        append msg "Meta-Keys: [dict keys $meta]\n"
    }
    append msg "\nNormal: $normal\nStrict: $strict"

    tk_messageBox -icon info -title "AST Validation" -message $msg
}

proc app::quit {} {
    # Ungespeicherte Editor-Tabs pruefen
    variable editorTabs
    foreach w $editorTabs {
        if {[info exists ::app::edDirty($w)] && $::app::edDirty($w)} {
            set file ""
            if {[info exists ::app::edFile($w)]} {
                set file $::app::edFile($w)
            }
            set answer [tk_messageBox -icon question \
                -title "Unsaved Changes" \
                -type yesnocancel \
                -message "Save changes to [file tail $file]?"]
            switch -- $answer {
                yes    { app::editorSave $w $file }
                cancel { return }
            }
        }
    }

    # Aktuelle Scroll-Position vor dem Speichern festhalten
    if {$::app::currentFile ne ""} {
        catch {
            set t [mdstack::viewer::widget $::app::viewerPath]
            set ::app::scrollPos($::app::currentFile) [lindex [$t yview] 0]
        }
    }

    # Auto-Save-Files entfernen (wir beenden sauber)
    catch { app::autoSaveCleanup }

    app::saveSettings
    exit
}
# ============================================================

# Einstellungen, Lesezeichen, Letzte Ordner (ausgelagert, Prio 12)
# Shared-Config (~/.tcldocs.rc) -- vor Settings damit loadSettings darauf
# zugreifen kann. Seit 2026-05-13 als externes Modul tcldocs::config
# (Repo tcldocs-config). Identische API wie das frueher inline
# gesourcete app/shared_config.tcl.
package require tcldocs::config

source [file join [file dirname [info script]] mdhelp_settings.tcl]

# Cross-app Tools-Menue -- seit 2026-05-13 als externes Modul
# tcldocs::launcher (Repo tcldocs-launcher). Identische API
# (::tools::findApp etc.).
package require tcldocs::launcher

# DeepL-Übersetzungs-Helper (optional)
source [file join [file dirname [info script]] deepl_helper.tcl]

# Side-by-Side Viewer (Original ↔ Übersetzung)
source [file join [file dirname [info script]] sidebyside.tcl]

# ============================================================
# Start
# ============================================================

# Load settings (setzt fontSize, docsRoot, geometry, bookmarks)
puts "mdhelp 0.1 startet..."
app::loadSettings

app::buildUI

# Tools-Menue jetzt fuellen (nach buildUI, weil .menubar.tools dann existiert)
::tools::buildToolsMenu "mdhelp" .menubar.tools \
    {expr {$::app::currentFile}} \
    {expr {$::app::docsRoot}}

# DeepL-Eintrag ans Tools-Menue anhaengen
.menubar.tools add separator
.menubar.tools add command \
    -label "Translate selection (DeepL)" \
    -command { app::deeplTranslateActive }
.menubar.tools add command \
    -label "Configure DeepL API key..." \
    -command ::deepl::configureKey

# Side-by-Side: Original + Übersetzung nebeneinander
.menubar.tools add separator
.menubar.tools add command \
    -label "Open original side-by-side" \
    -accelerator "F11" \
    -command { ::sbs::open $::app::currentFile }
bind . <F11> { ::sbs::open $::app::currentFile }

proc app::deeplTranslateActive {} {
    # Welches Widget ist aktiv? Editor, falls offen, sonst Viewer.
    set t ""
    set selected [.right.nb select]
    if {$selected eq ".right.nb.vtab"} {
        set t [mdstack::viewer::widget $::app::viewerPath]
    } elseif {[info exists ::app::edText($selected)]} {
        set t $::app::edText($selected)
    }
    if {$t eq "" || ![winfo exists $t]} {
        tk_messageBox -icon info -title "DeepL" \
            -message "Kein aktives Text-Widget."
        return
    }
    ::deepl::translateSelection $t
}

# Geometry nach buildUI anwenden
app::applyGeometry

# Lesezeichen- und Recent-Menue aktualisieren
app::updateBookmarkMenu
app::updateRecentMenu
app::updateRecentFilesMenu

# Fenster-Schliessen abfangen
wm protocol . WM_DELETE_WINDOW app::quit

# Fontgroesse aus Einstellungen anwenden
if {$::app::fontSize != 11} {
    mdstack::viewer::setFontSize $::app::viewerPath $::app::fontSize
}

# Apply theme (after GUI build)
if {$::app::theme ne "hell"} {
    mdstack::theme::applyToViewer $::app::viewerPath
}

# Docs directory: command line > settings > default
set openFile ""
if {$argc > 0} {
    set arg [lindex $argv 0]
    if {[file isfile $arg]} {
        # Single file: directory as tree, open file directly
        set docsDir [file dirname $arg]
        set openFile $arg
    } else {
        set docsDir $arg
    }
} elseif {$::app::docsRoot ne "" && [file isdirectory $::app::docsRoot]} {
    set docsDir $::app::docsRoot
} else {
    set docsDir [file join $appDir .. docs]
}

if {[file isdirectory $docsDir]} {
    app::loadTree $docsDir
    if {$openFile ne ""} {
        app::openFile $openFile 1
    } else {
        app::goHome
    }
} else {
    set ::app::statusText "No docs directory found: $docsDir"
}
