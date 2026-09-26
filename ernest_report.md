# Ernest: Language Report

Revision of 26 September 2026. Rationale, rejected alternatives, and open questions are in [`decisions.md`](docs/decisions.md).

## 0. Introduction

Ernest is a functional language for concurrent programs. It has two concepts: functions, with Hindley-Milner types, and processes with typed mailboxes, the only way to affect the world. Everything else in this report is a rule for how the two show up in each other.

Every function runs inside a process, an execution of a function with a mailbox that receives values of one type. A function that sends, receives, or asks for its own address acts through its process and names its mailbox in its type, `(A) -> B with M`; that is the only mark written on a function type. A function that does not act through its process is pure: its result depends only on its arguments, and it affects nothing. §3 and §6 make this precise; §10 states what the runtime must provide.

Five principles. Principles 2 to 5 are constructive; when following them yields code that surprises, principle 1 overrides.

1. Least surprise decides. A design surprises when a reader who knows the rest of Ernest would predict different code from the same requirement. The resulting code decides, not the rule.
2. One way, one job, in the language and prelude. No variants for the same thing, no two concepts that overlap. The standard library may pair functions for convenience.
3. Nothing invisible. Control flow, communication, and failure are visible in the code or in the type. A top-level binding is visible when its name appears at the use site.
4. Simple to parse: recursive descent, first-token dispatch, small bounded lookahead where the grammar demands it, no backtracking.
5. Small: few concepts, few primitives, few reserved words.

## 1. Notation

The grammar is Wirth-style EBNF. `=` defines, juxtaposition concatenates, `|` separates alternatives, `[ ]` is optional, `{ }` is zero or more, `( )` groups, `.` ends a rule. Uppercase names are non-terminals, lowercase names lexical categories. Terminals are in double or single quotes. `ident`, `conname`, `typename`, `typevar`, `binop`, and the literals are defined in §2. The complete grammar is Appendix A.

## 2. Lexical Elements

### 2.1 Characters

Source text is Unicode in UTF-8; a leading byte-order mark (U+FEFF) is stripped. Whitespace is space (U+0020), tab (U+0009), line feed (U+000A), and carriage return (U+000D); it separates tokens and has no other meaning.

### 2.2 Comments

`//` to end of line and `/* ... */`, which nests, are removed by the lexer and take part in no grammar rule. A block comment's text is not tokenized: the `*/` that closes its outermost `/*` ends it, inside quotes or not. A line ends at a line feed.

`///` to end of line is a doc comment; consecutive `///` lines form a doc block, whose text is CommonMark 0.31. A doc block immediately preceding a declaration, a constructor, or a named field, with no blank line between, is its documentation, extractable by the toolchain, §11.4. A doc block before the first declaration, with a blank line after it, is the module's documentation. Elsewhere it is an ordinary comment.

### 2.3 Identifiers

```
letter   = "a" | ... | "z" | "A" | ... | "Z" .
digit    = "0" | ... | "9" .
hexdigit = digit | "a" | ... | "f" | "A" | ... | "F" .
octdigit = "0" | ... | "7" .
bindigit = "0" | "1" .
lower    = "a" | ... | "z" .
upper    = "A" | ... | "Z" .
ident    = lower { letter | digit | "_" } | "_" ( letter | digit | "_" ) { letter | digit | "_" } .
typename = upper { letter | digit | "_" } .
conname  = typename .
typevar  = ident .
```

`ident` begins with a lowercase letter or `_`; `conname` and `typename` begin with an uppercase letter and are the same token; `typevar` is a lowercase identifier in type position. A reserved word (§2.4) is never an `ident`. `_` alone is the wildcard (§5.10). Identifiers are ASCII, though source text is Unicode. An identifier, a type name, and each segment of a qualified name is at most 255 characters long.

A qualified name is a sequence of uppercase-starting segments followed by a final segment. A final segment that starts lowercase names a function or a value, a final `userop` names an operator, and one that starts uppercase names a constructor: `Net.Http.parse`, `Stack.push`, `Int.+`, `Net.Http.Request`. The dots are namespaces, §4.2.

### 2.4 Reserved words

Eighteen, grouped by role:

| Role                 | Words                                                  |
|----------------------|--------------------------------------------------------|
| Types                | `type`, `abstract`, `with`, `foreign`                  |
| Pattern matching     | `match`, `when`, `receive`, `after`, `as`, `or`        |
| Control flow         | `if`, `then`, `else`                                   |
| Bindings             | `fn`, `let`                                            |
| Visibility           | `export`                                               |
| Literals             | `true`, `false`                                        |

### 2.5 Literals

```
int      = decimal | "0x" hexdigit { [ "_" ] hexdigit } | "0o" octdigit { [ "_" ] octdigit }
         | "0b" bindigit { [ "_" ] bindigit } .
float    = decimal "." decimal [ ( "e" | "E" ) [ "+" | "-" ] decimal ] .
decimal  = digit { [ "_" ] digit } .
char     = "'" ( character | escape ) "'" .
string   = '"' { character | escape } '"' | "`" { rawchar } "`" .
escape   = '\' ( "'" | '"' | '\' | "n" | "r" | "t"
           | "u{" hexdigit [ hexdigit ] [ hexdigit ] [ hexdigit ] [ hexdigit ] [ hexdigit ] "}" ) .
bool     = "true" | "false" .
```

`1` is `Int`, `1.0` and `1.0e-9` are `Float`. A float literal denotes the nearest `Float`, ties to even. A literal whose value rounds beyond the largest finite `Float` is an error, `1.0e400`; one that rounds to zero is `0.0`, `1.0e-400`. Literals carry no sign; `-` is a prefix operator. There are no overloaded literals and no default. `0x`, `0o`, and `0b` begin a hexadecimal, an octal, and a binary integer: `0x10FFFF`, `0o644`, `0b1010`. The prefix is lowercase. An `_` between two digits groups them and is ignored: `1_000_000`, `0xFFFF_FFFF`, `3.141_592`. An `_` anywhere else in a number is an error: `1_`, `1__0`, `0x_FF`. A letter or digit directly after a number is an error: `0b102`, `0x1g`, `12px`.

The escapes:

| Escape       | Meaning                                        |
|--------------|------------------------------------------------|
| `\'`         | single quote                                   |
| `\"`         | double quote                                   |
| `\\`         | backslash                                      |
| `\n`         | line feed (U+000A)                             |
| `\r`         | carriage return (U+000D)                       |
| `\t`         | tab (U+0009)                                   |
| `\u{...}`    | Unicode scalar; one to six hex digits          |

`\u{...}` denotes a Unicode scalar value, U+0000 through U+10FFFF excluding the surrogates U+D800 through U+DFFF. A `character` inside a `char` or `string` literal is any code point other than the enclosing quote, `\`, U+000A, and U+000D. A multi-line string is built with `\n`, by concatenation, or as a raw string. A raw string, `` `\d+\.\d+` ``, is a `String` whose text is taken as written: `rawchar` is any code point other than the backtick, there are no escapes, and it may span lines, a line break in it being a line feed, with a carriage return before it dropped.

### 2.6 Operators and delimiters

```
( ) { } [ ] << >> #( , ; : = <- -> | . .. _
+ - * / % <> :: == != < <= > >= && || |> !
```

Three grammar categories built from the above:

```
binop    = "*" | "/" | "%" | "+" | "-" | "<>" | "::"
         | "==" | "!=" | "<" | "<=" | ">" | ">=" | "&&" | "||"
         | "|>" .
userop   = "+" | "-" | "*" | "/" | "%" | "<>" .
literal  = int | float | char | string | bool .
```

Tokens are formed by max-munch: `>>`, `<-`, `->`, `==`, `!=`, `<=`, `>=`, `&&`, `||`, `|>`, `<>`, `::`, `#(`, `<<`, and `..` are single tokens. So `a<-1` is `a <- 1`; a comparison with a negative number is written `a < -1`. `|` is a delimiter of `match` clauses, sum-type constructors, and `receive` clauses, and never a `binop`.

Prefix `-` is negation and binds tighter than any binary operator. Precedence of the binary operators, highest first:

| Level | Operators              | Associativity |
|-------|------------------------|---------------|
| 1     | `* / %`                | left          |
| 2     | `+ - <>`               | left          |
| 3     | `::`                   | right         |
| 4     | `== != < <= > >=`      | left          |
| 5     | `&&`                   | left          |
| 6     | `\|\|`                 | left          |
| 7     | `\|>`                  | left          |

Only a `userop` can be qualified, `Int.+`, or declared, `fn Distance.+` (§4.8).

## 3. Types

```
Type      = TypeAtom | FnType | ParenType .
TypeAtom  = { typename "." } typename [ "(" Type { "," Type } ")" ]
          | typevar
          | TupleType .
TupleType = "#(" Type { "," Type } ")" .
FnType    = "(" [ Type { "," Type } ] ")" "->" Type [ "with" Type ] .
ParenType = "(" Type ")" .
```

`FnType` and `ParenType` both begin with `(`. A `->` after the matching `)` makes the type an `FnType`; otherwise it is a `ParenType`, which holds exactly one `Type`.

### 3.1 Base types

| Type     | Values                                     |
|----------|--------------------------------------------|
| `Int`    | integers of arbitrary precision            |
| `Float`  | IEEE 754 double precision                  |
| `Char`   | one Unicode scalar value                   |
| `String` | a Unicode string                           |
| `Bytes`  | a sequence of octets                       |
| `Bool`   | `true` or `false`                          |

A Unicode scalar value is a code point other than a surrogate, U+0000 through U+10FFFF without U+D800 through U+DFFF. The prelude declares `Unit`, the one-value type, §9.3; its only value is `Unit`. The empty type is `Never`, §3.7. There are no type aliases.

**Integer arithmetic.** Exact and unbounded. `/` truncates toward zero: `-7 / 3 = -2`. `%` satisfies `(a / b) * b + (a % b) == a`, so `-7 % 3 = -1`. `Int.div` and `Int.mod` (§9.6) use the same convention and return `Optional(Int)` in place of the zero-divisor fault: `Int.mod(-7, 3)` is `Some(-1)`.

**Float arithmetic.** IEEE 754 binary64, round to nearest, ties to even, restricted to the finite range. An operation whose result is not finite faults with cause `Fault("float arithmetic error")`: overflow, division of a non-zero numerator by zero, or `0.0 / 0.0`. Gradual underflow to a subnormal is not a fault. There is no `Infinity`, no `NaN`, and no negative zero: a zero is `0.0`, whether an operation or a negation gives it, or it enters the program from foreign code, from bytes, or from text. A float segment pattern `0.0` matches the bytes of either zero. A float segment pattern does not match the bytes of an infinity or a NaN. `Float.compare`, `Float.round`, `Float.truncate`, `Float.floor`, and `Float.ceil` are total.

`Int` and `Float` do not convert implicitly, and mixing them in an arithmetic expression is a type error; `Int.toFloat`, `Float.round`, `Float.truncate`, `Float.floor`, and `Float.ceil` convert. `Int.toFloat` rounds to the nearest `Float`, ties to even, and faults with cause `Fault("Int out of Float range")` where that rounding gives no finite `Float`. An integer above the largest finite `Float` that rounds down to it does not fault.

### 3.2 Tuples

`#(A, B)` is the type of a tuple and `#(a, b)` its value; tuples of one, two, or more components are all written this way. The tuple is the only positional product type.

### 3.3 Lists

`List(a)` is an immutable linked list. `[]` is the empty list; `x :: xs` prepends `x` to `xs`, and `::` is right-associative, so `[a, b]` is `a :: b :: []`.

### 3.4 Function types

`(A, B) -> C` is the type of a function of two arguments. Arity is part of the type: `(A, B) -> C` and `(#(A, B)) -> C` are different types; the first takes two arguments, the second one tuple. `() -> C` takes no arguments.

`with M` after the result is the mailbox type: the function uses the process it runs in, whose mailbox has type `M`, §6.1. A function type without `with M` is pure.

`with` binds to the nearest arrow. `(A) -> (B) -> C with M` is a pure function returning a function with mailbox `M`. `(A) -> ((B) -> C) with M` is a function with mailbox `M` returning a pure one. The same holds in a return annotation: `fn f() -> (A) -> B with M` returns a function with mailbox `M`; `fn f() -> ((A) -> B) with M` has mailbox `M` itself.

### 3.5 Sum types

Declared with `type`, §4.3. A constructor has no fields, exactly one positional field, or named fields:

```
type Optional(a) = None | Some(a)
type Snapshot = Snapshot(dir : Path, seen : Map(Path, Int))
```

Field names are unique within a constructor, and their declaration order carries no meaning. Positional and named fields are told apart by `:` after the first identifier in a declaration and by `=` in construction and patterns. For storage, hashing, and transport, named fields are placed in *canonical order*, lexicographic ASCII order of their names; field expressions are still evaluated in source order (§5.1).

A named field is *selected* with `e.f`: the field `f` of the value `e`, `snapshot.seen`. A type has the selector `f` when every one of its constructors has a named field `f`, and they have one type, which is the selector's; on any other type `e.f` is a type error. A positional field has no selector. Outside the module that declares an abstract type, its fields have no selectors, as its constructors are not visible there (§4.4). The type of `e` is found as an operator's operand type is (§4.8).

### 3.6 Abstract types

A sum type whose constructors may be mentioned only in the module that declares it, §4.4.

### 3.7 Built-in types

`Address(m)` is an address of a process that receives `m`. `Reply(a)` is a one-shot address for the answer to a request, §6.6. `Never` is the type with no values. It is an ordinary type and unifies with itself alone; a function that never returns and may stand at any type has a type variable as its result, as `todo` has (§9.6). `Foreign` is the type of a value foreign code made and Ernest does not inspect, §8.4 and Appendix E.12. The prelude types are listed in §9.

### 3.8 Foreign types

A type declared `foreign type T` has no constructors: its values are made and used only by foreign functions, §4.7, and can otherwise be held, passed, and sent. Its equality is §3.10's.

A foreign value is bound to the node that made it: transporting a value that transitively contains one to another node faults with cause `Fault("foreign value cannot cross nodes")`. Transport is `spawn(Peer(...), f)`, `send` to a remote address, the result of `remote(f)`, `answer(r, v)` to a caller on another node, and the captures of any shipped closure. The fault is the transporting process's, at the operation that transports: the caller of `spawn`, the sender of `send`, and the process that calls `answer`. The value of `remote(f)` is transported by no process of the program, and a foreign value in it faults the caller of `remote`, as a fault in `f` does (§6.7).

### 3.9 Type variables and polymorphism

Types are inferred according to Hindley-Milner. A `fn` definition and a top-level `let` are generalized over their free type variables; a `let` in a block is not. Type variables in a `fn` signature scope over the whole definition, including the annotations of lambdas, of block `let`s, and of local `fn`s within it. A variable named only in a lambda's annotation is the lambda's own and is not rigid. A variable named only in a block `let`'s annotation is that binding's own and is not rigid. A local `fn`'s signature shares the enclosing signature's variables, and a variable named only in it is the local function's own, rigid and generalized with it as a top-level function's is. Recursive and mutually recursive types are allowed; polymorphic recursion is not, even where the whole signature is written: a recursive call is at the definition's own type. Every type variable in a constructor's fields is a parameter of the type.

**Effect polymorphism.** The mailbox effect of a function type may be a type variable, generalized with the others: `fn apply(f, x) = f(x)` has type `((a) -> b with e, a) -> b with e`. At a call site an effect variable binds to a mailbox type or to pure: `apply(fn(x) = send(a, x), 5)` binds `e` to the mailbox of `send`, `apply(fn(x) = x + 1, 5)` binds `e` to pure. Pure is the absence of `with`; it is not a type. A mailbox type bound this way becomes the caller's. A pure function stands wherever a function of the same type with a mailbox type is expected, and a function with a mailbox type never stands where a pure one is expected. So an expression whose type is a function type without `with` takes a fresh effect variable in its place, which the context binds: with `fn done(n : Int) -> Unit = Unit`, `Upgrade(migrate = double, next = done)` binds it to `CounterMsg` (§6.10). Only the expression's own function type takes one. A function type inside it or inside another type, a parameter's, a result's, or a field's, keeps its effect until an expression has it as its own type, as a call or a selection does.

An effect position is the type after `with`. A value position is an argument, a result, a tuple component, or a type argument whose parameter occurs in a value position of its type's fields. A type argument of a built-in or foreign type is a value position. A variable that occurs only in effect positions ranges over the mailbox types and pure. A variable that also occurs in a value position ranges over types alone: `m` in `self : () -> Address(m) with m` is never pure. This is the only departure from Hindley-Milner in the form of types. Inference asks for an annotation in three places: an operator whose operand type nothing in the definition fixes (§4.8), a block binding whose type keeps a variable nothing resolves (§4.6), and a `<-` whose sum type is still open (§5.5).

The functions of §9.4 and §9.5 whose type has a `with`, and a `foreign fn` whose effect is its own, are *process-only*: their effect variable is treated as if it occurred in a value position, and pure code cannot call them. A `foreign fn`'s effect is its own unless its effect variable is also the effect of one of its parameters' function types, in which case the effect is that callback's and the function is effect-polymorphic: `foreign fn each(m : Map(k, v), f : (k, v) -> Unit with e) -> Unit with e` is pure when `f` is.

A function has one mailbox effect or none. A function that takes two callbacks with independent effects declares each effect: in `fn callBoth(p : (Int) -> Int, e : (Int) -> Unit with n) -> Unit with n`, `p` is pure, `e` has effect `n`, and the function inherits `n`. Two callbacks whose effects are both variables unify to one effect. Two callbacks with different concrete effects are a type error. The combinators of Appendix E are typed by the same rule, `List.map : (List(a), (a) -> b with e) -> List(b) with e`; a pure callback binds `e` to pure, an effectful one to the caller's mailbox.

