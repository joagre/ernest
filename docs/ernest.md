# Ernest: Language Report

September 2026. Rationale, rejected alternatives, and open questions are in `ernest-decisions.md`.

## 0. Introduction

Ernest is a functional language for concurrent programs. It has two concepts: functions, with Hindley-Milner types and full inference, and processes, with typed messages, as the only way to affect the world. Everything else in this report is a rule for how the two show up in each other.

Every function runs inside a process: an execution of a function, with a mailbox of its own that receives values of one type. A function either acts through its process, by sending, receiving, or asking who it is, or it does not. A function that does not is called pure: its result depends only on its arguments, and it affects nothing. A function that acts through its process names its mailbox in its type, `(A) -> B with M`; `M` is the function's mailbox type, and it is the only mark a function type carries. Sections 3 and 6 make this precise. The runtime is what runs Ernest programs; section 10 states what it must provide.

The language is built on five principles, in order. The reader comes first.

1. Least surprise decides — measured by the resulting code, not by the rule.
2. One way, one job — in the language and prelude. No variants for the same thing, no two concepts that overlap in what they express, unless what remains surprises more. The standard library, being ordinary Ernest code, may pair functions for convenience.
3. Nothing invisible. Control flow, communication, and failure are visible in the code or in the type. An ambient value is visible when its name appears at the use site; a hidden effect is not.
4. Simple to parse: recursive descent, first-token dispatch, small bounded lookahead where the grammar demands it, no backtracking.
5. Small: few concepts, few primitives, few reserved words — but not too few.

## 1. Notation

The grammar is written in EBNF. `=` defines, `|` separates alternatives, `[ ]` is optional, `{ }` is zero or more, `( )` groups, `.` ends a rule. Terminals are quoted. `ident`, `conname`, `typename`, `typevar`, and the literals are defined in section 2. The complete grammar is in Appendix A.

## 2. Lexical Elements

**Characters.** Source text is Unicode in UTF-8. Whitespace separates tokens and has no other meaning; line breaks mean nothing.

**Comments.** `//` to end of line and `/* ... */` (which nests) are removed by the lexer and take part in no grammar rule. `///` to end of line is a doc comment; consecutive `///` lines form a doc block. A doc block immediately preceding a declaration, with no blank line between, is attached to that declaration as documentation, extractable by the toolchain, section 11. Doc blocks elsewhere are ordinary comments.

**Identifiers.** `ident` begins with a lowercase letter or `_` and continues with any number of letters, digits, and `_`; `conname` and `typename` begin with an uppercase letter and continue the same way, and are lexically the same token; `typevar` is a lowercase identifier in type position. A qualified name is a sequence of uppercase-starting segments (each is a `typename`) followed by a final segment that starts either lowercase (a function, operator, or variable) or uppercase (a constructor): `Net.Http.parse`, `Stack.push`, `Int.+`, `ServerMsg.Get`. The dots are namespaces, section 4.

**Reserved words.** Sixteen: `type`, `opaque`, `with`, `match`, `when`, `if`, `then`, `else`, `recv`, `after`, `fn`, `let`, `foreign`, `as`, `true`, `false`.

**Literals.**

```
int      = digit { digit } .
float    = digit { digit } "." digit { digit } [ ( "e" | "E" ) [ "-" ] digit { digit } ] .
char     = "'" ( character | escape ) "'" .
text     = '"' { character | escape } '"' .
escape   = "\\" ( "'" | '"' | "\\" | "n" | "t" | "u{" hexdigit { hexdigit } "}" ) .
bool     = "true" | "false" .
```

`1` is `Int`, `1.0` and `1.0e-9` are `Float`. Literals carry no sign; `-` is a prefix operator. No overloaded literals and no default. The escapes are the six listed; a `character` is any code point other than the enclosing quote and `\`: in a `char` literal other than `'` and `\`, in a `text` literal other than `"` and `\`.

**Operators and delimiters.**

```
( ) { } [ ] << >> , ; : = <- -> | .. _
+ - * / % ++ +: == != < <= > >= && || |>
```

Prefix `-` is negation on `Int` and `Float`. Precedence of the binary operators, highest first: `* / %`, `+ - ++`, `+:` (right-associative), `== != < <= > >=`, `&&`, `||`, `|>`. All but `+:` are left-associative. An operator name can be qualified, `Int.+`, section 4. `|>` is not qualifiable — it is a syntactic form (section 5), not a namespaced function.

## 3. Types

```
Type      = FnType | TypeAtom .
TypeAtom  = { typename "." } typename [ "(" Type { "," Type } ")" ]
          | typevar
          | "(" Type "," Type { "," Type } ")"
          | "()" .
FnType    = "(" [ Type { "," Type } ] ")" "->" Type [ "with" Type ] .
```

**Base types.** `Int`, integers of arbitrary precision. `Float`, IEEE 754 double precision. `Char`, one code point. `Text`, a Unicode string. `Bytes`, a sequence of octets. `Bool`, with the literals `true` and `false`. `()`, the unit type with the single value `()`. There are no type aliases.

**Tuples.** `(A, B)` with two or more components. The tuple is the only positional product type.

**Lists.** `List(a)` is an immutable linked list. `[]` is the empty list. `x +: xs` prepends `x` to `xs`; `+:` is right-associative, so `[a, b]` is `a +: b +: []`.

**Function types.** `(A, B) -> C` is the type of a function of two arguments. Arity is part of the type: `(A, B) -> C` and `((A, B)) -> C` are different types. `() -> C` takes no arguments. `with M` after the result is the mailbox type: the function uses the process it runs in, whose mailbox has type `M`, section 6. A function type without a mailbox type is pure. `with` binds to the nearest arrow; `(A) -> (B) -> C with M` is a pure function returning a function with mailbox type `M`.

**Sum types.** Declared with `type`, section 4. A constructor has no payload, exactly one positional payload, or named fields:

