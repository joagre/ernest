# Ernest module OrderedMap

*Since 0.3.0.*

Operations on `Map(k, v)`, a finite map from keys to values in the
order of the keys' type's `compare` (report §3.10). A function that
needs the order says so, `needs k.compare` (report §4.9): `contains`,
`get`, `put`, `remove`, `update`, `merge`, `mergeWith` and `fromList`;
the rest keep the keys and need none. A map is data: `==` is
structural, a map keys a `Map`, and a map is sent to another node.
The order of `keys`, `values`, `toList`, `foldLeft`, `foreach` and
`find`, and the order in which `map`, `filter`, `filterMap`, `any`,
`all` and `mergeWith` meet the entries, is the keys'. The map is a
sorted list of pairs: `get`, `put` and `remove` are linear in the
size, `fromList` is a sort, `n log n`, and `merge` is linear in the
two sizes. Nothing is a primitive:
the module is written over `List`.

## Examples

```ernest
OrderedMap.keys(OrderedMap.fromList([#("b", 2), #("a", 1)]))
// => ["a", "b"]
```

## See also

`Map` for keys in no order, `OrderedSet` for elements in order.

## OrderedMap.Map

```ernest
abstract type Map(k, v)
```

A map in the order of its key type.

## OrderedMap.empty

```ernest
OrderedMap.empty : OrderedMap.Map(k, v)
```

The map with no entries.

## OrderedMap.fromList

```ernest
OrderedMap.fromList(pairs : List(#(k!, v!))) : OrderedMap.Map(k!, v!) needs k.compare
```

The map of those pairs; at one key, the last pair's value.

### Examples

```ernest
OrderedMap.toList(OrderedMap.fromList([#(2, "b"), #(1, "a"), #(2, "c")]))
// => [#(1, "a"), #(2, "c")]
```

## OrderedMap.size

```ernest
OrderedMap.size(OrderedMap.Map(k!, v!)) : Int
```

The number of entries.

### Examples

```ernest
#(OrderedMap.size(OrderedMap.fromList([#(1, "a")])), OrderedMap.isEmpty(OrderedMap.empty))
// => #(1, true)
```

## OrderedMap.isEmpty

```ernest
OrderedMap.isEmpty(OrderedMap.Map(k!, v!)) : Bool
```

`true` for the map with no entries.

## OrderedMap.contains

```ernest
OrderedMap.contains(map : OrderedMap.Map(k!, v!), key : k!) : Bool needs k.compare
```

`true` when a key the order calls `Equal` to it has a value.

### Examples

```ernest
#(OrderedMap.contains(OrderedMap.fromList([#("a", 1)]), "a"),
  OrderedMap.contains(OrderedMap.empty, "a"))
// => #(true, false)
```

## OrderedMap.get

```ernest
OrderedMap.get(OrderedMap.Map(k!, v!), key : k!) : Optional(v!) needs k.compare
```

The value at the key the order calls `Equal` to it, if any.

### Examples

```ernest
OrderedMap.get(OrderedMap.fromList([#("a", 1)]), "a")
// => Some(1)
```

## OrderedMap.put

```ernest
OrderedMap.put(OrderedMap.Map(k!, v!), key : k!, value : v!) : OrderedMap.Map(k!, v!) needs k.compare
```

The map with that value at that key, replacing one already there.

### Examples

```ernest
OrderedMap.toList(OrderedMap.put(OrderedMap.fromList([#(2, "b")]), 1, "a"))
// => [#(1, "a"), #(2, "b")]
```

## OrderedMap.remove

```ernest
OrderedMap.remove(OrderedMap.Map(k!, v!), key : k!) : OrderedMap.Map(k!, v!) needs k.compare
```

The map without the entry at that key, which need not be there.

### Examples

```ernest
OrderedMap.keys(OrderedMap.remove(OrderedMap.fromList([#(1, "a"), #(2, "b")]), 1))
// => [2]
```

## OrderedMap.update

```ernest
OrderedMap.update(map : OrderedMap.Map(k!, v!), key : k!, f : (Optional(v!)) -> v! with e) : OrderedMap.Map(k!, v!) with e needs k.compare
```

The map with the function's value at that key, the function given the
value there, if any.

### Examples

```ernest
OrderedMap.get(OrderedMap.update(OrderedMap.empty, "n", fn(o) = Optional.withDefault(o, 0) + 1),
               "n")
// => Some(1)
```

## OrderedMap.map

```ernest
OrderedMap.map(OrderedMap.Map(k!, v), f : (k!, v) -> w with e) : OrderedMap.Map(k!, w) with e
```

Each value replaced by the function's, the key beside it, in order.

### Examples

