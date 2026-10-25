%% The style guides, docs/style.md and guide/style.md, where a machine can check them.
-module(ern_style_tests).

-include_lib("eunit/include/eunit.hrl").

-export([write_formatted/0]).

-define(ROOT, "..").

%% The documents whose ```ernest fences the Ernest style guide governs.
-define(DOCUMENTS, ["guide/language.md", "guide/style.md", "report/language.md",
                    "report/toolchain.md", "report/library.md"]).

%% The British spellings the American rule refuses, each with the
%% inflections the repository has written or a writer would.
-define(BRITISH,
        ["colour", "colours", "coloured", "colouring", "behaviour", "behaviours",
         "utilisation", "utilisations", "utilise", "utilises", "utilised",
         "initialise", "initialises", "initialised", "initialiser", "initialisers",
         "normalise", "normalises", "normalised", "catalogue", "catalogues", "catalogued",
         "labelled", "labelling", "unlabelled", "judgement", "judgements", "licence", "licences",
         "favour", "favours", "favoured", "favourite", "favourable", "grey", "greys",
         "centre", "centres", "centred", "serialise", "serialises", "serialised", "serialiser",
         "serialising", "recognise", "recognises", "recognised", "organise", "organises",
         "organised", "synchronise", "synchronises", "synchronised", "optimise", "optimises",
         "optimised", "minimise", "minimises", "minimised", "realise", "realises", "realised",
         "analyse", "analysed", "modelling", "modelled", "signalling", "signalled",
         "travelling", "cancelled", "cancelling", "dialled", "dialling", "equalled",
         "totalling", "artefact", "artefacts", "defence", "offence", "pretence", "fulfil",
         "programme", "programmes", "whilst", "amongst", "learnt", "spelt", "metre", "metres",
         "litre", "litres", "fibre", "theatre", "sceptical", "ageing", "tyre", "tyres", "mould",
         "cheque", "cheques", "draught", "aluminium", "sulphur", "maths", "honour", "honouring",
         "humour", "armour", "flavour", "harbour", "labour", "neighbour", "neighbours",
         "neighbouring", "rumour", "savour", "vapour", "enrol", "instalment", "skilful", "storey",
         "practise", "enquire", "acknowledgement", "acknowledgements", "characterise",
         "criticised", "specialisation"]).

%% The host's names that keep the host's spelling.
-define(HOST_NAMES, "(?<![A-Za-z])-behaviour|behaviour_info|erl_parse:normalise"
                    "|digraph_utils:reachable_neighbours|digraph:in_neighbours").

%% docs/style.md: code lines are at most 100 characters, in the compiler's
%% Erlang, its C, its Makefiles and its scripts, and in Ernest alike; the
%% vendored getopt keeps its upstream form, and test/build holds a build's
%% copies, which a stale one failed. A regression test for the Makefiles,
%% scripts and headers, the fixtures' Erlang and the machines' script it
%% once left unread
line_length_test() ->
    Patterns = ["erl/*/src/*.erl", "erl/*/test/*.erl", "erl/*/c_src/*.c", "test/*.erl",
                "test/fixtures/**/*.erl", "src/stdlib/**/*.ern", "examples/**/*.ern",
                "src/shell/**/*.ern", "test/**/*.ern", "test/*.py", "editors/emacs/*.el",
                "editors/emacs/test/*.el", "src/libs/**/*.ern", "tools/*.ern", "tour/*/*.ern",
                "tools/*.sh", "test/machines/*.sh", "tools/*.escript", "bin/ern",
                "erl/*/include/*.hrl", "Makefile", "test/Makefile", "erl/*/src/Makefile",
                "erl/app.mk", "tools/release/Makefile"],
    Files = [File || File <- ern_repository:files(Patterns),
                     filename:basename(File) =/= "getopt.erl",
                     not lists:prefix("test/build/", File)],
    ?assert(length(Files) > 20),
    Long = [{File, Number} || File <- Files,
                              {Number, Line} <- numbered(File),
                              string:length(Line) > 100],
    ?assertEqual([], Long).

%% docs/development.md, `make bench`: the programs part's parser,
%% test/fixtures/bench/parser.ern, is examples/repl.ern's lexer, parser and
%% evaluator, from `fn tokenize` on, its comments aside, and each of its
%% types is the example's, so that the bench measures the example. A
%% regression test, written after the copy, which nothing held to the
%% example, and its types to nothing until the release review before 0.5.0
parser_fixture_test() ->
    ?assertEqual(code_from("examples/repl.ern"), code_from("test/fixtures/bench/parser.ern")),
    Copied = types("test/fixtures/bench/parser.ern"),
    ?assertNotEqual([], Copied),
    ?assertEqual([], Copied -- types("examples/repl.ern")).

%% An Ernest module's type declarations, each its lines from the one that
%% begins `type`, a line that begins with a space continuing it.
types(Path) ->
    declarations(string:split(binary_to_list(ern_repository:read(Path)), "\n", all)).

declarations(["type " ++ _ = Line | Rest]) ->
    {Continued, Next} = lists:splitwith(fun(Text) -> lists:prefix(" ", Text) end, Rest),
    [[Line | Continued] | declarations(Next)];
declarations([_ | Rest]) ->
    declarations(Rest);
declarations([]) ->
    [].

%% An Ernest module's lines from `fn tokenize` on, each without its comment
%% and the blanks before it, a line that holds nothing else left out.
code_from(Path) ->
    Lines = string:split(binary_to_list(ern_repository:read(Path)), "\n", all),
    [Code || Line <- lists:dropwhile(fun(Line) -> not lists:prefix("fn tokenize", Line) end,
                                     Lines),
             Code <- [string:trim(uncommented(Line, false), trailing)], Code =/= ""].

%% A line cut at a comment's `//`, one outside a string literal.
uncommented("//" ++ _, false) -> [];
uncommented([$\\, Char | Rest], true) -> [$\\, Char | uncommented(Rest, true)];
uncommented([$" | Rest], InString) -> [$" | uncommented(Rest, not InString)];
uncommented([Char | Rest], InString) -> [Char | uncommented(Rest, InString)];
uncommented([], _) -> [].

%% docs/style.md: no file holds a tab but a Makefile; the vendored getopt
%% keeps its upstream form. A regression test for the fixtures' Erlang and
%% the machines' script, which it once left unread
no_tab_test() ->
    Patterns = ["erl/*/src/*.erl", "erl/*/test/*.erl", "erl/*/include/*.hrl", "erl/*/c_src/*.c",
                "test/*.erl", "test/fixtures/**/*.erl", "src/stdlib/**/*.ern",
                "examples/**/*.ern", "src/shell/**/*.ern", "test/**/*.ern", "test/*.py",
                "editors/emacs/*.el", "editors/emacs/test/*.el",
                "editors/emacs/test/broken/*.ern", "src/libs/**/*.ern", "src/libs/*/*.md",
                "tools/*.ern", "tour/*/*.ern", "tools/*.sh", "test/machines/*.sh", "bin/ern",
                "*.md", "docs/*.md"],
    Files = [File || File <- ern_repository:files(Patterns),
                     filename:basename(File) =/= "getopt.erl",
                     not lists:prefix("test/build/", File)],
    ?assert(length(Files) > 20),
    ?assertEqual([], [{File, Number} || File <- Files, {Number, Line} <- numbered(File),
                                        lists:member($\t, Line)]).

%% docs/style.md: the spelling is American English, in every tracked file
%% of text but a proposal, the licenses and a borrowed file. A word is
%% matched whole, whatever its case, and a name is read as the words it
%% joins at `_` or a capital, `ern_utilizations` and `setUtilization`
%% alike; a name of the host's keeps the host's spelling, and this module's
%% list is the one place the British spellings are written. A word is a
%% run of lowercase letters after at most one capital, or a run of
%% capitals, so a British spelling stands in a line as one of three texts,
%% in lowercase, capitalized or in capitals, and a line is read for its
%% words only where it holds one of them. A regression test, written after
%% the sweep that made it hold: it refuses the spellings its list holds and
%% no other
american_spelling_test_() ->
    {timeout, 60, fun american_spelling/0}.

american_spelling() ->
    Unread = ["LICENSE", "THIRD_PARTY_LICENSES" | borrowed()],
    ?assert(length(Unread) > 2),
    Files = [File || File <- string:lexemes(os:cmd("git -C " ++ ?ROOT ++ " ls-files"), "\n"),
                     not lists:prefix("docs/proposals/", File),
                     not lists:member(File, Unread),
                     filelib:is_regular(filename:join(?ROOT, File))],
    ?assert(length(Files) > 300),
    Spellings = [list_to_binary(Spelling) || Spelling <- ?BRITISH],
    British = sets:from_list(Spellings, [{version, 2}]),
    Written = binary:compile_pattern(
                lists:append([[Spelling, string:titlecase(Spelling), string:uppercase(Spelling)]
                              || Spelling <- Spellings])),
    {ok, HostNames} = re:compile(?HOST_NAMES),
    {ok, Word} = re:compile("[A-Z]?[a-z]+|[A-Z]+(?![a-z])"),
    ?assertEqual([], [{File, Number, Found} || File <- Files,
                                               {Number, Line} <- spelled_lines(File),
                                               binary:match(Line, Written) =/= nomatch,
                                               Found <- words(Line, HostNames, Word),
                                               sets:is_element(string:lowercase(Found), British)]).

%% The files THIRD_PARTY_LICENSES says were copied from upstream; a table
%% derived from upstream's data is in a file of ours.
borrowed() ->
    Pattern = "  Path: +([^ ,\n]+)\n(?:  [A-Z][a-z]+: [^\n]*\n)*  Copied:",
    {match, Paths} = re:run(ern_repository:read("THIRD_PARTY_LICENSES"), Pattern,
                            [global, {capture, all_but_first, list}]),
    [Path || [Path] <- Paths].

%% The numbered lines of a file the spelling rule reads, but this module's
%% list of the British spellings, from its `-define` to the line that
%% closes it.
spelled_lines(File) ->
    Lines = text_lines(File),
    case File =:= "test/" ++ atom_to_list(?MODULE) ++ ".erl" of
        true ->
            {Before, Listed} = lists:splitwith(fun({_, Line}) -> not opens_list(Line) end, Lines),
            {_, [_ | After]} = lists:splitwith(fun({_, Line}) -> not closes_list(Line) end,
                                               Listed),
            Before ++ After;
        false ->
            Lines
    end.

opens_list(Line) ->
    Line =:= <<"-define(BRITISH,">>.

closes_list(Line) ->
    binary:longest_common_suffix([Line, <<"]).">>]) =:= 3.

%% A file's numbered lines, or none where it holds a zero byte and is not text.
text_lines(File) ->
    Bytes = ern_repository:read(File),
    case binary:match(Bytes, <<0>>) of
        nomatch -> lists:enumerate(binary:split(Bytes, <<"\n">>, [global]));
        _ -> []
    end.

%% A line's words, but in the host's names.
words(Line, HostNames, Word) ->
    Ours = re:replace(Line, HostNames, " ", [global, {return, binary}]),
    case re:run(Ours, Word, [global, {capture, first, binary}]) of
        {match, Words} -> [Found || [Found] <- Words];
        nomatch -> []
    end.

%% docs/style.md: one `-export` list, in the order the functions appear,
%% and a `-spec` on every exported function, in the toolchain's modules and
%% in the tests' and their harnesses'; the vendored getopt keeps its
%% upstream form. Written after the rule, when six modules had fallen out
%% of order and one had lost its specs; the tests' modules were read from
%% 2026-10-24, when the nodes harness's exports had none
exports_test() ->
    Files = [File || File <- ern_repository:files(["erl/*/src/*.erl", "test/*.erl"]),
                     filename:basename(File) =/= "getopt.erl"],
    ?assert(length(Files) > 20),
    ?assertEqual([],
                 [{File, Fault} || File <- Files,
                                   Fault <- export_faults(filename:join(?ROOT, File))]).

export_faults(File) ->
    {ok, Forms} = epp_dodger:quick_parse_file(File),
    Lists = [Exported || {attribute, _, export, Exported} <- Forms],
    Exports = lists:append(Lists),
    Specs = [FunctionArity || {attribute, _, spec, {FunctionArity, _}} <- Forms],
    Appear = [{Name, Arity} || {function, _, Name, Arity, _} <- Forms,
                               lists:member({Name, Arity}, Exports)],
    [lists_of_exports || length(Lists) > 1]
        ++ [out_of_order
            || Appear =/= [FunctionArity || FunctionArity <- Exports,
                                            lists:member(FunctionArity, Appear)]]
        ++ [{no_spec, FunctionArity} || FunctionArity <- Exports,
                                        not lists:member(FunctionArity, Specs)].

%% report §8.6, docs/style.md: the look reads a process that waits in a
%% module of the toolchain's own Erlang as one that waits as Ernest waits
%% (ern_rt:is_ernest/1), so every `receive` there that can wait, which is
%% every one but a `receive` with `after 0`, is named by its function under
%% its kind in its module's `-receives` attributes, and the forms are held
%% to the kind where they can show it. A `foreign_wait` waits on what the
%% look cannot see deliver, under the FOREIGN key
%% (ern_rt:entered_foreign/0), which the function, or every function of its
%% module that calls it, puts and takes away; a receive only a signal ends
%% needs no taking away. An `ernest_wait` waits on what the look reads, one
%% with a deadline under the TIMED key so (ern_rt:timed/0). An `own_process`
%% waits in a process that is no program's, which the look does not read. An
%% `answered_at_once` waits on an answer that comes before the look can find
%% it waiting.
%%
%% A receive of no kind, a key its forms do not show, a kind of another
%% name, and a function named twice or with no receive that can wait fail
%% the test, each by its file, line and function. A regression test,
%% written after the code it reads: the reading of every receive by hand
%% that it stands for found two waits unmarked, and its own reading a
%% third. It holds a tag to the forms, and not the kinds the forms cannot
%% show, `own_process`, `answered_at_once` and an `ernest_wait` with no
%% deadline, which are the writer's word; it reads no receive a macro
%% writes, and fails a wait whose key a caller in another module puts.
receives_test() ->
    Files = ern_repository:files(["erl/*/src/*.erl"]),
    ?assert(length(Files) > 20),
    ?assertEqual([], [Fault || File <- Files, Fault <- receive_faults(File)]).

receive_faults(File) ->
    {ok, Forms} = epp_dodger:quick_parse_file(filename:join(?ROOT, File)),
    ErlangModule = list_to_atom(filename:basename(File, ".erl")),
    Tags = [{Line, Value} || {attribute, Line, receives, Value} <- Forms],
    Kinds = [{FunctionArity, Kind} || {_, {Kind, Functions}} <- Tags, is_list(Functions),
                                      FunctionArity <- Functions],
    Waits = [{{Name, Arity}, Wait} || {function, _, Name, Arity, Clauses} <- Forms,
                                      Wait <- waits(Clauses)],
    Calls = #{{Name, Arity} => called(ErlangModule, Clauses)
              || {function, _, Name, Arity, Clauses} <- Forms},
    Exports = lists:append([Exported || {attribute, _, export, Exported} <- Forms]),
    [fault_line(File, Line, FunctionArity, Fault)
     || {FunctionArity, {Line, _, _} = Wait} <- Waits,
        Fault <- wait_faults(proplists:get_all_values(FunctionArity, Kinds), FunctionArity, Wait,
                             Calls, Exports)]
        ++ [fault_line(File, Line, Named, Fault)
            || {Line, Value} <- Tags, {Named, Fault} <- tag_faults(Value, Kinds, Waits)].

