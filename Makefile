PACKAGE := $(shell basename $(CURDIR))
export JULIA_PKG_OFFLINE = true
export JULIA_PROJECT = $(CURDIR)
export JULIA_DEPOT_PATH = $(CURDIR)/../jl_depot
export JULIA_NUM_THREADS = 8
#export JULIA_DEBUG=loading
export JULIA_UNIX_IO_DEBUG_LEVEL=0

all: README.md test

JL := ln -sf Manifest.toml.1.6 Manifest.toml; julia
JL15 := ln -sf Manifest.toml.1.5 Manifest.toml; julia15

.PHONY: README.md
README.md:
	julia --project -e "using $(PACKAGE); $(PACKAGE).readme_docs_generate()"

doc:
	cd docs; \
	$(JL) -e "using Documenter, $(PACKAGE); \
	          makedocs(sitename=\"$(PACKAGE)\")"

.PHONY: test
test:
	$(JL) test/runtests.jl
	$(JL15) test/runtests.jl

testpt:
	$(JL) test/pseudoterminal.jl

jl:
	$(JL) -i -e "using $(PACKAGE)"

jl15:
	$(JL15)

jlenv:
	$(JL)

dumb:
	TERM=dumb $(JL) -i -e "using $(PACKAGE)"

.PHONY: db
db: db4
db%:
	touch src/debug_recompile_trigger.jl
	JULIA_UNIX_IO_DEBUG_LEVEL=$* $(JL) -i -e "using $(PACKAGE)"
