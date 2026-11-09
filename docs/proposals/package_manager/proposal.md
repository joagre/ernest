# Packages

Under discussion. All of it is tentative, and nothing flows from it into the report, the plan or the log. It answers seven questions in order, each with its argument and its verdict, so that the whole can be inspected at once. [`trial.md`](trial.md) tries it on what exists, and [`other_systems.md`](other_systems.md) says what other systems do.

## The whole of it

A package is a directory with a manifest, `package.conf`, its version in `VERSION`, its Ernest under `src/`, and the packages it loads under `lib/`. It is what a library of Appendix G is, living elsewhere.

Ernest gains four things.

1. **One file.** `package.conf` names the least release of Ernest the package is written for, and every package its build loads, a line each.
2. **One rule.** A job finds `package.conf` in the directory it is started in, where it is given nothing or a file of that directory, and puts each named package on the load path. It gains no option.
3. **One job.** `ern unpack` checks the digest of each named package's archive, which the author downloaded, and unpacks it under `lib/`. No job touches the network.
4. **One check.** `ern build` reads each package's own manifest as a set of claims, and holds each claim against the root's lines.

There is no resolver, no lockfile, no registry, no installation shared between programs, no network, and no code of a package run while it is unpacked or built.

## The manifest

```json
{
  "ernest": "0.10.0",
  "packages": [
    {
      "name": "epx",
      "version": "0.2.1",
      "url": "https://github.com/joagre/ernest-epx/releases/download/v0.2.1/epx-0.2.1.tar.gz",
      "sha256": "9f2c..."
    }
  ]
}
```

It is JSON, as `ernest.conf` is (Appendix C), and is named beside it. A line holds one version. A version is three numbers, compared as numbers, and no version before a release is named: a checkout between releases states the version it works toward.

The manifest holds what nothing else knows: what the package needs. Its own name and version are not in it. A package's name is its directory's, `lib/epx`, and its archive's, `epx-0.2.1.tar.gz`. Its version is its `VERSION` file, one line of three numbers, which its Makefile reads too. So each of the two has one owner.

## 1. Does the tool ever choose a version?

Never.

A package's manifest names every package its build loads, whether its own modules name it or a package it loads does. The lines are read in two ways.

**As the root.** The package being built is the root. It builds with exactly the version each of its lines writes.

**As a dependency.** Each line is a claim: this package works with that one from `version` on. The root must hold a line for the same package whose version is that or later. Where it does not, the job is refused with the line to write, in the form §11.2 gives a refusal over a file: the job, the file, and what is wrong.

```
ern build: package.conf: http 0.4.0 needs json from 1.3.0, and the line for json says 1.2.0
ern build: package.conf: http 0.4.0 needs time from 1.1.0, and no line names time
```

So `version` is one number with two readings: what I build with, and the least I accept. The manifest is exact, so no lockfile says it again (principle 2). What is built is what the text says, on any day and any machine (principle 3). Nothing lists the versions that exist, so nothing needs an index.

The check is one level deep. Every manifest is whole, so the root reads the manifest of each package it lists and walks no further.

**No upper bound.** The checker is the ceiling: the root compiles every package from its source, so a later version that breaks an interface is refused where it is built. An upper bound would add only a guess about releases not yet made, and it would refuse every package above a library at each of its large releases until each author wrote a new line.

**A break takes a new name.** A later version under one name keeps what the earlier ones gave. A release that does not is another package, `json2` providing `Json2` (question 3). The two then stand in one build side by side, which one name could not. The rule is the author's promise; the checker holds its interface half.

The rule has no exemption, a version before 1.0 among them, and its cost is plain. Ernest writes a namespace at each use, with no second name for it, so a new name is a change at every line that uses the package. And nothing checks the promise's other half: a package that breaks under its old name is found by the checker or by the tests of whoever loads it.

Ernest has a line too. `ernest` is the least release the package is written for, and the running `ern` must be that or later. It is a claim in the root's manifest as in any other, since the running `ern` is what it is. Before 1.0 a release may refuse a program the one before accepted, and a package written for an earlier one is then refused by the checker, in its own source.

A line that nothing needs is accepted, as §0 accepts what the text shows only unused.

**Across nodes** nothing of this is asked. Two nodes that hold different versions of a package work together, since a definition crosses by its hash (§8.7). No definition's hash is used in a build: a hash says what code is, between nodes, and a manifest says what a build loads.

**The cost.** An upgrade deep in the graph is an edit by hand in the root, one refusal at a time. That is the price of an author who knows the whole of what the program loads. And a later version that changes what a function does, its type unchanged, is found by the program's tests and by nothing in the manifest.

**One version of a package in a build** follows from §4.2, where a namespace has one module. Two lines of one name are refused.

