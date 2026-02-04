SWIPLSRC=$(HOME)/src/swipl-devel
UID=$(shell id -u)
GID=$(shell id -g)
IMG=swipl-mingw-f43
QIMG=docker.io/library/${IMG}
IT=-it

MOUNT=	  -v $(SWIPLSRC):/home/swipl/src/swipl-devel
MOUNTX11= -v /tmp/.X11-unix:/tmp/.X11-unix

all::
	@echo "Targets:"
	@echo
	@echo "  image     Build the docker image"
	@echo "  run       Run a shell for building SWI-Prolog"
	@echo "  runx11    As 'run', providing X11 graphics"
	@echo "  win64     Build and package 64-bit version"
	@echo "  win       Build and package 64-bit version"
	@echo

BUILDARGS=--build-arg UID=$(UID) --build-arg GID=$(GID)

image:	Dockerfile
	docker build $(BUILDARGS) -t $(IMG) . 2>&1 | tee mkimg.log

run:
	docker run $(IT) --rm $(MOUNT) $(QIMG)

run11:
	docker run $(IT) --rm $(MOUNT) $(MOUNTX11) -e DISPLAY=${DISPLAY} $(QIMG)

win64:
	docker run $(IT) --rm $(MOUNT) $(QIMG) --win64

win:
	docker run $(IT) --rm $(MOUNT) $(QIMG) --win64
