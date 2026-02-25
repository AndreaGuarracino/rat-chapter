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
  04-notes.typ                # Notes (1–14)
  05-backmatter.typ           # Competing interests, acknowledgments
  references.yml              # Hayagriva YAML bibliography (43 refs)
  springer-basic-brackets.csl # Springer citation style (CSL)
  dois.tsv                    # DOI → citation key mapping (source of truth)
  doi2hayagriva.py            # Script: converts DOIs to Hayagriva YAML
```

## Regenerate references from DOIs

The `dois.tsv` file maps each citation key to its DOI. Lines marked `MANUAL` have no DOI (web resources, theses, manuscripts under review) and are maintained by hand at the bottom of `references.yml`.

To regenerate the DOI-based entries:

```bash
cd Chapter
python3 doi2hayagriva.py dois.tsv > references_auto.yml
```

Then review the output for:
- **Date mismatches**: doi2bib may return the epub date instead of the print year. Check that dates match the citation keys (e.g., `hickey2024` should show `date: 2024`).
- **Title artifacts**: some BibTeX entries contain residual LaTeX (e.g., `{\\textit{...}}`).
- **Missing journal names**: bioRxiv preprints may lack a journal field.

After review, append the manual entries (pravenec1989, guarracino2021wfmash, arends_bxdtools, hall_lab, villani2025thesis, guarracino2025impg) to produce the final `references.yml`.

### Adding a new reference

1. Add a line to `dois.tsv`: `key<TAB>DOI` (or `key<TAB>MANUAL` if no DOI)
2. Regenerate and review as above
3. Cite in `.typ` files with `@key`
4. Rebuild the PDF

### Citation style

Citations appear as numbered brackets [1], [2], etc., ordered by first appearance in the text, per Springer MiMB guidelines. This is handled automatically by Typst + the `springer-basic-brackets.csl` file.

## To do
- [ ] Check we covered [Guide/Editor_expectation.txt](Guide/Editor_expectation.txt)
- [ ] Check we respect [Author Instructions](Guide/Author%20Instructions_MiMB-2025[11]-1.pdf)
- [ ] **AT THE VERY END**: Check tool installation instructions
- [ ] **AT THE VERY END**: Check code instructions
- [ ] **AT THE VERY END**: Check that references are correct, and that they have correct title, author, year, ...