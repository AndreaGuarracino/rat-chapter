FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-c"]

# ---------------------------------------------------------
# System dependencies
# ---------------------------------------------------------
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository universe && \
    apt-get update && \
    apt-get install -y \
        wget curl git unzip \
        build-essential autoconf automake libtool nasm \
        ca-certificates \
        pkg-config cmake ninja-build \
        perl \
        python3 python3-pip python3-dev pybind11-dev \
        openjdk-17-jre \
        libbz2-dev liblzma-dev libncurses5-dev \
        libcurl4-openssl-dev libssl-dev libdeflate-dev \
        zlib1g-dev libatomic1 \
        libjemalloc-dev libgsl-dev libtbb-dev libzstd-dev \
        mummer \
        tabix samtools bcftools bedtools minimap2 hmmer \
        r-base \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------
# HTSlib 1.19 (build from source for consistent headers)
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
# Rust (needed for gfaffix + vcfbub)
# ---------------------------------------------------------
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:$PATH"

# ---------------------------------------------------------
# seqtk
# ---------------------------------------------------------
RUN git clone --depth 1 https://github.com/lh3/seqtk /tmp/seqtk && \
    cd /tmp/seqtk && make && \
    cp seqtk /usr/local/bin && \
    rm -rf /tmp/seqtk

# ---------------------------------------------------------
# miniprot (needed by compleasm)
# ---------------------------------------------------------
RUN git clone --depth 1 https://github.com/lh3/miniprot /tmp/miniprot && \
    cd /tmp/miniprot && make && \
    cp miniprot /usr/local/bin && \
    rm -rf /tmp/miniprot

# ---------------------------------------------------------
# VG 1.59.0 — static binary
# ---------------------------------------------------------
RUN wget -q https://github.com/vgteam/vg/releases/download/v1.59.0/vg \
        -O /usr/local/bin/vg && \
    chmod +x /usr/local/bin/vg

# ---------------------------------------------------------
# wfmash 0.14.0
# WFA_PNG_AND_TSV=OFF: avoids libpng dependency
# IPS4OML_USE_MCSTl=0: disables oneTBB parallel sort (API mismatch on Ubuntu 22.04)
# -latomic: needed for lock-free data structures
# ---------------------------------------------------------
RUN git clone --recursive --branch v0.14.0 \
        https://github.com/waveygang/wfmash /tmp/wfmash && \
    cmake -S /tmp/wfmash -B /tmp/wfmash/build \
        -DCMAKE_BUILD_TYPE=Release \
        -DWFA_PNG_AND_TSV=OFF \
        -DBUILD_TESTING=OFF \
        -DCMAKE_CXX_FLAGS="-DIPS4OML_USE_MCSTl=0" \
        -DCMAKE_EXE_LINKER_FLAGS="-latomic" && \
    cmake --build /tmp/wfmash/build --parallel $(nproc) && \
    find /tmp/wfmash/build -name wfmash -type f -executable -exec cp {} /usr/local/bin/ \; && \
    rm -rf /tmp/wfmash

# ---------------------------------------------------------
# seqwish 0.7.11
# ---------------------------------------------------------
RUN git clone --recursive --branch v0.7.11 \
        https://github.com/ekg/seqwish /tmp/seqwish && \
    cmake -S /tmp/seqwish -B /tmp/seqwish/build \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_TESTING=OFF \
        -DCMAKE_CXX_FLAGS="-DIPS4OML_USE_MCSTl=0" \
        -DCMAKE_EXE_LINKER_FLAGS="-latomic" && \
    cmake --build /tmp/seqwish/build --parallel $(nproc) && \
    find /tmp/seqwish/build -name seqwish -type f -executable -exec cp {} /usr/local/bin/ \; && \
    rm -rf /tmp/seqwish

# ---------------------------------------------------------
# smoothxg 0.8.0
# ---------------------------------------------------------
RUN git clone --recursive --branch v0.8.0 \
        https://github.com/pangenome/smoothxg /tmp/smoothxg && \
    cmake -S /tmp/smoothxg -B /tmp/smoothxg/build \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_TESTING=OFF \
        -DCMAKE_CXX_FLAGS="-DIPS4OML_USE_MCSTl=0" \
        -DCMAKE_EXE_LINKER_FLAGS="-latomic" && \
    cmake --build /tmp/smoothxg/build --parallel $(nproc) && \
    find /tmp/smoothxg/build -name smoothxg -type f -executable -exec cp {} /usr/local/bin/ \; && \
    rm -rf /tmp/smoothxg

# ---------------------------------------------------------
# gfaffix 0.1.5b (Rust)
# ---------------------------------------------------------
RUN git clone --depth 1 --branch 0.1.5b \
        https://github.com/marschall-lab/GFAffix /tmp/gfaffix && \
    cd /tmp/gfaffix && cargo build --release && \
    cp target/release/gfaffix /usr/local/bin && \
    rm -rf /tmp/gfaffix