%% A fault as its line, `file:line: function/arity: what`, which the
%% test's failure prints whole.
fault_line(File, Line, {Name, Arity}, Fault) when is_atom(Name), is_integer(Arity) ->
    lists:flatten(io_lib:format("~s:~B: ~s/~B: ~s", [File, Line, Name, Arity, Fault]));
fault_line(File, Line, Named, Fault) ->
    lists:flatten(io_lib:format("~s:~B: ~0p: ~s", [File, Line, Named, Fault])).

%% What a wait lacks: a kind, or the key its kind's forms show. A kind of
%% another name, and a function named twice, are its tag's faults.
wait_faults([], _, _, _, _) ->
    ["a receive that can wait, of no kind"];
wait_faults([foreign_wait], FunctionArity, {_, _, Endless}, Calls, Exports) ->
    ["a foreign wait not under the FOREIGN key"
     || not keyed(FunctionArity, {entered_foreign, left_foreign}, Endless, Calls, Exports)];
wait_faults([ernest_wait], FunctionArity, {_, Deadline, _}, Calls, Exports) ->
    ["a deadline not under the TIMED key"
     || Deadline, not keyed(FunctionArity, {timed, untimed}, false, Calls, Exports)];
wait_faults(_, _, _, _, _) ->
    [].

tag_faults({Kind, Functions}, Kinds, Waits) when is_list(Functions) ->
    [{Kind, "no kind of receive"}
     || not lists:member(Kind, [foreign_wait, ernest_wait, own_process, answered_at_once])]
        ++ [{FunctionArity, "named, with no receive that can wait"}
            || FunctionArity <- Functions, not lists:keymember(FunctionArity, 1, Waits)]
        ++ [{FunctionArity, "named under two kinds"}
            || FunctionArity <- Functions,
               length(proplists:get_all_values(FunctionArity, Kinds)) > 1];