```
type Optional(a) = None | Some(a)
type Snapshot = Snapshot(dir : Path, seen : Map(Path, Mtime))
```

Two or more positional fields are not allowed. Field names are unique within a constructor; their order carries no meaning. Positional and named payloads are distinguished by `:` after the first identifier in declarations, and by `=` in construction and patterns.

**Opaque types.** A sum type whose constructors may be mentioned only in the functions listed in the type's signature, section 4.

**Built-in types.** `Address(m)`, an address of a process that receives `m`. `Reply(a)`, a one-shot address for the answer to a request, section 6. `Never`, the type with no values. The prelude types, section 9.

**Foreign types.** A type declared `foreign type T` has no constructors: its values are made and used only by foreign functions, section 4, and can otherwise be held, passed, and sent. A foreign value is bound to the node that made it: `spawn(Peer(...), f)` or `send` to a remote address is a fault when the payload transitively contains a foreign value, including a closure that captures one, with cause `Fault("foreign value cannot cross nodes")`. Equality on a foreign type is identity.

**Type variables and polymorphism.** Types are inferred according to Hindley-Milner. A `fn` definition is generalized over its free type variables; a binding is not. Type variables in a `fn` signature scope over the whole definition. Recursive and mutually recursive types are allowed. Polymorphic recursion is not. Every type variable in a constructor's payload must be a parameter of the type.

**Equality.** `==` and `!=` are defined for all values except those containing functions or addresses; on those, `==` is a type error. Equality is structural. Ordering is defined per type by the function `compare` in the type's namespace, `Int.compare : (Int, Int) -> Ordering`.

**Serialization.** All values can be sent in messages, functions included; their code travels with them, section 10.

## 4. Declarations and Scope

```
Program     = { Declaration } .
Declaration = TypeDecl | OpaqueDecl | FnDecl | LetDecl | ForeignDecl .
ForeignDecl = "foreign" ( "type" QTypeName [ "(" typevar { "," typevar } ")" ]
            | "fn" Name "(" [ Param { "," Param } ] ")" Return "=" text ) .
TypeDecl    = "type" QTypeName [ "(" typevar { "," typevar } ")" ] "="
              Constructor { "|" Constructor } .
Constructor = conname [ "(" ( Type | Field { "," Field } ) ")" ] .
Field       = ident ":" Type .
OpaqueDecl  = "opaque" TypeDecl "with" "{" Signature { ";" Signature } "}" .
Signature   = ( ident | binop ) ":" Type .
FnDecl      = "fn" Name "(" [ Param { "," Param } ] ")" [ Return ] "=" Expr .
Param       = Pattern [ ":" Type ] .
Return      = "->" Type [ "with" Type ] .
LetDecl     = "let" Name [ ":" Type ] "=" Expr .
Binding     = "let" Pattern [ ":" Type ] ( "=" | "<-" ) Expr .
Name        = { typename "." } ( ident | binop ) .
QTypeName   = { typename "." } typename .
```

**Modules.** A *module* is a single Ernest source file, ending in `.ern`. It is the unit of compilation and the unit that carries a namespace; every top-level declaration belongs to exactly one module.

**Namespaces and visibility.** The namespace is in the name, and so is the visibility. A top-level declaration with a qualified name, `fn Net.Http.parse(b) = ...`, `type Net.Http.Request = ...`, is visible throughout the program under that name; two such declarations with the same full name are an error. A top-level declaration with an unqualified name, `fn helper(x) = ...`, is visible only in its own module. A module's path is its namespace: the qualified declarations in `Net/Http.ern` begin with `Net.Http.`, and may go deeper, `Net.Http.Header.parse`. That is the whole of a module's meaning, and there is no export list, no `pub`, and no `import`. Sub-namespaces are the dots; namespace segments are type names. An unqualified name in a body is looked up first among the module's unqualified declarations, then in the namespace of the enclosing declaration, then in the prelude; everything else must be qualified. The only other thing hidden is the constructor of an opaque type from definitions outside its signature. `main` is unqualified, section 8.

**Type declarations.** `type` declares a sum type with its constructors. A constructor has the visibility of its type.

**Opaque types.** `opaque type T = ... with { s1; s2 }` declares a type whose constructors may appear only in the definitions of the names given by the signatures. The names live in `T`'s namespace: the signature `push : (a, Stack(a)) -> Stack(a)` refers to `Stack.push`. The definitions are checked against the signatures and do not repeat the type. The constructor outside these definitions is a type error. The signature delimits who sees the constructor, not which functions may exist for the type.

```
opaque type Stack(a) = Stack(List(a)) with {
    empty : Stack(a);
    push : (a, Stack(a)) -> Stack(a);
    pop : (Stack(a)) -> Optional((a, Stack(a)))
}

let Stack.empty = Stack([])
fn Stack.push(x, Stack(xs)) = Stack(x +: xs)
fn Stack.pop(Stack(xs)) = match xs { [] -> None | x +: rest -> Some((x, Stack(rest))) }
```

**Functions.** `fn` declares a function of fixed arity. Annotations may be omitted where they can be inferred. The return annotation has three forms: omitted, `-> T` for a pure function, `-> T with M` for process code. A pure annotation on a function that calls process code is a type error. A function has one clause. Patterns in parameters must be irrefutable, section 5, `fn seenCount(Snapshot(seen = entries) : Snapshot) -> Int = Map.size(entries)`. `fn` may appear at top level and as a statement in a block; it sees its own name, and `fn` declarations in the same block or at top level may refer to each other mutually.

**Bindings.** In a block, `let p = e` binds the pattern `p` to the value of `e`; `let p <- e` is described in section 5. The pattern must be irrefutable. A binding is monomorphic and does not see its own name. Shadowing is allowed: a later binding of the same name hides the earlier one from the next statement on, and the right-hand side sees the earlier one. At top level, a `let` binds a `Name` — possibly qualified — to a value, `let Stack.empty = Stack([])`; the LHS is a name, not a pattern, and `<-` is a block form only.

