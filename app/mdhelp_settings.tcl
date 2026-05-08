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

    set data {}
    lappend data [list fontSize $fontSize]
    lappend data [list docsRoot $docsRoot]
    lappend data [list geometry [wm geometry .]]
    lappend data [list theme $theme]

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
                bookmarks  { set bookmarks $val }
                recentDirs { set recentDirs $val }
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

