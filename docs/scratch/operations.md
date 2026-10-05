# Operations records

*A design note for a reader outside the project. It describes how Ernest lets code be written once over several representations of one type, and how a generic function reaches an operation of the type it is generic in, without type classes. The design is built. The programs are those of Ernest's guide, section 7.3, whose tests compile each of them and compare what it prints with what is shown here; one more, `Num`, is a program of the project's own tests. Each part begins with a small example and then states its rules precisely, for the reader who wants them. A link marked *report* leads to the section of Ernest's language report that states the rule. Revised 2026-10-05.*

## Background

Ernest is a small functional language with two concepts: pure functions, typed by Hindley-Milner inference, and processes with typed mailboxes. This note stays on the function side. A few facts about the language carry the design.

- A type's operations are ordinary functions in its module, called through the module's name: `Set.put(set, x)`, `List.sort(list, compare)`. A file names its module: `ordered_set.ern` is the module `OrderedSet`.
- A handful of operations are *members* of a type: `compare`, `negate` and the arithmetic operators `+`, `-`, `*`, `/`, `%` and `<>`. A user type declares a member in its own module, with the type's name as prefix: `fn Date.compare(a : Date, b : Date) : Ordering = ...`. `Ordering` is `Less`, `Equal` or `Greater` ([report §4.5](https://github.com/joagre/ernest/blob/main/report/language.md#45-functions), [§3.10](https://github.com/joagre/ernest/blob/main/report/language.md#310-equality-and-ordering)).
- The compiler resolves an operator by the type of its operand. `a + b` is `Int.+` when `a` is an `Int` and `Money.+` when `a` is a `Money`. `x < y` is `T.compare(x, y) == Less` for the operand's type `T`. The operand's type must be known once the enclosing definition has been inferred. Before this design, an operator on a bare type variable was a type error ([report §4.8](https://github.com/joagre/ernest/blob/main/report/language.md#48-operators)).
- `==` is built in and structural on every value that holds no function and no process address. It is not a member and cannot be redefined ([report §3.10](https://github.com/joagre/ernest/blob/main/report/language.md#310-equality-and-ordering)).
- There is no type class, no implicit argument and no overloading beyond the members. A type has at most one `compare`, one `+`, and so on.
- In the code below, `#(a, b)` is a tuple, `::` is cons, `abstract type` hides a type's constructor outside its module, and `with e` in a function type is an effect variable: the function may do whatever its callback does.

## The problem

The standard library had one set, `Set`, a hash set. Two needs came together.

1. **A set in order.** `OrderedSet` keeps its elements in the order of their type's `compare`. Every function of it that touches the order needs the element type's `compare`, and a value carries no operations with it, so the type must say which: a set of `Int` needs `Int.compare`, a set of `Date` needs `Date.compare`.
2. **Code written once over both sets.** A function that builds two sets and intersects them should be written once and run on either representation, with the caller choosing which.

Beside the sets, the same question comes up for numbers. A sum over a list of `Int`, of `Float` or of a type of the program's own needs the element type's `+`.

The usual answers are type classes, as in Haskell; functors, as in OCaml and Standard ML; or passing the operation as a parameter at every call. Ernest takes a fourth way, built from three small forms and one idiom, each for a need of its own:

| The need | The form |
|---|---|
| A type's own operation, in a function generic in the type | a *requirement*, `needs a.compare` |
| One algorithm over several representations | an *operations record*, filled from a module by `..` |
| Values of several representations in one list | a record of closures |
| A type's order, written once | `derives compare` |

The last row is a form of the language; the third is an idiom, a record whose fields are closures, which needs nothing new.

## Goals

1. Each type's operations are called through its module: `Set.put(s, x)`, `OrderedSet.put(s, x)`, and the ordered set's own `OrderedSet.min(s)`.
2. Generic code is an ordinary function over a record, and the caller chooses the representation.
3. An ordered set is data: it has `==`, can key a `Map`, and can be sent to another node.
4. Sets in different orders cannot be combined.
5. Errors name what the user wrote: a function, a type, a record.
6. A program changes a set's representation by renaming it; no call site changes otherwise.

## A requirement

A function generic in a type may need the type's own operation: its order, to find the largest of a list. It says so after its result type, `needs a.compare`, a *requirement* ([report §4.9](https://github.com/joagre/ernest/blob/main/report/language.md#49-requirements)):

```ernest
// largest.ern  (namespace Largest)
fn largest(first : a, rest : List(a)) : a needs a.compare =
    List.foldLeft(rest, first, fn(best, x) = if x > best then x else best)

fn largestOf(list : List(a)) : Optional(a) needs a.compare =
    match list {
        [] -> None
      | first :: rest -> Some(largest(first, rest))
    }

fn sorted(list : List(a)) : List(a) needs a.compare =
    List.sort(list, a.compare)

export fn main() : Unit with Never = {
    Io.println(Int.toString(largest(3, [8, 5])));
    Io.println(largest("pear", ["fig", "apple"]));
    Io.println(Io.show(largestOf([1.5, 0.5])));
    Io.println(Io.show(sorted([3, 1, 2])))
}
```

```console
$ ern build largest.ern
$ ern run largest.erc
8
pear
Some(1.5)
[1, 2, 3]
```

In the body, an operator resolves to the member of whatever type `a` stands for, as it would on a known type: `x > best` in `largest` is `a.compare`. The member is also a value, written `a.compare`, which `sorted` hands to `List.sort`. `List.sort` takes its order as a parameter, since a sort may be given any order; a function declares a requirement where the type's own member is meant.

A call writes nothing for the requirement. `largest(3, [8, 5])` is `largest` with `Int.compare`, which the compiler supplies, since the element type is known there, and the next call is supplied `String.compare`. Where the element type is itself a type variable, the calling function declares the requirement too, as `largestOf` does for `largest`, and the member it was given goes along. Without the requirement the call is refused, naming what to add:

```ernest-rejected
fn largest(first : a, rest : List(a)) : a needs a.compare =
    List.foldLeft(rest, first, fn(best, x) = if x > best then x else best)

fn largestOf(list : List(a)) : Optional(a) =
    match list {
        [] -> None
      | first :: rest -> Some(largest(first, rest))
    }
```

```console
$ ern build generic.ern
generic.ern:7:31: largest needs a.compare, which largestOf does not declare
6 |         [] -> None
7 |       | first :: rest -> Some(largest(first, rest))
  |                               ^^^^^^^
  | = help: add `needs a.compare` to largestOf's signature
```

A requirement is always written: the compiler infers none, and a body that uses `>` on an `a` without it is refused the same way.

A requirement names `compare`, `negate`, an operator, or `show`, and nothing else. Several are separated by commas, `needs a.+, a.compare`. A sum is written once for `Int`, for `Float`, and for any type that declares a `+`:

```ernest
// members.ern  (namespace Members)
type Date = Date(year : Int, month : Int, day : Int) derives compare

fn sum(first : a, rest : List(a)) : a needs a.+ =
    List.foldLeft(rest, first, a.+)

fn shown(list : List(a)) : Unit with m needs a.show =
    List.foreach(list, fn(x) = Io.println(Io.show(x)))

export fn main() : Unit with Never = {
    Io.println(Int.toString(sum(1, [2, 3])));
    Io.println(Float.toString(sum(0.5, [1.5])));
    let dates = [Date(year = 2026, month = 10, day = 2), Date(year = 2025, month = 1, day = 1)];
    shown(List.sort(dates, Date.compare))
}
```

```console
$ ern build members.ern
$ ern run members.erc
6
2.0
Date(year = 2025, month = 1, day = 1)
Date(year = 2026, month = 10, day = 2)
```

`Date` gets its order from its declaration. `derives compare` gives the type the member `compare`, which orders two values by constructor in declaration order and then by field from left to right, each by its type's `compare`, so the dates print by year, then month, then day. A field whose type has no `compare`, an `Optional(Int)`, is refused at the declaration ([report §3.5](https://github.com/joagre/ernest/blob/main/report/language.md#35-sum-types)).

`shown` declares `needs a.show`. `show` is no member a type declares: every type can be shown. `Io.show` writes a value by its type, which a function generic in `a` does not know, so the function declares `needs a.show`, and each call supplies it for its type. `Io.show`'s own type says so, `(a!) -> String needs a.show`, and under the requirement it writes `a` and any type built from it, `List(a)` as well ([report §9.4](https://github.com/joagre/ernest/blob/main/report/language.md#94-built-in-functions-6), [E.1](https://github.com/joagre/ernest/blob/main/report/library.md#appendix-e1-ioern-namespace-io)).

### The requirement, precisely

**What it licenses in the body.** Under the requirement, `a.compare` in the body is that member, a value of type `(a, a) -> Ordering`. An operator on `a` resolves to it just as it would on a known type: `x < y` goes through `a.compare`, `x + y` through `a.+`. The member has its shape at `a`, with `a` for its result: `a.negate` has type `(a) -> a` and `a.+` has type `(a, a) -> a`. So a function that needs `a.+` accepts a type whose `+` answers that type, and not one whose `+` answers something else.

**What a call writes: nothing.** The compiler supplies the member once it has inferred the enclosing definition and knows what `a` was instantiated to. There are three cases.

- `a` is a known type. The compiler supplies that type's member. `OrderedSet.fromList([3, 1, 3])` is `fromList` with `Int.compare`.
- `a` is a type variable of the enclosing function's own signature. That function's own requirement supplies it. `largestOf` above declares `needs a.compare`, and its call of `largest` passes on the `compare` that `largestOf` was given.

- `a` is a type built from a variable, `List(b)`. It is read as a known type whose member is looked for, and refused where it has none.

Members supply members. A member with a requirement of its own, such as the derived `Pair.compare` below, is supplied with that requirement resolved at its type by the same rule: at `Pair(Int, String)` with `Int.compare` and `String.compare`, and at `Pair(a, b)` with the enclosing function's requirement. A function with a requirement used as a value is the function with its member supplied by the same rule: under `needs a.compare`, `List.foldLeft(list, empty, put)` passes `put` together with that `compare`.

**The errors.** Each names what the program wrote and, where there is one, what it must write instead.

- A call where the type is a variable and the enclosing function declares no requirement for it, as `generic.ern` above shows, with the help naming what to add.
- A call at a known type without the member:
  `fromList needs List(Int).compare, and List(Int) has no compare`
- A call at a type whose member has another shape:
  `total needs Vec.+ : (Vec, Vec) -> Vec, and Vec.+ answers Float`
- `a.compare` or `<` on a type variable in a body without the requirement is a type error, as it was before.

**Where a requirement is in force.** The requirement in force in a body is the enclosing `fn` declaration's, for the type variables of its signature, wherever the use stands: inside a lambda, and inside a lambda bound by `let`, included. One case needs care. A `let`-bound lambda whose own type variable is not the signature's is generalized on its own, before any call ties it to the signature, so an unannotated `let build = fn(xs) = OrderedSet.fromList(xs)` meets the first error above. A `fn` declared in a block declares its own requirement for its own variables and shares the enclosing one for the variables they share. A top-level `let` declares no requirement, so `let f = OrderedSet.fromList` is refused, `fromList needs a.compare, which a top-level let cannot declare`, with the help ``declare a `fn` with `needs a.compare` ``.

**What a requirement may name.** The variable is a type variable of the signature that stands in a value position ([report §3.9](https://github.com/joagre/ernest/blob/main/report/language.md#39-type-variables-and-polymorphism)). `needs e.compare` on an effect variable, and `needs b.compare` where `b` is nowhere in the signature, are errors at the declaration: `b is no type variable of the signature`. A variable that stands only in the result type may carry one, since the instantiation is read once the enclosing definition is inferred. Under a requirement on `a`, no parameter, `let` or pattern variable may be named `a`, so that `a.compare` reads one way.

A requirement names a member and nothing else: `compare`, `negate`, an operator, and beside them `show`. Under `needs a.show`, `Io.debug`, which prints a value to standard error and returns it, applies as `Io.show` does ([report E.1](https://github.com/joagre/ernest/blob/main/report/library.md#appendix-e1-ioern-namespace-io)). A value whose type holds a variable no requirement names `show` for is a type error.

`needs a.zero` and `needs a.hash` are errors at the declaration: `zero is not a member: a requirement names compare, negate, an operator or show (§4.8, E.1)`; the parenthesis cites the sections of the language's report that list the members. A program declares no member beyond these. What a generic function needs beyond the members, a `zero` or a `hash`, it takes as a parameter or as a field of a record the program fills, described below.

A type has one member of each name, so a requirement has one value at a type. A second order, sum or product for a type exists only through a second type. A requirement is never inferred: a function has the requirement it writes and no other, and a call that needs one the enclosing function does not declare is an error, never a silently widened signature.

**Parameter or requirement.** A function takes a member as a parameter where any function of its type may be given, `List.sort(list, compare)`. It declares a requirement where the type's own member is meant. A helper of a function with a requirement declares the requirement itself rather than taking the member as a parameter.

**The derived order.** `derives compare` names `compare` and nothing else ([report §3.5](https://github.com/joagre/ernest/blob/main/report/language.md#35-sum-types)). A field without an order is refused with `Date.compare cannot be derived: Optional(Int) has no compare`. The derived member is written on the type's documentation page as any member. For a type with parameters it declares a requirement for each parameter the comparison reaches: `type Pair(a, b) = Pair(first : a, second : b) derives compare` gives `Pair.compare` the requirement `needs a.compare, b.compare`.

## A module built on a requirement: the ordered set

The standard library's `OrderedSet` keeps a set's elements in the order of their type's `compare`, and each of its functions that needs the order declares `needs a.compare`. A program uses it without naming an order:

```ernest
// sets.ern  (namespace Sets)
fn unique(list : List(a)) : List(a) needs a.compare =
    OrderedSet.toList(OrderedSet.fromList(list))

export fn main() : Unit with Never = {
    let small = OrderedSet.fromList([3, 1, 3]);
    let both = OrderedSet.union(small, OrderedSet.fromList([2]));
    Io.println(Io.show(OrderedSet.toList(both)));
    Io.println(Io.show(OrderedSet.min(both)));
    Io.println(Bool.toString(both == OrderedSet.fromList([2, 3, 1])));
    let doubled = OrderedSet.map(both, fn(n) = n * 2);
    Io.println(Bool.toString(OrderedSet.contains(doubled, 6)));
    Io.println(Io.show(unique(["b", "a", "b"])));
    let ages = OrderedMap.fromList([#("bo", 42), #("al", 7)]);
    Io.println(Io.show(OrderedMap.keys(ages)))
}
```

```console
$ ern build sets.ern
$ ern run sets.erc
[1, 2, 3]
Some(1)
true
true
["a", "b"]
["al", "bo"]
```

`OrderedSet.fromList([3, 1, 3])` is `fromList` with `Int.compare`, and `unique`, generic in its element, declares the requirement and passes it on. `map` needs its result's order, `b.compare`, since the set it makes is in the results' order; `size`, `toList`, `filter` and the rest need none.

An order belongs to a type, since a type has one `compare`. A second order on `Int` is a second type with a `compare` of its own, and two sets in two orders are of two types, which cannot meet:

```ernest-rejected
type Descending = Descending(Int)

fn Descending.compare(Descending(left) : Descending, Descending(right) : Descending) : Ordering =
    Int.compare(right, left)

export fn main() : Unit with Never = {
    let up = OrderedSet.fromList([1]);
    let down = OrderedSet.fromList([Descending(1)]);
    Io.println(Int.toString(OrderedSet.size(OrderedSet.union(up, down))))
}
```

```console
$ ern build mixed.ern
mixed.ern:9:66: the argument does not fit OrderedSet.union: expected OrderedSet.Set(Int), found OrderedSet.Set(Descending)
8 |     let down = OrderedSet.fromList([Descending(1)]);
9 |     Io.println(Int.toString(OrderedSet.size(OrderedSet.union(up, down))))
  |                                             ---------------- OrderedSet.union : (OrderedSet.Set(a!), OrderedSet.Set(a!)) -> OrderedSet.Set(a!) needs a.compare
  |                                                                  ^^^^
  | = help: the types differ at Int and Descending
```

### The ordered set, precisely

**It is data.** `OrderedSet.Set(a)` holds its elements and nothing else; its order is its element type's `compare` ([report E.25](https://github.com/joagre/ernest/blob/main/report/library.md#appendix-e25-ordered_setern-namespace-orderedset)). `==` on two sets is structural, a set keys a `Map`, and a set is sent to another node as any value is. Of its functions, `fromList`, `contains`, `put`, `remove`, `union`, `intersection`, `difference` and `isSubset` need `a.compare`; `map` and `filterMap` need their result's, `b.compare`; `empty`, `size`, `isEmpty`, `toList`, `min`, `max`, `filter`, `foldLeft`, `foreach`, `any`, `all` and `find` need none.

**An order belongs to an element type**, as `mixed.ern` shows; that is goal 4.

**`put` keeps the element already there** where `compare` says `Equal`.

**The representation is a sorted list**, one shape per set, so that `==` is structural. `put`, `contains` and `remove` are linear in the set's size; `fromList` is a stable sort and one pass, `n log n`, and `map` and `filterMap` cost that beside the function's; `union`, `intersection`, `difference` and `isSubset` are linear in the two sizes. A representation of another shape must also have one shape per set. It would replace the list when a program's measurement shows the linear cost matters, with no change a program can see.

**Where it lives.** `OrderedSet` is the standard library's `ordered_set.ern`. Its type is `OrderedSet.Set(a)`; inside the file, `Set` is this type and shadows the built-in hash set. A set carried into the other representation goes through that representation's `fromList` of its `toList`. The hash set, `Set`, does not change.

**The ordered map.** `OrderedMap`, the standard library's `ordered_map.ern`, is specified as the ordered set is ([report E.26](https://github.com/joagre/ernest/blob/main/report/library.md#appendix-e26-ordered_mapern-namespace-orderedmap)). Its type `OrderedMap.Map(k, v)` keeps its keys in the order of their type's `compare`, with the same vocabulary as the hash map. Each function that needs the keys' order declares `needs k.compare`; the map is data, a sorted list of pairs with one shape per map, and `==` is structural. `put` replaces the value already there, as a map's `put` does.

## An operations record

A requirement names a type's members and nothing else. `fromList` and `intersection` are a module's functions, not members, so an algorithm written once over two representations of a set takes them another way: as a record, which the program declares.

```ernest
// common.ern  (namespace Common)
type Operations(s, a) =
    Operations(fromList : (List(a)) -> s, intersection : (s, s) -> s, toList : (s) -> List(a))

let hashed : Operations(Set(Int), Int) = Operations(..Set)

let ordered : Operations(OrderedSet.Set(Int), Int) = Operations(..OrderedSet)

fn common(list : List(a), other : List(a), operations : Operations(s, a)) : List(a) =
    operations.toList(operations.intersection(operations.fromList(list),
                                              operations.fromList(other)))

export fn main() : Unit with Never = {
    Io.println(Io.show(common([4, 2, 3], [3, 4, 5], ordered)));
    Io.println(Int.toString(List.size(common([4, 2, 3], [3, 4, 5], hashed))))
}
```

```console
$ ern build common.ern
$ ern run common.erc
[3, 4]
2
```

`Operations` is an *operations record*: the record of the operations `common` uses, each field's type over the record's parameters, `s` the representation and `a` the element. The parameter `s` keeps one call to one representation. `intersection : (s, s) -> s` takes two sets of it and gives a third, so `common` can pass what `fromList` made to `intersection` and its result to `toList`, and cannot mix a hashed set with an ordered one.

`Operations(..Set)` fills the record from the namespace `Set`: each field not given beside the namespace is the declaration of its name there, at the field's type. `Operations(..OrderedSet)` fills it from `OrderedSet`, where `fromList`'s requirement is met with `Int.compare`, since the record's type fixes `a`. A field the namespace lacks, or one of another type, is refused where the record is built ([report §5.6](https://github.com/joagre/ernest/blob/main/report/language.md#56-construction)).

`common` is an ordinary function over the record, and `operations.fromList` a field read, which the parameter's annotation makes possible ([report §3.5](https://github.com/joagre/ernest/blob/main/report/language.md#35-sum-types)). It is written once and called with either record, so the caller chooses the representation at each call. The standard library declares no such record: a program declares the one it needs, three fields here, and reaches what a representation has beyond it, `OrderedSet.min`, through its module.

### The record and the fill, precisely

**The record is the program's** ([report §4.9](https://github.com/joagre/ernest/blob/main/report/language.md#49-requirements)). Each field's type names only the record's own parameters, and the standard library declares no such record and no function over one: which operations a program needs is the program's to say. An operation whose callback has an effect variable, or whose accumulator has a type of its own, `filter` and `foldLeft` among them, cannot be a field, because the field's type would need a variable the record does not have. Generic code that needs one goes through `toList` and `List`.

**The fill** ([report §5.6](https://github.com/joagre/ernest/blob/main/report/language.md#56-construction)). A field may be given beside the module: `Operations(..OrderedSet, toList = mine)` takes the field given and fills the rest. Where the record's type leaves that variable open, the fill is an error naming the field and the variable: `fromList needs a.compare, and the record's type leaves a undetermined`.

A type variable of the enclosing function's signature that its requirement names is not open. So a function with a requirement returns the record generic in the element type, and one fill serves every element type with an order:

```ernest-fragment
fn orderedOperations() : Operations(OrderedSet.Set(a), a) needs a.compare =
    Operations(..OrderedSet)
```

`common([4, 2, 3], [3, 4, 5], orderedOperations())` is `[3, 4]`, and `common(["b", "a"], ["a", "c"], orderedOperations())` is `["a"]`. The fill is supplied from the requirement as a call is.

The name after `..` is a module where it is a qualified name made of type names alone, even where a constructor has the same name, and an expression otherwise, as in the record update `Snapshot(..old, seen = s)`. A module may stand alone after `..`; an expression keeps the rule that at least one field follows it. A field with no declaration of its name in the module, or one whose type does not fit the field's, is an error naming the field and the module: `Operations(..Set) lacks isSubset: Set has no isSubset`.

**A record filled by hand.** A record need not come from a namespace. Where the operations are no members and their names are no field names, the program fills it, one line a type:

```ernest
// num.ern  (namespace Num)
type Num(a) = Num(zero : a, one : a, add : (a, a) -> a, mul : (a, a) -> a)

let ints : Num(Int) = Num(zero = 0, one = 1, add = Int.+, mul = Int.*)

let floats : Num(Float) = Num(zero = 0.0, one = 1.0, add = Float.+, mul = Float.*)

fn sum(list : List(a), num : Num(a)) : a =
    List.foldLeft(list, num.zero, num.add)

fn product(list : List(a), num : Num(a)) : a =
    List.foldLeft(list, num.one, num.mul)

fn sumOfSquares(list : List(a), num : Num(a)) : a =
    sum(List.map(list, fn(x) = num.mul(x, x)), num)

export fn main() : Unit with Never = {
    Io.println(Int.toString(sum([1, 2, 3], ints)));
    Io.println(Io.show(product([1.5, 2.0], floats)));
    Io.println(Int.toString(sumOfSquares([1, 2, 3], ints)))
}
```

It prints `6`, `3.0` and `14`.

## A record of closures

An operations record keeps the representations apart: a list of sets is a list of one representation. Where values of different representations are to meet in one list or one message, a record of a second kind hides the representation. Its fields are functions that close over the value:

```ernest
// shapes.ern  (namespace Shapes)
type Shape = Shape(name : String, area : () -> Float)

fn circle(radius : Float) : Shape =
    Shape(name = "circle", area = fn() = Float.pi * radius * radius)

fn square(side : Float) : Shape =
    Shape(name = "square", area = fn() = side * side)

export fn main() : Unit with Never =
    List.foreach([circle(1.0), square(2.0)],
                 fn(shape) = Io.println(shape.name <> ": " <> Float.toString(shape.area())))
```

```console
$ ern build shapes.ern
$ ern run shapes.erc
circle: 3.141592653589793
square: 4.0
```

A circle and a square are both a `Shape`, since the radius and the side are not in the type: each is captured by the function in its record. The list holds both, and `shape.area()` runs the function the value carries.

The same form serves the two sets, where an operation answers another such record: `put` closes over one set and answers a `Bag` over the next.

```ernest
// bag.ern  (namespace Bag)
/// A set of either representation, which carries its operations and shows
/// no representation, so that a list may hold both.
type Bag(a) = Bag(contains : (a) -> Bool, put : (a) -> Bag(a), toList : () -> List(a))

fn ordered(set : OrderedSet.Set(a)) : Bag(a) needs a.compare =
    Bag(contains = fn(x) = OrderedSet.contains(set, x),
        put = fn(x) = ordered(OrderedSet.put(set, x)),
        toList = fn() = OrderedSet.toList(set))

fn hashed(set : Set(a)) : Bag(a) =
    Bag(contains = fn(x) = Set.contains(set, x),
        put = fn(x) = hashed(Set.put(set, x)),
        toList = fn() = Set.toList(set))

export fn main() : Unit with Never =
    List.foreach([ordered(OrderedSet.empty), hashed(Set.empty)], fn(bag) = {
        let filled = bag.put(2).put(1).put(2);
        Io.println(Io.show(#(List.size(filled.toList()), filled.contains(1))))
    })
```

```console
$ ern build bag.ern
$ ern run bag.erc
#(2, true)
#(2, true)
```

`ordered` declares the requirement, and the lambdas it makes close over the member it was given with the set.

A record of closures gives up what an operations record keeps:

- The representation is hidden, so nothing can take two bags apart to unite them. An operation over two of them needs a design of its own, as one that goes through `toList`.
- The value holds functions, so it has no `==` ([report §3.10](https://github.com/joagre/ernest/blob/main/report/language.md#310-equality-and-ordering)) and does not go to another node ([report §3.11](https://github.com/joagre/ernest/blob/main/report/language.md#311-serialization)).

Reach for an operations record where code written once must keep the representation's type, and for a record of closures where values of different representations meet.

A service with state needs none of these: two processes of different representations take one message type, and the caller holds an `Address(M)` ([report §6.5](https://github.com/joagre/ernest/blob/main/report/language.md#65-addresses)).

This is the form a Java interface takes: each value carries its operations, values of different representations share a list, and a call runs the value's own function. What it cannot do is what an interface cannot do either, an operation that sees inside two values of one representation.

## For the curious: how `OrderedSet` is written

The module is Ernest over `List`, and its source shows a requirement at work in a library. Here are the parts of `stdlib/ordered_set.ern` that carry it, with their doc blocks left out; the rest of the module is in the file, and `:doc OrderedSet` lists it:

```ernest-fragment
// stdlib/ordered_set.ern  (namespace OrderedSet), in part, its doc blocks left out
export abstract type Set(a) = Set(List(a))

export fn fromList(list : List(a)) : Set(a) needs a.compare =
    Set(firstOfEach(List.sort(list, a.compare)))

// The first of each run the order calls `Equal` in a sorted list. The sort
// is stable, so the list's earlier occurrence comes first and is the one
// kept, as `put` keeps the element already there.
fn firstOfEach(sorted : List(a)) : List(a) needs a.compare =
    match sorted {
        first :: second :: rest -> if a.compare(first, second) == Equal then
            firstOfEach(first :: rest)
        else
            first :: firstOfEach(second :: rest)
      | _ -> sorted
    }

export fn contains(Set(list) : Set(a), element : a) : Bool needs a.compare =
    has(list, element)

fn has(list : List(a), element : a) : Bool needs a.compare =
    match list {
        [] -> false
      | head :: rest -> match a.compare(element, head) {
            Less -> false
          | Equal -> true
          | Greater -> has(rest, element)
        }
    }

export fn map(Set(list) : Set(a), f : (a) -> b with e) : Set(b) with e needs b.compare =
    fromList(List.map(list, f))
```

`fromList` declares the requirement and hands `a.compare` to `List.sort`. `firstOfEach` and `has` are helpers generic in the element, so each declares the requirement too, and the member goes along from the exported function that calls it. `map` declares `needs b.compare`, the order of the set it builds.

## How it fits the type system

The type system is Hindley-Milner with let-polymorphism, and the design stays inside it ([report §3.9](https://github.com/joagre/ernest/blob/main/report/language.md#39-type-variables-and-polymorphism)). Every construct in the programs above but the three forms is one the language already had.

- **The requirement adds nothing to the function's type scheme.** It licenses `a.compare` and the operators on `a` in the body, each with the member's shape at `a`. At a call, the checker reads what `a` was instantiated to once the enclosing definition is inferred, as it already reads an operator's operand type. A known type's member becomes an argument the code generator adds after the written ones. A type variable is met by the enclosing function's requirement, whose own added argument is passed along. A member with a requirement of its own is supplied with that requirement resolved first, so the added argument may be a closure over arguments added in turn. Otherwise the call is an error. Nothing is inferred: a requirement is written, or the call is refused. A declaration's requirement is recorded in the module's compiled interface and shown after its type ([report §11.1](https://github.com/joagre/ernest/blob/main/report/toolchain.md#111-ern-build-compiler), [§11.5](https://github.com/joagre/ernest/blob/main/report/toolchain.md#115-diagnostics)).
- **The record is an ordinary sum type** with one constructor and named fields, rank-1: every field's type names only `s` and `a`. A field for `foldLeft` is refused with `type variable b is not a parameter of the type`.
- **Selection.** `operations.toList` in `common` is resolved as an operator's operand is: the operand's type constructor must be known when the enclosing definition is inferred, so the record parameter is annotated. Unannotated, it is refused with `the type whose field toList is read is not determined; annotate it`.
- **Code written once.** `common` is a let-polymorphic function over the record, with a principal type, instantiated at each representation.
- **The fill is checked as the literal it stands for.** Each field not given is the declaration of its name at a fresh instance of its scheme, unified with the field's type. A function that applies `==` to a value of a type variable carries an inferred equality constraint on that variable, and the constraints travel through a fill as through a literal: `hashed : Operations(Set(Int), Int)` carries the hash set's constraint on its elements, met at `Int`.
- **The bindings.** `let ordered : Operations(OrderedSet.Set(Int), Int) = Operations(..OrderedSet)` has a type with no variable in it. A top-level `let` runs its initializer once, and this one is a pure construction ([report §8.5](https://github.com/joagre/ernest/blob/main/report/language.md#85-initialization)).
- **Goal 4** holds because `OrderedSet.Set(Int)` and `OrderedSet.Set(Descending)` do not unify: two declared types are distinct by name ([report §8.7](https://github.com/joagre/ernest/blob/main/report/language.md#87-code-shipping)).
- **Equality.** `==` on two ordered sets is structural over their sorted lists and needs the element's equality at that application ([report §3.10](https://github.com/joagre/ernest/blob/main/report/language.md#310-equality-and-ordering)). A set whose elements hold functions can be built and used, and `==` on two of them is refused there, as `==` on the functions would be.
- **The invariant.** The sorted list is the module's alone; `abstract type` keeps the constructor inside the file ([report §4.4](https://github.com/joagre/ernest/blob/main/report/language.md#44-abstract-types)).

**What the types do not guarantee**, stated as the program's promise: `compare` is a total order, and where the element type has `==`, says `Equal` only where `==` holds. Nothing checks either. Where the element type has no `==`, an ordered set holds one element per class of `Equal`, and `put` keeps the element already there. A `compare` that is not transitive breaks the order: `contains` answers wrongly and duplicates stay. One that says `Equal` where `==` does not makes `==` on two sets depend on the order of insertion.

After a hot code upgrade ([report §6.10](https://github.com/joagre/ernest/blob/main/report/language.md#610-code-replacement)) or a reload in the shell ([report §11.2](https://github.com/joagre/ernest/blob/main/report/toolchain.md#112-ern-run-ern-test-and-ern-shell-runner)), a set built under the old `T.compare` is read under the new, and a changed order misorders it. A set sent to a node whose `T.compare` differs is read under that node's. What happens where two versions of a type meet is a question for the distribution design, and is not decided here.

## What it costs

In the language: two words read by position, `needs` after a function's parameters or result type and `derives` after a type's last constructor, each an ordinary identifier everywhere else ([report §2.4](https://github.com/joagre/ernest/blob/main/report/language.md#24-reserved-words)); a clause at the end of a function declaration; `a.member` as an expression, where `a` is a type variable under a requirement; `derives compare` at the end of a type declaration; and a module name after `..` in a record construction. The type checker gained the supply of members at calls and at fills, the code generator the added argument, and the compiled interface a record of each declaration's requirement. One sentence of the language's rule on operators changed ([report §4.8](https://github.com/joagre/ernest/blob/main/report/language.md#48-operators)). It had said that an operator carries no argument the program has not declared. It now says: on a known type none, and on a type variable the member a requirement names, which a call supplies without writing it.

At run time a requirement's member is an ordinary argument, and a field use is one indirect call, the Erlang runtime's own application of a function value. The ordered set's own costs are the sorted list's.

## Compared with OCaml, Standard ML, Haskell, Rust, Java and Elm

The programs above against the same programs in the six languages, in what a program writes:

| | The order | Equality | Code written once over two representations | Generic over the element | A second order |
|---|---|---|---|---|---|
| Ernest | nowhere; the member is found | `==` | a record the program declares, `Operations(..Set)` and `Operations(..OrderedSet)` | `needs a.compare` declared; nothing written at a call | a wrapper type |
| OCaml | once, at `Set.Make(Int)` | `IntSet.equal` | a first-class module, its parameter annotated | a functor, or a first-class module passed | a second functor application |
| Standard ML | once, at the functor application | `IntSet.equal` | a functor over the representation's structure | a functor | a second functor application |
| Haskell | nowhere; `Ord` is found | `==` | a class the program declares, an instance per representation | `Ord a =>`, inferred | a `newtype` |
| Rust | nowhere; `Ord` is found | `==` | a trait the program declares, an `impl` per representation | `T: Ord` declared; nothing written at a call | a wrapper type, `Reverse<T>` in the standard library |
| Java | nowhere where elements are `Comparable`; else once, at `new TreeSet<>(comparator)` | `equals` | the library's interface `Set<E>`, which `HashSet` and `TreeSet` implement | `<T extends Comparable<? super T>>` declared; nothing written at a call | a `Comparator` given to the set |
| Elm | nowhere; elements are `comparable` | `==` | no second representation | `comparable` only | no second order |

In `largest.ern`, `largest`, `largestOf` and `sorted` declare `needs a.compare` once each, and no call writes an order. In `members.ern`, `sum` declares `needs a.+` once and serves `Int` and `Float`, and `Date` gets its order from two words. In `sets.ern`, `main` writes no order and `==` once, and `unique` declares the requirement while its call writes nothing. In `common.ern`, `common` writes `operations.` four times over an annotated parameter, and the program declares `Operations` in two lines and fills it in two. A record filled by hand, `Num` below, takes one line a type, and every function over it takes `num` and writes `num.` before each operation.

In Rust, `unique` is `fn unique<T: Ord>(list: Vec<T>) -> Vec<T>`, its bound declared and supplied at each call as the requirement is; `Date` is `#[derive(PartialEq, Eq, PartialOrd, Ord)]` over a struct of three fields, four traits for one order, since `==` is a trait too; and `common` is a trait of three methods the program declares, with an `impl` for `HashSet<T>` and one for `BTreeSet<T>`, each writing each method. The derive is the same as `derives compare`: it orders by variant in declaration order and then by field from left to right, bounds the type's parameters, and is an error at a field whose type has no order. Rust bounds every parameter of the type, reached by the comparison or not; `derives compare` requires only those it reaches.

In Java, `unique` is `<T extends Comparable<? super T>> List<T> unique(List<T> list)`, its bound declared and met at each call as the requirement is. `Date` is a record that implements `Comparable<Date>` and writes `compareTo`, or an order built with `Comparator.comparing(...).thenComparing(...)`; nothing derives it. `common` needs no declaration of its own: `Set<E>` is the library's interface, `HashSet` and `TreeSet` implement it, `retainAll` is a method the set object carries, and the caller chooses the representation by passing a constructor, `HashSet::new` or `TreeSet::new`. A `TreeSet`'s order belongs to the set object, its elements' natural order or a `Comparator`'s, so two sets in different orders have one type and meet in `addAll`, each keeping its own order. Java's documentation asks that an order be consistent with `equals`, and checks it no more than Ernest checks the same promise.

An interface is the nearest relative of what this note describes, and the difference is where the operations live. A Java object carries its methods, so a value and its operations travel together and a call dispatches on the value. An operations record travels beside the data: the function takes it as a parameter, and the representation stays visible as the type parameter `s`. The record of closures, `Shape` and `Bag` above, is the Java shape: its functions close over one value, so each value carries its operations, values of different representations share a list, and no operation sees inside two of them.

**Pros.**

- Against OCaml and Standard ML: no functor application and no module per element type, one `OrderedSet` for every element type, and a record declared and filled in five lines where a functor is a module. The guarantee is the same: one order per type.
- Against Haskell: the same program on the element side, and no class declaration for code over two representations. Nothing is inferred and nothing is declared an instance: the only thing resolved is a member the type already has, nothing is written at a call, and every signature on the page says what its type must have.
- Against Rust: the same discipline, a requirement declared and never inferred, in one word where an order derived in Rust names four traits; a representation's operations enter the record by name from its module, `Operations(..Set)`, where an `impl` writes each method; and the derive requires only the parameters the comparison reaches, where Rust bounds them all.
- Against Java: an order belongs to the element type, so two sets in different orders are different types and the compiler refuses their union, where two `TreeSet`s of one type may hold different orders; a set is plain data with structural `==`, which can key a map and be sent to another node; an existing module enters a record after the fact, `Operations(..Set)`, where a class names the interfaces it implements when it is written; an order is derived in two words; and a function is generic over `+`, which no Java interface abstracts.
- Against Elm: a user type has an order, `fn Date.compare`; a second representation exists; a second order is a wrapper type.

**Cons.**

- Against Haskell: every generic function that needs the order declares `needs a.compare`, where Haskell infers `Ord a =>`; and one argument is passed unseen along the declared requirements, where the language's rule on operators had allowed none.
- Against Rust: a bound names any trait, the program's own among them, so a `zero` or a `hash` is a bound where Ernest passes a parameter or fills a field; a trait's method is dispatched statically, one copy of the code per type, where a field use is one indirect call and a requirement one argument passed; a bound stands once on an `impl` block for every method in it, where each function of `OrderedSet` that needs the order writes `needs a.compare`; and Rust orders `Option`, tuples and `Vec` by their contents, where Ernest's `Optional`, tuples and lists have no order.
- Against OCaml and Standard ML: the member is the only order a type has, so a reversed set of `Int` is a wrapper type where OCaml applies the functor again; and the requirement and the fill are two forms, where a functor is one.
- Against Java: the operations are passed and named, `operations.toList(...)`, where a method call dispatches on the object and nothing is passed; values of different representations in one list are Java's ordinary case and here need the record of closures; the library gives no ready interface for sets, so the program declares its record; a second order is a wrapper type where Java passes a `Comparator`; and a record has no default methods and no inheritance from another.
- Against Elm: two forms where Elm has none, and an order declared per user type where Elm has no such type at all.
- Against all: a record over the whole vocabulary is twelve fields the program writes, and `filter` and `foldLeft` cannot be fields. The requirement reaches the members and `show` only; a record that needs a `zero` or a `hash` fills them by name from a module and can name neither in a requirement.
