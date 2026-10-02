# Ernest: Language Report

Revision of 2 October 2026. Rationale and rejected alternatives are in [`decisions.md`](docs/decisions.md), and the decisions still to be made in [`implementation_plan.md`](docs/implementation_plan.md).

**Contents**
<!-- contents -->
- [0. Introduction](#0-introduction)
- [1. Notation](#1-notation)
- [2. Lexical Elements](#2-lexical-elements)
- [3. Types](#3-types)
- [4. Declarations and Scope](#4-declarations-and-scope)
- [5. Expressions](#5-expressions)
- [6. Processes](#6-processes)
- [7. Errors](#7-errors)
- [8. Programs](#8-programs)
- [9. Prelude](#9-prelude)
- [10. Runtime Requirements](#10-runtime-requirements)
- [11. Toolchain](#11-toolchain)
- [Appendix A. Grammar](#appendix-a-grammar)
- [Appendix B. Examples](#appendix-b-examples)
- [Appendix C. Configuration](#appendix-c-configuration)
- [Appendix D. A Foreign Library](#appendix-d-a-foreign-library)
- [Appendix E. Standard Library](#appendix-e-standard-library)
- [Appendix F. Glossary](#appendix-f-glossary)
- [Appendix G. Libraries](#appendix-g-libraries)
<!-- /contents -->

## 0. Introduction

Ernest is a functional language for concurrent programs. It has two concepts: functions, with Hindley-Milner types, and processes with typed mailboxes, the only way to affect the world. Everything else in this report is a rule for how the two show up in each other.

Every function runs inside a process, an execution of a function with a mailbox that receives values of one type. A function that sends, receives, or asks for its own address acts through its process and names its mailbox in its type, `(A) -> B with M`; that is the only mark written on a function type. A function that does not act through its process is pure: its result depends only on its arguments, and it affects nothing. §3 and §6 make this precise; §10 states what the runtime must provide.

Five principles. Principles 2 to 5 are constructive; when following them yields code that surprises, principle 1 overrides.

1. Least surprise decides. A design surprises when a reader who knows the rest of Ernest would predict different code from the same requirement. The resulting code decides, not the rule. The reader knows Ernest first. Where Ernest's own rules do not decide, the reader knows types as Standard ML and OCaml have them, and values and processes as Erlang has them, and no other language; a form is not admitted because another language has it. Where Ernest departs from what that reader predicts, the report states the departure as a rule.
2. One way, one job, in the language and prelude. No variants for the same thing, no two concepts that overlap. The standard library may pair functions for convenience. A second spelling of what the language already writes enters only where the first would nest where the reader reads a sequence, repeat a body, or rebuild what a pattern already holds; one that only shortens stays out. A literal form enters where the reader of principle 1 predicts it.
3. Nothing invisible. Control flow, communication, and failure are visible in the code or in the type. A top-level binding is visible when its name appears at the use site. A rule the type decides is checked when the program is compiled; one the value decides is a value, a message, or a fault when it runs (§7). The compiler refuses what the text alone shows can have no effect, a value dropped, a clause that cannot run, and accepts what the text shows only unused; there is no warning. Where a check refuses a program that would run, the rule is stated and its error names what to write.
4. Simple to parse: recursive descent, first-token dispatch, small bounded lookahead where the grammar demands it, no backtracking.
5. Small: few concepts, few primitives, few reserved words. The count is the language's, its concepts, its primitives and its reserved words; the standard library is bounded by Appendix E.0's rules, and a function is there where a reader who knows the type looks for it. How many programs ask for a feature decides nothing, for it or against it. A feature costs a program that does not use it nothing: no argument, no word, and no name of it is written there.

**The host.** Ernest runs on a host runtime (§10). A rule of the host is a rule of Ernest only where this report states it as Ernest's own. A host rule whose outcome the program sees, a value or a fault, is taken and stated. One whose outcome would be silent, a truncation, a coerced value, a fault made false, is met by a check on the value or a refusal of the form, and the cost of the check falls on that form alone. An outcome that comes while the host starts, before the runtime runs, is the host's, and the report states it. Where the report is silent, the runtime carries the host's rule without letting it show.

## 1. Notation

The grammar is Wirth-style EBNF. `=` defines, juxtaposition concatenates, `|` separates alternatives, `[ ]` is optional, `{ }` is zero or more, `( )` groups, `.` ends a rule. Uppercase names are non-terminals, lowercase names lexical categories. Terminals are in double or single quotes. `ident`, `conname`, `typename`, `typevar`, `binop`, `userop`, and the literals are defined in §2. The complete grammar is Appendix A.

## 2. Lexical Elements

### 2.1 Characters

Source text is Unicode in UTF-8; a leading byte-order mark (U+FEFF) is stripped. Whitespace is space (U+0020), tab (U+0009), line feed (U+000A), and carriage return (U+000D); it separates tokens. A blank line has one meaning more: it decides what a doc block documents (§2.2). Any other control character, U+0000 to U+001F and U+007F to U+009F, is an error wherever it stands, in a comment and a doc block as elsewhere; a string or a character literal writes one as an escape.

### 2.2 Comments

`//` to end of line and `/* ... */`, which nests, are removed by the lexer and take part in no grammar rule. A block comment's text is not tokenized: the `*/` that closes its outermost `/*` ends it, inside quotes or not. A line ends at a line feed.

`///` to end of line, where the third `/` is not followed by a fourth, is a doc comment; `////` begins an ordinary comment. A `///` after a token on its line is an error: a doc comment stands on a line of its own, and a note after code is written `//`. Consecutive `///` lines form a doc block, whose text is CommonMark 0.31. A doc block immediately preceding a top-level declaration, a constructor, or a named field, with no blank line between, is its documentation, extractable by the toolchain, §11.4. The first doc block before the first declaration, with a blank line after it, is the module's documentation. A doc block anywhere else, above a `fn` in a block or second before the first declaration, documents nothing and is an error, as a `///` after code is.

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
float    = decimal ( "." decimal [ exponent ] | exponent ) .
exponent = ( "e" | "E" ) [ "+" | "-" ] decimal .
decimal  = digit { [ "_" ] digit } .
char     = "'" ( character | escape ) "'" .
string   = '"' { character | escape } '"' | "`" { rawchar } "`" .
escape   = '\' ( "'" | '"' | '\' | "n" | "r" | "t"
           | "u{" hexdigit [ hexdigit ] [ hexdigit ] [ hexdigit ] [ hexdigit ] [ hexdigit ] "}" ) .
bool     = "true" | "false" .
```

`1` is `Int`; `1.0`, `1.0e-9`, and `1e10` are `Float`. A float literal denotes the nearest `Float`, ties to even. A literal whose value rounds beyond the largest finite `Float` is an error, `1.0e400`; one that rounds to zero is `0.0`, `1.0e-400`. Literals carry no sign; `-` is a prefix operator. There are no overloaded literals and no default. `0x`, `0o`, and `0b` begin a hexadecimal, an octal, and a binary integer: `0x10FFFF`, `0o644`, `0b1010`. The prefix is lowercase. An `_` between two digits groups them and is ignored: `1_000_000`, `0xFFFF_FFFF`, `3.141_592`. An `_` anywhere else in a number is an error: `1_`, `1__0`, `0x_FF`. A letter or digit directly after a number is an error: `0b102`, `0x1g`, `12px`.

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

Prefix `-` is negation and prefix `!` is negation on `Bool` (§4.8). Both bind tighter than any binary operator, and neither applies twice without parentheses: `-(-x)`. Precedence of the binary operators, highest first:

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
TupleType = "#(" Type "," Type { "," Type } ")" .
FnType    = "(" [ Type { "," Type } ] ")" "->" Type [ "with" Type ] .
ParenType = "(" Type ")" .
```

`FnType` and `ParenType` both begin with `(`. The parenthesized list of types is read whole, and a `->` after its `)` makes it an `FnType`; otherwise it is a `ParenType`, which holds exactly one `Type`.

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

**Integer arithmetic.** Exact and unbounded. `/` truncates toward zero: `-7 / 3 = -2`. `%` satisfies `(a / b) * b + (a % b) == a`, so `-7 % 3 = -1`. `Int.div` and `Int.rem` (Appendix E.8) use the same convention and return `Optional(Int)` in place of the zero-divisor fault: `Int.rem(-7, 3)` is `Some(-1)`.

**Float arithmetic.** IEEE 754 binary64, round to nearest, ties to even, restricted to the finite range. An operation whose result is not finite faults with cause `Fault("float arithmetic error")`: overflow, division of a non-zero numerator by zero, or `0.0 / 0.0`. Gradual underflow to a subnormal is not a fault. There is no `Infinity`, no `NaN`, and no negative zero: a zero is `0.0`, whether an operation or a negation gives it, or it enters the program from foreign code, from bytes, or from text. A float segment pattern `0.0` matches the bytes of either zero. A float segment pattern does not match the bytes of an infinity or a NaN. `Float.compare`, `Float.round`, `Float.truncate`, `Float.floor`, and `Float.ceil` are total.

`Int` and `Float` do not convert implicitly, and mixing them in an arithmetic expression is a type error; `Int.toFloat`, `Float.round`, `Float.truncate`, `Float.floor`, and `Float.ceil` convert. `Int.toFloat` rounds to the nearest `Float`, ties to even, and faults with cause `Fault("Int out of Float range")` where that rounding gives no finite `Float`. An integer above the largest finite `Float` that rounds down to it does not fault.

### 3.2 Tuples

`#(A, B)` is the type of a tuple and `#(a, b)` its value; a tuple has two components or more, all written this way. The tuple is the only positional product type.

### 3.3 Lists

`List(a)` is an immutable linked list. `[]` is the empty list; `x :: xs` prepends `x` to `xs`, and `::` is right-associative, so `[a, b]` is `a :: b :: []`.

### 3.4 Function types

`(A, B) -> C` is the type of a function of two arguments. Arity is part of the type: `(A, B) -> C` and `(#(A, B)) -> C` are different types; the first takes two arguments, the second one tuple. `() -> C` takes no arguments.

`with M` after the result is the mailbox type: the function uses the process it runs in, whose mailbox has type `M`, §6.1. A function type without `with M` is pure.

`with` binds to the nearest arrow. `(A) -> (B) -> C with M` is a pure function returning a function with mailbox `M`. `(A) -> ((B) -> C) with M` is a function with mailbox `M` returning a pure one. In a result annotation, a `with` after a function type is that type's: `fn f() : (A) -> B with M` returns a function with mailbox `M`; `fn f() : ((A) -> B) with M` has mailbox `M` itself.

### 3.5 Sum types

Declared with `type`, §4.3. A constructor has no fields, exactly one positional field, or named fields:

```ernest
type Optional(a) = None | Some(a)

type Snapshot = Snapshot(dir : Path, seen : Map(Path, Int))
```

Field names are unique within a constructor. Their declaration order is the order in which a value's fields are stored, transported (§8.4), and shown (Appendix E.1), and is part of the type's identity (§8.7); a construction and a pattern may give them in any order, and field expressions are evaluated in source order (§5.1). There is no canonical order. Positional and named fields are told apart by `:` after the first identifier in a declaration and by `=` in construction and patterns.

A named field is *selected* with `e.f`: the field `f` of the value `e`, `snapshot.seen`. A type has the selector `f` when every one of its constructors has a named field `f`, and they have one type once the operand type's arguments stand for its parameters, which is the selector's; on any other type `e.f` is a type error. A positional field has no selector. Outside the module that declares an abstract type, its fields have no selectors, as its constructors are not visible there (§4.4). The type of `e` is found as an operator's operand type is (§4.8).

### 3.6 Abstract types

A sum type whose constructors may be mentioned only in the module that declares it, §4.4.

### 3.7 Built-in types

`Address(m)` is an address of a process that receives `m`. `Reply(a)` is a one-shot address for the answer to a request, §6.6. `Never` is the type with no values. It is an ordinary type and unifies with itself alone; a function that never returns and may stand at any type has a type variable as its result, as `fault` has (§9.6). The prelude types are listed in §9.

### 3.8 Foreign types

A type declared `foreign type T` has no constructors: its values are made and used only by foreign functions, §4.7, and can otherwise be held, passed, and sent. Its equality is §3.10's. A host value of no other Ernest type enters Ernest through a foreign type alone, each with the runtime's exact equality: `foreign type T` declared by a module, and the foreign type of any host value, `Foreign.Term` (Appendix E.12).

A foreign value is bound to the node (§8.3) that made it: transporting a value that transitively contains one to another node faults with cause `Fault("foreign value cannot cross nodes")`. Transport is `Peer.spawn(name, f)` and `Peer.spawnMonitored(name, f, wrap)`, `send` to a remote address, the request of a call to one, `answer(r, v)` to a caller on another node, and the captures of a function spawned on a peer. The fault is the transporting process's, at the operation that transports: the caller of `spawn` or `spawnMonitored`, the sender of `send`, the caller of a call, and the process that calls `answer`.

### 3.9 Type variables and polymorphism

Types are inferred according to Hindley-Milner. A `fn` definition, a top-level `let`, and a `let` in a block that binds a name to a lambda are generalized over their free type variables; another `let` in a block is not, nor is a top-level `let` whose initializer calls a process-only function (§4.6). Type variables in a `fn` signature scope over the whole definition, including the annotations of lambdas, of block `let`s, and of local `fn`s within it. A type variable in an annotation means every type and is rigid. One named first in a lambda's annotation or a block `let`'s belongs to that lambda or binding, and only a generalized one may name it: a lambda that is a `let`'s whole value, at top level or in a block. Elsewhere it is a type error: `List.map(xs, fn(x : a) = x)`. A local `fn`'s signature shares the enclosing signature's variables, and a variable named only in it is the local function's own, rigid and generalized with it as a top-level function's is. Recursive and mutually recursive types are allowed; polymorphic recursion is not, even where the whole signature is written: a recursive call is at the definition's own type. Every type variable in a constructor's fields is a parameter of the type.

**Effect polymorphism.** The mailbox effect of a function type may be a type variable, generalized with the others: `fn apply(f, x) = f(x)` has type `((a) -> b with e, a) -> b with e`. At a call site an effect variable binds to a mailbox type or to pure: `apply(fn(x) = send(a, x), 5)` binds `e` to the mailbox of `send`, `apply(fn(x) = x + 1, 5)` binds `e` to pure. Pure is the absence of `with`; it is not a type. A mailbox type bound this way becomes the caller's. A pure function stands wherever a function of the same type with a mailbox type is expected, and a function with a mailbox type never stands where a pure one is expected. So an expression whose type is a function type without `with` takes a fresh effect variable in its place, which the context binds: with `fn double(n : Int) : Int = n * 2` and `fn done(n : Int) : Unit = Unit`, `Upgrade(migrate = double, next = done)` binds it to `CounterMsg` (§6.10). Only the expression's own function type takes one. A function type inside it or inside another type, a parameter's, a result's, or a field's, keeps its effect until an expression has it as its own type, as a call or a selection does.

An effect position is the type after `with`. A value position is an argument, a result, a tuple component, or a type argument whose parameter occurs in a value position of its type's fields. A type argument of a built-in or foreign type is a value position. A variable that occurs only in effect positions ranges over the mailbox types and pure. A variable that also occurs in a value position ranges over types alone: `m` in `self : () -> Address(m) with m` is never pure. Inference asks for an annotation in five places: an operator whose operand type nothing in the definition fixes (§4.8), a field selection whose operand type nothing fixes (§3.5), a top-level binding that is not generalized whose type keeps a variable nothing resolves (§4.6), a `<-` whose sum type is still open (§5.5), and `Io.show` or `Io.debug` at a type not known whole (Appendix E.1).

The functions of §9.4 and §9.5 whose own effect is a mailbox type, and a `foreign fn` whose effect is its own, are *process-only*: their effect variable is treated as if it occurred in a value position, and pure code cannot call them. A `foreign fn`'s effect is its own unless its effect variable is also the effect of one of its parameters' function types, in which case the effect is that callback's and the function is effect-polymorphic: `foreign fn each(m : Map(k, v), f : (k, v) -> Unit with e) : Unit with e` is pure when `f` is.

A function has one mailbox effect or none. A function may take a pure callback beside an effectful one: in `fn callBoth(p : (Int) -> Int, e : (Int) -> Unit with n) : Unit with n`, `p` is pure, `e` has effect `n`, and the function inherits `n`. Two callbacks whose effects are both variables unify to one effect. Two callbacks with different concrete effects are a type error.

**Inferred restrictions.** An annotation gives a function's shape: arity, argument types, result, mailbox effect. Three restrictions are inferred from the body. Where there is no body, a restriction is given instead: written on a foreign type's parameter, `k=`, the one mark a program writes (§4.7); given to a foreign function by §4.7 and the paragraph above; and stated for the prelude's types and primitives in §9. Each prints with its mark (§11.5). The equality constraint of §3.10 falls on a variable compared with `==`. Process-only is inherited by a function whose body calls a process-only function: `fn wrap(a, v) = send(a, v)` cannot be called from pure code. So one annotation can give two behaviours: `fn h(a : Int) : Unit with e = Unit` can be called from pure code, and the same head over `Io.println("")` cannot. Not-reply-carrying (§6.6) falls on a type variable of a parameter's type when the body, read with that variable as a reply-carrying type, would break §6.6, and on a foreign function's as §4.7 says: use such a value twice or not at all, through a `let` or a pattern as much as by the parameter's name, or put it where §6.6 forbids one. So `fn dup(x) = #(x, x)`, `fn discard(x) = Unit`, `fn keep(x) = { let y = x; Unit }`, and, for `type Box(a) = Box(a)`, `fn forget(b : Box(a)) : Unit = Unit` cannot take a reply, and `fn id(x) = x` can. `Optional.withDefault : (Optional(a!), a!) -> a!` is restricted, `a!` being how a printed type marks the restriction (§11.5). Each is part of the type scheme and travels with the function value through bindings, branches, and compiled interfaces. Each is checked at instantiation, not at definition. The compiler shows them (§11.5).

### 3.10 Equality and ordering

`==` and `!=` are structural and defined for all values except those containing functions or addresses, on which they are a type error. On a value of a foreign type, `Foreign.Term` among them, or of `Process`, they are the runtime's exact equality on the two representations (§8.4): two references are equal only when they are one reference, and two values that foreign code made as the same term are equal. Ordering is per type, through `compare` in the type's namespace: `Int.compare : (Int, Int) -> Ordering`. For a type a module declares, that is its member `T.compare` (§4.2); a function named `compare` outside the type's namespace gives no ordering. For operand type `T`, `a < b` is `T.compare(a, b) == Less`; `<=`, `>`, and `>=` likewise. They resolve against the operand type as the operators of §4.8 do. A type without `compare` has no ordering, and `<` on it is a type error. The prelude defines `compare` for `Int`, `Float`, `String`, and `Char` (§9.6), and for no other type: `Bool`, `Optional`, and `Path` have no ordering.

A function that applies `==` to a value of a type variable gives that variable an *equality constraint*, inferred and never written; instantiating it with a type that contains a function or an address is a type error at that call site. A foreign type's parameter may carry the constraint (§4.7), and `Map(k=, v)` and `Set(a=)` carry it on `k` and `a` (§9.2). A value of such a type over a type without equality is rejected at its first operation; a type that names one, `Map((Int) -> Int, Int)` in an annotation or a field, is not itself an error. A standard library function that compares elements, `List.contains`, propagates the constraint through its parameter. `fn equal(a, b) = a == b` has type `(a, a) -> Bool` with the constraint on `a`. The constraint is part of the type scheme (§3.9). `let f = equal` carries it, and applying `f` to addresses is an error at that application. `if flag then equal else always`, with `always` unconstrained, carries the union of the branches' constraints. A compiled interface carries it across modules. The check is at the concrete application.

### 3.11 Serialization

A message may be a value of any type, a function included. A function is bound to its node, as a foreign value is (§3.8): transporting a value that transitively contains one to another node faults with cause `Fault("function cannot cross nodes")`, at the operation that transports, in the process that transports. Two kinds of function cross all the same. The function `Peer.spawn(name, f)` or `Peer.spawnMonitored(name, f, wrap)` starts crosses with its code, and so does every function its captured values hold, through data and through other functions' captures alike (§8.7). An adapted address crosses as a reference to its function and the values the function captured, and the function runs only on the node where the address was made (§6.5). A value that holds both a foreign value and a function faults with the foreign value's cause. So a message between nodes is values only, and it needs no code on the node it reaches.

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
Return      = ":" Type [ "with" Type ] .
LetDecl     = "let" ident [ ":" Type ] "=" Expr .
Binding     = "let" Pattern [ ":" Type ] ( "=" | "<-" ) Expr .
DeclName    = ident | typename "." ( userop | "compare" | "negate" ) .
```

### 4.1 Modules

A *module* is one source file, ending in `.ern`: the unit of compilation and of namespace. Every top-level declaration belongs to exactly one module. The modules' dependencies are acyclic; a cycle is a compile-time error.

### 4.2 Namespaces and visibility

**Files are namespaces.** A file at `a/b/c.ern` under the source root provides the namespace `A.B.C`. A path segment is one or more words joined by `_` (§11.1), and the namespace segment is each word with its first letter uppercased and the `_` dropped: `http.ern` is `Http`, `httpv2.ern` is `Httpv2`, `ordered_set.ern` is `OrderedSet`, and `net/http_client.ern` is `Net.HttpClient`. A word begins with a letter, so the mapping is one-to-one: a namespace segment's words begin at its uppercase letters, and `OrderedSet` is the file `ordered_set.ern`. The top of the hierarchy, where the prelude lives, is provided by the runtime, not by user code.

**Declarations are local; `export` marks the boundary.** A declaration is written with its local name. `fn parse` in `net/http.ern` is exported as `Net.Http.parse` when marked `export`; otherwise it is private to its module. A use site may write a declaration's qualified name: within its own module for any declaration, and elsewhere for an exported one. A declaration never writes its own name qualified. Two exported declarations with the same qualified name are an error. The type of an exported declaration, and the field types of an exported type that is not abstract, may not name a type the module keeps private. A function's mailbox type is exempt: an exported entry point may receive a private message type. A type whose values cross the boundary but whose constructors do not is an `abstract type` (§4.4). There is no export list and no `import`.

**Taken namespaces.** A module namespace may not coincide with a namespace of the prelude or the standard library. The prelude's namespaces are `Prelude` and the name of every type that has a member in §9, as `Int` and `Address` do: `address.ern` at the source root is an error, and so is `io.ern`, a namespace of the standard library. A prelude type without members takes no namespace: `down.ern` at the source root provides the namespace `Down`, and the type `Down` is still the prelude's. The standard library's own source root, shipped with the toolchain, is the exception: its files provide those namespaces. A file under it is compiled with it as the source root (§11.1); another source root is an error.

```ernest-fragment
// net/http.ern
export type Request = Request(method : String, path : String)

export fn parse(s : String) : Optional(Request) =
    ...

// private to net/http.ern
fn helper(x) =
    ...
```

**Type members.** A type `T` declared in a module, concrete or abstract, is a nested namespace. Its members are its operators, its `compare` and its `negate` (§4.5), declared with the single prefix `T.`, as in §4.8's `fn Distance.+`, and exported at `Module.T.member`. The module of a prelude type is the exception §4.8 states: `export fn Float.+` in `float.ern` declares `Float.+`, and its `compare` and `negate` are declared unprefixed. The namespace belongs to the file that declares the type. A module namespace may not coincide with it: `main/stack.ern` is an error when `main.ern` declares `Stack`. In `main.ern`, `Main.Stack.compare` is therefore its own member where it declares `Stack`, and the module `Main.Stack`'s `compare` where it does not. The coincidence is exact: `main.ern` may declare `STACK` beside `main/stack.ern`, and a module may declare two types whose names differ only in case.

**Unqualified lookup.** An unqualified name in a body is looked up first among the names bound around it, the innermost first: parameters, `let` bindings, pattern and `receive` variables, and local `fn`s. It is then looked up in the module's declarations, exported or not, then in the prelude. A name not found there is written qualified; a type's member is written `T.name`, within the type's own members too. A module may declare a type or constructor with a prelude name, and the name then means the local one throughout the module. A dotted name's first segment is a type the module declares where that type has a member of the name, and otherwise the namespace of that name: in a module that declares `type List` with a member `List.<>`, `List.<>` is that member, and `List.map` the standard library's. `Prelude` names the prelude's own namespace, so `Prelude.Some` is the prelude's `Some` in a module that declares its own. It is written only where a declaration or a binding of the module hides the name it reaches: `Prelude.Some` in a module that declares no `Some` is an error. It takes one name the prelude declares, or a namespace of the prelude or the standard library and one of its names: `Prelude.List.<>` is the prelude's `List.<>` past a member `List.<>` of the module's own. A module of the program's own is reached by its namespace alone, so a member of the module's own type hides that module's name of the same path. No module and no type is named `Prelude`. Within a module, type names are unique and constructor names are unique across its types.

### 4.3 Type declarations

`type` declares a sum type with its constructors. A constructor has the visibility of its type.

### 4.4 Abstract types

`abstract type T = ...` declares a type whose constructors may appear only in the module that declares it. Every definition of that module may use them, a private one or a test included; another module sees the type and not its constructors. An abstract type is exported: one the module keeps private is an error.

```ernest
// stack.ern  (namespace Stack)
export abstract type Stack(a) = Stack(List(a))

export let empty = Stack([])

export fn push(Stack(xs), x) =
    Stack(x :: xs)

export fn pop(Stack(xs)) =
    match xs {
        [] -> None
      | x :: rest -> Some(#(x, Stack(rest)))
    }

export fn size(Stack(xs)) =
    List.size(xs)
```

External callers see `Stack.Stack`, `Stack.empty`, `Stack.push`, `Stack.pop`, and `Stack.size`; `Stack.Stack(...)` is refused outside `stack.ern`. A module may declare several abstract types. Outside its module, `Io.show` writes a value of an abstract type as `<abstract>` (Appendix E.1).

### 4.5 Functions

`fn` declares a function of fixed arity. Annotations may be omitted where they can be inferred. The result annotation is omitted, or is `: T` for a pure function, or `: T with M` for process code, as a parameter's annotation is `: T`. A pure annotation on a function that calls process code is a type error. A pure annotation makes pure the effect of every parameter the body calls: `fn apply(f, x) : Int = f(x)` has type `((a) -> Int, a) -> Int`.

A function has one clause. Patterns in parameters are irrefutable, §5.10: `fn seenCount(Snapshot(seen = entries) : Snapshot) : Int = Map.size(entries)`.

`fn` may appear at top level and as a statement in a block; it sees its own name, and `fn` declarations in the same block or at top level may refer to each other. A type-member name, `fn T.f`, is a top-level form; in a block it is an error. A type's operations are functions of its module. A member, `fn T.f`, is declared only for what the language resolves by the operand's type: an operator of §2.6, `compare` (§3.10), and `negate` (§5.1); a `let` declares no member. A module reaches its abstract type's constructors by being its module (§4.4).

### 4.6 Bindings

In a block, `let p = e` binds the irrefutable pattern `p` to the value of `e`; `let p <- e` is described in §5.5. A binding's initializer may not depend on its own name, which is a cycle (§8.5), so a function that calls itself is declared with `fn` (§4.5). It is monomorphic, except one that binds a name to a lambda, `let id = fn(x) = x`, which is generalized as a local `fn` is (§3.9). A later binding of the same name shadows the earlier one from the next statement on; the right-hand side of the later binding sees the earlier one.

A block binding's type may hold unresolved type variables; `[]`, `None`, `Map.empty`, and a call that returns a polymorphic value introduce them. A later use of the binding in the block pins such a variable: `let m = Map.empty; Map.put(m, "a", 1)` pins `m` at `Map(String, Int)`. One that reaches the block's result is generalized by the enclosing `fn` or top-level `let`: `fn namedEmpty() = { let xs = []; xs }` has type `() -> List(a)`. An annotation on the binding fixes it. A use pins a variable only where it fixes the variable's type, and a variable that nothing pins stays free: in `{ let xs = []; List.size(xs) }` the element type stays open.

At top level, `let` binds an `ident`. The left side is a name, not a pattern; `<-` is a block form only. The initializer is a body of mailbox type `Never` (§6.8): it may spawn, send, and call, and it may not receive. The binding generalizes its free type variables: `let empty : Stack(a) = Stack([])`. A binding whose initializer calls a process-only function (§3.9) is not generalized, and a type variable left in its type is a type error at the binding. The runtime evaluates top-level bindings in dependency order, in the entry process, before `main` runs (§8.5).

### 4.7 Foreign declarations

`foreign type T` declares a type implemented outside the language. A parameter written with `=`, `k=` in `foreign type Table(k=, v)`, puts the equality constraint of §3.10 on its argument at every operation of the type, and the type written with an argument that lacks it is not itself an error (§3.10).

`foreign fn f(params) : T = "impl"` declares a function whose body is the implementation named by the string, in the runtime's language; parameters and the result are annotated. A foreign function has no body from which §3.9 infers restrictions, and its code may copy a value it is given or drop it, so each type variable whose values a parameter holds is not reply-carrying (§6.6): one the parameter's type reaches through tuples and type arguments, and not under `Address`, `Reply`, or a function type. `Foreign.from(r)` on a reply is a type error. A foreign function with a mailbox type may do anything. One without a mailbox type promises purity: the same result for the same arguments, and no effect on anything. The implementation promises the declared types: a value of another shape, or an exception, is a fault, §7. Foreign code sees values in the runtime's representation, §8.4. Both declarations take `export` (§4.2).

### 4.8 Operators

The arithmetic operators `+`, `-`, `*`, `/`, `%` and `<>` resolve against the operand type, by *operator resolution*. In `a + b`, `+` is `Int.+` when `a : Int` and `Distance.+` when `a : Distance`, for `type Distance = Distance(Int)`. A user type declares its operators in its own module: `export fn Distance.+(Distance(a), Distance(b)) : Distance = Distance(a + b)`. The standard library module of a prelude type (§9) declares that type's operators the same way, with the type's name as the prefix: `fn Float.+` in `float.ern` declares `Float.+` (§9.6). In that module the prefix is allowed on an operator only; its other functions are declared unprefixed, `fn abs`. Both operands have one type, which either may determine, and there is no numeric type to generalize over: `fn f(a, b : Int) = a + b` uses `Int.+`. The operand type is determined when its type constructor is known: `xs <> []` is `List.<>`. An operator's result does not determine its operands. An operator is resolved once its definition is inferred, and before the definition is generalized. Its definition is the enclosing `fn` declaration, top-level or local, the enclosing top-level `let`, or a block `let` that binds a lambda, since each is generalized (§3.9, §4.6); any other lambda belongs to the definition it stands in. So `fn add(a, b) = a + b` in a block is a type error, whatever calls it later, and `fn add(a : Int, b : Int) = a + b` is not. An operand type still undetermined then is a type error. A field selection (§3.5) is resolved in the same way, against its operand's type. A member named by an operator has the type `(T, T) -> R` for its type `T`, `T.compare` the type `(T, T) -> Ordering`, and `T.negate` the type `(T) -> R`; each is pure. For a type with parameters, `T` is the type applied to any arguments, the same in each place: `Vec.+` of a type `Vec(a)` has the type `(Vec(a), Vec(a)) -> R`. A member of another shape is an error at its declaration. An operator on a type that declares no member for it, `%` on `Float` or `<>` on `Int`, is a type error.

`!` is negation on `Bool`, the prefix operator beside the logical operators `&&` and `||`, and `Bool.not` (E.7) is the same operation as a function, as `Int.negate` is of prefix `-`. `==`, `!=`, `<`, `<=`, `>`, `>=`, `&&`, and `||` cannot be defined per type: equality is structural and ordering goes through `compare` (§3.10); `&&` and `||` short-circuit on `Bool`. `::` is cons (§3.3); `|>` is a syntactic form (§5.7). The operators are the closed set of §2.6, and every other operation is a function. An operator the language resolves against its operand's type is resolved where that type is known, is a type error on a type variable, and carries no hidden argument; `==` compares structurally, or exactly on a foreign type and `Process` (§3.10), and needs none.

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
Tuple     = "#(" Expr "," Expr { "," Expr } ")" .
ListLit   = "[" [ Expr { "," Expr } ] "]" .
BitExpr   = "<<" [ BitSegE { "," BitSegE } ] ">>" .
BitSegE   = Expr [ ":" BitSpec { "-" BitSpec } ] .
Block     = "{" Stmt { ";" Stmt } "}" .
Stmt      = FnDecl | Binding | Expr .
Pattern   = ConsPat [ "as" ident ] .
ConsPat   = AtomPat [ "::" ConsPat ] .
AtomPat   = "_" | ident | literal | "-" ( int | float )
          | { typename "." } conname [ "(" ( Pattern | FieldPats ) ")" ]
          | "#(" Pattern "," Pattern { "," Pattern } ")"
          | "[" [ Pattern { "," Pattern } ] "]"
          | BitPat .
BitPat    = "<<" [ BitSegP { "," BitSegP } ] ">>" .
BitSegP   = Pattern [ ":" BitSpec { "-" BitSpec } ] .
BitSpec   = "size" "(" Expr ")"
          | "bytes" | "int" | "float"
          | "utf8" | "utf16" | "utf32"
          | "big" | "little"
          | "signed" | "unsigned" .
FieldPats = [ ident "=" Pattern { "," ident "=" Pattern } ] .
```

`fn` and `if` are not operands: `1 + if c then a else b` is a syntax error; write `1 + (if c then a else b)`. A `match` and a `receive` are (§5.9).

### 5.1 Evaluation

Strict, left to right, arguments before the call. A callee is evaluated before its arguments. In `x |> e`, `x` is evaluated before `e`: `x |> f(a)(b)` evaluates `x`, then `f(a)`, then `b`. A selection evaluates its operand, then reads the field. Nothing is delayed; `fn() = e` defers `e`. Prefix `-` is `negate` in the operand type's namespace: `Int.negate`, `Float.negate`, or `T.negate` for a user type `T`. A user type declares `T.negate` the way §4.8 declares `T.+`.

### 5.2 Calls

`f(x, y)` supplies all arguments. A call with the wrong number of arguments is a type error at the call; a call never yields a partially applied function. An expression whose value is a function can be called directly, `makeAdder(3)(4)`.

### 5.3 Lambda

`fn(x) = e` is an anonymous function. Its body is the longest `Expr` at the same nesting level, ending at the first delimiter of the enclosing form: `,`, `;`, `:`, `|`, `->`, `)`, `{`, `}`, `]`, `>>`, `then`, or `else`. A `{` that begins the body opens a block (§5.4), which is the body.

### 5.4 Blocks

`{ s1; s2; e }` is an expression whose value is its last statement, which is an expression: a block that ends in a `let` or a `fn` is refused. `;` separates statements and never appears last. A statement is a `fn` declaration, a `let` binding, or an expression evaluated for its effect. An expression that is not the last statement has type `Unit`; a value is discarded with `let _ = e` (§5.10).

A `fn` declared in a block is visible throughout it, so local functions may be recursive and mutually recursive. Two `fn` declarations of one name in one block are an error. A local `fn` may not take the name of a parameter or a variable in scope where it is declared, nor of a `let` of its block. The body of a local `fn` sees the bindings in force at its declaration. `let` bindings are sequential. A `fn` body that references a `let` declared later in the block is a compile-time error. A local `fn` may be used only after every `let` it references has been evaluated; a `let` referenced through another local function counts. A use is a call, or taking the function as a value, passing, storing, returning, or capturing it. An earlier use is a compile-time error.

### 5.5 Binding with `<-`

In a block, `let p <- e; rest` matches `e`: on `Right(v)`, `p` is bound to `v` and `rest` is evaluated; on `Left(err)`, the block's value is `Left(err)`. `p` is irrefutable (§5.10). With `Optional`, `Some` and `None` apply the same way.

In `let p : T <- e`, `T` is the type of `p`, the value inside. The sum type is decided after inference of the enclosing definition: from the type of `e`, or, if that is still open, from the block's type. Where both are open it is a type error, which asks for an annotation that fixes either, a parameter's type or the function's result type. `rest` has the block's type. All `<-` bindings in one block resolve to the same sum type.

### 5.6 Construction

`Some(e)`, `None`, `Snapshot(dir = d, seen = s)`. All fields are given, each once. `Snapshot(..p, seen = s)`, a *record update*, takes the unlisted fields from `p`; at least one field follows `..`. `..` is allowed only on a type with one constructor; on any other it is a type error. A constructor is qualified like a function, `Net.Http.Request(...)`.

A nullary constructor is a value. A single-positional constructor is a function value. A named constructor is neither; it appears only in construction syntax. A qualified operator is a function value, `Int.+`.

### 5.7 Pipe

`x |> e` applies `e`, a function value or a call, with `x` inserted as the first argument: `x |> f` is `f(x)`, `x |> f(a, b)` is `f(x, a, b)`.

```ernest-fragment
let words = input |> String.trim |> String.toLower |> String.toList
```

`|>` is left-associative and binds loosest, below `||`: `a + b |> f` is `f(a + b)`, `a |> b |> c` is `c(b(a))`. The right-hand side is an operand (Appendix A). A call is filled: the pipe fills its first-argument slot. Any other operand, a name, a qualified name, a field selection `s.f`, a block, a `match`, or a `receive`, is a value applied to `x`, and one whose value is not a function, or is a function of no parameter, is a type error: `x |> [f]`. Parentheses change nothing: `x |> (f(a))` is `f(x, a)`, and `x |> (f)` is `f(x)`. A construction is such a value and no call (Appendix A), so the pipe does not fill it: `x |> Some` is `Some(x)`, and `x |> Some(2)` and `x |> W(b = 2)` are type errors. A lambda is no operand and must be parenthesized, `x |> (fn(y) = y + 1)`. In a chained call the pipe fills the outermost call: `x |> f(a)(b)` is `f(a)(x, b)`. A function a call computes is applied in writing, `f(a)(x)`. The type of `x` is the target's first parameter type.

### 5.8 Conditional

`if c then a else b` with `c : Bool`; the branches have the same type.

### 5.9 `match`

A `match`, like a `receive` (§6.3) and a block, ends at its own `}` and may stand as an operand: `n > 0 && match x { ... }`. `if` and a lambda end in no delimiter of their own, and stand as an operand only in parentheses. The value is matched against the clauses' patterns in order; the first clause whose pattern matches and whose guard holds is evaluated. A clause may list several patterns separated by `or`, an *or-pattern*, and matches when any of them does: for `type Player = Player(alive : Bool, body : List(Int))`, `Player(alive = false) or Player(body = []) -> 0` matches a player that is not alive or has no body. Every alternative binds the same variables at the same types; the guard and the body see them. Alternatives that bind different variables are a type error. The clauses together must cover the type, and a `match` that does not is a type error; guards do not count toward coverage. `true` and `false` together cover `Bool`. A clause, or an alternative of one, is *redundant* when it can match no value the clauses and alternatives before it leave unmatched, and a redundant clause is a type error: `n -> n | 0 -> 1`. For redundancy, a bitstring pattern in an earlier clause is taken to match no value, and one in the clause being judged to match any value. A guard is a `Bool` expression with no mailbox effect that sees the pattern's variables and the enclosing scope. A guard that is `false` falls through to the next clause; a guard that faults faults the process. A `receive` guard falls through likewise, and is restricted further (§6.3).

### 5.10 Patterns

A pattern decomposes a value and binds its parts; the same patterns appear in `let`, in `match` and `receive` clauses, and in parameters.

`_` matches anything and binds nothing. An identifier binds the whole value at its position to a new variable, shadowing any outer one; it never refers to an existing variable. A literal matches itself, and a numeric literal may carry `-`: `match n { -1 -> "minus one" | _ -> "other" }`. A constructor pattern, `Some(p)` or `Snapshot(seen = s)`, matches that constructor and decomposes its fields; field patterns may omit fields. A nullary constructor is written bare: `None`. A single-positional constructor takes one pattern: `Some(p)`. A constructor with named fields takes its field patterns in parentheses, and may omit them all: `Circle()` matches any `Circle`. Any other form is a type error: `None()`, `Some`, `Some()`, and a bare `Circle`. A tuple `#(p, q)`, a list `[p, q]`, and `p :: q` decompose a tuple, a list, and a cons. Patterns nest to any depth. `p as c` binds `c` to the whole value that `p` matches. `as` binds looser than `::`: `x :: rest as all` names the whole list. `or` stands between a clause's whole patterns (§5.9), and `as` names what one of them matches, so each alternative names the value itself: `Some(1) as x or Some(2) as x`.

Each variable appears at most once in a pattern; equality is written in a guard. A pattern is *irrefutable* if it cannot fail: `_`, an identifier, a tuple of irrefutable patterns, a constructor pattern of a type with one constructor whose sub-patterns are irrefutable, or an irrefutable pattern with `as`. `let` and parameters require irrefutable patterns; `let Right(x) = e` is a type error.

### 5.11 Bitstrings

`<<...>>` constructs and matches a `Bytes` value at the bit level. It holds segments between `<<` and `>>`, separated by commas. A segment is a value, in construction, or a pattern, in a match, followed by an optional colon and a dash-separated list of specifiers.

| Specifier                   | Meaning                                                     |
|-----------------------------|-------------------------------------------------------------|
| `size(N)`                   | segment width, in bits, or in octets for `bytes`            |
| `bytes`                     | segment is a nested byte-aligned `Bytes` value              |
| `int`, `float`              | numeric segment (defaults: 8-bit, 64-bit)                   |
| `utf8`, `utf16`, `utf32`    | text encoding                                               |
| `big`, `little`             | endianness                                                  |
| `signed`, `unsigned`        | sign                                                        |

A segment without specifiers is `int` of size 8. A segment is `big` and `unsigned` unless it is marked otherwise. An `unsigned` segment of n bits holds 0 to 2^n − 1, and a `signed` one −2^(n−1) to 2^(n−1) − 1: `<<-1>>` is a compile-time error, and `<<n>>` with `n` −1 faults. `<<-1:signed>>` is the byte `0xFF`: the pattern `<<x>>` matches it with `x` bound to 255, and `<<x:signed>>` with `x` bound to −1. `signed` and `unsigned` apply to `int` segments, and `big` and `little` to `int`, `float`, `utf16`, and `utf32` segments; any other combination is a type error. `int` binds to `Int`, `float` to `Float`, the `utf` forms to `Char`, `bytes` to `Bytes`. A segment names at most one type (`int`, `float`, `bytes`, a `utf` form), one endianness, one sign, and one `size`: two of one kind, or one written twice, is a type error, `x:big-little`. A segment's size counts bits, and octets for a `bytes` segment: `x:size(16)` is 16 bits, and `b:size(2)-bytes` is two octets. A `float` segment is 16, 32, or 64 bits. A `utf` segment has no size. In a pattern, a `bytes` segment without a size takes the rest of the value and is the last segment. In a construction, a `bytes` segment without a size is its whole value, wherever it stands. The specifier names are specifiers only where a `BitSpec` stands, after a segment's `:` or `-`. Elsewhere, in a bitstring as outside one, they are ordinary identifiers: in `<<size:size(int)>>`, the first `size` and `int` are variables.

A bitstring's total bit count, in construction and in a pattern, is a multiple of 8. A violation of these rules the compiler can see is a compile-time error; one that depends on a dynamic size faults at construction (§7.4) or fails to match. So is a value that does not fit its width: a numeric literal, negated or not, that does not fit a segment of constant width is a compile-time error, in a construction and in a pattern, and any other value that does not fit faults at construction or fails to match. A segment pattern is a variable, `_`, or a literal of the segment's type, a negative numeric literal among them: `<<-1:signed>>`. `size(Expr)` in a pattern is a variable, a top-level `let`, an `Int` literal, or `+`, `-`, or `*` applied to these. The variable is bound by an earlier segment of the same bitstring, or is in scope where the pattern stands: a parameter, a block `let`, a pattern variable of an enclosing clause, or a lambda's capture. A top-level `let` is read when the `match` begins, after its scrutinee, or when the `receive` begins. A variable bound elsewhere in the same pattern is not in scope in its sizes. Any other segment pattern or size expression is a type error. A negative or out-of-range size fails the match. Construction evaluates the segments left to right. A `bytes` value fits a sized segment only when it is exactly that long. A negative size fits no value. A `float` value is rounded to a 16- or 32-bit width to nearest, ties to even, and a value too small for the width becomes `0.0`; one whose magnitude exceeds the width's largest finite value does not fit. `<<>>` is the empty `Bytes`.

```ernest
fn frame(len : Int, body : Bytes) : Bytes =
    <<len:size(16)-big, body:bytes>>

fn parseFrame(bytes : Bytes) : Optional(#(Int, Bytes, Bytes)) =
    match bytes {
        <<len:size(16)-big, body:size(len)-bytes, rest:bytes>> -> Some(#(len, body, rest))
      | _ -> None
    }
```

For coverage (§5.9) a bitstring pattern, at any depth, counts as matching no value. A position that holds one is covered only by a `_` or a variable at that position in another clause: `Some(<<x>>) | Some(_) | None`.

## 6. Processes

A process is an execution of a function with a mailbox type. It has a mailbox that receives values of that type, in arrival order per sender.

### 6.1 The mailbox type

`(A) -> B with M` is the type of a function that acts through the process it runs in, whose mailbox has type `M`: it uses that process's `send`, `receive`, or `self`, or calls a function whose type has one, a prelude function of §9.4 or §9.5, `spawn` and `kill` among them, or a foreign function with a mailbox type. Every function runs in a process; that is not marked.

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
spawn          : (() -> Unit with n) -> Address(n) with m
spawnMonitored : (() -> Unit with n, (Down) -> m) -> Address(n) with m
```

`self()` is the process's own address. `send(a, v)` places `v` in the mailbox of `a` and returns at once; sending to a dead process has no effect. A `send` promises the sender nothing. The one silence in the language is an act on what has ended that asks nothing back, which does nothing and says nothing: a message whose receiver has ended or restarts (§6.9), whose request has timed out or been answered, or whose peer is lost is dropped, and a `kill` (§6.9), a close or a `give` of a resource that has ended (Appendix E.18, E.23) does nothing. A program's end keeps no promise (§8.6). Every other failure is a value, a message, or a fault (§7).

`spawn(f)` starts a process on the running node that runs `f()` and returns its address. `self()` inside `f` is the new process's address; a parent that wants replies binds `let me = self();` before `spawn`. The effect `n` of `f` appears in `Address(n)` and so is a mailbox type (§3.9). A pure `f` fits, as a pure function fits wherever one with a mailbox type is expected, and `n` is then what the context makes it. A process that never receives is spawned with `fn() : Unit with Never = ...`. A node is one running runtime; a peer is another node it knows by name, §8.3. `Peer.spawn(name, f)` and `Peer.spawnMonitored(name, f, wrap)` start the process on the peer named (§8.3). An unknown or unreachable peer is a fault. The captures of `f` are copied to the peer.

`spawnMonitored(f, wrap)` starts the process as `spawn(f)` does, and the caller monitors it from its start (§6.9): `wrap(d)` is placed in the caller's mailbox when it ends, with its reason, however soon that is.

### 6.3 `receive`

`receive { clauses }` matches the mailbox in arrival order. The first message that matches a clause's pattern and guard is removed and the clause is evaluated; the rest remain. If none matches, the process waits. Patterns are typed against the mailbox type. Coverage is not required: a message no clause matches stays in the mailbox. A redundant clause is a type error, as in a `match` (§5.9).

A guard selects a message without removing it, so a `receive` guard is a *guard expression*. Its operands are the variables in scope, the pattern's and a lambda's captures among them, literals, negative numeric literals, and nullary constructors. A top-level `let` is an operand too, read when the `receive` begins. A guard expression is `true`, `false`, an operand of type `Bool`, a comparison of two operands with `==`, `!=`, `<`, `<=`, `>`, or `>=`, `!` before a guard expression, or two guard expressions joined by `&&` or `||`. `<`, `<=`, `>`, and `>=` compare the types whose `compare` §9.6 provides, in its order (§3.10). A guard expression calls nothing and cannot fault.

A final clause `after t -> e` gives a time limit of `t` milliseconds; `t` is evaluated on entry, and a time below 0 is 0. A time has no upper bound. When the limit passes without a matching message, `e` is evaluated. `after 0` does not wait for a message. Without `after` there is no limit.

### 6.4 Message ordering

Messages from one process to another are received in sending order. Between different senders there is no ordering.

### 6.5 Addresses

`Address(m)` identifies a process on a node and carries its protocol: `send(a, v)` is type-checked against `m` on any node. `via(addr, f)`, §9.5, is `addr` seen through `f : (a) -> b`: sending `v` to `via(addr, f)` sends `f(v)` to `addr`. `f` is applied on the node where `via(addr, f)` was made: by the `send`, in the sender, when the sender is on that node, and on delivery there when it is not. A `send` that applies `f` returns once `f` has, and a sender's messages keep their order through it (§6.4). An adapted address crosses to another node as a reference to `f` and the values `f` captured, which must be able to cross themselves (§3.11), and a `send` to it from another node carries `v` back to the node where it was made, where `f` is applied. An adapted address crosses only when `addr` names a process on the node where it was made. Otherwise transporting it faults as transporting a function does, with `Fault("function cannot cross nodes")` (§3.11). `via(self(), Wrap)`, with `Wrap : (Int) -> Msg` and the mailbox type `Msg`, is an `Address(Int)`; a value sent to it arrives as `Wrap(v)`. A fault in `f` is the target's: the process `addr` names dies of it, and the sender goes on.

Addresses have no equality (§3.10). The process behind an address is `Process.fromAddress(a)`, a value with equality that nothing can be sent to (Appendix E.21). There is no registry. A process reaches another through an address it holds or received, or through a top-level binding that holds one, which is a *service*:

```ernest-fragment
export let log : Address(LogMsg) =
    spawn(restarting(RestartLimit(restarts = 3, within = 5000), logger))
```

`restarting` keeps the service's address across its faults (§6.9). The address is the permission to send, and a service binding grants it to the modules that see the binding (§4.2).

### 6.6 Request-reply

A request carries a `Reply(a)`, a one-shot address for its answer.

```
Address.call        : (Address(m), (Reply(a)) -> m, Int) -> Optional(a) with n
Address.callForever : (Address(m), (Reply(a)) -> m) -> a with n
answer              : (Reply(a), a) -> Unit with m
```

`Address.call(addr, mk, ms)` allocates a fresh `r : Reply(a)`, sends `mk(r)` to `addr`, and returns `Some(v)` when the recipient answers or `None` after `ms` milliseconds, a time below 0 being 0. The clock starts at the call. A reply that arrives together with the timeout may be delivered or discarded. `Address.callForever(addr, mk)` waits without limit and returns `a`. When the process `addr` names has ended, or ends or restarts before it answers, the call ends at once. `Address.call` then returns `None`. `Address.callForever` faults the caller: with the callee's cause where the callee faulted, restarted after its fault or not, with `Fault("callee was killed")` where it was killed, with `Fault("callee returned without answering")` where its function returned, with `Fault("callee was closed")` where the program closes it, a socket or a listener (Appendix E.18), with `Fault("callee was restarted")` where it restarted because a restart was asked of it (§6.9), and with `Fault("callee had ended")` where it had ended before the call. Where the program ends, the caller ends with it. A request handed on to another process is watched only at the process it was sent to. `answer(r, v)` sends `v` to the caller. A reply travels by an identifier private to the call, never through the caller's mailbox. A late answer, after a timeout or the caller's death, is discarded silently, as is a second answer to a `Reply` already answered, which only foreign code can give (§4.7). The recipient cannot observe whether the caller still waits.

**The rule.** A `Reply`, and every value that contains one, is *consumed* exactly once on every path from where it is bound. `answer(r, v)` consumes a `Reply` by answering it. Every other consumption hands the obligation on:

- Passing the value to a function whose parameter is reply-carrying at that instantiation hands it to the callee. A callee that duplicates or discards the parameter rejects the call (§3.9).
- `send` hands it to the `receive` clause that binds the value.
- Placing it in a constructor field or tuple component of reply-carrying type, or in a list by `::` or a list literal, hands it to the built value.
- Returning it from a function whose result type is reply-carrying hands it to the caller.
- Capturing it in a lambda hands it to the lambda, which then carries the obligation by its capture (below). The lambda may be bound by a `let`. It, or the name bound to it, is consumed exactly once, by a call or as the function argument of `spawn` or `spawnMonitored`, and any other use of it is a type error. `let f = fn() = worker(r); spawn(f)` is legal; with `f()` after the `spawn`, `f` is consumed twice. A local `fn` may not capture a reply-carrying value; such a capture is a type error.

A value is bound by a parameter, a `let`, a pattern variable, a `receive` variable, a lambda's capture, or the result of a call, and each binding is an *obligation*. The check is per function and crosses no call boundary. It is static: every path makes the consumption, and whether execution reaches it is not checked. A call to a function whose result type is a variable no parameter's type names consumes every obligation open on its path, since the call does not return; `fault` (§7.4) is one. The `mk` callback of `Address.call` is checked by the rule: `r` is consumed by placement in the message `mk` returns, and `Address.call` discharges the message.

```ernest-rejected
type Request = Get(reply : Reply(Int)) | Stop

fn serve(request : Request) : Unit with m =
    match request {
        Get(reply = r) -> answer(r, 42) // accepted: r is answered on its one path
      | Stop -> Unit // Stop carries no reply
    }

fn twice(dst : Address(Request), request : Request) : Unit with m = {
    send(dst, request);
    send(dst, request) // rejected: request is consumed twice
}
```

**Which values contain a reply.** A type is *reply-carrying* if it is `Reply(a)` or has a constructor field, tuple component, or list element of a reply-carrying type. The property is transitive: `Request` above is reply-carrying, and so is `type Envelope = Env(msg : Request)`. It is by type, not by constructor: every value of `Request` is reply-carrying, `Stop` included. A declared type is reply-carrying at an instantiation whose fields, its arguments substituted, have a reply-carrying type: `Box(Reply(Int))` is, for `type Box(a) = Box(a)`, and `H(Request)` is not, for `type H(e) = H(f : (Int) -> Unit with e)`. A type whose operations are the runtime's, and `Address`, is never reply-carrying through its arguments: `Address(Request)` is not; `List` is, through its elements. A function type is never reply-carrying. A lambda that captures a reply-carrying value carries the obligation by its capture, not by its type, and so does the name a `let` binds it to; that name is consumed as the lambda is, and `let h = g` is a type error.

**Where such a value may stand.** A reply-carrying value stands only as a constructor field, a tuple component, a list element, a function parameter, a variable bound by `let`, by a pattern, or in a `receive` clause, a capture of a lambda, the scrutinee of a `match`, the right side of `<-`, the value of a branch or of a block, or the result of a function whose result type, declared or inferred, is reply-carrying. Anywhere else it is a type error, as an operand of `==` or `!=` among them. §6.6 names no type: a reply stands wherever the rule shows it consumed exactly once, in a list as in a constructor, and a function of a container takes a reply where §3.9's restriction lets it. A type whose operations are the runtime's takes none, since a foreign function's variables carry the restriction (§4.7). `Optional` and `Either` are sum types like any other: `Some(r)` carries a reply. A reply-carrying value as a statement, `Get(reply = r); Unit`, is refused as any statement that is not `Unit` is (§5.4).

**Patterns and branches.** A match consumes its scrutinee, and the obligation passes to the variables the pattern binds. A pattern on a reply-carrying value binds every reply-carrying field and element, so `_` or an omitted field there is a type error: `match request { Get() -> ... }` is rejected. `as` on a reply-carrying scrutinee is a type error. A constructor with no reply-carrying field, `Stop` above, and the pattern `[]` discharge the obligation. An `if`, `match`, `receive`, or block whose value is reply-carrying consumes it or hands it on in every branch.

### 6.7 Remote computation

Work on a peer is a process spawned there, `Peer.spawn(name, f)` (§6.2, §8.3), and its result reaches another process as a message. The program names the node at the spawn: the runtime chooses no node for it.

### 6.8 `Never`

A function with mailbox type `Never` can send but never receive: a `receive` with a pattern clause is a type error, and a `receive` with only an `after` clause is how a `Never` process waits.

`with Never` annotates a process root that never receives: `main`, or the function a spawn lambda calls. A function so annotated can only be called where the mailbox is `Never`; a send-only helper called from process code is polymorphic instead, `with m`, as `Io.println` in Appendix E.

### 6.9 Death

A process dies when its function returns, when `kill` is called on it, on a fault (§7.3), or when the program ends (§8.6). Its `Reason` (§9.3) says which: `Returned`, `Killed`, `Fault(cause)`, or `ProgramEnd`; `Unknown` is what a `monitor` made after the end says. `kill` is asynchronous: the target may run until the runtime interrupts it. `kill` on a process that is dead has no effect. `monitor(a, wrap)`, §9.5, places `wrap(d)` in the caller's mailbox when `a` dies; `d : Down` gives the process and the cause. `process` in `Down` is the process behind `a`, as `Process.fromAddress(a)` gives it (Appendix E.21). If `a` is already dead, the message is placed at once, with the reason `Unknown`: the runtime keeps nothing of a process that has ended, so a `monitor` made after the end cannot say how. A `monitor` made while the process runs gets its reason, and a process started with `spawnMonitored` (§6.2) is monitored from its start. Each `monitor` call produces one message. A `Down` comes from the runtime and has no order with the messages the ended process sent (§6.4); a result that must not be lost to a `Down` comes as the callee's own answer to a call (§6.6), which its end does not overtake. A `wrap` has no sender to run in: the runtime applies it as it delivers the message. A fault in it is the fault of the process it delivers to, and a `wrap` that does not finish holds up no other delivery. `site` in `Down` is where the dead process was spawned: the qualified name of the top-level declaration in which the `spawn` or `spawnMonitored` that started it is written, with the line where it is written: `Counter.main:19`. A `spawn` in a lambda or a local `fn` counts as written in the top-level declaration that contains it. Where `spawn` is passed as a value, it counts as written where its name is. For the entry process it is the entry point's name. With the reason `Unknown` it is the empty string. There are no other links. A process the program spawns belongs to no one, and ends only as this section says. A process the runtime starts for a resource, a socket, a listener, or a program the runtime started, belongs to the process that opened it or was given it, and ends with it; closing the resource ends its process, and killing its process closes it.

`restarting(RestartLimit(restarts = n, within = t), f)`, §9.5, is a function that runs `f()` and, when `f` faults, runs `f()` again in the same process. The process keeps its address, and the new run begins with nothing of the old one that the process holds: what it spawned, opened or put in a table lives on, since it is another's or the runtime's. Its mailbox is emptied, the message being handled lost with the rest, and every call waiting for an answer from it ends (§6.6). What the process has asked the runtime for is cancelled, whenever it asked, before its first run or in any run: its alarms (Appendix E.15), its monitors, and its subscriptions to the terminal (§8.2) and to faults (Appendix E.21). A message that arrives while the process restarts is dropped or taken by the new run. A restart is not a death, and no `monitor` is told of it. When `n` restarts have happened within the last `t` milliseconds, the next fault is not restarted; a count below 0 is none (§7.4), and a window below 1 is 1. A fault restarts the innermost restarting function the process runs, which counts it against its own limit; one that does not restart it gives it to the restarting function around it, and the process dies with its cause where there is none. A restarting function counts from when it is entered, so one entered again by the restart of the one around it counts afresh. `restarting(Unlimited, f)` runs `f()` again after every fault. `f` returning, a `kill`, and the program's end end the process as they end any other.

A child of a `Supervisor` (Appendix E.22) also runs `f()` again when its supervisor asks. It runs on until it next waits, in a `receive` or for a call's answer, and there runs `f()` again; a process already waiting does so at once. It restarts as a fault restarts it: its address kept, its mailbox emptied, every call waiting for an answer from it ended, and what it has asked the runtime for cancelled. A restart asked for is not a fault: it counts against no limit, and no fault is reported. Where `f` itself runs a `restarting` function, the restart asked for runs `f()` again, not the inner one. A process that computes without waiting takes the restart asked of it when it next waits, and one that never waits is never restarted.

### 6.10 Code replacement

A process replaces its code by a message in its own type that carries the new loop, and switches with a tail call:

```ernest
type CounterMsg =
    Inc(Int)
  | Get(reply : Reply(Int))
  | Upgrade(migrate : (Int) -> Int, next : (Int) -> Unit with CounterMsg)

fn counter(n : Int) : Unit with CounterMsg =
    receive {
        Inc(k) -> counter(n + k)
      | Get(reply = r) -> {
            answer(r, n);
            counter(n)
        }
      | Upgrade(migrate = m, next = k) -> k(m(n))
    }
```

A function does not cross nodes in a message (§3.11), so a process on another node is sent its `Upgrade` by a process spawned on that node, which the spawn gives the new function, as the statement `let _ = Peer.spawn(name, fn() = send(c, Upgrade(migrate = m, next = k)))` does. The language has no other mechanism for code replacement. The shell's reload (§11.2) runs new calls on the new code and never changes the code a running process runs; a process whose code the shell can no longer keep faults with `Fault("its code was unloaded")` (§7.4).

## 7. Errors

There are no exceptions. An error is a value, a message, or a fault.

### 7.1 Value errors

The error is part of the function's meaning and is in its result type, `Either(e, a)` or `Optional(a)`. The caller matches on the result or chains with `let p <- e` (§5.5).

### 7.2 Message errors

The error crosses a process boundary and is in the message: `Either`, or a constructor of the reply type. A missing reply is `None` from `Address.call`, after the time limit or once the callee has ended or restarted (§6.6).

### 7.3 Faults

A fault ends the process that meets it, with the reason `Fault(cause)` that `Down` carries (§6.9), unless the process restarts (§6.9). The code cannot see it, and nothing catches it. Its causes are those §7.4 lists and those a standard library function's section gives, the supervisor's among them (Appendix E.22), each with its text. A process that is killed, or that ends with the program, has not faulted.

### 7.4 Causes of faults

A function answers a failure as a value: `Optional` where the failure has no cause the program can act on, `Either` where it has one (§7.1, E.0 shape rule 4). A function faults only where it cannot return, where its result is a `Float` the finite range cannot hold (§3.1), or where the failure is the runtime's own, a boundary crossed, a peer lost, a limit of the host met. An operator and a construction the grammar gives fault, since the form has no place for a value. A refused request faults the process that made it; a failure no request stands behind, a standard input that cannot be read or keys that are not UTF-8 among them (§8.2), faults the entry process; standard output or standard error that cannot be written ends the program without a fault (§8.6). A count or a duration below 0 is none, but a restart window below 1 is 1 (§6.9); a duration has no upper bound, and a moment already past is now; no other value is corrected unsaid. The causes are these, each with its text, and a standard library function's section gives its own. A pure function can fault.

- `/` and `%` on `Int` with a zero divisor: `Fault("division by zero")`. `Int.div` and `Int.rem`, Appendix E.8, return `Optional` instead.
- `Float` arithmetic whose result the finite range cannot hold (§3.1): `Fault("float arithmetic error")`. `Int.toFloat` of an integer that rounds beyond the largest finite `Float`: `Fault("Int out of Float range")`.
- Bitstring construction (§5.11). A value that does not fit its width, other than a literal the compiler refuses: `Fault("segment overflow")`. A dynamic total bit count that is not a multiple of 8: `Fault("bitstring not byte-aligned")`.
- `fault(c)`, which compiles at any type: `Fault(c)`.
- `Address.callForever` whose callee has ended, or ends or restarts before it answers (§6.6): the callee's cause, `Fault("callee was killed")`, `Fault("callee returned without answering")`, `Fault("callee was closed")`, `Fault("callee was restarted")`, or `Fault("callee had ended")`.
- Cross-node transport of a foreign value (§3.8): `Fault("foreign value cannot cross nodes")`.
- Cross-node transport of a function (§3.11), or of an adapted address whose target is on another node than the address (§6.5): `Fault("function cannot cross nodes")`.
- `Peer.spawn` or `Peer.spawnMonitored` with an unknown or unreachable peer: `Fault("peer unreachable")`. `Peer.spawn` or `Peer.spawnMonitored` with a resolution failure on the peer (§8.7): `Fault("peer resolution failed: ...")`.
- A foreign function that raises: `Fault("foreign function m:f/n raised ...")`. A function of the program's that foreign code calls faults as it would anywhere, and the foreign function passes the fault on as it is; a restart asked for while it runs is a restart (§6.9). A foreign function's return is checked against its declared type when the function returns, and a reply foreign code gives (§8.4) when `Address.call` or `Address.callForever` returns it, each in the calling process and to the value's whole depth; a function value in it is checked when it is called, its result against its declared result type. A mismatch faults the calling process: `Fault("foreign return does not match T")`, `Fault("reply does not match T")`, and an argument foreign code gives an Ernest function `Fault("foreign argument does not match T")` (§8.4). A message from a foreign process that does not match the mailbox type faults the receiver on delivery (§8.4): `Fault("message does not match M")`. Each names the declared type.

These faults come from no operation of the list above. A failure in the runtime faults the process that meets it with the host's class and reason, as a spawn beyond the host's limit of processes does with `Fault("error:system_limit")`. A fault in a function adapting an address faults the target with its own cause (§6.5). `Os.exit` with a status outside 0 to 255 faults its caller with `Fault("an exit status is from 0 to 255")` (Appendix E.23). In the shell and under `ern test`, `Os.exit` with a status `n` from 0 to 255 faults its caller with `Fault("exited with status n")` (§11.2). A working directory the host can no longer read as the program starts faults the initializer of `Os.workingDirectory` with `Fault("the working directory cannot be read: r")`, `r` the host's reason, and so ends the program before `main` runs (§8.5, Appendix E.23). The loss of a peer faults every process on it with `Fault("peer lost")` (§10). A deadlock faults the entry process with `Fault("deadlock")` (§8.6), and under `ern test` the process of the test that runs (§11.2). The unloading of the code a process runs faults the process with `Fault("its code was unloaded")` (§11.2), and a use of a binding a faulting reload left without a value faults its reader with `Fault("the binding has no value, since one before it faulted")` (§11.2). A subscription to the terminal after it was read as lines faults the subscriber with `Fault("the terminal is already read as lines")`, and a read of a line or of bytes after it was claimed for keys faults the reader with `Fault("the terminal is already read as keys")` (§8.2). While a shell holds the terminal, subscribing to it or reading a line or bytes from any other process faults that process with `Fault("the shell holds the terminal; run the program with ern run to give it the keyboard")` (§11.2). A line of standard input that is not UTF-8 faults the process that asked for it with `Fault("the standard input is not UTF-8")`, and keys that are not UTF-8 fault the entry process with the same cause (§8.2). A standard input that cannot be read faults the entry process with `Fault("the standard input could not be read: ...")`, the host's reason after the colon (§8.2).

## 8. Programs

### 8.1 `main`

The entry point is a function of type `() -> Unit with m`. The process that runs it is the *entry process*. `m` is the message type when the entry receives. It is `Never` when the annotation says so. Otherwise it is polymorphic, and the runtime instantiates it to `Never`. A pure function of type `() -> Unit` is an entry point too, and its process's mailbox type is `Never`. A result type that is a type variable, as a function that never returns has, is taken as `Unit`, as a mailbox type that is a variable is taken as `Never`. A top-level `let`, a function of another shape, and a private function are not entry points, and `ern run` refuses them. `ern run module.erc` runs the `export fn main` of that module; `ern run --main Qualified.name module.erc` runs another exported function of that shape. `main` is a convention, not a reserved name.

### 8.2 System references

The runtime starts its system processes when the program starts, whether or not the program uses them. Each process's address is a top-level binding of its *system module* in the standard library, private to that module: `stdout`, `stderr`, and `stdin` of `Io`, and `reference` of `Terminal`, `Clock`, `Fs`, `Tcp`, and `Os` (Appendix E). A program uses each through its module's functions. The binding's initializer is a `foreign fn` of the module that answers the runtime's address (§4.7), evaluated before the program's other bindings (§8.5). The message type is declared in the module, in Ernest, for the module and for the foreign process behind it (§8.4), and no other module can make a message of it. A runtime may provide more system modules. In code shipped to a peer, a system module the peer's runtime does not provide is a resolution failure (§8.7).

**Standard output and standard error.** `stdout` writes the bytes it receives to standard output as they are, and adds nothing; a string reaches it as its UTF-8 bytes. `stderr` does the same to standard error. A write returns once its stream has taken the bytes, and waits while the stream is behind. A stream that can no longer be written, its reader gone or its device failing, ends the program (§8.6), and what was still to be written to it is lost.

**Text from the host.** Text the host gives a program is UTF-8, or is an error of the function that met it: a value where the function's type carries one, and a fault of the process that asked where it does not. Nothing is left out for its bytes; where a whole cannot be given as text, a directory's listing or an environment, the error names it.

**Standard input.** Standard input is read as UTF-8, whatever the host's locale. `stdin` answers each request with the next line, without its line feed and without one carriage return before the line feed, and with `None` at end of input. A last line without a line feed is a line, and keeps a carriage return it ends in. A line that is not UTF-8 faults the process that asked for it with `Fault("the standard input is not UTF-8")` (§7.4). A standard input that cannot be read faults the entry process (§7.4). A request for bytes is answered with what has arrived, at least one byte, and `None` at end of input. A line is read whole however long it is; a program that reads input of a size it does not trust reads bytes. Lines and bytes are read from one stream, each request taking up where the one before it stopped.

**The terminal.** The terminal sends each subscriber an `Event` (Appendix E.16) for every key pressed and for every change of the terminal's size. A process holds one subscription to the terminal: a second `Terminal.subscribe` replaces the first, and its wrap is the one used from then on. A subscription ends when its process dies or restarts (§6.9). Where standard input is not a terminal, a subscription is refused with `Left(NotATerminal)` and claims nothing, whether or not a line or bytes were read before it. The terminal answers a request for the size with the size now, and with `Left(NotATerminal)` where standard output is not a terminal, the one case in which the host has no size (Appendix E.16). The terminal and standard input are one terminal, read as keys or as lines: a subscription that is granted claims it for keys, and a read of a line or of bytes claims it for lines. Keys are read as UTF-8 too, and keys that are not UTF-8 fault the entry process with `Fault("the standard input is not UTF-8")`. The first claim stands, and a claim the other way faults the process that makes it (§7.4). A subscription after a line or bytes were read faults the subscriber with `Fault("the terminal is already read as lines")`. A read of a line or of bytes after a subscription was granted faults the reader with `Fault("the terminal is already read as keys")`.

**Keys.** A subscription is answered once the terminal is in the mode the keys need: nothing typed after `subscribe` returns is echoed. While a program is subscribed, the terminal delivers each key as it is pressed and does not echo it, and the runtime gives the terminal back with the settings the program found when the program ends. A key the terminal sends as one character arrives as `Key` of it, a control character among them: Enter is `Key('\r')`, or `Key('\n')` where the terminal sends a line feed, Backspace `Key('\u{7f}')` or `Key('\u{8}')`, and Tab `Key('\t')`. The escape character begins a sequence: an arrow's arrives as the arrow, and one the runtime does not name as `Escape` and the characters after it. `Escape` is delivered once no escape sequence can still follow it. The terminal applies each subscriber's wrap itself, keeping its keys in order. A wrap that does not finish delays that subscriber's keys and no other's.

**Paste.** While a program is subscribed, the runtime asks the terminal to bracket a paste. Pasted text then arrives as one `Pasted`, not as the keys of its characters, and its line endings are line feeds. A paste whose end the terminal does not send ends when no more of it arrives, what came of it being the `Pasted`, and an end that comes after it is nothing. A terminal that does not bracket a paste sends its characters as keys.

**Interrupt.** While the terminal is claimed for keys, its interrupt is delivered to every subscriber as `Interrupt`, in place of the signal that would end the program (§8.6). Otherwise that signal ends the program.

**The clock, the file system, TCP, and the host's programs** answer their modules' requests as Appendix E.15, E.17, E.18, and E.23 say.

### 8.3 Peers

A *node* is one running runtime, and a *peer* is another node this one knows by name. Peers are configured outside the language, §11.3, and nodes authenticate each other. The module `Peer` acts on a peer by its configured name: `Peer.spawn(name, f)` and `Peer.spawnMonitored(name, f, wrap)` start a process there as `spawn(f)` and `spawnMonitored(f, wrap)` start one on the running node (§6.2).

### 8.4 Foreign code

The system processes are foreign processes: their message types are declared in Ernest, their implementations live outside the language, and the runtime starts them (§8.2). Other foreign code enters through `foreign fn` and `foreign type`, §4.7. Both boundaries carry the same promise: the foreign side delivers the declared types, and a breach faults the receiving Ernest process: a bad return value or reply when the call returns, a bad message on delivery. The standard library and the system processes are the runtime's own, and what passes between them and a program is not checked: the return of one of the library's foreign functions, a message from a system process, an address or a `Reply` given to either, and the answer to a call the library makes. Everything else is checked where it crosses. An address that foreign code gives, in a return, a reply, a message, or an argument it calls an Ernest function with, is *foreign* unless it names a process of the program. An address of the program's that foreign code gives back is the program's own at the type it crossed at, and foreign at any other, so that what is sent to it is checked as a message foreign code sends. A message sent to a foreign address, an answer given to a `Reply` foreign code gave, and a foreign function's argument cross into foreign code: a message foreign code sends to an address in one is checked on delivery. That check lasts until the process the address names ends, and there is one for each distinct address that has crossed. An address made by `via` is distinct by its function and by the values its function captured. An answer foreign code gives to a call is checked when `Address.call` or `Address.callForever` returns it. An answer Ernest code gives to a `Reply` foreign code gave crosses into foreign code, as the sentences before say, and no other answer is checked. A type variable of a foreign function's result that no parameter's type names matches no value, since the function was given none of that type: `foreign fn cast(x : Foreign.Term) : a` faults whenever it returns, and a function that does not return, `Os.exit`, may be declared so. The check meets such a variable only at a value of it: an empty container holds none, and a value of a foreign type is not looked into, so a foreign function whose result is `List(a)` and empty, or `Table(k, v)` of a foreign type, returns. A function that crosses into foreign code, a foreign function's argument or one inside it, in a message or in an answer, has each argument foreign code calls it with checked against its parameter's type, and a mismatch faults the calling process with `Fault("foreign argument does not match T")`. A type variable that a parameter's type names matches any value, in a foreign function's result and in an argument foreign code calls a function with, since its type is the caller's: `foreign fn weird(x : a) : a` answering `2` for `weird([1, 2])` is not caught at the boundary. `Foreign.from` gives foreign code its value as the runtime holds it (Appendix E.12), so an address in it crosses without a proxy, and a function without its check.

**ABI.** The runtime maps Ernest values to host terms; for the BEAM runtime:

- `Int` → arbitrary-precision integer.
- `Float` → IEEE double, finite (§3.1).
- `Bool` → atom `true` or `false`.
- `Char` → integer, the code point.
- `String` → binary, UTF-8.
- `Bytes` → binary.
- Nullary constructor `C` → the quoted atom of its source spelling, `'Ready'`, `'None'`.
- Positional constructor `C(v)` → `{'C', v}`.
- Named constructor `C(f1 = v1, ..., fk = vk)` → `{'C', v1, ..., vk}` with the fields in their declared order (§3.5).
- Tuple `#(v1, ..., vn)` → `{v1, ..., vn}`.
- `List(a)` → proper list.
- `Map(k, v)` → a map from each key's term to its value's term.
- `Set(a)` → `{set, S}`, `S` a set of Erlang's `sets` module in its version 2, a map from each element's term to `[]`.
- `Address(m)`, function values → opaque handles foreign code may pass back but not inspect.
- `Reply(a)` → an alias: foreign code answers `v` by sending `{Alias, v}` to it.
- Foreign values → as foreign code made them; Ernest does not inspect them.

A process's end is a host term too: a process that returned exits `normal`, one that faulted `{ern, fault, Text}`, one killed by `kill` `{ern, killed}`, and one ended with the program `{ern, program_end}`. These are the `Reason` values of §9.3 as the host sees them.

Same-named constructors of different types share an atom; the receiver's declared type disambiguates. Cross-node transport uses the runtime's external term format for these representations. A `foreign fn` implementation is named `module:function/arity`, the arity its parameter count. A name not of that form, or whose arity is not the parameter count, is a compile-time error. A module or function the host lacks when the call is made raises, and the call faults as §7.4 says: `Fault("foreign function m:f/n raised error:undef")`.

### 8.5 Initialization

Before `main` runs, the runtime evaluates in the entry process, in dependency order, every top-level `let` of the standard library, and then of the entry point's module and of every module it depends on, directly or through others. The standard library is initialized whole, whether the program depends on each of its modules or not; another module the program does not depend on is not initialized. A binding depends on every top-level `let` its initializer names, and on what every function it names depends on, called or not; a lambda's body is part of its initializer. A binding is evaluated after those it depends on, and otherwise in the order its module declares it. A module's bindings are evaluated after those of every module it depends on. `let handlers = [f]` is a cycle when `f` names `handlers`, and so is `let a = fn() = a()`. The order of modules that do not depend on one another is unspecified. A cycle is a compile-time error. Only `let` requires evaluation. An initializer runs as a body of mailbox type `Never` (§4.6), whatever the entry process's mailbox type: it receives nothing, and `self()` in it is an `Address(Never)`. A service it spawns runs from then on. The initializers of two modules that do not depend on one another print in no promised order, and within a module they print in the order the initializers run, as above. An initializer that faults (§7.4) ends the program with that fault before `main` runs. Its fault is reported under the binding, its qualified name and the line it is declared on, as a spawn site is (§6.9): `Init.bad:3 faulted: division by zero`. Which of two independent faulting initializers is reported is unspecified. An initializer that does not terminate prevents the remaining initializers and `main` from running.

### 8.6 Program termination

The program ends when the entry process dies, whatever the reason (§6.9), a fault being reported on the runtime's exit indicator, when any of its processes calls `Os.exit`, which gives the status the runtime exits with (Appendix E.23), or when its standard output or standard error can no longer be written (§8.2). Live local processes then die with the reason `ProgramEnd`, and the runtime flushes the system processes' pending output before it stops. A signal from outside that ends the program, the host's termination or hangup, ends it the same way. One that comes before the runtime can take signals, in the host's first fraction of a second, may be lost, or may end the program as the host ends it, with status 0 and a line of the host's own. The host's interrupt ends it at once, and output the system processes have not yet written may be lost. The runtime prints nothing of its own about a signal. Workers spawned on peers are unaffected and follow their own return, `kill`, or peer loss (§10); peers observe the ending node as lost. A program that is to keep running waits in `main`.

When no forward progress is possible, the entry process faults with `Fault("deadlock")` (§7.4) and the program ends as above. No progress is possible when every live process waits in `receive` without `after` or in `Address.callForever`, no message is in flight, no monitor waits on a process the runtime did not start, and no system process, listener or socket (E.18), or connected peer holds a timer, a subscription, a pending I/O, or a computation whose completion would deliver a message. A process spawned on a peer by this node counts as such a computation while it runs, and a program that `Os.start` started until it has exited or been killed (Appendix E.23). Detection is per node. Whether a user-provided foreign process counts like a system process here is the runtime's choice.

### 8.7 Code shipping

Only a spawn on a peer ships code: `Peer.spawn(name, f)` and `Peer.spawnMonitored(name, f, wrap)` ship `f`, the values it captures, and the code that `f` and every function among its captures depend on. A message ships no code (§3.11): it is decoded with the types of the receiving process's mailbox type, which that process's node holds, and a value sent to an adapted address with the types of its function's argument, which the node where the address was made holds. Within a node nothing is shipped.

**Content addressing.** Every function, constructor, and type is identified across nodes by a hash of its normalized definition together with the hashes of what it references. Identical definitions have the same hash on every node. A type's hash includes its qualified name, so two types with the same constructors under different names are different types. A change to a definition that normalization does not undo changes its hash, and transitively the hashes of everything that depends on it. A set of mutually recursive definitions is hashed as a group, internal references by position, and each member's identity derives from the group's hash. Normalization renames local variables, keeps named fields in their declared order (§3.5), preserves the source evaluation order of construction expressions, and preserves the qualified names of external references.

**Resolution.** Before a shipped function runs, the peer resolves every hash it carries, transitively, from its own store or by fetching from the sender, and caches what it fetched. A resolution failure is a missing dependency, a system module the peer's runtime does not provide, or an incompatible foreign definition, and it faults the caller of `spawn` or `spawnMonitored`. A resolution failure does not invalidate other addresses on that peer; only the loss of the peer does (§10).

**Identity.** Two nodes with identical declarations under the same qualified name interoperate. Two nodes with different declarations under one name hold distinct types. A spawned function that mentions the sender's `FooMsg` uses the sender's `FooMsg` on the peer; the peer's own `FooMsg` is unrelated to it. An abstract type's hash also includes the types of its module's exported declarations: two `Stack(a)` declarations with the same name and representation are one type only if their modules export the same declarations with the same types. An address carries the hash of its process's mailbox type. A message reaches only a process whose mailbox type has the hash the sender's code gives it, and two versions of a type never meet in one message. A `foreign fn` that answers an address is trusted for its hash as for its type (§4.7).

**Bindings.** A top-level binding the function names is the peer's, and a value the function captured is the sender's. A system module's binding in shipped code is the peer's: a shipped `Io.println` writes on the peer. An address captured by the function is shipped as a value and still names the process it named on the sender. A top-level binding referenced by shipped code is evaluated on the peer on first use, in the peer's environment, at most once per node for each hash of its definition. Where the peer's own program has evaluated the binding, that evaluation is the one shipped code reads, so a service binding names the peer's service. A binding whose definition differs from the peer's by hash is another binding: shipped code compiled from another version of a service's module starts a second service on the peer, running the sender's version. An initializer that faults there faults the process that first uses it. Foreign declarations are not shipped: a shipped function that references one requires a compatible definition under the same qualified name on the peer.

## 9. Prelude

The prelude holds what a rule of this report names and what no function written over the prelude could provide: a function is the prelude's where a rule of this report names it, or where no declaration, a `foreign fn` among them, could give it its meaning, and how common an operation is puts it nowhere. A prelude function has the shape Appendix E.0 gives a library function of its kind, and differs from one by nothing but its place. Everything else is the standard library, Appendix E: the container, string, and numeric operations and the output helpers. An operation of §9.6 in a type's namespace, `Int.compare`, is provided by that type's standard library module, and `Io.show` and `Io.debug` of §9.4 by `io.ern` (Appendix E.1). `Address.call` and `Address.callForever` are the runtime's, as the rest of §9.4 and §9.5 are.

The prelude's names are documented as a standard library module's declarations are (E.0 shape rule 6), on a page of their own, and an operation a type's module provides is documented there.

A type is the prelude's when the language's rules name it, as `Optional` for `<-`, `Down` for `monitor`, and `RestartLimit` for `restarting`; or when the module of its operations is named after it, as `Map`, `Int`, `Path`, and `Process`. Any other type a module provides is the module's, as `Random.Seed`.

### 9.1 Built-in types (§3)

```
Int, Float, Char, String, Bytes, Bool // §3.1
Address(m) // an address of a process that receives m
Reply(a) // a one-shot address, §6.6
Never // the type with no values
Process // the identity of a process, Appendix E.21
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

```ernest-prelude
type Unit = Unit // the one-value type; carries no information

type Optional(a) = None | Some(a)

type Either(e, a) = Left(e) | Right(a)

type Ordering = Less | Equal | Greater

type Down = Down(process : Process, reason : Reason, site : String)

type Reason = Returned | Killed | ProgramEnd | Fault(String) | Unknown

type RestartLimit = RestartLimit(restarts : Int, within : Int) | Unlimited // within in milliseconds, §6.9

type Path = Path(String) // in the runtime's syntax
```

### 9.4 Built-in functions (§6)

```
self           : () -> Address(m) with m
send           : (Address(a), a) -> Unit with m
spawn          : (() -> Unit with n) -> Address(n) with m
spawnMonitored : (() -> Unit with n, (Down) -> m) -> Address(n) with m
Io.show        : (a) -> String // the value as Ernest writes it, at the use's type (Appendix E.1)
Io.debug       : (a) -> a with m // prints Io.show's text and a line feed to standard error, then returns the value
```

### 9.5 Process functions

```
via                 : (Address(b), (a) -> b) -> Address(a)
Address.call        : (Address(m), (Reply(a)) -> m, Int) -> Optional(a) with n
Address.callForever : (Address(m), (Reply(a)) -> m) -> a with n
answer              : (Reply(a), a) -> Unit with m
restarting          : (RestartLimit, () -> Unit with n) -> () -> Unit with n
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
Path.<> : (Path, Path) -> Path // Appendix E.14: the second under the first; an absolute second stands alone
Int.compare : (Int, Int) -> Ordering // §3.10: ordering is per type
Float.compare : (Float, Float) -> Ordering
String.compare : (String, String) -> Ordering
Char.compare : (Char, Char) -> Ordering
fault : (String) -> a // §7.4: faults with the cause given
```

On `Int`, `Float`, `String`, and `Bytes` an operator is the runtime's own operation; `List.<>` and `Path.<>` are Ernest in their modules. The declaration of one in the type's module, `fn Int.+(a, b) = a + b`, names that operation and is not a recursive call. On `Int`, `Float`, `String`, and `Char`, `<`, `<=`, `>`, and `>=` are likewise the runtime's own ordering, and `compare` in the type's module is written with them and is not a recursive call. On `Int` and `Float`, prefix `-` is the runtime's own negation, and `negate` in the type's module is written with it.

### 9.7 System references

The prelude binds no system reference. Each is a private binding of its system module, §8.2.

## 10. Runtime Requirements

- Tail calls take constant stack space. A function's body is in tail position. Where an expression is in tail position, so are both branches of an `if`, the body of each `match`, `receive`, and `after` clause, the last expression of a block, the right operand of `&&` and `||`, and the call a pipe makes.
- Processes are scheduled preemptively; a process cannot prevent others from running.
- Processes share no memory, except what foreign functions share (§4.7); a message is a copy or immutable.
- Mailboxes are unbounded; a program is responsible for its own backpressure.
- `Int` has arbitrary precision.
- Bitstrings are constructed and matched by the runtime's bit syntax (§5.11).
- Unicode's tables, which decide a `Char`'s category and case, a `String`'s graphemes and White_Space, and a grapheme's width (Appendix E.4, E.5, E.16), are the host's, of the version it ships.
- The representation of values is fixed and documented.
- The hash and the normal form of §8.7, how nodes authenticate each other (§8.3), and the wire format are the runtime's, fixed and documented with it.
- `Down` carries a reason distinguishable from every other.
- The runtime detects a deadlock (§8.6).
- A node ships the code of a function spawned on a peer that lacks it, identified by content; dependencies resolve by hash before the shipped function runs, types are content-addressed, a system module's binding is the peer's, and foreign code is per node, §8.7. A message ships no code, §3.11.
- The runtime detects the loss of a peer: every process on it is treated as dead with the reason `Fault("peer lost")`, and monitors deliver `Down` (§6.9). Loss is terminal: a peer that reappears under the same name is a new instance, and addresses held before the loss are unrelated to it. `send` to a peer is best-effort; messages in flight at the loss are dropped without notice.

## 11. Toolchain

The toolchain is one command, `ern`, whose first word is its job: `ern build`, `ern doc`, `ern format`, `ern run`, `ern test`, `ern shell`, and `ern config`. `ern --help` and `ern --version` are options. Options are long: `--name`, or `--name value` for one that takes a value. An option that names a directory ends in `-root` where the directory's layout gives namespaces (§4.2), in `-dir` where it is a plain directory, and in `-path` where it is a root that may be given more than once. Only a `-path` option is given more than once. `--name=value` is refused with the spelling `--name value`, and so is an empty value. A job or an option spelled as an earlier version of the toolchain spelled it is refused, and the refusal names the spelling that replaces it: `--shell`, `--test`, and `--doc` are the jobs `ern shell`, `ern test`, and `ern doc`; `--create-config-dir` is the job `ern config`; `--out-dir` is `--build-root`; `--errors short` is `--short-errors`; `--emit erl` is `--emit-erl`; and `--no-clean` is gone, a separate output taking a separate `--build-root`. `ern` refuses to start in a working directory whose name is not UTF-8. It starts the host without the flags and the code path the environment would give it, `ERL_AFLAGS`, `ERL_FLAGS`, `ERL_ZFLAGS` and `ERL_LIBS`. A word of the command line that is not UTF-8 is refused before the job begins, `ern build: a word that is not UTF-8: n\xFFme.ern`, each byte past ASCII written `\xHH`; an argument of a program is refused as §11.2 says. A failure of `ern` itself is a defect of the toolchain, and it is reported on standard error with the host's stack. The host's termination or hangup ends a job at once, and a run once the runtime has stopped as §8.6 says (§11.8). A `.erc` a job is given that is no compiled module is refused, `x.erc is not a compiled module`. A job whose standard output or standard error can no longer be written (§8.2), its reader gone or the stream closed as the job begins, ends at once and writes nothing more. A file a job writes is written whole or not at all: a job that ends as it writes leaves the file as it was. A link where `ern build` or `ern doc` writes a file is replaced by the file, and a link to the module `ern format` lays out is followed. Two jobs that write one file at once leave it as one of them wrote it. A file its owner may not write is not replaced: the job refuses it, `x.ern: permission denied`, and writes nothing beside it. The toolchain's manual page, `ern(1)`, is this section, rendered as §11.4 renders a manual page: each job's usage line as its SYNOPSIS, this section with §11.1 to §11.6 as its subsections as its DESCRIPTION, and §11.7 and §11.8 as its OPTIONS and EXIT STATUS.

### 11.1 `ern build` (compiler)

`ern build [--source-root src-root] [--build-root build-root] [--load-path dir]... [--emit-erl] [--short-errors] file.ern | src-dir` compiles a module to `file.erc`, or every module under `src-dir`, as below. That file carries the inferred types of the module's exported declarations and which of them are values rather than functions (§4.6); dependent modules are checked against them. A module depends on each module a qualified name in its source names, and on each module that declares a type the interface of a module it depends on names; the compiler checks it against the interfaces of them all, and the `.erc` records them. It carries the module's documentation too: every doc block of §2.2, each declaration's signature, and each function's parameter list as the module writes it. On the BEAM that is the EEP 48 `Docs` chunk, which the host's own documentation tools read. It also records the path from `build-root` to its source. `ern build [--source-root src-root] [--build-root build-root] [--load-path dir]... [--emit-erl] [--short-errors] src-dir` compiles every `.ern` under `src-dir` in dependency order, mirroring the source tree into `build-root` and creating directories as needed. A cycle among the modules (§4.1) is reported with the modules in it. A module that does not compile does not stop the others: every module is compiled but one that uses a module that failed, and every failure is reported. A module is recompiled when its source or the path from `build-root` to it has changed, when the interface of a module it depends on has changed, when any interface of the standard library has changed, or when it was compiled by another build of `ern`, another version or the same version's code changed; a change confined to a dependency's bodies does not recompile its dependents. A module outside the source root is read from its `.erc` under `build-root`, then under each `--load-path` root, found by namespace as §11.2 finds it. A `.erc` that holds another namespace than the build names is not written over: a single-file build under another source root is refused with the option that names the root. A `.erc` is stale when the path it records, taken from the root it lies under, names a file under the source root that no longer exists. A stale `.erc` is not read: a module that uses it is an error, `no module Util: build/util.erc was compiled from src/util.ern, which no longer exists`. Cross-module references link at load, against `.erc` files under `build-root` and the `--load-path` roots. `--emit-erl` writes the module's Erlang source as `.erl` instead, for reading; it carries no interface.

**Source root.** Each file's namespace comes from its path under the source root (§4.2). `--source-root` names it. Without it, a path under the standard library's source root (§4.2) uses that root. Otherwise single-file mode uses the current directory, and directory mode uses the directory passed to `ern build`. Output mirrors the source root, not the directory argument: `ern build --source-root src --build-root build src/net` writes `src/net/http.ern` to `build/net/http.erc`, not `build/http.erc`. `build-root` defaults to the source root, and to `build/stdlib` beside the toolchain for the standard library's own source root (§4.2), where its modules are built.

**Path shape.** The name of each `.ern` file compiled, and of each directory between it and the source root, is one or more words joined by single `_`, a word being a lowercase letter followed by lowercase letters and digits: `http`, `httpv2`, `ordered_set`. A module of several words is one such name, `ordered_set.ern` for `OrderedSet`, or a nested directory, `http/parser.ern` for `Http.Parser`. Extensions are `.ern` and `.erc`. A path that breaks the rule is an error, `path component Net must be lowercase`, and so is `http_2`, whose second word begins with a digit, or a `_` that does not stand between two words; the root itself and files that are not modules are not checked. In directory mode, a file or directory under `src-dir` whose name begins with a dot is not a module and is passed over, as an editor's lock file `.#http.ern` is. So is a symbolic link to a directory. A link to a file is read as that file, and is a module at the link's path. A name that is not UTF-8, of a `.ern` file or of a directory that holds one, is an error, `a name that is not UTF-8: src/n\xFFme.ern`, each byte past ASCII written `\xHH`.

**Cleanup.** After a successful directory-mode compilation to `.erc`, `ern build` removes every stale `.erc` from the mirrored build subtree, and each directory of the subtree that the removals leave empty. Nothing else is removed: not a `.erc` whose source lies outside the source root, nor one this build of `ern` cannot read, nor a directory that was empty before, nor `build-root` itself. The sweep passes over each name that begins with a dot and each symbolic link. `ern build --source-root src --build-root build src/net` sweeps `build/net/` and leaves `build/main.erc`. Single-file mode does not sweep.

### 11.2 `ern run`, `ern test`, and `ern shell` (runner)

`ern run [--config-dir dir] [--load-path dir]... [--main Qualified.name] file.erc [argument]...` loads the module and, on demand, the modules on the load path. They are found by namespace: `A.B.C` is `a/b/c.erc`, each segment written as its file's name is (§4.2), `OrderedSet` as `ordered_set`. A type-member reference `A.B.C.T.member` is found through the interface of `a/b/c.erc`, the module that owns `T`. The runner starts the system processes (§8.2) and calls the entry point (§8.1): the `export fn main` of the loaded module, or the function `--main` names, anywhere on the load path. The load path holds the standard library and the root of the loaded module: the directory reached from the module's file by going up one directory per segment of its namespace. `--load-path` adds directories. `--config-dir` names the configuration directory (§11.3), whose `ernest.conf` gives the node its peers (§8.3); `ern test` and `ern shell` take it too. A module compiled against another interface of a module it uses, or against another standard library, is refused before anything runs: `Main was compiled against another Geo.Shape; build Main again`. So is a file at a module's path that holds another module. The words after `file.erc` are the program's, `Os.arguments` (Appendix E.23), even one that begins with `-`; an argument that is not UTF-8 is refused before anything runs, `ern run` naming it by its position. An Erlang module that a `foreign fn` names (§8.4) is the host's own or a `.beam` file of that name in a directory of the load path; the host's own is found first. The path-shape rule of §11.1 applies to every `.erc` opened as a module and to each directory between its load-path root and it. Other files are not checked: `.ernest/` under a load-path root is not a module.

`ern test [--config-dir dir] [--load-path dir]... file.erc` runs every top-level `let` of type `Test.Case` in the module (Appendix E.24), exported or not, one at a time in the order the module declares them, each in a process of its own. The module's initializers (§8.5) run first, in the entry process, which then runs the tests. It prints each test's line as the test ends: the test's name with `passed`, with `failed` and the text of `Test.Failed`, or with `faulted` and the cause. A deadlock while a test runs (§8.6) is that test's fault, and the run goes on with the next test. Every other fault is reported on standard error as `ern run` reports it (below); a test's own fault is reported by its line alone. A module without tests prints `no tests`. A module two of whose tests have one name is refused before any test runs.

`ern run` reports every fault of every process the runtime started on standard error, as it happens, a line each: the spawn site and the cause of §6.9, `Counter.worker:23 faulted: division by zero`, and `faulted, restarted:` before the cause where the process restarts (§6.9). A control character of the cause is written as its escape (§2.5), a line feed as `\n`, so that a fault is one line and none of a program's reaches the terminal as itself; `ern test` and the shell write a cause so too, and `ern test` a test's name. Where standard error is neither a terminal nor the stream the environment's `JOURNAL_STREAM` names, each line begins with the time it was reported, in UTC as RFC 3339 writes it, to the millisecond: `2026-09-27T14:22:11.836Z Counter.worker:23 faulted: division by zero`. Beneath a failure in the runtime (§7.3) or a foreign function's raise (§7.4) it prints the host's stack, a function to a line; the cause a program sees in `Down` (§6.9) is the text alone. A system process's fault is not reported. The report is the runtime's own subscriber of `Process.faults` (Appendix E.21). A killed entry process prints `killed` to standard error.

`ern shell [--config-dir dir] [--load-path dir]... [--source-root src-root] [--main Qualified.name] [file.erc]` runs an interactive shell with every loaded module in scope; `--source-root` names where the shell finds a module's source, the working directory by default. In the shell and under `ern test`, `Os.arguments` is the empty list, and `Os.exit` faults the process that calls it with `Fault("exited with status n")` and ends neither the shell nor the run of the tests.

**The shell.** It is the entry point (§8.1). A file's entry point is spawned beside it, so §8.6 ends the program when the shell ends, not when that entry point returns; `--main` then names the function to spawn. A file without an entry point, and without `--main`, is loaded and nothing is spawned. `--main` without a file is refused. The terminal is the shell's, at a terminal and in line mode alike: `Terminal.subscribe` and `Io.readLine` from any other process fault (§7.4), and the terminal's interrupt reaches the shell as a key rather than ending the program (§8.6). A deadlock is not detected while a shell holds the terminal. The shell ends by `:quit`, by `C-d`, or at the end of its input. In line mode what programs write to standard output and to standard error, and what the shell says, goes to standard output in the order written, as all of it goes to the screen at a terminal.

**Inputs.** Each input is checked, compiled as a module of its own, and run in a process of its own. An input may declare what a module may, and every declaration it makes is the session's, so `export` at the prompt adds nothing, and an `abstract type` there needs none. An `abstract type` keeps its constructors to the input that declares it, since each input is a module of its own (§4.4). A `let` at the prompt binds as a `let` in a block does (§4.6), not as a top-level `let`, so that a lambda it binds is generalized, and stands alone in its input. Its pattern binds each name it contains, as in a block, and `let _ = e` runs `e` and binds nothing. A `let` with `<-` is refused. An input that binds a name whose type the input itself does not settle is refused, with the annotation that would settle it. An input whose value, or whose `let`, is reply-carrying is refused (§6.6). An expression's value is bound to `it`, except where the input does not settle its type, which leaves `it` as it was. The session counts what is entered at the prompt, an input or a command, from 1, and a diagnostic names a typed input as the file `input 3`, its count after the word. Bindings survive a fault or an interruption in an input. A socket or a running program that an input opens is owned by the input's process, which ends with the input, and so ends with it unless the socket is given to a process that lives on (Appendix E.18, E.23). An input that faults answers with `fault: ` and the cause, and one the interrupt ends with `Killed`. An input entered while another runs waits, and runs after it, in the order entered; the interrupt ends the running input alone.

**Commands.** A command begins with `:` and is not an Ernest function. A command that takes nothing refuses an argument. A command is selected by its name or by a prefix of its name that begins no other command's name; a prefix that begins more than one is refused with the names it begins. The commands, in the alphabetical order the shell's help lists them:

- `:bindings` lists what the session declares, with their types.
- `:browse Module` lists the exports of `Module` with their types; `:browse Prelude` lists the prelude's types and values (§9).
- `:doc Name` shows the documentation of `Name`; `:doc Prelude` shows the prelude's page, and `:doc Prelude.name` the prelude's `name` past one the session declares.
- `:faults` lists the faults reported since the session began, the last hundred of them.
- `:forget name` forgets a name the session declared, and `:forget *` forgets all of them.
- `:help` lists the commands, each with a line of help.
- `:load Module` loads a module, as **Loading and reloading** below says.
- `:output path` appends what programs write to the terminal or file `path`, `:output -` sends it back to the live region, and `:output` alone says where it goes.
- `:processes` lists the live processes of the session, by spawn site.
- `:quit` leaves the shell, as `C-d` on an empty line does.
- `:reload` reloads the loaded modules whose source has changed, as **Loading and reloading** below says.
- `:set depth n`, `:set length n`, `:set output n`, and `:set timing on` or `off` set the depth and the length a value is printed to, the rows of the live region, and timing; `:set` alone shows them.
- `:type e` shows the type of the expression `e`, which is not run, and refuses a `let` and a declaration.

**Printing.** An expression's value is printed with its type (§11.5), except a value of type `Unit`, which prints nothing. An input that is one name, `Io.readLine`, has its type printed as the name's declaration writes it, under the declaration's own variable names. A declaration is printed with its name and type, and a type declaration with its keyword and its name. A value is printed to a depth and a length, 10 and 100 at start, and what they leave out prints as `...`; `:set depth n` and `:set length n` change them, and 0 sets no limit. With timing on, a result is followed by the time its run took. What a program writes to standard output and standard error is shown in a live region at the foot of the screen, above the input, in as many rows as `:set output` gives it, five at start and none at 0. A byte that is not UTF-8 is shown as U+FFFD. What the shell itself says is written above the region and scrolls with the terminal, except what `Tab` and `Shift-Tab` show.

**Colour.** At a terminal, and where the environment's `NO_COLOR` is unset or empty, the shell colours what it says: a fault report, a diagnostic's first line, and every refusal of a command in red, what the shell answers being plain, the type after a printed value dimmed, a name bold in a completion listing and a `Shift-Tab` brief, the parameter a signature marks in cyan, and in documentation a heading and strong emphasis bold, emphasis in italics, and a code span in cyan. A colour takes no column. Elsewhere, and in `ern build`'s diagnostics, nothing is coloured.

**Scope.** The session's declarations are a scope. An unqualified name is looked up first among the names bound around it, then in the input's own declarations, then in the session's, then in the prelude (§4.2). A type the session declares prints unqualified, except one a later declaration of its name has shadowed, which prints under the input that declared it: `$Input2.T` for the second input's `T`. A later input may declare a member of a type the session declares, `fn Coin.+` after `type Coin`, and the member is the session's; it belongs to the latest declaration of the type's name, and a type declared again starts with no members.

**Faults.** The shell prints a line for each process that faults while the session runs, as `ern run` does and in place of its report. A process that returns, that is killed, or that ends with the program is not reported, nor is one of the shell's own, nor an input's own process. The shell learns of the faults as a subscriber of `Process.faults` (Appendix E.21). A spawn site in the session is written as the session writes names: in a function an input declares, by that function's name, `start:2`, and in an input's own expression as the file its diagnostics name, `input 3:1`. The line is counted as its diagnostics count it, within a typed input and within the file for an input of a startup file.

**Loading and reloading.** `:load` takes a module by its namespace. It compiles the module's source under the source root, or, where there is none, loads its compiled form from the load path or the source root. A compiled form is refused as `ern run` refuses one: one compiled against another interface of a module it uses, or of the standard library, than the session holds, and a file at a module's path that holds another module; and nothing is loaded. Each module it uses that the session has not loaded is loaded the same way, and a module is compiled against the modules the session has loaded. `:load` evaluates the top-level bindings of each module it loads, as §8.5 orders them, in a process of the shell's own. A binding that faults is reported with its cause, and nothing is loaded. The module is then in scope by its qualified name. A module the session has loaded already is refused by `:load`, a module of the standard library among them, since each is in scope from the start. `:reload` compiles again every loaded module whose source has changed, and every loaded module that uses one whose interface the reload changes, all of them before it loads any; where one fails, none is loaded and the session is as it was. A module reloaded has two versions in the session: a process still running the previous one keeps it, as §6.10 requires, and so does a binding that holds a function of it. A reloaded module's top-level bindings are evaluated again, as `:load` evaluates them. One that faults is reported with its cause, and it and the bindings after it keep the values the previous version gave them. A binding the previous version did not have is then without a value, and a use of it faults with `Fault("the binding has no value, since one before it faulted")` (§7.4). A module a reload loads for the first time is loaded as `:load` loads it, and one whose binding faults refuses the reload. A service binding (§6.5) evaluated again starts a service of the new version, and the service of the previous version keeps running the previous version's code, as §6.10 says of any process. A further reload of that module ends those processes with `Fault("its code was unloaded")` (§7.4) and forgets those bindings; the reload that left them running lists them and ends nothing.

**Editing.** At a terminal an input may span lines, and a line wider than the screen wraps onto the rows below it as it is typed. A control character of the input, typed, pasted or recalled, is drawn as its picture, as a diagnostic's source draws it (§11.5), and DEL as `␡`; the input holds it as typed. `Enter` runs the input where the parser can finish it, and takes another line where it cannot, under the prompt `... `. An input the parser cannot finish is one that ends where the grammar expects more, an unfinished raw string or block comment among them. `M-Enter` takes another line whatever the parser says, and `Enter` on an empty line runs what there is. A paste goes into the line at the cursor, its line feeds adding lines and running nothing. The line is edited with these of GNU Readline's Emacs keys, and every other control key does nothing: `C-a`, `C-e`, `C-b`, `C-f`, `M-b`, `M-f`, and the left and right arrows move; `Backspace`, `C-h`, and `C-d` delete a character, and `C-k`, `C-u`, `C-w`, `M-d`, and `M-Backspace` kill text; `C-y` puts back what the last kill took; `C-p`, `C-n`, the up and down arrows, `M-<`, and `M->` walk the history; `C-r` and `C-s` search it backward and forward; and `C-l` clears the screen. A key the terminal sends as an escape sequence, other than these and `Shift-Tab`, does nothing either: `Delete`, `Home`, `End` and the function keys among them. A word is a run of letters and digits for the `M-` keys, and `C-w` kills back to a space, as in Readline. When input or output is not a terminal, the shell is in *line mode*: it reads lines and does not edit them. An input the parser cannot finish takes the next line, under the prompt `... `, as at a terminal, and a blank line or the end of input runs what there is.

**Completion.** At a terminal `Tab` completes the name before the cursor a segment at a time: what is typed before the last `.` names a namespace, a module or a type with members, and the last segment reaches the names directly in it, a namespace completing with its dot. Where what is typed before the last `.` is a name the session binds or a module exports, or a selection from one, the last segment reaches the fields its type selects (§3.5), and so along a chain: `it.co` reaches `it.count`. A name the unfinished input binds, a parameter or a local `let`, is not completed there. A segment matches by its prefix or by the starts of its words, `L.fM` reaching `List.filterMap`, and its first letter as typed (§2.3). A namespace is offered only where it holds a name that may stand there. The names come from what may stand there: a type after `:`, a constructor in a pattern, a field inside a named constructor, a command at an input's start, and a value, constructor, or module anywhere else. After a command, what completes is what the command takes: a module for `:browse`, a module under the source root for `:load`, any name for `:doc`, a name the session declares for `:forget`, a setting for `:set` and, after `timing`, `on` or `off`, and an expression for `:type`. Nothing completes after another command. What the candidates reached by prefix share is completed, and never less than was typed. Where the candidates are reached by the starts of their words alone, the namespace they are all in is completed and the last segment is kept as typed: `L.fM` gives `List.fM`. A lone candidate is completed as far as it goes: a module with the dot after it, and a command or a setting that takes a value with a space after it. A lone candidate is listed whenever `Tab` reaches it, a name with its type and a command or a setting with its help line. Several candidates are listed by a second `Tab`, and by a `Tab` that adds nothing to the line. They are listed alphabetically, those reached by prefix before those reached by the starts of their words. Where nothing is typed, the candidates are the names the session declares, the modules in scope, and the prelude's names other than its constructors; every other name is reached by typing its first letters. `Tab` with only spaces before the cursor on its row indents four spaces. Elsewhere, with nothing before the cursor to complete, it lists what may stand there, after a command as anywhere.

**Documentation.** `Shift-Tab` on a name, the whole name the cursor stands in, shows its type, its first sentence (§11.4), and the version it appeared in, and its documentation (§11.4) when pressed again. A name's documentation is its declaration's section of §11.4's page, headed by the name as the session writes it and showing the type the shell prints for it. A constructor's documentation is its type's. A module's is the head of its page: the title, the version, and the module's doc block. A name that is both a type and a module has both, the type's section first. A namespace that is neither lists what it holds, each name with its type. A name bound by a `let` at the prompt has its name and type alone. `:doc` shows the same documentation.

**Rendering.** The shell shows documentation rendered for the terminal rather than as the CommonMark §11.4 writes. A heading is shown as its text, a code block without its fences, a list item behind a bullet or its number, a block quote behind a bar, and a link as its text with its address after it. Emphasis, strong emphasis, and a code span are shown in the terminal's styles where the shell colours, and as written where it does not. What the shell does not render, raw HTML among it, is shown as written. Prose wraps at the screen's width, 80 columns where there is no terminal.

**Signatures.** Inside a call, where no name at the cursor is documented, it shows the callee's signature with its parameters as declared and the one at the cursor marked, in cyan where the shell colours and between asterisks where it does not; inside a constructor, its fields, the one whose value is at the cursor marked. The call is found wherever the input stands, in a `let`, a declaration, or a command's argument. A callee that is not a function has no signature, and nothing is shown. What `Tab` and `Shift-Tab` show stands in the region under the input, and the next key takes it away. A line wider than the screen wraps. The lines the screen has no room for are counted on its last row: `and 7 more`.

**Startup and history.** At start the shell says `Ernest v. :help for the commands, :quit to leave.`, `v` the toolchain's version. After the file's entry point is spawned, it runs the inputs in `$HOME/.ernest/startup`, and then, where `--config-dir` names the configuration directory, those in its `startup`, neither file required. A file's inputs are taken from its lines as line mode takes them. Without `--config-dir`, `./.ernest/startup` is not run, though `./.ernest` is the configuration directory the option names by default: a directory the shell merely starts in runs nothing of its own. A file both paths name is run once. Such an input is checked and run as a typed one, a command among them, and its value is not printed; one that fails is reported with the file and the line it came from, and the session goes on. A startup file that is not UTF-8 is reported and not run. The inputs of a session at a terminal are kept in `$HOME/.ernest/history`, in a directory made its owner's alone before the file is read or written, one input a line, a newline in an input written `\n` and a backslash `\\`. Each is appended as it is entered; a blank input and one equal to the input before it are not. A line `C-c` abandons is appended as an entered input is and runs nothing, so that `C-p` recalls it to mend. The last thousand are kept, in the session as in the file, and the file is trimmed to them at start. A session in line mode neither reads the file nor writes it. A history file that cannot be read or written is reported once, and the session goes on without one. Where the environment sets no `HOME`, or sets one that is no absolute path, the shell reads no startup file of the person's, and a session at a terminal keeps no history and says so once, at start. `--config-dir` names the configuration directory, `./.ernest` by default.

### 11.3 Configuration setup

The configuration directory is `./.ernest` unless `--config-dir` names another. `ern config [--config-dir dir]` creates it, which only its owner can open, with `ernest.conf` and this node's private key, readable only by its owner, and does nothing else; it fails if the directory exists, empty or not. `ernest.conf` holds this node's network address and public key and the list of peers, each with a name, a network address, and a public key; Appendix C shows one. The names are what `Peer.spawn(name, f)` takes (§8.3).

### 11.4 Documentation extraction

`ern doc [--man] [--source-root src-root] [--build-root build-root] [--load-path dir]... [--short-errors] file.ern | file.erc | src-dir` writes the module's documentation to stdout as CommonMark. The documentation is read from the compiled module, so `ern doc file.erc` writes the same text, and a source path is compiled first. The text is: a title naming the module, `# Ernest module Net.Http`, the module's `since v` line (E.0 shape rule 6) as *Since v.* where the module has one, and the module's doc block; then, in source order, every exported declaration and every declaration with a doc block, each under a heading of its name as a caller writes it, `Net.Http.parse`, with its type (§11.5) in a code block, under the same name, a `since v` line of its own as *Since v.*, the line *Private to the module.* where the module does not export it, the rest of its doc block, and the doc blocks of its constructors or fields as a list. `ern doc src-dir` builds the directory as `ern build` does (§11.1), and writes one such document per module into `build-root` beside the `.erc`, and `index.md` listing them. For the standard library's own source root it also writes the prelude's page, `prelude.md`, titled `# Ernest prelude`, first in the index. The last line names `ern`'s version and the source file. A declaration's heading is level two, so a heading inside its doc block is level three or deeper; a heading in the module's doc block is level two. Appendix E.0 shape rule 6 says what a doc block contains.

**Manual pages.** `--man` writes a manual page instead, in the roff of man(7), which `man` reads. The page is named `Ernest.` and the module's name as a caller writes it, in section `3ern`: `Ernest.Net.Http(3ern)`, and the prelude's `Ernest.Prelude(3ern)`. `ern doc --man src-dir` writes each page beside its module's `.erc`, in a file named as `man` finds it, `Ernest.Net.Http.3ern`, and writes no index. A document or a page `ern doc` wrote of a module under the directory whose source is gone is removed, as the build removes its `.erc`. Each names its module in its title and stands at the module's place, and a file that does not is kept. The page's header names the page, and its footer the version of `ern`. Its NAME line is the page's name and the module's first sentence, the text of the first paragraph of its doc block up to the first period a space follows outside emphasis, code spans, and links, or the whole paragraph where there is none; a module whose doc block has no paragraph has its page's title there. The rest is the page above after its title, under DESCRIPTION: a heading of level two is a subsection and a deeper one a paragraph in bold, a code span and strong emphasis are bold, emphasis is in italics, a code block is indented and not filled, a list item follows its bullet or its number, a block quote is indented, and a link is its text with its address after it. The page's last line is a comment at the head of its source.

### 11.5 Diagnostics

An error is reported as `file:line:column: message`, then the source. Lines and columns count from 1. A line ends at a line feed, and a column is a code point: a tab is one column, and a letter written as two code points is two. The file is the source's path from the working directory, or its absolute path when it lies outside that directory. The source shows a gutter of line numbers, the line before, the erroneous span underlined with `^`, any second span the message depends on, underlined with `-` and labelled, and at most one `help:` line naming the fix. Where the lines shown are not one after another, a line `...` stands for those passed over. The source shows a tab as a space and a control character as its picture, `␛` for U+001B, one of U+0080 to U+009F as U+FFFD. `--short-errors`, which `ern build`, `ern doc` and `ern format` take, prints the first line alone. The parser reports one error per file; the checker reports every error that does not follow from another. Within a block, an error in a statement that binds nothing, or in a `let` whose annotation fixes its name's type, does not stop the block, and the statements after it are checked; an error in any other binding does, since what follows may use the name.

A type mismatch is reported at the innermost expression whose type is fixed: the last expression of a body or block, a branch or clause after the first, an argument, an operand, an element, or a pattern. The message shows both whole types. The label marks the span that fixed the expectation: an annotation, a callee's type, the first branch, clause, or element, the left operand, or the value matched. The help line names the part in which the types differ. An effect error names the primitive called and the function, `let`, or guard that is pure, and labels the annotation that made it so. An operator whose operand type is not determined (§4.8) is reported with the request to annotate it. A statement whose type is not `Unit` (§5.4) is reported whole, with the help line `let _ =`. `Io.show` or `Io.debug` at a type that is not known whole (Appendix E.1) is reported with the request to annotate it. A recursive call's argument at another type than the definition's own (§3.9) has a help line naming the rule: a call at another type goes to a second function. A reply-carrying value passed where it would be duplicated or discarded (§6.6) has a help line naming the ways to discharge it: answering it, passing it on once, or matching it. A `<-` where the parser expects a delimiter has a help line that names `a < -1` (§2.6). A selector its operand's type lacks is reported at the selector, naming a constructor without the field. An error whose span holds a use of a name the module's own declaration hides from the prelude (§4.2) labels that use with the prelude's qualified name: `Unknown` here is this module's constructor, and the prelude's is `Prelude.Unknown`.

A printed type elides an effect variable bound to pure (§3.9). An effect variable that occurs once in a printed type, and is not process-only, is printed as pure: `fn k() : Int with m = 5` prints as `() -> Int`. The compiler shows the three inferred restrictions of §3.9. In a printed type a variable with the equality constraint is `a=`, one that is not reply-carrying `a!`, and a process-only effect variable that occurs in no value position `m+`: `equal : (a=, a=) -> Bool`, `discard : (a!) -> Unit`, `send : (Address(a), a) -> Unit with m+`. One that occurs in a value position is never pure, and is not marked: `self : () -> Address(m) with m`. A printed type is not an annotation, and no mark can be written in one; `=` is written on a foreign type's parameter alone (§4.7), and §9.2 lists `Map(k=, v)` and `Set(a=)` with the mark, though neither is a foreign type. A type name is printed as the module would write it (§4.2). The module's own types and the prelude's are printed unqualified. Other modules' types are printed qualified. A local type that shadows a prelude name is printed qualified. A type variable is printed under its annotation's name; an unnamed one is `a`, `b`, ... for a value variable and `e`, `e1`, ... for an effect variable, avoiding the names in use. An error at a rejected call site names the parameter and the origin of its restriction; `ern doc` prints restrictions the same way.

### 11.6 `ern format`

`ern format [--check] [--short-errors] path...` lays out each module named, and every module under each directory named, as `ern build` finds them (§11.1), in the one layout below, and writes it back in place. A directory named is no source root: the path shape is checked from it, and nothing a namespace decides (§4.2). A file named alone is a module when its name ends in `.ern` and is otherwise one word, as §11.1's path shape says; one that is not is refused and left as it is. The layout has no options. `ern format -` lays out the module on standard input and writes it to standard output, and a diagnostic names that module `-`. With `--check` nothing is written back: the path of each module not in the layout is written to standard output, a line each. A module that does not parse is left as it is, and its diagnostic is written as §11.5 says.

Only line breaks and the spaces between tokens change. Every token is written as it was written, so a literal keeps its spelling and a parenthesis stays. Every comment stays beside the token it was beside. A block comment on a line of code is one space apart from the tokens around it, but for none after an opening bracket and none before a closing bracket or a separator. A blank line inside a construct is kept, one where there were several, except after an opening bracket and before a closing one. One blank line stands between two top-level declarations. A doc block is kept as written, and each Ernest example in it that parses as a module or as a function's body is laid out as one; any other is left as it is.

The layout indents by steps of four spaces, and fits a line within 100 columns where these rules can:

- **A line stands a step in from the line on which the innermost construct open around it began**: a bracket, a brace, an expression an operator carries on, or a body after a `=`, `->`, `then` or `else` that ends a line. A line that opens with a closing bracket or brace, or with `else`, stands at its construct's line. An item standing after its bracket counts as beginning a line there. A further arm, and a further line of a type's alternatives, opens with its bar two columns to the left, so that what follows the bar stands at the step. Only a bracket's items are aligned; nothing is lined up under an `->`, an `=` or a trailing comment.
- **A line that opens with a binary operator carries on the expression above it.** A further line of the same expression stands at the same step. A line whose operator binds more tightly carries on the operand begun on the line above, and stands a step further in.
- **A block, a `match` and a `receive` run over lines however short**, a statement or an arm a line. What follows the closing brace, an `else`, a `then`, a `;`, a `)` or an operator, follows it on its line.
- **A bracket stays on one line when the whole line fits, and otherwise holds one item a line.** A bracket is the parenthesis, square bracket or `<<` around a call's arguments, a function's parameters, a constructor's fields, declared or built, or the items of a tuple, a list or a bitstring. The first item stays on the bracket's line, each further item stands under it, and the closing bracket ends the last item's line. The outermost bracket breaks first, and of two on one line the first. A bracket of one item does not break. A comment or a doc block before the first item puts that item on a line of its own, and the items a step in.
- **A last item that opens a brace keeps the items on the bracket's line** where that line fits up to the brace, as a lambda whose body is a `match` does. The brace and the bracket close together.
- **An `if` stays on one line when it fits, and otherwise breaks at every `then` and `else`.** A branch whose first line ends in a brace or a `then` stays beside its `then` or `else` when that fits: `then {`, `} else {`, `else match x {`, and `else if` are each written on one line.
- **The body after an arm's `->`, a lambda's `=`, or a `let`'s `=` or `<-` stays on its line when it fits**, whole or up to a brace or a `then` that ends its first line. Otherwise it begins the next line. A lambda and a `let` have no other rule of their own.
- **A function's body begins on the line after its head's `=`, however short.** A body that is a block opens its brace at the end of the head's line. A `foreign fn`'s implementation string stands where a body does.
- **A type whose alternatives do not fit breaks after its `=`**, and holds one alternative a line, as a `match` holds one arm a line.

### 11.7 Options

Each option, the jobs that take it, and the section that says what it does:

- `--build-root build-root`, of `ern build` and `ern doc`: the root the compiled modules are written under (§11.1).
- `--check`, of `ern format`: nothing written back, and each module not in the layout named (§11.6).
- `--config-dir dir`, of `ern run`, `ern test`, `ern shell` and `ern config`: the configuration directory (§11.3).
- `--emit-erl`, of `ern build`: the module's Erlang source written instead (§11.1).
- `--help`, alone or after a job: the jobs, or the job's options, written to standard output.
- `--load-path dir`, of `ern build`, `ern doc`, `ern run`, `ern test` and `ern shell`, given more than once: a root under which modules are found (§11.1, §11.2).
- `--main Qualified.name`, of `ern run` and `ern shell`: the function run as the entry point (§11.2).
- `--man`, of `ern doc`: a manual page written instead (§11.4).
- `--short-errors`, of `ern build`, `ern doc` and `ern format`: each diagnostic's first line alone (§11.5).
- `--source-root src-root`, of `ern build` and `ern doc`: the source root (§11.1); of `ern shell`, where the shell finds a module's source (§11.2).
- `--version`, alone: `ern` and the toolchain's version, `ern 0.2.0`, written to standard output.

### 11.8 Exit status

A job exits with status 0 when it has done what it was asked, and with status 1 when it refuses its command line or cannot do it: an option it does not take, a module that does not compile, a file it cannot read or write. `--help` and `--version` exit with status 0. `ern test` exits with status 1 unless every test passed, and with status 0 for a module that has none. `ern format` exits with status 1 where a module does not parse, and with `--check` where a module is not in the layout.

`ern run` exits with the status `Os.exit` gives when a process calls it, and with status 0 when the entry point returns. It exits with status 1 when the entry process faults, by a deadlock (§8.6) as by any other cause, or is killed. The shell exits with status 0 when it ends, whatever its inputs did, and with status 1 where it cannot start, a file that does not load or an initializer that faults, or where its standard input faults it (§8.2). A fault of the shell's own for any other cause is a failure of `ern` itself.

A failure of `ern` itself exits with status 70. A job whose standard output or standard error can no longer be written exits with status 141, 128 plus the number of `SIGPIPE`. A job the host's termination or hangup ends, `ern run` among them once the runtime has stopped as §8.6 says, ends by that signal, but for one that comes before the runtime can take signals (§8.6), and so does a job the host's interrupt ends, at once (§8.6): a shell reports its status as 130, 128 plus the number of `SIGINT`.

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
Return      = ":" Type [ "with" Type ] .
LetDecl     = "let" ident [ ":" Type ] "=" Expr .
Binding     = "let" Pattern [ ":" Type ] ( "=" | "<-" ) Expr .
DeclName    = ident | typename "." ( userop | "compare" | "negate" ) .

Type        = TypeAtom | FnType | ParenType .
TypeAtom    = { typename "." } typename [ "(" Type { "," Type } ")" ] | typevar
            | TupleType .
TupleType   = "#(" Type "," Type { "," Type } ")" .
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
Tuple       = "#(" Expr "," Expr { "," Expr } ")" .
ListLit     = "[" [ Expr { "," Expr } ] "]" .
BitExpr     = "<<" [ BitSegE { "," BitSegE } ] ">>" .
BitSegE     = Expr [ ":" BitSpec { "-" BitSpec } ] .
Block       = "{" Stmt { ";" Stmt } "}" .
Stmt        = FnDecl | Binding | Expr .

Pattern     = ConsPat [ "as" ident ] .
ConsPat     = AtomPat [ "::" ConsPat ] .
AtomPat     = "_" | ident | literal | "-" ( int | float )
            | { typename "." } conname [ "(" ( Pattern | FieldPats ) ")" ]
            | "#(" Pattern "," Pattern { "," Pattern } ")"
            | "[" [ Pattern { "," Pattern } ] "]"
            | BitPat .
BitPat      = "<<" [ BitSegP { "," BitSegP } ] ">>" .
BitSegP     = Pattern [ ":" BitSpec { "-" BitSpec } ] .
BitSpec     = "size" "(" Expr ")"
            | "bytes" | "int" | "float"
            | "utf8" | "utf16" | "utf32"
            | "big" | "little"
            | "signed" | "unsigned" .
FieldPats   = [ ident "=" Pattern { "," ident "=" Pattern } ] .
```

`binop`, `userop`, and `literal` are defined in §2, along with the other lexical categories; `binop` precedence follows the table there. Every nonterminal is decided by its first token, or by the later token this paragraph names: `let` begins a binding, `fn` a declaration or lambda (an identifier or type name after `fn` makes it a declaration, `(` a lambda), `{` a block, `[` a list, `#(` a tuple, `(` a call or parenthesized expression, `<<` a bitstring. After a primary, `.` and an `ident` select a field (§3.5): a lowercase first segment is a value, so `s.upper` selects, while an uppercase one begins a `QName`, `Net.Http.parse`. In a qualified name, of a value in `QName`, of a type in `TypeAtom`, or of a constructor in `AtomPat`, after each uppercase token the next token decides: `.` continues the qualification, and otherwise the segment is final. In `QName` a final `ident` names a function or a value, a `userop` an operator, and a `conname` a constructor. A constructor's fields are positional or named by whether `=` or `:` follows the first identifier. When a constructor name is immediately followed by a parenthesized constructor argument, the parser consumes that argument in the constructor branch of `QName`; a single-positional construction has the semantics of calling the constructor's function value. `conname` and `typename` are one token class; which one a segment is follows from its position. A parenthesized list of types is an `FnType` when `->` follows its `)`, and otherwise a `ParenType` (§3). A `with` after a function type belongs to that type (§3). In a `receive`, a `|` followed by `after` begins its `AfterClause`.

## Appendix B. Examples

The counter of §6.10, with a `main` that sends it `Inc` and `Get`. §6.10 shows `Upgrade` at work.

```ernest
type CounterMsg =
    Inc(Int)
  | Get(reply : Reply(Int))
  | Upgrade(migrate : (Int) -> Int, next : (Int) -> Unit with CounterMsg)

export fn main() : Unit with m = {
    let c = spawn(fn() = counter(0));
    send(c, Inc(5));
    send(c, Inc(3));
    match Address.call(c, fn(r) = Get(reply = r), 1000) {
        Some(n) -> Io.println("count is " <> Int.toString(n))
      | None -> Io.println("counter is not answering")
    }
}

fn counter(n : Int) : Unit with CounterMsg =
    receive {
        Inc(k) -> counter(n + k)
      | Get(reply = r) -> {
            answer(r, n);
            counter(n)
        }
      | Upgrade(migrate = m, next = k) -> k(m(n))
    }
```

Ping-pong. `main` starts `pong` under a monitor and `ping` beside it, and waits for `pong` to end. `ping` calls `pong` three times and then stops it.

```ernest
type PongMsg = Ping(n : Int, reply : Reply(Int)) | Stop

type MainMsg = PongDone(Down)

export fn main() : Unit with MainMsg = {
    let pongAddr = spawnMonitored(fn() = pong(), PongDone);
    let _ = spawn(fn() = ping(pongAddr, 3));
    receive {
        PongDone(_) -> Unit
    }
}

fn ping(pongAddr : Address(PongMsg), n : Int) : Unit with m =
    if n == 0 then
        send(pongAddr, Stop)
    else {
        Io.println("ping " <> Int.toString(n));
        match Address.call(pongAddr, fn(r) = Ping(n = n, reply = r), 5000) {
            Some(_) -> ping(pongAddr, n - 1)
          | None -> {
                Io.println("pong is not answering");
                send(pongAddr, Stop)
            }
        }
    }

fn pong() : Unit with PongMsg =
    receive {
        Ping(n = n, reply = r) -> {
            Io.println("pong " <> Int.toString(n));
            answer(r, n);
            pong()
        }
      | Stop -> Unit
    }
```

A message that carries a function. `submitter` is send-only, so its mailbox type is `Never`. Sent to a worker on another node, the message faults the sender (§3.11).

```ernest
type WorkerMsg = DoWork(f : (String) -> Bytes, arg : String)

fn submitter(worker : Address(WorkerMsg)) : Unit with Never = {
    send(worker, DoWork(f = String.toUtf8, arg = "hello"));
    send(worker, DoWork(f = String.toUtf8, arg = "world"))
}
```

## Appendix C. Configuration

`ernest.conf`, as created by `ern config` and then edited to name two peers:

```json
{
  "network-address": "145.32.64.6:8654",
  "public-key": "<PEM public key>",
  "peers": [
    {
      "name": "foo",
      "network-address": "145.32.64.7:8654",
      "public-key": "<PEM public key>"
    },
    {
      "name": "bar",
      "network-address": "145.32.64.8:8654",
      "public-key": "<PEM public key>"
    }
  ]
}
```

`Peer.spawn("foo", f)` and `Peer.spawn("bar", f)` spawn on these peers, §8.3. The private key is in the same directory, `private-key.pem`, readable only by its owner. A freshly created file has an empty `peers` list.

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

E.0 is normative; a function enters this appendix by its rules before it enters `stdlib/`. The listing that follows is what E.0 has admitted, the modules that ship with the compiler as ordinary Ernest files under `stdlib/`. A listing gives each function's type as an annotation writes it, without the inferred restrictions of §3.9: `ern doc` prints every restriction (§11.5). The standard library is on the load path by default; every program can call `Io.println`, `List.map`, and the rest without any setup. The prelude in §9 is what the language itself requires. Everything else here is written in Ernest on top of the language and prelude, except the shims that E.0's first rule admits.

### Appendix E.0. Rules

Four *admission rules* decide whether a function is in: rules 1 to 3 each admit a function, and rule 4 refuses one they would admit. None of them counts programs: a function enters when a rule admits it, whether or not a program has asked.

1. Its value is the runtime's: it reaches a representation the runtime owns, a table of the host's, its path syntax, Unicode's tables or the floating-point library's, or a process of the runtime's (§8.2, E.21, E.22), and each module's section names its *primitives*; in a system module, a function that reaches its process is a primitive, and the rest is Ernest over them. A type the language's syntax builds, a list, a tuple, a bitstring, is the language's, and a type only a module's functions build is the runtime's. A primitive is a shim over `foreign fn` or over a system process, and a shim exists only where this rule applies. The primitives are a few, and the rest of the module is Ernest over them; what the language owns, `[]` and `::` among it, is written in Ernest, `List.sort` among it. A primitive passes data out and calls no Ernest function but a wrap it delivers through (shape rule 8): `toList`, not `foldLeft`. Speed is not a reason for a shim. A primitive beneath an operation Ernest could write over the module's other primitives is admitted only where the Ernest form costs a multiple of the host's own, measured, with the numbers in the decisions log; it is private, and the operation stays Ernest over it. The rule decides how an operation is carried out, never what a value is: where a value's identity, lifetime, or failure is the program's concern, it is a process (§8.2), and no shim stands in for one.
2. It follows from the type's structure, and each kind of type has a vocabulary. The kinds below, a container, a sequence, text, a set, a map, have their vocabulary here; a type of another kind, a path, a filesystem, lists its own in its section. A container provides the container operations of the vocabulary below, or says in its section which it lacks and what stands in its place. Text and octets are containers read through `toList`, and provide the container operations their sections list. A sequence adds order and position: `reverse`, `sort`, `take`, `drop`, `dropLast`, `last`, `span`, `partition`, `unique`, `indexed`, `repeat`, `zip`, `unzip`, `flatMap`, `range`, and `tryMap` and `tryFold` for a step that can fail. Text adds `startsWith`, `endsWith`, `indexOf`, `lastIndexOf`, `replace`, `slice`, `padStart`, `padEnd`, `repeat`, `split`, `join`, `lines`, `words`, `trim`, `trimStart`, `trimEnd`, `toLower`, `toUpper`, and a `Char` `isUpper`, `isLower`, `toUpper`, `toLower`. A set adds `union`, `intersection`, `difference`, and `isSubset`. A map adds `keys`, `values`, and `merge`. A conversion to text has its inverse where the text form is unambiguous and the type has no other way in; a `Char` has `String.toList` and needs none. A type that enters by rule 3 still gets its structure's vocabulary, not only the functions the program wrote. A published specification, a date, a pattern language, a format, a protocol, is a library's and no module's vocabulary.
3. It is a general operation of the type, its definition is the obvious one, and no policy is buried in it: `List.foldRight`, `Float.sqrt`. A function whose result depends on a choice the library would be making for the program, a format, a locale, a tolerance, is refused whatever asks for it. A policy the program passes as an argument without a default is not buried: `Supervisor.group`'s strategy and limit. A choice the section states whole and a program could make otherwise, E.13's generator, is not buried, and neither is a text form the language's own literals read back. A constant of the type enters as an operation does.
4. It is not a composition. A function outside rule 2's vocabulary, shape rule 2's operations, and shape rule 3's conversions that is one call of a function already here, or a pipe of two, is not added: `List.concat` is `List.flatMap(xs, fn(x) = x)`, `List.sum` is `List.foldLeft(xs, 0, Int.+)`. The vocabulary is admitted whole, since a reader guesses its names in every module that has the operation, whether or not one of them composes others: `Map.contains` is in, though it is `isSome` of `get`. A pair is admitted whole as the vocabulary is: a predicate of a two-constructor type with the other constructor's, `isSome` and `isNone`, `isLeft` and `isRight`, a print with its line form, `print` and `println`, `printError` and `printlnError`, and a text operation with its bytes form, `print` and `write`, `readLine` and `read`. `Io.debug` is kept alone, since it stands where an expression stands.

Nine *shape rules* give a function its shape. Shape rules 1 to 4, 7, and 9 hold in a library outside the standard library too, as Appendix D's, which the four admission rules do not reach.

1. The subject comes first, callbacks last but for shape rule 8's milliseconds, an accumulator between them: `x |> f(a)` is `f(x, a)`. No aliases, no argument-order variants.
2. One verb per operation on each kind of type that has it, and a type alone of its kind names its own; a module whose operations serve two kinds names the second's with the kind, `closeListener`, `nextFloat`. The container operations are `empty`, `size`, `isEmpty`, `contains`, `get` for lookup by index or key, `put` for insertion, `remove`, `map`, `filter`, `filterMap`, `foldLeft`, `foreach`, `any`, `all`, `find`, `fromList`, and `toList`; the sum-type operations are `withDefault`, `map`, and `andThen`. A predicate is `isX`. `empty` is a value; a function that makes something which belongs to a process and ends, as G.1's table does, is `new`. `contains` on text finds a substring of any length, not an element, the empty text being in every text, and `size` on text counts graphemes, not the `Char`s `toList` gives (E.5). A verb not in this list names an operation none of these does.
3. A conversion is named by the other type. Between a type and one its module builds on, both directions are the building module's, `fromX` and `toX`: `String.fromList` and `String.toList`, `Map.fromList`, `Either.fromOptional`. Any other conversion is its argument's module's `toX`: `String.toInt`, `Int.toString`. A conversion exists once. When one conversion has several policies, the policy is the name: `Float.round`, `Float.floor`, `Float.ceil`, `Float.truncate`. A conversion of any value into a foreign type is `from`, since no type names its argument, and a function that makes a particular host term is named for the term, `Erl.atom`.
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

Output to standard output and standard error, and input from standard input, through the module's system references `stdout`, `stderr`, and `stdin` (§8.2). `Io.show` and `Io.debug` are the prelude's, §9.4; this module provides them. The primitives are `print`, `println`, `printError`, `printlnError`, `readLine`, `read`, `write`, and `writeError`, which reach the module's processes, and `show` and `debug`, which read a value's representation in the runtime (E.0 rule 1). `Error` is the error of every system module. `NotAFile` is a path that names something other than a regular file, and `Exists` a path that names something where nothing may stand. `NotUtf8(bytes)` is text that is not UTF-8, a name or a link's target among them, its bytes as they came. `Invalid` is an argument the host cannot take: one that holds U+0000, or a port out of range. `Other(text)` holds the host's description of its reason, `"address already in use"`; where the host has no description, it holds the reason as the host writes it.

```
type Error = NotFound | Denied | Refused | Closed | Timeout | NotATerminal | NotAFile | Exists
           | NotUtf8(Bytes) | Invalid | Other(String)
Io.print : (String) -> Unit with m
Io.println : (String) -> Unit with m // appends "\n"
Io.printError : (String) -> Unit with m // to standard error
Io.printlnError : (String) -> Unit with m // appends "\n"
Io.readLine : () -> Optional(String) with m // the next line without its line feed; None at end of input
Io.read : () -> Optional(Bytes) with m // what has arrived, at least one byte; None at end of input
Io.write : (Bytes) -> Unit with m // the bytes to standard output, as they are
Io.writeError : (Bytes) -> Unit with m // the bytes to standard error, as they are
```

`Io.show` writes a value by the argument's type at the call, each value as its literal or construction is written: a negative number with `-` before it, `-1`, a `Char` as `'a'`, `Bytes` as `<<104, 105>>`, a named constructor with its fields in their declared order (§3.5), `Snap(dir = "x", seen = 2)`. A `Map` prints as `Map.fromList` of its pairs, a `Set` as `Set.fromList` of its elements, in an order the values fix, so that equal maps and equal sets print alike: ascending where the keys or the elements are `Int`, `Float`, `Char`, or `String`. An address prints as `<address 84>`, the number naming the process behind it, and a `Process` as `<process 84>` (E.21). A function prints as `<function>`; no reply reaches `Io.show`, whose argument is no reply-carrying type (§6.6). `Io.show` and `Io.debug` write a value by the type at which the name is used, as a callee or an argument, which must be known there whole, with no type variable in it, more than an operator asks (§4.8): on a type variable it is a type error, and neither takes a hidden argument. An effect variable in the type is no matter, since a function is written `<function>`. A value of an abstract type outside its module is written as `<abstract>`, and a value of a foreign type as `<foreign>`. `Io.debug` writes `Io.show`'s text to standard error.

### Appendix E.2. `list.ern` (namespace `List`)

`[]` is `empty` and `::` is `put`, so neither is a function; `fromList` and `toList` are the identity and are not provided. `contains`, `remove`, and `unique` require equality on `a` (§3.10). `List.<>` is the prelude's, §9.6; this module provides it (§9).

```
List.size : (List(a)) -> Int
List.isEmpty : (List(a)) -> Bool
List.contains : (List(a), a) -> Bool
List.get : (List(a), Int) -> Optional(a) // by index from 0; None for a negative index or one at or past the end
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
List.dropLast : (List(a), Int) -> List(a) // all but the last n; n below 0 is 0
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

Requires equality on `k` (§3.10). The order of `keys`, `values`, `toList`, `foldLeft`, `foreach`, and `find` is unspecified, and so is the order in which `map`, `filter`, `filterMap`, `any`, `all`, and `mergeWith` meet the entries. The primitives are `empty`, `size`, `get`, `put`, `remove`, and `toList` (E.0 rule 1).

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
Map.mergeWith : (Map(k, v), Map(k, v), (k, v, v) -> v with e) -> Map(k, v) with e // for a shared key, the function of the key, the first's value and the second's
Map.fromList : (List(#(k, v))) -> Map(k, v) // a later pair wins
Map.toList : (Map(k, v)) -> List(#(k, v))
Map.keys : (Map(k, v)) -> List(k)
Map.values : (Map(k, v)) -> List(v)
```

### Appendix E.4. `set.ern` (namespace `Set`)

Requires equality on `a` (§3.10). A set has no `get`; membership is `contains`. The order of `toList`, `foldLeft`, `foreach`, and `find` is unspecified, and so is the order in which `map`, `filter`, `filterMap`, `any`, and `all` meet the elements. The primitives are `empty`, `size`, `contains`, `put`, `remove`, and `toList` (E.0 rule 1).

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
Set.intersection : (Set(a), Set(a)) -> Set(a)
Set.difference : (Set(a), Set(a)) -> Set(a) // the elements of the first not in the second
Set.isSubset : (Set(a), Set(a)) -> Bool // every element of the first is in the second
```

### Appendix E.5. `string.ern` (namespace `String`)

A `String` is a container read through `toList`: of the container operations it provides `size`, `isEmpty`, `contains`, `fromList`, and `toList`, and the rest go through `toList`. `size`, `slice`, `indexOf`, `lastIndexOf`, `padStart`, and `padEnd` count and index in graphemes, extended grapheme clusters, each what a reader sees as one letter, and `graphemes` gives them in order. A pad that begins no grapheme, a combining mark, joins the grapheme beside it, so `padStart` and `padEnd` then leave the string shorter than asked. `toList` and `fromList` are `Char`s, one scalar value each, so a string holding a combining mark has more `Char`s than graphemes. The primitives are `size`, `graphemes`, `indexOf`, `lastIndexOf`, and the slice `slice` makes once it has clipped its index and count, the operations that need Unicode's tables, with `drop`, the string after a count of graphemes, `trimStart`, `trimEnd`, `toLower`, and `toUpper`, the conversions `toFloat`, `toList`, `fromList`, `toUtf8`, and `fromUtf8`, and the reading in a base that `toIntBase` makes once it has checked the base and the sign, the slice, the string after a count and the reading being private to the module (E.0 rule 1). The rest is Ernest over them, so every search matches whole graphemes: `String.contains("e\u{301}", "e")` is `false`, and `String.split("a\r\nb", "\n")` is `["a\r\nb"]`, a carriage return and a line feed being one grapheme; text whose lines may end either way is read with `String.lines`. `trim`, `trimStart`, and `trimEnd` remove the graphemes whose first code point is White_Space, as `Char.isSpace` says. `toLower` and `toUpper` use Unicode's full case mapping without the rules that depend on a language or a context: `String.toUpper("ß")` is `"SS"`. `String.compare` orders by code point. It and `String.<>` are the prelude's, §9.6; this module provides them (§9).

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

The predicates use the Unicode properties of the code point: `isDigit` is general category Nd, `isAlpha` is category L, `isSpace` is White_Space, `isUpper` is Lu, `isLower` is Ll. `Char.compare` orders by code point; it is the prelude's, §9.6, and this module provides it (§9). The primitives are the predicates `isAlpha`, `isDigit`, `isLower`, `isSpace`, and `isUpper`, `toUpper`, `toLower`, `toString`, `toInt`, and the conversion `fromInt` makes once it has checked its code point, which is private to the module (E.0 rule 1); the rest is Ernest over them.

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
Optional.isSome : (Optional(a)) -> Bool
Optional.isNone : (Optional(a)) -> Bool
Optional.withDefault : (Optional(a), a) -> a
Optional.map : (Optional(a), (a) -> b with e) -> Optional(b) with e
Optional.andThen : (Optional(a), (a) -> Optional(b) with e) -> Optional(b) with e
```

### Appendix E.11. `either.ern` (namespace `Either`)

```
Either.isLeft : (Either(e, a)) -> Bool
Either.isRight : (Either(e, a)) -> Bool
Either.withDefault : (Either(e, a), a) -> a
Either.map : (Either(e, a), (a) -> b with x) -> Either(e, b) with x
Either.mapLeft : (Either(e, a), (e) -> b with x) -> Either(b, a) with x
Either.andThen : (Either(e, a), (a) -> Either(e, b) with x) -> Either(e, b) with x
Either.toOptional : (Either(e, a)) -> Optional(a)
Either.fromOptional : (Optional(a), e) -> Either(e, a)
```

### Appendix E.12. `foreign.ern` (namespace `Foreign`)

`Term` is the foreign type of any value of the runtime (§3.8). Its functions are primitives (E.0 rule 1).

```
foreign type Term
Foreign.from : (a) -> Term // the value as the runtime holds it (§8.4)
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

`Path` is `Path(String)`, §9.3, in the runtime's syntax. `Path.<>` is the prelude's, §9.6; this module provides it (§9). The primitives are `isAbsolute` and `separator`, the host's separator, which is private to the module (E.0 rule 1); the rest is Ernest over `String`.

```
Path.join : (List(String)) -> Path // the segments as a path, the inverse of split: a root first stays a root, one separator between the others
Path.split : (Path) -> List(String) // the segments; an absolute path's first is the root
Path.parent : (Path) -> Optional(Path) // None for a bare name or the root
Path.name : (Path) -> Optional(String) // the last segment, None for the root, which has none
Path.extension : (Path) -> Optional(String) // after the last "." of the name, without it; the dots that begin the name begin none
Path.withExtension : (Path, String) -> Path // replaced or added, the rest as written; an empty one leaves the dot; the root, "." and ".." are left as they are
Path.withoutExtension : (Path) -> Path // removed, the rest as written; the root, "." and ".." are left as they are
Path.isAbsolute : (Path) -> Bool
Path.toString : (Path) -> String
```

### Appendix E.15. `clock.ern` (namespace `Clock`)

Over the clock's system reference (§8.2). Times are milliseconds since the epoch, by the host's clock, which may be set while the program runs. `monotonic` is milliseconds since a moment the runtime chose, and never goes back. The difference of two readings of `monotonic` is the time the host ran between them: where the host's monotonic clock stops while the machine is suspended, that time is left out. The difference of two `now`s is not that time when the clock is set between them. An alarm after milliseconds counts them as `monotonic` does, and setting the clock does not move it. An alarm at a time fires when the clock reaches the time, though the clock is set before it fires: a clock set past the time fires it once the host reports the change, and a clock set back delays it. An alarm fires once, and a program cannot cancel it: a process that no longer wants it ignores the message, and a periodic tick is scheduled after the previous one is handled. A restart of the process that set it cancels it (§6.9).

```
Clock.now : () -> Int with m
Clock.monotonic : () -> Int with m
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
Terminal.size : () -> Either(Io.Error, Size) with m // the terminal's size now; Left(NotATerminal) where standard output is not a terminal
Terminal.columns : (String) -> Int // the columns the text takes at a terminal: an escape sequence none, a wide or emoji grapheme two, a grapheme only of combining marks, format characters and controls none
```

### Appendix E.17. `fs.ern` (namespace `Fs`)

Over the file system's system reference (§8.2). The last argument is the milliseconds to wait. A `Left(Timeout)` does not undo the request: a write, a rename or a removal that answered it may still take place. A relative path names a file under the working directory, `Os.workingDirectory` (Appendix E.23). A path that holds U+0000 names no file, and each function answers `Left(Invalid)` for it. `read`, `readRange`, `write`, `append`, and `copy` work on regular files: a path that names anything else, a directory, a named pipe, a device, or a socket, answers `Left(NotAFile)`. The path `write` and `append` take, and the second path of `copy`, may name nothing, and the file is then created. A function follows the symbolic links of the paths it is given, but for a path's last segment where it names a link: `list` describes each entry as it is, a link as a `Link`, and `remove`, `rename`, and `readLink` act on the link itself. Each `Other` in an answer here is `Io.Error`'s, which says why, and not `Kind`'s, which is a kind of entry. `makeLink`, `makeHardLink` and `makeFile` answer `Left(Exists)` where the path they make names something, and `readLink` answers `Right(None)` for a path that names anything but a link and `Left(NotUtf8(target))` for a link whose target is not. `makeHardLink` makes a second name for a regular file: a second path that names anything else, a link among them, answers `Left(NotAFile)`. `removeAll` faults its caller where the runtime's helper fails, as `Os.start` does (Appendix E.23). `removeAll` walks a directory by the directories it has opened, never by a path: each entry is opened refusing a link and removed from its directory, so that a directory another process replaces with a link while the walk runs leads it nowhere else. It waits the milliseconds it is given once, for the whole removal.

```
type Kind = File | Directory | Link | Other // Other: a named pipe, a device, or a socket
type Entry = Entry(path : Path, mtime : Int, size : Int, kind : Kind) // mtime in milliseconds since the epoch, as Clock.now, read to the second and so a multiple of 1000; size in bytes
Fs.read : (Path, Int) -> Either(Io.Error, Bytes) with m // the whole file, however large; readRange reads a file of a size the program does not trust in parts
Fs.readRange : (Path, Int, Int, Int) -> Either(Io.Error, Bytes) with m // up to count bytes from offset, fewer at the end of the file and none past it; an offset or a count below 0 is none
Fs.write : (Path, Bytes, Int) -> Either(Io.Error, Unit) with m // creates or replaces
Fs.append : (Path, Bytes, Int) -> Either(Io.Error, Unit) with m // creates or extends
Fs.list : (Path, Int) -> Either(Io.Error, List(Entry)) with m // the entries of a directory but `.` and `..`, in unspecified order, each entry's path the directory's path joined with the entry's name, each described as it is; a name that is not UTF-8 answers `Left(NotUtf8(name))`, the first such in the order of their bytes (§8.2), and an entry gone before it is described is left out
Fs.stat : (Path, Int) -> Either(Io.Error, Entry) with m // what the path leads to, its links followed
Fs.makeDir : (Path, Int) -> Either(Io.Error, Unit) with m // with its missing parents; an existing directory is not an error
Fs.remove : (Path, Int) -> Either(Io.Error, Unit) with m // a file, a link, or an empty directory
Fs.rename : (Path, Path, Int) -> Either(Io.Error, Unit) with m // the first to the second
Fs.copy : (Path, Path, Int) -> Either(Io.Error, Unit) with m // a file, the first to the second; replaces
Fs.makeLink : (Path, Path, Int) -> Either(Io.Error, Unit) with m // a symbolic link at the first path to the second, which may name nothing
Fs.makeHardLink : (Path, Path, Int) -> Either(Io.Error, Unit) with m // a hard link at the first path to the regular file the second names, a second name for it
Fs.readLink : (Path, Int) -> Either(Io.Error, Optional(Path)) with m // the path a symbolic link holds, as it was written
Fs.makeFile : (Path, Bytes, Int) -> Either(Io.Error, Unit) with m // a new file, or none where the path names something
Fs.removeAll : (Path, Int) -> Either(Io.Error, Unit) with m // a directory and everything under it, or a file or a link; a link is removed, not followed
Fs.setModified : (Path, Int, Int) -> Either(Io.Error, Unit) with m // the modification time, in milliseconds since the epoch, kept to the second
Fs.setMode : (Path, Int, Int) -> Either(Io.Error, Unit) with m // the permission bits, as the host writes them, 0o600; a mode outside 0 to 0o7777 is Left(Invalid)
```

### Appendix E.18. `tcp.ern` (namespace `Tcp`)

Over TCP's system reference (§8.2). A socket is a process: its address can be sent, monitored, and killed like any other. Sockets and listeners are foreign processes (§8.4) but not system processes, so `Process.live`, `Process.info` and `Process.faults` include them. The site of a listener is `Tcp.listen`, and of a socket `Tcp.accept` or `Tcp.connect`, the function that opened it (§6.9), with no line, since the runtime opened it. It is owned by the process that opened it, the caller of `listen`, `accept` or `connect`, and `give(socket, process)` makes another a socket's owner. It lives until `Tcp.close`, until it is killed, until its owner dies, which kills it as a running program's is killed (Appendix E.23), or until the program ends; a socket given to a process that has ended is killed at once, and a restart is no death (§6.9). After its connection closes, from either end or by a failure, each `Tcp.read` answers `Left(Closed)`. A listener lives until `Tcp.closeListener`, until it is killed, until its owner dies, or until the program ends; closing it answers an `accept` waiting on it with `Left(Closed)`. `close` and `closeListener` answer each read or accept the socket or the listener has taken and holds waiting with `Left(Closed)` and end its process; `kill` ends it as it ends any process, a call waiting on it faulting as §6.6 says, and the host's socket closes either way. On a socket or a listener that has ended, a function that waits for its answer, `read`, `write`, `accept`, `port`, `remote`, or `local`, faults the caller as `Address.callForever` does (§6.6): with `Fault("callee was closed")` where the program's close ends it while the call waits in its mailbox, not yet taken, and with `Fault("callee had ended")` where it had ended before the call; `close`, `give` and `closeListener` do nothing. `Tcp.write` answers `Right(Unit)` once the socket has taken the bytes, which does not mean that the far end has them, and waits while the connection is behind, at most the milliseconds it is given; a write that waits holds up no read of the socket. A `Left(Timeout)` does not undo the write: the bytes may still be sent, after those written before. A write after the connection has closed, from either end or by a failure, answers `Left(Closed)`, and one the host refuses for another reason answers `Left(Other(text))`, the host's reason. A port outside 0 to 65535, and a host that holds U+0000, which names none, answer `Left(Invalid)`. A read, an accept, or a connect that times out has taken nothing: bytes that arrive later wait for the next read, and a connection that completes later is closed. There are no options; framing is bitstrings (§5.11). The last argument of a function that waits is the milliseconds.

```
abstract type ListenerMsg // what a listener takes
abstract type SocketMsg // what a socket takes
type Endpoint = Endpoint(host : String, port : Int)
Tcp.listen : (String, Int) -> Either(Io.Error, Address(ListenerMsg)) with m // host, port: the interface the host's name or address names, `"127.0.0.1"` the loopback alone and `"0.0.0.0"` or `"::"` every one; port 0 asks the system for a free one
Tcp.port : (Address(ListenerMsg)) -> Either(Io.Error, Int) with m // the port it listens on
Tcp.accept : (Address(ListenerMsg), Int) -> Either(Io.Error, Address(SocketMsg)) with m
Tcp.connect : (String, Int, Int) -> Either(Io.Error, Address(SocketMsg)) with m // host, port
Tcp.read : (Address(SocketMsg), Int) -> Either(Io.Error, Bytes) with m // what has arrived, at least one byte
Tcp.write : (Address(SocketMsg), Bytes, Int) -> Either(Io.Error, Unit) with m
Tcp.close : (Address(SocketMsg)) -> Unit with m
Tcp.give : (Address(SocketMsg), Process) -> Unit with m // makes the process the socket's owner
Tcp.closeListener : (Address(ListenerMsg)) -> Unit with m // stops listening
Tcp.remote : (Address(SocketMsg)) -> Either(Io.Error, Endpoint) with m // the connection's far end
Tcp.local : (Address(SocketMsg)) -> Either(Io.Error, Endpoint) with m // the connection's near end
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

`Process` is the prelude's (§9.1), and this module provides its operations. A `Process` is the identity of a process. It has equality and no ordering, exact as §3.10 says, and nothing can be sent to it. Across nodes a `Process` names its node. `info` is a snapshot of a live process, which may have changed when it is read. It answers `None` for a process that has ended (§6.9) and for one on another node. `live` answers the processes the runtime started that have not ended, the system processes excepted: those a program spawned, and a listener, a socket or a running program a system module opened (Appendix E.18, E.23). `faults(wrap)` delivers `wrap(r)` to the caller for every fault of every process the runtime started, the system processes' excepted, as E.0 shape rule 8 says of a function that delivers later. A process holds one subscription to faults, beside one to the terminal (§8.2): a second call replaces the first, its wrap from then on, and a subscription ends when its process dies or restarts (§6.9). A subscription to faults is no source that can deliver under §8.6. In a `FaultReport`, `restarted` is `true` where the process restarts after the fault (§6.9), and `trace` is the host's stack beneath a failure in the runtime or a foreign function's raise, a function to a line, and empty beneath a cause of §7.4.

```
type Info = Info(site : String, queued : Int, activity : Activity)
type Activity = Running | Receiving | Calling
type FaultReport = FaultReport(process : Process, site : String, cause : String, restarted : Bool, trace : String)
Process.fromAddress : (Address(m)) -> Process // the process behind the address, through every via
Process.info : (Process) -> Optional(Info) with m // its spawn site (§6.9), the messages in its mailbox, and whether it runs, waits in a receive, or waits for a call's answer; None once it has ended
Process.live : () -> List(Process) with m // in unspecified order
Process.faults : ((FaultReport) -> m) -> Unit with m // every fault from now on, wrapped, in the caller's mailbox
```

### Appendix E.22. `supervisor.ern` (namespace `Supervisor`)

A supervisor restarts a group of processes, its children, together. The primitives are `askRestart`, the restart a supervisor asks of a child, `spawnOrder`, the order in which the children were spawned, and `startCause`, why a restarting function began, each private to the module (E.0 rule 1); the rest is Ernest over them and the prelude. `group(strategy, limit)` spawns the process that keeps the group's children, which a supervisor's restart does not end, and answers the function a supervisor runs; the first process that runs it is the group's supervisor, and another that runs it, while the first runs or after it has ended, faults with `Fault("a group runs in one process")`. `child(supervisor, f)` is the function a child runs. The caller spawns the supervisor and each child: a child's site (§6.9) and its place are the caller's, and a service binding names it (§6.5). A child joins the group when it starts, before `f` runs, and waits until the supervisor has it; a child whose supervisor has ended faults with `Fault("the supervisor has ended")`. A supervisor and its children run on one node: a child whose supervisor is on another node faults with `Fault("a child runs on its supervisor's node")` before it joins, and between nodes a process watches another with `monitor`. After a fault it runs `f` again in place, as `restarting` does (§6.9), until the group gives up; its supervisor counts the fault before `f` runs again. A child at whose fault the group gives up runs nothing more until the group's end kills it or the supervisor, restarted in place, restarts it; one whose supervisor has ended by then is killed as the group's end kills the others. A child joins at any time, and a child that returns or is killed leaves the group. The strategy says what else a child's fault restarts: `OneForOne` nothing, `OneForAll` every other child, and `RestForOne` the children spawned after it, in the order the runtime spawned their processes, whatever order they joined in. Those are restarted as §6.9 says of a restart a supervisor asks for. A child that has not yet begun its first run of `f` is not asked, and one that faults before it takes the restart has restarted by its fault. The child whose fault restarts them runs `f` again once each of them has restarted or ended, so that a call to it after its fault is answered by the group restarted whole. A sibling that computes without waiting takes no restart until it waits (§6.9), and the child waits with it. When the children's faults pass `limit`, counted as `restarting` counts them, the supervisor faults with `Fault("supervisor restart limit reached")`. A supervisor that is itself a child restarts in place, after its own fault or when its parent asks, and asks each of its children to restart; they keep their order. When a supervisor dies, killed, faulted, or of a defect of its own, a process the module spawns beside it kills its children in the reverse of the order they were spawned, each once the one before has ended, and `kill(sup)` stops a group.

```
type Strategy = OneForOne | OneForAll | RestForOne
abstract type Msg // what a supervisor takes
Supervisor.group : (Strategy, RestartLimit) -> (() -> Unit with Msg) with m
Supervisor.child : (Address(Msg), () -> Unit with m) -> (() -> Unit with m)
```

### Appendix E.23. `os.ern` (namespace `Os`)

Over Os's system reference (§8.2). `arguments` is the words after the module on `ern run`'s command line (§11.2), and `workingDirectory` is the absolute path of the directory the program was started in, each bound when the program starts. Nothing in Ernest changes the working directory. A relative path given to `Fs`, or as a program's name to `start`, is resolved against it. A working directory the host can no longer read as the program starts, one removed since, faults `workingDirectory`'s initializer, which ends every program before `main` runs (§7.4, §8.5). `environment(name)` answers the value of the program's environment variable of that name, or `None` where the host has none. The environment is read once, when the program starts, and a value is decoded when it is asked for: one that is not UTF-8 faults the caller with `Fault("the environment variable n is not UTF-8")`, `n` its name. A name that occurs twice keeps its first value. `exit(status)` ends the program as §8.6 ends it, with that status, and does not return; a status outside 0 to 255 faults the caller (§7.4). In the shell and under `ern test` it faults the caller instead (§11.2).

`start(command)` starts a program of the host and answers its address. A running program is a process, as a `Tcp` socket is: `kill` stops it and `monitor` watches it, and its site is `Os.start`. The program is found as the host finds a command: a name without `/` in the directories of `PATH`, and a name with `/` as the path it is. Each argument reaches the program as it is, with no shell between. The program inherits the runtime's whole environment and its working directory. It does not share the runtime's standard input: its standard input is `input`, then what `write` gives it, until `closeInput` ends it. A `write` after that, or once the program has closed its standard input or has exited, answers `Left(Closed)`, and its bytes are dropped.

`read(program, ms)` answers the next piece of what the program wrote, `Stdout(bytes)` or `Stderr(bytes)`, in the order the host delivered them, and last `Exited(status)`, once the program has exited and its standard output and standard error have both ended. The host takes the program's output only while a read waits, so a program that no one reads waits on its output. A status other than 0 is answered as `Exited(status)`, not as a `Left`; a program ended by a signal has 128 plus the signal's number as its status. When `ms` milliseconds pass first, `read` answers `Left(Timeout)`, the program running on, and what it writes meanwhile is the next read's. A program runs until it exits or is killed: a run is bounded as any process is, by an alarm and `kill` (§6.9). A program is killed when its process is killed. Its process is owned by the process that called `start`, and `give(program, process)` makes another its owner; it is killed when its owner dies, a program given to a process that has ended at once, and a restart is no death (§6.9). The processes the program started that are still in its process group are killed with it. `write(program, bytes, ms)` answers `Right(Unit)` once the program has taken the bytes, and waits while it is behind, at most `ms` milliseconds; a `Left(Timeout)` does not undo the write. The program's process ends once it has answered `Exited`. A read or a write after its end faults as `Address.callForever` does on an ended process (§6.6), and `closeInput` does nothing.

`start` answers `Left(NotFound)` when the program is not found, `Left(Denied)` when it may not be run, and `Left(Other(text))`, the host's reason, when it cannot start for another. A name or an argument that holds U+0000 cannot reach a program, and `start` answers `Left(Invalid)` for it. Where the runtime's helper fails, as the program starts or later, the failure is the runtime's own (§7.4): the caller of `start`, `read`, or `write` faults with `Fault("the runtime's helper ern_exec failed")`, and a failure as the environment is read ends the program before `main` runs (§8.5).

`run(command, ms)` starts the program, ends its input after `input`, and reads it to its end within `ms` milliseconds of the start: it answers the exit status and all the program wrote to its standard output and to its standard error, the `Left` that `start` or a read answered, or `Left(Timeout)` when the milliseconds pass, the program killed then.

```
type Command = Command(program : String, arguments : List(String), input : Bytes)
type Output = Stdout(Bytes) | Stderr(Bytes) | Exited(Int)
type Finished = Finished(status : Int, stdout : Bytes, stderr : Bytes)
abstract type ProgramMsg // what a running program takes
Os.arguments : List(String)
Os.environment : (String) -> Optional(String) // the variable's value, None where there is none
Os.workingDirectory : Path
Os.exit : (Int) -> a with m
Os.start : (Command) -> Either(Io.Error, Address(ProgramMsg)) with m
Os.read : (Address(ProgramMsg), Int) -> Either(Io.Error, Output) with m
Os.write : (Address(ProgramMsg), Bytes, Int) -> Either(Io.Error, Unit) with m
Os.closeInput : (Address(ProgramMsg)) -> Unit with m
Os.give : (Address(ProgramMsg), Process) -> Unit with m // makes the process the program's owner
Os.run : (Command, Int) -> Either(Io.Error, Finished) with m
```

### Appendix E.24. `test.ern` (namespace `Test`)

A top-level `let` of type `Test.Case` is a test, which `ern test` runs (§11.2). Its `run` answers `Passed`, or `Failed` with what went wrong. The module declares these two types and no function.

```
type Case = Case(name : String, run : () -> Result with Never)
type Result = Passed | Failed(String)
```

## Appendix F. Glossary

Every technical term this report introduces, with a gloss and the section that defines it; the section is normative.

- **abstract type** — a sum type whose constructors are visible only in the module that declares it. §3.6, §4.4.
- **adapted address** — an address `via` makes, whose function turns what is sent to it into the target's message. §6.5.
- **address** — `Address(m)`, a reference to a process that receives values of type `m`. §3.7, §6.5.
- **admission rule** — one of the four rules that decide whether a function enters the standard library. Appendix E.0.
- **`after`** — the last clause of a `receive`, taken when no message arrives within its time. §6.3.
- **arity** — the number of arguments a function takes; part of its type. §3.4.
- **`as`** — `p as x`, a pattern that binds `x` to the whole value `p` matches. §5.10.
- **binding** — a `let` in a block, `let p = e` or `let p <- e`. §4.6, §5.5.
- **bitstring** — a bit-level value or pattern `<<...>>` that produces or matches a `Bytes` value. §5.11.
- **block** — `{ s1; s2; e }`, statements separated by `;`, whose value is its last. §5.4.
- **build root** — the directory a build writes its `.erc` files under, `--build-root`, mirroring the source root. §11.1.
- **`Bytes`** — the type of an octet sequence. §3.1.
- **cause** — the text a fault carries, `Fault(cause)`, which `Down` and a fault report give; §7.4 lists the language's. §7.3, §7.4.
- **child** — a process of a `Supervisor`'s group, which its supervisor restarts. Appendix E.22.
- **clause** — one pattern-branch of a `match` or `receive`. §5.9, §6.3.
- **code replacement** — a running process going on in a new function it received in a message. §6.10.
- **compare** — the per-type function that produces `Ordering`. §3.10.
- **compiled interface** — what a compiled module records of what it exports, their types and schemes, against which a module that uses it is checked. §3.9, §11.1.
- **concat operator** — `<>`, resolved per type. §4.8.
- **configuration directory** — the directory that holds a node's `ernest.conf`, its private key, and its `startup` file, `./.ernest` unless `--config-dir` names another. §11.2, §11.3.
- **cons operator** — `::`, list-prepend, right-associative. §3.3, §5.10.
- **constructor** — a case of a sum type; a value, a function, or a construction form. §3.5, §5.6.
- **consumed** — of a reply-carrying value: answered, or handed on by one of the uses §6.6 lists, exactly once on every path. §6.6.
- **container** — a type of the kind that holds elements and provides the container operations, a list, a map, a set. Appendix E.0.
- **content addressing** — naming a definition or type by the hash of its content. §8.7.
- **deadlock** — no process can progress. §8.6.
- **diagnostic** — an error the toolchain reports at a place in the source: its message, the source with the span underlined, its labels, and at most one help line. §11.5.
- **doc block** — consecutive `///` lines, read as CommonMark. §2.2.
- **doc comment** — `///`, not followed by a fourth `/`, to end of line; attached to the following declaration. §2.2.
- **effect polymorphism** — a mailbox effect that is a type variable. §3.9.
- **effect position** — the type after `with` in a function type. §3.9.
- **entry point** — the function run in the entry process: the module's `export fn main`, or the function `--main` names. §8.1, §11.2.
- **entry process** — the process that runs the entry point. §8.1, §8.6.
- **equality constraint** — the restriction on a type variable compared with `==`, or on a foreign type's parameter written `k=`. §3.10, §4.7.
- **fault** — a process death with the reason `Fault(cause)`. §7.3, §7.4.
- **field selection** — `e.f`, the named field `f` of `e`, where every constructor of the type has it. §3.5.
- **foreign address** — an address foreign code gave that names no process of the program; what is sent to it crosses into foreign code. §8.4.
- **foreign function** — declared `foreign fn`; body is a string reference to a runtime implementation. §4.7.
- **foreign process** — a process foreign code runs, whose messages are checked where they are delivered. §8.4.
- **foreign type** — declared `foreign type T`; values are made and used only by foreign functions. §3.8, §4.7.
- **generalization** — quantifying free type variables in a `fn` definition, a top-level `let`, or a block `let` that binds a lambda. §3.9, §4.6.
- **grapheme** — an extended grapheme cluster, what a reader sees as one letter, which `String`'s sizes and indices count. Appendix E.5.
- **group** — the processes a `Supervisor` restarts together, its children. Appendix E.22.
- **guard** — a `when` expression on a `match` or `receive` clause. §5.9.
- **guard expression** — the form of a `receive` guard. §6.3.
- **Hindley-Milner** — the type system Ernest uses; inference asks for an annotation only where §3.9 says. §3.9.
- **inferred restriction** — the equality constraint, process-only, or not-reply-carrying, inferred from a body; where there is none, written on a foreign type's parameter or given by §4.7 and §9. §3.9.
- **irrefutable pattern** — a pattern that cannot fail. §5.10.
- **`kill`** — `kill(a)`, ends the process `a` names with the reason `Killed`. §6.9, §9.5.
- **lambda** — an anonymous function, `fn(x) = e`. §5.3.
- **line mode** — the shell reading lines and editing none, when its input or output is not a terminal. §11.2.
- **literal** — a token that stands for an `Int`, `Float`, `Char`, `String`, or `Bool` value. §2.5.
- **live region** — the shell's rows below what it has written, where the line being typed stands. §11.2.
- **load path** — the roots a program's modules are found under by their namespaces, the standard library's among them. §11.1, §11.2.
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
- **or-pattern** — patterns joined by `or` in one clause, which matches when any of them does. §5.9.
- **owner** — the process that opened a resource or was given it, with which the resource ends. §6.9, Appendix E.18.
- **pattern** — decomposes a value and binds its parts. §5.10.
- **peer** — another node the runtime knows by name. §6.2, §8.3.
- **pipe** — the `|>` operator, `x |> f` = `f(x)`. §5.7.
- **positional field** — a field on a constructor identified by position, not name. §3.5.
- **precedence** — the binding tightness of a binary operator. §2.6.
- **prelude** — the small set of names the language requires to exist. §9.
- **`Prelude`** — the prelude's own namespace, `Prelude.Some`, for a name a module has shadowed, and the way past a member of the module's own to a name of the prelude's or the standard library's namespaces, `Prelude.List.<>`. §4.2.
- **primitive** — an operation beneath what Ernest writes: the language's, a built-in function of §9; a standard library module's, one that reaches a representation the runtime owns or a syntax the host owns, the rest of the module being Ernest over its primitives. §0, Appendix E.0.
- **process** — an execution of a function with a mailbox. §6.
- **`Process`** — the identity of a process, with equality; nothing can be sent to it. §6.5, Appendix E.21.
- **process-only** — a function whose effect variable cannot be pure. §3.9.
- **pure function** — a function without a mailbox type; result depends only on arguments. §0, §6.1.
- **qualified name** — a name with a dotted namespace prefix, `Net.Http.parse`. §2.3, §4.2.
- **raw string** — a `String` literal between backquotes, its text taken as written. §2.5.
- **`receive`** — a match over the mailbox. §6.3.
- **record update** — `C(..p, f = v)`, a construction whose unlisted fields are `p`'s. §5.6.
- **redundant** — of a clause or an alternative: able to match no value those before it leave. §5.9.
- **remote computation** — work on a peer: a process spawned there. §6.7.
- **`Reply(a)`** — a one-shot address for the answer to a request. §3.7, §6.6.
- **reply-carrying** — a type that transitively contains a `Reply`. §6.6.
- **request-reply** — `Address.call` sends a request that carries a `Reply`, and the callee answers it with `answer`. §6.6.
- **reserved word** — a word the grammar keeps for itself. §2.4.
- **restart** — `restarting`'s run of its function again after a fault, or when a `Supervisor` asks, in the same process with its address, its mailbox emptied. §6.9.
- **restart limit** — `RestartLimit(restarts, within)`, how many faults a restarting function or a group takes within a time, or `Unlimited`. §6.9, Appendix E.22.
- **rigid** — of a type variable an annotation names, which means every type. §3.9.
- **runner** — what `ern run`, `ern test` and `ern shell` start: it starts the system processes and calls the entry point. §11.2.
- **runtime** — the system that runs Ernest programs. §10.
- **scrutinee** — the value a `match` matches. §5.9.
- **segment** — a part of a qualified name between dots (§4.2), of a bitstring (§5.11), or of a path (Appendix E.14).
- **selector** — `.f` after a value, selecting its field `f`. §3.5.
- **`self`** — `self()`, the current process's own address. §6.2.
- **`send`** — `send(a, v)`, places `v` in the mailbox of `a`. §6.2.
- **sequence** — a container with order and position, a list, whose vocabulary adds `reverse`, `take` and the rest. Appendix E.0.
- **service** — a top-level binding that holds a process's address. §6.5.
- **shape rule** — one of the nine rules that give a function of the standard library its shape. Appendix E.0.
- **shim** — a primitive written as a `foreign fn` over the host or as a request to a system process. Appendix E.0.
- **source root** — the directory under which a file's path gives its namespace. §4.2, §11.1.
- **span** — a stretch of source a diagnostic underlines, the erroneous one with `^` and one the message depends on with `-` and its label. §11.5.
- **`spawn`** — `spawn(f)`, starts a new process; `spawnMonitored(f, wrap)` starts one monitored from its start. §6.2.
- **spawn site** — the top-level declaration and the line a process was spawned at, `Counter.main:19`, which `Down` and a fault report give. §6.9.
- **standard library** — the modules under `stdlib/`, on the load path by default; not the prelude. §9, Appendix E.
- **startup file** — a file of the shell's inputs, run when the shell starts. §11.2.
- **statement** — a part of a block, an expression, a `let`, or a `fn`. §5.4.
- **strategy** — what a `Supervisor`'s group restarts when a child faults. Appendix E.22.
- **structural equality** — the meaning of `==`; two values are equal when they are built by the same constructor from equal parts. §3.10.
- **subscription** — a process's standing request to the terminal for its events or to the runtime for its faults, ended when the process dies or restarts. §8.2, Appendix E.21.
- **sum type** — a type with one or more constructors. §3.5.
- **supervisor** — a process that restarts a group of processes, its children, together; the standard library's `Supervisor`. Appendix E.22.
- **system module** — the standard library module that holds a system reference, through which a program uses it. §8.2, Appendix E.0.
- **system process** — a process the runtime starts and keeps, its implementation foreign, its address a system reference. §8.2, §8.4.
- **system reference** — a system process's address, a private top-level binding of its system module that the runtime binds. §8.2.
- **tail position** — a function's body, and the branches, clause bodies, and last block expressions within it. §10.
- **taken namespace** — a namespace of the prelude or the standard library, which no other module may provide. §4.2.
- **top-level binding** — a value bound at file scope by a `let`. §4.6, §8.5.
- **tuple** — a positional product, `#(a, b)`, `#(a, b, c)`. §3.2.
- **type member** — a name declared with its type's prefix, `fn Distance.+`, in the type's nested namespace. §4.2.
- **type scheme** — a type with its quantified variables and their inferred restrictions, as a generalized binding has. §3.9.
- **type variable** — a lowercase identifier in type position; universally quantified in a `fn` or a top-level `let`. §3.9.
- **`Unit`** — the type with the single value `Unit`. §3.1, §9.3.
- **value position** — an argument, a result, a tuple component, or a type argument whose parameter occurs in a value position of its type's fields. §3.9.
- **`via`** — `via(addr, f)` is the address `addr` seen through `f`. §6.5, §9.5.
- **vocabulary** — the operations a kind of type provides by its structure, named alike in every module that has them. Appendix E.0.
- **wildcard** — the pattern `_`; matches anything, binds nothing. §2.3, §5.10.
- **`with`** — the mailbox-type marker on a function type, `with M`. §3.4, §6.1.

## Appendix G. Libraries

Informative. The libraries this project writes, each a directory under `libs/` and a source root of its own, which a program adds to its load path when it is compiled and when it is run (§11.1, §11.2). None is part of the language or of the standard library. Each follows the shape rules E.0 holds a library to and documents itself as shape rule 6 asks. A library written elsewhere follows Appendix D and is not listed here.

### Appendix G.1. `libs/ets` (namespace `Ets`)

Tables of the runtime, Erlang's `ets` tables of type `set`, which Appendix D shows with a shorter documentation. A table holds a value of type `v` at each key of type `k`, and keys are compared as the runtime compares its terms. A table belongs to the process that made it and ends with that process or with `close`, and every operation on a table that has ended faults, as a foreign function that raises does (§7.4). Any process on the node that holds a table reads and writes it, so every operation on one, a read too, carries `with m` (§4.7). `put` replaces the entry a key had, `remove` of a key that is not there does nothing, `clear` leaves the table empty, and `toList` answers the entries in unspecified order.

```
foreign type Table(k=, v)
Ets.new : () -> Table(k, v) with m
Ets.put : (Table(k, v), k, v) -> Unit with m
Ets.get : (Table(k, v), k) -> Optional(v) with m
Ets.contains : (Table(k, v), k) -> Bool with m
Ets.remove : (Table(k, v), k) -> Unit with m
Ets.size : (Table(k, v)) -> Int with m
Ets.clear : (Table(k, v)) -> Unit with m
Ets.close : (Table(k, v)) -> Unit with m
Ets.toList : (Table(k, v)) -> List(#(k, v)) with m
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
