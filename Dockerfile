FROM fedora:42
LABEL maintainer "Jan Wielemaker <jan@swi-prolog.org>"
RUN dnf -y update && \
    dnf -y install gcc ninja-build cmake make automake libtool autoconf gawk \
    diffutils git \
    unzip sudo \
    wine mingw32-nsis mingw64-nsis \
    mingw64-gcc mingw64-zlib mingw64-gcc-c++ \
    mingw64-zlib mingw64-gmp mingw64-openssl \
    mingw64-pcre2 mingw64-libffi \
    mingw64-SDL3.noarch mingw64-SDL3-static.noarch \
    mingw64-cairo.noarch mingw64-cairo-static.noarch \
    mingw64-pango.noarch mingw64-pango-static.noarch \
    xorg-x11-server-Xvfb \
    java-latest-openjdk-devel junit

ENV MINGW64_ROOT /usr/x86_64-w64-mingw32/sys-root/mingw
ENV CROSS64 x86_64-w64-mingw32

ENV ARCHIVE_VERSION 3.7.7
ENV UUID_VERSION 1.6.2
ENV BDB_VERSION 6.1.26

RUN mkdir -p /mingw/src

RUN install_yaml() { \
      ( cd libyaml; \
        ./bootstrap; \
        ./configure --host=$CROSS --prefix=$MINGW_ROOT; \
        make; \
        make install; \
      ); \
    }; \
    cd /mingw/src && \
    git clone https://github.com/yaml/libyaml && \
    CROSS=$CROSS64 MINGW_ROOT=$MINGW64_ROOT install_yaml && \
    rm -rf libyaml

COPY deps/libarchive-$ARCHIVE_VERSION.tar.gz /mingw/src/
RUN install_libarchive() { \
      ( tar zxf libarchive-$ARCHIVE_VERSION.tar.gz; \
	cd libarchive-$ARCHIVE_VERSION; \
	export CFLAGS="-I$MINGW_ROOT/include"; \
	export LDFLAGS="-L$MINGW_ROOT/lib"; \
	export lt_cv_deplibs_check_method='pass_all'; \
	export ac_cv_func__localtime64_s='no'; \
	export ac_cv_func__ctime64_s='no'; \
	./configure --host=$CROSS --prefix=$MINGW_ROOT --with-pic --with-zlib \
	--without-iconv --without-openssl --without-nettle --without-xml2 \
	--without-expat --without-bz2lib --without-lzma --without-lzo2; \
	make; \
	make install; \
      ); \
    }; \
    cd /mingw/src && \
    CROSS=$CROSS64 MINGW_ROOT=$MINGW64_ROOT install_libarchive && \
    rm -rf libarchive-$ARCHIVE_VERSION

COPY deps/uuid-$UUID_VERSION.tar.gz /mingw/src/
RUN install_uuid() { \
      tar zxf uuid-$UUID_VERSION.tar.gz; \
      ( cd uuid-$UUID_VERSION; \
        sed -i -e "s/-m 755 uuid /-m 755 uuid.exe /" Makefile.in; \
        ac_cv_va_copy=1 ./configure --host=$CROSS --prefix=$MINGW_ROOT; \
        make; \
        make install; \
      ); \
    }; \
    cd /mingw/src && \
    CROSS=$CROSS64 MINGW_ROOT=$MINGW64_ROOT install_uuid && \
    rm -rf uuid-$UUID_VERSION

COPY deps/db-$BDB_VERSION.tar.gz /mingw/src/
RUN install_bdb() { \
      tar zxf db-$BDB_VERSION.tar.gz; \
      ( cd db-$BDB_VERSION/build_unix; \
	sed -i -e "s:WinIoCtl.h:winioctl.h:" ../src/dbinc/win_db.h; \
	sed -i -e 's@\(#include "dbinc/txn.h"\)@\1\nint __repmgr_get_nsites __P((ENV *, u_int32_t *));\n@' ../src/rep/rep_method.c; \
	../dist/configure --enable-mingw --host=$CROSS --prefix=$MINGW_ROOT \
			  --enable-shared --disable-static; \
	sed -i -e "s/^POSTLINK=.*/POSTLINK=true/" Makefile; \
	make library_build; \
	make install_lib install_include; \
	cd $MINGW_ROOT/lib; \
	[ -f libdb.dll.a ] || ln -s libdb-*.dll.a libdb.dll.a; \
	[ -f libdb.la ] || ln -s libdb-*.la libdb.la; \
      ); \
    }; \
    cd /mingw/src && \
    CROSS=$CROSS64 MINGW_ROOT=$MINGW64_ROOT install_bdb	&& \
    rm -rf db-$BDB_VERSION

