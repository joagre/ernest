# A template for an Ernest application

A proposal for `ernest-template`, a repository an Ernest application is begun from by copying. It carries the way of working of this repository, cut to what an application needs: the same procedures, the same documents where they earn their place, and nothing that exists here only because this repository builds a language. Begun 2026-10-20; its ten decisions were discussed one at a time and decided with the user the same day, section 9.

## 1. What it is for

An application written in Ernest is not the language. It has no report of its own, no compiler, no Erlang, no twelve readers, and no section numbers for tests to cite. What it shares with this repository is the way of working: a plan that says what is built and when, a log that says why, a proposal discussed until it is solid, a test before every commit, a read-back before a report, a stop after each item, and the owner of each fact decided before a sentence is written.

The template holds that way of working in a form small enough that a new application starts from it in one copy and one edit. It is a template and not a framework: it holds no code of its own but a launcher and one checker, and it decides nothing about the program's design.

A library written in Ernest starts from the same template. It differs from an application in having no `main`, and in two directories that appear when it needs them, section 3 says which.

## 2. What an application needs of the toolchain

Everything the template does, the toolchain does already; the template only chooses the roots and names them once. The facts, each with its section of the report:

- `ern build --source-root src --build-root build src` compiles every module under `src/`, mirroring the tree into `build/`, in dependency order, and removes the stale `.erc` files of modules whose source is gone (§11.1). Without `--build-root` a module compiles beside its source, so the template always names the two roots. A module whose source and dependencies have not changed is not compiled again, so a build with nothing to do ends in the host's start time.
- A module's namespace is its path under the source root (§4.2): `tally.ern` under `src/` is `Tally`, and `tally/parse.ern` is `Tally.Parse`. Each directory between a load-path root and a module is lowercase words joined by `_`; the root's own name is not checked (§11.1, §11.2). The program's entry point is `main` of the module `ern run` is given, or of the one `--main` names (§11.2).
- A test is a top-level `let` of type `Test.Case(m)` in the module it tests (E.24), and `ern test build` runs the tests of every module under the build root, each module in a runtime of its own (§11.2). An application's unit tests therefore live in its modules, and no `test/` directory is needed for them.
- `ern format src` lays every module out, and `ern format --check src` names each that is not in the layout, exiting with status 1 where one is (§11.6).
- `ern doc src` writes a module's documentation as CommonMark where its `.erc` goes, and `ern doc --man src` a manual page instead (§11.4).
- A library is brought in with `--load-path dir`, a root under which modules are found by namespace (§11.2): one of Ernest's own, `build/libs/json` of a checkout or `lib/ernest/build/libs/json` of an installation, each root holding its `.erc` directly, or any built source tree. There is no package manager and no lockfile; a dependency is a directory.
- A compiled module is tied to the `ern` that built it: a module is recompiled when it was compiled by another build of `ern`, and one compiled against another interface, or another standard library, is refused before anything runs, `Main was compiled against another Geo.Shape; build Main again` (§11.1, §11.2). Two patch levels stand on one floor (§8.7), and a patch changes no interface of the library, which the release review holds.
- A program becomes a node by being started with `--config-dir dir` (§8.3, §11.3), which `ern config` creates, and whose `.ernest/` holds a private key; `ern run`'s own options stand before the `.erc`, and the program's arguments after it (§11.2). The operator's side, the directory, the configuration, the service manager and the upgrade, is the deployment guide's, and the template restates none of it.
- Until 1.0 a release of `ern` may refuse a program the previous release accepted, so an application is written for one floor of `ern`, which `ern --version` prints, `ern 0.4.0` for a release and `ern 0.4.0-dev` for a checkout's build.

## 3. The tree

What the copy holds, one line each; a document under `docs/` is named bare in the prose of this proposal, `plan.md` for the plan. A file is in the template only where it has content on the first day; what has none appears when it is first needed, and `CLAUDE.md` names it so that nothing waits for a decision about where it goes.

