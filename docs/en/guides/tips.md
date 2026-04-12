# Tips and Tricks

Useful hints for everyday use with mdhelp.

## Quick Navigation

**Bookmarks** for frequently visited pages: Ctrl+D on the
desired page, then access directly via the Bookmarks menu.

**Recent Folders** remember the 10 most recently opened directories.
Via File > Recent Folders you can quickly switch between projects.

**Use TOC:** The table of contents at the bottom left is the fastest
way to jump within a long document.

## Efficient Search

**Global Search** finds terms in all files. Switch
to "All Files" in the search bar, then Enter. The results list
shows file and line -- a click opens the location directly.

**Page Search** for quick finding in the current document.
F3 jumps forward, Shift+F3 backward through matches.

## Use Editor Productively

**Split Mode** is ideal: You see the source text on the left and
the result immediately on the right.

**Smart Return** saves time with lists. Type the first
list item, then Enter does the rest:

```
- Point one [Enter]
- |  <- automatically
```

**Insert Tables:** The table button creates a 3x3 template.
Adjust the number of columns and add rows.

**Context Menu:** Right-click provides quick access to
formatting, links and tables without the toolbar.

## Structure Documentation

**index.md** is the home page of each directory. mdhelp opens
it automatically on startup and when clicking on a folder.

**Subdirectories** for topic groups:

```
my-project/
+-- index.md           Home page
+-- getting-started.md
+-- api/
|   +-- index.md       API overview
|   +-- endpoints.md
+-- guides/
    +-- index.md       Guides overview
    +-- tutorial.md
```

**Generate Index:** File > Generate Index automatically creates
table of contents for all directories.

**Relative Links** keep documentation portable:

```markdown
See [API](api/index.md) and [back](../index.md).
```

## Optimize Display

**Font Size** adjust: Ctrl+Plus / Ctrl+Minus.
The setting is saved automatically.

**Frame Tables** look better than simple text tables.
Use the pipe syntax with alignment:

```markdown
| Name | Value |
|:-----|-----:|
| Alpha | 100 |
```

The colon at the dash determines alignment:
`:---` left, `:---:` center, `---:` right.

## Avoid Errors

**Special Characters in Filenames:** Avoid spaces and
umlauts in filenames. Use dashes: `my-document.md`.

**Broken Links:** After renaming a file, check
if all links still work. Global search helps with this.

**Large Files:** Very large Markdown files (>1000 lines)
can affect rendering speed.
Split them into smaller files.

Back to [Home](../index.md).
