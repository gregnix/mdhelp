#!/usr/bin/env tclsh
# test_commonmark.tcl -- CommonMark-Abdeckungstests fuer mdparser
#
# Prueft Parser-Ausgabe gegen erwartete AST-Strukturen.
# Aufruf: tclsh test_commonmark.tcl

::tcl::tm::path add [file join [file dirname [info script]] .. vendors tm]
package require mdparser 0.2

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

proc blockTypes {md} {
    set ast [mdparser::parse $md]
    set types {}
    foreach b [dict get $ast blocks] {
        lappend types [dict get $b type]
    }
    return $types
}

proc inlineTypes {md} {
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    if {![dict exists $block content]} { return {} }
    set types {}
    foreach i [dict get $block content] {
        lappend types [dict get $i type]
    }
    return $types
}

proc headingLevel {md} {
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    dict get $block level
}

proc headingText {md} {
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    set txt ""
    foreach i [dict get $block content] {
        if {[dict get $i type] eq "text"} {
            append txt [dict get $i value]
        }
    }
    return $txt
}

proc codeInfo {md} {
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    list [dict get $block language] [string trim [dict get $block text]]
}

proc linkUrl {md} {
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    set link [lindex [dict get $block content] 0]
    dict get $link url
}

proc metaKey {md key} {
    set ast [mdparser::parse $md]
    if {[dict exists [dict get $ast meta] $key]} {
        return [dict get [dict get $ast meta] $key]
    }
    return ""
}

puts "=== CommonMark-Abdeckungstests ==="
puts ""

# -- 1. ATX Headings --
puts "--- ATX Headings ---"
assert "h1"         {[headingLevel "# H1"] == 1}
assert "h2"         {[headingLevel "## H2"] == 2}
assert "h3"         {[headingLevel "### H3"] == 3}
assert "h4"         {[headingLevel "#### H4"] == 4}
assert "h5"         {[headingLevel "##### H5"] == 5}
assert "h6"         {[headingLevel "###### H6"] == 6}
assert "h1-text"    {[headingText "# Hello World"] eq "Hello World"}
assert "h-closing"  {[headingText "## Foo ##"] eq "Foo"}

# -- 2. Paragraphs --
puts "--- Paragraphs ---"
assert "para"       {[blockTypes "Hello\n\nWorld"] eq {paragraph paragraph}}
assert "para-cont"  {[blockTypes "Hello\nWorld"] eq {paragraph}}

# -- 3. Thematic Breaks --
puts "--- Thematic Breaks ---"
assert "hr-dash"    {[blockTypes "---"] eq {hr}}
assert "hr-star"    {[blockTypes "***"] eq {hr}}
assert "hr-under"   {[blockTypes "___"] eq {hr}}
assert "hr-long"    {[blockTypes "----------"] eq {hr}}

# -- 4. Fenced Code --
puts "--- Fenced Code ---"
assert "fence-backtick" {[blockTypes "```\ncode\n```"] eq {code_block}}
assert "fence-tilde"    {[blockTypes "~~~\ncode\n~~~"] eq {code_block}}
assert "fence-lang"     {[lindex [codeInfo "```tcl\nputs hi\n```"] 0] eq "tcl"}
assert "fence-empty"    {[lindex [codeInfo "```\n\n```"] 0] eq ""}

# -- 5. Indented Code --
puts "--- Indented Code ---"
assert "indent-code" {[blockTypes "    code line 1\n    code line 2"] eq {code_block}}

# -- 6. Emphasis --
puts "--- Emphasis ---"
assert "em"          {[inlineTypes "Hello *world*"] eq {text emphasis}}
assert "strong"      {[inlineTypes "Hello **world**"] eq {text strong}}
assert "strong-em"   {[inlineTypes "***both***"] eq {strong}}
assert "strike"      {[inlineTypes "~~gone~~"] eq {strike}}

