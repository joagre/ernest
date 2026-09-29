# Contracts

How code written once uses several representations of one thing, a set kept hashed and a set kept in order. The note holds the recommended way, its cost, and how it compares with full type classes, until MVP 2.97 decides; the decision goes to the report and the decisions log, and the note goes. The block marked `ernest` compiles today (2026-09-29); those marked `sketch` are Ernest as the recommendation, or type classes, would make it.

## What the user should see

The measure is the user of `Set` and an ordered set, judged by the five principles (§0):

1. **Each type on its own reads as today.** `Set.put(s, x)`, `OrderedSet.put(s, x)` and `OrderedSet.min(s)`: the same verbs for the same operations (E.0 shape rule 2), and the ordered set's own beside them.
2. **Code written once is an ordinary function**, and its caller chooses the representation.
3. **An ordered set is data.** It has `==`, keys a `Map`, and goes to a peer in a message, as a `Set(Int)` does.
4. **A wrong mix is refused, not computed.** Two sets ordered differently cannot meet in `union` and give a set in neither order.
5. **A mistake is reported in the user's words**, as a function, a type or a record the user wrote.

## What Ernest has today

- `==` on a type variable gives it the equality restriction, inferred and never written (§3.9, §3.10).
- `<` finds `T.compare` in its operand type's namespace (§3.10), but only where the definition fixes the type: on a type variable it is refused, ``the operand type of `<` is not determined; annotate it`` (§4.8).
- A type variable in a field must be a parameter of its type (§3.9), so a record cannot hold `Set.foldLeft`: `type variable b is not a parameter of the type` (language feedback 64).
- A value that holds a function has no `==` (§3.10; the checker does not refuse it yet, MVP 2.98 item 6) and cannot go to a peer (§3.11).

So an ordered set must carry its `compare` in each value, since nothing else can give it one:

```ernest
export abstract type OrderedSet(a) = OrderedSet(compare : (a, a) -> Ordering, items : List(a))

export fn empty(compare : (a, a) -> Ordering) : OrderedSet(a) =
    OrderedSet(compare = compare, items = [])

export fn put(s : OrderedSet(a), x : a) : OrderedSet(a) =
    OrderedSet(..s, items = inserted(s.items, x, s.compare))

fn inserted(items : List(a), x : a, compare : (a, a) -> Ordering) : List(a) =
    match items {
        [] -> [x]
      | y :: rest -> match compare(x, y) {
            Less -> x :: items
          | Equal -> items
          | Greater -> y :: inserted(rest, x, compare)
        }
    }

export fn min(s : OrderedSet(a)) : Optional(a) =
    List.get(s.items, 0)
```

That breaks measure 3, since the value holds a function, and measure 1, since `empty` takes an order that `Set.empty` does not.

## The recommendation: records of functions, two restrictions lifted

A contract is a record of functions, which Ernest has, and the caller chooses the representation by the record it passes. Two restrictions are lifted, each an error a user meets today. Nothing is added: no reserved word, no kind of declaration, no form of call.

1. **An order on a type variable, as equality.** `<`, `<=`, `>` and `>=` on a type variable give it the *ordering restriction*, inferred and never written, as `==` gives the equality restriction, and printed `a<` as that one is printed `a=`. At each instantiation the variable's type must have `compare`, or the call is a type error, and the comparison is that type's `compare`. A variable that no definition generalizes and nothing fixes is refused, as today (§4.8). The arithmetic operators keep §4.8's rule.
2. **A `compare` over parameters.** A member `T.compare` of a type with parameters may compare them, and then carries the restriction on them: `Pair(Int)` has an order and `Pair(Bool)` none.
3. **A top-level `let` is not generalized over an ordered variable**, as it is not when its initializer calls a process-only function (§3.9, §4.6), so it is still computed once (§8.5). A value that depends on an order is a function.
4. **A named field's own variables.** A type or effect variable that a named field names and its type does not take is the field's own, as a variable named only in a lambda's annotation is the lambda's own (§3.9). The value given for the field, where the record is built or updated with `..`, must have the field's type for every type the variable takes, and each selection or pattern instantiates it afresh. A positional field has none, since a single-positional constructor is a function value (§5.6). A field's own variable carries no inferred restriction, so a value that needs one does not fit the field.
5. **A contract is a record type**, named for what it holds. `Set.Operations(s, a)`, in `set.ern`, holds `Set`'s functions whose types stay within one representation: all but `map` and `filterMap`, whose result has another element.
6. **A representation meets a contract by a function its module exports**, `operations()`, whose annotation names the contract. It is a function in every representation, since an ordered one depends on an order (rule 3), so that all read alike. Any module may build a contract's record, for a type of its own or another's.
7. **Code written once takes the record last**, as `List.sort` takes its `compare` (E.0 shape rule 1).
8. **An ordered set orders its elements by their type's `compare`.** Another order is another type, as Haskell's `Down` is: `Descending(Int)`, with its own `compare`.
9. **`==` stays as it is**, structural. Values of several representations in one list are records whose functions close over their values, the guide's §7.3 first form: the same mechanism.

