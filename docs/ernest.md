# Ernest: Language Report

September 2026. Rationale, rejected alternatives, and open questions are in [`ernest-decisions.md`](ernest-decisions.md).

## 0. Introduction

Ernest is a functional language for concurrent programs. It has two concepts: functions, with Hindley-Milner types and full inference, and processes with typed mailboxes — the only way to affect the world. Everything else in this report is a rule for how the two show up in each other.

Every function runs inside a process: an execution of a function, with a mailbox of its own that receives values of one type. A function either acts through its process, by sending, receiving, or asking for its own address, or it does not. A function that does not is called pure: its result depends only on its arguments, and it affects nothing. A function that acts through its process names its mailbox in its type, `(A) -> B with M`; `M` is the function's mailbox type, and it is the only mark a function type carries. Sections 3 and 6 make this precise. The runtime is what runs Ernest programs; section 10 states what it must provide.

The language is built on five principles. Principle 1 is the final arbiter: it audits the effect of applying the others, measuring how the resulting Ernest code reads. Principles 2 through 5 are constructive rules; when following them yields code that surprises, principle 1 overrides.

1. Least surprise decides. A design surprises when a reader who knows the rest of Ernest would predict different code from the same requirement. The rule may look clean; the resulting code decides.
2. One way, one job — in the language and prelude. No variants for the same thing, no two concepts that overlap in what they express. The standard library, being ordinary Ernest code, may pair functions for convenience.
3. Nothing invisible. Control flow, communication, and failure are visible in the code or in the type. A top-level binding is visible when its name appears at the use site; a hidden effect is not.
4. Simple to parse: recursive descent, first-token dispatch, small bounded lookahead where the grammar demands it, no backtracking.
5. Small: few concepts, few primitives, few reserved words.

## 1. Notation

The grammar is written in Wirth-style EBNF (as in the Modula-2 and Oberon reports). `=` defines, concatenation is juxtaposition (no operator between elements), `|` separates alternatives, `[ ]` is optional, `{ }` is zero or more, `( )` groups, `.` ends a rule. Uppercase names are grammar non-terminals; lowercase names are lexical categories. Terminals are in double or single quotes (either quote may enclose the other). `ident`, `conname`, `typename`, `typevar`, `binop`, and the literals are defined in section 2. The complete grammar is in Appendix A.

## 2. Lexical Elements

### 2.1 Characters

Source text is Unicode in UTF-8; a leading byte-order mark (U+FEFF) is stripped. The whitespace characters are space (U+0020), tab (U+0009), line feed (U+000A), and carriage return (U+000D). Whitespace separates tokens and has no other meaning.

### 2.2 Comments

`//` to end of line and `/* ... */` (which nests) are removed by the lexer and take part in no grammar rule.

`///` to end of line is a doc comment; consecutive `///` lines form a doc block. A doc block immediately preceding a declaration, with no blank line between, is attached to that declaration as documentation, extractable by the toolchain, section 11. Doc blocks elsewhere are ordinary comments.

### 2.3 Identifiers

`ident` begins with a lowercase letter or `_` and continues with any number of letters, digits, and `_`. `conname` and `typename` begin with an uppercase letter and continue the same way, and are lexically the same token. `typevar` is a lowercase identifier in type position.

An identifier that begins with `_` must have at least one further character — the token `_` alone is the wildcard (§5.10).

A qualified name is a sequence of uppercase-starting segments (each is a `typename`) followed by a final segment that starts either lowercase (a function, operator, or variable) or uppercase (a constructor): `Net.Http.parse`, `Stack.push`, `Int.+`, `ServerMsg.Get`. The dots are namespaces, §4.2.

### 2.4 Reserved words

Sixteen, grouped by role:

| Role                 | Words                                                  |
|----------------------|--------------------------------------------------------|
| Type declarations    | `type`, `abstract`, `with`, `foreign`                  |
| Pattern matching     | `match`, `when`, `receive`, `after`, `as`              |
| Control flow         | `if`, `then`, `else`                                   |
| Bindings             | `fn`, `let`                                            |
| Literals             | `true`, `false`                                        |

### 2.5 Literals

```
int      = digit { digit } .
float    = digit { digit } "." digit { digit } [ ( "e" | "E" ) [ "-" ] digit { digit } ] .
char     = "'" ( character | escape ) "'" .
string   = '"' { character | escape } '"' .
escape   = "\\" ( "'" | '"' | "\\" | "n" | "t" | "u{" hexdigit { hexdigit } "}" ) .
bool     = "true" | "false" .
```

**Types.** `1` is `Int`, `1.0` and `1.0e-9` are `Float`. Literals carry no sign; `-` is a prefix operator. No overloaded literals and no default.

**Integer form.** Decimal only — no hex, octal, or binary forms and no digit separators. The standard library provides parsing functions for other bases when needed.

**Escapes.** The six listed above:

| Escape       | Meaning                                        |
|--------------|------------------------------------------------|
| `\'`         | single quote                                   |
| `\"`         | double quote                                   |
| `\\`         | backslash                                      |
| `\n`         | line feed (U+000A)                             |
| `\t`         | tab (U+0009)                                   |
| `\u{...}`    | Unicode scalar; one to six hex digits          |

`\u{...}` denotes a Unicode scalar value: U+0000 through U+10FFFF, excluding surrogates U+D800 through U+DFFF.

**Character content.** A `character` inside a `char` or `string` literal is any code point other than the enclosing quote, `\`, U+000A (line feed), and U+000D (carriage return). Multi-line strings are built by explicit `\n` or by concatenation.

**Lexical primitives.** `digit` is `0` through `9`; `hexdigit` is a digit or `a`-`f` or `A`-`F`; `letter` is `a`-`z` or `A`-`Z`. Identifiers are ASCII, though source text is Unicode.

### 2.6 Operators and delimiters

```
( ) { } [ ] << >> #( , ; : = <- -> | .. _
+ - * / % <> :: == != < <= > >= && || |>
```

Two grammar categories built from the above:

```
binop    = "*" | "/" | "%" | "+" | "-" | "<>" | "::"
         | "==" | "!=" | "<" | "<=" | ">" | ">=" | "&&" | "||"
         | "|>" .
literal  = int | float | char | string | bool .
```

Prefix `-` is negation on `Int` and `Float`, and binds tighter than any binary operator.

Precedence of the binary operators, highest first:

| Level | Operators              | Associativity |
|-------|------------------------|---------------|
| 1     | `* / %`                | left          |
| 2     | `+ - <>`               | left          |
| 3     | `::`                   | right         |
| 4     | `== != < <= > >=`      | left          |
| 5     | `&&`                   | left          |
| 6     | `\|\|`                 | left          |
| 7     | `\|>`                  | left          |

An operator name can be qualified, `Int.+`, §4.8. `|>` is not qualifiable — it is a syntactic form (§5.7), not a namespaced function.

## 3. Types

```
Type      = FnType | TypeAtom .
TypeAtom  = { typename "." } typename [ "(" Type { "," Type } ")" ]
          | typevar
          | TupleType .
TupleType = "#(" Type { "," Type } ")" .
FnType    = "(" [ Type { "," Type } ] ")" "->" Type [ "with" Type ] .
```

### 3.1 Base types

| Type     | Values                                     |
|----------|--------------------------------------------|
| `Int`    | integers of arbitrary precision            |
| `Float`  | IEEE 754 double precision                  |
| `Char`   | one Unicode code point                     |
| `String` | a Unicode string                           |
| `Bytes`  | a sequence of octets                       |
| `Bool`   | `true` or `false`                          |

The prelude declares `Void` as a one-value type (§9.3): a function that has nothing meaningful to return uses it, and the only value is `Void`. There are no type aliases.

### 3.2 Tuples

`#(A, B)` is the type of a tuple; the value form is the same, `#(a, b)`. Tuples of one, two, or more components are all written this way. The tuple is the only positional product type. The `#(` prefix keeps tuples distinct from expression grouping `(e)` and from function types `(A, B) -> C`.

