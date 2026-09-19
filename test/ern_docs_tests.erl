%% The documents' citations resolve: every `§x.y`, `Appendix X`, and `E.n`
%% written in a live document names a heading of the report, and the
%% guide's own bare `§x.y` names a heading of the guide. docs/decisions.md
%% is history and is not checked.
-module(ern_docs_tests).

-include_lib("eunit/include/eunit.hrl").

-define(ROOT, "..").

%% report §11, README "Building": `make xref`
citations_resolve_test() ->
    Report = read("ernest_report.md"),
    Guide = read("ernest_guide.md"),
    ReportHeads = headings(Report),
    GuideHeads = headings(Guide),
    Live = ["ernest_report.md", "README.md", "CLAUDE.md", "docs/implementation_plan.md",
            "docs/architecture.md", "docs/shell_design.md" | examples()],
    Dangling =
        [{F, C} || F <- Live, C <- cites(read(F)), not resolves(C, report, ReportHeads, GuideHeads)]
        ++ [{"ernest_guide.md", C} || C <- cites(Guide),
                                      not resolves(C, guide, ReportHeads, GuideHeads)],
    ?assertEqual([], Dangling).

read(Rel) ->
    {ok, Bin} = file:read_file(filename:join(?ROOT, Rel)),
    Bin.

examples() ->
    [filename:join("examples", F)
     || F <- filelib:wildcard("**/*.ern", filename:join(?ROOT, "examples"))].

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
