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
#   - ../runtimes/sdx.kit
#   - ../runtimes/tclkit-*Linux*tk
#   - ../runtimes/tclkit-*Win*.exe   (optional, fuer Windows-Build)
#
#   Bibliotheken (docir, mdstack, pdf4tcllib, pdf4tcl) entweder
#   - in ../libs/<name>/ (gemeinsames libs-Verzeichnis neben mdhelp4)
#   - oder per Env-Variable als Override: DOCIR_HOME, MDSTACK_HOME,
#     PDF4TCLLIB_HOME, PDF4TCL_HOME

encoding system utf-8

# ============================================================
# Verzeichnisse
# ============================================================

set scriptDir  [file dirname [file normalize [info script]]]
set buildDir   [file join $scriptDir build]
set distDir    [file join $scriptDir dist]
set runtimeDir [file normalize [file join $scriptDir .. runtimes]]
set libsDir    [file normalize [file join $scriptDir .. libs]]
set vfsDir     [file join $buildDir  mdhelp.vfs]

# Welche Top-Level-Verzeichnisse von $scriptDir 1:1 ins VFS kopiert werden.
# Hier neue dazunehmen wenn die App weitere Asset-Verzeichnisse braucht.
set assetDirs {docs styles}

# ============================================================
# Ausgabe
# ============================================================

proc loginfo {msg}  { puts "==> $msg" }
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

# Repo-Pfad aufloesen — entweder ../libs/<name>/ oder via ENV-Override.
# Liefert das Wurzelverzeichnis das den marker enthaelt.
# subdir ist die Liste der Pfadkomponenten unterhalb von base wo die
# .tm-Dateien liegen (typisch {lib tm} fuer docir, {lib} fuer mdstack).
proc resolveRepo {repoName envVar marker subdir} {
    global libsDir

    # 1. ENV-Override (fuer CI / abweichende Setups)
    if {[info exists ::env($envVar)] && $::env($envVar) ne ""} {
        set base $::env($envVar)
        set source "\$$envVar"
    } else {
        # 2. Default: shared libs/<repoName>/
        set base [file join $libsDir $repoName]
        set source "libs/$repoName"
        if {![file isdirectory $base]} {
            fail "Bibliothek '$repoName' nicht gefunden.\n  Erwartet in shared libs: $base\n  Oder Env-Override: export $envVar=/pfad/zum/${repoName}-repo"
        }
    }

    # 3. Marker pruefen — probiere $base direkt oder $base/<subdir>.
    #    Der Marker darf ein Glob-Muster sein (z.B. pdf4tcllib-*.tm), damit
    #    Versions-Bumps den Build nicht brechen.
    foreach try [list $base [file join $base {*}$subdir]] {
        if {[llength [glob -nocomplain -directory $try $marker]] > 0} {
            ok "$repoName: $source"
            return $try
        }
    }
    fail "$repoName: $base zeigt nicht auf ein gueltiges Repo ($marker nicht gefunden)\n  Probiert: $base und $base/[join $subdir /]"
}

# pdf4tcl ist ein klassisches Package (pkgIndex.tcl statt .tm),
# braucht eigene Resolver-Logik.
proc resolvePdf4tcl {} {
    global libsDir

    if {[info exists ::env(PDF4TCL_HOME)] && $::env(PDF4TCL_HOME) ne ""} {
        set base $::env(PDF4TCL_HOME)
        set source "\$PDF4TCL_HOME"
    } else {
        set base [file join $libsDir pdf4tcl]
        set source "libs/pdf4tcl"
        if {![file isdirectory $base]} {
            return ""  ;# pdf4tcl ist optional — warn statt fail
        }
    }

    if {![file exists [file join $base pkgIndex.tcl]]} {
        warn "$source enthaelt keine pkgIndex.tcl — PDF-Export im Starpack wird fehlschlagen"
        return ""
    }
    ok "pdf4tcl: $source"
    return $base
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
    global scriptDir buildDir vfsDir assetDirs

    loginfo "Baue VFS..."
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
    # Alle .tcl aus app/ kopieren, ausser mdhelp.tcl (wird separat als
    # mdhelp_app.tcl behandelt).
    set appSrcDir [file join $scriptDir app]
    set copied 0
    foreach src [glob -nocomplain -directory $appSrcDir *.tcl] {
        set name [file tail $src]
        if {$name eq "mdhelp.tcl"} continue
        file copy -force $src [file join $vfsDir $name]
        incr copied
    }
    ok "App-Komponenten: $copied Datei(en) aus app/ kopiert"

    # --- Module ---
    # mdhelp-eigene Module (lib/tm/) -> applib/
    foreach f [glob -nocomplain -directory [file join $scriptDir lib tm] *.tm] {
        file copy -force $f [file join $vfsDir applib [file tail $f]]
    }

    # Externe Module (docir, mdstack, pdf4tcllib) -> apptm/
    # Quelle: ../libs/<name>/ (Default) oder ENV-Override.
    set repoSubdir [dict create \
        docir            {lib tm} \
        mdstack          {lib} \
        pdf4tcllib       {lib} \
        tcldocs-config   {lib tm} \
        tcldocs-launcher {lib tm}]
    set repoMarker [dict create \
        docir            docir-*.tm \
        mdstack          mdstack-*.tm \
        pdf4tcllib       pdf4tcllib-*.tm \
        tcldocs-config   tcldocs/config-*.tm \
        tcldocs-launcher tcldocs/launcher-*.tm]
    set repoEnv [dict create \
        docir            DOCIR_HOME \
        mdstack          MDSTACK_HOME \
        pdf4tcllib       PDF4TCLLIB_HOME \
        tcldocs-config   TCLDOCS_CONFIG_HOME \
        tcldocs-launcher TCLDOCS_LAUNCHER_HOME]

    foreach repo {docir mdstack pdf4tcllib tcldocs-config tcldocs-launcher} {
        set found [resolveRepo $repo \
            [dict get $repoEnv $repo] \
            [dict get $repoMarker $repo] \
            [dict get $repoSubdir $repo]]

        foreach f [glob -nocomplain -directory $found *.tm] {
            file copy -force $f [file join $vfsDir apptm [file tail $f]]
        }

        # Sub-Verzeichnis (z.B. docir/, mdstack/, tcldocs/) mitkopieren
        set ns ""
        switch -- $repo {
            docir            { set ns docir }
            mdstack          { set ns mdstack }
            tcldocs-config   { set ns tcldocs }
            tcldocs-launcher { set ns tcldocs }
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
    set pkgSrc [resolvePdf4tcl]
    if {$pkgSrc ne ""} {
        file mkdir [file join $vfsDir vendors pkg]
        copyDir $pkgSrc [file join $vfsDir vendors pkg [file tail $pkgSrc]]
    } else {
        warn "pdf4tcl nicht gefunden (weder libs/pdf4tcl noch PDF4TCL_HOME) -- PDF-Export im Starpack wird fehlschlagen"
    }

    # --- Statische Asset-Verzeichnisse (docs, styles, ...) ---
    foreach subdir $assetDirs {
        set src [file join $scriptDir $subdir]
        if {[file isdirectory $src]} {
            copyDir $src [file join $vfsDir $subdir]
            ok "Asset-Verzeichnis: $subdir kopiert"
        } else {
            warn "Asset-Verzeichnis $subdir nicht gefunden -- uebersprungen"
        }
    }

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

    loginfo "Wrappe $platform..."
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