**Inferred restrictions.** An annotation gives a function's shape: arity, argument types, result, mailbox effect. Three restrictions are inferred from the body and never written. The equality constraint of §3.10 falls on a variable compared with `==`. Process-only is inherited by a function whose body calls a process-only function: `fn wrap(a, v) = send(a, v)` cannot be called from pure code. Not-reply-carrying (§6.6) falls on a type variable of a parameter's type when the body, read with that variable as a reply-carrying type, would break §6.6: use such a value twice or not at all, through a `let` or a pattern as much as by the parameter's name, or put it where §6.6 forbids one. So `fn dup(x) = #(x, x)`, `fn discard(x) = Unit`, `fn keep(x) = { let y = x; Unit }`, and `fn forget(b : Box(a)) -> Unit = Unit` cannot take a reply, and `fn id(x) = x` can. It does not fall on a variable that is also an element of `List`, `Map`, `Set`, `Optional`, or `Either` in a parameter type or the result type, directly or through tuples and those types, since §6.6 already forbids a reply-carrying element there: `Optional.withDefault : (Optional(a), a) -> a` is not restricted. Each is part of the type scheme and travels with the function value through bindings, branches, and compiled interfaces. Each is checked at instantiation, not at definition. The compiler shows them (§11.5). This is the one exception to principle 3.

### 3.10 Equality and ordering

`==` and `!=` are structural and defined for all values except those containing functions or addresses, on which they are a type error. On a value of a foreign type or of `Foreign`, they are the runtime's exact equality on the two representations (§8.4): two references are equal only when they are one reference, and two values that foreign code made as the same term are equal. Ordering is per type, through `compare` in the type's namespace: `Int.compare : (Int, Int) -> Ordering`. For a type a module declares, that is its member `T.compare` (§4.2); a function named `compare` outside the type's namespace gives no ordering. For operand type `T`, `a < b` is `T.compare(a, b) == Less`; `<=`, `>`, and `>=` likewise. They resolve against the operand type as the operators of §4.8 do. A type without `compare` has no ordering, and `<` on it is a type error. The prelude defines `compare` for `Int`, `Float`, `String`, and `Char` (§9.6), and for no other type: `Bool`, `Optional`, and `Path` have no ordering.

A function that applies `==` to a value of a type variable gives that variable an *equality constraint*, inferred and never written; instantiating it with a type that contains a function or an address is a type error at that call site. A foreign type's parameter may carry the constraint (§4.7), and `Map(k=, v)` and `Set(a=)` carry it on `k` and `a` (§9.2). A value of such a type over a type without equality is rejected at its first operation; a type that names one, `Map((Int) -> Int, Int)` in an annotation or a field, is not itself an error. A standard library function that compares elements, `List.contains`, propagates the constraint through its parameter. `fn equal(a, b) = a == b` has type `(a, a) -> Bool` with the constraint on `a`. The constraint is part of the type scheme (§3.9). `let f = equal` carries it, and applying `f` to addresses is an error at that application. `if flag then equal else always`, with `always` unconstrained, carries the union of the branches' constraints. A compiled interface carries it across modules. The check is at the concrete application.

### 3.11 Serialization

Every value can be sent in a message, a function included, and its code travels with it (§8.7). A foreign value does not leave its node (§3.8).

## 4. Declarations and Scope

```
Program     = { Declaration } .
Declaration = [ "export" ] ( TypeDecl | AbstractDecl | FnDecl | LetDecl | ForeignDecl ) .
ForeignDecl = "foreign" ( "type" typename [ "(" ForeignVar { "," ForeignVar } ")" ]
            | "fn" DeclName "(" [ ForeignParam { "," ForeignParam } ] ")" Return "=" string ) .
ForeignVar  = typevar [ "=" ] .
ForeignParam = ident ":" Type .
TypeDecl    = "type" typename [ "(" typevar { "," typevar } ")" ] "="
              Constructor { "|" Constructor } .
Constructor = conname [ "(" ( Type | Field { "," Field } ) ")" ] .
Field       = ident ":" Type .
AbstractDecl  = "abstract" TypeDecl .
FnDecl      = "fn" DeclName "(" [ Param { "," Param } ] ")" [ Return ] "=" Expr .
Param       = Pattern [ ":" Type ] .
Return      = "->" Type [ "with" Type ] .
LetDecl     = "let" DeclName [ ":" Type ] "=" Expr .
Binding     = "let" Pattern [ ":" Type ] ( "=" | "<-" ) Expr .
DeclName    = ident | typename "." ( ident | userop ) .
```

### 4.1 Modules

A *module* is one source file, ending in `.ern`: the unit of compilation and of namespace. Every top-level declaration belongs to exactly one module. The modules' dependencies are acyclic; a cycle is a compile-time error.

### 4.2 Namespaces and visibility

**Files are namespaces.** A file at `a/b/c.ern` under the source root provides the namespace `A.B.C`. Each segment is the path segment with its first letter uppercased: `http.ern` is `Http`, `httpv2.ern` is `Httpv2`. Path segments are one lowercase word (§11.1), so the mapping is one-to-one. The top of the hierarchy, where the prelude lives, is provided by the runtime, not by user code.

**Declarations are local; `export` marks the boundary.** A declaration is written with its local name. `fn parse` in `net/http.ern` is exported as `Net.Http.parse` when marked `export`; otherwise it is private to its module. A use site may write a declaration's qualified name, in its own module as well and exported or not; a declaration never does. Two exported declarations with the same qualified name are an error. The type of an exported declaration, and the field types of an exported type that is not abstract, may not name a type the module keeps private. A function's mailbox type is exempt: an exported entry point may receive a private message type. A type whose values cross the boundary but whose constructors do not is an `abstract type` (§4.4). There is no export list and no `import`.

**Taken namespaces.** A module namespace may not coincide with a namespace of the prelude or the standard library. The prelude's namespaces are `Prelude`, `Sys`, `Address`, and the name of every type §9 lists: `event.ern`, `sys.ern`, and `io.ern` at the source root are errors. The standard library's own source root, shipped with the toolchain, is the exception: its files provide those namespaces. A file under it is compiled with it as the source root (§11.1); another source root is an error.

```
// net/http.ern
export type Request = Request(method : String, path : String)
export fn parse(s : String) -> Optional(Request) = ...
fn helper(x) = ...        // private to net/http.ern
```

**Type members.** A type `T` declared in a module, concrete or abstract, is a nested namespace. Its members are declared with the single prefix `T.`, as in `fn Distance.+` and `let Stack.empty`, and are exported at `Module.T.member`. The namespace belongs to the file that declares the type. A module namespace may not coincide with it: `main/stack.ern` is an error when `main.ern` declares `Stack`. In `main.ern`, `Main.Stack.push` is therefore its own member where it declares `Stack`, and the module `Main.Stack`'s `push` where it does not. The coincidence is exact: `main.ern` may declare `STACK` beside `main/stack.ern`, and a module may declare two types whose names differ only in case.

**Unqualified lookup.** An unqualified name in a body is looked up first among the names bound around it, the innermost first: parameters, `let` bindings, pattern and `receive` variables, and local `fn`s. It is then looked up in the module's declarations, exported or not, then in the type-member namespace of the enclosing declaration, then in the prelude. A name not found there is written qualified. A module may declare a type or constructor with a prelude name, and the name then means the local one throughout the module. `Prelude` names the prelude's own namespace, so `Prelude.Close` is the prelude's `Close` in a module that declares its own. It takes one name the prelude declares. No module and no type is named `Prelude`. Within a module, type names are unique and constructor names are unique across its types.

### 4.3 Type declarations

`type` declares a sum type with its constructors. A constructor has the visibility of its type.

### 4.4 Abstract types

`abstract type T = ...` declares a type whose constructors may appear only in the module that declares it. Every definition of that module may use them, a private one or a test included; another module sees the type and not its constructors. An abstract type is exported: one the module keeps private is an error, since it hides from no other module.

```
// main.ern  (namespace Main)
export abstract type Stack(a) = Stack(List(a))

export let Stack.empty = Stack([])
export fn Stack.push(x, Stack(xs)) = Stack(x :: xs)
export fn Stack.pop(Stack(xs)) = match xs { [] -> None | x :: rest -> Some(#(x, Stack(rest))) }
export fn size(Stack(xs)) = List.size(xs)
```

External callers see `Main.Stack`, `Main.Stack.push`, and `Main.size`; `Stack(...)` is refused outside `main.ern`. A module may declare several abstract types.

### 4.5 Functions

`fn` declares a function of fixed arity. Annotations may be omitted where they can be inferred. The return annotation is omitted, or is `-> T` for a pure function, or `-> T with M` for process code. A pure annotation on a function that calls process code is a type error. A pure annotation makes pure the effect of every parameter the body calls: `fn apply(f, x) -> Int = f(x)` has type `((a) -> Int, a) -> Int`.

A function has one clause. Patterns in parameters are irrefutable, §5.10: `fn seenCount(Snapshot(seen = entries) : Snapshot) -> Int = Map.size(entries)`.

`fn` may appear at top level and as a statement in a block; it sees its own name, and `fn` declarations in the same block or at top level may refer to each other. A type-member name, `fn T.f`, is a top-level form; in a block it is an error.

### 4.6 Bindings

In a block, `let p = e` binds the irrefutable pattern `p` to the value of `e`; `let p <- e` is described in §5.5. A binding is monomorphic and does not see its own name. A later binding of the same name shadows the earlier one from the next statement on; the right-hand side of the later binding sees the earlier one.

A block binding's type may hold unresolved type variables; `[]`, `None`, `Map.empty`, and a call that returns a polymorphic value introduce them. Such a variable is resolved in one of three ways: a later use of the binding in the block pins it, `let m = Map.empty; Map.put(m, "a", 1)` pins `m` at `Map(String, Int)`; it reaches the block's result and is generalized by the enclosing `fn` or top-level `let`, `fn namedEmpty() = { let xs = []; xs }` has type `() -> List(a)`; or an annotation on the binding fixes it. A variable resolved in none of these ways is a type error at the binding. A use pins a variable only where it fixes the variable's type: in `{ let xs = []; List.size(xs) }` the element type stays open, and the binding is a type error. A spawned function whose mailbox type nothing fixes is annotated: `let a = spawn(Local, fn() -> Unit with Never = ping(p, 3))`. `let _ = e` binds no variable, so no variable in the type of `e` needs resolving: `let _ = spawn(Local, fn() = worker())` is legal with the mailbox type unresolved. A type parameter of an enclosing scope counts as resolved.

At top level, `let` binds a `DeclName`: an `ident`, optionally prefixed with a type of the same module (§4.2). The binding generalizes its free type variables: `let Stack.empty : Stack(a) = Stack([])`. The left side is a name, not a pattern; `<-` is a block form only. The initializer is pure. Effectful setup belongs in `main`. The runtime evaluates top-level bindings in dependency order before `main` runs (§8.5).

### 4.7 Foreign declarations

`foreign type T` declares a type implemented outside the language. A parameter written with `=`, `k=` in `foreign type Table(k=, v)`, puts the equality constraint of §3.10 on its argument wherever the type is written.

`foreign fn f(params) -> T = "impl"` declares a function whose body is the implementation named by the string, in the runtime's language; parameters and the result are annotated. A foreign function with a mailbox type may do anything. One without a mailbox type promises purity: the same result for the same arguments, and no effect on anything. The implementation promises the declared types: a value of another shape, or an exception, is a fault, §7. Foreign code sees values in the runtime's representation, §8.4. Both declarations take `export` (§4.2).

### 4.8 Operators

The arithmetic operators `+`, `-`, `*`, `/`, `%` and `<>` resolve against the operand type. In `a + b`, `+` is `Int.+` when `a : Int` and `Distance.+` when `a : Distance`. A user type declares its operators in its own module: `export fn Distance.+(Distance(a), Distance(b)) -> Distance = Distance(a + b)`. The standard library module of a built-in type declares that type's operators the same way, with the type's name as the prefix: `fn Float.+` in `float.ern` declares `Float.+` (§9.6). In that module the prefix is allowed on an operator only; its other functions are declared unprefixed, `fn abs`. Both operands have one type, which either may determine, and there is no numeric type to generalize over: `fn f(a, b : Int) = a + b` uses `Int.+`. The operand type is determined when its type constructor is known: `xs <> []` is `List.<>`. An operator's result does not determine its operands. An operator is resolved once its definition is inferred, and before the definition is generalized. Its definition is the enclosing `fn` declaration, top-level or local, or the enclosing top-level `let`; a lambda belongs to the definition it stands in. An operand type still undetermined then is a type error. A field selection (§3.5) is resolved in the same way, against its operand's type. A member named by an operator has the type `(T, T) -> R` for its type `T`, `T.compare` the type `(T, T) -> Ordering`, and `T.negate` the type `(T) -> R`; each is pure. For a type with parameters, `T` is the type applied to any arguments, the same in each place: `(Vec(a), Vec(a)) -> Vec(a)`. A member of another shape is an error at its declaration.

`!` is negation on `Bool`, the prefix operator of `&&` and `||`, and `Bool.not` (E.7) is the same operation as a function, as `Int.negate` is of prefix `-`. `==`, `!=`, `<`, `<=`, `>`, `>=`, `&&`, and `||` cannot be defined per type: equality is structural and ordering goes through `compare` (§3.10); `&&` and `||` short-circuit on `Bool`. An operator is declared with `fn`; `let T.op` is an error. `::` is cons (§3.3); `|>` is a syntactic form (§5.7).

## 5. Expressions

```
Expr      = Lambda | IfExpr | BinExpr .
Lambda    = "fn" "(" [ Param { "," Param } ] ")" [ Return ] "=" Expr .
IfExpr    = "if" Expr "then" Expr "else" Expr .
MatchExpr = "match" Expr "{" Clause { "|" Clause } "}" .
Clause    = Pattern { "or" Pattern } [ "when" Expr ] "->" Expr .
ReceiveExpr  = "receive" "{" ( Clause { "|" Clause } [ "|" AfterClause ] | AfterClause ) "}" .
AfterClause  = "after" Expr "->" Expr .
BinExpr   = Unary { binop Unary } .
Unary     = [ "-" | "!" ] Primary { Call | Select } .
Call      = "(" [ Expr { "," Expr } ] ")" .
Select    = "." ident .
Primary   = literal | QName | Tuple | ListLit | BitExpr | Block | MatchExpr | ReceiveExpr
          | "(" Expr ")" .
QName     = { typename "." } ( ident | conname [ "(" ( Expr | Fields ) ")" ] )
          | typename "." { typename "." } userop .
Fields    = ".." Expr "," FieldSet { "," FieldSet } | FieldSet { "," FieldSet } .
FieldSet  = ident "=" Expr .
Tuple     = "#(" Expr { "," Expr } ")" .
ListLit   = "[" [ Expr { "," Expr } ] "]" .
BitExpr   = "<<" [ BitSegE { "," BitSegE } ] ">>" .
BitSegE   = Expr [ ":" BitSpec { "-" BitSpec } ] .
Block     = "{" Stmt { ";" Stmt } "}" .
Stmt      = FnDecl | Binding | Expr .
Pattern   = ConsPat [ "as" ident ] .
ConsPat   = AtomPat [ "::" ConsPat ] .
AtomPat   = "_" | ident | literal | "-" ( int | float )
          | { typename "." } conname [ "(" ( Pattern | FieldPats ) ")" ]
          | "#(" Pattern { "," Pattern } ")"
          | "[" [ Pattern { "," Pattern } ] "]"
          | BitPat .
BitPat    = "<<" [ BitSegP { "," BitSegP } ] ">>" .
BitSegP   = Pattern [ ":" BitSpec { "-" BitSpec } ] .
BitSpec   = "size" "(" Expr ")" | "unit" "(" int ")"
          | "bytes" | "int" | "float"
          | "utf8" | "utf16" | "utf32"
          | "big" | "little"
          | "signed" | "unsigned" .
FieldPats = [ ident "=" Pattern { "," ident "=" Pattern } ] .
```

`fn`, `if`, `match`, and `receive` are not operands: `1 + if c then a else b` is a syntax error; write `1 + (if c then a else b)`.

### 5.1 Evaluation

Strict, left to right, arguments before the call. A callee is evaluated before its arguments. In `x |> e`, `x` is evaluated before `e`: `x |> f(a)(b)` evaluates `x`, then `f(a)`, then `b`. A selection evaluates its operand, then reads the field. Nothing is delayed; `fn() = e` defers `e`. Prefix `-` is `negate` in the operand type's namespace: `Int.negate`, `Float.negate`, or `T.negate` for a user type `T`. A user type declares `T.negate` the way §4.8 declares `T.+`.

### 5.2 Calls

`f(x, y)` supplies all arguments. A call with the wrong number of arguments is a type error at the call; a call never yields a partially applied function. An expression whose value is a function can be called directly, `makeAdder(3)(4)`.

### 5.3 Lambda

`fn(x) = e` is an anonymous function. Its body is the longest `Expr` at the same nesting level, ending at the first delimiter of the enclosing form: `,`, `;`, `:`, `|`, `->`, `)`, `{`, `}`, `]`, `>>`, `then`, or `else`.

### 5.4 Blocks

`{ s1; s2; e }` is an expression whose value is its last statement, which is an expression. `;` separates statements and never appears last. A statement is a `fn` declaration, a `let` binding, or an expression evaluated for its effect. An expression that is not the last statement has type `Unit`; a value is discarded with `let _ = e` (§4.6).

