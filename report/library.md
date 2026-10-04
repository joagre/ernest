# Ernest Report: The Standard Library

Revision of 4 October 2026.

This file holds the report's Appendices D, E and G. §0 to §10 and Appendices A, B and F are in [`language.md`](language.md), and §11 and Appendix C in [`toolchain.md`](toolchain.md). The three files are one report, and each is normative.

**Contents**
<!-- contents -->
- [Appendix D. A Foreign Library](#appendix-d-a-foreign-library)
- [Appendix E. Standard Library](#appendix-e-standard-library)
- [Appendix G. Libraries](#appendix-g-libraries)
<!-- /contents -->

## Appendix D. A Foreign Library

A library over Erlang's `ets`, tables of type `set`, outside the standard library; a program adds its compiled root to the load path (§11.1, §11.2). Raw bindings are module-local, unqualified; the library is ordinary Ernest over them. The values `ets` returns match the ABI of §8.4 without an Erlang-side wrapper: `true` and `false` are `Bool` on both sides, and `[{K, V}]` is `List(#(k, v))`. An API that answers Erlang's `{ok, V} | {error, R}` needs an Erlang helper that rewrites the answer, as E.19 says; the `ets` calls below do not use that convention.

```ernest
// ets.ern  (namespace Ets)

/// A key-value table stored in the runtime's ETS backend, keyed
/// by a value of type k with values of type v. A table lives
/// until Ets.close is called on it, or until the process that
/// created it dies.
export foreign type Table(k=, v)

/// A fresh empty table. The table is owned by the current
/// process and is destroyed when that process dies.
export fn new() : Table(k, v) with m =
    rawNew(Erl.atom("ernest"), [Erl.atom("set"), Erl.atom("public")])

foreign fn rawNew(name : Foreign.Term, options : List(Foreign.Term)) : Table(k, v) with m =
    "ets:new/2"

/// Insert or replace the entry for key.
export fn put(table : Table(k, v), key : k, value : v) : Unit with m = {
    let _ = rawInsert(table, #(key, value));
    Unit
}

foreign fn rawInsert(table : Table(k, v), entry : #(k, v)) : Bool with m =
    "ets:insert/2"

/// The value for key, or None if absent.
export fn get(table : Table(k, v), key : k) : Optional(v) with m =
    match rawLookup(table, key) {
        [#(_, value)] -> Some(value)
      | _ -> None
    }

foreign fn rawLookup(table : Table(k, v), key : k) : List(#(k, v)) with m =
    "ets:lookup/2"

/// Remove key. A key not present is not an error.
export fn remove(table : Table(k, v), key : k) : Unit with m = {
    let _ = rawDelete(table, key);
    Unit
}

foreign fn rawDelete(table : Table(k, v), key : k) : Bool with m =
    "ets:delete/2"

/// The number of entries in the table.
export fn size(table : Table(k, v)) : Int with m =
    rawInfo(table, Erl.atom("size"))

foreign fn rawInfo(table : Table(k, v), item : Foreign.Term) : Int with m =
    "ets:info/2"

/// Close the table, deleting it. All subsequent operations on it fault.
export fn close(table : Table(k, v)) : Unit with m = {
    let _ = rawClose(table);
    Unit
}

foreign fn rawClose(table : Table(k, v)) : Bool with m =
    "ets:delete/1"

/// Remove all entries, leaving the table empty.
export fn clear(table : Table(k, v)) : Unit with m = {
    let _ = rawClear(table);
    Unit
}

foreign fn rawClear(table : Table(k, v)) : Bool with m =
    "ets:delete_all_objects/1"

/// True if key is present in table.
export foreign fn contains(table : Table(k, v), key : k) : Bool with m =
    "ets:member/2"

/// All key-value pairs currently in the table, in unspecified order.
export foreign fn toList(table : Table(k, v)) : List(#(k, v)) with m =
    "ets:tab2list/1"
```

```ernest
export fn main() : Unit with Never = {
    let table = Ets.new();
    Ets.put(table, "a", 1);
    Ets.put(table, "b", 2);
    match Ets.get(table, "a") {
        Some(value) -> Io.println(Int.toString(value))
      | None -> Io.println("missing")
    };
    Ets.close(table)
}
```

`Ets.Table(k, v)` has type parameters the implementation never sees: `Ets.put(table, "a", 1)` fixes `table` to `Ets.Table(String, Int)`, and a `put` with other types on the next line is a type error. Every operation has a mailbox type, `size` and `contains` included. A table is state that every process holding it reads and writes.

## Appendix E. Standard Library

E.0 is normative; a function enters this appendix by its rules before it enters `stdlib/`. The listing that follows is what E.0 has admitted, the modules that ship with the compiler as ordinary Ernest files under `stdlib/`. A listing gives each function's type as §11.5 prints it, its inferred restrictions of §3.9 marked, so that the marks are part of its contract: `List.size : (List(a!)) -> Int` takes no list that holds a reply, and `List.map` takes one. A module's own types are written there without its namespace. The standard library is on the load path by default; every program can call `Io.println`, `List.map`, and the rest without any setup. The prelude in §9 is what the language itself requires. Everything else here is written in Ernest on top of the language and prelude, except the shims that E.0's first rule admits.

### Appendix E.0. Rules

Four *admission rules* decide whether a function is in: rules 1 to 3 each admit a function, and rule 4 refuses one they would admit. None of them counts programs: a function enters when a rule admits it, whether or not a program has asked.

1. Its value is the runtime's: it reaches a representation the runtime owns, a table of the host's, its path syntax, Unicode's tables or the floating-point library's, or a process of the runtime's (§8.2, E.21, E.22), and each module's section names its *primitives*; in a system module, a function that reaches its process is a primitive, and the rest is Ernest over them. A type the language's syntax builds, a list, a tuple, a bitstring, is the language's, and a type only a module's functions build is the runtime's. A primitive is a shim over `foreign fn` or over a system process, and a shim exists only where this rule applies. The primitives are a few, and the rest of the module is Ernest over them; what the language owns, `[]` and `::` among it, is written in Ernest, `List.sort` among it. A primitive passes data out and calls no Ernest function but a wrap it delivers through (shape rule 8): `toList`, not `foldLeft`. Speed is not a reason for a shim. A primitive beneath an operation Ernest could write over the module's other primitives is admitted only where the Ernest form's cost, measured at the sizes a program meets, is more than three times the host's own, or grows with something the host's does not, with the numbers in the decisions log. A cost within three times the host's admits none. `String.trimEnd` over `graphemes` costs what the text's length costs, where the host reads only the text's end, and so has a primitive beneath it. The primitive is private, and the operation stays Ernest over it. The rule decides how an operation is carried out, never what a value is: where a value's identity, lifetime, or failure is the program's concern, it is a process (§8.2), and no shim stands in for one.
2. It follows from the type's structure, and each kind of type has a vocabulary. The kinds below, a container, a sequence, text, a set, a map, have their vocabulary here; a type of another kind, a path, a filesystem, lists its own in its section. A container provides the container operations of the vocabulary below, or says in its section which it lacks and what stands in its place. Text and octets are containers read through `toList`, and provide the container operations their sections list. A sequence adds order and position: `reverse`, `sort`, `take`, `drop`, `dropLast`, `last`, `span`, `partition`, `unique`, `indexed`, `repeat`, `zip`, `unzip`, `flatMap`, `range`, and `tryMap` and `tryFold` for a step that can fail. Text adds `startsWith`, `endsWith`, `indexOf`, `lastIndexOf`, `replace`, `slice`, `padStart`, `padEnd`, `repeat`, `split`, `join`, `lines`, `words`, `trim`, `trimStart`, `trimEnd`, `toLower`, `toUpper`, and a `Char` `isUpper`, `isLower`, `toUpper`, `toLower`. A set adds `union`, `intersection`, `difference`, and `isSubset`. A map adds `keys`, `values`, and `merge`. A conversion to text has its inverse where the text form is unambiguous and the type has no other way in; a `Char` has `String.toList` and needs none. A type that enters by rule 3 still gets its structure's vocabulary, not only the functions the program wrote. A published specification, a date, a pattern language, a format, a protocol, is a library's and no module's vocabulary.
3. It is a general operation of the type, its definition is the obvious one, and no policy is buried in it: `List.foldRight`, `Float.sqrt`. A function whose result depends on a choice the library would be making for the program, a format, a locale, a tolerance, is refused whatever asks for it. A policy the program passes as an argument without a default is not buried: `Supervisor.group`'s strategy and limit. A choice the section states whole and a program could make otherwise, E.13's generator, is not buried, and neither is a text form the language's own literals read back. A constant of the type enters as an operation does.
4. It is not a composition. A function outside rule 2's vocabulary, shape rule 2's operations, and shape rule 3's conversions that is one call of a function already here, or a pipe of two, is not added: `List.concat` is `List.flatMap(xs, fn(x) = x)`, `List.sum` is `List.foldLeft(xs, 0, Int.+)`. The vocabulary is admitted whole, whether or not one of its functions composes others: `Map.contains` is in, though it is `isSome` of `get`. A pair is admitted whole as the vocabulary is: a predicate of a two-constructor type with the other constructor's, `isSome` and `isNone`, `isLeft` and `isRight`, a print with its line form, `print` and `println`, `printError` and `printlnError`, and a text operation with its bytes form, `print` and `write`, `readLine` and `read`. `Io.debug` is kept alone. An operations record and a function over one are the program's (§4.9): no module declares one.

Nine *shape rules* give a function its shape. Shape rules 1 to 4, 7, and 9 hold in a library outside the standard library too, as Appendix D's, which the four admission rules do not reach.

1. The subject comes first, callbacks last but for shape rule 8's milliseconds, an accumulator between them: `x |> f(a)` is `f(x, a)`. No aliases, no argument-order variants. An operations record (§4.9) comes directly after the subjects, before an accumulator and the callbacks: `common(list, other, operations)`. A function takes a member as a parameter where any function of its type may be given, `List.sort(list, compare)`, and declares the requirement where the type's own member is meant (§4.9).
2. One verb per operation on each kind of type that has it, and a type alone of its kind names its own; a module whose operations serve two kinds names the second's with the kind, `closeListener`, `nextFloat`. The container operations are `empty`, `size`, `isEmpty`, `contains`, `get` for lookup by index or key, `put` for insertion, `remove`, `map`, `filter`, `filterMap`, `foldLeft`, `foreach`, `any`, `all`, `find`, `fromList`, and `toList`; the sum-type operations are `withDefault`, `map`, and `andThen`. A predicate is `isX`. `empty` is a value; a function that makes something which belongs to a process and ends, as G.1's table does, is `new`. `contains` on text finds a substring of any length, not an element, the empty text being in every text, and `size` on text counts graphemes, not the `Char`s `toList` gives (E.5). A verb not in this list names an operation none of these does.
3. A conversion is named by the other type. Between a type and one its module builds on, both directions are the building module's, `fromX` and `toX`: `String.fromList` and `String.toList`, `Map.fromList`, `Either.fromOptional`. Any other conversion is its argument's module's `toX`: `String.toInt`, `Int.toString`. A conversion exists once. When one conversion has several policies, the policy is the name: `Float.round`, `Float.floor`, `Float.ceil`, `Float.truncate`. A conversion of any value into a foreign type is `from`, and a function that makes a particular host term is named for the term, `Erl.atom`.
4. A partial operation returns `Optional`; one with a cause returns `Either`. A function faults only as §7.4 says.
5. A function is pure unless it acts through a process or reads the host's clock: a function that reaches a system reference of §8.2, spawns a process, as `Supervisor.group` does, asks the runtime about its processes (E.21), or reads the time, as `Clock.monotonic` does without a message, carries `with m`, and nothing else does, so `Terminal.columns`, `Io.show`, and `Process.fromAddress` are pure. A function that calls a function it takes is effect-polymorphic in it (§3.9). A wrapping function that shape rule 8 delivers through is pure, as `via`'s is (§6.5).
6. A module is documented as a section 3 manual page, in CommonMark (§2.2). Under `See also`, a declaration or a module is named in backticks and not linked.
   - **The module.** Its doc block says what the module is for, then has the section `Examples`, with the module's central examples, and `See also` when there is something to see. It ends with the line `since v`, the toolchain version in which the module appeared.
   - **A declaration.** Every exported declaration has a doc block: one sentence saying what the type does not say, such as which occurrence `remove` removes, the order `toList` produces, or the range `next` draws from; an `Errors` section when it faults, and none otherwise (shape rule 4); an `Examples` section with one example for an exported `type`, an abstract type's examples covering its members; `See also` when there is something to see. A declaration has the module's `since` unless its doc block ends with one of its own. The name and the type are the heading and the code block `ern doc` renders (§11.4).
   - **Examples.** Every exported function but an operator is called by at least one example on the module's page, in the module's examples or its own, and an example that would repeat another is left out. An example ends in `// => v`, where `v` is what `Io.show` writes for its value; what the example itself prints comes before it and is not part of `v`. An example that cannot run where the page's examples run, because its value is of an abstract type, because it reads a file or a socket, or because it needs a mailbox of its own, has no `// =>` line and is only type-checked.
7. A type a module exports is listed in its section as its functions are, `abstract type Seed` in E.13, and is named for what it is within the module, never for the module.
8. A function that waits on what another party holds, a file, a socket, a peer, or a program the runtime started, takes the milliseconds as its last argument, after any callback, which bound that one request, and answers `Left(Timeout)` when they pass; a call, whose one failure is no answer, answers `None` (§6.6). One that waits on a stream of the program's own, standard input, standard output, standard error and the terminal, waits without a limit, and the stream's failure ends the program (§8.2). One answered from what the runtime holds answers at once. A function that waits without a limit on another party says so in its name, as `Address.callForever` does. One that delivers later takes a function from the message to the caller's mailbox type and delivers to the caller, as `monitor` does (§6.9). A time is as §7.4 says.
9. An exported function takes no `Bool` that chooses between two behaviours. It takes a type whose constructors name them: `render(doc, Plain)`, not `render(doc, false)`. A `Bool` that is the value operated on, as in `Bool.not`, is not such a choice.

### Appendix E.1. `io.ern` (namespace `Io`)

Output to standard output and standard error, and input from standard input, through the module's system references `stdout`, `stderr`, and `stdin` (§8.2). `Io.show` and `Io.debug` are the prelude's, §9.4; this module provides them. The primitives are `print`, `println`, `printError`, `printlnError`, `readLine`, `read`, `write`, and `writeError`, which reach the module's processes, and `show` and `debug`, which read a value's representation in the runtime (E.0 rule 1). `Error` is the error of every system module. `NotAFile` is a path that names something other than what the function works on, a regular file or, for `Fs.append`, a device, and `Exists` a path that names something where nothing may stand. `NotUtf8(bytes)` is text that is not UTF-8, a name or a link's target among them, its bytes as they came. `Invalid` is an argument the host cannot take, one that holds U+0000, a port out of range, or a time it cannot hold among them. `Other(text)` holds the host's description of its reason, `"address already in use"`; where the host has no description, it holds the reason as the host writes it.

```
type Error = NotFound | Denied | Refused | Closed | Timeout | NotATerminal | NotAFile | Exists
           | NotUtf8(Bytes) | Invalid | Other(String)
Io.print : (String) -> Unit with m+
Io.println : (String) -> Unit with m+ // appends "\n"
Io.printError : (String) -> Unit with m+ // to standard error
Io.printlnError : (String) -> Unit with m+ // appends "\n"
Io.readLine : () -> Optional(String) with m+ // the next line without its line feed; None at end of input
Io.read : () -> Optional(Bytes) with m+ // what has arrived, at least one byte; None at end of input
Io.write : (Bytes) -> Unit with m+ // the bytes to standard output, as they are
Io.writeError : (Bytes) -> Unit with m+ // the bytes to standard error, as they are
```

`Io.show` writes a value by the argument's type at the call, each value as its literal or construction is written: a negative number with `-` before it, `-1`, a `Char` as `'a'`, `Bytes` as `<<104, 105>>`, a named constructor with its fields in their declared order (§3.5), `Snap(dir = "x", seen = 2)`. A `Map` prints as `Map.fromList` of its pairs, a `Set` as `Set.fromList` of its elements, in an order the values fix: ascending where the keys or the elements are `Int`, `Float`, `Char`, or `String`. An address prints as `<address 84>`, the number naming the process behind it, and a `Process` as `<process 84>` (E.21). A function prints as `<function>`; no reply reaches `Io.show`, whose argument is no reply-carrying type (§6.6). `Io.show` and `Io.debug` write a value by the type at which the name is used, as a callee or an argument; their requirement, `needs a.show` (§9.4), is supplied there as any requirement is (§4.9). The type must be known there whole, not only determined as §4.8 asks of an operand, but for type variables a requirement in force names `show` for, at which the call writes the value as the types the variables are instantiated to: under `needs a.show`, `a`, `List(a)` and `Optional(#(a, Int))` are each written. A type variable no requirement names `show` for is a type error. Neither takes an argument the program has not declared: on a known type none, and under a requirement what it names, which a call supplies without writing it (§4.9). An effect variable in the type is no matter. A value of an abstract type outside its module is written as `<abstract>`, and a value of a foreign type as `<foreign>`. `Io.debug` writes as §9.4 says.

### Appendix E.2. `list.ern` (namespace `List`)

`[]` is `empty` and `::` is `put`, so neither is a function; `fromList` and `toList` are the identity and are not provided. `contains`, `remove`, and `unique` require equality on `a` (§3.10). `List.<>` is the prelude's, §9.6; this module provides it (§9).

```
List.size : (List(a!)) -> Int
List.isEmpty : (List(a!)) -> Bool
List.contains : (List(a=!), a=!) -> Bool
List.get : (List(a!), Int) -> Optional(a!) // by index from 0; None for a negative index or one at or past the end
List.remove : (List(a=!), a=!) -> List(a=!) // the first occurrence
List.map : (List(a), (a) -> b with e) -> List(b) with e
List.filter : (List(a!), (a!) -> Bool with e) -> List(a!) with e
List.filterMap : (List(a), (a) -> Optional(b) with e) -> List(b) with e
List.foldLeft : (List(a), b, (b, a) -> b with e) -> b with e
List.foldRight : (List(a), b, (a, b) -> b with e) -> b with e // from the right, the element first
List.foreach : (List(a), (a) -> Unit with e) -> Unit with e
List.any : (List(a!), (a!) -> Bool with e) -> Bool with e
List.all : (List(a!), (a!) -> Bool with e) -> Bool with e
List.find : (List(a!), (a!) -> Bool with e) -> Optional(a!) with e // the first that satisfies
List.last : (List(a!)) -> Optional(a!)
List.take : (List(a!), Int) -> List(a!) // the first n, or all when there are fewer; n below 0 is 0
List.drop : (List(a!), Int) -> List(a!) // all but the first n; n below 0 is 0
List.dropLast : (List(a!), Int) -> List(a!) // all but the last n; n below 0 is 0
List.span : (List(a!), (a!) -> Bool with e) -> #(List(a!), List(a!)) with e // the longest prefix that satisfies, and the rest
List.partition : (List(a!), (a!) -> Bool with e) -> #(List(a!), List(a!)) with e // those that satisfy and those that do not, each in order
List.unique : (List(a=!)) -> List(a=!) // the first occurrence of each, in order
List.indexed : (List(a)) -> List(#(Int, a)) // each element with its index from 0
List.repeat : (a!, Int) -> List(a!) // n copies; n below 0 is 0
List.reverse : (List(a)) -> List(a)
List.sort : (List(a!), (a!, a!) -> Ordering with e) -> List(a!) with e // stable
List.zip : (List(a!), List(b!)) -> List(#(a!, b!)) // to the shorter length
List.unzip : (List(#(a, b))) -> #(List(a), List(b))
List.flatMap : (List(a), (a) -> List(b) with e) -> List(b) with e
List.range : (Int, Int) -> List(Int) // from the first to the second inclusive; empty when the first is greater
List.tryMap : (List(a!), (a!) -> Either(e, b!) with x) -> Either(e, List(b!)) with x // the first Left ends it
List.tryFold : (List(a!), b, (b, a!) -> Either(e, b) with x) -> Either(e, b) with x // the first Left ends it
```

### Appendix E.3. `map.ern` (namespace `Map`)

Requires equality on `k` (§3.10). The order of `keys`, `values`, `toList`, `foldLeft`, `foreach`, and `find` is unspecified, and so is the order in which `map`, `filter`, `filterMap`, `any`, `all`, and `mergeWith` meet the entries. The primitives are `empty`, `size`, `get`, `put`, `remove`, and `toList` (E.0 rule 1).

```
Map.empty : Map(k=, v)
Map.size : (Map(k=!, v!)) -> Int
Map.isEmpty : (Map(k=!, v!)) -> Bool
Map.contains : (Map(k=!, v!), k=!) -> Bool
Map.get : (Map(k=!, v!), k=!) -> Optional(v!)
Map.put : (Map(k=!, v!), k=!, v!) -> Map(k=!, v!) // replaces an entry with that key
Map.remove : (Map(k=!, v!), k=!) -> Map(k=!, v!) // a key not present is not an error
Map.update : (Map(k=!, v!), k=!, (Optional(v!)) -> v! with e) -> Map(k=!, v!) with e // the entry, present or not, replaced by the function's value
Map.map : (Map(k=!, v!), (k=!, v!) -> w! with e) -> Map(k=!, w!) with e
Map.filter : (Map(k=!, v!), (k=!, v!) -> Bool with e) -> Map(k=!, v!) with e
Map.filterMap : (Map(k=!, v!), (k=!, v!) -> Optional(w!) with e) -> Map(k=!, w!) with e
Map.foldLeft : (Map(k=!, v!), b, (b, k=!, v!) -> b with e) -> b with e
Map.foreach : (Map(k=!, v!), (k=!, v!) -> Unit with e) -> Unit with e
Map.any : (Map(k=!, v!), (k=!, v!) -> Bool with e) -> Bool with e
Map.all : (Map(k=!, v!), (k=!, v!) -> Bool with e) -> Bool with e
Map.find : (Map(k=!, v!), (k=!, v!) -> Bool with e) -> Optional(#(k=!, v!)) with e // some entry that satisfies
Map.merge : (Map(k=!, v!), Map(k=!, v!)) -> Map(k=!, v!) // the second wins for a shared key
Map.mergeWith : (Map(k=!, v!), Map(k=!, v!), (k=!, v!, v!) -> v! with e) -> Map(k=!, v!) with e // for a shared key, the function of the key, the first's value and the second's
Map.fromList : (List(#(k=!, v!))) -> Map(k=!, v!) // a later pair wins
Map.toList : (Map(k=!, v!)) -> List(#(k=!, v!))
Map.keys : (Map(k=!, v!)) -> List(k=!)
Map.values : (Map(k=!, v!)) -> List(v!)
```

### Appendix E.4. `set.ern` (namespace `Set`)

Requires equality on `a` (§3.10). A set has no `get`; membership is `contains`. The order of `toList`, `foldLeft`, `foreach`, and `find` is unspecified, and so is the order in which `map`, `filter`, `filterMap`, `any`, and `all` meet the elements. The primitives are `empty`, `size`, `contains`, `put`, `remove`, and `toList` (E.0 rule 1).

```
Set.empty : Set(a=)
Set.size : (Set(a=!)) -> Int
Set.isEmpty : (Set(a=!)) -> Bool
Set.contains : (Set(a=!), a=!) -> Bool
Set.put : (Set(a=!), a=!) -> Set(a=!) // an element already present is not an error
Set.remove : (Set(a=!), a=!) -> Set(a=!) // an element not present is not an error
Set.map : (Set(a=!), (a=!) -> b=! with e) -> Set(b=!) with e // requires equality on b
Set.filter : (Set(a=!), (a=!) -> Bool with e) -> Set(a=!) with e
Set.filterMap : (Set(a=!), (a=!) -> Optional(b=!) with e) -> Set(b=!) with e // requires equality on b
Set.foldLeft : (Set(a=!), b, (b, a=!) -> b with e) -> b with e
Set.foreach : (Set(a=!), (a=!) -> Unit with e) -> Unit with e
Set.any : (Set(a=!), (a=!) -> Bool with e) -> Bool with e
Set.all : (Set(a=!), (a=!) -> Bool with e) -> Bool with e
Set.find : (Set(a=!), (a=!) -> Bool with e) -> Optional(a=!) with e // some element that satisfies
Set.fromList : (List(a=!)) -> Set(a=!)
Set.toList : (Set(a=!)) -> List(a=!)
Set.union : (Set(a=!), Set(a=!)) -> Set(a=!)
Set.intersection : (Set(a=!), Set(a=!)) -> Set(a=!)
Set.difference : (Set(a=!), Set(a=!)) -> Set(a=!) // the elements of the first not in the second
Set.isSubset : (Set(a=!), Set(a=!)) -> Bool // every element of the first is in the second
```

### Appendix E.5. `string.ern` (namespace `String`)

A `String` is a container read through `toList`: of the container operations it provides `size`, `isEmpty`, `contains`, `fromList`, and `toList`, and the rest go through `toList`. `size`, `slice`, `indexOf`, `lastIndexOf`, `padStart`, and `padEnd` count and index in graphemes, extended grapheme clusters, each what a reader sees as one letter, and `graphemes` gives them in order. A pad that begins no grapheme, a combining mark, joins the grapheme beside it, so `padStart` and `padEnd` then leave the string shorter than asked. `toList` and `fromList` are `Char`s, one scalar value each, so a string holding a combining mark has more `Char`s than graphemes. The primitives are `size`, `graphemes`, `indexOf`, `lastIndexOf`, `toLower` and `toUpper`, which need Unicode's tables, and the conversions `toFloat`, `toList`, `fromList`, `toUtf8` and `fromUtf8`. Three are private to the module: the slice `slice` makes once it has clipped its index and count, `drop`, the string after a count of graphemes, and the last grapheme `trimEnd` takes off, found from the string's end (E.0 rule 1). `drop` is beneath `trimStart` and `split`. The rest is Ernest over them, so every search matches whole graphemes: `String.contains("e\u{301}", "e")` is `false`, and `String.split("a\r\nb", "\n")` is `["a\r\nb"]`, a carriage return and a line feed being one grapheme. `trim`, `trimStart`, and `trimEnd` remove the graphemes whose first code point is White_Space, as `Char.isSpace` says. `toLower` and `toUpper` use Unicode's full case mapping without the rules that depend on a language or a context: `String.toUpper("ß")` is `"SS"`. `String.compare` orders by code point. It and `String.<>` are the prelude's, §9.6; this module provides them (§9).

```
String.size : (String) -> Int // graphemes
String.graphemes : (String) -> List(String) // the graphemes in order, each a String
String.isEmpty : (String) -> Bool
String.contains : (String, String) -> Bool // substring; an empty second is always there
String.indexOf : (String, String) -> Optional(Int) // where the second begins, None where it is not there; an empty second is 0
String.lastIndexOf : (String, String) -> Optional(Int) // where the second begins last, None where it is not there; an empty second is the first's size
String.startsWith : (String, String) -> Bool // true for an empty second
String.endsWith : (String, String) -> Bool // true for an empty second
String.replace : (String, String, String) -> String // every occurrence of the second by the third; an empty second changes nothing
String.slice : (String, Int, Int) -> String // from the index, that many graphemes, clipped to the string; a negative index or count is 0
String.padStart : (String, Int, String) -> String // the third's copies in front until the size is the second, the last cut to fit; an empty third adds none
String.padEnd : (String, Int, String) -> String // the third's copies at the end, as padStart puts them in front
String.repeat : (String, Int) -> String // n times; n below 0 is 0
String.trim : (String) -> String // without leading and trailing whitespace
String.trimStart : (String) -> String // without leading whitespace
String.trimEnd : (String) -> String // without trailing whitespace
String.toLower : (String) -> String
String.toUpper : (String) -> String
String.lines : (String) -> List(String) // at each line feed and each carriage return with a line feed; a line's end at the end adds no empty line, and "" has no lines
String.words : (String) -> List(String) // the parts between runs of White_Space, none empty
String.split : (String, String) -> List(String) // at each occurrence of the second; an empty second gives the first alone
String.join : (List(String), String) -> String // the second between the parts
String.toInt : (String) -> Optional(Int) // the digits 0 to 9, with an optional leading -
String.toIntBase : (String, Int) -> Optional(Int) // in that base, 2 to 36, its digits and letters in either case, with an optional leading -; None outside
String.toBool : (String) -> Optional(Bool) // "true" or "false"; None for anything else
String.toFloat : (String) -> Optional(Float) // §2.5's float without _, with an optional leading -; None for anything else and beyond the finite range of §3.1; below the smallest subnormal, the nearest Float, 0.0 included
String.toList : (String) -> List(Char)
String.fromList : (List(Char)) -> String
String.toUtf8 : (String) -> Bytes
String.fromUtf8 : (Bytes) -> Optional(String) // None when the bytes are not UTF-8
```

### Appendix E.6. `char.ern` (namespace `Char`)

The predicates use the Unicode properties of the code point: `isDigit` is general category Nd, `isAlpha` is category L, `isSpace` is White_Space, `isUpper` is Lu, `isLower` is Ll. `isAsciiDigit` is the digits `0` to `9` alone, those `String.toInt` reads (E.5). `Char.compare` orders by code point; it is the prelude's, §9.6, and this module provides it (§9). The primitives are the predicates `isAlpha`, `isDigit`, `isLower`, `isSpace`, and `isUpper`, `toUpper`, `toLower`, `toString`, `toInt`, and the conversion `fromInt` makes once it has checked its code point, which is private to the module (E.0 rule 1); the rest is Ernest over them.

```
Char.isDigit : (Char) -> Bool
Char.isAsciiDigit : (Char) -> Bool // one of the digits 0 to 9, those String.toInt reads (E.5)
Char.digitValue : (Char, Int) -> Optional(Int) // its value as a digit in the base, 2 to 36: 0 to 9, then a letter in either case 10 to 35, as Int.toStringBase writes them; None for no digit of the base, or a base outside 2 to 36
Char.isAlpha : (Char) -> Bool
Char.isSpace : (Char) -> Bool
Char.isUpper : (Char) -> Bool
Char.isLower : (Char) -> Bool
Char.toUpper : (Char) -> Char // itself when it has no single upper-case form
Char.toLower : (Char) -> Char // itself when it has no single lower-case form
Char.toString : (Char) -> String
Char.toInt : (Char) -> Int // the code point
Char.fromInt : (Int) -> Optional(Char) // None outside U+0000 to U+10FFFF or for a surrogate
```

### Appendix E.7. `bool.ern` (namespace `Bool`)

```
Bool.not : (Bool) -> Bool
Bool.toString : (Bool) -> String // "true" or "false"
```

### Appendix E.8. `int.ern` (namespace `Int`)

`Int.compare`, `Int.negate`, and the operators are the prelude's, §9.6; this module provides them (§9). The primitives are `bitAnd`, `bitOr`, `bitXor`, `bitNot`, `shiftLeft`, `shiftRight`, `toString`, `toFloat`, and the writing in a base that `toStringBase` makes once it has checked the base, which is private to the module (E.0 rule 1); the rest is Ernest over them.

```
Int.abs : (Int) -> Int
Int.min : (Int, Int) -> Int
Int.max : (Int, Int) -> Int
Int.div : (Int, Int) -> Optional(Int) // a / b, None where b is 0
Int.rem : (Int, Int) -> Optional(Int) // a % b, with the sign of a, None where b is 0
Int.bitAnd : (Int, Int) -> Int
Int.bitOr : (Int, Int) -> Int
Int.bitXor : (Int, Int) -> Int
Int.bitNot : (Int) -> Int
Int.shiftLeft : (Int, Int) -> Int // times two to the power of the second; a second below 0 is none
Int.shiftRight : (Int, Int) -> Int // arithmetic, sign-preserving; a second below 0 is none
Int.pow : (Int, Int) -> Optional(Int) // exact; None for a negative exponent; Int.pow(0, 0) is Some(1)
Int.toString : (Int) -> String
Int.toStringBase : (Int, Int) -> Optional(String) // in that base, 2 to 36, with upper-case letters; None outside
Int.toFloat : (Int) -> Float // faults outside the finite range, §3.1
```

### Appendix E.9. `float.ern` (namespace `Float`)

`Float.compare`, `Float.negate`, and the operators are the prelude's, §9.6; this module provides them (§9). The module holds the operations of the type itself. The primitives are `toString`, `truncate`, `floor`, `ceil`, and the functions of the host's floating-point library beneath `sqrt`, `pow`, `exp`, `log`, `sin`, `cos`, `tan`, `asin`, `acos`, `atan`, and `atan2` (E.0 rule 1). `Float.toString` gives the shortest digits that read back as the same value. From 0.0001 to below 1.0e16 in magnitude, and at `0.0`, it writes them plain, with at least one digit after the point: `0.001`, `123.0`. Beyond, it writes one digit, the point, at least one more digit, and the exponent: `1.0e16`, `1.5e-7`. The exponent's sign is written only when it is negative. Mathematics over collections of floats, statistics, matrices, and numerical methods, is a library.

```
Float.abs : (Float) -> Float
Float.min : (Float, Float) -> Float
Float.max : (Float, Float) -> Float
Float.toString : (Float) -> String // the shortest digits that read back as the same value
Float.round : (Float) -> Int // to the nearest, ties to even
Float.truncate : (Float) -> Int // toward zero
Float.floor : (Float) -> Int
Float.ceil : (Float) -> Int
Float.sqrt : (Float) -> Optional(Float) // None below zero
Float.pow : (Float, Float) -> Optional(Float) // None for a negative base with a fractional exponent, and for zero to a negative power; faults beyond the finite range
Float.exp : (Float) -> Float // faults beyond the finite range
Float.log : (Float) -> Optional(Float) // the natural logarithm; None at zero and below
Float.pi : Float // the ratio of a circle's circumference to its diameter, the nearest Float to it
Float.sin : (Float) -> Float // radians, as the other trigonometric functions
Float.cos : (Float) -> Float
Float.tan : (Float) -> Float
Float.asin : (Float) -> Optional(Float) // None outside -1.0 to 1.0
Float.acos : (Float) -> Optional(Float) // None outside -1.0 to 1.0
Float.atan : (Float) -> Float
Float.atan2 : (Float, Float) -> Float // the angle of the point #(x, y), the y first
```

### Appendix E.10. `optional.ern` (namespace `Optional`)

```
Optional.isSome : (Optional(a!)) -> Bool
Optional.isNone : (Optional(a!)) -> Bool
Optional.withDefault : (Optional(a!), a!) -> a!
Optional.map : (Optional(a), (a) -> b with e) -> Optional(b) with e
Optional.andThen : (Optional(a), (a) -> Optional(b) with e) -> Optional(b) with e
```

### Appendix E.11. `either.ern` (namespace `Either`)

```
Either.isLeft : (Either(e!, a!)) -> Bool
Either.isRight : (Either(e!, a!)) -> Bool
Either.withDefault : (Either(e!, a!), a!) -> a!
Either.map : (Either(e, a), (a) -> b with x) -> Either(e, b) with x
Either.mapLeft : (Either(e, a), (e) -> b with x) -> Either(b, a) with x
Either.andThen : (Either(e, a), (a) -> Either(e, b) with x) -> Either(e, b) with x
Either.toOptional : (Either(e!, a)) -> Optional(a)
Either.fromOptional : (Optional(a), e!) -> Either(e!, a)
```

### Appendix E.12. `foreign.ern` (namespace `Foreign`)

`Term` is the foreign type of any value of the runtime (§3.8). Its functions are primitives (E.0 rule 1). `from` gives its value as a foreign function's argument of the value's type crosses (§8.4), by the type at which the name is used, as a callee or an argument, which is known whole there, as `Io.show`'s is (E.1). On a type variable, and on a type that contains one, it is a type error, and no requirement names it.

```
foreign type Term
Foreign.from : (a!) -> Term // the value as it crosses into foreign code, at the use's type (§8.4)
Foreign.toInt : (Term) -> Optional(Int)
Foreign.toFloat : (Term) -> Optional(Float)
Foreign.toString : (Term) -> Optional(String) // a binary that is not UTF-8 is None
Foreign.toBytes : (Term) -> Optional(Bytes) // any binary
Foreign.toBool : (Term) -> Optional(Bool)
Foreign.toList : (Term) -> Optional(List(Term))
```

### Appendix E.13. `random.ern` (namespace `Random`)

The generator is SplitMix64, written in Ernest over `Int`'s bit operations. `Seed` is an abstract type made by `seed`: a seed is a value like any other and crosses nodes, and the same seed gives the same sequence everywhere. A program that wants a fresh seed takes `Clock.now()`.

```
abstract type Seed
Random.seed : (Int) -> Seed // numbers equal in their low 64 bits name the same sequence
Random.next : (Seed, Int) -> #(Int, Seed) // uniform between 0 and the second inclusive, whatever the second's sign, and the seed after it
Random.nextFloat : (Seed) -> #(Float, Seed) // uniform above 0.0 and below 1.0, and the seed after it
```

### Appendix E.14. `path.ern` (namespace `Path`)

`Path` is `Path(String)`, §9.3, in the runtime's syntax. `Path.<>` is the prelude's, §9.6; this module provides it (§9). The primitives are `isAbsolute` and `separator`, the host's separator, which is private to the module (E.0 rule 1); the rest is Ernest over `String`. `under` reads the path's text alone: a link under the root that leads out of it is the file system's (E.17).

```
Path.join : (List(String)) -> Path // the segments as a path, the inverse of split: a root first stays a root, one separator between the others
Path.split : (Path) -> List(String) // the segments; an absolute path's first is the root
Path.parent : (Path) -> Optional(Path) // None for a bare name or the root
Path.name : (Path) -> Optional(String) // the last segment, None for the root, which has none
Path.extension : (Path) -> Optional(String) // after the last "." of the name, without it; the dots that begin the name begin none
Path.withExtension : (Path, String) -> Path // replaced or added, the rest as written; an empty one leaves the dot; the root, "." and ".." are left as they are
Path.withoutExtension : (Path) -> Path // removed, the rest as written; the root, "." and ".." are left as they are
Path.under : (Path, Path) -> Optional(Path) // the second under the first, where it is relative and each segment names an entry: None for an absolute or empty path, or one with a "." or ".." segment
Path.isAbsolute : (Path) -> Bool
Path.toString : (Path) -> String
```

### Appendix E.15. `clock.ern` (namespace `Clock`)

Over the clock's system reference (§8.2). The primitives are `now`, `alarm` and `alarmAt`, which reach the clock's process, and `monotonic`, which reads the host's monotonic clock (E.0 rule 1). Times are milliseconds since the epoch, by the host's clock, which may be set while the program runs. `monotonic` is milliseconds since a moment the runtime chose, and never goes back. The difference of two readings of `monotonic` is the time the host ran between them: where the host's monotonic clock stops while the machine is suspended, that time is left out. The difference of two `now`s is not that time when the clock is set between them. An alarm after milliseconds counts them as `monotonic` does, and setting the clock does not move it. An alarm at a time fires when the clock reaches the time, though the clock is set before it fires: a clock set past the time fires it once the host reports the change, and a clock set back delays it. An alarm fires once, and a program cannot cancel it: a process that no longer wants it ignores the message, and a periodic tick is scheduled after the previous one is handled. A restart of the process that set it cancels it (§6.9).

```
Clock.now : () -> Int with m+
Clock.monotonic : () -> Int with m+
Clock.alarm : (Int, (Int) -> m) -> Unit with m // after the milliseconds, wrap(time) in the caller's mailbox, time the time it fired
Clock.alarmAt : (Int, (Int) -> m) -> Unit with m // at the time, wrap(time) in the caller's mailbox, time the time it fired
```

### Appendix E.16. `terminal.ern` (namespace `Terminal`)

Over the terminal's system reference (§8.2). The primitives are `subscribe` and `size`, which reach the terminal's process (E.0 rule 1). `columns` is Ernest over a table built from Unicode's East Asian Width, emoji, and general category data, of the version the host's grapheme segmentation follows. It counts a grapheme by its first code point that is no combining mark, format character, or control: two for one East Asian Wide or Fullwidth or of emoji presentation, or an extended pictographic one followed by U+FE0F, and one for any other. A grapheme only of combining marks, format characters, and controls takes none, a tab among them, whose width is the caller's. An escape sequence takes none: `ESC [` to its final byte, or `ESC` and the byte after it. The terminal speaks ECMA-48: `subscribe` decodes its keys from it, and `columns` reads its sequences in a string; the library `Ansi` writes them (Appendix G.3). `Event` names what the runtime decodes whole, a character, the four arrows, `Escape`, the interrupt, a paste and a resize; every other sequence arrives as `Escape` and its characters, from which a library names the rest.

```
type Size = Size(rows : Int, columns : Int)
type Event =
    Key(Char) | ArrowUp | ArrowDown | ArrowLeft | ArrowRight | Escape | Interrupt
  | Pasted(String) | Resized(Size)
Terminal.subscribe : ((Event) -> m) -> Either(Io.Error, Unit) with m // every key pressed and every resize from now on, wrapped, in the caller's mailbox; a second call replaces the first; Left(NotATerminal) where standard input is not a terminal
Terminal.size : () -> Either(Io.Error, Size) with m+ // the terminal's size now; Left(NotATerminal) where standard output is not a terminal
Terminal.columns : (String) -> Int // the columns the text takes at a terminal: an escape sequence none, a wide or emoji grapheme two, a grapheme only of combining marks, format characters and controls none
```

### Appendix E.17. `fs.ern` (namespace `Fs`)

Over the file system's system reference (§8.2). Every function is a primitive, reaching the file system's process (E.0 rule 1). A `Left(Timeout)` does not undo the request: a write, a rename or a removal that answered it may still take place. A relative path names a file under the working directory, `Os.workingDirectory` (Appendix E.23). A path that holds U+0000 names no file, and each function answers `Left(Invalid)` for it. `read`, `readRange`, `write`, and `copy` work on regular files: a path that names anything else, a directory, a named pipe, a device, or a socket, answers `Left(NotAFile)`. `append` works on a regular file and on a device, a terminal among them, and answers `Left(NotAFile)` for a directory, a named pipe, or a socket. The path `write` and `append` take, and the second path of `copy`, may name nothing, and the file is then created. A file is created with the permission bits the host's mask leaves of `0o666`. One that no other user may read is made in a directory only its owner may enter, whose mode `setMode` sets before the file is made. A function follows the symbolic links of the paths it is given, but for a path's last segment where it names a link: `list` describes each entry as it is, a link as a `Link`, and `remove`, `rename`, and `readLink` act on the link itself. Each `Other` in an answer here is `Io.Error`'s, which says why, and not `Kind`'s, which is a kind of entry. `makeLink`, `makeHardLink` and `makeFile` answer `Left(Exists)` where the path they make names something, and `readLink` answers `Right(None)` for a path that names anything but a link and `Left(NotUtf8(target))` for a link whose target is not. `makeHardLink` makes a second name for a regular file: a second path that names anything else, a link among them, answers `Left(NotAFile)`. `removeAll` faults its caller where the runtime's helper fails, as `Os.start` does (Appendix E.23). `removeAll` walks a directory by the directories it has opened, never by a path: each entry is opened refusing a link and removed from its directory, and a directory another process replaces with a link while the walk runs is not followed. It waits the milliseconds it is given once, for the whole removal.

```
type Kind = File | Directory | Link | Other // Other: a named pipe, a device, or a socket
type Entry = Entry(path : Path, mtime : Int, size : Int, kind : Kind, mode : Int, user : Int) // mtime in milliseconds since the epoch, as Clock.now, read to the second and so a multiple of 1000; size in bytes; mode the permission bits, as setMode takes them; user the host's number for the user the file belongs to, as Os.user is the program's
Fs.read : (Path, Int) -> Either(Io.Error, Bytes) with m+ // the whole file, however large
Fs.readRange : (Path, Int, Int, Int) -> Either(Io.Error, Bytes) with m+ // up to count bytes from offset, fewer at the end of the file and none past it; an offset or a count below 0 is none
Fs.write : (Path, Bytes, Int) -> Either(Io.Error, Unit) with m+ // creates or replaces
Fs.append : (Path, Bytes, Int) -> Either(Io.Error, Unit) with m+ // creates or extends a file, or writes to a device
Fs.list : (Path, Int) -> Either(Io.Error, List(Entry)) with m+ // the entries of a directory but `.` and `..`, in unspecified order, each entry's path the directory's path joined with the entry's name, each described as it is; a name that is not UTF-8 answers `Left(NotUtf8(name))`, the first such in the order of their bytes (§8.2), and an entry gone before it is described is left out
Fs.stat : (Path, Int) -> Either(Io.Error, Entry) with m+ // what the path leads to, its links followed
Fs.makeDir : (Path, Int) -> Either(Io.Error, Unit) with m+ // with its missing parents; an existing directory is not an error
Fs.remove : (Path, Int) -> Either(Io.Error, Unit) with m+ // a file, a link, or an empty directory
Fs.rename : (Path, Path, Int) -> Either(Io.Error, Unit) with m+ // the first to the second
Fs.copy : (Path, Path, Int) -> Either(Io.Error, Unit) with m+ // a file, the first to the second; replaces
Fs.makeLink : (Path, Path, Int) -> Either(Io.Error, Unit) with m+ // a symbolic link at the first path to the second, which may name nothing
Fs.makeHardLink : (Path, Path, Int) -> Either(Io.Error, Unit) with m+ // a hard link at the first path to the regular file the second names, a second name for it
Fs.readLink : (Path, Int) -> Either(Io.Error, Optional(Path)) with m+ // the path a symbolic link holds, as it was written
Fs.makeFile : (Path, Bytes, Int) -> Either(Io.Error, Unit) with m+ // a new file, or none where the path names something
Fs.removeAll : (Path, Int) -> Either(Io.Error, Unit) with m+ // a directory and everything under it, or a file or a link; a link is removed, not followed
Fs.setModified : (Path, Int, Int) -> Either(Io.Error, Unit) with m+ // the modification time, in milliseconds since the epoch, kept to the second; Left(Invalid) for one past the host's 64-bit seconds, and one past the file system's range kept as the file system keeps it
Fs.setMode : (Path, Int, Int) -> Either(Io.Error, Unit) with m+ // the permission bits, as the host writes them, 0o600; a mode outside 0 to 0o7777 is Left(Invalid)
```

### Appendix E.18. `tcp.ern` (namespace `Tcp`)

Over TCP's system reference (§8.2). The primitives are `listen` and `connect`, which reach TCP's process (E.0 rule 1); the rest are Ernest over the prelude's sends and calls to the process of the listener or the socket they are given. A socket is a process: its address can be sent and killed like any other, and its process monitored. Sockets and listeners are foreign processes (§8.4) but not system processes, so `Process.live`, `Process.info` and `Process.faults` include them. The site of a listener is `Tcp.listen`, and of a socket `Tcp.accept` or `Tcp.connect`, the function that opened it (§6.9), with no line. It is owned by the process that opened it, the caller of `listen`, `accept` or `connect`, and `give(socket, process)` makes another a socket's owner. It lives until `Tcp.close`, until it is killed, until its owner dies, which kills it as a running program's is killed (Appendix E.23), or until the program ends; a socket given to a process that has ended is killed at once, and a restart is no death (§6.9). After its connection closes, from either end or by a failure, each `Tcp.read` answers `Left(Closed)`. A listener lives until `Tcp.closeListener`, until it is killed, until its owner dies, or until the program ends; closing it answers an `accept` waiting on it with `Left(Closed)`. `close` and `closeListener` answer each read, write or accept the socket or the listener has taken and holds waiting with `Left(Closed)` and end its process; the bytes of a write so answered may have been taken, and are then sent as below. `kill` ends it as it ends any process, a call waiting on it faulting as §6.6 says, and a listener's host socket closes either way. However a socket ends, by `close`, by `kill`, by its owner's death or by the program's end, the bytes it has taken that the far end has not are sent while the far end takes them, until the runtime stops. Those the far end has not taken 5 seconds after the end or after the last bytes it took, or 3 minutes after the end, are dropped and the connection is reset. The host's socket then closes. On a socket or a listener that has ended, a function that waits for its answer, `read`, `write`, `accept`, `port`, `remote`, or `local`, faults the caller as `Address.callForever` does (§6.6): with `Fault("callee was closed")` where the program's close ends it while the call waits in its mailbox, not yet taken, and with `Fault("callee had ended")` where it had ended before the call; `close`, `give` and `closeListener` do nothing. `Tcp.write` answers `Right(Unit)` once the socket has taken the bytes, and waits while the connection is behind, at most the milliseconds it is given; a write that waits holds up no read of the socket. A `Left(Timeout)` does not undo the write: the bytes may still be sent, after those written before. A write after the connection has closed, from either end or by a failure, answers `Left(Closed)`, and one the host refuses for another reason answers `Left(Other(text))`, the host's reason. A port outside 0 to 65535, and a host that holds U+0000, which names none, answer `Left(Invalid)`. A read, an accept, or a connect that times out has taken nothing: bytes that arrive later wait for the next read, and a connection that completes later is closed. There are no options.

```
abstract type ListenerMsg // what a listener takes
abstract type SocketMsg // what a socket takes
type Endpoint = Endpoint(host : String, port : Int)
Tcp.listen : (String, Int) -> Either(Io.Error, Address(ListenerMsg)) with m+ // host, port: the interface the host's name or address names, `"127.0.0.1"` the loopback alone and `"0.0.0.0"` or `"::"` every one; port 0 asks the system for a free one
Tcp.port : (Address(ListenerMsg)) -> Either(Io.Error, Int) with m+ // the port it listens on
Tcp.accept : (Address(ListenerMsg), Int) -> Either(Io.Error, Address(SocketMsg)) with m+
Tcp.connect : (String, Int, Int) -> Either(Io.Error, Address(SocketMsg)) with m+ // host, port
Tcp.read : (Address(SocketMsg), Int) -> Either(Io.Error, Bytes) with m+ // what has arrived, at least one byte
Tcp.write : (Address(SocketMsg), Bytes, Int) -> Either(Io.Error, Unit) with m+
Tcp.close : (Address(SocketMsg)) -> Unit with m+
Tcp.give : (Address(SocketMsg), Process) -> Unit with m+ // makes the process the socket's owner
Tcp.closeListener : (Address(ListenerMsg)) -> Unit with m+ // stops listening
Tcp.remote : (Address(SocketMsg)) -> Either(Io.Error, Endpoint) with m+ // the connection's far end
Tcp.local : (Address(SocketMsg)) -> Either(Io.Error, Endpoint) with m+ // the connection's near end
```

### Appendix E.19. `erl.ern` (namespace `Erl`)

What a shim over an Erlang API needs from Erlang's conventions (rule 1). An API that answers `{ok, V}` or `{error, R}` needs an Erlang helper that rewrites the answer to `Either`'s encoding, `{'Right', V}` or `{'Left', R}` (§8.4). An atom `atom` makes is never freed while the node lives, and a node holds at most a number of atoms its host fixes, so `atom` is given the names a shim needs, never text a program receives. A text longer than 255 characters makes no atom, and `atom` faults as a foreign function that raises does (§7.4).

```
Erl.atom : (String) -> Foreign.Term // the Erlang atom of the text
```

### Appendix E.20. `bytes.ern` (namespace `Bytes`)

A `Bytes` is a container read through `toList`, which gives each octet as an `Int` from 0 to 255: of the container operations it provides `size`, `isEmpty`, `contains`, `get`, `fromList`, and `toList`, and the rest go through `toList`. `Bytes.<>` is the prelude's, §9.6; this module provides it. `<<...>>` builds and matches a `Bytes` at the bit level (§5.11), so there is no constructor here. The primitive is `size` (E.0 rule 1); the rest is written over it and with the bit syntax, `slice` among them. The functions `String` has for text, a search, a split, a replacement and their like, are `Bytes`' too, for octets, under the same names. `toHex` and `fromHex` are one encoding, Bytes written as text, whose two directions stand in the module of what is encoded, as `String.toUtf8` and `String.fromUtf8` stand in `String`'s.

```
Bytes.size : (Bytes) -> Int // octets
Bytes.isEmpty : (Bytes) -> Bool
Bytes.get : (Bytes, Int) -> Optional(Int) // the octet at the index from 0
Bytes.slice : (Bytes, Int, Int) -> Bytes // from the index, that many octets, clipped; a negative index or count is 0
Bytes.toList : (Bytes) -> List(Int)
Bytes.fromList : (List(Int)) -> Optional(Bytes) // None when a value is outside 0 to 255
Bytes.contains : (Bytes, Bytes) -> Bool // an empty second is always there
Bytes.indexOf : (Bytes, Bytes) -> Optional(Int) // where the second first begins, None where it is not there; an empty second is 0
Bytes.lastIndexOf : (Bytes, Bytes) -> Optional(Int) // where the second last begins, None where it is not there; an empty second is the size
Bytes.startsWith : (Bytes, Bytes) -> Bool // true for an empty second
Bytes.endsWith : (Bytes, Bytes) -> Bool // true for an empty second
Bytes.split : (Bytes, Bytes) -> List(Bytes) // at each occurrence of the second; an empty second gives the first alone
Bytes.replace : (Bytes, Bytes, Bytes) -> Bytes // every occurrence of the second by the third; an empty second changes nothing
Bytes.join : (List(Bytes), Bytes) -> Bytes // the second between the parts
Bytes.repeat : (Bytes, Int) -> Bytes // n times; n below 0 is 0
Bytes.toHex : (Bytes) -> String // two hexadecimal digits an octet, with upper-case letters
Bytes.fromHex : (String) -> Optional(Bytes) // two digits an octet, in either case; None for an odd count or another character
```

### Appendix E.21. `process.ern` (namespace `Process`)

`Process` is the prelude's (§9.1), and this module provides its operations. The primitives are `fromAddress`, `info` and `live`, which read the runtime's record of its processes, and a private one beneath `faults`, which reaches the runtime's report of faults (E.0 rule 1). A `Process` is the identity of a process. It has equality and no ordering, exact as §3.10 says, and nothing can be sent to it; `monitor` takes one (§6.9). Across nodes a `Process` names its node. `info` is a snapshot of a live process, which may have changed when it is read. It answers `None` for a process that has ended (§6.9) and for one on another node. `live` answers the processes the runtime started that have not ended, the system processes excepted: those a program spawned, and a listener, a socket or a running program a system module opened (Appendix E.18, E.23). `faults(wrap)` delivers `wrap(r)` to the caller for every fault of every process the runtime started, the system processes' excepted, as E.0 shape rule 8 says of a function that delivers later. A process holds one subscription to faults, beside one to the terminal (§8.2): a second call replaces the first, its wrap from then on, and a subscription ends when its process dies or restarts (§6.9). A subscription to faults is no source that can deliver under §8.6. In a `FaultReport`, `restarted` is `true` where the process restarts after the fault (§6.9), and `trace` is the innermost twelve frames of the host's stack beneath a failure in the runtime or a foreign function's raise, a function to a line, and empty beneath a cause of §7.4.

```
type Info = Info(site : String, queued : Int, activity : Activity)
type Activity = Running | Receiving | Calling
type FaultReport = FaultReport(process : Process, site : String, cause : String, restarted : Bool, trace : String)
Process.fromAddress : (Address(m)) -> Process // the process behind the address, through every via
Process.info : (Process) -> Optional(Info) with m+ // its spawn site (§6.9), the messages in its mailbox, and whether it runs, waits in a receive, or waits for a call's answer; None once it has ended
Process.live : () -> List(Process) with m+ // in unspecified order
Process.faults : ((FaultReport) -> m) -> Unit with m // every fault from now on, wrapped, in the caller's mailbox
```

### Appendix E.22. `supervisor.ern` (namespace `Supervisor`)

A supervisor restarts a group of processes, its children, together. The primitives are `askRestart`, the restart a supervisor asks of a child, `spawnOrder`, the order in which the children were spawned, and `startCause`, why a restarting function began, each private to the module (E.0 rule 1); the rest is Ernest over them and the prelude. `group(strategy, limit)` spawns the process that keeps the group's children, which a supervisor's restart does not end, and answers the function a supervisor runs; the first process that runs it is the group's supervisor, and another that runs it, while the first runs or after it has ended, faults with `Fault("a group runs in one process")`. `child(supervisor, f)` is the function a child runs. The caller spawns the supervisor and each child: a child's site (§6.9) and its place are the caller's, and a service binding names it (§6.5). A child joins the group when it starts, before `f` runs, and waits until the supervisor has it; a child whose supervisor has ended faults with `Fault("the supervisor has ended")`. A supervisor and its children run on one node: a child whose supervisor is on another node faults with `Fault("a child runs on its supervisor's node")` before it joins, and between nodes a process watches another with `monitor`. After a fault it runs `f` again in place, as `restarting` does (§6.9), until the group gives up; its supervisor counts the fault before `f` runs again. A child at whose fault the group gives up runs nothing more until the group's end kills it or the supervisor, restarted in place, restarts it; one whose supervisor has ended by then is killed as the group's end kills the others. A child joins at any time, and a child that returns or is killed leaves the group. The strategy says what else a child's fault restarts: `OneForOne` nothing, `OneForAll` every other child, and `RestForOne` the children spawned after it, in the order the runtime spawned their processes, whatever order they joined in. Those are restarted as §6.9 says of a restart a supervisor asks for. A child that has not yet begun its first run of `f` is not asked, and one that faults before it takes the restart has restarted by its fault. The child whose fault restarts them runs `f` again once each of them has restarted or ended, so that a call to it after its fault is answered by the group restarted whole. A sibling that computes without waiting takes no restart until it waits (§6.9), and the child waits with it. When the children's faults pass `limit`, counted as `restarting` counts them, the supervisor faults with `Fault("supervisor restart limit reached")`. A supervisor that is itself a child restarts in place, after its own fault or when its parent asks, and asks each of its children to restart; they keep their order. When a supervisor dies, killed, faulted, or of a defect of its own, a process the module spawns beside it kills its children in the reverse of the order they were spawned, each once the one before has ended, and `kill(sup)` stops a group.

```
type Strategy = OneForOne | OneForAll | RestForOne
abstract type Msg // what a supervisor takes
Supervisor.group : (Strategy, RestartLimit) -> (() -> Unit with Msg) with m+
Supervisor.child : (Address(Msg), () -> Unit with m+) -> () -> Unit with m+
```

### Appendix E.23. `os.ern` (namespace `Os`)

Over Os's system reference (§8.2). The primitives are `start`, which reaches Os's process, `exit`, which ends the program through the host, and `arguments`, `user`, `workingDirectory` and `environment`, bound from what the host gives at start (E.0 rule 1). `read`, `write`, `closeInput` and `give` are Ernest over the prelude's sends and calls to a running program's process, and `run` over `start`, `closeInput` and `read`. `arguments` is the words after the module on `ern run`'s command line (§11.2), `workingDirectory` is the absolute path of the directory the program was started in, and `user` is the host's number for the user the program runs as, which an entry of `Fs` is compared with (E.17), each bound when the program starts. Nothing in Ernest changes the working directory. A relative path given to `Fs`, or as a program's name to `start`, is resolved against it. A working directory the host can no longer read as the program starts, one removed since, faults `workingDirectory`'s initializer, which ends every program before `main` runs (§7.4, §8.5). `environment(name)` answers the value of the program's environment variable of that name, or `None` where the host has none. The program's environment is the one `ern` was started in (§11). It is read once, when the program starts, and a value is decoded when it is asked for: one that is not UTF-8 faults the caller with `Fault("the environment variable n is not UTF-8")`, `n` its name. A name that occurs twice keeps its first value. `exit(status)` ends the program as §8.6 ends it, with that status, and does not return; a status outside 0 to 255 faults the caller (§7.4). In the shell and under `ern test` it faults the caller instead (§11.2).

`start(command)` starts a program of the host and answers its address. A running program is a process, as a `Tcp` socket is: `kill` stops it and `monitor` watches it, and its site is `Os.start`. The program is found as the host finds a command: a name without `/` in the directories of `PATH`, and a name with `/` as the path it is. Each argument reaches the program as it is, with no shell between. The program inherits the program's whole environment and its working directory, and starts with every signal as the host first gives it, none ignored and none blocked. It does not share the runtime's standard input: its standard input is `input`, then what `write` gives it, until `closeInput` ends it. A `write` after that, or once the program has closed its standard input or has exited, answers `Left(Closed)`, and its bytes are dropped.

`read(program, ms)` answers the next piece of what the program wrote, `Stdout(bytes)` or `Stderr(bytes)`, in the order the host delivered them, and last `Exited(status)`, once the program has exited and its standard output and standard error have both ended. The host takes the program's output only while a read waits, so a program that no one reads waits on its output. A status other than 0 is answered as `Exited(status)`, not as a `Left`; a program ended by a signal has 128 plus the signal's number as its status. When `ms` milliseconds pass first, `read` answers `Left(Timeout)`, the program running on, and what it writes meanwhile is the next read's. A program runs until it exits or is killed. A program is killed when its process is killed. Its process is owned by the process that called `start`, and `give(program, process)` makes another its owner; it is killed when its owner dies, a program given to a process that has ended at once, and a restart is no death (§6.9). The processes the program started that are still in its process group are killed with it. `write(program, bytes, ms)` answers `Right(Unit)` once the program has taken the bytes, and waits while it is behind, at most `ms` milliseconds; a `Left(Timeout)` does not undo the write. The program's process ends once it has answered `Exited`. A read or a write after its end faults as `Address.callForever` does on an ended process (§6.6), and `closeInput` does nothing.

`start` answers `Left(NotFound)` when the program is not found, `Left(Denied)` when it may not be run, and `Left(Other(text))`, the host's reason, when it cannot start for another. A name or an argument that holds U+0000 cannot reach a program, and `start` answers `Left(Invalid)` for it. Where the runtime's helper fails, as the program starts or later, the failure is the runtime's own (§7.4): the caller of `start`, `read`, or `write` faults with `Fault("the runtime's helper ern_exec failed")`, and a failure as the environment and the user are read ends the program before `main` runs (§8.5).

`run(command, ms)` starts the program, ends its input after `input`, and reads it to its end within `ms` milliseconds of the start: it answers the exit status and all the program wrote to its standard output and to its standard error, the `Left` that `start` or a read answered, or `Left(Timeout)` when the milliseconds pass, the program killed then.

```
type Command = Command(program : String, arguments : List(String), input : Bytes)
type Output = Stdout(Bytes) | Stderr(Bytes) | Exited(Int)
type Finished = Finished(status : Int, stdout : Bytes, stderr : Bytes)
abstract type ProgramMsg // what a running program takes
Os.arguments : List(String)
Os.environment : (String) -> Optional(String) // the variable's value, None where there is none
Os.workingDirectory : Path
Os.user : Int // the host's number for the user the program runs as
Os.exit : (Int) -> a with m+
Os.start : (Command) -> Either(Io.Error, Address(ProgramMsg)) with m+
Os.read : (Address(ProgramMsg), Int) -> Either(Io.Error, Output) with m+
Os.write : (Address(ProgramMsg), Bytes, Int) -> Either(Io.Error, Unit) with m+
Os.closeInput : (Address(ProgramMsg)) -> Unit with m+
Os.give : (Address(ProgramMsg), Process) -> Unit with m+ // makes the process the program's owner
Os.run : (Command, Int) -> Either(Io.Error, Finished) with m+
```

### Appendix E.24. `test.ern` (namespace `Test`)

A top-level `let` of type `Test.Case(m)` is a test, which `ern test` runs in a process whose mailbox type is `m` (§11.2), so that a test may receive as an entry point may (§8.1). Its `run` answers `Passed`, or `Failed` with what went wrong. The module declares these two types and `equal`, which answers `Passed` where its two arguments are equal, and otherwise `Failed("expected e, got a")`, the expected value and the actual one written as `Io.show` writes them (§9.4).

```
type Case(m) = Case(name : String, run : () -> Result with m)
type Result = Passed | Failed(String)
Test.equal : (a=!, a=!) -> Result needs a.show // the actual value first, then the expected one
```

### Appendix E.25. `ordered_set.ern` (namespace `OrderedSet`)

A set in the order of its element type's `compare` (§3.10). `Set(a)` is an abstract type, `OrderedSet.Set(a)` outside the module, and within it hides the prelude's `Set` (§4.2); it holds its elements and nothing else, so a set is data: `==` is structural (§3.10), a set keys a `Map`, and a set is sent as any value is. A function that needs the order declares `needs a.compare` (§4.9), and a call writes nothing for it: `fromList`, `contains`, `put`, `remove`, `union`, `intersection`, `difference` and `isSubset` need it, `map` and `filterMap` need their result's, `b.compare`, and the rest need none. Two elements the order calls `Equal` are one element, and `put` keeps the one already there. An order belongs to an element type: a set in another order is a set of another type, `type Descending = Descending(Int)` with its own `compare`, and two sets of different types cannot meet in `union`. The order of `toList`, `foldLeft`, `foreach`, `find`, `min` and `max`, and the order in which `map`, `filter`, `filterMap`, `any` and `all` meet the elements, is the set's; `min` and `max` are the set's own operations (E.0 rule 3). A set carried into another representation goes through that representation's `fromList` of its `toList`. The set is a sorted list, one shape per set: `put`, `contains` and `remove` are linear in the set's size, `fromList` is a stable sort and one pass, `n log n`, `map` and `filterMap` cost that beside the function's, and `union`, `intersection`, `difference` and `isSubset` are linear in the two sizes. Nothing is a primitive: the module is Ernest over `List` (E.0 rule 1). The element type's `compare` is the program's promise, a total order that says `Equal` only where `==` holds, where the type has `==`; nothing checks it, and an order that breaks it misorders the set. After a code replacement (§6.10) or a reload (§11.2) a set built under the old `compare` is read under the new.

```
abstract type Set(a)
OrderedSet.empty : Set(a)
OrderedSet.size : (Set(a!)) -> Int
OrderedSet.isEmpty : (Set(a!)) -> Bool
OrderedSet.contains : (Set(a!), a!) -> Bool needs a.compare
OrderedSet.put : (Set(a!), a!) -> Set(a!) needs a.compare // an element already there is kept
OrderedSet.remove : (Set(a!), a!) -> Set(a!) needs a.compare // an element not present is not an error
OrderedSet.map : (Set(a), (a) -> b! with e) -> Set(b!) with e needs b.compare
OrderedSet.filter : (Set(a!), (a!) -> Bool with e) -> Set(a!) with e
OrderedSet.filterMap : (Set(a), (a) -> Optional(b!) with e) -> Set(b!) with e needs b.compare
OrderedSet.foldLeft : (Set(a), b, (b, a) -> b with e) -> b with e
OrderedSet.foreach : (Set(a), (a) -> Unit with e) -> Unit with e
OrderedSet.any : (Set(a!), (a!) -> Bool with e) -> Bool with e
OrderedSet.all : (Set(a!), (a!) -> Bool with e) -> Bool with e
OrderedSet.find : (Set(a!), (a!) -> Bool with e) -> Optional(a!) with e // the first in order that satisfies
OrderedSet.fromList : (List(a!)) -> Set(a!) needs a.compare
OrderedSet.toList : (Set(a)) -> List(a) // in order
OrderedSet.min : (Set(a!)) -> Optional(a!) // the first in order
OrderedSet.max : (Set(a!)) -> Optional(a!) // the last in order
OrderedSet.union : (Set(a!), Set(a!)) -> Set(a!) needs a.compare
OrderedSet.intersection : (Set(a!), Set(a!)) -> Set(a!) needs a.compare
OrderedSet.difference : (Set(a!), Set(a!)) -> Set(a!) needs a.compare // the elements of the first not in the second
OrderedSet.isSubset : (Set(a!), Set(a!)) -> Bool needs a.compare // every element of the first is in the second
```

### Appendix E.26. `ordered_map.ern` (namespace `OrderedMap`)

A map from keys to values in the order of the key type's `compare` (§3.10), with E.0 rule 2's vocabulary for a map. `Map(k, v)` is an abstract type, `OrderedMap.Map(k, v)` outside the module, and within it hides the prelude's `Map` (§4.2); it holds its entries and nothing else, so a map is data as E.25's set is. A function that needs the order declares `needs k.compare` (§4.9): `fromList`, `contains`, `get`, `put`, `remove`, `update`, `merge` and `mergeWith` need it, and the rest keep the keys and need none. Two keys the order calls `Equal` are one key, and `put` replaces the value already there. The order of `keys`, `values`, `toList`, `foldLeft`, `foreach` and `find`, and the order in which `map`, `filter`, `filterMap`, `any`, `all` and `mergeWith` meet the entries, is the keys'. The map is a sorted list of pairs, one shape per map: `get`, `put`, `remove` and `update` are linear in the map's size, `fromList` is a stable sort and one pass, `n log n`, and `merge` and `mergeWith` are linear in the two sizes. Nothing is a primitive: the module is Ernest over `List` (E.0 rule 1). The key type's `compare` is the program's promise, as E.25 says of the element type's.

```
abstract type Map(k, v)
OrderedMap.empty : Map(k, v)
OrderedMap.size : (Map(k!, v!)) -> Int
OrderedMap.isEmpty : (Map(k!, v!)) -> Bool
OrderedMap.contains : (Map(k!, v!), k!) -> Bool needs k.compare
OrderedMap.get : (Map(k!, v!), k!) -> Optional(v!) needs k.compare
OrderedMap.put : (Map(k!, v!), k!, v!) -> Map(k!, v!) needs k.compare // replaces an entry with that key
OrderedMap.remove : (Map(k!, v!), k!) -> Map(k!, v!) needs k.compare // a key not present is not an error
OrderedMap.update : (Map(k!, v!), k!, (Optional(v!)) -> v! with e) -> Map(k!, v!) with e needs k.compare // the entry, present or not, replaced by the function's value
OrderedMap.map : (Map(k!, v), (k!, v) -> w with e) -> Map(k!, w) with e
OrderedMap.filter : (Map(k!, v!), (k!, v!) -> Bool with e) -> Map(k!, v!) with e
OrderedMap.filterMap : (Map(k!, v), (k!, v) -> Optional(w) with e) -> Map(k!, w) with e
OrderedMap.foldLeft : (Map(k, v), b, (b, k, v) -> b with e) -> b with e
OrderedMap.foreach : (Map(k, v), (k, v) -> Unit with e) -> Unit with e
OrderedMap.any : (Map(k!, v!), (k!, v!) -> Bool with e) -> Bool with e
OrderedMap.all : (Map(k!, v!), (k!, v!) -> Bool with e) -> Bool with e
OrderedMap.find : (Map(k!, v!), (k!, v!) -> Bool with e) -> Optional(#(k!, v!)) with e // the first in order that satisfies
OrderedMap.merge : (Map(k!, v!), Map(k!, v!)) -> Map(k!, v!) needs k.compare // the second wins for a shared key
OrderedMap.mergeWith : (Map(k!, v!), Map(k!, v!), (k!, v!, v!) -> v! with e) -> Map(k!, v!) with e needs k.compare // for a shared key, the function of the key, the first's value and the second's
OrderedMap.fromList : (List(#(k!, v!))) -> Map(k!, v!) needs k.compare // a later pair wins
OrderedMap.toList : (Map(k, v)) -> List(#(k, v)) // in order
OrderedMap.keys : (Map(k, v!)) -> List(k) // in order
OrderedMap.values : (Map(k!, v)) -> List(v) // in the keys' order
```

## Appendix G. Libraries

Informative. The libraries this project writes, each a directory under `libs/` and a source root of its own, which a program adds to its load path when it is compiled and when it is run (§11.1, §11.2). None is part of the language or of the standard library. Each follows the shape rules E.0 holds a library to and documents itself as shape rule 6 asks. A library written elsewhere follows Appendix D and is not listed here.

### Appendix G.1. `libs/ets` (namespace `Ets`)

Tables of the runtime, Erlang's `ets` tables of type `set`, which Appendix D shows with a shorter documentation. A table holds a value of type `v` at each key of type `k`, and keys are compared as the runtime compares its terms. A table belongs to the process that made it and ends with that process or with `close`, and every operation on a table that has ended faults, as a foreign function that raises does (§7.4). Any process on the node that holds a table reads and writes it, so every operation on one, a read too, carries `with m` (§4.7). `put` replaces the entry a key had, `remove` of a key that is not there does nothing, `clear` leaves the table empty, and `toList` answers the entries in unspecified order.

```
foreign type Table(k=, v)
Ets.new : () -> Table(k=, v) with m+
Ets.put : (Table(k=!, v!), k=!, v!) -> Unit with m+
Ets.get : (Table(k=!, v!), k=!) -> Optional(v!) with m+
Ets.contains : (Table(k=!, v!), k=!) -> Bool with m+
Ets.remove : (Table(k=!, v!), k=!) -> Unit with m+
Ets.size : (Table(k=!, v!)) -> Int with m+
Ets.clear : (Table(k=!, v!)) -> Unit with m+
Ets.close : (Table(k=!, v!)) -> Unit with m+
Ets.toList : (Table(k=!, v!)) -> List(#(k=!, v!)) with m+
```

### Appendix G.2. `libs/markdown` (namespace `Markdown`)

CommonMark 0.31, read into blocks and inlines and laid out as text for a terminal or as a manual page. `parse` reads headings, paragraphs, code blocks, block quotes, lists, and thematic breaks, and inside them code spans, emphasis, strong emphasis, links, images, and hard line breaks. A line ends in a line feed, a carriage return, or both. A tab in a line's indentation, quote marks and list markers reaches to the next multiple of four columns, and one elsewhere, in a code block's content as in text, is kept. An image is read as a `Link`, its description the link's text and its source the address. What `parse` does not read is kept as written: an HTML block is a `Raw` block, and inline HTML, an entity, and a link by reference stay in the text. An HTML block begins with a comment, a declaration, a processing instruction, or a tag alone on its line, and a tag alone does not end a paragraph. Emphasis follows a simpler rule than the specification's: a mark opens before a character other than a space and closes after one, the nearest run of as many marks closes it, and a run of three or more is text. `render` lays the blocks out as rows at most `width` columns wide where a word allows, an empty row between two blocks, with the terminal's styles (Appendix E.16) when the output is `Styled` and each span as it was written when it is `Plain`. `roff` writes the blocks as a manual page in the roff of man(7), which groff and mandoc render: its header and its NAME line from the `Manual`, the blocks before its first heading of level 1 under DESCRIPTION, a heading of level 1 as a section, one of level 2 as a subsection, and a deeper one as a paragraph in bold, its lines filled to the left margin alone and never hyphenated. It lays out and styles the rest as §11.4 says of a manual page, with a thematic break as a row of asterisks and a `Raw` block as written. It writes every character roff would change as roff's escape for it, and the rest in UTF-8, which man-db and mandoc read. `firstSentence` is the first paragraph's text up to the first period a space follows outside emphasis, code spans, and links, or all of it where there is none, and empty where there is no paragraph.

```
type Inline = Text(String) | CodeSpan(String) | Emphasis(List(Inline)) | Strong(List(Inline))
  | Link(text : List(Inline), address : String) | Break
type Block = Heading(level : Int, text : List(Inline)) | Paragraph(List(Inline))
  | Code(info : String, lines : List(String)) | Quote(List(Block))
  | Items(start : Optional(Int), items : List(List(Block))) | Rule | Raw(List(String))
type Output = Plain | Styled
type Manual = Manual(name : String, section : String, summary : List(Inline), source : String,
  title : String)
Markdown.parse : (String) -> List(Block)
Markdown.render : (List(Block), Int, Output) -> List(String)
Markdown.roff : (List(Block), Manual) -> List(String)
Markdown.firstSentence : (List(Block)) -> List(Inline)
```

### Appendix G.3. `libs/ansi` (namespace `Ansi`)

Text that styles what a program writes to a terminal and moves its cursor, Ernest over ECMA-48, the standard the terminal speaks (Appendix E.16). Each answers its sequences as a string a program writes with `Io.print`. `styled` turns its style off after the text by the style's own code, and a style around it stays on. `Bold` and `Dim` are turned off together, by the one code ECMA-48 has for both. `libs/markdown` styles its output for a terminal with it, and so needs it on the load path.

```
type Colour = Black | Red | Green | Yellow | Blue | Magenta | Cyan | White
type Style = Bold | Dim | Italic | Underline | Foreground(Colour)
Ansi.styled : (String, Style) -> String // the text in the style
Ansi.up : (Int) -> String // the cursor up that many rows; "" for a number below 1
Ansi.down : (Int) -> String // the cursor down that many rows; "" for a number below 1
Ansi.left : (Int) -> String // the cursor left that many columns; "" for a number below 1
Ansi.right : (Int) -> String // the cursor right that many columns; "" for a number below 1
Ansi.clearBelow : String // erases from the cursor to the end of the screen
Ansi.clearScreen : String // erases the screen and puts the cursor at its top left
```
