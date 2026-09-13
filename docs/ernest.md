# Ernest: Language Report

September 2026. Rationale, rejected alternatives, and open questions are in `ernest-decisions.md`.

## 0. Introduction

Ernest is a functional language for concurrent programs. It has two concepts: functions, with Hindley-Milner types and full inference, and processes, with typed messages, as the only way to affect the world. Everything else in this report is a rule for how the two show up in each other.

Every function runs inside a process: an execution of a function, with a mailbox of its own that receives values of one type. A function either acts through its process, by sending, receiving, or asking who it is, or it does not. A function that does not is called pure: its result depends only on its arguments, and it affects nothing. A function that does names in its type the mailbox it uses, `(A) -> B with M`; `M` is the function's mailbox type, and it is the only mark a function type carries. Sections 3 and 6 make this precise. The runtime is what runs Ernest programs; section 10 states what it must provide.

The language is built on seven principles, in order. The reader comes first.

1. Least surprise decides, measured in code, not in the rule.
2. No variants, unless what remains surprises more.
3. Nothing invisible: control flow, communication, and failure are visible in the code or in the type.
4. Orthogonal: concepts do not affect one another.
5. Simple to parse: the grammar is LL(1), every construct is decided by its first token, and each bracket has one role.
6. Few reserved words, but not too few.
7. Small: concepts are counted, not primitives.

## 1. Notation

The grammar is written in EBNF. `=` defines, `|` separates alternatives, `[ ]` is optional, `{ }` is zero or more, `( )` groups, `.` ends a rule. Terminals are quoted. `ident`, `conname`, `typename`, `typevar`, and the literals are defined in section 2. The complete grammar is in Appendix A.

## 2. Lexical Elements

**Characters.** Source text is Unicode in UTF-8. Whitespace separates tokens and has no other meaning; line breaks mean nothing.

**Comments.** `//` to end of line, and `/* ... */`, which nests. Comments are removed by the lexer and take part in no grammar rule.

**Identifiers.** `ident` begins with a lowercase letter or `_`; `conname` and `typename` begin with an uppercase letter and are lexically the same token; `typevar` is a lowercase identifier in type position. A qualified name is a sequence of uppercase segments followed by a final segment: `Net.Http.parse`, `Stack.push`, `Int.+`, `ServerMsg.Get`. The dots are namespaces, section 4.

**Reserved words.** Sixteen: `type`, `opaque`, `with`, `match`, `when`, `if`, `then`, `else`, `recv`, `after`, `fn`, `let`, `foreign`, `as`, `true`, `false`.

**Literals.**

```
int      = digit { digit } .
float    = digit { digit } "." digit { digit } [ ( "e" | "E" ) [ "-" ] digit { digit } ] .
char     = "'" ( character | escape ) "'" .
text     = '"' { character | escape } '"' .
escape   = "\\" ( '"' | "\\" | "n" | "t" | "u{" hexdigit { hexdigit } "}" ) .
bool     = "true" | "false" .
```

`1` is `Int`, `1.0` and `1.0e-9` are `Float`. Literals carry no sign; `-` is a prefix operator. No overloaded literals and no default. The escapes are the five listed; a `character` is any code point other than the enclosing quote and `\`: in a `char` literal other than `'` and `\`, in a `text` literal other than `"` and `\`.

**Operators and delimiters.**

```
( ) { } [ ] , ; : = <- -> | .. _
+ - * / % ++ +: == != < <= > >= && ||
```

Prefix `-` is negation on `Int` and `Float`. Precedence of the binary operators, highest first: `* / %`, `+ - ++`, `+:` (right-associative), `== != < <= > >=`, `&&`, `||`. All but `+:` are left-associative. An operator name can be qualified, `Int.+`, section 4.

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

**Lists.** `List(a)`. `x +: xs` is the list whose first element is `x` and whose remainder is `xs`; `[a, b]` is `a +: b +: []`.

**Function types.** `(A, B) -> C` is the type of a function of two arguments. Arity is part of the type: `(A, B) -> C` and `((A, B)) -> C` are different types. `() -> C` takes no arguments. `with M` after the result is the mailbox type: the function uses the process it runs in, whose mailbox has type `M`, section 6. A function type without a mailbox type is pure. `with` binds to the nearest arrow; `(A) -> (B) -> C with M` is a pure function returning a function with mailbox type `M`.

