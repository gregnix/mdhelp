#!/usr/bin/env tclsh9.0
# build.tcl -- mdhelp 5: eine ausfuehrbare Datei je Plattform (Tcl/Tk 9 zipfs)
#
#   tclsh9.0 build.tcl                    alle Plattformen, fuer die ein Kit da ist
#   tclsh9.0 build.tcl linux              nur Linux
#   tclsh9.0 build.tcl windows            nur Windows (.exe, auch unter Linux baubar)
#   tclsh9.0 build.tcl macos              macOS: Stage + Aufruf fuer app-bauen.sh
#                                         (auf dem Mac baut es mdhelp.app selbst)
#   tclsh9.0 build.tcl linux -kit DATEI   Kit ausdruecklich angeben
#   tclsh9.0 build.tcl stage linux        nur die Stage bauen, nicht packen
#   tclsh9.0 build.tcl clean
#
# Grundlage ist ein statisch gebautes wish 9 mit zipfs ("Zipkit", z. B. aus
# BAWT). zipfs mkimg ersetzt dessen angehaengtes ZIP durch die Stage; Tcl- und
# Tk-Bibliothek werden deshalb aus dem Kit in die Stage kopiert (Buch "Tcl
# ausliefern", Kapitel Zipkits). Kein sdx, kein Tclkit, kein Metakit.
#
# Eingaben (neben dem mdhelp-Verzeichnis, wie bisher):
#   ../runtimes/        die Kits (Linux, Windows); gefunden wird je Plattform
#                       die erste Datei, deren Name passt und die tk_library
#                       enthaelt:
#                         linux    *linux*   (ohne .exe)
#                         windows  *win*.exe
#                       Override: MDHELP_KIT_LINUX, MDHELP_KIT_WINDOWS oder
#                       -kit DATEI.
#                       macOS braucht kein Kit, sondern /opt/tcl9 (BAWT,
#                       umgehaengt) und app-bauen.sh (hier oder MDHELP_APPBAUEN).
#   ../libs/common/     reine Tcl-Bibliotheken je Repo: docir, mdstack,
#                       pdf4tcllib, pdf4tcl, tclutils, tkutils,
#                       tcldocs-config, tcldocs-launcher, man-viewer (optional),
#                       tablelist* (optional, braucht tkutils)
#                       Override je Repo: <NAME>_HOME (DOCIR_HOME, ...).
#   ../libs/<os>-tcl9.0/  binaere Pakete je Plattform (Img, imgtools,
#                       tclpdfium, ...); os = linux | windows | macos.
#                       Override: MDHELP_LIBS (Verzeichnis mit den <os>-Ordnern).
#   DejaVu-Schriften    fuer den PDF-Export auf jedem System:
#                       ../libs/common/fonts/ oder /usr/share/fonts/truetype/dejavu
#                       Override: MDHELP_FONTS.
#
# Ausgabe in dist/:
#   mdhelp-linux-x86_64   mdhelp-windows-x86_64.exe   mdhelp.app/ (nur auf dem Mac)
#
# Aufbau der Stage (= Inhalt der Datei, //zipfs:/app/...):
#   main.tcl              Einstieg: Suchpfade nur aus dem Bundle, dann app/mdhelp.tcl
#   tcl_library/ tk_library/   aus dem Kit
#   app/                  wie im Quellbaum
#   lib/tm/               mdhelp-eigene Module
#   lib/ext/              docir, mdstack, pdf4tcllib, tclutils, tkutils, tcldocs,
#                         nroffparser (nur .tm, keine Tests, Demos, nogit)
#   lib/pkg/pdf4tcl/      pdf4tcl (nur die Laufzeitdateien)
#   lib/bin/              binaere Pakete NUR dieser Plattform
#   lib/fonts/            DejaVu (pdf4tcllib sucht <modul>/../fonts)
#   docs/ styles/

package require Tcl 9.0-
encoding system utf-8

set scriptDir  [file dirname [file normalize [info script]]]
set buildDir   [file join $scriptDir build]
set distDir    [file join $scriptDir dist]
set runtimeDir [file normalize [file join $scriptDir .. runtimes]]
set libsBase   [file normalize [file join $scriptDir .. libs]]
if {[info exists env(MDHELP_LIBS)] && $env(MDHELP_LIBS) ne ""} {
    set libsBase [file normalize $env(MDHELP_LIBS)]
}
set libsCommon [file join $libsBase common]
set platforms  {linux windows macos}

proc loginfo {msg} { puts "==> $msg" }
proc ok   {msg}    { puts " OK $msg" }
proc warn {msg}    { puts "WRN $msg" }
proc fail {msg}    { puts stderr "FEHLER: $msg"; exit 1 }