**Foreign declarations.** `foreign type T` declares a type implemented outside the language. `foreign fn f(params) -> T = "impl"` declares a function whose body is the implementation named by the string, in the runtime's language; parameters and the return are annotated. A foreign function with a mailbox type, `-> T with m`, may do anything; a foreign function without one promises purity: the same result for the same arguments and no effect on anything. The implementation promises the declared types; a value of another shape, or an exception, is a fault, section 7. Foreign code sees values in the runtime's representation, section 10.

**Operators.** An operator name is resolved against the operand type: `+` in `a + b` with `a : Int` means `Int.+`. Both operands must have the same type. Resolution happens before generalization; a function whose operands do not get their type from an annotation, a literal, a pattern, or a call in the same definition is a type error that requires an annotation. Every namespace may define operators for its type. There is no type "number" to generalize over.

## 5. Expressions

```
Expr      = Lambda | IfExpr | MatchExpr | RecvExpr | BinExpr .
Lambda    = "fn" "(" [ Param { "," Param } ] ")" [ Return ] "=" Expr .
IfExpr    = "if" Expr "then" Expr "else" Expr .
MatchExpr = "match" Expr "{" Arm { "|" Arm } "}" .
Arm       = Pattern [ "when" Expr ] "->" Expr .
RecvExpr  = "recv" "{" ( Arm { "|" Arm } [ "|" AfterArm ] | AfterArm ) "}" .
AfterArm  = "after" Expr "->" Expr .
BinExpr   = Unary { binop Unary } .
Unary     = [ "-" ] Primary { Call } .
Call      = "(" [ Expr { "," Expr } ] ")" .
Primary   = literal | QName | Tuple | "()" | ListLit | Block | "(" Expr ")" .
QName     = { typename "." } ( ident | binop | conname [ "(" ( Expr | Fields ) ")" ] ) .
Fields    = ".." Expr "," FieldSet { "," FieldSet } | FieldSet { "," FieldSet } .
FieldSet  = ident "=" Expr .
Tuple     = "(" Expr "," Expr { "," Expr } ")" .
ListLit   = "[" [ Expr { "," Expr } ] "]" .
Block     = "{" Stmt { ";" Stmt } "}" .
Stmt      = FnDecl | Binding | Expr .
Pattern   = ConsPat [ "as" ident ] .
ConsPat   = AtomPat [ "+:" ConsPat ] .
AtomPat   = "_" | ident | literal | { typename "." } conname [ "(" ( Pattern | FieldPats ) ")" ]
          | "(" Pattern "," Pattern { "," Pattern } ")" | "()"
          | "[" [ Pattern { "," Pattern } ] "]" .
FieldPats = [ ident "=" Pattern { "," ident "=" Pattern } ] .
```

**Evaluation.** Strict, left to right, arguments before the call. No delayed computation; `fn() = e` defers `e`. Prefix `-` is `Int.negate` or `Float.negate` by the operand type.

**Calls.** `f(x, y)` supplies all arguments. A call with the wrong number of arguments is a type error on the calling line; a call never yields a partially applied function. An expression whose value is a function can be called directly: `makeAdder(3)(4)`.

**Lambda.** `fn(x) = e` is an anonymous function. Its body is the longest `Expr` at the same nesting level as the `fn`, ending at the first outer `,`, `;`, `|`, `)`, or `}`.

**Blocks.** `{ s1; s2; e }` is an expression whose value is the last statement, which must be an expression. `;` separates statements and never appears last. Statements are `fn` declarations, `let` bindings, and expressions; an expression as a statement is evaluated for its effect.

**Binding with `<-`.** In a block, `let p <- e; rest` means that `e` is matched: on `Right(v)`, `p` is bound to `v` and `rest` is evaluated; on `Left(err)`, the block's value is `Left(err)`. If the block's type is `Optional`, `Some` and `None` apply the same way. The block's type decides which, resolved from the type of `e` as operators are; `rest` must have the block's type. All `<-` bindings in the same block resolve to the same sum type — the block is either `Either` or `Optional`, not both. The rewrite is local to the block.

**Construction.** `Some(e)`, `None`, `Snapshot(dir = d, seen = s)`. All fields must be given. `Snapshot(..p, seen = s)` takes unlisted fields from `p`; at least one field follows `..`. A constructor is qualified like a function, `Net.Http.Request(...)`. A nullary constructor is a value, a single-positional constructor is a function value, and named constructors are neither: they only appear in construction syntax. Qualified operators are function values, `Int.+`.

**Pipe.** `x |> e` treats `e` as a function value or a call and applies it with `x` inserted as an additional first argument: `x |> f` is `f(x)`; `x |> f(a, b)` is `f(x, a, b)`. The pipe reads left to right, which suits stdlib call chains where each function's first argument is the value being transformed:

```
let words = input |> Text.trim |> Text.toLower |> Text.chars
```

`|>` is left-associative and lowest-precedence, below `||`: `a + b |> f` is `f(a + b)`, and `a |> b |> c` is `c(b(a))`. The right-hand side may be a name, a qualified name, a lambda, or a call whose first-argument slot the pipe fills. The type of `x` must match the target function's first argument.

**Conditional.** `if c then a else b` with `c : Bool`; the branches have the same type.

**`match`.** The expression is matched against the arms' patterns in order; the first arm whose pattern matches and whose guard holds is evaluated. A failed guard falls through. The arms together must cover the type; guards do not count as coverage. Variables in the pattern are bound in the guard and the arm.

