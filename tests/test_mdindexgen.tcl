#!/usr/bin/env tclsh
# test_mdindexgen.tcl -- Tests fuer mdindexgen (Index-Generator)
#
# Aufruf: tclsh test_mdindexgen.tcl
#
# Skip-on-missing: Wenn das Paket mdindexgen nicht installiert ist
# (z.B. weil es nicht zum mdhelp4-Kern gehoert sondern als optionales
# Tool gepflegt wird), wird die Test-Suite mit Exit 2 uebersprungen.

if {[catch {package require mdindexgen 0.1} err]} {
    puts "SKIP: Paket 'mdindexgen' nicht verfuegbar ($err)"
    puts "      Diese Test-Suite testet einen optionalen Indexer."
    exit 2
}

set pass 0
set fail 0
set errors {}

proc assert {name cond} {
    upvar pass pass fail fail errors errors
    set ok [uplevel 1 [list expr $cond]]
    if {$ok} {
        incr pass
    } else {
        incr fail
        lappend errors $name
        puts "  FAIL: $name"
    }
}

# Temporaeres Testverzeichnis
set tmpBase /tmp
if {[info exists ::env(TMPDIR)] && $::env(TMPDIR) ne ""} {
    set tmpBase $::env(TMPDIR)
}
if {![file writable $tmpBase]} {
    set tmpBase [pwd]
}
set testDir [file join $tmpBase _test_indexgen_[pid]]

proc setupTestDir {} {
    upvar testDir testDir

    file mkdir $testDir
    file mkdir [file join $testDir sub]

    # Hauptdokument
    set fd [open [file join $testDir features.md] w]
    puts $fd "# Features\n\nDie Features von mdhelp."
    close $fd

    # Zweites Dokument
    set fd [open [file join $testDir installation.md] w]
    puts $fd "# Installation\n\nSo installiert man mdhelp."
    close $fd

    # Unterverzeichnis mit Datei
    set fd [open [file join $testDir sub howto.md] w]
    puts $fd "# Howto\n\nAnleitung."
    close $fd

    # Dokument ohne H1 (nur Text)
    set fd [open [file join $testDir notes.md] w]
    puts $fd "Einfach nur Text ohne Ueberschrift."
    close $fd

    # YAML-Frontmatter Dokument
    set fd [open [file join $testDir config.md] w]
    puts $fd "---\ntitle: Konfiguration\n---\n\nInhalt."
    close $fd
}

proc cleanupTestDir {} {
    upvar testDir testDir
    if {![file exists $testDir]} return

    # Erster Versuch: Standardweg.
    if {![catch {file delete -force -- $testDir}]} return

    # Fallback: manuell rekursieren. `file delete -force` versagt auf
    # manchen Filesystemen / Tcl-Versionen mit
    #   "illegal operation on a directory"
    # bei nicht-leeren Subverzeichnissen. Gemeldet 2026-05-07 via
    # zweite externe Code-Review.
    rmTreeBestEffort $testDir
}

proc rmTreeBestEffort {path} {
    if {![file exists $path] && ![file type $path] eq "link"} return
    # Symlink: nur den Link entfernen, nicht das Ziel
    if {![catch {file readlink $path}]} {
        catch {file delete -- $path}
        return
    }
    if {[file isdirectory $path]} {
        foreach item [glob -nocomplain -directory $path -tails -- *] {
            rmTreeBestEffort [file join $path $item]
        }
        # Versteckte Einträge (. und .. herausfiltern)
        foreach item [glob -nocomplain -directory $path -tails -types hidden -- *] {
            if {$item in {. ..}} continue
            rmTreeBestEffort [file join $path $item]
        }
        catch {file delete -- $path}
    } else {
        catch {file delete -force -- $path}
    }
}

puts "=== mdindexgen Tests ==="
puts ""

# -- 1. readTitle --
puts "--- readTitle ---"
setupTestDir

set title1 [mdindexgen::readTitle [file join $testDir features.md]]
assert "title-h1"       {$title1 eq "Features"}

set title2 [mdindexgen::readTitle [file join $testDir notes.md]]
assert "title-no-h1"    {$title2 eq "notes"}

set title3 [mdindexgen::readTitle [file join $testDir config.md]]
assert "title-yaml"     {$title3 eq "Konfiguration" || $title3 eq "config"}

# -- 2. Scan (dryrun) --
puts "--- Scan (dryrun) ---"
set result [mdindexgen::scan $testDir -dryrun 1 -verbose 0]
assert "scan-returns-dict" {[dict exists $result updated] && [dict exists $result created]}

# -- 3. Scan (real) --
puts "--- Scan (real) ---"
set result [mdindexgen::scan $testDir -verbose 0]
assert "scan-created"    {[llength [dict get $result created]] > 0 || [llength [dict get $result updated]] > 0}

# Index-Datei muss existieren
assert "index-exists"    {[file exists [file join $testDir index.md]]}

# Index muss Links zu Dokumenten enthalten
set fd [open [file join $testDir index.md] r]
set content [read $fd]
close $fd
assert "index-has-features" {[string match "*features.md*" $content]}
assert "index-has-install"  {[string match "*installation.md*" $content]}

# -- 4. Unterverzeichnis --
puts "--- Unterverzeichnis ---"
assert "sub-index-exists" {[file exists [file join $testDir sub index.md]] || \
    [file exists [file join $testDir indexsub.md]]}

# indexsub.md im Hauptverzeichnis
if {[file exists [file join $testDir indexsub.md]]} {
    set fd [open [file join $testDir indexsub.md] r]
    set sub [read $fd]
    close $fd
    assert "indexsub-has-sub" {[string match "*sub*" $sub]}
} else {
    assert "indexsub-has-sub" {1}
}

# -- 5. Idempotenz --
puts "--- Idempotenz ---"
set result2 [mdindexgen::scan $testDir -verbose 0]
assert "idempotent"      {[llength [dict get $result2 unchanged]] > 0}

# -- 6. updateIndex einzeln --
puts "--- updateIndex ---"
set r [mdindexgen::updateIndex $testDir -dryrun 1]
assert "update-index-ok" {$r ne ""}

# -- Aufraeuemen --
cleanupTestDir

# -- Summary --
puts ""
puts "========================================="
puts "  Result: $pass passed, $fail failed"
puts "========================================="
if {[llength $errors] > 0} {
    puts "\n  Failed:"
    foreach e $errors { puts "    - $e" }
}
exit $fail
