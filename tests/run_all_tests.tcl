#!/usr/bin/env tclsh
# run_all_tests.tcl -- Fuehrt alle mdhelp-Tests aus
#
# Aufruf: tclsh run_all_tests.tcl
# Exit-Code: 0 = alle passed, >0 = Anzahl faileder suites

set testDir [file dirname [info script]]
set totalPass 0
set totalFail 0
set failedSuites {}

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

    if {$rc != 0} {
        lappend failedSuites $name
        incr totalFail
    } else {
        incr totalPass
    }
}

puts "============================================"
puts "  Total: $totalPass suites passed, $totalFail failed"
puts "============================================"
if {[llength $failedSuites] > 0} {
    puts "\n  Failed suites:"
    foreach s $failedSuites { puts "    - $s" }
}
exit $totalFail
