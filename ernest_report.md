# Ernest: Language Report

Revision of 17 September 2026. Rationale, rejected alternatives, and open questions are in [`decisions.md`](docs/decisions.md).

## 0. Introduction

Ernest is a functional language for concurrent programs. It has two concepts: functions, with Hindley-Milner types and full inference, and processes with typed mailboxes, the only way to affect the world. Everything else in this report is a rule for how the two show up in each other.

Every function runs inside a process, an execution of a function with a mailbox that receives values of one type. A function that sends, receives, or asks for its own address acts through its process and names its mailbox in its type, `(A) -> B with M`; that is the only mark a function type carries. A function that does not is pure: its result depends only on its arguments, and it affects nothing. Sections 3 and 6 make this precise; section 10 states what the runtime must provide.

Five principles. Principles 2 to 5 are constructive; when following them yields code that surprises, principle 1 overrides.

1. Least surprise decides. A design surprises when a reader who knows the rest of Ernest would predict different code from the same requirement. The resulting code decides, not the rule.
2. One way, one job, in the language and prelude. No variants for the same thing, no two concepts that overlap. The standard library may pair functions for convenience.
3. Nothing invisible. Control flow, communication, and failure are visible in the code or in the type. A top-level binding is visible when its name appears at the use site.
4. Simple to parse: recursive descent, first-token dispatch, small bounded lookahead where the grammar demands it, no backtracking.
5. Small: few concepts, few primitives, few reserved words.

## 1. Notation

The grammar is Wirth-style EBNF. `=` defines, juxtaposition concatenates, `|` separates alternatives, `[ ]` is optional, `{ }` is zero or more, `( )` groups, `.` ends a rule. Uppercase names are non-terminals, lowercase names lexical categories. Terminals are in double or single quotes. `ident`, `conname`, `typename`, `typevar`, `binop`, and the literals are defined in section 2. The complete grammar is Appendix A.

## 2. Lexical Elements

### 2.1 Characters

Source text is Unicode in UTF-8; a leading byte-order mark (U+FEFF) is stripped. Whitespace is space (U+0020), tab (U+0009), line feed (U+000A), and carriage return (U+000D); it separates tokens and has no other meaning.

### 2.2 Comments

`//` to end of line and `/* ... */`, which nests, are removed by the lexer and take part in no grammar rule.

`///` to end of line is a doc comment; consecutive `///` lines form a doc block. A doc block immediately preceding a declaration, with no blank line between, is that declaration's documentation, extractable by the toolchain, section 11. Elsewhere it is an ordinary comment.

### 2.3 Identifiers

```
letter   = "a" | ... | "z" | "A" | ... | "Z" .
digit    = "0" | ... | "9" .
hexdigit = digit | "a" | ... | "f" | "A" | ... | "F" .
lower    = "a" | ... | "z" .
upper    = "A" | ... | "Z" .
ident    = ( lower | "_" ) { letter | digit | "_" } .
typename = upper { letter | digit | "_" } .
conname  = typename .
typevar  = ident .
```

`ident` begins with a lowercase letter or `_`; `conname` and `typename` begin with an uppercase letter and are the same token; `typevar` is a lowercase identifier in type position. A reserved word (§2.4) is never an `ident`. `_` alone is the wildcard (§5.10), so an identifier beginning with `_` has at least one further character.

A qualified name is a sequence of uppercase-starting segments followed by a final segment that starts lowercase, a function, operator, or variable, or uppercase, a constructor: `Net.Http.parse`, `Stack.push`, `Int.+`, `ServerMsg.Get`. The dots are namespaces, §4.2.

### 2.4 Reserved words

Seventeen, grouped by role:

| Role                 | Words                                                  |
|----------------------|--------------------------------------------------------|
| Type declarations    | `type`, `abstract`, `with`, `foreign`                  |
| Pattern matching     | `match`, `when`, `receive`, `after`, `as`              |
| Control flow         | `if`, `then`, `else`                                   |
| Bindings             | `fn`, `let`                                            |
| Visibility           | `export`                                               |
| Literals             | `true`, `false`                                        |

### 2.5 Literals

```
int      = digit { digit } .
float    = digit { digit } "." digit { digit } [ ( "e" | "E" ) [ "+" | "-" ] digit { digit } ] .
char     = "'" ( character | escape ) "'" .
string   = '"' { character | escape } '"' .
escape   = "\\" ( "'" | '"' | "\\" | "n" | "r" | "t"
           | "u{" hexdigit [ hexdigit ] [ hexdigit ] [ hexdigit ] [ hexdigit ] [ hexdigit ] "}" ) .
bool     = "true" | "false" .
```

`1` is `Int`, `1.0` and `1.0e-9` are `Float`. Literals carry no sign; `-` is a prefix operator. There are no overloaded literals and no default. Integers are decimal only; the standard library parses other bases.

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

`\u{...}` denotes a Unicode scalar value, U+0000 through U+10FFFF excluding the surrogates U+D800 through U+DFFF. A `character` inside a `char` or `string` literal is any code point other than the enclosing quote, `\`, U+000A, and U+000D; a multi-line string is built with `\n` or by concatenation. Identifiers are ASCII, though source text is Unicode.

### 2.6 Operators and delimiters

```
( ) { } [ ] << >> #( , ; : = <- -> | . .. _
+ - * / % <> :: == != < <= > >= && || |>
```

Three grammar categories built from the above:

```
binop    = "*" | "/" | "%" | "+" | "-" | "<>" | "::"
         | "==" | "!=" | "<" | "<=" | ">" | ">=" | "&&" | "||"
         | "|>" .
userop   = "+" | "-" | "*" | "/" | "%" | "<>" .
literal  = int | float | char | string | bool .
```

Tokens are formed by max-munch: `>>`, `<-`, `->`, `==`, `!=`, `<=`, `>=`, `&&`, `||`, `|>`, `<>`, `::`, `#(`, `<<`, and `..` are single tokens. `|` is a delimiter of `match` clauses, sum-type constructors, and `receive` clauses, and never a `binop`.

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

Only a `userop` can be qualified, `Int.+`, or declared, `fn Distance.+` (§4.8). `::` is cons (§3.3); the comparisons, `&&`, and `||` are built in (§4.8); `|>` is a syntactic form (§5.7).

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

`FnType` and `ParenType` share the leading `(`: `->` after the closing `)` makes an `FnType`; otherwise it is a `ParenType`, which holds exactly one `Type`.

### 3.1 Base types

| Type     | Values                                     |
|----------|--------------------------------------------|
| `Int`    | integers of arbitrary precision            |
| `Float`  | IEEE 754 double precision                  |
| `Char`   | one Unicode code point                     |
| `String` | a Unicode string                           |
| `Bytes`  | a sequence of octets                       |
| `Bool`   | `true` or `false`                          |

The prelude declares `Unit`, the one-value type, §9.3; its only value is `Unit`. The empty type is `Never`, §3.7. There are no type aliases.

**Integer arithmetic.** Exact and unbounded. `/` truncates toward zero, `-7 / 3 = -2`; `%` matches, `(a / b) * b + (a % b) == a`, so `-7 % 3 = -1`. `Int.div` and `Int.mod` (§9.6) use the same convention and return `Optional(Int)` in place of the zero-divisor fault.

**Float arithmetic.** IEEE 754 binary64, round to nearest, ties to even, restricted to the finite range. An operation whose result the finite range cannot hold, overflow, division by zero of a non-zero numerator, or `0.0 / 0.0`, faults with cause `Fault("float arithmetic error")`. Gradual underflow to a subnormal or a signed zero is not a fault. There is no `Infinity` and no `NaN`, so `Float.compare`, `Float.round`, `Float.floor`, and `Float.ceil` are total.

`Int` and `Float` do not convert implicitly, and mixing them in an arithmetic expression is a type error; `Int.toFloat`, `Float.round`, `Float.floor`, and `Float.ceil` cross the boundary. `Int.toFloat` rounds to the nearest `Float`, ties to even, and faults with cause `Fault("Int out of Float range")` on a magnitude beyond the largest finite `Float`.

### 3.2 Tuples

`#(A, B)` is the type of a tuple and `#(a, b)` its value; tuples of one, two, or more components are all written this way. The tuple is the only positional product type.

### 3.3 Lists

`List(a)` is an immutable linked list. `[]` is the empty list; `x :: xs` prepends `x` to `xs`, and `::` is right-associative, so `[a, b]` is `a :: b :: []`.

### 3.4 Function types

`(A, B) -> C` is the type of a function of two arguments. Arity is part of the type: `(A, B) -> C` and `(#(A, B)) -> C` are different types. `() -> C` takes no arguments.

`with M` after the result is the mailbox type: the function uses the process it runs in, whose mailbox has type `M`, §6.1. A function type without `with M` is pure.

`with` binds to the nearest arrow: `(A) -> (B) -> C with M` is a pure function returning a function with mailbox `M`, and `(A) -> ((B) -> C) with M` a function with mailbox `M` returning a pure one. The same holds in a return annotation.

### 3.5 Sum types