A `fn` declared in a block is visible throughout it, so local functions may be recursive and mutually recursive. Two `fn` declarations of one name in one block are an error. A local `fn` may not take the name of a parameter or a variable in scope where it is declared, nor of a `let` of its block. The body of a local `fn` sees the bindings in force at its declaration. `let` bindings are sequential. A `fn` body that references a `let` declared later in the block is a compile-time error. A local `fn` may be used only after every `let` it references has been evaluated; a `let` referenced through another local function counts. A use is a call, or taking the function as a value, passing, storing, returning, or capturing it. An earlier use is a compile-time error.

### 5.5 Binding with `<-`

In a block, `let p <- e; rest` matches `e`: on `Right(v)`, `p` is bound to `v` and `rest` is evaluated; on `Left(err)`, the block's value is `Left(err)`. With `Optional`, `Some` and `None` apply the same way.

The sum type is decided after inference of the enclosing definition: from the type of `e`, or, if that is still open, from the block's type. Where both are open it is a type error, which asks for an annotation. `rest` has the block's type. All `<-` bindings in one block resolve to the same sum type.

### 5.6 Construction

`Some(e)`, `None`, `Snapshot(dir = d, seen = s)`. All fields are given. `Snapshot(..p, seen = s)` takes the unlisted fields from `p`; at least one field follows `..`. `..` is allowed only on a type with one constructor; on any other it is a type error. A constructor is qualified like a function, `Net.Http.Request(...)`.

A nullary constructor is a value. A single-positional constructor is a function value. A named constructor is neither; it appears only in construction syntax. A qualified operator is a function value, `Int.+`.

### 5.7 Pipe

`x |> e` applies `e`, a function value or a call, with `x` inserted as the first argument: `x |> f` is `f(x)`, `x |> f(a, b)` is `f(x, a, b)`.

```
let words = input |> String.trim |> String.toLower |> String.toList
```

`|>` is left-associative and binds loosest, below `||`: `a + b |> f` is `f(a + b)`, `a |> b |> c` is `c(b(a))`. The right-hand side is a name, a qualified name, a call whose first-argument slot the pipe fills, or a parenthesized expression, whose value is applied to `x`. A lambda must be parenthesized, `x |> (fn(y) = y + 1)`. In a chained call the pipe fills the outermost call: `x |> f(a)(b)` is `f(a)(x, b)`. A parenthesized call is a value: `x |> (f(a))` is `f(a)(x)`. The type of `x` is the target's first parameter type.

### 5.8 Conditional

`if c then a else b` with `c : Bool`; the branches have the same type.

### 5.9 `match`

A `match`, like a `receive` (§6.3) and a block, ends at its own `}`, so it may stand as an operand: `n > 0 && match x { ... }`. `if` and a lambda end in no delimiter of their own, and stand as an operand only in parentheses. The value is matched against the clauses' patterns in order; the first clause whose pattern matches and whose guard holds is evaluated. A clause may list several patterns separated by `or`, and matches when any of them does: `Player(alive = false) or Player(body = []) -> #(acc, apples)`. Every alternative binds the same variables at the same types; the guard and the body see them. Alternatives that bind different variables are a type error. The clauses together must cover the type, and a `match` that does not is a type error; guards do not count toward coverage. A clause, or an alternative of one, is *redundant* when it can match no value the clauses and alternatives before it leave unmatched, and a redundant clause is a type error: `n -> n | 0 -> 1`. A guarded clause leaves every value its pattern matches, since its guard may fail. For this, a bitstring pattern before the clause matches no value, and one in the clause matches any. A guard is a `Bool` expression with no mailbox effect that sees the pattern's variables and the enclosing scope. A guard that is `false` falls through to the next clause; a guard that faults faults the process. A `receive` guard falls through likewise, and is restricted further (§6.3).

### 5.10 Patterns

A pattern decomposes a value and binds its parts; the same patterns appear in `let`, in `match` and `receive` clauses, and in parameters.

`_` matches anything and binds nothing. An identifier binds the whole value at its position to a new variable, shadowing any outer one; it never refers to an existing variable. A literal matches itself, and a numeric literal may carry `-`: `match n { -1 -> "minus one" | _ -> "other" }`. A constructor pattern, `Some(p)` or `Snapshot(seen = s)`, matches that constructor and decomposes its fields; field patterns may omit fields. A tuple `#(p, q)`, a list `[p, q]`, and `p :: q` decompose a tuple, a list, and a cons. Patterns nest to any depth. `p as c` binds `c` to the whole value that `p` matches. `as` binds loosest: `x :: rest as all` names the whole list.

Each variable appears at most once in a pattern; equality is written in a guard. A pattern is *irrefutable* if it cannot fail: `_`, an identifier, a tuple of irrefutable patterns, a constructor pattern of a type with one constructor whose sub-patterns are irrefutable, or an irrefutable pattern with `as`. `let` and parameters require irrefutable patterns; `let Right(x) = e` is a type error.

### 5.11 Bitstrings

`<<...>>` constructs and matches a `Bytes` value at the bit level. It holds segments between `<<` and `>>`, separated by commas. A segment is a value, in construction, or a pattern, in a match, followed by an optional colon and a dash-separated list of specifiers.

| Specifier                   | Meaning                                                     |
|-----------------------------|-------------------------------------------------------------|
| `size(N)`                   | segment width, in units                                     |
| `unit(N)`                   | bits per size unit (default 1)                              |
| `bytes`                     | segment is a nested byte-aligned `Bytes` value; unit is 8 bits |
| `int`, `float`              | numeric segment (defaults: 8-bit, 64-bit)                   |
| `utf8`, `utf16`, `utf32`    | text encoding                                               |
| `big`, `little`             | endianness                                                  |
| `signed`, `unsigned`        | sign                                                        |

A segment without specifiers is `int` of size 8. A segment is `big` and `unsigned` unless it is marked otherwise. An `unsigned` segment of n bits holds 0 to 2^n − 1, and a `signed` one −2^(n−1) to 2^(n−1) − 1: `<<-1>>` faults, `<<-1:signed>>` is the byte 255, and the pattern `<<x>>` binds 255 from it. `signed` and `unsigned` apply to `int` segments, and `big` and `little` to `int`, `float`, `utf16`, and `utf32` segments; any other combination is a type error. `int` binds to `Int`, `float` to `Float`, the `utf` forms to `Char`, `bytes` to `Bytes`. `unit` is 1 to 256. A `float` segment is 16, 32, or 64 bits. A `utf` segment has no size. In a pattern, a `bytes` segment without a size takes the rest of the value and is the last segment. In a construction, a `bytes` segment without a size is its whole value, wherever it stands. The specifier names are specifiers only where a `BitSpec` stands, after a segment's `:` or `-`. Elsewhere, in a bitstring as outside one, they are ordinary identifiers: in `<<size:size(int)>>`, the first `size` and `int` are variables.

A bitstring's total bit count, in construction and in a pattern, is a multiple of 8. A `bytes` segment has a byte-multiple size, whatever its unit; a sub-octet field is `int`: `x:size(3)-bytes-unit(1)` is an error, a 3-bit field is `x:size(3)-int`. A violation of these rules the compiler can see is a compile-time error; one that depends on a dynamic size faults at construction (§7.4) or fails to match. A value that does not fit its width faults at construction, a literal included. A segment pattern is a variable, `_`, or a literal of the segment's type. `size(Expr)` in a pattern is a variable, an `Int` literal, or `+`, `-`, or `*` applied to these. The variable is bound by an earlier segment of the same bitstring, or is in scope where the pattern stands and is not bound at top level: a parameter, a block `let`, a pattern variable of an enclosing clause, or a lambda's capture. A variable bound elsewhere in the same pattern is not in scope in its sizes. Any other segment pattern or size expression is a type error. A negative or out-of-range size fails the match. Construction evaluates the segments left to right; a value that does not fit its width is a fault. A `bytes` value fits a sized segment only when it is exactly that long. A negative size fits no value. A `float` value is rounded to a 16- or 32-bit width to nearest, ties to even, and a value too small for the width becomes `0.0`; one whose magnitude exceeds the width's largest finite value does not fit. `<<>>` is the empty `Bytes`.

```
fn frame(len : Int, body : Bytes) -> Bytes =
    <<len:size(16)-big, body:bytes>>

fn parseFrame(bytes : Bytes) -> Optional(#(Int, Bytes, Bytes)) = match bytes {
    <<len:size(16)-big, body:size(len)-bytes, rest:bytes>> -> Some(#(len, body, rest))
  | _ -> None
}
```

`parseFrame` matches a 16-bit big-endian length, then `len` bytes of body, then the rest. For coverage (§5.9) a bitstring pattern, at any depth, counts as matching no value. A position that holds one is covered only by a `_` or a variable at that position in another clause: `Some(<<x>>) | Some(_) | None`. Bitstrings compile to the runtime's bit syntax, §10.

## 6. Processes

A process is an execution of a function with a mailbox type. It has a mailbox that receives values of that type, in arrival order per sender.

### 6.1 The mailbox type

`(A) -> B with M` is the type of a function that acts through the process it runs in, whose mailbox has type `M`: it uses that process's `send`, `receive`, or `self`, or calls a foreign function with a mailbox type. Every function runs in a process; that is not marked.

The effect is inferred. A function that calls a function with effect `M` has effect `M`. Two calls with different concrete effects in one body are a type error. Calls with variable effects unify. A pure call contributes nothing. A `receive`, with pattern clauses or only `after`, is process-only, as `self` is. A function that contains no `receive` and none of whose calls determines an effect is pure.

| Written | Meaning |
|---|---|
| `(A) -> B` | pure; callable from any process |
| `(A) -> B with M` | uses its process; callable only where the mailbox type is `M` |
| `(A) -> B with m`, `m` a variable | uses its process when `m` is a mailbox type; `m` takes the caller's mailbox type |

A pure function that calls a function argument runs it in the caller's process and is effect-polymorphic in it (§3.9): `List.map(xs, fn(x) = send(a, x))` has the callback's effect. Nothing else is written on a function type.

### 6.2 Built-in functions

```
self           : () -> Address(m) with m
send           : (Address(a), a) -> Unit with m
spawn          : (Where, () -> Unit with n) -> Address(n) with m
spawnMonitored : (Where, () -> Unit with n, (Down) -> m) -> Address(n) with m

type Where = Local | Peer(String)
```

`self()` is the process's own address. `send(a, v)` places `v` in the mailbox of `a` and returns at once; sending to a dead process has no effect.

`spawn(w, f)` starts a process that runs `f()` and returns its address. `self()` inside `f` is the new process's address; a parent that wants replies binds `let me = self();` before `spawn`. The effect `n` of `f` appears in `Address(n)` and so is a mailbox type (§3.9). A pure `f` fits, as a pure function fits wherever one with a mailbox type is expected, and `n` is then what the context makes it. A process that never receives is spawned with `fn() -> Unit with Never = ...`. A node is one running runtime; a peer is another node it knows by name, §8.3. `w` places the process: `Local` on the running node, `Peer(name)` on that peer. An unknown or unreachable peer is a fault. The captures of `f` are copied to the peer.

`spawnMonitored(w, f, wrap)` starts the process as `spawn(w, f)` does, and the caller monitors it from its start (§6.9): `wrap(d)` is placed in the caller's mailbox when it ends, with its reason, however soon that is.

### 6.3 `receive`

`receive { clauses }` matches the mailbox in arrival order. The first message that matches a clause's pattern and guard is removed and the clause is evaluated; the rest remain. If none matches, the process waits. Patterns are typed against the mailbox type. Coverage is not required: a message no clause matches stays in the mailbox. A redundant clause is a type error, as in a `match` (§5.9).

A guard selects a message without removing it, so a `receive` guard is a *guard expression*. Its operands are the pattern's variables, the enclosing function's variables that are not bound at top level, literals, negative numeric literals, and nullary constructors. A guard expression is `true`, `false`, an operand of type `Bool`, a comparison of two operands with `==`, `!=`, `<`, `<=`, `>`, or `>=`, `!` before a guard expression, or two guard expressions joined by `&&` or `||`. `<`, `<=`, `>`, and `>=` compare `Int`, `Float`, `String`, and `Char` only, in the order of their `compare` (§3.10). A guard expression calls nothing and cannot fault.

A final clause `after t -> e` gives a time limit of `t` milliseconds; `t` is evaluated on entry, and a time below 0 is 0. A time has no upper bound. When the limit passes without a matching message, `e` is evaluated. `after 0` does not wait for a message. Without `after` there is no limit.

### 6.4 Message ordering

Messages from one process to another are received in sending order. Between different senders there is no ordering.

### 6.5 Addresses

`Address(m)` identifies a process on a node and carries its protocol: `send(a, v)` is type-checked against `m` on any node. `via(f, addr)`, §9.5, is `addr` seen through `f : (a) -> b`: sending `v` to `via(f, addr)` sends `f(v)` to `addr`, `f` being applied by the `send`, in the sender. `via(Wrap, self())`, with `Wrap : (Int) -> Msg` and the mailbox type `Msg`, is an `Address(Int)`; a value sent to it arrives as `Wrap(v)`. A fault in `f` is the target's: the process `addr` names dies of it, and the sender goes on.

Addresses have no equality; identity is expressed in the protocol. There is no registry: a process reaches another only through an address it holds or received, and possession of the address is the permission to send.

### 6.6 Request-reply

A request carries a `Reply(a)`, a one-shot address for its answer.

```
Address.call        : (Address(m), (Reply(a)) -> m, Int) -> Optional(a) with n
Address.callForever : (Address(m), (Reply(a)) -> m) -> a with n
answer              : (Reply(a), a) -> Unit with m
```

`Address.call(addr, mk, ms)` allocates a fresh `r : Reply(a)`, sends `mk(r)` to `addr`, and returns `Some(v)` when the recipient answers or `None` after `ms` milliseconds, a time below 0 being 0. The clock starts at the call. A reply that arrives together with the timeout may be delivered or discarded. `Address.callForever(addr, mk)` waits without limit and returns `a`. `answer(r, v)` sends `v` to the caller. A reply travels by an identifier private to the call, never through the caller's mailbox. A late answer, after a timeout or the caller's death, is discarded silently, as is a second answer to a `Reply` already answered. The recipient cannot observe whether the caller still waits.

**The rule.** A `Reply` is answered exactly once, and so is every value that contains one: on every path from where it is bound, it is *consumed* exactly once. `answer(r, v)` consumes a `Reply` by answering it. Every other consumption hands the obligation on:

- Passing the value to a function whose parameter is reply-carrying at that instantiation hands it to the callee. A callee that duplicates or discards the parameter rejects the call (§3.9).
- `send` hands it to the `receive` clause that binds the value.
- Placing it in a constructor field or tuple component of reply-carrying type hands it to the built value.
- Returning it from a function whose result type is reply-carrying hands it to the caller.
- Capturing it in a lambda hands it to the lambda, which is then reply-carrying itself. The lambda is consumed exactly once, by a call or as the function argument of `spawn` or `spawnMonitored`, and may appear nowhere else. `let f = fn() = worker(r); spawn(Local, f)` is legal; with `f()` after the `spawn`, `f` is consumed twice. A local `fn` may not capture a reply-carrying value; such a capture is a type error.

A value is bound by a parameter, a `let`, a pattern variable, a `receive` variable, a lambda's capture, or the result of a call, and each binding is an *obligation*. The check is per function and crosses no call boundary. It is static: every path makes the consumption, and whether execution reaches it is not checked, since non-termination, a fault, or an indefinite wait may prevent it.

```
type Request = Get(reply : Reply(Int)) | Stop

fn serve(request : Request) -> Unit with m = match request {
    Get(reply = r) -> answer(r, 42)  // accepted: r is answered on its one path
  | Stop -> Unit                     // Stop carries no reply
}

fn twice(dst : Address(Request), request : Request) -> Unit with m = {
    send(dst, request);
    send(dst, request)               // rejected: request is consumed twice
}
```

**Which values contain a reply.** A type is *reply-carrying* if it is `Reply(a)` or has a constructor field or tuple component of a reply-carrying type. The property is transitive: `Request` above is reply-carrying, and so is `type Envelope = Env(msg : Request)`. It is by type, not by constructor: every value of `Request` is reply-carrying, `Stop` included. A declared type is reply-carrying at an instantiation whose fields, its arguments substituted, have a reply-carrying type: `Box(Reply(Int))` is, for `type Box(a) = Box(a)`, and `H(Request)` is not, for `type H(e) = H(f : (Int) -> Unit with e)`, since a function type is never reply-carrying. A built-in type is never reply-carrying through its arguments: `Address(Request)` is not. A function type is never reply-carrying. A lambda that captures a reply-carrying value carries the obligation by its capture, not by its type, and so does the name a `let` binds it to; that name is consumed as the lambda is, and `let h = g` is a type error.

**Where such a value may stand.** A reply-carrying value stands only as a constructor field, a tuple component, a function parameter, a variable bound by `let`, by a pattern, or in a `receive` clause, a capture of a lambda, or the result of a function whose result type, declared or inferred, is reply-carrying. Anywhere else it is a type error, in particular as an element of `List`, `Map`, `Set`, `Optional`, or `Either`, or as an operand of `==` or `!=`. A statement never drops one, since a statement has type `Unit` (§5.4): `Get(reply = r); Unit` is a type error.

