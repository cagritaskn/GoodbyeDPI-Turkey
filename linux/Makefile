# Linux build entrypoint for GoodbyeDPI-Turkey.
#
# All the heavy lifting (cloning byedpi, compiling ciadpi, copying the binary
# into ./bin/) lives in build.sh. This Makefile is a thin convenience wrapper
# so that the same `make` muscle memory works for users coming from src/.

SHELL := /bin/bash

.PHONY: default all build clean check test help

default: build
all: build

build:
	@./build.sh

clean:
	@rm -rf bin
	@if [ -d third_party/byedpi ]; then \
	    $(MAKE) -C third_party/byedpi clean || true; \
	fi

check:
	@if [ ! -x tests/static-checks.sh ]; then \
	    echo "[make] check failed: tests/static-checks.sh is missing or not executable" >&2; \
	    exit 1; \
	fi
	@./tests/static-checks.sh

test:
	@if [ ! -x tests/lib-test.sh ]; then \
	    echo "[make] test failed: tests/lib-test.sh is missing or not executable" >&2; \
	    exit 1; \
	fi
	@./tests/lib-test.sh

help:
	@echo "Targets:"
	@echo "  make build   - fetch byedpi (if needed) and compile ciadpi into ./bin/"
	@echo "  make clean   - remove ./bin and clean the vendored byedpi build outputs"
	@echo "  make check   - run the shell static checks (./tests/static-checks.sh)"
	@echo "  make test    - run the library tests (./tests/lib-test.sh)"
