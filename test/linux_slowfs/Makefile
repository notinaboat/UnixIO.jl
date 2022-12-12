all: slowfs

FUSE_VERSION := 3.12.0

LIBFUSE := lib/libfuse3.so.$(FUSE_VERSION)
LIBFUSE_PATH := libfuse/build/$(LIBFUSE)

slowfs: slowfs.c $(LIBFUSE_PATH)
	clang -Ilibfuse/include -o slowfs slowfs.c $(LIBFUSE_PATH)

libfuse: 
	git clone \
		--depth 1 --branch fuse-$(FUSE_VERSION) \
		https://github.com/libfuse/libfuse.git

$(LIBFUSE_PATH): libfuse
	cd libfuse && \
	mkdir -p build && \
	cd build && \
	meson .. && \
	ninja $(LIBFUSE) && \
	ninja util/fusermount3

mount: slowfs
	sudo \
	PATH=$(PWD)/libfuse/build/util:$$PATH \
	LD_LIBRARY_PATH=$(PWD)/libfuse/build/lib \
	./slowfs \
		$(realpath ../slowfs_mount) \
		-omodules=subdir,subdir=$(realpath ../slowfs_files) \
		-oallow_other

umount: 
	sudo umount $(realpath ../slowfs_mount)
