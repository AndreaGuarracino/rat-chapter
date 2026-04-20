# Pangenome Graph Construction, Variant Calling, and Phenome-Wide Association in the HXB/BXH Rat Panel

The chapter describes a practical protocol for building a rat pangenome graph from the HXB/BXH family of recombinant inbred strains with PGGB, validating it, calling small variants and structural variants against it, and using the resulting genotypes for phenome-wide association mapping in GeneNetwork.

## Citation

> Villani F, Isaac A, Colonna V, Garrison E, Duggan D, Trent JM, Ashbrook DG, Williams RW, Chen H, Prins P, Guarracino A. Pangenome Graph Construction, Variant Calling, and Phenome-Wide Association in the HXB/BXH Rat Panel. In: *Methods in Molecular Biology*. Springer; TBD.
>
> DOI: _to be assigned upon publication_

Until then, please cite this repository: https://github.com/AndreaGuarracino/rat-chapter

## Docker

A single Docker image with every tool needed to reproduce the protocol. Pinned versions and commits live in [`Docker/Dockerfile`](Docker/Dockerfile).

### Requirements

- Docker >= 20.10
- ~10 GB disk space for the image
- Enough RAM for your dataset (>= 64 GB recommended for whole-genome pangenome)

### Build the image

```bash
git clone https://github.com/AndreaGuarracino/rat-chapter.git
cd rat-chapter/Docker
docker build -t rat-pangenome-tools .
```

### Run interactively with your data mounted

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

### Typical directory layout inside the container

```
/workspace/
├── assemblies/      <- mount your bgzipped FASTA assemblies here
│   ├── rn7.fa.gz
│   ├── SHR.fa.gz
│   └── BXH2.fa.gz
├── reads/           <- mount paired-end FASTQ files here
│   ├── SHR_1.fq.gz
│   └── SHR_2.fq.gz
├── output/          <- results written here (persists after container exits)
└── input/           <- additional reference files (e.g., rn7.fa.gz)
```
