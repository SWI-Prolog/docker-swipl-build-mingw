# Shell functions for common tasks

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
	  -DJUNIT_JAR=/usr/share/java/junit.jar \
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

PS1="[MinGW] (\W) \!_> "