### 3.3 Lists

`List(a)` is an immutable linked list. `[]` is the empty list. `x :: xs` prepends `x` to `xs`; `::` is right-associative, so `[a, b]` is `a :: b :: []`.

### 3.4 Function types

`(A, B) -> C` is the type of a function of two arguments. Arity is part of the type: `(A, B) -> C` and `(#(A, B)) -> C` are different types — the first takes two arguments, the second takes one tuple. `() -> C` takes no arguments.

`with M` after the result is the mailbox type: the function uses the process it runs in, whose mailbox has type `M`, §6.1. A function type without a `with M` is pure.

`with` binds to the nearest arrow; `(A) -> (B) -> C with M` is a pure function returning a function with mailbox type `M`.

### 3.5 Sum types

Declared with `type`, §4.3. A constructor has no fields, exactly one positional field, or named fields:

```
type Optional(a) = None | Some(a)
type Snapshot = Snapshot(dir : Path, seen : Map(Path, Mtime))
```

Positional fields cap at one — beyond that, names are required, because position alone would hide what each field means. Field names are unique within a constructor; their order carries no meaning. Positional and named fields are distinguished by `:` after the first identifier in declarations, and by `=` in construction and patterns.

### 3.6 Abstract types

A sum type whose constructors may be mentioned only in the functions listed in the type's signature, §4.4.

### 3.7 Built-in types

`Address(m)` is an address of a process that receives `m`. `Reply(a)` is a one-shot address for the answer to a request, §6.6. `Never` is the type with no values. The prelude types are listed in section 9.

### 3.8 Foreign types

A type declared `foreign type T` has no constructors: its values are made and used only by foreign functions, §4.7, and can otherwise be held, passed, and sent.

A foreign value is bound to the node that made it: `spawn(Peer(...), f)` or `send` to a remote address is a fault when the payload transitively contains a foreign value, including a closure that captures one, with cause `Fault("foreign value cannot cross nodes")`.

Equality on a foreign type is identity.

### 3.9 Type variables and polymorphism

Types are inferred according to Hindley-Milner. A `fn` definition is generalized over its free type variables; a `let` binding is not. Type variables in a `fn` signature scope over the whole definition.

Recursive and mutually recursive types are allowed. Polymorphic recursion is not. Every type variable in a constructor's fields must be a parameter of the type.

### 3.10 Equality and ordering

`==` and `!=` are defined for all values except those containing functions or addresses; on those, `==` is a type error. Equality is structural.

Ordering is defined per type by the function `compare` in the type's namespace, `Int.compare : (Int, Int) -> Ordering`.

### 3.11 Serialization

All values can be sent in messages, functions included; their code travels with them, section 10.

## 4. Declarations and Scope

```
Program     = { Declaration } .
Declaration = TypeDecl | AbstractDecl | FnDecl | LetDecl | ForeignDecl .
ForeignDecl = "foreign" ( "type" QTypeName [ "(" typevar { "," typevar } ")" ]
            | "fn" Name "(" [ Param { "," Param } ] ")" Return "=" string ) .
TypeDecl    = "type" QTypeName [ "(" typevar { "," typevar } ")" ] "="
              Constructor { "|" Constructor } .
Constructor = conname [ "(" ( Type | Field { "," Field } ) ")" ] .
Field       = ident ":" Type .
AbstractDecl  = "abstract" TypeDecl "with" "{" Signature { ";" Signature } "}" .
Signature   = ( ident | binop ) ":" Type .
FnDecl      = "fn" Name "(" [ Param { "," Param } ] ")" [ Return ] "=" Expr .
Param       = Pattern [ ":" Type ] .
Return      = "->" Type [ "with" Type ] .
LetDecl     = "let" Name [ ":" Type ] "=" Expr .
Binding     = "let" Pattern [ ":" Type ] ( "=" | "<-" ) Expr .
Name        = { typename "." } ( ident | binop ) .
QTypeName   = { typename "." } typename .
```

### 4.1 Modules

A *module* is a single Ernest source file, ending in `.ern`. It is the unit of compilation and the unit that carries a namespace; every top-level declaration belongs to exactly one module.

### 4.2 Namespaces and visibility

The namespace is in the name, and so is the visibility. A top-level declaration with a qualified name, `fn Net.Http.parse(b) = ...`, `type Net.Http.Request = ...`, is visible throughout the program under that name; two such declarations with the same full name are an error. A top-level declaration with an unqualified name, `fn helper(x) = ...`, is visible only in its own module.

A module's path is its namespace: the qualified declarations in `Net/Http.ern` begin with `Net.Http.`, and may go deeper, `Net.Http.Header.parse`. That is the whole of a module's meaning: there is no export list, no `pub`, and no `import`. Sub-namespaces are the dots; namespace segments are type names.

An unqualified name in a body is looked up first among the module's unqualified declarations, then in the namespace of the enclosing declaration, then in the prelude; everything else must be qualified. The only other thing hidden is the constructor of an abstract type from definitions outside its signature. `main` is unqualified, §8.1.

### 4.3 Type declarations

`type` declares a sum type with its constructors. A constructor has the visibility of its type.

### 4.4 Abstract types

`abstract type T = ... with { s1; s2 }` declares a type whose constructors may appear only in the definitions of the names given by the signatures. The names live in `T`'s namespace: the signature `push : (a, Stack(a)) -> Stack(a)` refers to `Stack.push`. The definitions are checked against the signatures and do not repeat the type. The constructor outside these definitions is a type error. The signature delimits who sees the constructor, not which functions may exist for the type.

```
abstract type Stack(a) = Stack(List(a)) with {
    empty : Stack(a);
    push : (a, Stack(a)) -> Stack(a);
    pop : (Stack(a)) -> Optional(#(a, Stack(a)))
}

let Stack.empty = Stack([])
fn Stack.push(x, Stack(xs)) = Stack(x :: xs)
fn Stack.pop(Stack(xs)) = match xs { [] -> None | x :: rest -> Some(#(x, Stack(rest))) }
```

### 4.5 Functions

`fn` declares a function of fixed arity. Annotations may be omitted where they can be inferred. The return annotation has three forms: omitted, `-> T` for a pure function, `-> T with M` for process code. A pure annotation on a function that calls process code is a type error.

A function has one clause. Patterns in parameters must be irrefutable, §5.10: `fn seenCount(Snapshot(seen = entries) : Snapshot) -> Int = Map.size(entries)`.

`fn` may appear at top level and as a statement in a block; it sees its own name, and `fn` declarations in the same block or at top level may refer to each other mutually.

### 4.6 Bindings

In a block, `let p = e` binds the pattern `p` to the value of `e`; `let p <- e` is described in §5.5. The pattern must be irrefutable. A binding is monomorphic and does not see its own name.

Shadowing is allowed: a later binding of the same name hides the earlier one from the next statement on, and the right-hand side sees the earlier one.

At top level, a `let` binds a `Name` — possibly qualified — to a value, `let Stack.empty = Stack([])`; the LHS is a name, not a pattern, and `<-` is a block form only.

### 4.7 Foreign declarations

`foreign type T` declares a type implemented outside the language.

`foreign fn f(params) -> T = "impl"` declares a function whose body is the implementation named by the string, in the runtime's language; parameters and the return are annotated. A foreign function with a mailbox type, `-> T with m`, may do anything; a foreign function without one promises purity: the same result for the same arguments and no effect on anything.