Declared with `type`, §4.3. A constructor has no fields, exactly one positional field, or named fields:

```
type Optional(a) = None | Some(a)
type Snapshot = Snapshot(dir : Path, seen : Map(Path, Mtime))
```

Beyond one field, names are required. Field names are unique within a constructor, and their declaration order carries no meaning. Positional and named fields are told apart by `:` after the first identifier in a declaration and by `=` in construction and patterns. For storage, hashing, and transport, named fields are placed in *canonical order*, lexicographic ASCII order of their names; field expressions are still evaluated in source order (§5.1).

### 3.6 Abstract types

A sum type whose constructors may be mentioned only in the functions listed in the type's signature, §4.4.

### 3.7 Built-in types

`Address(m)` is an address of a process that receives `m`. `Reply(a)` is a one-shot address for the answer to a request, §6.6. `Never` is the type with no values. The prelude types are listed in section 9.

### 3.8 Foreign types

A type declared `foreign type T` has no constructors: its values are made and used only by foreign functions, §4.7, and can otherwise be held, passed, and sent. Equality on a foreign type is identity.

A foreign value is bound to the node that made it: transporting a value that transitively contains one to another node faults with cause `Fault("foreign value cannot cross nodes")`. Transport is `spawn(Peer(...), f)`, `send` to a remote address, the result of `remote(f)`, `answer(r, v)` to a caller on another node, and the captures of any shipped closure.

### 3.9 Type variables and polymorphism

Types are inferred according to Hindley-Milner. A `fn` definition and a top-level `let` are generalized over their free type variables; a `let` in a block is not. Type variables in a `fn` signature scope over the whole definition, including the annotations of lambdas within it; a variable named only in a lambda's annotation is the lambda's own and is not rigid. Recursive and mutually recursive types are allowed; polymorphic recursion is not. Every type variable in a constructor's fields is a parameter of the type.

**Effect polymorphism.** The mailbox effect of a function type may be a type variable, generalized with the others: `fn apply(f, x) = f(x)` has type `((a) -> b with e, a) -> b with e`. At a call site an effect variable binds to a mailbox type, which the caller inherits, or to pure, the absence of `with`. Pure is not a type. A variable that occurs only in effect positions, after `with`, ranges over the mailbox types and pure; a variable that also occurs in a value position, an argument, a result, a tuple component, or a type argument, ranges over types alone, so `m` in `self : () -> Address(m) with m` is never pure. This is the only departure from Hindley-Milner. The process primitives of §9.4 and §9.5 and every `foreign fn` declared `with M` are *process-only*: their effect variable is treated as if it occurred in a value position, and pure code cannot call them. A printed type elides an effect variable bound to pure.

A function has one mailbox effect or none. Two callbacks with independent effects are declared so: in `fn callBoth(p : (Int) -> Int, e : (Int) -> Unit with n) -> Unit with n`, `p` is pure and the function inherits `n`. Two callbacks with polymorphic effects unify to one; two with different concrete effects are a type error.

**Inferred restrictions.** An annotation gives a function's shape: arity, argument types, result, mailbox effect. Three restrictions are inferred from the body, are part of the type scheme, travel with the function value through bindings, branches, and compiled interfaces, and are shown by the compiler (§11.5), never written: the equality constraint of §3.10 on a variable compared with `==`; process-only, inherited by a function whose body calls a process primitive; and not-reply-carrying (§6.6) on a parameter the function duplicates or discards, so that `fn dup(x) = #(x, x)` cannot take a reply and `fn id(x) = x` can. Each is checked at instantiation, not at definition. This is the one exception to principle 3.

### 3.10 Equality and ordering

`==` and `!=` are structural and defined for all values except those containing functions or addresses, on which they are a type error. Ordering is per type through `compare` in the type's namespace, `Int.compare : (Int, Int) -> Ordering`: `a < b` is `T.compare(a, b) == Less` for the operand type `T`, and `<=`, `>`, `>=` likewise; a type without `compare` has no ordering, and `<` on it is a type error. The prelude defines `compare` for `Int`, `Float`, `String`, and `Char` (§9.6).

A function that applies `==` to a value of a type variable gives that variable an *equality constraint*, inferred and never written; instantiating it with a type that contains a function or an address is a type error at that call site. `Map(k, v)` and `Set(a)` carry the constraint on `k` and `a`, rejected at the first operation, and a standard library function that compares elements, `List.contains`, propagates it through its parameter. The constraint is part of the type scheme (§3.9): `let f = equal` carries it, `if flag then equal else always` carries the union of the branches', and a compiled interface carries it across modules; the check is always at the concrete application.

### 3.11 Serialization

All values can be sent in messages, functions included; their code travels with them, section 10.

## 4. Declarations and Scope

```
Program     = { Declaration } .
Declaration = [ "export" ] ( TypeDecl | AbstractDecl | FnDecl | LetDecl | ForeignDecl ) .
ForeignDecl = "foreign" ( "type" typename [ "(" typevar { "," typevar } ")" ]
            | "fn" DeclName "(" [ ForeignParam { "," ForeignParam } ] ")" Return "=" string ) .
ForeignParam = ident ":" Type .
TypeDecl    = "type" typename [ "(" typevar { "," typevar } ")" ] "="
              Constructor { "|" Constructor } .
Constructor = conname [ "(" ( Type | Field { "," Field } ) ")" ] .
Field       = ident ":" Type .
AbstractDecl  = "abstract" TypeDecl "with" "{" Signature { ";" Signature } "}" .
Signature   = ( ident | userop ) ":" Type .
FnDecl      = "fn" DeclName "(" [ Param { "," Param } ] ")" [ Return ] "=" Expr .
Param       = Pattern [ ":" Type ] .
Return      = "->" Type [ "with" Type ] .
LetDecl     = "let" DeclName [ ":" Type ] "=" Expr .
Binding     = "let" Pattern [ ":" Type ] ( "=" | "<-" ) Expr .
DeclName    = ident | typename "." ( ident | userop ) .
```

### 4.1 Modules

A *module* is one source file, ending in `.ern`: the unit of compilation and of namespace. Every top-level declaration belongs to exactly one module.

### 4.2 Namespaces and visibility

**Files are namespaces.** A file at `a/b/c.ern` under the source root provides the namespace `A.B.C`, each segment the path segment with its first letter uppercased: `http.ern` is `Http`, `httpv2.ern` is `Httpv2`. Path segments are one lowercase word (§11.1), so the mapping is one-to-one. The top of the hierarchy, where the prelude lives, is the runtime's.

**Declarations are local; `export` marks the boundary.** A declaration is written with its local name. `fn parse` in `net/http.ern` is exported as `Net.Http.parse` when marked `export`, and is otherwise private to its module; the qualified name appears at use sites, never at declarations. Two exported declarations with the same qualified name are an error. A module namespace may not coincide with a prelude namespace: `io.ern` at the source root is an error. There is no export list and no `import`.

```
// net/http.ern
export type Request = Request(method : String, path : String)
export fn parse(s : String) -> Optional(Request) = ...
fn helper(x) = ...        // private to net/http.ern
```

**Type members.** A type `T` declared in a module, concrete or abstract, is a nested namespace. Its members are declared with the single prefix `T.`, `fn Distance.+`, `let Stack.empty`, and exported at `Module.T.member`. The namespace belongs to the file that declares the type: `main/stack.ern` cannot add members to the `Main.Stack` declared in `main.ern`, and a declaration that tries is a duplicate export. Type names that differ only in case are permitted. For an abstract type, only the definitions in its signature may name the constructor (§4.4).

**Unqualified lookup.** An unqualified name in a body is looked up in the module's declarations, exported or not, then in the type-member namespace of the enclosing declaration, then in the prelude; any other name is written qualified. A module may declare a type or constructor with a prelude name, and the name then means the local one throughout the module. Within a module, type names are unique and constructor names are unique across its types.

### 4.3 Type declarations

`type` declares a sum type with its constructors. A constructor has the visibility of its type.

### 4.4 Abstract types

`abstract type T = ... with { s1; s2 }` declares a type whose constructor may appear only in the definitions of the names in its signature. Each such definition is declared as a member, `fn Stack.push`, checked against its signature, and exported or private on its own; a definition not in the signature cannot mention the constructor. The members of a concrete type (§4.2) carry no such restriction.

```
// main.ern  (namespace Main)
export abstract type Stack(a) = Stack(List(a)) with {
    empty : Stack(a);
    push : (a, Stack(a)) -> Stack(a);
    pop : (Stack(a)) -> Optional(#(a, Stack(a)))
}

export let Stack.empty = Stack([])
export fn Stack.push(x, Stack(xs)) = Stack(x :: xs)
export fn Stack.pop(Stack(xs)) = match xs { [] -> None | x :: rest -> Some(#(x, Stack(rest))) }
```

External callers see `Main.Stack` and `Main.Stack.push`. A module may declare several abstract types.

### 4.5 Functions

`fn` declares a function of fixed arity. Annotations may be omitted where they can be inferred. The return annotation is omitted, `-> T` for a pure function, or `-> T with M` for process code; a pure annotation on a function that calls process code is a type error.

