%% The helpers the tests share beside their waits (ern_waits): a module
%% compiled from text, loaded, and unloaded again, a unit out of the code
%% table among them; the messages of one tag a process's mailbox holds; the
%% side of an Either; the options of a run whose standard output is let
%% go; and a process of another node.
-module(ern_helpers).

-export([loaded/2, unloaded/1, taken/1, side/1, quiet/0, quiet/1, far_process/0]).

%% Module compiled from Forms, each the text of one form, every function of
%% no argument exported, and loaded from memory, so that no file is
%% written; a test unloads it once it ends (unloaded/1), since the flake
%% hunt runs a test again in the same host.
-spec loaded(module(), [iodata()]) -> module().
loaded(Module, Forms) ->
    Texts = [io_lib:format("-module(~w).", [Module]),
             "-compile([export_all, nowarn_export_all])." | Forms],
    {ok, Module, Binary} = compile:forms([form(Text) || Text <- Texts]),
    {module, Module} = code:load_binary(Module, atom_to_list(Module) ++ ".erl", Binary),
    Module.

form(Text) ->
    {ok, Tokens, _} = erl_scan:string(lists:flatten(Text)),
    {ok, Form} = erl_parse:parse_form(Tokens),
    Form.

%% Report §8.7, §11.2: Module out of the code table, where it is a unit
%% there, and out of the host, its old code and its current purged; a
%% module the host does not hold is passed over.
-spec unloaded(module()) -> ok.
unloaded(Module) ->
    ok = ern_code:unloaded(Module),
    _ = code:purge(Module),
    _ = code:delete(Module),
    _ = code:purge(Module),
    ok.

%% What the calling process's mailbox holds under Tag, every `{Tag, Value}`
%% so far, taken, their values in the order they came.
-spec taken(term()) -> [term()].
taken(Tag) ->
    receive {Tag, Value} -> [Value | taken(Tag)] after 0 -> [] end.

%% Which side of an Either a result is, Left or Right.
-spec side({'Left' | 'Right', term()}) -> 'Left' | 'Right'.
side({Side, _}) -> Side.

%% A run's options, ern_rt:run_main/3's, its standard output let go.
-spec quiet() -> map().
quiet() ->
    #{stdout => fun(_) -> ok end}.

%% The same, with Options beside it.
-spec quiet(map()) -> map().
quiet(Options) ->
    maps:merge(quiet(), Options).

%% Report §8.7: a process of another node, `other@node.er`, which no
%% connection names, read from its external term.
-spec far_process() -> pid().
far_process() ->
    binary_to_term(<<131, 88, 119, 13, "other@node.er", 0:32, 1:32, 1:32>>).
