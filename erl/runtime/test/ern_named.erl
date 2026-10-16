%% A unit's function by its Ernest name, for the tests that call the
%% standard library or a program from Erlang: a unit names its functions by
%% their position (report §11.1), and its '$code'/0 says which holds each
%% name (ern_code:function/2).
-module(ern_named).

-export([function/2, main/1, functions/1]).

%% The function of Unit that holds the declaration Name of its module,
%% `sort`, or [MemberOf, Name] for a member, as a fun. The standard library
%% is loaded first, as a run's start loads it, since a test calls it from a
%% process of its own, which loads no unit at its first call
%% (ern_rt:stdlib_modules/0).
-spec function(module(), atom() | [atom()]) -> function().
function(Unit, Name) ->
    _ = ern_rt:stdlib_modules(),
    {module, Unit} = ern_code:ensure_loaded(Unit),
    [Namespace] = [Namespace || {Namespace, {calls, _}} <- Unit:'$code'()],
    Parts = case Name of
                [_ | _] -> Name;
                _ -> [Name]
            end,
    {Function, Arity} = ern_code:function(Unit, Namespace ++ Parts),
    erlang:make_fun(Unit, Function, Arity).

%% The entry point `main` of Unit, as a fun of no argument.
-spec main(module()) -> function().
main(Unit) ->
    function(Unit, main).

%% Unit's functions by their names, Name to the fun of function/2, so that
%% a test reads `List(sort)(Elements, Compare)` where a call by name read
%% `List:sort(Elements, Compare)`.
-spec functions(module()) -> fun((atom() | [atom()]) -> function()).
functions(Unit) ->
    fun(Name) -> function(Unit, Name) end.
