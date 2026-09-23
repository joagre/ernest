# Ernest Implementation Plan

The roadmap: what will be built, in what order, and what is built already. Why anything is
the way it is belongs in [`decisions.md`](decisions.md); what the language is belongs in
[`ernest_report.md`](../ernest_report.md); how the code is arranged belongs in
[`architecture.md`](architecture.md). This document points at them rather than repeating
them.

Read "Where we are" first. The milestones follow in order, then the standing gaps, then what
is done, then the tables worth keeping.

The toolchain is `ernc`, which compiles `.ern` to `.erc`, and `ern`, which runs a `.erc` and
adds a shell on request. Written in Erlang on OTP 29, one person. The language was called
Actorson until 12 September 2026.

---

## Where we are

**MVP 2.6, the shell, checkpoint 4.** Checkpoints 0 to 3 are done: the loop and the terminal
harness, bindings and the commands, the live region, and the line editor with history,
multi-line input and paste. What is left of the milestone is in "MVP 2.6" below: completion,
a guide chapter, the closing sweep, and a session of real use.

**The rhythm.** One item a turn, with its tests, its documents, its conformance section and
its commit; then a stop for review before the next. The user reads the plan and not the log,
so a decision they must see goes here.

---

## Milestones

| | What | State |
|---|---|---|
| MVP 1 | the chain: parser, types, BEAM | done 2026-09-18, tag `mvp1` |
| MVP 2 | the rest of the report on one node | done 2026-09-19 |
| MVP 2.5 | a complete standard library | done 2026-09-20 |
| **MVP 2.6** | **the shell** | **checkpoints 0–3 done; checkpoint 4 next** |
| MVP 2.65 | the language and the toolchain read back | after 2.6 |
| MVP 2.66 | introduce a supervisor behaviour? | after 2.6 |
| MVP 2.7 | the first libraries and the network stack | |
| MVP 2.8 | four more libraries | |
| MVP 2.9 | an Emacs major mode | |
| MVP 3.0 | peers | |
| MVP 3.1 | content addressing | |

---

## MVP 2.6 (the shell), about two weeks

The program that exercises everything at once, and the whole milestone: the libraries moved
to 2.7 on 2026-09-20 so that one large thing is measured rather than two. Designed in
[`shell_design.md`](shell_design.md), which owns the design; §11.2 owns what a user may rely
on. The source is a tree of its own, `shell/`, compiled by `make` into `build/shell/`, since
the shell is neither standard library nor library but the toolchain's own program.

**The checkpoints**, each a stop for review.

| | What | State |
|---|---|---|
| 0 | expressions only: the three processes, the foreign interface, an input checked, compiled, run, printed | done 2026-09-20 |
| 1 | bindings, `it`, timing, declarations at the prompt, the commands, fault reports, `:load`/`:reload`, the startup files | done 2026-09-20 |
| 2 | the terminal and the live region, `:output <path>` | done 2026-09-21 |
| 3 | the line editor: editing, history and its search, multi-line input, bracketed paste | done 2026-09-21 |
| 4 | completion and documentation | **next** |

**What is left.**

- **Checkpoint 4, completion and documentation.** Steps 1 to 3 are done, 2026-09-21:
  `Shell.Complete`, pure and tested, matching by prefix and by abbreviation segment by
  segment; `Tab` replacing the word before the cursor and indenting four spaces where there
  is none; a second `Tab` listing the candidates with their types above the region, forty at
  most; and the parser saying what may stand at the cursor, which filters the candidates by
  kind. What is left of the checkpoint: `Tab` completing a qualified name segment
  by segment, a second `Tab` listing candidates with their types, matching by prefix and by
  abbreviation; what completes by position, bindings and modules and constructors in an
  expression, types after `:`, a constructor's remaining fields, a command and then its
  argument; `Shift-Tab` for documentation, the type and first sentence and `since`, a second
  press for the `:doc` section, and inside a call the signature with the parameter at the
  cursor marked. Step 4 is half done, 2026-09-21: the editor reads `Escape [ Z` as one key,
  `Shift-Tab` shows a name's type and first sentence and the whole page when pressed again,
  and a command completes as a word of the shell's own, `:br` to `:browse`, with a second
  `Tab` listing them all. **Left of step 4:** the signature with the parameter at the cursor
  marked, which wants a parser tag for "inside a call's argument n" as the field position
  got one; a declaration's own `since`, which the page does not carry per declaration; and
  a terminal test for `Shift-Tab` and command completion — the editor's own tests cover the
  key, and the behaviour was checked by hand, but the pty test written for it raced its own
  output and was taken out rather than left failing.
- **Typing ahead while an input runs looks wrong.** A test that sent a second input before
  the first had finished never saw the second's result. Found 2026-09-21, not diagnosed, and
  recorded in the language note; it belongs with the session of real use below.
- **A guide chapter on the shell.** `ernest_guide.md` does not mention it. The report states
  the rules and the note holds the design, but the document that teaches says nothing about
  the tool a user lives in. Found 2026-09-21.
- **The closing sweep**, as the working rules require at the end of a plan step: the guide
  read against the report, then every other document against the report and the code.
- **A session of real use.** The user works in the shell and reports what it is like; what
  that finds is fixed before the milestone closes or recorded in the design note. Nothing so
  far has been driven by hand — every test goes through the pseudo-terminal harness, which
  tests what was thought of.

