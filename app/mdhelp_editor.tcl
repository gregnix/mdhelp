# mdhelp_editor.tcl -- Editor Integration (Priority 12: extracted from mdhelp.tcl)
#
# Contains: openInEditor, editorCmd, editorSave, editorClose,
#           Undo/Redo, Spell, TIP-700-Toolbar, Mode Switching.
#
# Loaded from mdhelp.tcl via source.
# All procs live in namespace app::.

if {![namespace exists ::app]} {
    error "mdhelp_editor.tcl must be loaded from mdhelp.tcl (namespace app missing)"
}

proc app::openInEditor {file} {
    # Editor as tab in notebook (instead of toplevel window)
    variable notebook
    variable editorTabs

    # Read file (UTF-8 with fallback to Latin-1)
    if {[catch {
        set fh [open $file r]
        fconfigure $fh -encoding utf-8
        set markdown [read $fh]
        close $fh
    } err]} {
        catch {close $fh}
        if {[catch {
            set fh [open $file r]
            fconfigure $fh -encoding iso8859-1
            set markdown [read $fh]
            close $fh
        } err2]} {
            tk_messageBox -icon error -title "Error" \
                -message "File not readable:\n$err2"
            return
        }
    }

    # Auto-Save-Pruefung: gibt es eine neuere autosave-Version?
    set restored [app::autoSaveCheckRestore $file]
    if {$restored ne ""} {
        set markdown $restored
        # Markiere dirty, damit der User die Wiederherstellung speichert
        set _restoredDirty 1
    } else {
        set _restoredDirty 0
    }

    # Tab-ID erzeugen
    set tabId "ed_[clock microseconds]"
    set w $notebook.$tabId
    lappend editorTabs $w

    ttk::frame $w
    set tabLabel "[file tail $file]"
    $notebook add $w -text $tabLabel
    $notebook select $w

    # --- Format-Toolbar ---
    ttk::frame $w.tb
    pack $w.tb -fill x -padx 2 -pady 2

    ttk::button $w.tb.save -text "Save" -width 10 \
        -command [list app::editorSave $w $file]
    ttk::button $w.tb.savclose -text "Save+Close" -width 20 \
        -command [list app::editorSaveClose $w $file]
    ttk::button $w.tb.close -text "Close" -width 10 \
        -command [list app::editorClose $w $file]
    ttk::separator $w.tb.s0 -orient vertical

    # Undo/Redo (Prio 10)
    ttk::button $w.tb.undo -text "\u21b6" -width 3 \
        -command [list app::editorUndo $w]
    ttk::button $w.tb.redo -text "\u21b7" -width 3 \
        -command [list app::editorRedo $w]
    ttk::separator $w.tb.s0b -orient vertical

    ttk::button $w.tb.bold -text "B" -width 3 \
        -command [list app::editorCmd $w wrap "**"]
    ttk::button $w.tb.italic -text "I" -width 3 \
        -command [list app::editorCmd $w wrap "*"]
    ttk::button $w.tb.code -text "<>" -width 3 \
        -command [list app::editorCmd $w wrap "`"]
    ttk::separator $w.tb.s1 -orient vertical

    ttk::button $w.tb.h1 -text "H1" -width 3 \
        -command [list app::editorCmd $w heading 1]
    ttk::button $w.tb.h2 -text "H2" -width 3 \
        -command [list app::editorCmd $w heading 2]
    ttk::button $w.tb.h3 -text "H3" -width 3 \
        -command [list app::editorCmd $w heading 3]
    ttk::separator $w.tb.s2 -orient vertical

    ttk::button $w.tb.list -text "List" -width 5 \
        -command [list app::editorCmd $w prefix "- "]
    ttk::button $w.tb.quote -text "Quote" -width 5 \
        -command [list app::editorCmd $w prefix "> "]
    ttk::button $w.tb.task -text "Task" -width 5 \
        -command [list app::editorCmd $w checkbox]
    ttk::separator $w.tb.s3 -orient vertical

    ttk::button $w.tb.codeblk -text "```" -width 4 \
        -command [list app::editorCmd $w codeblock tcl]
    ttk::button $w.tb.table -text "Table" -width 7 \
        -command [list app::editorCmd $w table 3 3]

    # TIP-700 Span-Menubutton
    ttk::separator $w.tb.s3b -orient vertical
    ttk::menubutton $w.tb.span -text "Span" -width 5 \
        -menu $w.tb.span.m
    menu $w.tb.span.m -tearoff 0
    foreach {cls label} {
        cmd "cmd (Command)"  sub "sub (Subcommand)"
        lit "lit (Literal)"   arg "arg (Argument)"
        optarg "optarg (Optional)" optlit "optlit (Opt.Literal)"
        ins "ins (Instance)"
        ccmd "ccmd (C Function)" cargs "cargs (C Args)" ret "ret (C Return)"
    } {
        $w.tb.span.m add command -label $label \
            -command [list app::editorSpanWrap $w $cls]
    }

    # TIP-700 Div-Menubutton
    ttk::menubutton $w.tb.div -text "Div" -width 4 \
        -menu $w.tb.div.m
    menu $w.tb.div.m -tearoff 0
    foreach {cls label} {
        synopsis "synopsis"  example "example"
        arguments "arguments" note "note" warning "warning"
    } {
        $w.tb.div.m add command -label $label \
            -command [list app::editorDivInsert $w $cls]
    }

    # YAML-Frontmatter
    ttk::button $w.tb.yaml -text "YAML" -width 5 \
        -command [list app::editorYamlInsert $w]

    ttk::separator $w.tb.s4 -orient vertical
    ttk::radiobutton $w.tb.mSplit -text "Split" \
        -variable ::app::edMode($w) -value "split" \
        -command [list app::editorSetMode $w split]
    ttk::radiobutton $w.tb.mEdit -text "Editor" \
        -variable ::app::edMode($w) -value "edit" \
        -command [list app::editorSetMode $w edit]
    ttk::radiobutton $w.tb.mView -text "Preview" \
        -variable ::app::edMode($w) -value "preview" \
        -command [list app::editorSetMode $w preview]

    pack $w.tb.save $w.tb.savclose $w.tb.close $w.tb.s0 \
         $w.tb.undo $w.tb.redo $w.tb.s0b \
         $w.tb.bold $w.tb.italic $w.tb.code $w.tb.s1 \
         $w.tb.h1 $w.tb.h2 $w.tb.h3 $w.tb.s2 \
         $w.tb.list $w.tb.quote $w.tb.task $w.tb.s3 \
         $w.tb.codeblk $w.tb.table $w.tb.s3b \
         $w.tb.span $w.tb.div $w.tb.yaml $w.tb.s4 \
         $w.tb.mSplit $w.tb.mEdit $w.tb.mView \
         -side left -padx 1

    # Spell checking toggle (only if available)
    if {$::app::hasSpellcheck} {
        ttk::separator $w.tb.s5 -orient vertical
        set ::app::edSpell($w) 1
        ttk::checkbutton $w.tb.spell -text "ABC" \
            -variable ::app::edSpell($w) \
            -command [list app::editorToggleSpell $w]
        pack $w.tb.s5 $w.tb.spell -side left -padx 1
    }

    # --- Status Bar ---
    ttk::frame $w.st
    pack $w.st -fill x -side bottom
    ttk::label $w.st.line  -text "Line: 1"   -width 12
    ttk::label $w.st.type  -text ""          -width 20
    ttk::label $w.st.count -text ""          -width 22 -foreground "#666666"
    ttk::label $w.st.mod   -text ""          -width 15 \
        -foreground [mdstack::theme::color status_error]
    pack $w.st.line $w.st.type $w.st.count $w.st.mod -side left -padx 5

    # --- mdeditorkit: Editor + Preview ---
    ttk::panedwindow $w.outer -orient horizontal
    pack $w.outer -fill both -expand 1

    set kit [mdstack::editorkit::create $w.outer.kit \
        -fontsize $::app::fontSize \
        -root [file dirname $file] \
        -debounce 400 \
        -onchange [list app::editorOnChange $w]]

    # Enable smart-editing features
    set ed [mdstack::editorkit::editor $kit]
    $ed enableFeature smartReturn
    $ed enableFeature indent

    # Outline panel (left, narrow)
    set outline [mdstack::outline::create $w.outer.outline -editor $ed]

    # Layout: Outline left, EditorKit right
    $w.outer add $outline -weight 0
    $w.outer add $kit -weight 1

    # Attach context menu
    mdstack::contextmenu::attachToEditor $ed

    # Attach spell checking (optional)
    set t_ed [mdstack::text::_t $ed]
    if {$::app::hasSpellcheck} {
        mdspellcheck::attach $t_ed
    }

    # State
    set ::app::edMode($w) "split"
    set ::app::edDirty($w) 0
    set ::app::edKit($w) $kit
    set ::app::edOutline($w) $outline
    set ::app::edFile($w) $file

    # Set text (triggers initial preview)
    mdstack::editorkit::settext $kit $markdown
    $ed modified 0

    # Wenn aus Auto-Save wiederhergestellt: dirty markieren, damit
    # User den Restore explizit speichern kann.
    if {$_restoredDirty} {
        set ::app::edDirty($w) 1
        catch {
            $::app::notebook tab $w -text "* [file tail $file]"
        }
        set ::app::statusText "Aus Auto-Save wiederhergestellt — bitte speichern"
    }

    # Fill outline initially
    mdstack::outline::refresh $outline

    # Status update timer
    app::editorUpdateStatus $w

    # Auto-Save-Timer starten (laeuft global, nur einmal aktiv)
    app::autoSaveStart

    # Bindings (on the tab frame)
    set t_ed [mdstack::text::_t $ed]
    bind $t_ed <Control-s> [list app::editorSave $w $file]
    bind $t_ed <Control-S> [list app::editorSave $w $file]
    bind $t_ed <Control-z> [list app::editorUndo $w]
    bind $t_ed <Control-Z> [list app::editorUndo $w]
    bind $t_ed <Control-y> [list app::editorRedo $w]
    bind $t_ed <Control-Y> [list app::editorRedo $w]
    bind $t_ed <Control-g> [list app::editorGotoLine $w]
    bind $t_ed <Control-G> [list app::editorGotoLine $w]
    bind $t_ed <F7> [list app::editorSpellAll $w]

    # Initial spell checking (delayed)
    if {$::app::hasSpellcheck} {
        after 500 [list app::editorSpellSilent $w]
    }
}