**Sum types.** Declared with `type`, section 4. A constructor has no payload, exactly one positional payload, or named fields:

```
type Optional(a) = None | Some(a)
type Peer = Peer(dir : Path, seen : Map(Path, Mtime))
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
ForeignDecl = "foreign" ( "type" typename [ "(" typevar { "," typevar } ")" ]
            | "fn" Name "(" [ Param { "," Param } ] ")" Return "=" text ) .
TypeDecl    = "type" typename [ "(" typevar { "," typevar } ")" ] "=" Constructor { "|" Constructor } .
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
```

**Namespaces and visibility.** The namespace is in the name, and so is the visibility. A top-level declaration with a qualified name, `fn Net.Http.parse(b) = ...`, `type Net.Http.Request = ...`, is visible throughout the program under that name; two such declarations with the same full name are an error. A top-level declaration with an unqualified name, `fn helper(x) = ...`, is visible only in its own source file. A file's path is its namespace: the qualified declarations in `Net/Http.ern` begin with `Net.Http.`, and may go deeper, `Net.Http.Header.parse`. That is the whole of a file's meaning, and there is no export list, no `pub`, and no `import`. Sub-namespaces are the dots; namespace segments are type names. An unqualified name in a body is looked up first among the file's unqualified declarations, then in the namespace of the enclosing declaration, then in the prelude; everything else must be qualified. The only other thing hidden is the constructor of an opaque type from definitions outside its signature. `main` is unqualified, section 8.

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

**Functions.** `fn` declares a function of fixed arity. Annotations may be omitted where they can be inferred. The return annotation has three forms: omitted, `-> T` for a pure function, `-> T with M` for process code. A pure annotation on a function that calls process code is a type error. A function has one clause. Patterns in parameters must be irrefutable, section 5, `fn seenCount(Peer(seen = entries) : Peer) -> Int = Map.size(entries)`. `fn` may appear at top level and as a statement in a block; it sees its own name, and `fn` declarations in the same block or at top level may refer to each other mutually.

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

**Lambda.** `fn(x) = e` is an anonymous function. Its body extends to the nearest delimiter at the same nesting level: `,`, `;`, `|`, `)`, or `}`.

**Blocks.** `{ s1; s2; e }` is an expression whose value is the last statement, which must be an expression. `;` separates statements and never appears last. Statements are `fn` declarations, `let` bindings, and expressions; an expression as a statement is evaluated for its effect.

**Binding with `<-`.** In a block, `let p <- e; rest` means that `e` is matched: on `Right(v)`, `p` is bound to `v` and `rest` is evaluated; on `Left(err)`, the block's value is `Left(err)`. If the block's type is `Optional`, `Some` and `None` apply the same way. The block's type decides which, resolved from the type of `e` as operators are; `rest` must have the block's type. All `<-` bindings in the same block resolve to the same sum type — the block is either `Either` or `Optional`, not both. The rewrite is local to the block.

**Construction.** `Some(e)`, `None`, `Peer(dir = d, seen = s)`. All fields must be given. `Peer(..p, seen = s)` takes unlisted fields from `p`; at least one field follows `..`. A constructor is qualified like a function, `Net.Http.Request(...)`. A nullary constructor is a value, a single-positional constructor is a function value, and named constructors are neither: they only appear in construction syntax. Qualified operators are function values, `Int.+`.

**Conditional.** `if c then a else b` with `c : Bool`; the branches have the same type.

**`match`.** The expression is matched against the arms' patterns in order; the first arm whose pattern matches and whose guard holds is evaluated. A failed guard falls through. The arms together must cover the type; guards do not count as coverage. Variables in the pattern are bound in the guard and the arm.

