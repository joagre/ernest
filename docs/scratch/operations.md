# Operations records

*A design note for a reader outside the project. It describes how Ernest lets code be written once over several representations of one type, and how a generic function reaches an operation of the type it is generic in, without type classes. The design is built: the ordered set and the ordered map are in the standard library, and the programs shown here compile and print what this note says they print. Revised 2026-10-03.*

## Background

Ernest is a small functional language with two concepts: pure functions, typed by Hindley-Milner inference, and processes with typed mailboxes. This note stays on the function side. A few facts about the language carry the design.

- A type's operations are ordinary functions in its module, called through the module's name: `Set.put(set, x)`, `List.sort(list, compare)`. A file names its module: `ordered_set.ern` is the module `OrderedSet`.
- A handful of operations are *members* of a type: `compare`, `negate` and the arithmetic operators `+`, `-`, `*`, `/`, `%` and `<>`. A user type declares a member in its own module, with the type's name as prefix: `fn Date.compare(a : Date, b : Date) : Ordering = ...`. `Ordering` is `Less`, `Equal` or `Greater`.
- The compiler resolves an operator by the type of its operand. `a + b` is `Int.+` when `a` is an `Int` and `Money.+` when `a` is a `Money`. `x < y` is `T.compare(x, y) == Less` for the operand's type `T`. The operand's type must be known once the enclosing definition has been inferred. Before this design, an operator on a bare type variable was a type error.
- `==` is built in and structural on every value that holds no function and no process address. It is not a member and cannot be redefined.
- There is no type class, no implicit argument and no overloading beyond the members. A type has at most one `compare`, one `+`, and so on.
- In the code below, `#(a, b)` is a tuple, `::` is cons, `abstract type` hides a type's constructor outside its module, and `with e` in a function type is an effect variable: the function may do whatever its callback does.

## The problem

The standard library had one set, `Set`, a hash set. Two needs came together.

1. **A set in order.** `OrderedSet` keeps its elements in the order of their type's `compare`. Every function of it that touches the order needs the element type's `compare`, and a value carries no operations with it, so the type must say which: a set of `Int` needs `Int.compare`, a set of `Date` needs `Date.compare`.
2. **Code written once over both sets.** A function that builds two sets and intersects them should be written once and run on either representation, with the caller choosing which.

Beside the sets, the same question comes up for numbers. A `total` over a list of `Int`, of `Float` or of `Money` needs the element type's `+`.

The usual answers are type classes, as in Haskell; functors, as in OCaml and Standard ML; or passing the operation as a parameter at every call. Ernest takes a fourth way, built from three small forms.

## Goals

1. Each type's operations are called through its module: `Set.put(s, x)`, `OrderedSet.put(s, x)`, and the ordered set's own `OrderedSet.min(s)`.
2. Generic code is an ordinary function over a record, and the caller chooses the representation.
3. An ordered set is data: it has `==`, can key a `Map`, and can be sent to another node.
4. Sets in different orders cannot be combined.
5. Errors name what the user wrote: a function, a type, a record.
6. A program changes a set's representation by renaming it; no call site changes otherwise.

## The three forms

- A **requirement**: a function declaration may end in `needs a.compare`, naming a member of a type it is generic in.
- A **fill**: a record construction may take its fields from a module, `Ops(..Set)`.
- A **derived order**: a type declaration may end in `derives compare`.

### The requirement

**What it says.** A function that needs a member of a type it is generic in says so after its result type:

```ernest-fragment
fn fromList(list : List(a)) : Set(a) needs a.compare = ...
```

`needs a.compare` names the member `compare` of whatever type `a` stands for. `needs a.+` names an operator, and a requirement names several with commas, `needs a.+, a.*`.

**What it licenses in the body.** Under the requirement, `a.compare` in the body is that member, a value of type `(a, a) -> Ordering`. An operator on `a` resolves to it just as it would on a known type: `x < y` goes through `a.compare`, `x + y` through `a.+`. The member has its shape at `a`, with `a` for its result: `a.negate` has type `(a) -> a` and `a.+` has type `(a, a) -> a`. So a function that needs `a.+` accepts a type whose `+` answers that type, and not one whose `+` answers something else.

