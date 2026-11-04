# Suggestions: the repository's layout

The actions from the walk of 2026-11-04. The reasons are in `temp.txt`.

## 0. Before anything is built

- [ ] An independent reader, one who has not heard this proposal's reasoning, reads this checklist and the tree, asked what breaks and what it misses; its findings are decided before 3 begins (decided with the user 2026-11-04)

## 1. Checked

- [x] GitHub does not render `docs/log.md`, 2.6 MB: checked by the user 2026-11-04. So 2's split is needed, and the site's citations of the log, which link its anchors on GitHub, are broken until it is made.

## 2. Before 1.0's launch

- [ ] Add `SECURITY.md`: where to report a security hole privately.
- [ ] Split `docs/log.md` by month into `docs/log/<year>-<month>.md` and so on, with one file there holding the index and the standing sections; the generator and the documents test resolve a citation's title to its file and anchor.

## 3. The restructuring, in one commit with its sweep, after MVP 4.2 closes and before MVP 4.15's item 2

Moves:

- [ ] `erl/lexer/`, `parser/`, `checker/`, `emitter/`, `formatter/`, `cli/` → `src/toolchain/<app>/`
- [ ] `erl/shared/` → `src/shared/`: the toolchain and the runtime both use it (`ern_tree`)
- [ ] `erl/cli/src/ern_node.erl`, `ern_carrier.erl`, `ern_gateway.erl`, `ern_exchange.erl`, `ern_arrival.erl`, `ern_epmd.erl`, `ern_code_load.erl` → `src/nodes/`, with their tests
- [ ] `erl/cli/src/ern_shell.erl` → `src/shell/ern_shell.erl`, with its tests; its `.beam` in `build/shell/ebin`, on the launcher's code path, since `ern_cli` runs the shell's job through it
- [ ] `erl/runtime/` → `src/runtime/`
- [ ] `erl/json/src/ern_json.erl` → `src/libs/json/ern_json.erl`, its test to `src/libs/json/test/`; the same for `http` and `base64`
- [ ] `tools/ern_site.erl` → `tools/site/ern_site.erl`, beside the generator it serves; `site.ern`, `site/` and `manual.ern` stay in `tools/`, a source root
- [ ] `tools/release/` → `release/`
- [ ] An app's inner `src/` goes: its modules stand beside its `include/` and `test/`

The build:

- [ ] Every build product under `build/`: `build/toolchain/<app>/ebin`, `build/shared/ebin`, `build/nodes/ebin`, `build/runtime/{ebin,priv}`, a shim's `.beam` beside its library's `.erc` in `build/libs/<lib>/`
- [ ] Tests compile into `build/toolchain/<app>/test/`, never an `ebin`; the three `is_test` checks go
- [ ] One generic rule compiles every app and every library's shim; the per-app Makefiles go
- [ ] `erlc -I src -I src/toolchain`, for `-include_lib` of the toolchain's headers and of `runtime/include`; the exact form confirmed by a probe
- [ ] The launcher: `-pa "$tree"/build/toolchain/*/ebin -pa "$tree"/build/shared/ebin -pa "$tree"/build/nodes/ebin -pa "$tree"/build/runtime/ebin -pa "$tree"/build/shell/ebin`
- [ ] An installation is `bin/` and `build/`; `tools/install.sh` removes an old prefix's `lib/ernest/erl/`, and the release's line in `CHANGES.md` says the installed layout changed, for a script that points inside an installation

The code that knows the tree's shape (`temp.txt`, *Wrinkles found by reading the code*):

- [ ] W2: the node's code digest covers `build/libs/*/*.beam`
- [ ] W3 and W4: one function lists the toolchain's own code, the libraries' shims among them; `ern_rt:own_modules`, the code digest and `ern_cli:toolchain_modified` ask it; report §11.2 names the shims as the toolchain's own
- [ ] `ern_tree:tree()`, `toolchain_modified`'s climb, the tests' `../../..`, `app.mk`'s `VERSION` and `-I`, the C helper's output, the dialyzer target, `.gitignore`

The documents:

