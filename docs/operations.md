# Operations records

*The specification of code written once over several representations of one type. MVP 2.99b's item 5 builds it. The log's *Operations Records*, *Members, Operators, and No Hidden Argument*, *The Operations Note Rewritten*, *The Order Bound Once* and *MVP 2.99b's Questions, One by One* argue its choices; the entry for the order carried in the set is item 5's to write. Revised 2026-10-02. The three files are whole under [`docs/operations/`](operations/), with their doc blocks, until item 5 moves them into the standard library. They fill their records from a namespace, rule 11, a form the toolchain does not have, so they do not build; before the fill replaced the two record literals they were built, run, formatted and rendered by `ern doc` on 2026-10-02 as user modules under other names, since `Set` is a namespace of the standard library, with every doc example checked against its value. `mixed.ern` is not built, and what it refuses is stated as expected. The code here is excerpted from the files, with the names they have in the standard library.*

Ernest has one set in its standard library, `Set`, a hash set. A second, `OrderedSet`, keeps its elements in order. Code written once works on both through an *operations record*, a record of a representation's operations that the caller passes. The § numbers cite Ernest's report.

## Requirements

1. Each type's operations are called through its module: `Set.put(s, x)`, `OrderedSet.put(s, x)`, and the ordered set's own `OrderedSet.min(s)`.
2. Generic code is an ordinary function, and the caller chooses the representation.
3. An ordered set carries its order, and can be sent to another node.
4. Sets in different orders cannot be combined.
5. Errors name what the user wrote: a function, a type, a record.
6. A program changes a set's representation by renaming it and giving the order where it makes a set; no other call site changes.

## The specification

Nothing in the type system changes, and the syntax does not. The rules give the standard library a convention and two files; *What changes in Ernest* lists the report's sections they touch.

1. **A set carries its order.** `OrderedSet.Set(a)` holds its elements and the function that orders them, a pure function of type `(a, a) -> Ordering`. The order is given where a set is made and nowhere else: `OrderedSet.empty(compare)` and `OrderedSet.fromList(list, compare)`, after the subject as `List.sort(list, compare)` has it. `map` and `filterMap` keep the element type, `(a) -> a` and `(a) -> Optional(a)`, and read the order from their set; a set of another element type is `fromList` of a list. Every other operation is a function of the module and reads the order from the set it is given: `OrderedSet.put(set, x)`. An operation on two sets, `union`, `intersection`, `difference`, `isSubset` and `equal`, reads the first's. No function of the module takes an order it can read from a set. No hidden argument is passed (§4.8).
2. **`==` is not defined on an ordered set.** Its value holds a function (§3.10). `OrderedSet.equal(set, other)` is `true` where the two have the same size and `compare` says `Equal` pair by pair in order, by the first's order. An ordered set is neither a key of a `Map` nor an element of a `Set`; a program that needs one keys by `toList`.
3. **A record holds the set's vocabulary whose types name only its parameters.** `Set.Operations(s, a)` holds twelve operations of E.0 rule 2's vocabulary for a container and a set: `empty`, `size`, `isEmpty`, `contains`, `put`, `remove`, `fromList`, `toList`, `union`, `intersection`, `difference` and `isSubset`, each of a type that names nothing but `s` and `a`. The record is an ordinary type (§3.5), and selecting a field is ordinary selection, resolved against the parameter's type (§4.8). The vocabulary's other eight, `map`, `filter`, `filterMap`, `foldLeft`, `foreach`, `any`, `all` and `find`, take a callback with an effect variable, or an accumulator of its own type, and are functions of each representation's module. A restriction a field's function carries travels with the record: binding the record's `a` to `Set`'s functions passes the equality restriction (§3.10), so `Set.operations` has the type `Set.Operations(Set(a=!), a=!)`, and `Set.operations.fromList([f])` with a function `f` is refused, naming `Set`'s element.
4. **Code written once is the program's.** Generic code is an ordinary function that the caller gives a record, written over the record's fields: `fn common(list, other, operations) = operations.toList(operations.intersection(operations.fromList(list), operations.fromList(other)))`. The library writes no generic function over the record (E.0 rule 4). Generic code that needs a callback folds over the record's `toList` with `List`'s functions, and sorts with `List.sort` and a function the caller gives it.
5. **A representation exports its record as `operations`**: `Set.operations`, a `let` filled from `Set`'s functions, `Operations(..Set)`, and `OrderedSet.operations(compare)`, a function of the order, filled from `OrderedSet`'s functions but `empty` and `fromList`, which close over it (rule 11). A representation fills each field itself. A type may meet several records, and a record may hold another as a field: a second ordered representation would bring `OrderedSet.Operations(s, a)`, holding `set : Set.Operations(s, a)` beside `min` and `max`. Any module can build a record from the operations another module exports.
6. **An order belongs to an element type.** A program gives one order for each element type it keeps ordered sets of: the type's `compare`, or the function it would declare as `compare` had the type a module of its own. A second order on one type is a second type with its own `compare`: `type Descending = Descending(Int)` with `fn Descending.compare`. Two sets in different orders have different types and cannot meet: `OrderedSet.union(up, down)` with `down : OrderedSet.Set(Descending)` is refused. Two sets of one element type made over two functions are the program's promise, which nothing checks; an operation on both reads the first's order.
7. **`put` keeps the element already there** where `compare` says `Equal`.
8. **A list that mixes representations needs a second record type**, one that hides `s`: its functions close over one set, and its `put` returns another such record. It has no operation on two sets and no `==`.
9. **`OrderedSet` is `ordered_set.ern`** in the standard library, a file whose words joined by `_` name one namespace (§4.2, §11.1). Its type is `OrderedSet.Set(a)` (E.0 shape rule 7). Inside the file it shadows the prelude's `Set`, and `Set.Operations` names the library's type (§4.2). A set carried into another representation goes through that representation's `fromList` of its `toList`. `Map` gets a record when it gets a second representation.
10. **The representation is a sorted list carrying its order.** `put`, `contains` and `remove` are linear in the set's size; `union`, `intersection`, `difference`, `isSubset` and `equal` are linear in the two sizes. No program can see the shape. A balanced tree may replace the list, with no change beyond the costs its section states.
11. **A record is filled from a namespace.** In a record construction, `..` may name a namespace in place of an expression: `Operations(..Set)` fills each field not given beside it from the declaration of its name that the use site may name (§4.2), and `Set.Operations(..OrderedSet, empty = empty(compare), fromList = fn(list) = fromList(list, compare))` takes the two fields given and fills the rest. The name after `..` is an expression where a binding or a constructor of that name is in scope, and a namespace otherwise. A field with no declaration of its name in the namespace, or one whose type does not fit the field's, is an error naming the field and the namespace: `Operations(..Set) lacks isSubset: Set has no isSubset`.

