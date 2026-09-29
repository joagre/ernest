# Operations records

Ernest has one set in its standard library, `Set`, a hash set. I want a second one that keeps its elements in order, and generic code, a `fromList` or a `size`, should work on both. Java would reach for an interface, Haskell for a type class and ML for a functor. Ernest has no type classes, and this note is an attempt to do without them. It proposes *operations records*: records of a type's operations that the caller passes explicitly. In other words, dictionary passing, written by the program instead of by the compiler.

What I would most like from you is where this breaks. Is there a program that type classes can express and this cannot? Is the ordering restriction sound as I describe it? And have you seen the open question at the end answered? The § numbers cite Ernest's report, and the code assumes the proposal.

## Why sets

Sets are the known hard case for type classes. Haskell's `Data.Set` is `Foldable` but not a `Functor`: `fmap` puts no constraint on the result's element, while a set's `map` needs `Ord` on it (Hughes 1999). A collection class needs the element type as a function of the collection type, which takes functional dependencies (Jones 2000) or associated types (Chakravarty et al. 2005). ML makes a set a functor over an ordered type, `Set.Make(Ord)`, whose application fixes the order. It is this proposal's closest relative. Abstractions over type constructors, such as `Functor` or `Monad`, stay out of reach, because Ernest has no variables over type constructors.

## Requirements

1. Each type reads as it does today: `Set.put(s, x)`, `OrderedSet.put(s, x)`, and the ordered set's own `OrderedSet.min(s)`.
2. Generic code is an ordinary function, and the caller chooses the representation.
3. An ordered set is data: it has `==`, can key a `Map`, and can be sent to another node.
4. Sets in different orders cannot be combined.
5. Errors name what the user wrote: a function, a type, a record.

## The proposal

One restriction is lifted, and the standard library adopts a convention. The syntax does not change.

1. `==` on a type variable already gives it an *equality restriction*, inferred and printed `a=`, as Standard ML's equality types do (§3.10). The proposal treats `<`, `<=`, `>` and `>=` the same way: on a type variable they give it an *ordering restriction*, printed `a<`. At each instantiation the type must have a `compare`, or be a variable, which then inherits the restriction. Anything else is a type error, and so is an ordered variable left ambiguous.
2. A parameterized type's `T.compare` may compare its parameters, and then carries their restriction: `Pair(Int)` is ordered and `Pair(Bool)` is not. Tuples and lists have no module in which to declare a `compare`, so they are ordered element by element whenever their elements are: `#(1, "b") < #(2, "a")`, `[1, 2] < [1, 3]` and `[] < [0]`. `Optional` and `Either` declare theirs in the prelude, with `None` before `Some` and `Left` before `Right`.
3. No top-level `let` is generalized over an ordered variable, so that each is still computed once, before `main` runs (§8.5). A value that depends on an order must be a function.
4. A record holds only the type's primitives, the few operations that touch its representation. `Set.Operations(s, e)` holds `Set`'s six: `empty`, `size`, `contains`, `put`, `remove` and `toList`. None of them is polymorphic beyond `s` and `e`.
5. Generic code is a function of the record. It is declared as a member of the record type and takes the record last, as in `Set.Operations.union(a, b, ops)`. `map` and `filterMap` take two records, one for the source and one for the result.
6. A representation exports one function per record it meets, named for that record, and its own functions, each of which calls the generic one with its record: `OrderedSet.setOperations()`, and `OrderedSet.union(a, b)` beside `Set.union(a, b)`. A type may meet several records, as a class implements several interfaces. A record may also hold another as a field, as one interface extends another: `Ordered.Operations(s, e)` holds `set : Set.Operations(s, e)` beside `min` and `max`. Any module can build a record, for its own type or for another module's.
7. An ordered set uses its element type's `compare`. A different order is a different type, such as `Descending(Int)` with its own `compare`, like Haskell's `Down`.
8. A list that mixes representations holds records whose functions close over their sets, as it does today.
9. `OrderedSet` joins the standard library in `ordered_set.ern`. A file name of words joined by `_` will name one namespace, as it does in Elixir. `Map` gets a record only when it gets a second representation.

