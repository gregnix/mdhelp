#!/usr/bin/env tclsh
# test_mdmodel.tcl -- Tests fuer mdmodel (Document Model)
#
# Aufruf: tclsh test_mdmodel.tcl

package require mdstack::parser 0.2
package require mdstack::model 0.1

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

puts "=== mdmodel Tests ==="
puts ""

# -- 1. Grundfunktionen --
puts "--- Model erstellen ---"

set md "---\ntitle: Test\nversion: 1.0\n---\n\n# Kapitel 1\n\nText.\n\n## Abschnitt 1.1\n\nMehr Text.\n\n# Kapitel 2\n\nNoch mehr.\n\n### Tief verschachtelt"

set ast [mdstack::parser::parse $md]
set doc [mdstack::model::new $ast]

assert "model-created"  {$doc ne ""}
assert "model-ast"      {[mdstack::model::ast $doc] ne ""}

# -- 2. Meta --
puts "--- Meta ---"
set meta [mdstack::model::meta $doc]
assert "meta-title"     {[dict get $meta title] eq "Test"}
assert "meta-version"   {[dict get $meta version] eq "1.0"}

# -- 3. Headings / TOC --
puts "--- Headings ---"
set headings [mdstack::model::headings $doc]
assert "heading-count"  {[llength $headings] == 4}

set h1 [lindex $headings 0]
assert "h1-level"       {[dict get $h1 level] == 1}
assert "h1-text"        {[dict get $h1 text] eq "Kapitel 1"}

set h2 [lindex $headings 1]
assert "h2-level"       {[dict get $h2 level] == 2}
assert "h2-text"        {[dict get $h2 text] eq "Abschnitt 1.1"}

set h3 [lindex $headings 2]
assert "h3-level"       {[dict get $h3 level] == 1}
assert "h3-text"        {[dict get $h3 text] eq "Kapitel 2"}

set h4 [lindex $headings 3]
assert "h4-level"       {[dict get $h4 level] == 3}
assert "h4-text"        {[dict get $h4 text] eq "Tief verschachtelt"}

# -- 4. TOC --
puts "--- TOC ---"
set toc [mdstack::model::toc $doc]
assert "toc-count"      {[llength $toc] == 4}

# -- 5. Anchors --
puts "--- Anchors ---"
set anchors [mdstack::model::anchors $doc]
assert "anchor-k1"      {[dict exists $anchors "kapitel-1"]}
assert "anchor-a11"     {[dict exists $anchors "abschnitt-1-1"]}

# -- 6. Find --
puts "--- Find ---"
set results [mdstack::model::find $doc "Text"]
assert "find-text"      {[llength $results] > 0}

set results2 [mdstack::model::find $doc "NICHT_VORHANDEN_XYZ"]
assert "find-none"      {[llength $results2] == 0}

# -- 7. Dokument ohne Meta --
puts "--- Ohne Meta ---"
set md2 "# Einfach\n\nNur Text."
set ast2 [mdstack::parser::parse $md2]
set doc2 [mdstack::model::new $ast2]
set meta2 [mdstack::model::meta $doc2]
assert "no-meta"        {[llength [dict keys $meta2]] == 0}

# -- 8. Leeres Dokument --
puts "--- Leeres Dokument ---"
set md3 ""
set ast3 [mdstack::parser::parse $md3]
set doc3 [mdstack::model::new $ast3]
set headings3 [mdstack::model::headings $doc3]
assert "empty-headings"  {[llength $headings3] == 0}

# -- 9. Heading mit Inline-Formatting --
puts "--- Heading mit Formatting ---"
set md4 "# **Bold** and *italic* title"
set ast4 [mdstack::parser::parse $md4]
set doc4 [mdstack::model::new $ast4]
set h [lindex [mdstack::model::headings $doc4] 0]
assert "fmt-heading"     {[string match "*Bold*" [dict get $h text]]}
assert "fmt-heading-clean" {![string match "*\\**" [dict get $h text]]}

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
