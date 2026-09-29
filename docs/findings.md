# Findings of the first review

Every finding of the twelve readers of 2026-09-28, one line each, by area, with its decision: **2.95**, fixed in MVP 2.95; **cheap**, fixed in MVP 2.98, a batch a document; **2.98**, planned in MVP 2.98; **done**; or **dropped**, with the reason. The readers: the report's principles (P), the cold reader (K), the register (G), the guide (U), the newcomer (N), the documents (D), the code (C), the Ernest code (E), the tools (T), the diagnostics (X), security (S), the shell's README (H). This file goes when every line is done or in the plan.

## MVP 2.95

- done — the directory build's sweep deletes `.erc` files and directories no build of its own wrote, a library's module it had just compiled against, the user's empty directories and `src/.git` (§11.1) (T1): fixed 2026-09-28, with the stale `.erc` refused when read and the link cycle the fix found; the log's *The Sweep Removes What a Build Wrote*
- done — `ern shell` runs `./.ernest/startup` from the working directory: a cloned tree runs host commands; from `$HOME` each line runs twice (§11.2) (S1, E10a): fixed 2026-09-28, the node's `startup` run only where `--config-dir` names it; the log's *A Directory Runs Nothing of Its Own*
- done — the working directory is on the host's code path ahead of the load path: a `.beam` there wins over the program's for a `foreign fn` (§11.2) (S2): fixed 2026-09-28, the directory taken off the host's code path where the load path is set
- done — `Fs.read`/`write`/`append` of a FIFO blocks every file operation of the node, for good (E.17) (S3): fixed 2026-09-28, the work around the host's file server and the four functions on regular files only; the log's *`Fs` Reads Regular Files*
- done — `Tcp.listen`/`connect` hang for ever on a bad port or host, and deadlock detection is then off (E.18) (S4, C1): fixed 2026-09-28, every request answered; the log's *`Tcp.listen` Names Its Interface*
- done — `Tcp.listen` binds every interface, with no way to bind loopback (E.18) (S5): fixed 2026-09-28, `Tcp.listen(host, port)`; the log's *`Tcp.listen` Names Its Interface*
- done — a socket's write blocks its reads and their time limits (E.18) (C3): fixed 2026-09-28, the writes in a process of the socket's own; the log's *`Tcp.listen` Names Its Interface*
- done — `Fs.list` fails for a whole directory over one dangling link; `Fs` follows links and cannot see one (E.17) (S6, E4): the failure fixed 2026-09-28, a link to nothing described as the link; that `Fs` cannot see a link is language feedback 65
- done — the shell's history is readable by others (E.17 lacks modes; §11.2) (S8): fixed 2026-09-28 with `Fs.makePrivate`, `$HOME/.ernest` its owner's alone before the history is read or written; the log's *`Fs.makePrivate`*
- done — `ern config`: a race leaks the private key through a descriptor opened on the temporary file; the directory may be an attacker's (§11.3) (S9): fixed 2026-09-28, the directory made at once and its owner's before a file is written; the log's *`ern config` Makes Its Directory Its Owner's*
- done — control characters of a fault cause, a doc block or a printed value reach the terminal and forge log lines (§2.1, §11.2) (S10): fixed 2026-09-28, refused in source, escaped in the toolchain's fault lines and in `Io.show`; the log's *No Control Character Reaches the Terminal Unasked*
- done — `end_program` misses a spawn the reaper handles after `live_rows()`: five runs left 176 processes (§8.6) (C2): fixed 2026-09-28, the reaper ends the program, and spawns nothing after
- done — `:reload` initializes changed modules in name order, not dependency order (§8.5, §11.2) (C4): fixed 2026-09-28, the modules initialized in §8.5's order
- done — a failed `:load` or `:reload` leaves its processes and unpurged code (§11.2) (C5): fixed 2026-09-28, the module withdrawn with the processes that run it
- done — a foreign function value inside a recursive type faults at its call with `badkey` (§8.4) (C6): fixed 2026-09-28, the wrapper given its result's descriptor closed over the recursive types around it
- done — a closed pipe crashes every job but `ern run`, leaving `erl_crash.dump` (§11) (T5): fixed 2026-09-28, every job's text through ports of its own, which end it with 141
- done — status 70 on an empty directory, a name that is not UTF-8, a corrupt `.erc` to `ern doc`, and 1100 tests in a module (§11) (T6): fixed 2026-09-28, each refused with status 1 or built; the log's *A Job Refuses What It Cannot Do*
- done — `write_whole` on a read-only file exits 70 and leaves a temporary file that blocks later runs (§11) (C12): fixed 2026-09-28, a file its owner may not write refused, nothing left beside it
- done — `Supervisor`'s restart limit: a child restarts itself before the supervisor counts it, about 200 times under a limit of 2; `within = 0` still gives up (E.22, §6.9) (E2, P15, K10): fixed 2026-09-28, the fault counted before the child runs again, and a time of 0 no limit; the log's *A Supervisor Counts a Fault Before the Child Runs Again*
- done — `emacs_mode.md` says Emacs 29 or later, and only Emacs 31.1 runs the mode's tests here: say what is tested, or run them on 29 (the documents' rewrite): 2026-09-28, the note says what is tested and what is expected
- done — `String`'s searches match inside a grapheme: `split` and `replace` lose text (E.5) (E1): fixed 2026-09-28, a match only between the string's grapheme boundaries; `lines` ends a line at CR LF; the log's *A Search Begins Where a Grapheme Does*
- done — `ern format` rewrites a `.txt` and paths `ern build` refuses (T11): fixed 2026-09-28, a file named alone a module when its name is, those under a directory found as the build finds them (§11.6)
- done — a command-line word that is not UTF-8 crashes every job (C13): fixed 2026-09-28, refused before the job begins and named as §11.1 names a file (§11)
- done — the shell's `.` completion crashes on a field of two types (C15): fixed 2026-09-28, the checker's question asked at a position it never shows, as its other questions are
- done — `ern format`: a raw string loses spaces in a doc example; trailing spaces of a doc line dropped; a `type` with a trailing comment; a blank line after a comment; a fence that does not parse re-indented (C11, C16, C24..C26): fixed 2026-09-28, a text's own spaces kept, a blank line after a comment kept, comments under a declaration kept beside it, an unparsed fence left as written (§11.6); C24 as a comment under a type moved away from it, the shape the line's words allow
- done — `ern format` stops with an internal error on a `///` after code (C17): fixed 2026-09-28, such a `///` an error (§2.2), which the formatter reports as it reports any; the log's *A `///` After Code Is an Error*
- done — a faulting `mk` of a call under `restarting` leaves the row, monitor and alias (C7): fixed 2026-09-28, a call settled however it ends, a callee's fault and the timed wait's count among them (§6.6, §6.9)
- done — `ern_os` crashes on a closed port for a queued read or write (C9): fixed 2026-09-28, a frame for a port the helper's end has closed dropped, the exit status it sent first ending the run (E.23)
- done — `stty sane` loses the user's settings (C20): fixed 2026-09-28, the settings kept with `stty -g` before the raw mode and given back at the end (§8.6)
- done — a lost paste end swallows every later key (C31): fixed 2026-09-28, a paste whose end does not come ended when no more of it arrives, and a late end nothing (§8.2)
- done — the shell's live region keeps an unfinished line whole: quadratic, never reclaimed (E3): fixed 2026-09-28, each row it fills at the window's width goes to the tail, the region holding one row of it at most; the log's *An Unfinished Line Leaves the Region a Row at a Time*
- done — filesync trusts a peer's path (S7): fixed 2026-09-28, a path stored only where it names a file in the directory, any other refused with `Denied` and shown as a value

