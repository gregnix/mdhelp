# deepl_helper.tcl -- DeepL-Übersetzungs-Hilfe
#
# Optional, wird per Tools-Menü angeboten. Setzt voraus dass:
#   - der API-Key in $::env(DEEPL_API_KEY) oder via UI gesetzt wurde
#   - das tcllib-Paket http verfügbar ist
#   - tls für HTTPS verfügbar ist
#
# API:
#   ::deepl::translate $text ?-source EN? ?-target DE?
#       returnt den übersetzten Text oder löst Fehler aus
#   ::deepl::available
#       1 falls API-Key + tls bereit, 0 sonst
#   ::deepl::setApiKey $key
#       überschreibt env-Variable
#
# UI-Helper (in mdhelp eingebunden):
#   ::deepl::translateSelection $textWidget
#       holt Selection, übersetzt, zeigt in Dialog mit "Copy / Replace"
#   ::deepl::configureKey
#       Dialog zum Setzen des API-Keys

namespace eval ::deepl {
    variable apiKey       ""
    variable apiBase      "https://api-free.deepl.com/v2/translate"
    variable apiBasePro   "https://api.deepl.com/v2/translate"
    variable usePro       0
    variable defaultSource "EN"
    variable defaultTarget "DE"
    # Status-Variable für UI
    variable lastError    ""
    variable lastStats    {}
}

proc ::deepl::available {} {
    if {[catch {package require http}]} { return 0 }
    if {[catch {package require tls}]} { return 0 }
    set k [::deepl::_resolveKey]
    return [expr {$k ne ""}]
}

proc ::deepl::_resolveKey {} {
    variable apiKey
    if {$apiKey ne ""} { return $apiKey }
    if {[info exists ::env(DEEPL_API_KEY)]} {
        return $::env(DEEPL_API_KEY)
    }
    if {[info exists ::tcldocs::cache]} {
        catch {
            set k [::tcldocs::getShared deeplApiKey ""]
            if {$k ne ""} { return $k }
        }
    }
    return ""
}

proc ::deepl::setApiKey {key} {
    variable apiKey
    set apiKey $key
    # Auch in shared config persistieren (wenn verfügbar)
    catch { ::tcldocs::setShared deeplApiKey $key }
}

proc ::deepl::setUsePro {flag} {
    variable usePro
    set usePro [expr {$flag ? 1 : 0}]
    catch { ::tcldocs::setShared deeplUsePro $usePro }
}

proc ::deepl::_endpoint {} {
    variable apiBase
    variable apiBasePro
    variable usePro
    set k [::deepl::_resolveKey]
    # DeepL-Konvention: Free-Keys enden auf ":fx", Pro-Keys nicht.
    # usePro forciert Pro auch fuer Free-Keys (selten gewuenscht).
    if {$usePro} {
        return $apiBasePro
    }
    if {[string match "*:fx" $k]} {
        return $apiBase
    }
    return $apiBasePro
}

# ============================================================
# JSON-Encoding (eigener kleiner Encoder, vermeidet huddle/json-write
# Abhaengigkeit fuer den schlanken Use-Case "ein paar Strings posten")
# ============================================================
proc ::deepl::_jsonEscape {s} {
    set out ""
    foreach ch [split $s ""] {
        switch -- $ch {
            "\""    { append out "\\\"" }
            "\\"   { append out "\\\\" }
            "\b"    { append out "\\b" }
            "\f"    { append out "\\f" }
            "\n"    { append out "\\n" }
            "\r"    { append out "\\r" }
            "\t"    { append out "\\t" }
            default {
                scan $ch %c code
                if {$code < 0x20} {
                    append out [format "\\u%04x" $code]
                } else {
                    append out $ch
                }
            }
        }
    }
    return $out
}