## 2. How does a job learn its package?

It finds `package.conf` in the directory it is started in.

`ern build`, `ern doc`, `ern run`, `ern test`, `ern shell` and `ern unpack` each read the working directory's `package.conf` where there is one. A directory without one is no package, and the job runs as it does today. No job looks in a directory above.

The manifest is read for the package's own work alone: where the job is given nothing, or a file or a directory under the working directory. A job given a file from elsewhere reads no manifest, so that a program is not handed the modules of a directory its user only stands in.

It is what `make` does with its Makefile, and the daily commands carry no flag. §11's sentence, that a job reads from the directory it is started in only what its command line names, takes this file as its one exception.

**Every job** puts on the load path the build of each named package, `lib/<name>/build`, in the manifest's order, before the toolchain's own libraries. `ern run`, `ern test` and `ern shell` add each `lib/<name>/ebin` too, as `--libs-dir` adds an application's. For that a job reads the root's manifest and no other. A named package that is not under `lib/` is refused with the job that puts it there: `ern build: package.conf: epx 0.2.1 is not under lib; ern unpack`. A directory the manifest and an option both name stands on the load path once.

**`ern build`** alone makes the checks of question 1, reading each named package's manifest, and holds each one's `VERSION` to its line. It then builds each named package that is not current, from `lib/<name>/src` into `lib/<name>/build`, a package after those its manifest names. A cycle among packages is refused. A run makes no check: a module compiled against another interface is refused before anything runs, as it is today (§11.2).

An attached shell reads no manifest, since its load path is its node's (§11.2). A shell in a package finds a module's source under `src`.

No job reads a `lib/` but the root's. A package's own `lib/`, which its archive may carry for whoever runs it alone, is passed over.

**The shape.** A package's shape is fixed, since a build must find a dependency's source: the manifest and `VERSION` at the top, `src/` the source root, `build/` the build root, `lib/` the packages it loads. So a source under a package's `src` has `src` as its source root and `build` as its build root, where the options do not say otherwise. A source elsewhere in the package, under `tools/` or `examples/`, is built as it is today. Every job takes its argument as it does today.

```
ern unpack
ern build src
ern test build
ern run build/chart.erc
```

**An installed program** is started from any directory by its launcher, with a file that is not under the working directory, so it reads no manifest. The launcher names its load path with `--load-path` and `--libs-dir`, as it does today. Both options stay as they are, for that and for what is no package.

**The cost.** What a job loads for a file of the working directory depends on the manifest there, which no word of the command names. `--verbose` says that the manifest was read, and which.

## 3. Does a package own a namespace?

Yes: one, its name's.

Every module of a package that another loads stands at the namespace of the package's name or under it. The package `epx` provides `Epx` and `Epx.Window`, as `libs/json` provides `Json`. The name is written as a file's name is (§11.2), `ordered_set` for `OrderedSet`. A named package that provides another namespace is refused by `ern build`, at the module.

The use site then names the package: `Epx.Window.open` says where it comes from (principle 3). Two packages cannot collide but by one name, which is refused already. ernest-epx has this shape today. ernest-httpd does not, with `Config` and `Session` at its root, and need not: a program is a root, and nothing loads it.

A root's own module at a named package's namespace is refused, naming the line.

A package takes no namespace of the standard library or of a library of Appendix G. §4.2 lets a program's own module hide a library of Appendix G, since the program's own tree shows it. A package that hid one would change what another package's `Http.parse` means, with nothing at that package's lines (principle 3). This departs from what a reader of §4.2 predicts, and the report states it as a rule.

The rules of this question are the toolchain's, §11's, over a manifest's lines. §4.2 is unchanged: it refuses a module at a namespace of the standard library or under `Ernest` already, in a package as anywhere.

## 4. What is a package's archive, and where is its digest?

A release archive, downloaded by hand, with its URL and its SHA-256 on its line.

**No job touches the network.** The author downloads the archive and puts it under `lib/` by its own name, `lib/epx-0.2.1.tar.gz`. `ern` stays what it is, a tool over files, with no client, no redirect and no half-finished download to state.

**The URL** is the archive's own address, written whole, its scheme `https` alone and its last part `name-version.tar.gz`. It is the one place that says where a package comes from, as *A Library Is Fetched by Its URL* decided, and no Makefile says it again. The root's line decides it; the `url` and `sha256` of a dependency's own lines are not read.

**The digest** is the archive's, on the line. Without it the same manifest could build other code tomorrow, where a release was replaced. A line without one is refused, and the refusal says the digest of the archive under `lib/`, so the author writes it once, having seen it. The digest of the definitions (Appendix H) was weighed and set aside: it moves with the form's version, so every line would be rewritten at each release, and it covers no host code.

