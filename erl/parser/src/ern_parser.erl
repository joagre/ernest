%% Parser for Ernest, report Appendix A. Recursive descent over the token
%% list from ern_lexer, threading {Node, Rest}; a precedence-climbing
%% loop for binary operators, and right recursion for `::` in patterns.
%% First-token dispatch; the bounded lookaheads the paragraph after
%% Appendix A's grammar decides; no backtracking. Errors are thrown and
%% returned as {error, #diagnostic{}}.
%% Every node's span runs from its first token to the end of the token
%% before the rest, set by spanned/1.
-module(ern_parser).

-export([parse/1, parse_string/1, parse_expr/1, parse_statement/1, parse_type/1]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("utils/include/ern_diagnostic.hrl").

-define(DECLARATION_START, [export, type, abstract, fn, 'let', foreign]).
-define(SPECS, [bytes, int, float, utf8, utf16, utf32, big, little, signed, unsigned]).

-spec parse([ern_lexer:token()]) -> {ok, [tuple()]} | {error, ern_diagnostic:diagnostic()}.
parse(Tokens) ->
    try
        {ModuleDoc, Tokens1} = module_doc(Tokens),
        Declarations = program(prune_docs(Tokens1), undefined, []),
        {ok, case ModuleDoc of undefined -> Declarations; _ -> [ModuleDoc | Declarations] end}
    catch
        throw:{parse_error, #diagnostic{} = Diagnostic} ->
            {error, incomplete_at_end(Tokens, Diagnostic)}
    end.

%% Report §11.2: the parser stopped at the end of the input, so more input
%% could finish it and the shell takes another line. The parser is the one
%% that knows; no other reader of a diagnostic looks at the flag.
incomplete_at_end(Tokens, #diagnostic{span = Span} = Diagnostic) ->
    case lists:last(Tokens) of
        {eof, Position} ->
            case ern_diagnostic:span(Position) of
                Span -> Diagnostic#diagnostic{incomplete = true};
                _ -> Diagnostic
            end;
        _ -> Diagnostic
    end.

-spec parse_string(unicode:chardata()) -> {ok, [tuple()]} | {error, ern_diagnostic:diagnostic()}.
parse_string(Text) ->
    case ern_lexer:tokenize(Text) of
        {ok, Tokens} -> parse(Tokens);
        {error, _} = Error -> Error
    end.

%% One expression, for tests and the shell.
-spec parse_expr(unicode:chardata()) -> {ok, tuple()} | {error, ern_diagnostic:diagnostic()}.
parse_expr(Text) ->
    parse_one(Text, fun(Tokens) -> expr(prune_docs(Tokens)) end).

%% One statement of a block, for the shell: report §11.2, a `let` at the
%% prompt is a block `let`.
-spec parse_statement(unicode:chardata()) -> {ok, tuple()} | {error, ern_diagnostic:diagnostic()}.
parse_statement(Text) ->
    parse_one(Text, fun(Tokens) -> statement(prune_docs(Tokens)) end).

%% One type, for the prelude tables and tests.
-spec parse_type(unicode:chardata()) -> {ok, tuple()} | {error, ern_diagnostic:diagnostic()}.
parse_type(Text) ->
    parse_one(Text, fun type/1).

%% What Parse reads from the whole of Text, which must end there.
parse_one(Text, Parse) ->
    case ern_lexer:tokenize(Text) of
        {ok, Tokens} ->
            try
                case Parse(Tokens) of
                    {Node, [{eof, _}]} -> {ok, Node};
                    {_, [Token | _]} ->
                        fail(position(Token),
                             "expected end of input instead of " ++ describe(Token))
                end
            catch
                throw:{parse_error, #diagnostic{} = Diagnostic} ->
                    {error, incomplete_at_end(Tokens, Diagnostic)}
            end;
        {error, _} = Error ->
            Error
    end.

%% Report §2.2: a doc block before the first declaration, with a blank line
%% after it, is the module's documentation.
module_doc([{doc, Position, Text}, Next | Rest]) ->
    case line(Next) > doc_end(Position, Text) + 1 of
        true -> {#module_doc{span = ern_diagnostic:span(Position), text = Text}, [Next | Rest]};
        false -> {undefined, [{doc, Position, Text}, Next | Rest]}
    end;
module_doc(Tokens) ->
    {undefined, Tokens}.

doc_end({Line, _, _, _}, Text) ->
    Line + length([Char || <<Char>> <= Text, Char =:= $\n]).

%% A doc token stands only where report §2.2 attaches it: on the line
%% before a top-level declaration, or, inside a type declaration, before a
%% constructor or a field; anywhere else it documents nothing and is an
%% error. InType is true inside a type or abstract type declaration, where
%% no expression can occur. Depth counts the open brackets, so that only a
%% declaration keyword outside every bracket is top-level, or ends a type.
prune_docs(Tokens) ->
    prune_docs(Tokens, false, 0).

prune_docs([{doc, Position, Text} = DocToken, Next | Rest], InType, Depth) ->
    Adjacent = line(Next) =:= doc_end(Position, Text) + 1,
    Attached = Adjacent andalso
               ((Depth =:= 0 andalso is_declaration_start(Next, Rest))
                orelse (InType andalso lists:member(symbol(Next), [typename, ident, '|']))),
    case Attached of
        true ->
            [DocToken | prune_docs([Next | Rest], InType, Depth)];
        false ->
            fail(Position, "a doc block documents nothing here",
                 "a doc block stands directly above a top-level declaration, a constructor"
                 " or a named field; a comment is written `//`")
    end;
prune_docs([Token | Rest], InType, Depth) ->
    {InType1, Depth1} =
        case symbol(Token) of
            type -> {true, Depth};
            Symbol when Symbol =:= '('; Symbol =:= '#('; Symbol =:= '{' -> {InType, Depth + 1};
            Symbol when Symbol =:= ')'; Symbol =:= '}' -> {InType, Depth - 1};
            Symbol when Depth =:= 0 ->
                {InType andalso not lists:member(Symbol, ?DECLARATION_START), Depth};
            _ -> {InType, Depth}
        end,
    [Token | prune_docs(Rest, InType1, Depth1)];
prune_docs([], _, _) ->
    [].

%% `fn` before a bracket opens a lambda, not a declaration.
is_declaration_start({fn, _}, [{'(', _} | _]) -> false;
is_declaration_start(Token, _) -> lists:member(symbol(Token), ?DECLARATION_START).

%%
%% Program and declarations
%%

program([{eof, _}], _Previous, Acc) ->
    lists:reverse(Acc);
program(Tokens, Previous, Acc) ->
    {Declaration, Tokens1} = declaration(Tokens),
    refuse_second_clause(Declaration, Previous),
    program(Tokens1, Declaration, [Declaration | Acc]).

%% A second consecutive fn with the same name is the Haskell habit.
refuse_second_clause(#fn_declaration{span = Span, member_of = MemberOf, name = Name},
                     #fn_declaration{span = FirstSpan, member_of = MemberOf, name = Name}) ->
    %% report §11.5: at the second clause, the first labelled
    Diagnostic = diagnostic(Span, "a function has one clause",
                            "write one clause whose body is a `match`"),
    throw({parse_error, Diagnostic#diagnostic{labels = [{FirstSpan, "first clause"}]}});
refuse_second_clause(_, _) ->
    ok.

declaration(Tokens) ->
    {Doc, Tokens1} = doc(Tokens),
    {Export, Tokens2} = case Tokens1 of
                            [{export, _} | Rest] -> {true, Rest};
                            _ -> {false, Tokens1}
                        end,
    case Tokens2 of
        [{type, _} | _] -> type_declaration(Tokens2, Doc, Export);
        [{abstract, _} | _] -> abstract_declaration(Tokens2, Doc, Export);
        [{fn, _} | _] -> fn_declaration(Tokens2, Doc, Export);
        [{'let', _} | _] -> let_declaration(Tokens2, Doc, Export);
        [{foreign, _} | _] -> foreign_declaration(Tokens2, Doc, Export);
        [Token | _] ->
            wanted(declaration, position(Token),
                   "expected a declaration (type, abstract, fn, let, foreign) instead of "
                   ++ describe(Token))
    end.

doc([{doc, _, Text} | Rest]) -> {Text, Rest};
doc(Tokens) -> {undefined, Tokens}.

type_declaration([{type, Position} | Rest], Doc, Export) ->
    {Name, Rest1} = expect_typename(Rest),
    {Params, Rest2} = optional_typevars(Rest1),
    Rest3 = expect(Rest2, '='),
    {Constructors, Rest4} = constructors(Rest3),
    {Derives, Rest5} = optional_derives(Rest4),
    spanned({#type_declaration{span = Position, doc = Doc, export = Export, name = Name,
                               params = Params, constructors = Constructors, derives = Derives},
             Rest5}).

%% Report §3.5, Appendix A's TypeDecl: `derives compare` after the
%% constructors, its span kept for the errors of the member it derives.
optional_derives([{derives, {Line, Column, _, PreviousEnd}}, {ident, {_, _, End, _}, compare}
                  | Rest]) ->
    {ern_diagnostic:span({Line, Column, End, PreviousEnd}), Rest};
optional_derives([{derives, _}, Token | _]) ->
    fail(position(Token), "`derives` names compare and nothing else, not " ++ describe(Token));
optional_derives(Tokens) ->
    {undefined, Tokens}.

optional_typevars([{'(', _} | Rest]) ->
    {Vars, Rest1} = separated(Rest, ',', fun expect_ident/1),
    {Vars, expect(Rest1, ')')};
optional_typevars(Tokens) ->
    {[], Tokens}.

%% Report §2.2: a doc block before a constructor documents it, on the line
%% above the constructor or above the `|` that leads it.
constructors(Tokens) ->
    {Constructor, Rest} = constructor(Tokens),
    constructors_rest(Rest, [Constructor]).

constructors_rest([{doc, _, Text}, {'|', _} | Rest], Acc) ->
    {Constructor, Rest1} = constructor(Rest, Text),
    constructors_rest(Rest1, [Constructor | Acc]);
constructors_rest([{'|', _} | Rest], Acc) ->
    {Constructor, Rest1} = constructor(Rest),
    constructors_rest(Rest1, [Constructor | Acc]);
constructors_rest(Rest, Acc) ->
    {lists:reverse(Acc), Rest}.

constructor(Tokens) ->
    {Doc, Tokens1} = doc(Tokens),
    constructor(Tokens1, Doc).

constructor(Tokens, Doc) ->
    {Name, Position, Rest} = expect_typename_position(Tokens),
    Named = case Rest of
                [{'(', _}, {ident, _, _}, {':', _} | _] -> true;
                [{'(', _}, {doc, _, _}, {ident, _, _}, {':', _} | _] -> true;
                _ -> false
            end,
    case Rest of
        [{'(', _} | Rest1] when Named ->
            {Fields, Rest2} = separated(Rest1, ',', fun field/1),
            spanned({#constructor{span = Position, doc = Doc, name = Name,
                                  fields = {named, Fields}},
                     expect(Rest2, ')')});
        [{'(', _} | Rest1] ->
            {Type, Rest2} = type(Rest1),
            spanned({#constructor{span = Position, doc = Doc, name = Name,
                                  fields = {positional, Type}},
                     expect(Rest2, ')')});
        _ ->
            spanned({#constructor{span = Position, doc = Doc, name = Name}, Rest})
    end.

field(Tokens) ->
    {Doc, Tokens1} = doc(Tokens),
    {Name, Position, Rest} = expect_ident_position(Tokens1),
    {Type, Rest1} = type(expect(Rest, ':')),
    spanned({#field{span = Position, doc = Doc, name = Name, annotation = Type}, Rest1}).

abstract_declaration([{abstract, Position} | Rest], Doc, Export) ->
    {TypeDeclaration, Rest1} = case Rest of
                                   [{type, _} | _] -> type_declaration(Rest, undefined, false);
                                   [Token | _] -> fail(position(Token),
                                                       "expected `type` after `abstract`")
                               end,
    case Rest1 of
        [{with, WithPosition} | _] ->
            %% report §4.4: the module is an abstract type's boundary, so
            %% there is no list of the definitions that may see inside it
            fail(WithPosition, "an abstract type has no signature: every definition of its module"
                               " may use its constructors, so leave out `with { ... }`");
        _ ->
            spanned({#abstract_declaration{span = Position, doc = Doc, export = Export,
                                           declaration = TypeDeclaration}, Rest1})
    end.

fn_declaration([{fn, Position} | Rest], Doc, Export) ->
    {MemberOf, Name, Rest1} = declaration_name(Rest),
    {Params, Rest2} = params(Rest1),
    {ResultType, Effect, Rest3} = optional_result_type(Rest2),
    {Requirement, Rest4} = optional_requirement(Rest3),
    {Body, Rest5} = expr(expect(Rest4, '=')),
    Declaration = #fn_declaration{span = Position, doc = Doc, export = Export,
                                  member_of = MemberOf, name = Name, params = Params,
                                  result_type = ResultType, effect = Effect,
                                  requirement = Requirement, body = Body},
    spanned({members_named(Declaration), Rest5}).

%% Report §4.9, Appendix A's Requirement: `needs` and the members it names,
%% after the result type.
optional_requirement([{needs, _} | Rest]) ->
    separated(Rest, ',', fun member/1);
optional_requirement(Tokens) ->
    {[], Tokens}.

%% Appendix A's Member: a type variable, `.`, and compare, negate, an
%% operator or show (report §4.9, §4.8, E.1).
member([{ident, Position, Variable}, {'.', _}, {Operator, _} | Rest])
  when Operator =:= '+'; Operator =:= '-'; Operator =:= '*';
       Operator =:= '/'; Operator =:= '%'; Operator =:= '<>' ->
    spanned({#member{span = Position, member_of = Variable, name = Operator}, Rest});
member([{ident, Position, Variable}, {'.', _}, {ident, _, Name} | Rest]) ->
    lists:member(Name, [compare, negate, show])
        orelse fail(Position, atom_to_list(Name) ++ " is not a member: a requirement names"
                                  " compare, negate, an operator or show (§4.8, E.1)"),
    spanned({#member{span = Position, member_of = Variable, name = Name}, Rest});
member([{ident, _, _}, {'.', _}, Token | _]) ->
    fail(position(Token), "expected compare, negate, an operator or show after `.` instead of "
                          ++ describe(Token));
member([{ident, _, Variable}, Token | _]) ->
    fail(position(Token), "expected `.` after " ++ atom_to_list(Variable) ++ " instead of "
                          ++ describe(Token),
         "a requirement names a member of a type variable, as needs a.compare");
member([Token | _]) ->
    fail(position(Token), "expected a type variable instead of " ++ describe(Token),
         "a requirement names a member of a type variable, as needs a.compare").

%% Appendix A, report §3.5, §4.9: in a declaration with a requirement,
%% `a.compare` and `a.negate`, where `a` is a type variable of its
%% signature, name the members of a's type and select nothing; the
%% declaration binds no name that is one of its type variables, so the two
%% readings never meet.
members_named(#fn_declaration{requirement = []} = Declaration) ->
    Declaration;
members_named(#fn_declaration{params = Params, result_type = ResultType, effect = Effect,
                              body = Body} = Declaration) ->
    Variables = lists:usort(signature_variables([ResultType, Effect]
                                                ++ [Annotation
                                                    || #param{annotation = Annotation} <- Params])),
    lists:foreach(fun(#param{pattern = Pattern}) -> no_binding_named(Pattern, Variables) end,
                  Params),
    Declaration#fn_declaration{body = named_members(Body, Variables)}.

%% The type variables a signature's annotations name.
signature_variables(#t_var{name = Name}) -> [Name];
signature_variables(Node) when is_tuple(Node) -> signature_variables(tuple_to_list(Node));
signature_variables(Nodes) when is_list(Nodes) -> lists:append([signature_variables(Node)
                                                               || Node <- Nodes]);
signature_variables(_) -> [].

%% The body with each selection of a member from a type variable named
%% Variables made that member, and every binding checked against them.
named_members(#e_selection{span = Span, expr = #e_var{path = [], name = Name},
                           field = Field} = Selection, Variables)
  when Field =:= compare; Field =:= negate ->
    case lists:member(Name, Variables) of
        true -> #e_member{span = Span, member_of = Name, name = Field};
        false -> Selection
    end;
named_members(#e_lambda{params = Params} = Lambda, Variables) ->
    lists:foreach(fun(#param{pattern = Pattern}) -> no_binding_named(Pattern, Variables) end,
                  Params),
    list_to_tuple([named_members(Child, Variables) || Child <- tuple_to_list(Lambda)]);
named_members(#binding{pattern = Pattern} = Binding, Variables) ->
    no_binding_named(Pattern, Variables),
    list_to_tuple([named_members(Child, Variables) || Child <- tuple_to_list(Binding)]);
named_members(#clause{pattern = Pattern} = Clause, Variables) ->
    no_binding_named(Pattern, Variables),
    list_to_tuple([named_members(Child, Variables) || Child <- tuple_to_list(Clause)]);
named_members(#fn_declaration{span = Span, name = Name, params = Params} = Local, Variables) ->
    lists:member(Name, Variables) andalso binding_named(Span, Name),
    lists:foreach(fun(#param{pattern = Pattern}) -> no_binding_named(Pattern, Variables) end,
                  Params),
    list_to_tuple([named_members(Child, Variables) || Child <- tuple_to_list(Local)]);
named_members(Node, Variables) when is_tuple(Node), is_atom(element(1, Node)) ->
    list_to_tuple([element(1, Node) | [named_members(Child, Variables)
                                       || Child <- tl(tuple_to_list(Node))]]);
named_members(Nodes, Variables) when is_list(Nodes) ->
    [named_members(Node, Variables) || Node <- Nodes];
named_members(Leaf, _) ->
    Leaf.

no_binding_named(Pattern, Variables) ->
    lists:foreach(fun({Name, _}) ->
                      case lists:member(Name, Variables) of
                          true -> binding_named(pattern_span(Pattern, Name), Name);
                          false -> ok
                      end
                  end, ern_ast:pattern_bindings(Pattern)).

%% Where a pattern binds Name, for the error.
pattern_span(Pattern, Name) ->
    ern_ast:walk(fun(#p_var{span = Span, name = Bound}, _) when Bound =:= Name -> Span;
                    (#p_as{name_span = Span, name = Bound}, _) when Bound =:= Name -> Span;
                    (_, Found) -> Found
                 end, Pattern, ern_ast:span(Pattern)).

-spec binding_named(ern_diagnostic:span(), atom()) -> no_return().
binding_named(Span, Name) ->
    Text = atom_to_list(Name),
    fail(Span, "`" ++ Text ++ "` names a type variable of the signature, and a declaration with a"
               " requirement binds no name that is one of its type variables",
         "rename the binding; " ++ Text ++ ".compare names the member of " ++ Text ++ "'s type").

%% Report §4.5, Appendix A's DeclName: a member, declared with `fn`, is an
%% operator, `compare` or `negate`, what the language resolves by the
%% operand's type; a type's other operations are functions of its module.
declaration_name([{ident, _, Name} | Rest]) ->
    {undefined, Name, Rest};
declaration_name([{typename, _, MemberOf}, {'.', _}, {ident, Position, Name} | Rest]) ->
    lists:member(Name, [compare, negate])
        orelse fail(Position, "`" ++ atom_to_list(Name) ++ "` cannot be a member of "
                              ++ atom_to_list(MemberOf) ++ ": a member is an operator, `compare` or"
                              " `negate`",
                    "a type's other operations are functions of its module:"
                    " write `fn " ++ atom_to_list(Name) ++ "`"),
    {MemberOf, Name, Rest};
declaration_name([{typename, _, MemberOf}, {'.', _}, {Operator, _} | Rest])
  when Operator =:= '+'; Operator =:= '-'; Operator =:= '*';
       Operator =:= '/'; Operator =:= '%'; Operator =:= '<>' ->
    {MemberOf, Operator, Rest};
declaration_name([{typename, _, _}, {'.', _}, Token | _]) ->
    fail(position(Token), "expected an operator, `compare` or `negate` after `.` instead of "
                          ++ describe(Token));
declaration_name([{typename, _, _} = Token | _]) ->
    fail(position(Token), "expected a name instead of " ++ describe(Token),
         "a function's name begins with a lowercase letter");
declaration_name([Token | _]) ->
    fail(position(Token), "expected a name instead of " ++ describe(Token)).

%% Report §4.5, §4.6, Appendix A's LetDecl: a `let` declares no member.
let_name([{ident, _, Name} | Rest]) ->
    {Name, Rest};
let_name([{typename, Position, MemberOf}, {'.', _}, {ident, _, Name} | _])
  when Name =/= compare, Name =/= negate ->
    fail(Position, "a `let` declares no member of " ++ atom_to_list(MemberOf),
         "a type's values are named in its module, as its functions are:"
         " write `let " ++ atom_to_list(Name) ++ "`");
let_name([{typename, Position, MemberOf}, {'.', _} | _] = Tokens) ->
    {_, Member, _} = declaration_name(Tokens),
    fail(Position, "a `let` declares no member of " ++ atom_to_list(MemberOf),
         "a member is declared with `fn`: write `fn " ++ atom_to_list(MemberOf) ++ "."
         ++ atom_to_list(Member) ++ "(...)`");
let_name([{typename, _, _} = Token | _]) ->
    fail(position(Token), "expected a name instead of " ++ describe(Token),
         "a value's name begins with a lowercase letter");
let_name([Token | _]) ->
    fail(position(Token), "expected a name instead of " ++ describe(Token)).

params(Tokens) ->
    Rest = expect(Tokens, '('),
    case Rest of
        [{')', _} | Rest1] -> {[], Rest1};
        _ ->
            {Params, Rest1} = separated(Rest, ',', fun param/1),
            {Params, expect(Rest1, ')')}
    end.

param(Tokens) ->
    {Pattern, Rest} = pattern(Tokens),
    case Rest of
        [{':', _} | Rest1] ->
            {Type, Rest2} = type(Rest1),
            spanned({#param{span = ern_ast:span(Pattern), pattern = Pattern, annotation = Type},
                     Rest2});
        _ ->
            spanned({#param{span = ern_ast:span(Pattern), pattern = Pattern}, Rest})
    end.

%% Report §4.5, Appendix A's Return: a result annotation is written `: T`,
%% as a parameter's is; `->` after the parameters is an earlier version's
%% spelling, refused with the one that replaces it (§11).
optional_result_type([{'->', Position} | _]) ->
    fail(Position, "a function's result is annotated with `:`, not `->`",
         "write `: T` after the parameters, as a parameter's type is written");
optional_result_type([{':', _} | Rest]) ->
    {Type, Rest1} = type(Rest),
    case Rest1 of
        [{with, _} | Rest2] ->
            {Effect, Rest3} = type(Rest2),
            {Type, Effect, Rest3};
        _ ->
            {Type, undefined, Rest1}
    end;
optional_result_type(Tokens) ->
    {undefined, undefined, Tokens}.

let_declaration([{'let', Position} | Rest], Doc, Export) ->
    {Name, Rest1} = let_name(Rest),
    {Annotation, Rest2} = case Rest1 of
                              [{':', _} | AfterColon] -> type(AfterColon);
                              _ -> {undefined, Rest1}
                          end,
    Rest3 = case Rest2 of
                [{'<-', ArrowPosition} | _] -> fail(ArrowPosition, "`<-` is a block form",
                                                    "a top-level `let` uses `=`");
                _ -> expect(Rest2, '=')
            end,
    {Body, Rest4} = expr(Rest3),
    spanned({#let_declaration{span = Position, doc = Doc, export = Export, name = Name,
                              annotation = Annotation, body = Body},
             Rest4}).

foreign_declaration([{foreign, Position}, {type, _} | Rest], Doc, Export) ->
    {Name, Rest1} = expect_typename(Rest),
    {Vars, Rest2} = case Rest1 of
                        [{'(', _} | AfterParen] ->
                            {ForeignVars, AfterVars} =
                                separated(AfterParen, ',', fun foreign_var/1),
                            {ForeignVars, expect(AfterVars, ')')};
                        _ -> {[], Rest1}
                    end,
    spanned({#foreign_type_declaration{span = Position, doc = Doc, export = Export, name = Name,
                                       params = [Var || {Var, _} <- Vars],
                                       equality = [Var || {Var, true} <- Vars]},
             Rest2});
foreign_declaration([{foreign, Position}, {fn, _} | Rest], Doc, Export) ->
    {MemberOf, Name, Rest1} = declaration_name(Rest),
    Rest2 = expect(Rest1, '('),
    {Params, Rest3} = case Rest2 of
                          [{')', _} | _] -> {[], Rest2};
                          _ -> separated(Rest2, ',', fun foreign_param/1)
                      end,
    Rest4 = expect(Rest3, ')'),
    {ResultType, Effect, Rest5} = case optional_result_type(Rest4) of
                                      {undefined, _, _} ->
                                          fail(position(hd(Rest4)),
                                               "a foreign function declares its result type");
                                      Annotated -> Annotated
                                  end,
    Rest6 = expect(Rest5, '='),
    case Rest6 of
        [{string, ImplementationPosition, Implementation} | Rest7] ->
            spanned({#foreign_fn_declaration{span = Position, doc = Doc, export = Export,
                                             member_of = MemberOf, name = Name, params = Params,
                                             result_type = ResultType, effect = Effect,
                                             implementation = Implementation,
                                             implementation_span =
                                                 ern_diagnostic:span(ImplementationPosition)},
                     Rest7});
        [Token | _] ->
            fail(position(Token), "expected the implementation name as a string instead of "
                                  ++ describe(Token))
    end;
foreign_declaration([{foreign, _}, Token | _], _Doc, _Export) ->
    fail(position(Token), "expected `type` or `fn` after `foreign` instead of " ++ describe(Token)).

%% Report §4.7, Appendix A: ForeignVar = typevar [ "=" ].
foreign_var(Tokens) ->
    {Name, Rest} = expect_ident(Tokens),
    case Rest of
        [{'=', _} | Rest1] -> {{Name, true}, Rest1};
        _ -> {{Name, false}, Rest}
    end.

foreign_param(Tokens) ->
    {Name, Position, Rest} = expect_ident_position(Tokens),
    {Variable, _} = spanned({#p_var{span = Position, name = Name}, Rest}),
    {Type, Rest1} = type(expect(Rest, ':')),
    spanned({#param{span = Position, pattern = Variable, annotation = Type}, Rest1}).

%%
%% Types
%%

type([{'(', Position} | Rest]) ->
    {Types, Rest1} = case Rest of
                         [{')', _} | _] -> {[], Rest};
                         _ -> separated(Rest, ',', fun type/1)
                     end,
    parenthesized(Position, Types, expect(Rest1, ')'));
type([{'#(', Position} | Rest]) ->
    {Elements, Rest1} = components(Position, separated(Rest, ',', fun type/1)),
    spanned({#t_tuple{span = Position, elements = Elements}, expect(Rest1, ')')});
type([{typename, Position, _} | _] = Tokens) ->
    case qualified(Tokens) of
        {{con, Path, Name}, [{'(', _} | Rest]} ->
            {Args, Rest1} = separated(Rest, ',', fun type/1),
            spanned({#t_named{span = Position, path = Path, name = Name, args = Args},
                     expect(Rest1, ')')});
        {{con, Path, Name}, Rest} ->
            spanned({#t_named{span = Position, path = Path, name = Name}, Rest});
        {{value, _, _}, Rest} ->
            %% report §11.5: over the whole name, with how an argument is
            %% written, which is true whether the name was meant as a type's
            %% argument, `List.a`, or is a value's, `Io.println`
            fail(span_through(Position, Tokens, Rest),
                 "expected a type name; a qualified type ends in an uppercase name",
                 "a type's arguments are written in parentheses, as List(a), and a lowercase"
                 " name after `.` names a value")
    end;
type([{ident, Position, Name} | Rest]) ->
    spanned({#t_var{span = Position, name = Name}, Rest});
type([Token | _]) ->
    wanted(typename, position(Token), "expected a type instead of " ++ describe(Token)).

%% Appendix A's FnType and ParenType: the types in parentheses are a
%% function type's parameters where `->` follows them, else the one type
%% they hold.
parenthesized(Position, Params, [{'->', _} | Rest]) ->
    {ResultType, Rest1} = type(Rest),
    case Rest1 of
        [{with, _} | Rest2] ->
            {Effect, Rest3} = type(Rest2),
            spanned({#t_fn{span = Position, params = Params, result_type = ResultType,
                           effect = Effect}, Rest3});
        _ ->
            spanned({#t_fn{span = Position, params = Params, result_type = ResultType}, Rest1})
    end;
parenthesized(_, [Type], Rest) ->
    spanned({Type, Rest});
parenthesized(Position, [], Rest) ->
    %% report §11.2: at the input's end a further line may hold the `->`
    Diagnostic = diagnostic(Position, "expected a type inside the parentheses, or `->` after them",
                            "the type whose one value is written () is Unit"),
    throw({parse_error, Diagnostic#diagnostic{incomplete = is_at_end(Rest)}});
parenthesized(_, _, [Token | _]) ->
    fail(position(Token), "expected `->` after a parameter list instead of " ++ describe(Token),
         "a tuple type is written with `#(`, as #(Int, Int)").

%% {typename "."} followed by a final segment. Returns {con, Path, Name} for
%% an uppercase final, {value, Path, Name} for an ident or userop final.
qualified([{typename, _, First} | Rest]) ->
    qualified(Rest, [], First).

qualified([{'.', _}, {typename, _, Next} | Rest], Path, Current) ->
    qualified(Rest, Path ++ [Current], Next);
qualified([{'.', _}, {ident, _, Name} | Rest], Path, Current) ->
    {{value, Path ++ [Current], Name}, Rest};
qualified([{'.', _}, {Operator, _} | Rest], Path, Current)
  when Operator =:= '+'; Operator =:= '-'; Operator =:= '*';
       Operator =:= '/'; Operator =:= '%'; Operator =:= '<>' ->
    {{value, Path ++ [Current], Operator}, Rest};
qualified([{'.', _}, Token | _], _Path, _Current) ->
    fail(position(Token), "expected a name after `.` instead of " ++ describe(Token));
qualified(Rest, Path, Current) ->
    {{con, Path, Current}, Rest}.

%%
%% Expressions
%%

expr(Tokens) ->
    {Expr, Rest} = case Tokens of
                       [{fn, Position} | AfterKeyword] -> lambda(AfterKeyword, Position);
                       [{'if', Position} | AfterKeyword] -> if_expr(AfterKeyword, Position);
                       _ -> binexpr(Tokens, 0)
                   end,
    refuse_juxtaposition(Rest),
    {Expr, Rest}.

%% `f x` where `f(x)` was meant: an operand directly after an expression.
refuse_juxtaposition([Token | _]) ->
    case lists:member(symbol(Token), [ident, typename, int, float, char, string, bool]) of
        true ->
            fail(position(Token), "unexpected " ++ describe(Token) ++ " after an expression",
                 "a call is written f(x), and statements are separated by `;`");
        false ->
            ok
    end.

lambda(Tokens, Position) ->
    {Params, Rest1} = params(Tokens),
    {ResultType, Effect, Rest2} = optional_result_type(Rest1),
    case Rest2 of
        [{needs, NeedsPosition} | _] ->
            %% report §4.9: a requirement is a `fn` declaration's
            fail(NeedsPosition, "a lambda declares no requirement",
                 "declare a `fn` with the requirement and pass it");
        _ -> ok
    end,
    {Body, Rest3} = expr(expect(Rest2, '=')),
    spanned({#e_lambda{span = Position, params = Params, result_type = ResultType, effect = Effect,
                       body = Body}, Rest3}).

if_expr(Tokens, Position) ->
    {Condition, Rest1} = expr(Tokens),
    {Then, Rest2} = expr(expect(Rest1, then)),
    case Rest2 of
        [{'else', _} | Rest3] ->
            {Else, Rest4} = expr(Rest3),
            spanned({#e_if{span = Position, condition = Condition, then_branch = Then,
                           else_branch = Else}, Rest4});
        [Next | _] ->
            %% report §11.5: at the `if`, which the next line need not show;
            %% report §11.2: where the input ended there, a further line may
            %% hold the `else`, and the shell takes it
            Diagnostic = diagnostic(Position, "`if` needs an `else`",
                                    "every `if` is an expression; give the"
                                    " other branch a value"),
            throw({parse_error, Diagnostic#diagnostic{incomplete = is_at_end([Next])}})
    end.

match_expr(Tokens, Position) ->
    {Scrutinee, Rest1} = expr(Tokens),
    Rest2 = expect(Rest1, '{'),
    {Clauses, Rest3} = separated(Rest2, '|', fun clause/1),
    spanned({#e_match{span = Position, scrutinee = Scrutinee, clauses = Clauses},
             expect(Rest3, '}')}).

receive_expr(Tokens, Position) ->
    Rest = expect(Tokens, '{'),
    {Clauses, After, Rest1} = receive_clauses(Rest, []),
    spanned({#e_receive{span = Position, clauses = Clauses, 'after' = After}, expect(Rest1, '}')}).

receive_clauses([{'after', Position} | Rest], Acc) ->
    {Timeout, Rest1} = expr(Rest),
    {Body, Rest2} = expr(expect(Rest1, '->')),
    {After, _} = spanned({#after_clause{span = Position, timeout = Timeout, body = Body}, Rest2}),
    {lists:reverse(Acc), After, Rest2};
receive_clauses(Tokens, Acc) ->
    {Clause, Rest} = clause(Tokens),
    case Rest of
        [{'|', _} | Rest1] -> receive_clauses(Rest1, [Clause | Acc]);
        _ -> {lists:reverse([Clause | Acc]), undefined, Rest}
    end.

%% Report §5.9: a clause lists one or more patterns separated by `or`.
clause(Tokens) ->
    {Alternatives, Rest} = separated(Tokens, 'or', fun pattern/1),
    {Pattern, _} = case Alternatives of
                       [Single] -> {Single, Rest};
                       [First | _] -> spanned({#p_or{span = ern_ast:span(First),
                                                     alternatives = Alternatives}, Rest})
                   end,
    {Guard, Rest1} = case Rest of
                         [{'when', _} | AfterWhen] -> expr(AfterWhen);
                         _ -> {undefined, Rest}
                     end,
    {Body, Rest2} = expr(expect(Rest1, '->')),
    spanned({#clause{span = ern_ast:span(Pattern), pattern = Pattern, guard = Guard, body = Body},
             Rest2}).

%% Precedence climbing. Higher binds tighter; report §2.6 numbers the levels
%% the other way round.
binexpr(Tokens, Min) ->
    {Left, Rest} = unary(Tokens),
    binexpr_loop(Left, Rest, Min).

binexpr_loop(Left, [{Operator, Position} | Rest] = Tokens, Min) ->
    case precedence(Operator) of
        {Precedence, Associativity} when Precedence >= Min ->
            NextMin = case Associativity of left -> Precedence + 1; right -> Precedence end,
            {Right, Rest1} = binexpr(Rest, NextMin),
            %% report §5.7: parentheses change nothing, so a parenthesized
            %% call is a call the pipe fills, as an unparenthesized one is
            Combined = combine(Operator, from_left_operand(Left, Position), Left, Right),
            {Node, _} = spanned({Combined, Rest1}),
            binexpr_loop(Node, Rest1, Min);
        _ ->
            {Left, Tokens}
    end;
binexpr_loop(Left, Tokens, _Min) ->
    {Left, Tokens}.

precedence('*') -> {7, left};
precedence('/') -> {7, left};
precedence('%') -> {7, left};
precedence('+') -> {6, left};
precedence('-') -> {6, left};
precedence('<>') -> {6, left};
precedence('::') -> {5, right};
precedence('==') -> {4, left};
precedence('!=') -> {4, left};
precedence('<') -> {4, left};
precedence('<=') -> {4, left};
precedence('>') -> {4, left};
precedence('>=') -> {4, left};
precedence('&&') -> {3, left};
precedence('||') -> {2, left};
precedence('|>') -> {1, left};
precedence(_) -> none.

%% `x |> f(a)` is `f(x, a)`; `x |> f` is `f(x)`; either call is marked as
%% a pipe's, since `x` is evaluated before the callee (report §5.1).
combine('|>', Position, Piped, #e_call{callee = Callee, args = Args}) ->
    #e_call{span = Position, callee = Callee, args = [Piped | Args], pipe = true};
combine('|>', Position, Piped, Callee) ->
    #e_call{span = Position, callee = Callee, args = [Piped], pipe = true};
combine(Operator, Position, Left, Right) ->
    #e_binop{span = Position, operator = Operator, left = Left, right = Right}.

%% An operator expression spans from its left operand (report §11.5).
from_left_operand(Left, {_, _, End, PreviousEnd}) ->
    {Line, Column, _} = ern_diagnostic:span(ern_ast:span(Left)),
    {Line, Column, End, PreviousEnd}.

unary([{'-', Position} | Rest]) ->
    {Expr, Rest1} = postfix(Rest),
    spanned({#e_negation{span = Position, expr = Expr}, Rest1});
unary([{'!', Position} | Rest]) ->
    %% report §4.8: prefix negation on Bool
    {Expr, Rest1} = postfix(Rest),
    spanned({#e_not{span = Position, expr = Expr}, Rest1});
unary(Tokens) ->
    postfix(Tokens).

postfix(Tokens) ->
    {Primary, Rest} = primary(Tokens),
    calls(Primary, Rest).

calls(Callee, [{'(', _} | Rest]) ->
    {Args, Rest1} = case Rest of
                        [{')', _} | _] -> {[], Rest};
                        _ -> arguments(Callee, Rest, 0)
                    end,
    Closed = inside(Callee, max(0, length(Args) - 1), fun() -> expect(Rest1, ')') end),
    {Call, Rest2} = spanned({#e_call{span = ern_ast:span(Callee), callee = Callee, args = Args},
                             Closed}),
    calls(Call, Rest2);
calls(Expr, [{'.', _}, {ident, FieldPosition, Field} | Rest]) ->
    %% report §3.5: a field selected from the value before it
    Unspanned = #e_selection{span = ern_ast:span(Expr), expr = Expr, field = Field,
                             field_span = ern_diagnostic:span(FieldPosition)},
    {Selection, Rest1} = spanned({Unspanned, Rest}),
    calls(Selection, Rest1);
calls(Expr, Tokens) ->
    {Expr, Tokens}.

%% A call's arguments, each parsed as the argument it is, so that an input
%% that stops inside one says which.
arguments(Callee, Tokens, Index) ->
    {Argument, Rest} = inside(Callee, Index, fun() -> expr(Tokens) end),
    case Rest of
        [{',', _} | Rest1] ->
            {Arguments, Rest2} = arguments(Callee, Rest1, Index + 1),
            {[Argument | Arguments], Rest2};
        _ ->
            {[Argument], Rest}
    end.

%% Report §11.2: the call an unfinished input stops inside, its callee and
%% the argument at the cursor, for `Shift-Tab`; a callee that is not a name
%% names nothing.
inside(#e_var{path = Path, name = Name}, Index, Parse) ->
    within(Path, Name, Index, Parse);
inside(_, _, Parse) ->
    Parse().

%% What Parse reads, an error in it marked as stopping within Name's
%% Argument. The innermost call or constructor is the first to catch the
%% error, so it is the one that names itself.
within(Path, Name, Argument, Parse) ->
    try Parse()
    catch throw:{parse_error, #diagnostic{within = undefined} = Diagnostic} ->
        Enclosing = #enclosing{path = Path, name = Name, argument = Argument},
        throw({parse_error, Diagnostic#diagnostic{within = Enclosing}})
    end.

primary([{Kind, Position, Value} | Rest]) when Kind =:= int; Kind =:= float; Kind =:= char;
                                               Kind =:= string; Kind =:= bool ->
    spanned({#e_literal{span = Position, kind = Kind, value = Value}, Rest});
primary([{ident, Position, Name}, {'.', _}, {Operator, _} | Rest])
  when Operator =:= '+'; Operator =:= '-'; Operator =:= '*';
       Operator =:= '/'; Operator =:= '%'; Operator =:= '<>' ->
    %% report §4.9, Appendix A: a type variable's member named by an
    %% operator, `a.+`; `a.compare` is a selection until its declaration's
    %% requirement makes it a member (members_named/1)
    spanned({#e_member{span = Position, member_of = Name, name = Operator}, Rest});
primary([{ident, Position, Name} | Rest]) ->
    spanned({#e_var{span = Position, name = Name}, Rest});
primary([{typename, Position, _} | _] = Tokens) ->
    case qualified(Tokens) of
        {{value, Path, Name}, Rest} ->
            spanned({#e_var{span = Position, path = Path, name = Name}, Rest});
        {{con, Path, Name}, Rest} ->
            constructor_expr(Position, Path, Name, Rest)
    end;
primary([{'#(', Position} | Rest]) ->
    {Elements, Rest1} = components(Position, separated(Rest, ',', fun expr/1)),
    spanned({#e_tuple{span = Position, elements = Elements}, expect(Rest1, ')')});
primary([{'[', Position} | Rest]) ->
    {Elements, Rest1} = case Rest of
                            [{']', _} | _] -> {[], Rest};
                            _ -> separated(Rest, ',', fun expr/1)
                        end,
    spanned({#e_list{span = Position, elements = Elements}, expect(Rest1, ']')});
primary([{'<<', Position} | Rest]) ->
    {Segments, Rest1} = bit_segments(Rest, fun expr/1),
    spanned({#e_bitstring{span = Position, segments = Segments}, Rest1});
primary([{'{', Position} | Rest]) ->
    block(Rest, Position);
primary([{match, Position} | Rest]) ->
    %% report §5.9: it ends at its own `}`, as a block does
    match_expr(Rest, Position);
primary([{'receive', Position} | Rest]) ->
    receive_expr(Rest, Position);
primary([{'(', _} | Rest]) ->
    {Expr, Rest1} = expr(Rest),
    spanned({Expr, expect(Rest1, ')')});
primary([{'_', Position} | _]) ->
    fail(Position, "`_` is a pattern, not an expression");
primary([{Keyword, Position} | _]) when Keyword =:= 'if'; Keyword =:= fn ->
    fail(Position, "`" ++ atom_to_list(Keyword) ++ "` is not an operand", "parenthesize it");
primary([Token | _]) ->
    wanted(expression, position(Token), "expected an expression instead of " ++ describe(Token)).

constructor_expr(Position, Path, Name, [{'(', _} | Rest]) ->
    case Rest of
        [{'..', _} | Rest1] ->
            %% report §5.6, Appendix A's Fields: a namespace after `..` may
            %% stand alone, which the checker decides
            {Base, Rest2} = expr(Rest1),
            {FieldSets, Rest3} = case Rest2 of
                                     [{',', _} | Rest4] -> separated(Rest4, ',',
                                                                     field_of(Path, Name, update));
                                     _ -> {[], Rest2}
                                 end,
            spanned({#e_constructor{span = Position, path = Path, name = Name, base = Base,
                                    args = {named, FieldSets}},
                     expect(Rest3, ')')});
        [{ident, _, _}, {'=', _} | _] ->
            {FieldSets, Rest1} = separated(Rest, ',', field_of(Path, Name, construction)),
            spanned({#e_constructor{span = Position, path = Path, name = Name,
                                    args = {named, FieldSets}},
                     expect(Rest1, ')')});
        [{')', ParenPosition} | _] ->
            %% report §11.5: the parser does not know the constructor's
            %% fields, so the help gives both forms
            fail(ParenPosition, "empty parentheses after " ++ atom_to_list(Name),
                 "a constructor without fields is written without parentheses, "
                 ++ atom_to_list(Name) ++ "; one with fields has its fields inside them");
        [{eof, EndPosition} | _] ->
            %% report §11.2: the input ends where the constructor's first
            %% argument would stand, and positional or named is not
            %% decided yet: what may stand here is a value or a field's
            %% name, and only the constructor's type tells which
            Diagnostic = diagnostic(EndPosition, "expected an expression instead of end of input",
                                    undefined),
            Expected = #expected_field{kind = field_or_value, path = Path, constructor_name = Name},
            Enclosing = #enclosing{path = Path, name = Name, argument = none},
            throw({parse_error, Diagnostic#diagnostic{expected = Expected,
                                                      within = Enclosing}});
        _ ->
            {Expr, Rest1} = within(Path, Name, 0, fun() -> expr(Rest) end),
            no_path(Expr, Rest1),
            spanned({#e_constructor{span = Position, path = Path, name = Name,
                                    args = {positional, Expr}},
                     expect(Rest1, ')')})
    end;
constructor_expr(Position, Path, Name, Tokens) ->
    spanned({#e_constructor{span = Position, path = Path, name = Name}, Tokens}).

%% Report §11.2: a field of this constructor, which the tag names, so
%% that completion knows which fields may stand at the cursor; and where
%% the input stops, which field's value it stops in, or `none` where a
%% field's name would stand, for `Shift-Tab`. Report §5.6: in an update the
%% field may be a path, `stats.indexed`, which a construction refuses.
field_of(Path, ConstructorName, Form) ->
    fun(Tokens) ->
        Expected = #expected_field{kind = field, path = Path, constructor_name = ConstructorName},
        ParseFieldName = fun() ->
                             tagging(Expected, fun() -> expect_ident_position(Tokens) end)
                         end,
        {Name, Position, Rest} = within(Path, ConstructorName, none, ParseFieldName),
        {Segments, Rest1} = path_segments(Rest, Form, Expected, [Name]),
        {Expr, Rest2} = within(Path, ConstructorName, {field, Name},
                               fun() -> expr(expect(Rest1, '=')) end),
        spanned({#field_set{span = Position, name = Name, path = Segments, expr = Expr}, Rest2})
    end.

%% The segments of a path after its first, each after a `.`, in an update;
%% completion is told the segments typed so far (report §11.2).
path_segments([{'.', DotPosition} | _], construction, _Expected, _SoFar) ->
    fail(DotPosition, "a path stands in a record update only",
         "write the field's value as a construction, or update a value with `..`");
path_segments([{'.', _} | Rest], update, #expected_field{path = Path,
                                                         constructor_name = Name} = Expected,
              SoFar) ->
    Typed = Expected#expected_field{segments = lists:reverse(SoFar)},
    ParseSegment = fun() -> tagging(Typed, fun() -> expect_ident_position(Rest) end) end,
    {Segment, _, Rest1} = within(Path, Name, none, ParseSegment),
    path_segments(Rest1, update, Expected, [Segment | SoFar]);
path_segments(Tokens, _Form, _Expected, SoFar) ->
    {tl(lists:reverse(SoFar)), Tokens}.

%% Report §5.6: a path written where a construction's one positional
%% field stands, `C(a.b = e)`, is refused as a path, not as a `)` missing.
no_path(#e_selection{span = Span}, [{'=', _} | _]) ->
    fail(Span, "a path stands in a record update only",
         "write the field's value as a construction, or update a value with `..`");
no_path(_, _) ->
    ok.

%%
%% Blocks
%%

block([{'}', Position} | _], _BlockPosition) ->
    fail(Position, "a block needs at least one expression");
block(Tokens, Position) ->
    {Statements, Rest} = statements(Tokens, undefined, []),
    spanned({#e_block{span = Position, statements = Statements}, Rest}).

statements(Tokens, Previous, Acc) ->
    {Statement, Rest} = statement(Tokens),
    refuse_second_clause(Statement, Previous),
    case Rest of
        [{';', SemicolonPosition}, {'}', _} | _] ->
            %% report §11.5: at the `;` the help says to remove
            fail(SemicolonPosition, "a block ends with an expression", "remove the trailing `;`");
        [{';', _} | Rest1] ->
            statements(Rest1, Statement, [Statement | Acc]);
        [{'}', BracePosition} | Rest1] ->
            case Statement of
                #binding{} ->
                    fail(BracePosition, "a block ends with an expression, not a `let`",
                         "add the expression the block is worth after it");
                #fn_declaration{} ->
                    fail(BracePosition, "a block ends with an expression, not a `fn`",
                         "add the expression the block is worth after it");
                _ ->
                    {lists:reverse([Statement | Acc]), Rest1}
            end;
        [Token | _] ->
            fail(position(Token), "expected `;` or `}` instead of " ++ describe(Token))
    end.

statement([{'let', Position} | Rest]) ->
    {Pattern, Rest1} = pattern(Rest),
    {Annotation, Rest2} = case Rest1 of
                              [{':', _} | AfterColon] -> type(AfterColon);
                              _ -> {undefined, Rest1}
                          end,
    {Operator, Rest3} = case Rest2 of
                            [{'=', _} | AfterOperator] -> {'=', AfterOperator};
                            [{'<-', _} | AfterOperator] -> {'<-', AfterOperator};
                            [Token | _] ->
                                fail(position(Token),
                                     "expected `=` or `<-` instead of " ++ describe(Token))
                        end,
    {Expr, Rest4} = expr(Rest3),
    spanned({#binding{span = Position, pattern = Pattern, annotation = Annotation,
                      operator = Operator, expr = Expr}, Rest4});
statement([{fn, _}, {'(', _} | _] = Tokens) ->
    expr(Tokens);
statement([{fn, _} | _] = Tokens) ->
    fn_declaration(Tokens, undefined, false);
statement(Tokens) ->
    expr(Tokens).

%%
%% Patterns
%%

pattern(Tokens) ->
    {Pattern, Rest} = conspat(Tokens),
    case Rest of
        [{as, _}, {ident, NamePosition, Name} | Rest1] ->
            spanned({#p_as{span = ern_ast:span(Pattern), pattern = Pattern, name = Name,
                           name_span = ern_diagnostic:span(NamePosition)}, Rest1});
        [{as, _}, Token | _] ->
            fail(position(Token), "expected a name after `as` instead of " ++ describe(Token));
        _ ->
            {Pattern, Rest}
    end.

conspat(Tokens) ->
    {Head, Rest} = atompat(Tokens),
    case Rest of
        [{'::', Position} | Rest1] ->
            {Tail, Rest2} = conspat(Rest1),
            spanned({#p_cons{span = Position, head = Head, tail = Tail}, Rest2});
        _ ->
            {Head, Rest}
    end.

atompat([{'_', Position} | Rest]) ->
    spanned({#p_wildcard{span = Position}, Rest});
atompat([{ident, Position, Name} | Rest]) ->
    spanned({#p_var{span = Position, name = Name}, Rest});
atompat([{Kind, Position, Value} | Rest]) when Kind =:= int; Kind =:= float; Kind =:= char;
                                               Kind =:= string; Kind =:= bool ->
    spanned({#p_literal{span = Position, kind = Kind, value = Value}, Rest});
atompat([{'-', Position}, {Kind, _, Value} | Rest]) when Kind =:= int; Kind =:= float ->
    spanned({#p_literal{span = Position, kind = Kind, value = negated(Value)}, Rest});
atompat([{'-', _}, Token | _]) ->
    fail(position(Token),
         "expected a number after `-` in a pattern instead of " ++ describe(Token));
atompat([{typename, Position, _} | _] = Tokens) ->
    case qualified(Tokens) of
        {{con, Path, Name}, Rest} -> constructor_pattern(Position, Path, Name, Rest);
        {{value, _, _}, Rest} ->
            fail(span_through(Position, Tokens, Rest),
                 "expected a constructor; a pattern cannot name a function or value")
    end;
atompat([{'#(', Position} | Rest]) ->
    {Elements, Rest1} = components(Position, separated(Rest, ',', fun pattern/1)),
    spanned({#p_tuple{span = Position, elements = Elements}, expect(Rest1, ')')});
atompat([{'[', Position} | Rest]) ->
    {Elements, Rest1} = case Rest of
                            [{']', _} | _] -> {[], Rest};
                            _ -> separated(Rest, ',', fun pattern/1)
                        end,
    spanned({#p_list{span = Position, elements = Elements}, expect(Rest1, ']')});
atompat([{'<<', Position} | Rest]) ->
    {Segments, Rest1} = bit_segments(Rest, fun pattern/1),
    spanned({#p_bitstring{span = Position, segments = Segments}, Rest1});
atompat([Token | _]) ->
    wanted(pattern, position(Token), "expected a pattern instead of " ++ describe(Token)).

constructor_pattern(Position, Path, Name, [{'(', _} | Rest]) ->
    case Rest of
        [{')', _} | Rest1] ->
            spanned({#p_constructor{span = Position, path = Path, name = Name, args = {named, []}},
                     Rest1});
        [{ident, _, _}, {'=', _} | _] ->
            {Fields, Rest1} = separated(Rest, ',', field_pattern_of(Path, Name)),
            spanned({#p_constructor{span = Position, path = Path, name = Name,
                                    args = {named, Fields}},
                     expect(Rest1, ')')});
        [{eof, EndPosition} | _] ->
            %% report §11.2: as in an expression, a field's name or a
            %% pattern may stand here, and the constructor's type tells
            wanted(#expected_field{kind = field_or_pattern, path = Path, constructor_name = Name},
                   EndPosition, "expected a pattern instead of end of input");
        _ ->
            {Pattern, Rest1} = pattern(Rest),
            no_path_pattern(Pattern, Rest1),
            spanned({#p_constructor{span = Position, path = Path, name = Name,
                                    args = {positional, Pattern}},
                     expect(Rest1, ')')})
    end;
constructor_pattern(Position, Path, Name, Tokens) ->
    spanned({#p_constructor{span = Position, path = Path, name = Name}, Tokens}).

%% Report §5.6: a path written where a constructor pattern's one
%% positional field stands, `C(a.b = p)`, is refused as a path.
no_path_pattern(#p_var{}, [{'.', DotPosition} | _]) ->
    fail(DotPosition, "a path stands in a record update only, not in a pattern",
         "match the field with a constructor pattern of its own");
no_path_pattern(_, _) ->
    ok.

%% Report §11.2: a field of this constructor in a pattern, tagged as in
%% an expression, so that completion knows which fields may stand there.
field_pattern_of(Path, ConstructorName) ->
    fun(Tokens) ->
        Expected = #expected_field{kind = field, path = Path, constructor_name = ConstructorName},
        {Name, Position, Rest} = tagging(Expected, fun() -> expect_ident_position(Tokens) end),
        case Rest of
            [{'.', DotPosition} | _] ->
                %% report §5.6: a path updates, and a pattern takes apart
                fail(DotPosition, "a path stands in a record update only, not in a pattern",
                     "match the field with a constructor pattern of its own");
            _ ->
                ok
        end,
        {Pattern, Rest1} = pattern(expect(Rest, '=')),
        spanned({#field_pattern{span = Position, name = Name, pattern = Pattern}, Rest1})
    end.

%%
%% Bitstrings. Value is parsed by Parse (an expression or a pattern).
%%

bit_segments([{'>>', _} | Rest], _Parse) ->
    {[], Rest};
bit_segments(Tokens, Parse) ->
    {Segments, Rest} = separated(Tokens, ',',
                                 fun(SegmentTokens) -> bit_segment(SegmentTokens, Parse) end),
    {Segments, expect(Rest, '>>')}.

bit_segment(Tokens, Parse) ->
    {Value, Rest} = Parse(Tokens),
    case Rest of
        [{':', _} | Rest1] ->
            {Specs, Rest2} = separated(Rest1, '-', fun bit_spec/1),
            spanned({#bit_segment{span = ern_ast:span(Value), value = Value, specs = Specs},
                     Rest2});
        _ ->
            spanned({#bit_segment{span = ern_ast:span(Value), value = Value}, Rest})
    end.

bit_spec([{ident, _, size}, {'(', _} | Rest]) ->
    {Expr, Rest1} = expr(Rest),
    {{size, Expr}, expect(Rest1, ')')};
bit_spec([{ident, Position, unit} | _]) ->
    %% report §5.11: a size counts bits, and octets for `bytes`, so no
    %% specifier scales it
    fail(Position, "there is no `unit` specifier",
         "a size counts bits, and octets for `bytes`: write `size(n * 8)`");
bit_spec([{ident, Position, Name} | Rest]) ->
    case lists:member(Name, ?SPECS) of
        true -> {Name, Rest};
        false -> fail(Position, "unknown bitstring specifier `" ++ atom_to_list(Name) ++ "`")
    end;
bit_spec([Token | _]) ->
    fail(position(Token), "expected a bitstring specifier instead of " ++ describe(Token)).

%%
%% Token helpers
%%

%% One or more of what Parse reads, separated by Separator.
separated(Tokens, Separator, Parse) ->
    {Item, Rest} = Parse(Tokens),
    case Rest of
        [{Separator, _} | Rest1] ->
            {Items, Rest2} = separated(Rest1, Separator, Parse),
            {[Item | Items], Rest2};
        _ ->
            {[Item], Rest}
    end.

expect([{Symbol, _} | Rest], Symbol) ->
    Rest;
expect([{'<-', _} = Token | _], Symbol) ->
    %% report §2.6, §11.5: max-munch makes `a<-1` a binding arrow, which a
    %% comparison with a negative number was meant as
    fail(position(Token),
         "expected `" ++ atom_to_list(Symbol) ++ "` instead of " ++ describe(Token),
         "`<-` is one token; write `a < -1` to compare with a negative number");
expect([Token | _], Symbol) ->
    fail(position(Token),
         "expected `" ++ atom_to_list(Symbol) ++ "` instead of " ++ describe(Token)).

expect_ident(Tokens) ->
    {Name, _, Rest} = expect_ident_position(Tokens),
    {Name, Rest}.

expect_ident_position([{ident, Position, Name} | Rest]) ->
    {Name, Position, Rest};
expect_ident_position([Token | _]) ->
    fail(position(Token), "expected a name instead of " ++ describe(Token)).

expect_typename(Tokens) ->
    {Name, _, Rest} = expect_typename_position(Tokens),
    {Name, Rest}.

expect_typename_position([{typename, Position, Name} | Rest]) -> {Name, Position, Rest};
expect_typename_position([{ident, IdentPosition, Name} = Token | _]) ->
    Help = case meant_typename(atom_to_list(Name)) of
               none -> "a type name begins with an uppercase letter";
               Typename -> "a type name begins with an uppercase letter: " ++ Typename
           end,
    Diagnostic = diagnostic(IdentPosition, "expected a type name instead of " ++ describe(Token),
                            Help),
    throw({parse_error, Diagnostic#diagnostic{expected = typename}});
expect_typename_position([Token | _]) ->
    wanted(typename, position(Token), "expected a type name instead of " ++ describe(Token)).

%% The type name an identifier was meant as, its leading `_` gone and its
%% first letter uppercase, or none where no letter begins what is left.
meant_typename(Identifier) ->
    case lists:dropwhile(fun(Char) -> Char =:= $_ end, Identifier) of
        [First | Rest] when First >= $a, First =< $z -> [First - $a + $A | Rest];
        _ -> none
    end.

%% A token is {Symbol, Position} or {Symbol, Position, Value}, as the
%% lexer gives it.
symbol(Token) -> element(1, Token).
position(Token) -> element(2, Token).

line(Token) ->
    {Line, _, _, _} = position(Token),
    Line.

%% Report §11.5: the span from Position to the end of the last token
%% Tokens gave before Rest, so an error covers a qualified name whole.
span_through({Line, Column, _, PreviousEnd}, Tokens, Rest) ->
    {_, _, End, _} = position(lists:nth(length(Tokens) - length(Rest), Tokens)),
    {Line, Column, End, PreviousEnd}.

%% Report §11.5: a node's span, from the node's first token to the end of
%% the token before the rest, which every token carries.
spanned({Node, [Next | _] = Rest}) ->
    {Line, Column, _} = ern_diagnostic:span(ern_ast:span(Node)),
    {_, _, _, End} = position(Next),
    {setelement(2, Node, {Line, Column, End}), Rest};
spanned({Node, []}) ->
    {setelement(2, Node, ern_diagnostic:span(ern_ast:span(Node))), []}.

describe({ident, _, Name}) -> "identifier `" ++ atom_to_list(Name) ++ "`";
describe({typename, _, Name}) -> "type name `" ++ atom_to_list(Name) ++ "`";
describe({int, _, Value}) -> "integer " ++ integer_to_list(Value);
describe({float, _, Value}) -> "float " ++ float_to_list(Value, [short]);
describe({char, _, _}) -> "char literal";
describe({string, _, _}) -> "string literal";
describe({bool, _, Value}) -> "`" ++ atom_to_list(Value) ++ "`";
describe({doc, _, _}) -> "doc comment";
describe({eof, _}) -> "end of input";
describe({Symbol, _}) -> "`" ++ atom_to_list(Symbol) ++ "`".

%% Report §3.2: a tuple has two components or more, as a type, a value
%% and a pattern alike.
components(Position, {[_], _}) ->
    fail(Position, "a tuple has two components or more",
         "write the component itself, or add another");
components(_, Parsed) ->
    Parsed.

-spec fail(ern_diagnostic:position(), iodata()) -> no_return().
fail(Position, Message) ->
    fail(Position, Message, undefined).

%% Report §11.2: what the parser wanted here, for the shell's
%% completion, which asks what may stand at the cursor. Only the
%% categories completion acts on are marked; every other failure leaves
%% the field alone.
-spec wanted(term(), ern_diagnostic:position(), iodata()) -> no_return().
wanted(What, Position, Message) ->
    throw({parse_error, (diagnostic(Position, Message, undefined))#diagnostic{expected = What}}).

%% What a failure inside this call wanted, where the caller knows it and
%% the failing code does not: a field name belongs to its constructor.
tagging(What, Parse) ->
    try Parse()
    catch throw:{parse_error, #diagnostic{expected = undefined} = Diagnostic} ->
        throw({parse_error, Diagnostic#diagnostic{expected = What}})
    end.

%% Report §11.5: the message states the rule, the help line the fix.
-spec fail(ern_diagnostic:position(), iodata(), string() | undefined) -> no_return().
fail(Position, Message, Help) ->
    throw({parse_error, diagnostic(Position, Message, Help)}).

%% Report §3.1: a negated literal, and no negative zero, so `-0.0` is the
%% zero.
negated(Number) when Number == 0 -> Number;
negated(Number) -> -Number.

%% Whether what is left is the input's end, where a further line may finish
%% what the parser was reading (report §11.2).
is_at_end([{eof, _} | _]) -> true;
is_at_end(_) -> false.

diagnostic(Position, Message, Help) ->
    #diagnostic{span = ern_diagnostic:span(Position), message = lists:flatten(Message),
                help = Help}.
