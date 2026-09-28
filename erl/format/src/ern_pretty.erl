%% The layout ern_format builds, and the printer that lays it out in 100
%% columns (report §11.6, docs/style.md). It is Wadler's prettier printer,
%% evaluated strictly as Lindig's is, with what the style guide needs
%% beside it: alignment to a column, a fill, a choice between two layouts
%% made on the first line of the first, and a trailing comment that ends
%% its line.
%%
%% A doc is text, a list of docs one after the other, or one of these:
%%   line, softline   a space or nothing on one line, a line break when
%%                    the group around it breaks
%%   hardline         a line break always; a group holding one breaks
%%   blank            a blank line where a line break falls here
%%   mark             nothing; a body choice's trial reached it
%%   {nest, N, D}     D's line breaks indent N more
%%   {align, D}       D's line breaks indent to the column D begins at
%%   {group, D}       D on one line when that fits, else every break taken
%%   {bracket, D}     a group, which a fit after it takes flat, so that of
%%                    two brackets on a line the first breaks
%%   {fill, Xs}       items and separators alternating; a separator breaks
%%                    only where the item after it does not fit
%%   {choice, K, A, B}  A when its first line fits and, for hug and
%%                    branch, ends in a brace, or, for body, reaches its
%%                    mark or ends in a brace or `then`, or, for
%%                    alternative, reaches its mark or ends in `(`; else B
%%   {suffix, T}      T at the end of the line, which then ends
-module(ern_pretty).

-export([render/1]).

-export_type([doc/0]).

-type doc() :: unicode:unicode_binary()
             | [doc()]
             | line | softline | hardline | blank | mark
             | {nest, integer(), doc()}
             | {align, doc()}
             | {group, doc()}
             | {bracket, doc()}
             | {fill, [doc()]}
             | {choice, hug | branch | body | alternative, doc(), doc()}
             | {suffix, unicode:unicode_binary()}.

-define(WIDTH, 100).

%% The printer's state: the column, a line break not yet written (its
%% indentation, and whether a blank line goes with it), the line being
%% written, reversed, the lines finished, reversed, whether anything was
%% written, the trailing comments waiting for the line's end, and, in a
%% choice's trial, whether its mark was reached.
-record(p, {col = 0, pending = none, line = [], lines = [], started = false,
            suffix = [], trial = false, marked = false}).