**Patterns.** A pattern decomposes a value and binds its parts. The same patterns appear in `let`, in `match` and `recv` arms, and in function parameters. `_` matches anything and binds nothing. An identifier binds the whole value at its position to a new variable, shadowing any outer variable of that name; it never refers to an existing variable. A literal matches itself. A constructor with a pattern, `Some(p)`, or with field patterns, `Snapshot(seen = s)`, which may omit fields, matches that constructor and decomposes its payload. A tuple, a list `[p, q]`, and `p +: q` decompose those. Patterns nest to any depth: `Some((x, Snapshot(dir = d)))`. `p as c` binds `c` to the whole value that `p` matches, `Some(Snapshot(dir = d) as snap)`; `as` binds loosest, so `x +: rest as all` names the whole list. Each variable appears at most once in a pattern; a pattern does not compare, and equality is written in a guard. A pattern is irrefutable if it cannot fail: `_`, an identifier, a tuple of irrefutable patterns, or a constructor pattern of a type with exactly one constructor whose sub-patterns are all irrefutable. `let` and parameters require irrefutable patterns; `let Right(x) = e` is a type error.

**Bit arrays.** `<<...>>` constructs and pattern-matches a `Bytes` value at the bit level. A bit array is a comma-separated list of segments between `<<` and `>>`; each segment is a value (in construction) or a pattern (in `match`), followed optionally by a colon and a dash-separated list of specifiers. Specifiers are: `size(N)` for segment width in units, `unit(N)` for bits per size unit (default 1), `bits` and `bytes` for nested bit arrays, `int` (default 8-bit) and `float` (default 64-bit) for numeric segments, `utf8`/`utf16`/`utf32` for text encoding, `big`/`little`/`native` for endianness, and `signed`/`unsigned` for sign. These specifier names carry that role only inside a bit array — outside, they are ordinary identifiers, and the reserved-word count remains sixteen. A bit-array pattern binds its segment variables; a segment whose length is `size(n)-bytes` and whose `n` refers to an earlier bound variable is a size-dependent match, common in protocol parsing. Constructing a bit array evaluates its segments left to right and concatenates them into a `Bytes` value; a segment whose value does not fit its specified width is a fault. An empty `<<>>` is the empty `Bytes`.

```
fn frame(len : Int, body : Bytes) -> Bytes =
    <<len:size(16)-big, body:bytes>>

fn parseFrame(bytes : Bytes) -> Optional((Int, Bytes, Bytes)) = match bytes {
    <<len:size(16)-big, body:size(len)-bytes, rest:bytes>> -> Some((len, body, rest))
  | _ -> None
}
```

`frame` constructs: it builds a `Bytes` value with a 16-bit big-endian length followed by the body. `parseFrame` matches the inverse: match a 16-bit big-endian length, then `len` bytes of body, then whatever is left. The runtime compiles bit arrays directly to BEAM's bit syntax, section 10, so the optimizer handles prefix-heavy protocol matches as it would in native BEAM code.

## 6. Processes

A process is an execution of a function with a mailbox type. It has a mailbox that receives values of that type, in arrival order per sender.

**The mailbox type.** `(A) -> B with M` is the type of a function that acts through the process it runs in, whose mailbox has type `M`. Every call runs in some process; the mailbox type marks that the function uses that process: its own `send`, `recv`, and `self`, or a foreign function with a mailbox type. It does not mark the fact of running in one. The mailbox type is inferred: a function that calls a function with mailbox type `M` gets mailbox type `M`. Two different mailbox types in the same function is a type error. A function without a mailbox type is pure: it neither sends, receives, nor calls foreign code with a mailbox type, and it can be called from any process. A pure higher-order function runs its function arguments in the caller's process: `List.map(xs, fn(x) = send(a, x))` has a mailbox type. Nothing else can be marked on a function type.

**Built-in functions.**

```
self  : () -> Address(m) with m
send  : (Address(a), a) -> () with m
spawn : (Where, () -> () with n) -> Address(n) with m

type Where = Local | Peer(Text)
```

`self()` is the process's own address. `send(a, v)` places `v` in the mailbox of `a` and returns immediately; sending to a process that has died has no effect. `spawn(w, f)` starts a new process that runs `f()` and returns its address; `self()` inside `f` is the new process's address; a parent that wants replies binds `let me = self();` before `spawn`. A node is one running instance of the runtime; a peer is another node it knows by name, section 8. `w` places the process: `Local` on the running node, `Peer(name)` on the peer with that name. An unknown or unreachable peer is a fault. The captured values of `f` are copied to the peer.

**`recv`.** `recv { arms }` is a match over the mailbox. The mailbox is scanned in arrival order; the first message that matches some arm is removed, the rest remain, and the arm is evaluated. If none matches, the process waits until one arrives. Patterns are typed against the mailbox type. Coverage is not required, unlike in `match`; a message no arm matches stays in the mailbox, so that a `recv` can wait for a specific reply in the middle of a protocol without losing other messages. A final arm `after t -> e` gives a time limit in milliseconds, evaluated on entry; after `t` without a matching message, `e` is evaluated. `after 0` does not wait for new messages. Without `after` there is no limit.

**Ordering.** Messages from one process to another are received in sending order. Between different senders there is no ordering.

**Addresses.** `Address(m)` identifies a process on a node and carries its protocol: `send(a, v)` is type-checked against `m` and is the same on every node. `via(f, addr)`, section 9, is the address `addr` seen through `f : (a) -> b`: sending `v` to `via(f, addr)` is sending `f(v)` to `addr`. A single-request answer uses `Reply(a)`, below; `via(Wrap, self())` gives a wrapper address for a process that receives replies in its own mailbox. Addresses have no equality; identity is expressed in the protocol. There is no registry: a process reaches another only through an address it holds or received in a message, and possession of the address is the permission to send.

**Request-reply.** A `Reply(a)` is a one-shot address for the answer to a request; unlike `Address(a)`, it is answered exactly once and cannot be stored.

```
Address.call        : (Address(m), (Reply(a)) -> m, Int) -> Optional(a) with n
Address.callForever : (Address(m), (Reply(a)) -> m) -> a with n
answer              : (Reply(a), a) -> () with m
```

