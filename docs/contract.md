# Contracts

The ways code written once can use several representations of one thing, a set kept hashed and a set kept in order, laid side by side so that MVP 2.97 can choose. The last, E, is the recommendation. This note holds the alternatives until then; the choice goes to the report and the decisions log, and the note goes. The example marked `ernest` is today's Ernest and was compiled when the note was written (2026-09-29); those marked `sketch` are in syntax Ernest does not have.

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

That already breaks measure 3: the value holds a function, so `OrderedSet(Int)` has no `==` and cannot go to a peer. It keeps measure 4 by a rule of its own, `union` taking the first set's order. The alternatives that find `compare` by the element's type, B, C and D below, give both back: `OrderedSet(Int)` is a sorted list and nothing else, and `Int.compare` is found as `<` finds it today.

## Left out

Each of these fails a measure outright, and none is weighed further:

- **No contract**, each representation written for: code written once is written twice (measure 2).
- **Values that carry their operations**, records of closures, the guide's §7.3 first form: `union` cannot be written, the value has no `==` and cannot cross nodes, and `s.put(x)` is a second way to call `Set.put` (measures 1, 3 and 4). It stays the guide's form for values of several representations in one list.
- **Records of operations passed beside the data**, the guide's §7.3 second form, and the same with polymorphic fields (language feedback 64): the record is threaded through every caller, and nothing ties it to its type, so two orders fit one record type (measures 2 and 4).
- **A service's message type**, each representation a process: a set is a value, and every operation would be a message and a wait.
- **Structural records**, row polymorphism: the threading and the incoherence of records passed, and a second kind of record (measures 2 and 4, principle 2).
- **Implicit arguments**, Scala 3's givens: what is in scope decides, and two of one type are ambiguous or silently chosen (measure 4, principle 3).

## A. Signatures and functors

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
- **For:** a named contract, checked where a module claims it; `t(a)` stands for a type constructor inside a signature, with no higher-kinded variables in the core; polymorphic operations are simply functions; a signature extends another by inclusion. Two orders give two modules whose types differ, so a mix of orders is a type error (measure 4). All of it is explicit (principle 3).
- **Against:** a second language above the first: signatures, functors, application, and module paths in types (principle 5); every use names the module it applies, which is the machinery showing through (measure 2).
- **Cost:** a module language in the report, the checker and the compiled interfaces; Ernest's modules are files, and a functor is not one.

## B. Type classes

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
- **For:** meets measures 1 to 4: nothing threaded, one instance per type (coherence), polymorphic operations, superclasses, defaults. It would make `==`, `compare` and the operators instances of one mechanism (principle 2).
- **Against:** a class over `Set` itself, not `Set(a)`, needs a higher-kinded variable, and then cannot demand `Ord(a)` of `OrderedSet`'s elements, which is why Haskell's own library has no set class; the two-parameter class above avoids that at the price of functional dependencies. Instances need rules for where they may be declared (orphans), for overlap and for ambiguity; `empty()` alone cannot choose, so the user annotates (measure 5); a constraint is a second mark on a function's type, where §0 has `with M` as the only one; the dictionary is an argument no one wrote (principle 3).
- **Cost:** qualified types in the checker, instance resolution, dictionaries in the emitter, constraints in the compiled interfaces and in MVP 3.1's hashes; the most machinery of the four.

## C. Traits with associated types

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

- **The user writes** as with B.
- **For:** B's ergonomics without higher-kinded variables or functional dependencies, the element type being the trait's; coherence by a rule that an impl stands with its trait or its type, which also lets a contract be met for a type declared elsewhere.
- **Against:** associated types are a concept of their own; bounds are written (`where S : SetLike`), a second mark on types; Rust copies each generic function per type, where Ernest would pass the dictionary unseen (principle 3).
- **Cost:** close to B's, the associated type in place of the second parameter.

## D. Contracts as type members

Ernest's own shape, grown from how `<` finds `T.compare` today. A contract is a record type that the library names. A type meets it by declaring a member of that type in its own module. A contract's field, called through the contract, is the member of its argument's type, and the constraint that a type meets the contract is inferred and carried as `a=` is.

```sketch
// set.ern: the contract, and Set's member meeting it
export type Ops(s, a) =
    Ops(empty : s,
        put : (s, a) -> s,
        contains : (s, a) -> Bool,
        union : (s, s) -> s,
        foldLeft : (s, b, (b, a) -> b) -> b)     // b is the field's own

export let Set.ops : Set.Ops(Set(a), a) = Set.Ops(empty = Set.empty, put = Set.put, ...)

// orderedset.ern: an OrderedSet(a) is its items, ordered by a's compare
export abstract type OrderedSet(a) = OrderedSet(List(a))
export let OrderedSet.ops : Set.Ops(OrderedSet(a), a) = Set.Ops(...)
export fn min(s : OrderedSet(a)) : Optional(a) = ...

// written once: Set.Ops.put resolves against its argument's type, as < does
fn fromList(xs : List(a)) : s = List.foldLeft(xs, Set.Ops.empty, Set.Ops.put)

let small : OrderedSet(Int) = fromList([3, 1, 3])
```

