# Ernest module List

*Since 0.1.0.*

Lists: values in order, the same type throughout.

Use a list for values in an order, read from the front. For a value
looked up by its key use a `Map`, for membership a `Set`, and for text a
`String`. A list is a value: every function here answers a new list and
leaves the one it was given as it was.

`[]` is the empty list, and `x :: rest` the list with `x` in front of
`rest`; both are the language's, so neither is a function here.

**Cost.** A list is walked from its front. Putting an element in front
with `::` costs nothing, whatever the list's length. `size`, `get`,
`last` and `<>` walk the list, and take time in proportion to its
length. A list built one element at a time is built in front, and
`reverse`d once at the end.

**Equality.** `contains`, `remove` and `unique` compare elements with
`==`, so the element type needs equality: a list of functions has none
of the three.

**Replies.** A list may hold a `Reply`, which must be answered exactly once
(report §6.6). A function that drops or copies elements, `size`, `filter`
and `take` among them, refuses such a list, and its printed type marks the
element `!`: `List.size : (List(a!)) -> Int`. One that uses each element
once, `map` or `foldLeft`, takes it.

## Examples

Each element doubled, and a list appended:

```ernest
List.map([1, 2, 3], fn(n) = n * 2) <> [0]
// => [2, 4, 6, 0]
```

The even numbers from 1 to 10, summed:

```ernest
List.foldLeft(List.filter(List.range(1, 10), fn(n) = n % 2 == 0), 0, Int.+)
// => 30
```

Words sorted by the order of `String`:

```ernest
List.sort(["pear", "fig", "apple"], String.compare)
// => ["apple", "fig", "pear"]
```

## See also

`Map` and `Set` for lookup by key, `String.toList` for the characters of
a string.

## List.<>

```ernest
List.<>(list : List(a), other : List(a)) : List(a)
```

The elements of the first list, then those of the second. The first list
is copied, so the cost grows with its length, and not with the second's.

### Examples

```ernest
[1, 2] <> [3]
// => [1, 2, 3]
```

## List.size

```ernest
List.size(list : List(a!)) : Int
```

The number of elements. The whole list is walked to count them.

### Examples

```ernest
#(List.size([1, 2, 3]), List.isEmpty([]))
// => #(3, true)
```

## List.isEmpty

```ernest
List.isEmpty(list : List(a!)) : Bool
```

`true` for the empty list.

## List.contains

```ernest
List.contains(list : List(a=!), element : a=!) : Bool
```

`true` when some element of the list is `==` to `element`.

### Examples

```ernest
#(List.contains([1, 2], 2), List.contains([1, 2], 3))
// => #(true, false)
```

## List.get

```ernest
List.get(list : List(a!), index : Int) : Optional(a!)
```

The element at `index`, counting from 0, or `None` where the list has
no element there: past its end, or at an index below 0. The list is
walked to the index.

### Examples

```ernest
#(List.get(["a", "b"], 1), List.get(["a", "b"], 2))
// => #(Some("b"), None)
```

## List.remove

```ernest
List.remove(list : List(a=!), element : a=!) : List(a=!)
```

The list without the first element that is `==` to `element`. Later
elements equal to it stay. A list without such an element is answered as
it is.

### Examples

```ernest
List.remove([1, 2, 1], 1)
// => [2, 1]
```

## List.map

```ernest
List.map(list : List(a), f : (a) -> b with e) : List(b) with e
```

The list of `f(x)` for each element `x`, in order. `f` is called for the
elements from the first.

## List.filter

```ernest
List.filter(list : List(a!), keep : (a!) -> Bool with e) : List(a!) with e
```

The elements `keep` answers `true` for, in their order.

### Examples

```ernest
List.filter([1, 2, 3, 4], fn(n) = n > 2)
// => [3, 4]
```

## List.filterMap

```ernest
List.filterMap(list : List(a), f : (a) -> Optional(b) with e) : List(b) with e
```

The values `f` answers `Some` for, in order. An element `f` answers
`None` for is left out, so it maps and filters in one pass.

### Examples