A function has one clause. Patterns in parameters are irrefutable, §5.10: `fn seenCount(Snapshot(seen = entries) : Snapshot) -> Int = Map.size(entries)`.

`fn` may appear at top level and as a statement in a block; it sees its own name, and `fn` declarations in the same block or at top level may refer to each other. A type-member name, `fn T.f`, is a top-level form; in a block it is an error.

### 4.6 Bindings

In a block, `let p = e` binds the irrefutable pattern `p` to the value of `e`; `let p <- e` is §5.5. A binding is monomorphic and does not see its own name. A later binding of the same name shadows the earlier one from the next statement on, and its right-hand side sees the earlier one.

A block binding's type may hold unresolved variables, from `[]`, `None`, `Map.empty`, or a call that returns a polymorphic value. Each is resolved by a later use of the binding in the block, by reaching the block's result and being generalized by the enclosing `fn` or top-level `let`, or by an annotation on the binding; a variable none of these resolves is a type error at the binding. `let _ = e` binds nothing and resolves nothing. A type parameter of an enclosing scope is not unresolved.

At top level, `let` binds a `DeclName`, an `ident` optionally prefixed with a type of the same module (§4.2), and generalizes its free type variables: `let Stack.empty : Stack(a) = Stack([])`. The left side is a name, not a pattern, and `<-` is a block form only. The initializer is pure; effectful setup belongs in `main`. The runtime evaluates top-level bindings in dependency order before `main` runs (§8.5).

### 4.7 Foreign declarations

`foreign type T` declares a type implemented outside the language.

`foreign fn f(params) -> T = "impl"` declares a function whose body is the implementation named by the string, in the runtime's language; parameters and the result are annotated. A foreign function with a mailbox type may do anything; one without promises purity, the same result for the same arguments and no effect on anything. The implementation promises the declared types: a value of another shape, or an exception, is a fault, section 7. Foreign code sees values in the runtime's representation, §8.4. Both declarations take `export` (§4.2).

### 4.8 Operators

The arithmetic operators and `<>` resolve against the operand type: `+` in `a + b` with `a : Int` is `Int.+`, and with `a : Distance` is `Distance.+`, declared in the type's module as `export fn Distance.+(Distance(a), Distance(b)) -> Distance = Distance(a + b)`. Both operands have the same type; there is no numeric type to generalize over. Resolution precedes generalization: an operand whose type comes from no annotation, literal, pattern, or call in the same definition is a type error that asks for an annotation.

`==`, `!=`, `<`, `<=`, `>`, `>=`, `&&`, and `||` cannot be defined per type: equality is structural and ordering goes through `compare` (§3.10); `&&` and `||` short-circuit on `Bool`. `::` is cons (§3.3); `|>` is a syntactic form (§5.7).

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
          | "bits" | "bytes" | "int" | "float"
          | "utf8" | "utf16" | "utf32"
          | "big" | "little" | "native"
          | "signed" | "unsigned" .
FieldPats = [ ident "=" Pattern { "," ident "=" Pattern } ] .
```

`fn`, `if`, `match`, and `receive` are not operands: `1 + if c then a else b` is a syntax error; write `1 + (if c then a else b)`.

### 5.1 Evaluation

Strict, left to right, arguments before the call. Nothing is delayed; `fn() = e` defers `e`. Prefix `-` is `negate` in the operand type's namespace: `Int.negate`, `Float.negate`, or `T.negate` declared as §4.8 declares `T.+`.

### 5.2 Calls

`f(x, y)` supplies all arguments. A call with the wrong number of arguments is a type error at the call; a call never yields a partially applied function. An expression whose value is a function can be called directly, `makeAdder(3)(4)`.

### 5.3 Lambda

`fn(x) = e` is an anonymous function. Its body is the longest `Expr` at the same nesting level, ending at the first delimiter of the enclosing form: `,`, `;`, `|`, `)`, `}`, `]`, or `>>`.

### 5.4 Blocks

`{ s1; s2; e }` is an expression whose value is its last statement, which is an expression. `;` separates statements and never appears last. A statement is a `fn` declaration, a `let` binding, or an expression evaluated for its effect.

A `fn` declared in a block is visible throughout it, so local functions may be recursive and mutually recursive; its body sees the bindings in force at its declaration. `let` bindings are sequential: a `fn` body that references a `let` declared later in the block is a compile-time error, and a local `fn` may be used, called, taken as a value, passed, stored, returned, or captured, only after every `let` it references, directly or through other local functions, has been evaluated.

### 5.5 Binding with `<-`

In a block, `let p <- e; rest` matches `e`: on `Right(v)`, `p` is bound to `v` and `rest` is evaluated; on `Left(err)`, the block's value is `Left(err)`. With `Optional`, `Some` and `None` apply the same way.

The sum type is decided after inference of the enclosing definition, from the type of `e` or else from the block's type; `rest` has the block's type, and all `<-` bindings in one block resolve to the same sum type.

### 5.6 Construction

`Some(e)`, `None`, `Snapshot(dir = d, seen = s)`. All fields are given. `Snapshot(..p, seen = s)` takes the unlisted fields from `p`; at least one field follows `..`. A constructor is qualified like a function, `Net.Http.Request(...)`.

A nullary constructor is a value and a single-positional constructor a function value; a named constructor is neither and appears only in construction syntax. A qualified operator is a function value, `Int.+`.

### 5.7 Pipe

`x |> e` applies `e`, a function value or a call, with `x` inserted as the first argument: `x |> f` is `f(x)`, `x |> f(a, b)` is `f(x, a, b)`.

```
let words = input |> String.trim |> String.toLower |> String.toList
```

`|>` is left-associative and binds loosest, below `||`: `a + b |> f` is `f(a + b)`, `a |> b |> c` is `c(b(a))`. The right-hand side is a name, a qualified name, a parenthesized lambda, or a call whose first-argument slot the pipe fills; a lambda must be parenthesized, `x |> (fn(y) = y + 1)`. In a chained call the pipe fills the outermost call: `x |> f(a)(b)` is `f(a)(x, b)`, and `x |> (f(a))` is `f(x, a)`. The type of `x` is the target's first parameter type.

### 5.8 Conditional

`if c then a else b` with `c : Bool`; the branches have the same type.

### 5.9 `match`

The value is matched against the clauses' patterns in order; the first clause whose pattern matches and whose guard holds is evaluated. The clauses together cover the type; guards do not count as coverage. A guard is a `Bool` expression with no mailbox effect that sees the pattern's variables and the enclosing scope. A guard that is `false` falls through to the next clause; a guard that faults faults the process. The same holds for `receive`.

### 5.10 Patterns

A pattern decomposes a value and binds its parts; the same patterns appear in `let`, in `match` and `receive` clauses, and in parameters.

`_` matches anything and binds nothing. An identifier binds the whole value at its position to a new variable, shadowing any outer one; it never refers to an existing variable. A literal matches itself, and a numeric literal may carry `-`: `match n { -1 -> "minus one" | _ -> "other" }`. A constructor pattern, `Some(p)` or `Snapshot(seen = s)` with fields omitted, a tuple `#(p, q)`, a list `[p, q]`, and `p :: q` decompose those, to any depth. `p as c` binds `c` to the whole value `p` matches, and binds loosest, so `x :: rest as all` names the whole list.

Each variable appears at most once in a pattern; equality is written in a guard. A pattern is *irrefutable* if it cannot fail: `_`, an identifier, a tuple of irrefutable patterns, or a constructor pattern of a type with one constructor whose sub-patterns are irrefutable. `let` and parameters require irrefutable patterns; `let Right(x) = e` is a type error.

### 5.11 Bitstrings

`<<...>>` constructs and matches a `Bytes` value at the bit level: segments between `<<` and `>>`, separated by commas, each a value or a pattern followed by an optional colon and a dash-separated list of specifiers.

| Specifier                   | Meaning                                                     |
|-----------------------------|-------------------------------------------------------------|
| `size(N)`                   | segment width, in units                                     |
| `unit(N)`                   | bits per size unit (default 1)                              |
| `bits`                      | segment is a nested `Bytes` value; unit is 1 bit            |
| `bytes`                     | segment is a nested byte-aligned `Bytes` value; unit is 8 bits |
| `int`, `float`              | numeric segment (defaults: 8-bit, 64-bit)                   |
| `utf8`, `utf16`, `utf32`    | text encoding                                               |
| `big`, `little`, `native`   | endianness                                                  |
| `signed`, `unsigned`        | sign                                                        |

A segment without specifiers is `int` of size 8. `int` binds to `Int`, `float` to `Float`, the `utf` forms to `Char`, `bits` and `bytes` to `Bytes`. The specifier names are ordinary identifiers outside a bitstring.

A construction's total bit count is a multiple of 8, and a `bits` or `bytes` segment bound to `Bytes` has a byte-multiple size; sub-octet fields are `int`. A violation that is constant is a compile-time error; one with a dynamic size faults at construction (§7.4) or fails to match. `size(Expr)` in a pattern is evaluated in the scope of the earlier segments and the enclosing scope; it is pure and yields a non-negative `Int`, a negative or out-of-range size fails the match, and a fault in it faults the process. Construction evaluates the segments left to right; a value that does not fit its width is a fault. `<<>>` is the empty `Bytes`.