**Out of 2.6:** every library, which is 2.7 with the paper program that needs it; `Regex`,
`Crypto`, `Uri`, `Zlib`, which are 2.8; the library fetcher, 3.1; an HTTP server, never.
Field selection and the names of the toolchain's options moved to 2.65 on 2026-09-21.

**What the shell has changed so far**, one line each, the arguments in the log.

- **Before any of it**, 2026-09-20: `test/ern_pty.py`, a pseudo-terminal harness, since
  Erlang cannot open one; `make test` needs python3. It tests §8.2's rules and drives snake.
  Rewritten the same week to wait for what it expects on the screen rather than to send at
  fixed times, which had failed about one run in ten.
- **§9.3 and §8.2 gained what the shell needs**, 2026-09-20: the terminal's interrupt as a
  key for the terminal's holder, the terminal's size, whether input is a terminal, and the
  runtime's record of how every process ended as a door for the shell alone.
- **Incremental checking was the estimate's risk and is not**, 2026-09-20: the checker takes
  the session as a fourth argument and resolution rewrites a session name to the input that
  declared it, so nothing downstream knows of a session. Two small changes.
- **`Keys` became `Terminal`**, 2026-09-20, one module for the resource; `io_ansi:scan` was
  measured twice and refused, being a capability scanner.
- **The panes became a live region**, 2026-09-21: the transcript is written into the terminal
  and scrolled by it, and the shell paints only the bottom rows. `Key` folded into one flat
  `Event`; the pane routing went in the same commit.
- **The pure parts became modules of their own**, 2026-09-21: `Shell.Editor`, `Shell.History`
  and `Shell.Region`, each tested by `ern --test` as top-level `Test` values — the first use
  of §9.3's `Test` here. Each split was forced by a name collision, which is the namespace
  rule doing the pushing; the log's entries say so.
- **The rule for `foreign`**, 2026-09-21, now in CLAUDE.md: a door is admitted for what the
  host alone can do, and everything else is written in Ernest. Its first sweep found one
  door of twenty-three in breach, `startup/0`.
- **Report changes it forced**, all 2026-09-21 unless dated otherwise: §11.2's whole core,
  the live region, `:output`, the history file, multi-line input, and the paste; §9.3's
  `Event` and `Pasted`; §8.2's bracketed paste and the answered subscription; §4.2's
  exported-declaration rule and the sentence on reaching a child module from its parent; E.5
  `indexOf`, `lastIndexOf`, and what a character is.
- **Defects it found, none of them the shell's**: `ernc` crashing on an exported declaration
  naming a private type; a binding compiled inside an unmarked foreign call, which fired
  `Deadlock`; a `let` of function type emitted as a `fn`; a subscription answered before the
  mode was set; the terminal process counting its source after `stty`, which fired `Deadlock`
  under load; `process_of/1` answering a checking proxy's own pid; the key decoder reading
  `\e[2` as `Escape` and two characters; and initializers running in alphabetical order
  rather than §8.5's dependency order.

---

## MVP 2.65 (the language and the toolchain read back after the shell), about four days

The shell is the first program of size written in Ernest by the people who designed it, and
what it felt is in [`language_feedback.md`](language_feedback.md), which owns that list.
This item decides each entry rather than collecting it: the language questions first, field
selection at their head, then what belongs to Appendix E, then the names of the toolchain's
options, then what is recorded and left alone.

- **Each entry is judged on §0's five principles**, and a standard library entry on E.0's
  four rules, one by one and in writing. How many sites in the shell felt it is an argument,
  never the gate.
- **Every entry ends in one of three things:** a report change, made before any code; an
  entry in the log under "Later" stating the verdict and what would change it; or a line
  saying it was weighed and left alone. Nothing is left open, since the next program will
  feel the same things and a second collection is not a decision.
- **The two candidates the note puts forward** are field selection, `s.upper`, with three
  witnesses in the shell and Gleam's totality rule to copy — a field read with a dot when
  every constructor of the type has a field of that name and type — and, tentatively, some
  way to name a prelude constructor a module has shadowed. Against the first is principle 2,
  a pattern already reading a field; for it, that Ernest took `..` for update from the family
  whose readers expect `.` for read. The report changes first if it is taken: §3.5 for the
  rule, Appendix A for the production, §11.5 for what a selector on an absent field says.
- **The names of the options to `ernc` and `ern`.** Both tools grew their options one MVP at
  a time and the set has never been read whole. Under review: the three words for a
  directory, `--source-root`, `--out-dir`, `--config-dir`, `--load-path`, and whether the
  rule that tells them apart is worth stating; the options that are modes rather than
  modifiers, `--doc`, `--test`, `--emit`, `--shell`, `--create-config-dir`, and whether a
  mode is a subcommand; `--create-config-dir`, a whole job in an option's clothes that names
  the same directory as `--config-dir`; `--no-clean`, the only negative; and `--errors
  short`, a value option with one value. The names are in §11.1 to §11.4, so each is a report
  change and worth deciding once.

---

## MVP 2.66 (a supervisor, or the argument that none is needed), about three days

The claim has stood since 2026-09-13 and has never been tested: a supervisor is fifteen
lines of `spawn`, `monitor` and `receive`, so Ernest needs no behaviour for it. This item
tests it by writing one, and decides what it should be, if anything.

