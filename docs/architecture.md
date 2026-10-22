# Ernest Toolchain: Architecture Notes

How the toolchain's code is arranged: its stages, its modules and what each does, the runtime, and the kinds of tests. The code wins any conflict with this document. The language is the report's; the layout of the repository and the commands are [`development.md`](development.md)'s; the reasons are the [decisions log](log.md)'s; the roadmap is the [plan](plan.md)'s. The Erlang follows [`style.md`](style.md). How a function does its work is its own comment's; this document says where the function is.

## The pipeline

One Ernest module goes through these stages, each an Erlang application under `erl/`:

| Stage | Modules | In | Out |
|---|---|---|---|
| lexer | `ern_lexer` | source text | tokens |
| parser | `ern_parser`; `ern_ast`, a node's span and the walks later stages share | tokens | AST, records of `ern_ast.hrl` |
| formatter | `ern_format` and its printer `ern_pretty` (§11.6) | source, tokens with comments, AST | the text laid out |
| checker | `ern_typecheck`, with `ern_types`, `ern_prelude` (§9), `ern_exhaust` (§5.9), `ern_bound` (§3.11), `ern_scope` (§5.4), `ern_bitspec` (§5.11), `ern_interface`, the interface chunk, and `ern_canonical`, the canonical forms and their chunk (Appendix H) | AST, dependency interfaces | typed AST, interface, environment; the canonical forms and their hashes |
| emitter | `ern_compile`, a checked module's compile; `ern_emitter`, the back end, which makes a unit from canonical forms; `ern_docs`, the `Docs` chunk; `ern_descriptor` (§8.4), the shell's descriptors | typed AST and environment; for the back end, a `#unit{}` | Erlang forms, then BEAM with the `ErnI`, `Docs` and `ErnC` chunks |
| runtime | `ern_rt`, the processes and the runner; `ern_boundary` (§8.4); `ern_show` (E.1); the system modules `ern_fs`, `ern_tty`, `ern_tcp` and `ern_os`; `ern_peer` (§8.7); `ern_code`, the code table (§8.7); the standard library's shims; `ern_tty_signal`; `ern_exec`, the one helper in C | | what compiled code calls |
| diagnostics | `ern_diagnostic`, in `shared`, beneath every stage | a `#diagnostic{}`, the source | the text of §11.5 |
| chunks | `ern_chunk`, in `shared`, which reads a compiled module's chunk as data alone (§11.1) | a chunk's bytes | the term, or `error` |
| namespaces | `ern_namespace`, in `shared`, the one mapping between a path's components and a namespace's segments (§4.2, §11.1) | a component or a segment | the other |
| tree | `ern_tree`, in `shared`, the toolchain's tree and the builds of its own under it (§11.1, §11.2) | a build's path | its directory |
| cli | the modules below | command lines, shell inputs | `ern`'s jobs, a session |

`erl/json` is the one application beside the stages, `libs/json`'s primitives (*The libraries' primitives*).

The modules of `cli`:

| Module | Job |
|---|---|
| `ern_cli` | the command, its jobs and the runner's start (*The tools*) |
| `ern_build` | the build every job reaches (§11.1) |
| `ern_shell` | the shell's front end (§11.2, *The shell*) |
| `ern_code_load` | `Code.load` (E.28, *The code table*) |
| `ern_page` | §11.4's renderer, the pages of `ern doc` and the shell's `:doc` |
| `ern_examples` | a module's doc examples as the cases of `ern test` (§11.2) |
| `ern_release` | the version text, `-dev` marking a build that is no release |
| `ern_out` | a job's standard output and standard error (§11) |
| `ern_signals` | the handler of termination and hangup (§8.6, §11.2) |
| `ern_node` | a node's configuration directory, made, checked and read (§8.3, §11.3, Appendix C) |
| `ern_carrier`, `ern_epmd`, `ern_gateway` | a node's carrier, its port mapper and its gateway (*A node*) |
| `ern_exchange`, `ern_arrival` | the exchange and the unit an exchange makes (*The exchange and arrivals*) |
| `getopt` | the vendored option parser, each job's options a spec of its own |

### The launcher

`bin/ern` finds its tree, refuses a working directory whose name is not UTF-8, and starts the host with `-noinput` and `erl/*/ebin` on its code path; its header comment says what else it sets and why. No compiled Ernest module is on that path: a unit of the standard library, the shell or the shell's two libraries is loaded from its `.erc` at its first call (*The code table*). It calls `ern_signals:install/0` and then `ern_cli:start/0`. [`design/install.md`](design/install.md) lays out the installed tree.

`ern_cli:start/0` installs `ern_signals` again, for a caller that is no launcher, and runs `ern_cli:ern/2`, whose status the host ends with (§11.8).

Every job but the shell writes its text through `ern_out`, ports on descriptors 1 and 2 in place of the host's `user` (§11). The shell keeps `user`, which is its terminal, and `ern_tty:is_terminal/1` asks `user` whether a stream is a terminal.

`ern_signals` takes `SIGTERM` and `SIGHUP` from OTP's default handler. During a run it ends the run through `ern_rt:signal/1` (§8.6); on a node hangup asks `ern_carrier:reload/0` (§8.7); otherwise it ends `ern` at once, `die/2` sending the signal again (§11.2).

`erl/app.mk` passes `VERSION` to `erlc` as a macro, with `DEVELOPMENT` beside it, by which `ern_release:version_text/0` carries `-dev`. The release archive recompiles `ern_release` without it (`tools/install.sh`). `ern_carrier:cookie/2` reads the mark: a development build's floor is the digest of its own code (§8.7).

The Emacs mode calls the toolchain only as `ern format -` ([`design/emacs_mode.md`](design/emacs_mode.md)).

## Tokens and AST

