# mdhelp_history-0.1.tm
#
# Browser-like back/forward navigation for mdhelp.
# Extracted from mdhelp_render-0.3.2, standalone without renderer dependency.
#
# Requirements:
#   Tcl 8.6+ (9.x compatible)
#   Tk (for bindings)
#
# API:
#   mdhelp_history::init $t                      → Initialize
#   mdhelp_history::setCallback $t $callback     → Callback on navigation
#   mdhelp_history::push $t $file ?$anchor?      → Add entry
#   mdhelp_history::back $t                      → Back
#   mdhelp_history::forward $t                   → Forward
#   mdhelp_history::canBack $t                   → Can go back?
#   mdhelp_history::canForward $t                → Can go forward?
#   mdhelp_history::current $t                   → Current entry
#   mdhelp_history::clear $t                     → Clear all
#   mdhelp_history::count $t                     → Number of entries
#   mdhelp_history::setupBindings $t             → Alt+Left/Right
#
# Callback signature: callback $file $anchor
#
# Example:
#   mdhelp_history::init .t
#   mdhelp_history::setCallback .t {apply {{file anchor} {
#       renderFile $file
#       if {$anchor ne ""} { gotoAnchor $anchor }
#   }}}
#   mdhelp_history::push .t "docs/intro.md"
#   mdhelp_history::push .t "docs/api.md" "section-2"
#   mdhelp_history::back .t   ;# → navigates to intro.md

package require Tcl 8.6-

package provide mdhelp_history 0.1

namespace eval mdhelp_history {
    namespace export init setCallback push back forward \
                     canBack canForward current clear count \
                     setupBindings

    variable state
    # state($t,back)     - Stack of previous entries
    # state($t,forward)  - Stack of next entries
    # state($t,current)  - Current entry {file anchor}
    # state($t,callback) - Callback on navigation
}

proc mdhelp_history::init {t} {
    # Initializes history for a widget.
    variable state

    set state($t,back) {}
    set state($t,forward) {}
    set state($t,current) {}
    set state($t,callback) {}
}

proc mdhelp_history::setCallback {t callback} {
    # Sets callback that is called on back/forward.
    # Callback signature: callback $file $anchor
    variable state

    if {![info exists state($t,back)]} {
        mdhelp_history::init $t
    }
    set state($t,callback) $callback
}

proc mdhelp_history::push {t file {anchor ""}} {
    # Adds a history entry.
    # Called on normal navigation (not on back/forward).
    variable state

    if {![info exists state($t,back)]} {
        mdhelp_history::init $t
    }

    set newEntry [list $file $anchor]

    # Same state? → do nothing
    if {$state($t,current) eq $newEntry} {
        return
    }

    # Push current state to back
    if {$state($t,current) ne {}} {
        lappend state($t,back) $state($t,current)
    }

    # Set new state
    set state($t,current) $newEntry

    # Discard forward (browser logic)
    set state($t,forward) {}
}

proc mdhelp_history::back {t} {
    # Navigates back.
    # Returns {file anchor} or {} if not possible.
    variable state

    if {![info exists state($t,back)] || [llength $state($t,back)] == 0} {
        return {}
    }

    # Aktuellen nach forward
    if {$state($t,current) ne {}} {
        lappend state($t,forward) $state($t,current)
    }

    # Letzten back holen
    set state($t,current) [lindex $state($t,back) end]
    set state($t,back) [lrange $state($t,back) 0 end-1]

    # Callback aufrufen
    if {$state($t,callback) ne {}} {
        lassign $state($t,current) file anchor
        uplevel #0 [list {*}$state($t,callback) $file $anchor]
    }

    return $state($t,current)
}

proc mdhelp_history::forward {t} {
    # Navigates forward.
    # Returns {file anchor} or {} if not possible.
    variable state

    if {![info exists state($t,forward)] || [llength $state($t,forward)] == 0} {
        return {}
    }

    # Aktuellen nach back
    if {$state($t,current) ne {}} {
        lappend state($t,back) $state($t,current)
    }

    # Letzten forward holen
    set state($t,current) [lindex $state($t,forward) end]
    set state($t,forward) [lrange $state($t,forward) 0 end-1]

    # Callback aufrufen
    if {$state($t,callback) ne {}} {
        lassign $state($t,current) file anchor
        uplevel #0 [list {*}$state($t,callback) $file $anchor]
    }

    return $state($t,current)
}

proc mdhelp_history::canBack {t} {
    # Checks if back navigation is possible.
    variable state

    if {![info exists state($t,back)]} {
        return 0
    }
    return [expr {[llength $state($t,back)] > 0}]
}

proc mdhelp_history::canForward {t} {
    # Checks if forward navigation is possible.
    variable state

    if {![info exists state($t,forward)]} {
        return 0
    }
    return [expr {[llength $state($t,forward)] > 0}]
}

proc mdhelp_history::current {t} {
    # Returns the current history entry.
    # Format: {file anchor} oder {}
    variable state

    if {![info exists state($t,current)]} {
        return {}
    }
    return $state($t,current)
}

proc mdhelp_history::clear {t} {
    # Clears the complete history.
    variable state

    set state($t,back) {}
    set state($t,forward) {}
    set state($t,current) {}
}

proc mdhelp_history::count {t} {
    # Returns the number of history entries (back + current + forward).
    variable state

    if {![info exists state($t,back)]} {
        return 0
    }

    set n [llength $state($t,back)]
    if {$state($t,current) ne {}} {
        incr n
    }
    incr n [llength $state($t,forward)]
    return $n
}

proc mdhelp_history::setupBindings {t} {
    # Sets up keyboard shortcuts for navigation.
    # Alt+Left = Back, Alt+Right = Forward

    bind $t <Alt-Left>  [list mdhelp_history::back $t]
    bind $t <Alt-Right> [list mdhelp_history::forward $t]

    # Additional bindings
    bind $t <Alt-Key-Left>  [list mdhelp_history::back $t]
    bind $t <Alt-Key-Right> [list mdhelp_history::forward $t]
}
