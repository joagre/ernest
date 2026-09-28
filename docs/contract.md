# Contracts

The ways code written once can use several representations of one thing, a set kept hashed and a set kept in order, laid side by side so that MVP 2.97 can choose. This note holds the alternatives until then; the choice goes to the report and the decisions log, and the note goes. The examples marked `ernest` are today's Ernest and were compiled and run when the note was written (2026-09-29); those marked `sketch` are in syntax Ernest does not have.

## What the user should see

The measure is the user of `Set` and `OrderedSet`, who should see none of the machinery:

1. **Each type on its own reads as today.** `Set.put(s, x)`, and `OrderedSet.put(s, x)` and `OrderedSet.min(s)`: the same verbs for the same operations (E.0 shape rule 2), and `OrderedSet`'s own beside them.
2. **Code written once is called as any function is.** `fromList([3, 1, 3])` gives a `Set(Int)` or an `OrderedSet(Int)` as the caller asks, with no argument that only carries machinery.
3. **An `OrderedSet(Int)` is data.** It has `==`, keys a `Map`, and goes to a peer in a message, as a `Set(Int)` does.
4. **A wrong mix is refused, not computed.** Two sets ordered differently cannot meet in `union` and give a set in neither order.
5. **A mistake is reported in the user's words**, as a function or a type the user wrote, never as a dictionary, an instance or a hidden argument.

## What Ernest has today

- **Three resolutions by type.** `==` carries an inferred equality constraint, written `a=` when a type is printed (report §3.10); `<` finds `T.compare` in the operand type's namespace (§3.10); `+` and the other operators resolve against the operand's type (§4.8). Each is a contract of one or two operations found by the type: `compare` and an operator a type meets in its own module, and `==` every type meets that holds no function or address.
- **No type variable stands for a type constructor.** `s` may be `Set(Int)`, never `Set` alone.
- **A function cannot cross nodes**, alone or inside a value (§3.11), and a value that holds one has no `==`.
- **The five principles** (§0): least surprise (1), one way (2), nothing invisible (3), simple to parse (4), small (5).

## The running example

A simplified `Set`: `empty`, `put`, `contains`, `union`, and `foldLeft`, whose accumulator is a type of its own, the operation that tests whether a contract can hold a polymorphic operation. An `OrderedSet` has the same five and `min`. Code written once: `fromList`, and `size` through `foldLeft`.

Today `OrderedSet` must carry its `compare` in each value, since nothing else can give it one:

```ernest
// orderedset.ern (namespace Orderedset)
export abstract type OrderedSet(a) = OrderedSet(compare : (a, a) -> Ordering, items : List(a))

export fn empty(compare : (a, a) -> Ordering) : OrderedSet(a) =
    OrderedSet(compare = compare, items = [])

export fn put(s : OrderedSet(a), x : a) : OrderedSet(a) =
    OrderedSet(..s, items = inserted(s.items, x, s.compare))

export fn contains(s : OrderedSet(a), x : a) : Bool =
    List.any(s.items, fn(y) = s.compare(x, y) == Equal)

export fn union(s : OrderedSet(a), t : OrderedSet(a)) : OrderedSet(a) =
    List.foldLeft(t.items, s, put)

export fn foldLeft(s : OrderedSet(a), acc : b, step : (b, a) -> b) : b =
    List.foldLeft(s.items, acc, step)

export fn min(s : OrderedSet(a)) : Optional(a) =
    List.get(s.items, 0)
```

That already breaks measure 3: the value holds a function, so `OrderedSet(Int)` has no `==` and cannot go to a peer. It keeps measure 4 by a rule of its own, `union` taking the first set's order. The alternatives that find `compare` by the element's type, H, I and K below, give both back: `OrderedSet(Int)` is a sorted list and nothing else, and `Int.compare` is found as `<` finds it today.

## A. No contract

Each representation is written for, and code written once is written twice.

```ernest
fn fromListHashed(xs : List(a)) : Set(a) =
    List.foldLeft(xs, Set.empty, Set.put)

fn fromListOrdered(compare : (a, a) -> Ordering, xs : List(a)) : Orderedset.OrderedSet(a) =
    List.foldLeft(xs, Orderedset.empty(compare), Orderedset.put)
```

