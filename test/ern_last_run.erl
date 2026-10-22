%% `make bench`'s memory of its last run (docs/development.md; plan, MVP
%% 3.29): at a run's start, the tables of the run before are kept in
%% `last/` beside the new ones, where that run wrote them all; at its end,
%% every row of every table that moved by more than the noise against the
%% last run's is named with both numbers, printed and written to
%% moved.txt. Where a run failed before its end, the tables of the run
%% before it stay the last run's.
%%
%% A table is the text a part of the bench writes: blocks of lines, a blank
%% line between two, the first line of each its title, the others its
%% rows. A row is matched with the last run's by its block's title and its
%% own words, each number in them read as a number, and by its place among
%% the rows of its block that read alike. Its numbers are compared but for
%% three kinds, which follow from the others: a range's two ends, `low to
%% high`; a ratio, `5.4x`; and a difference, `+131.6`. A number before a
%% unit of time or of bytes is compared in the unit's base, so that `990
%% ns` and `1.2 us` are compared as the two times they are. A number that
%% names a row, `1000 processes`, is the same in both runs, and a label,
%% `10:`, is a word. A line that gives the load average is no row: the
%% machine's load is not the bench's measure.
-module(ern_last_run).

-export([main/1, kept/2, compared/2, moved/2, rows/1]).

%% How far a number moves between two runs of one part on this machine
%% with nothing changed, a fifth (the log's *The Rows That Grew*).
-define(NOISE, 0.2).
%% The directory under the bench's output that holds the last run's tables.
-define(LAST, "last").
%% The file the comparison is written to, beside the tables.
-define(MOVED, "moved.txt").

%% `keep`, at a run's start: where every table of the list is in
%% Directory, they move to its `last/`, in place of what was there. Then
%% `compare`, at its end: each table in `last/` beside the same table in
%% Directory, the rows that moved printed and written to moved.txt.
-spec main([string()]) -> no_return().
main(["keep", Directory | Tables]) ->
    kept(Directory, Tables),
    halt(0);
main(["compare", Directory | Tables]) ->
    Text = unicode:characters_to_binary(compared(Directory, Tables)),
    io:format("~ts", [Text]),
    ok = file:write_file(filename:join(Directory, ?MOVED), Text),
    halt(0).

%% Every table of the list in Directory moved to its `last/`, where all of
%% them are there.
-spec kept(string(), [string()]) -> ok.
kept(Directory, Tables) ->
    Paths = [filename:join(Directory, Table) || Table <- Tables],
    case lists:all(fun filelib:is_regular/1, Paths) of
        true ->
            Last = filename:join(Directory, ?LAST),
            case file:del_dir_r(Last) of
                ok -> ok;
                {error, enoent} -> ok
            end,
            ok = file:make_dir(Last),
            lists:foreach(fun(Path) ->
                              ok = file:rename(Path, filename:join(Last, filename:basename(Path)))
                          end, Paths);
        false ->
            ok
    end.

%% The comparison's text: the rows that moved, under their table's file
%% and title; that none did; or that no last run is there.
-spec compared(string(), [string()]) -> iolist().
compared(Directory, Tables) ->
    Last = filename:join(Directory, ?LAST),
    Pairs = [{Table, filename:join(Last, Table), filename:join(Directory, Table)}
             || Table <- Tables],
    case [Pair || {_, Before, Now} = Pair <- Pairs,
                  filelib:is_regular(Before), filelib:is_regular(Now)] of
        [] ->
            io_lib:format("No last run in ~s; the next run is compared with this one.~n",
                          [Last]);
        Compared ->
            Moved = [{Table, Blocks} || {Table, Before, Now} <- Compared,
                                        Blocks <- [moved(read(Before), read(Now))], Blocks =/= []],
            case Moved of
                [] ->
                    io_lib:format("No row moved by more than a fifth since the last run, in ~s.~n",
                                  [Last]);
                _ ->
                    [io_lib:format("Moved by more than a fifth since the last run, in ~s:~n",
                                   [Last]),
                     [moved_text(Table, Blocks) || {Table, Blocks} <- Moved]]
            end
    end.

read(Path) ->
    {ok, Text} = file:read_file(Path),
    unicode:characters_to_list(Text).

moved_text(Table, Blocks) ->
    [[io_lib:format("~ts: ~ts~n", [Table, Title]),
      [io_lib:format("  ~ts: last ~ts, now ~ts, ~ts~n", [Name, Before, Now, change(Old, New)])
       || {Name, {Old, Before}, {New, Now}} <- Moved]]
     || {Title, Moved} <- Blocks].

change(Old, _) when Old == 0 -> "from none";
change(Old, New) -> io_lib:format("~s~B%", [[$+ || New >= Old], round((New - Old) * 100 / Old)]).

%% The rows of the text Now whose numbers moved by more than ?NOISE against
%% the same rows of the text Before, under their block's title: each moved
%% number named by the row's words before it, with its value and its text
%% in both.
-spec moved(string(), string()) ->
          [{string(), [{string(), {number(), string()}, {number(), string()}}]}].
moved(Before, Now) ->
    Last = maps:from_list([{Key, Values} || {Key, _, _, Values} <- rows(Before)]),
    joined([{Title, Moved}
            || {Key, Title, Words, Values} <- rows(Now),
               {ok, LastValues} <- [maps:find(Key, Last)],
               Moved <- [moved_values(Words, LastValues, Values)], Moved =/= []]).

moved_values(Words, LastValues, Values) ->
    [{string:join(lists:sublist(Words, Position - 1), " "), {Old, Before}, {New, Now}}
     || {{Old, Before, _}, {New, Now, Position}} <- lists:zip(LastValues, Values),
        is_moved(Old, New)].

is_moved(Old, New) when Old == 0 -> New /= 0;
is_moved(Old, New) -> abs(New - Old) > ?NOISE * abs(Old).

%% The moved rows of one block under its title once.
joined([{Title, Moved}, {Title, More} | Rest]) -> joined([{Title, Moved ++ More} | Rest]);
joined([Block | Rest]) -> [Block | joined(Rest)];
joined([]) -> [].

%% Each row of the text: its key, its block's title and its own shape with
%% its place among the rows of that shape in the block; the title as it
%% reads; the row's words; and its numbers compared, each with its text and
%% its place among the words.
-spec rows(string()) -> [{{string(), string(), pos_integer()}, string(), [string()],
                          [{number(), string(), pos_integer()}]}].
rows(Text) ->
    lists:append([block_rows(Block) || Block <- blocks(string:split(Text, "\n", all), [], [])]).

blocks([], Block, Blocks) ->
    lists:reverse([lists:reverse(Block) || Block =/= []] ++ Blocks);
blocks([Line | Lines], Block, Blocks) ->
    case {words(Line), Block} of
        {[], []} -> blocks(Lines, [], Blocks);
        {[], _} -> blocks(Lines, [], [lists:reverse(Block) | Blocks]);
        {Words, _} -> blocks(Lines, [Words | Block], Blocks)
    end.

block_rows([Title | Rows]) ->
    {TitleShape, _} = read_words(Title),
    {Read, _} = lists:mapfoldl(fun(Words, Seen) ->
                                   {Shape, Values} = read_words(Words),
                                   Place = maps:get(Shape, Seen, 0) + 1,
                                   {{{TitleShape, Shape, Place}, string:join(Title, " "), Words,
                                     Values},
                                    Seen#{Shape => Place}}
                               end, #{}, [Words || Words <- Rows, not is_load(Words)]),
    Read.

words(Line) ->
    string:lexemes(Line, " \t\r").

is_load(Words) ->
    string:find(string:lowercase(string:join(Words, " ")), "load average") =/= nomatch.

%% A row's words read: its shape, each number compared a `#` in it, and its
%% numbers compared.
read_words(Words) ->
    read_words(Words, 1, [], []).

