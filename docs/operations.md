# Operations records

*The specification of code written once over several representations of one type. MVP 2.99b's item 5 builds it. The log's *Operations Records*, *Members, Operators, and No Hidden Argument*, *The Operations Note Rewritten*, *The Order Bound Once* and *MVP 2.99b's Questions, One by One* argue its earlier choices; the entry for the requirement clause, the fill and the set as data is item 5's to write. Revised 2026-10-02. The five files are whole under [`docs/operations/`](operations/), with their doc blocks, until item 5 moves the ordered set and the ordered map into the standard library. All use the requirement or the fill, forms the toolchain does not have, so none builds, and what they print and refuse is stated as expected; an earlier form of the ordered set, carrying its order, was built, run, formatted and rendered by `ern doc` on 2026-10-02 under stand-in names, with every doc example checked. The code here is excerpted from the files.*

Ernest has one set in its standard library, `Set`, a hash set. A second, `OrderedSet`, keeps its elements in the order of their type's `compare`. Code written once works on both through an *operations record*, a record the program declares of the operations it needs, filled from each representation's namespace. The § numbers cite Ernest's report.

## Requirements

1. Each type's operations are called through its module: `Set.put(s, x)`, `OrderedSet.put(s, x)`, and the ordered set's own `OrderedSet.min(s)`.
2. Generic code is an ordinary function over a record, and the caller chooses the representation.
3. An ordered set is data: it has `==`, can key a `Map`, and can be sent to another node.
4. Sets in different orders cannot be combined.
5. Errors name what the user wrote: a function, a type, a record.
6. A program changes a set's representation by renaming it; no call site changes otherwise.

## The specification

Three forms enter the language, a clause that names a member of a type, a record filled from a namespace, and a type that derives its order; *What changes in Ernest* lists the report's sections they touch. The rules:

