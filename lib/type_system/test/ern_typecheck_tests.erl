-module(ern_typecheck_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("parser/include/ern_ast.hrl").
-include_lib("type_system/include/ern_types.hrl").

check(Text) -> ern_typecheck:check_string(['M'], Text).

ok(Text) ->
    case check(Text) of
        {ok, _, _, _} -> ok;
        {error, Errs} -> {error, [ern_typecheck:format_error(E) || E <- Errs]}
    end.

%% The printed type of the declaration named Name.
type_of(Text, Name) ->
    {ok, _, #iface{values = Vs}, _} = check(Text),
    Scheme = maps:get(['M', Name], Vs),
    ern_types:format_scheme(Scheme, ern_typecheck:type_state(ern_typecheck:prelude_env())).

err(Text) ->
    {error, [{_, _, Msg} | _]} = check(Text),
    Msg.

errs(Text) ->
    {error, Errs} = check(Text),
    [Msg || {_, _, Msg} <- Errs].

%%
%% Inference
%%

%% report §3.9
basic_inference_test() ->
    ?assertEqual("(Int) -> Int", type_of("export fn double(n) = n * 2", double)),
    ?assertEqual("(a) -> a", type_of("export fn id(x) = x", id)),
    ?assertEqual("(a, b!) -> a", type_of("export fn first(x, y) = x", first)),
    ?assertEqual("((a) -> b with e, a) -> b with e",
                 type_of("export fn apply(f, x) = f(x)", apply)),
    ?assertEqual("(Int) -> Int",
                 type_of("export fn fact(n : Int) -> Int = if n == 0 then 1 else n * fact(n - 1)",
                         fact)),
    ?assertEqual("((a) -> b with e, a, a) -> #(b, b) with e",
                 type_of("export fn map2(f, x, y) = #(f(x), f(y))", map2)),
    ?assertEqual("() -> List(a)", type_of("export fn namedEmpty() = { let xs = []; xs }",
                                          namedEmpty)),
    ?assertEqual("(List(a)) -> Int", type_of("export fn len(xs) = List.size(xs)", len)).

%% report §3.9, §11.5
constraints_are_inferred_and_printed_test() ->
    ?assertEqual("(a=, a=) -> Bool", type_of("export fn equal(a, b) = a == b", equal)),
    ?assertEqual("(a!) -> #(a!, a!)", type_of("export fn dup(x) = #(x, x)", dup)),
    ?assertEqual("(a!) -> Unit", type_of("export fn discard(x) = Unit", discard)),
    ?assertEqual("(a) -> a", type_of("export fn identity(x) = x", identity)).

%% report §4.8
operators_need_a_determined_operand_type_test() ->
    ?assertEqual("the operand type of `+` is not determined; annotate it",
                 err("fn twice(n) = n + n")),
    ?assertEqual("(Int) -> Int", type_of("export fn twice(n : Int) = n + n", twice)),
    ?assertEqual("Float arithmetic is not in MVP 1", err("fn f(x : Float) = x + x")),
    ?assertEqual("`+` is not defined on String", err("fn f(s : String) = s + s")),
    ?assertEqual("(String, String) -> String", type_of("export fn cat(a, b) = a <> b <> \"!\"",
                                                       cat)),
    ?assertEqual("`<>` is not defined on Int", err("fn f(x : Int) = x <> x")),
    ?assertEqual("(Int, Int) -> Bool", type_of("export fn lt(a : Int, b) = a < b", lt)),
    ?assertEqual("`<` is not defined on Bool", err("fn f(a : Bool, b) = a < b")).

%% report §3.10
equality_test() ->
    ?assertEqual("`==` is not defined on (Int) -> Int: it contains a function or an address",
                 err("fn f(g : (Int) -> Int) = g == g")),
    ?assertEqual("Address(Int) does not support equality (it contains a function or an"
                 " address), but it is compared here",
                 err("fn same(a : Address(Int), b) = equal(a, b)\nfn equal(a, b) = a == b")),
    ?assertEqual("Address(Int) does not support equality (it contains a function or an"
                 " address), but it is compared here",
                 err("fn f(a : Address(Int)) = Map.put(Map.empty, a, 1)")),
    ?assertEqual(ok, ok("fn f(a : String) = Map.put(Map.empty, a, 1)")).

%%
%% Effects (report §3.9, §6.1)
%%

%% report §3.9, §6.1
effects_test() ->
    ?assertEqual("() -> Unit with e", type_of("export fn main() = Io.println(\"x\")", main)),
    ?assertEqual("() -> Unit with Never",
                 type_of("export fn main() -> Unit with Never = Io.println(\"x\")", main)),
    ?assertEqual("this call needs a process: process code called from a pure function",
                 err("fn main() -> Unit = Io.println(\"x\")")),
    ?assertEqual("() -> Address(a) with a", type_of("export fn me() = self()", me)),
    ?assertEqual("(Address(a), a) -> Unit with e",
                 type_of("export fn wrap(a, v) = send(a, v)", wrap)),
    %% an effect used nowhere else is pure
    ?assertEqual("(List(Int)) -> List(Int)",
                 type_of("export fn inc(xs) = List.map(xs, fn(x) = x + 1)", inc)),
    ?assertEqual("(List(String)) -> Unit with e",
                 type_of("export fn say(xs) = List.foreach(xs, fn(x) = Io.println(x))", say)),
    ?assertEqual(ok, ok("type A = A\ntype B = B\nfn ga() -> Unit with A = Unit\n"
                        "fn gb() -> Unit with B = Unit\nfn ha() -> Unit with A = ga()")),
    ?assertMatch({error, [_]}, ok("type A = A\ntype B = B\nfn ga() -> Unit with A = Unit\n"
                                  "fn gb() -> Unit with B = Unit\n"
                                  "fn both() = { ga(); gb() }")).

%% report §6.3, §6.8
receive_and_mailboxes_test() ->
    Counter = "type CounterMsg = Inc(Int) | Get(reply : Reply(Int))\n"
              "export fn counter(n : Int) -> Unit with CounterMsg = receive {\n"
              "    Inc(k) -> counter(n + k)\n"
              "  | Get(reply = r) -> { answer(r, n); counter(n) }\n}",
    ?assertEqual("(Int) -> Unit with M.CounterMsg", type_of(Counter, counter)),
    ?assertEqual("`receive` in a pure function; give it a mailbox type with `with`",
                 err("fn f() -> Unit = receive { after 1 -> Unit }")),
    ?assertEqual(ok, ok("fn f() -> Unit with Never = receive { after 1 -> Unit }")),
    ?assertEqual("a function with mailbox Never cannot receive; only an `after` clause is"
                 " allowed",
                 err("fn f() -> Unit with Never = receive { Unit -> Unit }")),
    ?assertEqual("(a!) -> Unit with e",
                 type_of("export fn tick(n) = { let m = receive { k -> k }; Unit }", tick)).

%% report §6.2, §4.6
spawn_test() ->
    ?assertEqual(ok, ok("fn work() -> Unit with Never = Unit\n"
                        "fn main() -> Unit with Never = { let _ = spawn(Local, fn() = work());"
                        " Unit }")),
    ?assertEqual("the arguments do not fit spawn: process code called from a pure function",
                 err("fn main() -> Unit with Never = { let _ = spawn(Local, fn() -> Unit = Unit);"
                     " Unit }")),
    ?assertEqual("the type of a is not determined (Address(a)); use it, or annotate it",
                 err("fn work() = Unit\n"
                     "fn main() -> Unit with Never = { let a = spawn(Local, fn() = work());"
                     " Unit }")).

%% report §5.9
guards_are_pure_test() ->
    ?assertEqual(ok, ok("fn f(n : Int) = match n { k when k > 0 -> 1 | _ -> 0 }")),
    ?assertMatch("a guard is a Bool: " ++ _,
                 err("fn f(n : Int) = match n { k when k -> 1 | _ -> 0 }")),
    ?assertEqual("this call needs a process: process code called from a pure function",
                 err("fn f(n : Int) -> Int with Never = match n {"
                     " k when Io.println(\"x\") == Unit -> 1 | _ -> 0 }")).

%%
%% Patterns and blocks
%%

%% report §5.10
patterns_test() ->
    ?assertEqual("variable x appears twice in the pattern",
                 err("fn f(p) = match p { #(x, x) -> x }")),
    ?assertEqual("a `let` pattern must be irrefutable; use match",
                 err("fn f(o) = { let Some(x) = o; x }")),
    ?assertEqual(ok, ok("type P = P(x : Int, y : Int)\nfn f(p) = { let P(x = a) = p; a }")),
    ?assertEqual("a parameter pattern must be irrefutable", err("fn f(Some(x)) = x")),
    ?assertEqual("(M.P) -> Int",
                 type_of("type P = P(x : Int, y : Int)\nexport fn getX(P(x = v) : P) = v", getX)),
    ?assertEqual("Get has no field bogus",
                 err("type R = Get(reply : Int)\nfn f(r) = match r { Get(bogus = b) -> b }")).

%% report §4.6, §5.4
blocks_test() ->
    ?assertEqual("the type of xs is not determined (List(a)); use it, or annotate it",
                 err("fn f() = { let xs = []; 1 }")),
    %% List.size does not pin the element type; :: does (report §4.6)
    ?assertEqual("the type of xs is not determined (List(a)); use it, or annotate it",
                 err("fn f() = { let xs = []; List.size(xs) + 1 }")),
    ?assertEqual(ok, ok("fn f() = { let xs = []; List.size(1 :: xs) + 1 }")),
    ?assertEqual(ok, ok("fn f() = { let m : Map(String, Int) = Map.empty; m }")),
    ?assertEqual(ok, ok("fn f() = { let _ = []; 1 }")),
    %% local fns see earlier lets and each other
    ?assertEqual("(Int) -> Int",
                 type_of("export fn f(n : Int) = { let k = 2; fn g(x) = x * k; fn h(x) = g(x) + 1;"
                         " h(n) }", f)),
    ?assertEqual("(a) -> a",
                 type_of("export fn f(v) = { fn id(x) = x; let a = id(1); let b = id(\"s\");"
                         " id(v) }", f)),
    ?assertEqual("unknown name k",
                 err("fn f(n : Int) = { fn g(x) = x * k; let k = 2; g(n) }")).

%% report §4.5
local_fn_names_are_plain_test() ->
    ?assertEqual("a type-member name, `fn T.name`, is a top-level form; a local function has a"
                 " plain name",
                 err("type T = T\nfn f() = { fn T.g() = 1; 2 }")).

%% report §5.4
local_fn_forward_reference_test() ->
    %% a is generalized only after b, which it references, is checked
    ?assertEqual("the arguments do not fit a: expected (Int) -> Int, found (String) -> a",
                 err("fn f() = { fn a(x) = b(x); fn b(x) = x + 1; a(\"s\") }")),
    ?assertEqual("() -> Int", type_of("export fn f() = { fn a(x) = b(x); fn b(x) = x + 1; a(1) }",
                                      f)),
    %% and is polymorphic afterwards when b is
    ?assertEqual("() -> Int",
                 type_of("export fn f() = { fn a(x) = b(x); fn b(x) = x; let s = a(\"s\");"
                         " a(1) }", f)),
    %% mutual recursion between local fns
    ?assertEqual("(Int) -> Bool",
                 type_of("export fn f(n : Int) = { fn even(k) = if k == 0 then true"
                         " else odd(k - 1); fn odd(k) = if k == 0 then false else even(k - 1);"
                         " even(n) }", f)).

%% report §5.4
local_fn_used_before_let_test() ->
    %% report §5.4: a local fn is visible throughout the block but usable
    %% only after the lets it references
    ?assertEqual("local function g is used before `let k`, which it references",
                 err("fn f(n : Int) = { let a = g(n); let k = 2; fn g(x) = x * k; a }")),
    ?assertEqual("local function h is used before `let k`, which it references",
                 err("fn f(n : Int) = { fn h(x) = g(x); let a = h(n); let k = 2;"
                     " fn g(x) = x * k; a }")),
    ?assertEqual("local function g is used before `let k`, which it references",
                 err("fn f(n : Int) = { let a = List.map([n], g); let k = 2; fn g(x) = x * k;"
                     " a }")),
    ?assertEqual(ok, ok("fn f(n : Int) = { let k = 2; let a = g(n); fn g(x) = x * k; a }")),
    ?assertEqual(ok, ok("fn f(n : Int) = { fn g(x) = x * 2; let a = g(n); let k = 2; a + k }")).

%% report §5.5
bind_arrow_test() ->
    Opt = "export fn parseAndAdd(a : String, b : String) -> Optional(Int) = {\n"
          "    let x <- String.toInt(a);\n    let y <- String.toInt(b);\n    Some(x + y)\n}",
    ?assertEqual("(String, String) -> Optional(Int)", type_of(Opt, parseAndAdd)),
    Either = "export fn positiveInt(text : String) -> Either(String, Int) = {\n"
             "    let n <- Either.fromOptional(String.toInt(text), \"not an integer\");\n"
             "    if n > 0 then Right(n) else Left(\"not positive\")\n}",
    ?assertEqual("(String) -> Either(String, Int)", type_of(Either, positiveInt)),
    %% inferred from the block's type when e is not yet known
    ?assertEqual("(a) -> Either(String, Int)",
                 type_of("export fn f(n) -> Either(String, Int) = { let x <- g(n); Right(x + 1) }\n"
                         "fn g(n) = f(n)", f)),
    ?assertMatch("after `let p <- e` the block must have the same sum type as e: " ++ _,
                 err("fn f(a : String) = { let x <- String.toInt(a); Right(x) }")),
    ?assertMatch("`<-` needs an Either or an Optional, not Int", err("fn f() = { let x <- 1; x }")).

%%
%% Types and declarations
%%

%% report §3.5, §3.9, §4.2, §4.3
type_declarations_test() ->
    ?assertEqual("type T is declared twice", err("type T = A\ntype T = B")),
    ?assertEqual("constructor A is declared twice", err("type T = A\ntype U = A")),
    ?assertEqual("value f is declared twice", err("fn f() = 1\nlet f = 2")),
    ?assertEqual("type variable b is not a parameter of the type", err("type T(a) = T(b)")),
    ?assertEqual("unknown type Nope", err("fn f(x : Nope) = x")),
    ?assertEqual("List takes 1 type argument, not 2", err("fn f(x : List(Int, Int)) = x")),
    %% prelude names may be shadowed (report §4.2)
    ?assertEqual("(M.Key) -> Bool",
                 type_of("type Key = Up | Down\nexport fn isDown(k) = match k { Down -> true"
                         " | Up -> false }", isDown)),
    ?assertEqual("field names must be unique within a constructor",
                 err("type T = T(a : Int, a : Int)")).

%% report §3.9
annotations_are_rigid_test() ->
    ?assertEqual("type variable a in the annotation is used as Int", err("fn f(x : a) -> a = 1")),
    ?assertEqual("two type variables in the annotation are used as one type",
                 err("fn f(x : a, y : b) -> a = y")),
    ?assertEqual("(a) -> a", type_of("export fn id(x : a) -> a = x", id)),
    ?assertMatch("the body does not have the declared return type: " ++ _,
                 err("fn f(x : Int) -> String = x")).

%% report §3.4
with_binds_to_the_nearest_arrow_test() ->
    ?assertEqual("(Int) -> ((Int) -> Int with Never)",
                 type_of("export fn f(a : Int) -> (Int) -> Int with Never = fn(b) = a + b", f)),
    ?assertEqual("(Int) -> (Int) -> Int with Never",
                 type_of("export fn f(a : Int) -> ((Int) -> Int) with Never = fn(b) = a + b",
                         f)).

%% report §8.5
let_cycle_test() ->
    ?assertEqual("the initializer of a depends on itself, through b",
                 err("let a : Int = b\nlet b : Int = a")),
    ?assertEqual("the initializer of a depends on itself, through f",
                 err("let a : Int = f()\nfn f() -> Int = a")),
    ?assertEqual("the initializer of a depends on itself", err("let a : Int = a")),
    ?assertEqual(ok, ok("let a : Int = b + 1\nlet b : Int = 1")).

%% report §4.6
toplevel_let_test() ->
    ?assertEqual("Int", type_of("export let port : Int = 8080", port)),
    ?assertEqual("List(a)", type_of("export let empty = []", empty)),
    ?assertEqual("the value does not have the declared type: expected Float, found Int",
                 err("let pi : Float = 3")),
    ?assertEqual("this call needs a process: process code called from a pure function",
                 err("let x = Io.println(\"a\")")).

%% report §5.6
constructors_test() ->
    ?assertEqual("(Int) -> List(Optional(Int))",
                 type_of("export fn f(x : Int) = List.map([x], Some)", f)),
    ?assertEqual("missing field age", err("type P = P(name : String, age : Int)\n"
                                          "fn f() = P(name = \"a\")")),
    ?assertEqual("P has no field foo", err("type P = P(name : String, age : Int)\n"
                                           "fn f() = P(name = \"a\", age = 1, foo = 2)")),
    ?assertEqual(ok, ok("type P = P(name : String, age : Int)\n"
                        "fn f(p : P) = P(..p, age = 31)")),
    ?assertEqual("None takes no fields", err("fn f() = None(1)")),
    ?assertEqual("unknown constructor Nope", err("fn f() = Nope")).

%% report §5.2
calls_test() ->
    ?assertEqual("f takes 2 arguments, not 1; a call supplies them all",
                 err("fn f(a, b) = a\nfn g() = f(1)")),
    ?assertEqual("x is not a function; it has type Int", err("let x = 1\nfn g() = x(1)")),
    ?assertEqual("unknown name nope", err("fn g() = nope(1)")),
    ?assertEqual("(Int) -> Int", type_of("export fn add3(x) = makeAdder(3)(x)\n"
                                         "fn makeAdder(n : Int) = fn(m) = n + m", add3)).

%%
%% Exhaustiveness (report §5.9)
%%

%% report §5.9
exhaustiveness_test() ->
    ?assertEqual("match on Optional(a) is not exhaustive; missing None",
                 err("fn f(o) = match o { Some(x) -> x }")),
    ?assertEqual("match on Bool is not exhaustive; missing false",
                 err("fn f(b : Bool) = match b { true -> 1 }")),
    ?assertEqual("match on List(a) is not exhaustive; missing _ :: _",
                 err("fn f(xs) = match xs { [] -> 0 }")),
    ?assertEqual("match on List(Int) is not exhaustive; missing _ :: _ :: _",
                 err("fn f(xs : List(Int)) = match xs { [] -> 0 | [x] -> x }")),
    ?assertEqual("match on Int is not exhaustive; missing _",
                 err("fn f(n : Int) = match n { 0 -> 1 | 1 -> 2 }")),
    %% guards do not count
    ?assertEqual("match on Int is not exhaustive; missing _",
                 err("fn f(n : Int) = match n { k when k > 0 -> 1 | k when k <= 0 -> 0 }")),
    ?assertEqual("match on #(Optional(a), Bool) is not exhaustive; missing #(Some(_), false)",
                 err("fn f(p) = match p { #(None, _) -> 0 | #(Some(_), true) -> 1 }")),
    ?assertEqual(ok, ok("fn f(o) = match o { Some(x) -> x | None -> 0 }")),
    ?assertEqual(ok, ok("fn f(xs) = match xs { [] -> 0 | _ :: _ -> 1 }")),
    ?assertEqual(ok, ok("type R = Get(reply : Int) | Stop\n"
                        "fn f(r) = match r { Get(reply = n) -> n | Stop -> 0 }")),
    ?assertEqual("match on R is not exhaustive; missing Get",
                 err("type R = Get(reply : Int) | Stop\nfn f(r) = match r { Stop -> 0 }")).

%%
%% Reply discipline (report §6.6)
%%

%% report §6.6
reply_test() ->
    Msg = "type Req = Get(reply : Reply(Int)) | Stop\n",
    ?assertEqual(ok, ok(Msg ++ "fn serve(n : Int) -> Unit with Req = receive {\n"
                        "    Get(reply = r) -> { answer(r, n); serve(n) }\n  | Stop -> Unit }")),
    ?assertEqual("the reply-carrying value r is never consumed",
                 err(Msg ++ "fn serve(n : Int) -> Unit with Req = receive {\n"
                     "    Get(reply = r) -> serve(n)\n  | Stop -> Unit }")),
    ?assertEqual("the reply-carrying value r is consumed twice",
                 err(Msg ++ "fn serve(n : Int) -> Unit with Req = receive {\n"
                     "    Get(reply = r) -> { answer(r, n); answer(r, n) }\n  | Stop -> Unit }")),
    ?assertEqual("the reply-carrying value request is consumed twice",
                 err(Msg ++ "fn twice(dst : Address(Req), request : Req) ="
                     " { send(dst, request); send(dst, request) }")),
    ?assertEqual(ok, ok(Msg ++ "fn once(dst : Address(Req), request : Req) = send(dst, request)")),
    ?assertEqual("field reply of Get carries a reply and must be bound",
                 err(Msg ++ "fn f(r : Req) = match r { Get() -> 1 | Stop -> 0 }")),
    ?assertEqual("field reply of Get carries a reply and must be bound",
                 err(Msg ++ "fn f(r : Req) = match r { Get(reply = _) -> 1 | Stop -> 0 }")),
    ?assertEqual("`as` on a reply-carrying value would duplicate it",
                 err(Msg ++ "fn f(r : Req) = match r { Get(reply = x) as whole -> answer(x, 1)"
                     " | Stop -> Unit }")),
    ?assertEqual("a reply-carrying value cannot be an element of List",
                 err(Msg ++ "fn f(r : Req) = [r]")),
    ?assertEqual("the reply-carrying value r is consumed on one path but not on another",
                 err(Msg ++ "fn f(r : Reply(Int), b : Bool) = if b then answer(r, 1) else Unit")),
    ?assertEqual(ok, ok(Msg ++ "fn f(r : Reply(Int), b : Bool) = if b then answer(r, 1)"
                        " else answer(r, 2)")),
    ?assertEqual("in MVP 1 the reply-carrying value r is captured by a lambda that is not passed"
                 " directly to spawn",
                 err(Msg ++ "fn f(r : Reply(Int)) = List.map([1], fn(x) = answer(r, x))")),
    ?assertEqual(ok, ok(Msg ++ "fn f(r : Reply(Int)) -> Unit with Never ="
                        " { let _ = spawn(Local, fn() -> Unit with Never = answer(r, 1)); Unit }")),
    ?assertEqual("a reply-carrying value, Reply(Int), passed where the function duplicates or"
                 " discards its argument",
                 err(Msg ++ "fn dup(x) = #(x, x)\nfn f(r : Reply(Int)) = dup(r)")),
    ?assertEqual(ok, ok(Msg ++ "fn id(x) = x\nfn f(r : Reply(Int)) = answer(id(r), 1)")),
    ?assertEqual(ok, ok(Msg ++ "fn f(r : Reply(Int)) = { let r2 = r; answer(r2, 1) }")),
    %% the mk callback of Address.call
    ?assertEqual(ok, ok(Msg ++ "fn ask(a : Address(Req)) = Address.call(a, fn(r) = Get(reply = r),"
                        " 1000)")).

%% report §6.6, §3.9, §4.4, §4.7
warts_audit_test() ->
    Msg = "type Req = Get(reply : Reply(Int)) | Stop\n",
    %% a reply-carrying expression neither bound nor consumed
    ?assertEqual("a reply-carrying value is discarded; it must be consumed",
                 err(Msg ++ "fn f(r : Reply(Int)) = { Get(reply = r); Unit }")),
    ?assertEqual("`_` would discard a reply-carrying value",
                 err(Msg ++ "fn f(r : Reply(Int)) = { let _ = Get(reply = r); Unit }")),
    ?assertEqual("`_` would discard a reply-carrying value",
                 err(Msg ++ "fn f(_ : Reply(Int)) = Unit")),
    %% the flag reaches variables inside a tuple parameter
    ?assertEqual("(#(a, b!)) -> a", type_of("export fn fst(#(x, y)) = x", fst)),
    ?assertEqual("a reply-carrying value, Reply(Int), passed where the function duplicates or"
                 " discards its argument",
                 err(Msg ++ "fn fst(#(x, y)) = x\nfn f(r : Reply(Int)) = fst(#(1, r))")),
    %% a member less general than its signature
    ?assertEqual("Stack.push is (Int, Stack(Int)) -> Stack(Int), not the signature's"
                 " (a, Stack(a)) -> Stack(a)",
                 err("abstract type Stack(a) = Stack(List(a)) with {"
                     " push : (a, Stack(a)) -> Stack(a) }\n"
                     "fn Stack.push(x : Int, Stack(xs)) = Stack(x :: xs)")),
    %% duplicate field in a pattern
    ?assertEqual("a field is matched twice",
                 err(Msg ++ "fn f(r) = match r { Get(reply = a, reply = b) -> Unit"
                     " | Stop -> Unit }")),
    %% foreign fn with an effect is process-only
    ?assertEqual("this call needs a process: process code called from a pure function",
                 err("foreign fn tick() -> Unit with m = \"m:tick/0\"\nfn f() -> Unit = tick()")),
    ?assertEqual(ok, ok("foreign fn tick() -> Unit with m = \"m:tick/0\"\n"
                        "fn f() -> Unit with Never = tick()")),
    %% lambda annotation variables: the definition's are in scope and rigid,
    %% a new one belongs to the lambda and is not rigid
    ?assertEqual("(a) -> a", type_of("export fn f(x : a) -> a = (fn(y : a) -> a = y)(x)", f)),
    ?assertEqual("type variable a in the annotation is used as Int",
                 err("fn f(x : a) -> a = { let g = fn(y : a) -> a = 1; g(x) }")),
    ?assertEqual("(Int) -> Int", type_of("export fn f(x : Int) = (fn(y : b) -> b = 1)(x)", f)),
    ?assertEqual("(Int) -> Int", type_of("export fn f(x : Int) = (fn(y : b) -> b = y)(x)", f)).

%% report §3.1
base_types_test() ->
    ?assertEqual("() -> #(Int, Float, Char, String, Bool)",
                 type_of("export fn f() = #(1, 1.5, 'c', \"s\", true)", f)),
    ?assertEqual("() -> Unit", type_of("export fn f() = Unit", f)).

%% report §3.6
abstract_types_as_types_test() ->
    Stack = "export abstract type Stack(a) = Stack(List(a)) with {\n"
            "    empty : Stack(a);\n    push : (a, Stack(a)) -> Stack(a)\n}\n"
            "export let Stack.empty = Stack([])\n"
            "export fn Stack.push(x, Stack(xs)) = Stack(x :: xs)\n",
    ?assertEqual("(M.Stack(Int)) -> M.Stack(Int)",
                 type_of(Stack ++ "export fn f(s : Stack(Int)) = Stack.push(1, s)", f)),
    ?assertEqual("() -> M.Stack(String)",
                 type_of(Stack ++ "export fn f() = Stack.push(\"a\", Stack.empty)", f)),
    ?assertMatch("the arguments do not fit Stack.push: " ++ _,
                 err(Stack ++ "fn f(s : Stack(Int)) = Stack.push(\"a\", s)")),
    %% a sum type like any other: structural equality applies
    ?assertEqual("(M.Stack(Int), M.Stack(Int)) -> Bool",
                 type_of(Stack ++ "export fn same(a : Stack(Int), b) = a == b", same)).

%% report §3.8
foreign_types_test() ->
    Table = "export foreign type Table(k, v)\n"
            "foreign fn rawNew(name : String) -> Table(k, v) with m = \"ets:new/2\"\n",
    ?assertEqual("(M.Table(Int, String)) -> M.Table(Int, String)",
                 type_of(Table ++ "export fn id(t : Table(Int, String)) = t", id)),
    ?assertEqual("() -> M.Table(a, b) with e",
                 type_of(Table ++ "export fn new() = rawNew(\"t\")", new)),
    %% no constructors: nothing to construct or match on
    ?assertEqual("unknown constructor Table", err(Table ++ "fn f() = Table(1)")),
    ?assertEqual("unknown constructor Table",
                 err(Table ++ "fn f(t : Table(Int, Int)) = match t { Table(x) -> x }")),
    %% equality is identity, so it is allowed
    ?assertEqual("(M.Table(Int, Int), M.Table(Int, Int)) -> Bool",
                 type_of(Table ++ "export fn same(a : Table(Int, Int), b) = a == b", same)),
    %% held, passed, and sent
    ?assertEqual(ok, ok(Table ++ "fn send1(a : Address(Table(Int, Int)), t) = send(a, t)")).

%% report §3.7, §9.1, §9.2, §9.3: every built-in and declared type is usable
%% as a type, and every declared type's constructors cover it
prelude_types_test() ->
    ?assertEqual(ok, ok("fn f(a : Address(Int), n : Never, x : Foreign, l : List(Int),"
                        " m : Map(String, Int), s : Set(Char)) = Unit")),
    %% a Reply parameter must be consumed (§6.6), so it gets its own line
    ?assertEqual(ok, ok("fn f(r : Reply(Int)) -> Unit with Never = answer(r, 1)")),
    ?assertEqual(ok, ok("fn f(x : Unit) = match x { Unit -> 1 }")),
    ?assertEqual(ok, ok("fn f(x : Optional(Int)) = match x { None -> 0 | Some(v) -> v }")),
    ?assertEqual(ok, ok("fn f(x : Either(String, Int)) = match x { Left(_) -> 0"
                        " | Right(v) -> v }")),
    ?assertEqual(ok, ok("fn f(x : Ordering) = match x { Less -> 0 | Equal -> 1 | Greater -> 2 }")),
    ?assertEqual(ok, ok("fn f(x : Down) = match x { Down(reason = r, function = _) -> r }")),
    ?assertEqual(ok, ok("fn f(x : Reason) = match x { Returned -> 0 | Killed -> 1 | ProgramEnd -> 2"
                        " | Fault(_) -> 3 }")),
    ?assertEqual(ok, ok("fn f(x : ClockMsg) -> Unit with Never = match x {"
                        " After(ms = _, to = _) -> Unit | At(at = _, to = _) -> Unit"
                        " | Now(reply = r) -> answer(r, 0) }")),
    ?assertEqual(ok, ok("fn f(x : RemoteError) = match x { NoRemotePeer -> 0 | PeerLost -> 1 }")),
    ?assertEqual(ok, ok("fn f(x : Where) = match x { Local -> 0 | Peer(_) -> 1 }")).

%% report §9.4, §9.5, §9.6, §9.7 and Appendix E: every prelude and stdlib
%% signature parses, and every name resolves to a value
prelude_values_test() ->
    lists:foreach(fun({QName, Text}) ->
                      ?assertMatch({ok, _}, ern_parser:parse_type(Text)),
                      Name = lists:flatten(lists:join(".", [atom_to_list(P) || P <- QName])),
                      ?assertEqual(ok, ok("export let v = " ++ Name))
                  end, ern_prelude:values()),
    %% the process primitives are process-only, the stdlib combinators are not
    ?assertEqual("this call needs a process: process code called from a pure function",
                 err("fn f(a : Address(Int)) -> Unit = send(a, 1)")),
    ?assertEqual("(List(Int)) -> List(Int)",
                 type_of("export fn f(xs) = List.map(xs, fn(x : Int) = x)", f)),
    ?assertEqual("Address(String)", type_of("export let out = Sys.stdout", out)),
    ?assertEqual("Address(ClockMsg)", type_of("export let clk = Sys.clock", clk)).

%%
%% Abstract types and interfaces
%%

%% report §4.4
abstract_type_test() ->
    Stack = "export abstract type Stack(a) = Stack(List(a)) with {\n"
            "    empty : Stack(a);\n    push : (a, Stack(a)) -> Stack(a);\n"
            "    pop : (Stack(a)) -> Optional(#(a, Stack(a)))\n}\n"
            "export let Stack.empty = Stack([])\n"
            "export fn Stack.push(x, Stack(xs)) = Stack(x :: xs)\n"
            "export fn Stack.pop(Stack(xs)) = match xs { [] -> None | x :: rest ->"
            " Some(#(x, Stack(rest))) }\n",
    ?assertEqual(ok, ok(Stack)),
    ?assertEqual("(a, M.Stack(a)) -> M.Stack(a)",
                 type_of(Stack ++ "export fn use(x, s) = Stack.push(x, s)", use)),
    ?assertEqual("Stack.size is in the signature but not defined",
                 err("abstract type Stack(a) = Stack(List(a)) with { size : (Stack(a)) -> Int }")),
    ?assertMatch("Stack.size is (a!) -> Bool, not the signature's (Stack(a)) -> Int",
                 err("abstract type Stack(a) = Stack(List(a)) with { size : (Stack(a)) -> Int }\n"
                     "fn Stack.size(s) = true")),
    ?assertEqual("Nope is not a type declared in this module", err("fn Nope.f() = 1")).

%% report §4.2, §11.1
interface_test() ->
    Http = "export type Request = Request(method : String, path : String)\n"
           "export fn parse(s : String) -> Optional(Request) =\n"
           "    if s == \"GET /\" then Some(Request(method = \"GET\", path = \"/\")) else None\n"
           "fn private() = 1",
    {ok, _, Iface, _} = ern_typecheck:check_string(['Net', 'Http'], Http),
    ?assertMatch(#iface{namespace = ['Net', 'Http']}, Iface),
    ?assertEqual([['Net', 'Http', parse]], maps:keys(Iface#iface.values)),
    ?assertEqual([['Net', 'Http', 'Request']], maps:keys(Iface#iface.types)),
    Main = "export fn main() -> Unit with Never = match Net.Http.parse(\"GET /\") {\n"
           "    Some(Net.Http.Request(method = method, path = path)) ->"
           " Io.println(method <> \" \" <> path)\n"
           "  | None -> Io.println(\"bad request\")\n}",
    {ok, Main1} = ern_parser:parse_string(Main),
    ?assertMatch({ok, _, _, _}, ern_typecheck:check(['Main'], Main1, [Iface])),
    ?assertEqual({error, [{1, 45, "unknown name Net.Http.parse"}]},
                 ern_typecheck:check(['Main'], Main1, [])),
    Private = "fn f() = Net.Http.private()",
    {ok, P1} = ern_parser:parse_string(Private),
    ?assertMatch({error, [{1, 10, "unknown name Net.Http.private"}]},
                 ern_typecheck:check(['Main'], P1, [Iface])).

%% report §11.1
errors_are_collected_test() ->
    ?assertEqual(["unknown name a", "unknown name b"],
                 errs("fn f() = a\nfn g() = b")).

%% report plan 1.2
typed_ast_test() ->
    {ok, [#fn_decl{body = #e_binop{type = T, left = #e_var{type = LT}}}], _, _} =
        check("fn double(n : Int) = n * 2"),
    ?assertEqual({tcon, ['Int'], []}, T),
    ?assertEqual({tcon, ['Int'], []}, LT).

%%
%% The example programs
%%

%% report §4.2
modules_example_test() ->
    Dir = "../../../examples/modules/",
    {ok, Http} = file:read_file(Dir ++ "net/http.ern"),
    {ok, _, Iface, _} = ern_typecheck:check_string(['Net', 'Http'], Http),
    {ok, Main} = file:read_file(Dir ++ "main.ern"),
    {ok, Decls} = ern_parser:parse_string(Main),
    ?assertMatch({ok, _, _, _}, ern_typecheck:check(['Main'], Decls, [Iface])).

%% report Appendix B, examples/
examples_test_() ->
    Files = filelib:wildcard("../../../examples/*.ern"),
    Mvp1 = ["counter", "upgrade", "hello", "pingpong", "remote", "stack", "patterns",
            "kvparser", "ets"],
    [{F, fun() ->
              {ok, Bin} = file:read_file(F),
              Base = filename:basename(F, ".ern"),
              Ns = [list_to_atom(string:titlecase(Base))],
              Result = ern_typecheck:check_string(Ns, Bin),
              case lists:member(Base, Mvp1) of
                  true -> ?assertMatch({ok, _, _, _}, Result);
                  false ->
                      %% MVP 2 programs fail only on runtime names they assume
                      {error, Errs} = Result,
                      lists:foreach(fun({_, _, Msg}) ->
                                        ?assertMatch("unknown " ++ _, Msg)
                                    end, Errs)
              end
          end} || F <- Files].

%% report §5.4, §4.6: a local fn sees the bindings in force at its
%% declaration, so a use before the binding it sees is an error even when
%% an earlier binding of the same name exists
local_fn_shadowed_binding_test() ->
    ?assertMatch({error, [{_, _, "local function f is used before `let x`" ++ _}]},
                 check("fn m() -> Int = { let x = 1; let y = f(); let x = 2;"
                       " fn f() -> Int = x; y }\n")),
    ?assertMatch({error, [{_, _, "local function f is used before `let x`" ++ _}]},
                 check("fn m() -> Int = { let x = 1; let y = f(); fn f() -> Int = g();"
                       " let x = 2; fn g() -> Int = x; y }\n")),
    ?assertMatch({ok, _, _, _},
                 check("fn m() -> Int = { let x = 1; fn f() -> Int = x; let x = 2; f() + x }\n")),
    %% a parameter or inner binding of the same name is not a reference
    ?assertMatch({ok, _, _, _},
                 check("fn m() -> Int = { let y = f(3); let x = 2; fn f(x : Int) -> Int = x;"
                       " y + x }\n")).

%% report §5.4, §3.4: a local fn's annotation shapes its type before any
%% use, so a pure local fn may be used before its declaration in a process
%% body
local_fn_annotation_before_use_test() ->
    ?assertMatch({ok, _, _, _},
                 check("fn m() -> Int with Never = { let b = 5; let early = k();"
                       " fn k() -> Int = b + 1; early }\n")).

%% report §11.5, §4.2: a type prints as the module writes it: its own and
%% the prelude's types bare, another module's qualified, a local type
%% that shadows a prelude name qualified
type_names_in_messages_test() ->
    ?assertMatch({error, [{_, _, "the arguments do not fit f: expected (Shape) -> Int, found"
                           " (Optional(Shape)) -> a"}]},
                 check("type Shape = Dot\nfn f(s : Shape) -> Int = 1\n"
                       "fn g() -> Int = f(Some(Dot))\n")),
    ?assertMatch({error, [{_, _, "the arguments do not fit f: expected (M.Optional) -> Int,"
                           " found (Optional(Int)) -> a"}]},
                 check("type Optional = Nothing\nfn f(o : Optional) -> Int = 1\n"
                       "fn g() -> Int = f(List.head([1]))\n")),
    {ok, Http} = file:read_file("../../../examples/modules/net/http.ern"),
    {ok, _, Iface, _} = ern_typecheck:check_string(['Net', 'Http'], Http),
    {ok, Decls} = ern_parser:parse_string("fn f(r : Net.Http.Request) -> Int = 1\n"
                                          "fn g() -> Int = f(1)\n"),
    ?assertMatch({error, [{_, _, "the arguments do not fit f: expected (Net.Http.Request) -> Int,"
                           " found (Int) -> a"}]},
                 ern_typecheck:check(['Main'], Decls, [Iface])).

%% report §11.5, §3.9: a type variable prints under its annotation's name;
%% an unnamed one gets a fresh name that avoids the names in use; a use
%% of a value does not inherit the names of its declaration
variable_names_test() ->
    ?assertEqual("(Map(k=, v), k=) -> Optional(v)",
                 type_of("export fn get(m : Map(k, v), key : k) -> Optional(v) = Map.get(m, key)",
                         get)),
    ?assertEqual("(a=, a=) -> Bool",
                 type_of("export fn eq(x : a, y : a) -> Bool with m = x == y", eq)),
    ?assertEqual("() -> Map(a=, b)", type_of("export fn empty() = Map.empty", empty)),
    ?assertEqual("(b, (b) -> a with e) -> a with e",
                 type_of("export fn ap(x : b, f) = f(x)", ap)),
    ?assertEqual("((a) -> a with e, a) -> a with e",
                 type_of("export fn twice(f : (a) -> a with e, x : a) -> a with e = f(f(x))",
                         twice)).

%% report §5.7: the piped value must fit the target's first argument
pipe_type_test() ->
    ?assertEqual("(String) -> Int",
                 type_of("export fn n(s : String) = s |> String.trim |> String.size", n)),
    ?assertMatch("the arguments do not fit String.size: expected (String) -> Int, found (Int)" ++ _,
                 err("fn n() = 1 |> String.size")).

%% report §6.8: a `with Never` root is called only where the mailbox is
%% Never; a polymorphic helper is called from either
never_root_test() ->
    Root = "fn root() -> Unit with Never = Io.println(\"x\")\n",
    ?assertEqual("this call needs a process: expected Msg, found Never",
                 err("type Msg = Go\n" ++ Root ++ "fn p() -> Unit with Msg = root()")),
    ?assertEqual(ok, ok(Root ++ "fn q() -> Unit with Never = root()")),
    ?assertEqual("() -> Unit with Never", type_of(Root ++ "export fn r() = root()", r)),
    ?assertEqual(ok, ok("type Msg = Go\nfn helper() -> Unit with m = Io.println(\"x\")\n"
                        "fn p() -> Unit with Msg = helper()\n"
                        "fn q() -> Unit with Never = helper()")).
