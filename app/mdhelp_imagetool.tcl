# mdhelp_imagetool.tcl -- prepare an image for Markdown: open, crop (rubber-band
# on the preview or numeric x/y/w/h), resize (keep aspect), save as PNG and
# insert ![alt](path) into the active editor.
#
# Image ops build on tkutils::tkuimage (load/scale/fit); scaling uses the
# imgtools extension when present (smooth) and Tk photo scaling otherwise.
# Cropping is a native Tk photo `copy -from` region. Loading/saving needs Img.

namespace eval ::app {}

# Per-dialog state.
array set ::app::_it {
    src "" pv "" file "" pscale 1.0
    imgW 0 imgH 0
    cx 0 cy 0 cw 0 ch 0
    outW 0 keepAspect 1
    dragging 0 x0 0 y0 0
}

# One line per package: load status of the imaging stack, for System Info.
# Surfaces exactly why images can't be loaded/scaled (missing system lib,
# wrong package layout, ...) instead of failing silently.
proc app::imagingReport {} {
    set out "--- Imaging (Img / imgtools) ---\n"
    foreach p {Img imgtools tkutils::tkuimage} {
        if {[catch {package require $p} v]} {
            append out [format "  %-20s NOT LOADED: %s\n" $p $v]
        } else {
            append out [format "  %-20s %s\n" $p $v]
        }
    }
    set eng [expr {[info commands ::imgtools::scale] ne "" \
        ? "imgtools (smooth)" : "Tk subsample (fallback)"}]
    append out "  scaling engine:      $eng\n"
    return $out
}

proc app::imageTool {{file ""}} {
    if {[app::_activeEditorFile] eq ""} {
        tk_messageBox -parent . -icon info -title "Save the document first" \
            -message "Please save the document before inserting an image.\n\nThen\
 the image can be stored next to it and referenced by a short relative path that\
 works the same in the viewer, in HTML and in PDF export. Unsaved documents would\
 force a fragile absolute path."
        return
    }
    set ::app::_it(imgErr) ""
    if {[catch {package require Img} e]} { set ::app::_it(imgErr) $e }
    catch {package require imgtools}
    catch {package require fileutil}
    if {[catch {package require tkutils::tkuimage} e]} {
        tk_messageBox -parent . -icon error -title "Image Tool" \
            -message "Cannot open the image tool:\ntkutils::tkuimage failed to load.\n\n$e"
        return
    }
    # Img provides most formats (JPEG/TIFF/BMP/...). Tk core still handles
    # PNG/GIF, so we continue, but warn so the failure is never silent.
    if {$::app::_it(imgErr) ne ""} {
        tk_messageBox -parent . -icon warning -title "Image Tool" \
            -message "The Img extension could not be loaded, so only PNG and GIF\
 will work (JPEG/TIFF/BMP need Img).\n\nReason:\n$::app::_it(imgErr)\n\nSee Help ->\
 System Info for details."
    }

    set w .imgtool
    if {[winfo exists $w]} { destroy $w }
    toplevel $w
    wm title $w "Insert Image"
    wm transient $w .

    # -- preview canvas (left) --
    ttk::frame $w.pv
    set c $w.pv.c
    canvas $c -width 460 -height 340 -background "#2b2b2b" -highlightthickness 0
    pack $c -fill both -expand 1
    bind $c <ButtonPress-1>   [list app::_itDragStart $w %x %y]
    bind $c <B1-Motion>       [list app::_itDragMove  $w %x %y]
    bind $c <ButtonRelease-1> [list app::_itDragEnd   $w]

    # -- controls (right) --
    ttk::frame $w.ctl -padding 8
    ttk::button $w.ctl.open -text "Open image\u2026" -command [list app::_itOpen $w]

    ttk::labelframe $w.ctl.crop -text "Crop (px, on the original)" -padding 6
    foreach {k lbl} {cx X cy Y cw W ch H} {
        ttk::label $w.ctl.crop.l$k -text $lbl -width 2
        ttk::entry $w.ctl.crop.e$k -width 7 -textvariable ::app::_it($k)
        bind $w.ctl.crop.e$k <FocusOut> [list app::_itSyncFromFields $w]
        bind $w.ctl.crop.e$k <Return>   [list app::_itSyncFromFields $w]
    }
    grid $w.ctl.crop.lcx $w.ctl.crop.ecx $w.ctl.crop.lcy $w.ctl.crop.ecy -sticky w -padx 2 -pady 2
    grid $w.ctl.crop.lcw $w.ctl.crop.ecw $w.ctl.crop.lch $w.ctl.crop.ech -sticky w -padx 2 -pady 2
    ttk::button $w.ctl.crop.reset -text "Whole image" -command [list app::_itCropReset $w]
    grid $w.ctl.crop.reset -columnspan 4 -sticky ew -pady {4 0}

    ttk::labelframe $w.ctl.size -text "Resize" -padding 6
    ttk::label $w.ctl.size.l -text "Target width (px):"
    ttk::entry $w.ctl.size.e -width 8 -textvariable ::app::_it(outW)
    ttk::checkbutton $w.ctl.size.keep -text "Keep aspect ratio" \
        -variable ::app::_it(keepAspect)
    grid $w.ctl.size.l $w.ctl.size.e -sticky w -padx 2 -pady 2
    grid $w.ctl.size.keep -columnspan 2 -sticky w -padx 2

    ttk::label $w.ctl.info -textvariable ::app::_it(infoText) -foreground "#888888"

    ttk::frame $w.ctl.btns
    ttk::button $w.ctl.btns.orig -text "Insert original" \
        -command [list app::_itInsertOriginal $w]
    ttk::button $w.ctl.btns.ins -text "Save & Insert" -command [list app::_itSaveInsert $w 1]
    ttk::button $w.ctl.btns.save -text "Save as\u2026" -command [list app::_itSaveInsert $w 0]
    ttk::button $w.ctl.btns.cancel -text "Cancel" -command [list destroy $w]
    pack $w.ctl.btns.orig $w.ctl.btns.ins $w.ctl.btns.save $w.ctl.btns.cancel \
        -side left -padx 2

    pack $w.ctl.open -fill x -pady {0 6}
    pack $w.ctl.crop -fill x -pady 4
    pack $w.ctl.size -fill x -pady 4
    pack $w.ctl.info -fill x -pady 4
    pack $w.ctl.btns -fill x -pady {8 0}

    pack $w.pv  -side left -fill both -expand 1
    pack $w.ctl -side right -fill y

    if {$file ne ""} { app::_itLoad $w $file } else { app::_itOpen $w }
}

