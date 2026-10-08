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