**What a call writes: nothing.** The compiler supplies the member once it has inferred the enclosing definition and knows what `a` was instantiated to. There are three cases.

- `a` is a known type. The compiler supplies that type's member. `OrderedSet.fromList([3, 1, 3])` is `fromList` with `Int.compare`.
- `a` is a type variable of the enclosing function's own signature. That function's own requirement supplies it. `unique` below declares `needs a.compare`, and its call of `fromList` passes on the `compare` that `unique` was given:

```ernest-fragment
fn unique(list : List(a)) : List(a) needs a.compare =
    OrderedSet.toList(OrderedSet.fromList(list))
```

- `a` is a type built from a variable, `List(b)`. It is read as a known type whose member is looked for, and refused where it has none.

Members supply members. A member with a requirement of its own, such as the derived `Pair.compare` below, is supplied with that requirement resolved at its type by the same rule: at `Pair(Int, String)` with `Int.compare` and `String.compare`, and at `Pair(a, b)` with the enclosing function's requirement. A function with a requirement used as a value is the function with its member supplied by the same rule: under `needs a.compare`, `List.foldLeft(list, empty, put)` passes `put` together with that `compare`.

**The errors.** Each names what the program wrote and, where there is one, what it must write instead.

- A call where the type is a variable and the enclosing function declares no requirement for it:
  `fromList needs a.compare, which unique does not declare; add needs a.compare`
- A call at a known type without the member:
  `fromList needs List(Int).compare, and List(Int) has no compare`
- A call at a type whose member has another shape:
  `total needs Vec.+ : (Vec, Vec) -> Vec, and Vec.+ answers Float`
- `a.compare` or `<` on a type variable in a body without the requirement is a type error, as it was before.

**Where a requirement is in force.** The requirement in force in a body is the enclosing `fn` declaration's, for the type variables of its signature, wherever the use stands: inside a lambda, and inside a lambda bound by `let`, included. One case needs care. A `let`-bound lambda whose own type variable is not the signature's is generalized on its own, before any call ties it to the signature, so an unannotated `let build = fn(xs) = OrderedSet.fromList(xs)` meets the first error above. A `fn` declared in a block declares its own requirement for its own variables and shares the enclosing one for the variables they share. A top-level `let` declares no requirement, so `let f = OrderedSet.fromList` is refused with a message that says what to write instead: `fromList needs a.compare; a let cannot declare it, so write a fn with the requirement`.

**What a requirement may name.** The variable is a type variable of the signature that stands in a value position. `needs e.compare` on an effect variable, and `needs b.compare` where `b` is nowhere in the signature, are errors at the declaration: `b is no type variable of the signature`. A variable that stands only in the result type may carry one, since the instantiation is read once the enclosing definition is inferred. Under a requirement on `a`, no parameter, `let` or pattern variable may be named `a`, so that `a.compare` reads one way.

A requirement names a member and nothing else: `compare`, `negate`, an operator, and beside them `show`. `show` is no member of a type but the standard library's `Io.show`, which renders a value as text, and `Io.debug`, which prints one to standard error and returns it; both work from a description of the value's type that the compiler supplies. Under `needs a.show`, either may be applied in the body to a value whose type is `a` itself, and the compiler supplies the description as it does at a known type. A value of a type that merely contains `a`, a `List(a)`, cannot be shown this way, since its description would have to be composed at run time.

`needs a.zero` and `needs a.hash` are errors at the declaration: `zero is not a member: a requirement names compare, negate, an operator or show`. A program declares no member beyond these. What a generic function needs beyond the members, a `zero` or a `hash`, it takes as a parameter or as a field of a record the program fills, described below.

