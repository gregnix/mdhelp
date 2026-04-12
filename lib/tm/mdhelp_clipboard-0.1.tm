# mdhelp_clipboard-0.1.tm
#
# Clipboard functions for mdhelp — copy/select all for the read-only viewer.
# Extracted from mdhelp_render-0.3.2, standalone without renderer dependency.
#
# Requirements:
#   Tcl 8.6+ (9.x compatible)
#   Tk
#   Optional: mdhelp_search 0.1 (for context menu "Copy all matches")
#
# API:
#   mdhelp_clipboard::copy $t              → Copy selection (cleaned)
#   mdhelp_clipboard::copyRaw $t           → Copy selection (unchanged)
#   mdhelp_clipboard::selectAll $t         → Select all
#   mdhelp_clipboard::setupBindings $t     → Ctrl+C, Ctrl+A
#   mdhelp_clipboard::setupContextMenu $t  → Right-click menu
#
# Example:
#   mdhelp_clipboard::setupBindings .t
#   mdhelp_clipboard::setupContextMenu .t

package require Tcl 8.6-

package provide mdhelp_clipboard 0.1

namespace eval mdhelp_clipboard {
    namespace export copy copyRaw selectAll setupBindings setupContextMenu
}

proc mdhelp_clipboard::copy {t} {
    # Copies current selection to clipboard.
    # Cleans up text for better readability:
    # - Tabs from tables → spaces
    # - Multiple blank lines → max 2
    # - Trailing whitespace removed

    # Check if selection exists
    if {[catch {$t index sel.first}]} {
        return
    }

    # Get text from selection
    set text [$t get sel.first sel.last]

    # 1) Replace tabs from tables → two spaces
    regsub -all {\t+} $text {  } text

    # 2) Reduce multiple blank lines (max 2)
    regsub -all {\n{3,}} $text "\n\n" text

    # 3) Lines with only whitespace → empty lines
    regsub -all -line {^[ \t]+$} $text {} text

    # 4) Remove leading/trailing whitespace
    set text [string trim $text]

    # Set clipboard
    clipboard clear
    clipboard append $text
}

proc mdhelp_clipboard::copyRaw {t} {
    # Copies the selection unchanged (original layout).
    # For cases where the exact layout is needed.

    if {[catch {$t index sel.first}]} {
        return
    }

    # Text is normally disabled, temporarily enable for copy
    set wasDisabled [expr {[$t cget -state] eq "disabled"}]
    if {$wasDisabled} {
        $t configure -state normal
    }

    tk_textCopy $t

    if {$wasDisabled} {
        $t configure -state disabled
    }
}

proc mdhelp_clipboard::selectAll {t} {
    # Selects all text.

    $t tag remove sel 1.0 end
    $t tag add sel 1.0 "end-1c"
}

proc mdhelp_clipboard::setupBindings {t} {
    # Sets up standard keyboard shortcuts.
    # Ctrl+C = Copy, Ctrl+A = Select all

    bind $t <Control-c> [list mdhelp_clipboard::copy $t]
    bind $t <Control-C> [list mdhelp_clipboard::copy $t]

    bind $t <Control-a> [list mdhelp_clipboard::selectAll $t]
    bind $t <Control-A> [list mdhelp_clipboard::selectAll $t]

    # Mac-Bindings (Command statt Control)
    bind $t <Command-c> [list mdhelp_clipboard::copy $t]
    bind $t <Command-a> [list mdhelp_clipboard::selectAll $t]
}

proc mdhelp_clipboard::setupContextMenu {t} {
    # Creates a context menu for the text widget.

    set menuName "${t}_ctx"

    catch {destroy $menuName}

    menu $menuName -tearoff 0
    $menuName add command -label "Copy" \
        -accelerator "Ctrl+C" \
        -command [list mdhelp_clipboard::copy $t]
    $menuName add command -label "Copy Original" \
        -command [list mdhelp_clipboard::copyRaw $t]
    $menuName add separator
    $menuName add command -label "Copy All Matches" \
        -command [list mdhelp_search::copyAll $t]
    $menuName add separator
    $menuName add command -label "Select all" \
        -accelerator "Ctrl+A" \
        -command [list mdhelp_clipboard::selectAll $t]

    # Right-click
    bind $t <Button-3> [list mdhelp_clipboard::_showContextMenu $t $menuName %X %Y]

    # Mac: Control-Click
    bind $t <Control-Button-1> [list mdhelp_clipboard::_showContextMenu $t $menuName %X %Y]
}

proc mdhelp_clipboard::_showContextMenu {t menuName x y} {
    # Shows the context menu at mouse position.

    # Enable "Copy" only if selection exists
    if {[catch {$t index sel.first}]} {
        $menuName entryconfigure "Copy" -state disabled
        $menuName entryconfigure "Copy Original" -state disabled
    } else {
        $menuName entryconfigure "Copy" -state normal
        $menuName entryconfigure "Copy Original" -state normal
    }

    # "Copy All Matches" only if mdhelp_search loaded and matches present
    if {[namespace exists ::mdhelp_search] && [mdhelp_search::count $t] > 0} {
        $menuName entryconfigure "Copy All Matches" -state normal
    } else {
        $menuName entryconfigure "Copy All Matches" -state disabled
    }

    tk_popup $menuName $x $y
}
