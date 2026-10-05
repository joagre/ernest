# Ernest module OrderedSet

*Since 0.3.0.*

Sets whose elements are kept in order, the order of their type's `compare`.

Use an ordered set where the elements must come out in order, or where the
smallest or the largest is wanted. Where the order does not matter, the
prelude's `Set` serves. An ordered set is a value: `put` and `remove` answer
a new set and leave the one given as it was.

**The order.** A function that needs the order says so, `needs a.compare`
(report §4.9). A call writes nothing for it: the compiler supplies the
element type's `compare` where the type is known, and a generic function
that calls one declares the requirement itself. `fromList`, `contains`,
`put`, `remove`, `union`, `intersection`, `difference` and `isSubset` need
it, and `map` and `filterMap` need their result's; the rest need none.

**Equal is one.** Two elements the order calls `Equal` are one element, and
`put` keeps the one already there.

**Everything in order.** `toList`, `foldLeft`, `foreach`, `find`, `min` and
`max` go in the set's order, and `map`, `filter`, `filterMap`, `any` and
`all` meet the elements in it. A set in another order is a set of another
type, `type Descending = Descending(Int)` with its own `compare`, and the
two cannot meet.

**What it costs.** The set is a sorted list, written over `List` with no
primitive. `put`, `contains` and `remove` take time linear in the size,
`fromList` is a sort, `n log n`, and `union`, `intersection`, `difference`
and `isSubset` are linear in the two sizes.

A set is data: `==` is structural, a set keys a `Map`, and a set can be sent
to another node (report §3.10).

## Examples

Each element once, in order:

```ernest
OrderedSet.toList(OrderedSet.fromList([3, 1, 3]))
// => [1, 3]
```

Two sets of the same elements are equal, whatever order they were made in:

```ernest
OrderedSet.fromList([2, 1]) == OrderedSet.fromList([1, 2])
// => true
```

## See also

The prelude's `Set` for a set with no order, `List.sort` for a list in
order.

## OrderedSet.Set

```ernest
abstract type Set(a)
```

A set in the order of its element type.

## OrderedSet.empty

```ernest
OrderedSet.empty : OrderedSet.Set(a)
```

The set with no elements.

## OrderedSet.fromList

```ernest
OrderedSet.fromList(list : List(a!)) : OrderedSet.Set(a!) needs a.compare
```

The set of those elements, each once.

### Examples

```ernest
OrderedSet.toList(OrderedSet.fromList(["b", "a", "b"]))
// => ["a", "b"]
```

## OrderedSet.size

```ernest
OrderedSet.size(OrderedSet.Set(a!)) : Int
```

The number of elements.

### Examples

```ernest
#(OrderedSet.size(OrderedSet.fromList([1, 1, 2])), OrderedSet.isEmpty(OrderedSet.empty))
// => #(2, true)
```

## OrderedSet.isEmpty

```ernest
OrderedSet.isEmpty(OrderedSet.Set(a!)) : Bool
```

`true` for the set with no elements.

## OrderedSet.contains

```ernest
OrderedSet.contains(OrderedSet.Set(a!), element : a!) : Bool needs a.compare
```

`true` when an element the order calls `Equal` to `element` is in the set.

### Examples

```ernest
OrderedSet.contains(OrderedSet.fromList([1, 3]), 3)
// => true
```

## OrderedSet.put

```ernest
OrderedSet.put(OrderedSet.Set(a!), element : a!) : OrderedSet.Set(a!) needs a.compare
```

The set with `element`. Where the order calls an element already there
`Equal` to it, that one is kept and `element` dropped.

### Examples

```ernest
OrderedSet.toList(OrderedSet.put(OrderedSet.fromList([1, 3]), 2))
// => [1, 2, 3]
```

## OrderedSet.remove

```ernest
OrderedSet.remove(OrderedSet.Set(a!), element : a!) : OrderedSet.Set(a!) needs a.compare
```

The set without the element the order calls `Equal` to `element`, which need
not be there.

### Examples

```ernest
OrderedSet.toList(OrderedSet.remove(OrderedSet.fromList([1, 2]), 1))
// => [2]
```

## OrderedSet.map

```ernest
OrderedSet.map(OrderedSet.Set(a), f : (a) -> b! with e) : OrderedSet.Set(b!) with e needs b.compare
```

The set of `f`'s result for each element, met in order, in the order of the
results' type. Two results that order calls `Equal` become one, so the
result may be smaller.

### Examples

```ernest
OrderedSet.toList(OrderedSet.map(OrderedSet.fromList([2, 1]), fn(n) = n * 10))
// => [10, 20]
```

## OrderedSet.filter

```ernest
OrderedSet.filter(OrderedSet.Set(a!), keep : (a!) -> Bool with e) : OrderedSet.Set(a!) with e
```

