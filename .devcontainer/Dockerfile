# See the License.md file at the root of the repository for licensing information.
#
# I use Debian SID because it has support for MinGW32 UCRT target compilers and is 
# generally more up-to-date than stable releases. The "slim" variant is used to 
# reduce the image size, and I only install the necessary packages for building 
# and testing ncurses, as well as the LLVM MinGW toolchain and PCRE2 dependencies.
FROM debian:sid-slim

ENV DEBIAN_FRONTEND=noninteractive

# --------------------------------------------------
# APT performance + SID stability
# --------------------------------------------------
RUN echo 'Acquire::Retries "5";' > /etc/apt/apt.conf.d/80-retries \
 && echo 'APT::Install-Recommends "0";' > /etc/apt/apt.conf.d/99norecommends \
 && echo 'APT::Install-Suggests "0";' >> /etc/apt/apt.conf.d/99norecommends

# Set timezone to avoid tzdata prompts during package installation
# Please adjust this to your local timezone if needed, or set it to 
# UTC for a more generic configuration
ENV TZ=Europe/Berlin

# --------------------------------------------------
# Base build and convenience tools
# --------------------------------------------------
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    apt-get update && apt-get dist-upgrade -y && \
    apt-get install -y \
        ca-certificates \
        locales \
        curl \
        openssh-client \
        git \
        bash \
        less \
        sudo \
        file \
        pkg-config \
        ninja-build \
        cmake \
        make \
        autoconf \
        automake \
        libtool \
        autoconf-dickey \
        gettext \
        xz-utils \
        python3 \
        gdb \
        lldb \
        clang \
        llvm \
        lld \
        build-essential \
        wine \
        gcc-mingw-w64-ucrt64 \
        g++-mingw-w64-ucrt64 \
        binutils-mingw-w64-ucrt64 \
        gcc-mingw-w64 \
        g++-mingw-w64 \
        binutils-mingw-w64 \
    && rm -rf /var/lib/apt/lists/* \
    && sed -i 's/# de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen de_DE.UTF-8

# Set German locale as default (adjust if needed)
ENV LANG=de_DE.UTF-8
ENV LANGUAGE=de_DE:de
ENV LC_ALL=de_DE.UTF-8

# --------------------------------------------------
# llvm-mingw (Used for ARM64 builds only)
# --------------------------------------------------
WORKDIR /opt
ENV LLVM_MINGW_VERSION=20260224
RUN curl -L https://github.com/mstorsjo/llvm-mingw/releases/download/${LLVM_MINGW_VERSION}/llvm-mingw-${LLVM_MINGW_VERSION}-ucrt-ubuntu-22.04-$(uname -m).tar.xz \
    -o llvm-mingw.tar.xz && \
    tar xf llvm-mingw.tar.xz && \
    mv llvm-mingw-* llvm-mingw && \
    rm llvm-mingw.tar.xz

# ----------------------------------------------------------------------------
# PCRE2 builds
# I use a static minimal build of PCRE2 for use in libform's fty_regex.c 
# Using a static version avoids runtime DLL dependencies when building DLLs.
# ----------------------------------------------------------------------------

# 1) MSVCRT minimal (ASCII, POSIX, 64-Bit Intel)
RUN git clone --depth 1 https://github.com/PCRE2Project/pcre2.git /tmp/pcre2-git && \
    mkdir -p /tmp/pcre2-msvcrt-build-x86_64 && \
    cmake -S /tmp/pcre2-git -B /tmp/pcre2-msvcrt-build-x86_64 -G Ninja \
        -DBUILD_SHARED_LIBS=OFF \
        -DPCRE2_BUILD_PCRE2_8=ON \
        -DPCRE2_BUILD_PCRE2_16=OFF \
        -DPCRE2_BUILD_PCRE2_32=OFF \
        -DPCRE2_BUILD_PCRE2_POSIX=ON \
        -DPCRE2_BUILD_TESTS=OFF \
        -DPCRE2_BUILD_PCRE2GREP=OFF \
        -DPCRE2_BUILD_PCRE2TEST=OFF \
        -DPCRE2_SUPPORT_JIT=OFF \
        -DPCRE2_SUPPORT_UTF=OFF \
        -DPCRE2_SUPPORT_UNICODE=OFF \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/opt/pcre2-msvcrt/x86_64 \
        -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc && \
    cmake --build /tmp/pcre2-msvcrt-build-x86_64 && \
    cmake --install /tmp/pcre2-msvcrt-build-x86_64 && \
    rm -rf /tmp/pcre2-msvcrt-build-x86_64 /opt/pcre2-msvcrt/x86_64/share && \
    cd /opt/pcre2-msvcrt/x86_64/include && ln -sf pcre2posix.h regex.h

# 2) MSVCRT minimal (ASCII, POSIX, 32-Bit)
RUN mkdir -p /tmp/pcre2-msvcrt-build-i686 && \
    cmake -S /tmp/pcre2-git -B /tmp/pcre2-msvcrt-build-i686 -G Ninja \
        -DBUILD_SHARED_LIBS=OFF \
        -DPCRE2_BUILD_PCRE2_8=ON \
        -DPCRE2_BUILD_PCRE2_16=OFF \
        -DPCRE2_BUILD_PCRE2_32=OFF \
        -DPCRE2_BUILD_PCRE2_POSIX=ON \
        -DPCRE2_BUILD_TESTS=OFF \
        -DPCRE2_BUILD_PCRE2GREP=OFF \
        -DPCRE2_BUILD_PCRE2TEST=OFF \
        -DPCRE2_SUPPORT_JIT=OFF \
        -DPCRE2_SUPPORT_UTF=OFF \
        -DPCRE2_SUPPORT_UNICODE=OFF \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/opt/pcre2-msvcrt/i686 \
        -DCMAKE_C_COMPILER=i686-w64-mingw32-gcc && \
    cmake --build /tmp/pcre2-msvcrt-build-i686 && \
    cmake --install /tmp/pcre2-msvcrt-build-i686 && \
    rm -rf /tmp/pcre2-msvcrt-build-i686 /opt/pcre2-msvcrt/i686/share && \
    cd /opt/pcre2-msvcrt/i686/include && ln -sf pcre2posix.h regex.h

# 3) UCRT UTF+Unicode (for GCC 64-Bit Intel)
RUN mkdir -p /tmp/pcre2-ucrt-build-x86_64 && \
    cmake -S /tmp/pcre2-git -B /tmp/pcre2-ucrt-build-x86_64 -G Ninja \
        -DBUILD_SHARED_LIBS=OFF \
        -DPCRE2_BUILD_PCRE2_8=ON \
        -DPCRE2_BUILD_PCRE2_16=OFF \
        -DPCRE2_BUILD_PCRE2_32=OFF \
        -DPCRE2_BUILD_TESTS=OFF \
        -DPCRE2_BUILD_PCRE2GREP=OFF \
        -DPCRE2_BUILD_PCRE2TEST=OFF \
        -DPCRE2_SUPPORT_JIT=OFF \
        -DPCRE2_SUPPORT_UTF=ON \
        -DPCRE2_SUPPORT_UNICODE=ON \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/opt/pcre2-ucrt/x86_64 \
        -DCMAKE_C_COMPILER=x86_64-w64-mingw32ucrt-gcc && \
    cmake --build /tmp/pcre2-ucrt-build-x86_64 && \
    cmake --install /tmp/pcre2-ucrt-build-x86_64 && \
    rm -rf /tmp/pcre2-ucrt-build-x86_64  /opt/pcre2-ucrt/x86_64/share && \
    cd /opt/pcre2-ucrt/x86_64/include && ln -sf pcre2posix.h regex.h

ENV ORIG_PATH="$PATH"
ENV PATH="/opt/llvm-mingw/bin:${PATH}"

# 4) UCRT UTF+Unicode (for LLVM aarch64)
RUN mkdir -p /tmp/pcre2-ucrt-build-aarch64 && \
    cmake -S /tmp/pcre2-git -B /tmp/pcre2-ucrt-build-aarch64 -G Ninja \
        -DBUILD_SHARED_LIBS=OFF \
        -DPCRE2_BUILD_PCRE2_8=ON \
        -DPCRE2_BUILD_PCRE2_16=OFF \
        -DPCRE2_BUILD_PCRE2_32=OFF \
        -DPCRE2_BUILD_PCRE2_POSIX=ON \
        -DPCRE2_BUILD_TESTS=OFF \
        -DPCRE2_BUILD_PCRE2GREP=OFF \
        -DPCRE2_BUILD_PCRE2TEST=OFF \
        -DPCRE2_SUPPORT_JIT=OFF \
        -DPCRE2_SUPPORT_UTF=ON \
        -DPCRE2_SUPPORT_UNICODE=ON \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/opt/pcre2-ucrt/aarch64 \
        -DCMAKE_C_COMPILER=aarch64-w64-mingw32-clang && \
    cmake --build /tmp/pcre2-ucrt-build-aarch64 && \
    cmake --install /tmp/pcre2-ucrt-build-aarch64 && \
    rm -rf /tmp/pcre2-ucrt-build-aarch64  /opt/pcre2-ucrt/aarch64/share && \
    cd /opt/pcre2-ucrt/aarch64/include && ln -sf pcre2posix.h regex.h && \
    rm -rf /tmp/pcre2-git

ENV PATH="$ORIG_PATH"
ENV ORIG_PATH=""

# --------------------------------------------------
# Non-root dev user
# --------------------------------------------------
ARG USERNAME=vscode
RUN useradd -ms /bin/bash $USERNAME \
 && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER $USERNAME
COPY .devcontainer/scripts/bashrc /home/$USERNAME/.bashrc
