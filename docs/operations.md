# Operations records

*The specification of code written once over several representations of one type. MVP 2.99b's item 5 builds it. The log's *Operations Records*, *Members, Operators, and No Hidden Argument*, *The Operations Note Rewritten*, *The Order Bound Once* and *MVP 2.99b's Questions, One by One* argue its earlier choices; the entry for the member requirement, the fill and the set as data is item 5's to write. Revised 2026-10-02. The four files are whole under [`docs/operations/`](operations/), with their doc blocks, until item 5 moves the ordered set into the standard library. All use the requirement or the fill, forms the toolchain does not have, so none builds, and what they print and refuse is stated as expected; an earlier form of the ordered set, carrying its order, was built, run, formatted and rendered by `ern doc` on 2026-10-02 under stand-in names, with every doc example checked. The code here is excerpted from the files.*

Ernest has one set in its standard library, `Set`, a hash set. A second, `OrderedSet`, keeps its elements in the order of their type's `compare`. Code written once works on both through an *operations record*, a record the program declares of the operations it needs, filled from each representation's namespace. The § numbers cite Ernest's report.

## Requirements

1. Each type's operations are called through its module: `Set.put(s, x)`, `OrderedSet.put(s, x)`, and the ordered set's own `OrderedSet.min(s)`.
2. Generic code is an ordinary function over a record, and the caller chooses the representation.
3. An ordered set is data: it has `==`, can key a `Map`, and can be sent to another node.
4. Sets in different orders cannot be combined.
5. Errors name what the user wrote: a function, a type, a record.
6. A program changes a set's representation by renaming it; no call site changes otherwise.

## The specification

Two forms enter the language, a parameter that names a member of a type and a record filled from a namespace; *What changes in Ernest* lists the report's sections they touch. The rules:

