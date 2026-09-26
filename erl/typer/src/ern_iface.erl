%% The interface chunk "ErnI" of a compiled module, report §11.1: its name,
%% its format, how it is written and read, and the hash a dependent
%% records. The emitter writes it, and the compiler, the shell, the page
%% writer and the prelude's reading of the standard library read it, all
%% through here, so that the format has one owner.
-module(ern_iface).

-export([chunk_name/0, encode/2, read/1, hash/1]).

-export_type([chunk/0]).

-include_lib("typer/include/ern_types.hrl").

-define(CHUNK, <<"ErnI">>).
-define(FORMAT, 2).

-type chunk() :: #{iface := #iface{}, source_hash := binary(), deps := [{[atom()], binary()}],
                   compiler => binary(), stdlib => binary() | none}.

-spec chunk_name() -> binary().
chunk_name() ->
    ?CHUNK.

%% The chunk's bytes: the build's facts beside the interface in canonical
%% form, and the format they are written in.
-spec encode(map(), #iface{}) -> binary().
encode(Meta, Iface) ->
    term_to_binary(Meta#{format => ?FORMAT, iface => canonical(Iface, keep)}).

%% A chunk of another format, from another version of the compiler, reads
%% as an error, which makes the module stale (report §11.1).
-spec read(binary() | file:filename()) -> {ok, chunk()} | {error, string()}.
read(Beam) ->
    case beam_lib:chunks(Beam, [binary_to_list(?CHUNK)]) of
        {ok, {_, [{_, Chunk}]}} ->
            try binary_to_term(Chunk) of
                #{format := ?FORMAT, iface := {iface, Ns, Types, Values, Lets}} = Map ->
                    {ok, Map#{iface => #iface{namespace = Ns, types = maps:from_list(Types),
                                              values = maps:from_list(Values), lets = Lets}}};
                _ ->
                    {error, "the interface chunk is of another compiler version"}
            catch _:_ ->
                {error, "the interface chunk is of another compiler version"}
            end;
        {error, beam_lib, Reason} ->
            {error, lists:flatten(beam_lib:format_error(Reason))}
    end.

-spec hash(#iface{}) -> binary().
hash(Iface) ->
    crypto:hash(sha256, term_to_binary(canonical(Iface, strip))).

%% Quantified variables renumbered and maps as sorted lists, so that equal
%% interfaces have equal bytes (plan 2.4). The hash leaves the variables'
%% names out: a renamed annotation changes no dependent.
canonical(#iface{namespace = Ns, types = Ts, values = Vs, lets = Lets}, Names) ->
    {iface, Ns, lists:sort(maps:to_list(Ts)),
     lists:sort([{Q, canonical_scheme(S, Names)} || {Q, S} <- maps:to_list(Vs)]),
     lists:sort(Lets)}.

canonical_scheme(#scheme{vars = Vars, type = T, names = Names}, Keep) ->
    Map = maps:from_list([{Id, N} || {{Id, _}, N} <- lists:zip(Vars, lists:seq(1, length(Vars)))]),
    #scheme{vars = [{maps:get(Id, Map), Flags} || {Id, Flags} <- Vars],
            type = renumber(T, Map),
            names = case Keep of
                        keep -> maps:from_list([{maps:get(Id, Map), N}
                                                || {Id, N} <- maps:to_list(Names)]);
                        strip -> #{}
                    end}.

renumber({tvar, Id}, Map) -> {tvar, maps:get(Id, Map, Id)};
renumber({tcon, N, As}, Map) -> {tcon, N, [renumber(A, Map) || A <- As]};
renumber({ttuple, Es}, Map) -> {ttuple, [renumber(E, Map) || E <- Es]};
renumber({tfn, Ps, E, R}, Map) -> {tfn, [renumber(P, Map) || P <- Ps], renumber(E, Map),
                                   renumber(R, Map)};
renumber(T, _) -> T.
