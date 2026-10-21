# Style

What a program written in Ernest looks like: what a tool writes, what the report asks of a library's names, what the standard library does beyond that, and the names that recur in every program. The first is written for the writer by `ern format`, and the second binds a library (report Appendix E.0). The rest is what the standard library does, and a program that does the same reads like the library it calls.

## What a tool writes

`ern format` writes one layout and takes no option (report §11.6): a step of indentation is four spaces, a line fits within 100 columns where the layout can make it, a function's body begins on the line after its head's `=`, a `match`, a `receive` and a block run over lines, and a bracket that does not fit holds one item a line. `ern format src` lays every module under `src` out so, and `ern format --check src` names one that is not. A file's name is lowercase words joined by `_` (report §11.1), and the module's name is read from it, `kv_parser.ern` for `KvParser` (report §4.2).

## What the report asks of a library's names

Appendix E.0's shape rules 1 to 5, 7, 9 and 10 bind a library outside the standard library too: the subject comes first and callbacks last, so that `x |> f(a)` is `f(x, a)`; one verb per operation on each kind of type; a conversion named by the other type, `toInt`, `fromList`; a partial operation answering `Optional` and one with a cause `Either`; no `Bool` that chooses between two behaviors; and a name that is the word a reader who knows the operation predicts. Shape rule 6 says how a module is documented, which `ern doc` renders and the shell shows.

## What the standard library does

A value's name is camelCase and a type's PascalCase, `parseHeader`, `OrderedSet`, and a yes-or-no reads as the question, `isEmpty`. An exported function's parameters are named for their role, since the shell and `ern doc` show the signature: `List.filter(list, keep)`, `Fs.read(path, ms)`. A type variable is `a`, `b` for a value, `k` and `v` for a map's, `e` for an effect and `m` for a mailbox. A block holds more than one statement; one expression is written bare. The spelling is American English in names and messages alike, `color`, `initialize`; a name of the host's keeps its own.

## Glossary

The names that recur in a program, one for each concept, in every module. The report is the authority: a concept it names takes its name, and a citation such as E.5 names a section of its Appendix E. A name not here is the writer's.

- A function's **subject** is named for what it is, `list`, `text`, `map`, `set`, `bytes`, `path`, `table`, `process`.
- A **callback** is named for its role: `keep` for a predicate that keeps, `test` for one asked of each element, as `any`, `all`, `find`, `span` and `partition` ask it, `step` for a fold's or a try's (E.0 rule 2), `wrap` for what delivers a message (E.0 shape rule 8); `f` only where nothing more can be said.
- **acc**: what a fold or a recursion carries.
- **reply**: a `Reply`.
- **index**: a position in a sequence (E.2, E.5); a place in a file is an `offset` (E.17).
- **end**: the index a slice stops before, which it leaves out, `String.slice(text, index, end)` (E.5, E.20).
- **count**: how many.
- **ms**: milliseconds (E.23); a moment is a `time`.
- **old, new**: what `replace` takes, in every module.
- **cause**: a fault's cause (report §7.3).
- **error**: an error a function answers, an `Io.Error` among them.
- **user**: the host's number for a user, the one a file belongs to, an `Fs.Entry`'s `user`, and the one the program runs as, `Os.user` (E.17, E.23).
- **char**: a `Char`.
- A **request** constructor is the function it serves, `Read` for `read`, and where that is a prelude name, what it asks for, `ListEntries` for `list`; an **event** is in the past tense, `Resized`.
- A **mailbox type** is named for its process, with `Msg`: `CounterMsg`, `Os.ProgramMsg`.
- A prelude name, `Down`, `answer`, `kill`, means the prelude's thing in every module: the library binds it to nothing else.