`Address.call(addr, mk, ms)` allocates a fresh `Reply(a)`, calls `mk(r)` to build the message, sends it to `addr`, and returns `Some(v)` when the recipient answers or `None` after `ms` milliseconds. `Address.callForever(addr, mk)` is the same operation without a timeout: the caller waits as long as needed and receives `a` directly, not wrapped in `Optional`; the caller is opting out of the timeout by name, analogous to a `recv` without `after`. `answer(r, v)` sends `v` to the caller. A `Reply(a)` value appears only at these positions: a field of a message, a parameter of a function, a variable bound in a `recv` arm, and a value captured by a lambda passed to `spawn`. Any other position is a type error: a `Reply` in a container, in a `match` or `let` binding, in a return type not itself a message, or as an operand of equality, is rejected by the compiler. A `Reply(a)` bound in a `recv` arm is consumed exactly once on every path of the arm's expression. Consumption is `answer(r, v)`, sending `r` as a field of a message, or capturing `r` in a lambda passed to `spawn`; in the last case the captured `Reply` is consumed on every path of the spawned function's body, checked at its definition. A violation is a type error. The check is static: it ensures every path calls `answer` (or delegates or spawns) but not that execution reaches the call at runtime — non-termination, a fault, or an indefinite wait bypasses the answer. The mandatory timeout on `Address.call` returns `Optional(a)` so an answer that never arrives has somewhere to land; `Address.callForever` opts out of that by name, and the caller accepts that this call may hang. Under the hood the `Reply(a)` carries a fresh identifier so that `Address.call` receives only the answer to its own request; the caller's mailbox type is unaffected.

**Remote computation.** A pure function can be evaluated on another node:

```
remote         : (() -> a) -> Either(RemoteError, a)
parallelRemote : (List(() -> a)) -> List(Either(RemoteError, a))
type RemoteError = NoRemotePeer | PeerLost
```

`remote(f)` evaluates `f()` on a peer the runtime chooses among those configured for remote computation, and returns the value. Which peer, and by what criterion, the language does not say. `f` is pure and so is `remote`: the result depends on `f` alone, and the caller waits as it would for any computation. `Left(NoRemotePeer)` if no peer is configured; `Left(PeerLost)` if the peer disappears before the value returns.

`parallelRemote(fs)` runs the functions in `fs` on peers in parallel and returns the results in the input order, one `Either` per input. It is pure by the same reasoning as `remote`: the result depends on the inputs alone. The runtime picks peers and schedules the calls; a caller that needs richer control — cancellation, per-task timeouts, interleaved arrivals — spawns processes itself.

**`Never`.** A function with mailbox type `Never` can send but never receive; a `recv` in it is a type error.

**Death.** A process dies when its function returns, when `kill` is called on it, on a fault, section 7, or when the node it runs on is lost. `monitor(a, wrap)`, section 9, causes `wrap(d)` to be placed in the caller's mailbox when `a` dies, where `d : Down` gives the cause. There are no other links.

**Code replacement.** A process replaces its code by a message in its own type that carries the new loop, and switches with a tail call:

```
type CounterMsg
    = Inc(Int)
    | Get(reply : Reply(Int))
    | Upgrade(migrate : (Int) -> Int, next : (Int) -> () with CounterMsg)

fn counter(n : Int) -> () with CounterMsg = recv {
    Inc(k) -> counter(n + k)
  | Get(reply = r) -> { answer(r, n); counter(n) }
  | Upgrade(migrate = m, next = k) -> k(m(n))
}
```

The language has no other mechanism for code replacement.

## 7. Errors

There are no exceptions. An error is a value, a message, or a fault.

- **A value**, when the error is part of the function's meaning. Expressed in the return type: `Either(e, a)` with an error type `e`, or `Optional(a)`. The caller matches, or chains with `let p <- e`.
- **A message**, when the error crosses a process boundary. Expressed in the message: `Either` or a dedicated constructor in the reply type. A missing reply is `after` in `recv`. The error type across the boundary is its own, distinct from the function's.
- **A fault**, when the code cannot see it. Out of memory, `kill`, a failure in the runtime, a broken promise by foreign code. The process dies with a structured cause in `Down`. Nothing is caught. "Fault" here is the category — any death whose `Reason` is not `Returned`; `Fault(Text)` is one specific `Reason` alongside `Killed` and `ProgramEnd`.

The prelude is total: no built-in function faults. Partial operations return `Optional` or `Either`. A fault is therefore always something that happened to the process, never something it did, with three deliberate exceptions: `/` and `%` on `Int` with a zero divisor fault, `Fault("division by zero")`; `todo("...")`, which compiles at any type and faults if reached, `Fault("todo: ...")`, so that an unfinished function can be declared before it is written; and `spawn(Peer(...), f)` or `send` to a remote address when the payload transitively contains a foreign value, `Fault("foreign value cannot cross nodes")`, section 3. `Int.div` and `Int.mod` return `Optional` for the caller who wants to handle it.

## 8. Programs

**`main`.** A program is a set of modules with exactly one function `main : () -> () with m` for some `m`, unqualified, called by the runtime. Nothing sends to `main` that it has not given its address to; `m` is usually `()`.

**System references.** The runtime starts with its system processes and exposes their addresses as ambient top-level values in the `Sys` namespace. The language requires `Sys.stdout : Address(Text)` and `Sys.clock : Address(ClockMsg)`, section 9; a specific runtime may provide more, and a paper program that needs additions like `Sys.fs`, `Sys.stdin`, `Sys.keys`, or a stderr sink names them in its assumptions. These are values, not functions — like `List`, `Map`, and `Set` they are in scope everywhere at the top level. To do IO a function sends to one, and `send` requires a mailbox effect on the caller (section 6), so pure code cannot affect anything outside its process even though it can name the address. A reference to a `Sys.*` name the runtime does not provide is a name-resolution error at compile time. The `stdout` process writes each received `Text` to standard output as bytes; newlines are the sender's responsibility.

