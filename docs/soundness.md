# The soundness argument

What this document argues is held to the code by three machines of `make test`, [`test/ern_grammar_programs_tests.erl`](../test/ern_grammar_programs_tests.erl), [`erl/runtime/test/ern_laws_tests.erl`](../erl/runtime/test/ern_laws_tests.erl) and [`test/ern_typed_programs_tests.erl`](../test/ern_typed_programs_tests.erl), and by the checker's tests in [`erl/typer/test/ern_typecheck_tests.erl`](../erl/typer/test/ern_typecheck_tests.erl), which cite the sections cited here.

An argument that a well-typed program does not go wrong, over the rules of [`report/language.md`](../report/language.md) in its revision of 9 October 2026. It is prose and no machine checks it. It states a small calculus, the invariants a running program keeps, why each step keeps them, and then each place where two rules meet. The report owns the rules and the log their reasons. This document owns the argument alone: a change to a rule it covers rewrites the paragraph for that rule in the same commit (CLAUDE.md, *Before code*).

## 1. What is argued

For a program the checker accepts, compiled whole and run on one node:

1. **No step is undefined.** At each moment a process has returned, waits, has faulted with a cause §7.4 gives, or takes a step the report defines. It never calls what is no function, calls with another count of arguments than the function takes, selects a field its value lacks, finds no clause in a `match`, reads a binding that has no value, or gives a primitive a value of another type.
2. **Every message fits its mailbox.** The mailbox of a process whose mailbox type is `M` holds values of type `M` alone, and a `receive` binds no variable to a value of another type than the variable's.
3. **Every function runs where its type says.** A function whose type has `with M` runs only in a process whose mailbox type is `M`, and a function whose type has no `with` acts through no process.
4. **Every reply has one holder.** A `Reply` that is not yet answered is held in one place at most. So the program answers it at most once, and a function that returns has answered or handed on every reply it was given.

It does not argue the following.

- **That a program ends, or that a reply is answered.** The holder of a reply may fault, be killed, wait for ever, or lie in a mailbox no `receive` matches. §6.6 covers the caller: a deadline, or the end of the process the request was sent to.
- **That a program does not deadlock.** The runtime detects it (§8.6).
- **Foreign code**, past the checks of §8.4, which section 2 lists.
- **The shell's sessions** (§11.2), where a type is declared anew. Section 7 extends the argument to a program on several nodes, and MVP 3.1 extends it to code that crosses.
- **That the toolchain implements the rules.** That is the tests' to hold.

## 2. What is assumed

- **The runtime** gives the functions of §9.4 to §9.6 their types and their meaning, and meets §10: a value never changes, a message is a copy, processes share no memory, and a mailbox holds what was sent to it, in order for each sender.
- **The standard library's foreign functions and the system processes** deliver their declared types and keep what their sections of Appendix E say. §8.4 does not check them.
- **Other foreign code** is checked where it crosses (§8.4). Three promises are its own: at a type variable a parameter's type names it returns only values it was given at that variable; without a mailbox type it is pure (§4.7); and a reply it is given it answers once or not at all, as it hands on once what a function it calls returns. A second answer is discarded (§6.6), so claim 4 says what the program does, not what foreign code does. A message that fails the check does not enter the mailbox as a value: its fault stands in its place, and the wait that reaches it faults the receiver before any clause is tried (§8.4), so I1's mailbox holds only values of its type. An address of the program's that foreign code gives back is the program's own at the type it crossed at, which is its process's, and foreign at any other, where what is sent to it is checked as a message foreign code sends (§8.4). A process of the program's whose address foreign code was never given is a bad value where foreign code gives it as an address, except as an `Address(Never)`, through which no message passes (§8.4), so no address Ernest code holds lets a message of another type reach a mailbox.

## 3. The calculus

The calculus is the language without its conveniences. The pipe is a call (§5.7), an operator on a known type is a call of its member (§4.8), and a bitstring is a primitive whose failures are faults or failed matches (§5.11); none adds a rule.

