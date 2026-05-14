# mdhelp_settings.tcl -- Settings, Bookmarks, Recent Folders
#                        (Priority 12: extracted from mdhelp.tcl)
#
# Contains: saveSettings, loadSettings, applyGeometry,
#           addBookmark, removeBookmark, updateBookmarkMenu,
#           addRecentDir, updateRecentMenu, openRecentDir.
#
# Loaded from mdhelp.tcl via source.

if {![namespace exists ::app]} {
    error "mdhelp_settings.tcl must be loaded from mdhelp.tcl (namespace app missing)"
}

# Save/load settings
# ============================================================
proc app::saveSettings {} {
    variable settingsFile
    variable docsRoot
    variable fontSize
    variable theme
    variable tocSyncSuppressMs

    # Shared-Settings updaten (gleiche Werte wie unten in der eigenen
    # Datei, aber jede App liest beim Start beide).
    catch {
        ::tcldocs::setShared theme $theme
        ::tcldocs::setShared fontSize $fontSize
    }

    set data {}
    lappend data [list fontSize $fontSize]
    lappend data [list docsRoot $docsRoot]
    lappend data [list geometry [wm geometry .]]
    lappend data [list theme $theme]
    lappend data [list tocSyncSuppressMs $tocSyncSuppressMs]

    # Bookmarks
    variable bookmarks
    if {[info exists bookmarks]} {
        lappend data [list bookmarks $bookmarks]
    }

    # Recent folders
    variable recentDirs
    if {[llength $recentDirs] > 0} {
        lappend data [list recentDirs $recentDirs]
    }

    # Recent files (max 15)
    variable recentFiles
    if {[info exists recentFiles] && [llength $recentFiles] > 0} {
        lappend data [list recentFiles $recentFiles]
    }

    # Such-Historie (max je 15)
    if {[info exists ::app::searchHistory] && \
            [llength $::app::searchHistory] > 0} {
        lappend data [list searchHistory $::app::searchHistory]
    }
    if {[info exists ::app::replaceHistory] && \
            [llength $::app::replaceHistory] > 0} {
        lappend data [list replaceHistory $::app::replaceHistory]
    }

    # Scroll-Positionen pro Datei (max 200 Eintraege, neueste zuerst)
    variable scrollPos
    if {[info exists scrollPos] && [array size scrollPos] > 0} {
        set posList {}
        foreach k [array names scrollPos] {
            lappend posList [list $k $scrollPos($k)]
        }
        # Auf 200 begrenzen — Eintraege fuer Dateien die nicht mehr
        # existieren werden beim naechsten Save gefiltert.
        set posList [lrange $posList 0 199]
        lappend data [list filePos $posList]
    }

    if {[catch {
        set fh [open $settingsFile w]
        fconfigure $fh -encoding utf-8
        foreach item $data {
            puts $fh $item
        }
        close $fh
    } err]} {
        # Silent errors -- settings are not critical
    }
}

proc app::loadSettings {} {
    variable settingsFile
    variable fontSize
    variable docsRoot
    variable bookmarks
    variable recentDirs
    variable theme

    # Erst shared-Settings laden (~/.tcldocs.rc) — werden von eigenen
    # Settings ueberschrieben falls auch dort gesetzt.
    catch {
        set sharedTheme [::tcldocs::getShared theme ""]
        if {$sharedTheme ne ""} { set theme $sharedTheme }
        set sharedFs [::tcldocs::getShared fontSize ""]
        if {$sharedFs ne "" && [string is integer -strict $sharedFs] \
                && $sharedFs >= 8 && $sharedFs <= 24} {
            set fontSize $sharedFs
        }
    }

    if {![file exists $settingsFile]} return

    if {[catch {
        set fh [open $settingsFile r]
        fconfigure $fh -encoding utf-8
        while {[gets $fh line] >= 0} {
            set line [string trim $line]
            if {$line eq "" || [string index $line 0] eq "#"} continue
            set key [lindex $line 0]
            set val [lindex $line 1]
            switch -- $key {
                fontSize   {
                    if {[string is integer -strict $val] && $val >= 8 && $val <= 24} {
                        set fontSize $val
                    }
                }
                docsRoot   { set docsRoot $val }
                geometry   { variable savedGeometry $val }
                tocSyncSuppressMs {
                    if {[string is integer -strict $val] \
                            && $val >= 0 && $val <= 5000} {
                        variable tocSyncSuppressMs $val
                    }
                }
                bookmarks  { set bookmarks $val }
                recentDirs { set recentDirs $val }
                recentFiles {
                    variable recentFiles
                    set recentFiles {}
                    foreach f $val {
                        if {[file exists $f]} { lappend recentFiles $f }
                    }
                }
                searchHistory  { set ::app::searchHistory  $val }
                replaceHistory { set ::app::replaceHistory $val }
                filePos    {
                    variable scrollPos
                    foreach pair $val {
                        if {[llength $pair] == 2} {
                            lassign $pair f y
                            # Nur wenn Datei noch existiert
                            if {[file exists $f]} {
                                set scrollPos($f) $y
                            }
                        }
                    }
                }
                theme      {
                    if {$val in [mdstack::theme::names]} {
                        set theme $val
                        mdstack::theme::activate $val
                    }
                }
            }
        }
        close $fh
    } err]} {
        # Stille Fehler
    }
}

