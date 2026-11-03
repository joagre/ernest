<picture>
  <img src="../assets/ernest-combined-light.svg" alt="Ernest" width="520">
</picture>

# Programming in Ernest

The fixture the site's generator renders as the guide, whose pages its test holds equal to the expected ones. Every shape a chapter's page holds stands in it once, and §1 shows each.

**Contents**
<!-- contents -->
- [0. A chapter alone](#0-a-chapter-alone)
- [1. Every shape](#1-every-shape)
- [2. The last chapter](#2-the-last-chapter)
<!-- /contents -->

Beside the fixture: [Why Ernest](why.md), and [the questions](faq.md).

## 0. A chapter alone

The first chapter has no section, so its page has no sidebar, and no chapter before it. Its prose is a paragraph with `code`, *emphasis* and **strong emphasis**.

## 1. Every shape

A chapter's prose, its first sentence the page's description. A line ends here  
in a hard break, and a dot in `List.map` ends no sentence.

### 1.1 Citations

A bare §1.2 is the guide's own, and so is §2, and §1.1 on its own page is its anchor alone. The guide's §2.1, report §11.2, the report's §5.4 and the deployment guide's §1.5 name their owners. Appendix C, report Appendix E.1, E.0 shape rule 10 and Appendix E.17 are the report's. A § with no number is text.

### 1.2 Links

The report's first file is [its language](../report/language.md), [the tour](../tour/README.md) a book of its own, and [the README](../README.md) the installing page. A heading's anchor for GitHub, [the citations](#11-citations), is its number, on another chapter's page too, [the last chapter](#2-the-last-chapter). A file the site does not show is GitHub's, [the examples](../examples/README.md), and a link with a scheme stays as it is, [Erlang](https://www.erlang.org/).

### 1.3 Lists, a quote and a table

- An item of one paragraph.
- An item with a list in it:
  1. its first step
  2. and its second

3. A list that begins at three,
4. and goes on.

> A quote, with `code` in it.

---

| Left | Centered | Right |
|---|:-:|--:|
| `x` | two | 3 |
| *y* | four | 5 |

### 1.4 Code: `ernest` and the rest

A module of its own is pasted:

```ernest
fn double(value : Int) : Int =
    value * 2
```

One that exports `main` is loaded:

```ernest
export fn main() : Unit =
    Io.println("hello, world")
```

```console
$ ern build hello.ern
$ ern run hello.erc
hello, world
```

Blocks that name their file are a program's pieces, and are copied alone:

```ernest
// shapes.ern
export type Shape = Circle(radius : Float) | Square(side : Float)
```

```ernest
// shapes.ern, continued
export fn area(shape : Shape) : Float =
    match shape {
        Circle(=radius) -> 3.14 * radius * radius
      | Square(=side) -> side * side
    }
```

A block the compiler refuses, with what it says:

```ernest-rejected
fn twice(value) =
    value + "twice" // rejected
```

```console
$ ern build twice.ern
twice.ern:2:13: + takes two Ints
```

A fragment, which the lexer cannot read, is written as it is, and the prelude's declarations and another language's code are copied alone:

```ernest-fragment
let greeting = "unfinished
```

```ernest-prelude
type Optional(a) = Some(a) | None
```

```erlang
-module(helper).
-export([answer/0]).

answer() -> 42.
```

### 1.5 Sessions

A session begun bare is pasted an input at a time, and so is a console that continues it:

```console
$ ern shell
> 1 + 2
3 : Int
```

```console
> let names = ["Ada", "Grace"]
names : List(String)
```

A session that loads a module, one begun with a module, and a node's are copied alone:

```console
$ ern shell
> :load Counter
Counter, compiled from counter.ern
```

```console
$ ern build shapes.ern
$ ern shell shapes.erc
> Shapes.area(Shapes.Square(side = 2.0))
4.0 : Float
```

```console
$ ern shell --config-dir a
> Peer.utilizations()
[] : List(#(String, Float))
```

A code block in a list is copied alone:

- A step:

  ```ernest
  fn triple(value : Int) : Int =
      value * 3
  ```

### 1.6 Names of the library

`List.size` and `Markdown.parse` link to their declarations, in code too, and so does `List.<>`, whose name is an operator. A bare name, `spawn`, is text, and so are `List.map`, which the library does not declare, and `List.size(list)`, which is more than a name. The reasons are the log's *The Fixture's Entry*.

```ernest
fn counted(list : List(Int)) : Int =
    List.size(list) + Markdown.size
```

### Notes

A heading with no number has no anchor and no line in the sidebar.

## 2. The last chapter

### 2.1 Its one section

The last chapter has no chapter after it. Its code declares a type of its own, so `Markdown.parse` here is the type's, and text:

```ernest
type Markdown = Markdown(String)
```
