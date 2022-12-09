PACKAGE := UnixIO
#export JULIA_PKG_OFFLINE = true
export JULIA_PROJECT = $(CURDIR)
export JULIA_DEPOT_PATH = $(CURDIR)/../jl_depot
export JULIA_NUM_THREADS = 8
#export JULIA_DEBUG=loading
export JULIA_UNIX_IO_DEBUG_LEVEL=0

all: README.md test

#README_DOCS_DIR := $(shell julia --project -e \
#                     "using ReadmeDocs; println(pkgdir(ReadmeDocs))")
README_DOCS_DIR := ../ReadmeDocs

HTTP_ROOT := $(CURDIR)
HTML_TITLE_LINK := https://github.com/notinaboat/UnixIO.jl

#include $(README_DOCS_DIR)/Makefile.shared

HTML_FILES = packages/IOTraits/README.md.html
.PHONY: docs
docs: $(HTML_FILES:%=docs/%)
	cp -a $(README_DOCS_DIR)/css docs

docs/%.html: %.html
	@mkdir -p $(dir $@)
	cp $< $@

docgen:
	while kqwait packages/IOTraits/src/ ; do \
		$(MAKE) docs; \
		osascript -e 'tell application "Safari"' -e \
    		'set docUrl to URL of document 1' -e \
    		'set URL of document 1 to docUrl' -e \
		'end tell' ; \
	done
	
packages/IOTraits/README.md: packages/IOTraits/src/IOTraits.jl.md
	cp $< $@.tmp
#	$(JL) -e "using IOTraits; IOTraits.dump_info()" >> $@.tmp
	mv $@.tmp $@

JL := julia18

.PHONY: README.md
README.md:
	julia --project -e "using $(PACKAGE); $(PACKAGE).readme_docs_generate()"

#doc:
#	cd docs; \
#	$(JL) -e "using Documenter, $(PACKAGE); \
#	          makedocs(sitename=\"$(PACKAGE)\")"

.PHONY: test
test:
	$(JL) test/runtests.jl

testpt:
	$(JL) test/pseudoterminal.jl

jl:
	$(JL) -i -e "using $(PACKAGE)"

revise:
	$(JL) -i -e "using Revise; using $(PACKAGE)"

jlenv:
	$(JL)

dumb:
	TERM=dumb $(JL) -i -e "using $(PACKAGE)"

.PHONY: db
db: db4
db%:
	touch src/debug_recompile_trigger.jl
	JULIA_UNIX_IO_DEBUG_LEVEL=$* $(JL) -i -e "using $(PACKAGE)"
