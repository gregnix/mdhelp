#!/usr/bin/env tclsh
# build.tcl -- mdhelp 4 Standalone-Binary Builder
#
# Baut Linux- und Windows-Starpacks aus dem Quellcode.
#
# Verwendung:
#   tclsh build.tcl             ;# Linux + Windows
#   tclsh build.tcl linux       ;# nur Linux
#   tclsh build.tcl windows     ;# nur Windows
#   tclsh build.tcl clean       ;# Build-Artefakte loeschen
#
# Voraussetzungen:
#   - tclsh 8.6+
#   - runtimes/sdx.kit           (von https://chiselapp.com/user/aspect/repository/sdx)
#   - runtimes/tclkit-*Linux*tk  (von https://www.tcl3d.org/bawt/apps.html)
#   - runtimes/tclkit-*Win*.exe  (gleiche Quelle, fuer Windows-Binary)

encoding system utf-8

# ============================================================
# Verzeichnisse
# ============================================================

set scriptDir  [file dirname [file normalize [info script]]]
set buildDir   [file join $scriptDir build]
set distDir    [file join $scriptDir dist]
set runtimeDir [file normalize [file join $scriptDir .. runtimes]]
set vfsDir     [file join $buildDir  mdhelp.vfs]

# ============================================================
# Ausgabe
# ============================================================

proc info {msg}  { puts "==> $msg" }
proc ok   {msg}  { puts " OK $msg" }
proc warn {msg}  { puts "WRN $msg" }
proc fail {msg}  { puts stderr "FEHLER: $msg"; exit 1 }

# ============================================================
# Hilfsprozeduren
# ============================================================

# Verzeichnis rekursiv kopieren
proc copyDir {src dst} {
    file mkdir $dst
    foreach entry [glob -nocomplain -directory $src *] {
        set name [file tail $entry]
        set target [file join $dst $name]
        if {[file isdirectory $entry]} {
            copyDir $entry $target
        } else {
            file copy -force $entry $target
        }
    }
}

# In allen .tm/.tcl Dateien eines Verzeichnisses ersetzen
proc patchFiles {dir args} {
    foreach f [glob -nocomplain -directory $dir *.tm *.tcl] {
        set fh [open $f r]; fconfigure $fh -encoding utf-8
        set content [read $fh]; close $fh
        set patched $content
        foreach {old new} $args {
            set patched [string map [list $old $new] $patched]
        }
        if {$patched ne $content} {
            set fh [open $f w]; fconfigure $fh -encoding utf-8
            puts -nonewline $fh $patched; close $fh
        }
    }
}

# Anzahl Dateien in einem Verzeichnis (rekursiv)
proc countFiles {dir} {
    set n 0
    foreach f [glob -nocomplain -directory $dir -type f *] { incr n }
    foreach d [glob -nocomplain -directory $dir -type d *] {
        incr n [countFiles $d]
    }
    return $n
}

# ============================================================
# Runtimes pruefen
# ============================================================

proc findRuntime {dir pattern {ext ""}} {
    set hits [glob -nocomplain -directory $dir $pattern]
    # Dateien ohne Windows-Endung bevorzugen wenn kein ext erwartet
    foreach f $hits {
        if {$ext eq "" && [string match "*.exe" $f]} continue
        return $f
    }
    # Fallback: erstes Ergebnis
    return [lindex $hits 0]
}

proc checkRuntimes {} {
    global runtimeDir tclkitLinux tclkitWindows

    set missing {}

    # sdx.kit
    set sdx [file join $runtimeDir sdx.kit]
    if {![file exists $sdx]} {
        lappend missing "  sdx.kit fehlt.\n    Herunterladen von:\n    https://chiselapp.com/user/aspect/repository/sdx/uv/sdx.kit\n    -> $runtimeDir/sdx.kit"
    }

    # Linux Tclkit
    set tclkitLinux [findRuntime $runtimeDir "*Linux*-tk"]
    if {$tclkitLinux eq ""} {
        lappend missing "  Linux-Tclkit fehlt.\n    Herunterladen von:\n    https://www.tcl3d.org/bawt/apps.html  (tclkits-8.6.17.7z)\n    Benoetigt: tclkit-Linux64-tk  (oder aequivalent)\n    -> $runtimeDir/"
    } else {
        if {$::tcl_platform(platform) eq "unix"} {
            file attributes $tclkitLinux -permissions 0755
        }
        ok "Linux-Runtime:   [file tail $tclkitLinux]"
    }

    # Windows Tclkit (optional)
    set tclkitWindows [findRuntime $runtimeDir "*win*-tk.exe" .exe]
    if {$tclkitWindows eq ""} {
        warn "Windows-Tclkit fehlt -- Windows-Build wird uebersprungen."
        warn "  Benoetigt: tclkit-win64-tk.exe  (oder aequivalent)"
        warn "  Von: https://www.tcl3d.org/bawt/apps.html (tclkits-8.6.17.7z)"
        warn "  -> $runtimeDir/"
    } else {
        ok "Windows-Runtime: [file tail $tclkitWindows]"
    }

    if {[llength $missing] > 0} {
        puts stderr "\nFEHLER: Fehlende Dateien in $runtimeDir/:"
        foreach m $missing { puts stderr $m }
        puts stderr "\nSiehe BUILD.md fuer Details."
        exit 1
    }
}