proc app::editorUndo {w} {
    variable edKit
    if {![info exists edKit($w)]} return
    set ed [mdstack::editorkit::editor $edKit($w)]
    set t [mdstack::text::_t $ed]
    if {[catch {$t edit undo}]} {
        bell
    }
}

proc app::editorGotoLine {w} {
    # Springt zu einer vom Benutzer eingegebenen Zeilennummer.
    variable edKit
    if {![info exists edKit($w)]} return
    set ed [mdstack::editorkit::editor $edKit($w)]
    set t [mdstack::text::_t $ed]

    # Aktuelle Maximalzeile ermitteln
    set maxLine [lindex [split [$t index end-1c] .] 0]
    set initVal [lindex [split [$t index insert] .] 0]

    # Modaler kleiner Dialog
    set dlg .editorGoto
    catch {destroy $dlg}
    toplevel $dlg
    wm title $dlg "Gehe zu Zeile"
    wm transient $dlg [winfo toplevel $w]
    wm resizable $dlg 0 0

    ttk::label $dlg.lbl -text "Zeile (1 - $maxLine):"
    ttk::entry $dlg.e -width 10 -justify right
    $dlg.e insert end $initVal
    $dlg.e selection range 0 end

    ttk::frame $dlg.btns
    ttk::button $dlg.btns.ok -text "OK" -width 8 -command [list apply {{dlg t maxLine} {
        set v [$dlg.e get]
        if {[string is integer -strict $v] && $v >= 1 && $v <= $maxLine} {
            $t mark set insert $v.0
            $t see $v.0
            focus $t
            destroy $dlg
        } else {
            bell
            $dlg.e selection range 0 end
            focus $dlg.e
        }
    }} $dlg $t $maxLine]
    ttk::button $dlg.btns.cancel -text "Abbrechen" -width 10 \
        -command [list destroy $dlg]
    pack $dlg.btns.ok $dlg.btns.cancel -side left -padx 4

    pack $dlg.lbl -padx 10 -pady {10 2}
    pack $dlg.e   -padx 10 -pady {0 8}
    pack $dlg.btns -padx 10 -pady {0 10}

    bind $dlg.e <Return> [list $dlg.btns.ok invoke]
    bind $dlg   <Escape> [list destroy $dlg]

    # Mittig zum Hauptfenster
    update idletasks
    set parent [winfo toplevel $w]
    set px [winfo rootx $parent]
    set py [winfo rooty $parent]
    set pw [winfo width $parent]
    set ph [winfo height $parent]
    set dw [winfo reqwidth $dlg]
    set dh [winfo reqheight $dlg]
    set x [expr {$px + ($pw - $dw) / 2}]
    set y [expr {$py + ($ph - $dh) / 3}]
    wm geometry $dlg "+$x+$y"

    grab $dlg
    focus $dlg.e
}

