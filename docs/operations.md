# Operations records

*The comparison of operations records, code written once over several representations of one type, with type classes, functors and traits, what the forms cost to build, and three programs that use them. The report states the forms: the requirement in §4.9, `derives` in §3.5, the fill in §5.6, the place of a record among a function's parameters in E.0's shape rule 1, `show` under a requirement in E.1, and the ordered set and map in E.25 and E.26; [`soundness.md`](soundness.md) argues them. This note restates none of their rules. The log's *Operations Records*, *Members, Operators, and No Hidden Argument*, *The Operations Note Rewritten*, *The Order Bound Once*, *MVP 2.99b's Questions, One by One* and *The Requirement, the Fill and the Set as Data* argue the choices, and *The Requirement Built* the build. The three programs stand under [`docs/operations/`](operations/), where the integration tests build them and hold what they print to what this note says; the code here is excerpted from them. Revised 2026-10-04.*

Ernest has one set in its standard library, `Set`, a hash set. A second, `OrderedSet`, keeps its elements in the order of their type's `compare`. Code written once works on both through an *operations record*, a record the program declares of the operations it needs, filled from each representation's namespace. The § numbers cite Ernest's report.

## Goals

1. Each type's operations are called through its module: `Set.put(s, x)`, `OrderedSet.put(s, x)`, and the ordered set's own `OrderedSet.min(s)`.
2. Generic code is an ordinary function over a record, and the caller chooses the representation.
3. An ordered set is data: it has `==`, can key a `Map`, and can be sent to another node.
4. Sets in different orders cannot be combined.
5. Errors name what the user wrote: a function, a type, a record.
6. A program changes a set's representation by renaming it; no call site changes otherwise.

## The programs

The ordered set and the ordered map are the standard library's, [`ordered_set.ern`](../stdlib/ordered_set.ern) and [`ordered_map.ern`](../stdlib/ordered_map.ern); guide §7.3 shows the parts of the first that carry the requirement. The programs here use them and the forms.

[`usage.ern`](operations/usage.ern) is a program over both sets, a type that derives its order, a map in order, and printing in generic code. No line names an order; `unique` and `shown`, generic, declare what they need; and `Operations` is the record `common` needs, declared there and filled from each representation at `Int`.

```ernest
type Date = Date(year : Int, month : Int, day : Int) derives compare

type Operations(s, a) =
    Operations(fromList : (List(a)) -> s, intersection : (s, s) -> s, toList : (s) -> List(a))

let hashed : Operations(Set(Int), Int) = Operations(..Set)

let ordered : Operations(OrderedSet.Set(Int), Int) = Operations(..OrderedSet)

fn unique(list : List(a)) : List(a) needs a.compare =
    OrderedSet.toList(OrderedSet.fromList(list))

fn shown(list : List(a)) : Unit with m needs a.show =
    List.foreach(list, fn(x) = Io.println(Io.show(x)))

fn common(list : List(a), other : List(a), operations : Operations(s, a)) : List(a) =
    operations.toList(operations.intersection(operations.fromList(list),
                                              operations.fromList(other)))

export fn main() : Unit with Never = {
    let small = OrderedSet.fromList([3, 1, 3]);
    let both = OrderedSet.union(small, OrderedSet.fromList([2]));
    Io.println(Io.show(OrderedSet.toList(both)));
    Io.println(Io.show(OrderedSet.min(both)));
    Io.println(Bool.toString(both == OrderedSet.fromList([2, 3, 1])));
    Io.println(Io.show(OrderedSet.toList(OrderedSet.filter(both, fn(n) = n % 2 == 1))));
    let doubled = OrderedSet.map(both, fn(n) = n * 2);
    Io.println(Bool.toString(OrderedSet.contains(doubled, 6)));
    Io.println(Io.show(unique(["b", "a", "b"])));
    let dates =
        OrderedSet.fromList([Date(year = 2026, month = 10, day = 2),
                             Date(year = 2025, month = 1, day = 1)]);
    Io.println(Io.show(OrderedSet.min(dates)));
    shown(OrderedSet.toList(dates));
    let ages = OrderedMap.fromList([#("bo", 42), #("al", 7)]);
    Io.println(Io.show(OrderedMap.keys(ages)));
    Io.println(Io.show(OrderedMap.get(OrderedMap.put(ages, "cy", 1), "cy")));
    Io.println(Io.show(common([4, 2, 3], [3, 4, 5], ordered)));
    Io.println(Int.toString(List.size(common([4, 2, 3], [3, 4, 5], hashed))))
}
```

