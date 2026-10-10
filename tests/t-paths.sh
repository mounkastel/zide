#!/usr/bin/env bash
# Tilde expansion in path inputs; wizard default shown as a hint, not pre-filled.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# Quoted "~..." args pass a literal tilde so zide's own expansion is exercised (each carries its own SC2088 disable).

T=$(fresh_dir)
track_tmp "$T"
H=$(fresh_dir)
track_tmp "$H"
W=$T/work
mkdir -p -- "$W"

cmake_fixture() { # <dir>: minimal C/cmake project adoptable as-is
  mkdir -p -- "$1/src"
  cat >"$1/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.16)
project(fixture LANGUAGES C)
add_executable(fixture src/main.c)
EOF
  printf 'int main(void) { return 0; }\n' >"$1/src/main.c"
}

# 1. init ~/proj lands under the temporary HOME; no literal ~ dir appears.
# shellcheck disable=SC2088
if (cd "$W" && HOME="$H" "$ZIDE" init "~/proj" --lang c -y >"$T/init.log" 2>&1); then
  tap_ok "init ~/proj exits 0"
else
  tap_not_ok "init ~/proj exits 0"
fi
if [[ -f $H/proj/CMakeLists.txt ]]; then
  tap_ok "init ~/proj creates <tmp>/proj"
else
  tap_not_ok "init ~/proj creates <tmp>/proj"
fi
if [[ ! -e $W/~ ]]; then
  tap_ok "no literal ~ directory in the working directory"
else
  tap_not_ok "no literal ~ directory in the working directory"
fi

# 2. adopt ~/existing --dry-run plans for the expanded path.
cmake_fixture "$H/existing"
# shellcheck disable=SC2088
if (cd "$W" && HOME="$H" "$ZIDE" adopt "~/existing" --dry-run >"$T/adopt.log" 2>&1); then
  tap_ok "adopt ~/existing --dry-run exits 0"
else
  tap_not_ok "adopt ~/existing --dry-run exits 0"
fi
if grep -Fq "$H/existing" "$T/adopt.log"; then
  tap_ok "adopt ~/existing plans for <tmp>/existing"
else
  tap_not_ok "adopt ~/existing plans for <tmp>/existing"
fi

# 3. A bare ~ expands to $HOME itself, which safe_path refuses (exit 4).
before=$(cd "$H" && find . -mindepth 1 | LC_ALL=C sort)
if (cd "$W" && HOME="$H" "$ZIDE" init "~" -y >"$T/bare.log" 2>&1); then
  tap_not_ok "init ~ exits 4 (refused)"
else
  rc=$?
  if ((rc == 4)); then tap_ok "init ~ exits 4 (refused)"; else tap_not_ok "init ~ exits 4 (refused, got $rc)"; fi
fi
after=$(cd "$H" && find . -mindepth 1 | LC_ALL=C sort)
if [[ $after == "$before" ]] && [[ ! -e $W/~ ]]; then
  tap_ok "init ~ creates nothing"
else
  tap_not_ok "init ~ creates nothing"
fi

# 4. ~user is not expanded: the literal relative path is used, as before.
if (cd "$W" && HOME="$H" "$ZIDE" init "~user/x" --lang c -y --no-git --no-configure >"$T/user.log" 2>&1); then
  tap_ok "init ~user/x exits 0"
else
  tap_not_ok "init ~user/x exits 0"
fi
if [[ -f $W/~user/x/CMakeLists.txt ]] && [[ ! -e $H/user/x ]] && [[ ! -e $H/~user ]]; then
  tap_ok "init ~user/x uses the literal path (no expansion)"
else
  tap_not_ok "init ~user/x uses the literal path (no expansion)"
fi

# 5. With HOME unset, a path starting with ~ fails with exit 2 and a message.
W2=$T/nowork
mkdir -p -- "$W2"
# shellcheck disable=SC2088
if (cd "$W2" && env -u HOME "$ZIDE" init "~/y" --lang c -y --no-git --no-configure >"$T/nohome.log" 2>&1); then
  tap_not_ok "unset HOME with ~/y exits 2"
else
  rc=$?
  if ((rc == 2)); then tap_ok "unset HOME with ~/y exits 2"; else tap_not_ok "unset HOME with ~/y exits 2 (got $rc)"; fi
fi
if grep -Fq "HOME" "$T/nohome.log"; then
  tap_ok "unset HOME prints a clear message"