- **The user writes** each type's functions, as today, and two of everything written once.
- **For:** nothing new, nothing hidden; every call says what it calls.
- **Against:** fails measure 2 outright, and a third representation means a third copy.
- **Cost:** none.

## B. Values that carry their operations

Each value is a record of closures over its representation: an object. The guide's §7.3 teaches it as its first form.

```ernest
type SetOf(a) = SetOf(put : (a) -> SetOf(a), contains : (a) -> Bool, items : () -> List(a))

fn hashed(s : Set(a)) : SetOf(a) =
    SetOf(put = fn(x) = hashed(Set.put(s, x)),
          contains = fn(x) = Set.contains(s, x),
          items = fn() = Set.toList(s))

fn ordered(s : Orderedset.OrderedSet(a)) : SetOf(a) =
    SetOf(put = fn(x) = ordered(Orderedset.put(s, x)),
          contains = fn(x) = Orderedset.contains(s, x),
          items = fn() = Orderedset.foldLeft(s, [], fn(acc, x) = acc <> [x]))

fn fromList(empty : SetOf(a), xs : List(a)) : SetOf(a) =
    List.foldLeft(xs, empty, fn(s, x) = s.put(x))
```

- **The user writes** `fromList(hashed(Set.empty), xs)`, and then `s.put(x)` in place of `Set.put(s, x)`: a second way to call the same operation.
- **For:** values of different representations share one list or one message type; nothing new in the language.
- **Against:** `union` cannot be written, since it cannot see inside the other set; `foldLeft` needs its accumulator's type fixed per record; `SetOf` has no `==` and cannot cross nodes; `OrderedSet.min` is lost behind the record. Fails measures 1, 3 and 4.
- **Cost:** none, and the guide's §7.3 keeps teaching it for what it does well, values of several representations in one place.

## C. Operations passed beside the data

The contract is a record of operations over a representation `s`, passed with the data: dictionary passing, as a compiler lowers type classes, written by hand. The guide's §7.3 teaches it as its second form.

```ernest
type SetOps(s, a) =
    SetOps(empty : s, put : (s, a) -> s, contains : (s, a) -> Bool, union : (s, s) -> s)

fn hashedOps() : SetOps(Set(a), a) =
    SetOps(empty = Set.empty, put = Set.put, contains = Set.contains, union = Set.union)

fn orderedOps(compare : (a, a) -> Ordering) : SetOps(Orderedset.OrderedSet(a), a) =
    SetOps(empty = Orderedset.empty(compare),
           put = Orderedset.put,
           contains = Orderedset.contains,
           union = Orderedset.union)

fn fromList(ops : SetOps(s, a), xs : List(a)) : s =
    List.foldLeft(xs, ops.empty, ops.put)
```

A contract that extends another holds it: `type OrderedSetOps(s, a) = OrderedSetOps(set : SetOps(s, a), min : (s) -> Optional(a))`.

- **The user writes** `fromList(hashedOps(), xs)` and `fromList(orderedOps(Int.compare), xs)`, and every function above `fromList` takes the record to pass it on.
- **For:** binary operations work, since the representation's type is kept; everything is visible; nothing new in the language.
- **Against:** the record is threaded through every caller (measure 2); nothing ties a record to its type, so two `orderedOps` of different orders both fit `SetOps(OrderedSet(Int), Int)` (measure 4, saved only by `OrderedSet` carrying its `compare`); the contract cannot hold `foldLeft`, which the checker refuses: `type variable b is not a parameter of the type`; every program writes its own `SetOps`, since nothing in the library names it.
- **Cost:** none. What it lacks is D's field and a contract the library names.

## D. C, with polymorphic fields

C, where a field's type may name variables the record does not take, each field's own, as OCaml's polymorphic record fields do (language feedback 64). The library can then name the contract, and the types meet it.

```sketch
// set.ern: the contract, named by the library, and Set's record
export type Ops(s, a) =
    Ops(empty : s,
        put : (s, a) -> s,
        contains : (s, a) -> Bool,
        union : (s, s) -> s,
        foldLeft : (s, b, (b, a) -> b) -> b)     // b is the field's own

export let ops : Set.Ops(Set(a), a) = Set.Ops(empty = Set.empty, put = Set.put, ...)

// written once
fn size(ops : Set.Ops(s, a), set : s) : Int = ops.foldLeft(set, 0, fn(n, _) = n + 1)
```

