// Title — unnumbered
#heading(numbering: none, level: 1)[A Practical Guide to Pangenome Graph Construction, Variant Calling, and Phenome-Wide Association in the HXB/BXH Rat Panel]

// Authors and affiliations
#v(0.5em)
#text(size: 10pt)[
  Flavia Villani#super[1],~...~Pjotr Prins#super[2], Andrea Guarracino#super[1,\*]
]
#v(0.3em)
#text(size: 9pt)[
  #super[1] Bioinnovation and Genome Sciences, The Translational Genomics Research Institute (TGen), Phoenix, AZ 85004, USA\
  #super[2] Department of Genetics, Genomics and Informatics, University of Tennessee Health Science Center, Memphis, TN 38163, USA\
  #super[\*] Corresponding author: #link("mailto:aguarracino@tgen.org")[aguarracino\@tgen.org]
]
#v(1em)

// Abstract
#heading(numbering: none, level: 2)[Abstract]

A single reference genome cannot represent all genetic variation within a species, systematically biasing any analysis toward the reference allele and obscuring novel sequences and structural differences. Pangenomes reduce this bias by incorporating genomes from many individuals, thereby representing a broader spectrum of population diversity. A pangenome graph provides a unified model for encoding input genomes in a single data structure, where sequences are stored as nodes and their adjacency relationships as edges. Here we describe a practical methodology for constructing, validating, and leveraging a rat pangenome graph built from the HXB/BXH family of recombinant inbred (RI) rat strains, covering reference-free graph construction with PGGB, variant calling and validation, structural variant analysis, and phenome-wide association mapping. Applying this workflow, we identified novel variants absent from reference-based call sets and demonstrated their association with cardiometabolic and neurological phenotypes. We also discuss challenges in scaling pangenome analysis to larger cohorts and how implicit pangenome graphs may address these barriers, underscoring the value and future potential of pangenomic approaches for genotype--phenotype discovery.

#v(0.5em)
*Key Words:* Pangenome, _Rattus norvegicus_, Pangenome graph, HXB/BXH strains, Recombinant inbred, Structural variants, PheWAS, Variant calling, Reference bias
