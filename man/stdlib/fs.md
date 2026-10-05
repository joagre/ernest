# Ernest module Fs

*Since 0.1.0.*

The file system through its system process, which reaches it
(report §8.2). Every function answers `Right` with what it read or did,
or `Left` with an `Io.Error`; the last argument is how many milliseconds
to wait, and a slower answer than that is `Left(Io.Timeout)`, which does
not undo the request: a write, a rename or a removal may still take
place. A path is a `Path`, which `Path` builds and takes apart; a
relative one names a file under `Os.workingDirectory`, and one that
holds U+0000 names none, `Left(Io.Invalid)`. A name that is not UTF-8
makes `list` answer `Left(Io.NotUtf8(name))`. `Io.Other` holds the host's
description of a reason it has no constructor for, `"illegal operation
on a directory"` or `"not a directory"` (report Appendix E.1).

## Examples

```ernest
{
    let _ <- Fs.write(Path("greeting.txt"), String.toUtf8("hello"), 5000);
    Either.map(Fs.read(Path("greeting.txt"), 5000), String.fromUtf8)
}
// => Right(Some("hello"))
```

```ernest
Fs.read(Path("no-such-file"), 5000)
// => Left(NotFound)
```

## See also

`Path` for building and reading a path, `Bytes` and `String.toUtf8` for
what a file holds.

## Fs.Kind

```ernest
type Kind = File | Directory | Link | Other
```

What a path names: a regular file, a directory, a symbolic link, or
something else, a named pipe, a device, or a socket (report Appendix
E.17).

### Examples

```ernest
Either.map(Fs.stat(Path("."), 5000), fn(entry) = entry.kind == Fs.Directory)
// => Right(true)
```

## Fs.Entry

```ernest
type Entry = Entry(path : Path, mtime : Int, size : Int, kind : Kind, mode : Int, user : Int)
```

What `Fs.stat` and `Fs.list` tell of a file: its path, its modification
time in milliseconds since the epoch, as `Clock.now`, read to the second
and so a multiple of 1000, its size in bytes, its kind, its permission
bits, as `Fs.setMode` takes them, and the host's number for the user it
belongs to, as `Os.user` is the program's (report Appendix E.17).

### Examples

```ernest
Fs.Entry(path = Path("a.txt"), mtime = 0, size = 5, kind = Fs.File, mode = 0o644, user = 0)
// => Entry(path = Path("a.txt"), mtime = 0, size = 5, kind = File, mode = 420, user = 0)
```

```ernest
{
    let _ <- Fs.write(Path("private.txt"), <<>>, 5000);
    let _ <- Fs.setMode(Path("private.txt"), 0o600, 5000);
    Either.map(Fs.stat(Path("private.txt"), 5000),
               fn(entry) = #(entry.mode == 0o600, entry.user == Os.user))
}
// => Right(#(true, true))
```

## Fs.read

```ernest
Fs.read(path : Path, ms : Int) : Either(Io.Error, Bytes) with m+
```

The file's octets.

## Fs.readRange

```ernest
Fs.readRange(path : Path, offset : Int, count : Int, ms : Int) : Either(Io.Error, Bytes) with m+
```

Up to `count` octets of the file from `offset`, fewer at its end and
none past it, the rest of the file never held: how a file too large to
hold whole is read, a part at a time. An offset or a count below 0 is
none (report §7.4).

### Examples

```ernest
{
    let _ <- Fs.write(Path("alphabet.txt"), String.toUtf8("abcdef"), 5000);
    let middle <- Fs.readRange(Path("alphabet.txt"), 1, 3, 5000);
    let end <- Fs.readRange(Path("alphabet.txt"), 4, 9, 5000);
    Right(#(middle, end))
}
// => Right(#(<<98, 99, 100>>, <<101, 102>>))
```

## Fs.write

```ernest
Fs.write(path : Path, bytes : Bytes, ms : Int) : Either(Io.Error, Unit) with m+
```

Writes the octets, creating the file or replacing what it held.

## Fs.append

```ernest
Fs.append(path : Path, bytes : Bytes, ms : Int) : Either(Io.Error, Unit) with m+
```

Writes the octets after what the file holds, creating it when it is not
there.

### Examples

