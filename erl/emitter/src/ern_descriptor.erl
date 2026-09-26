%% Report §8.4, Appendix E.1: the descriptor of a type, the runtime's
%% reading of it: what the foreign boundary checks a value against, what a
%% proxy exposes an address with, and what `Io.debug` and the shell print a
%% value by, one printer (§11.2). A recursive type refers back to its mu.
-module(ern_descriptor).

-export([describe/3]).

-include_lib("typer/include/ern_types.hrl").

%% The type's names and the module it is seen from.
-record(cx, {env, ns = []}).

%% The descriptor of type T, whose names Env knows, seen from the module
%% Ns: from any other, an abstract type's representation is not the
%% program's to print (report §4.4).
-spec describe(term(), ern_typecheck:env(), [atom()]) -> term().
describe(T, Env, Ns) ->
    Cx = #cx{env = Env, ns = Ns},
    {D, _} = desc(ern_types:zonk(T, ern_typecheck:type_state(Env)), #{}, Cx),
    D.

%% Seen maps each user type enclosing the one being described to the id
%% its mu binds, so a recursive type refers back instead of unfolding; a
%% sibling is described in full, since a ref reaches only an enclosing mu.
desc({tvar, _}, Seen, _) -> {any, Seen};
desc(pure, Seen, _) -> {any, Seen};
desc({ttuple, Es}, Seen, Cx) ->
    {Ds, Seen1} = descs(Es, Seen, Cx),
    {{tuple, Ds}, Seen1};
desc({tfn, Ps, _, R}, Seen, Cx) ->
    %% report §7.4: a function value from foreign code has its result
    %% checked at each call, against the result's descriptor
    {D, Seen1} = desc(R, Seen, Cx),
    {{'fun', length(Ps), D, text_binary("foreign return does not match ", R, Cx)}, Seen1};
desc({tcon, ['Int'], []}, Seen, _) -> {int, Seen};
desc({tcon, ['Float'], []}, Seen, _) -> {float, Seen};
desc({tcon, ['Bool'], []}, Seen, _) -> {bool, Seen};
desc({tcon, ['Char'], []}, Seen, _) -> {char, Seen};
desc({tcon, ['String'], []}, Seen, _) -> {string, Seen};
desc({tcon, ['Bytes'], []}, Seen, _) -> {bytes, Seen};
desc({tcon, ['Address'], [M]}, Seen, Cx) ->
    %% the address's messages, for the proxy that exposes it (report §8.4)
    {D, Seen1} = desc(M, Seen, Cx),
    {{pid, D, text_binary("message does not match ", M, Cx)}, Seen1};
desc({tcon, ['Reply'], _}, Seen, _) -> {ref, Seen};
desc({tcon, ['Process'], []}, Seen, _) -> {process, Seen};
desc({tcon, ['Foreign'], []}, Seen, _) -> {any, Seen};
desc({tcon, ['Never'], []}, Seen, _) -> {never, Seen};
desc({tcon, ['List'], [A]}, Seen, Cx) ->
    {D, Seen1} = desc(A, Seen, Cx),
    {{list, D}, Seen1};
desc({tcon, ['Map'], [K, V]}, Seen, Cx) ->
    {[DK, DV], Seen1} = descs([K, V], Seen, Cx),
    {{map, DK, DV}, Seen1};
desc({tcon, ['Set'], [A]}, Seen, Cx) ->
    {D, Seen1} = desc(A, Seen, Cx),
    {{set, D}, Seen1};
desc({tcon, Q, Args} = T, Seen, #cx{env = Env} = Cx) ->
    case Seen of
        #{T := Id} ->
            {{ref, Id}, Seen};
        _ ->
            case ern_typecheck:lookup_type(Q, Env) of
                #tinfo{foreign = true} ->
                    {any, Seen};
                #tinfo{constructors = Cs, abstract = Abstract} ->
                    Id = map_size(Seen) + 1,
                    {ConDs, _} =
                        lists:mapfoldl(fun(#cinfo{name = Tag, fields = Spec} = C, S) ->
                                           {Ds, S1} = descs(fields(C, Args, Cx), S, Cx),
                                           {con_desc(Tag, Spec, Ds), S1}
                                       end, Seen#{T => Id}, Cs),
                    Con = {con, ConDs},
                    D = case refers(Con, Id) of
                            true -> {mu, Id, Con};
                            false -> Con
                        end,
                    %% report §4.4: seen from outside its module, an abstract
                    %% type's representation is not the program's to print
                    case Abstract andalso lists:droplast(Q) =/= Cx#cx.ns of
                        true -> {{abstract, D}, Seen};
                        false -> {D, Seen}
                    end
            end
    end.

%% A named constructor's descriptor keeps its field names, in canonical
%% order (report §3.5), for printing.
con_desc(Tag, {named, Names}, Ds) -> {Tag, Ds, Names};
con_desc(Tag, _, Ds) -> {Tag, Ds}.

refers({ref, Id}, Id) -> true;
refers(T, Id) when is_tuple(T) -> lists:any(fun(X) -> refers(X, Id) end, tuple_to_list(T));
refers(L, Id) when is_list(L) -> lists:any(fun(X) -> refers(X, Id) end, L);
refers(_, _) -> false.

descs(Ts, Seen, Cx) ->
    lists:mapfoldl(fun(T, S) -> desc(T, S, Cx) end, Seen, Ts).

%% A constructor's field types at the type's arguments: its scheme is
%% quantified over the type's parameters, which its result type lists in
%% order as distinct variables once instantiated.
fields(#cinfo{scheme = Scheme}, Args, #cx{env = Env}) ->
    {FT, _} = ern_types:instantiate(Scheme, ern_typecheck:type_state(Env)),
    {FieldTs, {tcon, _, Params}} = case FT of
                                       {tfn, Fs, _, R} -> {Fs, R};
                                       R -> {[], R}
                                   end,
    Sub = maps:from_list(lists:zip([Id || {tvar, Id} <- Params], Args)),
    [subst(F, Sub) || F <- FieldTs].

subst({tvar, Id} = T, Sub) -> maps:get(Id, Sub, T);
subst({tcon, Q, Args}, Sub) -> {tcon, Q, [subst(A, Sub) || A <- Args]};
subst({ttuple, Es}, Sub) -> {ttuple, [subst(E, Sub) || E <- Es]};
subst({tfn, Ps, E, R}, Sub) -> {tfn, [subst(P, Sub) || P <- Ps], subst(E, Sub), subst(R, Sub)};
subst(pure, _) -> pure.

text_binary(Prefix, T, #cx{env = Env}) ->
    unicode:characters_to_binary(Prefix ++ ern_types:format(T, ern_typecheck:type_state(Env))).
