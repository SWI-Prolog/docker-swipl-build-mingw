# syntax=docker/dockerfile:1.7
#
# Multi-stage build for the SWI-Prolog Windows cross-compile image.
#
# Stage 1 (builder) builds libyaml, libarchive, uuid, libdb, SDL_image
# and utf8proc into /staging using DESTDIR so the install tree can be
# COPYed wholesale into the runtime stage with all sources, build trees
# and build-only tools (autoconf/automake/libtool/...) left behind.
#
# Stage 2 (runtime) runs the Wine setup entirely as the swipl user so
# we never need a `chown -R /wine' fix-up pass --- which in the previous
# image cost a duplicate 1.77 GB layer of the wineprefix.

ARG MINGW64_ROOT=/usr/x86_64-w64-mingw32/sys-root/mingw
ARG CROSS64=x86_64-w64-mingw32

ARG ARCHIVE_VERSION=3.8.5
ARG UUID_VERSION=1.6.2
ARG BDB_VERSION=6.1.26
ARG SDL_VERSION=3.4.0
ARG UTF8PROC_VERSION=v2.11.3

# renovate: datasource=github-tags depName=python/cpython versioning=pep440
ARG PYTHON_VERSION=3.14.3
# renovate: datasource=github-releases depName=upx/upx versioning=loose
ARG UPX_VERSION=5.1.0
ARG OPENJDK64=openjdk-21.0.1_windows-x64_bin.zip

###############################################################################
# Stage 1: builder -- cross-compile dependencies, install to /staging
###############################################################################

FROM fedora:44 AS builder

ARG MINGW64_ROOT
ARG CROSS64
ARG ARCHIVE_VERSION
ARG UUID_VERSION
ARG BDB_VERSION
ARG SDL_VERSION
ARG UTF8PROC_VERSION

ENV MINGW64_ROOT=${MINGW64_ROOT} \
    CROSS64=${CROSS64} \
    STAGING=/staging \
    LANG=C.UTF-8

RUN dnf -y install \
        gcc gcc-c++ make ninja-build cmake \
        automake libtool autoconf gawk \
        diffutils git patch tar gzip \
        binutils-${CROSS64} \
        mingw64-gcc mingw64-gcc-c++ \
        mingw64-zlib mingw64-zlib-static mingw64-gmp \
        mingw64-openssl mingw64-pcre2 mingw64-libffi \
        mingw64-SDL3.noarch mingw64-SDL3-static.noarch \
        mingw64-cairo.noarch mingw64-cairo-static.noarch \
        mingw64-pango.noarch mingw64-pango-static.noarch \
        && dnf clean all && rm -rf /var/cache/dnf

COPY deps/libarchive-${ARCHIVE_VERSION}.tar.gz \
     deps/uuid-${UUID_VERSION}.tar.gz \
     deps/db-${BDB_VERSION}.tar.gz \
     deps/toolchain-mingw64.cmake \
     /tmp/deps/

