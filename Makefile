.PHONY: test test-compat bash50 lint fmt install

TEST_SH := $(wildcard tests/t-*.sh)

# Bash 5.0 interpreter for `test-compat` (oldest supported; contract is Bash 5+).
BASH50_VER = 5.0
BASH50_SRC = $(HOME)/.local/share/zide-dev/bash-$(BASH50_VER)
BASH50_BIN = $(BASH50_SRC)/install/bin/bash

test:
	tests/run.sh

# Run the full suite under Bash 5.0. Resolution order: $BASH_BIN if set, a
# working docker daemon (ubuntu:20.04 ships bash 5.0), a cached local 5.0
# build, else fetch and build 5.0 from GNU source (needs curl + gcc).
test-compat:
	@if [ -n "$(BASH_BIN)" ] && [ -x "$(BASH_BIN)" ]; then \
	  echo "test-compat: using BASH_BIN=$(BASH_BIN)"; \
	  BASH_BIN="$(BASH_BIN)" tests/run.sh; \
	elif docker info >/dev/null 2>&1; then \
	  echo "test-compat: using docker (ubuntu:20.04, bash 5.0)"; \
	  docker run --rm -v "$(PWD):/work" -w /work ubuntu:20.04 \
	    bash -c 'apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq cmake ninja-build gcc g++ git jq make ca-certificates cargo rustc > /dev/null && bash tests/run.sh'; \
	elif [ -x "$(BASH50_BIN)" ]; then \
	  echo "test-compat: using cached $(BASH50_BIN)"; \
	  BASH_BIN="$(BASH50_BIN)" tests/run.sh; \
	else \
	  $(MAKE) bash50 && BASH_BIN="$(BASH50_BIN)" tests/run.sh; \
	fi

bash50: $(BASH50_BIN)

$(BASH50_BIN):
	mkdir -p "$(BASH50_SRC)" && curl -sSL -o "$(BASH50_SRC)/bash-$(BASH50_VER).tar.gz" https://ftp.gnu.org/gnu/bash/bash-$(BASH50_VER).tar.gz \
	&& tar -xzf "$(BASH50_SRC)/bash-$(BASH50_VER).tar.gz" -C "$(BASH50_SRC)" \
	&& mkdir -p "$(BASH50_SRC)/build" \
	&& cd "$(BASH50_SRC)/build" && "$(BASH50_SRC)/bash-$(BASH50_VER)/configure" --prefix="$(BASH50_SRC)/install" --without-bash-malloc CFLAGS="-g -O2 -std=gnu89 -fcommon -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=return-mismatch" \
	&& $(MAKE) -C "$(BASH50_SRC)/build" -j"$$(nproc)" && $(MAKE) -C "$(BASH50_SRC)/build" install

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
