# Operations records

Ernest has one set in its standard library, `Set`, a hash set. I want a second one that keeps its elements in order, and generic code, a `fromList` or a `size`, should work on both. Java would reach for an interface, Haskell for a type class and ML for a functor. Ernest has no type classes, and this note is an attempt to do without them. It proposes *operations records*: records of a type's operations that the caller passes explicitly. In other words, dictionary passing (Wadler and Blott 1989), written by the program instead of by the compiler.

What I would most like from you is where this breaks. Which of the programs type classes express would you miss here? Is the ordering constraint sound as I describe it? And is my leaning on the question at the end right? I am least sure of the judgment against type classes and their implicit relatives, near the end. The § numbers cite Ernest's report, and the code assumes the proposal.

## Why sets

Sets are the known hard case for type classes. Haskell's `Data.Set` cannot be a `Functor`: `fmap` puts no constraint on the result's element, while a set's `map` needs `Ord` on it (Hughes 1999). Without variables over type constructors, a class over whole collection types needs the element type as a function of the collection type, which takes functional dependencies (Jones 2000) or associated type synonyms (Chakravarty, Keller and Peyton Jones 2005). OCaml makes a set a functor over an ordered type, `Set.Make(Ord)`, whose application fixes the order. The proposal's records are closest to ML structures passed as values (Russo 2000), as OCaml's first-class modules are. Abstractions over type constructors, such as `Functor` or `Monad`, stay out of reach, because Ernest has no variables over type constructors.

## Requirements

1. Each type's operations are called through its module: `Set.put(s, x)`, `OrderedSet.put(s, x)`, and the ordered set's own `OrderedSet.min(s)`.
2. Generic code is an ordinary function, and the caller chooses the representation.
3. An ordered set is data: it has `==`, can key a `Map`, and can be sent to another node.
4. Sets in different orders cannot be combined.
5. Errors name what the user wrote: a function, a type, a record.

## The proposal

The syntax does not change. The rules below lift one restriction, add one, and give the standard library a convention; the section *What changes in Ernest* lists the report's sections they touch.

1. In Ernest, `==` on a type variable gives it an *equality constraint*, inferred and printed `a=`, as Standard ML's equality types do (§3.10). `<`, `<=`, `>` and `>=` on a type variable give it an *ordering constraint*, printed `a<`: the predicate `Ord a` of qualified types (Jones 1994). Like the equality constraint, it is inferred from the body and never written (§3.9). At each instantiation the type must be ordered: a variable, which then carries the constraint, or a type whose `compare` is visible there and whose own condition holds (rule 2). Anything else is a type error, and so is an ordered variable left ambiguous.
2. A type's `T.compare` is declared over the type's own parameters, `(T(ā), T(ā)) -> Ordering`, and any other shape is refused at its declaration. It may compare the parameters, and then carries their constraint: `Pair(Int)` is ordered and `Pair(Bool)` is not. `List`, `Optional` and `Either` declare theirs this way in their modules: lists element by element, `[1, 2] < [1, 3]` and `[] < [0]`, with `None` before `Some` and `Left` before `Right`. Tuples have no module, so their order is built in, element by element: `#(1, "b") < #(2, "a")`.
3. No top-level `let` is generalized over an ordered variable. Its initializer may spawn and send, and must run once, before `main` runs (§8.5). A variable left ordered is an error at the binding (§4.6). A value that depends on an order must be a function, which is why `setOperations` is one.
4. A record holds only the type's primitives, the few operations that touch its representation. `Set.Operations(s, e)` holds `Set`'s six: `empty`, `size`, `contains`, `put`, `remove` and `toList`. None of them is polymorphic beyond `s` and `e`.
5. Generic code is a function of the record. It is declared as a member of the record type and takes the record last, as in `Set.Operations.union(a, b, ops)`. `map` and `filterMap` take two records, one for the source and one for the result.
6. A representation exports one function per record it meets, named for that record, and its own functions, each of which calls the generic one with its record: `OrderedSet.setOperations()`, and `OrderedSet.union(a, b)` beside `Set.union(a, b)`. A type may meet several records, as a class implements several interfaces. A record may also hold another as a field, as one interface extends another: `Ordered.Operations(s, e)` holds `set : Set.Operations(s, e)` beside `min` and `max`. Any module can build a record from the operations another module exports.
7. An ordered set uses its element type's `compare`. A different order is a different type, such as `Descending(Int)` with its own `compare`, like Haskell's `Down`.
8. A list that mixes representations needs a second record type, one that hides `s`: its functions close over one set, and its `put` returns another such record (Mitchell and Plotkin 1988). It loses operations on two sets, such as a `union` that reaches both representations (Bruce et al. 1995), and since it holds functions it has no `==`.
9. `OrderedSet` joins the standard library in `ordered_set.ern`, and `Ordered` in `ordered.ern`. A file name of words joined by `_` names one namespace. `Map` gets a record only when it gets a second representation.

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
                         f : (e) -> d with x,
                         from : Operations(s, e),
                         to : Operations(t, d)) : t with x =
    List.foldLeft(from.toList(set), to.empty, fn(acc, y) = to.put(acc, f(y)))

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
// OrderedSet.min(small) is Some(1), and OrderedSet.size(small) is 2.
// small == fromList([1, 3], OrderedSet.setOperations()) is true: an ordered set is data.
```

Types print as `OrderedSet.put : (OrderedSet(a<), a<) -> OrderedSet(a<)` and `Set.put : (Set(a=), a=) -> Set(a=)`.

## Typing and semantics

The ordering constraint is a single built-in type class with one method: Haskell's `Ord`, with each type's instance its `T.compare`. The class is fixed, but its instances are open: every module that declares a type may give it one, and only that module. The constraint is inferred like Standard ML's equality types, as a flag on a type variable. Unlike them, it needs evidence at run time, a `compare`, and three things follow that equality types never meet. An ambiguous ordered variable is an error, where an ambiguous equality constraint is harmless. A top-level value cannot be generalized over it (rule 3). And a variable named in an annotation, which the annotation cannot mark (§3.9), gains the constraint from the body: `inserted`'s `e` does, and takes a hidden parameter.

In rules, as a sketch I have not yet checked against the checker, in the form of qualified types, `P | Γ ⊢ e : τ`, where P holds the ordering predicates (the other restrictions of §3.9 travel beside them):

```text
P | Γ ⊢ e₁ : τ    P | Γ ⊢ e₂ : τ    P ⊩ Ord τ
─────────────────────────────────────────────    and likewise <=, >, >=
P | Γ ⊢ e₁ < e₂ : Bool