**Patterns and branches.** A match consumes its scrutinee, and the obligation passes to the variables the pattern binds. A pattern on a reply-carrying value binds every reply-carrying field, so `_` or an omitted field there is a type error: `match request { Get() -> ... }` would drop a reply. `as` on a reply-carrying scrutinee is a type error. A constructor with no reply-carrying field, `Stop` above, discharges the obligation. An `if`, `match`, `receive`, or block whose value is reply-carrying consumes it or hands it on in every branch. The `mk` callback of `Address.call` is checked by the rule: `r` is consumed by placement in the message `mk` returns, and `Address.call` discharges the message.

### 6.7 Remote computation

```
remote : (() -> a) -> Either(RemoteError, a) with m
type RemoteError = NoRemotePeer | PeerLost
```

`remote(f)` evaluates the pure function `f` on a peer the runtime chooses among those configured for remote computation and returns `Right(v)`. It returns `Left(NoRemotePeer)` when no such peer is configured, and `Left(PeerLost)` when the peer is lost before the value returns. A fault in `f` faults the caller with the same cause, as `f()` would. A resolution failure on the peer faults the caller with `Fault("peer resolution failed: ...")` (§8.7). Effectful work on a peer goes through `spawn(Peer(...), ...)`. `remote` carries a mailbox effect and is called from process code only.

### 6.8 `Never`

A function with mailbox type `Never` can send but never receive: a `receive` with a pattern clause is a type error, and a `receive` with only an `after` clause is how a `Never` process waits.

`with Never` annotates a process root that never receives: `main`, or the function a spawn lambda calls. A function so annotated can only be called where the mailbox is `Never`; a send-only helper called from process code is polymorphic instead, `with m`, as `Io.println` in Appendix E.

### 6.9 Death

A process dies when its function returns, when `kill` is called on it, on a fault (§7.3), or when the program ends (§8.6). Its `Reason` (§9.3) says which: `Returned`, `Killed`, `Fault(cause)`, or `ProgramEnd`; `Unknown` is what a `monitor` made after the end says. `kill` is asynchronous: the target may run until the runtime interrupts it. `kill` on a process that is dead has no effect. `kill` on a system process (§8.2) faults the caller with `Fault("a system process is the runtime's")`. `monitor(a, wrap)`, §9.5, places `wrap(d)` in the caller's mailbox when `a` dies; `d : Down` gives the cause. If `a` is already dead, the message is placed at once, with the reason `Unknown`: the runtime keeps nothing of a process that has ended, so a `monitor` made after the end cannot say how. A `monitor` made while the process runs gets its reason, and a process started with `spawnMonitored` (§6.2) is monitored from its start. Each `monitor` call produces one message. A `wrap` is applied as `via`'s function is (§6.5), by the delivery: a fault in it is the fault of the process it delivers to, and a `wrap` that does not finish holds up no other delivery. `function` in `Down` is the qualified name of the top-level declaration in which the `spawn` that started the dead process is written, with the line where it is written: `Counter.main:19`. A `spawn` in a lambda or a local `fn` counts as written in the top-level declaration that contains it. Where `spawn` is passed as a value, it counts as written where its name is. For the entry process it is the entry point's name. With the reason `Unknown` it is the empty string. There are no other links.

### 6.10 Code replacement

A process replaces its code by a message in its own type that carries the new loop, and switches with a tail call:

```
type CounterMsg =
    Inc(Int)
  | Get(reply : Reply(Int))
  | Upgrade(migrate : (Int) -> Int, next : (Int) -> Unit with CounterMsg)

fn counter(n : Int) -> Unit with CounterMsg = receive {
    Inc(k) -> counter(n + k)
  | Get(reply = r) -> { answer(r, n); counter(n) }
  | Upgrade(migrate = m, next = k) -> k(m(n))
}
```

The language has no other mechanism for code replacement. The shell's reload (§11.2) runs new calls on the new code and never changes the code a running process runs; a process whose code the shell can no longer keep faults with `Fault("its code was unloaded")` (§7.4).

## 7. Errors

There are no exceptions. An error is a value, a message, or a fault.

### 7.1 Value errors

The error is part of the function's meaning and is in its result type, `Either(e, a)` or `Optional(a)`. The caller matches on the result or chains with `let p <- e` (§5.5).

### 7.2 Message errors

The error crosses a process boundary and is in the message: `Either`, or a constructor of the reply type. A missing reply is `None` from `Address.call` (§6.6).

### 7.3 Faults

A fault ends the process that meets it, with the reason `Fault(cause)` that `Down` carries (§6.9). The code cannot see it, and nothing catches it. Its causes are those §7.4 lists, each with its text, and a failure in the runtime, out of memory among them, whose text is the host's class and reason: `Fault("error:badarg")`. A process that is killed, or that ends with the program, has not faulted.

### 7.4 Causes of faults

Partial operations in the prelude return `Optional` or `Either`, except the following, which fault with the cause given. A pure function can fault.

- `/` and `%` on `Int` with a zero divisor: `Fault("division by zero")`. `Int.div` and `Int.mod`, §9.6, return `Optional` instead.
- `Float` arithmetic whose result the finite range cannot hold (§3.1): `Fault("float arithmetic error")`. `Int.toFloat` of an integer that rounds beyond the largest finite `Float`: `Fault("Int out of Float range")`.
- Bitstring construction (§5.11). A value that does not fit its width: `Fault("segment overflow")`. A dynamic total bit count, or a dynamic size of a segment bound to `Bytes`, that is not a multiple of 8: `Fault("bitstring not byte-aligned")`.
- `todo("...")`, which compiles at any type: `Fault("todo: ...")`.
- Cross-node transport of a foreign value (§3.8): `Fault("foreign value cannot cross nodes")`.
- `spawn(Peer(...), ...)` or `spawnMonitored(Peer(...), ...)` with an unknown or unreachable peer: `Fault("peer unreachable")`. `spawn(Peer(...), ...)` or `remote(f)` with a resolution failure on the peer (§8.7): `Fault("peer resolution failed: ...")`. A fault in `remote`'s callback faults the caller with the callback's own cause. `send` to a remote address whose resolution fails faults the sender with the same cause, asynchronously, after `send` returns.
- `kill` on a system process: `Fault("a system process is the runtime's")`, in the caller (§6.9).
- A foreign function that raises: `Fault("foreign function m:f/n raised ...")`. A foreign function's return is checked against its declared type when the function returns, and a reply when `Address.call` or `Address.callForever` returns it, each in the calling process and to the value's whole depth; a function value in it is checked when it is called, its result against its declared result type. A mismatch faults the calling process: `Fault("foreign return does not match T")`, `Fault("reply does not match T")`. A message from a foreign process that does not match the mailbox type faults the receiver on delivery (§8.4): `Fault("message does not match M")`. Each names the declared type.

These faults come from no prelude operation. A fault in a function adapting an address faults the target with its own cause (§6.5). The loss of a peer faults every process on it with `Fault("peer lost")` (§10). A deadlock faults the entry process with `Fault("deadlock")` (§8.6). The unloading of the code a process runs faults the process with `Fault("its code was unloaded")` (§11.2). Reading the terminal both as lines and as keys faults the entry process with `Fault("the terminal is already read as lines")`, or `as keys` (§8.2). While a shell holds the terminal, subscribing to it or reading a line from any other process faults that process with `Fault("the shell holds the terminal; run the program with ern to give it the keyboard")` (§11.2). A standard input that cannot be read faults the entry process with `Fault("the standard input could not be read: ...")`, the host's reason after the colon.

## 8. Programs

### 8.1 `main`

The entry point is a `fn () -> Unit with m`. The process that runs it is the *entry process*. `m` is the message type when the entry receives. It is `Never` when the annotation says so. Otherwise it is polymorphic, and the runtime instantiates it to `Never`. A pure `fn () -> Unit` is an entry point too, and its process's mailbox type is `Never`. A result type that is a type variable, as a function that never returns has, is taken as `Unit`, as a mailbox type that is a variable is taken as `Never`. A top-level `let`, and a function of another shape, is not an entry point, and `ern` refuses it. `ern module.erc` runs the `export fn main` of that module; `ern --main Qualified.name module.erc` runs another exported function of that shape. `main` is a convention, not a reserved name.

### 8.2 System references

The runtime starts its system processes and binds their addresses to top-level values in the `Sys` namespace, §9.7. A program uses each through the standard library, Appendix E: `Sys.stdout`, `Sys.stderr`, and `Sys.stdin` through `Io`, the rest through the module of the same name, its *system module*. The address and its message type are declared in Ernest, for the module and for the foreign process behind it (§8.4). A runtime may provide more. The values are in scope everywhere; pure code can name an address but not send to it (§6.1). A `Sys.*` name the runtime does not provide is a compile-time error. In code shipped to a peer, one the peer's runtime does not provide is a resolution failure (§8.7).

**`stdout` and `stderr`.** `stdout` writes each received `String` to standard output as bytes, and adds no newline. `stderr` does the same to standard error. It is a second sink, for a program whose output is read by something else, and not a level of severity.

**`stdin`.** `stdin` answers each `ReadLine` with the next line without its line feed, and `None` at end of input.

**The terminal.** `terminal` sends each subscriber an `Event` for every key pressed and for every change of the terminal's size. A process holds one subscription: a second `Terminal.subscribe` replaces the first, its wrap from then on, and a subscription ends when its process dies. It answers `Measure` with the size now, and with `None` where there is no terminal or its size is unknown. `terminal` and `stdin` are the same terminal, and a program subscribes to the terminal or reads lines, not both. A program that does both faults its entry process with `Fault("the terminal is already read as lines")`, or `as keys` (§7.4).

**Keys.** A subscription is answered once the terminal is in the mode the keys need: nothing typed after `subscribe` returns is echoed. While a program is subscribed, the terminal delivers each key as it is pressed and does not echo it, and the runtime restores line mode with echo when the program ends. A sequence the runtime does not name arrives as `Escape` and the characters after it. `Escape` is delivered once no escape sequence can still follow it.

**Paste.** While a program is subscribed, the runtime asks the terminal to bracket a paste. Pasted text then arrives as one `Pasted`, not as the keys of its characters, and its line endings are line feeds. A terminal that does not bracket a paste sends the characters, which no program can tell from typing.

**Interrupt.** `Interrupt` is the terminal's interrupt, delivered to the holder of the terminal in place of the signal that would end the program (§8.6). A program that is not the holder is ended by that signal.

**`clock`, `fs`, and `tcp`** answer as their message types say (§9.3).

### 8.3 Peers

Peers are configured outside the language, §11.3; `Peer(name)` refers to them by the configured name, and nodes authenticate each other.

### 8.4 Foreign code

The system processes are foreign processes: their message types are declared in Ernest, their implementations live outside the language, and the runtime starts them and binds their addresses. Other foreign code enters through `foreign fn` and `foreign type`, §4.7. Both boundaries carry the same promise: the foreign side delivers the declared types, and a breach faults the receiving Ernest process: a bad return value or reply when the call returns, a bad message on delivery. Messages from the system processes are not checked.

**ABI.** The runtime maps Ernest values to host terms; for the BEAM runtime:

- `Int` → arbitrary-precision integer.
- `Float` → IEEE double, finite (§3.1).
- `Bool` → atom `true` or `false`.
- `Char` → integer, the code point.
- `String` → binary, UTF-8.
- `Bytes` → binary.
- Nullary constructor `C` → the quoted atom of its source spelling, `'Ready'`, `'None'`.
- Positional constructor `C(v)` → `{'C', v}`.
- Named constructor `C(f1 = v1, ..., fn = vn)` → `{'C', v1, ..., vn}` with the fields in canonical order (§3.5).
- Tuple `#(v1, ..., vn)` → `{v1, ..., vn}`.
- `List(a)` → list.
- `Map(k, v)`, `Set(a)` → opaque handles over BEAM maps.
- `Address(m)`, `Reply(a)`, function values → opaque handles foreign code may pass back but not inspect.
- Foreign values → as foreign code made them; Ernest does not inspect them.

A process's end is a host term too: a process that returned exits `normal`, one that faulted `{ern, fault, Text}`, one killed by `kill` `{ern, killed}`, and one ended with the program `{ern, program_end}`. These are the `Reason` values of §9.3 as the host sees them.

Same-named constructors of different types share an atom; the receiver's declared type disambiguates. Cross-node transport uses the runtime's external term format for these representations. A `foreign fn` implementation is named `module:function/arity`, the arity its parameter count. A name not of that form, or whose arity is not the parameter count, is a compile-time error. A module or function the host lacks when the call is made raises, and the call faults as §7.4 says: `Fault("foreign function m:f/n raised error:undef")`.

### 8.5 Initialization

Before `main` runs, the runtime evaluates in dependency order every top-level `let` of the entry point's module and of every module it depends on, directly or through others. A module the program does not depend on is not initialized. A binding depends on every top-level `let` its initializer names, and on what every function it names depends on, called or not; a lambda's body is part of its initializer. A binding is evaluated after those it depends on. `let handlers = [f]` is a cycle when `f` names `handlers`, and so is `let a = fn() = a()`. The order within an independent set is unspecified. A cycle is a compile-time error. Only `let` requires evaluation, and the `Sys.*` references are bound first. An initializer that faults (§7.4) ends the program with that fault before `main` runs. Which of two independent faulting initializers is reported is unspecified. An initializer that does not terminate prevents the remaining initializers and `main` from running.

### 8.6 Program termination

The program ends when `main` returns or faults, a fault being reported on the runtime's exit indicator. Live local processes then die with the reason `ProgramEnd`, and the runtime flushes the system processes' pending output before it stops. A signal from outside that ends the program, the host's termination or interrupt, ends it the same way, and the runtime prints nothing of its own about the signal. Workers spawned on peers are unaffected and follow their own return, `kill`, or peer loss (§10); peers observe the ending node as lost. A program that is to keep running waits in `main`.

When no forward progress is possible, the entry process faults with `Fault("deadlock")` (§7.4) and the program ends as above. No progress is possible when every live process waits in `receive` without `after` or in `Address.callForever`, no message is in flight, no monitor waits on a process the runtime did not start, and no system process or connected peer holds a timer, a subscription, a pending I/O, or a computation whose completion would deliver a message. A process spawned on a peer by this node counts as such a computation while it runs. Detection is per node. Whether a user-provided foreign process counts like a system process here is the runtime's choice.

### 8.7 Code shipping

Four operations ship a closure or payload, and the code it depends on, to a peer: `spawn(Peer(name), f)` and `spawnMonitored(Peer(name), f, wrap)`, `remote(f)` and the return of its result, `send` to a remote address, and `answer(r, v)` to a caller on another node. Within a node nothing is shipped.

**Content addressing.** Every function, constructor, and type is identified across nodes by a hash of its normalized definition together with the hashes of what it references. Identical definitions have the same hash on every node. A type's hash includes its qualified name, so two types with the same constructors under different names are different types, as they are to the checker. Any change to a definition changes its hash, and transitively the hashes of everything that depends on it. A set of mutually recursive definitions is hashed as a group, internal references by position, and each member's identity derives from the group's hash. Normalization renames local variables, orders named fields canonically (§3.5), preserves the source evaluation order of construction expressions, and preserves the qualified names of external references.

**Resolution.** Before a shipped closure runs, the peer resolves every hash it carries, transitively, from its own store or by fetching from the sender, and caches what it fetched. A resolution failure is a missing dependency, a missing `Sys.x`, or an incompatible foreign definition. For `remote` and `spawn(Peer, ...)` it is a fault of the caller. For `send` it is an asynchronous fault of the sender. A resolution failure does not invalidate other addresses on that peer; only the loss of the peer does (§10).

**Identity.** Types are identified by hash. Two nodes with identical declarations under the same qualified name interoperate. Two nodes with different declarations under one name hold distinct types. A shipped closure that mentions the sender's `FooMsg` uses the sender's `FooMsg` on the peer; the peer's own `FooMsg` is unrelated to it. An abstract type's hash also includes the types of its module's exported declarations: two `Stack(a)` declarations with the same name and representation are one type only if their modules export the same declarations with the same types.

**Bindings.** A `Sys.*` name in shipped code resolves on the peer that runs it: a shipped `Io.println` writes on the peer. An address captured by the closure is shipped as a value and still names the process it named on the sender: an `Address` captured from the sender's `Sys.stdout` still names the sender's stdout. A top-level binding referenced by shipped code is evaluated on the peer on first use, in the peer's environment, at most once per node for each hash of its definition: `let output = Sys.stdout` is the peer's stdout when evaluated on the peer. An initializer that faults there faults the process that first uses it. Foreign declarations are not shipped: a shipped closure that references one requires a compatible definition under the same qualified name on the peer, and a missing or incompatible one is a fault at resolution.

## 9. Prelude

The prelude is what §9 names. Everything else is the standard library, Appendix E: the container, string, and numeric operations and the output helpers. An operation of §9.6 in a type's namespace, `Int.compare`, is provided by that type's standard library module. `Address.call` and `Address.callForever` are the runtime's, as the rest of §9.4 and §9.5 are.

The prelude's names are documented as a standard library module's declarations are (E.0 rule 6), on a page of their own, and an operation a type's module provides is documented there. A type that is the prelude's because a system reference speaks it has no example, since a program does not send to a system reference (E.0 rule 8).

A type is the prelude's when the language's rules name it, as `Optional` for `<-` and `Down` for `monitor`; when the module of its operations is named after it, as `Map` and `Int`; or when a system reference speaks it (§9.7), as `FsMsg` and `IoError`. `Test` and `TestResult` are the prelude's for `ern --test` (§11.2). Any other type a module provides is the module's, as `Random.Seed`.

### 9.1 Built-in types (§3)