# -- 7. Code Spans --
puts "--- Code Spans ---"
assert "code-single" {[inlineTypes "`code`"] eq {inline_code}}
assert "code-double" {[inlineTypes "``co`de``"] eq {inline_code}}

# -- 8. Links --
puts "--- Links ---"
assert "link"        {[inlineTypes "\[text\](url)"] eq {link}}
assert "link-url"    {[linkUrl "\[t\](http://x.com)"] eq "http://x.com"}
assert "autolink"    {[inlineTypes "<https://x.com>"] eq {link}}
assert "mailto"      {[inlineTypes "<user@x.com>"] eq {link}}
assert "bare-url"    {[inlineTypes "see https://x.com here"] eq {text link text}}

# -- 9. Images --
puts "--- Images ---"
assert "image"       {[inlineTypes "text !\[alt\](img.png) text"] eq {text image text}}

# -- 10. Lists --
puts "--- Lists ---"
assert "ul"          {[blockTypes "- item 1\n- item 2"] eq {list}}
assert "ol"          {[blockTypes "1. item 1\n2. item 2"] eq {list}}

# -- 11. Blockquotes --
puts "--- Blockquotes ---"
assert "bq"          {[blockTypes "> quoted\n> text"] eq {blockquote}}

# -- 12. Tables --
puts "--- Tables ---"
assert "table"       {[blockTypes "| A | B |\n|---|---|\n| 1 | 2 |"] eq {table}}

# -- 13. Hard Line Breaks --
puts "--- Line Breaks ---"
set md "line one  \nline two"
set ast [mdparser::parse $md]
set para [lindex [dict get $ast blocks] 0]
set types {}
foreach i [dict get $para content] { lappend types [dict get $i type] }
assert "hard-break" {[lsearch -exact $types linebreak] >= 0}

# -- 14. Backslash Escapes --
puts "--- Backslash Escapes ---"
assert "esc-star"    {[inlineTypes "\\*not italic\\*"] eq {text text text}}
assert "esc-bracket" {[inlineTypes "\\\[not link\\\]"] eq {text text text}}

# -- 15. Reference Links --
puts "--- Reference Links ---"
set md "\[link text\]\[ref\]\n\n\[ref\]: http://example.com"
set ast [mdparser::parse $md]
set para [lindex [dict get $ast blocks] 0]
set first [lindex [dict get $para content] 0]
assert "reflink"     {[dict get $first type] eq "link"}
assert "reflink-url" {[dict get $first url] eq "http://example.com"}

# -- 16. YAML Frontmatter --
puts "--- YAML Frontmatter ---"
assert "yaml-title"  {[metaKey "---\ntitle: Hello\n---\ntext" title] eq "Hello"}
assert "yaml-multi"  {[metaKey "---\ntitle: T\nversion: 1.0\n---\ntext" version] eq "1.0"}

# -- 17. Definition Lists --
puts "--- Definition Lists ---"
assert "deflist"     {[blockTypes "Term\n:   Definition"] eq {deflist}}

# -- 18. Pandoc Divs --
puts "--- Pandoc Divs ---"
assert "div"         {[blockTypes "::: info\ntext\n:::"] eq {div}}

# -- 19. Footnotes --
puts "--- Footnotes ---"
set md "Text\[^1\]\n\n\[^1\]: Fussnote."
set ast [mdparser::parse $md]
set types [blockTypes $md]
assert "fn-section"  {"footnote_section" in $types}
set para [lindex [dict get $ast blocks] 0]
set itypes {}
foreach i [dict get $para content] { lappend itypes [dict get $i type] }
assert "fn-ref"      {"footnote_ref" in $itypes}

# -- 20. Bracketed Spans (TIP-700) --
puts "--- Bracketed Spans ---"
assert "span"        {[inlineTypes "\[text\]\{.red\}"] eq {span}}

# -- 21. Standalone Images --
puts "--- Standalone Images ---"
assert "standalone-img" {[blockTypes "!\[alt\](image.png)"] eq {image}}

