# Ernest module String

*Since 0.1.0.*

Text: Unicode strings, held as UTF-8.

Use a `String` for text a person reads or writes. For the bytes of a file or
a socket use `Bytes`, and convert with `toUtf8` and `fromUtf8`. A string is
a value: every function here answers a new string and leaves the one it was
given as it was.

**Letters, not bytes.** A string is counted and indexed in graphemes, each
what a reader sees as one letter. `size`, `slice`, `indexOf`, `lastIndexOf`,
`padStart` and `padEnd` count graphemes, so `"é"` has size 1 whether its
accent is a letter of its own or a mark after an `e`. Every search matches
whole graphemes: `String.contains("e\u{301}", "e")` is `false`, since the
`e` there is part of a larger letter (report Appendix E.5).

**Chars.** `toList` gives the string's `Char`s, one Unicode scalar value
each, and `fromList` builds a string from them. A grapheme may be several
`Char`s, and `graphemes` gives the graphemes themselves.

## Examples

Text split, each part in upper case, and joined again:

```ernest
String.join(List.map(String.split("a,b", ","), String.toUpper), "-")
// => "A-B"
```

Three characters from index 1:

```ernest
String.slice("hello", 1, 3)
// => "ell"
```

A number read from text:

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

The first string, then the second.

## String.size

```ernest
String.size(text : String) : Int
```

The number of graphemes, what a reader counts as letters. It is neither the
number of bytes nor the number of `Char`s: `e` with a combining accent is
one grapheme of two `Char`s.

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

The graphemes in order, each a `String`: what a reader sees as one letter,
where `toList` gives the `Char`s.

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

`true` for the empty string, `""`.

## String.compare

```ernest
String.compare(left : String, right : String) : Ordering
```

Compares two strings by their code points, which `<` and the other
comparisons on strings use. It is not alphabetical order in any language:
every capital letter of ASCII comes before every small one, so `"Z" < "a"`.

### Examples

```ernest
String.compare("a", "b")
// => Less
```

## String.contains

```ernest
String.contains(text : String, part : String) : Bool
```

`true` when `part` stands somewhere in `text`, as whole graphemes. An empty
`part` is always there.

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

The index, in graphemes, at which `part` first begins in `text`, or `None`
where it is not there. An empty `part` is at 0.

### Examples

```ernest
#(String.indexOf("hello", "ll"), String.indexOf("hello", "x"))
// => #(Some(2), None)
```

## String.lastIndexOf

```ernest
String.lastIndexOf(text : String, part : String) : Optional(Int)
```

The index, in graphemes, at which `part` last begins in `text`, or `None`
where it is not there. An empty `part` is at the size of `text`.

### Examples

```ernest
#(String.lastIndexOf("hello", "l"), String.lastIndexOf("hello", "x"))
// => #(Some(3), None)
```

## String.startsWith

```ernest
String.startsWith(text : String, prefix : String) : Bool
```

`true` when `text` begins with `prefix`, as whole graphemes. Every string
begins with the empty string.

### Examples

```ernest
#(String.startsWith("hello", "he"), String.endsWith("hello", "lo"))
// => #(true, true)
```

## String.endsWith

```ernest
String.endsWith(text : String, suffix : String) : Bool
```

`true` when `text` ends with `suffix`, as whole graphemes. Every string ends
with the empty string.

## String.replace

```ernest
String.replace(text : String, old : String, new : String) : String
```

`text` with each occurrence of `old` replaced by `new`. Occurrences are
found from the left and do not overlap, so `replace("aaa", "aa", "b")` is
`"ba"`. An empty `old` changes nothing.

### Examples

```ernest
String.replace("a-b-c", "-", "+")
// => "a+b+c"
```

## String.slice

```ernest
String.slice(text : String, index : Int, count : Int) : String
```

The `count` graphemes of `text` from `index`, or as many as there are. An
`index` below 0 starts at the beginning, and a `count` below 1 gives the
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

`text` with copies of `pad` put in front until it has `count` graphemes, the
last copy cut to fit. A text that already has `count` or more is answered as
it is, and an empty `pad` adds nothing. A `pad` that begins with a combining
mark joins the grapheme beside it, and the text stays short.

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

`text` with copies of `pad` put at its end until it has `count` graphemes,
as `padStart` puts them in front.

## String.repeat

```ernest
String.repeat(text : String, count : Int) : String
```

`text` repeated `count` times. A `count` below 1 gives the empty string.

### Examples

```ernest
String.repeat("ab", 3)
// => "ababab"
```

## String.trim

```ernest
String.trim(text : String) : String
```

