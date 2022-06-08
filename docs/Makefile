# # docs/Makefile
#
# - Copy the latest files from src dirs.
# - Build documentation.

THIS_MAKEFILE := $(lastword $(MAKEFILE_LIST))
THIS_MAKEFILE_DIR := $(realpath $(dir $(THIS_MAKEFILE)))

include ../
.PHONY: build
build:
	@cd $< ; \
		echo "Building: `pwd`" ; \
		make html ; \
		for f in `find . -name README.html`; do \
			cp $$f `echo $$f | sed 's/README.html/index.html/g'` ; \
		done
	@$(RSYNC) $</ $*/
	$(GIT) add $*
	$(GIT) diff --cached --quiet $* || \
		$(GIT) commit -m "$*: $(shell cd $< ; $(GIT) describe --tags)"


RSYNC := rsync \
	--archive \
	--verbose \
	--max-size 10m \
	--exclude '*.sysimage' \
	--exclude 'log' \
	--exclude 'jl_depot' \
	--exclude 'gerber' \
	--exclude '.*' \
	--delete


clean:
	rm -rf $(REPOS) $(REPO_TAGS) repos
