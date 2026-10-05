# syntax=docker/dockerfile:1.7
#
# SWI-Prolog cross-compile image for Windows on ARM64 (aarch64).  Must
# be built and run on an aarch64 Linux host with 4K pages, e.g. colima
# or podman on Apple Silicon.  Build using `make image-arm64` or, from
# the repository root:
#
#   docker build -f arm64/Dockerfile -t swipl-mingw-arm64 .
#
# Toolchain:    llvm-mingw (clang, lld, UCRT, libc++)
# Dependencies: MSYS2 CLANGARM64 packages installed with Fedora's pacman
#               into /opt/msys; /clangarm64 links to it so the absolute
#               paths in the MSYS2 .pc and CMake files resolve.
# Emulator:     Wine built from source with --enable-archs=aarch64
#
# Stage 1 (builder) builds Wine and ossp-uuid (not in MSYS2).

ARG LLVM_MINGW=20260922
ARG LLVM_MINGW_DIR=llvm-mingw-${LLVM_MINGW}-ucrt-ubuntu-22.04-aarch64
ARG WINE_VERSION=11.0
ARG WINE_DIR=11.0
ARG UUID_VERSION=1.6.2

ARG MINGW_ROOT=/clangarm64
ARG CROSS=aarch64-w64-mingw32

ARG PYTHON_VERSION=3.14.3
ARG PYTHON_SHA256=5404a5c44e51058ebcc2df099264d579deef2ee649cb51127d811ff7f3b7353e
ARG OPENJDK=microsoft-jdk-21.0.12.1-windows-aarch64.zip
ARG OPENJDK_SHA256=6581076267222110211ba893a1bcbe73782e83d66867f76cfbd9c9f53fa67c0e

###############################################################################
# Stage 1: builder
###############################################################################

FROM fedora:44 AS builder

ARG LLVM_MINGW
ARG LLVM_MINGW_DIR
ARG WINE_VERSION
ARG WINE_DIR
ARG UUID_VERSION
ARG MINGW_ROOT
ARG CROSS

ENV LANG=C.UTF-8

RUN dnf -y install \
        gcc make flex bison xz perl diffutils automake \
        freetype-devel gnutls-devel fontconfig-devel \
        libX11-devel libXext-devel libXrandr-devel libXi-devel \
        libXcursor-devel libXrender-devel libXfixes-devel \
        libXcomposite-devel libXinerama-devel libxkbcommon-devel \
        mesa-libGL-devel mesa-libEGL-devel vulkan-loader-devel \
        && dnf clean all && rm -rf /var/cache/dnf

RUN curl -fsSL https://github.com/mstorsjo/llvm-mingw/releases/download/${LLVM_MINGW}/${LLVM_MINGW_DIR}.tar.xz \
      | tar -xJ -C /opt && \
    ln -s /opt/${LLVM_MINGW_DIR} /opt/llvm-mingw
ENV PATH=/opt/llvm-mingw/bin:$PATH

WORKDIR /tmp/src

# Wine with ARM64 PE support.  The PE side is compiled by llvm-mingw's
# aarch64-w64-mingw32-clang, which configure finds on $PATH.  We do not
# build the i386/arm(32) parts, so wineboot complains that it cannot
# start syswow64/sysarm32 rundll32.exe; that is harmless.
RUN curl -fsSL https://dl.winehq.org/wine/source/${WINE_DIR}/wine-${WINE_VERSION}.tar.xz | tar -xJ && \
    mkdir wine-build && cd wine-build && \
    ../wine-${WINE_VERSION}/configure --prefix=/usr/local \
        --enable-archs=aarch64 --without-wayland --without-oss && \
    make -j"$(nproc)" && \
    make install DESTDIR=/staging && \
    cd /tmp/src && rm -rf wine-build wine-${WINE_VERSION}

# ossp-uuid, installed into the MSYS2 tree (/opt/msys/clangarm64) that
# the runtime stage populates.  Its 2008 config.sub does not know aarch64-w64-mingw32.
COPY deps/uuid-${UUID_VERSION}.tar.gz /tmp/deps/
RUN tar xzf /tmp/deps/uuid-${UUID_VERSION}.tar.gz && \
    ( cd uuid-${UUID_VERSION} && \
      cp /usr/share/automake-*/config.sub /usr/share/automake-*/config.guess . && \
      sed -i -e "s/-m 755 uuid /-m 755 uuid.exe /" Makefile.in && \
      ac_cv_va_copy=C99 ./configure --host=$CROSS --prefix=$MINGW_ROOT \
        CC=$CROSS-clang AR=llvm-ar RANLIB=llvm-ranlib STRIP=llvm-strip && \
      make -j"$(nproc)" && \
      make install DESTDIR=/staging/opt/msys ) && \
    rm -rf uuid-${UUID_VERSION}