1. **A function that needs a member of a type says so.** A parameter written `compare = a.compare` names the member `compare` of the type `a` is (§4.8, §3.10), and has that member's type at `a`; `add = a.+` names an operator. It is a requirement, not a default: the member is the only value the parameter takes. At a call where `a` is known when the enclosing definition is inferred (§4.8), the compiler passes that type's member and the argument is not written: `OrderedSet.fromList([3, 1, 3])` passes `Int.compare`. Where `a` is a type variable the argument is written, and it is a parameter of the enclosing function that names the same member: `fn unique(list : List(a), compare = a.compare) : List(a) = OrderedSet.toList(OrderedSet.fromList(list, compare))`. Such a parameter stands last among a function's parameters, and may be passed on to any parameter of its type, `List.sort(list, compare)`. A function with such a parameter used as a value is the function with the member passed, at a known type. Three things are errors, each naming the parameter: the argument written where the type is known, `fromList's compare is Int.compare where the element is Int; a set in another order is a set of another type`; the argument missing where the type is a variable, `fromList needs a's compare, which is not determined here; declare compare = a.compare`; and an argument that is not such a parameter, `fromList's compare takes a parameter declared compare = a.compare, not reversed`.
2. **A requirement names a member of §4.8 and nothing else.** The members are `compare`, `negate` and the operators, each of one shape (§4.8). `zero = a.zero`, `hash = a.hash` and `show = a.show` are errors at the declaration: `zero is not a member: a requirement names compare, negate or an operator (§4.8)`. A type has one member of each name, its own, so a requirement has one value at a type, and a second order, sum or product for a type exists only through a second type (rule 4). A requirement is never inferred: a scheme carries one only as a parameter the function declares (§3.9), and a call that needs one the enclosing function did not declare is rule 1's second error. What a record needs beyond the members, a `zero`, a `hash`, a `show`, is a field the program fills (rule 7).
3. **An ordered set is data.** `OrderedSet.Set(a)` holds its elements and nothing else; its order is its element type's `compare`. `==` is structural (§3.10), a set keys a `Map`, and a set is sent as any value is. `fromList`, `contains`, `put`, `remove`, `union`, `intersection`, `difference` and `isSubset` name `a.compare`; `map` and `filterMap` name their result's, `b.compare`; `empty`, `size`, `isEmpty`, `toList`, `min`, `max`, `filter`, `foldLeft`, `foreach`, `any`, `all` and `find` name none.
4. **An order belongs to an element type.** A type's order is its `compare`, and no set of that type is in another. A second order on one type is a second type with its own `compare`: `type Descending = Descending(Int)` with `fn Descending.compare`. Two sets in different orders have different types and cannot meet: `OrderedSet.union(up, down)` with `down : OrderedSet.Set(Descending)` is refused.
5. **`put` keeps the element already there** where `compare` says `Equal`.
6. **The record is the program's.** Code written once over several representations takes a record the program declares, holding the operations it uses, each field of a type that names only the record's parameters (§3.9): `type Ops(s, a) = Ops(fromList : (List(a)) -> s, intersection : (s, s) -> s, toList : (s) -> List(a))`. The program fills it from each representation's namespace at an element type (rule 7), one binding per representation and element type, `let ordered : Ops(OrderedSet.Set(Int), Int) = Ops(..OrderedSet)`, and passes it, `common(list, other, ops)`. Selecting a field is ordinary selection, resolved against the parameter's annotated type (§3.5, §4.8). The library declares no record and no generic function over one (E.0 rule 4). An operation whose callback has an effect variable, or whose accumulator has a type of its own, `filter` and `foldLeft` among them, is no field; generic code that needs one goes through `toList` and `List`.
7. **A record is filled from a namespace.** In a record construction, `..` may name a namespace in place of an expression: `Ops(..Set)` fills each field not given beside it from the declaration of its name that the use site may name (§4.2), at the field's type. A declaration with a parameter of rule 1 is filled with the member of the field's type, which the record's type must fix. `Ops(..OrderedSet, toList = mine)` takes the field given and fills the rest. The name after `..` is an expression where a binding or a constructor of that name is in scope, and a namespace otherwise. A field with no declaration of its name in the namespace, or one whose type does not fit the field's, is an error naming the field and the namespace: `Ops(..Set) lacks isSubset: Set has no isSubset`.
8. **`OrderedSet` is `ordered_set.ern`** in the standard library, a file whose words joined by `_` name one namespace (§4.2, §11.1). Its type is `OrderedSet.Set(a)` (E.0 shape rule 7), which inside the file shadows the prelude's `Set` (§4.2). A set carried into another representation goes through that representation's `fromList` of its `toList`. `Set` does not change.
9. **The representation is a sorted list**, one shape per set, so that `==` is structural. `put`, `contains` and `remove` are linear in the set's size; `union`, `intersection`, `difference` and `isSubset` are linear in the two sizes. A representation of another shape needs one shape per set as well.
10. **A list that mixes representations needs a second record type**, one that hides `s`: its functions close over one set, and its `put` returns another such record. It has no operation on two sets and no `==`.

## The files

[`ordered_set.ern`](operations/ordered_set.ern) is the ordered set. Shown are its type, `empty`, `fromList`, `contains`, `put`, `map`, `filter` and `union`; the rest of the vocabulary is written as these are, and the file holds it whole.

```ernest
export abstract type Set(a) = Set(List(a))

export let empty : Set(a) = Set([])

export fn fromList(list : List(a), compare = a.compare) : Set(a) =
    List.foldLeft(list, empty, fn(acc, x) = put(acc, x, compare))

export fn contains(Set(list) : Set(a), x : a, compare = a.compare) : Bool =
    has(list, x, compare)

fn has(list : List(a), x : a, compare : (a, a) -> Ordering) : Bool =
    match list {
        [] -> false
      | y :: rest -> match compare(x, y) {
            Less -> false
          | Equal -> true
          | Greater -> has(rest, x, compare)
        }
    }

export fn put(Set(list) : Set(a), x : a, compare = a.compare) : Set(a) =
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

export fn map(Set(list) : Set(a), f : (a) -> b with e, compare = b.compare) : Set(b) with e =
    fromList(List.map(list, f), compare)

export fn filter(Set(list) : Set(a), keep : (a) -> Bool with e) : Set(a) with e =
    Set(List.filter(list, keep))

export fn union(Set(list) : Set(a), Set(other) : Set(a), compare = a.compare) : Set(a) =
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

[`usage.ern`](operations/usage.ern) is a program over both sets. No line names an order, and `Ops` is the record `common` needs, declared there and filled from each representation at `Int`.

