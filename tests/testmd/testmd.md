# Markdown Rendering Test

This document tests Markdown rendering and PDF generation in mdhelp.

---

# 1 Headings

## Level 2 Heading

### Level 3 Heading

#### Level 4 Heading

---

# 2 Paragraphs

This is a normal paragraph used to test line wrapping and paragraph spacing.

This is another paragraph to verify spacing between paragraphs.

This paragraph contains **bold text**, *italic text*, and **bold with *italic* inside**.

---

# 3 Inline Code

Example of inline code:

Use the command `package require tablelist_tile`.

Another example:

`dict get $item name`

---

# 4 Code Blocks

Example Tcl code:

```
proc hello {} {
    puts "Hello World"
}
```

More complex example:

```
try {
    set data [read $fd]
} on error {msg opts} {
    log::error $msg
    return -options $opts $msg
} finally {
    close $fd
}
```

---

# 5 Lists

## Unordered List

* first item
* second item
* third item

Nested list:

* item

  * sub item
  * sub item
* item

## Ordered List

1. first
2. second
3. third

---

# 6 Tables

## 6.1 Simple Table

| Name  | Age | City    |
| ----- | --- | ------- |
| Alice | 30  | Berlin  |
| Bob   | 41  | Hamburg |
| Carol | 25  | Munich  |

## 6.2 Table with Long Cell Content (Wrap Test)

The following table has cells with long text that must wrap within the column.

| Parameter      | Description                                                                                             | Default      |
| -------------- | ------------------------------------------------------------------------------------------------------- | ------------ |
| -fontsize      | Font size in points used for all body text in the generated PDF document                                | 11           |
| -margin        | Page margin in PDF points applied uniformly to all four sides of every page                             | 50           |
| -pagesize      | Paper format for the output document, one of: A4, A5, Letter, Legal, or any custom WxH specification   | A4           |
| -title         | Document title embedded in the PDF metadata and optionally displayed in the page header of the document | (empty)      |
| -landscape     | Rotate the page to landscape orientation, so width and height are exchanged                             | 0            |
| -toc           | Generate a table of contents at the beginning of the document from all heading levels 1 through 3      | 0            |
| -header        | Header template string shown at top of each page, %p is replaced by the current page number            | (empty)      |
| -footer        | Footer template string shown at bottom of each page, %p is replaced by the current page number         | Page %p      |

## 6.3 Table with Mixed Alignments

| Product        | Price   | Stock | Notes                                              |
| -------------- | ------: | :---: | -------------------------------------------------- |
| Widget A       |   12.50 |  100  | Standard model, available in red, blue, and green  |
| Widget B       |   24.99 |   42  | Pro version with extended warranty                 |
| Widget C       |    8.00 |  500  | Economy model, single color only                   |
| Special Bundle |  199.00 |    5  | Includes all variants plus accessories and manual  |

## 6.4 Headerless Table

| proc      | _renderBlock   | Main render loop, dispatches by block type          |
| proc      | _renderStyledLine | Renders one line with mixed bold/italic/code segments |
| proc      | _wrapStyledSegments | Word-wrap a list of styled segments to maxW       |
| proc      | _drawTableHeader | Draw header row with wrapping, returns new y      |
| proc      | _drawTableVLines | Draw vertical column lines for one page segment  |
| proc      | _tablePageBreak | Page break inside table, repeats header if present |

## 6.5 Large Table (Page Break Test)

This table has enough rows to force a page break. The header should be
repeated on the continuation page, and the vertical lines must be
drawn correctly per page segment.