###############################################################################
# Stage 2: runtime
###############################################################################

FROM fedora:44
LABEL maintainer="Jan Wielemaker <jan@swi-prolog.org>"

ARG LLVM_MINGW
ARG LLVM_MINGW_DIR
ARG MINGW_ROOT
ARG CROSS
ARG PYTHON_VERSION
ARG PYTHON_SHA256
ARG OPENJDK
ARG OPENJDK_SHA256

# Runtime libraries for our Wine build are the non-devel versions of the
# builder's -devel packages.
RUN dnf -y update --refresh && \
    dnf -y install \
        ninja-build cmake make \
        diffutils git patch file \
        unzip xz zstd pacman \
        freetype gnutls fontconfig \
        libX11 libXext libXrandr libXi libXcursor libXrender libXfixes \
        libXcomposite libXinerama libxkbcommon \
        mesa-libGL mesa-libEGL mesa-dri-drivers vulkan-loader \
        mingw32-nsis mingw64-nsis \
        xorg-x11-server-Xvfb xdpyinfo \
        java-latest-openjdk-devel junit \
        procps \
        && dnf clean all && rm -rf /var/cache/dnf /var/log/dnf*

RUN curl -fsSL https://github.com/mstorsjo/llvm-mingw/releases/download/${LLVM_MINGW}/${LLVM_MINGW_DIR}.tar.xz \
      | tar -xJ -C /opt && \
    ln -s /opt/${LLVM_MINGW_DIR} /opt/llvm-mingw

ENV PATH=/opt/llvm-mingw/bin:$PATH \
    MINGW_ROOT=${MINGW_ROOT} \
    CROSS=${CROSS} \
    LANG=C.UTF-8

COPY --from=builder /staging/. /

