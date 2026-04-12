# mdhelp_pdf-0.3.tm
# (c) 2026 Gregor Ebbing -- MIT License (see ../../LICENSE)
#
# Native PDF-Export fuer mdstack 2.0 mit pdf4tcl
#
# Version 0.3: Umgestellt auf pdf4tcllib als Backend.
# mdhelp_pdf ist jetzt ein duenner Wrapper der die Widget-Extraktion
# uebernimmt und fuer das eigentliche PDF-Rendering an pdf4tcllib
# delegiert.
#
# Requirements:
#   Tcl 8.6+ (9.x compatible)
#   pdf4tcl
#   pdf4tcllib 0.1+ (fonts, unicode, text, table, image, page)
#
# Public API (unveraendert zu 0.2):
#   mdhelp_pdf::available
#   mdhelp_pdf::exportFromWidget $textWidget $outFile ?options?
#   mdhelp_pdf::exportFromFile $mdFile $outFile ?options?
#
# Optionen:
#   -title     ""       Titel oben auf erster Seite
#   -pagesize  A4       Seitengroesse (A4, Letter)
#   -landscape 0        Querformat (1 = Querformat)
#   -margin    50       Rand in Punkten
#   -fontsize  11       Basis-Schriftgroesse
#   -fontdir   ""       Verzeichnis mit TTF-Dateien (leer = auto)
#   -debug     0        Debug-Ausgaben


# vendors/tm Pfad hinzufuegen (pdf4tcllib)
set _vendorDir [file normalize [file join [file dirname [info script]] .. vendors tm]]
if {[file isdirectory $_vendorDir]} {
    tcl::tm::path add $_vendorDir
}
unset _vendorDir

package require pdf4tcl
package require pdf4tcllib 0.1

package provide mdhelp_pdf 0.3

namespace eval mdhelp_pdf {
    namespace export available exportFromWidget exportFromFile

    # Heading-Fontgroessen: Delta zur Basis-Fontgroesse
    variable headingDelta
    array set headingDelta {1 3  2 2  3 1  4 0  5 0  6 0}

    # Heading-Abstaende (in lineH-Einheiten)
    variable headingSpaceBefore
    variable headingSpaceAfter
    array set headingSpaceBefore {1 1.5  2 1.2  3 1.0  4 0.8  5 0.5  6 0.5}
    array set headingSpaceAfter  {1 0.5  2 0.4  3 0.3  4 0.2  5 0.2  6 0.2}
}

# ============================================================
# Verfuegbarkeitspruefung
# ============================================================

proc mdhelp_pdf::available {} {
    return 1
}

# ============================================================
# Export aus Text-Widget
# ============================================================

