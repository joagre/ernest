%% Report §11.4: the renderer of the documentation a compiled module
%% carries. `ern doc` writes the whole page, which ern_cli_tests covers;
%% this is the one declaration the shell's `:doc` prints (§11.2).
-module(ern_page_tests).

-include_lib("eunit/include/eunit.hrl").

%% report §11.4, §11.2: one declaration's entry, its heading, its signature,
%% and its text, and none where the module declares no such name
declaration_test() ->
    Beam = beam(),
    {ok, Page} = ern_page:declaration(Beam, <<"trim">>, entry),
    Text = unicode:characters_to_binary(Page),
    ?assertMatch({0, _}, binary:match(Text, <<"## String.trim">>)),
    %% report §11.4: a function's declaration, its parameters named
    ?assertMatch({_, _}, binary:match(Text, <<"String.trim(text : String) : String">>)),
    ?assertEqual(none, ern_page:declaration(Beam, <<"nosuchname">>, entry)).

%% Appendix E.0 shape rule 6, report §11.4: a doc block's `since` line is
%% its whole last line, and a sentence that ends in "since" and a number
%% is text. A regression test: "The seconds elapsed since 1970" was read
%% as a `since` line, rendered *Since 1970.*, and cut
since_line_test() ->
    Source = "/// The seconds elapsed since 1970\n"
             "export fn elapsed() : Int = 0\n\n"
             "/// The minutes.\n///\n/// since 0.3.0\n"
             "export fn minutes() : Int = 0\n",
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(['M'], Source),
    {ok, _, Beam} = ern_compile:compile(['M'], Typed, Interface, Env),
    {ok, Elapsed} = ern_page:declaration(Beam, <<"elapsed">>, entry),
    ElapsedText = unicode:characters_to_binary(Elapsed),
    ?assertMatch({_, _}, binary:match(ElapsedText, <<"The seconds elapsed since 1970">>)),
    ?assertEqual(nomatch, binary:match(ElapsedText, <<"*Since">>)),
    {ok, Minutes} = ern_page:declaration(Beam, <<"minutes">>, entry),
    ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(Minutes),
                                      <<"*Since 0.3.0.*">>)).

%% report §11.4, §4.5: a member is headed by its qualified name, and its
%% code block's line is the form a program writes at its type, its
%% parameters named without their types, its result and its requirement
%% after them; the members follow the module's other declarations, each
%% type's together, the types in the order of their first members, a
%% type's `compare` first, then its infix operators by their text, then
%% its `negate`; and `:doc` shows a member alone in the same form. Written
%% with the layout (the release review's E4)
member_page_test() ->
    Source = "export type Stack(a) = Stack(items : List(a))\n\n"
             "export fn Stack.<>(stack : Stack(a), other : Stack(a)) : Stack(a) =\n"
             "    Stack(items = stack.items <> other.items)\n\n"
             "/// Orders stacks.\n"
             "export fn Stack.compare(left : Stack(a), right : Stack(a)) : Ordering"
             " needs a.compare =\n"
             "    compare(left.items, right.items)\n\n"
             "export type Point = Point(x : Int)\n\n"
             "export fn Point.negate(point : Point) : Point = Point(x = -point.x)\n\n"
             "export fn Point.compare(left : Point, right : Point) : Ordering =\n"
             "    compare(left.x, right.x)\n\n"
             "export fn size(stack : Stack(a)) : Int = List.size(stack.items)\n",
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(['M'], Source),
    {ok, _, Beam} = ern_compile:compile(['M'], Typed, Interface, Env),
    Page = unicode:characters_to_binary(ern_page:page(Beam, "m.ern")),
    Headings = [Line || Line <- binary:split(Page, <<"\n">>, [global]),
                        binary:match(Line, <<"## ">>) =:= {0, 3}],
    ?assertEqual([<<"## M.Stack">>, <<"## M.Point">>, <<"## M.size">>,
                  <<"## M.Stack.compare">>, <<"## M.Stack.<>">>,
                  <<"## M.Point.compare">>, <<"## M.Point.negate">>], Headings),
    [?assertMatch({_, _}, binary:match(Page, Form))
     || Form <- [<<"## M.Stack.compare\n\n```ernest\ncompare(left, right) : Ordering needs"
                   " a.compare\n```\n\nOrders stacks.">>,
                 <<"```ernest\nstack <> other : Stack(a)\n```">>,
                 <<"```ernest\ncompare(left, right) : Ordering\n```">>,
                 <<"```ernest\n-point : Point\n```">>,
                 <<"```ernest\nM.size(stack : Stack(a)) : Int\n```">>]],
    {ok, Alone} = ern_page:declaration(Beam, <<"Point.negate">>, entry),
    ?assertEqual(<<"## M.Point.negate\n\n```ernest\n-point : Point\n```\n\n">>,
                 unicode:characters_to_binary(Alone)).

%% report §11.4: a prelude type's module declares the type's members
%% unprefixed or under the type's name, `Int`'s `compare` and `Int.+`, and
%% its page lists them after its functions in their order, each in its
%% form. Written with the layout (the release review's E4)
prelude_type_members_test() ->
    {ok, Beam} = file:read_file(filename:join(ern_prelude:stdlib_directory(), "int.erc")),
    Page = unicode:characters_to_binary(ern_page:page(Beam, "int.ern")),
    Headings = [Line || Line <- binary:split(Page, <<"\n">>, [global]),
                        binary:match(Line, <<"## Int.">>) =:= {0, 7}],
    ?assertEqual([<<"## Int.compare">>, <<"## Int.%">>, <<"## Int.*">>, <<"## Int.+">>,
                  <<"## Int.-">>, <<"## Int./">>, <<"## Int.negate">>],
                 lists:nthtail(length(Headings) - 7, Headings)),
    [?assertMatch({_, _}, binary:match(Page, Form))
     || Form <- [<<"```ernest\ncompare(left, right) : Ordering\n```">>,
                 <<"```ernest\nleft + right : Int\n```">>,
                 <<"```ernest\ndividend / divisor : Int\n```">>,
                 <<"```ernest\n-int : Int\n```">>]].

beam() ->
    {ok, Beam} = file:read_file(filename:join(ern_prelude:stdlib_directory(), "string.erc")),
    Beam.
