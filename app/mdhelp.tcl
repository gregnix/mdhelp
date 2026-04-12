#!/usr/bin/env wish
# -*- coding: utf-8 -*-
# mdhelp.tcl — Markdown Help Viewer 0.1
#
# App shell for mdstack 2.0 + mdhelp modules.
#
# Directory structure:
#   mdhelp/
#   +-- app/   
#   +-- lib/tm/                   mdhelp:  search, history, clipboard
#   +-- vendors/tm/            mdstack: mdparser, mdmodel, mdviewer, pdf
#   +-- demo/                  Demos for the modules
#   +-- mdhelp.tcl             this file
#   +-- docs/                  Markdown documentation
#
# Start:
#   wish mdhelp.tcl ?docs-directory?
#   tclsh mdhelp.tcl ?docs-directory?
package require Tk 8.6-

# --- Paths ---
set appDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file join $appDir .. lib tm]
tcl::tm::path add [file join $appDir .. vendors tm]
package require mdparser  0.2
package require mdmodel   0.1
package require mdviewer   0.3
package require mdvalidator 0.1
package require mdeditorkit 0.2
package require mdoutline    0.1
package require mdtheme      0.1
package require mdhtml        0.1
package require mdhelp_search    0.1
package require mdhelp_history   0.1
package require mdhelp_clipboard 0.1
package require mdindexgen       0.1
package require mdtext           0.1
package require mdcontextmenu    0.1

