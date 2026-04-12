# PDF Export

mdhelp can export the current document as a PDF file.

## Prerequisites

PDF export requires the Tcl package **pdf4tcl**.
mdhelp includes pdf4tcl 0.9.4 (in `vendors/pkg/`),
as well as **pdf4tcllib** (Unicode, emoji fallbacks, fonts) in `vendors/tm/`.

If pdf4tcl is not found, the menu entry is grayed out
and the PDF button in the toolbar is not available.

## Start Export

There are two ways:

- **Toolbar:** Click the "PDF" button
- **Menu:** File > Export PDF

A save dialog opens. The suggested filename
corresponds to the document name with `.pdf` extension.

## What Is Exported?

PDF export renders the content of the viewer window:

**Headings** are displayed with adjusted font size.
A page break is inserted before H1 and H2 headings.

**Tables** are exported with frames and zebra stripes,
including the frame tables from the viewer.

**Code blocks** appear in monospace font with background.

**Images** are embedded if they are available in the file system.

**Page numbers** appear in the footer.

## Limitations

- External images (URLs) are not downloaded
- Very large images may exceed the page width
- Complex nested lists may be simplified

## Tips

- Check the result in the viewer before exporting
- For professional PDFs, adjust the font size beforehand
- H1 headings automatically start a new page

Back to [Home](../index.md).