# -- 22. Nested Emphasis Edge Cases --
puts "--- Nested Emphasis ---"
set ast [mdparser::parse "**bold *and italic* text**"]
set para [lindex [dict get $ast blocks] 0]
set strong [lindex [dict get $para content] 0]
assert "nested-em-in-strong" {[dict get $strong type] eq "strong"}

# -- 23. Link in Emphasis --
puts "--- Link in Emphasis ---"
set ast [mdparser::parse "*\[link\](url)*"]
set para [lindex [dict get $ast blocks] 0]
set em [lindex [dict get $para content] 0]
assert "link-in-em" {[dict get $em type] eq "emphasis"}
set inner [lindex [dict get $em content] 0]
assert "link-in-em-content" {[dict get $inner type] eq "link"}

# -- 24. Multiple Blocks Sequence --
puts "--- Block Sequence ---"
set md "# Title\n\nParagraph.\n\n- list\n\n> quote\n\n---\n\n```\ncode\n```"
set types [blockTypes $md]
assert "block-seq" {$types eq {heading paragraph list blockquote hr code_block}}

# -- 25. HR Variants --
puts "--- HR Variants ---"
assert "hr-stars"     {[blockTypes "***"] eq {hr}}
assert "hr-undscr"    {[blockTypes "___"] eq {hr}}
assert "hr-dash5"     {[blockTypes "-----"] eq {hr}}
assert "hr-star5"     {[blockTypes "*****"] eq {hr}}
assert "hr-spc"       {[blockTypes "- - -"] eq {hr}}
assert "hr-spc-star"  {[blockTypes "* * *"] eq {hr}}

# -- 26. Fenced Code Tilde --
puts "--- Fenced Code Tilde ---"
assert "tilde-fence"  {[blockTypes "~~~\ncode\n~~~"] eq {code_block}}
assert "tilde-lang"   {[lindex [codeInfo "~~~python\nprint(1)\n~~~"] 0] eq "python"}

# -- 27. Heading Closing Hashes --
puts "--- Heading Closing Hashes ---"
assert "h2-close"     {[headingText "## Foo ##"] eq "Foo"}
assert "h3-close"     {[headingText "### Bar ###"] eq "Bar"}
assert "h1-no-close"  {[headingText "# Normal"] eq "Normal"}

# -- 28. Emphasis Edge Cases --
puts "--- Emphasis Edge Cases ---"
# Intra-word: mid*word*mid should still match
assert "em-intra"     {"emphasis" in [inlineTypes "mid*word*end"]}
# Nested bold in italic
set ast [mdparser::parse "*italic **bold** text*"]
set para [lindex [dict get $ast blocks] 0]
set em [lindex [dict get $para content] 0]
assert "bold-in-italic" {[dict get $em type] eq "emphasis"}

# -- 29. Code Span Edge Cases --
puts "--- Code Span Edge Cases ---"
set ast [mdparser::parse "Use ``foo `bar` baz`` here"]
set para [lindex [dict get $ast blocks] 0]
set code [lindex [dict get $para content] 1]
assert "dbl-backtick-inner" {[dict get $code type] eq "inline_code"}
assert "dbl-backtick-val"   {[dict get $code value] eq "foo `bar` baz"}

# -- 30. Link Title --
puts "--- Link Title ---"
set ast [mdparser::parse "\[text\](url \"My Title\")"]
set para [lindex [dict get $ast blocks] 0]
set link [lindex [dict get $para content] 0]
assert "link-title"    {[dict get $link title] eq "My Title"}

# -- 31. Image Title --
puts "--- Image Title ---"
set ast [mdparser::parse "text !\[alt\](img.png \"caption\") more"]
set para [lindex [dict get $ast blocks] 0]
set img {}
foreach i [dict get $para content] {
    if {[dict get $i type] eq "image"} { set img $i; break }
}
assert "img-title"     {$img ne "" && [dict get $img title] eq "caption"}

