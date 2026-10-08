#!/usr/bin/env bash
# adopt: existing CMake project gets Zed files; configure links compile_commands.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

T=$(fresh_dir)
track_tmp "$T"
P=$T/legacy
mkdir -p -- "$P/src"
cat >"$P/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.16)
project(legacy LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
add_executable(legacy src/main.cpp)
EOF
cat >"$P/src/main.cpp" <<'EOF'
int main() { return 0; }
EOF

if ! "$ZIDE" adopt "$P" --no-configure >/dev/null 2>&1; then
  tap_not_ok "adopt cmake project exits 0"
  exit 1
fi
tap_ok "adopt cmake project exits 0"

for f in .zed/settings.json .zed/tasks.json .zed/debug.json .clangd .clang-format .clang-tidy; do
  if [[ -f $P/$f ]]; then tap_ok "adopt writes $f"; else tap_not_ok "adopt writes $f"; fi
done
if grep -q '"label": "build"' "$P/.zed/tasks.json"; then tap_ok "tasks contain a build entry"; else tap_not_ok "tasks contain a build entry"; fi
# The project's own CMakeLists.txt is never modified.
if grep -q "project(legacy" "$P/CMakeLists.txt"; then tap_ok "existing CMakeLists.txt untouched"; else tap_not_ok "existing CMakeLists.txt untouched"; fi

if ! have_tool cmake; then
  tap_skip "configure links compile_commands.json" "cmake not installed"
  exit 0
fi
"$ZIDE" adopt "$P" >/dev/null 2>&1
if [[ -L $P/compile_commands.json ]]; then
  tap_ok "compile_commands.json symlinked after configure"
else
  tap_not_ok "compile_commands.json symlinked after configure"
fi
