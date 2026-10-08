#!/usr/bin/env bash
# init: Rust crate scaffolds, builds and passes tests.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if ! have_tool cargo || ! have_tool rustc; then
  tap_skip "rust crate builds and tests pass" "cargo/rustc not installed"
  exit 0
fi

T=$(fresh_dir)
track_tmp "$T"

if ! "$ZIDE" init "$T/rustdemo" --lang rust -y --no-git \
  --author "Test Author" --year 2024 >/dev/null 2>&1; then
  tap_not_ok "init rust exits 0"
  exit 1
fi
tap_ok "init rust exits 0"
if [[ -f $T/rustdemo/Cargo.toml && -f $T/rustdemo/src/lib.rs ]]; then tap_ok "rust layout exists"; else tap_not_ok "rust layout exists"; fi

if (cd -- "$T/rustdemo" && cargo test --offline >/dev/null 2>&1); then
  tap_ok "cargo test passes offline"
else
  tap_not_ok "cargo test passes offline"
fi
