SWIFT ?= swift
CLANG_FORMAT ?= clang-format

# C/C++ sources to format/lint
CPP_SOURCES ?= $(shell find Sources/Cxgrammar -type f \( -name '*.h' -o -name '*.c' -o -name '*.cc' \))

.PHONY: build test format format-swift lint lint-swift format-cpp lint-cpp clean

# Default target: build, test, and lint
all: build test lint

# Build the package
build:
	$(SWIFT) build

# Run tests
test:
	$(SWIFT) test

# Format Swift and C/C++ sources
format: format-swift format-cpp

# Format C/C++ bridge sources
format-cpp:
	$(CLANG_FORMAT) -i $(CPP_SOURCES)

# Format Swift sources
format-swift:
	$(SWIFT) format --in-place --recursive .

# Lint Swift and C/C++ sources
lint: lint-swift lint-cpp

# Lint C/C++ bridge formatting
lint-cpp:
	$(CLANG_FORMAT) --dry-run --Werror $(CPP_SOURCES)

# Lint Swift formatting
lint-swift:
	$(SWIFT) format lint --strict --recursive .

# Clean build artifacts
clean:
	$(SWIFT) package clean
	rm -rf .build