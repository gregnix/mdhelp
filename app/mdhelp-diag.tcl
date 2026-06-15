#!/usr/bin/env tclsh
# mdhelp-diag.tcl -- Diagnose fuer "key type not known" + fehlende Math/Mermaid.
# Aufruf MIT DERSELBEN tm::path-Umgebung wie mdhelp (also so starten,
# wie du mdhelp startest -- z.B. via deinem ~/.tclshrc), dann:
#   tclsh mdhelp-diag.tcl /pfad/zu/KOMPLEX-SHOWCASE.md
#
# Gibt aus: geladene Versionen + Dateipfade, AST-Knoten ohne "type",
# und den vollstaendigen errorInfo beim HTML-/PDF-Export.

if {[llength $argv] < 1} { puts "Usage: tclsh mdhelp-diag.tcl <file.md>"; exit 1 }
set mdFile [lindex $argv 0]

puts "=== tcl::tm::path ==="
foreach p [tcl::tm::path list] { puts "  $p" }
puts "=== auto_path (erste 6) ==="
foreach p [lrange $::auto_path 0 5] { puts "  $p" }

proc whichPkg {name} {
    if {[catch {package require $name} v]} { puts "  $name: NICHT LADBAR ($v)"; return }
    set src "?"
    catch { set src [package ifneeded $name $v] }
    # Dateipfad aus dem ifneeded-Script ziehen (source ...)
    set file "?"
    if {[regexp {source [^\}]*?([^ \t\}]+\.tm)} $src -> f]} { set file $f }
    puts "  $name $v   <- $file"
}
puts "=== Geladene Pakete ==="
foreach n {mdstack::parser mdstack::html mdstack::pdf docir::mdSource docir::pdf docir::html} { whichPkg $n }

set fh [open $mdFile]; fconfigure $fh -encoding utf-8; set md [read $fh]; close $fh
set ast [mdstack::parser::parse $md]

# AST nach Knoten ohne "type" durchsuchen (die Crash-Ursache)
proc astScan {node path} {
    if {[catch {dict size $node} ok] || !$ok} return
    if {![dict exists $node type]} {
        puts "  >> Knoten OHNE type bei $path : keys={[dict keys $node]}"
    }
    foreach k {children inlines blocks items rows cells content} {
        if {[dict exists $node $k]} {
            set v [dict get $node $k]
            set i 0
            foreach c $v {
                if {![catch {dict size $c}]} { astScan $c "$path/$k\[$i\]" }
                incr i
            }
        }
    }
}
puts "=== AST-Scan: Knoten ohne type ==="
set i 0
foreach b [dict get $ast blocks] { astScan $b "blocks\[$i\]"; incr i }
puts "  (wenn nichts: keine type-losen Knoten gefunden)"

puts "=== HTML-Export (math+mermaid an) ==="
if {[catch {mdstack::html::export $ast /tmp/diag.html -title T -toc 1 -enableMath 1 -enableMermaid 1} e]} {
    puts "  CRASH: $e"
    puts "  --- errorInfo ---"
    foreach l [split $::errorInfo \n] { puts "    $l" }
} else { puts "  ok ([file size /tmp/diag.html] b)" }

puts "=== PDF-Export ==="
if {[catch {mdstack::pdf::export $ast /tmp/diag.pdf -title T -root [file dirname $mdFile]} e]} {
    puts "  CRASH: $e"
} else { puts "  ok ([file size /tmp/diag.pdf] b)" }
