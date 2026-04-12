# Markdown Reference

This page shows the Markdown syntax supported by mdhelp.
It also serves as a rendering test.

## Headings

Headings are created with `#`. The count determines the level:

```markdown
# Heading 1
## Heading 2
### Heading 3
#### Heading 4
```

Optional closing hashes are removed: `## Title ##` yields "Title".

## Text Formatting

**Bold** is written with double asterisks: `**bold**`

*Italic* is written with single asterisks: `*italic*`

**Combined** also works: `***bold and italic***` yields ***bold and italic***.

~~Strikethrough~~ with double tildes: `~~strikethrough~~`

`Inline code` with backticks: `` `code` ``

Double backticks for code with backticks: ``` ``code with `backtick` inside`` ```

### Backslash Escapes

Special characters can be escaped with backslash:
`\*not italic\*`, `\[not a link\]`

Supported escape characters: `* _ ` ~ [ ] ( ) \ ! # + - . { } |`

### Hard Line Break

Two spaces at the end of a line create a break within
the paragraph (without starting a new paragraph):

```markdown
First line  
Second line (same paragraph)
```

## Links

Inline links with URL in parentheses:

```markdown
[Quick Start](quickstart.md)
[Section](viewer.md#search)
[Tcl/Tk](https://www.tcl.tk)
```

Links with title (shown as tooltip):

```markdown
[Tcl/Tk](https://www.tcl.tk "Official Site")
```

Anchor links jump within the page:

```markdown
[Back to top](#markdown-reference)
```

### Reference Links

Define links separately and reference them by label:

```markdown
Read the [documentation][docs] for details.

[docs]: features.md "Feature overview"
```

Shortcut references use the link text as label:

```markdown
See [features] for details.

[features]: features.md
```

### Autolinks

URLs in angle brackets are automatically linked:

```markdown
<https://www.tcl.tk>
<user@example.com>
```

Bare URLs (https://...) in running text are also recognized.

## Images

### Standalone Image

An image on its own line is rendered as a block:

```markdown
![Alt text](image.png)
![With title](image.png "Title text")
```

### Inline Image

An image within text is rendered inline:

```markdown
Text with ![icon](icon.png) embedded.
```

### Reference Images

```markdown
![Screenshot][screen]

[screen]: screenshot.png "Main window"
```

## Lists

### Unordered Lists

```markdown
- First item
- Second item
  - Sub-item A
  - Sub-item B
    - Deeply nested
- Third item
```

### Ordered Lists

```markdown
1. Step one
2. Step two
3. Step three
```

### Task Lists

```markdown
- [x] Task done
- [ ] Task open
- [ ] Another task
```

### Lists with Formatting

```markdown
- Item with **bold** and `code` in one item
- Item with *italic* text
```

## Code Blocks

### Backtick Fence with Language

````markdown
```tcl
proc hello {name} {
    puts "Hello, $name!"
}
```
````

### Tilde Fence

````markdown
~~~python
def hello(name):
    print(f"Hello, {name}!")
~~~
````

### Indented Code (4 Spaces)

```markdown
    set x 42
    puts $x
```

## Tables

### Simple Table

```markdown
| Name | Value |
|------|-------|
| A    | 1     |
| B    | 2     |
```

### Table with Alignment

```markdown
| Left   | Center | Right |
|:-------|:------:|------:|
| text   | text   | text  |
```

### Table with Formatting

```markdown
| Feature | Status  |
|---------|---------|
| **Bold** | `code` |
| *Italic* | ~~old~~ |
```

## Blockquotes

```markdown
> Simple quote spanning
> multiple lines.
```

### Quote with Formatting

```markdown
> Text with **bold** and *italic*.
```

### Nested Blockquotes

```markdown
> Outer quote
> > Inner quote
> > Second line inside
> Back outside
```

## Horizontal Rules

Three different variants:

```markdown
---
***
___
```

## Definition Lists

```markdown
Term
: Definition of the term.

Another Term
: First definition.
: Second definition.
```

## Footnotes

```markdown
Text with footnote[^1] and named reference[^note].

[^1]: First footnote.
[^note]: Second footnote with
  continuation line (2 spaces indentation).
```

In the viewer, references appear as clickable links.
At the page bottom, definitions are shown with a separator line.

## YAML Frontmatter

```markdown
---
title: Document Title
section: n
version: 8.6
---
```

Must be at the very beginning of the file.

## Fenced Divs (TIP 700)

```markdown
::: {.synopsis}
**command** *arg1* ?*arg2*?
:::
```

Classes: synopsis, example, arguments, note, warning.

## Bracketed Spans (TIP 700)

```markdown
[command]{.cmd} [argument]{.arg}
```

See [Features](features.md) for the full list of classes.

## Anchor Navigation

Heading anchors are set automatically. Links like
`[Back to top](#markdown-reference)` jump to the heading.
