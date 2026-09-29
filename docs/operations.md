# Operations records

Ernest is a functional language on the BEAM: pure functions with Hindley–Milner inference, and processes with typed mailboxes. Its standard library has one set, `Set`, a hash set. A program that needs its elements in order needs a sorted set too, and code written once, a `fromList` or a `size`, should work on both. Java would use an interface, Haskell a type class, ML a functor. This note proposes *operations records*, records of a type's operations that the caller passes explicitly (dictionary passing, written by the program), and argues against type classes. § numbers cite Ernest's report. The code assumes the proposal.

## Why sets

Sets are the known hard case for type classes. Haskell's `Data.Set` is `Foldable` but not a `Functor`: `fmap` puts no constraint on the result's element, while a set's `map` needs `Ord` on it (Hughes, *Restricted Data Types in Haskell*, 1999; later worked around with `ConstraintKinds`). A collection class needs the element type as a function of the collection type: functional dependencies (Jones, *Type Classes with Functional Dependencies*, 2000, with `Collects` as its running example) or associated types (Chakravarty et al., 2005). ML makes a set a functor over an ordered type, `Set.Make(Ord)`, whose application fixes the order; it is this proposal's closest relative. Abstractions over type constructors, a `Functor` or a `Monad`, stay out of reach: Ernest has no variables over type constructors.

## Requirements

1. Each type reads as today: `Set.put(s, x)`, `OrderedSet.put(s, x)`, and the ordered set's own `OrderedSet.min(s)`.
2. Code written once is an ordinary function, and the caller chooses the representation.
3. An ordered set is data: it has `==`, can key a `Map`, and can be sent to another node.
4. Sets in different orders cannot be combined.
5. Errors name what the user wrote: a function, a type, a record.

## The proposal

One restriction is lifted and the standard library adopts a convention. No syntax changes.

