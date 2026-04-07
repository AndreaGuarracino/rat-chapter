# syntax=docker/dockerfile:1

# ==========================================================
# Stage 0: extract PAV from official image
# ==========================================================
FROM becklab/pav:2.4.6 AS pav_image

# ==========================================================
# Stage 1: builder — compile every C++/Rust tool
# ==========================================================
FROM ubuntu:22.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-c"]

# ---------------------------------------------------------
# Build dependencies
# ---------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends software-properties-common && \
    add-apt-repository universe && \
    apt-get install -y --no-install-recommends \
        build-essential autoconf automake libtool nasm \
        cmake ninja-build pkg-config \
        git wget curl ca-certificates unzip \
        perl python3 python3-pip python3-dev pybind11-dev \
        libbz2-dev liblzma-dev libncurses-dev \
        libcurl4-openssl-dev libssl-dev libdeflate-dev \
        zlib1g-dev libatomic1 libjemalloc-dev libgsl-dev libtbb-dev libzstd-dev \
        libcairo2-dev \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------
# HTSlib 1.19 (prerequisite for samtools + bcftools)
# ---------------------------------------------------------
RUN wget -q https://github.com/samtools/htslib/releases/download/1.19/htslib-1.19.tar.bz2 \
        -O /tmp/htslib.tar.bz2 && \
    tar -xjf /tmp/htslib.tar.bz2 -C /tmp && \
    cd /tmp/htslib-1.19 && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && make install && \
    ldconfig && \
    rm -rf /tmp/htslib*

# ---------------------------------------------------------
# samtools 1.19 (matched to HTSlib 1.19)
# ---------------------------------------------------------
RUN wget -q https://github.com/samtools/samtools/releases/download/1.19/samtools-1.19.tar.bz2 \
        -O /tmp/samtools.tar.bz2 && \
    tar -xjf /tmp/samtools.tar.bz2 -C /tmp && \
    cd /tmp/samtools-1.19 && \
    ./configure --prefix=/usr/local --with-htslib=/usr/local && \
    make -j$(nproc) && make install && \
    rm -rf /tmp/samtools*

# ---------------------------------------------------------
# BCFtools 1.19 (matched to HTSlib 1.19)
# ---------------------------------------------------------
RUN wget -q https://github.com/samtools/bcftools/releases/download/1.19/bcftools-1.19.tar.bz2 \
        -O /tmp/bcftools.tar.bz2 && \
    tar -xjf /tmp/bcftools.tar.bz2 -C /tmp && \
    cd /tmp/bcftools-1.19 && \
    ./configure --prefix=/usr/local --with-htslib=/usr/local && \
    make -j$(nproc) && make install && \
    rm -rf /tmp/bcftools*

# ---------------------------------------------------------
# seqtk
# ---------------------------------------------------------
RUN git clone --depth 1 https://github.com/lh3/seqtk /tmp/seqtk && \
    cd /tmp/seqtk && make && \
    cp seqtk /usr/local/bin/ && \
    rm -rf /tmp/seqtk

# ---------------------------------------------------------
# miniprot (needed by compleasm)
# ---------------------------------------------------------
RUN git clone --depth 1 https://github.com/lh3/miniprot /tmp/miniprot && \
    cd /tmp/miniprot && make && \
    cp miniprot /usr/local/bin/ && \
    rm -rf /tmp/miniprot

# ---------------------------------------------------------
# SURVIVOR
# ---------------------------------------------------------
RUN git clone https://github.com/fritzsedlazeck/SURVIVOR /tmp/survivor && \
    cd /tmp/survivor && \
    git checkout ed1ca5188a2d9286d582417b7a65938c768df995 && \
    cd Debug && make && \
    cp SURVIVOR /usr/local/bin/ && \
    rm -rf /tmp/survivor

