#!/usr/bin/env bash
# --dry-run changes nothing; re-running is idempotent; output is deterministic.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

T=$(fresh_dir)
track_tmp "$T"

if ! "$ZIDE" init "$T/proj" --lang cpp -y --no-configure --no-git \
  --author "Test Author" --year 2024 >/dev/null 2>&1; then
  tap_not_ok "setup scaffold exits 0"
  exit 1
fi
tap_ok "setup scaffold exits 0"

before=$(tree_state "$T/proj")
if ! "$ZIDE" adopt "$T/proj" --dry-run --no-configure >/dev/null 2>&1; then
  tap_not_ok "dry-run adopt exits 0"
  exit 1
fi
tap_ok "dry-run adopt exits 0"
after=$(tree_state "$T/proj")
if [[ $before == "$after" ]]; then
  tap_ok "--dry-run leaves the tree (incl. modes) unchanged"
else
  tap_not_ok "--dry-run leaves the tree (incl. modes) unchanged" "$(diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") | head -10)"
fi

# Idempotency: adopting the same tree twice changes nothing the second time.
"$ZIDE" adopt "$T/proj" --no-configure >"$T/re1.log" 2>&1
"$ZIDE" adopt "$T/proj" --no-configure >"$T/re2.log" 2>&1
if grep -q "created : 0" "$T/re2.log" && grep -q "unchanged:" "$T/re2.log"; then
  tap_ok "second adopt reports no new files (idempotent)"
else
  tap_not_ok "second adopt reports no new files (idempotent)" "$(tail -8 "$T/re2.log")"
fi

# Determinism: same inputs (pinned --name) in different dirs => identical trees.
D1=$(fresh_dir)
track_tmp "$D1"
D2=$(fresh_dir)
track_tmp "$D2"
"$ZIDE" init "$D1/a" --name sameproj --lang cpp -y --no-configure --no-git \
  --author "Test Author" --year 2024 >/dev/null 2>&1
"$ZIDE" init "$D2/a" --name sameproj --lang cpp -y --no-configure --no-git \
  --author "Test Author" --year 2024 >/dev/null 2>&1
if diff -r --exclude=.git "$D1/a" "$D2/a" >/dev/null; then
  tap_ok "two runs with identical inputs produce identical files"
else
  tap_not_ok "two runs with identical inputs produce identical files"
fi
