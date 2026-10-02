%% Diagnostics, report §11.5: one record for every stage, rendered as the
%% first line `file:line:column: message`, then the source with a gutter,
%% the spans underlined and labelled, and at most one help line.
-module(ern_diagnostic).

-export([span/1, short/2, format/3]).

-export_type([position/0, span/0, diagnostic/0]).

-include_lib("utils/include/ern_diagnostic.hrl").

-type span() :: {pos_integer(), pos_integer(), {pos_integer(), pos_integer()}}.
%% line, column, and the end, exclusive, as line and column
-type diagnostic() :: #diagnostic{}.

%% A token's position, which carries the end of the token before it as
%% well; the lexer's `position()` is this type.
-type position() :: {pos_integer(), pos_integer(), {pos_integer(), pos_integer()},
                     {pos_integer(), pos_integer()}}.

%% A span from a token position or from a node position, which is one.
-spec span(position() | span()) -> span().
span({Line, Column, End, _PreviousEnd}) -> {Line, Column, End};
span({_, _, _} = Span) -> Span.

%% The first line alone: what a tool parses.
-spec short(string(), diagnostic()) -> string().
short(File, #diagnostic{span = {Line, Column, _}, message = Message}) ->
    lists:flatten(io_lib:format("~ts:~B:~B: ~ts", [File, Line, Column, Message])).

%% The first line, then the source with the spans underlined, the primary
%% with `^`, each label's with `-` followed by the label, and the help line.
-spec format(string(), unicode:chardata(), diagnostic()) -> string().
format(File, Source, #diagnostic{span = Span, labels = Labels, help = Help} = Diagnostic) ->
    Lines = lines(Source),
    Marks = lists:sort([{Span, "^", ""}
                        | [{LabelSpan, "-", Label} || {LabelSpan, Label} <- Labels]]),
    Width = length(integer_to_list(lists:max([Line || {{Line, _, _}, _, _} <- Marks]))),
    Body = marks(Marks, Lines, Width, 0),
    HelpLine = case Help of
                   undefined -> [];
                   _ -> [gutter(Width), "= help: ", Help, "\n"]
               end,
    lists:flatten([short(File, Diagnostic), "\n", Body, HelpLine]).

%% Each mark: the line before it when it is the first mark and the line
%% exists, a line `...` where lines are passed over since the last one
%% shown (report §11.5), the source line unless it was just printed, then
%% the underline.
marks([], _, _, _) ->
    [];
marks([{{Line, Column, End}, UnderlineChar, Label} | Rest], Lines, Width, Printed) ->
    LineBefore = case Printed =:= 0 andalso Line > 1 of
                     true -> source_line(Line - 1, Lines, Width);
                     false when Printed > 0, Line > Printed + 1 -> "...\n";
                     false -> []
                 end,
    SourceLine = case Line =:= Printed of
                     true -> [];
                     false -> source_line(Line, Lines, Width)
                 end,
    Suffix = case Label of "" -> ""; _ -> " " ++ Label end,
    Underline = [gutter(Width), lists:duplicate(Column - 1, $\s),
                 lists:duplicate(width(Line, Column, End, Lines), hd(UnderlineChar)), Suffix,
                 "\n"],
    [LineBefore, SourceLine, Underline | marks(Rest, Lines, Width, Line)].

source_line(LineNumber, Lines, Width) ->
    case LineNumber =< length(Lines) of
        true -> [io_lib:format("~*B | ", [Width, LineNumber]), lists:nth(LineNumber, Lines), "\n"];
        false -> []
    end.

gutter(Width) -> [lists:duplicate(Width, $\s), " | "].

%% The underline's width: the span on its first line, at least one column.
width(Line, Column, {Line, EndColumn}, _) ->
    max(1, EndColumn - Column);
width(Line, Column, _, Lines) when Line =< length(Lines) ->
    max(1, length(lists:nth(Line, Lines)) - Column + 1);
width(_, _, _, _) ->
    1.

%% Report §11.5: a line ends at a line feed, and a carriage return before
%% it ends the line with it; a carriage return anywhere else is a column
%% of the line, as the lexer counts it, shown as its picture.
lines(Source) ->
    [[shown(Char) || Char <- without_return(Line)]
     || Line <- string:split(chars(Source), "\n", all)].

without_return(Line) ->
    case lists:reverse(Line) of
        [$\r | Rest] -> lists:reverse(Rest);
        _ -> Line
    end.

%% Report §11.5: a source's characters, each byte that begins no UTF-8
%% character as U+FFFD, so that the lexer's refusal of one shows its line.
chars(<<Char/utf8, Rest/binary>>) -> [Char | chars(Rest)];
chars(<<_, Rest/binary>>) -> [16#FFFD | chars(Rest)];
chars(<<>>) -> [];
chars(Source) -> chars(unicode:characters_to_binary(Source)).

%% Report §11.5: an excerpt shows a tab as a space and a control character
%% as its picture, one column each, so that the caret stays under it and
%% no control character of a source reaches the terminal.
shown($\t) -> $\s;
shown(Char) when Char < 16#20 -> 16#2400 + Char;
shown(16#7F) -> 16#2421;
shown(Char) when Char >= 16#80, Char =< 16#9F -> 16#FFFD;
shown(Char) -> Char.
