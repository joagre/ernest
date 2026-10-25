%% Report §11.1, §11.4, EEP 48: the documentation chunk "Docs" of a compiled
%% module, which `ern doc`, the shell's `:doc` and the host's own tools
%% read: how it is built from a checked module, and how it is read back.
-module(ern_docs).

-export([chunk_name/0, read/1, build/4, member_form/4]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("checker/include/ern_types.hrl").

-spec chunk_name() -> binary().
chunk_name() ->
    <<"Docs">>.

%% A compiled module's documentation. A chunk of another format, from
%% another version of the compiler, reads as an error, and so does a module
%% without the chunk.
-spec read(binary() | file:filename()) -> {ok, tuple()} | {error, string()}.
read(Beam) ->
    case beam_lib:chunks(Beam, [binary_to_list(chunk_name())]) of
        {ok, {_, [{_, Chunk}]}} ->
            %% data alone, since a `.erc` may come from anywhere (ern_chunk)
            case ern_chunk:term(Chunk) of
                {ok, {docs_v1, _, ernest, _, _, _, _} = Docs} -> {ok, Docs};
                _ -> {error, "the documentation chunk is of another compiler version"}
            end;
        %% the host's text of the error quotes the bytes it was given
        {error, beam_lib, _} ->
            {error, "the module has no documentation chunk"}
    end.

%% Report §11.1, EEP 48: the module's documentation, read by `ern doc`
%% (§11.4) and by the host's own tools. One entry per declaration §11.4
%% renders, in source order: its signature as the page shows it, a
%% member's its form (member_form/4), its doc block verbatim, and, for a
%% type, its constructors and their fields in the metadata, an abstract
%% type's marked private, for a function its parameters' names, and for a
%% member its type's name and its own, so a reader of the chunk needs no
%% markdown. SourceName is the source file's name.
-spec build([atom()], [tuple()], ern_typecheck:env(), binary()) -> tuple().
build(Namespace, Declarations, Env, SourceName) ->
    ModuleDoc = case [Text || #module_doc{text = Text} <- Declarations] of
                    [Text | _] -> #{<<"en">> => Text};
                    [] -> none
                end,
    {docs_v1, erl_anno:new(0), ernest, <<"text/markdown">>, ModuleDoc, #{source => SourceName},
     [doc_entry(Declaration, Namespace, Env)
      || Declaration <- Declarations, documented(Declaration)]}.

doc_entry(Declaration, Namespace, Env) ->
    {Line, _, _} = ern_diagnostic:span(ern_ast:span(Declaration)),
    Member = member(Declaration, Namespace),
    {doc_key(Declaration), erl_anno:new(Line),
     doc_signature(Declaration, Member, ern_namespace:text(Namespace) ++ ".", Env),
     case doc_of(Declaration) of
         undefined -> none;
         Doc -> #{<<"en">> => Doc}
     end,
     case doc_exported(Declaration) of
         true -> doc_meta(Declaration, Member);
         false -> (doc_meta(Declaration, Member))#{private => true}
     end}.

%% Report §4.5, §11.4: the type a declaration of the module Namespace is a
%% member of, and the member, `{'Point', compare}` for `fn Point.compare`;
%% in a prelude type's module, which declares that type's members
%% unprefixed, `Int`'s `+` or `List`'s `compare`, that type; none for any
%% other declaration.
member(#fn_declaration{member_of = MemberOf, name = Name}, Namespace) ->
    member(MemberOf, Name, Namespace);
member(#foreign_fn_declaration{member_of = MemberOf, name = Name}, Namespace) ->
    member(MemberOf, Name, Namespace);
member(_, _) ->
    none.

member(undefined, Name, [Type]) ->
    case lists:member(Name, [compare, negate | ?USEROPS])
         andalso lists:member(Type, ern_prelude:member_types()) of
        true -> {Type, Name};
        false -> none
    end;
member(undefined, _, _) ->
    none;
member(MemberOf, Name, _) ->
    {MemberOf, Name}.

%% A type declaration is a type entry; everything else is a function entry,
%% under its Ernest name, a member's its type's and its own joined by `.`,
%% and the arity of its unit's function, a requirement's members after its
%% parameters (report §4.9). The unit names its functions by their
%% position (§11.1); the documentation names them as the program does. The names the
%% host gives every module, `module_info` and `record_info`, get a `$`, as
%% no Ernest name can spell, so that the host's own documentation tools,
%% which read the chunk, do not take one for the host's function.
doc_key(#type_declaration{name = Name, params = Params}) -> {type, Name, length(Params)};
doc_key(#abstract_declaration{declaration = #type_declaration{name = Name, params = Params}}) ->
    {type, Name, length(Params)};
doc_key(#foreign_type_declaration{name = Name, params = Params}) -> {type, Name, length(Params)};
doc_key(#fn_declaration{member_of = MemberOf, name = Name, params = Params,
                        requirement = Requirement}) ->
    {function, function_name(MemberOf, Name), length(Params) + length(Requirement)};
doc_key(#foreign_fn_declaration{member_of = MemberOf, name = Name, params = Params,
                                scheme = #scheme{requirement = Requirement}}) ->
    {function, function_name(MemberOf, Name), length(Params) + length(Requirement)};
doc_key(#let_declaration{name = Name}) ->
    {function, function_name(undefined, Name), 0}.

function_name(undefined, Name) -> function_atom(Name);
function_name(MemberOf, Name) -> list_to_atom(atom_to_list(MemberOf) ++ "." ++ atom_to_list(Name)).

function_atom(module_info) -> 'module_info$';
function_atom(record_info) -> 'record_info$';
function_atom(Name) -> Name.

doc_signature(#fn_declaration{params = Params, scheme = Scheme}, {_, Member}, _, Env) ->
    member_signature(Member, Params, Scheme, Env);
doc_signature(#foreign_fn_declaration{params = Params, scheme = Scheme}, {_, Member}, _, Env) ->
    member_signature(Member, Params, Scheme, Env);
doc_signature(Declaration, none, Prefix, Env) ->
    [unicode:characters_to_binary(Line)
     || Line <- string:split(signature(Declaration, Prefix, Env), "\n", all)].

member_signature(Member, Params, Scheme, Env) ->
    {_, Form} = member_form(Member, param_names(Params), Scheme, ern_typecheck:type_state(Env)),
    [unicode:characters_to_binary(Form)].

%% Report §11.4: a member's form, as a program writes it at its type, from
%% its scheme and its parameters' names, `_` for a pattern: the member
%% applied to the names, then its result type and its requirement,
%% `compare(left, right) : Ordering needs a.compare`, `left + right : Int`,
%% `-int : Int`; and its type as its first parameter has it, `Stack(a)`,
%% which `:browse` names its members under (§11.2). The types are printed
%% under TypeState, each part of the scheme on its own, its variables named
%% as the declaration names them.
-spec member_form(atom(), [atom()], #scheme{}, ern_types:type_state()) -> {string(), string()}.
member_form(Member, Params, #scheme{type = {tfn, [First | _], _, Result}} = Scheme, TypeState) ->
    Type = ern_types:format_scheme(Scheme#scheme{type = First, requirement = []}, TypeState),
    Applied = case {Member, [atom_to_list(Param) || Param <- Params]} of
                  {compare, [Left, Right]} -> ["compare(", Left, ", ", Right, ")"];
                  {negate, [Operand]} -> ["-", Operand];
                  {Operator, [Left, Right]} -> [Left, " ", atom_to_list(Operator), " ", Right]
              end,
    {Type, lists:flatten([Applied, " : ", ern_types:format_scheme(Scheme#scheme{type = Result},
                                                                  TypeState)])}.

%% The parameter list as the module writes it, for the shell's completion,
%% and a type's documented parts, for a reader that renders them itself;
%% `private` marks a declaration the module does not export (report §11.4),
%% and the constructors of an abstract type, which its module keeps
%% (§4.4), whose doc blocks `ern test` runs the examples of (§11.2) and a
%% page leaves out.
doc_meta(#fn_declaration{params = Params}, Member) -> member_meta(param_names(Params), Member);
doc_meta(#foreign_fn_declaration{params = Params}, Member) ->
    member_meta(param_names(Params), Member);
doc_meta(#type_declaration{constructors = Constructors}, none) ->
    #{items => [constructor_item(Constructor) || Constructor <- Constructors]};
doc_meta(#abstract_declaration{declaration = #type_declaration{constructors = Constructors}},
         none) ->
    #{items => [(constructor_item(Constructor))#{private => true}
                || Constructor <- Constructors]};
doc_meta(_, none) -> #{}.

%% A function's parameters' names, and a member's type and name, which a
%% page orders the members by (report §11.4).
member_meta(Names, none) -> #{params => Names};
member_meta(Names, {Type, Member}) ->
    #{params => Names, member => #{type => Type, name => Member}}.

%% A parameter's name as written; one that is not a plain variable shows
%% as `_`, since the shell completes names and has no source to quote.
param_names(Params) ->
    [case Pattern of #p_var{name = Name} -> Name; _ -> '_' end
     || #param{pattern = Pattern} <- Params].

constructor_item(#constructor{doc = Doc, name = Name, fields = Fields}) ->
    #{kind => constructor, name => Name, doc => doc_or_none(Doc),
      fields => [#{name => FieldName, type => text(syntax_text(Annotation)),
                   doc => doc_or_none(FieldDoc)}
                 || #field{doc = FieldDoc, name = FieldName,
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

%% The declaration as its page shows it (report §11.4): a function's head,
%% each parameter named beside its type, and a `let`'s type, from their
%% schemes, with the restrictions and the requirement every printed type
%% shows (§11.5, §9.4); the declaration itself for the type forms, an
%% abstract type without its representation.
signature(#fn_declaration{member_of = MemberOf, name = Name, params = Params, scheme = Scheme},
          Prefix, Env) ->
    head(Prefix, shown_name(MemberOf, Name), Params, Scheme, Env);
signature(#let_declaration{name = Name, scheme = Scheme}, Prefix, Env) ->
    text([Prefix, atom_to_list(Name), " : ",
          ern_types:format_scheme(Scheme, ern_typecheck:type_state(Env))]);
signature(#foreign_fn_declaration{member_of = MemberOf, name = Name, params = Params,
                                  scheme = Scheme}, Prefix, Env) ->
    head(Prefix, shown_name(MemberOf, Name), Params, Scheme, Env);
signature(#type_declaration{} = Declaration, _, _) ->
    text(type_text(Declaration));
signature(#abstract_declaration{declaration = #type_declaration{name = TypeName, params = Params}},
          _, _) ->
    text(["abstract type ", atom_to_list(TypeName), params_text(Params)]);
signature(#foreign_type_declaration{name = Name, params = Params, equality = Equality}, _, _) ->
    %% report §4.7: a parameter that requires equality is written `k=`
    text(["foreign type ", atom_to_list(Name),
          params_text([case Written of
                           true -> list_to_atom(atom_to_list(Param) ++ "=");
                           false -> Param
                       end || {Param, Written} <- lists:zip(Params, Equality)])]).

%% Report §11.4: a function's head, `List.take(list : List(a!), count : Int)
%% : List(a!)`, as `Shift-Tab` prints a signature, its parameters named.
head(Prefix, Name, Params, Scheme, Env) ->
    Names = param_names(Params),
    {Head, Marked, Rest} = ern_types:format_call(Scheme, Names, length(Names),
                                                 ern_typecheck:type_state(Env)),
    text([Prefix, atom_to_list(Name), Head, Marked, Rest]).

%% Report §11.4, §11.6: the declaration whole, `derives compare` among it,
%% as `ern format` lays it out.
type_text(#type_declaration{name = Name, params = Params, constructors = Constructors,
                            derives = Derives}) ->
    Source = ["type ", atom_to_list(Name), params_text(Params), " = ",
              lists:join(" | ", [constructor_text(Constructor) || Constructor <- Constructors]),
              [" derives compare" || Derives =/= undefined]],
    {ok, Laid} = ern_format:format(unicode:characters_to_binary(Source)),
    string:trim(Laid, trailing, "\n").

params_text([]) -> "";
params_text(Params) -> ["(", lists:join(", ", [atom_to_list(Param) || Param <- Params]), ")"].

constructor_text(#constructor{name = Name, fields = none}) ->
    atom_to_list(Name);
constructor_text(#constructor{name = Name, fields = {positional, Annotation}}) ->
    [atom_to_list(Name), "(", syntax_text(Annotation), ")"];
constructor_text(#constructor{name = Name, fields = {named, Fields}}) ->
    [atom_to_list(Name), "(",
     lists:join(", ",
                [[atom_to_list(FieldName), " : ", syntax_text(Annotation)]
                 || #field{name = FieldName, annotation = Annotation} <- Fields]),
     ")"].

%% A syntactic type as written.
syntax_text(#t_named{namespace = Namespace, name = Name, args = []}) ->
    ern_namespace:text(Namespace ++ [Name]);
syntax_text(#t_named{namespace = Namespace, name = Name, args = Args}) ->
    [ern_namespace:text(Namespace ++ [Name]), "(",
     lists:join(", ", [syntax_text(Arg) || Arg <- Args]), ")"];
syntax_text(#t_var{name = Name, equality = false}) -> atom_to_list(Name);
syntax_text(#t_var{name = Name, equality = true}) -> [atom_to_list(Name), "="];
syntax_text(#t_tuple{elements = Elements}) ->
    ["#(", lists:join(", ", [syntax_text(Element) || Element <- Elements]), ")"];
syntax_text(#t_fn{params = Params, result_type = Result, effect = Effect}) ->
    %% report §3.4: a function-typed result under an outer `receiving` keeps
    %% its parentheses, so that the `receiving` is the outer arrow's
    ResultText = case {Result, Effect} of
                     {#t_fn{}, Outer} when Outer =/= undefined -> ["(", syntax_text(Result), ")"];
                     _ -> syntax_text(Result)
                 end,
    ["(", lists:join(", ", [syntax_text(Param) || Param <- Params]), ") -> ", ResultText,
     case Effect of undefined -> ""; _ -> [" receiving ", syntax_text(Effect)] end].

%% The name as the program writes it.
shown_name(undefined, Name) -> Name;
shown_name(MemberOf, Name) -> list_to_atom(atom_to_list(MemberOf) ++ "." ++ atom_to_list(Name)).