- **The user writes** `size(Set.ops, s)` and `size(Orderedset.ops(Int.compare), t)`: C's threading, with the whole contract.
- **For:** the smallest step that lets a contract hold what a library type has; inference stays Hindley-Milner's, the field checked where the record is built and instantiated where it is selected.
- **Against:** everything else C lacks: threading, no tie between a record and its type. A field's own variable carries no inferred restriction, so a field that needs `==` on it does not fit.
- **Cost:** a type scheme inside a type declaration, a rank-2 type confined to declared fields, where the log's *Dropped from Unison* dropped rank-n types (principle 5).

## E. A service's message type

The contract is a message type, and each representation a process that takes it. The guide's §7.3 ends on it for a service with state.

```ernest
type SetMsg(a) = Put(a) | Has(item : a, reply : Reply(Bool)) | Size(Reply(Int))

fn hashed(s : Set(a)) : Unit with SetMsg(a) =
    receive {
        Put(x) -> hashed(Set.put(s, x))
      | Has(item = x, reply = r) -> {
            answer(r, Set.contains(s, x));
            hashed(s)
        }
      | Size(r) -> {
            answer(r, Set.size(s));
            hashed(s)
        }
    }

// written once, for any process that takes SetMsg
fn fill(set : Address(SetMsg(a)), xs : List(a)) : Optional(Int) with m = {
    List.foreach(xs, fn(x) = send(set, Put(x)));
    Address.call(set, Size, 1000)
}
```

- **The user writes** `fill(spawn(Local, fn() = hashed(Set.empty)), xs)`: a process for a value.
- **For:** Ernest's own concept, with nothing new; the address crosses nodes; the representation stays private to its process.
- **Against:** a set is a value and not a service: every operation is a message and a wait; `union` of two sets is two processes talking; nothing is pure. The right form for a service with state, the wrong one for a data type.
- **Cost:** none.

## F. Structural records

A function takes any record that has at least the fields it uses, a row type: `{ empty : s, put : (s, a) -> s | r }`. A contract needs no declaration, and a bigger record extends a smaller by having more fields.

```sketch
fn fromList(ops : { empty : s, put : (s, a) -> s | rest }, xs : List(a)) : s =
    List.foldLeft(xs, ops.empty, ops.put)
```

- **The user writes** C's calls, with any record that fits.
- **For:** extension by width, with no declared contract; inference with rows is well understood.
- **Against:** C's threading and coherence, and a second kind of record beside the named one Ernest has (principle 2); types printed with rows are hard to read (measure 5).
- **Cost:** row polymorphism in the checker and the report (principle 5).

## G. Signatures and functors

ML's modules. A contract is a signature, a module meets it, and code written once is a functor, a module that takes modules. OCaml's `Set.Make(Ord)` is this.

```sketch
signature SET = {
    type t(a)
    fn empty() : t(a)
    fn put(s : t(a), x : a) : t(a)
    fn union(s : t(a), u : t(a)) : t(a)
    fn foldLeft(s : t(a), acc : b, step : (b, a) -> b) : b
}

module Ordered(O : { fn compare(x : Int, y : Int) : Ordering }) : SET = { ... }
module Tools(S : SET) = { fn fromList(xs : List(a)) : S.t(a) = List.foldLeft(xs, S.empty(), S.put) }

let ascending = Tools(Ordered(Int))       // applied once, then used by name
```

- **The user writes** `Tools(Set).fromList(xs)`, or a name bound to the application.
- **For:** a named contract, checked where a module claims it; `t(a)` stands for a type constructor inside a signature, with no higher-kinded variables in the core; polymorphic operations are simply functions; a signature extends another by inclusion. Two orders give two modules whose types differ, so a mix of orders is a type error (measure 4). All of it is explicit.
- **Against:** a second language above the first: signatures, functors, application, and module paths in types (principle 5); every use names the module it applies (measure 2).
- **Cost:** a module language in the report, the checker and the compiled interfaces; Ernest's modules are files, and a functor is not one.

## H. Type classes

Haskell's classes. A contract is a class, a type meets it with an instance, and the instance is found by type, the checker passing it as a hidden argument.

