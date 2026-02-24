= Methods

All software listed in Section 2 should be installed before proceeding. The `filter_Ns.py` script (requires Python 3) for filtering N-rich SV calls is available at #link("https://github.com/Flavia95/HXB_rat_pangenome_manuscript")[github.com/Flavia95/HXB\_rat\_pangenome\_manuscript]. Adjust the `-t` thread count in all commands below to match your available CPU cores. Commands that use `pggb`, `vg`, `odgi`, or `vcfbub` require the `pggb` conda environment; commands that use other downstream tools (e.g., `bcftools`, `snpEff`, `minimap2`) require the `pangenome-tools` environment. When using Docker, all tools are available in a single container.

== Assembly quality assessment

Before constructing the pangenome, verify the quality and suitability of each de novo assembly. Assembly quality is evaluated using Compleasm @huang2023 to assess the representation of universal single-copy orthologs expected across mammals using the BUSCO Mammalia gene set. Each assembly is benchmarked against the mRatBN7.2 reference genome @dejong2024.

*1. Install Compleasm and download the Mammalia BUSCO gene set:*

```bash
conda create -n compleasm -c conda-forge -c bioconda compleasm
conda activate compleasm
mkdir -p busco/databases
compleasm download -L busco/databases mammalia
```

*2. Run Compleasm on each assembly and the reference genome:*

```bash
mkdir -p busco/results
for ASSEMBLY in assemblies/*.fa.gz; do
    STRAIN=$(basename "$ASSEMBLY" .fa.gz)
    mkdir -p busco/results/${STRAIN}
    compleasm run \
        -a ${ASSEMBLY} \
        -o busco/results/${STRAIN} \
        -t 48 \
        -l mammalia \
        -L busco/databases
    mv busco/results/${STRAIN}/summary.txt \
        busco/results/${STRAIN}/summary.mammalia.${STRAIN}.txt
done
```

Adjust the `-t` parameter to match available CPU threads. On an HPC cluster, each strain can be submitted as an independent job. The majority of BUSCO orthologs should be complete and single-copy, which is indicative of high assembly quality.

*3. Evaluate heterozygosity and genome characteristics.* Use K-mer counting with Meryl @rhie2020 and GenomeScope @vurture2017 to estimate genome size, heterozygosity, and repeat content:

```bash
meryl count k=21 reads.fq.gz output sample.meryl
meryl histogram sample.meryl > sample.hist
```