The field `foldLeft` names a variable, `b`, that the record type does not take: each use of the field chooses its own `b`, as OCaml's polymorphic record fields allow. Today's checker refuses it, `type variable b is not a parameter of the type` (language feedback 64), and D needs it.

- **The user writes** `Set.put(s, x)`, `OrderedSet.put(s, x)` and `OrderedSet.min(s)` as today, and `fromList(xs)` written once. An `OrderedSet(Int)` is its sorted items, with `==`.
- **For:** measures 1 to 4. Coherence comes by construction: a type's members belong to its module (§4.2), so a type meets a contract once, where it is declared, and no one else's module can. There is no higher-kinded variable, since the contract is over the whole type. `compare` and the operators become contracts of one rule (principle 2), and nothing is written on a function's type, the constraint being inferred as `a=` is.
- **Against:** what the next section lists.
- **Cost:** constraints on type variables, inferred and printed, with the dictionary passed by the emitter; resolution by the argument's type or the expected type; members whose own type carries a constraint; the polymorphic field. It is less surface than B and C: no classes, no instance declarations, no orphans and no written bounds. It is not less machinery at the core: inferred constraints and a dictionary passed unseen are what B and C are made of.

## What D has not settled

1. **The polymorphic field, with its effects.** `Set.foldLeft` is polymorphic in its effect as in its accumulator, so the field needs a variable and an effect variable of its own: a rank-2 type confined to declared fields, where the log's *Dropped from Unison* dropped rank-n types. Whether inference keeps principal types with such fields and inferred constraints together is the question the literature finds hard, and D stands or falls on it. Without it, a contract cannot hold `foldLeft`, and D shrinks to what its types close over.
2. **An operation chosen by the expected type.** `Set.Ops.empty` has no argument to resolve against, so the expected type chooses, and `fromList(xs)` needs an annotation somewhere or reports an ambiguity, Haskell's `read` problem (measure 5).
3. **`==` does not fit.** `compare` and the operators are members a type declares; `==` is structural and every type without a function or an address has it. Either `==` stays a rule of its own, and "one mechanism for three" is two, or every type meets an equality contract without declaring it, which is a rule of its own too.
4. **A member with a condition.** `OrderedSet.ops` exists only for elements that have `compare`, a member whose type carries a constraint, Haskell's `instance Ord a => …`, which the sketch passes over.
5. **No contract for another's type.** Only a type's own module can declare its member, so a user cannot make `List` meet `Set.Ops`, only wrap it. C's rule, the impl beside its trait or its type, allows it, but a member belongs to its type's namespace (§4.2), and D's framing forbids it.
6. **An argument no one wrote.** The member is passed unseen. Principle 3 is argued only by `<`, which does the same today, and a strict reader may take that as a precedent rather than a reason.

## E. Recommended: contracts met where a type is declared

D, settled, all things considered. Go and Roc chose its central rule and live with it: a type's operations are declared in its own module, and nowhere else. Java's lesson is that a contract feels simple when it is said where the type is declared and its polymorphic operations are written, not inferred.

1. **A contract is a record type the library names**, as `Set.Ops`. A field may name variables and effect variables of its own, declared in the field's type and never inferred. The record is checked where it is built and instantiated where a field is selected, as OCaml's polymorphic fields are, so a field's polymorphism is checked, never inferred (language feedback 64).
2. **A type meets a contract in its own module, by a member**, `let OrderedSet.ops : Set.Ops(OrderedSet(a), a) = …`, which says so in its annotation where a reader looks. A member's type may carry constraints on the type's parameters, as `Set.ops` carries `a=` today and `OrderedSet.ops` needs its elements' order.
3. **A contract's field, called through the contract, is the member of its type**: `Set.Ops.put(s, x)` resolves against the type of `s`, as `<` resolves `T.compare`, and `Set.Ops.empty` against the type expected, an annotation deciding where nothing else does. Where nothing decides, the error names the contract and asks for the type: ``fromList gives any type that meets `Set.Ops`; say which, as `: Set(Int)` ``.
4. **The constraint is inferred and printed, never written**, as `a=` is. `:type fromList` shows it, which is where principle 3 finds it.
5. **`compare` is the first contract.** `<` on a type variable infers that its type has `compare`, as `==` infers `a=`, so `OrderedSet(a)` orders its elements by their type's `compare`, and an order of one's own is a type of one's own, `Descending(Int)` with its `compare`.
6. **`==` stays as it is.** It is structural, and every type without a function or an address has it, the derived case, as Roc derives equality; no type declares it.
7. **Values of several representations in one list stay the guide's first form**, records of closures. A value packed with its type's member, Java's `Set<E> s`, is a later addition, not part of this.

