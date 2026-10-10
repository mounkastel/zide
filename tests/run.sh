#!/usr/bin/env bash
# tests/run.sh: minimal TAP runner that executes tests/t-*.sh and tallies results.
set -u

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
files=("$root"/tests/t-*.sh)
# Compat mode: BASH_BIN points at the interpreter under test (see `make test-compat`).
RUN_BASH=${BASH_BIN:-bash}
printf 'runner: %s\n' "$("$RUN_BASH" --version | head -n 1)"
total_ok=0
total_bad=0
total_skip=0
failed_files=()

for t in "${files[@]}"; do
  name=$(basename -- "$t")
  printf '=== %s ===\n' "$name"
  out=$("$RUN_BASH" "$t" 2>&1)
  rc=$?
  printf '%s\n' "$out"
  n_ok=$(printf '%s\n' "$out" | grep -c '^ok ')
  n_bad=$(printf '%s\n' "$out" | grep -c '^not ok ')
  n_skip=$(printf '%s\n' "$out" | grep -c '# SKIP')
  total_ok=$((total_ok + n_ok))
  total_bad=$((total_bad + n_bad))
  total_skip=$((total_skip + n_skip))
  if ((rc != 0 || n_bad > 0)); then failed_files+=("$name(rc=$rc)") total_bad=$((total_bad + 1)); fi
done

printf '\n----------------------------------------\n'
printf 'passed: %d  failed: %d  skipped: %d\n' "$total_ok" "$total_bad" "$total_skip"
if ((${#failed_files[@]})); then
  printf 'FAILURES in: %s\n' "${failed_files[*]}"
  exit 1
fi
printf 'ALL GREEN\n'
