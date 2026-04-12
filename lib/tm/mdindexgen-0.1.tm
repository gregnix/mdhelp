# mdindexgen-0.1.tm
#
# Generates index.md and indexsub.md for Markdown directory trees.
# Uses managed blocks (HTML comments) to update generated sections
# on subsequent runs, without destroying manual content.
#
# Public API:
#   mdindexgen::scan $dir ?-verbose 0? ?-dryrun 0?
#       Recursive: generate/update index.md + indexsub.md
#       -verbose 1: Print changes to stdout
#       -dryrun 1:  Check only, write nothing
#       Returns: dict with keys "updated", "unchanged", "created"
#
#   mdindexgen::updateIndex $dir ?-dryrun 0?
#       Only update index.md in directory
#
#   mdindexgen::updateSub $dir ?-dryrun 0?
#       Only update indexsub.md in directory
#
#   mdindexgen::readTitle $file
#       Read title from .md (YAML frontmatter or first H1, fallback: filename)
#
#   mdindexgen::readDescription $file
#       Read first non-empty paragraph after title (max 200 characters)
#
#   mdindexgen::configure ?-key value ...?
#       Change configuration:
#       -skip_files   {index.md indexsub.md}  Files to skip
#       -skip_dirs    {build dist .git ...}   Directories to skip
#       -descriptions 0/1                     Show short description in index
#       -sort         name/title              Sort order: filename or title
#       -autocreate   0/1                     Auto-create index.md for dirs without
#
# Managed Blocks:
#   <!-- mdindexgen:begin -->
#   ... generated content ...
#   <!-- mdindexgen:end -->
#
#   If the file already exists with manual content before/after the blocks,
#   it is preserved. Only the block content is replaced.
#
# Example:
#   package require mdindexgen 0.1
#   mdindexgen::scan /path/to/docs -verbose 1
#   mdindexgen::scan /path/to/docs -dryrun 1 -verbose 1

package provide mdindexgen 0.1

namespace eval mdindexgen {
    namespace export scan updateIndex updateSub readTitle readDescription configure

    variable BEGIN "<!-- mdindexgen:begin -->"
    variable END   "<!-- mdindexgen:end -->"

    # Files to skip during index generation
    variable SKIP_FILES {index.md indexsub.md}

    # Directories to skip during recursive search
    variable SKIP_DIRS {
        build dist .git .svn .hg __pycache__
        node_modules vendor vendors
    }

    # Optional features
    variable DESCRIPTIONS 0     ;# Show short description
    variable SORT         "name" ;# name or title
    variable AUTOCREATE   0     ;# Auto-create index.md
}

# ── Configuration ────────────────────────────────────────

proc mdindexgen::configure {args} {
    # Change configuration.
    #
    # Options:
    #   -skip_files   {index.md indexsub.md}
    #   -skip_dirs    {build dist .git ...}
    #   -descriptions 0/1
    #   -sort         name/title
    #   -autocreate   0/1
    #
    # Without arguments: return current configuration as dict.

    variable SKIP_FILES
    variable SKIP_DIRS
    variable DESCRIPTIONS
    variable SORT
    variable AUTOCREATE

    if {[llength $args] == 0} {
        return [dict create \
            -skip_files   $SKIP_FILES \
            -skip_dirs    $SKIP_DIRS \
            -descriptions $DESCRIPTIONS \
            -sort         $SORT \
            -autocreate   $AUTOCREATE]
    }

    foreach {key val} $args {
        switch -- $key {
            -skip_files   { set SKIP_FILES $val }
            -skip_dirs    { set SKIP_DIRS $val }
            -descriptions { set DESCRIPTIONS [expr {!!$val}] }
            -sort         {
                if {$val ni {name title}} {
                    error "mdindexgen::configure -sort: '$val'\
                           (allowed: name, title)"
                }
                set SORT $val
            }
            -autocreate   { set AUTOCREATE [expr {!!$val}] }
            default {
                error "mdindexgen::configure: Unknown option '$key'\
                       (allowed: -skip_files, -skip_dirs, -descriptions,\
                       -sort, -autocreate)"
            }
        }
    }
}

# ── File Helpers ──────────────────────────────────────────

proc mdindexgen::_stripBom {text} {
    # Removes UTF-8 BOM (EF BB BF) at file start.
    if {[string range $text 0 0] eq "\uFEFF"} {
        return [string range $text 1 end]
    }
    return $text
}

