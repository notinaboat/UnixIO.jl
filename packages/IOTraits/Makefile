PACKAGE := $(shell basename $(CURDIR))
#export JULIA_PKG_OFFLINE = true
export JULIA_PROJECT = $(CURDIR)
export JULIA_DEPOT_PATH = $(CURDIR)/../../../jl_depot
export JULIA_NUM_THREADS = 8
#export JULIA_DEBUG=loading
export JULIA_UNIX_IO_DEBUG_LEVEL=0

all: README.md test

JL := julia

.PHONY: README.md
README.md: src/IOTraits.jl.md
	cp $< $@

#	julia --project -e "using $(PACKAGE); $(PACKAGE).readme_docs_generate()"

doc:
	cd docs; \
	$(JL) -e "using Documenter, $(PACKAGE); \
	          makedocs(sitename=\"$(PACKAGE)\")"

.PHONY: test
test:
	$(JL) test/runtests.jl

testpt:
	$(JL) test/pseudoterminal.jl

jl:
	$(JL) -i -e "using $(PACKAGE)"

jlenv:
	$(JL)

README_DOCS_DIR := $(shell julia --project -e \
                     "using ReadmeDocs; println(pkgdir(ReadmeDocs))")

JL2MD := $(JL) $(README_DOCS_DIR)/src/jl_to_md.jl

%.jl.md: %.jl
	$(JL2MD) $<
