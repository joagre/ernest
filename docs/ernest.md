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

Tokens are formed by max-munch: `>>`, `<-`, `->`, `==`, `!=`, `<=`, `>=`, `&&`, `||`, `|>`, `<>`, `::`, `#(`, `<<`, and `..` are single tokens rather than sequences of shorter ones. `|` is a delimiter (`match` clauses, sum-type constructors, `receive` clauses) and never a `binop`; the Pratt loop for `binop` terminates when it sees `|`.

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
Type      = TypeAtom | FnType | ParenType .
TypeAtom  = { typename "." } typename [ "(" Type { "," Type } ")" ]
          | typevar
          | TupleType .
TupleType = "#(" Type { "," Type } ")" .
FnType    = "(" [ Type { "," Type } ] ")" "->" Type [ "with" Type ] .
ParenType = "(" Type ")" .
```

`FnType` and `ParenType` share the leading `(` and the comma-separated content up to the matching `)`. The parser consumes that common prefix, then inspects the next token: `->` completes an `FnType`; anything else finishes a `ParenType`, which requires exactly one `Type` inside the parens.

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

**Integer arithmetic.** Integers are exact and unbounded — no overflow. Division `/` truncates toward zero: `-7 / 3 = -2`. Modulo `%` matches: `(a / b) * b + (a % b) == a`, so `-7 % 3 = -1`. `Int.div` and `Int.mod` (§9.6) use the same convention and return `Optional(Int)` in place of the zero-divisor fault; `Int.mod` is named for symmetry with `Int.div` and gives the same result as `%` (mathematical mod with always-non-negative result is not provided — write it in Ernest when needed).

**Float arithmetic.** IEEE 754 binary64 round-to-nearest, ties-to-even, restricted to the finite range. Arithmetic that would produce a non-finite result — overflow, division by zero of a non-zero numerator, or `0.0 / 0.0` — faults with cause `Fault("float arithmetic error")`. Gradual underflow is supported: a tiny exact result rounds to a subnormal or signed zero according to the rounding rule. Underflow to zero does not fault; signed zero is a finite `Float` value. There is no representation for `Infinity` or `NaN`, so `Float.compare`, `Float.round`, `Float.floor`, and `Float.ceil` are total on their input. This matches the underlying BEAM domain; a program that needs non-finite arithmetic must handle those cases explicitly before they arise.

`Int` and `Float` are separate types with no implicit conversion. Mixing them in an arithmetic expression is a type error; use `Int.toFloat` or `Float.round`/`Float.floor`/`Float.ceil` at the boundary. `Int.toFloat` on an integer whose magnitude exceeds the largest finite `Float` faults with cause `Fault("Int out of Float range")`; values within range round to the nearest `Float`, with ties to even.

### 3.2 Tuples

`#(A, B)` is the type of a tuple; the value form is the same, `#(a, b)`. Tuples of one, two, or more components are all written this way. The tuple is the only positional product type. The `#(` prefix keeps tuples distinct from expression grouping `(e)` and from function types `(A, B) -> C`.

### 3.3 Lists

`List(a)` is an immutable linked list. `[]` is the empty list. `x :: xs` prepends `x` to `xs`; `::` is right-associative, so `[a, b]` is `a :: b :: []`.

### 3.4 Function types

`(A, B) -> C` is the type of a function of two arguments. Arity is part of the type: `(A, B) -> C` and `(#(A, B)) -> C` are different types — the first takes two arguments, the second takes one tuple. `() -> C` takes no arguments.

`with M` after the result is the mailbox type: the function uses the process it runs in, whose mailbox has type `M`, §6.1. A function type without a `with M` is pure.

`with` binds to the nearest arrow; `(A) -> (B) -> C with M` is a pure function returning a function with mailbox type `M`. Parentheses group a type to override the default: `(A) -> ((B) -> C) with M` is a function with mailbox `M` returning a pure function.

### 3.5 Sum types

Declared with `type`, §4.3. A constructor has no fields, exactly one positional field, or named fields:

```
type Optional(a) = None | Some(a)
type Snapshot = Snapshot(dir : Path, seen : Map(Path, Mtime))
```

Positional fields cap at one — beyond that, names are required, because position alone would hide what each field means. Field names are unique within a constructor; their declaration order carries no meaning to the type system. Positional and named fields are distinguished by `:` after the first identifier in declarations, and by `=` in construction and patterns. For storage, hashing, and transport, named fields are placed in *canonical order* — lexicographic ASCII field-name order — so two nodes that declare the same-named type with fields in different source order agree on layout. Field expressions in a construction are still evaluated in source order (§5.1); their values are then placed into their canonical positions.

### 3.6 Abstract types

A sum type whose constructors may be mentioned only in the functions listed in the type's signature, §4.4.

### 3.7 Built-in types

`Address(m)` is an address of a process that receives `m`. `Reply(a)` is a one-shot address for the answer to a request, §6.6. `Never` is the type with no values. The prelude types are listed in section 9.

### 3.8 Foreign types

A type declared `foreign type T` has no constructors: its values are made and used only by foreign functions, §4.7, and can otherwise be held, passed, and sent.

A foreign value is bound to the node that made it: any cross-node transport of a value that transitively contains a foreign value is a fault, with cause `Fault("foreign value cannot cross nodes")`. This applies to `spawn(Peer(...), f)`, `send` to a remote address, `remote(f)` results returned to the caller, `answer(r, v)` where the caller lives on another node, and captured values in any shipped closure.

Equality on a foreign type is identity.

### 3.9 Type variables and polymorphism

Types are inferred according to Hindley-Milner. A `fn` definition is generalized over its free type variables. A `let` binding in a block is not generalized; a top-level `let` is generalized like a `fn`, so that polymorphic prelude values (`Map.empty`, `Set.empty`, and abstract-type constants like `Stack.empty`) can be used at every instantiation. Type variables in a `fn` signature scope over the whole definition.

Recursive and mutually recursive types are allowed. Polymorphic recursion is not. Every type variable in a constructor's fields must be a parameter of the type.

**Effect polymorphism.** A function type's mailbox effect can itself be a type variable. Inference generalizes it alongside other type variables in a `fn` definition. `fn apply(f, x) = f(x)` has inferred type `((a) -> b with e, a) -> b with e`, quantified over `a`, `b`, and `e`.

At a call site, a variable in an effect position binds to one of:

- **A mailbox type `M`.** The caller inherits effect `M`. `apply(fn(x) = send(a, x), 5)` binds `e` to the mailbox effect of `send`, so this call has that effect.
- **The empty effect.** A function type written without `with M` is pure; its effect slot is *empty*. `apply(fn(x) = x + 1, 5)` binds `e = empty`, so the call is pure.

**One kind of variable, one well-formedness rule.** Ernest has a single kind of type variable, in the HM sense. The role a variable plays is decided by where it appears:

- In a *value position* — arguments, results, tuple components, and inside `Address(_)`, `Reply(_)`, `List(_)`, and other type constructors — a variable must resolve to a value type.
- In an *effect position* — the type after `with` — a variable is used as the caller's mailbox effect. Effect positions additionally admit *empty* (no mailbox).

A variable that appears *only* in effect positions (like `e` in `apply` above) can bind to either a mailbox type or empty. A variable that appears in *any* value position (like `m` in `self : () -> Address(m) with m`) must resolve to a value type: the value-position usage requires a real type, so at every use site both occurrences of `m` receive the same mailbox type, and empty is not admissible. This is the only rule that ties the two occurrences of `m` together; unification does the rest.

The prelude primitives that require a process context — `send`, `spawn`, `Address.call`, `Address.callForever`, `answer`, `monitor`, `kill`, `remote`, `parallelRemote`, and any `foreign fn` declared with `with M` — carry the same non-empty restriction on their outer effect variable: the type checker treats it as if it appeared in a value position, so pure code cannot invoke them. Their signatures use effect-only variables for brevity; the constraint is a rule of the prelude, not of the annotation grammar.