```sketch
// set.ern: the contract, and Set's record
export type Operations(s, a) =
    Operations(empty : s,
               put : (s, a) -> s,
               contains : (s, a) -> Bool,
               union : (s, s) -> s,
               foldLeft : (s, b, (b, a) -> b with e) -> b with e)  // b and e are the field's own

export fn operations() : Operations(Set(a), a) =
    Operations(empty = empty,
               put = put,
               contains = contains,
               union = union,
               foldLeft = foldLeft)

// orderedset.ern: an ordered set is its elements, in their type's order
export abstract type OrderedSet(a) = OrderedSet(List(a))

export let empty : OrderedSet(a) = OrderedSet([])

export fn put(OrderedSet(xs) : OrderedSet(a), x : a) : OrderedSet(a) =
    OrderedSet(inserted(xs, x))

fn inserted(xs : List(a), x : a) : List(a) =
    match xs {
        [] -> [x]
      | y :: rest -> if x < y then x :: xs else if y < x then y :: inserted(rest, x) else xs
    }

export fn min(OrderedSet(xs) : OrderedSet(a)) : Optional(a) =
    List.get(xs, 0)

export fn operations() : Set.Operations(OrderedSet(a), a) =
    Set.Operations(empty = empty, put = put, ...)

// the user
fn fromList(xs : List(a), operations : Set.Operations(s, a)) : s =
    List.foldLeft(xs, operations.empty, operations.put)

fn size(set : s, operations : Set.Operations(s, a)) : Int =
    operations.foldLeft(set, 0, fn(n, _) = n + 1)

let small = fromList([3, 1, 3], OrderedSet.operations())
OrderedSet.min(small)                                 // Some(1)
size(small, OrderedSet.operations())                  // 2
small == fromList([1, 3], OrderedSet.operations())    // true: an ordered set is data
```

`inserted` compares with `<`, so `put` and `operations` carry the ordering restriction, and `:type OrderedSet.put` shows `(OrderedSet(a<), a<) -> OrderedSet(a<)`.

**For:**
- The five measures. Each set reads as today, and `OrderedSet.put` takes no order. Code written once is a function of the record. An ordered set is its elements alone. Two orders are two types, and only the ordered set's module can build a record that sees inside it. A mistake is a record, a function, or a type without `compare`.
- Nothing new to learn: two errors a user meets today go, and Appendix A and §2.4 do not change (principles 4 and 5).
- One mechanism for every contract, a record of functions, for code written once and for values of several representations in one list (principle 2).
- A call names what it calls: the record is written at the call, and the function at the selection (principle 3).
- The record chooses the representation, so no annotation chooses it and no call is ambiguous.
- A contract may be met for any type in any module, `List` included: nothing is found by type, so there is no coherence rule and no orphan rule.
- Coherence where it matters, for orders, comes from the type: one `compare` per type, declared in its module (§3.10, §4.2).
- Inference stays Hindley-Milner's: a field's own variables are declared and checked, never inferred, as OCaml's polymorphic fields are.
- It closes no door. A field's own variables are what a class method needs, and the ordering restriction is the smallest case of a class's hidden argument, so type classes, if ever taken, would build on both.