# ============================================================
# VFS aufbauen
# ============================================================

proc buildVfs {} {
    global scriptDir buildDir vfsDir

    info "Baue VFS..."
    catch {file delete -force $vfsDir}
    file mkdir [file join $vfsDir applib]
    file mkdir [file join $vfsDir apptm]

    # --- main.tcl ---
    set mainTcl {package require Tk
set appDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file join $appDir applib]
tcl::tm::path add [file join $appDir apptm]
foreach pkgDir [glob -nocomplain -directory [file join $appDir vendors pkg] *] {
    if {[file isdirectory $pkgDir]} { lappend ::auto_path $pkgDir }
}
source [file join $appDir mdhelp_app.tcl]
}
    set fh [open [file join $vfsDir main.tcl] w]
    fconfigure $fh -encoding utf-8
    puts -nonewline $fh $mainTcl
    close $fh

    # --- mdhelp_app.tcl: ab "package require Tk" bis Ende ---
    set src [file join $scriptDir app mdhelp.tcl]
    set fh [open $src r]; fconfigure $fh -encoding utf-8
    set lines [split [read $fh] "\n"]; close $fh
    set start 0
    foreach i [lsearch -all $lines "package require Tk*"] {
        set start $i
        break
    }
    # Entwicklungs-Pfad-Zeilen entfernen — im Starpack sind alle Module
    # bereits im VFS, der Bootstrap-Mechanismus ist dort nicht noetig.
    # Im Starpack sind alle Module bereits im VFS — die Zeilen aus dem
    # Entwicklungs-Setup (set appDir / tcl::tm::path add lib/tm) sind
    # dort weder gewollt noch funktionierend, also rausfiltern.
    set appLines {}
    foreach line [lrange $lines $start end] {
        if {[string match "set appDir*" $line]} continue
        if {[string match "::tcl::tm::path*" $line]} continue
        if {[string match "tcl::tm::path*" $line]} continue
        lappend appLines $line
    }
    set fh [open [file join $vfsDir mdhelp_app.tcl] w]
    fconfigure $fh -encoding utf-8
    puts -nonewline $fh [join $appLines "\n"]
    close $fh

    # --- App-Komponenten ---
    foreach f {mdhelp_editor.tcl mdhelp_nav.tcl mdhelp_ui.tcl
               mdhelp_search_ui.tcl mdhelp_settings.tcl} {
        set src [file join $scriptDir app $f]
        if {[file exists $src]} {
            file copy -force $src [file join $vfsDir $f]
        } else {
            warn "Warnung: $f nicht gefunden"
        }
    }

    # --- Module ---
    # mdhelp-eigene Module (lib/tm/) → applib/
    foreach f [glob -nocomplain -directory [file join $scriptDir lib tm] *.tm] {
        file copy -force $f [file join $vfsDir applib [file tail $f]]
    }

    # Externe Module (docir, mdstack, pdf4tcllib) → apptm/
    # Pfade kommen aus Umgebungsvariablen. Diese MUESSEN gesetzt sein —
    # build.tcl fail-fast statt mit leerem VFS weiterzumachen.
    set repoEnv [dict create \
        docir       DOCIR_HOME \
        mdstack     MDSTACK_HOME \
        pdf4tcllib  PDF4TCLLIB_HOME]
    set repoSubdir [dict create \
        docir       {lib tm} \
        mdstack     {lib} \
        pdf4tcllib  {lib}]
    set repoMarker [dict create \
        docir       docir-0.1.tm \
        mdstack     mdstack-0.1.tm \
        pdf4tcllib  pdf4tcllib-0.2.tm]

    foreach repo {docir mdstack pdf4tcllib} {
        set envVar [dict get $repoEnv $repo]
        if {![info exists ::env($envVar)] || $::env($envVar) eq ""} {
            fail "Umgebungsvariable $envVar nicht gesetzt.\n  Beispiel: export $envVar=/pfad/zum/${repo}-repo"
        }
        set base $::env($envVar)
        # Probiere zwei Layouts: $BASE selbst (wenn schon Modul-Pfad)
        # oder $BASE/lib/tm bzw. $BASE/lib (wenn ganzes Repo).
        set marker [dict get $repoMarker $repo]
        set found ""
        foreach try [list $base [file join $base {*}[dict get $repoSubdir $repo]]] {
            if {[file exists [file join $try $marker]]} {
                set found $try
                break
            }
        }
        if {$found eq ""} {
            fail "$envVar=$base zeigt nicht auf $repo — $marker nicht gefunden"
        }
        foreach f [glob -nocomplain -directory $found *.tm] {
            file copy -force $f [file join $vfsDir apptm [file tail $f]]
        }
        # Sub-Verzeichnis (z.B. docir/, mdstack/) auch mitkopieren
        set subdir [file join $found [file tail [string trimright $found /]]]
        # Fuer docir/mdstack: <found>/docir/ bzw. <found>/mdstack/
        set ns ""
        switch -- $repo {
            docir   { set ns docir }
            mdstack { set ns mdstack }
        }
        if {$ns ne "" && [file isdirectory [file join $found $ns]]} {
            file mkdir [file join $vfsDir apptm $ns]
            foreach f [glob -nocomplain -directory [file join $found $ns] *.tm] {
                file copy -force $f [file join $vfsDir apptm $ns [file tail $f]]
            }
        }
    }

    # --- Tcl 8.6 -> 8.6- Patch fuer Tcl 9 Kompatibilitaet ---
    foreach dir [list [file join $vfsDir applib] [file join $vfsDir apptm] $vfsDir] {
        patchFiles $dir \
            "package require Tk 8.6\n"  "package require Tk 8.6-\n" \
            "package require Tk 8.6;"   "package require Tk 8.6-;" \
            "package require Tcl 8.6\n" "package require Tcl 8.6-\n" \
            "package require Tcl 8.6;"  "package require Tcl 8.6-;"
    }

    # --- pdf4tcl (klassisches Package mit pkgIndex.tcl) ---
    # Auch via ENV — PDF4TCL_HOME muss auf das Verzeichnis mit pkgIndex.tcl zeigen.
    if {[info exists ::env(PDF4TCL_HOME)] && $::env(PDF4TCL_HOME) ne ""} {
        set pkgSrc $::env(PDF4TCL_HOME)
        if {![file exists [file join $pkgSrc pkgIndex.tcl]]} {
            warn "PDF4TCL_HOME=$pkgSrc enthaelt keine pkgIndex.tcl — PDF-Export im Starpack wird fehlschlagen"
        } else {
            file mkdir [file join $vfsDir vendors pkg]
            copyDir $pkgSrc [file join $vfsDir vendors pkg [file tail $pkgSrc]]
        }
    } else {
        warn "PDF4TCL_HOME nicht gesetzt — PDF-Export im Starpack wird fehlschlagen"
    }

    # --- Dokumentation ---
    copyDir [file join $scriptDir docs] [file join $vfsDir docs]

    set n [countFiles $vfsDir]
    ok "VFS: $n Dateien in $vfsDir"
}

