# Style

Four rules hold in every language of the repository. `test/ern_style_tests.erl` checks the second, the third, and the fourth's Erlang half.

- A step of indentation is four spaces.
- No file holds a tab, but a Makefile.
- A line of code is at most 100 characters. Prose in markdown may be longer.
- A name in a namespace the repository shares with other code carries the repository's name: an Erlang module begins `ern`, an Emacs Lisp symbol `ernest-`.

## Erlang style guide

For the toolchain's code under `erl/`.

- **Every Erlang module is `ern_<thing>`**, where `<thing>` is unique across the repository; a vendored file keeps its upstream name. A module compiled from an Ernest source is `ern@<namespace>`, the path with `@` for `/`: `stdlib/io.ern` is `ern@io`. A module's name does not repeat its application, which its directory names. The decisions log's *One Token for the Project* says why.
- **One `-export` list at the top**, in the order the functions appear.
- **`-spec` on every exported function.** A type shared between modules is a `-type` of the module that owns it.
- **A shared record lives in `include/*.hrl`**, any other in its module. The only macros defined are the few constants that need a name.
- **Tests are EUnit**, in `erl/<app>/test/`, or in `test/` when they span applications. A test module is `<module>_tests` for the module it tests, and otherwise names what it tests: `ern_grammar_tests`. A test function tests one behaviour, is named after it, and has above it a comment naming what it tests: `%% report §x.y`, or a document's path.
- **No OTP behaviour for a process of the toolchain's own, and no rebar3.** A callback module that one of OTP's own servers calls, such as a signal handler, is no such process. The decisions log's *No OTP in the Toolchain* says why.
- **`make` compiles with `+debug_info -Werror`**: a warning is an error.
- **Tokens and AST nodes are plain tuples and records**, never closures or ETS state.
- **A precondition is `Cond orelse fail(...)` on one line.** Two or more conditions before the `fail` are a `case` on them.

## C style guide

The runtime's helper, `erl/runtime/c_src/ern_exec.c`, is C99, compiles with `-pedantic -Wall -Wextra -Werror`, and keeps the shared rules of indentation, tabs and line length.

## Ernest style guide

For every Ernest source in the repository and every Ernest block of the report and the guide. `ern format` writes the second list's layout, `make test` holds all of them to it, and `make format` restores it. What else the formatter keeps and changes is report §11.6's. The Emacs mode indents as the formatter does ([`emacs_mode.md`](emacs_mode.md)).

### What the writer decides

- **Top-down layout.** Types first; then the module's service bindings; then `main` in a program, or the exported functions in a library. Each is followed directly by its helpers. A helper that several share goes with its first user, or in a utilities section at the bottom.
- **A block holds more than one statement.** One expression is written bare, without braces. `test/ern_style_tests.erl` checks it.
- **A blank line groups.** Where one stands inside a construct is the writer's choice. A declaration's comment or doc block stands directly above it.
- **Name a part of a long expression** where the formatter's split reads worse than a name.
- **A section is marked by a banner**: a line `//`, one or more lines `// text`, and a line `//`, with a blank line before it and after it. A module with a doc block has no banner for the file; its `///` block is its header (report §2.2).

### The layout `ern format` writes

- **A line stands a step in from the line on which the innermost construct open around it began**: a bracket, a brace, an expression an operator carries on, or a body after a `=`, `->`, `then` or `else` that ends a line. A line that opens with a closing bracket or brace, or with `else`, stands at its construct's line. An item standing after its bracket counts as beginning a line there. A further arm, and a further line of a type's alternatives, opens with its bar two columns to the left, so that what follows the bar stands at the step. Only a bracket's items are aligned; nothing is lined up under an `->`, an `=` or a trailing comment.
- **A line that opens with a binary operator carries on the expression above it.** A further line of the same expression stands at the same step. A line whose operator binds more tightly carries on the operand begun on the line above, and stands a step further in.
- **A block, a `match` and a `receive` run over lines however short**, a statement or an arm a line. What follows the closing brace, an `else`, a `then`, a `;`, a `)` or an operator, follows it on its line.
- **A bracket stays on one line when the whole line fits, and otherwise holds one item a line.** A bracket is the parenthesis, square bracket or `<<` around a call's arguments, a function's parameters, a constructor's fields, declared or built, or the items of a tuple, a list or a bitstring. The first item stays on the bracket's line, each further item stands under it, and the closing bracket ends the last item's line. The outermost bracket breaks first, and of two on one line the first. A bracket of one item does not break. A comment or a doc block before the first item puts that item on a line of its own, and the items a step in.
- **A last item that opens a brace keeps the items on the bracket's line** where that line fits up to the brace, as a lambda whose body is a `match` does. The brace and the bracket close together.
- **An `if` stays on one line when it fits, and otherwise breaks at every `then` and `else`.** A branch whose first line ends in a brace or a `then` stays beside its `then` or `else` when that fits: `then {`, `} else {`, `else match x {`, and `else if` are each written on one line.
- **The body after an arm's `->`, a lambda's `=`, or a `let`'s `=` or `<-` stays on its line when it fits**, whole or up to a brace or a `then` that ends its first line. Otherwise it begins the next line. A lambda and a `let` have no other rule of their own.
- **A function's body begins on the line after its head's `=`, however short.** A body that is a block opens its brace at the end of the head's line. A `foreign fn`'s implementation string stands where a body does.
- **A type whose alternatives do not fit breaks after its `=`**, and its alternatives fill the lines that follow.

Illustrative code in the layout:

    fn start(keys : Optional(Keys)) -> Unit = {
        let reader = spawn(Local, fn() = match keys {
            Some(k) -> readLoop(k)
          | None -> plainLoop()
        });
        loop(reader)
    }

    fn respond(request : Request,
               session : SessionId,
               cookies : List(Cookie),
               body : String) -> Bytes with Msg =
        Response(status = StatusCode.ok, headers = [], body = body)
            |> withCookie("sid", SessionId.text(session))
            |> render