tag_faults(Value, _, _) ->
    [{Value, "not {Kind, [Function/Arity]}"}].

%% Each receive in a function's forms that can wait, nested ones among
%% them: its line, whether it has a deadline, and whether only a signal
%% ends it, `receive after infinity -> ok end`.
waits({'receive', Line, Clauses}) ->
    [{Line, false, false} | waits(Clauses)];
waits({'receive', _, Clauses, {integer, _, 0}, After}) ->
    waits([Clauses, After]);
waits({'receive', Line, Clauses, Timeout, After}) ->
    Untimed = case Timeout of
                  {atom, _, infinity} -> true;
                  _ -> false
              end,
    [{Line, not Untimed, Untimed andalso Clauses =:= []} | waits([Clauses, Timeout, After])];
waits(Form) when is_tuple(Form) ->
    waits(tuple_to_list(Form));
waits(Forms) when is_list(Forms) ->
    lists:append([waits(Form) || Form <- Forms]);
waits(_) ->
    [].

%% The functions of its module a function's forms call or name, `fun f/1`
%% among them, and the look's marks they call, which ern_rt calls
%% locally: `{ern_rt, entered_foreign}`.
called(ErlangModule, {call, _, {atom, _, Name}, Arguments}) ->
    [{Name, length(Arguments)}]
        ++ [{ern_rt, Name} || ErlangModule =:= ern_rt, Arguments =:= []]
        ++ called(ErlangModule, Arguments);