# ---------------------------------------------------------
# odgi 0.9.0
# ---------------------------------------------------------
RUN git clone --recursive --branch v0.9.0 \
        https://github.com/pangenome/odgi /tmp/odgi && \
    cmake -S /tmp/odgi -B /tmp/odgi/build \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_TESTING=OFF \
        -DCMAKE_CXX_FLAGS="-DIPS4OML_USE_MCSTl=0" \
        -DCMAKE_EXE_LINKER_FLAGS="-latomic" && \
    cmake --build /tmp/odgi/build --parallel $(nproc) && \
    find /tmp/odgi/build -name odgi -type f -executable -exec cp {} /usr/local/bin/ \; && \
    rm -rf /tmp/odgi

# ---------------------------------------------------------
# PGGB 0.7.0 — shell script wrapper
# ---------------------------------------------------------
RUN wget -q https://raw.githubusercontent.com/pangenome/pggb/v0.7.0/pggb \
        -O /usr/local/bin/pggb && \
    chmod +x /usr/local/bin/pggb

# ---------------------------------------------------------
# SURVIVOR
# ---------------------------------------------------------
RUN git clone --depth 1 https://github.com/fritzsedlazeck/SURVIVOR /tmp/survivor && \
    cd /tmp/survivor/Debug && make && \
    cp SURVIVOR /usr/local/bin && \
    rm -rf /tmp/survivor

# ---------------------------------------------------------
# vcflib 1.0.9
# pybind11-dev: required for Python bindings cmake module
# PKG_CONFIG_PATH: exposes htslib 1.19 built from source
# ---------------------------------------------------------
RUN git clone --recursive --depth 1 --branch v1.0.9 \
        https://github.com/vcflib/vcflib /tmp/vcflib && \
    export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig && \
    cmake -S /tmp/vcflib -B /tmp/vcflib/build \
        -DCMAKE_BUILD_TYPE=Release \
        -DZIG=OFF \
        -DBUILD_TESTING=OFF && \
    cmake --build /tmp/vcflib/build --parallel $(nproc) && \
    find /tmp/vcflib/build -maxdepth 2 -type f -executable \
        -exec cp {} /usr/local/bin/ \; && \
    rm -rf /tmp/vcflib

# ---------------------------------------------------------
# vcfbub (Rust)
# ---------------------------------------------------------
RUN git clone --depth 1 https://github.com/pangenome/vcfbub /tmp/vcfbub && \
    cd /tmp/vcfbub && cargo build --release && \
    cp target/release/vcfbub /usr/local/bin && \
    rm -rf /tmp/vcfbub

# ---------------------------------------------------------
# meryl
# ---------------------------------------------------------
RUN git clone --depth 1 https://github.com/marbl/meryl /tmp/meryl && \
    cd /tmp/meryl/src && make -j$(nproc) && \
    cp /tmp/meryl/build/bin/meryl /usr/local/bin && \
    rm -rf /tmp/meryl

# ---------------------------------------------------------
# RTG Tools 3.12.1
# ---------------------------------------------------------
RUN wget -q https://github.com/RealTimeGenomics/rtg-tools/releases/download/3.12.1/rtg-tools-3.12.1-linux-x64.zip \
        -O /tmp/rtg.zip && \
    unzip /tmp/rtg.zip -d /opt && \
    ln -s /opt/rtg-tools-3.12.1/rtg /usr/local/bin/rtg && \
    rm /tmp/rtg.zip

# ---------------------------------------------------------
# SnpEff + SnpSift 5.1
# ---------------------------------------------------------
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends snpeff && \
    mkdir -p /opt/snpEff && \
    find /usr/share/java -name "snpEff*.jar" \
        -exec cp {} /opt/snpEff/snpEff.jar \; && \
    find /usr/share/java -name "SnpSift*.jar" \
        -exec cp {} /opt/snpEff/SnpSift.jar \; && \
    printf '#!/bin/sh\nexec java -jar /opt/snpEff/snpEff.jar "$@"\n' \
        > /usr/local/bin/snpeff && \
    printf '#!/bin/sh\nexec java -jar /opt/snpEff/SnpSift.jar "$@"\n' \
        > /usr/local/bin/snpsift && \
    chmod +x /usr/local/bin/snpeff /usr/local/bin/snpsift && \
    rm -rf /var/lib/apt/lists/*
 
# ---------------------------------------------------------
# RepeatMasker 4.1.5
# ---------------------------------------------------------
RUN pip3 install h5py && \
    wget -q https://www.repeatmasker.org/RepeatMasker/RepeatMasker-4.1.5.tar.gz \
        -O /tmp/rm.tar.gz && \
    tar -xzf /tmp/rm.tar.gz -C /opt && \
    ln -s /opt/RepeatMasker/RepeatMasker /usr/local/bin/RepeatMasker && \
    rm /tmp/rm.tar.gz
 
# ---------------------------------------------------------
# GEMMA 0.98.5 — static binary
# ---------------------------------------------------------
RUN wget -q https://github.com/genetics-statistics/GEMMA/releases/download/v0.98.5/gemma-0.98.5-linux-static-AMD64.gz \
        -O /tmp/gemma.gz && \
    gunzip /tmp/gemma.gz && \
    mv /tmp/gemma /usr/local/bin/gemma && \
    chmod +x /usr/local/bin/gemma
 
# ---------------------------------------------------------
# Python tools, for now I am skipping the SVs and pheWAS analyses.
# ---------------------------------------------------------
#RUN pip3 install svim-asm compleasm
 
WORKDIR /workspace