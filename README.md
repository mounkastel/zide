[![CI](https://github.com/mounkastel/zide/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/mounkastel/zide/actions/workflows/ci.yml)

# zide

One Bash script that sets up Zed for C, C++ and Rust projects.

## Install

```sh
git clone https://github.com/mounkastel/zide.git && cd zide
make install   # installs to ~/.local/bin/zide
zide --version # prints the installed version
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

### Uninstall

```sh
make uninstall                 # removes ~/.local/bin/zide
make uninstall PREFIX=/usr/local
make uninstall DESTDIR=<stage> PREFIX=/usr/local  # packagers: staged removal
```

```
zide adopt <path>   retrofit an existing project (never breaks your build)
zide init  <path>   scaffold a new project that builds, tests and runs immediately
zide doctor         toolchain report with per-distro install hints (apt/dnf/pacman/zypper)
```

Requirements: Bash 5+ (Bash 5.0 is covered by `make test-compat`), Linux, GNU coreutils. Optional tools (`cmake ninja clangd clang-format clang-tidy jq git bear|compiledb
meson gdb lldb cargo rustc rust-analyzer`) fall back when missing. No network access is ever used.

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
unsafe operation, `130` interrupted. `doctor` exits `1` when a required tool
(`cmake clangd git cargo rustc`) is missing or broken.

## What gets written to disk

`adopt <path>` (existing project):

* `.zed/settings.json`: merged (your keys win). `.zed/tasks.json` and
  `.zed/debug.json`: missing entries added by `label`.
* `.clangd`, `.clang-format` (`--style`), `.clang-tidy`.
* `.gitignore`: one managed block (`# >>> zide >>>`); your lines are untouched.
* CMake projects: with `--configure`, configures (`dev` preset if present,
  else `build/zide`) and symlinks `compile_commands.json` to the root;
  without it, none is produced (re-run with `--configure`, or configure
  the build yourself and re-run `adopt`).
  Your `CMakeLists.txt` is never modified. No build system at all: generates
  a reviewable `CMakeLists.txt` from the sources (`--no-cmake` to skip).
  Make: with `--configure`, `compiledb -n make`, or `bear -- make -B`
  (a real build). Meson: `meson setup`. Bazel: a hint only.

When no build system is present, `adopt` generates a `CMakeLists.txt` with one executable target per file that defines `main()`, named after its relative path. A `CMakeLists.txt` that already exists is never modified; the report then states how many files with `main()` it builds and lists the ones it does not, using a textual check of file paths. Run and debug entries are created for every executable target.

`init <path>` (new project): `CMakeLists.txt`, `CMakePresets.json`
(`dev`/`release`/`asan`/`ubsan`/`tsan`), `include/<name>/`, `src/`, `tests/`,
`benchmarks/` (opt-in), `cmake/`, `scripts/{build,run,format,sanitize}.sh`,
`third_party/`, `.zed/`, clang configs, `LICENSE`, and a git repo with an
initial commit (unless `--no-git`). Rust: `Cargo.toml`, `src/{lib,main}.rs`,
`tests/`, `rustfmt.toml`, helper scripts, `.zed/`.

## Safety guarantees

* Existing files are kept unless `--force` is passed; replaced files get a `*.bak` backup.
* `--dry-run` prints the plan with diffs and writes nothing.
* `adopt` runs no project code unless `--configure` is passed.
* Paths under `/`, `$HOME`, and system directories are refused.
* Output is deterministic when `--author` and `--year` are pinned.

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

Open items are tracked in the [issue tracker](https://github.com/mounkastel/zide/issues).

## License

MIT. See [LICENSE](LICENSE).