# PDF optional (pdf4tcl not available everywhere)
set ::hasPdf 0
if {![catch {package require mdpdf 0.2}]} {
    set ::hasPdf 1
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
    .menubar.edit add command -label "Next Match" \
        -accelerator "F3" -command app::searchNext
    .menubar.edit add command -label "Previous Match" \
        -accelerator "Shift+F3" -command app::searchPrev
    .menubar.edit add separator
    .menubar.edit add command -label "Copy" \
        -accelerator "Ctrl+C" \
        -command {mdhelp_clipboard::copy [mdviewer::widget [set ::app::viewerPath]]}
    .menubar.edit add command -label "Select All" \
        -accelerator "Ctrl+A" \
        -command {mdhelp_clipboard::selectAll [mdviewer::widget [set ::app::viewerPath]]}
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
    foreach tn [mdtheme::names] {
        set label [dict get [mdtheme::theme $tn] name]
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

    menu .menubar.help -tearoff 0
    .menubar add cascade -label "Help" -menu .menubar.help
    .menubar.help add command -label "Quick Start" \
        -accelerator "F1" -command {app::openHelpPage en/kurzanleitung.md}
    .menubar.help add command -label "Viewer Guide" \
        -command {app::openHelpPage en/bedienung.md}
    .menubar.help add command -label "Editor" \
        -command {app::openHelpPage en/editor.md}
    .menubar.help add command -label "Keyboard Shortcuts" \
        -command {app::openHelpPage en/tastenkuerzel.md}
    .menubar.help add command -label "Markdown Syntax" \
        -command {app::openHelpPage en/markdown-syntax.md}
    .menubar.help add separator
    .menubar.help add command -label "Tips and Tricks" \
        -command {app::openHelpPage en/guides/tipps.md}
    .menubar.help add command -label "PDF Export" \
        -command {app::openHelpPage en/guides/pdf-export.md}
    .menubar.help add command -label "Custom Documentation" \
        -command {app::openHelpPage en/guides/eigene-doku.md}
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

    ttk::label .searchbar.lbl -text "Search:"
    ttk::entry .searchbar.entry -width 25 -textvariable ::app::searchPattern
    ttk::button .searchbar.go -text "Find" -width 7 \
        -command app::doSearch
    ttk::button .searchbar.prev -text "<" -width 2 \
        -command app::searchPrev
    ttk::button .searchbar.next -text ">" -width 2 \
        -command app::searchNext
    ttk::separator .searchbar.sep -orient vertical
    ttk::radiobutton .searchbar.rPage -text "Page" \
        -variable ::app::searchMode -value "page"
    ttk::radiobutton .searchbar.rGlobal -text "All Files" \
        -variable ::app::searchMode -value "global"
    ttk::label .searchbar.status -textvariable ::app::searchStatus \
        -foreground "#666666" -width 20
    ttk::button .searchbar.close -text "X" -width 2 \
        -command app::toggleSearch

    pack .searchbar.lbl .searchbar.entry \
         .searchbar.go .searchbar.prev .searchbar.next \
         .searchbar.sep \
         .searchbar.rPage .searchbar.rGlobal \
         .searchbar.status -side left -padx 2
    pack .searchbar.close -side right -padx 2

    bind .searchbar.entry <Return> app::doSearch
    bind .searchbar.entry <Escape> app::toggleSearch

    # -- PanedWindow --
    ttk::panedwindow .pw -orient horizontal
    pack .pw -fill both -expand 1

    # -- Left side: Tree + TOC --
    ttk::frame .left
    .pw add .left -weight 0

    # File tree
    ttk::labelframe .left.tree_frame -text "Library"
    pack .left.tree_frame -fill both -expand 1 -padx 2 -pady 2

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

    mdviewer::create .right.nb.vtab.viewer \
        -fontsize $::app::fontSize \
        -tablemode frame \
        -onlink app::onLink

    set ::app::viewerPath .right.nb.vtab.viewer

    # onhover is optional (only from mdviewer 0.3+)
    catch {mdviewer::configure $::app::viewerPath -onhover app::onHover}

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

    # Tab change binding
    bind .right.nb <<NotebookTabChanged>> app::onTabChanged

    # -- Status bar --
    ttk::label .status -textvariable ::app::statusText \
        -relief sunken -anchor w -padding {5 2}
    pack .status -fill x -side bottom

    # -- Keyboard Shortcuts --
    bind . <Control-f> app::toggleSearch
    bind . <Control-F> app::toggleSearch
    bind . <Control-o> app::openFolder
    bind . <Control-O> app::openFolder
    bind . <Control-q> {app::quit}
    bind . <Control-Q> {app::quit}
    bind . <Control-d> app::addBookmark
    bind . <Control-D> app::addBookmark
    bind . <Control-e> app::editCurrentFile
    bind . <Control-E> app::editCurrentFile
    bind . <F1>        {app::openHelpPage kurzanleitung.md}
    bind . <F3>        app::searchNext
    bind . <Shift-F3>  app::searchPrev
    bind . <F5>        app::reload
    bind . <Control-plus>  {app::changeFontSize 1}
    bind . <Control-minus> {app::changeFontSize -1}
    bind . <Alt-Left>  app::goBack
    bind . <Alt-Right> app::goForward
    bind . <Alt-Home>  app::goHome

    # History + Clipboard auf Viewer-Widget
    set t [mdviewer::widget $::app::viewerPath]
    mdhelp_history::init $t
    mdhelp_history::setCallback $t {apply {{file anchor} {
        app::openFile $file 0
        if {$anchor ne ""} {
            mdviewer::gotoAnchor $::app::viewerPath $anchor
        } else {
            app::restoreScroll $file
        }
    }}}
    mdhelp_history::setupBindings $t
    mdhelp_clipboard::setupBindings $t
    mdhelp_clipboard::setupContextMenu $t

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
    set version     "0.1"
    set lastchanged "2026-03-04"
    set modules "mdparser 0.2\n  mdmodel 0.1\n  mdviewer 0.3\n\
  mdvalidator 0.1\n  mdeditorkit 0.2\n  mdoutline 0.1\n\
  mdtheme 0.1\n  mdpdf 0.2\n  pdf4tcllib 0.2\n\
  mdhelp_search 0.1\n  mdhelp_history 0.1\n\
  mdhelp_clipboard 0.1\n  mdtext 0.1\n\
  mdcontextmenu 0.1\n  mdindexgen 0.1"
    if {$::app::hasSpellcheck} {
        append modules "\n  mdspellcheck 0.1 ([mdspellcheck::lang])"
    }
    tk_messageBox -icon info -title "About mdhelp 4" \
        -message "mdhelp $version\nStand: $lastchanged\n\nMarkdown Help Viewer\n\nModule:\n  $modules\n\nTcl/Tk [info patchlevel]"
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
        set pages [mdpdf::export $currentAst $outFile \
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

    set baseName [file rootname [file tail $currentFile]]
    set outFile [tk_getSaveFile \
        -title "Save HTML" \
        -defaultextension .html \
        -initialfile "${baseName}.html" \
        -filetypes {{"HTML Files" .html} {"All Files" *}}]

    if {$outFile eq ""} return

    set title $baseName
    if {[dict exists $currentAst meta title]} {
        set title [dict get $currentAst meta title]
    }

    if {[catch {
        mdhtml::export $currentAst $outFile \
            -title $title \
            -toc 1
        set ::app::statusText "HTML exported: $outFile"
    } err]} {
        tk_messageBox -icon error -title "HTML Error" \
            -message "Export failed:\n$err"
    }
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
    set normal [mdvalidator::report $currentAst]
    set strict [mdvalidator::report $currentAst -strict]

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
    app::saveSettings
    exit
}
# ============================================================

# Einstellungen, Lesezeichen, Letzte Ordner (ausgelagert, Prio 12)
source [file join [file dirname [info script]] mdhelp_settings.tcl]

# ============================================================
# Start
# ============================================================

# Load settings (setzt fontSize, docsRoot, geometry, bookmarks)
puts "mdhelp 0.1 startet..."
app::loadSettings

app::buildUI

# Geometry nach buildUI anwenden
app::applyGeometry

# Lesezeichen- und Recent-Menue aktualisieren
app::updateBookmarkMenu
app::updateRecentMenu

# Fenster-Schliessen abfangen
wm protocol . WM_DELETE_WINDOW app::quit

# Fontgroesse aus Einstellungen anwenden
if {$::app::fontSize != 11} {
    mdviewer::setFontSize $::app::viewerPath $::app::fontSize
}

# Apply theme (after GUI build)
if {$::app::theme ne "hell"} {
    mdtheme::applyToViewer $::app::viewerPath
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
