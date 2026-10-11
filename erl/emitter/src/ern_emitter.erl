%% The emitter, the compiler's back end: a unit's Erlang abstract format
%% made from its definitions' canonical forms (report §8.7, §11.1, Appendix
%% H), with what its module's build adds that is no definition's and the
%% link of what the forms reference outside the unit (ern_unit.hrl). It
%% reads no typed tree and no checker's environment: what the code depends
%% on is in the forms, and where they reference another unit, in the link
%% (ern_compile makes both for a build and for the shell's loads). Values
%% follow report §8.4.
%%
%% Report §11.1: a unit's functions are named by their position in it, so
%% that a unit adds one atom to the host, its own name. Its definitions
%% take the positions from 1 in the order of their forms, a type taking its
%% position though it has no function, and its foreign functions those
%% after them, in the order the module declares them: the function at
%% position N is '$N'. The function a local function of the definition at
%% N is lifted to, at its position P among the definition's lambdas and
%% local functions (Appendix H), is '$N.P', and the entry a spawn on a peer
%% starts a lambda or a local function by is '$N.P.entry' (§8.7). A
%% descriptor's function is '$type_K', K counting the unit's descriptors.
%% What the runtime calls on every unit
%% keeps its name: '$init'/0, '$deps'/0, '$tests'/0, '$spawned'/2 and
%% '$code'/0. Each function's Ernest name is in '$code'/0, by which a caller
%% from Erlang and a fault's trace find it (ern_code), and in a comment
%% above it in the code for reading, `--emit-erl` and the golden files.
%%
%% Report §5.1's left-to-right order of a call's arguments, a tuple's and a
%% list's elements and an operator's operands rests on the host compiler's,
%% which evaluates them left to right though Erlang's manual leaves the
%% order open; order_of_evaluation_test pins each form, so a change of the
%% host's order fails `make test`. A long literal's elements, and a
%% bitstring's values and sizes where one is bound, are put in order here.
%%
%% One traversal does the three pre-passes on the way: every local gets a
%% fresh Erlang variable (Ernest shadows, Erlang does not), local fns are
%% lifted to module functions taking the block's free variables first,
%% and `let p <- e` becomes a case (report §5.5).
-module(ern_emitter).

-export([unit/1, source/1, function_name/1]).

-include_lib("typer/include/ern_canonical.hrl").
-include_lib("emitter/include/ern_unit.hrl").

%% The elements past which a list or a tuple literal is built an element at
%% a time, so that the host's limit of values live at a call is never met.
-define(LONG_LITERAL, 256).

%% Emission context, threaded through everything. unit: the #unit{} being
%% made; namespace: the module's; erlang_module: the unit's name; own: the
%% unit's definitions and foreign functions (#own{}); definition: the
%% definition being compiled, {Position, Hash, QualifiedName}; declaration:
%% its Ernest name, [Name] or [MemberOf, Name], which a spawn site names;
%% restrictions: each type variable of the definition its schemes
%% quantify, by its number, with its restrictions, by which a check's
%% cause prints it (§11.5); variables: a local's number => its Erlang
%% variable; counter: the last number a made variable took; locals: a
%% local fn's number => its #local_fn{} (see Blocks); lifted: module
%% functions produced by lifting, reversed; descriptors: descriptor term =>
%% the name of the module function returning it; pattern_guards: Erlang
%% guard forms a pattern needs on its clause, a float segment's zero
%% (report §3.1), taken by the clause that uses them; members: {Number,
%% Member} => the Erlang variable of a member the enclosing declarations'
%% requirements name (report §4.9), each a parameter the program does not
%% write; outer: while a pattern is compiled, the variables in scope where
%% it began, else undefined; let_lambdas: the Erlang variable a `let` binds
%% to a lambda => the lambda and the variables in force at it, which its
%% captures are, for a spawn on a peer that names it (§3.11); entries: each
%% lambda's or local fn's entry a spawn on a peer starts, by its
%% definition's position and its own (§8.7, §11.1); builds_functions:
%% whether the unit builds a function value, a fun of its own code that may
%% be held anywhere (function_value/2), which the shell reads to keep an
%% input (§11.2).
-record(emit_context, {unit, namespace, erlang_module, own, definition, declaration,
                       restrictions = #{}, variables = #{}, counter = 0, locals = #{},
                       lifted = [], descriptors = #{}, pattern_guards = [], members = #{},
                       outer, let_lambdas = #{}, entries = #{}, builds_functions = false}).
%% The unit's own (report §11.1, Appendix H): forms, each definition's
%% position => {its #definition{}, its form prepared (prepared/2)}; hashes,
%% each definition's hash => the position of the first with it, two
%% definitions with one hash being one (§8.7); names, each definition's
%% qualified name, the module's and the form's, => its position; foreign,
%% each foreign function's qualified name as a form writes it => {its
%% position, its #foreign_function{}}.
-record(own, {forms = #{}, hashes = #{}, names = #{}, foreign = #{}}).
%% A spawn on a peer's entry (report §8.7, §11.1): the function's name and
%% arity, the enclosing definition's qualified name, its hash and the
%% position, which the unit's '$code'/0 lists with the reach.
-record(entry, {function, arity, qualified_name, hash, position}).
%% A local fn of a block (see Blocks): lifted_name, the module function's
%% name; captured, the free locals of its body that the enclosing scopes or
%% its block's lets bind; enclosing, the Erlang variables of the enclosing
%% blocks' local fns it references; references, the local fns of its block
%% it references; members, the Erlang variables of the enclosing
%% requirements' members its body uses; snapshot, the variables in force
%% at its declaration, once passed. All but references are what it closes
%% over. function: its form, which a spawn on a peer reads (§8.7);
%% position: its position in its definition; source: where it is written.
-record(local_fn, {lifted_name, captured, enclosing, references, members = [],
                   snapshot = pending, function, position, source}).

%%
%% Entry points
%%

%% Report §11.1: the unit's abstract forms, and whether it builds a function
%% value (§11.2). Every rule a program can break has been checked: what the
%% emitter cannot emit, or emits and the host does not compile, is a defect
%% of the toolchain, raised as one, which `ern` reports as its own failure
%% (report §11).
-spec unit(#unit{}) -> {[erl_parse:abstract_form()], boolean()}.
unit(Unit) ->
    {Forms, BuildsFunctions} = syntax(Unit),
    {erl_syntax:revert_forms(Forms), BuildsFunctions}.

%% Report §11.1: the unit as Erlang source, for reading (`--emit-erl`), each
%% function under a comment that names it as the program does.
-spec source(#unit{}) -> unicode:chardata().
source(Unit) ->
    {Forms, _} = syntax(Unit),
    [erl_prettypr:format(erl_syntax:form_list(Forms)), "\n"].

%% Report §11.1: the Erlang name of the function at Position in its unit.
-spec function_name(pos_integer()) -> atom().
function_name(Position) ->
    list_to_atom([$$ | integer_to_list(Position)]).

%% The function a local fn at Position in the definition at Definition is
%% lifted to.
lifted_name(Definition, Position) ->
    list_to_atom([$$ | integer_to_list(Definition)] ++ [$. | integer_to_list(Position)]).

%% The entry a spawn on a peer starts the lambda or the local fn at
%% Position in the definition at Definition by.
entry_name(Definition, Position) ->
    list_to_atom([$$ | integer_to_list(Definition)] ++ [$. | integer_to_list(Position)]
                 ++ ".entry").

syntax(#unit{namespace = Namespace, name = ErlangModule, definitions = Definitions,
             foreign_functions = ForeignFunctions, standard = Standard, code = Code} = Unit) ->
    Placed = lists:enumerate(Definitions),
    ForeignPlaced = lists:enumerate(length(Definitions) + 1, ForeignFunctions),
    Own = own(Placed, ForeignPlaced, Unit),
    Context = #emit_context{unit = Unit, namespace = Namespace, erlang_module = ErlangModule,
                            own = Own},
    {DefinitionFunctions, Context1} = lists:mapfoldl(fun definition_functions/2, Context,
                                                     Placed),
    {ForeignForms, Context2} = lists:mapfoldl(fun foreign_function/2, Context1, ForeignPlaced),
    {InitFunction, Context3} = init_function(Unit, Context2),
    TestsFunction = tests_function(Placed, Context3),
    DependenciesFunction = dependencies_function(Unit),
    Entries = maps:values(Context3#emit_context.entries),
    SpawnedFunction = spawned_function(Placed, ForeignPlaced, Entries, Context3),
    Lifted = lists:reverse(Context3#emit_context.lifted),
    Bodies = lists:append(DefinitionFunctions) ++ ForeignForms ++ InitFunction ++ TestsFunction
        ++ SpawnedFunction ++ Lifted,
    CodeFunction = case Code of
                       true ->
                           Calls = calls(Bodies, ErlangModule, Standard),
                           code_function(code(Placed, ForeignPlaced, Entries, Context3)
                                         ++ [{Namespace, {calls, Calls}}]);
                       false ->
                           []
                   end,
    Exports = exports(Placed, ForeignPlaced, Context3)
        ++ [{'$init', 0} || InitFunction =/= []] ++ [{'$tests', 0} || TestsFunction =/= []]
        ++ [{'$deps', 0} || DependenciesFunction =/= []]
        ++ [{'$spawned', 2} || SpawnedFunction =/= []] ++ [{'$code', 0} || CodeFunction =/= []],
    %% report §3.9: a function whose result is a type variable no parameter
    %% holds never returns, `fault` and `Os.exit` among them, so Dialyzer,
    %% which the release review runs over this code, is told it is meant
    NoReturn = erl_syntax:attribute(erl_syntax:atom(dialyzer), [erl_syntax:atom(no_return)]),
    Attrs = [erl_syntax:attribute(erl_syntax:atom(module), [erl_syntax:atom(ErlangModule)]),
             NoReturn,
             erl_syntax:attribute(erl_syntax:atom(export),
                                  [erl_syntax:list([erl_syntax:arity_qualifier(
                                                      erl_syntax:atom(Function),
                                                      erl_syntax:integer(Arity))
                                                    || {Function, Arity} <- Exports])])],
    Functions = lists:append(DefinitionFunctions) ++ ForeignForms ++ InitFunction ++ TestsFunction
        ++ DependenciesFunction ++ SpawnedFunction ++ CodeFunction ++ Lifted,
    {Attrs ++ Functions, Context3#emit_context.builds_functions}.

%% The unit's own definitions and foreign functions, each definition's form
%% prepared.
own(Placed, ForeignPlaced, #unit{sourced = Sourced} = Unit) ->
    Groups = maps:groups_from_list(fun({_, #definition{group = Group}}) -> group_of(Group) end,
                                   Placed),
    #own{forms = maps:from_list([{Position,
                                  {Definition,
                                   prepared(maps:get(QualifiedName, Sourced, Form),
                                            group_references(Definition, Groups, Unit))}}
                                 || {Position, #definition{qualified_name = QualifiedName,
                                                         form = Form} = Definition}
                                        <- Placed]),
         hashes = lists:foldl(fun({Position, #definition{hash = Hash}}, Acc) ->
                                  maps:merge(#{Hash => Position}, Acc)
                              end, #{}, Placed),
         names = maps:from_list(lists:append([[{QualifiedName, Position},
                                               {form_name(QualifiedName, Unit), Position}]
                                              || {Position, #definition{
                                                             qualified_name = QualifiedName}}
                                                     <- Placed])),
         foreign = maps:from_list([{form_name(QualifiedName, Unit), {Position, ForeignFunction}}
                                   || {Position, #foreign_function{qualified_name = QualifiedName}
                                                   = ForeignFunction} <- ForeignPlaced])}.

%% Report Appendix H: the references a definition's form makes to the
%% members of its own group by position, {in_group, P} => the reference that
%% names that member from outside the group, its hash or, for a binding,
%% its identity; a definition alone is a group of one.
group_references(#definition{group = none} = Definition, _, Unit) ->
    #{{in_group, 1} => reference(Definition, Unit)};
group_references(#definition{group = Group}, Groups, Unit) ->
    maps:from_list([{{in_group, Position}, reference(Member, Unit)}
                    || {_, #definition{group = {_, Position}} = Member}
                           <- maps:get(group_of(Group), Groups)]).

group_of(none) -> none;
group_of({GroupHash, _}) -> GroupHash.

reference(#definition{kind = binding, qualified_name = QualifiedName, hash = Hash}, Unit) ->
    {binding, form_name(QualifiedName, Unit), Hash};
reference(#definition{hash = Hash}, _) ->
    {hash, Hash}.

%% Report §11.2, Appendix H: a qualified name of the module's own, under the
%% namespace its forms write it in.
form_name(QualifiedName, #unit{namespace = Namespace, form_namespace = FormNamespace}) ->
    FormNamespace ++ lists:nthtail(length(Namespace), QualifiedName).

%% A definition's form as the emitter reads it: each reference to a member
%% of its own group by the reference that names that member (Appendix H),
%% and each lambda and local function marked with its position among the
%% definition's, in the order the walk meets them, a local function with
%% the number its block binds it to (marked/2).
prepared(Form, Linking) ->
    Absolute = absolute(Form, Linking),
    {Source, Node} = sourced(Absolute),
    case Node of
        {function, Scheme, Params, Result, Effect, Needs, Body} when is_list(Params) ->
            {[Params1, Body1], _} = lists:mapfoldl(fun marked/2, {0, 0}, [Params, Body]),
            rewrapped(Source, {function, Scheme, Params1, Result, Effect, Needs, Body1});
        _ ->
            element(1, marked(Absolute, {0, 0}))
    end.

absolute({in_group, Position} = Reference, Linking) when is_integer(Position) ->
    maps:get(Reference, Linking);
absolute(Term, Linking) when is_tuple(Term) ->
    list_to_tuple(absolute(tuple_to_list(Term), Linking));
absolute([Head | Tail], Linking) ->
    [absolute(Head, Linking) | absolute(Tail, Linking)];
absolute(Term, _) ->
    Term.

%% Report Appendix H: the walk numbers locals in the order it binds them,
%% a block's local functions as it enters the block, and counts lambdas and
%% local functions in the order it meets them; State is {the highest local
%% number met, the last position given}. A local function becomes
%% {local_fn, Number, Position, Function}, a lambda {lambda, Position, ...}.
marked({'$at', Source, Node}, State) ->
    {Marked, State1} = marked(Node, State),
    {{'$at', Source, Marked}, State1};
marked({block, Statements}, {Locals, Positions}) when is_list(Statements) ->
    Count = length([Statement || Statement <- Statements, is_local_fn(Statement)]),
    {Marked, {_, State}} =
        lists:mapfoldl(fun(Statement, {Next, {Bound, Given} = Acc}) ->
                           case is_local_fn(Statement) of
                               true ->
                                   {Source, Function} = sourced(Statement),
                                   {Inner, Acc1} = marked_parts(Function, {Bound, Given + 1}),
                                   {rewrapped(Source, {local_fn, Next, Given + 1, Inner}),
                                    {Next + 1, Acc1}};
                               false ->
                                   {Inner, Acc1} = marked(Statement, Acc),
                                   {Inner, {Next, Acc1}}
                           end
                       end, {Locals + 1, {Locals + Count, Positions}}, Statements),
    {{block, Marked}, State};
marked({local, Number} = Local, {Locals, Positions}) when is_integer(Number) ->
    {Local, {max(Locals, Number), Positions}};
marked({lambda, Params, Result, Effect, Body}, {Locals, Positions}) when is_list(Params) ->
    {[Params1, Body1], State} = lists:mapfoldl(fun marked/2, {Locals, Positions + 1},
                                               [Params, Body]),
    {{lambda, Positions + 1, Params1, Result, Effect, Body1}, State};
marked(Term, State) when is_tuple(Term) ->
    {Parts, State1} = marked(tuple_to_list(Term), State),
    {list_to_tuple(Parts), State1};
marked(Terms, State) when is_list(Terms) ->
    lists:mapfoldl(fun marked/2, State, Terms);
marked(Term, State) ->
    {Term, State}.

%% A local function's parts walked, the function itself having been given
%% its position.
marked_parts({function, Scheme, Params, Result, Effect, Needs, Body}, State) ->
    {[Params1, Body1], State1} = lists:mapfoldl(fun marked/2, State, [Params, Body]),
    {{function, Scheme, Params1, Result, Effect, Needs, Body1}, State1}.

is_local_fn(Statement) ->
    case sourced(Statement) of
        {_, {function, _, Params, _, _, _, _}} when is_list(Params) -> true;
        _ -> false
    end.

%% A node of a form and where it was written, none where the form holds no
%% source (ern_canonical:source()).
sourced({'$at', Source, Node}) ->
    {_, Unwrapped} = sourced(Node),
    {Source, Unwrapped};
sourced(Node) ->
    {none, Node}.

rewrapped(none, Node) -> Node;
rewrapped(Source, Node) -> {'$at', Source, Node}.

%% The name a node's source gives a local it binds, or none.
local_name({_, _, Name}) -> Name;
local_name(none) -> none.

%% The definition being compiled set in Context.
entering(Position, #definition{qualified_name = QualifiedName, hash = Hash}, Form,
         #emit_context{namespace = Namespace} = Context) ->
    Context#emit_context{definition = {Position, Hash, QualifiedName},
                         declaration = lists:nthtail(length(Namespace), QualifiedName),
                         restrictions = restrictions(Form), variables = #{}, locals = #{},
                         members = #{}, let_lambdas = #{}}.

%% Report §3.9, Appendix H: each type variable a scheme of the form
%% quantifies, by its number, with its restrictions; a foreign function's
%% scheme in a reference is numbered by itself, and is passed over.
restrictions(Form) ->
    maps:from_list(quantified(Form, [])).

quantified({foreign, QualifiedName, _}, Acc) when is_list(QualifiedName) ->
    Acc;
quantified({scheme, Quantified, Type, Requirement}, Acc) when is_list(Quantified) ->
    quantified([Type, Requirement], [{Number, Restrictions} || {Number, Restrictions} <- Quantified]
                                    ++ Acc);
quantified(Term, Acc) when is_tuple(Term) ->
    quantified(tuple_to_list(Term), Acc);
quantified(Terms, Acc) when is_list(Terms) ->
    lists:foldl(fun quantified/2, Acc, Terms);
quantified(_, Acc) ->
    Acc.

%%
%% The unit's functions, report §11.1
%%

%% A definition's function: a function's own, a binding's getter, which
%% '$init'/0 gives its value (§8.5), and a type's none.
definition_functions({_, #definition{kind = type}}, Context) ->
    {[], Context};
definition_functions({Position, #definition{kind = function} = Definition},
                     #emit_context{own = #own{forms = Forms}} = Context) ->
    {_, Form} = maps:get(Position, Forms),
    {Source, {function, _, Params, _, _, Needs, Body}} = sourced(Form),
    Context1 = entering(Position, Definition, Form, Context),
    {Head, Context2} = head_patterns(Params, Needs, Context1),
    {BodyForms, Context3} = body(Body, Context2),
    Clause = at(Source, erl_syntax:clause(Head, none, BodyForms)),
    Function = at(Source, erl_syntax:function(erl_syntax:atom(function_name(Position)), [Clause])),
    {[commented(Function, Definition)],
     Context3#emit_context{variables = #{}, members = #{}}};
definition_functions({Position, #definition{kind = binding} = Definition},
                     #emit_context{own = #own{forms = Forms}} = Context) ->
    {Source, _} = sourced(element(2, maps:get(Position, Forms))),
    Name = function_name(Position),
    Get = call_remote(ern_rt, binding, [key(Context, Name)]),
    Clause = at(Source, erl_syntax:clause([], none, [Get])),
    {[commented(at(Source, erl_syntax:function(erl_syntax:atom(Name), [Clause])), Definition)],
     Context}.

%% A function under a comment that names its definition as the program
%% does, for a reader of the code.
commented(Function, #definition{qualified_name = QualifiedName}) ->
    with_comment(Function, ern_namespace:text(QualifiedName)).

with_comment(Form, Text) ->
    erl_syntax:add_precomments([erl_syntax:comment(["% " ++ Text])], Form).

%% A function's parameters as patterns, then a parameter for each member
%% its requirement names (report §4.9).
head_patterns(Params, Needs, Context) ->
    {Patterns, Context1} = lists:mapfoldl(fun({param, Pattern, _}, Acc) ->
                                              pattern(Pattern, Acc)
                                          end, Context, Params),
    {Members, Context2} = members_taken(Needs, Context1),
    {Patterns ++ Members, Context2}.

%% Report §4.9: the members a requirement names, each a parameter after the
%% written ones, in the order the requirement writes them.
members_taken(Needs, Context) ->
    lists:mapfoldl(fun({needs, {variable, Number}, Member}, Acc) ->
                       {[Erlang], Acc1} = fresh_variables(1, "Member", Acc),
                       Members = Acc1#emit_context.members,
                       {erl_syntax:variable(Erlang),
                        Acc1#emit_context{members = Members#{{Number, Member} => Erlang}}}
                   end, Context, Needs).

%% Report §4.7, §8.4: a foreign function, its implementation called in
%% place, an exception it raises turned into a fault, and its return
%% checked; report §9.4: `Io.show` and `Io.debug` take their requirement's
%% member, the descriptor, after their argument, and pass it to the host.
foreign_function({Position, #foreign_function{qualified_name = QualifiedName,
                                            scheme = {scheme, Quantified,
                                                      {arrow, ParamTypes, Effect, ResultType},
                                                      Requirement},
                                            host_module = HostModule,
                                            host_function = HostFunction,
                                            source = Source}},
                 #emit_context{namespace = Namespace} = Context) ->
    Context1 = Context#emit_context{declaration = lists:nthtail(length(Namespace), QualifiedName),
                                    restrictions = maps:from_list(Quantified)},
    Prefixes = ["Argument" || _ <- ParamTypes] ++ ["Member" || _ <- Requirement],
    {Variables, Context2} = named_variables(Prefixes, Context1),
    {Args, Members} = lists:split(length(ParamTypes),
                                  [erl_syntax:variable(Variable) || Variable <- Variables]),
    {Body, Context3} = foreign_body({HostModule, HostFunction}, {ParamTypes, Effect, ResultType},
                                    Args, Members, Context2),
    Clause = at(Source, erl_syntax:clause(Args ++ Members, none, [Body])),
    Function = at(Source, erl_syntax:function(erl_syntax:atom(function_name(Position)), [Clause])),
    {with_comment(Function, ern_namespace:text(QualifiedName)), Context3}.

%% Report §8.4: a foreign function's body, its arguments exposed to the
%% host, the call, and its return checked.
foreign_body({HostModule, HostFunction}, {ParamTypes, Effect, ResultType}, Args, Members,
             Context) ->
    {Exposed, Context1} = lists:mapfoldl(fun exposed/2, Context, lists:zip(ParamTypes, Args)),
    Call = erl_syntax:application(erl_syntax:atom(HostModule), erl_syntax:atom(HostFunction),
                                  Exposed ++ Members),
    {Try, Context2} = foreign_call(Call, HostModule, HostFunction, length(Exposed ++ Members),
                                   {Effect, ParamTypes}, Context1),
    foreign_return(Try, ParamTypes, ResultType, Context2).

%% Report §4.7, §7.4: the foreign call, an exception it raises turned into
%% a fault. Report §8.6: a foreign call in progress can still deliver, so
%% it is counted while it runs. A standard library function with no
%% mailbox type of its own waits on no process, and is not: one that is
%% pure, and one whose effect is only a function's it is given, which runs
%% as Ernest and is counted as Ernest is, so that a deadlock in it is found
%% (Appendix E.0 rule 1). Nor is one whose implementation its runtime
%% module lists as waiting on no process, read function by function
%% (`ern_rt`'s `-waits_on_nothing`), since the count would cost a multiple
%% of the call.
foreign_call(Call, HostModule, HostFunction, Arity, {Effect, ParamTypes},
             #emit_context{unit = #unit{standard = Standard}} = Context) ->
    Uncounted = Standard
        andalso (waits_on_nothing(Effect, ParamTypes)
                 orelse is_listed_waiting_on_nothing(HostModule, HostFunction, Arity)),
    Counted = case Uncounted of
                  true -> Call;
                  false -> call_remote(ern_rt, in_foreign,
                                       [erl_syntax:fun_expr([erl_syntax:clause([], none, [Call])])])
              end,
    {[Class, Error, Trace], Context1} = named_variables(["Class", "Error", "Trace"], Context),
    Raised = call_remote(ern_boundary, raised,
                         [erl_syntax:atom(HostModule), erl_syntax:atom(HostFunction),
                          erl_syntax:integer(Arity)
                          | [erl_syntax:variable(Variable) || Variable <- [Class, Error, Trace]]]),
    Handler = erl_syntax:clause([erl_syntax:class_qualifier(erl_syntax:variable(Class),
                                                            erl_syntax:variable(Error),
                                                            erl_syntax:variable(Trace))],
                                none, [Raised]),
    {erl_syntax:try_expr([Counted], [Handler]), Context1}.

is_listed_waiting_on_nothing(HostModule, HostFunction, Arity) ->
    case code:ensure_loaded(HostModule) of
        {module, HostModule} ->
            Attributes = HostModule:module_info(attributes),
            lists:member({HostFunction, Arity},
                         lists:append(proplists:get_all_values(waits_on_nothing, Attributes)));
        _ ->
            false
    end.

waits_on_nothing(pure, _ParamTypes) -> true;
waits_on_nothing({variable, _} = Variable, ParamTypes) ->
    lists:member(Variable, type_variables(ParamTypes));
waits_on_nothing(_, _) -> false.

%% Report §8.4: the foreign call's return checked. The standard library's
%% is the runtime's own, and not checked; a type variable of the result
%% that no parameter names stands for no value the function could have
%% been given, so it matches none, and the return faults where it holds
%% one.
foreign_return(Try, _ParamTypes, _ResultType,
               #emit_context{unit = #unit{standard = true}} = Context) ->
    {Try, Context};
foreign_return(Try, ParamTypes, ResultType, Context) ->
    ParamVariables = type_variables(ParamTypes),
    Unnamed = [Variable || Variable <- lists:usort(type_variables(ResultType)),
                           not lists:member(Variable, ParamVariables)],
    check_form(as_never(Unnamed, ResultType), ResultType, Try, "foreign return does not match ",
               Context).

%% A binding's key, under which its value is kept (report §8.5).
key(#emit_context{erlang_module = ErlangModule}, Name) ->
    erl_syntax:tuple([erl_syntax:atom(ErlangModule), erl_syntax:atom(Name)]).

%% '$init'/0 evaluates the top-level lets once, in dependency order, each
%% named as the process's site while it runs, so that its fault is reported
%% under it (report §8.5, §11.2).
init_function(#unit{binding_order = []}, Context) ->
    {[], Context};
init_function(#unit{binding_order = Order}, #emit_context{own = Own} = Context) ->
    {Stores, Context1} =
        lists:mapfoldl(fun(QualifiedName, Acc) ->
                           Position = maps:get(QualifiedName, Own#own.names),
                           {Definition, Form} = maps:get(Position, Own#own.forms),
                           {Source, {binding, _, _, Body}} = sourced(Form),
                           Acc1 = entering(Position, Definition, Form, Acc),
                           Named = call_remote(ern_rt, initializing, [site(Source, Acc1)]),
                           {BodyForm, Acc2} = expr(Body, Acc1),
                           Store = call_remote(persistent_term, put,
                                               [key(Acc, function_name(Position)), BodyForm]),
                           {[Named, Store], Acc2}
                       end, Context, Order),
    Clause = erl_syntax:clause([], none, lists:append(Stores) ++ [erl_syntax:atom(ok)]),
    {[erl_syntax:function(erl_syntax:atom('$init'), [Clause])], Context1}.

%% Report Appendix E.24, §11.2: '$tests'/0 lists the module's tests, every
%% top-level let of type Test.Case(m), exported or not, for `ern test`; the
%% mailbox type is the test process's, and nothing here.
tests_function(Placed, #emit_context{own = #own{forms = Forms}}) ->
    Names = [function_name(Position)
             || {Position, #definition{kind = binding}} <- Placed,
                {_, {binding, {scheme, _, Type, _}, _, _}} <- [sourced(element(2, maps:get(Position,
                                                                                         Forms)))],
                is_test_case(Type)],
    case Names of
        [] -> [];
        _ ->
            %% the list is built a test at a time, from the last, so that no
            %% more than the list so far is live at a call: a list of every
            %% call at once passes the host's limit of live values
            {Matches, List} =
                lists:foldl(fun(Function, {Acc, Tail}) ->
                                Name = list_to_atom("Tests" ++ integer_to_list(length(Acc))),
                                Variable = erl_syntax:variable(Name),
                                Head = erl_syntax:application(erl_syntax:atom(Function), []),
                                Extended = erl_syntax:cons(Head, Tail),
                                Match = erl_syntax:match_expr(Variable, Extended),
                                {[Match | Acc], Variable}
                            end, {[], erl_syntax:nil()}, lists:reverse(Names)),
            [erl_syntax:function(erl_syntax:atom('$tests'),
                                 [erl_syntax:clause([], none, lists:reverse(Matches) ++ [List])])]
    end.

is_test_case({applied, {named, ['Test', 'Case']}, [_]}) -> true;
is_test_case(_) -> false.

%% Report §2.3: a definition whose own name holds `$`, the entry of an input
%% at the shell's prompt, is named by no program.
nameable(QualifiedName) -> not lists:member($$, atom_to_list(lists:last(QualifiedName))).

%% Report §11.1: what the unit exports: the functions of the definitions
%% and the foreign functions the module exports.
exports(Placed, ForeignPlaced, #emit_context{unit = #unit{exported = Exported},
                                                 own = #own{forms = Forms}}) ->
    [{function_name(Position), arity(element(2, maps:get(Position, Forms)))}
     || {Position, #definition{kind = Kind, qualified_name = QualifiedName}} <- Placed,
        Kind =/= type, lists:member(QualifiedName, Exported)]
        ++ [{function_name(Position), foreign_arity(ForeignFunction)}
            || {Position, #foreign_function{export = true} = ForeignFunction} <- ForeignPlaced].

%% The arity of a definition's function: a function's parameters and its
%% requirement's members (report §4.9), and a binding's getter none.
arity(Form) ->
    case sourced(Form) of
        {_, {function, _, Params, _, _, Needs, _}} -> length(Params) + length(Needs);
        {_, {binding, _, _, _}} -> 0
    end.

foreign_arity(#foreign_function{scheme = {scheme, _, {arrow, ParamTypes, _, _}, Requirement}}) ->
    length(ParamTypes) + length(Requirement).

%% Report §8.7: what the unit holds, which the code table reads as the
%% unit loads (ern_code): each definition by its qualified name, with its
%% hash, from its canonical form, and the function that holds it, a
%% function with its reach, or for a binding the key its value is kept
%% under (§8.5); each foreign declaration's implementation and its
%% function, which the canonical forms name by its qualified name alone;
%% each lambda and local fn a spawn on a peer starts, by its identity,
%% with its entry and its reach; and, last, under the module's namespace,
%% the units its code calls (calls/3). Each qualified name is the forms'
%% (Appendix H): an input of a shell's session names what it declares
%% under the session's one namespace, by which a reach finds it. A literal
%% '$code'/0 answers, so that a load reads it without decoding the
%% module's chunks, which costs more than the load.
code(Placed, ForeignPlaced, Entries,
     #emit_context{unit = #unit{reaches = Reaches} = Unit, own = #own{forms = Forms}} = Context) ->
    [definition_code(Position, Definition, element(2, maps:get(Position, Forms)), Context)
     || {Position, Definition} <- Placed]
        ++ [{form_name(QualifiedName, Unit),
             {foreign, HostModule, HostFunction, function_name(Position),
              foreign_arity(ForeignFunction)}}
            || {Position, #foreign_function{qualified_name = QualifiedName,
                                            host_module = HostModule,
                                            host_function = HostFunction} = ForeignFunction}
                   <- ForeignPlaced]
        ++ lists:sort([{form_name(QualifiedName, Unit),
                        {lambda, Hash, Position, Function, Arity,
                         maps:get({QualifiedName, Position}, Reaches)}}
                       || #entry{function = Function, arity = Arity,
                                 qualified_name = QualifiedName, hash = Hash,
                                 position = Position} <- Entries]).

definition_code(Position, #definition{kind = function, qualified_name = QualifiedName, hash = Hash},
                Form, #emit_context{unit = #unit{reaches = Reaches} = Unit}) ->
    {form_name(QualifiedName, Unit),
     {function, Hash, function_name(Position), arity(Form), maps:get(QualifiedName, Reaches)}};
definition_code(Position, #definition{kind = binding, qualified_name = QualifiedName, hash = Hash},
                _, #emit_context{erlang_module = ErlangModule, unit = Unit}) ->
    {form_name(QualifiedName, Unit), {binding, Hash, {ErlangModule, function_name(Position)}}};
definition_code(_, #definition{kind = type, qualified_name = QualifiedName, hash = Hash}, _,
                #emit_context{unit = Unit}) ->
    {form_name(QualifiedName, Unit), {type, Hash}}.

%% Report §8.7: '$spawned'/2 runs, in the calling process, a function of
%% this unit a spawn on a peer may start, over the values it captured:
%% each function and foreign function of no parameter, by its position, and
%% each lambda's or local fn's entry. The peer's runtime calls it with the
%% function its code table holds under the frame's identity, so that a
%% function no other unit may name runs where its identity is held.
spawned_function(Placed, ForeignPlaced, Entries, #emit_context{own = #own{forms = Forms}}) ->
    Clauses = [spawned_clause(function_name(Position), 0)
               || {Position, #definition{kind = function, qualified_name = QualifiedName}}
                      <- Placed,
                  arity(element(2, maps:get(Position, Forms))) =:= 0, nameable(QualifiedName)]
        ++ [spawned_clause(function_name(Position), 0)
            || {Position, #foreign_function{qualified_name = QualifiedName} = ForeignFunction}
                   <- ForeignPlaced,
               foreign_arity(ForeignFunction) =:= 0, nameable(QualifiedName)]
        ++ [spawned_clause(Function, Arity)
            || #entry{function = Function, arity = Arity} <- lists:keysort(#entry.function,
                                                                           Entries)],
    case Clauses of
        [] -> [];
        _ -> [erl_syntax:function(erl_syntax:atom('$spawned'), Clauses)]
    end.

%% '$spawned'(Function, [Capture1, ...]) -> Function(Capture1, ...).
spawned_clause(Function, Arity) ->
    Captures = [erl_syntax:variable(list_to_atom("Capture" ++ integer_to_list(Index)))
                || Index <- lists:seq(1, Arity)],
    erl_syntax:clause([erl_syntax:atom(Function), erl_syntax:list(Captures)], none,
                      [erl_syntax:application(erl_syntax:atom(Function), Captures)]).

code_function(Code) ->
    [erl_syntax:function(erl_syntax:atom('$code'),
                         [erl_syntax:clause([], none, [erl_syntax:abstract(Code)])])].

%% Report §8.7, §11.2: the other units the unit's code calls, each the
%% module of a remote call or of a function value that is an Ernest unit,
%% whose name begins `ern@` (§11.1). A peer's spawn reads a reach's
%% bindings and foreign declarations in the units the code of the unit
%% that runs it calls, directly or through one it calls (ern_code). A
%% module of the standard library lists none, since no reach names what it
%% holds (Appendix H), so that a walk from a program's unit ends there.
calls(_Bodies, _ErlangModule, true) ->
    [];
calls(Bodies, ErlangModule, false) ->
    lists:usort([Unit || Function <- Bodies,
                         Unit <- erl_syntax_lib:fold(fun called_unit/2, [], Function),
                         Unit =/= ErlangModule]).

called_unit(Node, Units) ->
    case erl_syntax:type(Node) of
        module_qualifier ->
            Module = erl_syntax:module_qualifier_argument(Node),
            case erl_syntax:type(Module) =:= atom
                 andalso lists:prefix("ern@", atom_to_list(erl_syntax:atom_value(Module))) of
                true -> [erl_syntax:atom_value(Module) | Units];
                false -> Units
            end;
        _ ->
            Units
    end.

%% Report §8.5: the units of the modules this one depends on, whose
%% top-level bindings are evaluated before its own.
dependencies_function(#unit{dependencies = []}) ->
    [];
dependencies_function(#unit{dependencies = Dependencies}) ->
    Modules = erl_syntax:list([erl_syntax:atom(Dependency) || Dependency <- Dependencies]),
    [erl_syntax:function(erl_syntax:atom('$deps'),
                         [erl_syntax:clause([], none, [Modules])])].

%%
%% Expressions: expr(Expr, Context) -> {Form, Context}
%%

%% An expression's form, at the place its source gives.
expr(Expr, Context) ->
    {Source, Node} = sourced(Expr),
    {Form, Context1} = expr_form(Node, Source, Context),
    {at(Source, Form), Context1}.

expr_form({literal, Kind, Value}, _, Context) ->
    {literal(Kind, Value), Context};
expr_form({var, Reference, Supplies}, Source, Context) ->
    {Form, Context1} = name_form(Source, Reference, Supplies, none, Context),
    {Form, function_value(Form, Context1)};
expr_form({var, Reference, Supplies, Extra}, Source, Context) ->
    {Form, Context1} = name_form(Source, Reference, Supplies, Extra, Context),
    {Form, function_value(Form, Context1)};
expr_form({construct, Constructor, Arguments}, _, Context) ->
    constructor_expr(Constructor, Arguments, Context);
expr_form({tuple, Elements}, _, Context) when length(Elements) > ?LONG_LITERAL ->
    {Built, Context1} = built_in_order(Elements, Context),
    {call_remote(erlang, list_to_tuple, [Built]), Context1};
expr_form({list, Elements}, _, Context) when length(Elements) > ?LONG_LITERAL ->
    built_in_order(Elements, Context);
expr_form({tuple, Elements}, _, Context) ->
    {Forms, Context1} = exprs(Elements, Context),
    {erl_syntax:tuple(Forms), Context1};
expr_form({list, Elements}, _, Context) ->
    {Forms, Context1} = exprs(Elements, Context),
    {erl_syntax:list(Forms), Context1};
expr_form({bitstring, Segments}, _, Context) ->
    %% report §5.11, §7.4: the runtime's bit syntax, each segment's value
    %% checked for its width by ern_bits, a badarg the segment overflow
    %% fault, and the result checked for alignment when a dynamic size
    %% leaves the bit count open
    {Compiled, {Context1, Open}} =
        lists:mapfoldl(fun(Segment, {Acc, OpenSoFar}) ->
                           {Spec, Value} = segment_spec(Segment),
                           {ValueForm, Acc1} = expr(Value, Acc),
                           {SizeForm, Acc2} = size_form(Spec, Acc1),
                           {{Spec, ValueForm, SizeForm}, {Acc2, OpenSoFar orelse is_open(Spec)}}
                       end, {Context, false}, Segments),
    {Bindings, Parts, Context2} = segments_bound(Compiled, Context1),
    Fields = [erl_syntax:binary_field(segment_value(Spec, ValueForm, SizeForm), SizeForm,
                                      type_specs(Spec))
              || {Spec, ValueForm, SizeForm} <- Parts],
    Handler = erl_syntax:clause([erl_syntax:class_qualifier(erl_syntax:atom(error),
                                                            erl_syntax:atom(badarg))],
                                none, [call_remote(ern_bits, overflow, [])]),
    Built = erl_syntax:try_expr([erl_syntax:binary(Fields)], [], [Handler]),
    Checked = case Open of
                  true -> call_remote(ern_bits, aligned, [Built]);
                  false -> Built
              end,
    {with_bindings(Bindings, Checked), Context2};
expr_form({block, Statements}, _, Context) ->
    {Forms, Context1} = block(Statements, Context),
    {erl_syntax:block_expr(Forms),
     Context1#emit_context{variables = Context#emit_context.variables,
                           locals = Context#emit_context.locals}};
expr_form({piped_call, Callee, [Expr | Rest]}, _, Context) ->
    %% report §5.1: in `x |> e`, x is evaluated before a callee that is
    %% evaluated at all, and the other arguments after it
    {[ExprForm, CalleeForm | RestForms], Context1} = exprs([Expr, Callee | Rest], Context),
    {[PipedName], Context2} = fresh_variables(1, "Piped", Context1),
    Piped = erl_syntax:variable(PipedName),
    Application = erl_syntax:application(CalleeForm, [Piped | RestForms]),
    {erl_syntax:block_expr([erl_syntax:match_expr(Piped, ExprForm), Application]), Context2};
expr_form({call, Callee, Args}, Source, Context) ->
    call(Source, Callee, Args, Context);
expr_form({'not', Expr}, _, Context) ->
    {Form, Context1} = expr(Expr, Context),
    {erl_syntax:prefix_expr(erl_syntax:operator('not'), Form), Context1};
expr_form({select, Expr, Reference, Field}, _, Context) ->
    {Form, Context1} = expr(Expr, Context),
    select(Field, Reference, Form, Context1);
expr_form({negate, Expr, {runtime, Type}}, _, Context) ->
    {Form, Context1} = expr(Expr, Context),
    {negate(checked_type(Type, Context), Form), Context1};
expr_form({negate, Expr, Supply}, _, Context) ->
    %% report §5.1, §4.9: `negate` in the operand type's namespace, or the
    %% member a requirement names
    {Form, Context1} = expr(Expr, Context),
    member_applied(Supply, [Form], Context1);
expr_form({operator, Operator, Left, Right, Operation}, _, Context) ->
    operator(Operator, Left, Right, Operation, Context);
expr_form({member, Supply}, _, Context) ->
    %% report §4.9: a member as a value
    {Form, Context1} = supply_form(Supply, Context),
    {Form, function_value(Form, Context1)};
expr_form({lambda, _Position, Params, _, _, Body}, _, Context) ->
    {Patterns, Context1} = lists:mapfoldl(fun({param, Pattern, _}, Acc) ->
                                              pattern(Pattern, Acc)
                                          end, Context, Params),
    {BodyForms, Context2} = body(Body, Context1),
    Clause = erl_syntax:clause(Patterns, none, BodyForms),
    {erl_syntax:fun_expr([Clause]),
     Context2#emit_context{variables = Context#emit_context.variables,
                           builds_functions = true}};
expr_form({'if', Condition, Then, Else}, _, Context) ->
    {ConditionForm, Context1} = expr(Condition, Context),
    {[ThenForms, ElseForms], Context2} = lists:mapfoldl(fun body/2, Context1, [Then, Else]),
    Clauses = [erl_syntax:clause([erl_syntax:atom(true)], none, ThenForms),
               erl_syntax:clause([erl_syntax:atom(false)], none, ElseForms)],
    {erl_syntax:case_expr(ConditionForm, Clauses), Context2};
expr_form({match, Scrutinee, Written}, _, Context) ->
    {ScrutineeForm, Context1} = expr(Scrutinee, Context),
    matched(ScrutineeForm, Written, Context1);
expr_form({'receive', Written, After}, _, Context) ->
    %% report §6.3: a receive guard is a guard expression, which the
    %% checker holds it to, so it is an Erlang guard here, a top-level `let`
    %% it names, or a pattern's size names (§5.11), read into a variable
    %% before the receive; a message from a foreign process was checked by
    %% the checker that delivered it (§8.4)
    {Clauses, {Reads, Context1}} = lists:mapfoldl(fun read_before/2, {[], Context}, Written),
    {Bindings, Receive, Context2} = receive_form(Clauses, After, Context1),
    {with_bindings(Reads ++ Bindings, Receive), Context2}.

%% Report §4.8, §4.9, §5.1: an operator. One resolved to a member a
%% requirement names, a member whose own requirement is supplied, or a
%% member of a type a module declares, is that member applied; a prelude
%% type's, and the runtime's own operation at its operand's type, is the
%% host's operation.
operator(Operator, Left, Right, {known, {named, [TypeName, _]}, []}, Context) ->
    plain_operator(Operator, Left, Right, {tcon, [TypeName], []}, Context);
operator(Operator, Left, Right, {runtime, Type}, Context) ->
    plain_operator(Operator, Left, Right, checked_type(Type, Context), Context);
operator(Operator, Left, Right, runtime, Context) ->
    plain_operator(Operator, Left, Right, none, Context);
operator(Operator, Left, Right, Supply, Context) ->
    {Operands, Context1} = exprs([Left, Right], Context),
    {Applied, Context2} = member_applied(Supply, Operands, Context1),
    {ordered(Operator, Applied), Context2}.

plain_operator(Operator, Left, Right, Type, Context) ->
    {[LeftForm, RightForm], Context1} = exprs([Left, Right], Context),
    case Type of
        {tcon, ['Float'], []}
          when Operator =:= '+'; Operator =:= '-'; Operator =:= '*'; Operator =:= '/' ->
            {[LeftName, RightName], Context2} = fresh_variables(2, "Operand", Context1),
            {float_operation(Operator, LeftForm, RightForm, LeftName, RightName), Context2};
        _ ->
            {binop(Operator, Type, LeftForm, RightForm, Context), Context1}
    end.

%% Report §5.11: a top-level `let` a pattern's size names is read into a
%% variable when the match begins, after its scrutinee (§5.1: left to
%% right), which is then matched from a variable of its own.
matched(ScrutineeForm, Written, Context) ->
    case lists:mapfoldl(fun read_sizes/2, {[], Context}, Written) of
        {Clauses, {[], Context1}} ->
            match_clauses(ScrutineeForm, Clauses, Context1);
        {Clauses, {Reads, Context1}} ->
            read_first(ScrutineeForm, Reads, Clauses, Context1)
    end.

%% A match whose sizes read top-level lets, its scrutinee bound to a
%% variable before the reads.
read_first(ScrutineeForm, Reads, Clauses, Context) ->
    {[ScrutineeName], Context1} = fresh_variables(1, "Scrutinee", Context),
    Scrutinee = erl_syntax:variable(ScrutineeName),
    Evaluated = erl_syntax:match_expr(Scrutinee, ScrutineeForm),
    {Form, Context2} = match_clauses(Scrutinee, Clauses, Context1),
    {with_bindings([Evaluated | Reads], Form), Context2}.

%% A receive of Clauses with its `after`, if any: the bindings before it,
%% and the receive.
receive_form(Clauses, none, Context) ->
    {Bindings, ClauseForms, Context1} = receive_clauses(Clauses, Context),
    {Bindings, erl_syntax:receive_expr(ClauseForms), Context1};
receive_form(Clauses, {'after', Timeout, AfterBody}, Context) ->
    {Bindings, ClauseForms, Context1} = receive_clauses(Clauses, Context),
    {Enter, Wait, Context2} = timed_receive(ClauseForms, Timeout, AfterBody, Context1),
    {Bindings ++ Enter, Wait, Context2}.

%% A receive's clauses and the bindings they need. Report §6.9: a restart
%% a supervisor asks for arrives before every other message and is taken
%% here, first; report §8.4: a foreign message that did not match stands
%% in the mailbox as its fault, which is taken here before any clause of
%% the program's could bind it.
receive_clauses(Clauses, Context) ->
    {Parts, Context1} = lists:mapfoldl(fun simple_clauses/2, Context, Clauses),
    {Bindings, OwnForms} = join_parts(Parts),
    {[CauseName], Context2} = fresh_variables(1, "Cause", Context1),
    Cause = erl_syntax:variable(CauseName),
    ClauseForms = [erl_syntax:clause([erl_syntax:atom('$ern_restart')], none,
                                     [call_remote(ern_rt, restart_now, [])]),
                   erl_syntax:clause([erl_syntax:tuple([erl_syntax:atom('$ern_fault'), Cause])],
                                     none, [call_remote(ern_rt, fault, [Cause])])
                   | OwnForms],
    {Bindings, ClauseForms, Context2}.

%% A receive with an `after`: the bindings that enter it, and the call
%% that waits. Report §8.6: a timed receive counts itself in before, and
%% out first in every body, so the reaper knows it is not waiting. Report
%% §6.3: a time below 0 is 0, and none is too long; the host waits at most
%% 2^32 - 1 ms at once, so the receive is entered again until the deadline
%% has passed (ern_rt:deadline/1).
timed_receive(ClauseForms, Timeout, AfterBody, Context) ->
    {TimeoutForm, Context1} = expr(Timeout, Context),
    {AfterForms, Context2} = body(AfterBody, Context1),
    waiting(ClauseForms, TimeoutForm, AfterForms, Context2).

%% The timed receive of ClauseForms, entered again until its deadline has
%% passed: the bindings that enter it, and the call that waits.
waiting(ClauseForms, TimeoutForm, AfterForms, Context) ->
    {[DeadlineName, WaitName], Context1} = named_variables(["Deadline", "Wait"], Context),
    Deadline = erl_syntax:variable(DeadlineName),
    Remaining = call_remote(ern_rt, remaining, [Deadline]),
    Untimed = call_remote(ern_rt, untimed, []),
    Timed = [erl_syntax:clause(erl_syntax:clause_patterns(ClauseForm),
                               erl_syntax:clause_guard(ClauseForm),
                               [Untimed | erl_syntax:clause_body(ClauseForm)])
             || ClauseForm <- ClauseForms],
    WaitAgain = erl_syntax:application(erl_syntax:variable(WaitName), []),
    Due = erl_syntax:case_expr(
            Remaining,
            [erl_syntax:clause([erl_syntax:integer(0)], none, [Untimed | AfterForms]),
             erl_syntax:clause([erl_syntax:underscore()], none, [WaitAgain])]),
    Receive = erl_syntax:receive_expr(Timed, Remaining, [Due]),
    Wait = erl_syntax:named_fun_expr(erl_syntax:variable(WaitName),
                                     [erl_syntax:clause([], none, [Receive])]),
    Enter = [erl_syntax:match_expr(Deadline, call_remote(ern_rt, deadline, [TimeoutForm])),
             call_remote(ern_rt, timed, [])],
    {Enter, erl_syntax:application(Wait, []), Context1}.

exprs(Exprs, Context) ->
    lists:mapfoldl(fun expr/2, Context, Exprs).

%% Report §6.3, §5.11: each top-level `let` a receive clause's guard or its
%% pattern's sizes name, read into a fresh variable that names it in its
%% place.
read_before(Clause, Acc) ->
    {Clause1, Acc1} = read_sizes(Clause, Acc),
    read_guard(Clause1, Acc1).

read_guard(Clause, Acc) ->
    {Source, {clause, Pattern, Guard, Body}} = sourced(Clause),
    case Guard of
        none ->
            {Clause, Acc};
        _ ->
            {Guard1, Acc1} = read_top(Guard, Acc),
            {rewrapped(Source, {clause, Pattern, Guard1, Body}), Acc1}
    end.

%% Report §5.11: each top-level `let` a clause's pattern names in a size.
read_sizes(Clause, Acc) ->
    {Source, {clause, Pattern, Guard, Body}} = sourced(Clause),
    {Pattern1, Acc1} = read_pattern_sizes(Pattern, Acc),
    {rewrapped(Source, {clause, Pattern1, Guard, Body}), Acc1}.

read_pattern_sizes({segment, Kind, {expr, Size}, Unit, Endian, Sign, Value}, Acc) ->
    {Size1, Acc1} = read_top(Size, Acc),
    {Value1, Acc2} = read_pattern_sizes(Value, Acc1),
    {{segment, Kind, {expr, Size1}, Unit, Endian, Sign, Value1}, Acc2};
read_pattern_sizes(Node, Acc) when is_tuple(Node), tuple_size(Node) > 0 ->
    {Fields, Acc1} = lists:mapfoldl(fun read_pattern_sizes/2, Acc, tuple_to_list(Node)),
    {list_to_tuple(Fields), Acc1};
read_pattern_sizes(Nodes, Acc) when is_list(Nodes) ->
    lists:mapfoldl(fun read_pattern_sizes/2, Acc, Nodes);
read_pattern_sizes(Other, Acc) ->
    {Other, Acc}.

read_top(Expr, Acc) ->
    {Source, Node} = sourced(Expr),
    {Node1, Acc1} = read_top_node(Node, Expr, Acc),
    {rewrapped(Source, Node1), Acc1}.

read_top_node({operator, Operator, Left, Right, Operation}, _, Acc) ->
    {Left1, Acc1} = read_top(Left, Acc),
    {Right1, Acc2} = read_top(Right, Acc1),
    {{operator, Operator, Left1, Right1, Operation}, Acc2};
read_top_node({'not', Inner}, _, Acc) ->
    {Inner1, Acc1} = read_top(Inner, Acc),
    {{'not', Inner1}, Acc1};
read_top_node({negate, Inner, Operation}, _, Acc) ->
    {Inner1, Acc1} = read_top(Inner, Acc),
    {{negate, Inner1, Operation}, Acc1};
read_top_node({var, Reference, _}, Expr, {Reads, Context})
  when element(1, Reference) =/= local, element(1, Reference) =/= read ->
    {Form, Context1} = expr(Expr, Context),
    {[ReadName], Context2} = fresh_variables(1, "Read", Context1),
    {{var, {read, ReadName}, []},
     {Reads ++ [erl_syntax:match_expr(erl_syntax:variable(ReadName), Form)], Context2}};
read_top_node(Node, _, Acc) ->
    {Node, Acc}.

%% A body: a block's statements spliced into the clause, else one expression.
body(Expr, Context) ->
    case sourced(Expr) of
        {_, {block, Statements}} ->
            {Forms, Context1} = block(Statements, Context),
            {Forms,
             Context1#emit_context{variables = Context#emit_context.variables,
                                   locals = Context#emit_context.locals}};
        _ ->
            {Form, Context1} = expr(Expr, Context),
            {[Form], Context1}
    end.

literal(int, Value) -> erl_syntax:integer(Value);
literal(float, Value) -> erl_syntax:float(Value);
literal(char, Value) -> erl_syntax:char(Value);
literal(string, Value) -> string_binary(Value);
literal(bool, Value) -> erl_syntax:atom(Value).

%% <<"text">>, with /utf8 only when a character is outside ASCII.
string_binary(Text) ->
    Chars = unicode:characters_to_list(Text),
    String = erl_syntax:string(Chars),
    Field = case lists:all(fun(Char) -> Char < 128 end, Chars) of
                true -> erl_syntax:binary_field(String);
                false -> erl_syntax:binary_field(String, [erl_syntax:atom(utf8)])
            end,
    erl_syntax:binary([Field]).

%%
%% Names
%%

%% A name used as a value: name_form(...) -> {Form, Context}. Report §4.2:
%% what the name refers to is the form's reference, read and not decided
%% here; Extra is what a form holds beside a use of `Address.call` or a
%% spawn on a peer, or none.
name_form(Source, {local, Number}, [], _, Context) ->
    local_value(Source, Number, Context);
name_form(_, {read, ReadName}, [], _, Context) ->
    {erl_syntax:variable(ReadName), Context};
%% Appendix E.1: the library's Io.show and Io.debug as values too, by what
%% the checker supplied for the argument's type, named by the form's
%% reference from another module and from the library's own alike
name_form(_, {named, ['Io', Name]}, [Shown], _, Context) when Name =:= show; Name =:= debug ->
    io_value(Name, Shown, Context);
%% Report §8.4, Appendix E.12: Foreign.term as a value, which gives its
%% argument as a foreign function's argument of the supplied type crosses
name_form(_, {named, ['Foreign', term]}, [{shown, Crossing}], _, Context) ->
    term_value(Crossing, Context);
%% Report §8.7: Peer.service as a value, its service's type's hash supplied
name_form(_, {named, ['Peer', service]}, [ServiceType], _, Context) ->
    {[Name], Context1} = fresh_variables(1, "Name", Context),
    {lambda([Name], call_remote(ern_peer, service, [erl_syntax:variable(Name),
                                                    service_hash(ServiceType)])),
     Context1};
name_form(Source, {named, QualifiedName} = Reference, [], Extra, Context) ->
    case is_own(Reference, Context) orelse not is_primitive(QualifiedName) of
        true -> {declared_value(Reference, Context), Context};
        false -> prelude_value(Source, QualifiedName, Extra, Context)
    end;
name_form(_, Reference, [], _, Context) ->
    {declared_value(Reference, Context), Context};
%% Report §4.9: a declaration with a requirement taken as a value is the
%% function with its members supplied
name_form(Source, Reference, Supplies, Extra, Context) ->
    Arity = value_arity(Reference, Context) - length(Supplies),
    {Function, Context1} = name_form(Source, Reference, [], Extra, Context),
    {SupplyForms, Context2} = supply_forms(Supplies, Context1),
    Call = fun([FunctionVariable | SupplyVariables], Args) ->
                   erl_syntax:application(FunctionVariable, Args ++ SupplyVariables)
           end,
    supplied_lambda(Arity, [{"Function", Function} | supplied(SupplyForms)], Call, Context2).

%% A local as a value: the variable it is bound to, or a local fn's
%% closure over what it closes over.
local_value(_, Number, #emit_context{variables = Variables, locals = Locals} = Context) ->
    case Variables of
        #{Number := Variable} ->
            {variable_form(Variable), Context};
        _ ->
            #{Number := #local_fn{lifted_name = LiftedName, function = Function}} = Locals,
            closure(LiftedName, captured_variables(Number, Context), local_arity(Function),
                    Context)
    end.

%% A local fn's arity, its parameters and its requirement's members, which
%% are supplied where it is named (§4.9).
local_arity({function, _, Params, _, _, Needs, _}) ->
    length(Params) + length(Needs).

%% Report §4.9: a function value with its members supplied, a lambda of
%% Arity parameters whose body is Call of the bound variables and the
%% parameters. Each of Bound, a variable's prefix and its form, is bound
%% before the lambda, so that it is computed once, where the value is.
supplied_lambda(Arity, Bound, Call, Context) ->
    {Params, Context1} = fresh_variables(Arity, "Argument", Context),
    {Variables, Context2} = named_variables([Prefix || {Prefix, _} <- Bound], Context1),
    Matches = [erl_syntax:match_expr(erl_syntax:variable(Variable), Form)
               || {Variable, {_, Form}} <- lists:zip(Variables, Bound)],
    Applied = Call([erl_syntax:variable(Variable) || Variable <- Variables],
                   [erl_syntax:variable(Param) || Param <- Params]),
    {erl_syntax:block_expr(Matches ++ [lambda(Params, Applied)]), Context2}.

%% The supplies' forms, each bound before the lambda to a variable of its
%% own.
supplied(SupplyForms) ->
    [{"Supplied", SupplyForm} || SupplyForm <- SupplyForms].

%% Report §4.6: a declaration as a value. A `let` is reached through its
%% getter even where it holds a function; a `fn` is the function itself, a
%% fun of its unit, which keeps the code it was taken from (§11.2).
declared_value(Reference, Context) ->
    case placed(Reference, Context) of
        {own, Position, value, _} ->
            erl_syntax:application(erl_syntax:atom(function_name(Position)), []);
        {own, Position, function, Arity} ->
            erl_syntax:implicit_fun(erl_syntax:atom(function_name(Position)),
                                    erl_syntax:integer(Arity));
        {Unit, Position, value, _} ->
            call_remote(Unit, function_name(Position), []);
        {Unit, Position, function, Arity} ->
            remote_fun(Unit, function_name(Position), Arity)
    end.

%% Report §11.1: where a declaration a form references is: own, a function
%% of this unit, or another unit's, with its position, its kind and its
%% function's arity.
placed(Reference, #emit_context{own = #own{forms = Forms, foreign = Foreign}} = Context) ->
    case own_position(Reference, Context) of
        {ok, Position} when is_map_key(Position, Forms) ->
            {_, Form} = maps:get(Position, Forms),
            Kind = case sourced(Form) of
                       {_, {binding, _, _, _}} -> value;
                       _ -> function
                   end,
            {own, Position, Kind, arity(Form)};
        {ok, Position} ->
            {_, ForeignFunction} = lists:keyfind(Position, 1, maps:values(Foreign)),
            {own, Position, function, foreign_arity(ForeignFunction)};
        error ->
            case linked(Reference, Context) of
                #linked{position = undefined} ->
                    fail(none, unlinked(Reference));
                #linked{unit = Unit, position = Position, kind = Kind, arity = Arity} ->
                    {Unit, Position, Kind, Arity}
            end
    end.

%% The position of the unit's own definition or foreign function a
%% reference names, or error for another unit's.
own_position({hash, Hash}, #emit_context{own = #own{hashes = Hashes}}) ->
    maps:find(Hash, Hashes);
own_position({binding, QualifiedName, _}, #emit_context{own = #own{names = Names}}) ->
    maps:find(QualifiedName, Names);
own_position({named, QualifiedName},
           #emit_context{own = #own{names = Names, foreign = Foreign}}) ->
    %% the standard library's own forms name its declarations by name
    case maps:find(QualifiedName, Names) of
        {ok, Position} ->
            {ok, Position};
        error ->
            case Foreign of
                #{QualifiedName := {Position, _}} -> {ok, Position};
                _ -> error
            end
    end;
own_position({foreign, QualifiedName, _}, #emit_context{own = #own{foreign = Foreign}}) ->
    case Foreign of
        #{QualifiedName := {Position, _}} -> {ok, Position};
        _ -> error
    end;
own_position(_, _) ->
    error.

is_own(Reference, Context) ->
    own_position(Reference, Context) =/= error.

%% The link's entry for a reference to another unit (report §8.7, §11.1).
linked(Reference, #emit_context{unit = #unit{link = #link{functions = Functions}}}) ->
    case Functions of
        #{Reference := Linked} -> Linked;
        _ -> erlang:error({emitter_defect, none, unlinked(Reference)})
    end.

unlinked(Reference) ->
    lists:flatten(io_lib:format("the link places no ~p in a unit", [Reference])).

%% The arity of the function a name a form references compiles to, a
%% requirement's members among its parameters (§4.9).
value_arity({local, Number}, #emit_context{locals = Locals}) ->
    #{Number := #local_fn{function = Function}} = Locals,
    local_arity(Function);
value_arity(Reference, Context) ->
    {_, _, _, Arity} = placed(Reference, Context),
    Arity.

%% Report §11.2: whether a name is one of the prelude's primitives, which
%% the runtime gives and no unit holds (§9).
is_primitive([Name]) ->
    lists:member(Name, [self, send, answer, adapted, monitor, kill, spawn, spawnMonitored,
                        restarting, fault]);
is_primitive(['Address', Name]) -> Name =:= call orelse Name =:= callForever;
is_primitive(['Int', Name]) -> lists:member(Name, ['+', '-', '*', '/', '%', negate]);
is_primitive([TypeName, '<>']) -> lists:member(TypeName, ['String', 'List', 'Bytes']);
is_primitive(_) -> false.

closure(LiftedName, Captures, Arity, Context) ->
    {Params, Context1} = fresh_variables(Arity, "Argument", Context),
    Args = [erl_syntax:variable(Variable) || Variable <- Captures ++ Params],
    Body = erl_syntax:application(erl_syntax:atom(LiftedName), Args),
    {erl_syntax:fun_expr([erl_syntax:clause([erl_syntax:variable(Param) || Param <- Params], none,
                                            [Body])]),
     Context1}.

%%
%% Calls
%%

call(Source, Callee, Args, Context) ->
    {_, CalleeNode} = sourced(Callee),
    callee(Source, CalleeNode, Callee, Args, Context).

callee(_, {var, {local, Number}, Supplies}, _, Args, Context) ->
    #emit_context{variables = Variables, locals = Locals} = Context,
    {ArgForms, Context1} = exprs(Args, Context),
    case Variables of
        #{Number := Variable} ->
            {erl_syntax:application(variable_form(Variable), ArgForms), Context1};
        _ ->
            #{Number := #local_fn{lifted_name = LiftedName}} = Locals,
            Captures = [erl_syntax:variable(Variable)
                        || Variable <- captured_variables(Number, Context)],
            {SupplyForms, Context2} = supply_forms(Supplies, Context1),
            Application = erl_syntax:application(erl_syntax:atom(LiftedName),
                                                 Captures ++ ArgForms ++ SupplyForms),
            {Application, Context2}
    end;
%% Appendix E.1: the library's Io.show and Io.debug, as name_form/5 names
%% them, written by what the checker supplied for the argument's type
callee(_, {var, {named, ['Io', Name]}, [Shown]}, _, [Argument], Context)
  when Name =:= show; Name =:= debug ->
    {[ArgumentForm], Context1} = exprs([Argument], Context),
    {DescriptorForm, Context2} = supply_form(Shown, Context1),
    {call_remote(ern_io, Name, [ArgumentForm, DescriptorForm]), Context2};
%% Report §8.4, Appendix E.12: Foreign.term, the value as a foreign
%% function's argument of its type crosses, by what the checker supplied
callee(_, {var, {named, ['Foreign', term]}, [{shown, Crossing}]}, _, [Argument], Context) ->
    {[ArgumentForm], Context1} = exprs([Argument], Context),
    exposed({Crossing, ArgumentForm}, Context1);
%% Report §8.7, Appendix E.27: Peer.service makes its service with its
%% message type's hash, of the type the checker supplied; Peer.spawn,
%% Peer.spawnMonitored and Peer.compute send the function's identity and
%% captures in place of the function, and the spawn's or the compute's
%% site, as a spawn on this node keeps it (§6.9); a spawn passes last the
%% captures that carry a reply, whose calls it ends where it fails (§6.6),
%% and a compute none, since the checker refuses a compute's function that
%% captured one (§6.6's rule)
callee(_, {var, {named, ['Peer', service]}, [ServiceType]}, _, [Argument], Context) ->
    {[ArgumentForm], Context1} = exprs([Argument], Context),
    {call_remote(ern_peer, service, [ArgumentForm, service_hash(ServiceType)]), Context1};
callee(Source, {var, {named, ['Peer', Name]}, _}, _, [PeerName, Spawned | Rest], Context)
  when Name =:= spawn; Name =:= spawnMonitored; Name =:= compute ->
    %% a compute's function holds no reply (§6.6's rule), nor its form any
    peer_spawn(Source, Name, [], PeerName, Spawned, Rest, Context);
callee(Source, {var, {named, ['Peer', Name]}, _, Held}, _, [PeerName, Spawned | Rest], Context)
  when Name =:= spawn; Name =:= spawnMonitored ->
    peer_spawn(Source, Name, Held, PeerName, Spawned, Rest, Context);
callee(Source, {var, {named, QualifiedName} = Reference, []} = Node, _, Args, Context) ->
    case is_own(Reference, Context) orelse not is_primitive(QualifiedName) of
        true ->
            declared_call(Reference, [], Args, Context);
        false ->
            %% report §4.2: the prelude's, `Prelude.x` among them
            {ArgForms, Context1} = exprs(Args, Context),
            prelude_call(Source, QualifiedName, Args, ArgForms, Node, Context1)
    end;
callee(Source, {var, {named, ['Address', _] = QualifiedName}, [], _} = Node, _, Args, Context) ->
    {ArgForms, Context1} = exprs(Args, Context),
    prelude_call(Source, QualifiedName, Args, ArgForms, Node, Context1);
%% report §4.9: a member called directly, `a.compare(x, y)` or a derived
%% compare's field
callee(_, {member, {known, Reference, Supplies}}, _, Args, Context) ->
    {ArgForms, Context1} = exprs(Args, Context),
    {SupplyForms, Context2} = supply_forms(Supplies, Context1),
    {member_call(Reference, ArgForms ++ SupplyForms, Context), Context2};
callee(_, {var, Reference, Supplies}, _, Args, Context) when element(1, Reference) =/= read ->
    declared_call(Reference, Supplies, Args, Context);
callee(_, _, Callee, Args, Context) ->
    {CalleeForm, Context1} = expr(Callee, Context),
    {ArgForms, Context2} = exprs(Args, Context1),
    {erl_syntax:application(CalleeForm, ArgForms), Context2}.

%% Report §4.6: a call of a declaration, a `let` through what its getter
%% answers and a `fn` the call itself, a requirement's members after the
%% arguments written.
declared_call(Reference, Supplies, Args, Context) ->
    {WrittenForms, Context1} = exprs(Args, Context),
    {SupplyForms, Context2} = supply_forms(Supplies, Context1),
    ArgForms = WrittenForms ++ SupplyForms,
    Form = case placed(Reference, Context) of
               {own, Position, value, _} ->
                   Get = erl_syntax:application(erl_syntax:atom(function_name(Position)), []),
                   erl_syntax:application(Get, ArgForms);
               {own, Position, function, _} ->
                   erl_syntax:application(erl_syntax:atom(function_name(Position)), ArgForms);
               {Unit, Position, value, _} ->
                   erl_syntax:application(call_remote(Unit, function_name(Position), []), ArgForms);
               {Unit, Position, function, _} ->
                   call_remote(Unit, function_name(Position), ArgForms)
           end,
    {Form, Context2}.

io_value(Name, Shown, Context) ->
    {[Value], Context1} = fresh_variables(1, "Argument", Context),
    {DescriptorForm, Context2} = supply_form(Shown, Context1),
    {lambda([Value], call_remote(ern_io, Name, [erl_syntax:variable(Value), DescriptorForm])),
     Context2}.

term_value(Crossing, Context) ->
    {[Value], Context1} = fresh_variables(1, "Argument", Context),
    {Form, Context2} = exposed({Crossing, erl_syntax:variable(Value)}, Context1),
    {lambda([Value], Form), Context2}.

%%
%% Supplies, report §4.9: what the checker resolved a requirement's members
%% to, each an argument the program does not write
%%

supply_forms(Supplies, Context) ->
    lists:mapfoldl(fun(Supply, Acc) ->
                       {Form, Acc1} = supply_form(Supply, Acc),
                       {Form, function_value(Form, Acc1)}
                   end, Context, Supplies).

%% A member the enclosing requirement names is the parameter it came in;
%% `show` at a known type is the type's descriptor; a known type's member
%% is that member as a function, its own requirement supplied.
supply_form({required, {variable, Number}, Member}, Context) ->
    {erl_syntax:variable(member_variable(Number, Member, Context)), Context};
supply_form({shown, Type, Abstract}, #emit_context{members = Members} = Context) ->
    %% report §4.9, Appendix E.1: a type built from type variables a
    %% requirement names `show` for is the descriptor composed of theirs,
    %% which came in as the requirement's members; the types the site
    %% prints as `<abstract>` are the form's
    Holes = [Number || {variable, Number} <- lists:usort(type_variables(Type)),
                       is_map_key({Number, show}, Members)],
    Descriptor = describe(Type, Holes, Abstract, Context),
    case Holes of
        [] -> {erl_syntax:abstract(Descriptor), Context};
        _ -> {holes_filled(Descriptor, Context), Context}
    end;
supply_form({known, {named, [_, Member]} = Reference, []}, Context) ->
    member_value(Reference, Member, Context);
supply_form({known, Reference, Supplies}, Context) ->
    {SupplyForms, Context1} = supply_forms(Supplies, Context),
    Arity = value_arity(Reference, Context) - length(Supplies),
    case SupplyForms of
        [] ->
            {member_fun(Reference, Arity, Context1), Context1};
        _ ->
            Call = fun(SupplyVariables, Args) ->
                           member_call(Reference, Args ++ SupplyVariables, Context1)
                   end,
            supplied_lambda(Arity, supplied(SupplyForms), Call, Context1)
    end.

%% A descriptor as a form, each hole the descriptor its variable's `show`
%% came in as.
holes_filled({hole, Number}, Context) ->
    erl_syntax:variable(member_variable(Number, show, Context));
holes_filled(Part, Context) when is_tuple(Part) ->
    erl_syntax:tuple([holes_filled(Inner, Context) || Inner <- tuple_to_list(Part)]);
holes_filled(Parts, Context) when is_list(Parts) ->
    erl_syntax:list([holes_filled(Inner, Context) || Inner <- Parts]);
holes_filled(Leaf, _) ->
    erl_syntax:abstract(Leaf).

%% The parameter a requirement's member came in, in the declaration being
%% emitted or one that encloses it.
member_variable(Number, Member, #emit_context{members = Members}) ->
    maps:get({Number, Member}, Members).

member_arity(negate) -> 1;
member_arity(_) -> 2.

%% A member of a declared type as a function value: a local function of
%% this unit's, or another unit's (report §11.2).
member_fun(Reference, Arity, Context) ->
    case placed(Reference, Context) of
        {own, Position, _, _} ->
            erl_syntax:implicit_fun(erl_syntax:atom(function_name(Position)),
                                    erl_syntax:integer(Arity));
        {Unit, Position, _, _} ->
            remote_fun(Unit, function_name(Position), Arity)
    end.

%% Report §4.6: a call of a type's member, a local call when the type is
%% this module's, otherwise a call into the unit that owns it (report §4.2).
member_call(Reference, Args, Context) ->
    case placed(Reference, Context) of
        {own, Position, _, _} ->
            erl_syntax:application(erl_syntax:atom(function_name(Position)), Args);
        {Unit, Position, _, _} ->
            call_remote(Unit, function_name(Position), Args)
    end.

%% fun M:F/A
remote_fun(HostModule, HostFunction, Arity) ->
    erl_syntax:implicit_fun(erl_syntax:atom(HostModule), erl_syntax:atom(HostFunction),
                            erl_syntax:integer(Arity)).

call_remote(HostModule, HostFunction, Args) ->
    erl_syntax:application(erl_syntax:module_qualifier(erl_syntax:atom(HostModule),
                                                       erl_syntax:atom(HostFunction)),
                           Args).

%%
%% The prelude, report §9
%%

prelude_call(_, [self], [], [], _, Context) ->
    {call_remote(ern_rt, self, []), Context};
prelude_call(_, [send], _, ArgForms, _, Context) ->
    {call_remote(ern_rt, send, ArgForms), Context};
prelude_call(_, [answer], _, ArgForms, _, Context) ->
    {call_remote(ern_rt, answer, ArgForms), Context};
prelude_call(_, [adapted], _, ArgForms, _, Context) ->
    {call_remote(ern_rt, adapted, ArgForms), Context};
prelude_call(_, [monitor], _, ArgForms, _, Context) ->
    {call_remote(ern_rt, monitor, ArgForms), Context};
prelude_call(_, [kill], _, ArgForms, _, Context) ->
    {call_remote(ern_rt, kill, ArgForms), Context};
prelude_call(Source, [spawn], _, ArgForms, _, Context) ->
    {call_remote(ern_rt, spawn, ArgForms ++ [site(Source, Context)]), Context};
prelude_call(Source, [spawnMonitored], _, ArgForms, _, Context) ->
    {call_remote(ern_rt, spawn_monitored, ArgForms ++ [site(Source, Context)]), Context};
prelude_call(_, ['Address', call], _, ArgForms, Callee, Context) ->
    reply_call(call, ArgForms, answer_of(Callee), Context);
prelude_call(_, ['Address', callForever], _, ArgForms, Callee, Context) ->
    reply_call(call_forever, ArgForms, answer_of(Callee), Context);
prelude_call(_, [restarting], _, ArgForms, _, Context) ->
    {call_remote(ern_rt, restarting, ArgForms), Context};
prelude_call(_, [fault], _, [CauseForm], _, Context) ->
    {call_remote(ern_rt, fault, [CauseForm]), Context};
prelude_call(_, ['Int', Operator], _, [LeftForm, RightForm], _, Context)
  when Operator =:= '+'; Operator =:= '-'; Operator =:= '*'; Operator =:= '/';
       Operator =:= '%' ->
    {binop(Operator, {tcon, ['Int'], []}, LeftForm, RightForm, Context), Context};
prelude_call(_, ['Int', negate], _, [OperandForm], _, Context) ->
    {erl_syntax:prefix_expr(erl_syntax:operator('-'), OperandForm), Context};
prelude_call(_, [TypeName, '<>'], _, [LeftForm, RightForm], _, Context) ->
    {binop('<>', {tcon, [TypeName], []}, LeftForm, RightForm, Context), Context};
prelude_call(Source, QualifiedName, _, _, _, _) ->
    fail(Source, "no emission for " ++ ern_namespace:text(QualifiedName)).

%% The answer's type a use of `Address.call` or `Address.callForever` holds
%% (Appendix H).
answer_of({var, _, _, Answer}) -> Answer.

%% Report §6.6, §8.4: `Address.call` or `Address.callForever`, and in a
%% program what an answer from foreign code is checked by, the Reply's
%% answer type, as a foreign function's return is; a call the standard
%% library makes is the runtime's own, and checks nothing.
reply_call(Function, ArgForms, _, #emit_context{unit = #unit{standard = true}} = Context) ->
    {call_remote(ern_rt, Function, ArgForms), Context};
reply_call(Function, ArgForms, AnswerType, Context) ->
    {Check, Context1} = case descriptor(AnswerType, Context) of
                            Unchecked when Unchecked =:= any; Unchecked =:= foreign ->
                                {erl_syntax:atom(none), Context};
                            Descriptor ->
                                {DescriptorForm, Described} = descriptor_form(Descriptor, Context),
                                Text = check_text("reply does not match ", AnswerType, Context),
                                {erl_syntax:tuple([DescriptorForm, Text]), Described}
                        end,
    {call_remote(ern_rt, Function, ArgForms ++ [Check]), Context1}.

%% A prelude name taken as a value: prelude_value(...) -> {Form, Context}.
prelude_value(Source, [spawn], _, Context) ->
    %% a closure, since spawn takes the site as a second argument
    {[Function], Context1} = fresh_variables(1, "Argument", Context),
    ArgForms = [erl_syntax:variable(Function), site(Source, Context)],
    {lambda([Function], call_remote(ern_rt, spawn, ArgForms)), Context1};
prelude_value(Source, [spawnMonitored], _, Context) ->
    {[Function, Wrap], Context1} = fresh_variables(2, "Argument", Context),
    ArgForms = [erl_syntax:variable(Variable) || Variable <- [Function, Wrap]]
        ++ [site(Source, Context)],
    {lambda([Function, Wrap], call_remote(ern_rt, spawn_monitored, ArgForms)), Context1};
prelude_value(_, ['Address', Name] = QualifiedName, Answer, Context)
  when Name =:= call; Name =:= callForever ->
    Function = case Name of call -> call; callForever -> call_forever end,
    #linked{arity = Arity} = linked({named, QualifiedName}, Context),
    {Variables, Context1} = fresh_variables(Arity, "Argument", Context),
    ArgForms = [erl_syntax:variable(Variable) || Variable <- Variables],
    {Body, Context2} = reply_call(Function, ArgForms, Answer, Context1),
    {lambda(Variables, Body), Context2};
prelude_value(_, ['Int', Member], _, Context) ->
    member_value({named, ['Int', Member]}, Member, Context);
prelude_value(_, [TypeName, '<>'], _, Context) ->
    member_value({named, [TypeName, '<>']}, '<>', Context);
prelude_value(_, [Name] = QualifiedName, _, Context) ->
    #linked{arity = Arity} = linked({named, QualifiedName}, Context),
    {remote_fun(ern_rt, Name, Arity), Context}.

%% Report §9.6, §4.8: a prelude type's member as a value: Int's arithmetic
%% and negate, and `<>`, inline as the operators are, and any other its
%% type's module's function, of the member's arity.
member_value({named, ['Int', negate]}, negate, Context) ->
    {[Operand], Context1} = fresh_variables(1, "Operand", Context),
    Negated = erl_syntax:prefix_expr(erl_syntax:operator('-'), erl_syntax:variable(Operand)),
    {lambda([Operand], Negated), Context1};
member_value({named, ['Int', Operator]}, Operator, Context)
  when Operator =:= '+'; Operator =:= '-'; Operator =:= '*'; Operator =:= '/';
       Operator =:= '%' ->
    operator_value(Operator, ['Int'], Context);
member_value({named, [TypeName, '<>']}, '<>', Context) ->
    operator_value('<>', [TypeName], Context);
member_value(Reference, Member, Context) ->
    {member_fun(Reference, member_arity(Member), Context), Context}.

operator_value(Operator, QualifiedName, Context) ->
    {[Left, Right], Context1} = fresh_variables(2, "Operand", Context),
    Body = binop(Operator, {tcon, QualifiedName, []}, erl_syntax:variable(Left),
                 erl_syntax:variable(Right), Context),
    {lambda([Left, Right], Body), Context1}.

lambda(Variables, Body) ->
    erl_syntax:fun_expr([erl_syntax:clause([erl_syntax:variable(Variable) || Variable <- Variables],
                                           none, [Body])]).

%% Report §11.2: Context marked as building a function value where Form,
%% what an expression or a supply emits, is one of this unit's code, a
%% lambda's fun, a function of the unit taken as a value, or one bound
%% beside the values it closes over; a function of another unit's is that
%% unit's code. A fun the emitter makes for its own use, a timed receive's
%% loop, a guard's way to the clauses after it, the body alternatives share
%% or a foreign call counted, is called where it is made and held by
%% nothing, and is no function value: it is never what an expression emits.
function_value(Form, Context) ->
    case is_own_function(Form) of
        true -> Context#emit_context{builds_functions = true};
        false -> Context
    end.

is_own_function(Form) ->
    case erl_syntax:type(Form) of
        fun_expr -> true;
        named_fun_expr -> true;
        implicit_fun -> erl_syntax:type(erl_syntax:implicit_fun_name(Form)) =/= module_qualifier;
        block_expr -> is_own_function(lists:last(erl_syntax:block_expr_body(Form)));
        _ -> false
    end.

%% Whether a descriptor describes a function anywhere inside it.
holds_function({function, _, _, _, _, _}) -> true;
holds_function(Part) when is_tuple(Part) -> lists:any(fun holds_function/1, tuple_to_list(Part));
holds_function(Parts) when is_list(Parts) -> lists:any(fun holds_function/1, Parts);
holds_function(_) -> false.

%% Report §6.9: the function that called `spawn`, qualified, and the line;
%% report §11.2: a reload's version's under the version's namespace,
%% `Counter$2.service:5`, as its unit is named. In the session, as the
%% session writes names: a function an input declares by its own name, and
%% the input's expression as its diagnostics name it, `input 3`; the line
%% as they count it. The input's name is asked of the shell when the spawn
%% runs, and is not the unit's code: an input typed again then compiles
%% to the code it did before, and the host keeps an entry for each lambda
%% of each version it loads (docs/memory.md). A form without its source
%% names the declaration alone.
site(Source, #emit_context{unit = #unit{site_namespace = SiteNamespace,
                                        session_offset = SessionOffset},
                           erlang_module = ErlangModule, declaration = Declaration}) ->
    case {SessionOffset, Declaration, Source} of
        {_, _, none} ->
            text_site([ern_namespace:text(SiteNamespace ++ Declaration)]);
        {false, _, {Line, _, _}} ->
            text_site([ern_namespace:text(SiteNamespace ++ Declaration), ":",
                       integer_to_list(Line)]);
        {Offset, ['$input'], {Line, _, _}} ->
            call_remote(ern_shell, input_site, [erl_syntax:atom(ErlangModule),
                                                erl_syntax:integer(Line + Offset)]);
        {Offset, _, {Line, _, _}} ->
            text_site([ern_namespace:text(Declaration), ":", integer_to_list(Line + Offset)])
    end.

text_site(SiteParts) ->
    string_binary(unicode:characters_to_binary(SiteParts)).

%% Report §8.7, Appendix H: a service's message type's hash, of its
%% canonical form.
service_hash({service, Type}) ->
    erl_syntax:abstract(crypto:hash(sha256,
                                    ern_canonical:bytes({ernest_type,
                                                         ern_canonical:form_version(), Type}))).

%%
%% Operators, report §4.8
%%

%% Report §4.8, §3.10, §5.1: by the operand type. Int's arithmetic, and
%% the ordering of the four ordered prelude types, Int, Float, String and
%% Char, are Erlang's operators; Float's arithmetic is
%% float_operation/5; a user type's operator is its member, applied by
%% member_applied/3 and ordered/2, and never reaches here.
binop(Operator, {tcon, ['Int'], []}, Left, Right, _)
  when Operator =:= '+'; Operator =:= '-'; Operator =:= '*' ->
    erl_syntax:infix_expr(Left, erl_syntax:operator(Operator), Right);
binop('/', {tcon, ['Int'], []}, Left, Right, _) ->
    erl_syntax:infix_expr(Left, erl_syntax:operator('div'), Right);
binop('%', {tcon, ['Int'], []}, Left, Right, _) ->
    erl_syntax:infix_expr(Left, erl_syntax:operator('rem'), Right);
binop('<>', {tcon, ['String'], []}, Left, Right, _) -> binary_append(Left, Right);
binop('<>', {tcon, ['Bytes'], []}, Left, Right, _) -> binary_append(Left, Right);
%% Report §9.6: `<>` on a prelude type whose module provides it in Ernest,
%% `List.<>` and `Path.<>`, a call of that module's, and a local call within it
binop('<>', {tcon, [Name], _}, Left, Right, Context) ->
    member_call({named, [Name, '<>']}, [Left, Right], Context);
binop('==', _, Left, Right, _) -> erl_syntax:infix_expr(Left, erl_syntax:operator('=:='), Right);
binop('!=', _, Left, Right, _) -> erl_syntax:infix_expr(Left, erl_syntax:operator('=/='), Right);
binop('&&', _, Left, Right, _) ->
    erl_syntax:infix_expr(Left, erl_syntax:operator('andalso'), Right);
binop('||', _, Left, Right, _) -> erl_syntax:infix_expr(Left, erl_syntax:operator('orelse'), Right);
binop('::', _, Left, Right, _) -> erl_syntax:cons(Left, Right);
binop('<=', _, Left, Right, _) -> erl_syntax:infix_expr(Left, erl_syntax:operator('=<'), Right);
binop(Operator, _, Left, Right, _) when Operator =:= '<'; Operator =:= '>'; Operator =:= '>=' ->
    erl_syntax:infix_expr(Left, erl_syntax:operator(Operator), Right).

%% Report §3.1, §7.4: a Float operation inline, its operands bound first so
%% that only its own badarith becomes the float fault; an Int division by
%% zero inside an operand stays that fault.
float_operation(Operator, Left, Right, LeftName, RightName) ->
    Cause = erl_syntax:string("float arithmetic error"),
    Text = erl_syntax:binary([erl_syntax:binary_field(Cause)]),
    Badarith = erl_syntax:class_qualifier(erl_syntax:atom(error), erl_syntax:atom(badarith)),
    Handler = erl_syntax:clause([Badarith], none, [call_remote(ern_rt, fault, [Text])]),
    Plain = erl_syntax:infix_expr(erl_syntax:variable(LeftName), erl_syntax:operator(Operator),
                                  erl_syntax:variable(RightName)),
    %% report §3.1: under round to nearest a sum or a difference of operands
    %% that are not negative zero is never one, and no operand is; a product
    %% or a quotient may be, and + 0.0 turns it into 0.0 and keeps any other
    Operation = case Operator of
                    _ when Operator =:= '*'; Operator =:= '/' ->
                        erl_syntax:infix_expr(Plain, erl_syntax:operator('+'),
                                              erl_syntax:float(0.0));
                    _ ->
                        Plain
                end,
    erl_syntax:block_expr([erl_syntax:match_expr(erl_syntax:variable(LeftName), Left),
                           erl_syntax:match_expr(erl_syntax:variable(RightName), Right),
                           erl_syntax:try_expr([Operation], [Handler])]).

negate({tcon, ['Float'], []}, Form) ->
    %% report §3.1: 0.0 - x, so that negating 0.0 gives 0.0
    erl_syntax:infix_expr(erl_syntax:float(0.0), erl_syntax:operator('-'), Form);
negate(_, Form) -> erl_syntax:prefix_expr(erl_syntax:operator('-'), Form).

%% Report §4.9: a member applied to its operands, the parameter a
%% requirement's member came in, or a known type's member with its own
%% requirement supplied.
member_applied({required, {variable, Number}, Member}, Args, Context) ->
    Function = erl_syntax:variable(member_variable(Number, Member, Context)),
    {erl_syntax:application(Function, Args), Context};
member_applied({known, Reference, Supplies}, Args, Context) ->
    {SupplyForms, Context1} = supply_forms(Supplies, Context),
    {member_call(Reference, Args ++ SupplyForms, Context1), Context1}.

%% Report §3.10: an ordering is its compare against Less or Greater; any
%% other operator is the member's own result.
ordered(Operator, Compared) ->
    case Operator of
        '<' -> erl_syntax:infix_expr(Compared, erl_syntax:operator('=:='), erl_syntax:atom('Less'));
        '>' -> erl_syntax:infix_expr(Compared, erl_syntax:operator('=:='),
                                     erl_syntax:atom('Greater'));
        '<=' -> erl_syntax:infix_expr(Compared, erl_syntax:operator('=/='),
                                      erl_syntax:atom('Greater'));
        '>=' -> erl_syntax:infix_expr(Compared, erl_syntax:operator('=/='),
                                      erl_syntax:atom('Less'));
        _ -> Compared
    end.

%% <<A/binary, B/binary>>, with a string literal as a plain segment and an
%% inner append flattened, so "a" <> f(x) <> "b" is one binary.
binary_append(Left, Right) ->
    erl_syntax:binary(segments(Left) ++ segments(Right)).

segments(Form) ->
    case erl_syntax:type(Form) of
        binary -> erl_syntax:binary_fields(Form);
        string -> [erl_syntax:binary_field(Form)];
        _ -> [erl_syntax:binary_field(Form, [erl_syntax:atom(binary)])]
    end.

%%
%% Types, report Appendix H: a type a form writes, its references read
%% through the unit's own forms and the link
%%

%% A type as the checker writes it, {tcon, QualifiedName, Args}, each
%% type's name the one it prints with, and each variable its number, for
%% the operations that dispatch on a prelude type and for printing.
checked_type({variable, Number}, _) ->
    {tvar, Number};
checked_type({applied, Reference, Args}, Context) ->
    {tcon, type_name(Reference, Context), [checked_type(Arg, Context) || Arg <- Args]};
checked_type({tuple, Elements}, Context) ->
    {ttuple, [checked_type(Element, Context) || Element <- Elements]};
checked_type({arrow, Params, Effect, Result}, Context) ->
    {tfn, [checked_type(Param, Context) || Param <- Params], checked_type(Effect, Context),
     checked_type(Result, Context)};
checked_type(pure, _) ->
    pure.

%% A type reference's qualified name, as the module prints it: the unit's
%% own type's declaration's, the link's for another unit's, and a name's
%% its own.
type_name(Reference, Context) ->
    {QualifiedName, _} = declared_type(Reference, Context),
    QualifiedName.

%% A type a reference names: its qualified name, and {Arity, Constructors}
%% as its form writes them or foreign; builtin for a type the runtime gives,
%% which has none (report §9.1).
declared_type({named, [Name]} = Reference, Context) ->
    case is_builtin(Name) of
        true -> {[Name], builtin};
        false -> linked_type(Reference, Context)
    end;
declared_type(Reference, #emit_context{own = #own{forms = Forms}} = Context) ->
    case own_position(Reference, Context) of
        {ok, Position} when is_map_key(Position, Forms) ->
            {#definition{qualified_name = QualifiedName},
             {type, _, Arity, _, _, Constructors}} = maps:get(Position, Forms),
            {QualifiedName, {Arity, Constructors}};
        _ ->
            linked_type(Reference, Context)
    end.

linked_type(Reference, #emit_context{unit = #unit{link = #link{types = Types}}}) ->
    case Types of
        #{Reference := Type} -> Type;
        _ -> erlang:error({emitter_defect, none, unlinked(Reference)})
    end.

is_builtin(Name) ->
    lists:member(Name, ['Int', 'Float', 'Bool', 'Char', 'String', 'Bytes', 'Address', 'Reply',
                        'Process', 'Never', 'List', 'Map', 'Set']).

%% The type variables a form holds, each once where it is first met.
type_variables({variable, Number} = Variable) when is_integer(Number) -> [Variable];
type_variables(Term) when is_tuple(Term) -> type_variables(tuple_to_list(Term));
type_variables(Terms) when is_list(Terms) ->
    lists:uniq(lists:append([type_variables(Term) || Term <- Terms]));
type_variables(_) -> [].

%% The type with each of Variables as `Never`.
as_never([], Type) -> Type;
as_never(Variables, {variable, _} = Variable) ->
    case lists:member(Variable, Variables) of
        true -> {applied, {named, ['Never']}, []};
        false -> Variable
    end;
as_never(Variables, Type) when is_tuple(Type) ->
    list_to_tuple([as_never(Variables, Element) || Element <- tuple_to_list(Type)]);
as_never(Variables, Types) when is_list(Types) ->
    [as_never(Variables, Element) || Element <- Types];
as_never(_, Type) -> Type.

%% Report §11.5: a type as the module prints it, a check's cause naming it.
%% Its variables are the definition's, named as §11.5 names a type's
%% variables, each with the restrictions its definition's scheme gives it.
printed(Type, #emit_context{unit = #unit{link = #link{printing = Printing}},
                            restrictions = Restrictions} = Context) ->
    Count = lists:max([0 | [Number || {variable, Number} <- type_variables(Type)]]),
    State = lists:foldl(fun(Number, Acc) ->
                            element(2, ern_types:fresh(Acc, maps:get(Number, Restrictions, [])))
                        end, Printing, lists:seq(1, Count)),
    ern_types:format(checked_type(Type, Context), State).

%%
%% The foreign boundary, report §8.4: a declared type as the term
%% ern_boundary interprets
%%

%% Form's value checked against Type and the fault's text naming Shown
%% (report §7.4, §8.4). A word's check is written in place; a value that
%% holds no function, address or Reply to arm and no float to make the
%% language's is checked alone (ern_boundary:check/3); a type variable a
%% parameter names matches any value, and is not checked.
check_form(Type, Shown, Form, Prefix, Context) ->
    Text = check_text(Prefix, Shown, Context),
    case descriptor(Type, Context) of
        Unchecked when Unchecked =:= any; Unchecked =:= foreign ->
            {Form, Context};
        Word when Word =:= int; Word =:= bool; Word =:= bytes; Word =:= float ->
            {[Variable], Context1} = fresh_variables(1, "Checked", Context),
            VariableForm = erl_syntax:variable(Variable),
            Test = erl_syntax:application(erl_syntax:atom(word_test(Word)), [VariableForm]),
            %% report §3.1: X + 0.0 is 0.0 for either zero, and X otherwise
            Value = case Word of
                        float -> erl_syntax:infix_expr(VariableForm, erl_syntax:operator('+'),
                                                       erl_syntax:float(0.0));
                        _ -> VariableForm
                    end,
            Fault = call_remote(ern_rt, fault, [Text]),
            {erl_syntax:case_expr(Form, [erl_syntax:clause([VariableForm], Test, [Value]),
                                         erl_syntax:clause([erl_syntax:underscore()], none,
                                                           [Fault])]), Context1};
        Word when is_atom(Word) ->
            {call_remote(ern_boundary, value, [erl_syntax:abstract(Word), Form, Text]), Context};
        Descriptor ->
            {DescriptorForm, Context1} = descriptor_form(Descriptor, Context),
            Check = case is_plain(Descriptor) of
                        true -> check;
                        false -> value
                    end,
            {call_remote(ern_boundary, Check, [DescriptorForm, Form, Text]), Context1}
    end.

word_test(int) -> is_integer;
word_test(bool) -> is_boolean;
word_test(bytes) -> is_binary;
word_test(float) -> is_float.

%% Whether a descriptor holds no function, no address, no Reply and no
%% float, as ern_boundary reads one: a checked value of it is the value
%% itself.
is_plain(float) -> false;
is_plain({address, _, _}) -> false;
is_plain({reply, _, _}) -> false;
is_plain({function, _, _, _, _, _}) -> false;
is_plain(Part) when is_tuple(Part) -> lists:all(fun is_plain/1, tuple_to_list(Part));
is_plain(Parts) when is_list(Parts) -> lists:all(fun is_plain/1, Parts);
is_plain(_) -> true.

%% An argument of a foreign function as it is given (§8.4): one with an
%% address inside, through the checker that checks what foreign code sends
%% it, and a Reply foreign code gave back as it gave it; a function,
%% wrapped to check the arguments foreign code calls it with; any other,
%% and every argument of the standard library's own, as it is.
exposed({_, Arg}, #emit_context{unit = #unit{standard = true}} = Context) ->
    {Arg, Context};
exposed({Type, Arg}, Context) ->
    Descriptor = descriptor(Type, Context),
    case crosses(Descriptor) of
        true ->
            {DescriptorForm, Context1} = descriptor_form(Descriptor, Context),
            {call_remote(ern_boundary, expose, [DescriptorForm, Arg]), Context1};
        false ->
            {Arg, Context}
    end.

%% A descriptor as a form: a literal when it is a word, else a call of a
%% unit function that returns it, one per distinct descriptor.
descriptor_form(Descriptor, Context) when is_atom(Descriptor) ->
    {erl_syntax:abstract(Descriptor), Context};
descriptor_form(Descriptor, Context) ->
    case Context#emit_context.descriptors of
        #{Descriptor := Name} ->
            {erl_syntax:application(erl_syntax:atom(Name), []), Context};
        Descriptors ->
            Name = list_to_atom("$type_" ++ integer_to_list(map_size(Descriptors) + 1)),
            Clause = erl_syntax:clause([], none, [built_descriptor(Descriptor)]),
            Function = erl_syntax:function(erl_syntax:atom(Name), [Clause]),
            %% report §11.2: a function's descriptor builds the function
            %% that checks the one crossing, of this unit's code, which the
            %% program holds in its place
            Builds = Context#emit_context.builds_functions orelse holds_function(Descriptor),
            {erl_syntax:application(erl_syntax:atom(Name), []),
             Context#emit_context{descriptors = Descriptors#{Descriptor => Name},
                                  lifted = [Function | Context#emit_context.lifted],
                                  builds_functions = Builds}}
    end.

%% A descriptor as the form that builds it. A function's descriptor also
%% carries the maker of its checked wrapper, a fun of its arity that checks
%% each result (report §7.4), which only generated code can spell for every
%% arity; ern_boundary applies it to a function value foreign code gives,
%% and to the result's descriptor closed over the recursive types around it.
built_descriptor({function, Arity, ResultDescriptor, Text, ParamDescriptors, ParamTexts}) ->
    Function = erl_syntax:variable('Function'),
    Result = erl_syntax:variable('Result'),
    Bound = erl_syntax:variable('Bound'),
    Args = [erl_syntax:variable(list_to_atom("Argument" ++ integer_to_list(Index)))
            || Index <- lists:seq(1, Arity)],
    Check = call_remote(ern_boundary, value,
                        [Result, erl_syntax:application(Function, Args),
                         erl_syntax:abstract(Text)]),
    Wrapper = erl_syntax:fun_expr([erl_syntax:clause(Args, none, [Check])]),
    Maker = erl_syntax:fun_expr([erl_syntax:clause([Function, Result], none, [Wrapper])]),
    %% report §8.4: the same function crossing into foreign code, wherever
    %% it stands in what crosses, each argument checked against its
    %% parameter's type, the recursive types around it in Bound
    Checked = [call_remote(ern_boundary, argument, [built_descriptor(Descriptor), Argument,
                                                    erl_syntax:abstract(ParamText), Bound])
               || {Descriptor, Argument, ParamText}
                      <- lists:zip3(ParamDescriptors, Args, ParamTexts)],
    Exposed = erl_syntax:fun_expr([erl_syntax:clause(Args, none, [called(Function, Checked)])]),
    Exposer = erl_syntax:fun_expr([erl_syntax:clause([Function, Bound], none, [Exposed])]),
    erl_syntax:tuple([erl_syntax:atom('fun'), erl_syntax:integer(Arity),
                      built_descriptor(ResultDescriptor),
                      erl_syntax:abstract(Text), Maker, Exposer]);
built_descriptor(Tuple) when is_tuple(Tuple) ->
    erl_syntax:tuple([built_descriptor(Element) || Element <- tuple_to_list(Tuple)]);
built_descriptor(Elements) when is_list(Elements) ->
    erl_syntax:list([built_descriptor(Element) || Element <- Elements]);
built_descriptor(Other) ->
    erl_syntax:abstract(Other).

%% Report §7.4: the program's Function where foreign code calls it, an
%% exception it raises the fault it would be anywhere (called_raised/3).
called(Function, Arguments) ->
    [Class, Error, Trace] = Raised = [erl_syntax:variable(Name)
                                      || Name <- ['Class', 'Error', 'Trace']],
    Handler = erl_syntax:clause([erl_syntax:class_qualifier(Class, Error, Trace)], none,
                                [call_remote(ern_boundary, called_raised, Raised)]),
    erl_syntax:try_expr([erl_syntax:application(Function, Arguments)], [Handler]).

check_text(Prefix, Type, Context) ->
    string_binary(cause(Prefix, Type, Context)).

%% Report §7.4, §8.4: a check's cause, its Prefix and the type as §11.5
%% prints it, which the boundary faults with.
cause(Prefix, Type, Context) ->
    unicode:characters_to_binary(Prefix ++ printed(Type, Context)).

%% Whether a descriptor holds what crossing into foreign code changes: an
%% address, a Reply, or a function.
crosses({address, _, _}) -> true;
crosses({reply, _, _}) -> true;
crosses({function, _, _, _, _, _}) -> true;
crosses(Part) when is_tuple(Part) -> lists:any(fun crosses/1, tuple_to_list(Part));
crosses(Parts) when is_list(Parts) -> lists:any(fun crosses/1, Parts);
crosses(_) -> false.

%% Report §8.4, Appendix E.1: the descriptor of a type a form writes
%% (ern_descriptor's descriptor()), as the runtime reads it for the
%% boundary and for `show`.
descriptor(Type, Context) ->
    describe(Type, [], [], Context).

%% The descriptor of Type, each variable of Holes `{hole, Number}`, whose
%% descriptor the program passes in under a requirement that names `show`
%% (report §4.9, Appendix E.1), and any other any; each type Abstract
%% names, which `show` prints as `<abstract>` from the module (the form's
%% view, Appendix H), wrapped. A recursive type refers back to its mu.
describe(Type, Holes, Abstract, Context) ->
    described(Type, #{}, {Holes, Abstract}, Context).

%% Seen maps each type enclosing the one being described to the id its mu
%% binds, so a recursive type refers back instead of unfolding; it is
%% passed down alone, and a sibling is described in full, since a ref
%% reaches only an enclosing mu.
described({variable, Number}, _, {Holes, _}, _) ->
    case lists:member(Number, Holes) of
        true -> {hole, Number};
        false -> any
    end;
described(pure, _, _, _) -> any;
described({tuple, Elements}, Seen, Scope, Context) ->
    {tuple, all_described(Elements, Seen, Scope, Context)};
described({arrow, Params, _, Result}, Seen, Scope, Context) ->
    %% report §7.4: a function value from foreign code has its result
    %% checked at each call, against the result's descriptor; report §8.4:
    %% one that crosses into foreign code has each argument checked, against
    %% its parameter's
    {function, length(Params), described(Result, Seen, Scope, Context),
     cause("foreign return does not match ", Result, Context),
     all_described(Params, Seen, Scope, Context),
     [cause("foreign argument does not match ", Param, Context) || Param <- Params]};
described({applied, {named, ['Int']}, []}, _, _, _) -> int;
described({applied, {named, ['Float']}, []}, _, _, _) -> float;
described({applied, {named, ['Bool']}, []}, _, _, _) -> bool;
described({applied, {named, ['Char']}, []}, _, _, _) -> char;
described({applied, {named, ['String']}, []}, _, _, _) -> string;
described({applied, {named, ['Bytes']}, []}, _, _, _) -> bytes;
described({applied, {named, ['Address']}, [MessageType]}, Seen, Scope, Context) ->
    %% the address's messages, for the checker that exposes it (report §8.4)
    {address, described(MessageType, Seen, Scope, Context),
     cause("message does not match ", MessageType, Context)};
described({applied, {named, ['Reply']}, [AnswerType]}, Seen, Scope, Context) ->
    %% the answer's, which a reply that crosses into foreign code is
    %% checked against (report §8.4)
    {reply, described(AnswerType, Seen, Scope, Context),
     cause("reply does not match ", AnswerType, Context)};
described({applied, {named, ['Process']}, []}, _, _, _) -> process;
described({applied, {named, ['Never']}, []}, _, _, _) -> never;
described({applied, {named, ['List']}, [ElementType]}, Seen, Scope, Context) ->
    {list, described(ElementType, Seen, Scope, Context)};
described({applied, {named, ['Map']}, [KeyType, ValueType]}, Seen, Scope, Context) ->
    {map, described(KeyType, Seen, Scope, Context), described(ValueType, Seen, Scope, Context)};
described({applied, {named, ['Set']}, [ElementType]}, Seen, Scope, Context) ->
    {set, described(ElementType, Seen, Scope, Context)};
described({applied, Reference, Args} = Type, Seen, {_, Abstract} = Scope, Context) ->
    case Seen of
        #{Type := Id} ->
            {ref, Id};
        _ ->
            case declared_type(Reference, Context) of
                {_, foreign} ->
                    %% report §8.4, Appendix E.1: unchecked, as a type
                    %% variable is, and shown as `<foreign>`
                    foreign;
                {_, {_, Constructors}} ->
                    Id = map_size(Seen) + 1,
                    Sum = {con, [constructor_descriptor(Name, Fields,
                                                        all_described(field_types(Fields, Args),
                                                                      Seen#{Type => Id}, Scope,
                                                                      Context))
                                 || {Name, Fields} <- Constructors]},
                    Descriptor = case refers(Sum, Id) of
                                     true -> {mu, Id, Sum};
                                     false -> Sum
                                 end,
                    %% report §4.4, Appendix E.1: seen from outside its
                    %% module, an abstract type's representation is not the
                    %% program's to print
                    case lists:member(Reference, Abstract) of
                        true -> {abstract, Descriptor};
                        false -> Descriptor
                    end
            end
    end.

all_described(Types, Seen, Scope, Context) ->
    [described(Type, Seen, Scope, Context) || Type <- Types].

%% A named constructor's descriptor keeps its fields' names, in declared
%% order (report §3.5), for printing.
constructor_descriptor(Tag, {named, Fields}, FieldDescriptors) ->
    {Tag, FieldDescriptors, [Field || {Field, _} <- Fields]};
constructor_descriptor(Tag, _, FieldDescriptors) ->
    {Tag, FieldDescriptors}.

%% A constructor's field types at the type's arguments, its parameters the
%% variables 1 to its arity (Appendix H).
field_types(none, _) -> [];
field_types({positional, Type}, Args) -> [instance(Type, Args)];
field_types({named, Fields}, Args) -> [instance(Type, Args) || {_, Type} <- Fields].

instance({variable, Number}, Args) -> lists:nth(Number, Args);
instance(Type, Args) when is_tuple(Type) ->
    list_to_tuple([instance(Part, Args) || Part <- tuple_to_list(Type)]);
instance(Types, Args) when is_list(Types) -> [instance(Type, Args) || Type <- Types];
instance(Type, _) -> Type.

refers({ref, Id}, Id) -> true;
refers(Part, Id) when is_tuple(Part) ->
    lists:any(fun(Inner) -> refers(Inner, Id) end, tuple_to_list(Part));
refers(Parts, Id) when is_list(Parts) -> lists:any(fun(Inner) -> refers(Inner, Id) end, Parts);
refers(_, _) -> false.

%%
%% Constructors, report §8.4
%%

%% A constructor a form writes, its type's reference and its position among
%% the type's constructors (Appendix H): its tag and its fields.
constructor_at({constructor, Reference, Position}, Context) ->
    {_, {_, Constructors}} = declared_type(Reference, Context),
    lists:nth(Position, Constructors).

%% Report §3.5, §8.4: a selected field. A named constructor is its tag and
%% its fields in declared order, so the field is one element of the tuple
%% where every constructor has it at one place, and a case on the tag where
%% the places differ.
select(Field, Reference, Form, Context) ->
    {_, {_, Constructors}} = declared_type(Reference, Context),
    Places = [{ConstructorName, place(Field, [Name || {Name, _} <- Fields]) + 1, length(Fields)}
              || {ConstructorName, {named, Fields}} <- Constructors],
    case lists:usort([Index || {_, Index, _} <- Places]) of
        [Index] ->
            {call_remote(erlang, element, [erl_syntax:integer(Index), Form]), Context};
        _ ->
            {[Variable], Context1} = fresh_variables(1, "Field", Context),
            VariableForm = erl_syntax:variable(Variable),
            Clauses = [erl_syntax:clause([selecting_pattern(ConstructorName, Index, Count,
                                                            VariableForm)],
                                         none, [VariableForm])
                       || {ConstructorName, Index, Count} <- Places],
            {erl_syntax:case_expr(Form, Clauses), Context1}
    end.

%% A named constructor's tuple as a pattern, the field at Index bound to the
%% variable and the others `_`.
selecting_pattern(ConstructorName, Index, Count, VariableForm) ->
    Fields = [case Place of
                  Index -> VariableForm;
                  _ -> erl_syntax:underscore()
              end || Place <- lists:seq(2, Count + 1)],
    erl_syntax:tuple([erl_syntax:atom(ConstructorName) | Fields]).

place(Field, [Field | _]) -> 1;
place(Field, [_ | Rest]) -> 1 + place(Field, Rest).

constructor_expr(Constructor, Arguments, Context) ->
    {Name, Fields} = constructor_at(Constructor, Context),
    Tag = erl_syntax:atom(Name),
    case {Fields, Arguments} of
        {none, none} ->
            {Tag, Context};
        {{positional, _}, none} ->
            %% as a function value
            {[Variable], Context1} = fresh_variables(1, "Argument", Context),
            VariableForm = erl_syntax:variable(Variable),
            Wrap = erl_syntax:clause([VariableForm], none, [erl_syntax:tuple([Tag, VariableForm])]),
            {erl_syntax:fun_expr([Wrap]), Context1#emit_context{builds_functions = true}};
        {{positional, _}, {positional, Arg}} ->
            {Form, Context1} = expr(Arg, Context),
            {erl_syntax:tuple([Tag, Form]), Context1};
        {{named, Declared}, {named, none, FieldSets}} ->
            Names = [FieldName || {FieldName, _} <- Declared],
            {Bindings, ByName, Context1} = field_sets(Names, FieldSets, Context),
            Tuple = erl_syntax:tuple([Tag | [maps:get(FieldName, ByName) || FieldName <- Names]]),
            {with_bindings(Bindings, Tuple), Context1};
        {{named, Declared}, {named, Base, FieldSets}} ->
            %% T(..base, f = e): bind the base to a tuple pattern, take the
            %% unlisted fields from it
            Names = [FieldName || {FieldName, _} <- Declared],
            {Bind, BaseFields, Context1} = base_bound(Tag, Base, length(Names), Context),
            {Bindings, ByName, Context2} = field_sets(Names, FieldSets, Context1),
            Forms = [maps:get(FieldName, ByName, BaseField)
                     || {FieldName, BaseField} <- lists:zip(Names, BaseFields)],
            {with_bindings([Bind | Bindings], erl_syntax:tuple([Tag | Forms])), Context2};
        _ ->
            fail(none, "constructor " ++ atom_to_list(Name) ++ " used with the wrong field shape,"
                       " which the checker refuses")
    end.

%% The base of an update matched against its constructor's tuple of Count
%% fields: the match, and a variable for each field.
base_bound(Tag, Base, Count, Context) ->
    {BaseForm, Context1} = expr(Base, Context),
    {Variables, Context2} = fresh_variables(Count, "Base", Context1),
    BaseFields = [erl_syntax:variable(Variable) || Variable <- Variables],
    {erl_syntax:match_expr(erl_syntax:tuple([Tag | BaseFields]), BaseForm), BaseFields, Context2}.

%% Report §3.5, §5.1: named fields are stored in declared order and
%% evaluated in the order written. Where the two differ, each field is
%% bound to a variable first, as written. The field forms by name, and
%% the bindings that go before the tuple.
field_sets(Names, FieldSets, Context) ->
    {Forms, Context1} = lists:mapfoldl(fun({field, _, Expr}, Acc) -> expr(Expr, Acc) end,
                                       Context, FieldSets),
    Written = [Name || {field, Name, _} <- FieldSets],
    case [Name || Name <- Names, lists:member(Name, Written)] of
        Written ->
            {[], maps:from_list(lists:zip(Written, Forms)), Context1};
        _ ->
            {Variables, Context2} = fresh_variables(length(FieldSets), "Field", Context1),
            VariableForms = [erl_syntax:variable(Variable) || Variable <- Variables],
            Bindings = [erl_syntax:match_expr(VariableForm, Form)
                        || {VariableForm, Form} <- lists:zip(VariableForms, Forms)],
            {Bindings, maps:from_list(lists:zip(Written, VariableForms)), Context2}
    end.

%%
%% A spawn on a peer, and a compute, report §8.7 and §3.11
%%

peer_spawn(Source, Name, Held, PeerName, Spawned, Rest, Context) ->
    {PeerForm, Context1} = expr(PeerName, Context),
    {SpawnedForm, Replies, Context2} = spawned(Spawned, Held, Context1),
    {RestForms, Context3} = exprs(Rest, Context2),
    {Function, Kept} = case Name of
                           spawn -> {spawn, [erl_syntax:list(Replies)]};
                           spawnMonitored -> {spawn_monitored, [erl_syntax:list(Replies)]};
                           compute -> {compute, []}
                       end,
    {call_remote(ern_peer, Function,
                 [PeerForm, SpawnedForm | RestForms] ++ [site(Source, Context) | Kept]),
     Context3}.

%% The function a spawn on a peer starts, or a compute runs, as its frame
%% names it in place of the function: a declaration by its identity,
%% `{function, Hash}`, or a foreign one by its qualified name, `{foreign,
%% Names}`, its names as text so that a peer that lacks it makes no atom of
%% them; a lambda or a local fn by its identity and the values it captured,
%% in the order its body first names them, `{lambda, Hash, Position,
%% Captures}`, an entry of this unit running it over them; and
%% `restarting` over one of these with its limit, `{restarting, Limit,
%% Spawned}`. The checker admitted only these (ern_bound). Beside the form,
%% the captures that carry a reply, each the variable in force at it with
%% its type's descriptor, which a spawn that fails reads the replies it
%% holds by and ends their calls, looking through no other value (ern_peer):
%% Held, which the form of the spawn holds (Appendix H).
spawned(Spawned, Held, Context) ->
    {_, Node} = sourced(Spawned),
    spawned_node(Node, Spawned, Held, Context).

spawned_node({call, Callee, [Limit, Function]}, _, Held, Context) ->
    case sourced(Callee) of
        {_, {var, {named, [restarting]}, []}} ->
            {LimitForm, Context1} = expr(Limit, Context),
            {Inner, Replies, Context2} = spawned(Function, Held, Context1),
            {erl_syntax:tuple([erl_syntax:atom(restarting), LimitForm, Inner]), Replies,
             Context2};
        _ ->
            fail(none, "a spawn on a peer starts a function the checker refuses")
    end;
spawned_node({lambda, _, _, _, _, _}, Lambda, Held,
             #emit_context{variables = Variables} = Context) ->
    spawned_lambda(Lambda, Variables, Held, Context);
spawned_node({var, {local, Number}, _}, _, Held,
             #emit_context{variables = Variables, locals = Locals,
                           let_lambdas = LetLambdas} = Context) ->
    case {Variables, Locals} of
        {#{Number := Variable}, _} ->
            case LetLambdas of
                #{Variable := {Lambda, Before}} -> spawned_lambda(Lambda, Before, Held, Context);
                _ -> fail(none, "a spawn on a peer starts a local that names no lambda")
            end;
        {_, #{Number := Local}} ->
            spawned_local(Number, Local, Context)
    end;
spawned_node({var, {foreign, QualifiedName, _}, _}, _, _, Context) ->
    {foreign_identity(QualifiedName), [], Context};
spawned_node({var, {hash, Hash}, _}, _, _, Context) ->
    {erl_syntax:abstract({function, Hash}), [], Context};
spawned_node({var, {named, QualifiedName} = Reference, _}, _, _, Context) ->
    case linked(Reference, Context) of
        #linked{identity = foreign} -> {foreign_identity(QualifiedName), [], Context};
        #linked{identity = Hash} -> {erl_syntax:abstract({function, Hash}), [], Context}
    end;
spawned_node(_, _, _, _Context) ->
    fail(none, "a spawn on a peer starts a function the checker refuses").

foreign_identity(QualifiedName) ->
    erl_syntax:abstract({foreign, [atom_to_binary(Part) || Part <- QualifiedName]}).

%% A lambda a spawn on a peer starts, its captures the variables in force
%% at it, Scope.
spawned_lambda(Lambda, Scope, Held, Context) ->
    {Source, {lambda, Position, _, _, _, Body} = Node} = sourced(Lambda),
    Captures = captures(Node),
    Context1 = entry(Position, length(Captures),
                     fun(Function, Acc) -> lambda_entry(Function, Body, Source, Captures, Acc) end,
                     Context),
    {spawned_identity(Position, [variable_form(maps:get(Number, Scope)) || Number <- Captures],
                      Context1),
     held_replies(Held, Scope, Context1), Context1}.

%% A local fn a spawn on a peer starts, its captures the variables in force
%% at its declaration, or at the spawn where it comes first (report §5.4).
%% A local fn captures no reply (§6.6).
spawned_local(Number, #local_fn{snapshot = Snapshot, function = Function,
                                position = Position} = Local,
              #emit_context{variables = Variables} = Context) ->
    Captures = captures(Function) -- [Number],
    Scope = case Snapshot of
                pending -> Variables;
                _ -> Snapshot
            end,
    Context1 = entry(Position, length(Captures),
                     fun(Entry, Acc) -> local_entry(Entry, Number, Local, Captures, Scope, Acc) end,
                     Context),
    {spawned_identity(Position, [variable_form(maps:get(Captured, Scope))
                                 || Captured <- Captures],
                      Context1),
     [], Context1}.

%% Report §6.6, §8.7: each held capture, the variable in force at it with
%% its type's descriptor.
held_replies(Held, Scope, Context) ->
    [erl_syntax:tuple([variable_form(maps:get(Number, Scope)),
                       erl_syntax:abstract(descriptor(Type, Context))])
     || {Number, Type} <- Held].

%% The frame's identity of the lambda or local fn at Position, and its
%% captures.
spawned_identity(Position, CaptureForms, #emit_context{definition = {_, Hash, _}}) ->
    erl_syntax:tuple([erl_syntax:atom(lambda), erl_syntax:abstract(Hash),
                      erl_syntax:integer(Position), erl_syntax:list(CaptureForms)]).

%% Report §8.7, §11.1: the entry of the lambda or local fn at Position, made
%% once however many spawns name it: a function of the unit, named by its
%% definition's position and its own, that takes its captures and runs
%% it, which '$spawned'/2 and '$code'/0 list under its identity.
entry(Position, Arity, Made,
      #emit_context{entries = Entries,
                    definition = {Definition, Hash, QualifiedName}} = Context) ->
    Key = {Definition, Position},
    case Entries of
        #{Key := _} ->
            Context;
        _ ->
            Function = entry_name(Definition, Position),
            Entry = #entry{function = Function, arity = Arity, qualified_name = QualifiedName,
                           hash = Hash, position = Position},
            Made(Function, Context#emit_context{entries = Entries#{Key => Entry}})
    end.

%% A lambda's entry: its body over its captures, each a fresh variable, in
%% a scope of its own.
lambda_entry(Function, Body, Source, Captures,
             #emit_context{variables = Variables, locals = Locals, members = Members,
                           let_lambdas = LetLambdas} = Context) ->
    {Parameters, Context1} = named_variables(["Capture" || _ <- Captures], Context),
    Inner = Context1#emit_context{variables = maps:from_list(lists:zip(Captures, Parameters)),
                                  locals = #{}, members = #{}, let_lambdas = #{}},
    {BodyForms, Context2} = body(Body, Inner),
    Clause = at(Source, erl_syntax:clause([erl_syntax:variable(Parameter)
                                           || Parameter <- Parameters], none, BodyForms)),
    Entry = at(Source, erl_syntax:function(erl_syntax:atom(Function), [Clause])),
    Context2#emit_context{variables = Variables, locals = Locals, members = Members,
                          let_lambdas = LetLambdas,
                          lifted = [entry_comment(Entry, Context) | Context2#emit_context.lifted]}.

%% A local fn's entry: its lifted function called with what it closes
%% over, which are its captures, each the variable in force at its
%% declaration, Scope; nothing else, since a spawn of one that closes over a
%% local fn or a requirement's member is refused (report §3.11).
local_entry(Function, Number, #local_fn{lifted_name = LiftedName}, Captures, Scope, Context) ->
    Parameters = [erl_syntax:variable(variable_atom(maps:get(Captured, Scope)))
                  || Captured <- Captures],
    Call = erl_syntax:application(erl_syntax:atom(LiftedName),
                                  [erl_syntax:variable(Variable)
                                   || Variable <- captured_variables(Number, Context)]),
    Entry = erl_syntax:function(erl_syntax:atom(Function),
                                [erl_syntax:clause(Parameters, none, [Call])]),
    Context#emit_context{lifted = [entry_comment(Entry, Context) | Context#emit_context.lifted]}.

entry_comment(Entry, #emit_context{definition = {_, _, QualifiedName}}) ->
    with_comment(Entry, "the entry of a function of " ++ ern_namespace:text(QualifiedName)
                        ++ " a spawn on a peer starts").

%% Report §3.11: a `let` of a lambda, by the variable it binds, with the
%% variables in force at the lambda, which a spawn on a peer that names it
%% captures from.
let_lambda(Pattern, Expr, #emit_context{variables = Before},
           #emit_context{variables = Variables, let_lambdas = LetLambdas} = Context) ->
    case {sourced(Pattern), sourced(Expr)} of
        {{_, {local, Number}}, {_, {lambda, _, _, _, _, _}}} ->
            #{Number := Variable} = Variables,
            Context#emit_context{let_lambdas = LetLambdas#{Variable => {Expr, Before}}};
        _ ->
            Context
    end.

%% Report §3.11, Appendix H: the locals a lambda's or a local fn's form
%% names and does not bind, each once, in the order it first names them,
%% which is the order its spawn's frame carries them in and its entry takes
%% them.
captures(Node) ->
    {Uses, Bound} = locals_named(Node, {[], []}),
    lists:uniq([Number || Number <- lists:reverse(Uses), not lists:member(Number, Bound)]).

%% The locals a form names, reversed, and those it binds.
locals_named({var, {local, Number}, _}, {Uses, Bound}) ->
    {[Number | Uses], Bound};
locals_named({var, {local, Number}, _, _}, {Uses, Bound}) ->
    {[Number | Uses], Bound};
locals_named({local, Number}, {Uses, Bound}) when is_integer(Number) ->
    {Uses, [Number | Bound]};
locals_named({local_fn, Number, _, Function}, {Uses, Bound}) ->
    locals_named(Function, {Uses, [Number | Bound]});
locals_named(Term, Acc) when is_tuple(Term) ->
    locals_named(tuple_to_list(Term), Acc);
locals_named(Terms, Acc) when is_list(Terms) ->
    lists:foldl(fun locals_named/2, Acc, Terms);
locals_named(_, Acc) ->
    Acc.

%%
%% Blocks, report §5.4 and §5.5, with local fns lifted
%%

%% A local fn becomes a unit function whose leading parameters are the
%% Erlang variables it closes over: for each free local of its body, the
%% variable in force at its declaration (report §5.4, §4.6), and, through
%% the local fns it references, theirs. A use before the declaration
%% resolves against the variables in force at the use, which §5.4 makes
%% the same ones. Bodies are emitted when the block ends, every
%% declaration passed.

block(Statements, Context) ->
    Fns = [Statement || Statement <- Statements, is_marked_local_fn(Statement)],
    Context1 = declare_locals(Fns, Statements, Context),
    {Forms, Context2} = statements(Statements, Context1, []),
    {Forms, emit_locals(Fns, Context2)}.

is_marked_local_fn(Statement) ->
    case sourced(Statement) of
        {_, {local_fn, _, _, _}} -> true;
        _ -> false
    end.

%% A block that ends in a `let`, `=` or `<-`, the checker refuses (report
%% §5.4); this guards the emitter alone.
statements([Last], Context, Acc) ->
    case sourced(Last) of
        {Source, {bind, _, _, _}} ->
            fail(Source, "a block ends with a `let`");
        {Source, {unwrap, _, _, _, _}} ->
            fail(Source, "a block ends with a `let`");
        _ ->
            {Form, Context1} = expr(Last, Context),
            {lists:reverse([Form | Acc]), Context1}
    end;
statements([Statement | Rest], Context, Acc) ->
    case sourced(Statement) of
        {_, {local_fn, Number, _, _}} ->
            #emit_context{locals = Locals, variables = Variables} = Context,
            Local = (maps:get(Number, Locals))#local_fn{snapshot = Variables},
            statements(Rest, Context#emit_context{locals = Locals#{Number => Local}}, Acc);
        {Source, {bind, _, Expr, Pattern}} ->
            {ExprForm, Context1} = expr(Expr, Context),
            {PatternForm, Context2} = pattern(Pattern, Context1),
            Context3 = let_lambda(Pattern, Expr, Context, Context2),
            statements(Rest, Context3,
                       [at(Source, erl_syntax:match_expr(PatternForm, ExprForm)) | Acc]);
        {Source, {unwrap, {named, [Sum]}, _, Expr, Pattern}} ->
            %% report §5.5
            {ExprForm, Context1} = expr(Expr, Context),
            {Clauses, Context2} = unwrapping_clauses(Source, Sum, Pattern, Rest, Context1),
            {lists:reverse([at(Source, erl_syntax:case_expr(ExprForm, Clauses)) | Acc]),
             Context2};
        _ ->
            {Form, Context1} = expr(Statement, Context),
            statements(Rest, Context1, [Form | Acc])
    end.

%% Report §5.5: the clauses of `let p <- e` on e's value: a Left or None
%% is the block's value, and the rest of the block runs on the value p
%% matches.
unwrapping_clauses(_, 'Either', Pattern, Rest, Context) ->
    {[LeftName], Context1} = fresh_variables(1, "Left", Context),
    Left = erl_syntax:tuple([erl_syntax:atom('Left'), erl_syntax:variable(LeftName)]),
    {Right, Context2} = unwrapped('Right', Pattern, Rest, Context1),
    {[erl_syntax:clause([Left], none, [Left]), Right], Context2};
unwrapping_clauses(_, 'Optional', Pattern, Rest, Context) ->
    None = erl_syntax:atom('None'),
    {Some, Context1} = unwrapped('Some', Pattern, Rest, Context),
    {[erl_syntax:clause([None], none, [None]), Some], Context1};
unwrapping_clauses(Source, _, _, _, _) ->
    fail(Source, "`<-` on a value that is neither Either nor Optional").

%% The clause on Tag(p) that runs the rest of the block.
unwrapped(Tag, Pattern, Rest, Context) ->
    {PatternForm, Context1} = pattern(Pattern, Context),
    {RestForms, Context2} = statements(Rest, Context1, []),
    Wrapped = erl_syntax:tuple([erl_syntax:atom(Tag), PatternForm]),
    {erl_syntax:clause([Wrapped], none, RestForms), Context2}.

declare_locals([], _Statements, Context) ->
    Context;
declare_locals(Fns, Statements, #emit_context{locals = Locals} = Context) ->
    Numbers = [Number || Fn <- Fns, {_, {local_fn, Number, _, _}} <- [sourced(Fn)]],
    BlockLets = lists:append([pattern_numbers(Pattern)
                              || Statement <- Statements,
                                 Pattern <- statement_pattern(element(2, sourced(Statement)))]),
    Declared = [declared_local(Fn, Numbers, BlockLets, Context) || Fn <- Fns],
    Context#emit_context{locals = maps:merge(Locals, maps:from_list(Declared))}.

statement_pattern({bind, _, _, Pattern}) -> [Pattern];
statement_pattern({unwrap, _, _, _, Pattern}) -> [Pattern];
statement_pattern(_) -> [].

%% A local fn of the block whose fns are Numbers, as its #local_fn{}, from
%% the scope the block opens in, Context. Its free locals are those its
%% form names and does not bind, its own number among them where it calls
%% itself: the block's fns it references, the locals of the scope or the
%% block's lets it captures, and the enclosing blocks' fns, whose captures
%% it closes over in turn (report §4.2, §5.4).
declared_local(Fn, Numbers, BlockLets,
               #emit_context{variables = Variables, locals = Locals,
                             definition = {Definition, _, _}} = Context) ->
    {Source, {local_fn, Number, Position, {function, _, _, _, _, Needs, Body} = Function}} =
        sourced(Fn),
    Free = lists:usort(captures(Function)),
    References = [Free1 || Free1 <- Free, lists:member(Free1, Numbers)],
    Captured = [Free1 || Free1 <- Free, not lists:member(Free1, Numbers),
                         is_map_key(Free1, Variables) orelse lists:member(Free1, BlockLets)],
    Enclosing = lists:append([captured_variables(Free1, Context)
                              || Free1 <- Free, not lists:member(Free1, Numbers),
                                 not lists:member(Free1, Captured), is_map_key(Free1, Locals)]),
    {Number, #local_fn{lifted_name = lifted_name(Definition, Position), captured = Captured,
                       enclosing = lists:usort(Enclosing), references = References,
                       members = enclosing_members(Body, Needs, Context), function = Function,
                       position = Position, source = Source}}.

%% Report §4.9: the parameters of the enclosing requirements' members a
%% local fn's body uses, which it closes over, its own requirement's aside.
enclosing_members(Body, Needs, #emit_context{members = Members}) ->
    Own = [{Number, Member} || {needs, {variable, Number}, Member} <- Needs],
    Used = required(Body, []),
    lists:usort([maps:get(Key, Members) || Key <- Used, not lists:member(Key, Own),
                                           is_map_key(Key, Members)]).

%% The members of requirements a form names, each {Number, Member}.
required({required, {variable, Number}, Member}, Acc) ->
    [{Number, Member} | Acc];
required(Term, Acc) when is_tuple(Term) ->
    required(tuple_to_list(Term), Acc);
required(Terms, Acc) when is_list(Terms) ->
    lists:foldl(fun required/2, Acc, Terms);
required(_, Acc) ->
    Acc.

%% The Erlang variables a local fn closes over, which its lifted function
%% takes first, in order, each once.
captured_variables(Number, #emit_context{locals = Locals, variables = Variables}) ->
    lists:usort(captured_variables([Number], Locals, Variables, [], [])).

captured_variables([], _Locals, _Variables, _Seen, Acc) ->
    Acc;
captured_variables([Number | Rest], Locals, Variables, Seen, Acc) ->
    case lists:member(Number, Seen) of
        true ->
            captured_variables(Rest, Locals, Variables, Seen, Acc);
        false ->
            #local_fn{captured = Captured, enclosing = Enclosing, references = References,
                      members = Members, snapshot = Snapshot} = maps:get(Number, Locals),
            Scope = case Snapshot of pending -> Variables; _ -> Snapshot end,
            Found = [variable_atom(maps:get(CapturedNumber, Scope))
                     || CapturedNumber <- Captured]
                ++ Enclosing
                ++ Members,
            captured_variables(References ++ Rest, Locals, Variables, [Number | Seen],
                               Found ++ Acc)
    end.

%% The lifted functions of a block, once every declaration has passed.
emit_locals(Fns, Context) ->
    lists:foldl(fun emit_local/2, Context, Fns).

emit_local(Fn, #emit_context{variables = Variables, locals = Locals, members = Members,
                             definition = {_, _, QualifiedName}} = Context) ->
    {Source, {local_fn, Number, _, {function, _, Params, _, _, Needs, Body}}} = sourced(Fn),
    #local_fn{lifted_name = LiftedName, captured = Captured, snapshot = Snapshot} =
        maps:get(Number, Locals),
    Captures = captured_variables(Number, Context),
    CapturedVariables = maps:from_list([{CapturedNumber, maps:get(CapturedNumber, Snapshot)}
                                       || CapturedNumber <- Captured]),
    {Head, Context1} = head_patterns(Params, Needs,
                                     Context#emit_context{variables = CapturedVariables}),
    {BodyForms, Context2} = body(Body, Context1),
    Clause = at(Source, erl_syntax:clause([erl_syntax:variable(Variable) || Variable <- Captures]
                                          ++ Head, none, BodyForms)),
    Function = at(Source, erl_syntax:function(erl_syntax:atom(LiftedName), [Clause])),
    Text = "a local function of " ++ ern_namespace:text(QualifiedName)
        ++ case local_name(Source) of
               none -> "";
               Name -> ", " ++ atom_to_list(Name)
           end,
    Context2#emit_context{variables = Variables, members = Members,
                          lifted = [with_comment(Function, Text) | Context2#emit_context.lifted]}.

%% The locals a pattern binds, in the order it binds them.
pattern_numbers(Pattern) ->
    {_, Bound} = locals_named(Pattern, {[], []}),
    lists:reverse(Bound).

%%
%% match and receive clauses
%%

%% A clause whose guard is not an Erlang guard expression falls through by
%% a continuation over the remaining clauses (report §5.9).
match_clauses(ScrutineeForm, Clauses, Context) ->
    InScope = maps:keys(Context#emit_context.variables),
    HasErlangGuard = fun(Clause) ->
                             {_, {clause, Pattern, Guard, _}} = sourced(Clause),
                             Guard =:= none
                                 orelse is_erlang_guard(Guard, pattern_numbers(Pattern) ++ InScope)
                     end,
    case lists:all(HasErlangGuard, Clauses) of
        true ->
            {Parts, Context1} = lists:mapfoldl(fun simple_clauses/2, Context, Clauses),
            {Bindings, Forms} = join_parts(Parts),
            {with_bindings(Bindings, erl_syntax:case_expr(ScrutineeForm, Forms)), Context1};
        false ->
            {[ScrutineeName], Context1} = fresh_variables(1, "Scrutinee", Context),
            Scrutinee = erl_syntax:variable(ScrutineeName),
            {Body, Context2} = general_clauses(Scrutinee, Clauses, Context1),
            {erl_syntax:block_expr([erl_syntax:match_expr(Scrutinee, ScrutineeForm), Body]),
             Context2}
    end.

general_clauses(Scrutinee, [Clause | Rest], #emit_context{variables = Variables} = Context) ->
    {Source, {clause, Pattern, Guard, ClauseBody}} = sourced(Clause),
    case {sourced(Pattern), Rest} of
        {{_, {alternatives, _}}, _} ->
            {RestBind, Fallthrough, Context1} = rest_fun(Scrutinee, Rest, Context),
            MakeClause = fun(AlternativeSource, PatternForm, AlternativeGuard, Call, Acc) ->
                             PatternGuard = joined_guard(none, Acc),
                             case AlternativeGuard of
                                 none ->
                                     {at(AlternativeSource,
                                         erl_syntax:clause([PatternForm], PatternGuard, Call)),
                                      Acc};
                                 _ ->
                                     {GuardForm, Acc1} = expr(AlternativeGuard, Acc),
                                     Test = guard_test(GuardForm, Call, Fallthrough),
                                     {at(AlternativeSource,
                                         erl_syntax:clause([PatternForm], PatternGuard, [Test])),
                                      Acc1}
                             end
                         end,
            {{Bindings, Forms}, Context2} = alternatives(Clause, MakeClause, Context1),
            Otherwise = erl_syntax:clause([erl_syntax:underscore()], none, [Fallthrough]),
            Case = erl_syntax:case_expr(Scrutinee, Forms ++ [Otherwise]),
            {erl_syntax:block_expr([RestBind | Bindings] ++ [Case]),
             Context2#emit_context{variables = Variables}};
        {_, []} when Guard =:= none ->
            {PatternForm, PatternGuard, Context1} = clause_head(Pattern, none, Context),
            {BodyForms, Context2} = body(ClauseBody, Context1),
            ClauseForm = erl_syntax:clause([PatternForm], PatternGuard, BodyForms),
            {erl_syntax:case_expr(Scrutinee, [ClauseForm]),
             Context2#emit_context{variables = Variables}};
        _ ->
            {Bind, Fallthrough, Context1} = rest_fun(Scrutinee, Rest, Context),
            {ClauseForm, Context2} = general_clause(Source, Pattern, Guard, ClauseBody,
                                                    Fallthrough, Context1),
            Otherwise = erl_syntax:clause([erl_syntax:underscore()], none, [Fallthrough]),
            Case = erl_syntax:case_expr(Scrutinee, [ClauseForm, Otherwise]),
            {erl_syntax:block_expr([Bind, Case]), Context2#emit_context{variables = Variables}}
    end.

%% A clause that falls through: its pattern, with the guard the pattern
%% asks for, and its body behind its own guard, if any.
general_clause(_Source, Pattern, Guard, ClauseBody, Fallthrough, Context) ->
    {PatternForm, PatternGuard, Context1} = clause_head(Pattern, none, Context),
    {Body, Context2} = case Guard of
                           none ->
                               body(ClauseBody, Context1);
                           _ ->
                               guarded_body(Guard, ClauseBody, Fallthrough, Context1)
                       end,
    {erl_syntax:clause([PatternForm], PatternGuard, Body), Context2}.

guarded_body(Guard, ClauseBody, Fallthrough, Context) ->
    {GuardForm, Context1} = expr(Guard, Context),
    {BodyForms, Context2} = body(ClauseBody, Context1),
    {[guard_test(GuardForm, BodyForms, Fallthrough)], Context2}.

%% A clause's pattern and its guard, the guards the pattern asks for joined
%% to Guard, which is an Erlang guard here, or none.
clause_head(Pattern, Guard, #emit_context{pattern_guards = Guards} = Context) ->
    {PatternForm, Context1} = pattern(Pattern, Context#emit_context{pattern_guards = []}),
    {OwnGuard, Context2} = case Guard of
                               none -> {none, Context1};
                               _ -> expr(Guard, Context1)
                           end,
    {PatternForm, joined_guard(OwnGuard, Context2),
     Context2#emit_context{pattern_guards = Guards}}.

%% A guard that is no Erlang guard, as a test inside its clause: the body
%% where it holds, the clauses after it where it does not.
guard_test(GuardForm, Body, Fallthrough) ->
    erl_syntax:case_expr(GuardForm, [erl_syntax:clause([erl_syntax:atom(true)], none, Body),
                                     erl_syntax:clause([erl_syntax:atom(false)], none,
                                                       [Fallthrough])]).

%% The clauses after the one being compiled, bound as Rest = fun() -> ...
%% end, and the call Rest() by which a guard falls through to them.
rest_fun(Scrutinee, Rest, Context) ->
    {[RestName], Context1} = fresh_variables(1, "Rest", Context),
    RestVariable = erl_syntax:variable(RestName),
    {RestBody, Context2} =
        case Rest of
            [] -> {call_remote(erlang, error, [erl_syntax:atom(no_match)]), Context1};
            _ -> general_clauses(Scrutinee, Rest, Context1)
        end,
    RestFun = erl_syntax:fun_expr([erl_syntax:clause([], none, [RestBody])]),
    {erl_syntax:match_expr(RestVariable, RestFun), erl_syntax:application(RestVariable, []),
     Context2}.

simple_clause(Source, Pattern, Guard, ClauseBody, #emit_context{variables = Variables} = Context) ->
    {PatternForm, GuardForm, Context1} = clause_head(Pattern, Guard, Context),
    {BodyForms, Context2} = body(ClauseBody, Context1),
    {at(Source, erl_syntax:clause([PatternForm], GuardForm, BodyForms)),
     Context2#emit_context{variables = Variables}}.

%% The Erlang clauses of one Ernest clause and the bindings they need.
simple_clauses(Clause, Context) ->
    {Source, {clause, Pattern, Guard, ClauseBody}} = sourced(Clause),
    case sourced(Pattern) of
        {_, {alternatives, _}} ->
            MakeClause = fun(AlternativeSource, PatternForm, AlternativeGuard, Call, Acc) ->
                             {OwnGuard, Acc1} = case AlternativeGuard of
                                                    none -> {none, Acc};
                                                    _ -> expr(AlternativeGuard, Acc)
                                                end,
                             GuardForm = joined_guard(OwnGuard, Acc1),
                             {at(AlternativeSource,
                                 erl_syntax:clause([PatternForm], GuardForm, Call)), Acc1}
                         end,
            alternatives(Clause, MakeClause, Context);
        _ ->
            {Form, Context1} = simple_clause(Source, Pattern, Guard, ClauseBody, Context),
            {{[], [Form]}, Context1}
    end.

join_parts(Parts) ->
    {lists:append([PartBindings || {PartBindings, _} <- Parts]),
     lists:append([PartForms || {_, PartForms} <- Parts])}.

with_bindings([], Form) -> Form;
with_bindings(Bindings, Form) -> erl_syntax:block_expr(Bindings ++ [Form]).

%% Report §5.9: a clause with pattern alternatives is one Erlang clause per
%% alternative. The body is compiled once, into a fun over the variables
%% every alternative binds, and each clause calls it; MakeClause builds a
%% clause from the clause's source, the pattern form, the Ernest guard, and
%% that call.
alternatives(Clause, MakeClause, Context) ->
    {Source, {clause, Pattern, Guard, ClauseBody}} = sourced(Clause),
    {_, {alternatives, [First | _] = Alternatives}} = sourced(Pattern),
    Numbers = pattern_numbers(First),
    {[BodyName], Context1} = fresh_variables(1, "Body", Context),
    #emit_context{variables = Variables, pattern_guards = Guards} = Context1,
    BodyFunction = erl_syntax:variable(BodyName),
    {_, PatternContext} = pattern(First, Context1#emit_context{pattern_guards = []}),
    Params = bound_variables(Numbers, PatternContext),
    {BodyForms, BodyContext} = body(ClauseBody,
                                    PatternContext#emit_context{pattern_guards = Guards}),
    Bind = erl_syntax:match_expr(BodyFunction,
                                 erl_syntax:fun_expr([erl_syntax:clause(Params, none, BodyForms)])),
    {Forms, Context2} =
        lists:mapfoldl(fun(Alternative, Acc) ->
                           {PatternForm, Acc1} =
                               pattern(Alternative, Acc#emit_context{pattern_guards = []}),
                           Args = bound_variables(Numbers, Acc1),
                           Call = [at(Source, erl_syntax:application(BodyFunction, Args))],
                           {Form, Acc2} = MakeClause(Source, PatternForm, Guard, Call, Acc1),
                           #emit_context{variables = Before, pattern_guards = Kept} = Acc,
                           {Form, Acc2#emit_context{variables = Before, pattern_guards = Kept}}
                       end, BodyContext#emit_context{variables = Variables}, Alternatives),
    {{[Bind], Forms}, Context2}.

%% The Erlang variables of the locals a pattern bound.
bound_variables(Numbers, #emit_context{variables = Variables}) ->
    [erl_syntax:variable(variable_atom(maps:get(Number, Variables))) || Number <- Numbers].

%% Report §6.3's guard expression over the locals in Bound, the clause's
%% and the enclosing function's: it is an Erlang guard. A name bound at top
%% level is read through its getter, a call, so it is not one.
is_erlang_guard(Guard, Bound) ->
    {_, Node} = sourced(Guard),
    is_guard_node(Node, Bound).

is_guard_node({operator, Operator, Left, Right, _}, Bound)
  when Operator =:= '&&'; Operator =:= '||' ->
    is_erlang_guard(Left, Bound) andalso is_erlang_guard(Right, Bound);
is_guard_node({operator, Operator, Left, Right, _}, Bound)
  when Operator =:= '=='; Operator =:= '!=' ->
    is_guard_operand(Left, Bound) andalso is_guard_operand(Right, Bound);
is_guard_node({operator, Operator, Left, Right, Operation}, Bound)
  when Operator =:= '<'; Operator =:= '<='; Operator =:= '>'; Operator =:= '>=' ->
    %% an ordering through T.compare is a call (report §3.10)
    is_prelude_operation(Operation) andalso is_guard_operand(Left, Bound)
        andalso is_guard_operand(Right, Bound);
is_guard_node({'not', Expr}, Bound) -> is_erlang_guard(Expr, Bound);
is_guard_node({literal, bool, _}, _) -> true;
is_guard_node({var, {local, Number}, []}, Bound) -> lists:member(Number, Bound);
is_guard_node({var, {read, _}, []}, _) -> true;
is_guard_node(_, _) -> false.

%% Whether an ordering is the runtime's own at a prelude type of no
%% argument, Int, Float, String or Char.
is_prelude_operation({runtime, {applied, {named, [_]}, []}}) -> true;
is_prelude_operation({known, {named, [_, _]}, []}) -> true;
is_prelude_operation(_) -> false.

is_guard_operand(Operand, Bound) ->
    case sourced(Operand) of
        {_, {literal, _, _}} -> true;
        {_, {negate, Literal, _}} ->
            case sourced(Literal) of
                {_, {literal, Kind, _}} -> Kind =:= int orelse Kind =:= float;
                _ -> false
            end;
        {_, {var, {local, Number}, []}} -> lists:member(Number, Bound);
        {_, {var, {read, _}, []}} -> true;
        {_, {construct, _, none}} -> true;
        _ -> false
    end.

%%
%% Patterns: pattern(Pattern, Context) -> {Form, Context} with the
%% variables bound
%%

%% The variables in scope where a pattern begins are kept as the context's
%% outer while its parts are compiled, since its bitstrings' sizes read
%% them and no variable the same pattern binds elsewhere (report §5.11).
pattern(Pattern, #emit_context{outer = undefined, variables = Variables} = Context) ->
    {Form, Context1} = pattern_part(Pattern, Context#emit_context{outer = Variables}),
    {Form, Context1#emit_context{outer = undefined}};
pattern(Pattern, Context) ->
    pattern_part(Pattern, Context).

pattern_part(Pattern, Context) ->
    {Source, Node} = sourced(Pattern),
    {Form, Context1} = pattern_form(Node, Source, Context),
    {at(Source, Form), Context1}.

pattern_form(wildcard, _, Context) ->
    {erl_syntax:underscore(), Context};
pattern_form({local, Number}, Source, Context) ->
    {Variable, Context1} = bind(Number, local_name(Source), Context),
    {erl_syntax:variable(Variable), Context1};
pattern_form({literal, Kind, Value}, _, Context) ->
    {literal(Kind, Value), Context};
pattern_form({construct, Constructor, Args}, _, Context) ->
    {Name, Fields} = constructor_at(Constructor, Context),
    Tag = erl_syntax:atom(Name),
    case {Fields, Args} of
        {none, _} ->
            {Tag, Context};
        {{positional, _}, {positional, SubPattern}} ->
            {PatternForm, Context1} = pattern(SubPattern, Context),
            {erl_syntax:tuple([Tag, PatternForm]), Context1};
        {{named, _}, {fields, FieldPatterns}} ->
            %% report §5.10: a field the pattern omits, a wildcard in the
            %% form, matches any value
            {Forms, Context1} = lists:mapfoldl(fun pattern/2, Context, FieldPatterns),
            {erl_syntax:tuple([Tag | Forms]), Context1}
    end;
pattern_form({tuple, Elements}, _, Context) ->
    {Forms, Context1} = lists:mapfoldl(fun pattern/2, Context, Elements),
    {erl_syntax:tuple(Forms), Context1};
pattern_form({list, Elements}, _, Context) ->
    {Forms, Context1} = lists:mapfoldl(fun pattern/2, Context, Elements),
    {erl_syntax:list(Forms), Context1};
pattern_form({cons, Head, Tail}, _, Context) ->
    {HeadForm, Context1} = pattern(Head, Context),
    {TailForm, Context2} = pattern(Tail, Context1),
    {erl_syntax:cons(HeadForm, TailForm), Context2};
pattern_form({as, SubPattern, Local}, _, Context) ->
    {PatternForm, Context1} = pattern(SubPattern, Context),
    {LocalSource, {local, Number}} = sourced(Local),
    {Variable, Context2} = bind(Number, local_name(LocalSource), Context1),
    {erl_syntax:match_expr(erl_syntax:variable(Variable), PatternForm), Context2};
pattern_form({bitstring, Segments}, _, #emit_context{outer = Outer} = Context) ->
    %% report §5.11: a size expression must be an Erlang guard expression
    %% here, in the scope before the pattern and of the earlier segments;
    %% a `bytes` segment is Erlang's `binary`, so an unaligned rest fails
    %% the match
    Segment = fun(SegmentForm, {Acc, SizeScope}) ->
                  {Spec, ValuePattern} = segment_spec(SegmentForm),
                  {SizeForm, Acc1} = size_form(Spec, Acc#emit_context{variables = SizeScope}),
                  {ValueForm, Acc2} =
                      bits_pattern_value(Spec, ValuePattern,
                                         Acc1#emit_context{variables = Acc#emit_context.variables}),
                  Bound = maps:with(pattern_numbers(ValuePattern), Acc2#emit_context.variables),
                  {erl_syntax:binary_field(ValueForm, SizeForm, type_specs(Spec)),
                   {Acc2, maps:merge(SizeScope, Bound)}}
              end,
    {Fields, {Context1, _}} = lists:mapfoldl(Segment, {Context, Outer}, Segments),
    {erl_syntax:binary(Fields), Context1}.

bits_pattern_value(#{kind := float}, ValuePattern, Context) ->
    case sourced(ValuePattern) of
        {Source, {local, Number}} ->
            {Variable, Context1} = bind(Number, local_name(Source), Context),
            Variables = (Context1#emit_context.variables)#{Number => {zero, Variable}},
            {at(Source, erl_syntax:variable(Variable)),
             Context1#emit_context{variables = Variables}};
        {Source, {literal, float, Zero}} when Zero == 0.0 ->
            %% report §3.1: the literal 0.0 matches the bytes of either zero
            {[ZeroName], Context1} = fresh_variables(1, "Zero", Context),
            Guard = erl_syntax:infix_expr(erl_syntax:variable(ZeroName), erl_syntax:operator('=='),
                                          erl_syntax:float(0.0)),
            Guards = Context1#emit_context.pattern_guards ++ [Guard],
            {at(Source, erl_syntax:variable(ZeroName)),
             Context1#emit_context{pattern_guards = Guards}};
        _ ->
            pattern(ValuePattern, Context)
    end;
bits_pattern_value(_, ValuePattern, Context) ->
    pattern(ValuePattern, Context).

%% A clause's guard: the guards its pattern asked for, joined to its own.
joined_guard(GuardForm, #emit_context{pattern_guards = []}) -> GuardForm;
joined_guard(GuardForm, #emit_context{pattern_guards = Guards}) ->
    All = case GuardForm of none -> Guards; _ -> Guards ++ [GuardForm] end,
    Joined = lists:foldl(fun(Guard, Acc) ->
                             erl_syntax:infix_expr(Acc, erl_syntax:operator('andalso'), Guard)
                         end, hd(All), tl(All)),
    Joined.

%%
%% Bitstring segments, report §5.11
%%

%% A segment's specifiers as a form writes them, with their defaults
%% (Appendix H), and its value.
segment_spec({segment, Kind, Size, Unit, Endian, Sign, Value}) ->
    {#{kind => Kind, size => Size, unit => Unit, endian => Endian, sign => Sign}, Value}.

size_form(#{size := none}, Context) -> {none, Context};
size_form(#{size := {const, Size}}, Context) -> {erl_syntax:integer(Size), Context};
size_form(#{size := {expr, SizeExpr}}, Context) -> expr(SizeExpr, Context).

%% The width in bits as a form: size times unit.
bits_form(#{size := {const, Size}, unit := Unit}, _) -> erl_syntax:integer(Size * Unit);
bits_form(#{unit := 1}, SizeForm) -> SizeForm;
bits_form(#{unit := Unit}, SizeForm) ->
    erl_syntax:infix_expr(SizeForm, erl_syntax:operator('*'), erl_syntax:integer(Unit)).

segment_value(#{kind := int, sign := Sign} = Spec, ValueForm, SizeForm) ->
    call_remote(ern_bits, int, [ValueForm, bits_form(Spec, SizeForm), erl_syntax:atom(Sign)]);
segment_value(#{kind := float} = Spec, ValueForm, SizeForm) ->
    call_remote(ern_bits, float, [ValueForm, bits_form(Spec, SizeForm)]);
segment_value(#{kind := bytes, size := none}, ValueForm, _) -> ValueForm;
segment_value(#{kind := bytes} = Spec, ValueForm, SizeForm) ->
    call_remote(ern_bits, bytes, [ValueForm, bits_form(Spec, SizeForm)]);
segment_value(_, ValueForm, _) -> ValueForm.

%% Report §5.1: a long literal's elements, evaluated first to last, each
%% put before the list so far, which alone stays live at the next, and the
%% list reversed at the end.
built_in_order(Elements, Context) ->
    {Matches, {Last, Context1}} =
        lists:mapfoldl(fun(Element, {SoFar, Acc}) ->
                           {Form, Acc1} = expr(Element, Acc),
                           {[Name], Acc2} = fresh_variables(1, "Built", Acc1),
                           {erl_syntax:match_expr(erl_syntax:variable(Name),
                                                  erl_syntax:cons(Form, SoFar)),
                            {erl_syntax:variable(Name), Acc2}}
                       end, {erl_syntax:nil(), Context}, Elements),
    {erl_syntax:block_expr(Matches ++ [call_remote(lists, reverse, [Last])]), Context1}.

%% Report §5.1, §5.11: a size that is an expression stands in a segment
%% twice, its width checked and its field built, so where one is, every
%% segment's value and every such size is bound once, in order, before the
%% binary; one that faults faults there, outside the overflow's handler.
segments_bound(Compiled, Context) ->
    case lists:all(fun({_, _, SizeForm}) -> is_plain_size(SizeForm) end, Compiled) of
        true ->
            {[], Compiled, Context};
        false ->
            {Bound, Context1} = lists:mapfoldl(fun segment_bound/2, Context, Compiled),
            {Bindings, Parts} = lists:unzip(Bound),
            {lists:append(Bindings), Parts, Context1}
    end.

segment_bound({Spec, ValueForm, SizeForm}, Context) ->
    {[ValueName], Context1} = fresh_variables(1, "Value", Context),
    ValueBinding = erl_syntax:match_expr(erl_syntax:variable(ValueName), ValueForm),
    case is_plain_size(SizeForm) of
        true ->
            {{[ValueBinding], {Spec, erl_syntax:variable(ValueName), SizeForm}}, Context1};
        false ->
            {[SizeName], Context2} = fresh_variables(1, "Size", Context1),
            SizeBinding = erl_syntax:match_expr(erl_syntax:variable(SizeName), SizeForm),
            {{[ValueBinding, SizeBinding],
              {Spec, erl_syntax:variable(ValueName), erl_syntax:variable(SizeName)}},
             Context2}
    end.

is_plain_size(none) -> true;
is_plain_size(SizeForm) -> lists:member(erl_syntax:type(SizeForm), [integer, variable]).

%% A dynamic size counted in bits, a unit of 1, leaves the bit count open;
%% the built value is then checked for alignment.
is_open(#{size := {expr, _}, unit := 1}) -> true;
is_open(_) -> false.

type_specs(#{kind := Kind, unit := Unit, endian := Endian, sign := Sign, size := Size}) ->
    Type = case Kind of
               int -> integer; bytes -> binary; Other -> Other
           end,
    IsUtf = lists:member(Kind, [utf8, utf16, utf32]),
    [erl_syntax:atom(Type)]
        ++ [erl_syntax:atom(Endian) || not IsUtf orelse Endian =/= big]
        ++ [erl_syntax:atom(Sign) || Kind =:= int]
        ++ [erl_syntax:size_qualifier(erl_syntax:atom(unit), erl_syntax:integer(Unit))
            || not IsUtf, Size =/= none].

%%
%% Variables: every local gets a fresh Erlang variable
%%

%% The local Number bound to a fresh Erlang variable, named after the name
%% the source gives it, and by its count alone where the form holds no
%% source, so that the variables of a unit made from forms that arrived
%% make no atoms past those of the largest unit made before (report
%% §11.2).
bind(Number, Name, #emit_context{variables = Variables, counter = Counter} = Context) ->
    Variable = erlang_variable(Name, Number, Counter + 1),
    {Variable,
     Context#emit_context{variables = Variables#{Number => Variable}, counter = Counter + 1}}.

%% Report §3.1: a variable a float segment bound may hold the runtime's
%% negative zero, so the map holds {zero, V} and each read is V + 0.0,
%% which is 0.0 for either zero and V otherwise; a capture passes V itself,
%% and the reads inside normalize it the same way.
variable_form({zero, Variable}) ->
    erl_syntax:infix_expr(erl_syntax:variable(Variable), erl_syntax:operator('+'),
                          erl_syntax:float(0.0));
variable_form(Variable) ->
    erl_syntax:variable(Variable).

variable_atom({zero, Variable}) -> Variable;
variable_atom(Variable) -> Variable.

erlang_variable(none, _, Count) ->
    list_to_atom("L_" ++ integer_to_list(Count));
erlang_variable(Name, _, Count) ->
    Text = atom_to_list(Name),
    Base = case Text of
               [$_ | Rest] -> "V_" ++ Rest;
               %% a name the checker makes, which no program spells (§2.3)
               [$$ | Rest] -> "V_" ++ Rest;
               [First | Rest] -> [string:to_upper(First) | Rest]
           end,
    host_name(Base, "_" ++ integer_to_list(Count)).

fresh_variables(Count, Prefix, #emit_context{counter = Counter} = Context) ->
    Variables = [list_to_atom(Prefix ++ "_" ++ integer_to_list(Counter + Index))
                 || Index <- lists:seq(1, Count)],
    {Variables, Context#emit_context{counter = Counter + Count}}.

named_variables(Prefixes, Context) ->
    lists:mapfoldl(fun(Prefix, Acc) ->
                           {[Variable], Acc1} = fresh_variables(1, Prefix, Acc),
                           {Variable, Acc1}
                   end, Context, Prefixes).

%% Report §11.1: a name the emitter makes, Base cut so that Base and its
%% numbered Suffix fit the host's 255 characters; the suffix keeps it apart
%% from every other.
host_name(Base, Suffix) ->
    list_to_atom(lists:sublist(Base, 255 - length(Suffix)) ++ Suffix).

%%
%% Helpers
%%

%% A form at the line and column its source gives, or as it is where the
%% form holds no source.
at(none, Form) ->
    Form;
at({Line, Column, _}, Form) ->
    erl_syntax:set_pos(Form, {Line, Column}).

%% A form the checker would not have passed: a defect of the toolchain, not
%% of the program.
-spec fail(term(), iodata()) -> no_return().
fail(Source, Message) ->
    erlang:error({emitter_defect, Source, lists:flatten(Message)}).
