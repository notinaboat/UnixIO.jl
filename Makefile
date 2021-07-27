PACKAGE := $(shell basename $(PWD))
export JULIA_PKG_OFFLINE = true
export JULIA_PROJECT = $(PWD)
export JULIA_DEPOT_PATH = $(CURDIR)/../jl_depot
export JULIA_NUM_THREADS = 8
export JULIA_UNIX_IO_EXPORT_ALL = 1
export JULIA_DEBUG=loading

all: README.md test

JL := julia

README.md: src/$(PACKAGE).jl
	$(JL) -e "using $(PACKAGE); \
		      println($(PACKAGE).readme())" > $@

.PHONY: test
test:
	JULIA_UNIX_IO_DEBUG_LEVEL=0 $(JL) test/runtests.jl

testptdb:
	JULIA_UNIX_IO_DEBUG_LEVEL=2 $(JL) test/pseudoterminal.jl

testpt:
	$(JL) test/pseudoterminal.jl

jl:
	$(JL) -i -e "using $(PACKAGE)"

dumb:
	TERM=dumb $(JL) -i -e "using $(PACKAGE)"

.PHONY: db
db: db4
db%:
	touch src/debug_recompile_trigger.jl
	JULIA_UNIX_IO_DEBUG_LEVEL=$* $(JL) -i -e "using $(PACKAGE)"