# ============================================================
# Starpack wrappen
# ============================================================

proc wrapStarpack {platform runtime output} {
    global buildDir runtimeDir tclkitLinux

    if {$runtime eq ""} {
        warn "Ueberspringe $platform (keine Runtime)"
        return
    }

    info "Wrappe $platform..."
    file mkdir [file dirname $output]

    # Runtime kopieren -- sdx kann keine Datei wrappen die gerade in use ist
    set rtCopy [file join $buildDir "runtime_[file tail $runtime]"]
    file copy -force $runtime $rtCopy

    set sdx [file join $runtimeDir sdx.kit]
    if {[catch {
        exec $tclkitLinux $sdx wrap $output \
            -vfs [file join $buildDir mdhelp.vfs] \
            -runtime $rtCopy
    } err]} {
        file delete -force $rtCopy
        fail "Wrap fehlgeschlagen ($platform): $err"
    }
    file delete -force $rtCopy

    if {![file exists $output]} {
        fail "Ausgabedatei nicht erzeugt: $output"
    }
    if {$platform eq "linux"} {
        file attributes $output -permissions 0755
    }
    set size [format "%.1f MB" [expr {[file size $output] / 1048576.0}]]
    ok "$platform: [file tail $output] ($size)"
}

# ============================================================
# Clean
# ============================================================

proc doClean {} {
    global vfsDir distDir buildDir
    catch {file delete -force $vfsDir}
    catch {file delete -force $distDir}
    foreach f [glob -nocomplain [file join $buildDir runtime_*]] {
        file delete -force $f
    }
    ok "Build-Artefakte geloescht."
}

# ============================================================
# Main
# ============================================================

set target [expr {$argc > 0 ? [lindex $argv 0] : "all"}]

if {$target eq "clean"} {
    doClean
    exit 0
}

if {$target ni {all linux windows}} {
    puts "Verwendung: tclsh build.tcl \[all|linux|windows|clean\]"
    exit 1
}

puts ""
puts "=========================================="
puts "  mdhelp 4 -- Build"
puts "=========================================="
puts ""

checkRuntimes
buildVfs

switch -- $target {
    all {
        wrapStarpack linux   $tclkitLinux   [file join $distDir mdhelp-linux-x86_64]
        wrapStarpack windows $tclkitWindows [file join $distDir mdhelp-windows-x86_64.exe]
    }
    linux   { wrapStarpack linux   $tclkitLinux   [file join $distDir mdhelp-linux-x86_64] }
    windows { wrapStarpack windows $tclkitWindows [file join $distDir mdhelp-windows-x86_64.exe] }
}

puts ""
ok "Fertig!"
if {[file isdirectory $distDir]} {
    foreach f [glob -nocomplain -directory $distDir *] {
        set size [format "%.1f MB" [expr {[file size $f] / 1048576.0}]]
        puts "  [file tail $f]  ($size)"
    }
}