1. **A function that needs a member of a type says so.** A clause after its result type, `needs a.compare`, names the member `compare` of the type `a` is (§4.8, §3.10); `needs a.+` names an operator, and a clause names several with commas, `needs a.+, a.*`. Under the clause, `a.compare` in the body is that member, and an operator on `a`, `x < y`, resolves to it as it resolves on a known type (§4.8). The member has its shape with `a` for its result: `a.compare` has the type `(a, a) -> Ordering`, `a.negate` the type `(a) -> a`, and an operator `a.+` the type `(a, a) -> a`. A call, or a fill (rule 7), at a type whose member has another result type is an error naming both: `total needs Vec.+ : (Vec, Vec) -> Vec, and Vec.+ answers Float`; generic code over an operation of another shape takes it as a parameter. A call writes nothing for it. Where `a` is a known type when the enclosing definition is inferred (§4.8), the compiler supplies that type's member: `OrderedSet.fromList([3, 1, 3])` is `fromList` with `Int.compare`. Where `a` is a type variable there, the enclosing function's own clause at that type supplies it: `fn unique(list : List(a)) : List(a) needs a.compare = OrderedSet.toList(OrderedSet.fromList(list))`. A function with a clause used as a value is the function with the member supplied, under the same rule, so `fromList` passes `put` to `List.foldLeft`. A call where the type is a variable and the enclosing function has no clause for it is an error naming both: `fromList needs a.compare, which unique does not declare; add needs a.compare`. So is `a.compare` or `<` on a variable in a body without the clause (§4.8), and so is a known type without the member, naming both: `fromList needs List(Int).compare, and List(Int) has no compare`. A lambda has no clause and uses its definition's (§4.8); a block `fn` may declare one. In a body under a clause, `a.compare` names the member where `a` is a type variable of the signature, and a definition with a clause has no binding named as one of its type variables. A function takes a member as a parameter where any function of its type may be given, `List.sort(list, compare)`, and declares the clause where the type's own member is meant; a helper of a function with a clause declares the clause and does not take the member.
2. **A requirement names a member of §4.8 and nothing else.** The members are `compare`, `negate` and the operators, each of one shape (§4.8), and beside them `show`, which is no member but E.1's `Io.show` and `Io.debug`: under `needs a.show` either may be applied to a value of `a` in the body, and the compiler supplies the type's descriptor as it does at a known type. `needs a.zero` and `needs a.hash` are errors at the declaration: `zero is not a member: a requirement names compare, negate, an operator or show (§4.8, E.1)`. A program declares no member beyond these (§4.8). A type has one member of each name, its own, so a requirement has one value at a type, and a second order, sum or product for a type exists only through a second type (rule 4). A requirement is never inferred: a function has the clause it writes and no other (§3.9), and a call that needs one the enclosing function does not declare is rule 1's error. What a record needs beyond the members and `show`, a `zero` or a `hash`, is a field the program fills (rule 7).
3. **An ordered set is data.** `OrderedSet.Set(a)` holds its elements and nothing else; its order is its element type's `compare`. `==` is structural (§3.10), a set keys a `Map`, and a set is sent as any value is. `fromList`, `contains`, `put`, `remove`, `union`, `intersection`, `difference` and `isSubset` need `a.compare`; `map` and `filterMap` need their result's, `b.compare`; `empty`, `size`, `isEmpty`, `toList`, `min`, `max`, `filter`, `foldLeft`, `foreach`, `any`, `all` and `find` need none.
4. **An order belongs to an element type.** A type's order is its `compare`, and no set of that type is in another. A second order on one type is a second type with its own `compare`: `type Descending = Descending(Int)` with `fn Descending.compare`. Two sets in different orders have different types and cannot meet: `OrderedSet.union(up, down)` with `down : OrderedSet.Set(Descending)` is refused.
5. **`put` keeps the element already there** where `compare` says `Equal`.
6. **The record is the program's.** Code written once over several representations takes a record the program declares, holding the operations it uses, each field of a type that names only the record's parameters (§3.9): `type Ops(s, a) = Ops(fromList : (List(a)) -> s, intersection : (s, s) -> s, toList : (s) -> List(a))`. The program fills it from each representation's namespace at an element type (rule 7), one binding per representation and element type, `let ordered : Ops(OrderedSet.Set(Int), Int) = Ops(..OrderedSet)`, and passes it, `common(list, other, ops)`. Selecting a field is ordinary selection, resolved against the parameter's annotated type (§3.5, §4.8). The library declares no record and no generic function over one (E.0 rule 4). An operation whose callback has an effect variable, or whose accumulator has a type of its own, `filter` and `foldLeft` among them, is no field; generic code that needs one goes through `toList` and `List`.
7. **A record is filled from a namespace.** In a record construction, `..` may name a namespace in place of an expression: `Ops(..Set)` fills each field not given beside it from the declaration of its name that the use site may name (§4.2), at the field's type. A declaration with a clause (rule 1) is filled with the member of the field's type supplied, which the record's type must fix; where it leaves that type a variable, the fill is an error naming the field and the variable, `fromList needs a.compare, and the record's type leaves a undetermined`. `Ops(..OrderedSet, toList = mine)` takes the field given and fills the rest. The name after `..` is an expression where a binding or a constructor of that name is in scope, and a namespace otherwise. A field with no declaration of its name in the namespace, or one whose type does not fit the field's, is an error naming the field and the namespace: `Ops(..Set) lacks isSubset: Set has no isSubset`.
8. **`OrderedSet` is `ordered_set.ern`** in the standard library, a file whose words joined by `_` name one namespace (§4.2, §11.1). Its type is `OrderedSet.Set(a)` (E.0 shape rule 7), which inside the file shadows the prelude's `Set` (§4.2). A set carried into another representation goes through that representation's `fromList` of its `toList`. `Set` does not change.
9. **The representation is a sorted list**, one shape per set, so that `==` is structural. `put`, `contains` and `remove` are linear in the set's size; `union`, `intersection`, `difference` and `isSubset` are linear in the two sizes. A representation of another shape needs one shape per set as well, and replaces the list when a program's measurement shows the linear cost matters, with no change a program can see.
10. **A list that mixes representations needs a second record type**, one that hides `s`: its functions close over one set, and its `put` returns another such record. It has no operation on two sets and no `==`.
11. **A type asks for the structural order.** A type declaration may end in `derives compare`: `type Date = Date(year : Int, month : Int, day : Int) derives compare`. The type gains the member `compare` (§4.8), which orders two values by constructor in declaration order and then by field from left to right, each by its type's `compare`. A field whose type has no `compare` is an error at the declaration: `Date.compare cannot be derived: Optional(Int) has no compare`. The member is written on the type's page as any member. For a type with parameters it declares `needs` for each parameter the comparison reaches: `type Pair(a, b) = Pair(a, b) derives compare` gives `Pair.compare` the clause `needs a.compare, b.compare`. `derives` names `compare` and nothing else.
12. **An ordered map is specified as the ordered set is.** `ordered_map.ern`, namespace `OrderedMap`, type `OrderedMap.Map(k, v)`, keeps its keys in the order of their type's `compare`, with E.0 rule 2's vocabulary for a map. Each function that needs the keys' order declares `needs k.compare`; the map is data, a sorted list of pairs with one shape per map, and `==` is structural. The file is [`ordered_map.ern`](operations/ordered_map.ern).

## The files

[`ordered_set.ern`](operations/ordered_set.ern) is the ordered set. Shown are its type, `empty`, `fromList`, `contains`, `put`, `map`, `filter` and `union`; the rest of the vocabulary is written as these are, and the file holds it whole.

```ernest
export abstract type Set(a) = Set(List(a))

