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
    {ok, _, Beam} = ern_emitter:compile(['M'], Typed, Interface, Env),
    {ok, Elapsed} = ern_page:declaration(Beam, <<"elapsed">>, entry),
    ElapsedText = unicode:characters_to_binary(Elapsed),
    ?assertMatch({_, _}, binary:match(ElapsedText, <<"The seconds elapsed since 1970">>)),
    ?assertEqual(nomatch, binary:match(ElapsedText, <<"*Since">>)),
    {ok, Minutes} = ern_page:declaration(Beam, <<"minutes">>, entry),
    ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(Minutes),
                                      <<"*Since 0.3.0.*">>)).

beam() ->
    File = "ern@string.beam",
    case code:where_is_file(File) of
        non_existing -> filename:join("../../../build/stdlib", File);
        Path -> Path
    end.