**Patterns.** A pattern decomposes a value and binds its parts. The same patterns appear in `let`, in `match` and `recv` arms, and in function parameters. `_` matches anything and binds nothing. An identifier binds the whole value at its position to a new variable, shadowing any outer variable of that name; it never refers to an existing variable. A literal matches itself. A constructor with a pattern, `Some(p)`, or with field patterns, `Peer(seen = s)`, which may omit fields, matches that constructor and decomposes its payload. A tuple, a list `[p, q]`, and `p +: q` decompose those. Patterns nest to any depth: `Some((x, Peer(dir = d)))`. `p as c` binds `c` to the whole value that `p` matches, `Some(Peer(dir = d) as peer)`; `as` binds loosest, so `x +: rest as all` names the whole list. Each variable appears at most once in a pattern; a pattern does not compare, and equality is written in a guard. A pattern is irrefutable if it cannot fail: `_`, an identifier, a tuple of irrefutable patterns, or a constructor pattern of a type with exactly one constructor whose sub-patterns are all irrefutable. `let` and parameters require irrefutable patterns; `let Right(x) = e` is a type error.

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

**Addresses.** `Address(m)` identifies a process on a node and carries its protocol: `send(a, v)` is type-checked against `m` and is the same on every node. `via(f, a)`, section 9, is the address `a` seen through `f : (b) -> m`: sending `v` to `via(f, a)` is sending `f(v)` to `a`. A single-request answer uses `Reply(a)`, below; `via(Wrap, self())` gives a wrapper address for a process that receives replies in its own mailbox. Addresses have no equality; identity is expressed in the protocol. There is no registry: a process reaches another only through an address it holds or received in a message, and possession of the address is the permission to send.

**Request-reply.** A `Reply(a)` is a one-shot address for the answer to a request; unlike `Address(a)`, it is answered exactly once and cannot be stored.

```
Address.call : (Address(m), (Reply(a)) -> m, Int) -> Optional(a) with n
answer       : (Reply(a), a) -> () with m
```

`Address.call(addr, mk, ms)` allocates a fresh `Reply(a)`, calls `mk(r)` to build the message, sends it to `addr`, and returns `Some(v)` when the recipient answers or `None` after `ms` milliseconds. `answer(r, v)` sends `v` to the caller. A `Reply(a)` value appears only at these positions: a field of a message, a parameter of a function, a variable bound in a `recv` arm, and a value captured by a lambda passed to `spawn`. Any other position is a type error: a `Reply` in a container, in a `match` or `let` binding, in a return type not itself a message, or as an operand of equality, is rejected by the compiler. A `Reply(a)` bound in a `recv` arm is consumed exactly once on every path of the arm's expression. Consumption is `answer(r, v)`, sending `r` as a field of a message, or capturing `r` in a lambda passed to `spawn`; in the last case the captured `Reply` is consumed on every path of the spawned function's body, checked at its definition. A violation is a type error. The mandatory timeout on `Address.call` returns `Optional(a)` so that the caller cannot forget the failure. Under the hood the `Reply(a)` carries a fresh identifier so that `Address.call` receives only the answer to its own request; the caller's mailbox type is unaffected.

**Remote computation.** A pure function can be evaluated on another node:

```
remote : (() -> a) -> Either(RemoteError, a)
type RemoteError = NoRemotePeer | PeerLost
```

`remote(f)` evaluates `f()` on a peer the runtime chooses among those configured for remote computation, and returns the value. Which peer, and by what criterion, the language does not say. `f` is pure and so is `remote`: the result depends on `f` alone, and the caller waits as it would for any computation. `Left(NoRemotePeer)` if no peer is configured; `Left(PeerLost)` if the peer disappears before the value returns.

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
- **A fault**, when the code cannot see it. Out of memory, `kill`, a failure in the runtime, a broken promise by foreign code. The process dies with a structured cause in `Down`. Nothing is caught.

The prelude is total: no built-in function faults. Partial operations return `Optional` or `Either`. A fault is therefore always something that happened to the process, never something it did, with three deliberate exceptions: `/` and `%` on `Int` with a zero divisor fault, `Fault("division by zero")`; `todo("...")`, which compiles at any type and faults if reached, `Fault("todo: ...")`, so that an unfinished function can be declared before it is written; and `spawn(Peer(...), f)` or `send` to a remote address when the payload transitively contains a foreign value, `Fault("foreign value cannot cross nodes")`, section 3. `Int.div` and `Int.mod` return `Optional` for the caller who wants to handle it.

## 8. Programs

**`main`.** A program is a set of source files with exactly one function `main : (Sys) -> () with m` for some `m`, unqualified, called by the runtime. Nothing sends to `main` that it has not given its address to; `m` is usually `()`.

