# Ernest module Set

*Since 0.1.0.*

Finite sets: each element once, in no order.

Use a set to ask whether a value is among others, and to keep each value
once. For values in an order use a `List`, for elements in their own order
an `OrderedSet`, and for values looked up by a key a `Map`. A set is a
value: `put` and `remove` answer a new set and leave the one given as it
was.

The element type needs equality, which the `=` in `Set(a=)` says: a set of
functions or addresses is a type error.

A set has no order. `toList`, `foldLeft`, `foreach` and `find` give the
elements in an order that is not specified, and `map`, `filter`,
`filterMap`, `any` and `all` call their function for the elements in such an
order.

## Examples

An element put in a set is in it:

```ernest
Set.contains(Set.put(Set.empty, "a"), "a")
// => true
```

The elements of one set that are not in another; a set has no order, so the
list is sorted to compare it:

```ernest
List.sort(Set.toList(Set.difference(Set.fromList([1, 2, 3]), Set.fromList([2]))), Int.compare)
// => [1, 3]
```

## See also

`Map` for elements with values, `List.unique` for order kept.

## Set.empty

```ernest
Set.empty : Set(a=)
```

The set with no elements.

## Set.size

```ernest
Set.size(set : Set(a=!)) : Int
```

The number of elements.

### Examples

```ernest
#(Set.size(Set.fromList([1, 1, 2])), Set.isEmpty(Set.empty))
// => #(2, true)
```

## Set.isEmpty

```ernest
Set.isEmpty(set : Set(a=!)) : Bool
```

`true` for the set with no elements.

## Set.contains

```ernest
Set.contains(set : Set(a=!), element : a=!) : Bool
```

`true` when `element` is in the set.

## Set.put

```ernest
Set.put(set : Set(a=!), element : a=!) : Set(a=!)
```

The set with `element` in it. A set that already holds it is answered as it
is.

## Set.remove

```ernest
Set.remove(set : Set(a=!), element : a=!) : Set(a=!)
```

The set without `element`. A set that does not hold it is answered as it is.

### Examples

```ernest
Set.toList(Set.remove(Set.fromList([1, 2]), 2))
// => [1]
```

## Set.map

```ernest
Set.map(set : Set(a=!), f : (a=!) -> b=! with e) : Set(b=!) with e
```

The set of `f(x)` for each element `x`. Two elements `f` maps to equal
values become one, so the result may be smaller.

### Examples

```ernest
List.sort(Set.toList(Set.map(Set.fromList([1, 2]), fn(n) = n * 10)), Int.compare)
// => [10, 20]
```

## Set.filter

```ernest
Set.filter(set : Set(a=!), keep : (a=!) -> Bool with e) : Set(a=!) with e
```

The set of the elements `keep` answers `true` for.

### Examples

```ernest
Set.toList(Set.filter(Set.fromList([1, 2, 3]), fn(n) = n > 2))
// => [3]
```

## Set.filterMap

```ernest
Set.filterMap(set : Set(a=!), f : (a=!) -> Optional(b=!) with e) : Set(b=!) with e
```

The set of the values `f` answers `Some` for; an element `f` answers `None`
for is left out.

### Examples

```ernest
Set.toList(Set.filterMap(Set.fromList(["1", "x"]), String.toInt))
// => [1]
```

## Set.foldLeft

```ernest
Set.foldLeft(set : Set(a=!), acc : b, step : (b, a=!) -> b with e) : b with e
```

The elements folded into one value. `step(acc, x)` is called with the given
`acc` for the first element met, and with what `step` answered before for
the rest. The order is unspecified, so `step` should give the same result in
any order.

### Examples

```ernest
Set.foldLeft(Set.fromList([1, 2]), 0, Int.+)
// => 3
```

## Set.foreach

```ernest
Set.foreach(set : Set(a=!), f : (a=!) -> Unit with e) : Unit with e
```

Calls `f` for each element, for its effect, in unspecified order.

### Examples

```ernest
Set.foreach(Set.fromList(["a"]), Io.println)
// => Unit
```

## Set.any

```ernest
Set.any(set : Set(a=!), test : (a=!) -> Bool with e) : Bool with e
```

`true` when `test` holds for at least one element, and `false` for the empty
set.

### Examples

```ernest
#(Set.any(Set.fromList([1]), fn(n) = n > 0), Set.all(Set.fromList([1]), fn(n) = n > 1))
// => #(true, false)
```

## Set.all

```ernest
Set.all(set : Set(a=!), test : (a=!) -> Bool with e) : Bool with e
```

`true` when `test` holds for every element, and for the empty set.

## Set.find

```ernest
Set.find(set : Set(a=!), test : (a=!) -> Bool with e) : Optional(a=!) with e
```

An element `test` holds for, or `None` where there is none. Where it holds
for several, which one is answered is unspecified.

### Examples

```ernest
Set.find(Set.fromList([1, 2]), fn(n) = n > 1)
// => Some(2)
```

## Set.fromList

```ernest
Set.fromList(list : List(a=!)) : Set(a=!)
```

The set of the list's elements, each once.

## Set.toList

```ernest
Set.toList(set : Set(a=!)) : List(a=!)
```

The elements, in unspecified order.

## Set.union

```ernest
Set.union(set : Set(a=!), other : Set(a=!)) : Set(a=!)
```

The set of the elements in either set.

### Examples

```ernest
List.sort(Set.toList(Set.union(Set.fromList([1]), Set.fromList([2]))), Int.compare)
// => [1, 2]
```

## Set.intersection

```ernest
Set.intersection(set : Set(a=!), other : Set(a=!)) : Set(a=!)
```

The set of the elements in both sets.

### Examples

```ernest
Set.toList(Set.intersection(Set.fromList([1, 2]), Set.fromList([2, 3])))
// => [2]
```

## Set.difference

```ernest
Set.difference(set : Set(a=!), other : Set(a=!)) : Set(a=!)
```

The elements of `set` that are not in `other`.

## Set.isSubset

```ernest
Set.isSubset(set : Set(a=!), other : Set(a=!)) : Bool
```

`true` when every element of `set` is in `other`. The empty set is a subset
of every set.

### Examples

```ernest
Set.isSubset(Set.fromList([1]), Set.fromList([1, 2]))
// => true
```

---

Generated by ern 0.3.1 from set.ern.