proc app::editorRedo {w} {
    variable edKit
    if {![info exists edKit($w)]} return
    set ed [mdstack::editorkit::editor $edKit($w)]
    set t [mdstack::text::_t $ed]
    if {[catch {$t edit redo}]} {
        bell
    }
}

proc app::editorCmd {w cmd args} {
    # Forward format command to mdtext editor.
    variable edKit
    if {![info exists edKit($w)]} return
    set ed [mdstack::editorkit::editor $edKit($w)]
    $ed {*}$cmd {*}$args
}

proc app::editorSetMode {w mode} {
    variable edKit
    if {![info exists edKit($w)]} return
    mdstack::editorkit::setmode $edKit($w) $mode
}

# TIP-700: Wrap selection with span markup
proc app::editorSpanWrap {w cls} {
    variable edKit
    if {![info exists edKit($w)]} return
    set ed [mdstack::editorkit::editor $edKit($w)]
    set t [mdstack::text::_t $ed]

    set sel [$t tag ranges sel]
    if {[llength $sel] < 2} {
        # No selection: insert placeholder
        $t insert insert "\[text\]{.${cls}}"
        return
    }
    set start [lindex $sel 0]
    set end   [lindex $sel 1]
    set text  [$t get $start $end]
    $t delete $start $end
    $t insert $start "\[${text}\]{.${cls}}"
}

