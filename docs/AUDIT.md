# zide audit — v2.0.0 (`zide`, 2448 lines)

Method: read the whole file in five overlapping windows; probed live behavior in
`mktemp -d` sandboxes; `shellcheck -x` (v0.10.0, user-local install — no root on
this machine); `shfmt -d` (v3.11.0). Shellcheck reports **only info-level notes**,
no warnings/errors. Every functional claim below was reproduced, except where
marked "inspection".

Conventions: `zide:<line>` = line in the audited file. Exit codes: 2 usage,
3 JSON, 4 refused, 130 interrupted (all verified live).

## 1. Bugs (functional, reproduced unless noted)

| # | Location | Problem | Reproduction |
|---|----------|---------|--------------|
| B1 | `zide:200-210` (`safe_path`) | Protected-path patterns match **exact paths only**. `/usr/local/foo`, `/etc/foo`, `/var/foo` are *not* refused. | `zide init /usr/local/zide-probe --lang c -y` → proceeds past `safe_path`, then dies at `mkdir` with `internal error (exit 1) at line 216: mkdir -p -- ...`. Same for `/etc/...`. `$HOME` exact-only is correct (subdirs are legit targets); system dirs need `/*` variants. |
| B2 | `zide:2385,2399-2401` | `--build` / `--build-system` is parsed and validated, then the value is **discarded** — a silent no-op. | `zide init x --build cmake` behaves byte-identically to no flag; `zide adopt x --build-system bazel` does not restrict detection. |
| B3 | `zide:833-837` vs `zide:1693` | `adopt_zed` calls `tasks_cmake "$PRESET" "$BUILD_DIR" 0`, i.e. `usep=0` **even when `PRESET=dev`**, while `init` passes `1`. Adopted preset projects get dir-style build/test tasks (`cmake --build build/dev`, `ctest --test-dir`) next to a preset-style `configure` task. Inconsistent; the preset spelling should be used when a preset was detected. | `adopt` a CMake project that has a `dev` preset → `.zed/tasks.json` mixes `--preset dev` (configure) with `--test-dir build/dev` (test). |
| B4 | `zide:79-87` (`on_err`, traps) | `on_err` prints an internal trace (`internal error (exit N) at line X: <cmd>`) for **ordinary runtime failures** (permission denied, failing `git`, …). Also `set -E` inherits the ERR trap into `$(…)`/`(…)` subshells, and the `(cd "$ROOT" && try_run …)` subshell at `zide:772` fires the inherited EXIT `cleanup`, deleting the parent's temp files (harmless today — `rm -rf` of a missing path is silent — but fragile). | The B1 repro above ends with `[fail] internal error (exit 1) at line 216: mkdir -p -- "$d"` although nothing internal happened; the user gets no actionable hint. |
| B5 | `zide:220-235`, `zide:349-357` | Dry-run pollutes the report: `backup_file` appends to `BACKUPS[]` and `put_block` appends to `UPDATED[]` even when `DRY_RUN=1`. A dry run then reports `backups: 2` for backups that do not exist. | `zide init r …` then `zide adopt r --dry-run` → prints `[dry ] backup …` lines and `backups: 2` in the summary although `find` before/after is identical (verified). |
| B6 | `zide:757-763` | `adopt_compdb` reuses the dirname of an existing `compile_commands.json` symlink unconditionally. An **absolute** symlink target yields an absolute `BUILD_DIR`, and the later `$ROOT/$BUILD_DIR/compile_commands.json` checks break. | `ln -s /elsewhere/c.json compile_commands.json; zide adopt .` → `BUILD_DIR=/elsewhere`, file-exists checks look under `$ROOT/elsewhere`. (Inspection + partial repro.) |
| B7 | `zide:1764-1766` | Dead no-op: `if ((BENCH)); then :; fi`. | Inspection. |
| B8 | `zide:1129` (`init_resolve`) | `--year` is never validated. | `zide init p … --year abc` → `LICENSE` contains `Copyright (c) abc`. |
| B9 | `zide:2410-2417` (`--std`) | A bare `--std N` sets **both** `C_STD` and `CXX_STD`. `--lang mixed --std 20` therefore dies with `unsupported C standard: 20`, although 20 is a perfectly good C++ default and the user never picked a C standard. | `zide init x --lang c-cpp-mixed --std 20 -y …` → exit 2. |
| B10 | `zide:1090-1095` (`init_resolve`) | Interactive C/C++ standard prompt stores raw input with no validation loop; garbage fails later at `zide:1110-1116` via `die`. In the wizard that aborts the whole flow instead of re-prompting. | `zide -i init ./x`, type `99` at the standard prompt → usage-error exit. (Wizard path; CLI path correctly dies with exit 2.) |
| B11 | `zide:606-615` (`scan_files`) | `find … -print \| sort \| read -r` splits on newlines; filenames containing newlines corrupt `FILES` (and downstream `grep "$ROOT/$f"`, main-detection reads). Spaces are fine (`IFS= read`), newlines are not. | Inspection; fix is `find -print0 … \| LC_ALL=C sort -z … \| while IFS= read -r -d ''`. |
| B12 | `zide:1933-1940` (`init_git`) | Only the final `commit` is failure-tolerant. `git init` / `git add -A` failures propagate through `set -e` into the B4 internal-error trace instead of a warning + continue (the scaffold itself is fine without git). | Inspection (e.g. `safe.directory` denial, read-only disk: `git add` fails → `internal error …`). |
| B13 | `zide:1958` (`init_bare_remote`) | `git init -q --bare "$remote"` failure propagates via `set -e` (same B4 shape). | Inspection. |
| B14 | `zide:2216-2229` (`wizard_init`) | A pre-filled invalid `--lang` (`zide -i init ./x --lang frobnicate`) hits `norm_lang … \|\| die`, killing the entire wizard instead of re-prompting. | Inspection. |
| B15 | `zide:919,1977` | `ROOT=$(safe_path …)` relies on `die`-in-command-substitution + `set -e` to propagate the exit code. Verified working today (protected path → exit 4, message visible), but fragile and opaque; make it explicit. | `zide adopt /` → exit 4 (verified). Harden to `… || exit` so the propagation does not depend on `set -e` subtleties. |

