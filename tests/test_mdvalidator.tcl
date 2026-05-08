#!/usr/bin/env tclsh
# test_mdvalidator.tcl -- Tests fuer mdvalidator (AST Validator)
#
# Aufruf: tclsh test_mdvalidator.tcl

package require mdstack::parser 0.2
package require mdstack::validator 0.1

set pass 0
set fail 0
set errors {}

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

puts "=== mdvalidator Tests ==="
puts ""

# -- 1. Gueltiger AST --
puts "--- Gueltige Dokumente ---"

set md "# Titel\n\nText mit **bold** und `code`.\n\n- Liste\n- Items\n\n> Zitat"
set ast [mdstack::parser::parse $md]
set errs [mdstack::validator::validate $ast]
assert "valid-basic"    {[llength $errs] == 0}

# -- 2. Komplexes Dokument --
set md2 "---\ntitle: Komplex\n---\n\n# H1\n\n## H2\n\nText mit \[link\](url) und !\[img\](pic.png).\n\n```tcl\ncode\n```\n\n| A | B |\n|---|---|\n| 1 | 2 |\n\n---\n\nTerm\n:   Definition"
set ast2 [mdstack::parser::parse $md2]
set errs2 [mdstack::validator::validate $ast2]
assert "valid-complex"  {[llength $errs2] == 0}

# -- 3. Leeres Dokument --
set ast3 [mdstack::parser::parse ""]
set errs3 [mdstack::validator::validate $ast3]
assert "valid-empty"    {[llength $errs3] == 0}

# -- 4. Nur Frontmatter --
set ast4 [mdstack::parser::parse "---\ntitle: Nur Meta\n---"]
set errs4 [mdstack::validator::validate $ast4]
assert "valid-meta-only" {[llength $errs4] == 0}

# -- 5. Ungueltige ASTs (manuell konstruiert) --
puts "--- Ungueltige ASTs ---"

# Kein type key
set bad1 [dict create version 1 blocks {}]
set errs5 [mdstack::validator::validate $bad1]
assert "invalid-no-type" {[llength $errs5] > 0}

# Falscher type
set bad2 [dict create type paragraph version 1 blocks {} meta {}]
set errs6 [mdstack::validator::validate $bad2]
assert "invalid-wrong-type" {[llength $errs6] > 0}

# Kein blocks key
set bad3 [dict create type document version 1 meta {}]
set errs7 [mdstack::validator::validate $bad3]
assert "invalid-no-blocks" {[llength $errs7] > 0}

# -- 6. Block mit fehlendem Pflichtfeld --
puts "--- Block-Validierung ---"

# Heading ohne level
set bad4 [dict create type document version 1 meta {} blocks [list \
    [dict create type heading content {type text value Test}]] reflinks {}]
set errs8 [mdstack::validator::validate $bad4]
assert "invalid-heading-no-level" {[llength $errs8] > 0}

# -- 7. Strict Mode --
puts "--- Strict Mode ---"
set md5 "# Normal\n\nText."
set ast5 [mdstack::parser::parse $md5]
set errs_normal [mdstack::validator::validate $ast5]
set errs_strict [mdstack::validator::validate $ast5 -strict]
assert "strict-no-worse" {[llength $errs_strict] >= [llength $errs_normal]}

# -- 8. Alle Block-Typen --
puts "--- Alle Block-Typen ---"
set md6 "# Heading\n\nPara.\n\n- List\n\n> Quote\n\n```\nCode\n```\n\n---\n\n| T |\n|---|\n| D |\n\nTerm\n:  Def\n\n::: info\nDiv\n:::\n\n!\[img\](x.png)\n\nText\[^1\]\n\n\[^1\]: Fussnote"
set ast6 [mdstack::parser::parse $md6]
set errs6 [mdstack::validator::validate $ast6]
assert "all-blocks-valid" {[llength $errs6] == 0}

# Block-Typen zaehlen
set typeCount [dict create]
foreach b [dict get $ast6 blocks] {
    set t [dict get $b type]
    dict incr typeCount $t
}
assert "has-heading"    {[dict exists $typeCount heading]}
assert "has-paragraph"  {[dict exists $typeCount paragraph]}
assert "has-list"       {[dict exists $typeCount list]}
assert "has-blockquote" {[dict exists $typeCount blockquote]}
assert "has-code"       {[dict exists $typeCount code_block]}
assert "has-hr"         {[dict exists $typeCount hr]}
assert "has-table"      {[dict exists $typeCount table]}
assert "has-deflist"    {[dict exists $typeCount deflist]}
assert "has-image"      {[dict exists $typeCount image]}
assert "has-footnotes"  {[dict exists $typeCount footnote_section]}

# -- 9. Inline-Typen --
puts "--- Inline-Typen ---"
set md7 "**bold** *italic* ~~strike~~ `code` \[link\](url) !\[img\](pic) \[span\]\{.red\}"
set ast7 [mdstack::parser::parse $md7]
set errs7 [mdstack::validator::validate $ast7]
assert "all-inlines-valid" {[llength $errs7] == 0}

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
