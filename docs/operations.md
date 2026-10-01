# Operations records

*Rewritten on 2026-10-01 under two rules the principles review gave the report that day: no operator carries a hidden argument (§4.8), and a member is an operator, `compare` or `negate` (§4.5). The earlier draft's ordering restriction and its member functions are out (the log's *Members, Operators, and No Hidden Argument*): the order of an ordered set is an argument, and the code written once is a function of `set.ern`. MVP 2.99b's item 4 decides what this note proposes. The sketch below was built and run on 2026-10-01 as user modules under other names, since `Set` is a namespace of the standard library; it is written here with the names it would have there.*

Ernest has one set in its standard library, `Set`, a hash set. I want a second one that keeps its elements in order, and generic code, a `fromList` or a `union`, should work on both. Java would reach for an interface, Haskell for a type class and ML for a functor. Ernest has no type classes, and this note is an attempt to do without them. It proposes *operations records*: records of a type's operations that the caller passes explicitly. In other words, dictionary passing (Wadler and Blott 1989), written by the program instead of by the compiler, with nothing passed that the program did not write.

What I would most like from you is where this breaks. Which of the programs type classes express would you miss here? Does the order as an argument hold what requirement 4 asks, as I state it? And is my leaning right in the judgment against type classes and their implicit relatives, near the end, of which I am least sure? The § numbers cite Ernest's report, and the code assumes the proposal.

## Why sets

Sets are the known hard case for type classes. Haskell's `Data.Set` cannot be a `Functor`: `fmap` puts no constraint on the result's element, while a set's `map` needs `Ord` on it (Hughes 1999). Without variables over type constructors, a class over whole collection types needs the element type as a function of the collection type, which takes functional dependencies (Jones 2000) or associated type synonyms (Chakravarty, Keller and Peyton Jones 2005). OCaml makes a set a functor over an ordered type, `Set.Make(Ord)`, whose application fixes the order. The proposal's records are closest to ML structures passed as values (Russo 2000), as OCaml's first-class modules are. Abstractions over type constructors, such as `Functor` or `Monad`, stay out of reach, because Ernest has no variables over type constructors.

## Requirements

1. Each type's operations are called through its module: `Set.put(set, x)`, `OrderedSet.put(set, x, Int.compare)`, with the order written where the set needs it, and the ordered set's own `OrderedSet.min(set)`.
2. Generic code is an ordinary function, and the caller chooses the representation.
3. An ordered set is data: it has `==`, can key a `Map`, and can be sent to another node.
4. Sets in different orders cannot be combined.
5. Errors name what the user wrote: a function, a type, a record.

The first requirement bends in one place. `OrderedSet.put(set, x)` cannot exist: the order is a function, and Ernest passes none hidden (§4.8), so the program writes it.

## The proposal

Nothing in the type system changes, and the syntax does not. The rules below give the standard library a convention and two files; the section *What changes in Ernest* lists the report's sections they touch.