```
Address(m) // an address of a process that receives m
Reply(a) // a one-shot address, §6.6
Never // the type with no values
Foreign // a value the language does not inspect, §3.7
```

### 9.2 Built-in parameterized types

Provided by the runtime:

```
List(a) // an immutable linked list of elements of type a
Map(k=, v) // an immutable dictionary from k to v
Set(a=) // an immutable set of a
```

A parameter written with `=` requires equality of its argument, as a foreign type's does (§4.7).

### 9.3 Declared types

```
type Unit = Unit // the one-value type; carries no information
type Optional(a) = None | Some(a)
type Either(e, a) = Left(e) | Right(a)
type Ordering = Less | Equal | Greater
type Down = Down(reason : Reason, function : String)
type Reason = Returned | Killed | ProgramEnd | Fault(String) | Unknown
type ClockMsg = // times in milliseconds
    After(ms : Int, to : Address(Int)) // the time it fires is sent to `to`
  | At(at : Int, to : Address(Int))
  | Now(reply : Reply(Int))
type RemoteError = NoRemotePeer | PeerLost
type Where = Local | Peer(String) // spawn placement, §6.2
type Size = Size(rows : Int, columns : Int)
type Event =
    Key(Char) | ArrowUp | ArrowDown | ArrowLeft | ArrowRight | Enter | Escape
  | Interrupt | Pasted(String) | Resized(Size)
type TerminalMsg =
    Subscribe(to : Address(Event), reply : Reply(Unit))
  | Measure(reply : Reply(Optional(Size)))
type StdinMsg = ReadLine(reply : Reply(Optional(String)))
type Path = Path(String) // in the runtime's syntax
type Entry = Entry(path : Path, mtime : Int, size : Int, isDir : Bool) // mtime in milliseconds since the epoch, as Clock.now; size in bytes
type IoError = NotFound | Denied | Refused | Closed | Timeout | Other(String)
type FsMsg =
    ReadFile(path : Path, reply : Reply(Either(IoError, Bytes)))
  | WriteFile(path : Path, bytes : Bytes, reply : Reply(Either(IoError, Unit)))
  | AppendFile(path : Path, bytes : Bytes, reply : Reply(Either(IoError, Unit)))
  | ListDir(path : Path, reply : Reply(Either(IoError, List(Entry))))
  | Stat(path : Path, reply : Reply(Either(IoError, Entry)))
  | MakeDir(path : Path, reply : Reply(Either(IoError, Unit)))
  | Remove(path : Path, reply : Reply(Either(IoError, Unit)))
  | Rename(from : Path, to : Path, reply : Reply(Either(IoError, Unit)))
  | Copy(from : Path, to : Path, reply : Reply(Either(IoError, Unit)))
type TcpMsg =
    Listen(port : Int, reply : Reply(Either(IoError, Address(ListenerMsg))))
  | Connect(host : String, port : Int, reply : Reply(Either(IoError, Address(SockMsg))))
type ListenerMsg = Accept(reply : Reply(Either(IoError, Address(SockMsg))))
type SockMsg = Recv(reply : Reply(Either(IoError, Bytes))) | Send(Bytes) | Close
type Test = Test(name : String, run : () -> TestResult with Never)
type TestResult = Passed | Failed(String)
```

A top-level `let` of type `Test` is a test; `ern --test` runs it (§11.2).

### 9.4 Built-in functions (§6)

```
self           : () -> Address(m) with m
send           : (Address(a), a) -> Unit with m
spawn          : (Where, () -> Unit with n) -> Address(n) with m
spawnMonitored : (Where, () -> Unit with n, (Down) -> m) -> Address(n) with m
```

### 9.5 Process functions

```
via                 : ((a) -> b, Address(b)) -> Address(a)
Address.call        : (Address(m), (Reply(a)) -> m, Int) -> Optional(a) with n
Address.callForever : (Address(m), (Reply(a)) -> m) -> a with n
answer              : (Reply(a), a) -> Unit with m
remote              : (() -> a) -> Either(RemoteError, a) with m
monitor             : (Address(a), (Down) -> m) -> Unit with m
kill                : (Address(a)) -> Unit with m
```

### 9.6 Operations required by the language

```
Int.+, Int.-, Int.*, Int./, Int.% : (Int, Int) -> Int // §4.8
Int.negate : (Int) -> Int // §5.1: prefix -
Float.+, Float.-, Float.*, Float./ : (Float, Float) -> Float
Float.negate : (Float) -> Float
String.<> : (String, String) -> String // §4.8: <> resolves per type
List.<> : (List(a), List(a)) -> List(a)
Bytes.<> : (Bytes, Bytes) -> Bytes
Int.div, Int.mod : (Int, Int) -> Optional(Int) // §7.4: / and % fault on zero; these do not
Int.compare : (Int, Int) -> Ordering // §3.10: ordering is per type
Float.compare : (Float, Float) -> Ordering
String.compare : (String, String) -> Ordering
Char.compare : (Char, Char) -> Ordering
todo : (String) -> a // §7.4: faults if reached
```

On `Int`, `Float`, `String`, `List`, and `Bytes` an operator is the runtime's own operation. The declaration of one in the type's module, `fn Int.+(a, b) = a + b`, names that operation and is not a recursive call.

### 9.7 System references

Runtime-provided, §8.2:

```
Sys.stdout : Address(String)
Sys.stderr : Address(String)
Sys.stdin : Address(StdinMsg)
Sys.terminal : Address(TerminalMsg)
Sys.clock : Address(ClockMsg)
Sys.fs : Address(FsMsg)
Sys.tcp : Address(TcpMsg)
```

Each is used through the standard library, §8.2.

## 10. Runtime Requirements

- Tail calls take constant stack space. A function's body is in tail position. Where an expression is in tail position, so are both branches of an `if`, the body of each `match`, `receive`, and `after` clause, and the last expression of a block.
- Processes are scheduled preemptively; a process cannot prevent others from running.
- Processes share no memory, except what foreign functions share (§4.7); a message is a copy or immutable.
- Mailboxes are unbounded; a program is responsible for its own backpressure.
- `Int` has arbitrary precision.
- Bitstrings are constructed and matched by the runtime's bit syntax (§5.11).
- The representation of values is fixed and documented.
- The hash and the normal form of §8.7, how nodes authenticate each other (§8.3), and the wire format are the runtime's, fixed and documented with it.
- `Down` carries a reason distinguishable from every other.
- The runtime detects a deadlock (§8.6).
- A node ships code to a peer that lacks it, identified by content; dependencies resolve by hash before a shipped closure runs, types are content-addressed, `Sys.*` re-binds to the peer, and foreign code is per node, §8.7.
- The runtime detects the loss of a peer: every process on it is treated as dead with the reason `Fault("peer lost")`, monitors deliver `Down` (§6.9), and pending `remote` calls return `Left(PeerLost)`. Loss is terminal: a peer that reappears under the same name is a new instance, and addresses held before the loss are unrelated to it. `send` to a peer is best-effort; messages in flight at the loss are dropped without notice.

## 11. Toolchain

Options are long: `--name`, or `--name value` for one that takes a value.

### 11.1 `ernc` (compiler)

`ernc [--source-root src-root] [--out-dir build-dir] [--load-path dir ...] file.ern` compiles a module to `file.erc`. That file carries the inferred types of the module's exported declarations and which of them are values rather than functions (§4.6); dependent modules are checked against them. It carries the module's documentation too: every doc block of §2.2, each declaration's signature, and each function's parameter list as the module writes it. On the BEAM that is the EEP 48 `Docs` chunk, which the host's own documentation tools read. `ernc [--source-root src-root] [--out-dir build-dir] [--load-path dir ...] src-dir` compiles every `.ern` under `src-dir` in dependency order, mirroring the source tree into `build-dir` and creating directories as needed. A cycle among the modules (§4.1) is reported with the modules in it. A module is recompiled when its source has changed, when the interface of a module it depends on has changed, when any interface of the standard library has changed, or when it was compiled by another build of `ernc`, another version or the same version's code changed; a change confined to a dependency's bodies does not recompile its dependents. A module outside the source root is read from its `.erc` under `build-dir`, then under each `--load-path` root, found by namespace as §11.2 finds it. Cross-module references link at load, against `.erc` files under `build-dir` and the `--load-path` roots. `--emit erl` writes the module's Erlang source as `.erl` instead, for reading; it carries no interface.

**Source root.** Each file's namespace comes from its path under the source root (§4.2). `--source-root` names it. Without it, a path under the standard library's source root (§4.2) uses that root. Otherwise single-file mode uses the current directory, and directory mode uses the directory passed to `ernc`. Output mirrors the source root, not the directory argument: `ernc --source-root src --out-dir build src/net` writes `src/net/http.ern` to `build/net/http.erc`, not `build/http.erc`. `build-dir` defaults to the source root, and to `build/stdlib` beside the toolchain for the standard library's own source root (§4.2), where its modules are built.

**Path shape.** The name of each `.ern` file compiled, and of each directory between it and the source root, is one word: a lowercase letter followed by lowercase letters and digits. A multi-word module is a nested directory, `http/parser.ern` for `Http.Parser`. Extensions are `.ern` and `.erc`. A path that breaks the rule is an error, `path component Net must be lowercase`; the root itself and files that are not modules are not checked.

**Cleanup.** After a successful directory-mode compilation to `.erc`, `ernc` removes from the mirrored build subtree every `.erc` whose `.ern` no longer exists under the source root, and every directory left empty; nothing else is removed: `ernc --source-root src --out-dir build src/net` sweeps `build/net/` and leaves `build/main.erc`. `--no-clean` disables it. Single-file mode does not sweep.

### 11.2 `ern` (runner)

`ern [--config-dir dir] [--load-path dir ...] [--main Qualified.name] file.erc` loads the module and, on demand, the modules on the load path. They are found by namespace: `A.B.C` is `a/b/c.erc`, each segment lowercased. A type-member reference `A.B.C.T.member` is found through the interface of `a/b/c.erc`, the module that owns `T`. The runner starts the system processes, binds their addresses to the `Sys.*` references, and calls the entry point (§8.1): the `export fn main` of the loaded module, or the function `--main` names, anywhere on the load path. The load path holds the standard library and the root of the loaded module: the directory reached from the module's file by going up one directory per segment of its namespace. `--load-path` adds directories. An Erlang module that a `foreign fn` names (§8.4) is the host's own or a `.beam` file of that name in a directory of the load path; the host's own is found first. The path-shape rule of §11.1 applies to every `.erc` opened as a module and to each directory between its load-path root and it. Other files are not checked: `.ernest/` under a load-path root is not a module.

`ern --test file.erc` runs every top-level `let` of type `Test` in the module (§9.3), exported or not, each in a process of its own after the module's initializers (§8.5). It prints each test's name with `passed`, `failed` and the text of `Failed`, or `faulted` and the cause, and exits with status 1 unless every test passed.

`ern` running a program exits with status 0 when the entry point returns. A fault of the entry process, a deadlock among them (§8.6), is printed to standard error as `fault: ` and its cause, and `ern` exits with status 1. Beneath a failure in the runtime (§7.3) or a foreign function's raise (§7.4) it prints the host's stack, a function to a line; the cause a program sees in `Down` (§6.9) is the text alone.

`ern [--shell] [--source-root dir] [file.erc]` adds an interactive shell with every loaded module in scope; `--shell` takes no argument and makes the file optional, and `--source-root` names where the shell finds a module's source, the working directory by default.

**The shell.** It is the entry point (§8.1). A file's entry point is spawned beside it, so §8.6 ends the program when the shell ends, not when that entry point returns; `--main` then names the function to spawn. A file without an entry point, and without `--main`, is loaded and nothing is spawned, so a library module is put in scope to be tried. The terminal is the shell's, at a terminal and in line mode alike: `Terminal.subscribe` and `Io.readLine` from any other process fault (§7.4), and the terminal's interrupt reaches the shell as a key rather than ending the program (§8.6). A deadlock is not detected while a shell holds the terminal.

**Inputs.** Each input is checked, compiled as a module of its own, and run in a process of its own. An input may declare what a module may, and every declaration it makes is the session's, so `export` at the prompt adds nothing. A `let` at the prompt binds as a `let` in a block does (§4.6), not as a top-level `let`, and stands alone in its input; `let T.name` declares a member and is a declaration like any other. Its pattern binds each name it contains, as in a block, and `let _ = e` runs `e` and binds nothing. A `let` with `<-` is refused, since no block follows it for the `<-` to end. An input that binds a name whose type the input itself does not settle is refused, with the annotation that would settle it. An input whose value, or whose `let`, is reply-carrying is refused (§6.6). An expression's value is bound to `it`, except where the input does not settle its type, which leaves `it` as it was. A diagnostic names the input as the file `input`. Bindings survive a fault or an interruption in an input. An input entered while another runs waits, and runs after it, in the order entered; the interrupt ends the running input alone. A command begins with `:` and is not an Ernest function. The shell's help lists the commands in alphabetical order. A command that takes nothing refuses an argument. A command is selected by its name or by a prefix of its name that begins no other command's name; a prefix that begins more than one is refused with the names it begins.

**Printing.** An expression's value is printed with its type (§11.5), except a value of type `Unit`, which prints nothing. An input that is one name, `Io.readLine`, has its type printed as the name's declaration writes it, under the declaration's own variable names. A declaration is printed with its name and type, and a type declaration with its keyword and its name. A value is printed to a depth and a length, and what they leave out prints as `...`; `:set depth n` and `:set length n` change them, and 0 sets no limit. `Io.debug` prints a value whole (E.1). With timing on, a result is followed by the time its run took. What a program writes through `Sys.stdout` and `Sys.stderr` is shown in a live region at the foot of the screen, above the input, in as many rows as `:set output` gives it, none at 0; what the shell itself says is written above the region and scrolls with the terminal, except what `Tab` and `Shift-Tab` show.

**Colour.** At a terminal, and where the environment does not set `NO_COLOR`, the shell colours what it says: a fault report, a diagnostic's first line, and every refusal of a command in red, what the shell answers being plain, the type after a printed value dimmed, a name bold in a completion listing and a `Shift-Tab` brief, the parameter a signature marks in cyan, and in documentation a heading and strong emphasis bold, emphasis in italics, and a code span in cyan. A colour takes no column. Elsewhere, and in `ernc`'s diagnostics, nothing is coloured.

**Scope.** The session's declarations are a scope. An unqualified name is looked up first among the names bound around it, then in the input's own declarations, then in the type-member namespace of the enclosing declaration, then in the session's, then in the prelude (§4.2). A type the session declares prints unqualified, except one a later declaration of its name has shadowed, which prints under the input that declared it: `$Input2.T` for the second input's `T`. No program can name an input, since `$` is in no identifier. A later input may declare a member of a type the session declares, `fn Coin.+` after `type Coin`, and the member is the session's; it belongs to the latest declaration of the type's name, and a type declared again starts with no members.

**Faults.** The shell prints a line for each process that faults while the session runs, with the spawn site and the cause of §6.9: `Counter.worker:23 faulted: division by zero`. A process that returns, that is killed, or that ends with the program is not reported, nor is one of the shell's own, nor an input's own process, whose fault is already its answer. This is the runtime's record of how every process it started ended (§6.9), read by the shell and not by a program, which learns of a death through `monitor` alone. A spawn site in the session is written as the session writes names: in a function an input declares, by that function's name, `start:2`, and in an input's own expression as the file its diagnostics name, `input:1`, the line counted within the input.

**Loading and reloading.** `:load` takes a module by its namespace. It compiles the module's source under the source root, or, where there is none, loads its compiled form from the load path or the source root; the modules it uses are loaded as `ern` loads them. The module is then in scope by its qualified name. A module the session has loaded already is refused by `:load`, since `:reload` is how it changes. `:reload` compiles again every loaded module whose source has changed, all of them before it loads any; where one fails, none is loaded and the session is as it was. A module reloaded has two versions in the session: a process still running the previous one keeps it, as §6.10 requires, and so does a binding that holds a function of it. A further reload of that module ends those processes with `Fault("its code was unloaded")` (§7.4) and forgets those bindings; the reload before it names them and ends nothing.

**Editing.** At a terminal an input may span lines, and a line wider than the screen wraps onto the rows below it as it is typed. `Enter` runs the input where the parser can finish it, and takes another line where it cannot, under the prompt `... `. An input the parser cannot finish is one that ends where the grammar expects more, an unfinished raw string or block comment among them. `M-Enter` takes another line whatever the parser says, and `Enter` on an empty line runs what there is. A paste goes into the line at the cursor, its line feeds adding lines and running nothing. The line is edited with the Emacs keys of GNU Readline, and `C-r` and `C-s` search the history backward and forward. A word is a run of letters and digits for the `M-` keys, and `C-w` kills back to a space, as in Readline. When input or output is not a terminal, the shell reads lines and does not edit them, and an input is a line.

