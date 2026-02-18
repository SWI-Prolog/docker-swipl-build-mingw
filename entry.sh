#!/bin/bash

export SWIPL_SOURCE_DIR=/home/swipl/src/swipl-devel
cd $SWIPL_SOURCE_DIR

unset DISPLAY
unset WAYLAND_DISPLAY
export WINEDLLOVERRIDES="winex11.drv=d;winwayland.drv=d"
export WINEDEBUG=-all
export WINEPREFIX=/wine

export CTEST_OUTPUT_ON_FAILURE=y
export CTEST_PARALLEL_LEVEL=16
export MINGW64_ROOT=/usr/x86_64-w64-mingw32/sys-root/mingw
export WINE_JAVA_HOME64=$(echo "$WINEPREFIX/drive_c/Program Files/Java/jdk"*)
export JAVA_HOME64=$(echo "$WINE_JAVA_HOME64" | sed 's/.*drive_c/c:/')

if [ ! -d "$WINEPREFIX/system.reg" ]; then
  wineboot -u
fi

if [ ! -f VERSION ]; then
  echo "Can not find SWI-Prolog source.  Please edit SWIPLSRC in Makefile"
  echo "and re-try"
  exit 1
fi

if [ -z "$*" ]; then
  echo "Starting interactive shell for cross-compiling SWI-Prolog"
  echo "Commands:"
  echo ""
  echo "  build_win64     -- build 64-bit version in build.win64"
  echo ""
  echo "  win64           -- Setup for win64 and enter build.win64"
  echo ""

  /bin/bash --rcfile /functions.sh
else
  source /functions.sh

  done=false
  while [ ! -z "$1" -a $done = false ]; do
    case "$1" in
      --win64)
	  build_win64
	  shift
	  ;;
      *)
	  echo "Options: --win64"
	  exit 1
	  done=true
    esac
  done
fi
