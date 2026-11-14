# Findings of the reading of MVP 4.16's item 6

The reading of 2026-11-14 over commit `f9c5b972`, the plan's item 41, sorted as [`reviews/full.md`](reviews/full.md)'s *The findings* says. One reader, R, a session of its own, read the commit's code and tests against §11.1, §11.2 and §11.9. It was given the report and the commit, and neither the log, the plan nor a proposal.

The reader ran its probes with `bin/ern` in trees of its own. The session ran those of R1, R3, R4, R5 and R6 again on copies of the trees, and each gave what the reader reported. R2, R8 and R9 are read and not run, by the reader and by the session.

## The lines

A line is `fix`, made in the round, the plan's item 42; `decide`, with the user; or `dropped`, with the reason; and `done` with the date once made. A `decide` line carries the session's recommendation.

### The code

- R1 — a FIFO at a module's name in a named package's `src` hangs every `ern build` in the root package, with no output. Directory mode hangs the same way with no package. decide: a `.ern` that reaches no regular file is refused before it is read, in the text `package.conf` and `VERSION` have, and fails that file alone; §11.1 gains the sentence (principles 1 and 2).
- R2 — a file and a directory under a named package are made with the mask's rights and narrowed after, so a file opened in between is written through after the build. decide: the new file is made inside a directory only its owner can enter, as `make_private_dir/1` makes one, and a directory made is listed after its mode is set (principle 1). The narrower promise would be true and of no use against the writer the promise is for.
- R3 — `ern doc --help` gives `--build-root`'s default as the source root, and in a root package it is the package's `build`. fix: the help says so, and `source_root_default_said_test_` holds the text.
- R10 — `Read1` and `Built1` are no later values of `Read` and `Built`. fix: `Manifests` and `PackageStatus`.
- R11 — a tuple of four parts is matched by position across five functions of `ern_package`, and `Read` names two things there. fix: a record for a named package with its manifest as read.

### The report

- R4 — a named package with no `src` builds nothing and says nothing, and so does one whose `src` is a file; two tests expect the first. decide: §11.9 says that a named package with no `src` has nothing built, and a `src` that is no directory is refused, `lib/leaf/src: not a directory` (principle 1).
- R5 — in a root package the argument count is refused after the package's refusals, where an unknown option is refused before them; and a path that is no module is refused after the named packages are built, where a path that names nothing is refused before. decide: the count is refused before the root package is read, as an option is, and every refusal of the given path that reads no source stands before the builds; §11.9 states the order (principle 2).
- R6 — a path that reaches a named package through the target of a link `lib` is not refused, and the build writes there. It is what §11 says of a path as resolved. decide: §11.9 states the narrower promise, that a path is under `lib` as §11 resolves it, and no link is followed (principle 2).

### The tests

- R7 — five sentences no test holds: the fourth rule silent on a root entry not of its form; a `src` that cannot be walked; a named package as the dependent under `ern run`, `ern test`, the shell and `Code.load`; the modules rule finding a module as directory mode does; and standard error, since `said/1` reads the two streams as one. fix: a regression test for each.
- R8 — `package_build_modes` expects `8#644` of a file written again and the mask's group right of the root package's files, and §11.9 says only "by its owner alone". decide: the file written again is held to the report's sentence, no right of the group's or of others' to write; the root package's two assertions stay, since they hold where the sentence ends.
- R9 — three tests pass with their rule broken: `package_build_trial`'s "fails that file alone", `package_build_rules_said`'s "no file is written" and `package_build_failure_passes_on`'s two lines. fix: the first removes `build/app.erc` before its build, the second compares each file's bytes and mode with the dot names among them, the third compares the output whole.
- R12 — a comment in the test of `--verbose` says `ern build` refuses a `VERSION` not of its form, which that test does not run. fix: the half goes.
- R13 — `package_build_trial`, `package_build_order`, `package_roots` and `package_build_given_under_lib` each hold several behaviors, against `code_style.md`'s one. decide: each is split where one part's fixture is not the next's, so that a failure hides nothing after it.

## The reader's list

The probe trees are p1 to p5. Each probe ran `bin/ern`, `ern 0.11.0-dev`, under the mask 0002 unless it says otherwise.

### Defects