| Nr  | Command               | Namespace             | Since | Description                                    |
| --- | --------------------- | --------------------- | ----- | ---------------------------------------------- |
| 01  | proc                  | ::tcl                 | 7.0   | Define a named procedure with arguments        |
| 02  | namespace eval        | ::tcl                 | 8.0   | Create or enter a namespace                    |
| 03  | namespace ensemble    | ::tcl                 | 8.5   | Create ensemble command from namespace         |
| 04  | package require       | ::tcl                 | 7.5   | Load a package by name and version             |
| 05  | package provide       | ::tcl                 | 7.5   | Declare the name and version of a package      |
| 06  | source                | ::tcl                 | 7.0   | Read and evaluate a Tcl script file            |
| 07  | uplevel               | ::tcl                 | 7.0   | Execute script in a different call frame       |
| 08  | upvar                 | ::tcl                 | 7.0   | Link variable to a variable in another frame   |
| 09  | variable              | ::tcl                 | 8.0   | Declare namespace variable                     |
| 10  | set                   | ::tcl                 | 7.0   | Assign or retrieve a variable value            |
| 11  | unset                 | ::tcl                 | 7.0   | Delete one or more variables                   |
| 12  | array get             | ::tcl                 | 7.4   | Return array as flat key-value list            |
| 13  | array set             | ::tcl                 | 7.4   | Initialize array from flat key-value list      |
| 14  | array names           | ::tcl                 | 7.4   | Return list of matching array keys             |
| 15  | dict create           | ::tcl                 | 8.5   | Create a new dictionary value                  |
| 16  | dict get              | ::tcl                 | 8.5   | Retrieve value from dictionary by key          |
| 17  | dict set              | ::tcl                 | 8.5   | Set value in dictionary, returns new dict      |
| 18  | dict exists           | ::tcl                 | 8.5   | Test whether key exists in dictionary          |
| 19  | dict keys             | ::tcl                 | 8.5   | Return list of all keys in dictionary          |
| 20  | dict for              | ::tcl                 | 8.5   | Iterate over dictionary key-value pairs        |
| 21  | lappend               | ::tcl                 | 7.0   | Append elements to a list variable             |
| 22  | lindex                | ::tcl                 | 7.0   | Retrieve element from list by index            |
| 23  | linsert               | ::tcl                 | 7.0   | Insert elements into a list at given index     |
| 24  | llength               | ::tcl                 | 7.0   | Return number of elements in a list            |
| 25  | lrange                | ::tcl                 | 7.0   | Return sublist between two indices             |
| 26  | lsearch               | ::tcl                 | 7.0   | Search list for matching element               |
| 27  | lsort                 | ::tcl                 | 7.0   | Sort list with configurable options            |
| 28  | lreplace              | ::tcl                 | 7.0   | Replace elements in list at index range        |
| 29  | string length         | ::tcl                 | 7.0   | Return number of characters in string          |
| 30  | string index          | ::tcl                 | 7.0   | Return character at given position             |
| 31  | string range          | ::tcl                 | 7.0   | Return substring between two indices           |
| 32  | string map            | ::tcl                 | 8.1   | Replace substrings using mapping list          |
| 33  | string match          | ::tcl                 | 7.0   | Glob-style pattern matching                    |
| 34  | regexp                | ::tcl                 | 7.0   | Regular expression matching                    |
| 35  | regsub                | ::tcl                 | 7.0   | Regular expression substitution               |
| 36  | format                | ::tcl                 | 7.0   | Format string like C printf                    |
| 37  | scan                  | ::tcl                 | 7.0   | Parse string like C scanf                      |
| 38  | expr                  | ::tcl                 | 7.0   | Evaluate mathematical expression               |
| 39  | incr                  | ::tcl                 | 7.0   | Increment integer variable by delta            |
| 40  | if                    | ::tcl                 | 7.0   | Conditional execution with elseif and else     |
| 41  | switch                | ::tcl                 | 7.0   | Multi-branch conditional dispatch              |
| 42  | while                 | ::tcl                 | 7.0   | Loop while condition is true                   |
| 43  | for                   | ::tcl                 | 7.0   | C-style loop with init, test, step             |
| 44  | foreach               | ::tcl                 | 7.0   | Iterate variable over list elements            |
| 45  | break                 | ::tcl                 | 7.0   | Exit innermost loop immediately                |
| 46  | continue              | ::tcl                 | 7.0   | Skip remainder of current loop iteration       |
| 47  | return                | ::tcl                 | 7.0   | Return from procedure with optional value      |
| 48  | error                 | ::tcl                 | 7.0   | Raise an error with message and info           |
| 49  | catch                 | ::tcl                 | 7.0   | Catch errors and return result code            |
| 50  | try                   | ::tcl                 | 8.6   | Structured exception handling with on/trap     |

---

# 7 Blockquotes

> This is a blockquote.
>
> It should be indented and visually separated from normal text.

---

# 8 Horizontal Rules

Below this line should be a horizontal rule.

---

Text continues after the rule.

---

# 9 Tree Structures

Filesystem tree example:

```
project/
├─ app/
│  └─ main.tcl
├─ src/
│  ├─ model/
│  ├─ actions/
│  └─ ui/
└─ lib/
```

---

# 10 Long Text

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed non risus. Suspendisse lectus tortor, dignissim sit amet, adipiscing nec, ultricies sed, dolor.

Cras elementum ultrices diam. Maecenas ligula massa, varius a, semper congue, euismod non, mi.

---

# 11 Mixed Formatting

This line contains **bold**, *italic*, `inline code`, and a link:

https://example.com

---

# 12 Special Characters

Characters to test UTF-8 handling:

ä ö ü ß
Ä Ö Ü
€ £ ¥

---

# 13 Large Code Block

```
namespace eval ::app::model {

    proc newItem {} {
        return [dict create id "" name "" created ""]
    }

    proc validateItem {item} {

        if {[dict get $item name] eq ""} {
            error "Name required"
        }

        return $item
    }

}
```

---

# 14 Copy Paste Test

The following text must be selectable in the PDF.

Example command:

```
tclsh main.tcl --test
```

---

# 15 Page Break Test

Content before page break.

Content after page break.

---

# End of Document
