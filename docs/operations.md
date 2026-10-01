# Operations records

*The specification of code written once over several representations of one type. MVP 2.99b's item 5 decides and builds it; the log's *Operations Records*, *Members, Operators, and No Hidden Argument*, *The Operations Note Rewritten*, *The Order Bound Once* and *MVP 2.99b's Questions, One by One* argue its choices. It was rewritten on 2026-10-01 under two rules the principles review gave the report that day, that no operator carries a hidden argument (§4.8) and that a member is an operator, `compare` or `negate` (§4.5), and on 2026-10-02 so that the record holds the set's vocabulary and the library writes no generic functions. The code below was built and run on 2026-10-02 as user modules under other names, since `Set` is a namespace of the standard library; it is written here with the names it has there.*

Ernest has one set in its standard library, `Set`, a hash set. A second one keeps its elements in order, and generic code, a `fromList` or a `union`, works on both. Java would reach for an interface, Haskell for a type class and ML for a functor. Ernest has no type classes. It writes *operations records*: records of a type's operations that the caller passes explicitly. That is dictionary passing (Wadler and Blott 1989), written by the program instead of by the compiler, with nothing passed that the program did not write. The § numbers cite Ernest's report.

## Why sets

Sets are the known hard case for type classes. Haskell's `Data.Set` cannot be a `Functor`: `fmap` puts no constraint on the result's element, while a set's `map` needs `Ord` on it (Hughes 1999). Without variables over type constructors, a class over whole collection types needs the element type as a function of the collection type, which takes functional dependencies (Jones 2000) or associated type synonyms (Chakravarty, Keller and Peyton Jones 2005). OCaml makes a set a functor over an ordered type, `Set.Make(Ord)`, whose application fixes the order. Operations records are closest to ML structures passed as values (Russo 2000), as OCaml's first-class modules are. Abstractions over type constructors, such as `Functor` or `Monad`, stay out of reach, because Ernest has no variables over type constructors.

## Requirements

1. Each type's operations are called through its module: `Set.put(s, x)`, `OrderedSet.put(s, x)`, and the ordered set's own `OrderedSet.min(s)`.
2. Generic code is an ordinary function, and the caller chooses the representation.
3. An ordered set is data: it has `==`, can key a `Map`, and can be sent to another node.
4. Sets in different orders cannot be combined.
5. Errors name what the user wrote: a function, a type, a record.

Requirement 1 is met for `Set`, and for the ordered set's operations that need no order, `OrderedSet.min(s)` among them. `OrderedSet.put(s, x)` cannot exist: the order is a function, and Ernest passes none hidden (§4.8). The program binds the ordered set's record once, `let ints = OrderedSet.operations(Int.compare)`, and writes `ints.put(s, x)`, as OCaml's program applies `Set.Make(Int)` once and writes `IntSet.add x s`. That line is the floor §4.8 sets. Nothing else falls on the program, and no function of the ordered set's module takes the order.

## The specification

Nothing in the type system changes, and the syntax does not. The rules give the standard library a convention and two files; the section *What changes in Ernest* lists the report's sections they touch.

