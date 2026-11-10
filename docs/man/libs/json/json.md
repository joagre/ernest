# Ernest module Json

*Since 0.4.0.*

JSON text, read into a value and written from one, as RFC 8259 defines
it, by the host's `json` module.

Use it where a program reads or writes JSON, a file of settings or what
a web service sends: `parse` reads a text into a `Value`, `format` writes
a `Value` as text laid out over lines, and `encode` writes it on one line.

The library stands on every job's load path, so a program names it with
no option (report Appendix G).

**Numbers.** A number written with neither a fraction nor an exponent is
an `Integer`, of any size the host can hold, and one written with either
is a `Real`: `1` is `Integer(1)`, and `1.0` and `1e0` are `Real(1.0)`. A
`Real` nearer to zero than a `Float` can hold is `0.0`, and so is `-0.0`,
since a `Float` has no negative zero (report §3.1). An integer longer than
the host can hold, and a real larger than a `Float` can hold, are not
read.

**Objects.** An object is a `Map` from its members' names to their
values. Where a text names a member twice, the last is kept, as
`Map.fromList` keeps a later pair. `format` and `encode` write the
members in the order of their names' code points, an order of this
library's, which the host's `json` module leaves to its caller.

**Errors.** A text that holds no value is an `Error`: the text ends
inside its value, a byte stands where none may, or a sequence writes no
character or a number the host cannot hold. A byte and a sequence carry
their `Position`, the line and the column they begin at, counted as a
diagnostic counts them (report §11.5).

**Reading back.** `parse` reads what `format` and `encode` write as the
value it was written from.

## Examples

A member of an object read:

```ernest
match Json.parse("{\"name\": \"desk\", \"port\": 4001}") {
    Right(Json.Object(members)) -> Map.get(members, "port")
  | _ -> None
}
// => Some(Json.Integer(4001))
```

An object written:

```ernest
Json.format(Json.Object(Map.fromList([#("port", Json.Integer(4001)),
                                      #("name", Json.Text("desk"))])))
// => "{\n  \"name\": \"desk\",\n  \"port\": 4001\n}\n"
```

## See also

`Map` for an object's members, `String` for the text a value is read from
and written to.

## Json.Value

```ernest
type Value =
    Null
  | Boolean(Bool)
  | Integer(Int)
  | Real(Float)
  | Text(String)
  | Array(List(Value))
  | Object(Map(String, Value))
```

A JSON value: `null`, `true` or `false`, a number, a string, an array or
an object.

### Examples

```ernest
Json.parse("[null, true, 2]")
// => Right(Json.Array([Json.Null, Json.Boolean(true), Json.Integer(2)]))
```

```ernest
Json.parse("[2.5, \"x\", []]")
// => Right(Json.Array([Json.Real(2.5), Json.Text("x"), Json.Array([])]))
```

## Json.Position

```ernest
type Position = Position(line : Int, column : Int)
```

*Since 0.9.0.*

Where an error begins: its line and its column, counted as a diagnostic
counts them (report §11.5), from 1, a line ending at a line feed and a
column a code point.

### Examples

```ernest
Json.parse("{\n  \"é\": x\n}")
// => Left(Json.UnexpectedByte(byte = 120, at = Json.Position(line = 2, column = 8)))
```

## Json.Error

```ernest
type Error =
    UnexpectedEnd
  | UnexpectedByte(byte : Int, at : Position)
  | UnexpectedSequence(text : String, at : Position)
```

Why a text holds no JSON value, as the host's `json` finds it, and where.
`UnexpectedEnd` is a text that ends inside its value or holds none.
`UnexpectedByte` is a byte that cannot stand where it is, the first of
its character's, a second value, a comma before a closing bracket, a
character no value begins with, or the first that differs from the
`true`, `false` or `null` it breaks off, and its position.

`UnexpectedSequence` is an escape that writes no character, a
surrogate's escape without its pair's and one broken off before its four
digits among them, or a number the host cannot hold, an integer too long
or a real larger than a `Float` can hold, and its position.

The sequence is the host's spelling of it: an escape as the text writes
it, up to the byte that breaks it where one does, `\u12` of `"\u12"`;
an integer as the text writes it, and a real with a fraction too; but a
real with an exponent and no fraction with `.0` before the exponent and
its `e` in lower case, `1.0e400` for `1E400`.

### Examples

```ernest
Json.parse("[1, 2,]")
// => Left(Json.UnexpectedByte(byte = 93, at = Json.Position(line = 1, column = 7)))
```

A real larger than a `Float` can hold, in the host's spelling:

```ernest
Json.parse("[1E400]")
// => Left(Json.UnexpectedSequence(text = "1.0e400", at = Json.Position(line = 1, column = 2)))
```

## Json.parse

```ernest
Json.parse(text : String) : Either(Error, Value)
```

The value `text` writes, or why it writes none. White space may stand
before the value and after it, and nothing else may.

### Examples

```ernest
Json.parse(" 4001 ")
// => Right(Json.Integer(4001))
```

```ernest
Json.parse("4001 4002")
// => Left(Json.UnexpectedByte(byte = 52, at = Json.Position(line = 1, column = 6)))
```

## Json.format

```ernest
Json.format(value : Value) : String
```

`value` as JSON text, laid out over lines as the host's `json:format`
lays it out, two spaces to a level, an object's members in the order of
their names' code points, and ending in a line feed. In a text it writes
`"` and `\` as `\"` and `\\`; a line feed, a carriage return, a tab, a
backspace and a form feed as `\n`, `\r`, `\t`, `\b` and `\f`; every
other character below U+0020 as `\u` and four uppercase hexadecimal
digits; and every other character as itself, U+007F and `/` among them.

### Examples

```ernest
Json.format(Json.Array([Json.Integer(1), Json.Null]))
// => "[1,null]\n"
```

A text's characters, U+0000 escaped and U+007F not:

```ernest
Json.format(Json.Text("a\u{0}\u{7f}\t/"))
// => "\"a\\u0000\u{7F}\\t/\"\n"
```

## Json.encode

```ernest
Json.encode(value : Value) : String
```

*Since 0.10.0.*

`value` as JSON text on one line, as the host's `json:encode` writes it,
with no white space between its parts and no line feed after it. An
object's members come in the order of their names' code points, and a
text is written as `format` writes it.

### Examples

```ernest
Json.encode(Json.Object(Map.fromList([#("tags", Json.Array([Json.Text("a"), Json.Null])),
                                      #("port", Json.Integer(4001))])))
// => "{\"port\":4001,\"tags\":[\"a\",null]}"
```

---

Generated by ern 0.11.0-dev from src/libs/json/json.ern.
