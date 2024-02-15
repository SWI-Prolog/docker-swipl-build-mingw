# Docker to cross-compile SWI-Prolog for Windows

This  docker  builds   SWI-Prolog   for    Windows   using   the   MinGW
cross-compilation toolchain from Linux.  Usage:

  - Get source tree if you don't have it already

```
	git clone https://github.com/SWI-Prolog/swipl-devel.git
        git -C swipl-devel submodule update --init
```
  - Setup docker-swipl-build-mingw

```
	git clone https://github.com/SWI-Prolog/docker-swipl-build-mingw.git
	git -C docker-swipl-build-mingw submodule update --init
```
  - Edit `Makefile` to make $SWIPLSRC point at a checked out source tree
    normally obtained using

```
	git clone https://github.com/SWI-Prolog/swipl-devel.git
	git submodule update --init
```
  - By default, the Docker image creates a user `swipl` with the UID and
    GID of the user that creates the image.  This user/group is used for
    the build process.  Edit GID and UID in Makefile if you want a
    different scenario.

  - Create the Docker image using the command below.  This takes quite
    long.  The image is pretty big (6.71Gb)

```
	make image
```

  - Run the image using the command below. This create an X11 _headless_
    server for running Wine.  If debugging is required it may be wise
    to run `make run11` which sets up X11 forwarding, making Wine
    windows appear on your X11 deskop (requires a Unix host).

```
	make run
```

  - The commands below create a fresh build.win32 (build.win64)
    directory, configures, builds and packages SWI-Prolog for
    Windows 32/64

```
	build_win32
	build_win64
```

  - For updating/debugging a build, go into one of the above
    build directories and build using `ninja`.  Note that the
    release build uses PGO optimization.  If you modified any
    of the SWI-Prolog core sources you must either disable
    PGO compilation using this command, after which you can
    rebuild using `ninja`

```
	../scripts/pgo-compile.sh --off
```

    or build using PGO optimization using

```
	../scripts/pgo-compile.sh
```

## Issues

  - The SSL test suite is currently not built.  There is an
    issue running `openssl.exe` in `wine` in a Docker container
    with the random seeding.

## Considerations

The Docker is built on Fedora (latest) as   this  distro seems to have a
good balance between stability  and   providing  up-to-date  development
tools. Notably the MinGW tool suite provides   a lot of the dependencies
we need and, unlike  its  Ubuntu   (20.04)  equivalent,  PGO compilation
works.
