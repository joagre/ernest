-module(asm_novalidate).
-export([assemble/1]).

%% Assemble a hand-written .S straight through beam_asm, skipping
%% beam_validator, for the experiment's callee-save variant alone.
assemble(File) ->
    {ok, Forms} = file:consult(File),
    {value, {module, Mod}} = lists:keysearch(module, 1, Forms),
    {value, {exports, Exp}} = lists:keysearch(exports, 1, Forms),
    {value, {attributes, Attr}} = lists:keysearch(attributes, 1, Forms),
    {value, {labels, NumLabels}} = lists:keysearch(labels, 1, Forms),
    Fs = functions([F || F <- Forms, not is_header(F)]),
    {ok, Code} = beam_asm:module({Mod, Exp, Attr, #{}, Fs, NumLabels}, [], [], []),
    ok = file:write_file(atom_to_list(Mod) ++ ".beam", Code),
    Mod.

is_header({module, _}) -> true;
is_header({exports, _}) -> true;
is_header({attributes, _}) -> true;
is_header({labels, _}) -> true;
is_header(_) -> false.

functions([{function, Name, Arity, Entry} | Rest]) ->
    {Is, More} = lists:splitwith(fun(I) -> not (is_tuple(I) andalso element(1, I) =:= function) end, Rest),
    [{function, Name, Arity, Entry, Is} | functions(More)];
functions([]) -> [].