1. **An order is a function the program names.** `<` resolves against a type the compiler knows and takes no hidden argument (§4.8), so no function receives a `compare` it did not ask for. An ordered set takes its order as an argument of type `(a, a) -> Ordering`: `Int.compare`, or the `compare` of a type the program declares (§3.10). It is written where it is needed: once, in the function that builds the set's record, and at each of the module's own functions that needs it.
2. **A record holds a type's primitives.** `Set.Operations(s, a)` holds `Set`'s six (E.4): `empty`, `size`, `contains`, `put`, `remove` and `toList`. None is polymorphic beyond `s` and `a`, so the record is an ordinary type (§3.5), and selecting a field is ordinary selection, resolved against the parameter's annotation (§4.8). A restriction a primitive carries travels with the record: binding the record's `a` to the primitives' passes the equality restriction (§3.10), so `Set.operations` has the type `Set.Operations(Set(a=!), a=!)`, and `Set.fromListWith([f], Set.operations)` with a function `f` is refused at that call, naming `Set`'s element.
3. **Code written once is a function of the record's module**, named with `With`, as `Map.mergeWith` (E.3) names an operation given its function: `Set.unionWith(set, other, operations)`, `Set.fromListWith(list, operations)`, `Set.mapWith(set, from, to, f)`. A module exports a name once (§4.2) and `set.ern` keeps `union` for its own representation, so the generic function cannot share the name; and it cannot be a member of the record type, `fn Operations.union`, since a member is an operator, `compare` or `negate` (§4.5). The record follows the subjects, a result's record follows it, and an accumulator and a callback come after them, as E.0's shape rule 1 places them: `Set.foldLeftWith(set, operations, acc, step)`. Each of E.4's fourteen functions beyond the primitives has its `With` form, and `Set`'s own is a call of it: `Set.union(set, other)` is `unionWith(set, other, operations)`. E.0's rule 4 admits the pair, since the vocabulary is admitted whole.
4. **A representation exports its record as `operations`**: a `let` where it needs nothing, `Set.operations`, and a function of what it needs, `OrderedSet.operations(compare)`. Its own functions call the generic ones with it, or, where its structure gives a cheaper one, write it: `OrderedSet.union` merges two sorted lists where `unionWith` would insert the second's elements one by one. A type may meet several records, as a class implements several interfaces, and a record may hold another as a field, as one interface extends another: a second ordered representation would bring `OrderedSet.Operations(s, a)`, holding `set : Set.Operations(s, a)` beside `min` and `max`. Any module can build a record from the operations another module exports.
5. **An order belongs to an element type.** The program passes one order for each element type it keeps ordered sets of: the type's `compare`, or the function it would have declared as `compare` had the type a module of its own, as a tuple has none. A second order on one type is a second type with its own `compare`, `type Descending = Descending(Int)` with `fn Descending.compare`, as Haskell's `Down` and OCaml's second functor application are. So two sets in different orders have different types, and they cannot meet: `OrderedSet.union(up, down, Int.compare)` with `down : OrderedSet.Set(Descending)` is refused, `expected OrderedSet.Set(Int), found OrderedSet.Set(Descending)`. Between two functions of one type the rule is the program's promise, which nothing checks, as `compare`'s laws are not checked.
6. **`put` keeps the element already there** where `compare` says `Equal`, so that no choice is left unstated.
7. **A list that mixes representations needs a second record type**, one that hides `s`: its functions close over one set, and its `put` returns another such record (Mitchell and Plotkin 1988). It loses operations on two sets, such as a `union` that reaches both representations (Bruce et al. 1995), and since it holds functions it has no `==`.
8. **`OrderedSet` joins the standard library in `ordered_set.ern`**, a file whose words joined by `_` name one namespace, which §4.2 and §11.1 gain in MVP 2.99b's item 10. Its type is `OrderedSet.Set(a)`, named for what it is within its module as E.0's shape rule 7 asks, and as Erlang's `gb_sets:set()` and OCaml's `t` are named; inside the file it shadows the prelude's `Set`, and `Set.Operations` still names the library's type, since a dotted name's first segment is the local type only where that type has a member of the name (§4.2). `Map` gets a record only when it gets a second representation.

The sketch is three files.

[`set.ern`](../stdlib/set.ern) shows only what the proposal adds to `Set`: the record type, `Set`'s record, three of the fourteen generic functions, and `Set.union`, now a call of one.

```ernest
export type Operations(s, a) =
    Operations(empty : s,
               size : (s) -> Int,
               contains : (s, a) -> Bool,
               put : (s, a) -> s,
               remove : (s, a) -> s,
               toList : (s) -> List(a))

export let operations : Operations(Set(a), a) =
    Operations(empty = empty,
               size = size,
               contains = contains,
               put = put,
               remove = remove,
               toList = toList)

export fn unionWith(set : s, other : s, operations : Operations(s, a)) : s =
    List.foldLeft(operations.toList(other), set, operations.put)

export fn fromListWith(list : List(a), operations : Operations(s, a)) : s =
    List.foldLeft(list, operations.empty, operations.put)

export fn mapWith(set : s,
                  from : Operations(s, a),
                  to : Operations(t, b),
                  f : (a) -> b with e) : t with e =
    List.foldLeft(from.toList(set), to.empty, fn(acc, x) = to.put(acc, f(x)))

export fn union(set : Set(a), other : Set(a)) : Set(a) =
    unionWith(set, other, operations)
```

`ordered_set.ern` is the ordered set, a sorted list. It meets `Set`'s record with `operations`, and the rest is its own: the six primitives over the list, each that needs the order taking it last, `union` as a merge, and `min` and `max`.

