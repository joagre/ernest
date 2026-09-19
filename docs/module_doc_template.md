# How an Ernest module is documented

The rules are the report's: §2.2 says where a doc block may stand and that its text is CommonMark, §11.4 what `ernc --doc` renders, and Appendix E.0 rule 6 what a doc block contains. This page shows them on one fictive module, `examples/template.ern`. Everything below the marker is the output of `ernc --doc examples/template.ern`, and a test keeps it so; another test type-checks every example in the module's doc blocks.

The sections of a section 3 manual page, and where each comes from:

| Manual page | Here | Written by |
|---|---|---|
| NAME | the heading, `# Module` or `## name` | `ernc --doc` |
| SYNOPSIS | the code block under the heading, the declaration or `name : type` | `ernc --doc` |
| DESCRIPTION | the doc block's first sentences | the author, mandatory |
| RETURN VALUE | the type, plus what the sentence adds that the type does not say | the author, in the sentence |
| ERRORS | `### Errors`, when the function faults; absent otherwise, by E.0 rule 4 | the author, mandatory where it faults |
| EXAMPLES | `### Examples`, one example, `## Examples` for the module | the author, mandatory |
| SEE ALSO | `### See also`, `## See also` for the module | the author, when there is something to see |

A member of an abstract type is documented at its signature entry and inherits that sentence under its own heading. A sentence on a constructor, a named field, or a signature entry is optional and renders as a list under the declaration. Headings inside a declaration's doc block are level three, since the declaration's own heading is level two; in the module's doc block they are level two.

A private declaration with a doc block appears among the exported ones.

<!-- generated: ernc --doc examples/template.ern -->
# Template

Shapes in the plane and their areas. A shape is a point alone or a
circle around one; `area` is the one operation every shape supports, and
`Stack` keeps shapes in the order they were pushed.

## Examples

```ernest
let c = Template.circle(Template.Point(x = 0, y = 0), 2);
Template.area(c)
```

## See also

`Int` (Appendix E.8) for the arithmetic used.

## Point

```ernest
type Point = Point(x : Int, y : Int)
```

A point in the plane, in whole units.

### Examples

```ernest
Template.Point(x = 1, y = 2)
```

- `Point`
  - `x : Int`: The horizontal coordinate, growing to the right.
  - `y : Int`: The vertical coordinate, growing upward.

## Shape

```ernest
type Shape = Dot(Point) | Circle(centre : Point, radius : Int)
```

A shape: a point alone, or a circle of a radius around a centre.

### Examples

```ernest
Template.Circle(centre = Template.Point(x = 0, y = 0), radius = 1)
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

The stack with nothing on it.

## Stack.push

```ernest
Stack.push : (Shape, Stack) -> Stack
```

The stack with the shape on top.

## Stack.pop

```ernest
Stack.pop : (Stack) -> Optional(#(Shape, Stack))
```

The top shape and the rest, `None` when the stack is empty.

## circle

```ernest
circle : (Point, Int) -> Shape
```

The circle of the radius around the centre.

### Examples

```ernest
Template.circle(Template.Point(x = 1, y = 2), 3)
```

## area

```ernest
area : (Shape) -> Int
```

The area of the shape: zero for a point, three times the radius squared
for a circle, since the module has no `Float`.

### Examples

```ernest
Template.area(Template.Dot(Template.Point(x = 0, y = 0)))
```

### See also

`circle`, which builds the shape whose area is not zero.

## checked

```ernest
checked : (Int) -> Int
```

The radius itself when it is not negative.

### Errors

Faults with `Fault("todo: negative radius")` on a negative radius, the
one fault in this module.

### Examples

```ernest
Template.checked(4)
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
```