**Types and effects.**

```
τ ::= B | α | T(τ, …) | #(τ, τ, …) | (τ, …) -> τ with ε | Address(τ) | Reply(τ) | Never
ε ::= pure | τ
σ ::= ∀ α, … . τ
```

`B` is a base type of §3.1. `T` is a declared, a built-in or a foreign type, `List` among them. An effect is `pure` or a type, the mailbox type; `pure` is no type (§3.9), and `(τ) -> τ with pure` is what the report writes without `with`. A type variable `α` may stand in an effect position. A scheme `σ` gives each of its variables a set of restrictions among *equality*, *process-only* and *not-reply-carrying* (§3.9), and an instance must meet them. A requirement (§4.9) is no part of a scheme.

**Expressions and values.**

```
e ::= x | k | fn(p, …) = e | e(e, …) | C | C(e) | C(f = e, …) | C(..e, f = e, …) | e.f
    | #(e, e, …) | [e, …] | e :: e | if e then e else e | { s; …; e }
    | match e { p when e -> e | … }
    | receive { p when e -> e | … | after e -> e }
s ::= let p = e | let p <- e | fn f(p, …) = e | e
v ::= k | C | C(v) | C(f = v, …) | #(v, v, …) | [v, …] | ⟨fn(p, …) = e; η⟩ | a | via(a, v) | r
```

`k` is a literal or a primitive, `p` a pattern (§5.10), `C` a constructor. A function value is a closure, a lambda with the values `η` of the names it captured. `a` is the address of a process, `via(a, v)` an adapted address (§6.5), and `r` a reply (§6.6). A value of a foreign type is opaque.

**Configurations.** A running program is a set of processes and a set of replies not yet answered. A process `a` has a mailbox type `M`, an expression `E` it evaluates, and a mailbox `Q`, a queue of values. An unanswered reply `r` has the process that waits for it, and the runtime's record of the call that made it: the caller's watch on the callee (§6.6) and, where the callee is on another node, the note that node keeps of the call (§8.7).

**Typing.** `Γ ⊢ e : τ ! ε` reads: under the names `Γ`, `e` has the type `τ` and acts through a process of mailbox type `ε`, or through none where `ε` is `pure`. The rules that matter here:

```
(name)     Γ(x) = ∀ᾱ.τ and the restrictions of ᾱ hold of τ̄        gives  Γ ⊢ x : τ[τ̄/ᾱ] ! pure
(lambda)   Γ, p̄ : τ̄ ⊢ e : τ ! ε′                                   gives  Γ ⊢ fn(p̄) = e : (τ̄) -> τ with ε′ ! pure
(call)     Γ ⊢ e₀ : (τ̄) -> τ with ε′ ! ε,  Γ ⊢ ē : τ̄ ! ε,  ε′ is pure or ε   gives  Γ ⊢ e₀(ē) : τ ! ε
(anywhere) Γ ⊢ e : τ ! pure                                         gives  Γ ⊢ e : τ ! ε
(stands)   Γ ⊢ e : (τ̄) -> τ with pure ! ε                           gives  Γ ⊢ e : (τ̄) -> τ with ε″ ! ε
(let)      Γ ⊢ e₁ : τ₁ ! ε,  p : τ₁ binds Γ₁,  Γ, Γ₁ ⊢ e₂ : τ ! ε   gives  Γ ⊢ { let p = e₁; e₂ } : τ ! ε
(match)    Γ ⊢ e : τ₀ ! ε,  each pᵢ : τ₀ binds Γᵢ,  Γ, Γᵢ ⊢ gᵢ : Bool ! pure,
           Γ, Γᵢ ⊢ eᵢ : τ ! ε,  the unguarded pᵢ cover τ₀            gives  Γ ⊢ match e { pᵢ when gᵢ -> eᵢ } : τ ! ε
(receive)  each pᵢ : M binds Γᵢ,  Γ, Γᵢ ⊢ gᵢ : Bool ! pure,  Γ, Γᵢ ⊢ eᵢ : τ ! M,
           Γ ⊢ t : Int ! M,  Γ ⊢ e′ : τ ! M          gives  Γ ⊢ receive { pᵢ when gᵢ -> eᵢ | after t -> e′ } : τ ! M
```