**Peers.** Peers are configured outside the language, section 11; `Peer(name)` refers to them by the configured name, and nodes authenticate each other.

**Foreign code.** The system processes are foreign processes: their message types are declared in Ernest, their implementations live outside the language, and the runtime starts them and binds their addresses to the `Sys.*` ambient references. Other foreign code enters through `foreign fn` and `foreign type`, section 4. Both boundaries carry the same promise: the foreign side delivers the declared types, and a breach is a fault.

**Program termination.** The program ends when `main` returns. Live processes then die with cause `ProgramEnd`; system processes release their resources. A program that is to keep running waits in `main`. If no process can run, all are waiting in `recv` without `after` and no messages are in flight, the runtime ends the program with the error `Deadlock`. A pending `after` or clock counts as a message in flight.

## 9. Prelude

The prelude is small: only what this report names. Convenience libraries — including all container operations, text and numeric utilities, and output helpers — live in the standard library, Appendix E.

Built-in types (section 3):

```
Address(m)   // an address of a process that receives m
Reply(a)     // a one-shot address, section 6
Never        // the type with no values
```

Built-in parameterized types, provided by the runtime:

```
List(a)      // an immutable linked list of elements of type a
Map(k, v)    // an immutable dictionary from k to v; requires equality on k
Set(a)       // an immutable set of a; requires equality on a
```

Declared types:

```
type Optional(a) = None | Some(a)
type Either(e, a) = Left(e) | Right(a)
type Ordering = Less | Equal | Greater
type Down = Down(reason : Reason, function : Text)
type Reason = Returned | Killed | ProgramEnd | Fault(Text)
type ClockMsg                                      // times in milliseconds
    = After(ms : Int, to : Address(()))
    | At(at : Int, to : Address(()))
    | Now(reply : Reply(Int))
type RemoteError = NoRemotePeer | PeerLost
type Foreign                                       // a value the language does not inspect
type Where = Local | Peer(Text)                    // spawn placement, section 6
```

Built-in functions (section 6):

```
self  : () -> Address(m) with m
send  : (Address(a), a) -> () with m
spawn : (Where, () -> () with n) -> Address(n) with m
```

Process functions:

```
via                 : ((a) -> b, Address(b)) -> Address(a)
Address.call        : (Address(m), (Reply(a)) -> m, Int) -> Optional(a) with n
Address.callForever : (Address(m), (Reply(a)) -> m) -> a with n
answer              : (Reply(a), a) -> () with m
remote              : (() -> a) -> Either(RemoteError, a)
parallelRemote      : (List(() -> a)) -> List(Either(RemoteError, a))
monitor             : (Address(a), (Down) -> m) -> () with m
kill                : (Address(a)) -> () with m
```

Operations required by the language:

```
Int.div, Int.mod : (Int, Int) -> Optional(Int)     // section 7: / and % fault on zero;
                                                   // Int.div and Int.mod return None instead
Int.compare      : (Int, Int) -> Ordering          // section 3: ordering is per type
Float.compare    : (Float, Float) -> Ordering
Text.compare     : (Text, Text) -> Ordering
Char.compare     : (Char, Char) -> Ordering
todo             : (Text) -> a                     // section 7: faults if reached
```

System references (runtime-provided, section 8):

```
Sys.stdout       : Address(Text)                   // the stdout process
Sys.clock        : Address(ClockMsg)               // the clock process
```

## 10. Runtime Requirements

- Tail calls take constant stack space. The last expression of a block, a `match` arm, and a `recv` arm is in tail position.
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

`ernc file.ern` compiles a module to `file.erc`, a compiled module the runtime can load. A program is compiled module by module; cross-module names are resolved at load.

`ern [--config-dir dir] [-pa dir ...] file.erc` loads the module and, on demand, the compiled modules on the load path, found by namespace, `Net.Http.parse` in `Net/Http.erc`; starts the system processes, binds their addresses to the `Sys.*` ambient references, and calls `main`. The standard library, Appendix E, is on the load path by default; `-pa` extends it. `ern --repl` starts a read-evaluate-print loop with the same loading. `--config-dir` names the configuration directory, `./.ernest` by default.

`ern --create-config-dir dir` creates `dir/.ernest/` containing `ernest.conf` and this node's private key, readable only by its owner, and does nothing else; it fails if the directory exists. `ernest.conf` holds this node's network address and public key, and the list of peers: for each, a name, a network address, a public key, and whether it accepts remote computation. Appendix C shows one. The names are the ones `Peer(name)` refers to.

`ernc --doc file.ern` writes the doc comments extracted from `file.ern` to stdout as Markdown, grouped by declaration.

## Appendix A. Grammar

