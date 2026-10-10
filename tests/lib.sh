#!/usr/bin/env bash
# tests/lib.sh: shared helpers for the zide test suite (TAP output, no deps).
# Sourced by tests/t-*.sh. Requires bash 4+.
set -u

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export ZIDE=$REPO_ROOT/zide # exported: consumed by every t-*.sh child process

# Isolate git/home so tests never touch the developer's ~/.gitconfig.
REAL_HOME=${HOME:-}
TEST_HOME=$(mktemp -d "${TMPDIR:-/tmp}/zide-test-home.XXXXXX")
export HOME=$TEST_HOME
export GIT_CONFIG_NOSYSTEM=1
export LC_ALL=C
# Compat mode: when BASH_BIN names another interpreter, shadow bash on PATH so every bash call under test uses it.
if [[ -n ${BASH_BIN:-} && -x ${BASH_BIN:-} && $(command -v bash) != "$BASH_BIN" ]]; then
  BASH_SHIM=$(mktemp -d "${TMPDIR:-/tmp}/zide-bashshim.XXXXXX")
  ln -s "$BASH_BIN" "$BASH_SHIM/bash"
  export PATH="$BASH_SHIM:$PATH"
fi
# Keep the real cargo/rustup homes so cargo works under the isolated HOME.
if [[ -n $REAL_HOME && -d $REAL_HOME/.cargo ]]; then export CARGO_HOME=$REAL_HOME/.cargo; fi
if [[ -n $REAL_HOME && -d $REAL_HOME/.rustup ]]; then export RUSTUP_HOME=$REAL_HOME/.rustup; fi

TAP_N=0
tap_ok() {
  TAP_N=$((TAP_N + 1))
  printf 'ok %d - %s\n' "$TAP_N" "$1"
}
tap_not_ok() {
  TAP_N=$((TAP_N + 1))
  printf 'not ok %d - %s\n' "$TAP_N" "$1"
  if [[ -n ${2:-} ]]; then printf '%s\n' "$2" | sed 's/^/# /'; fi
}
tap_skip() {
  TAP_N=$((TAP_N + 1))
  printf 'ok %d - %s # SKIP %s\n' "$TAP_N" "$1" "${2:-no reason given}"
}

have_tool() { command -v "$1" >/dev/null 2>&1; }

fresh_dir() { mktemp -d "${TMPDIR:-/tmp}/zide-test.XXXXXX"; }

# tree_state <dir>: stable snapshot of paths + modes + sizes (for dry-run checks).
tree_state() {
  (cd -- "$1" && find . -mindepth 1 -exec stat -c '%n %a %s' {} + | LC_ALL=C sort)
}

cleanup_test_tmp() { rm -rf -- "$TEST_HOME" "${TEST_TMPDIRS[@]:-}"; }
TEST_TMPDIRS=()
track_tmp() { TEST_TMPDIRS+=("$1"); }
