# Ernest module Map

*Since 0.1.0.*

Finite maps from keys to values, the prelude's type `Map(k=, v)`.

Use a map to look a value up by its key. A map is a value: `put` and
`remove` answer a new map and leave the one they were given as it was.
For elements without values use a `Set`, for order and position a
`List`, and for keys kept in their order an `OrderedMap`.

The key type needs equality, which the `=` in `Map(k=, v)` says: a key
that holds a function or an address is a type error.

A map has no order. `keys`, `values`, `toList`, `foldLeft`, `foreach`
and `find` give the entries in an order that is not specified, and
`map`, `filter`, `filterMap`, `any`, `all` and `mergeWith` call their
function for the entries in such an order. Sort the result where the
order matters.

## Examples

An entry put into the empty map and read back:

```ernest
Map.get(Map.put(Map.empty, "a", 1), "a")
// => Some(1)
```

A map built from pairs, and every value changed:

```ernest
Map.toList(Map.map(Map.fromList([#("a", 1)]), fn(_, n) = n * 10))
// => [#("a", 10)]
```

## See also

`Set` for elements without values, `List` for order and position,
`OrderedMap` for keys in their order.

## Map.empty

```ernest
Map.empty : Map(k=, v)
```

The map with no entries.

## Map.size

```ernest
Map.size(map : Map(k=!, v!)) : Int
```

The number of entries.

### Examples

```ernest
#(Map.size(Map.fromList([#("a", 1)])), Map.isEmpty(Map.empty))
// => #(1, true)
```

## Map.isEmpty

```ernest
Map.isEmpty(map : Map(k=!, v!)) : Bool
```

`true` for the map with no entries.

## Map.contains

```ernest
Map.contains(map : Map(k=!, v!), key : k=!) : Bool
```

`true` when the map has an entry with that key.

### Examples

```ernest
#(Map.contains(Map.fromList([#("a", 1)]), "a"), Map.contains(Map.empty, "a"))
// => #(true, false)
```

## Map.get

```ernest
Map.get(map : Map(k=!, v!), key : k=!) : Optional(v!)
```

The value at that key, or `None` where the map has no entry for it.

### Examples

```ernest
#(Map.get(Map.fromList([#("a", 1)]), "a"), Map.get(Map.fromList([#("a", 1)]), "b"))
// => #(Some(1), None)
```

## Map.put

```ernest
Map.put(map : Map(k=!, v!), key : k=!, value : v!) : Map(k=!, v!)
```

The map with that entry added. An entry the map had at that key is
replaced. The map given is left as it was.

### Examples

```ernest
{
    let one = Map.fromList([#("a", 1)]);
    let two = Map.put(one, "a", 2);
    #(Map.get(one, "a"), Map.get(two, "a"))
}
// => #(Some(1), Some(2))
```

## Map.remove

```ernest
Map.remove(map : Map(k=!, v!), key : k=!) : Map(k=!, v!)
```

The map without the entry at that key. A map that has no such entry is
answered as it is.

### Examples

```ernest
Map.toList(Map.remove(Map.fromList([#("a", 1)]), "a"))
// => []
```

## Map.update

```ernest
Map.update(map : Map(k=!, v!), key : k=!, f : (Optional(v!)) -> v! with e) : Map(k=!, v!) with e
```

The map with the value at that key replaced by `f` of it. `f` is given
`Some(value)` where the key has an entry and `None` where it has none, so
one call adds an entry or changes it.

### Examples

```ernest
Map.get(Map.update(Map.empty, "n", fn(o) = Optional.withDefault(o, 0) + 1), "n")
// => Some(1)
```

## Map.map

```ernest
Map.map(map : Map(k=!, v!), f : (k=!, v!) -> w! with e) : Map(k=!, w!) with e
```

The map with each value replaced by `f(key, value)`. The keys stay as
they are.

## Map.filter

```ernest
Map.filter(map : Map(k=!, v!), keep : (k=!, v!) -> Bool with e) : Map(k=!, v!) with e
```

The map of the entries `keep(key, value)` is `true` for.

### Examples

```ernest
Map.toList(Map.filter(Map.fromList([#("a", 1), #("b", 2)]), fn(_, n) = n > 1))
// => [#("b", 2)]
```

## Map.filterMap

```ernest
Map.filterMap(map : Map(k=!, v!), f : (k=!, v!) -> Optional(w!) with e) : Map(k=!, w!) with e
```

