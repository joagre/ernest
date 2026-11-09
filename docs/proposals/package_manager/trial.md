# Packages: the trial

[`proposal.md`](proposal.md), tried on paper against what exists, as its question 7 asks. Nothing here is built and no repository is touched. The findings stand last.

## 1. The three repositories

Each takes a `package.conf` with no dependency line, and keeps its `VERSION`. The template's and ernest-epx's are the same file.

ernest-template:

```json
{
  "ernest": "0.9.0",
  "packages": []
}
```

ernest-epx:

```json
{
  "ernest": "0.9.0",
  "packages": []
}
```

ernest-httpd:

```json
{
  "ernest": "0.10.0",
  "packages": []
}
```

The `ernest` line takes the place of `ERN_VERSION` and of the Makefile's `version` target. `ern build` makes the check, and says it in its own words:

```
ern build: package.conf: written for ern from 0.9.0, and this is ern 0.8.2
```

The check changes with it. Today ernest-epx on 0.9 is refused by `ern 0.10`. Under the proposal it is built, and refused only where the checker refuses its source.

## 2. The template's Makefile

What goes: `ERN_VERSION`, `DEPS`, `LOAD_PATH`, `RUN_LOAD_PATH`, `DEP_DIRS`, the `version` target, the loop that downloads, and the loop that builds each dependency.

What the changed targets read as:

```make
NAME        = name
ERL_DEPS    =
# The program's own Erlang applications, which make lib builds and links
# under lib/, each in a directory of its own name.
RUN_LIBS    = $(if $(ERL_DEPS),--libs-dir lib)

all: lib build

lib:
	@mkdir -p lib
	$(ERN) unpack
	@for app in $(ERL_DEPS); do \
	    ...as today... \
	done

build:
	$(ERN) build src

test: all
	$(ERN) format --check src tools $(wildcard test) $(if $(EXAMPLES),examples)
	$(ERN) test $(RUN_LIBS) build
	$(ERN) build --source-root tools --build-root tools/build tools
	$(ERN) test tools/build
	...

doc: all
	$(ERN) doc src
```

`tools/`, `test/` and `examples/` are roots of their own and are built as today. Each still names the program's own build, `--load-path build`, since the manifest names what the package loads and not the package.

`release` adds `package.conf` to the archive, beside the `VERSION` it carries already. `install`, `uninstall`, `man`, `format` and `clean` are untouched.

**The launcher** is untouched. It is started with a file that is not under the working directory, so it reads no manifest, and its two loops find `lib/<name>/build` and `lib/<name>/ebin` as they find them today.

## 3. One real edge: a program over ernest-epx

`examples/mandelbrot.ern` of ernest-epx, moved to a directory of its own, the file unchanged:

```
mandelbrot/
  package.conf
  src/mandelbrot.ern
  lib/
```

It has no `VERSION`, which is asked only of a package another loads.

```json
{
  "ernest": "0.9.0",
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

The first day, from an empty `lib/`:

```
$ ern build src
ern build: package.conf: epx 0.2.1 is not under lib; ern unpack
$ ern unpack
ern unpack: package.conf: epx 0.2.1 is not under lib; download
https://github.com/joagre/ernest-epx/releases/download/v0.2.1/epx-0.2.1.tar.gz
to lib/epx-0.2.1.tar.gz
$ curl -L -o lib/epx-0.2.1.tar.gz https://github.com/joagre/ernest-epx/releases/download/v0.2.1/epx-0.2.1.tar.gz
$ ern unpack
$ make -C lib/epx host
$ ern build src
$ ern run build/mandelbrot.erc out.ppm
```

Every day after it is the last two lines. The program names `Epx.putPixel` and `Epx.Window.show`, which say their package, and the source needs no change.

No Makefile is needed for a program of this size. That is new: today the same program needs the template's whole Makefile to reach `epx`.

## 4. A package that loads a package

No such pair is real, so a fixture holds it: `app` loads `mid`, and `mid` loads `leaf`.

`mid`'s manifest names `leaf` 1.1.0. `app`'s names `mid` 1.0.0 and `leaf` 1.2.0, and builds.

| The change | What `ern build` says |
|---|---|
| `app` has no line for `leaf` | `ern build: package.conf: mid 1.0.0 needs leaf from 1.1.0, and no line names leaf` |
| `app`'s line says `leaf` 1.0.0 | `ern build: package.conf: mid 1.0.0 needs leaf from 1.1.0, and the line for leaf says 1.0.0` |
| `lib/leaf` holds 1.3.0 | `ern build: package.conf: the line for leaf says 1.2.0, and lib/leaf holds 1.3.0` |
| two lines name `leaf` | `ern build: package.conf: two lines name leaf` |
| `leaf` names `mid` in turn | `ern build: package.conf: a cycle among the packages: mid, leaf` |
| `leaf` holds a module `Util` | `lib/leaf/src/util.ern: the package leaf provides Leaf and what stands under it` |
| `app` holds `src/leaf.ern` | `src/leaf.ern: Leaf is the package leaf's, which package.conf names` |
| `leaf` is written for a later `ern` | `ern build: package.conf: leaf 1.2.0 is written for ern from 0.11.0, and this is ern 0.10.2` |

