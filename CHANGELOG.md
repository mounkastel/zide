# Changelog

All notable changes to `zide` are recorded here. Versioning follows SemVer:
no command or flag has been renamed; where observable behavior changed, it is
listed under the release.

## [Unreleased]

### Added

* `make uninstall` (removes `$(DESTDIR)$(PREFIX)/bin/zide`, nothing else).
* `DESTDIR` support for `make install` (staged installs, e.g. packaging).

## [3.0.0] — 2026-10-08

### Breaking changes

* `adopt` no longer executes project code by default: no CMake configure,
  no Meson setup, no `compiledb`/`bear` run. If you relied on implicit
  configure (e.g. `zide adopt <path>` in CI to get `compile_commands.json`),
  add `--configure`. (Shipped briefly as 2.2.0 during development; renamed
  to 3.0.0 before any release because the default change is incompatible
  under SemVer.)
* New `--configure` flag for `adopt`. Before anything executes, zide prints
  `about to run (in <dir>): <exact command>`; the wizard asks first and
  defaults to "no".
* `--no-configure` is retained and keeps working; for `adopt` it now means
  the same as the default. For `init` nothing changed (it still configures
  once, on files zide itself generated).
* `compile_commands.json` is produced only with `--configure` (or when you
  configure the build yourself and re-run `adopt`).

### Deprecated

* `--no-configure` for `adopt`: not configuring is now the default, so the
  flag is a no-op there. It is still accepted (with a one-line warning) and
  will not be removed in 3.x. For `init` it is unchanged: it still skips the
  initial `cmake --preset dev`.

### Fixed

* All `adopt` executions now run with the project directory as the working
  directory, so the pre-execution notice is exact.

## [2.1.0] — 2026-10-08

### Added

* `doctor`: tools grouped into required / recommended / optional, per-tool
  install hints for every missing tool, `summary: ready` (or
  `N things to fix (M required)`), and `--json` machine-readable output.
* `--dry-run` (and the wizard preview) now shows capped unified diffs and
  content previews, not just action names.
* `--build` / `--build-system` is honored: `adopt` drives only the selected
  build system (and errors when its files are absent); `init` validates it
  against `--lang`.
* Regression suite: `tests/` (plain-bash TAP harness, no new dependencies)
  plus a `Makefile` with `test`, `lint`, `fmt` and `install` targets.

### Changed

* `doctor` exits `1` when a required tool (`cmake clangd git cargo rustc`)
  is missing or broken (previously always `0`).
* Final reports and `Next steps` go to stderr; `doctor` stays on stdout, so
  `zide doctor | grep` keeps working. Report vocabulary is now uniform:
  `created / updated / unchanged / kept / backups`, and backup paths are listed.
* `safe_path` refuses subdirectories of system roots (`/usr/...`, `/etc/...`),
  not just the exact paths.
* `--help` rewritten as a one-screen grouped reference covering every flag.
* Every error message states what happened, why, and the next command or flag.
* Adopted CMake projects with a `dev` preset now get `--preset`-style
  build/test tasks (previously directory-style).
* A bare `--std N` sets the C++ standard and adopts it for C only when valid
  for C (previously `mixed --std 20` died).
* `try_run` progress lines read `running: …` and failures report elapsed time.
* `adopt`/`init` announce before running project build files to produce
  `compile_commands.json` (`--no-configure` skips this).

### Fixed

* Dry-run reports no longer count backups that were never taken.
* Absolute `compile_commands.json` symlinks no longer corrupt build-dir reuse.
* `init` validates `--year`, rejects Rust keywords as crate names and C++
  keywords as derived identifiers (both produced projects that do not build).
* `git init` / `git add` / bare-remote failures warn and continue instead of
  aborting with an internal trace.
* Internal failure locations (`file:line`) are only shown with `--verbose`.
* Filenames with newlines no longer corrupt project scanning.
* Invalid pre-filled wizard values re-prompt instead of aborting the wizard.

### Deliberately unchanged

* Single-file layout kept (see `docs/PLAN.md` for the rationale).
* `.gitignore` managed block and `.zed/*.json` merging still apply without
  `--force` (merge-class behavior, now documented).
* Auto-configure stays on by default; per-step wizard Back-navigation deferred.
* Whole-file `shfmt` restyle declined (mechanical churn, no user gain).
