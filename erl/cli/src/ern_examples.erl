%% Report §11.2, Appendix E.0 shape rule 6: the doc examples of a compiled
%% module as the cases `ern test` runs after its tests, each compiled in a
%% module of its own that uses the documented one.
-module(ern_examples).

-export([cases/2, unload/1]).

-include_lib("shared/include/ern_diagnostic.hrl").

%% The cases of the doc examples of the module Namespace, which the run has
%% loaded with the modules it uses, Loaded, its own first: each as a test is,
%% `{'Case', Name, Run}`, its run answering `'Passed'` or `{'Failed', Text}`;
%% beside them the units their compiling loaded, which unload/1 takes out
%% once they have run. Report §11.2: an example is named by the declaration
%% it documents and its number among that declaration's, `List.take example
%% 2`, the module's own as `List example 1`; the fenced `ernest` blocks of a
%% type's constructors and fields are the type's, after its own.
-spec cases([atom()], [module()]) -> {[{'Case', binary(), fun(() -> term())}], [module()]}.
cases(Namespace, [ErlangModule | _] = Loaded) ->
    {ok, Beam} = file:read_file(code:which(ErlangModule)),
    Interfaces = [Interface || Unit <- lists:reverse(Loaded),
                               {ok, Compiled} <- [file:read_file(code:which(Unit))],
                               {ok, #{interface := Interface}} <- [ern_interface:read(Compiled)]],
    Examples = [{iolist_to_binary([Owner, " example ", integer_to_list(Number)]), Block}
                || {Owner, Docs} <- documented(Namespace, Beam),
                   {Number, Block} <- lists:enumerate(lists:append([fences(Doc)
                                                                      || Doc <- Docs]))],
    Compiled = [example(Name, Block, Index, Interfaces)
                || {Index, {Name, Block}} <- lists:enumerate(Examples)],
    {[Case || {Case, _} <- Compiled], [Unit || {_, Unit} <- Compiled, Unit =/= none]}.

%% The units the examples' compiling loaded, deleted, out of the code table,
%% and purged, as the shell takes out a module of its own (ern_shell).
-spec unload([module()]) -> ok.
unload(Units) ->
    lists:foreach(fun(Unit) ->
                      code:delete(Unit),
                      ern_code:unloaded(Unit),
                      code:purge(Unit)
                  end, Units).

%% Each declaration the module's documentation holds, as the program names
%% it, with its doc blocks, the module's own first, in the order the module
%% writes them (report §11.1, §11.4).
documented(Namespace, Beam) ->
    Module = ern_namespace:text(Namespace),
    case ern_docs:read(Beam) of
        {ok, {docs_v1, _, _, _, ModuleDoc, _, Entries}} ->
            [{Module, texts([ModuleDoc])}
             | [{[Module, ".", atom_to_binary(Name)], texts([Doc]) ++ item_docs(Meta)}
                || {{_Kind, Name, _Arity}, _, _, Doc, Meta} <- Entries]];
        {error, _} ->
            []
    end.

texts(Docs) ->
    [Text || #{<<"en">> := Text} <- Docs].

%% A type's constructors' and their fields' doc blocks, in declared order.
item_docs(#{items := Items}) ->
    lists:append([[Doc || is_binary(Doc)]
                  ++ [FieldDoc || #{doc := FieldDoc} <- Fields, is_binary(FieldDoc)]
                  || #{doc := Doc, fields := Fields} <- Items]);
item_docs(_) ->
    [].

%% Report §2.2: a doc block's fenced `ernest` blocks.
fences(Doc) ->
    case re:run(Doc, "```ernest\\n(.*?)\\n```", [global, dotall, {capture, all_but_first, binary}])
    of
        {match, Matches} -> [Block || [Block] <- Matches];
        nomatch -> []
    end.

%% One example as a case, and the unit its compiling loaded, or none. Report
%% §11.2, Appendix E.0 shape rule 6: an example that does not compile fails
%% with the diagnostic's message, the first of its errors; one that ends in
%% `// => v` runs, and fails where `Io.show` of its value is not `v`; one
%% without the line passes where it compiles. An example's function is
%% checked as a lambda's body where it runs nothing, so that it may receive,
%% and one that runs has the mailbox type Never, as an entry point's left
%% open has (report §8.1).
example(Name, Block, Index, Interfaces) ->
    Namespace = [list_to_atom("$Example" ++ integer_to_list(Index))],
    {Body, Value} = split_result(Block),
    {Declared, Expression} = declared(Body),
    Text = case Value of
               none -> [Declared, "fn docExample() = fn() = {\n", Expression, "\n}\n"];
               _ -> [Declared, "fn docExample() = {\n", Expression, "\n}\n\n"
                     "export fn docShown() : String receiving Never = Io.show(docExample())\n"]
           end,
    case {checked(Namespace, iolist_to_binary(Text), Interfaces), Value} of
        {{error, [#diagnostic{message = Message} | _]}, _} ->
            Failed = {'Failed', unicode:characters_to_binary(Message)},
            {{'Case', Name, fun() -> Failed end}, none};
        {{ok, _, _, _}, none} ->
            {{'Case', Name, fun() -> 'Passed' end}, none};
        {{ok, Typed, Interface, Env}, Expected} ->
            {ok, Unit, Beam} = ern_compile:compile(Namespace, Typed, Interface, Env),
            {module, Unit} = code:load_binary(Unit, "doc example", Beam),
            {ok, Recorded} = ern_canonical:read(Beam),
            ok = ern_code:loaded(Unit, Beam, Recorded),
            %% report §11.1: the unit names its functions by their position
            {Shown, 0} = ern_code:function(Unit, Namespace ++ [docShown]),
            {{'Case', Name, fun() -> compared(Unit, Shown, Expected) end}, Unit}
    end.

%% Report §8.5: the example's own bindings, where it declares any, then its
%% value as `Io.show` writes it, against the one its last line promises.
compared(Unit, Shown, Expected) ->
    case erlang:function_exported(Unit, '$init', 0) of
        true -> Unit:'$init'();
        false -> ok
    end,
    case Unit:Shown() of
        Expected -> 'Passed';
        Got -> {'Failed', <<"expected ", Expected/binary, ", got ", Got/binary>>}
    end.

checked(Namespace, Text, Interfaces) ->
    case ern_parser:parse_string(Text) of
        {ok, Declarations} -> ern_typecheck:check(Namespace, Declarations, Interfaces);
        {error, Diagnostic} -> {error, [Diagnostic]}
    end.

%% An example's body and the value its last line `// => v` promises, or none.
split_result(Block) ->
    Lines = binary:split(Block, <<"\n">>, [global]),
    case lists:last(Lines) of
        <<"// => ", Value/binary>> ->
            {iolist_to_binary(lists:join(<<"\n">>, lists:droplast(Lines))), Value};
        _ -> {Block, none}
    end.

%% Appendix E.0 shape rule 6: an example is an expression, which
%% declarations may stand before, as in a module: the paragraphs before its
%% last blank line, where they parse as a module's declarations, and the
%% expression after them; else no declaration and the whole example.
declared(Body) ->
    case string:split(Body, <<"\n\n">>, trailing) of
        [Declared, Expression] ->
            case ern_parser:parse_string(Declared) of
                {ok, [_ | _]} -> {<<Declared/binary, "\n">>, Expression};
                _ -> {<<>>, Body}
            end;
        _ ->
            {<<>>, Body}
    end.
