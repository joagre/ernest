# Contracts

Ernest is a functional language for concurrent programs on the BEAM: pure functions typed by Hindley–Milner inference, and processes with typed mailboxes. Its report states five principles (§0): least surprise, one way, nothing invisible, simple to parse, and small. This note proposes how code written once works over several representations of one thing, a set kept hashed and a set kept in order, and argues against type classes. It is the input to MVP 2.99b's decision; the decision goes to the report and the decisions log, and the note goes. The block marked `ernest` compiles today (2026-09-29); the one marked `sketch` is Ernest as the proposal would make it.

## The problem

`==` is structural. Used on a type variable it gives the variable an *equality restriction*, inferred and never written, as Standard ML's equality types do; a type holding a function or an address has no equality (§3.9, §3.10). Ordering is per type: `<` calls `T.compare` of its operand's type `T`. Two restrictions stand in the way of an ordered set:

- `<` on a type variable is refused: ``the operand type of `<` is not determined; annotate it`` (§4.8).
- A field's type may name only its type's parameters: ``type variable b is not a parameter of the type`` (§3.9). So a record of functions cannot hold `Set.foldLeft : (Set(a), b, (b, a) -> b with e) -> b with e`, nor nine of `Set`'s twenty functions.

An ordered set must therefore carry its order in every value:

```ernest
export abstract type OrderedSet(a) = OrderedSet(compare : (a, a) -> Ordering, items : List(a))

export fn empty(compare : (a, a) -> Ordering) : OrderedSet(a) =
    OrderedSet(compare = compare, items = [])
```

Such a value holds a function, so it has no `==`, keys no `Map`, and cannot go to a peer (§3.11); and `empty` takes an argument `Set.empty` does not.

## The measures

1. **Each type on its own reads as today.** `Set.put(s, x)`, `OrderedSet.put(s, x)`, and the ordered set's own `OrderedSet.min(s)`: the same verbs for the same operations.
2. **Code written once is an ordinary function**, and its caller chooses the representation.
3. **An ordered set is data.** It has `==`, keys a `Map`, and goes to a peer, as a `Set(Int)` does.
4. **A wrong mix is refused, not computed.** Two sets ordered differently cannot meet in `union`.
5. **A mistake is reported in the user's words**: a function, a type or a record the user wrote.

## The proposal

A contract is a record of functions, and the caller chooses the representation by the record it passes. Two restrictions are lifted. No syntax is added: Appendix A does not change.

1. **An ordering restriction, as the equality one.** `<`, `<=`, `>` and `>=` on a type variable give it the ordering restriction, inferred and never written, printed `a<` as the equality restriction is printed `a=`. At each instantiation the variable's type must have `compare`, or the call is a type error. A variable that nothing fixes and no definition generalizes is refused, as today.
2. **A `compare` over parameters.** A member `T.compare` of a type with parameters may compare them, and then carries their restriction: `Pair(Int)` is ordered and `Pair(Bool)` is not.
3. **A top-level `let` is not generalized over an ordered variable**, so it is still computed once, before `main` (§8.5). A value that depends on an order is a function.
4. **A named field's own variables.** A type or effect variable that a named field's type names, and its type does not take, is the field's own: the field is polymorphic in it. The value given for the field, where the record is built or updated, is checked with those variables rigid, as an annotation's are; each selection or pattern instantiates them afresh. A field's own variable carries no inferred restriction. A positional field has none, since a constructor with one positional field is a function value (§5.6).
5. **A contract is a record type** named for what it holds: `Set.Operations(s, a)` holds `Set`'s functions whose types stay within one representation, all but `map` and `filterMap`.
6. **A representation meets a contract by a function its module exports**, `operations()`. Any module may build a contract's record, for a type of its own or another's.
7. **Code written once takes the record last**, as `List.sort` takes its `compare`.
8. **An ordered set orders its elements by their type's `compare`.** Another order is another type, `Descending(Int)` with its own `compare`, as Haskell's `Down` is.
9. **`==` stays structural.** Values of several representations in one list are records whose functions close over their values, which Ernest has today.

```sketch
// set.ern: the contract, and Set's record
export type Operations(s, a) =
    Operations(empty : s,
               put : (s, a) -> s,
               contains : (s, a) -> Bool,
               union : (s, s) -> s,
               foldLeft : (s, b, (b, a) -> b with e) -> b with e)  // b and e are the field's own

export fn operations() : Operations(Set(a), a) =
    Operations(empty = empty, put = put, contains = contains, union = union, foldLeft = foldLeft)

// orderedset.ern: an ordered set is its elements, in their type's order
export abstract type OrderedSet(a) = OrderedSet(List(a))

export let empty : OrderedSet(a) = OrderedSet([])

export fn put(OrderedSet(xs) : OrderedSet(a), x : a) : OrderedSet(a) =
    OrderedSet(inserted(xs, x))

fn inserted(xs : List(a), x : a) : List(a) =
    match xs {
        [] -> [x]
      | y :: rest -> if x < y then x :: xs else if y < x then y :: inserted(rest, x) else xs
    }

export fn operations() : Set.Operations(OrderedSet(a), a) =
    Set.Operations(empty = empty, put = put, ...)

// the user
fn fromList(xs : List(a), operations : Set.Operations(s, a)) : s =
    List.foldLeft(xs, operations.empty, operations.put)

fn size(set : s, operations : Set.Operations(s, a)) : Int =
    operations.foldLeft(set, 0, fn(n, _) = n + 1)

let small = fromList([3, 1, 3], OrderedSet.operations())
OrderedSet.min(small)                                 // Some(1)
size(small, OrderedSet.operations())                  // 2
small == fromList([1, 3], OrderedSet.operations())    // true: an ordered set is data
```