- **Not in the language.** §6.9 gives monitors and no links, and §0's fifth principle keeps the surface
  small; a behaviour would be a second way to structure processes beside the three
  primitives. Nothing here proposes a report change.
- **Not in the standard library either, by E.0 rule 3.** A supervisor is policy and almost
  nothing else: which strategy, how many restarts in what time, in what order children stop.
  Rule 3 refuses a function whose result depends on a choice the library makes for the
  program. If it is written at all it is a library under `libs/`, on Appendix D's pattern,
  where a program that disagrees writes its own.
- **The experiment first:** `examples/supervisor.ern`, a supervisor of three workers with
  restart on fault and a restart-intensity limit, written with nothing but `spawn`,
  `monitor` and `receive`, and read back against the claim. If it is fifteen lines and reads
  as a program a person would write, the answer is the guide's idiom section and no code. If
  it is sixty and every program would write the same sixty, that is the argument for
  `libs/supervisor`.
- **Two things it will run into, and they are the content of the discussion.**
  - **A restarted child has a new address, and §6.3 has no registry**, so nobody who held
    the old one can reach it. A supervisor that restarts children is therefore a name
    service for them, or its children are unreachable after the first fault. This is the
    same hole the node protocol note's open question 8 names, and it is queued for MVP
    2.65; the supervisor is the second witness for it.
  - **Stopping a child needs `kill` or a protocol message.** `kill` is asynchronous and
    gives the child no chance to finish (§6.9); a message means the child's mailbox type
    carries a stop case, which is the child's business and cannot be imposed by a library.
    OTP solves this with exit signals and a shutdown timeout, which Ernest refuses.
- **What no-links costs, and the idiom that answers it.** A supervisor that dies leaves its
  children running, where OTP's would take them with it. The answer within the language is
  the reverse monitor: each child monitors its supervisor and returns when it dies. Whether
  that belongs in the guide beside the supervisor idiom is part of this item.

---

## MVP 2.7 (the first libraries and the network stack), about two weeks

Appendix D has been written to once, for `Ets`, and a pattern tried once is a guess: four
libraries written to it confirm or correct it before anyone outside writes to one, and they
are the compiler's second real user. `libs/` and `build/libs/` are created here, the last
step of the 2026-09-20 rename. Being first-party changes nothing about the tier: a library is
not on the load path unless a program puts it there.

- **Report first**, for what a command-line program needs: `Sys.args` and `Sys.env` in §8.2
  and §9.7 as runtime-bound values, an exit status in §8.6, and `Time` in Appendix E over the
  clock's milliseconds. They came back here on 2026-09-20 when the shell's colour went later.
- **`libs/json`**, pure Ernest: a `Json` type, a parser over `String` returning `Either`, a
  printer; the first test of `<-`, `tryMap` and `tryFold` at size.
- **`libs/base64`**, a shim over `base64`: the smallest there is, so Appendix D's pattern is
  written a second time before the two large ones.
- **`libs/tls`**, a shim over `ssl` and `public_key` with their manual pages open: `listen`,
  `accept`, `connect` returning `Address(SockMsg)` with the encryption inside the socket
  process, so `Tcp.read`, `write` and `close` serve both. Certificate verification is the
  caller's to ask for.
- **`libs/http`**, Ernest over `Tcp` and `Tls`: request and response types, a client. No
  server; that is the webserver example's job.
- **The paper program:** `examples/fetch.ern`, a command-line tool that fetches JSON over
  HTTPS and prints a report, errors to stderr, with an exit status. A paper program travels
  with the stack it needs; MVP 2.5 taught that a program which only compiles proves little.
- **Each library** is an Ernest source root under `libs/<name>/` that a program adds with
  `--load-path`, with `stdlib/`'s test discipline, a README of its own, and no entry in
  Appendix E. Own repositories later, when there is a package story.
- **The report lists them** in a new informative appendix, one section per library with its
  signatures and contracts, and a mirror test holding each compiled interface equal to it, as
  `ern_prelude_tests` holds the prelude to Appendix E. Third-party libraries are not listed;
  Appendix D is what they follow.

---

## MVP 2.8 (four more libraries), about two weeks

`libs/regex`, a shim over `re`, a library and never syntax: `Regex.compile : (String) ->
Either(RegexError, Regex)` with `Regex` a foreign type, so a bad pattern is a value the
program handles, as Gleam's `gleam_regexp` does. `libs/crypto`, a shim over `crypto` for
hashes, HMAC and random bytes, the key and cipher surface waiting for a program. `libs/uri`,
pure Ernest or a shim over `uri_string`. `libs/zlib`, a shim over `zlib`. Each is written and
documented in one pass to [`module_doc_template.md`](module_doc_template.md), and its
executed doc examples are its first user, so no paper program is required (decided
2026-09-19). Each gets an appendix section beside 2.7's four.

---

## MVP 2.9 (an Emacs major mode), about three days

`.ern` files are edited in `fundamental-mode` today. [`emacs_mode.md`](emacs_mode.md) owns
the detail; this item is its place in the order. `editor/emacs/ernest-mode.el`, derived from
`prog-mode` and not from `cc-mode`, since Ernest is expression-structured and CC Mode's
engine assumes C's statements: a syntax table for `//`, `/* */`, `///` with a face of its
own, strings, raw strings that span lines, and a `syntax-propertize-function` for char
literals so an apostrophe cannot unbalance a buffer; font-lock from §2's lexical rules;
four-space indentation, `match` and `receive` arms led by `|`, and no alignment padding,
which the style guide forbids; `compilation-error-regexp-alist` for `file:line:col: message`;
`auto-mode-alist`. A `comint` mode over `ern --shell` and completion are out of it.