The empty effect has no explicit syntax — its presence is the absence of a `with` clause. During type printing an effect variable bound to empty is elided from the output.

**Higher-order effect polymorphism.** `List.map`, `List.foreach`, `Map.map`, and other stdlib combinators that take function arguments are effect-polymorphic — the same rule that types `apply` above types them. Their published signatures in Appendix E make the effect variable explicit; a pure callback binds it to empty, an effectful callback binds it to the caller's mailbox.

**Two callbacks with independent effects.** Ernest has no effect union — a function has exactly one mailbox effect or none. A function that runs two callbacks with independent effects must declare them so:

```
fn callBoth(p : (Int) -> Int, e : (Int) -> Void with n) -> Void with n = {
    let _ = p(1);
    e(2)
}
```

`p` is pure (no `with`); `e` carries effect `n`; the outer function inherits `n`. If a body calls two callbacks whose effect variables are both polymorphic, unification collapses them to one — a function calls its callees in its own single effect context. If a body calls two callbacks whose effect types are concretely different, the call sites are incompatible and the definition is a type error.

**Annotations describe shape; some inferred properties are not written.** A type annotation gives the shape of a function — arity, argument types, return type, and mailbox effect. Two properties are inferred from the function body and not part of the annotation grammar:

- The equality constraint on a type variable induced by `==` usage (§3.10). Checked at instantiation.
- The exactly-once obligation on a reply-carrying parameter — bare `Reply(a)`, or a type that transitively contains it (§6.6). Signaled by the parameter type itself, checked compositionally.

An annotation is compatible with these; it doesn't need to state them. Constraints and obligations follow from usage in the body and from the callee's signatures.

**Inferred restrictions propagate through function values, branches, and modules.** Three restrictions travel with a function's type wherever the function flows:

- *Equality* (§3.10) — a variable used by `==` cannot be instantiated to a type containing functions or addresses.
- *Non-empty effect* — a function whose body calls a process primitive (`send`, `spawn`, `Address.call`, etc.) inherits that primitive's non-empty-effect restriction on its own effect variable. A wrapper `fn wrap(a, v) = send(a, v)` cannot be instantiated with an empty caller effect at any use site.
- *Not-reply-carrying* (§6.6) — a polymorphic parameter that a function duplicates, discards, or otherwise consumes twice cannot be instantiated to a reply-carrying type. `fn dup(x) = #(x, x)` and `fn discard(x) = Void` carry this restriction on their parameters; `fn id(x) = x` does not.

All three propagate the same way: they are part of the type scheme, travel through function values and branches, are preserved across compiled module interfaces, and are surfaced in diagnostics (printed types and error messages). The annotation grammar does not admit them; they are inferred and enforced by the type checker.

### 3.10 Equality and ordering

`==` and `!=` are defined for all values except those containing functions or addresses; on those, `==` is a type error. Equality is structural.

Ordering is defined per type by the function `compare` in the type's namespace, `Int.compare : (Int, Int) -> Ordering`. `Float.compare` is total on the finite domain of `Float` (§3.1).

**Equality on polymorphic types.** A function that uses `==` on a value of a type variable induces an implicit *equality constraint* on that variable. The constraint is not written in the type syntax; it is inferred from usage and checked at each call site. Instantiating the variable with a type that contains a function or address is a type error at that call site — not at the function's definition. The rule matches the equality-comparable check for concrete types.

`Map(k, v)` and `Set(a)` carry the same constraint on `k` and `a` respectively. Every operation on those containers implicitly asserts it, so a `Map` or `Set` parameterized by a non-comparable type is rejected at the first operation. Stdlib functions that use `==` internally on a type parameter, such as `List.contains` and `List.remove`, propagate the constraint through that parameter.

The check is at instantiation, not at generalization: `fn equal(a, b) = a == b` type-checks (its type is `(a, a) -> Bool`), and each call site is checked against the concrete type substituted for `a`.

**Propagation through function values, branches, and modules.** The equality constraint on a type variable is part of the type scheme, so it travels with the function value wherever the value flows. `let f = equal` gives `f` `equal`'s type including the constraint; applying `f` to addresses at some later point is an error at that application. `if flag then equal else always` unifies the branches to `(a, a) -> Bool` and inherits the union of constraints — since `equal` is constrained and `always` is not, the result is constrained, and the returned function cannot be applied to addresses. A module exports its polymorphic values with their constraints; a compiled interface encodes them, so a call from another module receives the same treatment as an internal call. The check remains at instantiation — a call chain through several intermediate polymorphic functions, where a constrained value is eventually applied to concrete arguments, is checked at the concrete application.

**Diagnostics.** The annotation grammar does not admit the equality constraint (§3.9), but the compiler surfaces it: printed types distinguish `equal : (a, a) -> Bool` (constrained) from `always : (a, a) -> Bool` (unconstrained) — the printer marks the constrained form so two functions with the same annotated shape are not indistinguishable. Error messages at rejected call sites identify which parameter's constraint failed and where the constraint came from. Generated documentation (`ernc --doc`) shows the constraint in the same form.

### 3.11 Serialization

All values can be sent in messages, functions included; their code travels with them, section 10.

## 4. Declarations and Scope

```
Program     = { Declaration } .
Declaration = [ "export" ] ( TypeDecl | AbstractDecl | FnDecl | LetDecl | ForeignDecl ) .
ForeignDecl = "foreign" ( "type" typename [ "(" typevar { "," typevar } ")" ]
            | "fn" DeclName "(" [ Param { "," Param } ] ")" Return "=" string ) .
TypeDecl    = "type" typename [ "(" typevar { "," typevar } ")" ] "="
              Constructor { "|" Constructor } .
Constructor = conname [ "(" ( Type | Field { "," Field } ) ")" ] .
Field       = ident ":" Type .
AbstractDecl  = "abstract" TypeDecl "with" "{" Signature { ";" Signature } "}" .
Signature   = ( ident | binop ) ":" Type .
FnDecl      = "fn" DeclName "(" [ Param { "," Param } ] ")" [ Return ] "=" Expr .
Param       = Pattern [ ":" Type ] .
Return      = "->" Type [ "with" Type ] .
LetDecl     = "let" DeclName [ ":" Type ] "=" Expr .
Binding     = "let" Pattern [ ":" Type ] ( "=" | "<-" ) Expr .
DeclName    = [ typename "." ] ( ident | binop ) .
```

### 4.1 Modules

A *module* is a single Ernest source file, ending in `.ern`. It is the unit of compilation and the unit that carries a namespace; every top-level declaration belongs to exactly one module.

### 4.2 Namespaces and visibility

**Files are namespaces.** A module's file path determines its namespace: a source file at `a/b/c.ern` provides declarations at namespace `A.B.C`, where each namespace segment is the case-preserving typename form of the corresponding path segment. Path segments are lowercase (§11.1); two namespace segments in the same program whose lowercase forms coincide (`Http` and `HTTP`) is a compile-time error. `main.ern` is a special file at the root — its declarations are in the root namespace, and its `main` function is the runtime entry point (§8.1).

**Declarations are local; `export` marks the boundary.** A top-level declaration in a module is written with its *local* name — no file-namespace prefix. `fn parse(...)` inside `net/http.ern` is one declaration; the compiler exports it as `Net.Http.parse`. The reserved word `export` marks a declaration as visible from other modules; without `export`, the declaration is private to its module.

```
// net/http.ern
export type Request = Request(method : String, path : String)
export fn parse(s : String) -> Optional(Request) = ...
fn helper(x) = ...        // private to net/http.ern
```

External callers write `Net.Http.parse` and `Net.Http.Request`; the file-namespace prefix appears at *use* sites, never at declarations. Two exported declarations with the same qualified name anywhere in the program are an error. There is no export list, no `pub`, and no `import`.