Each is one line that names what to change. `mid`'s source is compiled against `leaf` 1.2.0, a version its author never built with, and the checker is what holds it.

What `ern unpack` says in `app`, each a line of the same form:

| What stands under `lib/` | What `ern unpack` says |
|---|---|
| no archive of `leaf` | `ern unpack: package.conf: leaf 1.2.0 is not under lib; download`, the URL, and `to lib/leaf-1.2.0.tar.gz` |
| an archive with another digest | `ern unpack: lib/leaf-1.2.0.tar.gz: its sha256 is 71be..., and the line for leaf says 9f2c...` |
| the line has no `sha256` | `ern unpack: package.conf: the line for leaf has no sha256; lib/leaf-1.2.0.tar.gz has 71be...` |
| an archive whose `VERSION` says 1.3.0 | `ern unpack: lib/leaf-1.2.0.tar.gz: holds leaf 1.3.0, and the line for leaf says 1.2.0` |
| `leaf` and `mid` both hold `util.beam` | `ern unpack: lib/leaf-1.2.0.tar.gz: util.beam is mid's too, and the host loads one` |
| `leaf` holds `lists.beam` | `ern unpack: lib/leaf-1.2.0.tar.gz: lists.beam is the host's own module, which is found first` |

## 5. What the trial found

**1. The version has two readers, and one cannot read JSON.** The Makefile names the archive `NAME-VERSION.tar.gz`, and `make` reads `VERSION` with `cat`. It cannot read a member of `package.conf`. So the manifest holds no name and no version of its own (the proposal's *The manifest*).

**2. The host names an application by its directory.** `epx.erl` finds its library with `code:priv_dir(epx)`, which the host answers from a directory named `epx` that holds `ebin`. As a dependency the package stands at `lib/epx/`, and its `ebin/` and `priv/` at its top are found. As the root, the same package stands in a checkout named `ernest-epx`, and they are not. Where each stands is the proposal's question 5, *Where it stands*.

**3. ernest-epx needs a release to be loaded.** Its archive today holds no manifest, holds its Erlang under `lib/epx/` and not at its top, and holds `epx_nif.so` as the releasing machine built it. A release for the proposal carries `package.conf`, `ebin/` and `priv/` at the top without the built library, the C source under `erl/`, and a `host` target that builds the library in place.

**4. The roots' rule was too wide.** Giving every job in a package `src` and `build` as its roots would have had `ern build examples` look for `examples` under `src`. The rule holds for a source under the package's `src` alone (question 2, *The shape*).

**5. The Makefile shrinks little.** About thirty of the template's 221 lines go. The rest is tests, documents, the archive and the installation, which packages do not touch. What is gained is not fewer lines: a small program needs no Makefile at all, the build order is no longer written by hand, and a version that does not fit is refused in one line.

**6. `tree_db` in `epx`'s `ebin/` holds only by luck.** `tree_db` has no `priv/`, so the host never asks for its directory. An application that has one must stand in a directory of its own name, and would be a package of its own.

**7. ernest-httpd's `XTERM` is no package.** Its two archives are npm's, with no manifest and no Ernest, and `make xterm` keeps them.

**8. A clone begins with a list of downloads.** `lib/` is ignored by git in all three repositories, archives and unpacked packages alike. So the first `ern unpack` after a clone says every archive to download, in one run.