**Completion and documentation.** At a terminal `Tab` completes the name before the cursor a segment at a time: what is typed before the last `.` names a namespace, a module or a type with members, and the last segment reaches the names directly in it, a namespace completing with its dot. A segment matches by its prefix or by the starts of its words, `L.fM` reaching `List.filterMap`, and its first letter as typed, since the case of that letter says what a name is (§2.3). A namespace is offered only where it holds a name that may stand there. The names come from what may stand there: a type after `:`, a constructor in a pattern, a field inside a named constructor, a command at an input's start, and a value, constructor, or module anywhere else. After a command, what completes is what the command takes: a module for `:browse`, a module under the source root for `:load`, any name for `:doc`, a name the session declares for `:forget`, a setting for `:set` and, after `timing`, `on` or `off`, and an expression for `:type`. Nothing completes after another command. What the candidates reached by prefix share is completed, and never less than was typed. Where the candidates are reached by the starts of their words alone, the namespace they are all in is completed and the last segment is kept as typed: `L.fM` gives `List.fM`. A lone candidate is completed as far as it goes: a module with the dot after it, and a command or a setting that takes a value with a space after it. A lone candidate is listed whenever `Tab` reaches it, a name with its type and a command or a setting with its help line. Several candidates are listed by a second `Tab`, and by a `Tab` that adds nothing to the line. They are listed alphabetically, those reached by prefix before those reached by the starts of their words. Where nothing is typed, the candidates are the names the session declares, the modules in scope, and the prelude's names other than its constructors; every other name is reached by typing its first letters. `Tab` with only spaces before the cursor on its row indents four spaces. Elsewhere, with nothing before the cursor to complete, it lists what may stand there, after a command as anywhere. `Shift-Tab` on a name, the whole name the cursor stands in, shows its type, its first sentence, and the version it appeared in, and its documentation (§11.4) when pressed again. A name's documentation is its declaration's section of §11.4's page, headed by the name as the session writes it and showing the type the shell prints for it. A constructor's documentation is its type's. A module's is the head of its page: the title, the version, and the module's doc block. A name that is both a type and a module has both, the type's section first. A namespace that is neither lists what it holds, each name with its type. A name bound by a `let` at the prompt has its name and type alone. `:doc` shows the same documentation, so every name that completes after `:doc` has some. The shell shows documentation rendered for the terminal rather than as the CommonMark §11.4 writes. A heading is shown as its text, a code block without its fences, a list item behind a bullet or its number, a block quote behind a bar, and a link as its text with its address after it. Emphasis, strong emphasis, and a code span are shown in the terminal's styles where the shell colours, and as written where it does not. What the shell does not render, raw HTML among it, is shown as written. Prose wraps at the screen's width, 80 columns where there is no terminal. Inside a call, where no name at the cursor is documented, it shows the callee's signature with its parameters as declared and the one at the cursor marked, in cyan where the shell colours and between asterisks where it does not; inside a constructor, its fields, the one whose value is at the cursor marked. The call is found wherever the input stands, in a `let`, a declaration, or a command's argument. A callee that is not a function has no signature, and nothing is shown. What `Tab` and `Shift-Tab` show stands in the region under the input, and the next key takes it away. A line wider than the screen wraps. The lines the screen has no room for are counted on its last row: `and 7 more`.

**Startup and history.** At start, after the file's entry point is spawned, the shell runs the inputs in `$HOME/.ernest/startup` and then those in the configuration directory's `startup`, a line an input, neither file required. Such an input is checked and run as a typed one, a command among them, and its value is not printed; one that fails is reported with the file and the line it came from, and the session goes on. The inputs of a session at a terminal are kept in `$HOME/.ernest/history`, one input a line, a newline in an input written `\n` and a backslash `\\`. Each is appended as it is entered; a blank input and one equal to the input before it are not. The last thousand are kept, and the file is trimmed to them at start. A session whose input is not a terminal neither reads the file nor writes it. A history file that cannot be read or written is reported once, and the session goes on without one. Where the environment sets no `HOME`, a session at a terminal keeps no history and says so once, at start. `--config-dir` names the configuration directory, `./.ernest` by default.

### 11.3 Configuration setup

`ern --create-config-dir dir` creates `dir/.ernest/` with `ernest.conf` and this node's private key, readable only by its owner, and does nothing else; it fails if `dir/.ernest` exists. `ernest.conf` holds this node's network address and public key and the list of peers, each with a name, a network address, a public key, and whether it accepts remote computation; Appendix C shows one. The names are what `Peer(name)` refers to.

### 11.4 Documentation extraction

`ernc --doc file.ern` writes the module's documentation to stdout as CommonMark. The documentation is read from the compiled module, so `ernc --doc file.erc` writes the same text, and a source path is compiled first. The text is: a title naming the module, `# Ernest module Net.Http`, the module's `since v` line (E.0 rule 6) as *Since v.*, and the module's doc block; then, in source order, every exported declaration and every declaration with a doc block, each under a heading of its name as a caller writes it, `Net.Http.parse`, with its type (§11.5) in a code block, under the same name, a `since v` line of its own as *Since v.*, the rest of its doc block, and the doc blocks of its constructors or fields as a list. `ernc --doc src-dir` writes one such document per module into `build-dir` beside the `.erc`, and `index.md` listing them. For the standard library's own source root it also writes the prelude's page, `prelude.md`, titled `# Ernest prelude`, first in the index. The last line names the compiler's version and the source file. A declaration's heading is level two, so a heading inside its doc block is level three or deeper; a heading in the module's doc block is level two. Appendix E.0 rule 6 says what a doc block contains.

### 11.5 Diagnostics

An error is reported as `file:line:column: message`, then the source. The file is the source's path from the working directory, or its absolute path when it lies outside that directory. The source shows a gutter of line numbers, the line before, the erroneous span underlined with `^`, any second span the message depends on, underlined with `-` and labelled, and at most one `help:` line naming the fix. `--errors short` prints the first line alone. The parser reports one error per file; the checker reports every error that does not follow from another.

A type mismatch is reported at the innermost expression whose type is fixed: the last expression of a body or block, a branch or clause after the first, an argument, an operand, an element, or a pattern. The message shows both whole types. The label marks the span that fixed the expectation: an annotation, a callee's type, the first branch, clause, or element, the left operand, or the value matched. The help line names the part in which the types differ. An effect error names the primitive called and the function, `let`, or guard that is pure, and labels the annotation that made it so. An operator whose operand type is not determined (§4.8) is reported with the request to annotate it. A statement whose type is not `Unit` (§5.4) is reported whole, with the help line `let _ =`. A `<-` where the parser expects a delimiter has a help line that names `a < -1` (§2.6). A selector its operand's type lacks is reported at the selector, naming a constructor without the field.

A printed type elides an effect variable bound to pure (§3.9). An effect variable that occurs once in a printed type, and is not process-only, is printed as pure, since the context may bind it to pure: `fn k() -> Int with m = 5` prints as `() -> Int`. The compiler shows the three inferred restrictions of §3.9. In a printed type a variable with the equality constraint is `a=` and one that is not reply-carrying `a!`: `equal : (a=, a=) -> Bool`, `discard : (a!) -> Unit`. A process-only effect variable prints unchanged, and its restriction is stated by the message that rejects a pure instantiation. A type name is printed as the module would write it (§4.2). The module's own types and the prelude's are printed unqualified. Other modules' types are printed qualified. A local type that shadows a prelude name is printed qualified. A type variable is printed under its annotation's name; an unnamed one is `a`, `b`, ... for a value variable and `e`, `e1`, ... for an effect variable, avoiding the names in use. An error at a rejected call site names the parameter and the origin of its restriction; `ernc --doc` prints restrictions the same way.

## Appendix A. Grammar

```
Program     = { Declaration } .
Declaration = [ "export" ] ( TypeDecl | AbstractDecl | FnDecl | LetDecl | ForeignDecl ) .
ForeignDecl = "foreign" ( "type" typename [ "(" ForeignVar { "," ForeignVar } ")" ]
            | "fn" DeclName "(" [ ForeignParam { "," ForeignParam } ] ")" Return "=" string ) .
ForeignVar  = typevar [ "=" ] .
ForeignParam = ident ":" Type .

TypeDecl    = "type" typename [ "(" typevar { "," typevar } ")" ] "="
              Constructor { "|" Constructor } .
Constructor = conname [ "(" ( Type | Field { "," Field } ) ")" ] .
Field       = ident ":" Type .
AbstractDecl  = "abstract" TypeDecl .

FnDecl      = "fn" DeclName "(" [ Param { "," Param } ] ")" [ Return ] "=" Expr .
Param       = Pattern [ ":" Type ] .
Return      = "->" Type [ "with" Type ] .
LetDecl     = "let" DeclName [ ":" Type ] "=" Expr .
Binding     = "let" Pattern [ ":" Type ] ( "=" | "<-" ) Expr .
DeclName    = ident | typename "." ( ident | userop ) .

Type        = TypeAtom | FnType | ParenType .
TypeAtom    = { typename "." } typename [ "(" Type { "," Type } ")" ] | typevar
            | TupleType .
TupleType   = "#(" Type { "," Type } ")" .
FnType      = "(" [ Type { "," Type } ] ")" "->" Type [ "with" Type ] .
ParenType   = "(" Type ")" .

Expr        = Lambda | IfExpr | BinExpr .
Lambda      = "fn" "(" [ Param { "," Param } ] ")" [ Return ] "=" Expr .
IfExpr      = "if" Expr "then" Expr "else" Expr .
MatchExpr   = "match" Expr "{" Clause { "|" Clause } "}" .
Clause      = Pattern { "or" Pattern } [ "when" Expr ] "->" Expr .
ReceiveExpr    = "receive" "{" ( Clause { "|" Clause } [ "|" AfterClause ] | AfterClause ) "}" .
AfterClause    = "after" Expr "->" Expr .
BinExpr     = Unary { binop Unary } .
Unary       = [ "-" | "!" ] Primary { Call | Select } .
Call        = "(" [ Expr { "," Expr } ] ")" .
Select      = "." ident .
Primary     = literal | QName | Tuple | ListLit | BitExpr | Block | MatchExpr | ReceiveExpr
            | "(" Expr ")" .
QName       = { typename "." } ( ident | conname [ "(" ( Expr | Fields ) ")" ] )
            | typename "." { typename "." } userop .
Fields      = ".." Expr "," FieldSet { "," FieldSet } | FieldSet { "," FieldSet } .
FieldSet    = ident "=" Expr .
Tuple       = "#(" Expr { "," Expr } ")" .
ListLit     = "[" [ Expr { "," Expr } ] "]" .
BitExpr     = "<<" [ BitSegE { "," BitSegE } ] ">>" .
BitSegE     = Expr [ ":" BitSpec { "-" BitSpec } ] .
Block       = "{" Stmt { ";" Stmt } "}" .
Stmt        = FnDecl | Binding | Expr .

Pattern     = ConsPat [ "as" ident ] .
ConsPat     = AtomPat [ "::" ConsPat ] .
AtomPat     = "_" | ident | literal | "-" ( int | float )
            | { typename "." } conname [ "(" ( Pattern | FieldPats ) ")" ]
            | "#(" Pattern { "," Pattern } ")"
            | "[" [ Pattern { "," Pattern } ] "]"
            | BitPat .
BitPat      = "<<" [ BitSegP { "," BitSegP } ] ">>" .
BitSegP     = Pattern [ ":" BitSpec { "-" BitSpec } ] .
BitSpec     = "size" "(" Expr ")" | "unit" "(" int ")"
            | "bytes" | "int" | "float"
            | "utf8" | "utf16" | "utf32"
            | "big" | "little"
            | "signed" | "unsigned" .
FieldPats   = [ ident "=" Pattern { "," ident "=" Pattern } ] .
```

`binop`, `userop`, and `literal` are defined in §2, along with the other lexical categories; `binop` precedence follows the table there. Every nonterminal is decided by its first token, or by the later token this paragraph names: `let` begins a binding, `fn` a declaration or lambda (an identifier or type name after `fn` makes it a declaration, `(` a lambda), `{` a block, `[` a list, `#(` a tuple, `(` a call or parenthesized expression, `<<` a bitstring. After a primary, `.` and an `ident` select a field (§3.5): a lowercase first segment is a value, so `s.upper` selects, while an uppercase one begins a `QName`, `Net.Http.parse`. In `QName`, after each uppercase token the next token decides: `.` continues the qualification; otherwise the segment is final: an `ident` names a function or a value, a `userop` an operator, and a `conname` a constructor. A constructor's fields are positional or named by whether `=` or `:` follows the first identifier. When a constructor name is immediately followed by a parenthesized constructor argument, the parser consumes that argument in the constructor branch of `QName`; a single-positional construction has the semantics of calling the constructor's function value. `conname` and `typename` are one token class; which one a segment is follows from its position. A parenthesized list of types is an `FnType` when `->` follows its `)`, and otherwise a `ParenType` (§3).

## Appendix B. Examples

The counter of §6.10, with a `main` that exercises `Inc` and `Get`. `Upgrade` is not exercised here; it is covered by the fragment in §6.10.

```
type CounterMsg =
    Inc(Int)
  | Get(reply : Reply(Int))
  | Upgrade(migrate : (Int) -> Int, next : (Int) -> Unit with CounterMsg)

export fn main() -> Unit with m = {
    let c = spawn(Local, fn() = counter(0));
    send(c, Inc(5));
    send(c, Inc(3));
    match Address.call(c, fn(r) = Get(reply = r), 1000) {
        Some(n) -> Io.println("count is " <> Int.toString(n))
      | None -> Io.println("counter is not answering")
    }
}

fn counter(n : Int) -> Unit with CounterMsg = receive {
    Inc(k) -> counter(n + k)
  | Get(reply = r) -> { answer(r, n); counter(n) }
  | Upgrade(migrate = m, next = k) -> k(m(n))
}
```

```
type PongMsg = Ping(n : Int, reply : Reply(Int)) | Stop
type MainMsg = PongDone(Down)

export fn main() -> Unit with MainMsg = {
    let pongAddr = spawn(Local, fn() = pong());
    let _ = spawn(Local, fn() = ping(pongAddr, 3));
    monitor(pongAddr, PongDone);
    receive { PongDone(_) -> Unit }
}

fn ping(pongAddr : Address(PongMsg), n : Int) -> Unit with m =
    if n == 0 then send(pongAddr, Stop)
    else {
        Io.println("ping " <> Int.toString(n));
        match Address.call(pongAddr, fn(r) = Ping(n = n, reply = r), 5000) {
            Some(_) -> ping(pongAddr, n - 1)
          | None -> { Io.println("pong is not answering"); send(pongAddr, Stop) }
        }
    }

fn pong() -> Unit with PongMsg = receive {
    Ping(n = n, reply = r) -> {
        Io.println("pong " <> Int.toString(n));
        answer(r, n);
        pong()
    }
  | Stop -> Unit
}
```

```
type WorkerMsg = DoWork(f : (String) -> Bytes, arg : String)

fn submitter(worker : Address(WorkerMsg)) -> Unit with Never = {
    send(worker, DoWork(f = String.toUtf8, arg = "hello"));
    send(worker, DoWork(f = String.toUtf8, arg = "world"))
}
```

## Appendix C. Configuration

`ernest.conf`, as created by `ern --create-config-dir` and then edited to name two peers:

```json
{
  "network-address": "145.32.64.6:8654",
  "public-key": "<PEM public key>",
  "peers": [
    {
      "name": "foo",
      "network-address": "145.32.64.7:8654",
      "public-key": "<PEM public key>",
      "remote-peer": true
    },
    {
      "name": "bar",
      "network-address": "145.32.64.8:8654",
      "public-key": "<PEM public key>",
      "remote-peer": false
    }
  ]
}
```

`Peer("foo")` and `Peer("bar")` name these peers in `spawn`, §6.2. `remote(f)` chooses among peers with `"remote-peer": true`, here only `foo`. The private key is in the same directory, `private-key.pem`, readable only by its owner. A freshly created file has an empty `peers` list.

## Appendix D. A Foreign Library

A library over Erlang's `ets`, tables of type `set`, outside the standard library; a program adds its compiled root to the load path (§11.1, §11.2). Raw bindings are module-local, unqualified; the library is ordinary Ernest over them. The values `ets` returns match the ABI of §8.4 without an Erlang-side wrapper: `true` and `false` are `Bool` on both sides, and `[{K, V}]` is `List(#(k, v))`. Erlang's `{ok, V} | {error, R}` convention is the encoding of no Ernest constructor, `Left(e)` and `Right(a)` being `{'Left', e}` and `{'Right', a}`; an API that returns it needs a foreign adapter, an Erlang helper that rewrites the term before it crosses the boundary or a declared foreign decoding function. `Foreign` is opaque (E.12) and no pattern decomposes an atom. The `ets` calls below do not use that convention.

```
// ets.ern  (namespace Ets)

/// A key-value table stored in the runtime's ETS backend, keyed
/// by a value of type k with values of type v. A table lives
/// until Ets.drop is called on it, or until the process that
/// created it dies.
export foreign type Table(k=, v)

/// A fresh empty table. The table is owned by the current
/// process and is destroyed when that process dies.
export fn new() -> Table(k, v) with m =
    rawNew(Erl.atom("ernest"), [Erl.atom("set"), Erl.atom("public")])

foreign fn rawNew(name : Foreign, opts : List(Foreign)) -> Table(k, v) with m = "ets:new/2"

/// Insert or replace the entry for key.
export fn insert(t : Table(k, v), key : k, value : v) -> Unit with m = {
    let _ = rawInsert(t, #(key, value));
    Unit
}

foreign fn rawInsert(t : Table(k, v), row : #(k, v)) -> Bool with m = "ets:insert/2"

/// The value for key, or None if absent.
export fn lookup(t : Table(k, v), key : k) -> Optional(v) with m =
    match rawLookup(t, key) { [#(_, v)] -> Some(v) | _ -> None }

foreign fn rawLookup(t : Table(k, v), key : k) -> List(#(k, v)) with m = "ets:lookup/2"

/// Remove key. A key not present is not an error.
export fn delete(t : Table(k, v), key : k) -> Unit with m = { let _ = rawDelete(t, key); Unit }

foreign fn rawDelete(t : Table(k, v), key : k) -> Bool with m = "ets:delete/2"

/// The number of entries in the table.
export fn size(t : Table(k, v)) -> Int with m = rawInfo(t, Erl.atom("size"))

foreign fn rawInfo(t : Table(k, v), item : Foreign) -> Int with m = "ets:info/2"

/// Delete the table. All subsequent operations on it fault.
export fn drop(t : Table(k, v)) -> Unit with m = { let _ = rawDrop(t); Unit }

foreign fn rawDrop(t : Table(k, v)) -> Bool with m = "ets:delete/1"

/// Remove all entries, leaving the table empty.
export fn clear(t : Table(k, v)) -> Unit with m = { let _ = rawClear(t); Unit }

foreign fn rawClear(t : Table(k, v)) -> Bool with m = "ets:delete_all_objects/1"

/// True if key is present in t.
export foreign fn member(t : Table(k, v), key : k) -> Bool with m = "ets:member/2"

/// All key-value pairs currently in the table, in unspecified order.
export foreign fn toList(t : Table(k, v)) -> List(#(k, v)) with m = "ets:tab2list/1"
```

