PACKAGE := $(shell basename $(PWD))

all: README.md test

README.md: src/$(PACKAGE).jl
	julia --project -e "using $(PACKAGE); \
		                println($(PACKAGE).readme())" > $@

.PHONY: test
test: src/$(PACKAGE).jl
	julia --project \
		  --threads 10 \
		  -e "using Pkg; \
              Pkg.test()"
