# Paper Program 4: REPL

Written against the Ernest report, September 2026. A read-evaluate-print loop for a small expression language with numbers, `let`, functions of one argument, and recursion. The aim is to hit deep error handling in pure code (lexer, parser, evaluator) and `try` as a process (an expression that never terminates must be abortable).

## Assumptions

`Sys` is assumed to have `stdin : Address(StdinMsg)` with `ReadLine(reply : Address(Line))`: one line per request. The prelude is assumed to have `Text.chars`, `Char.isDigit`, `Char.isAlpha`, `Int.parse : (Text) -> Optional(Int)`.

## The Program

```
// Pure code: lexer -----------------------------------------------

type Token = Num(Int) | Ident(Text) | Op(Char) | LParen | RParen | KwLet | KwFun | Eq | Arrow
type LexError = BadChar(c : Char, at : Int)

fn tokenize(t : Text) -> Either(LexError, List(Token)) = lex(Text.chars(t), 0, [])

fn lex(cs : List(Char), i : Int, acc : List(Token)) -> Either(LexError, List(Token)) = match cs {
    []         -> Right(List.reverse(acc))
  | ' ' +: r   -> lex(r, i + 1, acc)
  | '(' +: r   -> lex(r, i + 1, LParen +: acc)
  | ')' +: r   -> lex(r, i + 1, RParen +: acc)
  | '=' +: r   -> lex(r, i + 1, Eq +: acc)
  | '-' +: '>' +: r -> lex(r, i + 2, Arrow +: acc)
  | c +: r when Char.isDigit(c) -> {
        let (digits, rest) = List.span(cs, Char.isDigit);
        let n = match Text.toInt(Text.fromChars(digits)) { Some(v) -> v | None -> 0 };
        lex(rest, i + List.size(digits), Num(n) +: acc)
    }
  | c +: r when Char.isAlpha(c) -> {
        let (word, rest) = List.span(cs, Char.isAlpha);
        let tok = match Text.fromChars(word) { "let" -> KwLet | "fun" -> KwFun | w -> Ident(w) };
        lex(rest, i + List.size(word), tok +: acc)
    }
  | c +: r when List.contains(['+', '-', '*', '/'], c) -> lex(r, i + 1, Op(c) +: acc)
  | c +: _   -> Left(BadChar(c = c, at = i))
}

// Pure code: parser ----------------------------------------------
// expr   := 'let' ident '=' expr | 'fun' ident '->' expr | sum
// sum    := prod (('+'|'-') prod)*
// prod   := app (('*'|'/') app)*
// app    := atom atom*
// atom   := num | ident | '(' expr ')'

type Expr
    = Lit(Int)
    | Var(Text)
    | Bin(op : Char, l : Expr, r : Expr)
    | Let(name : Text, value : Expr)
    | Fun(param : Text, body : Expr)
    | App(f : Expr, arg : Expr)

type ParseError = Unexpected(Token) | Eof

type Step = (Expr, List(Token))

fn parse(toks : List(Token)) -> Either(ParseError, Expr) = {
    let (e, rest) <- expr(toks);
    match rest { [] -> Right(e) | t +: _ -> Left(Unexpected(t)) }
}

fn expr(toks : List(Token)) -> Either(ParseError, Step) = match toks {
    KwLet +: Ident(x) +: Eq +: r    -> { (v, r2) <- expr(r); Right((Let(name = x, value = v), r2)) }
  | KwFun +: Ident(x) +: Arrow +: r -> { (b, r2) <- expr(r); Right((Fun(param = x, body = b), r2)) }
  | _ -> sum(toks)
}

fn sum(toks : List(Token)) -> Either(ParseError, Step) = { (l, r) <- prod(toks); sumRest(l, r) }

fn sumRest(l : Expr, toks : List(Token)) -> Either(ParseError, Step) = match toks {
    Op(c) +: r when c == '+' || c == '-' -> { (x, r2) <- prod(r); sumRest(Bin(op = c, l = l, r = x), r2) }
  | _ -> Right((l, toks))
}

fn prod(toks : List(Token)) -> Either(ParseError, Step) = { (l, r) <- app(toks); prodRest(l, r) }

fn prodRest(l : Expr, toks : List(Token)) -> Either(ParseError, Step) = match toks {
    Op(c) +: r when c == '*' || c == '/' -> { (x, r2) <- app(r); prodRest(Bin(op = c, l = l, r = x), r2) }
  | _ -> Right((l, toks))
}

fn app(toks : List(Token)) -> Either(ParseError, Step) = { (f, r) <- atom(toks); appRest(f, r) }

fn appRest(f : Expr, toks : List(Token)) -> Either(ParseError, Step) = match atom(toks) {
    Left(_)        -> Right((f, toks))          // no atom: the application is over
  | Right((a, r))  -> appRest(App(f = f, arg = a), r)
}

fn atom(toks : List(Token)) -> Either(ParseError, Step) = match toks {
    Num(n) +: r   -> Right((Lit(n), r))
  | Ident(x) +: r -> Right((Var(x), r))
  | LParen +: r   -> {
        let (e, r2) <- expr(r);
        match r2 {
            RParen +: r3 -> Right((e, r3))
          | t +: _       -> Left(Unexpected(t))
          | []           -> Left(Eof)
        }
    }
  | t +: _        -> Left(Unexpected(t))
  | []            -> Left(Eof)
}

// Pure code: evaluator -------------------------------------------

type Value = N(Int) | Closure(param : Text, body : Expr, env : Map(Text, Value))
type EvalError = Unbound(Text) | DivZero | NotAFunction | NotANumber

fn eval(env : Map(Text, Value), e : Expr) -> Either(EvalError, Value) = match e {
    Lit(n) -> Right(N(n))
  | Var(x) -> match Map.get(env, x) { Some(v) -> Right(v) | None -> Left(Unbound(x)) }
  | Fun(param = p, body = b) -> Right(Closure(param = p, body = b, env = env))
  | Let(value = v) -> eval(env, v)             // the REPL binds the name, see repl
  | Bin(op = op, l = l, r = r) -> {
        let lv <- eval(env, l);
        let rv <- eval(env, r);
        arith(op, lv, rv)
    }
  | App(f = f, arg = a) -> {
        let fv <- eval(env, f);
        let av <- eval(env, a);
        match fv {
            Closure(param = p, body = b, env = cenv) -> eval(Map.put(cenv, p, av), b)
          | N(_) -> Left(NotAFunction)
        }
    }
}

fn arith(op : Char, a : Value, b : Value) -> Either(EvalError, Value) = match (a, b) {
    (N(x), N(y)) -> match op {
        '+' -> Right(N(x + y))
      | '-' -> Right(N(x - y))
      | '*' -> Right(N(x * y))
      | _   -> match Int.div(x, y) { Some(q) -> Right(N(q)) | None -> Left(DivZero) }
    }
  | _ -> Left(NotANumber)
}

// Processes -------------------------------------------------------

type TryError = Eval(EvalError) | Crashed | Timeout

type ReplMsg
    = Line(Text)
    | Result(Either(EvalError, Value))
    | Died(Down)

fn repl(stdin : Address(StdinMsg), out : Address(Line), env : Map(Text, Value)) -> () with ReplMsg = {
    send(stdin, ReadLine(reply = via(Line, self())));
    recv {
        Line(text) -> match tokenize(text) {
            Left(BadChar(c = c, at = i)) -> {
                send(out, Line("illegal character " ++ Char.toText(c) ++ " at " ++ Int.toText(i)));
                repl(stdin, out, env)
            }
          | Right(toks) -> match parse(toks) {
                Left(e) -> { send(out, Line(ParseError.toText(e))); repl(stdin, out, env) }
              | Right(e) -> {
                    let v = try(env, e);
                    match (e, v) {
                        (Let(name = x), Right(val)) -> { show(out, Right(val)); repl(stdin, out, Map.put(env, x, val)) }
                      | (_, r)                          -> { show(out, r); repl(stdin, out, env) }
                    }
                }
            }
        }
    }
}

// try as a process: evaluate in a child, wait at most two seconds,
// kill the child if it does not answer.
fn try(env : Map(Text, Value), e : Expr) -> Either(TryError, Value) with ReplMsg = {
    let me = self();                               // not self() inside the lambda: that is the child's
    let child = spawn(Local, fn() = send(me, Result(eval(env, e))));
    monitor(child, Died);
    recv {
        Result(r) -> Either.mapLeft(Eval, r)
      | Died(_)   -> Left(Crashed)                 // a fault in the child
      | after 2000 -> { kill(child); Left(Timeout) }
    }
}

fn show(out : Address(Line), r : Either(TryError, Value)) -> () with ReplMsg = send(out, Line(match r {
    Right(N(n))       -> Int.toText(n)
  | Right(Closure) -> "<fun>"
  | Left(Eval(e))     -> "error: " ++ EvalError.toText(e)
  | Left(Crashed)     -> "crashed"
  | Left(Timeout)     -> "aborted after 2 s"
}))

fn main(Sys(stdin = stdin, stdout = out) : Sys) -> () with () = {
    let _ = spawn(Local, fn() = repl(stdin, out, Map.empty));
    ()
}
```

