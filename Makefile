SWIPLSRC=$(HOME)/src/swipl-devel
UID=$(shell id -u)
GID=$(shell id -g)

MOUNT=	  -v $(SWIPLSRC):/home/swipl/src/swipl-devel
MOUNTX11= -v /tmp/.X11-unix:/tmp/.X11-unix

all::
	@echo "Targets:"
	@echo
	@echo "  image     Build the docker image"
	@echo "  run       Run a shell for building SWI-Prolog"
	@echo "  runx11    As 'run', providing X11 graphics"
	@echo "  win32     Build and package 32-bit version"
	@echo "  win64     Build and package 64-bit version"
	@echo "  win       Build and package both 32-bit and 64-bit version"
	@echo

BUILDARGS=--build-arg UID=$(UID) GID=$(GID)

image:	Dockerfile
	docker build -t swipl-mingw . 2>&1 | tee mkimg.log

run:
	docker run -it --rm $(MOUNT) swipl-mingw

run11:
	docker run -it --rm $(MOUNT) $(MOUNTX11) -e DISPLAY=${DISPLAY} swipl-mingw

win32:
	docker run -it --rm $(MOUNT) swipl-mingw --win32

win64:
	docker run -it --rm $(MOUNT) swipl-mingw --win64

win:
	docker run -it --rm $(MOUNT) swipl-mingw --win32 x--win64