```ernest
// set.ern: the record type, Set's record, and the generic functions
export type Operations(s, e) =
    Operations(empty : s,
               size : (s) -> Int,
               contains : (s, e) -> Bool,
               put : (s, e) -> s,
               remove : (s, e) -> s,
               toList : (s) -> List(e))

export fn setOperations() : Operations(Set(e), e) =
    Operations(empty = empty,
               size = size,
               contains = contains,
               put = put,
               remove = remove,
               toList = toList)

export fn Operations.union(a : s, b : s, operations : Operations(s, e)) : s =
    List.foldLeft(operations.toList(b), a, operations.put)

export fn Operations.map(set : s,
                         f : (e) -> d,
                         from : Operations(s, e),
                         to : Operations(t, d)) : t =
    List.foldLeft(from.toList(set), to.empty, fn(acc, x) = to.put(acc, f(x)))

export fn union(a : Set(e), b : Set(e)) : Set(e) =
    Operations.union(a, b, setOperations())

// ordered.ern: a record that holds another
export type Operations(s, e) =
    Operations(set : Set.Operations(s, e), min : (s) -> Optional(e), max : (s) -> Optional(e))

// ordered_set.ern: an ordered set is its elements, in their type's order
export abstract type OrderedSet(e) = OrderedSet(List(e))

export let empty : OrderedSet(e) = OrderedSet([])

export fn put(OrderedSet(xs) : OrderedSet(e), x : e) : OrderedSet(e) =
    OrderedSet(inserted(xs, x))

fn inserted(xs : List(e), x : e) : List(e) =
    match xs {
        [] -> [x]
      | y :: rest -> if x < y then x :: xs else if y < x then y :: inserted(rest, x) else xs
    }

export fn min(OrderedSet(xs) : OrderedSet(e)) : Optional(e) =
    List.get(xs, 0)

export fn max(OrderedSet(xs) : OrderedSet(e)) : Optional(e) =
    List.last(xs)

export fn setOperations() : Set.Operations(OrderedSet(e), e) =
    Set.Operations(empty = empty,
                   size = size,
                   contains = contains,
                   put = put,
                   remove = remove,
                   toList = toList)

export fn orderedOperations() : Ordered.Operations(OrderedSet(e), e) =
    Ordered.Operations(set = setOperations(), min = min, max = max)

export fn union(a : OrderedSet(e), b : OrderedSet(e)) : OrderedSet(e) =
    Set.Operations.union(a, b, setOperations())

// the user
fn fromList(xs : List(e), operations : Set.Operations(s, e)) : s =
    List.foldLeft(xs, operations.empty, operations.put)

let small = fromList([3, 1, 3], OrderedSet.setOperations())
OrderedSet.min(small)                                 // Some(1)
OrderedSet.size(small)                                // 2
small == fromList([1, 3], OrderedSet.setOperations()) // true: an ordered set is data
```

Types print as `OrderedSet.put : (OrderedSet(a<), a<) -> OrderedSet(a<)`, beside today's `Set.put : (Set(a=), a=) -> Set(a=)`.

## Typing and semantics

The ordering restriction is a type class with one method, built in and closed: Haskell's `Ord`, with each type's instance fixed to its `T.compare`. It is inferred the way the equality restriction already is, as a flag on a variable that unification propagates and instantiation checks, so inference stays decidable. It is also elaborated the way `Ord` is. A definition takes a hidden `compare` for each ordered variable it generalizes, each call passes the instantiating type's, and a comparison on the variable calls it. Rule 2 is a conditional instance, `instance Ord a => Ord (Pair a)`, with the condition inferred, and tuples and lists get Haskell's derived instances. Rule 3 is Haskell's monomorphism restriction, there for the same reason.

The order belongs to the type, not to the value or the record. A set could carry its comparator, as Java's `TreeSet` does, but then it would hold a function. It would have no `==`, could not key a `Map` and could not be sent as a message (§3.10, §3.11), and two sets in different orders could meet in `union`. A record carrying `compare` would have the second problem. Fixing the order by the element type gives requirements 3 and 4 with no further rule.

