#!/bin/bash

export SWIPL_SOURCE_DIR=/home/swipl/src/swipl-devel

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

# Clone the SWI-Prolog source tree into the container.  Used by the
# GitHub Action so the build never touches the host filesystem and we
# do not have to worry about UID/GID mapping or SELinux labels.
clone_swipl() {
  local url=$1 ref=$2

  if [ -z "$url" ] || [ -z "$ref" ]; then
    echo "--win64-from-git requires URL and REF arguments" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$SWIPL_SOURCE_DIR")"
  rm -rf "$SWIPL_SOURCE_DIR"
  git clone --recurse-submodules --shallow-submodules \
            --branch "$ref" --depth 1 \
            "$url" "$SWIPL_SOURCE_DIR"
}

if [ -z "$*" ]; then
  if [ ! -f "$SWIPL_SOURCE_DIR/VERSION" ]; then
    echo "Can not find SWI-Prolog source.  Please edit SWIPLSRC in Makefile"
    echo "and re-try"
    exit 1
  fi
  cd "$SWIPL_SOURCE_DIR"
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
	  cd "$SWIPL_SOURCE_DIR"
	  build_win64
	  shift
	  ;;
      --update)
	  cd "$SWIPL_SOURCE_DIR"
	  update_win64
	  shift
	  ;;
      --win64-from-git)
	  clone_swipl "$2" "$3"
	  shift 3
	  cd "$SWIPL_SOURCE_DIR"
	  build_win64
	  ;;
      *)
	  echo "Options: --win64 | --update | --win64-from-git URL REF"
	  exit 1
	  done=true
    esac
  done
fi