# All cross-compile steps in one RUN so source and build trees do not
# leak into intermediate layers; each `make install' uses DESTDIR so
# the resulting tree at /staging mirrors the eventual on-target layout
# rooted at $MINGW64_ROOT (i.e. /staging/usr/x86_64-w64-mingw32/...).
RUN set -eux; \
    mkdir -p /tmp/src "$STAGING"; \
    cd /tmp/src; \
    \
    # libyaml
    git clone --depth 1 https://github.com/yaml/libyaml; \
    ( cd libyaml; \
      ./bootstrap; \
      ./configure --host=$CROSS64 --prefix=$MINGW64_ROOT; \
      make -j"$(nproc)"; \
      make install DESTDIR=$STAGING; \
    ); \
    \
    # libarchive
    tar xzf /tmp/deps/libarchive-${ARCHIVE_VERSION}.tar.gz; \
    ( cd libarchive-${ARCHIVE_VERSION}; \
      export CFLAGS="-I$MINGW64_ROOT/include" LDFLAGS="-L$MINGW64_ROOT/lib"; \
      export lt_cv_deplibs_check_method='pass_all'; \
      export ac_cv_func__localtime64_s='no'; \
      export ac_cv_func__ctime64_s='no'; \
      ./configure --host=$CROSS64 --prefix=$MINGW64_ROOT --with-pic --with-zlib \
        --without-iconv --without-openssl --without-nettle --without-xml2 \
        --without-expat --without-bz2lib --without-lzma --without-lzo2; \
      make -j"$(nproc)"; \
      make install DESTDIR=$STAGING; \
    ); \
    \
    # uuid
    tar xzf /tmp/deps/uuid-${UUID_VERSION}.tar.gz; \
    ( cd uuid-${UUID_VERSION}; \
      sed -i -e "s/-m 755 uuid /-m 755 uuid.exe /" Makefile.in; \
      ac_cv_va_copy=1 ./configure --host=$CROSS64 --prefix=$MINGW64_ROOT; \
      make -j"$(nproc)"; \
      make install DESTDIR=$STAGING; \
    ); \
    \
    # BerkeleyDB
    tar xzf /tmp/deps/db-${BDB_VERSION}.tar.gz; \
    ( cd db-${BDB_VERSION}/build_unix; \
      sed -i -e "s:WinIoCtl.h:winioctl.h:" ../src/dbinc/win_db.h; \
      sed -i -e 's@\(#include "dbinc/txn.h"\)@\1\nint __repmgr_get_nsites __P((ENV *, u_int32_t *));\n@' \
        ../src/rep/rep_method.c; \
      ../dist/configure --enable-mingw --host=$CROSS64 --prefix=$MINGW64_ROOT \
        --enable-shared --disable-static; \
      sed -i -e "s/^POSTLINK=.*/POSTLINK=true/" Makefile; \
      make -j"$(nproc)" library_build; \
      make install_lib install_include DESTDIR=$STAGING; \
      cd $STAGING$MINGW64_ROOT/lib; \
      [ -f libdb.dll.a ] || ln -s libdb-*.dll.a libdb.dll.a; \
      [ -f libdb.la ] || ln -s libdb-*.la libdb.la; \
    ); \
    \
    # SDL_image
    git clone --recurse-submodules --shallow-submodules \
      --depth 1 --branch release-${SDL_VERSION} \
      https://github.com/libsdl-org/SDL_image.git; \
    ( cd SDL_image; mkdir build; cd build; \
      cmake -DCMAKE_TOOLCHAIN_FILE=/tmp/deps/toolchain-mingw64.cmake \
            -DCMAKE_INSTALL_PREFIX=$MINGW64_ROOT \
            -DCMAKE_PREFIX_PATH=$MINGW64_ROOT ..; \
      make -j"$(nproc)"; \
      make install DESTDIR=$STAGING; \
    ); \
    \
    # utf8proc
    git clone --depth 1 --branch ${UTF8PROC_VERSION} \
      https://github.com/JuliaStrings/utf8proc.git; \
    ( cd utf8proc; mkdir build; cd build; \
      cmake -DCMAKE_TOOLCHAIN_FILE=/tmp/deps/toolchain-mingw64.cmake \
            -DCMAKE_INSTALL_PREFIX=$MINGW64_ROOT \
            -DBUILD_SHARED_LIBS=ON ..; \
      make -j"$(nproc)"; \
      make install DESTDIR=$STAGING; \
    ); \
    \
    # Strip cross-built artifacts in place under the staging tree.
    find "$STAGING$MINGW64_ROOT" \( -name '*.dll' -o -name '*.exe' \) \
      -exec ${CROSS64}-strip --strip-unneeded {} + 2>/dev/null || true; \
    \
    rm -rf /tmp/src /tmp/deps

###############################################################################
# Stage 2: runtime
###############################################################################

FROM fedora:44
LABEL maintainer="Jan Wielemaker <jan@swi-prolog.org>"

ARG MINGW64_ROOT
ARG CROSS64
ARG PYTHON_VERSION
ARG UPX_VERSION
ARG OPENJDK64

# Runtime dnf set: drops automake/libtool/autoconf/gawk/sudo which are
# only needed by the builder stage.
RUN dnf -y update --refresh && \
    dnf -y install \
        gcc ninja-build cmake make \
        diffutils git patch \
        unzip \
        wine mingw32-nsis mingw64-nsis \
        mingw64-gcc mingw64-zlib mingw64-gcc-c++ \
        mingw64-zlib mingw64-zlib-static mingw64-gmp mingw64-openssl \
        mingw64-pcre2 mingw64-libffi \
        mingw64-SDL3.noarch mingw64-SDL3-static.noarch \
        mingw64-cairo.noarch mingw64-cairo-static.noarch \
        mingw64-pango.noarch mingw64-pango-static.noarch \
        xorg-x11-server-Xvfb \
        java-latest-openjdk-devel junit \
        procps \
        && dnf clean all && rm -rf /var/cache/dnf /var/log/dnf*

ENV MINGW64_ROOT=${MINGW64_ROOT} \
    CROSS64=${CROSS64} \
    LANG=C.UTF-8

# Merge the cross-built libraries from the builder stage.  /staging
# mirrors the eventual on-target paths so a copy of /staging/. into /
# drops files exactly where the dnf-installed mingw root expects them.
COPY --from=builder /staging/. /

