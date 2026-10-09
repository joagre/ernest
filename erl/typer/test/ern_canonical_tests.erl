%% The canonical form and the hash of report Appendix H and §8.7, held to
%% what the appendix states: what a hash covers, what it leaves out, and
%% the bytes it is taken of. Written with the appendix and before the code
%% that computes a hash; the expected forms and hashes are built here by
%% hand from the appendix's terms, never from the code under test.
-module(ern_canonical_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("typer/include/ern_types.hrl").
-include_lib("typer/include/ern_canonical.hrl").

%% The canonical module of Text as the module T, and its interface with its
%% definitions' hashes, as a dependent is compiled against it.
canonical(Text) ->
    canonical(['T'], Text, []).

canonical(Namespace, Text, Interfaces) ->
    {ok, Declarations} = ern_parser:parse_string(Text),
    {ok, Typed, Interface, Env} = ern_typecheck:check(Namespace, Declarations, Interfaces),
    Module = ern_canonical:module(Namespace, Typed, Env, false),
    {Module, ern_canonical:interface(Interface, Module)}.

definitions(Text) ->
    {#{definitions := Definitions}, _} = canonical(Text),
    Definitions.

%% The definition of Text named by the last segments of its qualified name.
definition(Text, Name) ->
    named(definitions(Text), Name).

named(Definitions, Name) ->
    Names = case Name of
                [_ | _] -> Name;
                _ -> [Name]
            end,
    [Definition] = [Definition || #definition{qualified_name = QualifiedName} = Definition
                                      <- Definitions,
                                  lists:suffix(Names, QualifiedName)],
    Definition.

hash(Text, Name) ->
    (definition(Text, Name))#definition.hash.

form(Text, Name) ->
    (definition(Text, Name))#definition.form.

%% The hash of a term as Appendix H takes it, written out here as the
%% appendix states it.
sha(Term) ->
    crypto:hash(sha256, term_to_binary(Term, [deterministic, {minor_version, 2}])).

applied(Name) ->
    {applied, {named, [Name]}, []}.

%% Every subterm of a form, for asking whether one stands in it.
holds(Part, Part) ->
    true;
holds(Part, Term) when is_tuple(Term) ->
    holds(Part, tuple_to_list(Term));
holds(Part, [Head | Tail]) ->
    holds(Part, Head) orelse holds(Part, Tail);
holds(_, _) ->
    false.

%%
%% The bytes
%%

%% report Appendix H: the bytes are the host's external term format with
%% atoms in UTF-8, each literal's encoding fixed: an integer the host's
%% small integer, a float the host's 64-bit float, a string its UTF-8 as a
%% binary and a character its code point. The bytes are written here from
%% the format's documentation, so a change of encoding fails this test.
literal_bytes_test() ->
    Literal = [104, 3, 119, 7, "literal"],
    ?assertEqual(iolist_to_binary([131, Literal, 119, 3, "int", 97, 42]),
                 ern_canonical:bytes({literal, int, 42})),
    ?assertEqual(iolist_to_binary([131, Literal, 119, 5, "float", 70, <<1.5:64/float>>]),
                 ern_canonical:bytes({literal, float, 1.5})),
    ?assertEqual(iolist_to_binary([131, Literal, 119, 6, "string", 109, <<3:32>>, "h", 195, 169]),
                 ern_canonical:bytes({literal, string, <<"hé"/utf8>>})),
    ?assertEqual(iolist_to_binary([131, Literal, 119, 4, "char", 97, 233]),
                 ern_canonical:bytes({literal, char, 233})).

%% report Appendix H, §8.7: a definition of each literal hashes to the value
%% written here, computed once from the appendix's term; a change of the
%% form, of the encoding or of the version changes it
literal_hashes_test() ->
    Expected = [{"fn f() : Int = 42",
                 "884886a2011edc73fd3fad627628c517ba5078826eb4146a040ef32cda95e66c"},
                {"fn f() : Float = 1.5",
                 "40ed17e11d0db7ba568c8dcd0b6a9697c42b24a873ed44098dd4309ec269b4a8"},
                {"fn f() : String = \"hé\"",
                 "32e8e498d0c55b72d64bb8f13e25eef54795cb967730ef7c92534e7a9a09ad79"},
                {"fn f() : Char = 'é'",
                 "cae0cc4fc423257f8f74fe3e8b0a6f896ad9203d354ded5a67360e77565cad43"}],
    [?assertEqual({Text, list_to_binary(Hex)},
                  {Text, binary:encode_hex(hash(Text, f), lowercase)})
     || {Text, Hex} <- Expected],
    ?assertEqual(1, ern_canonical:form_version()).

%% report Appendix H: the form of a function, as the appendix writes it:
%% its scheme, its parameters, its annotations, its requirement and its
%% body, a local by its number and an operator the runtime applies holding
%% its operand's type
function_form_test() ->
    Int = applied('Int'),
    Expected = {function, {scheme, [], {arrow, [Int], pure, Int}, []},
                [{param, {local, 1}, Int}], Int, none, [],
                {operator, '+', {var, {local, 1}, []}, {literal, int, 1}, {runtime, Int}}},
    ?assertEqual(Expected, form("fn inc(x : Int) : Int = x + 1", inc)),
    ?assertEqual(sha({ernest_form, 1, Expected}), hash("fn inc(x : Int) : Int = x + 1", inc)).

%% report Appendix H: a type's form, its qualified name, its arity, whether
%% it derives compare, the compare its module declares, none here, and its
%% constructors in declared order with their fields in declared order; one
%% that derives compare names the compare derived for it, with which it is
%% one group
type_form_test() ->
    Float = applied('Float'),
    Text = "type Shape = Circle(Float) | Rect(w : Float, h : Float)",
    Constructors = [{'Circle', {positional, Float}},
                    {'Rect', {named, [{w, Float}, {h, Float}]}}],
    Expected = {type, ['T', 'Shape'], 0, false, none, Constructors},
    ?assertEqual(Expected, form(Text, 'Shape')),
    ?assertEqual(sha({ernest_form, 1, Expected}), hash(Text, 'Shape')),
    Derived = Text ++ " derives compare",
    ?assertEqual({type, ['T', 'Shape'], 0, true, {in_group, 2}, Constructors},
                 form(Derived, 'Shape')),
    ?assertMatch(#definition{group = {_, 2}}, definition(Derived, ['Shape', compare])),
    %% the parameters are the variables 1 to its arity
    ?assertEqual({type, ['T', 'Pair'], 2, false, none,
                  [{'Pair', {positional, {tuple, [{variable, 1}, {variable, 2}]}}}]},
                 form("type Pair(a, b) = Pair(#(a, b))", 'Pair')).

%% report Appendix H, §8.7, §3.10: a type's hash covers the compare its
%% module declares for it, which gives its order, and no other member: a
%% type with a written compare and one without hash apart; a change to
%% compare's body alone changes the type's hash, the hash of a key at an
%% ordered set of it, and the hash of a function that names it, and a
%% change to its negate changes none; the type and its compare reference
%% each other, and are one group, its form naming the compare by its
%% position. Regression tests, written after the code
type_compare_test() ->
    Coin = fun(Order, Negation) ->
                   "type Coin = Coin(Int)\n"
                   "fn Coin.compare(a : Coin, b : Coin) : Ordering = " ++ Order ++ "\n"
                   "fn Coin.negate(c : Coin) : Coin = " ++ Negation ++ "\n"
                   "let set : Peer.Key(OrderedSet.Set(Coin)) = Peer.key(\"coins\")\n"
                   "fn worth(c : Coin) : Int = match c { Coin(n) -> n }\n"
           end,
    First = Coin("match #(a, b) { #(Coin(x), Coin(y)) -> Int.compare(x, y) }",
                 "match c { Coin(n) -> Coin(-n) }"),
    Reversed = Coin("match #(a, b) { #(Coin(x), Coin(y)) -> Int.compare(y, x) }",
                    "match c { Coin(n) -> Coin(-n) }"),
    Negated = Coin("match #(a, b) { #(Coin(x), Coin(y)) -> Int.compare(x, y) }",
                   "match c { Coin(n) -> Coin(0 - n) }"),
    #definition{form = TypeForm, group = {Group, 1}} = definition(First, 'Coin'),
    #definition{group = {Group, 2}} = definition(First, ['Coin', compare]),
    ?assertMatch({type, ['T', 'Coin'], 0, false, {in_group, 2}, _}, TypeForm),
    ?assertNotEqual(hash("type Coin = Coin(Int)\n", 'Coin'), hash(First, 'Coin')),
    Key = fun(Text) ->
                  {#{keys := Keys}, _} = canonical(Text),
                  [Hash] = maps:values(Keys),
                  Hash
          end,
    [?assertNotEqual(Measure(First), Measure(Reversed))
     || Measure <- [fun(Text) -> hash(Text, 'Coin') end, Key,
                    fun(Text) -> hash(Text, worth) end]],
    [?assertEqual(Measure(First), Measure(Negated))
     || Measure <- [fun(Text) -> hash(Text, 'Coin') end, Key,
                    fun(Text) -> hash(Text, worth) end]],
    ?assertNotEqual(hash(First, ['Coin', negate]), hash(Negated, ['Coin', negate])).

%% report Appendix H, §8.7: a mutually recursive group is hashed as one, its
%% forms in source order, a reference within it its position, and each
%% member's hash taken of the group's hash and its position
group_form_test() ->
    Int = applied('Int'),
    Bool = applied('Bool'),
    Text = "fn even(n : Int) : Bool = if n == 0 then true else odd(n - 1)\n"
           "fn odd(n : Int) : Bool = if n == 0 then false else even(n - 1)\n",
    Member = fun(Answer, Other) ->
                 {function, {scheme, [], {arrow, [Int], pure, Bool}, []},
                  [{param, {local, 1}, Int}], Bool, none, [],
                  {'if', {operator, '==', {var, {local, 1}, []}, {literal, int, 0}, runtime},
                   {literal, bool, Answer},
                   {call, {var, {in_group, Other}, []},
                    [{operator, '-', {var, {local, 1}, []}, {literal, int, 1}, {runtime, Int}}]}}}
             end,
    Even = Member(true, 2),
    Odd = Member(false, 1),
    GroupHash = sha({ernest_form, 1, {group, [Even, Odd]}}),
    #definition{hash = EvenHash, form = EvenForm, group = EvenGroup} = definition(Text, even),
    #definition{hash = OddHash, form = OddForm, group = OddGroup} = definition(Text, odd),
    ?assertEqual({Even, Odd}, {EvenForm, OddForm}),
    ?assertEqual({GroupHash, 1}, EvenGroup),
    ?assertEqual({GroupHash, 2}, OddGroup),
    ?assertEqual(sha({ernest_member, 1, GroupHash, 1}), EvenHash),
    ?assertEqual(sha({ernest_member, 1, GroupHash, 2}), OddHash),
    %% a function that names itself alone is no group: itself is position 1
    #definition{form = Count, group = none} =
        definition("fn count(n : Int) : Int = if n == 0 then 0 else count(n - 1)", count),
    ?assert(holds({var, {in_group, 1}, []}, Count)).

%%
%% What a hash covers, and what it leaves out
%%

%% report §8.7, Appendix H: the same definition hashes the same across a
%% rebuild, though the checker numbers its variables otherwise when other
%% definitions come first
same_definition_same_hash_test() ->
    Text = "fn pick(xs : List(a), d : a) : a = match xs { x :: _ -> x | [] -> d }\n",
    Again = "type Other = Other(Int)\nfn first(x : a, y : b) : a = x\n" ++ Text,
    ?assertEqual(definitions(Text), definitions(Text)),
    ?assertEqual(hash(Text, pick), hash(Again, pick)),
    ?assertEqual(form(Text, pick), form(Again, pick)).

%% report §8.7, Appendix H: two bodies that differ only in local names,
%% annotation variables' names, layout or comments are one definition
local_names_and_layout_test() ->
    One = "fn swap(p : #(a, b)) : #(b, a) = { let #(x, y) = p; #(y, x) }\n",
    Two = "// swaps\nfn swap(pair : #(left, right))\n"
          "    : #(right, left) = {\n"
          "    let #(first, second) = pair; // the parts\n"
          "    #(second, first)\n"
          "}\n",
    ?assertEqual(hash(One, swap), hash(Two, swap)),
    %% a pattern names a constructor's fields in any order
    Shape = "type Shape = Rect(w : Int, h : Int)\n",
    ?assertEqual(hash(Shape ++ "fn area(s : Shape) : Int = match s { Rect(w = a, h = b) -> a * b }",
                      area),
                 hash(Shape ++ "fn area(s : Shape) : Int = match s { Rect(h = b, w = a) -> a * b }",
                      area)),
    %% where a name is bound decides its number, so shadowing differs from
    %% a second name
    ?assertNotEqual(hash("fn f(x : Int) : Int = { let y = x + 1; y }", f),
                    hash("fn f(x : Int) : Int = { let y = x + 1; x }", f)).

%% report §8.7: a renamed function keeps its dependents' hashes, since a
%% function's own name is not in its hash and a reference is the hash of
%% what it names
renamed_function_test() ->
    Before = "fn f(x : Int) : Int = x + 1\nfn caller() : Int = f(2)\n",
    After = "fn g(x : Int) : Int = x + 1\nfn caller() : Int = g(2)\n",
    ?assertEqual(hash(Before, f), hash(After, g)),
    ?assertEqual(hash(Before, caller), hash(After, caller)),
    ?assert(holds({var, {hash, hash(Before, f)}, []}, form(Before, caller))).

%% report §8.7, Appendix H: a renamed constructor changes its type's hash,
%% and so its users'
renamed_constructor_test() ->
    Before = "type T = A | B\nfn use() : T = A\n",
    After = "type T = C | B\nfn use() : T = C\n",
    ?assertNotEqual(hash(Before, 'T'), hash(After, 'T')),
    ?assertNotEqual(hash(Before, use), hash(After, use)),
    ?assert(holds({construct, {constructor, {hash, hash(Before, 'T')}, 1}, none},
                  form(Before, use))),
    %% a renamed field does too
    ?assertNotEqual(hash("type P = P(x : Int)", 'P'), hash("type P = P(y : Int)", 'P')).

%% report §8.7: a type's hash covers its qualified name, so a renamed type
%% is another type, and its users change with it
renamed_type_test() ->
    ?assertNotEqual(hash("type T = A(Int)", 'T'), hash("type U = A(Int)", 'U')),
    ?assertNotEqual(hash("type T = A(Int)\nfn mk() : T = A(1)", mk),
                    hash("type U = A(Int)\nfn mk() : U = A(1)", mk)),
    %% and its module's name, which is in its qualified name
    {#{definitions := InT}, _} = canonical(['T'], "type T = A(Int)", []),
    {#{definitions := InU}, _} = canonical(['U'], "type T = A(Int)", []),
    ?assertNotEqual((named(InT, 'T'))#definition.hash, (named(InU, 'T'))#definition.hash).

%% report Appendix H: derives compare is in a type's hash; whether a type is
%% exported or abstract is not
type_flags_test() ->
    Plain = hash("type T = A(Int)", 'T'),
    ?assertNotEqual(Plain, hash("type T = A(Int) derives compare", 'T')),
    ?assertEqual(Plain, hash("export type T = A(Int)", 'T')),
    ?assertEqual(Plain, hash("export abstract type T = A(Int)", 'T')).

%% report §8.7, Appendix H: moving a definition within a mutually recursive
%% group changes the group's hash, and so every member's
moved_in_group_test() ->
    Even = "fn even(n : Int) : Bool = if n == 0 then true else odd(n - 1)\n",
    Odd = "fn odd(n : Int) : Bool = if n == 0 then false else even(n - 1)\n",
    #definition{hash = EvenHash, group = {GroupHash, 1}} = definition(Even ++ Odd, even),
    #definition{hash = MovedHash, group = {MovedGroupHash, 2}} = definition(Odd ++ Even, even),
    ?assertNotEqual(GroupHash, MovedGroupHash),
    ?assertNotEqual(EvenHash, MovedHash),
    ?assertNotEqual(hash(Even ++ Odd, odd), hash(Odd ++ Even, odd)).

%% report §8.7, Appendix H: a changed literal changes the hash
changed_literal_test() ->
    ?assertNotEqual(hash("fn f() : Int = 1", f), hash("fn f() : Int = 2", f)),
    ?assertNotEqual(hash("fn f() : String = \"a\"", f), hash("fn f() : String = \"b\"", f)),
    %% a character is not the integer of its code point
    ?assertNotEqual(form("fn f() : Char = 'a'", f), form("fn f() : Int = 97", f)).

%% report §8.7: two hashes for one definition and one hash for two are what
%% the hash guards against: one body under two names, in two modules, is
%% one hash, and two bodies are two
one_hash_for_one_definition_test() ->
    Text = "fn f() : Int = 1\nfn g() : Int = 1\nfn h() : Int = 2\n",
    ?assertEqual(hash(Text, f), hash(Text, g)),
    ?assertNotEqual(hash(Text, f), hash(Text, h)),
    {#{definitions := InA}, _} = canonical(['A'], "fn f() : Int = 1", []),
    {#{definitions := InB}, _} = canonical(['B'], "fn other() : Int = 1", []),
    ?assertEqual((named(InA, f))#definition.hash, (named(InB, other))#definition.hash),
    %% a type variable's name is no part of it; which variables are one is
    ?assertEqual(hash("fn k(x : a, y : b) : a = x", k), hash("fn k(p : t, q : u) : t = p", k)),
    ?assertNotEqual(hash("fn k(x : a, y : b) : a = x", k), hash("fn k(x : a, y : a) : a = x", k)).

%% report §8.7: a binding's identity is its qualified name with its hash, so
%% two bindings with one initializer have one hash and are two things, and
%% a function that names one names the binding
binding_identity_test() ->
    Text = "let a : Int = 5\nlet b : Int = 5\nfn useA() : Int = a\nfn useB() : Int = b\n",
    #definition{qualified_name = ['T', a], kind = binding, hash = Hash} = definition(Text, a),
    #definition{qualified_name = ['T', b], kind = binding, hash = Hash} = definition(Text, b),
    ?assertEqual({var, {binding, ['T', a], Hash}, []},
                 element(7, form(Text, useA))),
    ?assertNotEqual(hash(Text, useA), hash(Text, useB)).

%% report §8.7, Appendix H: a lambda's or a local function's identity is its
%% enclosing definition's hash and its position, counted in the order the
%% walk meets them
lambda_identity_test() ->
    Text = "fn both(xs : List(Int)) : List(Int) = {\n"
           "    fn twice(x : Int) : Int = x * 2;\n"
           "    List.map(List.map(xs, fn(x) = x + 1), fn(x) = twice(x))\n"
           "}\n",
    #definition{hash = Hash, form = Form} = definition(Text, both),
    Functions = ern_canonical:lambdas(Hash, Form),
    ?assertEqual([{Hash, 1}, {Hash, 2}, {Hash, 3}], [Identity || {Identity, _} <- Functions]),
    [{_, {function, _, _, _, _, _, _}}, {_, {lambda, _, _, _, Inner}}, {_, {lambda, _, _, _, _}}] =
        Functions,
    %% xs is 1, twice 2 as the block begins, twice's x 3 and the lambda's x 4
    ?assertEqual({operator, '+', {var, {local, 4}, []}, {literal, int, 1},
                  {runtime, applied('Int')}},
                 Inner),
    %% the same lambda in another definition is another lambda
    Other = Text ++ "fn other(xs : List(Int)) : List(Int) = List.map(xs, fn(x) = x + 1)\n",
    #definition{hash = OtherHash, form = OtherForm} = definition(Other, other),
    ?assertEqual([{OtherHash, 1}],
                 [Identity || {Identity, _} <- ern_canonical:lambdas(OtherHash, OtherForm)]),
    ?assertNotEqual(Hash, OtherHash).

%% report §8.7, Appendix H: a definition of the standard library or the
%% prelude is referenced by its qualified name
standard_library_by_name_test() ->
    Text = "fn inc(xs : List(Int)) : List(Int) = List.map(xs, fn(x) = x + 1)\n"
           "fn first(xs : List(Int)) : Optional(Int) = List.get(xs, 0)\n",
    ?assert(holds({var, {named, ['List', map]}, []}, form(Text, inc))),
    ?assert(holds({applied, {named, ['Optional']}, [applied('Int')]}, form(Text, first))),
    ?assert(holds({var, {named, [self]}, []},
                  form("fn me() : Address(Never) with Never = self()", me))).

%% report §8.7, Appendix H: a reference to another module's definition is
%% its hash, which the module's interface holds; a change to its body
%% changes the dependent's hash, and renaming it does not
other_module_test() ->
    Dependent = fun(Body, Name) ->
                    {_, Interface} = canonical(['A'], "export fn " ++ Name ++ "() : Int = "
                                                          ++ Body, []),
                    {#{definitions := Definitions, references := References}, _} =
                        canonical(['B'], "fn caller() : Int = A." ++ Name ++ "() + 1",
                                  [Interface]),
                    {(named(Definitions, caller))#definition.hash, References,
                     maps:get(['A', list_to_atom(Name)], Interface#interface.identities)}
                end,
    {Hash, [{['A', f], FHash}], FHash} = Dependent("1", "f"),
    ?assertMatch({Hash, _, _}, Dependent("1", "g")),
    {Changed, _, _} = Dependent("2", "f"),
    ?assertNotEqual(Hash, Changed).

%% report §8.7, Appendix H: a foreign function has no hash and is named by
%% its qualified name and its scheme; a foreign type by its qualified name;
%% the interface marks both
foreign_test() ->
    Text = "foreign type Handle\n"
           "foreign fn now() : Int = \"erlang:monotonic_time/0\"\n"
           "fn later() : Int = now() + 1\n",
    {#{definitions := Definitions}, Interface} = canonical(Text),
    ?assertEqual([later], [lists:last(QualifiedName)
                           || #definition{qualified_name = QualifiedName} <- Definitions]),
    Int = applied('Int'),
    ?assert(holds({var, {foreign, ['T', now], {scheme, [], {arrow, [], pure, Int}, []}}, []},
                  form(Text, later))),
    ?assertEqual(foreign, maps:get(['T', now], Interface#interface.identities)),
    ?assertEqual(foreign, maps:get(['T', 'Handle'], Interface#interface.identities)),
    ?assertEqual(hash(Text, later), maps:get(['T', later], Interface#interface.identities)).

%% report Appendix H: a type of the module is referenced by its hash, and a
%% type variable an annotation writes by its number
type_reference_test() ->
    Text = "type Box(a) = Box(a)\nfn open(b : Box(a)) : a = match b { Box(x) -> x }\n",
    BoxHash = hash(Text, 'Box'),
    Box = {applied, {hash, BoxHash}, [{variable, 1}]},
    {function, {scheme, [{1, _}], {arrow, [Box], pure, {variable, 1}}, []},
     [{param, {local, 1}, {applied, {hash, BoxHash}, [{variable, 2}]}}], {variable, 2}, none, [],
     {match, {var, {local, 1}, []},
      [{clause, {construct, {constructor, {hash, BoxHash}, 1}, {positional, {local, 2}}}, none,
        {var, {local, 2}, []}}]}} = form(Text, open).

%% report Appendix H: a use of Address.call holds the type of the answer
%% its reply is checked against, and an operator the runtime applies the
%% type of its operand, so two bodies the emitter writes otherwise differ
types_the_back_end_reads_test() ->
    Text = "type Msg = Get(Reply(Int))\n"
           "fn ask(a : Address(Msg)) : Optional(Int) with Never = Address.call(a, Get, 100)\n",
    ?assert(holds({var, {named, ['Address', call]}, [], applied('Int')}, form(Text, ask))),
    ?assertNotEqual(form("fn f(x : Int) : Int = x * x", f),
                    form("fn f(x : Float) : Float = x * x", f)),
    ?assert(holds({negate, {var, {local, 1}, []}, {runtime, applied('Float')}},
                  form("fn f(x : Float) : Float = -x", f))).

%% report Appendix H: a local function's scheme names its requirement's
%% variable as its type does, though the checker recorded it under another
%% identifier the substitution bound to the enclosing one. A regression
%% test, from a reading of the forms: the identifier was numbered as it
%% stood, a variable no other part of the form named. Not covered: a
%% requirement bound to a type that is not a variable, which the checker
%% never makes
local_requirement_test() ->
    Text = "fn sorted(xs : List(a)) : Bool needs a.compare = {\n"
           "    fn less(p : a, q : a) : Bool needs a.compare = p < q;\n"
           "    match xs { x :: y :: _ -> less(x, y) | _ -> true }\n"
           "}\n",
    {block, [{function, {scheme, [], {arrow, [{variable, 1}, {variable, 1}], pure, _},
                         [{1, compare}]},
              _, _, _, _, _} | _]} = element(7, form(Text, sorted)).

%% report Appendix H, §8.7: a key's message type stands in the form of the
%% definition that makes the key as `{key, Type}`, so that a change to the
%% type changes that definition's hash; the type's hash, which the key
%% carries, is that of `{ernest_type, 1, Type}`, a declared type of the
%% program by its hash and a built-in one by its name. A regression test,
%% written after the code (MVP 3.1's item 4)
key_type_hash_test() ->
    Text = fun(Msg) ->
               "type Msg = " ++ Msg ++ "\n"
               "let one : Peer.Key(Msg) = Peer.key(\"one\")\n"
               "let maybe : Peer.Key(Optional(Msg)) = Peer.key(\"maybe\")\n"
           end,
    First = Text("Add(Int)"),
    {#{keys := Keys}, _} = canonical(First),
    MsgHash = hash(First, 'Msg'),
    Msg = {applied, {hash, MsgHash}, []},
    ?assert(holds({var, {named, ['Peer', key]}, [{key, Msg}]}, form(First, one))),
    ?assertEqual(sha({ernest_type, 1, Msg}), maps:get({tcon, ['T', 'Msg'], []}, Keys)),
    Optional = {applied, {named, ['Optional']}, [Msg]},
    ?assertEqual(sha({ernest_type, 1, Optional}),
                 maps:get({tcon, ['Optional'], [{tcon, ['T', 'Msg'], []}]}, Keys)),
    Second = Text("Add(Int) | Sub(Int)"),
    ?assertNotEqual(hash(First, one), hash(Second, one)),
    {#{keys := Changed}, _} = canonical(Second),
    ?assertNotEqual(maps:get({tcon, ['T', 'Msg'], []}, Keys),
                    maps:get({tcon, ['T', 'Msg'], []}, Changed)).

%% report §8.7, §11.1: a function's reach names each binding and each
%% foreign declaration of a program it references, through every function
%% it calls, its own module's and another's, whose interface holds it; a
%% group's members share one; a lambda's and a local function's are their
%% own, with their identities' positions, by their spans. A regression
%% test, written after the code (MVP 3.1's item 4)
reach_test() ->
    {_, Interface} = canonical(['A'], "let note : Int = 1\n"
                                      "foreign fn now() : Int = \"erlang:monotonic_time/0\"\n"
                                      "export fn noted() : Int = note + now()\n"
                                      "export fn plain() : Int = 2\n", []),
    NoteHash = maps:get(['A', note], Interface#interface.identities),
    Reached = {[{['A', note], NoteHash}], [['A', now]]},
    ?assertEqual(Reached, maps:get(['A', noted], Interface#interface.reaches)),
    ?assertNot(maps:is_key(['A', plain], Interface#interface.reaches)),
    Text = "let own : Int = 3\n"
           "fn even(n : Int) : Bool = if n == 0 then true else odd(n - 1)\n"
           "fn odd(n : Int) : Bool = if n == 0 then A.noted() == own else even(n - 1)\n"
           "fn spawns() : Int = {\n"
           "    let quiet = fn() : Int = A.plain();\n"
           "    let loud = fn() : Int = own;\n"
           "    quiet() + loud()\n"
           "}\n",
    {#{reaches := Reaches, functions := Functions, definitions := Definitions}, _} =
        canonical(['B'], Text, [Interface]),
    #definition{hash = OwnHash} = named(Definitions, own),
    Group = {[{['A', note], NoteHash}, {['B', own], OwnHash}], [['A', now]]},
    ?assertEqual(Group, maps:get(['B', even], Reaches)),
    ?assertEqual(Group, maps:get(['B', odd], Reaches)),
    ?assertEqual([{['B', spawns], 1, {[], []}}, {['B', spawns], 2, {[{['B', own], OwnHash}], []}}],
                 lists:sort(maps:values(Functions))).

%% report §11.1: the chunk of the canonical forms is written compressed, and
%% reads back as the definitions it was written of; a regression test,
%% written when the chunk was compressed. Not covered: a chunk of another
%% form's version, which reads as an error
compressed_chunk_test() ->
    {ok, Bytes} = file:read_file(code:which('ern@list')),
    {ok, {_, [{_, Chunk}]}} = beam_lib:chunks(Bytes, [binary_to_list(ern_canonical:chunk_name())]),
    ?assertMatch(<<131, 80, _/binary>>, Chunk),
    {1, Written} = binary_to_term(Chunk),
    ?assertEqual({ok, Written}, ern_canonical:read(Bytes)),
    ?assert(length(Written) > 10).
