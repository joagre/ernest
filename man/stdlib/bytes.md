# Ernest module Bytes

*Since 0.1.0.*

Operations on `Bytes`, a sequence of octets (report §3.1). A `Bytes` is
a container read through `toList`, which gives its octets, each an `Int`
from 0 to 255, and `<<...>>` builds and matches one at the bit level
(report §5.11), so there is no constructor here. The primitive is
`size`, the runtime's; the rest is written over it and with the bit
syntax (report Appendix E.0 rule 1).

## Examples

```ernest
Bytes.toList(<<104, 105>> <> <<33>>)
// => [104, 105, 33]
```

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

The octets of the first, then those of the second.

## Bytes.size

```ernest
Bytes.size(bytes : Bytes) : Int
```

The number of octets.

### Examples

```ernest
#(Bytes.size(<<1, 2, 3>>), Bytes.isEmpty(<<>>))
// => #(3, true)
```

## Bytes.isEmpty

```ernest
Bytes.isEmpty(bytes : Bytes) : Bool
```

`true` for the empty `Bytes`.

## Bytes.get

```ernest
Bytes.get(bytes : Bytes, index : Int) : Optional(Int)
```

The octet at the index, counting from 0, or `None` beyond either end.

### Examples

```ernest
#(Bytes.get(<<7, 8>>, 1), Bytes.get(<<7, 8>>, 2))
// => #(Some(8), None)
```

## Bytes.slice

```ernest
Bytes.slice(bytes : Bytes, index : Int, count : Int) : Bytes
```

The octets from the index, that many of them, clipped to what is there;
a negative index or count is 0.

### Examples

```ernest
#(Bytes.slice(<<1, 2, 3>>, 1, 5), Bytes.slice(<<1, 2, 3>>, -1, 2))
// => #(<<2, 3>>, <<1, 2>>)
```

## Bytes.toList

```ernest
Bytes.toList(bytes : Bytes) : List(Int)
```

The octets, each from 0 to 255.

## Bytes.fromList

```ernest
Bytes.fromList(octets : List(Int)) : Optional(Bytes)
```

The `Bytes` of those octets, or `None` when one is outside 0 to 255.

### Examples

```ernest
Bytes.fromList([256])
// => None
```

## Bytes.contains

```ernest
Bytes.contains(bytes : Bytes, part : Bytes) : Bool
```

`true` when the second occurs in the first; an empty second always does.

### Examples

```ernest
#(Bytes.contains(<<1, 2, 3>>, <<2, 3>>), Bytes.contains(<<1, 2>>, <<3>>))
// => #(true, false)
```

## Bytes.indexOf

```ernest
Bytes.indexOf(bytes : Bytes, part : Bytes) : Optional(Int)
```

Where the second begins in the first, the first place it does, and
`None` where it is not there. An empty second is at 0.

### Examples

```ernest
#(Bytes.indexOf(<<1, 2, 1, 2>>, <<1, 2>>), Bytes.indexOf(<<1>>, <<2>>))
// => #(Some(0), None)
```

## Bytes.lastIndexOf

```ernest
Bytes.lastIndexOf(bytes : Bytes, part : Bytes) : Optional(Int)
```

Where the second begins in the first, the last place it does, and
`None` where it is not there. An empty second is at the end.

### Examples

```ernest
#(Bytes.lastIndexOf(<<1, 2, 1, 2>>, <<1, 2>>), Bytes.lastIndexOf(<<1>>, <<2>>))
// => #(Some(2), None)
```

## Bytes.startsWith

```ernest
Bytes.startsWith(bytes : Bytes, prefix : Bytes) : Bool
```

`true` when the first begins with the second, and for an empty second.

### Examples

```ernest
#(Bytes.startsWith(<<1, 2, 3>>, <<1, 2>>), Bytes.startsWith(<<1>>, <<1, 2>>))
// => #(true, false)
```

## Bytes.endsWith

```ernest
Bytes.endsWith(bytes : Bytes, suffix : Bytes) : Bool
```

`true` when the first ends with the second, and for an empty second.

### Examples

```ernest
Bytes.endsWith(<<1, 2, 3>>, <<3>>)
// => true
```

## Bytes.split

```ernest
Bytes.split(bytes : Bytes, separator : Bytes) : List(Bytes)
```

The parts between the occurrences of the second, the empty parts
included; an empty second gives the first alone.

### Examples

```ernest
Bytes.split(<<1, 0, 0, 2>>, <<0>>)
// => [<<1>>, <<>>, <<2>>]
```

## Bytes.replace

```ernest
Bytes.replace(bytes : Bytes, old : Bytes, new : Bytes) : Bytes
```

Every occurrence of the second replaced by the third, the first
occurrence first; an empty second changes nothing.

### Examples

```ernest
Bytes.replace(<<1, 0, 2, 0>>, <<0>>, <<9, 9>>)
// => <<1, 9, 9, 2, 9, 9>>
```

## Bytes.join

```ernest
Bytes.join(parts : List(Bytes), separator : Bytes) : Bytes
```

The parts with the second between them.

### Examples

```ernest
Bytes.join([<<1>>, <<2>>], <<0>>)
// => <<1, 0, 2>>
```

## Bytes.repeat

```ernest
Bytes.repeat(bytes : Bytes, count : Int) : Bytes
```

The octets `count` times; `count` below 0 gives the empty `Bytes`.

### Examples

```ernest
Bytes.repeat(<<1, 2>>, 2)
// => <<1, 2, 1, 2>>
```

## Bytes.toHex

```ernest
Bytes.toHex(bytes : Bytes) : String
```

Each octet as two hexadecimal digits, with upper-case letters as
`Int.toStringBase` writes them.

### Examples

```ernest
Bytes.toHex(<<0, 171, 255>>)
// => "00ABFF"
```

## Bytes.fromHex

```ernest
Bytes.fromHex(text : String) : Optional(Bytes)
```

The octets two hexadecimal digits write each, in either case, or `None`
for an odd number of digits or a character that is none.

### Examples

```ernest
#(Bytes.fromHex("00abFF"), Bytes.fromHex("0"), Bytes.fromHex("zz"))
// => #(Some(<<0, 171, 255>>), None, None)
```

---

Generated by ern 0.3.0 from bytes.ern.
