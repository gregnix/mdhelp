# Create Your Own Documentation

How to create a documentation project for mdhelp.

## Create Directory

Create a directory with your Markdown files:

```
my-docs/
+-- index.md          Home page
+-- chapter1.md       First chapter
+-- chapter2.md       Second chapter
+-- api/
|   +-- index.md      API overview
|   +-- endpoints.md
+-- images/
    +-- logo.png
```

## Home Page (index.md)

The `index.md` is the home page of your project.
It is automatically displayed when:

- Starting mdhelp
- Clicking on a folder in the file tree
- Clicking the Home button (Alt+Home)

A good home page contains links to all important pages:

```markdown
# My Project

Welcome to the documentation.

## Contents

| Topic | Page |
|---|---|
| Introduction | [Chapter 1](chapter1.md) |
| Advanced | [Chapter 2](chapter2.md) |
| API | [API Reference](api/index.md) |
```

## Generate Index Automatically

Via `File > Generate Index` mdhelp automatically creates
table of contents for all directories.

The generated content is inserted in managed blocks:

```markdown
<!-- BEGIN mdhelp-index -->
(automatically generated -- do not edit manually)
<!-- END mdhelp-index -->
```

Your own text outside the blocks remains intact.
This way you can write an introduction and let the rest
be generated automatically.

## Links Between Documents

Relative links reference other files:

```markdown
See [Chapter 1](chapter1.md) for details.
```

Links with anchors jump directly to a heading:

```markdown
Direct to [section](chapter1.md#installation).
```

Links to parent directories with `..`:

```markdown
Back to [home](../index.md).
```

## Tables

Tables with pipe characters and optional alignment:

```markdown
| Left | Center | Right |
|:-----|:------:|------:|
| AAA  | BBB    |   100 |
```

Result:

| Left | Center | Right |
|:-----|:------:|------:|
| AAA | BBB | 100 |
| CCC | DDD | 200 |

## Embed Images

Reference images relative to the document:

```markdown
![Logo](images/logo.png)
```

Supported formats: PNG, JPG, GIF. SVG if tksvg is installed.

## Edit Files

Directly in mdhelp with Ctrl+E or right-click > "Open in Editor".
Details under [Editor](../editor.md).

## Start Project

```
wish mdhelp.tcl ./my-docs
```

Or in mdhelp: Ctrl+O > Select directory.

Back to [Home](../index.md).
