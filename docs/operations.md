# Operations records

Ernest is a functional language for concurrent programs on the BEAM: pure functions typed by Hindley–Milner inference, and processes with typed mailboxes. Its report, which the § numbers below cite, states five principles (§0): least surprise, one way, nothing invisible, simple to parse, and small. This note proposes how code written once works over several representations of one thing, a set kept hashed and a set kept in order, and argues against type classes. Where Java would declare an interface and Haskell a type class, the proposal passes an *operations record*, a record of a type's operations, explicitly: dictionary passing written by the program. The block marked `ernest` compiles with Ernest as it is; the one marked `sketch` is Ernest as the proposal would make it.

## The problem

`==` is structural. Used on a type variable it gives the variable an *equality restriction* (a constraint, in the usual term), inferred and never written, as Standard ML's equality types do; a type holding a function or an address has no equality (§3.9, §3.10). Ordering is per type: `<` calls `T.compare` of its operand's type `T`, which the type's module declares. `<` on a type variable is refused, ``the operand type of `<` is not determined; annotate it`` (§4.8), so an ordered set must carry its order in every value:

```ernest
export abstract type OrderedSet(a) = OrderedSet(compare : (a, a) -> Ordering, items : List(a))

export fn empty(compare : (a, a) -> Ordering) : OrderedSet(a) =
    OrderedSet(compare = compare, items = [])
```

Such a value holds a function, so it has no `==`, keys no `Map`, and cannot go to a peer (§3.11); `empty` takes an argument that `Set.empty` does not; and two sets built with two orders would meet in `union` and give a set in neither.

## Why sets

Sets are the known hard case for type classes. Haskell's `Data.Set` is `Foldable` but cannot be a `Functor`, since `fmap` puts no constraint on its result's element and a set's `map` needs `Ord` on it: the problem of restricted data types (Hughes, *Restricted Data Types in Haskell*, 1999), which GHC's `ConstraintKinds` later let libraries work around. A class of collections needs the element type as a function of the collection's, which Haskell gained through functional dependencies, whose running example is a class `Collects` (Jones, *Type Classes with Functional Dependencies*, 2000), and later through associated types (Chakravarty et al., 2005), `class Collects ce where type Elem ce`. The ML family writes a set as a functor over an ordered type, OCaml's `Set.Make(Ord)`, whose application fixes the order: the closest relative of this proposal. Sets test the proposal where type classes needed extensions. What needs a variable over type constructors, a `Functor` or a `Monad`, stays out of its reach, since Ernest has none.

## The measures

1. **Each type on its own reads as today.** `Set.put(s, x)`, `OrderedSet.put(s, x)`, and the ordered set's own `OrderedSet.min(s)`: the same verbs for the same operations.
2. **Code written once is an ordinary function**, and its caller chooses the representation.
3. **An ordered set is data.** It has `==`, keys a `Map`, and goes to a peer, as a `Set(Int)` does.
4. **A wrong mix is refused, not computed.** Two sets ordered differently cannot meet in `union`.
5. **A mistake is reported in the user's words**: a function, a type or a record the user wrote.

## The proposal

One restriction is lifted, and the standard library follows a convention. No syntax is added: Appendix A does not change.