A type has one member of each name, so a requirement has one value at a type. A second order, sum or product for a type exists only through a second type. A requirement is never inferred: a function has the requirement it writes and no other, and a call that needs one the enclosing function does not declare is an error, never a silently widened signature.

**Parameter or requirement.** A function takes a member as a parameter where any function of its type may be given, `List.sort(list, compare)`. It declares a requirement where the type's own member is meant. A helper of a function with a requirement declares the requirement itself rather than taking the member as a parameter.

### The ordered set

**It is data.** `OrderedSet.Set(a)` holds its elements and nothing else; its order is its element type's `compare`. `==` on two sets is structural, a set keys a `Map`, and a set is sent to another node as any value is. Of its functions, `fromList`, `contains`, `put`, `remove`, `union`, `intersection`, `difference` and `isSubset` need `a.compare`; `map` and `filterMap` need their result's, `b.compare`; `empty`, `size`, `isEmpty`, `toList`, `min`, `max`, `filter`, `foldLeft`, `foreach`, `any`, `all` and `find` need none.

**An order belongs to an element type.** A type's order is its `compare`, and no set of that type is in another order. A second order on one type is a second type with its own `compare`: `type Descending = Descending(Int)` with `fn Descending.compare`. Two sets in different orders have different types and cannot meet: `OrderedSet.union(up, down)` with `down : OrderedSet.Set(Descending)` is refused. That is goal 4.

**`put` keeps the element already there** where `compare` says `Equal`.

**The representation is a sorted list**, one shape per set, so that `==` is structural. `put`, `contains` and `remove` are linear in the set's size; `fromList` is a stable sort and one pass, `n log n`, and `map` and `filterMap` cost that beside the function's; `union`, `intersection`, `difference` and `isSubset` are linear in the two sizes. A representation of another shape must also have one shape per set. It would replace the list when a program's measurement shows the linear cost matters, with no change a program can see.

**Where it lives.** `OrderedSet` is the standard library's `ordered_set.ern`. Its type is `OrderedSet.Set(a)`; inside the file, `Set` is this type and shadows the prelude's hash set. A set carried into the other representation goes through that representation's `fromList` of its `toList`. The hash set, `Set`, does not change.

### Operations records and the fill

**The record is the program's.** Code written once over several representations takes a record the program declares, holding the operations it uses. Each field's type names only the record's own parameters:

```ernest-fragment
type Ops(s, a) = Ops(fromList : (List(a)) -> s, intersection : (s, s) -> s, toList : (s) -> List(a))
```

The program fills it from each representation's module, one binding per representation and element type, or one function per representation generic in the element type, shown below, and passes it:

```ernest-fragment
let ordered : Ops(OrderedSet.Set(Int), Int) = Ops(..OrderedSet)

fn common(list : List(a), other : List(a), ops : Ops(s, a)) : List(a) =
    ops.toList(ops.intersection(ops.fromList(list), ops.fromList(other)))
```

Selecting a field, `ops.toList`, is ordinary field selection, resolved against the parameter's annotated type. The standard library declares no such record and no generic function over one: which operations a program needs is the program's to say. An operation whose callback has an effect variable, or whose accumulator has a type of its own, `filter` and `foldLeft` among them, cannot be a field, because the field's type would need a variable the record does not have. Generic code that needs one goes through `toList` and `List`.

**The fill.** In a record construction, `..` may name a module in place of an expression. `Ops(..Set)` fills each field not given beside it from the declaration of that field's name in the module, at the field's type. `Ops(..OrderedSet, toList = mine)` takes the field given and fills the rest. A declaration with a requirement is filled with its member supplied at the field's type, which the record's type must fix: `Ops(OrderedSet.Set(Int), Int)` fixes `a` to `Int`, so `fromList` is filled with `Int.compare`. Where the record's type leaves that variable open, the fill is an error naming the field and the variable: `fromList needs a.compare, and the record's type leaves a undetermined`.

A type variable of the enclosing function's signature that its requirement names is not open. So a function with a requirement returns the record generic in the element type, and one fill serves every element type with an order:

```ernest-fragment
fn orderedOps() : Ops(OrderedSet.Set(a), a) needs a.compare =
    Ops(..OrderedSet)