# Patch CMake (CPACK_NSIS_ONINIT_REGVIEW).  Drop the patch dir after.
COPY patch /tmp/patch
RUN cd /usr/share/cmake && \
    for f in /tmp/patch/cmake/*.patch; do patch -p1 < "$f"; done && \
    rm -rf /tmp/patch

# The emacs-module.h header lives next to the other mingw includes.
COPY deps/emacs-module.h ${MINGW64_ROOT}/include/

# Create the swipl user BEFORE wineboot so /wine is owned by swipl from
# the start.  Doing it the other way around forces a `chown -R /wine'
# fix-up RUN later, which in the previous image cost a 1.77 GB layer.
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

# Stage the Wine-side build inputs in a location swipl owns so the
# single mega-RUN below can use them without going back to root.
COPY --chown=swipl:swipl pywine/wine-init.sh pywine/SHA256SUMS.txt \
     /tmp/helper/
COPY --chown=swipl:swipl deps/Win64OpenSSL_Light-3_4_0.exe \
     /tmp/helper/Win64OpenSSL.exe
COPY pywine/mkuserwineprefix /opt/

USER swipl:swipl

# One RUN for the whole Wine setup -- wineboot, pywine init, Python +
# UPX install, OpenSSL install, OpenJDK download+unzip+remove, then
# trim Python pyc/test/idle/Doc trees and clear wine temp.  Keeping
# this in a single layer means no duplicated wineprefix state across
# layers and no leaked installer payloads.
RUN --mount=from=ghcr.io/sigstore/cosign/cosign:v3.0.4@sha256:0b015a3557a64a751712da8a6395534160018eaaa2d969882a85a336de9adb70,source=/ko-app/cosign,target=/usr/bin/cosign \
    set -eux; \
    umask 0; \
    cd /tmp/helper; \
    # 1. wineboot
    wineboot -u; \
    wineserver -w; \
    rm -rf "$WINEPREFIX"/drive_c/users/swipl/Temp/* 2>/dev/null || true; \
    # 2. pywine init (HKCU registry tweaks)
    xvfb-run sh ./wine-init.sh; \
    # 3. Python + UPX
    curl --fail-with-body -LOO \
        "https://www.python.org/ftp/python/${PYTHON_VERSION}/python-${PYTHON_VERSION}-amd64.exe{,.sigstore}" \
        "https://github.com/upx/upx/releases/download/v${UPX_VERSION}/upx-${UPX_VERSION}-win64.zip"; \
    cosign verify-blob --certificate-oidc-issuer https://github.com/login/oauth \
        --certificate-identity-regexp='@python.org$' \
        --bundle "python-${PYTHON_VERSION}-amd64.exe.sigstore" \
        "python-${PYTHON_VERSION}-amd64.exe"; \
    sha256sum -c SHA256SUMS.txt; \
    xvfb-run sh -c "\
        wine python-${PYTHON_VERSION}-amd64.exe /quiet TargetDir=C:\\\\Python \
            Include_doc=0 InstallAllUsers=1 PrependPath=1; \
        wineserver -w"; \
    unzip "upx-${UPX_VERSION}-win64.zip"; \
    mv "upx-${UPX_VERSION}-win64/upx.exe" "$WINEPREFIX/drive_c/windows/"; \
    # 4. OpenSSL
    xvfb-run sh -c "wine /tmp/helper/Win64OpenSSL.exe /SILENT; wineserver -w"; \
    # 5. OpenJDK (download, unzip, drop the zip in the same layer)
    curl --fail-with-body -L \
        "https://download.java.net/java/GA/jdk21.0.1/415e3f918a1f4062a0074a2794853d0d/12/GPL/${OPENJDK64}" \
        -o "/tmp/helper/${OPENJDK64}"; \
    mkdir -p "$WINEPREFIX/drive_c/Program Files/Java"; \
    ( cd "$WINEPREFIX/drive_c/Program Files/Java" && \
      unzip -qq "/tmp/helper/${OPENJDK64}" ); \
    # 6. Trim Python (pyc, tests, idle, docs)
    find "$WINEPREFIX/drive_c/Python" -type d -name __pycache__ \
        -exec rm -rf {} + 2>/dev/null || true; \
    rm -rf "$WINEPREFIX/drive_c/Python/Lib/test" \
           "$WINEPREFIX/drive_c/Python/Lib/idlelib" \
           "$WINEPREFIX/drive_c/Python/Lib/turtledemo" \
           "$WINEPREFIX/drive_c/Python/Doc"; \
    # 7. Final cleanup
    rm -rf /tmp/helper /tmp/.X11-unix /tmp/.X32-lock 2>/dev/null || true; \
    rm -rf "$WINEPREFIX"/drive_c/users/swipl/Temp/* 2>/dev/null || true

COPY --chown=swipl:swipl entry.sh /entry.sh
COPY --chown=swipl:swipl functions.sh /functions.sh

ENTRYPOINT ["/entry.sh"]