**Abstract-type accessors carry the type's prefix.** An abstract type `T` declared in a module creates a nested namespace `T` inside that module; the signature-listed accessor functions are declared with `T.` as prefix and exported at that nested namespace. This is the one case where `fn` and `let` declarations carry a typename prefix on their name — the prefix is always a single abstract-type name declared in the same module, never the file-namespace path. §4.4 gives the full rule.

**Unqualified lookup inside a body.** A name written unqualified in a function body is looked up in this order: the module's local declarations (whether or not `export`ed); the abstract-type namespace of the enclosing declaration, if any; and the prelude. Anything not found there must be qualified. The constructor of an abstract type is hidden from definitions outside its signature.

### 4.3 Type declarations

`type` declares a sum type with its constructors. A constructor has the visibility of its type.

### 4.4 Abstract types

`abstract type T = ... with { s1; s2 }` declares a type whose constructors may appear only in the definitions of the names given by the signatures. The type creates a nested namespace `T` inside its module: the signature `push : (a, Stack(a)) -> Stack(a)` refers to a definition of `Stack.push` in the same module. Accessor definitions carry the type name as a single-segment prefix (`fn Stack.push(...)`) — the one case where declarations use a qualified name; the file-namespace prefix (§4.2) is still implicit. The definitions are checked against the signatures and do not repeat the type. The constructor outside these definitions is a type error. The signature delimits who sees the constructor, not which functions may exist for the type.

```
// main.ern (root namespace)
export abstract type Stack(a) = Stack(List(a)) with {
    empty : Stack(a);
    push : (a, Stack(a)) -> Stack(a);
    pop : (Stack(a)) -> Optional(#(a, Stack(a)))
}

export let Stack.empty = Stack([])
export fn Stack.push(x, Stack(xs)) = Stack(x :: xs)
export fn Stack.pop(Stack(xs)) = match xs { [] -> None | x :: rest -> Some(#(x, Stack(rest))) }
```

Placed in `main.ern` at the root, the type is externally `Stack` and its operations are `Stack.empty`, `Stack.push`, `Stack.pop`. A module can co-locate multiple abstract types by declaring them alongside each other; each type carries its own nested namespace. When an abstract type is packaged in a namespaced file, its external name inherits the file's namespace — a `Foo` type in `bar.ern` (namespace `Bar`) is externally `Bar.Foo` and its operations are `Bar.Foo.*`.

### 4.5 Functions

`fn` declares a function of fixed arity. Annotations may be omitted where they can be inferred. The return annotation has three forms: omitted, `-> T` for a pure function, `-> T with M` for process code. A pure annotation on a function that calls process code is a type error.

A function has one clause. Patterns in parameters must be irrefutable, §5.10: `fn seenCount(Snapshot(seen = entries) : Snapshot) -> Int = Map.size(entries)`.

`fn` may appear at top level and as a statement in a block; it sees its own name, and `fn` declarations in the same block or at top level may refer to each other mutually.

### 4.6 Bindings

In a block, `let p = e` binds the pattern `p` to the value of `e`; `let p <- e` is described in §5.5. The pattern must be irrefutable. A binding is monomorphic and does not see its own name.

Shadowing is allowed: a later binding of the same name hides the earlier one from the next statement on, and the right-hand side sees the earlier one.

**Free type variables in a binding.** A block binding `let p = e` types `p` at `e`'s inferred type. That type may contain unification variables — the polymorphic empty values `[]`, `None`, `Map.empty`, `Set.empty`, and calls returning polymorphic values like `Ets.new()` all introduce them. Because a block binding is monomorphic, the compiler does not generalize at the binding site. Each such variable must be resolved by one of:

- A subsequent use of `p` within the block that pins it. `let m = Map.empty; Map.put(m, "a", 1)` unifies `m`'s type with `Map(String, Int)`.
- Propagation to the enclosing scope through the block's result type. A variable that appears in the block's result is carried out to the surrounding `fn` (or top-level `let`), where it is generalized by the standard rule. `fn namedEmpty() = { let xs = []; xs }` types as `() -> List(a)`; `[]`'s element type escapes through `xs` to the block's result and is generalized by `fn`.
- An explicit annotation on the binding, `let m : Map(String, Int) = Map.empty`.

A variable that none of these resolves — not pinned by later uses of `p`, not carried out through the block's result, not annotated — is genuinely unconstrained. That is a type error at the binding's site.

The wildcard binding `let _ = e` is a discard, not a name binding: `_` does not bind a variable, so unification variables in `e`'s type never propagate anywhere and do not need resolution. `let _ = spawn(Local, fn() = worker())` is legal even when the spawned lambda's mailbox type is a fresh polymorphic variable — nothing downstream cares.

Type parameters of the enclosing `fn` (or of any outer scope) are not "unresolved" — they are quantified at their binding site and appear in the block's environment. A binding whose inferred type mentions such a parameter typechecks without needing further resolution.

At top level, a `let` binds a `DeclName` — an unqualified `ident` (`binop` on operator definitions), optionally prefixed with a single typename that names an abstract type declared in the same module — to a value. `let empty : Stack(a) = Stack([])` inside `main.ern` under `abstract type Stack` becomes `let Stack.empty : Stack(a) = Stack([])` for the accessor form. The LHS is a name, not a pattern, and `<-` is a block form only. Top-level `let` may generalize its free type variables: `let Stack.empty : Stack(a) = Stack([])` declares a polymorphic value usable at every instantiation of `a`. `export` marks the declaration visible outside its module (§4.2).

A top-level `let`'s initializer must be pure — no mailbox effect. Effectful setup (spawning processes, opening resources, sending initial messages) belongs in `main`, not in top-level declarations. The runtime evaluates top-level `let` bindings in dependency order before `main` runs (§8.5).

### 4.7 Foreign declarations

`foreign type T` declares a type implemented outside the language.

`foreign fn f(params) -> T = "impl"` declares a function whose body is the implementation named by the string, in the runtime's language; parameters and the return are annotated. A foreign function with a mailbox type, `-> T with m`, may do anything; a foreign function without one promises purity: the same result for the same arguments and no effect on anything.

Both `foreign type` and `foreign fn` may be prefixed with `export` to make them visible from other modules (§4.2), following the same rule as ordinary declarations. The implementation promises the declared types; a value of another shape, or an exception, is a fault, section 7. Foreign code sees values in the runtime's representation, section 10.

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

### 5.1 Evaluation

Strict, left to right, arguments before the call. No delayed computation; `fn() = e` defers `e`. Prefix `-` is `Int.negate` or `Float.negate` by the operand type.

### 5.2 Calls

`f(x, y)` supplies all arguments. A call with the wrong number of arguments is a type error on the calling line; a call never yields a partially applied function. An expression whose value is a function can be called directly: `makeAdder(3)(4)`.

### 5.3 Lambda

`fn(x) = e` is an anonymous function. Its body is the longest `Expr` at the same nesting level as the `fn`, ending at the first outer delimiter of the enclosing form — `,`, `;`, `|`, `)`, `}`, `]`, or `>>`.

### 5.4 Blocks

`{ s1; s2; e }` is an expression whose value is the last statement, which must be an expression. `;` separates statements and never appears last. Statements are `fn` declarations, `let` bindings, and expressions; an expression as a statement is evaluated for its effect.

A `fn` declared inside a block is visible throughout the block, so mutual and self-recursion between local `fn`s works the same as at the top level. `let` bindings remain sequential: `let p = e` is visible from the next statement onward, and a `fn` body that references a `let` declared later in the same block is a compile-time error. A local `fn` may only be *used* — called, obtained as a function value, passed to another function, stored, returned, or captured by another closure — after every `let` binding it references (directly or through references to other local `fn`s in the same block) has been evaluated. Using it earlier is a compile-time error; the check follows references between local functions, so both direct calls and function-value uses count.

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