called(ErlangModule, {call, _, {remote, _, {atom, _, ern_rt}, {atom, _, Name}}, Arguments}) ->
    [{ern_rt, Name} || Arguments =:= []] ++ called(ErlangModule, Arguments);
called(_, {'fun', _, {function, Name, Arity}}) when is_atom(Name) ->
    [{Name, Arity}];
called(ErlangModule, Form) when is_tuple(Form) ->
    called(ErlangModule, tuple_to_list(Form));
called(ErlangModule, Forms) when is_list(Forms) ->
    lists:append([called(ErlangModule, Form) || Form <- Forms]);
called(_, _) ->
    [].

%% Whether a function's waits are under the look's key that Put puts and
%% Take takes away: the function calls both, or Put alone where only a
%% signal ends the wait, or it is called only by functions of its module
%% that are so, never from outside, which an export allows and the forms
%% cannot show. A caller already asked of is the question's own.
keyed(FunctionArity, Keys, Endless, Calls, Exports) ->
    keyed(FunctionArity, Keys, Endless, Calls, Exports, []).

keyed(FunctionArity, {Put, Take} = Keys, Endless, Calls, Exports, Asked) ->
    #{FunctionArity := Called} = Calls,
    Puts = lists:member({ern_rt, Put}, Called)
        andalso (Endless orelse lists:member({ern_rt, Take}, Called)),
    Callers = [Caller || Caller := CallerCalled <- Calls, Caller =/= FunctionArity,
                         lists:member(FunctionArity, CallerCalled)],
    Puts orelse (not lists:member(FunctionArity, Exports) andalso Callers =/= []
                 andalso lists:all(fun(Caller) ->
                                       lists:member(Caller, Asked)
                                           orelse keyed(Caller, Keys, Endless, Calls, Exports,
                                                        [FunctionArity | Asked])
                                   end, Callers)).

