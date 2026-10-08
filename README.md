# zide

One Bash script that gives **Zed** an IDE-grade setup for C, C++ and Rust projects.

```
zide adopt <path>   retrofit an existing project (never breaks your build)
zide init  <path>   scaffold a new project that builds, tests and runs immediately
zide doctor         toolchain report with per-distro install hints (apt/dnf/pacman/zypper)
```

Requirements: Bash 5+, Linux. Optional: `cmake ninja clangd clang-format jq git bear|compiledb gdb|lldb cargo rust-analyzer`.
No network access is ever used.

## Interactive mode

```sh
zide              # in a terminal: starts the wizard
zide -i           # same, explicitly
zide -i init ./x  # wizard pre-filled with the mode / path
```
The wizard asks only what is relevant (arrow-key menus, `Tab` completes paths), shows a summary, and lets you
**Preview** (dry-run) before **Apply**. Anything you already passed as a flag is not asked again. Afterwards it can
open the project in Zed.

## Install

```sh
install -m 0755 zide ~/.local/bin/zide
```

## Safety model

* Existing files that differ from a template are **kept**; `--force` replaces them and first saves `*.bak.<UTC timestamp>`.
* `.zed/settings.json` is **merged** (your keys win); `tasks.json` / `debug.json` get missing entries added by `label`.
  Files containing comments (JSONC) are left alone unless `--force`.
* `.gitignore` gets one managed block (`# >>> zide >>>`), your lines are untouched.
* `--dry-run` prints every action and writes/executes nothing. Re-running is a no-op (idempotent).
* Refuses `/`, `$HOME` and system directories. All generated JSON is validated with `jq` when installed.
* Deterministic: same flags => byte-identical output (license year via `--year`).

## adopt

Detects C / C++ / Rust and CMake / Meson / Make / Bazel / Cargo, then:

* CMake: exports `compile_commands.json` (preset `dev` if present, else `build/zide`) and symlinks it to the repo root.
  Your `CMakeLists.txt` is never modified.
* No build system at all: generates a reviewable `CMakeLists.txt` from the sources (`--no-cmake` to skip).
* Make: `compiledb -n make` (no build) or `bear -- make -B`. Meson: `meson setup`. Bazel: a hint only.
* Writes `.zed/{settings,tasks,debug}.json`, `.clangd`, `.clang-format` (`--style llvm|mozilla|google`), `.clang-tidy`.
* Prints a report: created / modified / kept files, backups, toolchain versions, next steps.

## init

```sh
zide init ~/src/fastcalc --lang cpp --std 20 --strict --test doctest
zide init ~/src/packetd  --lang c   --std 17 --license apache2 --benchmarks
zide init ~/src/bridge   --lang c-cpp-mixed -y
zide init ~/src/agent    --lang rust --strict
```

Layout: `CMakeLists.txt`, `CMakePresets.json` (dev, release, asan, ubsan, tsan), `include/<name>/`, `src/`, `tests/`,
`benchmarks/` (opt-in), `cmake/`, `scripts/{build,run,format,sanitize}.sh`, `third_party/`, `.zed/`, clang configs, LICENSE, git repo.

`cmake --preset dev && cmake --build --preset dev && ctest --preset dev` passes out of the box.
Catch2 / doctest / GoogleTest are used if installed system-wide; otherwise the same test falls back to a built-in smoke test.
Apache-2.0 and GPL-3 texts are copied from `/usr/share/common-licenses` when present (otherwise a short notice with the URL).

## Verify the Zed setup

```sh
jq empty .zed/*.json CMakePresets.json && echo json ok
readlink compile_commands.json
clangd --check=src/main.cpp          # use your main source file
zed .
```
In Zed: `task: spawn` lists configure/build/clean/rebuild/test/run; `debugger: start` offers CodeLLDB and GDB profiles;
`dev: open language server logs` should show clangd; saving a mis-indented file reformats it via `.clang-format`.

Exit codes: 0 ok, 1 failure, 2 usage, 3 invalid generated JSON, 4 refused unsafe operation.
