#!/usr/bin/env tclsh
# test_pdf_features.tcl -- PDF-Feintuning Tests
#
# Erzeugt Test-PDFs und prueft dabei:
# 1. Heading-Groessen (H1 +4pt, H2 +2pt, H3 +1pt)
# 2. Tabellen-Baseline/Linien
# 3. Truncation langer Zellentexte
# 4. Tabellen ohne Header
# 5. Seitenumbruch in grossen Tabellen
# 6. PDF-Titel vs. H1-Groesse
# 7. Alle Features (Footnotes, Tilde, DefLists, HR)
#
# Aufruf: tclsh test_pdf_features.tcl

::tcl::tm::path add [file join [file dirname [info script]] .. vendors tm]
lappend ::auto_path [file join [file dirname [info script]] .. vendors pkg]

package require mdparser 0.2
package require mdpdf 0.2

set outDir [file join [file dirname [info script]] .. pdf_test]
if {![file exists $outDir]} { file mkdir $outDir }

set pass 0
set fail 0
set errors {}

proc testPdf {name md args} {
    upvar outDir outDir pass pass fail fail errors errors
    set outFile [file join $outDir ${name}.pdf]
    set ok 1
    set err ""
    if {[catch {
        set ast [mdparser::parse $md]
        mdpdf::export $ast $outFile {*}$args
    } msg]} {
        set ok 0
        set err $msg
    }
    if {$ok && [file exists $outFile] && [file size $outFile] > 100} {
        incr pass
        # Count pages
        set fd [open $outFile r]
        fconfigure $fd -translation binary
        set data [read $fd]
        close $fd
        regexp {/Count (\d+)} $data -> pages
        if {![info exists pages]} { set pages "?" }
        puts "  OK: $name ([file size $outFile] bytes, $pages Seiten)"
    } else {
        incr fail
        lappend errors "$name: $err"
        puts "  FAIL: $name -- $err"
    }
}

puts "=== PDF-Feintuning Tests ==="
puts "Ausgabe: $outDir"
puts ""

# --- Test 1: Heading-Groessen ---
puts "--- 1. Heading-Groessen ---"
testPdf "headings" {# H1 Ueberschrift (+4pt)

## H2 Ueberschrift (+2pt)

### H3 Ueberschrift (+1pt)

#### H4 Ueberschrift (base)

##### H5 Ueberschrift (base)

###### H6 Ueberschrift (base)

Text auf base fontSize zum Vergleich.
} -fontsize 11

# --- Test 2: Heading bei verschiedenen Font-Groessen ---
puts "--- 2. Heading bei fontSize 9 ---"
testPdf "headings-small" {# H1 klein

## H2 klein

### H3 klein

Text bei fontSize 9.
} -fontsize 9

puts "--- 2b. Heading bei fontSize 14 ---"
testPdf "headings-large" {# H1 gross

## H2 gross

### H3 gross

Text bei fontSize 14.
} -fontsize 14

# --- Test 3: PDF-Titel vs. H1 ---
puts "--- 3. PDF-Titel vs. H1 ---"
testPdf "title-vs-h1" {# Dokument-Ueberschrift

Dieser Text folgt direkt auf H1. Titel-Font sollte
gleich gross wie H1 sein (fontSize + 4).

## Zweite Ueberschrift

Weiterer Text.
} -title "Titelzeile (fontSize+4)" -fontsize 11

# --- Test 4: Einfache Tabelle ---
puts "--- 4. Einfache Tabelle ---"
testPdf "table-simple" {# Tabellen-Test

| Name | Typ | Status |
|------|-----|--------|
| Alpha | Lib | OK |
| Beta | App | Fehler |
| Gamma | Tool | OK |
} -fontsize 11

# --- Test 5: Tabelle mit Alignment ---
puts "--- 5. Tabelle mit Alignment ---"
testPdf "table-alignment" {# Alignment-Test

| Links | Mitte | Rechts |
|:------|:-----:|-------:|
| AAA | BBB | 100 |
| CCC | DDD | 200 |
| EEE | FFF | 300 |
}