```ernest
export abstract type Set(a) = Set(List(a))

export fn operations(compare : (a, a) -> Ordering) : Set.Operations(Set(a), a) =
    Set.Operations(empty = empty,
                   size = size,
                   contains = fn(set, x) = contains(set, x, compare),
                   put = fn(set, x) = put(set, x, compare),
                   remove = fn(set, x) = remove(set, x, compare),
                   toList = toList)

export let empty : Set(a) = Set([])

export fn size(Set(list) : Set(a)) : Int =
    List.size(list)

export fn contains(Set(list) : Set(a), x : a, compare : (a, a) -> Ordering) : Bool =
    match list {
        [] -> false
      | y :: rest -> match compare(x, y) {
            Less -> false
          | Equal -> true
          | Greater -> contains(Set(rest), x, compare)
        }
    }

export fn put(Set(list) : Set(a), x : a, compare : (a, a) -> Ordering) : Set(a) =
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

export fn remove(Set(list) : Set(a), x : a, compare : (a, a) -> Ordering) : Set(a) =
    Set(List.filter(list, fn(y) = compare(x, y) != Equal))

export fn toList(Set(list) : Set(a)) : List(a) =
    list

export fn union(Set(list) : Set(a), Set(other) : Set(a), compare : (a, a) -> Ordering) : Set(a) =
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

export fn min(Set(list) : Set(a)) : Optional(a) =
    List.get(list, 0)

export fn max(Set(list) : Set(a)) : Optional(a) =
    List.last(list)
```

`usage.ern` is a program that uses it.

```ernest
export fn main() : Unit with Never = {
    let small = Set.fromListWith([3, 1, 3], OrderedSet.operations(Int.compare));
    Io.println(Io.show(OrderedSet.min(small)));
    Io.println(Int.toString(OrderedSet.size(small)));
    let again = Set.fromListWith([1, 3], OrderedSet.operations(Int.compare));
    Io.println(Bool.toString(small == again));
    let doubled =
        Set.mapWith(small, OrderedSet.operations(Int.compare), Set.operations, fn(n) = n * 2);
    Io.println(Int.toString(Set.size(doubled)))
}
```

It prints `Some(1)`, `2`, `true` and `2`: an ordered set is data, two sets built in different orders are equal, and `mapWith` carries a set from one representation to the other.

`mixed.ern` is a program the proposal refuses, by rule 5.

```ernest-rejected
type Descending = Descending(Int)

fn Descending.compare(Descending(a) : Descending, Descending(b) : Descending) : Ordering =
    Int.compare(b, a)

export fn main() : Unit with Never = {
    let up = OrderedSet.put(OrderedSet.empty, 1, Int.compare);
    let down = OrderedSet.put(OrderedSet.empty, Descending(1), Descending.compare);
    Io.println(Int.toString(OrderedSet.size(OrderedSet.union(up, down, Int.compare))))
}
```

```console
$ ern build --short-errors mixed.ern
mixed.ern:9:60: the argument does not fit OrderedSet.union: expected OrderedSet.Set(Int), found OrderedSet.Set(Descending)
```

Types print as `ern doc` writes them: `OrderedSet.put : (OrderedSet.Set(a!), a!, (a!, a!) -> Ordering) -> OrderedSet.Set(a!)`, the `!` saying that no reply can be an element, since `put` may drop one (§6.6), and `Set.operations : Set.Operations(Set(a=!), a=!)`, the `=` the equality `Set`'s element needs.

## Typing and semantics

Nothing is added to inference. A record is a sum type with named fields (§3.5), its field a selection resolved against the annotated parameter (§4.8), and the three restrictions of §3.9 travel through it as through any type: the primitives' marks reach the record's parameters when the record is built, and from there every caller of a generic function. A generic function is checked once, over the record, and instantiated at each representation as any polymorphic function is.

The order is an argument because the alternative is a hidden one. An operator the language resolves against its operand's type is a type error on a type variable and carries no hidden argument (§4.8), so `fn less(a, b) = a < b` is refused, and so would be a `put` that compared elements of type `a` with nothing but `a`. The earlier draft made `<` the one exception, inferring an ordering restriction on `a` and passing its `compare` unseen; the principles review refused the exception, since one rule covers every such operator and the hidden `compare` was the dictionary nobody wrote. What the program writes instead is `Int.compare` at `OrderedSet.put(set, x, Int.compare)`, and once at `OrderedSet.operations(Int.compare)` for everything that goes through the record.