**Against:**
- A function that is only handed a set takes the record too, and passes it on: `size(small, OrderedSet.operations())`, where type classes write `size(small)`.
- The record's parameter is annotated, since a selection needs its record's type (§3.5).
- One argument no one wrote: the `compare` of an ordered variable, passed by the emitter. `<` is its precedent, finding `T.compare` by type today, and the restriction is the language's own: no user declares another.
- A field's own variable is a rank-2 type confined to named fields, which the log's *Dropped from Unison* left out. The user sees only the error go.
- A field's own variable carries no restriction, so `map` and `filterMap` stay out of the contract, as they are out of Haskell's and Java's.
- A value that depends on an order is a function, `OrderedSet.operations()`, not a `let`.
- Generic code orders with `<` and its kin and has no name for its variable's `compare`, so it sorts with `List.sort` and a lambda built from `<`.

**Cost**, in the plan's days:
- **A named field's own variables, about 2 days**, in the checker alone. `field_type` keeps the variables it refuses today, and `#cinfo` records them per field, which the compiled interface carries. A field's value is inferred, generalized, and checked with the field's own variables rigid, as an annotation's are, whose errors exist already. Selection and patterns instantiate them. The emitter does nothing, since the value's representation does not change.
- **The ordering restriction, about 3 days.** In the checker: a fourth flag on a variable beside `eq`, `process_only` and `no_reply`; a comparison on a variable sets it where it fails today; the check at instantiation stands beside equality's; the printer adds the mark; the compiled interface carries flags already. In the emitter, the first argument no one wrote, since none is passed today: a definition takes a `compare` for each ordered variable, each call passes one, a function used as a value closes over it, and a comparison on a variable calls it. A `T.compare` over parameters is closed over its parameters' `compare`s.
- **The report**: §3.9, §3.10, §4.8 and §11.5 amended, and Appendix E for the contract and the ordered set. With the guide's §7.3 and the library, that is MVP 2.97's own 2 days.
- **In all, about 7 days**, 5 more than MVP 2.97 has now.

## Full type classes

Haskell's classes, in the form that can hold a set's operations, with what a full design brings. A `class` is over the whole set type, with its element an associated type, as Rust's traits have, so that no variable stands for a type constructor. Instances are declared with `instance`, with their conditions written in their heads. There are superclasses and default methods. Constraints are inferred, as `a=` is, and never written on a function. A method is resolved by its argument's type or by the type expected. There is one instance per type, with an orphan rule. `==`, `compare` and the operators become classes, so that the three are one mechanism. A method is named through its class, as a type's member is through its type (§4.2), since Ernest has no import to bring a method's name into scope.

```sketch
// set.ern: the class, and Set's instance of it
export class Collection(s) {
    type Element
    let empty : s
    fn put(set : s, x : Element) : s
    fn contains(set : s, x : Element) : Bool
    fn union(set : s, other : s) : s
    fn foldLeft(set : s, acc : b, step : (b, Element) -> b with e) : b with e
}

instance Collection(Set(a)) where Eq(a) {
    type Element = a
    ...
}

// orderedset.ern: the ordered set's instance, which needs an order on its elements
instance Collection(OrderedSet(a)) where Ord(a) {
    type Element = a
    ...
}

// the user
fn fromList(xs) =
    List.foldLeft(xs, Set.Collection.empty, Set.Collection.put)

fn size(set) =
    Set.Collection.foldLeft(set, 0, fn(n, _) = n + 1)

let small : OrderedSet(Int) = fromList([3, 1, 3])
OrderedSet.min(small)                                 // Some(1)
size(small)                                           // 2
```

## Compared

### For the developer

| The developer | Recommended | Type classes |
|---|---|---|
| uses one kind of set | `OrderedSet.put(s, x)` | `OrderedSet.put(s, x)`, or the method `Set.Collection.put(s, x)` |
| writes code once | annotates the record, `operations : Set.Operations(s, a)`, and calls `operations.put` | calls `Set.Collection.put`, the constraint inferred |
| builds a set with it | `fromList([3, 1, 3], OrderedSet.operations())` | `let small : OrderedSet(Int) = fromList([3, 1, 3])`, the annotation choosing |
| hands it a set | `size(small, OrderedSet.operations())` | `size(small)` |
| adds a representation | exports `operations()` | declares an `instance` |
| fits a type declared elsewhere, `List` | builds a record, in any module | declares an instance beside the class or the type, and nowhere else |
| orders a type | `fn T.compare` | `fn T.compare`, or an `Ord` instance, whichever the design keeps |
| orders a type another way | a type of its own, with its `compare` | the same, with its instance |
| reads a call | the record, named at the call | the argument's type, then its instance |
| meets a mistake | a record or a function of the wrong type; a type without `compare` | also: no instance, an ambiguous type, overlapping instances, an orphan |
| needs two contracts | two record arguments | two inferred constraints |
| holds both kinds in one list | a record that closes over its value | the same, or an existential type, which is more |

