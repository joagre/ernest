# ets

Tables of the runtime, a shim over Erlang's `ets`: `Ets.new`, `insert`, `lookup`, `member`,
`delete`, `size`, `clear`, `drop`, and `toList`. Its documentation is in `ets.ern`, and
`ernc --doc libs/ets/ets.ern` renders it.

A table is state that every process holding it reads and writes. The standard library keeps
report §10's promise that processes share no memory, so this is a library, which a program
adds itself. Appendix D of the report writes it out as its example of a foreign library.

`make` compiles it into `build/libs/ets`. A program is compiled and run with that root on its
load path:

```
ernc --load-path build/libs/ets --out-dir build/app app
ern --load-path build/libs/ets build/app/main.erc
```