1. **An order is a function the program names once.** `<` resolves against a type the compiler knows and takes no hidden argument (§4.8), so no function receives a `compare` it did not ask for. An ordered set's order, of type `(a, a) -> Ordering`, is written where the program binds the set's record, `let ints = OrderedSet.operations(Int.compare)`, and nowhere else. An operation that needs the order is a field of that record: `ints.contains`, `ints.put`, `ints.remove`, `ints.fromList`, `ints.union`, `ints.intersection`, `ints.difference` and `ints.isSubset`. One that does not is a function of the module: `size`, `isEmpty`, `toList`, `filter`, `foldLeft`, `foreach`, `any`, `all`, `find`, `min` and `max`, since a walk of a sorted list keeps its order. No function of `ordered_set.ern` takes the order, so an ordered operation has one spelling.
2. **A record holds the set's vocabulary whose types name only its parameters.** `Set.Operations(s, a)` holds twelve operations of E.0 rule 2's vocabulary for a container and a set: `empty`, `size`, `isEmpty`, `contains`, `put`, `remove`, `fromList`, `toList`, `union`, `intersection`, `difference` and `isSubset`, each of a type that names nothing but `s` and `a`. The record is an ordinary type (§3.5), and selecting a field is ordinary selection, resolved against the binding's or the parameter's type (§4.8). The vocabulary's other eight, `map`, `filter`, `filterMap`, `foldLeft`, `foreach`, `any`, `all` and `find`, take a callback with an effect variable, and `foldLeft` an accumulator of its own type, which a field could hold only with a type quantified inside it; they stay functions of each representation's module. A restriction a field's function carries travels with the record: binding the record's `a` to `Set`'s functions passes the equality restriction (§3.10), so `Set.operations` has the type `Set.Operations(Set(a=!), a=!)`, and `Set.operations.fromList([f])` with a function `f` is refused, naming `Set`'s element.
3. **Code written once is the program's.** Requirement 2 asks for an ordinary function that the caller gives a record, and the program writes it over the record's fields: `fn common(list, other, operations) = operations.toList(operations.intersection(operations.fromList(list), operations.fromList(other)))`. The library writes no generic function over the record. Each would be one call of a field or a pipe of two, which E.0 rule 4 refuses, and the vocabulary a reader looks for is in the record already. Generic code that needs a callback folds over the record's `toList` with `List`'s functions.
4. **A representation exports its record as `operations`**: a `let` where it needs nothing, `Set.operations`, whose fields are `Set`'s own functions, and a function of what it needs, `OrderedSet.operations(compare)`, whose fields close over the order. A representation fills each field itself, as its structure gives: `OrderedSet`'s `union` merges two sorted lists. A type may meet several records, as a class implements several interfaces, and a record may hold another as a field, as one interface extends another: a second ordered representation would bring `OrderedSet.Operations(s, a)`, holding `set : Set.Operations(s, a)` beside `min` and `max`. Any module can build a record from the operations another module exports.
5. **An order belongs to an element type.** The program binds one record for each element type it keeps ordered sets of, over the type's `compare`, or over the function it would have declared as `compare` had the type a module of its own, as a tuple has none. A second order on one type is a second type with its own `compare`, `type Descending = Descending(Int)` with `fn Descending.compare`, as Haskell's `Down` and OCaml's second functor application are. So two sets in different orders have different types, and they cannot meet: `ints.union(up, down)` with `down : OrderedSet.Set(Descending)` is refused. Between two records of one element type, one over `Int.compare` and one over a function that reverses it, the rule is the program's promise, which nothing checks, as `compare`'s laws are not checked.
6. **`put` keeps the element already there** where `compare` says `Equal`, so that no choice is left unstated.
7. **A list that mixes representations needs a second record type**, one that hides `s`: its functions close over one set, and its `put` returns another such record (Mitchell and Plotkin 1988). It loses operations on two sets, such as a `union` that reaches both representations (Bruce et al. 1995), and since it holds functions it has no `==`.
8. **`OrderedSet` joins the standard library in `ordered_set.ern`**, a file whose words joined by `_` name one namespace, which §4.2 and §11.1 gain in MVP 2.99b's item 4. Its type is `OrderedSet.Set(a)`, named for what it is within its module as E.0's shape rule 7 asks, and as Erlang's `gb_sets:set()` and OCaml's `t` are named; inside the file it shadows the prelude's `Set`, and `Set.Operations` still names the library's type, since a dotted name's first segment is the local type only where that type has a member of the name (§4.2). Its `map` and `filterMap` need the order of their result, and take the result's record between the set and the callback: `OrderedSet.map(set, operations, f)`, into any representation. `Map` gets a record only when it gets a second representation.

## The files

[`set.ern`](../stdlib/set.ern) gains the record type and `Set`'s record. Its functions and E.4 do not change.