proc mdhelp_pdf::exportFromWidget {t outFile args} {
    # Optionen parsen
    array set opt {
        -title     ""
        -pagesize  A4
        -landscape 0
        -margin    50
        -fontsize  11
        -fontdir   ""
        -debug     0
    }
    array set opt $args

    # pdf4tcllib Fonts initialisieren
    pdf4tcllib::fonts::init -fontdir $opt(-fontdir)

    set fontSans     [pdf4tcllib::fonts::fontSans]
    set fontSansBold [pdf4tcllib::fonts::fontSansBold]
    set fontMono     [pdf4tcllib::fonts::fontMono]

    if {$opt(-debug)} {
        if {[pdf4tcllib::fonts::hasTtf]} {
            puts "PDF Export: TTF-Fonts aktiv ($fontSans, $fontSansBold)"
        } else {
            puts "PDF Export: Fallback-Fonts (Helvetica, Courier)"
        }
    }

    # Seitengroessen
    switch -exact -- $opt(-pagesize) {
        A4      { set pageW 595; set pageH 842 }
        Letter  { set pageW 612; set pageH 792 }
        default { set pageW 595; set pageH 842 }
    }
    if {$opt(-landscape)} {
        lassign [list $pageW $pageH] pageH pageW
    }

    set margin $opt(-margin)
    set fontSize $opt(-fontsize)
    set lineH [expr {int(ceil($fontSize * 1.4))}]

    set x0 $margin
    set x1 [expr {$pageW - $margin}]
    set yTop $margin
    set yBot [expr {$pageH - $margin - 30}]
    set maxW [expr {$x1 - $x0}]

    # Heading-Zeilen aus Widget-Tags ermitteln
    array set headingLines {}
    foreach level {1 2 3 4 5 6} {
        foreach {start end} [$t tag ranges h$level] {
            set lineNo [lindex [split $start .] 0]
            set headingLines($lineNo) $level
        }
    }

    # Heading-Fontgroessen
    variable headingDelta
    variable headingSpaceBefore
    variable headingSpaceAfter
    array set headingSize {}
    foreach {lvl delta} [array get headingDelta] {
        set headingSize($lvl) [expr {$fontSize + $delta}]
    }

    # Bilder im Text-Widget finden
    array set imagePositions {}
    array set seenImages {}

    # 1. Direkte Bilder im Text-Widget
    set allImgNames [$t image names]
    if {$opt(-debug)} {
        puts "PDF Export: Text-Widget hat [llength $allImgNames] Bild-Eintraege"
    }

    foreach imgName $allImgNames {
        if {[catch {set tkImg [$t image cget $imgName -image]} err]} {
            continue
        }
        if {$tkImg eq ""} { continue }
        if {[info exists seenImages($tkImg)]} { continue }
        set seenImages($tkImg) 1

        set idx [$t index $imgName]
        set lineNo [lindex [split $idx .] 0]
        if {![info exists imagePositions($lineNo)]} {
            set imagePositions($lineNo) {}
        }
        lappend imagePositions($lineNo) [list $imgName $tkImg]
    }

    # 2. Bilder in eingebetteten Fenstern (Tabellen) suchen
    foreach winName [$t window names] {
        set idx [$t index $winName]
        set lineNo [lindex [split $idx .] 0]

        set childImages [_findImagesInWidget $winName]
        foreach tkImg $childImages {
            if {$tkImg eq "" || [info exists seenImages($tkImg)]} { continue }
            set seenImages($tkImg) 1
            if {![info exists imagePositions($lineNo)]} {
                set imagePositions($lineNo) {}
            }
            lappend imagePositions($lineNo) [list "table_img" $tkImg]
        }
    }

    if {$opt(-debug)} {
        puts "PDF Export: [array size seenImages] Bilder gefunden (inkl. Tabellen)"
    }

    # 3. Frame-Tabellen finden (mdviewer -tablemode frame)
    array set frameTableLines {}
    foreach winName [$t window names] {
        if {![string match "*.tbl*" $winName]} continue
        if {![winfo exists $winName]} continue

        set idx [$t index $winName]
        set lineNo [lindex [split $idx .] 0]

        set tableData [_extractFrameTable $winName]
        if {$tableData ne ""} {
            set frameTableLines($lineNo) $tableData
            if {$opt(-debug)} {
                set nRows [llength [dict get $tableData rows]]
                set nCols [llength [dict get $tableData aligns]]
                puts "PDF Export: Frame-Tabelle in Zeile $lineNo: ${nCols}x${nRows}"
            }
        }
    }

    # PDF erstellen
    if {$opt(-landscape)} {
        set pdf [::pdf4tcl::new %AUTO% -paper $opt(-pagesize) -orient true -landscape true]
    } else {
        set pdf [::pdf4tcl::new %AUTO% -paper $opt(-pagesize) -orient true]
    }

    # Erste Seite
    $pdf startPage
    set pageNo 1
    set y $yTop

    # Titel
    if {$opt(-title) ne ""} {
        $pdf setFont $headingSize(1) $fontSansBold
        pdf4tcllib::unicode::safeText $pdf "$opt(-title)" -x $x0 -y $y
        set y [expr {$y + 2 * $lineH}]
    }

    # Text aus Widget holen
    set text [$t get 1.0 end-1c]
    set lines [split $text "\n"]

    if {$opt(-debug)} {
        puts "PDF Export: [llength $lines] Zeilen, Seite ${pageW}x${pageH}"
    }

    set currentFont $fontSans
    $pdf setFont $fontSize $fontSans

    set lineNo 1

    foreach line $lines {
        # Bilder in dieser Zeile? (aber nicht wenn Frame-Tabelle)
        if {[info exists imagePositions($lineNo)] && ![info exists frameTableLines($lineNo)]} {
            set imgList $imagePositions($lineNo)
            set numImages [llength $imgList]

            if {$numImages > 1} {
                set imgMaxW [expr {$maxW / $numImages - 10}]
                set xOffset $x0
                set maxImgH 0

                foreach imgInfo $imgList {
                    lassign $imgInfo imgName tkImg
                    set imgH [pdf4tcllib::image::insertAt $pdf $tkImg $xOffset y $imgMaxW $yTop $yBot pageNo $pageW $pageH $margin $fontSize $opt(-debug)]
                    if {$imgH > $maxImgH} { set maxImgH $imgH }
                    set xOffset [expr {$xOffset + $imgMaxW + 10}]
                }
                if {$maxImgH > 0} {
                    set y [expr {$y + $maxImgH + 10}]
                }
            } else {
                foreach imgInfo $imgList {
                    lassign $imgInfo imgName tkImg
                    pdf4tcllib::image::insert $pdf $tkImg $x0 y $maxW $yTop $yBot pageNo $pageW $pageH $margin $fontSize $opt(-debug)
                }
            }
        }

        # Frame-Tabelle? -> Delegiert an pdf4tcllib::table (dict-Format)
        if {[info exists frameTableLines($lineNo)]} {
            pdf4tcllib::table::render $pdf $frameTableLines($lineNo) \
                $x0 y $maxW $yTop $yBot pageNo \
                $pageW $pageH $margin $fontSize $lineH $opt(-debug)
            incr lineNo
            continue
        }

        # Font-Erkennung VOR Sanitize
        set isHeading [info exists headingLines($lineNo)]
        if {!$isHeading} {
            set useFont [pdf4tcllib::text::detectFont $line]
            if {$useFont ne $currentFont} {
                set currentFont $useFont
                $pdf setFont $fontSize $currentFont
            }
        }

        # Unicode-Zeichen ersetzen/filtern
        set isMono [expr {$currentFont eq $fontMono}]
        set line [pdf4tcllib::unicode::sanitize $line -mono $isMono]

        # Heading?
        if {$isHeading} {
            set hlevel $headingLines($lineNo)
            set hSize $headingSize($hlevel)
            set hLineH [expr {int(ceil($hSize * 1.4))}]

            if {$y > [expr {$yTop + $lineH}]} {
                set y [expr {$y + int($headingSpaceBefore($hlevel) * $lineH)}]
            }

            if {($y + $hLineH + $lineH) > $yBot} {
                _writeFooter $pdf $pageNo $pageW $pageH $margin $fontSize
                $pdf endPage
                incr pageNo
                $pdf startPage
                set y $yTop
            }

            $pdf setFont $hSize $fontSansBold
            set wrapped [pdf4tcllib::text::wrap $line $maxW $hSize $fontSansBold]
            foreach wline $wrapped {
                pdf4tcllib::unicode::safeText $pdf "$wline" -x $x0 -y $y
                set y [expr {$y + $hLineH}]
            }

            set y [expr {$y + int($headingSpaceAfter($hlevel) * $lineH)}]
            $pdf setFont $fontSize $currentFont
        } else {
            # Code-Continuation fuer Monospace
            set isCode [expr {$currentFont eq $fontMono}]
            set line [pdf4tcllib::text::expandTabs $line 8]
            set wrapped [pdf4tcllib::text::wrap $line $maxW $fontSize $currentFont $isCode]
            foreach wline $wrapped {
                if {$y > $yBot} {
                    _writeFooter $pdf $pageNo $pageW $pageH $margin $fontSize
                    $pdf endPage
                    incr pageNo
                    $pdf startPage
                    $pdf setFont $fontSize $currentFont
                    set y $yTop
                }
                pdf4tcllib::unicode::safeText $pdf "$wline" -x $x0 -y $y
                set y [expr {$y + $lineH}]
            }
        }

        incr lineNo
    }

    _writeFooter $pdf $pageNo $pageW $pageH $margin $fontSize
    $pdf endPage

    $pdf write -file $outFile
    $pdf destroy

    if {$opt(-debug)} {
        puts "PDF Export: $pageNo Seiten geschrieben nach $outFile"
    }

    return $pageNo
}

