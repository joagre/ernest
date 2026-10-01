# Ernest module Markdown

*Since 0.1.0.*

CommonMark 0.31, the specification at commonmark.org, read into blocks
and inlines, and rendered as text for a terminal or as a manual page.
`parse` reads the blocks a document is made of, headings, paragraphs,
code blocks, block quotes, lists, and thematic breaks, and inside them
code spans, emphasis, strong emphasis, links, images, and hard line
breaks; `render` lays them out at a width, and `roff` writes them as a
manual page in the roff of man(7). What it does not read is kept as
written: an HTML block is a `Raw` block, and inline HTML, an entity, and
a link by reference stay in the text. An HTML block begins with a
comment, a declaration, a processing instruction, or a tag alone on its
line, and a tag alone does not end a paragraph. Emphasis follows a
simpler rule than the specification's: a mark opens before a character
other than a space and closes after one, the nearest run of as many
marks closes it, and a run of three or more is text. A tab in a line's
indentation, quote marks and list markers reaches to the next multiple
of four columns, and one elsewhere is kept, in a code block's content as
in text. A line may end in a line feed, a carriage return and a line
feed, or a carriage return. A program puts the library on its load path, when it is compiled
and when it is run.

## Examples

```ernest
Markdown.render(Markdown.parse("# Title\n\nSome *words*."), 80, Markdown.Plain)
// => ["Title", "", "Some *words*."]
```

```ernest
Markdown.render(Markdown.parse("- one\n- two"), 80, Markdown.Plain)
// => ["• one", "• two"]
```

## See also

`String.lines`, which `parse` splits a document with.

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

How `render` writes a document: each span as it is written, or with
the terminal's styles.

### Examples

```ernest
Markdown.render(Markdown.parse("Some *words*."), 80, Markdown.Plain)
// => ["Some *words*."]
```

- `Plain`: Emphasis, strong emphasis and code spans as they are written.
- `Styled`: Bold, italics and colour, in the terminal's escape sequences.

## Markdown.Manual

```ernest
type Manual =
    Manual(name : String, section : String, summary : List(Inline), source : String, title : String)
```

What a manual page's header and its NAME line say: the page's name, the
section of the manual it is in, what follows the name on the NAME line,
the source the footer names, and the title of the manual the header
names.

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
Markdown.parse : (String) -> List(Block)
```

The blocks of the document, in order.

### Examples

```ernest
Markdown.parse("## Usage\n\nRun `ern`")
// => [Heading(level = 2, text = [Text("Usage")]), Paragraph([Text("Run "), CodeSpan("ern")])]
```

## Markdown.render

```ernest
Markdown.render : (List(Block), Int, Output) -> List(String)
```

The document as rows of text at most that many columns wide where a
word allows, with the terminal's styles when the output is `Styled`. A
heading is its text, bold with styles; a code block is indented four
columns and never wrapped; a list item follows a bullet, or its number
and a period whichever delimiter it was written with; a block quote
follows a bar; a thematic break is a line across the width; and a link
is its text with its address after it. Emphasis is in italics, strong
emphasis bold, and a code span cyan with styles, and each is as
written without them. Blocks are separated by an empty row.

### Examples

```ernest
Markdown.render(Markdown.parse("A [link](https://example.org).\n\n    code"),
                80,
                Markdown.Plain)
// => ["A link (https://example.org).", "", "    code"]
```

## Markdown.roff

```ernest
Markdown.roff : (List(Block), Manual) -> List(String)
```

The document as a manual page in the roff of man(7), which groff and
mandoc render, a line of the page's source each: the header and the
NAME line from the page, the blocks before the first heading of level 1
under DESCRIPTION, a heading of level 1 a section, one of level 2 a
subsection, and a deeper one a paragraph in bold. Lines are filled to
the left margin alone and no word is hyphenated, so that a name in the
text is never spread or broken. A code span and strong
emphasis are bold, emphasis is in italics, a code block is indented and
not filled, a list item follows its bullet or its number, a block quote
is indented, a thematic break is a row of asterisks, a link is its text
with its address after it, and a `Raw` block is as written. Every
character roff would change is written as roff's escape for it, so that
code copied from the page is the code written, and the rest is UTF-8,
which man-db and mandoc read.

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
Markdown.firstSentence : (List(Block)) -> List(Inline)
```

The first sentence of the document: the text of its first paragraph up
to the first period a space follows outside emphasis, code spans, and
links, or all of it where there is none, and nothing where the document
has no paragraph.

### Examples

```ernest
Markdown.firstSentence(Markdown.parse("# Title\n\nOne `a`. Two."))
// => [Text("One "), CodeSpan("a"), Text(".")]
```

---

Generated by ern 0.2.0 from markdown.ern.
