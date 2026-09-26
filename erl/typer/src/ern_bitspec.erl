%% Report §5.11: the specifiers of a bitstring segment, read into one map
%% with their defaults, for the checker, which types a segment by it, and
%% the emitter, which builds and matches the segment by it.
-module(ern_bitspec).

-export([spec/1]).

-include_lib("parser/include/ern_ast.hrl").

%% Report §5.11: the specifiers of a segment as one map, kind, size
%% (none, {const, N}, or {expr, E}), unit, endian, sign, with the defaults,
%% or the error of a conflict, a sign or byte order the kind does not take,
%% or an impossible width.
-spec spec([term()]) -> {ok, map()} | {error, string()}.
spec(Specs) ->
    try
        Spec = lists:foldl(fun spec_fold/2, #{}, Specs),
        Kind = maps:get(kind, Spec, int),
        Unit = maps:get(unit, Spec, case Kind of bytes -> 8; _ -> 1 end),
        Size = case maps:get(size, Spec, none) of
                   none when Kind =:= int -> {const, 8};
                   none when Kind =:= float -> {const, 64};
                   S -> S
               end,
        case {Kind, Spec} of
            {int, _} -> ok;
            {_, #{sign := Sign}} ->
                throw("`" ++ atom_to_list(Sign) ++ "` applies to an `int` segment only, not a `"
                      ++ atom_to_list(Kind) ++ "` one");
            _ -> ok
        end,
        case {Kind, Spec} of
            {_, #{endian := Endian}} when Kind =:= bytes; Kind =:= utf8 ->
                throw("`" ++ atom_to_list(Endian) ++ "` applies to an `int`, `float`, `utf16`"
                      " or `utf32` segment, not a `" ++ atom_to_list(Kind) ++ "` one");
            _ -> ok
        end,
        Utf = lists:member(Kind, [utf8, utf16, utf32]),
        case Utf andalso (maps:is_key(size, Spec) orelse maps:is_key(unit, Spec)) of
            true -> throw("a utf segment has no size or unit");
            false -> ok
        end,
        case Unit >= 1 andalso Unit =< 256 of
            true -> ok;
            false -> throw("unit is 1 to 256 on this runtime")
        end,
        case {Kind, Size} of
            {float, {const, N}} when N =/= 16, N =/= 32, N =/= 64 ->
                throw("a float segment is 16, 32, or 64 bits");
            {bytes, {const, N}} when (N * Unit) rem 8 =/= 0 ->
                throw("a `bytes` segment is a whole number of bytes, not "
                      ++ integer_to_list(N * Unit) ++ " bits");
            _ -> ok
        end,
        {ok, Spec#{kind => Kind, size => Size, unit => Unit,
                   endian => maps:get(endian, Spec, big), sign => maps:get(sign, Spec, unsigned)}}
    catch
        throw:Msg -> {error, Msg}
    end.

spec_fold({size, #e_lit{kind = int, value = N}}, Spec) -> once(size, {const, N}, Spec);
spec_fold({size, E}, Spec) -> once(size, {expr, E}, Spec);
spec_fold({unit, N}, Spec) -> once(unit, N, Spec);
spec_fold(K, Spec) when K =:= int; K =:= float; K =:= bytes; K =:= utf8; K =:= utf16;
                        K =:= utf32 ->
    once(kind, K, Spec);
spec_fold(E, Spec) when E =:= big; E =:= little -> once(endian, E, Spec);
spec_fold(S, Spec) when S =:= signed; S =:= unsigned -> once(sign, S, Spec).

once(Key, Value, Spec) ->
    case Spec of
        #{Key := Other} ->
            throw("conflicting bitstring specifiers " ++ spec_text(Key, Other) ++ " and "
                  ++ spec_text(Key, Value));
        _ ->
            Spec#{Key => Value}
    end.

spec_text(size, {const, N}) -> "`size(" ++ integer_to_list(N) ++ ")`";
spec_text(size, _) -> "`size(...)`";
spec_text(unit, N) -> "`unit(" ++ integer_to_list(N) ++ ")`";
spec_text(_, A) -> "`" ++ atom_to_list(A) ++ "`".