```ernest
export type Operations(s, a) =
    Operations(empty : s,
               size : (s) -> Int,
               isEmpty : (s) -> Bool,
               contains : (s, a) -> Bool,
               put : (s, a) -> s,
               remove : (s, a) -> s,
               fromList : (List(a)) -> s,
               toList : (s) -> List(a),
               union : (s, s) -> s,
               intersection : (s, s) -> s,
               difference : (s, s) -> s,
               isSubset : (s, s) -> Bool)

export let operations : Operations(Set(a), a) =
    Operations(empty = empty,
               size = size,
               isEmpty = isEmpty,
               contains = contains,
               put = put,
               remove = remove,
               fromList = fromList,
               toList = toList,
               union = union,
               intersection = intersection,
               difference = difference,
               isSubset = isSubset)
```

`ordered_set.ern` is the ordered set, a sorted list. Its `operations` fills the record with closures over the order; the module exports what needs no order and keeps the rest private. `intersection`, `difference` and `isSubset` are written as `union` is, a walk of the two sorted lists, and `foreach`, `any`, `all`, `find` and `filterMap` as `filter` and `map` are; they are left out here.

```ernest
export abstract type Set(a) = Set(List(a))

export fn operations(compare : (a, a) -> Ordering) : Set.Operations(Set(a), a) =
    Set.Operations(empty = empty,
                   size = size,
                   isEmpty = isEmpty,
                   contains = fn(set, x) = contains(set, x, compare),
                   put = fn(set, x) = put(set, x, compare),
                   remove = fn(set, x) = remove(set, x, compare),
                   fromList = fn(list) = fromList(list, compare),
                   toList = toList,
                   union = fn(set, other) = union(set, other, compare),
                   intersection = fn(set, other) = intersection(set, other, compare),
                   difference = fn(set, other) = difference(set, other, compare),
                   isSubset = fn(set, other) = isSubset(set, other, compare))

export let empty : Set(a) = Set([])

export fn size(Set(list) : Set(a)) : Int =
    List.size(list)

export fn isEmpty(Set(list) : Set(a)) : Bool =
    List.isEmpty(list)

export fn toList(Set(list) : Set(a)) : List(a) =
    list

export fn min(Set(list) : Set(a)) : Optional(a) =
    List.get(list, 0)

export fn max(Set(list) : Set(a)) : Optional(a) =
    List.last(list)

export fn filter(Set(list) : Set(a), keep : (a) -> Bool with e) : Set(a) with e =
    Set(List.filter(list, keep))

export fn foldLeft(Set(list) : Set(a), acc : b, step : (b, a) -> b with e) : b with e =
    List.foldLeft(list, acc, step)

export fn map(Set(list) : Set(a),
              operations : Set.Operations(s, b),
              f : (a) -> b with e) : s with e =
    List.foldLeft(list, operations.empty, fn(acc, x) = operations.put(acc, f(x)))

fn contains(Set(list) : Set(a), x : a, compare : (a, a) -> Ordering) : Bool =
    match list {
        [] -> false
      | y :: rest -> match compare(x, y) {
            Less -> false
          | Equal -> true
          | Greater -> contains(Set(rest), x, compare)
        }
    }

fn put(Set(list) : Set(a), x : a, compare : (a, a) -> Ordering) : Set(a) =
    Set(inserted(list, x, compare))

fn inserted(list : List(a), x : a, compare : (a, a) -> Ordering) : List(a) =
    match list {
        [] -> [x]
      | y :: rest -> match compare(x, y) {
            Less -> x :: list
          | Equal -> list
          | Greater -> y :: inserted(rest, x, compare)
        }
    }

fn remove(Set(list) : Set(a), x : a, compare : (a, a) -> Ordering) : Set(a) =
    Set(List.filter(list, fn(y) = compare(x, y) != Equal))

fn fromList(list : List(a), compare : (a, a) -> Ordering) : Set(a) =
    List.foldLeft(list, empty, fn(acc, x) = put(acc, x, compare))

fn union(Set(list) : Set(a), Set(other) : Set(a), compare : (a, a) -> Ordering) : Set(a) =
    Set(merged(list, other, compare))

fn merged(list : List(a), other : List(a), compare : (a, a) -> Ordering) : List(a) =
    match #(list, other) {
        #([], _) -> other
      | #(_, []) -> list
      | #(x :: rest, y :: others) -> match compare(x, y) {
            Less -> x :: merged(rest, other, compare)
          | Equal -> x :: merged(rest, others, compare)
          | Greater -> y :: merged(list, others, compare)
        }
    }
```

