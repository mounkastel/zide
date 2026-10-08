#!/usr/bin/env bash
# init: mixed C/C++ project scaffolds, builds and passes tests.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

T=$(fresh_dir)
track_tmp "$T"

if ! "$ZIDE" init "$T/proj" --lang c-cpp-mixed -y --no-configure --no-git --test catch2 \
  --author "Test Author" --year 2024 >/dev/null 2>&1; then
  tap_not_ok "init mixed exits 0"
  exit 1
fi
tap_ok "init mixed exits 0"
if [[ $(compgen -G "$T/proj/src/*_c.c" | wc -l) -eq 1 && -f $T/proj/src/proj.cpp ]]; then tap_ok "mixed has C and C++ sources"; else tap_not_ok "mixed has C and C++ sources"; fi

if ! have_tool cmake; then
  tap_skip "mixed project builds and tests pass" "cmake not installed"
  exit 0
fi
if (cd -- "$T/proj" && cmake --preset dev >/dev/null 2>&1 &&
  cmake --build --preset dev >/dev/null 2>&1 &&
  ctest --preset dev >/dev/null 2>&1); then
  tap_ok "mixed project builds and tests pass"
else
  tap_not_ok "mixed project builds and tests pass"
fi
