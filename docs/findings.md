# Findings of the first review

The findings of the twelve readers of 2026-09-28 still open, one line each, by area; each is planned in MVP 2.98. The readers: the report's principles (P), the cold reader (K), the register (G), the guide (U), the newcomer (N), the documents (D), the code (C), the Ernest code (E), the tools (T), the diagnostics (X), security (S), the shell's README (H). The 143 lines done by 2026-09-29, each with what was done, are at commit b7d34c0. This file goes when every line is done or in the plan.

## The report

- 2.98 — the supervisor's restart on request is a language mechanism with no prelude entry; every `receive` of a child is an unwritten exit point (P10)
- 2.98 — claiming the terminal twice faults the entry process rather than the caller (P12)
- 2.98 — `Tcp.write` and `Os.write` fail silently (P13)
- 2.98 — bitstring sizes cannot name a top-level constant or a variable bound to their left (P16)
- 2.98 — `Int.div` and `Int.mod` are prelude variants of `/` and `%`, and `mod` is a remainder (P17, K-B6)
- 2.98 — `Address.callForever` beside `Address.call` is a second way (P18)
- 2.98 — every prelude type takes a module namespace, `Test` and `Path` among them (P19)
- 2.98 — an unresolved block variable is an error though nothing depends on it (P20)
- 2.98 — `C` and `C()` both match any value of a named constructor; `Some()` and `None()` are grammatical (P21, K19)
- 2.98 — `unit(N)` is a second way to scale a size (P22)
- 2.98 — rules that buy little, to weigh: `true`/`false` reserved, prefix `!`, `abstract` with `export` only, the 255-character limit, `Path` in the prelude (P-C)

## The guide and the README

- 2.98 — `Tcp` is never taught, though §9.5 shows a chat server's unit (N1)
- 2.98 — §4.4 does not cover a broadcast to a consumer that stalls (N4)
- 2.98 — the language: sockets pull-only, mandatory timeouts, slow standard library calls, no bounded mailbox (N-L1..L6)

## Diagnostics (§11.5)

- 2.98 — a rejected call site does not name the parameter and its restriction (`==` through a variable, a reply to `drop`) (X1, X2)
- 2.98 — a recursive use at another type is reported over the declaration, reversed, unlabelled (X3)
- 2.98 — positions and labels: `compare`'s shape, a field of two types, a foreign implementation, a field named twice, annotation variables, the type mismatches without their label, the second span of a duplicate, selector errors at the selector, a block ending in `;`, receive in Never, short spans, "on this runtime" (X5, X7..X17)
- 2.98 — clarity: tuples of `(...)`, occurs through branches, "not a function" for self-application, `()`, `None()`, refutable parameters, a reply in a local fn, a reply on one path, `if` without `else`, a lowercase type name (X-B1..B10)
- 2.98 — uncovered: the `Prelude.Local` label, `a=`/`a!` at a call site, an effect error in a pure `let` or guard (X)

## The toolchain

- 2.98 — `--build-root` does not find modules outside the source root, against §11.1 (T2)
- 2.98 — a stale dependent runs against a changed interface and faults (T3)
- 2.98 — a single-file build takes its namespace from the working directory and rewrites a module as another (T4)
- 2.98 — a repeated option takes the first; `--name=value` undocumented; empty values accepted (T8)
- 2.98 — the checker reports one error per function; a directory build stops at the first failing module (T10)
- 2.98 — `:load` of a dependent cannot use a module already loaded (T12)
- 2.98 — a faulting top-level binding: three behaviours and the wrong name (T14)
- 2.98 — the shell cannot show the prelude (T19)
- 2.98 — a large paste is scanned again as it grows, a cost of `ern_tty`'s (shell_design.md's rewrite)

## The runtime

- 2.98 — sockets, listeners and programs are missing from `Process.live`, `info` and faults (C10)
- 2.98 — hardening: unchecked casts through `Foreign`, `Erl.atom` on received text, `stty` from `PATH`, the host's flags from the environment, a relative `HOME`, unbounded reads, the key in the working tree, a dangling `--config-dir` (S-H)
- 2.98 — the history decoder is quadratic (S11)

## The standard library, the libraries, the examples

- 2.98 — `Bytes` has no search or split (N-L), and gains the functions of Erlang's `binary` that `String` has, named as `String`'s are: `contains`, `indexOf`, `startsWith` and `endsWith` from `match`, `split`, `replace`, `join`, `repeat` from `copy/2`, and `toHex` and `fromHex` from `encode_hex` and `decode_hex`. Not taken: `at`, `part`, `bin_to_list` and `list_to_bin`, which are `get`, `slice`, `toList` and `fromList`; `first` and `last`, which `get` is; `encode_unsigned` and `decode_unsigned`, which are bitstrings' (§5.11); `longest_common_prefix` and `longest_common_suffix`, words `String` has not; and `compile_pattern`, `copy/1` and `referenced_byte_size`, which are the host's representation
- 2.98 — the language: a list of functions as a binding, `kill` and `monitor` on `Process`, "no limit" unnamed, `Io.debug` a shim, every program's `errorText`, no word of a restart's end, `Tcp.close` and `closeListener`, `Bytes.slice` a shim (E-C1..C8)

## The documents

- 2.98 — the tightened documents were checked by their writers against the code and by `make test-docs`, and read back whole only in part: the plan's MVP 2.95, 3.0 and 3.1, `style.md`, `install.md` and the shell note's opening. `architecture.md`, `shell_design.md`, the two distribution notes, `memory.md`, `development.md` and `emacs_mode.md` are read back against the code, and D5..D31 checked one by one (the documents' rewrite)
- 2.98 — `Clock.monotonic` and `Udp` stand in the plan's "Not in any MVP" as waiting for "a later MVP", with no milestone and no verdict (CLAUDE.md, *No decision is left pending*): each is judged on E.0 and placed (the documents' rewrite)