`OrderedSet.put` prints `(OrderedSet(a<), a<) -> OrderedSet(a<)`.

## Typing and meaning

- **The ordering restriction is a type class with one method, built in and closed.** It is Haskell's `Ord` with each type's instance fixed to its `T.compare`, and is elaborated as Haskell elaborates `Ord`: a definition takes a `compare` for each ordered variable it generalizes, each call passes the instantiating type's, and a comparison on the variable calls it. It is the one argument Ernest passes that no one writes. A `compare` over parameters (rule 2) is a conditional instance, `instance Ord a => Ord (Pair a)`, its condition inferred from its body. Rule 3 is Haskell's monomorphism restriction, for the same reason.
- **Coherence is by construction.** A type's order is its own member, declared in its module (§4.2), so each type has one order in the whole program: no instance can overlap another or stand apart from its type. Two sets of one element type are in one order wherever they were built, which is measure 4.
- **A field's own variables are rank-2 polymorphism confined to declared record fields**: OCaml's polymorphic record fields, and Haskell's polymorphic components. They are declared, never inferred, and a selection's record type is already required to be known (§3.5), so inference stays Hindley–Milner's.
- **An ordered set holds no function.** Its order is its element type's, so the value is data: structural `==` is set equality for a canonical representation, and the value crosses nodes as a message does. A generic function closes over the `compare`s it was given, and they travel with it as its code does (§3.11).
- **`compare` is assumed a total order consistent with the type.** Nothing checks this, as Haskell does not check `Ord`'s laws.

## For, against, and cost

**For:**
- The five measures: each set reads as today, code written once is a function of the record, an ordered set is data, two orders are two types, and a mistake is a record, a function, or a type without `compare`.
- Principle 2: one mechanism, the record of functions, for code written once and for mixed representations.
- Principle 3: a call names the record it uses, and a selection the function.
- Principles 4 and 5: no syntax, no declaration and no reserved word; two errors a user meets today go.
- Any module may meet a contract for any type, `List` included: nothing is found by type, so there is no orphan rule.
- It closes no door: type classes would need both extensions, polymorphic methods and a hidden argument, and would build on them.

**Against:**
- A function that only hands a set on takes the record too: `size(small, OrderedSet.operations())`, where type classes write `size(small)`.
- A record parameter is annotated, since a selection needs its record's type (§3.5).
- The `compare` of an ordered variable is passed unwritten (principle 3). Its precedent is `<`, which finds `T.compare` by type today, and it is the language's own: no user declares another restriction.
- `map` and `filterMap`, whose result is a set of another element, stay out of the contract: the result's type would need a variable over type constructors, which Ernest has not, and an ordered result its element's order, which a field's own variable cannot carry.
- A value that depends on an order is a function, `OrderedSet.operations()`, not a `let`.
- Generic code has no name for its variable's `compare`; it sorts with `List.sort` and a lambda built from `<`.
- A second order on one element type takes a type of its own.

**Cost**, in working days: the ordering restriction about 3 (the checker, and the emitter's hidden argument); a field's own variables about 2 (the checker alone, since a value's representation does not change); the report, the guide's §7.3 and the library about 2. In all about 7.

## Why not type classes

A type class that can hold a set's operations is a class over the whole set type with the element an associated type, since Ernest has no variable over type constructors, with instances declared under conditions, superclasses, default methods, constraints inferred, a method resolved by its argument's type or the type expected, one instance per type under an orphan rule, and `==`, `compare` and the operators rebuilt as classes.

What it would give: no record at a call. `size(small)` and `fromList([3, 1, 3])` with an annotation choosing the representation, and no annotation on code written once.

What it would cost:
- **Nothing invisible (3).** What a method runs is chosen by a type the reader infers, and every constraint is a dictionary no one wrote; `empty` alone needs an annotation to mean anything.
- **One way (2).** Classes beside records of functions, and methods beside module functions.
- **Simple to parse (4).** `class`, `instance`, method signatures, associated types, and conditions in instance heads enter Appendix A.
- **Small (5).** Classes, instances, associated types, conditions, superclasses, defaults, coherence, orphans and ambiguity: each a section of the report, a set of new errors for the user, and rules across modules for the checker.
- **Work:** about six weeks against about seven days: two days for the lexer, parser, formatter and editor mode, three weeks for the types and the checker, one for the emitter's dictionaries, and days for the shell, `ern doc`, the report and the guide.

Type classes contain the proposal: a dictionary is a record whose methods are polymorphic as a field's own variables are, and passing it generalizes the ordering restriction's hidden argument. What they add is declared instances and resolution by type, which save the record at a call. For that return the cost is a second mechanism, a larger report, and a larger type system.

## What the decision also settles

- **The ordered set's name.** A file `orderedset.ern` provides the namespace `Orderedset` (§4.2), not `OrderedSet`.
- **Its representation.** `==` is structural, so the representation must be canonical: a sorted list is, and a tree whose shape follows the order of insertion is not.
- **Which of two elements it keeps** when `compare` finds them equal and `==` tells them apart.
- **The contract's fields** beyond the sketch's five.
- **When a type's operation is a member and when a module function** (the plan's MVP 2.99b item 4): a member is found by type only for an operator and `compare`, so the rest is a question of naming.