## What Chafed

**1. Nested matches on `Either`, measured.** The first version, without `<-`: the parser has eleven functions returning `Either`, seven of them with a match whose `Right` arm contains the next step, and `atom` and `eval`'s `App` arm were three levels deep. 43 of 140 lines of pure code were `Left(e) -> Left(e)`, thirty percent that said nothing. The code above is the version with `let x <- e`; the three places now read:

```
  | LParen +: r -> {
        let (e, r2) <- expr(r);
        match r2 {
            RParen +: r3 -> Right((e, r3))
          | t +: _       -> Left(Unexpected(t))
          | []           -> Left(Eof)
        }
    }

  | Bin(op = op, l = l, r = r) -> {
        let lv <- eval(env, l);
        let rv <- eval(env, r);
        arith(op, lv, rv)
    }
  | App(f = f, arg = a) -> {
        let fv <- eval(env, f);
        let av <- eval(env, a);
        match fv {
            Closure(param = p, body = b, env = cenv) -> eval(Map.put(cenv, p, av), b)
          | N(_) -> Left(NotAFunction)
        }
    }
```

Fifteen lines against twenty-four in the first version, and none of the fifteen is a forwarding. The web server tempted, the file sync did not, the game did not, the REPL is where it is decided: a program with deep pure error handling has thirty percent noise without `<-`. That is the evidence Later asked for.

