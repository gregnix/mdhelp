#!/usr/bin/env tclsh
# test_toc_suppress.tcl -- Logik-Test fuer TOC-Selection-Suppress
#
# Prueft die Suppress-Logik aus mdhelp_ui.tcl (Variable tocSyncSuppressUntil)
# isoliert -- ohne Tk, mdstack oder eine echte UI zu laden.
#
# Hintergrund: nach Klick auf TOC-Eintrag triggert `gotoAnchor` ein
# Scroll-Event, das durch debounced `syncTocFromScroll` die Selektion
# UEBERSCHREIBEN wuerde mit dem Anchor *oberhalb* der sichtbaren Zeile.
# Loesung: `onTocSelect` setzt `tocSyncSuppressUntil = now + 500ms`.
# `syncTocFromScroll` checkt das und returned ohne Update.

package require tcltest
namespace import ::tcltest::*

# --- Minimal app::-Namespace anlegen, wie ihn mdhelp.tcl deklariert ---
namespace eval ::app {
    variable tocSyncSuppressUntil 0
    variable tocSyncSuppressMs 500
    variable _syncRanCount 0   ;# Test-only: zaehlt erfolgreiche Sync-Laufe
}

# --- Mocks: Verhalten von mdhelp_ui.tcl nachbilden ohne Tk ---

# Simuliert app::onTocSelect (nur den Suppress-relevanten Teil)
proc ::app::testTocSelect {} {
    variable tocSyncSuppressUntil
    variable tocSyncSuppressMs
    set tocSyncSuppressUntil [expr {[clock milliseconds] + $tocSyncSuppressMs}]
}

# Simuliert app::syncTocFromScroll-Guard (nur den Check)
proc ::app::testSyncFromScroll {} {
    variable tocSyncSuppressUntil
    variable _syncRanCount
    if {[clock milliseconds] < $tocSyncSuppressUntil} {
        return 0
    }
    incr _syncRanCount
    return 1
}

# Reset-Helper
proc resetState {{ms 500}} {
    set ::app::tocSyncSuppressUntil 0
    set ::app::tocSyncSuppressMs $ms
    set ::app::_syncRanCount 0
}

# --- Tests ---

test toc-suppress-1.1 {Ohne TOC-Klick laeuft Sync normal} -setup {
    resetState
} -body {
    ::app::testSyncFromScroll
    set ::app::_syncRanCount
} -result 1

test toc-suppress-1.2 {Nach TOC-Klick wird Sync sofort unterdrueckt} -setup {
    resetState
} -body {
    ::app::testTocSelect
    set r [::app::testSyncFromScroll]
    list ranNow=$r count=$::app::_syncRanCount
} -result {ranNow=0 count=0}

test toc-suppress-1.3 {Mehrere Sync-Versuche innerhalb des Fensters bleiben blockiert} -setup {
    resetState
} -body {
    ::app::testTocSelect
    ::app::testSyncFromScroll
    ::app::testSyncFromScroll
    ::app::testSyncFromScroll
    set ::app::_syncRanCount
} -result 0

test toc-suppress-1.4 {Sync laeuft wieder nach Ablauf des Fensters} -setup {
    resetState 50
} -body {
    ::app::testTocSelect
    set dur [::app::testSyncFromScroll]
    after 100
    set aft [::app::testSyncFromScroll]
    list during=$dur after=$aft count=$::app::_syncRanCount
} -result {during=0 after=1 count=1}

test toc-suppress-1.5 {SuppressMs = 0 deaktiviert Suppress (Legacy-Modus)} -setup {
    resetState 0
} -body {
    ::app::testTocSelect
    after 1   ;# winzige Pause, sicher dass clock fortgeschritten
    ::app::testSyncFromScroll
    set ::app::_syncRanCount
} -result 1

test toc-suppress-1.6 {Bounds-Check: gueltige Werte 0..5000} -body {
    set good {0 1 100 500 1000 5000}
    set bad  {-1 5001 abc {}}
    foreach v $good {
        if {!([string is integer -strict $v] && $v >= 0 && $v <= 5000)} {
            return "good rejected: $v"
        }
    }
    foreach v $bad {
        if {[string is integer -strict $v] && $v >= 0 && $v <= 5000} {
            return "bad accepted: $v"
        }
    }
    return ok
} -result ok

# --- Source-Code-Strukturen-Check: Critical Patterns ---
# Stellt sicher, dass die echten Source-Files weiterhin die noetigen
# Patterns enthalten -- haelt zukuenftige Refactorings davon ab, den
# Fix unbemerkt zu entfernen.

set scriptDir [file dirname [file normalize [info script]]]
set repoDir   [file dirname $scriptDir]

test toc-suppress-2.1 {mdhelp.tcl deklariert tocSyncSuppressUntil und tocSyncSuppressMs} -body {
    set f [open [file join $repoDir app mdhelp.tcl] r]
    set src [read $f]
    close $f
    set hasUntil [regexp {variable tocSyncSuppressUntil} $src]
    set hasMs    [regexp {variable tocSyncSuppressMs}    $src]
    list until=$hasUntil ms=$hasMs
} -result {until=1 ms=1}

test toc-suppress-2.2 {mdhelp_ui.tcl: onTocSelect setzt Suppress vor gotoAnchor} -body {
    set f [open [file join $repoDir app mdhelp_ui.tcl] r]
    set src [read $f]
    close $f
    # Set-Statement und Call-Statement haben spezifische Praefixe,
    # die nicht in Kommentaren vorkommen.
    set setIdx  [string first "set ::app::tocSyncSuppressUntil" $src]
    set callIdx [string first "mdstack::viewer::gotoAnchor" $src]
    if {$setIdx == -1 || $callIdx == -1} {
        return "missing: set=$setIdx call=$callIdx"
    }
    if {$setIdx >= $callIdx} {
        return "wrong order: Suppress muss VOR gotoAnchor-Call stehen"
    }
    return ok
} -result ok

test toc-suppress-2.3 {mdhelp_ui.tcl: syncTocFromScroll hat Suppress-Guard} -body {
    set f [open [file join $repoDir app mdhelp_ui.tcl] r]
    set src [read $f]
    close $f
    if {![regexp {(?s)proc app::syncTocFromScroll.*?\n\}} $src body]} {
        return "syncTocFromScroll not found"
    }
    set hasCheck [regexp {tocSyncSuppressUntil} $body]
    set hasEarly [regexp {return} $body]
    list check=$hasCheck early-return=$hasEarly
} -result {check=1 early-return=1}

test toc-suppress-2.4 {mdhelp_settings.tcl persistiert tocSyncSuppressMs} -body {
    set f [open [file join $repoDir app mdhelp_settings.tcl] r]
    set src [read $f]
    close $f
    set hasSave [regexp {list tocSyncSuppressMs} $src]
    set hasLoad [regexp {tocSyncSuppressMs\s*\{} $src]
    list save=$hasSave load=$hasLoad
} -result {save=1 load=1}

cleanupTests