# ---------------------------------------------------------
# meryl
# ---------------------------------------------------------
RUN git clone --depth 1 https://github.com/marbl/meryl /tmp/meryl && \
    cd /tmp/meryl/src && make -j$(nproc) && \
    cp /tmp/meryl/build/bin/meryl /usr/local/bin/ && \
    rm -rf /tmp/meryl

# ---------------------------------------------------------
# wfmash v0.14.1
# ---------------------------------------------------------
RUN git clone --recursive https://github.com/waveygang/wfmash /tmp/wfmash && \
    cd /tmp/wfmash && \
    git checkout v0.14.1 && \
    git submodule update --init --recursive && \
    find . \( -name CMakeLists.txt -o -name Makefile \) \
        -exec sed -i 's/-march=native/-march=x86-64-v2/g' {} + && \
    cmake -H. -DCMAKE_BUILD_TYPE=Generic -DEXTRA_FLAGS='-march=x86-64-v2 -Ofast' -Bbuild && \
    cmake --build build -- -j$(nproc) && \
    cp build/bin/wfmash /usr/local/bin/wfmash && \
    cp build/lib/* /usr/local/lib/ && \
    cp scripts/paf2dotplot /usr/local/bin/paf2dotplot && \
    chmod +x /usr/local/bin/paf2dotplot && \
    sed -i 's/kill 1, \$child;/kill 1, \$child if \$child > 1;/' /usr/local/bin/paf2dotplot && \
    rm -rf /tmp/wfmash

# ---------------------------------------------------------
# seqwish
# ---------------------------------------------------------
RUN git clone --recursive https://github.com/ekg/seqwish /tmp/seqwish && \
    cd /tmp/seqwish && \
    git checkout 90dc76e1204fcfc6d9642373cb05dca8aa197164 && \
    git submodule update --init --recursive && \
    find . \( -name CMakeLists.txt -o -name Makefile \) \
        -exec sed -i 's/-march=native/-march=x86-64-v2/g' {} + && \
    cmake -H. -DCMAKE_BUILD_TYPE=Generic -DEXTRA_FLAGS='-march=x86-64-v2 -Ofast' -Bbuild && \
    cmake --build build -- -j$(nproc) && \
    cp bin/seqwish /usr/local/bin/seqwish && \
    rm -rf /tmp/seqwish

# ---------------------------------------------------------
# smoothxg
# ---------------------------------------------------------
RUN git clone --recursive https://github.com/pangenome/smoothxg /tmp/smoothxg && \
    cd /tmp/smoothxg && \
    git checkout 0ea0470a6034b29776689b05b75916c609d06d1e && \
    git submodule update --init --recursive && \
    find . \( -name CMakeLists.txt -o -name Makefile \) \
        -exec sed -i 's/-march=native/-march=x86-64-v2/g' {} + && \
    sed -i 's/-msse4.1/-march=x86-64-v2/g' deps/spoa/CMakeLists.txt && \
    cmake -H. -DCMAKE_BUILD_TYPE=Generic -DEXTRA_FLAGS='-march=x86-64-v2 -Ofast' -Bbuild && \
    cmake --build build -- -j$(nproc) && \
    cp bin/smoothxg /usr/local/bin/smoothxg && \
    rm -rf /tmp/smoothxg

# ---------------------------------------------------------
# odgi v0.8.6
# ---------------------------------------------------------
RUN git clone --recursive https://github.com/pangenome/odgi /tmp/odgi && \
    cd /tmp/odgi && \
    git checkout v0.8.6 && \
    git submodule update --init --recursive && \
    find . \( -name CMakeLists.txt -o -name Makefile \) \
        -exec sed -i 's/-march=native/-march=x86-64-v2/g' {} + && \
    cmake -H. -DCMAKE_BUILD_TYPE=Generic -DEXTRA_FLAGS='-march=x86-64-v2 -Ofast' -Bbuild && \
    cmake --build build -- -j$(nproc) && \
    cp bin/odgi /usr/local/bin/odgi && \
    rm -rf /tmp/odgi

# ---------------------------------------------------------
# vcflib
# ---------------------------------------------------------
RUN git clone --recursive https://github.com/vcflib/vcflib.git /tmp/vcflib && \
    cd /tmp/vcflib && \
    git checkout b118a9bfd99b07da9d40d0bd8b3c2bdc4523b568 && \
    mkdir -p build && cd build && \
    cmake -DZIG=OFF -DCMAKE_BUILD_TYPE=Debug -DWFA_GITMODULE=ON .. && \
    cmake --build . -- -j$(nproc) && \
    cp vcfwave vcfuniq /usr/local/bin/ && \
    find . \( -name "libvcflib.so*" -o -name "libwfa2*.so*" \) \
        -exec cp -P {} /usr/local/lib/ \; && \
    ldconfig && \
    rm -rf /tmp/vcflib

# ---------------------------------------------------------
# minimap2
# ---------------------------------------------------------
RUN git clone https://github.com/lh3/minimap2 /usr/local/minimap2 && \
    cd /usr/local/minimap2 && make && \
    cp minimap2 /usr/local/bin/minimap2 && \
    ln -sf /usr/local/minimap2/misc/paftools.js /usr/local/bin/paftools.js

# ---------------------------------------------------------
# Hall-lab assembly_validation
# ---------------------------------------------------------
RUN git clone --recursive https://github.com/hall-lab/assembly_validation \
        /usr/local/assembly_validation

# ---------------------------------------------------------
# pggb v0.7.0 — main script + helper scripts
# ---------------------------------------------------------
RUN git clone --depth 1 --branch v0.7.0 \
        https://github.com/pangenome/pggb /tmp/pggb && \
    cp /tmp/pggb/pggb /usr/local/bin/pggb && \
    chmod 777 /usr/local/bin/pggb && \
    cp /tmp/pggb/partition-before-pggb /usr/local/bin/partition-before-pggb && \
    chmod a+rx /usr/local/bin/partition-before-pggb && \
    cp /tmp/pggb/scripts/* /usr/local/bin/ && \
    cp -r /tmp/pggb/scripts /usr/local/bin/scripts && \
    rm -rf /tmp/pggb

# ---------------------------------------------------------
# Rust toolchain
# ---------------------------------------------------------
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:$PATH"

# ---------------------------------------------------------
# GFAffix
# ---------------------------------------------------------
RUN git clone https://github.com/marschall-lab/GFAffix.git /tmp/GFAffix && \
    cd /tmp/GFAffix && \
    git checkout 460e0dd798a9da7d12aef4f9181419d71489da95 && \
    cargo build --release && \
    cp target/release/gfaffix /usr/local/bin/ && \
    rm -rf /tmp/GFAffix

# ---------------------------------------------------------
# vcfbub 
# ---------------------------------------------------------
RUN git clone https://github.com/pangenome/vcfbub /tmp/vcfbub && \
    cd /tmp/vcfbub && \
    git checkout 77289654b246a4e3422902d04277e258d9fabe9a && \
    cargo build --release && \
    cp target/release/vcfbub /usr/local/bin/ && \
    rm -rf /tmp/vcfbub

# ---------------------------------------------------------
# fastix 
# ---------------------------------------------------------
RUN git clone https://github.com/ekg/fastix.git /tmp/fastix && \
    cd /tmp/fastix && \
    git checkout 331c1159ea16625ee79d1a82522e800c99206834 && \
    cargo build --release && \
    cp target/release/fastix /usr/local/bin/ && \
    rm -rf /tmp/fastix

# ---------------------------------------------------------
# gfalook 
# ---------------------------------------------------------
RUN git clone https://github.com/pangenome/gfalook.git /tmp/gfalook && \
    cd /tmp/gfalook && \
    git checkout 5199d77ecc4980b181177c16b94f6e56c0d06e4c && \
    cargo build --release && \
    cp target/release/gfalook /usr/local/bin/ && \
    rm -rf /tmp/gfalook

# ---------------------------------------------------------
# pafplot
# ---------------------------------------------------------
RUN git clone https://github.com/ekg/pafplot.git /tmp/pafplot && \
    cd /tmp/pafplot && \
    git checkout 2785b0ef30d37300afc77fd4b04d1d949c143551 && \
    cargo build --release && \
    cp target/release/pafplot /usr/local/bin/ && \
    rm -rf /tmp/pafplot

# ---------------------------------------------------------
# k8 v1.2
# ---------------------------------------------------------
RUN wget -q https://github.com/attractivechaos/k8/releases/download/v1.2/k8-1.2.tar.bz2 \
        -O /tmp/k8.tar.bz2 && \
    tar -xjf /tmp/k8.tar.bz2 -C /tmp && \
    cp /tmp/k8-1.2/k8-x86_64-Linux /usr/local/bin/k8 && \
    chmod +x /usr/local/bin/k8 && \
    rm -rf /tmp/k8*

# ---------------------------------------------------------
# Python packages
# numpy + pandas required by PAV
# ---------------------------------------------------------
RUN pip3 install --no-cache-dir \
        "numpy==1.24.4" \
        "pandas==1.5.3" \
        biopython \
        drmaa \
        intervaltree \
        joblib \
        matplotlib \
        matplotlib-venn \
        pulp \
        pysam \
        scipy \
        "pulp==2.7.0" \
        snakemake \
        "truvari==4.0.0"

# ---------------------------------------------------------
# SVIM-asm
# ---------------------------------------------------------
RUN git clone https://github.com/eldariont/svim-asm /tmp/svim-asm && \
    cd /tmp/svim-asm && \
    git checkout 6f59b61691af64a958d3a894a69964c93d27943a && \
    pip3 install . && \
    rm -rf /tmp/svim-asm

# ==========================================================
# Stage 2: runtime image
# ==========================================================
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-c"]

# ---------------------------------------------------------
# Runtime system dependencies
# ---------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends software-properties-common && \
    add-apt-repository universe && \
    apt-get install -y --no-install-recommends \
        ca-certificates wget curl git unzip \
        perl bc time pigz parallel \
        python3 python3-pip \
        openjdk-17-jre \
        bzip2 libbz2-1.0 liblzma5 libncurses6 \
        libcurl4 libssl3 libdeflate0 \
        zlib1g libatomic1 libgomp1 \
        libjemalloc-dev libgsl-dev libtbb-dev libzstd1 libcairo2 \
        mummer hmmer \
        r-base \
        bedtools \
        gnuplot \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------
# Copy compiled binaries
# ---------------------------------------------------------
COPY --from=builder /usr/local/bin/ /usr/local/bin/
COPY --from=builder /usr/local/lib/ /usr/local/lib/
COPY --from=builder /usr/local/minimap2/ /usr/local/minimap2/
COPY --from=builder /usr/local/assembly_validation/ /usr/local/assembly_validation/
RUN ldconfig && \
    echo "deb http://security.ubuntu.com/ubuntu focal-security main" \
        > /etc/apt/sources.list.d/focal-security.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends libssl1.1 && \
    rm /etc/apt/sources.list.d/focal-security.list && \
    rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------
# PAV (from official image)
# ---------------------------------------------------------
COPY --from=pav_image /opt/pav /opt/pav
RUN ln -s /opt/pav/runlocal /usr/local/bin/pav-runlocal

# ---------------------------------------------------------
# SnpEff 5.0 + SnpSift 
# ---------------------------------------------------------
RUN mkdir -p /opt/snpEff && \
    wget -q https://snpeff-public.s3.amazonaws.com/versions/snpEff_v5_0_core.zip \
        -O /tmp/snpeff_core.zip && \
    unzip -p /tmp/snpeff_core.zip snpEff/snpEff.jar > /opt/snpEff/snpEff.jar && \
    unzip -p /tmp/snpeff_core.zip snpEff/SnpSift.jar > /opt/snpEff/SnpSift.jar && \
    unzip -p /tmp/snpeff_core.zip snpEff/snpEff.config > /opt/snpEff/snpEff.config && \
    rm /tmp/snpeff_core.zip && \
    printf '#!/bin/sh\nexec java -Xmx8g -jar /opt/snpEff/snpEff.jar -config /opt/snpEff/snpEff.config "$@"\n' \
        > /usr/local/bin/snpeff && \
    printf '#!/bin/sh\nexec java -Xmx8g -jar /opt/snpEff/SnpSift.jar "$@"\n' \
        > /usr/local/bin/snpsift && \
    chmod +x /usr/local/bin/snpeff /usr/local/bin/snpsift

# ---------------------------------------------------------
# VG v1.71.0 
# ---------------------------------------------------------
RUN wget -q https://github.com/vgteam/vg/releases/download/v1.71.0/vg \
        -O /usr/local/bin/vg && \
    chmod +x /usr/local/bin/vg

# ---------------------------------------------------------
# GEMMA 0.98.5 
# ---------------------------------------------------------
RUN wget -q https://github.com/genetics-statistics/GEMMA/releases/download/v0.98.5/gemma-0.98.5-linux-static-AMD64.gz \
        -O /tmp/gemma.gz && \
    gunzip /tmp/gemma.gz && \
    mv /tmp/gemma /usr/local/bin/gemma && \
    chmod +x /usr/local/bin/gemma

# ---------------------------------------------------------
# ncbi-datasets-cli
# ---------------------------------------------------------
RUN wget -q https://ftp.ncbi.nlm.nih.gov/pub/datasets/command-line/LATEST/linux-amd64/datasets \
        -O /usr/local/bin/datasets && \
    chmod +x /usr/local/bin/datasets

# ---------------------------------------------------------
# RTG Tools 3.12.1
# ---------------------------------------------------------
RUN wget -q https://github.com/RealTimeGenomics/rtg-tools/releases/download/3.12.1/rtg-tools-3.12.1-linux-x64.zip \
        -O /tmp/rtg.zip && \
    unzip /tmp/rtg.zip -d /opt && \
    ln -s /opt/rtg-tools-3.12.1/rtg /usr/local/bin/rtg && \
    rm /tmp/rtg.zip

# ---------------------------------------------------------
# compleasm 0.2.7 
# ---------------------------------------------------------
RUN wget -q -O /tmp/compleasm.tar.bz2 \
        https://github.com/huangnengCSU/compleasm/releases/download/v0.2.7/compleasm-0.2.7_x64-linux.tar.bz2 && \
    tar -xjf /tmp/compleasm.tar.bz2 -C /usr/local/ && \
    ln -s /usr/local/compleasm_kit/compleasm.py /usr/local/bin/compleasm && \
    rm /tmp/compleasm.tar.bz2

# ---------------------------------------------------------
# Workspace directory layout
# ---------------------------------------------------------
RUN mkdir -p \
        /workspace/reads \
        /workspace/assemblies \
        /workspace/busco/databases \
        /workspace/busco/results \
        /workspace/alignments \
        /workspace/parts \
        /workspace/output \
        /workspace/SVIM-asm \
        /workspace/PAV \
        /workspace/Hall-lab \
        /workspace/PGGB \
        /workspace/merged

# ---------------------------------------------------------
# Environment variables
# ---------------------------------------------------------
ENV PAV=/opt/pav
ENV PATH="/opt/pav/bin:$PATH"
ENV PAFTOOLS=/usr/local/minimap2/misc/paftools.js
ENV K8=/usr/local/bin/k8
ENV ASSEMBLY_VALIDATION=/usr/local/assembly_validation
ENV PAFTOOLS_SCRIPTS=/usr/local/assembly_validation/docker/analyze_assemblies/scripts
ENV SURVIVOR=/usr/local/bin/SURVIVOR

WORKDIR /workspace