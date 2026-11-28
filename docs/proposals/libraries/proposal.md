# Which libraries become packages

Status: a proposal for MVP 4.18's item 6, written 2026-11-28. Nothing here is decided, and nothing in it is authoritative. It ends with what the user decides.

## The question

Appendix G lists eleven libraries. Each one's build stands on every job's load path, and no program names one. A library written elsewhere reaches a program as a package, by an entry of a manifest (§11.9). So a library reaches a program in two ways, and what sorts a library into G is that it was written here before packages were. ernest-epx was written here after them and is a package.

A reader of the full review asked for the rule G lacks (the log's *What Stands on Every Load Path*). Two tests were put:

- a library stands on every load path only where a job of the toolchain's calls it;
- a library is a package where it is over a published specification.

The item also asks whether the standard library keeps `OrderedSet`, `OrderedMap` and `Random`, and whether the draw of `Peer.computeAnywhere` is a policy a library holds.

## What stands today

Each library is one module. The lines are its Ernest's, and its Erlang's where it has a shim.

| Library | Lines | Called by | Its foreign functions name |
|---|---|---|---|
| `Markdown` | 2,450 | the shell, `ern doc --man`, the repository's tools | nothing |
| `Ansi` | 187 | the shell, `Markdown`, an example, ernest-httpd | nothing |
| `Ets` | 244 | the shell, the guide's §8.5 | the host's `ets`, and `ern_rt` |
| `Crypto` | 211 | `ern unpack`, the site's generator, an example, ernest-httpd | the host's `crypto` |
| `Proxy` | 210 | the guide's §8.2 | `ern_rt` |
| `Utilization` | 238 | nothing | the host's `erlang`, `cpu_sup`, `memsup` and `disksup` |
| `Json` | 776 and 115 | an example, ernest-httpd 108 times | its shim `ern_json`, over the host's `json` |
| `Http` | 4,339 and 73 | two examples, ernest-httpd 321 times | its shim `ern_http`, over the host's `decode_packet` |
| `Uri` | 786 and 46 | `Http`, an example, the site's generator, ernest-httpd | its shim `ern_uri`, over the host's `uri_string` |
| `Time` | 323 | `Http`, ernest-httpd | the host's `calendar` |
| `Base64` | 256 | ernest-httpd | the host's `base64` |

`ern_rt` is the runtime's own Erlang. `Proxy` tells it that the proxy's process ends with its caller (`ends_with_caller/1`), and `Ets` tells it of a table made. `Utilization` reads the services that a node's `measures` start (Appendix C).

The eleven builds are about 1.6 MB. No manifest of this project's programs names a package: ernest-httpd's, ernest-epx's and ernest-template's each hold an empty list.

## What a move changes for a program

**How it is taken.** A program that uses a package holds a manifest, the package's archive under `lib`, and runs `ern unpack` (§11.9). A manifest is flat, so a program over `Http` names three packages: `http`, `time` and `uri`. No job downloads: each archive is put under `lib` by hand. Today the program is one file, built by `ern build fetch.ern`.

**Across nodes.** A foreign declaration over a module of OTP's or of `ern`'s agrees on every node by the floor, and one over a module of the program's own is each node's to hold (§8.7). A library's shim is `ern`'s today. So a function that calls `Json.parse` runs on any peer, a bare node among them, when it is spawned there. As a package's, the shim is the program's own: the peer runs the function only where its own load path holds the package's `ebin`, and the spawn answers `NotLoaded` where it does not (§8.7). That holds for `Json`, `Http` and `Uri`, the three with a shim.

**What is gained.** The manifest names every library the program loads, where today eleven are loaded unnamed. The package's version is the program's to choose, where today a library changes with each release of Ernest. The names `json`, `http`, `uri`, `time` and `base64` are free for another's package, where today §11.9 refuses each. And ernest-httpd would be the first program to name a package, five of them.

## The two tests against the facts

**A job calls it.** Seven would move. `Proxy` cannot as it stands: a package would call a function of the runtime's own, and that function would become an interface a release must keep. The other six can.

**A published specification.** `Markdown` is over CommonMark, `Ansi` over ECMA-48 and `Crypto` over FIPS 180, and jobs call all three. So this test moves nothing by itself, and needs the first beside it.

**What the two leave.** A library stands on every load path where a job of the toolchain's calls it, or where it stands on the runtime's own: `Markdown`, `Ansi`, `Ets`, `Crypto` and `Proxy`. A library that could be a package is one: `Json`, `Http`, `Uri`, `Time`, `Base64` and `Utilization`. This rule can be checked from the code, and it closes G to growth: a library written from now on enters only where the toolchain cannot be built without it.

## The move, if it is taken

Each owner the item names, read against a move of the six.

- **Where they live.** `packages/<name>/` in this repository, each a package: its manifest, its `VERSION`, its `src`, its shim compiled under `ebin`, its tests. A package gets a repository of its own when its releases part from Ernest's.
- **Whose version.** Each its own, raised when the package changes, so that a release of Ernest that leaves a package alone changes no manifest.
- **How they ship.** `make release` writes each archive. The releases page holds them, for an entry's `url`, and the installation holds them too, so that a machine with Ernest needs nothing more. A program copies an archive to its `lib`, and `ern unpack` says the digest of one whose entry has none.
- **The report.** G.4, G.6, G.8, G.10, G.11 and G.12 become `Unused`, as G.5 is. G's opening states the rule. §11.9's example of a refused namespace names another library. Appendix C's `measures` names the host's services and no library.
- **The examples.** `fetch.ern` and `web_server.ern` each become a directory with a manifest, and their first comments say how the archives are taken.
- **The guide.** §7.1's sentence on a library's namespace names `Ets` and `Markdown`. §8.2's mention of `Json` names a package. §9.6 stays, or shows `http` in place of `leaf`.
- **The site and the man pages.** `/man/libs/` and the installed pages lose six libraries. A package's pages are its own: the Projects page lists the six with ernest-epx, each linking to its page in the repository.
- **The repository's tools.** The site's generator calls `Uri` at four sites. The repository becomes a root package that links `lib/uri`, or the generator reads a fragment without it.
- **ernest-httpd.** Its manifest names `base64`, `http`, `json`, `time` and `uri`, and its deployment copies five archives. Its session does this in its release on 0.12.0, on a path the rehearsal has not walked.
- **Every node.** A node that runs a spawned function over `Json`, `Http` or `Uri` holds that package, by its own manifest.

## The recommendation

**Nothing moves for 0.12.0, and G gains its rule.** The argument:

1. *What a first user meets.* The tour and the guide use none of the six. A reader who goes on to a program over HTTP or JSON builds one file today. After a move they write a manifest of three or four entries and copy as many archives before the first build. The rule that sorts what stands before the launch asks what a first user meets, and here a move makes it worse.
2. *Principle 1, across nodes.* The homepage's claim is that a function started on another node takes its code with it. A reader who knows that predicts that a function over `Json.parse` travels as any function does. It does today. After a move it answers `NotLoaded` on a peer that does not name the package.
3. *No need met in use asks for it.* The plan has a change to the libraries driven by a need met in use. The question came from a reading that asked for a rule, and no program has wanted a library's name, a library at another version, or a release of `Http` without one of Ernest.
4. *The rule is the cheap part.* What the reader missed is a rule, and G can state one without a move: the rule above, with the six that it does not admit standing by name, as E.0 holds `OrderedSet`, `OrderedMap` and `Random`. That closes G to growth now.

What the move would buy stays true: one way for a library to reach a program, a manifest that names all of them, and a version of `Http` that the program chooses. The first of the six that a need met in use asks for moves then, by the design above, and the break is a few lines of a manifest.

**The sentences.** Appendix G's opening would read, in place of its sentence on the four that jobs call:

> A library is listed here where a job of the toolchain's calls it, `Markdown`, `Ansi`, `Ets` and `Crypto`, or where it stands on the runtime's own, `Ets` and `Proxy`. `Json`, `Http`, `Uri`, `Time`, `Base64` and `Utilization` are listed by name. Any other library is a package (§11.9).

Its second paragraph's "A library written elsewhere is used as a package (§11.9)" goes, the sentence above saying it of every library.

## The three modules of the standard library

`OrderedSet`, `OrderedMap` and `Random` stay in Appendix E, by name, as E.0 has held them since 2026-11-23. Nothing changes.

Under the rule above none of the three could enter G: no job calls one, and each is Ernest alone. So a move would make each a package, and for each it would change this:

- the guide's §7.3 teaches a requirement and an operations record by `OrderedSet`, Why shows `Operations(..OrderedSet)`, and two examples use `OrderedMap` and `Random`: each would need a manifest;
- at the prompt, a name of the standard library resolves, and a module outside it is loaded first, by `:load`;
- the standard library is initialized whole in every program and agrees across nodes by the floor (§8.5, §8.7), where a package's definitions travel by hash;
- the checking of a foreign return changes nothing, since none of the three declares a foreign function.

## The compute's draw

The draw stays in `Peer`, and E.0's rule 3 names it.

A library cannot hold the compute: `Peer.computeAnywhere` is a primitive, called where it is named, and a function that came as a parameter is refused (§3.11). A library could hold the pick alone, a function that answers a peer's name, with `Peer.compute` written after it. That is two lines at each call with two absences to answer, and it is the form put to the user on 2026-11-23 as a program's own and not taken (the log's *The Compute and the Node's Measures*). The tour's *Work anywhere* stands on the one call.

Rule 3 has a choice stated whole only where the language, the toolchain or the host makes the same choice, and names one exception, E.13's generator. E.27 states the draw whole, two peers at random and the less busy, and nothing else makes that choice. The log first gave the draw to a library for that reason (*No Remote Computation in the Language*, 2026-09-27) and took it into `Peer` on 2026-10-11 (*Placing Work by Name*) without naming it in the rule. So the rule's sentence would read:

> Any other is an argument, or a library's, but for E.13's generator and E.27's draw, each of which stands with its module by name.

## What the user decides

One question: whether nothing moves for 0.12.0 and G states the rule, the six by name. The other two answers follow from it and are taken with it or apart:

1. the libraries: recommended, none moves and G's opening gains the sentences above;
2. `OrderedSet`, `OrderedMap` and `Random`: recommended, they stay as E.0 names them;
3. the draw: recommended, it stays and rule 3 names it.

If the move is taken instead, it is the six, built as *The move, if it is taken* says, and the item says first whether it is built before the tag.
