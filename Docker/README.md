# Rat Pangenome Docker container

A single Docker image containing all tools required to reproduce the HXB/BXH rat
pangenome protocol described in the methods chapter. 

## Included tools

### §3.1 Assembly quality assessment

| Tool | Version | Purpose |
|------|---------|---------|
| compleasm | 0.2.7 | Assembly completeness (BUSCO Mammalia) |
| meryl | 1.4 | K-mer counting and histogram |
| samtools | 1.19 | Contig filtering, indexing, BAM/CRAM processing |
| htslib (bgzip / tabix) | 1.19 | Compression and indexing |
| seqtk | 1.5-r133 | Telomere repeat detection |
| NCBI datasets | 18.23.0 | Reference genome download |

### §3.2 PGGB pangenome construction

| Tool | Version | Purpose |
|------|---------|---------|
| fastix | 0.1.0 | PanSN-spec sequence renaming |
| pggb | v0.7.0 | Pangenome graph construction (orchestrator) |
| wfmash | v0.14.1 | All-to-all sequence alignment (pggb stage 1) |
| seqwish | commit 90dc76e1 | Graph induction from alignments (pggb stage 2) |
| smoothxg | commit 0ea0470a | Graph normalization via POA (pggb stage 3) |
| gfaffix | commit 460e0dd | Redundancy removal (pggb stage 4) |
| bcftools | 1.19 | VCF/BCF processing (concat per-chromosome VCFs) |

### §3.3 Graph quality assessment

| Tool | Version | Purpose |
|------|---------|---------|
| odgi | v0.8.6 | Graph statistics, 1D/2D visualization, extraction |

### §3.4 Variant calling and read mapping to the pangenome

| Tool | Version | Purpose |
|------|---------|---------|
| vg | v1.71.0 | Graph indexing (autoindex), read mapping (Giraffe), variant calling (deconstruct), surjection |

### §3.5 Variant annotation

| Tool | Version | Purpose |
|------|---------|---------|
| SnpEff | 5.0 | Functional variant annotation |
| SnpSift | 5.0 | VCF filtering and manipulation |

### §3.6 Validation strategies

| Tool | Version | Purpose |
|------|---------|---------|
| RTG Tools | 3.12.1 | VCF evaluation (vcfeval) |
| MUMmer4 (nucmer) | 3.1 | Pairwise genome alignment and SNP calling |
| bedtools | v2.30.0 | Genome arithmetic (complement for callable regions) |

### §3.7 Structural variant analysis

| Tool | Version | Purpose |
|------|---------|---------|
| minimap2 | 2.26 | Assembly-to-reference alignment |
| svim-asm | 1.0.3 | Assembly-based SV calling (haploid mode) |
| PAV | 2.4.6 | Haplotype-resolved SV calling |
| snakemake | 7.32.4 | Workflow management (PAV pipeline) |
| paftools.js (k8) | 2.30 / 1.2 | Hall-lab assembly-based SV calling |
| pafplot | 0.1.0 | PAF alignment visualization |
| vcfbub | 0.1.0 | Nested allele removal from pangenome VCF |
| vcfwave | (vcflib) | Complex variant decomposition |
| SURVIVOR | 1.0.7 | Multi-caller SV merging |

### §3.8 PheWAS

| Tool | Version | Purpose |
|------|---------|---------|
| GEMMA | 0.98.5 | Linear mixed model association (LOCO kinship) |

## Requirements

- Docker ≥ 20.10
- ~10 GB disk space for the image
- Sufficient RAM for your dataset (≥ 64 GB recommended for whole-genome pangenome)

## Quick start

### 1. Pull or build the image

Build from this directory:

```bash
cd /path/to/rat-chapter/Docker
docker build -t rat-pangenome-tools .
```

### 2. Run interactively with your data mounted

Replace each `/path/to/your/...` with the actual path on your machine. Only mount the directories you need; all four mounts are optional.

```bash
docker run -it --rm \
    -v /path/to/your/assemblies:/workspace/assemblies \
    -v /path/to/your/reads:/workspace/reads \
    -v /path/to/your/output:/workspace/output \
    -v /path/to/your/input:/workspace/input \
    rat-pangenome-tools \
    bash
```

You will land in `/workspace` with all tools on `$PATH`.

### 3. Typical directory layout inside the container

```
/workspace/
├── assemblies/      ← mount your bgzipped FASTA assemblies here
│   ├── rn7.fa.gz
│   ├── SHR.fa.gz
│   └── BXH2.fa.gz
├── reads/           ← mount paired-end FASTQ files here
│   ├── SHR_1.fq.gz
│   └── SHR_2.fq.gz
├── output/          ← results written here (persists after container exits)
└── input/           ← additional reference files (e.g., rn7.fa.gz)
```