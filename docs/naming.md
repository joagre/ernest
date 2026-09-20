# Naming the Erlang Side

The scheme, settled 2026-09-20 and not yet carried out. The report owns the language, so
nothing here touches it; this is the toolchain's own directories, applications, and Erlang
modules, which a reader meets before any of them. The rule moves into [`style.md`](style.md)
when the rename is done, and this page stays as its record.

## The problem

`ern_` says nothing. `ern_check`, `ern_bits`, `ern_show`, `ern_fs`, `ern_keys`, `ern_tcp`,
and `ern_rt` are one application; `ern_char`, `ern_float`, and `ern_string` are another;
`ern_diag` is a third. Two directories, `runtime` and `ern_stdlib`, are named by different
conventions from each other, and `lib/compiler` holds one module that is not the compiler.
A newcomer has to read the Makefile to learn the shape of the repository.

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

> Every Erlang module in this repository is `ernest_<thing>`, where `<thing>` is unique
> across the repository. Every module compiled from an Ernest source is
> `ernest@<namespace>`. The one exception is a vendored file, which keeps its upstream
> name.

`ernest_` says whose it is and cannot collide with anything Erlang ships or will ship.
`ernest@` is the language itself, and the `@` carries that distinction. The two halves of
one thing are named alike: `ernest@tcp` is the `Tcp` module, `ernest_tcp` is its Erlang
side.

The directory says which layer a module belongs to, so the module name does not repeat it.
`erl/typer/src/ernest_types.erl` needs no `typer` in the file name. `make` fails on a
duplicate module name, so uniqueness keeps itself.

Directories are named for the application, in whole words, and avoid Erlang's application
names.

## The tree

The top level answers the first question a newcomer has, which language a file is in:

```
erl/        the toolchain, written in Erlang
stdlib/     the standard library, written in Ernest
libs/       the libraries, written in Ernest
examples/   programs, written in Ernest
bin/ build/ docs/ test/
```

## The map

| Now | Then |
|---|---|
| `lib/` | `erl/` |
| `lib/lexer/src/ern_lexer.erl` | `erl/lexer/src/ernest_lexer.erl` |
| `lib/lexer/src/ern_diag.erl` | `erl/lexer/src/ernest_diag.erl` |
| `lib/lexer/include/ern_diag.hrl` | `erl/lexer/include/ernest_diag.hrl` |
| `lib/parser/src/ern_parser.erl` | `erl/parser/src/ernest_parser.erl` |
| `lib/parser/include/ern_ast.hrl` | `erl/parser/include/ernest_ast.hrl` |
| `lib/type_system/` | `erl/typer/` |
| `lib/type_system/src/ern_typecheck.erl` | `erl/typer/src/ernest_typer.erl` |
| `lib/type_system/src/ern_types.erl` | `erl/typer/src/ernest_types.erl` |
| `lib/type_system/src/ern_prelude.erl` | `erl/typer/src/ernest_prelude.erl` |
| `lib/type_system/src/ern_reply.erl` | `erl/typer/src/ernest_reply.erl` |
| `lib/type_system/src/ern_exhaust.erl` | `erl/typer/src/ernest_exhaust.erl` |
| `lib/type_system/include/ern_types.hrl` | `erl/typer/include/ernest_types.hrl` |
| `lib/compiler/` | `erl/emitter/` |
| `lib/compiler/src/ern_compiler.erl` | `erl/emitter/src/ernest_emitter.erl` |
| `lib/runtime/` | `erl/rt/` |
| `lib/runtime/src/ern_rt.erl` | `erl/rt/src/ernest_rt.erl` |
| `lib/runtime/src/ern_check.erl` | `erl/rt/src/ernest_foreign.erl` |
| `lib/runtime/src/ern_bits.erl` | `erl/rt/src/ernest_bits.erl` |
| `lib/runtime/src/ern_show.erl` | `erl/rt/src/ernest_show.erl` |
| `lib/runtime/src/ern_fs.erl` | `erl/rt/src/ernest_fs.erl` |
| `lib/runtime/src/ern_keys.erl` | `erl/rt/src/ernest_keys.erl` |
| `lib/runtime/src/ern_tcp.erl` | `erl/rt/src/ernest_tcp.erl` |
| `lib/cli/src/ern_cli.erl` | `erl/cli/src/ernest_cli.erl` |
| `lib/utils/src/getopt.erl` | `erl/utils/src/getopt.erl`, unchanged: vendored, and `THIRD_PARTY_LICENSES` names it |
| `lib/ern_stdlib/` | `erl/estdlib/` |
| `lib/ern_stdlib/src/ern_char.erl` | `erl/estdlib/src/ernest_char.erl` |
| (and `float`, `foreign`, `int`, `io`, `list`, `map`, `path`, `random`, `set`, `string`) | likewise |
| `lib/*/test/ern_x_tests.erl` | `<new module name>_tests.erl` beside its subject |
| `test/ern_docs_tests.erl` | `test/ernest_docs_tests.erl` |
| `test/ern_style_tests.erl` | `test/ernest_style_tests.erl` |
| `test/ern_integration_tests.erl` | `test/ernest_integration_tests.erl` |
| — | `erl/elibs/` for the Erlang side of an Ernest library, `libs/` for the libraries themselves, `build/libs/` for their compiled form |