export let empty : Set(a) = Set([])

export fn fromList(list : List(a)) : Set(a) needs a.compare =
    List.foldLeft(list, empty, put)

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

[`usage.ern`](operations/usage.ern) is a program over both sets, a type that derives its order, a map in order, and printing in generic code. No line names an order; `unique` and `shown`, generic, declare what they need; and `Ops` is the record `common` needs, declared there and filled from each representation at `Int`.

```ernest
type Date = Date(year : Int, month : Int, day : Int) derives compare

type Ops(s, a) =
    Ops(fromList : (List(a)) -> s,
        intersection : (s, s) -> s,
        toList : (s) -> List(a))

let hashed : Ops(Set(Int), Int) = Ops(..Set)

let ordered : Ops(OrderedSet.Set(Int), Int) = Ops(..OrderedSet)

fn unique(list : List(a)) : List(a) needs a.compare =
    OrderedSet.toList(OrderedSet.fromList(list))

fn shown(list : List(a)) : Unit needs a.show =
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
    let dates = OrderedSet.fromList([Date(2026, 10, 2), Date(2025, 1, 1)]);
    Io.println(Io.show(OrderedSet.min(dates)));
    shown(OrderedSet.toList(dates));
    let ages = OrderedMap.fromList([#("bo", 42), #("al", 7)]);
    Io.println(Io.show(OrderedMap.keys(ages)));
    Io.println(Io.show(OrderedMap.get(OrderedMap.put(ages, "cy", 1), "cy")));
    Io.println(Io.show(common([4, 2, 3], [3, 4, 5], ordered)));
    Io.println(Int.toString(List.size(common([4, 2, 3], [3, 4, 5], hashed))))
}
```

It prints `[1, 2, 3]`, `Some(1)`, `true`, `[1, 3]`, `true`, `["a", "b"]`, `Some(Date(year = 2025, month = 1, day = 1))`, the two dates on a line each in order, `["al", "bo"]`, `Some(1)`, `[3, 4]` and `2`: two sets built in different orders are `==`, `map` makes a set of the results' type, `unique` and `shown` write nothing at their calls, `Date` is ordered by year, month and day from its declaration, and `common` is written once for both representations. Without its clause, `unique` is rule 1's error:

