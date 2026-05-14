# HTML Style Themes

This directory contains alternative CSS themes for mdhelp's HTML
export. mdhelp's `Export HTML…` dialog reads `*.css` files from this
directory and offers them in a style selection combo box.

## Bundled themes

| File              | Description                                |
|-------------------|--------------------------------------------|
| `sticky-top.css`  | TOC fixed at the top, scrolls with the page (max 40 % viewport height) |
| `sidebar.css`     | TOC on the left as a 280 px sidebar, body on the right |
| `collapsible.css` | TOC collapsed by default, expands on hover or focus |

All themes use a font stack with monochrome fallback fonts (DejaVu
Sans, Symbola, Segoe UI Symbol) so that special glyphs (Em-Dash,
arrows, currency, smart quotes, the warning sign ⚠) render without
inflating line height. Color emoji fonts are intentionally not part
of the stack.

## Adding your own themes

Drop any `*.css` file into this directory. mdhelp picks it up
automatically and lists it as `Custom: <basename>` in the style combo
box. You can also point to an arbitrary CSS file via `Custom file…`
in the same dialog.

## HTML structure to style

The HTML produced by `mdstack::html` (which uses `docir::html` under
the hood) follows a fixed structure with the following key selectors:

```html
<nav class="toc">
  <ul>
    <li class="toc-level-1"><a href="#anchor">Heading</a></li>
    <li class="toc-level-2"><a href="#anchor">Sub-Heading</a></li>
    <li class="toc-level-3">…</li>
  </ul>
</nav>
<h1 id="…">…</h1>
<p>…</p>
<h2 id="…">…</h2>
…
```

For the full list of CSS classes (including manpage headers, list
variants, table styles, footnotes), see the schema documentation in
the docir repository at `docir/doc/html-css-schema.md`.

## CSS Grid pitfall

If you use `body { display: grid }` for a sidebar layout, set
`grid-column` explicitly on every direct child of `<body>`. Otherwise
CSS grid auto-placement distributes items alternately across columns,
hiding roughly half of the document content behind the sidebar. The
shipped `sidebar.css` shows the correct pattern:

```css
body { display: grid; grid-template-columns: 280px 1fr; }
nav.toc { grid-column: 1; grid-row: 1 / -1; }
body > *:not(nav.toc) { grid-column: 2; }
```

## License

The bundled themes are released under the same MIT License as the rest
of mdhelp 4. Copy and modify them freely.
