-module(ern_typecheck_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("parser/include/ern_ast.hrl").
-include_lib("typer/include/ern_types.hrl").
-include_lib("utils/include/ern_diag.hrl").

check(Text) -> ern_typecheck:check_string(['M'], Text).

ok(Text) ->
    case check(Text) of
        {ok, _, _, _} -> ok;
        {error, Errs} -> {error, [ern_diag:short("", E) || E <- Errs]}
    end.

%% The printed type of the declaration named Name.
type_of(Text, Name) ->
    {ok, _, #iface{values = Vs}, _} = check(Text),
    Scheme = maps:get(['M', Name], Vs),
    ern_types:format_scheme(Scheme, ern_typecheck:type_state(ern_typecheck:prelude_env())).

err(Text) ->
    {error, [#diag{message = Msg} | _]} = check(Text),
    Msg.

errs(Text) ->
    {error, Errs} = check(Text),
    [Msg || #diag{message = Msg} <- Errs].

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

%% report §3.9, §6.6
container_elements_are_not_marked_not_reply_carrying_test() ->
    ?assertEqual("(Optional(a), a) -> a",
                 type_of("export fn orElse(o : Optional(a), d : a) -> a =\n"
                         "    match o { Some(x) -> x | None -> d }", orElse)),
    ?assertEqual("(a, List(#(a, b))) -> List(#(a, b))",
                 type_of("export fn keep(x : a, ys : List(#(a, b))) = ys", keep)),
    ?assertEqual("(a!, (List(a!)) -> Int) -> Unit",
                 type_of("export fn skip(x : a, f : (List(a)) -> Int) = Unit", skip)).

%% report §3.9: a foreign fn whose effect is its own is process-only; one
%% whose effect is a parameter's callback's is effect-polymorphic
foreign_effect_test() ->
    Own = "foreign fn tick(n : Int) -> Int with m = \"erlang:abs/1\"\n"
          "export fn pure() -> Int = tick(1)\n",
    {error, [#diag{message = Msg} | _]} = ern_typecheck:check_string(['M'], Own),
    ?assertEqual("tick needs a process, and pure is pure", Msg),
    Callback = "foreign fn each(xs : List(a), f : (a) -> Unit with e) -> Unit with e ="
               " \"lists:foreach/2\"\n"
               "export fn pure(xs : List(Int)) -> Unit = each(xs, fn(x) = Unit)\n"
               "export fn inProcess(xs : List(Int)) -> Unit with m ="
               " each(xs, fn(x) = Io.println(Int.toString(x)))\n",
    ?assertMatch({ok, _, _, _}, ern_typecheck:check_string(['M'], Callback)).

%% report §3.9: a type argument is a value position only where its
%% parameter occurs in a value position of the type's fields, so a variable
%% that occurs in H(e) and after `with` ranges over the mailbox types and
%% pure, and `run` holds a pure callback and one with a mailbox alike. The
%% argument of a type whose parameter is a field is a value position, and
%% the rule reaches through another type's fields and a type's own. `run`
%% was process-only, and a pure caller was refused.
effect_only_type_argument_test() ->
    H = "export type H(e) = H(f : (Int) -> Unit with e)\n"
        "export fn run(h : H(e), x : Int) -> Unit with e = h.f(x)\n",
    ?assertEqual(ok, ok(H ++ "fn usePure() -> Unit = run(H(f = fn(x) = Unit), 1)\n"
                        "fn useBox(a : Address(Int)) -> Unit with Int ="
                        " run(H(f = fn(x) = send(a, x)), 1)\n")),
    %% and prints as an effect variable does, in the module's own state
    {ok, _, #iface{values = Vs}, Env} =
        check("export type H(e) = H(f : (Int) -> Unit with e)\n"
              "export fn run(h, x : Int) = { let H(f = g) = h; g(x) }\n"),
    ?assertEqual("(H(e), Int) -> Unit with e",
                 ern_types:format_scheme(maps:get(['M', run], Vs),
                                         ern_typecheck:type_state(Env))),
    ?assertEqual(ok, ok(H ++ "type K(e) = K(h : H(e)) | L(k : K(e))\n"
                        "fn go(k : K(e)) -> Unit with e ="
                        " match k { K(h = h) -> run(h, 1) | L(k = k2) -> go(k2) }\n"
                        "fn usePure() -> Unit = go(L(k = K(h = H(f = fn(x) = Unit))))\n")),
    ?assertEqual("run needs a process, and usePure is pure",
                 err("type V(e) = V(f : (Int) -> Unit with e, v : e)\n"
                     "fn run(h : V(e), x : Int) -> Unit with e = h.f(x)\n"
                     "fn usePure() -> Unit = run(V(f = fn(x) = Unit, v = 1), 1)\n")).

%% report §3.9: a pure function stands where one with a mailbox type is
%% expected, whether it is named, declared, annotated, a parameter, a
%% field, or a call's result, and in either order beside one that sends;
%% one with a mailbox type never stands where a pure one is expected.
%% Found by the cold read (its 1.1): a named pure function was refused
%% where the same function written in place was accepted
pure_stands_for_a_mailbox_test() ->
    Types = "type Msg = Add(Int) | Up(next : (Int) -> Unit with Msg)\n"
            "type Hook = Hook(run : (Int) -> Unit)\n"
            "fn done(n : Int) -> Unit = Unit\n"
            "fn quiet(n) = Unit\n"
            "fn later() -> (Int) -> Unit = done\n"
            "fn both(f, g) = { f(1); g(2) }\n",
    Main = fun(Body) ->
               Types ++ "fn main() -> Unit with Msg = { let a = self(); " ++ Body ++ "; Unit }\n"
           end,
    ?assertEqual(ok, ok(Main("let _ = Up(next = done)"))),
    ?assertEqual(ok, ok(Main("let _ = Up(next = quiet)"))),
    ?assertEqual(ok, ok(Main("let _ = Up(next = later())"))),
    ?assertEqual(ok, ok(Main("let h = Hook(run = done); let _ = Up(next = h.run)"))),
    ?assertEqual(ok, ok(Main("both(done, fn(x) = send(a, Add(x)))"))),
    ?assertEqual(ok, ok(Main("both(fn(x) = send(a, Add(x)), done)"))),
    ?assertEqual(ok, ok(Main("let _ = spawn(Local, fn() = done(1))"))),
    ?assertEqual(ok, ok(Types ++ "fn wrap(f : (Int) -> Unit) -> Msg = Up(next = f)\n")),
    %% a field selected before its record's type is known, and called in a
    %% process; a regression test: the selection, resolved after the call,
    %% was not opened, and the pure field was refused
    ?assertEqual(ok, ok(Main("List.foreach([Hook(run = done)],"
                             " fn(h) = { send(a, Add(1)); h.run(1) })"))),
    ?assertEqual("field run: a function that runs in a process where a pure one is needed",
                 err(Main("let _ = Hook(run = fn(x) = send(a, Add(x)))"))),
    %% and a pure function still prints as pure
    ?assertEqual("(Int) -> Unit", type_of("export fn done(n : Int) -> Unit = Unit", done)).

%% report §5.9, §6.3: a clause or an alternative that can match nothing
%% the clauses before it leave is an error, in `match` and in `receive`; a
%% guarded clause covers nothing, and a bitstring pattern judged is taken
%% to match anything. The label names the clause that completes the cover.
%% Found by the cold read (its 2.13): every redundant clause was accepted
redundant_clause_test() ->
    Never = "this clause can never match",
    ?assertEqual(Never, err("fn f(x : Optional(Int)) -> Int ="
                            " match x { Some(n) -> n | None -> 0 | Some(1) -> 1 }")),
    ?assertEqual(Never, err("fn f(x : Int) -> Int = match x { n -> n | 0 -> 1 }")),
    ?assertEqual(Never, err("fn f() -> Int with Int = receive { n -> n | 5 -> 1 }")),
    ?assertEqual(Never, err("fn f(b : Bool) -> Int = match b { true -> 1 | false -> 2 | _ -> 3 }")),
    ?assertEqual("this alternative can never match",
                 err("fn f(x : Optional(Int)) -> Int ="
                     " match x { Some(_) or Some(1) -> 1 | None -> 0 }")),
    %% a guarded clause may fail, so what follows it is reached
    ?assertEqual(ok, ok("fn f(x : Int) -> Int = match x { n when n > 0 -> n | 0 -> 1 | _ -> 2 }")),
    %% a guarded clause is itself redundant when unguarded ones cover it
    ?assertEqual(Never, err("fn f(x : Int) -> Int = match x { _ -> 1 | n when n > 0 -> n }")),
    %% two bitstring clauses may differ by what their sizes decide
    ?assertEqual(ok, ok("fn f(b : Bytes) -> Int ="
                        " match b { <<x>> -> x | <<x, _>> -> x | _ -> 0 }")),
    {error, [D1 | _]} = check("fn f(x : Int) -> Int = match x { n -> n | 0 -> 1 }"),
    ?assertEqual([{{1, 34, {1, 35}}, "this pattern matches every value it would"}],
                 D1#diag.labels),
    {error, [D2 | _]} =
        check("fn f(b : Bool) -> Int = match b { true -> 1 | false -> 2 | _ -> 3 }"),
    ?assertEqual([{{1, 47, {1, 52}},
                   "with those before it, this one matches every value it would"}],
                 D2#diag.labels).

%% report §4.7, §3.10, §9.2: a foreign type's parameter written `k=` puts
%% the equality constraint on its argument wherever the type is written,
%% as Map's key has it. Feedback item 39: a table keyed by functions was
%% accepted, and the host compared the keys
foreign_type_equality_test() ->
    T = "export foreign type T(k=, v)\n"
        "foreign fn mk() -> T(k, v) = \"m:mk/0\"\n"
        "foreign fn put(t : T(k, v), key : k, value : v) -> T(k, v) = \"m:put/3\"\n",
    ?assertEqual(ok, ok(T ++ "fn f() = put(mk(), 1, 2)\n")),
    ?assertEqual("(Int) -> Int does not support equality (it contains a function or an"
                 " address), but it is compared here",
                 err(T ++ "fn f() = put(mk(), fn(x : Int) -> Int = x, 2)\n")),
    %% a parameter without `=` asks nothing
    ?assertEqual(ok, ok(T ++ "fn f() = put(mk(), 1, fn(x : Int) -> Int = x)\n")),
    %% the constraint shows in a type that names the parameter
    ?assertEqual("(a=, b) -> M.T(a=, b)",
                 type_of(T ++ "export fn g(key, value) = put(mk(), key, value)\n", g)).

%% report §4.8: `!` is negation on Bool
not_operator_test() ->
    ?assertEqual("(Bool) -> Bool", type_of("export fn flip(b) = !b", flip)),
    ?assertEqual("(Bool, Bool) -> Bool", type_of("export fn nand(a, b) = !(a && b)", nand)),
    ?assertEqual("the operand of `!`: expected Bool, found Int", err("fn f() = !3")).

%% report §4.8
operators_need_a_determined_operand_type_test() ->
    ?assertEqual("the operand type of `+` is not determined; annotate it",
                 err("fn twice(n) = n + n")),
    ?assertEqual("(Int) -> Int", type_of("export fn twice(n : Int) = n + n", twice)),
    ?assertEqual("(Float) -> Float", type_of("export fn f(x : Float) = x + x", f)),
    ?assertEqual("(Float) -> Float", type_of("export fn f(x : Float) = -x * 2.0 / 0.5", f)),
    ?assertEqual("`%` is not defined on Float", err("fn f(x : Float) = x % x")),
    ?assertEqual("`-` is not defined on String", err("fn f(x : String) = -x")),
    ?assertEqual("`+` is not defined on String", err("fn f(s : String) = s + s")),
    %% report §4.8: the operand type comes from the operands, not from where
    %% the result goes, since a user operator's result may differ from them
    ?assertEqual("the operand type of `<>` is not determined; annotate it",
                 err("fn cat(a, b) = a <> b <> \"!\"")),
    ?assertEqual("(String, String) -> String",
                 type_of("export fn cat(a : String, b) = a <> b <> \"!\"", cat)),
    ?assertEqual("`<>` is not defined on Int", err("fn f(x : Int) = x <> x")),
    ?assertEqual("(Int, Int) -> Bool", type_of("export fn lt(a : Int, b) = a < b", lt)),
    ?assertEqual("`<` is not defined on Bool", err("fn f(a : Bool, b) = a < b")).

%% report §4.8: an operator's operand type is resolved once the definition
%% is inferred, from either operand; `[]` and a lambda's use determine it as
%% well as a literal; a local fn is a definition of its own, so its
%% operands must be determined inside it, where a lambda's may come from
%% its use in the enclosing definition; and an operator's result does not
%% determine its operands. A regression test: the checker conformed before
%% it was written. It does not cover a mutually recursive group.
operator_operand_sources_test() ->
    ?assertEqual("(Int, Int) -> Int", type_of("export fn f(a, b : Int) = a + b", f)),
    ?assertEqual("(List(a)) -> List(a)", type_of("export fn g(xs) = xs <> []", g)),
    ?assertEqual("the operand type of `+` is not determined; annotate it",
                 err("fn h(n : Int) = { fn dbl(x) = x + x; dbl(n) }")),
    ?assertEqual("(Int) -> Int",
                 type_of("export fn h(n : Int) = { let dbl = fn(x) = x + x; dbl(n) }", h)),
    ?assertEqual("the operand type of `+` is not determined; annotate it",
                 err("fn h(a) = { let x = a + a; Int.abs(x) }")).

%% report §4.8, §3.10: a user type's own operator and its compare resolve
%% against the operand type; the result is the operator's, and an
%% ordering is a Bool; a type without the member has no operator
user_type_operators_test() ->
    Vec = "export type Vec = Vec(Int)\nexport fn Vec.+(Vec(a), Vec(b)) -> Vec = Vec(a + b)\n"
          "export fn Vec.*(Vec(a), Vec(b)) -> Float = Int.toFloat(a * b)\n"
          "export fn Vec.compare(Vec(a), Vec(b)) -> Ordering = Int.compare(a, b)\n",
    ?assertEqual("(M.Vec, M.Vec) -> M.Vec", type_of(Vec ++ "export fn f(a : Vec, b) = a + b", f)),
    ?assertEqual("(M.Vec, M.Vec) -> Float",
                 type_of(Vec ++ "export fn f(a : Vec, b) = (a * b) + 1.0", f)),
    ?assertEqual("(M.Vec, M.Vec) -> Bool",
                 type_of(Vec ++ "export fn f(a : Vec, b) = a < b || a >= b", f)),
    %% the operand type learned later in the definition resolves the operator
    ?assertEqual("(M.Vec, M.Vec) -> Float",
                 type_of(Vec ++ "export fn f(a, b) = { let c = a * b; let d : Vec = a; c }", f)),
    %% a member declared after its user, and one using its own operator on Int
    ?assertEqual("(M.Vec, M.Vec) -> M.Vec",
                 type_of("export fn f(a : Vec, b) = a + b\n" ++ Vec, f)),
    ?assertEqual("`-` is not defined on Vec", err(Vec ++ "fn f(a : Vec, b) = a - b")),
    ?assertEqual("`-` is not defined on Vec", err(Vec ++ "fn f(a : Vec) = -a")),
    %% report §5.1: prefix - is negate in the operand type's namespace
    ?assertEqual("(M.Vec) -> M.Vec",
                 type_of(Vec ++ "export fn Vec.negate(Vec(a)) -> Vec = Vec(-a)\n"
                         "export fn f(a : Vec) = -a", f)),
    %% report §8.5: a let is not on a cycle through an operator it does not use
    ?assertEqual(ok, ok("export type Vec = Vec(Int)\nlet scale = 2 + 1\n"
                        "export fn Vec.+(Vec(a), Vec(b)) -> Vec = Vec(a + b * scale)\n")).

%% report §4.8: a member named by an operator has the type (T, T) -> R for
%% its type T, T.compare the type (T, T) -> Ordering, and T.negate the type
%% (T) -> R, each pure; another shape is an error at the declaration, where
%% a wrong arity, a wrong parameter, and a wrong result of compare were
%% reported at a use, and a member with a mailbox effect was accepted. The
%% type's arguments may be any, the same in both parameters.
operator_member_shape_test() ->
    Vec = "export type Vec = Vec(Int)\n",
    ?assertEqual("Vec.negate must have the type (Vec) -> Vec, not (Vec, Vec) -> Vec",
                 err(Vec ++ "export fn Vec.negate(Vec(a), Vec(b)) -> Vec = Vec(-a)\n")),
    ?assertEqual("Vec.compare must have the type (Vec, Vec) -> Ordering, not (Vec, Vec) -> Int",
                 err(Vec ++ "export fn Vec.compare(Vec(a), Vec(b)) -> Int = a - b\n")),
    ?assertEqual("Vec.+ must have the type (Vec, Vec) -> Vec, not (Vec, Int) -> Vec",
                 err(Vec ++ "export fn Vec.+(Vec(a), b : Int) -> Vec = Vec(a + b)\n")),
    ?assertEqual("Vec.* must have the type (Vec, Vec) -> Int, not (Int, Vec) -> Int",
                 err(Vec ++ "export fn Vec.*(a : Int, Vec(b)) -> Int = a * b\n")),
    ?assertEqual("Vec.- must have the type (Vec, Vec) -> Vec, not (Vec, Vec) -> Vec with Never",
                 err(Vec ++ "export fn Vec.-(Vec(a), Vec(b)) -> Vec with Never = Vec(a - b)\n")),
    ?assertEqual("Vec.<> must have the type (Vec, Vec) -> Vec, not (Vec, Vec) -> Vec with m",
                 err(Vec ++ "export fn Vec.<>(Vec(a), Vec(b)) -> Vec with m ="
                     " { let _ = receive { n -> n }; Vec(a + b) }\n")),
    {error, [#diag{help = Help} | _]} =
        check(Vec ++ "export fn Vec.compare(Vec(a), Vec(b)) -> Int = a - b\n"),
    ?assertEqual("compare takes two values of its type, returns an Ordering, and is pure", Help),
    %% the type's arguments are any, one in both parameters
    Box = "export type Box(a) = Box(List(a))\n",
    ?assertEqual(ok, ok(Box ++ "export fn Box.<>(Box(a), Box(b)) = Box(a <> b)\n")),
    ?assertEqual(ok, ok(Box ++ "export fn Box.*(x : Box(Int), y : Box(Int)) -> Int = 1\n")),
    ?assertEqual("Box.<> must have the type (Box(a), Box(a)) -> Box(a),"
                 " not (Box(a), Box(b)) -> Box(a)",
                 err(Box ++ "export fn Box.<>(x : Box(a), y : Box(b)) -> Box(a) = x\n")),
    %% an inferred signature is read as it is inferred
    ?assertEqual(ok, ok(Vec ++ "export fn Vec.negate(Vec(a)) = Vec(-a)\n")).

%% report §4.8, §9.6: in the module of a built-in type, the module's own
%% operators, compare, and negate are the type's members, of the same
%% shapes. A regression test for the standard library's modules, which
%% conform; it does not cover a foreign fn member.
builtin_member_shape_test() ->
    Check = fun(Text) ->
                    case ern_typecheck:check_string(['Int'], Text) of
                        {ok, _, _, _} -> ok;
                        {error, [#diag{message = M} | _]} -> M
                    end
            end,
    ?assertEqual(ok, Check("export fn compare(a : Int, b : Int) -> Ordering = Equal\n")),
    ?assertEqual("Int.compare must have the type (Int, Int) -> Ordering, not (Int, Int) -> Int",
                 Check("export fn compare(a : Int, b : Int) -> Int = 0\n")),
    ?assertEqual("Int.negate must have the type (Int) -> Int, not (Int, Int) -> Int",
                 Check("export fn negate(a : Int, b : Int) -> Int = a\n")),
    ?assertEqual("Int.+ must have the type (Int, Int) -> Int, not (Int, Float) -> Int",
                 Check("export fn Int.+(a : Int, b : Float) -> Int = a\n")).

%% report §4.8, §3.9: an operator's member is checked when first demanded,
%% so a helper both the member and another definition use keeps its
%% polymorphism, a member and a helper may use each other, and a member
%% that fails leaves its users with their own types
operator_member_on_demand_test() ->
    Vec = "export type Vec = Vec(Int)\n",
    %% pair is polymorphic in x; Vec.+ uses it at Vec and f at String
    ?assertEqual("(M.Vec, M.Vec) -> #(String, Int)",
                 type_of(Vec ++ "export fn f(a : Vec, b) = { let _ = a + b; pair(\"s\", 2) }\n"
                         "fn pair(x, n : Int) = #(x, n + 1)\n"
                         "export fn Vec.+(Vec(a), Vec(b)) -> Vec = {"
                         " let #(v, _) = pair(Vec(a + b), 1); v }\n", f)),
    %% norm uses Vec.+, and Vec.+ uses norm
    ?assertEqual("(M.Vec) -> M.Vec",
                 type_of(Vec ++ "export fn norm(v : Vec) = v + Vec(1)\n"
                         "export fn Vec.+(Vec(a), Vec(b)) -> Vec ="
                         " if a == 0 then norm(Vec(b)) else Vec(a + b)\n", norm)),
    %% one error, in the member; its user keeps its own type
    Errs = errs(Vec ++ "export fn f(a : Vec, b) = a + b\n"
                "export fn Vec.+(Vec(a), Vec(b)) -> Vec = Vec(a <> b)\n"),
    ?assertEqual(["`<>` is not defined on Int"], Errs).


%% report §3.10
equality_test() ->
    ?assertEqual("`==` is not defined on (Int) -> Int: it contains a function or an address",
                 err("fn f(g : (Int) -> Int) = g == g")),
    ?assertEqual("Address(Int) does not support equality (it contains a function or an"
                 " address), but it is compared here",
                 err("fn same(a : Address(Int), b) = equal(a, b)\nfn equal(a, b) = a == b")),
    ?assertEqual("Address(Int) does not support equality (it contains a function or an"
                 " address), and a Map's key needs it",
                 err("fn f(a : Address(Int)) = Map.put(Map.empty, a, 1)")),
    ?assertEqual(ok, ok("fn f(a : String) = Map.put(Map.empty, a, 1)")).

%% report §3.10: a type's ordering is the `compare` in its own namespace; a
%% module-level `fn compare` is an ordinary function and gives the type no
%% ordering. A regression test: the checker conformed before it was
%% written. It does not cover a prelude type's namespace.
module_level_compare_gives_no_ordering_test() ->
    D = "type D = D(Int)\nfn compare(D(a), D(b)) -> Ordering = Int.compare(a, b)\n",
    ?assertEqual("`<` is not defined on D", err(D ++ "fn f(x : D, y : D) = x < y")),
    ?assertEqual(ok, ok(D ++ "fn f(x : D, y : D) -> Ordering = compare(x, y)")).

%% report §3.10: a Map over a key without equality is refused at its first
%% operation, and the error names the key, not a comparison; a Set's element
%% alike; a type that names such a Map, in an annotation or a field, is no
%% error alone; a variable inside a key is constrained as one that is the
%% key. A regression test, written after the fix; it does not cover a
%% user function's own Map parameter instantiated at such a key, which
%% takes the same path.
map_key_equality_test() ->
    ?assertEqual("(Int) -> Int does not support equality (it contains a function or an"
                 " address), and a Map's key needs it",
                 err("fn f() = { let m : Map((Int) -> Int, Int) = Map.empty; m }")),
    ?assertEqual("Address(Int) does not support equality (it contains a function or an"
                 " address), and a Set's element needs it",
                 err("fn f(a : Address(Int)) = Set.put(Set.empty, a)")),
    ?assertEqual(ok, ok("type Box = Box(m : Map((Int) -> Int, Int))\n"
                        "fn f(m : Map((Int) -> Int, Int)) -> Int = 1\n"
                        "fn g(b : Box) -> Box = b")),
    ?assertEqual("(Map(#(k=, Int), v)) -> Map(#(k=, Int), v)",
                 type_of("export fn f(m : Map(#(k, Int), v)) -> Map(#(k, Int), v) = m", f)),
    ?assertEqual("Address(Int) does not support equality (it contains a function or an"
                 " address), and a Map's key needs it",
                 err("fn f(m : Map(#(k, Int), Int), key : k) = m\n"
                     "fn g(m : Map(#(Address(Int), Int), Int), a : Address(Int)) = f(m, a)")).

%%
%% Effects (report §3.9, §6.1)
%%

%% report §3.9, §6.1
effects_test() ->
    ?assertEqual("() -> Unit with e", type_of("export fn main() = Io.println(\"x\")", main)),
    ?assertEqual("() -> Unit with Never",
                 type_of("export fn main() -> Unit with Never = Io.println(\"x\")", main)),
    ?assertEqual("Io.println needs a process, and main is pure",
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

%% report §6.1, §6.3, §6.8, §7.2: a missing reply is `after` in receive; a
%% receive makes its function process-only, one with only `after` too
receive_and_mailboxes_test() ->
    Counter = "type CounterMsg = Inc(Int) | Get(reply : Reply(Int))\n"
              "export fn counter(n : Int) -> Unit with CounterMsg = receive {\n"
              "    Inc(k) -> counter(n + k)\n"
              "  | Get(reply = r) -> { answer(r, n); counter(n) }\n}",
    ?assertEqual("(Int) -> Unit with M.CounterMsg", type_of(Counter, counter)),
    ?assertEqual("`receive` needs a process, and f is pure",
                 err("fn f() -> Unit = receive { after 1 -> Unit }")),
    ?assertEqual(ok, ok("fn f() -> Unit with Never = receive { after 1 -> Unit }")),
    %% an after-only receive, inferred, is process-only (a regression case,
    %% added after the checker conformed)
    ?assertEqual("(Int) -> Unit with e",
                 type_of("export fn sleep(ms : Int) = receive { after ms -> Unit }", sleep)),
    ?assertEqual("sleep needs a process, and p is pure",
                 err("fn sleep(ms : Int) = receive { after ms -> Unit }\n"
                     "fn p() -> Unit = sleep(1)")),
    ?assertEqual("a function with mailbox Never cannot receive",
                 err("fn f() -> Unit with Never = receive { Unit -> Unit }")),
    ?assertEqual("(a!) -> Unit with e",
                 type_of("export fn tick(n) = { let m = receive { k -> k }; Unit }", tick)).

%% report §6.2, §4.6
spawn_test() ->
    ?assertEqual(ok, ok("fn work() -> Unit with Never = Unit\n"
                        "fn main() -> Unit with Never = { let _ = spawn(Local, fn() = work());"
                        " Unit }")),
    %% a callback written pure is spawned as any pure function is (report §3.9)
    ?assertEqual(ok, ok("fn main() -> Unit with Never = {"
                        " let _ = spawn(Local, fn() -> Unit = Unit); Unit }")),
    ?assertEqual("the type of a is not determined (Address(a)); use it, or annotate it",
                 err("fn work() = Unit\n"
                     "fn main() -> Unit with Never = { let a = spawn(Local, fn() = work());"
                     " Unit }")).

%% report §4.5, §3.9, §11.5: a pure result annotation on an effect-polymorphic
%% function makes its callback pure, and the error names the side that is
%% pure: a process function passed where a pure one is needed; in a
%% parameter's parameter the two swap, since there the callee hands the
%% function over. A pure one passed where a process is needed is no error
%% since the cold read's 1.1. A regression test, written after the fix; it
%% does not cover a result's function, nor the shell's rendering of the
%% message.
effect_mismatch_direction_test() ->
    ?assertEqual("the argument does not fit apply: a function that runs in a process where a"
                 " pure one is needed",
                 err("fn apply(f, x) -> Int = f(x)\n"
                     "fn g(a : Address(Int)) -> Int with m ="
                     " apply(fn(y) = { send(a, y); y }, 1)")),
    ?assertEqual("the value does not have the declared type: a function that runs in a process"
                 " where a pure one is needed",
                 err("fn g() -> Int with Never = {"
                     " let k : (Int) -> Int = fn(y) = { Io.println(\"x\"); y }; k(1) }")),
    %% h hands k a process function, and k's parameter must be pure
    ?assertEqual("the argument does not fit h: a function that runs in a process where a"
                 " pure one is needed",
                 err("fn h(k : ((Int) -> Int with m) -> Int) -> Int with m ="
                     " { let _ = self(); k(fn(x) = x) }\n"
                     "fn g() -> Int with Never = h(fn(f : (Int) -> Int) -> Int = f(1))")),
    ?assertEqual(ok, ok("fn apply(f, x) -> Int = f(x)\nfn g() -> Int = apply(fn(y) = y + 1, 1)")).

%% report §5.9
guards_are_pure_test() ->
    ?assertEqual(ok, ok("fn f(n : Int) = match n { k when k > 0 -> 1 | _ -> 0 }")),
    ?assertMatch("a guard is a Bool: " ++ _,
                 err("fn f(n : Int) = match n { k when k -> 1 | _ -> 0 }")),
    ?assertEqual("Io.println needs a process, and a guard is pure",
                 err("fn f(n : Int) -> Int with Never = match n {"
                     " k when Io.println(\"x\") == Unit -> 1 | _ -> 0 }")).

%%
%% Patterns and blocks
%%

%% report §5.10
patterns_test() ->
    ?assertEqual("variable x appears twice in the pattern",
                 err("fn f(p) = match p { #(x, x) -> x }")),
    ?assertEqual("a `let` pattern must be irrefutable",
                 err("fn f(o) = { let Some(x) = o; x }")),
    ?assertEqual(ok, ok("type P = P(x : Int, y : Int)\nfn f(p) = { let P(x = a) = p; a }")),
    ?assertEqual("a parameter pattern must be irrefutable", err("fn f(Some(x)) = x")),
    ?assertEqual("(M.P) -> Int",
                 type_of("export type P = P(x : Int, y : Int)\n"
                         "export fn getX(P(x = v) : P) = v", getX)),
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

%% report §5.4, §11.5: an expression that is not a block's last statement
%% has type Unit, so an Either an error would ride on is not dropped unseen;
%% `let _ =` discards on purpose, and a statement of any Unit type passes
statement_is_unit_test() ->
    Check = "fn check(n : Int) -> Either(String, Int) =\n"
            "    if n > 0 then Right(n) else Left(\"neg\")\n",
    ?assertEqual("this statement's value is discarded: expected Unit,"
                 " found Either(String, Int)",
                 err(Check ++ "fn f() = { check(-1); 1 }")),
    {error, [#diag{help = Help} | _]} = check(Check ++ "fn f() = { check(-1); 1 }"),
    ?assertEqual("`let _ = ...` discards it on purpose", Help),
    ?assertEqual(ok, ok(Check ++ "fn f() = { let _ = check(-1); 1 }")),
    ?assertEqual(ok, ok("fn f(a : Address(Int)) -> Int with m = { send(a, 1); 2 }")),
    %% a statement whose type is still open is settled at Unit
    ?assertEqual(ok, ok("fn f() -> Int = { todo(\"later\"); 1 }")).

%% report §5.4
local_fn_forward_reference_test() ->
    %% a is generalized only after b, which it references, is checked
    ?assertEqual("the argument does not fit a: expected Int, found String",
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

%% report §5.5: `<-` over a value whose sum type nothing decides asks for an
%% annotation; its pattern is irrefutable, as `let`'s is, so a constructor
%% pattern is refused and a tuple accepted. A regression test: the checker
%% conformed before it was written. It does not cover an Either.
bind_arrow_open_sum_and_pattern_test() ->
    ?assertEqual("`<-` needs to know whether the value is an Either or an Optional; annotate it",
                 err("fn g(x) = { let a <- x; x }")),
    ?assertEqual("a `let` pattern must be irrefutable; use match",
                 err("fn f(x : Optional(Optional(Int))) -> Optional(Int) ="
                     " { let Some(y) <- x; y }")),
    ?assertEqual(ok, ok("fn f(x : Optional(#(Int, Int))) -> Optional(Int) ="
                        " { let #(a, b) <- x; Some(a + b) }")).

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
                 type_of("export type Key = Up | Down\nexport fn isDown(k) = match k"
                         " { Down -> true"
                         " | Up -> false }", isDown)),
    ?assertEqual("field names must be unique within a constructor",
                 err("type T = T(a : Int, a : Int)")).

%% report §4.2, §5.4: a module declares each top-level name once, private or
%% exported, and a block each local fn name once; two adjacent ones are the
%% parser's "one clause" error (ern_parser_tests). The top-level half is a
%% regression test, written after the checker conformed; the local half
%% was fixed with it, since two local fns of one name apart in a block were
%% accepted. It does not cover a local fn and a `let` of one name.
declared_once_test() ->
    ?assertEqual("value f is declared twice", err("fn f() = 1\nfn g() = 3\nfn f() = 2")),
    ?assertEqual("local function g is declared twice in the block",
                 err("fn h() = { fn g() = 1; let x = 1; fn g() = 2; g() + x }")),
    ?assertEqual(ok, ok("fn h() = { fn g() = 1; let x = { fn g() = 2; g() }; g() + x }")).

%% report §5.4: a local fn may not take the name of a parameter or a
%% variable in scope where it is declared, nor of a `let` of its block:
%% the enclosing fn's parameter, a `let` or a pattern's variable bound
%% before it, a `let` after it in its block, a lambda's parameter. Each was
%% accepted, the checker taking the name for the fn and the emitter for
%% the variable, and the program faulted with badfun. A local fn of an
%% enclosing block, and a top-level function, are no variables.
local_fn_takes_no_variables_name_test() ->
    Scope = "local function g has the name of a variable in scope where it is declared",
    ?assertEqual(Scope, err("fn f(g : Int) -> Int = { fn g() -> Int = 1; g() }")),
    ?assertEqual(Scope, err("fn f() -> Int = { let g = 1; fn g() -> Int = 2; g() }")),
    ?assertEqual(Scope, err("fn f(x : Int) -> Int = match x { g -> { fn g() -> Int = 2; g() } }")),
    ?assertEqual(Scope, err("fn f(p : #(Int, Int)) -> Int = {"
                            " let #(a, g) = p; fn g() -> Int = a; g() }")),
    ?assertEqual(Scope, err("fn f() -> Int ="
                            " { let h = fn(g : Int) -> Int = { fn g() -> Int = 2; g() }; h(1) }")),
    ?assertEqual(Scope, err("let k = fn(g : Int) -> Int = { fn g() -> Int = 2; g() }")),
    ?assertEqual(Scope, err("fn f(g : Int) -> Int = { fn h() -> Int = { fn g() -> Int = 1; g() };"
                            " h() }")),
    ?assertEqual("local function g has the name of a `let` of its block",
                 err("fn f() -> Int = { fn g() -> Int = 2; let g = 1; g }")),
    D = diag("fn f(g : Int) -> Int = { fn g() -> Int = 1; g() }"),
    ?assertEqual([{{1, 6, {1, 7}}, "g is bound here"}], D#diag.labels),
    ?assertEqual("rename the function or the variable", D#diag.help),
    ?assertEqual(ok, ok("fn g() -> Int = 1\nfn f() -> Int = { fn g() -> Int = 2; g() }")),
    ?assertEqual(ok, ok("fn f() -> Int ="
                        " { let x = { let g = 1; g }; fn g() -> Int = 2; g() + x }")),
    ?assertEqual(ok, ok("fn f(x : Int) -> Int = { fn g(g : Int) -> Int = g; g(x) }")).

%% report §3.9
annotations_are_rigid_test() ->
    ?assertEqual("type variable a in the annotation is used as Int", err("fn f(x : a) -> a = 1")),
    ?assertEqual("two type variables in the annotation are used as one type",
                 err("fn f(x : a, y : b) -> a = y")),
    ?assertEqual("(a) -> a", type_of("export fn id(x : a) -> a = x", id)),
    ?assertMatch("the body does not have the declared return type: " ++ _,
                 err("fn f(x : Int) -> String = x")).

%% report §3.9: a local fn's signature shares the enclosing signature's
%% variables, rigid there; a variable named only in it is the local fn's
%% own, rigid and generalized with it. The local fn's `a` was its own, so
%% `inner(1)` was accepted where the enclosing `a` is not Int.
local_fn_signature_shares_variables_test() ->
    ?assertEqual("(a) -> a",
                 type_of("export fn outer(x : a) -> a = { fn inner(y : a) -> a = y; inner(x) }",
                         outer)),
    ?assertEqual("type variable a in the annotation is used as Int",
                 err("fn outer(x : a) -> a = { fn inner(y : a) -> a = y; inner(1) }")),
    ?assertEqual("type variable a in the annotation is used as Int",
                 err("fn outer(x : a) -> Int = { fn inner(y : a) -> a = y; inner(1) }")),
    ?assertEqual("(a) -> a",
                 type_of("export fn outer(x : a) -> a ="
                         " { fn id(y : b) -> b = y; let _ = id(1); id(x) }", outer)),
    ?assertEqual("two type variables in the annotation are used as one type",
                 err("fn outer(x : a) -> a = { fn g(y : b) -> b = x; x }")),
    ?assertEqual("type variable b in the annotation is used as Int",
                 err("fn outer(x : a) -> a = { fn g(y : b) -> b = 1; x }")).

%% report §3.9: polymorphic recursion is refused, even under a full
%% signature. A regression test: the checker conformed before it was
%% written. It does not cover a mutually recursive group.
polymorphic_recursion_is_refused_test() ->
    ?assertEqual("recursive use does not match the definition: a type that would contain"
                 " itself ((Nested(List(a))) -> Int against (Nested(a)) -> Int)",
                 err("type Nested(a) = Flat(a) | Nest(Nested(List(a)))\n"
                     "fn depth(n : Nested(a)) -> Int ="
                     " match n { Flat(_) -> 0 | Nest(m) -> 1 + depth(m) }")).

%% report §3.9: a signature's type variables reach a block `let`'s annotation,
%% `=` and `<-` alike, and stay rigid there; a variable named only in the
%% block `let` is its own and flexible, each `let` its own; inside a lambda
%% the lambda's variables reach it too. A regression test, written after
%% the fix; it does not cover a local `fn`'s own signature, which starts a
%% definition of its own.
block_let_annotation_variables_test() ->
    ?assertEqual("type variable a in the annotation is used as Int",
                 err("fn f(x : a) -> Int = { let y : a = 1; y }")),
    ?assertEqual("type variable a in the annotation is used as Int",
                 err("fn f(x : Optional(a), n : Int) -> Optional(Int) ="
                     " { let y : a <- Some(n); Some(y) }")),
    ?assertEqual("(a) -> a", type_of("export fn f(x : a) -> a = { let y : a = x; y }", f)),
    ?assertEqual(ok, ok("fn f(x : Int) -> Int = { let y : a = x; y }")),
    ?assertEqual(ok, ok("fn f(x : Int) -> Int = { let y : a = x; let z : a = \"s\"; y }")),
    %% the lambda's own b, not rigid, is the one the inner `let` names
    ?assertEqual(ok, ok("fn f(x : Int) -> Int ="
                        " { let g = fn(y : b) -> b = { let z : b = y; z }; g(x) }")),
    ?assertEqual("the argument does not fit g: expected String, found Int",
                 err("fn f(x : Int) -> Int ="
                     " { let g = fn(y : b) -> b = { let z : b = \"s\"; z }; g(x) }")).

%% report §3.4
with_binds_to_the_nearest_arrow_test() ->
    ?assertEqual("(Int) -> ((Int) -> Int with Never)",
                 type_of("export fn f(a : Int) -> (Int) -> Int with Never = fn(b) = a + b", f)),
    ?assertEqual("(Int) -> (Int) -> Int with Never",
                 type_of("export fn f(a : Int) -> ((Int) -> Int) with Never = fn(b) = a + b",
                         f)).

%% report §5.9: the alternatives of a clause bind the same variables at the
%% same types, and coverage counts each alternative
or_pattern_test() ->
    Shape = "export type Shape = Circle(Int) | Square(Int) | Dot\n",
    ?assertEqual("(M.Shape) -> Int",
                 type_of(Shape ++ "export fn area(s : Shape) = match s {"
                         " Circle(n) or Square(n) -> n | Dot -> 0 }", area)),
    ?assertEqual("the alternatives of a clause bind different variables: `n` is bound by the"
                 " first alternative and not by this one",
                 err(Shape ++ "fn f(s : Shape) ="
                     " match s { Circle(n) or Dot -> n | Square(_) -> 0 }")),
    ?assertEqual("the alternatives of a clause bind different variables: `m` is bound by this"
                 " alternative and not by the first",
                 err(Shape ++ "fn f(s : Shape) ="
                     " match s { Dot or Square(m) -> 1 | Circle(_) -> 0 }")),
    [TypeErr | _] = errs("fn f(e : Either(Int, String)) = match e { Left(x) or Right(x) -> 1 }"),
    ?assertMatch({match, _}, re:run(TypeErr, "the alternatives bind `x` at one type")),
    ?assertEqual(ok, ok("fn f(e : Either(Int, Int)) = match e { Left(n) or Right(n) -> n }")),
    [Cover | _] = errs("fn f(o : Optional(Int)) = match o { Some(1) or Some(2) -> 1 }"),
    ?assertMatch({match, _}, re:run(Cover, "^match on Optional")).

%% report §4.8: an operator is declared with `fn`
let_operator_test() ->
    ?assertEqual("an operator is declared with `fn`, not `let`",
                 err("type Vec = Vec(Int)\nlet Vec.+ = fn(a : Vec, b : Vec) -> Vec = a")),
    ?assertEqual(ok, ok("type Vec = Vec(Int)\nlet Vec.zero = Vec(0)")).

%% report §8.5
let_cycle_test() ->
    ?assertEqual("the initializer of a depends on itself, through b",
                 err("let a : Int = b\nlet b : Int = a")),
    ?assertEqual("the initializer of a depends on itself, through f",
                 err("let a : Int = f()\nfn f() -> Int = a")),
    ?assertEqual("the initializer of a depends on itself", err("let a : Int = a")),
    ?assertEqual(ok, ok("let a : Int = b + 1\nlet b : Int = 1")),
    %% through an operator's member (report §4.8)
    ?assertEqual("the initializer of x depends on itself, through Vec.+, y",
                 err("export type Vec = Vec(Int)\nlet x = Vec(1) + Vec(2)\nlet y = x\n"
                     "export fn Vec.+(Vec(a), Vec(b)) -> Vec ="
                     " { let Vec(c) = y; Vec(a + b + c) }")),
    %% two independent cycles are two errors
    ?assertEqual(["the initializer of a depends on itself",
                  "the initializer of b depends on itself"],
                 errs("let a : Int = a\nlet b : Int = b")).

%% report §8.5: a binding depends on what every function it names depends
%% on, called or not, and a lambda's body is part of its initializer. A
%% regression test: the checker conformed before it was written.
let_cycle_through_a_named_function_test() ->
    ?assertEqual("the initializer of handlers depends on itself, through f",
                 err("let handlers = [f]\nfn f() -> Int = List.size(handlers)\n")),
    ?assert(lists:member("the initializer of a depends on itself", errs("let a = fn() = a\n"))),
    ?assertEqual(["the initializer of a depends on itself"],
                 errs("let a : () -> Int = fn() -> Int = a()\n")).

%% report §4.6
toplevel_let_test() ->
    ?assertEqual("Int", type_of("export let port : Int = 8080", port)),
    ?assertEqual("List(a)", type_of("export let empty = []", empty)),
    ?assertEqual("the value does not have the declared type: expected Float, found Int",
                 err("let pi : Float = 3")),
    ?assertEqual("Io.println needs a process, and a top-level `let` is pure",
                 err("let x = Io.println(\"a\")")).

%% report §3.9, §6.6: a type variable is not-reply-carrying where the body,
%% read with it taken for a reply, would break the discipline: through a
%% `let` as much as by the parameter's name, or dropped inside a user type;
%% one used exactly once stays open. A regression test: a `let` hid the
%% second use and the drop, so a reply could be answered twice or never. It
%% does not cover a variable that is only a container's element, which is
%% exempt
reply_through_bindings_test() ->
    Req = "type Req = Get(reply : Reply(Int))\nexport type Box(a) = Box(a)\n",
    ?assertEqual("(a!) -> #(a!, a!)",
                 type_of("export fn dup(x) = { let y = x; #(y, y) }", dup)),
    ?assertEqual("(a!) -> Unit", type_of("export fn drop(x) = { let y = x; Unit }", drop)),
    ?assertEqual("(M.Box(a!)) -> Unit",
                 type_of(Req ++ "export fn forget(b : Box(a)) -> Unit = Unit", forget)),
    ?assertEqual("(a) -> a", type_of("export fn keep(x) = { let y = x; y }", keep)),
    ?assertEqual("a reply-carrying value, Reply(Int), passed where the function duplicates or"
                 " discards its argument",
                 err(Req ++ "fn dup(x) = { let y = x; #(y, y) }\n"
                     "fn f(r : Reply(Int)) = {\n"
                     "    let #(a, b) = dup(r); answer(a, 1); answer(b, 2) }")).

%% report §6.6, §3.9: a declared type is reply-carrying at an instantiation
%% whose fields, its arguments substituted, have a reply-carrying type, so
%% a variable is not-reply-carrying for a dropped value of the type only
%% where its parameter reaches a field outside function types and the
%% arguments of built-in types, directly or through another declared
%% type's parameter. H(e) was taken as reply-carrying at a reply-carrying
%% e, and `drop` printed as `(H(e!)) -> Unit`; so were Lst(a) and WH(a).
reply_carrying_by_the_fields_test() ->
    Types = "export type H(e) = H(f : (Int) -> Unit with e)\n"
            "export type Box(a) = Box(a)\n"
            "export type Lst(a) = Lst(List(a))\n"
            "export type Wrap(a) = Wrap(b : Box(a))\n"
            "export type WH(e) = WH(h : H(e))\n"
            "export type Pair(a) = Pair(#(a, Int))\n",
    Printed = fun(Decl, Name) ->
                      {ok, _, #iface{values = Vs}, Env} = check(Types ++ Decl),
                      ern_types:format_scheme(maps:get(['M', Name], Vs),
                                              ern_typecheck:type_state(Env))
              end,
    ?assertEqual("(H(e)) -> Unit", Printed("export fn drop(h : H(e)) -> Unit = Unit\n", drop)),
    ?assertEqual("(WH(e)) -> Unit",
                 Printed("export fn drop(h : WH(e)) -> Unit = Unit\n", drop)),
    ?assertEqual("(Lst(a)) -> Unit",
                 Printed("export fn drop(b : Lst(a)) -> Unit = Unit\n", drop)),
    ?assertEqual("(Box(a!)) -> Unit",
                 Printed("export fn drop(b : Box(a)) -> Unit = Unit\n", drop)),
    ?assertEqual("(Wrap(a!)) -> Unit",
                 Printed("export fn drop(b : Wrap(a)) -> Unit = Unit\n", drop)),
    ?assertEqual("(Pair(a!)) -> Unit",
                 Printed("export fn drop(b : Pair(a)) -> Unit = Unit\n", drop)),
    %% an H over a mailbox of requests is no reply, and may be dropped
    Req = "type Req = Get(reply : Reply(Int))\n",
    ?assertEqual(ok, ok(Types ++ Req ++ "fn drop(h : H(e)) -> Unit = Unit\n"
                        "fn f(h : H(Req)) -> Unit = { drop(h); drop(h) }\n")),
    ?assertEqual("a reply-carrying value, Reply(Int), passed where the function duplicates or"
                 " discards its argument",
                 err(Types ++ "fn drop(b : Box(a)) -> Unit = Unit\n"
                     "fn f(r : Reply(Int)) -> Unit = drop(Box(r))\n")).

%% report §3.5, §4.8, §11.5: a field is selected where every constructor has
%% it, of one type; a type found later in the definition serves, one never
%% found is an error, and an abstract type's fields are its module's
field_selection_test() ->
    Shape = "export type Point = Point(x : Int, y : Int)\n"
            "export type Shape = Dot(at : Point) | Circle(at : Point, radius : Int)\n",
    ?assertEqual("(M.Shape) -> Int", type_of(Shape ++ "export fn f(s : Shape) = s.at.x", f)),
    ?assertEqual("(M.Point) -> Int",
                 type_of(Shape ++ "export fn g(p) = { let n = p.x; n + norm(p) }\n"
                         "fn norm(p : Point) -> Int = p.y", g)),
    ?assertEqual("Shape has no field radius in every constructor: Dot has none",
                 err(Shape ++ "fn f(s : Shape) = s.radius")),
    ?assertEqual("Point has no field z", err(Shape ++ "fn f(p : Point) = p.z")),
    ?assertEqual("#(Int, Int) has no field x", err("fn f() = #(1, 2).x")),
    ?assertEqual("the type whose field x is read is not determined; annotate it",
                 err(Shape ++ "fn f(p) = p.x")),
    ?assertMatch("the field name in every constructor" ++ _,
                 err("type T = A(name : Int) | B(name : String)\nfn f(t : T) = t.name")),
    ?assertEqual(ok, ok("export abstract type Box = Box(n : Int)\nfn f(b : Box) = b.n")).

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

%% report §5.6: `..` is allowed only on a type with one constructor. It was
%% accepted on a type of two, and the program faulted with badmatch where
%% the value was the other constructor.
update_needs_one_constructor_test() ->
    T = "type T = A(x : Int, y : Int) | B(x : Int, y : Int)\n",
    D = diag(T ++ "fn f(t : T) -> T = A(..t, x = 1)\n"),
    ?assertEqual("`..` is allowed only on a type with one constructor, and T has 2",
                 D#diag.message),
    ?assertEqual("give every field of A", D#diag.help),
    ?assertEqual(ok, ok(T ++ "fn f(t : T) -> T = A(x = 1, y = t.y)\n")),
    ?assertEqual(ok, ok("type P(a) = P(x : a, y : Int)\n"
                        "fn f(p : P(String)) -> P(String) = P(..p, y = 2)\n")).

%% report §5.2
calls_test() ->
    ?assertEqual("f takes 2 arguments, not 1",
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
    ?assertEqual("the reply-carrying value r is captured by a lambda that is not called, bound by"
                 " `let`, or passed directly to spawn",
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

%% report §6.6: a local fn may not capture a reply-carrying value, since it
%% may be called many times; a function whose inferred result is
%% reply-carrying returns the reply to its caller, who must consume it. A
%% regression test: the checker conformed before it was written. It does
%% not cover a local fn that captures a lambda that captured the reply.
reply_through_functions_test() ->
    ?assertEqual("the reply-carrying value r is captured by a local function",
                 err("fn f(r : Reply(Int)) -> Unit with Never = { fn go() = answer(r, 1); go() }")),
    Pass = "fn pass(r : Reply(Int)) = r\n",
    ?assertEqual(ok, ok(Pass ++ "fn f(r : Reply(Int)) -> Unit with Never = answer(pass(r), 1)")),
    ?assertEqual("the reply-carrying value x is never consumed",
                 err(Pass ++ "fn g(r : Reply(Int)) -> Unit with Never ="
                     " { let x = pass(r); Unit }")).

%% report §6.6, §3.9, §4.4, §4.7
warts_audit_test() ->
    Msg = "type Req = Get(reply : Reply(Int)) | Stop\n",
    %% a reply-carrying expression neither bound nor consumed: a statement
    %% has type Unit (§5.4), which carries no reply
    ?assertEqual("this statement's value is discarded: expected Unit, found Req",
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
    %% duplicate field in a pattern
    ?assertEqual("a field is matched twice",
                 err(Msg ++ "fn f(r) = match r { Get(reply = a, reply = b) -> Unit"
                     " | Stop -> Unit }")),
    %% report §8.4: the implementation is module:function/arity, the arity
    %% the parameter count
    ?assertEqual("the implementation names arity 2, and tick has 0 parameters",
                 err("foreign fn tick() -> Unit with m = \"m:tick/2\"")),
    ?assertEqual("the implementation of tick is named module:function/arity, as \"ets:new/2\"",
                 err("foreign fn tick() -> Unit with m = \"tick\"")),
    %% foreign fn with an effect is process-only
    ?assertEqual("tick needs a process, and f is pure",
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

%% report §8.4: a foreign fn's implementation is named module:function/arity,
%% and the arity is its parameter count; either mistake is a compile error.
%% A regression test: the checker conformed before it was written. It does
%% not cover a module or function missing at run time.
foreign_implementation_name_test() ->
    Named = "the implementation of tick is named module:function/arity, as \"ets:new/2\"",
    ?assertEqual(Named, err("foreign fn tick(n : Int) -> Int = \"erlang:abs\"")),
    ?assertEqual(Named, err("foreign fn tick(n : Int) -> Int = \"abs/1\"")),
    ?assertEqual(Named, err("foreign fn tick(n : Int) -> Int = \"erlang:abs/x\"")),
    ?assertEqual("the implementation names arity 2, and tick has 1 parameter",
                 err("foreign fn tick(n : Int) -> Int = \"erlang:abs/2\"")),
    ?assertEqual(ok, ok("foreign fn tick(n : Int) -> Int = \"erlang:abs/1\"")).

%% report §3.1
base_types_test() ->
    ?assertEqual("() -> #(Int, Float, Char, String, Bool)",
                 type_of("export fn f() = #(1, 1.5, 'c', \"s\", true)", f)),
    ?assertEqual("() -> Unit", type_of("export fn f() = Unit", f)).

%% report §3.6
abstract_types_as_types_test() ->
    Stack = "export abstract type Stack(a) = Stack(List(a))\n"
            "export let Stack.empty = Stack([])\n"
            "export fn Stack.push(x, Stack(xs)) = Stack(x :: xs)\n",
    ?assertEqual("(M.Stack(Int)) -> M.Stack(Int)",
                 type_of(Stack ++ "export fn f(s : Stack(Int)) = Stack.push(1, s)", f)),
    ?assertEqual("() -> M.Stack(String)",
                 type_of(Stack ++ "export fn f() = Stack.push(\"a\", Stack.empty)", f)),
    ?assertMatch("the argument does not fit Stack.push: " ++ _,
                 err(Stack ++ "fn f(s : Stack(Int)) = Stack.push(\"a\", s)")),
    %% a sum type like any other: structural equality applies
    ?assertEqual("(M.Stack(Int), M.Stack(Int)) -> Bool",
                 type_of(Stack ++ "export fn same(a : Stack(Int), b) = a == b", same)).

%% report §3.8
foreign_types_test() ->
    Table = "export foreign type Table(k, v)\n"
            "foreign fn rawNew(name : String) -> Table(k, v) with m = \"ets:new/1\"\n",
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
    lists:foreach(fun({QName, Text, _}) ->
                      ?assertMatch({ok, _}, ern_parser:parse_type(Text)),
                      Name = lists:flatten(lists:join(".", [atom_to_list(P) || P <- QName])),
                      ?assertEqual(ok, ok("export let v = " ++ Name))
                  end, ern_prelude:values()),
    %% the process primitives are process-only, the stdlib combinators are not
    ?assertEqual("send needs a process, and f is pure",
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
    Stack = "export abstract type Stack(a) = Stack(List(a))\n"
            "export let Stack.empty = Stack([])\n"
            "export fn Stack.push(x, Stack(xs)) = Stack(x :: xs)\n"
            "export fn Stack.pop(Stack(xs)) = match xs { [] -> None | x :: rest ->"
            " Some(#(x, Stack(rest))) }\n",
    ?assertEqual(ok, ok(Stack)),
    %% report §3.9: push puts its element in a List, where a reply may not stand
    ?assertEqual("(a!, M.Stack(a!)) -> M.Stack(a!)",
                 type_of(Stack ++ "export fn use(x, s) = Stack.push(x, s)", use)),
    %% an abstract type the module keeps private hides from no module
    ?assertEqual("Stack is an abstract type the module keeps private, which hides its"
                 " constructors from no module",
                 err("abstract type Stack(a) = Stack(List(a))")),
    ?assertEqual("Nope is not a type declared in this module", err("fn Nope.f() = 1")).

%% report §6.6: a lambda that captures a reply-carrying value is reply-carrying
%% itself, consumed exactly once by a call or as spawn's direct argument,
%% bindable by let, and legal nowhere else
reply_lambda_test() ->
    Msg = "type Req = Get(reply : Reply(Int)) | Stop\n"
          "fn worker(r : Reply(Int)) -> Unit with Never = answer(r, 1)\n",
    ?assertEqual(ok, ok(Msg ++ "fn f(r : Reply(Int)) -> Unit with Never = {\n"
                        "    let g = fn() = worker(r);\n    let _ = spawn(Local, g);\n    Unit }")),
    ?assertEqual(ok, ok(Msg ++ "fn f(r : Reply(Int)) -> Unit with Never = {\n"
                        "    let g = fn() = worker(r);\n    g() }")),
    ?assertEqual(ok, ok(Msg ++ "fn f(r : Reply(Int)) -> Unit with Never = (fn() = worker(r))()")),
    ?assertEqual("the reply-carrying value g is consumed twice",
                 err(Msg ++ "fn f(r : Reply(Int)) -> Unit with Never = {\n"
                     "    let g = fn() = worker(r);\n    let _ = spawn(Local, g);\n    g() }")),
    ?assertEqual("the reply-carrying value g is never consumed",
                 err(Msg ++ "fn f(r : Reply(Int)) -> Unit with Never = {\n"
                     "    let g = fn() = worker(r);\n    Unit }")),
    ?assertEqual("the reply-carrying value g is captured by a lambda that is not called, bound by"
                 " `let`, or passed directly to spawn",
                 err(Msg ++ "fn f(r : Reply(Int)) -> Unit with Never = {\n"
                     "    let g = fn() = worker(r);\n    List.foreach([1], fn(_) = g()) }")),
    ?assertEqual("the lambda g captures a reply-carrying value and may only be called or passed"
                 " directly to spawn",
                 err(Msg ++ "fn f(r : Reply(Int)) -> Unit with Never = {\n"
                     "    let g = fn() = worker(r);\n    let h = g;\n    h() }")),
    ?assertEqual("the reply-carrying value g is consumed on one path but not on another",
                 err(Msg ++ "fn f(r : Reply(Int), b : Bool) -> Unit with Never = {\n"
                     "    let g = fn() = worker(r);\n    if b then g() else Unit }")).

%% report §4.2: a module may name its own declarations by their qualified
%% names, in any order
self_qualified_test() ->
    ?assertEqual("() -> Int", type_of("export fn f() = M.g()\nfn g() = 1\n", f)),
    ?assertEqual("(M.T) -> Int", type_of("export type T = T(Int)\nexport fn f(t) = M.T.n(t)\n"
                                         "fn T.n(T(n)) = n\n", f)).

%% report §4.2, §8.5: a local binding does not hide the module's own
%% qualified name, so the initializer depends on it as on the plain name.
%% A regression test: before the fix the cycle went unseen, and `M.b` was
%% unknown whenever the groups ran `a` first. It does not cover a
%% multi-segment namespace
self_qualified_under_a_local_test() ->
    ?assertEqual("the initializer of a depends on itself, through b",
                 err("let a = { let b = 1; M.b + b }\nlet b = a\n")),
    ?assertEqual("Int", type_of("export let four = { let two = 1; M.two - two }\nlet two = 5\n",
                                four)).

%% report §4.4: every definition of the module that declares an abstract
%% type may use its constructors, a private one and a local fn among them;
%% another module may not (ern_cli_tests)
ownership_test() ->
    Stack = "export abstract type Stack(a) = Stack(List(a))\n"
            "export let Stack.empty = Stack([])\n"
            "export fn Stack.push(x, Stack(xs)) = Stack(x :: xs)\n",
    ?assertEqual(ok, ok(Stack ++ "fn peek(Stack(xs)) = xs")),
    ?assertEqual(ok, ok(Stack ++ "fn Stack.size(s) = match s { Stack(xs) -> List.size(xs) }")),
    ?assertEqual(ok, ok(Stack ++ "fn wrap(xs : List(List(Int))) = List.map(xs, Stack)")),
    ?assertEqual(ok, ok(Stack ++ "fn use() = { fn wrap(y) = Stack([y]); wrap(1) }")).

%% report §4.2, §11.1
%% report §4.8: the standard library module of a built-in type declares that
%% type's operators as a user type's module does; no other module may
builtin_type_operators_test() ->
    Float = "export foreign fn Float.+(a : Float, b : Float) -> Float = \"ern_float:add/2\"\n",
    {ok, _, Iface, _} = ern_typecheck:check_string(['Float'], Float),
    ?assertEqual([['Float', '+']], maps:keys(Iface#iface.values)),
    ?assertEqual("Float is not a type declared in this module",
                 err("export fn Float.+(a : Float, b : Float) -> Float = a")),
    ?assertMatch({error, _},
                 ern_typecheck:check_string(['Float'],
                                            "export fn Float.abs(x : Float) -> Float = x")).

%% report §4.1, §4.2: a module's interface holds its exports under its
%% namespace, and another module reaches them by the qualified name
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
    ?assertMatch({error, [#diag{span = {1, 45, _}, message = "unknown name Net.Http.parse"}]},
                 ern_typecheck:check(['Main'], Main1, [])),
    Private = "fn f() = Net.Http.private()",
    {ok, P1} = ern_parser:parse_string(Private),
    ?assertMatch({error, [#diag{span = {1, 10, _}, message = "unknown name Net.Http.private"}]},
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

%% report §4.2: an exported declaration is made of the types that cross the
%% boundary with it; a private type in its signature is refused, and an
%% abstract type, whose values cross and whose constructors do not, is not
exported_types_test() ->
    ?assertEqual("start is exported and its type names Msg, which this module keeps private",
                 err("type Msg = Ping\nexport fn start() -> Address(Msg) with m ="
                     " spawn(Local, fn() = Unit)")),
    ?assertEqual("Holder is exported and its type names Hidden, which this module keeps private",
                 err("type Hidden = Hidden(Int)\nexport type Holder = Holder(Hidden)")),
    ?assertEqual(ok, ok("export type Msg = Ping\nexport fn start() -> Address(Msg) with m ="
                        " spawn(Local, fn() = Unit)")),
    %% an abstract type is how a value crosses without its constructors, and
    %% its fields may name a private type, since they do not cross
    ?assertEqual(ok, ok("export abstract type Box = B(Int)\nexport fn Box.of(n) = B(n)")),
    ?assertEqual(ok, ok("type Hidden = Hidden(Int)\nexport abstract type Box = B(Hidden)\n"
                        "export fn Box.of(n) = B(Hidden(n))")),
    %% the effect names no value: an entry point's mailbox type may be private
    ?assertEqual(ok, ok("type Msg = Ping\nexport fn main() -> Unit with Msg ="
                        " receive { Ping -> Unit }")).

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
    Files = [F || F <- filelib:wildcard("../../../examples/*.ern"),
                  hd(filename:basename(F)) =/= $.], % editor artifacts, report §11.1
    [{F, fun() ->
              {ok, Bin} = file:read_file(F),
              Base = filename:basename(F, ".ern"),
              Ns = [list_to_atom(string:titlecase(Base))],
              ?assertMatch({ok, _, _, _}, ern_typecheck:check_string(Ns, Bin))
          end} || F <- Files].

%% report §5.4, §4.6: a local fn sees the bindings in force at its
%% declaration, so a use before the binding it sees is an error even when
%% an earlier binding of the same name exists
local_fn_shadowed_binding_test() ->
    ?assertMatch({error, [#diag{message = "local function f is used before `let x`" ++ _}]},
                 check("fn m() -> Int = { let x = 1; let y = f(); let x = 2;"
                       " fn f() -> Int = x; y }\n")),
    ?assertMatch({error, [#diag{message = "local function f is used before `let x`" ++ _}]},
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

%% report §4.2: `Prelude.X` is the prelude's X past a module's own X, as a
%% constructor, a pattern, a type, and a value; a match on the prelude's
%% type is checked against the prelude's constructors; `Prelude.` takes one
%% name, and no type takes the name
prelude_namespace_test() ->
    Shadow = "type Last = Other | Tabbed\ntype Entry = Entry(name : String)\n"
             "fn send(n : Int) -> Int = n\n",
    ?assertEqual("(IoError) -> String",
                 type_of(Shadow ++ "export fn describe(e : Prelude.IoError) = match e {"
                         " Prelude.Other(t) -> t | _ -> \"known\" }", describe)),
    ?assertEqual("(Entry) -> Int",
                 type_of(Shadow ++ "export fn size(e : Prelude.Entry) ="
                         " match e { Prelude.Entry(size = n) -> n }", size)),
    ?assertEqual("() -> IoError",
                 type_of(Shadow ++ "export fn other() = Prelude.Other(\"x\")", other)),
    ?assertEqual(ok, ok(Shadow ++ "fn f(a : Address(String)) -> Unit with m ="
                        " Prelude.send(a, \"x\")")),
    %% the module's own names are untouched
    ?assertEqual(ok, ok(Shadow ++ "fn g() -> Int = send(1)\nfn h() -> Last = Other")),
    ?assertEqual("Prelude.Io.println: Prelude takes one name the prelude declares,"
                 " as `Prelude.Close`",
                 err("fn f() -> Unit with m = Prelude.Io.println(\"x\")")),
    ?assertEqual("the prelude declares no constructor Nope", err("fn f() = Prelude.Nope")),
    ?assertEqual("Prelude names the prelude, and a type may not take it",
                 err("type Prelude = P")).

%% report §11.5, §4.2: a type prints as the module writes it: its own and
%% the prelude's types bare, another module's qualified, a local type
%% that shadows a prelude name qualified
type_names_in_messages_test() ->
    ?assertMatch({error, [#diag{message =
                                  "the argument does not fit f: expected Shape,"
                                  " found Optional(Shape)"}]},
                 check("type Shape = Dot\nfn f(s : Shape) -> Int = 1\n"
                       "fn g() -> Int = f(Some(Dot))\n")),
    ?assertMatch({error, [#diag{message =
                                  "the argument does not fit f: expected M.Optional,"
                                  " found Optional(Int)"}]},
                 check("type Optional = Nothing\nfn f(o : Optional) -> Int = 1\n"
                       "fn g() -> Int = f(List.get([1], 0))\n")),
    {ok, Http} = file:read_file("../../../examples/modules/net/http.ern"),
    {ok, _, Iface, _} = ern_typecheck:check_string(['Net', 'Http'], Http),
    {ok, Decls} = ern_parser:parse_string("fn f(r : Net.Http.Request) -> Int = 1\n"
                                          "fn g() -> Int = f(1)\n"),
    ?assertMatch({error, [#diag{message =
                                  "the argument does not fit f: expected Net.Http.Request,"
                                  " found Int"}]},
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
    ?assertMatch("the argument does not fit String.size: expected String, found Int",
                 err("fn n() = 1 |> String.size")).

%% report §6.8: a `with Never` root is called only where the mailbox is
%% Never; a polymorphic helper is called from either
never_root_test() ->
    Root = "fn root() -> Unit with Never = Io.println(\"x\")\n",
    ?assertEqual("root needs mailbox Never, and the mailbox here is Msg",
                 err("type Msg = Go\n" ++ Root ++ "fn p() -> Unit with Msg = root()")),
    ?assertEqual(ok, ok(Root ++ "fn q() -> Unit with Never = root()")),
    ?assertEqual("() -> Unit with Never", type_of(Root ++ "export fn r() = root()", r)),
    ?assertEqual(ok, ok("type Msg = Go\nfn helper() -> Unit with m = Io.println(\"x\")\n"
                        "fn p() -> Unit with Msg = helper()\n"
                        "fn q() -> Unit with Never = helper()")).

%%
%% Error placement (report §11.5)
%%

%% The first diagnostic, whole.
diag(Text) ->
    {error, [D | _]} = check(Text),
    D.

%% report §11.5: a mismatch is reported at the leaf that has the wrong
%% type, not at the enclosing expression, and the label names the
%% declaration that fixed the expectation
leaf_placement_test() ->
    %% the else branch of an `if` in a declared body: the span is the literal
    D1 = diag("fn f(b : Bool) -> Int =\n    if b then 1 else \"x\"\n"),
    ?assertEqual("the body does not have the declared return type: expected Int, found String",
                 D1#diag.message),
    ?assertEqual({2, 22, {2, 25}}, D1#diag.span),
    ?assertEqual([{{1, 19, {1, 22}}, "declared to return Int here"}], D1#diag.labels),
    %% the last statement of a block
    D2 = diag("fn f() -> Int = { let x = 1; \"x\" }\n"),
    ?assertEqual({1, 30, {1, 33}}, D2#diag.span),
    %% a match clause: the second clause against the first
    D3 = diag("fn f(n : Int) = match n { 0 -> 1 | _ -> \"x\" }\n"),
    ?assertEqual("the clauses must have one type: expected Int, found String", D3#diag.message),
    ?assertEqual({1, 41, {1, 44}}, D3#diag.span),
    ?assertEqual([{{1, 32, {1, 33}}, "the first clause has type Int"}], D3#diag.labels),
    %% the else branch against the then branch when nothing outside fixed the type
    D4 = diag("fn f(b : Bool) = if b then 1 else \"x\"\n"),
    ?assertEqual("the branches of `if` must have one type: expected Int, found String",
                 D4#diag.message),
    ?assertEqual([{{1, 28, {1, 29}}, "the then branch has type Int"}], D4#diag.labels),
    %% a call argument, at the argument, labelled with the callee's type
    D5 = diag("fn f(x : Int) = x\nfn g() = f(\"x\")\n"),
    ?assertEqual("the argument does not fit f: expected Int, found String", D5#diag.message),
    ?assertEqual({2, 12, {2, 15}}, D5#diag.span),
    ?assertEqual([{{2, 10, {2, 11}}, "f : (Int) -> Int"}], D5#diag.labels),
    %% a binary operator: the right operand, labelled with the left's type
    D6 = diag("fn f() = 1 + \"x\"\n"),
    ?assertEqual({1, 14, {1, 17}}, D6#diag.span),
    ?assertEqual([{{1, 10, {1, 11}}, "the left operand has type Int"}], D6#diag.labels),
    %% a list element against the first
    D7 = diag("fn f() = [1, \"x\"]\n"),
    ?assertEqual({1, 14, {1, 17}}, D7#diag.span),
    ?assertEqual([{{1, 11, {1, 12}}, "the first element has type Int"}], D7#diag.labels),
    %% an annotated `let` in a block: the value, labelled with the annotation
    D8 = diag("fn f() = { let x : Int = \"x\"; x }\n"),
    ?assertEqual("the value does not have the declared type: expected Int, found String",
                 D8#diag.message),
    ?assertEqual({1, 26, {1, 29}}, D8#diag.span),
    ?assertEqual([{{1, 20, {1, 23}}, "declared Int here"}], D8#diag.labels),
    %% a pattern against the value matched
    D9 = diag("fn f(n : Int) = match n { Some(x) -> x }\n"),
    ?assertEqual("the pattern does not fit the value: expected Int, found Optional(a)",
                 D9#diag.message),
    ?assertEqual([{{1, 23, {1, 24}}, "the value matched has type Int"}], D9#diag.labels).

%% report §11.5: the message shows the whole types; when they differ
%% inside, the help line names the differing part
differing_part_test() ->
    D = diag("fn f(xs : List(Int)) = xs\nfn g() = f([\"x\"])\n"),
    ?assertEqual("the argument does not fit f: expected List(Int), found List(String)",
                 D#diag.message),
    ?assertEqual("the types differ at Int and String", D#diag.help),
    ?assertEqual(undefined, (diag("fn f() = 1 + \"x\"\n"))#diag.help).

%% report §11.5, §3.4: an effect error names the callee and what is pure,
%% labels the annotation that made it pure, and says what to do
effect_placement_test() ->
    D1 = diag("fn main() -> Unit = Io.println(\"x\")\n"),
    ?assertEqual("Io.println needs a process, and main is pure", D1#diag.message),
    ?assertEqual({1, 21, {1, 36}}, D1#diag.span),
    ?assertEqual([{{1, 14, {1, 18}}, "`-> Unit` with no `with` declares main pure"}],
                 D1#diag.labels),
    ?assertEqual("give main a mailbox type with `with`", D1#diag.help),
    D2 = diag("let x = Io.println(\"a\")\n"),
    ?assertEqual([{{1, 1, {1, 24}}, "a top-level `let` is pure"}], D2#diag.labels),
    ?assertEqual("compute the value in a function with a mailbox type", D2#diag.help),
    D3 = diag("fn f(n : Int) -> Int with Never = match n {"
              " k when Io.println(\"x\") == Unit -> 1 | _ -> 0 }\n"),
    ?assertEqual([{{1, 52, {1, 75}}, "a guard is pure (report §5.9)"}], D3#diag.labels),
    ?assertEqual("compute the value before the match", D3#diag.help),
    D4 = diag("fn f() -> Unit = receive { after 1 -> Unit }\n"),
    ?assertEqual("`receive` needs a process, and f is pure", D4#diag.message),
    ?assertEqual("give f a mailbox type with `with`", D4#diag.help),
    D5 = diag("type Msg = Go\nfn root() -> Unit with Never = Io.println(\"x\")\n"
              "fn p() -> Unit with Msg = root()\n"),
    ?assertEqual([{{3, 21, {3, 24}}, "p is declared `with Msg` here"}], D5#diag.labels),
    ?assertEqual(undefined, D5#diag.help),
    %% a lambda's own annotation is the origin inside it
    D6 = diag("fn f() -> Unit with Never = { let g = fn() -> Unit = Io.println(\"x\"); g() }\n"),
    ?assertEqual("Io.println needs a process, and the lambda is pure", D6#diag.message),
    ?assertEqual("give the lambda a mailbox type with `with`", D6#diag.help).

%% report §11.5, §3.4: a regression test. After a local fn or an annotated
%% lambda, an effect error in the enclosing function names that function
%% and labels its own annotation, not the nested definition's. Not
%% covered: the other scopes that set the origin, a guard and a size
%% expression, which effect_placement_test and the bitstring tests reach.
effect_origin_is_restored_after_a_nested_definition_test() ->
    D1 = diag("fn f() -> Unit = { fn g() -> Int = 1; receive { after 1 -> Unit } }\n"),
    ?assertEqual("`receive` needs a process, and f is pure", D1#diag.message),
    ?assertEqual([{{1, 11, {1, 15}}, "`-> Unit` with no `with` declares f pure"}],
                 D1#diag.labels),
    D2 = diag("fn f() -> Unit = { let g = fn(x : Int) -> Int = x; Io.println(\"x\") }\n"),
    ?assertEqual("Io.println needs a process, and f is pure", D2#diag.message),
    ?assertEqual("give f a mailbox type with `with`", D2#diag.help).

%% report §11.5: an unannotated lambda's mailbox is its own, so an effect
%% error inside it labels no annotation, not the enclosing definition's.
%% A regression test: the label named `main is declared with Never`, or
%% `run` pure, where neither annotation had fixed the lambda's mailbox.
effect_origin_of_an_unannotated_lambda_test() ->
    Decls = "fn g() -> Unit with String = Unit\nfn h() -> Unit with Int = Unit\n",
    D1 = diag(Decls ++ "fn main() -> Unit with Never = { let k = fn() = { g(); h() }; Unit }\n"),
    ?assertEqual("h needs mailbox Int, and the mailbox here is String", D1#diag.message),
    ?assertEqual([], D1#diag.labels),
    D2 = diag(Decls ++ "fn run() -> Int = { let k = fn() = { g(); h() }; 1 }\n"),
    ?assertEqual([], D2#diag.labels).

%% report §6.6, §4.2: only the prelude's spawn consumes a capturing lambda
%% as its direct argument; a module's own function named spawn is any
%% other function. A regression test: the reply check knew spawn by its
%% unqualified name, and a module's own spawn was taken for the prelude's.
own_spawn_is_no_spawn_test() ->
    D = diag("fn spawn(a : Int, f : () -> Unit with m) -> Unit with m = Unit\n"
             "fn handle(r : Reply(Int)) -> Unit with m = {\n"
             "    let f = fn() = answer(r, 1);\n"
             "    spawn(1, f)\n}\n"),
    ?assertEqual("the lambda f captures a reply-carrying value and may only be called or"
                 " passed directly to spawn", D#diag.message).

%% report §4.8, §3.4: an operator resolved at the end of its definition,
%% once its operand type is known, calls its member, which is pure, in a
%% process body and a pure one alike, for a top-level and a local fn. It
%% was written against a member with a mailbox effect, which §4.8 now
%% refuses at its declaration (operator_member_shape_test). Not covered:
%% `negate`, which takes the same path.
deferred_operator_calls_a_pure_member_test() ->
    V = "type V = V(Int)\nfn V.+(V(a), V(b)) -> V = V(a + b)\n",
    ?assertEqual(ok, ok(V ++ "fn f(x, y) -> V with Never = { let z = x + y; let V(_) = x; z }\n")),
    ?assertEqual(ok, ok(V ++ "fn f() -> V with Never = {\n"
                        "    fn g(x, y) = { let z = x + y; let V(_) = x; z };\n"
                        "    g(V(1), V(2))\n"
                        "}\n")),
    ?assertEqual(ok, ok(V ++ "fn f(x, y) -> V = { let z = x + y; let V(_) = x; z }\n")).

%% report §3.10, §4.8: a regression test. An operator resolved at the end
%% of its definition keeps its member's equality constraint, as one
%% resolved at once does. Not covered: the no_reply restriction, which
%% the same list carries.
deferred_operator_keeps_its_members_equality_test() ->
    B = "type Box(a) = Box(a)\n"
        "fn Box.+(Box(x), Box(y)) -> Box(a) = if x == y then Box(x) else Box(y)\n",
    Msg = "(Int) -> Int does not support equality (it contains a function or an address),"
          " but it is compared here",
    ?assertEqual(Msg, err(B ++ "fn f(p : Box((Int) -> Int), q) -> Box((Int) -> Int) = p + q\n")),
    ?assertEqual(Msg, err(B ++ "fn f(p, q) -> Box((Int) -> Int) = {\n"
                          "    let z = p + q;\n"
                          "    let _ : Box((Int) -> Int) = p;\n"
                          "    z\n"
                          "}\n")).

%%
%% Bitstrings (report §5.11)
%%

%% report §5.11: a construction is Bytes; each segment's value has its
%% specifier's type; the specifiers have their defaults and cannot
%% conflict; a constant bit count is a multiple of 8
bitstring_construction_test() ->
    ?assertEqual("(Int, Bytes) -> Bytes",
                 type_of("export fn frame(len : Int, body : Bytes) -> Bytes ="
                         " <<len:size(16)-big, body:bytes>>", frame)),
    ?assertEqual("(Float, Char, Bytes) -> Bytes",
                 type_of("export fn f(x, c, b) = <<x:float, c:utf8, b:size(2)-bytes, 1:size(4),"
                         " 2:size(4)>>", f)),
    ?assertEqual("() -> Bytes", type_of("export fn f() = <<>>", f)),
    ?assertEqual("an `int` segment: expected Int, found String", err("fn f() = <<\"a\">>")),
    ?assertEqual("a `bytes` segment: expected Bytes, found Int", err("fn f() = <<1:bytes>>")),
    ?assertEqual("the size of a segment: expected Int, found Bool",
                 err("fn f() = <<1:size(true)>>")),
    ?assertEqual("the bitstring is 12 bits, not a multiple of 8",
                 err("fn f() = <<1, 2:size(4)>>")),
    ?assertEqual(ok, ok("fn f(n : Int) = <<1:size(4), 2:size(n)>>")),
    ?assertEqual("conflicting bitstring specifiers `int` and `float`",
                 err("fn f() = <<1:int-float>>")),
    ?assertEqual("conflicting bitstring specifiers `big` and `little`",
                 err("fn f() = <<1:big-little>>")),
    ?assertEqual("unit is 1 to 256 on this runtime", err("fn f() = <<1:unit(0)>>")),
    ?assertEqual("a utf segment has no size or unit", err("fn f() = <<'a':utf8-size(8)>>")),
    ?assertEqual("a float segment is 16, 32, or 64 bits", err("fn f() = <<1.0:size(8)-float>>")),
    ?assertEqual("a `bytes` segment is a whole number of bytes, not 12 bits",
                 err("fn f(b : Bytes) = <<b:size(12)-bytes-unit(1)>>")).

%% report §5.11: `signed` and `unsigned` apply to an `int` segment only;
%% `big` and `little` to an `int`, `float`, `utf16` or `utf32` segment
%% only; in a construction and in a pattern alike. The defaults the checker
%% hands the emitter are big and unsigned. A regression test, written after
%% the fix; the defaults' bytes at run time (`<<258:size(16)>>` is
%% `<<1, 2>>`, `<<x>>` over 255 binds 255) are not covered here.
bitstring_specifier_kinds_test() ->
    ?assertEqual("`signed` applies to an `int` segment only, not a `float` one",
                 err("fn f(x : Float) = <<x:float-signed>>")),
    ?assertEqual("`unsigned` applies to an `int` segment only, not a `bytes` one",
                 err("fn f(x : Bytes) = <<x:unsigned-bytes>>")),
    ?assertEqual("`signed` applies to an `int` segment only, not a `utf8` one",
                 err("fn f(c : Char) = <<c:utf8-signed>>")),
    ?assertEqual("`little` applies to an `int`, `float`, `utf16` or `utf32` segment, not a"
                 " `utf8` one", err("fn f(c : Char) = <<c:utf8-little>>")),
    ?assertEqual("`little` applies to an `int`, `float`, `utf16` or `utf32` segment, not a"
                 " `bytes` one", err("fn f(x : Bytes) = <<x:bytes-little>>")),
    ?assertEqual("`big` applies to an `int`, `float`, `utf16` or `utf32` segment, not a"
                 " `bytes` one",
                 err("fn f(b : Bytes) -> Int = match b { <<n, _:bytes-big>> -> n | _ -> 0 }")),
    ?assertEqual(ok, ok("fn f(x : Int, y : Float, c : Char) = <<x:signed-little, x:unsigned,"
                        " y:float-little, c:utf16-little, c:utf32-big, c:utf8>>")),
    ?assertEqual(ok, ok("fn f(b : Bytes) -> Int = match b {"
                        " <<n:size(16)-signed-little, _:bytes>> -> n | _ -> 0 }")),
    ?assertMatch({ok, #{kind := int, size := {const, 8}, endian := big, sign := unsigned}},
                 ern_bitspec:spec([])).

%% report §5.11: a pattern binds each segment at its type; a size sees the
%% earlier segments and is pure; a segment pattern is a variable, `_`, or
%% a literal; a sizeless rest is last; a match needs a final wildcard
bitstring_pattern_test() ->
    ?assertEqual("(Bytes) -> Optional(#(Int, Bytes, Bytes))",
                 type_of("export fn parse(b : Bytes) = match b {"
                         " <<len:size(16)-big, body:size(len)-bytes, rest:bytes>> ->"
                         " Some(#(len, body, rest)) | _ -> None }", parse)),
    ?assertEqual("(Bytes) -> Optional(#(Char, Float))",
                 type_of("export fn f(b) = match b { <<c:utf8, x:size(32)-float, _:bytes>> ->"
                         " Some(#(c, x)) | _ -> None }", f)),
    ?assertEqual("the size of a segment: expected Int, found Bytes",
                 err("fn f(b : Bytes) = match b { <<n:bytes, x:size(n)>> -> x | _ -> 0 }")),
    ?assertEqual("Io.println needs a process, and a size expression is pure",
                 err("fn f(b : Bytes) -> Int with Never = match b {"
                     " <<x:size({ Io.println(\"a\"); 8 })>> -> x | _ -> 0 }")),
    ?assertEqual("a segment pattern is a variable, `_`, or a literal",
                 err("fn f(b : Bytes) = match b { <<Some(x)>> -> x | _ -> 0 }")),
    ?assertEqual("a `bytes` segment without a size takes the rest, so it is the last segment",
                 err("fn f(b : Bytes) = match b { <<a:bytes, c:bytes>> -> a | _ -> b }")),
    ?assertEqual("the pattern is 4 bits, not a multiple of 8",
                 err("fn f(b : Bytes) = match b { <<x:size(4)>> -> x | _ -> 0 }")),
    ?assertMatch("match on Bytes is not exhaustive; missing _",
                 err("fn f(b : Bytes) = match b { <<>> -> 0 | <<_, r:bytes>> -> 1 }")),
    ?assertEqual("a `let` pattern must be irrefutable",
                 err("fn f(b : Bytes) = { let <<x>> = b; x }")).

%% report §6.3: a receive guard is a guard expression, and calls nothing;
%% a match guard is any Bool expression
receive_guard_test() ->
    Msg = "type Msg = N(Int) | Stop\n",
    ?assertEqual(ok, ok(Msg ++ "fn big(k : Int) -> Bool = k > 100\n"
                        "fn loop(limit : Int, go : Bool) -> Unit with Msg = receive {"
                        " N(k) when (k > limit || k == -1) && go && k != 7 -> loop(limit, go)"
                        " | Stop -> Unit | N(_) -> Unit }")),
    ?assertEqual(ok, ok(Msg ++ "fn big(k : Int) -> Bool = k > 100\n"
                        "fn f(m : Msg) -> Unit ="
                        " match m { N(k) when big(k) -> Unit | _ -> Unit }")),
    D = diag(Msg ++ "fn big(k : Int) -> Bool = k > 100\n"
             "fn loop() -> Unit with Msg = receive { N(k) when big(k) -> Unit | _ -> Unit }"),
    ?assertEqual("a `receive` guard combines `true`, `false`, Bool variables, and comparisons"
                 " with `!`, `&&`, and `||`, and calls nothing", D#diag.message),
    ?assertEqual("receive the message and `match` it", D#diag.help).

%% report §6.3: each form of a guard expression: `true`, `false`, a Bool
%% operand, `!` before a guard expression, and a comparison whose operands
%% are negative numeric literals and nullary constructors as well as
%% variables and literals
receive_guard_forms_test() ->
    Head = "type Msg = N(Int) | F(Float) | O(Ordering)\n"
           "fn loop(flag : Bool) -> Unit with Msg = receive { ",
    Tail = " -> Unit | _ -> Unit }",
    Accepted = ["N(_) when true", "N(_) when false", "N(_) when flag", "N(_) when !flag",
                "N(k) when !(k > 1)", "N(k) when !(!(k == 1)) && !flag || !false",
                "N(k) when k > -1", "F(y) when y < -1.5", "F(y) when -1.5 != y",
                "O(o) when o == Less"],
    [?assertEqual({G, ok}, {G, ok(Head ++ G ++ Tail)}) || G <- Accepted].

%% report §6.3: a comparison's operands are operands, so a comparison, a
%% negation, arithmetic, or a negated variable is not one; a variable bound
%% at top level is not the function's
receive_guard_refused_test() ->
    Head = "type Msg = N(Int)\nlet limit = 5\nlet ready = true\n"
           "fn loop(flag : Bool, go : Bool, m : Int) -> Unit with Msg = receive { ",
    Tail = " -> Unit | _ -> Unit }",
    Operand = "a comparison in a `receive` guard compares variables, literals, and nullary"
              " constructors",
    Refused = [{"N(_) when !flag == true", Operand},
               {"N(_) when flag == go == true", Operand},
               {"N(k) when k + 1 > 2", Operand},
               {"N(k) when k > -m", Operand},
               {"N(k) when k > limit",
                "limit is bound at top level, and a `receive` guard reads only the function's"
                " variables"},
               {"N(_) when !ready",
                "ready is bound at top level, and a `receive` guard reads only the function's"
                " variables"},
               {"N(k) when Int.compare(k, m) == Less",
                Operand}],
    [?assertEqual({G, Expected}, {G, err(Head ++ G ++ Tail)}) || {G, Expected} <- Refused],
    D = diag(Head ++ "N(k) when k > limit" ++ Tail),
    ?assertEqual("bind its value to a variable before the `receive`", D#diag.help).

%% report §6.3, §3.10: `<`, `<=`, `>`, and `>=` in a receive guard order
%% Int, Float, String, and Char only, not a user type with its own compare
receive_guard_ordering_test() ->
    ?assertEqual("a `receive` guard orders only Int, Float, String, and Char, not Vec",
                 err("export type Vec = Vec(Int)\n"
                     "export fn Vec.compare(Vec(a), Vec(b)) -> Ordering = Int.compare(a, b)\n"
                     "type M = Go(Vec)\n"
                     "fn loop() -> Unit with M = receive { Go(v) when v < Vec(0) -> Unit"
                     " | _ -> Unit }")).

%% report §5.11: a size in a pattern is a variable, a literal, or +, -, *
%% of them
bitstring_size_shape_test() ->
    ?assertEqual(ok, ok("fn f(b : Bytes, n : Int) = match b {"
                        " <<k, rest:size(k * 8 + n - 1)-bytes-unit(1)>> -> rest | _ -> b }")),
    ?assertEqual("a size in a pattern is a variable, an Int literal, or `+`, `-`, `*` of them",
                 err("fn f(b : Bytes) = match b {"
                     " <<n, rest:size(List.size([n]))-bytes>> -> rest | _ -> b }")),
    ?assertEqual("a size in a pattern is a variable, an Int literal, or `+`, `-`, `*` of them",
                 err("fn f(b : Bytes) = match b { <<n, rest:size(n / 2)-bytes>> -> rest"
                     " | _ -> b }")).

%% report §5.11: a pattern's size may name a block `let`'s variable or one a
%% lambda captures, as a parameter; a top-level `let` is no variable, and
%% one bound elsewhere in the same pattern, outside the bitstring, is not
%% in scope. A regression test: the checker conformed before it was
%% written. It does not cover a receive clause's pattern.
bitstring_size_variables_test() ->
    ?assertEqual(ok, ok("fn f(n : Int, b : Bytes) -> Int ="
                        " { let k = n; match b { <<x:size(k)>> -> x | _ -> 0 } }")),
    ?assertEqual(ok, ok("fn f(n : Int) -> (Bytes) -> Int ="
                        " fn(b) = match b { <<x:size(n)>> -> x | _ -> 0 }")),
    ?assertEqual("a size in a pattern is a variable, an Int literal, or `+`, `-`, `*` of them",
                 err("let k = 8\nfn f(b : Bytes) -> Int ="
                     " match b { <<x:size(k)>> -> x | _ -> 0 }")),
    ?assertEqual("unknown name k",
                 err("fn f(p : #(Int, Bytes)) -> Int ="
                     " match p { #(k, <<x:size(k)-bytes>>) -> k | _ -> 0 }")).

%% report §5.9, §5.11: a bitstring nested in a constructor covers nothing,
%% as one at the top does not; a wildcard at its place completes the match.
%% A regression test: the checker conformed before it was written. It does
%% not cover a bitstring inside a tuple.
nested_bitstring_coverage_test() ->
    ?assertEqual("match on Optional(Bytes) is not exhaustive; missing Some(_)",
                 err("fn f(x : Optional(Bytes)) -> Int ="
                     " match x { Some(<<n>>) -> n | None -> 0 }")),
    ?assertEqual(ok, ok("fn f(x : Optional(Bytes)) -> Int ="
                        " match x { Some(<<n>>) -> n | None -> 0 | Some(_) -> 1 }")).

%% report §5.11: a specifier's name is an ordinary identifier outside a
%% specifier list, so a value, a parameter and a pattern's variable may be
%% named `size`, `int` or `little`. A regression test: the checker
%% conformed before it was written; the parser's half is in
%% ern_parser_tests.
specifier_names_are_identifiers_test() ->
    ?assertEqual("(Int, Int) -> Bytes",
                 type_of("export fn build(size : Int, int : Int) -> Bytes ="
                         " <<size:size(int)-big>>", build)),
    ?assertEqual("(Bytes) -> Int",
                 type_of("export fn parse(b : Bytes) -> Int = match b {"
                         " <<size:size(16), little:bytes>> -> size | _ -> 0 }", parse)).

%% report §8.5, §4.2: a name bound inside a body — a pattern's variable,
%% a lambda's parameter, a block's binding — shadows a top-level one, so
%% it is no reference to it and makes no cycle. A `let` that calls such a
%% function was reported as depending on itself.
shadowed_name_is_no_reference_test() ->
    ?assertMatch({ok, _, _, _},
                 check("let one = pick([1])\n"
                       "fn pick(xs : List(Int)) -> Int ="
                       " match xs { [one] -> one | _ -> 0 }\n")),
    ?assertMatch({ok, _, _, _},
                 check("let twice = apply(fn(n) = n * 2)\n"
                       "fn apply(f : (Int) -> Int) -> Int = f(21)\n"
                       "fn other() -> Int = { let twice = 2; twice }\n")),
    %% a real cycle is still a cycle
    ?assertEqual("the initializer of a depends on itself, through b",
                 err("let a = b()\nfn b() -> Int = a\n")).
