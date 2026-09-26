%% Report §11.1, §11.4, EEP 48: the documentation chunk "Docs" of a compiled
%% module, which `ern doc`, the shell's `:doc` and the host's own tools
%% read: how it is built from a checked module, and how it is read back.
-module(ern_docs).

-export([chunk_name/0, build/4, read/1]).

-include_lib("parser/include/ern_ast.hrl").

-spec chunk_name() -> binary().
chunk_name() ->
    <<"Docs">>.

%% Report §11.1, EEP 48: the module's documentation, read by `ern doc`
%% (§11.4) and by the host's own tools. One entry per declaration §11.4
%% renders, in source order: its signature as the page shows it, its doc
%% block verbatim, and, for a type, its constructors, fields, and signature
%% entries in the metadata, so a reader of the chunk needs no markdown.
-spec read(binary() | file:filename()) -> {ok, tuple()} | {error, string()}.
read(Beam) ->
    case beam_lib:chunks(Beam, [binary_to_list(chunk_name())]) of
        {ok, {_, [{_, Chunk}]}} ->
            try binary_to_term(Chunk) of
                {docs_v1, _, ernest, _, _, _, _} = Docs -> {ok, Docs};
                _ -> {error, "the documentation chunk is of another compiler version"}
            catch _:_ ->
                {error, "the documentation chunk is of another compiler version"}
            end;
        {error, beam_lib, Reason} ->
            {error, lists:flatten(beam_lib:format_error(Reason))}
    end.

