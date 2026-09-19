# How an Ernest module is documented

This page is the norm for documenting a standard library module, and every module written in MVP 2.5 and after is documented to it. The rules are the report's: §2.2 says where a doc block may stand and that its text is CommonMark, §11.4 what `ernc --doc` renders, and Appendix E.0 rule 6 what a doc block contains. The page shows them on one fictive module, `examples/template.ern`. Everything below the marker is the output of `ernc --doc examples/template.ern`, and a test keeps it so; another test type-checks every example in the module's doc blocks.

A module's documentation is a section 3 manual page. Its headings fall in three groups.

**Automatic**, written by `ernc --doc` and never by hand:

- NAME: the heading, `# Ernest module Name` for the module and `## name` for each declaration, the name as the module writes it; and the last line, which names the `ernc` version and the source file, so a page read alone says what it is and what made it.
- SYNOPSIS: the code block under the heading, the declaration for a type and `name : type` for a function or value; an abstract type without its representation.

**Mandatory**, written by the author:

- The module's doc block, first in the file with a blank line after it: what the module is for in free text, then `## Examples` with a few central examples, the ones a reader tries first, one per core operation.
- DESCRIPTION for every exported declaration: one or a few sentences, saying what the type does not say, which occurrence `remove` removes, the order `toList` produces, the range `next` draws from. A member of an abstract type is documented at its signature entry and inherits that text under its own heading.
- `### Errors` for every function that faults, naming the fault; no other function has the section, by E.0 rule 4.
- `since v` as the last line of the module's doc block and of every exported declaration's, `v` the `VERSION` in which it appeared; rendered as *Since v.* after the synopsis, so a later tool can list what a version added.
- `### Examples` with one example for every exported `type` and `fn`. An abstract type's examples cover its members, which are documented at their signature entries. An exported `let` needs none: its sentence says what the value is, and an example would repeat the synopsis. A private declaration with a doc block may have one. An example ends in `// => v`, where `v` is what `Io.debug` prints for its value; the test runs the example and compares, so a documented result is a tested one. An example whose value is of an abstract type omits the line, since the rendering would show the private representation.

**Optional**, added where the author sees fit:

- A sentence on a constructor, a named field, or a signature entry, rendered as a list under the declaration.
- `### See also`, and `## See also` for the module.
- Further examples, and a doc block on a private declaration, which then appears among the exported ones.

RETURN VALUE has no heading: it is the type, plus what the description adds. `See also` names declarations and modules in backticks and never links them, since CommonMark fixes no anchor rule; a renderer that knows the headings may linkify. An example whose value cannot be shown, one that reads a file or a socket, or one of an abstract type, has no `// =>` line and is type-checked only.

Each standard library module is written and documented in one pass, to this page. After each module, its rendered page is read against this one before the next module starts, and what the reading changes goes into this page and E.0 rule 6 first. Headings inside a declaration's doc block are level three, since the declaration's own heading is level two; in the module's doc block they are level two.

<!-- generated: ernc --doc examples/template.ern -->
# Ernest module Template

*Since 0.1.0.*

Shapes in the plane and their areas. A shape is a point alone or a
circle around one; `area` is the one operation every shape supports, and
`Stack` keeps shapes in the order they were pushed.

## Examples

A shape and its area:

```ernest
let c = Template.circle(Template.Point(x = 0, y = 0), 2);
Template.area(c)
// => 12
```

A stack of shapes, pushed and popped:

```ernest
let s = Template.Stack.push(Template.Dot(Template.Point(x = 1, y = 1)), Template.Stack.empty);
match Template.Stack.pop(s) {
    Some(#(top, _)) -> Template.area(top)
  | None -> -1
}
// => 0
```

## See also

`Int` (Appendix E.8) for the arithmetic used.

## Point

```ernest
type Point = Point(x : Int, y : Int)
```

*Since 0.1.0.*

A point in the plane, in whole units.

### Examples

```ernest
Template.Point(x = 1, y = 2)
// => Point(1, 2)
```

- `Point`
  - `x : Int`: The horizontal coordinate, growing to the right.
  - `y : Int`: The vertical coordinate, growing upward.

## Shape

```ernest
type Shape = Dot(Point) | Circle(centre : Point, radius : Int)
```

*Since 0.1.0.*

A shape: a point alone, or a circle of a radius around a centre.

### Examples

```ernest
Template.Circle(centre = Template.Point(x = 0, y = 0), radius = 1)
// => Circle(Point(0, 0), 1)
```

- `Dot`: A point alone; its area is zero.
- `Circle`: A circle by its centre and radius.

## Stack

```ernest
abstract type Stack with {
    empty : Stack;
    push : (Shape, Stack) -> Stack;
    pop : (Stack) -> Optional(#(Shape, Stack))
}
```

*Since 0.1.0.*

Shapes in the order they were pushed, most recent on top. The
representation is private.

### Examples

```ernest
Template.Stack.push(Template.Dot(Template.Point(x = 0, y = 0)), Template.Stack.empty)
```

### See also

`List` (Appendix E.2), which a stack is a restriction of.

- `empty : Stack`: The stack with nothing on it.
- `push : (Shape, Stack) -> Stack`: The stack with the shape on top.
- `pop : (Stack) -> Optional(#(Shape, Stack))`: The top shape and the rest, `None` when the stack is empty.

## Stack.empty

```ernest
Stack.empty : Stack
```

*Since 0.1.0.*

The stack with nothing on it.

## Stack.push

```ernest
Stack.push : (Shape, Stack) -> Stack
```

*Since 0.1.0.*

The stack with the shape on top.

## Stack.pop

```ernest
Stack.pop : (Stack) -> Optional(#(Shape, Stack))
```

*Since 0.1.0.*

The top shape and the rest, `None` when the stack is empty.

## circle

```ernest
circle : (Point, Int) -> Shape
```

*Since 0.1.0.*

The circle of the radius around the centre.

### Examples

```ernest
Template.circle(Template.Point(x = 1, y = 2), 3)
// => Circle(Point(1, 2), 3)
```

## area

```ernest
area : (Shape) -> Int
```

*Since 0.1.0.*

The area of the shape: zero for a point, three times the radius squared
for a circle, since the module has no `Float`.

### Examples

```ernest
Template.area(Template.Dot(Template.Point(x = 0, y = 0)))
// => 0
```

### See also

`circle`, which builds the shape whose area is not zero.

## checked

```ernest
checked : (Int) -> Int
```

*Since 0.1.0.*

The radius itself when it is not negative.

### Errors

Faults with `Fault("todo: negative radius")` on a negative radius, the
one fault in this module.

### Examples

```ernest
Template.checked(4)
// => 4
```

## half

```ernest
half : (Int) -> Int
```

Half of a whole number, toward zero. Private, and documented, so it
appears in the module's documentation among the exported declarations.

### Examples

```ernest
half(7)
// => 3
```

---

Generated by ernc 0.1.0 from template.ern.
