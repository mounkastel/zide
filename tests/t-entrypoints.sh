#!/usr/bin/env bash
# adopt: one CMake target per file with main(); gaps reported for existing CMakeLists.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

entry_fixture() { # <dir>: two mains, one main-less source, one commented main, one header
  mkdir -p -- "$1/lab1" "$1/lab2"
  printf 'int main() { return 0; }\n' >"$1/lab1/a.cpp"
  printf 'int helper() { return 1; }\n' >"$1/lab1/b.cpp"
  printf 'int main(void) { return 0; }\n' >"$1/lab2/c.c"
  printf '/*\nint main() { return 0; }\n*/\nint x = 1;\n' >"$1/lab2/comment.cpp"
  printf '#pragma once\nint shared();\n' >"$1/util.h"
}

T=$(fresh_dir)
track_tmp "$T"
entry_fixture "$T/fx"

if ! "$ZIDE" adopt "$T/fx" --no-configure >"$T/adopt.log" 2>&1; then
  tap_not_ok "adopt entry-point fixture exits 0"
  exit 1
fi
tap_ok "adopt entry-point fixture exits 0"
n=$(grep -c '^add_executable(' "$T/fx/CMakeLists.txt")
if ((n == 2)); then tap_ok "generated CMakeLists has exactly two targets"; else tap_not_ok "generated CMakeLists has exactly two targets (got $n)"; fi
if grep -q '^add_executable(lab1_a lab1/a.cpp)$' "$T/fx/CMakeLists.txt"; then tap_ok "lab1/a.cpp becomes lab1_a"; else tap_not_ok "lab1/a.cpp becomes lab1_a"; fi
if grep -q '^add_executable(lab2_c lab2/c.c)$' "$T/fx/CMakeLists.txt"; then tap_ok "lab2/c.c becomes lab2_c"; else tap_not_ok "lab2/c.c becomes lab2_c"; fi
if grep -E '^add_executable\(' "$T/fx/CMakeLists.txt" | grep -q 'comment'; then tap_not_ok "commented main is not a target"; else tap_ok "commented main is not a target"; fi
if grep -qF 'CMake targets: 2 (one per file with main())' "$T/adopt.log"; then tap_ok "adopt prints the target summary"; else tap_not_ok "adopt prints the target summary"; fi

# A hand-written CMakeLists is never modified; uncovered entry points are reported.
H=$(fresh_dir)
track_tmp "$H"
entry_fixture "$H/hand"
cat >"$H/hand/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.16)
project(hand LANGUAGES CXX)
add_executable(app lab1/a.cpp)
EOF
before=$(cat -- "$H/hand/CMakeLists.txt")
if ! "$ZIDE" adopt "$H/hand" --force >"$H/hand.log" 2>&1; then
  tap_not_ok "adopt hand-written cmake project exits 0"
  exit 1
fi
tap_ok "adopt hand-written cmake project exits 0"
after=$(cat -- "$H/hand/CMakeLists.txt")
if [[ $before == "$after" ]]; then tap_ok "existing CMakeLists left byte-identical under --force"; else tap_not_ok "existing CMakeLists left byte-identical under --force"; fi
if grep -qF 'It builds 1 of 2 files with main().' "$H/hand.log"; then tap_ok "report counts covered entry points"; else tap_not_ok "report counts covered entry points"; fi
if grep -q 'lab2/c.c' "$H/hand.log"; then tap_ok "report lists lab2/c.c as not included"; else tap_not_ok "report lists lab2/c.c as not included"; fi
if grep -q 'comment.cpp' "$H/hand.log"; then tap_not_ok "non-entry file absent from the gap list"; else tap_ok "non-entry file absent from the gap list"; fi

# Colliding names get distinct targets.
C=$(fresh_dir)
track_tmp "$C"
printf 'int main() { return 0; }\n' >"$C/a-b.cpp"
printf 'int main() { return 0; }\n' >"$C/a_b.cpp"
"$ZIDE" adopt "$C" --no-configure >"$C/collide.log" 2>&1
names=$(grep -oE '^add_executable\([A-Za-z0-9_]+' "$C/CMakeLists.txt" | sed -E 's/^add_executable\(//' | LC_ALL=C sort -u | wc -l)
if ((names == 2)); then tap_ok "colliding sources get distinct target names"; else tap_not_ok "colliding sources get distinct target names"; fi
if grep -q 'avoids a name collision' "$C/collide.log"; then tap_ok "collision rename is reported"; else tap_not_ok "collision rename is reported"; fi

# Determinism: identical inputs in different dirs give identical files.
D1=$(fresh_dir)
track_tmp "$D1"
D2=$(fresh_dir)
track_tmp "$D2"
entry_fixture "$D1/a"
entry_fixture "$D2/a"
"$ZIDE" adopt "$D1/a" --no-configure >/dev/null 2>&1
"$ZIDE" adopt "$D2/a" --no-configure >/dev/null 2>&1
if cmp -s -- "$D1/a/CMakeLists.txt" "$D2/a/CMakeLists.txt"; then
  tap_ok "two adopts produce identical CMakeLists.txt"
else
  tap_not_ok "two adopts produce identical CMakeLists.txt"
fi

# Every generated target builds into an executable when a toolchain exists.
if ! have_tool cmake || ! { have_tool cc || have_tool gcc || have_tool cxx || have_tool g++; }; then
  tap_skip "every target builds an executable" "cmake/compiler not installed"
else
  B=$(fresh_dir)
  track_tmp "$B"
  entry_fixture "$B/bld"
  "$ZIDE" adopt "$B/bld" --no-configure >/dev/null 2>&1
  if (cd -- "$B/bld" && cmake -S . -B build >/dev/null 2>&1 && cmake --build build >/dev/null 2>&1); then
    all_ok=1
    while IFS= read -r t; do
      if [[ -x $B/bld/build/$t ]]; then tap_ok "target $t produces an executable"; else tap_not_ok "target $t produces an executable"; all_ok=0; fi
    done < <(grep -oE '^add_executable\([A-Za-z0-9_]+' "$B/bld/CMakeLists.txt" | sed -E 's/^add_executable\(//')
    ((all_ok)) || exit 1
  else
    tap_not_ok "generated project configures and builds"
  fi
fi

# Dry-run plans the targets and writes nothing.
R=$(fresh_dir)
track_tmp "$R"
entry_fixture "$R/dry"
if ! "$ZIDE" adopt "$R/dry" --dry-run >"$R/dry.log" 2>&1; then
  tap_not_ok "dry-run exits 0"
  exit 1
fi
tap_ok "dry-run exits 0"
if grep -qF 'CMake targets: 2 (one per file with main())' "$R/dry.log"; then tap_ok "dry-run prints the planned targets"; else tap_not_ok "dry-run prints the planned targets"; fi
if [[ ! -e $R/dry/CMakeLists.txt ]]; then tap_ok "dry-run writes no CMakeLists.txt"; else tap_not_ok "dry-run writes no CMakeLists.txt"; fi
