SWIPLSRC=$(HOME)/src/swipl-devel
UID=$(shell id -u)
GID=$(shell id -g)
IMG=swipl-mingw-f44
QIMG=docker.io/library/${IMG}
IT=-it

MOUNT=	  -v $(SWIPLSRC):/home/swipl/src/swipl-devel:z
MOUNTX11= -v /tmp/.X11-unix:/tmp/.X11-unix
SEC=	  --cap-add=SYS_PTRACE --security-opt seccomp=unconfined

all::
	@echo "Targets:"
	@echo
	@echo "  image     Build the docker image"
	@echo "  run       Run a shell for building SWI-Prolog"
	@echo "  runx11    As 'run', providing X11 graphics"
	@echo "  win64     Build and package 64-bit version"
	@echo "  update    Do incremental build of Win64 version"
	@echo "  ctest     Run ctest"
	@echo
	@echo "Windows on ARM64 (needs an aarch64 Linux docker host, e.g. colima):"
	@echo
	@echo "  image-arm64   Build the ARM64 docker image"
	@echo "  run-arm64     Run a shell for building SWI-Prolog for ARM64"
	@echo "  winarm64      Build and package ARM64 version"
	@echo "  update-arm64  Do incremental build of ARM64 version"
	@echo "  ctest-arm64   Run ctest on ARM64 version"
	@echo
	@echo "update and ctest may be passed \"OPTIONS=<string\" to pass options for"
	@echo "ninja or ctest"

BUILDARGS=--build-arg UID=$(UID) --build-arg GID=$(GID)

image:	Dockerfile
#	docker pull fedora:44
	docker build $(BUILDARGS) -t $(IMG) . 2>&1 | tee mkimg.log

run:
	docker run $(IT) --rm $(MOUNT) $(SEC) $(QIMG)

run11:
	docker run $(IT) --rm $(MOUNT) $(MOUNTX11) -e DISPLAY=${DISPLAY} $(QIMG)

update:
	docker run $(IT) --rm $(MOUNT) $(SEC) $(QIMG) --update ${OPTIONS}

ctest:
	docker run $(IT) --rm $(MOUNT) $(SEC) $(QIMG) --ctest ${OPTIONS}

win64:
	docker run $(IT) --rm $(MOUNT) $(SEC) $(QIMG) --win64

win:
	docker run $(IT) --rm $(MOUNT) $(QIMG) --win64

################################################################
# Windows on ARM64.  Needs an aarch64 Linux docker host with 4K pages
# (e.g., colima on Apple Silicon; not Asahi Linux, whose 16K pages break
# Wine).

IMG_ARM64=swipl-mingw-arm64

image-arm64:	arm64/Dockerfile arm64/entry.sh arm64/functions.sh arm64/pacman.conf
	docker build $(BUILDARGS) -f arm64/Dockerfile -t $(IMG_ARM64) . 2>&1 | tee mkimg-arm64.log

run-arm64:
	docker run $(IT) --rm $(MOUNT) $(SEC) $(IMG_ARM64)

winarm64:
	docker run $(IT) --rm $(MOUNT) $(SEC) $(IMG_ARM64) --winarm64

update-arm64:
	docker run $(IT) --rm $(MOUNT) $(SEC) $(IMG_ARM64) --update ${OPTIONS}

ctest-arm64:
	docker run $(IT) --rm $(MOUNT) $(SEC) $(IMG_ARM64) --ctest ${OPTIONS}