```ernest
{
    let _ <- Fs.write(Path("log.txt"), String.toUtf8("a"), 5000);
    let _ <- Fs.append(Path("log.txt"), String.toUtf8("b"), 5000);
    Either.map(Fs.read(Path("log.txt"), 5000), String.fromUtf8)
}
// => Right(Some("ab"))
```

## Fs.list

```ernest
Fs.list(path : Path, ms : Int) : Either(Io.Error, List(Entry)) with m+
```

The entries of the directory, in unspecified order, each path the
directory's joined with the entry's name, and each described as it is:
a link is a `Link`, whatever it leads to.

### Examples

```ernest
{
    let _ <- Fs.makeDir(Path("shelf"), 5000);
    let _ <- Fs.write(Path("shelf/one.txt"), <<>>, 5000);
    Either.map(Fs.list(Path("shelf"), 5000),
               fn(entries) = List.filterMap(entries, fn(entry) = Path.name(entry.path)))
}
// => Right(["one.txt"])
```

```ernest
{
    let _ <- Fs.makeDir(Path("kinds"), 5000);
    let _ <- Fs.makeLink(Path("kinds/link"), Path("elsewhere"), 5000);
    Either.map(Fs.list(Path("kinds"), 5000),
               fn(entries) = List.map(entries, fn(entry) = entry.kind))
}
// => Right([Link])
```

## Fs.stat

```ernest
Fs.stat(path : Path, ms : Int) : Either(Io.Error, Entry) with m+
```

What the path leads to, its links followed: its size, its modification
time, and its kind.

### Examples

```ernest
{
    let _ <- Fs.write(Path("three.txt"), String.toUtf8("abc"), 5000);
    Either.map(Fs.stat(Path("three.txt"), 5000), fn(entry) = entry.size)
}
// => Right(3)
```

## Fs.makeDir

```ernest
Fs.makeDir(path : Path, ms : Int) : Either(Io.Error, Unit) with m+
```

Makes the directory and any parent it needs; a directory already there
is not an error.

## Fs.remove

```ernest
Fs.remove(path : Path, ms : Int) : Either(Io.Error, Unit) with m+
```

Removes a file, a link, or an empty directory; a link is removed, not
what it leads to.

### Examples

```ernest
{
    let _ <- Fs.write(Path("gone.txt"), <<>>, 5000);
    let _ <- Fs.remove(Path("gone.txt"), 5000);
    Fs.read(Path("gone.txt"), 5000)
}
// => Left(NotFound)
```

## Fs.rename

```ernest
Fs.rename(source : Path, destination : Path, ms : Int) : Either(Io.Error, Unit) with m+
```

Renames the first path to the second.

### Examples

```ernest
{
    let _ <- Fs.write(Path("before.txt"), String.toUtf8("x"), 5000);
    let _ <- Fs.rename(Path("before.txt"), Path("after.txt"), 5000);
    Either.map(Fs.read(Path("after.txt"), 5000), String.fromUtf8)
}
// => Right(Some("x"))
```

## Fs.copy

```ernest
Fs.copy(source : Path, destination : Path, ms : Int) : Either(Io.Error, Unit) with m+
```

Copies the file at the first path to the second, replacing what is
there.

### Examples

```ernest
{
    let _ <- Fs.write(Path("source.txt"), String.toUtf8("y"), 5000);
    let _ <- Fs.copy(Path("source.txt"), Path("copy.txt"), 5000);
    Either.map(Fs.read(Path("copy.txt"), 5000), String.fromUtf8)
}
// => Right(Some("y"))
```

## Fs.makeLink

```ernest
Fs.makeLink(path : Path, target : Path, ms : Int) : Either(Io.Error, Unit) with m+
```

Makes a symbolic link at the first path that leads to the second, which
is kept as it is written and may name nothing. A first path that names
something is `Left(Exists)`.

### Examples

```ernest
{
    let _ <- Fs.write(Path("target.txt"), String.toUtf8("t"), 5000);
    let _ <- Fs.makeLink(Path("pointer"), Path("target.txt"), 5000);
    Either.map(Fs.read(Path("pointer"), 5000), String.fromUtf8)
}
// => Right(Some("t"))
```

## Fs.makeHardLink

```ernest
Fs.makeHardLink(path : Path, target : Path, ms : Int) : Either(Io.Error, Unit) with m+
```

*Since 0.2.0.*

