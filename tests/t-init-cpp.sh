#!/usr/bin/env bash
# init: C++ project scaffolds, configures, builds and passes tests.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

T=$(fresh_dir)
track_tmp "$T"

"$ZIDE" init "$T/proj" --lang cpp -y --no-configure --no-git \
  --author "Test Author" --year 2024 >/dev/null 2>&1
rc=$?
if ((rc != 0)); then
  tap_not_ok "init cpp exits 0"
  exit 1
fi
tap_ok "init cpp exits 0"

for f in CMakeLists.txt CMakePresets.json .zed/settings.json .zed/tasks.json \
  .zed/debug.json .clangd .clang-format .clang-tidy src/main.cpp tests/test_main.cpp; do
  if [[ -f $T/proj/$f ]]; then tap_ok "scaffold contains $f"; else tap_not_ok "scaffold contains $f"; fi
done

if ! have_tool cmake || ! have_tool ctest; then
  tap_skip "configure+build+ctest" "cmake/ctest not installed"
  exit 0
fi
if (cd -- "$T/proj" && cmake --preset dev >/dev/null 2>&1 &&
  cmake --build --preset dev >/dev/null 2>&1 &&
  ctest --preset dev >/dev/null 2>&1); then
  tap_ok "cmake preset dev configures, builds and tests pass"
else
  tap_not_ok "cmake preset dev configures, builds and tests pass"
fi

# gtest selection falls back to the smoke test when GTest is absent.
T2=$(fresh_dir)
track_tmp "$T2"
"$ZIDE" init "$T2/g" --lang cpp -y --no-configure --no-git --test gtest \
  --author "Test Author" --year 2024 >/dev/null 2>&1
if ! have_tool cmake; then
  tap_skip "gtest-fallback project builds" "cmake not installed"
  exit 0
fi
if (cd -- "$T2/g" && cmake --preset dev >/dev/null 2>&1 &&
  cmake --build --preset dev >/dev/null 2>&1 &&
  ctest --preset dev >/dev/null 2>&1); then
  tap_ok "gtest-selected project builds (system GTest or smoke fallback)"
else
  tap_not_ok "gtest-selected project builds (system GTest or smoke fallback)"
fi