- **The reserved words and the operators restate Appendix A**, so the item carries a mirror
  test keeping the mode's lists equal to the lexer's. A restatement without one is a wart.
- **Elisp is a fourth language here**, and this is the only file of it: `docs/style.md` gains
  the rule it needs, lines of at most 100 characters and no tabs, and the README's layout
  gains `editor/`.
- **Tree-sitter waits for a second editor.** `ernest-ts-mode` over a grammar built from
  Appendix A would give structural highlighting and serve Neovim, Helix and Zed too; against
  it, the grammar is a second statement of Appendix A in a fourth language with no mirror
  test writable between EBNF and it, and it adds a C toolchain and a compiled object per
  platform. The plain mode costs heuristic indentation and font-lock a pathological line can
  confuse; that is the price until a second editor is asked for.

---

## MVP 3.0 (peers), about three weeks

Designed in [`node_protocol.md`](node_protocol.md), which owns the protocol: node identity
as the hash of the TLS key, incarnations, addresses, spawning, monitors, ordering,
connections and the wire encoding. It is marked tentative, and it is written against an
older spelling of the language; the report changes it implies are listed at the end of this
section and are decided before any of it is built.

Nodes that reach each other and the four operations of §8.7 between them, with code shipping
restricted to nodes running the same build: identical definitions have identical hashes,
which is §8.7 in its easiest case. A peer whose build differs is refused with an error naming
3.1. Split from 3.1 on 2026-09-20, since content addressing proper is the larger half and
peers are the useful one.

- `spawn(Peer(name), f)` and `remote(f)` over the peers in `ernest.conf`, authenticated with
  the configured keys: the connection is `ssl` with the peer's public key from `ernest.conf`
  as the only trust, read with `public_key`, inside `ern`, and a program never sees either
  module. `remote` picks among peers flagged `"remote-peer": true` by load, criterion chosen
  then.
- Peer loss as §10 says: every process on the lost peer dead with `Fault("peer lost")`,
  monitors delivered, pending `remote` calls `Left(PeerLost)`; a peer that reappears is a new
  instance.
- **What the protocol note asks of the report**, each to be decided before it is built:
  `Down` gains `Unreachable` and a cause for an address that never had a process, since a
  watcher must tell a lost connection from a death (§9.3, §6.9); §6.4 gains that what
  arrives is an unbroken prefix of what was sent and that a sender is told nothing of a
  drop; and the note's `spawn_at(node, f)`, `MonitorRef` with `demonitor`, and a name
  registry are surface the report does not have — `spawn(Peer(name), f)` is one primitive
  with a placement argument (§9.4), `monitor` is one message and no handle (§9.5), and
  §6.3 refuses a registry outright. The registry is the one of these that is a language
  question rather than a protocol question, and it belongs with MVP 2.65's list: without
  one, a service another node started cannot be reached, since only spawning or being sent
  an address gives you one. The note's open question 11, a way to stop an uncooperative
  process, is already answered: `kill` is the language's (§6.9), asynchronous, and a killed
  process's monitors see `Killed`; across nodes it needs a frame the note's table lacks.
- **An adapted address across a node** is open, and report first when it is taken. `via(f,
  addr)` has been the pair of the function and the address since 2026-09-20 (§6.5), so an
  `Address` that leaves a node may carry a function, which is the same question as a message
  that carries one. Whether the function travels or the adaptation stays behind is the
  decision.

---

## MVP 3.1 (content addressing), about four weeks

Designed in [`code_distribution.md`](code_distribution.md), which owns it: what is hashed,
names as a build product, the loader beside `code_server`, have/want before every message,
the trust model, and the atom-leak restart. Marked tentative, and two things in it meet the
code as it stands. Its section 11 asks MVP 1 for a named IR stage with locals numbered by
position: there is none, since `ern_emitter` goes from the typed AST to Erlang's abstract
format in one traversal, so the choice is to introduce an IR here or to canonicalise the
typed AST, which is the decision below either way. And its section 3.4 hashes every
declared type nominally, name included, where §8.7 says structurally identical definitions
share a hash and only an abstract type's hash carries its name — the note is right that the
wire should mean what the checker means, and §8.7 is already in two minds about it, so this
is a report change to make here.

§8.7's identity in full. The first decision is what "normalized definition" means, since two
nodes must agree exactly: the typed tree or the untyped one, whether local names are erased,
and what becomes of the effect variables, which are inferred and never written.
`ern_emitter:iface_hash/1` already hashes a canonical interface; whether it grows into the
definition hash or a second scheme stands beside it is part of that decision, and the cheaper
answer is the first.

- Every definition gets a hash of its typed AST; modules are named by hash; a registry per
  node `{Hash -> Module}`. A message with a function carries the hash, and a node that lacks
  it fetches the code from the sender. Erlang's module distribution is not used.
- Two nodes with different versions of one type: reject at send, each message carrying its
  type hash; fetch on receipt is the alternative, decided when peers exist and the two can be
  measured. The log has both shapes.