A `fn` definition, a top-level `let`, and a block's `let` of a lambda are given the scheme that quantifies the variables of their type which `Γ` does not hold, each with its restrictions (§3.9, §4.6); section 6.1 gives the one exception. The primitives are names with schemes (§9.4, §9.5), among them:

```
self         : ∀m. () -> Address(m) with m
send         : ∀a m. (Address(a), a) -> Unit with m
spawn        : ∀n m. (() -> Unit with n) -> Address(n) with m
via          : ∀a b. (Address(b), (a) -> b) -> Address(a)
Address.call : ∀m a n. (Address(m), (Reply(a)) -> m, Int) -> Optional(a) with n
answer       : ∀a m. (Reply(a), a) -> Unit with m
```

The effect variable of `send`, `spawn`, `Address.call` and `answer`, of every other function of §9.4 and §9.5 whose effect is its own, and of `restarting`, is process-only.

**Steps.** Within a process an expression steps as in any strict language, left to right (§5.1): a call of a closure puts the arguments for its parameters, a `match` takes the first clause whose pattern matches and whose guard holds, a block evaluates its statements in order. The steps that reach outside the expression are these.

```
(send)     a: E[send(b, v)]              a goes on with Unit; v joins the mailbox of b, or of b′ as f(v)
                                         where b is via(b′, f); nothing where the process has ended
(spawn)    a: E[spawn(v)]                a goes on with b, a new process of mailbox type N running v(),
                                         for v : () -> Unit with N
(self)     a: E[self()]                  a goes on with a
(receive)  a: E[receive { … }]           the first message a clause matches leaves the mailbox and its
                                         clause is evaluated; where the time passes first, the after clause
(call)     a: E[Address.call(b, v, t)]   a fresh r; v(r) is sent to b; a waits for r, for t at most
(answer)   c: E[answer(r, w)]            c goes on with Unit; the process that waits for r goes on with
                                         Some(w), and r is answered; nothing where none waits
(fault)    a: E[a faulting step]         a ends with Fault(cause), or runs its restarting function again
```

## 4. The invariants

Every configuration a program reaches keeps these.

- **I1, processes.** For each process `a` with mailbox type `M`: its expression has type `Unit` at effect `M`, and each value in its mailbox has type `M`. The entry process before `main` runs is the one exception, which 6.4 covers.
- **I2, addresses.** Each address of `a` has the type `Address(M)` for the mailbox type `M` of `a`. Each `via(b, f)` has the type `Address(τ)` with `f : (τ) -> M′` pure and `M′` the mailbox type of the process `b` reaches.
- **I3, replies.** Each reply `r` of type `Reply(τ)` that is not yet answered occurs at most once in the configuration, the runtime's record of its call aside: in one process's expression, counted through the closures it holds, or in one message. The record holds `r` only to end the call, and answers nothing. The process that waits for it, while one does, will take `Optional(τ)`, or `τ` for `Address.callForever`.

Claims 1 and 2 follow from I1 with the rules of section 3, claim 3 from the shape of the call rule, and claim 4 from I3.

## 5. Each step keeps them

**The functional steps.** These are the steps of Hindley-Milner's calculus with sum types, and the usual argument holds: a step replaces an expression by one of the same type. The count of arguments is part of a function's type (§3.4), so a call has as many as the closure takes (§5.2). A pattern in a parameter or a `let` is irrefutable (§5.10), so its binding cannot fail. The unguarded clauses of a `match` cover its type (§5.9), so a clause matches whatever the guards answer. A selection `e.f` is typed only where every constructor of the type has the field (§3.5), and a record update only on a type with one constructor (§5.6). An operator is a call of a member chosen when the program is compiled (6.9). `==` takes two values of one type and is defined on every pair of them (6.13). Division by zero, a float out of range, a bitstring that does not fit and `fault` are faults, which claim 1 counts as defined (§7.4). A name is read only after its binding has a value: top-level bindings are evaluated in dependency order, a member counting as named where it is supplied, and a cycle is refused (§8.5), and a local `fn` is not used before the `let`s it references (§5.4).

