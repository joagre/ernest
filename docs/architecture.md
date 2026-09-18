# Ernest Toolchain: Architecture Notes

How the MVP 1 toolchain is built, for whoever starts MVP 2. Written from the code on 2026-09-17; the code wins any conflict. The report is the specification, the plan says why each part is the way it is; this says where things are and what flows between them.

## The pipeline

One Ernest module goes through six stages, each an Erlang application under `lib/` with its own `src/`, `include/`, `ebin/`, `test/`:

| Stage | Module | In | Out |
|---|---|---|---|
| lexer | `ern_lexer` | source text | token list |
| parser | `ern_parser` | token list | AST, records of `ern_ast.hrl` |
| type checker | `ern_typecheck` with `ern_types`, `ern_prelude`, `ern_exhaust`, `ern_reply` | AST, dependency interfaces | typed AST, interface, environment |
| compiler | `ern_compiler` | typed AST, environment | Erlang forms, then a BEAM binary with the `ErnI` chunk |
| runtime | `ern_rt`, `ernest@io` and the other stdlib modules | | what compiled code calls |
| diagnostics | `ern_diag`, in the lexer's application | a `#diag{}` from any stage, the source | the text of §11.5, or its first line |
| cli | `ern_cli` | command lines | `ernc` and `ern` |

`utils` holds the vendored `getopt`. The escripts in `bin/` add `lib/*/ebin` to the code path relative to their own location and call `ern_cli:main/2`.

## Tokens and AST

`ern_lexer:tokenize/1` returns `{ok, [Token]}` or `{error, {Line, Column, Message}}`. A token is `{Category, {Line, Column}, Value}` for `int`, `float`, `char`, `string`, `bool`, `ident`, `typename`, `doc`, and `{Symbol, {Line, Column}}` for operators, delimiters, and reserved words, which are quoted atoms where Erlang would otherwise read them (`'when'`, `'receive'`, `'after'`, `'if'`, `'let'`, `'else'`). Strings are UTF-8 binaries, chars code points.

`ern_parser:parse/1` takes tokens; `parse_string/1`, `parse_expr/1`, `parse_type/1` are conveniences. Every AST node is a record of `lib/parser/include/ern_ast.hrl` with `pos` first, one record per production of Appendix A. Expressions and patterns carry a `type` field the checker fills; declarations carry `doc` and `export`. Two rewrites happen in the parser: parentheses produce no node, and `x |> f(a)` becomes `f(x, a)`. Expressions are parsed by one precedence-climbing loop over the token list; patterns by a second small loop with `::` right-associative and `as` postfix; declarations by recursive descent. No backtracking; the three one-token peeks are documented in the plan, 1.1.

## The type checker

`ern_typecheck:check(Ns, Decls, Ifaces)` returns `{ok, Typed, Iface, Env}` or `{error, [{Line, Column, Message}]}`. `Ns` is the module's namespace as a list of atoms; `Ifaces` are the `#iface{}` records of the modules it refers to.

Types are the terms of `lib/type_system/include/ern_types.hrl`: `{tcon, QName, Args}`, `{tvar, Id}`, `{ttuple, Elems}`, `{tfn, Params, Effect, Result}` where `Effect` is `pure` or a type. Every variable has a `#tv{}` entry in the state's table with its level, its flags (`eq`, `process_only`, `no_reply`, report §3.9), and the name its annotation gave it. `ern_types` owns the state: fresh variables, unification with the effect rules, generalization by levels with pure elision, instantiation, and the printer that error messages and `ernc --doc` share (report §11.5: names as the module writes them, annotation names kept).

`ern_prelude` is the prelude as four tables: the built-in types, the declared types as Ernest source, the standard library's declared types as Ernest source by namespace, and the values as qualified name and type text, plus the process-only and equality-constrained ones. `prelude_env/0` parses them into the starting environment.

Checking a module runs in this order:

1. `declare_types`: every type of the module into the environment, constructors with their canonical field order (report §3.5), reply-carrying computed transitively (§6.6).
2. `check_values`: the `fn`, `let`, and `foreign fn` declarations, in dependency groups from a `digraph` of references. Per group, `check_group`: a `let` cycle is an error (§8.5); each member gets a monomorphic placeholder; annotated shapes are unified first so every member sees every other's signature; then bodies are inferred in order and generalized.
3. `post_checks`, per definition, after inference: `<-` bindings resolved to `Either` or `Optional` from the inferred types (§5.5); operators resolved on the operand type (§4.8); rigid annotation variables (§3.9); the local-fn use order (§5.4); undetermined block bindings (§4.6); exhaustiveness by `ern_exhaust`, Maranget's algorithm with a witness (§5.9); the reply discipline by `ern_reply` (§6.6); the no-reply instantiation check.
4. `check_signatures`: abstract type signatures against the definitions (§4.4).
5. `make_iface`: the exported types and values.

