// A Practical Guide to Pangenome Graph Construction, Variant Calling,
// and Phenome-Wide Association in the HXB/BXH Rat Panel
//
// For: Springer Methods in Molecular Biology

#set document(
  title: "Pangenome Graph Construction, Variant Calling, and Phenome-Wide Association in the HXB/BXH Rat Panel",
  author: ("Flavia Villani", "Vincenza Colonna", "Erik Garrison", "David Duggan", "David G. Ashbrook", "Robert W. Williams", "Hao Chen", "Pjotr Prins", "Andrea Guarracino"),
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
  fill: white,
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

*Fig. 1.* Overview of the pangenome workflow described in this protocol. *First (top)*: genome assemblies were generated from 10x Genomics Linked-Read sequencing of 31 HXB/BXH recombinant inbred strains derived from the parental SHR/OlaIpcv (H) and BN-Lx/Cub (B) strains; six representative strains (HXB23, BXH6, HXB21, SHROlaIpcv, BXH3, and BNLxCub) are shown. Assembly completeness is assessed with Compleasm (%BUSCOs). *Second (middle)*: chromosome-level pangenome graphs were built using PGGB; an example of the chr12 pangenome graph is shown, visualized with ODGI, where each horizontal colored line represents a haplotype and vertical white stripes indicate structural variation. *Third (bottom*): downstream analyses including (i) variant calling from graph snarls (illustrated with a two-genome bubble-graph schematic showing divergent paths through shared anchor nodes); (ii) read mapping (shown with short reads aligned to a similar bubble-graph); (iii) variant benchmarking comparing the pangenome dataset against a genomic truth-set to capture pangenome-only, genomic-only, and shared variants, evaluated by precision, recall, and F1-score; (iv) phenome-wide association study (PheWAS) linking validated SNPs to phenotypes including blood glucose concentration and central nervous system traits via GeneNetwork; (v) structural variant (SV) validation using Nanopore adaptive sequencing to confirm a representative 82 bp insertion at chr12:1,942,010 across samples relative to the reference genome; (vi) SV interpretation showing haplotype-resolved allele frequencies across strains. A representative complex insertion of 82 bp in the Cd209c gene resolves into six haplotypes composed of seven variable blocks, of which four are observed fewer than two times.