**`Sys`.** The runtime starts with its system processes and hands their addresses to `main` in a value of type `Sys`, a constructor with named fields defined by the runtime. The language requires the fields `stdout : Address(Line)` and `clock : Address(ClockMsg)`, section 9. A program that uses a field the runtime lacks is a type error. A function without a system address among its arguments and without foreign calls cannot affect anything outside its process.

**Peers.** Peers are configured outside the language, section 11; `Peer(name)` refers to them by the configured name, and nodes authenticate each other.

**Foreign code.** The system processes are foreign processes: their message types are declared in Ernest, their implementations live outside the language, and the runtime starts them and places their addresses in `Sys`. Other foreign code enters through `foreign fn` and `foreign type`, section 4. Both boundaries carry the same promise: the foreign side delivers the declared types, and a breach is a fault.

**Program termination.** The program ends when `main` returns. Live processes then die with cause `ProgramEnd`; system processes release their resources. A program that is to keep running waits in `main`. If no process can run, all are waiting in `recv` without `after` and no messages are in flight, the runtime ends the program with the error `Deadlock`. A pending `after` or clock counts as a message in flight.

## 9. Prelude

Types and functions the language presupposes. The namespace is the type's.

```
type Optional(a) = None | Some(a)
type Either(e, a) = Left(e) | Right(a)
type Ordering = Less | Equal | Greater
type Line = Line(Text)
type Down = Down(reason : Reason, function : Text)
type Reason = Returned | Killed | ProgramEnd | Fault(Text)
type ClockMsg                                      // times in milliseconds
    = After(ms : Int, to : Address(()))
    | At(at : Int, to : Address(()))
    | Now(reply : Reply(Int))

via          : ((a) -> b, Address(b)) -> Address(a)
Address.call : (Address(m), (Reply(a)) -> m, Int) -> Optional(a) with n
answer       : (Reply(a), a) -> () with m
remote       : (() -> a) -> Either(RemoteError, a)        // Where, RemoteError: section 6
monitor      : (Address(a), (Down) -> m) -> () with m
kill         : (Address(a)) -> () with m

Int.div, Int.mod : (Int, Int) -> Optional(Int)    // None on zero; `/` and `%` fault on zero instead; mod is non-negative for a positive divisor
Int.negate : (Int) -> Int                         // likewise Float
Int.compare : (Int, Int) -> Ordering              // likewise Float, Text, Char
Int.toText : (Int) -> Text                        // likewise Float
Text.toInt : (Text) -> Optional(Int)
Text.chars : (Text) -> List(Char)            Text.fromChars : (List(Char)) -> Text
Text.fromUtf8 : (Bytes) -> Optional(Text)    Text.toUtf8 : (Text) -> Bytes
Text.lines : (Text) -> List(Text)              Text.all : (Text, (Char) -> Bool) -> Bool
Char.isDigit, Char.isAlpha : (Char) -> Bool
List.size, List.reverse, List.head, List.at, List.contains, List.map, List.filter,
List.filterMap, List.foldLeft, List.foreach, List.any, List.span, List.sort, List.remove, List.dropLast
Map.empty, Map.get, Map.put, Map.delete, Map.size, Map.values, Map.map, Map.foldLeft
Set.empty, Set.add, Set.remove, Set.contains, Set.size, Set.toList
Int.toFloat : (Int) -> Float                      Float.round, Float.floor : (Float) -> Int
Optional.map, Optional.flatMap
todo : (Text) -> a                               // faults if reached; section 7
type Foreign                                     // a value the language does not inspect
Foreign.toInt, Foreign.toFloat, Foreign.toText, Foreign.toBool : (Foreign) -> Optional(...)
Foreign.toList : (Foreign) -> Optional(List(Foreign))
Either.map, Either.mapLeft, Either.andThen
```

`List.head : (List(a)) -> Optional(a)`, `List.at : (List(a), Int) -> Optional(a)`, `Map.get : (Map(k, v), k) -> Optional(v)`. `List.sort : (List(a), (a, a) -> Ordering) -> List(a)`. Containers are taken as the first argument. `Map(k, v)` and `Set(a)` require equality on `k` and `a`.

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

`ernc file.ern` compiles a source file to `file.erc`, a compiled file the runtime can load. A program is compiled file by file; cross-file names are resolved at load.

