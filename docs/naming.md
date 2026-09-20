# Naming the Erlang Side

The scheme, settled 2026-09-20 and not yet carried out. The report owns the language, so
nothing here touches it; this is about the toolchain's own directories, applications, and
Erlang modules, which a reader meets before any of them. The rule moves into
[`style.md`](style.md) when the rename is done, and this page becomes its record.

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

> Every Erlang module in this repository is `ernest_<app>` or `ernest_<app>_<thing>`.
> Every module compiled from an Ernest source is `ernest@<namespace>`. The one exception
> is a vendored file, which keeps its upstream name.

The prefix is two things at once: `ernest` says whose it is, `<app>` says which
application it belongs to, so `ernest_rt_tcp` is the `tcp` part of `rt`. `ernest@` is the
language itself, and the `@` carries that distinction already.

The vendor part earns its length twice over. An Ernest program calls foreign functions,
so any Erlang library a user loads sits in the same node as our runtime; module names are
global, and `rt`, `cli`, `parser`, and `typer` are exactly the names another library may
take. And the precedent splits by who owns the distribution: Erlang's own compiler names
its layers `erl_lint` and `beam_ssa_opt` because those names are its to take, while
Elixir, a guest as we are, prefixes its whole Erlang side `elixir_tokenizer`,
`elixir_parser`, `elixir_expand`.

Directories are named for the application, short, and free of Erlang's application
names.

## The map

The top level answers the first question a newcomer has, which language a file is in:

```
erl/        the toolchain, written in Erlang
stdlib/     the standard library, written in Ernest
libs/       the libraries, written in Ernest
examples/   programs, written in Ernest
bin/ build/ docs/ test/
```

`core` was the first suggestion and says only "important", which every directory claims.

| Now | Suggested |
|---|---|
| `lib/` | `erl/` |
| `lib/lexer/src/ern_lexer.erl` | `erl/lexer/src/ernest_lexer.erl` |
| `lib/lexer/src/ern_diag.erl` | `erl/lexer/src/ernest_lexer_diag.erl` |
| `lib/lexer/include/ern_diag.hrl` | `erl/lexer/include/ernest_lexer_diag.hrl` |
| `lib/parser/src/ern_parser.erl` | `erl/parser/src/ernest_parser.erl` |
| `lib/parser/include/ern_ast.hrl` | `erl/parser/include/ernest_parser_ast.hrl` |
| `lib/type_system/` | `erl/typer/` |
| `lib/type_system/src/ern_typecheck.erl` | `erl/typer/src/ernest_typer.erl` |
| `lib/type_system/src/ern_types.erl` | `erl/typer/src/ernest_typer_types.erl` |
| `lib/type_system/src/ern_prelude.erl` | `erl/typer/src/ernest_typer_prelude.erl` |
| `lib/type_system/src/ern_reply.erl` | `erl/typer/src/ernest_typer_reply.erl` |
| `lib/type_system/src/ern_exhaust.erl` | `erl/typer/src/ernest_typer_exhaust.erl` |
| `lib/type_system/include/ern_types.hrl` | `erl/typer/include/ernest_typer_types.hrl` |
| `lib/compiler/` | `erl/codegen/` |
| `lib/compiler/src/ern_compiler.erl` | `erl/codegen/src/ernest_codegen.erl` |
| `lib/runtime/` | `erl/rt/` |
| `lib/runtime/src/ern_rt.erl` | `erl/rt/src/ernest_rt.erl` |
| `lib/runtime/src/ern_check.erl` | `erl/rt/src/ernest_rt_check.erl` |
| `lib/runtime/src/ern_bits.erl` | `erl/rt/src/ernest_rt_bits.erl` |
| `lib/runtime/src/ern_show.erl` | `erl/rt/src/ernest_rt_show.erl` |
| `lib/runtime/src/ern_fs.erl` | `erl/rt/src/ernest_rt_fs.erl` |
| `lib/runtime/src/ern_keys.erl` | `erl/rt/src/ernest_rt_keys.erl` |
| `lib/runtime/src/ern_tcp.erl` | `erl/rt/src/ernest_rt_tcp.erl` |
| `lib/cli/src/ern_cli.erl` | `erl/cli/src/ernest_cli.erl` |
| `lib/utils/src/getopt.erl` | `erl/utils/src/getopt.erl`, unchanged: vendored, and `THIRD_PARTY_LICENSES` names it |
| `lib/ern_stdlib/` | `erl/estdlib/` |
| `lib/ern_stdlib/src/ern_char.erl` | `erl/estdlib/src/ernest_stdlib_char.erl` |
| (and `float`, `foreign`, `int`, `io`, `list`, `map`, `path`, `random`, `set`, `string`) | likewise |
| `lib/*/test/ern_x_tests.erl` | `erl/*/test/<new module name>_tests.erl` |
| `test/ern_docs_tests.erl` | `test/ernest_docs_tests.erl` |
| `test/ern_style_tests.erl` | `test/ernest_style_tests.erl` |
| `test/ern_integration_tests.erl` | `test/ernest_integration_tests.erl` |
| — | `erl/elibs/` for the Erlang side of an Ernest library, modules `ernest_libs_<name>` |
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

1. `lib/` to `erl/`, directory rename only, Makefile and `ERL_LIBS` with it.
2. Directory renames inside `erl/`: `type_system` to `typer`, `compiler` to `codegen`,
   `runtime` to `rt`, `ern_stdlib` to `estdlib`.
3. One application's modules at a time, headers with them, starting at the leaves:
   `utils`, `lexer`, `parser`, `typer`, `codegen`, `rt`, `estdlib`, `cli`.
4. Test modules, each with its subject.
5. The emitted names. `ernest_codegen` writes calls to `ernest_rt` and the standard
   library's modules, so `make golden` runs here and every golden file changes.
6. The documents: README's layout, the architecture note, the plan, CLAUDE.md, the style
   guide, and the naming rule itself, which moves into `docs/style.md`.
7. `libs/`, `build/libs/` and `erl/elibs/` are created empty when the first library is
   written, not before.

## Settled, 2026-09-20

- `ernest_<app>_<thing>` everywhere, the long form, for the two reasons above.
- The vendored `getopt` keeps its name. The risk is that `getopt` is a global name a
  user's foreign code could also load; it is not worth renaming a borrowed file over, and
  the file's own header says where it came from.
- `erl/`, not `core/`, so the top level says which language each tree is in.
- `estdlib` keeps its `e`: the directory is an application name, `code:lib_dir/1`
  resolves it, and `stdlib` is Erlang's. The `e` means the Erlang side of an Ernest
  thing, as in `elibs`; the `ernest_` in a module name means something else, and the two
  never meet in one name.
