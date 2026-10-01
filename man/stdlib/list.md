# Ernest module List

*Since 0.1.0.*

Operations on `List(a)`, the singly linked list of the language (report
§3.3). `[]` is the empty list and `::` puts an element in front, so
neither is a function here, and `toList` and `fromList` would be the
identity, so the module has neither. `contains`, `remove`, and
`unique` compare elements, so their element type needs equality
(report §3.10).

## Examples

```ernest
List.map([1, 2, 3], fn(n) = n * 2) <> [0]
// => [2, 4, 6, 0]
```

```ernest
List.foldLeft(List.filter(List.range(1, 10), fn(n) = n % 2 == 0), 0, Int.+)
// => 30
```

```ernest
List.sort(["pear", "fig", "apple"], String.compare)
// => ["apple", "fig", "pear"]
```

## See also

`Map` and `Set` for lookup by key, `String.toList` for the characters of
a string.

## List.<>

```ernest
List.<> : (List(a), List(a)) -> List(a)
```

The elements of the first list, then those of the second.

### Examples

```ernest
[1, 2] <> [3]
// => [1, 2, 3]
```

## List.size

```ernest
List.size : (List(a!)) -> Int
```

The number of elements.

### Examples

```ernest
#(List.size([1, 2, 3]), List.isEmpty([]))
// => #(3, true)
```

## List.isEmpty

```ernest
List.isEmpty : (List(a!)) -> Bool
```

`true` for the empty list.

## List.contains

```ernest
List.contains : (List(a=!), a=!) -> Bool
```

`true` when some element equals `x`.

### Examples

```ernest
#(List.contains([1, 2], 2), List.contains([1, 2], 3))
// => #(true, false)
```

## List.get

```ernest
List.get : (List(a!), Int) -> Optional(a!)
```

The element at index `i`, counting from 0, or `None` beyond either end.

### Examples

```ernest
#(List.get(["a", "b"], 1), List.get(["a", "b"], 2))
// => #(Some("b"), None)
```

## List.remove

```ernest
List.remove : (List(a=!), a=!) -> List(a=!)
```

The list without the first element that equals `x`, or the list itself
when none does.

### Examples

```ernest
List.remove([1, 2, 1], 1)
// => [2, 1]
```

## List.map

```ernest
List.map : (List(a), (a) -> b with e) -> List(b) with e
```

The function applied to each element, in order.

## List.filter

```ernest
List.filter : (List(a!), (a!) -> Bool with e) -> List(a!) with e
```

The elements the predicate holds for, in order.

### Examples

```ernest
List.filter([1, 2, 3, 4], fn(n) = n > 2)
// => [3, 4]
```

## List.filterMap

```ernest
List.filterMap : (List(a), (a) -> Optional(b) with e) -> List(b) with e
```

The values of the `Some` results, in order: mapping and filtering in one
pass.

### Examples

```ernest
List.filterMap(["1", "x", "3"], String.toInt)
// => [1, 3]
```

## List.foldLeft

```ernest
List.foldLeft : (List(a), b, (b, a) -> b with e) -> b with e
```

The accumulator after the function has seen each element from the left,
the accumulator first.

## List.foldRight

```ernest
List.foldRight : (List(a), b, (a, b) -> b with e) -> b with e
```

The accumulator after the function has seen each element from the
right, the element first.

### Examples

```ernest
List.foldRight(["a", "b"], "", fn(s, acc) = s <> acc)
// => "ab"
```

## List.foreach

```ernest
List.foreach : (List(a), (a) -> Unit with e) -> Unit with e
```

The function applied to each element for its effect.

### Examples

```ernest
List.foreach([1, 2], fn(n) = Io.println(Int.toString(n)))
// => Unit
```

## List.any

```ernest
List.any : (List(a!), (a!) -> Bool with e) -> Bool with e
```

`true` when the predicate holds for some element; it is not called after
the first that satisfies it.

### Examples

```ernest
#(List.any([1, 2], fn(n) = n > 1), List.all([1, 2], fn(n) = n > 1))
// => #(true, false)
```

## List.all

```ernest
List.all : (List(a!), (a!) -> Bool with e) -> Bool with e
```

`true` when the predicate holds for every element, and for the empty
list; it is not called after the first that fails.

## List.find

```ernest
List.find : (List(a!), (a!) -> Bool with e) -> Optional(a!) with e
```

The first element the predicate holds for.

### Examples

```ernest
List.find([1, 2, 3], fn(n) = n > 1)
// => Some(2)
```

## List.last

```ernest
List.last : (List(a!)) -> Optional(a!)
```

The last element.

### Examples

```ernest
let empty : List(Int) = [];
#(List.last([1, 2]), List.last(empty))
// => #(Some(2), None)
```