```ernest
type Ops(s, a) =
    Ops(fromList : (List(a)) -> s,
        intersection : (s, s) -> s,
        toList : (s) -> List(a))

let hashed : Ops(Set(Int), Int) = Ops(..Set)

let ordered : Ops(OrderedSet.Set(Int), Int) = Ops(..OrderedSet)

fn common(list : List(a), other : List(a), ops : Ops(s, a)) : List(a) =
    ops.toList(ops.intersection(ops.fromList(list), ops.fromList(other)))

export fn main() : Unit with Never = {
    let small = OrderedSet.fromList([3, 1, 3]);
    let both = OrderedSet.union(small, OrderedSet.fromList([2]));
    Io.println(Io.show(OrderedSet.toList(both)));
    Io.println(Io.show(OrderedSet.min(both)));
    Io.println(Bool.toString(both == OrderedSet.fromList([2, 3, 1])));
    Io.println(Io.show(OrderedSet.toList(OrderedSet.filter(both, fn(n) = n % 2 == 1))));
    let doubled = OrderedSet.map(both, fn(n) = n * 2);
    Io.println(Bool.toString(OrderedSet.contains(doubled, 6)));
    Io.println(Io.show(common([4, 2, 3], [3, 4, 5], ordered)));
    Io.println(Int.toString(List.size(common([4, 2, 3], [3, 4, 5], hashed))))
}
```

It prints `[1, 2, 3]`, `Some(1)`, `true`, `[1, 3]`, `true`, `[3, 4]` and `2`: two sets built in different orders are `==`, `map` makes a set of the results' type, and `common` is written once for both representations.

`mixed.ern` is a program rule 4 refuses.

```ernest-rejected
type Descending = Descending(Int)

fn Descending.compare(Descending(a) : Descending, Descending(b) : Descending) : Ordering =
    Int.compare(b, a)

export fn main() : Unit with Never = {
    let up = OrderedSet.fromList([1]);
    let down = OrderedSet.fromList([Descending(1)]);
    Io.println(Int.toString(OrderedSet.size(OrderedSet.union(up, down))))
}
```

`ern build` refuses it at `down`: `the argument does not fit the callee: expected OrderedSet.Set(Int), found OrderedSet.Set(Descending)`.

Two programs beyond sets test the two forms where no set is involved. [`numeric.ern`](operations/numeric.ern) writes generic numeric functions over the requirement `add = a.+`, at `Int`, at `Float`, and at a type with a `+` of its own; `sum` needs a zero as well, which is no member, so its caller passes one.

```ernest
type Money = Money(Int)

fn Money.+(Money(a) : Money, Money(b) : Money) : Money =
    Money(a + b)

fn total(list : List(a), add = a.+) : Optional(a) =
    match list {
        [] -> None
      | first :: rest -> Some(List.foldLeft(rest, first, add))
    }

fn sum(list : List(a), zero : a, add = a.+) : a =
    List.foldLeft(list, zero, add)

fn doubled(list : List(a), add = a.+) : List(a) =
    List.map(list, fn(x) = add(x, x))
```

Its `main` prints `Some(6)`, `Some(4.0)`, `Some(Money(3))`, `6`, `[Money(4)]` and `Some(6)`. Declaring the zero as a requirement is rule 2's error:

```ernest-rejected
fn sum(list : List(a), zero = a.zero, add = a.+) : a =
    List.foldLeft(list, zero, add)
```

```console
$ ern build --short-errors numeric.ern
numeric.ern:16:24: zero is not a member: a requirement names compare, negate or an operator (§4.8)
```

[`num.ern`](operations/num.ern) writes the same functions over a record the program fills by hand, `Num`, since `zero` and `one` are no members and `+` is no field name, so no fill applies; each type is one line, and generic code passes the record.

```ernest
type Num(a) =
    Num(zero : a,
        one : a,
        add : (a, a) -> a,
        mul : (a, a) -> a)

let ints : Num(Int) = Num(zero = 0, one = 1, add = Int.+, mul = Int.*)

fn sum(list : List(a), num : Num(a)) : a =
    List.foldLeft(list, num.zero, num.add)

fn sumOfSquares(list : List(a), num : Num(a)) : a =
    sum(List.map(list, fn(x) = num.mul(x, x)), num)
```

Its `main` prints `6`, `3.0` and `14`.

