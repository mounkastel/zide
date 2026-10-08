# zide

One Bash script that gives **Zed** an IDE-grade setup for C, C++ and Rust projects.

## Install

```sh
git clone https://github.com/mounkastel/zide.git && cd zide
make install   # installs to ~/.local/bin/zide
zide --version # 3.0.0
```

Make sure `~/.local/bin` is on your `PATH`
(`export PATH="$HOME/.local/bin:$PATH"`). To install elsewhere, point
`PREFIX` at it: `make install PREFIX=/usr/local` (use `sudo` only when the
target directory needs it).

No git? Install straight from the script (same file, no installer):

```sh
curl -fsSL https://raw.githubusercontent.com/mounkastel/zide/main/zide -o ~/.local/bin/zide
chmod +x ~/.local/bin/zide
```

```
zide adopt <path>   retrofit an existing project (never breaks your build)
zide init  <path>   scaffold a new project that builds, tests and runs immediately
zide doctor         toolchain report with per-distro install hints (apt/dnf/pacman/zypper)
```

Requirements: Bash 5+ (verified on 5.0 and 5.3 via `make test-compat`), Linux, GNU coreutils. Optional tools (all degrade gracefully
when missing): `cmake ninja clangd clang-format clang-tidy jq git bear|compiledb
meson gdb lldb cargo rustc rust-analyzer`. No network access is ever used.

## Quick start

```sh
zide init ~/src/fastcalc --lang cpp --std 20 --strict --test doctest -y
cd ~/src/fastcalc && cmake --preset dev && cmake --build --preset dev && ctest --preset dev
zed .

zide adopt ~/src/legacy --dry-run   # preview the plan (with diffs) first
zide adopt ~/src/legacy             # safe by default: runs no project code
zide adopt ~/src/legacy --configure # opt in to running the build system

zide doctor                         # grouped report + "ready" / "N things to fix"
zide doctor --json | jq .           # machine-readable variant
```

Interactive mode (arrow-key menus, preview before apply, nothing is written until
you confirm):

```sh
zide              # in a terminal: starts the wizard
zide -i           # same, explicitly
zide -i init ./x  # wizard pre-filled with the mode / path
```

## Flags

Full reference: `zide --help` (one screen). The most used:

| Flag | Meaning |
|------|---------|
| `-n, --dry-run` | plan only: list actions and show diffs, change nothing |
| `-f, --force` | replace differing files (originals kept as `*.bak.<UTC>`) |
| `-y, --yes` | never prompt; take defaults for anything not passed |
| `-v, --verbose` | extra detail (and internal locations on failure) |
| `--no-color` | plain output (`NO_COLOR` is honoured too) |
| `--lang L` | `init`: `c \| cpp \| rust \| c-cpp-mixed` (default: `cpp`) |
| `--build B` | `adopt`: drive only `cmake \| cargo`; `init`: must agree with `--lang` |
| `--std N`, `--c-std N` | C++ (`17\|20\|23`, default 20) / C (`11\|17\|23`, default 17) standard |
| `--test T` | `ctest \| catch2 \| doctest \| gtest \| none` (default: `ctest`; external frameworks are used only if installed system-wide, otherwise a smoke test) |
| `--license L` | `mit \| apache2 \| bsd3 \| gpl3 \| none` (default: `mit`) |
| `--strict` | `-Wall -Wextra -Wpedantic -Werror` (warnings denied for Rust) |
| `--benchmarks` | add a `benchmarks/` target (opt-in) |
| `--generator G` | CMake generator: `auto \| ninja \| make` (default: `auto`) |
| `--style S` | clang-format base: `llvm \| mozilla \| google` |
| `--no-git` | skip `git init` and the initial commit |
| `--bare-remote D` | bare repo at `D` with a post-receive stub, added as `origin` |
| `--no-configure` | deprecated for `adopt` (this is the default); `init`: skip the initial `cmake --preset dev` |
| `--configure` | `adopt`: run the build system to export `compile_commands.json` (project code executes) |
| `--no-cmake` | `adopt`: never generate a `CMakeLists.txt` |
| `--json` | `doctor`: machine-readable report on stdout |