`|>` is left-associative and lowest-precedence, below `||`: `a + b |> f` is `f(a + b)`, and `a |> b |> c` is `c(b(a))`. The right-hand side may be a name, a qualified name, a parenthesized lambda, or a call whose first-argument slot the pipe fills. A lambda in this position must be parenthesized (`x |> (fn(y) = y + 1)`); an unparenthesized `fn(...) = ...` after `|>` would extend its body greedily into the surrounding expression. When the RHS is a chained call — `f(a)(b)` — the pipe fills the *outermost* call's first-argument slot: `x |> f(a)(b)` is `f(a)(x, b)`. A parenthesized call `(f(a))` behaves as a plain call: `x |> (f(a))` is `f(x, a)`. The type of `x` must match the target function's first argument.

### 5.8 Conditional

`if c then a else b` with `c : Bool`; the branches have the same type.

### 5.9 `match`

The expression is matched against the clauses' patterns in order; the first clause whose pattern matches and whose guard holds is evaluated. A failed guard falls through. The clauses together must cover the type; guards do not count as coverage. Variables in the pattern are bound in the guard and the clause.

A guard is an expression of type `Bool` with no mailbox effect — the type checker rejects `send`, `receive`, `spawn`, `Address.call`, and any other effect-carrying operation in a guard. The guard sees the pattern-bound variables of its clause and the enclosing scope. A guard that evaluates to `false` falls through to the next clause; a guard that faults faults the enclosing process — there is no fall-through for faults. The same rules apply to guards in `receive` clauses.

### 5.10 Patterns

A pattern decomposes a value and binds its parts. The same patterns appear in `let`, in `match` and `receive` clauses, and in function parameters.

**Atomic patterns.** `_` matches anything and binds nothing. An identifier binds the whole value at its position to a new variable, shadowing any outer variable of that name; it never refers to an existing variable. A literal matches itself; a numeric literal may be prefixed with `-` to match a negative value, `match n { -1 -> "minus one" | _ -> "other" }`.

**Compound patterns.** A constructor with a pattern, `Some(p)`, or with field patterns, `Snapshot(seen = s)`, which may omit fields, matches that constructor and decomposes its fields. A tuple `#(p, q)`, a list `[p, q]`, and `p :: q` decompose those. Patterns nest to any depth: `Some(#(x, Snapshot(dir = d)))`.

**`as` bindings.** `p as c` binds `c` to the whole value that `p` matches, `Some(Snapshot(dir = d) as snap)`. `as` binds loosest, so `x :: rest as all` names the whole list.

**Constraints.** Each variable appears at most once in a pattern; a pattern does not compare, and equality is written in a guard.

**Irrefutable patterns.** A pattern is irrefutable if it cannot fail: `_`, an identifier, a tuple of irrefutable patterns, or a constructor pattern of a type with exactly one constructor whose sub-patterns are all irrefutable. `let` and parameters require irrefutable patterns; `let Right(x) = e` is a type error.

### 5.11 Bitstrings

`<<...>>` constructs and pattern-matches a `Bytes` value at the bit level. A bitstring is a comma-separated list of segments between `<<` and `>>`; each segment is a value (in construction) or a pattern (in `match`), followed optionally by a colon and a dash-separated list of specifiers.

**Specifiers.**

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

These specifier names carry that role only inside a bitstring — outside, they are ordinary identifiers, and the reserved-word count remains seventeen.

**Byte alignment.** `<<...>>` produces a `Bytes` value, and `Bytes` is a sequence of octets (§3.1). The total bit count of a construction must therefore be a multiple of 8. Every `bits` or `bytes` segment that binds to `Bytes` — either as a construction source or a pattern binding — must itself have a byte-multiple size: `size(3)-bits` binding to `Bytes` is rejected, because a 3-bit `Bytes` value does not exist. Sub-octet fields use the `int` specifier and bind to `Int`. Compile-time-constant violations are compile-time errors; dynamic-size violations fault at construction (§7.4) or fail to match in a pattern.

**Patterns and construction.** A bitstring pattern binds its segment variables; a segment whose length is `size(n)-bytes` and whose `n` refers to an earlier bound variable is a size-dependent match, common in protocol parsing. `size(Expr)` in a pattern evaluates `Expr` in the scope of earlier-bound segment variables and the enclosing scope; the expression must be pure (no mailbox effect) and produce a non-negative `Int`. A negative or out-of-range size fails the match; a fault in the size expression faults the enclosing process. Constructing a bitstring evaluates its segments left to right and concatenates them into a `Bytes` value; a segment whose value does not fit its specified width is a fault. An empty `<<>>` is the empty `Bytes`.

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

The mailbox effect is inferred:

- A function whose body calls another function with effect `M` gets effect `M`.
- Two calls with different concrete effects in the same function body are a type error.
- Calls with variable effects unify; the enclosing function has the unified effect.
- A pure call (no `with M` on the callee) contributes no effect: the enclosing function's effect is whatever its other calls determine.

A function without a mailbox effect is pure: it neither sends, receives, nor calls foreign code with a mailbox effect, and it can be called from any process. A pure higher-order function runs its function arguments in the caller's process: `List.map(xs, fn(x) = send(a, x))` has the same effect as the callback, and `List.map` is effect-polymorphic (§3.9). Nothing else can be marked on a function type.

### 6.2 Built-in functions

```
self  : () -> Address(m) with m
send  : (Address(a), a) -> Void with m
spawn : (Where, () -> Void with n) -> Address(n) with m

type Where = Local | Peer(String)
```

`self()` is the process's own address. `send(a, v)` places `v` in the mailbox of `a` and returns immediately; sending to a process that has died has no effect.

`spawn(w, f)` starts a new process that runs `f()` and returns its address. `self()` inside `f` is the new process's address; a parent that wants replies binds `let me = self();` before `spawn`. The callback's mailbox effect `n` also appears in `Address(n)`, so it must be a real mailbox type (§3.9) — a pure `f` (one with no `with M`) cannot be spawned. To spawn a process that never receives, annotate the callback with `with Never`: `spawn(Local, fn() -> Void with Never = ...)`.

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

**Reply-carrying types.** A type is *reply-carrying* if it is `Reply(a)`, or if any of its constructor fields or tuple components has a reply-carrying type. The property is transitive: `type Request = Get(reply : Reply(Int))` is reply-carrying because `Get` has a reply-carrying field; `#(Request, Int)` is reply-carrying because one component is; `type Envelope = Env(msg : Request)` is reply-carrying because `Env`'s field is. The property is by type, not by constructor: `type PongMsg = Ping(n : Int, reply : Reply(Int)) | Stop` is reply-carrying, and `Stop` values are treated the same as `Ping` values for the discipline below — the checker cannot in general tell which constructor a value carries.

**Legal positions.** A reply-carrying value may appear as: a field of a constructor, a component of a tuple, a parameter of a function, a variable bound in a `receive` clause, a variable captured by a lambda passed directly to `spawn`, or a value returned from a function whose declared return type is reply-carrying. Any other position is a type error — in particular, reply-carrying values may not appear as elements of `List`, `Map`, `Set`, `Optional`, or `Either`, or as an operand of equality. `as` on a reply-carrying scrutinee is a type error, because the alias would duplicate the obligation.

Pattern-matching a reply-carrying value must bind every reply-carrying field of the matched constructor: a wildcard (`_`) or an omitted field for a position whose declared type is reply-carrying is a type error, because it would silently drop the value. The match transfers the obligation from the scrutinee to the pattern-bound reply-carrying variables — the scrutinee is fully consumed by the match and cannot be used after. If the matched constructor has no reply-carrying fields (e.g., `Stop` in a `type PongMsg = Ping(reply : Reply(Int)) | Stop`), matching that clause discharges the scrutinee's obligation with no new binding introduced.