else
  tap_not_ok "unset HOME prints a clear message"
fi
if [[ ! -e $W2/~ ]] && [[ ! -e $W2/y ]]; then
  tap_ok "unset HOME creates nothing"
else
  tap_not_ok "unset HOME creates nothing"
fi

# 6. --bare-remote ~/remote.git expands under the temporary HOME.
if ! have_tool git; then
  tap_skip "init --bare-remote ~/remote.git exits 0" "git not installed"
  tap_skip "bare remote lands at <tmp>/remote.git" "git not installed"
else
  # shellcheck disable=SC2088
  if (cd "$W" && HOME="$H" "$ZIDE" init "$W/proj2" --lang c -y --no-git --no-configure --bare-remote "~/remote.git" >"$T/remote.log" 2>&1); then
    tap_ok "init --bare-remote ~/remote.git exits 0"
  else
    tap_not_ok "init --bare-remote ~/remote.git exits 0"
  fi
  if [[ -f $H/remote.git/HEAD ]] && [[ -x $H/remote.git/hooks/post-receive ]] && [[ ! -e $W/~ ]]; then
    tap_ok "bare remote lands at <tmp>/remote.git"
  else
    tap_not_ok "bare remote lands at <tmp>/remote.git"
  fi
fi

# 7. Wizard through a pty: hint display, empty buffer, Enter-accepts-default, and a typed ~/x under the temporary HOME.
if ! have_tool script; then
  if [[ -n ${ZIDE_REQUIRE_PTY:-} ]]; then
    tap_not_ok "wizard path prompt shows the default as a hint (script(1) missing but required)"
    tap_not_ok "wizard path buffer starts empty (script(1) missing but required)"
    tap_not_ok "wizard Enter accepts the default path (script(1) missing but required)"
    tap_not_ok "wizard typing ~/x adopts <tmp>/x (script(1) missing but required)"
  else
    tap_skip "wizard path prompt shows the default as a hint" "script(1) not installed"
    tap_skip "wizard path buffer starts empty" "script(1) not installed"
    tap_skip "wizard Enter accepts the default path" "script(1) not installed"
    tap_skip "wizard typing ~/x adopts <tmp>/x" "script(1) not installed"
  fi
else
  OLD_HOME=$HOME
  export HOME=$H
  cmake_fixture "$T/wizdef"
  # No path argument, so every Enter accepts the default and the wizard adopts the current directory.
  if (cd "$T/wizdef" && printf '\n\n\n\n\n\n' | timeout 120 script -qec "$ZIDE -i adopt" /dev/null >"$T/wizdef.log" 2>&1); then
    tap_ok "wizard adopt exits 0"
  else
    tap_not_ok "wizard adopt exits 0"
  fi
  if grep -Fq 'Path to the project [.]:' "$T/wizdef.log"; then
    tap_ok "wizard path prompt shows the default as a hint"
  else
    tap_not_ok "wizard path prompt shows the default as a hint"
  fi
  region=$(sed -n '/Path to the project/,/found: languages/p' "$T/wizdef.log")
  if printf '%s\n' "$region" | grep -Fq '> .'; then
    tap_not_ok "wizard path buffer starts empty"
  else
    tap_ok "wizard path buffer starts empty"
  fi
  if [[ -f $T/wizdef/.zed/settings.json ]]; then
    tap_ok "wizard Enter accepts the default path"
  else
    tap_not_ok "wizard Enter accepts the default path"
  fi
  cmake_fixture "$H/x"
  # A typed tilde path replaces the default entirely and expands to the temporary HOME.
  # shellcheck disable=SC2088
  if (cd "$W" && printf '~/x\n\n\n\n\n\n' | timeout 120 script -qec "$ZIDE -i adopt" /dev/null >"$T/wiztilde.log" 2>&1); then
    tap_ok "wizard typing ~/x exits 0"
  else
    tap_not_ok "wizard typing ~/x exits 0"
  fi
  if [[ -f $H/x/.zed/settings.json ]] && [[ ! -e $W/~ ]] && grep -Fq "$H/x" "$T/wiztilde.log"; then
    tap_ok "wizard typing ~/x adopts <tmp>/x"
  else
    tap_not_ok "wizard typing ~/x adopts <tmp>/x"
  fi
  export HOME=$OLD_HOME
fi