```
fn frame(len : Int, body : Bytes) -> Bytes =
    <<len:size(16)-big, body:bytes>>

fn parseFrame(bytes : Bytes) -> Optional(#(Int, Bytes, Bytes)) = match bytes {
    <<len:size(16)-big, body:size(len)-bytes, rest:bytes>> -> Some(#(len, body, rest))
  | _ -> None
}
```

Bitstrings compile to the runtime's bit syntax, section 10.

## 6. Processes

A process is an execution of a function with a mailbox type. It has a mailbox that receives values of that type, in arrival order per sender.

### 6.1 The mailbox type

`(A) -> B with M` is the type of a function that acts through the process it runs in, whose mailbox has type `M`: it uses that process's `send`, `receive`, or `self`, or calls a foreign function with a mailbox type. Running in a process is not marked; every function does.

The effect is inferred. A function that calls a function with effect `M` has effect `M`; two calls with different concrete effects in one body are a type error; calls with variable effects unify; a pure call contributes nothing, and a function none of whose calls determines an effect is pure.

| Written | Meaning |
|---|---|
| `(A) -> B` | pure; callable from any process |
| `(A) -> B with M` | uses its process; callable only where the mailbox type is `M` |
| `(A) -> B with m`, `m` a variable | uses its process; `m` takes the caller's mailbox type |

A pure higher-order function runs its function arguments in the caller's process and is effect-polymorphic (§3.9): `List.map(xs, fn(x) = send(a, x))` has the callback's effect. Nothing else is marked on a function type.

### 6.2 Built-in functions

```
self  : () -> Address(m) with m
send  : (Address(a), a) -> Unit with m
spawn : (Where, () -> Unit with n) -> Address(n) with m

type Where = Local | Peer(String)
```

`self()` is the process's own address. `send(a, v)` places `v` in the mailbox of `a` and returns at once; sending to a dead process has no effect.

`spawn(w, f)` starts a process that runs `f()` and returns its address; `self()` inside `f` is the new process's address. The callback's mailbox effect `n` also appears in `Address(n)`, so it is a real mailbox type (§3.9); a process that never receives is spawned with `fn() -> Unit with Never = ...`. `w` places the process, `Local` on the running node or `Peer(name)` on the peer of that name, §8.3; an unknown or unreachable peer is a fault, and the captures of `f` are copied to the peer.

### 6.3 `receive`

`receive { clauses }` matches the mailbox in arrival order: the first message that matches a clause is removed and the clause evaluated, the rest remain, and if none matches the process waits. Patterns are typed against the mailbox type. Coverage is not required: a message no clause matches stays in the mailbox.

A final clause `after t -> e` gives a limit of `t` milliseconds, evaluated on entry, after which `e` is evaluated; `after 0` does not wait. Without `after` there is no limit.

### 6.4 Message ordering

Messages from one process to another are received in sending order. Between different senders there is no ordering.

### 6.5 Addresses

`Address(m)` identifies a process on a node and carries its protocol: `send(a, v)` is type-checked against `m`, on every node alike. `via(f, addr)`, §9.5, is `addr` seen through `f : (a) -> b`: sending `v` to `via(f, addr)` sends `f(v)` to `addr`.

Addresses have no equality; identity is expressed in the protocol. There is no registry: a process reaches another only through an address it holds or received, and possession of the address is the permission to send.

### 6.6 Request-reply

A `Reply(a)` is a one-shot address for the answer to a request, answered exactly once. It is *linear*: a value of `Reply(a)`, or of any type containing one, is consumed exactly once.

```
Address.call        : (Address(m), (Reply(a)) -> m, Int) -> Optional(a) with n
Address.callForever : (Address(m), (Reply(a)) -> m) -> a with n
answer              : (Reply(a), a) -> Unit with m
```

`Address.call(addr, mk, ms)` allocates a fresh `Reply(a)`, sends `mk(r)` to `addr`, and returns `Some(v)` when the recipient answers or `None` after `ms` milliseconds; the clock starts at the call, and a reply that arrives together with the timeout may be delivered or discarded. `Address.callForever(addr, mk)` waits without limit and returns `a`. `answer(r, v)` sends `v` to the caller. A reply travels by an identifier private to the call, never through the caller's mailbox; a late answer, after a timeout or the caller's death, and a second answer to a `Reply` already answered are discarded silently, and the recipient cannot observe whether the caller still waits.

A type is *reply-carrying* if it is `Reply(a)` or has a constructor field or tuple component of a reply-carrying type, transitively and by type, not by constructor: every value of `type PongMsg = Ping(n : Int, reply : Reply(Int)) | Stop` is reply-carrying, `Stop` included. A declared type is reply-carrying at an instantiation whose argument is; a built-in type never is through its arguments, so `Address(PongMsg)` is not.

A reply-carrying value may appear as a constructor field, a tuple component, a function parameter, a variable bound in a `receive` clause, a capture of a lambda passed directly to `spawn`, or the result of a function whose declared result type is reply-carrying. Anywhere else, as an element of `List`, `Map`, `Set`, `Optional`, or `Either`, or as an operand of `==`, it is a type error, and so is `as` on a reply-carrying scrutinee. A pattern on a reply-carrying value binds every reply-carrying field; `_` or an omitted field there is a type error. The match consumes the scrutinee and transfers the obligation to the variables it binds, or discharges it when the constructor has no reply-carrying field.

Every binding of a reply-carrying value, a parameter, a `receive` variable, a `spawn` capture, a pattern variable, a `let`, or the result of a call, is an obligation: on every path from it the value is consumed exactly once. Consumption is `answer`, the only primitive that discharges a `Reply`; passing the value to a function whose parameter is reply-carrying at that instantiation, which delegates to the callee and is rejected when the callee duplicates or discards it (§3.9); `send`, which shifts the obligation to the `receive` clause that binds the value; placing it in a constructor field or tuple component of reply-carrying type, so that the built value carries the obligation; returning it from a function whose result type is reply-carrying, which shifts it to the caller; or capturing it in a lambda passed directly to `spawn`. An `if`, `match`, `receive`, or block whose value is reply-carrying consumes or passes it on in every branch. A reply-carrying value neither bound nor consumed is a type error.

The check is per function and crosses no call boundary. It is static in flow: every path calls the consumption, whether or not execution reaches it. `fn twice(dst : Address(Request), request : Request) = { send(dst, request); send(dst, request) }` is rejected, `request` being consumed by the first `send`; `match req { Get() -> ... }` on `Get(reply : Reply(Int))` is rejected, the omitted field dropping a reply.

### 6.7 Remote computation

```
remote         : (() -> a) -> Either(RemoteError, a) with m
parallelRemote : (List(() -> a)) -> List(Either(RemoteError, a)) with m
type RemoteError = NoRemotePeer | PeerLost
```

`remote(f)` evaluates the pure function `f` on a peer the runtime chooses among those configured for remote computation and returns its value: `Left(NoRemotePeer)` when no such peer is configured, `Left(PeerLost)` when the peer is lost before the value returns or resolution on the peer fails (§8.7). Effectful work on a peer goes through `spawn(Peer(...), ...)`. `parallelRemote(fs)` runs the functions on peers in parallel and returns their results in input order, one `Either` each. Both carry a mailbox effect and are called from process code only.

### 6.8 `Never`

A function with mailbox type `Never` can send but never receive: a `receive` with a pattern clause is a type error, and a `receive` with only an `after` clause is how a `Never` process waits.

`with Never` annotates a process root that never receives, `main` or the function a spawn lambda calls. It can only be called where the mailbox is `Never`, so a send-only helper called from process code is polymorphic instead, `with m`, as `Io.println` in Appendix E.

### 6.9 Death

A process dies when its function returns, when `kill` is called on it, on a fault, section 7, or when its node is lost. `kill` is asynchronous: the target may run until the runtime interrupts it. `monitor(a, wrap)`, §9.5, places `wrap(d)` in the caller's mailbox when `a` dies, `d : Down` giving the cause; a process already dead is reported at once, the runtime remembering how every process it started ended, and each `monitor` call produces one message. `function` in `Down` is the qualified name of the function that called `spawn` for the dead process with the line of the call, `Counter.main:19`, and the entry point's name for the entry process. There are no other links.

### 6.10 Code replacement

A process replaces its code by a message in its own type that carries the new loop, and switches with a tail call:

```
type CounterMsg
    = Inc(Int)
    | Get(reply : Reply(Int))
    | Upgrade(migrate : (Int) -> Int, next : (Int) -> Unit with CounterMsg)

fn counter(n : Int) -> Unit with CounterMsg = receive {
    Inc(k) -> counter(n + k)
  | Get(reply = r) -> { answer(r, n); counter(n) }
  | Upgrade(migrate = m, next = k) -> k(m(n))
}
```

The language has no other mechanism for code replacement.

## 7. Errors

There are no exceptions. An error is a value, a message, or a fault.