1. **An ordering restriction, as the equality one.** `<`, `<=`, `>` and `>=` on a type variable give it the ordering restriction, inferred and never written, printed `a<` as the equality restriction is printed `a=`. At each instantiation the variable's type must have `compare`, or be a variable, which takes the restriction; any other type is a type error at the call. A variable that nothing fixes and no definition generalizes is refused, as today.
2. **A `compare` over parameters.** A member `T.compare` of a type with parameters may compare them, and then carries their restriction: `Pair(Int)` is ordered and `Pair(Bool)` is not.
3. **A top-level `let` is not generalized over an ordered variable**, so it is still computed once, before `main` (§8.5). A value that depends on an order is a function.
4. **An operations record holds a type's primitives**, the few operations that reach its representation, which the standard library already names (Appendix E.0 rule 1). `Set.Operations(s, e)` holds `Set`'s six: `empty`, `size`, `contains`, `put`, `remove`, and `toList`. None is polymorphic beyond the record's parameters.
5. **A function written once is a member of the record's type**, and takes the record last, as `List.sort` takes its `compare`: `Set.Operations.union(a, b, operations)`. `Set`'s own fourteen functions beyond the primitives are written so, each `Set.f` a call of `Set.Operations.f` with `Set`'s record. `map` and `filterMap` take two records, the source's and the result's.
6. **A representation meets the record by a function its module exports**, `operations()`, and names its own functions as `Set` does: `OrderedSet.union(a, b)` calls `Set.Operations.union` with its record. Any module may build a record, for a type of its own or another's.
7. **An ordered set orders its elements by their type's `compare`.** Another order is another type, `Descending(Int)` with its own `compare`, as Haskell's `Down` is.
8. **`==` stays structural.** Values of several representations in one list are records whose functions close over their values, which Ernest has today.
9. **The standard library gains `OrderedSet`** as the second representation of `Set.Operations`. `Map` gains a record when it gains a second representation, since a record one type meets abstracts over nothing.