[`set.ern`](../stdlib/set.ern) does not change. `ern doc` writes a parameter of rule 1 as declared: `OrderedSet.fromList : (List(a), compare = a.compare) -> OrderedSet.Set(a)`.

## Typing

Every construct above but the two forms is one the report specifies and the checker of Ernest 0.2.0 implements. The type system is §3.9's, and the specification stays inside it.

- **The requirement.** A parameter `compare = a.compare` has the member's type at `a`, `(a, a) -> Ordering`, in the function's scheme (§3.9), and the body uses it as any parameter. At a call with one argument fewer than the parameters, the last a requirement, the checker reads the type `a` is instantiated to once the enclosing definition is inferred, as it reads an operator's operand type (§4.8), and inserts that type's member as the argument; a type variable there is rule 1's error. An argument written for it is checked to be a parameter of the enclosing function naming the same member. Nothing propagates: no constraint is inferred, and a scheme carries nothing but its parameters' types.
- **The record.** `Ops(s, a)` is a sum type with one constructor and named fields (§3.5), rank-1: every field's type names only `s` and `a`. A field for `foldLeft` is refused with `type variable b is not a parameter of the type`.
- **Selection.** `ops.toList` in `common` is §3.5's selector, resolved as an operator's operand type is (§4.8): the operand's type constructor must be known when the enclosing definition is inferred, so the record parameter is annotated. Unannotated, it is refused with `the type whose field toList is read is not determined; annotate it`.
- **Code written once.** `common` is a let-polymorphic function over the record, with a principal type, instantiated at each representation.
- **The fill.** `Ops(..OrderedSet)` is checked as the literal it stands for: each field not given is the declaration of its name at a fresh instance of its scheme, unified with the field's type. `Ops(OrderedSet.Set(Int), Int)` fixes `a` to `Int`, so `fromList`'s requirement is filled with `Int.compare` and the field holds `fromList` at `Int`. The restrictions travel as from a literal: `hashed : Ops(Set(Int), Int)` carries `=` from `Set`'s functions, met at `Int`.
- **The bindings.** `let ordered : Ops(OrderedSet.Set(Int), Int) = Ops(..OrderedSet)` has a type with no variable in it; §8.5 runs the initializer once, a pure construction.
- **Requirement 4.** `OrderedSet.Set(Int)` and `OrderedSet.Set(Descending)` do not unify, since two declared types are distinct by name (§8.7).
- **Equality.** `==` on two ordered sets is structural over their sorted lists (§3.10) and needs the element's equality at that application: a set whose elements hold functions is built and used, and `==` on two of them is refused there.
- **The invariant.** The sorted list is the module's alone (§4.4).

**What the types do not guarantee**, stated as the program's promise: `compare` is a total order, and where the element type has `==`, says `Equal` only where `==` holds. Nothing checks either. Where the element type has no `==`, an ordered set holds one element per class of `Equal`, and `put` keeps the element already there (rule 5). A `compare` that is not transitive breaks the order: `contains` answers wrongly and duplicates stay. One that says `Equal` where `==` does not makes `==` on two sets depend on the order of insertion.

After an `Upgrade` (§6.10) or `:reload` (§11.2) a set built under the old `T.compare` is read under the new, and a changed order misorders it. A set sent to a node whose `T.compare` differs is read under that node's; MVP 3.0 decides where versions meet.

## What changes in Ernest

- §4.8 and Appendix A: a parameter may name a member of a type, `compare = a.compare`, `Param = ident ":" Type | ident "=" typevar "." member`. Where the type is known at the call the compiler passes the member and the argument is not written; where it is a variable the argument is written, and is a parameter of the enclosing function naming the same member; the three errors of rule 1. A requirement names a member of §4.8 only, and is never inferred (rule 2). The sentence that an operator carries no hidden argument stays, and this is the one argument the program does not write.
- §3.5 and Appendix A: in a record construction, `..` may name a namespace, which fills the fields not given from the declarations of their names (rule 7). `Fields = ".." ( Expr | Namespace ) [ "," FieldSet { "," FieldSet } ] | FieldSet { "," FieldSet }`.
- §4.2 and §11.1: a file name of words joined by `_` names one namespace, MVP 2.99b's item 4, done 2026-10-02.
- Appendix E, a section at its end: `ordered_set.ern`, namespace `OrderedSet`, with `abstract type Set(a)`, `empty`, `fromList`, and E.0 rule 2's vocabulary; which functions name `a.compare` and which `b.compare` (rule 3); `==` structural; the sorted list's costs.
- §11.5: the three errors of rule 1, rule 2's error for a name that is no member, and the fill's; a call of a selected field names it as written, `ops.intersection`, where its message says "the callee", as requirement 5 asks; `ern doc` writes a requirement as declared.
- E.4 and E.0's vocabulary do not change. Nothing else in §3 or §4; §3.10 stays as it is: tuples, lists, `Optional` and `Either` have no order, and a program sorts pairs with a function it passes to `List.sort`.