Requirements 3 and 4 rest on four conditions. The set holds its elements and nothing else, so it has `==`, keys a `Map` and crosses nodes (§3.10, §3.11); a set that carried its comparator, as Java's `TreeSet` does, would hold a function and have none of the three. The representation has one shape per set, the open question at the end, so that structural `==` means set equality. The type is abstract (§4.4), so only its module builds a value and the invariant holds. And one order per element type, rule 5, which the type system keeps between types and the program keeps between functions of one type.

Two versions of a `compare` can still meet one set: at a node whose `T.compare` differs, after an `Upgrade` (§6.10), and across `:reload` and the shell's later inputs (§11.2). A set built under one and read under another is misordered. With the order an argument the program named both, where the earlier draft's hidden `compare` named neither; code shipped with a spawn carries the sender's `compare` by its hash (§8.7), and a set sent as a message meets the receiver's, which MVP 3.0 decides where versions meet over the network.

A record holding an operation that is polymorphic beyond its parameters, a fold with its own accumulator type, would need rank-2 fields, as OCaml's polymorphic record fields are. The primitives need none, which is why `foldLeft` is not in the record: `Set.foldLeftWith(set, operations, acc, step)` is written once over `toList`, at the cost of the list `toList` builds.

Finally, `compare` is assumed to be a total order, and where the element type has `==`, to say `Equal` only where `==` holds, as Haskell's `Ord` laws are stated over `Eq`. Nothing checks either, just as Haskell checks neither. Where the element type has no `==`, because its values hold a function, an ordered set holds one element per class of `compare`'s `Equal`, and `put` keeps the element already there (rule 6). An unlawful `compare` voids the rest. One that is not transitive breaks the order itself, so `contains` answers wrongly and duplicates stay. One that says `Equal` where `==` does not makes `==` on two sets depend on the order of insertion.

## What it buys and what it costs

As far as I can tell, the proposal meets the five requirements under the conditions above, requirement 1 with the order written, with one mechanism for generic code, the record, which the standard library uses too. Each call names the record it uses, and no record is resolved by type; each order is written where it acts, and no argument is passed that the program did not write (§4.8). There is no new syntax, declaration or reserved word, and the checker and the emitter do not change. Type classes could still come later, built on records.

Most of the price is paid at call sites. A function that only passes a set on must take the record too, where type classes would pass nothing. A record parameter needs its type fixed within its definition, usually by an annotation, before a field can be selected (§3.5, §4.8). The ordered set's own functions take the order at every call, `OrderedSet.put(set, x, Int.compare)`, where OCaml's functor takes it once; the record takes it once, `OrderedSet.operations(Int.compare)`, for the code that goes through the record. Each derived operation has two names, `Set.union(set, other)` and `Set.unionWith(set, other, operations)`, and `Set.mapWith` takes a second record where Haskell's `Set.map` takes an `Ord` constraint. Generic code cannot name its variable's `compare`, so it sorts with `List.sort` and a function the caller gives it. And a list of mixed representations needs a second record type (rule 7).

The rest falls elsewhere. An operation a representation does better than the generic function, a merge for two sorted lists, is written twice, once over the record and once for it. Requirement 4 holds between orders that are types and not between two functions of one type: two `OrderedSet.Set(Int)` built under `Int.compare` and under a function that reverses it meet in `union` without an error, and their `==` is false on equal elements. And a record over a representation that is not abstract, `List(a)`, loses requirement 4 altogether: two records over `List(a)` with different invariants meet in `Set.unionWith`.

## What changes in Ernest

- §4.2 and §11.1: a file name of words joined by `_` names one namespace, MVP 2.99b's item 10, decided.
- E.0, shape rule 1: an operations record stands directly after the subjects.
- E.4: `Set.Operations(s, a)`, `Set.operations`, the fourteen functions named with `With`, and the sentence that each of `Set`'s own beyond the primitives is a call of one.
- Appendix E, a section at its end: `ordered_set.ern`, namespace `OrderedSet`, with `abstract type Set(a)`, `operations`, the primitives, `union`, `min` and `max`, each that needs the order taking it last, and the rest of the vocabulary E.0's rule 2 asks of a set, each a call of `Set`'s `With` form or written for the list where it needs no order, as `filter` does.
- Nothing in §3, §4 or §11, and no change to the checker or the emitter. §3.10 stays as it is: tuples, lists, `Optional` and `Either` have no order, since their `compare` would compare elements of a type variable, which §4.8 refuses, and a program sorts pairs with a function it passes to `List.sort`. This reverses the verdict of 2026-09-29, which rested on what other languages do.