Investigated and **cleared** (kept for the record, no change needed):

- `join_by $',\n'` (`zide:500`): suspected unquoted word-splitting of the separator.
  `$'…'` is a quoting construct — verified `f $',\n' A B` → 3 args, separator intact —
  and mixed-language output shows correct newlines. **Not a bug.**
- `commit_file` chmod branch (`zide:245`): misread `((!DRY_RUN))` as `((DRY_RUN))` during
  review; direct tests (`DRY_RUN=1` → SKIP, `DRY_RUN=0` → chmod) and an end-to-end
  dry-run with a de-executable `scripts/build.sh` confirm dry-run never chmods. **Not a bug.**
- `merge_array` label-less entries (`zide:279-281`): `.label` missing → `$l=null` →
  `index(null)` is null → `not` → entry appended, never wrongly deduped. **Not a bug.**
- `put_file`/`commit_file` symlink handling, `cargo_pkg_name` awk precedence
  (`p && /^name/` ≡ `p && ($0 ~ …)` — correct), doctest `message(…)` parens, `TOK`
  leakage across wizard re-runs (keys always overwritten before use), empty-array
  expansion under `set -u` (fine on Bash ≥4.4): all checked, no action.

## 2. Security and data-loss risks

- **S1 — `safe_path` subdirectory gap (same root cause as B1).** The only filesystem
  guard is exact-match. Operating under `/usr/local`, `/etc`, `/srv`, `/opt` proceeds
  until something else fails. No user data was harmed in probes (mkdir failed on
  permissions), but on a writable system path zide would happily scaffold. **Must fix**
  (add `/*` variants for system roots; keep `$HOME` exact-only).
- **S2 — adopt executes project-controlled build code by default.** `bear -- make -B`
  (`zide:803-804`) runs a real build; `cmake`/`meson configure` evaluate the project's
  build files. Adopting an untrusted tree therefore runs its code unless
  `--no-configure` is passed. The bear path already warns; cmake/meson do not. Keep
  auto-run (current behavior, needed for the out-of-the-box clangd story) but print an
  explicit notice naming the command about to run, and document the risk + opt-out.
  Recorded as a conscious decision, not a silent behavior change.
- **S3 — quoting audit: PASS.** Every path reaching `rm/cp/mv/mkdir/install/ln/find/grep`
  is quoted with `--` (`zide:217,231,254,261,354,362-387,611,669,801,…`). Only gap is
  newline-in-filename (B11). `git add -A/commit` only touches a repo zide just created,
  and is skipped inside existing work trees (`zide:1929-1932`). No change required
  beyond B11/B12.