### 7.1 Value errors

The error is part of the function's meaning and is in its result type, `Either(e, a)` or `Optional(a)`. The caller matches on the result or chains with `let p <- e` (§5.5).

### 7.2 Message errors

The error crosses a process boundary and is in the message: `Either`, or a constructor of the reply type. A missing reply is `after` in `receive` (§6.3). The error type across the boundary is its own, distinct from the function's.

### 7.3 Faults

The code cannot see the error: out of memory, `kill`, a failure in the runtime, a broken promise by foreign code. The process dies with a structured cause in `Down` (§6.9). Nothing is caught. A fault is any death whose `Reason` is not `Returned`; `Fault(String)` is one `Reason` beside `Killed` and `ProgramEnd`.

### 7.4 Prelude operations and faults

Partial operations in the prelude return `Optional` or `Either`. These fault, with the cause given; a missing mailbox effect does not mean a missing fault.

- `/` and `%` on `Int` with a zero divisor: `Fault("division by zero")`.
- `Float` arithmetic whose result the finite range cannot hold (§3.1): `Fault("float arithmetic error")`. `Int.toFloat` beyond the largest finite `Float`: `Fault("Int out of Float range")`.
- Bitstring construction (§5.11): a value that does not fit its width, `Fault("segment overflow")`; a dynamic size not a multiple of 8 where `Bytes` is bound, `Fault("bitstring not byte-aligned")`.
- `todo("...")`, which compiles at any type: `Fault("todo: ...")`.
- Cross-node transport of a foreign value (§3.8): `Fault("foreign value cannot cross nodes")`.
- `spawn(Peer(...), ...)` with an unknown or unreachable peer, `Fault("peer unreachable")`, or with a resolution failure on the peer (§8.7), `Fault("peer resolution failed: ...")`. `send` to a remote address faults the sender with the same cause asynchronously, after its return, when resolution fails.
- A foreign return or a message from a foreign process that does not match the declared type faults the receiving Ernest process on first observation (§8.4).

## 8. Programs

### 8.1 `main`

The entry point is a `fn () -> Unit with m`. `m` is `Never` when the entry only spawns and sends, a message type when it receives, and polymorphic when it uses `Address.call` without a protocol of its own; a polymorphic `m` is instantiated to `Never` by the runtime. `ern module.erc` runs the `export fn main` of that module; `ern --main Qualified.name module.erc` runs another exported function of that shape. `main` is a convention, not a reserved name.

### 8.2 System references

The runtime starts its system processes and binds their addresses to top-level values in the `Sys` namespace, §9.7. A program uses each through the standard library module of its name, Appendix E; the address and its message type are declared for that module and for a foreign process that speaks it (§8.4). A runtime may provide more; a program that needs one names it in its assumptions. The values are in scope everywhere, and since `send` requires a mailbox effect (§6.1), pure code can name an address and not use it. A `Sys.*` name the runtime does not provide is a name-resolution error.

`stdout` writes each received `String` to standard output as bytes; newlines are the sender's. `stdin` answers each `ReadLine` with the next line without its line feed, `None` at end of input. `keys` sends every key pressed to each subscriber; it and `stdin` are the same terminal, and a program subscribes to keys or reads lines, not both. `fs` and `tcp` answer as their message types say.

### 8.3 Peers

Peers are configured outside the language, §11.3; `Peer(name)` refers to them by the configured name, and nodes authenticate each other.

### 8.4 Foreign code

The system processes are foreign processes: their message types are declared in Ernest, their implementations live outside the language, and the runtime starts them and binds their addresses. Other foreign code enters through `foreign fn` and `foreign type`, §4.7. Both boundaries carry the same promise: the foreign side delivers the declared types, and a breach faults the receiving Ernest process on first observation.

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

Same-named constructors of different types share an atom; the receiver's declared type disambiguates. Cross-node transport uses the runtime's external term format for these representations.

### 8.5 Initialization

Before `main` runs, the runtime evaluates every top-level `let` in dependency order: a binding that references another, directly or through the functions it calls, is evaluated after it; the order within an independent set is unspecified; a cycle is a compile-time error. Only `let` requires evaluation, and the `Sys.*` references are bound first. An initializer that faults ends the program with that fault before `main`; which of two independent faulting initializers is reported is unspecified, and one that does not terminate prevents the rest.

### 8.6 Program termination

The program ends when `main` returns or faults, a fault being reported on the runtime's exit indicator. Live local processes then die with cause `ProgramEnd`, and the runtime flushes the system processes' pending output before it stops. Workers spawned on peers are unaffected and follow their own return, `kill`, or peer loss (§10); peers observe the ending node as lost. A program that is to keep running waits in `main`.

When no forward progress is possible, every live process waiting in `receive` without `after`, no message in flight, and no system process or connected peer holding a timer, subscription, pending I/O, or computation whose completion would deliver a message, the runtime ends the program with the error `Deadlock`. Detection is per node, and whether a user-provided foreign process counts as such a source is the runtime's choice.

### 8.7 Code shipping

`spawn(Peer(name), f)`, `remote(f)`, and `send` to a remote address ship the closure or payload and the code it depends on; within a node nothing is shipped.

**Content addressing.** Every function, constructor, and type is identified across nodes by a hash of its normalized definition together with the hashes of what it references; structurally identical definitions have the same hash on every node, and any change to a definition changes its hash and, transitively, its dependents'. A set of mutually recursive definitions is hashed as a group, internal references by position, and each member's identity derives from the group's hash. Normalization renames local variables, orders named fields canonically (§3.5), preserves the source evaluation order of construction expressions, and preserves the qualified names of external references.

**Resolution.** Before a shipped closure runs, the peer resolves every hash it carries, transitively, from its own store or by fetching from the sender, and caches what it fetched. A failure, a missing dependency, a missing `Sys.x`, an incompatible foreign definition, or a fault in `remote`'s callback, is `Left(PeerLost)` for `remote`, a fault of the caller for `spawn(Peer, ...)`, and an asynchronous fault of the sender for `send`. `Left(PeerLost)` from one operation does not invalidate other addresses on that peer; only the loss of the peer does (§10).

**Identity.** Types are identified by hash: two nodes with structurally identical declarations interoperate, two with different declarations under one name hold distinct types, and a shipped closure uses the sender's hashes on the peer. An abstract type's hash includes its qualified name and its signature, so two abstract types with the same representation are distinct unless both match.

**Bindings.** A `Sys.*` name in shipped code resolves on the peer that runs it; a captured address ships as the value it is. A top-level binding referenced by shipped code is evaluated on the peer, in the peer's environment, at most once per node per code version. Foreign declarations are not shipped: a shipped closure that references one requires a compatible definition under the same qualified name on the peer, and a missing or incompatible one is a fault at resolution.

## 9. Prelude

The prelude is what this report names; everything else, the container, string, and numeric operations and the output helpers, is the standard library, Appendix E. A prelude operation in a type's namespace, `Int.compare`, is provided by that type's standard library module.

### 9.1 Built-in types (section 3)

```
Address(m) // an address of a process that receives m
Reply(a) // a one-shot address, section 6
Never // the type with no values
Foreign // a value the language does not inspect, section 4
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
type Unit = Unit // the one-value type; carries no information
type Optional(a) = None | Some(a)
type Either(e, a) = Left(e) | Right(a)
type Ordering = Less | Equal | Greater
type Down = Down(reason : Reason, function : String)
type Reason = Returned | Killed | ProgramEnd | Fault(String)
type ClockMsg // times in milliseconds
    = After(ms : Int, to : Address(Unit))
    | At(at : Int, to : Address(Unit))
    | Now(reply : Reply(Int))
type RemoteError = NoRemotePeer | PeerLost
type Where = Local | Peer(String) // spawn placement, section 6
type Key = Char(Char) | ArrowUp | ArrowDown | ArrowLeft | ArrowRight | Enter | Escape
type KeyMsg = Subscribe(Address(Key))
type StdinMsg = ReadLine(reply : Reply(Optional(String)))
type Path = Path(String) // in the runtime's syntax
type Entry = Entry(path : Path, mtime : Int, size : Int, isDir : Bool) // mtime in milliseconds since the epoch, as Clock.now; size in bytes
type IoError = NotFound | Denied | Refused | Closed | Timeout | Other(String)
type FsMsg
    = ReadFile(path : Path, reply : Reply(Either(IoError, Bytes)))
    | WriteFile(path : Path, bytes : Bytes, reply : Reply(Either(IoError, Unit)))
    | AppendFile(path : Path, bytes : Bytes, reply : Reply(Either(IoError, Unit)))
    | ListDir(path : Path, reply : Reply(Either(IoError, List(Entry))))
    | Stat(path : Path, reply : Reply(Either(IoError, Entry)))
    | MakeDir(path : Path, reply : Reply(Either(IoError, Unit)))
    | Remove(path : Path, reply : Reply(Either(IoError, Unit)))
    | Rename(from : Path, to : Path, reply : Reply(Either(IoError, Unit)))
    | Copy(from : Path, to : Path, reply : Reply(Either(IoError, Unit)))
type TcpMsg
    = Listen(port : Int, reply : Reply(Either(IoError, Address(ListenerMsg))))
    | Connect(host : String, port : Int, reply : Reply(Either(IoError, Address(SockMsg))))
type ListenerMsg = Accept(reply : Reply(Either(IoError, Address(SockMsg))))
type SockMsg = Recv(reply : Reply(Either(IoError, Bytes))) | Send(Bytes) | Close
```