%% guide/style.md: a block holds more than one statement, in every module,
%% every example in a module's doc blocks, and every Ernest block of the
%% guide and the report. A brace after an expression or after `receive`
%% holds clauses and is not a block. Written with the rule.
block_of_one_test() ->
    ?assertEqual([],
                 [{File, Number} || {File, Tokens} <- ernest_tokens(),
                                    Number <- blocks_of_one(Tokens)]).

%% report §11.6: every module is in the layout `ern format`
%% writes, the examples of its doc blocks with it, and so is every Ernest
%% block of the guide and the report that parses; `make format` lays out
%% what is not. Written with the formatter, as the style guide's hand-made
%% checks of a statement a line, a function's head and the blank line
%% between declarations, which it holds, went.
formatted_test_() ->
    {timeout, 120,
     fun() ->
         ?assertEqual([], [File || File <- modules(), not formatted(File)]),
         ?assertEqual([], [File || File <- ?DOCUMENTS, not document_formatted(File)])
     end}.

formatted(File) ->
    Bytes = ern_repository:read(File),
    ern_format:format(Bytes) =:= {ok, Bytes}.

document_formatted(File) ->
    Bytes = ern_repository:read(File),
    ern_format:markdown(Bytes) =:= Bytes.

%% The Ernest blocks of the documents laid out, for `make format`.
-spec write_formatted() -> ok.
write_formatted() ->
    lists:foreach(fun(Document) ->
                      Path = filename:join(?ROOT, Document),
                      Bytes = ern_repository:read(Document),
                      case ern_format:markdown(Bytes) of
                          Bytes -> ok;
                          Formatted -> ok = file:write_file(Path, Formatted)
                      end
                  end, ?DOCUMENTS).

