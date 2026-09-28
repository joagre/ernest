#!/usr/bin/env escript
%% -*- erlang -*-
%% make unused (docs/coherence.md C14): every private declaration of the
%% Ernest the repository ships and of its examples that nothing uses. Each
%% argument is a source root and the directory its modules were written
%% to as Erlang, `stdlib=build/unused/stdlib`. A private function or `let`
%% nothing uses is a function the host's compiler finds unused in the
%% Erlang it compiles to, a block's local function among them; a private
%% type nothing uses is one whose name no token of its module holds
%% outside its own declaration, since a type leaves no Erlang behind. It
%% prints each, and fails where there is one.

-include("../erl/parser/include/ern_ast.hrl").

main(Roots) ->
    code:add_pathsa(filelib:wildcard("erl/*/ebin")),
    Found = lists:append([root(string:split(R, "=")) || R <- Roots]),
    [io:format("make unused: ~s: ~s is used by nothing~n", [Source, What])
     || {Source, What} <- lists:sort(Found)],
    case Found of
        [] -> ok;
        _ -> halt(1)
    end.

root([Source, Built]) ->
    lists:append([functions(Source, Built, Erl) ++ types(filename:join(Source, rel(Built, Erl)))
                  || Erl <- filelib:wildcard(filename:join(Built, "**/*.erl"))]).

%% The source a written module came from, by its place under the root.
rel(Built, Erl) ->
    string:prefix(filename:rootname(Erl), Built ++ "/") ++ ".ern".

%% The private functions and lets the host's compiler finds unused.
functions(Source, Built, Erl) ->
    {ok, _, _, Warnings} = compile:file(Erl, [binary, return_warnings]),
    File = filename:join(Source, rel(Built, Erl)),
    [{File, what(File, F, A)} || {_, Ws} <- Warnings,
                                 {_, erl_lint, {unused_function, {F, A}}} <- Ws].

%% A lifted local function is written `name$N`.
what(File, F, A) ->
    case string:split(atom_to_list(F), "$") of
        [Local, _] -> io_lib:format("the local fn ~s", [Local]);
        [Name] -> named(File, list_to_atom(Name), A)
    end.

named(File, Name, A) ->
    {ok, Decls} = ern_parser:parse_string(element(2, file:read_file(File))),
    case [D || #let_decl{name = N} = D <- Decls, N =:= Name] of
        [] -> io_lib:format("fn ~s/~B", [Name, A]);
        _ -> io_lib:format("let ~s", [Name])
    end.

%% The private types whose names no token outside their declarations holds.
types(File) ->
    {ok, Text} = file:read_file(File),
    {ok, Decls} = ern_parser:parse_string(Text),
    {ok, Tokens} = ern_lexer:tokenize(unicode:characters_to_list(Text)),
    Private = [T || #type_decl{export = false} = T <- Decls]
        ++ [T || #abstract_decl{export = false, type = T} <- Decls],
    [{File, io_lib:format("type ~s", [Name])}
     || #type_decl{pos = {L, C, End}, name = Name} <- Private,
        [] =:= [P || {typename, P, N} <- Tokens, N =:= Name,
                     not inside(P, {L, C}, End)]].

inside({L, C, _, _}, From, To) ->
    {L, C} >= From andalso {L, C} =< To.
