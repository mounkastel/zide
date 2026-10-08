#!/usr/bin/env bash
# Exit codes and error hygiene: 2 for usage, 4 for protected paths.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

T=$(fresh_dir)
track_tmp "$T"

out=$("$ZIDE" frobnicate 2>&1)
rc=$?
if ((rc == 2)); then tap_ok "unknown command exits 2"; else tap_not_ok "unknown command exits 2"; fi
if [[ -n $out ]]; then tap_ok "unknown command prints a message"; else tap_not_ok "unknown command prints a message"; fi

"$ZIDE" --bogus init "$T/x" >/dev/null 2>&1
rc=$?
if ((rc == 2)); then tap_ok "unknown flag exits 2"; else tap_not_ok "unknown flag exits 2"; fi

"$ZIDE" init >/dev/null 2>&1
rc=$?
if ((rc == 2)); then tap_ok "missing path exits 2"; else tap_not_ok "missing path exits 2"; fi

mkdir -p -- "$T/blank"
"$ZIDE" adopt "$T/blank" >/dev/null 2>&1
rc=$?
if ((rc == 2)); then tap_ok "adopt with no sources exits 2"; else tap_not_ok "adopt with no sources exits 2"; fi

"$ZIDE" adopt / >/dev/null 2>&1
rc=$?
if ((rc == 4)); then tap_ok "adopt / exits 4 (refused)"; else tap_not_ok "adopt / exits 4 (refused)"; fi

"$ZIDE" init "$HOME" --lang cpp -y --no-git >/dev/null 2>&1
rc=$?
if ((rc == 4)); then tap_ok "init \$HOME exits 4 (refused)"; else tap_not_ok "init \$HOME exits 4 (refused)"; fi

"$ZIDE" init /usr/zide-probe-nonexistent --lang cpp -y --no-git >/dev/null 2>&1
rc=$?
if ((rc == 4)); then tap_ok "init under /usr exits 4 (refused)"; else tap_not_ok "init under /usr exits 4 (refused)"; fi

"$ZIDE" doctor >/dev/null 2>&1
rc=$?
if ((rc == 0 || rc == 1)); then tap_ok "doctor exits 0/1"; else tap_not_ok "doctor exits 0/1 (got $rc)"; fi
if "$ZIDE" doctor 2>/dev/null | grep -q "cmake"; then tap_ok "doctor reports on cmake"; else tap_not_ok "doctor reports on cmake"; fi
