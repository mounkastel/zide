.PHONY: test lint fmt install

TEST_SH := $(wildcard tests/t-*.sh)

test:
	tests/run.sh

lint:
	@if command -v shellcheck >/dev/null 2>&1; then \
	  shellcheck -x zide tests/run.sh tests/lib.sh $(TEST_SH); \
	else \
	  echo "SKIP: shellcheck not installed (https://www.shellcheck.net/) — lint not enforced"; \
	fi

fmt:
	@if command -v shfmt >/dev/null 2>&1; then \
	  shfmt -w -i 2 tests/run.sh tests/lib.sh $(TEST_SH); \
	  shfmt -d -i 2 tests/run.sh tests/lib.sh $(TEST_SH); \
	else \
	  echo "SKIP: shfmt not installed (https://github.com/mvdan/sh) — fmt not enforced"; \
	fi

PREFIX ?= $(HOME)/.local

install:
	install -D -m 0755 zide $(PREFIX)/bin/zide
