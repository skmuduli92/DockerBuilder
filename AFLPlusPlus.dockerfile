#
# This Dockerfile for AFLplusplus uses Ubuntu 18.04 and
# installs LLVM 14 for afl-clang-lto support.

FROM ubuntu:18.04 AS aflplusplus
LABEL "maintainer"="Sujit Muduli <smuduli@cse.iitk.ac.in>"
LABEL "about"="AFLplusplus container image"

### Comment out to enable these features
# Only available on specific ARM64 boards
ENV NO_CORESIGHT=1
# Possible but unlikely in a docker container
ENV NO_NYX=1

# Only version 14 is supported now
ENV LLVM_VERSION 14
ENV GCC_VERSION 11
### No changes beyond the point unless you know what you are doing :)

ARG DEBIAN_FRONTEND=noninteractive

ENV NO_ARCH_OPT=1
ENV IS_DOCKER=1

RUN apt-get update && apt-get full-upgrade -y && \
    apt-get install -y --no-install-recommends bash-completion \
    ca-certificates git cmake automake ninja-build make \
    bison flex dirmngr gpg lbzip2 wget gnupg2 libtinfo5 \
    software-properties-common build-essential && \
    rm -rf /var/lib/apt/lists/*

# Signing keys
ENV GPG_KEYS 09C4E7007CB2EFFB A2C794A986419D8A B4468DF4E95C63DC D23DD2C20DD88BA2 8F0871F202119294 0FC3042E345AD05D

# Retrieve keys
RUN gpg --batch --keyserver keyserver.ubuntu.com --recv-keys $GPG_KEYS

# Add llvm ppa
RUN git clone --depth=1 https://github.com/vanhauser-thc/afl-cov && \
    (cd afl-cov && make install) && rm -rf afl-cov

# Install LLVM
RUN wget -qO - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
RUN apt-add-repository ppa:ubuntu-toolchain-r/test -y
RUN echo "deb http://apt.llvm.org/bionic/ llvm-toolchain-bionic-14 main" | tee /etc/apt/sources.list.d/llvm-bionic.list

RUN apt-get update -y

RUN apt-get install -y --no-install-recommends python3 python3-dev python3-setuptools \
    gcc-${GCC_VERSION} g++-${GCC_VERSION} gcc-${GCC_VERSION}-plugin-dev gdb lcov \
    clang-${LLVM_VERSION} clang-tools-${LLVM_VERSION} libc++1-${LLVM_VERSION} \
    libc++-${LLVM_VERSION}-dev libc++abi1-${LLVM_VERSION} libc++abi-${LLVM_VERSION}-dev \
    libclang1-${LLVM_VERSION} libclang-${LLVM_VERSION}-dev \
    libclang-common-${LLVM_VERSION}-dev libclang-cpp${LLVM_VERSION} \
    libclang-cpp${LLVM_VERSION}-dev liblld-${LLVM_VERSION} \
    liblld-${LLVM_VERSION}-dev liblldb-${LLVM_VERSION} liblldb-${LLVM_VERSION}-dev \
    libllvm${LLVM_VERSION} libomp-${LLVM_VERSION}-dev libomp5-${LLVM_VERSION} \
    lld-${LLVM_VERSION} lldb-${LLVM_VERSION} llvm-${LLVM_VERSION} \
    llvm-${LLVM_VERSION}-dev llvm-${LLVM_VERSION}-runtime llvm-${LLVM_VERSION}-tools \
    $([ "$(dpkg --print-architecture)" = "amd64" ] && echo gcc-${GCC_VERSION}-multilib gcc-multilib) \
    $([ "$(dpkg --print-architecture)" = "arm64" ] && echo libcapstone-dev) && \
    rm -rf /var/lib/apt/lists/*
    # gcc-multilib is only used for -m32 support on x86
    # libcapstone-dev is used for coresight_mode on arm64

RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-${GCC_VERSION} 0 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-${GCC_VERSION} 0 && \
    update-alternatives --install /usr/bin/clang clang /usr/bin/clang-${LLVM_VERSION} 0 && \
    update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-${LLVM_VERSION} 0


RUN wget -qO- https://sh.rustup.rs | CARGO_HOME=/etc/cargo sh -s -- -y -q --no-modify-path
ENV PATH=$PATH:/etc/cargo/bin

ENV LLVM_CONFIG=llvm-config-${LLVM_VERSION}
ENV AFL_SKIP_CPUFREQ=1
ENV AFL_TRY_AFFINITY=1
ENV AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1

RUN git clone --depth=1 https://github.com/vanhauser-thc/afl-cov && \
    (cd afl-cov && make install) && rm -rf afl-cov

WORKDIR /AFLplusplus
RUN git clone https://github.com/AFLplusplus/AFLplusplus.git .
RUN make distrib