```

`common([4, 2, 3], [3, 4, 5], orderedOps())` is `[3, 4]`, and `common(["b", "a"], ["a", "c"], orderedOps())` is `["a"]`. The fill is supplied from the requirement as a call is.

The name after `..` is a module where it is a qualified name made of type names alone that names no constructor or binding in scope, and an expression otherwise, as in the record update `Snapshot(..old, seen = s)`. A module may stand alone after `..`; an expression keeps the rule that at least one field follows it. A field with no declaration of its name in the module, or one whose type does not fit the field's, is an error naming the field and the module: `Ops(..Set) lacks isSubset: Set has no isSubset`.

**A list that mixes representations** needs a second record type, one that hides `s`: its functions close over one set, and its `put` returns another such record. It has no operation on two sets and no `==`. The design does not try to make one record serve both uses.

### The derived order

A type declaration may end in `derives compare`:

```ernest-fragment
type Date = Date(year : Int, month : Int, day : Int) derives compare
```

The type gains the member `compare`, which orders two values by constructor in declaration order and then by field from left to right, each field by its type's `compare`. A field whose type has no `compare` is an error at the declaration: `Date.compare cannot be derived: Optional(Int) has no compare`. The member appears on the type's documentation page like any member. For a type with parameters, the derived member declares a requirement for each parameter the comparison reaches: `type Pair(a, b) = Pair(first : a, second : b) derives compare` gives `Pair.compare` the requirement `needs a.compare, b.compare`. `derives` names `compare` and nothing else.

### The ordered map

`OrderedMap`, the standard library's `ordered_map.ern`, is specified as the ordered set is. Its type `OrderedMap.Map(k, v)` keeps its keys in the order of their type's `compare`, with the same vocabulary as the hash map. Each function that needs the keys' order declares `needs k.compare`; the map is data, a sorted list of pairs with one shape per map, and `==` is structural. `put` replaces the value already there, as a map's `put` does.

## The code

`ordered_set.ern` is the ordered set. Shown are its type, `empty`, `fromList` with its pass, `contains`, `put`, `map`, `filter` and `union`; the rest of the vocabulary is written as these are.

```ernest
export abstract type Set(a) = Set(List(a))

export let empty : Set(a) = Set([])

export fn fromList(list : List(a)) : Set(a) needs a.compare =
    Set(firstOfEach(List.sort(list, a.compare)))

// The first of each run the order calls `Equal` in a sorted list. The sort
// is stable, so the list's earlier occurrence comes first and is the one
// kept, as `put` keeps the element already there.
fn firstOfEach(sorted : List(a)) : List(a) needs a.compare =
    match sorted {
        x :: y :: rest -> if a.compare(x, y) == Equal then
            firstOfEach(x :: rest)
        else
            x :: firstOfEach(y :: rest)
      | _ -> sorted
    }

export fn contains(Set(list) : Set(a), x : a) : Bool needs a.compare =
    has(list, x)

fn has(list : List(a), x : a) : Bool needs a.compare =
    match list {
        [] -> false
      | y :: rest -> match a.compare(x, y) {
            Less -> false
          | Equal -> true
          | Greater -> has(rest, x)
        }
    }

export fn put(Set(list) : Set(a), x : a) : Set(a) needs a.compare =
    Set(inserted(list, x))

fn inserted(list : List(a), x : a) : List(a) needs a.compare =
    match list {
        [] -> [x]
      | y :: rest -> match a.compare(x, y) {
            Less -> x :: list
          | Equal -> list
          | Greater -> y :: inserted(rest, x)
        }
    }

export fn map(Set(list) : Set(a), f : (a) -> b with e) : Set(b) with e needs b.compare =
    fromList(List.map(list, f))

export fn filter(Set(list) : Set(a), keep : (a) -> Bool with e) : Set(a) with e =
    Set(List.filter(list, keep))

