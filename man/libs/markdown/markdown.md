# Ernest module Markdown

*Since 0.1.0.*

Markdown documents, read and laid out as text for a terminal or as a manual
page.

Use it to show a document a program holds. `parse` reads CommonMark 0.31
text, the specification at commonmark.org, into blocks; `render` lays the
blocks out as rows for a terminal, and `roff` writes them as a manual page.
The shell's `:doc` shows documentation with `render`, and `ern doc` writes
manual pages with `roff`.

A program that uses the library puts it on its load path, both when it is
compiled and when it is run: `--load-path` with the directory of the
compiled library, `lib/ernest/build/libs/markdown` under the prefix Ernest
is installed in. It styles text with `libs/ansi`, which a run needs on the
load path beside it (report Appendix G.2). Under `/usr/local`, where Ernest
is installed by default:

```sh
ern build --load-path /usr/local/lib/ernest/build/libs/markdown main.ern
ern run --load-path /usr/local/lib/ernest/build/libs/markdown \
    --load-path /usr/local/lib/ernest/build/libs/ansi main.erc
```

**What it reads.** `parse` reads headings, paragraphs, code blocks, block
quotes, lists and thematic breaks, and inside them code spans, emphasis,
strong emphasis, links, images and hard line breaks. An image is read as a
`Link`. A line may end in a line feed, a carriage return and a line feed, or
a carriage return.

**What it keeps as written.** An HTML block is a `Raw` block, and inline
HTML, an entity and a link by reference stay in the text.

**Emphasis, more simply than CommonMark.** A run of `*` or `_` opens
emphasis where a character other than a space follows it. The nearest later
run of as many marks that follows such a character closes it. A run of three
or more marks is text.

**HTML blocks, more simply than CommonMark.** One begins with a comment, a
declaration, a processing instruction or a CDATA section, whatever follows
on the line, or with a tag alone on its line outside a paragraph; inside a
paragraph such a tag is text. A comment runs to the line that holds `-->`, a
processing instruction to one that holds `?>`, a CDATA section to one that
holds `]]>`, and a declaration to one that holds `>`, its first line among
them, and each to the end where no line does. A tag runs to a blank line.

**Tabs.** A tab in a line's indentation, quote marks and list markers
reaches to the next multiple of four columns. One elsewhere is kept, in a
code block's content as in text.

## Examples

A heading and a paragraph rendered plain, 80 columns wide; plain text keeps
emphasis between `*`s:

```ernest
Markdown.render(Markdown.parse("# Title\n\nSome *words*."), 80, Markdown.Plain)
// => ["Title", "", "Some *words*."]
```

A bullet list rendered plain:

```ernest
Markdown.render(Markdown.parse("- one\n- two"), 80, Markdown.Plain)
// => ["• one", "• two"]
```

## See also

`String.lines` for splitting text into lines; `parse` also ends a line at a
lone carriage return, which `String.lines` does not.

## Markdown.Inline

```ernest
type Inline =
    Text(String)
  | CodeSpan(String)
  | Emphasis(List(Inline))
  | Strong(List(Inline))
  | Link(text : List(Inline), address : String)
  | Break
```

A span of text inside a block.

### Examples

```ernest
Markdown.Link(address = "https://example.org", text = [Markdown.Text("home")])
// => Link(text = [Text("home")], address = "https://example.org")
```

- `Text`: Text as it reads.
- `CodeSpan`: A code span, its text taken literally.
- `Emphasis`: Emphasis, shown in italics.
- `Strong`: Strong emphasis, shown bold.
- `Link`: A link or an image, by the text it shows and the address it names.
- `Break`: A hard line break.

## Markdown.Block

```ernest
type Block =
    Heading(level : Int, text : List(Inline))
  | Paragraph(List(Inline))
  | Code(info : String, lines : List(String))
  | Quote(List(Block))
  | Items(start : Optional(Int), items : List(List(Block)))
  | Rule
  | Raw(List(String))
```

A block of a document.

### Examples

```ernest
Markdown.Heading(level = 2, text = [Markdown.Text("Usage")])
// => Heading(level = 2, text = [Text("Usage")])
```

- `Heading`: A heading, its level from 1 to 6.
- `Paragraph`: A paragraph.
- `Code`: A code block: the info string after its opening fence, empty for an
indented one, and its lines.
- `Quote`: A block quote.
- `Items`: A list: the number its first item carries, `None` for a bullet list,
and the blocks of each item.
- `Rule`: A thematic break.
- `Raw`: Lines that are not read, an HTML block's, kept as written.