# ============================================================
# Export direkt aus Markdown-Datei
# ============================================================

proc mdhelp_pdf::exportFromFile {mdFile outFile args} {
    if {![file exists $mdFile]} {
        error "Datei nicht gefunden: $mdFile"
    }

    array set opt {
        -title     ""
        -pagesize  A4
        -landscape 0
        -margin    50
        -fontsize  11
        -fontdir   ""
        -debug     0
    }
    array set opt $args

    pdf4tcllib::fonts::init -fontdir $opt(-fontdir)

    set fontSans     [pdf4tcllib::fonts::fontSans]
    set fontSansBold [pdf4tcllib::fonts::fontSansBold]
    set fontMono     [pdf4tcllib::fonts::fontMono]

    if {$opt(-title) eq ""} {
        set opt(-title) [file rootname [file tail $mdFile]]
    }

    set fd [open $mdFile r]
    fconfigure $fd -encoding utf-8
    set content [read $fd]
    close $fd

    switch -exact -- $opt(-pagesize) {
        A4      { set pageW 595; set pageH 842 }
        Letter  { set pageW 612; set pageH 792 }
        default { set pageW 595; set pageH 842 }
    }

    if {$opt(-landscape)} {
        lassign [list $pageW $pageH] pageH pageW
    }

    set margin $opt(-margin)
    set fontSize $opt(-fontsize)
    set lineH [expr {int(ceil($fontSize * 1.4))}]

    set x0 $margin
    set yTop $margin
    set yBot [expr {$pageH - $margin - 30}]
    set maxW [expr {$pageW - 2 * $margin}]

    variable headingDelta
    variable headingSpaceBefore
    variable headingSpaceAfter
    array set headingSize {}
    foreach {lvl delta} [array get headingDelta] {
        set headingSize($lvl) [expr {$fontSize + $delta}]
    }

    if {$opt(-landscape)} {
        set pdf [::pdf4tcl::new %AUTO% -paper $opt(-pagesize) -orient true -landscape true]
    } else {
        set pdf [::pdf4tcl::new %AUTO% -paper $opt(-pagesize) -orient true]
    }

    $pdf startPage
    set pageNo 1
    set y $yTop

    if {$opt(-title) ne ""} {
        $pdf setFont $headingSize(1) $fontSansBold
        pdf4tcllib::unicode::safeText $pdf "$opt(-title)" -x $x0 -y $y
        set y [expr {$y + 2 * $lineH}]
    }

    set currentFont $fontSans
    $pdf setFont $fontSize $fontSans

    foreach line [split $content "\n"] {
        # Heading-Erkennung VOR Sanitize
        set isHeading 0
        set hlevel 0
        if {[regexp {^(#{1,6})\s+(.+)$} $line -> hashes htext]} {
            set hlevel [string length $hashes]
            set line $htext
            set isHeading 1
        } else {
            set useFont [pdf4tcllib::text::detectFont $line]
            if {$useFont ne $currentFont} {
                set currentFont $useFont
                $pdf setFont $fontSize $currentFont
            }
        }

        set isMono [expr {$currentFont eq $fontMono}]
        set line [pdf4tcllib::unicode::sanitize $line -mono $isMono]

        if {$isHeading} {
            set hSize $headingSize($hlevel)
            set hLineH [expr {int(ceil($hSize * 1.4))}]

            if {$y > [expr {$yTop + $lineH}]} {
                set y [expr {$y + int($headingSpaceBefore($hlevel) * $lineH)}]
            }

            if {($y + $hLineH + $lineH) > $yBot} {
                _writeFooter $pdf $pageNo $pageW $pageH $margin $fontSize
                $pdf endPage
                incr pageNo
                $pdf startPage
                set y $yTop
            }

            $pdf setFont $hSize $fontSansBold
            set wrapped [pdf4tcllib::text::wrap $line $maxW $hSize $fontSansBold]
            foreach wline $wrapped {
                pdf4tcllib::unicode::safeText $pdf "$wline" -x $x0 -y $y
                set y [expr {$y + $hLineH}]
            }

            set y [expr {$y + int($headingSpaceAfter($hlevel) * $lineH)}]
            $pdf setFont $fontSize $currentFont
        } else {
            set isCode [expr {$currentFont eq $fontMono}]
            set line [pdf4tcllib::text::expandTabs $line 8]
            set wrapped [pdf4tcllib::text::wrap $line $maxW $fontSize $currentFont $isCode]
            foreach wline $wrapped {
                if {$y > $yBot} {
                    _writeFooter $pdf $pageNo $pageW $pageH $margin $fontSize
                    $pdf endPage
                    incr pageNo
                    $pdf startPage
                    $pdf setFont $fontSize $currentFont
                    set y $yTop
                }
                pdf4tcllib::unicode::safeText $pdf "$wline" -x $x0 -y $y
                set y [expr {$y + $lineH}]
            }
        }
    }

    _writeFooter $pdf $pageNo $pageW $pageH $margin $fontSize
    $pdf endPage

    $pdf write -file $outFile
    $pdf destroy

    return $pageNo
}

# ============================================================
# Widget-spezifische Hilfsfunktionen (bleiben in mdhelp_pdf)
# ============================================================

proc mdhelp_pdf::_extractFrameTable {w} {
    # Extrahiert Tabellendaten aus einem Frame-Widget (grid-basiert).
    # Liefert dict: {header {..} rows {{..} {..}} aligns {..} cols N}
    if {![winfo exists $w]} { return "" }

    set slaves [grid slaves $w]
    if {[llength $slaves] == 0} { return "" }

    set maxRow -1
    set maxCol -1
    foreach s $slaves {
        set ginfo [grid info $s]
        set row -1; set col -1
        foreach {key val} $ginfo {
            if {$key eq "-row"}    { set row $val }
            if {$key eq "-column"} { set col $val }
        }
        if {$row > $maxRow} { set maxRow $row }
        if {$col > $maxCol} { set maxCol $col }
    }

    if {$maxRow < 0 || $maxCol < 0} { return "" }

    set cols [expr {$maxCol + 1}]

    array set cells {}
    array set cellAligns {}
    set hasHeader 0

    foreach s $slaves {
        set ginfo [grid info $s]
        set row -1; set col -1
        foreach {key val} $ginfo {
            if {$key eq "-row"}    { set row $val }
            if {$key eq "-column"} { set col $val }
        }
        if {$row < 0 || $col < 0} continue

        set text ""
        catch {set text [$s cget -text]}
        if {$text eq ""} {
            set img ""
            catch {set img [$s cget -image]}
            if {$img ne ""} { set text "(Bild)" }
        }
        set cells($row,$col) $text

        set anchor "w"
        catch {set anchor [$s cget -anchor]}
        switch -- $anchor {
            center { set cellAligns($col) center }
            e      { set cellAligns($col) right }
            default {
                if {![info exists cellAligns($col)]} {
                    set cellAligns($col) left
                }
            }
        }

        if {$row == 0} {
            set bg ""
            catch {set bg [$s cget -bg]}
            if {$bg ne "" && $bg ne "white" && $bg ne "#ffffff" && $bg ne "#f8f8f8"} {
                set hasHeader 1
            }
        }
    }

    set header {}
    if {$hasHeader} {
        for {set c 0} {$c < $cols} {incr c} {
            if {[info exists cells(0,$c)]} {
                lappend header $cells(0,$c)
            } else {
                lappend header ""
            }
        }
    }

    set startRow [expr {$hasHeader ? 1 : 0}]
    set rows {}
    for {set r $startRow} {$r <= $maxRow} {incr r} {
        set row {}
        for {set c 0} {$c < $cols} {incr c} {
            if {[info exists cells($r,$c)]} {
                lappend row $cells($r,$c)
            } else {
                lappend row ""
            }
        }
        lappend rows $row
    }

    set aligns {}
    for {set c 0} {$c < $cols} {incr c} {
        if {[info exists cellAligns($c)]} {
            lappend aligns $cellAligns($c)
        } else {
            lappend aligns left
        }
    }

    return [dict create header $header rows $rows aligns $aligns cols $cols]
}

proc mdhelp_pdf::_findImagesInWidget {w} {
    # Sucht rekursiv nach Tk-Images in einem Widget-Baum.
    set images {}
    if {![winfo exists $w]} { return {} }

    if {[winfo class $w] eq "Label"} {
        if {![catch {set img [$w cget -image]}]} {
            if {$img ne ""} { lappend images $img }
        }
    }

    foreach child [winfo children $w] {
        foreach img [_findImagesInWidget $child] {
            lappend images $img
        }
    }

    return $images
}

proc mdhelp_pdf::_writeFooter {pdf pageNo pageW pageH margin fontSize} {
    # Seitennummer rechts unten.
    set fontSans [pdf4tcllib::fonts::fontSans]
    set y [expr {$pageH - $margin * 0.5}]
    set x [expr {$pageW - $margin}]
    $pdf setFont [expr {$fontSize - 2}] $fontSans
    pdf4tcllib::unicode::safeText $pdf "- $pageNo -" -x $x -y $y -align right
}
