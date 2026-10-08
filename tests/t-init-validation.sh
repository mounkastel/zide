#!/usr/bin/env bash
# init: validation of --year, --std mapping, and keyword guards.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

T=$(fresh_dir)
track_tmp "$T"

"$ZIDE" init "$T/a" --lang cpp -y --no-configure --no-git --year abc >/dev/null 2>&1
rc=$?
if ((rc == 2)); then tap_ok "invalid --year exits 2"; else tap_not_ok "invalid --year exits 2 (got $rc)"; fi

if ! "$ZIDE" init "$T/b" --lang cpp -y --no-configure --no-git --year 2024-2025 >/dev/null 2>&1; then
  tap_not_ok "year range accepted"
  exit 1
fi
tap_ok "year range accepted"

"$ZIDE" init "$T/c" --lang rust -y --no-git --name crate >/dev/null 2>&1
rc=$?
if ((rc == 2)); then tap_ok "rust keyword crate name exits 2"; else tap_not_ok "rust keyword crate name exits 2 (got $rc)"; fi

"$ZIDE" init "$T/d" --lang cpp -y --no-configure --no-git --name class >/dev/null 2>&1
rc=$?
if ((rc == 2)); then tap_ok "c++ keyword project name exits 2"; else tap_not_ok "c++ keyword project name exits 2 (got $rc)"; fi

if ! "$ZIDE" init "$T/e" --lang c -y --no-configure --no-git --name class --author T --year 2024 >/dev/null 2>&1; then
  tap_not_ok "plain c accepts non-keyword-colliding name"
  exit 1
fi
tap_ok "plain c accepts non-keyword-colliding name"

if ! "$ZIDE" init "$T/f" --lang c-cpp-mixed -y --no-configure --no-git --std 20 --author T --year 2024 >/dev/null 2>&1; then
  tap_not_ok "mixed --std 20 accepted (c++ reading)"
  exit 1
fi
tap_ok "mixed --std 20 accepted (c++ reading)"

"$ZIDE" init "$T/g" --lang c -y --no-configure --no-git --std 20 >/dev/null 2>&1
rc=$?
if ((rc == 2)); then tap_ok "c --std 20 exits 2 with c-std hint"; else tap_not_ok "c --std 20 exits 2 with c-std hint (got $rc)"; fi

if ! "$ZIDE" init "$T/h" --lang c -y --no-configure --no-git --c-std 11 --author T --year 2024 >/dev/null 2>&1; then
  tap_not_ok "c --c-std 11 accepted"
  exit 1
fi
tap_ok "c --c-std 11 accepted"

# A failing git must not fail the scaffold (warns and continues).
mkdir -p -- "$T/fakebin"
printf '#!/usr/bin/env bash\nexit 1\n' >"$T/fakebin/git"
chmod +x "$T/fakebin/git"
if ! PATH="$T/fakebin:$PATH" "$ZIDE" init "$T/nogit" --lang c -y --no-configure --author T --year 2024 >"$T/nogit.log" 2>&1; then
  tap_not_ok "init survives failing git"
  exit 1
fi
tap_ok "init survives failing git"
if grep -q "continuing without" "$T/nogit.log"; then tap_ok "git failure warns and continues"; else tap_not_ok "git failure warns and continues"; fi
