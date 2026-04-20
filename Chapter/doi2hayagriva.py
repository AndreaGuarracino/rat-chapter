#!/usr/bin/env python3
"""
Re-fetch Hayagriva YAML entries for every DOI-bearing reference in
references.yml. Manual entries (no `serial-number.doi`) are skipped.

Usage:
    python3 doi2hayagriva.py references.yml | diff - references.yml | less

The script reads DOIs directly from references.yml (the build's single
source of truth), fetches fresh metadata via doi2bib, and prints the
regenerated YAML to stdout. Pipe through diff to see what would change
since the last regeneration; merge wanted changes by editing
references.yml directly.

Requires: doi2bib (pip install doi2bib), pyyaml (pip install pyyaml)
"""

import subprocess
import sys
import re
import time

import yaml


def fetch_bibtex(doi: str) -> str:
    """Fetch BibTeX entry from doi2bib."""
    result = subprocess.run(
        ["doi2bib", doi],
        capture_output=True, text=True, timeout=30
    )
    return result.stdout.strip()


def parse_bibtex(bib: str) -> dict:
    """Parse a BibTeX entry into a dict of fields."""
    fields = {}
    # Get entry type
    m = re.match(r"@(\w+)\{", bib)
    if m:
        fields["_type"] = m.group(1).lower()

    # Extract fields: key = {value} or key = value
    for match in re.finditer(
        r"(\w+)\s*=\s*\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}", bib
    ):
        key = match.group(1).lower()
        val = match.group(2).strip()
        # Clean LaTeX artifacts
        val = val.replace("{", "").replace("}", "")
        val = val.replace("\\&", "&")
        val = val.replace("\\'e", "é")
        val = val.replace("\\`e", "è")
        val = val.replace("\\c{c}", "ç").replace("\\cc", "ç")
        fields[key] = val

    return fields


def format_authors(author_str: str) -> list:
    """Convert 'Last, First and Last2, First2' to list of 'Last, First'."""
    authors = []
    for a in author_str.split(" and "):
        a = a.strip()
        if not a:
            continue
        # Include all authors so the CSL "et al" threshold works
        pass
        authors.append(a)
    return authors


def bibtex_to_hayagriva(key: str, fields: dict, doi: str) -> str:
    """Convert parsed BibTeX fields to Hayagriva YAML."""
    lines = [f"{key}:"]
    lines.append("  type: article")

    if "title" in fields:
        title = fields["title"]
        lines.append(f'  title: "{title}"')

    if "author" in fields:
        authors = format_authors(fields["author"])
        lines.append("  author:")
        for a in authors:
            lines.append(f'    - "{a}"')

    if "year" in fields:
        lines.append(f"  date: {fields['year']}")

    # DOI
    lines.append("  serial-number:")
    lines.append(f'    doi: "{doi}"')

    if "pages" in fields:
        pages = fields["pages"].replace("--", "-").replace("–", "-")
        lines.append(f'  page-range: "{pages}"')

    lines.append("  parent:")
    lines.append("    type: periodical")
    if "journal" in fields:
        lines.append(f'    title: "{fields["journal"]}"')
    if "volume" in fields:
        lines.append(f"    volume: {fields['volume']}")
    if "number" in fields:
        lines.append(f"    issue: {fields['number']}")

    return "\n".join(lines)


def main():
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        sys.exit(1)

    input_file = sys.argv[1]
    entries = []

    with open(input_file) as f:
        data = yaml.safe_load(f)
    if not isinstance(data, dict):
        print(f"ERROR: {input_file} is not a YAML mapping", file=sys.stderr)
        sys.exit(1)

    for key, entry in data.items():
        if not isinstance(entry, dict):
            print(f"WARNING: skipping non-mapping entry {key!r}",
                  file=sys.stderr)
            continue
        serial = entry.get("serial-number") or {}
        doi = serial.get("doi") if isinstance(serial, dict) else None
        if not doi:
            print(f"SKIP: {key} (no DOI; MANUAL entry)", file=sys.stderr)
            continue
        entries.append((key, str(doi).strip()))

    for i, (key, doi) in enumerate(entries):
        print(f"Fetching {key}: {doi}", file=sys.stderr)
        try:
            bib = fetch_bibtex(doi)
            if not bib or "@" not in bib:
                print(f"ERROR: no BibTeX for {doi}", file=sys.stderr)
                continue
            fields = parse_bibtex(bib)
            entry_yaml = bibtex_to_hayagriva(key, fields, doi)
            print(entry_yaml)
            print()
        except Exception as e:
            print(f"ERROR: {key}: {e}", file=sys.stderr)

        # Rate limiting
        if i < len(entries) - 1:
            time.sleep(0.5)


if __name__ == "__main__":
    main()