## The files

[`set.ern`](operations/set.ern) gains the record type and `Set`'s record. Its functions and E.4 do not change.

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
    Operations(..Set)
```

[`ordered_set.ern`](operations/ordered_set.ern) is the ordered set. Shown are its type, its record, the two functions that take an order, and `contains`, `put`, `equal`, `map`, `filter` and `union`; the rest of the vocabulary is written as these are, and the file holds it whole.

```ernest
export abstract type Set(a) = Set(elements : List(a), order : (a, a) -> Ordering)

export fn operations(compare : (a, a) -> Ordering) : Set.Operations(Set(a), a) =
    Set.Operations(..OrderedSet,
                   empty = empty(compare),
                   fromList = fn(list) = fromList(list, compare))

export fn empty(compare : (a, a) -> Ordering) : Set(a) =
    Set(elements = [], order = compare)

export fn fromList(list : List(a), compare : (a, a) -> Ordering) : Set(a) =
    List.foldLeft(list, empty(compare), put)

export fn contains(set : Set(a), x : a) : Bool =
    has(set.elements, x, set.order)

fn has(list : List(a), x : a, compare : (a, a) -> Ordering) : Bool =
    match list {
        [] -> false
      | y :: rest -> match compare(x, y) {
            Less -> false
          | Equal -> true
          | Greater -> has(rest, x, compare)
        }
    }

export fn put(set : Set(a), x : a) : Set(a) =
    withElements(set, inserted(set.elements, x, set.order))

fn withElements(set : Set(a), elements : List(a)) : Set(a) =
    Set(elements = elements, order = set.order)

fn inserted(list : List(a), x : a, compare : (a, a) -> Ordering) : List(a) =
    match list {
        [] -> [x]
      | y :: rest -> match compare(x, y) {
            Less -> x :: list
          | Equal -> list
          | Greater -> y :: inserted(rest, x, compare)
        }
    }

export fn equal(set : Set(a), other : Set(a)) : Bool =
    isSame(set.elements, other.elements, set.order)

fn isSame(list : List(a), other : List(a), compare : (a, a) -> Ordering) : Bool =
    match #(list, other) {
        #([], []) -> true
      | #(x :: rest, y :: others) -> compare(x, y) == Equal && isSame(rest, others, compare)
      | _ -> false
    }

export fn map(set : Set(a), f : (a) -> a with e) : Set(a) with e =
    fromList(List.map(set.elements, f), set.order)