proc ::deepl::_buildJsonBody {text source target} {
    set body "{"
    # text ist ein Array
    append body "\"text\":\[\"[::deepl::_jsonEscape $text]\"\]"
    if {$source ne ""} {
        append body ",\"source_lang\":\"[::deepl::_jsonEscape $source]\""
    }
    if {$target ne ""} {
        append body ",\"target_lang\":\"[::deepl::_jsonEscape $target]\""
    }
    # Markup-Schutz via DeepL-eigenem Mechanismus
    append body ",\"tag_handling\":\"xml\""
    append body ",\"ignore_tags\":\[\"code\",\"pre\",\"tt\"\]"
    append body "}"
    return $body
}

# ============================================================
# Markup-Schutz
# ============================================================
# Bevor wir DeepL aufrufen ersetzen wir Markdown-Markup durch
# Platzhalter, damit DeepL nicht Backticks oder Sternchen "übersetzt".
# Nach dem Call werden die Platzhalter zurückersetzt.

proc ::deepl::_protectMarkdown {text} {
    set placeholders {}
    set i 0
    set out $text

    # Inline-Code: `...` (greedy match, kein Newline)
    set out [regsub -all {`([^`\n]+)`} $out {<<<MD\1>>>}]
    # Triple-backtick blocks bewahren wir nicht, die sind eh selten
    # in einer Manpage-Übersetzung — falls doch, einfach manuell.

    # Bold: **text**
    set out [regsub -all {\*\*([^*\n]+)\*\*} $out {<<<MB\1>>>}]
    # Italic: *text* (nur wenn nicht schon bold gefangen)
    set out [regsub -all {\*([^*\n]+)\*} $out {<<<MI\1>>>}]

    return $out
}

proc ::deepl::_unprotectMarkdown {text} {
    set out $text
    set out [regsub -all {<<<MD([^>]+)>>>} $out {`\1`}]
    set out [regsub -all {<<<MB([^>]+)>>>} $out {**\1**}]
    set out [regsub -all {<<<MI([^>]+)>>>} $out {*\1*}]
    return $out
}

# ============================================================
# HTTP / Translate
# ============================================================

proc ::deepl::translate {text args} {
    variable defaultSource
    variable defaultTarget
    variable lastError
    set lastError ""

    set source $defaultSource
    set target $defaultTarget
    set protectMarkup 1
    foreach {k v} $args {
        switch -- $k {
            -source { set source $v }
            -target { set target $v }
            -protect-markdown { set protectMarkup [expr {$v ? 1 : 0}] }
            default { error "unbekannte Option: $k" }
        }
    }

    if {[catch {package require http}]}       { error "http-Paket fehlt" }
    if {[catch {package require tls}]}        { error "tls-Paket fehlt" }
    if {[catch {package require json}]}       { error "tcllib::json fehlt — installiere tcllib" }

    set key [::deepl::_resolveKey]
    if {$key eq ""} {
        error "Kein DeepL-API-Key gesetzt — siehe Tools/DeepL"
    }

    # HTTPS via tls registrieren
    catch {http::register https 443 [list ::tls::socket -autoservername 1]}

    # Markup schützen (Markdown -> XML-Platzhalter; DeepL ignoriert die
    # via tag_handling=xml + ignore_tags)
    set sendText $text
    if {$protectMarkup} {
        set sendText [::deepl::_protectMarkdown $sendText]
    }

    set body [::deepl::_buildJsonBody $sendText $source $target]

    set headers [list \
        Authorization "DeepL-Auth-Key $key" \
        Content-Type  "application/json" \
        User-Agent    "mdhelp/0.1 (DeepL helper for tcl9-de corpus)"]

    set tok [http::geturl [::deepl::_endpoint] \
        -method POST \
        -headers $headers \
        -query $body \
        -type "application/json" \
        -timeout 15000]

    set status [http::status $tok]
    set ncode  [http::ncode $tok]
    set respBody [http::data $tok]
    http::cleanup $tok

    if {$status ne "ok"} {
        set lastError "HTTP $status"
        error "DeepL-HTTP-Fehler: $status"
    }
    if {$ncode != 200} {
        set lastError "HTTP $ncode: $respBody"
        # DeepL gibt bei Fehlern oft ein {"message":"..."}-JSON zurück
        set userMsg "DeepL-Fehler $ncode"
        if {[catch {set parsed [json::json2dict $respBody]} _]} {
            append userMsg ": $respBody"
        } else {
            if {[dict exists $parsed message]} {
                append userMsg ": [dict get $parsed message]"
            } else {
                append userMsg ": $respBody"
            }
        }
        error $userMsg
    }

    # Antwort parsen — sample:
    # {"translations":[{"detected_source_language":"EN","text":"Hallo, Welt!"}]}
    set parsed [json::json2dict $respBody]
    set translated ""
    if {[dict exists $parsed translations]} {
        set first [lindex [dict get $parsed translations] 0]
        if {[dict exists $first text]} {
            set translated [dict get $first text]
        }
    }

    if {$translated eq ""} {
        set lastError "Konnte Antwort nicht parsen: $respBody"
        error "DeepL-Antwort: kein 'text' im JSON"
    }

    # Markup zurück
    if {$protectMarkup} {
        set translated [::deepl::_unprotectMarkdown $translated]
    }
    return $translated
}

# ============================================================
# UI-Helper
# ============================================================

proc ::deepl::configureKey {} {
    set dlg .deeplConfig
    catch {destroy $dlg}
    toplevel $dlg
    wm title $dlg "DeepL API Key"
    wm transient $dlg .

    ttk::label $dlg.intro \
        -text "DeepL-API-Key (aus deinem DeepL-Account):" \
        -padding 10
    pack $dlg.intro -fill x

    ttk::frame $dlg.f -padding {10 0}
    pack $dlg.f -fill x
    ttk::entry $dlg.f.e -width 50 -show "*"
    pack $dlg.f.e -fill x

    set currentKey [::deepl::_resolveKey]
    if {$currentKey ne ""} {
        $dlg.f.e insert 0 $currentKey
    }

    ttk::label $dlg.hint \
        -text "Free-Keys enden auf \":fx\" — werden automatisch erkannt.\nKeys werden in ~/.tcldocs.rc gespeichert (unverschlüsselt)." \
        -foreground "#666666" \
        -padding {10 4 10 4}
    pack $dlg.hint -fill x

    ttk::frame $dlg.btn -padding 10
    pack $dlg.btn
    ttk::button $dlg.btn.ok -text "Speichern" -width 12 \
        -command [list apply {{dlg} {
            ::deepl::setApiKey [$dlg.f.e get]
            destroy $dlg
            tk_messageBox -icon info -title "DeepL" \
                -message "API-Key gespeichert."
        }} $dlg]
    ttk::button $dlg.btn.cancel -text "Abbrechen" -width 12 \
        -command [list destroy $dlg]
    pack $dlg.btn.ok $dlg.btn.cancel -side left -padx 4

    bind $dlg <Escape> [list destroy $dlg]
    update idletasks
    grab $dlg
    focus $dlg.f.e
}

proc ::deepl::translateSelection {textWidget} {
    if {![winfo exists $textWidget]} {
        tk_messageBox -icon error -title "DeepL" \
            -message "Kein Text-Widget aktiv."
        return
    }

    set sel ""
    catch { set sel [$textWidget get sel.first sel.last] }
    if {$sel eq ""} {
        tk_messageBox -icon info -title "DeepL" \
            -message "Bitte zuerst einen Textbereich markieren."
        return
    }

    if {![::deepl::available]} {
        set ans [tk_messageBox -icon question -type yesno \
            -title "DeepL" \
            -message "Kein DeepL-API-Key gesetzt.\n\nJetzt konfigurieren?"]
        if {$ans eq "yes"} {
            ::deepl::configureKey
        }
        return
    }

    if {[catch {
        set translated [::deepl::translate $sel \
            -source EN -target DE]
    } err]} {
        tk_messageBox -icon error -title "DeepL" \
            -message "Übersetzung fehlgeschlagen:\n$err"
        return
    }

    ::deepl::_showResultDialog $sel $translated $textWidget
}

proc ::deepl::_showResultDialog {original translated textWidget} {
    set dlg .deeplResult
    catch {destroy $dlg}
    toplevel $dlg
    wm title $dlg "DeepL-Vorschlag"
    wm geometry $dlg 800x500
    wm transient $dlg .

    ttk::frame $dlg.top
    pack $dlg.top -fill both -expand 1 -padx 4 -pady 4

    # Original (oben)
    ttk::labelframe $dlg.top.o -text "Original (Englisch)"
    pack $dlg.top.o -fill both -expand 1 -pady {0 4}
    text $dlg.top.o.t -wrap word -height 8 -font {TkDefaultFont 10} \
        -yscrollcommand [list $dlg.top.o.sb set]
    ttk::scrollbar $dlg.top.o.sb -orient vertical \
        -command [list $dlg.top.o.t yview]
    pack $dlg.top.o.sb -side right -fill y
    pack $dlg.top.o.t  -fill both -expand 1
    $dlg.top.o.t insert end $original
    $dlg.top.o.t configure -state disabled

    # Übersetzung (unten, editierbar damit User nachbessern kann)
    ttk::labelframe $dlg.top.t -text "DeepL-Vorschlag (editierbar)"
    pack $dlg.top.t -fill both -expand 1 -pady {4 0}
    text $dlg.top.t.t -wrap word -height 10 -font {TkDefaultFont 10} \
        -yscrollcommand [list $dlg.top.t.sb set]
    ttk::scrollbar $dlg.top.t.sb -orient vertical \
        -command [list $dlg.top.t.t yview]
    pack $dlg.top.t.sb -side right -fill y
    pack $dlg.top.t.t  -fill both -expand 1
    $dlg.top.t.t insert end $translated

    # Buttons
    ttk::frame $dlg.btn
    pack $dlg.btn -fill x -padx 4 -pady 4
    ttk::button $dlg.btn.replace -text "In Zielfeld einfügen" \
        -command [list ::deepl::_doReplace $dlg $textWidget]
    ttk::button $dlg.btn.copy -text "In Zwischenablage" \
        -command [list ::deepl::_doCopy $dlg]
    ttk::button $dlg.btn.close -text "Schließen" \
        -command [list destroy $dlg]
    pack $dlg.btn.replace $dlg.btn.copy -side left -padx 4
    pack $dlg.btn.close -side right -padx 4

    bind $dlg <Escape> [list destroy $dlg]
    focus $dlg.top.t.t
}

proc ::deepl::_doReplace {dlg textWidget} {
    if {![winfo exists $textWidget]} {
        destroy $dlg
        return
    }
    set new [$dlg.top.t.t get 1.0 "end - 1 char"]
    set state [$textWidget cget -state]
    if {$state ne "normal"} {
        tk_messageBox -icon warning -title "DeepL" \
            -message "Zielfeld ist nicht editierbar — \"In Zwischenablage\" benutzen."
        return
    }
    if {[catch {
        set s [$textWidget index sel.first]
        set e [$textWidget index sel.last]
    }]} {
        # Selection schon weg — am insert einfügen
        set s [$textWidget index insert]
        set e $s
    }
    $textWidget delete $s $e
    $textWidget insert $s $new
    destroy $dlg
}

proc ::deepl::_doCopy {dlg} {
    set new [$dlg.top.t.t get 1.0 "end - 1 char"]
    clipboard clear
    clipboard append $new
    set ::app::statusText "DeepL-Übersetzung in Zwischenablage."
    catch {destroy $dlg}
}