# MSYS2 CLANGARM64 dependencies.  Signatures are checked against the
# MSYS2 keyring, which we take from the MSYS2 repository itself
# (trust-on-first-use over https).
COPY arm64/pacman.conf /opt/msys/etc/pacman.conf
RUN set -eux; \
    mkdir -p /opt/msys/var/lib/pacman /opt/msys/var/cache/pacman/pkg /opt/msys/var/log /tmp/keyring; \
    kr=$(curl -fsSL https://repo.msys2.org/msys/x86_64/ | \
         grep -oE 'msys2-keyring-[^"]+-any\.pkg\.tar\.zst' | sort -uV | tail -1); \
    curl -fsSL "https://repo.msys2.org/msys/x86_64/$kr" | tar --zstd -x -C /tmp/keyring; \
    pacman-key --config /opt/msys/etc/pacman.conf --init; \
    pacman-key --config /opt/msys/etc/pacman.conf \
        --populate-from /tmp/keyring/usr/share/pacman/keyrings --populate msys2; \
    pkgs=" \
        mingw-w64-clang-aarch64-libc++ \
        mingw-w64-clang-aarch64-libunwind \
        mingw-w64-clang-aarch64-libwinpthread \
        mingw-w64-clang-aarch64-zlib \
        mingw-w64-clang-aarch64-gmp \
        mingw-w64-clang-aarch64-openssl \
        mingw-w64-clang-aarch64-pcre2 \
        mingw-w64-clang-aarch64-libffi \
        mingw-w64-clang-aarch64-sdl3 \
        mingw-w64-clang-aarch64-sdl3-image \
        mingw-w64-clang-aarch64-cairo \
        mingw-w64-clang-aarch64-pango \
        mingw-w64-clang-aarch64-libyaml \
        mingw-w64-clang-aarch64-libarchive \
        mingw-w64-clang-aarch64-db \
        mingw-w64-clang-aarch64-libutf8proc \
        mingw-w64-clang-aarch64-pkgconf"; \
    # Retry: mirrors rate-limit (HTTP 429); completed downloads are cached.
    for i in 1 2 3 4 5; do \
      pacman --config /opt/msys/etc/pacman.conf --root /opt/msys --noconfirm \
          -Sy --needed --noscriptlet $pkgs && break; \
      [ $i -lt 5 ] || exit 1; \
      sleep 30; \
    done; \
    rm -rf /opt/msys/var/cache/pacman/pkg/* /tmp/keyring; \
    ln -s /opt/msys/clangarm64 /clangarm64

# Native compiler for build-time host tools (mkvmi, defatom).
# TODO: merge into the dnf install above when that layer is rebuilt
# anyway; kept separate to avoid re-downloading the MSYS2 packages.
RUN dnf -y install gcc && dnf clean all && rm -rf /var/cache/dnf /var/log/dnf*

# Use llvm-mingw's runtime DLLs rather than MSYS2's: our code is compiled
# with llvm-mingw's clang and headers, and swipl's CMake ships the DLLs
# from $MINGW_ROOT/bin.  Keep MSYS2's libc++.dll though: it also exports
# the unwinder (_Unwind_Resume, ...), which MSYS2 libraries such as cairo
# and graphite2 import from it.  llvm-mingw's libc++.dll does not, which
# Wine tolerates but Windows refuses to load.  MSYS2's libc++ is at least
# as new as llvm-mingw's, so it provides everything our code imports.
RUN for dll in libunwind.dll libwinpthread-1.dll; do \
      cp /opt/llvm-mingw/${CROSS}/bin/$dll ${MINGW_ROOT}/bin/$dll; \
    done

# Patch CMake (CPACK_NSIS_ONINIT_REGVIEW).
COPY patch /tmp/patch
RUN cd /usr/share/cmake && \
    for f in /tmp/patch/cmake/*.patch; do patch -p1 < "$f"; done && \
    rm -rf /tmp/patch

COPY deps/emacs-module.h ${MINGW_ROOT}/include/

ARG GID=1000
ARG UID=1000
RUN groupadd -g $GID -o swipl && \
    useradd  -u $UID -g $GID -o -m swipl && \
    mkdir -p /wine /home/swipl/tmp && \
    chmod 700 /home/swipl/tmp && \
    chown -R swipl:swipl /wine /home/swipl

ENV WINEPREFIX=/wine \
    WINEDEBUG=-all \
    WINEDLLOVERRIDES="winemenubuilder.exe=d" \
    XDG_RUNTIME_DIR=/home/swipl/tmp

USER swipl:swipl

# Wine prefix, Python (NuGet zip) and OpenJDK, in one layer.
RUN set -eux; \
    umask 0; \
    mkdir -p /tmp/helper; cd /tmp/helper; \
    wineboot -u; \
    wineserver -w; \
    curl -fsSL -o python.zip \
        "https://api.nuget.org/v3-flatcontainer/pythonarm64/${PYTHON_VERSION}/pythonarm64.${PYTHON_VERSION}.nupkg"; \
    echo "${PYTHON_SHA256}  python.zip" | sha256sum -c; \
    unzip -qq python.zip 'tools/*' -d py; \
    mv py/tools "$WINEPREFIX/drive_c/Python"; \
    # The NuGet package has no installer; put Python on the Windows PATH
    # as the python.org installer's PrependPath=1 does.  janus.pl looks
    # for python3.dll there.
    wine reg add 'HKCU\Environment' /v PATH /t REG_EXPAND_SZ \
        /d 'C:\Python;C:\Python\Scripts' /f; \
    wineserver -w; \
    curl -fsSL -o "${OPENJDK}" "https://aka.ms/download-jdk/${OPENJDK}"; \
    echo "${OPENJDK_SHA256}  ${OPENJDK}" | sha256sum -c; \
    mkdir -p "$WINEPREFIX/drive_c/Program Files/Java"; \
    ( cd "$WINEPREFIX/drive_c/Program Files/Java" && unzip -qq "/tmp/helper/${OPENJDK}" ); \
    find "$WINEPREFIX/drive_c/Python" -type d -name __pycache__ \
        -exec rm -rf {} + 2>/dev/null || true; \
    rm -rf "$WINEPREFIX/drive_c/Python/Lib/test" \
           "$WINEPREFIX/drive_c/Python/Lib/idlelib" \
           "$WINEPREFIX/drive_c/Python/Lib/turtledemo"; \
    cd /; rm -rf /tmp/helper; \
    rm -rf "$WINEPREFIX"/drive_c/users/swipl/Temp/* 2>/dev/null || true

COPY --chown=swipl:swipl arm64/entry.sh /entry.sh
COPY --chown=swipl:swipl arm64/functions.sh /functions.sh

ENTRYPOINT ["/entry.sh"]