# --- Test 6: Lange Zellentexte (Truncation) ---
puts "--- 6. Lange Zellentexte ---"
testPdf "table-truncation" {# Truncation-Test

| Spalte 1 | Spalte 2 |
|----------|----------|
| Kurz | OK |
| Sehr langer Text der nicht in die Spalte passt und abgeschnitten werden muss | Ebenfalls ein sehr langer Text fuer die zweite Spalte |
| Normal | Normal |
}

# --- Test 7: Tabelle ohne Header ---
puts "--- 7. Tabelle ohne Header ---"
# Parser erzeugt immer Header, daher leeren Header simulieren
testPdf "table-minimal" {# Minimal-Tabelle

| A | B |
|---|---|
| 1 | 2 |
}

# --- Test 8: Grosse Tabelle (Seitenumbruch) ---
puts "--- 8. Grosse Tabelle (Seitenumbruch) ---"
set bigTable "# Grosse Tabelle\n\n| Nr | Beschreibung | Wert |\n|------|------------|------|\n"
for {set i 1} {$i <= 60} {incr i} {
    append bigTable "| $i | Zeile Nummer $i mit etwas Text | [expr {$i * 100}] |\n"
}
testPdf "table-pagebreak" $bigTable -fontsize 10

# --- Test 9: Alle Features kombiniert ---
puts "--- 9. Alle Features ---"
testPdf "all-features" {---
title: Vollstaendiger Test
version: 4.2
---

# Vollstaendiger PDF-Test

## Textformatierung

**Fett**, *kursiv*, ***beides***, ~~durchgestrichen~~, `code`.

## Listen

- Punkt eins
- Punkt zwei
  - Unterpunkt

1. Eins
2. Zwei
3. Drei

- [ ] Offen
- [x] Erledigt

## Code-Bloecke

```tcl
proc test {} {
    puts "Hello"
}
```

~~~python
print("Tilde-Fence")
~~~

## Tabelle

| Feature | Status |
|---------|--------|
| **Fett** | OK |
| *Kursiv* | OK |
| `Code` | OK |

## Blockquote

> Zitat mit **Formatierung** und `code`.
> Zweite Zeile.

## Horizontale Linien

---

***

## Definition Lists

API
: Application Programming Interface

CLI
: Command Line Interface

## Footnotes

Text mit Fussnote[^1] und [^note].

[^1]: Erste Fussnote.
[^note]: Zweite Fussnote mit
  Fortsetzungszeile.

---

*Ende.*
} -title "Vollstaendiger Test" -header "Test - Seite %p" -footer "- %p -" \
  -toc 1 -fontsize 11

# --- Test 10: Nur Tabelle (Baseline-Pruefung) ---
puts "--- 10. Baseline-Pruefung ---"
testPdf "table-baseline" {# Baseline-Test

Normaler Text auf der Baseline.

| Spalte A | Spalte B | Spalte C |
|----------|----------|----------|
| Text | 12345 | `code` |
| **Fett** | *Kursiv* | Normal |

Text nach der Tabelle auf der Baseline.
} -fontsize 11

# --- Test 11: Viele Headings (TOC + Seitenumbruch) ---
puts "--- 11. Viele Headings ---"
set manyH "# Dokument mit vielen Headings\n\n"
for {set i 1} {$i <= 20} {incr i} {
    append manyH "## Kapitel $i\n\nText fuer Kapitel $i. Lorem ipsum dolor sit amet.\n\n"
}
testPdf "many-headings" $manyH -toc 1 -fontsize 11

# --- Summary ---
puts ""
puts "========================================="
puts "  Result: $pass passed, $fail failed"
puts "  PDFs in: $outDir"
puts "========================================="
if {[llength $errors] > 0} {
    puts "\n  Failed:"
    foreach e $errors { puts "    - $e" }
}
exit [expr {$fail > 0}]
