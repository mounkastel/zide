#!/usr/bin/env bash
# adopt: existing .zed JSON is merged (user keys win), .gitignore preserved.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

T=$(fresh_dir)
track_tmp "$T"
P=$T/keep
mkdir -p -- "$P/.zed"
printf 'int main(void) { return 0; }\n' >"$P/main.c"
cat >"$P/.zed/settings.json" <<'EOF'
{
  "languages": {},
  "lsp": {},
  "my_custom_key": "mine"
}
EOF
cat >"$P/.zed/tasks.json" <<'EOF'
[
  {
    "label": "build",
    "command": "my-custom-build",
    "args": [],
    "cwd": "$ZED_WORKTREE_ROOT"
  }
]
EOF
printf 'my-own-line\n' >"$P/.gitignore"

if ! "$ZIDE" adopt "$P" --no-configure >/dev/null 2>&1; then
  tap_not_ok "adopt merge fixture exits 0"
  exit 1
fi
tap_ok "adopt merge fixture exits 0"

if ! have_tool jq; then
  tap_skip "user keys survive merge" "jq not installed"
  exit 0
fi
if jq -e '.my_custom_key == "mine"' -- "$P/.zed/settings.json" >/dev/null; then tap_ok "custom settings key survives"; else tap_not_ok "custom settings key survives"; fi
if jq -e 'map(select(.label == "build" and .command == "my-custom-build")) | length == 1' \
  -- "$P/.zed/tasks.json" >/dev/null; then tap_ok "custom build task wins over template"; else tap_not_ok "custom build task wins over template"; fi
if jq -e 'map(.label) | index("test") != null or index("configure") != null' \
  -- "$P/.zed/tasks.json" >/dev/null 2>&1; then tap_ok "zide entries added alongside user tasks"; else tap_not_ok "zide entries added alongside user tasks"; fi
if grep -q "my-own-line" "$P/.gitignore" && grep -q ">>> zide >>>" "$P/.gitignore"; then tap_ok ".gitignore user lines preserved + block added"; else tap_not_ok ".gitignore user lines preserved + block added"; fi