export fn union(Set(list) : Set(a), Set(other) : Set(a)) : Set(a) needs a.compare =
    Set(merged(list, other))

fn merged(list : List(a), other : List(a)) : List(a) needs a.compare =
    match #(list, other) {
        #([], _) -> other
      | #(_, []) -> list
      | #(x :: rest, y :: others) -> match a.compare(x, y) {
            Less -> x :: merged(rest, other)
          | Equal -> x :: merged(rest, others)
          | Greater -> y :: merged(list, others)
        }
    }
```

`usage.ern` is a program over both sets, a type that derives its order, a map in order, and printing in generic code. No line names an order; `unique` and `shown`, both generic, declare what they need; and `Ops` is the record `common` needs, declared there and filled from each representation at `Int`.

```ernest
type Date = Date(year : Int, month : Int, day : Int) derives compare

type Ops(s, a) = Ops(fromList : (List(a)) -> s, intersection : (s, s) -> s, toList : (s) -> List(a))

let hashed : Ops(Set(Int), Int) = Ops(..Set)

let ordered : Ops(OrderedSet.Set(Int), Int) = Ops(..OrderedSet)

fn unique(list : List(a)) : List(a) needs a.compare =
    OrderedSet.toList(OrderedSet.fromList(list))

fn shown(list : List(a)) : Unit with m needs a.show =
    List.foreach(list, fn(x) = Io.println(Io.show(x)))

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

It prints:

```console
[1, 2, 3]
Some(1)
true
[1, 3]
true
["a", "b"]
Some(Date(year = 2025, month = 1, day = 1))
Date(year = 2025, month = 1, day = 1)
Date(year = 2026, month = 10, day = 2)
["al", "bo"]
Some(1)
[3, 4]
2
```

Two sets built in different orders are `==`; `map` makes a set of the results' type; `unique` and `shown` write nothing at their calls; `Date` is ordered by year, month and day from its declaration; and `common` is written once for both representations. Without its requirement, `unique` is refused:

```ernest-rejected
fn unique(list : List(a)) : List(a) =
    OrderedSet.toList(OrderedSet.fromList(list))
```

```console
$ ern build --short-errors usage.ern
usage.ern:17:23: fromList needs a.compare, which unique does not declare; add needs a.compare
```

`mixed.ern` is a program goal 4 refuses:

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

Two programs beyond sets test the forms where no set is involved. `numeric.ern` writes generic numeric functions over the requirement `needs a.+`, used at `Int`, at `Float`, and at a type with a `+` of its own. `sum` needs a zero as well, which is no member, so its caller passes one.

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

export fn main() : Unit with Never = {
    Io.println(Io.show(total([1, 2, 3])));
    Io.println(Io.show(total([1.5, 2.5])));
    Io.println(Io.show(total([Money(1), Money(2)])));
    Io.println(Int.toString(sum([1, 2, 3], 0)));
    Io.println(Io.show(doubled([Money(2)])));
    Io.println(Io.show(total(doubled([1, 2]))))
}
```

It prints `Some(6)`, `Some(4.0)`, `Some(Money(3))`, `6`, `[Money(4)]` and `Some(6)`. Declaring the zero as a requirement is refused:

```ernest-rejected
fn sum(list : List(a)) : a needs a.zero, a.+ =
    List.foldLeft(list, a.zero, a.+)
```

```console
$ ern build --short-errors numeric.ern
numeric.ern:16:34: zero is not a member: a requirement names compare, negate, an operator or show
```

`num.ern` writes the same functions over a record the program fills by hand, `Num`. `zero` and `one` are no members and `+` is no field name, so no fill applies. Each type is one line, and generic code passes the record.

```ernest
type Num(a) = Num(zero : a, one : a, add : (a, a) -> a, mul : (a, a) -> a)

let ints : Num(Int) = Num(zero = 0, one = 1, add = Int.+, mul = Int.*)

fn sum(list : List(a), num : Num(a)) : a =
    List.foldLeft(list, num.zero, num.add)

