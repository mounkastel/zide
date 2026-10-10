# Design notes

`adopt` runs no project code by default. It writes Zed settings, tasks,
clang configs, and a `.gitignore` block, but it never runs CMake configure,
Meson setup, or a compilation database tool on its own. This keeps adopting
an unfamiliar tree safe: nothing the project ships gets executed without
being asked for.

Passing `--configure` opts in to running the build system. Before anything
runs, zide prints the exact command and the directory it will run in. The
interactive wizard asks the same question and defaults to no. `init` is
different: it configures once, on files zide itself just generated.

This default changed in 3.0.0. Earlier releases configured during `adopt`,
so a bare `adopt` produced `compile_commands.json`. Scripts and CI jobs
that relied on that now pass `--configure`. The behavior change was
incompatible, so it shipped as a major release with a Breaking changes
entry, and the fix for existing callers is the one flag.

Three things are deliberately not done. The wizard has no per-step Back
button: entries are checked as they are typed, nothing is written before
the final confirmation, and cancelling there or interrupting is
side-effect-free, so re-running covers corrections. The script is not
restyled to satisfy the formatter: expanding every compact case branch
would rewrite the whole file for no functional gain, while new code
follows the existing two-space style. Duplicated task, debug, and license
blocks stay duplicated: they are small, stable, and build-critical, and
merging them would risk drift between variants.
