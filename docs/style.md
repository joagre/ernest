# Style

Four rules hold in every language of the repository. `test/ern_style_tests.erl` checks the second, the third, and the fourth's Erlang half, and of the Erlang style guide the export list's order and the `-spec`s.

- A step of indentation is four spaces.
- No file holds a tab, but a Makefile.
- A line of code is at most 100 characters. Prose in markdown may be longer.
- A name in a namespace the repository shares with other code carries the repository's name: an Erlang module begins `ern`, an Emacs Lisp symbol `ernest-`.

The rules below build on style guides that are widely accepted, and state only the repository's own rules and where it differs from them. For Erlang they are Ericsson's *Programming Rules and Conventions* (Eriksson, Williams and Armstrong) and Inaka's *Erlang Coding Standards & Guidelines*; for Ernest, the *Elm Style Guide*, the nearest in spirit, and after it the conventions of Gleam and OCaml. Where one of them and this file differ, this file holds.

## Names

Code is read more often than it is written, and mostly by someone other than its writer, so a name is written for that reader. These rules hold for every name in every language of the repository: a variable, a parameter, a function, and a record and its fields in Erlang, a type, a constructor and a field in Ernest. Longer names make the code longer, and that is accepted; the line stays at 100 characters.

- **A name says what its value is, or what its function does**, in the words of what the code is about: `Tokens`, `Descriptor`, `Namespace`, `parse_module`. It does not say what the value is made of, `List`, `Tuple`, `Map`, where that is not what it is.
- **One concept has one name** across the repository. A thing named one way in one module is named the same way in every other: a type's descriptor is `Descriptor` in the emitter, the boundary and the runtime alike. Two concepts never share a name, even in different modules. A value that changes as it goes through a function is its name numbered, `Env1`, `Env2`, and a numbered name is never anything else. Two numbered steps are the most: a third says the function does too much, and it is split.
- **No abbreviation or acronym a reader must guess.** Those the host or the report writes are kept: `Pid`, `Ref`, `Fd`, `UTF-8`, and `Acc` for what a fold carries.
- **A one-letter name only where its whole scope is one line that shows what it is**: the element of a list comprehension, the parameter of a one-line fun, `[size(Module) || Module <- Modules]` over `[size(M) || M <- Ms]` wherever the line does not show it.
- **A function that does something is named by a verb**, `compile`, `send`; one that gives a value by that value, a noun or, for the value made so, a past participle: `descriptor`, `armed`, `held`. A function that answers yes or no reads as the question: `is_link` in Erlang, `isEmpty` in Ernest.
- **A record's name says what one holds, and each field what it holds**: `#emit_context{}`, never `#cx{}`. In Ernest a type is a noun, and a constructor says which case of the type a value is: `Key(Terminal.Event)`, never `K`.
- **A name the report states**, an exported function's, a type's, a constructor's, changes only through the report.

## Structure

These hold in every language of the repository, as the names do.

- **A function reads on one screen.** A longer one is split into steps, each a function whose name says what the step does.
- **Nesting goes no more than three levels deep**: a `case` inside a `case` inside a `case` is the most, and a fourth is a function of its own.
- **A module has one job**, which its first comment states.
- **A comment says why, and cites the report section the code implements**: `%% Report §8.4: ...` in Erlang, `// Report §11.2: ...` in Ernest. What the code does, its names say.

## Erlang style guide

For the toolchain's code under `erl/`.

- **Every Erlang module is `ern_<thing>`**, where `<thing>` is unique across the repository; a vendored file keeps its upstream name. A module compiled from an Ernest source is `ern@<namespace>`, the path with `@` for `/`: `stdlib/io.ern` is `ern@io`. A module's name does not repeat its application, which its directory names. The decisions log's *One Token for the Project* says why.
- **One `-export` list at the top**, in the order the functions appear.
- **`-spec` on every exported function.** A type shared between modules is a `-type` of the module that owns it.
- **A shared record lives in `include/*.hrl`**, any other in its module. The only macros defined are the few constants that need a name.
- **Tests are EUnit**, in `erl/<app>/test/`, or in `test/` when they span applications. A test module is `<module>_tests` for the module it tests, and otherwise names what it tests: `ern_grammar_tests`. A test function tests one behaviour, is named after it, and has above it a comment naming what it tests: `%% report §x.y`, or a document's path.
- **No OTP behaviour for a process of the toolchain's own, and no rebar3.** A callback module that one of OTP's own servers calls, such as a signal handler, is no such process. The decisions log's *No OTP in the Toolchain* says why.
- **`make` compiles with `+debug_info -Werror`**: a warning is an error.
- **Tokens and AST nodes are plain data**, records and tuples, never closures or ETS state.
- **A value of more than three parts is a record**, and so is a tuple of more than two that crosses from one module to another: a positional tuple makes its reader count.
- **A precondition is `Cond orelse fail(...)` on one line.** Two or more conditions before the `fail` are a `case` on them.

## C style guide

The runtime's helper, `erl/runtime/c_src/ern_exec.c`, is C99, compiles with `-pedantic -Wall -Wextra -Werror`, and keeps the shared rules of indentation, tabs and line length.

## Ernest style guide

For every Ernest source in the repository and every Ernest block of the report and the guide. The first list below is the writer's; the layout `ern format` writes, and what else it keeps and changes, is report §11.6's. `make test` holds every source to it, and `make format` restores it. The Emacs mode indents as the formatter does ([`emacs_mode.md`](emacs_mode.md)).

### What the writer decides

- **Top-down layout.** Types first; then the module's service bindings; then `main` in a program, or the exported functions in a library. Each is followed directly by its helpers. A helper that several share goes with its first user, or in a utilities section at the bottom.
- **A block holds more than one statement.** One expression is written bare, without braces. `test/ern_style_tests.erl` checks it.
- **A blank line groups.** Where one stands inside a construct is the writer's choice. A declaration's comment or doc block stands directly above it.
- **Name a part of a long expression** where the formatter's split reads worse than a name.
- **A section is marked by a banner**: a line `//`, one or more lines `// text`, and a line `//`, with a blank line before it and after it. A module with a doc block has no banner for the file; its `///` block is its header (report §2.2).
- **An exported function's parameters are named for their role**, since its signature is documentation that the shell and `ern doc` show: `List.filter(list, keep)`. `xs` and `f` stand only where the function is so general that nothing more can be said.
- **A message type's constructors name what they are**: a request in the imperative, `Subscribe`, `Write`, and an event in the past tense, `Resized`, `Pasted`.

### The layout `ern format` writes

Report §11.6 states it. Illustrative code in that layout:

    fn start(keys : Optional(Keys)) : Unit = {
        let reader = spawn(Local, fn() = match keys {
            Some(k) -> readLoop(k)
          | None -> plainLoop()
        });
        loop(reader)
    }

    fn respond(request : Request,
               session : SessionId,
               cookies : List(Cookie),
               body : String) : Bytes with Msg =
        Response(status = StatusCode.ok, headers = [], body = body)
            |> withCookie("sid", SessionId.text(session))
            |> render