-spec build([atom()], [tuple()], ern_typecheck:env(), binary()) -> tuple().
build(Ns, Decls, Env, Source) ->
    ModDoc = case [T || #module_doc{text = T} <- Decls] of
                 [T | _] -> #{<<"en">> => T};
                 [] -> none
             end,
    Prefix = qname(Ns) ++ ".",
    {docs_v1, erl_anno:new(0), ernest, <<"text/markdown">>, ModDoc, #{source => Source},
     [doc_entry(D, Prefix, Env) || D <- Decls, documented(D)]}.

doc_entry(D, Prefix, Env) ->
    {doc_key(D), erl_anno:new(element(1, doc_pos(D))), doc_signature(D, Prefix, Env),
     case doc_of(D) of
         undefined -> none;
         Doc -> #{<<"en">> => Doc}
     end,
     doc_meta(D)}.

%% A type declaration is a type entry; everything else is a function of the
%% module, under the name and arity the emission gives it.
doc_key(#type_decl{name = N, params = Ps}) -> {type, N, length(Ps)};
doc_key(#abstract_decl{type = #type_decl{name = N, params = Ps}}) -> {type, N, length(Ps)};
doc_key(#foreign_type_decl{name = N, params = Ps}) -> {type, N, length(Ps)};
doc_key(#fn_decl{owner = O, name = N, params = Ps}) ->
    {function, ern_emitter:function_name(O, N), length(Ps)};
doc_key(#foreign_fn_decl{owner = O, name = N, params = Ps}) ->
    {function, ern_emitter:function_name(O, N), length(Ps)};
doc_key(#let_decl{owner = O, name = N}) ->
    {function, ern_emitter:function_name(O, N), 0}.

doc_signature(D, Prefix, Env) ->
    [unicode:characters_to_binary(L)
     || L <- string:split(signature(D, Prefix, Env), "\n", all)].

%% The parameter list as the module writes it, for the shell's completion,
%% and a type's documented parts, for a reader that renders them itself.
doc_meta(#fn_decl{params = Ps}) -> #{params => param_names(Ps)};
doc_meta(#foreign_fn_decl{params = Ps}) -> #{params => param_names(Ps)};
doc_meta(#type_decl{constructors = Cs}) -> #{items => [constructor_item(C) || C <- Cs]};
doc_meta(_) -> #{}.

%% A parameter's name as written; one that is not a plain variable shows
%% as `_`, since the shell completes names and has no source to quote.
param_names(Ps) ->
    [case Pat of #p_var{name = N} -> N; _ -> '_' end || #param{pattern = Pat} <- Ps].

constructor_item(#constructor{doc = Doc, name = N, fields = Fields}) ->
    #{kind => constructor, name => N, doc => doc_or_none(Doc),
      fields => [#{name => F, type => text(syn(T)), doc => doc_or_none(FDoc)}
                 || #field{doc = FDoc, name = F, type = T} <- named_fields(Fields)]}.

doc_or_none(undefined) -> none;
doc_or_none(Doc) -> Doc.

named_fields({named, Fs}) -> Fs;
named_fields(_) -> [].

text(IoList) -> unicode:characters_to_binary(IoList).

%% Report §11.4: every exported declaration, and every declaration with a
%% doc block.
documented(#module_doc{}) -> false;
documented(D) -> doc_exported(D) orelse doc_of(D) =/= undefined.

doc_pos(#type_decl{pos = P}) -> P;
doc_pos(#abstract_decl{pos = P}) -> P;
doc_pos(#foreign_type_decl{pos = P}) -> P;
doc_pos(#fn_decl{pos = P}) -> P;
doc_pos(#foreign_fn_decl{pos = P}) -> P;
doc_pos(#let_decl{pos = P}) -> P.

doc_exported(#type_decl{export = E}) -> E;
doc_exported(#abstract_decl{export = E}) -> E;
doc_exported(#fn_decl{export = E}) -> E;
doc_exported(#let_decl{export = E}) -> E;
doc_exported(#foreign_type_decl{export = E}) -> E;
doc_exported(#foreign_fn_decl{export = E}) -> E.

doc_of(#type_decl{doc = D}) -> D;
doc_of(#abstract_decl{doc = D}) -> D;
doc_of(#fn_decl{doc = D}) -> D;
doc_of(#let_decl{doc = D}) -> D;
doc_of(#foreign_type_decl{doc = D}) -> D;
doc_of(#foreign_fn_decl{doc = D}) -> D.

%% The declaration's type: inferred schemes for fn and let, the
%% declaration itself for the type forms, an abstract type without its
%% representation.
signature(#fn_decl{owner = O, name = N, type = Scheme}, Prefix, Env) ->
    text([Prefix, atom_to_list(shown_name(O, N)), " : ",
          ern_types:format_scheme(Scheme, ern_typecheck:type_state(Env))]);
signature(#let_decl{owner = O, name = N, type = Scheme}, Prefix, Env) ->
    text([Prefix, atom_to_list(shown_name(O, N)), " : ",
          ern_types:format_scheme(Scheme, ern_typecheck:type_state(Env))]);
signature(#foreign_fn_decl{owner = O, name = N, params = Ps, ret = R, effect = E}, Prefix, _) ->
    Type = #t_fn{params = [T || #param{type = T} <- Ps], ret = R, effect = E},
    text([Prefix, atom_to_list(shown_name(O, N)), " : ", syn(Type)]);
signature(#type_decl{} = D, _, _) ->
    text(type_text(D));
signature(#abstract_decl{type = #type_decl{name = TName, params = Ps}}, _, _) ->
    text(["abstract type ", atom_to_list(TName), params_text(Ps)]);
signature(#foreign_type_decl{name = N, params = Ps, eq = Eq}, _, _) ->
    %% report §4.7: a parameter that requires equality is written `k=`
    text(["foreign type ", atom_to_list(N),
          params_text([case lists:member(P, Eq) of
                           true -> list_to_atom(atom_to_list(P) ++ "=");
                           false -> P
                       end || P <- Ps])]).

type_text(#type_decl{name = N, params = Ps, constructors = Cs}) ->
    ["type ", atom_to_list(N), params_text(Ps), " = ",
     lists:join(" | ", [constructor_text(C) || C <- Cs])].

params_text([]) -> "";
params_text(Ps) -> ["(", lists:join(", ", [atom_to_list(P) || P <- Ps]), ")"].

constructor_text(#constructor{name = N, fields = none}) ->
    atom_to_list(N);
constructor_text(#constructor{name = N, fields = {positional, T}}) ->
    [atom_to_list(N), "(", syn(T), ")"];
constructor_text(#constructor{name = N, fields = {named, Fs}}) ->
    [atom_to_list(N), "(",
     lists:join(", ", [[atom_to_list(F), " : ", syn(T)] || #field{name = F, type = T} <- Fs]),
     ")"].

%% A syntactic type as written.
syn(#t_con{path = P, name = N, args = []}) -> qname(P ++ [N]);
syn(#t_con{path = P, name = N, args = As}) ->
    [qname(P ++ [N]), "(", lists:join(", ", [syn(A) || A <- As]), ")"];
syn(#t_var{name = N}) -> atom_to_list(N);
syn(#t_tuple{elems = Es}) -> ["#(", lists:join(", ", [syn(E) || E <- Es]), ")"];
syn(#t_fn{params = Ps, ret = R, effect = E}) ->
    ["(", lists:join(", ", [syn(P) || P <- Ps]), ") -> ", syn(R),
     case E of undefined -> ""; _ -> [" with ", syn(E)] end].

%% The name as the program writes it.
shown_name(undefined, N) -> N;
shown_name(Owner, N) -> list_to_atom(atom_to_list(Owner) ++ "." ++ atom_to_list(N)).

qname(Parts) ->
    lists:flatten(lists:join(".", [atom_to_list(P) || P <- Parts])).