### 9.4 Built-in functions (section 6)

```
self  : () -> Address(m) with m
send  : (Address(a), a) -> Unit with m
spawn : (Where, () -> Unit with n) -> Address(n) with m
```

### 9.5 Process functions

```
via                 : ((a) -> b, Address(b)) -> Address(a)
Address.call        : (Address(m), (Reply(a)) -> m, Int) -> Optional(a) with n
Address.callForever : (Address(m), (Reply(a)) -> m) -> a with n
answer              : (Reply(a), a) -> Unit with m
remote              : (() -> a) -> Either(RemoteError, a) with m
parallelRemote      : (List(() -> a)) -> List(Either(RemoteError, a)) with m
monitor             : (Address(a), (Down) -> m) -> Unit with m
kill                : (Address(a)) -> Unit with m
```

### 9.6 Operations required by the language

```
Int.+, Int.-, Int.*, Int./, Int.% : (Int, Int) -> Int // section 4
Int.negate : (Int) -> Int // section 5: prefix -
Float.+, Float.-, Float.*, Float./ : (Float, Float) -> Float
Float.negate : (Float) -> Float
String.<> : (String, String) -> String // section 4: <> resolves per type
List.<> : (List(a), List(a)) -> List(a)
Bytes.<> : (Bytes, Bytes) -> Bytes
Int.div, Int.mod : (Int, Int) -> Optional(Int) // section 7: / and % fault on zero; these do not
Int.compare : (Int, Int) -> Ordering // section 3: ordering is per type
Float.compare : (Float, Float) -> Ordering
String.compare : (String, String) -> Ordering
Char.compare : (Char, Char) -> Ordering
todo : (String) -> a // section 7: faults if reached
```

### 9.7 System references

Runtime-provided, section 8:

```
Sys.stdout : Address(String)
Sys.stdin : Address(StdinMsg)
Sys.keys : Address(KeyMsg)
Sys.clock : Address(ClockMsg)
Sys.fs : Address(FsMsg)
Sys.tcp : Address(TcpMsg)
```

Each is used through the standard library module of its name, Appendix E.

## 10. Runtime Requirements

- Tail calls take constant stack space. The last expression of a block, a `match` clause, and a `receive` clause is in tail position.
- Processes are scheduled preemptively; a process cannot prevent others from running.
- Processes share no memory; a message is a copy or immutable.
- Mailboxes are unbounded; a program is responsible for its own backpressure.
- `Int` has arbitrary precision.
- The representation of values is fixed and documented, so that foreign code can produce and consume them.
- `Down` carries a cause distinguishable from other causes.
- The runtime detects `Deadlock` as in section 8.
- A node ships code to a peer that lacks it, identified by content, so that `spawn` on a peer and `remote` need no prior installation; dependencies resolve by hash before a shipped closure runs, types are content-addressed, `Sys.*` re-binds to the peer, and foreign code is per node, §8.7.
- The runtime detects the loss of a peer: every process on it is treated as dead with cause `Fault("peer lost")`, monitors deliver (§6.9), and pending `remote` calls return `Left(PeerLost)`. Loss is terminal: a peer that reappears under the same name is a new instance, and addresses held before the loss are unrelated to it. `send` to a peer is best-effort; messages in flight at the loss are dropped without notice.

## 11. Toolchain

Options are long: `--name`, or `--name value` for one that takes a value.

### 11.1 `ernc` (compiler)

`ernc [--source-root src-root] [--out-dir build-dir] file.ern` compiles a module to `file.erc`, a compiled module carrying the inferred types of its exported declarations, against which dependent modules are checked. `ernc [--source-root src-root] [--out-dir build-dir] src-dir` compiles every `.ern` under `src-dir` in dependency order, mirroring the source tree into `build-dir` and creating directories as needed. The module dependency graph is acyclic; a cycle is a compile-time error naming the modules in it. A module is recompiled when its source has changed or when the interface of a module it depends on has changed; a change confined to a dependency's bodies does not recompile its dependents. Cross-module references link at load, against `.erc` files under `build-dir` and the `--load-path` roots. `--emit erl` writes the module's Erlang source as `.erl` instead, for reading; it carries no interface.

**Source root.** Each file's namespace comes from its path under the source root (§4.2). `--source-root` names it; otherwise single-file mode uses the current directory and directory mode the directory given. Output mirrors the source root, not the directory argument: `ernc --source-root src --out-dir build src/net` writes `src/net/http.ern` to `build/net/http.erc`. `build-dir` defaults to the source root.

**Path shape.** Each `.ern` file compiled, and each directory between it and the source root, is one word: a lowercase letter followed by lowercase letters and digits. A multi-word module is a nested directory, `http/parser.ern` for `Http.Parser`. Extensions are `.ern` and `.erc`. A path that breaks the rule is an error, `path component Net must be lowercase`; the root itself and files that are not modules are not checked.

**Cleanup.** After a directory-mode compilation, `ernc` removes from the mirrored build subtree every `.erc` whose `.ern` no longer exists under the source root, and every directory left empty; nothing else is removed. `--no-clean` disables it. Single-file mode does not sweep.

### 11.2 `ern` (runner)

`ern [--config-dir dir] [--load-path dir ...] [--main Qualified.name] file.erc` loads the module and, on demand, the modules on the load path, found by namespace: `A.B.C` is `a/b/c.erc`, each segment lowercased, and a type-member reference `A.B.C.T.member` is found through the interface of `a/b/c.erc`, which owns `T`. The runner starts the system processes, binds their addresses to the `Sys.*` references, and calls the entry point (§8.1): the `export fn main` of the loaded module, or the function `--main` names, anywhere on the load path. The standard library is on the load path by default; `--load-path` extends it. The path-shape rule of §11.1 applies to every `.erc` opened as a module and to the directories to it; other files are not checked.

`--shell` adds an interactive shell process to the running program with every loaded module in scope; without a file, `ern --shell` starts the runtime with the standard library alone. `--config-dir` names the configuration directory, `./.ernest` by default.

### 11.3 Configuration setup

`ern --create-config-dir dir` creates `dir/.ernest/` with `ernest.conf` and this node's private key, readable only by its owner, and does nothing else; it fails if the directory exists. `ernest.conf` holds this node's network address and public key and the list of peers, each with a name, a network address, a public key, and whether it accepts remote computation; Appendix C shows one. The names are what `Peer(name)` refers to.

### 11.4 Documentation extraction

`ernc --doc file.ern` writes the module's documentation to stdout as Markdown: every exported declaration and every declaration with a doc comment, each with its type (§11.5) and its doc comment, in source order.

### 11.5 Diagnostics

An error is reported as `file:line:column: message`, then the source: a gutter of line numbers, the line before, the erroneous span underlined with `^`, any second span the message depends on, underlined with `-` and labelled, and at most one `help:` line naming the fix. `--errors short` prints the first line alone. The parser reports one error per file; the checker reports every error that does not follow from another.

A type mismatch is reported at the innermost expression whose type is fixed: the last expression of a body or block, a branch or clause after the first, an argument, an operand, an element, a pattern; the message shows both whole types, the label the span that fixed the expectation, an annotation, a callee's type, the first branch, clause, or element, the left operand, the value matched, and the help line the part in which the types differ. An effect error names the primitive called and the function, `let`, or guard that is pure, and labels the annotation that made it so.

The compiler shows the three inferred restrictions of §3.9. In a printed type a variable with the equality constraint is `a=` and one that is not reply-carrying `a!`: `equal : (a=, a=) -> Bool`, `discard : (a!) -> Unit`. A process-only effect variable prints unchanged, and its restriction is stated by the message that rejects a pure instantiation. A type name is printed as the module would write it (§4.2): the module's own types and the prelude's unqualified, other modules' qualified, a local type that shadows a prelude name qualified. A type variable is printed under its annotation's name; an unnamed one is `a`, `b`, ... for a value variable and `e`, `e1`, ... for an effect variable, avoiding the names in use. An error at a rejected call site names the parameter and the origin of its restriction; `ernc --doc` prints restrictions the same way.

## Appendix A. Grammar

```
Program     = { Declaration } .
Declaration = [ "export" ] ( TypeDecl | AbstractDecl | FnDecl | LetDecl | ForeignDecl ) .
ForeignDecl = "foreign" ( "type" typename [ "(" typevar { "," typevar } ")" ]
            | "fn" DeclName "(" [ ForeignParam { "," ForeignParam } ] ")" Return "=" string ) .
ForeignParam = ident ":" Type .

TypeDecl    = "type" typename [ "(" typevar { "," typevar } ")" ] "="
              Constructor { "|" Constructor } .
Constructor = conname [ "(" ( Type | Field { "," Field } ) ")" ] .
Field       = ident ":" Type .
AbstractDecl  = "abstract" TypeDecl "with" "{" Signature { ";" Signature } "}" .
Signature   = ( ident | userop ) ":" Type .

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
            | "bits" | "bytes" | "int" | "float"
            | "utf8" | "utf16" | "utf32"
            | "big" | "little" | "native"
            | "signed" | "unsigned" .
FieldPats   = [ ident "=" Pattern { "," ident "=" Pattern } ] .
```

