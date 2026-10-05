# Ernest module String

*Since 0.1.0.*

Operations on `String`, a Unicode string (report §3.1). A `String` is
a container read through `toList`, which gives its `Char`s. `size`,
`slice`, `indexOf`, `lastIndexOf`, `padStart`, and `padEnd` count and
index in graphemes, extended grapheme clusters, each what a reader sees
as one letter; `toList` and `fromList` are `Char`s, one scalar value
each. Every search matches whole graphemes, so
`String.contains("e\u{301}", "e")` is `false` (report Appendix E.5).

## Examples

```ernest
String.join(List.map(String.split("a,b", ","), String.toUpper), "-")
// => "A-B"
```

```ernest
String.slice("hello", 1, 3)
// => "ell"
```

```ernest
String.toInt("-12")
// => Some(-12)
```

## See also

`Char` for one scalar value, `Bytes` for octets, `Int.toString` and
`Float.toString` for numbers as text.

## String.<>

```ernest
String.<>(left : String, right : String) : String
```

The first, then the second.

## String.size

```ernest
String.size(text : String) : Int
```

The number of graphemes, extended grapheme clusters, which is neither
the number of octets nor the number of `Char`s: `e` with a combining
acute is one grapheme of two `Char`s.

### Examples

```ernest
#(String.size("héj"), String.isEmpty(""))
// => #(3, true)
```

```ernest
#(String.size("e\u{301}"), List.size(String.toList("e\u{301}")))
// => #(1, 2)
```

## String.graphemes

```ernest
String.graphemes(text : String) : List(String)
```

The graphemes in order, each a `String`: what a reader sees as one
letter, where `toList` gives the `Char`s.

### Examples

```ernest
String.graphemes("a中!")
// => ["a", "中", "!"]
```

```ernest
#(List.size(String.graphemes("e\u{301}")), List.size(String.toList("e\u{301}")))
// => #(1, 2)
```

## String.isEmpty

```ernest
String.isEmpty(text : String) : Bool
```

`true` for the empty string.

## String.compare

```ernest
String.compare(left : String, right : String) : Ordering
```

The order of the code points, which `<` and the other comparisons use.

### Examples

```ernest
String.compare("a", "b")
// => Less
```

## String.contains

```ernest
String.contains(text : String, part : String) : Bool
```

`true` when the second is somewhere in the first, as whole graphemes; an
empty second is always there.

### Examples

```ernest
#(String.contains("hello", "ell"), String.contains("hello", "x"))
// => #(true, false)
```

```ernest
String.contains("e\u{301}", "e")
// => false
```

## String.indexOf

```ernest
String.indexOf(text : String, part : String) : Optional(Int)
```

Where the second begins in the first, and `None` where it is not
there. An empty second is at 0.

### Examples

```ernest
#(String.indexOf("hello", "ll"), String.indexOf("hello", "x"))
// => #(Some(2), None)
```

## String.lastIndexOf

```ernest
String.lastIndexOf(text : String, part : String) : Optional(Int)
```

Where the second begins last in the first, and `None` where it is not
there. An empty second is at the first's size.

### Examples

```ernest
#(String.lastIndexOf("hello", "l"), String.lastIndexOf("hello", "x"))
// => #(Some(3), None)
```

## String.startsWith

```ernest
String.startsWith(text : String, prefix : String) : Bool
```

`true` when the string begins with the second, as whole graphemes, and
for an empty second.

### Examples

```ernest
#(String.startsWith("hello", "he"), String.endsWith("hello", "lo"))
// => #(true, true)
```

## String.endsWith

```ernest
String.endsWith(text : String, suffix : String) : Bool
```

`true` when the string ends with the second, as whole graphemes, and for
an empty second.

## String.replace

```ernest
String.replace(text : String, old : String, new : String) : String
```

Every occurrence of the second replaced by the third; an empty second
changes nothing.

### Examples

```ernest
String.replace("a-b-c", "-", "+")
// => "a+b+c"
```

## String.slice

```ernest
String.slice(text : String, index : Int, count : Int) : String
```

From the index, that many graphemes, clipped to what is there; a
negative index starts at the beginning, and a negative count gives the
empty string.

### Examples

```ernest
#(String.slice("hello", -1, 3), String.slice("hello", 3, 9))
// => #("hel", "lo")
```

## String.padStart

```ernest
String.padStart(text : String, count : Int, pad : String) : String
```

The pad's copies in front until the text has that many graphemes, the
last copy cut to fit; an empty pad adds none. A pad that begins no
grapheme, a combining mark, joins the grapheme beside it, and the text
stays short.

### Examples

```ernest
#(String.padStart("7", 3, "0"), String.padEnd("7", 4, "ab"))
// => #("007", "7aba")
```

```ernest
String.size(String.padStart("ab", 4, "\u{301}"))
// => 3
```

## String.padEnd

```ernest
String.padEnd(text : String, count : Int, pad : String) : String
```

The pad's copies at the end until the text has that many graphemes, as
`padStart` puts them in front.

