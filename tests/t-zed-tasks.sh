#!/usr/bin/env bash
# adopt: run/debug tasks carry no shell logic; scripts/zide-run.sh does the work.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

no_shell_tokens() { # <tasks.json> <debug.json>: no shell in command/args
  jq -e '([.[] | .command // empty] + [.[] | .args[]? // empty]
    | map(select(. == "bash" or . == "-c" or contains("&&")
      or contains("||") or contains("[") or contains("]")))
    | length == 0)' -- "$1" >/dev/null \
  && jq -e '([.[] | .command // empty] + [.[] | .args[]? // empty]
    | map(select(. == "bash" or . == "-c" or contains("&&")
      or contains("||") or contains("[") or contains("]")))
    | length == 0)' -- "$2" >/dev/null
}

T=$(fresh_dir)
track_tmp "$T"
P=$T/proj
mkdir -p -- "$P/src"
printf '#include <cstdio>\nint main(){std::printf("hi\\n");return 0;}\n' >"$P/src/main.cpp"
printf 'cmake_minimum_required(VERSION 3.16)\nproject(probe LANGUAGES CXX)\nadd_executable(probe src/main.cpp)\n' >"$P/CMakeLists.txt"

if ! "$ZIDE" adopt "$P" --no-configure >"$T/adopt.log" 2>&1; then
  tap_not_ok "adopt probe fixture exits 0"
  exit 1
fi
tap_ok "adopt probe fixture exits 0"
if ! have_tool jq; then
  tap_skip "no shell logic in generated tasks" "jq not installed"
else
  if no_shell_tokens "$P/.zed/tasks.json" "$P/.zed/debug.json"; then tap_ok "no shell logic in generated tasks"; else tap_not_ok "no shell logic in generated tasks"; fi
  if jq empty "$P/.zed/tasks.json" && jq empty "$P/.zed/debug.json"; then tap_ok "zed files are valid JSON"; else tap_not_ok "zed files are valid JSON"; fi
fi
if [[ -x $P/scripts/zide-run.sh ]]; then tap_ok "scripts/zide-run.sh is executable"; else tap_not_ok "scripts/zide-run.sh is executable"; fi
if [[ $(stat -c '%a' -- "$P/scripts/zide-run.sh") == 755 ]]; then tap_ok "scripts/zide-run.sh is mode 0755"; else tap_not_ok "scripts/zide-run.sh is mode 0755"; fi
if ! have_tool shellcheck; then
  tap_skip "zide-run.sh passes shellcheck" "shellcheck not installed"
elif shellcheck -x "$P/scripts/zide-run.sh"; then
  tap_ok "zide-run.sh passes shellcheck"
else
  tap_not_ok "zide-run.sh passes shellcheck"
fi
"$P/scripts/zide-run.sh" >/dev/null 2>&1
rc=$?
if ((rc == 2)); then tap_ok "script with no argument exits 2"; else tap_not_ok "script with no argument exits 2 (got $rc)"; fi

# Stub cmake: a foreign cache means no -G and no failure; a fresh tree
# passes -G Ninja only when ninja is on PATH.
S=$(fresh_dir)
track_tmp "$S"
mkdir -p -- "$S/fakebin" "$S/stub/build/zide"
# shellcheck disable=SC2016 # the stub script keeps "$@" and "$STUB_LOG" literally
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@" >>"$STUB_LOG"\n' >"$S/fakebin/cmake"
chmod +x "$S/fakebin/cmake"
printf 'CMAKE_GENERATOR:INTERNAL=Unix Makefiles\n' >"$S/stub/build/zide/CMakeCache.txt"
printf '#!/bin/sh\necho stub-exe-ran\n' >"$S/stub/build/zide/app"
chmod +x "$S/stub/build/zide/app"
export STUB_LOG=$S/stub-cmake.log
cp "$P/scripts/zide-run.sh" "$S/stub/zide-run.sh"
if (cd -- "$S/stub" && STUB_LOG=$S/stub-cmake.log PATH="$S/fakebin:$PATH" ./zide-run.sh app >"$S/stub.out" 2>&1); then
  tap_ok "script with a foreign cache exits 0"
else
  tap_not_ok "script with a foreign cache exits 0"