```sketch
class SetLike(s, a) | s -> a {            // two parameters, a fixed by s
    fn empty() : s
    fn put(set : s, x : a) : s
    fn union(set : s, other : s) : s
    fn foldLeft(set : s, acc : b, step : (b, a) -> b) : b
}
instance SetLike(Set(a), a) where Eq(a) { fn empty() = Set.empty ... }
instance SetLike(OrderedSet(a), a) where Ord(a) { ... }   // compare found by a's type
class SetLike(s, a) => OrderedSetLike(s, a) { fn min(set : s) : Optional(a) }

fn fromList(xs : List(a)) : s where SetLike(s, a) = List.foldLeft(xs, empty(), put)

let small : OrderedSet(Int) = fromList([3, 1, 3])      // the annotation chooses
```

- **The user writes** `fromList(xs)`, the result's type choosing the instance; `OrderedSet.min(s)` as a function of its own.
- **For:** meets measures 1 to 4: nothing threaded, one instance per type (coherence), polymorphic operations, superclasses, defaults. It would make `==`, `compare` and the operators three instances of one mechanism (principle 2).
- **Against:** a class over `Set` itself, not `Set(a)`, needs a higher-kinded variable, and then cannot demand `Ord(a)` of `OrderedSet`'s elements, which is why Haskell's own library has no set class; the two-parameter class above avoids that at the price of functional dependencies. Instances need rules for where they may be declared (orphans), for overlap and for ambiguity; `empty()` alone cannot choose, so the user annotates (measure 5); a constraint is a second mark on a function's type, where §0 has `with M` as the only one; the dictionary is an argument no one wrote (principle 3).
- **Cost:** qualified types in the checker, instance resolution, dictionaries in the emitter, constraints in the compiled interfaces and in MVP 3.1's hashes; the most machinery of all.

## I. Traits with associated types

Rust's traits and Swift's protocols: type classes over a whole type, the element type a member of the trait rather than a parameter.

```sketch
trait SetLike {
    type Item
    fn empty() : Self
    fn put(self, x : Item) : Self
    fn foldLeft(self, acc : b, step : (b, Item) -> b) : b
}
impl SetLike for Set(a) where a has == { type Item = a ... }
impl SetLike for OrderedSet(a) where a has compare { ... }

fn fromList(xs : List(S.Item)) : S where S : SetLike = ...
```

- **The user writes** as with H.
- **For:** H's ergonomics without higher-kinded variables or functional dependencies, the element type being the trait's; coherence by a rule that an impl stands with its trait or its type.
- **Against:** associated types are a concept of their own; bounds are written (`where S : SetLike`), a second mark on types; Rust copies each generic function per type, where Ernest would pass the dictionary unseen (principle 3).
- **Cost:** close to H's, the associated type in place of the second parameter.

## J. Implicit arguments

Scala 3's givens and OCaml's proposed modular implicits: C's records, found among the values in scope that are marked for it when the caller does not pass one.

```sketch
given hashedOps : SetOps(Set(a), a) = ...
fn fromList(xs : List(a), using ops : SetOps(s, a)) : s = List.foldLeft(xs, ops.empty, ops.put)

let s : Set(Int) = fromList([3, 1, 3])     // ops found in scope
```

- **The user writes** `fromList(xs)`, or passes a record explicitly where two would fit.
- **For:** a small step from C: the records stay ordinary values, and explicit passing still works.
- **Against:** what is in scope decides, which a reader must search for (principle 3); two givens of one type are an ambiguity or a silent choice, so coherence is not had (measure 4); scope rules for givens join the report (principle 5).
- **Cost:** resolution by type among marked values, and the rules that make it deterministic.

## K. Contracts as type members

Ernest's own shape, grown from how `<` finds `T.compare` today. A contract is a record type that the library names. A type meets it by declaring a member of that type in its own module. A contract's field, called through the contract, is the member of its argument's type, and the constraint that a type meets the contract is inferred and carried as `a=` is.