## String.repeat

```ernest
String.repeat(text : String, count : Int) : String
```

The string `count` times; `count` below 0 gives the empty string.

### Examples

```ernest
String.repeat("ab", 3)
// => "ababab"
```

## String.trim

```ernest
String.trim(text : String) : String
```

Without leading and trailing whitespace: the graphemes whose first code
point is White_Space, as `Char.isSpace` says. It is `trimStart` then
`trimEnd`, a pair the library keeps named (report Appendix E.0 rule 4).

### Examples

```ernest
String.trim("  hi\n")
// => "hi"
```

```ernest
String.trim("\u{a0}a\u{3000}")
// => "a"
```

## String.trimStart

```ernest
String.trimStart(text : String) : String
```

Without leading whitespace, as `trim` has it.

### Examples

```ernest
#(String.trimStart("  a "), String.trimEnd("  a "))
// => #("a ", "  a")
```

## String.trimEnd

```ernest
String.trimEnd(text : String) : String
```

Without trailing whitespace, as `trim` has it.

## String.toLower

```ernest
String.toLower(text : String) : String
```

The lower-case form, by Unicode.

### Examples

```ernest
#(String.toLower("ÉH"), String.toUpper("éh"))
// => #("éh", "ÉH")
```

## String.toUpper

```ernest
String.toUpper(text : String) : String
```

The upper-case form, by Unicode.

## String.lines

```ernest
String.lines(text : String) : List(String)
```

The lines, split at each line feed and at each carriage return with a
line feed, which is one grapheme; a line's end at the end adds no empty
line, and `""` has no lines.

### Examples

```ernest
#(String.lines("a\nb\n"), String.lines("a\r\nb"))
// => #(["a", "b"], ["a", "b"])
```

## String.words

```ernest
String.words(text : String) : List(String)
```

*Since 0.2.0.*

The words: the parts between runs of whitespace, the graphemes whose
first code point is White_Space, as `trim` judges them, none of the
parts empty. A grapheme is never split, so a combining mark after a
space goes with the space.

### Examples

```ernest
#(String.words("  one two\tthree\n"), String.words(" "))
// => #(["one", "two", "three"], [])
```

```ernest
String.words("a \u{301}b")
// => ["a", "b"]
```

## String.split

```ernest
String.split(text : String, separator : String) : List(String)
```

The parts between the occurrences of the second, the empty parts
included; an empty second gives the string alone.

### Examples

```ernest
String.split("a,,b", ",")
// => ["a", "", "b"]
```

## String.join

```ernest
String.join(parts : List(String), separator : String) : String
```

The parts with the second between them.

### Examples

```ernest
String.join(["a", "b"], ", ")
// => "a, b"
```

## String.toInt

```ernest
String.toInt(text : String) : Optional(Int)
```

The digits 0 to 9 as an `Int`, with an optional leading `-`, or `None`
for anything else.

### Examples

```ernest
#(String.toInt("12"), String.toInt("1x"))
// => #(Some(12), None)
```

## String.toIntBase

```ernest
String.toIntBase(text : String, base : Int) : Optional(Int)
```

The digits and letters in that base, 2 to 36, in either case, with an
optional leading `-`, or `None` for anything else, a leading `+` among
it, and for a base outside those.

### Examples

```ernest
#(String.toIntBase("ff", 16), String.toIntBase("fg", 16))
// => #(Some(255), None)
```

## String.toBool

```ernest
String.toBool(text : String) : Optional(Bool)
```

`true` for `"true"` and `false` for `"false"`, or `None` for anything
else; the inverse of `Bool.toString`.

### Examples

```ernest
#(String.toBool("true"), String.toBool("yes"))
// => #(Some(true), None)
```

## String.toFloat

```ernest
String.toFloat(text : String) : Optional(Float)
```

The float literal form of report §2.5 without `_`, with an optional
leading `-`, as a `Float`, or `None` for anything else and for a value
beyond the finite range of report §3.1; one below the smallest
subnormal is the nearest `Float`, `0.0` among them.

### Examples

```ernest
#(String.toFloat("1.5"), String.toFloat("1"))
// => #(Some(1.5), None)
```

## String.toList

```ernest
String.toList(text : String) : List(Char)
```

The code points, in order.

### Examples

```ernest
String.fromList(List.filter(String.toList("a1b"), Char.isAlpha))
// => "ab"
```

## String.fromList

```ernest
String.fromList(chars : List(Char)) : String
```

The string of those code points.

## String.toUtf8

```ernest
String.toUtf8(text : String) : Bytes
```

The UTF-8 octets of the string.

### Examples

```ernest
#(String.toUtf8("hi"), String.fromUtf8(<<104, 105>>))
// => #(<<104, 105>>, Some("hi"))
```

## String.fromUtf8

```ernest
String.fromUtf8(bytes : Bytes) : Optional(String)
```

The string those octets spell, or `None` when they are not UTF-8.

---

Generated by ern 0.3.0 from string.ern.