```
README.md            what the program is, how to build, test and run it, and what
                     each document is
CLAUDE.md            the working rules, section 5, importing docs/style.md
LICENSE              the license
VERSION              the program's version, one line, which make release reads
Makefile             the targets of section 4, one file
.gitignore           *.erc, build/, lib/, test/build/, tools/build/ and .ernest/,
                     which holds a private key
bin/name             the launcher, a POSIX sh script, section 4, renamed for the
                     program on the copy; an application's, not a library's
src/                 the Ernest source, one source root; a module's tests in the
                     module
src/name.ern         the entry module, a placeholder renamed and written on the copy
tools/docs.ern       Docs, the checker: the paths the documents name exist, and each
                     paragraph past about a hundred words is listed; a source root
                     of its own, built into tools/build/ and outside the archive
docs/plan.md         the roadmap and where we are: milestones, each with its items,
                     and the table of those done
docs/log.md          the dated rationale, never normative
docs/design.md       how the program is arranged: its processes, its types, what
                     each module owns, and the glossary of its names
docs/release.md      what a release runs to be ready, section 6
docs/style.md        the rules an Ernest program is written by, a verbatim copy of
                     this repository's, its first line naming the release it was
                     cut from; no application edits it
lib/                 not committed: each dependency as make lib unpacks it, each
                     of Ernest's own libraries the program wants, and each Erlang
                     application's ebin and priv, section 4
build/               not committed: what ern build writes
```

What appears when needed, named in `CLAUDE.md`:

- `language_feedback.md`, at its first line: what writing Ernest felt against the principles, in the shape of this repository's file, so that a line is carried to it by copy. The template's applications are where the language is used in anger, and this file is the road back.
- `findings.md`, while a review's findings are open, with the same rule as here: it goes when every line is done, dropped or planned.
- `proposals/`, with the first proposal, a directory for each, as here.
- `test/`, for what a module's tests cannot do: a program run end to end, started with arguments and standard input by `Os.run` and its output held to what is expected by `Test.equal`. It is a second source root of Ernest modules, built into `test/build/` against `build/` and run by `ern test`, so that one tool runs every test; it holds no scripts.
- `THIRD_PARTY_LICENSES`, with the first borrowed file; `ACKNOWLEDGMENTS.md`, with the first name.
- For a library: `examples/`, with its README listing the programs by topic, and `docs/man/`, which `make man` writes and a release commits.
- `erl/`, for a program that stands on Erlang code: one read-only git submodule per Erlang application, pinned to a commit and never a copy, which `make lib` builds by the application's own `make`; the repository is cloned with `--recursive`.

## 4. The Makefile, the launcher and the archive

One Makefile at the top, which names the roots once. The variables an application edits stand first; the targets follow and are the same in every application, so that a reader who knows one knows all. Eight targets: `all`, `test`, `format`, `doc`, `run`, `lib`, `release` and `clean`; there is no light run and no full run, since an application's whole suite runs in seconds, and where one day it does not, that is a defect of the tests to measure, as *The tools are fast* says.

```
NAME        = tally               # the launcher and the entry module, src/tally.ern
ERN_VERSION = 0.4                 # the floor, section 2
LIBS        = json                # Ernest's own libraries the program wants
DEPS        = https://github.com/joagre/ernest-websocket/releases/download/v0.3.0/ernest-websocket-0.3.0.tar.gz
ERL_DEPS    = tree_db epx         # the Erlang applications under erl/, in build order
```

The entry point is `main` of the module the launcher is named for, `src/<name>.ern`; an operator who wants another runs `ern run --main` directly, as the deployment guide shows. A library sets `NAME` for its archive alone and has no launcher.

**The load path.** Everything a program loads beyond the standard library stands under `lib/`: `lib/<name>/build` for Ernest's own libraries and for dependencies alike, and `lib/<app>/ebin` for an Erlang application, with its `priv` linked beside it, so that the load path is the one glob, `lib/*/build` and `lib/*/ebin`, in the Makefile and the launcher both, and no path is written twice. `ern run` adds each load-path directory to the host's code path, so the host finds a NIF and an application's files from `priv/` beside `ebin/` as it does anywhere. `make lib` makes it: for each of `LIBS`, `lib/json/build` is a symbolic link to Ernest's root of that library, found beside `ern` under `../lib/ernest/build/libs` and then `../build/libs`, and refused with both paths where neither is there; for each of `DEPS`, the archive is fetched and unpacked under `lib/` where its directory is not there already. A dependency is named by its archive's URL alone, whose last component names the directory, `ernest-websocket-0.3.0`, and whose version is the pin. A dependency a dependency needs is listed too, before it, since `all` builds them in the order listed; the template resolves nothing, which is Ernest's decision for another day.

