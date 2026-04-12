#!/usr/bin/env wish
# demo_search.tcl — Demo for mdhelp_search-0.1.tm
#
# Shows widget search with highlighting, Next/Prev, CopyAll.
# Start: wish demo_search.tcl

package require Tk

set scriptDir [file dirname [info script]]
tcl::tm::path add [file join $scriptDir .. lib]

package require mdhelp_search 0.1

wm title . "mdhelp_search Demo"
wm geometry . 700x500

# ── Toolbar ──
ttk::frame .tb
pack .tb -fill x -padx 5 -pady 5

ttk::label .tb.lbl -text "Search:"
ttk::entry .tb.entry -width 30 -textvariable ::searchPattern
ttk::button .tb.find -text "Find" -command doSearch
ttk::button .tb.prev -text "◀ Prev" -command {mdhelp_search::prev .t}
ttk::button .tb.next -text "Next ▶" -command {mdhelp_search::next .t}
ttk::button .tb.clear -text "Clear" -command {mdhelp_search::clear .t; set ::statusText ""}
ttk::button .tb.copy -text "Copy All" -command doCopyAll
ttk::label .tb.status -textvariable ::statusText

pack .tb.lbl .tb.entry .tb.find .tb.prev .tb.next .tb.clear .tb.copy -side left -padx 2
pack .tb.status -side left -padx 10

# ── Text Widget ──
text .t -wrap word -font {Helvetica 11} -padx 10 -pady 10 \
    -yscrollcommand {.sb set}
ttk::scrollbar .sb -orient vertical -command {.t yview}
pack .sb -side right -fill y
pack .t -fill both -expand 1 -padx 5 -pady 5

# ── Example text ──
.t insert end "Tcl/Tk Introduction\n" {heading}
.t insert end "\n"
.t insert end "Tcl (Tool Command Language) is a dynamic scripting language.\n"
.t insert end "Tk is the associated GUI toolkit for Tcl.\n"
.t insert end "Together, Tcl and Tk form a powerful tool.\n"
.t insert end "\n"
.t insert end "Basics\n" {heading}
.t insert end "\n"
.t insert end "In Tcl, everything is a string. Even numbers and lists are strings.\n"
.t insert end "The Tcl interpreter processes commands line by line.\n"
.t insert end "Each command follows the pattern: command arg1 arg2 ...\n"
.t insert end "\n"
.t insert end "Variables\n" {heading}
.t insert end "\n"
.t insert end "Variables are set with set: set name \"Tcl\"\n"
.t insert end "The value is retrieved with \$name.\n"
.t insert end "Tcl also knows arrays: set data(key) \"value\"\n"
.t insert end "\n"
.t insert end "Procedures\n" {heading}
.t insert end "\n"
.t insert end "Procedures are defined with proc:\n"
.t insert end "proc greet {name} { puts \"Hello \$name\" }\n"
.t insert end "Tcl supports variable arguments with args.\n"
.t insert end "Default values are possible: proc f {{x 0}} {}\n"
.t insert end "\n"
.t insert end "Control Structures\n" {heading}
.t insert end "\n"
.t insert end "Tcl provides if, while, for, foreach and switch.\n"
.t insert end "All control structures are normal Tcl commands.\n"
.t insert end "This is a fundamental design principle of Tcl.\n"

.t tag configure heading -font {Helvetica 14 bold} -spacing1 10

# Enter key in entry
bind .tb.entry <Return> doSearch

# ── Actions ──
proc doSearch {} {
    set n [mdhelp_search::find .t $::searchPattern]
    if {$n > 0} {
        set idx [expr {[mdhelp_search::current .t] + 1}]
        set ::statusText "$idx / $n matches"
    } else {
        set ::statusText "No matches"
    }
}

proc doCopyAll {} {
    set n [mdhelp_search::copyAll .t]
    if {$n > 0} {
        set ::statusText "$n matches copied to clipboard"
    }
}

# Update status on Next/Prev
proc updateStatus {args} {
    set n [mdhelp_search::count .t]
    if {$n > 0} {
        set idx [expr {[mdhelp_search::current .t] + 1}]
        set ::statusText "$idx / $n matches"
    }
}

# Bindings for Next/Prev with status update
bind .t <F3> {mdhelp_search::next .t; updateStatus}
bind .t <Shift-F3> {mdhelp_search::prev .t; updateStatus}

# Wrap buttons with status update
.tb.prev configure -command {mdhelp_search::prev .t; updateStatus}
.tb.next configure -command {mdhelp_search::next .t; updateStatus}

focus .tb.entry
set statusText "F3 = Next, Shift+F3 = Prev"
