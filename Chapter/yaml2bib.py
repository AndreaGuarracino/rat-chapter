#!/usr/bin/env python3
"""
Convert Hayagriva YAML bibliography (references.yml) to BibTeX (references.bib).

The pandoc Word-export pipeline (see README.md) needs a .bib sidecar because
pandoc does not read Hayagriva YAML natively. This script treats references.yml
as the single source of truth and emits a one-shot references.bib.

Usage:
    python3 yaml2bib.py references.yml > references.bib

Only handles the entry types currently used in this repo: article, web, thesis.
"""

import logging
import sys
from typing import Any

import yaml

logging.basicConfig(
    level=logging.INFO,
    format="[yaml2bib] %(levelname)s: %(message)s",
    stream=sys.stderr,
)
log = logging.getLogger(__name__)


def escape_bibtex(value: str) -> str:
    """Escape characters that have special meaning in BibTeX field values."""
    assert isinstance(value, str), f"expected str, got {type(value).__name__}"
    result = value
    # Order matters: escape backslash first, then the rest.
    result = result.replace("\\", "\\\\")
    result = result.replace("&", "\\&")
    result = result.replace("%", "\\%")
    result = result.replace("$", "\\$")
    result = result.replace("#", "\\#")
    result = result.replace("_", "\\_")
    return result


def format_one_author(a: Any) -> str:
    """Convert one Hayagriva author entry to BibTeX form.

    Handles three input shapes:
    - 'Family, Given' string with comma -> emit as-is
    - 'Corporate Name' string with no comma -> wrap in {{...}} so BibTeX
      treats it as a corporate author and does not split on whitespace
    - Mapping with 'name', optional 'given-name', optional 'prefix' ->
      assemble 'Prefix Family, Given' for personal authors, or
      '{{Name}}' for corporate (no given-name)
    """
    if isinstance(a, str):
        if "," in a:
            return a
        # Corporate / mononymous author: brace it so BibTeX does not
        # parse 'Hall Lab' as a personal name 'Lab, H'.
        return "{" + a + "}"
    if isinstance(a, dict):
        name = str(a.get("name", "")).strip()
        given = str(a.get("given-name") or a.get("given") or "").strip()
        prefix = str(a.get("prefix") or "").strip()
        suffix = str(a.get("suffix") or "").strip()
        if not name:
            raise ValueError(f"author dict missing 'name': {a}")
        if given:
            family = (prefix + " " + name).strip() if prefix else name
            # Brace multi-word family names so BibTeX does not parse a
            # leading lowercase particle (de, van, von) as a von-form.
            # Example: 'de Jong' -> '{de Jong}'.
            if " " in family:
                family = "{" + family + "}"
            out = f"{family}, {given}"
            if suffix:
                out += f", {suffix}"
            return out
        # Corporate: brace it
        return "{" + name + "}"
    raise TypeError(f"unexpected author item type: {type(a).__name__}: {a!r}")


def format_authors(author_field: Any) -> str:
    """Join a Hayagriva author list into BibTeX form."""
    if author_field is None:
        return ""
    if isinstance(author_field, (str, dict)):
        items = [author_field]
    elif isinstance(author_field, list):
        items = author_field
    else:
        raise TypeError(
            f"unexpected author field type: {type(author_field).__name__}"
        )
    return " and ".join(format_one_author(a) for a in items)


def year_from_date(date_field: Any) -> str:
    """Pull a 4-digit year out of a Hayagriva date field."""
    if date_field is None:
        return ""
    text = str(date_field)
    # Hayagriva dates may be 'YYYY' or 'YYYY-MM-DD'.
    return text.split("-", 1)[0]


def extract_doi(entry: dict) -> str:
    """Pull the DOI out of the serial-number block if present."""
    serial = entry.get("serial-number")
    if serial is None:
        return ""
    if isinstance(serial, dict):
        return str(serial.get("doi", "")).strip()
    if isinstance(serial, str):
        return serial.strip()
    return ""


def extract_url(entry: dict) -> str:
    """Pull the URL out of the url block if present."""
    url = entry.get("url")
    if url is None:
        return ""
    if isinstance(url, dict):
        return str(url.get("value", "")).strip()
    if isinstance(url, str):
        return url.strip()
    return ""