The map of the entries `f(key, value)` answers `Some(w)` for, each with
`w` as its value. An entry `f` answers `None` for is left out.

### Examples

```ernest
Map.toList(Map.filterMap(Map.fromList([#("a", "1"), #("b", "x")]), fn(_, s) = String.toInt(s)))
// => [#("a", 1)]
```

## Map.foldLeft

```ernest
Map.foldLeft(map : Map(k=!, v!), acc : b, step : (b, k=!, v!) -> b with e) : b with e
```

The entries folded into one value. `step(acc, key, value)` is called for
each entry, with `acc` for the first and what `step` answered for the
entry before for the rest. The order of the entries is unspecified, so
`step` should give the same result in any order.

### Examples

```ernest
Map.foldLeft(Map.fromList([#("a", 1), #("b", 2)]), 0, fn(acc, key, n) = acc + n)
// => 3
```

## Map.foreach

```ernest
Map.foreach(map : Map(k=!, v!), f : (k=!, v!) -> Unit with e) : Unit with e
```

Calls `f(key, value)` for each entry, for its effect, in unspecified
order.

### Examples

```ernest
Map.foreach(Map.fromList([#("a", 1)]), fn(key, _) = Io.println(key))
// => Unit
```

## Map.any

```ernest
Map.any(map : Map(k=!, v!), test : (k=!, v!) -> Bool with e) : Bool with e
```

`true` when `test(key, value)` holds for at least one entry, and `false`
for the map with no entries.

### Examples

```ernest
#(Map.any(Map.fromList([#("a", 1)]), fn(_, n) = n > 0),
  Map.all(Map.fromList([#("a", 1)]), fn(_, n) = n > 1))
// => #(true, false)
```

## Map.all

```ernest
Map.all(map : Map(k=!, v!), test : (k=!, v!) -> Bool with e) : Bool with e
```

`true` when `test(key, value)` holds for every entry, and for the map
with no entries.

## Map.find

```ernest
Map.find(map : Map(k=!, v!), test : (k=!, v!) -> Bool with e) : Optional(#(k=!, v!)) with e
```

An entry `test(key, value)` holds for, or `None` where there is none.
Where it holds for several, which one is answered is unspecified.

### Examples

```ernest
Map.find(Map.fromList([#("a", 1)]), fn(_, n) = n == 1)
// => Some(#("a", 1))
```

## Map.merge

```ernest
Map.merge(map : Map(k=!, v!), other : Map(k=!, v!)) : Map(k=!, v!)
```

The entries of both maps. Where both have a key, the second map's value
is kept.

### Examples

```ernest
Map.toList(Map.merge(Map.fromList([#("a", 1)]), Map.fromList([#("a", 2)])))
// => [#("a", 2)]
```

## Map.mergeWith

```ernest
Map.mergeWith(map : Map(k=!, v!), other : Map(k=!, v!), f : (k=!, v!, v!) -> v! with e) : Map(k=!, v!) with e
```

The entries of both maps. Where both have a key, its value is
`f(key, first, second)`, of the first map's value and the second's.

### Examples

```ernest
{
    let merged =
        Map.mergeWith(Map.fromList([#("a", 1), #("b", 1)]),
                      Map.fromList([#("a", 2), #("b", 2)]),
                      fn(key, first, second) = if key == "a" then first + second else second);
    #(Map.get(merged, "a"), Map.get(merged, "b"))
}
// => #(Some(3), Some(2))
```

## Map.fromList

```ernest
Map.fromList(pairs : List(#(k=!, v!))) : Map(k=!, v!)
```

The map of those pairs. Where a key occurs more than once, its last pair
is kept.

### Examples

```ernest
Map.toList(Map.fromList([#("a", 1), #("a", 2)]))
// => [#("a", 2)]
```

## Map.toList

```ernest
Map.toList(map : Map(k=!, v!)) : List(#(k=!, v!))
```

The entries as pairs, in unspecified order.

## Map.keys

```ernest
Map.keys(map : Map(k=!, v!)) : List(k=!)
```

The keys, in unspecified order.

### Examples

```ernest
#(Map.keys(Map.fromList([#("a", 1)])), Map.values(Map.fromList([#("a", 1)])))
// => #(["a"], [1])
```

## Map.values

```ernest
Map.values(map : Map(k=!, v!)) : List(v!)
```

The values, in unspecified order.

---

Generated by ern 0.3.1 from map.ern.