proc app::applyGeometry {} {
    # Fenstergroesse aus Einstellungen wiederherstellen.
    # Wird nach buildUI aufgerufen.
    variable savedGeometry
    if {[info exists savedGeometry] && $savedGeometry ne ""} {
        catch {wm geometry . $savedGeometry}
    }
}

# ============================================================
# Lesezeichen
# ============================================================
namespace eval app {
    variable bookmarks {}  ;# Liste von {file title}
}

proc app::addBookmark {} {
    variable currentFile
    variable bookmarks

    if {$currentFile eq ""} return

    # Schon vorhanden?
    foreach bm $bookmarks {
        if {[lindex $bm 0] eq $currentFile} {
            set ::app::statusText "Bookmark already exists"
            return
        }
    }

    set title [file rootname [file tail $currentFile]]
    lappend bookmarks [list $currentFile $title]
    app::updateBookmarkMenu
    app::saveSettings
    set ::app::statusText "Bookmark: $title"
}

proc app::removeBookmark {} {
    variable currentFile
    variable bookmarks

    set newList {}
    foreach bm $bookmarks {
        if {[lindex $bm 0] ne $currentFile} {
            lappend newList $bm
        }
    }
    set bookmarks $newList
    app::updateBookmarkMenu
    app::saveSettings
    set ::app::statusText "Bookmark removed"
}

proc app::updateBookmarkMenu {} {
    variable bookmarks

    # Delete dynamic entries (from index 3: after separator)
    set last [.menubar.bookmarks index end]
    if {$last ne "none" && $last >= 3} {
        for {set i $last} {$i >= 3} {incr i -1} {
            .menubar.bookmarks delete $i
        }
    }

    # Insert bookmarks
    foreach bm $bookmarks {
        lassign $bm file title
        .menubar.bookmarks add command -label $title \
            -command [list app::openFile $file 1]
    }
}

# ============================================================
# Recent Folders
# ============================================================
proc app::addRecentDir {dir} {
    variable recentDirs

    set dir [file normalize $dir]

    # Remove duplicate
    set newList {}
    foreach d $recentDirs {
        if {$d ne $dir} { lappend newList $d }
    }

    # Insert at front, max 10
    set recentDirs [lrange [linsert $newList 0 $dir] 0 9]
    app::updateRecentMenu
}

proc app::updateRecentMenu {} {
    variable recentDirs

    .menubar.file.recent delete 0 end

    if {[llength $recentDirs] == 0} {
        .menubar.file.recent add command -label "(empty)" -state disabled
        return
    }

    foreach dir $recentDirs {
        .menubar.file.recent add command -label $dir \
            -command [list app::openRecentDir $dir]
    }
}

proc app::openRecentDir {dir} {
    if {![file isdirectory $dir]} {
        set ::app::statusText "Directory not found: $dir"
        return
    }
    app::loadTree $dir
    app::goHome
}


# ============================================================
# Recent Files (max 15)
# ============================================================
namespace eval app {
    variable recentFiles {}
}

proc app::addRecentFile {file} {
    variable recentFiles
    set file [file normalize $file]

    # Duplikate raus
    set newList {}
    foreach f $recentFiles {
        if {$f ne $file} { lappend newList $f }
    }

    # Vorne einfuegen, max 15
    set recentFiles [lrange [linsert $newList 0 $file] 0 14]
    app::updateRecentFilesMenu
}

proc app::updateRecentFilesMenu {} {
    variable recentFiles
    if {![winfo exists .menubar.file.recentFiles]} return

    .menubar.file.recentFiles delete 0 end

    if {[llength $recentFiles] == 0} {
        .menubar.file.recentFiles add command -label "(empty)" -state disabled
        return
    }

    foreach f $recentFiles {
        # Dateinamen kuerzen, aber Pfad zeigen
        set tail [file tail $f]
        set dir  [file dirname $f]
        if {[string length $dir] > 40} {
            set dir "...[string range $dir end-37 end]"
        }
        set lbl "$tail   ($dir)"
        .menubar.file.recentFiles add command -label $lbl \
            -command [list app::openRecentFile $f]
    }
}

proc app::openRecentFile {file} {
    if {![file exists $file]} {
        set ::app::statusText "Datei nicht gefunden: $file"
        # Aus der Liste streichen
        variable recentFiles
        set recentFiles [lsearch -all -inline -not -exact $recentFiles $file]
        app::updateRecentFilesMenu
        return
    }
    # Falls die Datei in einem anderen docs-Ordner liegt: Tree neu laden
    set parent [file dirname $file]
    if {[file normalize $parent] ne [file normalize $::app::docsRoot]} {
        # heuristisch: nutze parent als docs-Root
        app::loadTree $parent
    }
    app::openFile $file 1
}