```sketch
// set.ern: the contract, and Set's member meeting it
export type Ops(s, a) =
    Ops(empty : s,
        put : (s, a) -> s,
        contains : (s, a) -> Bool,
        union : (s, s) -> s,
        foldLeft : (s, b, (b, a) -> b) -> b)     // D's polymorphic field

export let Set.ops : Set.Ops(Set(a), a) = Set.Ops(empty = Set.empty, put = Set.put, ...)

// orderedset.ern: an OrderedSet(a) is its items, ordered by a's compare
export abstract type OrderedSet(a) = OrderedSet(List(a))
export let OrderedSet.ops : Set.Ops(OrderedSet(a), a) = Set.Ops(...)
export fn min(s : OrderedSet(a)) : Optional(a) = ...

// written once: Set.Ops.put resolves against its argument's type, as < does
fn fromList(xs : List(a)) : s = List.foldLeft(xs, Set.Ops.empty, Set.Ops.put)

let small : OrderedSet(Int) = fromList([3, 1, 3])
```

- **The user writes** `Set.put(s, x)`, `OrderedSet.put(s, x)` and `OrderedSet.min(s)` as today, and `fromList(xs)` written once. An `OrderedSet(Int)` is its sorted items, with `==`.
- **For:** measures 1 to 4. Coherence comes by construction: a type's members belong to its module (§4.2), so a type meets a contract once, where it is declared, and no one else's module can. There is no higher-kinded variable, since the contract is over the whole type. It turns `==`, `compare` and the operators into three contracts of one rule (principle 2), and nothing is written on a function's type, the constraint being inferred as `a=` is.
- **Against:** a type meets a contract only in its own module, so the built-in `List` cannot be made a `Set.Ops` by a user, only wrapped. `Set.Ops.empty` has no argument to resolve against, so the expected type chooses, and an annotation is sometimes needed (measure 5). `OrderedSet`'s member needs its elements ordered by their type, an ordering constraint beside `a=` that the report does not have. The member is still an argument no one wrote (principle 3), though the type it comes from is in the code. It needs D's field for `foldLeft`.
- **Cost:** constraints on type variables, inferred and printed, with the dictionary passed by the emitter; resolution by the argument's type or the expected type; an ordering constraint; D's field. It is less than H and I: no classes, no instance declarations, no orphans and no written bounds.

## Side by side

| | written once | `union` | `foldLeft` | `OrderedSet` extends `Set` | two orders refused | nothing threaded | `OrderedSet(Int)` is data | new in the language |
|---|---|---|---|---|---|---|---|---|
| A. no contract | no | yes | yes | by convention | yes | yes | no | nothing |
| B. objects | yes | no | no | no | no | yes | no | nothing |
| C. records passed | yes | yes | no | by holding | no | no | no | nothing |
| D. C with polymorphic fields | yes | yes | yes | by holding | no | no | no | a field's own variables |
| E. a service | yes | awkward | yes | by message type | yes | yes | no | nothing |
| F. structural records | yes | yes | no | by width | no | no | no | rows |
| G. signatures, functors | yes | yes | yes | by inclusion | yes | named once | yes | a module language |
| H. type classes | yes | yes | yes | superclass | yes | yes | yes | classes, instances, constraints |
| I. traits | yes | yes | yes | supertrait | yes | yes | yes | traits, associated types, bounds |
| J. implicits | yes | yes | no | by holding | no | yes | no | givens and their scope |
| K. type members | yes | yes | with D | by holding | yes | yes | yes | inferred contract constraints, D |

## To think hard about

- **Is a dictionary found by type invisible?** Principle 3 asks that control flow and failure be visible in the code or in the type. In H, I and K the operation called is decided by a type the code states or infers, and no argument is written. `<` has done this since the first MVP.
- **One mechanism for three.** `==`, `compare` and the operators resolve by type today, each by a rule of its own. A contract mechanism that absorbed them would be one way (principle 2); one that stood beside them would be a fourth.
- **Where may a type meet a contract?** Only in its own module (K) gives coherence for nothing and forbids retrofitting. H and I allow more and need orphan rules.
- **Written or inferred constraints.** §0 keeps `with M` as the only mark written on a function type, and `a=` is inferred and never written. K keeps that; H and I write bounds.
- **What the user annotates.** A contract whose operation takes no value of the type, `empty`, is chosen by the expected type. How often does a user then write `: OrderedSet(Int)`?
- **What crosses nodes.** A record of functions cannot, and a dictionary found by type need not, since each node finds its own. B, C and D keep functions in values; H, I and K do not.
- **MVP 3.1's hashes.** A definition's hash names what it uses. A dictionary found by type is used without being named, and its instance's hash must enter the definition's.