**Generalization.** A pure initializer makes a value that never changes (§10), and a value of a scheme's type holds no value of the types its variables stand for, so it is a value of each instance. This is why a top-level `let` whose initializer is pure is generalized though it is no lambda, as `let empty = []` is. Section 6.1 gives the initializer that is not pure.

**`receive`.** The clauses' patterns are typed against the mailbox type `M` (§6.3), and by I1 each message has type `M`, so each variable is bound at its type and the clause's body keeps I1. No coverage is asked: a message no clause matches stays, and the process waits.

**`send`.** `send(b, v)` is typed with `b : Address(τ)` and `v : τ`. By I2 either `b` is an address of a process with mailbox type `τ`, and the message keeps I1 there, or `b` is `via(b′, f)` and `f(v)` has the mailbox type of `b′`. `f` is pure, so it may run in the sender or on delivery (6.3).

**`spawn`.** `spawn(v)` with `v : () -> Unit with N` makes a process of mailbox type `N` whose expression `v()` has type `Unit` at effect `N`, which is I1, and its address has type `Address(N)`, which is I2. Where `v` is pure, `N` is the type inference leaves it; any type serves, since a pure body receives nothing.

**`self`.** `self` has the effect `m` and answers `Address(m)`. By claim 3 it runs in a process of mailbox type `m`, so I2 holds of what it answers.

**`Address.call` and `answer`.** The call makes a fresh `r : Reply(τ)` and sends `request(r)`, of the callee's mailbox type, so I1 holds; `r` occurs in that message alone, so I3 holds. `answer(r, w)` is typed with `w : τ`, so the caller goes on with a value of the type its step expects. An answer travels by `r` and not through the caller's mailbox (§6.6), so it cannot break I1.

**Messages the runtime delivers.** A `monitor`, a `spawnMonitored`, an alarm and a subscription each take a function from what they deliver to the caller's mailbox type (Appendix E.0 shape rule 8). The function is pure and its result has the mailbox type of the process it delivers to, so I1 holds. A message from foreign code is checked on delivery (§8.4).

**Faults, kills and restarts.** A process that ends takes no further step. What it held is gone, a reply among it: I3 says at most one holder, and none is allowed. A restart runs the same function again in the same process (§6.9), at the same mailbox type, with an empty mailbox, so I1 holds.

## 6. Where rules meet

### 6.1 Generalization against effects

A process is the one thing in the language that holds a state. Were its address generalized, the state would be read at two types:

```ernest-fragment
type Cell(a) = Put(a) | Get(reply : Reply(a))

fn cell(v : a) : Unit with Cell(a) = …

let shared = spawn(fn() = cell(None))       // refused
```

Generalized, `shared` would have the type `Address(Cell(Optional(a)))` for every `a`: one process could be sent `Put(Some(1))` and then asked, at `Optional(String)`, for what it holds. So a top-level `let` whose initializer calls a process-only function as it is evaluated is not generalized, and a variable left in its type is an error (§3.9, §4.6). The initializer's own effect decides: a spawn reached through a helper that calls its argument, or through a function a call returns, counts, and a call in the body of a lambda the initializer only builds does not. A block's `let` is generalized only where it binds a lambda, which evaluates nothing. A `fn` is generalized over the variables of its type that no name in scope around it holds (§3.9): each call makes its processes anew, so two instances share none of those, and a process it captures is held by a name around it, whose variables it is not generalized over. A local `fn` that sends to a block's `let c = spawn(fn() = cell(None))` has `c`'s variable in its type, held by `c`, so every call of it is at the one type `c` has.

### 6.2 A pure function where one with a mailbox type is expected