# Create Wine setup with OpenSSL and OpenJDK

ENV WINEPREFIX /wine
ENV WINEDEBUG -all
ENV OPENJDK64 openjdk-21.0.1_windows-x64_bin.zip
RUN curl https://download.java.net/java/GA/jdk21.0.1/415e3f918a1f4062a0074a2794853d0d/12/GPL/${OPENJDK64} > ${OPENJDK64}
COPY deps/Win64OpenSSL_Light-3_4_0.exe /Win64OpenSSL.exe

# Patch uninstall issues in CMake 3.25.2.  We should remove and the
# patch file after CMake has been updated.  Used to use `git apply`,
# but that not appear the work if there is even the slightest change.
RUN dnf -y install patch
COPY patch /patch
RUN cd /usr/share/cmake && \
    for f in /patch/cmake/*.patch; do \
      patch -p1 < $f; \
    done

# From pywine.  Only do Python
COPY pywine/wine-init.sh pywine/keys.gpg /tmp/helper/
COPY pywine/mkuserwineprefix /opt/

RUN xvfb-run sh /tmp/helper/wine-init.sh

ARG PYTHON_VERSION=3.13.0
RUN umask 0 && cd /tmp/helper && \
  curl -LOO \
    https://www.python.org/ftp/python/${PYTHON_VERSION}/python-${PYTHON_VERSION}-amd64.exe{,.asc} \
  && \
  gpgv --keyring ./keys.gpg python-${PYTHON_VERSION}-amd64.exe.asc python-${PYTHON_VERSION}-amd64.exe && \
  xvfb-run sh -c "\
    wine python-${PYTHON_VERSION}-amd64.exe /quiet TargetDir=C:\\Python \
      Include_doc=0 InstallAllUsers=1 PrependPath=1; \
    wineserver -w" && \
  cd .. && rm -Rf helper && \
  rm -rf /tmp/.X11-unix /tmp/.X32-lock

# Get SDL3_Image
COPY deps/toolchain-mingw64.cmake /mingw/toolchain-mingw64.cmake
RUN cd /mingw/src && \
    git clone --recurse-submodules https://github.com/libsdl-org/SDL_image.git && \
    cd SDL_image && mkdir build && cd build && \
    cmake -DCMAKE_TOOLCHAIN_FILE=/mingw/toolchain-mingw64.cmake -DCMAKE_INSTALL_PREFIX=$MINGW64_ROOT .. && \
    make && make install

# Get libedit
RUN cd /mingw/src && \
    git clone https://github.com/SWI-Prolog/winlibedit.git && \
    cd winlibedit && \
    git checkout 1a98b8f6c6e3105b4721725fcd18057a426dd10a && \
    ./configure --prefix=$MINGW64_ROOT -host=x86_64-w64-mingw32 host_alias=x86_64-w64-mingw32 --enable-pic --enable-static --disable-shared 'CFLAGS=-Isrc -I. -D__STDC_ISO_10646__' && \
    make -j && \
    make install

ARG GID=1000
ARG UID=1000

RUN groupadd -g $GID -o swipl && \
    useradd  -u $UID -g $GID -o swipl && \
    mkdir -p $WINEPREFIX && \
    chown swipl:swipl $WINEPREFIX && \
    mkdir -p /home/swipl/tmp && \
    chmod 700 /home/swipl/tmp && \
    chown swipl:swipl /home/swipl/tmp

USER swipl:swipl
ENV XDG_RUNTIME_DIR /home/swipl/tmp

RUN export DISPLAY=:32 && \
    (Xvfb $DISPLAY > /dev/null 2>&1 &) && \
    mkdir -p $WINEPREFIX/drive_c/tmp && \
    WINEDEBUG=-all WINEPREFIX=${WINEPREFIX} wine /Win64OpenSSL.exe /SILENT && \
    mkdir -p "${WINEPREFIX}/drive_c/Program Files/Java" && \
    cd "${WINEPREFIX}/drive_c/Program Files/Java" && \
    unzip -qq /${OPENJDK64}
RUN rm -rf /tmp/.X11-unix /tmp/.X32-lock

COPY deps/emacs-module.h $MINGW64_ROOT/include

COPY entry.sh entry.sh
COPY functions.sh functions.sh

ENV LANG C.UTF-8
ENTRYPOINT ["/entry.sh"]
