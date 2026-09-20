# Naming the Erlang Side

A suggestion, not yet decided. The report owns the language, so nothing here touches it;
this is about the toolchain's own directories, applications, and Erlang modules, which a
reader meets before any of them.

## The problem

`ern_` says nothing. `ern_check`, `ern_bits`, `ern_show`, `ern_fs`, `ern_keys`, `ern_tcp`
and `ern_rt` are one application; `ern_char`, `ern_float` and `ern_string` are another;
`ern_diag` is a third. Nothing in a name says which layer a file belongs to, and two
directories, `runtime` and `ern_stdlib`, are named by different conventions from each
other. A newcomer has to read the Makefile to learn the shape of the repository.

## What the runtime actually allows

Measured on OTP 27, with `ERL_LIBS` pointing at our applications:

- **An application directory may take an Erlang application's name.** `lib/compiler` does
  today, and both `ebin` directories stay on the code path, so `compile:forms/2` still
  resolves to Erlang's.
- **But the duplicate wins `code:lib_dir/1`.** `code:lib_dir(compiler)` answers with ours.
  Anything that resolves an application by name, a release tool or an escript, gets ours.
- **A module name must not clash.** Modules are global and our `ebin` directories precede
  Erlang's own applications on the path, so a module of ours named `sets` or `compile`
  would shadow Erlang's for the whole node.
- Of the names we want, only `compiler` and `stdlib` exist in the distribution. `lexer`,
  `parser`, `typer`, `codegen`, `rt`, `cli`, `utils`, `libs`, `elibs` and `estdlib` are
  free.

So the rule is not "avoid Erlang's names"; it is **modules may never clash, directories
should not clash**, since a directory that clashes quietly takes over a name that
something else may ask for.

## The rule

> Every Erlang module in this repository is `ernest_<layer>` or `ernest_<layer>_<thing>`.
> Every module compiled from an Ernest source is `ernest@<namespace>`. There is nothing
> else.

One prefix, learned once. `ernest_` is the toolchain, written in Erlang; `ernest@` is the
language, written in Ernest. The `@` already carries that distinction, and `ernest_` can
never collide with anything Erlang ships or will ship.

Directories are named for the layer, short, and free of Erlang's application names.

## The map

| Now | Suggested |
|---|---|
| `lib/` | `core/` |
| `lib/lexer/src/ern_lexer.erl` | `core/lexer/src/ernest_lexer.erl` |
| `lib/lexer/src/ern_diag.erl` | `core/lexer/src/ernest_lexer_diag.erl` |
| `lib/lexer/include/ern_diag.hrl` | `core/lexer/include/ernest_lexer_diag.hrl` |
| `lib/parser/src/ern_parser.erl` | `core/parser/src/ernest_parser.erl` |
| `lib/parser/include/ern_ast.hrl` | `core/parser/include/ernest_parser_ast.hrl` |
| `lib/type_system/` | `core/typer/` |
| `lib/type_system/src/ern_typecheck.erl` | `core/typer/src/ernest_typer.erl` |
| `lib/type_system/src/ern_types.erl` | `core/typer/src/ernest_typer_types.erl` |
| `lib/type_system/src/ern_prelude.erl` | `core/typer/src/ernest_typer_prelude.erl` |
| `lib/type_system/src/ern_reply.erl` | `core/typer/src/ernest_typer_reply.erl` |
| `lib/type_system/src/ern_exhaust.erl` | `core/typer/src/ernest_typer_exhaust.erl` |
| `lib/type_system/include/ern_types.hrl` | `core/typer/include/ernest_typer_types.hrl` |
| `lib/compiler/` | `core/codegen/` |
| `lib/compiler/src/ern_compiler.erl` | `core/codegen/src/ernest_codegen.erl` |
| `lib/runtime/` | `core/rt/` |
| `lib/runtime/src/ern_rt.erl` | `core/rt/src/ernest_rt.erl` |
| `lib/runtime/src/ern_check.erl` | `core/rt/src/ernest_rt_check.erl` |
| `lib/runtime/src/ern_bits.erl` | `core/rt/src/ernest_rt_bits.erl` |
| `lib/runtime/src/ern_show.erl` | `core/rt/src/ernest_rt_show.erl` |
| `lib/runtime/src/ern_fs.erl` | `core/rt/src/ernest_rt_fs.erl` |
| `lib/runtime/src/ern_keys.erl` | `core/rt/src/ernest_rt_keys.erl` |
| `lib/runtime/src/ern_tcp.erl` | `core/rt/src/ernest_rt_tcp.erl` |
| `lib/cli/src/ern_cli.erl` | `core/cli/src/ernest_cli.erl` |
| `lib/utils/src/getopt.erl` | `core/utils/src/ernest_getopt.erl` |
| `lib/ern_stdlib/` | `core/estdlib/` |
| `lib/ern_stdlib/src/ern_char.erl` | `core/estdlib/src/ernest_stdlib_char.erl` |
| (and `float`, `foreign`, `int`, `io`, `list`, `map`, `path`, `random`, `set`, `string`) | likewise |
| `lib/*/test/ern_x_tests.erl` | `core/*/test/<new module name>_tests.erl` |
| `test/ern_docs_tests.erl` | `test/ernest_docs_tests.erl` |
| `test/ern_style_tests.erl` | `test/ernest_style_tests.erl` |
| `test/ern_integration_tests.erl` | `test/ernest_integration_tests.erl` |
| — | `core/elibs/` for the Erlang side of an Ernest library, modules `ernest_libs_<name>` |
| — | `libs/` for Ernest library sources, `build/libs/` for their compiled form |