The rule (stands) of section 3 is §3.9's: an expression whose type is a function type without `with` takes a fresh effect variable in its place. It is sound because a pure body takes none of the steps (send) to (answer), so it keeps I1 to I3 in whatever process runs it. The rule applies to the expression's own type and to no type inside another: `List(() -> Unit)` is not `List(() -> Unit with M)`. That is a restriction, and needs no argument. The converse is refused, and 6.3 says why it must be.

### 6.3 Process-only

An effect variable that stands in no value position may be instantiated with `pure` (§3.9). A function that calls `send` or `spawn`, or waits in a `receive` that binds nothing of its mailbox's type, has such a variable and must not be taken for pure, so the variable carries the process-only restriction and `pure` does not instantiate it. Claim 2 rests on this, since the language runs some functions outside the process they were written for. The function of `via` runs in the sender or on delivery, in no process of the target's (§6.5). A wrap is applied by the runtime (§6.9). A guard is evaluated while a message is selected (§6.3). Each is typed pure. Were a function that receives accepted there, its `receive` would read one process's mailbox at another's type. `restarting` carries the restriction though its effect is its function's: a restart empties the process's mailbox and ends every call waiting on it (§6.9), so the function it returns acts on the process whatever `f` does. Were it taken for pure when `f` is, a pure function would empty a mailbox, which claim 3 forbids.

### 6.4 An initializer runs at `Never`

A top-level initializer is typed at the mailbox type `Never` and run in the entry process, whose mailbox type may be another (§4.6, §8.5). It is the one body that runs outside claim 3, and `Never` is what makes it safe. `Never` has no value. So `self()` in an initializer is an `Address(Never)`, to which nothing can be sent; a wrap `(Down) -> Never` cannot return a message; and a `receive` there has no pattern clause (§6.8). A function that returns what it receives, called there, waits for a message that cannot come, and the runtime faults it with `Fault("deadlock")` (§6.8, §8.6). Nothing therefore reaches the entry process's mailbox before `main` runs, and `main` begins with I1 holding at its own mailbox type. A wrap `(Down) -> Never` an initializer gave `monitor` or `spawnMonitored` is applied when its process ends, which may be once `main` has begun: it returns no message, since `Never` has no value, and a fault in it is the fault of the process it delivers to, `main` (§6.9), so it puts nothing in `main`'s mailbox either.

### 6.5 The reply discipline

§6.6 makes each binding of a reply-carrying value an *obligation*, consumed exactly once on every path from where it is bound. The argument is that every consumption moves the value to one new holder or answers it, and that no other step copies or drops it. Then each step keeps I3.

- **Each place a reply may stand moves it.** An argument becomes the callee's parameter. A field, a tuple component or a list element becomes part of one value. A `send` puts it in one message, and a `receive` binds it from that message. A scrutinee passes to the variables its pattern binds, each sub-value once: `_`, an omitted field and `as` are refused on a reply-carrying value. A result passes to the caller. `answer` ends it.
- **No other place is typed.** `==` is refused on a reply. A selection would drop the fields it leaves and a record update the field it replaces, so both are refused on a reply-carrying value, and a pattern takes it apart. A statement that is not `Unit` is refused (§5.4).
- **Every path consumes.** The branches of an `if`, a `match` and a `receive`, its `after` clause among them, consume the same obligations. The right operand of `&&` and `||` and what follows a `<-` may be skipped, so neither consumes an obligation open before it. A call that cannot return ends its path (6.8).
- **An obligation is a binding, not a name.** A name bound inside hides the obligation of that name around it, and its uses consume nothing of the outer one.
- **A top-level binding holds none.** Every function may read it, any number of times, so it is no obligation, and one whose type is reply-carrying is refused. A generalized one holds no value of its variables' types, and so no reply at any instance.
- **A function value takes each reply once**, by 6.6 and 6.7, so handing a reply to any function keeps I3.

The check is per function and reads types, not values. A value of a reply-carrying type that holds no reply, `Stop` or `[]`, is discharged by the pattern that shows it.