```sketch
// set.ern: the contract, and Set meeting it
export type Ops(s, a) =
    Ops(empty : s,
        put : (s, a) -> s,
        contains : (s, a) -> Bool,
        union : (s, s) -> s,
        foldLeft : (s, b, (b, a) -> b with e) -> b with e)     // b and e are the field's own

export let Set.ops : Set.Ops(Set(a), a) =
    Set.Ops(empty = Set.empty, put = Set.put, contains = Set.contains, union = Set.union,
            foldLeft = Set.foldLeft)

// orderedset.ern: its items, in the order of their type's compare
export abstract type OrderedSet(a) = OrderedSet(List(a))
export let OrderedSet.ops : Set.Ops(OrderedSet(a), a) = Set.Ops(empty = OrderedSet([]), put = put, ...)
export fn put(s : OrderedSet(a), x : a) : OrderedSet(a) = ...     // x < y, a's compare
export fn min(s : OrderedSet(a)) : Optional(a) = ...

// the user
fn fromList(xs : List(a)) : s = List.foldLeft(xs, Set.Ops.empty, Set.Ops.put)
fn size(set : s) : Int = Set.Ops.foldLeft(set, 0, fn(n, _) = n + 1)

let small : OrderedSet(Int) = fromList([3, 1, 3])
OrderedSet.min(small)           // Some(1)
small == fromList([1, 3])       // true: an OrderedSet(Int) is data
```

**For:**
- The five measures. The user of `Set` and `OrderedSet` writes each as today and `fromList(xs)` once, threads nothing, holds data that has `==` and crosses nodes, and cannot mix two orders, which are two types.
- Coherence by construction: a type's members are its module's (§4.2), so there is one per type, and no orphan rule is needed.
- No new keyword and no new kind of declaration: a contract is a type and a member is a `let`. Nothing is written on a function's type, `with M` staying the only mark (§0).
- No variable stands for a type constructor, since a contract is over a whole type.
- It grows from what the report has: the inferred `a=`, type members, and `<` resolving `T.compare`. `compare` joins as its first contract, and the operators can follow.
- Polymorphic fields are declared, so inference only checks them, the property that makes Java's generic methods and OCaml's polymorphic fields easy.
- Go and Roc are precedents at scale for its rule, and Roc for leaving `==` derived.

**Against:**
- The core is type classes' core: constraints inferred on type variables, and a dictionary passed where no one wrote it. It is less surface, not less machinery, and a strict reader will call it restricted type classes, rightly.
- The argument no one wrote rests on `<` as its precedent (principle 3), and its reason is that the type shows it.
- An operation that takes no value of its type is chosen by the expected type, so a user sometimes annotates (measure 5).
- No contract for another's type: the built-in `List` cannot be made a `Set.Ops`, only wrapped.
- A field's own variable carries no inferred restriction, so an operation that needs `==` on it does not fit a field.
- Java's interface values, a set of either representation in one variable, wait for a later addition.
- MVP 3.1's hashes must count the members a definition resolves, which its text does not name.

**What it asks of the implementation**, in order: polymorphic fields, declared, with their effects; ordering inferred as a constraint beside `a=`; constraints of named contracts, inferred, printed and carried in compiled interfaces; resolution by argument and by expected type, with its error; the dictionary passed by the emitter; then `Set.Ops`, `OrderedSet` in the standard library, and the guide's §7.3 rewritten over them.

## Side by side

| | written once | `union` | `foldLeft` | `OrderedSet` extends `Set` | two orders refused | nothing threaded | `OrderedSet(Int)` is data | new in the language |
|---|---|---|---|---|---|---|---|---|
| A. signatures, functors | yes | yes | yes | by inclusion | yes | named once | yes | a module language |
| B. type classes | yes | yes | yes | superclass | yes | yes | yes | classes, instances, constraints |
| C. traits | yes | yes | yes | supertrait | yes | yes | yes | traits, associated types, bounds |
| D. type members | yes | yes | if the field holds | by holding | yes | yes | yes | inferred contract constraints, the field |
| E. recommended | yes | yes | yes, declared | by holding | yes, as two types | yes | yes | inferred contract constraints, declared polymorphic fields, ordering inferred |

## To think hard about

- **Is a dictionary found by type invisible?** Principle 3 asks that control flow and failure be visible in the code or in the type. In B, C and D the operation called is decided by a type the code states or infers, and no argument is written. `<` has done this since the first MVP. A, alone, keeps everything written.
- **One mechanism for three.** `==`, `compare` and the operators resolve by type today, each by a rule of its own. A contract mechanism that absorbed them would be one way (principle 2); one that stood beside them would be a fourth.
- **Where may a type meet a contract?** Only in its own module (D) gives coherence for nothing and forbids retrofitting. B and C allow more and need orphan rules.
- **Written or inferred constraints.** §0 keeps `with M` as the only mark written on a function type, and `a=` is inferred and never written. D keeps that; B and C write bounds.
- **What the user annotates.** A contract whose operation takes no value of the type, `empty`, is chosen by the expected type. How often does a user then write `: OrderedSet(Int)`?
- **What crosses nodes.** A record of functions cannot, and a dictionary found by type need not, since each node finds its own. B, C and D keep functions out of values; A's modules are not values.
- **MVP 3.1's hashes.** A definition's hash names what it uses. A dictionary found by type is used without being named, and its instance's hash must enter the definition's.
