%% Report §11.1, §11.4, EEP 48: the documentation chunk "Docs" of a compiled
%% module, which `ern doc`, the shell's `:doc` and the host's own tools
%% read: how it is built from a checked module, and how it is read back.
-module(ern_docs).

-export([chunk_name/0, read/1, build/4]).

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
build(Namespace, Declarations, Env, Source) ->
    ModuleDoc = case [Text || #module_doc{text = Text} <- Declarations] of
                    [Text | _] -> #{<<"en">> => Text};
                    [] -> none
                end,
    Prefix = qualified_name_text(Namespace) ++ ".",
    {docs_v1, erl_anno:new(0), ernest, <<"text/markdown">>, ModuleDoc, #{source => Source},
     [doc_entry(Declaration, Prefix, Env) || Declaration <- Declarations, documented(Declaration)]}.

doc_entry(Declaration, Prefix, Env) ->
    {doc_key(Declaration), erl_anno:new(element(1, doc_span(Declaration))),
     doc_signature(Declaration, Prefix, Env),
     case doc_of(Declaration) of
         undefined -> none;
         Doc -> #{<<"en">> => Doc}
     end,
     case doc_exported(Declaration) of
         true -> doc_meta(Declaration);
         false -> (doc_meta(Declaration))#{private => true}
     end}.

%% A type declaration is a type entry; everything else is a function of the
%% module, under the name and arity the emission gives it.
doc_key(#type_declaration{name = Name, params = Params}) -> {type, Name, length(Params)};
doc_key(#abstract_declaration{declaration = #type_declaration{name = Name, params = Params}}) ->
    {type, Name, length(Params)};
doc_key(#foreign_type_declaration{name = Name, params = Params}) -> {type, Name, length(Params)};
doc_key(#fn_declaration{owner = Owner, name = Name, params = Params}) ->
    {function, ern_emitter:function_name(Owner, Name), length(Params)};
doc_key(#foreign_fn_declaration{owner = Owner, name = Name, params = Params}) ->
    {function, ern_emitter:function_name(Owner, Name), length(Params)};
doc_key(#let_declaration{name = Name}) ->
    {function, ern_emitter:function_name(undefined, Name), 0}.

doc_signature(Declaration, Prefix, Env) ->
    [unicode:characters_to_binary(Line)
     || Line <- string:split(signature(Declaration, Prefix, Env), "\n", all)].

%% The parameter list as the module writes it, for the shell's completion,
%% and a type's documented parts, for a reader that renders them itself;
%% `private` marks a declaration the module does not export (report §11.4).
doc_meta(#fn_declaration{params = Params}) -> #{params => param_names(Params)};
doc_meta(#foreign_fn_declaration{params = Params}) -> #{params => param_names(Params)};
doc_meta(#type_declaration{constructors = Constructors}) ->
    #{items => [constructor_item(Constructor) || Constructor <- Constructors]};
doc_meta(_) -> #{}.

%% A parameter's name as written; one that is not a plain variable shows
%% as `_`, since the shell completes names and has no source to quote.
param_names(Params) ->
    [case Pattern of #p_var{name = Name} -> Name; _ -> '_' end
     || #param{pattern = Pattern} <- Params].

constructor_item(#constructor{doc = Doc, name = Name, fields = Fields}) ->
    #{kind => constructor, name => Name, doc => doc_or_none(Doc),
      fields => [#{name => Field, type => text(syntax_text(Annotation)),
                   doc => doc_or_none(FieldDoc)}
                 || #field{doc = FieldDoc, name = Field,
                           annotation = Annotation} <- named_fields(Fields)]}.

doc_or_none(undefined) -> none;
doc_or_none(Doc) -> Doc.

named_fields({named, Fields}) -> Fields;
named_fields(_) -> [].

text(IoList) -> unicode:characters_to_binary(IoList).

%% Report §11.4: every exported declaration, and every declaration with a
%% doc block.
documented(#module_doc{}) -> false;
documented(Declaration) -> doc_exported(Declaration) orelse doc_of(Declaration) =/= undefined.

doc_span(#type_declaration{span = Span}) -> Span;
doc_span(#abstract_declaration{span = Span}) -> Span;
doc_span(#foreign_type_declaration{span = Span}) -> Span;
doc_span(#fn_declaration{span = Span}) -> Span;
doc_span(#foreign_fn_declaration{span = Span}) -> Span;
doc_span(#let_declaration{span = Span}) -> Span.

doc_exported(#type_declaration{export = Export}) -> Export;
doc_exported(#abstract_declaration{export = Export}) -> Export;
doc_exported(#fn_declaration{export = Export}) -> Export;
doc_exported(#let_declaration{export = Export}) -> Export;
doc_exported(#foreign_type_declaration{export = Export}) -> Export;
doc_exported(#foreign_fn_declaration{export = Export}) -> Export.

doc_of(#type_declaration{doc = Doc}) -> Doc;
doc_of(#abstract_declaration{doc = Doc}) -> Doc;
doc_of(#fn_declaration{doc = Doc}) -> Doc;
doc_of(#let_declaration{doc = Doc}) -> Doc;
doc_of(#foreign_type_declaration{doc = Doc}) -> Doc;
doc_of(#foreign_fn_declaration{doc = Doc}) -> Doc.

%% The declaration's type: inferred schemes for fn and let, the
%% declaration itself for the type forms, an abstract type without its
%% representation.
signature(#fn_declaration{owner = Owner, name = Name, scheme = Scheme}, Prefix, Env) ->
    text([Prefix, atom_to_list(shown_name(Owner, Name)), " : ",
          ern_types:format_scheme(Scheme, ern_typecheck:type_state(Env))]);
signature(#let_declaration{name = Name, scheme = Scheme}, Prefix, Env) ->
    text([Prefix, atom_to_list(Name), " : ",
          ern_types:format_scheme(Scheme, ern_typecheck:type_state(Env))]);
signature(#foreign_fn_declaration{owner = Owner, name = Name, params = Params, result_type = Result,
                                  effect = Effect},
          Prefix, _) ->
    Type = #t_fn{params = [Annotation || #param{annotation = Annotation} <- Params],
                 result_type = Result, effect = Effect},
    text([Prefix, atom_to_list(shown_name(Owner, Name)), " : ", syntax_text(Type)]);
signature(#type_declaration{} = Declaration, _, _) ->
    text(type_text(Declaration));
signature(#abstract_declaration{declaration = #type_declaration{name = TypeName, params = Params}},
          _, _) ->
    text(["abstract type ", atom_to_list(TypeName), params_text(Params)]);
signature(#foreign_type_declaration{name = Name, params = Params, equality = Equality}, _, _) ->
    %% report §4.7: a parameter that requires equality is written `k=`
    text(["foreign type ", atom_to_list(Name),
          params_text([case lists:member(Param, Equality) of
                           true -> list_to_atom(atom_to_list(Param) ++ "=");
                           false -> Param
                       end || Param <- Params])]).

%% Report §11.4, §11.6: the declaration on one line, or, where that line
%% would pass 100 characters, a constructor a line as `ern format` lays it out.
type_text(#type_declaration{name = Name, params = Params, constructors = Constructors}) ->
    Head = ["type ", atom_to_list(Name), params_text(Params), " ="],
    Texts = [constructor_text(Constructor) || Constructor <- Constructors],
    OneLine = [Head, " ", lists:join(" | ", Texts)],
    case iolist_size(OneLine) > 100 of
        false -> OneLine;
        true -> [Head, "\n    ", lists:join("\n  | ", Texts)]
    end.

params_text([]) -> "";
params_text(Params) -> ["(", lists:join(", ", [atom_to_list(Param) || Param <- Params]), ")"].

constructor_text(#constructor{name = Name, fields = none}) ->
    atom_to_list(Name);
constructor_text(#constructor{name = Name, fields = {positional, Annotation}}) ->
    [atom_to_list(Name), "(", syntax_text(Annotation), ")"];
constructor_text(#constructor{name = Name, fields = {named, Fields}}) ->
    [atom_to_list(Name), "(",
     lists:join(", ",
                [[atom_to_list(Field), " : ", syntax_text(Annotation)]
                 || #field{name = Field, annotation = Annotation} <- Fields]),
     ")"].

%% A syntactic type as written.
syntax_text(#t_named{path = Path, name = Name, args = []}) -> qualified_name_text(Path ++ [Name]);
syntax_text(#t_named{path = Path, name = Name, args = Args}) ->
    [qualified_name_text(Path ++ [Name]), "(", lists:join(", ", [syntax_text(Arg) || Arg <- Args]),
     ")"];
syntax_text(#t_var{name = Name}) -> atom_to_list(Name);
syntax_text(#t_tuple{elements = Elements}) ->
    ["#(", lists:join(", ", [syntax_text(Element) || Element <- Elements]), ")"];
syntax_text(#t_fn{params = Params, result_type = Result, effect = Effect}) ->
    ["(", lists:join(", ", [syntax_text(Param) || Param <- Params]), ") -> ", syntax_text(Result),
     case Effect of undefined -> ""; _ -> [" with ", syntax_text(Effect)] end].

%% The name as the program writes it.
shown_name(undefined, Name) -> Name;
shown_name(Owner, Name) -> list_to_atom(atom_to_list(Owner) ++ "." ++ atom_to_list(Name)).

qualified_name_text(Parts) ->
    lists:flatten(lists:join(".", [atom_to_list(Part) || Part <- Parts])).