Inside a block, local `fn`s get placeholders shaped by their annotations before any statement, so a use before the declaration type-checks; a local fn is generalized only once every later local fn it references is checked.

The environment is opaque outside the module; `type_state/1`, `resolve_type/2`, `lookup_type/2`, `lookup_con/4`, `node_type/1` are what the compiler reads.

## The compiler

`ern_compiler:forms(Ns, Typed, Env)` builds Erlang abstract forms with `erl_syntax` in one traversal. A context record `#cx{}` threads the namespace, the variable map, a counter, the local-fn table, and the lifted functions. The two tables of the plan, 2.1, are its specification; values follow the ABI of report §8.4.

What the traversal does on the way, the plan's three pre-passes:

- Every Ernest binding becomes a fresh Erlang variable `Name_N`, so shadowing needs no analysis.
- A local `fn` becomes a module function `'name$N'` whose leading parameters are the Erlang variables it closes over: for each free name, the variable in force at its declaration (§5.4), and through the local fns it references, theirs. Bodies are emitted when the block ends. A use in statements calls it with those variables; a use as a value wraps it in a closure.
- `let p <- e` becomes a `case` on `Left`/`Right` or `None`/`Some` whose second clause holds the rest of the block.

Also: `match` becomes `case`; a guard that is not an Erlang guard expression falls through by a continuation; a `receive` guard must be an Erlang guard expression (plan 2.2, MVP 4 lifts it); top-level `let` is a getter over `persistent_term` filled by `'$init'/0` in §8.5 dependency order; `spawn` gets the spawn site as a third argument for `Down` (§6.9); string `<>` is one binary construction; prelude and stdlib names map per plan 2.1, table two, `Int.toString` to `'ernest@int':toString/1` and so on.

`compile/5` runs `compile:forms` with the interface as the extra chunk `ErnI`: a map with a format number, the canonical interface (variables renumbered, lists sorted), the source hash, and per dependency the hash of the interface compiled against. `read_interface/1` reads it back; a chunk of another format is an error, so the module counts as stale. `iface_hash/1` leaves variable names out. `erl_source/3` is `--emit erl`.

Module atoms are `ernest@` and the path with `@` for `/`: `ernest@net@http`. Type members keep their prefix: `'Stack.push'/2`.

## The runtime

`ern_rt` is what generated code calls for processes. Every `Address` is a pid; `send` is `!`; `Reply` is a process alias made with `alias([reply])`, so a late answer after a timeout is dropped by `unalias`; `via` and `monitor` spawn proxy processes so a generated `receive` never sees a foreign message. A reaper process `spawn_monitor`s every process and records its exit reason in an ETS table, which is how `monitor` on an already dead process reports its recorded cause (§6.9). `run/1` wraps every process body so an exception is a fault: `badarith` is `Fault("division by zero")`, a thrown `{ernest, fault, Msg}` is `Fault(Msg)`.

`run_main(Main, Site, Opts)` is the launcher: it starts the reaper and the `stdout` and `clock` processes, binds them under `persistent_term` for `Sys.stdout` and `Sys.clock`, runs `Main` as a process, waits for it, ends every live local process with `ProgramEnd`, flushes stdout, and returns `ok` or `{fault, Msg}`. `Opts` can replace stdout with a function, which the tests use.

