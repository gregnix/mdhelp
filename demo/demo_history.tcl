#!/usr/bin/env wish
# demo_history.tcl — Demo for mdhelp_history-0.1.tm
#
# Simulates browser navigation between documents.
# Start: wish demo_history.tcl

package require Tk

set scriptDir [file dirname [info script]]
tcl::tm::path add [file join $scriptDir .. lib]

package require mdhelp_history 0.1

wm title . "mdhelp_history Demo"
wm geometry . 600x450

# ── Document data (simulated) ──
array set docs {
    intro.md    "# Introduction\n\nWelcome to the documentation.\nHere you will find everything important."
    install.md  "# Installation\n\nStep 1: Download\nStep 2: Extract\nStep 3: Start"
    api.md      "# API Reference\n\nProc: init\nProc: render\nProc: export"
    faq.md      "# FAQ\n\nQuestion: How do I start?\nAnswer: Start with wish.\n\nQuestion: Which version?\nAnswer: Tcl 8.6+"
}

# ── Toolbar ──
ttk::frame .tb
pack .tb -fill x -padx 5 -pady 5

ttk::button .tb.back -text "← Back" -command goBack
ttk::button .tb.fwd  -text "Forward →" -command goForward
ttk::label .tb.sep -text "  │  "
ttk::label .tb.loc -textvariable ::currentFile -font {Helvetica 10 bold}
ttk::label .tb.hist -textvariable ::histStatus -foreground gray

pack .tb.back .tb.fwd .tb.sep .tb.loc -side left -padx 2
pack .tb.hist -side right -padx 5

# ── Document list ──
ttk::frame .nav
pack .nav -side left -fill y -padx 5 -pady 5

ttk::label .nav.title -text "Documents:" -font {Helvetica 10 bold}
pack .nav.title -anchor w

foreach doc [lsort [array names docs]] {
    ttk::button .nav.b_[string map {. _ - _} $doc] \
        -text "📄 $doc" -width 18 \
        -command [list navigateTo $doc]
    pack .nav.b_[string map {. _ - _} $doc] -fill x -pady 1
}

# ── Text Widget ──
ttk::frame .main
pack .main -fill both -expand 1 -padx 5 -pady 5

text .main.t -wrap word -font {Helvetica 11} -padx 10 -pady 10 \
    -state disabled -yscrollcommand {.main.sb set}
ttk::scrollbar .main.sb -orient vertical -command {.main.t yview}
pack .main.sb -side right -fill y
pack .main.t -fill both -expand 1

# ── Initialize history ──
mdhelp_history::init .main.t

mdhelp_history::setCallback .main.t {apply {{file anchor} {
    showDoc $file
}}}

# ── Functions ──
proc showDoc {file} {
    # Display a document (without history push)
    global docs currentFile
    
    .main.t configure -state normal
    .main.t delete 1.0 end
    
    if {[info exists docs($file)]} {
        .main.t insert end $docs($file)
    } else {
        .main.t insert end "Document not found: $file"
    }
    
    .main.t configure -state disabled
    set currentFile $file
    updateButtons
}

proc navigateTo {file} {
    # Normal navigation (with history push)
    mdhelp_history::push .main.t $file
    showDoc $file
}

proc goBack {} {
    mdhelp_history::back .main.t
    updateButtons
}

proc goForward {} {
    mdhelp_history::forward .main.t
    updateButtons
}

proc updateButtons {} {
    if {[mdhelp_history::canBack .main.t]} {
        .tb.back state !disabled
    } else {
        .tb.back state disabled
    }
    
    if {[mdhelp_history::canForward .main.t]} {
        .tb.fwd state !disabled
    } else {
        .tb.fwd state disabled
    }
    
    set n [mdhelp_history::count .main.t]
    set ::histStatus "History: $n entries"
}

# Alt+Left/Right bindings
mdhelp_history::setupBindings .main.t
# Update buttons after back/forward
bind .main.t <Alt-Left>  {+ updateButtons}
bind .main.t <Alt-Right> {+ updateButtons}

# ── Start ──
navigateTo "intro.md"
focus .main.t