**Exactly-once obligation.** Every binding of a reply-carrying value creates a consumption obligation checked statically at the binding site. On every path from the binding, the value must be consumed exactly once. Bindings include: a variable in a `receive` clause, a function parameter, a spawn-lambda capture, a variable introduced by pattern-matching a reply-carrying scrutinee, and the result at the call site of a function whose return type is reply-carrying.

Consumption is one of:

- `answer(r, v)` where `r : Reply(a)`. This is the only primitive that finally discharges a `Reply`.
- Passing the value to a function whose corresponding parameter type is reply-carrying — delegates the obligation to the callee, checked at the callee's definition.
- Sending the value with `send(a, v)` when `v` is reply-carrying — shifts the obligation to whichever `receive` clause in the recipient's process eventually binds it.
- Placing the value into a constructor field or tuple component of reply-carrying type — the constructed value inherits the obligation and is itself subject to the discipline.
- Returning the value from a function whose declared return type is reply-carrying — shifts the obligation to the caller's use-site binding.
- Capturing the value in a lambda passed directly to `spawn` — shifts the obligation to the spawned function's body.

The check is compositional: each function is analyzed at its own definition against its reply-carrying parameters, receive-bound values, and construction and return sites. No analysis crosses call boundaries. The `mk` callback of `Address.call` is checked by this rule — its `Reply(a)` parameter is consumed by placement into the reply-carrying value the lambda returns, and the returned value's obligation is discharged by `Address.call`'s runtime.

The check is static in flow, not in dynamics: it ensures every path *calls* the consumption but not that execution *reaches* it at runtime — non-termination, a fault, or an indefinite wait bypasses the call without invalidating the type check.

`fn twice(dst : Address(Request), request : Request) = { send(dst, request); send(dst, request) }` is rejected: `request` is reply-carrying, consumed by the first `send`, and used again by the second. `match req { Get() -> ... }` on a `Get(reply : Reply(Int))` constructor is rejected: the omitted field would silently drop a reply-carrying value.

**Timeout rationale.** The mandatory timeout on `Address.call` returns `Optional(a)` so an answer that never arrives has somewhere to land; `Address.callForever` opts out of that by name, and the caller accepts that this call may hang.

**Deadline start and races.** The timeout clock starts when `Address.call` is invoked, so the `mk(r)` build and the outgoing send count against the deadline. A reply that arrives simultaneously with the timeout may be delivered (returning `Some(v)`) or discarded (returning `None`) — the runtime does not guarantee a tiebreak.

**Late answers.** After `Address.call` returns `None` on timeout, the runtime deregisters the `Reply(a)`'s fresh identifier. Any subsequent `answer(r, v)` call by the recipient sends a value tagged with that identifier; the runtime silently discards it — it does not appear in the caller's mailbox, does not fault, does not affect other messages. `Address.callForever` behaves the same way if the caller dies while waiting: the reply value is silently discarded when it arrives at a dead process. Caller timeout or death does not cause `answer` to fail on the recipient — the recipient has no way to observe whether the caller is still waiting. Cross-node transport faults (§3.8, foreign values crossing nodes) still apply to `answer` when the caller is on another node.

**Mailbox isolation.** The fresh identifier attached to each `Reply(a)` is known only to the `Address.call` that allocated it. Reply values are delivered to the waiting call via that identifier; they never appear in the caller's declared mailbox, and the caller's mailbox type does not include them. Ordinary messages sent to the same process by other senders continue to flow into the mailbox typed as `m`, uninfluenced by pending or timed-out `Address.call` operations.

### 6.7 Remote computation

A pure function can be evaluated on another node:

```
remote         : (() -> a) -> Either(RemoteError, a) with m
parallelRemote : (List(() -> a)) -> List(Either(RemoteError, a)) with m
type RemoteError = NoRemotePeer | PeerLost
```

`remote(f)` evaluates `f()` on a peer the runtime chooses among those configured for remote computation, and returns the value. Which peer, and by what criterion, the language does not say. `f` is pure by `remote`'s design — the operation is a one-shot compute-and-return; effectful work on a peer goes through `spawn(Peer(...), ...)` instead. `remote` itself is not pure: `Left(NoRemotePeer)` if no peer is configured; `Left(PeerLost)` if the peer disappears before the value returns or resolution on the peer fails (§8.7). Those failure modes expose runtime state, so `remote` carries a mailbox effect (`with m`) — it can only be called from process code.

`parallelRemote(fs)` runs the functions in `fs` on peers in parallel and returns the results in the input order, one `Either` per input. Same effect status as `remote`, same reasoning. The runtime picks peers and schedules the calls; a caller that needs richer control — cancellation, per-task timeouts, interleaved arrivals — spawns processes itself.

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

### 7.4 Prelude operations and faults

Partial operations in the prelude generally return `Optional` or `Either`. The operations listed below deliberately fault on specified inputs or runtime conditions. Absence of a mailbox effect does not guarantee absence of faults.

- `/` and `%` on `Int` with a zero divisor fault with cause `Fault("division by zero")`. `Int.div` and `Int.mod` return `Optional` for the caller who wants to handle it.
- `Float` arithmetic operations `+`, `-`, `*`, `/` fault with cause `Fault("float arithmetic error")` on any result the finite domain cannot represent — overflow, division by zero of a non-zero numerator, or `0.0 / 0.0` (§3.1). Gradual underflow to signed zero is not a fault. `Float` values are finite; there is no `Infinity` or `NaN`, so `Float.compare`, `Float.round`, `Float.floor`, and `Float.ceil` are total. `Int.toFloat` faults on integers whose magnitude exceeds the largest finite `Float` (cause `Fault("Int out of Float range")`).
- Bitstring construction faults in two cases (§5.11): a segment value that does not fit its specified width (`Fault("segment overflow")`), or a total or per-segment bit count that is not a multiple of 8 with dynamic sizes when binding to `Bytes` (`Fault("bitstring not byte-aligned")`). Compile-time-constant violations are rejected at compile time; the runtime fault covers the dynamic cases.
- `todo("...")` compiles at any type and faults if reached with cause `Fault("todo: ...")`, so that an unfinished function can be declared before it is written.
- Any cross-node transport of a value that transitively contains a foreign value, with cause `Fault("foreign value cannot cross nodes")` (§3.8).
- `spawn(Peer(...), ...)` faults the caller when the peer is unknown or unreachable (§6.2), and when peer-side dependency resolution fails (§8.7) — a missing `Sys.x`, an incompatible foreign definition, or an unresolvable code hash. Cause is `Fault("peer unreachable")` or `Fault("peer resolution failed: ...")`.
- `send` to a remote address (§6.5) faults the sending process asynchronously if peer-side resolution fails; the fault is delivered after `send`'s immediate return, once the recipient's runtime reports the failure. Cause matches `spawn(Peer, ..)`'s peer-resolution fault.
- Invalid foreign returns and invalid messages received from foreign processes fault the receiving Ernest process on first observation (§8.4); the foreign side's ABI breach is reported as a fault on the process that would have consumed the malformed value.

## 8. Programs

### 8.1 `main`

A program is a set of modules with exactly one function `main : () -> Void with m` for some `m`, unqualified, called by the runtime. Nothing sends to `main` that it has not given its address to. `m` is `Never` when `main` only spawns and sends; a specific message type when `main` receives; polymorphic when `main` uses `Address.call` without its own receive protocol. When `m` is left polymorphic in the source, the runtime instantiates it to `Never` — the main process's mailbox is send-only unless the program explicitly gives out `self()`.

### 8.2 System references

The runtime starts with its system processes and exposes their addresses as top-level values in the `Sys` namespace. The language requires `Sys.stdout : Address(String)` and `Sys.clock : Address(ClockMsg)`, §9.7; a specific runtime may provide more, and a paper program that needs additions like `Sys.fs`, `Sys.stdin`, `Sys.keys`, or a stderr sink names them in its assumptions.

