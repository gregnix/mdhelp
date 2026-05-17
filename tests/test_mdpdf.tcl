#!/usr/bin/env tclsh
# test_mdpdf.tcl -- Tests fuer mdpdf (PDF Export)
#
# Generiert PDFs und prueft: Dateigroesse, PDF-Header, Seitenzahl.
# Aufruf: tclsh test_mdpdf.tcl
#
# Skip-on-missing: ohne pdf4tcl wird die Suite mit Exit 2 uebersprungen.

# TCLLIBPATH wird nur in auto_path uebernommen, nicht in tcl::tm::path.
# Fuer Tcl-Module (.tm) muss tm::path explizit gesetzt sein. Wir nehmen
# alle TCLLIBPATH-Eintraege auch in tm::path mit.
if {[info exists ::env(TCLLIBPATH)]} {
    foreach p $::env(TCLLIBPATH) {
        if {[file isdirectory $p]} {
            ::tcl::tm::path add $p
        }
    }
}

if {[catch {package require pdf4tcl} err]} {
    puts "SKIP: pdf4tcl nicht verfuegbar ($err)"
    exit 2
}
package require mdstack::parser 0.2
package require mdstack::pdf 0.2

set pass 0
set fail 0
set errors {}
# Temp-Dir plattform-unabhaengig via docir::util
package require docir::util
set tmpDir [docir::util::mktmpdir _test_mdpdf]

proc assert {name cond} {
    upvar pass pass fail fail errors errors
    set ok [uplevel 1 [list expr $cond]]
    if {$ok} {
        incr pass
    } else {
        incr fail
        lappend errors $name
        puts "  FAIL: $name"
    }
}

proc pdfFile {name} {
    global tmpDir
    return [file join $tmpDir ${name}.pdf]
}

proc exportMd {name md args} {
    global tmpDir
    set outFile [pdfFile $name]
    set ast [mdstack::parser::parse $md]
    mdstack::pdf::export $ast $outFile {*}$args
    return $outFile
}

proc pdfPages {file} {
    set fd [open $file r]
    fconfigure $fd -translation binary
    set data [read $fd]
    close $fd
    # Zaehle /Type /Page (ohne /Pages)
    set count 0
    set idx 0
    while {[set idx [string first "/Type /Page" $data $idx]] >= 0} {
        set after [string index $data [expr {$idx + 11}]]
        if {$after ne "s"} {
            incr count
        }
        incr idx 12
    }
    return $count
}

proc pdfValid {file} {
    if {![file exists $file]} { return 0 }
    if {[file size $file] < 100} { return 0 }
    set fd [open $file r]
    fconfigure $fd -translation binary
    set header [read $fd 8]
    close $fd
    return [string match "%PDF-*" $header]
}

puts "=== mdpdf Tests ==="
puts ""

# -- 1. Einfaches Dokument --
puts "--- Einfaches Dokument ---"
set f [exportMd "basic" "# Hallo\n\nEin einfacher Test."]
assert "basic-valid"  {[pdfValid $f]}
assert "basic-size"   {[file size $f] > 500}
assert "basic-pages"  {[pdfPages $f] >= 1}

# -- 2. Alle Heading-Levels --
puts "--- Headings ---"
set md "# H1\n\n## H2\n\n### H3\n\n#### H4\n\n##### H5\n\n###### H6"
set f [exportMd "headings" $md]
assert "headings-valid" {[pdfValid $f]}
# PDF should be bigger than basic (more content)
assert "headings-size"  {[file size $f] > [file size [pdfFile "basic"]]}

# -- 3. Textformatierung --
puts "--- Textformatierung ---"
set md "**Fett**, *kursiv*, ~~strike~~, `code`.\n\n***Fett und kursiv***."
set f [exportMd "format" $md]
assert "format-valid"   {[pdfValid $f]}

# -- 4. Tabelle --
puts "--- Tabelle ---"
set md "| Links | Mitte | Rechts |\n|:------|:-----:|-------:|\n| AAA | BBB | 100 |\n| CCC | DDD | 200 |"
set f [exportMd "table" $md]
assert "table-valid"    {[pdfValid $f]}

# -- 5. Tabelle mit langen Zellen (Truncation) --
puts "--- Tabelle mit langen Zellen ---"
set md "| Name | Beschreibung |\n|------|------|\n| Test | Dies ist ein sehr langer Zellentext der abgeschnitten werden sollte wenn er nicht in die Spalte passt |\n| Kurz | OK |"
set f [exportMd "table-long" $md]
assert "table-long-valid" {[pdfValid $f]}

# -- 6. Tabelle ohne Header --
puts "--- Tabelle ohne Header ---"
set md "| | |\n|---|---|\n| A | B |\n| C | D |"
set f [exportMd "table-noheader" $md]
assert "table-noheader-valid" {[pdfValid $f]}

# -- 7. Grosse Tabelle (Seitenumbruch) --
puts "--- Grosse Tabelle ---"
set rows "| Name | Wert |\n|------|------|\n"
for {set i 1} {$i <= 80} {incr i} {
    append rows "| Item $i | Wert $i |\n"
}
set f [exportMd "table-big" $rows]
assert "table-big-valid"  {[pdfValid $f]}
assert "table-big-pages"  {[pdfPages $f] >= 2}