```
export fn main() -> Unit with Never = {
    let t = Ets.new();
    Ets.insert(t, "a", 1);
    Ets.insert(t, "b", 2);
    match Ets.lookup(t, "a") {
        Some(n) -> Io.println(Int.toString(n))
      | None -> Io.println("missing")
    };
    Ets.drop(t)
}
```

The `raw` names have no `export` and are invisible outside the module; the exported `Ets.*` interface is what callers see. `Ets.Table(k, v)` has type parameters the implementation never sees: `Ets.insert(t, "a", 1)` fixes `t` to `Ets.Table(String, Int)`, and an insert with other types on the next line is a type error. Every operation has a mailbox type, `size` and `member` included: they read state that others write. `atom` is pure: the same text gives the same atom. What the type cannot say, the declaration's documentation says: a table lives until `Ets.drop`, or until the process that created it dies. A table is state that every process holding it reads and writes, which a foreign function with a mailbox type may make (§4.7) and the standard library does not (E.0 rule 1).

## Appendix E. Standard Library

E.0 is normative; a function enters this appendix by its rules before it enters `stdlib/`. The listing that follows is what E.0 has admitted, the modules that ship with the compiler as ordinary Ernest files under `stdlib/`. The standard library is on the load path by default; every program can call `Io.println`, `List.map`, and the rest without any setup. The prelude in §9 is what the language itself requires. Everything else here is written in Ernest on top of the language and prelude, except the shims that E.0's first rule admits.

### Appendix E.0. Rules

Four rules decide whether a function is in. None of them counts programs: a function enters when a rule admits it, whether or not a program has asked, and a program that wants one the rules refuse writes it itself.

1. Its value lives in the runtime and Ernest cannot compute it, given the modules beneath it: the `Map` and `Set` operations, the Unicode operations on `String` and `Char`, `Int.toString` and `Float.toString`, the conversions between `Int` and `Float` and between `Int` and `Char`, the `Bytes` operations, the bit operations, `Foreign`, `Erl.atom`, `Random`, and the modules over the system references of §8.2. These are shims over `foreign fn` or over a system process, and a shim exists only where this rule applies. The line is ownership: where the runtime owns the representation, a `Map`, a `Set`, a `String`, a `Bytes`, a `Float`, its operations are the runtime's; what the language owns, `[]` and `::` among them, is written in Ernest, `List.sort` among it. Speed is not a reason for a shim; where a measurement ever demands one, it is admitted with the measurement beside it. The rule decides how an operation is carried out, never what a value is: where a value's identity, lifetime, or failure is the program's concern, it is a process (§8.2), and no shim stands in for one.
2. It follows from the type's structure, and each kind of type has a vocabulary. A container provides the container operations of the vocabulary below, or says in its section which it lacks and why. A sequence adds order and position: `reverse`, `sort`, `take`, `drop`, `dropLast`, `last`, `span`, `partition`, `unique`, `indexed`, `repeat`, `zip`, `unzip`, `flatMap`, `range`, and `tryMap` and `tryFold` for a step that can fail. Text adds `startsWith`, `endsWith`, `indexOf`, `lastIndexOf`, `replace`, `slice`, `padStart`, `padEnd`, `repeat`, `split`, `join`, `lines`, `trim`, `toLower`, `toUpper`, and a `Char` `isUpper`, `isLower`, `toUpper`, `toLower`. A path adds its segments: `join`, `split`, `parent`, `name`, `extension`, `withExtension`, `isAbsolute`. A filesystem adds files and directories: `read`, `write`, `append`, `list`, `stat`, `makeDir`, `remove`, `rename`, `copy`. A conversion to text has its inverse where the text form is unambiguous and the type has no other way in; a `Char` has `String.toList` and needs none. A type that enters by rule 3 still gets its structure's vocabulary, not only the functions the program wrote.
3. It is a general operation of the type, its definition is the obvious one, and no policy is buried in it: `List.foldRight`, `Float.sqrt`. A function whose result depends on a choice the library would be making for the program, a format, a locale, a tolerance, is refused whatever asks for it.
4. It is not a composition. A function that is one pipe of two functions already here is not added: `List.concat` is `List.flatMap(xs, fn(x) = x)`, `List.sum` is `List.foldLeft(xs, 0, Int.+)`.

Nine rules give a function its shape.

1. The subject comes first, callbacks last, an accumulator between them: `x |> f(a)` is `f(x, a)`. No aliases, no argument-order variants.
2. One verb per operation, in every module that has it. The container operations are `empty`, `size`, `isEmpty`, `contains`, `get` for lookup by index or key, `put` for insertion, `remove`, `map`, `filter`, `filterMap`, `foldLeft`, `foreach`, `any`, `all`, `find`, `fromList`, and `toList`; the sum-type operations are `withDefault`, `map`, and `andThen`. A predicate is `isX`. A verb not in this list names an operation none of these does, and one verb names it in every module that has it.
3. A conversion is named by the other type and lives in the subject's module: `String.toInt`, `String.fromList`, `Int.toString`. When one conversion has several policies, the policy is the name: `Float.round`, `Float.floor`, `Float.ceil`, `Float.truncate`.
4. A partial operation returns `Optional`; one with a cause returns `Either`. No function here faults except as §7.4 or the function's own section says.
5. A function is pure unless its value lives in a process: the modules over the system references of §8.2 carry `with m`, and nothing else does. A function that calls a function it takes is effect-polymorphic in it (§3.9). A wrapping function that rule 8 delivers through is pure, as `via`'s is (§6.5).
6. A module is documented as a section 3 manual page, in CommonMark (§2.2). Under `See also`, a declaration or a module is named in backticks and not linked.
   - **The module.** Its doc block says what the module is for, then has the section `Examples`, with the module's central examples, and `See also` when there is something to see. It ends with the line `since v`, the toolchain version in which the module appeared.
   - **A declaration.** Every exported declaration has a doc block: one sentence saying what the type does not say, which occurrence `remove` removes, the order `toList` produces, the range `next` draws from; an `Errors` section when it faults, and none otherwise (rule 4); an `Examples` section with one example for an exported `type`, an abstract type's examples covering its members; `See also` when there is something to see. A declaration has the module's `since` unless its doc block ends with one of its own. The name and the type are the heading and the code block `ernc --doc` renders (§11.4).
   - **Examples.** Every exported function except an operator, whose use is infix, is called by at least one example on the module's page, in the module's examples or its own, and an example that would repeat another is left out. An example ends in `// => v`, where `v` is what `Io.debug` prints for its value; what the example itself prints comes before it and is not part of `v`. An example that cannot run where the page's examples run, because its value is of an abstract type, because it reads a file or a socket, or because it needs a mailbox of its own, has no `// =>` line and is only type-checked.
7. A type a module declares is listed in its section as its functions are, `foreign type Seed` in E.13, and is named for what it is within the module, never for the module. The types the runtime speaks are the prelude's, §9.3.
8. A system reference of §8.2 is used through its standard library module, never by `send`. A function that waits takes the milliseconds as its last argument and answers `Left(Timeout)`; `Clock.now`, `Terminal.size`, `Terminal.subscribe`, `Tcp.listen`, and `Io.readLine` take none, the first four answered at once and the last waiting for the user; one that delivers later takes a function from the message to the caller's mailbox type and delivers to the caller, as `monitor` does (§6.9). In either, a time below 0 is 0, a time has no upper bound, and a moment already past is now.
9. An exported function takes no `Bool` that chooses between two behaviours. It takes a type whose constructors name them, so that the call says which: `render(doc, Plain)`, not `render(doc, false)`. A `Bool` that is the value operated on, as in `Bool.not`, is not such a choice.

### Appendix E.1. `io.ern` (namespace `Io`)

Output to `Sys.stdout` and input from `Sys.stdin` (§8.2). A string goes to any other `Address(String)` by `send`.

```
Io.print : (String) -> Unit with m
Io.println : (String) -> Unit with m // appends "\n"
Io.printError : (String) -> Unit with m // to `Sys.stderr`
Io.printlnError : (String) -> Unit with m // appends "\n"
Io.readLine : () -> Optional(String) with m // the next line without its line feed; None at end of input
Io.debug : (a) -> a with m // prints the value as Ernest writes it, then returns it
```

`Io.debug` writes to `Sys.stdout` and ends what it writes with a line feed. It prints by the argument's type at the call, each value as its literal or construction is written: a `Char` as `'a'`, `Bytes` as `<<104, 105>>`, a named constructor with its fields in canonical order (§3.5), `Snap(dir = "x", seen = 2)`. A `Map` prints as `Map.fromList` of its pairs, a `Set` as `Set.fromList` of its elements. An address, a reply, and a function print as `<address>`, `<reply>`, and `<function>`, and a value of an abstract type outside its module as `<abstract>`. Where the argument's type is a type variable or a foreign type, the value is printed by its runtime representation (§8.4): a `Char` as its `Int`, a `Bytes` that is UTF-8 as a `String`, a constructor's fields positional, and `<foreign>` where the representation reads as none of these.

### Appendix E.2. `list.ern` (namespace `List`)

`[]` is `empty` and `::` is `put`, so neither is a function; `fromList` and `toList` are the identity and are not provided. `contains`, `remove`, and `unique` require equality on `a` (§3.10). `List.<>` is the prelude's, §9.6; this module provides it (§9).

```
List.size : (List(a)) -> Int
List.isEmpty : (List(a)) -> Bool
List.contains : (List(a), a) -> Bool
List.get : (List(a), Int) -> Optional(a) // by index from 0; None for a negative index and one past the end
List.remove : (List(a), a) -> List(a) // the first occurrence
List.map : (List(a), (a) -> b with e) -> List(b) with e
List.filter : (List(a), (a) -> Bool with e) -> List(a) with e
List.filterMap : (List(a), (a) -> Optional(b) with e) -> List(b) with e
List.foldLeft : (List(a), b, (b, a) -> b with e) -> b with e
List.foldRight : (List(a), b, (a, b) -> b with e) -> b with e // from the right, the element first
List.foreach : (List(a), (a) -> Unit with e) -> Unit with e
List.any : (List(a), (a) -> Bool with e) -> Bool with e
List.all : (List(a), (a) -> Bool with e) -> Bool with e
List.find : (List(a), (a) -> Bool with e) -> Optional(a) with e // the first that satisfies
List.last : (List(a)) -> Optional(a)
List.take : (List(a), Int) -> List(a) // the first n, or all when there are fewer; n below 0 is 0
List.drop : (List(a), Int) -> List(a) // all but the first n; n below 0 is 0
List.dropLast : (List(a)) -> List(a) // the empty list stays empty
List.span : (List(a), (a) -> Bool with e) -> #(List(a), List(a)) with e // the longest prefix that satisfies, and the rest
List.partition : (List(a), (a) -> Bool with e) -> #(List(a), List(a)) with e // those that satisfy and those that do not, each in order
List.unique : (List(a)) -> List(a) // the first occurrence of each, in order
List.indexed : (List(a)) -> List(#(Int, a)) // each element with its index from 0
List.repeat : (a, Int) -> List(a) // n copies; n below 0 is 0
List.reverse : (List(a)) -> List(a)
List.sort : (List(a), (a, a) -> Ordering with e) -> List(a) with e // stable
List.zip : (List(a), List(b)) -> List(#(a, b)) // to the shorter length
List.unzip : (List(#(a, b))) -> #(List(a), List(b))
List.flatMap : (List(a), (a) -> List(b) with e) -> List(b) with e
List.range : (Int, Int) -> List(Int) // from the first to the second inclusive; empty when the first is greater
List.tryMap : (List(a), (a) -> Either(e, b) with x) -> Either(e, List(b)) with x // the first Left ends it
List.tryFold : (List(a), b, (b, a) -> Either(e, b) with x) -> Either(e, b) with x // the first Left ends it
```

### Appendix E.3. `map.ern` (namespace `Map`)

Requires equality on `k` (§3.10). The order of `keys`, `values`, `toList`, `foldLeft`, `foreach`, and `find` is unspecified.

```
Map.empty : Map(k, v)
Map.size : (Map(k, v)) -> Int
Map.isEmpty : (Map(k, v)) -> Bool
Map.contains : (Map(k, v), k) -> Bool
Map.get : (Map(k, v), k) -> Optional(v)
Map.put : (Map(k, v), k, v) -> Map(k, v) // replaces an entry with that key
Map.remove : (Map(k, v), k) -> Map(k, v) // a key not present is not an error
Map.update : (Map(k, v), k, (Optional(v)) -> v with e) -> Map(k, v) with e // the entry, present or not, replaced by the function's value
Map.map : (Map(k, v), (k, v) -> w with e) -> Map(k, w) with e
Map.filter : (Map(k, v), (k, v) -> Bool with e) -> Map(k, v) with e
Map.filterMap : (Map(k, v), (k, v) -> Optional(w) with e) -> Map(k, w) with e
Map.foldLeft : (Map(k, v), b, (b, k, v) -> b with e) -> b with e
Map.foreach : (Map(k, v), (k, v) -> Unit with e) -> Unit with e
Map.any : (Map(k, v), (k, v) -> Bool with e) -> Bool with e
Map.all : (Map(k, v), (k, v) -> Bool with e) -> Bool with e
Map.find : (Map(k, v), (k, v) -> Bool with e) -> Optional(#(k, v)) with e // some entry that satisfies
Map.merge : (Map(k, v), Map(k, v)) -> Map(k, v) // the second wins for a shared key
Map.fromList : (List(#(k, v))) -> Map(k, v) // a later pair wins
Map.toList : (Map(k, v)) -> List(#(k, v))
Map.keys : (Map(k, v)) -> List(k)
Map.values : (Map(k, v)) -> List(v)
```

### Appendix E.4. `set.ern` (namespace `Set`)

Requires equality on `a` (§3.10). A set has no `get`; membership is `contains`. The order of `toList`, `foldLeft`, `foreach`, and `find` is unspecified.

```
Set.empty : Set(a)
Set.size : (Set(a)) -> Int
Set.isEmpty : (Set(a)) -> Bool
Set.contains : (Set(a), a) -> Bool
Set.put : (Set(a), a) -> Set(a) // an element already present is not an error
Set.remove : (Set(a), a) -> Set(a) // an element not present is not an error
Set.map : (Set(a), (a) -> b with e) -> Set(b) with e // requires equality on b
Set.filter : (Set(a), (a) -> Bool with e) -> Set(a) with e
Set.filterMap : (Set(a), (a) -> Optional(b) with e) -> Set(b) with e // requires equality on b
Set.foldLeft : (Set(a), b, (b, a) -> b with e) -> b with e
Set.foreach : (Set(a), (a) -> Unit with e) -> Unit with e
Set.any : (Set(a), (a) -> Bool with e) -> Bool with e
Set.all : (Set(a), (a) -> Bool with e) -> Bool with e
Set.find : (Set(a), (a) -> Bool with e) -> Optional(a) with e // some element that satisfies
Set.fromList : (List(a)) -> Set(a)
Set.toList : (Set(a)) -> List(a)
Set.union : (Set(a), Set(a)) -> Set(a)
Set.intersect : (Set(a), Set(a)) -> Set(a)
Set.difference : (Set(a), Set(a)) -> Set(a) // the elements of the first not in the second
Set.isSubset : (Set(a), Set(a)) -> Bool // every element of the first is in the second
```

### Appendix E.5. `string.ern` (namespace `String`)

A `String` is not a container: operations on its `Char`s go through `toList`. `size`, `slice`, `indexOf`, `lastIndexOf`, `padStart`, and `padEnd` count and index in graphemes, extended grapheme clusters, each what a reader sees as one letter. `toList` and `fromList` are `Char`s, one scalar value each, so a string holding a combining mark has more `Char`s than graphemes. `String.compare` and `String.<>` are the prelude's, §9.6; this module provides them (§9).

```
String.size : (String) -> Int // graphemes
String.isEmpty : (String) -> Bool
String.contains : (String, String) -> Bool // substring
String.indexOf : (String, String) -> Optional(Int) // where the second begins, None where it is not there; an empty second is 0
String.lastIndexOf : (String, String) -> Optional(Int) // where the second begins last, None where it is not there; an empty second is the first's size
String.startsWith : (String, String) -> Bool
String.endsWith : (String, String) -> Bool
String.replace : (String, String, String) -> String // every occurrence of the second by the third; an empty second changes nothing
String.slice : (String, Int, Int) -> String // from the index, that many graphemes, clipped to the string; a negative index or count is 0
String.padStart : (String, Int, Char) -> String // the Char in front until the size is at least the second
String.padEnd : (String, Int, Char) -> String // the Char at the end until the size is at least the second
String.repeat : (String, Int) -> String // n times; n below 0 is 0
String.trim : (String) -> String // without leading and trailing whitespace
String.toLower : (String) -> String
String.toUpper : (String) -> String
String.lines : (String) -> List(String) // at each line feed; a line feed at the end adds no empty line, and "" has no lines
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

The predicates use the Unicode properties of the code point: `isDigit` is general category Nd, `isAlpha` is category L, `isSpace` is White_Space, `isUpper` is Lu, `isLower` is Ll. `Char.compare` is the prelude's, §9.6; this module provides it (§9).

```
Char.isDigit : (Char) -> Bool
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