## Markdown.Output

```ernest
type Output = Plain | Styled
```

*Since 0.2.0.*

How `render` writes a document: plain, or with the terminal's styles.

### Examples

```ernest
Markdown.render(Markdown.parse("Some *words*."), 80, Markdown.Plain)
// => ["Some *words*."]
```

- `Plain`: A code span between single backticks, emphasis between `*`s and
strong emphasis between `**`s, whether the source wrote `*` or `_`.
- `Styled`: Bold, italics and colour, in the terminal's escape sequences.

## Markdown.Manual

```ernest
type Manual =
    Manual(name : String, section : String, summary : List(Inline), source : String, title : String)
```

What a manual page's header, footer and NAME line say.

- `name`: the page's name, `ern`.
- `section`: the section of the manual it is in, `1`.
- `summary`: what follows the name on the NAME line.
- `source`: the package and its version, printed at the foot of the page,
  `Ernest 0.1.0`.
- `title`: the manual's name, printed at its head, `Ernest Manual`.

### Examples

```ernest
Markdown.Manual(name = "ern",
                section = "1",
                summary = [Markdown.Text("the Ernest toolchain")],
                source = "Ernest 0.1.0",
                title = "Ernest Manual").section
// => "1"
```

## Markdown.parse

```ernest
Markdown.parse(text : String) : List(Block)
```

The blocks of `text`, in order.

### Examples

```ernest
Markdown.parse("## Usage\n\nRun `ern`")
// => [Heading(level = 2, text = [Text("Usage")]), Paragraph([Text("Run "), CodeSpan("ern")])]
```

## Markdown.render

```ernest
Markdown.render(blocks : List(Block), width : Int, output : Output) : List(String)
```

The document as rows of text at most `width` columns wide, where a word
allows, with the terminal's styles where `output` is `Styled`. Blocks are
separated by an empty row.

A heading is its text, bold with styles. A code block is indented four
columns and never wrapped. A list item follows a bullet, or its number and a
period, whatever delimiter it was written with. A block quote follows a bar,
a thematic break is a line across the width, and a link is its text with its
address after it.

With styles, emphasis is in italics, strong emphasis bold, and a code span
cyan; emphasis within emphasis, and strong emphasis within a heading, are as
the text around them. Without styles a code span is between single
backticks, emphasis between `*`s and strong emphasis between `**`s.

### Examples

```ernest
Markdown.render(Markdown.parse("A [link](https://example.org).\n\n    code"),
                80,
                Markdown.Plain)
// => ["A link (https://example.org).", "", "    code"]
```

## Markdown.roff

```ernest
Markdown.roff(blocks : List(Block), manual : Manual) : List(String)
```

The document as a manual page in man(7)'s roff markup, which groff and
mandoc render, one line of roff text in each element.

The header and the NAME line come from `manual`. The blocks before the first
heading of level 1 go under DESCRIPTION; a heading of level 1 is a section,
one of level 2 a subsection, and a deeper one a paragraph in bold. Lines are
filled to the left margin alone and no word is hyphenated, so that a name in
the text is never spread or broken.

A code span and strong emphasis are bold, and emphasis is in italics. A code
block is indented and not filled, a list item follows its bullet or its
number, a block quote is indented, a thematic break is a row of asterisks, a
link is its text with its address after it, and a `Raw` block is as written.

Every character roff would change is written as roff's escape for it, so
that code copied from the page is the code written. The rest is UTF-8, which
man-db and mandoc read.

### Examples

The page from its NAME line on, after its header's four lines:

```ernest
List.drop(Markdown.roff(Markdown.parse("Says *hello*."),
                        Markdown.Manual(name = "hello",
                                        section = "1",
                                        summary = [Markdown.Text("greet")],
                                        source = "Hello 1.0",
                                        title = "Hello Manual")),
          4)
// => [".SH NAME", "hello \\- greet", ".SH DESCRIPTION", ".PP", "Says \\fIhello\\fR."]
```

## Markdown.firstSentence

```ernest
Markdown.firstSentence(blocks : List(Block)) : List(Inline)
```

The text of the document's first paragraph up to and including the first
period followed by a space, not counting a period inside emphasis, a code
span or a link. It is the whole paragraph where there is no such period, and
nothing where the document has no paragraph.

### Examples

```ernest
Markdown.firstSentence(Markdown.parse("# Title\n\nOne `a`. Two."))
// => [Text("One "), CodeSpan("a"), Text(".")]
```

---

Generated by ern 0.3.1 from markdown.ern.
