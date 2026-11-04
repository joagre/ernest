# Suggestions: the repository's layout

The actions from the walk of 2026-11-04. The reasons are in `temp.txt`.

## 1. Check first

- [ ] Open https://github.com/joagre/ernest/blob/main/docs/log.md and see whether GitHub renders it (2.6 MB). The answer decides 2's log split.

## 2. Before 1.0's launch

- [ ] Add `SECURITY.md`: where to report a security hole privately.
- [ ] If the log does not render: split `docs/log.md` by month into `docs/log/<year>-<month>.md` and so on, with one file there holding the index and the standing sections; the generator and the documents test resolve a citation's title to its file and anchor.

## 3. The restructuring, in one commit with its sweep

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
- [ ] An installation is `bin/` and `build/`; `tools/install.sh` removes an old prefix's `lib/ernest/erl/`

The code that knows the tree's shape (`temp.txt`, *Wrinkles found by reading the code*):

- [ ] W2: the node's code digest covers `build/libs/*/*.beam`
- [ ] W3 and W4: one function lists the toolchain's own code, the libraries' shims among them; `ern_rt:own_modules`, the code digest and `ern_cli:toolchain_modified` ask it; report §11.2 names the shims as the toolchain's own
- [ ] `ern_tree:tree()`, `toolchain_modified`'s climb, the tests' `../../..`, `app.mk`'s `VERSION` and `-I`, the C helper's output, the dialyzer target, `.gitignore`

The documents:

- [ ] `docs/development.md`'s layout, `docs/architecture.md`, the design notes, CLAUDE.md's owner rows, `THIRD_PARTY_LICENSES`, and every cited path the documents test lists
- [ ] Not `docs/log.md`: it is history, and keeps the paths it cites as they were; the documents test does not read it

## 4. Renames and additions, each its own commit, before or after 3

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

## 6. Files (`temp-files.md`)

- [ ] `README.md` ← `temp-README.md`, after the Gleam check; `ern_tour_tests`' cases follow its sessions
- [ ] `guide/why.md` ← `temp-why.md`, after the Gleam check
- [ ] The first claim renamed "Code travels": `guide/why.md`, its anchor `#code-travels`, the homepage, and the site's fixture `test/fixtures/site/tree/guide/why.md` with its expected homepage
- [ ] Gleam's `process.receive` checked against `gleam_erlang`'s current documentation, the call and the claim, in the README, `why.md` and `guide/faq.md`
- [ ] `tools/release/README.md`'s first sentence: the new README's
- [ ] CLAUDE.md redrafted rule for rule: the owner table's `docs/` rows to one, the plain register; then every old rule mapped to a new sentence
- [ ] `SECURITY.md`'s content, decided with the user when this is planned
