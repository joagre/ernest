%% The documents' citations resolve: every `§x.y`, `Appendix X`, and `E.n`
%% written in a live document names a heading of the report, and the
%% guide's own bare `§x.y` names a heading of the guide. docs/decisions.md
%% is history and is not checked.
-module(ern_docs_tests).

-include_lib("eunit/include/eunit.hrl").

-export([write_contents/0]).

-define(ROOT, "..").

%% The documents with a contents list, and the lines that bound it.
-define(CONTENTS, ["ernest_report.md", "ernest_guide.md"]).
-define(BEGIN, <<"<!-- contents -->">>).
-define(END, <<"<!-- /contents -->">>).

%% report §11, README "Building": `make xref`
citations_resolve_test() ->
    Report = read("ernest_report.md"),
    Guide = read("ernest_guide.md"),
    ReportHeads = headings(Report),
    GuideHeads = headings(Guide),
    Live = ["ernest_report.md", "README.md", "CLAUDE.md", "docs/implementation_plan.md",
            "docs/architecture.md", "docs/shell_design.md", "docs/module_doc_template.md",
            "docs/coherence.md", "docs/review.md", "docs/style.md", "docs/emacs_mode.md",
            "docs/node_protocol.md", "docs/code_distribution.md", "shell/README.md"]
        ++ examples() ++ stdlib() ++ shell(),
    Dangling =
        [{F, C} || F <- Live, C <- cites(read(F)), not resolves(C, report, ReportHeads, GuideHeads)]
        ++ [{"ernest_guide.md", C} || C <- cites(Guide),
                                      not resolves(C, guide, ReportHeads, GuideHeads)],
    ?assertEqual([], Dangling).

%% ernest_report.md, ernest_guide.md, README "Building": a document's
%% contents list is its top-level sections, its headings of level two, each
%% linked to its heading, which `make contents` writes
contents_test() ->
    [?assertEqual({F, contents(Bin)}, {F, listed(Bin)}) || F <- ?CONTENTS, Bin <- [read(F)]].

%% Rewrite the contents list of every document that has one.
-spec write_contents() -> ok.
write_contents() ->
    lists:foreach(fun(F) ->
                      Bin = read(F),
                      [Before, Rest] = binary:split(Bin, ?BEGIN),
                      [_, After] = binary:split(Rest, ?END),
                      ok = file:write_file(filename:join(?ROOT, F),
                                           [Before, ?BEGIN, contents(Bin), ?END, After])
                  end, ?CONTENTS).

listed(Bin) ->
    [_, Rest] = binary:split(Bin, ?BEGIN),
    [List, _] = binary:split(Rest, ?END),
    List.

%% The list: a line per heading of level two, linked by the anchor a
%% renderer gives it; the anchors are counted over every heading, since a
%% renderer numbers a repeated one whatever its level.
contents(Bin) ->
    Entries = [["- [", Text, "](#", Anchor, ")\n"]
               || {2, Text, Anchor} <- anchored(heads(Bin))],
    iolist_to_binary(["\n", Entries]).

%% Every heading outside a fenced block, with its level and its text.
heads(Bin) ->
    heads(binary:split(Bin, <<"\n">>, [global]), false, []).

heads([], _, Acc) ->
    lists:reverse(Acc);
heads([<<"```", _/binary>> | Rest], Fenced, Acc) ->
    heads(Rest, not Fenced, Acc);
heads([L | Rest], false, Acc) ->
    case re:run(L, "^(#{1,6}) +(.*?) *$", [{capture, all_but_first, binary}, unicode]) of
        {match, [Hashes, Text]} -> heads(Rest, false, [{byte_size(Hashes), Text} | Acc]);
        nomatch -> heads(Rest, false, Acc)
    end;
heads([_ | Rest], true, Acc) ->
    heads(Rest, true, Acc).