def render_entry(key: str, entry: dict) -> str:
    """Render a single Hayagriva entry as a BibTeX record."""
    assert isinstance(entry, dict), f"{key}: expected mapping"
    etype = entry.get("type", "article")

    fields: list[tuple[str, str]] = []

    title = entry.get("title")
    if title:
        # Wrap title in extra braces to preserve capitalization in BibTeX.
        fields.append(("title", "{" + escape_bibtex(str(title)) + "}"))

    author_str = format_authors(entry.get("author"))
    if author_str:
        fields.append(("author", escape_bibtex(author_str)))

    year = year_from_date(entry.get("date"))
    if year:
        fields.append(("year", year))

    doi = extract_doi(entry)
    if doi:
        # DOIs may contain underscores (e.g. mulligan2017's
        # 10.1007/978-1-4939-6427-7_4). BibTeX/citeproc treats the doi
        # field as URL-like, so do NOT escape special chars here.
        fields.append(("doi", doi))

    url = extract_url(entry)
    if url:
        # URLs likewise must not be backslash-escaped, or pandoc emits
        # literal \_ in the rendered hyperlink.
        fields.append(("url", url))

    page_range = entry.get("page-range")
    if page_range is not None:
        fields.append(("pages", escape_bibtex(str(page_range))))

    parent = entry.get("parent") or {}
    parent_title = ""
    if isinstance(parent, dict):
        parent_title = str(parent.get("title") or "")
        # For chapters, parent.title is the BOOK title -> goes in 'booktitle'.
        # For everything else, parent.title is the JOURNAL/venue -> goes in 'journal'.
        if etype == "chapter":
            if parent_title:
                # Brace-wrap booktitle so BibTeX/citeproc preserves capitals.
                fields.append(("booktitle", "{" + escape_bibtex(parent_title) + "}"))
            editors = parent.get("editor")
            if editors:
                fields.append(("editor", escape_bibtex(format_authors(editors))))
            pub = parent.get("publisher")
            if pub:
                fields.append(("publisher", escape_bibtex(str(pub))))
        else:
            if parent_title:
                # Brace-wrap journal name so multi-word journals (e.g.
                # "Cell Host & Microbe") keep their case.
                fields.append(("journal", "{" + escape_bibtex(parent_title) + "}"))
        if parent.get("volume") is not None:
            fields.append(("volume", escape_bibtex(str(parent["volume"]))))
        if parent.get("issue") is not None:
            fields.append(("number", escape_bibtex(str(parent["issue"]))))

    if etype == "thesis":
        bib_type = "phdthesis"
        publisher = entry.get("publisher") or entry.get("organization")
        if publisher:
            fields.append(("school", escape_bibtex(str(publisher))))
    elif etype == "web":
        # BibLaTeX @online maps cleanly to CSL "webpage" so pandoc renders
        # the URL. (@misc maps to a generic type that the Springer CSL
        # silently drops the URL from.)
        bib_type = "online"
        if url and not any(k == "howpublished" for k, _ in fields):
            fields.append(("howpublished", "\\url{" + url + "}"))
        # Hayagriva web entries carry an access date inside the url block;
        # surface it as urldate for BibLaTeX/CSL.
        url_field = entry.get("url")
        if isinstance(url_field, dict):
            access = url_field.get("date")
            if access:
                fields.append(("urldate", escape_bibtex(str(access))))
    elif etype == "chapter":
        bib_type = "incollection"
    else:
        bib_type = "article"

    log.debug("rendering %s as @%s with %d fields", key, bib_type, len(fields))

    lines = [f"@{bib_type}{{{key},"]
    for name, value in fields:
        lines.append(f"  {name} = {{{value}}},")
    lines.append("}")
    return "\n".join(lines)


def main() -> int:
    if len(sys.argv) != 2:
        log.error("usage: yaml2bib.py <references.yml>")
        return 2

    input_path = sys.argv[1]
    log.info("reading %s", input_path)
    with open(input_path, "r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle)

    if not isinstance(data, dict):
        log.error("top-level YAML is not a mapping")
        return 1

    log.info("found %d entries", len(data))
    type_counts: dict[str, int] = {}
    for key, entry in data.items():
        etype = (entry or {}).get("type", "article")
        type_counts[etype] = type_counts.get(etype, 0) + 1
    log.info("entry types: %s", type_counts)

    print("% Auto-generated from references.yml by yaml2bib.py")
    print("% DO NOT EDIT by hand. Edit references.yml and regenerate.")
    print()
    for key, entry in data.items():
        try:
            print(render_entry(key, entry or {}))
            print()
        except Exception as exc:
            log.error("failed to render %s: %s", key, exc)
            return 1

    log.info("done")
    return 0


if __name__ == "__main__":
    sys.exit(main())