export fn filter(set : Set(a), keep : (a) -> Bool with e) : Set(a) with e =
    withElements(set, List.filter(set.elements, keep))

export fn union(set : Set(a), other : Set(a)) : Set(a) =
    withElements(set, merged(set.elements, other.elements, set.order))

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

[`usage.ern`](operations/usage.ern) is a program that uses it. It gives the order where it makes a set and nowhere else, and has one function written once, `common`, which it calls with both representations.

```ernest
fn common(list : List(a), other : List(a), operations : Set.Operations(s, a)) : List(a) =
    operations.toList(operations.intersection(operations.fromList(list),
                                              operations.fromList(other)))

export fn main() : Unit with Never = {
    let small = OrderedSet.fromList([3, 1, 3], Int.compare);
    let both = OrderedSet.union(small, OrderedSet.fromList([2], Int.compare));
    Io.println(Io.show(OrderedSet.toList(both)));
    Io.println(Io.show(OrderedSet.min(both)));
    let same = OrderedSet.fromList([2, 3, 1], Int.compare);
    Io.println(Bool.toString(OrderedSet.equal(both, same)));
    Io.println(Io.show(OrderedSet.toList(OrderedSet.filter(both, fn(n) = n % 2 == 1))));
    let doubled = OrderedSet.map(both, fn(n) = n * 2);
    Io.println(Bool.toString(OrderedSet.contains(doubled, 6)));
    Io.println(Io.show(common([4, 2, 3], [3, 4, 5], OrderedSet.operations(Int.compare))));
    Io.println(Int.toString(List.size(common([4, 2, 3], [3, 4, 5], Set.operations))))
}
```

It prints `[1, 2, 3]`, `Some(1)`, `true`, `[1, 3]`, `true`, `[3, 4]` and `2`: two sets built in different orders are equal by `equal`, `map` keeps the order, and `common` is written once for both representations.

`mixed.ern` is a program rule 6 refuses.

```ernest-rejected
type Descending = Descending(Int)

fn Descending.compare(Descending(a) : Descending, Descending(b) : Descending) : Ordering =
    Int.compare(b, a)

export fn main() : Unit with Never = {
    let up = OrderedSet.fromList([1], Int.compare);
    let down = OrderedSet.fromList([Descending(1)], Descending.compare);
    Io.println(Int.toString(OrderedSet.size(OrderedSet.union(up, down))))
}
```

`ern build` refuses it at `down`: `the argument does not fit the callee: expected OrderedSet.Set(Int), found OrderedSet.Set(Descending)`.

Types print as `ern doc` writes them: `OrderedSet.operations : ((a!, a!) -> Ordering) -> Set.Operations(OrderedSet.Set(a!), a!)` and `OrderedSet.equal : (OrderedSet.Set(a!), OrderedSet.Set(a!)) -> Bool`, the `!` saying that no reply can be an element (§6.6); `OrderedSet.empty : ((a, a) -> Ordering) -> OrderedSet.Set(a)`; and `Set.operations : Set.Operations(Set(a=!), a=!)`, the `=` the equality `Set`'s element needs.

## Typing

Every construct above is one the report specifies and the checker of Ernest 0.2.0 implements. The type system is §3.9's, and the specification stays inside it.

