# Naming the Erlang Side

The scheme, settled 2026-09-20 and not yet carried out. The report owns the language, so
nothing here touches it; this is the toolchain's own directories, applications, and Erlang
modules, which a reader meets before any of them. The rule moves into [`style.md`](style.md)
when the rename is done, and this page stays as its record.

## The problem

Three conventions and no rule. `ern_check`, `ern_bits`, `ern_show`, `ern_fs`, `ern_keys`,
`ern_tcp`, and `ern_rt` are one application; `ern_char`, `ern_float`, and `ern_string` are
another; `ern_diag` is a third. Two directories, `runtime` and `ern_stdlib`, are named by
different conventions from each other. `lib/` holds Erlang applications and, inside
`ern_stdlib/ebin`, compiled Ernest. `lib/compiler` holds one module that is not the
compiler. A newcomer reads the Makefile to learn the shape of the repository.

## What the runtime allows

Measured on OTP 27, with `ERL_LIBS` pointing at our applications:

- **An application directory may take an Erlang application's name.** `lib/compiler` does
  today, and both `ebin` directories stay on the code path, so `compile:forms/2` still
  resolves to Erlang's.
- **But the duplicate wins `code:lib_dir/1`.** `code:lib_dir(compiler)` answers with ours,
  so anything that resolves an application by name gets ours.
- **A module name must never clash.** Modules are global, and our `ebin` directories
  precede Erlang's applications on the path, so a module of ours named `sets` or `compile`
  would shadow Erlang's for the whole node. An Ernest program calls foreign functions, so
  whatever a user loads shares the node with us.
- Of the names in play, only `compiler` and `stdlib` exist in the distribution.

## The rule

> Every Erlang module in this repository is `ern_<thing>`, where `<thing>` is unique
> across the repository. Every module compiled from an Ernest source is `ern@<namespace>`.
> The one exception is a vendored file, which keeps its upstream name.

One token for the whole project: `ern` is the runner, `ernc` the compiler, `.ern` the
source, `ern_` our Erlang, `ern@` our Ernest. It is learned once and typed everywhere.
`ern` is not shorthand invented for a directory, as `rt` and `codegen` would have been; it
is the name on the binary and on every source file here.

The prose keeps the language's full name, because it is about the language rather than the
toolchain: `ernest_report.md`, `ernest_guide.md`.

The directory says which layer a module belongs to, so the module name does not repeat it:
`erl/typer/src/ern_types.erl` needs no `typer` in the file name, and `make` fails on a
duplicate module name, so uniqueness keeps itself.

Directories are named for the application, in whole words, and avoid Erlang's application
names.

## The tree

The top level answers the first question a newcomer has, which language a file is in:

```
erl/        the toolchain, written in Erlang
stdlib/     the standard library, written in Ernest
libs/       the libraries, written in Ernest, each with its own erl/ if it needs one
examples/   programs, written in Ernest
bin/ build/ docs/ test/
```

Nothing is named to dodge a collision. The Erlang half of the standard library is part of
the runtime, since it is what a compiled program calls, and the compiled `ern@*.beam`
files are build output under `build/stdlib/`, which the tools put on the code path. A
library that needs Erlang keeps it beside itself, `libs/json/json.ern` with
`libs/json/erl/ern_json_support.erl`, so everything about a library is in one place.

## The map

Most modules keep their names. What changes is where they live, two names that were
wrong, and the compiled prefix.

| Now | Then |
|---|---|
| `lib/` | `erl/` |
| `lib/type_system/` | `erl/typer/` |
| `lib/compiler/` | `erl/emitter/` |
| `lib/compiler/src/ern_compiler.erl` | `erl/emitter/src/ern_emitter.erl` |
| `lib/runtime/src/ern_check.erl` | `erl/runtime/src/ern_boundary.erl` |
| `lib/ern_stdlib/src/*.erl` | `erl/runtime/src/`, the shims being what a compiled program calls |
| `lib/ern_stdlib/test/*.erl` | `erl/runtime/test/` |
| `lib/ern_stdlib/ebin/ernest@*.beam` | `build/stdlib/ern@*.beam`, build output rather than an application's `ebin` |
| `ernest@<namespace>` | `ern@<namespace>`, in `module_atom/1`, every golden file, and the installed names |
| `lib/utils/src/getopt.erl` | `erl/utils/src/getopt.erl`, unchanged: vendored, and `THIRD_PARTY_LICENSES` names it |
| everything else under `lib/` | the same name under `erl/<application>/` |

Unchanged: `bin/ernc` and `bin/ern`; `stdlib/*.ern`; `examples/*.ern`; the markdown
documents.

## Two names that are wrong, not just mis-prefixed

- **`ern_emitter`, not `ern_compiler`.** `ernc` is the compiler, the whole chain of CLI,
  lexer, parser, typer, and this. The application that turns a typed tree into Erlang forms
  is the emitter, which is what the plan and the architecture note have called it all
  along. `emitter` also sidesteps the one directory clash that matters, since `compiler` is
  Erlang's application name and wins `code:lib_dir/1`.
- **`ern_boundary`, not `ern_check`.** It is the foreign boundary of §8.4, and nothing in
  it is a "check" in the sense the type checker uses that word. It cannot be `ern_foreign`,
  which the standard library's `Foreign` already takes, and that near miss is what the
  uniqueness rule is for.

## Against the principles

The five principles are the language's, §0, but they were written for design and this is
design.

1. **Least surprise.** One token, `ern`, in the command, the file extension, the Erlang
   modules and the compiled ones. A reader who has run `ernc` predicts the rest. The
   surprise left is that a module name does not say its layer, which the directory says.
2. **One way, one job.** One prefix, one exception, and it is a borrowed file. Today there
   are three conventions and no rule.
3. **Nothing invisible.** The tree says which language each part is written in, which the
   present layout hides.
4. **Simple to parse**, read as simple to find: a grep for `ern_` finds our Erlang and
   nothing else, `ern@` our Ernest.
5. **Small.** Seven directories under `erl/`, one prefix, one token. An earlier draft had
   `ernest_<app>_<thing>`, `estdlib`, and `elibs`, which said in a name what the path
   already said.

## Migration, in discrete steps

Each step ends green, with `make test` and `make xref` passing, and is its own commit.

1. `lib/` to `erl/`, directory rename only, the Makefile and `ERL_LIBS` with it.
2. `type_system` to `typer`, `compiler` to `emitter`; `ern_stdlib`'s sources and tests move
   into `runtime`.
3. The installed library moves from an application's `ebin` to `build/stdlib/`, with the
   code path set by `bin/ernc`, `bin/ern`, the Makefiles, and the one place the runtime
   asks where the library is installed.
4. The two renamed modules, `ern_compiler` to `ern_emitter` and `ern_check` to
   `ern_boundary`, each with its tests and its callers.
5. `ernest@` to `ern@`: `module_atom/1`, the installed names, the `foreign fn` targets that
   name a standard library module, and `make golden`, whose diff is read rather than
   accepted.
6. The documents: the README's layout, the architecture note, the plan, CLAUDE.md, and the
   style guide, which is where the rule lands.
7. `libs/` and `build/libs/` are created when the first library is written, not before.
8. A test that fails on any name outside the rule, so the rename's completion is a fact the
   suite checks rather than a claim.