```ernest
List.filterMap(["1", "x", "3"], String.toInt)
// => [1, 3]
```

## List.foldLeft

```ernest
List.foldLeft(list : List(a), acc : b, step : (b, a) -> b with e) : b with e
```

What `step` answers for the last element. `step` is called on each element
in order: first with `acc` and the first element, then with what it answered
before and the next element. The empty list answers `acc`.

### Examples

```ernest
List.foldLeft([1, 2, 3], 0, fn(sum, n) = sum + n)
// => 6
```

## List.foldRight

```ernest
List.foldRight(list : List(a), acc : b, step : (a, b) -> b with e) : b with e
```

The elements folded into one value, from the last. `step(x, acc)` is
called with the given `acc` for the last element, and with what `step`
answered for the one after it for the rest. The empty list answers
`acc`.

### Examples

```ernest
List.foldRight(["a", "b"], "", fn(s, acc) = s <> acc)
// => "ab"
```

## List.foreach

```ernest
List.foreach(list : List(a), f : (a) -> Unit with e) : Unit with e
```

Calls `f` for each element, in order, for its effect, and answers `Unit`.

### Examples

Prints `1` and `2`, each on a line:

```ernest
List.foreach([1, 2], fn(n) = Io.println(Int.toString(n)))
// => Unit
```

## List.any

```ernest
List.any(list : List(a!), test : (a!) -> Bool with e) : Bool with e
```

`true` when `test` holds for at least one element, and `false` for the
empty list. `test` is not called after the first element it holds for.

### Examples

```ernest
#(List.any([1, 2], fn(n) = n > 1), List.all([1, 2], fn(n) = n > 1))
// => #(true, false)
```

## List.all

```ernest
List.all(list : List(a!), test : (a!) -> Bool with e) : Bool with e
```

`true` when `test` holds for every element, and for the empty list.
`test` is not called after the first element it fails for.

## List.find

```ernest
List.find(list : List(a!), test : (a!) -> Bool with e) : Optional(a!) with e
```

The first element `test` holds for, or `None` where there is none.

### Examples

```ernest
List.find([1, 2, 3], fn(n) = n > 1)
// => Some(2)
```

## List.last

```ernest
List.last(list : List(a!)) : Optional(a!)
```

The last element, or `None` for the empty list. The whole list is walked
to reach it.

### Examples

The empty list needs its element type written, since nothing else settles
it:

```ernest
{
    let empty : List(Int) = [];
    #(List.last([1, 2]), List.last(empty))
}
// => #(Some(2), None)
```

## List.take

```ernest
List.take(list : List(a!), count : Int) : List(a!)
```

The first `count` elements, or all of them where there are fewer. A
`count` below 0 takes none.

### Examples

```ernest
#(List.take([1, 2, 3], 2), List.drop([1, 2, 3], 2))
// => #([1, 2], [3])
```

## List.drop

```ernest
List.drop(list : List(a!), count : Int) : List(a!)
```

The list without its first `count` elements, or empty where there are
fewer. A `count` below 0 drops none.

## List.dropLast

```ernest
List.dropLast(list : List(a!), count : Int) : List(a!)
```

The list without its last `count` elements, or empty where there are
fewer. A `count` below 0 drops none.

### Examples

```ernest
#(List.dropLast([1, 2, 3], 1), List.dropLast([1, 2, 3], 5))
// => #([1, 2], [])
```

## List.span

```ernest
List.span(list : List(a!), test : (a!) -> Bool with e) : #(List(a!), List(a!)) with e
```

The list split where `test` first fails: the elements before that one,
all of which `test` holds for, and the rest, from that one on.

### Examples

```ernest
List.span([1, 2, 3, 1], fn(n) = n < 3)
// => #([1, 2], [3, 1])
```

## List.partition

```ernest
List.partition(list : List(a!), test : (a!) -> Bool with e) : #(List(a!), List(a!)) with e
```

The elements `test` holds for, and those it does not, each in their
order.

### Examples

```ernest
List.partition([1, 2, 3, 4], fn(n) = n % 2 == 0)
// => #([2, 4], [1, 3])
```

## List.unique

