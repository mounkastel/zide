#!/usr/bin/env bash
# Reports: stderr stream, uniform vocabulary, backup listing, dry-run diffs.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

T=$(fresh_dir)
track_tmp "$T"

if ! "$ZIDE" init "$T/proj" --lang cpp -y --no-configure --no-git --author T --year 2024 >"$T/out.txt" 2>"$T/err.txt"; then
  tap_not_ok "setup scaffold exits 0"
  exit 1
fi
tap_ok "setup scaffold exits 0"

# stdout must be empty (data-only); the report lives on stderr.
if [[ ! -s $T/out.txt ]]; then tap_ok "init report goes to stderr (stdout empty)"; else tap_not_ok "init report goes to stderr (stdout empty)"; fi
if grep -q "Scaffold report" "$T/err.txt"; then tap_ok "report found on stderr"; else tap_not_ok "report found on stderr"; fi
if grep -q "  updated : " "$T/err.txt"; then tap_ok "report uses 'updated' vocabulary"; else tap_not_ok "report uses 'updated' vocabulary"; fi
if grep -q "Next steps:" "$T/err.txt"; then tap_ok "next steps hint on stderr"; else tap_not_ok "next steps hint on stderr"; fi

# A forced second run over a locally modified file backs it up and updates it.
printf '# local tweak\n' >>"$T/proj/CMakeLists.txt"
"$ZIDE" init "$T/proj" --lang cpp -y --no-configure --no-git --force --author T --year 2024 >"$T/out2.txt" 2>"$T/err2.txt"
if grep -q "backups: [1-9]" "$T/err2.txt" && grep -q "      b " "$T/err2.txt"; then
  tap_ok "backups counted and listed"
else
  tap_not_ok "backups counted and listed"
fi

# Dry-run shows a plan with diffs and writes nothing.
before=$(tree_state "$T/proj")
if ! "$ZIDE" adopt "$T/proj" --dry-run --no-configure >"$T/dry-out.txt" 2>"$T/dry-err.txt"; then
  tap_not_ok "dry-run exits 0"
  exit 1
fi
tap_ok "dry-run exits 0"
after=$(tree_state "$T/proj")
if [[ $before == "$after" ]]; then tap_ok "dry-run changes nothing"; else tap_not_ok "dry-run changes nothing"; fi
if grep -q "dry run: nothing written" "$T/dry-err.txt"; then tap_ok "dry-run banner on stderr"; else tap_not_ok "dry-run banner on stderr"; fi
if grep -qE '^    (\+|-|@@|[-+][^-+])' "$T/dry-err.txt"; then tap_ok "dry-run shows diff preview"; else tap_not_ok "dry-run shows diff preview"; fi