These are values, not functions — like `List`, `Map`, and `Set` they are in scope everywhere at the top level. To do IO a function sends to one, and `send` requires a mailbox effect on the caller (§6.1), so pure code cannot affect anything outside its process even though it can name the address.

A reference to a `Sys.*` name the runtime does not provide is a name-resolution error at compile time. The `stdout` process writes each received `String` to standard output as bytes; newlines are the sender's responsibility.

### 8.3 Peers

Peers are configured outside the language, §11.3; `Peer(name)` refers to them by the configured name, and nodes authenticate each other.

### 8.4 Foreign code

The system processes are foreign processes: their message types are declared in Ernest, their implementations live outside the language, and the runtime starts them and binds their addresses to the `Sys.*` top-level references. Other foreign code enters through `foreign fn` and `foreign type`, §4.7. Both boundaries carry the same promise: the foreign side delivers the declared types, and a breach is a fault. The fault is delivered to the *receiving* Ernest process — the process that would have consumed the malformed value — on first observation, not to the foreign side.

**ABI.** The runtime maps Ernest values to host-language terms as follows (specified here for the BEAM runtime; other runtimes state their own equivalent):

- `Int` → arbitrary-precision integer.
- `Float` → IEEE double, finite (§3.1).
- `Bool` → atom `true` or `false`.
- `Char` → integer (Unicode code point).
- `String` → binary (UTF-8 encoded).
- `Bytes` → binary.
- `Void` → atom `void`.
- Nullary constructor `C` → the quoted atom preserving the source spelling, e.g. `'Ready'`, `'READY'`, `'None'`. Preserving case makes the tag injective: two constructors that differ only in case (`Ready` vs `READY`) map to distinct atoms.
- Positional constructor `C(v)` → tuple `{'C', v}` with the constructor's quoted-atom tag as the first element.
- Named constructor `C(f1 = v1, ..., fn = vn)` → tuple `{'C', v_sorted_1, ..., v_sorted_n}` with the tag first, then the field values in *canonical order* (sorted by field name; §3.5). Field expressions are evaluated in source order per §5.1 and then placed into their canonical positions.
- Tuple `#(v1, ..., vn)` → tuple `{v1, ..., vn}`.
- `List(a)` → list.
- `Map(k, v)` → opaque runtime handle backed by BEAM's `maps` (structural equality on keys, no cross-key ordering guarantee).
- `Set(a)` → opaque runtime handle backed by the same map primitive.
- `Address(m)`, `Reply(a)` → opaque runtime handles; foreign code may pass them back to Ernest but cannot inspect them.
- Foreign values → as produced by foreign code; Ernest does not inspect them.
- Ernest function values → opaque runtime handles; foreign code may pass them back to Ernest but cannot inspect them.

Same-named constructors of different types share an atom on the wire; the receiving Ernest process's declared type disambiguates. The ABI is fixed per runtime; cross-node transport uses the runtime's external term format for these representations. Canonical field ordering is what makes two nodes that declare the same-named type with reordered fields agree on layout (§3.5, §8.7). A foreign implementation that returns a term not matching the declared Ernest type is a fault on the Ernest side per the previous paragraph.

### 8.5 Initialization

Before `main` runs, the runtime evaluates every top-level `let` binding in the program. Evaluation follows data dependencies: a binding that references another is evaluated after the one it references. Order within an independent set is unspecified — top-level `let` initializers are pure (§4.6), so the order does not affect the result. A cycle among top-level `let` initializers is an error: within a single module it is caught at compile time; across modules it is caught at load time, when the runtime has resolved every referenced module (§11.2).

Top-level `type`, `abstract type`, `fn`, and `foreign` declarations have no runtime effect; only `let` requires evaluation. The `Sys.*` references (§8.2) are available to `let` initializers — the runtime binds them before evaluating top-level bindings.

**Failure during initialization.** Purity does not imply totality. A top-level initializer can fault (via `todo`, `Int` zero-divisor, or the other exceptions in §7.4) or fail to terminate. An initializer that faults ends the program with that fault before `main` runs. Because order within an independent set is unspecified, which of two independent faulting initializers is reported is unspecified; a nonterminating initializer prevents unrelated initializers from being reached.

**Dependency graph.** The cycle-detection graph is symbolic: binding `p` depends on binding `q` if `p`'s initializer directly or transitively references `q` by name in a resolvable position. A function called by an initializer contributes its own referenced bindings to the graph. Cross-module cycles are detected at load time, when the runtime has resolved every referenced module (§11.2).

### 8.6 Program termination

The program ends when `main` returns. Live *local* processes then die with cause `ProgramEnd`; system processes release their resources; the runtime flushes pending output on system processes before the program's process ends. Remotely spawned workers on peer nodes are unaffected by the initiating program's exit — they run independently under their peer's runtime, and their lifetimes follow their own return, `kill`, or peer-loss (§10). A program that is to keep running waits in `main`. `main` faulting has the same effect as returning, except that the fault's cause is reported on the runtime's exit indicator. Peers observe the ending node's death through their own `PeerLost` channel (§10); the ending node does not send a coordinated shutdown signal.

If forward progress is impossible — every live process is waiting in `receive` without `after`, no message is in flight, and no live system process or connected peer holds a subscription, timer, pending I/O, or in-progress computation whose completion would deliver a message to a live process — the runtime ends the program with the error `Deadlock`. Pending `after`s, pending clock timers, network listeners, keyboard subscribers, and any similar registered future delivery from a system process count as messages in flight; a connected peer with a pending `Address.call` reply or a running `spawn`ed worker on this node's behalf also counts, so a program awaiting a reply from a still-computing peer is not deadlocked. Deadlock detection is per-node — the runtime does not coordinate across peers, and a program deadlocked in a distributed sense may not be detected. `Sys.*` system processes count as external event sources by the runtime's default; a specific runtime decides whether user-provided foreign event sources are similarly registered.

### 8.7 Code shipping

`spawn(Peer(name), f)` (§6.2), `remote(f)` (§6.7), and any `send` whose destination is a remote address (§6.5) ship the closure or message payload and the code it depends on to the peer. Within-node operations ship nothing — a function is a value in the local heap. This section specifies the peer-ship contract.

**Content addressing.** Every function, constructor, and type is identified across nodes by a content hash: a hash of its normalized definition together with the hashes of every definition it references. Structurally identical definitions have the same hash on every node; any change — a constructor added, a field renamed, a called function's body altered — changes the hash and, transitively, the hashes of everything that depends on it.

**Recursive definitions.** A function that references itself, or a set of mutually recursive functions or types, is hashed as a group: internal references within the group use positional indices, external references use their hashes, and the group is hashed as a whole. Each member's identity is derived from the group hash. This gives a finite construction and a consistent identity across nodes.

**Normalization.** Normalization strips local variable names (α-conversion). Named-field declarations and layouts use lexicographic ASCII field-name order (§3.5), matching the ABI (§8.4). In function bodies, normalization preserves the source evaluation order of construction expressions, including their possible faults and effects; placing the resulting values in canonical field positions does not erase that evaluation order from the function's normalized definition. Qualified names of external references are preserved. Because declarations and layouts use the same canonical order, two nodes whose declarations of the same-named type differ only in source field order have the same hash *and* the same on-wire layout.

**Dependency resolution.** A shipped closure carries the hashes of the code it needs. Before it runs, the peer resolves every hash transitively: hashes it already has (from an earlier ship, or from its own compilation of an identical definition) are used directly; missing hashes are fetched from the sender and cached. Any resolution failure — a missing dependency, a missing `Sys.x` on the peer (§8.2), an incompatible foreign definition (§4.7), or a fault raised while running `remote`'s callback — surfaces as `Left(PeerLost)` for `remote` and as a caller fault for `spawn(Peer, ...)`, matching §6.2's rule that an unknown or unreachable peer faults the caller. `Left(PeerLost)` signals that this specific `remote` operation did not complete; it does not invalidate other `Address` values held for the same peer, which are only invalidated by actual peer-loss detection (§10). A shipped `send` payload uses the same contract; because `send` returns immediately (§6.2), a resolution failure at the recipient faults the sending process *asynchronously*, after `send`'s return, once the peer runtime reports the failure.