# -- 8. Code-Bloecke --
puts "--- Code-Bloecke ---"
set md "```tcl\nproc test \{} \{\n    puts \"hello\"\n\}\n```\n\n~~~python\nprint(\"hi\")\n~~~\n\n    indented code"
set f [exportMd "code" $md]
assert "code-valid"     {[pdfValid $f]}

# -- 9. Blockquotes --
puts "--- Blockquotes ---"
set md "> Einfaches Zitat.\n\n> > Verschachteltes Zitat."
set f [exportMd "blockquote" $md]
assert "bq-valid"       {[pdfValid $f]}

# -- 10. Listen --
puts "--- Listen ---"
set md "- Punkt 1\n- Punkt 2\n  - Unterpunkt\n\n1. Eins\n2. Zwei\n\n- \[ \] Offen\n- \[x\] Erledigt"
set f [exportMd "lists" $md]
assert "lists-valid"    {[pdfValid $f]}

# -- 11. Definition Lists --
puts "--- Definition Lists ---"
set md "API\n: Application Programming Interface\n\nCLI\n: Command Line Interface"
set f [exportMd "deflist" $md]
assert "deflist-valid"  {[pdfValid $f]}

# -- 12. Horizontale Linien --
puts "--- Horizontale Linien ---"
set md "Text.\n\n---\n\nMehr Text.\n\n***\n\nNoch mehr.\n\n___"
set f [exportMd "hr" $md]
assert "hr-valid"       {[pdfValid $f]}

# -- 13. Footnotes --
puts "--- Footnotes ---"
set md "Text mit Fussnote\[^1\].\n\n\[^1\]: Die Fussnote."
set f [exportMd "footnotes" $md]
assert "fn-valid"       {[pdfValid $f]}

# -- 14. YAML Frontmatter + Titel --
puts "--- YAML Frontmatter ---"
set md "---\ntitle: Testdokument\nversion: 1.0\n---\n\n# Testdokument\n\nInhalt."
set f [exportMd "yaml" $md -title "Testdokument"]
assert "yaml-valid"     {[pdfValid $f]}

# -- 15. Header + Footer --
puts "--- Header/Footer ---"
set f [exportMd "headerfooter" "# Test\n\nInhalt." \
    -header "Kopfzeile - Seite %p" -footer "- %p -"]
assert "hf-valid"       {[pdfValid $f]}

# -- 16. TOC --
puts "--- Inhaltsverzeichnis ---"
set md "# Kapitel 1\n\nText.\n\n## Abschnitt 1.1\n\nMehr.\n\n# Kapitel 2\n\nNoch mehr."
set f [exportMd "toc" $md -toc 1]
assert "toc-valid"      {[pdfValid $f]}
assert "toc-bigger"     {[file size $f] > [file size [pdfFile "basic"]]}

# -- 17. Font-Groesse --
puts "--- Font-Groesse ---"
set md "# Heading\n\nText in verschiedenen Groessen."
set f8  [exportMd "font8" $md -fontsize 8]
set f14 [exportMd "font14" $md -fontsize 14]
assert "font8-valid"    {[pdfValid $f8]}
assert "font14-valid"   {[pdfValid $f14]}

# -- 18. Margin --
puts "--- Margin ---"
set f [exportMd "margin" "# Test\n\nInhalt." -margin 80]
assert "margin-valid"   {[pdfValid $f]}

# -- 19. Kombiniertes Dokument --
puts "--- Komplettes Dokument ---"
set md {---
title: Komplett-Test
version: 1.0
---

# Komplett-Test

**Fett**, *kursiv*, `code`, ~~strike~~.

## Tabelle

| A | B |
|---|---|
| 1 | 2 |

## Code

```tcl
puts "hello"
```

## Liste

- Punkt 1
- Punkt 2

> Zitat

---

API
: Application Programming Interface

Text mit Fussnote[^1].

[^1]: Fussnote.
}
set f [exportMd "komplett" $md -title "Komplett-Test" -toc 1 \
    -header "Test" -footer "Seite %p"]
assert "komplett-valid"  {[pdfValid $f]}
assert "komplett-pages"  {[pdfPages $f] >= 1}

# -- 20. Leeres Dokument --
puts "--- Leeres Dokument ---"
set f [exportMd "empty" ""]
assert "empty-valid"    {[pdfValid $f]}

# -- 21. Nur Heading --
puts "--- Nur Heading ---"
set f [exportMd "heading-only" "# Nur eine Ueberschrift"]
assert "heading-only"   {[pdfValid $f]}

# -- 22. Heading-Groessen pruefen --
puts "--- Heading-Groessen (fontSize=11) ---"
# Bei fontSize=11: H1=15pt, H2=13pt, H3=12pt, H4-H6=11pt
# Titel im TOC: fontSize+4 = 15pt, identisch mit H1
# Das ist dokumentiert und akzeptabel
set md "# H1 Test\n\n## H2 Test\n\n### H3 Test\n\n#### H4 Test"
set f [exportMd "hsizes" $md -fontsize 11]
assert "hsizes-valid"   {[pdfValid $f]}

# -- Aufraeumen --
file delete -force $tmpDir

# -- Summary --
puts ""
puts "========================================="
puts "  Result: $pass passed, $fail failed"
puts "========================================="
if {[llength $errors] > 0} {
    puts "\n  Failed:"
    foreach e $errors { puts "    - $e" }
}
exit $fail