**`ern unpack`**, named for what it does, since it fetches nothing, takes each named package that is not under `lib/` at its line's version. It checks its archive's digest against the line and unpacks it as `lib/<name>/`. The archive holds one directory, `name-version`, whose `VERSION` says that version. A `lib/<name>` that holds another version is replaced whole, and a link there is removed and not followed. The archive stays where it was put.

A package is unpacked whole or not at all, as a file a job writes is (§11): a job that ends as it unpacks leaves `lib/<name>` as it was. The job takes no argument.

An archive that is not there is refused with what to download and where to put it, every such line in one run:

```
ern unpack: package.conf: epx 0.2.1 is not under lib; download
https://github.com/joagre/ernest-epx/releases/download/v0.2.1/epx-0.2.1.tar.gz
to lib/epx-0.2.1.tar.gz
```

`ern build` reads what stands under `lib/<name>` whatever put it there (question 2). A checkout linked there by hand is a package like any other. The digest is the unpacking's check, and a build makes none.

**What it asks of the libraries.** The job is written in Ernest. It needs `Crypto.sha256`, a library over the host's `zlib` for gzip, and one over the host's `erl_tar`, each an E.0 reading first.

**A download is a second step.** A job that fetches what is missing would take the same line and change no manifest: the refusal above would go, and nothing else. It is decided on its own, with its client.

## 5. A package's Erlang and C parts

They travel built, and `ern` builds none of them.

**No code of a package runs while it is unpacked or built.** `ern unpack` unpacks, and `ern build` compiles Ernest, which runs nothing. A line added to a manifest runs no code until the program calls it. What Cargo and npm run at an install is [`other_systems.md`](other_systems.md)'s.

**Erlang.** A package's `.beam` files stand in its `ebin/`, compiled by whoever released it, and its other files in `priv/`. §11.2 finds a `foreign fn`'s module as a `.beam` in a directory of the load path already. The host loads compiled code on at least two of its releases after the one that compiled it, and on none before it, so a `.beam` is compiled on the earliest release of OTP its package is meant for.

**C.** A library the host loads from `priv/` is built for one machine and does not travel. The package's own `make` builds it, run by the author who loads the package, by name, as the package's README says. Until then a call into it faults as any foreign function does whose module the host cannot load.

A package's `ebin/` holds every `.beam` it needs, its own or another's. Two packages that hold a `.beam` of one name are refused by `ern unpack`, naming both, since the host would load one without a word. So is a `.beam` named as a module of the host's or of the toolchain's, which §11.2 finds first and the package's never. The check is made where a package arrives, so that no start reads every `ebin/`.

**Where it stands.** The host names an Erlang application by its directory, and finds its `priv/` from there: `epx.erl` loads its library from `code:priv_dir(epx)`. A package another loads stands at `lib/<name>/`, so the `ebin/` and `priv/` at its top are found where the application has the package's name. An archive carries them there.

A root's own Erlang cannot stand at its top, since a checkout is named as its owner likes, `ernest-epx`. It stands under `lib/<application>/`, linked there by the root's own `make lib` and named by `--libs-dir lib`, as it is today. A release copies it to the archive's top.

ernest-epx is the cost: it needs a second command after the unpacking, said in its README. It stays one package, with `tree_db`'s modules in its `ebin/` beside its own, which holds because `tree_db` has no `priv/`. An application that has one stands in a directory of its own name, and is a package of its own.

## 6. Do Appendix G's libraries become packages?

No. They stay on every job's load path, and a program names none of them.

A release of Ernest is one thing: the language, the standard library and every library of Appendix G, under the release's one version. So a package depends on them through its `ernest` line and through nothing else (question 1), and no line names one. A line for one would say the release's version a second time (principle 2).

A one-file program that uses `Json` needs no manifest today, and the tour's programs are such programs. A manifest for them would be a cost on programs that load no package (principle 5).

No rule of admission changes. A library is Ernest's where it is over a specification a program of any kind may meet, as before. What goes is the wrong reason to be listed, that being listed was the only easy way onto a load path.

A library may begin as a package and enter Appendix G in a later release. Its namespace is then a taken one (question 3), so a line for the package is refused under that release, and its users drop the line.

The libraries `ern unpack` asks for, gzip and tar, enter by the same test, each a published format.

The eleven libraries there stay. Moving one out breaks programs for no gain: a node's start measured the same with four of them and without.

## 7. Which real edge is it written against?

None exists: `DEPS` is empty in ernest-template, ernest-epx and ernest-httpd. That is no argument against (principle 5), but the proposal needs a program.

