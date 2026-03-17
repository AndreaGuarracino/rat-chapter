# Rat Pangenome Chapter

For: Springer Methods in Molecular Biology (MiMB).

## Prerequisites

- [Typst](https://typst.app/) >= 0.14
- [doi2bib](https://pypi.org/project/doi2bib/) (`pip install doi2bib`) — only needed to regenerate references
- Python 3 — only needed to regenerate references

## Build the PDF

```bash
cd rat-chapter
typst compile Chapter/main.typ Chapter/chapter.pdf
```

## File structure

```
Chapter/
  main.typ                    # Master document (includes all sections)
  00-frontmatter.typ          # Title, authors, abstract, keywords
  01-introduction.typ         # Introduction (sections 1.1–1.5)
  02-materials.typ            # Materials (sections 2.1–2.4)
  03-methods.typ              # Methods (sections 3.1–3.8)
  04-notes.typ                # Notes (1–16)
  05-backmatter.typ           # Competing interests, acknowledgments
  references.yml              # Hayagriva YAML bibliography (NLM-abbreviated journals)
  springer-basic-brackets.csl # Springer citation style (CSL)
  dois.tsv                    # DOI → citation key mapping (source of truth)
  doi2hayagriva.py            # Script: converts DOIs to Hayagriva YAML (full author lists)
  Figures/
    Figure1.pdf               # Figure 1 (submitted separately per MiMB)
    alt-text.xlsx             # Alternative text for figures (EU Accessibility Act)
```

## Regenerate references from DOIs

The `dois.tsv` file maps each citation key to its DOI. Lines marked `MANUAL` have no DOI (web resources, theses, preprints without standard DOI) and are maintained by hand at the bottom of `references.yml`.

To regenerate the DOI-based entries:

```bash
cd Chapter
python3 doi2hayagriva.py dois.tsv > references_auto.yml
```

Then review the output for:
- **Date mismatches**: doi2bib may return the epub date instead of the print year. Check that dates match the citation keys (e.g., `hickey2024` should show `date: 2024`).
- **Title artifacts**: some BibTeX entries contain residual LaTeX or multi-line formatting (e.g., the `cingolani2012` and `wick2015` titles).
- **Missing journal names**: bioRxiv/openRxiv preprints may lack a journal field — add `title: "bioRxiv"` or `title: "openRxiv"` under `parent:`.
- **Journal abbreviations**: the script outputs full journal names. Abbreviate to NLM standard (e.g., "Nature Biotechnology" → "Nat Biotechnol").

After review, append the manual entries (pravenec1989, guarracino2021wfmash, arends_bxdtools, hall_lab, villani2025thesis, guarracino2025impg) to produce the final `references.yml`.

### Adding a new reference

1. Add a line to `dois.tsv`: `key<TAB>DOI` (or `key<TAB>MANUAL` if no DOI)
2. Regenerate and review as above
3. Cite in `.typ` files with `@key`
4. Rebuild the PDF

### Citation style

Citations appear as numbered brackets [1], [2], etc., ordered by first appearance in the text, per Springer MiMB guidelines. This is handled automatically by Typst + the `springer-basic-brackets.csl` file.

## To do

- [ ] **Author Agreement Form**: complete `Guide/Rat Genomics_AUTHOR AGREEMENT.docx` with all authors, addresses, ORCIDs, title, corresponding author signature
- [ ] **Figure EPS conversion**: once SVG is available from Google Slides, convert to EPS (`inkscape Figure1.svg --export-filename=Figure1.eps --export-type=eps`) and verify lettering is 8–12pt at 160mm print width
- [ ] **Final checks**: verify all tool installation instructions and code/command examples are correct and runnable
- [ ] **Final checks**: verify all references have correct title, author, year, journal (spot-check rendered PDF)
