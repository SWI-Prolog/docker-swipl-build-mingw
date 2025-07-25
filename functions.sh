# Shell functions for common tasks

# Running to many jobs concurrently under  wine   that  access  a lot of
# files causes wineserver to generate  timeouts   which  shows  as files
# claimed missing while they are not.

jobs=$(($(nproc)/2))
nopts="-j $jobs"

must_be_in_source_root()
{ if [ ! -f VERSION ]; then
    echo "Must start in source root dir"
    return 1
  fi
}

config_win64()
{ BUILD_TYPE=PGO

  if [ ! -z "$1" ]; then
      BUILD_TYPE=$1
  fi

  cmake -DCMAKE_BUILD_TYPE=$BUILD_TYPE \
	-DSWIPL_CC=gcc.exe -DSWIPL_CXX=g++.exe \
	-DSKIP_SSL_TESTS=ON \
        -DJAVA_HOME="$WINE_JAVA_HOME64" \
        -DCMAKE_TOOLCHAIN_FILE=../cmake/cross/linux_win64.cmake \
        -DJAVA_COMPATIBILITY=ON \
	-DJUNIT_JAR=/usr/share/java/junit.jar \
	-DPython_ROOT_DIR=$WINEPREFIX/drive_c/Python \
        -G Ninja ..
}

build_win64()
{ must_be_in_source_root || return 1

  dir=build.win64
  export JAVA_HOME="$JAVA_HOME64"

  rm -rf $dir
  mkdir $dir
  ( cd $dir
    config_win64 PGO
    timeout -k 2m 1h ninja $nopts
    timeout -k 2m 1h ninja $nopts
    cpack
  )
}

win64()
{ export JAVA_HOME="$JAVA_HOME64"
  mkdir -p $SWIPL_SOURCE_DIR/build.win64
  cd $SWIPL_SOURCE_DIR/build.win64
  PS1="[MinGW 64] (\W) \!_> "
}

PS1="[MinGW] (\W) \!_> "

cls()
{ clear && printf '\e[3J'
}
