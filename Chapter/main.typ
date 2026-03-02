// A Practical Guide to Pangenome Graph Construction, Variant Calling,
// and Phenome-Wide Association in the HXB/BXH Rat Panel
//
// For: Springer Methods in Molecular Biology

#set document(
  title: "A Practical Guide to Pangenome Graph Construction, Variant Calling, and Phenome-Wide Association in the HXB/BXH Rat Panel",
  author: ("Flavia Villani", "Pjotr Prins", "Andrea Guarracino"),
)

#set text(font: "New Computer Modern", size: 11pt, lang: "en")
#set par(justify: true)
#set page(
  paper: "a4",
  margin: (top: 2.5cm, bottom: 2.5cm, left: 2.5cm, right: 2.5cm),
  numbering: "1",
)

// Heading numbering: 1., 1.1, 1.2.1, etc.
#set heading(numbering: "1.")

// Code block styling
#show raw.where(block: true): set text(size: 9pt)
#show raw.where(block: true): block.with(
  fill: luma(245),
  inset: 8pt,
  radius: 3pt,
  width: 100%,
)

#include "00-frontmatter.typ"
#include "01-introduction.typ"
#include "02-materials.typ"
#include "03-methods.typ"
#include "04-notes.typ"
#include "05-backmatter.typ"

#bibliography("references.yml", style: "springer-basic-brackets.csl")

// Figure captions (figures submitted as separate files per MiMB instructions)
#heading(numbering: none, level: 1)[Figure Captions]

*Fig. 1.* Overview of the pangenome workflow described in this protocol. *Top:* the 31 HXB/BXH recombinant inbred rat strains, derived from SHR/OlaIpcv and BN-Lx/Cub progenitors, are sequenced and de novo assembled; assembly completeness is assessed with Compleasm (%BUSCOs). *Upper middle:* the PGGB pipeline constructs the pangenome graph through all-to-all alignment (WFMASH), graph induction (SEQWISH), graph normalization (SMOOTHXG), and redundancy removal (GFAFFIX). *Lower middle:* 1D visualization of the resulting pangenome graph (odgi viz), where each horizontal row represents a genome path and colored segments indicate node traversals. *Bottom:* downstream analyses including variant calling from graph snarls, read mapping with vg Giraffe, variant benchmarking (assembly evaluation and variant calling evaluation with precision, recall, and F1-score), and phenome-wide association study (PheWAS) linking variants to phenotypes.
