# Examples

Complete Ernest programs, each larger than a section of the guide can hold. They are listed in an order to read them, from the smallest to the largest. Each file begins with a comment that says what the program does, what to look at in it, and how to run it; the chapters named beside each are the guide's, [`guide/language.md`](../guide/language.md).

The commands assume `ern` on your `PATH`, the repository's `bin/` or an installation's, and are run from this directory. The tests of the repository build every program here, and run each that ends of itself and compare what it prints.

| Program | What it is | What it shows | Guide |
|---|---|---|---|
| [`hello.ern`](hello.ern) | the smallest program | `main`, and a mailbox that receives nothing | chapter 1 |
| [`tally.ern`](tally.ern) | lines, words and bytes of the files named, as `wc` counts them | the command line, files, errors as values, `<-`, a record with an operator of its own, an exit status | chapters 2, 3 and 6 |
| [`word_count.ern`](word_count.ern) | a word count written once over two kinds of map | an operations record filled from a module, a requirement the fill supplies, a derived order | chapter 7 |
| [`repl.ern`](repl.ern) | a read-evaluate-print loop for a small language | a lexer, a parser and an evaluator as pure functions; a process that bounds an evaluation, killed when it runs too long | chapters 3, 5 and 6 |
| [`services.ern`](services.ern) | three services under one supervisor | services reached by name, a restart that keeps the address and loses the state | chapter 6 |
| [`shout.ern`](shout.ern) | a TCP server and three clients in one program | a socket as a process, a process for each connection, reading until a line has arrived | chapters 4 and 8 |
| [`web_server.ern`](web_server.ern) | a web server with sessions; it serves until stopped | state shared by processes as a process that owns a `Map`, request and reply, an alarm | chapters 4 and 6 |
| [`file_sync.ern`](file_sync.ern) | two directories kept identical; it runs until stopped | two processes that learn each other's address from a message, the file system, a program's own tests | chapters 4 and 5 |
| [`typed_channels.ern`](typed_channels.ern) | a counter whose mailbox has one type, met with the doubts a reader may have of a typed channel | a send checked against the address's type, a reply answered once, an adapted address | chapters 4 and 5 |
| [`typed_channels_nodes.ern`](typed_channels_nodes.ern) | the same counter on a node of its own, found from another | a service that carries its message type, a call across nodes | chapter 8 |
| [`snake.ern`](snake.ern) | a snake game at a terminal | a world that is one value, ticks kept to a deadline, keys as messages, randomness passed as a seed | chapters 2, 4 and 5 |

`snake.ern` draws with the library `libs/ansi`, and is built and run with `--load-path ../build/libs/ansi`, as its first comment shows. The others need the standard library alone.