fn sumOfSquares(list : List(a), num : Num(a)) : a =
    sum(List.map(list, fn(x) = num.mul(x, x)), num)
```

Its `main` prints `6`, `3.0` and `14`.

`ordered_map.ern` is the ordered map. Shown are its type, `empty`, `fromList`, `get`, `put`, `map`, which keeps the keys and needs nothing, `merge` and `mergeWith`; the rest of the vocabulary is written as these are.

```ernest
export abstract type Map(k, v) = Map(List(#(k, v)))

export let empty : Map(k, v) = Map([])

export fn fromList(pairs : List(#(k, v))) : Map(k, v) needs k.compare =
    Map(lastOfEach(List.sort(pairs, fn(#(key, _), #(other, _)) = k.compare(key, other))))

// The last of each run of pairs whose keys the order calls `Equal`, in a
// sorted list. The sort is stable, so the list's later pair comes last
// and is the one kept, as `put` replaces the value already there.
fn lastOfEach(sorted : List(#(k, v))) : List(#(k, v)) needs k.compare =
    match sorted {
        #(key, value) :: #(other, later) :: rest -> if k.compare(key, other) == Equal then
            lastOfEach(#(other, later) :: rest)
        else
            #(key, value) :: lastOfEach(#(other, later) :: rest)
      | _ -> sorted
    }

export fn get(Map(pairs) : Map(k, v), key : k) : Optional(v) needs k.compare =
    found(pairs, key)

fn found(pairs : List(#(k, v)), key : k) : Optional(v) needs k.compare =
    match pairs {
        [] -> None
      | #(other, value) :: rest -> match k.compare(key, other) {
            Less -> None
          | Equal -> Some(value)
          | Greater -> found(rest, key)
        }
    }

export fn put(Map(pairs) : Map(k, v), key : k, value : v) : Map(k, v) needs k.compare =
    Map(inserted(pairs, key, value))

fn inserted(pairs : List(#(k, v)), key : k, value : v) : List(#(k, v)) needs k.compare =
    match pairs {
        [] -> [#(key, value)]
      | #(other, kept) :: rest -> match k.compare(key, other) {
            Less -> #(key, value) :: pairs
          | Equal -> #(key, value) :: rest
          | Greater -> #(other, kept) :: inserted(rest, key, value)
        }
    }

export fn map(Map(pairs) : Map(k, v), f : (k, v) -> w with e) : Map(k, w) with e =
    Map(List.map(pairs, fn(#(key, value)) = #(key, f(key, value))))

export fn merge(map : Map(k, v), other : Map(k, v)) : Map(k, v) needs k.compare =
    mergeWith(map, other, fn(_, _, value) = value)

export fn mergeWith(Map(pairs) : Map(k, v),
                    Map(others) : Map(k, v),
                    f : (k, v, v) -> v with e) : Map(k, v) with e needs k.compare =
    Map(mergedWith(pairs, others, f))

fn mergedWith(pairs : List(#(k, v)),
              others : List(#(k, v)),
              f : (k, v, v) -> v with e) : List(#(k, v)) with e needs k.compare =
    match #(pairs, others) {
        #([], _) -> others
      | #(_, []) -> pairs
      | #(#(key, mine) :: rest, #(theirs, value) :: more) -> match k.compare(key, theirs) {
            Less -> #(key, mine) :: mergedWith(rest, others, f)
          | Equal -> #(key, f(key, mine, value)) :: mergedWith(rest, more, f)
          | Greater -> #(theirs, value) :: mergedWith(pairs, more, f)
        }
    }
```

The hash set's module does not change. The documentation tool writes a requirement as declared, `OrderedSet.fromList : (List(a)) -> OrderedSet.Set(a) needs a.compare`, and the shell shows it the same way.

## How it fits the type system

The type system is Hindley-Milner with let-polymorphism, and the design stays inside it. Every construct above but the three forms is one the language already had.

- **The requirement adds nothing to the function's type scheme.** It licenses `a.compare` and the operators on `a` in the body, each with the member's shape at `a`. At a call, the checker reads what `a` was instantiated to once the enclosing definition is inferred, as it already reads an operator's operand type. A known type's member becomes an argument the code generator adds after the written ones. A type variable is met by the enclosing function's requirement, whose own added argument is passed along. A member with a requirement of its own is supplied with that requirement resolved first, so the added argument may be a closure over arguments added in turn. Otherwise the call is an error. Nothing is inferred: a requirement is written, or the call is refused. A declaration's requirement is recorded in the module's compiled interface and shown after its type.
- **The record is an ordinary sum type** with one constructor and named fields, rank-1: every field's type names only `s` and `a`. A field for `foldLeft` is refused with `type variable b is not a parameter of the type`.
- **Selection.** `ops.toList` in `common` is resolved as an operator's operand is: the operand's type constructor must be known when the enclosing definition is inferred, so the record parameter is annotated. Unannotated, it is refused with `the type whose field toList is read is not determined; annotate it`.
- **Code written once.** `common` is a let-polymorphic function over the record, with a principal type, instantiated at each representation.
- **The fill is checked as the literal it stands for.** Each field not given is the declaration of its name at a fresh instance of its scheme, unified with the field's type. A function that applies `==` to a value of a type variable carries an inferred equality constraint on that variable, and the constraints travel through a fill as through a literal: `hashed : Ops(Set(Int), Int)` carries the hash set's constraint on its elements, met at `Int`.
- **The bindings.** `let ordered : Ops(OrderedSet.Set(Int), Int) = Ops(..OrderedSet)` has a type with no variable in it. A top-level `let` runs its initializer once, and this one is a pure construction.
- **Goal 4** holds because `OrderedSet.Set(Int)` and `OrderedSet.Set(Descending)` do not unify: two declared types are distinct by name.
- **Equality.** `==` on two ordered sets is structural over their sorted lists and needs the element's equality at that application. A set whose elements hold functions can be built and used, and `==` on two of them is refused there, as `==` on the functions would be.
- **The invariant.** The sorted list is the module's alone; `abstract type` keeps the constructor inside the file.

**What the types do not guarantee**, stated as the program's promise: `compare` is a total order, and where the element type has `==`, says `Equal` only where `==` holds. Nothing checks either. Where the element type has no `==`, an ordered set holds one element per class of `Equal`, and `put` keeps the element already there. A `compare` that is not transitive breaks the order: `contains` answers wrongly and duplicates stay. One that says `Equal` where `==` does not makes `==` on two sets depend on the order of insertion.

After a hot code upgrade or a reload in the shell, a set built under the old `T.compare` is read under the new, and a changed order misorders it. A set sent to a node whose `T.compare` differs is read under that node's. What happens where two versions of a type meet is a question for the distribution design, and is not decided here.

## What it costs

In the language: two reserved words, `needs` and `derives`; a clause at the end of a function declaration; `a.member` as an expression, where `a` is a type variable under a requirement; `derives compare` at the end of a type declaration; and a module name after `..` in a record construction. The type checker gained the supply of members at calls and at fills, the code generator the added argument, and the compiled interface a record of each declaration's requirement. One sentence of the language's rule on operators changed. It had said that an operator carries no argument the program has not declared. It now says: on a known type none, and on a type variable the member a requirement names, which a call supplies without writing it.

At run time a requirement's member is an ordinary argument, and a field use is one indirect call, the host's own application of a function value. The ordered set's own costs are the sorted list's.

## Compared with OCaml, Standard ML, Haskell, Rust and Elm

`usage.ern` against the same program in the five languages, in what a program writes:

| | The order | Equality | Code written once over two representations | Generic over the element | A second order |
|---|---|---|---|---|---|
| Ernest | nowhere; the member is found | `==` | a record the program declares, `Ops(..Set)` and `Ops(..OrderedSet)` | `needs a.compare` declared; nothing written at a call | a wrapper type |
| OCaml | once, at `Set.Make(Int)` | `IntSet.equal` | a first-class module, its parameter annotated | a functor, or a first-class module passed | a second functor application |
| Standard ML | once, at the functor application | `IntSet.equal` | a functor over the representation's structure | a functor | a second functor application |
| Haskell | nowhere; `Ord` is found | `==` | a class the program declares, an instance per representation | `Ord a =>`, inferred | a `newtype` |
| Rust | nowhere; `Ord` is found | `==` | a trait the program declares, an `impl` per representation | `T: Ord` declared; nothing written at a call | a wrapper type, `Reverse<T>` in the standard library |
| Elm | nowhere; elements are `comparable` | `==` | no second representation | `comparable` only | no second order |

In `usage.ern`, `main` writes no order and `==` once; `unique` declares the requirement and its call writes nothing; `common` writes `ops.` four times over an annotated parameter; the program declares `Ops` in three lines and fills it in two. In `numeric.ern`, three generic functions declare `needs a.+` once each, their calls write nothing, and their bodies write `+` or `a.+`; `sum`'s zero is passed beside the `+` that is found. In `num.ern`, each type fills `Num` in one line, and every generic function takes `num` and writes `num.` before each operation.

In Rust, `unique` is `fn unique<T: Ord>(list: Vec<T>) -> Vec<T>`, its bound declared and supplied at each call as the requirement is; `Date` is `#[derive(PartialEq, Eq, PartialOrd, Ord)]` over a struct of three fields, four traits for one order, since `==` is a trait too; and `common` is a trait of three methods the program declares, with an `impl` for `HashSet<T>` and one for `BTreeSet<T>`, each writing each method. The derive is the same as `derives compare`: it orders by variant in declaration order and then by field from left to right, bounds the type's parameters, and is an error at a field whose type has no order. Rust bounds every parameter of the type, reached by the comparison or not; `derives compare` requires only those it reaches.

**Pros.**

- Against OCaml and Standard ML: no functor application and no module per element type, one `OrderedSet` for every element type, and a record declared and filled in five lines where a functor is a module. The guarantee is the same: one order per type.
- Against Haskell: the same program on the element side, and no class declaration for code over two representations. Nothing is inferred and nothing is declared an instance: the only thing resolved is a member the type already has, nothing is written at a call, and every signature on the page says what its type must have.
- Against Rust: the same discipline, a requirement declared and never inferred, in one word where an order derived in Rust names four traits; a representation's operations enter the record by name from its module, `Ops(..Set)`, where an `impl` writes each method; and the derive requires only the parameters the comparison reaches, where Rust bounds them all.
- Against Elm: a user type has an order, `fn Date.compare`; a second representation exists; a second order is a wrapper type.

**Cons.**

- Against Haskell: every generic function that needs the order declares `needs a.compare`, where Haskell infers `Ord a =>`; and one argument is passed unseen along the declared requirements, where the language's rule on operators had allowed none.
- Against Rust: a bound names any trait, the program's own among them, so a `zero` or a `hash` is a bound where Ernest passes a parameter or fills a field; a trait's method is dispatched statically, one copy of the code per type, where a field use is one indirect call and a requirement one argument passed; a bound stands once on an `impl` block for every method in it, where each function of `OrderedSet` that needs the order writes `needs a.compare`; and Rust orders `Option`, tuples and `Vec` by their contents, where Ernest's `Optional`, tuples and lists have no order.
- Against OCaml and Standard ML: the member is the only order a type has, so a reversed set of `Int` is a wrapper type where OCaml applies the functor again; and the requirement and the fill are two forms, where a functor is one.
- Against Elm: two forms where Elm has none, and an order declared per user type where Elm has no such type at all.
- Against all: a record over the whole vocabulary is twelve fields the program writes, and `filter` and `foldLeft` cannot be fields. The requirement reaches the members and `show` only; a record that needs a `zero` or a `hash` fills them by name from a module and can name neither in a requirement.