# ------------------------------------------------------------
# Dateien kopieren (ohne Punktdateien: zipfs mkimg packt auch .git, .svn ...)
# ------------------------------------------------------------
proc copyTree {src dst {patterns *} {skipDirs {}}} {
    file mkdir $dst
    foreach e [glob -nocomplain -directory $src *] {
        set n [file tail $e]
        if {[string index $n 0] eq "."} continue
        if {[file isdirectory $e]} {
            if {$n in $skipDirs} continue
            copyTree $e [file join $dst $n] $patterns $skipDirs
        } else {
            set hit 0
            foreach p $patterns { if {[string match $p $n]} { set hit 1; break } }
            if {$hit} { file copy -force $e [file join $dst $n] }
        }
    }
}
proc countFiles {dir} {
    set n [llength [glob -nocomplain -directory $dir -type f *]]
    foreach d [glob -nocomplain -directory $dir -type d *] { incr n [countFiles $d] }
    return $n
}
proc dirSize {dir} {
    set s 0
    foreach f [glob -nocomplain -directory $dir -type f *] { incr s [file size $f] }
    foreach d [glob -nocomplain -directory $dir -type d *] { incr s [dirSize $d] }
    return $s
}
proc mb {bytes} { format "%.1f MB" [expr {$bytes / 1048576.0}] }

# ------------------------------------------------------------
# Bibliotheken finden: <NAME>_HOME, sonst libs/common/<repo>
# ------------------------------------------------------------
proc repoDir {repo envVar {optional 0}} {
    global libsCommon
    if {[info exists ::env($envVar)] && $::env($envVar) ne ""} {
        set d [file normalize $::env($envVar)]
        set src "\$$envVar"
    } else {
        set d [file join $libsCommon $repo]
        set src "libs/common/$repo"
    }
    if {![file isdirectory $d]} {
        if {$optional} { warn "$repo nicht gefunden ($src) -- uebersprungen"; return "" }
        fail "$repo nicht gefunden: $d\n  Erwartet in libs/common/$repo oder per $envVar=/pfad/zum/repo"
    }
    ok "$repo: $src"
    return $d
}

# Unterverzeichnis mit den .tm-Dateien (lib/tm, lib oder das Repo selbst)
proc tmRoot {repoDir marker} {
    foreach sub {{lib tm} lib {}} {
        set d [file join $repoDir {*}$sub]
        if {[llength [glob -nocomplain -directory $d $marker]] > 0} { return $d }
    }
    fail "$repoDir: $marker nicht gefunden (lib/tm, lib oder Wurzel)"
}

# ------------------------------------------------------------
# Kits
# ------------------------------------------------------------
proc kitValid {f} {
    if {![file isfile $f]} { return 0 }
    set mp //zipfs:/mdhelpkitprobe
    if {[catch {zipfs mount $f mdhelpkitprobe}]} { return 0 }
    set ok [expr {[file exists $mp/tcl_library/init.tcl] && [file exists $mp/tk_library/tk.tcl]}]
    catch {zipfs unmount mdhelpkitprobe}
    return $ok
}
proc findKit {plat} {
    global runtimeDir kitArg
    if {$kitArg ne ""} {
        if {![kitValid $kitArg]} { fail "-kit $kitArg ist kein wish-Zipkit (tcl_library/tk_library fehlt)" }
        return [file normalize $kitArg]
    }
    set var MDHELP_KIT_[string toupper $plat]
    if {[info exists ::env($var)] && $::env($var) ne ""} {
        if {![kitValid $::env($var)]} { fail "$var=$::env($var) ist kein wish-Zipkit" }
        return [file normalize $::env($var)]
    }
    switch -- $plat {
        linux   { set pats {*linux* *Linux*} }
        windows { set pats {*win*.exe *Win*.exe} }
    }
    foreach p $pats {
        foreach f [lsort [glob -nocomplain -directory $runtimeDir -type f $p]] {
            if {$plat ne "windows" && [string match *.exe $f]} continue
            if {[kitValid $f]} { return $f }
        }
    }
    return ""
}

