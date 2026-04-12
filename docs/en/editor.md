# Editor

mdhelp has an integrated Markdown editor with live preview.

## Opening the Editor

Three ways to open the editor:

- **Ctrl+E** -- edits the currently displayed file
- **Toolbar** -- click "Edit"
- **Right-click** in the file tree > "Open in Editor"

The editor opens as a new tab in the main window.
You can edit multiple files simultaneously.
Each tab shows the filename; unsaved changes
are marked with an asterisk (*).

## Editor Tab Layout

**Format Toolbar** (top): Save/Close buttons, Undo/Redo,
format buttons (Bold, Italic, Code, Headings, Lists, Tables),
TIP-700 buttons (Span, Div, YAML) and mode switcher.

**Outline** (left): Heading treeview. Click jumps to line.
Updates automatically on changes.

**Editor** (center): Text field for the Markdown source.

**Preview** (right): Shows the rendered result in real time.
Preview updates 400ms after the last input.
Editor and preview scroll synchronously.

**Status Bar** (bottom): Line number, line type and change indicator.

## Format Toolbar

Select text and click a button to apply formatting.
Without selection, formatting is inserted at the cursor position.

| Button | Result | Markdown |
|---|---|---|
| B | **Bold** | `**Text**` |
| I | *Italic* | `*Text*` |
| <> | `Code` | `` `Text` `` |
| H1 | Heading 1 | `# Text` |
| H2 | Heading 2 | `## Text` |
| H3 | Heading 3 | `### Text` |
| List | Bullet list | `- Text` |
| Quote | Blockquote | `> Text` |
| Task | Task | `- [ ] Text` |
| ``` | Code block | Triple backtick |
| Table | 3x3 table | Pipe syntax |

## TIP-700 Toolbar

Three buttons for Tcl man page markup:

**Span**: Menu button with 10 semantic classes. Wraps the
selection in `[text]{.class}` syntax. Without selection, a
placeholder is inserted. Classes: cmd, sub, lit, optlit, arg,
optarg, ins, ccmd, cargs, ret.

**Div**: Menu button with 5 div classes. Inserts a fenced div block
`::: {.class}`. With selection, the marked text is enclosed.
Classes: synopsis, example, arguments, note, warning.

**YAML**: Inserts a frontmatter template at the file beginning
with title, section and manual-section.

## Outline Panel

The outline panel on the left shows all headings as a tree.
Clicking a heading jumps to the corresponding line in the editor
and briefly highlights it yellow.

The outline updates automatically on every change.

## Smart Editing

The editor supports intelligent input helpers:

**Smart Return:** When pressing Enter in a list, the list marker
is automatically continued:

```
- First item       <- press Enter
- |                <- inserted automatically
```

For numbered lists, the number is incremented:

```
1. First item      <- press Enter
2. |               <- next number automatically
```

A second Enter on an empty list item ends the list.

**Tab / Shift+Tab:** Indents or outdents the current line.
Also works with multiple selected lines.

```
- Main item
  - Sub-item       <- indented with Tab
    - Deeper       <- Tab again
```

**Checkbox Toggle:** Space key on a checkbox toggles
between `[ ]` and `[x]`.

## Context Menu

Right-click in the editor opens a menu with:

| Entry | Action |
|---|---|
| Cut | Cut selected text |
| Copy | Copy selected text |
| Paste | Paste from clipboard |
| Select All | Select entire text |
| Bold | Format selection as bold |
| Italic | Format selection as italic |
| Code | Format selection as code |
| Insert Link | Open link dialog |
| Insert Image | Open image dialog |
| Insert Table | Table at cursor position |
| Separator | Insert horizontal rule |

## Modes

The radio buttons in the toolbar let you switch modes:

**Split** (default): Editor and preview side by side.
Ideal for writing with immediate feedback.

**Editor**: Only the text editor, full width.
For focused writing.

**Preview**: Only the rendered view.
For checking the result.

## Saving

**Ctrl+S** saves the file. The title changes from
`* Edit - file.md` back to `Edit - file.md`.

**Save + Close**: Saves and closes the editor tab.

If the edited file is currently shown in the viewer,
the viewer updates automatically after saving.

## Unsaved Changes

The change indicator `[MODIFIED]` in the status bar and
the asterisk `*` in the tab title indicate unsaved changes.

When closing the editor with unsaved changes, a dialog appears:

- **Yes** -- save and close
- **No** -- discard and close
- **Cancel** -- return to editor

## Tips

- Open the editor alongside the viewer for maximum overview
- Use Tab indentation for nested lists
- Table insertion creates a 3x3 template you can customize
- Smart Return also works with blockquotes (`>`)

## Spellcheck

If **aspell** or **hunspell** is installed, mdhelp checks
spelling automatically in the editor. Misspelled words
are underlined in red.

### On/Off

The **ABC** button in the toolbar toggles the check on and off.
It is enabled by default.

**F7** starts a complete check of the entire document.
The status bar shows the number of errors found.

### Correction

Right-click on a red-underlined word shows a menu with:

- **Suggestions** (up to 8) -- click to replace the word
- **Ignore Word** -- removes the marking for this session
- **Add Word** -- like ignore, but remembers the word

### Language

The default language is `de_DE`. aspell/hunspell must have the
corresponding dictionary installed.

Installation (examples):

```
# Linux (Debian/Ubuntu)
sudo apt install aspell aspell-de

# Linux (Fedora)
sudo dnf install aspell aspell-de
```

### What Is Not Checked?

Code blocks, inline code, link URLs and Markdown syntax are
excluded from the check. Only prose text is checked.

## Next

- [Keyboard Shortcuts](shortcuts.md) -- all shortcuts at a glance
- [Markdown Reference](markdown-syntax.md) -- look up syntax