`usage.ern` is a program that uses it. It binds the record once, writes nothing else of the order, and has one function written once, `common`, which it calls with both representations.

```ernest
let ints = OrderedSet.operations(Int.compare)

fn common(list : List(a), other : List(a), operations : Set.Operations(s, a)) : List(a) =
    operations.toList(operations.intersection(operations.fromList(list),
                                              operations.fromList(other)))

export fn main() : Unit with Never = {
    let small = ints.fromList([3, 1, 3]);
    let both = ints.union(small, ints.fromList([2]));
    Io.println(Io.show(OrderedSet.toList(both)));
    Io.println(Io.show(OrderedSet.min(both)));
    Io.println(Bool.toString(both == ints.fromList([2, 3, 1])));
    Io.println(Io.show(OrderedSet.toList(OrderedSet.filter(both, fn(n) = n % 2 == 1))));
    let doubled = OrderedSet.map(both, Set.operations, fn(n) = n * 2);
    Io.println(Bool.toString(Set.contains(doubled, 6)));
    Io.println(Io.show(common([4, 2, 3], [3, 4, 5], ints)));
    Io.println(Int.toString(List.size(common([4, 2, 3], [3, 4, 5], Set.operations))))
}
```

It prints `[1, 2, 3]`, `Some(1)`, `true`, `[1, 3]`, `true`, `[3, 4]` and `2`: an ordered set is data, two sets built in different orders are equal, `map` carries a set into the hash set, and `common` is written once for both.

`mixed.ern` is a program rule 5 refuses.

```ernest-rejected
type Descending = Descending(Int)

fn Descending.compare(Descending(a) : Descending, Descending(b) : Descending) : Ordering =
    Int.compare(b, a)

let ints = OrderedSet.operations(Int.compare)

let downs = OrderedSet.operations(Descending.compare)

export fn main() : Unit with Never = {
    let up = ints.fromList([1]);
    let down = downs.fromList([Descending(1)]);
    Io.println(Int.toString(OrderedSet.size(ints.union(up, down))))
}
```

```console
$ ern build --short-errors mixed.ern
mixed.ern:13:57: the argument does not fit the callee: expected OrderedSet.Set(Int), found OrderedSet.Set(Descending)
```

That is the refusal where the checker can see the record's type, which it could on 2026-10-02 only in a program that names `Set`; `mixed.ern` does not, and the toolchain of that day refused it for the wrong reason, a defect MVP 2.99b's item 4 fixes (*Typing*, *Evidence*). Its message says "the callee" where requirement 5 asks for `ints.union`, which item 5's build changes.

Types print as `ern doc` writes them: `OrderedSet.operations : ((a!, a!) -> Ordering) -> Set.Operations(OrderedSet.Set(a!), a!)`, the `!` saying that no reply can be an element, since `put` may drop one (§6.6), and `Set.operations : Set.Operations(Set(a=!), a=!)`, the `=` the equality `Set`'s element needs.

## Typing

Every construct above is one the report specifies and the checker of Ernest 0.2.0 implements. The type system is Damas and Milner's with algebraic data types (§3.9; Damas and Milner 1982), and the specification stays inside it.

