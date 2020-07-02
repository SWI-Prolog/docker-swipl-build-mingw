#!/bin/bash

cd /home/swipl/src/swipl-devel

if [ -z "$DISPLAY" ]; then
  export DISPLAY=:32
  Xvfb $DISPLAY > /dev/null 2>&1 &
fi

export MINGW64_ROOT=/usr/x86_64-w64-mingw32/sys-root/mingw
export MINGW32_ROOT=/usr/i686-w64-mingw32/sys-root/mingw
export WINEPREFIX=/wine
export WINEDEBUG=-all
export JAVA_HOME=$(echo "$WINEPREFIX/drive_c/Program Files/Java/jdk"* | sed 's/.*drive_c/c:/')

if [ ! -f VERSION ]; then
  echo "Can not find SWI-Prolog source.  Please edit SWIPLSRC in Makefile"
  echo "and re-try"
  exit 1
fi

if [ -z "$*" ]; then
  echo "Starting interactive shell for cross-compiling SWI-Prolog"
  echo "Commands:"
  echo ""
  echo "  build_win32     -- build 32-bit version in build.win32"
  echo "  build_win64     -- build 64-bit version in build.win64"
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