- The library fetcher, decided 2026-09-19: `ern fetch name url` fetches a library's source
  tree from a git URL into a directory on the load path, compiles it, and records the hashes
  of its definitions. No resolver, no semver, no lockfile beyond those hashes, and no
  registry; discovery by name is a tooling question for later.

---

## Not in any MVP

A canonical formatter, `ernc --format`, one style and no configuration, mechanical over the
grammar; it lands before a second person writes Ernest. `Slot(a)`, a one-shot credit parallel
to `Reply(a)`, is out on principles 2 and 5; the log holds its shape if the verdict is
revisited. String interpolation is declined for now on principles 2, 3 and 4. Erlang
scheduling hints wait for a program that needs them. No HTTP server, ever, and no database
connectors: those are libraries for others to write on Appendix D's pattern.

---

## Standing gaps

- **§3.11, §8.3 and §8.7 have no citing test**, which `make sections` lists. All three are
  MVP 3.0 and 3.1 material and unimplemented; anything else that appears there is a gap.
- **How the region measures a wide character.** A tab is settled — painted as the spaces to
  the next stop of eight — but a wide glyph is one column to the region and two to the
  terminal, and nothing in the runtime knows a glyph's width. `expand` in
  `shell/shell/region.ern` is the one function that has to learn it. The design note's only
  open item.
- **The guide owes the idioms** the log's "Later" lists, links and supervisors and parallel
  `remote`, and a chapter on the shell (MVP 2.6 above).
- **`e_bits` and `p_bits` are in no example**, so the AST coverage test excludes them
  (2026-09-19).
- **A label at the first use of the variable whose type a mismatch names** was planned for
  §3.4's placement work and not built (2026-09-18).

---

## Done

### MVP 1 — the chain (done 2026-09-18, tag `mvp1`)

Prove parser, types and BEAM with the report's language unchanged, accepting a subset: `Int`
but no `Float`, no ownership rule for abstract types, no foreign code, no `Tcp`, no
distribution. Exhaustiveness checking was in from the start, being the check that shaped
`receive` and `if`. What still binds:

- **A hand-written lexer and a direct precedence-climbing parser** over a token list, no yecc
  and no generic Pratt engine: the hand parser is the executable test of principle 4. Tokens
  are yecc-shaped, `{Category, Pos, Value}`, with `Pos` carrying the token's end and the
  previous token's end so the parser can close every node's span. Three places need one more
  token: the constructor-fields peek, `FnType` against `ParenType`, and `fn` before an
  identifier or `(`. No backtracking.
- **Hindley-Milner with an effect slot**, §3.9: the arrow is `Arrow(args, E, result)`, the
  slot holding `pure`, a mailbox type, or an effect variable; unification is component-wise;
  an effect variable that also occurs in a value position or belongs to a process primitive
  is *process-only* and does not unify with `pure`. A free effect variable generalizes, which
  is what lets `List.map` run a process callback. The only departures from the textbook are
  `pure` as a non-type in the slot and that flag.
- **The reply discipline**, §6.6: a reply-carrying value is consumed exactly once on every
  path from its binding, the obligation passing through patterns, blocks and constructors;
  compiled interfaces carry it. `Address.call`'s `mk` callback is the canonical case.
- **Local `fn`s generalize late**, once every later local `fn` they reference has been
  checked, so `fn a(x) = b(x); fn b(x) = x + 1` does not accept `a("s")`.
- **One Erlang module per Ernest module**, `ern@` and the path with `@` for `/`, functions
  keeping their local names and type members their prefix (`'Stack.push'/2`). The reasons for
  the name are in the log's *One Token for the Project*.
- **Three pre-passes inside the emitter's one traversal**: unique variable names, lambda
  lifting of local `fn`s with their free variables as leading parameters, and the `<-`
  desugaring of §5.5 from the type the checker left on the node.
- **Diagnostics**, 3.4 below and §11.5: one `#diag{span, message, labels, help}` from every
  stage and one renderer, `ern_diag`; `ern_typecheck:check/5` pushes an expected type into
  `if` branches, `match` and `receive` clauses and a block's last statement, so a mismatch is
  reported at the leaf, with the origin as the label. No colour until an editor renders
  through an LSP; no error codes.
- **Testing**: the MVP 1 programs are the `PROGRAMS` macro in `test/ern_integration_tests.erl`
  and the golden set; `test/golden/*.erl` holds the Erlang the emitter writes, rewritten by
  `make golden`; `test/target/*.erl` holds the two hand-written targets, the only tests that
  are not self-referential. Output is compared as a multiset of lines, since interleaving is
  scheduling-dependent.
- **The report was pared** on 2026-09-18, 13,084 words to under 8,000 in one pass, and read
  back on 2026-09-19: the paring had lost five rules and compressed 86 sentences past easy
  reading, all restored. The standing rule since: a change is made inside its heading, in the
  report's register, clear before short, and a section past 600 words is read for restating.

### MVP 2 — the rest of the report on one node (done 2026-09-19)

Each item was a rule MVP 1 refused or did not check; the README's table named the refusal it
lifted. In the order worked, with what the log's entries explain in full: `Float` and
operators on user types, resolved during inference from the operand type (§3.1, §4.8, §5.1);
`foreign fn` and `foreign type`, the check a descriptor term the compiler builds and
`ern_boundary` interprets, with a checking proxy standing in front of every Ernest address a
foreign function is given (§4.7, §8.4); bitstrings, with `ern_bits` checking each value
against its width (§5.11); pattern alternatives (§5.9); `Io.debug` printing by the argument's
type through `ern_show` (E.1); raw strings (§2.5); abstract-type ownership (§4.4); the reply
discipline through function values, narrower than planned — a lambda is reply-carrying as a
value, and a reply-carrying function *type* is not taken (§6.6); `Deadlock` as global
quiescence rather than a wait-for graph (§8.6); and nine points from the consistency pass of
2026-09-19.