The implementation promises the declared types; a value of another shape, or an exception, is a fault, section 7. Foreign code sees values in the runtime's representation, section 10.

### 4.8 Operators

The arithmetic operators (`+`, `-`, `*`, `/`, `%`) and concatenation (`<>`) resolve against the operand type: `+` in `a + b` with `a : Int` means `Int.+`. Both operands must have the same type. Every namespace may define operators for its type. There is no type "number" to generalize over.

Resolution happens before generalization; a function whose operands do not get their type from an annotation, a literal, a pattern, or a call in the same definition is a type error that requires an annotation.

The comparison operators `==`, `!=`, `<`, `<=`, `>`, `>=` and the Boolean `&&`, `||` are built into the language, not per-namespace: equality is structural (§3.10), ordering uses each type's `compare` function, `&&`/`||` short-circuit on `Bool`. `::` is the list cons (§3.3); `|>` is a syntactic form (§5.7).

## 5. Expressions

```
Expr      = Lambda | IfExpr | MatchExpr | ReceiveExpr | BinExpr .
Lambda    = "fn" "(" [ Param { "," Param } ] ")" [ Return ] "=" Expr .
IfExpr    = "if" Expr "then" Expr "else" Expr .
MatchExpr = "match" Expr "{" Clause { "|" Clause } "}" .
Clause    = Pattern [ "when" Expr ] "->" Expr .
ReceiveExpr  = "receive" "{" ( Clause { "|" Clause } [ "|" AfterClause ] | AfterClause ) "}" .
AfterClause  = "after" Expr "->" Expr .
BinExpr   = Unary { binop Unary } .
Unary     = [ "-" ] Primary { Call } .
Call      = "(" [ Expr { "," Expr } ] ")" .
Primary   = literal | QName | Tuple | ListLit | BitExpr | Block | "(" Expr ")" .
QName     = { typename "." } ( ident | binop | conname [ "(" ( Expr | Fields ) ")" ] ) .
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
AtomPat   = "_" | ident | literal | { typename "." } conname [ "(" ( Pattern | FieldPats ) ")" ]
          | "#(" Pattern { "," Pattern } ")"
          | "[" [ Pattern { "," Pattern } ] "]"
          | BitPat .
BitPat    = "<<" [ BitSegP { "," BitSegP } ] ">>" .
BitSegP   = Pattern [ ":" BitSpec { "-" BitSpec } ] .
BitSpec   = "size" "(" Expr ")" | "unit" "(" int ")"
          | "bits" | "bytes" | "int" | "float"
          | "utf8" | "utf16" | "utf32"
          | "big" | "little" | "native"
          | "signed" | "unsigned" .
FieldPats = [ ident "=" Pattern { "," ident "=" Pattern } ] .
```

### 5.1 Evaluation

Strict, left to right, arguments before the call. No delayed computation; `fn() = e` defers `e`. Prefix `-` is `Int.negate` or `Float.negate` by the operand type.

### 5.2 Calls

`f(x, y)` supplies all arguments. A call with the wrong number of arguments is a type error on the calling line; a call never yields a partially applied function. An expression whose value is a function can be called directly: `makeAdder(3)(4)`.

### 5.3 Lambda

`fn(x) = e` is an anonymous function. Its body is the longest `Expr` at the same nesting level as the `fn`, ending at the first outer `,`, `;`, `|`, `)`, or `}`.

### 5.4 Blocks

`{ s1; s2; e }` is an expression whose value is the last statement, which must be an expression. `;` separates statements and never appears last. Statements are `fn` declarations, `let` bindings, and expressions; an expression as a statement is evaluated for its effect.

### 5.5 Binding with `<-`

In a block, `let p <- e; rest` means that `e` is matched: on `Right(v)`, `p` is bound to `v` and `rest` is evaluated; on `Left(err)`, the block's value is `Left(err)`. If the block's type is `Optional`, `Some` and `None` apply the same way.

The block's type decides which, resolved from the type of `e` as operators are; `rest` must have the block's type. All `<-` bindings in the same block resolve to the same sum type — the block is either `Either` or `Optional`, not both. The rewrite is local to the block.

### 5.6 Construction

`Some(e)`, `None`, `Snapshot(dir = d, seen = s)`. All fields must be given. `Snapshot(..p, seen = s)` takes unlisted fields from `p`; at least one field follows `..`. A constructor is qualified like a function, `Net.Http.Request(...)`.

A nullary constructor is a value, a single-positional constructor is a function value, and named constructors are neither: they only appear in construction syntax. Qualified operators are function values, `Int.+`.

### 5.7 Pipe

`x |> e` treats `e` as a function value or a call and applies it with `x` inserted as an additional first argument: `x |> f` is `f(x)`; `x |> f(a, b)` is `f(x, a, b)`. The pipe reads left to right, which suits stdlib call chains where each function's first argument is the value being transformed:

```
let words = input |> String.trim |> String.toLower |> String.chars
```

`|>` is left-associative and lowest-precedence, below `||`: `a + b |> f` is `f(a + b)`, and `a |> b |> c` is `c(b(a))`. The right-hand side may be a name, a qualified name, a lambda, or a call whose first-argument slot the pipe fills. The type of `x` must match the target function's first argument.

### 5.8 Conditional

`if c then a else b` with `c : Bool`; the branches have the same type.

### 5.9 `match`

The expression is matched against the clauses' patterns in order; the first clause whose pattern matches and whose guard holds is evaluated. A failed guard falls through. The clauses together must cover the type; guards do not count as coverage. Variables in the pattern are bound in the guard and the clause.

### 5.10 Patterns

A pattern decomposes a value and binds its parts. The same patterns appear in `let`, in `match` and `receive` clauses, and in function parameters.

**Atomic patterns.** `_` matches anything and binds nothing. An identifier binds the whole value at its position to a new variable, shadowing any outer variable of that name; it never refers to an existing variable. A literal matches itself.

**Compound patterns.** A constructor with a pattern, `Some(p)`, or with field patterns, `Snapshot(seen = s)`, which may omit fields, matches that constructor and decomposes its fields. A tuple `#(p, q)`, a list `[p, q]`, and `p :: q` decompose those. Patterns nest to any depth: `Some(#(x, Snapshot(dir = d)))`.

**`as` bindings.** `p as c` binds `c` to the whole value that `p` matches, `Some(Snapshot(dir = d) as snap)`. `as` binds loosest, so `x :: rest as all` names the whole list.

**Constraints.** Each variable appears at most once in a pattern; a pattern does not compare, and equality is written in a guard.

**Irrefutable patterns.** A pattern is irrefutable if it cannot fail: `_`, an identifier, a tuple of irrefutable patterns, or a constructor pattern of a type with exactly one constructor whose sub-patterns are all irrefutable. `let` and parameters require irrefutable patterns; `let Right(x) = e` is a type error.

### 5.11 Bitstrings

`<<...>>` constructs and pattern-matches a `Bytes` value at the bit level. A bitstring is a comma-separated list of segments between `<<` and `>>`; each segment is a value (in construction) or a pattern (in `match`), followed optionally by a colon and a dash-separated list of specifiers.

**Specifiers.**

| Specifier                   | Meaning                                                     |
|-----------------------------|-------------------------------------------------------------|
| `size(N)`                   | segment width in units                                      |
| `unit(N)`                   | bits per size unit (default 1)                              |
| `bits`, `bytes`             | segment is a nested bitstring                               |
| `int`, `float`              | numeric segment (defaults: 8-bit, 64-bit)                   |
| `utf8`, `utf16`, `utf32`    | text encoding                                               |
| `big`, `little`, `native`   | endianness                                                  |
| `signed`, `unsigned`        | sign                                                        |