%% The modules the Ernest style guide governs.
modules() ->
    Patterns = ["src/stdlib/**/*.ern", "examples/**/*.ern", "src/shell/**/*.ern",
                "src/libs/**/*.ern", "tools/*.ern", "tour/*/*.ern", "test/**/*.ern"],
    Modules = [File || File <- ern_repository:files(Patterns),
                       not lists:prefix("test/build/", File)],
    ?assert(length(Modules) > 20),
    Modules.

doc_lines(Docs) ->
    [{Number, lists:nthtail(3, string:trim(Line, leading))} || {Number, Line} <- Docs].

%% The ```ernest fences, each its lines, an example that must not compile
%% among them.
fences(Lines) ->
    fences(Lines, none).

fences([], _) -> [];
fences([{Number, Line} | Rest], Inside) ->
    case {lists:prefix("```", string:trim(Line)), Inside} of
        {true, none} ->
            case lists:prefix("```ernest", string:trim(Line)) of
                true -> fences(Rest, []);
                false -> fences(Rest, other)
            end;
        {true, other} -> fences(Rest, none);
        {true, Fence} -> [lists:reverse(Fence) | fences(Rest, none)];
        {false, other} -> fences(Rest, other);
        {false, none} -> fences(Rest, none);
        {false, Fence} -> fences(Rest, [{Number, Line} | Fence])
    end.

%% Each text of Ernest as the lexer's tokens, their lines the file's: a
%% module whole, each example of its doc blocks, and each fence of the
%% documents. A text the lexer refuses fails the test with its file.
ernest_tokens() ->
    [{File, tokens(File, Lines)} || {File, Lines} <- ernest_texts()].

%% Each text of Ernest as its numbered lines.
ernest_texts() ->
    Texts = [{File, numbered(File)} || File <- modules()]
        ++ [{File, Fence} || File <- modules(),
                             Fence <- fences(doc_lines([{Number, Line}
                                                        || {Number, Line} <- numbered(File),
                                                           lists:prefix("///",
                                                                        string:trim(Line))]))]
        ++ [{File, Fence} || File <- ?DOCUMENTS, Fence <- fences(numbered(File))],
    [{File, Lines} || {File, Lines} <- Texts, Lines =/= []].

tokens(File, [{First, _} | _] = Lines) ->
    case ern_lexer:tokenize(lists:join("\n", [Line || {_, Line} <- Lines])) of
        {ok, Tokens} ->
            [moved(Token, First - 1) || Token <- Tokens];
        {error, _} ->
            error({not_lexed, File, First})
    end.

%% The lines of the blocks of one statement. A brace is a block's unless
%% it follows an expression or `receive`, where it holds clauses.
blocks_of_one(Tokens) ->
    blocks_of_one(Tokens, none).

blocks_of_one([], _) -> [];
blocks_of_one([{'{', _} = Brace | Rest], Before) ->
    [line(Brace) || not ends_expression(Before), statements(Rest, 0) =:= 1]
        ++ blocks_of_one(Rest, Brace);
blocks_of_one([Token | Rest], _) ->
    blocks_of_one(Rest, Token).

statements([{'}', _} | _], 0) -> 1;
statements([{';', _} | Rest], 0) -> 1 + statements(Rest, 0);
statements([Token | Rest], Depth) -> statements(Rest, Depth + depth(Token)).