entail        P ⊩ Ord a                if Ord a ∈ P
              P ⊩ Ord Int, Ord Float, Ord String, Ord Char
              P ⊩ Ord T(τ₁, …, τₙ)     if T.compare : ∀ā. Q ⇒ (T(ā), T(ā)) -> Ordering
                                        is visible and P ⊩ Q[ā := τ̄]
              P ⊩ Ord #(τ₁, …, τₙ)     if P ⊩ Ord τ₁, …, P ⊩ Ord τₙ

reduce        a predicate Ord T(τ̄) or Ord #(τ̄) is replaced by what entails it, when
              unification binds its variable and again when its definition ends,
              until only predicates on variables remain; one with no instance is refused
generalize    at a definition's end, a predicate on a variable free in Γ is deferred to
              the enclosing definition; one on a generalized variable is quantified,
              ∀ā. Q ⇒ τ; one on a generalized variable not free in τ is ambiguous and
              refused; at a top-level let, no variable under a predicate is generalized
instantiate   ∀ā. Q ⇒ τ at τ̄ adds Q[ā := τ̄] to P
elaborate     ∀ā. Q ⇒ τ takes a hidden compare for each predicate of Q, in the order its
              variable first occurs in τ; e₁ < e₂ is c(e₁, e₂) == Less, where c is the
              evidence for Ord τ: the hidden parameter at a variable, T.compare at T,
              a closure over T.compare and the evidence for Q at a conditional instance,
              and a compare built lexicographically from its elements' at a tuple