The elements `keep` holds for, in order.

### Examples

```ernest
OrderedSet.toList(OrderedSet.filter(OrderedSet.fromList([1, 2, 3]), fn(n) = n > 1))
// => [2, 3]
```

## OrderedSet.filterMap

```ernest
OrderedSet.filterMap(OrderedSet.Set(a), f : (a) -> Optional(b!) with e) : OrderedSet.Set(b!) with e needs b.compare
```

The values of `f`'s `Some` results, as a set in the order of their type.

### Examples

```ernest
OrderedSet.toList(OrderedSet.filterMap(OrderedSet.fromList(["1", "x"]), String.toInt))
// => [1]
```

## OrderedSet.foldLeft

```ernest
OrderedSet.foldLeft(OrderedSet.Set(a), acc : b, step : (b, a) -> b with e) : b with e
```

The accumulator after `step` has seen each element in order, the accumulator
first.

### Examples

```ernest
OrderedSet.foldLeft(OrderedSet.fromList([1, 2]), 0, Int.+)
// => 3
```

## OrderedSet.foreach

```ernest
OrderedSet.foreach(OrderedSet.Set(a), f : (a) -> Unit with e) : Unit with e
```

Applies `f` to each element in order, for its effect.

### Examples

```ernest
OrderedSet.foreach(OrderedSet.fromList(["a"]), Io.println)
// => Unit
```

## OrderedSet.any

```ernest
OrderedSet.any(OrderedSet.Set(a!), test : (a!) -> Bool with e) : Bool with e
```

`true` when `test` holds for some element.

### Examples

```ernest
#(OrderedSet.any(OrderedSet.fromList([1]), fn(n) = n > 0),
  OrderedSet.all(OrderedSet.fromList([1]), fn(n) = n > 1))
// => #(true, false)
```

## OrderedSet.all

```ernest
OrderedSet.all(OrderedSet.Set(a!), test : (a!) -> Bool with e) : Bool with e
```

`true` when `test` holds for every element, and for the set with no
elements.

## OrderedSet.find

```ernest
OrderedSet.find(OrderedSet.Set(a!), test : (a!) -> Bool with e) : Optional(a!) with e
```

The first element in order that `test` holds for.

### Examples

```ernest
OrderedSet.find(OrderedSet.fromList([3, 1, 2]), fn(n) = n > 1)
// => Some(2)
```

## OrderedSet.toList

```ernest
OrderedSet.toList(OrderedSet.Set(a)) : List(a)
```

The elements, in order.

## OrderedSet.min

```ernest
OrderedSet.min(OrderedSet.Set(a!)) : Optional(a!)
```

The first element in order, or `None` for the set with no elements.

### Examples

```ernest
#(OrderedSet.min(OrderedSet.fromList([2, 1])), OrderedSet.max(OrderedSet.fromList([2, 1])))
// => #(Some(1), Some(2))
```

## OrderedSet.max

```ernest
OrderedSet.max(OrderedSet.Set(a!)) : Optional(a!)
```

The last element in order, or `None` for the set with no elements.

## OrderedSet.union

```ernest
OrderedSet.union(OrderedSet.Set(a!), OrderedSet.Set(a!)) : OrderedSet.Set(a!) needs a.compare
```

The elements of both.

### Examples

```ernest
OrderedSet.toList(OrderedSet.union(OrderedSet.fromList([1]), OrderedSet.fromList([2])))
// => [1, 2]
```

## OrderedSet.intersection

```ernest
OrderedSet.intersection(OrderedSet.Set(a!), OrderedSet.Set(a!)) : OrderedSet.Set(a!) needs a.compare
```

The elements in both.

### Examples

```ernest
OrderedSet.toList(OrderedSet.intersection(OrderedSet.fromList([1, 2]),
                                          OrderedSet.fromList([2, 3])))
// => [2]
```

## OrderedSet.difference

```ernest
OrderedSet.difference(OrderedSet.Set(a!), OrderedSet.Set(a!)) : OrderedSet.Set(a!) needs a.compare
```

The elements of the first set that are not in the second.

### Examples

```ernest
OrderedSet.toList(OrderedSet.difference(OrderedSet.fromList([1, 2]),
                                        OrderedSet.fromList([2, 3])))
// => [1]
```

## OrderedSet.isSubset

```ernest
OrderedSet.isSubset(OrderedSet.Set(a!), OrderedSet.Set(a!)) : Bool needs a.compare
```

`true` when every element of the first set is in the second.

### Examples

```ernest
OrderedSet.isSubset(OrderedSet.fromList([1]), OrderedSet.fromList([1, 2]))
// => true
```

---

Generated by ern 0.3.1 from ordered_set.ern.
