#!/usr/bin/env bash
# make install / make uninstall with PREFIX and DESTDIR (temp dirs only).
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

T=$(fresh_dir)
track_tmp "$T"

# 1. Plain PREFIX install: binary lands executable and reports the version.
if ! make -C "$REPO_ROOT" install PREFIX="$T/pfx" >/dev/null 2>&1; then
  tap_not_ok "make install PREFIX works"
  exit 1
fi
tap_ok "make install PREFIX works"
if [[ -x $T/pfx/bin/zide ]]; then tap_ok "installed binary is executable"; else tap_not_ok "installed binary is executable"; fi
installed_ver=$("$T/pfx/bin/zide" --version)
repo_ver=$("$REPO_ROOT/zide" --version)
if [[ $installed_ver == "$repo_ver" ]] && printf '%s\n' "$installed_ver" | grep -q "1.2.0"; then
  tap_ok "installed binary prints 1.2.0"
else
  tap_not_ok "installed binary prints 1.2.0"
fi

# 2. DESTDIR staging with an absolute PREFIX never touches the real prefix.
real_before="absent"
if [[ -e /usr/local/bin/zide ]]; then real_before="present"; fi
if ! make -C "$REPO_ROOT" install DESTDIR="$T/stage" PREFIX=/usr/local >/dev/null 2>&1; then
  tap_not_ok "make install DESTDIR works"
  exit 1
fi
tap_ok "make install DESTDIR works"
if [[ -x $T/stage/usr/local/bin/zide ]]; then tap_ok "staged binary lands under DESTDIR"; else tap_not_ok "staged binary lands under DESTDIR"; fi
real_after="absent"
if [[ -e /usr/local/bin/zide ]]; then real_after="present"; fi
if [[ $real_before == "$real_after" ]]; then tap_ok "real /usr/local untouched"; else tap_not_ok "real /usr/local untouched"; fi

# 3. Uninstall removes the binary but keeps the directory; reruns succeed.
if ! make -C "$REPO_ROOT" uninstall PREFIX="$T/pfx" >/dev/null 2>&1; then
  tap_not_ok "make uninstall PREFIX works"
  exit 1
fi
tap_ok "make uninstall PREFIX works"
if [[ ! -e $T/pfx/bin/zide ]] && [[ -d $T/pfx/bin ]]; then
  tap_ok "uninstall removes the file, keeps the directory"
else
  tap_not_ok "uninstall removes the file, keeps the directory"
fi
if make -C "$REPO_ROOT" uninstall PREFIX="$T/pfx" >/dev/null 2>&1; then
  tap_ok "second uninstall succeeds"
else
  tap_not_ok "second uninstall succeeds"
fi

# 4. Staged uninstall removes only the staged file.
if ! make -C "$REPO_ROOT" uninstall DESTDIR="$T/stage" PREFIX=/usr/local >/dev/null 2>&1; then
  tap_not_ok "make uninstall DESTDIR works"
  exit 1
fi
tap_ok "make uninstall DESTDIR works"
if [[ ! -e $T/stage/usr/local/bin/zide ]] && [[ -d $T/stage/usr/local/bin ]]; then
  tap_ok "staged uninstall removes only the file"
else
  tap_not_ok "staged uninstall removes only the file"
fi
real_final="absent"
if [[ -e /usr/local/bin/zide ]]; then real_final="present"; fi
if [[ $real_before == "$real_final" ]]; then tap_ok "real /usr/local still untouched"; else tap_not_ok "real /usr/local still untouched"; fi
