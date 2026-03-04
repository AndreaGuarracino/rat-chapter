= Methods

All software listed in Section 2 should be installed before proceeding. Adjust the `-t` thread count in all commands below to match your available CPU cores. Commands that use `pggb`, `vg`, or `odgi` require the `pggb` conda environment; commands that use other downstream tools (e.g., `bcftools`, `snpEff`, `minimap2`, `vcfbub`, `vcfwave`) require the `pangenome-tools` environment. Activate the appropriate environment before running each set of commands (e.g., `conda activate pggb` or `conda activate pangenome-tools`). When using Docker, all tools are available in a single container.

Throughout this protocol, assembly files are stored in an `assemblies/` directory. Create this directory and place each genome assembly as a bgzip-compressed FASTA file named `<strain>.fa.gz` (e.g., `rn7.fa.gz`, `SHR.fa.gz`, `BXH2.fa.gz`), including the reference genome as `rn7.fa.gz`. For steps that require raw sequencing reads (Sections 3.1 and 3.4), paired-end FASTQ files should be available as `reads/<strain>_1.fq.gz` and `reads/<strain>_2.fq.gz`.

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

On an HPC cluster, each strain can be submitted as an independent job. The majority of BUSCO orthologs should be complete and single-copy, indicating high assembly quality.

*3. Evaluate heterozygosity and genome characteristics.* Use K-mer counting with Meryl @rhie2020 and GenomeScope @vurture2017 to estimate genome size, heterozygosity, and repeat content:

```bash
STRAIN=BXH2  # adjust per strain
meryl count k=21 reads/${STRAIN}_1.fq.gz \
    reads/${STRAIN}_2.fq.gz output ${STRAIN}.meryl
meryl histogram ${STRAIN}.meryl > ${STRAIN}.hist
```