- [ ] `docs/development.md`'s layout, `docs/architecture.md`, the design notes, CLAUDE.md's owner rows, `THIRD_PARTY_LICENSES`, and every cited path the documents test lists
- [ ] Not `docs/log.md`: it is history, and keeps the paths it cites as they were; the documents test does not read it

## 4. Renames and additions, each its own commit, before or after 3 and before MVP 4.4's full review

A rename of a document changes, in its own commit, CLAUDE.md's owner row and `docs/README.md` where they name it.

- [ ] `examples/tally.ern` → `examples/wc.ern`
- [ ] `examples/word_count.ern` → `examples/word_frequency.ern`
- [ ] `examples/repl.ern` → `examples/interpreter.ern`
- [ ] `examples/typed_channels_nodes.ern` → `examples/remote_counter.ern`
- [ ] `test/fixtures/expected/` → `test/fixtures/outputs/`, and the outputs of the renamed examples with it
- [ ] `test/fixtures/golden/` → `test/fixtures/emitted/`
- [ ] `test/*_costs.erl`, `ern_bench.erl`, `ern_measure.erl`, `ern_last_run.erl` → `test/bench/`
- [ ] `docs/style.md` → `docs/code_style.md`
- [ ] `docs/release_review.md`, `full_review.md`, `principles_review.md` → `docs/reviews/release.md`, `full.md`, `principles.md`
- [ ] `docs/memory.md` → `docs/memory_checks.md`
- [ ] `editors/emacs/test/broken/` → `editors/emacs/test/half_typed/`
- [ ] Add `site/README.md`: a few lines pointing at `docs/development.md`'s layout and `site/templates/README.md`
- [ ] Add `docs/proposals/fides/README.md`
- [ ] `.gitignore`: `*.erc` under the build's heading; drop `.env` and `.env.local`

## 5. Rules

- [ ] CLAUDE.md's *Proposals*: a proposal refused or not taken up stays, its README's status line saying which; only a built one goes

## 6. Files (`temp-files.md`), before MVP 4.4's full review

- [ ] `README.md` ← `temp-README.md`; `ern_tour_tests`' cases follow its sessions, and its sessions' start lines are brought to `VERSION`, which `make version` leaves a proposal's as written
- [ ] `guide/why.md` ← `temp-why.md`
- [ ] The first claim renamed "Code travels": `guide/why.md`, its anchor `#code-travels`, the homepage, the site's fixture `test/fixtures/site/tree/guide/why.md` with its expected pages, and the homepage rule of `docs/proposals/site/decisions.md`, live while MVP 4.2 is open
- [x] Gleam's `process.receive` checked 2026-11-04 against `gleam_erlang` v1.3.0's documentation: the call is `receive(from subject, within timeout)`, and a process that does not own a non-named subject panics when it receives with it. The drafts write `process.receive(subject, 1000)`, which "compiles wherever a subject is in hand, and panics at run time in a process that does not own it"; `guide/faq.md`'s two sentences, the typed send and the reply `Subject`, stand as they are
- [ ] `tools/release/README.md`'s first sentence: the new README's
- [ ] GitHub's About blurb, the day the new README lands, follows its opening: "A small BEAM language built around code that travels. A process started on another node brings its code along, and the compiler checks every send against the mailbox it reaches." Today's blurb follows the old opening
- [ ] `site/projects.md` linked from `README.md`, a line in the draft's *Where to begin* with `temp-files.md`'s kept links following; from the guide's §13; and from the end of `tour/README.md`. `guide/why.md`'s *Reading on* has its link, and `temp-why.md` keeps it. Each is the relative path, decided with the user 2026-11-04: GitHub and the site resolve it, and in an installation, which holds no `site/`, it leads nowhere, as the guide's §13's link to `docs/log.md` does
- [ ] Before it, the harvest: the four repositories' CLAUDE.md read side by side, a sibling's clearer wording or applicable rule taken into Ernest's draft (`temp-other-repos.md`, item 5)
- [ ] A standing rule in Ernest's CLAUDE.md and the template's: a good rule found in an application goes to the template, and to Ernest's where it applies, and from the template to the other copies
- [ ] CLAUDE.md redrafted rule for rule: the owner table's `docs/` rows to one, the plain register; then every old rule mapped to a new sentence
- [ ] `SECURITY.md`'s content, decided with the user when this is planned