**Type identity.** Types are identified by hash. Two nodes with structurally identical `FooMsg` share the same type hash and interoperate freely. Two nodes that both declare a local type `FooMsg` but define it differently have different hashes; the peer treats them as distinct types. A shipped closure that mentions the sender's `FooMsg` uses the sender's hash on the peer; the peer's own `FooMsg` under the same source name is unrelated to it as far as the type checker on the peer is concerned.

**Abstract types.** An abstract type's hash includes its qualified name and its exported signature (the `with { ... }` block), not just its private representation. Two nodes that separately declare `abstract type Stack(a) = Stack(List(a)) with { ... }` are equivalent only if their qualified name and exported operations match — the abstraction boundary is part of type identity, so independent Stacks with the same private representation do not silently interoperate across nodes.

**Runtime bindings.** A `Sys.*` name referenced by shipped code resolves *on the peer that runs the code*, not on the sender; a shipped `Io.println` sends to the peer's `Sys.stdout`. A closure that captures an already-obtained address as a value ships that value: an `Address` captured from the sender's `Sys.stdout` still points to the sender after transport, because captures capture values, not names. Top-level bindings referenced by shipped code are computed on demand on the peer from the shipped initializer, and the initializer runs in the peer's environment — a binding like `let output = Sys.stdout` evaluates to the peer's stdout on the peer and the sender's on the sender; the two results need not match. Each top-level initializer is evaluated at most once per node per code version.

**Foreign code.** `foreign fn` and `foreign type` (§4.7) are not shipped. A shipped closure that references foreign code requires the peer to have a compatible foreign definition under the same qualified name and shape; a missing or incompatible foreign definition is a fault at resolution.

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
remote              : (() -> a) -> Either(RemoteError, a) with m
parallelRemote      : (List(() -> a)) -> List(Either(RemoteError, a)) with m
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
- A node ships code to a peer that lacks it, identified by content, so that `spawn` on a peer and `remote` need no prior installation; peers need not hold the same code. Transitive dependencies resolve by hash before the shipped closure runs; types are content-addressed; `Sys.*` re-binds to the peer; foreign code is per-node. See §8.7.
- The runtime detects the loss of a peer: from the observing node's view, all processes on the lost peer are treated as dead with cause `Fault("peer lost")`, monitors deliver accordingly (§6.9), and pending `remote` calls return `Left(PeerLost)`. Loss is terminal from the observer's view — a peer that later reappears with the same name is a new instance whose addresses are unrelated to any held before the loss; the language has no reconnection concept. `send` has no delivery guarantee beyond best-effort while the peer is reachable; in-flight messages to a peer at the moment of loss are dropped without notification.

## 11. Toolchain

### 11.1 `ernc` (compiler)

`ernc [-o build-dir] file.ern` compiles a module to `file.erc` — a compiled module the runtime can load, carrying the inferred types of the module's qualified declarations so dependent modules can be type-checked against it. `ernc [-o build-dir] src-dir` compiles every `.ern` file under `src-dir` in dependency order, mirroring the source tree into `build-dir`. The output directory (and any missing intermediate subdirectories under it) is created if absent. A program is compiled module by module in dependency order; cross-module references link at load.

**Path shape.** Below any source or build root, every directory component and every `.ern`/`.erc` filename stem must exactly match the lowercase of a valid Ernest typename — a lowercase letter followed by lowercase letters, digits, and underscores. Extensions are exactly `.ern` and `.erc`. `ernc` rejects a source path whose components fail this rule (`lib/Net/http.ern` errors: "path component `Net` must be lowercase"). The rule applies below the root, not to the root itself; `Lib/net/http.ern` is fine.

### 11.2 `ern` (runner)

`ern [--config-dir dir] [-pa dir ...] file.erc` loads the module and, on demand, the compiled modules on the load path, found by namespace: the compiled module for namespace `A.B.C` is `a/b/c.erc` on the load path, where each path segment is the lowercase of the corresponding namespace segment. `Net.Http.parse` is looked up at `net/http.erc`. The runner starts the system processes, binds their addresses to the `Sys.*` top-level references, and calls `main`. The standard library, Appendix E, is on the load path by default; `-pa` extends it. The runner enforces the same path-shape rule as `ernc` (§11.1) on load-path directories: any `.erc` file or directory component below a load-path root whose name is not the exact lowercase of a valid Ernest typename is rejected.

`ern --repl` starts a read-evaluate-print loop with the same loading. `--config-dir` names the configuration directory, `./.ernest` by default.

### 11.3 Configuration setup

`ern --create-config-dir dir` creates `dir/.ernest/` containing `ernest.conf` and this node's private key, readable only by its owner, and does nothing else; it fails if the directory exists. `ernest.conf` holds this node's network address and public key, and the list of peers: for each, a name, a network address, a public key, and whether it accepts remote computation. Appendix C shows one. The names are the ones `Peer(name)` refers to.

### 11.4 Documentation extraction

`ernc --doc file.ern` writes the doc comments extracted from `file.ern` to stdout as Markdown, grouped by declaration.

## Appendix A. Grammar

