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


def format_authors(author_field: Any) -> str:
    """Join a Hayagriva author list ('Last, First') into BibTeX form."""
    if author_field is None:
        return ""
    if isinstance(author_field, str):
        authors = [author_field]
    elif isinstance(author_field, list):
        authors = [str(a) for a in author_field]
    else:
        raise TypeError(
            f"unexpected author field type: {type(author_field).__name__}"
        )
    # BibTeX joins co-authors with literal ' and '.
    return " and ".join(authors)


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
        fields.append(("doi", escape_bibtex(doi)))

    url = extract_url(entry)
    if url:
        fields.append(("url", escape_bibtex(url)))

    page_range = entry.get("page-range")
    if page_range is not None:
        fields.append(("pages", escape_bibtex(str(page_range))))

    parent = entry.get("parent") or {}
    if isinstance(parent, dict):
        parent_title = parent.get("title")
        if parent_title:
            fields.append(("journal", escape_bibtex(str(parent_title))))
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
        bib_type = "misc"
        if url and not any(k == "howpublished" for k, _ in fields):
            fields.append(
                ("howpublished", "\\url{" + escape_bibtex(url) + "}")
            )
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
    print("% DO NOT EDIT by hand — edit references.yml and regenerate.")
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