It prints `[1, 2, 3]`, `Some(1)`, `true`, `[1, 3]`, `true`, `["a", "b"]`, `Some(Date(year = 2025, month = 1, day = 1))`, the two dates on a line each in order, `["al", "bo"]`, `Some(1)`, `[3, 4]` and `2`: two sets built in different orders are `==`, `map` makes a set of the results' type, `unique` and `shown` write nothing at their calls, `Date` is ordered by year, month and day from its declaration, and `common` is written once for both representations. Without its requirement, `unique` is §4.9's error:

```ernest-rejected
fn unique(list : List(a)) : List(a) =
    OrderedSet.toList(OrderedSet.fromList(list))
```

```console
$ ern build --short-errors usage.ern
usage.ern:18:23: fromList needs a.compare, which unique does not declare
```

`mixed.ern` is a program E.25 refuses, an order belonging to an element type.

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

`ern build` refuses it at `down`: `the argument does not fit OrderedSet.union: expected OrderedSet.Set(Int), found OrderedSet.Set(Descending)`.

Two programs beyond sets test the two forms where no set is involved. [`numeric.ern`](operations/numeric.ern) writes generic numeric functions over the requirement `needs a.+`, at `Int`, at `Float`, and at a type with a `+` of its own; `sum` needs a zero as well, which is no member, so its caller passes one.

```ernest
type Money = Money(Int)

fn Money.+(Money(a) : Money, Money(b) : Money) : Money =
    Money(a + b)

fn total(list : List(a)) : Optional(a) needs a.+ =
    match list {
        [] -> None
      | first :: rest -> Some(List.foldLeft(rest, first, a.+))
    }

fn sum(list : List(a), zero : a) : a needs a.+ =
    List.foldLeft(list, zero, fn(acc, x) = acc + x)

fn doubled(list : List(a)) : List(a) needs a.+ =
    List.map(list, fn(x) = x + x)
```

Its `main` prints `Some(6)`, `Some(4.0)`, `Some(Money(3))`, `6`, `[Money(4)]` and `Some(6)`. Declaring the zero as a requirement is §4.9's error:

```ernest-rejected
fn sum(list : List(a)) : a needs a.zero, a.+ =
    List.foldLeft(list, a.zero, a.+)
```

```console
$ ern build --short-errors numeric.ern
numeric.ern:16:34: zero is not a member: a requirement names compare, negate, an operator or show (§4.8, E.1)
```

[`num.ern`](operations/num.ern) writes the same functions over a record the program fills by hand, `Num`, since `zero` and `one` are no members and `+` is no field name, so no fill applies; each type is one line, and generic code passes the record.

```ernest
type Num(a) = Num(zero : a, one : a, add : (a, a) -> a, mul : (a, a) -> a)

let ints : Num(Int) = Num(zero = 0, one = 1, add = Int.+, mul = Int.*)

fn sum(list : List(a), num : Num(a)) : a =
    List.foldLeft(list, num.zero, num.add)

fn sumOfSquares(list : List(a), num : Num(a)) : a =
    sum(List.map(list, fn(x) = num.mul(x, x)), num)
```

Its `main` prints `6`, `3.0` and `14`.

## What the types do not guarantee

The report holds no contract for `compare`'s laws yet; MVP 2.99d's item 4 moves this section to §3.10, E.25 and E.26 pointing at it, and it then goes from here.

Stated as the program's promise: `compare` is a total order, and where the element type has `==`, says `Equal` only where `==` holds. Nothing checks either. Where the element type has no `==`, an ordered set holds one element per class of `Equal`, and `put` keeps the element already there (E.25). A `compare` that is not transitive breaks the order: `contains` answers wrongly and duplicates stay. One that says `Equal` where `==` does not makes `==` on two sets depend on the order of insertion.

After an `Upgrade` (§6.10) or `:reload` (§11.2) a set built under the old `T.compare` is read under the new, and a changed order misorders it. A set sent to a node whose `T.compare` differs is read under that node's; MVP 3.1's normalized definition decides where versions meet.

## What it costs to build

The work falls on the parser and checker for the two forms, on the library, and on the documents:

| Area | Work | Item |
|---|---|---|
| Lexer, Emacs mode | two words read by position, `needs` and `derives` | 5 |
| Parser, checker, interfaces, emitter | the requirement: its form, its two errors, its record in the `.erc`, the member or `show`'s descriptor supplied at a call or passed along from the enclosing requirement | 5 |
| Parser, checker, emitter | `derives compare`: the generated member, its error, its place on the page | 5 |
| Parser, checker | `..` naming a namespace in a record construction, its error | 5 |
| `ordered_set.ern` | the module, its page, its tests, its section of Appendix E with a test per section | 5 |
| `ordered_map.ern` | the same, over keys in order | 5 |
| `ern shell` | a requirement in `:type` and in completion | 5 |
| `ern doc` | a requirement written as declared; a record type's constructor one field per line, where it writes it on one line | 5 |
| Report | a new section after §4.8 for the requirement; §4.8, §3.5, §5.6, §2.4, E.0, E.1, Appendix A, Appendix F, §11.5; the two Appendix E sections | 5 |
| Guide §7.3 | rewritten over the finished code, `ordered_set.ern` its example with `usage.ern`'s program | 16 |