Exit codes: `0` ok, `1` failure, `2` usage, `3` bad generated JSON, `4` refused
unsafe operation, `130` interrupted. `doctor` exits `1` when a *required* tool
(`cmake clangd git cargo rustc`) is missing or broken.

## What gets written to disk

`adopt <path>` (existing project):

* `.zed/settings.json` — **merged** (your keys win), `.zed/tasks.json` /
  `.zed/debug.json` — missing entries added by `label`.
* `.clangd`, `.clang-format` (`--style`), `.clang-tidy`.
* `.gitignore` — one managed block (`# >>> zide >>>`); your lines are untouched.
* CMake projects: with `--configure`, configures (`dev` preset if present,
  else `build/zide`) and symlinks `compile_commands.json` to the root;
  without it, no `compile_commands.json` is produced (re-run with
  `--configure`, or configure the build yourself and re-run `adopt`).
  Your `CMakeLists.txt` is never modified. No build system at all: generates
  a reviewable `CMakeLists.txt` from the sources (`--no-cmake` to skip).
  Make: with `--configure`, `compiledb -n make`, or `bear -- make -B`
  (a real build). Meson: `meson setup`. Bazel: a hint only.

`init <path>` (new project): `CMakeLists.txt`, `CMakePresets.json`
(`dev`/`release`/`asan`/`ubsan`/`tsan`), `include/<name>/`, `src/`, `tests/`,
`benchmarks/` (opt-in), `cmake/`, `scripts/{build,run,format,sanitize}.sh`,
`third_party/`, `.zed/`, clang configs, `LICENSE`, and a git repo with an
initial commit (unless `--no-git`). Rust: `Cargo.toml`, `src/{lib,main}.rs`,
`tests/`, `rustfmt.toml`, helper scripts, `.zed/`.

## Safety guarantees

* Existing files that differ from a template are **kept**; `--force` replaces
  them and first saves `*.bak.<UTC timestamp>`.
* `.zed/settings.json` is **merged** (your keys win); `tasks.json` / `debug.json`
  get missing entries added by `label`. Files containing comments (JSONC) are
  left alone unless `--force`.
* `.gitignore` gets one managed block (`# >>> zide >>>`), your lines are untouched.
* `--dry-run` prints every action (with diffs) and writes/executes nothing.
  Re-running is a no-op (idempotent).
* Refuses `/`, `$HOME` and system directories (including their subdirectories).
  All generated JSON is validated with `jq` when installed.
* Deterministic: same flags ⇒ byte-identical output (pin `--author`/`--year`
  for byte-identical licenses across machines/years).
* `adopt` never executes project code (no CMake configure, no build) unless
  you pass `--configure`; the exact command is announced before it runs.
  `--no-configure` is retained for compatibility (with a one-line deprecation
  warning on `adopt`) and means the same as the default. (`init` still
  configures once, on files zide itself generated.)
* Without `compile_commands.json`, clangd in Zed has degraded code
  intelligence (no accurate includes, defines, or jump-to-definition).
  Generate the database with `zide adopt --configure <path>`, or configure
  the build yourself and re-run `adopt`.
* Generating `compile_commands.json` with `--configure` runs your build
  system's configure step (project build files execute). stdout stays
  data-only (`zide doctor | grep` works); all human output goes to stderr.

## Verify the Zed setup

```sh
jq empty .zed/*.json CMakePresets.json && echo json ok
readlink compile_commands.json
clangd --check=src/main.cpp          # use your main source file
zed .
```

In Zed: `task: spawn` lists configure/build/clean/rebuild/test/run;
`debugger: start` offers CodeLLDB and GDB profiles;
`dev: open language server logs` should show clangd; saving a mis-indented
file reformats it via `.clang-format`.

## Tests

```sh
make test   # full matrix (builds real projects; missing toolchains skip with a reason)
make test-compat  # same matrix under Bash 5.0 (oldest supported; builds it if needed)
make lint   # shellcheck -x (needs shellcheck; skips gracefully if absent)
make fmt    # shfmt -w on tests/ (needs shfmt; skips gracefully if absent)
./tests/run.sh   # same as make test
```

See `docs/AUDIT.md` (pre-release audit) and `docs/PLAN.md` (design decisions).

## License

MIT — see [LICENSE](LICENSE).