`ern_lexer:tokenize/1` returns `{ok, [Token]}` or `{error, #diagnostic{}}`. A token is `{Category, Position, Value}` for a literal, an `ident`, a `typename` or a `doc` block, and `{Symbol, Position}` for the rest; `Position` is `{Line, Column, End, PreviousEnd}`. `tokenize/2` with `comments` adds each comment as a token, for the formatter.

`ern_parser:parse/1` takes tokens; `parse_string/1`, `parse_expr/1`, `parse_type/1` and the shell's `parse_statement/1` are conveniences. The diagnostic of an unfinished input carries `expected`, which completion reads, and `within`, which `Shift-Tab` reads (§11.2).

Expressions are parsed by one precedence-climbing loop, patterns by a second, and declarations by recursive descent. Nothing backtracks: the lookaheads are those Appendix A's last paragraph names.

Every node is a record of `erl/parser/include/ern_ast.hrl`, one per production of Appendix A, `span` first, which `ern_ast:span/1` reads. Expressions and patterns end in a `type` field the checker fills, and declarations carry `doc` and `export`.

- A name, `#e_var{}`, carries its `referent`, what §4.2's lookup resolved, which the canonical form reads (Appendix H).
- A `fn` declaration's requirement is a list of `#member{}`, and `a.compare` in its body an `#e_member{}` (§4.9).
- The parser rewrites twice: parentheses make no node, and `x |> f(a)` is a call with its `pipe` flag set (§5.1).
- A clause's `or` alternatives are one `#p_or{}` (§5.9).
- `prune_docs` keeps a doc block only where §2.2 attaches it; the module's is `#module_doc{}`, first in the list.

## The type checker

`ern_typecheck:check/3` takes a namespace, the declarations and the `#interface{}` records of the modules referred to, and returns `{ok, Typed, Interface, Env}` or `{error, [#diagnostic{}]}`; the shell calls `check/4`. In the module, `infer/2` gives an expression its type and `check_expr/5` checks one against an expected type, which gives a diagnostic §11.5's labels.

Types are the terms of `erl/checker/include/ern_types.hrl`. Each type variable has a `#type_variable{}`, with its level and its restrictions (§3.9), in the `#type_state{}`. `ern_types` owns that state: unification, generalization, instantiation, and the printer that diagnostics and `ern doc` share.

`ern_prelude` holds §9 as tables, each entry documented. `ern_typecheck:prelude_env/0` builds the starting environment from them and from `ern_prelude:stdlib_interfaces/0`, and `ern_prelude:docs/0` gives `ern_page` the prelude's page.

A module is checked in this order:

1. `declare_types`: the types and their constructors (§3.5), `mark_abstract` (§4.4), and `check_recursive_groups` (§3.9).
2. `check_values`: the value declarations in dependency groups (§4.2), each checked by `check_group` when `run_group` reaches it or `demand` asks for it (§4.8), and `let_cycles` after each (§8.5).
3. `post_checks`, per definition, which the module's header comment lists; then `ern_bound:check/2` reads each top-level definition for a spawn on a peer (§3.11) and a `Code.running` (E.28).
4. `check_abstract` and `check_exports` (§4.2, §4.4).
5. `interface_of`: the exported types and values, and the private types they name (`private_types/3`, §4.2, §11.1).

A requirement (§4.9) is held in these places:

