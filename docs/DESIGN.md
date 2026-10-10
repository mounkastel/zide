# Design notes

zide is a single script. The install story is the product: copying one
file into `~/.local/bin` is all it takes. A split into library files
would need a runtime lookup for its own directory, which breaks for
renamed copies and piped installs, or a separate install step every
user would have to run. The single file is organized in delimited
sections, so there is nothing to gain by splitting it.

`adopt` does not run project code by default. It writes Zed settings,
tasks, clang configs, and a `.gitignore` block, but it never runs the
build system on its own. Adopting an unfamiliar tree must be safe, and
build files are code. Passing `--configure` opts in: zide prints the
exact command and directory before running anything, and the wizard
asks first and defaults to no. `init` is different: it configures once,
on files zide itself just generated.

The wizard has no per-step Back button. Entries are checked as they
are typed, nothing is written before the final confirmation, and
cancelling there or interrupting leaves nothing behind, so answering
again covers corrections. A full step-back flow would need a rewrite
of the wizard for little gain (see closed issue #2).

The existing shell style is kept as is. Reformatting the whole script
would rewrite every compact case branch for no functional gain and
bury real changes. New code follows the surrounding two-space style,
and the formatter runs on the test suite only, where it enforces that
same style.

`doctor` defines its required tools globally: `cmake`, `clangd`,
`git`, `cargo`, and `rustc`. Each one gates a default flow, from C
configuration to the initial commit. Everything else degrades
gracefully or is situational, so it is reported as recommended or
optional. With a project path, tools for languages the project does
not use move down a tier, except `git`, which stays required.
