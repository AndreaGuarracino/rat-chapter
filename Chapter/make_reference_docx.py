#!/usr/bin/env python3
"""Regenerate the pandoc reference.docx used to style the Word build.

Pandoc's default DOCX output styles code blocks in Cambria (the Normal
font) and leaves body text left-aligned. Springer MiMB expects code
blocks in monospace and body text justified. This script:

  1. asks pandoc for its default reference.docx
  2. patches word/styles.xml so that:
       - SourceCode  -> Consolas 10pt, left-aligned
       - VerbatimChar -> (pandoc's default Consolas, kept)
       - Normal, BodyText, FirstParagraph, Compact, Abstract -> justified
       - Heading1-6, Caption*, Figure*, Bibliography, Author, Title,
         Subtitle, AbstractTitle, Date, DefinitionTerm, Definition,
         BlockText -> left-aligned
  3. writes the result to ./reference.docx

The resulting reference.docx is fed to pandoc via --reference-doc when
building chapter.docx (see README.md and CLAUDE.md for the full build
command).

Usage:
    python3 make_reference_docx.py

The output (reference.docx) is committed to the repository so that the
build is reproducible without needing to re-run this script. Re-run only
when the styling rules in this file change.
"""
import logging
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

logging.basicConfig(
    level=logging.INFO,
    format="[make_reference_docx] %(levelname)s: %(message)s",
    stream=sys.stderr,
)
log = logging.getLogger(__name__)

OUT = Path(__file__).parent / "reference.docx"

JUSTIFY_STYLES = ("Normal", "BodyText", "FirstParagraph", "Compact", "Abstract")
LEFT_STYLES = (
    "SourceCode",
    "Heading1", "Heading2", "Heading3", "Heading4", "Heading5", "Heading6",
    "Caption", "TableCaption", "ImageCaption", "Figure", "CaptionedFigure",
    "Bibliography", "Author", "Title", "Subtitle", "AbstractTitle", "Date",
    "DefinitionTerm", "Definition", "BlockText",
)
# SourceCode rPr to inject (Consolas 10pt). pandoc's default has no rPr,
# so the body text font (Cambria) wins; this fixes that.
SOURCECODE_RPR = (
    '<w:rPr>'
    '<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" w:cs="Consolas"/>'
    '<w:sz w:val="20"/>'
    '</w:rPr>'
)


def add_jc(styles_xml: str, style_id: str, val: str) -> str:
    """Add or replace <w:jc w:val="VAL"/> inside the <w:pPr> of style_id."""
    assert val in ("both", "left", "right", "center"), f"invalid alignment: {val}"
    pattern = (
        r'(<w:style w:type="[^"]+"(?:[^>]*)?w:styleId="'
        + re.escape(style_id)
        + r'"[^>]*>)(.*?)(</w:style>)'
    )
    m = re.search(pattern, styles_xml, re.DOTALL)
    if not m:
        log.debug("style %s not present, skipping", style_id)
        return styles_xml
    head, body, tail = m.group(1), m.group(2), m.group(3)
    body = re.sub(r"<w:jc w:val=\"[^\"]+\"\s*/>", "", body)
    inject = f'<w:jc w:val="{val}"/>'
    if "<w:pPr>" in body:
        body = body.replace("<w:pPr>", f"<w:pPr>{inject}", 1)
    elif "<w:pPr/>" in body:
        body = body.replace("<w:pPr/>", f"<w:pPr>{inject}</w:pPr>", 1)
    else:
        new_pPr = f"<w:pPr>{inject}</w:pPr>"
        if "<w:rPr>" in body:
            body = body.replace("<w:rPr>", new_pPr + "<w:rPr>", 1)
        else:
            body = new_pPr + body
    return styles_xml.replace(m.group(0), head + body + tail)


SOURCECODE_STYLE = (
    '<w:style w:type="paragraph" w:customStyle="1" w:styleId="SourceCode">'
    '<w:name w:val="Source Code"/>'
    '<w:basedOn w:val="Normal"/>'
    '<w:link w:val="VerbatimChar"/>'
    '<w:pPr><w:wordWrap w:val="off"/></w:pPr>'
    '<w:rPr><w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" w:cs="Consolas"/><w:sz w:val="20"/></w:rPr>'
    '</w:style>'
)


def add_sourcecode_font(styles_xml: str) -> str:
    """Ensure the SourceCode paragraph style exists with Consolas 10pt.

    pandoc's default reference.docx does NOT include the SourceCode style;
    it is added on the fly the first time pandoc encounters a code block.
    The auto-added style has no font set, so it inherits Cambria from
    Normal. To force Consolas, we inject a SourceCode definition into
    reference.docx; pandoc then uses ours instead of generating its own.
    """
    pattern = (
        r'(<w:style w:type="paragraph"(?:[^>]*)?w:styleId="SourceCode"[^>]*>)(.*?)(</w:style>)'
    )
    m = re.search(pattern, styles_xml, re.DOTALL)
    if m:
        log.info("SourceCode style already present in reference.docx; replacing with Consolas-styled version")
        return styles_xml.replace(m.group(0), SOURCECODE_STYLE)
    log.info("SourceCode style not in reference.docx; injecting Consolas-styled version")
    return styles_xml.replace("</w:styles>", SOURCECODE_STYLE + "</w:styles>")


def main() -> int:
    log.info("asking pandoc for the default reference.docx")
    with tempfile.TemporaryDirectory() as td:
        tmp_ref = Path(td) / "default-reference.docx"
        with tmp_ref.open("wb") as fh:
            subprocess.run(
                ["pandoc", "--print-default-data-file", "reference.docx"],
                stdout=fh,
                check=True,
            )
        log.info("default reference.docx is %d bytes", tmp_ref.stat().st_size)

        with zipfile.ZipFile(tmp_ref, "r") as z:
            styles = z.read("word/styles.xml").decode("utf-8")

        log.info("patching SourceCode style to use Consolas 10pt")
        styles = add_sourcecode_font(styles)

        log.info("setting %d styles to justified: %s", len(JUSTIFY_STYLES), ", ".join(JUSTIFY_STYLES))
        for sid in JUSTIFY_STYLES:
            styles = add_jc(styles, sid, "both")

        log.info("setting %d styles to left-aligned: %s", len(LEFT_STYLES), ", ".join(LEFT_STYLES))
        for sid in LEFT_STYLES:
            styles = add_jc(styles, sid, "left")

        log.info("writing patched styles back into a new reference.docx at %s", OUT)
        with zipfile.ZipFile(tmp_ref, "r") as zin, zipfile.ZipFile(
            OUT, "w", zipfile.ZIP_DEFLATED
        ) as zout:
            for item in zin.namelist():
                data = zin.read(item)
                if item == "word/styles.xml":
                    data = styles.encode("utf-8")
                zout.writestr(item, data)

        log.info("done: %s (%d bytes)", OUT, OUT.stat().st_size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