```
Program     = { Declaration } .
Declaration = TypeDecl | OpaqueDecl | FnDecl | LetDecl | ForeignDecl .
ForeignDecl = "foreign" ( "type" QTypeName [ "(" typevar { "," typevar } ")" ]
            | "fn" Name "(" [ Param { "," Param } ] ")" Return "=" text ) .

TypeDecl    = "type" QTypeName [ "(" typevar { "," typevar } ")" ] "="
              Constructor { "|" Constructor } .
Constructor = conname [ "(" ( Type | Field { "," Field } ) ")" ] .
Field       = ident ":" Type .
OpaqueDecl  = "opaque" TypeDecl "with" "{" Signature { ";" Signature } "}" .
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
            | "(" Type "," Type { "," Type } ")" | "()" .
FnType      = "(" [ Type { "," Type } ] ")" "->" Type [ "with" Type ] .

Expr        = Lambda | IfExpr | MatchExpr | RecvExpr | BinExpr .
Lambda      = "fn" "(" [ Param { "," Param } ] ")" [ Return ] "=" Expr .
IfExpr      = "if" Expr "then" Expr "else" Expr .
MatchExpr   = "match" Expr "{" Arm { "|" Arm } "}" .
Arm         = Pattern [ "when" Expr ] "->" Expr .
RecvExpr    = "recv" "{" ( Arm { "|" Arm } [ "|" AfterArm ] | AfterArm ) "}" .
AfterArm    = "after" Expr "->" Expr .
BinExpr     = Unary { binop Unary } .
Unary       = [ "-" ] Primary { Call } .
Call        = "(" [ Expr { "," Expr } ] ")" .
Primary     = literal | QName | Tuple | "()" | ListLit | BitExpr | Block | "(" Expr ")" .
QName       = { typename "." } ( ident | binop | conname [ "(" ( Expr | Fields ) ")" ] ) .
Fields      = ".." Expr "," FieldSet { "," FieldSet } | FieldSet { "," FieldSet } .
FieldSet    = ident "=" Expr .
Tuple       = "(" Expr "," Expr { "," Expr } ")" .
ListLit     = "[" [ Expr { "," Expr } ] "]" .
BitExpr     = "<<" [ BitSegE { "," BitSegE } ] ">>" .
BitSegE     = Expr [ ":" BitSpec { "-" BitSpec } ] .
Block       = "{" Stmt { ";" Stmt } "}" .
Stmt        = FnDecl | Binding | Expr .

Pattern     = ConsPat [ "as" ident ] .
ConsPat     = AtomPat [ "+:" ConsPat ] .
AtomPat     = "_" | ident | literal | { typename "." } conname [ "(" ( Pattern | FieldPats ) ")" ]
            | "(" Pattern "," Pattern { "," Pattern } ")" | "()"
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

binop       = "*" | "/" | "%" | "+" | "-" | "++" | "+:"
            | "==" | "!=" | "<" | "<=" | ">" | ">=" | "&&" | "||"
            | "|>" .
literal     = int | float | char | text | bool .
```

Precedence for `binop` as in section 2. Every nonterminal is decided by its first token: `let` begins a binding, `fn` a declaration or lambda, `{` a block, `[` a list, `(` a call, tuple, or parenthesized expression. In `QName`, after each uppercase token the next token decides: `.` continues the qualification; otherwise the segment is final, and a lowercase final is a function or operator, an uppercase final a constructor. A constructor's payload is positional or named by whether `=` or `:` follows the first identifier. `conname` and `typename` are one token class; which one a segment is follows from its position.

## Appendix B. Examples

The counter of section 6, with a `main` that exercises `Inc` and `Get`. `Upgrade` is not exercised here; it is covered by the fragment in section 6.

```
type CounterMsg
    = Inc(Int)
    | Get(reply : Reply(Int))
    | Upgrade(migrate : (Int) -> Int, next : (Int) -> () with CounterMsg)

fn main() -> () with () = {
    let c = spawn(Local, fn() = counter(0));
    send(c, Inc(5));
    send(c, Inc(3));
    match Address.call(c, fn(r) = Get(reply = r), 1000) {
        Some(n) -> Io.println("count is " ++ Int.toText(n))
      | None -> Io.println("counter is not answering")
    }
}

fn counter(n : Int) -> () with CounterMsg = recv {
    Inc(k) -> counter(n + k)
  | Get(reply = r) -> { answer(r, n); counter(n) }
  | Upgrade(migrate = m, next = k) -> k(m(n))
}
```

```
type PongMsg = Ping(n : Int, reply : Reply(Int)) | Stop

fn main() -> () with () = {
    let pongAddr = spawn(Local, fn() = pong());
    let _ = spawn(Local, fn() = ping(pongAddr, 3));
    ()
}

fn ping(pongAddr : Address(PongMsg), n : Int) -> () with m =
    if n == 0 then send(pongAddr, Stop)
    else {
        Io.println("ping " ++ Int.toText(n));
        match Address.call(pongAddr, fn(r) = Ping(n = n, reply = r), 5000) {
            Some(_) -> ping(pongAddr, n - 1)
          | None -> { Io.println("pong is not answering"); send(pongAddr, Stop) }
        }
    }

fn pong() -> () with PongMsg = recv {
    Ping(n = n, reply = r) -> {
        Io.println("pong " ++ Int.toText(n));
        answer(r, n);
        pong()
    }
  | Stop -> ()
}
```

```
type WorkerMsg = DoWork(f : (Text) -> Bytes, arg : Text)

fn submitter(worker : Address(WorkerMsg)) -> () with Never = {
    send(worker, DoWork(f = Text.toUtf8, arg = "hello"));
    send(worker, DoWork(f = Text.toUtf8, arg = "world"))
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

A shim over Erlang's `ets`, tables of type `set`. Raw bindings are module-local (unqualified); the library is ordinary Ernest over them. No Erlang module is needed: the representation of values, section 10, already matches Erlang's conventions, `true` is `Bool`, `[{K, V}]` is `List((k, v))`, and `{ok, V} | {error, R}` is a sum type with constructors tagged `ok` and `error`.

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

foreign fn rawNew(name : Text, opts : List(Foreign)) -> Ets.Table(k, v) with m = "ets:new/2"
foreign fn atom(name : Text) -> Foreign = "erlang:binary_to_atom/1"

/// Insert or replace the entry for key.
fn Ets.insert(t : Ets.Table(k, v), key : k, value : v) -> () with m = {
    let _ = rawInsert(t, (key, value));
    ()
}

foreign fn rawInsert(t : Ets.Table(k, v), row : (k, v)) -> Bool with m = "ets:insert/2"

/// The value for key, or None if absent.
fn Ets.lookup(t : Ets.Table(k, v), key : k) -> Optional(v) with m =
    match rawLookup(t, key) { [(_, v)] -> Some(v) | _ -> None }

foreign fn rawLookup(t : Ets.Table(k, v), key : k) -> List((k, v)) with m = "ets:lookup/2"

/// Remove key. A key not present is not an error.
fn Ets.delete(t : Ets.Table(k, v), key : k) -> () with m = { let _ = rawDelete(t, key); () }

foreign fn rawDelete(t : Ets.Table(k, v), key : k) -> Bool with m = "ets:delete/2"

/// The number of entries in the table.
fn Ets.size(t : Ets.Table(k, v)) -> Int with m = rawInfo(t, atom("size"))

foreign fn rawInfo(t : Ets.Table(k, v), item : Foreign) -> Int with m = "ets:info/2"

/// Delete the table. All subsequent operations on it fault.
fn Ets.drop(t : Ets.Table(k, v)) -> () with m = { let _ = rawDrop(t); () }

foreign fn rawDrop(t : Ets.Table(k, v)) -> Bool with m = "ets:delete/1"

/// Remove all entries, leaving the table empty.
fn Ets.clear(t : Ets.Table(k, v)) -> () with m = { let _ = rawClear(t); () }

foreign fn rawClear(t : Ets.Table(k, v)) -> Bool with m = "ets:delete_all_objects/1"

/// True if key is present in t.
foreign fn Ets.member(t : Ets.Table(k, v), key : k) -> Bool with m = "ets:member/2"

/// All key-value pairs currently in the table, in unspecified order.
foreign fn Ets.toList(t : Ets.Table(k, v)) -> List((k, v)) with m = "ets:tab2list/1"
```