- **The record.** `Operations(s, a)` is a sum type with one constructor and named fields (§3.5). Every field's type names only `s` and `a`, so §3.9's rule holds that every type variable in a constructor's fields is a parameter of the type, and no field quantifies a variable of its own. The record is rank-1 throughout. That is why it holds twelve of the vocabulary's twenty operations: a field for `foldLeft`, polymorphic in its accumulator, would need a rank-2 type, and the checker refuses it with `type variable b is not a parameter of the type` (language feedback 64); a field for `filter`, whose callback has an effect variable, would fix one effect for every use of the record.
- **Selection.** `ints.put` is §3.5's selector, resolved as an operator's operand type is (§4.8): the operand's type constructor must be known when the enclosing definition is inferred. Every record parameter above is annotated, so it is. An unannotated one is refused with the standing diagnostic, `the type whose field put is read is not determined; annotate it`. That is the report's restriction, not a new one.
- **Code written once.** `common` is a let-polymorphic function over the record, inferred and generalized as any `fn` is, with a principal type, and instantiated at each representation.
- **The records.** `Set.operations` is a top-level `let` of type `Operations(Set(a), a)` for every `a`, generalized by §4.6 since its initializer calls no process-only function. `OrderedSet.operations` is a function that returns a record whose fields are closures over `compare`. Closures and records of functions are ordinary values.
- **The binding.** `let ints = OrderedSet.operations(Int.compare)` has a type with no variable in it, so generalization is trivial, `ints.put` resolves, and §8.5 runs the initializer once, a pure call. In a block the binding is monomorphic (§4.6), and the selection resolves the same way.
- **The restrictions.** The three of §3.9 travel through the record as through any type. When the record is built, unifying its `a` with the variables of the functions that fill it passes their marks to it: `=` by §3.10's rule that binding a variable with the equality restriction restricts the variables in value positions of the type it is bound to, `!` by §4.7's rule for a foreign function's variables. Each is a flag on a type variable, checked at instantiation and printed (§11.5), as Standard ML's equality types are (Milner, Tofte, Harper and MacQueen 1997). So `Set.operations : Set.Operations(Set(a=!), a=!)`, and `Set.operations.fromList([f])` fails the check, `(Int) -> Int does not support equality, and a Set's element needs it`.
- **Requirement 4.** `OrderedSet.Set(Int)` and `OrderedSet.Set(Descending)` do not unify, since two declared types are distinct by name (§8.7). Nothing more is involved.
- **The invariant.** The sorted list is the module's alone, since an abstract type's constructors are visible only in its module (§4.4): representation independence, as Mitchell and Plotkin state it.

**No implicit machinery.** There is no set of predicates, no entailment, no instance resolution, no ambiguity check and no coherence question, because nothing is resolved by type. The specification lives in the language that type classes elaborate into, Hindley-Milner with records of functions, which Wadler and Blott showed and Hall, Hammond, Peyton Jones and Wadler formalized; it needs that target and none of the source-level theory. Decidability and principal types are Damas and Milner's, and §3.9 forbids polymorphic recursion.

**What the types do not guarantee**, stated as invariants rather than left implicit: one order per element type between two records of one type, which the type system keeps apart only where the orders are types; `compare`'s laws, totality and agreement with `==`; and one shape per set, which the representation decides. Each is the promise OCaml's `Set.Make` and Haskell's `Ord` ask of a program.

Two versions of a `compare` can meet one set: at a node whose `T.compare` differs, after an `Upgrade` (§6.10), and across `:reload` and the shell's later inputs (§11.2). A set built under one and read under another is misordered. The program named both where it bound the records; code shipped with a spawn carries the sender's `compare` by its hash (§8.7), and a set sent as a message meets the receiver's, which MVP 3.0 decides where versions meet over the network.

`compare` is assumed to be a total order, and where the element type has `==`, to say `Equal` only where `==` holds, as Haskell's `Ord` laws are stated over `Eq`. Nothing checks either, just as Haskell checks neither. Where the element type has no `==`, because its values hold a function, an ordered set holds one element per class of `compare`'s `Equal`, and `put` keeps the element already there (rule 6). An unlawful `compare` voids the rest. One that is not transitive breaks the order itself, so `contains` answers wrongly and duplicates stay. One that says `Equal` where `==` does not makes `==` on two sets depend on the order of insertion.