- on a declaration's `#scheme{}`, which `ern_types:format_scheme/2` prints and `ern_types:instance/2` instantiates;
- in the environment's `requirement`, the members in force;
- in a use's `supplies` or an operator's `member`, a `#pending_member{}` until the definition ends, when `supplied/2` replaces each with a supply of `ern_types.hrl` (the glossary's *Supply*).

`derived_members/2` makes each `derives compare` an `fn T.compare` declaration before the values are checked (§3.5). `filled/7` reads `Ops(..Set)` as a construction, and `updated_through_paths/7` a path in a record update as bindings and constructions (§5.6).

A block's local `fn`s (§5.4), an initializer (§4.6, `is_value_form/1`) and a built-in type's operators (`builtin_operators/2`, §4.8) are checked in the same module.

The environment is opaque outside the module. The compiler and the shell read it through functions of its own: `type_state/1`, `resolve_type/2`, `lookup_type/2`, `lookup_constructor/4`, `node_type/1`, `foreign_implementation/1`, `declared_scheme/3`, `fields/2` and `let_order/1` (§8.5) among them.

## The compiler

The build's path is typed tree, form, unit. `ern_compile:compile/5` takes the checker's typed tree and environment, has `ern_canonical:module/5` write the forms, and gives `ern_emitter:unit/1` a `#unit{}` (`erl/emitter/include/ern_unit.hrl`).

A `#unit{}` holds the module's `#definition{}`s with their sourced forms, what the build adds that is no definition's, and the link, `#link{}`, which `ern_compile:link/5` reads from the environment's interfaces. The emitter reads nothing else, so that a unit a node makes from forms that arrived goes through the same back end (`units_from_forms_alone_test_`). The `ErnI` and `Docs` chunks are the build's and no unit's. The interface the `ErnI` chunk holds, and the build gives a dependent once the module is checked, is `ern_compile:interface/5`'s: the checker's, with the forms' hashes, reaches and positions, and the values of its exported ground bindings, which `ern_emitter:ground_terms/2` gives over a link of the types they name (§11.1).

Three makers give the emitter a `#unit{}`:

- the build, `ern_compile:compile/5`;
- the shell's load and `Code.load`, from what a `.erc` records, `ern_compile:from_compiled/5`;
- a node's arrival, `ern_arrival`, linked through the code table.

All three compile through `ern_compile:compiled/2`.

`ern_emitter:unit/1` builds Erlang forms with `erl_syntax` in one traversal of each form, threading `#emit_context{}`. `prepared/2` first marks the references within a group and each lambda's and local fn's position (Appendix H). A value's representation is §8.4's ABI.

A unit's functions are named by position (§11.1), as `ern_emitter`'s header comment gives them: `'$N'` (`function_name/1`), `'$N.P'` for a lifted local fn, `'$N.P.entry'` for an entry, `'$type_K'` for a descriptor, and `'$lacked_K'` for a lacked function. The functions the runtime calls keep their names: `'$init'/0`, `'$deps'/0`, `'$tests'/0`, `'$spawned'/2` and `'$code'/0`. The interface's `positions` say where a dependent calls each.

A caller from Erlang finds a function by its qualified name through `ern_code:function/2`: `ern_cli` for the entry point and the shell's program, `ern_shell` for an input's entry, `ern_page`, and the tests through `ern_named`. A fault's trace (`ern_rt:trace/1`) names each frame of a unit's code as a spawn site is named through `ern_code:function_text/3`, which reads the unit's `'$code'/0`, the namespace its sites name its declarations under and each binding's first line among it, and the name the recorded forms give an input's expression; a frame of `'$init'/0` is named by the binding whose source holds its line, and the frames beneath the program's outermost are left out (E.21). A function value has no line, and `ern_code:value_text/1` names it so without one, a fun of `'$init'/0` by the binding whose value it is, for the cause of an argument foreign code gives it (§8.4).

### What the emitter writes

Each construct's function says how it is written:

- a local `fn`, lifted to `'$N.P'` (§5.4);
- `let p <- e`, a `case` (§5.5);
- a selected field (§3.5, §8.4);
- a clause's alternatives, `alternatives/3` (§5.9);
- a top-level `let`, a getter over `persistent_term` that `'$init'/0` fills (§8.5, §11.1); one whose initializer is a ground term, `ground/2`, is read as its value, `term_form/1`, in its module and, through the interface's `terms` and a `#linked{}`'s `term`, in a dependent, and `'$init'/0` gives it its value before any initializer runs (§11.1);
- a spawn on a peer, `spawned/2`, its captures, `captures/1`, and a service's hash, `service_hash/1` (§8.7);
- a spawn's site, `site_name/2`, written by `ern_namespace:site_text/2` as a frame of a trace is (§6.9, E.21);
- a fault the code meets, `raised/1`, the host's throw where it is met, so that the trace holds the function that met it (§7.3);
- a requirement's members, `supply_form/2` and `enclosing_members/3` (§4.9);
- a `Float` operation, `float_operation/5`, and a float segment's variable, `variable_form/1` (§3.1, §7.4);
- a type's descriptor, `describe/4`, a function type's maker, `built_descriptor/1`, and the printing of a check's cause, `printed/2` and `printing/2` (§8.4, §11.5);
- whether the unit builds a function value, `function_value/2` (§11.2).

`'$code'/0` lists what the unit holds, which the code table reads. `compile/5` alone writes it, so the golden files and `--emit-erl` have none. `ern_emitter:source/1` is `--emit-erl`, each function under a comment that names it.

A unit is the module's Erlang name, `ern@` and its path (§11.1), unless `compile/5`'s `units` names another: the shell's unit of a reload's version, `ern@counter$2` (`ern_compile:unit_of/2`, §11.2). An input of the shell's session has its lines counted as the session counts them before the emitter reads its forms (`ern_compile:session_lined/2`), so that its code's lines, its sites' and its trace's agree.

### The chunks

| Chunk | Owner | Holds |
|---|---|---|
| `ErnI` | `ern_interface`: `encode/2`, `read/1`, `written/1`, `hash/1` | a format number, the canonical interface, and what §11.1's recompile rule compares, `references` and `builds_functions` among them |
| `ErnC` | `ern_canonical`: `module/4`, `closed/1`, `recorded_source/1`, `read/1` | `{FormVersion, #recorded{}}`, the records of `ern_canonical.hrl` (§8.7, Appendix H) |
| `Docs` | `ern_docs`: `ern_docs:build/4`, `read/1`, `doc_key/1` | EEP 48's documentation, an entry per declaration §11.4 renders, an abstract type's constructors marked private, which a page leaves out, its `BeamLanguage` `ernest` |

Each chunk is read through `ern_chunk`. A name a shell session declares is written under `$Session` in a form and in `'$code'/0` (`form_name/2` in `ern_canonical` and in `ern_emitter`; Appendix H, §11.2).

## The runtime

`ern_rt` is what compiled code calls for processes, and the runner. Its header comment gives a value's representation (§8.4), the shapes of an address and a reply (§6.5, §6.6), and the answers a call takes. The shape the runtime keeps its promises by, what it keeps and where, the look, a launch, a call, a kill, the boundary and the frames, is [`design/runtime.md`](design/runtime.md)'s; this section is the map of its modules and functions.

### The tables

| Table | Owner | Row, keyed by its first element | Holds |
|---|---|---|---|
| `ern_processes` | `ern_rt` | `{Pid, Site, SpawnOrder, Root, Peer}` | each process the runtime started or adopted |
| `ern_callees` | `ern_rt` | `{{Callee, Caller}, Reply}`, ordered, with the host's write concurrency | each pending call on a process of the node, which a restart reads (§6.9) |
| `ern_faults` | `ern_rt` | `{Subscriber, Address}` | the subscriptions to faults (E.21) |
| `ern_terminating` | `ern_rt` | `{Subscriber, Address, Told}` | the subscriptions to the program's end (E.23) |
| `ern_held` | `ern_rt` | `{{source, Holder}, Count}` and `{{opened, Pid}}` | the sources, and the processes a system module opened (§8.6) |
| `ern_deliveries` | `ern_rt` | `{{Recipient, Starter, Pid}}`, ordered | the deliveries in flight (§6.9) |
| `ern_restarts` | `ern_rt` | `{Pid, Alias}` | the restarts a process may be asked (§6.9) |
| `ern_checkers` | `ern_rt` | `{{checker, Key}, Checker}` and `{{behind, Checker}, Pid, Address, Key}` | the checkers (§8.4) |
| `ern_launch` | `ern_rt` | `{reading, Kind}`, `{entry_process, Pid}`, `{deadlock_victim, Pid}`, `{ending, Runner, Launch}`, `{wait_over}`, `{utilization, Utilization}` | the launch's state (§8.2, §8.6, §8.7) |
| `ern_offers` | `ern_rt` | `{{Name, Hash}, Address, Process}`, ordered | the node's offers (§8.7) |
| `ern_offered` | `ern_rt` | `{Process, Service}`, a bag | each process's own services (§8.7) |
| `ern_initialized` | `ern_rt` | `{ErlangModule}` | the modules whose initializers have run (§8.7) |
| `ern_notes` | `ern_rt` | `{{CallerNode, Reply}, Callee, Caller}`, ordered | the notes of calls from other nodes, a compute's among them (§8.7) |
| `ern_spawns` | `ern_peer`, held by the gateway | `{{Node, Ref}, Waiting, Order}`, ordered | the spawns on a peer that wait for an answer (§8.7) |
| `ern_utilizations` | `ern_peer`, held by the gateway | `{Node, Utilization, At, Interval}` | each peer's last telling (§8.7) |
| `ern_code` | `ern_code`, held by the code table's holder | a bag, its keys under *The code table* | the code table (§8.7) |
| `ern_code_sums` | `ern_code`, beside it | a row for each count | the sums of the host's counts (§11.2) |
| `ern_shell` | `ern_shell`, held by the runner | `{Key, Value}` | the session as it stands, and what its inputs and loads leave (§11.2) |

`run_main` makes `ern_rt`'s thirteen (`tables/0`), each described where `ern_rt` defines it; `make load` counts their rows ([`memory.md`](memory.md)). `ern test`'s `run_tests/5` keeps the running test in a table of its own.

### The processes

| Process | Started by | Held by | Job |
|---|---|---|---|
| the runner | the caller of `run_main/3` | | starts the rest and waits for the end (*The runner*) |
| the entry process | the runner | the runner's monitor | the initializers, then the entry point (§8.5) |
| the reaper | the runner | | spawns and monitors every process of the program, and finds a deadlock (*The reaper*) |
| `stdout`, `stderr`, `stdin`, `fs`, `terminal`, `tcp`, `os`, `clock` | the runner (`started_system/1`) | `persistent_term`, `{ern_rt, Name}`, read by `system_process/1` | the system processes (§8.2, *The system processes*) |
| a delivery | the reaper, the clock or an end's teller (`counted_link/2`, `wrapped/3`) | a link to its starter | applies a wrap and delivers the message (§6.5, §6.9) |
| an end's teller | the runner (`told/3`) | the reaper (`reaper_held/2`) | tells one subscriber of `Os.termination` (§8.6, E.23) |
| a kept process | a gateway's worker (`kept/1`) | the reaper (`reaper_held/2`) | applies an adapted address's function to a peer's messages (§6.5, §8.7) |
| a checker | `ern_rt:checker_for/3` | `ern_checkers` | checks each message foreign code sends (§8.4) |
| a courier | the terminal | a link to the terminal | applies one subscriber's wrap to its keys (E.16) |
| a request's worker | `fs` | | does one `Fs` request (E.17) |
| a listener's or a socket's process | `tcp` (`opened/4`) | `ern_held`, as opened | a listener or a socket (E.18) |
| a connect's or an accept's worker | `tcp` (`counted/1`) | `ern_held`, as a source | one connect or accept (E.18) |
| a closer | a socket (`lingering/4`) | | closes a host socket once the far end has taken its bytes (E.18) |
| a running program's process | `os` | `ern_held`, as opened | owns the program's `ern_exec` port (E.23) |
| the code table's holder | `ern_code`, at the table's first use | | holds `ern_code` and `ern_code_sums` for the host's life |
| the gateway, registered `ern_gateway`, and a worker for each peer | `ern_carrier:start/1` | | takes the runtime's frames from the peers (*A node*) |
| the exchange, registered `ern_exchange` | `ern_gateway:start/0` | | carries a reach's definitions between nodes (*The exchange and arrivals*) |
| an evaluator | `ern_shell` (`evaluate/3`) | the session | evaluates a load's bindings, the root of what they start (§11.2) |

The gateway and the exchange are the only registered processes. A delivery, a courier and a kept process act for their recipient through `ern_rt:acting_for/1`, an `#acting{}` in their dictionary (§6.5, §6.9).

### Processes, calls and restarts

- A spawn goes through the reaper, which writes the process's `ern_processes` row; `run/1` wraps every process body, so that an exception is a fault (§7.4).
- `send/2` applies an adapted address's functions (`adapted_way/2`), and a message to an address made on another node goes to that node's gateway (§6.5, §8.7).
- A call (§6.6) is `call/3,4` and `call_forever/2,3`; a compute (§8.7) is `compute/3`, its process on the peer running `computing/2`.
- `restarting/2` runs a restarting function, and `fresh_run/0` begins a new run (§6.9). `ask_restart/1`, `start_cause/0` and `spawn_order/1` are `Supervisor`'s shims (E.22).
- A time is a deadline on the monotonic clock, `deadline/1` and `remaining/1` (§6.3). The clock holds the alarms, setting those at a time again when the host's time offset changes (`set_again/1`, E.15).
- A caller keeps its call under its `CALL` key, its callee and the reply, put before the request is sent and erased once the call's records are dropped (`pending/2`, `uncalled/0`); the callee's row is written for a callee of the node, and a note to its gateway for one of another node (§6.6, §8.7).
- Every end the runtime gives a process from outside it but the program's end goes through `killed/2`: a process of its own suspends the victim, reads its `CALL` key, drops the call's records and ends it, a source while it works, so that two processes killing each other cannot each suspend the other. A `kill` of a process of another node is a frame to that node's gateway, which carries it out so (§6.9, §8.7).
- `Process.status` reads `ern_processes`, the host's status and the process's `CALL` key (E.21).

### The reaper

- It monitors every process a program spawns, every listener, socket and running program a system module opens (`opened/3`), and every process a `monitor` names that it did not start (§6.9).
- Each `Down` is delivered by `wrapped/3`, a delivery. Where the reaper learns of a process's end, it ends every delivery to it (`abandoned/1`).
- It looks for a deadlock (`look/0`, §8.6) after `LOOK_SOON` or `LOOK_LATER` milliseconds without a message. It does not look on a node or while the shell holds the terminal.
- Sources (§8.6) are counted where they begin: the clock's alarms, `stdin`'s requests, the terminal's subscriptions, the reaper's own monitors, and a kill under way (`killed/2`).
- What the look needs of a process, the process keeps in its own dictionary, under the look's keys, and the look reads it with the process's top frame once every process waits (`still/1`): a receive with a deadline is `TIMED` (`timed/0`, `untimed/0`), a call to a system process, a listener, a socket or a running program is a pending I/O by its `CALL` key (`calling_the_system/2`), and a process inside foreign code where its stack cannot show it is `FOREIGN` (`entered_foreign/0`, `left_foreign/0`), while a function given to foreign code runs (the wrapper `ern_emitter`'s `called/2` writes) and while the runtime waits on a peer, a port, the code table's holder, a restart's answers, `Code.load`'s evaluation or the program's end. A function on top of the stack that is neither a unit's nor of the toolchain's own (`is_ernest/1`, `own_modules/0`) is the host's, a receive inside foreign code; a foreign call writes nothing.
- Faults are reported by `report/5` (E.21), to the run's `faults` function and each subscriber in `ern_faults`. `run_main` sets the host's backtrace depth to 64, of which a trace shows twelve (E.21, E.28). A fault the runtime gives a waiting process, a deadlock, carries the process's stack as `found_fault/2` finds it (§7.3).

### The runner

`run_main(EntryPoint, Site, Options)` makes the tables, starts the reaper and the system processes, and runs in the entry process the standard library's initializers, the `init` option and the entry point (§8.5). Its comment lists its outcomes and its options.

The runner's `init` is `ern_rt:init_modules/1` over the modules it loaded, ordered by each one's `'$deps'/0`, the shell's own among them for `ern shell`.

At the end the runner tells the subscribers of `Os.termination` (`told/3`, §8.6), ends every process with `ProgramEnd`, and flushes `stdout` and `stderr` (`sink_flushed/1`). `ern_cli:report_outcome/2` makes the outcome §11.8's status.

A reference tags each launch, held with its runner, its reaper and what its options give in the launch's row of `ern_launch`, `#launch{}`, which goes with the table at the end (`launch/0`). Each adapted address its processes make holds it (§8.7, §11.2).

### The system processes

- `stdout` and `stderr` write through a function or a port on a descriptor, `{fd, N}`, which learns when the stream has gone (§8.2). `stdin` is a port on descriptor 0, opened for each request. All three are `ern_rt`'s, and so is the clock.
- `ern_fs`, `ern_tty` and `ern_tcp` are the processes behind `Fs`, `Terminal` and `Tcp` (E.17, E.16, E.18), each speaking its module's message types.
- The terminal reads keys through standard input in `stty`'s raw mode. `ern_tty_signal`, added to OTP's signal server at the first subscription, sends it each `SIGWINCH`.
- A socket is a process over its `gen_tcp` port, alive until `Tcp.close`. One whose bytes the far end has not taken hands its host socket to a closer, `lingering/4`.
- `ern_os` (E.23) answers `Start` with the program's process, which owns a port of `ern_exec` (`erl/runtime/c_src/ern_exec.c`). Run with no program, the helper answers `ern_os:host/0`, for `Os.user` and `Os.environment`.
- `ern_exec` also holds a node's lock on `ernest.pid`, its `lock` mode, and signals the node that holds one, its `node` mode (§8.7, §11.2).

### A node

The modules of a node (§8.7) are `ern_node`, `ern_carrier`, `ern_epmd` and `ern_gateway` in `cli`, and `ern_peer` in `runtime`.

- `ern_node` reads the configuration directory into a `#configuration{}` (`erl/cli/include/ern_node.hrl`) and holds `ernest.pid` through the helper's `lock` mode, a port the runner's process owns (`pid_written/1`).
- `ern_carrier` is the carrier: the host's boot flags (`boot_flags/1`), the node's name (`name/1`, `host/1`), the cookie (`cookie/0`), the rule that accepts a peer (`verify/3`), the start (`start/1`), a reload (`reload/0`), the end in order (`depart/0`), and the lines a node says (`say/1`).
- `ern_epmd` answers the host in the port mapper's place, from the configuration.
- `ern_gateway` takes every frame of the runtime's from every peer and hands each to a worker for that peer, which `ern_peer:frame/2` reads. Its header comment lists the frames.
- The gateway records a call's notes in `ern_notes` itself (§8.7). It answers a utilization, tells each connected peer its own every `utilization-interval`, and holds each peer's telling in `ern_utilizations`.
- A gateway's worker keeps a process for each adapted address a peer sends to (`ern_rt:kept/1`), and hands a spawn or a compute of a function the node lacks to the exchange.
- `ern_peer` is `Peer`'s shims (E.27): `offer/2`, `find/2`, `spawn/3`, `compute/2`, `utilization/2` and `picked/0`, with the work its frames give the gateway.

### The code table

The code table (§8.7) is `ern_code`'s bag of that name, made at its first use by a process of its own (`ensure/0`). `load/3` loads a unit from its file, and `loaded/2` and `loaded/3` put a unit's rows as it loads, read from its `'$code'/0`; `unloaded/1` takes them.

`ensure_loaded/1` loads a module where the host holds none of its name, as the host's `code:ensure_loaded/1` does: a unit of the toolchain's own from its `.erc`, which `own_file/1` finds by namespace in `build/stdlib`, `build/shell`, `build/libs/ansi` and `build/libs/markdown`, and any other module as the host loads it. The runtime's error handler, `ern_rt:undefined_function/3`, calls it at a first call, on every process the runtime starts and on the one each job runs in (`ern_cli:start/0`); `ern_code:function/2` calls it too.

Its keys are `{hash, Hash}` for a function or a type, `{lambda, Hash, Position}`, `{unit, Unit}`, `{binding, QualifiedName, Hash}`, `{term, QualifiedName, Hash}` for a ground binding's value, `{foreign, QualifiedName}`, `{declared, QualifiedName}`, and `{forms, Unit}` for what a unit's compiled form records. The module's header comment gives each row.

- Its lookups are `function/2`, `function_text/3`, `value_text/1`, `spawnable/1`, `holders/1`, `linkable/1`, `valued/1`, `ground/1`, `forms/1`, `called/1`, `absent_binding/1,2`, `foreign/2`, `declared/1,2` and `present/1`. Where several units hold an identity, `answering/1` picks one (§8.7, §11.2).
- `running/1` is `Code.running`, and `hashes/1` is `Code.hashes` (E.28).
- `is_free/1`, `is_held/2`, `fresh_unit/1`, `unit_beside/2` and `placement/4` name and place a unit for the shell's load and `Code.load`. `binding_keys/1` gives the values a refused load erases.
- The host's limits (§11.2) are `counts/0`, the sums `ern_code_sums` keeps (`summed/1`), and `nearing/0`. `ern_cli:say_limits/0` says the lines at a run's start, at each arrival and `Code.load`, and at each load of the shell's.

`Code.load` (E.28, §11.2) is `ern_code_load:load/1`, run in the calling process; its header comment gives its steps. It finds each module on the run's load path, `ern_cli:load_path/0`, places it through `ern_code:placement/4`, and makes a unit from forms through `ern_compile:from_compiled/5`. Its units load in one `code:atomic_load/1`, and their bindings are evaluated under a mark (`ern_rt:rooting/0`).

### The exchange and arrivals

- The exchange (§8.7) is `ern_exchange`, registered on each node from its start, which keeps its exchanges in its own state and no table. It plays both parts, the spawner's node and the node asked, which its header comment gives.
- Its frames are `reach_request`, `reach`, `lacks` and `code_frame`, passed to it by the gateway as they come. `ern_canonical:verified/2` verifies a code frame's forms.
- `ern_peer:reach_lacked/2` and `ern_peer:foreign_lacked/1` find what a reach needs that the node lacks; `ern_peer:failed/4` gives every refusal, said through `ern_gateway:outcome/2`.
- An arrival (§8.7, §11.2) is `ern_arrival:received/5`: a reach's definitions made one `#unit{}`, compiled by `ern_compile:compiled/2`, loaded off the code path, and put in the code table with what it records.
- An arrival is named from the pool, `ern$N` (`ern_arrival:name/1`). What it names that the node lacks is linked to a lacked function, `'$lacked_K'` (`lacked/2`).

### The standard library

Appendix E is one Erlang module per namespace, `ern@list` and so on, compiled by `make` from `src/stdlib/` into `build/stdlib`, one `.erc` each. The standard library is every `.erc` of that directory beside the toolchain (`ern_prelude:stdlib_files/0`), whose interfaces the checker reads and whose modules a run loads at its start, for their initializers (`ern_rt:stdlib_modules/0`, §8.5). The library's own build sets the directory aside (`ern_prelude:set_stdlib_directory/1`), and `ern build` lets its source root take prelude namespaces (`ern_build:is_stdlib_root/1`, §4.2).

`ern_prelude` holds §9 alone. A module declares its own types, and a prelude operation in a type's namespace, `Int.compare`, is in that type's module.

- A shimmed module's Erlang helper is `ern_` and the module's name: `ern_bytes`, `ern_char`, `ern_float`, `ern_foreign`, `ern_int`, `ern_io`, `ern_map`, `ern_path`, `ern_set` and `ern_string`, each saying in its header comment what it holds that no host function does as it stands (E.0 rule 1). The rest of the primitives are host functions named in their `foreign fn`s.
- `ern_char` reads E.6's predicates from the host's `unicode_util` tables. A `Set` is `{set, S}`, `S` a version 2 `sets:set`.
- `ern_io:show/2` and `ern_io:debug/2` write through `ern_show`, which reads a value by its type's descriptor (`ern_descriptor`, E.1); the shell prints through `ern_show` with a depth and a length.
- `ern_bits` makes the checks of §5.11 and §7.4 that the host's bit syntax does not.
- The foreign boundary is `ern_boundary` (§8.4): `expose/2,3`, `raised/6`, `check/3` and `value/3`, with `conformed/3` beneath them (§3.1). A function value's wrappers call `result/4`, `argument/5` and `raised/4`, whose causes name the function, which the descriptor leaves for them to write in (§7.4).

The tests that hold the library to its names: `erl/runtime/test/ern_stdlib_tests.erl` calls each module by the ABI, each function found through `ern_named`. `primitives_test`, in `erl/checker/test/ern_prelude_tests.erl`, holds each module's `foreign fn`s equal to its section's primitives. `prelude_targets_test`, in `erl/emitter/test/ern_emitter_tests.erl`, and `stdlib_targets_test`, in `erl/runtime/test/ern_doc_tests.erl`, hold each name at the position its interface gives it.

### The libraries' primitives

A library under `src/libs/` stands on the host as the standard library does. The primitives it needs in Erlang are an application of their own under `erl/`, named for the library, on the code path as every application is (§11.2).

`erl/json` is `libs/json`'s (G.6): `ern_json:parse/1` and `ern_json:format/1`.

## The tools

`ern_cli:ern/2` takes the job from the first word (`jobs/0`), each job's options a getopt spec of its own. `no_job/1` refuses a word that is no job, and `one_spelling/2` an option's second spelling.

`ern_build` holds the build and what every other job takes from it: a module's source and namespace, an interface, the load path, and a file written whole (`write_whole/2`, `write_output/2,3`, §11). It alone of the jobs is in the compiler's hash (`compiler_modules/0`, §11.1). `load_path/1` is every job's load path past the roots the job puts first: the options' directories, then the build of each library, which `ern_tree:libraries/0` lists (§11.1, §11.2).

`ern run`, `ern test` and `ern shell` also install `ern_signals`, for a test that calls the job, and lower the host's logger to warnings.

- **`ern build`** (§11.1): `modules_of/3` finds the modules, and `compile_order/3` orders them over a `digraph` that holds the build root's and the load path's modules too (`recorded_uses/3`), each after those it uses and otherwise in the order of their paths (`ordered/2`); `module_cycle/1` refuses a cycle. A checked module is written once every module its forms name is checked (`built/3`).
- **`ern run`** (§11.2): `program/2` loads the `.erc` and its dependencies (`loaded_unit/3`, `no_cycle/2`) and calls `run_main`. `reporting_options/2` gives the run `report_fault/3` as its `faults`.
- With `--config-dir` and no `.erc`, `ern run` starts a bare node (`as_node/4`, `run_bare/2`, §8.7).
- **`ern shell`** loads a file and names its entry point (`shell_entry/2`); `ern_cli:shell/3` starts the shell (*The shell*).
- **`ern test`** is `run_tests/6`: the module's tests in one launch (`cases_launch/6`), each in a monitored process of its own, which `ern_rt:deadlock_victim/1` names to the reaper (§11.2); then each of its doc examples in a launch of its own (`run_examples/4`, `example_launch/3`), which initializes the modules the example uses, and whose end before the example returns is the example's line alone, the reporter knowing the entry process's fault by `ern_rt:entry_process/0`. `ern_examples:cases/4` compiles the examples before the run, each in a module of its own, a private declaration's and an abstract type's constructor's inside its module's source in a unit of its own, and checks each against the modules it names too, which `ern_build:compiled_dependencies/1` finds on the load path as a build finds those a source names, and which the run's load loads with those they use; `in_directory/3` makes an example's empty directory, the host's working directory while its launch runs; and `unload/1` takes their units out after the last.
- **`ern format`** is `ern_format:format/1`, printed by `ern_pretty` in 100 columns; `ern_format:markdown/1` lays out a CommonMark text's Ernest blocks (§11.6).
- **`ern doc`** renders a page with `ern_page:page/1` from the two chunks (§11.4). `doc_dir/3` writes a directory's pages that are `outdated/2`; `--man` renders through `libs/markdown`'s `roff` in a started runtime (`in_runtime/2`). `ern(1)` is `tools/manual.ern`'s, which `make manual` runs over §11.
- **`ern config`** writes Appendix C's file and an Ed25519 key pair (`ern_node:create/1`, §11.3).
- **`ern reload`** and **`ern stop`** signal the node that holds their directory's `ernest.pid`, through the helper's `node` mode (`ern_node:signaled/2`, `ern_node:stopped/1`, §8.7).

### The shell

The shell is an Ernest program over `Terminal`: `src/shell/shell.ern` and its modules under `src/shell/shell/`, compiled by `make` into `build/shell` against `libs/markdown` and `libs/ansi` in `build/libs`. [`src/shell/README.md`](../src/shell/README.md) guides a reader through the code, and [`design/shell.md`](design/shell.md) holds the design.

`ern_shell` is the front end the shell reaches through `foreign fn`. It holds the session and checks an input with `ern_typecheck:check/4`, the input a module of its own (§11.2).

- `:load` places each module after the modules it uses (`#placing{}`, `needed_placed/3`, `dependency_placed/3`, `in_dependency_order/1`). A module is compiled (`compile_unit/5`), taken from its current compiled form (`current_form/4`, `compiled_unit/5`, `install_one/2`), or taken as a unit the node holds of the same code.
- `:reload` brings each version beside the previous one and compiles again what `ern build` would (`stale_users/3`). A changed type moves to the previous version's namespace, `Counter$1` (`versioned/3`, `returned/3`), whose interface `#session.previous` holds and whose unit `#session.units` names.
- `:reload` compiles again each declaring input whose forms reference a changed hash (`reached_inputs/2`, `compiled_again/2`, `input_text/2`, `out_of_scope/3`). A version names its sites under its own namespace (`site_namespace/2`).
- A load evaluates each module's bindings in an evaluator (`evaluate/3`, `evaluators/0`). A refused load is undone by `withdraw/2`, and a module refused again makes no unit (`kept_or_fresh/5`).
- A session's declarations are named under `$Session` (`?SESSION_NAMESPACE`, `redeclared/2`). An input that declares or builds a function value is kept; any other is deleted once its answer is in (`release/1`, `collected/1`).
- `Shift-Tab` is `documentation/1` or `signature/1`, which prints through `ern_types:format_call/4`. `:doc` is `ern_page`'s `declaration/3`, `session_declaration/3` or `module_head/1`.

## Tests

`make test-full` runs every kind below; the targets, the light `make test` among them, are [`development.md`](development.md)'s.

### The code and the programs

- **Unit tests**: EUnit under `erl/*/test`, one function per behavior, each citing what it tests; `make sections` lists the report sections none cites.
- The emitter's tests run a program as the runner does with `ern_emitter_tests:run/3`, which `ern_supervisor_tests`, `ern_restart_tests`, `ern_reaper_tests`, `ern_system_module_tests` and `ern_terminating_tests` share.
- **Golden files**: `test/fixtures/golden` holds the Erlang emitted for `hello` and `services` of `test/fixtures/programs` (`golden_names/0`), compared as text. `test/fixtures/target` holds the two expectations the emitter did not write, for `hello` and `counter`. Both name a call into the standard library by its position there.
- **Programs**: `test/ern_integration_tests.erl` builds and runs the programs of `test/fixtures/programs`, and the examples `hello` and `typed_channels_nodes`, comparing their output with `test/fixtures/expected` as a multiset of lines. Programs that need input, a file or a client run under tests of their own in the same file.
- The same file tests the signals, the streams, `Os`, each library's `Test` values (`libs_test_`), and the programs under `docs/proposals/operations/programs/` (`operations_test_`). Its helpers serve `test/ern_manual_tests.erl`, which holds the manual pages to §11, and `test/ern_install_tests.erl`, which installs into a scratch prefix and from the release archive.
- `test/ern_measure_tests.erl` holds that `make bench`'s measuring machine reaches every function of the library.
- **The corpus**: `ast_coverage_test` holds that the examples, the programs, the standard library and the libraries use every AST record, and the checker's tests type-check every example and program.
- **Generated programs**: `test/ern_grammar_programs_tests.erl` derives programs from Appendix A, read by `test/ern_grammar.erl`. `test/ern_typed_programs_tests.erl` generates well-typed programs and runs each against an interpreter. `erl/runtime/test/ern_laws_tests.erl` holds the standard library to its laws on drawn cases ([`soundness.md`](soundness.md)).

### The documents

- **Documentation**: the CLI's tests hold `docs/module_doc_template.md` equal to `ern doc`'s page for `test/fixtures/programs/template.ern`. `erl/runtime/test/ern_doc_tests.erl` checks the documentation of the template, `src/stdlib/` and `src/libs/`.
- **The examples**: `ern test` is their one checker. `make test-library` runs it over `build/stdlib` and `build/libs`, and `ern_doc_tests` over a build of the template and over the prelude's page, whose examples it writes into a module's doc block, since no `.erc` holds them.
- **Style**: `test/ern_style_tests.erl` checks `docs/style.md`'s tested rules, `ern format`'s layout over every module and every Ernest block of the report and the guide, and the Emacs mode's word lists against the lexer and the parser.
- **Citations**: `test/ern_docs_tests.erl` (`make xref`) resolves every section citation, holds the contents lists equal to the headings, and checks the backticked paths of the documents that say where things are. It and the style tests read the repository through `test/ern_repository.erl`.
- **The guide and the report**: `test/ern_guide_tests.erl` compiles every `ernest` block, runs every program a console shows, checks every `ernest-rejected` block's error, and replays every shell session, in the guide, the report and the README. It checks `docs/diagnostics.md` the same way.

### Nodes, the shell and waits

- **Nodes**: `test/ern_nodes_tests.erl` runs real nodes on one machine, each an `ern run --config-dir` of its own, its streams read by a watcher registered under the node's directory. Its programs are under `test/fixtures/peers/`, beside `ern_peers_host.erl`, and `harness.ern` there holds the time each of their waits is given, the harness's `wait_ms/0`, which a test holds equal.
- **Deployment**: `test/ern_deployment_tests.erl` runs the deployment guide through the same harness, its consoles, its section 8, and each line its sections 7 and 4.3 quote (`catalog_test`).
- **The shell**: `test/ern_shell_tests.erl` runs sessions in line mode and under the pseudo-terminal, and `test/ern_terminal_tests.erl` drives §8.2's keys, the terminal's restoration and `snake`. Both reach the harness, `test/ern_pty.py`, through `test/ern_pty.erl`.
- **Waits**: no test sleeps to wait for something; a wait that is a time bounds an absence, with its reason beside it (CLAUDE.md, *No fixed sleep*). `erl/runtime/test/ern_waits.erl` holds the waits the tests share, each read from what the host reports.
- A module compiled from an application's `test/`, a wait's helper among them, ships with no installation and is outside a development build's code digest (`tools/install.sh`, `ern_carrier:is_test/1`).
- **The Emacs mode**: `make test-emacs` runs the tests under `editors/emacs/test/` ([`design/emacs_mode.md`](design/emacs_mode.md)).

### Outside `make test-full`

- `make load` runs [`memory.md`](memory.md)'s loads: `test/ern_load.erl` runs each program under `test/fixtures/load/`, and the shell under a session it writes.
- `make bench` is the measuring machine. `test/ern_bench.erl` sets `test/fixtures/bench/bench.ern`'s operations beside Erlang's, and `test/ern_measure.erl` every function of the library beside the host's.
- `test/ern_node_costs.erl` measures the costs between two nodes of `test/fixtures/peers/`, and `test/ern_code_costs.erl` the costs of code that crosses, through `test/fixtures/bench/ern_code_probe.erl`.
- `make service` runs `test/ern_service_tests.erl`, a program under the host's service manager.