```ernest-rejected
fn unique(list : List(a)) : List(a) =
    OrderedSet.toList(OrderedSet.fromList(list))
```

```console
$ ern build --short-errors usage.ern
usage.ern:17:23: fromList needs a.compare, which unique does not declare; add needs a.compare
```

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

Two programs beyond sets test the two forms where no set is involved. [`numeric.ern`](operations/numeric.ern) writes generic numeric functions over the clause `needs a.+`, at `Int`, at `Float`, and at a type with a `+` of its own; `sum` needs a zero as well, which is no member, so its caller passes one.

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

Its `main` prints `Some(6)`, `Some(4.0)`, `Some(Money(3))`, `6`, `[Money(4)]` and `Some(6)`. Declaring the zero as a requirement is rule 2's error:

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

[`ordered_map.ern`](operations/ordered_map.ern) is the ordered map of rule 12. Shown are its type, `empty`, `fromList`, `get`, `put`, `map`, which keeps the keys and needs nothing, `merge` and `mergeWith`; the rest of the vocabulary is written as these are, and the file holds it whole.

```ernest
export abstract type Map(k, v) = Map(List(#(k, v)))

export let empty : Map(k, v) = Map([])

export fn fromList(pairs : List(#(k, v))) : Map(k, v) needs k.compare =
    List.foldLeft(pairs, empty, fn(acc, #(key, value)) = put(acc, key, value))

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

[`set.ern`](../stdlib/set.ern) does not change. `ern doc` writes a clause as declared: `OrderedSet.fromList : (List(a)) -> OrderedSet.Set(a) needs a.compare`.

## Typing

Every construct above but the two forms is one the report specifies and the checker of Ernest 0.2.0 implements. The type system is §3.9's, and the specification stays inside it.

- **The requirement.** A clause adds nothing to the function's scheme (§3.9). It licenses `a.compare` and an operator on `a` in the body, each with the member's shape at `a`, its result `a` for an operator and for `negate` (rule 1), so that a type whose member answers another type is refused where the member is supplied. At a call of a function with a clause, the checker reads the type `a` is instantiated to once the enclosing definition is inferred, as it reads an operator's operand type (§4.8): a known type's member is supplied as an argument the emitter adds after the written ones; a type variable is met by the enclosing function's clause at that type, whose own added argument is passed along; and otherwise the call is rule 1's error. Nothing is inferred: a clause is written, or the call is refused.
- **The record.** `Ops(s, a)` is a sum type with one constructor and named fields (§3.5), rank-1: every field's type names only `s` and `a`. A field for `foldLeft` is refused with `type variable b is not a parameter of the type`.
- **Selection.** `ops.toList` in `common` is §3.5's selector, resolved as an operator's operand type is (§4.8): the operand's type constructor must be known when the enclosing definition is inferred, so the record parameter is annotated. Unannotated, it is refused with `the type whose field toList is read is not determined; annotate it`.
- **Code written once.** `common` is a let-polymorphic function over the record, with a principal type, instantiated at each representation.
- **The fill.** `Ops(..OrderedSet)` is checked as the literal it stands for: each field not given is the declaration of its name at a fresh instance of its scheme, unified with the field's type. `Ops(OrderedSet.Set(Int), Int)` fixes `a` to `Int`, so `fromList`'s clause is supplied with `Int.compare` and the field holds `fromList` at `Int`. The restrictions travel as from a literal: `hashed : Ops(Set(Int), Int)` carries `=` from `Set`'s functions, met at `Int`.
- **The bindings.** `let ordered : Ops(OrderedSet.Set(Int), Int) = Ops(..OrderedSet)` has a type with no variable in it; §8.5 runs the initializer once, a pure construction.
- **Requirement 4.** `OrderedSet.Set(Int)` and `OrderedSet.Set(Descending)` do not unify, since two declared types are distinct by name (§8.7).
- **Equality.** `==` on two ordered sets is structural over their sorted lists (§3.10) and needs the element's equality at that application: a set whose elements hold functions is built and used, and `==` on two of them is refused there.
- **The invariant.** The sorted list is the module's alone (§4.4).

**What the types do not guarantee**, stated as the program's promise: `compare` is a total order, and where the element type has `==`, says `Equal` only where `==` holds. Nothing checks either. Where the element type has no `==`, an ordered set holds one element per class of `Equal`, and `put` keeps the element already there (rule 5). A `compare` that is not transitive breaks the order: `contains` answers wrongly and duplicates stay. One that says `Equal` where `==` does not makes `==` on two sets depend on the order of insertion.

After an `Upgrade` (§6.10) or `:reload` (§11.2) a set built under the old `T.compare` is read under the new, and a changed order misorders it. A set sent to a node whose `T.compare` differs is read under that node's; MVP 3.0 decides where versions meet.

## What changes in Ernest

- §4.8 and Appendix A: a function declaration may end in a clause naming members of its type variables, `needs a.compare`: `FnDecl = ... [ "needs" Member { "," Member } ] "=" Expr`, `Member = typevar "." ( ident | userop )`; and `Primary` gains `typevar "." ( userop | "compare" | "negate" )`, mirroring `DeclName`, so that `a.compare` and `a.+` are expressions, §3.5 saying that under a clause such a name is the member and not a selection. Under the clause `a.compare` in the body is that member, and an operator on `a` resolves to it; the member has its shape with `a` for its result, `(a, a) -> a` for an operator, and a call at a type whose member has another result type is refused (rule 1). A call writes nothing for it: where the type is known when the enclosing definition is inferred the compiler supplies the member, where it is a variable the enclosing function's clause at that type supplies it, and without one the call is refused. A clause names a member of §4.8 only, and is never inferred (rule 2). The sentence that an operator carries no hidden argument stays, and a clause's member is the one argument the program does not write.
- §2.4: `needs` and `derives` are reserved words, twenty with them; the lexer, the Emacs mode's list of them and the formatter follow. Neither is an identifier anywhere in the repository's Ernest.
- §3.5 and Appendix A: a type declaration may end in `derives compare`, `TypeDecl = ... [ "derives" "compare" ]`, which declares the member rule 11 states.
- E.1: under `needs a.show`, `Io.show` and `Io.debug` apply to a value of a type variable (rule 2).
- §3.5 and Appendix A: in a record construction, `..` may name a namespace, which fills the fields not given from the declarations of their names (rule 7). `Fields = ".." ( Expr | Namespace ) [ "," FieldSet { "," FieldSet } ] | FieldSet { "," FieldSet }`.
- §4.2 and §11.1: a file name of words joined by `_` names one namespace, MVP 2.99b's item 4, done 2026-10-02.
- Appendix E, a section for `ordered_map.ern`, namespace `OrderedMap`, as rule 12 states, and a section for `ordered_set.ern`, namespace `OrderedSet`, with `abstract type Set(a)`, `empty`, `fromList`, and E.0 rule 2's vocabulary; which functions name `a.compare` and which `b.compare` (rule 3); `==` structural; the sorted list's costs.
- §11.5: rule 1's errors for a call without the clause and for a member of another result type, rule 2's error for a name that is no member, and the fill's; a call of a selected field names it as written, `ops.intersection`, where its message says "the callee", as requirement 5 asks; `ern doc` writes a clause as declared, and `ern shell` shows it as `ern doc` writes it, in `:type` and in completion.
- E.4 and E.0's vocabulary do not change. Nothing else in §3 or §4; §3.10 stays as it is: tuples, lists, `Optional` and `Either` have no order, and a program sorts pairs with a function it passes to `List.sort`.

## What it costs to build

The work falls on the parser and checker for the two forms, on the library, and on the documents:

| Area | Work | Item |
|---|---|---|
| Lexer, Emacs mode | two reserved words, `needs` and `derives`, and §2.4's count | 5 |
| Parser, checker, interfaces, emitter | the clause: its form, its two errors, its record in the `.erc`, the member or `show`'s descriptor supplied at a call or passed along from the enclosing clause | 5 |
| Parser, checker, emitter | `derives compare`: the generated member, its error, its place on the page | 5 |
| Parser, checker | `..` naming a namespace in a record construction, its error | 5 |
| `ordered_set.ern` | the module, its page, its tests, its section of Appendix E with a test per section | 5 |
| `ordered_map.ern` | the same, over keys in order | 5 |
| `ern shell` | a clause in `:type` and in completion | 5 |
| `ern doc` | a clause written as declared; a record type's constructor one field per line, where it writes it on one line | 5 |
| Report | §4.8, §3.5, E.1, Appendix A, §11.5, the two Appendix E sections | 5 |
| Guide §7.3 | rewritten over the finished code | 16 |

At run time a clause's member is an ordinary argument and a field use one indirect call, the host's own application of a fun. The ordered set's own costs are rule 9's.

## Compared, with pros and cons

`usage.ern` against the same program in OCaml, Standard ML, Haskell and Elm, in what a program writes:

| | The order | Equality | Code written once over two representations | Generic over the element | A second order |
|---|---|---|---|---|---|
| Ernest | nowhere; the member is found | `==` | a record the program declares, `Ops(..Set)` and `Ops(..OrderedSet)` | `needs a.compare` declared; nothing written at a call | a wrapper type |
| OCaml | once, at `Set.Make(Int)` | `IntSet.equal` | a first-class module, its parameter annotated | a functor, or a first-class module passed | a second functor application |
| Standard ML | once, at the functor application | `IntSet.equal` | a functor over the representation's structure | a functor | a second functor application |
| Haskell | nowhere; `Ord` is found | `==` | a class the program declares, an instance per representation | `Ord a =>`, inferred | a `newtype` |
| Elm | nowhere; elements are `comparable` | `==` | no second representation | `comparable` only | no second order |

In `usage.ern`, `main` writes no order and `==` once; `unique` declares the clause and its call writes nothing; `common` writes `ops.` four times over an annotated parameter; the program declares `Ops` in three lines and fills it in two. In `numeric.ern`, three generic functions declare `needs a.+` once each, their calls write nothing, and their bodies write `+` or `a.+`; `sum`'s zero is passed beside the `+` that is found. In `num.ern`, each type fills `Num` in one line, and every generic function takes `num` and writes `num.` before each operation.

**Pros.**

- Against OCaml and Standard ML: no functor application and no module per element type, one `OrderedSet` for every element type, and a record declared and filled in five lines where a functor is a module. The guarantee is the same: one order per type.
- Against Haskell: the same program on the element side, and no class declaration for code over two representations. Nothing is inferred and nothing is declared an instance: the only thing resolved is a member the type already has, nothing is written at a call, and every signature on the page says what its type must have.
- Against Elm: a user type has an order, `fn Date.compare`; a second representation exists; a second order is a wrapper type.

**Cons.**

- Against Haskell: every generic function that needs the order declares `needs a.compare`, where Haskell infers `Ord a =>` and Rust declares its bounds; and one argument is passed unseen along the declared clauses, where §4.8 allowed none.
- Against OCaml and Standard ML: the member is the only order a type has, so a reversed set of `Int` is a wrapper type where OCaml applies the functor again; and the requirement and the fill are two forms, where a functor is one.
- Against Elm: two forms where Elm has none, and an order declared per user type where Elm has no such type at all.
- Against all: a record over the whole vocabulary is twelve fields the program writes, and `filter` and `foldLeft` cannot be fields. The requirement reaches §4.8's members and `show` only; a record that needs a `zero` or a `hash` fills them by name from a namespace (rule 7) and can name neither in a requirement (rule 2).
