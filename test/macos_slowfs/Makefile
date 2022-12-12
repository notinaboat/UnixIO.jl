# Based on: https://github.com/osxfuse/filesystems/blob/master/filesystems-c/loopback/Makefile
TARGETS = slowfs

# Root for OSXFUSE includes and libraries
OSXFUSE_ROOT = /usr/local

INCLUDE_DIR = $(OSXFUSE_ROOT)/include/osxfuse/fuse
LIBRARY_DIR = $(OSXFUSE_ROOT)/lib

CC ?= clang

CFLAGS_OSXFUSE = -I$(INCLUDE_DIR) -L$(LIBRARY_DIR)
CFLAGS_OSXFUSE += -D_FILE_OFFSET_BITS=64
CFLAGS_OSXFUSE += -D_DARWIN_USE_64_BIT_INODE

CFLAGS_EXTRA = -Wall -g $(CFLAGS)

LIBS = -lfuse

.c:
	$(CC) $(CFLAGS_OSXFUSE) $(CFLAGS_EXTRA) -o $@ $< $(LIBS)

all: info

slowfs: slowfs.c

info: $(TARGETS)
	@echo
	@echo Compiled. The following is a typical way to run the slowfs file system. In
	@echo this example, /tmp/dir is an existing directory whose contents will become
	@echo available in the existing mount point /Volumes/loop:
	@echo
	@echo "sudo ./slowfs /Volumes/slowfs -omodules=threadid:subdir,subdir=/tmp/dir -oallow_other,native_xattr,volname=LoopbackFS -onoubc"
	@echo

mount: slowfs
	./slowfs $(realpath ../slowfs_mount) \
		-omodules=threadid:subdir,subdir=$(PWD)/../slowfs_files \
		-oallow_other,native_xattr,volname=SlowFS \
		-onoubc

umount: 
	umount $(realpath ../slowfs_mount)

clean:
	rm -f $(TARGETS) *.o
	rm -rf *.dSYM