**2. `<-` tested against the principles.** Least surprise: Gleam has `use x <- result.try(e)`, Haskell and Unison have `<-` in do-blocks; the form is recognized. No variants: there is no other flat form; the nesting is not a variant but what `<-` is rewritten into. Nothing invisible: `<-` stands on the line, and the block's type says `Either`. Orthogonal: the rule is local to blocks and `Either`, touches neither functions nor processes, no early return. Words: no new reserved word, `<-` is a symbol like `=`. Small: one rule in the block grammar. It passes. Should `<-` apply to `Optional` too? Same rule, `None` becomes the block's value; that is one more type on the same line, not a second rule. Yes, if the block is `Optional`; the type checker knows which.

**3. Two clauses again.** `arith` was first written with two clauses, the third time in three programs, out of Haskell habit. The specification says one clause and `match`, and it is right, but the habit is strong enough that there should be a clear error message: "a function has one clause; write match." Fixed above: `match (a, b)`.

**4. `try` as a process worked, with a gap.** Nine lines: spawn, monitor, recv with a time limit, kill. It is `catch` with a timeout, and it shows. But the child must send to the parent, and `self()` inside the `spawn` lambda is the child's address; the first version wrote `parent`, which did not exist. The solution is to bind before, `me = self()`, as the code above does. Erlang has the same trap with `self()` in `spawn(fun() -> ... end)`, and an error message cannot help, since the code type-checks with the child's `self()` if the types happen to agree. Now stands as a warning under `spawn`.

**5. `EvalError` first got two constructors from the process.** `Crashed` and `Timeout` are not the evaluator's errors but `try`'s, and they ended up in `EvalError` because `try` returned the same type. Fixed: `Either(TryError, Value)` with `TryError = Eval(EvalError) | Crashed | Timeout`. One line, and it shows that the process boundary has its own error type, an error as message in the report, and that it must not be mixed with an error as value.

**6. What did not chafe.** `recv` as a form carried `repl` and `try`. The environment as an argument in the loop was the obvious thing; nobody missed a registry. The lexer with guards and list patterns reads like the grammar. `Int.div` as `Optional` gave `DivZero` for free, without anyone having to think about it: totality did the work.

## Adopted into the Report

- `<-` from Later to Syntax in the report (findings 1 and 2), for `Either` and `Optional`. Adopted.
- Warning under `spawn`: `self()` in the lambda is the child's; bind before (finding 4). Adopted.
- Error message for multiple clauses (finding 3), in the plan. Adopted.
- `TryError` as an example of a message (finding 5), under Errors. Adopted into the decision log.
- The code transferred to syntax revision 3 and to the grammar audit: single `Int`, named fields in parentheses, `let`.