These specifier names carry that role only inside a bitstring — outside, they are ordinary identifiers, and the reserved-word count remains sixteen.

**Patterns and construction.** A bitstring pattern binds its segment variables; a segment whose length is `size(n)-bytes` and whose `n` refers to an earlier bound variable is a size-dependent match, common in protocol parsing. Constructing a bitstring evaluates its segments left to right and concatenates them into a `Bytes` value; a segment whose value does not fit its specified width is a fault. An empty `<<>>` is the empty `Bytes`.

```
fn frame(len : Int, body : Bytes) -> Bytes =
    <<len:size(16)-big, body:bytes>>

fn parseFrame(bytes : Bytes) -> Optional(#(Int, Bytes, Bytes)) = match bytes {
    <<len:size(16)-big, body:size(len)-bytes, rest:bytes>> -> Some(#(len, body, rest))
  | _ -> None
}
```

`frame` constructs: it builds a `Bytes` value with a 16-bit big-endian length followed by the body. `parseFrame` matches the inverse: match a 16-bit big-endian length, then `len` bytes of body, then whatever is left. The runtime compiles bitstrings directly to BEAM's bit syntax, section 10, so the optimizer handles prefix-heavy protocol matches as it would in native BEAM code.

## 6. Processes

A process is an execution of a function with a mailbox type. It has a mailbox that receives values of that type, in arrival order per sender.

### 6.1 The mailbox type

`(A) -> B with M` is the type of a function that acts through the process it runs in, whose mailbox has type `M`. Every call runs in some process; the mailbox type marks that the function uses that process: its own `send`, `receive`, and `self`, or a foreign function with a mailbox type. It does not mark the fact of running in one.

The mailbox type is inferred: a function that calls a function with mailbox type `M` gets mailbox type `M`. Two different mailbox types in the same function is a type error.

A function without a mailbox type is pure: it neither sends, receives, nor calls foreign code with a mailbox type, and it can be called from any process. A pure higher-order function runs its function arguments in the caller's process: `List.map(xs, fn(x) = send(a, x))` has a mailbox type. Nothing else can be marked on a function type.

### 6.2 Built-in functions

```
self  : () -> Address(m) with m
send  : (Address(a), a) -> Void with m
spawn : (Where, () -> Void with n) -> Address(n) with m

type Where = Local | Peer(String)
```

`self()` is the process's own address. `send(a, v)` places `v` in the mailbox of `a` and returns immediately; sending to a process that has died has no effect.

`spawn(w, f)` starts a new process that runs `f()` and returns its address. `self()` inside `f` is the new process's address; a parent that wants replies binds `let me = self();` before `spawn`.

A node is one running instance of the runtime; a peer is another node it knows by name, §8.3. `w` places the process: `Local` on the running node, `Peer(name)` on the peer with that name. An unknown or unreachable peer is a fault. The captured values of `f` are copied to the peer.

### 6.3 `receive`

`receive { clauses }` is a match over the mailbox. The mailbox is scanned in arrival order; the first message that matches some clause is removed, the rest remain, and the clause is evaluated. If none matches, the process waits until one arrives.

Patterns are typed against the mailbox type. Coverage is not required, unlike in `match`; a message no clause matches stays in the mailbox, so that a `receive` can wait for a specific reply in the middle of a protocol without losing other messages.

A final clause `after t -> e` gives a time limit in milliseconds, evaluated on entry; after `t` without a matching message, `e` is evaluated. `after 0` does not wait for new messages. Without `after` there is no limit.

### 6.4 Message ordering

Messages from one process to another are received in sending order. Between different senders there is no ordering.

### 6.5 Addresses

`Address(m)` identifies a process on a node and carries its protocol: `send(a, v)` is type-checked against `m` and is the same on every node.

`via(f, addr)`, §9.5, is the address `addr` seen through `f : (a) -> b`: sending `v` to `via(f, addr)` is sending `f(v)` to `addr`. A single-request answer uses `Reply(a)`, below; `via(Wrap, self())` gives a wrapper address for a process that receives replies in its own mailbox.

Addresses have no equality; identity is expressed in the protocol. There is no registry: a process reaches another only through an address it holds or received in a message, and possession of the address is the permission to send.

### 6.6 Request-reply

A `Reply(a)` is a one-shot address for the answer to a request; unlike `Address(a)`, it is answered exactly once and cannot be stored.

```
Address.call        : (Address(m), (Reply(a)) -> m, Int) -> Optional(a) with n
Address.callForever : (Address(m), (Reply(a)) -> m) -> a with n
answer              : (Reply(a), a) -> Void with m
```

`Address.call(addr, mk, ms)` allocates a fresh `Reply(a)`, calls `mk(r)` to build the message, sends it to `addr`, and returns `Some(v)` when the recipient answers or `None` after `ms` milliseconds. `Address.callForever(addr, mk)` is the same operation without a timeout: the caller waits as long as needed and receives `a` directly, not wrapped in `Optional`; the caller is opting out of the timeout by name, analogous to a `receive` without `after`. `answer(r, v)` sends `v` to the caller.

**Where `Reply(a)` may appear.** As a field of a message, a parameter of a function, a variable bound in a `receive` clause, and a value captured by a lambda passed to `spawn`. Any other position is a type error: a `Reply` in a container, in a `match` or `let` binding, in a return type not itself a message, or as an operand of equality, is rejected by the compiler.

**Linearity.** A `Reply(a)` bound in a `receive` clause is consumed exactly once on every path of the clause's expression. Consumption is `answer(r, v)`, sending `r` as a field of a message, or capturing `r` in a lambda passed to `spawn`; in the last case the captured `Reply` is consumed on every path of the spawned function's body, checked at its definition. A violation is a type error. The check is static: it ensures every path calls `answer` (or delegates or spawns) but not that execution reaches the call at runtime — non-termination, a fault, or an indefinite wait bypasses the answer.

**Timeout rationale.** The mandatory timeout on `Address.call` returns `Optional(a)` so an answer that never arrives has somewhere to land; `Address.callForever` opts out of that by name, and the caller accepts that this call may hang.

**Implementation.** The `Reply(a)` carries a fresh identifier so that `Address.call` receives only the answer to its own request; the caller's mailbox type is unaffected.

### 6.7 Remote computation

A pure function can be evaluated on another node:

```
remote         : (() -> a) -> Either(RemoteError, a)
parallelRemote : (List(() -> a)) -> List(Either(RemoteError, a))
type RemoteError = NoRemotePeer | PeerLost
```

`remote(f)` evaluates `f()` on a peer the runtime chooses among those configured for remote computation, and returns the value. Which peer, and by what criterion, the language does not say. `f` is pure and so is `remote`: the result depends on `f` alone, and the caller waits as it would for any computation. `Left(NoRemotePeer)` if no peer is configured; `Left(PeerLost)` if the peer disappears before the value returns.

`parallelRemote(fs)` runs the functions in `fs` on peers in parallel and returns the results in the input order, one `Either` per input. It is pure by the same reasoning as `remote`: the result depends on the inputs alone. The runtime picks peers and schedules the calls; a caller that needs richer control — cancellation, per-task timeouts, interleaved arrivals — spawns processes itself.

### 6.8 `Never`

A function with mailbox type `Never` can send but never receive; a `receive` in it is a type error.

### 6.9 Death

A process dies when its function returns, when `kill` is called on it, on a fault, section 7, or when the node it runs on is lost. `monitor(a, wrap)`, §9.5, causes `wrap(d)` to be placed in the caller's mailbox when `a` dies, where `d : Down` gives the cause. There are no other links.

### 6.10 Code replacement

