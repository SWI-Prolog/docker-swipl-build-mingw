FROM fedora:latest
LABEL maintainer "Jan Wielemaker <jan@swi-prolog.org>"
RUN dnf -y update && \
    dnf -y install gcc ninja-build cmake make automake libtool autoconf \
		   diffutils git \
		   unzip sudo \
		   wine mingw32-nsis \
                   mingw64-gcc mingw64-zlib mingw64-gcc-c++ \
		   mingw64-zlib mingw64-gmp mingw64-openssl mingw64-pcre \
		   mingw64-libffi mingw64-libjpeg-turbo \
                   mingw32-gcc mingw32-zlib mingw32-gcc-c++ \
		   mingw32-zlib mingw32-gmp mingw32-openssl mingw32-pcre \
		   mingw32-libffi mingw32-libjpeg-turbo \
		   xorg-x11-server-Xvfb \
		   java-11-openjdk-devel junit

ENV MINGW64_ROOT /usr/x86_64-w64-mingw32/sys-root/mingw
ENV MINGW32_ROOT /usr/i686-w64-mingw32/sys-root/mingw
ENV CROSS64 x86_64-w64-mingw32
ENV CROSS32 i686-w64-mingw32

ENV ARCHIVE_VERSION 3.4.0
ENV UUID_VERSION 1.6.2
ENV BDB_VERSION 6.1.26

RUN mkdir -p /mingw/src

RUN install_libxpm() { \
      ( cd libXpm/lib; \
        autoconf; \
        ./configure --host=$CROSS --prefix=$MINGW_ROOT; \
        make -f Makefile.mingw; \
        make -f Makefile.mingw install; \
      ); \
    }; \
    cd /mingw/src && \
    git clone https://github.com/SWI-Prolog/libXpm.git && \
    CROSS=$CROSS64 MINGW_ROOT=$MINGW64_ROOT install_libxpm && \
    git -C libXpm clean -xfd && \
    CROSS=$CROSS32 MINGW_ROOT=$MINGW32_ROOT install_libxpm && \
    rm -rf libXpm

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
    git -C libyaml clean -xfd && \
    CROSS=$CROSS32 MINGW_ROOT=$MINGW32_ROOT install_yaml && \
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
	--without-expat --without-libregex --without-bz2lib \
	--without-lzmadec --without-lzma --without-lzo2; \
	make; \
	make install; \
      ); \
    }; \
    cd /mingw/src && \
    CROSS=$CROSS64 MINGW_ROOT=$MINGW64_ROOT install_libarchive && \
    rm -rf libarchive-$ARCHIVE_VERSION && \
    CROSS=$CROSS32 MINGW_ROOT=$MINGW32_ROOT install_libarchive && \
    rm -rf libarchive-$ARCHIVE_VERSION

COPY deps/uuid-$UUID_VERSION.tar.gz /mingw/src/
RUN install_uuid() { \
      tar zxf uuid-$UUID_VERSION.tar.gz; \
      ( cd uuid-$UUID_VERSION; \
        sed -i -e "s/-m 755 uuid /-m 755 uuid.exe /" Makefile.in; \
        ./configure --host=$CROSS --prefix=$MINGW_ROOT; \
        make; \
        make install; \
      ); \
    }; \
    cd /mingw/src && \
    CROSS=$CROSS64 MINGW_ROOT=$MINGW64_ROOT install_uuid && \
    rm -rf uuid-$UUID_VERSION && \
    CROSS=$CROSS32 MINGW_ROOT=$MINGW32_ROOT install_uuid && \
    rm -rf uuid-$UUID_VERSION

COPY deps/db-$BDB_VERSION.tar.gz /mingw/src/
RUN install_bdb() { \
      tar zxf db-$BDB_VERSION.tar.gz; \
      ( cd db-$BDB_VERSION/build_unix; \
	sed -i -e "s:WinIoCtl.h:winioctl.h:" ../src/dbinc/win_db.h; \
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
    rm -rf db-$BDB_VERSION && \
    CROSS=$CROSS32 MINGW_ROOT=$MINGW32 install_bdb	&& \
    rm -rf db-$BDB_VERSION

# Create Wine setup with OpenSSL and OpenJDK

ENV WINEPREFIX /wine
ENV WINEDEBUG -all
ENV OPENJDK openjdk-13.0.2_windows-x64_bin.zip
RUN curl https://download.java.net/java/GA/jdk13.0.2/d4173c853231432d94f001e99d882ca7/8/GPL/${OPENJDK} > ${OPENJDK}
COPY deps/Win64OpenSSL_Light-1_1_1g.exe /Win64OpenSSL.exe

RUN groupadd -g 1000 -o swipl && \
    useradd  -u 1000 -g 1000 -o swipl && \
    mkdir -p $WINEPREFIX && \
    chown swipl.swipl $WINEPREFIX && \
    export DISPLAY=:32 && \
    (Xvfb $DISPLAY > /dev/null 2>&1 &) && \
    sudo -u swipl mkdir -p $WINEPREFIX/drive_c/tmp && \
    sudo -u swipl WINEDEBUG=-all WINEPREFIX=${WINEPREFIX} wine /Win64OpenSSL.exe /SILENT && \
    sudo -u swipl mkdir -p "${WINEPREFIX}/drive_c/Program Files/Java" && \
    cd "${WINEPREFIX}/drive_c/Program Files/Java" && \
    sudo -u swipl unzip -qq /${OPENJDK}
RUN rm -rf /tmp/.X11-unix /tmp/.X32-lock

COPY entry.sh entry.sh
COPY bash-init.sh bash-init.sh
ENV LANG C.UTF-8
ENTRYPOINT ["/entry.sh"]