1. **A FIFO named as a module in a named package's `src` hangs every `ern build` in the root package.**
   - Place: `src/toolchain/cli/ern_build.erl:109-128`, where `packages_built/4` calls `built_tree(Job, Src, ...)`, and §11.1's directory mode.
   - The commit makes every `ern build` build each named package's `src`, whatever path it is given, a single file among them. A FIFO at `lib/leaf/src/leaf/f.ern` is opened and read, and the job waits forever with no output.
   - The same commit guards `package.conf` and `VERSION` against this, "so that no read waits on it", `ern_package.erl:108-112, 218-222`.
   - The cause is older than the commit: plain directory mode hangs the same way. The commit carries it into every build of a root package, from a directory the user may not have written, such as a package linked by hand.
   - Ran: in p2, `mkfifo lib/leaf/src/leaf/f.ern; timeout 30 ern build src` exited 124 with no output. In p4, a plain directory, `mkfifo src/f.ern; timeout 20 ern build src` exited 124.
   - Fix: refuse a `.ern` that reaches no regular file before it is read, and fail that file alone. §11.1 then needs: "A `.ern` that reaches no regular file is refused before it is read, `src/f.ern: is no regular file`, and fails that file alone."

2. **"Owner alone" is set after each file and directory is made, so a mask that lets others write leaves a window.**
   - Place: `ern_build.erl:2449-2476`, `make_owners_dirs/1` and `owners_alone/1`, and `write_at/4:2346-2349`.
   - Code: `Made = case file:make_dir(Dir) of ok -> owners_alone(Dir); ...` and `[fun() -> owners_alone(New) end || Kept =:= owner_alone] ++ [write ...]`.
   - Under the mask 000, or 002 for the group, `file:make_dir` and `made_beside`'s `file:open(New, [write, exclusive, raw])` first make the entry writable by others, and only then take that right away.
   - A user who opens `.leaf.erc.<pid>.<n>.new` in the window keeps a writable descriptor after the mode changes. Through it they write the `.erc` the root package then loads.
   - A directory another user plants inside a directory just made is used as it is: `filelib:is_dir(Dir)` is true, so the function answers `ok`.
   - `make_private_dir/1:2484` already closes the directory's half, listing the directory after its mode is set.
   - Read, not run: it is a race between two users. Without a race the modes are right: under the mask 000 they were 755 for `lib/leaf/build` and its subdirectories and 644 for its `.erc` files.
   - Fix: make each directory as `make_private_dir` does, and write the new file inside a directory nobody else can enter until the rename. Otherwise narrow §11.9's promise to what the code can keep.

3. **`ern doc --help` gives the wrong default for `--build-root` in a root package.**
   - Place: `src/toolchain/cli/ern_cli.erl:567-570`, `doc_options/0`.
   - Text: `"where the documents go, and where a current .erc is read from; default: the source root"`.
   - The commit changed `ern build`'s help for the root package's `build`, and not `ern doc`'s own text. In a root package `ern doc src` writes under `build/` (§11.1, §11.4).
   - Ran: `ern doc --help` printed `default: the source root`, exit 0. In p1, `ern doc --verbose src` printed `source root src`, `build root build`, `wrote build/main.md`, exit 0.
   - `source_root_default_said_test_` does not check this text.
   - Fix: append `, or the root package's build where that is its src`, and add the text to that test.

### Expectations and behavior the report does not state

4. **A named package with no `src`, or whose `src` is not a directory, builds nothing and says nothing.**
   - Place: `ern_build.erl:114`, `case filelib:is_dir(Src) of false -> {Status, Built#{Name => Package}}`, and `ern_package.erl:570`.
   - The report: "`ern build` then builds each named package ... compiling its `src` into its `build` as it compiles a directory (§11.1)". Read to the letter, a missing `src` is a path that names nothing.
   - With no `src`, or a `src` that is a regular file or a link to nothing, nothing is built and no `source root` line is written. The package's absent `build` stays on the build's load path.
   - `package_build_unused_entry` and `package_build_order` expect this, "a package with no `src` builds nothing", so they hold what the report does not say.
   - Ran in p1: with `lib/leaf/src` absent, `--verbose` gave `manifest package.conf`, `package leaf 1.0.0`, then the root package's lines, exit 0. With `lib/leaf/src` a regular file, the same, exit 0.
   - Missing sentence: "A named package with no `src` has nothing built. A `src` that is there and is no directory is refused, `lib/leaf/src: not a directory`." The second half is a recommendation: today such a `src` is passed over in silence.

