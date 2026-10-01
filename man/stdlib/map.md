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
Map.size : (Map(k, v)) -> Int
```

The number of entries.

### Examples

```ernest
#(Map.size(Map.fromList([#("a", 1)])), Map.isEmpty(Map.empty))
// => #(1, true)
```

## Map.isEmpty

```ernest
Map.isEmpty : (Map(k=!, v!)) -> Bool
```

`true` for the map with no entries.

## Map.contains

```ernest
Map.contains : (Map(k=!, v!), k=!) -> Bool
```

`true` when the map has an entry with that key.

### Examples

```ernest
#(Map.contains(Map.fromList([#("a", 1)]), "a"), Map.contains(Map.empty, "a"))
// => #(true, false)
```

## Map.get

```ernest
Map.get : (Map(k, v), k) -> Optional(v)
```

The value at that key.

## Map.put

```ernest
Map.put : (Map(k, v), k, v) -> Map(k, v)
```

The map with that entry, replacing any entry with the same key.

## Map.remove

```ernest
Map.remove : (Map(k, v), k) -> Map(k, v)
```

The map without that key, which need not be present.

### Examples

```ernest
Map.toList(Map.remove(Map.fromList([#("a", 1)]), "a"))
// => []
```

## Map.update

```ernest
Map.update : (Map(k=!, v!), k=!, (Optional(v!)) -> v! with e) -> Map(k=!, v!) with e
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
Map.map : (Map(k=!, v!), (k=!, v!) -> w! with e) -> Map(k=!, w!) with e
```

Each value replaced by the function's, the key beside it.

## Map.filter

```ernest
Map.filter : (Map(k=!, v!), (k=!, v!) -> Bool with e) -> Map(k=!, v!) with e
```

The entries the predicate holds for.

### Examples

```ernest
Map.toList(Map.filter(Map.fromList([#("a", 1), #("b", 2)]), fn(_, n) = n > 1))
// => [#("b", 2)]
```

## Map.filterMap

```ernest
Map.filterMap : (Map(k=!, v!), (k=!, v!) -> Optional(w!) with e) -> Map(k=!, w!) with e
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
Map.foldLeft : (Map(k=!, v!), b, (b, k=!, v!) -> b with e) -> b with e
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
Map.foreach : (Map(k=!, v!), (k=!, v!) -> Unit with e) -> Unit with e
```

The function applied to each entry for its effect.

### Examples

```ernest
Map.foreach(Map.fromList([#("a", 1)]), fn(key, _) = Io.println(key))
// => Unit
```

## Map.any

```ernest
Map.any : (Map(k=!, v!), (k=!, v!) -> Bool with e) -> Bool with e
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
Map.all : (Map(k=!, v!), (k=!, v!) -> Bool with e) -> Bool with e
```

`true` when the predicate holds for every entry, and for the map with no
entries.

## Map.find

```ernest
Map.find : (Map(k=!, v!), (k=!, v!) -> Bool with e) -> Optional(#(k=!, v!)) with e
```

Some entry the predicate holds for.

### Examples

```ernest
Map.find(Map.fromList([#("a", 1)]), fn(_, n) = n == 1)
// => Some(#("a", 1))
```

## Map.merge

```ernest
Map.merge : (Map(k=!, v!), Map(k=!, v!)) -> Map(k=!, v!)
```

The entries of both, the second winning a shared key.

### Examples

```ernest
Map.toList(Map.merge(Map.fromList([#("a", 1)]), Map.fromList([#("a", 2)])))
// => [#("a", 2)]
```

## Map.mergeWith

```ernest
Map.mergeWith : (Map(k=!, v!), Map(k=!, v!), (k=!, v!, v!) -> v! with e) -> Map(k=!, v!) with e
```

The entries of both, a shared key given the function of the key, the
first's value and the second's.

### Examples

```ernest
Map.toList(Map.mergeWith(Map.fromList([#("a", 1), #("b", 1)]),
                         Map.fromList([#("a", 2), #("b", 2)]),
                         fn(key, a, b) = if key == "a" then a + b else b))
// => [#("a", 3), #("b", 2)]
```

## Map.fromList

```ernest
Map.fromList : (List(#(k=!, v!))) -> Map(k=!, v!)
```

The map of those pairs, a later pair winning its key.

## Map.toList

```ernest
Map.toList : (Map(k, v)) -> List(#(k, v))
```

The entries as pairs, in unspecified order.

## Map.keys

```ernest
Map.keys : (Map(k=!, v!)) -> List(k=!)
```

The keys, in unspecified order.

### Examples

```ernest
#(Map.keys(Map.fromList([#("a", 1)])), Map.values(Map.fromList([#("a", 1)])))
// => #(["a"], [1])
```

## Map.values

```ernest
Map.values : (Map(k=!, v!)) -> List(v!)
```

The values, in unspecified order.

---

Generated by ern 0.2.0 from map.ern.