Unchanged: `bin/ernc` and `bin/ern`; `stdlib/*.ern`; `examples/*.ern`; `build/stdlib/`; and
the compiled `ernest@<namespace>.beam` names, which report §11.1 fixes.

Two renames carry an argument rather than a convention. `ern_check` becomes
`ernest_foreign`, since it is the foreign boundary of §8.4 and nothing about it is a
"check" in the sense the type checker uses that word. And `ern_compiler` becomes
`ernest_emitter`, because `ernc` is the compiler, the whole chain of CLI, lexer, parser,
typer, and this; the application that turns a typed tree into Erlang forms is the emitter,
which is what the plan and the architecture note have called it all along.

## Two names that need a reason

- **`emitter`, not `compiler` or `codegen`.** `compiler` is Erlang's application name and
  would win `code:lib_dir/1`; `codegen` is an acronym in spirit. `emitter` is the word
  this project already uses for that code.
- **`estdlib`, not `stdlib`.** The directory holds the Erlang half of the standard
  library, `stdlib` is Erlang's application name, and we call `code:lib_dir/1` on this
  application at startup, so the clash would be ours to trip over. The `e` means "the
  Erlang side of an Ernest tree", as in `elibs`, and it appears in no other position.

## Against the principles

The five principles are the language's, §0, but they were written for design and this is
design.

1. **Least surprise.** A reader who has seen `ernest@tcp` predicts `ernest_tcp` for its
   Erlang side, and a reader in a stack trace knows at once whether a frame is ours. The
   one surprise left is that a module name does not say its layer, which the directory
   says instead.
2. **One way, one job.** One prefix, one exception, and it is a borrowed file. The old
   scheme had three conventions and no rule; the long form, `ernest_<app>_<thing>`, had
   two.
3. **Nothing invisible.** The tree says which language each part is written in, which the
   present layout hides: today `lib/` holds both Erlang applications and, under
   `ern_stdlib/ebin`, compiled Ernest.
4. **Simple to parse**, read as "simple to find": a name is `ernest_` and a word, so a
   grep for `ernest_` finds our code and nothing else.
5. **Small.** Nine directories under `erl/`, one prefix, thirty-five modules that each say
   one thing. `ernest_rt_tcp` said two, and the second was in the path already.

## Migration, in discrete steps

Each step ends green, with `make test` and `make xref` passing, and is its own commit.

1. `lib/` to `erl/`, directory rename only, the Makefile and `ERL_LIBS` with it.
2. Directory renames inside `erl/`: `type_system` to `typer`, `compiler` to `emitter`,
   `runtime` to `rt`, `ern_stdlib` to `estdlib`.
3. One application's modules at a time, headers with them, leaves first: `utils`, `lexer`,
   `parser`, `typer`, `emitter`, `rt`, `estdlib`, `cli`.
4. Test modules, each with its subject.
5. The emitted names. `ernest_emitter` writes calls to `ernest_rt` and to the standard
   library's modules, so `make golden` runs here and every golden file changes.
6. The documents: the README's layout, the architecture note, the plan, CLAUDE.md, and the
   style guide, which is where the rule lands.
7. `libs/`, `build/libs/`, and `erl/elibs/` are created when the first library is written,
   not before.