```ernest
OrderedMap.values(OrderedMap.map(OrderedMap.fromList([#(1, 10)]), fn(key, value) = key + value))
// => [11]
```

## OrderedMap.filter

```ernest
OrderedMap.filter(OrderedMap.Map(k!, v!), keep : (k!, v!) -> Bool with e) : OrderedMap.Map(k!, v!) with e
```

The entries the predicate holds for, in order.

### Examples

```ernest
OrderedMap.keys(OrderedMap.filter(OrderedMap.fromList([#(1, "a"), #(2, "b")]),
                                  fn(key, _) = key > 1))
// => [2]
```

## OrderedMap.filterMap

```ernest
OrderedMap.filterMap(OrderedMap.Map(k!, v), f : (k!, v) -> Optional(w) with e) : OrderedMap.Map(k!, w) with e
```

The entries whose value the function maps to `Some`, with that value.

### Examples

```ernest
OrderedMap.toList(OrderedMap.filterMap(OrderedMap.fromList([#(1, "1"), #(2, "x")]),
                                       fn(_, value) = String.toInt(value)))
// => [#(1, 1)]
```

## OrderedMap.foldLeft

```ernest
OrderedMap.foldLeft(OrderedMap.Map(k, v), acc : b, step : (b, k, v) -> b with e) : b with e
```

The accumulator after the function has seen each entry in order, the
accumulator first.

### Examples

```ernest
OrderedMap.foldLeft(OrderedMap.fromList([#(1, 2), #(3, 4)]),
                    0,
                    fn(acc, key, value) = acc + key * value)
// => 14
```

## OrderedMap.foreach

```ernest
OrderedMap.foreach(OrderedMap.Map(k, v), f : (k, v) -> Unit with e) : Unit with e
```

The function applied to each entry in order for its effect.

### Examples

```ernest
OrderedMap.foreach(OrderedMap.fromList([#(1, "a")]), fn(_, value) = Io.println(value))
// => Unit
```

## OrderedMap.any

```ernest
OrderedMap.any(OrderedMap.Map(k!, v!), test : (k!, v!) -> Bool with e) : Bool with e
```

`true` when the predicate holds for some entry.

### Examples

```ernest
#(OrderedMap.any(OrderedMap.fromList([#(1, 1)]), fn(key, value) = key == value),
  OrderedMap.all(OrderedMap.fromList([#(1, 2)]), fn(key, value) = key == value))
// => #(true, false)
```

## OrderedMap.all

```ernest
OrderedMap.all(OrderedMap.Map(k!, v!), test : (k!, v!) -> Bool with e) : Bool with e
```

`true` when the predicate holds for every entry, and for the map with
no entries.

## OrderedMap.find

```ernest
OrderedMap.find(OrderedMap.Map(k!, v!), test : (k!, v!) -> Bool with e) : Optional(#(k!, v!)) with e
```

The first entry in order the predicate holds for.

### Examples

```ernest
OrderedMap.find(OrderedMap.fromList([#(2, "b"), #(1, "a")]), fn(key, _) = key > 1)
// => Some(#(2, "b"))
```

## OrderedMap.merge

```ernest
OrderedMap.merge(map : OrderedMap.Map(k!, v!), other : OrderedMap.Map(k!, v!)) : OrderedMap.Map(k!, v!) needs k.compare
```

The entries of both; at one key, the second's value.

### Examples

```ernest
OrderedMap.toList(OrderedMap.merge(OrderedMap.fromList([#(1, "a")]),
                                   OrderedMap.fromList([#(1, "b")])))
// => [#(1, "b")]
```

## OrderedMap.mergeWith

```ernest
OrderedMap.mergeWith(OrderedMap.Map(k!, v!), OrderedMap.Map(k!, v!), f : (k!, v!, v!) -> v! with e) : OrderedMap.Map(k!, v!) with e needs k.compare
```

The entries of both; at one key, the function's value from the two.

### Examples

```ernest
OrderedMap.toList(OrderedMap.mergeWith(OrderedMap.fromList([#(1, 1)]),
                                       OrderedMap.fromList([#(1, 2), #(3, 3)]),
                                       fn(_, mine, theirs) = mine + theirs))
// => [#(1, 3), #(3, 3)]
```

## OrderedMap.toList

```ernest
OrderedMap.toList(OrderedMap.Map(k, v)) : List(#(k, v))
```

The entries, in order.

## OrderedMap.keys

```ernest
OrderedMap.keys(OrderedMap.Map(k, v!)) : List(k)
```

The keys, in order.

## OrderedMap.values

```ernest
OrderedMap.values(OrderedMap.Map(k!, v)) : List(v)
```

The values, in the keys' order.

---

Generated by ern 0.3.0 from ordered_map.ern.
