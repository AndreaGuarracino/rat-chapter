# Rat Pangenome Chapter

For: Springer Methods in Molecular Biology (MiMB).

## Prerequisites

- [Typst](https://typst.app/) >= 0.14 (PDF build).
- Python 3 with PyYAML (`pip install pyyaml`) for `yaml2bib.py` (Word build) and `doi2hayagriva.py` (regenerating references).
- [doi2bib](https://pypi.org/project/doi2bib/) (`pip install doi2bib`), only needed to regenerate references from DOIs.
- [pandoc](https://pandoc.org/) >= 3.1.2, only needed to produce the Word file for Springer submission.

All commands below are run from inside this `Chapter/` directory.

## Build the PDF file

```bash
typst compile main.typ chapter.pdf
```

## Build the Word file (for Springer submission)

Typst does not export to Word directly. Use pandoc (>= 3.1.2), which reads Typst natively. The build regenerates two intermediate files first: `references.bib` (from `references.yml` via `yaml2bib.py`, because pandoc cannot read Hayagriva YAML) and `reference.docx` (the Word style template, via `make_reference_docx.py`).

```bash
python3 make_reference_docx.py
python3 yaml2bib.py references.yml > references.bib
pandoc main.typ -o chapter.docx \
    --citeproc \
    --csl=springer-basic-brackets.csl \
    --bibliography=references.bib \
    --number-sections \
    --lua-filter=unnumber-backmatter.lua \
    --reference-doc=reference.docx
```

- `make_reference_docx.py` patches pandoc's default Word template: Consolas 10pt code blocks, justified body, left-aligned headings/captions/bibliography. Full rule list in the script docstring. Skip it and pandoc falls back to Cambria code with left-aligned body, which is wrong for MiMB.
- `--number-sections` restores the hierarchical section numbering (1, 1.1, 2.2.1) that Typst auto-generates and pandoc otherwise drops.
- `unnumber-backmatter.lua` keeps Title, Summary, Competing Interests, Acknowledgments, and Figure Captions unnumbered, and left-aligns the affiliations block.

Figures are not embedded (MiMB wants them separate anyway), and cross-references to `*Note N*` / `Fig. N` render as literal text rather than hyperlinks.

## Prepare figures for submission

MiMB requires figures as separate EPS files (with embedded fonts, lettering 8-12pt at 160mm print width). The figure source is maintained as SVG (exported from Google Slides) and converted to EPS in two steps. Going via a high-DPI PDF preserves embedded raster content (e.g. the ODGI visualization) at full fidelity; Inkscape's (>= 1.2) direct `--export-type=eps` rasterizes at 96 DPI regardless of `--export-dpi` and produces a low-quality file.

```bash
cd Figures
# 1. SVG -> PDF at 1200 DPI, with text outlined for portability.
inkscape Figure1.svg --export-filename=Figure1.pdf --export-type=pdf \
    --export-text-to-path --export-dpi=1200
# 2. PDF -> EPS preserving the embedded raster at 1200 DPI.
pdftops -eps -level3 -r 1200 Figure1.pdf Figure1.eps