- **The record.** `Operations(s, a)` is a sum type with one constructor and named fields (§3.5). Every field's type names only `s` and `a`, and no field quantifies a variable of its own. A field for `foldLeft`, polymorphic in its accumulator, is refused with `type variable b is not a parameter of the type`; a field for `filter`, whose callback has an effect variable, would fix one effect for every use of the record.
- **Selection.** `operations.put` in `common` is §3.5's selector, resolved as an operator's operand type is (§4.8): the operand's type constructor must be known when the enclosing definition is inferred. A record parameter is annotated. An unannotated one is refused with `the type whose field put is read is not determined; annotate it`.
- **Code written once.** `common` is a let-polymorphic function over the record, inferred and generalized as any `fn` is, with a principal type, and instantiated at each representation.
- **The records.** `Set.operations` is a top-level `let` of type `Operations(Set(a), a)` for every `a`, generalized by §4.6. `OrderedSet.operations` is a function that returns a record whose `empty` and `fromList` are closures over `compare` and whose other fields are the module's functions.
- **The fill.** `Operations(..Set)` is checked as the record literal it stands for: each field not given is the declaration of its name, at a fresh instance of its scheme (§3.9), unified with the field's type, so `s` is `Set(a)` from `empty` and every function must agree. The restrictions travel as from a literal, `=` from `Set`'s functions among them.
- **The set.** `OrderedSet.Set(a)` is an abstract type with two named fields, `elements` and `order` (§3.5, §4.4), which its functions select. `OrderedSet.fromList([1], Int.compare)` has a type with no variable in it; a top-level `let` of it is an initializer (§8.5), a pure call, and in a block the binding is monomorphic (§4.6).
- **The restrictions.** The three of §3.9 travel through the record as through any type. When the record is built, unifying its `a` with the variables of the functions that fill it passes their marks to it: `=` by §3.10's rule that binding a variable with the equality restriction restricts the variables in value positions of the type it is bound to, `!` by §4.7's rule for a foreign function's variables. Each is a flag on a type variable, checked at instantiation and printed (§11.5). So `Set.operations : Set.Operations(Set(a=!), a=!)`, and `Set.operations.fromList([f])` fails the check, `(Int) -> Int does not support equality, and a Set's element needs it`. `OrderedSet.Set(a)` holds a function and does not support equality: `==` on two ordered sets, `Map.put` keyed by one and `Set.put` of one are refused at the application, `OrderedSet.Set(Int) does not support equality`.
- **Requirement 4.** `OrderedSet.Set(Int)` and `OrderedSet.Set(Descending)` do not unify, since two declared types are distinct by name (§8.7).
- **The invariant.** The sorted list and its order are the module's alone (§4.4).

**What the types do not guarantee**, stated as the program's promises: one order per element type between two sets of one type, kept apart only where the orders are types; and `compare`'s laws, totality and agreement with `==`.

Two versions of a `compare` can meet. After an `Upgrade` (§6.10) and across `:reload` (§11.2), a set made before carries the old and one made after the new, and an operation on both reads the first's. Code shipped with a spawn carries the sender's `compare` by its hash (§8.7). What the function a set carries runs at a receiving node, the code it names by hash or that node's version, MVP 3.0 decides.

`compare` is a total order, and where the element type has `==`, says `Equal` only where `==` holds. Nothing checks either. Where the element type has no `==`, an ordered set holds one element per class of `Equal`, and `put` keeps the element already there (rule 7). A `compare` that is not transitive breaks the order: `contains` answers wrongly and duplicates stay. One that says `Equal` where `==` does not makes `equal` hold between sets whose elements differ by `==`.

## What changes in Ernest

- §4.2 and §11.1: a file name of words joined by `_` names one namespace, MVP 2.99b's item 4, done 2026-10-02.
- E.0, rule 2: `map` and `filterMap` of an ordered container keep the element type, `(a) -> a` and `(a) -> Optional(a)`.
- §3.5 and Appendix A: in a record construction, `..` may name a namespace, which fills the fields not given from the declarations of their names (rule 11). `Fields = ".." ( Expr | Namespace ) [ "," FieldSet { "," FieldSet } ] | FieldSet { "," FieldSet }`.
- E.4: `Set.Operations(s, a)` and `Set.operations`.
- Appendix E, a section at its end: `ordered_set.ern`, namespace `OrderedSet`, with `abstract type Set(a)`, `operations`, `empty`, `fromList`, `equal`, and E.0 rule 2's vocabulary. `empty` and `fromList` take the order, and every other function reads it from its set; `map` and `filterMap` keep the element type. `==` is not defined on the type (§3.10), and `equal` is its equality.
- §11.5: a call of a selected field names it as written, `operations.union`, where its message says "the callee", as requirement 5 asks.
- Nothing in §3 or §4, and no change to the checker's typing or to the emitter. §3.10 stays as it is: tuples, lists, `Optional` and `Either` have no order, and a program sorts pairs with a function it passes to `List.sort`.

## What it costs to build

Nothing in the checker's typing, the emitter or the runtime changes. The work falls on the library, a diagnostic and the documents:

| Area | Work | Item |
|---|---|---|
| Checker, emitter, runtime | none; the defect the first build found was item 4's, fixed 2026-10-02 | 4 |
| Parser, checker | `..` naming a namespace in a record construction (§3.5), its error, its test | 5 |
| `set.ern` | the record type, `operations`, their doc blocks and examples | 5 |
| `ordered_set.ern` | the module, its page, its tests, its section of Appendix E with a test per section | 5 |
| §11.5's message for a selected callee | the field named as written | 5 |
| `ern doc` | a record type's constructor laid out as the source writes it, one field per line, where it writes it on one line | 5 |
| Report | rule 2's clause for `map` and `filterMap` of an ordered container, E.4, the new section | 5 |
| Guide §7.3 | rewritten over the finished code | 16 |

At run time a field use is one indirect call, the host's own application of a fun, which `make bench` confirms. The ordered set's own costs are rule 10's.