A process replaces its code by a message in its own type that carries the new loop, and switches with a tail call:

```
type CounterMsg
    = Inc(Int)
    | Get(reply : Reply(Int))
    | Upgrade(migrate : (Int) -> Int, next : (Int) -> Void with CounterMsg)

fn counter(n : Int) -> Void with CounterMsg = receive {
    Inc(k) -> counter(n + k)
  | Get(reply = r) -> { answer(r, n); counter(n) }
  | Upgrade(migrate = m, next = k) -> k(m(n))
}
```

The language has no other mechanism for code replacement.

## 7. Errors

There are no exceptions. An error is a value, a message, or a fault.

### 7.1 Value errors

The error is part of the function's meaning. It is expressed in the return type: `Either(e, a)` with an error type `e`, or `Optional(a)`. The caller matches on the result, or chains with `let p <- e` (§5.5).

### 7.2 Message errors

The error crosses a process boundary. It is expressed in the message: `Either` or a dedicated constructor in the reply type. A missing reply is `after` in `receive` (§6.3). The error type across the boundary is its own, distinct from the function's.

### 7.3 Faults

The code cannot see the error. Causes include out of memory, `kill`, a failure in the runtime, and a broken promise by foreign code. The process dies with a structured cause in `Down` (§6.9). Nothing is caught.

"Fault" here is the category — any death whose `Reason` is not `Returned`. `Fault(String)` is one specific `Reason` alongside `Killed` and `ProgramEnd`.

### 7.4 The total prelude

The prelude is total: no built-in function faults. Partial operations return `Optional` or `Either`. A fault is therefore always something that happened to the process, never something it did.

Three deliberate exceptions:

- `/` and `%` on `Int` with a zero divisor fault with cause `Fault("division by zero")`. `Int.div` and `Int.mod` return `Optional` for the caller who wants to handle it.
- `todo("...")` compiles at any type and faults if reached with cause `Fault("todo: ...")`, so that an unfinished function can be declared before it is written.
- `spawn(Peer(...), f)` or `send` to a remote address when the payload transitively contains a foreign value, with cause `Fault("foreign value cannot cross nodes")` (§3.8).

## 8. Programs

### 8.1 `main`

A program is a set of modules with exactly one function `main : () -> Void with m` for some `m`, unqualified, called by the runtime. Nothing sends to `main` that it has not given its address to; `m` is usually `Void`.

### 8.2 System references

The runtime starts with its system processes and exposes their addresses as top-level values in the `Sys` namespace. The language requires `Sys.stdout : Address(String)` and `Sys.clock : Address(ClockMsg)`, §9.7; a specific runtime may provide more, and a paper program that needs additions like `Sys.fs`, `Sys.stdin`, `Sys.keys`, or a stderr sink names them in its assumptions.

These are values, not functions — like `List`, `Map`, and `Set` they are in scope everywhere at the top level. To do IO a function sends to one, and `send` requires a mailbox effect on the caller (§6.1), so pure code cannot affect anything outside its process even though it can name the address.

A reference to a `Sys.*` name the runtime does not provide is a name-resolution error at compile time. The `stdout` process writes each received `String` to standard output as bytes; newlines are the sender's responsibility.

### 8.3 Peers

Peers are configured outside the language, §11.3; `Peer(name)` refers to them by the configured name, and nodes authenticate each other.

### 8.4 Foreign code

The system processes are foreign processes: their message types are declared in Ernest, their implementations live outside the language, and the runtime starts them and binds their addresses to the `Sys.*` top-level references. Other foreign code enters through `foreign fn` and `foreign type`, §4.7. Both boundaries carry the same promise: the foreign side delivers the declared types, and a breach is a fault.

### 8.5 Program termination

The program ends when `main` returns. Live processes then die with cause `ProgramEnd`; system processes release their resources. A program that is to keep running waits in `main`.

If no process can run, all are waiting in `receive` without `after`, and no messages are in flight, the runtime ends the program with the error `Deadlock`. A pending `after` or clock counts as a message in flight.

## 9. Prelude

The prelude is small: only what this report names. Convenience libraries — including all container operations, string and numeric utilities, and output helpers — live in the standard library, Appendix E.

### 9.1 Built-in types (section 3)

```
Address(m) // an address of a process that receives m
Reply(a) // a one-shot address, section 6
Never // the type with no values
```

### 9.2 Built-in parameterized types

Provided by the runtime:

```
List(a) // an immutable linked list of elements of type a
Map(k, v) // an immutable dictionary from k to v; requires equality on k
Set(a) // an immutable set of a; requires equality on a
```

### 9.3 Declared types

```
type Void = Void // the one-value type; carries no information
type Optional(a) = None | Some(a)
type Either(e, a) = Left(e) | Right(a)
type Ordering = Less | Equal | Greater
type Down = Down(reason : Reason, function : String)
type Reason = Returned | Killed | ProgramEnd | Fault(String)
type ClockMsg // times in milliseconds
    = After(ms : Int, to : Address(Void))
    | At(at : Int, to : Address(Void))
    | Now(reply : Reply(Int))
type RemoteError = NoRemotePeer | PeerLost
type Foreign // a value the language does not inspect
type Where = Local | Peer(String) // spawn placement, section 6
```

### 9.4 Built-in functions (section 6)

```
self  : () -> Address(m) with m
send  : (Address(a), a) -> Void with m
spawn : (Where, () -> Void with n) -> Address(n) with m
```

### 9.5 Process functions

```
via                 : ((a) -> b, Address(b)) -> Address(a)
Address.call        : (Address(m), (Reply(a)) -> m, Int) -> Optional(a) with n
Address.callForever : (Address(m), (Reply(a)) -> m) -> a with n
answer              : (Reply(a), a) -> Void with m
remote              : (() -> a) -> Either(RemoteError, a)
parallelRemote      : (List(() -> a)) -> List(Either(RemoteError, a))
monitor             : (Address(a), (Down) -> m) -> Void with m
kill                : (Address(a)) -> Void with m
```

### 9.6 Operations required by the language

```
Int.+, Int.-, Int.*, Int./, Int.%   : (Int, Int) -> Int              // section 4
Int.negate                          : (Int) -> Int                   // section 5: prefix -
Float.+, Float.-, Float.*, Float./  : (Float, Float) -> Float
Float.negate                        : (Float) -> Float
String.<>                             : (String, String) -> String           // section 4: <> resolves per type
List.<>                             : (List(a), List(a)) -> List(a)
Int.div, Int.mod                    : (Int, Int) -> Optional(Int)    // section 7: / and %
                                                                     // fault on zero; these do not
Int.compare                         : (Int, Int) -> Ordering         // section 3: ordering is per type
Float.compare                       : (Float, Float) -> Ordering
String.compare                        : (String, String) -> Ordering
Char.compare                        : (Char, Char) -> Ordering
todo                                : (String) -> a                    // section 7: faults if reached
```

### 9.7 System references

Runtime-provided, section 8:

```
Sys.stdout       : Address(String) // the stdout process
Sys.clock        : Address(ClockMsg) // the clock process
```

## 10. Runtime Requirements

- Tail calls take constant stack space. The last expression of a block, a `match` clause, and a `receive` clause is in tail position.
- Processes are scheduled preemptively; a process cannot prevent others from running.
- Processes share no memory; a message is a copy or immutable.
- Mailboxes are unbounded; a program is responsible for its own backpressure.
- `Int` has arbitrary precision.
- The representation of values is fixed and documented, so that foreign code can produce and consume them.
- `Down` carries a cause distinguishable from other causes.
- The runtime detects `Deadlock` as in section 8.
- A node ships code to a peer that lacks it, identified by content, so that `spawn` on a peer and `remote` need no prior installation; peers need not hold the same code.
- The runtime detects the loss of a node: its processes die with `Fault("peer lost")` and its remote computations return `Left(PeerLost)`.