## The report

- 2.98 — a `foreign fn`'s type variables escape §6.6 and §3.10: `Foreign.from(r)` drops a Reply, `Foreign.from` compares functions and addresses; a foreign type's arguments are never reply-carrying (P1, P3, K1)
- 2.98 — `Io.show` and `Io.debug` depend on the static type at the call: `fn s(x) = Io.show(x)` prints a Char as its Int (P2, K4, E-C4)
- done — where `via`'s function runs: §6.5 in the sender, §6.9 by the delivery; its fault is the target's (P11, K2): decided 2026-09-29, in the sender at the `send`, and a wrap by the runtime as it delivers (§6.5, §6.9)
- 2.98 — §4.2's lookup names a type-member step the compiler does not implement, and which would shadow a member by a module function (P5)
- 2.98 — `Optional` and `Either` refuse reply-carrying elements while user sum types allow them; the rule and §3.9's exemption exist for each other (P6); met again 2026-09-28, when `Supervisor`'s watcher had to hold its children's replies in a list type of its own, `Held`, since `List` holds none
- 2.98 — a `receive` guard is a second, smaller expression language: no top-level binding, no call, no ordering on a user type (P7)
- 2.98 — a type variable named only in a lambda's annotation is the lambda's and not rigid, so one annotation text has two meanings (P8)
- 2.98 — a block `let` of a lambda is monomorphic while a block `fn` and a top-level `let` are polymorphic (P9)
- 2.98 — the supervisor's restart on request is a language mechanism with no prelude entry; every `receive` of a child is an unwritten exit point (P10)
- 2.98 — claiming the terminal twice faults the entry process rather than the caller (P12)
- 2.98 — `Tcp.write` and `Os.write` fail silently (P13)
- done — E.0 shape rule 8 lists waits that take no milliseconds and omits `Io.print`, `println`, `printError`, `printlnError`, `write`, `Tcp.write`, `Os.read`, `Os.write` (P14, K3, U2, E-B12): fixed 2026-09-29, rule 8 names the three kinds that take no milliseconds
- 2.98 — bitstring sizes cannot name a top-level constant or a variable bound to their left (P16)
- 2.98 — `Int.div` and `Int.mod` are prelude variants of `/` and `%`, and `mod` is a remainder (P17, K-B6)
- 2.98 — `Address.callForever` beside `Address.call` is a second way (P18)
- 2.98 — every prelude type takes a module namespace, `Test` and `Path` among them (P19)
- 2.98 — an unresolved block variable is an error though nothing depends on it (P20)
- 2.98 — `C` and `C()` both match any value of a named constructor; `Some()` and `None()` are grammatical (P21, K19)
- 2.98 — `unit(N)` is a second way to scale a size (P22)
- 2.98 — `fn Int.+(a, b) = a + b` "is not a recursive call"; `negate` and `compare` are not covered (P23, K27, E-B11)
- 2.98 — §3.9 misses field selection among the places inference asks for an annotation (K5)
- 2.98 — what `T` annotates in `let p : T <- e` (K6)
- 2.98 — a first segment's lookup where a module declares a prelude type's name; `Prelude.T.member` (K7)
- 2.98 — §4.8's `fn Float.+` against §4.2's export rule (K8)
- 2.98 — "faults the binding `Os.workingDirectory`" against §8.5 (K9)
- done — E.0 rule 4 against `Optional.isNone` and `Either.isRight` (K11): fixed 2026-09-29, rule 4 keeps the two negations as a pair and says why principle 2 allows it
- done — shape rule 2's `contains` "one grapheme long or longer" against E.5's empty substring (K12): fixed 2026-09-29, rule 2's `contains` on text finds a substring of any length, the empty one included
- done — E.6 and E.8 name no primitives, as E.0 rule 1 asks (K13): fixed 2026-09-29, each names its primitives
- done — §3.11 leaves out `spawnMonitored` (K14): fixed 2026-09-29
- done — Appendix D and G.1's `Ets.new` against shape rule 2's `empty` (K15): fixed 2026-09-29, shape rule 2: `empty` is a value, and what belongs to a process and ends is made by `new`
- done — G.2's `parse` reads images that `Inline` cannot hold (K16): fixed 2026-09-29, G.2 says an image is read as a `Link`
- done — §7.4's first list: `Int.toFloat` is E.8's, and a partial operation that faults breaks shape rule 4 (K17): fixed 2026-09-29, §7.4 speaks of every partial operation, and shape rule 4 names `Int.toFloat` as its exception; whether `Float.exp` and `pow` fault is K25's
- 2.98 — §5.11 leaves conflicting, duplicate and size-less specifiers, and negative literals, open (K18, K-B7: `<<-1>>` is a fault the compiler could see)
- 2.98 — §8.5's order between dependent modules whose bindings do not depend on each other (K20)
- 2.98 — §8.4's ABI for `Map` and `Set` (K21)
- 2.98 — §11.6 defers the layout to `docs/style.md` (K22)
- done — §11.5 does not say how columns count (K23): fixed 2026-09-29, lines and columns from 1, a column a code point
- 2.98 — `String.padStart` with a Char that does not start a grapheme (K24, E14)
- 2.98 — `Float.exp` and `pow` out of range: fault or `None` (K25)
- done — §6.5's remote adapted address has no cause in §7.4 (K26): fixed 2026-09-29, `Fault("function cannot cross nodes")`, as a function's
- 2.98 — smaller silences: `true` and `false` covering `Bool`; pipe right-hand forms; one type of a selector over a parameterized type; tail position of `&&`, `||`, a pipe; a `spawnMonitored` site; `abstract type` at the prompt; `Os.exit(300)` in the shell (K28)
- done — wrong references: §6.6's "(§7.2)"; glossary's arity §4.5, node §8.3; missing glossary terms (K29, P-B11): fixed 2026-09-29, §7.4 and §3.4 cited, *node* and *peer* defined in §8.3, and eleven terms added
- done — names used before they are defined, and `Distance`, `Vec`, `Player` never declared (K30): fixed 2026-09-29, `node` pointed to §8.3 at its first use, and the three types declared where they are used; the other names the reader listed cite their section already
- done — clarity: §6.6's "may appear nowhere else", §6.3's operand sentence, §7.4's shell clause, E.2's `get`, §5.11's `<<-1>>`, App. B's prose, Appendix E's missing `a=`/`a!`, §8.4's `fn` placeholder, §8.7's list of ways to an address, §5.3's `{`, §6.10's statement, §7.3's example (K-B1..B14): fixed 2026-09-29; B6 is P17's, B7 is K18's, and B11's sentence had gone
- done — clarity: §2.1 whitespace against §2.2's doc blocks, §2.6's `!`, §5.5's irrefutable `<-` pattern, §6.6's second answer, `a=`/`a!` not writable, one signature two behaviours (P-B1..B10): fixed 2026-09-29; B2 with K-B3, and B7's sentence had gone
- done — §11.2's `--config-dir` explained last; the `Os.arguments` rule in the `ern test` paragraph (G29, G32): fixed 2026-09-29, `--config-dir` in the first paragraph and its default in §11.3; the rule with the shell
- done — rationale left in sections under 600 words: §4.4, §5.9, §6.5, §6.9, §11.5, E.16, E.21, E.22 (G, outside the brief): fixed 2026-09-29, the clauses cut, or stated as rules where they were rules
- 2.98 — `Io.read` from another process under the shell is unstated (G)
- 2.98 — rules that buy little, to weigh: `true`/`false` reserved, prefix `!`, `abstract` with `export` only, the 255-character limit, `Path` in the prelude (P-C)
- done — §11.2 is silent on the defaults: the depth 10 and the length 100 a value prints to, the live region's five rows, the start's greeting, and that `:output path` appends (shell_design.md's rewrite): fixed 2026-09-29
- done — §11.2 says a session whose input is not a terminal keeps no history; the code keeps none whenever input or output is not one (shell_design.md's rewrite): fixed 2026-09-29, *line mode* named and the rule said of it
- done — §11.2's "does not set `NO_COLOR`": the code reads `NO_COLOR=""` as unset, as no-color.org does, which the report does not say (shell_design.md's rewrite): fixed 2026-09-29, "unset or empty"
- done — §11.2's "the Emacs keys of GNU Readline" names no subset; the keys bound are `editor.ern`'s `plain`, `character` and `meta` (shell_design.md's rewrite): fixed 2026-09-29, the keys listed, and every other control key doing nothing

## The guide and the README

- done — §7.1: `Prelude.Close` names nothing; use `Local` and `Prelude.Local` (U1): fixed 2026-09-29
- done — §9.2: a signal's status 143, stale since `ern run` ends by the signal (U3): fixed 2026-09-29, `ern run` ends by the signal, which a shell reports as 128 plus its number
- done — §8.5: JSON, TLS, regular expressions and HTTP named as libraries that do not exist (U4): fixed 2026-09-29, a format, a protocol and a pattern language a library's by E.0 rule 3, and Appendix G for the libraries there are
- done — §2.9: `Os` missing from the system modules (U5): fixed 2026-09-29
- done — taught two ways: a dropped spawn's `with Never`; `main`'s signature; a type's operations as members or module functions (U6, U7, U8): U6 and U7 fixed 2026-09-29, a dropped address's lambda without `with Never` and each `main` with it; U8, when an operation is a member and when a module function, moved to MVP 2.99b, where the contract's decision settles how a type's operations are declared
- done — §4.4 omits `callee was restarted`; §9.5's stamp where standard error is a pipe; §14's `monitor` in repl; §8's configuration read; §8.2's code shipped; §1.1's `Io.debug`; §2.1's raw string (U9..U17, N8): fixed 2026-09-29; the README's line had been fixed with N9
- done — the guide's §8.2 on an adapted address that crosses to a peer, which step 5's answer decides (U9..U17, N8): 2026-09-29, the answer keeps §8.2 as it stands, and §5.5 points at it
- done — citations: shape rule 6, §6.6's cause, §4.5 for order, Appendix G.1 (U18): fixed 2026-09-29
- done — ownership: §14's test lists, the peer status, §6.5's layout, §10's protocol, §12's lambda answer (U19..U23): fixed 2026-09-29, each pointed at its owner; the lambda's answer argued in the log's *A Lambda Is Written `fn(x) = e`*
- done — clarity: §5.5's `Done`, §7.1's `main.erc`, §9.3 against §1.2, §1.2's Tab, §4.4's pacing, §8's comma splice (U24..U29): fixed 2026-09-29; U24 had been, and U29's sentence went with U20
- 2.98 — `Tcp` is never taught, though §9.5 shows a chat server's unit (N1)
- done — §5.5 leads one to expect sockets in the mailbox; `Tcp.read` pulls; one socket in two processes (N2): fixed 2026-09-29, the guide's §5.5 saying what does not deliver and how a reader process delivers it
- done — §8.6 recommends `Bytes.get` for scanning; a pattern is 120 times faster; no line splitter (N3): fixed 2026-09-29, §8.6 scans with a pattern and shows a line splitter; `Bytes` has no `split` by E.0 rule 2, and splitting stays in the program
- 2.98 — §4.4 does not cover a broadcast to a consumer that stalls (N4)
- done — no way to wait without a limit is said; `accept` and `read` repeat on `Timeout` (N6): fixed 2026-09-29, §2.9
- done — how to show an `Io.Error` to a user (N7): fixed 2026-09-29, §2.9: a `match` in the program's own words, as the shell's `trouble` does
- done — README: an example, compiled by `readme_examples_test_`; the unbuilt bullet cut, in the guide's list as well; a clone line; "§14 says what each shows" says the larger ones; Gleam and Unison stay, since the sentence that names them says what each gives (N9)
- done — `ern format` re-joins a split type; `Clock.now` untaught; `ern shell prog.erc` and `Os.arguments` (N10): `Clock.now` and `Os.arguments` fixed 2026-09-29; a type that breaks now holds one alternative a line, decided with the user 2026-09-29 (`docs/style.md`; the log's *A Type That Breaks Holds One Alternative a Line*)
- 2.98 — the language: sockets pull-only, mandatory timeouts, slow standard library calls, no bounded mailbox (N-L1..L6)

## Diagnostics (§11.5)

- done — `'ab'` reported as an unterminated char literal (X6): fixed 2026-09-29, a literal closed later on its line named as one of more than one code point
- done — a `let` and a `<-` pattern mismatch print expected and found reversed (X4): fixed 2026-09-29, the value's type expected, and the `<-` error at its pattern with the value labelled
- 2.98 — a rejected call site does not name the parameter and its restriction (`==` through a variable, a reply to `drop`) (X1, X2)
- 2.98 — a recursive use at another type is reported over the declaration, reversed, unlabelled (X3)
- 2.98 — positions and labels: `compare`'s shape, a field of two types, a foreign implementation, a field named twice, annotation variables, the type mismatches without their label, the second span of a duplicate, selector errors at the selector, a block ending in `;`, receive in Never, short spans, "on this runtime" (X5, X7..X17)
- 2.98 — clarity: tuples of `(...)`, occurs through branches, "not a function" for self-application, `()`, `None()`, refutable parameters, a reply in a local fn, a reply on one path, `if` without `else`, a lowercase type name (X-B1..B10)
- 2.98 — uncovered: the `Prelude.Local` label, `a=`/`a!` at a call site, an effect error in a pure `let` or guard (X)

## The toolchain

- 2.98 — `--build-root` does not find modules outside the source root, against §11.1 (T2)
- 2.98 — a stale dependent runs against a changed interface and faults (T3)
- 2.98 — a single-file build takes its namespace from the working directory and rewrites a module as another (T4)
- done — old spellings' refusals recommend options the job refuses; prefixes matched (T7): fixed 2026-09-29, an old spelling matched by its whole name and named only to a job that takes its replacement; `--version` and `--help` stand alone
- 2.98 — a repeated option takes the first; `--name=value` undocumented; empty values accepted (T8)
- done — `ern shell --main` without a file is ignored (T9): fixed 2026-09-29, refused (§11.2)
- 2.98 — the checker reports one error per function; a directory build stops at the first failing module (T10)
- 2.98 — `:load` of a dependent cannot use a module already loaded (T12)
- done — `:reload` says "no source has changed" when it found none (T13): fixed 2026-09-29, a loaded module the source root holds no source of named
- 2.98 — a faulting top-level binding: three behaviours and the wrong name (T14)
- done — a startup file's failures lack file and line; a startup file that is not UTF-8 is read as empty (T15, E10b..d): fixed 2026-09-29, a refusal and a fault named by file and line, a file that is not UTF-8 said and not run (§11.2), and the file named from the working directory; E10a was fixed with S1
- done — the shell's diagnostics use absolute paths (T16): fixed 2026-09-29, as §11.5 names a file
- done — `ern doc src` leaves a stale page and writes `.erc` files (T17): fixed 2026-09-29, a page of a module whose source is gone removed, by the module its title names at its place, and the build stated (§11.4); the manual pages found written with a Latin-1 `§`, and written as UTF-8
- done — the history's failure reported twice, the second garbling the transcript (T18, E9): fixed 2026-09-29, said once, and the history not written after
- 2.98 — the shell cannot show the prelude (T19)
- done — a corrupt `.erc` gets the host's message (T20): fixed 2026-09-28 with T6
- done — clarity: configuration options that do nothing yet, the startup file run silently, a silent directory build, a silent `ern test`, `:set timing`, every spawn site `input:1`, qualified type names, "tail" against "live region", `killed` against `Killed`, line mode and the formatter's layout, `--source-root` hint, the lowercase path's file, `ern(1)`'s synopses, the shell's exit status, `ern config`'s JSON, `:type let`, `:doc it`, an elided excerpt (T21..T34): fixed 2026-09-29 or decided: `--config-dir`'s help says what each job reads (T21); `ern test` says `no tests` and refuses two tests of one name (T24); timing measured the run already (T25); `:browse` writes types as the session does (T27); "live region" in `:help` and `:output`, GHCi gone (T28); the file named in a path refusal and `--source-root` hinted (T30); the synopses completed, and `ern(1)`'s sections planned in MVP 2.99 (T31); `ern config` laid out as Appendix C (T33); `:type` refuses a declaration, `:doc it` answers, and a gap in an excerpt is `...` (T34). Kept, with the log's *The Toolchain's Clarity Lines*: the startup files run without a line (T22), a directory build is silent (T23), `killed` and `Killed` (T28). Decided with the user 2026-09-29, and done: a typed input named by its count (T26), line mode taking further lines as a terminal does (T29), the shell's exit status and streams stated (T32)
- done — the toolchain's output depends on the locale, against §11.6 (C14): found fixed by MVP 2.95's ports, and a regression test added 2026-09-29
- done — `ern_cli`'s internal error has no newline (C34): fixed 2026-09-29
- 2.98 — a large paste is scanned again as it grows, a cost of `ern_tty`'s (shell_design.md's rewrite)

## The runtime

- done — the helper acknowledges an input after its end ahead of queued ones (C8): fixed 2026-09-29, its 'a' waiting behind the ones before it
- 2.98 — sockets, listeners and programs are missing from `Process.live`, `info` and faults (C10)
- done — `Os.start` can answer `Timeout`, which E.23 does not list (C18): fixed 2026-09-29, E.23 and `start`'s page say it: a time that passes before the program has started
- done — the helper's pipe and fork failures give no host reason (C19): fixed 2026-09-29, an 'f' frame with the host's reason, as a failed exec has
- done — the shell erases a held module's values (C21): fixed 2026-09-29, a module's values let go once it is purged; found by reading, and not covered by a test
- done — `Address.call`'s deadline taken after the delivery (C22): fixed 2026-09-29
- done — stdin opens a port beside the tty after keys were granted (C23): fixed 2026-09-29, a refused claim served nothing
- done — writers after a gone stream fault "returned without answering" (C27): fixed 2026-09-28, a sink whose stream has gone drops what it is given and answers, until the program has ended (§11); `stream_gone_test_` met it once in six runs
- done — `flush_run` misses a `signal` message (C28): fixed 2026-09-29
- done — a final line's `\r` at end of input (C29): fixed 2026-09-29, and §8.2 says a last line keeps its carriage return
- done — `variable/2` keeps a later value where the first is not UTF-8 (C30): fixed 2026-09-29, a name seen kept though its value is dropped; no test, the host giving no way to repeat a name in an environment
- done — a span's end treated as inside (C32): fixed 2026-09-29; no test reaches the position the reader named
- done — `note_text`'s wording against §11.5 (C33): fixed 2026-09-29, the code writing §11.5's words
- done — `spawnMonitored`'s wait not in `Watching` (C35): fixed 2026-09-29, spawnMonitored's wait watched as monitor's is; not covered by a test
- done — the shell collects in the input's own process (C36): fixed 2026-09-29, the session collecting in its own process once an input has answered; not covered by a test
- 2.98 — hardening: unchecked casts through `Foreign`, `Erl.atom` on received text, `stty` from `PATH`, the host's flags from the environment, a relative `HOME`, unbounded reads, the key in the working tree, a dangling `--config-dir` (S-H)
- 2.98 — the history decoder is quadratic (S11)

## The standard library, the libraries, the examples

- done — Markdown's styled rows leave a style open across the listing's cut (E5): fixed 2026-09-29, each styled row standing alone, a look it leaves on turned off at its end and on again at the next
- done — the editor's cursor counts Chars, the text graphemes (E6): fixed 2026-09-29, the cursor measured as the text before it stands
- done — filesync never settles, recording the peer's mtime (E7): fixed 2026-09-29, a stored file given the peer's time with `Fs.setModified`
- done — Markdown: inline HTML at a line's start becomes a Raw block; a lazy line after a quoted heading; tabs in code expanded (E8, E21, E22): fixed 2026-09-29, and G.2 states the HTML and tab rules
- 2.98 — `Bytes` has no search or split (N-L), and gains the functions of Erlang's `binary` that `String` has, named as `String`'s are: `contains`, `indexOf`, `startsWith` and `endsWith` from `match`, `split`, `replace`, `join`, `repeat` from `copy/2`, and `toHex` and `fromHex` from `encode_hex` and `decode_hex`. Not taken: `at`, `part`, `bin_to_list` and `list_to_bin`, which are `get`, `slice`, `toList` and `fromList`; `first` and `last`, which `get` is; `encode_unsigned` and `decode_unsigned`, which are bitstrings' (§5.11); `longest_common_prefix` and `longest_common_suffix`, words `String` has not; and `compile_pattern`, `copy/1` and `referenced_byte_size`, which are the host's representation
- done — `List.partition` calls its predicate from the last element (E11): fixed 2026-09-29
- done — `Path.withExtension` and `extension` on dot-files and the root (E12): fixed 2026-09-29, a dot that begins a name beginning no extension and the root left as it is (E.14)
- done — `Fs.Entry.mtime` is whole seconds (E13): fixed 2026-09-29 by stating it: the host gives whole seconds (E.17)
- done — `Terminal.size`'s page example does not compile outside the module; examples checked inside their module (E15): fixed 2026-09-29, and an exported declaration's example checked from outside its module
- done — the history trim is not written whole (E16): fixed 2026-09-29, written beside and renamed; a history that is not UTF-8 reported as unreadable
- done — the web server answers a bad request with 404 (E17): fixed 2026-09-29, with the banner and the empty id of the pages line
- done — services' stale line and sleep; echo's unwatched monitor; repl's recursion claim (E18..E20): fixed 2026-09-29: services' line was right after the layout change, and its sleep waits on the language (nothing says a restart has finished); echo awaits its server; repl's claim dropped
- done — pages: Tcp's close and Errors, Fs's rules, Os's Errors sections, Ets and others without Errors or Examples, String's primitives and `toFloat`, Map and Set orders, Either's citation, `Erl.atom`'s page, `Process.faults`, Supervisor's example, `compare` written with `<`, NO_COLOR, the shell's Bool styles, "tail", the shell's `//` pages, the template, the web server's banner, snake, `tools/manual.ern` (E-B1..B21): fixed 2026-09-29; §9.6 states the ordering of the four types, §11.4 marks a private declaration, and the interrupt reaches every subscriber as §8.2 says, a runtime defect snake's test found; the log's *The Pages Line*
- 2.98 — the language: a list of functions as a binding, `kill` and `monitor` on `Process`, "no limit" unnamed, `Io.debug` a shim, every program's `errorText`, no word of a restart's end, `Tcp.close` and `closeListener`, `Bytes.slice` a shim (E-C1..C8)

## The code

- done — a test's uncounted sleep calls a deadlock 4 times in 40; `restart_limit_test` cannot tell its limits; two tests assert only `{error, _}`; a comment of `ern_tcp_tests`; a stale `Sys` clause (C37..C41): fixed 2026-09-29; the uncounted sleep had been fixed in MVP 2.95
- done — `-spec`s missing in `ern_signals`; export lists out of order; stale comments in `ern_rt`, `ern_tty`, `ern_typecheck`, `ern_descriptor`, `ern_boundary`, `ern_shell`, `ern_cli`, `ern_lexer`; misplaced test comments (C42..C46): fixed 2026-09-29, and `ern_style_tests` now holds the export lists' order and the `-spec`s
- done — clarity: the formatter's dead filter and `IsClose`; the lexer's quadratic block comment; a block comment glues the next token; unreflowed comments; `ern_rt`'s repeated names and ad hoc catches; the helper's `runtime_open` and polling; `ern_tcp`'s repeated shape; function descriptors' two shapes; `trim_start`; `ern_typecheck`'s text match; the emitter's doubled form; `ern_cli`'s duplicates; `initialize/3`'s monitor; nits (C-B1..B19): fixed 2026-09-29, each as the reader asked; kept: the helper's 50 ms poll after a program's outputs close, and `live/0`'s catch around a select, with the log's *The Code's Cheap Lines*

## The documents

- done — tightened on 2026-09-28: CLAUDE.md, the plan, `architecture.md`, `shell_design.md`, the two distribution notes brought to the report, `style.md`, `install.md`, `memory.md`, `development.md`, `emacs_mode.md`, `language_feedback.md`, `testing_improvements.md`, with the documents reader's findings on each (D5..D31, D-B), marked done on their writers' word; what they argued is the log's *What the Design Notes Argued* and *Erlang's Standard Library, Module by Module*
- done — code comments that cited the old plan's numbered sections (`plan 2.1`, `plan 2.4`) or `review.md`'s numbered steps cite the report, or nothing; `ern_rt`'s header said a late monitor reports the cause, where §6.9 says `Unknown`
- done — `make sections` and `make xref` never check Appendix G; the documents' tests read too few files (D1, D4): fixed 2026-09-29, every appendix letter checked, G.1 and G.2 cited by tests, and every tracked document read, which found `shell/README.md`'s paths read from its own directory and `install.md`'s `VERSION` for `<version>`; `findings.md` alone is left out of the citations, since its lines cite as their readers did
- done — `shell/README.md`: `Process` is no system module; the reader bullet does not parse; the greeting, the first prompt, line mode (D26, D-B8); the page cut from 2,297 words to 1,325, what `shell_design.md` owns pointed at
- done — the report's line 3 sends open questions to the log (D): fixed 2026-09-29, the decisions still to be made are the plan's
- done — `ern_cli_tests`' `--help` loop leaves out `format`; `editor.ern` cites §9.3 for E.16 (D): fixed 2026-09-29, and the terminal tests' and the probe's citations with it
- done — the shell reader's findings (H1..H18), the register reader's (G1..G28, G30, G31, G33..G39)
- 2.98 — the tightened documents were checked by their writers against the code and by `make test-docs`, and read back whole only in part: the plan's MVP 2.95, 3.0 and 3.1, `style.md`, `install.md` and the shell note's opening. `architecture.md`, `shell_design.md`, the two distribution notes, `memory.md`, `development.md` and `emacs_mode.md` are read back against the code, and D5..D31 checked one by one (the documents' rewrite)
- done — `memory.md` keeps "about a minute and a half" for `make load`, not measured since the loads changed (the documents' rewrite): measured 2026-09-29 at 99 and 104 seconds; the first run found the shell's code growing, the sites of T26 compiled into each input, fixed the same day
- done — the log's *Erlang's Standard Library, Module by Module* has a column "Waiting, and when", roadmap the plan owns (the documents' rewrite): fixed 2026-09-29, the column gone and the plan named, which holds all three
- 2.98 — `Clock.monotonic` and `Udp` stand in the plan's "Not in any MVP" as waiting for "a later MVP", with no milestone and no verdict (CLAUDE.md, *No decision is left pending*): each is judged on E.0 and placed (the documents' rewrite)
- done — `shell_design.md`'s *Ordering* says the session drains the screen before each prompt, and `main` writes the first at a terminal without a drain: the note says so, or `main` calls `prompt` (the shell README's rewrite): fixed 2026-09-29, `main` calls `prompt`
- done — `shell_design.md`'s *Processes* and `shell.ern`'s header say "without a terminal" where line mode is input that is not a terminal or output with no size; the note's *Start and end* leaves out the greeting (the shell README's rewrite): fixed 2026-09-29
