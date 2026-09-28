%% The catalogue of the front end's errors (docs/coherence.md C21),
%% test/diagnostics.md: one small program for every error the lexer, the
%% parser and the checker give. ern_guide_tests checks each program's
%% output as the catalogue shows it; this module checks that the catalogue
%% holds a program for every error. An error is the words the front end's
%% code writes at a place that raises or builds a diagnostic, or that it
%% hands to a function that writes one: the string arguments of a call to
%% one of the functions below, split where a placeholder of
%% `io_lib:format` stands. It is catalogued where one diagnostic of a
%% program's output, its message and the lines under it, holds all its
%% words, and begins with the first where the code's message does.
-module(ern_diagnostics_tests).

-include_lib("eunit/include/eunit.hrl").

-export([sites/0]).

-define(FRONT, ["../erl/lexer/src/ern_lexer.erl", "../erl/parser/src/ern_parser.erl",
                "../erl/typer/src/ern_scope.erl", "../erl/typer/src/ern_typecheck.erl",
                "../erl/typer/src/ern_reply.erl", "../erl/typer/src/ern_exhaust.erl",
                "../erl/typer/src/ern_bitspec.erl"]).

%% The functions whose string arguments are an error's words: those that
%% raise one, and those the checker hands the context of a mismatch, the
%% words of a sibling branch, or the origin of an effect.
-define(WRITERS, [fail, error_at, unfinished_at, wanted, throw, unify_at, check_expr,
                  ret_context, sibling, default, alignment, effect_origin, never_receives]).

%% The writers whose first string, standing as an argument of its own,
%% begins the message: a context begins the mismatch it names. The others
%% place their words inside a message, `expected a name instead of ...`,
%% or, as a sibling branch does, may begin with a label.
-define(LEADING, [fail, error_at, unfinished_at, unify_at, check_expr, ret_context, default,
                  alignment]).

