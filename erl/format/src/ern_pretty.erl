%% The layout ern_format builds, and the printer that lays it out in 100
%% columns (report §11.6). It is Wadler's prettier printer,
%% evaluated strictly as Lindig's is, with what §11.6's layout needs
%% beside it: alignment to a column, a choice between two layouts made on
%% the first line of the first, and a trailing comment that ends its line.
%%
%% A layout is text, a list of layouts one after the other, or one of these:
%%   line, softline   a space or nothing on one line, a line break when
%%                    the group around it breaks
%%   hardline         a line break always; a group holding one breaks
%%   blank            a blank line where a line break falls here
%%   mark             nothing; a body choice's trial reached it
%%   {nest, N, Inner}   Inner's line breaks indent N more
%%   {align, Inner}     Inner's line breaks indent to the column it begins at
%%   {group, Inner}     Inner on one line when that fits, else every break taken
%%   {bracket, Inner}   a group, which a fit after it takes flat, so that of
%%                      two brackets on a line the first breaks
%%   {choice, Kind, First, Second}  First when its first line fits and, for
%%                    hug and branch, ends in a brace, or, for body, reaches
%%                    its mark or ends in a brace or `then`, or, for
%%                    alternative, reaches its mark or ends in `(`; else Second
%%   {suffix, Text}   Text at the end of the line, which then ends
-module(ern_pretty).

-export([render/1]).

-export_type([layout/0]).

-type layout() :: unicode:unicode_binary()
                | [layout()]
                | line | softline | hardline | blank | mark
                | {nest, integer(), layout()}
                | {align, layout()}
                | {group, layout()}
                | {bracket, layout()}
                | {choice, hug | branch | body | alternative, layout(), layout()}
                | {suffix, unicode:unicode_binary()}.

-define(WIDTH, 100).

%% The printer's state: the column, a line break not yet written (its
%% indentation, and whether a blank line goes with it), the line being
%% written, reversed, the lines finished, reversed, whether anything was
%% written, the trailing comments waiting for the line's end, and, in a
%% choice's trial, whether its mark was reached.
-record(printer, {column = 0, pending = none, line = [], lines = [], started = false,
                  suffixes = [], trial = false, marked = false}).

