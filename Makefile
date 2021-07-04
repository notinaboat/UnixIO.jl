PACKAGE := $(shell basename $(PWD))

all: README.md test

README.md: src/$(PACKAGE).jl
	julia --project -e "using $(PACKAGE); \
		                println($(PACKAGE).readme())" > $@

test: src/$(PACKAGE).jl
	julia --project -e "using Pkg; \
		                Pkg.test()"