`ern [--config-dir dir] [-pa dir ...] file.erc` loads the file and, on demand, the compiled files on the load path, found by namespace, `Net.Http.parse` in `Net/Http.erc`; starts the system processes, builds `Sys`, and calls `main`. `ern --repl` starts a read-evaluate-print loop with the same loading. `--config-dir` names the configuration directory, `./.ernest` by default.

`ern --create-config-dir dir` creates `dir/.ernest/` containing `ernest.conf` and this node's private key, readable only by its owner, and does nothing else; it fails if the directory exists. `ernest.conf` holds this node's network address and public key, and the list of peers: for each, a name, a network address, a public key, and whether it accepts remote computation. Appendix C shows one. The names are the ones `Peer(name)` refers to.

## Appendix A. Grammar

```
Program     = { Declaration } .
Declaration = TypeDecl | OpaqueDecl | FnDecl | LetDecl | ForeignDecl .
ForeignDecl = "foreign" ( "type" typename [ "(" typevar { "," typevar } ")" ]
            | "fn" Name "(" [ Param { "," Param } ] ")" Return "=" text ) .

TypeDecl    = "type" typename [ "(" typevar { "," typevar } ")" ] "=" Constructor { "|" Constructor } .
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
Primary     = literal | QName | Tuple | "()" | ListLit | Block | "(" Expr ")" .
QName       = { typename "." } ( ident | binop | conname [ "(" ( Expr | Fields ) ")" ] ) .
Fields      = ".." Expr "," FieldSet { "," FieldSet } | FieldSet { "," FieldSet } .
FieldSet    = ident "=" Expr .
Tuple       = "(" Expr "," Expr { "," Expr } ")" .
ListLit     = "[" [ Expr { "," Expr } ] "]" .
Block       = "{" Stmt { ";" Stmt } "}" .
Stmt        = FnDecl | Binding | Expr .

Pattern     = ConsPat [ "as" ident ] .
ConsPat     = AtomPat [ "+:" ConsPat ] .
AtomPat     = "_" | ident | literal | { typename "." } conname [ "(" ( Pattern | FieldPats ) ")" ]
            | "(" Pattern "," Pattern { "," Pattern } ")" | "()"
            | "[" [ Pattern { "," Pattern } ] "]" .
FieldPats   = [ ident "=" Pattern { "," ident "=" Pattern } ] .

binop       = "*" | "/" | "%" | "+" | "-" | "++" | "+:"
            | "==" | "!=" | "<" | "<=" | ">" | ">=" | "&&" | "||" .
literal     = int | float | char | text | bool .
```

Precedence for `binop` as in section 2. Every nonterminal is decided by its first token: `let` begins a binding, `fn` a declaration or lambda, `{` a block, `[` a list, `(` a call, tuple, or parenthesized expression. In `QName`, after each uppercase token the next token decides: `.` continues the qualification; otherwise the segment is final, and a lowercase final is a function or operator, an uppercase final a constructor. A constructor's payload is positional or named by whether `=` or `:` follows the first identifier. `conname` and `typename` are one token class; which one a segment is follows from its position.

## Appendix B. Examples

```
type PongMsg = Ping(n : Int, reply : Reply(Int)) | Stop

fn pong(out : Address(Line)) -> () with PongMsg = recv {
    Ping(n = n, reply = r) -> {
        send(out, Line("pong " ++ Int.toText(n)));
        answer(r, n);
        pong(out)
    }
  | Stop -> ()
}

fn ping(out : Address(Line), pongAddr : Address(PongMsg), n : Int) -> () with m =
    if n == 0 then send(pongAddr, Stop)
    else {
        send(out, Line("ping " ++ Int.toText(n)));
        match Address.call(pongAddr, fn(r) = Ping(n = n, reply = r), 5000) {
            Some(_) -> ping(out, pongAddr, n - 1)
          | None    -> { send(out, Line("pong is not answering")); send(pongAddr, Stop) }
        }
    }

fn main(Sys(stdout = out) : Sys) -> () with () = {
    let pongAddr = spawn(Local, fn() = pong(out));
    let _ = spawn(Local, fn() = ping(out, pongAddr, 3));
    ()
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
  "ip-address": "145.32.64.6:8654",
  "public-key": "<PEM public key>",
  "peers": [
    {
      "name": "foo",
      "ip-address": "145.32.64.7:8654",
      "public-key": "<PEM public key>",
      "remote-peer": true
    },
    {
      "name": "bar",
      "ip-address": "145.32.64.8:8654",
      "public-key": "<PEM public key>",
      "remote-peer": false
    }
  ]
}
```

