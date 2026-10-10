#!/usr/bin/env bash
# adopt: run/debug entries cover every CMake executable target (no 24-cap).
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

many_fixture() { # <dir> <count>: <count> independent mains, zero-padded names
  mkdir -p -- "$1/src"
  local i
  for ((i = 0; i < $2; i++)); do
    printf 'int main() { return %d; }\n' "$i" >"$1/src/m$(printf '%02d' "$i").cpp"
  done
}

T=$(fresh_dir)
track_tmp "$T"
many_fixture "$T/many" 30

if ! "$ZIDE" adopt "$T/many" --no-configure >"$T/adopt.log" 2>&1; then
  tap_not_ok "adopt 30-target fixture exits 0"
  exit 1
fi
tap_ok "adopt 30-target fixture exits 0"
n_run=$(grep -c '"label": "run: ' "$T/many/.zed/tasks.json")
if ((n_run == 30)); then tap_ok "tasks.json holds 30 run entries"; else tap_not_ok "tasks.json holds 30 run entries (got $n_run)"; fi
n_dbg=$(grep -c '"label": "Debug ' "$T/many/.zed/debug.json")
if ((n_dbg == 60)); then tap_ok "debug.json holds 60 debug entries"; else tap_not_ok "debug.json holds 60 debug entries (got $n_dbg)"; fi
all_once=1
for t in src_m00 src_m15 src_m29; do
  if (( $(grep -c "\"label\": \"run: $t\"" "$T/many/.zed/tasks.json") != 1 )); then all_once=0; fi
  if (( $(grep -c "Debug $t (CodeLLDB)" "$T/many/.zed/debug.json") != 1 )); then all_once=0; fi
  if (( $(grep -c "Debug $t (GDB)" "$T/many/.zed/debug.json") != 1 )); then all_once=0; fi
done
if ((all_once)); then tap_ok "each target appears exactly once per entry kind"; else tap_not_ok "each target appears exactly once per entry kind"; fi
if grep -q 'first 24' "$T/adopt.log"; then tap_not_ok "no truncation warning on stderr"; else tap_ok "no truncation warning on stderr"; fi
if grep -qF 'run/debug entries: 30 executable targets' "$T/adopt.log"; then tap_ok "entry count line printed"; else tap_not_ok "entry count line printed"; fi

# The same counts hold through --configure when a toolchain exists.
if ! have_tool cmake || ! { have_tool cc || have_tool gcc || have_tool cxx || have_tool g++; }; then
  tap_skip "configure path keeps all 30 targets" "cmake/compiler not installed"
else
  C=$(fresh_dir)
  track_tmp "$C"
  many_fixture "$C/conf" 30
  if "$ZIDE" adopt "$C/conf" --configure >/dev/null 2>&1; then
    tap_ok "adopt --configure exits 0"
  else
    tap_not_ok "adopt --configure exits 0"
  fi
  n_run=$(grep -c '"label": "run: ' "$C/conf/.zed/tasks.json")
  if ((n_run == 30)); then tap_ok "configure path keeps all 30 run entries"; else tap_not_ok "configure path keeps all 30 run entries (got $n_run)"; fi
fi

# Re-adopting adds no duplicates.
"$ZIDE" adopt "$T/many" --no-configure >/dev/null 2>&1
n_run=$(grep -c '"label": "run: ' "$T/many/.zed/tasks.json")
n_dbg=$(grep -c '"label": "Debug ' "$T/many/.zed/debug.json")
if ((n_run == 30 && n_dbg == 60)); then tap_ok "re-adopt adds no duplicate entries"; else tap_not_ok "re-adopt adds no duplicate entries ($n_run run, $n_dbg debug)"; fi

# A user-provided debug entry wins; the rest are added alongside it.
U=$(fresh_dir)
track_tmp "$U"
many_fixture "$U/user" 30
mkdir -p -- "$U/user/.zed"
cat >"$U/user/.zed/debug.json" <<'EOF'
[
  {
    "label": "Debug src_m05 (GDB)",
    "adapter": "GDB",
    "request": "launch",
    "program": "my-custom-program",
    "cwd": "$ZED_WORKTREE_ROOT"
  }
]
EOF
"$ZIDE" adopt "$U/user" --no-configure >/dev/null 2>&1
if grep -q 'my-custom-program' "$U/user/.zed/debug.json"; then tap_ok "user debug entry kept"; else tap_not_ok "user debug entry kept"; fi
n_dbg=$(grep -c '"label": "Debug ' "$U/user/.zed/debug.json")
if ((n_dbg == 60)); then tap_ok "remaining debug entries added around it"; else tap_not_ok "remaining debug entries added around it (got $n_dbg)"; fi

# Zero executable targets: the fallback guess path is unchanged.
Z=$(fresh_dir)
track_tmp "$Z"
mkdir -p -- "$Z/onlylib"
printf 'cmake_minimum_required(VERSION 3.16)\nproject(onlylib)\n' >"$Z/onlylib/CMakeLists.txt"
printf 'int helper() { return 1; }\n' >"$Z/onlylib/helper.c"
if ! "$ZIDE" adopt "$Z/onlylib" --no-configure >"$Z/zero.log" 2>&1; then
  tap_not_ok "adopt zero-target fixture exits 0"
  exit 1
fi
tap_ok "adopt zero-target fixture exits 0"
if grep -q 'no add_executable target detected' "$Z/zero.log"; then tap_ok "fallback warning unchanged"; else tap_not_ok "fallback warning unchanged"; fi
if grep -q '"label": "run: onlylib"' "$Z/onlylib/.zed/tasks.json"; then tap_ok "guessed run entry unchanged"; else tap_not_ok "guessed run entry unchanged"; fi

# Dry-run writes nothing and prints the planned entry count.
R=$(fresh_dir)
track_tmp "$R"
many_fixture "$R/dry" 30
if ! "$ZIDE" adopt "$R/dry" --dry-run >"$R/dry.log" 2>&1; then
  tap_not_ok "dry-run exits 0"
  exit 1
fi
tap_ok "dry-run exits 0"
if grep -qF 'run/debug entries: 30 executable targets' "$R/dry.log"; then tap_ok "dry-run prints the planned entry count"; else tap_not_ok "dry-run prints the planned entry count"; fi
if [[ ! -e $R/dry/.zed/tasks.json && ! -e $R/dry/.zed/debug.json ]]; then tap_ok "dry-run writes no zed files"; else tap_not_ok "dry-run writes no zed files"; fi

# Both files are valid JSON.
if ! have_tool jq; then
  tap_skip "zed files are valid JSON" "jq not installed"
else
  if jq empty "$T/many/.zed/tasks.json" && jq empty "$T/many/.zed/debug.json"; then
    tap_ok "zed files are valid JSON"
  else
    tap_not_ok "zed files are valid JSON"
  fi
fi
