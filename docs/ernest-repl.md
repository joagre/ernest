# Paper Program 4: REPL

Written against the Ernest report, September 2026. A read-evaluate-print loop for a small expression language with numbers, `let`, functions of one argument, and recursion. The aim is to hit deep error handling in pure code (lexer, parser, evaluator) and `try` as a process (an expression that never terminates must be abortable).

## Assumptions

The runtime is assumed to provide `Sys.stdin : Address(StdinMsg)` as an additional ambient reference beyond the report's required `Sys.stdout` and `Sys.clock`, with `ReadLine(reply : Address(Text))`: one line per request. `Text.chars`, `Char.isDigit`, `Char.isAlpha`, `Char.toText`, and `Text.toInt : (Text) -> Optional(Int)` are in the standard library (report Appendix E). `ParseError.toText : (ParseError) -> Text` and `EvalError.toText : (EvalError) -> Text` are hand-written renderings for stdout; both are `todo("on paper")` here.

## The Program

```
// Types ----------------------------------------------------------

type Token = Num(Int) | Ident(Text) | Op(Char) | LParen | RParen | KwLet | KwFun | Eq | Arrow
type LexError = BadChar(c : Char, at : Int)

type Expr
    = Lit(Int)
    | Var(Text)
    | Bin(op : Char, l : Expr, r : Expr)
    | Let(name : Text, value : Expr)
    | Fun(param : Text, body : Expr)
    | App(f : Expr, arg : Expr)

type ParseError = Unexpected(Token) | Eof
type Step = (Expr, List(Token))

type Value = N(Int) | Closure(param : Text, body : Expr, env : Map(Text, Value))
type EvalError = Unbound(Text) | DivZero | NotAFunction | NotANumber

type TryError = Eval(EvalError) | Crashed | Timeout

type ReplMsg
    = Input(Text)
    | Result(Either(EvalError, Value))
    | Died(Down)

// Program --------------------------------------------------------

fn main() -> () with () = {
    let _ = spawn(Local, fn() = repl(Map.empty));
    ()
}

// Processes ------------------------------------------------------

fn repl(env : Map(Text, Value)) -> () with ReplMsg = {
    send(Sys.stdin, ReadLine(reply = via(Input, self())));
    recv {
        Input(text) -> match tokenize(text) {
            Left(BadChar(c = c, at = i)) -> {
                Io.println("illegal character " ++ Char.toText(c) ++ " at " ++ Int.toText(i));
                repl(env)
            }
          | Right(toks) -> match parse(toks) {
                Left(e) -> { Io.println(ParseError.toText(e)); repl(env) }
              | Right(e) -> {
                    let v = try(env, e);
                    match (e, v) {
                        (Let(name = x), Right(val)) -> { show(Right(val)); repl(Map.put(env, x, val)) }
                      | (_, r)                          -> { show(r); repl(env) }
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
        Result(r) -> Either.mapLeft(r, Eval)
      | Died(_)   -> Left(Crashed)                 // a fault in the child
      | after 2000 -> { kill(child); Left(Timeout) }
    }
}

fn show(r : Either(TryError, Value)) -> () with ReplMsg = Io.println(match r {
    Right(N(n))       -> Int.toText(n)
  | Right(Closure) -> "<fun>"
  | Left(Eval(e))     -> "error: " ++ EvalError.toText(e)
  | Left(Crashed)     -> "crashed"
  | Left(Timeout)     -> "aborted after 2 s"
})

// Pure code: lexer -----------------------------------------------

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
```
