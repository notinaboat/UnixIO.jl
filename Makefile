PACKAGE := $(shell basename $(PWD))
export JULIA_PKG_OFFLINE = true
export JULIA_DEPOT_PATH = $(CURDIR)/../jl_depot
export JULIA_NUM_THREADS = 8
export JULIA_UNIX_IO_EXPORT_ALL = 1

all: README.md test

JL := julia --project

README.md: src/$(PACKAGE).jl
	$(JL) -e "using $(PACKAGE); \
		      println($(PACKAGE).readme())" > $@

.PHONY: test
test:
	$(JL) test/runtests.jl

testpt:
	$(JL) test/pseudoterminal.jl

jl:
	$(JL) -i -e "using $(PACKAGE)"

.PHONY: db
db: db4
db%:
	touch src/debug_recompile_trigger.jl
	JULIA_UNIX_IO_DEBUG_LEVEL=$* $(JL) -i -e "using $(PACKAGE)"
