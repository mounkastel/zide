#!/usr/bin/env bash
# init: C project scaffolds, builds and passes tests.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

T=$(fresh_dir)
track_tmp "$T"

if ! "$ZIDE" init "$T/proj" --lang c --std 17 -y --no-configure --no-git \
  --author "Test Author" --year 2024 >/dev/null 2>&1; then
  tap_not_ok "init c exits 0"
  exit 1
fi
tap_ok "init c exits 0"
if [[ -f $T/proj/src/main.c ]]; then tap_ok "c main exists"; else tap_not_ok "c main exists"; fi

if ! have_tool cmake; then
  tap_skip "c project builds and tests pass" "cmake not installed"
  exit 0
fi
if (cd -- "$T/proj" && cmake --preset dev >/dev/null 2>&1 &&
  cmake --build --preset dev >/dev/null 2>&1 &&
  ctest --preset dev >/dev/null 2>&1); then
  tap_ok "c project builds and tests pass"
else
  tap_not_ok "c project builds and tests pass"
fi
