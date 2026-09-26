# Building and installing

How the toolchain is built, tested, and installed. This document owns what building needs, the make targets, and the installation; the README says where things are, [`style.md`](style.md) how the code is written, and the plan when a target was added.

## What building needs

Erlang/OTP 29 and GNU make. The toolchain's Erlang uses no rebar3 and no OTP behaviours, by design; [`style.md`](style.md) says what that covers. `make test` also needs python3, for the pseudo-terminal the terminal tests run a program under; Erlang cannot open one. Emacs is optional: without it the mode's tests are skipped and the rest runs.

## The make targets

```
make              compile every application into its ebin/, then stdlib/, libs/, shell/
make test         build, then run every area below
make test-erl     the unit tests of every application under erl/, side by side;
                  APP=typer for one
make test-programs  the example programs, compiled and run
make test-docs    the citations and the style
make test-guide   the guide's examples
make test-shell   the shell's sessions and the terminal
make test-emacs   the Emacs mode's tests (docs/emacs_mode.md)
make doc          write the standard library's and the prelude's pages to build/stdlib/,
                  with index.md
make sections     list the report sections no test cites
make xref         check that every section citation and document path in the documents resolves
make coverage     every section with how many tests cite it, thinnest first
make golden       rewrite test/golden/, the Erlang the compiler emits per example
make clean        remove build products
make clean-emacs  remove Emacs backup, auto-save, and lock files
```

CLAUDE.md says which of the test targets a change runs.

## Installing

Not yet: `make install` is the plan's MVP 2.95, which writes this section when it builds it. Until then the toolchain runs from the repository, as `bin/ern`.