**The build.** `all` checks the floor, then builds each dependency's `src/` into its own `build/` with `lib/*/build` on the load path, then the application's `src/` into `build/`. A dependency is built by the consumer's own `ern`, whatever built the archive, and §11.1's rule makes that free where nothing changed.

**The tests.** `test` runs `ern format --check` over every source root, `ern test build` with the load path, the checker's build into `tools/build/`, its tests and its run, and, where `test/` exists, its build into `test/build/` and `ern test test/build`. Each root beside `src/` builds into a `build/` of its own, so that `ern test build` runs the program's tests alone and the archive holds the program alone.

**The floor.** `version` compares the first two numbers of `ern --version` with `ERN_VERSION` and refuses another floor with both texts, `ern 0.4 expected, ern 0.5.0 found`; a development build of the floor passes. `release` demands a release and refuses a development build, since the archive's compiled modules go to machines that run a release.

**The launcher.** `bin/<name>` runs `ern run` on `build/<name>.erc`, the module its own name names, with the load path `lib/*/build` relative to its own directory, so that an operator and a service unit run one command from a checkout and from an unpacked archive alike. It forwards a leading `--config-dir dir`, the one option an operator gives, to `ern run`, and everything after it to the program. A library has no launcher, and its `run` refuses with a sentence.

**The archive.** `release` runs `test`, then writes `build/<name>-<version>.tar.gz`, which unpacks to `<name>-<version>/` holding `bin/` where there is one, `src/`, `build/`, `lib/` with each link copied through, `README.md` and `LICENSE`. One shape for an application and a library, so that any archive can be a dependency and `make lib` reads one shape. The source travels so that a consumer builds the modules with its own `ern`; the compiled modules travel so that an operator runs the application as it is, under any release of its floor. The `lib/` that travels serves the operator, for whom the archive is whole; a consumer's load path is its own `lib/*/build`, so a consumer lists every dependency itself, and an archive's `lib/` is not read as one.

`clean` removes `build/`, `test/build/` and `lib/`, which `make lib` restores.

## 5. The working rules

`CLAUDE.md` is a cut of this repository's, kept under about a hundred lines, and reads in the same order: authority, owners, before code, design, defects, tests, writing, done. Each rule of this repository's file is kept, changed or dropped as the table says; a rule not in the table is kept as it is.

