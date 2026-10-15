# Ernest module Path

*Since 0.1.0.*

File system paths: building them, and taking them apart.

A `Path` is a name for a file or a directory, `Path("/etc/hosts")` or
`Path("notes.txt")`, and what `Fs` takes. A path is built from text with the
constructor `Path`, and `toString` gives the text back. Join two with `<>`:
`Path("logs") <> Path("today.txt")`.

This module reads a path's text alone and never asks the file system:
`parent`, `name` and `extension` say nothing of whether the file is there.

**Segments.** A path is a list of segments between its separators, `/` on
the host. An absolute path begins at a root, which is its first segment:
`split(Path("/etc/hosts"))` is `["/", "etc", "hosts"]`. A relative path
names a file under the program's working directory (`Os.workingDirectory`).

## Examples

Two paths joined:

```ernest
Path.toString(Path("/etc") <> Path("hosts"))
// => "/etc/hosts"
```

A path's last part, and its extension:

```ernest
#(Path.name(Path("/tmp/report.txt")), Path.extension(Path("/tmp/report.txt")))
// => #(Some("report.txt"), Some("txt"))
```

## See also

`Fs` for reading and writing what a path names, `String` for the text.

## Path.<>

```ernest
Path.<>(path : Path, under : Path) : Path
```

*Since 0.2.0.*

`under` placed below `path`: the segments of both, joined, so `Path("a//b")
<> Path("c")` is `Path("a/b/c")`. An absolute `under` is answered as it was
written, so a name from outside the program can leave `path`; `Path.under`
refuses such a name.

### Examples

```ernest
#(Path.toString(Path("/etc/") <> Path("hosts")), Path.toString(Path("/etc") <> Path("/var")))
// => #("/etc/hosts", "/var")
```

## Path.join

```ernest
Path.join(segments : List(String)) : Path
```

The path of those segments, the inverse of `split`. A root first stays a
root, and one separator stands between the others.

### Examples

```ernest
Path.toString(Path.join(Path.split(Path("/etc//hosts"))))
// => "/etc/hosts"
```

## Path.split

```ernest
Path.split(path : Path) : List(String)
```

The path's segments, none of them empty. An absolute path's first segment is
its root.

### Examples

```ernest
Path.split(Path("/etc/hosts"))
// => ["/", "etc", "hosts"]
```

## Path.parent

```ernest
Path.parent(path : Path) : Optional(Path)
```

The path without its last segment, or `None` for a bare name, which has no
parent written, and for the root.

### Examples

```ernest
#(Path.parent(Path("/etc/hosts")), Path.parent(Path("hosts")))
// => #(Some(Path("/etc")), None)
```

```ernest
#(Path.parent(Path("a/b/")), Path.parent(Path("./x")), Path.parent(Path("/")))
// => #(Some(Path("a")), Some(Path(".")), None)
```

## Path.name

```ernest
Path.name(path : Path) : Optional(String)
```

The path's last segment, or `None` for the root, which has none.

### Examples

```ernest
#(Path.name(Path("a/b.txt")), Path.name(Path("/")))
// => #(Some("b.txt"), None)
```

## Path.extension

```ernest
Path.extension(path : Path) : Optional(String)
```

What follows the last `.` of the path's name, without the dot, or `None`
where the name has none. A dot that begins the name begins no extension, so
`.bashrc`, `.` and `..` have none.

## Path.withExtension

```ernest
Path.withExtension(path : Path, extension : String) : Path
```

The path with `extension` in place of any it had, after a dot; an empty
`extension` leaves the dot. The rest of the path stays as it was written.
The root, `.` and `..` have no name to extend, and are answered as they are.

### Examples

```ernest
#(Path.toString(Path.withExtension(Path("a/b.txt"), "md")),
  Path.toString(Path.withExtension(Path("a/b"), "")))
// => #("a/b.md", "a/b.")
```

## Path.withoutExtension

```ernest
Path.withoutExtension(path : Path) : Path
```

*Since 0.2.0.*

The path without its extension, the rest as it was written. The root, `.`
and `..` have no name to shorten, and are answered as they are.

### Examples

```ernest
#(Path.toString(Path.withoutExtension(Path("a/b.txt"))),
  Path.toString(Path.withoutExtension(Path(".bashrc"))))
// => #("a/b", ".bashrc")
```

## Path.under

```ernest
Path.under(root : Path, path : Path) : Optional(Path)
```

*Since 0.3.0.*

`path` placed below `root`, or `None` where it could name something outside
it: where `path` is absolute or empty, or has a `.` or `..` segment. Use it
for a name that comes from outside the program, a request or a file a peer
sends, where `<>` would let it leave `root`. It reads the text alone: a link
under `root` may still lead out, which the file system decides.

### Examples

```ernest
#(Optional.map(Path.under(Path("/srv"), Path("site/index.html")), Path.toString),
  Path.under(Path("/srv"), Path("../etc")),
  Path.under(Path("/srv"), Path("/etc")))
// => #(Some("/srv/site/index.html"), None, None)
```

## Path.isAbsolute

```ernest
Path.isAbsolute(path : Path) : Bool
```

`true` when the path begins at a root, `/` on the host.

### Examples

```ernest
#(Path.isAbsolute(Path("/etc")), Path.isAbsolute(Path("etc")))
// => #(true, false)
```

## Path.toString

```ernest
Path.toString(path : Path) : String
```

The path's text, as it was written.

---

Generated by ern 0.3.1 from path.ern.