`Peer("foo")` and `Peer("bar")` name these peers in `spawn`, section 6. `remote(f)` chooses among peers with `"remote-peer": true`, here only `foo`. The private key is in the same directory, `private-key.pem`, readable only by its owner. A freshly created file has an empty `peers` list.

## Appendix D. A Foreign Library

A shim over Erlang's `ets`, tables of type `set`. Raw bindings are file-local; the library is ordinary Ernest over them. No Erlang module is needed: the representation of values, section 10, already matches Erlang's conventions, `true` is `Bool`, `[{K, V}]` is `List((k, v))`, and `{ok, V} | {error, R}` is a sum type with constructors tagged `ok` and `error`.

```
// Ets.ern

foreign type Ets.Table(k, v)

foreign fn rawNew(name : Text, opts : List(Foreign)) -> Ets.Table(k, v) with m   = "ets:new/2"
foreign fn rawInsert(t : Ets.Table(k, v), row : (k, v)) -> Bool with m           = "ets:insert/2"
foreign fn rawLookup(t : Ets.Table(k, v), key : k) -> List((k, v)) with m        = "ets:lookup/2"
foreign fn rawDelete(t : Ets.Table(k, v), key : k) -> Bool with m                = "ets:delete/2"
foreign fn rawDrop(t : Ets.Table(k, v)) -> Bool with m                            = "ets:delete/1"
foreign fn rawClear(t : Ets.Table(k, v)) -> Bool with m                           = "ets:delete_all_objects/1"
foreign fn rawInfo(t : Ets.Table(k, v), item : Foreign) -> Int with m             = "ets:info/2"
foreign fn atom(name : Text) -> Foreign                                           = "erlang:binary_to_atom/1"

foreign fn Ets.member(t : Ets.Table(k, v), key : k) -> Bool with m                = "ets:member/2"
foreign fn Ets.toList(t : Ets.Table(k, v)) -> List((k, v)) with m                 = "ets:tab2list/1"

fn Ets.new() -> Ets.Table(k, v) with m = rawNew("ernest", [atom("set"), atom("public")])

fn Ets.insert(t : Ets.Table(k, v), key : k, value : v) -> () with m = { let _ = rawInsert(t, (key, value)); () }

fn Ets.lookup(t : Ets.Table(k, v), key : k) -> Optional(v) with m =
    match rawLookup(t, key) { [(_, v)] -> Some(v) | _ -> None }

fn Ets.delete(t : Ets.Table(k, v), key : k) -> () with m = { let _ = rawDelete(t, key); () }

fn Ets.size(t : Ets.Table(k, v)) -> Int with m = rawInfo(t, atom("size"))

fn Ets.drop(t : Ets.Table(k, v)) -> () with m = { let _ = rawDrop(t); () }

fn Ets.clear(t : Ets.Table(k, v)) -> () with m = { let _ = rawClear(t); () }
```

```
fn main(Sys(stdout = out) : Sys) -> () with () = {
    let t = Ets.new();
    Ets.insert(t, "a", 1);
    Ets.insert(t, "b", 2);
    match Ets.lookup(t, "a") {
        Some(n) -> send(out, Line(Int.toText(n)))
      | None    -> send(out, Line("missing"))
    };
    Ets.drop(t)
}
```

The raw names are unqualified and therefore invisible outside the file; `Ets.*` is the library. `Ets.Table(k, v)` has type parameters the implementation never sees: `Ets.insert(t, "a", 1)` fixes `t` to `Table(Text, Int)`, and an insert with other types on the next line is a type error. Every operation has a mailbox type, `size` and `member` included, because they read state that others write. `atom` is pure: the same text gives the same atom. An Erlang-side module is needed only to catch: a raw function that throws is a fault, and a shim that wants `Either` instead must `try` in Erlang, since Ernest cannot. What the type cannot say, the declaration's documentation must: a table lives until `Ets.drop`, or until the process that created it dies.
