#!/usr/bin/env tclsh
# run_all_tests.tcl -- Fuehrt alle mdhelp-Tests aus
#
# Aufruf: tclsh run_all_tests.tcl
# Exit-Code: 0 = alle passed, >0 = Anzahl faileder suites
#            2 = fehlende Dependencies (siehe README.md)

set testDir [file dirname [info script]]
set totalPass 0
set totalFail 0
set totalSkip 0
set failedSuites {}
set skipDepCheck 0

foreach arg $argv {
    switch -- $arg {
        --skip-dep-check - --no-deps {
            set skipDepCheck 1
        }
        --help - -h {
            puts "Usage: tclsh run_all_tests.tcl ?--skip-dep-check?"
            puts "  --skip-dep-check  Pre-Check fuer mdstack/docir ueberspringen"
            puts "                    (zB fuer Tests die keine Deps brauchen)"
            exit 0
        }
        default {
            puts stderr "Unknown arg: $arg (--help for usage)"
            exit 1
        }
    }
}

# ----------------------------------------------------------
# Dependency-Vorpruefung
# ----------------------------------------------------------
# Tests brauchen mdstack, docir, pdf4tcl. Statt jeder Test einzeln
# stack-tracet ueber 'can't find package ...', pruefen wir hier zentral
# und geben eine User-freundliche Meldung mit Install-Hinweis.
#
# pdf4tcl ist optional: nur PDF-Tests brauchen es. Wenn fehlt, wird
# eine Warnung gezeigt, aber Lauf geht weiter (nicht-PDF-Tests laufen).
#
# Pre-Check via --skip-dep-check ueberspringbar -- nuetzlich fuer
# Tests die keine Deps brauchen (z.B. test_toc_suppress.tcl).

proc checkPackage {pkg version optional} {
    set rc [catch {package require $pkg $version} err]
    if {$rc != 0} {
        return [list missing $err]
    }
    return [list ok [package present $pkg]]
}

if {!$skipDepCheck} {
    set requiredDeps {
        {mdstack::parser 0.2 required}
        {docir          1.0 required}
        {pdf4tcl        0.9 optional}
    }

    set missingRequired {}
    set missingOptional {}

    foreach dep $requiredDeps {
        lassign $dep pkg ver mode
        set r [checkPackage $pkg $ver $mode]
        lassign $r state info
        if {$state eq "missing"} {
            if {$mode eq "required"} {
                lappend missingRequired [list $pkg $ver $info]
            } else {
                lappend missingOptional [list $pkg $ver $info]
            }
        }
    }

    if {[llength $missingRequired] > 0} {
        puts stderr "============================================"
        puts stderr "  mdhelp Test Suite -- DEPENDENCIES MISSING"
        puts stderr "============================================"
        puts stderr ""
        puts stderr "Required Tcl packages konnten nicht gefunden werden:"
        foreach m $missingRequired {
            lassign $m pkg ver info
            puts stderr "  - $pkg (>= $ver) -- $info"
        }
        puts stderr ""
        puts stderr "Installation siehe README.md Abschnitt 'Setup'."
        puts stderr "Schnell-Setup (Linux, sudo):"
        puts stderr "  cd ../docir   && sudo make install"
        puts stderr "  cd ../mdstack && sudo make install"
        puts stderr ""
        puts stderr "Oder User-Install (ohne sudo):"
        puts stderr "  cd ../docir   && make install-user"
        puts stderr "  export TCLLIBPATH=\"\$HOME/lib/tcltk/docir \$HOME/lib/tcltk/mdstack\""
        puts stderr ""
        puts stderr "Tipp: einzelne Deps-freie Tests gehen direkt:"
        puts stderr "  tclsh tests/test_toc_suppress.tcl"
        puts stderr "Oder Pre-Check ueberspringen:"
        puts stderr "  tclsh tests/run_all_tests.tcl --skip-dep-check"
        puts stderr ""
        exit 2
    }

    if {[llength $missingOptional] > 0} {
        puts "WARN: optional packages fehlen -- entsprechende Tests werden failen:"
        foreach m $missingOptional {
            lassign $m pkg ver info
            puts "  - $pkg (>= $ver) -- $info"
        }
        puts ""
    }
}

# ----------------------------------------------------------
# Test-Suite ausfuehren
# ----------------------------------------------------------

puts "============================================"
puts "  mdhelp Test Suite"
puts "============================================"
puts ""

foreach testFile [lsort [glob -nocomplain [file join $testDir test_*.tcl]]] {
    set name [file tail $testFile]
    puts ">>> $name"

    set rc [catch {exec [info nameofexecutable] $testFile 2>@1} output]
    puts $output
    puts ""

    # Exit-Codes:
    #   0  -> pass
    #   2  -> skip (Convention: optionale Dependency fehlt, kein Fehler)
    #   *  -> fail
    if {$rc == 0} {
        incr totalPass
    } else {
        # exec catch liefert errorCode mit CHILDSTATUS pid exitCode
        set ec ""
        if {[info exists ::errorCode] && [lindex $::errorCode 0] eq "CHILDSTATUS"} {
            set ec [lindex $::errorCode 2]
        }
        if {$ec eq "2"} {
            incr totalSkip
        } else {
            lappend failedSuites $name
            incr totalFail
        }
    }
}

puts "============================================"
puts "  Total: $totalPass passed, $totalSkip skipped, $totalFail failed"
puts "============================================"
if {[llength $failedSuites] > 0} {
    puts "\n  Failed suites:"
    foreach s $failedSuites { puts "    - $s" }
}
exit $totalFail