### 6.6 A reply captured by a lambda

A closure may be applied any number of times, and each application would use its capture again. So a lambda that captures an obligation is an obligation itself: it is consumed once, by a call or as the function `spawn` or `spawnMonitored` takes, and in any other place, passed, stored, returned or sent, it is refused (§6.6). A `let` may name it, and the name is consumed as the lambda is. A lambda that captures such a name captures an obligation in turn. A local `fn` may capture none, since it may be called many times. The lambda's type does not show the obligation, and need not: the lambda cannot leave the function that made it except into a `spawn`, which runs it once.

### 6.7 Restrictions: code that does not know its argument's type

The claim behind 6.5's last point is that every function value, given a reply-carrying argument, consumes it exactly once on each path that returns. A lambda and a `fn` whose parameter types are known are checked with the parameters as obligations. A definition generalized over a type variable is read once more with that variable taken for reply-carrying. Where that reading breaks the discipline the variable takes the not-reply-carrying restriction, and an instance at a reply-carrying type is refused where it is used (§3.9).

- **One reading suffices.** Code that does not know a value's type can only move the value, so what it does with one reply-carrying type it does with every one. Each variable is read alone, and that is enough: a break under two assumptions is a misuse of some value, whose type holds one of the two variables.
- **The variable may stand anywhere in the definition's type.** A function the definition returns, or holds in a list or a field, is read as the definition is: `fn pair() = fn(x) = #(x, x)` has the type `() -> (a!) -> #(a!, a!)`. A lambda a block's `let` binds takes its restrictions before it is generalized.
- **The restriction follows the value.** Passing a value to a function that has the restriction restricts the caller's variable: the two variables are one where the value is passed alone, and where it is passed inside another value, `dup([x])`, the reading finds a reply-carrying type where the restriction forbids one.
- **What has no body is restricted by rule**: a foreign function's variables by §4.7, and the prelude's by §9. A foreign function's equality mark (§4.7) adds a restriction and removes none, so an instance it admits is one the function without it admits.
- **Pure code answers nothing.** `answer`, `send` and `spawn` are process-only, so pure code that returns can only hand a reply on, through its result, or discharge a value that holds none. A guard is pure and its value is a `Bool`, so a guard that is given a live reply does not return, and one that falls through has consumed none (§6.6).

### 6.8 The call that does not return

A call to a function whose result type is a type variable that neither a parameter's type nor its mailbox type names consumes every obligation open on its path (§6.6). The reason is that such a function may be taken at `Never`, where it takes the same arguments and runs in the same process, since the variable stands in neither, and there it would return a value of a type that has none. What a function does does not depend on the type it is taken at: types are checked and then gone. So it returns at no type: it faults, runs for ever, or ends the program. A requirement on the variable changes nothing, since a member takes values of the type and makes none from nothing, and a foreign function that returns at such a variable faults at the boundary or returns no value of it (§8.4, **Type variables**). A function whose result type is its mailbox type is not of this kind: taken at `Never` it runs in another process, one that receives nothing, and elsewhere it returns what it receives.

### 6.9 An operator

`a + b` is the call `T.+(a, b)` for the type `T` of its operands, chosen once the enclosing definition is inferred (§4.8). The member is a function, its type `(T, T) -> R` is checked at its declaration, and nothing is chosen while the program runs, so an operator adds no step to section 5. Where the operand's type is a type variable of the signature, the member is the requirement's (6.10), and on any other type variable the operator is refused. An operator carries nothing the program did not declare.

### 6.10 A requirement and what supplies it

`needs a.compare` is a parameter the program does not write: the member, of type `(a, a) -> Ordering`. The argument is that every use of a declaration with a requirement is given the member, of the right type, when the program is compiled (§4.9).

