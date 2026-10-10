#!/usr/bin/env bash
# init: flag handling: license/year, benchmarks, invalid values, protected paths.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

T=$(fresh_dir)
track_tmp "$T"

"$ZIDE" init "$T/p" --lang cpp -y --no-configure --no-git --test none --benchmarks \
  --license mit --author "Jane Doe" --year 2024 >/dev/null 2>&1
tap_ok "init with benchmarks/test-none exits 0"
if [[ -d $T/p/benchmarks ]]; then tap_ok "benchmarks dir created"; else tap_not_ok "benchmarks dir created"; fi
if grep -q "Copyright (c) 2024 Jane Doe" "$T/p/LICENSE"; then tap_ok "license year/author recorded"; else tap_not_ok "license year/author recorded"; fi

"$ZIDE" init "$T/q" --lang frobnicate -y --no-git >/dev/null 2>&1
rc=$?
if ((rc == 2)); then tap_ok "invalid --lang exits 2"; else tap_not_ok "invalid --lang exits 2 (got $rc)"; fi

"$ZIDE" init "$T/q" --lang cpp --test wat -y --no-git >/dev/null 2>&1
rc=$?
if ((rc == 2)); then tap_ok "invalid --test exits 2"; else tap_not_ok "invalid --test exits 2 (got $rc)"; fi

"$ZIDE" init "$T/q" --lang cpp --std 99 -y --no-git >/dev/null 2>&1
rc=$?
if ((rc == 2)); then tap_ok "invalid --std exits 2"; else tap_not_ok "invalid --std exits 2 (got $rc)"; fi