- **S4 — temp-file handling.** `mktemp "${TMPDIR:-/tmp}/zide.XXXXXX"` is safe;
  `cleanup` only ever removes those. The subshell-EXIT-trap issue (B4) is robustness,
  not a vulnerability (it can only delete zide's own temps, never user files).

## 3. Violations of the design rules (contract)

- **D1 — report stream.** "stdout is for data, stderr is for everything else":
  `print_report` (`zide:897-915`) and both `Next steps` blocks (`zide:956`, `zide:2007-2010`)
  print to **stdout**, while every other human message uses stderr
  (measured: 1440 B stdout vs 79 B stderr on `init`). `doctor` on stdout is correct
  (it *is* data: `zide doctor | grep`). Fix: reports + next-steps → stderr.
- **D2 — report vocabulary.** Code tracks `CREATED/UPDATED/KEPT/BACKUPS` but the report
  prints `created/modified/unchanged/kept`; backups are counted, never listed. Fix to the
  uniform vocabulary `created / updated / unchanged / kept / backup` and list backup paths.
- **D3 — `.gitignore` managed block vs "nothing overwritten without `--force`".**
  `put_block` (`zide:341-359`) intentionally rewrites the file without `--force`
  (user lines preserved verbatim, only the `# >>> zide >>>` block is managed) — the same
  merge-class exception as `.zed/*.json` merging. Not a bug, but the contract text must
  say so. Fixed by documentation, not code.
- Otherwise the contract holds and was verified: no overwrite without `--force`
  (`commit_file` KEPT branch), user keys win on merge (`merge_object .[0]*.[1]`,
  `merge_array` label dedup), `jq` validation pre-write when installed (`put_file`),
  determinism (two same-`--name` runs in different temp dirs → `diff -r` clean),
  dry-run writes nothing (`find` tree identical before/after), re-run idempotent
  (`created: 0 modified: 0 unchanged: 22`), exit codes 2/4/130 as specified.

## 4. UX problems

- **U1 — `usage` (`zide:2016-2070`).** Omits `--build/--build-system`, `--git`,
  `--no-bench`, `--test-framework`/`--language` aliases; ~54 lines, no command/flag
  table. Rewrite: one screen, grouped table, every flag listed.
- **U2 — error messages name the failure but rarely the remedy.** E.g.
  `no C, C++ or Rust sources found under $ROOT` (no hint toward `init` or path check),
  `refusing to operate on protected path` (no hint), `unknown command` (has hint — good
  template). Every error must state what happened, why, and the next command/flag.
- **U3 — `doctor` (`zide:181-190`).** Flat 17-tool dump; hints cover only 11 tools
  (`compiledb/compdb/meson/rustc` missing from hints loop); no required/recommended/
  optional grouping; no color (despite color infra); no summary line; **exit code always
  0** (verified with `rust-analyzer`/`compiledb` missing). Rewrite per spec.
- **U4 — `--dry-run` shows actions, never diffs.** Add capped unified diffs for files
  that would be created/updated/patched so "Preview first" in the wizard is meaningful.
- **U5 — wizard gaps.** No validation loop on std prompt (B10); invalid prefill kills
  the flow (B14); no per-step Back (Cancel exists only at the final Ready menu; Ctrl+C
  is clean — verified cursor restore via `cleanup`). Fix validation; document the
  Cancel/Ctrl-C scope decision (see PLAN).
- **U6 — long operations.** `try_run` prints one `info` line then silence; no elapsed
  time, no notice that project build files are about to execute (S2). Add elapsed time
  to the failure/success path (one line, stderr, no stdout noise).

## 5. Duplication

- `tasks_cmake` preset vs dir branches (`zide:515-534`), meson/make/bazel task blocks
  (`zide:843-864`), `emit_license` MIT/BSD heredocs, `zed_lang_block` two branches.
  All are small, stable, and behavior-critical; unifying them risks drift for no
  functional gain. **Deliberately left as-is.**

## 6. Dead code

- `--build/--build-system` value (B2 — fix by honoring, not deleting; the flag is public).
- `if ((BENCH)); then :; fi` (`zide:1764-1766` — delete).
- `TOK[STRICT_JSON]` vs `TOK[STRICT_ONOFF]`: identical values, different contexts
  (JSON string vs CMake unquoted token). Keep both names; not dead.

## 7. Missing tests

No test suite exists. Required coverage (per task §2.3.2): init×{c,cpp,mixed,rust}×testfw
build+pass (skip with reason when toolchain absent); adopt×{cmake-project, no-build-system,
existing-.zed-merge}; dry-run tree-compare; idempotency (`UNCHANGED`); determinism
(same `--name`, two temp dirs, `diff -r`); protected paths → 4; invalid args → 2 with
message. Harness: plain-bash TAP runner (`tests/`), no new dependencies (bats stays
optional and is *not* required — see PLAN). Plus `Makefile` with `test`/`lint`/`fmt`.

## 8. `set -u` verification

All globals initialized (`DRY_RUN/VERBOSE/FORCE/YES/COLOR`, `ROOT`, `CREATED/…`,
`FILES/DETECT_*/BUILDS/CC_BUILD`, `STYLE/NO_CMAKE/NO_CONFIGURE/C_STD/CXX_STD/…`,
`LANG_SEL/INIT_NAME/TESTFW/LICENSE_SEL/AUTHOR/YEAR/STRICT/GIT/BENCH/BARE_REMOTE/GENERATOR/IDENT/CRATE`,
`POS_CMD/POS_PATH`, `INTERACTIVE/RUN_RC/WIZ_SNAP`, `TOK`, `WARNINGS/TMPFILES/TMP_LAST/OURS`).
`${HOME:-…}`, `${TMPDIR:-…}`, `${NO_COLOR:-}`, `${USER:-…}`, `${INTERACTIVE:-0}` guarded.
Nameref `local -n` needs Bash ≥4.3 — fine for the Bash 5+ requirement. No uninitialized
expansion found; the suite will re-verify by running every command under `set -u`
(which is already global via `set -Eeuo pipefail`).