At run time a requirement's member is an ordinary argument and a field use one indirect call, the host's own application of a fun. The ordered set's own costs are E.25's.

## Compared, with pros and cons

`usage.ern` against the same program in OCaml, Standard ML, Haskell, Rust and Elm, in what a program writes:

| | The order | Equality | Code written once over two representations | Generic over the element | A second order |
|---|---|---|---|---|---|
| Ernest | nowhere; the member is found | `==` | a record the program declares, `Operations(..Set)` and `Operations(..OrderedSet)` | `needs a.compare` declared; nothing written at a call | a wrapper type |
| OCaml | once, at `Set.Make(Int)` | `IntSet.equal` | a first-class module, its parameter annotated | a functor, or a first-class module passed | a second functor application |
| Standard ML | once, at the functor application | `IntSet.equal` | a functor over the representation's structure | a functor | a second functor application |
| Haskell | nowhere; `Ord` is found | `==` | a class the program declares, an instance per representation | `Ord a =>`, inferred | a `newtype` |
| Rust | nowhere; `Ord` is found | `==` | a trait the program declares, an `impl` per representation | `T: Ord` declared; nothing written at a call | a wrapper type, `Reverse<T>` in the standard library |
| Elm | nowhere; elements are `comparable` | `==` | no second representation | `comparable` only | no second order |

In `usage.ern`, `main` writes no order and `==` once; `unique` declares the requirement and its call writes nothing; `common` writes `operations.` four times over an annotated parameter; the program declares `Operations` in three lines and fills it in two. In `numeric.ern`, three generic functions declare `needs a.+` once each, their calls write nothing, and their bodies write `+` or `a.+`; `sum`'s zero is passed beside the `+` that is found. In `num.ern`, each type fills `Num` in one line, and every generic function takes `num` and writes `num.` before each operation.

In Rust, `unique` is `fn unique<T: Ord>(list: Vec<T>) -> Vec<T>`, its bound declared and supplied at each call as the requirement is; `Date` is `#[derive(PartialEq, Eq, PartialOrd, Ord)]` over a struct of three fields, four traits for one order, since `==` is a trait too; and `common` is a trait of three methods the program declares, with an `impl` for `HashSet<T>` and one for `BTreeSet<T>`, each writing each method. The derive is the same as `derives compare`: it orders by variant in declaration order and then by field from left to right, bounds the type's parameters, and is an error at a field whose type has no order. Rust bounds every parameter of the type, reached by the comparison or not; `derives compare` requires only those it reaches.

**Pros.**

- Against OCaml and Standard ML: no functor application and no module per element type, one `OrderedSet` for every element type, and a record declared and filled in five lines where a functor is a module. The guarantee is the same: one order per type.
- Against Haskell: the same program on the element side, and no class declaration for code over two representations. Nothing is inferred and nothing is declared an instance: the only thing resolved is a member the type already has, nothing is written at a call, and every signature on the page says what its type must have.
- Against Rust: the same discipline, a requirement declared and never inferred, in one word where an order derived in Rust names four traits; a representation's operations enter the record by name from its module, `Operations(..Set)`, where an `impl` writes each method; and the derive requires only the parameters the comparison reaches, where Rust bounds them all.
- Against Elm: a user type has an order, `fn Date.compare`; a second representation exists; a second order is a wrapper type.

**Cons.**

- Against Haskell: every generic function that needs the order declares `needs a.compare`, where Haskell infers `Ord a =>`; and one argument is passed unseen along the declared requirements, where §4.8 allowed none.
- Against Rust: a bound names any trait, the program's own among them, so a `zero` or a `hash` is a bound where Ernest passes a parameter or fills a field; a trait's method is dispatched statically, one copy of the code per type, where a field use is one indirect call and a requirement one argument passed; a bound stands once on an `impl` block for every method in it, where each function of `OrderedSet` that needs the order writes `needs a.compare`; and Rust orders `Option`, tuples and `Vec` by their contents, where Ernest's `Optional`, tuples and lists have no order.
- Against OCaml and Standard ML: the member is the only order a type has, so a reversed set of `Int` is a wrapper type where OCaml applies the functor again; and the requirement and the fill are two forms, where a functor is one.
- Against Elm: two forms where Elm has none, and an order declared per user type where Elm has no such type at all.
- Against all: a record over the whole vocabulary is twelve fields the program writes, and `filter` and `foldLeft` cannot be fields. The requirement reaches §4.8's members and `show` only; a record that needs a `zero` or a `hash` fills them by name from a namespace (§5.6) and can name neither in a requirement (§4.9).