| Rule here | In the template |
|---|---|
| The report is the only normative document | **Changed.** The report and the guide are the language, Ernest's installation holds them, and the application changes neither. The application's own normative document is `design.md` with the plan item being built; a design question is decided in a proposal first. |
| Section 0 is the tiebreaker | **Kept.** The five principles judge the application's design as they judge the language's: a feature enters or stays out by them, and the log names the principle that decided. |
| The owners table | **Changed.** Six owners: `README.md`, `plan.md`, `log.md`, `design.md`, `release.md`, the code and its tests; `language_feedback.md` and `findings.md` while they exist; `docs/style.md` is Ernest's and owned here. |
| Proposals, handouts and scratch | **Kept** whole. |
| Where a sentence goes | **Kept.** |
| The implementation is Erlang, OTP 29 | **Changed.** The application is Ernest, for one floor of `ern`, which the Makefile names. |
| Work on `main`, no branch of a session's own | **Kept.** |
| A coding job of many steps goes to an agent; name the model at a change of kind | **Kept.** |
| A commit names its paths | **Kept.** |
| The report changes first | **Changed.** The design changes first: an anomaly found while building changes `design.md`, then the log, then the code. |
| A changed rule rewrites its soundness paragraph | **Dropped.** |
| A design is discussed in its proposal until the user says it is ready | **Kept.** |
| State a change to the plan and make it; leave no decision pending | **Kept.** |
| Prefer minimal, direct implementations; judge features on the principles; bring options | **Kept.** |
| The tools are fast; what Ernest adds costs a fraction; beautiful inside and out; no fixed sleep | **Kept.** The measure is the application's own: a test or a tool that costs more than its work is named to the user. |
| Shims | **Changed** to one rule: the application is Ernest, and `foreign` is only what the host alone can do. A function the library lacks is not written in Erlang meanwhile; it goes to `language_feedback.md`, and the application waits or writes it in Ernest. |
| No warts; fix a known defect when found; memory is a defect at its cause | **Kept.** |
| Nothing routes around a defect or a gap | **Changed.** A defect of the toolchain or a gap in the library goes to `language_feedback.md` for the user to carry to Ernest, and what needed it says that it waits in the plan. The application does not fork Ernest and does not work around it. |
| A published specification is a library's work | **Kept.** Whether the library is the application's own under `src/`, a dependency under `lib/`, or asked of Ernest is decided with the user. |
| Writing Ernest tests the language | **Kept**, and is the template's reason to exist. |
| Where the report is silent, add the sentence or reject the input | **Changed.** Where the design is silent, add the sentence to `design.md` or reject the input with an error; never accept it silently. |
| Every report section has a test | **Changed.** Every section of `design.md` has a test whose doc block names it, and every function the module exports has one. |
| A test written after the code is a regression test | **Kept.** |
| `make test` before every commit; `make test-full` before closing an item | **Changed.** `make test` before every commit, and before the commit that closes an item the same with a fresh clone where the item touched the build. |
| A proposal's edits are committed at a pause | **Kept.** |
| Readers before a release | **Changed** to section 6's two readers. |
| The report and the guide are tight, in a Wirth register | **Changed.** `design.md` states the design in that register; the plan, the log, a proposal and a commit message are plain and short. |
| A paragraph is one turn of the text | **Kept**, with the checker listing the long ones. |
| A report edit updates the revision date; section numbers never change | **Dropped.** `design.md` is not cited by number from outside the repository. |
| Compiler behavior goes to §11 | **Dropped.** |
| American English; no document names who proposed an idea | **Kept.** |
| Read the result back before reporting | **Kept.** |
| Commit only after the checks pass; push only when the user says | **Kept.** |
| Every message that reports code work ends with *Report conformance* | **Changed** to *Design conformance*: the sections of `design.md` applied; every place the design was silent and what was done; every deliberate omission with the item that lifts it; and every line added to `language_feedback.md`. |
| Stop after each plan item | **Kept.** |
| Closing an item, the ten lines | **Changed** to the lines that survive the table, about seven. |
| The glossary is living | **Kept**, in `design.md`'s glossary; the Ernest glossary is `docs/style.md`'s and not edited. |
| `docs/style.md` imported | **Kept**: the template's `docs/style.md` is imported the same way, and is a copy, decision 5. |

## 6. The release

`release.md` is what a release runs, in five lines where this repository's has five sections.

1. A fresh clone builds and passes: `git clone`, `make test`, in a directory of its own.
2. Two readers, each a session of its own, given its brief and the files and nothing that argues for them: a cold reader, who reads `README.md` and runs the program as a user would, and a code reader, who reads `src/` against `design.md`, the principles and E.0's shape rules. The findings are sorted as here: a defect is fixed or planned, clarity fixed where cheap and otherwise dropped.
3. `VERSION` set, the tag, and the archive `make release` writes, published beside the tag so that `make lib` can name it.
4. The notes say what the release is and what a user of the previous release changes, and list none of the changes.
5. `language_feedback.md`'s lines carried to Ernest, so that a release of the application leaves nothing the language has not heard.

There is no full review and no principles review: the two readers over an application's size are the full review, and the principles are the language's to review.

## 7. What the template asks of Ernest

Four things the template would rather not carry itself. None is needed for the first copy; each is a line for this repository's `docs/language_feedback.md`, written when the template exists and not before.