Unchanged: `bin/ernc` and `bin/ern`; `stdlib/*.ern`; `examples/*.ern`; `build/stdlib/`; the
compiled `ernest@<namespace>.beam` names, which report §11.1 fixes.

## Two names that need a reason

- **`codegen`, not `compiler`.** The application turns a typed tree into BEAM; `ernc` is
  the compiler as a whole, and it is the CLI, the typer and this together. The name is
  more accurate, and it sidesteps the one directory clash that matters.
- **`estdlib`, not `stdlib`.** The directory holds the Erlang half of the standard
  library. `stdlib` would take Erlang's application name, and we ourselves call
  `code:lib_dir/1` on this application at startup, so the clash would be ours to trip
  over. `e` here means "the Erlang side of", the same sense as `elibs`.

## Migration, in discrete steps

Each step ends green, with `make test` and `make xref` passing, and is its own commit.

1. `lib/` to `core/`, directory rename only, Makefile and `ERL_LIBS` with it.
2. Directory renames inside `core/`: `type_system` to `typer`, `compiler` to `codegen`,
   `runtime` to `rt`, `ern_stdlib` to `estdlib`.
3. One application's modules at a time, headers with them, starting at the leaves:
   `utils`, `lexer`, `parser`, `typer`, `codegen`, `rt`, `estdlib`, `cli`.
4. Test modules, each with its subject.
5. The emitted names. `ernest_codegen` writes calls to `ernest_rt` and the standard
   library's modules, so `make golden` runs here and every golden file changes.
6. The documents: README's layout, the architecture note, the plan, CLAUDE.md, the style
   guide, and the naming rule itself, which moves into `docs/style.md`.
7. `libs/`, `build/libs/` and `core/elibs/` are created empty when the first library is
   written, not before.

## Open questions

- Is `ernest_rt_tcp` worth its length against `rt_tcp`? The long form buys one rule
  instead of two and immunity from clashes; the short form reads better in a stack trace.
- Should the vendored `getopt` keep its upstream name, since `THIRD_PARTY_LICENSES` names
  it and its header says where it came from? Renaming it to `ernest_getopt` keeps the rule
  whole; keeping `getopt` would be the single exception, and it is a name Erlang does not
  ship.
- Does `core/` earn its name, or is `src/` plainer for a newcomer? `core` says these are
  the toolchain's own applications, against `stdlib/` and `libs/`, which are Ernest.