%% The text a layout lays out, each line without the spaces the layout
%% wrote at its end, ending in a line feed.
-spec render(layout()) -> unicode:unicode_binary().
render(Layout) ->
    Printer = print([{0, break, Layout}], #printer{}),
    Lines = lists:reverse([finish_line(Printer) | Printer#printer.lines]),
    unicode:characters_to_binary([lists:join($\n, Lines), $\n]).

%%
%% The printer: a stack of {Indent, Mode, Layout}, Mode flat or break.
%%

print([], Printer) ->
    Printer;
print([{Indent, Mode, Layout} | Rest], Printer) ->
    case Layout of
        Text when is_binary(Text) -> print(Rest, text(Text, Indent, Printer));
        Layouts when is_list(Layouts) ->
            print([{Indent, Mode, Part} || Part <- Layouts] ++ Rest, Printer);
        line when Mode =:= flat -> print(Rest, text(<<" ">>, Indent, Printer));
        softline when Mode =:= flat -> print(Rest, Printer);
        line -> print(Rest, newline(Indent, Printer));
        softline -> print(Rest, newline(Indent, Printer));
        hardline -> print(Rest, newline(Indent, Printer));
        blank -> print(Rest, blank(Printer));
        mark -> print(Rest, Printer#printer{marked = true});
        {nest, More, Inner} -> print([{Indent + More, Mode, Inner} | Rest], Printer);
        {align, Inner} -> print([{column(Printer), Mode, Inner} | Rest], Printer);
        {bracket, Inner} -> print([{Indent, Mode, {group, Inner}} | Rest], Printer);
        {group, Inner} when Mode =:= flat -> print([{Indent, flat, Inner} | Rest], Printer);
        {group, Inner} ->
            GroupMode = case fits(?WIDTH - column(Printer), [{Indent, flat, Inner} | Rest]) of
                            true -> flat;
                            false -> break
                        end,
            print([{Indent, GroupMode, Inner} | Rest], Printer);
        {choice, _, First, _} when Mode =:= flat -> print([{Indent, flat, First} | Rest], Printer);
        {choice, Kind, First, Second} ->
            case accept(Kind, [{Indent, break, First} | Rest], Printer) of
                true -> print([{Indent, break, First} | Rest], Printer);
                false -> print([{Indent, break, Second} | Rest], Printer)
            end;
        {suffix, Text} -> print(Rest, Printer#printer{suffixes = [Text | Printer#printer.suffixes]})
    end.

%%
%% Writing
%%

column(#printer{pending = {Indent, _}}) -> Indent;
column(#printer{column = Column}) -> Column.

%% Spaces that would begin a line are dropped: indentation is the
%% printer's. A trailing comment ends its line, so code after one on the
%% same line starts a new line first.
text(Text, Indent, #printer{suffixes = [_ | _], pending = none} = Printer) ->
    case is_space(Text) of
        true -> Printer;
        false -> text(Text, Indent, newline(Indent, Printer))
    end;
text(Text, _Indent, #printer{pending = {BreakIndent, Blank}} = Printer) ->
    case is_space(Text) of
        true -> Printer;
        false ->
            Lines = case Blank of
                        true -> [<<>>, finish_line(Printer) | Printer#printer.lines];
                        false -> [finish_line(Printer) | Printer#printer.lines]
                    end,
            Printer1 = Printer#printer{pending = none, lines = Lines, suffixes = [],
                                       line = [binary:copy(<<" ">>, BreakIndent)],
                                       column = BreakIndent},
            append(Text, Printer1)
    end;
text(Text, _Indent, #printer{started = false} = Printer) ->
    case is_space(Text) of
        true -> Printer;
        false -> append(Text, Printer#printer{started = true})
    end;
%% A space the layout writes after one it wrote is one space: a block
%% comment is kept apart from what follows it by a space of its own, which
%% a space the layout puts there anyway joins.
text(Text, _Indent, #printer{line = [Last | _]} = Printer)
  when Text =:= <<" ">>, Last =:= <<" ">> ->
    Printer;
text(Text, _Indent, Printer) ->
    append(Text, Printer).

append(Text, Printer) ->
    Column = case binary:split(Text, <<"\n">>, [global]) of
                 [One] -> Printer#printer.column + string:length(One);
                 Parts -> string:length(lists:last(Parts))
             end,
    Printer#printer{line = [Text | Printer#printer.line], column = Column, started = true}.

%% A line break, not written until text follows it, so that two in a row
%% make one, the later's indentation winning, and one at the very end
%% makes none. In a trial, the first line ends here.
newline(_Indent, #printer{started = false} = Printer) ->
    Printer;
newline(_Indent, #printer{trial = true} = Printer) ->
    throw({first_line, Printer});
newline(Indent, #printer{pending = {_, Blank}} = Printer) ->
    Printer#printer{pending = {Indent, Blank}};
newline(Indent, Printer) ->
    Printer#printer{pending = {Indent, false}}.

blank(#printer{pending = {Indent, _}} = Printer) -> Printer#printer{pending = {Indent, true}};
blank(Printer) -> Printer.

%% The spaces the layout wrote at a line's end are dropped; a text keeps
%% the spaces it was written with, as a doc line does (report §11.6).
finish_line(#printer{line = Line, suffixes = Suffixes}) ->
    unicode:characters_to_binary([lists:reverse(without_laid_spaces(Line)),
                                  lists:reverse(Suffixes)]).

without_laid_spaces([Text | Rest] = Line) ->
    case is_space(Text) of
        true -> without_laid_spaces(Rest);
        false -> Line
    end;
without_laid_spaces([]) ->
    [].

is_space(Text) ->
    string:trim(Text, both, " ") =:= <<>>.

%%
%% Fitting
%%

%% Whether what the stack writes up to its first line break fits in Room
%% columns: the group asked about flat, what follows it in the mode it has,
%% so that a group after it, which may yet break, ends the line at its
%% first break, as Prettier's printer has it; a bracket after it is taken
%% flat, since the first of two brackets on a line breaks first. A hard
%% line break inside a flat group cannot be; code after a trailing comment
%% on the same line cannot be. A body or a branch choice after the group
%% may begin the next line, so the line may end there.
fits(Room, Stack) ->
    fits(Room, Stack, false).

fits(Room, _, _) when Room < 0 -> false;
fits(_, [], _) -> true;
fits(Room, [{Indent, Mode, Layout} | Rest], Ended) ->
    case Layout of
        Text when is_binary(Text) ->
            case {Ended andalso not is_space(Text), binary:split(Text, <<"\n">>)} of
                {true, _} -> false;
                {false, [One]} -> fits(Room - string:length(One), Rest, Ended);
                {false, [First, _]} -> Room - string:length(First) >= 0
            end;
        Layouts when is_list(Layouts) ->
            fits(Room, [{Indent, Mode, Part} || Part <- Layouts] ++ Rest, Ended);
        line when Mode =:= flat ->
            case Ended of
                true -> false;
                false -> fits(Room - 1, Rest, Ended)
            end;
        softline when Mode =:= flat -> fits(Room, Rest, Ended);
        hardline when Mode =:= flat -> false;
        _ when Layout =:= line; Layout =:= softline; Layout =:= hardline -> true;
        _ when Layout =:= blank; Layout =:= mark -> fits(Room, Rest, Ended);
        {nest, More, Inner} -> fits(Room, [{Indent + More, Mode, Inner} | Rest], Ended);
        {align, Inner} -> fits(Room, [{Indent, Mode, Inner} | Rest], Ended);
        {group, Inner} -> fits(Room, [{Indent, Mode, Inner} | Rest], Ended);
        {bracket, Inner} -> fits(Room, [{Indent, flat, Inner} | Rest], Ended);
        {choice, hug, First, _} -> fits(Room, [{Indent, Mode, First} | Rest], Ended);
        {choice, _, First, _} when Mode =:= flat ->
            fits(Room, [{Indent, Mode, First} | Rest], Ended);
        {choice, _, _, _} -> true;
        {suffix, _} -> fits(Room, Rest, true)
    end.

%% A choice takes its first layout when a trial of it, written up to its
%% first line break, fits, and: for hug and branch, ends in the brace that
%% opens what runs over lines; for body, reaches the mark after the body or
%% ends in a brace or `then`; for alternative, reaches the mark or ends in
%% `(`.
accept(Kind, Stack, Printer) ->
    Start = case Printer#printer.pending of
                {Indent, _} ->
                    Printer#printer{pending = none, column = Indent, line = [], started = true};
                none ->
                    Printer#printer{line = []}
            end,
    Trial = Start#printer{trial = true, marked = false},
    Tried = try print(Stack, Trial) catch throw:{first_line, Stopped} -> Stopped end,
    Written = string:trim(unicode:characters_to_binary(lists:reverse(Tried#printer.line)),
                          trailing, " "),
    Tried#printer.column =< ?WIDTH andalso
        case Kind of
            _ when Kind =:= hug; Kind =:= branch -> ends_with(Written, <<"{">>);
            body -> Tried#printer.marked orelse ends_with(Written, <<"{">>)
                        orelse ends_with(Written, <<" then">>);
            %% a type's one alternative stays after its `=` where it fits
            %% whole, or where a doc block breaks its bracket after `(`
            alternative -> Tried#printer.marked orelse ends_with(Written, <<"(">>)
        end.

ends_with(Text, Ending) ->
    string:find(Text, Ending, trailing) =:= Ending.