# TIP-700: Insert fenced div
proc app::editorDivInsert {w cls} {
    variable edKit
    if {![info exists edKit($w)]} return
    set ed [mdstack::editorkit::editor $edKit($w)]
    set t [mdstack::text::_t $ed]

    set sel [$t tag ranges sel]
    if {[llength $sel] >= 2} {
        set start [lindex $sel 0]
        set end   [lindex $sel 1]
        set text  [$t get $start $end]
        $t delete $start $end
        $t insert $start "::: {.${cls}}\n${text}\n:::\n"
    } else {
        $t insert insert "::: {.${cls}}\n\n:::\n"
        # Set cursor in empty line
        $t mark set insert "insert - 2 lines lineend"
    }
}

# Insert YAML frontmatter template
proc app::editorYamlInsert {w} {
    variable edKit
    if {![info exists edKit($w)]} return
    set ed [mdstack::editorkit::editor $edKit($w)]
    set t [mdstack::text::_t $ed]

    set template "---\ntitle: \nsection: n\nmanual-section: Tcl Built-In Commands\n---\n\n"
    $t insert 1.0 $template
    $t mark set insert "1.7"
}

proc app::editorOnChange {w args} {
    set ::app::edDirty($w) 1
    # Tab label with dirty marking
    if {[info exists ::app::edFile($w)]} {
        catch {
            $::app::notebook tab $w -text "* [file tail $::app::edFile($w)]"
        }
    }
    # Update outline
    if {[info exists ::app::edOutline($w)]} {
        after idle [list catch [list mdstack::outline::refresh $::app::edOutline($w)]]
    }
}

