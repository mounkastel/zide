# zide plan — v2.0.0 → v2.1.0

## Structure decision (task §2.3.4): keep the single file

`zide` stays one self-contained Bash script. Reasons:

1. The install story *is* the product: `install -m 0755 zide ~/.local/bin/zide`.
   A `lib/` split forces either a fragile runtime lookup
   (`$(dirname "$(readlink -f "$0")")` breaks for `curl … | bash`, copies, and renames)
   or an install step (Makefile `install` target) that every user must now run.
2. The file is large but already section-delimited (`Logging`, `Safe filesystem
   primitives`, `Detection`, `Mode 1: adopt`, `Mode 2: init`, `CLI`, `wizard`);
   the problem is bugs/UX, not navigation.
3. The hard constraints forbid behavior drift; a mechanical split adds risk with zero
   user-visible gain.

So: one file, clearly delimited sections (unchanged layout), plus `tests/` and `docs/`.
Installation is unchanged; the `Makefile` gains an `install` target only as a
convenience wrapper around the same `install -m 0755` line.

## Test-harness decision (task §2.3.2): plain-bash TAP, no bats dependency

`bats-core` is fine software, but making it mandatory adds a dependency to a tool
whose contract is "Bash 5+, GNU coreutils, Linux". The suite is therefore a minimal
bash harness (`tests/run.sh` + `tests/t-*.sh`) emitting TAP, covering exactly the
scenarios in §2.3.2. Developers who prefer bats can run the same assertions later;
nothing in the harness precludes that.

`Makefile` targets: `test` (harness), `lint` (`shellcheck -x`, must be clean),
`fmt` (formats `tests/` with `shfmt -i 2`; for `zide` itself only *checks* —
see below), `install` (the documented one-liner).

## `shfmt` decision

`shfmt -d` (even with `-i 2`) wants to explode every `;;` one-liner `case` branch
(~15 sites) into multi-line form — a whole-file restyle with no functional gain and
a diff that would bury the audit fixes. Per "no rewriting for its own sake", the
existing 2-space compact style is kept; new code follows it. `shellcheck -x` is the
enforced gate (zero warnings; each `disable` justified inline — currently only
SC2016-literal and SC2018/19-ASCII-identifier false positives, if any remain).

## Conservative-behavior decisions (ambiguous requirements)

1. **Auto-configure stays on by default** (S2). `adopt`/`init` keep running
   `cmake`/`meson`/`bear` so clangd works out of the box; added: an explicit stderr
   notice naming the exact command before project build files execute, plus README
   documentation and the existing `--no-configure` opt-out. Rationale: changing the
   default would silently break the promised "clangd works immediately" flow.
2. **Wizard Back-navigation deferred.** The wizard writes nothing before `wiz_apply`
   (verified — only `find`/`safe_path` reads), Cancel-at-summary and Ctrl+C (exit 130,
   cursor restored) are side-effect-free. Full per-step Back needs a state-machine
   rewrite of `wizard_init`/`wizard_adopt`; Cancel + re-run covers it because the
   wizard is fast. Validation loops (path/standard/license inputs) *are* added.
3. **`--std N` for mixed (B9).** `--std N` now sets `CXX_STD=N` always and `C_STD=N`
   only when `N` is a valid C standard; otherwise the C default (17) is kept.
   Rationale: `--std 20 --lang mixed` dying is a trap, and the C++ reading matches
   the flag's documented primary meaning.
4. **`doctor` required set.** `doctor` takes no project path, so "required" is defined
   globally: `cmake clangd git cargo rustc` — each gates at least one default flow
   (C configure / promised LSP / Rust build / default initial commit).
   `rust-analyzer jq ninja clang-format …` are recommended/optional: without `jq` zide
   still works (keep-or-force fallback), without `rust-analyzer` Zed still opens Rust.
   Exit 1 iff any *required* tool is missing; the summary line always prints
   `ready` or `N things to fix (M required)`. Rationale: a context-free doctor that
   fails a healthy C-only box over a missing Rust LSP would be noise, while silently
   exiting 0 with no `cmake` would be a lie.
5. **Report stream change (D1).** `print_report` + `Next steps` move stdout→stderr.
   Technically observable, but reports were never machine data; `doctor` (the only
   piped command, `zide doctor | grep`) stays on stdout. Recorded in CHANGELOG.
6. **`.gitignore` managed block (D3).** Treated as merge-class like `.zed/*.json`
   (user lines preserved verbatim); documented in README instead of gated on `--force`.

## Stages (each = its own commit; green gate before proceeding)

| Stage | Commits | Gate |
|-------|---------|------|
| 0. Repo + harness + Makefile | `test(harness): TAP runner, fixtures, Makefile test/lint/fmt` | `make lint`, runner self-test green |
| 1. Safety/correctness | `fix(safe-path): refuse system subdirs` (B1/S1); `fix(build-flag): honor --build/--build-system` (B2); `fix(adopt): preset tasks use --preset` (B3); `fix(errors): verbose-gated traces, no subshell traps` (B4); `fix(dry-run): report counts nothing not written` (B5); `fix(compdb): absolute symlink target` (B6); `fix(init): validate --year; lenient --std for mixed; git/bare-remote warn+continue; wizard re-prompt` (B8,B9,B10,B12,B13,B14); `fix(scan): NUL-delimited file walk` (B11); `fix(main): explicit safe_path propagation` (B15); `chore: drop dead no-op` (B7) | shellcheck clean; new tests red→green; manual `init`+`adopt` in `mktemp -d` + build generated project |
| 2. UX | `feat(help): one-screen grouped usage` (U1); `feat(errors): what/why/next-step messages` (U2); `feat(doctor): grouped report, colors, summary, exit code, --json` (U3); `feat(report): stderr, uniform verbs, backup list, next steps` (D1,D2); `feat(dry-run): capped unified diffs` (U4); `feat(doctor,adopt,init): elapsed time + pre-exec notice` (U6/S2); `feat(wizard): validation loops, prefill checks` (U5/B10/B14) | full matrix green; `--help`/error/report before-after captured |
| 3. Docs/release | `docs: README + CHANGELOG`, `chore(release): 2.1.0` | final matrix + shellcheck + `zide --help`/`doctor`/`init`+build in empty dir |

## Risks

- `doctor` exit-code change may surprise scripts that assumed 0: mitigated — old code
  *always* exited 0, so no one could have depended on failure codes; CHANGELOG notes it.
- Report stdout→stderr: anyone scraping `init` stdout gets nothing now; mitigated by
  CHANGELOG entry and the fact that machine consumers should use `--dry-run`/files.
- `safe_path` tightening could refuse a path someone used (e.g. building under
  `/srv/...` or `/tmp/...` — note `/tmp` itself is **not** refused, only system roots;
  check: `/tmp` not in list, correct for `mktemp -d` workflows and tests).
- No network at runtime: all changes are offline (`--json` is hand-rolled, no new deps).
- Bash 5.0 compat: no new builtins beyond what is used (`local -n` already required
  ≥4.3); `read -d ''`, `sort -z`, `mapfile` all predate 5.0. Oldest available bash here
  is 5.3; features used exist since 4.x, verified by inspection.

## What will NOT change, and why

- Commands/flags names (contract); `--build` keeps its name, now honored.
- Generated file formats (only the doctor/report *presentation* changes, which is
  runtime output, not generated project files). If any template byte changes during
  fixes, it goes in CHANGELOG with a determinism re-check — none is planned.
- License/attribution. Duplicated-but-stable task/debug blocks (audit §5).
- `shfmt` whole-file restyle (above). Full wizard step-back (above).