## Why not type classes

To hold a set's operations, a class must range over the whole set type, with the element given by an associated type or a functional dependency, since Ernest has no variables over type constructors. A full design would add instances with conditions, superclasses, default methods, inferred constraints, method resolution by argument or expected type, and one instance per type with orphan checks. To keep a single mechanism, it would also recast `==`, `compare` and the operators as classes.

What that buys is no record at call sites and no order at the ordered set's own calls: `size(small)`, `put(small, 4)`, and `fromList([3, 1, 3])` with an annotation choosing the representation, and no annotation on generic code.

What it costs seems to me larger. The code a method runs is chosen by an inferred type, and each constraint is a dictionary nobody wrote, the hidden argument §4.8 refuses; `empty` alone needs an annotation to mean anything. There would be two mechanisms, classes beside records and methods beside module functions. `class`, `instance`, method signatures, associated types and instance conditions would enter the grammar. Resolution, conditions, associated types, superclasses, defaults, coherence, orphans and ambiguity would each add rules to the report, errors for users and work in every part of the toolchain.

Neither design contains the other. Type classes elaborate to records found by type; records allow two records at one type, and records built at run time, as `OrderedSet.operations(compare)` is; classes allow one instance per type, found without being named. What type classes add is declared instances and resolution by type. That saves the record and the order at call sites, at the price of a second mechanism and a larger type system.

## Related work

Type classes are elaborated to dictionary passing (Wadler and Blott 1989). The proposal writes the dictionaries in the program instead, and hides none. OCaml's `Set.Make(Ord)` takes the order once, as a functor argument, and a second order is a second application with a type of its own; `OrderedSet.operations(Int.compare)` is that application as a value, and rule 5's second type is its second application. Rust's `BTreeSet<Reverse<T>>` and Haskell's `Down` are rule 5 at the element. Jane Street's Base keeps sets of different orders apart with a comparator witness in the type, `('a, 'cmp) Set.t`, while passing the comparator as a value; I did not take it, since the witness is a second parameter on every type that holds a set, paid by programs that never mix orders, for a guarantee a wrapper type gives (rule 5). The equality restriction that travels through the record is Standard ML's equality types (Milner, Tofte, Harper and MacQueen 1997).

Between explicit records and type classes lie modular type classes (Dreyer, Harper, Chakravarty and Keller 2007) and OCaml's modular implicits (White, Bour and Yallop 2014). There the dictionaries are ML modules, and the compiler passes one implicitly when it is in scope. That would remove the proposal's main cost, the record and the order at call sites. I lean against it, because an argument found by type is code the reader does not see at the call, which is the rule Ernest now states for its operators (§4.8). Scala's implicits show the same idea from the object-oriented side: a type class is an interface whose instance is passed implicitly (Oliveira, Moors and Odersky 2010).

## An open question

A question still open: the ordered set's representation. Structural `==` needs one shape per set, what the literature calls a unique representation. `Set` has one, since it is the runtime's map, whose `==` compares contents. For `OrderedSet`, a sorted list has one shape, but `put` and `contains` are linear. A balanced tree's shape depends on the order of insertion, and deterministic unique representations built on comparison cost more than logarithmic time in the models studied (Snyder 1977; Sundar and Tarjan 1990; Andersson and Ottmann 1995). A treap with hash-derived priorities has one shape and logarithmic expected time (Seidel and Aragon 1996), but needs a hash of any element, which the standard library lacks; one would be a structural operation of the runtime's, as `==` is, and a decision of its own. My leaning is the sorted list first, as in the sketch, because it is simple and correct, and a treap only if a measurement shows that the linear cost matters.

## References

- Andersson and Ottmann 1995. New tight bounds on uniquely represented dictionaries. *SIAM Journal on Computing*.
- Bruce, Cardelli, Castagna, the Hopkins Objects Group, Leavens and Pierce 1995. On binary methods. *Theory and Practice of Object Systems*.
- Chakravarty, Keller and Peyton Jones 2005. Associated type synonyms. *ICFP*.
- Dreyer, Harper, Chakravarty and Keller 2007. Modular type classes. *POPL*.
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
