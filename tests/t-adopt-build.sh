#!/usr/bin/env bash
# --build/--build-system selects (and requires) the build system for adopt,
# and must agree with --lang for init.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

T=$(fresh_dir)
track_tmp "$T"

mkdir -p -- "$T/cmake-proj/src"
cat >"$T/cmake-proj/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.16)
project(bflag LANGUAGES CXX)
add_executable(bflag src/main.cpp)
EOF
printf 'int main() { return 0; }\n' >"$T/cmake-proj/src/main.cpp"

if ! "$ZIDE" adopt "$T/cmake-proj" --no-configure --build cmake >/dev/null 2>&1; then
  tap_not_ok "adopt --build cmake on cmake project"
  exit 1
fi
tap_ok "adopt --build cmake on cmake project"

"$ZIDE" adopt "$T/cmake-proj" --no-configure --build cargo >/dev/null 2>&1
rc=$?
if ((rc == 2)); then tap_ok "adopt --build cargo without Cargo.toml exits 2"; else tap_not_ok "adopt --build cargo without Cargo.toml exits 2 (got $rc)"; fi

mkdir -p -- "$T/bare"
printf 'int main(void) { return 0; }\n' >"$T/bare/main.c"
"$ZIDE" adopt "$T/bare" --no-configure --build cmake >/dev/null 2>&1
rc=$?
if ((rc == 2)); then tap_ok "adopt --build cmake without CMakeLists exits 2"; else tap_not_ok "adopt --build cmake without CMakeLists exits 2 (got $rc)"; fi

if ! "$ZIDE" init "$T/i1" --lang cpp -y --no-configure --no-git --build cmake --author T --year 2024 >/dev/null 2>&1; then
  tap_not_ok "init cpp --build cmake accepted"
  exit 1
fi
tap_ok "init cpp --build cmake accepted"

"$ZIDE" init "$T/i2" --lang cpp -y --no-configure --no-git --build cargo >/dev/null 2>&1
rc=$?
if ((rc == 2)); then tap_ok "init cpp --build cargo exits 2"; else tap_not_ok "init cpp --build cargo exits 2 (got $rc)"; fi

"$ZIDE" init "$T/i3" --lang rust -y --no-git --build cmake >/dev/null 2>&1
rc=$?
if ((rc == 2)); then tap_ok "init rust --build cmake exits 2"; else tap_not_ok "init rust --build cmake exits 2 (got $rc)"; fi