%% GitHub's anchors: lowercase, every character but a letter, a digit, an
%% underscore, a space or a hyphen dropped, spaces as hyphens, and a second
%% heading of the same anchor numbered `-1`, a third `-2`.
anchored(Heads) ->
    {Anchored, _} =
        lists:mapfoldl(
          fun({Level, Text}, Seen) ->
              Lower = string:lowercase(Text),
              Kept = re:replace(Lower, "[^\\p{L}\\p{M}\\p{N}_ \\-]", "",
                                [global, unicode, ucp, {return, binary}]),
              Base = binary:replace(Kept, <<" ">>, <<"-">>, [global]),
              N = maps:get(Base, Seen, 0),
              Anchor = case N of
                           0 -> Base;
                           _ -> <<Base/binary, "-", (integer_to_binary(N))/binary>>
                       end,
              {{Level, Text, Anchor}, Seen#{Base => N + 1}}
          end, #{}, Heads),
    Anchored.

%% docs/style.md, README "Layout of the repository": a document that says
%% where things are names things that are there. The report and the guide
%% name paths a program might have, `net/http.ern`, and the plan and the
%% naming record name paths that are gone or not yet written, so the four
%% checked here are the ones that describe the repository as it is.
document_paths_test() ->
    Where = ["README.md", "CLAUDE.md", "docs/architecture.md", "docs/style.md"],
    Missing = [{F, P} || F <- Where, P <- paths(read(F)),
                         not exists(P)],
    ?assertEqual([], Missing).

%% A backticked path under one of the repository's own directories. A
%% metavariable is written `<name>`, as docs/style.md writes `ern_<thing>`,
%% and a wildcard stands for a set, so neither names one file.
paths(Bin) ->
    Tops = ["erl/", "docs/", "test/", "bin/", "stdlib/", "examples/", "build/"],
    Quoted = [B || B <- binary:split(Bin, <<"`">>, [global])],
    [binary_to_list(P) || {I, P} <- lists:zip(lists:seq(1, length(Quoted)), Quoted),
                          I rem 2 =:= 0,
                          lists:any(fun(T) -> lists:prefix(T, binary_to_list(P)) end, Tops),
                          binary:match(P, [<<"*">>, <<"<">>]) =:= nomatch,
                          binary:last(P) =/= $/].

exists(Rel) ->
    filelib:is_file(filename:join(?ROOT, Rel)).

read(Rel) ->
    {ok, Bin} = file:read_file(filename:join(?ROOT, Rel)),
    Bin.

%% A name that begins with a dot is no module (report §11.1's path shape),
%% and an editor's lock file, `.#main.ern`, is one that may not be readable.
examples() ->
    [filename:join("examples", F)
     || F <- filelib:wildcard("**/*.ern", filename:join(?ROOT, "examples")),
        hd(filename:basename(F)) =/= $.].

%% The shell's Ernest source, whose comments cite the report as the
%% standard library's do.
shell() ->
    [filename:join("shell", F)
     || F <- filelib:wildcard("**/*.ern", filename:join(?ROOT, "shell"))].

stdlib() ->
    [filename:join("stdlib", F)
     || F <- filelib:wildcard("*.ern", filename:join(?ROOT, "stdlib"))]
    ++ [filename:join("libs", F)
        || F <- filelib:wildcard("*/*.ern", filename:join(?ROOT, "libs"))].

%% "3.9", "3", "Appendix A", "E.12" for the headings of a document.
headings(Bin) ->
    Lines = binary:split(Bin, <<"\n">>, [global]),
    lists:append([heading(L) || L <- Lines]).

heading(L) ->
    case re:run(L, "^#{1,3} (?:([0-9]+(?:\\.[0-9]+)?)\\.? |Appendix ([A-F])(?:\\.([0-9]+))?\\.)",
                [{capture, all_but_first, list}]) of
        {match, [N]} -> [N];
        {match, [[], A]} -> ["Appendix " ++ A];
        {match, [[], A, E]} -> ["Appendix " ++ A, A ++ "." ++ E];
        nomatch -> []
    end.

%% Every citation in a document: {Kind, Target} with Kind report, guide,
%% or bare, the bare ones resolved by the document's own convention.
cites(Bin) ->
    Sec = case re:run(Bin, "([Rr]eport|[Gg]uide)?,? ?§([0-9]+(?:\\.[0-9]+)?)",
                      [global, unicode, {capture, all_but_first, list}]) of
              {match, Ms} -> [{kind(W), N} || [W, N] <- Ms];
              nomatch -> []
          end,
    App = case re:run(Bin, "Appendix ([A-F])(?:\\.([0-9]+))?",
                      [global, {capture, all_but_first, list}]) of
              {match, As} -> lists:append([case A of [X] -> [{report, "Appendix " ++ X}];
                                                     [X, E] -> [{report, X ++ "." ++ E}]
                                           end || A <- As]);
              nomatch -> []
          end,
    E0 = case re:run(Bin, "\\bE\\.([0-9]+)\\b", [global, {capture, all_but_first, list}]) of
             {match, Es} -> [{report, "E." ++ E} || [E] <- Es];
             nomatch -> []
         end,
    lists:usort(Sec ++ App ++ E0).

kind([]) -> bare;
kind(W) -> list_to_atom(string:lowercase(W)).

resolves({report, T}, _, ReportHeads, _) -> lists:member(T, ReportHeads);
resolves({guide, T}, _, _, GuideHeads) -> lists:member(T, GuideHeads);
resolves({bare, T}, report, ReportHeads, _) -> lists:member(T, ReportHeads);
resolves({bare, T}, guide, _, GuideHeads) -> lists:member(T, GuideHeads).