# -- 32. Nested Blockquotes --
puts "--- Nested Blockquotes ---"
set md "> level 1\n>> level 2\n>>> level 3"
set ast [mdparser::parse $md]
set bq1 [lindex [dict get $ast blocks] 0]
assert "bq-outer"      {[dict get $bq1 type] eq "blockquote"}
# Inner structure depends on parser nesting
assert "bq-has-blocks"  {[dict exists $bq1 blocks]}

# -- 33. Ordered List Start Number --
puts "--- Ordered List Start ---"
set ast [mdparser::parse "1. first\n2. second\n3. third"]
set lst [lindex [dict get $ast blocks] 0]
assert "ol-type"       {[dict get $lst type] eq "list"}
assert "ol-items"      {[llength [dict get $lst items]] == 3}

# -- 34. Mixed List --
puts "--- Mixed Content ---"
set md "- item with **bold** and `code`"
set ast [mdparser::parse $md]
set lst [lindex [dict get $ast blocks] 0]
set item [lindex [dict get $lst items] 0]
set itypes {}
# Items may have blocks inside
if {[dict exists $item blocks]} {
    set pb [lindex [dict get $item blocks] 0]
    if {[dict exists $pb content]} {
        foreach i [dict get $pb content] { lappend itypes [dict get $i type] }
    }
} elseif {[dict exists $item content]} {
    foreach i [dict get $item content] { lappend itypes [dict get $i type] }
}
assert "list-inline-mix" {"strong" in $itypes && "inline_code" in $itypes}

# -- 35. Empty Document --
puts "--- Edge Cases ---"
assert "empty-doc"     {[blockTypes ""] eq {}}
assert "whitespace"    {[blockTypes "   \n   \n   "] eq {}}

# -- 36. Consecutive Headings --
assert "consec-headings" {[blockTypes "# One\n## Two\n### Three"] eq {heading heading heading}}

# -- 37. Reference Image --
puts "--- Reference Images ---"
set md "!\[photo\]\[img1\]\n\n\[img1\]: /path/to/image.png"
set ast [mdparser::parse $md]
set para [lindex [dict get $ast blocks] 0]
set first [lindex [dict get $para content] 0]
assert "ref-image"     {[dict get $first type] eq "image"}
assert "ref-image-url" {[dict get $first url] eq "/path/to/image.png"}

# -- 38. Multiple Footnotes --
puts "--- Multiple Footnotes ---"
set md "A\[^a\] and B\[^b\].\n\n\[^a\]: Alpha\n\[^b\]: Beta"
set ast [mdparser::parse $md]
set fnsec {}
foreach b [dict get $ast blocks] {
    if {[dict get $b type] eq "footnote_section"} { set fnsec $b; break }
}
assert "multi-fn"      {$fnsec ne ""}
assert "multi-fn-count" {[llength [dict get $fnsec footnotes]] == 2}

# -- 39. Multiline Footnote --
puts "--- Multiline Footnote ---"
set md "Text\[^ml\].\n\n\[^ml\]: First line\n  second line\n  third line"
set ast [mdparser::parse $md]
set fnsec {}
foreach b [dict get $ast blocks] {
    if {[dict get $b type] eq "footnote_section"} { set fnsec $b; break }
}
set fnDef [lindex [dict get $fnsec footnotes] 0]
set fnText ""
foreach c [dict get $fnDef content] {
    if {[dict get $c type] eq "text"} { append fnText [dict get $c value] }
}
assert "ml-fn-text"    {[string match "*second*" $fnText]}

# -- 40. Task Lists --
puts "--- Task Lists ---"
set md "- \[ \] unchecked\n- \[x\] checked"
set ast [mdparser::parse $md]
set lst [lindex [dict get $ast blocks] 0]
assert "task-list" {[dict get $lst type] eq "list"}

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