[`trial.md`](trial.md) tries it on three things: the three repositories as they stand, a program over ernest-epx, and a package that loads a package, which a fixture holds since no such pair is real. Its findings are in the questions above.

`web_socket.ern` stays ernest-httpd's own, as *WebSocket Is the Server's* decided, until another program asks.

## What does not change

- The language: no rule of §1 to §9 and nothing of Appendix A.
- A compiled module, a node, and how code crosses between nodes.
- A program with no `package.conf`, and every job on it.
- Appendix G's list, and the rule that admits a library to it.
- `--load-path` and `--libs-dir`, and an installed program's launcher.

## The cost

- **To Ernest:** one file's form, one job, about a dozen refusals, and three additions to the libraries, `Crypto.sha256`, gzip and tar.
- **To every job:** one look for `package.conf` in the working directory as it starts, measured before it is built on (*The tools are fast*). A job that finds none does nothing more.
- **To a build in a package:** a read of each named package's manifest and `VERSION`.
- **To an author:** a line for every package the build loads, an archive downloaded by hand for each, and an edit by hand at each upgrade.
- **To the other repositories:** a manifest each and the template's Makefile cut, as the trial writes them, and for ernest-epx a release that carries its host part as question 5 says.

## The build order

Each step stands on those before it, and the first three need no library and no other repository.

1. The report: the new section at the end of §11, §11's opening, §11.1, §11.2, Appendix F and Appendix G's opening, read cold before the build.
2. The manifest read and the load path: every job puts the named packages on it, with `lib/` filled by hand.
3. `ern build`'s checks, the roots of a package's `src`, and the named packages built in their order. The trial's table of refusals is its first test.
4. `Crypto.sha256`, and the libraries for gzip and tar, each with its section of Appendix G first.
5. `ern unpack`, in Ernest, over the three.
6. The guide's section on a package, since the guide teaches what the report states.
7. ernest-template, then each copy, and ernest-epx's release, by their own sessions.

A job that downloads is no step here (question 4).

## What it meets

Read against each owner below, from both sides, on 2026-11-09. What the reading changed is in the text above; what it leaves for the day the proposal is built is said here.

**The report.**

- §11's opening. Its sentence, that a job reads from the directory it is started in only what its command line names, takes the manifest as its exception. Its list of jobs gains one, and its sentence on `ern(1)` gains the new section.
- §11.1. A module outside the source root is read under the build root, then under each `--load-path` root, then under each named package's build, then under the toolchain's libraries. The roots of a package's `src` are stated where the source root's defaults are.
- §11.2. The load path's sentence gains the packages, after the options and before the toolchain's libraries. A node reads every module of its load path at its start (§8.7), so on a node a line that nothing needs still loads its modules.
- §11.5 and §11.8. A refusal over the manifest has §11.2's form and status 1.
- A new section at the end of §11 holds the manifest and `ern unpack`, since no section there can hold them and none is inserted.
- §4.2 is unchanged (question 3). Appendix C is the manifest's model, and Appendix F gains *package*, *manifest* and *root*, and its *load path* the packages.
- Appendix G's opening: its last sentence, on a library written elsewhere, names the package. Appendix D is unchanged.
- E.0 is read for `Crypto.sha256`, gzip and tar before each is written.

**The log.**

- *Packages* is superseded in part: its "no versioned package manager, ever", and its sentence that such a thing lives in the guide and not the report. Its refusal of a resolver, a lockfile and semver's arguments stands.
- *MVP 2.7, the Fetcher, and No Server* is superseded where it has a fetched library recorded as the hashes of its definitions.
- *A Library Is Fetched by Its URL* keeps its verdict: no registry, the URL written by the author, and an index that is a page. Its mechanism goes: a git URL, the definitions' hashes, and a job that fetches.
- *A Libs Flag Instead of the Environment* argues that nothing outside the command changes what runs. The manifest in the working directory goes against it, and the decision's entry records that argument beside the one that won.

**The other repositories.**

- ernest-template first, then each copy, by their own sessions. `TEMPLATE.md` says today that there is no package manager, that a dependency is a directory, that `DEPS` is written in build order and that nothing resolves; its Makefile holds `ERN_VERSION`, `DEPS` and the `version` target. The trial writes out what each becomes.
- The launcher and `docs/design/install.md` are unchanged. The launcher names every directory under `lib/`, where a manifest names its lines' alone, so a directory left under `lib/` is loaded by an installed node and by no job in the package.
- `site/projects.md` is the index and stays a page.

**The way of working.**

- What this proposal says was weighed and set aside goes to the log when it is decided, and the trial is its experiment (CLAUDE.md's *Proposals*).
- A job written in Ernest stands under `Ernest`, which the shell's source root alone provides today (§4.2). Where `ern unpack` stands is decided when it is built.