Type classes write less where a set is only handed on, and need no annotation on a function written once. The recommendation writes a record at the call where type classes write an annotation. Otherwise the two are equal, or the recommendation has less to learn: every call says what it calls, every error is about a record, a function or a type, and a contract fits any type in any module.

### By the principles

| Principle | Recommended | Type classes |
|---|---|---|
| 1. Least surprise | A call names what it calls; two errors a reader would not predict go. | What a method runs is chosen by a type the reader infers, and `empty` alone needs an annotation. |
| 2. One way | Every contract is a record of functions. | Classes beside records of functions, and methods beside module functions; `==`, `compare` and the operators become one mechanism. |
| 3. Nothing invisible | The record is written at the call. One argument is unwritten, an ordered variable's `compare`, as `<` finds `T.compare` today. | An unwritten dictionary for every constraint, of every class a program declares. |
| 4. Simple to parse | Appendix A does not change. | `class` and `instance`, method signatures, associated types, and conditions in instance heads. |
| 5. Small | Two restrictions lifted. | Classes, instances, associated types, conditions, superclasses, defaults, coherence and orphan rules, ambiguity. |

### The work

The toolchain has about 18,000 lines of Erlang, the checker 3,000 of them and the emitter 1,400. The estimates are in the plan's days.

| Part | Recommended | Type classes |
|---|---|---|
| Lexer, parser, formatter, Emacs mode | none | two reserved words; class and instance declarations, their layout and their indentation: 2 days |
| Types | a fourth flag on a variable; a field's own variables in `#cinfo` | conditions over types in every scheme, through unification, generalization, instantiation and printing |
| Checker | a comparison flags a variable; `compare` checked at instantiation beside equality; a field's own variables checked at construction and instantiated at selection | the same polymorphic methods; resolution with conditions and superclasses; associated types reduced in unification; overlap, orphan and ambiguity checks across modules; defaults: 3 weeks with the types |
| Emitter | a `compare` per ordered variable, passed at each call and closed over by each function used as a value | a dictionary per constraint: a tuple of methods with its superclasses', and an instance a function of its conditions' dictionaries: 1 week |
| Compiled interfaces | flags travel already; `#cinfo` gains the field's own variables | classes, instances and conditions |
| Shell and `ern doc` | the mark `a<` | conditions in `:type`, pages for classes and instances, an ambiguous type at the prompt: 2 days |
| Report and guide | §3.9, §3.10, §4.8 and §11.5 amended; the guide's §7.3 | sections for classes, instances, constraints, resolution and coherence; Appendix A; §3.10 and §4.8 rewritten on classes; a chapter of the guide: 3 days |
| Standard library | `Set.Operations` and the ordered set | the classes, and an instance for every type with `compare` or an operator |
| MVP 3.1's hashes | as `<` today | a definition's hash names the instances it resolves |
| In all | about 5 days, beside MVP 2.97's own 2 | about 6 weeks |

Type classes contain the recommendation: their methods need a field's own variables, and their dictionaries are the ordering restriction's hidden argument made general. What they add is the surface that declares classes and instances and the resolution that finds an instance by type: the six weeks, and an argument no one wrote at every call of a method.

**The verdict.** For the developer, type classes save the record at a call, and in a function that only hands a set on. For that they add classes, instances, associated types, conditions and the rules of coherence, a second mechanism beside records of functions, and about six weeks of work where the recommendation takes five days. The recommendation meets the five measures with neither, and is the one recommended.

## What MVP 2.97 settles beside

- **The ordered set's name and place.** The sketches write its namespace `OrderedSet`, and a file `orderedset.ern` provides `Orderedset` (§4.2).
- **Its representation.** `==` is structural, so a set must have one representation: a sorted list has, and a balanced tree whose shape follows the order of insertion has not.
- **Which of two elements it keeps** when `compare` finds them equal and `==` tells them apart.
- **The contract's fields** beyond the sketch's five.
- **The plan's item 4 (U8).** A member is resolved by type only for an operator and `compare`; whether a type's other operations are members or module functions is then naming alone, which item 4 decides.