read_words([], _, Shape, Values) ->
    {string:join(lists:reverse(Shape), " "), lists:reverse(Values)};
read_words([Word | Rest], Position, Shape, Values) ->
    case {number(Word), Rest} of
        {{plain, _}, ["to", End | After]} ->
            case number(End) of
                {plain, _} -> read_words(After, Position + 3, ["# to #" | Shape], Values);
                _ -> plain(Word, Rest, Position, Shape, Values)
            end;
        {{plain, _}, _} ->
            plain(Word, Rest, Position, Shape, Values);
        {{derived, Kind}, _} ->
            read_words(Rest, Position + 1, [Kind | Shape], Values);
        {word, _} ->
            read_words(Rest, Position + 1, [Word | Shape], Values)
    end.

%% A plain number, and its unit where one follows.
plain(Word, Rest, Position, Shape, Values) ->
    {plain, Value} = number(Word),
    case unit(Rest) of
        {Kind, Factor, Unit, After} ->
            Shown = shown(Word) ++ " " ++ shown(Unit),
            read_words(After, Position + 2, ["#" ++ Kind | Shape],
                       [{Value * Factor, Shown, Position} | Values]);
        none ->
            read_words(Rest, Position + 1, ["#" | Shape],
                       [{Value, shown(Word), Position} | Values])
    end.

%% A number or a unit as the row shows it, without the punctuation after it.
shown(Word) ->
    string:trim(Word, trailing, ",;)").

%% A word read as a number: a plain one, compared; a ratio or a
%% difference, which follow from the plain ones; or a word, a label such as
%% `10:` among them.
number(Word) ->
    Opened = string:trim(Word, leading, "("),
    Core = string:trim(Opened, trailing, ",;)"),
    case lists:suffix(":", Opened) of
        true ->
            word;
        false ->
            case re:run(Core, "^([+-]?)([0-9]+(\\.[0-9]+)?)(x?)$",
                        [{capture, [1, 2, 4], list}]) of
                {match, [[], Number, []]} -> {plain, value(Number)};
                {match, [[], _, "x"]} -> {derived, "#x"};
                {match, [_, _, _]} -> {derived, "+#"};
                nomatch -> word
            end
    end.

value(Number) ->
    case string:to_float(Number) of
        {Float, []} -> Float;
        {error, _} -> list_to_integer(Number)
    end.

%% The unit of time or of bytes the words begin with, with its factor to
%% nanoseconds or bytes, and the words after it.
unit([Unit | After]) ->
    case lists:keyfind(shown(Unit), 1, units()) of
        {_, Kind, Factor} -> {Kind, Factor, Unit, After};
        false -> none
    end;
unit([]) ->
    none.

units() ->
    [{"ns", "t", 1}, {"us", "t", 1000}, {"µs", "t", 1000}, {"ms", "t", 1000000},
     {"s", "t", 1000000000}, {"B", "b", 1}, {"KB", "b", 1024}, {"MB", "b", 1048576},
     {"GB", "b", 1073741824}].