Makes a hard link at the first path to the regular file the second
names: a second name for the file, which outlives the first. A first
path that names something is `Left(Exists)`, and a second that names
anything but a regular file, a link among them, is `Left(NotAFile)`.

### Examples

```ernest
{
    let _ <- Fs.write(Path("original.txt"), String.toUtf8("o"), 5000);
    let _ <- Fs.makeHardLink(Path("twin.txt"), Path("original.txt"), 5000);
    let _ <- Fs.remove(Path("original.txt"), 5000);
    Either.map(Fs.read(Path("twin.txt"), 5000), String.fromUtf8)
}
// => Right(Some("o"))
```

## Fs.readLink

```ernest
Fs.readLink(path : Path, ms : Int) : Either(Io.Error, Optional(Path)) with m+
```

The path a symbolic link holds, as it was written, or `None` where the
path names something that is not a link. A link whose target is not
UTF-8 is `Left(NotUtf8(target))`, the target's bytes.

### Examples

```ernest
{
    let _ <- Fs.makeLink(Path("sign"), Path("somewhere"), 5000);
    let _ <- Fs.write(Path("plain.txt"), <<>>, 5000);
    let target <- Fs.readLink(Path("sign"), 5000);
    let plain <- Fs.readLink(Path("plain.txt"), 5000);
    Right(#(target, plain))
}
// => Right(#(Some(Path("somewhere")), None))
```

## Fs.makeFile

```ernest
Fs.makeFile(path : Path, bytes : Bytes, ms : Int) : Either(Io.Error, Unit) with m+
```

*Since 0.2.0.*

Writes a new file, or none where the path names something already,
which is `Left(Exists)`: the one way to claim a name, as a lock
file or a temporary file needs.

### Examples

```ernest
{
    let first = Fs.makeFile(Path("claimed.txt"), String.toUtf8("mine"), 5000);
    let second = Fs.makeFile(Path("claimed.txt"), String.toUtf8("yours"), 5000);
    #(first, second)
}
// => #(Right(Unit), Left(Exists))
```

## Fs.removeAll

```ernest
Fs.removeAll(path : Path, ms : Int) : Either(Io.Error, Unit) with m+
```

Removes a directory and everything under it, or a file or a link. A link
is removed and not followed, wherever it stands, so what it leads to is
left, even where another process puts it in a directory's place while
the removal runs. It waits the milliseconds given once, for the whole
removal.

### Errors

Where the runtime's helper fails, the caller faults with `Fault("the
runtime's helper ern_exec failed")`, as `Os.start`'s does.

### Examples

```ernest
{
    let _ <- Fs.makeDir(Path("tree/branch"), 5000);
    let _ <- Fs.write(Path("tree/branch/leaf.txt"), <<>>, 5000);
    let _ <- Fs.removeAll(Path("tree"), 5000);
    Right(Either.isLeft(Fs.stat(Path("tree"), 5000)))
}
// => Right(true)
```

## Fs.setModified

```ernest
Fs.setModified(path : Path, mtime : Int, ms : Int) : Either(Io.Error, Unit) with m+
```

Sets the modification time, in milliseconds since the epoch as
`Clock.now` gives it, kept to the second as the file system keeps it.

### Examples

```ernest
{
    let _ <- Fs.write(Path("dated.txt"), <<>>, 5000);
    let _ <- Fs.setModified(Path("dated.txt"), 86400000, 5000);
    Either.map(Fs.stat(Path("dated.txt"), 5000), fn(entry) = entry.mtime)
}
// => Right(86400000)
```

## Fs.setMode

```ernest
Fs.setMode(path : Path, mode : Int, ms : Int) : Either(Io.Error, Unit) with m+
```

*Since 0.2.0.*

Sets the permission bits of a file or a directory to the mode, as the
host writes them: `0o600` is its owner's alone to read and write, and a
directory made `0o700` before a file is written in it keeps the file
from others as it is written. A mode outside 0 to `0o7777`, or with the
bit `0o1000`, which the host does not write, is `Left(Invalid)`.

### Examples

```ernest
{
    let _ <- Fs.makeDir(Path("own"), 5000);
    Fs.setMode(Path("own"), 0o700, 5000)
}
// => Right(Unit)
```

---

Generated by ern 0.3.0 from fs.ern.
