if [ -z "$DISPLAY" ]; then
  export DISPLAY=:32
  Xvfb $DISPLAY > /dev/null 2>&1 &
fi

export MINGW64_ROOT=/usr/x86_64-w64-mingw32/sys-root/mingw
export MINGW32_ROOT=/usr/i686-w64-mingw32/sys-root/mingw
export WINEPREFIX=/wine
export WINEDEBUG=-all
export JAVA_HOME=$(echo "$WINEPREFIX/drive_c/Program Files/Java/jdk"* | sed 's/.*drive_c/c:/')

must_be_in_source_root()
{ if [ ! -f VERSION ]; then
    echo "Must start in source root dir"
    return 1
  fi
}

build_win64()
{ must_be_in_source_root || return 1

  dir=build.win64

  rm -rf $dir
  mkdir $dir
  ( cd $dir
    cmake -DCMAKE_BUILD_TYPE=Release \
	  -DSKIP_SSL_TESTS=ON \
          -DJAVA_HOME="$WINEPREFIX/drive_c/Program Files/Java/jdk-13.0.2" \
          -DCMAKE_TOOLCHAIN_FILE=../cmake/cross/linux_win64.cmake \
          -DJAVA_COMPATIBILITY=ON \
          -G Ninja ..
    ../scripts/pgo-compile.sh
    ninja
    cpack
  )
}

build_win32()
{ must_be_in_source_root || return 1

  dir=build.win32

  rm -rf $dir
  mkdir $dir
  ( cd $dir
    cmake -DCMAKE_BUILD_TYPE=Release \
	  -DSKIP_SSL_TESTS=ON \
          -DCMAKE_TOOLCHAIN_FILE=../cmake/cross/linux_win32.cmake \
          -G Ninja ..
    ../scripts/pgo-compile.sh
    ninja
    cpack
  )
}

if [ ! -f VERSION ]; then
  echo "Can not find SWI-Prolog source.  Edit SWIPLSRC in Makefile"
  echo "and re-try"
  exit 1
fi

if [ -z "$*" ]; then
  echo "Interactive shell for cross-compiling SWI-Prolog"
  echo "Commands:"
  echo ""
  echo "  build_win32     -- build 32-bit version in build.win32"
  echo "  build_win64     -- build 64-bit version in build.win64"
  echo ""
else
  done=false
  while [ ! -z "$1" -a $done = false ]; do
    case "$1" in
      --win64)
	  build_win64
	  shift
	  ;;
      --win32)
	  build_win32
	  shift
	  ;;
      *)
	  echo "Options: --win32 --win64"
	  exit 1
	  done=true
    esac
  done
fi