### MVP 2.5 — a complete standard library (done 2026-09-20)

Twenty-one modules in Ernest, every system door open, four paper programs written and three
under test, documentation in the `.erc`, and the manual terminal check made. Appendix E is
the shape and E.0 the rules; **a shim exists only where E.0's first rule admits it**, which
is a standing rule and not a milestone. The steps, in the order done:

0. **The shape of a module's documentation**, 2026-09-19, first because every module after it
   is written to it: [`module_doc_template.md`](module_doc_template.md) is generated from
   `examples/template.ern` and two tests keep them equal, type-check its examples, and run
   every example ending in `// => v` against `Io.debug`'s rendering. §2.2 and §11.4 say what
   a doc block is and what `ernc --doc` emits.
1. **Report first**, 2026-09-19: E.19 `Erl`; §4.2's exception for the standard library's own
   source root; the `Test` and `TestResult` types in §9.3; and the layout, `stdlib/*.ern`
   with its Erlang halves in `erl/runtime/src/` and its ABI tests in `erl/runtime/test/`.
2. **The checker reads the standard library's compiled interfaces** as it reads any
   dependency's, 2026-09-19, which shrank `ern_prelude` to §9. `ern --test` runs every
   top-level `Test` in the modules it is given (§11.2).
3. **Appendix E rewritten module by module**, pure modules first, each done when its Erlang
   original is deleted with the ABI tests and `ern --test` green. `Map` and `Set` stay over
   Erlang's `maps`, which share structure on update. Read-backs of the first modules changed
   the language: based literals and digit separators (§2.5), no negative zero (§3.1), the
   not-reply-carrying mark not inferred on a container's element (§3.9), and the module of a
   built-in type declaring its own operators (§4.8).
