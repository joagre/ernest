# Ernest Report: The Language

Revision of 8 October 2026.

This file holds the report's §0 to §10 and Appendices A, B and F. §11 and Appendix C are in [`toolchain.md`](toolchain.md), and Appendices D, E and G in [`library.md`](library.md). The three files are one report, and each is normative.

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
- [Appendix A. Grammar](#appendix-a-grammar)
- [Appendix B. Examples](#appendix-b-examples)
- [Appendix F. Glossary](#appendix-f-glossary)
<!-- /contents -->

## 0. Introduction

Ernest is a functional language for concurrent programs. It has two concepts: functions, with Hindley-Milner types, and processes with typed mailboxes, the only way to affect the world. Everything else in this report is a rule for how the two show up in each other.

Every function runs inside a process, an execution of a function with a mailbox that receives values of one type. A function that sends, receives, or asks for its own address acts through its process and names its mailbox in its type, `(A) -> B with M`; that is the only mark written on a function type. A function that does not act through its process is pure: its result depends only on its arguments, and it affects nothing. §3 and §6 make this precise; §10 states what the runtime must provide.

Five principles. Principles 2 to 5 are constructive; when following them yields code that surprises, principle 1 overrides.

1. Least surprise decides. A design surprises when a reader who knows the rest of Ernest would predict different code from the same requirement. The resulting code decides, not the rule. The reader knows Ernest first. Where Ernest's own rules do not decide, the reader knows types as Standard ML and OCaml have them, and values and processes as Erlang has them, and no other language; a form is not admitted because another language has it. Where Ernest departs from what that reader predicts, the report states the departure as a rule.
2. One way, one job, in the language and prelude. No variants for the same thing, no two concepts that overlap. The standard library may pair functions for convenience. A second spelling of what the language already writes enters only where the first would nest where the reader reads a sequence, repeat a body, rebuild what a pattern already holds, or pair each of a record's fields with the declaration of the same name in one namespace; one that only shortens stays out. A literal form enters where the reader of principle 1 predicts it.
3. Nothing invisible. Control flow, communication, and failure are visible in the code or in the type. A top-level binding is visible when its name appears at the use site, or, in a fill, when the use site names its namespace and the record's declaration names its field (§5.6). A rule the type decides is checked when the program is compiled; one the value decides is a value, a message, or a fault when it runs (§7). The compiler refuses what the text alone shows can have no effect, a value dropped, a clause that cannot run, and accepts what the text shows only unused; there is no warning. Where a check refuses a program that would run, the rule is stated and its error names what to write.
4. Simple to parse: recursive descent, first-token dispatch, small bounded lookahead where the grammar demands it, no backtracking.
5. Small: few concepts, few primitives, few reserved words. The count is the language's, its concepts, its primitives and its reserved words; the standard library is bounded by Appendix E.0's rules, and a function is there where a reader who knows the type looks for it. How many programs ask for a feature decides nothing, for it or against it. A feature costs a program that does not use it nothing: no argument, no word, and no name of it is written there.

**The host.** Ernest runs on a host runtime (§10). A rule of the host is a rule of Ernest only where this report states it as Ernest's own. A host rule whose outcome the program sees, a value or a fault, is taken and stated. One whose outcome would be silent, a truncation, a coerced value, a fault made false, is met by a check on the value or a refusal of the form, and the cost of the check falls on that form alone. An outcome that comes while the host starts, before the runtime runs, is the host's, and the report states it. Where the report is silent, the runtime carries the host's rule without letting it show.

## 1. Notation

The grammar is Wirth-style EBNF. `=` defines, juxtaposition concatenates, `|` separates alternatives, `[ ]` is optional, `{ }` is zero or more, `( )` groups, `.` ends a rule. Uppercase names are non-terminals, lowercase names lexical categories. Terminals are in double or single quotes. `ident`, `conname`, `typename`, `typevar`, `binop`, `userop`, and the literals are defined in §2. The complete grammar is Appendix A.

## 2. Lexical Elements

### 2.1 Characters

Source text is Unicode in UTF-8; a leading byte-order mark (U+FEFF) is stripped. A source that is not UTF-8 is an error at its first byte that begins no character, before any other. Whitespace is space (U+0020), tab (U+0009), line feed (U+000A), and carriage return (U+000D); it separates tokens. A blank line has one meaning more: it decides what a doc block documents (§2.2). Any other control character, U+0000 to U+001F and U+007F to U+009F, is an error wherever it stands, in a comment and a doc block as elsewhere; a string or a character literal writes one as an escape.

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

`needs` and `derives` are words of Appendix A read by position, as a bitstring's specifiers are (§5.11), and identifiers everywhere else: `needs` after a `fn` declaration's parameters or result type (§4.9), and `derives` after a type declaration's last constructor (§3.5).

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

`\u{...}` denotes a Unicode scalar value, U+0000 through U+10FFFF excluding the surrogates U+D800 through U+DFFF. One that names a surrogate or a value above U+10FFFF is an error: `'\u{D800}'`. A `character` inside a `char` or `string` literal is any code point other than the enclosing quote, `\`, U+000A, and U+000D. A multi-line string is built with `\n`, by concatenation, or as a raw string. A raw string, `` `\d+\.\d+` ``, is a `String` whose text is taken as written: `rawchar` is any code point other than the backtick, there are no escapes, and it may span lines, a line break in it being a line feed, with a carriage return before it dropped.

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
Type       = TypeAtom | FnType | ParenType .
TypeAtom   = { typename "." } typename [ "(" ListedType { "," ListedType } ")" ]
           | typevar
           | TupleType .
ListedType = typevar "=" | Type .
TupleType  = "#(" ListedType "," ListedType { "," ListedType } ")" .
FnType     = "(" [ ListedType { "," ListedType } ] ")" "->" FnResult .
FnResult   = FnType | ( TypeAtom | ParenType ) [ "with" Type ] .
ParenType  = "(" Type ")" .
```

`FnType` and `ParenType` both begin with `(`. The parenthesized list of types is read whole, and a `->` after its `)` makes it an `FnType`; otherwise it is a `ParenType`, which holds exactly one `Type`. In a list of types, a type variable followed by `=` is marked with the equality constraint of §3.10, which is written in a foreign function's parameters alone (§4.7).

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

**Integer arithmetic.** Exact and unbounded. `/` truncates toward zero: `-7 / 3 = -2`. `%` satisfies `(a / b) * b + (a % b) == a`, so `-7 % 3 = -1`. `Int.div` and `Int.rem` (Appendix E.8) use the same convention and return `Optional(Int)` (§9.3) in place of the zero-divisor fault: `Int.rem(-7, 3)` is `Some(-1)`.

**Float arithmetic.** IEEE 754 binary64, round to nearest, ties to even, restricted to the finite range. An operation whose result is not finite faults with cause `Fault("float arithmetic error")` (§7.3): overflow, division of a non-zero numerator by zero, or `0.0 / 0.0`. Gradual underflow to a subnormal is not a fault. There is no `Infinity`, no `NaN`, and no negative zero: a zero is `0.0`, whether an operation or a negation gives it, or it enters the program from foreign code, from bytes, or from text. A float segment pattern `0.0` matches the bytes of either zero. A float segment pattern does not match the bytes of an infinity or a NaN. `Float.compare`, `Float.round`, `Float.truncate`, `Float.floor`, and `Float.ceil` are total.

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

type Snapshot = Snapshot(directory : Path, seen : Map(Path, Int))
```

`Path` and `Map` are the prelude's (§9.2, §9.3). Field names are unique within a constructor. Their declaration order is the order in which a value's fields are stored, transported (§8.4), and shown (Appendix E.1), and is part of the type's identity (§8.7); a construction and a pattern may give them in any order, and field expressions are evaluated in source order (§5.1). There is no canonical order. Positional and named fields are told apart by `:` after the first identifier in a declaration and by `=` in construction and patterns.

A type declaration may end in `derives compare`: `type Date = Date(year : Int, month : Int, day : Int) derives compare`. The type then has the member `compare` (§4.5), which orders two values by constructor in declaration order and then by field from left to right, each by its type's `compare` (§3.10). A field whose type has no `compare` is an error at the declaration: `Date.compare cannot be derived: Optional(Int) has no compare`. For a type with parameters, the member has the requirement (§4.9) `needs` of each parameter the comparison reaches: `type Pair(a, b) = Pair(first : a, second : b) derives compare` gives `Pair.compare` the requirement `needs a.compare, b.compare`. `derives` names `compare` and nothing else.

A named field is *selected* with `e.f`: the field `f` of the value `e`, `snapshot.seen`. A type has the selector `f` when every one of its constructors has a named field `f`, and they have one type once the operand type's arguments stand for its parameters, which is the selector's; on any other type `e.f` is a type error. A positional field has no selector. Outside the module that declares an abstract type, its fields have no selectors, as its constructors are not visible there (§4.4). The type of `e` is found as an operator's operand type is (§4.8). In a body with a requirement, `a.member` names a member and selects nothing (§4.9).

### 3.6 Abstract types

A sum type whose constructors may be mentioned only in the module that declares it, §4.4.

### 3.7 Built-in types

`Address(m)` is an address of a process that receives `m`. `Reply(a)` is a one-shot address for the answer to a request, §6.6. `Never` is the type with no values. It is an ordinary type and unifies with itself alone; a function that never returns and may stand at any type has a type variable as its result, as `fault` has (§9.6). The prelude types are listed in §9.

### 3.8 Foreign types

A type declared `foreign type T` has no constructors: its values are made and used only by foreign functions, §4.7, and can otherwise be held, passed, and sent. Its equality is §3.10's. A host value of no other Ernest type enters Ernest through a foreign type alone, each with the runtime's exact equality: `foreign type T` declared by a module, and the foreign type of any host value, `Foreign.Term` (Appendix E.12).

A foreign type is bound to its node (§3.11): a value of it never crosses to another node, and the compiler refuses the operations that would start one on its way.

### 3.9 Type variables and polymorphism

Types are inferred according to Hindley-Milner. A `fn` definition, a top-level `let`, and a `let` in a block that binds a name to a lambda are generalized over the type variables of their types that no name in scope around them holds; another `let` in a block is not, nor is a top-level `let` whose initializer calls a process-only function (§4.6). Type variables in a `fn` signature scope over the whole definition, including the annotations of lambdas, of block `let`s, and of local `fn`s within it. A type variable in an annotation means every type and is rigid. A type variable named first in a lambda's annotation or a block `let`'s belongs to that lambda or binding. Only a generalized lambda or binding may name such a variable: a lambda that is a `let`'s whole value, at top level or in a block. Naming one elsewhere is a type error: `List.map(xs, fn(x : a) = x)`. A local `fn`'s signature shares the enclosing signature's variables, and a variable named only in it is the local function's own, rigid and generalized with it as a top-level function's is. Recursive and mutually recursive types are allowed; polymorphic recursion is not, even where the whole signature is written: a recursive call is at the definition's own type. A module's definitions are inferred each after the definitions it names, and a group of definitions that name one another is inferred together, each call within the group at the called definition's own type, before any is generalized. Within a recursive group of types, a type of the group is named in the group's fields at the parameters of the type declared, each in its place, and at nothing else. `type Nest(a) = Flat(a) | Deeper(Nest(List(a)))` is refused at its declaration, and so is `type Flip(a, b) = End(a) | Turn(Flip(b, a))`; `Deeper(List(Nest(a)))` is allowed. Every type variable in a constructor's fields is a parameter of the type.

**Effect polymorphism.** The mailbox effect of a function type may be a type variable, generalized with the others: `fn apply(f, x) = f(x)` has type `((a) -> b with e, a) -> b with e`. At a call site an effect variable binds to a mailbox type or to pure: `apply(fn(x) = send(a, x), 5)` binds `e` to the mailbox of `send`, `apply(fn(x) = x + 1, 5)` binds `e` to pure. Pure is the absence of `with`; it is not a type. A mailbox type bound this way becomes the caller's. A pure function stands wherever a function of the same type with a mailbox type is expected, and a function with a mailbox type never stands where a pure one is expected. So an expression whose type is a function type without `with` takes a fresh effect variable in its place, which the context binds: with `fn double(n : Int) : Int = n * 2` and `fn done(n : Int) : Unit = Unit`, `Upgrade(migrate = double, next = done)` binds it to `CounterMsg` (§6.10). Only the expression's own function type takes one. A function type inside it or inside another type, a parameter's, a result's, or a field's, keeps its effect until an expression has it as its own type, as a call or a selection does.

An effect position is the type after `with`. A value position is an argument, a result, a tuple component, or a type argument whose parameter occurs in a value position of its type's fields. A type argument of a built-in or foreign type is a value position. A variable that occurs only in effect positions ranges over the mailbox types and pure. A variable that also occurs in a value position ranges over types alone: `m` in `self : () -> Address(m) with m` is never pure. Inference asks for an annotation at an operator whose operand type nothing in the definition fixes (§4.8), a field selection whose operand type nothing fixes (§3.5), a top-level binding that is not generalized whose type keeps a variable nothing resolves (§4.6), a `<-` whose sum type is still open (§5.5), `Io.show` or `Io.debug` at a type not known whole that no requirement names (Appendix E.1, §4.9), a fill whose record type leaves a requirement's variable undetermined (§5.6), a path in a record update through a field whose type nothing fixes (§5.6), `Foreign.from` at a type not known whole that holds no type variable of the signature (Appendix E.12), and an input at the prompt that binds a name its type does not settle (§11.2). A `Peer.spawn` or `Peer.spawnMonitored` whose function captured a value whose type holds a type variable is refused (§3.11).

The functions of §9.4 and §9.5 whose own effect is a mailbox type, `restarting`, and a `foreign fn` whose effect is its own, are *process-only*: their effect variable is treated as if it occurred in a value position, and pure code cannot call them. A `foreign fn`'s effect is its own unless its effect variable is also the effect of one of its parameters' function types, in which case the effect is that callback's and the function is effect-polymorphic: `foreign fn each(m : Map(k, v), f : (k, v) -> Unit with e) : Unit with e` is pure when `f` is.

A function has one mailbox effect or none. A function may take a pure callback beside an effectful one: in `fn callBoth(p : (Int) -> Int, e : (Int) -> Unit with n) : Unit with n`, `p` is pure, `e` has effect `n`, and the function inherits `n`. Two callbacks whose effects are both variables unify to one effect. Two callbacks with different concrete effects are a type error.

**Inferred restrictions.** An annotation gives a function's shape: arity, argument types, result, mailbox effect. Three restrictions are inferred from the body. Where there is no body, a restriction is given instead: written on a foreign type's parameter, `k=`, or on a type variable in a foreign function's parameters, `a=`, the one mark a program writes (§4.7); given to a foreign function by §4.7 and the paragraph above; and stated for the prelude's types and primitives in §9. Each prints with its mark (§11.5). The equality constraint of §3.10 falls on a variable compared with `==`. Process-only is inherited by a function whose body calls a process-only function: `fn wrap(a, v) = send(a, v)` cannot be called from pure code, and neither can `fn h(a : Int) : Unit with e = Io.println("")`. Not-reply-carrying (§6.6) falls on a type variable of a definition's type when the definition, read with that variable as a reply-carrying type, would break §6.6, and on a foreign function's as §4.7 says: use such a value twice or not at all, through a `let` or a pattern as much as by the parameter's name, put it where §6.6 forbids one, or pass it, alone or inside another value, where a function carries the restriction. The variable stands in a parameter's type, in the result type, or in the type of a value. A function the definition returns or holds is read as the definition is. So `fn dup(x) = #(x, x)`, `fn discard(x) = Unit`, `fn keep(x) = { let y = x; Unit }`, `fn both(x) = dup([x])`, and, for `type Box(a) = Box(a)`, `fn forget(b : Box(a)) : Unit = Unit` cannot take a reply, nor can the function `fn pair() = fn(x) = #(x, x)` returns, of type `() -> (a!) -> #(a!, a!)`, and `fn id(x) = x` can. `Optional.withDefault : (Optional(a!), a!) -> a!` is restricted. Each is part of the type scheme and travels with the function value through bindings, branches, and compiled interfaces. Each is checked at instantiation, not at definition.

### 3.10 Equality and ordering

`==` and `!=` are structural and defined for all values except those containing functions or addresses, on which they are a type error. On a value of a foreign type, `Foreign.Term` among them, or of `Process`, they are the runtime's exact equality on the two representations (§8.4): two references are equal only when they are one reference, and two values that foreign code made as the same term are equal. Ordering is per type, through `compare` in the type's namespace: `Int.compare : (Int, Int) -> Ordering` (§9.3). For a type a module declares, that is its member `T.compare` (§4.2); a function named `compare` outside the type's namespace gives no ordering. For operand type `T`, `a < b` is `T.compare(a, b) == Less`; `<=`, `>`, and `>=` likewise. They resolve against the operand type as the operators of §4.8 do. A type without `compare` has no ordering, and `<` on it is a type error. The prelude defines `compare` for `Int`, `Float`, `String`, and `Char` (§9.6), and for no other type: `Bool`, `Optional`, and `Path` (§9.3) have no ordering.

An *order* on a type `T` is a function `f : (T, T) -> Ordering` for which, for all `a`, `b`, and `c` of `T`: `f(a, a)` is `Equal`; `f(a, b)` is `Less` exactly when `f(b, a)` is `Greater`; where `f(a, b)` and `f(b, c)` are `Less`, `f(a, c)` is `Less`; and where `f(a, b)` is `Equal`, `f(a, c)` is `f(b, c)`. Each `compare` of the prelude is an order, and says `Equal` only where `==` holds. A derived `compare` (§3.5) is an order where the `compare` of each other type its fields name is one, and says `Equal` only where `==` holds where each of those does. Where any other function is given as an order, or is the `compare` an ordered set or map requires, the laws are the program's promise, and nothing checks them. What the standard library says of a sorted list, and of an ordered set or map, holds only where the function it is given, or the `compare` it requires, is an order (Appendix E.2, E.25, E.26).

A function that applies `==` to a value of a type variable gives that variable an *equality constraint*, inferred and never written; instantiating it with a type that contains a function or an address is a type error at that call site. A foreign type's parameter and a foreign function's type variable may carry the constraint (§4.7), and `Map(k=, v)` and `Set(a=)` carry it on `k` and `a` (§9.2). A value of such a type over a type without equality is rejected at its first operation; a type that names one, `Map((Int) -> Int, Int)` in an annotation or a field, is not itself an error. A standard library function that compares elements, `List.contains`, propagates the constraint through its parameter. `fn equal(a, b) = a == b` has type `(a, a) -> Bool` with the constraint on `a`. The constraint travels and is checked as §3.9 says: `let f = equal` carries it, and applying `f` to addresses is an error at that application; `if flag then equal else always`, with `always` unconstrained, carries the union of the branches' constraints.

### 3.11 Serialization

A message may be a value of any type, a function included. A type is *bound* to its node where it holds a function type, a foreign type (§3.8), a resource, or an `Address(m)` or a `Reply(m)` whose `m` is bound; a resource is `Ets.Table` (Appendix G.1) or the address of a socket, a listener or a program the runtime started (Appendix E.18, E.23). Every other type crosses: `Int`, `Float`, `Bool`, `Char`, `String`, `Bytes`, a tuple, a list, `Map`, `Set`, a declared type's values, an address, a `Process` and a `Reply` of an unbound type, and an adapted address (§6.5). A value of a bound type never crosses. The compiler refuses the three operations that would start one on its way: a `Peer.key` of a bound type (§8.7); a `Peer.spawn` or `Peer.spawnMonitored` whose function captured a value of a bound type, or a value whose type holds a type variable (§3.9); and a `Peer.spawn` or `Peer.spawnMonitored` whose function's mailbox type is bound. A key's message type and the mailbox type of a process spawned on a peer are known whole where they are written: one that holds a type variable there is refused, as a bound one is. The function a spawn on a peer starts is the name of a `fn` or `foreign fn` declaration, which captures nothing, or a lambda written in the same definition, at the spawn or bound by a `let` whose name the spawn writes; its captures are the locals its body names. Any other expression is refused, a function that came as a parameter, in a message or from a call among them, since its captures are not in its type. `Peer.spawn` and `Peer.spawnMonitored` are called where they are named, and are not taken as values. No other operation is checked, and nothing is looked through at a send: an adapted address crosses with the values its function captured as payload, which are touched only on the node that made it, where the function runs (§6.5). A value crosses in the runtime's external term format (§8.4) and carries nothing of its type, which is known at both ends and the same at both, since every node runs one build (§8.7). So a message between nodes is values only, and it needs no code on the node it reaches.

## 4. Declarations and Scope

```
Program     = { Declaration } .
Declaration = [ "export" ] ( TypeDecl | AbstractDecl | FnDecl | LetDecl | ForeignDecl ) .
ForeignDecl = "foreign" ( "type" typename [ "(" ForeignVar { "," ForeignVar } ")" ]
            | "fn" DeclName "(" [ ForeignParam { "," ForeignParam } ] ")" Return "=" string ) .
ForeignVar  = typevar [ "=" ] .
ForeignParam = ident ":" ListedType .
TypeDecl    = "type" typename [ "(" typevar { "," typevar } ")" ] "="
              Constructor { "|" Constructor } [ "derives" "compare" ] .
Constructor = conname [ "(" ( Type | Field { "," Field } ) ")" ] .
Field       = ident ":" Type .
AbstractDecl  = "abstract" TypeDecl .
FnDecl      = "fn" DeclName "(" [ Param { "," Param } ] ")" [ Return ] [ Requirement ] "=" Expr .
Requirement = "needs" Member { "," Member } .
Member      = typevar "." ( userop | "compare" | "negate" | "show" ) .
Param       = Pattern [ ":" Type ] .
Return      = ":" FnResult .
LetDecl     = "let" ident [ ":" Type ] "=" Expr .
Binding     = "let" Pattern [ ":" Type ] ( "=" | "<-" ) Expr .
DeclName    = ident | typename "." ( userop | "compare" | "negate" ) .
```

### 4.1 Modules

A *module* is one source file, ending in `.ern`: the unit of compilation and of namespace. Every top-level declaration belongs to exactly one module. The modules' dependencies are acyclic; a cycle is a compile-time error.

### 4.2 Namespaces and visibility

**Files are namespaces.** A file at `a/b/c.ern` under the source root provides the namespace `A.B.C`. A path segment is one or more words joined by `_` (§11.1), and the namespace segment is each word with its first letter uppercased and the `_` dropped: `http.ern` is `Http`, `httpv2.ern` is `Httpv2`, `ordered_set.ern` is `OrderedSet`, and `net/http_client.ern` is `Net.HttpClient`. A namespace segment's words begin at its uppercase letters: `OrderedSet` is the file `ordered_set.ern`. The top of the hierarchy, where the prelude lives, is provided by the runtime, not by user code.

**Declarations are local; `export` marks the boundary.** A declaration is written with its local name. `fn parse` in `net/http.ern` is exported as `Net.Http.parse` when marked `export`; otherwise it is private to its module. A use site may write a declaration's qualified name: elsewhere for an exported one, and within its own module only where a binding hides the declaration's plain name, as `Prelude.` is written only where the module hides the prelude's. A module's own type, constructor or member, which no binding hides, is written plain within it; the qualified form there is an error whose help names the plain one. A declaration never writes its own name qualified. Two declarations of one name in a module are an error, exported or not: `fn f` beside `let f`. The type of an exported declaration, and the field types of an exported type that is not abstract, may not name a type the module keeps private. A function's mailbox type is exempt: an exported entry point may receive a private message type. A type whose values cross the boundary but whose constructors do not is an `abstract type` (§4.4). There is no export list and no `import`.

**Taken namespaces.** A module namespace may not coincide with a namespace of the prelude or the standard library. The prelude's namespaces are `Prelude` and the name of every type that has a member in §9, as `Int` and `Address` do: `address.ern` at the source root is an error, and so is `io.ern`, a namespace of the standard library. A prelude type without members takes no namespace: `down.ern` at the source root provides the namespace `Down`, and the type `Down` is still the prelude's. The standard library's own source root, shipped with the toolchain, is the exception: its files provide those namespaces. A file under it is compiled with it as the source root (§11.1); another source root is an error.

```ernest-fragment
// net/http.ern
export type Request = Request(method : String, path : String)

export fn parse(text : String) : Optional(Request) =
    ...

// private to net/http.ern
fn helper(x) =
    ...
```

**Type members.** A type `T` declared in a module, concrete or abstract, is a nested namespace. Its members are its operators, its `compare` and its `negate` (§4.5), declared with the single prefix `T.`, as in §4.8's `fn Distance.+`, or derived (§3.5), and exported at `Module.T.member`. The module of a prelude type is the exception §4.8 states: `export fn Float.+` in `float.ern` declares `Float.+`, and its `compare` and `negate` are declared unprefixed. The namespace belongs to the file that declares the type. A module namespace may not coincide with it: `main/stack.ern` is an error when `main.ern` declares `Stack`. In `main.ern`, `Main.Stack.compare` is the member of its own type `Stack` where it declares one, and the module `Main.Stack`'s `compare` where it does not. The coincidence is exact: `main.ern` may declare `STACK` beside `main/stack.ern`, and a module may declare two types whose names differ only in case.

**Unqualified lookup.** An unqualified name in a body is looked up first among the names bound around it, the innermost first: parameters, `let` bindings, pattern and `receive` variables, and local `fn`s. It is then looked up in the module's declarations, exported or not, then in the prelude. A name not found there is written qualified; a type's member is written `T.name`, within the type's own members too. A module may declare a type, a constructor, a function or a value with a prelude name, and the name then means the local one throughout the module. A dotted name's first segment is a type the module declares where that type has a member of the name, and otherwise the namespace of that name: in a module that declares `type List` with a member `List.<>`, `List.<>` is that member, and `List.map` the standard library's. `Prelude` names the prelude's own namespace: `Prelude.Some` is the prelude's `Some` in a module that declares its own. It is written only where a declaration or a binding of the module hides the name it reaches: `Prelude.Some` in a module that declares no `Some` is an error. It takes one name the prelude declares, or a namespace of the prelude or the standard library and one of its names: `Prelude.List.<>` is the prelude's `List.<>` past a member `List.<>` of the module's own. A member `T.f` of the module's own type is reached before a program module `T`'s `f`, and no prefix reaches past it, as `Prelude.` reaches past a prelude name. No module and no type is named `Prelude`. Within a module, type names are unique and constructor names are unique across its types.

### 4.3 Type declarations

`type` declares a sum type with its constructors. A type's parameters are distinct type variables. A constructor has the visibility of its type.

### 4.4 Abstract types

`abstract type T = ...` declares a type whose constructors may appear only in the module that declares it. Every definition of that module may use them, a private one or a test included; another module sees the type and not its constructors. An abstract type is exported: one the module keeps private is an error.

```ernest
// stack.ern  (namespace Stack)
export abstract type Stack(a) = Stack(List(a))

export let empty = Stack([])

export fn push(Stack(items), item) =
    Stack(item :: items)

export fn pop(Stack(items)) =
    match items {
        [] -> None
      | item :: rest -> Some(#(item, Stack(rest)))
    }

export fn size(Stack(items)) =
    List.size(items)
```

External callers see `Stack.Stack`, `Stack.empty`, `Stack.push`, `Stack.pop`, and `Stack.size`; `Stack.Stack(...)` is refused outside `stack.ern`. A module may declare several abstract types. Outside its module, `Io.show` writes a value of an abstract type as `<abstract>` (Appendix E.1).

### 4.5 Functions

`fn` declares a function of fixed arity. Annotations may be omitted where they can be inferred. The result annotation is omitted, or is `: T` for a pure function, or `: T with M` for process code, as a parameter's annotation is `: T`. A pure annotation on a function that calls process code is a type error. A pure annotation makes pure the effect of every parameter the body calls: `fn apply(f, x) : Int = f(x)` has type `((a) -> Int, a) -> Int`. `with M` where `M` is a type variable that names no parameter's effect is written only where the body acts through a process, making `M` process-only (§3.9); over a body that does not, it is an error, since the function is pure and `: T` is its one annotation: `fn k() : Int with m = 5` is refused.

A function has one clause. Patterns in parameters are irrefutable, §5.10: `fn seenCount(Snapshot(seen = entries) : Snapshot) : Int = Map.size(entries)`.

`fn` may appear at top level and as a statement in a block; it sees its own name, and `fn` declarations in the same block or at top level may refer to each other. A type-member name, `fn T.f`, is a top-level form; in a block it is an error. A type's operations are functions of its module. A member, `fn T.f`, is declared only for what the language resolves by the operand's type: an operator of §2.6, `compare` (§3.10), and `negate` (§5.1); a `let` declares no member. A type whose declaration ends in `derives compare` has that member without declaring it (§3.5). A function declaration may end in a requirement, which names members of its type variables (§4.9). A module reaches its abstract type's constructors by being its module (§4.4).

### 4.6 Bindings

In a block, `let p = e` binds the irrefutable pattern `p` to the value of `e`; `let p <- e` is described in §5.5. A binding's initializer may not depend on its own name, which is a cycle (§8.5), so a function that calls itself is declared with `fn` (§4.5). It is monomorphic, except one that binds a name to a lambda, `let id = fn(x) = x`, which is generalized as a local `fn` is (§3.9). A later binding of the same name shadows the earlier one from the next statement on; the right-hand side of the later binding sees the earlier one.

A block binding's type may hold unresolved type variables; `[]`, `None`, `Map.empty`, and a call that returns a polymorphic value introduce them. A later use of the binding in the block pins such a variable: `let m = Map.empty; Map.put(m, "a", 1)` pins `m` at `Map(String, Int)`. One that reaches the block's result is generalized by the enclosing `fn` or top-level `let`: `fn namedEmpty() = { let xs = []; xs }` has type `() -> List(a)`. An annotation on the binding fixes it. A use pins a variable only where it fixes the variable's type, and a variable that nothing pins stays free: in `{ let xs = []; List.size(xs) }` the element type stays open.

At top level, `let` binds an `ident`. The left side is a name, not a pattern; `<-` is a block form only. The initializer is a body of mailbox type `Never` (§6.8): it may spawn, send, and call, and it receives no message, a `receive` in it having only an `after` clause. The binding generalizes its free type variables: `let empty : Stack(a) = Stack([])`. A binding whose initializer calls a process-only function (§3.9) as it is evaluated is not generalized, and a type variable left in its type is a type error at the binding. A call in the body of a lambda the initializer builds and does not call is the lambda's: `let me = fn() = self()` is generalized. The runtime evaluates top-level bindings in dependency order, in the entry process, before `main` runs (§8.5).

### 4.7 Foreign declarations

`foreign type T` declares a type implemented outside the language. Its parameters are distinct type variables. A parameter written with `=`, `k=` in `foreign type Table(k=, v)`, puts the equality constraint of §3.10 on its argument at every operation of the type, and the type written with an argument that lacks it is not itself an error (§3.10).

`foreign fn f(params) : T = "impl"` declares a function whose body is the implementation named by the string, in the runtime's language; parameters and the result are annotated. A type variable written with `=` in a parameter's type, `a=` in `foreign fn member(element : a=, list : List(a)) : Bool = "lists:member/2"`, carries the equality constraint of §3.10, as one a body compares with `==` does. A variable is marked once, at any of its occurrences in the parameters: a second mark is a type error, and so is a mark in the result type or in any annotation outside a foreign function's parameters. A foreign function has no body from which §3.9 infers restrictions, and its code may copy a value it is given or drop it, so each type variable whose values a parameter holds is not reply-carrying (§6.6): one the parameter's type reaches through tuples and type arguments, and not under `Address`, `Reply`, or a function type. What a function it is given returns is the foreign code's to hand on once, as a `Reply` it is given is its to answer once (§8.4). `Foreign.from(r)` on a reply is a type error. A foreign function with a mailbox type may do anything. One without a mailbox type promises purity: the same result for the same arguments, and no effect on anything. The implementation promises the declared types: a value of another shape, where it is checked (§8.4), or an exception, is a fault, §7. Foreign code sees values in the runtime's representation, §8.4. Both declarations take `export` (§4.2).

### 4.8 Operators

The arithmetic operators `+`, `-`, `*`, `/`, `%` and `<>` resolve against the operand type, by *operator resolution*. In `a + b`, `+` is `Int.+` when `a : Int` and `Distance.+` when `a : Distance`, for `export type Distance = Distance(Int)`. A user type declares its operators in its own module: `export fn Distance.+(Distance(a), Distance(b)) : Distance = Distance(a + b)`. The standard library module of a prelude type (§9) declares that type's operators the same way, with the type's name as the prefix: `fn Float.+` in `float.ern` declares `Float.+` (§9.6). In that module the prefix is allowed on an operator only; its other functions are declared unprefixed, `fn abs`. Both operands have one type, which either may determine, and there is no numeric type to generalize over: `fn f(a, b : Int) = a + b` uses `Int.+`. The operand type is determined when its type constructor is known: `xs <> []` is `List.<>`. An operator's result does not determine its operands. An operator is resolved once its definition is inferred, and before the definition is generalized. Its definition is the enclosing `fn` declaration, top-level or local, the enclosing top-level `let`, or a block `let` that binds a lambda, since each is generalized (§3.9, §4.6); any other lambda belongs to the definition it stands in. So `fn add(a, b) = a + b` in a block is a type error, whatever calls it later, and `fn add(a : Int, b : Int) = a + b` is not. An operand whose type is then a type variable of the enclosing declaration's signature resolves to the member its requirement names, `needs a.+` (§4.9). An operand type still undetermined then, or a type variable no requirement names, is a type error. A field selection (§3.5) is resolved in the same way, against its operand's type. A member named by an operator has the type `(T, T) -> R` for its type `T`, `T.compare` the type `(T, T) -> Ordering`, and `T.negate` the type `(T) -> R`; each is pure. For a type with parameters, `T` is the type applied to any arguments, the same in each place: `Vec.+` of a type `Vec(a)` has the type `(Vec(a), Vec(a)) -> R`. A member of another shape is an error at its declaration. An operator on a type that declares no member for it, `%` on `Float` or `<>` on `Int`, is a type error.

`!` is negation on `Bool`, the prefix operator beside the logical operators `&&` and `||`, and `Bool.not` (E.7) is the same operation as a function, as `Int.negate` is of prefix `-`. `==`, `!=`, `<`, `<=`, `>`, `>=`, `&&`, and `||` cannot be defined per type: equality is structural and ordering goes through `compare` (§3.10); `&&` and `||` short-circuit on `Bool`. `::` is cons (§3.3); `|>` is a syntactic form (§5.7). The operators are the closed set of §2.6, and every other operation is a function. An operator the language resolves against its operand's type is resolved where that type is known, and on a type variable where a requirement names the member (§4.9); on any other type variable it is a type error. It carries no argument the program has not declared: on a known type none, and on a type variable the member the requirement names, which a call supplies without writing it. `==` compares structurally, or exactly on a foreign type and `Process` (§3.10), and needs none. Requirements are §4.9.

### 4.9 Requirements

A `fn` declaration may end in a *requirement*: `needs` and the members it names, after the result type and before `=`. `fn fromList(list : List(a)) : Set(a) needs a.compare = ...` names the member `compare` of the type `a` stands for (§4.5, §3.10); `needs a.+` names an operator, and a requirement names several with commas, `needs a.+, a.*`. A requirement names `compare`, `negate`, an operator of §2.6, or `show`, which is no member but `Io.show` and `Io.debug` (Appendix E.1), and nothing else: `needs a.zero` is an error at the declaration, `zero is not a member: a requirement names compare, negate, an operator or show (§4.8, E.1)`. The variable is a type variable of the signature that stands in a value position (§3.9); one in effect positions alone, and one the signature does not name, are errors at the declaration, `b is no type variable of the signature`. A variable that stands in the result type alone may carry one. A requirement names a variable's member once; naming it twice is an error, `the requirement names a.compare twice`. A type has one member of each name.

In the body, a member the requirement names is a value of the member's shape at `a`: `a.compare` has the type `(a, a) -> Ordering`, `a.negate` the type `(a) -> a`, and an operator `a.+` the type `(a, a) -> a`. An operator on `a` resolves to it as it resolves on a known type (§4.8), `x < y` through `a.compare` (§3.10) and prefix `-` through `a.negate` (§5.1). Under `needs a.show`, `Io.show` and `Io.debug` apply to a value of the type `a` itself (Appendix E.1). A member of a type variable the requirement does not name, `a.compare`, `<` or `Io.show` on it, is a type error (§4.8, Appendix E.1). The member is written `a.member` where `a` is a type variable of the signature of a declaration with a requirement (§3.5); such a declaration binds no name that is one of its type variables: a parameter, a `let` or a pattern variable so named is an error.

A call writes nothing for a requirement. The requirement is supplied once the enclosing definition is inferred, as an operator is resolved (§4.8), by the type the variable is instantiated to there. Where that type is known, the compiler supplies its member, and `show` as `Io.show` is supplied at a known type: `OrderedSet.fromList([3, 1, 3])` is `fromList` with `Int.compare`. Where it is a type variable of the enclosing declaration's signature, the enclosing requirement at that variable supplies it: `fn unique(list : List(a)) : List(a) needs a.compare = OrderedSet.toList(OrderedSet.fromList(list))`. A type built from a variable, `List(b)`, is a known type, whose member is looked for. A member with a requirement of its own, a derived `Pair.compare` (§3.5), is supplied with its own requirement met at its type by the same rule: at `Pair(Int, String)` with `Int.compare` and `String.compare`, and at `Pair(a, b)` with the enclosing requirement's. The member has its shape at the type: a call at a type whose member has another result type is an error naming both, `total needs Vec.+ : (Vec, Vec) -> Vec, and Vec.+ answers Float`, with the help `a function over an operation of another shape takes it as a parameter`. A known type without the member is an error naming both: `fromList needs List(Int).compare, and List(Int) has no compare`. A type variable the enclosing declaration's requirement does not name is an error naming both, `fromList needs a.compare, which unique does not declare`, with the help line ``add `needs a.compare` to unique's signature``. A declaration with a requirement taken as a value is the function with its members supplied by the same rule: `List.foldLeft(list, empty, put)` under `needs a.compare` passes `put` with that `compare`.

The requirement in force in a body is the enclosing `fn` declaration's, for the type variables of its signature, wherever a use stands in the body, in a lambda and in a `let`-bound lambda included (§3.9). A lambda a `let` binds is generalized before a call ties its own variables to the signature's (§4.6): `let build = fn(xs) = OrderedSet.fromList(xs)`, unannotated, meets the error above. A `fn` in a block declares a requirement for its own variables and shares the enclosing declaration's for the shared ones (§3.9). A top-level `let` declares no requirement: `let f = OrderedSet.fromList` is refused, `fromList needs a.compare, which a top-level let cannot declare`, with the help line ``declare a `fn` with `needs a.compare` ``. A requirement is never inferred: a function has the requirement it writes and no other. It is no part of a type scheme (§3.9); a declaration's requirement is recorded in the module's compiled interface (§11.1) and shown after its type (§11.5).

Code written once over several representations of a type takes an *operations record*: a record the program declares of the operations it uses, filled from each representation's namespace (§5.6) and passed as an argument.

```ernest
type Date = Date(year : Int, month : Int, day : Int) derives compare

type Operations(s, a) =
    Operations(fromList : (List(a)) -> s, intersection : (s, s) -> s, toList : (s) -> List(a))

let hashed : Operations(Set(Int), Int) = Operations(..Set)

let ordered : Operations(OrderedSet.Set(Int), Int) = Operations(..OrderedSet)

fn unique(list : List(a)) : List(a) needs a.compare =
    OrderedSet.toList(OrderedSet.fromList(list))

fn common(list : List(a), other : List(a), operations : Operations(s, a)) : List(a) =
    operations.toList(operations.intersection(operations.fromList(list),
                                              operations.fromList(other)))
```

`unique(["b", "a", "b"])` is `["a", "b"]`; `common([4, 2, 3], [3, 4, 5], ordered)` is `[3, 4]`, and with `hashed` the same elements in the hash set's order; `OrderedSet.fromList([Date(year = 2026, month = 10, day = 2), Date(year = 2025, month = 1, day = 1)])` is ordered by year, then month, then day.

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
Primary   = literal | QName | typevar "." userop | Tuple | ListLit
          | BitExpr | Block | MatchExpr | ReceiveExpr | "(" Expr ")" .
QName     = { typename "." } ( ident | conname [ "(" ( Expr | Fields ) ")" ] )
          | typename "." { typename "." } userop .
Fields    = ".." Expr [ "," UpdateSet { "," UpdateSet } ] | FieldSet { "," FieldSet } .
UpdateSet = ident { "." ident } "=" Expr .
FieldSet  = ident "=" Expr .
Tuple     = "#(" Expr "," Expr { "," Expr } ")" .
ListLit   = "[" [ Expr { "," Expr } ] "]" .
BitExpr   = "<<" [ BitSegE { "," BitSegE } ] ">>" .
BitSegE   = Expr [ ":" BitSpec { "-" BitSpec } ] .
Block     = "{" Stmts "}" .
Stmts     = ( FnDecl | Binding ) ";" Stmts | Expr [ ";" Stmts ] .
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

Strict, left to right, arguments before the call. A callee is evaluated before its arguments. In `x |> e`, `x` is evaluated before `e`: `x |> f(a)(b)` evaluates `x`, then `f(a)`, then `b`. A selection evaluates its operand, then reads the field. Nothing is delayed; `fn() = e` defers `e`. Prefix `-` is `negate` in the operand type's namespace: `Int.negate`, `Float.negate`, or `T.negate` for a user type `T`, and `a.negate` on a type variable whose requirement names it (§4.9). A user type declares `T.negate` the way §4.8 declares `T.+`.

### 5.2 Calls

`f(x, y)` supplies all arguments. A call with the wrong number of arguments is a type error at the call; a call never yields a partially applied function. An expression whose value is a function can be called directly, `makeAdder(3)(4)`.

### 5.3 Lambda

`fn(x) = e` is an anonymous function. Its body is the longest `Expr` at the same nesting level, ending at the first delimiter of the enclosing form: `,`, `;`, `:`, `|`, `->`, `)`, `{`, `}`, `]`, `>>`, `then`, or `else`. A `{` that begins the body opens a block (§5.4), which is the body.

### 5.4 Blocks

`{ s1; s2; e }` is an expression whose value is its last statement, which is an expression: a block that ends in a `let` or a `fn` is refused. `;` separates statements and never appears last. A statement is a `fn` declaration, a `let` binding, or an expression evaluated for its effect. An expression that is not the last statement has type `Unit`; a value is discarded with `let _ = e` (§5.10), whatever `e` is, a pure one among them, since the `_` shows the value unused (§0, principle 3).

A `fn` declared in a block is visible throughout it, so local functions may be recursive and mutually recursive. Two `fn` declarations of one name in one block are an error. A local `fn` may not take the name of a parameter or a variable in scope where it is declared, nor of a `let` of its block. The body of a local `fn` sees the bindings in force at its declaration, and a later `let` of a name it reads does not reach it. `let` bindings are sequential. A `fn` body that reads a name only a `let` declared later in the block binds is a compile-time error. A local `fn` may be used only after every `let` it references has been evaluated; a `let` referenced through another local function counts. A use is a call, or taking the function as a value, passing, storing, returning, or capturing it. An earlier use is a compile-time error.

### 5.5 Binding with `<-`

In a block, `let p <- e; rest` matches `e`: on `Right(v)`, `p` is bound to `v` and `rest` is evaluated; on `Left(err)`, the block's value is `Left(err)`. `p` is irrefutable (§5.10). With `Optional`, `Some` and `None` apply the same way.

In `let p : T <- e`, `T` is the type of `p`, the value inside. The sum type is decided after inference of the enclosing definition: from the type of `e`, or, if that is still open, from the block's type. Where both are open it is a type error, which asks for an annotation that fixes either, a parameter's type or the function's result type. `rest` has the block's type. All `<-` bindings in one block resolve to the same sum type.

### 5.6 Construction

`Some(e)`, `None`, `Snapshot(directory = d, seen = s)`. All fields are given, each once. `Snapshot(..p, seen = s)`, a *record update*, takes the unlisted fields from `p`; at least one field follows `..`. A field of a field is updated through a *path*: `Pool(..pool, stats.indexed = e)` is `Pool(..pool, stats = Stats(..pool.stats, indexed = e))`, with `pool` evaluated once. A path stands in a record update only, and each type along it has one constructor with the named field. Two paths may share a prefix, `stats.indexed` beside `stats.hits`; neither may be a prefix of the other, and no path is given twice. The base is evaluated first, and the field expressions in source order (§5.1). `Operations(..Set)`, a *fill*, names a namespace after `..` and takes each field not given beside it from the declaration of its name in that namespace that the use site may name (§4.2), at the field's type; a namespace may stand alone after `..`, and `Operations(..OrderedSet, toList = mine)` takes the field given and fills the rest. The name after `..` is a namespace where it is a qualified name of type names alone, a constructor of the same name notwithstanding, and an expression otherwise. `..Prelude.N` is refused: `Prelude.` reaches a name, not a namespace (§4.2). A field with no declaration of its name in the namespace, or one whose type does not fit the field's, is an error naming the field and the namespace: `Operations(..Set) lacks isSubset: Set has no isSubset`. A declaration with a requirement (§4.9) fills a field with its members supplied at the field's type, which the construction's type must fix; where that type leaves the requirement's variable undetermined, the fill is an error naming the field and the variable, which asks for an annotation: `fromList needs a.compare, and the record's type leaves the variable a undetermined; annotate it`. `..` is allowed only on a type with one constructor; on any other it is a type error. A constructor is qualified like a function, `Net.Http.Request(...)`.

A nullary constructor is a value. A single-positional constructor is a function value. A named constructor is neither; it appears only in construction syntax. A qualified operator is a function value, `Int.+`.

### 5.7 Pipe

`x |> e` applies `e`, a function value or a call, with `x` inserted as the first argument: `x |> f` is `f(x)`, `x |> f(a, b)` is `f(x, a, b)`. Parentheses around `e` change nothing: `x |> (f(a))` is `f(x, a)`.

```ernest-fragment
let words = input |> String.trim |> String.toLower |> String.toList
```

`|>` is left-associative and binds loosest, below `||`: `a + b |> f` is `f(a + b)`, `a |> b |> c` is `c(b(a))`. The right-hand side is an operand (Appendix A). A call is filled: the pipe fills its first-argument slot. Any other operand, a name, a qualified name, a field selection `s.f`, a block, a `match`, or a `receive`, is a value applied to `x`, and one whose value is not a function, or is a function of no parameter, is a type error: `x |> [f]`. Parentheses change nothing: `x |> (f(a))` is `f(x, a)`, and `x |> (f)` is `f(x)`. A construction is such a value and no call (Appendix A), so the pipe does not fill it: `x |> Some` is `Some(x)`, and `x |> Some(2)` and `x |> W(b = 2)` are type errors. A lambda is no operand and must be parenthesized, `x |> (fn(y) = y + 1)`. In a chained call the pipe fills the outermost call: `x |> f(a)(b)` is `f(a)(x, b)`. A function a call computes is applied in writing, `f(a)(x)`. The type of `x` is the target's first parameter type.

### 5.8 Conditional

`if c then a else b` with `c : Bool`; the branches have the same type.

### 5.9 `match`

A `match`, like a `receive` (§6.3) and a block, ends at its own `}` and may stand as an operand: `n > 0 && match x { ... }`. `if` and a lambda end in no delimiter of their own, and stand as an operand only in parentheses. The value is matched against the clauses' patterns in order; the first clause whose pattern matches and whose guard holds is evaluated. A clause may list several patterns separated by `or`, an *or-pattern*, and matches when any of them does: for `type Player = Player(alive : Bool, body : List(Int))`, `Player(alive = false) or Player(body = []) -> 0` matches a player that is not alive or has no body. Every alternative binds the same variables at the same types; the guard and the body see them. Alternatives that bind different variables are a type error. The clauses together must cover the type, and a `match` that does not is a type error; guards do not count toward coverage. `true` and `false` together cover `Bool`. A clause, or an alternative of one, is *redundant* when it can match no value the clauses and alternatives before it leave unmatched, and a redundant clause is a type error: `n -> n | 0 -> 1`. For redundancy, a bitstring pattern in an earlier clause is taken to match no value, and one in the clause being judged to match any value. A guarded clause before the one being judged is taken to match no value, so `n when n > 0 -> 1 | n -> 0` is not redundant. A guard is a `Bool` expression with no mailbox effect that sees the pattern's variables and the enclosing scope. A guard that is `false` falls through to the next clause; a guard that faults faults the process. A `receive` guard falls through likewise, and is restricted further (§6.3).

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

A segment without specifiers is `int` of size 8. A segment is `big` and `unsigned` unless it is marked otherwise. An `unsigned` segment of n bits holds 0 to 2^n − 1, and a `signed` one −2^(n−1) to 2^(n−1) − 1. `<<-1:signed>>` is the byte `0xFF`: the pattern `<<x>>` matches it with `x` bound to 255, and `<<x:signed>>` with `x` bound to −1. `signed` and `unsigned` apply to `int` segments, and `big` and `little` to `int`, `float`, `utf16`, and `utf32` segments; any other combination is a type error. `int` binds to `Int`, `float` to `Float`, the `utf` forms to `Char`, `bytes` to `Bytes`. A segment names at most one type (`int`, `float`, `bytes`, a `utf` form), one endianness, one sign, and one `size`: two of one kind, or one written twice, is a type error, `x:big-little`. A `float` segment is 16, 32, or 64 bits. A `utf` segment has no size. In a pattern, a `bytes` segment without a size takes the rest of the value and is the last segment. In a construction, a `bytes` segment without a size is its whole value, wherever it stands. The specifier names are specifiers only where a `BitSpec` stands, after a segment's `:` or `-`. Elsewhere, in a bitstring as outside one, they are ordinary identifiers: in `<<size:size(int)>>`, the first `size` and `int` are variables.

A bitstring's total bit count, in construction and in a pattern, is a multiple of 8. A violation of these rules the compiler can see is a compile-time error; one that depends on a dynamic size faults at construction (§7.4) or fails to match. A value that does not fit its width is an error too: a numeric literal, negated or not, that does not fit a segment of constant width is a compile-time error, in a construction and in a pattern, and any other value that does not fit faults at construction or fails to match. `<<-1>>` is a compile-time error, and `<<n>>` with `n` −1 faults. A segment pattern is a variable, `_`, or a literal of the segment's type, a negative numeric literal among them: `<<-1:signed>>`. `size(Expr)` in a pattern is a variable, a top-level `let`, an `Int` literal, or `+`, `-`, or `*` applied to these. The variable is bound by an earlier segment of the same bitstring, or is in scope where the pattern stands: a parameter, a block `let`, a pattern variable of an enclosing clause, or a lambda's capture. A top-level `let` is read when the `match` begins, after its scrutinee, or when the `receive` begins. A variable bound elsewhere in the same pattern is not in scope in its sizes. Any other segment pattern or size expression is a type error. A negative or out-of-range size fails the match. Construction evaluates the segments left to right. A `bytes` value fits a sized segment only when it is exactly that long. A negative size fits no value. A `float` value is rounded to a 16- or 32-bit width to nearest, ties to even, and a value too small for the width becomes `0.0`; one whose magnitude exceeds the width's largest finite value does not fit. `<<>>` is the empty `Bytes`.

```ernest
fn frame(bodySize : Int, body : Bytes) : Bytes =
    <<bodySize:size(16)-big, body:bytes>>

fn parseFrame(bytes : Bytes) : Optional(#(Int, Bytes, Bytes)) =
    match bytes {
        <<bodySize:size(16)-big, body:size(bodySize)-bytes, rest:bytes>> ->
            Some(#(bodySize, body, rest))
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

`self()` is the process's own address. `send(a, v)` places `v` in the mailbox of `a` and returns at once; sending to a dead process has no effect. To a process of another node it hands `v` to the runtime and returns, and waits only while what waits to be sent to that node exceeds the host's buffer (§8.7). A `send` promises the sender nothing. The one silence in the language is an act on what has ended, or cannot be reached, that asks nothing back, which does nothing and says nothing: a message whose receiver has ended or restarts (§6.9), or whose request has timed out or been answered, is dropped; a message or a `kill` to a process whose node is out of reach or not listed vanishes, while the process may live on (§8.7); and a `kill` (§6.9), a close or a `give` of a resource that has ended (Appendix E.18, E.23) does nothing. A program's end keeps no promise (§8.6). Every other failure is a value, a message, or a fault (§7).

`spawn(f)` starts a process on the running node that runs `f()` and returns its address. `self()` inside `f` is the new process's address; a parent that wants replies binds `let me = self();` before `spawn`. The effect `n` of `f` appears in `Address(n)` and so is a mailbox type (§3.9). A pure `f` fits, as a pure function fits wherever one with a mailbox type is expected, and `n` is then what the context makes it. A process that never receives is spawned with `fn() : Unit with Never = ...`. A node is one running runtime; a peer is another node it knows by name (§8.3). `Peer.spawn(name, f, ms)` and `Peer.spawnMonitored(name, f, wrap, ms)` start the process on the peer named, and answer its address or a failure, as a value (§8.7, Appendix E.27). The values `f` captured cross to the peer (§3.11).

`spawnMonitored(f, wrap)` starts the process as `spawn(f)` does, and the caller monitors it from its start (§6.9): `wrap(d)` is placed in the caller's mailbox when it ends, with its reason, however soon that is.

### 6.3 `receive`

`receive { clauses }` matches the mailbox in arrival order. The first message that matches a clause's pattern and guard is removed and the clause is evaluated; the rest remain. If none matches, the process waits. Patterns are typed against the mailbox type. Coverage is not required: a message no clause matches stays in the mailbox. A redundant clause is a type error, as in a `match` (§5.9).

A guard selects a message without removing it, so a `receive` guard is a *guard expression*. Its operands are the variables in scope, the pattern's and a lambda's captures among them, literals, negative numeric literals, and nullary constructors. A top-level `let` is an operand too, read when the `receive` begins. A guard expression is `true`, `false`, an operand of type `Bool`, a comparison of two operands with `==`, `!=`, `<`, `<=`, `>`, or `>=`, `!` before a guard expression, or two guard expressions joined by `&&` or `||`. `<`, `<=`, `>`, and `>=` compare the types whose `compare` §9.6 provides, in its order (§3.10). A guard expression calls nothing and cannot fault.

A final clause `after t -> e` gives a time limit of `t` milliseconds; `t` is evaluated on entry, and corrected as §7.4 says. A time has no upper bound. When the limit passes without a matching message, `e` is evaluated. `after 0` does not wait for a message. Without `after` there is no limit.

### 6.4 Message ordering

Messages from one process to another are received in sending order. Between different senders there is no ordering.

### 6.5 Addresses

`Address(m)` identifies a process on a node and carries its protocol: `send(a, v)` is type-checked against `m` on any node. `via(addr, f)`, §9.5, is `addr` seen through `f : (a) -> b`: sending `v` to `via(addr, f)` sends `f(v)` to `addr`. `f` is applied on the node where `via(addr, f)` was made: by the `send`, in the sender, when the sender is on that node, and on arrival there when it is not. A `send` that applies `f` returns once `f` has, and a sender's messages keep their order through it (§6.4), with one exception: a message to an adapted address made on another node than the sender's takes one step more, on the node that made it, and a message sent straight after it can pass it (§8.7). An adapted address crosses to another node as a reference to `f` and the values `f` captured, which cross as payload and are touched on no other node (§3.11). A `send` to it from another node carries `v` to the node where it was made, where `f` is applied and `f(v)` is sent on to `addr`, on whichever node its process is. `via(self(), Wrap)`, with `Wrap : (Int) -> Msg` and the mailbox type `Msg`, is an `Address(Int)`; a value sent to it arrives as `Wrap(v)`. A fault in `f` is the target's, on one node and across nodes alike: the process `addr` names dies of it, and the sender goes on.

Addresses have no equality (§3.10). The process behind an address is `Process.fromAddress(a)`, a value with equality that nothing can be sent to and that `monitor` watches (§6.9, Appendix E.21). There is no registry. A process reaches another through an address it holds or received, through a top-level binding that holds one, which is a *service*, or, from another node, through a key the service is offered under (§8.7):

```ernest-fragment
export type LogMsg = Line(String)

export let log : Address(LogMsg) =
    spawn(restarting(RestartLimit(restarts = 3, within = 5000), logger))
```

`restarting` keeps the service's address across its faults (§6.9). The address is the permission to send to the process and to kill it; a service binding grants it to the modules that see the binding (§4.2), and an offer under a key to every peer of the node (§8.7).

### 6.6 Request-reply

A request carries a `Reply(a)`, a one-shot address for its answer.

```
Address.call        : (Address(m), (Reply(a)) -> m, Int) -> Optional(a) with n
Address.callForever : (Address(m), (Reply(a)) -> m) -> a with n
answer              : (Reply(a), a) -> Unit with m
```

`Address.call(address, request, ms)` allocates a fresh `r : Reply(a)`, sends `request(r)` to `address`, and returns `Some(v)` when the recipient answers or `None` after `ms` milliseconds, `ms` corrected as §7.4 says. The clock starts at the call. `request(r)` is evaluated in the caller and sent from there as `send` sends it (§6.5). `ms` bounds the wait for the answer and nothing before it: the request is evaluated and sent though the `ms` milliseconds have passed, and a wait that begins after they have passed ends at once. A reply that arrives together with the timeout may be delivered or discarded. `Address.callForever(address, request)` waits without limit and returns `a`. When the process `address` names has ended, or ends or restarts before it answers, the wait ends at once, and so it does when the process's node goes out of reach (§8.7). `Address.call` then returns `None`, which says that no answer came, and nothing of whether the request was received or ran. `Address.callForever` faults the caller: with the callee's cause where the callee faulted, restarted after its fault or not, with `Fault("callee was killed")` where it was killed, with `Fault("callee returned without answering")` where its function returned, with `Fault("callee was closed")` where the program closes it, a socket or a listener (Appendix E.18), with `Fault("callee was restarted")` where it restarted because a restart was asked of it (§6.9), with `Fault("callee had ended")` where it had ended before the call, and with `Fault("callee is unreachable")` where its node went out of reach (§8.7). Where the program ends, the caller ends with it. A request handed on to another process is watched only at the process it was sent to. `answer(r, v)` sends `v` to the caller. A call's reply travels by an identifier private to the call, never through the caller's mailbox. A late answer, after a timeout or the caller's death, is discarded silently, as is a second answer to a `Reply` already answered, which only foreign code can give (§4.7). The recipient cannot observe whether the caller still waits.

**The rule.** A `Reply`, and every value that contains one, is *consumed* exactly once on every path from where it is bound. `answer(r, v)` consumes a `Reply` by answering it. Every other consumption hands the obligation on:

- Passing the value to a function whose parameter is reply-carrying at that instantiation hands it to the callee. A callee that duplicates or discards the parameter rejects the call (§3.9).
- `send` hands it to the `receive` clause that binds the value.
- Placing it in a constructor field or tuple component of reply-carrying type, or in a list by `::` or a list literal, hands it to the built value.
- Returning it from a function whose result type is reply-carrying hands it to the caller.
- Capturing it in a lambda hands it to the lambda, which then carries the obligation by its capture (below). The lambda may be bound by a `let`. It, or the name bound to it, is consumed exactly once, by a call or as the first argument of `spawn` or `spawnMonitored`, the function the spawn runs, and any other use of it is a type error. `let f = fn() = worker(r); spawn(f)` is legal; with `f()` after the `spawn`, `f` is consumed twice, and `let h = f` is a type error. A local `fn` may not capture a reply-carrying value; such a capture is a type error.

A value is bound by a parameter, a `let`, a pattern variable, a `receive` variable, a lambda's capture, or the result of a call, and each binding is an *obligation*. The check is per function and crosses no call boundary. It is static: every path makes the consumption, and whether execution reaches it is not checked. A call to a function whose result type is a type variable that neither a parameter's type nor its mailbox type names consumes every obligation open on its path, since the call does not return; `fault` (§7.4) is one. A function whose result type is its mailbox type returns what it receives, `fn next() = receive { x -> x }`, and a call to it consumes nothing. The `request` callback of `Address.call` is checked by the rule: `r` is consumed by placement in the message `request` returns, and `Address.call` discharges the message.

```ernest-rejected
type Request = Get(reply : Reply(Int)) | Stop

fn serve(request : Request) : Unit with m =
    match request {
        Get(reply = reply) -> answer(reply, 42) // accepted: reply is answered on its one path
      | Stop -> Unit // Stop carries no reply
    }

fn twice(server : Address(Request), request : Request) : Unit with m = {
    send(server, request);
    send(server, request) // rejected: request is consumed twice
}
```

**Which values contain a reply.** A type is *reply-carrying* if it is `Reply(a)` or has a constructor field, tuple component, or list element of a reply-carrying type. The property is transitive: `Request` above is reply-carrying, and so is `type Envelope = Env(msg : Request)`. It is by type, not by constructor: every value of `Request` is reply-carrying, `Stop` included. A declared type is reply-carrying at an instantiation whose fields, its arguments substituted, have a reply-carrying type: `Box(Reply(Int))` is, for `type Box(a) = Box(a)`, and `H(Request)` is not, for `type H(e) = H(f : (Int) -> Unit with e)`. A type whose operations are the runtime's, and `Address`, is never reply-carrying through its arguments: `Address(Request)` is not; `List` is, through its elements. A function type is never reply-carrying; a lambda that captures a reply-carrying value carries the obligation by its capture (above).

**Where such a value may stand.** A reply-carrying value stands only as a constructor field, a tuple component, a list element, a function parameter, an operand of an operator a member answers among them (§4.8), a variable bound by `let`, by a pattern, or in a `receive` clause, a capture of a lambda, the scrutinee of a `match`, the right side of `<-`, the value of a branch or of a block, or the result of a function whose result type, declared or inferred, is reply-carrying. Anywhere else it is a type error: as an operand of `==` or `!=`, as the value a field is selected from, and as the base of a record update, among them. A top-level binding of reply-carrying type is a type error.

**Patterns and branches.** A match consumes its scrutinee, and the obligation passes to the variables the pattern binds. A pattern on a reply-carrying value binds every reply-carrying field and element, so `_` or an omitted field there is a type error: `match request { Get() -> ... }` is rejected. `as` on a reply-carrying scrutinee is a type error. A constructor with no reply-carrying field, `Stop` above, and the pattern `[]` discharge the obligation. An `if`, `match`, `receive`, or block whose value is reply-carrying consumes it or hands it on in every branch. The right operand of `&&` and of `||` is a branch the left operand may skip (§4.8), and what follows a `let p <- e` in its block is a branch a `Left` or a `None` skips (§5.5). An obligation open before either is consumed before it or after it, and not in it: `if c && done(r) then a else b` is a type error, and so is `{ let n <- String.toInt(text); answer(r, n) }`, which is written as a `match` on `String.toInt(text)`. A guard is pure (§5.9) and its value is a `Bool`, so it can neither answer a reply nor hand one on: a guard that takes one does not return, and a guard that falls through has consumed none.

### 6.7 Remote computation

Work on a peer is a process spawned there, `Peer.spawn(name, f, ms)` (§6.2, §8.7), and its result reaches another process as a message. The program names the node at the spawn: the runtime chooses no node for it. The spawn answers the process's address, or a failure the program matches on, within `ms` milliseconds (Appendix E.27).

### 6.8 `Never`

A function with mailbox type `Never` can send but never receive: a `receive` with a pattern clause written in a body of mailbox type `Never` is a type error, and a `receive` with only an `after` clause is how a `Never` process waits. A function whose mailbox type is a variable, called at `Never`, waits in its `receive` for a message that cannot come, and where nothing else can run the entry process faults with `Fault("deadlock")` (§8.6).

`with Never` annotates a process root that never receives: `main`, or the function a spawn lambda calls. A function so annotated can only be called where the mailbox is `Never`; a send-only helper called from process code is polymorphic instead, `with m`, as `Io.println` in Appendix E.

### 6.9 Death

A process dies when its function returns, when `kill` is called on it, on a fault (§7.3), or when the program ends (§8.6). Its `Reason` (§9.3) says which: `Returned`, `Killed`, `Fault(cause)`, or `ProgramEnd`. A monitor on a process of another node gives `Unreachable` when that node goes out of reach, which says nothing of whether the process lives (§8.7). A process the host ends otherwise, killed by foreign code or by the end of a process it is linked to, has the reason `Fault(text)`, `text` the host's term as the host writes it. `kill` is asynchronous: the target may run until the runtime interrupts it. `kill` on a process that is dead has no effect, and `kill` on a process of another node reaches it as `send` does (§6.2).

`monitor(p, wrap)`, §9.5, places `wrap(d)` in the caller's mailbox when the process `p` dies; `d : Down` gives the process and the cause. `p` is a `Process`, the identity of a process (Appendix E.21), which `Process.fromAddress(a)` gives for an address `a`; `kill` takes the address (§6.5). `process` in `Down` is `p`. If `p` is already dead, the message is placed at once, with the reason `Unknown`. A `monitor` made while the process runs gets its reason, and a process started with `spawnMonitored` (§6.2) is monitored from its start. Each `monitor` call produces one message. A `Down` comes from the runtime and has no order with the messages the ended process sent (§6.4). The answer to a call (§6.6) is not overtaken by the callee's `Down`. A `wrap` has no sender to run in: the runtime applies it as it delivers the message. A fault in it is the fault of the process it delivers to, and a `wrap` that does not finish holds up no other delivery.

`site` in `Down` is where the dead process was spawned: the qualified name of the top-level declaration in which the `spawn` or `spawnMonitored` that started it is written, with the line where it is written: `Counter.main:19`. A `spawn` in a lambda or a local `fn` counts as written in the top-level declaration that contains it. Where `spawn` is passed as a value, it counts as written where its name is. For the entry process it is the entry point's name. With the reason `Unknown` or `Unreachable` it is the empty string; otherwise it is what the node that spawned the process recorded, and crosses in the `Down` (§8.7).

A monitor is the one link between processes; there is no other. A process the program spawns belongs to no one, and ends only as this section says. A process the runtime starts for a resource, a socket, a listener, or a program the runtime started, belongs to the process that opened it or was given it, and is killed when that process dies. Closing the resource ends its process with the reason `Returned`, and killing its process closes it.

`restarting(RestartLimit(restarts = n, within = t), f)`, §9.5, is a function that runs `f()` and, when `f` faults, runs `f()` again in the same process. The process keeps its address, and the new run begins with nothing of the old one that the process holds: what it spawned, opened or put in a table lives on. Its mailbox is emptied, the message being handled lost with the rest, and every call waiting for an answer from it ends (§6.6). What the process has asked the runtime for is cancelled, whenever it asked, before its first run or in any run: its alarms (Appendix E.15), its monitors, and its subscriptions to the terminal (§8.2) and to faults (Appendix E.21). A message that arrives while the process restarts is dropped or taken by the new run. A restart is not a death, and no `monitor` is told of it. When `n` restarts have happened within the last `t` milliseconds, the next fault is not restarted; a window below 1 is 1, and a count is corrected as §7.4 says. A fault restarts the innermost restarting function the process runs, which counts it against its own limit; one that does not restart it gives it to the restarting function around it, and the process dies with its cause where there is none. A restarting function counts from when it is entered, so one entered again by the restart of the one around it counts afresh. `restarting(Unlimited, f)` runs `f()` again after every fault. `f` returning, a `kill`, and the program's end end the process as they end any other.

A child of a `Supervisor` (Appendix E.22) also runs `f()` again when its supervisor asks. It runs on until it next waits, in a `receive` or for a call's answer, and there runs `f()` again; a process already waiting does so at once. It restarts as a fault restarts it (above). A restart asked for is not a fault: it counts against no limit, and no fault is reported. Where `f` itself runs a `restarting` function, the restart asked for runs `f()` again, not the inner one.

### 6.10 Code replacement

A process replaces its code by a message in its own type that carries the new loop, and switches with a tail call:

```ernest
type CounterMsg =
    Inc(Int)
  | Get(reply : Reply(Int))
  | Upgrade(migrate : (Int) -> Int, next : (Int) -> Unit with CounterMsg)

fn count(total : Int) : Unit with CounterMsg =
    receive {
        Inc(amount) -> count(total + amount)
      | Get(reply = reply) -> {
            answer(reply, total);
            count(total)
        }
      | Upgrade(migrate = migrate, next = next) -> next(migrate(total))
    }
```

A function does not cross nodes (§3.11), so a process on another node is sent its `Upgrade` by a process spawned on that node, whose function captures nothing bound and names the service and the new functions as top-level bindings, which are the peer's (§8.7): `let _ = Peer.spawn(name, fn() = send(Counter.service, Upgrade(migrate = Counter.double, next = Counter.count2)), 5000)`. The language has no other mechanism for code replacement. The shell's reload (§11.2) runs a call by name on the new code, and a call through a function value on the version current where the value was taken, and never changes the code a running process runs; a process whose code the shell can no longer keep faults with `Fault("its code was unloaded")` (§7.4).

## 7. Errors

There are no exceptions. An error is a value, a message, or a fault.

### 7.1 Value errors

The error is part of the function's meaning and is in its result type, `Either(e, a)` or `Optional(a)`. The caller matches on the result or chains with `let p <- e` (§5.5).

### 7.2 Message errors

The error crosses a process boundary and is in the message: `Either`, or a constructor of the reply type. A missing reply is `None` from `Address.call`, after the time limit or once the callee has ended or restarted (§6.6).

### 7.3 Faults

A fault ends the process that meets it, with the reason `Fault(cause)` that `Down` carries (§6.9), unless the process restarts (§6.9). The code cannot see it, and nothing catches it. Its causes are those §7.4 lists and those a standard library function's section gives, the supervisor's among them (Appendix E.22), each with its text. A process that is killed, or that ends with the program, has not faulted.

### 7.4 Causes of faults

A function answers a failure as a value: `Optional` where the failure has no cause the program can act on, `Either` where it has one (§7.1, E.0 shape rule 4). A function faults only where it cannot return, where its result is a `Float` the finite range cannot hold (§3.1), or where the failure is the runtime's own, a boundary crossed, a limit of the host met. An operator and a construction the grammar gives fault. A refused request faults the process that made it; a failure no request stands behind, a standard input that cannot be read or keys that are not UTF-8 among them (§8.2), faults the entry process; standard output or standard error that cannot be written ends the program without a fault (§8.6). A count or a duration below 0 is none, and a restart window is corrected as §6.9 says; a duration has no upper bound, and a moment already past is now; no other value is corrected unsaid. A pure function can fault. The causes are these, and a standard library function's section gives its own:

- `/` and `%` on `Int` with a zero divisor: `Fault("division by zero")`. `Int.div` and `Int.rem`, Appendix E.8, return `Optional` instead.
- `Float` arithmetic whose result the finite range cannot hold (§3.1): `Fault("float arithmetic error")`. `Int.toFloat` of an integer that rounds beyond the largest finite `Float`: `Fault("Int out of Float range")`.
- Bitstring construction (§5.11). A value that does not fit its width, other than a literal the compiler refuses: `Fault("segment overflow")`. A dynamic total bit count that is not a multiple of 8: `Fault("bitstring not byte-aligned")`.
- `fault(c)`, which compiles at any type: `Fault(c)`.
- `Address.callForever` whose callee has ended, or ends or restarts before it answers (§6.6): the callee's cause, `Fault("callee was killed")`, `Fault("callee returned without answering")`, `Fault("callee was closed")`, `Fault("callee was restarted")`, `Fault("callee had ended")`, or `Fault("callee is unreachable")` where the callee's node went out of reach (§8.7).
- `Peer.offer` under a key a living process holds (§8.7): `Fault("k is offered by a living process")`, `k` the key's name. `Peer.offer` of an address that names no process of the running node: `Fault("an offer names a process on its own node")`.
- A foreign function that raises: `Fault("foreign function m:f/n raised ...")`. A function of the program's that foreign code calls faults as it would anywhere, and the foreign function passes the fault on as it is; a restart asked for while it runs is a restart (§6.9). A foreign function's return is checked against its declared type when the function returns, and a reply foreign code gives (§8.4) when `Address.call` or `Address.callForever` returns it, each in the calling process and to the value's whole depth; a function value in it is checked when it is called, its result against its declared result type. A mismatch faults the calling process: `Fault("foreign return does not match T")`, `Fault("reply does not match T")`, and an argument foreign code gives an Ernest function `Fault("foreign argument does not match T")` (§8.4). A message from a foreign process that does not match the mailbox type faults the receiver on delivery (§8.4): `Fault("message does not match M")`. Each names the declared type. Each check reaches as far as §8.4 has it reach: its **What is checked** and **Type variables** say what crosses unchecked.

Beside the list, these faults are raised. A failure in the runtime faults the process that meets it with the host's class and reason, as a spawn beyond the host's limit of processes does with `Fault("error:system_limit")`. A fault in a function adapting an address faults the target with its own cause (§6.5). `Os.exit` with a status outside 0 to 255 faults its caller with `Fault("an exit status is from 0 to 255")` (Appendix E.23). In the shell and under `ern test`, `Os.exit` with a status `n` from 0 to 255 faults its caller with `Fault("exited with status n")` (§11.2). A working directory the host can no longer read as the program starts faults the initializer of `Os.workingDirectory` with `Fault("the working directory cannot be read: r")`, `r` the host's reason, and so ends the program before `main` runs (§8.5, Appendix E.23). A deadlock faults the entry process with `Fault("deadlock")` (§8.6), and under `ern test` the process of the test that runs (§11.2). The unloading of the code a process runs faults the process with `Fault("its code was unloaded")` (§11.2), and a use of a binding a faulting reload left without a value faults its reader with `Fault("the binding has no value, since one before it faulted")` (§11.2). A subscription to the terminal after it was read as lines faults the subscriber with `Fault("the terminal is already read as lines")`, and a read of a line or of bytes after it was claimed for keys faults the reader with `Fault("the terminal is already read as keys")` (§8.2). While a shell holds the terminal, subscribing to it or reading a line or bytes from any other process faults that process with `Fault("the shell holds the terminal; run the program with ern run to give it the keyboard")` (§11.2). A line of standard input that is not UTF-8 faults the process that asked for it with `Fault("the standard input is not UTF-8")`, and keys that are not UTF-8 fault the entry process with the same cause (§8.2). A standard input that cannot be read faults the entry process with `Fault("the standard input could not be read: ...")`, the host's reason after the colon (§8.2).

## 8. Programs

### 8.1 `main`

The entry point is a function of type `() -> Unit with m`. The process that runs it is the *entry process*. `m` is the message type when the entry receives. It is `Never` when the annotation says so. Otherwise it is polymorphic, and the runtime instantiates it to `Never`. A pure function of type `() -> Unit` is an entry point too, and its process's mailbox type is `Never`. A result type that is a type variable, as a function that never returns has, is taken as `Unit`, as a mailbox type that is a variable is taken as `Never`. A top-level `let`, a function of another shape, and a private function are not entry points, and `ern run` refuses them. `ern run module.erc` runs the `export fn main` of that module; `ern run --main Qualified.name module.erc` runs another exported function of that shape. `main` is a convention, not a reserved name.

### 8.2 System references

The runtime starts its system processes when the program starts, whether or not the program uses them. Each process's address is a top-level binding of its *system module* in the standard library, private to that module: `stdout`, `stderr`, and `stdin` of `Io`, and `reference` of `Terminal`, `Clock`, `Fs`, `Tcp`, and `Os` (Appendix E). A program uses each through its module's functions. The binding's initializer is a `foreign fn` of the module that answers the runtime's address (§4.7), evaluated before the program's other bindings (§8.5). The message type is declared in the module, in Ernest, for the module and for the foreign process behind it (§8.4), and no other module can make a message of it. A runtime may provide more system modules. In a process spawned on a peer, a system module's binding is the peer's: `Io.println` there writes to the peer's standard output (§8.7).

**Standard output and standard error.** `stdout` writes the bytes it receives to standard output as they are, and adds nothing; a string reaches it as its UTF-8 bytes. `stderr` does the same to standard error. A write returns once its stream has taken the bytes, and waits while the stream is behind. A stream that can no longer be written, its reader gone or its device failing, ends the program (§8.6), and what was still to be written to it is lost.

**Text from the host.** Text the host gives a program is UTF-8, or is an error of the function that met it: a value where the function's type carries one, and a fault of the process that asked where it does not. Nothing is left out for its bytes; where a whole cannot be given as text, a directory's listing or an environment, the error names it.

**Standard input.** Standard input is read as UTF-8, whatever the host's locale. `stdin` answers each request with the next line, without its line feed and without one carriage return before the line feed, and with `None` at end of input. A last line without a line feed is a line, and keeps a carriage return it ends in. A line that is not UTF-8 faults the process that asked for it with `Fault("the standard input is not UTF-8")` (§7.4). A standard input that cannot be read faults the entry process with `Fault("the standard input could not be read: r")`, `r` the host's reason (§7.4). A request for bytes is answered with what has arrived, at least one byte, and `None` at end of input. A line is read whole however long it is. Lines and bytes are read from one stream, each request taking up where the one before it stopped.

**The terminal.** The terminal sends each subscriber an `Event` (Appendix E.16) for every key pressed and for every change of the terminal's size. A process holds one subscription to the terminal: a second `Terminal.subscribe` replaces the first, and its wrap is the one used from then on. A subscription ends when its process dies or restarts (§6.9). Where standard input is not a terminal, a subscription is refused with `Left(NotATerminal)` and claims nothing, whether or not a line or bytes were read before it. The terminal answers a request for the size with the size now, and with `Left(NotATerminal)` where standard output is not a terminal or its terminal has no rows or no columns (Appendix E.16). The terminal and standard input are one terminal, read as keys or as lines: a subscription that is granted claims it for keys, and a read of a line or of bytes claims it for lines. Keys are read as UTF-8 too, and keys that are not UTF-8 fault the entry process with `Fault("the standard input is not UTF-8")`. The first claim stands, and a claim the other way faults the process that makes it (§7.4). A subscription after a line or bytes were read faults the subscriber with `Fault("the terminal is already read as lines")`. A read of a line or of bytes after a subscription was granted faults the reader with `Fault("the terminal is already read as keys")`.

**Keys.** A subscription is answered once the terminal is in the mode the keys need: nothing typed after `subscribe` returns is echoed. While a program is subscribed, the terminal delivers each key as it is pressed and does not echo it, and the runtime gives the terminal back with the settings the program found when the program ends. A key the terminal sends as one character arrives as `Key` of it, a control character among them: Enter is `Key('\r')`, or `Key('\n')` where the terminal sends a line feed, Backspace `Key('\u{7f}')` or `Key('\u{8}')`, and Tab `Key('\t')`. The escape character begins a sequence: an arrow's arrives as the arrow, and one the runtime does not name as `Escape` and the characters after it. `Escape` is delivered once no escape sequence can still follow it. The terminal applies each subscriber's wrap itself, keeping its keys in order. A wrap that does not finish delays that subscriber's keys and no other's.

**Paste.** While a program is subscribed, the runtime asks the terminal to bracket a paste. Pasted text then arrives as one `Pasted`, not as the keys of its characters, and its line endings are line feeds. A paste whose end the terminal does not send ends when no more of it arrives, what came of it being the `Pasted`, and an end that comes after it is nothing. A terminal that does not bracket a paste sends its characters as keys.

**Interrupt.** While the terminal is claimed for keys, its interrupt is delivered to every subscriber as `Interrupt`, in place of the signal that would end the program (§8.6). Otherwise that signal ends the program.

**The clock, the file system, TCP, and the host's programs** answer their modules' requests as Appendix E.15, E.17, E.18, and E.23 say.

### 8.3 Peers

A *node* is one running runtime, and a *peer* is another node this one knows by name. A node is a program started with `--config-dir` (§11.2): its configuration directory holds `ernest.conf`, which lists its peers, each by a name, a public key and a network address (§11.3, Appendix C), and its own key, by which nodes authenticate each other (§8.7). A program started without `--config-dir` is no node, has no peers and listens to nothing. The module `Peer` (Appendix E.27) acts on a peer by its listed name: `Peer.spawn(name, f, ms)` and `Peer.spawnMonitored(name, f, wrap, ms)` start a process there as `spawn(f)` and `spawnMonitored(f, wrap)` start one on the running node (§6.2), and `Peer.offer` and `Peer.find` offer a service to the node's peers under a key, and find one (§8.7). Every node runs the same compiled program, whole, and no code crosses between nodes; what crosses is §3.11's.

### 8.4 Foreign code

The system processes are foreign processes: their message types are declared in Ernest, their implementations live outside the language, and the runtime starts them (§8.2). Other foreign code enters through `foreign fn` and `foreign type`, §4.7. Both boundaries carry the same promise: the foreign side delivers the declared types, and a breach faults the receiving Ernest process: a bad return value or reply when the call returns, a bad message on delivery. A bad message's fault takes the message's place in the receiver's mailbox, and the receiver faults at the wait that reaches it, in a `receive` or for a call's answer, as at a fault of its own, which `restarting` restarts (§6.9).

**What is checked.** The standard library and the system processes are the runtime's own, and what passes between them and a program is not checked: the return of one of the library's foreign functions, a message from a system process, an address or a `Reply` given to either, and the answer to a call the library makes. A message from a peer is not checked on arrival: its type is known at both ends and the same at both (§3.11), and a value of another type a faulty peer sends is met where the receiving process matches on it (§8.7). Everything else is checked where it crosses.

**Addresses and answers.** An address that foreign code gives, in a return, a reply, a message, or an argument it calls an Ernest function with, is *foreign* unless it names a process of the program. An address of the program's that foreign code gives back is the program's own at the type it crossed at, and foreign at any other. What is sent to it at another type is checked as a message foreign code sends. A process of the program's whose address foreign code was never given, one it names by its own `self()` in a `foreign fn` or by a `Process` it was given, is a bad value where foreign code gives it as an address, except as an `Address(Never)`, through which no message passes. A message sent to a foreign address, an answer given to a `Reply` foreign code gave, and a foreign function's argument cross into foreign code: a message foreign code sends to an address in one is checked on delivery. That check lasts until the process the address names ends, and there is one for each distinct address that has crossed. An address made by `via` is distinct by its function and by the values its function captured. An answer foreign code gives to a call is checked when `Address.call` or `Address.callForever` returns it. An answer Ernest code gives to a `Reply` foreign code gave crosses into foreign code, and no other answer is checked.

**Functions.** A function that crosses into foreign code, a foreign function's argument or one inside it, in a message or in an answer, has each argument foreign code calls it with checked against its parameter's type, and a mismatch faults the calling process with `Fault("foreign argument does not match T")`. `Foreign.from` gives its value as a foreign function's argument of the value's type crosses, an address in it behind its check and a function with its own (Appendix E.12).

**Type variables.** A type variable of a foreign function's result that no parameter's type names matches no value: `foreign fn cast(x : Foreign.Term) : a` faults whenever it returns, and a function that does not return, `Os.exit`, may be declared so. The check meets such a variable only at a value of it: an empty container holds none, and a value of a foreign type is not looked into, so a foreign function whose result is `List(a)` and empty, or `Table(k, v)` of a foreign type, returns. A type variable that a parameter's type names matches any value, in a foreign function's result and in an argument foreign code calls a function with. There the promise is the foreign side's alone: at such a variable it returns, and calls a function with, only values it was given at that variable. `foreign fn weird(x : a) : a` answering `2` for `weird([1, 2])` breaks the promise and is not caught at the boundary.

**What the checks do.** The checks catch a foreign side's mistake and confine nothing: foreign code runs within the runtime, and what it does there on purpose is not checked.

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

A process's end is a host term too, the `Reason` of §9.3 as the host sees it. The runtime ends a process with one of these terms; any other end is the host's (§6.9). A process that returned exits `normal`. One that faulted exits `{ern, fault, Cause}`. Where the fault is a failure in the runtime or a foreign function's raise (§7.4), it exits `{ern, fault, Cause, Trace}`, `Trace` the trace of Appendix E.21 as text. One killed, by `kill` or by its owner's death (§6.9), exits `{ern, killed}`, and one ended with the program `{ern, program_end}`. A socket or a listener the program closed exits `{ern, closed}`, which is `Returned` (§6.9). A process the shell ends because a reload unloaded its code exits `{ern, code_unloaded}`, which is `Fault("its code was unloaded")` (§7.4, §11.2).

Same-named constructors of different types share an atom; the receiver's declared type disambiguates. Cross-node transport uses the runtime's external term format for these representations. A `foreign fn` implementation is named `module:function/arity`, the arity its parameter count. The function is named as the host names it, an operator among them: `erlang:+/2`. A name not of that form, or whose arity is not the parameter count, is a compile-time error. A module or function the host lacks when the call is made raises, and the call faults as §7.4 says: `Fault("foreign function m:f/n raised error:undef")`.

### 8.5 Initialization

Before `main` runs, the runtime evaluates in the entry process, in dependency order, every top-level `let` of the standard library, and then of the entry point's module and of every module it depends on, directly or through others. The standard library is initialized whole, whether the program depends on each of its modules or not; another module the program does not depend on is not initialized. A binding depends on every top-level `let` its initializer names, and on what every function it names depends on, called or not; a lambda's body is part of its initializer. A member is named where an operator resolves to it (§4.8), and where it is supplied: by a requirement (§4.9), a fill (§5.6), or a derived `compare` (§3.5). A binding is evaluated after those it depends on, and otherwise in the order its module declares it. A module's bindings are evaluated after those of every module it depends on. `let handlers = [f]` is a cycle when `f` names `handlers`, and so is `let a = fn() = a()`. The order of modules that do not depend on one another is unspecified. A cycle is a compile-time error. Only `let` requires evaluation. An initializer runs as a body of mailbox type `Never` (§4.6), whatever the entry process's mailbox type: it receives nothing, and `self()` in it is an `Address(Never)`. A service it spawns runs from then on. The initializers of two modules that do not depend on one another print in no promised order, and within a module they print in the order the initializers run, as above. An initializer that faults (§7.4) ends the program with that fault before `main` runs. Its fault is reported under the binding, its qualified name and the line it is declared on, as a spawn site is (§6.9): `Init.bad:3 faulted: division by zero`. Which of two independent faulting initializers is reported is unspecified. An initializer that does not terminate prevents the remaining initializers and `main` from running. A node (§8.3) runs its initializers so, and listens to its peers only once all have their values (§8.7).

### 8.6 Program termination

The program ends when the entry process dies, whatever the reason (§6.9), a fault being reported on the runtime's exit indicator, when any of its processes calls `Os.exit`, which gives the status the runtime exits with (Appendix E.23), or when its standard output or standard error can no longer be written (§8.2). Live local processes then die with the reason `ProgramEnd`, and the runtime flushes the system processes' pending output before it stops. A process that faults once the entry process has died, at what the program's end ended, as an `accept` whose listener its owner's death closed, dies with the reason `ProgramEnd` too, and its fault is not reported (§11.2). Where a stream can then no longer be written, that ends the program (§8.2), in place of what ended it. For a program that is no node, a signal from outside, the host's termination or hangup, ends it the same way; for a node, termination ends it the same way, and hangup is a reload (§8.7). One that comes before the runtime can take signals, in the host's first fraction of a second, may be lost, or may end the program as the host ends it, with status 0 and a line of the host's own. The host's interrupt ends it at once, and output the system processes have not yet written may be lost. The runtime prints nothing of its own about a signal. A node that ends is no loss to its peers: its processes die with `ProgramEnd`, and the node stops in order, so that every `Down` already on its way crosses before its connections close (§8.7). A process this program spawned on a peer runs on there. A program that is to keep running waits in `main`.

When no forward progress is possible, the entry process faults with `Fault("deadlock")` (§7.4) and the program ends as above. No progress is possible when every live process waits in `receive` without `after` or in `Address.callForever`, no message is in flight, no monitor waits on a process the runtime did not start, and no system process, listener or socket (E.18) holds a timer, a subscription, a pending I/O, or a computation whose completion would deliver a message; a program that `Os.start` started counts as such a computation until it has exited or been killed (Appendix E.23). A node (§8.3) detects no deadlock: it can be reached from outside, by a message, a spawn or a connection. Whether a user-provided foreign process counts like a system process here is the runtime's choice.

### 8.7 Nodes

A node (§8.3) is identified by its key, which `ern config` makes with a certificate the node signs itself and `ernest.conf`, printing the public key that another node's configuration lists (§11.3). A configuration directory is made for one machine. Two nodes started from copies of one are one node to their peers, and each one's dial ends the other's connection, which the peer says on its standard error each time. As it starts, a node refuses a configuration directory, or a file of it that the node reads, that is neither its user's own nor the superuser's, or that anyone beyond its owner and group may write, as the shell's startup files are refused (§11.2), and a key that any but its owner may read or write. A program started without `--config-dir` is no node.

**Its configuration.** `ernest.conf` (Appendix C) holds the node's `listen`, its public key, its peers, its `keys` and its `measures`. `listen` is what the node's listener binds to, an address of one interface, or `0.0.0.0` or `::` for all of them, and a port, or port 0, at which the host picks one and the node says on its standard error which it bound; a node without `listen` does not listen, and only dials. A peer has a name, a public key and a `network-address`, `host:port`, the host a name or an address, an IPv6 address in brackets; a name is resolved by the host at each dial. A peer listed without an address is never dialled, and is out of reach until it opens a connection itself. A node runs over one family of addresses, IPv4 or IPv6, its listener's, or IPv4 where it has no listener; a peer whose address is of the other family, or whose name resolves only to it, is refused when the configuration is read, with an error that names the peer. `keys` lists, under a key's name, the peers that may offer it, by their names, in the order a find asks them; a key not listed is found nowhere. `measures` names which of the host's measures run on the node, `cpu`, `memory` and `disk`, each with the host's parameters under it, named by their meaning: `check-interval`, in milliseconds, and for `memory` a whole number of minutes, which the host's memory measure counts, and `almost-full`, a fraction from 0 to 1; `cpu` takes none, and none runs where the section is absent. A node refuses to start where `ernest.conf` is not JSON, gives a field it does not know or one twice, names a peer or a key twice, lists its own key as a peer's, or breaks a rule of this paragraph; its key is the one `ernest.conf` and the certificate name, and the refusal names the file and the rule.

**Its start and its end.** Each start of a node has a number of its own, which the host draws and puts in every address, so that an address of an earlier start is dead. A node runs its initializers as a program does (§8.5), and listens only once they all have their values; an initializer that faults ends the node as it ends a program. A node writes its process number to `ernest.pid` in its directory at its start and removes it at its exit; one that starts and finds the file naming a living process refuses to start, saying so, and overwrites a file a dead one left. A node ends when its program ends, or by termination, which `ern stop --config-dir dir` sends by `ernest.pid` and `kill -TERM` sends as well (§8.6, §11.2). A node that ends is no loss to its peers: its processes die with `ProgramEnd`, and the node stops in order, so that every `Down` already on its way crosses before its connections close. A peer's monitor on one of its processes gives `ProgramEnd`; only a monitor made after that gives `Unreachable`.

**What it says.** A node says on its standard error, one line each, that a peer connected; that a peer was lost, and whether it fell silent or closed; that a peer was refused for its key, or for its build; that a living connection was replaced by another from the same node; and what a reload did. Each line names the peer by its name in `ernest.conf`, and by its key's digest where it is not listed. Nothing is said for a message, a call or a spawn, and the host's own reports of its nodes are not written.

**A reload.** For a node, hangup is a reload and termination an end (§8.6). `ern reload --config-dir dir` sends the node named by `ernest.pid` the hangup signal, which `kill -HUP` sends as well (§11.2), and the node reads `ernest.conf` again. A peer added is listed, and nothing else happens until an operation dials it or it dials in. A peer removed, or one whose key changed, has its connection ended: both nodes run the loss, and the addresses a program holds of its processes are those of a node not listed. A peer whose address changed keeps an open connection, and the next dial uses the new address. A peer whose name changed under the same key keeps its connection; only the name a program uses changes. A change to `measures` starts or stops the host's services it names. The node's own key and `listen` cannot change while it runs: a file that changes either, or that does not parse, is refused, and the old configuration stays. The node says on its standard error which peers were added and removed, or why the file was refused; the signal carries nothing back.

**Connections.** Two nodes have at most one connection, opened by the first operation that needs it, over TLS 1.3 with a certificate on each side. A node accepts a peer whose public key its configuration lists, and no other; a certificate's name and dates mean nothing to it. A node finds a peer's address in its configuration, and nowhere else. Connections are not transitive: that A knows B and B knows C connects A and C in no way. Where both dial at once, one connection is kept. Each node computes at its start a fingerprint of its build: the digest of the protocol's version, `ern`'s version, the host's version, and the checksum of every compiled module on its load path, in name order, each as its name and the host's digest of its code, which leaves out documentation, line numbers and attributes; the standard library is not in it, `ern`'s version standing for it. Two nodes connect only where their fingerprints are equal, which the handshake proves before anything passes. A find or a spawn whose connection the peer refused fails with `Unreachable`, the refusing side saying why on its standard error.

**What passes.** A message is carried by the host as on one node, straight into the mailbox. Seven frames are the runtime's own: a message to an adapted address, which goes to the node that made it (§6.5); a spawn on a peer, and its answer; a find, and its answer; that a call waits, and that it gave up. A monitor and its `Down`, a `kill`, the answer to a call, a sign of life, and the proof that two nodes run one build are the host's. A node has one *gateway*, a process that takes every frame from every peer and hands each to a worker for the sender's node. A frame the gateway cannot read is faulty, and the node ends the connection. A message between nodes costs what the host's send costs; one to an adapted address made on another node than the sender's takes one step more, on the node that made it, and a message sent straight after it can pass it (§6.4, §6.5). The function of an adapted address must finish, across nodes as on one: a slow one delays what that peer sends through the gateway, and one that never finishes holds it for good.

**A loss.** A connection is lost when the network breaks it, when the detector finds it silent, or when a frame is faulty. Each node is told by its own host and runs the loss for itself: it gives a `Down` with the reason `Unreachable` and an empty `site` for each monitor held on the peer's processes, ends each call waiting on one of them, and drops what waited to be sent; nothing else ends, but a process waiting in `Address.callForever` on one of them, which faults (§6.6). A node whose peer dials it anew while it believes the old connection alive runs the loss of the old one first. Any traffic is a sign of life, and a tick is sent where nothing else was for 15 seconds; a peer from which nothing came in four such intervals is lost, so a silence is found in 45 to 75 seconds, and a peer that closes is found at once. A connection is opened again when an operation needs it, never in the background, and with no delay between one attempt and the next. A dial that is refused fails at once; one that nothing answers is given up after 7 seconds, and what waited behind it is then dropped. A node that cannot be dialled is reached only while it holds a connection open: after a loss, what the other node sends vanishes and its monitors say `Unreachable` until the first node next acts towards it.

**Addresses.** An address names its process for as long as the process lives, on whichever node, and a loss does not end it: when the two nodes connect again, the same address reaches the same process. An address of an earlier start of its node is dead: what is sent to it is dropped, a call through it ends at once, and a monitor on its process gives `Unknown`. An address is a value like any other, and is as good on a third node it is sent to as on the node that sent it. A monitor does not outlive a loss: the loss gave its `Down`, and a program that is to go on watching calls `monitor` again, on the process the `Down` names; while that process's node is out of reach, or not listed, the new monitor gives its `Down` with `Unreachable` once the dial has failed. A `send` or a `kill` to a process whose node is out of reach or not listed vanishes (§6.2).

**Messages.** `send` hands the message to the host and returns (§6.2). Where no connection is open the host opens one, and the message waits behind the dial: it is sent where the connection opens, and dropped where it does not. What waits to be sent to a peer waits in the host's buffer for that peer, 1 MB, and a `send` that finds the buffer full waits until it drains, at the latest until the detector gives the peer up; a process that waits so serves nothing from its mailbox meanwhile. A call, a find, a spawn and an `answer` send the same way, so that everything one process sends keeps its order. What one process sends another arrives in the order it was sent, whichever addresses it was sent through, but for the one step more of §6.5. Between nodes a message is never dropped alone: where one is dropped, the connection is lost, with everything that waited to be sent. A message arrives once or not at all, and the runtime sends nothing a second time. A large value crosses in pieces, and other senders' messages pass between them. A value crosses in the runtime's external term format (§8.4), a constructor as the text of its name; nothing is looked through before a value is sent, and on arrival it is not looked into (§3.11).

**Calls.** A `Reply` crosses as the host's alias, which takes one answer and drops any other (§6.6). The caller monitors the callee while it waits, so the callee's end and a loss both end the call: `Address.call` answers `None`, which says that no answer came and nothing of whether the request was received or ran, and `Address.callForever` faults with `Fault("callee is unreachable")` (§7.4). The call's time bounds the wait for the answer and nothing before it (§6.6): where the host's buffer for the peer is full, the caller waits in the send first. A call to a process of another node sends that node a note that this caller waits, with its reply; the node keeps the note until the callee answers, and where the callee restarts or ends first, tells the caller so by it. A call whose time ran out sends a second note, and a loss drops every note of that peer.

**A spawn.** `Peer.spawn(name, f, ms)` sends the peer named `name` a frame with `f` as a reference to its code, its module and its place there, the values it captured (§3.11), and the spawn's site (§6.9), which the peer records for the process as it records a local spawn's. The peer starts the process, runs `f()` in it, and answers its address. The spawner waits at most `ms` milliseconds, the opening of a connection among them, and the wait ends when the peer answers, when no connection can be opened, when the connection is lost, or when the time runs out, with a failure of Appendix E.27 as its answer; a spawn faults for nothing the network or the peer does. A monitored spawn that fails leaves no monitor. Where the time runs out, or the connection is lost while the spawner waits, the process may have started: where the connection lasts, it is ended as soon as its answer arrives, and where the connection was lost, it runs on, and no one holds its address. A function spawned on a peer runs where the bindings it depends on have their values there; otherwise the peer starts nothing and the spawn fails with `NotLoaded`, and nothing is initialized because a peer asked. In the spawned function a top-level binding is the peer's, a value it captured is the spawner's, and the system processes are the peer's (§8.2).

**A service and its key.** On one node a service is a top-level binding that holds an address (§6.5). A peer cannot name another node's binding, so a service that peers are to reach is offered under a *key*, a value of `Peer.Key(m)` that holds a name and the text of its message type `m` as the compiler prints it with every name qualified, `Counter.Msg` or `Counter.Box(Int)`, whichever module writes the key. `Peer.key("counter")` makes one at the type the compiler finds where it is written, and is refused where that type is not fully known there, or is bound (§3.11). A key starts nothing. `Peer.offer(key, address)` lets this node's peers find `address` under the key; it is accepted by the compiler only where the key and the address have one message type, and the node keeps the address under the key's name and its type's text for as long as the process lives. An offer under a key a living process holds faults the caller with `Fault("counter is offered by a living process")`, the key's name first (§7.4); a `restarting` loop keeps its address and its offer across its restarts (§6.9). An offer of an address that names no process of the running node faults the caller with `Fault("an offer names a process on its own node")`. Nothing withdraws an offer: it ends with its process. `Peer.find(key, ms)` asks the peers `keys` lists under the key's name, in that order, each given the time left, for what it offers under the name, and a peer answers the address where the type's text is the same. The find passes over `Unreachable`, `Refused`, `NotOffered` and `OtherType`, answers the first address found, and otherwise the last failure met, or `Timeout` where the time ran out; a key whose name `keys` does not list answers `NotListed`. Where a service lives is the configuration's: a service on one node is an entry of one peer, and two peers that offer one key are asked in the list's order. Only what a node offers can be found, and a find ships no code. A process that is to reach a service after it ends monitors it and finds it again by the key.

## 9. Prelude

The prelude holds what a rule of this report names and what no function written over the prelude could provide: a function is the prelude's where a rule of this report names it, or where no declaration, a `foreign fn` among them, could give it its meaning, and how common an operation is puts it nowhere. A prelude function has the shape Appendix E.0 gives a library function of its kind, and differs from one by nothing but its place. Everything else is the standard library, Appendix E: the container, string, and numeric operations and the output helpers. An operation of §9.6 in a type's namespace, `Int.compare`, is provided by that type's standard library module, and `Io.show` and `Io.debug` of §9.4 by `io.ern` (Appendix E.1). `Address.call` and `Address.callForever` are the runtime's, as the process functions of §9.4 and §9.5 are.

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

type Reason = Returned | Killed | ProgramEnd | Fault(String) | Unknown | Unreachable

type RestartLimit = RestartLimit(restarts : Int, within : Int) | Unlimited // within in milliseconds, §6.9

type Path = Path(String) // in the runtime's syntax
```

`Unreachable` is given by a monitor on a process of another node alone, when that node goes out of reach (§6.9, §8.7); a `match` on a `Reason` covers it as any constructor (§5.9).

### 9.4 Built-in functions (§6)

```
self           : () -> Address(m) with m
send           : (Address(a), a) -> Unit with m
spawn          : (() -> Unit with n) -> Address(n) with m
spawnMonitored : (() -> Unit with n, (Down) -> m) -> Address(n) with m
```

`io.ern` provides `Io.show` and `Io.debug` (Appendix E.1):

```
Io.show        : (a!) -> String needs a.show // the value as Ernest writes it, at the use's type
Io.debug       : (a!) -> a! with m needs a.show // prints Io.show's text and a line feed to standard error, then returns the value
```

### 9.5 Process functions

```
via                 : (Address(b), (a) -> b) -> Address(a)
Address.call        : (Address(m), (Reply(a)) -> m, Int) -> Optional(a) with n
Address.callForever : (Address(m), (Reply(a)) -> m) -> a with n
answer              : (Reply(a), a) -> Unit with m
restarting          : (RestartLimit, () -> Unit with n) -> () -> Unit with n
monitor             : (Process, (Down) -> m) -> Unit with m
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

On `Int`, `Float`, `String`, and `Bytes` an operator is the runtime's own operation; `List.<>` and `Path.<>` are Ernest in their modules. The operator is the primitive, and the function of its name in the type's module is written with it: the body of `fn Int.+(left : Int, right : Int) : Int = left + right` applies the runtime's `+`. On `Int`, `Float`, `String`, and `Char`, `<`, `<=`, `>`, and `>=` are likewise the runtime's own ordering, and `compare` in the type's module is written with them. On `Int` and `Float`, prefix `-` is the runtime's own negation, and `negate` in the type's module is written with it.

### 9.7 System references

The prelude binds no system reference. Each is a private binding of its system module, §8.2.

## 10. Runtime Requirements

- Tail calls take constant stack space. A function's body is in tail position. Where an expression is in tail position, so are both branches of an `if`, the body of each `match`, `receive`, and `after` clause, the last expression of a block, the right operand of `&&` and `||`, and the call a pipe makes.
- Processes are scheduled preemptively; a process cannot prevent others from running.
- Processes share no memory, except what foreign functions share (§4.7); a message is a copy or immutable.
- Mailboxes are unbounded; a program is responsible for its own backpressure.
- Memory is the host's. A program that exhausts it ends at once, every process with it: no process faults, no monitor is told, and the host's message is written to standard error (§11.8).
- `Int` has arbitrary precision. A result beyond the host's integers faults with `Fault("error:system_limit")`, a limit of the host met (§7.4).
- Bitstrings are constructed and matched by the runtime's bit syntax (§5.11).
- Unicode's tables, which decide a `Char`'s category and case, a `String`'s graphemes and White_Space, and a grapheme's width (Appendix E.6, E.5, E.16), are the host's, of the version it ships.
- The representation of values is fixed and documented.
- How nodes authenticate each other, the carrier between them with its frames and its numbers (§8.7), and the wire format, the runtime's external term format (§8.4), are the runtime's, fixed and documented with it, and the same on every node.
- `Down` carries a reason distinguishable from every other.
- The runtime detects a deadlock (§8.6).
- No code crosses between nodes: every node runs one build, which the handshake proves before anything passes (§8.7), and a message carries values only (§3.11).
- The runtime detects the loss of a connection on both of its nodes, at once where it is closed and within 45 to 75 seconds where it falls silent, and runs the loss as §8.7 says: one `Down` with `Unreachable` for each monitor on the peer's processes, each waiting call ended, and what waited to be sent dropped. A message between nodes arrives at most once, in the order it was sent for each sender and receiver, and is never dropped alone while the connection lasts. An address outlives a loss, and dies with its process or with its node's restart (§8.7). The runtime sends nothing a second time and retries nothing.

## Appendix A. Grammar

```
Program     = { Declaration } .
Declaration = [ "export" ] ( TypeDecl | AbstractDecl | FnDecl | LetDecl | ForeignDecl ) .
ForeignDecl = "foreign" ( "type" typename [ "(" ForeignVar { "," ForeignVar } ")" ]
            | "fn" DeclName "(" [ ForeignParam { "," ForeignParam } ] ")" Return "=" string ) .
ForeignVar  = typevar [ "=" ] .
ForeignParam = ident ":" ListedType .

TypeDecl    = "type" typename [ "(" typevar { "," typevar } ")" ] "="
              Constructor { "|" Constructor } [ "derives" "compare" ] .
Constructor = conname [ "(" ( Type | Field { "," Field } ) ")" ] .
Field       = ident ":" Type .
AbstractDecl  = "abstract" TypeDecl .

FnDecl      = "fn" DeclName "(" [ Param { "," Param } ] ")" [ Return ] [ Requirement ] "=" Expr .
Requirement = "needs" Member { "," Member } .
Member      = typevar "." ( userop | "compare" | "negate" | "show" ) .
Param       = Pattern [ ":" Type ] .
Return      = ":" FnResult .
LetDecl     = "let" ident [ ":" Type ] "=" Expr .
Binding     = "let" Pattern [ ":" Type ] ( "=" | "<-" ) Expr .
DeclName    = ident | typename "." ( userop | "compare" | "negate" ) .

Type        = TypeAtom | FnType | ParenType .
TypeAtom    = { typename "." } typename [ "(" ListedType { "," ListedType } ")" ] | typevar
            | TupleType .
ListedType  = typevar "=" | Type .
TupleType   = "#(" ListedType "," ListedType { "," ListedType } ")" .
FnType      = "(" [ ListedType { "," ListedType } ] ")" "->" FnResult .
FnResult    = FnType | ( TypeAtom | ParenType ) [ "with" Type ] .
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
Primary     = literal | QName | typevar "." userop | Tuple | ListLit
            | BitExpr | Block | MatchExpr | ReceiveExpr | "(" Expr ")" .
QName       = { typename "." } ( ident | conname [ "(" ( Expr | Fields ) ")" ] )
            | typename "." { typename "." } userop .
Fields      = ".." Expr [ "," UpdateSet { "," UpdateSet } ] | FieldSet { "," FieldSet } .
UpdateSet   = ident { "." ident } "=" Expr .
FieldSet    = ident "=" Expr .
Tuple       = "#(" Expr "," Expr { "," Expr } ")" .
ListLit     = "[" [ Expr { "," Expr } ] "]" .
BitExpr     = "<<" [ BitSegE { "," BitSegE } ] ">>" .
BitSegE     = Expr [ ":" BitSpec { "-" BitSpec } ] .
Block       = "{" Stmts "}" .
Stmts       = ( FnDecl | Binding ) ";" Stmts | Expr [ ";" Stmts ] .

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

`binop`, `userop`, and `literal` are defined in §2, along with the other lexical categories; `binop` precedence follows the table there. Every nonterminal is decided by its first token, or by the later token this paragraph names: `let` begins a binding, `fn` a declaration or lambda (an identifier or type name after `fn` makes it a declaration, `(` a lambda), `{` a block, `[` a list, `#(` a tuple, `(` a call or parenthesized expression, `<<` a bitstring. After a primary, `.` and an `ident` select a field (§3.5): a lowercase first segment is a value, so `s.upper` selects, while an uppercase one begins a `QName`, `Net.Http.parse`. An `ident`, `.` and a `userop` are a type variable's member, `a.+`. An `ident`, `.` and `compare` or `negate`, `a.compare`, parse as a selection, which §4.9 makes the member in a declaration with a requirement. The expression after `..` in `Fields` names a namespace where §5.6 says so, and the parser reads one form. In a qualified name, of a value in `QName`, of a type in `TypeAtom`, or of a constructor in `AtomPat`, after each uppercase token the next token decides: `.` continues the qualification, and otherwise the segment is final. In `QName` a final `ident` names a function or a value, a `userop` an operator, and a `conname` a constructor. A constructor's fields are positional or named by whether `=` or `:` follows the first identifier. When a constructor name is immediately followed by a parenthesized constructor argument, one expression or fields, the parser consumes that argument in the constructor branch of `QName`; a single-positional construction has the semantics of calling the constructor's function value. Empty parentheses after a constructor name, or two expressions or more, are a call of its value (§5.6). `conname` and `typename` are one token class; which one a segment is follows from its position. A parenthesized list of types is an `FnType` when `->` follows its `)`, and otherwise a `ParenType` (§3). In a `ListedType`, a type variable followed by `=` is marked (§3). A `with` after a function type belongs to that type (§3), and a function type that ends in a `with` takes no second: a function's effect after a result that is a function type is written after that type in parentheses, `(A) -> ((B) -> C with M) with N`, in a `Return` as in a type, `: ((A) -> B with M) with N`. In a `receive`, a `|` followed by `after` begins its `AfterClause`.

## Appendix B. Examples

The counter of §6.10, with a `main` that sends it `Inc` and `Get`. §6.10 shows `Upgrade` at work.

```ernest
type CounterMsg =
    Inc(Int)
  | Get(reply : Reply(Int))
  | Upgrade(migrate : (Int) -> Int, next : (Int) -> Unit with CounterMsg)

export fn main() : Unit with m = {
    let counter = spawn(fn() = count(0));
    send(counter, Inc(5));
    send(counter, Inc(3));
    match Address.call(counter, fn(reply) = Get(reply = reply), 1000) {
        Some(total) -> Io.println("count is " <> Int.toString(total))
      | None -> Io.println("counter is not answering")
    }
}

fn count(total : Int) : Unit with CounterMsg =
    receive {
        Inc(amount) -> count(total + amount)
      | Get(reply = reply) -> {
            answer(reply, total);
            count(total)
        }
      | Upgrade(migrate = migrate, next = next) -> next(migrate(total))
    }
```

Ping-pong. `main` starts `pong` under a monitor and `ping` beside it, and waits for `pong` to end. `ping` calls `pong` three times and then stops it.

```ernest
type PongMsg = Ping(round : Int, reply : Reply(Int)) | Stop

type MainMsg = PongDone(Down)

export fn main() : Unit with MainMsg = {
    let opponent = spawnMonitored(fn() = pong(), PongDone);
    let _ = spawn(fn() = ping(opponent, 3));
    receive {
        PongDone(_) -> Unit
    }
}

fn ping(opponent : Address(PongMsg), round : Int) : Unit with m =
    if round == 0 then
        send(opponent, Stop)
    else {
        Io.println("ping " <> Int.toString(round));
        match Address.call(opponent, fn(reply) = Ping(round = round, reply = reply), 5000) {
            Some(_) -> ping(opponent, round - 1)
          | None -> {
                Io.println("pong is not answering");
                send(opponent, Stop)
            }
        }
    }

fn pong() : Unit with PongMsg =
    receive {
        Ping(round = round, reply = reply) -> {
            Io.println("pong " <> Int.toString(round));
            answer(reply, round);
            pong()
        }
      | Stop -> Unit
    }
```

A message that carries a function. `submitter` is send-only, so its mailbox type is `Never`. Sent to a worker on another node, the message faults the sender (§3.11).

```ernest
type WorkerMsg = DoWork(work : (String) -> Bytes, input : String)

fn submitter(worker : Address(WorkerMsg)) : Unit with Never = {
    send(worker, DoWork(work = String.toUtf8, input = "hello"));
    send(worker, DoWork(work = String.toUtf8, input = "world"))
}
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
- **bound type** — a type whose values never cross to another node: one that holds a function type, a foreign type, a resource, or an address or a reply of a bound type. §3.11.
- **build root** — the directory a build writes its `.erc` files under, `--build-root`, mirroring the source root. §11.1.
- **`Bytes`** — the type of an octet sequence. §3.1.
- **cause** — the text a fault carries, `Fault(cause)`, which `Down` and a fault report give; §7.4 lists the language's. §7.3, §7.4.
- **child** — a process of a `Supervisor`'s group, which its supervisor restarts. Appendix E.22.
- **clause** — one pattern-branch of a `match` or `receive`. §5.9, §6.3.
- **code replacement** — a running process going on in a new function it received in a message. §6.10.
- **compare** — the per-type function that produces `Ordering`. §3.10.
- **compiled interface** — what a compiled module records of what it exports, their types and schemes, against which a module that uses it is checked. §3.9, §11.1.
- **concat operator** — `<>`, resolved per type. §4.8.
- **configuration directory** — the directory `--config-dir` names, which holds a node's `ernest.conf`, its key, its `ernest.pid` and its `startup` file; `./.ernest` for a program that is no node. §8.7, §11.2, §11.3.
- **connection** — what two nodes send each other over, at most one between them, opened by the first operation that needs it. §8.7.
- **cons operator** — `::`, list-prepend, right-associative. §3.3, §5.10.
- **constructor** — a case of a sum type; a value, a function, or a construction form. §3.5, §5.6.
- **consumed** — of a reply-carrying value: answered, or handed on by one of the uses §6.6 lists, exactly once on every path. §6.6.
- **container** — a type of the kind that holds elements and provides the container operations, a list, a map, a set. Appendix E.0.
- **deadlock** — no process can progress. §8.6.
- **derives** — `derives compare` at the end of a type declaration, which gives the type the member `compare` over its constructors and fields. §3.5.
- **diagnostic** — an error the toolchain reports at a place in the source: its message, the source with the span underlined, its labels, and at most one help line. §11.5.
- **doc block** — consecutive `///` lines, read as CommonMark. §2.2.
- **doc comment** — `///`, not followed by a fourth `/`, to end of line; attached to the following declaration. §2.2.
- **effect polymorphism** — a mailbox effect that is a type variable. §3.9.
- **effect position** — the type after `with` in a function type. §3.9.
- **entry point** — the function run in the entry process: the module's `export fn main`, or the function `--main` names. §8.1, §11.2.
- **entry process** — the process that runs the entry point. §8.1, §8.6.
- **equality constraint** — the restriction on a type variable compared with `==`, or on a foreign type's parameter written `k=`. §3.10, §4.7.
- **fault** — the end of a process with the reason `Fault(cause)`, or its restart where it restarts (§6.9). §7.3, §7.4.
- **field selection** — `e.f`, the named field `f` of `e`, where every constructor of the type has it. §3.5.
- **fill** — `C(..N)`, a construction whose fields not given are the declarations of their names in the namespace `N`. §5.6.
- **foreign address** — an address foreign code gave that names no process of the program; what is sent to it crosses into foreign code. §8.4.
- **foreign function** — declared `foreign fn`; body is a string reference to a runtime implementation. §4.7.
- **foreign process** — a process whose implementation lies outside the language, the system processes among them; §8.4 says which of its messages are checked. §8.4.
- **foreign type** — declared `foreign type T`; values are made and used only by foreign functions. §3.8, §4.7.
- **gateway** — the one process of a node that takes the runtime's frames from its peers: a spawn, a find and a message to an adapted address. §8.7.
- **generalization** — quantifying free type variables in a `fn` definition, a top-level `let`, or a block `let` that binds a lambda. §3.9, §4.6.
- **grapheme** — an extended grapheme cluster, what a reader sees as one letter, which `String`'s sizes and indices count. Appendix E.5.
- **group** — the processes a `Supervisor` restarts together, its children. Appendix E.22.
- **guard** — a `when` expression on a `match` or `receive` clause. §5.9.
- **guard expression** — the form of a `receive` guard. §6.3.
- **Hindley-Milner** — the type system Ernest uses; inference asks for an annotation only where §3.9 says. §3.9.
- **inferred restriction** — the equality constraint, process-only, or not-reply-carrying, inferred from a body; where there is none, written on a foreign type's parameter or given by §4.7 and §9. §3.9.
- **irrefutable pattern** — a pattern that cannot fail. §5.10.
- **key** — `Peer.Key(m)`, a name and a message type under which a service is offered to a node's peers and found by them. §8.7, Appendix E.27.
- **`kill`** — `kill(a)`, ends the process `a` names with the reason `Killed`. §6.9, §9.5.
- **lambda** — an anonymous function, `fn(x) = e`. §5.3.
- **line mode** — the shell reading lines and editing none, when its input or output is not a terminal. §11.2.
- **literal** — a token that stands for an `Int`, `Float`, `Char`, `String`, or `Bool` value. §2.5.
- **live region** — the shell's rows below what it has written, where the line being typed stands. §11.2.
- **load path** — the roots a program's modules are found under by their namespaces, the standard library's among them. §11.1, §11.2.
- **loss** — the end of a connection, which gives each monitor on the peer's processes its `Down` with `Unreachable`, ends each waiting call, and drops what waited to be sent, and nothing else. §8.7.
- **mailbox** — the queue of values a process receives. §6.
- **mailbox type** — the `M` in `(A) -> B with M`; the type of the process's mailbox. §6.1.
- **`match`** — the pattern-matching expression form. §5.9.
- **member** — an operator, `compare` or `negate` of a type, in the type's nested namespace: declared with the type's prefix, `fn Distance.+`, derived (§3.5), or, for a prelude type, declared unprefixed in its module; a requirement names one on a type variable. §4.2, §4.5, §4.9.
- **module** — a single Ernest source file (`.ern`); the unit of compilation and namespace. §4.1.
- **monitor** — `monitor(p, wrap)`; sends `wrap(d)` to the caller when the process `p` dies. §6.9, §9.5.
- **named field** — a field on a constructor identified by name, not position. §3.5.
- **namespace** — the dotted prefix of a name; equal to the module's path. §4.2.
- **`Never`** — the type with no values; as a mailbox type, a process that cannot receive. §3.7, §6.8.
- **node** — one running runtime, started with a configuration directory and identified by its key. §8.3, §8.7.
- **not-reply-carrying** — the restriction on a type variable whose values a function duplicates or discards: it stands for no reply-carrying type. §3.9, §6.6.
- **obligation** — a binding of a reply-carrying value, consumed exactly once on every path. §6.6.
- **operations record** — a record a program declares of the operations it uses on a type, filled from each representation's namespace and passed to code written once over them. §4.9.
- **operator resolution** — per-type dispatch of arithmetic and `<>` to `Type.<op>`. §4.8.
- **or-pattern** — patterns joined by `or` in one clause, which matches when any of them does. §5.9.
- **order** — a function `(T, T) -> Ordering` that keeps §3.10's laws, which `List.sort` takes and an ordered set or map requires of `compare`. §3.10, Appendix E.25.
- **owner** — the process that opened a resource or was given it, with which the resource ends. §6.9, Appendix E.18.
- **pattern** — decomposes a value and binds its parts. §5.10.
- **peer** — another node this node lists in its `ernest.conf`, by a name, a public key and a network address. §8.3, §8.7.
- **pipe** — the `|>` operator, `x |> f` = `f(x)`. §5.7.
- **positional field** — a field on a constructor identified by position, not name. §3.5.
- **precedence** — the binding tightness of a binary operator. §2.6.
- **prelude** — the small set of names the language requires to exist. §9.
- **`Prelude`** — the prelude's own namespace, `Prelude.Some`, for a name a module has shadowed, and the way past a member of the module's own to a name of the prelude's or the standard library's namespaces, `Prelude.List.<>`. §4.2.
- **primitive** — an operation beneath what Ernest writes: the language's, a built-in function of §9; a standard library module's, one that reaches a representation the runtime owns or a syntax the host owns, or one a function of the host does exactly, the rest of the module being Ernest over its primitives. §0, Appendix E.0.
- **process** — an execution of a function with a mailbox. §6.
- **`Process`** — the identity of a process, with equality; nothing can be sent to it. §6.5, Appendix E.21.
- **process-only** — a function whose effect variable cannot be pure. §3.9.
- **pure function** — a function without a mailbox type; result depends only on arguments. §0, §6.1.
- **qualified name** — a name with a dotted namespace prefix, `Net.Http.parse`. §2.3, §4.2.
- **raw string** — a `String` literal between backquotes, its text taken as written. §2.5.
- **`receive`** — a match over the mailbox. §6.3.
- **record update** — `C(..p, f = v)`, a construction whose unlisted fields are `p`'s; `f.g = v` reaches a field of a field through a *path*. §5.6.
- **redundant** — of a clause or an alternative: able to match no value those before it leave. §5.9.
- **remote computation** — work on a peer: a process spawned there. §6.7.
- **`Reply(a)`** — a one-shot address for the answer to a request. §3.7, §6.6.
- **reply-carrying** — a type that transitively contains a `Reply`. §6.6.
- **request-reply** — `Address.call` sends a request that carries a `Reply`, and the callee answers it with `answer`. §6.6.
- **requirement** — `needs a.compare` after a function's result type, naming members of its type variables that the body may use and a call supplies without writing. §4.9.
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
- **structural equality** — the meaning of `==`: two values are equal when they are built by the same constructor from equal parts, and a foreign type's and a `Process`'s equality is exact. §3.10.
- **subscription** — a process's standing request to the terminal for its events or to the runtime for its faults, ended when the process dies or restarts. §8.2, Appendix E.21.
- **sum type** — a type with one or more constructors. §3.5.
- **supervisor** — a process that restarts a group of processes, its children, together; the standard library's `Supervisor`. Appendix E.22.
- **system module** — the standard library module that holds a system reference, through which a program uses it. §8.2, Appendix E.0.
- **system process** — a process the runtime starts and keeps, its implementation foreign, its address a system reference. §8.2, §8.4.
- **system reference** — a system process's address, a private top-level binding of its system module that the runtime binds. §8.2.
- **tail position** — a function's body, and the branches, clause bodies, last block expressions, right operands of `&&` and `||`, and pipes' calls within it. §10.
- **taken namespace** — a namespace of the prelude or the standard library, which no other module may provide. §4.2.
- **top-level binding** — a value bound at file scope by a `let`. §4.6, §8.5.
- **tuple** — a positional product, `#(a, b)`, `#(a, b, c)`. §3.2.
- **type scheme** — a type with its quantified variables and their inferred restrictions, as a generalized binding has. §3.9.
- **type variable** — a lowercase identifier in type position, over which a definition is generalized as §3.9 says. §3.9.
- **`Unit`** — the type with the single value `Unit`. §3.1, §9.3.
- **value position** — an argument, a result, a tuple component, or a type argument whose parameter occurs in a value position of its type's fields. §3.9.
- **`via`** — `via(addr, f)` is the address `addr` seen through `f`. §6.5, §9.5.
- **vocabulary** — the operations a kind of type provides by its structure, named alike in every module that has them. Appendix E.0.
- **wildcard** — the pattern `_`; matches anything, binds nothing. §2.3, §5.10.
- **`with`** — the mailbox-type marker on a function type, `with M`. §3.4, §6.1.