```ernest
List.unique(list : List(a=!)) : List(a=!)
```

The list without repeats: the first occurrence of each element is kept,
in order. Each element is compared with every later one, so the cost
grows with the square of the length; for a long list, `Set.fromList`
or `OrderedSet.fromList` is quicker where the order may change.

### Examples

```ernest
List.unique([2, 1, 2, 3])
// => [2, 1, 3]
```

## List.indexed

```ernest
List.indexed(list : List(a)) : List(#(Int, a))
```

Each element paired with its index, counting from 0.

### Examples

```ernest
List.indexed(["a", "b"])
// => [#(0, "a"), #(1, "b")]
```

## List.repeat

```ernest
List.repeat(element : a!, count : Int) : List(a!)
```

A list of `count` copies of `element`. A `count` below 0 gives the empty
list.

### Examples

```ernest
List.repeat("ha", 2)
// => ["ha", "ha"]
```

## List.reverse

```ernest
List.reverse(list : List(a)) : List(a)
```

The elements in the opposite order.

### Examples

```ernest
List.reverse([1, 2, 3])
// => [3, 2, 1]
```

## List.sort

```ernest
List.sort(list : List(a!), compare : (a!, a!) -> Ordering with e) : List(a!) with e
```

The elements sorted by `compare`, smallest first. `compare` is an order
(report §3.10), `Int.compare` or one of the program's.

The sort is stable: two elements `compare` calls `Equal` keep the order they
had. So to sort by age, and by name among equal ages, sort by name first and
then by age.

### Examples

```ernest
List.sort([3, 1, 2], Int.compare)
// => [1, 2, 3]
```

## List.zip

```ernest
List.zip(list : List(a!), other : List(b!)) : List(#(a!, b!))
```

The pairs of the elements at each index of both lists. The longer list's
extra elements are left out.

### Examples

```ernest
List.zip([1, 2, 3], ["a", "b"])
// => [#(1, "a"), #(2, "b")]
```

## List.unzip

```ernest
List.unzip(pairs : List(#(a, b))) : #(List(a), List(b))
```

The pairs taken apart: the list of their first components and the list
of their second, each in order.

### Examples

```ernest
List.unzip([#(1, "a"), #(2, "b")])
// => #([1, 2], ["a", "b"])
```

## List.flatMap

```ernest
List.flatMap(list : List(a), f : (a) -> List(b) with e) : List(b) with e
```

The lists `f` answers for the elements, joined in order.

### Examples

```ernest
List.flatMap([1, 2], fn(n) = [n, n * 10])
// => [1, 10, 2, 20]
```

## List.range

```ernest
List.range(first : Int, last : Int) : List(Int)
```

The integers from `first` to `last`, both included, counting up. Where
`first` is greater than `last` the list is empty.

### Examples

```ernest
#(List.range(1, 4), List.range(2, 1))
// => #([1, 2, 3, 4], [])
```

## List.tryMap

```ernest
List.tryMap(list : List(a!), step : (a!) -> Either(e, b!) with x) : Either(e, List(b!)) with x
```

Calls `step` on each element in order. Where every call answers `Right(y)`,
the answer is `Right` of the list of the `y`s. At the first `Left(e)` the
answer is `Left(e)`, and `step` is not called again. The empty list answers
`Right([])`.

### Examples

```ernest
List.tryMap(["1", "x"], fn(s) = Either.fromOptional(String.toInt(s), s))
// => Left("x")
```

## List.tryFold

```ernest
List.tryFold(list : List(a!), acc : b, step : (b, a!) -> Either(e, b) with x) : Either(e, b) with x
```

Folds the list as `foldLeft` does, `step` answering `Right` of the next
accumulator. Where every call answers a `Right`, the answer is `Right` of
the last accumulator. At the first `Left(e)` the answer is `Left(e)`, and
`step` is not called again. The empty list answers `Right(acc)`.

### Examples

```ernest
List.tryFold([1, 2], 0, fn(acc, n) = if n > 1 then Left("big") else Right(acc + n))
// => Left("big")
```

---

Generated by ern 0.3.1 from list.ern.