proc app::editorUpdateStatus {w} {
    variable edKit
    if {![info exists edKit($w)] || ![winfo exists $w]} return

    set ed [mdstack::editorkit::editor $edKit($w)]
    if {![winfo exists $ed]} return

    # Line number
    set pos [$ed index insert]
    set line [lindex [split $pos .] 0]
    $w.st.line configure -text "Line: $line"

    # Line type
    catch {$w.st.type configure -text "[$ed lineType]"}

    # Wort-/Zeichen-Zaehler
    catch {
        set t [mdstack::text::_t $ed]
        set txt [$t get 1.0 "end - 1 char"]
        set chars [string length $txt]
        # Wortzaehler: nicht-leere whitespace-getrennte Token
        set words [llength [regexp -all -inline {\S+} $txt]]
        $w.st.count configure -text "${words} W / ${chars} Z"
    }

    # Modified
    if {[info exists ::app::edDirty($w)] && $::app::edDirty($w)} {
        $w.st.mod configure -text "\[MODIFIED\]"
    } else {
        # Wenn kein Modified: stattdessen ggf. Auto-Save-Status zeigen
        if {$::app::autoSaveLastStatus ne ""} {
            $w.st.mod configure -text $::app::autoSaveLastStatus \
                -foreground "#666666"
        } else {
            $w.st.mod configure -text "" \
                -foreground [mdstack::theme::color status_error]
        }
    }

    after 500 [list app::editorUpdateStatus $w]
}

proc app::editorSave {w file} {
    variable edKit
    if {![info exists edKit($w)]} return

    set markdown [mdstack::editorkit::gettext $edKit($w)]

    if {[catch {
        set fh [open $file w]
        fconfigure $fh -encoding utf-8
        puts -nonewline $fh $markdown
        close $fh
    } err]} {
        tk_messageBox -icon error -title "Save" \
            -message "Save failed:\n$err"
        return
    }

    set ::app::edDirty($w) 0
    catch {
        $::app::notebook tab $w -text [file tail $file]
    }

    # Auto-Save-File entfernen — wir sind sauber
    catch { app::autoSaveRemove $file }

    # Update viewer if same file
    if {[file normalize $file] eq [file normalize $::app::currentFile]} {
        app::reload
    }
}

proc app::editorSaveClose {w file} {
    app::editorSave $w $file
    app::editorDestroy $w
}

proc app::editorClose {w file} {
    if {[info exists ::app::edDirty($w)] && $::app::edDirty($w)} {
        set answer [tk_messageBox -icon question \
            -title "Unsaved Changes" \
            -type yesnocancel \
            -message "Save changes to [file tail $file]?"]
        switch -- $answer {
            yes    { app::editorSave $w $file ; app::editorDestroy $w }
            no     {
                # Auch ohne Save: autosave entfernen, wenn User
                # explizit verworfen hat.
                catch { app::autoSaveRemove $file }
                app::editorDestroy $w
            }
            cancel { return }
        }
    } else {
        app::editorDestroy $w
    }
}