proc mdindexgen::_readFile {file} {
    set fh [open $file r]
    fconfigure $fh -encoding utf-8
    set data [read $fh]
    close $fh
    return [_stripBom $data]
}

proc mdindexgen::_writeFile {file text} {
    set fh [open $file w]
    fconfigure $fh -encoding utf-8
    puts -nonewline $fh $text
    close $fh
}

# ── Public Helpers ──────────────────────────────────

proc mdindexgen::readTitle {file} {
    # Reads title from a Markdown file.
    #
    # Order:
    #   1. YAML frontmatter: title: ...
    #   2. First H1: # ...
    #   3. Fallback index.md: directory name
    #   4. Fallback others: filename without extension
    #
    # BOM is automatically removed.

    set fh [open $file r]
    fconfigure $fh -encoding utf-8

    set title ""
    set in_frontmatter 0
    set line_no 0
    set first_line 1

    while {[gets $fh line] >= 0} {
        incr line_no

        # Remove BOM in first line
        if {$first_line} {
            set line [_stripBom $line]
            set first_line 0
        }

        # Frontmatter start (must be first line)
        if {$line_no == 1 && [string trim $line] eq "---"} {
            set in_frontmatter 1
            continue
        }

        # Frontmatter end
        if {$in_frontmatter && [string trim $line] eq "---"} {
            set in_frontmatter 0
            continue
        }

        # title: in frontmatter
        if {$in_frontmatter} {
            if {[regexp {^title:\s*(.+)} $line -> t]} {
                set title [string trim $t "\"' "]
                break
            }
            continue
        }

        # H1 heading (first match)
        if {[regexp {^#\s+(.*)} $line -> t]} {
            set title [string trim $t]
            break
        }

        # Give up after 30 lines
        if {$line_no > 30} break
    }

    close $fh

    if {$title eq ""} {
        # For index.md: directory name as fallback (not "index")
        set basename [file tail $file]
        if {[string tolower $basename] eq "index.md"} {
            set title [file tail [file dirname [file normalize $file]]]
        } else {
            set title [file rootname $basename]
        }
    }
    return $title
}

proc mdindexgen::readDescription {file} {
    # Reads first non-empty paragraph after title.
    # Returns max 200 characters, truncated with ...
    # Empty string if no description found.

    set fh [open $file r]
    fconfigure $fh -encoding utf-8

    set found_title 0
    set in_frontmatter 0
    set desc_lines {}
    set line_no 0
    set first_line 1

    while {[gets $fh line] >= 0} {
        incr line_no

        if {$first_line} {
            set line [_stripBom $line]
            set first_line 0
        }

        # Skip frontmatter
        if {$line_no == 1 && [string trim $line] eq "---"} {
            set in_frontmatter 1
            continue
        }
        if {$in_frontmatter} {
            if {[string trim $line] eq "---"} {
                set in_frontmatter 0
            }
            continue
        }

        # Skip title (H1)
        if {!$found_title && [regexp {^#\s+} $line]} {
            set found_title 1
            continue
        }

        # After title: skip empty lines
        if {$found_title && [string trim $line] eq ""} {
            # If we already have description lines -> end
            if {[llength $desc_lines] > 0} break
            continue
        }

        # Collect description text (no headings, no lists, no code)
        if {$found_title} {
            if {[regexp {^[#\-\*\|`>]} $line]} break
            lappend desc_lines [string trim $line]
            if {[llength $desc_lines] >= 3} break
        }

        if {$line_no > 40} break
    }

    close $fh

    if {[llength $desc_lines] == 0} {
        return ""
    }

    set desc [join $desc_lines " "]
    if {[string length $desc] > 200} {
        set desc "[string range $desc 0 196]..."
    }
    return $desc
}

# ── Internal Helpers ────────────────────────────────────────

proc mdindexgen::_listMarkdownFiles {dir} {
    variable SKIP_FILES
    set files {}
    foreach f [glob -nocomplain -directory $dir *.md] {
        set name [file tail $f]
        if {$name in $SKIP_FILES} continue
        lappend files $f
    }
    return [lsort -dictionary $files]
}

proc mdindexgen::_listSubDirs {dir} {
    variable SKIP_DIRS
    set dirs {}
    foreach d [glob -nocomplain -directory $dir *] {
        if {![file isdirectory $d]} continue
        set name [file tail $d]
        if {$name in $SKIP_DIRS} continue
        # Skip hidden directories
        if {[string index $name 0] eq "."} continue
        lappend dirs $d
    }
    return [lsort -dictionary $dirs]
}

proc mdindexgen::_sortEntries {entries} {
    # Sorts {filename title ?desc?} lists.
    # According to SORT setting: name (filename) or title.
    variable SORT

    if {$SORT eq "title"} {
        return [lsort -dictionary -index 1 $entries]
    }
    return [lsort -dictionary -index 0 $entries]
}

proc mdindexgen::_buildBlock {content} {
    # Baut den managed Block mit BEGIN/END-Markern.
    variable BEGIN
    variable END
    return "$BEGIN\n$content\n$END"
}

proc mdindexgen::_replaceBlock {text block} {
    # Replaces managed block in text.
    # Safe against regsub special characters (& \1 etc.).
    variable BEGIN
    variable END

    set idx_begin [string first $BEGIN $text]
    set idx_end   [string first $END $text]

    if {$idx_begin < 0 || $idx_end < 0} {
        return ""  ;# no block found
    }

    set before [string range $text 0 [expr {$idx_begin - 1}]]
    set after  [string range $text [expr {$idx_end + [string length $END]}] end]

    return "${before}${block}${after}"
}

proc mdindexgen::_updateBlock {file content args} {
    # Ersetzt den managed Block in $file, oder haengt ihn an.
    #
    # Optionen:
    #   -dryrun 0/1  Nur pruefen, nicht schreiben
    #
    # Rueckgabe: "created", "updated", "unchanged"

    variable BEGIN
    variable END

    array set opts {-dryrun 0}
    array set opts $args

    set block [_buildBlock $content]

    if {[file exists $file]} {
        set text [_readFile $file]
        set old_text $text

        if {[string match "*$BEGIN*$END*" $text]} {
            # String-based replacement (safe against & \1 etc.)
            set new_text [_replaceBlock $text $block]
            if {$new_text ne ""} {
                set text $new_text
            }
        } else {
            append text "\n\n$block\n"
        }

        if {$text eq $old_text} {
            return "unchanged"
        }

        if {!$opts(-dryrun)} {
            _writeFile $file $text
        }
        return "updated"
    } else {
        if {!$opts(-dryrun)} {
            _writeFile $file "$block\n"
        }
        return "created"
    }
}

# ── Public API ─────────────────────────────────────

proc mdindexgen::updateIndex {dir args} {
    # Creates/updates index.md in specified directory.
    # Lists all .md files (except skip_files) with title.
    # Optional with short description (-descriptions 1).
    # Links to indexsub.md if subdirectories exist.
    #
    # Options: -dryrun 0/1
    # Returns: Dict {file $path status $status}

    variable DESCRIPTIONS

    array set opts {-dryrun 0}
    array set opts $args

    set files [_listMarkdownFiles $dir]
    if {[llength $files] == 0 && [llength [_listSubDirs $dir]] == 0} {
        return [dict create file "" status ""]
    }

    # Collect entries: {filename title description}
    set entries {}
    foreach f $files {
        set title [readTitle $f]
        set name  [file tail $f]
        set desc  ""
        if {$DESCRIPTIONS} {
            set desc [readDescription $f]
        }
        lappend entries [list $name $title $desc]
    }

    # Sort
    set entries [_sortEntries $entries]

    set lines {}
    lappend lines "## Contents\n"

    foreach entry $entries {
        lassign $entry name title desc
        if {$desc ne ""} {
            lappend lines [format { - [%s](%s) -- %s} $title $name $desc]
        } else {
            lappend lines [format { - [%s](%s)} $title $name]
        }
    }

    # Reference to subdirectory index (only if subdirs exist)
    set subdirs [_listSubDirs $dir]
    if {[llength $subdirs] > 0} {
        lappend lines ""
        lappend lines "---"
        lappend lines ""
        lappend lines "## Subdirectories"
        lappend lines ""
        lappend lines {See [Subdirectories](indexsub.md).}
    }

    set outfile [file join $dir index.md]
    set status [_updateBlock $outfile [join $lines "\n"] -dryrun $opts(-dryrun)]
    return [dict create file $outfile status $status]
}

proc mdindexgen::updateSub {dir args} {
    # Creates/updates indexsub.md in specified directory.
    # Lists all subdirectories containing .md files.
    # Shows title from respective index.md (or folder name).
    # Optional with short description (-descriptions 1).
    #
    # With -autocreate 1: Creates missing index.md in subdirs.
    #
    # Options: -dryrun 0/1
    # Returns: Dict {file $path status $status autocreated {}}

    variable DESCRIPTIONS
    variable AUTOCREATE

    array set opts {-dryrun 0}
    array set opts $args

    set entries {}
    set autocreated {}

    foreach d [_listSubDirs $dir] {
        set idx [file join $d index.md]
        set name [file tail $d]

        if {[file exists $idx]} {
            # index.md present -> title from it
            set title [readTitle $idx]
            set desc ""
            if {$DESCRIPTIONS} {
                set desc [readDescription $idx]
            }
            lappend entries [list $name $title $desc]
        } elseif {$AUTOCREATE} {
            # Check if directory has .md files
            set mdfiles [glob -nocomplain -directory $d *.md]
            if {[llength $mdfiles] > 0} {
                # Auto-create index.md
                set title $name
                if {!$opts(-dryrun)} {
                    _writeFile $idx "# $name\n"
                }
                lappend autocreated $idx
                lappend entries [list $name $title ""]
            }
        }
    }

    if {[llength $entries] == 0} {
        return [dict create file "" status "" autocreated {}]
    }

    # Sort
    set entries [_sortEntries $entries]

    set lines {}
    foreach entry $entries {
        lassign $entry name title desc
        if {$desc ne ""} {
            lappend lines [format { - [%s](%s/index.md) -- %s} $title $name $desc]
        } else {
            lappend lines [format { - [%s](%s/index.md)} $title $name]
        }
    }

    set outfile [file join $dir indexsub.md]
    set status [_updateBlock $outfile [join $lines "\n"] -dryrun $opts(-dryrun)]
    return [dict create file $outfile status $status autocreated $autocreated]
}

proc mdindexgen::scan {dir args} {
    # Recursive: Creates index.md and indexsub.md for $dir
    # and all subdirectories.
    #
    # Options:
    #   -verbose 0/1  Print changes to stdout
    #   -dryrun  0/1  Check only, write nothing
    #
    # Returns: dict with keys:
    #   created   {List of newly created files}
    #   updated   {List of updated files}
    #   unchanged {List of unchanged files}

    array set opts {-verbose 0 -dryrun 0}
    array set opts $args

    # Internal call: _depth tracks recursion depth
    set depth [expr {[info exists opts(-_depth)] ? $opts(-_depth) : 0}]

    set result [dict create created {} updated {} unchanged {}]

    set prefix ""
    if {$opts(-dryrun)} { set prefix "(dry-run) " }

    # indexsub.md first (so index.md can link to it)
    set r [updateSub $dir -dryrun $opts(-dryrun)]
    set status [dict get $r status]
    set file   [dict get $r file]
    if {$status ne ""} {
        dict lappend result $status $file
        if {$opts(-verbose) && $status ne "unchanged"} {
            puts "${prefix}${status}: $file"
        }
    }
    # Report auto-created index.md files
    foreach ac [dict get $r autocreated] {
        dict lappend result created $ac
        if {$opts(-verbose)} {
            puts "${prefix}autocreated: $ac"
        }
    }

    # index.md
    set r [updateIndex $dir -dryrun $opts(-dryrun)]
    set status [dict get $r status]
    set file   [dict get $r file]
    if {$status ne ""} {
        dict lappend result $status $file
        if {$opts(-verbose) && $status ne "unchanged"} {
            puts "${prefix}${status}: $file"
        }
    }

    # Recursion into subdirectories
    foreach d [_listSubDirs $dir] {
        set sub [scan $d -verbose $opts(-verbose) -dryrun $opts(-dryrun) \
                     -_depth [expr {$depth + 1}]]
        foreach key {created updated unchanged} {
            dict lappend result $key {*}[dict get $sub $key]
        }
    }

    # Summary only at top level (depth == 0)
    if {$opts(-verbose) && $depth == 0} {
        set nc [llength [dict get $result created]]
        set nu [llength [dict get $result updated]]
        set nn [llength [dict get $result unchanged]]
        if {$nc + $nu + $nn > 0} {
            puts "${prefix}---"
            puts "${prefix}Result: $nc new, $nu updated, $nn unchanged"
        }
    }

    return $result
}
