# Style

The rules build on widely accepted guides and state only the repository's own rules and where they differ: for Erlang, Ericsson's *Programming Rules and Conventions* (Eriksson, Williams and Armstrong) and Inaka's *Erlang Coding Standards & Guidelines*; for Ernest, the *Elm Style Guide*, then the conventions of Gleam and OCaml. Where they and this file differ, this file holds. A guide serves the reader and is not a law: a rule a test checks holds always, and where another would make the code read worse, judgment goes first. `test/ern_style_tests.erl` checks what is marked *(tested)*.

## Every language

- A step of indentation is four spaces.
- No file holds a tab, but a Makefile *(tested)*.
- A line of code is at most 100 characters; prose in markdown may be longer *(tested)*.
- A name in a namespace shared with other code carries the repository's name: an Erlang module begins `ern` *(tested)*, an Emacs Lisp symbol `ernest-`.

### Names

Code is read more often than written, mostly by someone else, so a name is written for that reader. These rules cover a variable, a parameter, a function, an Erlang record and its fields, and an Ernest type, constructor and field. Longer names make longer code, and that is accepted.

- **A name says what its value is or what its function does**, in the words of the domain: `Tokens`, `Descriptor`, `Namespace`, `parse_module`; not what the value is made of, `List`, `Map`, where that is not what it is.
- **One concept, one name, in every module**: a type's descriptor is `Descriptor` in the emitter, the boundary and the runtime alike, and two concepts never share a name. A concept the report names takes the report's name; where the code names one otherwise, or the report's name seems wrong for the code, the question goes to the user before anything is renamed. A value changing through a function is numbered, `Env1`, `Env2`, and a numbered name is nothing else; past two steps the function is split.
- **No abbreviation a reader must guess.** A well-known acronym is fine, `TCP`, `URL`, `UTF-8`, `JSON`, and so is an abbreviation the host or the report writes: `Pid`, `Ref`, `Fd`, and `Acc` for what a fold carries.
- **One letter only where the whole scope is one line that shows what it is**, as a comprehension's element or a one-line fun's parameter: `[size(Module) || Module <- Modules]`, not `[size(M) || M <- Ms]`, wherever the line does not show it.
- **A function that does something is a verb**, `compile`; one that gives a value is that value, a noun or, for the value made so, a past participle, `descriptor`, `armed`, `held`; a yes-or-no reads as the question, `is_link`, `isEmpty`.
- **A record, a type or a constructor names what it holds**, a type as a noun: `#emit_context{}`, not `#cx{}`; `Key(Terminal.Event)`, not `K`.
- **A name the report states** changes only through the report.

### Structure

- **A function reads on one screen**; a longer one is split into steps whose names say what they do.
- **How deep code nests is the writer's judgment**, bounded by the line: a construct that no longer reads within 100 characters becomes a function.
- **A module has one job**, which its first comment states.
- **A comment says why and cites the report section the code implements**, `%% Report §8.4: ...`, `// Report §11.2: ...`; the names say what it does.

## Erlang

For the toolchain under `erl/`.

- **Every module is `ern_<thing>`**, `<thing>` unique across the repository and not repeating its application, which its directory names; a vendored file keeps its upstream name. A module compiled from Ernest is `ern@<namespace>`, the path with `@` for `/`: `stdlib/io.ern` is `ern@io`. The log's *One Token for the Project* says why.
- **One `-export` list at the top**, in the order the functions appear *(tested)*.
- **`-spec` on every exported function** *(tested)*; a type shared between modules is a `-type` of its owner.
- **A shared record lives in `include/*.hrl`**, any other in its module. The only macros are the few constants that need a name.
- **Tokens and AST nodes are plain data**, records and tuples, never closures or ETS state. A value of more than three parts is a record, and so is a tuple of more than two that crosses modules: a positional tuple makes its reader count.
- **A precondition is `Cond orelse fail(...)` on one line**; two or more conditions are a `case`.
- **No OTP behaviour for the toolchain's own processes, and no rebar3**; a callback module one of OTP's servers calls, a signal handler, is no such process. The log's *No OTP in the Toolchain* says why.
- **`make` compiles with `+debug_info -Werror`**: a warning is an error.
- **Tests are EUnit**, in `erl/<app>/test/`, or in `test/` when they span applications. A test module is `<module>_tests`, or names what it tests, `ern_grammar_tests`. A test function tests one behaviour, is named after it, and has above it a comment naming what it tests: `%% report §x.y`, or a document's path.

## C

The runtime's helper, `erl/runtime/c_src/ern_exec.c`, is C99 and compiles with `-pedantic -Wall -Wextra -Werror`.

## Ernest

For every Ernest source and every Ernest block of the report and the guide. The layout `ern format` writes, and what else it keeps and changes, is report §11.6's: `make test` holds every source to it, `make format` restores it, and the Emacs mode indents as it does ([`emacs_mode.md`](emacs_mode.md)). The writer decides the rest:

- **Top-down**: types, then the module's service bindings, then `main` or the exported functions, each followed directly by its helpers; a helper several share goes with its first user or in a utilities section at the bottom.
- **A block holds more than one statement**; one expression is written bare *(tested)*.
- **A blank line groups**, where the writer chooses. A declaration's comment or doc block stands directly above it.
- **Name a part of a long expression** where the formatter's split reads worse than a name.
- **A section's banner** is a line `//`, lines `// text`, and a line `//`, with a blank line before and after. A module with a doc block has no banner for the file; its `///` block is its header (report §2.2).
- **An exported function's parameters are named for their role**, since the shell and `ern doc` show the signature: `List.filter(list, keep)`; `xs` and `f` only where nothing more can be said.
- **A message type's constructors**: a request in the imperative, `Subscribe`; an event in the past tense, `Resized`.

Code in that layout:

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
