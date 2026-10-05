# Ernest module Map

*Since 0.1.0.*

Operations on `Map(k=, v)`, a finite map from keys to values (report
§9.2). The key type needs equality, which the type itself requires
(report §3.10), so a key holding a function or an address is a type
error. The order of `keys`, `values`, `toList`, `foldLeft`, `foreach`,
and `find` is unspecified, and so is the order in which `map`,
`filter`, `filterMap`, `any`, `all`, and `mergeWith` meet the entries.
The primitives are `empty`, `size`, `get`, `put`, `remove`, and
`toList`, the runtime's; the rest is written over them (report Appendix
E.0 rule 1).

## Examples

```ernest
Map.get(Map.put(Map.empty, "a", 1), "a")
// => Some(1)
```

```ernest
Map.toList(Map.map(Map.fromList([#("a", 1)]), fn(_, n) = n * 10))
// => [#("a", 10)]
```

## See also

`Set` for elements without values, `List` for order and position.

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

The value at that key.

## Map.put

```ernest
Map.put(map : Map(k=!, v!), key : k=!, value : v!) : Map(k=!, v!)
```

The map with that entry, replacing any entry with the same key.

## Map.remove

```ernest
Map.remove(map : Map(k=!, v!), key : k=!) : Map(k=!, v!)
```

The map without that key, which need not be present.

### Examples

```ernest
Map.toList(Map.remove(Map.fromList([#("a", 1)]), "a"))
// => []
```

## Map.update

```ernest
Map.update(map : Map(k=!, v!), key : k=!, f : (Optional(v!)) -> v! with e) : Map(k=!, v!) with e
```

The map with the entry at that key replaced by the function's value; the
function sees `None` when there is no entry.

### Examples

```ernest
Map.get(Map.update(Map.empty, "n", fn(o) = Optional.withDefault(o, 0) + 1), "n")
// => Some(1)
```

## Map.map

```ernest
Map.map(map : Map(k=!, v!), f : (k=!, v!) -> w! with e) : Map(k=!, w!) with e
```

Each value replaced by the function's, the key beside it.

## Map.filter

```ernest
Map.filter(map : Map(k=!, v!), keep : (k=!, v!) -> Bool with e) : Map(k=!, v!) with e
```

The entries the predicate holds for.

### Examples

```ernest
Map.toList(Map.filter(Map.fromList([#("a", 1), #("b", 2)]), fn(_, n) = n > 1))
// => [#("b", 2)]
```

## Map.filterMap

```ernest
Map.filterMap(map : Map(k=!, v!), f : (k=!, v!) -> Optional(w!) with e) : Map(k=!, w!) with e
```

The entries whose value the function answers `Some` for, that value in
their place.

### Examples

```ernest
Map.toList(Map.filterMap(Map.fromList([#("a", "1"), #("b", "x")]), fn(_, s) = String.toInt(s)))
// => [#("a", 1)]
```

## Map.foldLeft

```ernest
Map.foldLeft(map : Map(k=!, v!), acc : b, step : (b, k=!, v!) -> b with e) : b with e
```

The accumulator after the function has seen each entry, the accumulator
first.

### Examples

```ernest
Map.foldLeft(Map.fromList([#("a", 1), #("b", 2)]), 0, fn(acc, key, n) = acc + n)
// => 3
```

## Map.foreach

```ernest
Map.foreach(map : Map(k=!, v!), f : (k=!, v!) -> Unit with e) : Unit with e
```

The function applied to each entry for its effect.

### Examples

```ernest
Map.foreach(Map.fromList([#("a", 1)]), fn(key, _) = Io.println(key))
// => Unit
```

## Map.any

```ernest
Map.any(map : Map(k=!, v!), test : (k=!, v!) -> Bool with e) : Bool with e
```

`true` when the predicate holds for some entry.

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

`true` when the predicate holds for every entry, and for the map with no
entries.

## Map.find

```ernest
Map.find(map : Map(k=!, v!), test : (k=!, v!) -> Bool with e) : Optional(#(k=!, v!)) with e
```

Some entry the predicate holds for.

### Examples

```ernest
Map.find(Map.fromList([#("a", 1)]), fn(_, n) = n == 1)
// => Some(#("a", 1))
```

## Map.merge

```ernest
Map.merge(map : Map(k=!, v!), other : Map(k=!, v!)) : Map(k=!, v!)
```

The entries of both, the second winning a shared key.

### Examples

```ernest
Map.toList(Map.merge(Map.fromList([#("a", 1)]), Map.fromList([#("a", 2)])))
// => [#("a", 2)]
```

## Map.mergeWith

```ernest
Map.mergeWith(map : Map(k=!, v!), other : Map(k=!, v!), f : (k=!, v!, v!) -> v! with e) : Map(k=!, v!) with e
```

The entries of both; at a key both hold, `f(key, first, second)` of
the first map's value and the second's.

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

The map of those pairs, a later pair winning its key.

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

Generated by ern 0.3.0 from map.ern.