5. **In a root package, the order between a refusal of the command line and the package's refusals is unstated.**
   - Place: `ern_cli.erl:284-298, 575-578`, and `ern_build.erl:64` against `packages_built`.
   - With no argument, or with two, `ern build` reads the root package first. Where the package is refused, only its lines are written: `a file or a directory is required` and `one file or directory is taken, and 2 were given` never appear.
   - A path that names nothing is refused before any named package is built. A path that is no module, `notes.txt` or `Notes.ern`, is refused only after every named package has been built.
   - Ran in p1, with `lib/leaf/VERSION` at 1.2.0 against an entry of 1.0.0: `ern build` and `ern build src src` each printed only `ern build: package.conf: the entry for leaf says 1.0.0, and lib/leaf holds 1.2.0; ...`, exit 1.
   - Ran in p2: `ern build nosuch.ern` printed `nosuch.ern: no such file`, exit 1, and nothing was built. `ern build --verbose Notes.ern` compiled `Leaf.Deep.X`, `Leaf` and `Mid`, then printed ``ern build: Notes.ern: path component `Notes` must be lowercase``, exit 1.
   - §11.9 says only "A job reads its root package before what it is given".
   - Fix: refuse the argument count before the root package is read, since it is the command line and not what the job was given. Otherwise state the order, and say that a path that is no module is refused after the named packages are built.

6. **A path through a link to `lib` is not refused, and the build then writes into a named package's `src`.**
   - Place: `ern_package.erl:450-467`, which compares the path as resolved, and §11.
   - In p3, where `lib -> store`: `ern build lib/leaf/src/leaf.ern` is refused. `ern build store/leaf/src/leaf.ern` builds the named packages, then compiles the package's own source as `Store.Leaf.Src.Leaf` into `store/leaf/src/leaf.erc`, a file inside the named package's `src`.
   - This is what the report says: §11 judges a path as resolved, with no link followed. The refusal under `lib` still guards nothing against a path through a link's target.
   - Ran: the first printed `ern build: lib/leaf/src/leaf.ern is the package leaf's, which ern build builds`, exit 1. The second printed `compiled Store.Leaf.Src.Leaf from store/leaf/src/leaf.ern to store/leaf/src/leaf.erc`, exit 0.
   - Missing sentence, the narrower promise: "A path is under `lib` as §11 resolves it: one that reaches `lib` or a named package through a link's target is not refused." Otherwise compare by the path with its links followed.

