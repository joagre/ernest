# Examples

Complete Ernest programs, each larger than a section of the guide can hold. They are listed by topic, not by size: a program's first line, values and failure as a value, processes and a supervisor, sockets and files, nodes, and a game last. Each file begins with a comment that says what the program does, what to look at in it, and how to run it; the chapters named beside each are the guide's, [`guide/language.md`](../guide/language.md).

The commands assume `ern` on your `PATH`, the repository's `bin/` or an installation's, and are run from this directory. The tests of the repository build every program here, run each that ends of itself and compare what it prints, and connect to each server and read its answer.

An installation holds this directory as `share/doc/ernest/examples/` under its prefix. `ern build` writes the compiled module beside its source, so copy the directory to one of your own first.

## Run one

Two commands run most programs here: `ern build` compiles a program to a file beside it, and `ern run` runs that file, with the program's arguments after it.

```console
$ ern build hello.ern
$ ern run hello.erc
hello, world
$ ern build tally.ern
$ printf 'one two\nthree\n' > words.txt
$ ern run tally.erc words.txt
2 3 14 words.txt
2 3 14 total
```

`ern run snake.erc` plays the snake game at your terminal, `ern run shout.erc` serves until you stop it, and `ern test file_sync.erc` runs a program's own tests. `typed_channels_nodes.ern` and `upgrade/` run as nodes, with the configuration directories their first comments make. Each program's first comment says how it is run and what to look at in it.

## The programs

| Program | What it is | What it shows | Guide |
|---|---|---|---|
| [`hello.ern`](hello.ern) | the smallest program | `main`, and a mailbox that receives nothing | chapter 1 |
| [`tally.ern`](tally.ern) | lines, words and bytes of the files named, as `wc` counts them | the command line, files, errors as values, `<-`, a record with an operator of its own, an exit status | chapters 2, 3 and 6 |
| [`word_count.ern`](word_count.ern) | the words of the file named, counted by one function over two kinds of map | an operations record filled from a module, a requirement the fill supplies, a derived order | chapter 7 |
| [`repl.ern`](repl.ern) | a read-evaluate-print loop for a small language | a lexer, a parser and an evaluator as pure functions; a process that bounds an evaluation, killed when it runs too long | chapters 3, 5 and 6 |
| [`services.ern`](services.ern) | a stock kept by three services under one supervisor, told what to do on standard input | services reached by name, a fault the input causes, a restart that keeps the address and loses the state | chapter 6 |
| [`shout.ern`](shout.ern) | a TCP server that answers each line in capitals; it serves until stopped | a socket as a process, a process for each connection, reading until a line has arrived | chapters 4 and 8 |
| [`web_server.ern`](web_server.ern) | a web server with sessions; it serves until stopped | state shared by processes as a process that owns a `Map`, request and reply, an alarm | chapters 4 and 6 |
| [`file_sync.ern`](file_sync.ern) | two directories kept identical; it runs until stopped | two processes that learn each other's address from a message, the file system, a program's own tests | chapters 4 and 5 |
| [`typed_channels_nodes.ern`](typed_channels_nodes.ern) | a counter on a node of its own, found from another | a service that carries its message type, a call across nodes | chapter 8 |
| [`upgrade/`](upgrade/) | a counter's two builds, `v1/` and `v2/`, the second moving the first's running counters to new code, here and on every peer | one module built twice, its unchanged definitions one hash in both; the processes that run a function, listed by `Code.running`, each sent its `Upgrade`; a spawn that carries the code a peer lacks | chapters 4 and 8 |
| [`snake.ern`](snake.ern) | a snake game at a terminal | a world that is one value, ticks kept to a deadline, keys as messages, randomness passed as a seed | chapters 2, 4 and 5 |

`snake.ern` draws with the library `libs/ansi`, which is on the load path already, as every library of the toolchain's is; the others need the standard library alone. `upgrade/` is one module, `Counter`, in two directories, and each is built as a directory, `ern build upgrade/v1`, as its first comment shows.