%% A name or a literal, a token of three, ends an expression, as a
%% closing bracket does.
ends_expression({_, _, _}) -> true;
ends_expression({Kind, _}) -> lists:member(Kind, [')', ']', '}', '>>', 'receive']);
ends_expression(none) -> false.

depth({Kind, _}) ->
    case Kind of
        _ when Kind =:= '('; Kind =:= '#('; Kind =:= '['; Kind =:= '{'; Kind =:= '<<' -> 1;
        _ when Kind =:= ')'; Kind =:= ']'; Kind =:= '}'; Kind =:= '>>' -> -1;
        _ -> 0
    end;
depth(_) -> 0.

%% A token's line, the first of its position, which ern_parser reads so too.
line(Token) ->
    {Line, _, _, _} = element(2, Token),
    Line.

%% A token whose line is a number of lines further down; only its line is
%% read here.
moved(Token, Offset) ->
    {Line, Column, End, Previous} = element(2, Token),
    setelement(2, Token, {Line + Offset, Column, End, Previous}).

%% docs/style.md: every Erlang module is ern_<thing>, unique across the
%% repository, and a module compiled from an Ernest source is ern@<namespace>;
%% the one exception is a vendored file, which THIRD_PARTY_LICENSES names
module_name_test() ->
    ErlangFiles = ern_repository:files(["erl/*/src/*.erl", "erl/*/test/*.erl", "test/*.erl"]),
    ?assert(length(ErlangFiles) > 20),
    Names = [filename:basename(File, ".erl") || File <- ErlangFiles],
    ?assertEqual([], [Name || Name <- Names, string:prefix(Name, "ern_") =:= nomatch,
                              not vendored(Name)]),
    %% the module attribute agrees with the file name, so a grep finds both
    ?assertEqual([], [File || File <- ErlangFiles,
                              not has_line(File, "-module(" ++ filename:basename(File, ".erl")
                                                 ++ ").")]),
    %% unique across the repository, which the directory no longer disambiguates
    ?assertEqual([], Names -- lists:usort(Names)),
    Sources = lists:usort(ern_repository:files(["src/stdlib/**/*.ern"])),
    ?assert(length(Sources) > 10),
    ?assertEqual([], [File || File <- Sources, not compiled_as(File)]).

%% editors/emacs/README.md: the lines an init file needs are in the README
%% and in the header of editors/emacs/ernest-mode.el, which is installed
%% alone, and the two give the same lines in the same order
emacs_installation_test() ->
    Readme = ern_repository:read("editors/emacs/README.md"),
    Mode = ern_repository:read("editors/emacs/ernest-mode.el"),
    Blocks = tl(binary:split(Readme, <<"```elisp\n">>, [global])),
    FromReadme = lists:append([lines(hd(binary:split(Block, <<"```">>))) || Block <- Blocks]),
    [_, AfterHead] = binary:split(Mode, <<";;; Installation:\n">>),
    [Installation, _] = binary:split(AfterHead, <<";;; Code:\n">>),
    FromHeader = [Line
                  || <<";;     ", Line/binary>> <- binary:split(Installation, <<"\n">>, [global])],
    ?assert(length(FromReadme) >= 5),
    ?assertEqual(FromReadme, FromHeader).

lines(Text) ->
    [Line || Line <- binary:split(Text, <<"\n">>, [global]), Line =/= <<>>].

%% docs/design/emacs_mode.md: the Emacs mode restates §2.4's reserved words, but
%% true and false, which it paints as constants, and a subset of §2.6's
%% symbols, so a test keeps the two equal. It found `=>`
%% and `do`, which the mode painted and the language does not have.
%% report §2.4, Appendix A
emacs_mode_mirrors_the_lexer_test() ->
    Lexer = unicode:characters_to_list(ern_repository:read("erl/lexer/src/ern_lexer.erl")),
    Mode = unicode:characters_to_list(ern_repository:read("editors/emacs/ernest-mode.el")),
    ?assertEqual(lists:sort(atoms_of(Lexer, "-define(RESERVED,")),
                 lists:sort(strings_of(Mode, "(defconst ernest-reserved-words"))),
    Symbols = strings_of(Lexer, "-define(SYMBOLS,"),
    ?assert(length(Symbols) > 20),
    Painted = strings_of(Mode, "(defconst ernest-operators"),
    ?assert(length(Painted) > 5),
    ?assertEqual([], Painted -- Symbols).

