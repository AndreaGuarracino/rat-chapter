= Materials

== Genome assemblies

+ Reference genome: mRatBN7.2 (rn7), available from NCBI (GenBank assembly accession GCA\_015227675.2) @dejong2024.

+ De novo haploid genome assembly for each of the 31 HXB/BXH RI strains, generated from 10x Genomics Chromium Linked-Read whole-genome sequencing data at an average coverage depth of 109× using Supernova (version 2.1.1) @dejong2024. Linked-Read technology bridges the gap between short-read and long-read approaches by providing long-range barcode information that links short reads originating from the same high-molecular-weight DNA molecule (_see_ *Note 1*).

+ Gene annotations from Ensembl for the mRatBN7.2 assembly @martin2023.

+ Phenotype data from GeneNetwork (#link("https://genenetwork.org")[genenetwork.org]), comprising quantitative molecular and physiological phenotypes collected over more than three decades across the HXB/BXH panel @mulligan2017.

== PGGB pipeline components

The PGGB @garrison2024 pipeline (available at #link("https://github.com/pangenome/pggb")) consists of four core modules whose algorithmic details are described in the Introduction (Section 1.3). Install PGGB using one of the following methods:

```bash
# Docker (recommended — includes all dependencies)
docker pull ghcr.io/pangenome/pggb:v0.7.0

# or Bioconda
conda create -n pggb -c bioconda -c conda-forge pggb=0.7.0
conda activate pggb
```

Singularity and Guix containers are also available. The individual module versions bundled with PGGB v0.7.0 and used in this protocol are:

+ *WFMASH* (v0.14.0): All-to-all whole-genome alignment. #link("https://github.com/waveygang/wfmash") @guarracino2021wfmash.
+ *SEQWISH* (v0.7.11): Graph induction from pairwise alignments. #link("https://github.com/ekg/seqwish") @garrison2023.
+ *SMOOTHXG* (v0.8.0): Graph normalization via partial order alignment. #link("https://github.com/pangenome/smoothxg").
+ *GFAFFIX* (v0.1.5b): Walk-preserving redundancy removal. #link("https://github.com/marschall-lab/GFAffix").
+ *ODGI* (v0.9.0): Graph statistics, visualization, and manipulation. #link("https://github.com/pangenome/odgi") @guarracino2022odgi.
+ *vg* (v1.59.0): Graph indexing, read mapping (Giraffe), variant calling (deconstruct, call). #link("https://github.com/vgteam/vg") @garrison2018.

== Downstream analysis tools

Install the downstream tools in a Bioconda environment. Note that the PGGB Bioconda package is Linux-only; macOS users should use Docker.

```bash
conda create -n pangenome-tools -c bioconda -c conda-forge \
    samtools bcftools rtg-tools snpeff snpsift \
    seqtk minimap2 survivor vcflib vcfbub \
    svim-asm repeatmasker meryl mummer4
conda activate pangenome-tools
```

vg and ODGI are already installed as part of the PGGB environment (Section 2.2); activate that environment when running `pggb`, `vg`, or `odgi` commands. Compleasm is installed in its own environment (Section 3.1).

PAV (@ebert2021) and the Hall-lab pipeline (@hall_lab) are not available via Bioconda and should be installed from their respective GitHub repositories. The `fastix` utility for sequence renaming is included in the PGGB Docker image; when using Bioconda, install it via `cargo install fastix` (requires a Rust toolchain) or use `sed` for header renaming (see Section 3.2.1).

+ ODGI @guarracino2022odgi: for computing graph statistics (node count, edge count, base content, path coverage) and for generating visualizations. ODGI provides both one-dimensional (1D) visualizations that show how paths align into the graph structure and two-dimensional (2D) visualizations that reveal graph topology. It can also produce pairwise distance matrices suitable for phylogenetic analysis.

+ vg deconstruct (from the vg toolkit) @garrison2018: for extracting variants from the pangenome graph relative to a specified reference path by enumerating bubbles (snarls) in the graph.

+ BCFtools @danecek2021: for VCF normalization, decomposition, filtering, and statistics.

+ RTG Tools @cleary2015: for precision/recall analysis of variant call sets using vcfeval.

+ SnpEff (v5.1) @cingolani2012: for functional annotation and effect prediction of variants on genes and proteins.

+ GEMMA @zhou2012 (available via Bioconda: `conda install -c bioconda gemma`) or GeneNetwork/BXDtools @arends_bxdtools (R package: `devtools::install_github("DannyArends/BXDtools")`): for kinship-corrected linear mixed model association analysis (PheWAS). R (≥ 4.0) is required for the PheWAS analysis in Section 3.7.

+ Assembly-based SV callers: PAV @ebert2021, SVIM-asm @heller2020, and Hall-lab pipeline @hall_lab, used in combination with vg to produce a multi-method high-confidence SV call set.

+ SURVIVOR @jeffares2017: for merging structural variant calls across multiple callers.

+ vcfbub (#link("https://github.com/pangenome/vcfbub")): for removing nested alleles from multi-allelic VCF records.

+ vcfwave (from vcflib; #link("https://github.com/vcflib/vcflib")): for decomposing complex variants using the BiWFA algorithm.

+ RepeatMasker @tarailo2009: for masking low-complexity and repetitive regions.

+ Compleasm @huang2023: for BUSCO-based assessment of assembly completeness using the Mammalia ortholog gene set.

+ Minimap2 @li2018: for assembly-to-reference alignment used by SV callers.

== Hardware requirements

PGGB is computationally intensive. The HXB/BXH pangenome was built on a high-performance computing (HPC) cluster using machines equipped with AMD EPYC 7402P 24-core processors (48 threads), 256--378 GB of RAM, and 1 TB solid-state drive (SSD) storage. As a reference for runtime and memory requirements: building a pangenome graph of rat chromosome 12 from 32 haplotypes required approximately 29 GB of RAM, while human chromosome 6 from 90 haplotypes required approximately 1,183 minutes and 136 GB of RAM @garrison2024. Docker and Singularity containers are available to simplify deployment. A cluster-scalable Nextflow implementation (nf-core/pangenome) is also available for distributing alignment jobs across multiple nodes @heumos2024.