`Int.div`, `Int.mod`, `Int.compare`, `Int.negate`, and the operators are the prelude's, §9.6; this module provides them (§9).

```
Int.abs : (Int) -> Int
Int.min : (Int, Int) -> Int
Int.max : (Int, Int) -> Int
Int.bitAnd : (Int, Int) -> Int
Int.bitOr : (Int, Int) -> Int
Int.bitXor : (Int, Int) -> Int
Int.bitNot : (Int) -> Int
Int.shiftLeft : (Int, Int) -> Int // times two to the power of the second; a negative second shifts right
Int.shiftRight : (Int, Int) -> Int // arithmetic, sign-preserving; a negative second shifts left
Int.pow : (Int, Int) -> Optional(Int) // exact; None for a negative exponent; Int.pow(0, 0) is Some(1)
Int.toString : (Int) -> String
Int.toStringBase : (Int, Int) -> Optional(String) // in that base, 2 to 36, with upper-case letters; None outside
Int.toFloat : (Int) -> Float // faults outside the finite range, §3.1
```

### Appendix E.9. `float.ern` (namespace `Float`)

`Float.compare`, `Float.negate`, and the operators are the prelude's, §9.6; this module provides them (§9). The module holds the operations of the type itself. Mathematics over collections of floats, statistics, matrices, and numerical methods, is a library.

```
Float.abs : (Float) -> Float
Float.min : (Float, Float) -> Float
Float.max : (Float, Float) -> Float
Float.toString : (Float) -> String // the shortest decimal that reads back as the same value
Float.round : (Float) -> Int // to the nearest, ties to even
Float.truncate : (Float) -> Int // toward zero
Float.floor : (Float) -> Int
Float.ceil : (Float) -> Int
Float.sqrt : (Float) -> Optional(Float) // None below zero
Float.pow : (Float, Float) -> Optional(Float) // None for a negative base with a fractional exponent, and for zero to a negative power
Float.exp : (Float) -> Float
Float.log : (Float) -> Optional(Float) // the natural logarithm; None at zero and below
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
Optional.isSome : (Optional(a)) -> Bool
Optional.isNone : (Optional(a)) -> Bool
Optional.withDefault : (Optional(a), a) -> a
Optional.orElse : (Optional(a), Optional(a)) -> Optional(a) // the first that is Some
Optional.map : (Optional(a), (a) -> b with e) -> Optional(b) with e
Optional.andThen : (Optional(a), (a) -> Optional(b) with e) -> Optional(b) with e
```

### Appendix E.11. `either.ern` (namespace `Either`)

```
Either.isLeft : (Either(e, a)) -> Bool
Either.isRight : (Either(e, a)) -> Bool
Either.withDefault : (Either(e, a), a) -> a
Either.orElse : (Either(e, a), Either(e, a)) -> Either(e, a) // the first that is Right
Either.map : (Either(e, a), (a) -> b with x) -> Either(e, b) with x
Either.mapLeft : (Either(e, a), (e) -> b with x) -> Either(b, a) with x
Either.andThen : (Either(e, a), (a) -> Either(e, b) with x) -> Either(e, b) with x
Either.toOptional : (Either(e, a)) -> Optional(a)
Either.fromOptional : (Optional(a), e) -> Either(e, a)
```

### Appendix E.12. `foreign.ern` (namespace `Foreign`)

```
Foreign.from : (a) -> Foreign // the value as the runtime holds it (§8.4)
Foreign.toInt : (Foreign) -> Optional(Int)
Foreign.toFloat : (Foreign) -> Optional(Float)
Foreign.toString : (Foreign) -> Optional(String)
Foreign.toBool : (Foreign) -> Optional(Bool)
Foreign.toList : (Foreign) -> Optional(List(Foreign))
```

### Appendix E.13. `random.ern` (namespace `Random`)

The runtime's generator behind a pure interface. `Seed` is a foreign type (§3.8): made by `seed`, bound to its node, and the same seed gives the same sequence on one runtime version. A program that wants a fresh seed takes `Clock.now()`.

```
foreign type Seed
Random.seed : (Int) -> Random.Seed // numbers equal in their low 64 bits name the same sequence
Random.next : (Random.Seed, Int) -> #(Int, Random.Seed) // uniform between 0 and the second inclusive, whatever the second's sign, and the seed after it
Random.nextFloat : (Random.Seed) -> #(Float, Random.Seed) // uniform above 0.0 and below 1.0, and the seed after it
```

### Appendix E.14. `path.ern` (namespace `Path`)

`Path` is `Path(String)`, §9.3, in the runtime's syntax.

```
Path.join : (Path, Path) -> Path // the second under the first; an absolute second stands alone
Path.split : (Path) -> List(String) // the segments; an absolute path's first is the root
Path.parent : (Path) -> Optional(Path) // None for a bare name or the root
Path.name : (Path) -> String // the last segment
Path.extension : (Path) -> Optional(String) // after the last "." of the name, without it
Path.withExtension : (Path, String) -> Path // replaced or added; an empty string removes it
Path.isAbsolute : (Path) -> Bool
Path.toString : (Path) -> String
```

### Appendix E.15. `clock.ern` (namespace `Clock`)

Over `Sys.clock`. Times are milliseconds since the epoch. An alarm fires once and cannot be cancelled: a process that no longer wants it ignores the message, and a periodic tick is scheduled after the previous one is handled.

```
Clock.now : () -> Int with m
Clock.alarm : (Int, (Int) -> m) -> Unit with m // after the milliseconds, wrap(t) in the caller's mailbox, t the time it fired
Clock.alarmAt : (Int, (Int) -> m) -> Unit with m // at the time, wrap(t) in the caller's mailbox, t the time it fired
```

### Appendix E.16. `terminal.ern` (namespace `Terminal`)

Over `Sys.terminal`.

```
Terminal.subscribe : ((Event) -> m) -> Unit with m // every key pressed and every resize from now on, wrapped, in the caller's mailbox; a second call replaces the first
Terminal.size : () -> Optional(Size) with m        // the terminal's size now, None where there is no terminal
```

### Appendix E.17. `fs.ern` (namespace `Fs`)

Over `Sys.fs`. The last argument is the milliseconds to wait.

```
Fs.read : (Path, Int) -> Either(IoError, Bytes) with m
Fs.write : (Path, Bytes, Int) -> Either(IoError, Unit) with m // creates or replaces
Fs.append : (Path, Bytes, Int) -> Either(IoError, Unit) with m // creates or extends
Fs.list : (Path, Int) -> Either(IoError, List(Entry)) with m // the entries of a directory, in unspecified order, each path the directory's joined with the entry's name
Fs.stat : (Path, Int) -> Either(IoError, Entry) with m
Fs.makeDir : (Path, Int) -> Either(IoError, Unit) with m // with its missing parents; an existing directory is not an error
Fs.remove : (Path, Int) -> Either(IoError, Unit) with m // a file or an empty directory
Fs.rename : (Path, Path, Int) -> Either(IoError, Unit) with m // the first to the second
Fs.copy : (Path, Path, Int) -> Either(IoError, Unit) with m // a file, the first to the second; replaces
```

### Appendix E.18. `tcp.ern` (namespace `Tcp`)

Over `Sys.tcp`. A socket is a process: its address can be sent, monitored, and killed like any other, and it dies with the connection. `Tcp.write` is a send: it returns at once, and a connection that fails shows as the socket's death to a monitor and as `Left(Closed)` from the next `Tcp.read`. There are no options; framing is bitstrings (§5.11). The last argument of a function that waits is the milliseconds.

```
Tcp.listen : (Int) -> Either(IoError, Address(ListenerMsg)) with m // the port
Tcp.accept : (Address(ListenerMsg), Int) -> Either(IoError, Address(SockMsg)) with m
Tcp.connect : (String, Int, Int) -> Either(IoError, Address(SockMsg)) with m // host, port
Tcp.read : (Address(SockMsg), Int) -> Either(IoError, Bytes) with m // what has arrived, at least one byte
Tcp.write : (Address(SockMsg), Bytes) -> Unit with m
Tcp.close : (Address(SockMsg)) -> Unit with m
```

### Appendix E.19. `erl.ern` (namespace `Erl`)

What a shim over an Erlang API needs from Erlang's conventions (rule 1). An API that answers `{ok, V}` or `{error, R}` needs an Erlang helper that rewrites the answer to `Either`'s encoding, `{'Right', V}` or `{'Left', R}` (§8.4).

```
Erl.atom : (String) -> Foreign // the Erlang atom of the text
```

### Appendix E.20. `bytes.ern` (namespace `Bytes`)

A `Bytes` is not a container: operations on its octets go through `toList`, which gives each as an `Int` from 0 to 255. `Bytes.<>` is the prelude's, §9.6; this module provides it. `<<...>>` builds and matches a `Bytes` at the bit level (§5.11), so there is no constructor here.

```
Bytes.size : (Bytes) -> Int // octets
Bytes.isEmpty : (Bytes) -> Bool
Bytes.get : (Bytes, Int) -> Optional(Int) // the octet at the index from 0
Bytes.slice : (Bytes, Int, Int) -> Bytes // from the index, that many octets, clipped; a negative index or count is 0
Bytes.toList : (Bytes) -> List(Int)
Bytes.fromList : (List(Int)) -> Optional(Bytes) // None when a value is outside 0 to 255
```

## Appendix F. Glossary

Every technical term this report introduces, with the section that defines it. Pointers only — the definition lives in the referenced section.

- **abstract type** — a sum type whose constructors are visible only in the module that declares it. §3.6, §4.4.
- **address** — `Address(m)`, a reference to a process that receives values of type `m`. §3.7, §6.5.
- **arity** — the number of arguments a function takes; part of its type. §4.5.
- **binding** — a `let` in a block, `let p = e` or `let p <- e`. §4.6, §5.5.
- **bitstring** — a bit-level value or pattern `<<...>>` that produces or matches a `Bytes` value. §5.11.
- **`Bytes`** — the type of an octet sequence. §3.1.
- **canonical order** — the order in which a constructor's named fields are stored and transported. §3.5.
- **clause** — one pattern-branch of a `match` or `receive`. §5.9, §6.3.
- **compare** — the per-type function that produces `Ordering`. §3.10.
- **concat operator** — `<>`, resolved per type: `String.<>`, `List.<>`, `Bytes.<>`. §4.8.
- **cons operator** — `::`, list-prepend, right-associative. §3.3, §5.10.
- **constructor** — a case of a sum type; a value, a function, or a construction form. §3.5, §5.6.
- **consumed** — of a reply-carrying value: answered, or handed on by one of the uses §6.6 lists, exactly once on every path. §6.6.
- **content addressing** — naming a definition or type by the hash of its content. §8.7.
- **deadlock** — no process can progress; the entry process faults with `Fault("deadlock")`. §8.6.
- **doc block** — consecutive `///` lines, read as CommonMark. §2.2.
- **doc comment** — `///` to end of line; attached to the following declaration. §2.2.
- **effect polymorphism** — a mailbox effect that is a type variable. §3.9.
- **effect position** — the type after `with` in a function type. §3.9.
- **entry point** — the function `ern` calls to run a program: the module's `export fn main`, or the function `--main` names. §8.1, §11.2.
- **entry process** — the process that runs the entry point. §8.1, §8.6.
- **equality constraint** — the restriction on a type variable compared with `==`, or on a foreign type's parameter written `k=`. §3.10, §4.7.
- **fault** — a process death with the reason `Fault(cause)`; not catchable. §7.3, §7.4.
- **field selection** — `e.f`, the named field `f` of `e`, where every constructor of the type has it. §3.5.
- **foreign function** — declared `foreign fn`; body is a string reference to a runtime implementation. §4.7.
- **foreign type** — declared `foreign type T`; values are made and used only by foreign functions. §3.8, §4.7.
- **generalization** — quantifying free type variables in a `fn` definition or a top-level `let`. §3.9, §4.6.
- **guard** — a `when` expression on a `match` or `receive` clause. §5.9.
- **guard expression** — the form of a `receive` guard. §6.3.
- **Hindley-Milner** — the type system Ernest uses; inference asks for an annotation only where §3.9 says. §3.9.
- **inferred restriction** — the equality constraint, process-only, or not-reply-carrying, inferred from a body and never written. §3.9.
- **irrefutable pattern** — a pattern that cannot fail; required in `let` and function parameters. §5.10.
- **lambda** — an anonymous function, `fn(x) = e`. §5.3.
- **literal** — a token that stands for an `Int`, `Float`, `Char`, `String`, or `Bool` value. §2.5.
- **mailbox** — the queue of values a process receives. §6.
- **mailbox type** — the `M` in `(A) -> B with M`; the type of the process's mailbox. §6.1.
- **`match`** — the pattern-matching expression form. §5.9.
- **module** — a single Ernest source file (`.ern`); the unit of compilation and namespace. §4.1.
- **monitor** — `monitor(a, wrap)`; sends `wrap(d)` to the caller when `a` dies. §6.9, §9.5.
- **named field** — a field on a constructor identified by name, not position. §3.5.
- **namespace** — the dotted prefix of a name; equal to the module's path. §4.2.
- **`Never`** — the type with no values; as a mailbox type, a process that cannot receive. §3.7, §6.8.
- **node** — one running runtime; a peer is another node. §8.3.
- **not-reply-carrying** — the restriction on a parameter a function duplicates or discards: it cannot take a reply-carrying value. §3.9, §6.6.
- **obligation** — a binding of a reply-carrying value, consumed exactly once on every path. §6.6.
- **operator resolution** — per-type dispatch of arithmetic and `<>` to `Type.<op>`. §4.8.
- **pattern** — decomposes a value and binds its parts. §5.10.
- **peer** — another node the runtime knows by name. §6.2, §8.3.
- **pipe** — the `|>` operator, `x |> f` = `f(x)`. §5.7.
- **positional field** — a field on a constructor identified by position, not name. §3.5.
- **precedence** — the binding tightness of a binary operator. §2.6.
- **prelude** — the small set of names the language requires to exist. §9.
- **`Prelude`** — the prelude's own namespace, `Prelude.Close`, for a name a module has shadowed. §4.2.
- **process** — an execution of a function with a mailbox. §6.
- **process-only** — a function whose effect variable cannot be pure. §3.9.
- **pure function** — a function without a mailbox type; result depends only on arguments. §0, §6.1.
- **qualified name** — a name with a dotted namespace prefix, `Net.Http.parse`. §2.3, §4.2.
- **`receive`** — a match over the mailbox. §6.3.
- **redundant** — of a clause or an alternative: able to match no value those before it leave; a type error. §5.9.
- **remote computation** — `remote(f)` evaluates a pure function on a peer. §6.7.
- **`Reply(a)`** — a one-shot address for the answer to a request. §3.7, §6.6.
- **reply-carrying** — a type that transitively contains a `Reply`. §6.6.
- **reserved word** — one of eighteen keywords. §2.4.
- **runtime** — the system that runs Ernest programs. §10.
- **`self`** — `self()`, the current process's own address. §6.2.
- **`send`** — `send(a, v)`, places `v` in the mailbox of `a`. §6.2.
- **source root** — the directory under which a file's path gives its namespace. §4.2, §11.1.
- **`spawn`** — `spawn(w, f)`, starts a new process; `spawnMonitored(w, f, wrap)` starts one monitored from its start. §6.2.
- **standard library** — the modules under `stdlib/`, on the load path by default; not the prelude. §9, Appendix E.
- **structural equality** — the meaning of `==`; two values are equal when they are built by the same constructor from equal parts. §3.10.
- **sum type** — a type with one or more constructors. §3.5.
- **system module** — the standard library module of a system reference's name, through which a program uses it. §8.2, Appendix E.0.
- **system process** — a process the runtime starts and keeps, its implementation foreign, its address a system reference. §8.2, §8.4.
- **system reference** — a top-level address in `Sys.*`, wired by the runtime. §8.2.
- **tail position** — a function's body, and the branches, clause bodies, and last block expressions within it. §10.
- **taken namespace** — a namespace of the prelude or the standard library, which no other module may provide. §4.2.
- **top-level binding** — a value bound at file scope by a `let` or provided by the runtime. §4.6, §8.2.
- **tuple** — a positional product, `#(a, b)`, `#(a, b, c)`, `#(a)`. §3.2.
- **type member** — a name declared with its type's prefix, `fn Distance.+`, in the type's nested namespace. §4.2.
- **type variable** — a lowercase identifier in type position; universally quantified in a `fn` or a top-level `let`. §3.9.
- **`Unit`** — the type with the single value `Unit`. §3.1, §9.3.
- **value position** — an argument, a result, a tuple component, or a type argument whose parameter occurs in a value position of its type's fields. §3.9.
- **`via`** — `via(f, addr)` is the address `addr` seen through `f`. §6.5, §9.5.
- **wildcard** — the pattern `_`; matches anything, binds nothing. §2.3, §5.10.
- **`with`** — the mailbox-type marker on a function type, `with M`. §3.4, §6.1.
