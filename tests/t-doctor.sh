#!/usr/bin/env bash
# doctor: grouped report, summary line, exit code, --json, pipe-clean output.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

out=$("$ZIDE" doctor 2>/dev/null)
rc=$?

# Exit code must reflect the required set: cmake clangd git cargo rustc.
expected=0
for t in cmake clangd git cargo rustc; do
  if ! have_tool "$t"; then expected=1; fi
  if ! "$t" --version >/dev/null 2>&1; then expected=1; fi
done
if ((rc == expected)); then tap_ok "doctor exit ($rc) reflects required tools"; else tap_not_ok "doctor exit ($rc) reflects required tools"; fi

for group in required recommended optional; do
  if printf '%s\n' "$out" | grep -q "^$group:$"; then tap_ok "doctor has '$group' group"; else tap_not_ok "doctor has '$group' group"; fi
done
if printf '%s\n' "$out" | grep -q "^summary: "; then tap_ok "doctor prints a summary line"; else tap_not_ok "doctor prints a summary line"; fi

# Piped (non-TTY) stdout must carry no escape codes, with or without NO_COLOR.
if printf '%s\n' "$out" | grep -q $'\033'; then tap_not_ok "piped doctor output is plain"; else tap_ok "piped doctor output is plain"; fi
if NO_COLOR=1 "$ZIDE" doctor 2>/dev/null | grep -q $'\033'; then tap_not_ok "NO_COLOR doctor output is plain"; else tap_ok "NO_COLOR doctor output is plain"; fi

if ! have_tool jq; then
  tap_skip "--json is valid JSON" "jq not installed"
  exit 0
fi
json=$("$ZIDE" doctor --json 2>/dev/null)
jrc=$?
if printf '%s\n' "$json" | jq -e . >/dev/null 2>&1; then tap_ok "--json is valid JSON"; else tap_not_ok "--json is valid JSON"; fi
if printf '%s\n' "$json" | jq -e '[.tools[] | select(.tier == "required")] | length == 5' >/dev/null 2>&1; then
  tap_ok "--json lists 5 required tools"
else
  tap_not_ok "--json lists 5 required tools"
fi
if ((jrc == expected)); then tap_ok "--json exit matches text exit"; else tap_not_ok "--json exit matches text exit"; fi

# Per-project scope: tiers follow the detected languages.
T=$(fresh_dir)
track_tmp "$T"
mkdir -p -- "$T/rustonly/src"
printf '[package]\nname = "scoped"\nversion = "0.1.0"\n' >"$T/rustonly/Cargo.toml"
printf 'pub fn add(a: i32, b: i32) -> i32 { a + b }\n' >"$T/rustonly/src/lib.rs"
mkdir -p -- "$T/conly"
printf 'int main(void) { return 0; }\n' >"$T/conly/main.c"
if ! have_tool jq; then tap_skip "per-project tiers" "jq not installed"; else
  tier_cmake_rust=$("$ZIDE" doctor --json "$T/rustonly" 2>/dev/null | jq -r '.tools[] | select(.name=="cmake") | .tier')
  tier_cargo_rust=$("$ZIDE" doctor --json "$T/rustonly" 2>/dev/null | jq -r '.tools[] | select(.name=="cargo") | .tier')
  if [[ $tier_cmake_rust == recommended && $tier_cargo_rust == required ]]; then
    tap_ok "rust project: cmake recommended, cargo required"
  else
    tap_not_ok "rust project: cmake recommended, cargo required"
  fi
  tier_cargo_c=$("$ZIDE" doctor --json "$T/conly" 2>/dev/null | jq -r '.tools[] | select(.name=="cargo") | .tier')
  tier_cmake_c=$("$ZIDE" doctor --json "$T/conly" 2>/dev/null | jq -r '.tools[] | select(.name=="cmake") | .tier')
  if [[ $tier_cargo_c == recommended && $tier_cmake_c == required ]]; then
    tap_ok "c project: cargo recommended, cmake required"
  else
    tap_not_ok "c project: cargo recommended, cmake required"
  fi
  proj=$("$ZIDE" doctor --json "$T/conly" 2>/dev/null | jq -r '.project')
  if [[ $proj == "$T/conly" ]]; then tap_ok "--json reports the scoped project"; else tap_not_ok "--json reports the scoped project"; fi
fi
"$ZIDE" doctor /nonexistent-zide-probe-xyz >/dev/null 2>&1
rc=$?
if ((rc == 2)); then tap_ok "doctor bad path exits 2"; else tap_not_ok "doctor bad path exits 2 (got $rc)"; fi