Upload the histogram file to GenomeScope 2.0 (#link("https://qb.cshl.edu/genomescope/genomescope2.0/")) to visualize the results.

*4. Evaluate homozygosity* of each strain by examining the fraction of heterozygous variant sites from standard reference-based variant calling (e.g., DeepVariant/GLnexus joint calling @yun2021). For inbred strains, close to 98% of variants should be homozygous. Flag any strain that deviates substantially (_see_ *Note 2*).

*5. Decontamination.* Screen assemblies for mitochondrial, chloroplast, and other contamination. The NCBI Foreign Contamination Screen (FCS; #link("https://github.com/ncbi/fcs")) provides a standardized approach. For simplicity, remove contigs shorter than 100 kb, which in Linked-Read assemblies typically represent unresolved haplotype segments or assembly fragments too short for reliable pangenome construction:

```bash
samtools faidx assembly.fasta
awk '$2 > 100000 {print $1}' assembly.fasta.fai > keep.list
samtools faidx -r keep.list assembly.fasta > assembly.clean.fasta
samtools faidx assembly.clean.fasta
```

*6. Identify telomeric repeats* to assess assembly completeness at chromosome ends:

```bash
seqtk telo assembly.fasta > assembly.telo.bed 2> assembly.telo.counts
```

The BED output (stdout) lists telomeric repeat intervals; the count summary (stderr) reports the number and total length of detected telomeres per sequence.

== PGGB pangenome construction

=== Input preparation

The PGGB pipeline outputs a pangenome graph in GFA format (version 1). Include the reference genome in the graph (_see_ *Note 3*). Although PGGB is reference-free, including the reference is essential for downstream variant calling relative to an established coordinate system and for comparison with existing datasets.

*1. Combine all haploid assemblies and the mRatBN7.2 reference* into a single multi-FASTA file:

```bash
rm -f combined.fa
ls *.fa.gz | cut -f 1 -d '.' | uniq | while read f; do
    echo "$f"
    zcat "${f}".fa.gz >> combined.fa
done
```

*2. Rename sequences* according to the PanSN-spec (Pangenome Sequence Naming specification) convention: `sample#haplotype#contig`. For example: `SHR#1#chr12`. Because the assemblies are haploid, the haplotype field is set to 1 for all strains:

```bash
rm -f in.fa
ls *.fa.gz | cut -f 1 -d '.' | uniq | while read f; do
    echo "${f}"
    # Using fastix (available in PGGB Docker image):
    zcat "${f}".fa.gz | fastix -p "${f}#1#" >> in.fa
    # Alternative without fastix:
    # zcat "${f}".fa.gz | sed "s/^>/>""${f}""#1#/" >> in.fa
done
```

*3. Compress and index:*

```bash
bgzip -@ 48 in.fa
samtools faidx in.fa.gz
```

=== All-to-All Alignment (WFMASH)

Run PGGB, which internally invokes WFMASH as its first step. The command used for the HXB/BXH pangenome was:

```bash
pggb -i in.fa.gz \
    -p 98 -s 2000 -n 32 \
    -F 0.001 -k 79 -P asm5 -O 0.03 \
    -G 4001,4507 \
    -V rn7:# \
    -t 48 -T 48 \
    -o output_dir
```

The main parameters passed to WFMASH are the mapping identity minimum `-p` and the segment length `-s`. Key parameters (_see_ *Notes 5--6* for parameter selection guidance):

- `-p 98`: percent identity threshold for mapping. Set to 98% because the HXB/BXH strains are closely related inbred strains derived from two parental strains. For more divergent comparisons, lower values (e.g., 90--95%) are appropriate.

- `-s 2000`: segment length for mapping (in bp). This sets the minimum length of aligned segments.

- `-n 32`: number of haplotypes in the input (31 RI strains + 1 reference).

- `-F 0.001`: k-mer frequency filter threshold. Ignores the top 0.1% most frequent k-mers in the MinHash sketches, reducing spurious alignments in repetitive regions. For scaling the number of pairwise comparisons with large inputs, see the `-x` sparsification option (_see_ *Note 7*).

WFMASH outputs alignments in PAF format. Each sequence is aligned directly against every other sequence, so that no single genome is privileged. The BiWFA algorithm computes base-level alignments from the segment-level mappings.

=== Graph induction (SEQWISH)

PGGB automatically invokes SEQWISH after alignment. SEQWISH reads the input genomes and the PAF alignments produced by WFMASH and induces a variation graph in GFA format. Graph induction often works better when very short exact matches are filtered out of the input alignments. These short matches typically occur in regions of low alignment quality, which are characteristic of areas with large indels and structural variations in the WFMASH alignments. A key parameter is:

- `-k 79`: minimum exact match length for graph induction. For the HXB/BXH pangenome, `-k 79` was used, appropriate for the low divergence between these closely related inbred strains (the default `-k 23` is suitable for divergences up to ~5%). Setting `-k N` means that the graph can tolerate a local pairwise difference rate of no more than 1/N: indels represented by complex series of edit operations are opened into bubbles, and alignment regions with very low identity are ignored.

=== Graph normalization (SMOOTHXG)

The raw graph from SEQWISH contains spurious local complexity. SMOOTHXG refines the graph by running a partial order alignment (POA) across segments, called blocks. Key parameters:

- `-G 4001,4507`: target sequence length (in bp) for POA blocks. Two comma-separated values specify two successive smoothing passes with block targets of ~4 kbp and ~4.5 kbp respectively, providing progressive refinement. Higher values make sense for lower-diversity pangenomes.

- `-P asm5`: POA scoring parameters, using a minimap2-style preset tuned for assemblies with ~0.1% divergence. This is appropriate for the closely related HXB/BXH strains.

- `-O 0.03`: POA block padding factor. Each block boundary is extended by 3% of the longest sequence in the block to improve alignment quality at block edges.

- `-T 48`: number of threads for POA steps.

=== Redundancy removal (GFAFFIX)

GFAFFIX collapses walk-preserving redundant nodes---nodes that share identical sequence prefixes or suffixes across all traversing paths. The final graph is sorted using ODGI. The output is a GFA file representing the complete pangenome variation graph.

=== Running PGGB chromosome by chromosome

For large genomes, it is practical to partition the input by chromosome and run PGGB independently on each chromosome (_see_ *Note 8*). Use WFMASH to map assembly contigs against the reference to assign contigs to chromosomes, then run PGGB on each chromosome subset separately. This reduces memory requirements and allows parallel execution on a cluster.

*Sequence partitioning.* Map each assembly against the reference genome using WFMASH:

```bash
# a. Combine all assemblies into a single FASTA and index
cat assemblies/*.fasta.gz > combined.fasta.gz
samtools faidx combined.fasta.gz

# b. List sample assembly files (excluding the reference)
ls assemblies/*.fasta.gz | grep -v rn7 \
    | xargs -I{} basename {} | sort -V | uniq > haps.list

# c. Map each assembly against the reference
REF=assemblies/rn7.fasta.gz
mkdir -p alignments
for HAP in $(cat haps.list); do
    wfmash -t 48 -m -N -p 90 -s 20000 \
        ${REF} assemblies/${HAP} \
        > alignments/${HAP}.vs.ref.paf
done
```

The `-m` flag requests mapping-only output (no base-level alignment), `-N` prevents query splitting (maps each sequence in one piece), `-p 90` sets a permissive identity threshold to capture divergent contigs, and `-s 20000` sets a 20 kbp segment length appropriate for chromosome-scale assignment.

*Subset by chromosome.* Extract contig names per chromosome and build chromosome-specific FASTAs:

```bash
# d. Extract contig names assigned to each chromosome
mkdir -p parts
for CHR in $(seq 1 20) X Y; do
    awk -v chr="chr${CHR}" '$6 ~ chr"$"' \
        alignments/*.vs.ref.paf \
        | cut -f 1 | sort -V \
        > parts/chr${CHR}.contigs
done

# e. Build per-chromosome FASTAs from mapped contigs
for CHR in $(seq 1 20) X Y; do
    xargs samtools faidx combined.fasta.gz \
        < parts/chr${CHR}.contigs \
        > parts/chr${CHR}.pan.fa
done

# f. Add the reference chromosome and compress
# (chrM is excluded: the mitochondrial genome is small
#  and has a distinct evolutionary history)
for CHR in $(seq 1 20) X Y; do
    samtools faidx ${REF} rn7#1#chr${CHR} \
        > parts/rn7.chr${CHR}.fa
    cat parts/rn7.chr${CHR}.fa parts/chr${CHR}.pan.fa \
        > parts/chr${CHR}.pan+ref.fa
    bgzip parts/chr${CHR}.pan+ref.fa
    samtools faidx parts/chr${CHR}.pan+ref.fa.gz
done
```

The output is a set of bgzip-compressed, indexed per-chromosome FASTAs (`chr${CHR}.pan+ref.fa.gz`), each containing all strain contigs mapping to that chromosome plus the corresponding reference sequence. Contigs that do not map to any chromosome (e.g., unplaced scaffolds) are excluded from this partitioning; if retaining them is important, they can be collected separately and processed as an additional partition.

*Run PGGB per chromosome:*

```bash
for CHR in $(seq 1 20) X Y; do
    pggb \
        -i parts/chr${CHR}.pan+ref.fa.gz \
        -p 98 -s 2000 -n 32 \
        -F 0.001 -k 79 -P asm5 -O 0.03 \
        -G 4001,4507 \
        -V rn7:# \
        -t 48 -T 48 \
        -o output/chr${CHR}.pan+ref
done
```

Each chromosome can be submitted as an independent job on an HPC cluster. Using a local scratch disk for intermediate files and moving results to persistent storage upon completion is recommended.

== Graph quality assessment

After construction, evaluate graph quality using ODGI and diagnostic visualizations.

*1. Graph statistics.* Compute total graph length, node count, edge count, path count, and non-reference sequence with odgi stats:

```bash
odgi stats -i graph.og -S
```

For MultiQC-compatible output, add the `-m -sgdl` flags:

```bash
odgi stats -i graph.og -m -sgdl
```

*2. 1D visualization.* Generate a linearized view of all paths against the pangenome sequence with odgi viz:

```bash
odgi viz -i graph.og -o graph.1D.png -x 500
```

Additional options: `-z` colors bars by node strandedness (black = forward, red = reverse); `-bm` colors bars by mean coverage depth (black = low, green = high).

*3. 2D visualization.* First compute a 2D layout, then render it as an image:

```bash
odgi layout -i graph.og -o graph.og.lay
odgi draw -i graph.og -c graph.og.lay -p graph.2D.png
```

*4. Subgraph extraction.* Extract and inspect specific regions of interest:

```bash
# By node ID (with context of 1 step)
odgi extract -i graph.og -n 23 -c 1 -o subgraph.og

# By reference coordinates (e.g., a 1 Mbp window on chr12)
odgi extract -i graph.og -r rn7#1#chr12:1000000-2000000 \
    -o subgraph.og
```

The 1D visualization produces a horizontal image in which each row represents a path (genome) through the graph; colored segments show how each path traverses graph nodes, with gaps indicating sequence absent from that path (Fig. 2A). The 2D layout reveals the topological structure of the graph: linear stretches appear as straight lines, while bubbles (variant sites) and complex rearrangements produce visible branching patterns (Fig. 2B). Both views are useful for quality control---for example, a large inversion will appear as a red (reverse-strand) segment in the 1D view and as a loop in the 2D view. For further discussion of visualization challenges and limitations, _see_ *Note 13*.

== Read mapping to the pangenome

Variants called from the pangenome graph via vg deconstruct (Section 3.5) are derived from the assemblies, not directly from the raw sequencing reads. To call variants from the reads themselves, the original reads are mapped back to the pangenome graph using vg Giraffe @siren2021 and then genotyped with `vg call`. In addition, the alignments can be surjected onto the reference path to produce a standard BAM file for read-level inspection of individual variant sites. vg Giraffe maps reads to a graph index:

*1. Build graph indexes.* Convert the GFA to the formats required by vg Giraffe:

```bash
# Convert GFA to vg format and compute snarls
vg autoindex --workflow giraffe \
    -g graph.gfa \
    -p graph_index \
    -t 48
```

The `autoindex` command creates the distance index, minimizer index, and GBWT haplotype index needed by Giraffe.

*2. Map reads.* Align paired-end reads against the pangenome graph:

```bash
vg giraffe \
    -Z graph_index.giraffe.gbz \
    -m graph_index.min \
    -d graph_index.dist \
    -f reads_1.fq.gz -f reads_2.fq.gz \
    -t 48 \
    -o gaf \
    > aligned.gaf
```

The output is in GAF (Graph Alignment Format). To convert to BAM for use with standard tools, surject the alignments onto the reference path:

```bash
vg surject -x graph_index.giraffe.gbz \
    -t 48 -b -G -N sample_name -R "sample_name" \
    aligned.gaf > aligned.bam
samtools sort -@ 48 aligned.bam -o aligned.sorted.bam
samtools index aligned.sorted.bam
```

*3. Call variants from read alignments.* Use `vg call` to genotype the snarls (bubble sites) in the graph based on the read alignments:

```bash
vg pack -x graph_index.giraffe.gbz \
    -g aligned.gaf -t 48 -o aligned.pack

vg call graph_index.giraffe.gbz \
    -k aligned.pack \
    -t 48 \
    --ref-path rn7 \
    > read_called.vcf
```

The `vg pack` step computes read support (coverage and quality) at each graph node and edge, and `vg call` uses this support to genotype each snarl relative to the specified reference path. The resulting VCF provides read-based variant calls that can be compared with the assembly-derived calls from vg deconstruct (Section 3.5) to identify variants supported by both lines of evidence.

The surjected BAM (Step 2) can also be used for visual inspection of read support at specific variant sites in a genome browser such as IGV @robinson2011.

vg Giraffe operates on any graph converted to GBZ format. When using a PGGB graph, the `vg autoindex` step (shown above) handles all necessary format conversions. Both PGGB and Minigraph-Cactus graphs are fully compatible with vg Giraffe (_see_ *Note 4*).

== Variant calling from the pangenome

Variants are extracted from the pangenome graph relative to the reference path using vg deconstruct, which identifies bubbles---pairs of divergent paths between shared anchors---and decomposes them into VCF records.

- `-V rn7:#`: specifies the reference prefix for VCF output. Variants are called relative to paths matching this prefix. vg deconstruct is invoked automatically by PGGB when the `-V` flag is set.

*Normalize and decompose* the resulting VCF using BCFtools:

```bash
bcftools norm -m -both -f rn7.fa output.vcf.gz | \
    bcftools view -e 'ALT="*"' | \
    bcftools sort -Oz -o normalized.vcf.gz
tabix normalized.vcf.gz
```

Perform reference-based variant calling using DeepVariant/GLnexus @yun2021 on the same sequencing data as a benchmark call set for validation (Section 3.5). DeepVariant and GLnexus are available as Docker containers and are used here only for benchmarking; they are not required for the pangenome workflow itself. Annotate variants using SnpEff @cingolani2012 for functional consequence prediction:

```bash
# Verify the exact database name for mRatBN7.2:
snpEff databases | grep -i "rattus"
# Then run annotation (adjust database name as needed):
snpEff mRatBN7.2 input.vcf > annotated.vcf
```

== Validation strategies

=== Cross-validation with reference-based Joint Calling

Process both the pangenome-derived and reference-based call sets to remove missing data, N-allele sites, homozygous reference genotypes, and variants >50 bp. Compare call sets using RTG Tools vcfeval with the `--squash-ploidy` option (since the inbred strains are essentially isogenic, haploid pangenome calls are treated as homozygous diploid for comparison):

```bash
# Create an SDF from the reference FASTA
rtg format -o ref.sdf reference.fa

# Run vcfeval to compute precision, recall, and F1-score
rtg vcfeval \
    -t ref.sdf \
    -b truth/sample.joint_calling.snps.vcf.gz \
    -c pangenome/sample.pggb.snps.vcf.gz \
    --squash-ploidy \
    -e easy_regions.bed \
    -T 48 \
    -o vcfeval_output/snps
```

Here `-b` specifies the baseline (truth) VCF from reference-based joint calling, `-c` is the pangenome-derived call set to evaluate, `-e` restricts evaluation to confidently callable regions (e.g., RepeatMasker-derived easy regions excluding low-complexity repeats), and `-T` sets the number of threads. The output contains precision, recall, F1-score, and partitioned true-positive, false-positive, and false-negative VCFs (_see_ *Note 9*).

=== Cross-validation with MUMMER4

An independent validation approach uses NUCMER (part of MUMMER4 @marcais2018) to generate pairwise alignments between individual genome sequences and call variants from these alignments:

```bash
# Align sample assembly against the reference
nucmer --maxmatch -l 100 -c 500 \
    reference.fa sample.fa -p sample

# Filter alignments and call variants
delta-filter -1 sample.delta > sample.filtered.delta
show-snps -Clr sample.filtered.delta > sample.snps
```

The NUCMER-derived variants are converted to VCF format and compared against the pangenome-derived call set using RTG Tools vcfeval as described above. F1-scores exceeding 90% have been obtained across diverse genomic contexts @garrison2024.

== Structural variant analysis

Structural variants (≥50 bp) are called from the pangenome using a multi-method approach to maximize sensitivity and specificity. For the full pipeline and detailed analysis, see @villani2025.

*1. Assembly-based SV calling.* Align each sample assembly against the reference with minimap2 @li2018 and call SVs using three independent methods:

```bash
REF=reference.fa
for SAMPLE in $(cat samples.list); do
    # Align assembly to reference
    minimap2 -ax asm5 -L --cs -t 48 ${REF} \
        assemblies/${SAMPLE}.fa \
        | samtools sort -m 8G -@ 48 -o ${SAMPLE}.bam -
    samtools index ${SAMPLE}.bam

    # Method 1: SVIM-asm (haploid mode)
    svim-asm haploid svim_out/ ${SAMPLE}.bam ${REF} \
        --sample ${SAMPLE} --query_names \
        --interspersed_duplications_as_insertions \
        --min_sv_size 50

    # Method 2: PAV
    # Requires config.json pointing to reference and
    # assemblies.tsv listing sample paths (see PAV docs)

    # Method 3: Hall-lab pipeline
    # Uses paftools.js call (distributed with minimap2,
    # requires the k8 JavaScript runtime) for variant
    # detection from the alignment, followed by VCF conversion
done
```

For each caller, normalize and filter the output to retain only SVs (≥50 bp):

```bash
bcftools norm -m -any -f ${REF} ${SAMPLE}.raw.vcf.gz -cs \
    | bcftools norm -d exact \
    | bcftools view -i 'STRLEN(REF)>=50 | STRLEN(ALT)>=50' \
    | bcftools sort | bgzip -c > ${SAMPLE}.caller.vcf.gz
tabix ${SAMPLE}.caller.vcf.gz
```

*2. Graph-based SV calling from PGGB.* Extract per-sample SVs from the pangenome VCF produced by vg deconstruct. Use vcfbub to remove nested alleles and vcfwave to decompose complex variants:

```bash
# Decompose complex alleles from the pangenome VCF
vcfbub -l 0 -a 100000 --input pangenome.vcf.gz \
    | vcfwave -t 48 -I 1000 \
    | bgzip -c > pangenome.wave.vcf.gz

# Extract per-sample SVs
for SAMPLE in $(cat samples.list); do
    bcftools annotate -x INFO pangenome.wave.vcf.gz \
        | bcftools view -a -s ${SAMPLE} -Ou \
        | bcftools norm -f ${REF} -c s -m - -Ou \
        | bcftools view -e 'GT="ref" | GT~"\."' \
            -f 'PASS,.' -Ou \
        | bcftools sort -Ou \
        | bcftools norm -d exact \
        | bcftools view \
            -i 'STRLEN(REF)>=50 | STRLEN(ALT)>=50' \
        | bgzip -c > ${SAMPLE}.pggb.vcf.gz
    tabix ${SAMPLE}.pggb.vcf.gz
done
```

*3. Multi-method merging.* Merge SV calls across all four methods per sample using SURVIVOR @jeffares2017, requiring agreement from at least two callers on type and strand within a 1,000 bp breakpoint distance. Note that SURVIVOR can over-merge distinct events when the breakpoint distance parameter is set too high; 1,000 bp is a reasonable compromise for mammalian genomes, but users should inspect merged calls in regions with clustered SVs:

```bash
for SAMPLE in $(cat samples.list); do
    # List per-caller VCFs for this sample
    printf '%s\n' ${SAMPLE}.hall-lab.vcf.gz \
        ${SAMPLE}.pggb.vcf.gz ${SAMPLE}.svim-asm.vcf.gz \
        ${SAMPLE}.pav.vcf.gz > ${SAMPLE}.file_list

    # Merge: 1000bp max distance, >=2 callers,
    # agree on type and strand, min SV size 50bp
    SURVIVOR merge ${SAMPLE}.file_list \
        1000 2 1 1 0 50 ${SAMPLE}.merged.vcf

    # Filter variants with >10% Ns in REF/ALT
    filter_Ns.py 10 < ${SAMPLE}.merged.vcf \
        | bcftools sort \
        | bgzip -c > ${SAMPLE}.merged.filtered.vcf.gz
    tabix ${SAMPLE}.merged.filtered.vcf.gz
done
```

*4. Cross-sample merging.* Merge the per-sample filtered call sets into a single cohort VCF:

```bash
ls *.merged.filtered.vcf.gz | while read f; do
    SAMPLE=$(basename $f .merged.filtered.vcf.gz)
    bcftools view \
        -s $(bcftools query -l $f | head -1) $f \
        > ${SAMPLE}.vcf
done

ls *.merged.filtered.vcf.gz > sample_files
SURVIVOR merge sample_files 1000 2 1 1 0 50 \
    all_samples.merged.vcf

bcftools sort all_samples.merged.vcf \
    | bgzip -c > all_samples.merged.vcf.gz
tabix all_samples.merged.vcf.gz
```

Note that PGGB's graph-based method typically reports fewer SVs than assembly-based methods (_see_ *Note 10*).

*5. Complex SV inspection.* For complex SVs, extract the local subgraph using ODGI and visualize with Bandage (#link("https://rrwick.github.io/Bandage/")) or ODGI to reveal all realized haplotypes. For example, a complex insertion in the _Cd209c_ gene was resolved into multiple variable blocks forming distinct haplotypes across the RI panel (_see_ *Note 11*).

*6.* Annotate SV content with RepeatMasker @tarailo2009 to identify retrotransposon content (LINEs, SINEs) within structural variants.

== Phenome-Wide Association Study (PheWAS)

The pangenome enables discovery of novel variants that can be immediately tested for phenotypic associations using the extensive HXB/BXH phenotype database.

*1. Prepare the genotype file.* Extract genotypes for validated pangenome-only variants and convert to a BXDtools-compatible format:

```bash
# Extract genotype calls from validated variants
bcftools query -f '%CHROM\t%POS\t[ %GT]\n' \
    validated_variants.vcf.gz \
    -o validated.gt.txt
```

Convert to a genotype matrix in R (≥ 4.0). Install BXDtools if not already available: `devtools::install_github("DannyArends/BXDtools")` in R.

```r
# Read genotype calls and sample names
vcf <- read.table("validated.gt.txt")
samples <- read.table("samples.txt", header = FALSE)
colnames(vcf) <- c("Chr", "POS", samples$V1)

# Create locus identifiers (e.g., chr12_4347739)
vcf$Locus <- paste0(vcf$Chr, "_", vcf$POS)
vcf <- vcf[!duplicated(vcf$Locus), ]

# Recode: 0 (ref) -> "B", 1 (alt) -> "A", missing -> "U"
vcf[vcf == "0"] <- "B"
vcf[vcf == "1"] <- "A"
vcf[vcf == "."] <- "U"

# Add required columns and format for BXDtools
vcf$cM <- "."
vcf$Mb <- vcf$POS / 1e6
vcf$Chr <- gsub("chr", "", vcf$Chr)
write.table(vcf, "HXB.geno", row.names = FALSE,
    sep = "\t", quote = FALSE)
```

*2. Download phenotype data and run PheWAS.* Retrieve trait metadata and sample data from GeneNetwork via the API, then run association analysis using an adaptation of BXDtools @arends_bxdtools:

```r
library(BXDtools)

# GeneNetwork API endpoints:
# genenetwork.org/api/v_pre1/traits/HXBBXHPublish.csv
# genenetwork.org/api/v_pre1/sample_data/HXBBXHPublish.csv

# Load genotypes and recode to numeric
bxd.geno <- read.table("HXB.geno", sep = "\t",
    header = TRUE, row.names = 1)
bxd.genotypes <- recode.BXD.genotypes(
    only.BXD.genotypes(bxd.geno))

# Load phenotypes, match samples to genotype file
bxd.pheno <- download.BXD.phenotypes()
bxd.genotypes <- bxd.genotypes[,
    colnames(bxd.genotypes) %in% colnames(bxd.pheno)]

# Build phenotype matrix, filter, group phenosomes
bxd.phenotypes <- as.phenotype.matrix(
    bxd.genotypes, bxd.pheno)
bxd.phenosomes <- only.phenosomes(
    bxd.phenotypes, minimum = 1)

# Run PheWAS for a validated marker
marker <- "chr12_4347739"
scores <- do.BXD.phewas(bxd.genotypes,
    bxd.phenosomes, marker = marker, LRS = TRUE)

# Plot with LRS > 16 significance threshold
pdf("phewas_result.pdf", width = 7, height = 7)
plot.phewas(scores, bxd.phenosomes, do.sort = TRUE,
    main = paste0("HXB PheWAS at ", marker),
    significance = 16)
dev.off()
```

The `do.BXD.phewas` function computes Spearman correlations between genotype and each phenotype, with Bonferroni correction for multiple testing. Significant associations (LRS > 16) are reported. Note that with only ~30 RI strains, statistical power is limited, particularly for variants with small effect sizes or low minor allele frequency; results should be interpreted as hypothesis-generating rather than definitive. For a more rigorous primary analysis, a linear mixed model (LMM) with leave-one-chromosome-out (LOCO) kinship correction is recommended (Step 3). Adapted scripts are available at #link("https://github.com/Flavia95/HXB_rat_pangenome_manuscript/blob/main/workflows/3_PheWAS.md").

*3. Confirm associations.* Validate significant PheWAS hits using a linear mixed model (LMM) corrected for kinship, as implemented in GeneNetwork or GEMMA @zhou2012. Use a leave-one-chromosome-out (LOCO) kinship matrix to avoid proximal contamination---i.e., inflated statistics caused by including the test locus in the kinship estimate. This LMM step is essential for controlling false positives arising from the shared relatedness structure among RI strains (_see_ *Note 12*).

*4. Functional annotation.* Cross-reference significant associations with previously mapped QTLs using the Rat Genome Database (RGD; #link("https://rgd.mcw.edu")[rgd.mcw.edu]) @smith2020 and the Ensembl Genome Browser @martin2023 selecting the mRatBN7.2 reference genome @dejong2024.

*Expected results.* Applying this workflow to the HXB/BXH panel, the following associations were identified @villani2025: (a) A variant (chr12\_4347739) within a long non-coding RNA gene was associated with blood glucose concentration and located on the same chromosome as a previously mapped QTL controlling insulin/glucose ratio (Insglur6, LOD 18.97). (b) An intronic variant (chr12\_18797475) within a locus similar to the paired immunoglobulin-like type 2 receptor was associated with both blood insulin concentration and hippocampal chromogranin A (CGA) expression. Additionally, validated SVs were found in disease-relevant genes including _Lmtk2_ (implicated in neurodegeneration, including Alzheimer's disease) and _Mcemp1_ (a critical factor in allergic and inflammatory lung diseases).