1. **Ordering restriction.** Ernest's `==` is structural; on a type variable it gives the variable an *equality restriction*, inferred and printed `a=`, as Standard ML's equality types do, and a type holding a function has no equality (§3.10). Likewise `<`, `<=`, `>` and `>=` on a type variable give it an *ordering restriction*, printed `a<`. At each instantiation the type must have `compare`, or be a variable, which inherits the restriction; otherwise the call is a type error. An ordered variable that nothing fixes and no definition generalizes is an error, as now.
2. **Conditional `compare`.** `T.compare` for a parameterized type may compare the parameters, and then carries their restriction: `Pair(Int)` is ordered, `Pair(Bool)` is not.
3. **No top-level `let` is generalized over an ordered variable**, so it is still computed once, before `main` (§8.5). A value that depends on an order is a function.
4. **A record holds the type's primitives**, the few operations that touch its representation, which the standard library already names for each module. `Set.Operations(s, e)` holds `Set`'s six: `empty`, `size`, `contains`, `put`, `remove`, `toList`. None is polymorphic beyond `s` and `e`.
5. **Code written once is a function of the record**, declared as a member of the record type (`T.name`, as Ernest writes a type's operations, §4.2), taking the record last: `Set.Operations.union(a, b, ops)`. `Set`'s other fourteen functions are written this way, each `Set.f` a call of `Set.Operations.f` with `Set`'s record. `map` and `filterMap` take two records, the source's and the result's.
6. **A representation exports `operations()`** and names its own functions as `Set` does: `OrderedSet.union(a, b)` calls `Set.Operations.union` with its record. Any module can build a record, for its own type or another's.
7. **An ordered set uses its element type's `compare`.** Another order is another type, `Descending(Int)` with its own `compare`, like Haskell's `Down`.
8. **`==` stays structural.** A list of sets of different representations holds records whose functions close over their sets, as today.
9. **`OrderedSet` joins the standard library** in `ordered_set.ern`: a file name of words joined by `_` will name one namespace, as in Elixir. `Map` gets a record only when it gets a second representation.

```ernest
// set.ern: the record, Set's, and the functions written once
export type Operations(s, e) =
    Operations(empty : s,
               size : (s) -> Int,
               contains : (s, e) -> Bool,
               put : (s, e) -> s,
               remove : (s, e) -> s,
               toList : (s) -> List(e))

export fn operations() : Operations(Set(e), e) =
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
    Operations.union(a, b, operations())

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

export fn operations() : Set.Operations(OrderedSet(e), e) =
    Set.Operations(empty = empty, put = put, ...)

export fn union(a : OrderedSet(e), b : OrderedSet(e)) : OrderedSet(e) =
    Set.Operations.union(a, b, operations())

// the user
fn fromList(xs : List(e), operations : Set.Operations(s, e)) : s =
    List.foldLeft(xs, operations.empty, operations.put)

let small = fromList([3, 1, 3], OrderedSet.operations())
OrderedSet.min(small)                                 // Some(1)
OrderedSet.size(small)                                // 2
small == fromList([1, 3], OrderedSet.operations())    // true: an ordered set is data
```

Types print as `OrderedSet.put : (OrderedSet(a<), a<) -> OrderedSet(a<)`, beside today's `Set.put : (Set(a=), a=) -> Set(a=)`.

## Typing and semantics

- **The ordering restriction is a one-method type class, built in and closed**: Haskell's `Ord` with each type's instance fixed to its `T.compare`. It is inferred as the equality restriction is, a flag on a variable propagated by unification and checked at instantiation, so inference stays decidable. It is elaborated as `Ord` is: a definition takes a `compare` for each ordered variable it generalizes, each call passes the instantiating type's, and a comparison on the variable calls it. It is the only argument Ernest passes that no one writes. Rule 2 is a conditional instance, `instance Ord a => Ord (Pair a)`, its condition inferred. Rule 3 is Haskell's monomorphism restriction, for the same reason.
- **The order belongs to the type, not the value or the record.** A set could carry its comparator, as Java's `TreeSet` does, and need no restriction, since `<` on a type variable is refused today (§4.8). But the set would hold a function, so it would have no `==`, could not key a `Map` and could not be sent as a message (§3.10, §3.11), and two sets in different orders could meet in `union`. A record carrying `compare` has the second fault: two calls could give one set two orders. Fixing the order by the element type gives requirements 3 and 4 by construction.
- **Coherence by construction.** A type's `compare` is a member declared in the type's module (§4.2), so a type has one order in a program, and no instance can overlap another or be an orphan. This holds within one version of a program: a set sent to a node whose `T.compare` differs is misordered there.
- **Records are ordinary records**, their fields polymorphic only in the record's parameters, so inference stays Hindley–Milner and code written once is ordinary polymorphic functions. A record holding an operation polymorphic beyond its parameters, a fold with its own accumulator type, would need rank-2 fields like OCaml's polymorphic record fields; the primitives need none.
- **An ordered set holds no function.** Structural `==` is set equality, given a canonical representation, and the value can be sent as a message. A generic function closes over the `compare`s it receives, which travel with its code (§3.11).
- **`compare` is assumed a total order, `Equal` only where `==` holds.** Nothing checks it, as Haskell does not check `Ord`'s laws.

## Pros, cons, cost

Pros:
- Meets the five requirements.
- One mechanism, the record, for code written once and for mixed representations; the standard library uses it too.
- Explicit: each call names the record it uses.
- No new syntax, declaration or reserved word, and one existing error, `<` on a type variable, goes.
- Any module can build a record for any type, `List` included. Nothing is resolved by type, so there are no orphan rules.
- Type classes can still come later: they would build on the hidden `compare` argument and on records.

Cons:
- A function that only passes a set on must take the record too; type classes would pass nothing.
- A record parameter needs an annotation, since field selection needs the record's type (§3.5).
- The hidden `compare` is passed at run time, where today `<` resolves `T.compare` at compile time.
- Each operation has two names: `OrderedSet.union(a, b)` and `Set.Operations.union(a, b, ops)`.
- A top-level `let` used at two ordered types is refused, the monomorphism restriction's known surprise; the error says to write a function.
- Only `Int`, `Float`, `String`, `Char` and types that declare `compare` are ordered. Pairs, lists and `Optional` are not (§3.10), so a set of pairs needs a wrapper type.
- Generic code cannot name its variable's `compare`; it sorts with `List.sort` and a lambda built from `<`.
- `Set.Operations.map` takes a second record where Haskell's `Set.map` takes an `Ord` constraint.

Cost, in working days: the ordering restriction about 3, in the checker and the emitter's hidden argument; `set.ern` over its record and `OrderedSet` with tests and docs about 3; the report and the guide about 2. About 8 in all.

## Why not type classes

To hold a set's operations, a class must range over the whole set type, with the element as an associated type, since Ernest has no variables over type constructors. A full design adds instances with conditions, superclasses, default methods, inferred constraints, method resolution by argument or expected type, one instance per type with orphan checks, and, for a single mechanism, `==`, `compare` and the operators recast as classes.

Gain: no record at call sites. `size(small)`, and `fromList([3, 1, 3])` with an annotation choosing the representation; no annotation on generic code.

Cost:
- The code a method runs is chosen by an inferred type, and each constraint is a dictionary nobody wrote; `empty` alone needs an annotation to mean anything.
- Two mechanisms: classes beside records, methods beside module functions.
- `class`, `instance`, method signatures, associated types and instance conditions enter the grammar.
- Instances, associated types, conditions, superclasses, defaults, coherence, orphans and ambiguity each add rules to the report, errors for users, and checks across modules.
- About six weeks of work against about eight days: two days for the lexer, parser, formatter and editor mode, three weeks for the types and the checker, one for dictionary passing, and days for the tools and the documentation.

Type classes contain the proposal: the ordering restriction is one class with fixed instances, and a dictionary is an operations record found by type. What they add, declared instances and resolution by type, saves the record at call sites, at the cost of a second mechanism and a larger type system.

## Open questions

- **Representation.** Structural `==` needs one shape per set. A sorted list has one, but `put` and `contains` are linear. A balanced tree's shape depends on the order of insertion. A treap with hash-derived priorities has one shape and logarithmic operations, but needs a hash the standard library lacks.
- **Which element to keep** when `compare` says `Equal` and `==` does not.
- **Whether the record includes `foldLeft`** beside `toList`.
- **Members or module functions.** Only operators and `compare` are found by type; code written once is a member of the record type. Where a type's other operations belong is a question of naming.
- **Whether tuples, lists and `Optional` get a lexicographic `compare`**, as rule 2 allows, so that a set of pairs needs no wrapper.
