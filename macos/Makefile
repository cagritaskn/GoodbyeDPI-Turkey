# macOS build entrypoint for GoodbyeDPI-Turkey.
#
# All the heavy lifting (cloning byedpi, compiling ciadpi, copying the binary
# into ./bin/) lives in build.sh. This Makefile is a thin convenience wrapper
# so that the same `make` muscle memory works for users coming from src/.

SHELL := /bin/bash

.PHONY: default all build clean help

default: build
all: build

build:
	@./build.sh

clean:
	@rm -rf bin
	@if [ -d third_party/byedpi ]; then \
	    $(MAKE) -C third_party/byedpi clean || true; \
	fi

help:
	@echo "Targets:"
	@echo "  make build   - fetch byedpi (if needed) and compile ciadpi into ./bin/"
	@echo "  make clean   - remove ./bin and clean the vendored byedpi build outputs"