```sketch
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

// orderedset.ern: an ordered set is its elements, in their type's order
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

`OrderedSet.put` prints `(OrderedSet(a<), a<) -> OrderedSet(a<)`, as `Set.put` prints `(Set(a=), a=) -> Set(a=)` today.

## Typing and meaning

- **The ordering restriction is a type class with one method, built in and closed.** It is inferred as the equality restriction is, a flag on a variable propagated through unification and checked at instantiation, so inference stays decidable. It is Haskell's `Ord` with each type's instance fixed to its `T.compare`, and is elaborated as Haskell elaborates `Ord`: a definition takes a `compare` for each ordered variable it generalizes, each call passes the instantiating type's, and a comparison on the variable calls it. It is the one argument Ernest passes that no one writes. A `compare` over parameters (rule 2) is a conditional instance, `instance Ord a => Ord (Pair a)`, its condition inferred from its body. Rule 3 is Haskell's monomorphism restriction, for the same reason.
- **Why the order is the type's and not the record's.** A record could carry a `compare`, and no restriction would be needed; but then the caller supplies the order, and two calls may pass one set two orders. Fixing the order by the element's type makes measure 4 hold by construction.
- **Coherence is by construction.** A type's order is its own member, declared in its module (§4.2), so each type has one order in the whole program: no instance can overlap another or stand apart from its type. Two sets of one element type are in one order wherever they were built, within one version of the program: a set sent to a node whose `T.compare` differs is not in that node's order, and the node's operations on it answer wrongly.
- **An operations record is an ordinary record**, its fields polymorphic in its own parameters alone, since it holds the primitives: inference stays Hindley–Milner's, and the functions written once over it are ordinary polymorphic functions. A record that had to hold an operation polymorphic beyond its parameters, a fold with its own accumulator, would need rank-2 fields, as OCaml's polymorphic record fields are; this proposal needs none.
- **An ordered set holds no function.** Its order is its element type's, so the value is data: structural `==` is set equality for a canonical representation, and the value crosses nodes as a message does. A generic function closes over the `compare`s it was given, and they travel with it as its code does (§3.11).
- **`compare` is assumed a total order that finds two values `Equal` only when `==` does.** Nothing checks this, as Haskell does not check `Ord`'s laws; where it fails, which element a set keeps is an open question below.

## For, against, and cost

**For:**
- The five measures: each set reads as today, code written once is a function of the record, an ordered set is data, two orders are two types, and a mistake is a record, a function, or a type without `compare`.
- Principle 2: one mechanism, the record, for code written once and for mixed representations; the standard library uses what users use.
- Principle 3: a call names the record it uses, and a selection the function.
- Principles 4 and 5: no syntax, no declaration and no reserved word; one error a user meets today goes.
- Any module may build a record for any type, `List` included: nothing is found by type, so there is no orphan rule.
- It closes no door: type classes would build on the ordering restriction's hidden argument and on records of operations.

**Against:**
- A function that only hands a set on takes the record too, where type classes pass nothing.
- A record parameter is annotated, since a selection needs its record's type (§3.5).
- The `compare` of an ordered variable is passed unwritten (principle 3). Its precedent is `<`, which finds `T.compare` by type today, but that is resolved where the program is compiled; this one is passed at run time.
- Each operation has two names: a representation's own, `OrderedSet.union(a, b)`, and the one written once, `Set.Operations.union(a, b, operations)`.
- A top-level `let` that would be ordered at two types is refused, the known surprise of the monomorphism restriction; the error says to write a function.
- Only `Int`, `Float`, `String`, `Char` and types that declare `compare` are ordered. A pair, a list or an `Optional` has no order (§3.10), so an ordered set of pairs needs a type of its own with a `compare`.
- Generic code has no name for its variable's `compare`; it sorts with `List.sort` and a lambda built from `<`.
- `Set.Operations.map` takes a second record, where Haskell's `Set.map` needs `Ord` on the result: the constraint moves into an argument.

**Cost**, in working days: the ordering restriction about 3, in the checker and the emitter's hidden argument; `set.ern` rewritten over its record, `OrderedSet` with its tests and page, about 3; the report, Appendix E and the guide's §7.3 about 2. In all about 8.

## Why not type classes

A type class that can hold a set's operations is a class over the whole set type with the element an associated type, since Ernest has no variable over type constructors, with instances declared under conditions, superclasses, default methods, constraints inferred, a method resolved by its argument's type or the type expected, one instance per type under an orphan rule, and, so that there is one mechanism, `==`, `compare` and the operators rebuilt as classes.

What it would give: no record at a call. `size(small)` and `fromList([3, 1, 3])` with an annotation choosing the representation, and no annotation on code written once.

What it would cost:
- **Nothing invisible (3).** What a method runs is chosen by a type the reader infers, and every constraint is a dictionary no one wrote; `empty` alone needs an annotation to mean anything.
- **One way (2).** Classes beside records, and methods beside module functions.
- **Simple to parse (4).** `class`, `instance`, method signatures, associated types, and conditions in instance heads enter Appendix A.
- **Small (5).** Classes, instances, associated types, conditions, superclasses, defaults, coherence, orphans and ambiguity: each a section of the report, a set of new errors for the user, and rules across modules for the checker.
- **Work:** about six weeks against about eight days: two days for the lexer, parser, formatter and editor mode, three weeks for the types and the checker, one for the emitter's dictionaries, and days for the shell, `ern doc`, the report and the guide.

Type classes contain the proposal: the ordering restriction is one class with its instances fixed, and a dictionary is an operations record found by type. What they add is declared instances and resolution by type, which save the record at a call. For that return the cost is a second mechanism, a larger report, and a larger type system.

## Open questions

- **The ordered set's name.** A file `orderedset.ern` provides the namespace `Orderedset` (§4.2), not `OrderedSet`; `set/ordered.ern`, `Set.Ordered`, is the other place.
- **Its representation.** `==` is structural, so a set must have one shape for each set of elements. A sorted list has, but `put` and `contains` take linear time. A balanced tree whose shape follows the order of insertion has not. A treap whose priorities are a hash of the element has one shape and logarithmic time, and needs a hash the standard library does not have.
- **Which of two elements it keeps** when `compare` finds them equal and `==` tells them apart.
- **Whether `Set`'s record holds `foldLeft`** beside `toList`, which the functions written once would otherwise build on.
- **When a type's operation is a member and when a module function.** A member is found by type only for an operator and `compare`, and the functions written once are members of the record's type.
- **Whether tuples, lists and `Optional` take a `compare`**, lexicographic, as rule 2 allows: an ordered set of pairs would then need no type of its own.