%% The text a doc lays out, each line without the spaces the layout wrote
%% at its end, ending in a line feed.
-spec render(doc()) -> unicode:unicode_binary().
render(Doc) ->
    P = go([{0, break, Doc}], #p{}),
    Lines = lists:reverse([finish_line(P) | P#p.lines]),
    unicode:characters_to_binary([lists:join($\n, Lines), $\n]).

%%
%% The printer: a stack of {Indent, Mode, Doc}, Mode flat or break.
%%

go([], P) ->
    P;
go([{I, M, D} | Rest], P) ->
    case D of
        Text when is_binary(Text) -> go(Rest, text(Text, I, P));
        Ds when is_list(Ds) -> go([{I, M, X} || X <- Ds] ++ Rest, P);
        line when M =:= flat -> go(Rest, text(<<" ">>, I, P));
        softline when M =:= flat -> go(Rest, P);
        line -> go(Rest, newline(I, P));
        softline -> go(Rest, newline(I, P));
        hardline -> go(Rest, newline(I, P));
        blank -> go(Rest, blank(P));
        mark -> go(Rest, P#p{marked = true});
        {nest, N, X} -> go([{I + N, M, X} | Rest], P);
        {align, X} -> go([{column(P), M, X} | Rest], P);
        {bracket, X} -> go([{I, M, {group, X}} | Rest], P);
        {group, X} when M =:= flat -> go([{I, flat, X} | Rest], P);
        {group, X} ->
            Mode = case fits(?WIDTH - column(P), [{I, flat, X} | Rest]) of
                       true -> flat;
                       false -> break
                   end,
            go([{I, Mode, X} | Rest], P);
        {fill, Xs} -> fill(Xs, I, M, Rest, P);
        {choice, _, A, _} when M =:= flat -> go([{I, flat, A} | Rest], P);
        {choice, Kind, A, B} ->
            case accept(Kind, [{I, break, A} | Rest], P) of
                true -> go([{I, break, A} | Rest], P);
                false -> go([{I, break, B} | Rest], P)
            end;
        {suffix, Text} -> go(Rest, P#p{suffix = [Text | P#p.suffix]})
    end.

%% A fill lays each item out in the mode around it and breaks a separator
%% only where the separator and the item after it do not fit flat.
fill([], _I, _M, Rest, P) ->
    go(Rest, P);
fill([X], I, M, Rest, P) ->
    go([{I, M, X} | Rest], P);
fill([X, Sep, Y | Xs], I, flat, Rest, P) ->
    go([{I, flat, X}, {I, flat, Sep}, {I, flat, {fill, [Y | Xs]}} | Rest], P);
fill([X, Sep, Y | Xs], I, break, Rest, P) ->
    P1 = go([{I, break, X}], P),
    SepMode = case fits(?WIDTH - column(P1), [{I, flat, Sep}, {I, flat, Y}]) of
                  true -> flat;
                  false -> break
              end,
    P2 = go([{I, SepMode, Sep}], P1),
    fill([Y | Xs], I, break, Rest, P2).

%%
%% Writing
%%

column(#p{pending = {Indent, _}}) -> Indent;
column(#p{col = Col}) -> Col.

%% Spaces that would begin a line are dropped: indentation is the
%% printer's. A trailing comment ends its line, so code after one on the
%% same line starts a new line first.
text(Text, I, #p{suffix = [_ | _], pending = none} = P) ->
    case is_space(Text) of
        true -> P;
        false -> text(Text, I, newline(I, P))
    end;
text(Text, _I, #p{pending = {Indent, Blank}} = P) ->
    case is_space(Text) of
        true -> P;
        false ->
            Lines = case Blank of
                        true -> [<<>>, finish_line(P) | P#p.lines];
                        false -> [finish_line(P) | P#p.lines]
                    end,
            P1 = P#p{pending = none, lines = Lines, suffix = [],
                     line = [binary:copy(<<" ">>, Indent)], col = Indent},
            append(Text, P1)
    end;
text(Text, _I, #p{started = false} = P) ->
    case is_space(Text) of
        true -> P;
        false -> append(Text, P#p{started = true})
    end;
text(Text, _I, P) ->
    append(Text, P).

append(Text, P) ->
    Col = case binary:split(Text, <<"\n">>, [global]) of
              [One] -> P#p.col + string:length(One);
              Parts -> string:length(lists:last(Parts))
          end,
    P#p{line = [Text | P#p.line], col = Col, started = true}.

%% A line break, not written until text follows it, so that two in a row
%% make one, the later's indentation winning, and one at the very end
%% makes none. In a trial, the first line ends here.
newline(_I, #p{started = false} = P) ->
    P;
newline(_I, #p{trial = true} = P) ->
    throw({first_line, P});
newline(I, #p{pending = {_, Blank}} = P) ->
    P#p{pending = {I, Blank}};
newline(I, P) ->
    P#p{pending = {I, false}}.

blank(#p{pending = {Indent, _}} = P) -> P#p{pending = {Indent, true}};
blank(P) -> P.

%% The spaces the layout wrote at a line's end are dropped; a text keeps
%% the spaces it was written with, as a doc line does (report §11.6).
finish_line(#p{line = Line, suffix = Suffix}) ->
    unicode:characters_to_binary([lists:reverse(laid_spaces(Line)), lists:reverse(Suffix)]).

laid_spaces([Text | Rest] = Line) ->
    case is_space(Text) of
        true -> laid_spaces(Rest);
        false -> Line
    end;
laid_spaces([]) ->
    [].

is_space(Text) ->
    string:trim(Text, both, " ") =:= <<>>.

%%
%% Fitting
%%

%% Whether what the stack writes up to its first line break fits in W
%% columns: the group asked about flat, what follows it in the mode it has,
%% so that a group after it, which may yet break, ends the line at its
%% first break, as Prettier's printer has it; a bracket after it is taken
%% flat, since the first of two brackets on a line breaks first. A hard line break inside a
%% flat group cannot be; code after a trailing comment on the same line
%% cannot be. A body or a branch choice after the group may begin the next
%% line, so the line may end there.
fits(W, Stack) ->
    fits(W, Stack, false).

fits(W, _, _) when W < 0 -> false;
fits(_, [], _) -> true;
fits(W, [{I, M, D} | Rest], Ended) ->
    case D of
        Text when is_binary(Text) ->
            case {Ended andalso not is_space(Text), binary:split(Text, <<"\n">>)} of
                {true, _} -> false;
                {false, [One]} -> fits(W - string:length(One), Rest, Ended);
                {false, [First, _]} -> W - string:length(First) >= 0
            end;
        Ds when is_list(Ds) -> fits(W, [{I, M, X} || X <- Ds] ++ Rest, Ended);
        line when M =:= flat ->
            case Ended of
                true -> false;
                false -> fits(W - 1, Rest, Ended)
            end;
        softline when M =:= flat -> fits(W, Rest, Ended);
        hardline when M =:= flat -> false;
        _ when D =:= line; D =:= softline; D =:= hardline -> true;
        _ when D =:= blank; D =:= mark -> fits(W, Rest, Ended);
        {nest, N, X} -> fits(W, [{I + N, M, X} | Rest], Ended);
        {align, X} -> fits(W, [{I, M, X} | Rest], Ended);
        {group, X} -> fits(W, [{I, M, X} | Rest], Ended);
        {bracket, X} -> fits(W, [{I, flat, X} | Rest], Ended);
        {fill, Xs} -> fits(W, [{I, M, X} || X <- Xs] ++ Rest, Ended);
        {choice, hug, A, _} -> fits(W, [{I, M, A} | Rest], Ended);
        {choice, _, A, _} when M =:= flat -> fits(W, [{I, M, A} | Rest], Ended);
        {choice, _, _, _} -> true;
        {suffix, _} -> fits(W, Rest, true)
    end.

%% A choice takes its first layout when a trial of it, written up to its
%% first line break, fits, and for hug ends in the brace that opens what
%% runs over lines, for body either reaches the mark after the body or ends
%% in a brace or `then`.
accept(Kind, Stack, P) ->
    Start = case P#p.pending of
                {Indent, _} -> P#p{pending = none, col = Indent, line = [], started = true};
                none -> P#p{line = []}
            end,
    Trial = Start#p{trial = true, marked = false},
    End = try go(Stack, Trial) catch throw:{first_line, Q} -> Q end,
    Written = string:trim(unicode:characters_to_binary(lists:reverse(End#p.line)),
                          trailing, " "),
    End#p.col =< ?WIDTH andalso
        case Kind of
            _ when Kind =:= hug; Kind =:= branch -> ends_with(Written, <<"{">>);
            body -> End#p.marked orelse ends_with(Written, <<"{">>)
                        orelse ends_with(Written, <<" then">>);
            %% a type's one alternative stays after its `=` where it fits
            %% whole, or where a doc block breaks its bracket after `(`
            alternative -> End#p.marked orelse ends_with(Written, <<"(">>)
        end.

ends_with(Text, End) ->
    string:find(Text, End, trailing) =:= End.
