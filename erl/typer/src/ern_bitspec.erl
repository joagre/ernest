%% Report §5.11: the specifiers of a bitstring segment, read into one map
%% with their defaults, for the checker, which types a segment by it, and
%% the emitter, which builds and matches the segment by it.
-module(ern_bitspec).

-export([spec/1]).

-include_lib("parser/include/ern_ast.hrl").

%% Report §5.11: the specifiers of a segment as one map, kind, size (none,
%% {const, Bits}, or {expr, Expr}), unit, endian, sign, with the defaults,
%% or the error of a conflict, a sign or byte order the kind does not
%% take, or an impossible width. The unit is what a size counts, 8 bits
%% for `bytes` and 1 otherwise; no specifier sets it.
-spec spec([term()]) -> {ok, map()} | {error, string()}.
spec(Specs) ->
    try
        Spec = lists:foldl(fun spec_fold/2, #{}, Specs),
        Kind = maps:get(kind, Spec, int),
        Unit = case Kind of bytes -> 8; _ -> 1 end,
        Size = case maps:get(size, Spec, none) of
                   none when Kind =:= int -> {const, 8};
                   none when Kind =:= float -> {const, 64};
                   Given -> Given
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
        not (Utf andalso maps:is_key(size, Spec)) orelse throw("a utf segment has no size"),
        case {Kind, Size} of
            {float, {const, Bits}} when Bits =/= 16, Bits =/= 32, Bits =/= 64 ->
                throw("a float segment is 16, 32, or 64 bits");
            _ -> ok
        end,
        {ok, Spec#{kind => Kind, size => Size, unit => Unit,
                   endian => maps:get(endian, Spec, big), sign => maps:get(sign, Spec, unsigned)}}
    catch
        throw:Message -> {error, Message}
    end.

spec_fold({size, #e_literal{kind = int, value = Bits}}, Spec) -> once(size, {const, Bits}, Spec);
spec_fold({size, Expr}, Spec) -> once(size, {expr, Expr}, Spec);
spec_fold(Kind, Spec) when Kind =:= int; Kind =:= float; Kind =:= bytes; Kind =:= utf8;
                           Kind =:= utf16; Kind =:= utf32 ->
    once(kind, Kind, Spec);
spec_fold(Endian, Spec) when Endian =:= big; Endian =:= little -> once(endian, Endian, Spec);
spec_fold(Sign, Spec) when Sign =:= signed; Sign =:= unsigned -> once(sign, Sign, Spec).

once(Key, Value, Spec) ->
    case Spec of
        #{Key := Other} ->
            throw("conflicting bitstring specifiers " ++ spec_text(Key, Other) ++ " and "
                  ++ spec_text(Key, Value));
        _ ->
            Spec#{Key => Value}
    end.

spec_text(size, {const, Bits}) -> "`size(" ++ integer_to_list(Bits) ++ ")`";
spec_text(size, _) -> "`size(...)`";
spec_text(_, Value) -> "`" ++ atom_to_list(Value) ++ "`".
