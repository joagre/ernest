-module(ern_typecheck_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("parser/include/ern_ast.hrl").
-include_lib("checker/include/ern_types.hrl").
-include_lib("shared/include/ern_diagnostic.hrl").

check(Text) -> ern_typecheck:check_string(['M'], Text).

ok(Text) ->
    case check(Text) of
        {ok, _, _, _} -> ok;
        {error, Diagnostics} ->
            {error, [ern_diagnostic:short("", Diagnostic) || Diagnostic <- Diagnostics]}
    end.

%% The printed type of the declaration named Name.
type_of(Text, Name) ->
    {ok, _, #interface{values = Values}, _} = check(Text),
    Scheme = maps:get(['M', Name], Values),
    ern_types:format_scheme(Scheme, ern_typecheck:type_state(ern_typecheck:prelude_env())).

%% The printed type of the member Name of the type MemberOf.
member_type_of(Text, MemberOf, Name) ->
    {ok, _, #interface{values = Values}, _} = check(Text),
    Scheme = maps:get(['M', MemberOf, Name], Values),
    ern_types:format_scheme(Scheme, ern_typecheck:type_state(ern_typecheck:prelude_env())).

refusal(Text) ->
    {error, [#diagnostic{message = Message} | _]} = check(Text),
    Message.

refusal_and_help(Text) ->
    {error, [#diagnostic{message = Message, help = Help} | _]} = check(Text),
    {Message, Help}.

refusals(Text) ->
    {error, Diagnostics} = check(Text),
    [Message || #diagnostic{message = Message} <- Diagnostics].

%%
%% Inference
%%

%% report §3.9
basic_inference_test() ->
    ?assertEqual("(Int) -> Int", type_of("export fn double(n) = n * 2", double)),
    ?assertEqual("(a) -> a", type_of("export fn id(x) = x", id)),
    ?assertEqual("(a, b) -> a", type_of("export fn first(x, y) = x", first)),
    ?assertEqual("((a) -> b receiving e, a) -> b receiving e",
                 type_of("export fn apply(f, x) = f(x)", apply)),
    ?assertEqual("(Int) -> Int",
                 type_of("export fn fact(n : Int) : Int = if n == 0 then 1 else n * fact(n - 1)",
                         fact)),
    ?assertEqual("((a) -> b receiving e, a, a) -> #(b, b) receiving e",
                 type_of("export fn map2(f, x, y) = #(f(x), f(y))", map2)),
    ?assertEqual("() -> List(a)", type_of("export fn namedEmpty() = { let xs = []; xs }",
                                          namedEmpty)).

%% report §3.9, §11.5: a parameter's function type whose effect variable
%% occurs nowhere else admits a function with any mailbox type, and one
%% with none, and the variable is printed; a result's is none, and is not.
%% A regression test, written after the code: the variable was made none
%% at generalization, and an argument that receives was refused
lone_effect_variable_test() ->
    Ignore = "export fn ignore(f : () -> Unit receiving e) : Int = 5\n"
             "fn receiver() : Unit receiving Int = receive { _ -> Unit }\n",
    ?assertEqual("(() -> Unit receiving e) -> Int", type_of(Ignore, ignore)),
    ?assertEqual(ok, ok(Ignore ++ "fn g() : Int = ignore(receiver)\n"
                                  "fn h() : Int = ignore(fn() = Unit)\n")),
    ?assertEqual("() -> (a) -> #(a, a)", type_of("export fn pair() = fn(x) = #(x, x)", pair)).

%% report §3.9, §11.5
constraints_are_inferred_and_printed_test() ->
    ?assertEqual("(a=, a=) -> Bool", type_of("export fn equal(a, b) = a == b", equal)),
    ?assertEqual("(a) -> a", type_of("export fn identity(x) = x", identity)).

%% report §3.9: a foreign fn whose mailbox type is a variable of its own
%% is process-only; one whose mailbox type is a parameter's callback's is
%% effect-polymorphic
foreign_effect_test() ->
    Own = "foreign fn tick(n : Int) : Int receiving m = \"erlang:abs/1\"\n"
          "export fn plain() : Int = tick(1)\n",
    {error, [#diagnostic{message = Message} | _]} = ern_typecheck:check_string(['M'], Own),
    ?assertEqual("tick needs a mailbox, and plain receives nothing", Message),
    Callback = "foreign fn each(xs : List(a), f : (a) -> Unit receiving e) : Unit receiving e ="
               " \"lists:foreach/2\"\n"
               "export fn plain(xs : List(Int)) : Unit = each(xs, fn(x) = Unit)\n"
               "export fn inProcess(xs : List(Int)) : Unit ="
               " each(xs, fn(x) = Io.println(Int.toString(x)))\n",
    ?assertMatch({ok, _, _, _}, ern_typecheck:check_string(['M'], Callback)).

%% report Appendix E.2, §3.9: `List.mapFold` carries its step's effect: a
%% step that receives makes the call receive, and one that receives
%% nothing leaves its caller without a mailbox. A regression test, written
%% after the code
map_fold_effect_test() ->
    ?assertEqual("(List(Int)) -> #(Int, List(Int))",
                 type_of("export fn sums(list : List(Int)) =\n"
                         "    List.mapFold(list, 0, fn(sum, n) = #(sum + n, sum))\n", sums)),
    ?assertEqual("(List(Int)) -> #(Int, List(Int)) receiving Int",
                 type_of("export fn taken(list : List(Int)) =\n"
                         "    List.mapFold(list, 0,\n"
                         "                 fn(sum, n) = receive { m -> #(sum + m, n * m) })\n",
                         taken)).

%% report §3.9: a type argument is a value position only where its
%% parameter occurs in a value position of the type's fields, so a variable
%% that occurs in H(e) and after `receiving` ranges over the mailbox types
%% and none, and `run` holds a callback that receives nothing and one that
%% receives alike. The argument of a type whose parameter is a field is a
%% value position, and the rule reaches through another type's fields and a
%% type's own. `run` was process-only, and a caller that receives nothing
%% was refused.
effect_only_type_argument_test() ->
    Source = "export type H(e) = H(f : (Int) -> Unit receiving e)\n"
             "export fn run(h : H(e), x : Int) : Unit receiving e = h.f(x)\n",
    ?assertEqual(ok, ok(Source ++ "fn usePlain() : Unit = run(H(f = fn(x) = Unit), 1)\n"
                        "fn useBox(a : Address(Int)) : Unit receiving Int ="
                        " run(H(f = fn(x) = receive { n -> send(a, x + n) }), 1)\n")),
    %% and prints as an effect variable does, in the module's own state
    {ok, _, #interface{values = Values}, Env} =
        check("export type H(e) = H(f : (Int) -> Unit receiving e)\n"
              "export fn run(h, x : Int) = { let H(f = g) = h; g(x) }\n"),
    ?assertEqual("(H(e), Int) -> Unit receiving e",
                 ern_types:format_scheme(maps:get(['M', run], Values),
                                         ern_typecheck:type_state(Env))),
    ?assertEqual(ok, ok(Source ++ "type K(e) = K(h : H(e)) | L(k : K(e))\n"
                        "fn go(k : K(e)) : Unit receiving e ="
                        " match k { K(h = h) -> run(h, 1) | L(k = k2) -> go(k2) }\n"
                        "fn usePlain() : Unit = go(L(k = K(h = H(f = fn(x) = Unit))))\n")),
    ?assertEqual("run needs a mailbox, and usePlain receives nothing",
                 refusal("type V(e) = V(f : (Int) -> Unit receiving e, v : e)\n"
                         "fn run(h : V(e), x : Int) : Unit receiving e = h.f(x)\n"
                         "fn usePlain() : Unit = run(V(f = fn(x) = Unit, v = 1), 1)\n")).

%% report §3.9: a type argument whose parameter occurs in no field of its
%% type is a value position, as `m` of `Peer.Service(m)`: a variable that
%% stands there and after `receiving` ranges over types alone, so a call
%% of a function with it is never at none, and it prints as a value
%% variable. A caller written `: T` lets the variable stand where its
%% body neither waits nor has the variable's type (report §4.5), as it
%% lets `self`'s, and is refused where the callback it gives waits. A
%% regression test of the principles review's K7 (2026-10-09): the report
%% left such a parameter in no position, and the checker took it for an
%% effect position, accepting usePlain and printing P(e); usePlain is
%% accepted again since 2026-10-24, at a type and not at none
phantom_type_argument_test() ->
    Source = "type P(e) = P(n : Int)\n"
             "fn run(p : P(e), f : (Int) -> Unit receiving e) : Unit receiving e = f(p.n)\n",
    ?assertEqual(ok, ok(Source ++ "fn usePlain() : Unit = run(P(n = 1), fn(x) = Unit)\n")),
    ?assertEqual("run needs a mailbox, and useWait receives nothing",
                 refusal(Source ++ "fn useWait() : Unit ="
                                   " run(P(n = 1), fn(x) = receive { n -> Unit })\n")),
    ?assertEqual(ok, ok(Source ++ "fn useBox(a : Address(Int)) : Unit receiving Int ="
                        " run(P(n = 1), fn(x) = send(a, x))\n")),
    ?assertEqual("the body does not have the declared result type: expected Int, found P(a)",
                 refusal("type P(e) = P(n : Int)\n"
                         "fn make() : P(e) = P(n = 1)\n"
                         "fn f() : Int = make()\n")).

%% report §5.4, §0 principle 3: `let _ = e` discards a value whatever `e`
%% is, a call's that acts on nothing among them, since the `_` shows it
%% unused, and such a call may still fault; an expression statement not of type Unit is refused. A
%% test of the full review's P6 (2026-10-04), which found the toolchain
%% already accepting it and the report silent
discard_whatever_test() ->
    ?assertEqual(ok, ok("fn checked(n : Int) : Int = if n < 0 then fault(\"negative\") else n\n"
                        "fn f(n : Int) : Unit receiving m = {\n"
                        "    let _ = 5;\n    let _ = checked(n);\n    let _ = self();\n"
                        "    Unit\n}\n")),
    ?assertEqual("this statement's value is discarded: expected Unit, found Int",
                 refusal("fn f() : Unit = {\n    5;\n    Unit\n}\n")).

%% report §3.9, §6.9, §9.5: `restarting`'s mailbox type is its function's,
%% none for a function that receives nothing, which restarts in any process
%% and is called from a function that receives nothing; one that receives
%% makes its caller receive. A regression test, 2026-10-16, written after
%% the code: it was process-only, a restart emptying the mailbox, until the
%% mark on every action went (§6.9 restarts the process it runs in)
restarting_takes_the_function_s_mailbox_test() ->
    Limit = "RestartLimit(restarts = 1, within = 1000)",
    ?assertEqual(ok, ok("fn tryIt(n : Int) : Int = {\n"
                        "    let run = restarting(" ++ Limit ++ ", fn() = Unit);\n"
                        "    run();\n    n\n}\n")),
    ?assertEqual(ok, ok("fn tryIt() : Unit = restarting(" ++ Limit ++ ", fn() = Unit)()\n")),
    ?assertEqual("the callee needs a mailbox, and tryIt receives nothing",
                 refusal("fn tryIt() : Unit = restarting(" ++ Limit ++ ","
                         " fn() = receive { after 1 -> Unit })()\n")),
    ?assertEqual(ok, ok("fn serve() : Unit =\n"
                        "    restarting(" ++ Limit ++ ", fn() = Unit)()\n"
                        "fn start() : Unit = {\n"
                        "    let _ = spawn(restarting(" ++ Limit ++ ", fn() = Unit));\n"
                        "    Unit\n}\n")).

%% report §3.9: a function that receives nothing stands where one with a
%% mailbox type is expected, whether it is named, declared, annotated, a
%% parameter, a field, or a call's result, and in either order beside one
%% that receives; one that receives never stands where one that receives
%% nothing is expected. Found by the cold read (its 1.1): a named function
%% that received nothing was refused where the same function written in
%% place was accepted
receiving_nothing_stands_for_a_mailbox_test() ->
    Types = "type Msg = Add(Int) | Up(next : (Int) -> Unit receiving Msg)\n"
            "type Hook = Hook(run : (Int) -> Unit)\n"
            "fn done(n : Int) : Unit = Unit\n"
            "fn quiet(n) = Unit\n"
            "fn later() : (Int) -> Unit = done\n"
            "fn both(f, g) = { f(1); g(2) }\n",
    Main = fun(Body) ->
               Types ++ "fn main() : Unit receiving Msg = { let a = self(); " ++ Body
                   ++ "; Unit }\n"
           end,
    ?assertEqual(ok, ok(Main("let _ = Up(next = done)"))),
    ?assertEqual(ok, ok(Main("let _ = Up(next = quiet)"))),
    ?assertEqual(ok, ok(Main("let _ = Up(next = later())"))),
    ?assertEqual(ok, ok(Main("let h = Hook(run = done); let _ = Up(next = h.run)"))),
    ?assertEqual(ok, ok(Main("both(done, fn(x) = receive { Add(n) -> send(a, Add(x + n)) })"))),
    ?assertEqual(ok, ok(Main("both(fn(x) = receive { Add(n) -> send(a, Add(x + n)) }, done)"))),
    ?assertEqual(ok, ok(Main("let _ = spawn(fn() = done(1))"))),
    ?assertEqual(ok, ok(Types ++ "fn wrap(f : (Int) -> Unit) : Msg = Up(next = f)\n")),
    %% a field selected before its record's type is known, and called in a
    %% process; a regression test: the selection, resolved after the call,
    %% was not opened, and the field that receives nothing was refused
    ?assertEqual(ok, ok(Main("List.forEach([Hook(run = done)],"
                             " fn(h) = { let _ = receive { n -> n }; h.run(1) })"))),
    ?assertEqual("field run: a function that receives where one that receives nothing is"
                 " needed",
                 refusal(Main("let _ = Hook(run = fn(x) = receive { after 1 -> Unit })"))),
    %% and a function that receives nothing prints without a mailbox type
    ?assertEqual("(Int) -> Unit", type_of("export fn done(n : Int) : Unit = Unit", done)).

%% report §5.9, §6.3: a clause or an alternative that can match nothing
%% the clauses before it leave is an error, in `match` and in `receive`; a
%% guarded clause covers nothing, and a bitstring pattern judged is taken
%% to match anything. The label names the clause that completes the cover.
%% Found by the cold read (its 2.13): every redundant clause was accepted
redundant_clause_test() ->
    Never = "this clause can never match",
    ?assertEqual(Never, refusal("fn f(x : Optional(Int)) : Int ="
                                " match x { Some(n) -> n | None -> 0 | Some(1) -> 1 }")),
    ?assertEqual(Never, refusal("fn f(x : Int) : Int = match x { n -> n | 0 -> 1 }")),
    ?assertEqual(Never, refusal("fn f() : Int receiving Int = receive { n -> n | 5 -> 1 }")),
    ?assertEqual(Never,
                 refusal("fn f(b : Bool) : Int = match b { true -> 1 | false -> 2 | _ -> 3 }")),
    ?assertEqual("this alternative can never match",
                 refusal("fn f(x : Optional(Int)) : Int ="
                         " match x { Some(_) or Some(1) -> 1 | None -> 0 }")),
    %% a guarded clause may fail, so what follows it is reached
    ?assertEqual(ok, ok("fn f(x : Int) : Int = match x { n when n > 0 -> n | 0 -> 1 | _ -> 2 }")),
    %% a guarded clause is itself redundant when unguarded ones cover it
    ?assertEqual(Never, refusal("fn f(x : Int) : Int = match x { _ -> 1 | n when n > 0 -> n }")),
    %% two bitstring clauses may differ by what their sizes decide
    ?assertEqual(ok, ok("fn f(b : Bytes) : Int ="
                        " match b { <<x>> -> x | <<x, _>> -> x | _ -> 0 }")),
    {error, [CoveredByOne | _]} = check("fn f(x : Int) : Int = match x { n -> n | 0 -> 1 }"),
    ?assertEqual([{{1, 33, {1, 34}}, "this pattern matches every value it would"}],
                 CoveredByOne#diagnostic.labels),
    {error, [CoveredByAll | _]} =
        check("fn f(b : Bool) : Int = match b { true -> 1 | false -> 2 | _ -> 3 }"),
    ?assertEqual([{{1, 46, {1, 51}},
                   "with those before it, this one matches every value it would"}],
                 CoveredByAll#diagnostic.labels).

%% report §4.7, §3.10, §9.2: a foreign type's parameter written `k=` puts
%% the equality constraint on its argument wherever the type is written,
%% as Map's key has it. A regression test: a table keyed by functions was
%% accepted, and the host compared the keys
foreign_type_equality_test() ->
    Source = "export foreign type T(k=, v)\n"
             "foreign fn mk() : T(k, v) = \"m:mk/0\"\n"
             "foreign fn put(t : T(k, v), key : k, value : v) : T(k, v) = \"m:put/3\"\n",
    ?assertEqual(ok, ok(Source ++ "fn f() = put(mk(), 1, 2)\n")),
    %% reported at the first place that needs it, `put`'s second argument,
    %% put's type in the label showing the key's restriction (§11.5)
    ?assertEqual("(Int) -> Int does not support equality (it contains a function, an address"
                 " or a reply), which put requires of its second argument",
                 refusal(Source ++ "fn f() = put(mk(), fn(x : Int) : Int = x, 2)\n")),
    %% a parameter without `=` asks nothing
    ?assertEqual(ok, ok(Source ++ "fn f() = put(mk(), 1, fn(x : Int) : Int = x)\n")),
    %% the constraint shows in a type that names the parameter (report §4.7)
    ?assertEqual("(a=, b) -> M.T(a=, b)",
                 type_of(Source ++ "export fn g(key, value) = put(mk(), key, value)\n", g)).

%% report §4.8: `!` is negation on Bool
not_operator_test() ->
    ?assertEqual("(Bool) -> Bool", type_of("export fn flip(b) = !b", flip)),
    ?assertEqual("(Bool, Bool) -> Bool", type_of("export fn nand(a, b) = !(a && b)", nand)),
    ?assertEqual("the operand of `!`: expected Bool, found Int", refusal("fn f() = !3")).

%% report §4.8
operators_need_a_determined_operand_type_test() ->
    ?assertEqual("the operand type of `+` is not determined; annotate it",
                 refusal("fn twice(n) = n + n")),
    ?assertEqual("(Int) -> Int", type_of("export fn twice(n : Int) = n + n", twice)),
    ?assertEqual("(Float) -> Float", type_of("export fn f(x : Float) = x + x", f)),
    ?assertEqual("(Float) -> Float", type_of("export fn f(x : Float) = -x * 2.0 / 0.5", f)),
    ?assertEqual("`%` is not defined on Float", refusal("fn f(x : Float) = x % x")),
    ?assertEqual("`-` is not defined on String", refusal("fn f(x : String) = -x")),
    ?assertEqual("`+` is not defined on String", refusal("fn f(s : String) = s + s")),
    %% report §4.8: the operand type comes from the operands, not from where
    %% the result goes, since a user operator's result may differ from them
    ?assertEqual("the operand type of `<>` is not determined; annotate it",
                 refusal("fn cat(a, b) = a <> b <> \"!\"")),
    ?assertEqual("(String, String) -> String",
                 type_of("export fn cat(a : String, b) = a <> b <> \"!\"", cat)),
    ?assertEqual("`<>` is not defined on Int", refusal("fn f(x : Int) = x <> x")),
    ?assertEqual("(Int, Int) -> Bool", type_of("export fn lt(a : Int, b) = a < b", lt)),
    ?assertEqual("`<` is not defined on Bool", refusal("fn f(a : Bool, b) = a < b")).

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
                 refusal("fn h(n : Int) = { fn dbl(x) = x + x; dbl(n) }")),
    %% report §4.6: a `let` of a lambda is generalized as a local `fn` is,
    %% so its operator's operand type is fixed in the lambda or annotated
    ?assertEqual("the operand type of `+` is not determined; annotate it",
                 refusal("fn h(n : Int) = { let dbl = fn(x) = x + x; dbl(n) }")),
    ?assertEqual("(Int) -> Int",
                 type_of("export fn h(n : Int) = { let dbl = fn(x : Int) = x + x; dbl(n) }", h)),
    ?assertEqual("the operand type of `+` is not determined; annotate it",
                 refusal("fn h(a) = { let x = a + a; Int.abs(x) }")).

%% report §4.6, §3.9: a `let` of a lambda to a name is generalized, as a
%% local `fn` is, so it serves two types; a variable its annotation names
%% first is rigid. A regression test, written with the rule: the binding
%% was monomorphic
lambda_let_generalized_test() ->
    ?assertEqual(ok, ok("fn f() = { let id = fn(x) = x; #(id(1), id(\"a\")) }")),
    ?assertEqual(ok, ok("fn f() = { let id = fn(x : a) : a = x; #(id(1), id(\"a\")) }")),
    ?assertEqual("both operands of `+` must have the same type: expected a, found Int",
                 refusal("fn f() = { let g = fn(x : a) : a = x + 1; g(2) }")),
    ?assertEqual(ok, ok("export let id = fn(x : a) : a = x")),
    %% any other block binding stays monomorphic
    ?assertMatch("the argument does not fit f" ++ _,
                 refusal("fn g() = { let f = List.reverse; #(f([1]), f([\"a\"])) }")).

%% report §4.8, §3.10: a user type's own operator and its compare resolve
%% against the operand type; the result is the operator's, and an
%% ordering is a Bool; a type without the member has no operator
user_type_operators_test() ->
    Vec = "export type Vec = Vec(Int)\nexport fn Vec.+(Vec(a), Vec(b)) : Vec = Vec(a + b)\n"
          "export fn Vec.*(Vec(a), Vec(b)) : Float = Int.toFloat(a * b)\n"
          "export fn Vec.compare(Vec(a), Vec(b)) : Ordering = Int.compare(a, b)\n",
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
    ?assertEqual("`-` is not defined on Vec", refusal(Vec ++ "fn f(a : Vec, b) = a - b")),
    ?assertEqual("`-` is not defined on Vec", refusal(Vec ++ "fn f(a : Vec) = -a")),
    %% report §5.1: prefix - is negate in the operand type's namespace
    ?assertEqual("(M.Vec) -> M.Vec",
                 type_of(Vec ++ "export fn Vec.negate(Vec(a)) : Vec = Vec(-a)\n"
                         "export fn f(a : Vec) = -a", f)),
    %% report §8.5: a let is not on a cycle through an operator it does not use
    ?assertEqual(ok, ok("export type Vec = Vec(Int)\nlet scale = 2 + 1\n"
                        "export fn Vec.+(Vec(a), Vec(b)) : Vec = Vec(a + b * scale)\n")).

%% report §4.8: a member named by an operator has the type (T, T) -> R for
%% its type T, T.compare the type (T, T) -> Ordering, and T.negate the type
%% (T) -> R, each receiving nothing; another shape is an error at the
%% declaration, where a wrong arity, a wrong parameter, and a wrong result
%% of compare were reported at a use, and a member with a mailbox type was
%% accepted. The
%% type's arguments may be any, the same in both parameters.
operator_member_shape_test() ->
    Vec = "export type Vec = Vec(Int)\n",
    ?assertEqual("Vec.negate must have the type (Vec) -> Vec, not (Vec, Vec) -> Vec",
                 refusal(Vec ++ "export fn Vec.negate(Vec(a), Vec(b)) : Vec = Vec(-a)\n")),
    ?assertEqual("Vec.compare must have the type (Vec, Vec) -> Ordering, not (Vec, Vec) -> Int",
                 refusal(Vec ++ "export fn Vec.compare(Vec(a), Vec(b)) : Int = a - b\n")),
    ?assertEqual("Vec.+ must have the type (Vec, Vec) -> Vec, not (Vec, Int) -> Vec",
                 refusal(Vec ++ "export fn Vec.+(Vec(a), b : Int) : Vec = Vec(a + b)\n")),
    ?assertEqual("Vec.* must have the type (Vec, Vec) -> Int, not (Int, Vec) -> Int",
                 refusal(Vec ++ "export fn Vec.*(a : Int, Vec(b)) : Int = a * b\n")),
    ?assertEqual("Vec.- must have the type (Vec, Vec) -> Vec,"
                 " not (Vec, Vec) -> Vec receiving Never",
                 refusal(Vec ++ "export fn Vec.-(Vec(a), Vec(b)) : Vec receiving Never ="
                         " Vec(a - b)\n")),
    ?assertEqual("Vec.<> must have the type (Vec, Vec) -> Vec, not (Vec, Vec) -> Vec receiving m+",
                 refusal(Vec ++ "export fn Vec.<>(Vec(a), Vec(b)) : Vec receiving m ="
                         " { receive { after 1 -> Unit }; Vec(a + b) }\n")),
    %% a member may send and print, as a guard may (§4.8, §5.9)
    ?assertEqual(ok, ok("export type Note = Note(Int)\n"
                        "export fn Note.+(Note(a), Note(b)) : Note ="
                        " { Io.println(\"added\"); Note(a + b) }\n")),
    {error, [#diagnostic{help = Help} | _]} =
        check(Vec ++ "export fn Vec.compare(Vec(a), Vec(b)) : Int = a - b\n"),
    ?assertEqual("compare takes two values of its type, returns an Ordering, and receives nothing",
                 Help),
    %% the type's arguments are any, one in both parameters
    Box = "export type Box(a) = Box(List(a))\n",
    ?assertEqual(ok, ok(Box ++ "export fn Box.<>(Box(a), Box(b)) = Box(a <> b)\n")),
    ?assertEqual(ok, ok(Box ++ "export fn Box.*(x : Box(Int), y : Box(Int)) : Int = 1\n")),
    ?assertEqual("Box.<> must have the type (Box(a), Box(a)) -> Box(a),"
                 " not (Box(a), Box(b)) -> Box(a)",
                 refusal(Box ++ "export fn Box.<>(x : Box(a), y : Box(b)) : Box(a) = x\n")),
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
                    {error, [#diagnostic{message = Message} | _]} -> Message
                end
            end,
    ?assertEqual(ok, Check("export fn compare(a : Int, b : Int) : Ordering = Equal\n")),
    ?assertEqual("Int.compare must have the type (Int, Int) -> Ordering, not (Int, Int) -> Int",
                 Check("export fn compare(a : Int, b : Int) : Int = 0\n")),
    ?assertEqual("Int.negate must have the type (Int) -> Int, not (Int, Int) -> Int",
                 Check("export fn negate(a : Int, b : Int) : Int = a\n")),
    ?assertEqual("Int.+ must have the type (Int, Int) -> Int, not (Int, Float) -> Int",
                 Check("export fn Int.+(a : Int, b : Float) : Int = a\n")).

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
                         "export fn Vec.+(Vec(a), Vec(b)) : Vec = {"
                         " let #(v, _) = pair(Vec(a + b), 1); v }\n", f)),
    %% norm uses Vec.+, and Vec.+ uses norm
    ?assertEqual("(M.Vec) -> M.Vec",
                 type_of(Vec ++ "export fn norm(v : Vec) = v + Vec(1)\n"
                         "export fn Vec.+(Vec(a), Vec(b)) : Vec ="
                         " if a == 0 then norm(Vec(b)) else Vec(a + b)\n", norm)),
    %% one error, in the member; its user keeps its own type
    Messages = refusals(Vec ++ "export fn f(a : Vec, b) = a + b\n"
                        "export fn Vec.+(Vec(a), Vec(b)) : Vec = Vec(a <> b)\n"),
    ?assertEqual(["`<>` is not defined on Int"], Messages).


%% report §4.2, §11.5: an error at a use of a name the module's own
%% declaration hides from the prelude labels that use with the prelude's
%% qualified name; an error elsewhere has no such label
hidden_prelude_name_test() ->
    Text = "type Outcome = Unknown(Int) | Known\n"
           "fn reason() : Reason = Unknown\n",
    {error, [#diagnostic{labels = Labels}]} = ern_typecheck:check_string(['M'], Text),
    ?assertEqual(["`Unknown` here is this module's constructor, and the prelude's is"
                  " `Prelude.Unknown`"],
                 [Label || {_, Label} <- Labels, string:find(Label, "Prelude.") =/= nomatch]),
    {error, [#diagnostic{labels = Others}]} =
        ern_typecheck:check_string(['M'], "type Outcome = Unknown(Int)\nfn f() : Int = \"x\"\n"),
    ?assertEqual([], [Label || {_, Label} <- Others, string:find(Label, "Prelude.") =/= nomatch]).

%%
%% What crosses to another node (report §3.11)
%%

%% A module checked with the standard library in scope, Peer among it
%% (Appendix E.27).
typed_peer(Text) ->
    {ok, Typed, _, _} = with_peer(Text),
    {ok, Typed}.

%% The calls in a typed node, every one, outermost first.
calls(#e_call{args = Args} = Call) ->
    [Call | calls(Args)];
calls(Node) when is_tuple(Node) ->
    calls(tl(tuple_to_list(Node)));
calls(Nodes) when is_list(Nodes) ->
    lists:append([calls(Node) || Node <- Nodes]);
calls(_) ->
    [].

with_peer(Text) ->
    {ok, Declarations} = ern_parser:parse_string(Text),
    ern_typecheck:check(['M'], Declarations, []).

peer_ok(Text) ->
    case with_peer(Text) of
        {ok, _, _, _} -> ok;
        {error, [#diagnostic{message = Message} | _]} -> {error, Message}
    end.

peer_refusal(Text) ->
    {error, [#diagnostic{message = Message} | _]} = with_peer(Text),
    Message.

%% A function body that spawns Function on the peer `p` and drops what
%% the spawn answers, after the given statements.
spawning(Statements, Function) ->
    "    " ++ Statements ++ "let _ = Peer.spawn(\"p\", " ++ Function ++ ", 5000);\n"
    "    Unit\n"
    "}\n".

%% report §3.11, §3.8, Appendix E.18, E.23: a type is bound to its node
%% where it holds a function, a foreign type, a resource, or an address or
%% a reply whose message type is bound; the prelude's own types, which
%% the checker keeps as foreign ones, cross, and so do a declared type's
%% values, an address and a reply of an unbound type, and a Process
bound_type_test() ->
    Env = ern_typecheck:prelude_env(),
    Binds = fun(Type) -> ern_bound:binds(Type, Env) end,
    Int = {tcon, ['Int'], []},
    Function = {tfn, [Int], none, Int},
    ?assertEqual(false, Binds(Int)),
    ?assertEqual(false, Binds({tcon, ['List'], [{tcon, ['String'], []}]})),
    ?assertEqual(false, Binds({tcon, ['Address'], [Int]})),
    ?assertEqual(false, Binds({tcon, ['Reply'], [Int]})),
    ?assertEqual(false, Binds({tcon, ['Process'], []})),
    ?assertEqual(false, Binds({tcon, ['Never'], []})),
    ?assertEqual(false, Binds({tcon, ['Optional'], [Int]})),
    ?assertEqual(false, Binds({tcon, ['Down'], []})),
    ?assertEqual("a function", Binds(Function)),
    ?assertEqual("a function", Binds({tcon, ['Optional'], [Function]})),
    ?assertEqual("a function", Binds({ttuple, [Int, Function]})),
    ?assertEqual("a value of the foreign type Foreign.Term",
                 Binds({tcon, ['Map'], [Int, {tcon, ['Foreign', 'Term'], []}]})),
    ?assertEqual("the address of a socket",
                 Binds({tcon, ['Address'], [{tcon, ['Tcp', 'SocketMsg'], []}]})),
    ?assertEqual("the address of a listener",
                 Binds({tcon, ['Address'], [{tcon, ['Tcp', 'ListenerMsg'], []}]})),
    ?assertEqual("the address of a running program",
                 Binds({tcon, ['Address'], [{tcon, ['Os', 'ProgramMsg'], []}]})),
    ?assertEqual("an address whose message type holds a function",
                 Binds({tcon, ['Address'], [Function]})),
    ?assertEqual("a reply whose answer holds the address of a socket",
                 Binds({tcon, ['Reply'], [{tcon, ['Address'],
                                           [{tcon, ['Tcp', 'SocketMsg'], []}]}]})),
    %% an abstract type's private fields, which its interface carries
    ?assertEqual("an address whose message type holds a function",
                 Binds({tcon, ['Address'], [{tcon, ['Supervisor', 'Msg'], []}]})).

%% report §3.11, §3.9: a declared type is read through its fields, a
%% recursive one once, with its arguments in place of its parameters
bound_declared_type_test() ->
    Source = "export type Tree(a) = Leaf | Node(left : Tree(a), value : a, right : Tree(a))\n"
             "export type Job = Job(run : () -> Unit receiving Never)\n",
    ?assertEqual(ok, peer_ok(Source ++ "export let service : Peer.Service(Tree(Int)) ="
                                        " Peer.service(\"tree\")\n")),
    ?assertEqual("Peer.service names a service at Tree(Job), which is bound to its node, since"
                 " it holds a function",
                 peer_refusal(Source ++ "export let service : Peer.Service(Tree(Job)) ="
                                        " Peer.service(\"tree\")\n")).

%% report §3.11, §8.7, Appendix E.27: a service is made at a message type
%% known whole where it is written, which crosses, and the checker supplies
%% the type itself, every name in it qualified, the module's own among
%% them, whose hash the compiler gives the service beside its name
service_test() ->
    Source = "export type Msg = Add(Int) | Get(reply : Reply(Int))\n"
             "export type Box(a) = Box(a)\n",
    {ok, Typed, _, _} =
        with_peer(Source ++ "export let service : Peer.Service(Msg) = Peer.service(\"counter\")\n"
                            "export let boxes : Peer.Service(Box(Optional(Int))) ="
                            " Peer.service(\"boxes\")\n"),
    Box = {tcon, ['M', 'Box'], [{tcon, ['Optional'], [{tcon, ['Int'], []}]}]},
    ?assertEqual([[#service_type{type = {tcon, ['M', 'Msg'], []}}], [#service_type{type = Box}]],
                 [Supplies || #let_declaration{body = #e_call{callee = #e_var{supplies = Supplies}}}
                                  <- Typed]),
    ?assertEqual("Peer.service names a service at a message type known whole, and here it is a",
                 peer_refusal("export fn serviceOf(name : String) : Peer.Service(a) ="
                              " Peer.service(name)\n")),
    ?assertEqual("Peer.service names a service at (Int) -> Int, which is bound to its node, since"
                 " it holds a function",
                 peer_refusal("export let service : Peer.Service((Int) -> Int) ="
                              " Peer.service(\"f\")\n")),
    ?assertEqual("Peer.service names a service at Address(Tcp.SocketMsg), which is bound to its"
                 " node, since it holds the address of a socket",
                 peer_refusal("export let service : Peer.Service(Address(Tcp.SocketMsg)) ="
                              " Peer.service(\"s\")\n")).

%% report §8.7, Appendix E.27: an offer is accepted only where the service
%% and the address have one message type, and answers the service's holder
%% or Unit
offer_test() ->
    Source = "export type Msg = Add(Int)\n"
             "export let service : Peer.Service(Msg) = Peer.service(\"counter\")\n",
    ?assertEqual(ok, peer_ok(Source ++ "fn serve(counter : Address(Msg)) :"
                                       " Either(Process, Unit) ="
                                       " Peer.offer(service, counter)\n")),
    ?assertMatch({error, _}, peer_ok(Source ++ "fn serve(counter : Address(Int)) :"
                                               " Either(Process, Unit) ="
                                               " Peer.offer(service, counter)\n")),
    ?assertMatch({error, _}, peer_ok(Source ++ "fn serve(counter : Address(Msg)) : Unit ="
                                               " Peer.offer(service, counter)\n")).

%% report §3.11, §3.8, Appendix G.1: a library's resource is a foreign type,
%% and `Ets.Table`, which the checker names nowhere, is bound by that rule:
%% a service at a table is refused, and so is a spawn whose function captures
%% one
ets_table_bound_test() ->
    {ok, Ets} = file:read_file("../../../src/libs/ets/ets.ern"),
    {ok, _, Interface, _} = ern_typecheck:check_string(['Ets'], Ets),
    Refusal = fun(Text) ->
                      {ok, Declarations} = ern_parser:parse_string(Text),
                      {error, [#diagnostic{message = Message} | _]} =
                          ern_typecheck:check(['M'], Declarations, [Interface]),
                      Message
              end,
    ?assertEqual("Peer.service names a service at Ets.Table(Int, Int), which is bound to its"
                 " node, since it holds a value of the foreign type Ets.Table",
                 Refusal("export let service : Peer.Service(Ets.Table(Int, Int)) ="
                         " Peer.service(\"t\")\n")),
    ?assertEqual("the function Peer.spawn starts captures table, whose type Ets.Table(Int, Int)"
                 " is bound to its node, since it holds a value of the foreign type Ets.Table",
                 Refusal("fn f(table : Ets.Table(Int, Int)) : Unit = {\n"
                         ++ spawning("", "fn() : Unit receiving Never = { let _ = table; Unit }"))).

%% report §3.11: the function a spawn on a peer starts is a lambda written
%% in the definition, at the spawn or bound by a `let` the spawn names, a
%% `fn` declared in the definition, or a declaration's name, and what the
%% lambda or the `fn` captures crosses
spawn_function_test() ->
    Head = "fn work(x : Int) : Unit receiving Never = Unit\n"
           "fn f(x : Int) : Unit = {\n",
    ?assertEqual(ok, peer_ok(Head ++ spawning("", "fn() : Unit receiving Never = work(x)"))),
    ?assertEqual(ok, peer_ok(Head ++ spawning("let job = fn() : Unit receiving Never ="
                                              " work(x);\n    ", "job"))),
    ?assertEqual(ok, peer_ok("fn run() : Unit receiving Never = Unit\n"
                             "fn f() : Unit = {\n" ++ spawning("", "run"))),
    ?assertEqual(ok, peer_ok("type Msg = Died(Down)\n"
                             "fn run() : Unit receiving Never = Unit\n"
                             "fn f() : Unit receiving Msg = {\n"
                             "    let _ = Peer.spawnMonitored(\"p\", run, Died, 5000);\n"
                             "    Unit\n"
                             "}\n")),
    %% a local fn, whose captures are checked as a lambda's. A regression
    %% test: one was refused as a function that came as a value
    ?assertEqual(ok, peer_ok("fn f(x : Int) : Unit = {\n"
                             ++ spawning("fn run() : Unit receiving Never = { let _ = x; Unit };\n"
                                         "    ", "run"))),
    ?assertEqual("the function Peer.spawn starts captures g, a function, which is bound to its"
                 " node",
                 peer_refusal("fn f(g : (Int) -> Int) : Unit = {\n"
                              ++ spawning("fn run() : Unit receiving Never ="
                                          " { let _ = g(1); Unit };\n    ", "run"))),
    %% a function that came as a value: a parameter, a top-level `let`, a
    %% call's result, and a `let` of a lambda that a later binding of the
    %% name hides
    ?assertEqual("Peer.spawn starts job, a function that came as a value, whose captures the"
                 " compiler does not see",
                 peer_refusal("fn f(job : () -> Unit receiving Never) : Unit = {\n"
                              ++ spawning("", "job"))),
    ?assertEqual("Peer.spawn starts run, a top-level `let`, whose value may hold captures the"
                 " compiler does not see",
                 peer_refusal("let run : () -> Unit receiving Never = fn() = Unit\n"
                              "fn f() : Unit = {\n" ++ spawning("", "run"))),
    ?assertEqual("Peer.spawn starts a function written where the compiler sees what it"
                 " captures: a declaration's name, or a lambda or a `fn` written in this"
                 " definition",
                 peer_refusal("fn make() : () -> Unit receiving Never = fn() = Unit\n"
                              "fn f() : Unit = {\n" ++ spawning("", "make()"))),
    ?assertEqual("Peer.spawn starts job, a function that came as a value, whose captures the"
                 " compiler does not see",
                 peer_refusal("fn f(jobs : List(() -> Unit receiving Never)) : Unit = {\n"
                              ++ spawning("let job = fn() : Unit receiving Never = Unit;\n"
                                          "    let _ = match jobs { [] -> Unit"
                                          " | job :: _ -> { let _ = Peer.spawn(\"p\", job,"
                                          " 5000); Unit } };\n    ", "job"))),
    %% Peer.spawn is called where it is named
    ?assertEqual("Peer.spawn is called where it is named, so that the compiler sees the function"
                 " it starts",
                 peer_refusal("fn f() : Unit = { let s = Peer.spawn; Unit }\n")).

%% report §8.7, §3.11: a lambda that captures a reply is started by
%% Peer.spawn and Peer.spawnMonitored, the reply crossing with its
%% captures, written at the spawn and bound by a `let`. A regression test,
%% written after the code, which refused the lambda with a message that
%% read false of it
peer_spawn_reply_test() ->
    Worker = "fn worker(r : Reply(Int)) : Unit receiving Never = answer(r, 1)\n",
    Head = Worker ++ "fn f(r : Reply(Int)) : Unit = {\n",
    ?assertEqual(ok, peer_ok(Head ++ spawning("", "fn() : Unit receiving Never = worker(r)"))),
    ?assertEqual(ok, peer_ok(Head ++ spawning("let job = fn() : Unit receiving Never = worker(r);\n"
                                              "    ", "job"))),
    ?assertEqual(ok, peer_ok("type Msg = Died(Down)\n" ++ Worker
                             ++ "fn f(r : Reply(Int)) : Unit receiving Msg = {\n"
                                "    let job = fn() : Unit receiving Never = worker(r);\n"
                                "    let _ = Peer.spawnMonitored(\"p\", job, Died, 5000);\n"
                                "    Unit\n"
                                "}\n")).

%% report §3.11, §6.9, §4.9: `restarting` applied to a function a spawn on a
%% peer admits is admitted, its captures checked as that function's, and
%% applied to any other refused; a lambda or a local fn whose body uses a
%% member of the requirement in force, a function the definition was
%% given, is refused, and a member of a requirement of a fn declared in its
%% body is that fn's own. Regression tests, written after the code
%% (MVP 3.1's item 4)
spawn_restarting_and_members_test() ->
    Limit = "let limit = RestartLimit(restarts = 1, within = 1000);\n    ",
    ?assertEqual(ok, peer_ok("fn run() : Unit receiving Never = Unit\n"
                             "fn f() : Unit = {\n"
                             ++ spawning(Limit, "restarting(limit, run)"))),
    ?assertEqual(ok, peer_ok("fn f(x : Int) : Unit = {\n"
                             ++ spawning(Limit, "restarting(limit, fn() : Unit receiving Never ="
                                                " { let _ = x; Unit })"))),
    ?assertEqual("the function Peer.spawn starts captures g, a function, which is bound to its"
                 " node",
                 peer_refusal("fn f(g : (Int) -> Int) : Unit = {\n"
                              ++ spawning(Limit, "restarting(limit, fn() : Unit receiving Never ="
                                                 " { let _ = g(1); Unit })"))),
    ?assertEqual("Peer.spawn starts a function written where the compiler sees what it"
                 " captures: a declaration's name, or a lambda or a `fn` written in this"
                 " definition",
                 peer_refusal("fn run() : Unit receiving Never = Unit\n"
                              "fn f() : Unit = {\n"
                              ++ spawning(Limit, "restarting(limit, restarting(limit, run))"))),
    ?assertEqual("Peer.spawn starts a function that uses a.show, a member of the requirement in"
                 " force, which is a function bound to its node",
                 peer_refusal("fn f(x : a) : Unit receiving Never needs a.show = {\n"
                              ++ spawning("", "fn() : Unit receiving Never = {"
                                              " let y : a = fault(\"no\");"
                                              " Io.println(Io.show(y)) }"))),
    ?assertEqual(ok, peer_ok("fn f() : Unit = {\n"
                             ++ spawning("", "fn() : Unit receiving Never = {"
                                             " fn shown(v : b) : String needs b.show = Io.show(v);"
                                             " Io.println(shown(1)) }"))).

%% report §3.11, §5.6: the errors the two sections state are the
%% compiler's: a spawn on a peer of a function that came as a value,
%% `Peer.spawn` taken as a value, and a record update with no field. A
%% regression test of the principles review's K19 and K3 (2026-10-09):
%% §3.11 stated its rules and no error, and §5.6 no error for the update
stated_errors_test() ->
    {ok, Report} = file:read_file("../../../report/language.md"),
    [_, AfterSerialization] = binary:split(Report, <<"### 3.11 Serialization">>),
    [Serialization, _] = binary:split(AfterSerialization, <<"\n## 4.">>),
    [_, AfterConstruction] = binary:split(Report, <<"### 5.6 Construction">>),
    [Construction, _] = binary:split(AfterConstruction, <<"\n### 5.7">>),
    Stated = fun(Section, Message) ->
                 ?assertNotEqual({nomatch, Message},
                                 {binary:match(Section, list_to_binary(Message)), Message})
             end,
    Stated(Serialization,
           peer_refusal("fn g(f : () -> Unit receiving Never) : Unit = {\n"
                        ++ spawning("", "f"))),
    Stated(Serialization, peer_refusal("fn g() : Unit = { let start = Peer.spawn; Unit }\n")),
    Stated(Serialization,
           peer_refusal("fn f(x : a) : Unit receiving Never needs a.show = {\n"
                        ++ spawning("", "fn() : Unit receiving Never = {"
                                        " let y : a = fault(\"no\"); Io.println(Io.show(y)) }"))),
    Stated(Construction,
           refusal("type Point = Point(x : Int, y : Int)\n"
                   "fn same(p : Point) : Point = Point(..p)\n")).

%% report §3.11, §3.9: what the lambda a spawn on a peer starts captures is
%% neither bound nor of a type that holds a type variable, and a name its
%% body binds itself, or a top-level name it writes, is no capture
spawn_captures_test() ->
    %% a captured function is named, since its type at the use has the
    %% use's effect (§3.9) and not the one its parameter declares
    ?assertEqual("the function Peer.spawn starts captures g, a function, which is bound to its"
                 " node",
                 peer_refusal("fn f(g : (Int) -> Int) : Unit = {\n"
                              ++ spawning("", "fn() : Unit receiving Never ="
                                              " { let _ = g(1); Unit }"))),
    ?assertEqual("the function Peer.spawn starts captures socket, whose type"
                 " Address(Tcp.SocketMsg) is bound to its node, since it holds the address of a"
                 " socket",
                 peer_refusal("fn f(socket : Address(Tcp.SocketMsg)) : Unit = {\n"
                              ++ spawning("", "fn() : Unit receiving Never = { let _ = socket; Unit"
                                              " }"))),
    ?assertEqual("the function Peer.spawn starts captures x, whose type a holds a type"
                 " variable",
                 peer_refusal("fn f(x : a) : Unit = {\n"
                              ++ spawning("", "fn() : Unit receiving Never ="
                                              " { let _ = [x]; Unit }"))),
    %% a local fn captured by the lambda is a function
    ?assertEqual("the function Peer.spawn starts captures helper, a function, which is bound to"
                 " its node",
                 peer_refusal("fn f() : Unit = {\n"
                              ++ spawning("fn helper() : Unit receiving Never = Unit;\n    ",
                                          "fn() : Unit receiving Never = helper()"))),
    ?assertEqual(ok, peer_ok("fn work(x : Int) : Unit receiving Never = Unit\n"
                             "fn f(n : Int) : Unit = {\n"
                             ++ spawning("", "fn() : Unit receiving Never = {"
                                             " let local = fn(y : Int) : Int = y + n;"
                                             " work(local(1)) }"))).

%% report §3.11, §8.1: the process a spawn on a peer starts has a mailbox
%% type known whole where it is written, which crosses; one that is a
%% variable nothing fixed is Never, as an entry point's is, and one an
%% annotation names is refused, since an instance could make it bound. A
%% regression test: §6.10's spawn of a lambda with no annotation was
%% refused
spawn_mailbox_test() ->
    ?assertEqual(ok, peer_ok("fn f() : Unit = {\n" ++ spawning("", "fn() = Unit"))),
    {ok, Typed} = typed_peer("fn idle() : Unit receiving m = receive { after 1 -> Unit }\n"
                             "fn f() : Unit = {\n" ++ spawning("", "idle")),
    ?assertEqual(["Address(Never)"],
                 [ern_types:format(Answer, ern_types:new())
                  || #fn_declaration{name = f, body = Body} <- Typed,
                     #e_call{callee = #e_var{name = spawn}, type = {tcon, ['Either'], [_, Answer]}}
                         <- calls(Body)]),
    ?assertEqual("Peer.spawn starts a process whose mailbox type a is not known whole here",
                 peer_refusal("fn f() : Either(Io.Error, Address(a)) ="
                              " Peer.spawn(\"p\", fn() = Unit, 5000)\n")),
    ?assertEqual("Peer.spawn starts a process whose mailbox type Msg is bound to its node,"
                 " since it holds a function",
                 peer_refusal("type Msg = Up(f : (Int) -> Int)\n"
                              "fn loop() : Unit receiving Msg = receive { Up(f = _) -> loop() }\n"
                              "fn f() : Unit = {\n" ++ spawning("", "loop"))),
    ?assertEqual(ok, peer_ok("type Msg = Add(Int)\n"
                             "fn loop() : Unit receiving Msg = receive { Add(_) -> loop() }\n"
                             "fn f() : Unit = {\n" ++ spawning("", "loop"))).

%% A function body that computes Function by Form, `Peer.computeAt` on the
%% peer `p` or `Peer.compute` on a peer the node picks, and drops what the
%% compute answers, after the given statements.
computing(Form, Statements, Function) ->
    "    " ++ Statements ++ "let _ = " ++ Form ++ "(" ++ peer_name(Form) ++ Function
        ++ ", 5000);\n"
    "    Unit\n"
    "}\n".

peer_name("Peer.computeAt") -> "\"p\", ";
peer_name("Peer.compute") -> "".

%% report §3.11, §8.7, Appendix E.27: the function a compute runs, on a peer
%% named or on one the node picks, is checked as a spawn's, each error
%% naming the form written: its captures, a function that came as a value,
%% a member of a requirement in force, its mailbox type, which is Never
%% where it is a variable nothing fixed, and
%% `restarting` over a function it admits; each form is called where it is
%% named. A regression test, written after the code, of `Peer.computeAt`,
%% today's form of the compute on a named peer, and of `Peer.compute`
compute_function_test() ->
    lists:foreach(fun compute_function/1, ["Peer.computeAt", "Peer.compute"]).

compute_function(Form) ->
    Head = "fn work(x : Int) : Int = x\n"
           "fn f(x : Int) : Unit = {\n",
    ?assertEqual(ok, peer_ok(Head ++ computing(Form, "", "fn() = work(x)"))),
    ?assertEqual(ok, peer_ok(Head ++ computing(Form, "let job = fn() = work(x);\n    ", "job"))),
    ?assertEqual(ok, peer_ok("fn run() : Int = 42\n"
                             "fn f() : Unit = {\n" ++ computing(Form, "", "run"))),
    ?assertEqual("the function " ++ Form ++ " runs captures g, a function, which is bound to"
                 " its node",
                 peer_refusal("fn f(g : (Int) -> Int) : Unit = {\n"
                              ++ computing(Form, "", "fn() = g(1)"))),
    ?assertEqual("the function " ++ Form ++ " runs captures socket, whose type"
                 " Address(Tcp.SocketMsg) is bound to its node, since it holds the address of a"
                 " socket",
                 peer_refusal("fn f(socket : Address(Tcp.SocketMsg)) : Unit = {\n"
                              ++ computing(Form, "", "fn() = { let _ = socket; 1 }"))),
    ?assertEqual("the function " ++ Form ++ " runs captures x, whose type a holds a type"
                 " variable",
                 peer_refusal("fn f(x : a) : Unit = {\n"
                              ++ computing(Form, "", "fn() = { let _ = [x]; 1 }"))),
    ?assertEqual(Form ++ " runs job, a function that came as a value, whose captures the"
                 " compiler does not see",
                 peer_refusal("fn f(job : () -> Int) : Unit = {\n"
                              ++ computing(Form, "", "job"))),
    ?assertEqual(Form ++ " runs a function that uses a.show, a member of the requirement"
                 " in force, which is a function bound to its node",
                 peer_refusal("fn f(x : a) : Unit receiving Never needs a.show = {\n"
                              ++ computing(Form, "", "fn() = { let y : a = fault(\"no\");"
                                                     " Io.show(y) }"))),
    ?assertEqual(Form ++ " starts a process whose mailbox type Msg is bound to its node,"
                 " since it holds a function",
                 peer_refusal("type Msg = Up(f : (Int) -> Int)\n"
                              "fn loop() : Int receiving Msg = receive { Up(f = _) -> loop() }\n"
                              "fn f() : Unit = {\n" ++ computing(Form, "", "loop"))),
    ?assertEqual(Form ++ " starts a process whose mailbox type a is not known whole here",
                 peer_refusal("fn f(other : Address(a)) : Unit = {\n"
                              ++ computing(Form, "", "fn() = { let me : Address(a) = self();"
                                                     " 1 }"))),
    Limit = "let limit = RestartLimit(restarts = 1, within = 1000);\n    ",
    ?assertEqual(ok, peer_ok("fn run() : Unit receiving Never = Unit\n"
                             "fn f() : Unit = {\n"
                             ++ computing(Form, Limit, "restarting(limit, run)"))),
    ?assertEqual(Form ++ " is called where it is named, so that the compiler sees the"
                 " function it starts",
                 peer_refusal("fn f() : Unit = { let c = " ++ Form ++ "; Unit }\n")).

%% report §3.11, Appendix E.27: the help of a form taken as a value writes
%% the call as the form takes its arguments, `Peer.compute` without a
%% peer's name. A regression test, written after the code
compute_as_value_help_test() ->
    Help = fun(Form) ->
               {error, [#diagnostic{help = Text} | _]} =
                   with_peer("fn f() : Unit = { let c = " ++ Form ++ "; Unit }\n"),
               Text
           end,
    ?assertEqual("call it: `Peer.compute(fn() = ..., ms)` (report §3.11)", Help("Peer.compute")),
    ?assertEqual("call it: `Peer.computeAt(name, fn() = ..., ms)` (report §3.11)",
                 Help("Peer.computeAt")).

%% report §3.11, Appendix E.28: Code.running names a top-level `fn` of any
%% arity whose result type is Unit and whose mailbox type, read from its
%% declaration, holds no type variable where it has one, and the call is
%% List(Address(m)), m that mailbox type, so a send over the list is
%% checked against it, and Never for a function that receives nothing
%% (code_running_never_test); a local, a lambda, a top-level `let`, a foreign
%% declaration and the prelude's name are refused, so are a result type
%% other than Unit and a mailbox type that holds a type variable, and
%% Code.running is called where it is named. A regression test, written
%% after the code; a function that receives nothing was refused until
%% 2026-10-16
code_running_test() ->
    Loop = "type Msg = Stop\n"
           "fn loop(n : Int, name : String) : Unit receiving Msg = receive { Stop -> Unit }\n",
    Listing = fun(Function) ->
                  "fn f() : Unit = {\n    let _ = Code.running(" ++ Function ++ ");\n"
                  "    Unit\n}\n"
              end,
    ?assertEqual(ok, peer_ok(Loop ++ "fn f() : Unit =\n"
                             "    List.forEach(Code.running(loop), fn(p) = send(p, Stop))\n")),
    ?assertEqual(ok, peer_ok(Loop ++ "fn f() : List(Address(Msg)) = Code.running(loop)\n")),
    ?assertMatch({error, _},
                 peer_ok(Loop ++ "fn f() : Unit =\n"
                         "    List.forEach(Code.running(loop), fn(p) = send(p, 1))\n")),
    %% a recursive declaration names itself
    ?assertEqual(ok, peer_ok("fn again() : Unit receiving Int =\n"
                             "    receive { _ -> List.forEach(Code.running(again), fn(p) ="
                             " send(p, 1)) }\n")),
    ?assertEqual("Code.running lists the processes that run a declaration, and g is a local,"
                 " whose function is no declaration",
                 peer_refusal(Loop ++ "fn f() : Unit = {\n    let g = loop;\n"
                              "    let _ = Code.running(g);\n    Unit\n}\n")),
    ?assertEqual("Code.running lists the processes that run a declaration, named where the call"
                 " is written",
                 peer_refusal(Loop ++ Listing("fn() : Unit receiving Msg = loop(1, \"a\")"))),
    ?assertEqual("Code.running lists the processes that run a declaration, and g is a top-level"
                 " `let`, whose value is no declaration",
                 peer_refusal("let g : (Int) -> Int = fn(n) = n\n" ++ Listing("g"))),
    ?assertEqual("Code.running lists the processes that run a declaration, and outside is a"
                 " foreign declaration, which has no hash",
                 peer_refusal("foreign fn outside() : Unit receiving Int = \"m:f/0\"\n"
                              ++ Listing("outside"))),
    ?assertEqual("Code.running lists the processes that run a declaration, and spawn is the"
                 " prelude's, which no module declares",
                 peer_refusal(Listing("spawn"))),
    ?assertEqual("Code.running lists the processes that run g, whose result type is Int, not"
                 " Unit",
                 peer_refusal("fn g() : Int receiving Int = receive { n -> n }\n" ++ Listing("g"))),
    ?assertEqual(ok, peer_ok("fn g() : Unit = Io.println(\"g\")\n" ++ Listing("g"))),
    ?assertEqual(ok, peer_ok("fn g() : Unit = Unit\n"
                             "fn f() : Unit = List.forEach(Code.running(g), kill)\n")),
    ?assertEqual("Code.running lists the processes that run g, whose mailbox type m holds a"
                 " type variable",
                 peer_refusal("fn g() : Unit receiving m = receive { after 1 -> Unit }\n"
                              ++ Listing("g"))),
    ?assertEqual("Code.running is called where it is named, so that the compiler sees the"
                 " declaration it names",
                 peer_refusal("fn f() : Unit = { let r = Code.running; Unit }\n")).

%% report §3.11, Appendix E.28, §6.2: Code.running of a function that
%% receives nothing answers addresses at Never, since the function runs in
%% a process whose mailbox type it does not know: its declaration's, though
%% the function stands at the call for one that receives (§3.9). A send to
%% one is refused, `expected Never`, a send over the list too, and an
%% annotation of another mailbox type; `kill` over it is not. A regression
%% test, written after the fix (the release review before 0.4.0 found the
%% addresses at a variable nothing fixed, a send of 42 to a process that
%% received another type compiling and breaking its mailbox at run time);
%% it does not run a program
code_running_never_test() ->
    Work = "fn work(n : Int) : Unit = if n == 0 then Unit else work(n - 1)
",
    ?assertEqual(ok, peer_ok(Work ++ "fn f() : List(Address(Never)) = Code.running(work)
")),
    ?assertEqual(ok, peer_ok(Work ++ "fn f() : Unit = List.forEach(Code.running(work), kill)
")),
    ?assertEqual("the argument does not fit send: expected Never, found Int",
                 peer_refusal(Work ++ "fn f() : Unit = match Code.running(work) {
"
                              "    [p] -> send(p, 42)
  | _ -> Unit
}
")),
    ?assertEqual("the argument does not fit List.forEach: expected (Address(Never)) -> Unit,"
                 " found (Address(Int)) -> Unit",
                 peer_refusal(Work ++ "fn f() : Unit =
"
                              "    List.forEach(Code.running(work), fn(q) = send(q, 42))
")),
    ?assertMatch({error, _},
                 peer_ok(Work ++ "fn f() : List(Address(Int)) = Code.running(work)
")).

%% report §3.11, §8.7, §3.9: the value a compute answers crosses back, so
%% the result type of its function is known whole where the compute is
%% written and is not bound; a function with a mailbox type runs there, as
%% a function with none does, its mailbox type Never where it is a variable
%% the definition's type does not hold; and the call's type is
%% Either(Io.Error, a), a the result type; for both forms, on a peer named
%% and on one the node picks. A regression test, written after the code;
%% the function with a mailbox type a regression of its own: the
%% declaration's effect variable, which occurs once, was taken for none,
%% and the compute refused every function with a mailbox type
compute_result_test() ->
    lists:foreach(fun compute_result/1,
                  [{"Peer.computeAt", computeAt, 2}, {"Peer.compute", compute, 1}]).

compute_result({Form, Name, Position}) ->
    ?assertEqual(Form ++ " answers a value of type (Int) -> Int, which is bound to its"
                 " node, since it holds a function",
                 peer_refusal("fn f() : Unit = {\n"
                              ++ computing(Form, "", "fn() = fn(n : Int) = n + 1"))),
    ?assertEqual(Form ++ " answers a value of type Address(Tcp.SocketMsg), which is bound"
                 " to its node, since it holds the address of a socket",
                 peer_refusal("fn socket() : Address(Tcp.SocketMsg) = fault(\"none\")\n"
                              "fn f() : Unit = {\n"
                              ++ computing(Form, "", "fn() = socket()"))),
    ?assertEqual(Form ++ " answers a value of type List(a), which holds a type variable,"
                 " so whether it crosses is not known here",
                 peer_refusal("fn f() : Unit = {\n" ++ computing(Form, "", "fn() = []"))),
    ?assertEqual(ok, peer_ok("fn f() : Unit = {\n"
                             ++ computing(Form, "",
                                          "fn() : Int receiving Int = receive { n -> n }"))),
    ?assertEqual(ok, peer_ok("fn f() : Unit = {\n"
                             ++ computing(Form, "", "fn() = { Io.println(\"here\"); 42 }"))),
    {ok, Typed} = typed_peer("fn idle() : Int receiving m = receive { after 1 -> 7 }\n"
                             "fn f() : Unit = {\n" ++ computing(Form, "", "idle")),
    [{Answer, Function}] = [{Answer, lists:nth(Position, Params)}
                            || #fn_declaration{name = f, body = Body} <- Typed,
                               #e_call{callee = #e_var{name = Called, type = CalleeType},
                                       type = Answer} <- calls(Body),
                               Called =:= Name,
                               {tfn, Params, _, _} <- [CalleeType]],
    ?assertEqual("Either(Io.Error, Int)", ern_types:format(Answer, ern_types:new())),
    ?assertMatch({tfn, [], {tcon, ['Never'], []}, {tcon, ['Int'], []}}, Function).

%% report §3.10, §11.1: `==` on another module's abstract type whose fields
%% name a private type reads the private type from the interface. A
%% regression test: the checker stopped on it, and it does not cover the
%% descriptor builder, which had read those types already
equality_reads_private_types_test() ->
    {ok, _, Interface, _} =
        ern_typecheck:check_string(['A'], "export abstract type T = T(Inner)\n"
                                          "type Inner = Inner(Int)\n"
                                          "export fn make() : T = T(Inner(1))\n"),
    {ok, Declarations} = ern_parser:parse_string("fn f(x : A.T, y : A.T) : Bool = x == y\n"),
    ?assertMatch({ok, _, _, _}, ern_typecheck:check(['M'], Declarations, [Interface])).

%% report §11.1, §4.2: the interface carries each private type an exported
%% signature names wherever an arrow's effect names it, a mailbox type an
%% exported function receives, one a function parameter or result receives
%% and one a function in an exported type's field receives, with those
%% their fields name, beside those an abstract type's fields name, and no
%% other private type; a dependent describes a value of each and cannot
%% name it. A regression test: the interface carried those an abstract
%% type's fields name alone, and a dependent describing an address of a
%% private mailbox type faulted; the descriptors built from them are the
%% shell's tests' and the integration tests'
interface_carries_named_private_types_test() ->
    {ok, _, #interface{private_types = PrivateTypes} = Interface, _} =
        ern_typecheck:check_string(
          ['A'],
          "type Msg = Add(Int) | Get(Reply(Inner))\n"
          "type Inner = Inner(Int)\n"
          "type Job = Job\n"
          "type Done = Done\n"
          "type Step = Step\n"
          "type Field = Field(Int)\n"
          "type Kept = Kept(Int)\n"
          "export abstract type Hidden = Hidden(Field)\n"
          "export type Task = Task(run : () -> Unit receiving Step)\n"
          "export fn count(total : Int) : Unit receiving Msg = receive { _ -> count(total) }\n"
          "export fn run(job : () -> Unit receiving Job) : Unit = Unit\n"
          "export fn later() : () -> Unit receiving Done =\n"
          "    fn() : Unit receiving Done = receive { _ -> Unit }\n"
          "export fn kept() : Int = match Kept(1) { Kept(n) -> n }\n"),
    ?assertEqual([['A', 'Done'], ['A', 'Field'], ['A', 'Inner'], ['A', 'Job'], ['A', 'Msg'],
                  ['A', 'Step']],
                 lists:sort(maps:keys(PrivateTypes))),
    {ok, Spawn} = ern_parser:parse_string("fn f() : Unit = {\n"
                                          "    let p = spawn(fn() = A.count(0));\n"
                                          "    Unit\n"
                                          "}\n"),
    {ok, _, _, Env} = ern_typecheck:check(['M'], Spawn, [Interface]),
    ?assertMatch(#type_info{qualified_name = ['A', 'Msg']},
                 ern_typecheck:described_type(['A', 'Msg'], Env)),
    {ok, Named} = ern_parser:parse_string("fn f(x : A.Msg) : Int = 1\n"),
    ?assertMatch({error, [#diagnostic{message = "A.Msg is a type A keeps private"}]},
                 ern_typecheck:check(['M'], Named, [Interface])).

%% report §11.5, §4.2: a dependent that names a type another module keeps
%% private, which that module's interface carries, is refused as private,
%% on the type as written, with no namespace to load; a qualified type
%% nothing declares stays unknown. A regression test, written after the
%% code: the private type was refused as unknown; it does not cover the
%% prompt, which the shell's tests do
private_type_named_by_a_dependent_test() ->
    {ok, _, Interface, _} =
        ern_typecheck:check_string(['Plain'],
                                   "type Msg = Add(Int)\n"
                                   "export fn count(total : Int) : Unit receiving Msg =\n"
                                   "    receive { Add(amount) -> count(total + amount) }\n"),
    {ok, Named} = ern_parser:parse_string("fn f(x : Address(Plain.Msg)) : Int = 1\n"),
    ?assertMatch({error, [#diagnostic{span = {1, 18, _},
                                      message = "Plain.Msg is a type Plain keeps private",
                                      unknown_namespace = undefined}]},
                 ern_typecheck:check(['M'], Named, [Interface])),
    {ok, Absent} = ern_parser:parse_string("fn f(x : Plain.Absent) : Int = 1\n"),
    ?assertMatch({error, [#diagnostic{message = "unknown type Plain.Absent",
                                      unknown_namespace = ['Plain']}]},
                 ern_typecheck:check(['M'], Absent, [Interface])).

%% report §11.5, §4.2: a dependent that names a constructor of a type
%% another module keeps private, which that module's interface carries, is
%% refused as the private type's, in an expression and a pattern alike,
%% with no namespace to load; a constructor nothing declares, and one of a
%% private type the interface does not carry, stay unknown. A regression
%% test, written after the code: the constructor was refused as unknown
%% (the tour's spike, docs/findings.md's S2); it does not cover the
%% prompt, which the shell's tests do
private_constructor_named_by_a_dependent_test() ->
    {ok, _, Interface, _} =
        ern_typecheck:check_string(['Plain'],
                                   "type Msg = Add(Int)\n"
                                   "type Kept = Kept(Int)\n"
                                   "export fn count(total : Int) : Unit receiving Msg =\n"
                                   "    receive { Add(amount) -> count(total + amount) }\n"
                                   "export fn kept() : Int = match Kept(1) { Kept(n) -> n }\n"),
    Refused = fun(Text) ->
                  {ok, Module} = ern_parser:parse_string(Text),
                  ern_typecheck:check(['M'], Module, [Interface])
              end,
    Private = "Plain.Add is a constructor of Plain.Msg, a type Plain keeps private",
    ?assertMatch({error, [#diagnostic{span = {1, 26, _}, message = Private,
                                      unknown_namespace = undefined}]},
                 Refused("fn f() : Int = { let _ = Plain.Add(1); 1 }\n")),
    ?assertMatch({error, [#diagnostic{message = Private}]},
                 Refused("fn f(x) : Int = match x { Plain.Add(n) -> n | _ -> 0 }\n")),
    ?assertMatch({error, [#diagnostic{message = "unknown constructor Plain.Absent",
                                      unknown_namespace = ['Plain']}]},
                 Refused("fn f() : Int = { let _ = Plain.Absent; 1 }\n")),
    ?assertMatch({error, [#diagnostic{message = "unknown constructor Plain.Kept"}]},
                 Refused("fn f() : Int = { let _ = Plain.Kept(1); 1 }\n")).

%% report §4.7, §3.10: a foreign function's type variable written `a=` in
%% its parameters carries the equality constraint, as one a body compares
%% does; it is written once, and nowhere but a foreign function's
%% parameters
foreign_fn_equality_mark_test() ->
    Member = "foreign fn member(element : a=, list : List(a)) : Bool = \"lists:member/2\"\n",
    ?assertEqual(ok, ok(Member ++ "fn f() = member(1, [2])\n")),
    ?assertEqual("(Int) -> Int does not support equality (it contains a function, an address"
                 " or a reply), which member requires of its first argument",
                 refusal(Member ++ "fn f() = member(fn(x : Int) : Int = x, [])\n")),
    %% the mark is the variable's: it holds at the occurrence it is not on
    ?assertEqual("(a=, List(a=)) -> Bool",
                 type_of("export " ++ Member, member)),
    ?assertEqual(type_of("export " ++ Member, member),
                 type_of("export foreign fn member(element : a, list : List(a=)) : Bool ="
                         " \"lists:member/2\"\n", member)),
    ?assertEqual({"a is marked twice", "write a= once; it marks every occurrence of a"},
                 refusal_and_help("foreign fn m(list : List(a=), element : a=) : Bool ="
                                  " \"lists:member/2\"\n")),
    ?assertEqual({"a foreign function's result type takes no equality mark",
                  "mark a in the parameters, a="},
                 refusal_and_help("foreign fn m(list : List(a)) : List(a=) = \"m:m/1\"\n")),
    Elsewhere = {"the equality mark is written in a foreign function's parameters alone",
                 "write a; a has equality where a body compares its values with =="},
    ?assertEqual(Elsewhere, refusal_and_help("fn f(x : List(a=)) : Int = 1\n")),
    ?assertEqual(Elsewhere, refusal_and_help("type Box(a) = Box(List(a=))\n")),
    ?assertEqual(Elsewhere, refusal_and_help("fn f() = { let x : List(a=) = []; 1 }\n")).

%% report §3.10, Appendix E.21: a process has equality and no ordering, and
%% a comparison of addresses is refused with the process behind each named
process_identity_test() ->
    ok("fn same(a : Address(Int), b : Address(Int)) : Bool =\n"
       "    Process.fromAddress(a) == Process.fromAddress(b)"),
    ?assertEqual("`==` is not defined on Address(Int): it contains a function, an address or a"
                 " reply; compare the processes behind addresses, `Process.fromAddress(a)`",
                 refusal("fn same(a : Address(Int), b : Address(Int)) = a == b")),
    ?assertMatch("`<` is not defined on Process" ++ _,
                 refusal("fn before(a : Process, b : Process) = a < b")).

%% report §3.10
equality_test() ->
    ?assertEqual("`==` is not defined on (Int) -> Int: it contains a function, an address or a"
                 " reply",
                 refusal("fn f(g : (Int) -> Int) = g == g")),
    ?assertEqual("Address(Int) does not support equality (it contains a function, an address"
                 " or a reply), which equal requires of its first argument; compare the"
                 " processes behind addresses, `Process.fromAddress(a)`",
                 refusal("fn same(a : Address(Int), b) = equal(a, b)\nfn equal(a, b) = a == b")),
    ?assertEqual("Address(Int) does not support equality (it contains a function, an address"
                 " or a reply), which Map.put requires of a Map's key, in its second argument"
                 "; compare the processes behind addresses, `Process.fromAddress(a)`",
                 refusal("fn f(a : Address(Int)) = Map.put(Map.empty, a, 1)")),
    ?assertEqual(ok, ok("fn f(a : String) = Map.put(Map.empty, a, 1)")).

%% report §3.10: `==` on a reply, or on a value that holds one, is a type
%% error, as on a function or an address, through the equality constraint
%% as at the operator. A regression test written after the code,
%% 2026-10-16, when §6.6's obligation, which had refused it first, went
reply_equality_test() ->
    ?assertEqual("`==` is not defined on Reply(Int): it contains a function, an address or a"
                 " reply",
                 refusal("fn f(r : Reply(Int)) : Bool = r == r")),
    ?assertEqual("`==` is not defined on List(Reply(Int)): it contains a function, an address"
                 " or a reply",
                 refusal("fn f(rs : List(Reply(Int))) : Bool = rs == rs")),
    ?assertEqual("Reply(Int) does not support equality (it contains a function, an address or"
                 " a reply), which equal requires of its first argument",
                 refusal("fn equal(a, b) = a == b\n"
                         "fn f(r : Reply(Int)) : Bool = equal(r, r)")).

%% report §6.6, §4.7, §11.2: a reply is a value and stands wherever a value
%% stands: dropped by `_` or an omitted field, bound twice by `as`, the
%% operand of a selection and the base of an update, on a path `&&` or a
%% `<-` may skip, captured by a local fn or by a lambda passed on, held at
%% top level, in a map, given to a function that copies or drops it and to
%% `Foreign.term`, and answered twice or never. A regression test written
%% after the code, 2026-10-16, when the reply's obligation, which refused
%% each, went
reply_is_a_value_test() ->
    Source = "type Ask = Ask(reply : Reply(Int), n : Int)\n"
             "type Req = Get(reply : Reply(Int)) | Stop\n",
    Programs =
        ["fn f(r : Reply(Int)) : Unit = { let _ = r; Unit }",
         "fn f(q : Req) : Int = match q { Get() -> 1 | Stop -> 0 }",
         "fn f(q : Req) : Int = match q { Get(reply = _) as whole -> 1 | Stop -> 0 }",
         "fn f(a : Ask) : Int = a.n",
         "fn f(a : Ask) : Ask = Ask(..a, n = 2)",
         "fn f(r : Reply(Int), c : Bool) : Bool = c && { answer(r, 1); true }",
         "fn f(r : Reply(Int), t : String) : Optional(Unit) =\n"
         "    { let n <- String.toInt(t); answer(r, n); Some(Unit) }",
         "fn f(r : Reply(Int)) : Unit = { fn go() : Unit = answer(r, 1); go() }",
         "fn f(r : Reply(Int)) : Unit = List.forEach([1, 2], fn(x) = answer(r, x))",
         "let none : List(Reply(Int)) = []",
         "fn f(r : Reply(Int)) : Map(Int, Reply(Int)) = Map.put(Map.empty, 1, r)",
         "fn f(rs : List(Reply(Int))) : Int = List.size(rs)",
         "fn f(r : Reply(Int)) : Foreign.Term = Foreign.term(r)",
         "fn f(r : Reply(Int)) : Unit = { answer(r, 1); answer(r, 2) }",
         "fn f(r : Reply(Int)) : Unit = Unit"],
    [?assertEqual({Program, ok}, {Program, ok(Source ++ Program)}) || Program <- Programs],
    ?assertEqual("(a) -> #(a, a)", type_of("export fn dup(x) = #(x, x)", dup)).

%% report §3.10: a declared type holds what its fields hold, its arguments
%% in place of its parameters, an abstract type too; a recursive type, one
%% nested in itself at other arguments among them, is read to its end; a
%% parameter no field holds brings nothing. A regression test: the fields
%% were not read, and `Box(f) == Box(f)` compared two functions. It does
%% not cover an abstract type of another module, which reads the same
%% constructors from its interface.
declared_type_equality_test() ->
    ?assertEqual("`==` is not defined on Box: it contains a function, an address or a reply",
                 refusal("type Box = Box((Int) -> Int)\nfn f(b : Box) = b == b")),
    ?assertEqual("`==` is not defined on Wrap(Int): it contains a function, an address or a"
                 " reply",
                 refusal("type Wrap(a) = Wrap((a) -> Int)\nfn f(w : Wrap(Int)) = w == w")),
    ?assertEqual("`==` is not defined on Holder((Int) -> Int): it contains a function, an"
                 " address or a reply",
                 refusal("type Holder(a) = Holder(Optional(a))\n"
                         "fn f(h : Holder((Int) -> Int)) = h == h")),
    ?assertEqual("`==` is not defined on Tree: it contains a function, an address or a reply",
                 refusal("type Tree = Leaf | Node(left : Tree, f : (Int) -> Int)\n"
                         "fn f(t : Tree) = t == t")),
    ?assertEqual("`==` is not defined on Nest((Int) -> Int): it contains a function, an address"
                 " or a reply",
                 refusal("type Nest(a) = Flat(a) | Deeper(List(Nest(a)))\n"
                         "fn f(n : Nest((Int) -> Int)) = n == n")),
    ?assertEqual("`==` is not defined on Hidden: it contains a function, an address or a reply",
                 refusal("export abstract type Hidden = Hidden((Int) -> Int)\n"
                         "fn f(h : Hidden) = h == h")),
    ?assertEqual(ok, ok("type Tree(a) = Leaf | Node(left : Tree(a), value : a)\n"
                        "type Nest(a) = Flat(a) | Deeper(List(Nest(a)))\n"
                        "fn f(t : Tree(Int), n : Nest(String)) = t == t && n == n")),
    ?assertEqual(ok, ok("type Tag(a) = Tag(Int)\nfn f(t : Tag((Int) -> Int)) = t == t")).

%% report §4.9, §9.4, Appendix E.1, §11.5: Io.show needs a.show, which a
%% call supplies: at a type variable of the signature the requirement's, and
%% at a type built from variables the requirement names, the descriptor
%% composed of theirs, for Io.show and for any function that needs show; a
%% variable the requirement does not name is a call that needs it. A
%% regression test of the full review's P4 (2026-10-04): `List(a)` under
%% `needs a.show` was refused
show_under_a_requirement_test() ->
    ?assertEqual(ok, ok("fn wrap(x : a) : String needs a.show = Io.show(x)")),
    ?assertEqual(ok, ok("fn wrap(x : a) : String needs a.show = Io.show(x)\n"
                        "fn f() : String = wrap(1)")),
    ?assertEqual({"Io.show needs a.show, which wrap does not declare",
                  "add `needs a.show` to wrap's signature"},
                 refusal_and_help("fn wrap(x : a) : String = Io.show(x)")),
    ?assertEqual(ok, ok("fn wrap(xs : List(a)) : String needs a.show = Io.show(xs)")),
    ?assertEqual(ok, ok("fn wrap(x : a) : String needs a.show = Io.show(Some(#(x, 1)))")),
    ?assertEqual(ok, ok("fn wrap(x : a) : String needs a.show = Io.show(x)\n"
                        "fn f(xs : List(b)) : String needs b.show = wrap(xs)")),
    ?assertEqual("Io.show needs b.show, which wrap does not declare",
                 refusal("fn wrap(pair : #(a, b)) : String needs a.show = Io.show(pair)")).

%% report Appendix E.1: `Io.show` and `Io.debug` write a value by the type
%% at which the name is used, as a callee or an argument, known whole once
%% the definition is inferred; a type variable in it is a type error, and
%% an effect variable is none, a function being written `<function>`. A
%% regression test of the rule of 2026-10-01: a type variable wrote the
%% runtime's representation
show_needs_a_known_type_test() ->
    Help = "annotate the value where it is bound; at a type variable of the signature, a"
           " requirement `needs a.show` lets it write the value",
    ?assertEqual({"the type List(a) is not known whole here, and Io.show writes a value by its"
                  " type", Help},
                 refusal_and_help("fn f() : String = Io.show([])")),
    ?assertEqual("the type Optional(a) is not known whole here, and Io.debug writes a value by"
                 " its type",
                 refusal("fn f() : Unit = { let _ = Io.debug(None); Unit }")),
    ?assertEqual(ok, ok("fn f() : String = { let xs : List(Int) = []; Io.show(xs) }")),
    ?assertEqual(ok, ok("fn f() : String = Io.show(fn(n : Int) = n)")),
    ?assertEqual(ok, ok("fn f(xs : List(Int)) : List(String) = List.map(xs, Io.show)")).

%% report §8.4: a foreign function's implementation is named
%% module:function/arity, the function as the host names it, an operator
%% among them; a name of another form is refused. A regression test,
%% written after the code: an operator was no name
operator_implementation_test() ->
    ?assertEqual(ok, ok("foreign fn plus(a : Int, b : Int) : Int = \"erlang:+/2\"")),
    ?assertEqual(ok, ok("foreign fn same(a : Int, b : Int) : Bool = \"erlang:=:=/2\"")),
    ?assertEqual("the implementation of plus is not written `module:function/arity`",
                 refusal("foreign fn plus(a : Int, b : Int) : Int = \"erlang:+x/2\"")),
    ?assertEqual("the implementation names arity 3, and plus has 2 parameters",
                 refusal("foreign fn plus(a : Int, b : Int) : Int = \"erlang:+/3\"")).

%% report §11.1: a `foreign fn` whose implementation names a unit, a module
%% `ern@` and a path, is refused at the string, since a unit's functions are
%% named by their position and an Ernest function is called by its name;
%% a module whose name merely holds `ern` is the host's. Written with the
%% code (MVP 3.2's item 4)
unit_implementation_test() ->
    ?assertEqual("the implementation names ern@util, a unit of Ernest's, whose functions are"
                 " named by their position",
                 refusal("foreign fn twice(n : Int) : Int = \"ern@util:twice/1\"")),
    ?assertEqual("the implementation names ern@net@http, a unit of Ernest's, whose functions"
                 " are named by their position",
                 refusal("foreign fn get(n : Int) : Int = \"ern@net@http:get/1\"")),
    ?assertEqual(ok, ok("foreign fn time() : Int = \"ern_rt:now/0\"")).

%% report §8.4, Appendix E.12: `Foreign.term` gives its value by the type at
%% which the name is used, which is known whole there: on a type variable,
%% and on a type that holds one, it is refused, as a callee and as a value,
%% and no requirement names it; at a known type it is taken, an effect
%% variable in the type being no matter. A regression test, written after
%% the code: the value crossed as the runtime held it, whatever its type
foreign_from_at_a_known_type_test() ->
    %% at a signature's variable the help is the `foreign fn` alone: a
    %% regression test, the help opened with an annotation, which cannot fix it
    ?assertEqual({"the type a is not known whole here, and Foreign.term gives foreign code a"
                  " value by its type",
                  "a value of a type variable is given by a `foreign fn` whose parameter is of"
                  " that variable"},
                 refusal_and_help("fn give(x : a) : Foreign.Term = Foreign.term(x)")),
    ?assertEqual({"the type List(a) is not known whole here, and Foreign.term gives foreign code"
                  " a value by its type", "annotate the value where it is bound"},
                 refusal_and_help("fn give() : Foreign.Term = Foreign.term([])")),
    ?assertEqual("the type List(a) is not known whole here, and Foreign.term gives foreign code"
                 " a value by its type",
                 refusal("fn give(xs : List(a)) : Foreign.Term needs a.show = Foreign.term(xs)")),
    ?assertEqual("the type a is not known whole here, and Foreign.term gives foreign code a"
                 " value by its type",
                 refusal("fn give(xs : List(a)) : List(Foreign.Term) =\n"
                         "    List.map(xs, Foreign.term)")),
    ?assertEqual(ok, ok("fn give(xs : List(Int)) : List(Foreign.Term) =\n"
                        "    List.map(xs, Foreign.term)")),
    ?assertEqual(ok, ok("fn give(f : (Int) -> Int receiving e) : Foreign.Term = Foreign.term(f)")).

%% report §3.8, §3.10: a `Foreign` value has the runtime's exact equality,
%% directly or inside another value, whatever term foreign code made, a
%% function's among them. A regression test of the rule of 2026-10-01: the
%% checker refused `==` on `Foreign`
foreign_has_exact_equality_test() ->
    ?assertEqual(ok, ok("fn f(g : (Int) -> Int) = Foreign.term(g) == Foreign.term(g)")),
    ?assertEqual(ok, ok("fn eq(a, b) = a == b\nfn f() = eq([Foreign.term(1)], [Foreign.term(2)])")),
    ?assertEqual(ok, ok("fn f() = Foreign.toInt(Foreign.term(1)) == Some(1)")).

%% report §3.10: a variable with the equality constraint bound to a type
%% passes the constraint to the variables of that type, so an instance
%% that makes one of them a function is refused where it is made. A
%% regression test: `eq([x], [x])` gave `g` no constraint, and
%% `g(fn(y : Int) = y)` compared two functions.
equality_through_a_binding_test() ->
    Source = "fn eq(a, b) = a == b\nexport fn g(x) = eq([x], [x])\n",
    ?assertEqual("(Int) -> Int does not support equality (it contains a function, an address"
                 " or a reply), which g requires of its first argument",
                 refusal(Source ++ "fn h() = g(fn(y : Int) = y)")),
    ?assertEqual(ok, ok(Source ++ "fn h() = g(1)")),
    ?assertEqual("(a=) -> Bool", type_of(Source, g)).

%% report §3.10: a type's ordering is the `compare` in its own namespace; a
%% module-level `fn compare` is an ordinary function and gives the type no
%% ordering. A regression test: the checker conformed before it was
%% written. It does not cover a prelude type's namespace.
module_level_compare_gives_no_ordering_test() ->
    Source = "type D = D(Int)\nfn compare(D(a), D(b)) : Ordering = Int.compare(a, b)\n",
    ?assertEqual("`<` is not defined on D", refusal(Source ++ "fn f(x : D, y : D) = x < y")),
    ?assertEqual(ok, ok(Source ++ "fn f(x : D, y : D) : Ordering = compare(x, y)")).

%% report §3.10: a Map over a key without equality is refused at its first
%% operation, and the error names the key, not a comparison; a Set's element
%% alike; a type that names such a Map, in an annotation or a field, is no
%% error alone; a variable inside a key is constrained as one that is the
%% key. A regression test, written after the fix; it does not cover a
%% user function's own Map parameter instantiated at such a key, which
%% takes the same path.
map_key_equality_test() ->
    ?assertEqual("(Int) -> Int does not support equality (it contains a function, an address"
                 " or a reply), and a Map's key needs it",
                 refusal("fn f() = { let m : Map((Int) -> Int, Int) = Map.empty; m }")),
    ?assertEqual("Address(Int) does not support equality (it contains a function, an address"
                 " or a reply), which Set.put requires of a Set's element, in its second"
                 " argument; compare the processes behind addresses, `Process.fromAddress(a)`",
                 refusal("fn f(a : Address(Int)) = Set.put(Set.empty, a)")),
    ?assertEqual(ok, ok("type Box = Box(m : Map((Int) -> Int, Int))\n"
                        "fn f(m : Map((Int) -> Int, Int)) : Int = 1\n"
                        "fn g(b : Box) : Box = b")),
    ?assertEqual("(Map(#(k=, Int), v)) -> Map(#(k=, Int), v)",
                 type_of("export fn f(m : Map(#(k, Int), v)) : Map(#(k, Int), v) = m", f)),
    ?assertEqual("Address(Int) does not support equality (it contains a function, an address"
                 " or a reply), which f requires of a Map's key, in its first argument"
                 "; compare the processes behind addresses, `Process.fromAddress(a)`",
                 refusal("fn f(m : Map(#(k, Int), Int), key : k) = m\n"
                         "fn g(m : Map(#(Address(Int), Int), Int), a : Address(Int)) = f(m, a)")).

%%
%% Effects (report §3.9, §6.1)
%%

%% report §0, §3.9, §6.1: a function that receives names its mailbox in
%% its type, and one that does not, which may send and print, names none;
%% a callback that receives makes its caller receive
effects_test() ->
    ?assertEqual("() -> Unit", type_of("export fn main() = Io.println(\"x\")", main)),
    ?assertEqual("() -> Unit receiving Never",
                 type_of("export fn main() : Unit receiving Never = Io.println(\"x\")", main)),
    ?assertEqual(ok, ok("fn main() : Unit = Io.println(\"x\")")),
    ?assertEqual("() -> Address(a) receiving a", type_of("export fn me() = self()", me)),
    ?assertEqual("(Address(a), a) -> Unit", type_of("export fn wrap(a, v) = send(a, v)", wrap)),
    ?assertEqual("(Address(Int)) -> Unit",
                 type_of("export fn mark(a) = { kill(spawn(fn() = Unit)); send(a, 1) }", mark)),
    %% an effect used nowhere else is none
    ?assertEqual("(List(Int)) -> List(Int)",
                 type_of("export fn inc(xs) = List.map(xs, fn(x) = x + 1)", inc)),
    ?assertEqual("(List(String)) -> Unit",
                 type_of("export fn say(xs) = List.forEach(xs, fn(x) = Io.println(x))", say)),
    ?assertEqual("(List(Int)) -> Unit receiving e+",
                 type_of("export fn wait(xs) ="
                         " List.forEach(xs, fn(x) = receive { after x -> Unit })", wait)),
    ?assertEqual(ok, ok("type A = A\ntype B = B\n"
                        "fn ga() : Unit receiving A = receive { A -> Unit }\n"
                        "fn gb() : Unit receiving B = receive { B -> Unit }\n"
                        "fn ha() : Unit receiving A = ga()")),
    ?assertMatch({error, [_]}, ok("type A = A\ntype B = B\n"
                                  "fn ga() : Unit receiving A = receive { A -> Unit }\n"
                                  "fn gb() : Unit receiving B = receive { B -> Unit }\n"
                                  "fn both() = { ga(); gb() }")).

%% report §6.1, §6.3, §6.8, §7.2: a missing reply is `after` in receive; a
%% receive with only `after` makes its function process-only
receive_and_mailboxes_test() ->
    Counter = "type CounterMsg = Inc(Int) | Get(reply : Reply(Int))\n"
              "export fn counter(n : Int) : Unit receiving CounterMsg = receive {\n"
              "    Inc(k) -> counter(n + k)\n"
              "  | Get(reply = r) -> { answer(r, n); counter(n) }\n}",
    ?assertEqual("(Int) -> Unit receiving M.CounterMsg", type_of(Counter, counter)),
    ?assertEqual("`receive` needs a mailbox, and f receives nothing",
                 refusal("fn f() : Unit = receive { after 1 -> Unit }")),
    ?assertEqual(ok, ok("fn f() : Unit receiving Never = receive { after 1 -> Unit }")),
    %% an after-only receive, inferred, is process-only (a regression case,
    %% added after the checker conformed)
    ?assertEqual("(Int) -> Unit receiving e+",
                 type_of("export fn sleep(ms : Int) = receive { after ms -> Unit }", sleep)),
    ?assertEqual("sleep needs a mailbox, and p receives nothing",
                 refusal("fn sleep(ms : Int) = receive { after ms -> Unit }\n"
                         "fn p() : Unit = sleep(1)")),
    ?assertEqual("f is declared with mailbox Never and cannot receive",
                 refusal("fn f() : Unit receiving Never = receive { Unit -> Unit }")),
    ?assertEqual("(a) -> Unit receiving e+",
                 type_of("export fn tick(n) = { let m = receive { k -> k }; Unit }", tick)).

%% report §3.9: a `receive` whose patterns fix no type, a wildcard or a
%% variable nothing fixes, reads its process's mailbox at no type, so its
%% function is process-only, printed `+`, and stands neither as `adapted`'s
%% function nor in a guard, where a function receiving nothing is expected;
%% one whose pattern fixes the type is not, and a function receiving
%% nothing stands there. A regression test, written after the checker,
%% which did so before §3.9 named it; it does not cover a variable that
%% the clause's body fixes, whose function receives at that type
receive_fixing_no_type_test() ->
    ?assertEqual("() -> Unit receiving e+", type_of("export fn f() = receive { _ -> Unit }", f)),
    ?assertEqual("(Int) -> Int receiving e+",
                 type_of("export fn wait(n : Int) = receive { _ -> n }", wait)),
    ?assertEqual("() -> Unit receiving Int", type_of("export fn f() = receive { 1 -> Unit }", f)),
    Adapted = "export fn g() : Address(Int) receiving Int = adapted(self(), wait)\n",
    ?assertEqual("the argument does not fit adapted: a function that receives where one that"
                 " receives nothing is needed",
                 refusal("fn wait(n : Int) = receive { _ -> n }\n" ++ Adapted)),
    ?assertEqual(ok, ok("fn wait(n : Int) = n\n" ++ Adapted)),
    ?assertEqual({"ready needs a mailbox, and a guard receives nothing",
                  "compute the value before the match"},
                 refusal_and_help("fn ready() = receive { _ -> true }\n"
                                  "fn g() : Unit receiving Int ="
                                  " receive { n when ready() -> Unit }")).

%% report §3.9, §11.5: a wait alone makes a function process-only, a
%% `receive` that fixes no type, and a call of `self` or `monitor` does
%% not: where the function's type holds the address nowhere, its effect
%% variable stands in no value position, which a call binds to none, so
%% the type prints without it and a function that receives nothing calls
%% it, a guard and `adapted`'s function among them. `receiving m` over
%% such a body names the variable and `: T` lets it stand (report §4.5,
%% standing_over_a_body_that_calls_self_test); the two waits stay
%% process-only, through a call too, one whose variable is a value's among
%% them. A regression test of the sweep's finding (2026-10-24), written
%% after the code: `self` and `monitor` made their function process-only,
%% `fn f() = kill(self())` printing `receiving e+`; the runtime's tests
%% run such a function in a wrap and in an adapted address's function on
%% arrival
process_only_marks_a_wait_alone_test() ->
    Kill = "fn f() = kill(self())\n",
    ?assertEqual("() -> Unit", type_of("export " ++ Kill, f)),
    ?assertEqual("(Process) -> Unit",
                 type_of("export fn watch(p) = monitor(p, fn(d) = fault(\"down\"))", watch)),
    ?assertEqual(ok, ok(Kill ++ "fn g() : Unit = f()\n"
                        "fn h(n : Int) : Int = match n { k when f() == Unit -> k | _ -> 0 }\n"
                        "fn k() : Address(Int) receiving Int ="
                        " adapted(self(), fn(n : Int) = { f(); n })\n")),
    ?assertEqual("() -> Unit", type_of("export fn k() : Unit receiving m = kill(self())", k)),
    ?assertEqual("() -> Unit receiving e+",
                 type_of("export fn f() = { kill(self()); receive { after 1 -> Unit } }", f)),
    ?assertEqual("() -> Unit receiving e+",
                 type_of("export fn f() = { kill(self()); receive { _ -> Unit } }", f)),
    ?assertEqual("() -> Unit receiving e+",
                 type_of("fn w() = receive { x -> x }\n"
                         "export fn f() = { let _ = w(); Unit }\n", f)).

%% report §4.5, §3.9, §11.5: `: T` stands over a body that calls `self` or
%% `monitor`, or a function whose type holds their variable, where the
%% body neither waits nor has the variable in a value position of the
%% signature, so that the type the shell prints can be written. The
%% variable is read as the definition ends, and is refused in the words
%% and at the place a call that receives is refused at once: where a
%% parameter holds it, through a tuple, a record's field or a callback;
%% where the result does; where the body fixes it, through a block `let`,
%% a returned lambda or a wrap's result; and where an enclosing
%% definition holds it, a local fn's. A wait and a process-only callee are
%% refused at once, as before, and a parameter the body calls still
%% receives nothing. A regression test, written after the checker: it
%% does not cover a recursive group whose other member fixes the
%% variable, nor the shell's prompt, whose inputs are typed as a block's
%% statements are
standing_over_a_body_that_calls_self_test() ->
    ?assertEqual("() -> Unit", type_of("export fn k() : Unit = kill(self())", k)),
    ?assertEqual("() -> Unit",
                 type_of("fn me() = self()\nexport fn k() : Unit = { let _ = me(); Unit }\n",
                         k)),
    ?assertEqual("(Process) -> Unit",
                 type_of("export fn watch(p : Process) : Unit ="
                         " monitor(p, fn(d) = fault(\"down\"))", watch)),
    ?assertEqual("() -> Unit",
                 type_of("export fn f() : Unit = { fn g() = self(); kill(g()) }", f)),
    ?assertEqual("() -> Unit",
                 type_of("export fn f() : Unit = (fn() = kill(self()))()", f)),
    ?assertEqual("() -> () -> Unit",
                 type_of("export fn f() : (() -> Unit) = { let a = self(); fn() = kill(a) }",
                         f)),
    %% a spawned function's mailbox type nothing fixed is Never after the
    %% variable is read, as it is without the annotation
    ?assertEqual("() -> Unit",
                 type_of("export fn f() : Unit = {"
                         " let p = spawn(fn() = Unit); kill(if true then p else self()) }", f)),
    Refused = "self needs a mailbox, and f receives nothing",
    ?assertEqual(Refused, refusal("fn f(x) : Unit = send(self(), x)")),
    ?assertEqual(Refused, refusal("fn f(t) : Unit = match t { #(x, _) -> send(self(), x) }")),
    ?assertEqual(Refused, refusal("type Box(a) = Box(a : a)\n"
                                  "fn f(b) : Unit = match b { Box(a = x) -> send(self(), x) }")),
    ?assertEqual(Refused, refusal("fn f(cb) : Unit = cb(self())")),
    ?assertEqual(Refused, refusal("fn f() : Address(m) = self()")),
    ?assertEqual(Refused, refusal("fn f() : Unit = send(self(), 5)")),
    ?assertEqual(Refused, refusal("fn f() : Unit = { let a = self(); send(a, 5) }")),
    ?assertEqual(Refused, refusal("fn f() : (() -> Address(Int)) = { let a = self(); fn() = a }")),
    ?assertEqual(Refused, refusal("fn f() : Unit = {"
                                  " let a = self(); fn g(x) : Unit = send(a, x); g(5) }")),
    ?assertEqual("monitor needs a mailbox, and f receives nothing",
                 refusal("fn f(p : Process) : Unit = monitor(p, fn(d) = 5)")),
    ?assertEqual("self needs a mailbox, and inner receives nothing",
                 refusal("fn outer(x) = { fn inner() : Unit = send(self(), x); inner() }")),
    %% the refusal stands at the call, the annotation labeled
    Late = diagnostic("fn f() : Unit = { let a = self(); send(a, 5) }\n"),
    ?assertEqual({1, 27, {1, 33}}, Late#diagnostic.span),
    ?assertEqual([{{1, 10, {1, 14}},
                   "`: Unit` without `receiving` declares that f receives nothing"}],
                 Late#diagnostic.labels),
    ?assertEqual("give f its mailbox type with `receiving`", Late#diagnostic.help),
    ?assertEqual("`receive` needs a mailbox, and f receives nothing",
                 refusal("fn f() : Unit = { kill(self()); receive { after 1 -> Unit } }")),
    ?assertEqual("w needs a mailbox, and f receives nothing",
                 refusal("fn w() = receive { x -> x }\nfn f() : Unit = { let _ = w(); Unit }")),
    ?assertEqual("((a) -> Int, a) -> Int", type_of("export fn apply(f, x) : Int = f(x)", apply)),
    %% a lambda's `: T` and a guard are no `fn` declaration's
    ?assertEqual("self needs a mailbox, and the lambda receives nothing",
                 refusal("fn f() = (fn() : Unit = kill(self()))()")),
    ?assertEqual("self needs a mailbox, and a guard receives nothing",
                 refusal("fn f(n : Int) : Int receiving Int ="
                         " match n { k when kill(self()) == Unit -> k | _ -> 0 }")).

%% report §6.2, §4.6
spawn_test() ->
    ?assertEqual(ok, ok("fn work() : Unit = Unit\n"
                        "fn main() : Unit = { let _ = spawn(fn() = work());"
                        " Unit }")),
    %% a callback written without `receiving` is spawned as any function
    %% that receives nothing is (report §3.9)
    ?assertEqual(ok, ok("fn main() : Unit = {"
                        " let _ = spawn(fn() : Unit = Unit); Unit }")),
    %% an address nothing sends to keeps its mailbox type open (report §4.6)
    ?assertEqual(ok, ok("fn work() = Unit\n"
                        "fn main() : Unit = { let a = spawn(fn() = work());"
                        " Unit }")).

%% report §4.5, §3.9, §11.5: a result annotation without `receiving` on an
%% effect-polymorphic function makes its callback one that receives
%% nothing, and the error names the side that receives: a function that
%% receives passed where one that receives nothing is needed; in a
%% parameter's parameter the two swap, since there the callee hands the
%% function over. One that receives nothing passed where one that receives
%% is needed is no error since the cold read's 1.1. A regression test,
%% written after the fix; it does not cover a result's function, nor the
%% shell's rendering of the message.
effect_mismatch_direction_test() ->
    ?assertEqual("the argument does not fit apply: a function that receives where one that"
                 " receives nothing is needed",
                 refusal("fn apply(f, x) : Int = f(x)\n"
                         "fn g() : Int receiving m ="
                         " apply(fn(y) = receive { after 1 -> y }, 1)")),
    ?assertEqual("the value does not have the declared type: a function that receives where one"
                 " that receives nothing is needed",
                 refusal("fn g() : Int receiving m = {"
                         " let k : (Int) -> Int = fn(y) = receive { after 1 -> y }; k(1) }")),
    %% h hands k a function that receives, and k's parameter must receive
    %% nothing
    ?assertEqual("the argument does not fit h: a function that receives where one that"
                 " receives nothing is needed",
                 refusal("fn h(k : ((Int) -> Int receiving m) -> Int) : Int receiving m ="
                         " { receive { after 1 -> Unit }; k(fn(x) = x) }\n"
                         "fn g() : Int receiving n = h(fn(f : (Int) -> Int) : Int = f(1))")),
    ?assertEqual(ok, ok("fn apply(f, x) : Int = f(x)\nfn g() : Int = apply(fn(y) = y + 1, 1)")).

%% report §5.9: a guard receives nothing, and may send and print
guards_receive_nothing_test() ->
    ?assertEqual(ok, ok("fn f(n : Int) = match n { k when k > 0 -> 1 | _ -> 0 }")),
    ?assertMatch("a guard is a Bool: " ++ _,
                 refusal("fn f(n : Int) = match n { k when k -> 1 | _ -> 0 }")),
    ?assertEqual(ok, ok("fn f(n : Int) : Int = match n {"
                        " k when Io.println(\"x\") == Unit -> 1 | _ -> 0 }")),
    ?assertEqual("wait needs a mailbox, and a guard receives nothing",
                 refusal("fn wait() : Bool receiving m = receive { after 1 -> true }\n"
                         "fn f(n : Int) : Int receiving Never = match n {"
                         " k when wait() -> 1 | _ -> 0 }")).

%%
%% Patterns and blocks
%%

%% report §5.10, §11.5: a name after `as` binds as a variable does, so one
%% bound twice through it is refused at the second. A regression test: the
%% checker crashed looking for two variables
as_binds_twice_test() ->
    ?assertEqual("variable x appears twice in the pattern", refusal("fn f(x as x) : Int = x")),
    ?assertEqual("variable a appears twice in the pattern",
                 refusal("fn g(p : #(Int, Int)) : Int = match p { #(a, b) as a -> a }")).

%% report §5.10, §11.5: a name bound twice, the first time after `as`, is
%% refused at the second and labels the first. A regression test, found by
%% the independent read of MVP 2.99b's item 7: the name after `as` kept its
%% token's position where every other node keeps a span, so the two sorted
%% the wrong way, and the error stood at the first `b` labeling the second
as_binds_first_test() ->
    Diagnostic = diagnostic("fn f(p : #(Int, Int)) : Int = match p { #(a as b, b) -> a }"),
    ?assertMatch(#diagnostic{span = {1, 51, {1, 52}}, labels = [{{1, 48, {1, 49}}, _}]},
                 Diagnostic).

%% report §3.4, §11.5: a function of the wrong arity is named with its own
%% count first and the expected one after. A regression test, found by the
%% independent read of MVP 2.99b's item 7: the two counts were printed the
%% other way round, a function of one argument passed where two were
%% expected reading "a function of 2 arguments where one of 1 was expected"
arity_mismatch_named_test() ->
    Diagnostic = diagnostic("fn apply2(f : (Int, Int) -> Int) : Int = f(1, 2)\n"
                            "fn one(x : Int) : Int = x\n"
                            "fn main() : Int = apply2(one)\n"),
    ?assertNotEqual(nomatch, string:find(Diagnostic#diagnostic.message,
                                         "a function of 1 argument where one of 2 was expected")).

%% report §5.10
patterns_test() ->
    ?assertEqual("variable x appears twice in the pattern",
                 refusal("fn f(p) = match p { #(x, x) -> x }")),
    ?assertEqual("a `let` pattern must be irrefutable",
                 refusal("fn f(o) = { let Some(x) = o; x }")),
    ?assertEqual(ok, ok("type P = P(x : Int, y : Int)\nfn f(p) = { let P(x = a) = p; a }")),
    ?assertEqual("a parameter pattern must be irrefutable", refusal("fn f(Some(x)) = x")),
    ?assertEqual("(M.P) -> Int",
                 type_of("export type P = P(x : Int, y : Int)\n"
                         "export fn getX(P(x = v) : P) = v", getX)),
    ?assertEqual("Get has no field bogus",
                 refusal("type R = Get(reply : Int)\nfn f(r) = match r { Get(bogus = b) -> b }")).

%% report §4.6, §5.4: a block binding's variable that nothing pins stays
%% free; List.size does not pin the element type, and :: does. A
%% regression test: such a binding was refused
blocks_test() ->
    ?assertEqual("() -> Int", type_of("export fn f() = { let xs = []; 1 }", f)),
    ?assertEqual("() -> Int", type_of("export fn f() = { let xs = []; List.size(xs) + 1 }", f)),
    ?assertEqual(ok, ok("fn f() = { let m = Map.empty; let o = None; Map.size(m) }")),
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
                 refusal("fn f(n : Int) = { fn g(x) = x * k; let k = 2; g(n) }")).

%% report §4.5, §4.6: a binding does not see its own name, so a lambda bound
%% by `let` does not call itself, and a local `fn` does. A regression test,
%% written when §4.6 said so
let_lambda_does_not_recur_test() ->
    ?assertEqual("unknown name count",
                 refusal("fn f() : Int = { let count = fn(n : Int) : Int ="
                         " if n == 0 then 0 else count(n - 1); count(3) }")),
    ?assertEqual(ok, ok("fn f() : Int = { fn count(n : Int) : Int ="
                        " if n == 0 then 0 else count(n - 1); count(3) }")).

%% report §4.5
local_fn_names_are_plain_test() ->
    ?assertEqual("a member, `fn T.compare`, is a top-level form; a local function has a"
                 " plain name",
                 refusal("type T = T\nfn f() = {"
                         " fn T.compare(a : T, b : T) : Ordering = Equal; 2 }")).

%% report §5.4, §11.5: an expression that is not a block's last statement
%% has type Unit, so an Either an error would ride on is not dropped unseen;
%% `let _ =` discards on purpose, and a statement of any Unit type passes
statement_is_unit_test() ->
    Check = "fn check(n : Int) : Either(String, Int) =\n"
            "    if n > 0 then Right(n) else Left(\"neg\")\n",
    ?assertEqual("this statement's value is discarded: expected Unit,"
                 " found Either(String, Int)",
                 refusal(Check ++ "fn f() = { check(-1); 1 }")),
    {error, [#diagnostic{help = Help} | _]} = check(Check ++ "fn f() = { check(-1); 1 }"),
    ?assertEqual("`let _ = ...` discards it on purpose", Help),
    ?assertEqual(ok, ok(Check ++ "fn f() = { let _ = check(-1); 1 }")),
    ?assertEqual(ok, ok("fn f(a : Address(Int)) : Int = { send(a, 1); 2 }")),
    %% a statement whose type is still open is settled at Unit
    ?assertEqual(ok, ok("fn f() : Int = { fault(\"later\"); 1 }")).

%% report §5.4
local_fn_forward_reference_test() ->
    %% a is generalized only after b, which it references, is checked
    ?assertEqual("the argument does not fit a: expected Int, found String",
                 refusal("fn f() = { fn a(x) = b(x); fn b(x) = x + 1; a(\"s\") }")),
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
                 refusal("fn f(n : Int) = { let a = g(n); let k = 2; fn g(x) = x * k; a }")),
    ?assertEqual("local function h is used before `let k`, which it references",
                 refusal("fn f(n : Int) = { fn h(x) = g(x); let a = h(n); let k = 2;"
                         " fn g(x) = x * k; a }")),
    ?assertEqual("local function g is used before `let k`, which it references",
                 refusal("fn f(n : Int) = { let a = List.map([n], g); let k = 2; fn g(x) = x * k;"
                         " a }")),
    ?assertEqual(ok, ok("fn f(n : Int) = { let k = 2; let a = g(n); fn g(x) = x * k; a }")),
    ?assertEqual(ok, ok("fn f(n : Int) = { fn g(x) = x * 2; let a = g(n); let k = 2; a + k }")).

%% report §5.5
bind_arrow_test() ->
    Opt = "export fn parseAndAdd(a : String, b : String) : Optional(Int) = {\n"
          "    let x <- String.toInt(a);\n    let y <- String.toInt(b);\n    Some(x + y)\n}",
    ?assertEqual("(String, String) -> Optional(Int)", type_of(Opt, parseAndAdd)),
    Either = "export fn positiveInt(text : String) : Either(String, Int) = {\n"
             "    let n <- Either.fromOptional(String.toInt(text), \"not an integer\");\n"
             "    if n > 0 then Right(n) else Left(\"not positive\")\n}",
    ?assertEqual("(String) -> Either(String, Int)", type_of(Either, positiveInt)),
    %% inferred from the block's type when e is not yet known
    ?assertEqual("(a) -> Either(String, Int)",
                 type_of("export fn f(n) : Either(String, Int) = { let x <- g(n); Right(x + 1) }\n"
                         "fn g(n) = f(n)", f)),
    ?assertMatch("the value of `<-` must have the block's sum type: expected Either(a, Int),"
                 " found Optional(Int)",
                 refusal("fn f(a : String) = { let x <- String.toInt(a); Right(x) }")),
    ?assertMatch("`<-` needs an Either or an Optional, not Int",
                 refusal("fn f() = { let x <- 1; x }")).

%% report §11.5: a callee's type in the label at its call is printed as its
%% declaration writes it, under its own variable names, and a field's in a
%% fill's label under its type's parameter names. A regression test: each
%% label printed a fresh instance, `t` as `a` and `m` as `e`
declared_names_in_labels_test() ->
    #diagnostic{labels = CallLabels} =
        diagnostic("fn g(x : Int, y : t) : t receiving m = {\n"
                   "    receive { after 1 -> Unit };\n    y\n}\n"
                   "fn f() : Unit receiving Int = g(\"x\", Unit)\n"),
    ?assertMatch([{_, "g : (Int, t) -> t receiving m+"}], CallLabels),
    #diagnostic{labels = FillLabels} =
        diagnostic("type Ops(s) = Ops(size : (s) -> Bool)\n"
                   "fn f() : Ops(Set(Int)) = Ops(..Set)\n"),
    ?assertMatch([{_, "Ops declares size : (s) -> Bool"}], FillLabels).

%% report §11.5, §3.5, §4.8: a deferred mismatch labels the later use that
%% fixed the operand type, beside the annotation. A regression test: the
%% found type had no visible source; it does not cover a type fixed by a
%% unification that cannot fail, as a first branch's
settled_operand_labeled_test() ->
    #diagnostic{labels = SelectionLabels} =
        diagnostic("type Point = Point(x : Int)\n"
                   "fn f(p) : String = {\n    let s : String = p.x;\n    let q : Point = p;\n"
                   "    s\n}\n"),
    ?assertMatch([{_, "declared String here"},
                  {{4, 21, _}, "this fixes the value whose x is read as Point"}],
                 SelectionLabels),
    #diagnostic{labels = OperatorLabels} =
        diagnostic("fn g(a, b) : Int = {\n    let s : String = a + b;\n    let n : Int = b;\n"
                   "    n\n}\n"),
    ?assertMatch([{_, "declared String here"}, {{3, 19, _}, "this fixes `+`'s operands as Int"}],
                 OperatorLabels).

%% report §11.5, §5.5: a `<-` whose value's sum type is known where it
%% stands is checked there, so that its error stops the block, before a
%% later statement's error hides it or a later use settles the types it
%% prints. A regression test: a later error was reported alone, and the
%% pattern's mismatch printed a type a later line had settled. It does not
%% cover a `<-` whose sum type is open, which waits for the end of the
%% definition as before
bind_arrow_checked_where_it_stands_test() ->
    ?assertEqual(["`<-` needs an Either or an Optional, not Int"],
                 refusals("fn f() : Optional(Int) = {\n    let x <- 1;\n"
                          "    let z : String = 2;\n    Some(x)\n}")),
    ?assertEqual(["the pattern does not fit the value inside the sum type: expected Int,"
                  " found #(a, b)"],
                 refusals("fn f(o : Optional(Int)) : Optional(Int) = {\n    let #(a, b) <- o;\n"
                          "    let z : String = a;\n    Some(1)\n}")).

%% report §5.5: `<-` over a value whose sum type nothing decides asks for an
%% annotation; its pattern is irrefutable, as `let`'s is, so a constructor
%% pattern is refused and a tuple accepted. A regression test: the checker
%% conformed before it was written. It does not cover an Either.
bind_arrow_open_sum_and_pattern_test() ->
    ?assertEqual("`<-` needs to know whether the value is an Either or an Optional; annotate it",
                 refusal("fn g(x) = { let a <- x; x }")),
    ?assertEqual("a `let` pattern must be irrefutable",
                 refusal("fn f(x : Optional(Optional(Int))) : Optional(Int) ="
                         " { let Some(y) <- x; y }")),
    ?assertEqual(ok, ok("fn f(x : Optional(#(Int, Int))) : Optional(Int) ="
                        " { let #(a, b) <- x; Some(a + b) }")).

%%
%% Types and declarations
%%

%% report §4.5, §11.5: two fns of one name in a row are told they are one
%% function written as clauses, at the second with the first labeled, at
%% the top and in a block; moved from the parser's tests in MVP 2.99c item
%% 1, when the parser came to read them as Appendix A does
two_clause_function_test() ->
    ?assertEqual({"a function has one clause", "write one clause whose body is a `match`"},
                 refusal_and_help("fn f(0) = 1\nfn f(n) = n")),
    ?assertEqual("a function has one clause",
                 refusal("fn g() : Int = { fn f(0) = 1; fn f(n) = n; f(1) }")),
    %% apart, they are one name declared twice
    ?assertEqual("value f is declared twice", refusal("fn f() = 1\nlet x = 2\nfn f() = 3")).

%% report §5.6, Appendix A: a constructor's empty parentheses are a call of
%% its value, which is no function where it has no fields, and two
%% arguments are one too many for a positional field; moved from the
%% parser's tests in MVP 2.99c item 1
constructor_called_test() ->
    ?assertEqual({"empty parentheses after None",
                  "a constructor without fields is written without parentheses, None"},
                 refusal_and_help("fn f() : Optional(Int) = None()")),
    ?assertEqual("Some takes 1 argument, not 2", refusal("fn f() : Optional(Int) = Some(1, 2)")),
    ?assertEqual("Snap has named fields; write Snap(a = value)",
                 refusal("type Snap = Snap(a : Int)\nfn f() : Snap = Snap()")).

%% report §3.5, §4.9: a declaration with a requirement binds no name that is
%% one of its type variables, a parameter, a pattern's, a let's, a local
%% fn's, in a lambda too; moved from the parser's tests in MVP 2.99c item 1
requirement_binds_no_type_variable_test() ->
    Message = "`a` names a type variable of the signature, and a declaration with a requirement"
              " binds no name that is one of its type variables",
    ?assertEqual({Message, "rename the binding; a.compare names the member of a's type"},
                 refusal_and_help("fn f(a : a) : a needs a.compare = a")),
    ?assertEqual(Message, refusal("fn f(x : a) : a needs a.compare = { let a = x; a }")),
    ?assertEqual(Message, refusal("fn f(x : a) : a needs a.compare = match x { a -> a }")),
    ?assertEqual(Message, refusal("fn f(x : a) : a needs a.compare = (fn(a) = a)(x)")),
    ?assertEqual(Message, refusal("fn f(x : a) : a needs a.compare = { fn a() = x; a() }")),
    %% without a requirement, a name may be one
    ok = ok("fn f(a : a) : a = a").

%% report §4.3, §4.7: a type's parameters are distinct, a foreign type's too
type_parameters_distinct_test() ->
    ?assertEqual("type variable a appears twice among the parameters of Pair",
                 refusal("type Pair(a, a) = Pair(a)")),
    ?assertEqual("type variable a appears twice among the parameters of Stack",
                 refusal("abstract type Stack(a, a) = Stack(List(a))")),
    ?assertEqual("type variable k appears twice among the parameters of Table",
                 refusal("foreign type Table(k=, k)")),
    %% the second underlined, the first labeled: a regression test, the
    %% declaration was underlined whole
    ?assertMatch(#diagnostic{span = {1, 14, _}, labels = [{{1, 11, _}, "first written here"}]},
                 diagnostic("type Pair(a, a) = Pair(a)")).

%% report §3.5, §3.9, §4.2, §4.3
type_declarations_test() ->
    ?assertEqual("type T is declared twice", refusal("type T = A\ntype T = B")),
    ?assertEqual("constructor A is declared twice", refusal("type T = A\ntype U = A")),
    ?assertEqual("value f is declared twice", refusal("fn f() = 1\nlet f = 2")),
    ?assertEqual("type variable b is not a parameter of the type", refusal("type T(a) = T(b)")),
    ?assertEqual("unknown type Nope", refusal("fn f(x : Nope) = x")),
    ?assertEqual("List takes 1 type argument, not 2", refusal("fn f(x : List(Int, Int)) = x")),
    %% prelude names may be shadowed (report §4.2)
    ?assertEqual("(M.Key) -> Bool",
                 type_of("export type Key = Up | Less\nexport fn isLess(k) = match k"
                         " { Less -> true"
                         " | Up -> false }", isLess)),
    ?assertEqual("field a is declared twice",
                 refusal("type T = T(a : Int, a : Int)")).

%% report §3.1: there are no type aliases, so a constructor named as a type
%% in scope other than its own is refused at the constructor, a prelude
%% type, one the module declares, one of the session's at the prompt
%% (§11.2), and one with a field alike; a constructor named as its own type
%% is not. A regression test of the principles review's W8 (2026-10-09):
%% `type Word = String` declared a constructor `String` and was accepted
no_alias_test() ->
    ?assertEqual({"constructor String is named as the type String",
                  "there are no type aliases (report §3.1)"},
                 refusal_and_help("type Word = String")),
    ?assertMatch({error, [#diagnostic{span = {1, 13, _}}]}, check("type Word = String")),
    ?assertEqual("constructor List is named as the type List",
                 refusal("type Numbers = List(Int)")),
    ?assertEqual("constructor Down is named as the type Down",
                 refusal("type Key = Up | Down")),
    ?assertEqual("constructor Shape is named as the type Shape",
                 refusal("type Shape = Circle(Float)\ntype Drawing = Shape(Int) | Empty")),
    ?assertEqual("constructor Point is named as the type Point",
                 refusal("type Thing = Point\nforeign type Point")),
    ?assertMatch({ok, _, _, _}, check("type Path = Path(String)\ntype Word = Word(String)")),
    {ok, _, Interface, _} = ern_typecheck:check_string(['Session1'],
                                                       "export type Shape = Circle(Float)"),
    {ok, Declarations} = ern_parser:parse_string("type Drawing = Shape(Int)"),
    Session = #{types => #{'Shape' => ['Session1', 'Shape']}},
    ?assertMatch({error, [#diagnostic{message = "constructor Shape is named as the type Shape"}]},
                 ern_typecheck:check(['M'], Declarations, [Interface], Session)).

%% report §4.2, §5.4: a module declares each top-level name once, private or
%% exported, and a block each local fn name once; two adjacent ones are the
%% parser's "one clause" error (ern_parser_tests). The top-level half is a
%% regression test, written after the checker conformed; the local half
%% was fixed with it, since two local fns of one name apart in a block were
%% accepted. It does not cover a local fn and a `let` of one name.
declared_once_test() ->
    ?assertEqual("value f is declared twice", refusal("fn f() = 1\nfn g() = 3\nfn f() = 2")),
    ?assertEqual("local function g is declared twice in the block",
                 refusal("fn h() = { fn g() = 1; let x = 1; fn g() = 2; g() + x }")),
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
    ?assertEqual(Scope, refusal("fn f(g : Int) : Int = { fn g() : Int = 1; g() }")),
    ?assertEqual(Scope, refusal("fn f() : Int = { let g = 1; fn g() : Int = 2; g() }")),
    ?assertEqual(Scope,
                 refusal("fn f(x : Int) : Int = match x { g -> { fn g() : Int = 2; g() } }")),
    ?assertEqual(Scope, refusal("fn f(p : #(Int, Int)) : Int = {"
                                " let #(a, g) = p; fn g() : Int = a; g() }")),
    ?assertEqual(Scope, refusal("fn f() : Int ="
                                " { let h = fn(g : Int) : Int = { fn g() : Int = 2; g() };"
                                " h(1) }")),
    ?assertEqual(Scope, refusal("let k = fn(g : Int) : Int = { fn g() : Int = 2; g() }")),
    ?assertEqual(Scope, refusal("fn f(g : Int) : Int = { fn h() : Int = { fn g() : Int = 1; g() };"
                                " h() }")),
    ?assertEqual("local function g has the name of a `let` of its block",
                 refusal("fn f() : Int = { fn g() : Int = 2; let g = 1; g }")),
    Diagnostic = diagnostic("fn f(g : Int) : Int = { fn g() : Int = 1; g() }"),
    ?assertEqual([{{1, 6, {1, 7}}, "g is bound here"}], Diagnostic#diagnostic.labels),
    ?assertEqual("rename the function or the variable", Diagnostic#diagnostic.help),
    ?assertEqual(ok, ok("fn g() : Int = 1\nfn f() : Int = { fn g() : Int = 2; g() }")),
    ?assertEqual(ok, ok("fn f() : Int ="
                        " { let x = { let g = 1; g }; fn g() : Int = 2; g() + x }")),
    ?assertEqual(ok, ok("fn f(x : Int) : Int = { fn g(g : Int) : Int = g; g(x) }")).

%% report §3.9
annotations_are_rigid_test() ->
    ?assertEqual("the body does not have the declared result type: expected a, found Int",
                 refusal("fn f(x : a) : a = 1")),
    ?assertEqual("the body does not have the declared result type: expected a, found b",
                 refusal("fn f(x : a, y : b) : a = y")),
    ?assertEqual("(a) -> a", type_of("export fn id(x : a) : a = x", id)),
    ?assertMatch("the body does not have the declared result type: " ++ _,
                 refusal("fn f(x : Int) : String = x")).

%% report §3.9: a local fn's signature shares the enclosing signature's
%% variables, rigid there; a variable named only in it is the local fn's
%% own, rigid and generalized with it. The local fn's `a` was its own, so
%% `inner(1)` was accepted where the enclosing `a` is not Int.
local_fn_signature_shares_variables_test() ->
    ?assertEqual("(a) -> a",
                 type_of("export fn outer(x : a) : a = { fn inner(y : a) : a = y; inner(x) }",
                         outer)),
    ?assertEqual("the argument does not fit inner: expected a, found Int",
                 refusal("fn outer(x : a) : a = { fn inner(y : a) : a = y; inner(1) }")),
    ?assertEqual("the argument does not fit inner: expected a, found Int",
                 refusal("fn outer(x : a) : Int = { fn inner(y : a) : a = y; inner(1) }")),
    ?assertEqual("(a) -> a",
                 type_of("export fn outer(x : a) : a ="
                         " { fn id(y : b) : b = y; let _ = id(1); id(x) }", outer)),
    ?assertEqual("the body does not have the declared result type: expected b, found a",
                 refusal("fn outer(x : a) : a = { fn g(y : b) : b = x; x }")),
    ?assertEqual("the body does not have the declared result type: expected b, found Int",
                 refusal("fn outer(x : a) : a = { fn g(y : b) : b = 1; x }")).

%% report §3.9: polymorphic recursion is refused, even under a full
%% signature, the message naming the rule and §11.5's help line the fix, a
%% second function, at a top-level and a
%% local definition's recursive call alike, and at no other call. A
%% regression test: the checker conformed before it was written; the help
%% line, of 2026-10-01, is its own. It does not cover a mutually recursive
%% group.
polymorphic_recursion_is_refused_test() ->
    Help = "declare a second function for the call at another type",
    %% report §11.5: at the recursive call's argument, as any call is;
    %% §3.9's rule for a recursive group refuses the type that once
    %% exercised this, so a list does
    ?assertEqual({"the argument of a recursive call does not fit depth at its own type"
                  " (report §3.9): a type that would contain itself (a against List(a))", Help},
                 refusal_and_help("fn depth(x : a) : Int = 1 + depth([x])")),
    ?assertEqual({"the argument of a recursive call does not fit both at its own type"
                  " (report §3.9): expected a, found Bool", Help},
                 refusal_and_help("fn f() : Int = {\n"
                                  "    fn both(x : a, n : Int) : Int ="
                                  " if n == 0 then 0 else both(true, n - 1);\n"
                                  "    both(1, 1)\n}")),
    ?assertEqual({"the argument does not fit g: expected Int, found Bool", undefined},
                 refusal_and_help("fn twice(g, n : Int) = { let _ = g(n); g(true) }")).

%% report §3.9, §4.6: a signature's type variables reach a block `let`'s
%% annotation, `=` and `<-` alike, and stay rigid there; a variable named
%% only in a block `let` means every type, which a binding that is not
%% generalized cannot hold; a `let` of a lambda is generalized, and its
%% lambda's variables are rigid and reach the lambda's body. A regression
%% test; it does not cover a local `fn`'s own signature, which starts a
%% definition of its own.
block_let_annotation_variables_test() ->
    ?assertEqual("the value does not have the declared type: expected a, found Int",
                 refusal("fn f(x : a) : Int = { let y : a = 1; y }")),
    ?assertEqual("the pattern does not fit the value inside the sum type: expected Int, found a",
                 refusal("fn f(x : Optional(a), n : Int) : Optional(Int) ="
                         " { let y : a <- Some(n); Some(y) }")),
    ?assertEqual("(a) -> a", type_of("export fn f(x : a) : a = { let y : a = x; y }", f)),
    ?assertEqual("type variable a in the annotation means every type, and a `let` in a block"
                 " is generalized only over a lambda",
                 refusal("fn f(x : Int) : Int = { let y : a = x; y }")),
    %% the lambda's own b is rigid, and the one the inner `let` names
    ?assertEqual(ok, ok("fn f(x : Int) : Int ="
                        " { let g = fn(y : b) : b = { let z : b = y; z }; g(x) }")),
    ?assertEqual("the value does not have the declared type: expected b, found String",
                 refusal("fn f(x : Int) : Int ="
                         " { let g = fn(y : b) : b = { let z : b = \"s\"; z }; g(x) }")).

%% report §3.4
with_binds_to_the_nearest_arrow_test() ->
    ?assertEqual("(Int) -> (Int) -> Int receiving Never",
                 type_of("export fn f(a : Int) : (Int) -> Int receiving Never = fn(b) = a + b", f)),
    ?assertEqual("(Int) -> ((Int) -> Int) receiving Never",
                 type_of("export fn f(a : Int) : ((Int) -> Int) receiving Never = fn(b) = a + b",
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
                 refusal(Shape ++ "fn f(s : Shape) ="
                         " match s { Circle(n) or Dot -> n | Square(_) -> 0 }")),
    ?assertEqual("the alternatives of a clause bind different variables: `m` is bound by this"
                 " alternative and not by the first",
                 refusal(Shape ++ "fn f(s : Shape) ="
                         " match s { Dot or Square(m) -> 1 | Circle(_) -> 0 }")),
    [TypeError | _] =
        refusals("fn f(e : Either(Int, String)) = match e { Left(x) or Right(x) -> 1 }"),
    ?assertMatch({match, _}, re:run(TypeError, "the alternatives bind `x` at one type")),
    ?assertEqual(ok, ok("fn f(e : Either(Int, Int)) = match e { Left(n) or Right(n) -> n }")),
    [Cover | _] = refusals("fn f(o : Optional(Int)) = match o { Some(1) or Some(2) -> 1 }"),
    ?assertMatch({match, _}, re:run(Cover, "^match on Optional")).

%% report §5.9, §5.10: `or` stands between a clause's whole patterns and
%% `as` names what one of them matches, so each alternative names the value
%% itself, which the refusal's help says. A regression test, written when
%% §5.10 was made to agree with Appendix A
as_in_each_alternative_test() ->
    ?assertEqual(ok, ok("fn f(o : Optional(Int)) : Optional(Int) ="
                        " match o { Some(1) as x or Some(2) as x -> x | _ -> None }")),
    {error, [#diagnostic{message = Message, help = Help} | _]} =
        check("fn f(o : Optional(Int)) : Optional(Int) ="
              " match o { Some(1) or Some(2) as x -> x | _ -> None }"),
    ?assertEqual("the alternatives of a clause bind different variables: `x` is bound by this"
                 " alternative and not by the first", Message),
    ?assertEqual("bind each name in every alternative, as `Some(1) as x or Some(2) as x`", Help).

%% report §8.5
let_cycle_test() ->
    ?assertEqual("the initializer of a depends on itself, through b",
                 refusal("let a : Int = b\nlet b : Int = a")),
    ?assertEqual("the initializer of a depends on itself, through f",
                 refusal("let a : Int = f()\nfn f() : Int = a")),
    ?assertEqual("the initializer of a depends on itself", refusal("let a : Int = a")),
    ?assertEqual(ok, ok("let a : Int = b + 1\nlet b : Int = 1")),
    %% through an operator's member (report §4.8)
    ?assertEqual("the initializer of x depends on itself, through Vec.+, y",
                 refusal("export type Vec = Vec(Int)\nlet x = Vec(1) + Vec(2)\nlet y = x\n"
                         "export fn Vec.+(Vec(a), Vec(b)) : Vec ="
                         " { let Vec(c) = y; Vec(a + b + c) }")),
    %% two independent cycles are two errors
    ?assertEqual(["the initializer of a depends on itself",
                  "the initializer of b depends on itself"],
                 refusals("let a : Int = a\nlet b : Int = b")).

%% report §8.5: a binding depends on what every function it names depends
%% on, called or not, and a lambda's body is part of its initializer. A
%% regression test: the checker conformed before it was written.
let_cycle_through_a_named_function_test() ->
    ?assertEqual("the initializer of handlers depends on itself, through f",
                 refusal("let handlers = [f]\nfn f() : Int = List.size(handlers)\n")),
    ?assertEqual(["the initializer of a depends on itself"], refusals("let a = fn() = a\n")),
    ?assertEqual(["the initializer of a depends on itself"],
                 refusals("let a : () -> Int = fn() : Int = a()\n")).

%% report §11.5: a declaration whose check failed is used at the type its
%% signature states, so that no error at a use follows from its own. A
%% regression test: `Io.show` of its result was refused as not known whole;
%% it does not cover a signature itself in error
failed_declaration_keeps_its_signature_test() ->
    ?assertEqual(["fromList needs a.compare, which unique does not declare"],
                 refusals("fn unique(list : List(a)) : List(a) =\n"
                          "    OrderedSet.toList(OrderedSet.fromList(list))\n"
                          "fn f() : String = Io.show(unique([\"b\", \"a\"]))\n")).

%% report §3.9, §11.5: an unannotated fn's body is checked against the
%% result type its uses gave it, an earlier use's, a group member's or the
%% body's own recursive one, and a body that disagrees is a mismatch. A
%% regression test: each crashed the checker, which took the result type
%% for a fresh variable
unannotated_result_fixed_by_use_test() ->
    Rule = "the body does not have the result type ",
    ?assertEqual(Rule ++ "h's uses give it: expected Int, found String",
                 refusal("fn main() : Int = {\n    let x = h() + 1;\n    fn h() = \"a\";\n"
                         "    x\n}\n")),
    %% in a group, whichever member is checked first fixes the type the
    %% other is refused against
    Group = refusal("fn g(n : Int) = f(n) + 1\n"
                    "fn f(n : Int) =\n"
                    "    if n == 0 then \"a\" else { let _ = g(n - 1); \"b\" }\n"),
    ?assert(lists:member(Group, [Rule ++ "f's uses give it: expected Int, found String",
                                 "both operands of `+` must have the same type: expected String,"
                                 " found Int"])),
    ?assertEqual(Rule ++ "f's uses give it: a type that would contain itself"
                 " (a against List(a))",
                 refusal("fn f() = [f()]\n")).

%% report §5.11, §8.5: a size expression names an earlier segment's
%% variable, which no top-level `let` of the same name is. A regression
%% test: the name was taken for the let's, and a false cycle refused
size_names_no_let_test() ->
    ?assertEqual(ok, ok("let n : Int = parse(<<2, 7, 8>>)\n"
                        "fn parse(bytes : Bytes) : Int =\n"
                        "    match bytes {\n"
                        "        <<n, body:size(n)-bytes>> -> Bytes.size(body)\n"
                        "      | _ -> 0\n"
                        "    }\n")).

%% report §11.5: an unnamed variable past `z` is named `a1`, `b1`, ...,
%% avoiding a name an annotation took. A regression test: the 26th was
%% named `a1` beside the annotation's own
variable_names_past_z_test() ->
    Params = string:join(["x : a1" | ["y" ++ integer_to_list(N) || N <- lists:seq(1, 26)]],
                         ", "),
    Printed = type_of("export fn f(" ++ Params ++ ") : a1 = x\n", f),
    ?assertMatch({match, _}, re:run(Printed, ", z, b1\\) -> a1$")).

%% report §11.5, §4.8: of the operators whose operand type nothing fixes,
%% the first in the source is reported, after a selection a later use
%% resolved. A regression test: the second was named
unresolved_operator_first_test() ->
    #diagnostic{span = Span} =
        diagnostic("type Point = Point(x : Int, y : Int)\n"
                   "fn f(p, a, b, c, d) = {\n    let s = p.x;\n    let u = a + b;\n"
                   "    let v = c + d;\n    let q : Point = p;\n    Unit\n}\n"),
    ?assertMatch({4, 13, _}, Span).

%% report §11.1, §2.3: a member whose Erlang name passes the host's 255
%% characters is refused, a foreign member and a derived `compare` among
%% them, with the type's name that fits; so is a foreign fn's
%% implementation whose module or function name passes it; a type name of
%% §2.3's length is otherwise taken. A regression test: the emitter
%% crashed making the name, and the checker making a foreign fn's
host_name_limit_test() ->
    Long = "T" ++ lists:duplicate(254, $a),
    Refused = fun(Length) ->
                  "the member's Erlang name, its type's and its own joined by `.`, is "
                      ++ integer_to_list(Length)
                      ++ " characters long, and the host's names are at most 255"
              end,
    ?assertEqual({Refused(263), "shorten the type's name to at most 247 characters"},
                 refusal_and_help("type " ++ Long ++ " = A(Int) derives compare\n")),
    ?assertEqual({Refused(257), "shorten the type's name to at most 253 characters"},
                 refusal_and_help("type " ++ Long ++ " = A(Int)\n"
                                  "fn " ++ Long ++ ".+(x : " ++ Long ++ ", y : " ++ Long
                                  ++ ") : " ++ Long ++ " = x\n")),
    ?assertEqual(Refused(263),
                 refusal("type " ++ Long ++ " = A(Int)\n"
                         "foreign fn " ++ Long ++ ".compare(x : " ++ Long ++ ", y : " ++ Long
                         ++ ") : Ordering = \"erlang:max/2\"\n")),
    LongName = lists:duplicate(256, $m),
    ?assertEqual("the implementation's module name is 256 characters long, and the host's names"
                 " are at most 255",
                 refusal("foreign fn f(x : Int) : Int = \"" ++ LongName ++ ":g/1\"\n")),
    ?assertEqual("the implementation's function name is 256 characters long, and the host's"
                 " names are at most 255",
                 refusal("foreign fn f(x : Int) : Int = \"m:" ++ LongName ++ "/1\"\n")),
    ?assertEqual(ok, ok("type " ++ Long ++ " = A(Int)\n")).

%% report §6.3, §4.8: a `receive` guard's ordering is checked once its
%% operand type is known, a later use fixing it as well as an earlier one.
%% A regression test: it was refused before a later `send` fixed it
guard_order_fixed_later_test() ->
    ?assertEqual(ok, ok("fn g() = {\n    let me = self();\n"
                        "    receive { #(x, y) when x < y -> Unit };\n"
                        "    send(me, #(1, 2))\n}\n")),
    ?assertEqual("a `receive` guard orders only Int, Float, String, and Char, not Money",
                 refusal("type Money = Money(Int)\n"
                         "fn Money.compare(a : Money, b : Money) : Ordering = Equal\n"
                         "fn g() = {\n    let me = self();\n"
                         "    receive { #(x, y) when x < y -> Unit };\n"
                         "    send(me, #(Money(1), Money(2)))\n}\n")).

%% report §8.5, §11.5: a let whose initializer uses it at another type than
%% its own is refused for the cycle alone, the mismatch following from it.
%% A regression test; it does not cover a mismatch at a
%% use of the let inside a function of its cycle, which is reported there
let_named_by_itself_one_error_test() ->
    ?assertEqual(["the initializer of f depends on itself"],
                 refusals("let f = fn(x) = if x then f(1) else 2\n")).

%% report §8.5, §11.5: a cycle through a function says that the function
%% reads the value when called and that a `fn` builds it when asked; one
%% through lets alone has no help. A regression test, written with the
%% help; it does not cover a cycle through a function of another module,
%% which a module cycle refuses first (§4.2)
let_cycle_help_test() ->
    {error, [#diagnostic{help = Help} | _]} =
        check("let handlers = [f]\nfn f() : Int = List.size(handlers)\n"),
    ?assertEqual("`f` reads handlers when it is called; a `fn handlers() = ...` builds the"
                 " value when it is asked for", Help),
    {error, [#diagnostic{help = None} | _]} = check("let a : Int = b\nlet b : Int = a\n"),
    ?assertEqual(undefined, None),
    %% the function the help names is the one that reads the value, the last
    %% on the cycle, which is listed in its order; a lambda on a longer cycle
    %% is a recursive function still; and a member let is named with its
    %% type. A regression test: the help named the first function, the
    %% cycle was listed sorted, a lambda was told to take no parameters, and
    %% a member was named bare
    {error, [#diagnostic{message = Order, help = Reads} | _]} =
        check("let a : Int = g()\nfn g() : Int = f()\nfn f() : Int = a\n"),
    ?assertEqual("the initializer of a depends on itself, through g, f", Order),
    ?assertEqual("`f` reads a when it is called; a `fn a() = ...` builds the value when it is"
                 " asked for", Reads),
    {error, [#diagnostic{help = Lambda} | _]} =
        check("let h = fn(n : Int) : Int = g(n)\nfn g(n : Int) : Int = h(n)\n"),
    ?assertEqual("a recursive function is declared with `fn h(...) = ...`", Lambda).

%% report §4.6
toplevel_let_test() ->
    ?assertEqual("Int", type_of("export let port : Int = 8080", port)),
    ?assertEqual("List(a)", type_of("export let empty = []", empty)),
    ?assertEqual("the value does not have the declared type: expected Float, found Int",
                 refusal("let pi : Float = 3")),
    %% report §4.6, §6.8: an initializer is a body of mailbox type Never,
    %% which may print, spawn and send, and receives no message
    ?assertEqual("Unit", type_of("export let x = Io.println(\"a\")", x)),
    ?assertEqual("Address(Int)",
                 type_of("export let s : Address(Int) =\n"
                         "    spawn(fn() : Unit receiving Int = receive { n -> Unit })", s)),
    ?assertEqual("a top-level initializer runs with mailbox Never and cannot receive",
                 refusal("let x = receive { n -> n }")),
    %% report §3.9, §4.6: one whose initializer is a call has the type the
    %% call gives, generalized where that type is data, so a variable left
    %% in a type that holds an address is an error, where a value generalizes
    ?assertEqual("the type of s is not determined (Address(Optional(a))), and a top-level"
                 " `let` whose initializer is no value is not generalized where its type holds"
                 " an address; annotate it",
                 refusal("fn hold(value : a) : Unit receiving a = receive { next -> hold(next) }\n"
                         "export let s = spawn(fn() = hold(None))")),
    ?assertEqual("List(a)", type_of("export let empty = List.reverse([])", empty)),
    ?assertEqual("List(Int)", type_of("export let some = List.reverse([1])", some)),
    %% a constructor applied to values, a tuple and a list of them are values
    ?assertEqual("Optional(List(a))", type_of("export let none = Some([])", none)),
    ?assertEqual("#(List(a), Optional(b))", type_of("export let pair = #([], None)", pair)),
    ?assertEqual("List(Optional(a))", type_of("export let nones = [None, None]", nones)).

%% report §3.9, §4.6: an initializer that is or holds a call whose type
%% holds an address is not generalized, a spawn through a helper that calls
%% what it is given, through a function a call returns, and through a
%% function passed by name among them; a lambda it builds and does not call
%% is generalized. Regression tests, written with the type system's argument
%% (2026-10-04), which rests on them: a process generalized over its mailbox
%% type would answer one caller with another's value. Kept for the value
%% restriction, 2026-10-16
initializer_call_not_generalized_test() ->
    Cell = "type Cell(a) = Put(a) | Get(reply : Reply(a))\n"
           "fn cell(v : a) : Unit receiving Cell(a) = receive {\n"
           "    Put(x) -> cell(x)\n  | Get(reply = r) -> { answer(r, v); cell(v) } }\n"
           "fn apply(f) = f()\n"
           "fn make() = fn() = spawn(fn() = cell(None))\n"
           "fn start() = spawn(fn() = cell(None))\n",
    Refused = "the type of shared is not determined (Address(Cell(Optional(a)))), and a"
              " top-level `let` whose initializer is no value is not generalized where its type"
              " holds an address; annotate it",
    ?assertEqual(Refused, refusal(Cell ++ "let shared = spawn(fn() = cell(None))")),
    ?assertEqual(Refused, refusal(Cell ++ "let shared = apply(fn() = spawn(fn() = cell(None)))")),
    ?assertEqual(Refused, refusal(Cell ++ "let shared = make()()")),
    ?assertEqual(Refused, refusal(Cell ++ "let shared = apply(start)")),
    ?assertEqual("() -> Address(a) receiving a", type_of("export let me = fn() = self()", me)).

%% report §6.2, §3.11, §4.6: a spawned function's mailbox type that nothing
%% fixed by the end of the definition, which no parameter's type holds and
%% which is not the definition's own mailbox type, is Never: a top-level
%% `let` of a spawn, and of a `Peer.spawn` with no mark; a `fn`, whose type
%% then holds it, a process-only one among them, and a local `fn` as a
%% top-level one; nothing can be sent to such an address. One a send fixes,
%% one an annotation names, one a parameter's type holds, of the definition
%% or of the function it answers, one that is the definition's own mailbox
%% type, whose `receive` stands, and one an enclosing definition fixes
%% after a local fn's end are kept, and a variable inside a mailbox type is
%% still §4.6's refusal. A regression test, written after the code; it
%% does not cover the shell's input, which ern_shell_tests does, nor a
%% group of definitions
unfixed_mailbox_is_never_test() ->
    ?assertEqual("Address(Never)", type_of("export let p = spawn(fn() = Io.println(\"x\"))", p)),
    ?assertEqual("Either(Io.Error, Address(Never))",
                 type_of("export let q = Peer.spawn(\"p\", fn() = Unit, 5000)", q)),
    ?assertEqual("() -> Address(Never)",
                 type_of("export fn make() = spawn(fn() = Io.println(\"x\"))", make)),
    ?assertEqual("() -> Address(Never)",
                 type_of("export fn start() = spawn(fn() = receive { _ -> Unit })", start)),
    ?assertEqual("(() -> Unit receiving a) -> Address(a)",
                 type_of("export fn start(f) = spawn(f)", start)),
    ?assertEqual(ok, ok("fn start(f) = spawn(f)\n"
                        "fn g() : Unit = {\n"
                        "    let p = start(fn() = receive { n -> Io.println(Int.toString(n)) });\n"
                        "    send(p, 1)\n"
                        "}\n")),
    ?assertEqual("() -> (() -> Unit receiving a) -> Address(a)",
                 type_of("export fn make() = fn(f) = spawn(f)", make)),
    ?assertEqual("(Address(a)) -> Address(a)",
                 type_of("export fn relay(other) = { let p = spawn(fn() = Unit);"
                         " if true then p else other }", relay)),
    ?assertEqual("() -> Unit receiving e+",
                 type_of("export fn loop() = { let p = spawn(fn() = Unit);"
                         " receive { m -> send(p, m) } }", loop)),
    ?assertEqual("the argument does not fit send: expected Never, found Int",
                 refusal("let p = spawn(fn() = Unit)\nfn f() : Unit = send(p, 1)")),
    ?assertEqual("the argument does not fit send: expected Never, found Int",
                 refusal("fn f() : Unit = { fn start() = spawn(fn() = Unit); send(start(), 1) }")),
    ?assertEqual("the argument does not fit send: expected Never, found Int",
                 refusal("fn f() : Unit = { let start = fn() = spawn(fn() = Unit);"
                         " send(start(), 1) }")),
    ?assertEqual("() -> Address(Int)",
                 type_of("export fn start() = { let p = spawn(fn() = Unit); send(p, 1); p }",
                         start)),
    ?assertEqual("(() -> Unit receiving m) -> Address(m)",
                 type_of("export fn start(f : () -> Unit receiving m) : Address(m) = spawn(f)",
                         start)),
    ?assertEqual(ok, ok("fn f() : Unit = { let p = spawn(fn() = Unit); fn g() = p;"
                        " send(g(), 1) }")),
    ?assertEqual("the type of shared is not determined (Address(Optional(a))), and a top-level"
                 " `let` whose initializer is no value is not generalized where its type holds"
                 " an address; annotate it",
                 refusal("fn hold(value : a) : Unit receiving a = receive { next -> hold(next) }\n"
                         "let shared = spawn(fn() = hold(None))")).

%% report §4.6, §3.9, §6.2: a call's binding that is not generalized has
%% each type variable left in its type that stands in no value position,
%% after `receiving` or in a type argument whose parameter the type's
%% fields hold in none, Never, as a spawned function's unfixed mailbox type
%% is: a test case a helper builds, its annotation's variable among them,
%% and a function a call returns that receives; one a call returns that
%% receives nothing receives nothing, the variable by which it stands for
%% one that receives (§3.9) none, and is no longer refused; a variable in a
%% value position beside one is still refused. A regression test, written after
%% the fix (the release review before 0.4.0 found `let t = case("x")`
%% refused, "annotate it"); it does not cover a group of bindings
not_generalized_effect_only_is_never_test() ->
    Case = "fn case(name : String) : Test.Case(m) =\n"
           "    Test.Case(name = name, run = fn() = Test.Passed)\n",
    ?assertEqual("Test.Case(Never)", type_of(Case ++ "export let t = case(\"x\")", t)),
    ?assertEqual("Test.Case(Never)",
                 type_of(Case ++ "export let u : Test.Case(m) = case(\"y\")", u)),
    ?assertEqual("() -> Unit receiving Never",
                 type_of("fn make() : () -> Unit receiving m = fn() = receive { _ -> Unit }\n"
                         "export let f = make()", f)),
    ?assertEqual("() -> Unit",
                 type_of("fn make() = fn() = Io.println(\"k\")\nexport let k = make()", k)),
    ?assertEqual(ok, ok("fn make() = fn() = Io.println(\"k\")\nlet k = make()\n"
                        "fn main() : Unit = k()\n")),
    ?assertEqual("the type of g is not determined ((a) -> a receiving Never), and a top-level"
                 " `let` whose initializer is no value is not generalized where its type holds"
                 " a function; annotate it",
                 refusal("fn make() : (a) -> a receiving m = fn(x) = receive { _ -> x }\n"
                         "let g = make()")).

%% report §4.6: a call's binding whose type, read through the fields of the
%% declared types it names, holds a function type, a foreign type, an
%% address or a reply is not generalized, the refusal naming what it holds:
%% a function a call returns, a declared type that holds an address through
%% its field, the module's own foreign type, a reply, and an address inside
%% a declared type met again inside its own fields, whose argument is read.
%% Regression tests, written after the code; they do not cover a type of
%% another module that keeps its constructors (§4.4), whose fields the walk
%% reads as it reads the module's own
call_holding_no_data_not_generalized_test() ->
    Refused = fun(Name, Type, Held) ->
                  "the type of " ++ Name ++ " is not determined (" ++ Type ++ "), and a"
                  " top-level `let` whose initializer is no value is not generalized where its"
                  " type holds " ++ Held ++ "; annotate it"
              end,
    ?assertEqual(Refused("id", "(a) -> a", "a function"),
                 refusal("fn make() = fn(x) = x\nlet id = make()")),
    ?assertEqual(Refused("box", "Box(a)", "an address"),
                 refusal("type Box(a) = Box(Address(a))\n"
                         "fn boxed() : Box(a) = Box(spawn(fn() = Unit))\nlet box = boxed()")),
    ?assertEqual(Refused("handle", "Handle(a)", "the foreign type Handle(a)"),
                 refusal("foreign type Handle(a)\n"
                         "foreign fn open() : Handle(a) = \"m:open/0\"\nlet handle = open()")),
    ?assertEqual(Refused("asked", "Optional(Reply(a))", "a reply"),
                 refusal("foreign fn asking() : Optional(Reply(a)) = \"m:asking/0\"\n"
                         "let asked = asking()")),
    ?assertEqual(Refused("doubly", "Wrap(Wrap(Address(a)))", "an address"),
                 refusal("type Wrap(a) = Wrap(a)\n"
                         "foreign fn wrapped() : Wrap(Wrap(Address(a))) = \"m:wrapped/0\"\n"
                         "let doubly = wrapped()")).

%% report §4.6: a call's binding whose type holds none of the four is
%% generalized, and is used at two types in its module: a list a foreign
%% function answers, a declared type over data, and a recursive one, whose
%% walk ends at the type met again. Regression tests, written after the
%% code; Map.empty and Set.empty, which the standard library's build
%% checks, are the case the rule was relaxed for
call_holding_data_generalized_test() ->
    Empty = "foreign fn nothing() : List(a) = \"m:nothing/0\"\n"
            "export let empty = nothing()\n"
            "export fn sizes() : Int = List.size(1 :: empty) + List.size(\"a\" :: empty)\n",
    ?assertEqual("List(a)", type_of(Empty, empty)),
    Pair = "export type Pair(a) = Pair(items : List(a), first : Optional(a))\n"
           "foreign fn paired() : Pair(a) = \"m:paired/0\"\n"
           "export let pair = paired()\n"
           "export fn sizes() : Int =\n"
           "    List.size(1 :: pair.items) + List.size(\"a\" :: pair.items)\n",
    ?assertEqual("M.Pair(a)", type_of(Pair, pair)),
    Tree = "export type Tree(a) = Leaf | Node(left : Tree(a), value : a, right : Tree(a))\n"
           "foreign fn planted() : Tree(a) = \"m:planted/0\"\n"
           "export let tree = planted()\n"
           "export fn trees() : #(Tree(Int), Tree(String)) = #(tree, tree)\n",
    ?assertEqual("M.Tree(a)", type_of(Tree, tree)).

%% report §3.5, §4.8, §11.5: a field is selected where every constructor has
%% it, of one type; a type found later in the definition serves, one never
%% found is an error, and an abstract type's fields are its module's
field_selection_test() ->
    Shape = "export type Point = Point(x : Int, y : Int)\n"
            "export type Shape = Dot(at : Point) | Circle(at : Point, radius : Int)\n",
    ?assertEqual("(M.Shape) -> Int", type_of(Shape ++ "export fn f(s : Shape) = s.at.x", f)),
    ?assertEqual("(M.Point) -> Int",
                 type_of(Shape ++ "export fn g(p) = { let n = p.x; n + norm(p) }\n"
                         "fn norm(p : Point) : Int = p.y", g)),
    ?assertEqual("not every constructor of Shape has the field radius: Dot has none",
                 refusal(Shape ++ "fn f(s : Shape) = s.radius")),
    ?assertEqual("Point has no field z", refusal(Shape ++ "fn f(p : Point) = p.z")),
    ?assertEqual("#(Int, Int) has no field x", refusal("fn f() = #(1, 2).x")),
    ?assertEqual("the type whose field x is read is not determined; annotate it",
                 refusal(Shape ++ "fn f(p) = p.x")),
    ?assertEqual("T has no field name of one type: name is Int in A and String in B",
                 refusal("type T = A(name : Int) | B(name : String)\nfn f(t : T) = t.name")),
    ?assertEqual(ok, ok("export abstract type Box = Box(n : Int)\nfn f(b : Box) = b.n")).

%% report §5.6
constructors_test() ->
    ?assertEqual("(Int) -> List(Optional(Int))",
                 type_of("export fn f(x : Int) = List.map([x], Some)", f)),
    ?assertEqual("missing field age", refusal("type P = P(name : String, age : Int)\n"
                                              "fn f() = P(name = \"a\")")),
    ?assertEqual("P has no field foo", refusal("type P = P(name : String, age : Int)\n"
                                               "fn f() = P(name = \"a\", age = 1, foo = 2)")),
    ?assertEqual(ok, ok("type P = P(name : String, age : Int)\n"
                        "fn f(p : P) = P(..p, age = 31)")),
    ?assertEqual("None takes no fields", refusal("fn f() = None(1)")),
    ?assertEqual("unknown constructor Nope", refusal("fn f() = Nope")).

%% report §11.5: a block goes on after an error in a statement that binds
%% nothing, or in a `let` whose annotation fixes its name's type, and
%% reports every error of its own; it stops at any other binding's error,
%% whose name the rest may use. A regression test: a definition's first
%% error was its only one
errors_of_a_block_test() ->
    ?assertEqual(["the argument does not fit Io.println: expected String, found Int",
                  "the argument does not fit Io.println: expected String, found Int"],
                 refusals("fn f() : Unit receiving Never ="
                          " { Io.println(1); Io.println(2); Unit }")),
    ?assertEqual(["the value does not have the declared type: expected Int, found String",
                  "the value does not have the declared type: expected Int, found String"],
                 refusals("fn f() : Int = { let a : Int = \"x\"; let b : Int = \"y\"; a + b }")),
    ?assertEqual(["both operands of `+` must have the same type: expected String, found Int"],
                 refusals("fn f() : Int = { let c = \"z\" + 1; c * 2 }")).

%% report §5.10: each constructor is matched in one form: a nullary one
%% bare, a single-positional one with one pattern, and one with named
%% fields with its parentheses, `C()` matching any of its values. A
%% regression test: a bare `Circle` matched as `Circle()` did
constructor_pattern_forms_test() ->
    Shape = "type Shape = Circle(r : Int) | Square(side : Int) | Dot\n",
    ?assertEqual(ok, ok(Shape ++ "fn f(s : Shape) : Int ="
                        " match s { Circle() -> 1 | Square(side = n) -> n | Dot -> 0 }")),
    ?assertEqual(ok, ok(Shape ++ "fn f(s : Shape) : Int ="
                        " match s { Circle() or Square() -> 1 | Dot -> 0 }")),
    ?assertEqual("Circle has named fields; write Circle() to match any Circle",
                 refusal(Shape ++ "fn f(s : Shape) : Int = match s { Circle -> 1 | _ -> 0 }")),
    ?assertEqual("Dot takes no fields",
                 refusal(Shape ++ "fn f(s : Shape) : Int = match s { Dot() -> 1 | _ -> 0 }")),
    ?assertEqual("Some has one positional field; write Some(p)",
                 refusal("fn f(o : Optional(Int)) : Int = match o { Some() -> 1 | _ -> 0 }")).

%% report §5.6, §5.10, §11.5: a constructor with named fields written with
%% positional ones is told its fields by name, as a construction and as a
%% pattern. A regression test: the help said `field = value`, naming none
named_fields_named_test() ->
    Point = "type Point = Point(x : Int, y : Int)\n",
    ?assertEqual("Point has named fields; write Point(x = value, y = value)",
                 refusal(Point ++ "fn f() : Point = Point(1)")),
    ?assertEqual("Point has named fields; write Point(x = p, y = p)",
                 refusal(Point ++ "fn f(q : Point) : Int = match q { Point(a) -> a }")).

%% report §5.6, §11.5: a constructor with named fields where a function
%% that takes its fields is wanted, as Os.termination's wrap, is told the
%% lambda that constructs it; where any other value is wanted, the
%% construction. A regression test, written after the fix: the help named a
%% construction where a function was wanted
named_constructor_as_function_test() ->
    ?assertEqual("Stop has named fields; write fn(reply) = Stop(reply = reply)",
                 refusal("type Stop = Stop(reply : Reply(Unit))\n"
                         "fn f() : Unit receiving Stop = Os.termination(Stop)\n")),
    Point = "type Point = Point(x : Int, y : Int)\n"
            "fn made(make : (Int, Int) -> Point) : Point = make(1, 2)\n",
    ?assertEqual("Point has named fields; write fn(x, y) = Point(x = x, y = y)",
                 refusal(Point ++ "fn f() : Point = made(Point)\n")),
    ?assertEqual("Point has named fields; write Point(x = value, y = value)",
                 refusal(Point ++ "fn f() : (Int) -> Point = Point\n")),
    ?assertEqual("Point has named fields; write Point(x = value, y = value)",
                 refusal(Point ++ "fn f() : Point = Point\n")).

%% report §5.6: a construction gives each field once. A regression test,
%% written after the code
field_given_once_test() ->
    ?assertEqual("field x is given twice",
                 refusal("type P = P(x : Int, y : Int)\n"
                         "fn f() : P = P(x = 1, x = 2, y = 3)")).

%% report §5.6: `..` is allowed only on a type with one constructor. It was
%% accepted on a type of two, and the program faulted with badmatch where
%% the value was the other constructor.
update_needs_one_constructor_test() ->
    Source = "type T = A(x : Int, y : Int) | B(x : Int, y : Int)\n",
    Diagnostic = diagnostic(Source ++ "fn f(t : T) : T = A(..t, x = 1)\n"),
    ?assertEqual("`..` is allowed only on a type with one constructor, and T has 2",
                 Diagnostic#diagnostic.message),
    ?assertEqual("give every field of A", Diagnostic#diagnostic.help),
    ?assertEqual(ok, ok(Source ++ "fn f(t : T) : T = A(x = 1, y = t.y)\n")),
    ?assertEqual(ok, ok("type P(a) = P(x : a, y : Int)\n"
                        "fn f(p : P(String)) : P(String) = P(..p, y = 2)\n")).

%% report §5.2
calls_test() ->
    ?assertEqual("f takes 2 arguments, not 1",
                 refusal("fn f(a, b) = a\nfn g() = f(1)")),
    ?assertEqual("x is not a function; it has type Int", refusal("let x = 1\nfn g() = x(1)")),
    ?assertEqual("unknown name nope", refusal("fn g() = nope(1)")),
    ?assertEqual("(Int) -> Int", type_of("export fn add3(x) = makeAdder(3)(x)\n"
                                         "fn makeAdder(n : Int) = fn(m) = n + m", add3)).

%%
%% Exhaustiveness (report §5.9)
%%

%% report §5.9
exhaustiveness_test() ->
    ?assertEqual("match on Optional(a) is not exhaustive; missing None",
                 refusal("fn f(o) = match o { Some(x) -> x }")),
    ?assertEqual("match on Bool is not exhaustive; missing false",
                 refusal("fn f(b : Bool) = match b { true -> 1 }")),
    ?assertEqual("match on List(a) is not exhaustive; missing _ :: _",
                 refusal("fn f(xs) = match xs { [] -> 0 }")),
    ?assertEqual("match on List(Int) is not exhaustive; missing _ :: _ :: _",
                 refusal("fn f(xs : List(Int)) = match xs { [] -> 0 | [x] -> x }")),
    ?assertEqual("match on Int is not exhaustive; missing _",
                 refusal("fn f(n : Int) = match n { 0 -> 1 | 1 -> 2 }")),
    %% guards do not count
    ?assertEqual("match on Int is not exhaustive; missing _",
                 refusal("fn f(n : Int) = match n { k when k > 0 -> 1 | k when k <= 0 -> 0 }")),
    ?assertEqual("match on #(Optional(a), Bool) is not exhaustive; missing #(Some(_), false)",
                 refusal("fn f(p) = match p { #(None, _) -> 0 | #(Some(_), true) -> 1 }")),
    ?assertEqual(ok, ok("fn f(o) = match o { Some(x) -> x | None -> 0 }")),
    ?assertEqual(ok, ok("fn f(xs) = match xs { [] -> 0 | _ :: _ -> 1 }")),
    ?assertEqual(ok, ok("type R = Get(reply : Int) | Stop\n"
                        "fn f(r) = match r { Get(reply = n) -> n | Stop -> 0 }")),
    %% a named-field constructor with no field shown is written as §5.10's
    %% pattern for any value of it: a regression test, it was shown bare
    ?assertEqual("match on R is not exhaustive; missing Get()",
                 refusal("type R = Get(reply : Int) | Stop\nfn f(r) = match r { Stop -> 0 }")).

%%
%% Names, forms and the built-in types
%%

%% report §4.2: a type's member is written `T.name`, within the type's own
%% members too; no lookup step finds it unqualified. A regression test,
%% written when the report dropped the step the compiler never had
member_written_qualified_test() ->
    Box = "type Box = Box(Int)\nfn Box.compare(a : Box, b : Box) : Ordering = Equal\n",
    ?assertEqual("unknown name compare",
                 refusal(Box ++ "fn Box.negate(b : Box) : Box = match compare(b, b) { _ -> b }")),
    ?assertEqual(ok, ok(Box ++ "fn Box.negate(b : Box) : Box ="
                        " match Box.compare(b, b) { _ -> b }")).

%% report §4.2: a dotted name's first segment is the module's own type
%% where that type has a member of the name, and otherwise the namespace
%% of that name; `Prelude.T.name` reaches the name of a namespace of the
%% prelude or the standard library past the module's own member. A
%% regression test, written with the rule: the standard library's
%% `List.size` was out of reach there, and its `Io.println` before; since
%% a member is an operator, `compare` or `negate` (§4.5), the module's own
%% `List.<>` stands for both
first_segment_test() ->
    Own = "type List = Nil | Cons(Int)\nfn List.<>(a : List, b : List) : List = a\n",
    ?assertEqual(ok, ok(Own ++ "fn f() : List = List.<>(Nil, Nil)")),
    ?assertEqual(ok, ok(Own ++ "fn f() : Prelude.List(Int) = Prelude.List.<>([1], [2])")),
    ?assertEqual(ok, ok(Own ++ "fn f() : Prelude.List(Int) = List.reverse([1])")),
    ?assertEqual("the argument does not fit List.<>: expected M.List, found List(Int)",
                 refusal(Own ++ "fn f() : Prelude.List(Int) = List.<>([1], [2])")).

%% report §5.5: in `let p : T <- e`, `T` is the type of `p`, the value
%% inside. A regression test, written after the report said so
let_arrow_annotation_test() ->
    ?assertEqual(ok, ok("fn f(o : Optional(Int)) : Optional(Int) ="
                        " { let x : Int <- o; Some(x + 1) }")),
    ?assertEqual("the pattern does not fit the value inside the sum type: expected Int,"
                 " found Optional(Int)",
                 refusal("fn f(o : Optional(Int)) : Optional(Int) ="
                         " { let x : Optional(Int) <- o; Some(1) }")).

%% report §5.11: a segment names each kind of specifier once, and a
%% negative literal is a segment pattern. A regression test, written after
%% the report said what the compiler did
bitstring_specifiers_test() ->
    ?assertEqual("conflicting bitstring specifiers `big` and `little`",
                 refusal("fn f(x : Int) : Bytes = <<x:big-little>>")),
    ?assertEqual("conflicting bitstring specifiers `size(8)` and `size(16)`",
                 refusal("fn f(x : Int) : Bytes = <<x:size(8)-size(16)>>")),
    ?assertEqual("conflicting bitstring specifiers `big` and `big`",
                 refusal("fn f(x : Int) : Bytes = <<x:big-big>>")),
    ?assertEqual(ok, ok("fn f(b : Bytes) : Bool = match b { <<-1:signed>> -> true | _ -> false }")).

%% report §5.9: `true` and `false` cover `Bool`. A regression test,
%% written after the report said what the checker did
bool_covered_test() ->
    ?assertEqual(ok, ok("fn f(b : Bool) : Int = match b { true -> 1 | false -> 0 }")).

%% report §5.7: a pipe's right-hand side is any operand, a selected function
%% among them, and one that is no function is a type error. A regression
%% test, written after the report said what the checker did
pipe_operand_test() ->
    ?assertEqual(ok, ok("type S = S(f : (Int) -> Int)\nfn g(s : S) : Int = 1 |> s.f")),
    ?assertEqual("the callee is not a function; it has type List((Int) -> Int)",
                 refusal("fn g(f : (Int) -> Int) = 1 |> [f]")).

%% report §3.5: a selector over a type with parameters has one type once
%% the arguments stand for them. A regression test, written after the
%% report said what the checker did
selector_at_the_arguments_test() ->
    Source = "type P(a) = A(x : a) | B(x : Int)\n",
    ?assertEqual(ok, ok(Source ++ "fn g(p : P(Int)) : Int = p.x")),
    ?assertEqual("P(String) has no field x of one type: x is String in A and Int in B",
                 refusal(Source ++ "fn g(p : P(String)) = p.x")).

%% report §5.10: a pattern matches each field once
field_matched_twice_test() ->
    ?assertEqual("field reply is matched twice",
                 refusal("type Req = Get(reply : Reply(Int)) | Stop\n"
                         "fn f(r) = match r { Get(reply = a, reply = b) -> Unit | Stop -> Unit }")).

%% report §4.7, §3.9: a foreign function whose mailbox type is a variable
%% of its own is process-only, and a function that receives nothing cannot
%% call it
foreign_effect_process_only_test() ->
    ?assertEqual("tick needs a mailbox, and f receives nothing",
                 refusal("foreign fn tick() : Unit receiving m = \"m:tick/0\"\n"
                         "fn f() : Unit = tick()")),
    ?assertEqual(ok, ok("foreign fn tick() : Unit receiving m = \"m:tick/0\"\n"
                        "fn f() : Unit receiving Never = tick()")).

%% report §3.9: a lambda's annotation variables: the definition's are in
%% scope and rigid, and a new one means every type, which only a lambda
%% that is generalized may name. A regression test for the new one: it
%% belonged to the lambda and became Int
lambda_annotation_variables_test() ->
    ?assertEqual("(a) -> a", type_of("export fn f(x : a) : a = (fn(y : a) : a = y)(x)", f)),
    ?assertEqual("the lambda body does not have the declared type: expected a, found Int",
                 refusal("fn f(x : a) : a = { let g = fn(y : a) : a = 1; g(x) }")),
    ?assertEqual("type variable b in the lambda's annotation means every type, and the lambda"
                 " is not generalized",
                 refusal("fn f(x : Int) = (fn(y : b) : b = y)(x)")),
    ?assertEqual("(Int) -> Int",
                 type_of("export fn f(x : Int) = { let g = fn(y : b) : b = y; g(x) }", f)).

%% report §8.4: a foreign fn's implementation is named module:function/arity,
%% and the arity is its parameter count; either mistake is a compile error.
%% A regression test: the checker conformed before it was written. It does
%% not cover a module or function missing at run time.
foreign_implementation_name_test() ->
    Named = "the implementation of tick is not written `module:function/arity`",
    %% the help gives the arity to write: a regression test
    ?assertEqual({Named, "write the host's module and function and the arity 1, as"
                         " `module:function/1`"},
                 refusal_and_help("foreign fn tick(n : Int) : Int = \"erlang:abs\"")),
    ?assertEqual(Named, refusal("foreign fn tick(n : Int) : Int = \"abs/1\"")),
    ?assertEqual(Named, refusal("foreign fn tick(n : Int) : Int = \"erlang:abs/x\"")),
    ?assertEqual("the implementation names arity 2, and tick has 1 parameter",
                 refusal("foreign fn tick(n : Int) : Int = \"erlang:abs/2\"")),
    %% a line feed after the arity is no part of the form; a regression
    %% test: `$` matched before it
    ?assertEqual(Named, refusal("foreign fn tick(n : Int) : Int = \"erlang:abs/1\\n\"")),
    ?assertEqual(ok, ok("foreign fn tick(n : Int) : Int = \"erlang:abs/1\"")).

%% report §3.1
base_types_test() ->
    ?assertEqual("() -> #(Int, Float, Char, String, Bool)",
                 type_of("export fn f() = #(1, 1.5, 'c', \"s\", true)", f)),
    ?assertEqual("() -> Unit", type_of("export fn f() = Unit", f)).

%% report §3.6
abstract_types_as_types_test() ->
    Stack = "export abstract type Stack(a) = Stack(List(a))\n"
            "export let empty = Stack([])\n"
            "export fn push(x, Stack(xs)) = Stack(x :: xs)\n",
    ?assertEqual("(M.Stack(Int)) -> M.Stack(Int)",
                 type_of(Stack ++ "export fn f(s : Stack(Int)) = push(1, s)", f)),
    ?assertEqual("() -> M.Stack(String)",
                 type_of(Stack ++ "export fn f() = push(\"a\", empty)", f)),
    ?assertMatch("the argument does not fit push: " ++ _,
                 refusal(Stack ++ "fn f(s : Stack(Int)) = push(\"a\", s)")),
    %% a sum type like any other: structural equality applies
    ?assertEqual("(M.Stack(Int), M.Stack(Int)) -> Bool",
                 type_of(Stack ++ "export fn same(a : Stack(Int), b) = a == b", same)).

%% report §3.8
foreign_types_test() ->
    Table = "export foreign type Table(k, v)\n"
            "foreign fn rawNew(name : String) : Table(k, v) = \"ets:new/1\"\n",
    ?assertEqual("(M.Table(Int, String)) -> M.Table(Int, String)",
                 type_of(Table ++ "export fn id(t : Table(Int, String)) = t", id)),
    ?assertEqual("() -> M.Table(a, b)",
                 type_of(Table ++ "export fn new() = rawNew(\"t\")", new)),
    %% no constructors: nothing to construct or match on
    ?assertEqual("unknown constructor Table", refusal(Table ++ "fn f() = Table(1)")),
    ?assertEqual("unknown constructor Table",
                 refusal(Table ++ "fn f(t : Table(Int, Int)) = match t { Table(x) -> x }")),
    %% equality is identity, so it is allowed
    ?assertEqual("(M.Table(Int, Int), M.Table(Int, Int)) -> Bool",
                 type_of(Table ++ "export fn same(a : Table(Int, Int), b) = a == b", same)),
    %% held, passed, and sent
    ?assertEqual(ok, ok(Table ++ "fn send1(a : Address(Table(Int, Int)), t) = send(a, t)")).

%% report §3.7: Never is an ordinary type, which unifies with itself alone,
%% and a function that may stand at any type has a variable as its result,
%% as fault has. A regression test, written after the code, which the
%% review found stated and untested
never_is_ordinary_test() ->
    ?assertEqual("the body does not have the declared result type: expected Int, found Never",
                 refusal("fn f(x : Never) : Int = x")),
    ?assertEqual(ok, ok("fn f(x : Never) : Never = x")),
    ?assertEqual(ok, ok("fn f() : Int = fault(\"no\")")).

%% report §3.7, §9.1, §9.2, §9.3: every built-in and declared type is usable
%% as a type, and every declared type's constructors cover it
prelude_types_test() ->
    ?assertEqual(ok, ok("fn f(a : Address(Int), n : Never, x : Foreign.Term, l : List(Int),"
                        " m : Map(String, Int), s : Set(Char), r : Reply(Int)) = Unit")),
    ?assertEqual(ok, ok("fn f(x : Unit) = match x { Unit -> 1 }")),
    ?assertEqual(ok, ok("fn f(x : Optional(Int)) = match x { None -> 0 | Some(v) -> v }")),
    ?assertEqual(ok, ok("fn f(x : Either(String, Int)) = match x { Left(_) -> 0"
                        " | Right(v) -> v }")),
    ?assertEqual(ok, ok("fn f(x : Ordering) = match x { Less -> 0 | Equal -> 1 | Greater -> 2 }")),
    ?assertEqual(ok, ok("fn f(x : Down) = match x { Down(reason = r, site = _) -> r }")),
    ?assertEqual(ok, ok("fn f(x : Reason) = match x { Returned -> 0 | Killed -> 1 | ProgramEnd -> 2"
                        " | Fault(_) -> 3 | Unknown -> 4 | Unreachable -> 5 }")),
    ?assertEqual(ok, ok("fn f(x : RestartLimit) = match x {"
                        " RestartLimit(restarts = n, within = _) -> n | Unlimited -> -1 }")).

%% report §9.4, §9.5, §9.6, §9.7 and Appendix E: every prelude and stdlib
%% signature parses, and every name resolves to a value
prelude_values_test() ->
    lists:foreach(fun({QualifiedName, Text, _}) ->
                      ?assertMatch({ok, _}, ern_parser:parse_type(Text)),
                      Name = lists:flatten(lists:join(".",
                                                      [atom_to_list(Part)
                                                       || Part <- QualifiedName])),
                      ?assertEqual(ok, ok("export let v = " ++ Name))
                  end, ern_prelude:values()),
    %% the process primitives that receive name the caller's mailbox, those
    %% that act on another process and the stdlib combinators do not
    ?assertEqual(ok, ok("fn f(a : Address(Int)) : Unit = send(a, 1)")),
    ?assertEqual("self needs a mailbox, and f receives nothing",
                 refusal("fn f() : Unit = { let a = self(); send(a, 1) }")),
    ?assertEqual("(List(Int)) -> List(Int)",
                 type_of("export fn f(xs) = List.map(xs, fn(x : Int) = x)", f)),
    %% report §9.7: the prelude binds no system reference
    ?assertEqual("unknown name Sys.stdout", refusal("let out = Sys.stdout")).

%%
%% Abstract types and interfaces
%%

%% report §4.4
abstract_type_test() ->
    Stack = "export abstract type Stack(a) = Stack(List(a))\n"
            "export let empty = Stack([])\n"
            "export fn push(x, Stack(xs)) = Stack(x :: xs)\n"
            "export fn pop(Stack(xs)) = match xs { [] -> None | x :: rest ->"
            " Some(#(x, Stack(rest))) }\n",
    ?assertEqual(ok, ok(Stack)),
    %% report §3.9, §6.6: push places its element in a list once, so a reply may
    %% be pushed
    ?assertEqual("(a, M.Stack(a)) -> M.Stack(a)",
                 type_of(Stack ++ "export fn use(x, s) = push(x, s)", use)),
    %% an abstract type the module keeps private hides from no module
    ?assertEqual("Stack is an abstract type the module keeps private, which hides its"
                 " constructors from no module",
                 refusal("abstract type Stack(a) = Stack(List(a))")),
    ?assertEqual("Nope is not a type declared in this module", refusal("fn Nope.negate(n) = n")).

%% report §4.2: a module may name its own declaration by its qualified name
%% where a binding hides the plain one, in any order, and not its own
%% member, which no binding hides (the full review's P7, 2026-10-04)
self_qualified_test() ->
    ?assertEqual("() -> Int", type_of("export fn f() = { let g = 0; M.g() + g }\nfn g() = 1\n",
                                      f)),
    ?assertEqual("M.T.negate is the module's own T.negate, which no binding hides",
                 refusal("export type T = T(Int)\nexport fn f(t : T) : T = M.T.negate(t)\n"
                         "fn T.negate(t : T) : T = t\n")).

%% report §4.2, §8.5: a local binding does not hide the module's own
%% qualified name, so the initializer depends on it as on the plain name.
%% A regression test: before the fix the cycle went unseen, and `M.b` was
%% unknown whenever the groups ran `a` first. It does not cover a
%% multi-segment namespace
self_qualified_under_a_local_test() ->
    ?assertEqual("the initializer of a depends on itself, through b",
                 refusal("let a = { let b = 1; M.b + b }\nlet b = a\n")),
    ?assertEqual("Int", type_of("export let four = { let two = 1; M.two - two }\nlet two = 5\n",
                                four)).

%% report §4.4: every definition of the module that declares an abstract
%% type may use its constructors, a private one and a local fn among them;
%% another module may not (ern_cli_tests)
ownership_test() ->
    Stack = "export abstract type Stack(a) = Stack(List(a))\n"
            "export let empty = Stack([])\n"
            "export fn push(x, Stack(xs)) = Stack(x :: xs)\n",
    ?assertEqual(ok, ok(Stack ++ "fn peek(Stack(xs)) = xs")),
    ?assertEqual(ok, ok(Stack ++ "fn size(s) = match s { Stack(xs) -> List.size(xs) }")),
    ?assertEqual(ok, ok(Stack ++ "fn wrap(xs : List(List(Int))) = List.map(xs, Stack)")),
    ?assertEqual(ok, ok(Stack ++ "fn use() = { fn wrap(y) = Stack([y]); wrap(1) }")).

%% report §4.2, §11.1
%% report §4.8: the standard library module of a built-in type declares that
%% type's operators as a user type's module does; no other module may
builtin_type_operators_test() ->
    Float = "export foreign fn Float.+(a : Float, b : Float) : Float = \"ern_float:add/2\"\n",
    {ok, _, Interface, _} = ern_typecheck:check_string(['Float'], Float),
    ?assertEqual([['Float', '+']], maps:keys(Interface#interface.values)),
    ?assertEqual("Float is not a type declared in this module",
                 refusal("export fn Float.+(a : Float, b : Float) : Float = a")),
    ?assertMatch({error, _},
                 ern_typecheck:check_string(['Float'],
                                            "export fn Float.abs(x : Float) : Float = x")).

%% report §4.1, §4.2: a module's interface holds its exports under its
%% namespace, and another module reaches them by the qualified name
interface_test() ->
    Http = "export type Request = Request(method : String, path : String)\n"
           "export fn parse(s : String) : Optional(Request) =\n"
           "    if s == \"GET /\" then Some(Request(method = \"GET\", path = \"/\")) else None\n"
           "fn private() = 1",
    {ok, _, Interface, _} = ern_typecheck:check_string(['Net', 'Http'], Http),
    ?assertMatch(#interface{namespace = ['Net', 'Http']}, Interface),
    ?assertEqual([['Net', 'Http', parse]], maps:keys(Interface#interface.values)),
    ?assertEqual([['Net', 'Http', 'Request']], maps:keys(Interface#interface.types)),
    Main = "export fn main() : Unit = match Net.Http.parse(\"GET /\") {\n"
           "    Some(Net.Http.Request(method = method, path = path)) ->"
           " Io.println(method <> \" \" <> path)\n"
           "  | None -> Io.println(\"bad request\")\n}",
    {ok, MainDeclarations} = ern_parser:parse_string(Main),
    ?assertMatch({ok, _, _, _}, ern_typecheck:check(['Main'], MainDeclarations, [Interface])),
    ?assertMatch({error, [#diagnostic{span = {1, 33, _}, message = "unknown name Net.Http.parse"}]},
                 ern_typecheck:check(['Main'], MainDeclarations, [])),
    Private = "fn f() = Net.Http.private()",
    {ok, PrivateDeclarations} = ern_parser:parse_string(Private),
    ?assertMatch({error, [#diagnostic{span = {1, 10, _},
                                      message = "unknown name Net.Http.private"}]},
                 ern_typecheck:check(['Main'], PrivateDeclarations, [Interface])).

%% report §11.1: every type the interfaces given name has a declaration
%% among them; the checker fails as the toolchain's own defect where one
%% has none, rather than read it as a built-in type with no fields. A
%% regression test: `==` on such a type was accepted (the log's *A Type
%% Reached Through Another Module's Interface*)
undeclared_type_in_interface_test() ->
    {ok, _, Boxes, _} = ern_typecheck:check_string(['Boxes'],
                                                   "export type Box = Box(f : (Int) -> Int)\n"),
    {ok, MakerDeclarations} = ern_parser:parse_string(
                                "export fn make() : Boxes.Box = Boxes.Box(f = fn(n) = n + 1)\n"),
    {ok, _, Maker, _} = ern_typecheck:check(['Maker'], MakerDeclarations, [Boxes]),
    {ok, MainDeclarations} =
        ern_parser:parse_string("fn same() : Bool = Maker.make() == Maker.make()\n"),
    ?assertMatch({error, [#diagnostic{message = "`==` is not defined on Boxes.Box: it contains a"
                                                " function, an address or a"
                                                " reply"}]},
                 ern_typecheck:check(['Main'], MainDeclarations, [Maker, Boxes])),
    ?assertError({interface_names_undeclared_type, "Boxes.Box"},
                 ern_typecheck:check(['Main'], MainDeclarations, [Maker])).

%% report §11.1
errors_are_collected_test() ->
    ?assertEqual(["unknown name a", "unknown name b"],
                 refusals("fn f() = a\nfn g() = b")).

%% report §3.9, §11.1: every expression of the checked AST carries its type
typed_ast_test() ->
    {ok, [#fn_declaration{body = #e_binop{type = Type, left = #e_var{type = LeftType}}}], _, _} =
        check("fn double(n : Int) = n * 2"),
    ?assertEqual({tcon, ['Int'], []}, Type),
    ?assertEqual({tcon, ['Int'], []}, LeftType).

%%
%% The example programs
%%

%% report §4.2: an exported declaration is made of the types that cross the
%% boundary with it; a private type in its signature is refused, and an
%% abstract type, whose values cross and whose constructors do not, is not
exported_types_test() ->
    ?assertEqual("start is exported and its type names Msg, which this module keeps private",
                 refusal("type Msg = Ping\nexport fn start() : Address(Msg) ="
                         " spawn(fn() = Unit)")),
    ?assertEqual("Holder is exported and its type names Hidden, which this module keeps private",
                 refusal("type Hidden = Hidden(Int)\nexport type Holder = Holder(Hidden)")),
    ?assertEqual(ok, ok("export type Msg = Ping\nexport fn start() : Address(Msg) ="
                        " spawn(fn() = Unit)")),
    %% an abstract type is how a value crosses without its constructors, and
    %% its fields may name a private type, since they do not cross
    ?assertEqual(ok, ok("export abstract type Box = B(Int)\nexport fn box(n) = B(n)")),
    ?assertEqual(ok, ok("type Hidden = Hidden(Int)\nexport abstract type Box = B(Hidden)\n"
                        "export fn box(n) = B(Hidden(n))")),
    %% the effect names no value: an entry point's mailbox type may be private
    ?assertEqual(ok, ok("type Msg = Ping\nexport fn main() : Unit receiving Msg ="
                        " receive { Ping -> Unit }")).

%% report §4.2
modules_example_test() ->
    Dir = "../../../test/fixtures/programs/modules/",
    {ok, Http} = file:read_file(Dir ++ "net/http.ern"),
    {ok, _, Interface, _} = ern_typecheck:check_string(['Net', 'Http'], Http),
    {ok, MainSource} = file:read_file(Dir ++ "main.ern"),
    {ok, Declarations} = ern_parser:parse_string(MainSource),
    ?assertMatch({ok, _, _, _}, ern_typecheck:check(['Main'], Declarations, [Interface])).

%% report Appendix B, examples/ and test/fixtures/programs/
examples_test_() ->
    Files = [File || File <- filelib:wildcard("../../../examples/**/*.ern")
                                 ++ filelib:wildcard("../../../test/fixtures/programs/*.ern"),
                     hd(filename:basename(File)) =/= $.], % editor artifacts, report §11.1
    %% report §11.1, Appendix G: the libraries' interfaces, as an example
    %% has them on its load path; snake writes with libs/ansi
    LibraryInterfaces = [Interface
                         || Path <- filelib:wildcard("../../../build/libs/*/*.erc"),
                            {ok, Bytes} <- [file:read_file(Path)],
                            {ok, #{interface := Interface}} <- [ern_interface:read(Bytes)]],
    ?assertNotEqual([], LibraryInterfaces),
    [{File, fun() ->
                {ok, Source} = file:read_file(File),
                {ok, Segment} = ern_namespace:segment(filename:basename(File, ".ern")),
                Namespace = [list_to_atom(Segment)],
                {ok, Declarations} = ern_parser:parse_string(Source),
                ?assertMatch({ok, _, _, _},
                             ern_typecheck:check(Namespace, Declarations, LibraryInterfaces))
            end} || File <- Files].

%% report §5.4, §4.6: a local fn sees the bindings in force at its
%% declaration, so a use before the binding it sees is an error even when
%% an earlier binding of the same name exists
local_fn_shadowed_binding_test() ->
    ?assertMatch({error, [#diagnostic{message = "local function f is used before `let x`" ++ _}]},
                 check("fn m() : Int = { let x = 1; let y = f(); let x = 2;"
                       " fn f() : Int = x; y }\n")),
    ?assertMatch({error, [#diagnostic{message = "local function f is used before `let x`" ++ _}]},
                 check("fn m() : Int = { let x = 1; let y = f(); fn f() : Int = g();"
                       " let x = 2; fn g() : Int = x; y }\n")),
    ?assertMatch({ok, _, _, _},
                 check("fn m() : Int = { let x = 1; fn f() : Int = x; let x = 2; f() + x }\n")),
    %% a parameter or inner binding of the same name is not a reference
    ?assertMatch({ok, _, _, _},
                 check("fn m() : Int = { let y = f(3); let x = 2; fn f(x : Int) : Int = x;"
                       " y + x }\n")).

%% report §5.4, §3.4: a local fn's annotation shapes its type before any
%% use, so a local fn that receives nothing may be used before its
%% declaration in a process body
local_fn_annotation_before_use_test() ->
    ?assertMatch({ok, _, _, _},
                 check("fn m() : Int receiving Never = { let b = 5; let early = k();"
                       " fn k() : Int = b + 1; early }\n")).

%% report §4.2: `Prelude.X` is the prelude's X past a module's own X, as a
%% constructor, a pattern, a type, and a value; a match on the prelude's
%% type is checked against the prelude's constructors; `Prelude.` takes one
%% name, and no type takes the name
prelude_namespace_test() ->
    Shadow = "type Last = Fault | Tabbed\n"
             "type RestartLimit = RestartLimit(name : String)\n"
             "fn send(n : Int) : Int = n\n",
    ?assertEqual("(Reason) -> String",
                 type_of(Shadow ++ "export fn describe(e : Reason) = match e {"
                         " Prelude.Fault(t) -> t | _ -> \"here\" }", describe)),
    ?assertEqual("(RestartLimit) -> Int",
                 type_of(Shadow ++ "export fn size(e : Prelude.RestartLimit) ="
                         " match e { Prelude.RestartLimit(restarts = n) -> n | Unlimited -> 0 }",
                         size)),
    ?assertEqual("() -> Reason",
                 type_of(Shadow ++ "export fn other() = Prelude.Fault(\"x\")", other)),
    ?assertEqual(ok, ok(Shadow ++ "fn f(a : Address(String)) : Unit ="
                        " Prelude.send(a, \"x\")")),
    %% the module's own names are untouched
    ?assertEqual(ok, ok(Shadow ++ "fn g() : Int = send(1)\nfn h() : Last = Fault")),
    ?assertEqual("Prelude.Io.println is written only where the module hides Io.println",
                 refusal("fn f() : Unit = Prelude.Io.println(\"x\")")),
    ?assertEqual("Prelude.Stack.other: Prelude takes one name the prelude declares, as"
                 " `Prelude.Some`, or a name of the prelude's or the standard library's"
                 " namespaces, as `Prelude.Io.println`",
                 refusal("fn f() : Int = Prelude.Stack.other()")),
    ?assertEqual("the prelude declares no constructor Nope", refusal("fn f() = Prelude.Nope")),
    ?assertEqual("Prelude names the prelude, and a type may not take it",
                 refusal("type Prelude = P")).

%% report §4.2: `Prelude.X` is written only where the module hides the
%% prelude's X, by a declaration or a binding; elsewhere `X` is the one way
%% to write it. A regression test: `Prelude.Some` was accepted anywhere
prelude_only_where_hidden_test() ->
    Refused = fun(Name) ->
                  Hidden = case lists:member($., Name) of
                               true -> Name;
                               false -> "the prelude's " ++ Name
                           end,
                  "Prelude." ++ Name ++ " is written only where the module hides " ++ Hidden
              end,
    ?assertEqual(Refused("Some"), refusal("fn f() : Optional(Int) = Prelude.Some(1)")),
    ?assertEqual(Refused("Reason"), refusal("fn f(w : Prelude.Reason) : Int = 0")),
    ?assertEqual(Refused("send"),
                 refusal("fn f(a : Address(Int)) : Unit = Prelude.send(a, 1)")),
    ?assertEqual(Refused("List.size"), refusal("fn f() : Int = Prelude.List.size([1])")),
    %% a parameter hides a prelude value as a declaration does
    ?assertEqual(ok, ok("fn f(send : Int, a : Address(Int)) : Unit ="
                        " Prelude.send(a, send)")).

%% report §11.5, §4.2: a type prints as the module writes it: its own and
%% the prelude's types bare, another module's qualified, a local type
%% that shadows a prelude name qualified
type_names_in_messages_test() ->
    ?assertMatch({error, [#diagnostic{message =
                                  "the argument does not fit f: expected Shape,"
                                  " found Optional(Shape)"}]},
                 check("type Shape = Dot\nfn f(s : Shape) : Int = 1\n"
                       "fn g() : Int = f(Some(Dot))\n")),
    ?assertMatch({error, [#diagnostic{message =
                                  "the argument does not fit f: expected M.Optional,"
                                  " found Optional(Int)"}]},
                 check("type Optional = Nothing\nfn f(o : Optional) : Int = 1\n"
                       "fn g() : Int = f(List.get([1], 0))\n")),
    {ok, Http} = file:read_file("../../../test/fixtures/programs/modules/net/http.ern"),
    {ok, _, Interface, _} = ern_typecheck:check_string(['Net', 'Http'], Http),
    {ok, Declarations} = ern_parser:parse_string("fn f(r : Net.Http.Request) : Int = 1\n"
                                                 "fn g() : Int = f(1)\n"),
    ?assertMatch({error, [#diagnostic{message =
                                  "the argument does not fit f: expected Net.Http.Request,"
                                  " found Int"}]},
                 ern_typecheck:check(['Main'], Declarations, [Interface])).

%% report §11.5, §3.9: a type variable prints under its annotation's name;
%% an unnamed one gets a fresh name that avoids the names in use; a use
%% of a value does not inherit the names of its declaration
variable_names_test() ->
    ?assertEqual("(Map(k=, v), k=) -> Optional(v)",
                 type_of("export fn get(m : Map(k, v), key : k) : Optional(v) = Map.get(m, key)",
                         get)),
    ?assertEqual("(a=, a=) -> Bool",
                 type_of("export fn eq(x : a, y : a) : Bool = x == y", eq)),
    ?assertEqual("() -> Map(a=, b)", type_of("export fn empty() = Map.empty", empty)),
    ?assertEqual("(b, (b) -> a receiving e) -> a receiving e",
                 type_of("export fn ap(x : b, f) = f(x)", ap)),
    ?assertEqual("((a) -> a receiving e, a) -> a receiving e",
                 type_of("export fn twice(f : (a) -> a receiving e, x : a) : a receiving e ="
                         " f(f(x))", twice)).

%% report §4.5, §3.9: a `fn` whose result annotation writes an effect
%% variable that names no parameter's mailbox type, and whose body
%% receives nothing, is refused, the signature without `receiving` being the
%% one spelling, a body that sends among them; a variable a parameter's
%% mailbox type names, or one the body makes process-only, stands; a
%% restriction the body breaks is named first. A regression test of the
%% full review's P12 (2026-10-04); the restriction's case is a regression
%% test written after the code, 2026-10-16, the reply's it replaced having
%% gone with §6.6's obligation
needless_effect_test() ->
    ?assertEqual({"k receives nothing, and `receiving m` names no parameter's mailbox type",
                  "write k's type without `receiving`"},
                 refusal_and_help("fn k() : Int receiving m = 5")),
    ?assertEqual("tell receives nothing, and `receiving m` names no parameter's mailbox type",
                 refusal("fn tell(a : Address(Int)) : Unit receiving m = send(a, 1)\n")),
    ?assertEqual(ok, ok("fn apply(f : () -> Unit receiving m) : Unit receiving m = f()\n"
                        "fn pause(ms : Int) : Unit receiving m = receive { after ms -> Unit }\n"
                        "fn k() : Int = 5\n")),
    ?assertEqual("(Int) -> Int does not support equality (it contains a function, an address"
                 " or a reply), which equal requires of its first argument",
                 refusal("fn equal(a, b) = a == b\n"
                         "fn k(f : (Int) -> Int) : Bool receiving m = equal(f, f)")).

%% report §4.8: an operator is resolved in its definition, and a local fn
%% and a lambda a block `let` binds are definitions of their own, since
%% each is generalized; a lambda passed on belongs to the definition it
%% stands in. A regression test of what the report states
local_helper_over_an_operator_test() ->
    Undetermined = "the operand type of `+` is not determined; annotate it",
    ?assertEqual(Undetermined,
                 refusal("fn f(x : Int) : Int = { fn add(a, b) = a + b; add(x, 1) }")),
    ?assertEqual(Undetermined,
                 refusal("fn f(x : Int) : Int = { let add = fn(a, b) = a + b; add(x, 1) }")),
    ?assertEqual(ok, ok("fn f(x : Int) : Int ="
                        " { fn add(a : Int, b : Int) = a + b; add(x, 1) }")),
    ?assertEqual(ok, ok("fn f(x : Int) : Int = List.foldLeft([x, 1], 0, fn(acc, n) = acc + n)")).

%% report §5.7, Appendix A: a construction is a value and no call, so the
%% pipe applies a bare constructor and does not fill a construction. A
%% regression test: the refusals named the callee or a missing field and
%% not the pipe
pipe_into_construction_test() ->
    Source = "type W = W(a : Int, b : Int)\n",
    ?assertEqual(ok, ok("fn f() : Optional(Int) = 1 |> Some")),
    Refused = "a construction is a value, not a call, and `|>` does not fill it",
    ?assertEqual(Refused, refusal("fn f() : Optional(Int) = 1 |> Some(2)")),
    ?assertEqual(Refused, refusal(Source ++ "fn f() : W = 1 |> W(b = 2)")).

%% report §5.7: the piped value must fit the target's first argument
pipe_type_test() ->
    ?assertEqual("(String) -> Int",
                 type_of("export fn n(s : String) = s |> String.trim |> String.size", n)),
    ?assertMatch("the argument does not fit String.size: expected String, found Int",
                 refusal("fn n() = 1 |> String.size")).

%% report §6.8: a `receiving Never` root is called only where the mailbox
%% is Never; a helper that receives nothing is called from either
never_root_test() ->
    Root = "fn root() : Unit receiving Never = Io.println(\"x\")\n",
    ?assertEqual("root needs mailbox Never, and the mailbox here is Msg",
                 refusal("type Msg = Go\n" ++ Root ++ "fn p() : Unit receiving Msg = root()")),
    ?assertEqual(ok, ok(Root ++ "fn q() : Unit receiving Never = root()")),
    ?assertEqual("() -> Unit receiving Never", type_of(Root ++ "export fn r() = root()", r)),
    ?assertEqual(ok, ok("type Msg = Go\nfn helper() : Unit = Io.println(\"x\")\n"
                        "fn p() : Unit receiving Msg = helper()\n"
                        "fn q() : Unit receiving Never = helper()")).

%%
%% Error placement (report §11.5)
%%

%% The first diagnostic, whole.
diagnostic(Text) ->
    {error, [Diagnostic | _]} = check(Text),
    Diagnostic.

%% report §11.5: a mismatch is reported at the leaf that has the wrong
%% type, not at the enclosing expression, and the label names the
%% declaration that fixed the expectation
leaf_placement_test() ->
    %% the else branch of an `if` in a declared body: the span is the literal
    Branch = diagnostic("fn f(b : Bool) : Int =\n    if b then 1 else \"x\"\n"),
    ?assertEqual("the body does not have the declared result type: expected Int, found String",
                 Branch#diagnostic.message),
    ?assertEqual({2, 22, {2, 25}}, Branch#diagnostic.span),
    ?assertEqual([{{1, 18, {1, 21}}, "result type Int declared here"}], Branch#diagnostic.labels),
    %% the last statement of a block
    LastStatement = diagnostic("fn f() : Int = { let x = 1; \"x\" }\n"),
    ?assertEqual({1, 29, {1, 32}}, LastStatement#diagnostic.span),
    %% a match clause: the second clause against the first
    Clause = diagnostic("fn f(n : Int) = match n { 0 -> 1 | _ -> \"x\" }\n"),
    ?assertEqual("the clauses must have one type: expected Int, found String",
                 Clause#diagnostic.message),
    ?assertEqual({1, 41, {1, 44}}, Clause#diagnostic.span),
    ?assertEqual([{{1, 32, {1, 33}}, "the first clause has type Int"}], Clause#diagnostic.labels),
    %% the else branch against the then branch when nothing outside fixed the type
    ElseBranch = diagnostic("fn f(b : Bool) = if b then 1 else \"x\"\n"),
    ?assertEqual("the branches of `if` must have one type: expected Int, found String",
                 ElseBranch#diagnostic.message),
    ?assertEqual([{{1, 28, {1, 29}}, "the then branch has type Int"}],
                 ElseBranch#diagnostic.labels),
    %% a call argument, at the argument, labeled with the callee's type
    Argument = diagnostic("fn f(x : Int) = x\nfn g() = f(\"x\")\n"),
    ?assertEqual("the argument does not fit f: expected Int, found String",
                 Argument#diagnostic.message),
    ?assertEqual({2, 12, {2, 15}}, Argument#diagnostic.span),
    ?assertEqual([{{2, 10, {2, 11}}, "f : (Int) -> Int"}], Argument#diagnostic.labels),
    %% a binary operator: the right operand, labeled with the left's type
    Operand = diagnostic("fn f() = 1 + \"x\"\n"),
    ?assertEqual({1, 14, {1, 17}}, Operand#diagnostic.span),
    ?assertEqual([{{1, 10, {1, 11}}, "the left operand has type Int"}], Operand#diagnostic.labels),
    %% a list element against the first
    Element = diagnostic("fn f() = [1, \"x\"]\n"),
    ?assertEqual({1, 14, {1, 17}}, Element#diagnostic.span),
    ?assertEqual([{{1, 11, {1, 12}}, "the first element has type Int"}], Element#diagnostic.labels),
    %% an annotated `let` in a block: the value, labeled with the annotation
    Annotated = diagnostic("fn f() = { let x : Int = \"x\"; x }\n"),
    ?assertEqual("the value does not have the declared type: expected Int, found String",
                 Annotated#diagnostic.message),
    ?assertEqual({1, 26, {1, 29}}, Annotated#diagnostic.span),
    ?assertEqual([{{1, 20, {1, 23}}, "declared Int here"}], Annotated#diagnostic.labels),
    %% a pattern against the value matched
    Pattern = diagnostic("fn f(n : Int) = match n { Some(x) -> x }\n"),
    ?assertEqual("the pattern does not fit the value: expected Int, found Optional(a)",
                 Pattern#diagnostic.message),
    ?assertEqual([{{1, 23, {1, 24}}, "the value matched has type Int"}], Pattern#diagnostic.labels),
    %% a `let` pattern against its value, the value's type expected; a
    %% regression test, the two having been printed the other way round
    LetPattern = diagnostic("fn f() : Int = {\n    let #(a, b) = 1;\n    a\n}\n"),
    ?assertEqual("the pattern does not fit the value: expected Int, found #(a, b)",
                 LetPattern#diagnostic.message),
    ?assertEqual({2, 9, {2, 16}}, LetPattern#diagnostic.span),
    ?assertEqual([{{2, 19, {2, 20}}, "the value has type Int"}], LetPattern#diagnostic.labels),
    %% a `<-` pattern against the value inside, at the pattern and labeled
    %% at the value; a regression test too, the error having stood at the
    %% `let`, unlabeled and turned round
    ArrowPattern = diagnostic("fn f(o : Optional(Int)) : Optional(Int) = {\n    let #(a, b) <- o;\n"
                              "    Some(a)\n}\n"),
    ?assertEqual("the pattern does not fit the value inside the sum type: expected Int,"
                 " found #(a, b)", ArrowPattern#diagnostic.message),
    ?assertEqual({2, 9, {2, 16}}, ArrowPattern#diagnostic.span),
    ?assertEqual([{{2, 20, {2, 21}}, "the value inside has type Int"}],
                 ArrowPattern#diagnostic.labels).

%% report §11.5: the message shows the whole types; when they differ
%% inside, the help line names the differing part
differing_part_test() ->
    Diagnostic = diagnostic("fn f(xs : List(Int)) = xs\nfn g() = f([\"x\"])\n"),
    ?assertEqual("the argument does not fit f: expected List(Int), found List(String)",
                 Diagnostic#diagnostic.message),
    ?assertEqual("the types differ at Int and String", Diagnostic#diagnostic.help),
    ?assertEqual(undefined, (diagnostic("fn f() = 1 + \"x\"\n"))#diagnostic.help).

%% report §11.5, §3.4: an effect error names the `receive`, the `self` or
%% the callee that receives, and the function or the guard whose type names
%% no mailbox, labels the annotation that made it so, and says what to do
effect_placement_test() ->
    Self = diagnostic("fn main() : Unit = { let a = self(); send(a, 1) }\n"),
    ?assertEqual("self needs a mailbox, and main receives nothing", Self#diagnostic.message),
    ?assertEqual({1, 30, {1, 36}}, Self#diagnostic.span),
    ?assertEqual([{{1, 13, {1, 17}},
                   "`: Unit` without `receiving` declares that main receives nothing"}],
                 Self#diagnostic.labels),
    ?assertEqual("give main its mailbox type with `receiving`", Self#diagnostic.help),
    Guard = diagnostic("fn wait() : Bool receiving m = receive { after 1 -> true }\n"
                       "fn f(n : Int) : Int receiving Never = match n {"
                       " k when wait() -> 1 | _ -> 0 }\n"),
    ?assertEqual("wait needs a mailbox, and a guard receives nothing", Guard#diagnostic.message),
    ?assertEqual([{{2, 56, {2, 62}}, "a guard receives nothing (report §5.9)"}],
                 Guard#diagnostic.labels),
    ?assertEqual("compute the value before the match", Guard#diagnostic.help),
    Receive = diagnostic("fn f() : Unit = receive { after 1 -> Unit }\n"),
    ?assertEqual("`receive` needs a mailbox, and f receives nothing", Receive#diagnostic.message),
    ?assertEqual("give f its mailbox type with `receiving`", Receive#diagnostic.help),
    Declared = diagnostic("type Msg = Go\n"
                          "fn root() : Unit receiving Never = receive { after 1 -> Unit }\n"
                          "fn p() : Unit receiving Msg = root()\n"),
    ?assertEqual([{{3, 25, {3, 28}}, "p is declared `receiving Msg` here"}],
                 Declared#diagnostic.labels),
    ?assertEqual(undefined, Declared#diagnostic.help),
    %% a lambda's own annotation is the origin inside it
    Lambda = diagnostic("fn f() : Unit receiving Never ="
                        " { let g = fn() : Unit = receive { after 1 -> Unit }; g() }\n"),
    ?assertEqual("`receive` needs a mailbox, and the lambda receives nothing",
                 Lambda#diagnostic.message),
    ?assertEqual("give the lambda its mailbox type with `receiving`", Lambda#diagnostic.help).

%% report §11.5, §3.4: a regression test. After a local fn or an annotated
%% lambda, an effect error in the enclosing function names that function
%% and labels its own annotation, not the nested definition's. Not
%% covered: the other scopes that set the origin, a guard and a size
%% expression, which effect_placement_test and the bitstring tests reach.
effect_origin_is_restored_after_a_nested_definition_test() ->
    AfterFn = diagnostic("fn f() : Unit = { fn g() : Int = 1; receive { after 1 -> Unit } }\n"),
    ?assertEqual("`receive` needs a mailbox, and f receives nothing", AfterFn#diagnostic.message),
    ?assertEqual([{{1, 10, {1, 14}},
                   "`: Unit` without `receiving` declares that f receives nothing"}],
                 AfterFn#diagnostic.labels),
    AfterLambda = diagnostic("fn f() : Unit ="
                             " { let g = fn(x : Int) : Int = x; let a = self(); send(a, 1) }\n"),
    ?assertEqual("self needs a mailbox, and f receives nothing", AfterLambda#diagnostic.message),
    ?assertEqual("give f its mailbox type with `receiving`", AfterLambda#diagnostic.help).

%% report §11.5: an unannotated lambda's mailbox is its own, so an effect
%% error inside it labels no annotation, not the enclosing definition's.
%% A regression test: the label named `main is declared with Never`, or
%% `run` pure, where neither annotation had fixed the lambda's mailbox.
effect_origin_of_an_unannotated_lambda_test() ->
    Helpers = "fn g() : Unit receiving String = Unit\nfn h() : Unit receiving Int = Unit\n",
    InNever = diagnostic(Helpers ++ "fn main() : Unit ="
                         " { let k = fn() = { g(); h() }; Unit }\n"),
    ?assertEqual("h needs mailbox Int, and the mailbox here is String", InNever#diagnostic.message),
    ?assertEqual([], InNever#diagnostic.labels),
    InPure = diagnostic(Helpers ++ "fn run() : Int = { let k = fn() = { g(); h() }; 1 }\n"),
    ?assertEqual([], InPure#diagnostic.labels).

%% report §4.8, §3.4: an operator resolved at the end of its definition,
%% once its operand type is known, calls its member, which receives
%% nothing, in a process body and in one that receives nothing alike, for a
%% top-level and a local fn. It was written against a member with a
%% mailbox effect, which §4.8 now refuses at its declaration
%% (operator_member_shape_test). Not covered: `negate`, which takes the
%% same path.
deferred_operator_calls_its_member_test() ->
    Source = "type V = V(Int)\nfn V.+(V(a), V(b)) : V = V(a + b)\n",
    ?assertEqual(ok,
                 ok(Source ++ "fn f(x, y) : V receiving Never ="
                    " { let z = x + y; let V(_) = x; z }\n")),
    ?assertEqual(ok, ok(Source ++ "fn f() : V receiving Never = {\n"
                        "    fn g(x, y) = { let z = x + y; let V(_) = x; z };\n"
                        "    g(V(1), V(2))\n"
                        "}\n")),
    ?assertEqual(ok, ok(Source ++ "fn f(x, y) : V = { let z = x + y; let V(_) = x; z }\n")).

%% report §3.10, §11.5: a comparison on a value a later use makes a function
%% is reported at the comparison, which needed the equality. A regression
%% test: it was reported at the later call, saying it was compared there
comparison_reported_where_it_stands_test() ->
    {error, [#diagnostic{span = Span, message = Message} | _]} =
        check("fn k(g) = {\n    let _ = g == g;\n    g(1)\n}\n"),
    ?assertMatch({2, 13, _}, ern_diagnostic:span(Span)),
    ?assertMatch("(Int) -> a" ++ _, Message),
    ?assertNotEqual(nomatch, string:find(Message, "but it is compared here")).

%% report §3.10, §11.5: a map keyed by addresses is an error at its first
%% operation, at the argument that gives the key, as the guide teaches it.
%% A regression test: the error stood at the map's last operation, a
%% `Map.size` after the `Map.put` that gave it the key
address_key_at_first_operation_test() ->
    {error, [#diagnostic{span = Span} | _]} =
        check("type Msg = Go\n"
              "fn main() : Unit receiving Msg = {\n"
              "    let m = Map.put(Map.empty, self(), 1);\n"
              "    Io.println(Int.toString(Map.size(m)))\n"
              "}\n"),
    ?assertMatch({3, 32, _}, ern_diagnostic:span(Span)).

%% report §3.10, §4.8: a regression test. An operator resolved at the end
%% of its definition keeps its member's equality constraint, as one
%% resolved at once does.
deferred_operator_keeps_its_members_equality_test() ->
    Source = "type Box(a) = Box(a)\n"
             "fn Box.+(Box(x), Box(y)) : Box(a) = if x == y then Box(x) else Box(y)\n",
    Message = "(Int) -> Int does not support equality (it contains a function, an address or"
              " a reply), but it is compared here",
    ?assertEqual(Message,
                 refusal(Source ++ "fn f(p : Box((Int) -> Int), q) : Box((Int) -> Int) = p + q\n")),
    ?assertEqual(Message, refusal(Source ++ "fn f(p, q) : Box((Int) -> Int) = {\n"
                                  "    let z = p + q;\n"
                                  "    let _ : Box((Int) -> Int) = p;\n"
                                  "    z\n"
                                  "}\n")).

%%
%% Bitstrings (report §5.11)
%%

%% report §5.11: a numeric literal that does not fit a segment of constant
%% width is a compile-time error, in a construction and in a pattern; one
%% that fits, and a computed value, are not refused. A regression test: a
%% literal faulted at construction and never matched
literal_does_not_fit_test() ->
    Byte = "the literal does not fit an unsigned segment of 8 bits, which holds 0 to 255",
    ?assertEqual(Byte, refusal("fn f() : Bytes = <<256>>")),
    ?assertEqual(Byte, refusal("fn f() : Bytes = <<-1>>")),
    ?assertEqual("the literal does not fit a signed segment of 8 bits, which holds -128 to 127",
                 refusal("fn f() : Bytes = <<-129:signed>>")),
    ?assertEqual("the literal does not fit a float segment of 16 bits, whose largest finite"
                 " value is 65504.0", refusal("fn f() : Bytes = <<70000.0:size(16)-float>>")),
    ?assertEqual(Byte, refusal("fn f(b : Bytes) : Int = match b { <<256>> -> 1 | _ -> 0 }")),
    ?assertEqual(ok, ok("fn f() : Bytes = <<255, -1:signed, 65504.0:size(16)-float>>")),
    ?assertEqual(ok, ok("fn f(n : Int) : Bytes = <<n + 256>>")).

%% report §5.11: a construction is Bytes; each segment's value has its
%% specifier's type; the specifiers have their defaults and cannot
%% conflict; a constant bit count is a multiple of 8
bitstring_construction_test() ->
    ?assertEqual("(Int, Bytes) -> Bytes",
                 type_of("export fn frame(len : Int, body : Bytes) : Bytes ="
                         " <<len:size(16)-big, body:bytes>>", frame)),
    ?assertEqual("(Float, Char, Bytes) -> Bytes",
                 type_of("export fn f(x, c, b) = <<x:float, c:utf8, b:size(2)-bytes, 1:size(4),"
                         " 2:size(4)>>", f)),
    ?assertEqual("() -> Bytes", type_of("export fn f() = <<>>", f)),
    ?assertEqual("an `int` segment: expected Int, found String", refusal("fn f() = <<\"a\">>")),
    ?assertEqual("a `bytes` segment: expected Bytes, found Int", refusal("fn f() = <<1:bytes>>")),
    ?assertEqual("the size of a segment: expected Int, found Bool",
                 refusal("fn f() = <<1:size(true)>>")),
    ?assertEqual("the bitstring is 12 bits, not a multiple of 8",
                 refusal("fn f() = <<1, 2:size(4)>>")),
    ?assertEqual(ok, ok("fn f(n : Int) = <<1:size(4), 2:size(n)>>")),
    ?assertEqual("conflicting bitstring specifiers `int` and `float`",
                 refusal("fn f() = <<1:int-float>>")),
    ?assertEqual("conflicting bitstring specifiers `big` and `little`",
                 refusal("fn f() = <<1:big-little>>")),
    ?assertEqual("a utf segment has no size", refusal("fn f() = <<'a':utf8-size(8)>>")),
    ?assertEqual("a float segment is 16, 32, or 64 bits",
                 refusal("fn f() = <<1.0:size(8)-float>>")).

%% report §5.11: `signed` and `unsigned` apply to an `int` segment only;
%% `big` and `little` to an `int`, `float`, `utf16` or `utf32` segment
%% only; in a construction and in a pattern alike. The defaults the checker
%% hands the emitter are big and unsigned. A regression test, written after
%% the fix; the defaults' bytes at run time (`<<258:size(16)>>` is
%% `<<1, 2>>`, `<<x>>` over 255 binds 255) are not covered here.
bitstring_specifier_kinds_test() ->
    ?assertEqual("`signed` applies to an `int` segment only, not a `float` one",
                 refusal("fn f(x : Float) = <<x:float-signed>>")),
    ?assertEqual("`unsigned` applies to an `int` segment only, not a `bytes` one",
                 refusal("fn f(x : Bytes) = <<x:unsigned-bytes>>")),
    ?assertEqual("`signed` applies to an `int` segment only, not a `utf8` one",
                 refusal("fn f(c : Char) = <<c:utf8-signed>>")),
    ?assertEqual("`little` applies to an `int`, `float`, `utf16` or `utf32` segment, not a"
                 " `utf8` one", refusal("fn f(c : Char) = <<c:utf8-little>>")),
    ?assertEqual("`little` applies to an `int`, `float`, `utf16` or `utf32` segment, not a"
                 " `bytes` one", refusal("fn f(x : Bytes) = <<x:bytes-little>>")),
    ?assertEqual("`big` applies to an `int`, `float`, `utf16` or `utf32` segment, not a"
                 " `bytes` one",
                 refusal("fn f(b : Bytes) : Int = match b { <<n, _:bytes-big>> -> n | _ -> 0 }")),
    ?assertEqual(ok, ok("fn f(x : Int, y : Float, c : Char) = <<x:signed-little, x:unsigned,"
                        " y:float-little, c:utf16-little, c:utf32-big, c:utf8>>")),
    ?assertEqual(ok, ok("fn f(b : Bytes) : Int = match b {"
                        " <<n:size(16)-signed-little, _:bytes>> -> n | _ -> 0 }")),
    ?assertMatch({ok, #{kind := int, size := {const, 8}, endian := big, sign := unsigned}},
                 ern_bitspec:spec([])).

%% report §5.11: a pattern binds each segment at its type; a size sees the
%% earlier segments and receives nothing; a segment pattern is a variable, `_`, or
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
                 refusal("fn f(b : Bytes) = match b { <<n:bytes, x:size(n)>> -> x | _ -> 0 }")),
    ?assertEqual("`receive` needs a mailbox, and a size expression receives nothing",
                 refusal("fn f(b : Bytes) : Int receiving Never = match b {"
                         " <<x:size(receive { after 1 -> 8 })>> -> x | _ -> 0 }")),
    ?assertEqual("a segment pattern is a variable, `_`, or a literal",
                 refusal("fn f(b : Bytes) = match b { <<Some(x)>> -> x | _ -> 0 }")),
    ?assertEqual("a `bytes` segment without a size takes the rest, so it is the last segment",
                 refusal("fn f(b : Bytes) = match b { <<a:bytes, c:bytes>> -> a | _ -> b }")),
    ?assertEqual("the pattern is 4 bits, not a multiple of 8",
                 refusal("fn f(b : Bytes) = match b { <<x:size(4)>> -> x | _ -> 0 }")),
    ?assertMatch("match on Bytes is not exhaustive; missing _",
                 refusal("fn f(b : Bytes) = match b { <<>> -> 0 | <<_, r:bytes>> -> 1 }")),
    ?assertEqual("a `let` pattern must be irrefutable",
                 refusal("fn f(b : Bytes) = { let <<x>> = b; x }")).

%% report §6.3: a receive guard is a guard expression, and calls nothing;
%% a match guard is any Bool expression. The help offers a `let` before
%% the `receive` first, which keeps the message in the mailbox, a regression
%% test of the help, written after it (the release review before 0.4.0
%% found the help to `match` alone, which takes the message out)
receive_guard_test() ->
    Source = "type Msg = N(Int) | Stop\n",
    ?assertEqual(ok, ok(Source ++ "fn big(k : Int) : Bool = k > 100\n"
                        "fn loop(limit : Int, go : Bool) : Unit receiving Msg = receive {"
                        " N(k) when (k > limit || k == -1) && go && k != 7 -> loop(limit, go)"
                        " | Stop -> Unit | N(_) -> Unit }")),
    ?assertEqual(ok, ok(Source ++ "fn big(k : Int) : Bool = k > 100\n"
                        "fn f(m : Msg) : Unit ="
                        " match m { N(k) when big(k) -> Unit | _ -> Unit }")),
    Diagnostic = diagnostic(Source ++ "fn big(k : Int) : Bool = k > 100\n"
                            "fn loop() : Unit receiving Msg ="
                            " receive { N(k) when big(k) -> Unit | _ -> Unit }"),
    ?assertEqual("a `receive` guard combines `true`, `false`, Bool variables, and comparisons"
                 " with `!`, `&&`, and `||`, and calls nothing", Diagnostic#diagnostic.message),
    ?assertEqual("bind what the guard needs with a `let` before the `receive` and compare"
                 " that; or receive the message and `match` it, which takes it out of the"
                 " mailbox", Diagnostic#diagnostic.help).

%% report §6.3: each form of a guard expression: `true`, `false`, a Bool
%% operand, `!` before a guard expression, and a comparison whose operands
%% are negative numeric literals and nullary constructors as well as
%% variables and literals
receive_guard_forms_test() ->
    Head = "type Msg = N(Int) | F(Float) | O(Ordering)\n"
           "fn loop(flag : Bool) : Unit receiving Msg = receive { ",
    Tail = " -> Unit | _ -> Unit }",
    Accepted = ["N(_) when true", "N(_) when false", "N(_) when flag", "N(_) when !flag",
                "N(k) when !(k > 1)", "N(k) when !(!(k == 1)) && !flag || !false",
                "N(k) when k > -1", "F(y) when y < -1.5", "F(y) when -1.5 != y",
                "O(o) when o == Less"],
    [?assertEqual({Guard, ok}, {Guard, ok(Head ++ Guard ++ Tail)}) || Guard <- Accepted].

%% report §6.3: a comparison's operands are operands, so a comparison, a
%% negation, arithmetic, or a negated variable is not one; a top-level `let`
%% is one, which the `receive` reads before it waits. The top-level half is
%% a regression test: such a binding was refused
receive_guard_refused_test() ->
    Head = "type Msg = N(Int)\nlet limit = 5\nlet ready = true\n"
           "fn loop(flag : Bool, go : Bool, m : Int) : Unit receiving Msg = receive { ",
    Tail = " -> Unit | _ -> Unit }",
    Operand = "a comparison in a `receive` guard compares variables, literals, and nullary"
              " constructors",
    Refused = [{"N(_) when !flag == true", Operand},
               {"N(_) when flag == go == true", Operand},
               {"N(k) when k + 1 > 2", Operand},
               {"N(k) when k > -m", Operand},
               {"N(k) when Int.compare(k, m) == Less",
                Operand}],
    [?assertEqual({Guard, Expected}, {Guard, refusal(Head ++ Guard ++ Tail)})
     || {Guard, Expected} <- Refused],
    [?assertEqual({Guard, ok}, {Guard, ok(Head ++ Guard ++ Tail)})
     || Guard <- ["N(k) when k > limit", "N(_) when !ready", "N(k) when k > limit && ready"]].

%% report §6.3, §3.10: `<`, `<=`, `>`, and `>=` in a receive guard order
%% Int, Float, String, and Char only, not a user type with its own compare
receive_guard_ordering_test() ->
    ?assertEqual("a `receive` guard orders only Int, Float, String, and Char, not Vec",
                 refusal("export type Vec = Vec(Int)\n"
                         "export fn Vec.compare(Vec(a), Vec(b)) : Ordering = Int.compare(a, b)\n"
                         "type M = Go(Vec)\n"
                         "fn loop() : Unit receiving M = receive { Go(v) when v < Vec(0) -> Unit"
                         " | _ -> Unit }")).

%% report §5.11: a size in a pattern is a variable, a literal, or +, -, *
%% of them
bitstring_size_shape_test() ->
    ?assertEqual(ok, ok("fn f(b : Bytes, n : Int) = match b {"
                        " <<k, rest:size(k * 8 + n - 1)-bytes>> -> rest | _ -> b }")),
    ?assertEqual("a size in a pattern is a variable, a top-level `let`, an Int literal, or `+`,"
                 " `-`, `*` of them",
                 refusal("fn f(b : Bytes) = match b {"
                         " <<n, rest:size(List.size([n]))-bytes>> -> rest | _ -> b }")),
    ?assertEqual("a size in a pattern is a variable, a top-level `let`, an Int literal, or `+`,"
                 " `-`, `*` of them",
                 refusal("fn f(b : Bytes) = match b { <<n, rest:size(n / 2)-bytes>> -> rest"
                         " | _ -> b }")).

%% report §5.11: a pattern's size may name a block `let`'s variable or one a
%% lambda captures, as a parameter, and a top-level `let`, of this module or
%% another; one bound elsewhere in the same pattern, outside the bitstring,
%% is not in scope, and the error says so. A regression test for the
%% variables: the checker conformed before it was written. It does not
%% cover a receive clause's pattern, which the emitter's test runs.
bitstring_size_variables_test() ->
    ?assertEqual(ok, ok("fn f(n : Int, b : Bytes) : Int ="
                        " { let k = n; match b { <<x:size(k)>> -> x | _ -> 0 } }")),
    ?assertEqual(ok, ok("fn f(n : Int) : (Bytes) -> Int ="
                        " fn(b) = match b { <<x:size(n)>> -> x | _ -> 0 }")),
    ?assertEqual(ok, ok("let k = 8\nfn f(b : Bytes) : Int ="
                        " match b { <<x:size(k)>> -> x | _ -> 0 }")),
    ?assertEqual(ok, ok("let k = 8\nfn f(b : Bytes) : Int ="
                        " match b { <<x:size(k * 2 - -k)>> -> x | _ -> 0 }")),
    ?assertEqual("k is bound in the same pattern, and a size names a variable an earlier segment"
                 " of its bitstring binds, or one bound before the pattern",
                 refusal("fn f(p : #(Int, Bytes)) : Int ="
                         " match p { #(k, <<x:size(k)-bytes>>) -> k | _ -> 0 }")).

%% report §5.9, §5.11: a bitstring nested in a constructor covers nothing,
%% as one at the top does not; a wildcard at its place completes the match.
%% A regression test: the checker conformed before it was written. It does
%% not cover a bitstring inside a tuple.
nested_bitstring_coverage_test() ->
    ?assertEqual("match on Optional(Bytes) is not exhaustive; missing Some(_)",
                 refusal("fn f(x : Optional(Bytes)) : Int ="
                         " match x { Some(<<n>>) -> n | None -> 0 }")),
    ?assertEqual(ok, ok("fn f(x : Optional(Bytes)) : Int ="
                        " match x { Some(<<n>>) -> n | None -> 0 | Some(_) -> 1 }")).

%% report §5.11: a specifier's name is an ordinary identifier outside a
%% specifier list, so a value, a parameter and a pattern's variable may be
%% named `size`, `int` or `little`. A regression test: the checker
%% conformed before it was written; the parser's half is in
%% ern_parser_tests.
specifier_names_are_identifiers_test() ->
    ?assertEqual("(Int, Int) -> Bytes",
                 type_of("export fn build(size : Int, int : Int) : Bytes ="
                         " <<size:size(int)-big>>", build)),
    ?assertEqual("(Bytes) -> Int",
                 type_of("export fn parse(b : Bytes) : Int = match b {"
                         " <<size:size(16), little:bytes>> -> size | _ -> 0 }", parse)).

%% report §8.5, §4.2: a name bound inside a body — a pattern's variable,
%% a lambda's parameter, a block's binding — shadows a top-level one, so
%% it is no reference to it and makes no cycle. A `let` that calls such a
%% function was reported as depending on itself.
shadowed_name_is_no_reference_test() ->
    ?assertMatch({ok, _, _, _},
                 check("let one = pick([1])\n"
                       "fn pick(xs : List(Int)) : Int ="
                       " match xs { [one] -> one | _ -> 0 }\n")),
    ?assertMatch({ok, _, _, _},
                 check("let twice = apply(fn(n) = n * 2)\n"
                       "fn apply(f : (Int) -> Int) : Int = f(21)\n"
                       "fn other() : Int = { let twice = 2; twice }\n")),
    %% a real cycle is still a cycle
    ?assertEqual("the initializer of a depends on itself, through b",
                 refusal("let a = b()\nfn b() : Int = a\n")).

%%
%% Requirements (report §4.9), derived members (§3.5) and the fill (§5.6)
%%

%% report §4.9: a requirement names members of the signature's type
%% variables, which the body applies, and which an operator on the
%% variable resolves to; it ends the declaration's printed type (§11.5);
%% written after the code
requirement_in_the_body_test() ->
    ?assertEqual("(List(a)) -> List(a) needs a.compare",
                 type_of("export fn f(list : List(a)) : List(a) needs a.compare =\n"
                         "    List.sort(list, a.compare)\n", f)),
    ?assertEqual("(a, a) -> Bool needs a.compare",
                 type_of("export fn f(x : a, y : a) : Bool needs a.compare = x < y\n", f)),
    ?assertEqual("(a) -> a needs a.negate",
                 type_of("export fn f(x : a) : a needs a.negate = -x\n", f)),
    ?assertEqual("(a, a) -> a needs a.+, a.*",
                 type_of("export fn f(x : a, y : a) : a needs a.+, a.* = x * y + a.+(x, y)\n", f)).

%% report §4.9: a requirement's variable stands in a value position of the
%% signature; written after the code
requirement_variable_test() ->
    ?assertEqual("b is no type variable of the signature",
                 refusal("fn f(x : a) : a needs b.compare = x")),
    %% an effect variable's own message: a regression test
    ?assertEqual({"e is an effect variable, and a requirement names a type variable in a value"
                  " position", undefined},
                 refusal_and_help("fn f(x : a) : a receiving e needs e.compare = x")),
    ?assertEqual(ok, ok("fn f() : List(a) needs a.compare = []")).

%% report §4.9, §11.5: a requirement names a variable's member once, the
%% second naming refused and the first labeled, an operator's and a local
%% fn's alike; one member on two variables is no repetition. Written with
%% the rule, which the report had been silent on
requirement_named_twice_test() ->
    #diagnostic{message = Message, span = Span, labels = Labels} =
        diagnostic("fn largest(list : List(a)) : Optional(a) needs a.compare, a.compare =\n"
                   "    List.last(list)\n"),
    ?assertEqual("the requirement names a.compare twice", Message),
    ?assertMatch({1, 59, _}, Span),
    ?assertMatch([{{1, 48, _}, "first named here"}], Labels),
    ?assertEqual("the requirement names a.+ twice",
                 refusal("fn sum(x : a, y : a) : a needs a.+, a.+ = a.+(x, y)\n")),
    ?assertEqual("the requirement names a.compare twice",
                 refusal("fn f() : Int = {\n"
                         "    fn same(x : a) : a needs a.compare, a.compare = x;\n"
                         "    same(1)\n"
                         "}\n")),
    ?assertEqual(ok, ok("fn f(x : a, y : b) : a needs a.compare, b.compare = x\n")).

%% report §4.9, §4.8: a member the requirement does not name is a type
%% error, written, by an operator, or by its type variable without a
%% requirement; written after the code
member_not_declared_test() ->
    ?assertEqual({"f does not declare a.+", "add `needs a.+` to f's signature"},
                 refusal_and_help("fn f(x : a, y : a) : a needs a.compare = a.+(x, y)")),
    ?assertEqual({"`<` needs a.compare, which f does not declare",
                  "add `needs a.compare` to f's signature"},
                 refusal_and_help("fn f(x : a, y : a) : Bool = x < y")),
    ?assertEqual("`-` needs a.negate, which f does not declare",
                 refusal("fn f(x : a) : a = -x")),
    ?assertEqual({"unknown name a",
                  "a is a type variable of the signature; its member, as a.compare, is named"
                  " under a requirement, needs a.compare"},
                 refusal_and_help("fn f(x : a, y : a) : Ordering = a.compare(x, y)")).

%% report §4.9: `a.show` names nothing in a body, and the help for it names
%% `Io.show`, which writes the value under `needs a.show`. A regression
%% test of the principles review's K12 (2026-10-09): the help named
%% `a.compare`, a member, where the declaration already wrote `needs a.show`
show_named_in_body_test() ->
    ?assertEqual({"unknown name a",
                  "a.show names nothing in a body; under needs a.show, write the value with"
                  " Io.show (report §4.9)"},
                 refusal_and_help("fn describe(x : a) : String needs a.show = a.show(x)")),
    ?assertEqual(ok, ok("fn describe(x : a) : String needs a.show = Io.show(x)")).

%% report §11.5, §4.9, §4.8: a field read on a value of a type variable of
%% the signature names the variable, whose values have no field, and the
%% declaration whose signature writes it; where the requirement names the
%% member at the variable, the help writes the member on the variable, and
%% where it names none of the field's name, or the field is `show`, which
%% is no member, there is none. A regression test, written after the code:
%% the read asked for an annotation, which does not help (the tour's spike,
%% docs/findings.md's S1); it does not cover the prompt
member_read_on_a_value_test() ->
    Tally = "export abstract type Tally(k) = Tally(Map(k, Int))\n"
            "export fn report(Tally(counts)) : List(#(k, Int)) needs k.compare =\n",
    ?assertEqual({"a value of k, a type variable of report's signature, has no field compare",
                  "under `needs k.compare`, write the member on the type variable,"
                  " `k.compare(..., ...)`"},
                 refusal_and_help(Tally ++ "    List.sort(Map.toList(counts),"
                                           " fn(#(a, _), #(b, _)) = a.compare(b))\n")),
    ?assertEqual(ok, ok(Tally ++ "    List.sort(Map.toList(counts),"
                                 " fn(#(a, _), #(b, _)) = k.compare(a, b))\n")),
    ?assertEqual({"a value of a, a type variable of f's signature, has no field negate",
                  "under `needs a.negate`, write the member on the type variable, `a.negate(...)`"},
                 refusal_and_help("fn f(x : a) : a needs a.negate = x.negate()")),
    %% a local fn's own requirement, and the enclosing one's in force in it
    ?assertEqual("under `needs b.compare`, write the member on the type variable,"
                 " `b.compare(..., ...)`",
                 element(2, refusal_and_help("fn f(list : List(a)) : Int = {\n"
                                             "    fn g(x : b, y : b) : Ordering needs b.compare ="
                                             " x.compare(y);\n"
                                             "    0\n"
                                             "}\n"))),
    ?assertEqual({"a value of a, a type variable of f's signature, has no field compare",
                  "under `needs a.compare`, write the member on the type variable,"
                  " `a.compare(..., ...)`"},
                 refusal_and_help("fn f(list : List(a)) : List(a) needs a.compare = {\n"
                                  "    fn g(x : a, y : a) : Ordering = x.compare(y);\n"
                                  "    List.sort(list, g)\n"
                                  "}\n")),
    ?assertEqual({"a value of a, a type variable of f's signature, has no field compare",
                  undefined},
                 refusal_and_help("fn f(x : a, y : a) : Ordering needs a.+ = x.compare(y)")),
    ?assertEqual({"a value of a, a type variable of f's signature, has no field show",
                  undefined},
                 refusal_and_help("fn f(x : a) : String needs a.show = x.show()")),
    ?assertEqual({"a value of a, a type variable of f's signature, has no field x", undefined},
                 refusal_and_help("fn f(p : a) : Int = p.x")).

%% report §4.9: a call writes nothing for a requirement: at a known type
%% the compiler supplies the type's member, at a type variable the
%% enclosing requirement does, and otherwise the call is refused; written
%% after the code
requirement_supplied_test() ->
    ?assertEqual(ok, ok("fn f() : List(Int) = OrderedSet.toList(OrderedSet.fromList([3, 1]))")),
    ?assertEqual(ok, ok("fn unique(list : List(a)) : List(a) needs a.compare =\n"
                        "    OrderedSet.toList(OrderedSet.fromList(list))")),
    ?assertEqual({"fromList needs a.compare, which unique does not declare",
                  "add `needs a.compare` to unique's signature"},
                 refusal_and_help("fn unique(list : List(a)) : List(a) =\n"
                         "    OrderedSet.toList(OrderedSet.fromList(list))")),
    ?assertEqual("fromList needs List(Int).compare, and List(Int) has no compare",
                 refusal("fn f() : Int = OrderedSet.size(OrderedSet.fromList([[1]]))")),
    %% the member's shape, its result the type itself
    ?assertEqual({"total needs Vec.+ : (Vec, Vec) -> Vec, and Vec.+ answers Float",
                  "a function over an operation of another shape takes it as a parameter"},
                 refusal_and_help("type Vec = Vec(Float)\n"
                                  "fn Vec.+(Vec(a) : Vec, Vec(b) : Vec) : Float = a + b\n"
                                  "fn total(list : List(a), zero : a) : a needs a.+ =\n"
                                  "    List.foldLeft(list, zero, a.+)\n"
                                  "fn f() : Vec = total([Vec(1.0)], Vec(0.0))")),
    %% a top-level let declares no requirement
    ?assertEqual({"fromList needs a.compare, which a top-level let cannot declare",
                  "declare a `fn` with `needs a.compare`"},
                 refusal_and_help("let f = OrderedSet.fromList")).

%% report §4.9: the requirement in force is the enclosing `fn` declaration's,
%% in a lambda and in a block fn that shares its variables; a let-bound
%% lambda's own variable is generalized before a call ties it to the
%% signature's, and a block fn declares its own; written after the code
requirement_reach_test() ->
    ?assertEqual(ok, ok("fn f(list : List(a)) : List(List(a)) needs a.compare =\n"
                        "    List.map(list, fn(x) = OrderedSet.toList(OrderedSet.fromList([x])))")),
    ?assertEqual(ok, ok("fn f(list : List(a)) : Optional(a) needs a.compare = {\n"
                        "    fn larger(x : a, y : a) : a = if x < y then y else x;\n"
                        "    List.find(list, fn(x) = larger(x, x) == x)\n}")),
    ?assertEqual(ok, ok("fn f(list : List(a)) : List(a) needs a.compare = {\n"
                        "    fn sorted(xs : List(b)) : List(b) needs b.compare =\n"
                        "        OrderedSet.toList(OrderedSet.fromList(xs));\n"
                        "    sorted(list)\n}")),
    ?assertEqual({"fromList needs a.compare, at a type variable no requirement can name",
                  "annotate it with a type variable of f's signature, and add the requirement"
                  " there"},
                 refusal_and_help("fn f(list : List(Int)) : Int = {\n"
                                  "    let build = fn(xs) = OrderedSet.fromList(xs);\n"
                                  "    OrderedSet.size(build(list))\n}")).

%% report §4.9: a declaration with a requirement taken as a value is the
%% function with its members supplied; written after the code
requirement_as_a_value_test() ->
    ?assertEqual(ok, ok("fn putAll(list : List(a)) : OrderedSet.Set(a) needs a.compare =\n"
                        "    List.foldLeft(list, OrderedSet.empty, OrderedSet.put)")),
    ?assertEqual(ok, ok("fn f() : (OrderedSet.Set(Int), Int) -> OrderedSet.Set(Int) ="
                        " OrderedSet.put")).

%% report §3.5, §4.9: a type that derives compare gains the member, ordered by
%% constructor then field, with the requirement its comparison reaches; an
%% operator on it resolves to it, and members supply members; written after
%% the code
derives_test() ->
    Types = "export type Date = Date(year : Int, month : Int, day : Int) derives compare\n"
            "export type Pair(a, b) = Pair(first : a, second : b) derives compare\n"
            "export type Tree(a) = Leaf | Node(left : Tree(a), value : a, right : Tree(a))"
            " derives compare\n",
    ?assertEqual("(M.Date, M.Date) -> Ordering", member_type_of(Types, 'Date', compare)),
    ?assertEqual("(M.Pair(a, b), M.Pair(a, b)) -> Ordering needs a.compare, b.compare",
                 member_type_of(Types, 'Pair', compare)),
    ?assertEqual("(M.Tree(a), M.Tree(a)) -> Ordering needs a.compare",
                 member_type_of(Types, 'Tree', compare)),
    ?assertEqual(ok, ok(Types ++ "fn earlier(x : Date, y : Date) : Bool = x < y\n"
                        "fn f(x : Pair(Int, String)) : Bool = x > x\n"
                        "fn g(x : Pair(a, b)) : Bool needs a.compare, b.compare = x <= x\n")),
    ?assertEqual("fromList needs Pair(List(Int), Int).compare, and List(Int) has no compare",
                 refusal(Types ++ "fn f(x : Pair(List(Int), Int)) : Int =\n"
                         "    OrderedSet.size(OrderedSet.fromList([x]))\n")),
    %% a parameter the comparison does not reach is not required
    ?assertEqual("(M.Holder(a), M.Holder(a)) -> Ordering",
                 member_type_of("export type Wrap(a) = Wrap(Int)\n"
                                "export fn Wrap.compare(Wrap(x) : Wrap(a), Wrap(y) : Wrap(a))"
                                " : Ordering =\n"
                                "    Int.compare(x, y)\n"
                                "export type Holder(a) = Holder(Wrap(a)) derives compare\n",
                                'Holder', compare)).

%% report §3.5: a field whose type has no compare is an error at the
%% declaration, and a type derives no compare it declares; written after the
%% code
derives_refused_test() ->
    ?assertEqual("Date.compare cannot be derived: Optional(Int) has no compare",
                 refusal("type Date = Date(year : Int, at : Optional(Int)) derives compare")),
    ?assertEqual("T.compare cannot be derived: #(Int, Int) has no compare",
                 refusal("type T = T(#(Int, Int)) derives compare")),
    ?assertEqual("T derives compare and declares it too",
                 refusal("type T = T(Int) derives compare\n"
                         "fn T.compare(x : T, y : T) : Ordering = Equal")).

%% report §5.6: a record is filled from a namespace, each field not given
%% the declaration of its name there at the field's type, a requirement's
%% members supplied where the record's type fixes them; written after the
%% code
fill_test() ->
    Ops = "type Ops(s, a) = Ops(fromList : (List(a)) -> s, toList : (s) -> List(a))\n",
    ?assertEqual(ok, ok(Ops ++ "let hashed : Ops(Set(Int), Int) = Ops(..Set)\n"
                        "let ordered : Ops(OrderedSet.Set(Int), Int) = Ops(..OrderedSet)\n"
                        "let mine : Ops(Set(Int), Int) = Ops(..Set, toList = Set.toList)\n")),
    ?assertEqual(ok, ok(Ops ++ "fn f(list : List(a)) : List(a) needs a.compare = {\n"
                        "    let ops : Ops(OrderedSet.Set(a), a) = Ops(..OrderedSet);\n"
                        "    ops.toList(ops.fromList(list))\n}\n")),
    ?assertEqual("Ops(..Set) lacks min: Set has no min",
                 refusal("type Ops(s, a) = Ops(min : (s) -> Optional(a))\n"
                         "let hashed : Ops(Set(Int), Int) = Ops(..Set)")),
    ?assertEqual("fromList needs a.compare, and the record's type leaves the variable a"
                 " undetermined; annotate it",
                 refusal(Ops ++ "fn f() : Int = { let ops = Ops(..OrderedSet); 1 }")),
    %% the help names the part that differs, past a variable on either
    %% side; a regression: it said "the types differ at a=! and a=!". The
    %% two types are named as one, so two variables are `a` and `b`; a
    %% regression test too, both printed as `a`
    ?assertEqual({"Ops(..Set) fills size with Set.size: expected (a) -> Bool, found"
                  " (Set(b=)) -> Int", "the types differ at Bool and Int"},
                 refusal_and_help("type Ops(s) = Ops(size : (s) -> Bool)\n"
                                  "fn f() : Ops(Set(Int)) = Ops(..Set)")),
    %% an expression after `..` keeps the record update's rule
    ?assertEqual("a record update gives at least one field after its `..`",
                 refusal(Ops ++ "fn f(o : Ops(Set(Int), Int)) : Ops(Set(Int), Int) = Ops(..o)")).

%% report §5.6, §4.2: after `..`, a name of type names alone is a namespace,
%% a constructor of the same name notwithstanding, and `..Prelude.N` is
%% refused, naming the namespace to write. A regression test of the full
%% review's P3 (2026-10-04): a constructor `Set` took the fill from `Set`
%% away, and `..Prelude.Set` read as a namespace that holds nothing. A
%% constructor `Set` is refused since the principles review's W8 (§3.1), so
%% the constructor beside the fill is `OrderedSet`, a namespace and no type
fill_beside_a_constructor_test() ->
    Ops = "type Mode = OrderedSet | Plain\n"
          "type Ops(s, a) = Ops(fromList : (List(a)) -> s, toList : (s) -> List(a))\n",
    ?assertEqual(ok, ok(Ops ++ "let ordered : Ops(OrderedSet.Set(Int), Int) = Ops(..OrderedSet)\n"
                        "let mode : Mode = OrderedSet\n")),
    ?assertEqual({"`Prelude.Set` names no namespace: `Prelude.` reaches one of the prelude's"
                  " names", "write the namespace after `..` as it is, `..Set` (report §5.6)"},
                 refusal_and_help(Ops ++ "let hashed : Ops(Set(Int), Int) = Ops(..Prelude.Set)\n")).

%% report §11.5: a selected field called is named as written where its
%% argument does not fit; written after the code
selected_callee_named_test() ->
    ?assertEqual("the argument does not fit ops.toList: expected Set(Int), found Int",
                 refusal("type Ops = Ops(toList : (Set(Int)) -> List(Int))\n"
                         "fn f(ops : Ops) : List(Int) = ops.toList(1)")).

%% report §5.6, §5.1: a path in a record update is the nested update, each
%% type along it one constructor with the named field, two paths sharing
%% a prefix and none covering another; written after the code
update_path_test() ->
    Types = "export type Stats = Stats(indexed : Int, hits : Int)\n"
            "export type Pool = Pool(name : String, stats : Stats)\n"
            "export type Site = Site(pool : Pool, visits : Int)\n",
    ?assertEqual("(M.Pool) -> M.Pool",
                 type_of(Types ++ "export fn f(p : Pool) : Pool =\n"
                         "    Pool(..p, stats.indexed = 1, name = \"q\", stats.hits = 2)\n", f)),
    ?assertEqual("(M.Site) -> M.Site",
                 type_of(Types ++ "export fn f(s : Site) : Site =\n"
                         "    Site(..s, pool.stats.hits = 5, visits = 1, pool.name = \"q\")\n", f)),
    ?assertEqual(ok, ok("type Box(a) = Box(inner : a)\n"
                        "type Point = Point(x : Int)\n"
                        "fn f(b : Box(Point)) : Box(Point) = Box(..b, inner.x = 1)")),
    %% a value of another type is the inner field's error
    ?assertEqual("field indexed: expected Int, found String",
                 refusal(Types ++ "fn f(p : Pool) : Pool = Pool(..p, stats.indexed = \"x\")")),
    ?assertEqual("`shape.at` reaches Shape, which has 2 constructors, and a path goes through a"
                 " type with one",
                 refusal("type Shape = Dot | Circle(at : Int)\n"
                         "type Holder = Holder(shape : Shape)\n"
                         "fn f(h : Holder) : Holder = Holder(..h, shape.at = 1)")),
    ?assertEqual("`size.x` reaches Int, which has no fields",
                 refusal("type Holder = Holder(size : Int)\n"
                         "fn f(h : Holder) : Holder = Holder(..h, size.x = 1)")),
    ?assertEqual("Stats has no field misses",
                 refusal(Types ++ "fn f(p : Pool) : Pool = Pool(..p, stats.misses = 1)")),
    ?assertEqual("Pool has no field stat",
                 refusal(Types ++ "fn f(p : Pool) : Pool = Pool(..p, stat.hits = 1)")),
    ?assertEqual({"`stats.hits` and `stats` update one field",
                  "give the field once, or paths into it that do not overlap"},
                 refusal_and_help(Types ++ "fn f(p : Pool) : Pool =\n"
                                  "    Pool(..p, stats = Stats(indexed = 0, hits = 0),"
                                  " stats.hits = 2)")),
    ?assertEqual("field stats.hits is given twice",
                 refusal(Types ++ "fn f(p : Pool) : Pool =\n"
                         "    Pool(..p, stats.hits = 2, stats.hits = 3)")),
    ?assertEqual("the type of inner under `inner.x` is not determined; annotate it",
                 refusal("type Box(a) = Box(inner : a)\nfn f(b) = Box(..b, inner.x = 1)")),
    ?assertEqual("`size.x` is a path, which updates a value, and `..Set` names a namespace",
                 refusal("type Ops(s) = Ops(size : (s) -> Int)\n"
                         "let hashed : Ops(Set(Int)) = Ops(..Set, size.x = 1)")).

%% report §3.9, §11.5: within a recursive group a type of the group is
%% named in the group's fields at the declaring type's parameters alone,
%% refused at the declaration, self-recursive and mutually recursive alike;
%% a reference outside the group, and the group's types under another,
%% stand; written after the code
recursive_group_at_parameters_test() ->
    %% the help names the fix
    ?assertEqual({"Nest is named at List(a) in its own fields, and a type of a recursive group"
                  " is named in its fields at the declaring type's parameters alone",
                  "write `Nest(a)`, or `List(Nest(a))` to hold it in a List"},
                 refusal_and_help("type Nest(a) = Flat(a) | Deeper(Nest(List(a)))")),
    ?assertEqual("Nest is named at Int in its own fields, and a type of a recursive group is"
                 " named in its fields at the declaring type's parameters alone",
                 refusal("type Nest(a) = Flat(a) | Deeper(Nest(Int))")),
    ?assertEqual("Forest is named at List(a) in the fields of Tree, and a type of a recursive"
                 " group is named in its fields at the declaring type's parameters alone",
                 refusal("type Tree(a) = Node(value : a, children : Forest(List(a)))\n"
                         "type Forest(a) = Forest(List(Tree(a)))")),
    %% each parameter in its place: named in another order, or one twice, a
    %% walk would call itself at another type; found when a derived compare
    %% of such a type failed with a message about an annotation (2026-10-04)
    ?assertEqual({"Flip is named at Flip(b, a) in its own fields, and a type of a recursive group"
                  " is named in its fields at the declaring type's parameters, each in its"
                  " place, (a, b)", "write `Flip(a, b)`"},
                 refusal_and_help("type Flip(a, b) = End(a) | Turn(Flip(b, a))")),
    ?assertEqual("Twin is named at Twin(a, a) in its own fields, and a type of a recursive group"
                 " is named in its fields at the declaring type's parameters, each in its place,"
                 " (a, b)",
                 refusal("type Twin(a, b) = One(first : a, second : b) | Both(Twin(a, a))")),
    ?assertEqual("B is named at B(b) in the fields of A, and a type of a recursive group is"
                 " named in its fields at the declaring type's parameters, each in its place,"
                 " (a, b)",
                 refusal("type A(a, b) = A(first : a, rest : B(b))\n"
                         "type B(b) = Nil | B(A(b, b))")),
    ?assertEqual(ok, ok("type Tree(a) = Node(value : a, children : Forest(a))\n"
                        "type Forest(a) = Forest(List(Tree(a)))\n"
                        "type Rose(a) = Rose(value : a, children : List(Rose(a)))\n"
                        "type Chain(a) = End | Link(head : a, tail : Optional(Chain(a)))\n"
                        "type Pair(a, b) = Pair(first : a, second : b)\n"
                        "type Deep(a) = Deep(Pair(List(a), Deep(a)))\n"
                        "type Boxed = Boxed(List(Boxed))")).

%% report §6.9, §9.5: monitor takes a Process, the identity of a process,
%% which Process.fromAddress gives for an address; an address is refused,
%% since watching needs no permission to send. Written after the code
monitor_takes_a_process_test() ->
    Source = "type M = Died(Down)\n",
    ?assertEqual(ok, ok(Source ++ "fn f(a : Address(Int)) : Unit receiving M ="
                        " monitor(Process.fromAddress(a), Died)")),
    ?assertEqual(ok, ok(Source ++ "fn f(p : Process) : Unit receiving M = monitor(p, Died)")),
    ?assertEqual("the argument does not fit monitor: expected Process, found Address(Int)",
                 refusal(Source ++ "fn f(a : Address(Int)) : Unit receiving M = monitor(a, Died)")).

%% report Appendix E.24, §11.2: a test's run has the mailbox type of the
%% test's process, so one that receives infers Test.Case of its message
%% type, one that does not leaves it open, and the type takes an
%% argument. Written after the code
test_case_mailbox_test() ->
    ?assertEqual(ok, ok("type Go = Go\n"
                        "let waits = Test.Case(name = \"waits\", run = fn() = {\n"
                        "    let me = self();\n"
                        "    let _ = spawn(fn() : Unit receiving Never = send(me, Go));\n"
                        "    receive { Go -> Test.Passed }\n"
                        "})\n"
                        "fn f(t : Test.Case(Go)) : String = t.name\n"
                        "let name = f(waits)\n")),
    ?assertEqual(ok, ok("let quiet = Test.Case(name = \"quiet\", run = fn() = Test.Passed)\n"
                        "fn f(t : Test.Case(Int)) : String = t.name\n"
                        "fn g(t : Test.Case(Never)) : String = t.name\n"
                        "let both = f(quiet) <> g(quiet)\n")),
    ?assertMatch("Test.Case" ++ _,
                 refusal("let t : Test.Case = Test.Case(name = \"t\", run = fn() = Test.Passed)")).