Coherence follows in the same way. A type's `compare` is declared in the type's own module (§4.2), so a type has one order in a program, and no instance can overlap another or be an orphan. That holds within one version of a program: a set sent to a node whose `T.compare` differs arrives misordered.

Records stay ordinary records, so inference stays Hindley–Milner. A record holding an operation that is polymorphic beyond its parameters, such as a fold with its own accumulator type, would need rank-2 fields, like OCaml's polymorphic record fields. The primitives need none. That is why `foldLeft` is not in the record: it is written once over `toList`, as `Set.Operations.foldLeft(set, acc, f, ops)`, at the cost of the list `toList` builds.

Finally, `compare` is assumed to be a total order that says `Equal` only where `==` holds. Nothing checks this, just as Haskell does not check `Ord`'s laws. Where a `compare` breaks it, `put` keeps the element already in the set.

## What it buys and what it costs

The proposal meets the five requirements with one mechanism, the record, which serves both generic code and lists that mix representations, and the standard library uses it too. Each call names the record it uses, so nothing is chosen out of the reader's sight. There is no new syntax, declaration or reserved word, and one error that exists today, `<` on a type variable, goes away. Any module can build a record for any type, `List` included, and since nothing is resolved by type, there are no orphan rules. Type classes could still come later, built on the hidden `compare` argument and on records.

Most of the price is paid at call sites. A function that only passes a set on must take the record too, where type classes would pass nothing. A record parameter needs an annotation, because selecting a field needs the record's type (§3.5). Each operation has two names, `OrderedSet.union(a, b)` and `Set.Operations.union(a, b, ops)`, and `Set.Operations.map` takes a second record where Haskell's `Set.map` takes an `Ord` constraint. Generic code cannot name its variable's `compare`, so it sorts with `List.sort` and a lambda built from `<`.

The rest falls elsewhere. The hidden `compare` is passed at run time, where today `<` finds `T.compare` at compile time. A top-level `let` used at two ordered types is refused, the monomorphism restriction's familiar surprise, and the error says to write a function instead. And tuples and lists gain an order they do not have today, one more rule in §3.10.

Building it means the ordering restriction, its check at instantiation and the order of tuples and lists in the checker; the hidden `compare` argument in the emitter; `set.ern` rewritten over its record; `OrderedSet` with its tests and documentation; and changes to the report and the guide.

## Why not type classes

To hold a set's operations, a class must range over the whole set type, with the element as an associated type, since Ernest has no variables over type constructors. A full design would add instances with conditions, superclasses, default methods, inferred constraints, method resolution by argument or expected type, and one instance per type with orphan checks. To keep a single mechanism, it would also recast `==`, `compare` and the operators as classes.

What that buys is no record at call sites: `size(small)`, and `fromList([3, 1, 3])` with an annotation choosing the representation, and no annotation on generic code.

What it costs is larger. The code a method runs is chosen by an inferred type, and each constraint is a dictionary nobody wrote; `empty` alone needs an annotation to mean anything. There would be two mechanisms, classes beside records and methods beside module functions. `class`, `instance`, method signatures, associated types and instance conditions would enter the grammar. Resolution, conditions, associated types, superclasses, defaults, coherence, orphans and ambiguity would each add rules to the report, errors for users and work in every part of the toolchain.

Type classes contain the proposal. The ordering restriction is one class with fixed instances, and a dictionary is an operations record found by type. What type classes add is declared instances and resolution by type. That saves the record at call sites, at the price of a second mechanism and a larger type system.

## The open question

One question is still open: the ordered set's representation. Structural `==` needs one shape per set. `Set` has one, since it is the runtime's map, whose `==` compares contents. For `OrderedSet`, a sorted list has one shape, but `put` and `contains` are linear. A balanced tree's shape depends on the order of insertion. A treap with hash-derived priorities has one shape and logarithmic operations, but needs a hash, which the standard library lacks. My leaning is the sorted list first, as in the sketch, because it is simple and correct, and a treap only if a measurement shows that the linear cost matters. The hash it needs would then be a decision of its own.