```

Inference should stay decidable, with principal types for programs that are not ambiguous: every predicate has one parameter, every instance's condition is on its head's variables, so reduction terminates, and Ernest has no polymorphic recursion (Jones 1994; Odersky, Sulzmann and Wehr 1999). Rule 3, like Haskell's monomorphism restriction (Haskell 2010, §4.5.5), gives up principal types at top-level `let`s. Haskell's restriction is there for sharing; Ernest's is there because an initializer's effects must run once.

Within `T.compare`'s own definition, a `<` at `T(ā)` is the recursive reference, not an instance, so a recursive type's condition is the least one inference finds, with no iteration. A `compare` that recurses at another instance of its type, as a non-regular type such as `Nest(a) = Flat(a) | Deeper(Nest(List(a)))` needs, is polymorphic recursion, which Ernest refuses, so such a type has no `compare`. A function in the same recursive group that uses `<` at `T(Int)` makes `T.compare` monomorphic.

The order belongs to the type, not to the value. A set that carries its comparator, as Java's `TreeSet` does, holds a function, so it has no `==`, cannot key a `Map` and cannot be sent to another node (§3.10, §3.11), which requirement 3 forbids. A comparator witness in the set's type, as in Jane Street's Base (`('a, 'cmp) Set.t`), keeps sets of different orders apart, but the set still holds the function. Fixing the order by the element type makes requirements 3 and 4 possible. They hold when the representation has one shape per set (the open question), `compare` keeps its law, the elements have `==`, the set's type is abstract (§4.4) so that only its module builds its values, and the order is unique, as the next paragraph discusses.

The elaboration is coherent (Jones 1993): with one instance per type and no superclasses, every elaboration of a program means the same. An ordered set's invariant needs more, the global uniqueness of instances (Winant and Devriese 2018): one `compare` per type wherever two of its values meet. A type's `compare` is declared in the type's own module (§4.2), so there are no orphans and no overlap, and uniqueness holds within one version of each module. Two versions of a module can meet, though: at a node whose `T.compare` differs, in code shipped with a spawn (§8.7), after an `Upgrade` (§6.10), and across `:reload` and the shell's later inputs (§11.2). A set built under one `compare` and read under another is misordered. Making `compare` part of its type's identity (§8.7) would close this; I have not settled it.

Records stay ordinary records, and add nothing to inference. A record holding an operation that is polymorphic beyond its parameters, such as a fold with its own accumulator type, would need rank-2 fields, like OCaml's polymorphic record fields. The primitives need none. That is why `foldLeft` is not in the record: it is written once over `toList`, as `Set.Operations.foldLeft(set, acc, f, ops)`, at the cost of the list `toList` builds.

Finally, `compare` is assumed to be a total order. Where the element type has `==`, it is also assumed to say `Equal` only where `==` holds, as Haskell's `Ord` laws are stated over `Eq`. Nothing checks either, just as Haskell checks neither. Where the element type has no `==`, because its values hold a function, an ordered set holds one element per class of `compare`'s `Equal`, and `put` keeps the element already there. An unlawful `compare` voids the rest. One that is not transitive breaks the order itself, so `contains` answers wrongly and duplicates stay. One that says `Equal` where `==` does not makes `==` on two sets depend on the order of insertion.

## What it buys and what it costs

As far as I can tell, the proposal can meet the five requirements, under the conditions above, with one mechanism for generic code, the record, which the standard library uses too. Each call names the record it uses, and no record is resolved by type. The order is, as Ernest's operators are (§4.8), and that there are no orphans is itself a rule: a type's `compare` lives in its module. There is no new syntax, declaration or reserved word. Type classes could still come later, built on the hidden `compare` and on records.

Most of the price is paid at call sites. A function that only passes a set on must take the record too, where type classes would pass nothing. A record parameter needs its type fixed within its definition, usually by an annotation, before a field can be selected (§3.5, §4.8). Each operation has two names, `OrderedSet.union(a, b)` and `Set.Operations.union(a, b, ops)`, and `Set.Operations.map` takes a second record where Haskell's `Set.map` takes an `Ord` constraint. Generic code cannot name its variable's `compare`, so it sorts with `List.sort` and a function built from `<`. And a list of mixed representations needs a second record type (rule 8).

The rest falls elsewhere. A comparison through an ordered variable calls a `compare` passed at run time. A `<` on a variable added to a body adds a hidden parameter, so the function's compiled arity changes and its dependents are compiled again. An ambiguous ordered variable is an error where an ambiguous equality constraint is not, so a program can be accepted over one representation and refused over another: `fromList([], Set.setOperations())` is accepted, and `fromList([], OrderedSet.setOperations())` is refused. A top-level `let` whose value depends on an order is refused at the binding, and the error says to write a function. And a record over a representation that is not abstract, such as `List(e)`, loses requirement 4: two records over `List(e)` with different invariants meet in `Set.Operations.union`.

## What changes in Ernest

- §3.9: the ordering constraint joins the restrictions inferred from a body.
- §3.10: `<`, `<=`, `>` and `>=` on a type variable give it the ordering constraint; tuples are ordered element by element, and `List`, `Optional` and `Either` where their elements are.
- §4.6: no top-level `let` is generalized over an ordered variable.
- §4.8: a comparison whose operand type is still a variable when its definition ends gives the constraint instead of an error, and `T.compare` is declared over `T`'s own parameters.
- §6.3: a guard's comparison stays on `Int`, `Float`, `String` and `Char`.
- §9, §9.6 and Appendix E: `List.compare`, `Optional.compare` and `Either.compare`, `set.ern` over `Set.Operations`, and the modules `Ordered` and `OrderedSet`.
- §4.2 and §11.1: a file name of words joined by `_` names one namespace.
- §11.1 and §11.5: a compiled interface records each function's ordered variables in order, and a type prints `a<`, beside `a=` where a variable has both.
- The checker infers, reduces and checks the constraint; the emitter passes the hidden `compare`.

## Why not type classes

To hold a set's operations, a class must range over the whole set type, with the element given by an associated type or a functional dependency, since Ernest has no variables over type constructors. A full design would add instances with conditions, superclasses, default methods, inferred constraints, method resolution by argument or expected type, and one instance per type with orphan checks. To keep a single mechanism, it would also recast `==`, `compare` and the operators as classes.

What that buys is no record at call sites: `size(small)`, and `fromList([3, 1, 3])` with an annotation choosing the representation, and no annotation on generic code.

What it costs seems to me larger. The code a method runs is chosen by an inferred type, and each constraint is a dictionary nobody wrote; `empty` alone needs an annotation to mean anything. There would be two mechanisms, classes beside records and methods beside module functions. `class`, `instance`, method signatures, associated types and instance conditions would enter the grammar. Resolution, conditions, associated types, superclasses, defaults, coherence, orphans and ambiguity would each add rules to the report, errors for users and work in every part of the toolchain.

Neither design contains the other. Type classes elaborate to records found by type, and the ordering constraint is one class. Records allow two records at one type, and records built at run time; classes allow one instance per type, found without being named. What type classes add is declared instances and resolution by type. That saves the record at call sites, at the price of a second mechanism and a larger type system.

## Related work

Type classes are elaborated to dictionary passing (Wadler and Blott 1989). The proposal writes the dictionaries in the program instead, and keeps one hidden, the `compare` of an ordered variable. The ordering constraint is inferred as Standard ML's equality types are (Milner, Tofte, Harper and MacQueen 1997), which have their critics (Appel 1993); I would like to know whether you count them a mistake. Rust's `BTreeSet<T: Ord>` with `Reverse` is the nearest working analogue of rule 7, and Rust's orphan rule of a `compare` living in its type's module.

Between explicit records and type classes lie modular type classes (Dreyer, Harper, Chakravarty and Keller 2007) and OCaml's modular implicits (White, Bour and Yallop 2014). There the dictionaries are ML modules, and the compiler passes one implicitly when it is in scope. That would remove the proposal's main cost, the record at call sites. I lean against it, because an argument found by type is code the reader does not see at the call, though the hidden `compare` is already such an argument. I have not ruled it out. Scala's implicits show the same idea from the object-oriented side: a type class is an interface whose instance is passed implicitly (Oliveira, Moors and Odersky 2010).

## An open question

A question still open: the ordered set's representation. Structural `==` needs one shape per set, what the literature calls a unique representation. `Set` has one, since it is the runtime's map, whose `==` compares contents. For `OrderedSet`, a sorted list has one shape, but `put` and `contains` are linear. A balanced tree's shape depends on the order of insertion, and deterministic unique representations built on comparison cost more than logarithmic time in the models studied (Snyder 1977; Sundar and Tarjan 1990; Andersson and Ottmann 1995). A treap with hash-derived priorities has one shape and logarithmic expected time (Seidel and Aragon 1996), but needs a hash, which the standard library lacks. My leaning is the sorted list first, as in the sketch, because it is simple and correct, and a treap only if a measurement shows that the linear cost matters. The hash it needs would then be a decision of its own.

## References

- Andersson and Ottmann 1995. New tight bounds on uniquely represented dictionaries. *SIAM Journal on Computing*.
- Appel 1993. A critique of Standard ML. *Journal of Functional Programming*.
- Bruce, Cardelli, Castagna, the Hopkins Objects Group, Leavens and Pierce 1995. On binary methods. *Theory and Practice of Object Systems*.
- Chakravarty, Keller and Peyton Jones 2005. Associated type synonyms. *ICFP*.
- Dreyer, Harper, Chakravarty and Keller 2007. Modular type classes. *POPL*.
- Haskell 2010 Language Report, ed. Marlow, §4.5.5, the monomorphism restriction.
- Hughes 1999. Restricted data types in Haskell. *Haskell Workshop*.
- Jones 1993. Coherence for qualified types. Yale University research report.
- Jones 1994. *Qualified Types: Theory and Practice*. Cambridge University Press.
- Jones 2000. Type classes with functional dependencies. *ESOP*.
- Milner, Tofte, Harper and MacQueen 1997. *The Definition of Standard ML (Revised)*. MIT Press.
- Mitchell and Plotkin 1988. Abstract types have existential type. *ACM TOPLAS*.
- Odersky, Sulzmann and Wehr 1999. Type inference with constrained types. *Theory and Practice of Object Systems*.
- Oliveira, Moors and Odersky 2010. Type classes as objects and implicits. *OOPSLA*.
- Russo 2000. First-class structures for Standard ML. *Nordic Journal of Computing*.
- Seidel and Aragon 1996. Randomized search trees. *Algorithmica*.
- Snyder 1977. On uniquely represented data structures. *FOCS*.
- Sundar and Tarjan 1990. Unique binary search tree representations and equality-testing of sets and sequences. *STOC*.
- Wadler and Blott 1989. How to make ad-hoc polymorphism less ad hoc. *POPL*.
- White, Bour and Yallop 2014. Modular implicits. *ML Family Workshop*.
- Winant and Devriese 2018. Coherent explicit dictionary application for Haskell. *Haskell Symposium*.