```
Program     = { Declaration } .
Declaration = [ "export" ] ( TypeDecl | AbstractDecl | FnDecl | LetDecl | ForeignDecl ) .
ForeignDecl = "foreign" ( "type" typename [ "(" typevar { "," typevar } ")" ]
            | "fn" DeclName "(" [ Param { "," Param } ] ")" Return "=" string ) .

TypeDecl    = "type" typename [ "(" typevar { "," typevar } ")" ] "="
              Constructor { "|" Constructor } .
Constructor = conname [ "(" ( Type | Field { "," Field } ) ")" ] .
Field       = ident ":" Type .
AbstractDecl  = "abstract" TypeDecl "with" "{" Signature { ";" Signature } "}" .
Signature   = ( ident | binop ) ":" Type .

FnDecl      = "fn" DeclName "(" [ Param { "," Param } ] ")" [ Return ] "=" Expr .
Param       = Pattern [ ":" Type ] .
Return      = "->" Type [ "with" Type ] .
LetDecl     = "let" DeclName [ ":" Type ] "=" Expr .
Binding     = "let" Pattern [ ":" Type ] ( "=" | "<-" ) Expr .
DeclName    = [ typename "." ] ( ident | binop ) .

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

`binop` and `literal` are defined in section 2, along with the other lexical categories; `binop` precedence follows the table there. Every nonterminal is decided by its first token: `let` begins a binding, `fn` a declaration or lambda, `{` a block, `[` a list, `#(` a tuple, `(` a call or parenthesized expression, `<<` a bitstring. In `QName`, after each uppercase token the next token decides: `.` continues the qualification; otherwise the segment is final, and a lowercase final is a function or operator, an uppercase final a constructor. A constructor's fields are positional or named by whether `=` or `:` follows the first identifier. When a constructor name is immediately followed by a parenthesized constructor argument, the parser consumes that argument in the constructor branch of `QName`; a single-positional construction has the semantics of calling the constructor's function value. `conname` and `typename` are one token class; which one a segment is follows from its position.

## Appendix B. Examples

The counter of section 6, with a `main` that exercises `Inc` and `Get`. `Upgrade` is not exercised here; it is covered by the fragment in section 6.

```
type CounterMsg
    = Inc(Int)
    | Get(reply : Reply(Int))
    | Upgrade(migrate : (Int) -> Int, next : (Int) -> Void with CounterMsg)

fn main() -> Void with m = {
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
type MainMsg = PongDone(Down)

fn main() -> Void with MainMsg = {
    let pongAddr = spawn(Local, fn() = pong());
    let _ = spawn(Local, fn() = ping(pongAddr, 3));
    monitor(pongAddr, PongDone);
    receive { PongDone(_) -> Void }
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

A shim over Erlang's `ets`, tables of type `set`. Raw bindings are module-local (unqualified); the library is ordinary Ernest over them. The BEAM values `ets` returns line up with Ernest's ABI (§8.4) here without an Erlang-side wrapper: `true` and `false` are `Bool` on both sides, and Erlang's `[{K, V}]` matches `List(#(k, v))`. Erlang's `{ok, V} | {error, R}` convention uses lowercase atoms `ok` and `error`, which under §8.4 do *not* map to Ernest's `Ok(v)` / `Error(r)` constructors (whose canonical encoding is `{'Ok', v}` / `{'Error', r}`, quoted and source-preserving). A shim that wants `Either` from a `{ok, _} | {error, _}` API therefore decodes the raw return with a `match` (or wraps the call in an Erlang helper that produces the quoted-atom form). The `ets` calls used below don't use that convention, so no adapter is needed here.

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
export fn insert(t : Table(k, v), key : k, value : v) -> Void with m = {
    let _ = rawInsert(t, #(key, value));
    Void
}

foreign fn rawInsert(t : Table(k, v), row : #(k, v)) -> Bool with m = "ets:insert/2"

/// The value for key, or None if absent.
export fn lookup(t : Table(k, v), key : k) -> Optional(v) with m =
    match rawLookup(t, key) { [#(_, v)] -> Some(v) | _ -> None }

foreign fn rawLookup(t : Table(k, v), key : k) -> List(#(k, v)) with m = "ets:lookup/2"

/// Remove key. A key not present is not an error.
export fn delete(t : Table(k, v), key : k) -> Void with m = { let _ = rawDelete(t, key); Void }

foreign fn rawDelete(t : Table(k, v), key : k) -> Bool with m = "ets:delete/2"

/// The number of entries in the table.
export fn size(t : Table(k, v)) -> Int with m = rawInfo(t, atom("size"))

foreign fn rawInfo(t : Table(k, v), item : Foreign) -> Int with m = "ets:info/2"

/// Delete the table. All subsequent operations on it fault.
export fn drop(t : Table(k, v)) -> Void with m = { let _ = rawDrop(t); Void }

foreign fn rawDrop(t : Table(k, v)) -> Bool with m = "ets:delete/1"

/// Remove all entries, leaving the table empty.
export fn clear(t : Table(k, v)) -> Void with m = { let _ = rawClear(t); Void }

foreign fn rawClear(t : Table(k, v)) -> Bool with m = "ets:delete_all_objects/1"

/// True if key is present in t.
export foreign fn member(t : Table(k, v), key : k) -> Bool with m = "ets:member/2"

/// All key-value pairs currently in the table, in unspecified order.
export foreign fn toList(t : Table(k, v)) -> List(#(k, v)) with m = "ets:tab2list/1"
```

```
fn main() -> Void with Never = {
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

The `raw` names have no `export` and are therefore invisible outside the module; the exported `Ets.*` interface is what callers see. `Ets.Table(k, v)` has type parameters the implementation never sees: `Ets.insert(t, "a", 1)` fixes `t` to `Ets.Table(String, Int)`, and an insert with other types on the next line is a type error. Every operation has a mailbox type, `size` and `member` included, because they read state that others write. `atom` is pure: the same text gives the same atom. An Erlang-side module is needed only to catch: a raw function that throws is a fault, and a shim that wants `Either` instead must `try` in Erlang, since Ernest cannot. What the type cannot say, the declaration's documentation must: a table lives until `Ets.drop`, or until the process that created it dies.

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
List.isEmpty     : (List(a)) -> Bool
List.head        : (List(a)) -> Optional(a)
List.last        : (List(a)) -> Optional(a)
List.at          : (List(a), Int) -> Optional(a)
List.reverse     : (List(a)) -> List(a)
List.take        : (List(a), Int) -> List(a)
List.drop        : (List(a), Int) -> List(a)
List.dropLast    : (List(a)) -> List(a)
List.contains    : (List(a), a) -> Bool // requires equality on a (§3.10)
List.find        : (List(a), (a) -> Bool with e) -> Optional(a) with e
List.any         : (List(a), (a) -> Bool with e) -> Bool with e
List.all         : (List(a), (a) -> Bool with e) -> Bool with e
List.map         : (List(a), (a) -> b with e) -> List(b) with e
List.filter      : (List(a), (a) -> Bool with e) -> List(a) with e
List.filterMap   : (List(a), (a) -> Optional(b) with e) -> List(b) with e
List.foldLeft    : (List(a), b, (b, a) -> b with e) -> b with e
List.foreach     : (List(a), (a) -> Void with e) -> Void with e
List.span        : (List(a), (a) -> Bool with e) -> #(List(a), List(a)) with e
List.sort        : (List(a), (a, a) -> Ordering with e) -> List(a) with e
List.remove      : (List(a), a) -> List(a) // requires equality on a (§3.10)
```

### Appendix E.3. `Map.ern`

Container-first operations over `Map(k, v)`.

```
Map.empty        : Map(k, v)
Map.size         : (Map(k, v)) -> Int
Map.isEmpty      : (Map(k, v)) -> Bool
Map.contains     : (Map(k, v), k) -> Bool
Map.get          : (Map(k, v), k) -> Optional(v)
Map.put          : (Map(k, v), k, v) -> Map(k, v)
Map.remove       : (Map(k, v), k) -> Map(k, v)
Map.keys         : (Map(k, v)) -> List(k)
Map.values       : (Map(k, v)) -> List(v)
Map.map          : (Map(k, v), (k, v) -> w with e) -> Map(k, w) with e
Map.foldLeft     : (Map(k, v), b, (b, k, v) -> b with e) -> b with e
```

### Appendix E.4. `Set.ern`

Container-first operations over `Set(a)`.

```
Set.empty        : Set(a)
Set.size         : (Set(a)) -> Int
Set.isEmpty      : (Set(a)) -> Bool
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
String.isEmpty     : (String) -> Bool
String.contains    : (String, String) -> Bool // substring test
String.toInt       : (String) -> Optional(Int)
String.chars       : (String) -> List(Char)
String.fromChars   : (List(Char)) -> String
String.fromUtf8    : (Bytes) -> Optional(String)
String.toUtf8      : (String) -> Bytes
String.lines       : (String) -> List(String)
String.all         : (String, (Char) -> Bool with e) -> Bool with e
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
Float.toString   : (Float) -> String
Float.round      : (Float) -> Int // banker's rounding, IEEE 754 default
Float.floor      : (Float) -> Int
Float.ceil       : (Float) -> Int
```

### Appendix E.10. `Optional.ern`

```
Optional.isSome      : (Optional(a)) -> Bool
Optional.isNone      : (Optional(a)) -> Bool
Optional.withDefault : (Optional(a), a) -> a
Optional.map         : (Optional(a), (a) -> b with e) -> Optional(b) with e
Optional.andThen     : (Optional(a), (a) -> Optional(b) with e) -> Optional(b) with e
```

### Appendix E.11. `Either.ern`

```
Either.isLeft       : (Either(e, a)) -> Bool
Either.isRight      : (Either(e, a)) -> Bool
Either.withDefault  : (Either(e, a), a) -> a
Either.map          : (Either(e, a), (a) -> b with x) -> Either(e, b) with x
Either.mapLeft      : (Either(e, a), (e) -> f with x) -> Either(f, a) with x
Either.andThen      : (Either(e, a), (a) -> Either(e, b) with x) -> Either(e, b) with x
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
- **`Never`** — the type with no values. As a mailbox type it is the canonical send-only marker: the process cannot receive anything, and a `receive` in it is a type error. §3.7, §6.8.
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
- **reserved word** — one of seventeen keywords. §2.4.
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