Upload the histogram file to GenomeScope 2.0 (#link("https://qb.cshl.edu/genomescope/genomescope2.0/")) to visualize the results.

*4. Evaluate homozygosity* of each strain by examining the fraction of heterozygous variant sites from standard reference-based variant calling (e.g., DeepVariant/GLnexus joint calling @yun2021). For inbred strains, close to 98% of variants should be homozygous. Flag any strain that deviates substantially (_see_ *Note 2*).

*5. Decontamination.* Screen assemblies for mitochondrial, chloroplast, and other contamination. The NCBI Foreign Contamination Screen (FCS; #link("https://github.com/ncbi/fcs")) @astashyn2024 provides a standardized approach. For simplicity, remove contigs shorter than 100 kb, which in Linked-Read assemblies typically represent unresolved haplotype segments or assembly fragments too short for reliable pangenome construction:

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
for f in assemblies/*.fa.gz; do
    STRAIN=$(basename "$f" .fa.gz)
    echo "$STRAIN"
    zcat "$f" >> combined.fa
done
```

*2. Rename sequences* according to the PanSN-spec (Pangenome Sequence Naming specification) convention: `sample#haplotype#contig`. For example: `SHR#1#chr12`. Because the assemblies are haploid, the haplotype field is set to 1 for all strains:

```bash
rm -f in.fa
for f in assemblies/*.fa.gz; do
    STRAIN=$(basename "$f" .fa.gz)
    echo "$STRAIN"
    # Using fastix (available in PGGB Docker image):
    zcat "$f" | fastix -p "${STRAIN}#1#" >> in.fa
    # Alternative without fastix:
    # zcat "$f" | sed "s/^>/>""${STRAIN}""#1#/" >> in.fa
done
```

*3. Compress and index:*

```bash
bgzip -@ 48 in.fa
samtools faidx in.fa.gz
```

=== All-to-All Alignment (WFMASH)

Run PGGB, which internally invokes all four pipeline stages in sequence. The following single command was used for the HXB/BXH pangenome; parameters are grouped by the module they control and explained in the subsections below:

```bash
pggb -i in.fa.gz \
    -p 98 -s 2000 -n 32 \
    -F 0.001 -k 79 -P asm5 -O 0.03 \
    -G 4001,4507 \
    -V rn7:# \
    -t 48 -T 48 \
    -o output_dir
```

- `-V rn7:#`: reference path prefix for variant calling. When this flag is set, PGGB automatically invokes vg deconstruct after graph construction, producing a VCF file with variants called relative to all paths starting with `rn7` (Section 3.5).

The main parameters passed to WFMASH are the mapping identity minimum `-p` and the segment length `-s`. Key parameters (_see_ *Notes 5--6* for parameter selection guidance):

- `-p 98`: percent identity threshold for mapping. Set to 98% because the HXB/BXH strains are closely related inbred strains derived from two parental strains. For more divergent comparisons, lower values (e.g., 90--95%) are appropriate.

- `-s 2000`: segment length for mapping (in bp). This sets the minimum length of aligned segments.

- `-n 32`: number of haplotypes in the input (31 RI strains + 1 reference).

- `-F 0.001`: k-mer frequency filter threshold. Ignores the top 0.1% most frequent k-mers in the minmer sketches, reducing spurious alignments in repetitive regions. For scaling the number of pairwise comparisons with large inputs, see the `-x` sparsification option (_see_ *Note 7*).

WFMASH outputs alignments in PAF format. Each sequence is aligned directly against every other sequence, so that no single genome is privileged. The BiWFA algorithm computes base-level alignments from the segment-level mappings.

PGGB writes several output files to `output_dir`, including: the final pangenome graph in GFA format (`*.smooth.final.gfa`) and ODGI binary format (`*.smooth.final.og`); 1D visualization PNGs; and a VCF file with variants relative to the reference paths when `-V` is set. Use the `.smooth.final.og` file as input for graph quality assessment (Section 3.3) and subsequent steps.

=== Graph induction (SEQWISH)

PGGB automatically invokes SEQWISH after alignment. SEQWISH reads the input genomes and the PAF alignments produced by WFMASH and induces a variation graph in GFA format. Graph induction often works better when very short exact matches are filtered out of the input alignments. These short matches typically occur in regions of low alignment quality, which are characteristic of areas with large indels and structural variations in the WFMASH alignments. A key parameter is:

- `-k 79`: minimum exact match length for graph induction. For the HXB/BXH pangenome, `-k 79` was used, appropriate for the low divergence between these closely related inbred strains (the default `-k 23` is suitable for divergences up to ∼5%). Setting `-k N` means that the graph can tolerate a local pairwise difference rate of no more than 1/N: indels represented by complex series of edit operations are opened into bubbles, and alignment regions with very low identity are ignored.

=== Graph normalization (SMOOTHXG)

The raw graph from SEQWISH contains spurious local complexity. SMOOTHXG refines the graph by running a partial order alignment (POA) across segments, called blocks. Key parameters:

- `-G 4001,4507`: target sequence length (in bp) for POA blocks. Two comma-separated values specify two successive smoothing passes with block targets of ∼4 kb and ∼4.5 kb respectively, providing progressive refinement. Higher values make sense for lower-diversity pangenomes.

- `-P asm5`: POA scoring parameters, using a minimap2-style preset tuned for assemblies with ∼0.1% divergence. This is appropriate for the closely related HXB/BXH strains.

- `-O 0.03`: POA block padding factor. Each block boundary is extended by 3% of the longest sequence in the block to improve alignment quality at block edges.

- `-T 48`: number of threads for POA steps.

=== Redundancy removal (GFAFFIX)

GFAFFIX collapses walk-preserving redundant nodes (nodes that share identical sequence prefixes or suffixes across all traversing paths). The final graph is sorted using ODGI. The output is a GFA file representing the complete pangenome variation graph.

=== Running PGGB chromosome by chromosome

As an alternative to running PGGB on the whole genome at once (Sections 3.2.1--3.2.4), large genomes can be partitioned by chromosome and processed independently (_see_ *Note 8*). This approach reduces peak memory requirements and enables parallel execution on a cluster. Use WFMASH to map assembly contigs against the reference to assign contigs to chromosomes, then run PGGB on each chromosome subset separately.

*Sequence partitioning.* This section uses the PanSN-renamed and indexed `in.fa.gz` from Sections 3.2.1--3.2.2. Map each assembly against the reference genome using WFMASH:

```bash
# a. List non-reference haplotypes from the PanSN-named FASTA
grep "^>" <(zcat in.fa.gz) | sed 's/>//' | cut -f1 -d'#' \
    | sort -u | grep -v rn7 > haps.list

# b. Map each assembly against the reference
REF=assemblies/rn7.fa.gz
mkdir -p alignments
for HAP in $(cat haps.list); do
    # Extract this haplotype's sequences from in.fa.gz
    samtools faidx in.fa.gz \
        $(grep "^${HAP}#" in.fa.gz.fai | cut -f1) \
        > ${HAP}.tmp.fa
    wfmash -t 48 -m -N -p 90 -s 20000 \
        ${REF} ${HAP}.tmp.fa \
        > alignments/${HAP}.vs.ref.paf
    rm ${HAP}.tmp.fa
done
```

The `-m` flag requests mapping-only output (no base-level alignment), `-N` prevents query splitting (maps each sequence in one piece), `-p 90` sets a permissive identity threshold to capture divergent contigs, and `-s 20000` sets a 20 kb segment length appropriate for chromosome-scale assignment. The contig names in the PAF output will use PanSN-spec names (e.g., `SHR#1#scaffold_123`) since the input is the renamed `in.fa.gz`.

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
    xargs samtools faidx in.fa.gz \
        < parts/chr${CHR}.contigs \
        > parts/chr${CHR}.pan.fa
done

# f. Add the reference chromosome and compress
# (chrM is excluded: the mitochondrial genome is small
#  and has a distinct evolutionary history)
for CHR in $(seq 1 20) X Y; do
    samtools faidx in.fa.gz rn7#1#chr${CHR} \
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

Each chromosome can be submitted as an independent job on an HPC cluster. Using a local scratch disk for intermediate files and moving results to persistent storage upon completion is recommended. After all chromosomes complete, concatenate the per-chromosome VCFs into a genome-wide file:

```bash
bcftools concat -Oz -o genome_wide.vcf.gz \
    output/chr*//*.vcf.gz
tabix genome_wide.vcf.gz
```

For read mapping (Section 3.4), merge the per-chromosome graphs into a single genome-wide graph using `odgi squeeze` before building the Giraffe indexes, since whole-genome reads must be mapped against the complete graph.

== Graph quality assessment

After construction, evaluate graph quality using ODGI and diagnostic visualizations. In the commands below, replace `graph.og` with the `*.smooth.final.og` file from the PGGB output directory.

*1. Graph statistics.* Compute total graph length, node count, edge count, path count, and non-reference sequence with odgi stats:

```bash
odgi stats -i graph.og -S
```

For a well-constructed pangenome of 32 closely related haplotypes, the total graph length should modestly exceed a single reference genome size, and all paths should cover close to 100% of the input sequences. For MultiQC-compatible YAML output, use the `-m` flag (which produces a comprehensive set of statistics in a format compatible with MultiQC):

```bash
odgi stats -i graph.og -m
```

*2. 1D visualization.* Generate a linearized view of all paths against the pangenome sequence with odgi viz:

```bash
odgi viz -i graph.og -o graph.1D.png -x 500
```

The `-x 500` flag sets the image width to 500 pixels; increase this value for larger graphs to avoid losing resolution. Additional options: `-z` colors bars by node strandedness (black = forward, red = reverse); `-b` draws path borders in black; `-m` colors bars by mean coverage depth (black = low, blue = high).

*3. 2D visualization.* First compute a 2D layout, then render it as an image:

```bash
odgi layout -i graph.og -o graph.og.lay
odgi draw -i graph.og -c graph.og.lay -p graph.2D.png
```

*4. Subgraph extraction.* Extract and inspect specific regions of interest:

```bash
# By node ID (with context of 1 step)
odgi extract -i graph.og -n 23 -c 1 -o subgraph.og

# By reference coordinates (e.g., a 1 Mb window on chr12)
odgi extract -i graph.og -r rn7#1#chr12:1000000-2000000 \
    -o subgraph.og
```

The 1D visualization produces a horizontal image in which each row represents a path (genome) through the graph; colored segments show how each path traverses graph nodes, with gaps indicating sequence absent from that path. The 2D layout reveals the topological structure of the graph: linear stretches appear as straight lines, while bubbles (variant sites) and complex rearrangements produce visible branching patterns. Both views are useful for quality control; for example, a large inversion will appear as a red (reverse-strand) segment in the 1D view and as a loop in the 2D view (_see_ *Note 13* for further discussion of visualization challenges and limitations).

== Read mapping to the pangenome

Variants called from the pangenome graph via vg deconstruct (Section 3.5) are derived from the assemblies, not directly from the raw sequencing reads. To call variants from the reads themselves, the original reads are mapped back to the pangenome graph using vg Giraffe @siren2021 and then genotyped with `vg call`. The alignments can also be surjected onto the reference path to produce a standard BAM file for read-level inspection of individual variant sites. The steps below describe how to build the graph index, map reads, call variants, and surject alignments:

*1. Chop long nodes and build graph indexes.* PGGB graphs can contain nodes longer than vg Giraffe expects. Use ODGI to chop nodes into smaller pieces (preserving topology and path order), then build the Giraffe indexes:

```bash
# Chop nodes to a maximum of 256 bp
odgi chop -c 256 -i graph.og -o graph.chop.og
odgi view -i graph.chop.og -g > graph.chop.gfa

# Build Giraffe indexes (distance, minimizer, GBWT)
vg autoindex --workflow giraffe \
    -g graph.chop.gfa \
    -p graph_index \
    -t 48
```

The `autoindex` command creates the distance index, minimizer index, and GBWT haplotype index needed by Giraffe.

*2. Map reads.* Align paired-end reads against the pangenome graph:

```bash
vg giraffe \
    -Z graph_index.giraffe.gbz \
    -m graph_index.shortread.withzip.min \
    -z graph_index.shortread.zipcodes \
    -d graph_index.dist \
    -f reads_1.fq.gz -f reads_2.fq.gz \
    -t 48 \
    > aligned.gam
```

The output is in GAM (Graph Alignment Map) format.

*3. Call variants from read alignments.* Compute read support at each graph node and edge with `vg pack`, then genotype each snarl (bubble site) with `vg call`:

```bash
vg pack -x graph_index.giraffe.gbz \
    -g aligned.gam \
    -t 48 \
    -o aligned.pack

vg call graph_index.giraffe.gbz \
    -k aligned.pack \
    -S rn7 \
    -a -t 48 \
    > read_called.vcf
```

The `-g` flag specifies GAM-format input (use `-a` instead for GAF format). The `-S rn7` flag anchors VCF output coordinates to the rn7 reference sample paths. The `-a` flag instructs `vg call` to output genotypes for all snarls, including homozygous reference sites; omit `-a` to output only non-reference variant calls.

*4. Surject to BAM for visual inspection.* GAM alignments can be surjected onto the reference path to produce a standard BAM file for read-level inspection in IGV @robinson2011. Alternatively, vg Giraffe can output GAF (Graph Alignment Format) by adding the `-o gaf` flag; in that case, pass `-G` to `vg surject` to indicate GAF input.

```bash
vg surject -x graph_index.giraffe.gbz \
    -p "rn7#1#" \
    -t 48 -b -N sample_name -R "sample_name" \
    aligned.gam > aligned.bam
samtools sort -@ 48 aligned.bam -o aligned.sorted.bam
samtools index aligned.sorted.bam
```

The `-p` flag restricts surjection to paths matching the given prefix (here, the rn7 reference paths); without it, surjection considers all paths in the graph, which can be extremely slow.

=== Cross-validation of assembly-based and read-based calls

The read-based call set (Section 3.4, step 3) can be intersected with the assembly-based call set (Section 3.5) to identify variants supported by both lines of evidence and to flag potential false positives in either approach:

```bash
# Normalize both call sets
bcftools norm -m -any read_called.vcf \
    | bgzip -c > read_called.norm.vcf.gz
tabix read_called.norm.vcf.gz

bcftools norm -m -any -f rn7.fa normalized.vcf.gz \
    | bgzip -c > pangenome.norm.vcf.gz
tabix pangenome.norm.vcf.gz

# Intersect: variants called by both methods
bcftools isec -p isec_output \
    read_called.norm.vcf.gz pangenome.norm.vcf.gz
```

The `bcftools isec` output directory contains four VCF files: records private to the read-based calls (0000.vcf), records private to the assembly-based calls (0001.vcf), and records shared by both (0002.vcf, 0003.vcf). Variants confirmed by both approaches represent high-confidence calls; variants found only in one call set can be inspected further to identify potential false positives in either approach.

vg Giraffe operates on any graph converted to GBZ format. When using a PGGB graph, the `odgi chop` and `vg autoindex` steps handle all necessary format conversions. Both PGGB and Minigraph-Cactus graphs are fully compatible with vg Giraffe (_see_ *Note 4*).

== Variant calling from the pangenome

Variants are extracted from the pangenome graph relative to the reference path using vg deconstruct, which identifies bubbles (pairs of divergent paths between shared anchors) and decomposes them into VCF records.

- `-V rn7:#`: specifies the reference prefix for VCF output. Variants are called relative to paths matching this prefix. vg deconstruct is invoked automatically by PGGB when the `-V` flag is set.

*Normalize and decompose* the resulting VCF (the `*.vcf.gz` file from the PGGB output directory, or the per-chromosome VCFs concatenated with `bcftools concat`) using BCFtools. The reference FASTA must be uncompressed and indexed (`samtools faidx rn7.fa`):

```bash
bcftools norm -m -both -f rn7.fa output.vcf.gz | \
    bcftools view -e 'ALT="*"' | \
    bcftools sort -Oz -o normalized.vcf.gz
tabix normalized.vcf.gz
```

The `ALT="*"` filter removes spanning deletion records (placeholder alleles indicating that a position is covered by a deletion defined at an upstream site). These records are not informative for per-site variant analysis and can cause issues with downstream tools.

Optionally, perform reference-based variant calling using DeepVariant/GLnexus @yun2021 on the same sequencing data as a benchmark call set for validation (Section 3.6). DeepVariant and GLnexus are available as Docker containers (`google/deepvariant` and `quay.io/mlin/glnexus`); see the DeepVariant documentation (#link("https://github.com/google/deepvariant")) for per-sample calling and GLnexus for joint genotyping. These tools are used here only for benchmarking; they are not required for the pangenome workflow itself. Annotate variants using SnpEff @cingolani2012 for functional consequence prediction:

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

Here `-b` specifies the baseline (truth) VCF from reference-based joint calling, `-c` is the pangenome-derived call set to evaluate, and `-T` sets the number of threads. The optional `-e` flag restricts evaluation to confidently callable regions; to generate `easy_regions.bed`, run RepeatMasker on the reference, then use `bedtools complement` to obtain the non-repetitive regions. Omit `-e` to evaluate across the full genome. The output contains precision, recall, F1-score, and partitioned true-positive, false-positive, and false-negative VCFs (_see_ *Note 9*).

=== Cross-validation with MUMmer4

An independent validation approach uses NUCMER (part of MUMmer4 @marcais2018) to generate pairwise alignments between individual genome sequences and call variants from these alignments:

```bash
# Align sample assembly against the reference
nucmer reference.fa sample.fa --prefix sample

# Call variants from alignments
show-snps -THC sample.delta > sample.var.txt
```

Optionally, filter the `.delta` file with `delta-filter -1` before `show-snps` to retain only the best one-to-one alignment for each region, which reduces ambiguity in repetitive areas. The NUCMER-derived SNPs are converted to VCF format using the `nucmer2vcf.R` script provided in the PGGB repository (`scripts/nucmer2vcf.R`) and compared against the pangenome-derived call set using RTG Tools vcfeval as described above. The output directory contains `summary.txt` with precision, recall, and F1-score. F1-scores generally exceeding 90% have been obtained across diverse genomic contexts @garrison2024.

== Structural variant analysis

Structural variants (≥50 bp) are called from the pangenome using a multi-method approach to maximize sensitivity and specificity. For the full pipeline and detailed analysis, see @villani2025.

Create a list of non-reference sample names for use in the commands below:

```bash
grep -v rn7 haps.list > samples.list
```

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
    svim-asm haploid svim_out/${SAMPLE}/ ${SAMPLE}.bam ${REF} \
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
bcftools norm -m -any -f ${REF} ${SAMPLE}.raw.vcf.gz -c s \
    | bcftools norm -d exact \
    | bcftools view -i 'STRLEN(REF)>=50 | STRLEN(ALT)>=50' \
    | bcftools sort | bgzip -c > ${SAMPLE}.caller.vcf.gz
tabix ${SAMPLE}.caller.vcf.gz
```

*2. Graph-based SV calling from PGGB.* Extract per-sample SVs from the pangenome VCF produced by vg deconstruct. Use vcfbub to remove nested alleles and vcfwave to decompose complex variants. The vcfbub `-l 0` flag removes all nested (multi-level) alleles, retaining only top-level bubbles; `-a 100000` discards alleles longer than 100 kb, which are typically artifacts from graph topology. The vcfwave `-I 1000` flag sets the minimum allele length to consider for inverted alignment (default: 64 bp):

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

    # Filter variants with >10% Ns in REF or ALT
    awk '/^#/{print;next}
        {r=$4; a=$5; lr=length(r); la=length(a);
         nr=gsub(/N/,"",r); na=gsub(/N/,"",a);
         if((lr==0||100*nr/lr<=10) && (la==0||100*na/la<=10))
           print}' \
        ${SAMPLE}.merged.vcf \
        | bcftools sort \
        | bgzip -c > ${SAMPLE}.merged.filtered.vcf.gz
    tabix ${SAMPLE}.merged.filtered.vcf.gz
done
```

*4. Cross-sample merging.* Merge the per-sample filtered call sets into a single cohort VCF. SURVIVOR requires uncompressed VCF input:

```bash
# Decompress per-sample VCFs for SURVIVOR
mkdir -p cross_sample
for f in *.merged.filtered.vcf.gz; do
    SAMPLE=$(basename $f .merged.filtered.vcf.gz)
    zcat $f > cross_sample/${SAMPLE}.vcf
done

# Create file list and merge across samples
# Retain SVs found in at least 2 samples
# (same type and strand, <=1000 bp breakpoint distance)
ls cross_sample/*.vcf > sample_files
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
# Extract sample names and genotype calls from validated variants
bcftools query -l validated_variants.vcf.gz > samples.txt
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

Although the BXDtools function names contain "BXD" (the package was originally developed for BXD mouse RI strains), they work with any RI population when provided with the appropriate genotype and phenotype files. For species without RI populations or GeneNetwork phenotype data, replace Steps 1--2 with your own genotype--phenotype matrix preparation and use GEMMA or a similar LMM tool (Step 3) as the primary association method. The `do.BXD.phewas` function computes Spearman correlations between genotype and each phenotype, with Bonferroni correction for multiple testing. Significant associations (likelihood ratio statistic, LRS > 16) are reported. Note that with only ∼30 RI strains, statistical power is limited, particularly for variants with small effect sizes or low minor allele frequency; results should be interpreted as hypothesis-generating rather than definitive. For a more rigorous primary analysis, a linear mixed model (LMM) with leave-one-chromosome-out (LOCO) kinship correction is recommended (Step 3). Adapted scripts are available at #link("https://github.com/Flavia95/HXB_rat_pangenome_manuscript/blob/main/workflows/3_PheWAS.md").

*3. Confirm associations.* Validate significant PheWAS hits using a linear mixed model (LMM) corrected for kinship, as implemented in GeneNetwork or GEMMA @zhou2012. Use a leave-one-chromosome-out (LOCO) kinship matrix to avoid proximal contamination (inflated statistics caused by including the test locus in the kinship estimate). This LMM step is essential for controlling false positives arising from the shared relatedness structure among RI strains (_see_ *Note 12*).

*4. Functional annotation.* Cross-reference significant associations with previously mapped QTLs using the Rat Genome Database (RGD; #link("https://rgd.mcw.edu")[rgd.mcw.edu]) @smith2020 and the Ensembl Genome Browser @martin2023 selecting the mRatBN7.2 reference genome @dejong2024.

*Expected results.* Applying this workflow to the HXB/BXH panel, the following associations were identified @villani2025: (a) A variant (chr12\_4347739) within a long non-coding RNA gene was associated with blood glucose concentration and located on the same chromosome as a previously mapped QTL controlling insulin/glucose ratio (Insglur6, logarithm of odds (LOD) score 18.97). (b) An intronic variant (chr12\_18797475) within a locus similar to the paired immunoglobulin-like type 2 receptor was associated with both blood insulin concentration and hippocampal chromogranin A (CGA) expression. Additionally, validated SVs were found in disease-relevant genes including _Lmtk2_ (implicated in neurodegeneration, including Alzheimer's disease) and _Mcemp1_ (a critical factor in allergic and inflammatory lung diseases).
