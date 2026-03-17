#!/usr/bin/env python3
"""
Convert a list of DOIs to Hayagriva YAML for Typst bibliography.

Usage:
    python3 doi2hayagriva.py dois.tsv > references.yml

Input: TSV with columns: key<TAB>doi
  Lines starting with # are comments.
  Lines with key<TAB>MANUAL are skipped (for entries without DOIs).

Requires: doi2bib (pip install doi2bib)
"""

import subprocess
import sys
import re
import time


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
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) < 2:
                print(f"WARNING: skipping malformed line: {line}",
                      file=sys.stderr)
                continue
            key, doi = parts[0], parts[1]
            if doi == "MANUAL":
                print(f"SKIP: {key} (manual entry)", file=sys.stderr)
                continue
            entries.append((key, doi))

    for i, (key, doi) in enumerate(entries):
        print(f"Fetching {key}: {doi}", file=sys.stderr)
        try:
            bib = fetch_bibtex(doi)
            if not bib or "@" not in bib:
                print(f"ERROR: no BibTeX for {doi}", file=sys.stderr)
                continue
            fields = parse_bibtex(bib)
            yaml = bibtex_to_hayagriva(key, fields, doi)
            print(yaml)
            print()
        except Exception as e:
            print(f"ERROR: {key}: {e}", file=sys.stderr)

        # Rate limiting
        if i < len(entries) - 1:
            time.sleep(0.5)


if __name__ == "__main__":
    main()