## List.take

```ernest
List.take : (List(a!), Int) -> List(a!)
```

The first `n` elements, or all of them when there are fewer; `n` below 0
takes none.

### Examples

```ernest
#(List.take([1, 2, 3], 2), List.drop([1, 2, 3], 2))
// => #([1, 2], [3])
```

## List.drop

```ernest
List.drop : (List(a!), Int) -> List(a!)
```

All but the first `n` elements; `n` below 0 drops none.

## List.dropLast

```ernest
List.dropLast : (List(a!), Int) -> List(a!)
```

All but the last `n` elements; `n` below 0 drops none.

### Examples

```ernest
#(List.dropLast([1, 2, 3], 1), List.dropLast([1, 2, 3], 5))
// => #([1, 2], [])
```

## List.span

```ernest
List.span : (List(a!), (a!) -> Bool with e) -> #(List(a!), List(a!)) with e
```

The longest prefix the predicate holds for, and the rest.

### Examples

```ernest
List.span([1, 2, 3, 1], fn(n) = n < 3)
// => #([1, 2], [3, 1])
```

## List.partition

```ernest
List.partition : (List(a!), (a!) -> Bool with e) -> #(List(a!), List(a!)) with e
```

The elements the predicate holds for and those it does not, each in
order.

### Examples

```ernest
List.partition([1, 2, 3, 4], fn(n) = n % 2 == 0)
// => #([2, 4], [1, 3])
```

## List.unique

```ernest
List.unique : (List(a=!)) -> List(a=!)
```

The first occurrence of each element, in order.

### Examples

```ernest
List.unique([2, 1, 2, 3])
// => [2, 1, 3]
```

## List.indexed

```ernest
List.indexed : (List(a)) -> List(#(Int, a))
```

Each element with its index, counting from 0.

### Examples

```ernest
List.indexed(["a", "b"])
// => [#(0, "a"), #(1, "b")]
```

## List.repeat

```ernest
List.repeat : (a!, Int) -> List(a!)
```

`n` copies of the value; `n` below 0 gives none.

### Examples

```ernest
List.repeat("ha", 2)
// => ["ha", "ha"]
```

## List.reverse

```ernest
List.reverse : (List(a)) -> List(a)
```

The elements in the opposite order.

### Examples

```ernest
List.reverse([1, 2, 3])
// => [3, 2, 1]
```

## List.sort

```ernest
List.sort : (List(a!), (a!, a!) -> Ordering with e) -> List(a!) with e
```

The elements in the order `compare` gives, stable: two elements it calls
`Equal` keep the order they had.

### Examples

```ernest
List.sort([3, 1, 2], Int.compare)
// => [1, 2, 3]
```

## List.zip

```ernest
List.zip : (List(a!), List(b!)) -> List(#(a!, b!))
```

The pairs of elements at the same index, to the length of the shorter
list.

### Examples

```ernest
List.zip([1, 2, 3], ["a", "b"])
// => [#(1, "a"), #(2, "b")]
```

## List.unzip

```ernest
List.unzip : (List(#(a, b))) -> #(List(a), List(b))
```

The first components and the second components, each in order.

### Examples

```ernest
List.unzip([#(1, "a"), #(2, "b")])
// => #([1, 2], ["a", "b"])
```

## List.flatMap

```ernest
List.flatMap : (List(a), (a) -> List(b) with e) -> List(b) with e
```

The lists the function gives, one after another.

### Examples

```ernest
List.flatMap([1, 2], fn(n) = [n, n * 10])
// => [1, 10, 2, 20]
```

## List.range

```ernest
List.range : (Int, Int) -> List(Int)
```

The integers from the first to the second, both included; empty when the
first is greater.

### Examples

```ernest
#(List.range(1, 4), List.range(2, 1))
// => #([1, 2, 3, 4], [])
```

## List.tryMap

```ernest
List.tryMap : (List(a), (a) -> Either(e, b) with x) -> Either(e, List(b)) with x
```

The mapped elements, or the first `Left` the function gives, which ends
the walk.

### Examples

```ernest
List.tryMap(["1", "x"], fn(s) = Either.fromOptional(String.toInt(s), s))
// => Left("x")
```

## List.tryFold

```ernest
List.tryFold : (List(a), b, (b, a) -> Either(e, b) with x) -> Either(e, b) with x
```

The accumulator after the function has seen each element, or the first
`Left` it gives, which ends the walk.

### Examples

```ernest
List.tryFold([1, 2], 0, fn(acc, n) = if n > 1 then Left("big") else Right(acc + n))
// => Left("big")
```

---

Generated by ern 0.2.0 from list.ern.