**Evidence.** The guide's §7.3 compiles and runs this shape under `make test` today: a record of operations, a `let` record for the hashed set, a function of a compare returning closures, and generic code over the record. The files above were built and run on 2026-10-02 under stand-in names; `usage.ern` prints what this document says, `ern format --check` accepts every file as written, and `Set.operations.fromList([f])` is refused naming `Set`'s element, as requirement 5 asks. The build found a defect of the checker, not of the specification: the checker is given the interfaces of the modules a program names, and none of those whose types they name, so `mixed.ern`, which names `OrderedSet` and not `Set`, selected no field of the record, and a program that receives a type through another module's function compared two of its values that hold functions, which §3.10 refuses. MVP 2.99b's item 4 fixes it, with the sentence §11.1 lacks (the log's *A Type Reached Through Another Module's Interface*). Neither the checker nor the emitter needs any other change.

## What it buys and what it costs

It buys:

- **No new theory and no new checker pass.** Rank-1 records, let-polymorphism, closures and nominal data types, all implemented today. Principal types and decidability are Damas and Milner's as before.
- **Everything visible.** Every record is named at the call and every order at its binding. No code is chosen by an inferred type, so there is no coherence or ambiguity question to specify, to test or to explain in an error.
- **One name for each operation.** `union` is `Set.union` for the hash set and `ints.union` for the ordered set, the shape of OCaml's `IntSet.union`. The library adds no generic functions and no naming rule, and E.0 rule 4 holds.
- **An ordered set that is data**: `==`, a `Map` key, a message across nodes.
- **Orders that are types cannot meet**, and the error is an ordinary type mismatch naming both types, as requirement 5 asks.
- **Two things classes do not allow**: two records at one type, and a record built at run time from a value, as `operations(compare)` is.
- **Nothing added to the language.** No reserved word, no grammar change, nothing in §3 or §4. Type classes could still come later, built on records.

It costs, at call sites:

- **The record travels by hand.** Generic code takes it as a parameter, a function that only passes a set on must take it too, where type classes would pass nothing, and a record parameter needs its type fixed within its definition, usually by an annotation, before a field can be selected (§3.5, §4.8).
- **`ints.put` instead of `OrderedSet.put`.** The ordered set's user binds the record once, where OCaml's applies the functor once, and that binding is the floor §4.8 sets; one binding per element type per program. The operations that need the order then go through the record and not through the module, where both of principle 1's readers write the module's function, `IntSet.add x s` and `gb_sets:add(X, S)`, so the ordered set's section states the departure as a rule.
- **Two places for the vocabulary.** The twelve operations whose types the record can hold are its fields; the eight that take a callback are each module's functions, and the ordered set's `map` and `filterMap` take the result's record.
- **Generic code over a callback goes through `toList`**, at the cost of the list it builds, and generic code cannot name its variable's `compare`, so it sorts with `List.sort` and a function the caller gives it.
- **A conversion between representations is written out**: `ints.fromList(Set.toList(set))`.
- **A list of mixed representations needs a second record type** (rule 7), which loses `==`.

And elsewhere:

- **A third representation fills all twelve fields itself**, with no generic `union` from the library to borrow. Were one to come, a function that completes a record from its six primitives would be where that code is shared.
- **Requirement 4 holds between orders that are types and not between two records of one type.** Two `OrderedSet.Set(Int)` built over `Int.compare` and over a function that reverses it meet in `union` without an error, and their `==` is false on equal elements. A record over a representation that is not abstract, `List(a)`, loses requirement 4 altogether: two records over `List(a)` with different invariants meet in its `union`.
- **No order for tuples, lists, `Optional` or `Either`.** A pair's compare is written by hand each time it is needed, since nothing composes compares.
- **A linear ordered set for now.** `put` and `contains` walk the sorted list; which representation pays what is *The representation*'s question.
- **The pattern does not scale for free.** Each container kind with a second representation needs its own record and its fields filled, which is why `Map` gets a record only with a second representation.

## What changes in Ernest