```
fn main() -> () with () = {
    let t = Ets.new();
    Ets.insert(t, "a", 1);
    Ets.insert(t, "b", 2);
    match Ets.lookup(t, "a") {
        Some(n) -> Io.println(Int.toText(n))
      | None -> Io.println("missing")
    };
    Ets.drop(t)
}
```

The raw names are unqualified and therefore invisible outside the module; `Ets.*` is the library. `Ets.Table(k, v)` has type parameters the implementation never sees: `Ets.insert(t, "a", 1)` fixes `t` to `Table(Text, Int)`, and an insert with other types on the next line is a type error. Every operation has a mailbox type, `size` and `member` included, because they read state that others write. `atom` is pure: the same text gives the same atom. An Erlang-side module is needed only to catch: a raw function that throws is a fault, and a shim that wants `Either` instead must `try` in Erlang, since Ernest cannot. What the type cannot say, the declaration's documentation must: a table lives until `Ets.drop`, or until the process that created it dies.

## Appendix E. Standard Library

Informative, not normative: this appendix lists the modules that ship with the compiler as ordinary Ernest files under `stdlib/`. The standard library is on the load path by default — no `-pa` flag needed. Every program can call `Io.println`, `List.map`, and the rest without any setup. The prelude in section 9 is what the language itself requires; everything below is convenience written in Ernest on top of it.

### Appendix E.1. `Io.ern`

Output helpers. The ambient forms send to `Sys.stdout` (section 8); the `*To` forms take an explicit `Address(Text)`, useful for logging to a mailbox that is not stdout.

```
Io.print      : (Text) -> () with m                    // to Sys.stdout
Io.println    : (Text) -> () with m                    // to Sys.stdout, appends "\n"

Io.printTo    : (Address(Text), Text) -> () with m
Io.printlnTo  : (Address(Text), Text) -> () with m     // appends "\n"
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
List.append      : (List(a), List(a)) -> List(a)
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
List.foreach     : (List(a), (a) -> ()) -> ()
List.span        : (List(a), (a) -> Bool) -> (List(a), List(a))
List.sort        : (List(a), (a, a) -> Ordering) -> List(a)
List.remove      : (List(a), a) -> List(a)
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
Map.map          : (Map(k, v), (k, v) -> w) -> Map(k, w)
Map.foldLeft     : (Map(k, v), b, (b, k, v) -> b) -> b
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

### Appendix E.5. `Text.ern`

```
Text.size        : (Text) -> Int                       // number of code points
Text.isEmpty     : (Text) -> Bool
Text.contains    : (Text, Text) -> Bool                // substring test
Text.toInt       : (Text) -> Optional(Int)
Text.chars       : (Text) -> List(Char)
Text.fromChars   : (List(Char)) -> Text
Text.fromUtf8    : (Bytes) -> Optional(Text)
Text.toUtf8      : (Text) -> Bytes
Text.lines       : (Text) -> List(Text)
Text.all         : (Text, (Char) -> Bool) -> Bool
```

### Appendix E.6. `Char.ern`

```
Char.isDigit     : (Char) -> Bool
Char.isAlpha     : (Char) -> Bool
Char.isSpace     : (Char) -> Bool
Char.toText      : (Char) -> Text
Char.toInt       : (Char) -> Int                       // Unicode code point
```

### Appendix E.7. `Bool.ern`

```
Bool.not         : (Bool) -> Bool
Bool.toText      : (Bool) -> Text                      // "true" or "false"
```

### Appendix E.8. `Int.ern`

```
Int.abs          : (Int) -> Int
Int.negate       : (Int) -> Int
Int.min          : (Int, Int) -> Int
Int.max          : (Int, Int) -> Int
Int.bitAnd       : (Int, Int) -> Int
Int.bitOr        : (Int, Int) -> Int
Int.bitXor       : (Int, Int) -> Int
Int.bitNot       : (Int) -> Int
Int.shiftLeft    : (Int, Int) -> Int
Int.shiftRight   : (Int, Int) -> Int                   // arithmetic (sign-preserving)
Int.toText       : (Int) -> Text
Int.toFloat      : (Int) -> Float
```

### Appendix E.9. `Float.ern`

```
Float.abs        : (Float) -> Float
Float.negate     : (Float) -> Float
Float.toText     : (Float) -> Text
Float.round      : (Float) -> Int                      // banker's rounding, IEEE 754 default
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
Foreign.toText   : (Foreign) -> Optional(Text)
Foreign.toBool   : (Foreign) -> Optional(Bool)
Foreign.toList   : (Foreign) -> Optional(List(Foreign))
```

The standard library is expected to grow. New modules are added when a pattern shows up in three programs, matching the rule the decisions log applies to other deferred additions.