## 11. Toolchain

### 11.1 `ernc` (compiler)

`ernc file.ern` compiles a module to `file.erc`, a compiled module the runtime can load. A program is compiled module by module; cross-module names are resolved at load.

### 11.2 `ern` (runner)

`ern [--config-dir dir] [-pa dir ...] file.erc` loads the module and, on demand, the compiled modules on the load path, found by namespace, `Net.Http.parse` in `Net/Http.erc`; starts the system processes, binds their addresses to the `Sys.*` top-level references, and calls `main`. The standard library, Appendix E, is on the load path by default; `-pa` extends it.

`ern --repl` starts a read-evaluate-print loop with the same loading. `--config-dir` names the configuration directory, `./.ernest` by default.

### 11.3 Configuration setup

`ern --create-config-dir dir` creates `dir/.ernest/` containing `ernest.conf` and this node's private key, readable only by its owner, and does nothing else; it fails if the directory exists. `ernest.conf` holds this node's network address and public key, and the list of peers: for each, a name, a network address, a public key, and whether it accepts remote computation. Appendix C shows one. The names are the ones `Peer(name)` refers to.

### 11.4 Documentation extraction

`ernc --doc file.ern` writes the doc comments extracted from `file.ern` to stdout as Markdown, grouped by declaration.

## Appendix A. Grammar

```
Program     = { Declaration } .
Declaration = TypeDecl | AbstractDecl | FnDecl | LetDecl | ForeignDecl .
ForeignDecl = "foreign" ( "type" QTypeName [ "(" typevar { "," typevar } ")" ]
            | "fn" Name "(" [ Param { "," Param } ] ")" Return "=" string ) .

TypeDecl    = "type" QTypeName [ "(" typevar { "," typevar } ")" ] "="
              Constructor { "|" Constructor } .
Constructor = conname [ "(" ( Type | Field { "," Field } ) ")" ] .
Field       = ident ":" Type .
AbstractDecl  = "abstract" TypeDecl "with" "{" Signature { ";" Signature } "}" .
Signature   = ( ident | binop ) ":" Type .

FnDecl      = "fn" Name "(" [ Param { "," Param } ] ")" [ Return ] "=" Expr .
Param       = Pattern [ ":" Type ] .
Return      = "->" Type [ "with" Type ] .
LetDecl     = "let" Name [ ":" Type ] "=" Expr .
Binding     = "let" Pattern [ ":" Type ] ( "=" | "<-" ) Expr .
Name        = { typename "." } ( ident | binop ) .
QTypeName   = { typename "." } typename .

Type        = FnType | TypeAtom .
TypeAtom    = { typename "." } typename [ "(" Type { "," Type } ")" ] | typevar
            | TupleType .
TupleType   = "#(" Type { "," Type } ")" .
FnType      = "(" [ Type { "," Type } ] ")" "->" Type [ "with" Type ] .

Expr        = Lambda | IfExpr | MatchExpr | ReceiveExpr | BinExpr .
Lambda      = "fn" "(" [ Param { "," Param } ] ")" [ Return ] "=" Expr .
IfExpr      = "if" Expr "then" Expr "else" Expr .
MatchExpr   = "match" Expr "{" Clause { "|" Clause } "}" .
Clause      = Pattern [ "when" Expr ] "->" Expr .
ReceiveExpr    = "receive" "{" ( Clause { "|" Clause } [ "|" AfterClause ] | AfterClause ) "}" .
AfterClause    = "after" Expr "->" Expr .
BinExpr     = Unary { binop Unary } .
Unary       = [ "-" ] Primary { Call } .
Call        = "(" [ Expr { "," Expr } ] ")" .
Primary     = literal | QName | Tuple | ListLit | BitExpr | Block | "(" Expr ")" .
QName       = { typename "." } ( ident | binop | conname [ "(" ( Expr | Fields ) ")" ] ) .
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
AtomPat     = "_" | ident | literal | { typename "." } conname [ "(" ( Pattern | FieldPats ) ")" ]
            | "#(" Pattern { "," Pattern } ")"
            | "[" [ Pattern { "," Pattern } ] "]"
            | BitPat .
BitPat      = "<<" [ BitSegP { "," BitSegP } ] ">>" .
BitSegP     = Pattern [ ":" BitSpec { "-" BitSpec } ] .
BitSpec     = "size" "(" Expr ")" | "unit" "(" int ")"
            | "bits" | "bytes" | "int" | "float"
            | "utf8" | "utf16" | "utf32"
            | "big" | "little" | "native"
            | "signed" | "unsigned" .
FieldPats   = [ ident "=" Pattern { "," ident "=" Pattern } ] .
```

`binop` and `literal` are defined in section 2, along with the other lexical categories; `binop` precedence follows the table there. Every nonterminal is decided by its first token: `let` begins a binding, `fn` a declaration or lambda, `{` a block, `[` a list, `(` a call, tuple, or parenthesized expression. In `QName`, after each uppercase token the next token decides: `.` continues the qualification; otherwise the segment is final, and a lowercase final is a function or operator, an uppercase final a constructor. A constructor's fields are positional or named by whether `=` or `:` follows the first identifier. `conname` and `typename` are one token class; which one a segment is follows from its position.

## Appendix B. Examples

The counter of section 6, with a `main` that exercises `Inc` and `Get`. `Upgrade` is not exercised here; it is covered by the fragment in section 6.

```
type CounterMsg
    = Inc(Int)
    | Get(reply : Reply(Int))
    | Upgrade(migrate : (Int) -> Int, next : (Int) -> Void with CounterMsg)

fn main() -> Void with Void = {
    let c = spawn(Local, fn() = counter(0));
    send(c, Inc(5));
    send(c, Inc(3));
    match Address.call(c, fn(r) = Get(reply = r), 1000) {
        Some(n) -> Io.println("count is " <> Int.toString(n))
      | None -> Io.println("counter is not answering")
    }
}

fn counter(n : Int) -> Void with CounterMsg = receive {
    Inc(k) -> counter(n + k)
  | Get(reply = r) -> { answer(r, n); counter(n) }
  | Upgrade(migrate = m, next = k) -> k(m(n))
}
```

```
type PongMsg = Ping(n : Int, reply : Reply(Int)) | Stop

fn main() -> Void with Void = {
    let pongAddr = spawn(Local, fn() = pong());
    let _ = spawn(Local, fn() = ping(pongAddr, 3));
    Void
}

fn ping(pongAddr : Address(PongMsg), n : Int) -> Void with m =
    if n == 0 then send(pongAddr, Stop)
    else {
        Io.println("ping " <> Int.toString(n));
        match Address.call(pongAddr, fn(r) = Ping(n = n, reply = r), 5000) {
            Some(_) -> ping(pongAddr, n - 1)
          | None -> { Io.println("pong is not answering"); send(pongAddr, Stop) }
        }
    }

fn pong() -> Void with PongMsg = receive {
    Ping(n = n, reply = r) -> {
        Io.println("pong " <> Int.toString(n));
        answer(r, n);
        pong()
    }
  | Stop -> Void
}
```