# ------------------------------------------------------------
# main.tcl in der Stage
# ------------------------------------------------------------
set mainTcl {# main.tcl -- Einstieg der mdhelp-Einzeldatei (Tcl/Tk 9 zipfs)
#
# Tcl-9-Zipkits uebernehmen TCLLIBPATH und die *_TM_PATH-Variablen des
# Rechners, dazu den Installationspfad des Kits. Damit kein fremdes docir
# oder mdstack geladen wird, gelten hier nur Pfade aus dem Bundle: alles
# unter //zipfs:/ und -- im macOS-App-Buendel (AppMain.tcl startet diese
# Datei) -- alles unter MeinProg.app/Contents.
set ::mdhelp_bundled 1
set root [file dirname [file normalize [info script]]]

set inside [list //zipfs:/*]
set exe [file normalize [info nameofexecutable]]
if {[string match */Contents/MacOS/* $exe]} {
    lappend inside [file dirname [file dirname $exe]]/*
}
proc ::mdhelpInside {p patterns} {
    foreach pat $patterns { if {[string match $pat $p]} { return 1 } }
    return 0
}
set keep {}
foreach p $::auto_path {
    if {[::mdhelpInside $p $inside]} { lappend keep $p }
}
set ::auto_path [concat $keep [list [file join $root lib pkg] [file join $root lib bin]]]
foreach p [tcl::tm::path list] {
    if {![::mdhelpInside $p $inside]} { tcl::tm::path remove $p }
}
tcl::tm::path add [file join $root lib ext] [file join $root lib tm] [file join $root lib bin]

package require Tk 9.0-
set ::argv0 [info nameofexecutable]
source [file join $root app mdhelp.tcl]
}

# ------------------------------------------------------------
# Stage bauen
# ------------------------------------------------------------
proc buildStage {plat kit} {
    global scriptDir buildDir libsBase mainTcl
    set stage [file join $buildDir stage-$plat]
    loginfo "Stage $plat"
    file delete -force $stage      ;# siehe Buch: file copy in vorhandenes Verzeichnis
    file mkdir $stage

    # 1. Tcl- und Tk-Bibliothek aus dem Kit (mkimg ersetzt dessen ZIP).
    #    macOS: kein Kit, die Bibliotheken stecken in den BAWT-dylibs.
    if {$kit ne ""} {
        zipfs mount $kit mdhelpkit
        foreach lib {tcl_library tk_library} {
            file copy //zipfs:/mdhelpkit/$lib [file join $stage $lib]
        }
        zipfs unmount mdhelpkit
        ok "tcl_library, tk_library aus [file tail $kit]"
    }

    # 2. main.tcl
    set fh [open [file join $stage main.tcl] w]
    fconfigure $fh -encoding utf-8
    puts -nonewline $fh $mainTcl
    close $fh

    # 3. App, eigene Module, Doku, Styles
    copyTree [file join $scriptDir app] [file join $stage app] {*.tcl}
    copyTree [file join $scriptDir lib tm] [file join $stage lib tm] {*.tm}
    # mdhelp_search 0.1 ist ersetzt (mdhelp.tcl verlangt 0.2)
    file delete -force [file join $stage lib tm mdhelp_search-0.1.tm]
    foreach d {docs styles} {
        if {[file isdirectory [file join $scriptDir $d]]} {
            copyTree [file join $scriptDir $d] [file join $stage $d]
        }
    }

    # 4. Externe Module: nur .tm, ohne Tests/Demos/nogit
    set ext [file join $stage lib ext]
    file mkdir $ext
    foreach {repo env marker opt} {
        docir            DOCIR_HOME            docir-*.tm          0
        mdstack          MDSTACK_HOME          mdstack-*.tm        0
        pdf4tcllib       PDF4TCLLIB_HOME       pdf4tcllib-*.tm     0
        tclutils         TCLUTILS_HOME         tclutils-*.tm       1
        tkutils          TKUTILS_HOME          tkutils-*.tm        1
        tcldocs-config   TCLDOCS_CONFIG_HOME   tcldocs/config-*.tm 0
        tcldocs-launcher TCLDOCS_LAUNCHER_HOME tcldocs/launcher-*.tm 0
        man-viewer       MANVIEWER_HOME        nroffparser-*.tm    1
    } {
        set d [repoDir $repo $env $opt]
        if {$d eq ""} continue
        set tm [tmRoot $d $marker]
        if {$repo eq "man-viewer"} {
            # nur, was mdhelp fuer Manpages braucht
            foreach f [glob -nocomplain -directory $tm nroffparser-*.tm nroffrenderer-*.tm mvdebug-*.tm] {
                file copy -force $f $ext
            }
        } else {
            copyTree $tm $ext {*.tm} {tests demo demos nogit tmp out}
        }
    }

    # 5. pdf4tcl: nur die Laufzeitdateien
    set p4 [repoDir pdf4tcl PDF4TCL_HOME 1]
    if {$p4 ne "" && ![file exists [file join $p4 pkgIndex.tcl]] && [file exists [file join $p4 pkg pkgIndex.tcl]]} {
        set p4 [file join $p4 pkg]
    }
    if {$p4 ne ""} {
        set dst [file join $stage lib pkg pdf4tcl]
        file mkdir $dst
        foreach f {pkgIndex.tcl pdf4tcl.tcl stdmetrics.tcl stdkern.tcl glyph2uni.tcl licence.terms} {
            if {[file exists [file join $p4 $f]]} { file copy -force [file join $p4 $f] $dst }
        }
        if {[file isdirectory [file join $p4 bitmaps]]} {
            file copy -force [file join $p4 bitmaps] [file join $dst bitmaps]
        }
    } else {
        warn "ohne pdf4tcl: kein PDF-Export"
    }

    # 5b. Reine Tcl-Pakete mit pkgIndex.tcl, die tkutils braucht (Tablelist).
    #     Gesucht: <NAME>_HOME, libs/common/<name>*, sonst uebersprungen.
    foreach {name env} {tablelist TABLELIST_HOME} {
        set d ""
        if {[info exists ::env($env)] && $::env($env) ne ""} {
            set d [file normalize $::env($env)]
        } else {
            set d [lindex [lsort -decreasing -dictionary [glob -nocomplain -type d \
                -directory [file join $libsBase common] $name*]] 0]
        }
        if {$d eq "" || ![file exists [file join $d pkgIndex.tcl]]} {
            warn "$name nicht gefunden (libs/common/$name* oder $env) -- tkutils (Dialoge, Tooltips, Bildvorschau) fehlt dann"
            continue
        }
        copyTree $d [file join $stage lib pkg [file tail $d]] {*.tcl *.txt *.tm} {doc demos}
        ok "$name: [file tail $d]"
    }

    # 6. Binaere Pakete nur dieser Plattform
    set bin [file join $libsBase $plat-tcl9.0]
    if {[file isdirectory $bin]} {
        copyTree $bin [file join $stage lib bin] {*} {nogit}
        set nlib [llength [glob -nocomplain -directory [file join $stage lib bin] -type d *]]
        ok "lib/bin: $nlib Paket(e) aus [file tail $bin]"
    } else {
        warn "kein $bin -- ohne Img, imgtools, tclpdfium (Bildwerkzeug, JPEG, PDF-Vorschau)"
    }

    # 7. Schriften fuer den PDF-Export (Windows und macOS haben kein DejaVu)
    set fontSrc ""
    set cands [list [file join $libsBase common fonts] \
                    /usr/share/fonts/truetype/dejavu /usr/share/fonts/TTF]
    if {[info exists ::env(MDHELP_FONTS)] && $::env(MDHELP_FONTS) ne ""} {
        set cands [linsert $cands 0 $::env(MDHELP_FONTS)]
    }
    foreach c $cands {
        if {$c ne "" && [file exists [file join $c DejaVuSansCondensed.ttf]]} { set fontSrc $c; break }
    }
    if {$fontSrc ne ""} {
        set fdst [file join $stage lib fonts]
        file mkdir $fdst
        foreach f {DejaVuSansCondensed.ttf DejaVuSansCondensed-Bold.ttf
                   DejaVuSansCondensed-Oblique.ttf DejaVuSansCondensed-BoldOblique.ttf
                   DejaVuSansMono.ttf DejaVuSansMono-Bold.ttf DejaVuSans.ttf} {
            if {[file exists [file join $fontSrc $f]]} { file copy -force [file join $fontSrc $f] $fdst }
        }
        ok "lib/fonts: DejaVu aus $fontSrc"
    } else {
        warn "keine DejaVu-Schriften gefunden -- PDF-Export nutzt die Systemschriften (unter Windows/macOS: Ersatzzeichen)"
    }

    ok "Stage: [countFiles $stage] Dateien, [mb [dirSize $stage]]"
    return $stage
}

# ------------------------------------------------------------
# Packen
# ------------------------------------------------------------
proc wrap {plat kit stage} {
    global distDir buildDir scriptDir
    file mkdir $distDir
    switch -- $plat {
        linux   { set out [file join $distDir mdhelp-linux-x86_64] }
        windows { set out [file join $distDir mdhelp-windows-x86_64.exe] }
    }
    file delete -force $out
    zipfs mkimg $out $stage $stage "" $kit
    if {$plat ne "windows"} { file attributes $out -permissions 0755 }
    ok "$plat: [file tail $out] ([mb [file size $out]])"
}

# macOS: kein Zipkit. Ein Zipkit laesst sich nicht sauber signieren (das
# angehaengte ZIP liegt ausserhalb des Mach-O), und der Finder startet eine
# nackte Datei nicht als App (Buch "Tcl/Tk unter macOS", Kapitel "Programm
# als App weitergeben", gemessen 2026-10-19). Stattdessen das App-Buendel mit
# dem BAWT-wish9.0 aus /opt/tcl9: app-bauen.sh kopiert die Stage nach
# Resources/app, holt die Pakete und dylibs, schreibt AppMain.tcl und
# signiert ad hoc. build.tcl liefert die Stage und den Aufruf.
# Befehl zum Abschreiben: Argumente mit Leerzeichen in Anfuehrungszeichen
proc shellJoin {cmd} {
    set out {}
    foreach a $cmd {
        if {[string match "* *" $a]} { lappend out "\"$a\"" } else { lappend out $a }
    }
    return [join $out " "]
}
proc wrapMacos {stage} {
    global scriptDir distDir runtimeDir
    set icns [file join $scriptDir icons mdhelp.icns]
    set cmd [list zsh app-bauen.sh -n mdhelp -d $stage -m main.tcl \
        -p "Img imgtools" -b de.gregnix.mdhelp -v 5.0 -o $distDir -t "md markdown txt"]
    if {[file exists $icns]} { lappend cmd -i $icns }
    set script ""
    set cands [list [file join $runtimeDir app-bauen.sh]]
    if {[info exists ::env(MDHELP_APPBAUEN)] && $::env(MDHELP_APPBAUEN) ne ""} {
        set cands [linsert $cands 0 $::env(MDHELP_APPBAUEN)]
    }
    foreach c $cands {
        if {[file exists $c]} { set script $c; break }
    }
    if {$::tcl_platform(os) eq "Darwin" && $script ne ""} {
        file mkdir $distDir
        file delete -force [file join $distDir mdhelp.app]
        set cmd [lreplace $cmd 1 1 $script]
        loginfo "macos: [shellJoin $cmd]"
        exec {*}$cmd >@ stdout 2>@ stderr
        ok "macos: [file join $distDir mdhelp.app]"
        return
    }
    warn "macos: Stage fertig in $stage"
    warn "macos: auf dem Mac (mit umgehaengtem /opt/tcl9, Buch macOS Kap. 105) ausfuehren:"
    warn "       [shellJoin $cmd]"
    warn "       app-bauen.sh liegt im Buch macOS unter beispiele/; nach ../runtimes/ kopieren"
    warn "       oder MDHELP_APPBAUEN setzen, dann baut 'build.tcl macos' das Buendel selbst."
}

# ------------------------------------------------------------
# Hauptprogramm
# ------------------------------------------------------------
set kitArg ""
set args {}
for {set i 0} {$i < $argc} {incr i} {
    set a [lindex $argv $i]
    if {$a eq "-kit"} { set kitArg [lindex $argv [incr i]] } else { lappend args $a }
}
set stageOnly 0
if {[lindex $args 0] eq "stage"} { set stageOnly 1; set args [lrange $args 1 end] }
set target [lindex $args 0]
if {$target eq ""} { set target all }

if {$target eq "clean"} {
    foreach d [glob -nocomplain -directory $buildDir stage-*] { file delete -force $d }
    file delete -force $distDir [file join $buildDir mdhelp.vfs]
    ok "build/stage-*, dist/ geloescht"
    exit 0
}
if {$target ni [list all {*}$platforms]} {
    puts stderr "Aufruf: tclsh9.0 build.tcl ?stage? ?all|linux|windows|macos|clean? ?-kit DATEI?"
    exit 2
}
if {$kitArg ne "" && $target eq "all"} { fail "-kit nur zusammen mit einer Plattform" }

puts "\n  mdhelp 5 -- Build (Tcl [info patchlevel], zipfs)\n"
set todo [list $target]
if {$target eq "all"} { set todo $platforms }
set built 0
foreach plat $todo {
    if {$plat eq "macos"} {
        set stage [buildStage macos ""]
        if {!$stageOnly} { wrapMacos $stage }
        incr built
        continue
    }
    set kit [findKit $plat]
    if {$kit eq ""} {
        if {$target eq "all"} { warn "$plat: kein Kit in $runtimeDir -- uebersprungen"; continue }
        fail "$plat: kein wish-Zipkit gefunden in $runtimeDir (oder -kit / MDHELP_KIT_[string toupper $plat])"
    }
    ok "$plat: Kit [file tail $kit]"
    set stage [buildStage $plat $kit]
    if {!$stageOnly} { wrap $plat $kit $stage }
    incr built
}
if {$built == 0} { fail "nichts gebaut: keine Kits in $runtimeDir" }
puts ""
ok "Fertig."
