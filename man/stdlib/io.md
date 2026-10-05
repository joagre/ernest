# Ernest module Io

*Since 0.1.0.*

Output to standard output and standard error, and input from standard
input, through the module's system references `stdout`, `stderr`, and
`stdin` (report §8.2). Each is a system process, so printing is a
message and carries the caller's mailbox effect; pure code cannot print.
A write returns once its stream has taken the bytes, and waits while the
stream is behind, so a program is held to the pace of what reads it.
`Error` is the error of every system module.

## Examples

```ernest
Io.println("hello, world")
// => Unit
```

```ernest
Io.debug(Optional.map(Some(2), fn(n) = n * 10))
// => Some(20)
```

## See also

`String` for building what is printed, `Terminal` for the keys and the
screen themselves.

## Io.Error

```ernest
type Error =
    NotFound
  | Denied
  | Refused
  | Closed
  | Timeout
  | NotATerminal
  | NotAFile
  | Exists
  | NotUtf8(Bytes)
  | Invalid
  | Other(String)
```

Why an operation of a system module found no answer: `NotFound`, the
file or the host is not there; `Denied`, access was refused; `Refused`
and `Closed`, the connection was refused or has closed; `Timeout`, the
time ran out; `NotATerminal`, the standard stream an operation needs is
not a terminal, standard input for `Terminal.subscribe` and standard
output, or a terminal with no rows or no columns, for `Terminal.size`;
`NotAFile`, a path names something other than a regular file; `Exists`,
a path names something where nothing may stand; `NotUtf8(bytes)`, text
that is not UTF-8, a name or a link's target among them, its bytes
carried; `Invalid`, an argument the host cannot take whole, one that
holds U+0000, a port out of range, a mode with bits the host does not
write, or a time it cannot hold; and `Other(text)`, another reason as
the host describes it, `"address already in use"`, or as the host writes
it where it has no description (report Appendix E.1).

### Examples

```ernest
match Fs.read(Path("/no/such/file"), 1000) {
    Left(Io.NotFound) -> "missing"
  | Left(_) -> "failed"
  | Right(_) -> "read"
}
```

## Io.print

```ernest
Io.print(text : String) : Unit with m+
```

The string to standard output, as it is, without a line feed.

### Examples

```ernest
Io.print("half ");
Io.println("and half")
// => Unit
```

## Io.println

```ernest
Io.println(text : String) : Unit with m+
```

The string to standard output, with a line feed after it.

## Io.printError

```ernest
Io.printError(text : String) : Unit with m+
```

The string to standard error, as it is, without a line feed. Standard
error is a second sink, for a program whose output something else reads;
it is not a level of severity.

### Examples

```ernest
Io.printError("cannot ");
Io.printlnError("open the file")
// => Unit
```

## Io.printlnError

```ernest
Io.printlnError(text : String) : Unit with m+
```

The string to standard error, with a line feed after it.

## Io.readLine

```ernest
Io.readLine() : Optional(String) with m+
```

The next line from standard input, without its line feed and without
one carriage return before it, or `None` at end of input. A last line
without a line feed is a line. Standard input is read as UTF-8. A
program reads lines or subscribes to keys, not both (report §8.2).

### Errors

A line that is not UTF-8 faults the caller with `Fault("the standard
input is not UTF-8")`, and a read after the program subscribed to the
keys with `Fault("the terminal is already read as keys")` (report §7.4).

### Examples

```ernest
Io.readLine()
```

## Io.read

```ernest
Io.read() : Optional(Bytes) with m+
```

What has arrived on standard input, at least one byte, or `None` at end
of input. Lines and bytes are read from one stream, so a read takes up
where the line before it stopped (report §8.2).

### Errors

A read after the program subscribed to the keys faults the caller with
`Fault("the terminal is already read as keys")` (report §7.4).

### Examples

```ernest
Io.read()
```

## Io.write

```ernest
Io.write(bytes : Bytes) : Unit with m+
```

The bytes to standard output, as they are.

### Examples

```ernest
Io.write(<<104, 105, 10>>)
// => Unit
```

## Io.writeError

```ernest
Io.writeError(bytes : Bytes) : Unit with m+
```

*Since 0.2.0.*

The bytes to standard error, as they are, `write`'s twin as
`printError` is `print`'s.

### Examples

```ernest
Io.writeError(<<104, 105, 10>>)
// => Unit
```

## Io.show

```ernest
Io.show(value : a!) : String needs a.show
```

The value as Ernest writes it, by its type at the call: a value as its
literal or construction is written, a named constructor's fields in
declared order (report §3.5), an address as the process behind it,
`<address 84>`, and a function as `<function>`. It needs `a.show`, which
a call at a known type supplies without writing it; in a generic
function, `needs a.show` lets it write `a` and any type built from it,
`List(a)` among them, and a type variable no requirement names is a type
error (report §9.4, Appendix E.1). It is pure.

### Examples

```ernest
Io.show(#('a', Some([1, 2]), <<104, 105>>))
// => "#('a', Some([1, 2]), <<104, 105>>)"
```

## Io.debug

```ernest
Io.debug(value : a!) : a! with m+ needs a.show
```

The value printed as `Io.show` writes it, with a line feed, to
standard error, and returned, so it wraps an expression where it
stands: `let n = Io.debug(f(x))`. It needs `a.show`, as `Io.show`
does, and writes the same types.

---

Generated by ern 0.3.0 from io.ern.