- **The style rules an application follows are not installed.** `docs/style.md`'s rules of an Ernest program, *Every language* with *Names* and *Structure*, the *Ernest* section and the Ernest part of the glossary, bind every Ernest program, and an installation holds the report and the guide but not them. Were the file split into the rules of Ernest programs and the rules of this repository, and the first installed under `share/doc/ernest/`, the template's `CLAUDE.md` would import it there and copy nothing.
- **A program cannot ask where the libraries are.** `make lib` guesses from where `ern` is, `../lib/ernest/build/libs` and then `../build/libs`. A way for `ern` to say its library root, as the shell knows it, would make the guess a fact.
- **A program cannot know its own version.** `VERSION` names the release, and a program that prints `--version` keeps the same text in a `let`, which a test holds equal to the file. A build that could hand the module a value would make one owner of two.
- **A dependency's dependencies are the consumer's to list.** The template lists archives and resolves nothing. Whether Ernest decides how a library is fetched, pinned and resolved is a decision of its own, and the template follows it when it comes.

## 8. What the template does not do

- It does not ship an empty file or directory. A README under `test/` with nothing to list is a promise, and the tree of section 3 is only what has content.
- It does not copy this repository's `test/`, its EUnit, or a Makefile under `test/` or `src/`. Ernest's tests are in the modules, and one Makefile builds everything.
- It does not copy `docs/README.md`, `development.md` and `architecture.md`. With six documents the top `README.md` lists them in one section, and how the program is arranged is `design.md`'s.
- It does not copy `full_review.md`, `principles_review.md`, `memory.md`, `soundness.md`, `otp_bugs.md`, `diagnostics.md`, `module_doc_template.md` and `docs/man/`. Each exists because this repository builds a language.
- It does not invent a dependency tool. A dependency is an archive unpacked under `lib/`, named by its URL, and the load path is a glob; when Ernest decides how a library is fetched and resolved, the template follows.
- It does not let Erlang in, and holds no `erl/`. `foreign` is for what the host alone does.
- It does not run in a continuous-integration service, decision 8.
- It does not let the rules live in two places. An application is a copy of the template, and what an application learns about the way of working goes back to the template by hand, and from there into the next copy. A file that is a copy, `docs/style.md` and `Tools.Docs`, is refreshed in an application by copying the file again.

## 9. The decisions

Discussed one at a time with the user and decided 2026-10-20. Each with the argument that decided it.

1. **The names.** `ernest_template` here, as the other proposals' directories are named, and `ernest-template` on GitHub, a repository of its own. A directory inside this repository would drag an application's starting point into every release of the language. Decided as recommended.
2. **One Makefile**, at the top, with the eight targets of section 4. A Makefile per directory sends a reader to three places to learn what `make test` runs, and an application has no Erlang to compile and no light run to be lighter than. Decided as recommended.
3. **Tests live in their modules**, and `test/` appears only for end-to-end runs, as Ernest modules run by `ern test` and not as scripts, so that one tool runs every test and the tool is Ernest. A large fixture becomes a module of its own that only the tests use. Decided as recommended, the end-to-end runs changed from a script to Ernest in discussion.
4. **Five documents**: `plan.md`, `log.md`, `design.md`, `release.md` and `proposals/`, with `language_feedback.md` and `findings.md` appearing at their first line. `development.md` folds into `README.md`, `architecture.md` into `design.md`, which splits into a directory only when one file no longer reads, a decision of that application's. `release.md` is named for the five lines it holds. Decided as recommended.
5. **The Ernest style rules** are a verbatim `docs/style.md`, the parts that bind an Ernest program, its first line naming the release it was cut from, imported by `CLAUDE.md` with `@` as here, until Ernest installs them. A copy as a file is refreshed by copying the file; a section inside `CLAUDE.md` is refreshed by hand. Decided for the file, where the proposal had recommended the section.
6. **The Makefile pins the floor of `ern`**, `0.4`, and refuses another with both texts; a development build of the floor passes, since the applications are written against a checkout's `ern` to drive the language; `make release` refuses a development build. An exact match would have refused the user's own workflow on day one. Decided as recommended, the match changed from exact to the floor in discussion.
7. **A dependency is a release archive**, unpacked under `lib/` by `make lib`, named by its URL, built by the consumer's own `ern`, and `lib/*/build` is the whole load path; no `deps/`, no source checkout of a dependency, no tool. The user brought the archive as the unit, which the proposal had not seen; the report's rule that a compiled module is tied to its `ern` put the source into the archive. Decided so.
8. **Continuous integration**: not in the template. A workflow must install OTP 29 and build Ernest before the application's seconds of tests, twenty lines that break with Ernest's build in every copy; the release's fresh clone does the job by hand. A release archive of Ernest that installs without a build, or a published action, would change the verdict. Decided as recommended.
9. **The checker is an Ernest program**, `Tools.Docs`, written in the template as its first program: a tool's work is written in Ernest, which the template exists to carry, and the first Ernest written against the template is its first language feedback. A copied script would be a second owner of what this repository's script says. Decided as recommended.
10. **One template for an application and a library**, `MAIN` empty for a library, and one archive shape with the source always in it, so that any archive can be a dependency. Decided as recommended.

