# Ernest module Bytes

*Since 0.1.0.*

Sequences of bytes, as a file or a socket holds them.

Use `Bytes` for data that is not text: what `Fs.read` and `Tcp.read` answer,
and what a binary format is made of. For text use a `String`, and convert
with `String.toUtf8` and `String.fromUtf8`.

A `Bytes` is built and taken apart with bitstrings, which the language
provides: `<<1, 2, 3>>`, and in a pattern `<<length:size(16), rest:bytes>>`
reads a 16-bit number and the bytes after it (report §5.11). This module
holds the operations bitstrings do not: searching, splitting and the
conversions. A `Bytes` is a value, which no function here changes.

`toList` gives the bytes as `Int`s, each from 0 to 255, and `fromList`
builds a `Bytes` from them.

## Examples

Two byte sequences joined with `<>`, and the bytes as numbers:

```ernest
Bytes.toList(<<104, 105>> <> <<33>>)
// => [104, 105, 33]
```

Bytes made from numbers, each from 0 to 255:

```ernest
Bytes.fromList([104, 105])
// => Some(<<104, 105>>)
```

## See also

`String.toUtf8` and `String.fromUtf8` for text, `Int` for the octets.

## Bytes.<>

```ernest
Bytes.<>(left : Bytes, right : Bytes) : Bytes
```

The bytes of the first, then those of the second.

## Bytes.size

```ernest
Bytes.size(bytes : Bytes) : Int
```

The number of bytes.

### Examples

```ernest
#(Bytes.size(<<1, 2, 3>>), Bytes.isEmpty(<<>>))
// => #(3, true)
```

## Bytes.isEmpty

```ernest
Bytes.isEmpty(bytes : Bytes) : Bool
```

`true` for the empty `Bytes`, `<<>>`.

## Bytes.get

```ernest
Bytes.get(bytes : Bytes, index : Int) : Optional(Int)
```

The byte at `index`, counting from 0, as an `Int` from 0 to 255, or `None`
where there is no byte there: past the end, or at an index below 0.

### Examples

```ernest
#(Bytes.get(<<7, 8>>, 1), Bytes.get(<<7, 8>>, 2))
// => #(Some(8), None)
```

## Bytes.slice

```ernest
Bytes.slice(bytes : Bytes, index : Int, count : Int) : Bytes
```

The `count` bytes from `index`, or as many as there are. An `index` or a
`count` below 0 counts as 0.

### Examples

```ernest
#(Bytes.slice(<<1, 2, 3>>, 1, 5), Bytes.slice(<<1, 2, 3>>, -1, 2))
// => #(<<2, 3>>, <<1, 2>>)
```

## Bytes.toList

```ernest
Bytes.toList(bytes : Bytes) : List(Int)
```

The bytes in order, each an `Int` from 0 to 255.

## Bytes.fromList

```ernest
Bytes.fromList(octets : List(Int)) : Optional(Bytes)
```

The `Bytes` of those numbers, or `None` where one is outside 0 to 255.

### Examples

```ernest
Bytes.fromList([256])
// => None
```

## Bytes.contains

```ernest
Bytes.contains(bytes : Bytes, part : Bytes) : Bool
```

`true` when `part` occurs somewhere in `bytes`. An empty `part` always does.

### Examples

```ernest
#(Bytes.contains(<<1, 2, 3>>, <<2, 3>>), Bytes.contains(<<1, 2>>, <<3>>))
// => #(true, false)
```

## Bytes.indexOf

```ernest
Bytes.indexOf(bytes : Bytes, part : Bytes) : Optional(Int)
```

The index at which `part` first begins in `bytes`, or `None` where it is not
there. An empty `part` is at 0.

### Examples

```ernest
#(Bytes.indexOf(<<1, 2, 1, 2>>, <<1, 2>>), Bytes.indexOf(<<1>>, <<2>>))
// => #(Some(0), None)
```

## Bytes.lastIndexOf

```ernest
Bytes.lastIndexOf(bytes : Bytes, part : Bytes) : Optional(Int)
```

The index at which `part` last begins in `bytes`, or `None` where it is not
there. An empty `part` is at the end, the size of `bytes`.

### Examples

```ernest
#(Bytes.lastIndexOf(<<1, 2, 1, 2>>, <<1, 2>>), Bytes.lastIndexOf(<<1>>, <<2>>))
// => #(Some(2), None)
```

## Bytes.startsWith

```ernest
Bytes.startsWith(bytes : Bytes, prefix : Bytes) : Bool
```

`true` when `bytes` begins with `prefix`, and always for an empty `prefix`.

### Examples

```ernest
#(Bytes.startsWith(<<1, 2, 3>>, <<1, 2>>), Bytes.startsWith(<<1>>, <<1, 2>>))
// => #(true, false)
```

## Bytes.endsWith

```ernest
Bytes.endsWith(bytes : Bytes, suffix : Bytes) : Bool
```

`true` when `bytes` ends with `suffix`, and always for an empty `suffix`.

### Examples

```ernest
Bytes.endsWith(<<1, 2, 3>>, <<3>>)
// => true
```

## Bytes.split

```ernest
Bytes.split(bytes : Bytes, separator : Bytes) : List(Bytes)
```

The parts of `bytes` between the occurrences of `separator`, empty parts
included. An empty `separator` gives `[bytes]`.

### Examples

```ernest
Bytes.split(<<1, 0, 0, 2>>, <<0>>)
// => [<<1>>, <<>>, <<2>>]
```

## Bytes.replace

```ernest
Bytes.replace(bytes : Bytes, old : Bytes, new : Bytes) : Bytes
```

`bytes` with each occurrence of `old` replaced by `new`, found from the left
without overlaps. An empty `old` changes nothing.

### Examples

```ernest
Bytes.replace(<<1, 0, 2, 0>>, <<0>>, <<9, 9>>)
// => <<1, 9, 9, 2, 9, 9>>
```

## Bytes.join

```ernest
Bytes.join(parts : List(Bytes), separator : Bytes) : Bytes
```

The parts joined, with `separator` between each two.

### Examples

```ernest
Bytes.join([<<1>>, <<2>>], <<0>>)
// => <<1, 0, 2>>
```

## Bytes.repeat

```ernest
Bytes.repeat(bytes : Bytes, count : Int) : Bytes
```

`bytes` repeated `count` times. A `count` below 1 gives the empty `Bytes`.

### Examples

```ernest
Bytes.repeat(<<1, 2>>, 2)
// => <<1, 2, 1, 2>>
```

## Bytes.toHex

```ernest
Bytes.toHex(bytes : Bytes) : String
```

Each byte as two hexadecimal digits, letters in upper case: `<<255, 1>>` is
`"FF01"`.

### Examples

```ernest
Bytes.toHex(<<0, 171, 255>>)
// => "00ABFF"
```

## Bytes.fromHex

```ernest
Bytes.fromHex(text : String) : Optional(Bytes)
```

The bytes that `text` writes two hexadecimal digits each, letters in either
case, or `None` for an odd number of digits or a character that is no digit.

### Examples

```ernest
#(Bytes.fromHex("00abFF"), Bytes.fromHex("0"), Bytes.fromHex("zz"))
// => #(Some(<<0, 171, 255>>), None, None)
```

---

Generated by ern 0.3.1 from bytes.ern.
