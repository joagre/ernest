# Style

What a program written in Ernest looks like: what a tool writes, what the report asks of a library's names, what the standard library does beyond that, and the names that recur in every program. It assumes [*Programming in Ernest*](language.md), whose words it uses, and cites the report, Ernest's definition under `report/`, by section, Appendix E being the standard library's. The first is written for the writer by `ern format`, and the second binds a library, a set of modules a program uses beside the standard library's (report Appendix E.0). The rest is what the standard library does, and a program that does the same reads like the library it calls.

## What a tool writes

`ern format` writes one layout, which has no options (report §11.6): a step of indentation is four spaces, a line fits within 100 columns where the layout can make it, a function's body begins on the line after its head's `=`, a `match`, a `receive` and a block run over lines, and a bracket that does not fit holds one item a line. `ern format src` lays every module under `src` out so, and `ern format --check src` names one that is not. A file's name is lowercase words joined by `_` (report §11.1), and the module's name is read from it, `kv_parser.ern` for `KvParser` (report §4.2).

## What the report asks of a library's names

Appendix E.0 has four admission rules, which decide whether an operation is the standard library's, and ten *shape rules*, which give an operation its name and its arguments.

Shape rules 1 to 5, 7, 9 and 10 bind a library outside the standard library too: the *subject*, the value an operation acts on, comes first and its *callbacks*, the functions passed to it, last, so that `x |> f(a)` is `f(x, a)`; one verb per operation on each kind of type; a conversion named by the other type, `toInt`, `fromList`; a partial operation, one with no answer for some inputs, answering `Optional` and one with a cause `Either`; a function's type naming a mailbox only where the function's own process's mailbox is involved; an exported type listed as the functions are and named for what it is, never for its module; no `Bool` that chooses between two behaviors; and a name that is the word a reader who knows the operation predicts.

Shape rule 6 says what a module's documentation holds, which `ern doc` writes as a page and the shell's `:doc` shows.

## What the standard library does

A value's name is camelCase and a type's PascalCase, `parseHeader`, `OrderedSet`, and a yes-or-no reads as the question, `isEmpty`. A name says what its value is or what its function does, in the words of the domain: a function that does something is a verb, `parse`, and one that gives a value is that value, a noun or an adjective, `size`, `sorted`; a type or a constructor names what it holds, a type as a noun, `Line(String)`, not `L`.

No abbreviation a reader must guess: a well-known acronym is fine, `TCP`, `URL`, `UTF-8`, `JSON`, and so is one the host, the Erlang runtime Ernest runs on, writes, `Pid`, `Ref`, `Fd`. One letter only where the whole scope is one line that shows what it is, `fn(x) = x + 1`, and `xs` and `f` only where nothing more can be said. One concept, one name, in every module.

An exported function's parameters are named for their role, as the glossary below names them, since the shell and `ern doc` show the signature: `List.filter(list, keep)`, `Fs.read(path, ms)`. A type variable is `a`, `b` for a value, `k` and `v` for a map's, `e` for an effect, what a function receives, and `m` for a mailbox type (the language guide's §3.5 and §4.1); where an `Either(e, a)`'s error takes `e`, the effect is `x`, `Either.map : (Either(e, a), (a) -> b receiving x) -> Either(e, b) receiving x` (report Appendix E.11); an exported function's type variables are annotated too, since an inferred one prints as `a`, `b`, `c` whatever its role. The spelling is American English in names and messages alike, `color`, `initialize`; a name of the host's keeps its own.

A module reads top-down: its types, then its service bindings, the top-level `let`s that hold a process's address (the language guide's §6.5), then `main` or the exported functions, each followed directly by its helpers; a helper several share goes with its first user or in a section at the bottom. A module has one job, which its doc block, the `///` lines first in the file (report §2.2), or its first comment states. A function reads on one screen; a longer one is split into steps whose names say what they do, and a construct that no longer reads within the line becomes a function.

A block holds more than one statement; one expression is written bare. A blank line groups, where the writer chooses, and a comment or doc block stands directly above its declaration. A part of a long expression is named where the formatter's split reads worse than a name. A section's banner is a line `//`, lines `// text`, and a line `//`, with a blank line before and after; a module with a doc block has no banner for the file, since the block is its header (report §2.2). A comment says why; the names say what.

## Glossary

The names that recur in a program, one for each concept, in every module. The report is the authority: a concept it names takes its name, and a citation such as E.5 names a section of its Appendix E, and E.0's admission and shape rules their number. A name not here is the writer's.

- A function's **subject** is named for what it is, `list`, `text`, `map`, `set`, `bytes`, `path`, `table`, `process`. Not `xs`, `s`, `m`, `b`, `r`, `t`, `p`.
- A **callback** is named for its role: `keep` for a predicate that keeps, `test` for one asked of each element, as `any`, `all`, `find`, `span` and `partition` ask it, `step` for what a fold or a `try` function, `List.tryMap`, runs over each element (E.0 rule 2), `wrap` for the function a caller gives to make its own message from what arrives later, a `Down`, an alarm (E.0 shape rule 8); `f` only where nothing more can be said. Not `p`, `g`.
- **acc**: what a fold or a recursion carries. Not `done`.
- **reply**: a `Reply`. Not `r`.
- **index**: a position in a sequence (E.2, E.5); a place in a file is an `offset` (E.17). Not `at`, `i`, `from`, `start`.
- **end**: the index a slice stops before, which it leaves out, `String.slice(text, index, end)` (E.5, E.20). Not `to`, `stop`.
- **count**: how many. Not `n`, `length`.
- **ms**: milliseconds (E.0 shape rule 8); a moment is a `time`. Not `wait`, `t`.
- **old, new**: what `replace` takes, in every module. Not `from`, `to`.
- **cause**: a fault's cause (report §7.3). Not `why`, `c`, `text`.
- **error**: an error a function answers, an `Io.Error` among them. Not `e`, `why`.
- **user**: the host's number for a user, the one a file belongs to, an `Fs.Entry`'s `user`, and the one the program runs as, `Os.user` (E.17, E.23). Not `owner`, which is the process a resource, a file, a socket or a table, belongs to, nor `uid`.
- **char**: a `Char`. Not `c`, `ch`.
- A mailbox type's constructors are requests, what the process is asked to do, and events, what it is told happened. A **request** constructor is the function it serves, `Read` for `read`, and where that is a prelude name, one every module uses unqualified (the language guide's §2.9), what it asks for, `ListEntries` for `list`; an **event** is in the past tense, `Resized`. Not `Recv`, `Measure`, `FarEnd` for a request, nor `Resize` for an event.
- A **mailbox type**, the type of the messages a process takes (the language guide's §4.1), is named for its process, with `Msg`: `CounterMsg`, `Os.ProgramMsg`.
- A prelude name, `Down`, `answer`, `kill`, means the prelude's thing in every module: the library binds it to nothing else.
