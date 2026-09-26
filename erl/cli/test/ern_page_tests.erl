%% Report §11.4: the renderer of the documentation a compiled module
%% carries. `ern doc` writes the whole page, which ern_cli_tests covers;
%% this is the one declaration the shell's `:doc` prints (§11.2).
-module(ern_page_tests).

-include_lib("eunit/include/eunit.hrl").

%% report §11.4, §11.2: one declaration's entry, its heading, its signature,
%% and its text, and none where the module declares no such name
declaration_test() ->
    Beam = beam(),
    {ok, Page} = ern_page:declaration(Beam, <<"trim">>),
    Text = unicode:characters_to_binary(Page),
    ?assertMatch({0, _}, binary:match(Text, <<"## String.trim">>)),
    ?assertMatch({_, _}, binary:match(Text, <<"String.trim : (String) -> String">>)),
    ?assertEqual(none, ern_page:declaration(Beam, <<"nosuchname">>)).

beam() ->
    File = "ern@string.beam",
    case code:where_is_file(File) of
        non_existing -> filename:join("../../../build/stdlib", File);
        Path -> Path
    end.