proc app::editorDestroy {w} {
    # Detach spellcheck
    if {$::app::hasSpellcheck} {
        variable edKit
        if {[info exists edKit($w)]} {
            set ed [mdstack::editorkit::editor $edKit($w)]
            catch { mdspellcheck::detach [mdstack::text::_t $ed] }
        }
    }
    catch {unset ::app::edDirty($w)}
    catch {unset ::app::edMode($w)}
    catch {unset ::app::edKit($w)}
    catch {unset ::app::edOutline($w)}
    catch {unset ::app::edSpell($w)}
    catch {unset ::app::edFile($w)}

    # Remove tab from notebook
    variable notebook
    variable editorTabs
    catch {$notebook forget $w}
    set editorTabs [lsearch -all -inline -not -exact $editorTabs $w]
    catch {destroy $w}

    # Wenn keine Editor-Tabs mehr offen sind: Auto-Save-Timer stoppen
    if {[llength $editorTabs] == 0} {
        catch { app::autoSaveStop }
    }

    # Return to viewer tab
    catch {$notebook select 0}
}

proc app::editorToggleSpell {w} {
    variable edKit
    variable edSpell
    if {![info exists edKit($w)]} return
    set t_ed [mdstack::text::_t [mdstack::editorkit::editor $edKit($w)]]
    if {$edSpell($w)} {
        mdspellcheck::enabled $t_ed 1
        mdspellcheck::checkAll $t_ed
    } else {
        mdspellcheck::enabled $t_ed 0
    }
}

proc app::editorSpellSilent {w} {
    variable edKit
    if {![info exists edKit($w)]} return
    if {![winfo exists $w]} return
    if {!$::app::hasSpellcheck} return
    set t_ed [mdstack::text::_t [mdstack::editorkit::editor $edKit($w)]]
    catch { mdspellcheck::checkAll $t_ed }
}

proc app::editorSpellAll {w} {
    variable edKit
    if {![info exists edKit($w)]} return
    if {![winfo exists $w]} return
    if {!$::app::hasSpellcheck} return
    set t_ed [mdstack::text::_t [mdstack::editorkit::editor $edKit($w)]]
    mdspellcheck::enabled $t_ed 1
    catch {set ::app::edSpell($w) 1}
    mdspellcheck::checkAll $t_ed
    # Count number of errors
    set count 0
    set idx 1.0
    while {1} {
        set range [$t_ed tag nextrange spellwrong $idx end]
        if {[llength $range] != 2} break
        incr count
        set idx "[lindex $range 1] + 1 char"
    }
    if {$count == 0} {
        $w.st.mod configure -text "No errors" -foreground "#008800"
        after 3000 [list catch [list $w.st.mod configure -text "" -foreground "#cc0000"]]
    } else {
        $w.st.mod configure -text "$count errors" -foreground "#cc0000"
        mdspellcheck::showResults $t_ed $w
    }
}


# ============================================================
# Auto-Save fuer Editor-Tabs
# ============================================================
# Alle ::app::autoSaveIntervalMs ms wird jeder dirty Editor-Tab in
# eine versteckte Datei .<basename>.autosave neben dem Original
# geschrieben. Beim regulaeren Save oder Tab-Close wird sie wieder
# entfernt.
#
# Beim Oeffnen einer Datei prueft openInEditor, ob ein neuerer
# autosave existiert, und bietet Wiederherstellung an.

set ::app::autoSaveIntervalMs 30000   ;# 30s
set ::app::autoSaveTimerId    ""
set ::app::autoSaveLastStatus ""

proc app::_autoSavePath {file} {
    set dir  [file dirname $file]
    set base [file tail $file]
    return [file join $dir ".${base}.autosave"]
}