fi
if [[ -f $S/stub-cmake.log ]] && ! grep -q -- '-G' "$S/stub-cmake.log"; then tap_ok "no -G passed with an existing cache"; else tap_not_ok "no -G passed with an existing cache"; fi
if grep -q 'stub-exe-ran' "$S/stub.out"; then tap_ok "script execs the built target"; else tap_not_ok "script execs the built target"; fi
rm -f -- "$S/stub-cmake.log"
mkdir -p -- "$S/fresh/build/zide"
printf '#!/usr/bin/env bash\nexit 0\n' >"$S/fakebin/ninja"
chmod +x "$S/fakebin/ninja"
printf '#!/bin/sh\necho fresh-exe-ran\n' >"$S/fresh/build/zide/app"
chmod +x "$S/fresh/build/zide/app"
cp "$P/scripts/zide-run.sh" "$S/fresh/zide-run.sh"
if (cd -- "$S/fresh" && STUB_LOG=$S/stub-cmake.log PATH="$S/fakebin:$PATH" ./zide-run.sh app >"$S/fresh.out" 2>&1); then
  tap_ok "script on a fresh tree exits 0"
else
  tap_not_ok "script on a fresh tree exits 0"
fi
if grep -qx -- '-G' "$S/stub-cmake.log" && grep -qx 'Ninja' "$S/stub-cmake.log"; then tap_ok "fresh tree passes -G Ninja when ninja exists"; else tap_not_ok "fresh tree passes -G Ninja when ninja exists"; fi

# Real toolchain: adopt, then the script builds and runs the target.
if ! have_tool cmake || ! { have_tool cc || have_tool gcc || have_tool cxx || have_tool g++; }; then
  tap_skip "script builds and runs a real target" "cmake/compiler not installed"
else
  R=$(fresh_dir)
  track_tmp "$R"
  mkdir -p -- "$R/real/src"
  printf '#include <cstdio>\nint main(){std::printf("real-ok\\n");return 0;}\n' >"$R/real/src/main.cpp"
  printf 'cmake_minimum_required(VERSION 3.16)\nproject(real LANGUAGES CXX)\nadd_executable(real src/main.cpp)\n' >"$R/real/CMakeLists.txt"
  "$ZIDE" adopt "$R/real" --no-configure >/dev/null 2>&1
  if (cd -- "$R/real" && ./scripts/zide-run.sh real >"$R/real.out" 2>&1); then
    tap_ok "script builds a real target"
  else
    tap_not_ok "script builds a real target"
  fi
  if grep -q 'real-ok' "$R/real.out"; then tap_ok "real executable runs"; else tap_not_ok "real executable runs"; fi
fi

# Re-adopt is idempotent; a user edit survives without --force only.
before=$(cat -- "$P/scripts/zide-run.sh")
"$ZIDE" adopt "$P" --no-configure >/dev/null 2>&1
after=$(cat -- "$P/scripts/zide-run.sh")
if [[ $before == "$after" ]]; then tap_ok "re-adopt leaves the script unchanged"; else tap_not_ok "re-adopt leaves the script unchanged"; fi
printf '# local tweak\n' >>"$P/scripts/zide-run.sh"
"$ZIDE" adopt "$P" --no-configure >/dev/null 2>&1
if grep -q 'local tweak' "$P/scripts/zide-run.sh"; then tap_ok "user-modified script kept without --force"; else tap_not_ok "user-modified script kept without --force"; fi
"$ZIDE" adopt "$P" --force >/dev/null 2>&1
if grep -q 'local tweak' "$P/scripts/zide-run.sh"; then tap_not_ok "script restored with --force"; else tap_ok "script restored with --force"; fi

# Dry-run writes nothing and lists the script in the plan.
D=$(fresh_dir)
track_tmp "$D"
mkdir -p -- "$D/dry/src"
printf 'int main(){return 0;}\n' >"$D/dry/src/main.cpp"
printf 'cmake_minimum_required(VERSION 3.16)\nproject(dry LANGUAGES CXX)\nadd_executable(dry src/main.cpp)\n' >"$D/dry/CMakeLists.txt"
if ! "$ZIDE" adopt "$D/dry" --dry-run >"$D/dry.log" 2>&1; then
  tap_not_ok "dry-run exits 0"
  exit 1
fi
tap_ok "dry-run exits 0"
if [[ ! -e $D/dry/scripts/zide-run.sh ]]; then tap_ok "dry-run writes no script"; else tap_not_ok "dry-run writes no script"; fi
if grep -q 'scripts/zide-run.sh' "$D/dry.log"; then tap_ok "dry-run lists the script in the plan"; else tap_not_ok "dry-run lists the script in the plan"; fi