proc app::_itOpen {w} {
    set types {
        {"Images" {.png .gif .jpg .jpeg .tif .tiff .bmp .ppm .pgm}}
        {"All Files" *}
    }
    set f [tk_getOpenFile -parent $w -title "Open image" -filetypes $types]
    if {$f ne ""} { app::_itLoad $w $f }
}

proc app::_itLoad {w file} {
    variable _it
    if {[catch {::tkutils::tkuimage::load $file} src]} {
        tk_messageBox -parent $w -icon error -title "Open" \
            -message "Could not load image:\n$src"
        return
    }
    catch {image delete $_it(src)}
    catch {image delete $_it(pv)}
    set _it(src)  $src
    set _it(file) $file
    set _it(imgW) [image width $src]
    set _it(imgH) [image height $src]
    set _it(outW) $_it(imgW)
    app::_itCropReset $w
    app::_itRenderPreview $w
}

# Fit the source to the canvas and remember the preview scale.
proc app::_itRenderPreview {w} {
    variable _it
    set c $w.pv.c
    $c delete all
    if {$_it(src) eq ""} return
    set cw [winfo width $c] ; set chh [winfo height $c]
    if {$cw < 10} { set cw 460 } ; if {$chh < 10} { set chh 340 }
    lassign [::tkutils::tkuimage::fit $_it(imgW) $_it(imgH) $cw $chh] dw dh scale
    if {$dw < 1} { set dw 1 } ; if {$dh < 1} { set dh 1 }
    catch {image delete $_it(pv)}
    set _it(pv) [::tkutils::tkuimage::scale $_it(src) $dw $dh]
    set _it(pscale) [expr {$dw / double($_it(imgW))}]
    $c create image 0 0 -anchor nw -image $_it(pv) -tags img
    app::_itDrawCropRect $w
    set _it(infoText) "$_it(imgW)x$_it(imgH) px  ->  crop $_it(cw)x$_it(ch)"
}

proc app::_itDrawCropRect {w} {
    variable _it
    set c $w.pv.c
    $c delete croprect
    if {$_it(cw) <= 0 || $_it(ch) <= 0} return
    set s $_it(pscale)
    set x1 [expr {$_it(cx) * $s}] ; set y1 [expr {$_it(cy) * $s}]
    set x2 [expr {($_it(cx)+$_it(cw)) * $s}] ; set y2 [expr {($_it(cy)+$_it(ch)) * $s}]
    $c create rectangle $x1 $y1 $x2 $y2 -outline "#4ea1ff" -width 2 -tags croprect
}