- §4.2 and §11.1: a file name of words joined by `_` names one namespace, MVP 2.99b's item 4, decided.
- E.0, shape rule 1: an operations record stands directly after the subjects, before a callback, as `OrderedSet.map(set, operations, f)` has it.
- E.4: `Set.Operations(s, a)` and `Set.operations`.
- Appendix E, a section at its end: `ordered_set.ern`, namespace `OrderedSet`, with `abstract type Set(a)`, `operations`, `empty`, `size`, `isEmpty`, `toList`, `min`, `max`, and the vocabulary's functions that take a callback. Its section states the departure principle 1 asks for: an operation that needs the order is a field of the record `operations` builds, since no hidden argument carries it (§4.8), and says which of E.0 rule 2's vocabulary are fields and which functions.
- §11.5: a call of a selected field names it as written, `ints.union`, where its message says "the callee", as requirement 5 asks.
- Nothing in §3 or §4, and no change to the checker's typing or to the emitter. §3.10 stays as it is: tuples, lists, `Optional` and `Either` have no order, since their `compare` would compare elements of a type variable, which §4.8 refuses, and a program sorts pairs with a function it passes to `List.sort`. This reverses the verdict of 2026-09-29, which rested on what other languages do.

## What it costs to build

Nothing in the checker's typing, the emitter or the runtime changes. The files above were built with Ernest 0.2.0's toolchain as it stands, and the guide's §7.3 has compiled the same shape under `make test` since 2026-09-28. The work falls on the library, a diagnostic and the documents, two to three days in all, beside item 4's:

| Area | Work | Item |
|---|---|---|
| Checker, emitter, runtime | none for the specification; the defect the sketch found, item 4's | 4 |
| `ern build`'s path rule (§11.1), `:load`, completion, `ern doc`, the pages | `_` in a file name | 4 |
| `set.ern` | the record type, `operations`, their doc blocks and examples | 5 |
| `ordered_set.ern` | the module, its page, its tests, its section of Appendix E with a test per section | 5 |
| §11.5's message for a selected callee | the field named as written | 5 |
| Report | shape rule 1's clause, E.4, the new section, the departure stated | 5 |
| Guide §7.3 | rewritten over the finished code | 16 |

At run time a field use is one indirect call, the host's own application of a fun, which `make bench` confirms. The run-time cost that matters is the ordered set's own, linear per operation over a sorted list, which *The representation* decides.

The files were built as user modules. Under the standard library's own source root, where `Set` is a taken namespace and `ordered_set.ern` shadows the prelude's `Set` inside itself, a toolchain defect may surface that the user modules did not reach, and `ern doc` has not yet rendered a record type's page. One found is fixed where it is found, as the reached interfaces are.

For scale: the design that went out, the ordering constraint, would have added a restriction to the checker, a mark to compiled interfaces and evidence passing to the emitter, weeks of work; type classes more than that.

## Why not type classes

To hold a set's operations, a class must range over the whole set type, with the element given by an associated type or a functional dependency, since Ernest has no variables over type constructors. A full design would add instances with conditions, superclasses, default methods, inferred constraints, method resolution by argument or expected type, and one instance per type with orphan checks. To keep a single mechanism, it would also recast `==`, `compare` and the operators as classes.

What that buys is no record at call sites and no binding of the order: `size(small)`, `put(small, 4)`, and `fromList([3, 1, 3])` with an annotation choosing the representation, and no annotation on generic code.

What it costs is larger. The code a method runs is chosen by an inferred type, and each constraint is a dictionary nobody wrote, the hidden argument §4.8 refuses; `empty` alone needs an annotation to mean anything. There would be two mechanisms, classes beside records and methods beside module functions. `class`, `instance`, method signatures, associated types and instance conditions would enter the grammar. Resolution, conditions, associated types, superclasses, defaults, coherence, orphans and ambiguity would each add rules to the report, errors for users and work in every part of the toolchain.

Neither design contains the other. Type classes elaborate to records found by type; records allow two records at one type, and records built at run time, as `OrderedSet.operations(compare)` is; classes allow one instance per type, found without being named. What type classes add is declared instances and resolution by type. That saves the record at call sites and the binding of the order, at the price of a second mechanism and a larger type system.

## Related work