The standard library, Appendix E, is hand-written Erlang under `lib/runtime/src/`, one module per namespace, `ernest@list` and so on, each exporting Appendix E under the ABI. The names of the modules MVP 2.5 adds, `Keys`, `Fs`, `Tcp`, `Io.readLine`, and the references `Sys.stdin`, `Sys.keys`, `Sys.fs`, `Sys.tcp`, are in the prelude tables so programs type-check, and `ern_compiler:refused/1` names them for the compile-time refusal and for the targets test to skip. Every contract is Appendix E's; a module header restates the ones its implementation depends on. The prelude operations in a type's namespace, `Int.compare`, live in that type's module (§9). `ernest@float` holds the `Float` operators because a compiled `badarith` carries no operands, so the runtime cannot tell the Float fault from the Int one. `ernest@char` decides the Unicode predicates of E.6 with the `re` module's property classes above ASCII. `ernest@random` is `rand` with the `exsss` algorithm behind a pure interface; a seed is `rand`'s state. `ernest@clock` is `Sys.clock` spoken through `via` and `Address.callForever`. A stdlib type, `Random.Seed`, is declared by `ern_prelude`'s fourth table under its namespace as a foreign type, so `Random.seed(42)` checks and prints as a type from any other module would (§11.5). The system modules follow one pattern, Appendix E.0 rule 8: a function that delivers later is `send` of the message with `via(Wrap, self())` as its target, `monitor`'s shape; a function that waits is `Address.call` with the milliseconds and `None` mapped to `Left(Timeout)`. The compiler's test `prelude_targets_test` asserts that every name in `ern_prelude:values/0` is exported by its module with the arity of its type.

## The tools

`ern_cli` is everything; the escripts are two lines. `ernc` in file or directory mode: modules from paths (shape rule and namespace, §11.1, §4.2), dependencies from a parse-only scan of qualified names resolved against existing `.ern` files, a `digraph` for order and cycles, then per module: dependency interfaces from the build directory, the recompile rule on source hash and dependency interface hashes, type-check, compile, write `.erc`, or `--emit erl`, or `--doc`. Directory mode sweeps stale `.erc` files unless `--no-clean`. `ern`: reads the `.erc`, derives the root from its namespace depth, loads dependencies by namespace from the root and `--load-path` roots, purges and loads each once, runs every module's `'$init'/0` dependencies first, then `run_main` with `main` or `--main`. `--create-config-dir` writes Appendix C's file and an Ed25519 key pair.

## Tests

Four kinds, all run by `make test`:

- EUnit per application under `lib/*/test`, one test function per behaviour, each citing the report section it tests; `make sections` lists sections no test cites.
- Golden files under `test/golden`: the Erlang source emitted for every MVP 1 example, compared as text by the compiler's tests; `make golden` rewrites them after an intended change. The hand-written targets under `test/target` are the two tests that are not self-referential.
- Integration tests under `test/`: every MVP 1 example compiled with `bin/ernc` and run with `bin/ern`, output compared as a multiset of lines with `test/expected`.
- The examples corpus itself: a parser test asserts it exercises every AST record but bitstrings, and the checker's tests type-check every example.

## Where MVP 2 hooks in

- **`Float`**: the checker refuses Float arithmetic in `resolve_operators`; lift the refusal and let `binop` in the compiler call `'ernest@float'` for the four operators. The stdlib module and its fault mapping exist.
- **`foreign fn`, `foreign type`**: the checker accepts them; `ern_compiler:decl/2` refuses `#foreign_fn_decl{}`. Emit a call to the named Erlang function wrapped in a catch that turns an exception into a fault (§8.4); the `Foreign.*` conversions already exist as `ernest@foreign`. `stdlib/*.ern` can then replace the Erlang modules one by one, MVP 2.5, since generated code calls `ernest@list:map/2` either way.
- **Bitstrings**: the lexer has no `<<` and `>>` tokens; `#e_bits{}` and `#p_bits{}` exist in the AST and the checker and compiler refuse them. Type against `Bytes` and emit BEAM's bit syntax directly.
- **Abstract type ownership** (§4.4): the checker has the signature; add the constructor-visibility check in `check_values`. One Erlang module per type with the signature as export list is a compiler change in `decl/2` and `module_atom/1`.
- **`Deadlock`** (§8.6): the reaper knows every live process; add the waiting state and the timers to what it tracks.
- **`--shell`**: needs an incremental `check` that keeps the environment between inputs; `ern_cli:ern_main/2` has the option and refuses it.
- **The system processes of MVP 2.5** (`stdin`, `keys`, `fs`, `tcp`): foreign processes bound like `stdout` and `clock` in `run_main`, speaking the §9.3 types, with `ernest@keys`, `ernest@fs`, `ernest@tcp`, and `Io.readLine` over them as `ernest@clock` is over the clock; then the four names leave `ern_compiler:refused/1`. `Sys.tcp` answers `Listen` and `Connect`; each socket is a process over its `gen_tcp` port speaking `SockMsg`, so it is an address that `monitor`, `kill`, and `via` accept. If the two hops per read cost, measured by the echo server the plan names, `Tcp.read` and `Tcp.write` become foreign calls on the port while the socket process keeps identity and lifetime.