```
type WorkerMsg = DoWork(f : (String) -> Bytes, arg : String)

fn submitter(worker : Address(WorkerMsg)) -> Void with Never = {
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

`Peer("foo")` and `Peer("bar")` name these peers in `spawn`, section 6. `remote(f)` chooses among peers with `"remote-peer": true`, here only `foo`. The private key is in the same directory, `private-key.pem`, readable only by its owner. A freshly created file has an empty `peers` list.

## Appendix D. A Foreign Library

A shim over Erlang's `ets`, tables of type `set`. Raw bindings are module-local (unqualified); the library is ordinary Ernest over them. No Erlang module is needed: the representation of values, section 10, already matches Erlang's conventions, `true` is `Bool`, `[{K, V}]` is `List(#(k, v))`, and `{ok, V} | {error, R}` is a sum type with constructors tagged `ok` and `error`.

```
// Ets.ern

/// A key-value table stored in the runtime's ETS backend, keyed
/// by a value of type k with values of type v. A table lives
/// until Ets.drop is called on it, or until the process that
/// created it dies.
foreign type Ets.Table(k, v)

/// A fresh empty table. The table is owned by the current
/// process and is destroyed when that process dies.
fn Ets.new() -> Ets.Table(k, v) with m = rawNew("ernest", [atom("set"), atom("public")])

foreign fn rawNew(name : String, opts : List(Foreign)) -> Ets.Table(k, v) with m = "ets:new/2"
foreign fn atom(name : String) -> Foreign = "erlang:binary_to_atom/1"

/// Insert or replace the entry for key.
fn Ets.insert(t : Ets.Table(k, v), key : k, value : v) -> Void with m = {
    let _ = rawInsert(t, (key, value));
    Void
}

foreign fn rawInsert(t : Ets.Table(k, v), row : (k, v)) -> Bool with m = "ets:insert/2"

/// The value for key, or None if absent.
fn Ets.lookup(t : Ets.Table(k, v), key : k) -> Optional(v) with m =
    match rawLookup(t, key) { [(_, v)] -> Some(v) | _ -> None }

foreign fn rawLookup(t : Ets.Table(k, v), key : k) -> List(#(k, v)) with m = "ets:lookup/2"

/// Remove key. A key not present is not an error.
fn Ets.delete(t : Ets.Table(k, v), key : k) -> Void with m = { let _ = rawDelete(t, key); () }

foreign fn rawDelete(t : Ets.Table(k, v), key : k) -> Bool with m = "ets:delete/2"

/// The number of entries in the table.
fn Ets.size(t : Ets.Table(k, v)) -> Int with m = rawInfo(t, atom("size"))

foreign fn rawInfo(t : Ets.Table(k, v), item : Foreign) -> Int with m = "ets:info/2"

/// Delete the table. All subsequent operations on it fault.
fn Ets.drop(t : Ets.Table(k, v)) -> Void with m = { let _ = rawDrop(t); () }

foreign fn rawDrop(t : Ets.Table(k, v)) -> Bool with m = "ets:delete/1"

/// Remove all entries, leaving the table empty.
fn Ets.clear(t : Ets.Table(k, v)) -> Void with m = { let _ = rawClear(t); () }

foreign fn rawClear(t : Ets.Table(k, v)) -> Bool with m = "ets:delete_all_objects/1"

/// True if key is present in t.
foreign fn Ets.member(t : Ets.Table(k, v), key : k) -> Bool with m = "ets:member/2"

/// All key-value pairs currently in the table, in unspecified order.
foreign fn Ets.toList(t : Ets.Table(k, v)) -> List(#(k, v)) with m = "ets:tab2list/1"
```

```
fn main() -> Void with Void = {
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

The raw names are unqualified and therefore invisible outside the module; `Ets.*` is the library. `Ets.Table(k, v)` has type parameters the implementation never sees: `Ets.insert(t, "a", 1)` fixes `t` to `Table(String, Int)`, and an insert with other types on the next line is a type error. Every operation has a mailbox type, `size` and `member` included, because they read state that others write. `atom` is pure: the same text gives the same atom. An Erlang-side module is needed only to catch: a raw function that throws is a fault, and a shim that wants `Either` instead must `try` in Erlang, since Ernest cannot. What the type cannot say, the declaration's documentation must: a table lives until `Ets.drop`, or until the process that created it dies.

## Appendix E. Standard Library

Informative, not normative: this appendix lists the modules that ship with the compiler as ordinary Ernest files under `stdlib/`. The standard library is on the load path by default — no `-pa` flag needed. Every program can call `Io.println`, `List.map`, and the rest without any setup. The prelude in section 9 is what the language itself requires; everything below is convenience written in Ernest on top of it.

### Appendix E.1. `Io.ern`

Output helpers. The plain forms send to `Sys.stdout` (section 8); the `*To` forms take an explicit `Address(String)`, useful for logging to a mailbox that is not stdout.

```
Io.print      : (String) -> Void with m // to Sys.stdout
Io.println    : (String) -> Void with m // to Sys.stdout, appends "\n"

Io.printTo    : (Address(String), String) -> Void with m
Io.printlnTo  : (Address(String), String) -> Void with m // appends "\n"
```

### Appendix E.2. `List.ern`

Container-first operations over `List(a)`.

```
List.size        : (List(a)) -> Int
List.isVoid     : (List(a)) -> Bool
List.head        : (List(a)) -> Optional(a)
List.last        : (List(a)) -> Optional(a)
List.at          : (List(a), Int) -> Optional(a)
List.reverse     : (List(a)) -> List(a)
List.take        : (List(a), Int) -> List(a)
List.drop        : (List(a), Int) -> List(a)
List.dropLast    : (List(a)) -> List(a)
List.contains    : (List(a), a) -> Bool
List.find        : (List(a), (a) -> Bool) -> Optional(a)
List.any         : (List(a), (a) -> Bool) -> Bool
List.all         : (List(a), (a) -> Bool) -> Bool
List.map         : (List(a), (a) -> b) -> List(b)
List.filter      : (List(a), (a) -> Bool) -> List(a)
List.filterMap   : (List(a), (a) -> Optional(b)) -> List(b)
List.foldLeft    : (List(a), b, (b, a) -> b) -> b
List.foreach     : (List(a), (a) -> Void) -> Void
List.span        : (List(a), (a) -> Bool) -> #(List(a), List(a))
List.sort        : (List(a), (a, a) -> Ordering) -> List(a)
List.remove      : (List(a), a) -> List(a)
```

### Appendix E.3. `Map.ern`

Container-first operations over `Map(k, v)`.

```
Map.empty        : Map(k, v)
Map.size         : (Map(k, v)) -> Int
Map.isVoid      : (Map(k, v)) -> Bool
Map.contains     : (Map(k, v), k) -> Bool
Map.get          : (Map(k, v), k) -> Optional(v)
Map.put          : (Map(k, v), k, v) -> Map(k, v)
Map.remove       : (Map(k, v), k) -> Map(k, v)
Map.keys         : (Map(k, v)) -> List(k)
Map.values       : (Map(k, v)) -> List(v)
Map.map          : (Map(k, v), (k, v) -> w) -> Map(k, w)
Map.foldLeft     : (Map(k, v), b, (b, k, v) -> b) -> b
```

### Appendix E.4. `Set.ern`

Container-first operations over `Set(a)`.

```
Set.empty        : Set(a)
Set.size         : (Set(a)) -> Int
Set.isVoid      : (Set(a)) -> Bool
Set.contains     : (Set(a), a) -> Bool
Set.add          : (Set(a), a) -> Set(a)
Set.remove       : (Set(a), a) -> Set(a)
Set.union        : (Set(a), Set(a)) -> Set(a)
Set.intersect    : (Set(a), Set(a)) -> Set(a)
Set.difference   : (Set(a), Set(a)) -> Set(a)
Set.fromList     : (List(a)) -> Set(a)
Set.toList       : (Set(a)) -> List(a)
```

### Appendix E.5. `String.ern`

```
String.size        : (String) -> Int // number of code points
String.isVoid     : (String) -> Bool
String.contains    : (String, String) -> Bool // substring test
String.toInt       : (String) -> Optional(Int)
String.chars       : (String) -> List(Char)
String.fromChars   : (List(Char)) -> String
String.fromUtf8    : (Bytes) -> Optional(String)
String.toUtf8      : (String) -> Bytes
String.lines       : (String) -> List(String)
String.all         : (String, (Char) -> Bool) -> Bool
```

### Appendix E.6. `Char.ern`

```
Char.isDigit     : (Char) -> Bool
Char.isAlpha     : (Char) -> Bool
Char.isSpace     : (Char) -> Bool
Char.toString      : (Char) -> String
Char.toInt       : (Char) -> Int // Unicode code point
```

### Appendix E.7. `Bool.ern`

```
Bool.not         : (Bool) -> Bool
Bool.toString      : (Bool) -> String // "true" or "false"
```

### Appendix E.8. `Int.ern`

```
Int.abs          : (Int) -> Int
Int.min          : (Int, Int) -> Int
Int.max          : (Int, Int) -> Int
Int.bitAnd       : (Int, Int) -> Int
Int.bitOr        : (Int, Int) -> Int
Int.bitXor       : (Int, Int) -> Int
Int.bitNot       : (Int) -> Int
Int.shiftLeft    : (Int, Int) -> Int
Int.shiftRight   : (Int, Int) -> Int // arithmetic (sign-preserving)
Int.toString       : (Int) -> String
Int.toFloat      : (Int) -> Float
```

### Appendix E.9. `Float.ern`

```
Float.abs        : (Float) -> Float
Float.toString     : (Float) -> String
Float.round      : (Float) -> Int // banker's rounding, IEEE 754 default
Float.floor      : (Float) -> Int
Float.ceil       : (Float) -> Int
```

### Appendix E.10. `Optional.ern`

```
Optional.isSome      : (Optional(a)) -> Bool
Optional.isNone      : (Optional(a)) -> Bool
Optional.withDefault : (Optional(a), a) -> a
Optional.map         : (Optional(a), (a) -> b) -> Optional(b)
Optional.andThen     : (Optional(a), (a) -> Optional(b)) -> Optional(b)
```

### Appendix E.11. `Either.ern`

```
Either.isLeft       : (Either(e, a)) -> Bool
Either.isRight      : (Either(e, a)) -> Bool
Either.withDefault  : (Either(e, a), a) -> a
Either.map          : (Either(e, a), (a) -> b) -> Either(e, b)
Either.mapLeft      : (Either(e, a), (e) -> f) -> Either(f, a)
Either.andThen      : (Either(e, a), (a) -> Either(e, b)) -> Either(e, b)
Either.toOptional   : (Either(e, a)) -> Optional(a)
Either.fromOptional : (Optional(a), e) -> Either(e, a)
```

### Appendix E.12. `Foreign.ern`

```
Foreign.toInt    : (Foreign) -> Optional(Int)
Foreign.toFloat  : (Foreign) -> Optional(Float)
Foreign.toString   : (Foreign) -> Optional(String)
Foreign.toBool   : (Foreign) -> Optional(Bool)
Foreign.toList   : (Foreign) -> Optional(List(Foreign))
```

The standard library is expected to grow. New modules are added when a pattern shows up in three programs, matching the rule the decisions log applies to other deferred additions.

## Appendix F. Glossary

Every technical term this report introduces, with the section that defines it. Pointers only — the definition lives in the referenced section.

- **abstract type** — a sum type whose constructors are visible only to the functions listed in its signature. §3.6, §4.4.
- **address** — `Address(m)`, a reference to a process that receives values of type `m`. §3.7, §6.5.
- **arity** — the number of arguments a function takes; part of its type. §4.5.
- **binding** — a `let` in a block, `let p = e` or `let p <- e`. §4.6, §5.5.
- **bitstring** — a bit-level value or pattern `<<...>>` that produces or matches a `Bytes` value. §5.11.
- **`Bytes`** — the type of an octet sequence. §3.1.
- **clause** — one pattern-branch of a `match` or `receive`. §5.9, §6.3.
- **compare** — the per-type function that produces `Ordering`. §3.10.
- **concat operator** — `<>`, resolved per type: `String.<>`, `List.<>`, `Bytes.<>`. §4.8.
- **cons operator** — `::`, list-prepend, right-associative. §3.3, §5.10.
- **constructor** — a case of a sum type; a value, a function, or a construction form. §3.5, §5.6.
- **doc comment** — `///` to end of line; attached to the following declaration. §2.2.
- **fault** — a process death whose `Reason` is not `Returned`; not catchable. §7.3.
- **`Fault(msg)`** — one specific `Reason`, carrying a message. §7.3, §7.4.
- **foreign function** — declared `foreign fn`; body is a string reference to a runtime implementation. §4.7.
- **foreign type** — declared `foreign type T`; values are made and used only by foreign functions. §3.8, §4.7.
- **generalization** — quantifying free type variables in a `fn` definition. §3.9.
- **guard** — a `when` expression on a `match` or `receive` clause. §5.9.
- **Hindley-Milner** — the type system Ernest uses; full inference. §3.9.
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
- **`Never`** — a mailbox type that permits `send` but forbids `receive`. §3.7, §6.8.
- **operator resolution** — per-type dispatch of arithmetic and `<>` to `Type.<op>`. §4.8.
- **pattern** — decomposes a value and binds its parts. §5.10.
- **peer** — another node the runtime knows by name. §6.2, §8.3.
- **pipe** — the `|>` operator, `x |> f` = `f(x)`. §5.7.
- **positional field** — a field on a constructor identified by position, not name. §3.5.
- **precedence** — the binding tightness of a binary operator. §2.6.
- **prelude** — the small set of names the language requires to exist. §9.
- **process** — an execution of a function with a mailbox. §6.
- **pure function** — a function without a mailbox type; result depends only on arguments. §0, §6.1.
- **qualified name** — a name with a dotted namespace prefix, `Net.Http.parse`. §2.3, §4.2.
- **`receive`** — a match over the mailbox. §6.3.
- **remote computation** — `remote(f)` and `parallelRemote(fs)` evaluate pure functions on peers. §6.7.
- **`Reply(a)`** — a one-shot address for the answer to a request; linear inside a `receive` clause. §3.7, §6.6.
- **reserved word** — one of sixteen keywords. §2.4.
- **runtime** — the system that runs Ernest programs; BEAM. §10.
- **`self`** — `self()`, the current process's own address. §6.2.
- **`send`** — `send(a, v)`, places `v` in the mailbox of `a`. §6.2.
- **`spawn`** — `spawn(w, f)`, starts a new process. §6.2.
- **structural equality** — the meaning of `==`; two values are equal if their shape is. §3.10.
- **sum type** — a type with one or more constructors. §3.5.
- **system reference** — a top-level address in `Sys.*`, wired by the runtime. §8.2.
- **tail position** — the last expression of a block, `match` clause, or `receive` clause; guaranteed TCO. §10.
- **top-level binding** — a value in scope everywhere at the top level. §0, §8.2.
- **tuple** — a positional product, `#(a, b)`, `#(a, b, c)`, `#(a)`. §3.2.
- **type variable** — a lowercase identifier in type position; universally quantified in a `fn`. §3.9.
- **`Void`** — a type with the single value `Void`; the prelude's stand-in for "no meaningful return." §3.1, §9.3.
- **`via`** — `via(f, addr)` is the address `addr` seen through `f`. §6.5, §9.5.
- **wildcard** — the pattern `_`; matches anything, binds nothing. §2.3, §5.10.
- **`with M`** — the mailbox-type marker on a function type. §3.4, §6.1.
