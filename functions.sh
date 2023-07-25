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

build_win64()
{ must_be_in_source_root || return 1

  dir=build.win64
  export JAVA_HOME="$JAVA_HOME64"

  rm -rf $dir
  mkdir $dir
  ( cd $dir
    cmake -DCMAKE_BUILD_TYPE=PGO \
	  -DSKIP_SSL_TESTS=ON \
          -DJAVA_HOME="$WINEPREFIX/drive_c/Program Files/Java/jdk-13.0.2" \
          -DCMAKE_TOOLCHAIN_FILE=../cmake/cross/linux_win64.cmake \
          -DJAVA_COMPATIBILITY=ON \
	  -DJUNIT_JAR=/usr/share/java/junit.jar \
	  -DPython_ROOT_DIR=$WINEPREFIX/drive_c/Python \
          -G Ninja ..
    timeout -k 2m 1h ninja $nopts
    timeout -k 2m 1h ninja $nopts
    cpack
  )
}

build_win32()
{ must_be_in_source_root || return 1

  dir=build.win32
  export JAVA_HOME="$JAVA_HOME32"

  rm -rf $dir
  mkdir $dir
  ( cd $dir
    cmake -DCMAKE_BUILD_TYPE=PGO \
	  -DSKIP_SSL_TESTS=ON \
	  -DJAVA_HOME="$WINEPREFIX/drive_c/Program Files (x86)/Java/jdk-14.0.2+12" \
          -DCMAKE_TOOLCHAIN_FILE=../cmake/cross/linux_win32.cmake \
          -DJAVA_COMPATIBILITY=ON \
	  -DJUNIT_JAR=/usr/share/java/junit.jar \
          -G Ninja ..
    timeout -k 2m 1h ninja $nopts
    timeout -k 2m 1h ninja $nopts
    cpack
  )
}

win32()
{ export JAVA_HOME="$JAVA_HOME32"
  mkdir -p $SWIPL_SOURCE_DIR/build.win32
  cd $SWIPL_SOURCE_DIR/build.win32
  PS1="[MinGW 32] (\W) \!_> "
}

win64()
{ export JAVA_HOME="$JAVA_HOME64"
  mkdir -p $SWIPL_SOURCE_DIR/build.win64
  cd $SWIPL_SOURCE_DIR/build.win64
  PS1="[MinGW 64] (\W) \!_> "
}

PS1="[MinGW] (\W) \!_> "
