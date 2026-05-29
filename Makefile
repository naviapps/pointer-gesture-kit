SWIFT_FORMAT_PATHS := Sources Tests Package.swift
SWIFT_TEST_FLAGS := -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
SWIFT_BUILD_FLAGS := $(SWIFT_TEST_FLAGS)
SWIFT_DOCC_MODULES := PointerGestureKit PointerGestureKitCoreGraphics
SWIFT_DOCC_OUTPUT_DIR := .build/docc
SWIFT_DOCC_BUNDLE_VERSION := 1.0.0
SWIFT_SYMBOL_GRAPH_DIR := .build/$(shell swift -print-target-info | awk -F\" '/"unversionedTriple"/ { print $$4; exit }')/symbolgraph

.DEFAULT_GOAL := help

.PHONY: help check format lint test build docc

help:
	@awk -F: '/^[a-zA-Z0-9_-]+:/ { print $$1 }' $(MAKEFILE_LIST)

check: lint test build docc

format:
	swift format format --recursive --in-place $(SWIFT_FORMAT_PATHS)

lint:
	swift format lint --recursive --strict $(SWIFT_FORMAT_PATHS)

test:
	swift test $(SWIFT_TEST_FLAGS)

build:
	swift build $(SWIFT_BUILD_FLAGS)

docc: build
	@mkdir -p $(SWIFT_DOCC_OUTPUT_DIR)
	swift package dump-symbol-graph --minimum-access-level public
	@for module in $(SWIFT_DOCC_MODULES); do \
		xcrun docc convert Sources/$$module/$$module.docc \
			--additional-symbol-graph-dir $(SWIFT_SYMBOL_GRAPH_DIR) \
			--output-dir $(SWIFT_DOCC_OUTPUT_DIR)/$$module.doccarchive \
			--fallback-display-name $$module \
			--fallback-bundle-identifier com.naviapps.$$module \
			--fallback-bundle-version $(SWIFT_DOCC_BUNDLE_VERSION) \
			--warnings-as-errors || exit $$?; \
	done
