# Ernest Report: The Language

For Ernest 0.11.0.

*Dedicated to the memory of Joe Armstrong, 1950–2019.*

> To me beautiful code is clear, concise and does *exactly* what it is supposed to and *nothing* else with a minimum of fuss. It usually ends up being faster than ugly code - that's because God likes your code if it's beautiful.
>
> — Joe Armstrong, on erlang-questions, 23 January 2003

This file holds the report's §0 to §9 and Appendices A, B and F. §10 to §12 and Appendices C and H are in [`toolchain.md`](toolchain.md), and Appendices D, E and G in [`library.md`](library.md). The three files are one report. It is normative, but Appendix G is informative apart from its list of libraries, and where a gloss of Appendix F and the section it names differ, the section holds. Where the prose and Appendix A differ, Appendix A holds; where Appendix A is ambiguous, §0 decides.

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
- [Appendix A. Grammar](#appendix-a-grammar)
- [Appendix B. Examples](#appendix-b-examples)
- [Appendix F. Glossary](#appendix-f-glossary)
<!-- /contents -->

## 0. Introduction

Ernest is a functional language for concurrent programs. It has two concepts: functions, with Hindley-Milner types, and processes with typed mailboxes, the only way Ernest code affects the world; what foreign code does is §4.7's. Everything else in this report is a rule for how the two show up in each other.

Every function runs inside a process, an execution of a function with a mailbox that receives values of one type. A function that receives from its mailbox, gives out its address through its type, or asks for a message of a type it fixes to be delivered into it names the mailbox in its type, `(A) -> B receiving M`; that is the only mark written on a function type. A function whose type names no mailbox receives nothing and runs in any process. §3 and §6 make this precise; §10 states what the runtime must provide.

Five principles. Principles 2 to 5 are constructive. Principle 1 overrides where a rule would make what a reader writes mean something other than the reader predicts. Where a rule only refuses what the reader predicts, or asks a line more, principles 2 to 5 decide and the report states the departure.

1. Least surprise decides.

   A design surprises when a reader who knows the rest of Ernest would predict different code from the same requirement. The resulting code decides, not the rule.

   The reader knows Ernest first. Where Ernest's own rules do not decide, the reader knows types as Standard ML and OCaml have them, and values and processes as Erlang has them, and no other language. Where Standard ML and OCaml differ, the reader predicts neither, and the report states the rule. A form is not admitted because another language has it. Of a protocol, a format or a tool that the report names, the reader knows its specification, and no other. Where Ernest departs from what that reader predicts, the report states the departure as a rule.

2. One way, one job, in the language and prelude.

   No variants for the same thing, no two concepts that overlap. The standard library adds a second way only where Appendix E.0 names the pair.

   A second spelling of what the language already writes enters only where the first would nest where the reader reads a sequence, repeat a body, rebuild what a pattern already holds, or pair a record's field with the declaration of its name in one namespace or with the name in scope that gives or binds it; one that only shortens stays out. A form enters, too, where the reader of principle 1 predicts it, or where it promises what the first spelling cannot: a member no caller chooses, a monitor from the process's start.

3. Nothing invisible.

   Control flow, communication, and failure are visible in the code or in the type. Visible means visible where it happens: a send at the line that sends, a fault at the line that faults, a receive at the line that receives and in the type of the function around it. A top-level binding is visible when its name appears at the use site, or, in a fill, when the use site names its namespace and the record's declaration names its field (§5.6).

   A rule the type decides is checked when the program is compiled; one the value decides is a value, a message, or a fault when it runs (§7). What a call supplies unwritten, a requirement's member, is written in the callee's signature, or, for a derived `compare`, derived with it (§3.5); what a call is only checked against, a restriction, is inferred and printed with its mark, or written where there is no body (§4.7).

   The compiler refuses what the text alone shows can have no effect, a value dropped, a clause no value reaches, and accepts what the text shows only unused; there is no warning. Where a check refuses a program that would run, the rule is stated and its error names what to write.

4. Simple to parse: recursive descent, first-token dispatch, small bounded lookahead where the grammar demands it, no backtracking.

5. Small: few concepts, few primitives, few reserved words.

   The count is the language's, its concepts, its primitives and its reserved words; the standard library is bounded by Appendix E.0's rules, and a function they admit stands in the module of the type a reader looks in. How many programs ask for a feature decides nothing, for it or against it: a count measures a cost and is no reason for a rule.

   A type carries what keeps values and messages safe, the type of what a function receives among it, and nothing of what a function does.

   A feature costs a program that does not use it nothing: no argument, no word, and no name of it is written there, but a constructor of a type that its `match` covers constructor by constructor: `Unreachable` of `Reason` (§9.3), `NotListed` of `Io.Error` (Appendix E.1). Every function the prelude or a library names is a value, taken, passed and stored as any function is, but a member, which is reached through its operator or `compare` and is no value (§4.5). A function that is no value is a primitive, named where the report states it.

   No rule of the language exists for the runtime's or a library's convenience: a cost the runtime cannot bear is a limit the report states, never a form the compiler refuses; what the runtime must give, and what each operation costs, is §10's.

The toolchain is held to principles 1 to 3 as the language is: a job has one way to do a thing, says what it did where its reader could not see it and nothing else, and a refusal names what to write. Its count is its jobs, its options and its commands, as principle 5 counts the language's.

**The host.** Ernest runs on a host runtime (§10). A rule of the host is a rule of Ernest only where this report states it as Ernest's own. A rule this report states as Ernest's own holds at the host's limits too, and ends there only by a value, a fault or the program's end that the report states. A time, an order, an amount or a lifetime that the host decides there is the host's, and the report states it as the host has it.

A host rule whose outcome the program sees, a value or a fault, is taken and stated. One whose outcome would be silent, a truncation, a coerced value, a fault made false, is met by a check on the value, a refusal of the form, or a form of Ernest's own under which the outcome cannot come, and the cost of the check falls on that form alone.

An outcome that comes while the host starts, before the runtime runs, is the host's, and the report states it. Where the report is silent, the runtime carries the host's rule without letting it show.

**Time.** A wait of the program's ends by the program's time, by the party it waits on, or by a time the report states where the wait stands, the host's as the host states it. A wait of the runtime's own on a party outside the program, a peer, a far end or a stream's reader, ends without that party, by a signal the report names or by such a time. The runtime retries nothing of a program's, and chooses a time of its own only where nothing signals what the wait is for.

## 1. Notation

The grammar is Wirth-style EBNF. `=` defines, juxtaposition concatenates, `|` separates alternatives, `[ ]` is optional, `{ }` is zero or more, `( )` groups, `.` ends a rule. Uppercase names are non-terminals, lowercase names lexical categories. Terminals are in double or single quotes. `ident`, `conname`, `typename`, `typevar`, `binop`, `userop`, and the literals are defined in §2. The complete grammar is Appendix A.

## 2. Lexical Elements

### 2.1 Characters

Source text is Unicode in UTF-8; a leading byte-order mark (U+FEFF) is stripped. A source that is not UTF-8 is an error at its first byte that begins no character, before any other. Whitespace is space (U+0020), tab (U+0009), line feed (U+000A), and carriage return (U+000D); it separates tokens. A blank line has one meaning more: it decides what a doc block documents (§2.2). Any other control character, U+0000 to U+001F and U+007F to U+009F, is an error wherever it stands, in a comment and a doc block as elsewhere; a string or a character literal writes one as an escape.

### 2.2 Comments

`//` to end of line and `/* ... */`, which nests, are removed by the lexer and take part in no grammar rule. A block comment's text is not tokenized: the `*/` that closes its outermost `/*` ends it, inside quotes or not. A line ends at a line feed.

`///` to end of line, where the third `/` is not followed by a fourth, is a doc comment; `////` begins an ordinary comment. A `///` after a token on its line is an error: a doc comment stands on a line of its own, and a note after code is written `//`.

Consecutive `///` lines form a doc block, whose text is CommonMark 0.31. A doc block immediately preceding a top-level declaration, a constructor, or a named field, with no blank line between, is its documentation, extractable by the toolchain, §11.4. The first doc block before the first declaration, with a blank line after it, is the module's documentation. A doc block anywhere else, above a `fn` in a block or second before the first declaration, documents nothing and is an error, as a `///` after code is.

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

A qualified name is a sequence of uppercase-starting segments followed by a final segment. A final segment that starts lowercase names a function or a value, and one that starts uppercase names a constructor: `Net.Http.parse`, `Stack.push`, `Net.Http.Request`. The dots are namespaces, §4.2.

### 2.4 Reserved words

Eighteen, grouped by role:

| Role                 | Words                                                  |
|----------------------|--------------------------------------------------------|
| Types                | `type`, `abstract`, `receiving`, `foreign`             |
| Pattern matching     | `match`, `when`, `receive`, `after`, `as`, `or`        |
| Control flow         | `if`, `then`, `else`                                   |
| Bindings             | `fn`, `let`                                            |
| Visibility           | `export`                                               |
| Literals             | `true`, `false`                                        |

`needs` and `derives` are words of Appendix A read by position, as a bitstring's specifiers are (§5.11), and identifiers everywhere else: `needs` after a `fn` declaration's parameters or result type (§4.9), and `derives` after a type declaration's last constructor (§3.5). So are `compare`, `negate` and `show`, identifiers everywhere else: `compare` after `derives`; `compare` and `negate` after the dot of a member's declared name, `fn Coin.compare` (§4.5); and all three after the dot of a requirement's member, `needs a.show` (§4.9).

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

`\u{...}` denotes a Unicode scalar value, U+0000 through U+10FFFF excluding the surrogates U+D800 through U+DFFF. One that names a surrogate or a value above U+10FFFF is an error: `'\u{D800}'`. A `character` inside a `char` or `string` literal is any code point other than the enclosing quote, `\`, U+000A, and U+000D. A raw string, `` `\d+\.\d+` ``, is a `String` whose text is taken as written: `rawchar` is any code point other than the backtick, there are no escapes, and it may span lines, a line break in it being a line feed, with a carriage return before it dropped.

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

Only a `userop` can be declared, `fn Distance.+` (§4.8); where a member is named is §4.5's.

## 3. Types

```
Type       = TypeAtom | FnType | ParenType .
TypeAtom   = { typename "." } typename [ "(" ListedType { "," ListedType } ")" ]
           | typevar
           | TupleType .
ListedType = typevar "=" | Type .
TupleType  = "#(" ListedType "," ListedType { "," ListedType } ")" .
FnType     = "(" [ ListedType { "," ListedType } ] ")" "->" FnResult .
FnResult   = FnType | ( TypeAtom | ParenType ) [ "receiving" Type ] .
ParenType  = "(" Type ")" .
```

A parenthesized list of types is an `FnType` or a `ParenType` as Appendix A decides, and a `ParenType` holds exactly one `Type`. In a list of types, a type variable followed by `=` is marked with the equality constraint of §3.10, which is written in a foreign function's parameters alone (§4.7).

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

A type whose one constructor is named as a type in scope other than its own is an error: `type Word = String` declares a constructor `String`, and is refused, and so is `type Names = List(String)`. Where what is written reads as that type, its positional fields as many as the type's parameters, the help writes the wrapper: `` there are no type aliases; a type that holds a List(String) is written `type Names = Names(List(String))` ``. Elsewhere, `type Failure = Down(String)`, the help is `rename the constructor; Down is the prelude's type`, or, for a type the module declares, `rename the constructor; A is a type this module declares`. `type Heading = Up | Down | Idle` builds, as §4.2 lets a module take a prelude name.

**Integer arithmetic.** Exact, and bounded by the host's integers alone (§10). `/` truncates toward zero: `-7 / 3 = -2`. `%` satisfies `(a / b) * b + (a % b) == a`, so `-7 % 3 = -1`. `/` and `%` with a zero divisor fault with `Fault("division by zero")`. `Int.div` and `Int.rem` (Appendix E.8) truncate the same way and return `Optional(Int)` (§9.3) in place of the zero-divisor fault: `Int.rem(-7, 3)` is `Some(-1)`.

**Float arithmetic.** IEEE 754 binary64, round to nearest, ties to even, restricted to the finite range. An operation whose result is not finite faults with cause `Fault("float arithmetic error")` (§7.3): overflow, division of a non-zero numerator by zero, or `0.0 / 0.0`. Gradual underflow to a subnormal is not a fault. There is no `Infinity`, no `NaN`, and no negative zero: a zero is `0.0`, whether an operation or a negation gives it, or it enters the program from foreign code, from bytes, or from text. A float segment pattern `0.0` matches the bytes of either zero. A float segment pattern does not match the bytes of an infinity or a NaN. `Float.compare`, `Float.round`, `Float.truncate`, `Float.floor`, and `Float.ceil` are total.

`Int` and `Float` do not convert implicitly, and mixing them in an arithmetic expression is a type error; `Int.toFloat`, `Float.round`, `Float.truncate`, `Float.floor`, and `Float.ceil` convert. `Int.toFloat` rounds to the nearest `Float`, ties to even, and faults with cause `Fault("Int out of Float range")` where that rounding gives no finite `Float`. An integer above the largest finite `Float` that rounds down to it does not fault.

### 3.2 Tuples

`#(A, B)` is the type of a tuple and `#(a, b)` its value; a tuple has two components or more, all written this way. The tuple is the only positional product type.

### 3.3 Lists

`List(a)` is an immutable linked list. `[]` is the empty list; `x :: xs` prepends `x` to `xs`, and `::` is right-associative, so `[a, b]` is `a :: b :: []`.

### 3.4 Function types

`(A, B) -> C` is the type of a function of two arguments. Arity is part of the type: `(A, B) -> C` and `(#(A, B)) -> C` are different types; the first takes two arguments, the second one tuple. `() -> C` takes no arguments.

`receiving M` after the result is the mailbox type: the function receives from the mailbox of the process it runs in, whose type is `M`, §6.1. A function type without `receiving M` receives nothing.

`receiving` binds to the nearest arrow. `(A) -> (B) -> C receiving M` is a function that receives nothing and returns a function receiving `M`. `(A) -> ((B) -> C) receiving M` is a function receiving `M` that returns one that receives nothing. In a result annotation, a `receiving` after a function type is that type's: `fn f() : (A) -> B receiving M` returns a function receiving `M`; `fn f() : ((A) -> B) receiving M` receives `M` itself.

### 3.5 Sum types

Declared with `type`, §4.3. A constructor has no fields, exactly one positional field, or named fields:

```ernest
type Optional(a) = None | Some(a)

type Snapshot = Snapshot(directory : Path, seen : Map(Path, Int))
```

`Path`, `Map` and `Set` are the prelude's (§9.2, §9.3). Field names are unique within a constructor. Their declaration order is the order in which a value's fields are stored, transported (§12.2), and shown (Appendix E.1), and is part of the type's identity (§8.7); a construction and a pattern may give them in any order, and field expressions are evaluated in source order (§5.1). There is no canonical order. Positional and named fields are told apart by `:` after the first identifier in a declaration and by `=` in construction and patterns.

A type declaration may end in `derives compare`: `type Date = Date(year : Int, month : Int, day : Int) derives compare`. The type then has the member `compare` (§4.5), which orders two values by constructor in declaration order and then by field from left to right, each by its type's `compare` (§3.10). A field whose type has no `compare` is an error at the declaration: `type Task = Task(due : Date, tags : Set(String)) derives compare` is refused, `Task.compare cannot be derived: Set(String) has no compare`. For a type with parameters, the member has the requirement (§4.9) `needs` of each parameter the comparison reaches: `type Pair(a, b) = Pair(first : a, second : b) derives compare` gives `Pair.compare` the requirement `needs a.compare, b.compare`. `derives` names `compare` and nothing else.

A named field is *selected* with `e.f`: the field `f` of the value `e`, `snapshot.seen`. A type has the selector `f` when every one of its constructors has a named field `f`, and they have one type once the operand type's arguments stand for its parameters, which is the selector's; on any other type `e.f` is a type error. A positional field has no selector. Outside the module that declares an abstract type, its fields have no selectors, as its constructors are not visible there (§4.4). The type of `e` is found as an operator's operand type is (§4.8). `a.member`, where `a` is a type variable of the signature and no value named `a` is in scope, selects nothing and is refused.

A field selection whose operand's type is a type variable of the signature (§4.8) is reported naming the variable, the declaration whose signature writes it, and the field, `a value of k, a type variable of merge's signature, has no field compare`. Where the requirement names the field's member at that variable (§4.9), the help line writes what reaches it, ``under `needs k.compare`, write `compare(..., ...)` ``. A selector its operand's type lacks is reported at the selector, naming a constructor without the field where another has it, the type where none has, and of an abstract type outside its module that it is abstract.

### 3.6 Abstract types

A sum type whose constructors may be mentioned only in the module that declares it, §4.4.

### 3.7 Built-in types

`Address(m)` is an address of a process that receives `m`. `Reply(a)` is a one-shot address for the answer to a request, §6.6. `Never` is the type with no values. It is an ordinary type and unifies with itself alone; a function that never returns and may stand at any type has a type variable as its result, as `fault` has (§9.6). The prelude types are listed in §9.

### 3.8 Foreign types

A type declared `foreign type T` has no constructors: its values are made and used only by foreign functions, §4.7, and can otherwise be held, passed, and sent. Its equality is §3.10's. A host value of no other Ernest type enters Ernest through a foreign type alone, each with the runtime's exact equality: `foreign type T` declared by a module, and the foreign type of any host value, `Foreign.Term` (Appendix E.12).

A foreign type is bound to its node (§3.11).

### 3.9 Type variables and polymorphism

Types are inferred according to Hindley-Milner. A `fn` definition, a top-level `let`, and a `let` in a block that binds a name to a lambda are generalized over the type variables of their types that no name in scope around them holds; another `let` in a block is not, and a top-level `let` whose initializer is no value is generalized as §4.6 says.

Type variables in a `fn` signature scope over the whole definition, including the annotations of lambdas, of block `let`s, and of local `fn`s within it. A type variable in an annotation means every type its inferred restrictions admit (below), and is rigid. A type variable named first in a lambda's annotation or a block `let`'s belongs to that lambda or binding. Only a generalized lambda or binding may name such a variable: a lambda that is a `let`'s whole value, at top level or in a block. Naming one elsewhere is a type error: `List.map(xs, fn(x : a) = x)`. A local `fn`'s signature shares the enclosing signature's variables, and a variable named only in it is the local function's own, rigid and generalized with it as a top-level function's is.

Recursive and mutually recursive types are allowed; polymorphic recursion is not, even where the whole signature is written: a recursive call is at the definition's own type. A module's definitions are inferred each after the definitions it names, and a group of definitions that name one another is inferred together, each call within the group at the called definition's own type, before any is generalized.

Within a recursive group of types, a type of the group is named in the group's fields at the parameters of the type declared, each in its place, and at nothing else, so the types of a group take the same parameters: `type Tree(a) = Leaf(a) | Node(Forest(a))` with `type Forest(a) = Trees(List(Tree(a)))` is allowed, and with `type Forest = Trees(List(Tree(Int)))` refused. `type Nest(a) = Flat(a) | Deeper(Nest(List(a)))` is refused at its declaration, and so is `type Flip(a, b) = End(a) | Turn(Flip(b, a))`; `Deeper(List(Nest(a)))` is allowed. Every type variable in a constructor's fields is a parameter of the type.

A recursive call's argument at another type than the definition's own is reported as not fitting the callee at its own type, with a help line naming the fix: a second function for the call at another type. A type of a recursive group named in its fields at other than the declaring type's parameters is reported at that name, with a help line naming the fix: the type named at those parameters, `Nest(a)`, and, where the type it was named at takes one argument, that type holding it, `List(Nest(a))`.

**Effect polymorphism.** The mailbox type of a function type may be a type variable, an *effect variable*, generalized with the others: `fn apply(f, x) = f(x)` has type `((a) -> b receiving e, a) -> b receiving e`. At a call site an effect variable binds to a mailbox type or to none: `apply(fn(x) = self(), 5)` binds `e` to the caller's mailbox type, `apply(fn(x) = x + 1, 5)` binds `e` to none. None is the absence of `receiving`; it is not a type. A mailbox type bound this way becomes the caller's.

A function that receives nothing stands wherever a function of the same type receiving `M` is expected, and a function that receives stands nowhere one that receives nothing is expected. So an expression whose type is a function type without `receiving` takes a fresh effect variable in its place, which the context binds: with `fn done(n : Int) : Unit = Unit`, `Upgrade(next = done)` binds it to `CounterMsg` (§6.10). Only the expression's own function type takes one. A function type inside it or inside another type, a parameter's, a result's, or a field's, keeps its effect until an expression has it as its own type, as a call or a selection does.

An effect position is the type after `receiving`. A value position is an argument, a result, a tuple component, or a type argument whose parameter occurs in a value position of its type's fields. A type argument of a built-in or foreign type is a value position. So is a type argument whose parameter occurs in no field of its type: `m` in `Peer.Service(m)` (§8.7). A variable that occurs only in effect positions ranges over the mailbox types and none. A variable that also occurs in a value position ranges over types alone: `m` in `self : () -> Address(m) receiving m` is never none. A body that calls `self` is checked at the variable, and only the definition's type drops it (§4.5).

Inference asks for an annotation at:

- an operator whose operand type nothing in the definition fixes (§4.8);
- a field selection whose operand type nothing fixes (§3.5);
- a top-level binding that is not generalized whose type keeps a variable nothing resolves (§4.6);
- a `<-` whose sum type is still open (§5.5);
- a `show` supplied at a type not known whole that no requirement names (§4.9, Appendix E.1);
- a call whose requirement's variable nothing fixes by its definition's end (§4.9);
- a fill whose record type leaves a requirement's variable undetermined (§5.6);
- a path in a record update through a field whose type nothing fixes (§5.6).

Inference asks for one too at `Foreign.term` at a type not known whole that holds no type variable of the signature (Appendix E.12), `Peer.service` at a type not known whole once its definition is inferred (§8.7), the mailbox type of a process spawned on a peer and the result type of a compute's function, where either still holds a type variable (§3.11), and an input at the prompt that binds a name its type does not settle (§11.2).

The effect variable of a function whose own body, outside its lambdas and local `fn`s, holds a `receive` that fixes no type for the message it takes, one whose patterns are wildcards or variables that nothing fixes, is *process-only* where nothing else fixes it: it is never none, as a variable in a value position is not. So is the variable of its own that a `foreign fn`'s `receiving` names. A function whose effect variable is process-only is process-only. No other effect variable is, but for one unified with a process-only variable (below): a function that sends, spawns, answers, sleeps, prints, reads a file or calls only functions that receive nothing names no mailbox, and a call of it adds nothing to the caller's type.

A `foreign fn`'s mailbox type is its own unless its effect variable is also the effect of one of its parameters' function types, in which case the mailbox type is that callback's and the function is effect-polymorphic: `foreign fn each(m : Map(k, v), f : (k, v) -> Unit receiving e) : Unit receiving e` receives nothing when `f` does.

An effect variable that nothing has fixed to a type by the end of its definition (§4.8), that no definition around it holds and that is not process-only, is none in the definition's type where it occurs there at most once and outside every parameter's type: the function receives nothing. `fn f() = kill(Process.fromAddress(self()))` has type `() -> Unit`, and `fn pair() = fn(x) = #(x, x)` the type `() -> (a) -> #(a, a)`. A variable in a parameter's type stays: `fn ignore(f : () -> Unit receiving e) : Int = 5` has type `(() -> Unit receiving e) -> Int`.

A function has one mailbox type or none. A function may take a callback that receives nothing beside one that receives: in `fn callBoth(p : (Int) -> Int, e : (Int) -> Unit receiving n) : Unit receiving n`, `p` receives nothing, `e` receives `n`, and the function inherits `n`. Two callbacks whose mailbox types are both variables unify to one. Two callbacks with different concrete mailbox types are a type error.

**Inferred restrictions.** An annotation gives a function's shape: arity, argument types, result, mailbox type. Two restrictions are inferred from the body. Where there is no body, a restriction is given instead: written on a foreign type's parameter, `k=`, or on a type variable in a foreign function's parameters, `a=`, the one restriction a program writes (§4.7); given to a foreign function by this section's process-only rule; and stated for the prelude's types and primitives in §9. Each prints with its mark (§11.5).

The equality constraint of §3.10 falls on a variable compared with `==`. Process-only is the effect variable's, and passes to each variable unified with it: `fn skip() = receive { _ -> Unit }` cannot be taken for one that receives nothing, and neither can `fn h() : Unit receiving e = skip()`, which calls it, nor `fn f() = { let me = self(); let _ = spawn(fn() = receive { x -> send(me, x) }); Unit }`, whose spawned lambda receives at `f`'s own mailbox type.

Each restriction is part of the type scheme and travels with the function value through bindings, branches, and compiled interfaces. Each is checked at instantiation, not at definition.

### 3.10 Equality and ordering

`==` and `!=` are structural and defined for all values except those containing functions, addresses or replies, on which they are a type error. On a value of a foreign type, `Foreign.Term` among them, or of `Process` or `Clock.Alarm` (Appendix E.21, E.15), they are the runtime's exact equality on the two representations (§12.2): two references are equal only when they are one reference, and two values that foreign code made as the same term are equal. `==` on a value of an abstract type compares its representation, outside its module too.

```ernest-rejected
fn same(f : () -> Int, g : () -> Int) : Bool =
    f == g // rejected: == is not defined on functions
```

Ordering is per type, through `compare` in the type's namespace: `Int.compare : (Int, Int) -> Ordering` (§9.3). For a type a module declares, that is its member `T.compare` (§4.2); a function named `compare` outside the type's namespace gives no ordering. For operand type `T`, `a < b` is `T.compare(a, b) == Less`; `<=`, `>`, and `>=` likewise. They resolve against the operand type as the operators of §4.8 do. A type without `compare` has no ordering, and `<` on it is a type error.

The prelude defines `compare` for `Int`, `Float`, `String`, `Char`, and `Bool`, on which `false` is before `true` (§9.6); for `Optional` and `Either` where their element types have one, `None` before `Some` and `Left` before `Right`, then by the element (§9.3); and for a tuple and a list where every component type has one, component by component from the left, a shorter list before a longer one it begins. `Path`, `Map` and `Set` have no ordering, and neither has a tuple or a list whose component type has none. `List.compare`, `Optional.compare` and `Either.compare` are the prelude's (§9.6), each provided by its module (Appendix E.2, E.10, E.11); a tuple's `compare` is the language's.

`compare(a, b)`, §9.6, is `T.compare(a, b)` for operand type `T`, resolved as `<` is, and reaches every order the operators reach, a tuple's among them. An order is used through `compare` and the operators alone: `T.compare` names the declaration (§4.5), and a function that needs an order declares the requirement (§4.9).

An *order* on a type `T` is a function `f : (T, T) -> Ordering` for which, for all `a`, `b`, and `c` of `T`: `f(a, a)` is `Equal`; `f(a, b)` is `Less` exactly when `f(b, a)` is `Greater`; where `f(a, b)` and `f(b, c)` are `Less`, `f(a, c)` is `Less`; and where `f(a, b)` is `Equal`, `f(a, c)` is `f(b, c)`.

Each `compare` of the prelude is an order, and says `Equal` only where `==` holds. A derived `compare` (§3.5) is an order where the `compare` of each other type its fields name is one, and says `Equal` only where `==` holds where each of those does. Where any other `compare` is the one a sort, or an ordered set or map, requires, the laws are the program's promise, and nothing checks them. What the standard library says of a sorted list, and of an ordered set or map, holds only where the `compare` it requires is an order (Appendix E.2, E.25, E.26).

A function that applies `==` to a value of a type variable gives that variable an *equality constraint*, inferred and never written; instantiating it with a function type, the type of an address or of a reply, or a type that holds one, is a type error at that call site: a built-in or a foreign type holds its arguments, and a declared type the types of its fields, its arguments in place of its parameters.

A foreign type's parameter and a foreign function's type variable may carry the constraint (§4.7), and `Map(k=, v)` and `Set(a=)` carry it on `k` and `a` (§9.2). A value of such a type over a type without equality is rejected at its first operation; a type that names one, `Map((Int) -> Int, Int)` in an annotation or a field, is not itself an error. A standard library function that compares elements, `List.contains`, propagates the constraint through its parameter.

`fn equal(a, b) = a == b` has type `(a, a) -> Bool` with the constraint on `a`. The constraint travels and is checked as §3.9 says: `let f = equal` carries it, and applying `f` to addresses is an error at that application; `if flag then equal else always`, with `always` unconstrained, carries the union of the branches' constraints.

### 3.11 Serialization

A message may be a value of any type, a function included. A type is *bound* to its node where it holds a function type, a foreign type (§3.8), a resource, or an `Address(m)` or a `Reply(m)` whose `m` is bound; a resource is the address of a socket, a listener or a program the runtime started, or a `Clock.Alarm` (Appendix E.15, E.18, E.23); and the message types of the three, `Tcp.SocketMsg`, `Tcp.ListenerMsg` and `Os.ProgramMsg`, are bound themselves; a library's resource is a foreign type. Every other type crosses: `Int`, `Float`, `Bool`, `Char`, `String`, `Bytes`, a tuple, a list, `Map`, `Set`, a declared type's values, an address, a `Process` and a `Reply` of an unbound type, and an adapted address (§6.5).

A value of a bound type is never used on another node. The compiler refuses the operations that would start one on its way: a `Peer.service` at a bound type (§8.7); a `Peer.spawn`, a `Peer.spawnMonitored`, a `Peer.compute` or a `Peer.computeAnywhere` whose function captured a value of a bound type, or a value whose type holds a type variable (§3.9); a `Peer.spawn`, a `Peer.spawnMonitored`, a `Peer.compute` or a `Peer.computeAnywhere` whose function's mailbox type is bound; and a `Peer.compute` or a `Peer.computeAnywhere` whose function's result type, which crosses back, is bound (§8.7).

A service's message type is known whole as §8.7 says. The mailbox type of a process spawned on a peer or started by a `Peer.compute` or a `Peer.computeAnywhere`, and the result type of the function a `Peer.compute` or a `Peer.computeAnywhere` runs, are read at the end §6.2 gives a spawn's mailbox type. A mailbox type that is unfixed then (§6.2) is `Never`, as an entry point's is (§8.1). A type that then still holds a type variable is refused, as a bound one is.

The function a spawn on a peer starts, or a `Peer.compute` or a `Peer.computeAnywhere` runs, is the name of a top-level `fn` or `foreign fn` declaration, which captures nothing; a lambda written in the same definition, at the spawn or bound by a `let` whose name the spawn writes; a `fn` declared in the same definition, whose captures are checked as a lambda's; or `restarting` (§6.9) applied to one of these, whose result captures its two arguments and nothing else.

The captures of a lambda or of a local `fn` are the locals its body names. A captured value's type is read at the end of the top-level definition the spawn or the compute is written in, or of the shell's input (§11.2). A member of a requirement in force (§4.9) that such a body uses is a function the definition was given, and the spawn is refused as one that captured a function: `Peer.spawn starts a function that uses a.show, a member of the requirement in force, which is a function bound to its node`, the member named.

Any other expression is refused, a function that came as a parameter, in a message or from a call among them. A local name that names no such lambda or `fn` is refused with `Peer.spawn starts f, a function that came as a value, whose captures the compiler does not see`, `f` the name.

`Peer.spawn`, `Peer.spawnMonitored`, `Peer.compute` and `Peer.computeAnywhere` are called where they are named, and are not taken as values: `let start = Peer.spawn` is refused with `Peer.spawn is called where it is named, so that the compiler sees the function it starts`. `Code.running` is called where it is named the same way (§6.10, Appendix E.28). These five are primitives (§0). Each error names the operation written.

No other operation is checked, and nothing is looked through at a send. The values an adapted address's function captured cross as its payload and are touched only on the node that made it, where the function runs (§6.5). A value crosses carrying nothing of its type, and needs no code on the node it reaches. A program holds an address of another node's process only from a find, a spawn or a compute, or inside a message or a call's answer.

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
Requirement = "needs" Need { "," Need } .
Need        = typevar "." ( userop | "compare" | "negate" | "show" ) .
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

**Declarations are local; `export` marks the boundary.** A declaration is written with its local name. `fn parse` in `net/http.ern` is exported as `Net.Http.parse` when marked `export`; otherwise it is private to its module. A use site may write a declaration's qualified name, in its shortest resolving form (**Qualified lookup**): elsewhere for an exported one, and within its own module only where a binding hides the declaration's plain name, `Http.parse` in `net/http.ern`, as `Prelude.` is written only where the module hides the prelude's. A module's own type or constructor, which no binding hides, is written plain within it (**Qualified lookup**). A declaration never writes its own name qualified. Two declarations of one name in a module are an error, exported or not: `fn f` beside `let f`.

The type of an exported declaration, and the field types of an exported type that is not abstract, may not name a type the module keeps private. A function's mailbox type is exempt: an exported entry point may receive a private message type. A type whose values cross the boundary but whose constructors do not is an `abstract type` (§4.4). There is no export list and no `import`.

**Taken namespaces.** The prelude's namespaces are taken, `Prelude` and the name of every type whose namespace §9 fills, as `Int` and `Address`, and so is each namespace of the standard library: `address.ern` at the source root is an error, and so is `io.ern`. A prelude type whose namespace §9 fills with nothing takes no namespace: `down.ern` at the source root provides the namespace `Down`, and the type `Down` is still the prelude's.

`Ernest` is taken too, with every namespace under it; the toolchain's own Ernest stands there, the shell as `Ernest.Shell` (§11.2). `ernest.ern` at the source root and `ernest/shell.ern` under it are errors as `io.ern` is, and a program names nothing under `Ernest`: `Ernest.Shell.main` is an unknown name, said so.

No segment of a module namespace, at any depth, is a taken one, `Ernest` among them: `fs/entry.ern`, `fides/io.ern` and `fides/ernest.ern` are errors as `io.ern` is. The toolchain's own source roots are the exception: the standard library's provides the prelude's namespaces and its own, and the shell's provides `Ernest` and what stands under it, each root's files providing its namespaces alone, built to a build root of the toolchain's own. A file under one is compiled with it as the source root (§11.1); another source root is an error.

The namespace of a library of the toolchain's own (Appendix G) is not taken. A program's module whose namespace is that of a library's module hides that module, the library standing last on the load path (**Qualified lookup**, §11.2). A qualified name unknown under the namespace of a module that hides a library's module has a help line naming the two, the module by the file the job took for it, a source or a compiled form, its path written as §11.5 writes one: `help: Json here is json.ern, which hides the library Json; give it another name to reach the library's`. At the prompt the `:load` that would put the name in scope is the answer where §11.2 gives one. A program's module under a library's namespace hides nothing where no module of the library has its namespace: `time/zone.ern` provides `Time.Zone` beside the library's `Time`.

A program's module whose namespace is that of a library's module on which a module the job takes depends, a library's or a named package's, is refused where a job compiles it, where a run, a session or a node takes it compiled (§11.1, §11.2), and where `Code.load` loads it (Appendix E.28), and a run that finds it for a library's module compiled against the library's is refused (§11.2).

The modules a job takes are those it is given and each module they depend on, for `ern build` and `ern doc` as for a run; a session takes every library and every named package on its load path, and a node its whole load path, every module of which it loads at its start (§8.7): a program's `time.ern` that `ern build` and `ern run` take is refused at a node's start, since `Http` uses `Time`. A shell given a file takes a run's modules until its first `:load` or `:reload`.

```ernest-fragment
// net/http.ern
export type Request = Request(method : String, path : String)

export fn parse(text : String) : Optional(Request) =
    ...

// private to net/http.ern
fn helper(x) =
    ...
```

**Type members.** A type `T` declared in a module, concrete or abstract, is a nested namespace. Its members are its operators, its `compare` and its `negate` (§4.5), declared with the single prefix `T.`, as in §4.8's `fn Distance.+`, or derived (§3.5); an operator reaches a member of an exported type from every module, and `Module.T.member` names the declaration alone (§4.5). The module of a prelude type is the exception §4.8 states: `export fn Float.+` in `float.ern` declares `Float.+`, and its `compare` and `negate` are declared unprefixed; they are members all the same, and `compare` in a body there is the prelude's (§4.5).

The namespace belongs to the file that declares the type, and the module of that name shares it: `main.ern` may declare `Stack` beside `main/stack.ern`, as the prelude's `Map` stands beside the standard library's. A qualified name `Main.Stack.compare` in an expression is the module `Main.Stack`'s `compare` (§4.5). A member of an exported type and an exported value of the module of its name, a function or a `let`, may not share a name all the same: `main/stack.ern` exporting `compare` while `main.ern` exports `Stack` with a `compare` is an error, reported in `main/stack.ern` at the value's declaration, naming the type and the module that declares it: `Main.Stack.compare is a member of the type Stack in the module Main`.

The sharing is by the exact name: `main.ern` declaring `STACK` beside `main/stack.ern` shares nothing, and a module may declare two types whose names differ only in case.

**Unqualified lookup.** An unqualified name in a body is looked up first among the names bound around it, the innermost first: parameters, `let` bindings, pattern and `receive` variables, and local `fn`s. It is then looked up in the module's declarations, exported or not, then in the prelude. A name not found there is written qualified. A type's member is no name a body writes: an operator reaches it (§4.5). A module may declare a type, a constructor, a function or a value with a prelude name, and the name then means the local one throughout the module. The `compare` a prelude type's module declares unprefixed is the exception: it is its type's member (**Type members**), and `compare` in a body there is the prelude's.

A dotted name's first segment is a namespace, and a member stands in no expression (§4.5): in a module that declares `type List` with a member `List.<>`, `List.map` is the standard library's `map`, and `<>` on the module's own `List` is its member.

**Qualified lookup.** A qualified name resolves from the writer's namespace outward. Its first segment is looked up as a module namespace directly under the writer's own namespace, then under each enclosing namespace in turn, and last at the root; the segments after it descend from the namespace found. A type's nested namespace (**Type members**) is never found so.

The nearer namespace wins where two hold the first segment. The farther is reached from there only by a name whose first segment is found above it, `Top.Util` from `Top.Shell`, where `Util` is `Top.Shell.Util`, and one at the root is out of reach. A qualified name unknown in a namespace nearer than the root, where a module of its first segment stands at the root, has a help line naming the two: `help: Util here is Top.Shell.Util, which hides the root's Util from Top.Shell; give it another name to reach the root's`.

The root is one namespace. The modules of the source root and of each load path root stand in it together, beside the prelude's namespaces, the standard library's and the toolchain's libraries': `geo/a.ern` under the source root and `geo.erc` under a load path root provide `Geo.A` and `Geo`. Where two roots hold a module of one namespace, the module is the first root's, the source root standing first and the load path's roots after it in their order (§11.1, §11.2), and it hides the other. A module is hidden by a module of its namespace alone, and a directory hides nothing. Where a named package's namespace is found is §11.9's.

So `Command.parse` in `Ernest.Shell` names `Ernest.Shell.Command.parse`, `Region.Region` in `Ernest.Shell.Complete` names its sibling's type, `Shell.attach` there names its parent's function, and `Io.println` anywhere names the standard library's. The lookup finds a namespace where a module's file stands at its path, or anywhere under its directory: from `Top.User`, `Net.Http.get` names `Top.Net.Http.get` where `top/net/http.ern` stands and no `top/net.ern` does. A directory that holds no module is passed over. A first segment found nowhere is an error, as a module that does not exist is. A shell's input resolves as §11.2 says.

A name written longer than its shortest resolving form, `Ernest.Shell.Command.parse` where `Command.parse` resolves to it, is an error at the name, whose help names the short one. A module's own type or constructor written qualified and `Prelude.x` where the plain `x` is the prelude's (**Declarations are local**) are two cases of it. A trace and a site print a name whole, from the root. What `ern doc`, the shell and a diagnostic print is §11.4's, §11.2's and §11.5's.

`Prelude` names the prelude's own namespace: `Prelude.Some` is the prelude's `Some` in a module that declares its own. It takes one name the prelude declares and nothing else. No module and no type is named `Prelude`. Within a module, type names are unique and constructor names are unique across its types.

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

External callers see `Stack.Stack`, `Stack.empty`, `Stack.push`, `Stack.pop`, and `Stack.size`; `Stack.Stack(...)` is refused outside `stack.ern`. A module may declare several abstract types. Outside its module, `Io.show` writes a value of an abstract type as `<abstract>` (Appendix E.1), and `==` compares its representation (§3.10).

### 4.5 Functions

`fn` declares a function of fixed arity. Annotations may be omitted where they can be inferred. The result annotation is omitted, or is `: T` for a function that receives nothing, or `: T receiving M` for one that receives, as a parameter's annotation is `: T`.

An annotation without `receiving` on a function that receives is a type error. Such an annotation makes every parameter the body calls one that receives nothing: `fn apply(f, x) : Int = f(x)` has type `((a) -> Int, a) -> Int`.

`: T` stands over the body of a `fn` that calls `self`, `monitor` or another function whose type holds its mailbox type in a value position, where that mailbox type is, at the function's end, a variable that §3.9 makes none. `fn f() : Unit = kill(Process.fromAddress(self()))` has type `() -> Unit`; `fn g() : Unit = send(self(), 5)`, whose `send` fixes the variable to `Int`, is refused. A lambda is read so at its own end, where no check waiting for its definition's end holds the variable (§4.8), under its `: T` and where its context expects a function that receives nothing: `monitor(p, fn(d) = { kill(Process.fromAddress(self())); d })` gives `monitor` a wrap that receives nothing.

`receiving M` where `M` is a type variable is an error over a body at whose end §3.9 makes `M` none, a body that does not involve its mailbox (§6.1) among them: `fn k() : Int receiving m = 5` is refused, and so is `fn f() : Unit receiving m = kill(Process.fromAddress(self()))`. It is reported at `M`, naming the function, with the help line that writes its type without `receiving`.

A function has one clause. Patterns in parameters are irrefutable, §5.10: `fn seenCount(Snapshot(seen = entries) : Snapshot) : Int = Map.size(entries)`. Each name appears at most once among a function's parameters, as a variable does in a pattern (§5.10). `fn f(x : Int, x : Int)` is refused, `parameter x appears twice`, and so is a lambda's and a `foreign fn`'s.

`fn` may appear at top level and as a statement in a block; it sees its own name, and `fn` declarations in the same block or at top level may refer to each other. A type-member name, `fn T.f`, is a top-level form; in a block it is an error.

A type's operations are functions of its module. A member, `fn T.f` or `foreign fn T.f`, is declared only for what the language resolves by the operand's type: an operator of §2.6, `compare` (§3.10), and `negate` (§5.1); a `let` declares no member. A type whose declaration ends in `derives compare` has that member without declaring it (§3.5). A function declaration may end in a requirement, which names members of its type variables (§4.9).

A member is reached by what resolves to it alone, the operator of §4.8, prefix `-` (§5.1) and `compare` (§3.10); its name, `T.f` and a requirement's `a.f`, stands in a declaration and in a requirement and in no expression, where it is an error naming the operator to write: `Int.negate(x)` is written `-x`, and `Int.compare(a, b)` is written `compare(a, b)`. A module reaches its abstract type's constructors by being its module (§4.4).

### 4.6 Bindings

In a block, `let p = e` binds the irrefutable pattern `p` to the value of `e`; `let p <- e` is described in §5.5. It is monomorphic, except one that binds a name to a lambda, `let id = fn(x) = x`, which is generalized as a local `fn` is (§3.9). A later binding of the same name shadows the earlier one from the next statement on; the right-hand side of the later binding sees the earlier one.

A block binding's type may hold unresolved type variables; `[]`, `None`, `Map.empty`, and a call that returns a polymorphic value introduce them. A later use of the binding in the block pins such a variable: `let m = Map.empty; Map.put(m, "a", 1)` pins `m` at `Map(String, Int)`. One that reaches the block's result is generalized by the enclosing `fn` or top-level `let`: `fn namedEmpty() = { let xs = []; xs }` has type `() -> List(a)`. An annotation on the binding fixes it. A use pins a variable only where it fixes the variable's type, and a variable that nothing pins stays free: in `{ let xs = []; List.size(xs) }` the element type stays open.

At top level, `let` binds an `ident`. The left side is a name, not a pattern; `<-` is a block form only. A binding's initializer may not depend on its own name, which is a cycle (§8.5), so a function that calls itself is declared with `fn` (§4.5). The initializer is a body receiving `Never` (§6.8): it may spawn, send, call and sleep, and a `receive` in its own body, outside its lambdas and local `fn`s, is a type error.

The binding generalizes its free type variables where its initializer is a value: a literal, a name, a lambda, a tuple or a list of values, a list built with `::` from values, or a constructor applied to values, a record update of a value and a fill among them (§5.6), `let empty : Stack(a) = Stack([])`. A top-level binding whose initializer is a *constant*, a literal, a negated number literal, a constructor of no fields, or a constructor, a tuple or a list of constants, is not evaluated: it has its value from the program's start (§8.5), and no fault leaves it without one (§11.2).

A binding whose initializer is no value has the type the initializer gives. It is generalized where that type, read through the fields of the declared types it names, holds no function type, no foreign type, no address and no reply: `let empty : Map(k, v) = emptyMap()`, `emptyMap` a foreign function that answers the host's empty map.

Where that type holds one of them, the binding is not generalized. Of the variables left in its type:

- An effect variable that stands in no value position and is not process-only is none (§3.9) where it stands as a function type's effect, a parameter's among them: `let p = twice(fn(x : Int) = x)` with `fn twice(f) = #(f, f)` is `#((Int) -> Int, (Int) -> Int)`. It is `Never` where it stands as a type argument, which is a type, and a variable that stands as both is `Never` throughout (§6.2, §11.2).
- A spawned function's unfixed mailbox type is `Never` (§6.2).
- Any other variable left, a process-only effect variable among them, is a type error at the binding: `let shared = spawn(fn() = cell(None))` is refused until an annotation fixes the type of what the cell holds.

A top-level `let`'s type closes by that rule with none where a function type's effect stands open: with `fn makeApplier() = fn(f) = f() + 1`, `let h = makeApplier()` is `(() -> Int) -> Int`, where `fn h2() = makeApplier()` keeps its variable, `() -> (() -> Int receiving e) -> Int receiving e`. A call in the body of a lambda the initializer builds and does not call is the lambda's: `let me = fn() = self()` is generalized. The runtime evaluates top-level bindings in dependency order, in the entry process, before `main` runs (§8.5).

### 4.7 Foreign declarations

`foreign type T` declares a type implemented outside the language. Its parameters are distinct type variables. A parameter written with `=`, `k=` in `foreign type Table(k=, v)`, puts the equality constraint of §3.10 on its argument at every operation of the type, and the type written with an argument that lacks it is not itself an error (§3.10).

`foreign fn f(params) : T = "impl"` declares a function whose body is the implementation named by the string, in the runtime's language; parameters and the result are annotated. A type variable written with `=` in a parameter's type, `a=` in `foreign fn member(element : a=, list : List(a)) : Bool = "lists:member/2"`, carries the equality constraint of §3.10, as one a body compares with `==` does. A variable is marked `=` once, at any of its occurrences in a foreign function's parameters; a second mark is a type error.

An `=` in a foreign function's result is an error at the mark, with the help ``mark a in the parameters, `a=` ``. Any other mark, an `=` in an annotation outside a foreign declaration or an `e+` anywhere, is an error at the mark, with the help `` write `a`; the compiler infers the mark ``, `a` the variable written.

What a function a foreign function is given returns is the foreign code's to hand on, as a `Reply` it is given is its to answer (§8.4).

A foreign function that declares `receiving M` may receive from the calling process's mailbox and deliver into it, and promises to deliver values of `M` alone; one whose mailbox type is a variable that a parameter's function type names, `receiving e` with a parameter `(a) -> b receiving e`, promises to receive and deliver through that parameter alone; foreign code that holds a process's host identity, through `Foreign.term` of a `Process` among them (Appendix E.12), promises to deliver values of that process's mailbox type alone. Foreign code but the runtime's own calls a function it was given, whose type has `receiving`, only in the process that gave it, and, where it was given as an argument, before the foreign function returns. A foreign function without `receiving` promises to do neither, and may do anything else.

The implementation promises the declared types: a value of another shape, where it is checked (§8.4), or an exception, is a fault, §7. Foreign code sees values in the runtime's representation, §8.4. Both declarations take `export` (§4.2).

### 4.8 Operators

The arithmetic operators `+`, `-`, `*`, `/`, `%` and `<>` resolve against the operand type, by *operator resolution*. In `a + b`, `+` is `Int.+` when `a : Int` and `Distance.+` when `a : Distance`, for `export type Distance = Distance(Int)`. A user type declares its operators in its own module: `export fn Distance.+(Distance(a), Distance(b)) : Distance = Distance(a + b)`. The standard library module of a prelude type (§9) declares that type's operators the same way, with the type's name as the prefix: `fn Float.+` in `float.ern` declares `Float.+` (§9.6). In that module the prefix is allowed on an operator only; its other functions are declared unprefixed, `fn abs`.

Both operands have one type, which either may determine, and there is no numeric type to generalize over: `fn f(a, b : Int) = a + b` uses `Int.+`. The operand type is determined when its type constructor is known: `xs <> []` is `List.<>`. An operator's result does not determine its operands.

An operator is resolved once its definition is inferred, and before the definition is generalized. Its definition is the enclosing `fn` declaration, top-level or local, the enclosing top-level `let`, or a block `let` that binds a lambda (§3.9, §4.6); any other lambda belongs to the definition it stands in. So `fn add(a, b) = a + b` in a block is a type error, whatever calls it later, and `fn add(a : Int, b : Int) = a + b` is not. An operand whose type is then a type variable of the enclosing declaration's signature resolves to the member its requirement names, `needs a.+` (§4.9). An operand type still undetermined then, or a type variable no requirement names, is a type error. A field selection (§3.5) is resolved in the same way, against its operand's type.

An operator whose operand type is not determined, and a field read on a value whose type is not determined (§3.5), are reported with a help that names what to annotate and writes its form: ``help: annotate the local, `let line : ... = ...` `` where the operand is read from a local, ``help: annotate the parameter, `b : ...` `` where it is read from a parameter, and otherwise the request to annotate it. Where that type is the type of the messages a `receive` takes, or a part of it, the `receive` is labeled ``this `receive` takes the message``, the first line names the function the `receive` stands in, and the help gives that function its mailbox type with `receiving` and, for a field read on the whole message, names a constructor's pattern.

A member named by an operator has the type `(T, T) -> R` for its type `T`, `T.compare` the type `(T, T) -> Ordering`, and `T.negate` the type `(T) -> R`; each receives nothing. For a type with parameters, `T` is the type applied to any arguments, the same in each place: `Vec.+` of a type `Vec(a)` has the type `(Vec(a), Vec(a)) -> R`. A member of another shape is an error at its declaration. An operator on a type that declares no member for it, `%` on `Float` or `<>` on `Int`, is a type error.

`!` is negation on `Bool`, the prefix operator beside the logical operators `&&` and `||`; an operation the language writes as an operator has no function form (§4.5). `==`, `!=`, `<`, `<=`, `>`, `>=`, `&&`, and `||` cannot be defined per type: equality is structural and ordering goes through `compare` (§3.10); `&&` and `||` short-circuit on `Bool`. `::` is cons (§3.3); `|>` is a syntactic form (§5.7). The operators are the closed set of §2.6, and every other operation is a function.

### 4.9 Requirements

A `fn` declaration may end in a *requirement*: `needs` and the members it names, after the result type and before `=`. `fn fromList(list : List(a)) : Set(a) needs a.compare = ...` names the member `compare` of the type `a` stands for (§4.5, §3.10); `needs a.+` names an operator, and a requirement names several with commas, `needs a.+, a.*`. A requirement names `compare`, `negate`, an operator of §2.6, or `show`, which is no member but `Io.show` (Appendix E.1), and nothing else: `needs a.zero` is an error at the requirement, `` `zero` is not what a requirement names: `+`, `-`, `*`, `/`, `%`, `<>`, `compare`, `negate` or `show` ``.

The variable is a type variable of the signature that stands in a value position (§3.9); one the signature does not name is an error at the requirement, `b is no type variable of the signature`, and so is one in effect positions alone, `e is an effect variable, and a requirement names a type variable in a value position`. A variable that stands in the result type alone may carry one. A requirement names a variable's member once; naming it twice is an error at the second, with the first labeled, `the requirement names a.compare twice`. A type has one member of each name.

In the body, a member the requirement names is reached as on a known type: an operator on `a` resolves to it (§4.8), `x < y` and `compare(x, y)` through `a.compare` (§3.10) and prefix `-` through `a.negate` (§5.1). The member has its shape at `a`: `a.compare` the type `(a, a) -> Ordering`, `a.negate` the type `(a) -> a`, and an operator `a.+` the type `(a, a) -> a`. Under `needs a.show`, `Io.show` applies to a value of the type `a` itself (Appendix E.1).

A member of a type variable the requirement does not name, `<`, `compare` or `Io.show` on it, is a type error (§4.8, Appendix E.1). §3.5 says where `a.member` selects nothing.

A call writes nothing for a requirement. The requirement is supplied once the enclosing definition is inferred, as an operator is resolved (§4.8), by the type the variable is instantiated to there. Where that type is known, the compiler supplies its member: `OrderedSet.fromList([3, 1, 3])` is `fromList` with `Int.compare`. Where it is a type variable of the enclosing declaration's signature, the enclosing requirement at that variable supplies it: `fn unique(list : List(a)) : List(a) needs a.compare = OrderedSet.toList(OrderedSet.fromList(list))`. A type built from a variable, `List(b)`, is a known type, whose member is looked for.

`show` is supplied only at a type known whole, but for the variables a requirement in force names `show` for (Appendix E.1). A member with a requirement of its own, a derived `Pair.compare` (§3.5), is supplied with its own requirement met at its type by the same rule: at `Pair(Int, String)` with `Int.compare` and `String.compare`, and at `Pair(a, b)` with the enclosing requirement's.

Each of the errors below is reported at the call, or at the name where it is taken as a value. A call at a type whose member has another result type is an error naming both, `total needs Vec.+ : (Vec, Vec) -> Vec, and Vec.+ answers Float`, with the help ``a requirement names `+` at one type, (a, a) -> a; a function that takes the operation as a parameter takes this one``. A known type without the member is an error naming both: `OrderedSet.fromList needs Map(Int, Int).compare, and Map(Int, Int) has no compare`. A type variable the enclosing declaration's requirement does not name is an error naming both, `OrderedSet.fromList needs a.compare, which unique does not declare`, with the help line ``add `needs a.compare` to unique's signature``.

A declaration with a requirement taken as a value is the function with its members supplied by the same rule: `List.foldLeft(list, empty, put)` under `needs a.compare` passes `put` with that `compare`.

The requirement in force in a body is the enclosing `fn` declaration's, for the type variables of its signature, wherever a use stands in the body, in a lambda and in a `let`-bound lambda included (§3.9). A lambda a `let` binds is generalized before a call ties its own variables to the signature's (§4.6): in a block, `let build = fn(xs) = OrderedSet.fromList(xs)`, with no annotation of `xs` at a known type or at a variable of the signature, is refused, `OrderedSet.fromList needs a.compare, at the a of List(a), a type variable no requirement can name`. A call whose requirement's variable nothing fixes by its definition's end (§4.8) is refused the same way.

The line names the type that holds the variable, `at the a of T`, `a` the variable the requirement's is instantiated to: for an operator its operand's type, and for a call the first of the callee's parameter types that holds it, as the call instantiates them, or the callee's result type where no parameter does. Where that type is the variable alone, or the name is taken as a value and not called, the line has `at a type variable no requirement can name` and no type. The help is `annotate the value where it is bound`, and where the line names a type it writes the form, the type that needs the member with its open parts written `...`, `` annotate the value where it is bound, `let value : Pair(..., Int) = ...` ``.

A `fn` in a block declares a requirement for its own variables and shares the enclosing declaration's for the shared ones (§3.9). A top-level `let` declares no requirement: `let f = OrderedSet.fromList` is refused, ``OrderedSet.fromList needs a.compare, which a top-level `let` cannot declare``, with the help line ``declare a `fn` with `needs a.compare` ``.

A requirement is never inferred from a body: a declaration has the one it writes, and a derived `compare` the one §3.5 gives it. It is no part of a type scheme (§3.9); a declaration's requirement is recorded in the module's compiled interface (§11.1) and shown after its type (§11.5).

```ernest
type Date = Date(year : Int, month : Int, day : Int) derives compare

fn unique(list : List(a)) : List(a) needs a.compare =
    OrderedSet.toList(OrderedSet.fromList(list))
```

`unique(["b", "a", "b"])` is `["a", "b"]`, and `OrderedSet.fromList([Date(year = 2026, month = 10, day = 2), Date(year = 2025, month = 1, day = 1)])` is ordered by year, then month, then day.

## 5. Expressions

```
Expr      = Lambda | IfExpr | BinExpr .
Lambda    = "fn" "(" [ Param { "," Param } ] ")" [ Return ] "=" Expr .
IfExpr    = "if" Expr "then" Expr "else" Expr .
MatchExpr = "match" Expr "{" Clause { "|" Clause } "}" .
Clause    = Pattern { "or" Pattern } [ "when" Expr ] "->" Expr .
ReceiveExpr  = "receive" "{" Clause { "|" Clause } [ "|" AfterClause ] "}" .
AfterClause  = "after" Expr "->" Expr .
BinExpr   = Unary { binop Unary } .
Unary     = [ "-" | "!" ] Primary { Call | Select } .
Call      = "(" [ Expr { "," Expr } ] ")" .
Select    = "." ident .
Primary   = literal | QName | Tuple | ListLit
          | BitExpr | Block | MatchExpr | ReceiveExpr | "(" Expr ")" .
QName     = { typename "." } ( ident | conname [ "(" ( Expr | Fields ) ")" ] ) .
Fields    = ".." Expr [ "," UpdateSet { "," UpdateSet } ] | FieldSet { "," FieldSet } .
UpdateSet = ident { "." ident } "=" Expr | "=" ident .
FieldSet  = ident "=" Expr | "=" ident .
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
FieldPats = [ FieldPat { "," FieldPat } ] .
FieldPat  = ident "=" Pattern | "=" ident .
```

`fn` and `if` are not operands: `1 + if c then a else b` is a syntax error; write `1 + (if c then a else b)`. A `match` and a `receive` are (§5.9).

### 5.1 Evaluation

Strict, left to right, arguments before the call. A callee is evaluated before its arguments. In `x |> e`, `x` is evaluated before `e`: `x |> f(a)(b)` evaluates `x`, then `f(a)`, then `b`. A selection evaluates its operand, then reads the field. Nothing is delayed; `fn() = e` defers `e`. Prefix `-` is `negate` in the operand type's namespace: `Int.negate`, `Float.negate`, or `T.negate` for a user type `T`, and `a.negate` on a type variable whose requirement names it (§4.9). A user type declares `T.negate` the way §4.8 declares `T.+`.

### 5.2 Calls

`f(x, y)` supplies all arguments. A call with the wrong number of arguments is a type error at the call; a call never yields a partially applied function. An expression whose value is a function can be called directly, `makeAdder(3)(4)`.

### 5.3 Lambda

`fn(x) = e` is an anonymous function. Its body is the longest `Expr` (Appendix A). A `{` that begins the body opens a block (§5.4), which is the body.

### 5.4 Blocks

`{ s1; s2; e }` is an expression whose value is its last statement, which is an expression: a block that ends in a `let` or a `fn` is refused. `;` separates statements and never appears last. A statement is a `fn` declaration, a `let` binding, or an expression evaluated for its effect. An expression that is not the last statement has type `Unit`; a value is discarded with `let _ = e` (§5.10), whatever `e` is, one that does nothing but compute among them. A statement whose type is not `Unit` is reported whole, with the help line `let _ =`.

A `fn` declared in a block is visible throughout it, so local functions may be recursive and mutually recursive. Two `fn` declarations of one name in one block are an error. A local `fn` may not take the name of a parameter or a variable in scope where it is declared, nor of a `let` of its block. The body of a local `fn` sees the bindings in force at its declaration, and a later `let` of a name it reads does not reach it.

`let` bindings are sequential. A `fn` body that reads a name only a `let` declared later in the block binds is a compile-time error. A local `fn` may be used only after every `let` it references has been evaluated; a `let` referenced through another local function counts. A use is a call, or taking the function as a value, passing, storing, returning, or capturing it. An earlier use is a compile-time error.

### 5.5 Binding with `<-`

In a block, `let p <- e; rest` matches `e`: on `Right(v)`, `p` is bound to `v` and `rest` is evaluated; on `Left(err)`, the block's value is `Left(err)`. `p` is irrefutable (§5.10). With `Optional`, `Some` and `None` apply the same way.

In `let p : T <- e`, `T` is the type of `p`, the value inside. The sum type is decided after inference of the enclosing definition, a block `let` that binds a lambda being a definition of its own as §4.8 has it: from the type of `e`, or, if that is still open, from the block's type. Where both are open it is a type error, which asks for an annotation that fixes either, a parameter's type or the function's result type. `rest` has the block's type. All `<-` bindings in one block resolve to the same sum type.

### 5.6 Construction

`Some(e)`, `None`, `Snapshot(directory = d, seen = s)`. All fields are given, each once. `Snapshot(..p, seen = s)`, a *record update*, takes the unlisted fields from `p`. A record update with no field after `..` is a type error: ``a record update gives at least one field after its `..` ``.

A field of a field is updated through a *path*: `Pool(..pool, stats.indexed = e)` is `Pool(..pool, stats = Stats(..pool.stats, indexed = e))`, with `pool` evaluated once. A path stands in a record update only, and each type along it has one constructor with the named field. Two paths may share a prefix, `stats.indexed` beside `stats.hits`; neither may be a prefix of the other, and no path is given twice. The base is evaluated first, and the field expressions in source order (§5.1). A path that reaches a type with several constructors or none, or a field whose type is not determined, is reported at the path, naming the type reached; two paths of which one is a prefix of the other are reported at the second, with the first labeled.

An *operations record* is a record a program declares of the operations it uses on a type, filled from each representation's namespace and passed as an argument:

```ernest
type Operations(s, a) =
    Operations(fromList : (List(a)) -> s, intersection : (s, s) -> s, toList : (s) -> List(a))
```

`Operations(..Set)`, a *fill*, names a namespace after `..` and takes each field not given beside it from the declaration of its name in that namespace that the use site may name (§4.2), at the field's type; a namespace may stand alone after `..`, and `Operations(..OrderedSet, toList = mine)` takes the field given and fills the rest. The name after `..` is a namespace where it is a qualified name of type names alone, a constructor of the same name notwithstanding, and an expression otherwise. `..Prelude.N` is refused: `Prelude.` reaches a name, not a namespace (§4.2).

A field with no declaration of its name in the namespace is an error naming the field and the namespace: `` `Operations(..Map)` lacks intersection: Map has no intersection ``. A field whose declaration there has another type is a type mismatch naming the field and the declaration, `` `Operations(..Set)` fills fromList with Set.fromList: expected ..., found ... ``, the constructor labeled with the field as declared. A fill's error is reported at the namespace after `..`.

A declaration with a requirement (§4.9) fills a field with its members supplied at the field's type, which the construction's type must fix; where that type leaves the requirement's variable undetermined, the fill is an error naming the declaration and the variable, whose help asks for an annotation: `let ops = Operations(..OrderedSet)`, with the `Operations` above, is refused, `OrderedSet.fromList needs a.compare, and the record's type leaves the variable a undetermined`. A fill whose requirement the enclosing declaration does not declare is an error naming the declaration, the enclosing one and its variable, `OrderedSet.fromList needs b.compare, which g does not declare` in `fn g(list : List(b))`. `..` is allowed only on a type with one constructor; on any other it is a type error. A constructor is qualified like a function, `Net.Http.Request(...)`.

A field given the value its own name names in scope may be written once, `=seen` for `seen = seen`, a *pun*: `Snapshot(=directory, =seen)` is `Snapshot(directory = directory, seen = seen)`. A pun stands beside the other forms, `Snapshot(=directory, seen = s)`, `Snapshot(..p, =seen)`, `Operations(..Set, =toList)`. A pun names a field: `Some(=x)` is a type error, `Some has one positional field`, with the help ``write `Some(x)` ``.

A nullary constructor is a value. A single-positional constructor is a function value. A named constructor is neither; it appears only in construction syntax.

### 5.7 Pipe

`x |> e` applies `e`, a function value or a call, with `x` inserted as the first argument: `x |> f` is `f(x)`, `x |> f(a, b)` is `f(x, a, b)`.

```ernest-fragment
let words = input |> String.trim |> String.toLower |> String.toList
```

`|>` is left-associative and binds loosest, below `||`: `a + b |> f` is `f(a + b)`, `a |> b |> c` is `c(b(a))`.

The right-hand side is an operand (Appendix A), or operands joined by operators that bind tighter than `|>` (§2.6). A right-hand side that is a call is filled: the pipe fills its first-argument slot. Any other, a name, a qualified name, a field selection `s.f`, a block, a `match`, a `receive`, or an expression with a binary operator, is a value applied to `x`, and one whose value is not a function, or is a function of no parameter, is a type error: `x |> [f]`. Parentheses around a call or a name on the right-hand side change nothing: `x |> (f(a))` is `f(x, a)`, and `x |> (f)` is `f(x)`. A construction is such a value and no call (Appendix A), so the pipe does not fill it: `x |> Some` is `Some(x)`, and `x |> Some(2)` and `x |> W(b = 2)` are type errors.

A lambda, an `if` and a pipe stand as the right-hand side only in parentheses, and each is then a value applied to `x`: `x |> (fn(y) = y + 1)`. A pipe in parentheses is no call, and the outer pipe does not fill it: `x |> (a |> f)` is `f(a)(x)`.

In a chained call the pipe fills the outermost call: `x |> f(a)(b)` is `f(a)(x, b)`. A function a call computes is applied in writing, `f(a)(x)`. The type of `x` is the target's first parameter type.

### 5.8 Conditional

`if c then a else b` with `c : Bool`; the branches have the same type.

### 5.9 `match`

A `match`, like a `receive` (§6.3) and a block, ends at its own `}` and may stand as an operand: `n > 0 && match x { ... }`. `if` and a lambda end in no delimiter of their own, and stand as an operand only in parentheses.

The value is matched against the clauses' patterns in order; the first clause whose pattern matches and whose guard holds is evaluated. A clause may list several patterns separated by `or`, an *or-pattern*, and matches when any of them does: for `type Player = Player(alive : Bool, body : List(Int))`, `Player(alive = false) or Player(body = []) -> 0` matches a player that is not alive or has no body. Every alternative binds the same variables at the same types; the guard and the body see them. Alternatives that bind different variables are a type error.

The clauses together must cover the type, and a `match` that does not is a type error, `match on Shape is not exhaustive; missing Dot, Circle(_) and Blob(_)`. The line shows up to three patterns no clause matches, in the order the check finds them, a type's constructors in declared order, each with a wildcard where any value is missing and a constructor of named fields as `Square()`: `missing _` for an `Int`, `missing []` for a list. Two read `missing A and B` and three `missing A, B and C`; a line that leaves some out names three and ends `and more`, `missing A, B, C and more`. `true` and `false` together cover `Bool`.

A clause, or an alternative of one, is *redundant* when it can match no value the clauses and alternatives before it leave unmatched, and a redundant clause is a type error: `n -> n | 0 -> 1`. A guard is read neither for redundancy nor for coverage. For coverage a guarded clause is taken to match no value.

For redundancy, a bitstring pattern in an earlier clause is taken to match no value, and one in the clause being judged to match any value. A guarded clause before the one being judged is taken to match no value, so `n when n > 0 -> 1 | n -> 0` is not redundant.

A guard is a `Bool` expression that receives nothing and sees the pattern's variables and the enclosing scope. A guard that is `false` falls through to the next clause; a guard that faults faults the process. A `receive` guard falls through likewise, and is restricted further (§6.3).

### 5.10 Patterns

A pattern decomposes a value and binds its parts; the same patterns appear in `let`, in `match` and `receive` clauses, and in parameters.

`_` matches anything and binds nothing. An identifier binds the whole value at its position to a new variable, shadowing any outer one; it never refers to an existing variable. A literal matches itself, and a numeric literal may carry `-`: `match n { -1 -> "minus one" | _ -> "other" }`.

A constructor pattern, `Some(p)` or `Snapshot(seen = s)`, matches that constructor and decomposes its fields; field patterns may omit fields. A field pattern that binds a variable of the field's name may be written `=seen`, a pun, for `seen = seen`. A nullary constructor is written bare: `None`. A single-positional constructor takes one pattern: `Some(p)`. A constructor with named fields takes its field patterns in parentheses, and may omit them all: `Circle()` matches any `Circle`. Any other form is a type error: `None()`, `Some`, `Some()`, and a bare `Circle`; so is a pun in a single-positional constructor's pattern, `Some(=x)`, `Some has one positional field`, with the help ``write `Some(x)` ``.

A tuple `#(p, q)`, a list `[p, q]`, and `p :: q` decompose a tuple, a list, and a cons. Patterns nest to any depth. `p as c` binds `c` to the whole value that `p` matches. `as` binds looser than `::`: `x :: rest as all` names the whole list. `or` stands between a clause's whole patterns (§5.9), and `as` names what one of them matches, so each alternative names the value itself: `Some(1) as x or Some(2) as x`. An `or` inside a pattern is reported at the alternatives it joins, ``an `or` stands between a clause's whole patterns``. In a clause the help line writes the clause's alternatives out whole: ``write the clause's alternatives out: `#(Paste, _) or #(Load, _)` `` for `#(Paste or Load, _)`.

A `,` after a constructor pattern's positional field is reported as a second positional field in a declaration is (§3.5), `a constructor has exactly one positional field`, with a help line in a pattern's terms, ``name the fields, `V(x = ..., y = ...)`, or match a tuple, `V(#(..., ...))` ``.

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

A segment without specifiers is `int` of size 8. A segment is `big` and `unsigned` unless it is marked otherwise. An `unsigned` segment of n bits holds 0 to 2^n − 1, and a `signed` one −2^(n−1) to 2^(n−1) − 1. `<<-1:signed>>` is the byte `0xFF`: the pattern `<<x>>` matches it with `x` bound to 255, and `<<x:signed>>` with `x` bound to −1.

`signed` and `unsigned` apply to `int` segments, and `big` and `little` to `int`, `float`, `utf16`, and `utf32` segments; any other combination is a type error. `int` binds to `Int`, `float` to `Float`, the `utf` forms to `Char`, `bytes` to `Bytes`. A segment names at most one type (`int`, `float`, `bytes`, a `utf` form), one endianness, one sign, and one `size`: two of one kind, or one written twice, is a type error, `x:big-little`. A `float` segment is 16, 32, or 64 bits. A `utf` segment has no size. In a pattern, a `bytes` segment without a size takes the rest of the value and is the last segment. In a construction, a `bytes` segment without a size is its whole value, wherever it stands.

The specifier names are specifiers only where a `BitSpec` stands, after a segment's `:` or `-`. Elsewhere, in a bitstring as outside one, they are ordinary identifiers: in `<<size:size(int)>>`, the first `size` and `int` are variables.

A bitstring's total bit count, in construction and in a pattern, is a multiple of 8. A violation of these rules the compiler can see is a compile-time error; one that depends on a dynamic size faults at construction (below) or fails to match. A value that does not fit its width is an error too: a numeric literal, negated or not, that does not fit a segment of constant width is a compile-time error, in a construction and in a pattern, and any other value that does not fit faults at construction or fails to match. `<<-1>>` is a compile-time error, and `<<n>>` with `n` −1 faults.

A value that does not fit its width at construction, other than a literal the compiler refuses, faults with `Fault("segment overflow: 300 does not fit 8 bits")`, `signed bits` for a signed segment, `a 32-bit float` for a float, and `a 3-byte value does not fit 2 bytes` for bytes, and with `Fault("segment overflow")` where the host refused the segment. A dynamic total bit count that is not a multiple of 8 faults with `Fault("bitstring not byte-aligned")`.

A segment pattern is a variable, `_`, or a literal of the segment's type, a negative numeric literal among them: `<<-1:signed>>`. `size(Expr)` in a pattern is a variable, a top-level `let`, an `Int` literal, or `+`, `-`, or `*` applied to these. The variable is bound by an earlier segment of the same bitstring, or is in scope where the pattern stands: a parameter, a block `let`, a pattern variable of an enclosing clause, or a lambda's capture. A top-level `let` is read when the `match` begins, after its scrutinee, or when the `receive` begins. A variable bound elsewhere in the same pattern is not in scope in its sizes. Any other segment pattern or size expression is a type error. A negative or out-of-range size fails the match.

Construction evaluates the segments left to right. A `bytes` value fits a sized segment only when it is exactly that long. A negative size fits no value. A `float` value is rounded to a 16- or 32-bit width to nearest, ties to even, and a value too small for the width becomes `0.0`; one whose magnitude exceeds the width's largest finite value does not fit. `<<>>` is the empty `Bytes`.

```ernest
fn frame(bodySize : Int, body : Bytes) : Bytes =
    <<bodySize:size(16)-big, body:bytes>>

fn parseFrame(bytes : Bytes) : Optional(#(Int, Bytes, Bytes)) =
    match bytes {
        <<bodySize:size(16)-big, body:size(bodySize)-bytes, rest:bytes>> ->
            Some(#(bodySize, body, rest))
      | _ ->
            None
    }
```

For coverage (§5.9) a bitstring pattern, at any depth, counts as matching no value. A position that holds one is covered only by a `_` or a variable at that position in another clause: `Some(<<x>>) | Some(_) | None`.

## 6. Processes

A process is an execution of a function with a mailbox type. It has a mailbox that receives values of that type, in arrival order per sender.

### 6.1 The mailbox type

`(A) -> B receiving M` is the type of a function whose own process's mailbox is involved, the mailbox of type `M`: it receives from it, gives out the address `self` answers through its type, asks for a message to be delivered into it, as `monitor` and `spawnMonitored` do through their wrap (§6.9, Appendix E.0 shape rule 8), or calls a function whose type names one, a prelude function of §9.4 or §9.5 or a foreign function among them. Its type names `M` but where `M` is a variable that is none (§3.9, §4.5), and then the function receives nothing, as `fn f() = kill(Process.fromAddress(self()))` does.

Every function runs in a process; that is not marked, and neither is what a function does through other processes or through the world: a `send`, a `spawn`, a `kill`, an `answer`, a call, printing, a file, a socket or a clock carry no mark.

The mailbox type is inferred. A function that calls a function receiving `M` receives `M`. Two calls with different concrete mailbox types in one body are a type error. Calls with variable mailbox types unify. A call of a function without `receiving` contributes nothing. A `receive` gives the mailbox type its patterns, guards and bodies fix; one that fixes none is process-only (§3.9). A function that contains no `receive`, calls no `self` whose address its type carries, asks for no delivery and none of whose calls determines a mailbox type receives nothing (§3.9).

| Written | Meaning |
|---|---|
| `(A) -> B` | receives nothing; callable from any process |
| `(A) -> B receiving M` | receives from its process; callable only where the mailbox type is `M` |
| `(A) -> B receiving m`, `m` a variable | receives when `m` is a mailbox type; `m` takes the caller's mailbox type |

A function that calls a function argument runs it in the caller's process and is effect-polymorphic in it (§3.9): `List.map(xs, fn(x) = receive { n -> x + n })` has the callback's mailbox type, and `List.map(xs, fn(x) = send(a, x))` has none. Nothing else is written on a function type.

### 6.2 Built-in functions

`self`, `send`, `spawn` and `spawnMonitored` are the prelude's, and §9.4 lists their types. `self()` is the process's own address. `send(a, v)` places `v` in the mailbox of `a` and returns at once. To an adapted address made on the sender's node it first applies the address's function, in the sender (§6.5), and returns when that has returned. Sending to a dead process has no effect. To a process of another node it hands `v` to the runtime and returns, and waits only while more waits to be sent to that node than §8.7 states. A `send` promises the sender nothing.

The one silence in the language is an act on what has ended, or cannot be reached, that asks nothing back, which does nothing and says nothing: a message whose receiver has ended or restarts (§6.9), or whose request has timed out or been answered, is dropped; a message or a `kill` to a process whose node is out of reach or not listed vanishes, while the process may live on (§8.7); and a `kill` (§6.9), a close, a `give` or a `closeInput` of a resource that has ended (Appendix E.18, E.23) does nothing. A program's end keeps no promise (§8.6). Every other failure is a value, a message, or a fault (§7).

`spawn(f)` starts a process on the running node that runs `f()` and returns its address. `self()` inside `f` is the new process's address. The mailbox type `n` of `f` appears in `Address(n)` and so is a type (§3.9). An `f` that receives nothing fits, as such a function fits wherever one receiving `n` is expected, and `n` is then what the context makes it: a process that never receives is spawned as any other, and what is sent to its address waits in a mailbox nothing reads.

Where nothing has fixed `n` by the end of the definition the spawn is written in (§4.8), or of the shell's input (§11.2), and no call fixes it (below), `n` is *unfixed*, and is `Never` (§9.1): a top-level `let p = spawn(fn() = Io.println("x"))` binds `p : Address(Never)`, to which nothing can be sent. Definitions that name one another end together (§3.9), and where a name in scope around the definition holds `n`, the same is asked at the end of the definition around it.

A variable that a parameter's type holds, the definition's own parameter or a parameter of a function the definition answers, at any depth, or that is the definition's own mailbox type, is fixed by each call and keeps: `fn start(f) = spawn(f)` has type `(() -> Unit receiving n) -> Address(n)`. One that only a function inside a value the definition answers holds, a tuple's, a list's or a constructor's, is unfixed. A function such a value holds by its top-level name keeps its own variable: `#(start, 1)`. In a top-level `let` that is not generalized, a variable so kept is refused as §4.6 says.

`Peer.spawn(name, f, ms)` and `Peer.spawnMonitored(name, f, wrap, ms)` start the process on the peer named (§8.3), and answer its address or a failure, as a value (§8.7, Appendix E.27). The values `f` captured cross to the peer (§3.11).

`spawnMonitored(f, wrap)` starts the process as `spawn(f)` does, and the caller monitors it from its start (§6.9): `wrap(d)` is placed in the caller's mailbox when it ends, with its reason, however soon that is. A `monitor` made once `spawn(f)` has returned gives the reason `Unknown` where the process has already ended (§6.9).

### 6.3 `receive`

`receive { clauses }` matches the mailbox in arrival order. The first message that matches a clause's pattern and guard is removed and the clause is evaluated; the rest remain. If none matches, the process waits. Patterns are typed against the mailbox type. Coverage is not required: a message no clause matches stays in the mailbox. A redundant clause is a type error, as in a `match` (§5.9).

A guard selects a message without removing it, so a `receive` guard is a *guard expression*. Its operands are the variables in scope, the pattern's and a lambda's captures among them, a field selected from a variable in scope or from a top-level `let`, or from such a selection, `s.at`, `s.lot.at` (§3.5), literals, negative numeric literals, and nullary constructors. A top-level `let` is an operand too, read when the `receive` begins.

A guard expression is `true`, `false`, an operand of type `Bool`, a comparison of two operands with `==`, `!=`, `<`, `<=`, `>`, or `>=`, `!` before a guard expression, or two guard expressions joined by `&&` or `||`. An operand, and a guard expression, may stand in parentheses. `<`, `<=`, `>`, and `>=` compare `Int`, `Float`, `String`, `Char`, and `Bool`, in their order (§3.10), and on another type are a type error. A guard expression calls nothing and cannot fault.

A final clause `after t -> e` gives a time limit of `t` milliseconds; `t` is evaluated on entry, and corrected as §7.4 says. A time has no upper bound. When the limit passes without a matching message, `e` is evaluated. `after 0` does not wait for a message. Without `after` there is no limit. A `receive` has a pattern clause. One with an `after` clause alone is a syntax error, ``a `receive` takes a message``, with the help ``to wait a time, write `Clock.sleep(ms)` ``, `ms` being the `after`'s time where it is a literal or a name, and `...` otherwise. An `after` clause that another clause follows is a syntax error: ``the `after` clause of a `receive` comes last``.

### 6.4 Message ordering

Messages from one process to another are received in sending order, but for the one step more of §6.5 and that of a check (§8.4). Between different senders there is no ordering.

### 6.5 Addresses

`Address(m)` identifies a process on a node and carries its protocol: `send(a, v)` is type-checked against `m` on any node.

`adapted(addr, f)`, §9.5, is an *adapted address*, `addr` seen through `f : (a) -> b`: sending `v` to `adapted(addr, f)` sends `f(v)` to `addr`. `f` is applied on the node where `adapted(addr, f)` was made: by the `send`, in the sender, when the sender is on that node, and when it is not, on arrival there, in a process the node keeps for the address and the sending node, started as a message arrives and ended once none waits. A function that never finishes holds the messages to the address from that node and nothing else.

What `f` opens, spawns or asks of the runtime is the sender's where the send applies `f`. On arrival it is the target's where the target is on that node, as a wrap's is its recipient's (§6.9); where the target is on another node, a resource `f` opens ends with the process kept for the address, and a process it spawns heads a chain of its own. In each of the three cases `self()` in `f` is the address of the process that owns what `f` opens, the sender, the target or the process kept for the address, `Process.current()` in `f` is that process (Appendix E.21), and a `monitor` in `f` is that process's monitor, whose wrap is as a `monitor`'s in a `wrap` (§6.9).

A `send` that applies `f` returns once `f` has, and a sender's messages keep their order through it (§6.4), with one exception: a message to an adapted address made on another node than the sender's takes one step more, on the node that made it, and a message sent straight after it to another address can pass it.

An adapted address crosses to another node as a reference to `f` and the values `f` captured, which cross as payload and are touched on no other node (§3.11). A `send` to it from another node carries `v` to the node where it was made, where the process kept for it applies `f` and sends `f(v)` on to `addr`, on whichever node its process is.

An adapted address held on another node keeps nothing alive on the node that made it. A process or a resource that a captured value names lives there as though no address named it, and what the host holds for a captured value of a foreign type lives as the host has it, where the host keeps it only while a process of that node reaches it (§10); each may have gone when a message arrives. Every other captured value comes back with the message as it crossed. A use in `f` of a process or a resource that has ended is what it is in any function, a foreign function given a value the host holds nothing for does what the host's function does, and a fault of either is a fault in `f` (below).

`adapted(self(), Wrap)`, with `Wrap : (Int) -> Msg` and the mailbox type `Msg`, is an `Address(Int)`; a value sent to it arrives as `Wrap(v)`.

A fault in `f` is the target's, on one node and across nodes alike: it takes the message's place in the target's mailbox, with one exception (below), and the target faults at the wait that reaches it, as at a fault of its own (§8.4), which `restarting` restarts (§6.9); a target the runtime did not start, a foreign process (§8.4), has no wait of Ernest's and is sent the fault as an exit signal, and one on another node takes the fault as a message; the sender goes on.

The fault goes straight to the target. Where `f`'s results go on through an adapted address made on another node than the one that applies `f`, they take the one step more on the node that made it (above), and the fault can pass a message sent through that address before it.

Addresses have no equality (§3.10). An address is the permission to send to a process; a `Process` is its identity, which a `Down` carries, a monitor watches and `kill` ends (Appendix E.21). The process behind an address is `Process.fromAddress(a)`, a value with equality that nothing can be sent to (§6.9, Appendix E.21). There is no registry of a node's own processes. A process reaches another through an address it holds or received, through a top-level binding that holds one, which is a *service*, through `Code.running` of the function the other runs (§6.10), or, from another node, through the name the service is offered under (§8.7):

```ernest-fragment
export type LogMsg = Line(String)

export let log : Address(LogMsg) =
    spawn(restarting(RestartLimit(restarts = 3, within = 5000), logger))
```

`restarting` keeps the service's address across its faults (§6.9). A service binding grants the permission its address is to the modules that see the binding (§4.2), and an offer of the service to every peer of the node (§8.7). An exported function that `Code.running` takes (Appendix E.28) grants it to its users, for every process running the function (§6.10).

### 6.6 Request-reply

A request carries a `Reply(a)`, a one-shot address for its answer. `Address.call`, `Address.callForever` and `answer` are the prelude's, and §9.5 lists their types.

`Address.call(address, request, ms)` allocates a fresh `r : Reply(a)`, sends `request(r)` to `address`, and returns `Some(v)` when the recipient answers or `None` after `ms` milliseconds, `ms` corrected as §7.4 says. `Process.fromReply(r)`, Appendix E.21, is the caller's `Process` (§6.9), with which the callee may monitor its caller; it gives no address, so nothing is sent through it. The clock starts at the call. `request(r)` is evaluated in the caller and sent from there as `send` sends it (§6.5). `ms` bounds the wait for the answer and nothing before it: the request is evaluated and sent though the `ms` milliseconds have passed, and a wait that begins after they have passed ends at once. A reply that arrives together with the timeout may be delivered or discarded. `Address.callForever(address, request)` waits without limit and returns `a`. A callee that lives on without answering holds a `callForever` caller for as long as it lives.

Where more waits to be sent to the callee's node than §8.7 states, either call waits as a `send` waits there, before its wait for the answer begins and after that wait has ended, and returns or faults only once it waits so no longer.

When the process `address` names has ended, or ends or restarts before it answers, the wait ends at once, and so it does when the process's node goes out of reach (§8.7). `Address.call` then returns `None`, which says that no answer came, and nothing of whether the request was received or ran. Where the callee is on another node, its death ends the wait when a `Down` to the caller would be sent, which may wait on a third node (§8.7).

`Address.callForever` faults the caller: with the callee's cause where the callee faulted, restarted after its fault or not, the cause unchanged along a chain of calls, with `Fault("callee was killed")` where it was killed, with `Fault("callee returned without answering")` where its function returned, with `Fault("callee was closed")` where the program closes it, a socket or a listener (Appendix E.18), with `Fault("callee was restarted")` where it restarted because a restart was asked of it (§6.9), with `Fault("callee had ended")` where it had ended before the call, with `Fault("callee ended with its program")` where it is a process of another node that ended with that node's program (§8.7), and with `Fault("callee is unreachable")` where its node went out of reach (§8.7).

The report of a caller's fault names the callee's site after the cause, where the runtime knows the site and the cause is the callee's own or says how the callee ended (§11.2). Where the callee is a process of another node, whose site the runtime does not know, the report names the callee's peer after a cause that is the callee's own (§11.2).

Where the caller's own program ends, the caller ends with it. A request handed on to another process is watched only at the process it was sent to.

`answer(r, v)` sends `v` to the caller. A call's reply travels by an identifier private to the call, never through the caller's mailbox. A late answer, after a timeout or the caller's death, is discarded silently, as is a second answer to a `Reply` already answered. The recipient cannot observe whether the caller still waits.

### 6.7 Remote computation

Work on a peer is a process spawned there, `Peer.spawn(name, f, ms)`, or a function run there for its value, `Peer.compute(name, f, ms)` on the peer named or `Peer.computeAnywhere(f, ms)` on one the node draws, as §6.2, §8.7 and Appendix E.27 say.

### 6.8 `Never`

A function receiving `Never` can send but never receive a message: a `receive` written in a body receiving `Never` is a type error, and such a body waits a time with `Clock.sleep` (Appendix E.15). A function whose mailbox type is a variable, called at `Never`, waits in its `receive` for a message that cannot come, and where nothing else can run the entry process faults with `Fault("deadlock")` (§8.6).

`Never` is the mailbox type of a top-level initializer (§4.6), of the entry process where the entry point receives nothing (§8.6), and of a spawned function's process where nothing fixed it (§6.2); `self()` there is an `Address(Never)`, to which nothing can be sent. A function that receives nothing, `main` or the function a spawn runs among them, writes no mark, and is called from any process.

### 6.9 Death

A process dies when its function returns, when `kill` is called on it, on a fault (§7.3), or when the program ends (§8.6). Its `Reason` (§9.3) says which: `Returned`, `Killed`, `Fault(cause)`, or `ProgramEnd`. A monitor on a process of another node gives `Unreachable` when that node goes out of reach or its end drops the `Down`, which says nothing of whether the process lives (§8.7). A process the host ends otherwise, killed by foreign code or by the end of a process it is linked to, has the reason `Fault(text)`, `text` the host's term as the host writes it.

`kill` is asynchronous: the target may run until the runtime interrupts it. `kill` on a process that is dead has no effect, and `kill` on a process of another node reaches it as `send` does (§6.2).

`monitor(p, wrap)`, §9.5, places `wrap(d)` in the caller's mailbox when the process `p` dies; `d : Down` gives the process and the cause. `p` is a `Process` (§6.5), which `Process.fromAddress(a)` gives for an address `a`, and `kill` takes one too (Appendix E.21). `process` in `Down` is `p`. If `p` is already dead, the message is placed at once, with the reason `Unknown`. A `monitor` made while the process runs gets its reason, and a process started with `spawnMonitored` (§6.2) is monitored from its start. Each `monitor` call produces one message.

`monitorService(p, wrap)`, §9.5, is a *service monitor*: a monitor that is told of a restart too. At each restart of `p` (below) it places `wrap(d)` in the caller's mailbox with the reason `Restarted` and stands; at `p`'s death it delivers as `monitor` does, and ends.

A `Down` with `Restarted` comes to a service monitor alone, and reaches its watcher before anything the new run sends: the restarting process empties its mailbox, waits until each service monitor's `wrap` has placed its message, and then runs `f` again, so a wrap that does not finish holds up that restart. A wrap the runtime has no room to apply, whose watcher faults instead (§7.4), holds it up no longer, as a subscriber the end cannot tell does not hold up the end (§8.6). Where `p` dies while its restart waits, each delivery of `Restarted` not yet placed ends with it, so no `Restarted` follows the `Down` of `p`'s death.

A service monitor on a process of another node is told of its restarts too, by the runtime's own frames (§8.7), and of its death and of a loss as a monitor is; a restart of a process that a process of another node monitors or calls waits for that node's answer as it waits for a wrap, at the latest until a loss or that node's end (§8.7).

`demonitor(p)`, §9.5, ends every monitor the caller holds on `p`, whichever function of the process asked for them, service monitors among them; a `Down` already in the caller's mailbox stays, and none comes after. A `demonitor` on a process the caller does not monitor does nothing.

A `Down` comes from the runtime and has no order with the messages the ended process sent (§6.4). The answer to a call (§6.6) is not overtaken by the callee's `Down`. Where two processes die, their `Down`s have no order with each other, whichever died first. The `Down` of a process of another node may wait on a third node (§8.7).

The runtime applies a `wrap` as it delivers the message. A fault in it is the fault of the process it delivers to, which meets it at its next wait (§6.5). What a `wrap` opens, spawns or asks of the runtime is that process's too, as if it had done it itself (Appendix E.18, E.21): `Process.current()` in it is that process, `self()` in it is that process's address, and a `monitor` in it is that process's monitor. A `wrap` receives nothing (§3.9), and the wrap of a `monitor` in it answers no value: it faults or does not finish. A `wrap` that does not finish holds up no other delivery. A delivery to a process that has ended ends with it.

`site` in `Down` is where the dead process was spawned: the qualified name of the top-level declaration in which the `spawn` or `spawnMonitored` that started it is written, with the line where it is written: `Counter.main:19`. A `spawn` in a lambda or a local `fn` counts as written in the top-level declaration that contains it. Where `spawn` is passed as a value, it counts as written where its name is.

The entry process's site is the entry point's name, and a bare node's (§8.1) is `bare node`. With the reason `Unknown` or `Unreachable` it is the empty string, and so it is for a process of another node: a process's site is its node's record, and the node where a process faulted reports the fault with its site (§11.2).

A monitor is the one link a program makes between two processes. A process the program spawns belongs to no one, and ends only as this section says. A process the runtime starts for a resource, a socket, a listener, or a program the runtime started, belongs to the process that opened it or was given it, and is killed when that process dies. Closing the resource ends its process with the reason `Returned`, and killing its process closes it. An alarm is no process and belongs to the process that set it (Appendix E.15).

`restarting(RestartLimit(restarts = n, within = t), f)`, §9.5, is a function that runs `f()` and, when `f` faults, runs `f()` again in the same process. The `f` run again is the one given, so a process that has moved to new code by a message of its type (§6.10) runs the code it started with at its next fault.

The process keeps its address, and the new run begins with nothing of the old one that the process holds: what it spawned, opened or put in a table lives on. Its mailbox is emptied, the message being handled lost with the rest, and every call waiting for an answer from it ends (§6.6), before its service monitors are told (above). What the process has asked the runtime for is canceled, with what is on its way to it, whenever it asked, before its first run or in any run: its alarms (Appendix E.15), its monitors, and its subscriptions to the terminal (§12.1), to faults (Appendix E.21) and to the program's end (Appendix E.23). A message that arrives while the process restarts is dropped or taken by the new run. A restart is not a death.

When `n` restarts have happened within the last `t` milliseconds, the next fault is not restarted; a window and a count are corrected as §7.4 says. A fault restarts the innermost restarting function the process runs, which counts it against its own limit; one that does not restart it gives it to the restarting function around it, and the process dies with its cause where there is none. A restarting function counts from when it is entered, so one entered again by the restart of the one around it counts afresh. `restarting(Unlimited, f)` runs `f()` again after every fault. `f` returning, a `kill`, and the program's end end the process as they end any other.

A restarting function called where the runtime applies a function for another process, in a `wrap` the runtime applies as it delivers (§10) or in an adapted address's function on delivery (§6.5), faults with `Fault("restart in a function the runtime applies")`, which the process the function delivers to meets as it meets any fault there. A wait in such a function, a `Clock.sleep` (Appendix E.15), is the applying process's own, and a restart asked of the recipient reaches the recipient's next wait of its own.

A child of a `Supervisor` (Appendix E.22) also runs `f()` again when its supervisor asks. It runs on until it next waits, in a `receive`, in `Clock.sleep`, for a call's answer or for a load's (Appendix E.28), and there runs `f()` again; a process already waiting does so at once. It restarts as a fault restarts it (above). A restart asked for is not a fault: it counts against no limit, and no fault is reported. Where `f` itself runs a `restarting` function, the restart asked for runs `f()` again, not the inner one.

### 6.10 Code replacement

A process replaces its code by a message in its own type that carries the new loop, and switches with a tail call:

```ernest
type CounterMsg = Inc(Int) | Get(Reply(Int)) | Upgrade(next : (Int) -> Unit receiving CounterMsg)

fn count(total : Int) : Unit receiving CounterMsg =
    receive {
        Inc(amount) ->
            count(total + amount)
      | Get(reply) -> {
            answer(reply, total);
            count(total)
        }
      | Upgrade(=next) ->
            next(total)
    }
```

An `Upgrade`, which holds a function, does not cross nodes (§3.11). A process on another node is sent its `Upgrade` by a process spawned on that node, whose function captures nothing bound and names the service and the new function by their declarations; the service there is the peer's, and a function the peer lacks crosses with the spawn (§8.7): `let _ = Peer.spawn(name, fn() = send(Counter.service, Counter.Upgrade(next = Counter.countAloud)), 5000)`.

`Code.running(f)` lists the addresses of the processes running a function (Appendix E.28): `List.forEach(Code.running(Counter.count), fn(p) = send(p, Counter.Upgrade(next = Counter.countAloud)))`, written where the processes run, moves every process on `count`.

A type that carries `Upgrade` holds a function and is bound to its node (§3.11). A process reached from another node, a service or one spawned on a peer, is offered through an adapted address (§6.5) of a type without it, and its upgrade is sent on its own node.

The language has no other mechanism for code replacement. The shell's reload (§11.2) runs a call by name on the new code, and a call through a function value on the version current where the value was taken, and never changes the code a running process runs.

## 7. Errors

There are no exceptions. An error is a value, a message, or a fault.

### 7.1 Value errors

The error is part of the function's meaning and is in its result type, `Either(e, a)` or `Optional(a)`. The caller matches on the result or chains with `let p <- e` (§5.5).

### 7.2 Message errors

The error crosses a process boundary and is in the message: `Either`, or a constructor of the reply type. A missing reply is `None` from `Address.call`, after the time limit or once the callee has ended or restarted (§6.6).

### 7.3 Faults

A fault ends the process that meets it, or, for a function applied on a message's way (§6.5, §6.9), the process the message is for, with the reason `Fault(cause)` that `Down` carries (§6.9), unless the process restarts (§6.9). The code cannot see it, and nothing catches it. Each cause is stated with its text in the section §7.4 names for it, the supervisor's in Appendix E.22. A process that is killed, or that ends with the program, has not faulted. A function that receives nothing can fault.

A fault carries a trace, the host's stack where the fault was met, at the moment it was (Appendix E.21); the fault's report shows it (§11.2), and `Down` carries the cause alone.

### 7.4 Causes of faults

A function answers a failure as a value: `Optional` where the failure has no cause the program can act on, `Either` where it has one (§7.1). A function faults only where it cannot return, where its result is a `Float` the finite range cannot hold (§3.1), where its result has no room for the failure, where a rule of this report refuses the request (below), where it reads a variable of the program's environment that is not UTF-8 (Appendix E.23), or where the failure is the runtime's own, a boundary crossed, a limit of the host met by the process's own work, a spawn's or an `Int`'s. An operator and a construction the grammar gives fault.

A request a rule of this report refuses, which the program alone could have kept, faults the process that made it: a second process running a group, a claim of the terminal the other way, a `Forever` form's call on a socket, a listener or a program that has ended (Appendix E.18, E.23). An argument the host cannot take whole is `Left(Invalid)`; one outside the function's own domain is answered as the function's section says, and where the section says nothing, by `None` or a `Left` where the result has room for one and by a fault where it has none; it is corrected only where this section or the function's says. What the world refuses, a port in use, a file that exists, or a full table of the host's that a request of `Fs`, `Tcp`, `Os` or `Terminal` needs room in, is a value with its cause (§12.5).

A failed read of standard input faults the process that asked for the line or the bytes (§12.1). A failure no request stands behind, keys that are not UTF-8 or a key that a full table of ports leaves no room to read (§12.1), faults the entry process; standard output or standard error that cannot be written, and keys the host can no longer read, end the program without a fault (§8.6, §12.1).

A count or a duration below 0 is 0, but for a terminal's rows and columns (Appendix E.23), and a window below 1 is 1 (§6.9); a duration has no upper bound, and a moment already past is now; no other value is corrected unsaid.

A cause's text stands with its rule: an operator's in §3.1, a bitstring's in §5.11, a `callForever`'s in §6.6, a restart's in §6.9, the boundary's in §8.4 and §12.3, a deadlock's in §8.6, a load's and a shell's in §11.2, the terminal's and standard input's in §12.1, and a standard library function's in its section. `fault(c)`, which compiles at any type, faults with `Fault(c)`.

A failure in the runtime faults the process that meets it with the host's class and reason, as a spawn beyond the host's limit of processes does with `Fault("error:system_limit")`. A message or a delivery the runtime has no room to make, through an adapted address, a wrap or the end's telling of a subscriber, faults the process it is for with `Fault("error:system_limit")` at its next wait, as a fault in a function adapting an address faults its target with its own cause (§6.5).

## 8. Programs

### 8.1 `main`

The entry point is a function of type `() -> Unit`, `receiving m` or without. The process that runs it is the *entry process*. `m` is the message type where the entry point receives; where it receives nothing, or `m` is a variable, the process's mailbox type is `Never`. A result type that is a type variable, as a function that never returns has, is taken as `Unit`.

A top-level `let`, a function of another shape, and a private function are not entry points, and `ern run` refuses them. `ern run module.erc` runs the `export fn main` of that module; `ern run --main name module.erc` runs another exported function of that module and that shape. `main` is a convention, not a reserved name. A bare node (§8.7) has no entry point: its entry process, whose site is `bare node` (§6.9), evaluates the standard library's bindings (§8.5) and waits, and the node ends as §8.6 says.

### 8.2 System references

The runtime starts its system processes when the program starts, whether or not the program uses them. Each process's address is a top-level binding of its *system module* in the standard library, private to that module: `stdout`, `stderr`, and `stdin` of `Io`, and `reference` of `Terminal`, `Clock`, `Fs`, `Tcp`, and `Os` (Appendix E). A program uses each through its module's functions. The binding's initializer is a `foreign fn` of the module that answers the runtime's address (§4.7), evaluated before the program's other bindings (§8.5). The message type is declared in the module, in Ernest, for the module and for the foreign process behind it (§8.4), and no other module can make a message of it. In a process spawned on a peer, a system module's binding is the peer's: `Io.println` there writes to the peer's standard output (§8.7).

What standard output and standard error, standard input and the terminal do, the keys, a paste and the interrupt among it, is §12.1's. The clock, the file system, TCP, and the host's programs answer their modules' requests as Appendix E.15, E.17, E.18, and E.23 say.

### 8.3 Peers

A *node* is one running runtime, and a *peer* is another node this one knows by name. A node is a program started with `--config-dir` (§11.2): its configuration directory holds its own key, by which nodes authenticate each other (§8.7), and `ernest.conf`, which lists its peers (§12.5, Appendix C). A program started without `--config-dir` is no node, has no peers and listens to nothing.

The module `Peer` (Appendix E.27) acts on a peer by its listed name: `Peer.spawn(name, f, ms)` and `Peer.spawnMonitored(name, f, wrap, ms)` start a process there as `spawn(f)` and `spawnMonitored(f, wrap)` start one on the running node (§6.2), `Peer.offer` and `Peer.find` offer a service to the node's peers, and find one (§8.7), and `Peer.peers` answers the names of the peers the node lists, in the configuration's order. Nodes of different builds connect on one floor (§8.7).

### 8.4 Foreign code

The system processes are foreign processes: their message types are declared in Ernest, their implementations live outside the language, and the runtime starts them (§8.2). Other foreign code enters through `foreign fn` and `foreign type`, §4.7. Both boundaries carry the same promise: the foreign side delivers the declared types, and a breach faults the receiving Ernest process: a bad return value or reply when the call returns, a bad message on delivery. A bad message's fault takes the message's place in the receiver's mailbox, with two exceptions (**Addresses and answers**), and the receiver faults at the wait that reaches it, in a `receive`, in `Clock.sleep`, for a call's answer or for a load's (Appendix E.28), as at a fault of its own, which `restarting` restarts (§6.9).

Foreign code but the runtime's own that keeps its declaration meets every rule of this report. One that breaks it is caught only where this section has a check meet the value (**What is checked**, **Type variables**): what no check can know is the foreign side's promise (§4.7).

**What is checked.** The standard library and the system processes are the runtime's own, and what passes between them and a program is not checked: the return of one of the library's foreign functions, a message from a system process, an address or a `Reply` given to either, and the answer to a call the library makes. A message from a peer is not checked on arrival; a value of another type a faulty peer sends is met where the receiving process matches on it.

Everything else is checked where it crosses. A foreign function's return is checked against its declared type when the function returns, and a reply foreign code gives when `Address.call` or `Address.callForever` returns it, each in the calling process and to the value's whole depth; a function value in it is checked when it is called, its result against its declared result type. A message foreign code sends to a process by its host identity, which a foreign function's implementation has as its caller, crosses nothing and is not checked: that it is of the mailbox's type is the foreign side's promise (§4.7).

A foreign function's return declared `Unit` that is the atom `ok` is `Unit`: the check takes it, and a foreign function of the standard library's, which is not checked, answers `Unit` itself. A function value's result declared `Unit` takes `ok` at its top as a return does. Nothing else takes `ok`: a message, a reply, an argument, and a `Unit` within another value are `'Unit'` alone.

**Addresses and answers.** An address that foreign code gives, in a return, a reply, a message, or an argument it calls an Ernest function with, is *foreign* unless it names a process of the program. An address of the program's that foreign code gives back is the program's own at the type it crossed at, and foreign at any other. What is sent to it at another type is checked as a message foreign code sends. A type is the type an address crossed at where the two have one hash (§8.7) once every type variable in each is written as the same variable.

A process of the program's whose address foreign code was never given, one it names by its own `self()` in a `foreign fn` or by a `Process` it was given, is a bad value where foreign code gives it as an address, except as an `Address(Never)`, through which no message passes.

A message sent to a foreign address, an answer given to a `Reply` foreign code gave, a foreign function's argument, and what a function that crossed returns to foreign code cross into foreign code: a message foreign code sends to an address in one is checked on delivery. That check lasts until the process the address names ends, and there is one for each distinct address that has crossed, at each type it crossed at. Foreign code is given a different address for each check, and the type an address crossed at is its check's. An address made by `adapted` is distinct by the address it adapts, by its function and by the values its function captured. A foreign address goes back as foreign code gave it, and gains no check of its own. No answer is checked but the reply foreign code gives a call (**What is checked**).

A message foreign code sends to an adapted address is checked against the type the address crossed at before its function is applied. Where the address crossed on the node that made it, the function is applied as on arrival (§6.5), in the process that checks (§10), which takes the place of the process kept for the address; a function that never finishes holds what foreign code sends to the address and nothing else. Where it crossed on another node, the checked message goes on as a `send` from that node does.

Foreign code sends as the process it runs in, the calling process or a foreign process. A message that goes through a check takes one step more, in the check's process (§10), on the node where its address crossed. It need not be in its receiver's mailbox when the foreign function that sent it has returned. Messages one process sends through one check are received in sending order, and a message it sends the same receiver after one of them another way can pass it.

A bad message's fault goes straight to the receiver. It can pass a message foreign code sent to the same address before it where the checked messages take the one step more of §6.5 on their way. A receiver that is a foreign process the runtime did not start takes the fault as such a target takes a fault in `f` (§6.5).

**Functions.** A function that crosses into foreign code, a foreign function's argument or one inside it, in a message, in an answer or in what a function that crossed returns to foreign code, has each argument foreign code calls it with checked against its parameter's type, and a mismatch faults the calling process with `Fault("an argument of f from foreign code does not match T")`, `f` the function's qualified name, or, for a lambda or a local `fn`, that of the top-level declaration it is written in (§6.9). `Foreign.term` gives its value as a foreign function's argument of the value's type crosses, an address in it behind its check and a function with its own (Appendix E.12).

**Type variables.** A type variable of a foreign function's result that no parameter's type names matches no value: `foreign fn cast(x : Foreign.Term) : a` faults whenever it returns, and a function that does not return, `Os.exit`, may be declared so. The check meets such a variable only at a value of it: an empty container holds none, and a value of a foreign type is not looked into, so a foreign function whose result is `List(a)` and empty, or `Table(k, v)` of a foreign type, returns.

A type variable that a parameter's type names matches any value wherever a check meets it. There the promise is the foreign side's alone. At such a variable it returns only a value the program gave it at the type the variable stands for at that call. It calls a function with, and sends to an address, only a value the program gave it at the type the variable stood for at the call that gave it the function or the address. `foreign fn weird(x : a) : a` answering `2` for `weird([1, 2])` breaks the promise and is not caught at the boundary.

An address or a function that crossed at a type that holds such a variable foreign code gives back only at the type the program held it at, each variable of the type it gives it back at read as the type it stands for at that call. `foreign fn last(witness : b) : Address(b)` answering an address that `foreign fn keep(to : Address(a)) : Unit` was given breaks the promise where `Address(b)` is then another type than the program held the address at, and is not caught at the boundary.

A value given to foreign code at such a variable, what a function that crossed returns to it among them, crosses as it is: an address in it has no check, and a function no check of its arguments. Foreign code gives such a value at such a variable alone, sends nothing to an address in it and calls no function in it.

A type variable in a call's answer type matches any value in a reply foreign code gives the call. There the promise is the foreign side's alone: it answers a `Reply` only with a value of the type the `Reply` crossed at.

**What the checks do.** The checks confine nothing: what foreign code does within the runtime, beyond what crosses, is not checked.

How each value crosses, the host's term for it and the term a process ends with, is §12.2's, fixed and documented (§10). A `foreign fn` implementation is named `module:function/arity`, the arity its parameter count. The function is named by its name, or an operator by the operator itself: `erlang:+/2`. A name not of that form, or whose arity is not the parameter count, is a compile-time error. A module or function the host lacks when the call is made faults the call with the cause §12.3 gives.

### 8.5 Initialization

Before `main` runs, the runtime evaluates in the entry process, in dependency order, every top-level `let` of the standard library but a constant (§4.6), and then of the entry point's module and of every module it depends on, directly or through others. The standard library is initialized whole, whether the program depends on each of its modules or not; another module the program does not depend on is not initialized. On a bare node (§8.7) the standard library's bindings are evaluated and no other.

A binding depends on every top-level `let` its initializer names, and on what every function it names depends on, called or not; a lambda's body is part of its initializer. A member is named where an operator resolves to it (§4.8), and where it is supplied: by a requirement (§4.9), a fill (§5.6), or a derived `compare` (§3.5). A binding is evaluated after those it depends on, and otherwise in the order its module declares it. A module's bindings are evaluated after those of every module it depends on. `let handlers = [f]` is a cycle when `f` names `handlers`, and so is `let a = fn() = a()`. The order of modules that do not depend on one another is unspecified. A cycle is a compile-time error. Only `let` requires evaluation.

An initializer runs as a body of mailbox type `Never` (§4.6), whatever the entry process's mailbox type: it receives nothing, and `self()` in it is an `Address(Never)`. A service it spawns runs from then on. The initializers of two modules that do not depend on one another print in no promised order, and within a module they print in the order the initializers run, as above.

An initializer that faults (§7.4) ends the program with that fault before `main` runs. Its fault is reported under the binding, its qualified name and the line it is declared on, as a spawn site is (§6.9): `Init.bad:3 faulted: division by zero`. Which of two independent faulting initializers is reported is unspecified. An initializer that does not terminate prevents the remaining initializers and `main` from running. A node (§8.3) runs its initializers so (§8.7).

### 8.6 Program termination

The program ends when the entry process dies, whatever the reason (§6.9), a fault being reported on the runtime's exit indicator, when any of its processes calls `Os.exit`, which gives the status the runtime exits with (Appendix E.23), when its standard output or standard error can no longer be written or its keys can no longer be read (§12.1), or, on a node, when its carrier cannot start (§12.5). A bare node ends as a program does, but never by its entry process's return (§8.1).

Before it ends by any of these, or by termination, the runtime tells the processes that subscribed with `Os.subscribeTermination` (Appendix E.23): each is sent `wrap(reply)` in its own mailbox type, delivered as a monitor's `Down` is (§6.9), and the end waits until every reply is answered or its subscriber has ended or restarted; nothing of the runtime's own times the wait. The caller of an `Os.exit` that began the end is neither told nor waited for: its subscription ends at the call. A subscriber whose delivery foreign code kills before it arrives is waited for no longer. What the runtime says of the wait is §11.2's.

Every process runs while the end waits, and a peer finds, calls and sends to the node as before (§8.7). A subscription made while the end waits is told at once. The end goes on without a subscriber that faults, whether it ends or restarts (§6.9), one the end cannot tell for want of room among them (§7.4). A process that waits with nothing in flight while the end waits is no deadlock. While the end waits, what began it stands: the entry process's end, a stream that can no longer be written and keys that can no longer be read change nothing.

An `Os.exit` once the end has begun ends the program at once, with its status. The host's interrupt, and a termination once the end has begun, whoever began it, end the program at once, with the status of what began the end: an `Os.exit`'s, the entry process's where its return or its fault began it, and the signal's where a termination did. Under `ern test` and in the shell the subscribers are told as under `ern run`. Live local processes then die with the reason `ProgramEnd`, and the runtime flushes the system processes' pending output before it stops. The flush lasts until the streams have taken what is pending. A termination during it ends the program without it (§12.4).

While the end waits, a fault is the process's own, reported as any fault is (§7.3). Once the wait is over, and from the entry process's death where no subscriber waits, a process that faults before it is ended, as an `acceptForever` whose listener its owner's death killed, dies with the reason `ProgramEnd` too, and its fault is not reported (§11.2). Where a stream can then no longer be written, that ends the program (§12.1), in place of what ended it.

The host's termination, a signal from outside, ends the program the same way, on a node as elsewhere. A hangup is a termination where the program is no node, and a reload on a node (§8.7). What a signal in the host's first fraction of a second does, and what output may be lost, is §12.4's.

What a node's end is to its peers is §8.7's. A process this program spawned on a peer runs on there.

When no forward progress is possible, the entry process faults with `Fault("deadlock")` and the program ends as above; while an evaluator of a load waits (Appendix E.28), the evaluator faults in its place, the one started last where several wait, and the load is refused; under `ern test`, the process of the test that runs faults in its place (§11.2). The fault's report lists the waiting processes beneath the trace (§12.4). The fault comes at most 100 milliseconds after the moment no progress is possible, or at most a second after it where something could still deliver when the runtime last looked, each beside the time the runtime takes to find it.

No progress is possible when every live process waits in `receive` without `after`, in `Address.callForever`, or in `Process.run`, `Test.faults` or `Code.load`, which wait as it does (Appendix E.0 shape rule 8), no message is in flight, no monitor waits on a process the runtime did not start, and no system process, listener or socket (E.18) holds a timer, a subscription, a pending I/O, or a computation whose completion would deliver a message; a program that `Os.start` or `Os.startTerminal` started counts as such a computation until a read has answered its exit or it has been killed, and a subscription to the program's end as such a subscription (Appendix E.23). The runtime counts a standard library operation as such a computation where the module that implements it says the operation waits.

A process inside foreign code (§8.4) is not waiting; the runtime reads that from the process, and from a crossing back into Ernest code (§8.4), and no foreign call declares it. A function the standard library is given runs as Ernest code, not as foreign code. A node (§8.3) detects no deadlock, and neither does a program while a shell holds the terminal (§11.2). A foreign process the runtime did not start counts as one that may deliver a message only while a monitor of it stands; a call that waits on it (§6.6) is such a monitor. A delivery that foreign code arranges for once its call has returned, by a timer of the host's or by a host process it started that no monitor watches, is not counted. A program whose waits are on such a delivery alone is read as deadlocked.

### 8.7 Nodes

A node (§8.3) is identified by its key, which `ern config` makes with a certificate the node signs itself and `ernest.conf`, printing the public key that another node's configuration lists (§11.3). A configuration directory is made for one machine. Two nodes started from copies of one are one node to their peers, and each one's dial ends the other's connection, which the peer says on its standard error each time.

**Its configuration.** What `ernest.conf` holds is §12.5's (Appendix C); a node refuses to start on a file that breaks a rule of it, saying which file and which rule.

`services` lists, under a service's name, the peers that may offer it, by their names, in the order a find asks them; a service not listed is found nowhere.

**Its start and its end.** Each start of a node has a number of its own, which the host draws and puts in every address (**Addresses**).

A *bare node* is `ern run --config-dir dir` with no `.erc` (§11.2): it holds no definition of a program's, its entry process is as §8.1 says and its initialization as §8.5 says, it listens and takes what its peers spawn and compute on it, which bring their code (**The exchange**), it offers what the processes spawned on it offer, and it ends as §8.6 says; one whose `ernest.conf` has no `listen` is refused at its start, but for the shell's (§11.2).

A node reads every module of its load path at its start, those its program does not use among them, and is refused where one of them uses a module the load path lacks, with §11.2's text. Where its program does not use the module the load path lacks, the text ends with the node's rule: `no module Util, which Old uses, on the load path; a node reads every module of its load path`. It listens and dials only once its initializers have their values (§8.5): a find, a spawn, a compute or a utilization in an initializer answers `Unreachable`.

A node that ends is no loss to the peers connected when it begins to stop. Its processes die with `ProgramEnd` and its output is flushed (§8.6), and from then until its connections have closed the node *stops*, in order (§12.6): it tells each of those peers that it ends, after what is placed for that peer (**Messages**), a `Down` among it, and waits for the peer's answer, so a peer that has fallen silent holds the node's end until it is lost (**A loss**). A peer that connects while the node stops is told nothing, and the close is a loss to it (**A loss**).

A node that stops tells no peer how busy it is (Appendix E.27). A find, a spawn, a compute or a utilization that reaches the node while it stops answers `Unreachable`. A peer's monitor on a process that died with the node's program gives `ProgramEnd`, or `Unreachable` where its `Down` was dropped (**Messages**), a call waiting on one of them ends as §6.6 says, and a monitor made while the node stops gives `Unknown`, as for any process that has ended; one made once the node has stopped gives `Unreachable`.

**A reload.** `ern reload --config-dir dir` makes the node read its configuration directory again (§12.5). A peer added is reached by the next operation towards it or when it dials in; a peer removed, or one whose key changed, is lost, both nodes running the loss, and the addresses a program holds of its processes are those of a node not listed; a peer whose address or name changed keeps its connection. The node's own key, in `private-key.pem`, and its `listen` cannot change while it runs.

**Connections.** Two nodes have at most one connection, opened by the first operation that needs it, and only where each lists the other's public key (§12.5); connections are not transitive. Two nodes connect only where they stand on one *floor*, one major and minor release of `ern` on one major release of OTP, which the handshake proves before anything passes (§12.5). A patch release changes nothing a floor rests on or agrees by (§12.5), and a build of `ern` that is no release stands on a floor of its own.

Nodes of different builds connect, and what they share they share by hash: a service names its type by hash and a spawn its function (below). What the hashes leave out, the runtime's functions, the standard library and every foreign declaration over a module of OTP's or of `ern`'s, agrees by the floor. A foreign declaration over a module of the program's own is in the hashes by its name and type alone (Appendix H), and what that module does on a node is the node's. A find, a spawn, a compute or a utilization whose connection the peer refused fails with `Unreachable`, the refusing side saying why on its standard error.

**Definitions and their hashes.** Every definition, a function, a type or a top-level binding, has a *hash*, the SHA-256 of its canonical form, which Appendix H states and the `.erc` holds (§11.1). A top-level function's qualified name is in its hash, and its positions are not (Appendix H). A type's hash covers its qualified name, its parameters by position, the `compare` its module declares or derives for it, which gives its order (§3.10), and its constructors in order with their fields' names and types.

A mutually recursive group is hashed as one, in source order, each member's hash made of the group's hash and its position in it; a lambda's or a local function's identity is its enclosing definition's hash and its position in it. A definition's *identity* is its hash, and a binding's is its qualified name with its definition's hash. A type written whole, `Counter.Msg` or `Optional(Counter.Msg)`, has a hash too, that of its canonical form, in which a type a program declares, but a foreign type, is its hash and any other type its name (Appendix H).

A definition's *reach* is the definition with everything it references, transitively. A node holds its definitions by hash, in the code table the runtime keeps (§10), read from its build directory at its start (§11.1), and the shell's definitions with them, read from `ern`'s own build (§11.2). A lambda or a local function that a spawn on a peer starts, or a compute runs, is held by its identity too, as a function that takes the values it captured (§11.1), and with each function the bindings and the foreign declarations its reach names. Two nodes that hold one hash hold one function or one type; a binding is its name with the hash.

**What passes.** A message is carried by the host as on one node, straight into the mailbox. What else crosses is the runtime's own frames, seventeen, fixed and documented (§10), or the host's, and §12.6 lists both.

**A loss.** A connection is lost when it is closed: when the network breaks it, when the host closes it once the detector has found it silent (§12.6), or when a frame is faulty.

Each node is told by its own host and runs the loss for itself: it gives a `Down` with the reason `Unreachable` and an empty `site` for each monitor held on the peer's processes, ends each call waiting on one of them and each wait on the peer that began before the node ran the loss, a spawn's, a find's, a compute's, a utilization's, and a restart's wait for the peer's answer (**A restart**), drops what waited to be sent, the calls it holds for the peer and its utilization; no other process ends, but one waiting in `Address.callForever` on one of them, which faults (§6.6). A node whose peer dials it anew while it believes the old connection alive runs the loss of the old one first.

A connection is opened again when an operation needs it, never in the background, and with no delay between one attempt and the next. A dial that is refused fails at once; one that nothing answers is given up after 7 seconds, and what waited behind it is then dropped. A node that cannot be dialed is reached only while it holds a connection open: after a loss, what the other node sends vanishes and its monitors say `Unreachable` until the first node next acts towards it.

**Addresses.** An address names its process for as long as the process lives, on whichever node, and a loss does not end it: when the two nodes connect again, the same address reaches the same process. An address of an earlier start of its node is dead: what is sent to it is dropped, a call through it ends at once, and a monitor on its process gives `Unknown`. An adapted address made by an earlier start of its node is dead too: what is sent to it is dropped, and its function is not applied. An address is a value like any other, and is as good on a third node it is sent to as on the node that sent it; what an adapted address keeps alive is §6.5's.

A monitor does not outlive a loss: the loss gave its `Down`. A monitor made while the process's node is out of reach or not listed gives its `Down` with `Unreachable` once the dial has failed. A `send` or a `kill` to a process whose node is out of reach or not listed vanishes (§6.2).

**A restart.** A restart (§6.9) is told by the restarting process's node to each other node with a process that monitors the restarting one when the restart reads them, after it has ended its calls (§6.9): a watcher's node, whose runtime holds the watcher's monitor, and a caller's whose call's end has not reached it (§6.6). Each node told delivers `Restarted` through the wraps of the service monitors it holds and answers once every delivery has ended, at once where it holds none; how the asking and the answer cross is §12.6's, and nothing of the wait reaches the new run. The restart waits for each answer as it waits for a wrap on its own node; a loss, or the node's end (**Its start and its end**), ends the wait.

A loss ends the wait on both sides: the restarting process goes on, and the node that lost the connection ends its deliveries of `Restarted` for the peer's processes not yet placed, as it ends the monitors they deliver for, so no `Down` follows the loss's (**A loss**).

**Messages.** `send` hands the message to the host and returns (§6.2). Where no connection is open the host opens one, and the message waits behind the dial: it is sent where the connection opens, and dropped where it does not.

What the connection has not yet taken waits in the host's buffer for that peer, or waits to be placed there. A `send` places its message in the buffer while less than 1 MB waits there, a large message in parts, and once 1 MB waits there the `send` waits, with whatever of its message is not yet placed, until the connection has taken enough from the buffer. What the connection has taken counts no longer, though the peer has not received it, so a `send` to a peer that stands still waits only once the connection takes no more. A loss ends the wait, as it drops what waited (**A loss**). A process that waits so serves nothing from its mailbox meanwhile.

A call, a find, a spawn, a compute, a utilization and an `answer` send as a `send` does. What a call, a find, a spawn, a compute and a utilization send the peer as their wait for it begins and as it ends is sent the same way too (§6.6, Appendix E.27). Of what the runtime itself sends a peer, a monitor's and a demonitor's signal, the note for a call or a compute whose caller was killed or has ended, and the exchange's frames (**The exchange**) are placed without waiting, and wait in the host's buffer for that peer with no bound until the connection takes them or is lost.

A process that dies while what it sends waits to be placed has sent it. Whatever is not yet placed is placed as the wait would have placed it, until a loss or the node's end (below). The `Down`s that the death gives watchers on other nodes are sent only once it is placed whole or a loss has dropped it.

A `Down` that a death gives a watcher on another node is placed in the buffer for that node. Where 1 MB waits there it may wait to be placed, until the connection has taken enough or the node is lost, and the `Down`s that the same death gives watchers on other nodes may wait behind it. A `Down` to a watcher on the dead process's own node waits on no peer. A call that ends by its callee's death (§6.6) ends when a `Down` to its caller would be sent.

The word that a node ends (**Its start and its end**) is sent to a peer as a `send` sends, and what is placed for the peer before it crosses before it. The node's end waits for nothing else. What a `send` or a death has not placed for the peer by then may be dropped. A watcher on another node whose `Down` is dropped so is told `Unreachable`, and a call that waits on the dead process ends as at a loss (§6.6).

What one process sends another arrives in the order §6.4 gives. Between nodes a message is never dropped alone: where one is dropped, the connection is lost or closed by the node's end, with everything that still waited to be sent. A message arrives once or not at all, and the runtime sends nothing a second time.

**Calls.** A loss ends a call as §6.6 says. A restart in place ends every call whose request came before it, but for a request through an adapted address made on a third node.

**A spawn.** `Peer.spawn(name, f, ms)` asks the peer named `name` to start a process and run `f()` in it, the values `f` captured (§3.11) crossing as they cross in a message, a reply among them (Appendix E.27), and for `restarting(limit, g)` the limit and `g`; the peer records the spawn's site (§6.9) for the process as it records a local spawn's, and answers its address; what the spawn answers, and within what time, is Appendix E.27's.

A function spawned on a peer runs there once the peer's code table holds its identity and every identity its reach names, which cross to a peer that lacks them (**The exchange**), and only where:

- every top-level binding its reach names, found by its identity, has its value there, in the unit its code reads it from (§11.2), a constant (§4.6) having it wherever its form is, made from the form and evaluated nowhere (§8.5);
- the module every foreign declaration its reach names calls is on the peer with the function in it.

Otherwise the peer starts nothing, the peer says on its standard error what it lacked, the binding or the module, or the function in it, and the spawn fails with `NotLoaded(text)`, `text` the words the peer writes after `was not loaded:`.

Nothing is initialized because a peer asked. A function spawns whatever its module holds beside it: a binding outside its reach keeps it from no peer.

In the spawned function a top-level `let` and a declaration's name are the peer's, a value it captured is the spawner's, and the system processes are the peer's (§8.2).

**The exchange.** What the peer lacks of the function's reach crosses to it as the definitions' canonical forms (Appendix H), never compiled code, dependencies first, within the spawn's time, and the peer verifies each against its hash, compiles the reach and loads it whole before anything of it runs (§12.7); a reach the peer cannot compile or load fails the spawn with `Other(text)`, `text` the peer's reason. A definition that arrived stays for the node's life (§11.2), and a spawn that names it ships nothing. A foreign function spawned or computed by its name (§3.11), which has no hash, crosses as its declaration where the peer lacks it, and a received definition calls the host's function the sender's declaration names, the module's code being the node's (**Connections**).

A node trusts each peer it lists. A peer runs what it is sent as its own code: a peer that may spawn on a node may run anything on it. Code crosses with a spawn and a compute and nowhere else: a find ships nothing, a message ships nothing, and the shell's load is the session's (§11.2).

**A compute.** `Peer.compute(name, f, ms)` asks the peer named `name` to run `f()` in a process it starts as it starts a spawned one, recording the compute's site for it, the declaration and the line where the `Peer.compute` or `Peer.computeAnywhere` is written (§6.9), and to answer `f`'s value to the caller as a call is answered; the process ends as its function returns (§6.9); what the compute answers, and within what time, is Appendix E.27's. `Peer.computeAnywhere(f, ms)` names no peer: the node draws one by the utilizations it holds (**A utilization**) and sends it the same frame.

A fault in `f` is the caller's: the fault crosses to the caller, its cause and its trace (Appendix E.21), and the caller faults with that cause and with that trace followed by the caller's frame where the compute is written, which its node reports as it reports any fault of the caller, the peer named after the cause (§11.2); the process dies of the fault as any process does (§6.9), and the peer writes nothing of it and tells no subscriber of `Process.subscribeFaults`. Where `f` is `restarting` over a function (§6.9), a restart does not end the compute: a fault it restarts is the process's own, reported on the peer, and the caller waits for the run that answers.

The value crosses back at the type the compiler checked at the compute, `f`'s result type as §3.11 reads it, an instance of the one the peer holds in `f`'s form (Appendix H).

**A utilization.** `Peer.utilization(name, ms)` asks the peer named `name` how busy it is, by the run queue's measure (§12.8) or what `Peer.setUtilization` set. What it answers, how a node tells its peers how busy it is and holds what they told it, and how `Peer.computeAnywhere` draws a peer by that are Appendix E.27's.

**A service and its name.** On one node a service is a top-level binding that holds an address (§6.5). A service that peers are to reach is offered as a `Peer.Service(m)`, a value that holds the service's name and the hash of its message type `m` (above), whichever module writes it; the name is what a line writes of a service, and the hash is what a find compares. `Peer.service("counter")` makes one at the type its definition fixes (§4.8), or the shell's input (§11.2), and is refused where that type is not fully known there, or is bound (§3.11). A `Peer.Service(m)` starts nothing; what `Peer.offer` and `Peer.find` answer is Appendix E.27's.

## 9. Prelude

The prelude is what §9 lists. A function of §9.4 or §9.5 enters it where its meaning is the runtime's own act, which no function over the prelude and no declaration over a host's documented function could give, and an operation of §9.6 where an operator, a literal or a requirement resolves to it. A rule elsewhere that names a library function or type names it as the library's, by its namespace, as §3.11 and §8.7 name `Peer.spawn` and `Peer.Service(m)` (Appendix E.27). A prelude function has the shape Appendix E.0 gives a library function of its kind, and differs from one by nothing but its place. Everything else is the standard library, Appendix E: the container, string, and numeric operations and the output helpers. An operation of §9.6 in a type's namespace, `Int.compare`, is provided by that type's standard library module, and `Io.show` of §9.4 by `io.ern` (Appendix E.1).

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

type Optional(a) = None | Some(a) // compare where a has one, None before Some, §3.10

type Either(e, a) = Left(e) | Right(a) // compare where e and a have one, Left before Right, §3.10

type Ordering = Less | Equal | Greater

type Down = Down(process : Process, reason : Reason, site : String)

type Reason = Returned | Killed | ProgramEnd | Fault(String) | Unknown | Unreachable | Restarted // Restarted to a service monitor alone, §6.9

type RestartLimit = RestartLimit(restarts : Int, within : Int) | Unlimited // within in milliseconds, §6.9

type Path = Path(String) // in the runtime's syntax
```

`Unreachable` is given by a monitor on a process of another node alone (§6.9, §8.7), and `Restarted` by a service monitor alone (§6.9); a `match` on a `Reason` covers each as any constructor (§5.9).

### 9.4 Built-in functions (§6, Appendix E.1)

```
self           : () -> Address(m) receiving m
send           : (Address(a), a) -> Unit
spawn          : (() -> Unit receiving n) -> Address(n)
spawnMonitored : (() -> Unit receiving n, (Down) -> m) -> Address(n) receiving m
```

`io.ern` provides `Io.show` (Appendix E.1):

```
Io.show        : (a) -> String needs a.show // the value as Ernest writes it, at the use's type
```

### 9.5 Process functions

```
adapted             : (Address(b), (a) -> b) -> Address(a)
Address.call        : (Address(m), (Reply(a)) -> m, Int) -> Optional(a)
Address.callForever : (Address(m), (Reply(a)) -> m) -> a
answer              : (Reply(a), a) -> Unit
restarting          : (RestartLimit, () -> Unit receiving n) -> () -> Unit receiving n
monitor             : (Process, (Down) -> m) -> Unit receiving m
monitorService      : (Process, (Down) -> m) -> Unit receiving m
demonitor           : (Process) -> Unit
kill                : (Process) -> Unit
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
Bool.compare : (Bool, Bool) -> Ordering // §3.10: false before true
List.compare : (List(a), List(a)) -> Ordering needs a.compare
Optional.compare : (Optional(a), Optional(a)) -> Ordering needs a.compare
Either.compare : (Either(e, a), Either(e, a)) -> Ordering needs e.compare, a.compare
fault : (String) -> a // §7.4: faults with the cause given
compare : (a, a) -> Ordering needs a.compare // §3.10: the operand type's compare, as < is
```

On `Int`, `Float`, `String`, and `Bytes` an operator is the runtime's own operation, and so is `<>` on `List`; `Path.<>` is Ernest in its module. The operator is the primitive, and the function of its name in the type's module is written with it: the body of `fn Int.+(left : Int, right : Int) : Int = left + right` applies the runtime's `+`. On `Int`, `Float`, `String`, `Char`, and `Bool`, `<`, `<=`, `>`, and `>=` are likewise the runtime's own ordering, and `compare` in the type's module is written with them. On `Int` and `Float`, prefix `-` is the runtime's own negation, and `negate` in the type's module is written with it. `compare` is the operators' resolution itself, `T.compare` for the operand type, and no module provides it.

Each `T.f` this section lists is a member (§4.5), which `T`'s module provides: Appendix E.2 for `List`, E.5 for `String`, E.6 for `Char`, E.7 for `Bool`, E.8 for `Int`, E.9 for `Float`, E.10 for `Optional`, E.11 for `Either`, E.14 for `Path` and E.20 for `Bytes`.

### 9.7 System references

The prelude binds no system reference. Each is a private binding of its system module, §8.2.

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
Requirement = "needs" Need { "," Need } .
Need        = typevar "." ( userop | "compare" | "negate" | "show" ) .
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
FnResult    = FnType | ( TypeAtom | ParenType ) [ "receiving" Type ] .
ParenType   = "(" Type ")" .

Expr        = Lambda | IfExpr | BinExpr .
Lambda      = "fn" "(" [ Param { "," Param } ] ")" [ Return ] "=" Expr .
IfExpr      = "if" Expr "then" Expr "else" Expr .
MatchExpr   = "match" Expr "{" Clause { "|" Clause } "}" .
Clause      = Pattern { "or" Pattern } [ "when" Expr ] "->" Expr .
ReceiveExpr    = "receive" "{" Clause { "|" Clause } [ "|" AfterClause ] "}" .
AfterClause    = "after" Expr "->" Expr .
BinExpr     = Unary { binop Unary } .
Unary       = [ "-" | "!" ] Primary { Call | Select } .
Call        = "(" [ Expr { "," Expr } ] ")" .
Select      = "." ident .
Primary     = literal | QName | Tuple | ListLit
            | BitExpr | Block | MatchExpr | ReceiveExpr | "(" Expr ")" .
QName       = { typename "." } ( ident | conname [ "(" ( Expr | Fields ) ")" ] ) .
Fields      = ".." Expr [ "," UpdateSet { "," UpdateSet } ] | FieldSet { "," FieldSet } .
UpdateSet   = ident { "." ident } "=" Expr | "=" ident .
FieldSet    = ident "=" Expr | "=" ident .
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
FieldPats   = [ FieldPat { "," FieldPat } ] .
FieldPat    = ident "=" Pattern | "=" ident .
```

`binop`, `userop`, and `literal` are defined in §2, along with the other lexical categories; `binop` precedence follows the table there. Every nonterminal is decided by its first token, or by the later token this paragraph names: `let` begins a binding, `fn` a declaration or lambda (an identifier or type name after `fn` makes it a declaration, `(` a lambda), `{` a block, `[` a list, `#(` a tuple, `(` a call or parenthesized expression, `<<` a bitstring.

After a primary, `.` and an `ident` select a field (§3.5): a lowercase first segment is a value, so `s.upper` selects, while an uppercase one begins a `QName`, `Net.Http.parse`. An `ident`, `.` and `compare` or `negate`, `a.compare`, parse as a selection, which selects nothing where §3.5 says. The expression after `..` in `Fields` names a namespace where §5.6 says so, and the parser reads one form. In a qualified name, of a value in `QName`, of a type in `TypeAtom`, or of a constructor in `AtomPat`, after each uppercase token the next token decides: `.` continues the qualification, and otherwise the segment is final. In `QName` a final `ident` names a function or a value, and a `conname` a constructor.

A constructor's fields are positional or named by whether `=` or `:` follows the first identifier, or `=` stands before it. When a constructor name is immediately followed by a parenthesized constructor argument, one expression or fields, the parser consumes that argument in the constructor branch of `QName`; a single-positional construction has the semantics of calling the constructor's function value. Empty parentheses after a constructor name, or two expressions or more, are a call of its value (§5.6). `conname` and `typename` are one token class; which one a segment is follows from its position.

A parenthesized list of types is an `FnType` when `->` follows its `)`, and otherwise a `ParenType` (§3). In a `ListedType`, a type variable followed by `=` is marked (§3). A `receiving` after a function type belongs to that type (§3), and a function type that ends in a `receiving` takes no second: a function's mailbox type after a result that is a function type is written after that type in parentheses, `(A) -> ((B) -> C receiving M) receiving N`, in a `Return` as in a type, `: ((A) -> B receiving M) receiving N`.

In a `receive`, a `|` followed by `after` begins its `AfterClause`.

## Appendix B. Examples

The counter of §6.10, with a `main` that sends it `Inc` and `Get`. §6.10 shows `Upgrade` at work.

```ernest
type CounterMsg = Inc(Int) | Get(Reply(Int)) | Upgrade(next : (Int) -> Unit receiving CounterMsg)

export fn main() : Unit = {
    let counter = spawn(fn() = count(0));
    send(counter, Inc(5));
    send(counter, Inc(3));
    match Address.call(counter, Get, 1000) {
        Some(total) -> Io.println("count is " <> Int.toString(total))
      | None -> Io.println("counter is not answering")
    }
}

fn count(total : Int) : Unit receiving CounterMsg =
    receive {
        Inc(amount) ->
            count(total + amount)
      | Get(reply) -> {
            answer(reply, total);
            count(total)
        }
      | Upgrade(=next) ->
            next(total)
    }
```

Ping-pong. `main` starts `pong` under a monitor and `ping` beside it, and waits for `pong` to end. `ping` calls `pong` three times and then stops it.

```ernest
type PongMsg = Ping(round : Int, reply : Reply(Int)) | Stop

type MainMsg = PongDone(Down)

export fn main() : Unit receiving MainMsg = {
    let opponent = spawnMonitored(fn() = pong(), PongDone);
    let _ = spawn(fn() = ping(opponent, 3));
    receive {
        PongDone(_) -> Unit
    }
}

fn ping(opponent : Address(PongMsg), round : Int) : Unit =
    if round == 0 then
        send(opponent, Stop)
    else {
        Io.println("ping " <> Int.toString(round));
        match Address.call(opponent, fn(reply) = Ping(=round, =reply), 5000) {
            Some(_) ->
                ping(opponent, round - 1)
          | None -> {
                Io.println("pong is not answering");
                send(opponent, Stop)
            }
        }
    }

fn pong() : Unit receiving PongMsg =
    receive {
        Ping(=round, =reply) -> {
            Io.println("pong " <> Int.toString(round));
            answer(reply, round);
            pong()
        }
      | Stop ->
            Unit
    }
```

A message that carries a function. `submitter` only sends, so it receives nothing. A worker on another node cannot be given it: `Address(WorkerMsg)` is bound to its node (§3.11).

```ernest
type WorkerMsg = DoWork(work : (String) -> Bytes, input : String)

fn submitter(worker : Address(WorkerMsg)) : Unit = {
    send(worker, DoWork(work = String.toUtf8, input = "hello"));
    send(worker, DoWork(work = String.toUtf8, input = "world"))
}
```

## Appendix F. Glossary

Every technical term this report introduces, with a gloss and the section that defines it; the section is normative.

- **abstract type** — a sum type whose constructors are visible only in the module that declares it. §3.6, §4.4.
- **`adapted`** — `adapted(addr, f)` is the address `addr` seen through `f`. §6.5, §9.5.
- **adapted address** — an address `adapted` makes, whose function turns what is sent to it into the target's message. §6.5.
- **address** — `Address(m)`, a reference to a process that receives values of type `m`. §3.7, §6.5.
- **admission rule** — one of the four rules that decide whether a function enters the standard library. Appendix E.0.
- **`after`** — the last clause of a `receive`, taken when no message arrives within its time. §6.3.
- **application** — a directory of the host's code named `name` or `name-version`, holding `ebin`, which `--libs-dir` puts on the load path. §11.2.
- **arity** — the number of arguments a function takes; part of its type. §3.4.
- **`as`** — `p as x`, a pattern that binds `x` to the whole value `p` matches. §5.10.
- **attached shell** — a shell whose session runs on a listed peer, the shell's own node being its terminal and its files. §11.2.
- **bare node** — a node started with no `.erc`, which holds no definition of a program's and runs what its peers spawn and compute on it. §8.7, §11.2.
- **binding** — a `let` in a block, `let p = e` or `let p <- e`. §4.6, §5.5.
- **bitstring** — a bit-level value or pattern `<<...>>` that produces or matches a `Bytes` value. §5.11.
- **block** — `{ s1; s2; e }`, statements separated by `;`, whose value is its last. §5.4.
- **bound type** — a type whose values are never used on another node: one that holds a function type, a foreign type, a resource, a socket's, a listener's or a program's message type, or an address or a reply of a bound type. §3.11.
- **build root** — the directory a build writes its `.erc` files under, `--build-root`, mirroring the source root. §11.1.
- **`Bytes`** — the type of an octet sequence. §3.1.
- **callee** — the function a call applies (§5.1); of a request-reply call (§6.6), the process the request is sent to. §5.1, §6.6, §11.2, §12.4, Appendix E.21.
- **canonical form** — the term a definition's hash is taken of: its typed tree after checking, its locals numbered, its names resolved, each reference the identity of what it names. §11.1, Appendix H.
- **carrier** — the host's distribution, over which nodes connect, as a node runs it. §12.5, §10.
- **cause** — the text a fault carries, `Fault(cause)`, which `Down` and a fault report give; §7.4 names the sections that state one. §7.3, §7.4.
- **chain** — the process at the head of a process's spawns and every process that one started, directly or through one it started. §6.5, Appendix E.24.
- **child** — a process of a `Supervisor`'s group, which its supervisor restarts. Appendix E.22.
- **clause** — one pattern-branch of a `match` or `receive`. §5.9, §6.3.
- **code frame** — the exchange's frame that carries one definition's canonical form. §12.7.
- **code replacement** — a running process going on in a new function it received in a message. §6.10.
- **code table** — a node's table from each definition's hash to the unit and function that hold it. §10.
- **compare** — the member that defines a type's order, `fn T.compare`, and the prelude function that reaches the operand type's as `<` does, the one way an order is used as an `Ordering`. §3.10, §9.6.
- **compiled interface** — what a compiled module records of what it exports, their types and schemes, and the hash of each of its definitions, against which a module that uses it is checked. §3.9, §11.1.
- **compute** — `Peer.compute` or `Peer.computeAnywhere`: a function run in a process on a peer for its value. §6.7, §8.7, Appendix E.27.
- **concat operator** — `<>`, resolved per type. §4.8.
- **configuration directory** — the directory `--config-dir` names, which holds a node's `ernest.conf`, its key, its `ernest.pid` and its `startup` file. §12.5, §11.2, §11.3.
- **connection** — what two nodes send each other over, at most one between them, opened by the first operation that needs it (§8.7); also what a socket of TCP or TLS holds (Appendix E.18).
- **cons operator** — `::`, list-prepend, right-associative. §3.3, §5.10.
- **constant** — a top-level binding's initializer that is a literal, a negated number literal, a constructor of no fields, or a constructor, a tuple or a list of constants; the binding is not evaluated and always has its value. §4.6, §11.1.
- **constructor** — a case of a sum type; a value, a function, or a construction form. §3.5, §5.6.
- **container** — a type of the kind that holds elements and provides the container operations, a list, a map, a set. Appendix E.0.
- **cookie** — the digest of the protocol's version, the form's version, `ern`'s major and minor and OTP's major release, or of a development build's own code, by which the handshake proves the floor. §12.5.
- **deadlock** — no process can progress. §8.6.
- **demonitor** — `demonitor(p)`; ends every monitor the caller holds on the process `p`, whichever function asked for it; a `Down` already delivered stays. §6.9, §9.5.
- **derives** — `derives compare` at the end of a type declaration, which gives the type the member `compare` over its constructors and fields. §3.5.
- **detector** — the host's watch on a connection, which finds a silent peer by its ticks. §8.7, §12.6.
- **diagnostic** — an error the toolchain reports at a place in the source: its message, the source with the span underlined, its labels, and at most one help line. §11.5.
- **dial** — a node's opening of a connection to a peer, at the address its configuration lists. §8.7.
- **doc block** — consecutive `///` lines, read as CommonMark. §2.2.
- **doc comment** — `///`, not followed by a fourth `/`, to end of line; attached to the following declaration. §2.2.
- **effect polymorphism** — a mailbox type that is a type variable, an effect variable. §3.9.
- **effect position** — the type after `receiving` in a function type. §3.9.
- **effect variable** — a type variable that is a function type's mailbox type, bound at a call to a mailbox type or to none. §3.9.
- **entry point** — the function run in the entry process: the module's `export fn main`, or the function `--main` names. §8.1, §11.2.
- **entry process** — the process that runs the entry point. §8.1, §8.6.
- **equality constraint** — the restriction on a type variable compared with `==`, or on a foreign type's parameter written `k=`. §3.10, §4.7.
- **evaluator** — the process of the runtime's own in which a load evaluates a module's bindings, which ends with them unless it owns what a binding opened. §11.2, Appendix E.28.
- **exchange** — the frames by which a spawn or a compute carries to a peer the definitions of its function's reach that the peer lacks: the request for a reach, the reach, the lacks and the code frames. §8.7, §12.7.
- **family** — of an address, IPv4 or IPv6; a listener takes connections of its own address's, and a node runs over its listener's. §12.5, Appendix E.18.
- **fault** — the end of a process with the reason `Fault(cause)`, or its restart where it restarts (§6.9). §7.3, §7.4.
- **field selection** — `e.f`, the named field `f` of `e`, where every constructor of the type has it. §3.5.
- **fill** — `C(..N)`, a construction whose fields not given are the declarations of their names in the namespace `N`. §5.6.
- **find** — `Peer.find`: the peers listed under a service's name asked, in the order listed, for the address offered under it. §8.7, Appendix E.27.
- **floor** — one major and minor release of `ern` on one major release of OTP, or one development build of `ern`, on which nodes of different builds connect. §8.7, §12.5.
- **foreign address** — an address foreign code gave that names no process of the program, or that names one at another type than its address crossed at; what is sent to it crosses into foreign code. §8.4.
- **foreign code** — code outside the language, in the runtime's language: a foreign function's implementation or a foreign process's. §4.7, §8.4.
- **foreign function** — declared `foreign fn`; body is a string reference to a runtime implementation. §4.7.
- **foreign process** — a process whose implementation lies outside the language, the system processes among them; §8.4 says which of its messages are checked. §8.4.
- **foreign type** — declared `foreign type T`; values are made and used only by foreign functions. §3.8, §4.7.
- **form** — in Appendix E, an operation of the standard library that is called where it is named and is no value, as `Peer.spawn` is; elsewhere a construct of the language (§0), or the canonical form. Appendix E.
- **frame** — a message of the runtime's own between nodes, one of the seventeen §12.6 lists; and a line of a trace, a function of the host's stack (Appendix E.21). §12.6, Appendix E.21.
- **generalization** — quantifying free type variables in a `fn` definition, a top-level `let`, or a block `let` that binds a lambda. §3.9, §4.6.
- **grapheme** — an extended grapheme cluster, what a reader sees as one letter, which `String`'s sizes and indices count. Appendix E.5.
- **group** — the processes a `Supervisor` restarts together, its children. Appendix E.22.
- **guard** — a `when` expression on a `match` or `receive` clause. §5.9.
- **guard expression** — the form of a `receive` guard. §6.3.
- **handshake** — the opening of a connection between two nodes, in which each node proves its key and the floor before anything passes (§12.5); also TLS's own (Appendix E.18).
- **hangup** — the host's signal `SIGHUP`, a reload to a node and a termination to any other Ernest program. §8.6, §12.5, Appendix E.23.
- **hash** — the SHA-256 of a definition's canonical form, its identity on every node, or of a type's, which a service carries. §8.7, §11.1, Appendix H.
- **hide** — to be the one found where two share a namespace or a spelling: a module before a later root's, a module's declaration before the prelude's, a binding before a declaration's or the prelude's. §4.2, §11.1.
- **Hindley-Milner** — the type system Ernest uses; inference asks for an annotation only where §3.9 says. §3.9.
- **host** — the host runtime Ernest runs on, a rule of which is Ernest's only where the report states it as Ernest's own. §0.
- **identity** — what a reference to a definition names: a function's or a type's hash, a binding's qualified name with its definition's hash. §8.7.
- **inferred restriction** — the equality constraint or process-only, inferred from a body; where there is none, written on a foreign type's parameter or given by §4.7 and §9. §3.9.
- **interrupt** — the host's signal `SIGINT`, which ends the Ernest program at once; sent to a running program by `Os.signal`. §8.6, Appendix E.23.
- **irrefutable pattern** — a pattern that cannot fail. §5.10.
- **key** — a node's own key, the key pair by which it is identified. §8.3, §8.7, §11.3.
- **`kill`** — `kill(p)`, ends the process `p` with the reason `Killed`. §6.9, §9.5, Appendix E.21.
- **lambda** — an anonymous function, `fn(x) = e`. §5.3.
- **line mode** — the shell reading lines and editing none, when its input or output is not a terminal. §11.2.
- **literal** — a token that stands for an `Int`, `Float`, `Char`, `String`, or `Bool` value. §2.5.
- **live region** — the rows at the foot of the screen that the shell draws again: what programs have written, the input, and what `Tab` shows. §11.2.
- **load path** — the directories, in order, under which a program's modules are found by their namespaces and in which a `foreign fn`'s `.beam` is found. §11.1, §11.2, §11.9.
- **loss** — a connection closed by the network, by the host for its silence or at a faulty frame, and not by a node's end in order. §8.7.
- **mailbox** — the queue of values a process receives. §6.
- **mailbox type** — the `M` in `(A) -> B receiving M`; the type of the process's mailbox. §6.1.
- **manifest** — `package.conf`, the file that makes a directory a package: the least release of Ernest the package is written for, and an entry for each package its modules use, directly or through another package. §11.9.
- **`match`** — the pattern-matching expression form. §5.9.
- **measure** — one of the host's measures a node runs, `cpu`, `memory` or `disk`, named in `ernest.conf`. §12.5, Appendix C.
- **member** — an operator, `compare` or `negate` of a type, in the type's nested namespace, reached by its operator or `compare` alone. §4.2, §4.5, §4.9.
- **module** — a single Ernest source file (`.ern`); the unit of compilation and namespace. §4.1.
- **monitor** — `monitor(p, wrap)`; sends `wrap(d)` to the caller when the process `p` dies. §6.9, §9.5.
- **named field** — a field on a constructor identified by name, not position. §3.5.
- **named package** — a package the root package's manifest names, which stands under the root package's `lib`. §11.9.
- **namespace** — the dotted prefix of a name; equal to the module's path. §4.2.
- **`Never`** — the type with no values; as a mailbox type, a process that cannot receive. §3.7, §6.8.
- **node** — one running runtime, started with a configuration directory and identified by its key. §8.3, §8.7.
- **offer** — a service made findable by `Peer.offer`, for as long as its process lives. Appendix E.27.
- **operations record** — a record a program declares of the operations it uses on a type, filled from each representation's namespace and passed to code written once over them. §5.6.
- **operator resolution** — per-type dispatch of arithmetic and `<>` to `Type.<op>`. §4.8.
- **or-pattern** — patterns joined by `or` in one clause, which matches when any of them does. §5.9.
- **order** — a function `(T, T) -> Ordering` that keeps §3.10's laws, which a type's `compare` keeps, and `List.sort` and an ordered set or map require of it. §3.10, Appendix E.25.
- **owner** — of a resource, the process that opened it or was given it, or that made a table or started a process to end with it, with which the resource ends; of a file, the user the host records as owning it. §6.9, §11.2, §11.9, §12.5, Appendix D, E.18, E.21.
- **package** — a directory that holds a manifest, its Ernest under `src`. §11.9.
- **pattern** — decomposes a value and binds its parts. §5.10.
- **peer** — another node this node lists in its `ernest.conf`, by a name, a public key and a network address. §8.3, §8.7.
- **piece** — the bytes one read of a stream answers, whose ends are the host's and no write's. Appendix E.18, E.23.
- **pipe** — the `|>` operator, `x |> f` = `f(x)`. §5.7.
- **positional field** — a field on a constructor identified by position, not name. §3.5.
- **precedence** — the binding tightness of a binary operator. §2.6.
- **prelude** — the names §9 lists, which the language requires to exist. §9.
- **`Prelude`** — the prelude's own namespace, `Prelude.Some`, for a name a module has shadowed; it takes one prelude name and no namespace. §4.2.
- **primitive** — an operation beneath what Ernest writes, the language's or a standard library module's. §0, Appendix E.0.
- **process** — an execution of a function with a mailbox. §6.
- **`Process`** — the identity of a process, with equality; nothing can be sent to it. §6.5, Appendix E.21.
- **process a session started** — a process the session started on its node, directly or through a process it started there, until the session ends: the chains of its file's entry point, of an input and of a load. §11.2, §12.1.
- **process of the shell's own** — a session's own process on the shell's own node, an input's aside, from which `Os.exit` ends the shell. §11.2, Appendix E.23.
- **process-only** — an effect variable that a `receive` fixing no type for its message, or a `foreign fn`'s own `receiving`, keeps from being none, or a function whose effect variable is one. §3.9.
- **pseudo-terminal** — a terminal the runtime opens for a program `Os.startTerminal` starts, its standard input, standard output and standard error together. Appendix E.23.
- **pun** — `=f` for `f = f`: in a construction the field `f` given what `f` names in scope, in a pattern the field `f` binding a variable `f`. §5.6, §5.10.
- **qualified name** — a name with a dotted namespace prefix, `Net.Http.parse`, resolved from the writer's namespace outward and written in its shortest resolving form. §2.3, §4.2.
- **raw string** — a `String` literal between backquotes, its text taken as written. §2.5.
- **reach** — a definition with everything it references, transitively. §8.7.
- **`receive`** — a match over the mailbox. §6.3.
- **receiving** — the one mark on a function type, `(A) -> B receiving M`: the function's own process's mailbox, of type `M`, is involved. §6.1.
- **record update** — `C(..p, f = v)`, a construction whose unlisted fields are `p`'s; `f.g = v` reaches a field of a field through a *path*. §5.6.
- **redundant** — of a clause or an alternative: able to match no value those before it leave. §5.9.
- **remote computation** — work on a peer: a process spawned there, or a function run there for its value. §6.7.
- **`Reply(a)`** — a one-shot address for the answer to a request. §3.7, §6.6.
- **request-reply** — `Address.call` sends a request that carries a `Reply`, and the callee answers it with `answer`. §6.6.
- **requirement** — `needs a.compare` after a function's result type, naming members of its type variables that the body reaches through the operators and `compare`, and a call supplies without writing. §4.9.
- **reserved word** — a word the grammar keeps for itself. §2.4.
- **resource** — the address of a socket, a listener or a program the runtime started, or a `Clock.Alarm`; a library's is a foreign type. §3.11.
- **restart** — `restarting`'s run of its function again after a fault, or when a `Supervisor` asks, in the same process with its address, its mailbox emptied. §6.9.
- **restart limit** — `RestartLimit(restarts, within)`, how many faults a restarting function or a group takes within a time, or `Unlimited`. §6.9, Appendix E.22.
- **rigid** — of a type variable an annotation names, which means every type its inferred restrictions admit. §3.9.
- **root package** — the package whose manifest a job reads: the directory `--package-dir` names, or without that option the directory the job is started in, where the job is given no file or directory, or one under it. §11.9.
- **runner** — what `ern run`, `ern test` and `ern shell` start: it starts the system processes and calls the entry point. §11.2.
- **runtime** — the system that runs Ernest programs. §10.
- **scrutinee** — the value a `match` matches. §5.9.
- **segment** — a part of a qualified name between dots (§4.2), of a bitstring (§5.11), or of a path (Appendix E.14).
- **selector** — `.f` after a value, selecting its field `f`. §3.5.
- **`self`** — `self()`, the current process's own address. §6.2.
- **`send`** — `send(a, v)`, places `v` in the mailbox of `a`. §6.2.
- **sequence** — a container with order and position, a list, whose vocabulary adds `reverse`, `take` and the rest. Appendix E.0.
- **service** — a top-level binding that holds a process's address, §6.5; to the node's peers, a `Peer.Service(m)`, the service's name at its message type, under which its address is offered and found, §8.7, Appendix E.27.
- **service binding** — the top-level binding that a service is, which grants the permission its address is to the modules that see it. §6.5.
- **service monitor** — `monitorService(p, wrap)`; a monitor that also sends `wrap(d)` with the reason `Restarted` at each restart of `p`, and stands until `p` dies. §6.9, §9.5.
- **session** — a shell's run on a node: its declarations, their scope and its inputs' processes; a node has many at once, each with a number. §11.2.
- **session's own process** — a process the shell runs to serve a session, the session's, its reader's, its screen's, its local half's or an input's, which `Process.live` leaves out. §11.2, Appendix E.21.
- **shape rule** — one of the rules that give a function its shape, in the standard library and in every library. Appendix E.0.
- **shim** — a primitive written as a `foreign fn` over the host or as a request to a system process. Appendix E.0.
- **source root** — the directory under which a file's path gives its namespace. §4.2, §11.1.
- **span** — a stretch of source a diagnostic underlines, the erroneous one with `^` and one the message depends on with `-` and its label. §11.5.
- **`spawn`** — `spawn(f)`, starts a new process; `spawnMonitored(f, wrap)` starts one monitored from its start. §6.2.
- **spawn site** — the top-level declaration and the line a process was spawned at, `Counter.main:19`, which `Down` and a fault report give; a session's under its namespace, `$Session2.input 3:1`. §6.9, §11.2.
- **standard library** — the modules of Appendix E, which ship with the compiler and are on the load path by default; not the prelude, and not one of Appendix G's libraries. §9, Appendix E.
- **start number** — the number the host gives each start of a node, carried in every address of its processes. §8.7.
- **startup file** — a file of the shell's inputs, run when the shell starts. §11.2.
- **statement** — a part of a block, an expression, a `let`, or a `fn`. §5.4.
- **strategy** — what a `Supervisor`'s group restarts when a child faults. Appendix E.22.
- **structural equality** — the meaning of `==`: two values are equal when they are built by the same constructor from equal parts, and a foreign type's and a `Process`'s equality is exact. §3.10.
- **subscriber** — a process that asked to be told: of the program's end, by `Os.subscribeTermination`, told and waited for at the end; of the terminal's events; of faults. §8.6, §12.1, Appendix E.21, E.23.
- **subscription** — a process's standing request to be told of the terminal's events, of faults, or of the program's end, ended when the process dies or restarts, or at its own call of `Os.exit`. §6.9, §8.6, §12.1, Appendix E.21, E.23.
- **sum type** — a type with one or more constructors. §3.5.
- **supervisor** — a process that restarts a group of processes, its children, together; the standard library's `Supervisor`. Appendix E.22.
- **system module** — the standard library module that holds a system reference, through which a program uses it. §8.2, Appendix E.0.
- **system process** — a process the runtime starts and keeps, its implementation foreign, its address a system reference. §8.2, §8.4.
- **system reference** — a system process's address, a private top-level binding of its system module that the runtime binds. §8.2.
- **tail position** — a function's body, and the branches, clause bodies, last block expressions, right operands of `&&` and `||`, and pipes' calls within it. §10.
- **taken namespace** — a namespace of the prelude, of the standard library or of the toolchain's own `Ernest`, which no segment of another module's namespace may be, at any depth. §4.2.
- **telling** — the frame a node sends each peer every `utilization-interval` with how busy it is, which the peer holds to draw a peer for `Peer.computeAnywhere`. §8.7, Appendix E.27.
- **termination** — the host's signal `SIGTERM`, which ends the Ernest program as a return of `main` does, its subscribers told; sent to a running program by `Os.signal`. §8.6, Appendix E.23.
- **tick** — a sign of life the host sends a peer where nothing else was sent for 15 seconds. §12.6.
- **top-level binding** — a value bound at file scope by a `let`. §4.6, §8.5.
- **trace** — the host's stack where a fault was met, at the moment it was, as text, a frame a line as Appendix E.21 writes it; a fault's report shows it and `Down` leaves it out. §7.3, §11.2, Appendix E.21.
- **tuple** — a positional product, `#(a, b)`, `#(a, b, c)`. §3.2.
- **type scheme** — a type with its quantified variables and their inferred restrictions, as a generalized binding has. §3.9.
- **type variable** — a lowercase identifier in type position, over which a definition is generalized as §3.9 says. §3.9.
- **unfixed** — a type variable nothing has fixed by the end of its definition, or of the shell's input, that no call fixes (§6.2); a spawned function's mailbox type that is one is `Never`. §3.11, §6.2.
- **`Unit`** — the type with the single value `Unit`. §3.1, §9.3.
- **unit** — a compiled module of the host's that holds definitions, which nothing in a program names. §10, §11.1, §11.2.
- **utilization** — how busy a node is, on one scale: 1.0 every scheduler busy, below it room, above it work waiting; the run queue's measure (§12.8), and answered to a peer by `Peer.utilization`. §8.7, §12.8, Appendix E.27.
- **value position** — an argument, a result, a tuple component, or a type argument whose parameter occurs in a value position of its type's fields. §3.9.
- **version** — three numbers joined by `.`: a package's, which its `VERSION` holds and an entry names, or the least release a manifest's `ernest` names. §11.9.
- **version text** — the toolchain's version as `ern --version` writes it, `0.11.0`, and `0.11.0-dev` or `0.11.0+1a2b3c4d` for a build that is no release. §11.7.
- **vocabulary** — the operations a kind of type provides by its structure, named alike in every module that has them. Appendix E.0.
- **wildcard** — the pattern `_`; matches anything, binds nothing. §2.3, §5.10.
- **wrap** — the function a `monitor` or another function that delivers later takes, from what it delivers to the caller's mailbox type, which the runtime applies as it delivers. §6.9, Appendix E.0.
