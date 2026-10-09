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
-define(FORMAT, 8).

-type chunk() :: #{format := pos_integer(), interface := #interface{}, source_hash := binary(),
                   deps := [{[atom()], binary()}], references => [{[atom()], binary()}],
                   compiler => binary(), stdlib => binary() | none,
                   source_path => binary()}.

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
            %% data alone, since a `.erc` may come from anywhere (ern_chunk)
            try ern_chunk:term(Chunk) of
                {ok, #{format := ?FORMAT,
                       interface := {interface, Namespace, Types, Values, Lets, PrivateTypes,
                                     Identities, Reaches}}
                       = Read} ->
                    Interface = #interface{namespace = Namespace, types = maps:from_list(Types),
                                           values = maps:from_list(Values), lets = Lets,
                                           private_types = maps:from_list(PrivateTypes),
                                           identities = maps:from_list(Identities),
                                           reaches = maps:from_list(Reaches)},
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

%% The hash a dependent records, which leaves the definitions' hashes out,
%% and their reaches, which follow from them: a change to a dependency's
%% bodies recompiles a dependent only where it changes a hash the
%% dependent's forms reference, which the build compares (report §11.1).
-spec hash(#interface{}) -> binary().
hash(Interface) ->
    Bodiless = Interface#interface{identities = #{}, reaches = #{}},
    crypto:hash(sha256, term_to_binary(canonical(Bodiless, strip))).

%% Quantified variables renumbered and maps as sorted lists, so that equal
%% interfaces have equal bytes (report §11.1). VariableNames, keep or
%% strip: the hash leaves the variables' names out, since a renamed
%% annotation changes no dependent.
canonical(#interface{namespace = Namespace, types = Types, values = Values, lets = Lets,
                     private_types = PrivateTypes, identities = Identities, reaches = Reaches},
          VariableNames) ->
    {interface, Namespace,
     lists:sort([{QualifiedName, canonical_type(TypeInfo, VariableNames)}
                 || {QualifiedName, TypeInfo} <- maps:to_list(Types)]),
     lists:sort([{QualifiedName, canonical_scheme(Scheme, #{}, VariableNames)}
                 || {QualifiedName, Scheme} <- maps:to_list(Values)]),
     lists:sort(Lets),
     %% report §11.1: a change to what an abstract type's fields name changes
     %% how a dependent describes its values, so it is in the hash
     lists:sort([{QualifiedName, canonical_type(TypeInfo, VariableNames)}
                 || {QualifiedName, TypeInfo} <- maps:to_list(PrivateTypes)]),
     lists:sort(maps:to_list(Identities)),
     lists:sort(maps:to_list(Reaches))}.

%% A type's parameters numbered by place, and its constructors' schemes
%% over the same numbers; the names its declaration writes are left out of
%% the hash, as a value's variables' are.
canonical_type(#type_info{params = Params, param_names = ParamNames,
                          constructors = Constructors} = TypeInfo, VariableNames) ->
    Numbers = maps:from_list([{Id, Number} || {Number, {tvar, Id}} <- lists:enumerate(Params)]),
    TypeInfo#type_info{
      params = [{tvar, maps:get(Id, Numbers)} || {tvar, Id} <- Params],
      param_names = case VariableNames of
                        keep -> ParamNames;
                        strip -> []
                    end,
      constructors = [Constructor#constructor_info{
                        scheme = canonical_scheme(Scheme, Numbers, VariableNames)}
                      || #constructor_info{scheme = Scheme} = Constructor <- Constructors]}.

%% Numbers: the numbers some quantified variables have already, a type's
%% parameters; the rest are numbered after them in the order quantified.
canonical_scheme(#scheme{quantified = Quantified, type = Type, names = Names,
                         requirement = Requirement}, Given, VariableNames) ->
    Rest = [Id || {Id, _} <- Quantified, not is_map_key(Id, Given)],
    Numbers = maps:merge(Given, maps:from_list([{Id, maps:size(Given) + Number}
                                                || {Number, Id} <- lists:enumerate(Rest)])),
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
