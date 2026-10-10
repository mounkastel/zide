# Changelog

All notable changes to `zide` are recorded here. Versioning follows SemVer:
no command or flag has been renamed; where observable behavior changed, it is
listed under the release.

## [Unreleased]

### Added

* `make uninstall` (removes `$(DESTDIR)$(PREFIX)/bin/zide`, nothing else).
* `DESTDIR` support for `make install` (staged installs, e.g. packaging).

## [3.1.0] — 2026-10-08

### Added

* A leading `~` or `~/...` in path arguments and wizard path prompts
  expands to `$HOME`. `~user` forms stay literal. A bare `~` is refused
  with exit 4 like `$HOME`; with `HOME` unset or empty, `~` paths fail
  with exit 2. Reports show the expanded absolute path.

### Fixed

* Wizard text prompts show the default as a hint and start with an empty
  input buffer. Enter accepts the default, and typed text replaces it.

## [3.0.0] — 2026-10-08

### Added

* `adopt` does not run the project's build system unless `--configure`
  is passed.
* New `--configure` flag for `adopt`. Before anything executes, zide prints
  `about to run (in <dir>): <exact command>`; the wizard asks first and
  defaults to "no".
* `compile_commands.json` is produced with `--configure`, or when the build
  is configured separately and `adopt` is re-run.
* `--no-configure` for `adopt` is accepted for compatibility with scripts
  written against preview builds and behaves like the default, with a
  one-line warning. For `init` it skips the initial `cmake --preset dev`.
* Every `adopt` execution runs with the project directory as the working
  directory, so the pre-execution notice names the exact directory.