4. **The system processes**, 2026-09-20: `Sys.stdin`, `Sys.fs`, `Sys.keys` and `Sys.tcp` as
   runtime processes bound by the launcher, each speaking its §9.3 type and used through its
   Appendix E module, never by `send` (E.0 rule 8); `Ets` under `stdlib/` as Appendix D has
   it. `Tcp` is processes first: every socket is a process, so `monitor`, `kill` and `via`
   accept it. **Measured** with `examples/echo.ern`: 2,000 round trips over loopback take
   160 ms through socket processes against 90 ms in raw Erlang, 35 µs a round trip, 1.8
   times raw — the verdict is to keep the processes; a foreign fast path stays available
   under E.0 rule 1 if a program ever shows it matters, and `read` would move socket
   ownership between processes, which principle 3 refuses. Writing the paper programs found
   three defects, one of them in the report (E.17 now says what an `Entry`'s path is). Two
   terminal defects went into §8.2: raw mode set with `stty` on an inheriting port, and an
   escape alone for fifty milliseconds being the key. `snake` stays compiled-only and was
   checked by hand, since no test can press a key.
5. **What "complete" means beyond that**: Erlang's standard library read module by module on
   2026-09-18; the table is under "Reference". A function enters Appendix E when E.0's rules
   admit it, report first; nothing waits for a program to ask.
6. **Documentation in the `.erc`**, 2026-09-20: `ernc` writes each module's doc blocks and
   each function's parameters as written into EEP 48's `Docs` chunk, so `code:get_doc/1`
   reads an Ernest module and `ernc --doc` on a compiled module reads the chunk. §11.1 and
   §11.4 say so. The shell's `:doc` and `Shift-Tab` depend on it.

**The naming of the toolchain**, a detour between steps 4 and 5, done 2026-09-20: every
Erlang module `ern_<thing>`, every compiled Ernest module `ern@<namespace>`, `lib/` became
`erl/`, the standard library's Erlang half joined the runtime, and two wrong names were fixed
(`ern_compiler` to `ern_emitter`, `ern_check` to `ern_boundary`). The rule is in the style
guide, the record in the log's *One Token for the Project*. What remains of it is `libs/` in MVP 2.7.

---

## Reference

### The emitter's two tables

Decided before the emitter was written and kept as its specification; the code is the truth
now, and these are what a change to it is read against. Values follow §8.4 throughout. Types
are erased: `type_decl`, `abstract_decl`, `foreign_type_decl`, `signature`, `field` and the
`t_*` records produce no code, the interface chunk carrying them.

| Record | Erlang |
|---|---|
| `constructor` | nullary: the quoted atom; positional: `{'C', V}`; named: `{'C', V1, ..., Vn}` in canonical field order |
| `fn_decl`, top level | a function clause; exported if `export`; a type member is `'Stack.push'` |
| `fn_decl`, in a block | lifted to a module function with its free variables as leading parameters; the name is bound to a closure over them |
| `let_decl` | `name/0`, reading a value the module's `'$init'/0` computed once in dependency order before `main` (§8.5) |
| `foreign_fn_decl` | a clause calling the named `M:F/A` |
| `param` | the pattern in the clause head |
| `e_lit` | integer, float, or char literal; string as a binary; bool as an atom |
| `e_var` | a local: the Erlang variable; a top-level fn as a value: `fun f/N`; a top-level let: `name()`; a prelude name: table below |
| `e_con` | as `constructor`; a single-positional constructor as a value: `fun(V) -> {'C', V} end` |
| `field_set` | its value at its canonical position |
| `e_tuple`, `e_list` | tuple, list |
| `e_bits`, `bit_seg` | bit syntax, each value checked by `ern_bits` |
| `e_block` | a sequence; `binding` with `=` as `Pat = Expr`; `binding` with `<-` as a `case` on `Left`/`Right` or `None`/`Some` with the rest of the block in the second clause (§5.5) |
| `e_call` | `F(Args)` for a local; `f(Args)` or `'ern@m':f(Args)` for a known function; a prelude name: table below |
| `e_neg` | `-E`; on `Float`, `0.0 - E`, so that no negative zero arises (§3.1) |
| `e_binop` | `Int`: `+ - * div rem` (`/` is `div`, `%` is `rem`; a zero divisor's `badarith` becomes `Fault("division by zero")`); `<>`: binary append for `String` and `Bytes`, `++` for `List`; `==`, `!=`: `=:=`, `=/=`; `<`, `<=`, `>`, `>=` on `Int`, `Float`, `Char`, `String`: the native operators, since binaries compare by code point; `&&`, `\|\|`: `andalso`, `orelse`; `::`: `[H \| T]` |
| `e_lambda` | `fun(Pats) -> Body end` |
| `e_if` | `case C of true -> T; false -> E end` |
| `e_match`, `clause` | `case`; a clause whose guard is not an Erlang guard expression falls through by a continuation: `Rest = fun() -> <remaining clauses> end`, so no code is duplicated |
| `e_receive`, `after_clause` | `receive ... after T -> B end`; a receive guard is §5.9's guard expression and is emitted as an Erlang guard |
| `p_wild`, `p_var`, `p_lit` | `_`, a variable, a literal (a string as a binary) |
| `p_con`, `field_pat` | as `constructor`, an omitted named field as `_` |
| `p_tuple`, `p_list`, `p_cons` | tuple, list, `[H \| T]` |
| `p_as` | `Var = Pat` |
| `p_bits` | bit syntax |

**Prelude name to Erlang** (§9.4 to §9.7, Appendix E). Called, or taken as a value with
`fun M:F/A`.

| Name | Erlang |
|---|---|
| `self` | `ern_rt:self/0` |
| `send`, `answer`, `via`, `monitor`, `kill` | `ern_rt:send/2`, `answer/2`, `via/2`, `monitor/2`, `kill/1` |
| `spawn` | `ern_rt:spawn/3`, the third argument the spawn site for `Down` (§6.9) |
| `Address.call`, `Address.callForever` | `ern_rt:call/3`, `call_forever/2` |
| `remote`, `parallelRemote` | MVP 3; until then `ern_rt:remote/1` answers `Left(NoRemotePeer)` |
| `Int.+` and the other `userop`s on `Int`, `Int.negate` | the inline operators above |
| `Float.*` | inline, the operands bound first and the operation's own `badarith` caught and raised as the §7.4 fault |
| `String.<>`, `List.<>`, `Bytes.<>` | inline as above |
| `Int.div`, `Int.mod`, `*.compare`, `Int.toString`, ... | `'ern@int':'div'/2` and so on: the namespace's module |
| `todo` | `ern_rt:fault(<<"todo: ...">>)` |
| `Sys.stdout`, `Sys.clock`, `Sys.stdin`, `Sys.terminal`, `Sys.fs`, `Sys.tcp` | `ern_rt:sys(stdout)` and so on; `Io`, `Terminal`, `Fs`, `Tcp` are the namespaces' modules |
| `Clock.*`, `Path.*`, `Random.*`, `Io.*`, `List.*`, ... | `'ern@clock':alarm/2`, `'ern@io':println/1`: the namespace's module |

### Erlang's standard library, read module by module (2026-09-18)

Every user-facing OTP module is a row; what is not a row is OTP's own machinery, which
Ernest's concepts or toolchain replace.

| Erlang | Ernest | In Appendix E | Waiting, and when | Out, and why |
|---|---|---|---|---|
| `erlang` BIFs | the language; `Int`, `Float`, `String`, `Char` | `spawn`, `self`, `send`, `monitor` as §9.4 and §9.5; `abs`, `min`, `max`, rounding, `toString`, `toFloat`, the bit operations | an exit status for §8.6, `Sys.args`, `Sys.env`, MVP 2.7 | `register`, `whereis`: §6.5 has no registry. `link`, `exit`, `throw`, `catch`: §7 and §6.9. `term_to_binary`: MVP 3's transport. `phash2`, `md5`: a hashing library. `make_ref`: identity is a `Reply` or an address. `iolist_to_binary`: `String.fromList`, `<>`. `memory`, `system_info`: the runtime's |
| `lists` | `List` | E.2, thirty-one functions and `<>` | | `first`, `rest`, `flatten`, `count`, `map2`, `sum`, `max`, `min`: one pipe each, rule 4. `scan`, `mapFold`, `window`, `chunk`: a `foldLeft` with an accumulator, and each hides a choice about the ends. `permutations`, `transpose`, `combinations`: specialities. `key*`: `Map` |
| `maps`, `dict`, `orddict`, `gb_trees`, `proplists` | `Map` | E.3 | | the four alternatives: history |
| `sets`, `ordsets`, `gb_sets` | `Set` | E.4 | | `symmetric_difference`, `is_disjoint`: compositions |
| `string`, `unicode` | `String`, `Char` | E.5, E.6 | | the list-based half of `string` |
| `io`, `io_lib` | `Io` | E.1: `print`, `println`, `printError`, `printlnError`, `debug`, `readLine` | | `format`: no format strings, `<>` and `toString` are the one way |
| `file`, `filelib` | `Fs` | E.17, nine functions | `watch`, and the working directory with absolute paths, MVP 2.7 | `wildcard`: a glob library. `fold_files`: five lines over `List` |
| `filename` | `Path` | E.14, eight functions | | `absname`, `expand`: `Fs`'s, they read the working directory. `nativename`: a `Path` is in the runtime's syntax |
| `timer` | `Clock` | `now`, `alarm`, `alarmAt` | `Clock.monotonic` | `send_interval`, `cancel`: E.15's positions. `sleep`: `receive { after ms -> Unit }`. `seconds`, `minutes`: arithmetic |
| `rand` | `Random` | E.13: `seed`, `next`, `nextFloat` | | |
| `math` | `Float` | the operators, `abs`, `min`, `max`, `round`, `floor`, `ceil`, `truncate`, `toString`, `sqrt`, `pow`, `exp`, `log`, the trigonometry | | `looselyEquals`: the tolerance is the program's. `toPrecision`: a format, and §9.6 has no format strings |
| `gen_tcp`, `inet`, `socket`, `ssl` | `Tcp` | E.18 | `Udp` as its own module, a later MVP | socket options: tuning is a library's. TLS: `libs/tls` in MVP 2.7, returning the same `Address(SockMsg)` |
| `ets` | `Ets` | E.21 and Appendix D | | match specifications, `qlc`: `Ets` is a key-value table |
| `os` | `Sys` | | `Sys.env`, `Sys.args`, MVP 2.7 | `cmd`: a door to the system a program opens itself, MVP 3 at the earliest |
| `calendar` | `Time` | | a `Time` type and its parts, MVP 2.7 | formatting: a format is the program's, rule 3 |
| `binary` | `Bytes` | E.20, and `<>` | | `split`, `match`, `replace`, `encode_unsigned`: `<<...>>` and the `Int` operations |
| `array`, `queue` | | | | `List` and `Map` give both, rule 4; a persistent array is a library |
| `eunit` | `Test` | §9.3's `Test` and `TestResult`, run by `ern --test` (§11.2) | | |
| `base64`, `json`, `uri_string`, `re`, `crypto`, `zlib`, `dets`, `digraph`, `sofs`, `erl_tar`, `zip`, `disk_log`; the applications `ssl`, `inets`, `xmerl`, `public_key`, `asn1`, `mnesia`, `snmp` | libraries | | | each a namespace of its own on Appendix D's pattern, never stdlib |
| `observer`, `dbg`, `cover`, `debugger`, `dialyzer`, `edoc`, `common_test`, `syntax_tools`, `parsetools`, `argparse`, `escript` | | | | tooling: `ernc --doc`, Ernest's own types, the compiler, `ern`; an argument parser is a library |
| `gen_*`, `supervisor`, `proc_lib`, `sys`, `logger`, `application`, `code`, `rpc`, `erpc`, `global`, `pg`, `net_kernel`, `persistent_term`, `atomics`, `counters`, `init`, `heart`, `os_mon`, `wx`, `erl_*`, the shell | | | | a function with a mailbox type, fifteen lines of `spawn` and `monitor`, `send` to a sink, MVP 3's distribution, the runtime's internals, `ernc` and `ern` |

Gleam's `gleam_stdlib` v1.0.5, Elixir's core and Haskell's `base` were read the same way, and
what they have that this table does not take is a position, not a gap: `gleam/order`,
`gleam/pair` and `gleam/function` (patterns and compositions), `string_tree` (a builder
BEAM's binary append makes unnecessary), `gleam/uri` (a library), `dynamic/decode` (`Foreign`
and a JSON library), `string.inspect` (no universal printer), `bool.guard` (`<-`); Elixir's
`Stream` (§5.1 is strict, a lazy source is a process) and `Keyword` lists (`Map`); Haskell's
type classes (`toString` per type, `==` structural, `compare` per type).

### Tools, and what was decided before the start

Erlang, OTP 29 (raised from 27 on 2026-09-20), Makefiles, no rebar3, no OTP behaviours; EUnit
per application under `erl/*/test`, integration tests under `test/`; the toolchain shipped as
the escript sources in `bin/`, which put `erl/*/ebin` on the code path with no escriptize
step. Also decided before the start and unchanged: the `erl/` layout, one Erlang application
per stage; the error format of §11.5; one Erlang module per Ernest module.

### The MVP 1 time budget

| Phase | Parts | Days |
|---|---|---|
| 1 | parser, type inference, abstract types, standard types | 24.5 |
| 2 | compiler, processes, standard library, code generation | 9 |
| 3 | integration, tests, documentation, error placement, paring | 11 |
| **Total** | | **44.5, about nine working weeks** |

The actual: MVP 1 done 2026-09-18, MVP 2 the day after, MVP 2.5 the day after that.
