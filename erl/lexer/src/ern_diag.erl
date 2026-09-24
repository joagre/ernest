%% Diagnostics, report §11.5: one record for every stage, rendered as the
%% first line `file:line:column: message`, then the source with a gutter,
%% the spans underlined and labelled, and at most one help line.
-module(ern_diag).

-export([span/1, line/1, column/1, short/2, format/3]).

-export_type([span/0, diag/0]).

-include_lib("lexer/include/ern_diag.hrl").

-type span() :: {pos_integer(), pos_integer(), {pos_integer(), pos_integer()}}.
%% line, column, and the end, exclusive, as line and column
-type diag() :: #diag{}.

%% A span from a node position or a token position (ern_lexer:pos()).
-spec span(tuple()) -> span().
span({L, C, End, _Before}) -> {L, C, End};
span({_, _, _} = Span) -> Span.

-spec line(span()) -> pos_integer().
line({L, _, _}) -> L.

-spec column(span()) -> pos_integer().
column({_, C, _}) -> C.

%% The first line alone: what a tool parses.
-spec short(string(), diag()) -> string().
short(File, #diag{span = {L, C, _}, message = Message}) ->
    lists:flatten(io_lib:format("~ts:~B:~B: ~ts", [File, L, C, Message])).

%% The first line, then the source with the spans underlined, the primary
%% with `^`, each label's with `-` followed by the label, and the help line.
-spec format(string(), unicode:chardata(), diag()) -> string().
format(File, Source, #diag{span = Span, labels = Labels, help = Help} = D) ->
    Lines = lines(Source),
    Marks = lists:sort([{Span, "^", ""} | [{S, "-", Text} || {S, Text} <- Labels]]),
    Width = length(integer_to_list(lists:max([line(S) || {S, _, _} <- Marks]))),
    Body = marks(Marks, Lines, Width, 0),
    HelpLine = case Help of
                   undefined -> [];
                   _ -> [gutter(Width), "= help: ", Help, "\n"]
               end,
    lists:flatten([short(File, D), "\n", Body, HelpLine]).

%% Each mark: the line before it when it is the first mark and the line
%% exists, the source line unless it was just printed, then the underline.
marks([], _, _, _) ->
    [];
marks([{{L, C, End}, Char, Text} | Rest], Lines, Width, Printed) ->
    Context = case Printed =:= 0 andalso L > 1 of
                  true -> source_line(L - 1, Lines, Width);
                  false -> []
              end,
    SourceLine = case L =:= Printed of
                     true -> [];
                     false -> source_line(L, Lines, Width)
                 end,
    Text1 = case Text of "" -> ""; _ -> " " ++ Text end,
    Under = [gutter(Width), lists:duplicate(C - 1, $\s),
             lists:duplicate(width(L, C, End, Lines), hd(Char)), Text1, "\n"],
    [Context, SourceLine, Under | marks(Rest, Lines, Width, L)].

source_line(N, Lines, Width) ->
    case N =< length(Lines) of
        true -> [io_lib:format("~*B | ", [Width, N]), lists:nth(N, Lines), "\n"];
        false -> []
    end.

gutter(Width) -> [lists:duplicate(Width, $\s), " | "].

%% The underline's width: the span on its first line, at least one column.
width(L, C, {L, EC}, _) -> max(1, EC - C);
width(L, C, _, Lines) when L =< length(Lines) -> max(1, length(lists:nth(L, Lines)) - C + 1);
width(_, _, _, _) -> 1.

lines(Source) ->
    Chars = unicode:characters_to_list(Source),
    [[case Ch of $\t -> $\s; _ -> Ch end || Ch <- Line, Ch =/= $\r]
     || Line <- string:split(Chars, "\n", all)].
