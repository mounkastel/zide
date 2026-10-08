#!/usr/bin/env bash
# adopt: project without any build system gets a generated CMakeLists (or not).
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

T=$(fresh_dir)
track_tmp "$T"
mkdir -p -- "$T/bare"
printf 'int main(void) { return 0; }\n' >"$T/bare/main.c"

if ! "$ZIDE" adopt "$T/bare" --no-configure >/dev/null 2>&1; then
  tap_not_ok "adopt bare project exits 0"
  exit 1
fi
tap_ok "adopt bare project exits 0"
if grep -q "add_executable" "$T/bare/CMakeLists.txt"; then tap_ok "CMakeLists.txt generated from sources"; else tap_not_ok "CMakeLists.txt generated from sources"; fi

mkdir -p -- "$T/bare2"
printf 'int main(void) { return 0; }\n' >"$T/bare2/main.c"
"$ZIDE" adopt "$T/bare2" --no-configure --no-cmake >/dev/null 2>&1
if [[ ! -e $T/bare2/CMakeLists.txt ]]; then
  tap_ok "--no-cmake skips CMakeLists generation"
else
  tap_not_ok "--no-cmake skips CMakeLists generation"
fi