## 10. The read-back

The design read back whole after the ten, as a reader who knows Ernest would, and what surprised, each decided here.

- **The load path had two owners.** The Makefile guessed where Ernest's libraries are and the launcher would have had to guess again at run time, on the operator's machine. Decided: everything on the load path stands under `lib/<name>/build`, Ernest's own libraries by a link `make lib` makes and the archive copies through, so that the glob is the one owner and the guess lives in `make lib` alone.
- **The launcher could not tell `ern run`'s options from the program's.** Decided: it forwards a leading `--config-dir dir`, the one option an operator gives, and the rest to the program; `ern reload` and `ern stop` the operator runs directly, as the deployment guide says.
- **A dependency's build needed the other dependencies.** Decided: `DEPS` is in build order, a dependency before what needs it, and `all` builds them in that order with `lib/*/build` on the load path; the template resolves nothing.
- **A second source root's build under `build/` would have run its tests twice**, since `ern test build` runs every module under it. Decided: `test/` builds into `test/build/`, which is the directory the user's first list named.
- **A development build's archive.** Decided: `make release` refuses it, section 4.

Found while the template was built, the same day:

- **The checker under `src/` would have gone into every archive**, so that two dependencies begun from the template would both carry `Tools.Docs`, one module name under two roots of the load path. Decided: the checker is `Docs` under `tools/`, a source root of its own built into `tools/build/`, outside the archive, as `test/` is.
- **`MAIN` said what the launcher's name says.** The launcher runs the module it is named for, and the Makefile's `NAME` names both. Decided: no `MAIN`; `ern run --main` is the operator's.
- **A template cannot ship an empty directory**, and `make` on a copy with no `src/` fails in `ern`'s words. Decided: `name.ern` under `src/`, a placeholder entry module the copy renames and writes, so that the template's own `make test` is green and a copy begins green; `docs/proposals/` appears with the first proposal.
- **A document that names a file that appears later** fails the checker, which holds every backticked path to what is there. Decided: such a file is named bare, `language_feedback.md` under `docs/`, as this proposal names the template's documents.
- **How a copy is made.** Decided: `ernest-template` is a GitHub template repository, *Use this template* making the copy, and is tagged when the way of working changes; the copy's first log entry names the tag, from which `docs/style.md` and the checker are refreshed. No archive of the template is made.

Found by the first copy, `ernest-epx`, the same day, and built as the template's `v0.2.0`:

- **An Erlang application is not a dependency `make lib` fetches.** epx, the pixel library the first copy stands on, is Erlang with a NIF and its own Makefile, with tree_db beside it. Decided: an Erlang application is a read-only git submodule under `erl/`, pinned and never copied, named in `ERL_DEPS` in build order, built by its own `make` and linked as `lib/<app>/ebin` and `priv`; the load path gains `lib/*/ebin`. rebar3 was set aside: epx's port configuration is rebar2's, its dependency unpinned, and the tool is not on the machine. Tried before being written: a pixmap made, filled and read through the NIF from a scratch Ernest program.

## 11. Once decided

Built 2026-10-20, the repository's first commit: its files as section 3 lists them, `CLAUDE.md` as section 5 cuts it, the Makefile, the launcher and the archive as section 4 says, and `Docs`. Its `make test` is green against the checkout's `ern`, its archive was made by the release's recipe and run from where it was unpacked, and the archive was fetched and built as a dependency of a second copy. The tag and the repository on GitHub are the user's. The first application is copied from it, and what the copy teaches comes back to the template, and to this proposal's record where it changes the design.

In this repository nothing changes but four lines of `docs/language_feedback.md`, section 7's, and one sentence of `README.md` that says where an application begins, once the template exists.
