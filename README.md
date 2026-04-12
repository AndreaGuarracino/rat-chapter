# Rat Pangenome Chapter

For: Springer Methods in Molecular Biology (MiMB).

## Prerequisites

- [Typst](https://typst.app/) >= 0.14 — PDF build
- Python 3 with PyYAML (`pip install pyyaml`) — for `yaml2bib.py` (Word build) and `doi2hayagriva.py` (regenerating references)
- [doi2bib](https://pypi.org/project/doi2bib/) (`pip install doi2bib`) — only needed to regenerate references from DOIs
- [pandoc](https://pandoc.org/) >= 3.1.2 — only needed to produce the Word file for Springer submission

## Build the PDF file

```bash
cd rat-chapter
typst compile Chapter/main.typ Chapter/chapter.pdf
```

## Build the Word file (for Springer submission)

Typst does not export to Word directly. Use pandoc (≥ 3.1.2), which reads Typst natively. Pandoc cannot read Hayagriva YAML, so `references.bib` is regenerated from `references.yml` on each build via `yaml2bib.py`.

```bash
cd Chapter
python3 yaml2bib.py references.yml > references.bib
pandoc main.typ -o chapter.docx \
    --citeproc \
    --csl=springer-basic-brackets.csl \
    --bibliography=references.bib
```

Open `chapter.docx` and diff it against `chapter.pdf` before submitting. Figures are not embedded (MiMB wants them separate anyway), and cross-references to `*Note N*` / `Fig. N` render as literal text rather than hyperlinks.

## File structure

```
Chapter/
  main.typ                    # Master document (includes all sections)
  00-frontmatter.typ          # Title, authors, abstract, keywords
  01-introduction.typ         # Introduction (sections 1.1–1.6)
  02-materials.typ            # Materials (sections 2.1–2.3)
  03-methods.typ              # Methods (sections 3.1–3.9, Docker-first)
  04-notes.typ                # Notes (1–16)
  05-backmatter.typ           # Competing interests, acknowledgments
  references.yml              # Hayagriva YAML bibliography (NLM-abbreviated journals)
  springer-basic-brackets.csl # Springer citation style (CSL)
  dois.tsv                    # DOI → citation key mapping (source of truth)
  doi2hayagriva.py            # Script: converts DOIs to Hayagriva YAML (full author lists)
  yaml2bib.py                 # Script: converts references.yml → references.bib for pandoc
  references.bib              # BibTeX sidecar for pandoc Word build (regenerated from references.yml)
  Figures/
    Figure1.pdf               # Figure 1 (submitted separately per MiMB)
    alt-text.xlsx             # Alternative text for figures (EU Accessibility Act)
Docker/
  Dockerfile                  # Single image with every tool used in the protocol
  README.md                   # Build/run instructions and tool version table
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

## Docker

A reproducible Docker image bundling every tool used in the protocol is defined in `Docker/Dockerfile`. Tool versions are defined in `Chapter/02-materials.typ`.

See [`Docker/README.md`](Docker/README.md) for the full tool version table and build/run instructions.
