%% The interface chunk "ErnI" of a compiled module, report §11.1: its name,
%% its format, how it is written and read, and the hash a dependent
%% records. The emitter writes it, and the compiler, the shell, the page
%% writer and the prelude's reading of the standard library read it, all
%% through here, so that the format has one owner.
-module(ern_interface).

-export([chunk_name/0, encode/2, read/1, hash/1]).

-export_type([chunk/0]).

-include_lib("typer/include/ern_types.hrl").

-define(CHUNK, <<"ErnI">>).
-define(FORMAT, 4).

-type chunk() :: #{format := pos_integer(), interface := #interface{}, source_hash := binary(),
                   deps := [{[atom()], binary()}], compiler => binary(),
                   stdlib => binary() | none, source_path => binary()}.

-spec chunk_name() -> binary().
chunk_name() ->
    ?CHUNK.

%% The chunk's bytes: the build's facts beside the interface in canonical
%% form, and the format they are written in.
-spec encode(map(), #interface{}) -> binary().
encode(Facts, Interface) ->
    term_to_binary(Facts#{format => ?FORMAT, interface => canonical(Interface, keep)}).

%% A chunk of another format, from another version of the compiler, reads
%% as an error, which makes the module stale (report §11.1).
-spec read(binary() | file:filename()) -> {ok, chunk()} | {error, string()}.
read(Beam) ->
    case beam_lib:chunks(Beam, [binary_to_list(?CHUNK)]) of
        {ok, {_, [{_, Chunk}]}} ->
            try binary_to_term(Chunk) of
                #{format := ?FORMAT,
                  interface := {interface, Namespace, Types, Values, Lets}} = Read ->
                    Interface = #interface{namespace = Namespace, types = maps:from_list(Types),
                                           values = maps:from_list(Values), lets = Lets},
                    {ok, Read#{interface => Interface}};
                _ ->
                    {error, "the interface chunk is of another compiler version"}
            catch _:_ ->
                {error, "the interface chunk is of another compiler version"}
            end;
        %% the host's text of the error quotes the bytes it was given
        {error, beam_lib, _} ->
            {error, "not a compiled module"}
    end.

-spec hash(#interface{}) -> binary().
hash(Interface) ->
    crypto:hash(sha256, term_to_binary(canonical(Interface, strip))).

%% Quantified variables renumbered and maps as sorted lists, so that equal
%% interfaces have equal bytes (report §11.1). VariableNames, keep or
%% strip: the hash leaves the variables' names out, since a renamed
%% annotation changes no dependent.
canonical(#interface{namespace = Namespace, types = Types, values = Values, lets = Lets},
          VariableNames) ->
    {interface, Namespace, lists:sort(maps:to_list(Types)),
     lists:sort([{QualifiedName, canonical_scheme(Scheme, VariableNames)}
                 || {QualifiedName, Scheme} <- maps:to_list(Values)]),
     lists:sort(Lets)}.

canonical_scheme(#scheme{quantified = Quantified, type = Type, names = Names,
                         requirement = Requirement}, VariableNames) ->
    Numbers = maps:from_list([{Id, Number} || {Number, {Id, _}} <- lists:enumerate(Quantified)]),
    #scheme{quantified = [{maps:get(Id, Numbers), Restrictions}
                          || {Id, Restrictions} <- Quantified],
            type = renumber(Type, Numbers),
            %% report §4.9, §11.1: a declaration's requirement is in its
            %% interface, over the scheme's own variables
            requirement = [{maps:get(Id, Numbers), Member} || {Id, Member} <- Requirement],
            names = case VariableNames of
                        keep -> maps:from_list([{maps:get(Id, Numbers), Name}
                                                || {Id, Name} <- maps:to_list(Names)]);
                        strip -> #{}
                    end}.

renumber({tvar, Id}, Numbers) ->
    {tvar, maps:get(Id, Numbers, Id)};
renumber({tcon, QualifiedName, Args}, Numbers) ->
    {tcon, QualifiedName, [renumber(Arg, Numbers) || Arg <- Args]};
renumber({ttuple, Elements}, Numbers) ->
    {ttuple, [renumber(Element, Numbers) || Element <- Elements]};
renumber({tfn, Params, Effect, Result}, Numbers) ->
    {tfn, [renumber(Param, Numbers) || Param <- Params], renumber(Effect, Numbers),
     renumber(Result, Numbers)};
renumber(Type, _) ->
    Type.