%% report §11.5, docs/coherence.md C21: every error of the lexer, the
%% parser and the checker has its program in the catalogue
every_error_catalogued_test() ->
    Diagnostics = [D || {Kind, #{shown := Shown}} <- ern_guide_tests:units("diagnostics.md"),
                        Kind =:= rejected orelse Kind =:= session, is_binary(Shown),
                        D <- diagnostics(Shown)],
    Unshown = [Words || {Words, _} <- unshown()],
    Missing = [{M, L, Words} || {M, L, Lead, Words} <- sites(), not lists:member(Words, Unshown),
                                not lists:any(fun(D) -> holds(D, Lead, Words) end, Diagnostics)],
    ?assertEqual([], Missing),
    %% an error below that the front end no longer gives
    ?assertEqual([], Unshown -- [Words || {_, _, _, Words} <- sites()]).

%% The errors a program in this document cannot give, each with why and
%% the test that gives it instead: a document of UTF-8 whose every block
%% ends in a line feed holds no bytes that are not UTF-8, and no input that
%% ends inside a string or an escape.
unshown() ->
    [{["input is not valid UTF-8"], "ern_lexer_tests' not_utf8_test"},
     {["unterminated string literal"], "ern_lexer_tests' errors_test"},
     {["unterminated escape"], "ern_lexer_tests' errors_test"}].

%% An output's diagnostics, each its message and the lines under it, as
%% report §11.5 lays them out: a message begins `file:line:column: `, in a
%% session after the prompt.
diagnostics(Shown) ->
    Lines = string:split(unicode:characters_to_list(Shown), "\n", all),
    lists:reverse(lists:foldl(fun(Line, Acc) ->
                                  case re:run(Line, "^(?:> )*[^ :]+:[0-9]+:[0-9]+: (.*)",
                                              [{capture, all_but_first, list}, unicode]) of
                                      {match, [Message]} -> [{Message, Line} | Acc];
                                      nomatch when Acc =:= [] -> Acc;
                                      nomatch ->
                                          [{Message, Text} | Rest] = Acc,
                                          [{Message, Text ++ "\n" ++ Line} | Rest]
                                  end
                              end, [], Lines)).

holds({Message, Text}, Lead, Words) ->
    (Lead =:= none orelse string:prefix(Message, Lead) =/= nomatch)
        andalso lists:all(fun(W) -> string:find(Text, W) =/= nomatch end, Words).

%% Each error of the front end, as its module, its line, the text its
%% message begins with or `none`, and its words.
sites() ->
    lists:append([sites(F) || F <- ?FRONT]).

sites(File) ->
    {ok, Bin} = file:read_file(File),
    {ok, Tokens, _} = erl_scan:string(unicode:characters_to_list(Bin)),
    Module = list_to_atom(filename:basename(File, ".erl")),
    [{Module, L, Lead, Words} || {L, Lead, Words} <- lists:usort(written(Tokens))].

%% Each call to a writer, or diagnostic built, with words of its own; a
%% writer's own head, which only passes its words on, has none.
written([{'-', _}, {atom, _, spec} | Rest]) ->
    written(skip_form(Rest));
written([{dot, _}, {atom, _, F}, {'(', _} | Rest]) ->
    case lists:member(F, ?WRITERS) of
        true -> written(skip_head(Rest));
        false -> written(Rest)
    end;
written([{atom, L, F}, {'(', _} | Rest]) ->
    case lists:member(F, ?WRITERS) of
        true -> words(L, lists:member(F, ?LEADING), strings(Rest, 1, start, [])) ++ written(Rest);
        false -> written(Rest)
    end;
written([{'#', L}, {atom, _, diag}, {'{', _} | Rest]) ->
    words(L, true, message(Rest, 1)) ++ written(Rest);
written([_ | Rest]) ->
    written(Rest);
written([]) ->
    [].

%% The words of a call's strings, and the text its message begins with: the
%% first string's text before its first placeholder, where that string
%% begins an argument of a leading writer.
words(_, _, {_, []}) -> [];
words(L, Leading, {First, [S | _] = Strings}) ->
    Lead = case {Leading andalso First, string:trim(hd(pieces(S)), trailing)} of
               {true, [_ | _] = Text} -> Text;
               _ -> none
           end,
    case [string:trim(W) || Str <- Strings, W <- pieces(Str), length(string:trim(W)) >= 3] of
        [] -> [];
        Words -> [{L, Lead, Words}]
    end.

%% A format's text between its placeholders.
pieces(S) ->
    re:split(S, "~[-0-9.*]*[a-zA-Z]", [{return, list}, unicode]).

skip_head([{'->', _} | Rest]) -> Rest;
skip_head([_ | Rest]) -> skip_head(Rest);
skip_head([]) -> [].

skip_form([{dot, _} | _] = Rest) -> Rest;
skip_form([_ | Rest]) -> skip_form(Rest);
skip_form([]) -> [].

%% The strings among a call's arguments, up to its `)`, and whether the
%% first begins an argument: whether the token before it is the call's `(`
%% or a `,` between its arguments.
strings(_, 0, First, Acc) -> {First =:= true, lists:reverse(Acc)};
strings([{string, _, [_ | _] = S} | Rest], D, First, Acc) ->
    strings(Rest, D, first(First, D), [S | Acc]);
strings([{'(', _} | Rest], D, First, Acc) -> strings(Rest, D + 1, after_token(First), Acc);
strings([{')', _} | Rest], D, First, Acc) -> strings(Rest, D - 1, after_token(First), Acc);
strings([{',', _} | Rest], 1, First, Acc) when First =:= start; First =:= later ->
    strings(Rest, 1, start, Acc);
strings([_ | Rest], D, First, Acc) -> strings(Rest, D, after_token(First), Acc);
strings([], _, First, Acc) -> {First =:= true, lists:reverse(Acc)}.

%% `start` while the next token begins an argument, `later` once one does
%% not, and the answer for the first string once it is met.
first(start, 1) -> true;
first(start, _) -> false;
first(later, _) -> false;
first(Found, _) -> Found.

after_token(start) -> later;
after_token(Found) -> Found.

%% The strings of a diagnostic's `message` field, up to its `}`, and
%% whether the first begins the field.
message(_, 0) -> {false, []};
message([{atom, _, message}, {'=', _} | Rest], 1) ->
    Strings = value(Rest, 0, []),
    {element(1, hd(Rest)) =:= string, Strings};
message([{'{', _} | Rest], D) -> message(Rest, D + 1);
message([{'}', _} | Rest], D) -> message(Rest, D - 1);
message([_ | Rest], D) -> message(Rest, D);
message([], _) -> {false, []}.

value([{T, _} | _], 0, Acc) when T =:= ','; T =:= '}' -> lists:reverse(Acc);
value([{string, _, [_ | _] = S} | Rest], D, Acc) -> value(Rest, D, [S | Acc]);
value([{T, _} | Rest], D, Acc) when T =:= '('; T =:= '['; T =:= '{' -> value(Rest, D + 1, Acc);
value([{T, _} | Rest], D, Acc) when T =:= ')'; T =:= ']'; T =:= '}' -> value(Rest, D - 1, Acc);
value([_ | Rest], D, Acc) -> value(Rest, D, Acc);
value([], _, Acc) -> lists:reverse(Acc).
