#!/usr/bin/env bash
# adopt is safe by default: no project code executes without --configure.
# Sentinel fixture: CMake configure runs execute_process -> SENTINEL_RAN.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

make_sentinel_fixture() { # <dir>: cmake project whose configure drops a sentinel
  mkdir -p -- "$1/src"
  cat >"$1/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.16)
project(sentinel LANGUAGES C)
execute_process(COMMAND ${CMAKE_COMMAND} -E touch "${CMAKE_CURRENT_SOURCE_DIR}/SENTINEL_RAN")
add_executable(sentinel src/main.c)
EOF
  printf 'int main(void) { return 0; }\n' >"$1/src/main.c"
}

T=$(fresh_dir)
track_tmp "$T"
make_sentinel_fixture "$T/s1"

# 1. Default adopt executes nothing.
if ! "$ZIDE" adopt "$T/s1" >"$T/default.log" 2>&1; then
  tap_not_ok "default adopt exits 0"
  exit 1
fi
tap_ok "default adopt exits 0"
if [[ ! -e $T/s1/SENTINEL_RAN ]]; then tap_ok "default adopt runs no project code"; else tap_not_ok "default adopt runs no project code"; fi
if [[ ! -e $T/s1/compile_commands.json ]]; then tap_ok "no compilation database fabricated"; else tap_not_ok "no compilation database fabricated"; fi
if grep -q -- "--configure" "$T/default.log"; then tap_ok "fallback message explains --configure"; else tap_not_ok "fallback message explains --configure"; fi
if grep -q "degraded code intelligence" "$T/default.log"; then tap_ok "warning states the clangd consequence"; else tap_not_ok "warning states the clangd consequence"; fi
if grep -q "deprecated" "$T/default.log"; then tap_not_ok "no deprecation noise by default"; else tap_ok "no deprecation noise by default"; fi

# 2. Legacy --no-configure keeps working and executes nothing.
if ! "$ZIDE" adopt "$T/s1" --no-configure >"$T/ncflag.log" 2>&1; then
  tap_not_ok "adopt --no-configure exits 0"
  exit 1
fi
tap_ok "adopt --no-configure exits 0"
if [[ $(grep -c "deprecated" "$T/ncflag.log") -eq 1 ]]; then tap_ok "--no-configure warns once"; else tap_not_ok "--no-configure warns once"; fi
if [[ ! -e $T/s1/SENTINEL_RAN ]]; then tap_ok "--no-configure runs no project code"; else tap_not_ok "--no-configure runs no project code"; fi

# 3. --dry-run executes nothing, with or without --configure.
"$ZIDE" adopt "$T/s1" --dry-run >/dev/null 2>&1
if [[ ! -e $T/s1/SENTINEL_RAN ]]; then tap_ok "--dry-run runs no project code"; else tap_not_ok "--dry-run runs no project code"; fi
"$ZIDE" adopt "$T/s1" --dry-run --configure >/dev/null 2>&1
if [[ ! -e $T/s1/SENTINEL_RAN ]]; then tap_ok "--dry-run --configure runs no project code"; else tap_not_ok "--dry-run --configure runs no project code"; fi

# 4. --configure executes (notice first), producing the database.
if ! have_tool cmake; then tap_skip "--configure runs the build" "cmake not installed"; else
  if ! "$ZIDE" adopt "$T/s1" --configure >"$T/conf.log" 2>&1; then
    tap_not_ok "adopt --configure exits 0"
  else
    tap_ok "adopt --configure exits 0"
  fi
  if [[ -e $T/s1/SENTINEL_RAN ]]; then tap_ok "--configure runs the build"; else tap_not_ok "--configure runs the build"; fi
  if grep -q "about to run (in $T/s1): cmake" "$T/conf.log"; then
    tap_ok "pre-execution notice names command and directory"
  else
    tap_not_ok "pre-execution notice names command and directory"
  fi
  if awk '/about to run/{a=NR} /running: cmake/{b=NR} END{exit !(a && b && a<b)}' "$T/conf.log"; then
    tap_ok "notice precedes execution"
  else
    tap_not_ok "notice precedes execution"
  fi
  if [[ -L $T/s1/compile_commands.json ]]; then tap_ok "--configure links compile_commands.json"; else tap_not_ok "--configure links compile_commands.json"; fi
fi

# 5. Wizard defaults to no execution (driven through a pty).
# ZIDE_REQUIRE_PTY=1 (set in CI) turns a missing script(1) into failures.
if ! have_tool script; then
  if [[ -n ${ZIDE_REQUIRE_PTY:-} ]]; then
    tap_not_ok "wizard adopt exits 0 (script(1) missing but required)"
    tap_not_ok "wizard runs no project code by default (script(1) missing but required)"
    tap_not_ok "wizard still writes configuration (script(1) missing but required)"
  else
    tap_skip "wizard adopt exits 0" "script(1) not installed"
    tap_skip "wizard runs no project code by default" "script(1) not installed"
    tap_skip "wizard still writes configuration" "script(1) not installed"
  fi
else
  make_sentinel_fixture "$T/wiz"
  # Style / configure(n) / force(n) / Ready(apply) / do-something-else(n).
  if printf '\n\n\n\n\n' | timeout 120 script -qec "$ZIDE -i adopt $T/wiz" /dev/null >"$T/wiz.log" 2>&1; then
    tap_ok "wizard adopt exits 0"
  else
    tap_not_ok "wizard adopt exits 0"
  fi
  if [[ ! -e $T/wiz/SENTINEL_RAN ]]; then tap_ok "wizard runs no project code by default"; else tap_not_ok "wizard runs no project code by default"; fi
  if [[ -f $T/wiz/.zed/settings.json ]]; then tap_ok "wizard still writes configuration"; else tap_not_ok "wizard still writes configuration"; fi
fi