%% docs/design/emacs_mode.md: the Emacs mode restates how tightly each binary
%% operator binds, which places a line an operator opens, so a test keeps
%% its table equal to the parser's. Written with the table.
%% report §2.6
emacs_mode_mirrors_the_parser_test() ->
    Parser = unicode:characters_to_list(ern_repository:read("erl/parser/src/ern_parser.erl")),
    Mode = unicode:characters_to_list(ern_repository:read("editors/emacs/ernest-mode.el")),
    {match, InParser} = re:run(Parser, "^precedence\\('([^']+)'\\) -> \\{([0-9]+),",
                               [global, multiline, {capture, all_but_first, list}]),
    {match, InMode} = re:run(body(Mode, "(defconst ernest--precedence"),
                             "\\(\"([^\"]+)\" \\. ([0-9]+)\\)",
                             [global, {capture, all_but_first, list}]),
    ?assert(length(InParser) > 10),
    ?assertEqual(lists:sort(InParser), lists:sort(InMode)).

%% The strings, or the atoms, of the list that opens at Marker: the same
%% two shapes in Erlang and in Elisp.
strings_of(Text, Marker) ->
    case re:run(body(Text, Marker), "\"([^\"]*)\"", [global, {capture, all_but_first, list}]) of
        {match, Found} -> [String || [String] <- Found];
        nomatch -> []
    end.

atoms_of(Text, Marker) ->
    [string:trim(Piece, both, "' \n\t") || Piece <- string:split(body(Text, Marker), ",", all)].

%% From the list that opens after Marker to the bracket that closes it. A
%% bracket inside a string is not one: the symbol table lists "(" and ")".
body(Text, Marker) ->
    Rest = string:find(Text, Marker),
    ?assertNotEqual(nomatch, Rest),
    {_, [Open | Body]} = string:take(string:slice(Rest, length(Marker)), "[(", true),
    Close = case Open of $[ -> $]; $( -> $) end,
    scan(Body, Open, Close, 0, []).

scan([], _, _, _, Acc) -> lists:reverse(Acc);
scan([$" | Rest], Open, Close, Depth, Acc) -> in_string(Rest, Open, Close, Depth, [$" | Acc]);
scan([Char | Rest], Open, Close, Depth, Acc) when Char =:= Open ->
    scan(Rest, Open, Close, Depth + 1, [Char | Acc]);
scan([Char | _], _, Close, 0, Acc) when Char =:= Close -> lists:reverse(Acc);
scan([Char | Rest], Open, Close, Depth, Acc) when Char =:= Close ->
    scan(Rest, Open, Close, Depth - 1, [Char | Acc]);
scan([Char | Rest], Open, Close, Depth, Acc) -> scan(Rest, Open, Close, Depth, [Char | Acc]).

in_string([$\\, Char | Rest], Open, Close, Depth, Acc) ->
    in_string(Rest, Open, Close, Depth, [Char, $\\ | Acc]);
in_string([$" | Rest], Open, Close, Depth, Acc) -> scan(Rest, Open, Close, Depth, [$" | Acc]);
in_string([Char | Rest], Open, Close, Depth, Acc) ->
    in_string(Rest, Open, Close, Depth, [Char | Acc]);
in_string([], _, _, _, Acc) -> lists:reverse(Acc).

%% THIRD_PARTY_LICENSES names every borrowed file, so the exception is checked
%% rather than listed twice.
vendored(Name) ->
    string:find(ern_repository:read("THIRD_PARTY_LICENSES"), Name ++ ".erl") =/= nomatch.

%% build/stdlib holds the standard library, each module in the .erc of its
%% path, under the Erlang name erlang_module/1 gives it.
compiled_as(Relative) ->
    Component = filename:rootname(filename:basename(Relative)),
    Erc = filename:join([?ROOT, "build", "stdlib", Component ++ ".erc"]),
    case file:read_file(Erc) of
        {ok, Beam} ->
            {ok, {Module, _}} = beam_lib:chunks(Beam, []),
            Module =:= ern_namespace:erlang_module(ern_namespace:namespace([Component]));
        {error, _} ->
            false
    end.

has_line(Relative, Line) ->
    lists:member(Line, [Text || {_, Text} <- numbered(Relative)]).

numbered(Relative) ->
    Text = unicode:characters_to_list(ern_repository:read(Relative)),
    Lines = string:split(Text, "\n", all),
    lists:zip(lists:seq(1, length(Lines)), Lines).