Type classes are elaborated to dictionary passing (Wadler and Blott 1989; Hall, Hammond, Peyton Jones and Wadler 1996). The specification writes the dictionaries in the program instead, and hides none. OCaml's `Set.Make(Ord)` takes the order once, as a functor argument, and a second order is a second application with a type of its own; `let ints = OrderedSet.operations(Int.compare)` is `module IntSet = Set.Make(Int)` as a value, `ints.union` is `IntSet.union`, and rule 5's second type is a second application. Rust's `BTreeSet<Reverse<T>>` and Haskell's `Down` are rule 5 at the element. Jane Street's Base keeps sets of different orders apart with a comparator witness in the type, `('a, 'cmp) Set.t`, while carrying the comparator in the value. Not taken: a value that holds a function has no `==` in Ernest, and the witness is a second parameter on every type that holds a set, paid by programs that never mix orders, for a guarantee a wrapper type gives (rule 5). The equality restriction that travels through the record is Standard ML's equality types (Milner, Tofte, Harper and MacQueen 1997).

Between explicit records and type classes lie modular type classes (Dreyer, Harper, Chakravarty and Keller 2007) and OCaml's modular implicits (White, Bour and Yallop 2014). There the dictionaries are ML modules, and the compiler passes one implicitly when it is in scope. That would remove the main cost, the record at call sites. Not taken: an argument found by type is code the reader does not see at the call, which is the rule Ernest states for its operators (§4.8). Scala's implicits show the same idea from the object-oriented side: a type class is an interface whose instance is passed implicitly (Oliveira, Moors and Odersky 2010).

## The representation

Structural `==` needs one shape per set, what the literature calls a unique representation. `Set` has one, since it is the runtime's map, whose `==` compares contents. For `OrderedSet`, a sorted list has one shape, but `put` and `contains` are linear. A balanced tree's shape depends on the order of insertion, and deterministic unique representations built on comparison cost more than logarithmic time in the models studied (Snyder 1977; Sundar and Tarjan 1990; Andersson and Ottmann 1995). A treap with hash-derived priorities has one shape and logarithmic expected time (Seidel and Aragon 1996), but needs a hash of any element, which the standard library lacks; one would be a structural operation of the runtime's, as `==` is, and a decision of its own. The sorted list comes first, as in the files above, because it is simple and correct; a treap enters only when a measurement shows that the linear cost matters, with its hash decided then.

## References

- Andersson and Ottmann 1995. New tight bounds on uniquely represented dictionaries. *SIAM Journal on Computing*.
- Bruce, Cardelli, Castagna, the Hopkins Objects Group, Leavens and Pierce 1995. On binary methods. *Theory and Practice of Object Systems*.
- Chakravarty, Keller and Peyton Jones 2005. Associated type synonyms. *ICFP*.
- Damas and Milner 1982. Principal type-schemes for functional programs. *POPL*.
- Dreyer, Harper, Chakravarty and Keller 2007. Modular type classes. *POPL*.
- Hall, Hammond, Peyton Jones and Wadler 1996. Type classes in Haskell. *ACM TOPLAS*.
- Hughes 1999. Restricted data types in Haskell. *Haskell Workshop*.
- Jones 2000. Type classes with functional dependencies. *ESOP*.
- Milner, Tofte, Harper and MacQueen 1997. *The Definition of Standard ML (Revised)*. MIT Press.
- Mitchell and Plotkin 1988. Abstract types have existential type. *ACM TOPLAS*.
- Oliveira, Moors and Odersky 2010. Type classes as objects and implicits. *OOPSLA*.
- Russo 2000. First-class structures for Standard ML. *Nordic Journal of Computing*.
- Seidel and Aragon 1996. Randomized search trees. *Algorithmica*.
- Snyder 1977. On uniquely represented data structures. *FOCS*.
- Sundar and Tarjan 1990. Unique binary search tree representations and equality-testing of sets and sequences. *STOC*.
- Wadler and Blott 1989. How to make ad-hoc polymorphism less ad hoc. *POPL*.
- White, Bour and Yallop 2014. Modular implicits. *ML Family Workshop*.