proc app::autoSaveTick {} {
    variable editorTabs
    set anySaved 0
    foreach w $editorTabs {
        if {![info exists ::app::edDirty($w)]}  continue
        if {!$::app::edDirty($w)}                continue
        if {![info exists ::app::edFile($w)]}   continue
        if {![info exists ::app::edKit($w)]}    continue

        set file $::app::edFile($w)
        set asPath [app::_autoSavePath $file]
        if {[catch {
            set markdown [mdstack::editorkit::gettext $::app::edKit($w)]
            set fh [open $asPath w]
            fconfigure $fh -encoding utf-8
            puts -nonewline $fh $markdown
            close $fh
        } err]} {
            catch {close $fh}
            # stille Ignorierung — kein Schreibrecht etc.
        } else {
            set anySaved 1
        }
    }
    if {$anySaved} {
        set ts [clock format [clock seconds] -format "%H:%M:%S"]
        set ::app::autoSaveLastStatus "Auto-saved $ts"
    }

    # Reschedule
    set ::app::autoSaveTimerId [after $::app::autoSaveIntervalMs \
        app::autoSaveTick]
}

proc app::autoSaveStart {} {
    if {$::app::autoSaveTimerId ne ""} return
    set ::app::autoSaveTimerId [after $::app::autoSaveIntervalMs \
        app::autoSaveTick]
}

proc app::autoSaveStop {} {
    if {$::app::autoSaveTimerId ne ""} {
        catch {after cancel $::app::autoSaveTimerId}
        set ::app::autoSaveTimerId ""
    }
}

proc app::autoSaveRemove {file} {
    # Wird nach erfolgreichem Save oder Close gerufen.
    catch { file delete -force [app::_autoSavePath $file] }
}

proc app::autoSaveCleanup {} {
    # Beim sauberen Quit alle autosaves entfernen, auch wenn die
    # Tabs schon geschlossen sind aber wir noch File-Pfade kennen.
    variable editorTabs
    foreach w $editorTabs {
        if {[info exists ::app::edFile($w)]} {
            app::autoSaveRemove $::app::edFile($w)
        }
    }
}

proc app::autoSaveCheckRestore {file} {
    # Prueft ob ein Auto-Save zur Datei existiert und neuer ist als
    # die Originaldatei. Wenn ja: frage den User.
    # Returnt: Inhalt zum Wiederherstellen (Text) oder "" wenn nicht.
    set asPath [app::_autoSavePath $file]
    if {![file exists $asPath]} { return "" }

    set asTime  [file mtime $asPath]
    set origTime 0
    catch { set origTime [file mtime $file] }

    if {$asTime <= $origTime} {
        # Original ist neuer (oder gleich) → veralteten autosave loeschen
        catch { file delete -force $asPath }
        return ""
    }

    set diff [expr {$asTime - $origTime}]
    set when [clock format $asTime -format "%Y-%m-%d %H:%M:%S"]
    set answer [tk_messageBox -icon question -type yesno \
        -title "Auto-Save gefunden" \
        -message "Fuer\n  [file tail $file]\nexistiert ein Auto-Save\nvom $when\n($diff Sek. neuer als die Datei).\n\nWiederherstellen?"]

    if {$answer eq "yes"} {
        if {[catch {
            set fh [open $asPath r]
            fconfigure $fh -encoding utf-8
            set content [read $fh]
            close $fh
        } err]} {
            catch {close $fh}
            return ""
        }
        return $content
    } else {
        # Verworfen → autosave loeschen
        catch { file delete -force $asPath }
        return ""
    }
}

# ============================================================
# Tabs schliessen (Mittelklick + Ctrl+W)
# ============================================================

proc app::tabCloseAt {x y} {
    # Wird per Button-2 (Mittelklick) auf .right.nb aufgerufen.
    set tab [$::app::notebook identify tab $x $y]
    if {$tab eq ""} return
    set w [lindex [$::app::notebook tabs] $tab]
    if {$w eq ".right.nb.vtab"} return  ;# Viewer-Tab nicht schliessbar
    if {[info exists ::app::edFile($w)]} {
        app::editorClose $w $::app::edFile($w)
    }
}

proc app::closeCurrentTab {} {
    set tab [$::app::notebook select]
    if {$tab eq ".right.nb.vtab"} return
    if {[info exists ::app::edFile($tab)]} {
        app::editorClose $tab $::app::edFile($tab)
    }
}