- **At a known type** the type's member is supplied, and its whole type is checked against the member's shape at that type, so a member declared for `Vec(Int)` alone does not serve `Vec(String)`.
- **At a type variable of the enclosing signature** the enclosing requirement supplies it, and a variable the enclosing declaration's requirement does not name is refused.
- **`show` at a type built from type variables** the enclosing requirement names `show` for is the type's descriptor with each variable's descriptor, which came in as that requirement's member, in the variable's place (Appendix E.1). A descriptor passed in describes every value of the type its caller instantiated the variable to, by induction on the calls that supplied it, so the composed one describes every value of the instance. A descriptor passed in binds each recursive reference inside it, so it stands in a variable's place whatever recursive type encloses it.
- **Anywhere else it is refused**: at a variable nothing fixes, and in a top-level `let`, which declares no requirement.

A requirement is never inferred and is no part of a scheme, so no function value carries one unmet: a declaration taken as a value is taken with its members supplied. A type has one member of each name, so the type alone decides what is supplied. A member is pure, so supplying one changes no effect.

### 6.11 A derived `compare`

`derives compare` makes a `fn T.compare` that is checked as any member is (§3.5), so it needs no rule of its own. Its requirement names the members of the parameters the comparison reaches, found as a least fixed point over the type's recursive group; a field whose type has no `compare` is refused at the declaration. It compares two finite values by constructor and then by field, and by 6.12 it calls itself at its own type alone.

### 6.12 The rule for a recursive group's types

Within a recursive group, a type of the group is named at the parameters of the type declared, each in its place (§3.9). Two things rest on it. Unfolding a type reaches the group's types at the same arguments only, so the properties a type has through its fields, that it carries a reply, that it has equality, which parameters stand in value positions, what a derived `compare` requires, are least fixed points over finitely many types. And a function over the type calls itself at its own type, as §3.9 requires of every recursive call, so a function can walk every type that is declared.

### 6.13 Equality

`==` on two values of one type is defined, so it cannot go wrong. The equality constraint (§3.10) keeps it from values that hold a function or an address, where the host's answer would not be the language's. The constraint travels as 6.7's restriction does: it is part of the scheme, is checked at each instance, and passes into the variables of a type a constrained variable is bound to. A foreign function has no `==` to infer it from: the mark its signature writes (§4.7) puts it on the scheme as the inference would, and from there it travels and is checked as an inferred one is. Foreign code that compares values at a variable without the mark is outside the argument as its other broken promises are; the standard library's keep Appendix E, which names the functions that require equality.

## 7. Across nodes

MVP 3.0 runs one program on several nodes (§8.3, §8.7), and the four claims hold on each node as they hold on one. Two things are added: which two types are one across nodes, and what crosses a node.

**Which two types are one.** Every definition has a hash, the SHA-256 of its canonical form, and a type's hash covers its name, its parameters, the `compare` its module declares or derives for it and its constructors with their fields' types' hashes (§8.7, §11.1, Appendix H); two nodes that hold one hash hold one definition, whatever each build calls it. A type's hash covers its order, so two types of one hash order their values alike, and a value of an ordered container, built under one `compare`, never crosses into code that reads it under another. The form holds whatever the back end reads of a definition, every name resolved to the identity of what it names and every inferred type the emitted code depends on (Appendix H), but for the definition's name, its positions and whether it is exported, which change no value it computes: a spawn's site shows the first two, and nothing compares them (§8.7). So two definitions of one form compute alike. That two forms never share a hash is SHA-256's, assumed. A key holds the hash of its message type beside its text, and a find answers an address only where the offering node holds the same hash (§8.7), so an address a find gives has the type `Address(m)` of the key, which is the mailbox type of the process it names, and I2 holds of it whatever builds the two nodes are of. A spawn's function is named by its identity, and the peer starts it only where its code table holds that identity and every binding its reach names has its value there; a definition's reach is hashed into it, so the function runs on the peer over the definitions it was compiled with, which is I1 there, and the spawn answers `Address(N)` for `f : () -> Unit with N`, which is I2. What the hashes leave out, the runtime's functions, the standard library and every foreign declaration over a module of OTP's or of `ern`'s, is assumed the same on every node by the floor (§8.7), stated below. On one node, across the shell's reload, two versions of a type are two types by hash: a binding made before the reload keeps the type it was checked under, and the checker refuses a message of one version to an address of the other (§11.2), so I2 holds on one node as the hashes hold it between nodes, and the host's one representation of the two versions' constructors is never reached by a message of the wrong one. No other operation gives a program a remote address: every one it holds came from a find, from a spawn, inside a message whose type was agreed by one of the two, or among the values a function spawned on a peer captured, which the spawn's check admits as it admits a message's.