`binop`, `userop`, and `literal` are defined in section 2, along with the other lexical categories; `binop` precedence follows the table there. Every nonterminal is decided by its first token: `let` begins a binding, `fn` a declaration or lambda (an identifier after `fn` makes it a declaration, `(` a lambda), `{` a block, `[` a list, `#(` a tuple, `(` a call or parenthesized expression, `<<` a bitstring. In `QName`, after each uppercase token the next token decides: `.` continues the qualification; otherwise the segment is final, and a lowercase final is a function or operator, an uppercase final a constructor. A constructor's fields are positional or named by whether `=` or `:` follows the first identifier. When a constructor name is immediately followed by a parenthesized constructor argument, the parser consumes that argument in the constructor branch of `QName`; a single-positional construction has the semantics of calling the constructor's function value. `conname` and `typename` are one token class; which one a segment is follows from its position.

## Appendix B. Examples

The counter of section 6, with a `main` that exercises `Inc` and `Get`. `Upgrade` is not exercised here; it is covered by the fragment in section 6.

```
type CounterMsg
    = Inc(Int)
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

`Peer("foo")` and `Peer("bar")` name these peers in `spawn`, section 6. `remote(f)` chooses among peers with `"remote-peer": true`, here only `foo`. The private key is in the same directory, `private-key.pem`, readable only by its owner. A freshly created file has an empty `peers` list.

## Appendix D. A Foreign Library

A shim over Erlang's `ets`, tables of type `set`. Raw bindings are module-local (unqualified); the library is ordinary Ernest over them. The BEAM values `ets` returns line up with Ernest's ABI (§8.4) here without an Erlang-side wrapper: `true` and `false` are `Bool` on both sides, and Erlang's `[{K, V}]` matches `List(#(k, v))`. Erlang's `{ok, V} | {error, R}` convention uses lowercase atoms `ok` and `error`, which under §8.4 are not the encoding of any Ernest constructor: `Either`'s `Left(e)` and `Right(a)` encode as `{'Left', e}` and `{'Right', a}`, quoted and source-preserving. An API returning that shape needs a foreign adapter that returns the declared Ernest representation — either an Erlang helper module that rewrites `{ok, V}` to `{'Right', V}` before it crosses the boundary, or explicitly declared foreign decoding functions on the Ernest side. An ordinary Ernest `match` cannot destructure the raw `{ok, _}` term directly: `Foreign` is opaque (Appendix E.12) and Ernest has no atom-decomposition pattern. The `ets` calls used below don't use that convention, so no adapter is needed here.

```
// ets.ern  (namespace Ets)

/// A key-value table stored in the runtime's ETS backend, keyed
/// by a value of type k with values of type v. A table lives
/// until Ets.drop is called on it, or until the process that
/// created it dies.
export foreign type Table(k, v)

/// A fresh empty table. The table is owned by the current
/// process and is destroyed when that process dies.
export fn new() -> Table(k, v) with m = rawNew(atom("ernest"), [atom("set"), atom("public")])

foreign fn rawNew(name : Foreign, opts : List(Foreign)) -> Table(k, v) with m = "ets:new/2"
foreign fn atom(name : String) -> Foreign = "erlang:binary_to_atom/1"

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
export fn size(t : Table(k, v)) -> Int with m = rawInfo(t, atom("size"))

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

The `raw` names have no `export` and are therefore invisible outside the module; the exported `Ets.*` interface is what callers see. `Ets.Table(k, v)` has type parameters the implementation never sees: `Ets.insert(t, "a", 1)` fixes `t` to `Ets.Table(String, Int)`, and an insert with other types on the next line is a type error. Every operation has a mailbox type, `size` and `member` included, because they read state that others write. `atom` is pure: the same text gives the same atom. No Erlang wrapper module is needed for this particular `ets` API because its raw returns already have Ernest-compatible shapes; an API using the `{ok, _} | {error, _}` convention would need one, as the introduction to this appendix notes. What the type cannot say, the declaration's documentation must: a table lives until `Ets.drop`, or until the process that created it dies.

## Appendix E. Standard Library

Informative, not normative: this appendix lists the modules that ship with the compiler as ordinary Ernest files under `stdlib/`. The standard library is on the load path by default; every program can call `Io.println`, `List.map`, and the rest without any setup. The prelude in section 9 is what the language itself requires; a prelude operation in a type's namespace, `Int.compare`, is provided by that type's module below. Everything else here is written in Ernest on top of the language and prelude, except the shims that E.0's first rule admits.

### Appendix E.0. Rules

Four rules decide whether a function is in.

1. Its value lives in the runtime and Ernest cannot compute it, or the runtime's implementation is the one to trust: the `Map` and `Set` operations, the Unicode operations on `String` and `Char`, `Float` arithmetic, `Int.toString`, the bit operations, `Foreign`, `Random`, and the modules over the system references of §8.2. These are shims over `foreign fn` or over a system process, and a shim exists only where this rule applies.
2. It follows from the type's structure, and each kind of type has a vocabulary. A container provides the container operations of the vocabulary below, or says in its section which it lacks and why. A sequence adds order and position: `reverse`, `sort`, `take`, `drop`, `dropLast`, `last`, `span`, `partition`, `unique`, `indexed`, `repeat`, `zip`, `unzip`, `flatMap`, `range`, and `tryMap` and `tryFold` for a step that can fail. Text adds `startsWith`, `endsWith`, `replace`, `slice`, `padStart`, `padEnd`, `repeat`, `split`, `join`, `lines`, `trim`, `toLower`, `toUpper`, and a character `isUpper`, `isLower`, `toUpper`, `toLower`. A path adds its segments: `join`, `split`, `parent`, `name`, `extension`, `withExtension`, `isAbsolute`. A filesystem adds files and directories: `read`, `write`, `append`, `list`, `stat`, `makeDir`, `remove`, `rename`, `copy`. A conversion to text has its inverse when programs read that type from text. A type that enters by rule 3 still gets its structure's vocabulary, not only the functions the program wrote.
3. A program under `examples/` writes it and the hand-written version has no policy choice in it. One program is enough.
4. It is not a composition. A function that is one pipe of two functions already here is not added: `List.concat` is `List.flatMap(xs, fn(x) = x)`, `List.sum` is `List.foldLeft(xs, 0, Int.+)`.

Six rules give a function its shape.

1. The subject comes first, callbacks last, an accumulator between them, so that `x |> f(a)` is `f(x, a)`. No aliases, no argument-order variants.
2. One verb per operation, in every module that has it. The container operations are `empty`, `size`, `isEmpty`, `contains`, `get` for lookup by index or key, `put` for insertion, `remove`, `map`, `filter`, `filterMap`, `foldLeft`, `foreach`, `any`, `all`, `find`, `fromList`, and `toList`; the sum-type operations are `withDefault`, `map`, and `andThen`. A predicate is `isX`. A verb not in this list needs an entry in the decisions log.
3. A conversion is named by the other type and lives in the subject's module: `String.toInt`, `String.fromList`, `Int.toString`. When one conversion has several policies, the policy is the name: `Float.round`, `Float.floor`, `Float.ceil`.
4. A partial operation returns `Optional`; one with a cause returns `Either`. No function here faults except as §7.4 says.
5. A function is pure unless its value lives in a process: `Io` carries `with m`, nothing else does. Every function that takes a function is effect-polymorphic (§3.9).
6. What the type does not say, the comment on the signature says: which occurrence `remove` removes, the order `toList` produces, the range `next` draws from.
7. A type a module declares is listed in its section as its functions are, `foreign type Seed` in E.13, and is named for what it is within the module, never for the module, since it is `Module.Type` from outside. The types the runtime speaks are the prelude's, §9.3.
8. A system reference of §8.2 is used through the module of its name, never by `send`. A function that waits takes the milliseconds as its last argument and answers `Left(Timeout)`; one that delivers later takes a function from the message to the caller's mailbox type and delivers to the caller, as `monitor` does (§6.9).

### Appendix E.1. `io.ern` (namespace `Io`)

Output to `Sys.stdout` and input from `Sys.stdin` (section 8). A string goes to any other `Address(String)` by `send`.

```
Io.print : (String) -> Unit with m
Io.println : (String) -> Unit with m // appends "\n"
Io.readLine : () -> Optional(String) with m // the next line without its line feed; None at end of input
```

### Appendix E.2. `list.ern` (namespace `List`)

`[]` is `empty` and `::` is `put`, so neither is a function; `fromList` and `toList` are the identity and are not provided. `contains`, `remove`, and `unique` require equality on `a` (§3.10). `List.<>` is the prelude's, §9.6.

```
List.size : (List(a)) -> Int
List.isEmpty : (List(a)) -> Bool
List.contains : (List(a), a) -> Bool
List.get : (List(a), Int) -> Optional(a) // by index from 0
List.remove : (List(a), a) -> List(a) // the first occurrence
List.map : (List(a), (a) -> b with e) -> List(b) with e
List.filter : (List(a), (a) -> Bool with e) -> List(a) with e
List.filterMap : (List(a), (a) -> Optional(b) with e) -> List(b) with e
List.foldLeft : (List(a), b, (b, a) -> b with e) -> b with e
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

A `String` is not a container: operations on its characters go through `toList`. `String.compare` and `String.<>` are the prelude's, §9.6.

```
String.size : (String) -> Int // code points
String.isEmpty : (String) -> Bool
String.contains : (String, String) -> Bool // substring
String.startsWith : (String, String) -> Bool
String.endsWith : (String, String) -> Bool
String.replace : (String, String, String) -> String // every occurrence of the second by the third; an empty second changes nothing
String.slice : (String, Int, Int) -> String // from the index, that many code points, clipped to the string; a negative index or count is 0
String.padStart : (String, Int, Char) -> String // the character in front until the length is at least the second
String.padEnd : (String, Int, Char) -> String // the character at the end until the length is at least the second
String.repeat : (String, Int) -> String // n times; n below 0 is 0
String.trim : (String) -> String // without leading and trailing whitespace
String.toLower : (String) -> String
String.toUpper : (String) -> String
String.lines : (String) -> List(String) // at each line feed; a line feed at the end adds no empty line
String.split : (String, String) -> List(String) // at each occurrence of the second; an empty second gives the first alone
String.join : (List(String), String) -> String // the second between the parts
String.toInt : (String) -> Optional(Int) // the digits 0 to 9, with an optional leading -
String.toFloat : (String) -> Optional(Float) // the float literal form of §2.5, with an optional leading -
String.toList : (String) -> List(Char)
String.fromList : (List(Char)) -> String
String.toUtf8 : (String) -> Bytes
String.fromUtf8 : (Bytes) -> Optional(String) // None when the bytes are not UTF-8
```

### Appendix E.6. `char.ern` (namespace `Char`)

The predicates use the Unicode properties of the code point: `isDigit` is general category Nd, `isAlpha` is category L, `isSpace` is White_Space, `isUpper` is Lu, `isLower` is Ll. `Char.compare` is the prelude's, §9.6.

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

`Int.div`, `Int.mod`, `Int.compare`, `Int.negate`, and the operators are the prelude's, §9.6.

```
Int.abs : (Int) -> Int
Int.min : (Int, Int) -> Int
Int.max : (Int, Int) -> Int
Int.bitAnd : (Int, Int) -> Int
Int.bitOr : (Int, Int) -> Int
Int.bitXor : (Int, Int) -> Int
Int.bitNot : (Int) -> Int
Int.shiftLeft : (Int, Int) -> Int
Int.shiftRight : (Int, Int) -> Int // arithmetic, sign-preserving
Int.toString : (Int) -> String
Int.toFloat : (Int) -> Float // faults outside the finite range, §3.1
```

### Appendix E.9. `float.ern` (namespace `Float`)

`Float.compare`, `Float.negate`, and the operators are the prelude's, §9.6.

```
Float.abs : (Float) -> Float
Float.min : (Float, Float) -> Float
Float.max : (Float, Float) -> Float
Float.toString : (Float) -> String // the shortest decimal that reads back as the same value
Float.round : (Float) -> Int // to the nearest, ties to even
Float.floor : (Float) -> Int
Float.ceil : (Float) -> Int
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
Either.mapLeft : (Either(e, a), (e) -> f with x) -> Either(f, a) with x
Either.andThen : (Either(e, a), (a) -> Either(e, b) with x) -> Either(e, b) with x
Either.toOptional : (Either(e, a)) -> Optional(a)
Either.fromOptional : (Optional(a), e) -> Either(e, a)
```

### Appendix E.12. `foreign.ern` (namespace `Foreign`)

```
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
Random.seed : (Int) -> Random.Seed
Random.next : (Random.Seed, Int) -> #(Int, Random.Seed) // uniform between 0 and the second inclusive, and the seed after it
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
Clock.alarm : (Int, (Unit) -> m) -> Unit with m // after the milliseconds, wrap(Unit) in the caller's mailbox
Clock.alarmAt : (Int, (Unit) -> m) -> Unit with m // at the time, wrap(Unit) in the caller's mailbox
```

### Appendix E.16. `keys.ern` (namespace `Keys`)

Over `Sys.keys`.

```
Keys.subscribe : ((Key) -> m) -> Unit with m // every key pressed from now on, wrapped, in the caller's mailbox
```

### Appendix E.17. `fs.ern` (namespace `Fs`)

Over `Sys.fs`. The last argument is the milliseconds to wait.

```
Fs.read : (Path, Int) -> Either(IoError, Bytes) with m
Fs.write : (Path, Bytes, Int) -> Either(IoError, Unit) with m // creates or replaces
Fs.append : (Path, Bytes, Int) -> Either(IoError, Unit) with m // creates or extends
Fs.list : (Path, Int) -> Either(IoError, List(Entry)) with m // the entries of a directory, in unspecified order
Fs.stat : (Path, Int) -> Either(IoError, Entry) with m
Fs.makeDir : (Path, Int) -> Either(IoError, Unit) with m // with its missing parents; an existing directory is not an error
Fs.remove : (Path, Int) -> Either(IoError, Unit) with m // a file or an empty directory
Fs.rename : (Path, Path, Int) -> Either(IoError, Unit) with m // the first to the second
Fs.copy : (Path, Path, Int) -> Either(IoError, Unit) with m // a file, the first to the second; replaces
```

### Appendix E.18. `tcp.ern` (namespace `Tcp`)

Over `Sys.tcp`. A socket is a process: its address can be sent, monitored, and killed like any other, and it dies with the connection. There are no options; framing is bitstrings (§5.11). The last argument of a function that waits is the milliseconds.

```
Tcp.listen : (Int) -> Either(IoError, Address(ListenerMsg)) with m // the port
Tcp.accept : (Address(ListenerMsg), Int) -> Either(IoError, Address(SockMsg)) with m
Tcp.connect : (String, Int, Int) -> Either(IoError, Address(SockMsg)) with m // host, port
Tcp.read : (Address(SockMsg), Int) -> Either(IoError, Bytes) with m // what has arrived, at least one byte
Tcp.write : (Address(SockMsg), Bytes) -> Unit with m
Tcp.close : (Address(SockMsg)) -> Unit with m
```

A function enters this appendix by the rules of E.0 before it enters `stdlib/`.

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
- **`Never`** — the type with no values. As a mailbox type it is the canonical send-only marker: the process cannot receive anything, and a `receive` with a pattern clause in it is a type error. §3.7, §6.8.
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
- **`Reply(a)`** — a one-shot address for the answer to a request. Reply-carrying: consumed exactly once by `answer`, delegation to a reply-carrying parameter, `send`, placement into a constructor or tuple, return from a reply-carrying return type, or capture in a `spawn`-lambda. The discipline propagates to any type transitively containing a `Reply`. §3.7, §6.6.
- **reserved word** — one of seventeen keywords. §2.4.
- **runtime** — the system that runs Ernest programs; BEAM. §10.
- **`self`** — `self()`, the current process's own address. §6.2.
- **`send`** — `send(a, v)`, places `v` in the mailbox of `a`. §6.2.
- **`spawn`** — `spawn(w, f)`, starts a new process. §6.2.
- **structural equality** — the meaning of `==`; two values are equal if their shape is. §3.10.
- **sum type** — a type with one or more constructors. §3.5.
- **standard library** — the modules under `stdlib/`, on the load path by default; not the prelude. §9, Appendix E.
- **system module** — the standard library module of a system reference's name, through which a program uses it. §8.2, Appendix E.0.
- **system reference** — a top-level address in `Sys.*`, wired by the runtime. §8.2.
- **tail position** — the last expression of a block, `match` clause, or `receive` clause; guaranteed TCO. §10.
- **top-level binding** — a value bound at file scope by a `let` (§4.6) or provided by the runtime (§8.2). A user-declared top-level binding is visible in its own module under its local name; external modules see it at the file's qualified name when marked `export`. Runtime-provided top-level bindings (`Sys.stdout`, prelude values) are in scope everywhere. §0, §8.2.
- **tuple** — a positional product, `#(a, b)`, `#(a, b, c)`, `#(a)`. §3.2.
- **type variable** — a lowercase identifier in type position; universally quantified in a `fn`. §3.9.
- **`Unit`** — a type with the single value `Unit`; the prelude's stand-in for "no meaningful return." §3.1, §9.3.
- **`via`** — `via(f, addr)` is the address `addr` seen through `f`. §6.5, §9.5.
- **wildcard** — the pattern `_`; matches anything, binds nothing. §2.3, §5.10.
- **`with M`** — the mailbox-type marker on a function type. §3.4, §6.1.
