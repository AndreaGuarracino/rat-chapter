#let fixme(txt) = text(red,"Fixme:" + txt)

= Materials

== Genome assemblies

+ Reference genome: mRatBN7.2 (rn7), available from NCBI (GenBank assembly accession GCA\_015227675.2) @dejong2024.

+ De novo haploid genome assembly for each of the 31 HXB/BXH RI strains, generated from 10x Genomics Chromium Linked-Read whole-genome sequencing data at an average coverage depth of 109× using Supernova (version 2.1.1) @weisenfeld2017 @dejong2024. Linked-Read technology bridges the gap between short-read and long-read approaches by providing long-range barcode information that links short reads originating from the same high-molecular-weight DNA molecule (_see_ *Note 1*). Long-read reassembly of these strains would substantially improve the pangenome (_see_ *Note 15*).

+ Gene annotations from Ensembl for the mRatBN7.2 assembly @martin2023.

+ Phenotype data from GeneNetwork (#link("https://genenetwork.org")[genenetwork.org]), comprising quantitative molecular and physiological phenotypes collected over more than three decades across the HXB/BXH panel @mulligan2017.

== Software environment

All software required for this protocol is bundled in a single Docker container defined by `Docker/Dockerfile`. Build and launch the container as described in Section 3.1; once inside, every tool listed below is on `$PATH` and you can follow the rest of the protocol without installing anything else.

=== Assembly Quality control

+ *Compleasm* (v0.2.7) @huang2023: BUSCO-based @manni2021 assessment of assembly completeness using the Mammalia ortholog gene set.
+ *meryl* (v1.4) @rhie2020: k-mer counting and histogram generation for GenomeScope @vurture2017.
+ *samtools/htslib* (v1.19) @danecek2021: contig filtering, indexing, BAM/CRAM processing, compression, and indexing.
+ *seqtk* (v1.5-r133): telomere repeat detection.
+ *NCBI datasets CLI* (v18.23.0): linear reference genome download from NCBI.

=== PGGB pangenome construction

+ *fastix* (commit 331c1159): PanSN-spec sequence renaming.
+ *PGGB* (v0.7.0) @garrison2024: orchestrates the pangenome construction pipeline. #link("https://github.com/pangenome/pggb")
+ *WFMASH* (v0.14.1) @guarracino2021wfmash: all-to-all whole-genome alignment (PGGB stage 1). #link("https://github.com/waveygang/wfmash")
+ *SEQWISH* (commit 90dc76e1) @garrison2023: graph induction from pairwise alignments (PGGB stage 2). #link("https://github.com/ekg/seqwish")
+ *SMOOTHXG* (commit 0ea0470a) @garrison2024: graph normalization via partial order alignment @lee2002 (PGGB stage 3). #link("https://github.com/pangenome/smoothxg")
+ *GFAFFIX* (commit 460e0dd) @garrison2024: walk-preserving redundancy removal (PGGB stage 4). #link("https://github.com/marschall-lab/GFAffix")
+ *bcftools* (v1.19) @danecek2021: VCF/BCF processing and concatenation of per-chromosome VCFs.
+ *ODGI* (v0.8.6) @guarracino2022odgi: graph statistics, 1D/2D visualization, subgraph extraction, and manipulation. #link("https://github.com/pangenome/odgi")
+ *Panacus* (v0.2.3) @parmigiani2024panacus: pangenome growth and core/shell/private size estimation from GFA graphs. #link("https://github.com/marschall-lab/panacus")

=== Variant calling and validation

+ *vg* (v1.71.0) @garrison2018: graph indexing (`autoindex`), short-read mapping (`giraffe`), variant calling (`deconstruct`, `call`), and surjection. #link("https://github.com/vgteam/vg")
+ *SnpEff/SnpSift* (v5.0) @cingolani2012: functional annotation, effect prediction of variants on genes and proteins, and VCF filtering.
+ *RTG Tools* (v3.12.1) @cleary2015: precision/recall analysis of variant call sets via `vcfeval`.
+ *MUMmer3/nucmer* (v3.23) @kurtz2004: independent pairwise genome alignment and SNP calling for cross-validation.
+ *bedtools* (v2.30.0) @quinlan2010: genome arithmetic such as computing complement regions for callable loci. #link("https://github.com/arq5x/bedtools2")

=== Structural variant analysis

+ *minimap2* (v2.26) @li2018: assembly-to-reference alignment used by SV callers.
+ *SVIM-asm* (v1.0.3) @heller2020: assembly-based SV calling in haploid mode.
+ *PAV* (v2.4.6) @ebert2021 with *snakemake* (v7.32.4): haplotype-resolved SV detection from local alignment coordinates.
+ *Hall-lab assembly_validation* @hall_lab (paftools.js + k8 v1.2): assembly-based SV calling via split-read alignment.
+ *vcfbub* (v0.1.0): nested allele removal from multi-allelic pangenome VCF records. #link("https://github.com/pangenome/vcfbub")
+ *vcfwave* (vcflib commit b118a9b) @garrison2022vcflib: complex variant decomposition using the BiWFA algorithm @marcosola2023. #link("https://github.com/vcflib/vcflib")
+ *SURVIVOR* (v1.0.7) @jeffares2017: multi-caller SV merging.

=== PheWAS

+ *GEMMA* (v0.98.5) @zhou2012: kinship-corrected linear mixed model association analysis for PheWAS.


Two pieces of software used in the protocol are *not* included in the Docker image and must be installed separately:

+ *RepeatMasker* @tarailo2009: for masking low-complexity and repetitive regions. Install per the upstream instructions; required only if generating callable-region masks for validation (Section 3.7).

+ *BXDtools* @arends_bxdtools: an R package for kinship-corrected association analysis on RI panels, used as an alternative to GEMMA in the PheWAS step (Section 3.9). Install in R (≥ 4.0) outside the container with `devtools::install_github("DannyArends/BXDtools")`. Adapted scripts are available at https://github.com/Flavia95/HXB_rat_pangenome_manuscript/blob/main/workflows/3_PheWAS.md

== Hardware requirements and workflows

PGGB is computationally intensive. The HXB/BXH pangenome was built on a high-performance computing (HPC) cluster using machines equipped with AMD EPYC 7402P 24-core processors (48 threads), 256-378 GB of RAM, and 1 TB solid-state drive (SSD) storage. To give a sense of scale: building a pangenome graph of human chromosome 6 from 90 haplotypes required approximately 1,183 minutes (12 hours) and 136 GB of RAM @garrison2024; on the same hardware, the smaller rat chromosome 12 from 32 haplotypes (31 HXB/BXH strains plus the mRatBN7.2 reference) used about 29 GB of RAM. Docker and Singularity containers are available to simplify deployment, and a cluster-scalable Nextflow implementation (nf-core/pangenome) can distribute alignment jobs across multiple nodes @heumos2024. A common workflow language (CWL) alternative is also available from the authors.