`text` without whitespace at its start and its end. Whitespace is the
graphemes whose first code point is Unicode White_Space, as `Char.isSpace`
says: spaces, tabs, line ends and the like.

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

`text` without whitespace at its start, whitespace as `trim` has it.

### Examples

```ernest
#(String.trimStart("  a "), String.trimEnd("  a "))
// => #("a ", "  a")
```

## String.trimEnd

```ernest
String.trimEnd(text : String) : String
```

`text` without whitespace at its end, whitespace as `trim` has it.

## String.toLower

```ernest
String.toLower(text : String) : String
```

`text` in lower case, by Unicode's rules, which may change its size: one
letter may become two.

### Examples

```ernest
#(String.toLower("ÉH"), String.toUpper("éh"))
// => #("éh", "ÉH")
```

## String.toUpper

```ernest
String.toUpper(text : String) : String
```

`text` in upper case, by Unicode's rules, which may change its size: `"ß"`
becomes `"SS"`.

## String.lines

```ernest
String.lines(text : String) : List(String)
```

The lines of `text`, split at each line feed and at each carriage return
followed by a line feed. A line end at the very end adds no empty line, and
`""` has no lines.

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

The words of `text`: the parts between runs of whitespace, whitespace as
`trim` has it, none of them empty. A grapheme is never split, so a combining
mark after a space goes with the space.

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

The parts of `text` between the occurrences of `separator`, empty parts
included: `"a,,b"` split at `","` is `["a", "", "b"]`. An empty `separator`
gives `[text]`, and so does a text without one.

### Examples

```ernest
String.split("a,,b", ",")
// => ["a", "", "b"]
```

## String.join

```ernest
String.join(parts : List(String), separator : String) : String
```

The strings of `parts` joined, with `separator` between each two.

### Examples

```ernest
String.join(["a", "b"], ", ")
// => "a, b"
```

## String.toInt

```ernest
String.toInt(text : String) : Optional(Int)
```

Reads `text` as a decimal integer. It answers `Some(n)` where `text` is
digits with an optional leading `-`. Other text answers `None`, text with a
space, a `+`, an `_` or a point among it.

### Examples

```ernest
#(String.toInt("12"), String.toInt("1x"))
// => #(Some(12), None)
```

## String.toIntBase

```ernest
String.toIntBase(text : String, base : Int) : Optional(Int)
```

Reads `text` as an integer in `base`, from 2 to 36. It answers `Some(n)`
where `text` is digits and letters of the base, in either case, with an
optional leading `-`. Other text answers `None`, a leading `+` among it, and
so does a base outside 2 to 36.

### Examples

```ernest
#(String.toIntBase("ff", 16), String.toIntBase("fg", 16))
// => #(Some(255), None)
```

## String.toBool

```ernest
String.toBool(text : String) : Optional(Bool)
```

`Some(true)` for `"true"` and `Some(false)` for `"false"`, or `None` for any
other text; the inverse of `Bool.toString`.

### Examples

```ernest
#(String.toBool("true"), String.toBool("yes"))
// => #(Some(true), None)
```

## String.toFloat

```ernest
String.toFloat(text : String) : Optional(Float)
```

Reads `text` as a `Float`. It answers `Some(x)` where `text` is digits with
a point and digits after it, `"2.5"`, with an exponent, `"1e10"`, or with
both, and an optional leading `-`. A whole number, `"1"`, answers `None`, as
do `"2."`, `".5"`, a `+` or an `_`, other text, and a value too large for a
`Float`. A value too small to hold is the nearest `Float`, `0.0` among them
(report §2.5, §3.1).

### Examples

```ernest
#(String.toFloat("1.5"), String.toFloat("1"))
// => #(Some(1.5), None)
```

## String.toList

```ernest
String.toList(text : String) : List(Char)
```

The `Char`s of the string, its Unicode scalar values, in order. A grapheme
may be several of them; `graphemes` gives the graphemes.

### Examples

```ernest
String.fromList(List.filter(String.toList("a1b"), Char.isAlpha))
// => "ab"
```

## String.fromList

```ernest
String.fromList(chars : List(Char)) : String
```

The string of those `Char`s, in order.

## String.toUtf8

```ernest
String.toUtf8(text : String) : Bytes
```

The string's bytes, in UTF-8, as a file or a socket takes them.

### Examples

```ernest
#(String.toUtf8("hi"), String.fromUtf8(<<104, 105>>))
// => #(<<104, 105>>, Some("hi"))
```

## String.fromUtf8

```ernest
String.fromUtf8(bytes : Bytes) : Optional(String)
```

The string that `bytes` holds in UTF-8, or `None` where they are not UTF-8.

---

Generated by ern 0.3.1 from string.ern.
