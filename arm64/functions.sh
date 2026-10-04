# Shell functions for common tasks (Windows ARM64)

jobs=$(($(nproc)/2))
nopts="-j $jobs"
dir=build.winarm64

must_be_in_source_root()
{ if [ ! -f VERSION ]; then
    echo "Must start in source root dir"
    return 1
  fi
}

# FindPython cannot run the Windows python.exe to query it, so we pass
# the include directory and import library of the NuGet Python
# explicitly.  Otherwise it picks up the Linux python3 and MSYS2's
# libpython.
config_winarm64()
{ BUILD_TYPE=${BUILD_TYPE:=Release}
  OPTS=${OPTS:=}

  if [ ! -z "$1" ]; then
      BUILD_TYPE=$1
  fi

  cmake -DCMAKE_BUILD_TYPE=$BUILD_TYPE $OPTS \
	-DSWIPL_CC=clang.exe -DSWIPL_CXX=clang++.exe \
	-DSKIP_SSL_TESTS=ON \
        -DJAVA_HOME="$WINE_JAVA_HOME" \
        -DCMAKE_TOOLCHAIN_FILE=../cmake/cross/linux_win_arm64.cmake \
        -DJAVA_COMPATIBILITY=ON \
	-DJUNIT_JAR=/usr/share/java/junit.jar \
	-DPython_ROOT_DIR=$WINEPREFIX/drive_c/Python \
	-DPython_INCLUDE_DIR=$WINEPREFIX/drive_c/Python/include \
	-DPython_LIBRARY=$(ls $WINEPREFIX/drive_c/Python/libs/python3?*.lib | head -1) \
        -G Ninja -S .. -B .
}

build_winarm64()
{ must_be_in_source_root || return 1

  export JAVA_HOME="$JAVA_HOME_WIN"

  rm -rf $dir
  mkdir $dir
  ( cd $dir
    config_winarm64
    ninja $nopts
    cpack
  )
}

update_winarm64()
{ must_be_in_source_root || return 1

  export JAVA_HOME="$JAVA_HOME_WIN"

  ( cd $dir
    ninja $nopts $*
  )
}

ctest_winarm64()
{ must_be_in_source_root || return 1

  export JAVA_HOME="$JAVA_HOME_WIN"

  echo "ctest $*"

  ( cd $dir
    ctest $*
  )
}

winarm64()
{ export JAVA_HOME="$JAVA_HOME_WIN"
  mkdir -p $SWIPL_SOURCE_DIR/$dir
  cd $SWIPL_SOURCE_DIR/$dir
  PS1="[MinGW ARM64] (\W) \!_> "
}

PS1="[MinGW ARM64] (\W) \!_> "

cls()
{ clear && printf '\e[3J'
}
