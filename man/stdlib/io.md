# Ernest module Io

*Since 0.1.0.*

Printing, and reading standard input.

Use it to write text to standard output or standard error, to read standard
input a line or a few bytes at a time, and to turn a value into text with
`show`.

**It needs a process.** Standard output, standard error and standard input
are each a system process of the runtime, so printing is a message: a
function that prints carries a mailbox effect, `with m`, and pure code
cannot print. `show` alone is pure.

**Pace.** A write returns once its stream has taken the bytes, and waits
while the stream is behind, so a program is held to the pace of what reads
it.

**Errors.** `Error` is the error every system module answers with in a
`Left`, `Fs`, `Tcp` and `Os` among them.

## Examples

Prints `hello, world` and a line feed on standard output:

```ernest
Io.println("hello, world")
// => Unit
```

`debug` writes a value to standard error and answers it, so it wraps an
expression where it stands:

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

Why an operation of a system module failed. Every system module answers
`Left` with one of these:

- `NotFound`: the file or the host is not there.
- `Denied`: access was refused.
- `Refused`, `Closed`: the connection was refused, or has closed.
- `Timeout`: the time given ran out.
- `NotATerminal`: a standard stream an operation needs is not a terminal, or
  is one with no rows or no columns.
- `NotAFile`: a path names something other than a regular file.
- `Exists`: the path already names something, where the operation needs it
  free, as when a directory is made that is there.
- `NotUtf8(bytes)`: text that is not UTF-8, a name or a link's target among
  them, with its bytes.
- `Invalid`: an argument the host cannot take, one that holds U+0000, a port
  out of range or a time it cannot hold among them.
- `Other(text)`: another reason, in the host's words, `"address already in
  use"`.

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

Writes the string to standard output, as it is, without a line feed.

### Examples

Prints `half and half` on one line, since `print` adds no line feed:

```ernest
{
    Io.print("half ");
    Io.println("and half")
}
// => Unit
```

## Io.println

```ernest
Io.println(text : String) : Unit with m+
```

Writes the string to standard output, and a line feed after it.

## Io.printError

```ernest
Io.printError(text : String) : Unit with m+
```

Writes the string to standard error, as it is, without a line feed. Standard
error is a second output stream, for messages to the person running the
program, kept apart from the output another program reads. Writing there
marks nothing as an error.

### Examples

Prints `cannot open the file` on one line of standard error:

```ernest
{
    Io.printError("cannot ");
    Io.printlnError("open the file")
}
// => Unit
```

## Io.printlnError

```ernest
Io.printlnError(text : String) : Unit with m+
```

Writes the string to standard error, and a line feed after it.

## Io.readLine

```ernest
Io.readLine() : Optional(String) with m+
```

The next line of standard input, without its line feed, or `None` at the end
of the input. A carriage return before the line feed is dropped too, and a
last line without a line feed is a line. Standard input is read as UTF-8. A
program reads lines or subscribes to keys with `Terminal`, not both (report
§8.2).

### Errors

Faults where a line is not UTF-8, with the cause `the standard input is not
UTF-8`; input that may not be text is read with `read`. Faults after the
program has subscribed to the keys, with the cause `the terminal is already
read as keys`.

### Examples

One line read and echoed, or the end of the input noticed:

```ernest
match Io.readLine() {
    Some(line) -> Io.println("read: " <> line)
  | None -> Io.println("no more input")
}
```

## Io.read

```ernest
Io.read() : Optional(Bytes) with m+
```

What has arrived on standard input, at least one byte, or `None` at the end
of the input. Lines and bytes are read from one stream, so a read takes up
where the line before it stopped (report §8.2).

### Errors

Faults after the program has subscribed to the keys, with the cause `the
terminal is already read as keys`.

### Examples

How many bytes the next read brought, 0 at the end of the input:

```ernest
match Io.read() {
    Some(bytes) -> Bytes.size(bytes)
  | None -> 0
}
```

## Io.write

```ernest
Io.write(bytes : Bytes) : Unit with m+
```

Writes the bytes to standard output, as they are.

### Examples

Prints `hi` and a line feed, the bytes 104, 105 and 10:

```ernest
Io.write(<<104, 105, 10>>)
// => Unit
```

## Io.writeError

```ernest
Io.writeError(bytes : Bytes) : Unit with m+
```

*Since 0.2.0.*

Writes the bytes to standard error, as they are, as `printError` writes a
string.

### Examples

Prints `hi` and a line feed on standard error:

```ernest
Io.writeError(<<104, 105, 10>>)
// => Unit
```

## Io.show

```ernest
Io.show(value : a!) : String needs a.show
```

The value as Ernest writes it: a number, a string or a constructor as its
literal is written, `Some("a")`, a named constructor's fields in their
declared order, an address as `<address 84>`, and a function as
`<function>`. It is pure.

`show` writes a value by its type, which the compiler knows at a call:
`Io.show([1, 2])` writes a `List(Int)`. In a function generic in a type `a`,
the function declares `needs a.show`, and can then write `a` and any type
built from it, `List(a)` among them; without it, showing an `a` is a type
error (report §9.4).

### Examples

```ernest
Io.show(#('a', Some([1, 2]), <<104, 105>>))
// => "#('a', Some([1, 2]), <<104, 105>>)"
```

## Io.debug

```ernest
Io.debug(value : a!) : a! with m+ needs a.show
```

Writes the value to standard error as `show` writes it, with a line feed,
and answers the value, so it wraps an expression where it stands: `let n =
Io.debug(f(x))`. Like `show`, a generic function needs `a.show` to use it.

---

Generated by ern 0.3.1 from io.ern.