# -- rubber band --
proc app::_itDragStart {w px py} {
    variable _it
    if {$_it(src) eq ""} return
    set _it(dragging) 1 ; set _it(x0) $px ; set _it(y0) $py
}
proc app::_itDragMove {w px py} {
    variable _it
    if {!$_it(dragging)} return
    set s $_it(pscale)
    if {$s <= 0} return
    set x1 [expr {min($_it(x0),$px)}] ; set y1 [expr {min($_it(y0),$py)}]
    set x2 [expr {max($_it(x0),$px)}] ; set y2 [expr {max($_it(y0),$py)}]
    # clamp to image bounds (in preview px)
    set maxX [expr {$_it(imgW)*$s}] ; set maxY [expr {$_it(imgH)*$s}]
    set x1 [expr {max(0,$x1)}] ; set y1 [expr {max(0,$y1)}]
    set x2 [expr {min($maxX,$x2)}] ; set y2 [expr {min($maxY,$y2)}]
    set _it(cx) [expr {int($x1/$s)}] ; set _it(cy) [expr {int($y1/$s)}]
    set _it(cw) [expr {int(($x2-$x1)/$s)}] ; set _it(ch) [expr {int(($y2-$y1)/$s)}]
    app::_itDrawCropRect $w
    set _it(infoText) "crop $_it(cw)x$_it(ch) @ $_it(cx),$_it(cy)"
}
proc app::_itDragEnd {w} {
    variable _it
    set _it(dragging) 0
}

proc app::_itSyncFromFields {w} {
    variable _it
    foreach k {cx cy cw ch outW} {
        if {![string is integer -strict $_it($k)]} { set _it($k) 0 }
    }
    app::_itDrawCropRect $w
}

proc app::_itCropReset {w} {
    variable _it
    set _it(cx) 0 ; set _it(cy) 0
    set _it(cw) $_it(imgW) ; set _it(ch) $_it(imgH)
    app::_itDrawCropRect $w
}

# Build the result photo (crop then resize). Returns a NEW photo name.
proc app::_itBuildResult {w} {
    variable _it
    set src $_it(src)
    # crop
    if {$_it(cw) > 0 && $_it(ch) > 0 \
            && ($_it(cx) != 0 || $_it(cy) != 0 \
                || $_it(cw) != $_it(imgW) || $_it(ch) != $_it(imgH))} {
        set x2 [expr {min($_it(imgW), $_it(cx)+$_it(cw))}]
        set y2 [expr {min($_it(imgH), $_it(cy)+$_it(ch))}]
        set cropped [image create photo -width [expr {$x2-$_it(cx)}] \
            -height [expr {$y2-$_it(cy)}]]
        $cropped copy $src -from $_it(cx) $_it(cy) $x2 $y2
    } else {
        set cropped [image create photo]
        $cropped copy $src
    }
    # resize
    set cw [image width $cropped] ; set ch [image height $cropped]
    set outW $_it(outW)
    if {![string is integer -strict $outW] || $outW < 1} { set outW $cw }
    if {$_it(keepAspect)} {
        set outH [expr {max(1, int(round($outW * $ch / double($cw))))}]
    } else {
        set outH $ch
    }
    if {$outW == $cw && $outH == $ch} { return $cropped }
    set result [::tkutils::tkuimage::scale $cropped $outW $outH]
    image delete $cropped
    return $result
}

proc app::_itSaveInsert {w insert} {
    variable _it
    if {$_it(src) eq ""} { return }
    # default save dir: current file's dir, else docs root, else home
    set dir [pwd]
    catch { if {[info exists ::app::docsRoot] && $::app::docsRoot ne ""} { set dir $::app::docsRoot } }
    set base "[file rootname [file tail $_it(file)]]-edited.png"
    set out [tk_getSaveFile -parent $w -title "Save PNG" \
        -defaultextension .png -initialdir $dir -initialfile $base \
        -filetypes {{"PNG" .png} {"All Files" *}}]
    if {$out eq ""} return
    set result [app::_itBuildResult $w]
    if {[catch {$result write $out -format png} err]} {
        catch {image delete $result}
        tk_messageBox -parent $w -icon error -title "Save" \
            -message "Could not save PNG:\n$err"
        return
    }
    catch {image delete $result}

    if {$insert} { app::_itInsertRef $w $out }
    destroy $w
}

# File of the active editor tab, or "" if the tab has no saved file yet.
proc app::_activeEditorFile {} {
    if {[catch {set cur [$::app::notebook select]}]} { return "" }
    if {[info exists ::app::edFile($cur)] && $::app::edFile($cur) ne ""} {
        return $::app::edFile($cur)
    }
    return ""
}

# Directory of the current doc (editor file's dir, else docsRoot, else cwd).
proc app::_currentDocDir {} {
    set f [app::_activeEditorFile]
    if {$f ne ""} { return [file dirname $f] }
    if {[info exists ::app::docsRoot] && $::app::docsRoot ne ""} {
        return $::app::docsRoot
    }
    return [pwd]
}