## What it costs to build

The work falls on the parser and checker for the two forms, on the library, and on the documents:

| Area | Work | Item |
|---|---|---|
| Parser, checker, interfaces, emitter | the requirement: its form, its three errors, its record in the `.erc`, the member inserted at the call | 5 |
| Parser, checker | `..` naming a namespace in a record construction, its error | 5 |
| `ordered_set.ern` | the module, its page, its tests, its section of Appendix E with a test per section | 5 |
| `ern doc` | a requirement written as declared; a record type's constructor one field per line, where it writes it on one line | 5 |
| Report | §4.8, §3.5, Appendix A, §11.5, the Appendix E section | 5 |
| Guide §7.3 | rewritten over the finished code | 16 |

At run time a requirement is an ordinary argument and a field use one indirect call, the host's own application of a fun. The ordered set's own costs are rule 9's.

## Compared, with pros and cons

`usage.ern` against the same program in OCaml, Standard ML, Haskell and Elm, in what a program writes:

| | The order | Equality | Code written once over two representations | Generic over the element | A second order |
|---|---|---|---|---|---|
| Ernest | nowhere; the member is found | `==` | a record the program declares, `Ops(..Set)` and `Ops(..OrderedSet)` | `compare = a.compare` declared, and passed at each call | a wrapper type |
| OCaml | once, at `Set.Make(Int)` | `IntSet.equal` | a first-class module, its parameter annotated | a functor, or a first-class module passed | a second functor application |
| Standard ML | once, at the functor application | `IntSet.equal` | a functor over the representation's structure | a functor | a second functor application |
| Haskell | nowhere; `Ord` is found | `==` | a class the program declares, an instance per representation | `Ord a =>`, inferred | a `newtype` |
| Elm | nowhere; elements are `comparable` | `==` | no second representation | `comparable` only | no second order |

In `usage.ern`, `main` writes no order and `==` once; `common` writes `ops.` four times over an annotated parameter; the program declares `Ops` in three lines and fills it in two. In `numeric.ern`, three generic functions declare `add = a.+` once each and their calls write nothing, but `sum`, whose zero is passed beside the `+` that is found. In `num.ern`, each type fills `Num` in one line, and every generic function takes `num` and writes `num.` before each operation.

**Pros.**

- Against OCaml and Standard ML: no functor application and no module per element type, one `OrderedSet` for every element type, and a record declared and filled in five lines where a functor is a module. The guarantee is the same: one order per type.
- Against Haskell: the same program on the element side, and no class declaration for code over two representations. Nothing is inferred and nothing is declared an instance: the only thing resolved is a member the type already has, and the chain through generic code is written at every call and read on every page.
- Against Elm: a user type has an order, `fn Date.compare`; a second representation exists; a second order is a wrapper type.

**Cons.**

- Against Haskell: every generic function that needs the order declares `compare = a.compare` and passes it at every call, where Haskell infers `Ord a =>`; and one argument is passed that the program does not write, where §4.8 allowed none.
- Against OCaml and Standard ML: the member is the only order a type has, so a reversed set of `Int` is a wrapper type where OCaml applies the functor again; and the requirement and the fill are two forms, where a functor is one.
- Against Elm: two forms where Elm has none, and an order declared per user type where Elm has no such type at all.
- Against all: a record over the whole vocabulary is twelve fields the program writes, and `filter` and `foldLeft` cannot be fields. The requirement reaches §4.8's members only, `compare`, `negate` and the operators; a record that needs a `zero`, a `hash` or a `show` fills them by name from a namespace (rule 7) and can name none in a requirement (rule 2).