7. **Sentences no test holds.** Each was run, and the code holds it.
   - a. "Where the root package's entry of that name is not of its form, the rule says nothing of it" (§11.9). In p2, a root entry `mid` at `1.0` and `leaf` needing `mid` from 2.0.0 gave only the form's line, exit 1.
   - b. "A `src` that cannot be walked is refused in the words directory mode has for it (§11.1), in the place of the package's modules". `lib/leaf/src/sub` at mode 000 gave `ern build: lib/leaf/src/sub: permission denied`, exit 1. A name with the byte 0xFF gave `ern build: a name that is not UTF-8: lib/mid/src/m\xFFd.ern`, exit 1.
   - c. A named package as the dependent the hiding refusal names (§11.1's *Names the host holds*, §11.2, E.28), under `ern run`, `ern test`, the shell's `:load` and `:reload`, and `Code.load`. The commit changed `ern_cli:another_interface/4`, `ern_shell`'s `source_refusal/3`, `form_refusal/3` and `another_interface/5`, and `ern_code_load:not_hiding/3`. Only `ern build` and `ern doc` are tested, in `package_hiding_dependent`.
   - c, ran in p5: with a stray `build/base64.erc`, `ern run build/hd_main.erc` printed `ern run: build/base64.erc: Base64 hides the library Base64, which the package hd_server uses`, exit 1. The shell's `:load Base64` printed `src/base64.ern: Base64 hides the library Base64, which the package hd_server uses`.
   - d. "A module is found as directory mode finds one" in the modules rule. No test shows the rule passing over a dot-named file, a link to a directory, or a `lib` beside a `package.conf` under a named package's `src`. Read, not run.
   - e. The stream. Every new refusal's test goes through `said/1`, which captures standard output and standard error together, so no test of the commit holds §11's "on standard error". In p1, `ern build src 2>/dev/null` wrote nothing, and `2>&1 >/dev/null` wrote the rule's line, so the code is right.

8. **`package_build_modes` expects modes the report does not state.**
   - Place: `ern_cli_tests.erl:8722-8727`.
   - Code: `?assertEqual(8#020, mode_of(In("build/bm_main.erc")) band 8#020)` and `?assertEqual(8#644, mode_of(In("lib/bm_leaf/build/bm_leaf.erc")))`.
   - §11.9 says only "may be written by its owner alone". Nothing says the root package's files take the mask, or that a file written again keeps its other bits. A build that wrote 0600 would meet the report and fail the test.
   - Read, not run.
   - Fix: assert `band 8#022 =:= 0` for the named package and nothing for the root package, or add the sentence to the report.

9. **Tests that would pass with their rule broken.**
   - `package_build_trial`, `ern_cli_tests.erl:8198`: `?assert(filelib:is_regular("build/app.erc"))` is meant to hold "fails that file alone" after `src/leaf.ern`'s refusal. The first `Built()` at the test's top already wrote `build/app.erc`, so a build that stopped at the refusal still passes. Fix: delete `build/app.erc` before that build.
   - `package_build_rules_said`, lines 8233 and 8253: "no file is written" is held by `filelib:wildcard("**")`, which compares names alone. It does not see a file written again in place, a mode changed, or a dot name left behind such as `.x.erc.<pid>.<n>.new`. Fix: compare `read_file_info` and the bytes, dot names among them.
   - `package_build_failure_passes_on`, from line 8763: the two "is not compiled" lines are held by `binary:match`. In the second round `build/fp_other.erc` already stands, so one more failure line, `FpOther is not compiled`, would pass. Fix: compare the whole output after the diagnostic.

### Matters of clarity

10. **Numbered names that are not later values of their base.** `docs/code_style.md` says a numbered name "is nothing else" than a later value.
    - `ern_package.erl:87`: `Read1` holds the named packages with their manifests, while `Read` is the root manifest's `#form{}`.
    - `ern_build.erl:122`: `Built1` is a status, 0 or 1, while `Built` is the map of packages.
    - Fix: bind `Manifests` in the first case, and use `PackageStatus` in the second.

11. **A tuple of four parts matched by position across five functions.**
    - Place: `ern_package.erl:87, 162, 186-188, 502, 588-593`.
    - The tuple `{Name, Version, Package, {FormLines, Form}}` passes through `read/3`, `named_packages/4`, `in_built_order/1`, `package_rules/4` and `cycles/2`, and each matches it by position.
    - `docs/code_style.md`: "A value of more than three parts is a record".
    - `Read` also means two things in the module: the root's `#form{}` in `read/3`, and a package's name in `named_packages/4:162`.
    - Fix: a record for a named package placed under `lib`, with its manifest as read.

12. **A test's comment claims what its test does not run.** At `ern_cli_tests.erl:7918`: "`ern build` refuses a `VERSION` not of its form, and the other jobs read no rule". The test runs no `ern build` after writing `1.3\n`; `package_build_version_form` holds that first half. Fix: drop the first half.

13. **Some new tests hold many behaviors in one function.** `docs/code_style.md` says "A test function tests one behavior".
    - `package_build_trial` holds seven rules in sequence.
    - `package_build_order` holds the order, a package with no `src`, `--verbose`, current modules, `--emit-erl` and `ern run`.
    - `package_roots` and `package_build_given_under_lib` are alike.
    - A failure early in one hides every assertion after it. This is a matter of judgment.

### What was read

Read whole: the report's §11 opening, §11.1, §11.4, §11.5, §11.7, §11.8 and §11.9, and §11.2's sentences on a package; the commit's report diff; `ern_package.erl`; `ern_build.erl` lines 36-675, 836-930, 1800-1940 and 2262-2529; `ern_cli.erl` lines 200-440, 560-760 and 1290-1390; `ern_code_load.erl` lines 60-140; every test the commit adds or changes in `ern_cli_tests.erl`, with its helpers, and the new test of the shell.

Read only in the diff: `ern_shell.erl`, `ern_release.erl` and `include/ern_build.hrl`, and the rest of `ern_build.erl`, `is_failed/2`, `source_root/3`, `build_root/2` and `emitted/6`.

Not reached: §11.2 beyond its sentences on a package, E.28 beyond its `Invalid` sentence, and how `--verbose` orders `ern doc`'s lines. In p1, `read Main from build/main.erc` came before `source root src`, an order older than the commit.

Every new test but R9's three tells its rule from its absence: it compares the whole output, or its fixture fails under the wrong behavior.