# Is $path inside the tree rooted at $baseDir? (relative has no leading "..")
proc app::_itUnderTree {baseDir path} {
    if {[catch {::fileutil::relative $baseDir $path} rel]} { return 0 }
    return [expr {[string range $rel 0 1] ne ".."}]
}

# Copy src into <baseDir>/images/, de-duplicating the name. The original is
# left untouched. Returns the new path, or "" on failure.
proc app::_copyIntoImages {srcPath baseDir} {
    set imgDir [file join $baseDir images]
    if {[catch {file mkdir $imgDir}]} { return "" }
    set target [file join $imgDir [file tail $srcPath]]
    if {[file normalize $srcPath] eq [file normalize $target]} { return $target }
    if {[file exists $target]} {
        set root [file rootname [file tail $srcPath]]
        set ext  [file extension $srcPath]
        set n 1
        while {[file exists [file join $imgDir "$root-$n$ext"]]} { incr n }
        set target [file join $imgDir "$root-$n$ext"]
    }
    if {[catch {file copy -force $srcPath $target}]} { return "" }
    return $target
}

# Decide which path to reference: inside the doc tree -> as-is; outside ->
# offer to copy into <docs>/images/. Returns the path, or "" if cancelled.
proc app::_resolveImageRef {srcPath parent} {
    catch {package require fileutil}
    set base [app::_currentDocDir]
    if {[app::_itUnderTree $base $srcPath]} { return $srcPath }
    set ans [tk_messageBox -parent $parent -type yesnocancel -icon question \
        -title "Insert image" \
        -message "This image is outside your docs folder.\n\nCopy it into\
 <docs>/images/ and reference the copy? The original file is left untouched.\n\n\
Yes = copy in       No = reference where it is"]
    if {$ans eq "cancel"} { return "" }
    if {$ans eq "no"}     { return $srcPath }
    set copied [app::_copyIntoImages $srcPath $base]
    if {$copied eq ""} {
        tk_messageBox -parent $parent -icon error -title "Copy" \
            -message "Could not copy the image into <docs>/images/."
        return $srcPath
    }
    return $copied
}

# Insert the currently loaded image AS-IS (no crop/resize/save). If it lives
# outside the doc tree, offer to copy it into <docs>/images/ first.
proc app::_itInsertOriginal {w} {
    variable _it
    if {$_it(file) eq ""} { return }
    set ref [app::_resolveImageRef $_it(file) $w]
    if {$ref eq ""} { return }
    app::_itInsertRef $w $ref
    destroy $w
}

# Quick path (no dialog): pick an existing image and reference it (as-is, or
# copied into <docs>/images/ if it's outside the tree).
proc app::insertExistingImage {} {
    if {[app::_activeEditorFile] eq ""} {
        tk_messageBox -parent . -icon info -title "Save the document first" \
            -message "Please save the document first, then insert the image so it\
 can be referenced by a short relative path (works in viewer, HTML and PDF)."
        return
    }
    catch {package require fileutil}
    set types {
        {"Images" {.png .gif .jpg .jpeg .tif .tiff .bmp .svg .webp}}
        {"All Files" *}
    }
    set f [tk_getOpenFile -parent . -title "Insert existing image" -filetypes $types]
    if {$f eq ""} return
    set ref [app::_resolveImageRef $f .]
    if {$ref eq ""} return
    app::_itInsertRef "" $ref
}

# Insert ![alt](relpath) into the active editor tab; else clipboard + note.
proc app::_itInsertRef {w path} {
    set alt [file rootname [file tail $path]]
    # relative to the current editor file if possible
    set ref $path
    catch {
        set cur [$::app::notebook select]
        if {[info exists ::app::edFile($cur)]} {
            set base [file dirname $::app::edFile($cur)]
            set rel [::fileutil::relative $base $path]
            if {$rel ne ""} { set ref $rel }
        }
    }
    set md "!\[$alt\]($ref)"
    set done 0
    catch {
        set cur [$::app::notebook select]
        if {[info exists ::app::edKit($cur)]} {
            set ed [mdstack::editorkit::editor $::app::edKit($cur)]
            set t [mdstack::text::_t $ed]
            # Insert as a block: docir only embeds images that stand on their
            # own line (blank line before/after). Inline images (mixed with
            # text) render as a [image: alt] marker with no picture in the PDF.
            $t insert insert "\n\n$md\n\n"
            set done 1
        }
    }
    if {!$done} {
        clipboard clear -displayof . ; clipboard append -displayof . $md
        tk_messageBox -parent . -icon info -title "Image saved" \
            -message "Saved:\n$path\n\nMarkdown copied to clipboard:\n$md"
    }
}