**What crosses.** A value crosses as a value, in the host's external term format, and a type is bound to its node where a value of it could not: one that holds a function type, a foreign type, a resource, or an address or a reply of a bound type (§3.11). That no bound value is used on another node is by the three refusals, and by the one way a bound value crosses, as the payload of an adapted address, which no operation on another node reaches. A key is refused at a bound type, so no remote address of a bound type comes from a find. A spawn is refused where its function's mailbox type is bound or holds a type variable, which a later instance could make bound, but for a variable the type of the definition does not hold, which no instance reaches, and which is `Never`, so that no message reaches the process; so none comes from a spawn. Its function is a top-level declaration's name, which captures nothing, or a lambda or a `fn` written in the definition, whose captures are the locals its body names, and the spawn is refused where one of them is bound or holds a type variable and so might be bound, and where the body uses a member of a requirement in force, a function the definition was given, so no bound value crosses with a function; `restarting` applied to one of these captures the limit, of the prelude's `RestartLimit`, which crosses, and that function, and nothing else; a function that came by any other way is refused, since its captures are not in its type, and `Peer.spawn` is never a value, so no call escapes the check. Every remote address a program holds is therefore of an unbound type, so every message sent to one is of an unbound type, and so is everything inside it. An adapted address crosses with its captured values as payload: its function is pure (6.3) and runs only on the node that made it, where those values are at home, and the message it makes is of its target's mailbox type (I2), sent on from there (§6.5). A reply crosses inside a message, to one holder, as on one node, and is answered through the host's alias, which takes one answer (§6.6); I3 holds with the processes of every node as one configuration, the note a callee's node keeps being part of the runtime's record of the call, which answers nothing (section 4). A `Down` with `Unreachable` is made by the watcher's node and reaches the watcher through its wrap, at its mailbox type, as every message the runtime delivers does (section 5). A `send` to a process of a node out of reach, and a `kill`, do nothing (§6.2), and a send to an adapted address an earlier start of its node made is dropped, its function not applied (§8.7), which keeps I1 as a send to an ended process does.

**The end.** The runtime delivers `wrap(reply)` to each subscriber of `Os.terminating` at its own mailbox type, as every message the runtime delivers (section 5), so I1 holds; the reply is fresh, held by that one message, and answered through the alias, so I3 holds; and the end waits for the answer or the subscriber's end, so no process runs after the end, which is §8.6's claim as it was. A process that waits while the end waits is no deadlock, since the end's own answers are in flight.

**What is not argued.** That a peer keeps the rules: a peer is trusted whole (§8.7), and a value of another type it sends on purpose is met where the receiving process matches on it, outside the argument as foreign code's broken promises are. That a message arrives: a loss drops what was in flight, and the argument is of the values that do arrive. That every node stands on the floor it proves, one release of `ern` on one major release of OTP: `ern`'s version names the runtime's functions and the standard library, which the hashes leave out (§8.7).

## 8. What it leaves

- **The standard results it leans on** are not argued again: that Hindley-Milner inference gives each expression a type the rules of section 3 derive, and that the coverage check of §5.9 refuses a `match` that some value escapes.
- **The checker against the rules.** The argument is of the report. The checker's tests hold each paragraph of section 6 as a case that is refused or accepted, and the typed generator's round on replies changes consumptions in programs that run, each change one the checker must refuse.
- **Sessions.** A session declares a type anew (§11.2), a question of which two types are one, which section 7 answers by the hash: two declarations are one type where their hashes are equal, across nodes of different builds and across a reload in one session alike.
