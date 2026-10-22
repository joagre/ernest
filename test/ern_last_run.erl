%% `make bench`'s memory of its runs (docs/development.md; plan, MVP
%% 3.29, MVP 3.295): a run is compared with two references, the last run's
%% tables in `last/` and the release's in `release/`, and the memory is
%% kept a table at a time, so that a run of one part of the bench keeps and
%% compares that part's tables alone, and a run of the whole every table.
%% At a run's start each of its tables that the run before wrote is kept in
%% `last/`, in place of the one there, and the rest of `last/` stays; the
%% release review keeps the tables in `release/` the same way (`make
%% bench-release`), and so does a user whose first run on a new machine is
%% a new reference. At a run's end every row of its tables that moved by
%% more than the noise against either reference is named with both
%% numbers, under the reference, printed and written to moved.txt, which
%% names the run's tables first, since a part's run writes it as the
%% whole's does. A part that failed leaves no table, so the next run is
%% compared with the one before it.
%%
%% A file is the text a part of the bench writes: tables, a blank line
%% between two, the first line of each its title, the others its rows. A
%% line that gives the load average is neither: the machine's load is not
%% the bench's measure. A row is matched with the reference's by its
%% table's title and its own words, each number in them read as a number,
%% and by its place among the rows of its table that read alike.
%%
%% A table some of whose rows carry a ratio, `5.41x`, a time over another
%% measured beside it, the host's or a smaller burst's, is compared by its
%% ratios alone, since the machine's state moves both times and not their
%% ratio; a row of it with no ratio is not compared. A table with none is
%% compared by its numbers but for two kinds, which follow from the
%% others: a range's two ends, `low to high`, and a difference, `+131.6`. A
%% number before a unit of time or of bytes is compared in the unit's base,
%% so that `990 ns` and `1.2 us` are compared as the two times they are. A
%% number that names a row, `1000 processes`, is the same in both runs, and
%% a label, `10:`, is a word.
-module(ern_last_run).

-export([main/1, kept/2, released/2, compared/2, moved/2, rows/1]).

%% How far a number moves between two runs of one part on this machine
%% with nothing changed, a fifth (the log's *The Rows That Grew*).
-define(NOISE, 0.2).
%% The directories under the bench's output that hold the two references'
%% tables.
-define(LAST, "last").
-define(RELEASE, "release").
%% The file the comparison is written to, beside the tables.
-define(MOVED, "moved.txt").

%% `keep`, at a run's start: each table of the list that is in Directory
%% moves to its `last/`, in place of the one there. `release`, by hand:
%% each table of the list that is in Directory is copied to its `release/`,
%% in place of the one there, and those kept are named. `compare`, at a
%% run's end: each table of the list in Directory beside the same table of
%% both references, the rows that moved printed and written to moved.txt.
-spec main([string()]) -> no_return().
main(["keep", Directory | Tables]) ->
    kept(Directory, Tables),
    halt(0);
main(["release", Directory | Tables]) ->
    case released(Directory, Tables) of
        {[], _} ->
            io:format(standard_error, "No table kept: no run wrote ~ts in ~s; run make bench "
                      "first.~n", [lists:join(", ", Tables), Directory]),
            halt(1);
        {Kept, Unwritten} ->
            io:format("Kept as the release's run, in ~s: ~ts.~n",
                      [filename:join(Directory, ?RELEASE), lists:join(", ", Kept)]),
            case Unwritten of
                [] -> ok;
                _ -> io:format("Not kept, since no run wrote them in ~s: ~ts.~n",
                               [Directory, lists:join(", ", Unwritten)])
            end,
            halt(0)
    end;
main(["compare", Directory | Tables]) ->
    Text = unicode:characters_to_binary(compared(Directory, Tables)),
    io:format("~ts", [Text]),
    ok = file:write_file(filename:join(Directory, ?MOVED), Text),
    halt(0).

%% Each table of the list that is in Directory moved to its `last/`, in
%% place of the one there; a table the run before did not write leaves the
%% one in `last/`.
-spec kept(string(), [string()]) -> ok.
kept(Directory, Tables) ->
    Last = made(filename:join(Directory, ?LAST)),
    lists:foreach(fun(Table) ->
                      ok = file:rename(filename:join(Directory, Table),
                                       filename:join(Last, Table))
                  end, written(Directory, Tables)).

%% Each table of the list that is in Directory copied to its `release/`, in
%% place of the one there: the tables kept, and those no run wrote, whose
%% own in `release/` stay.
-spec released(string(), [string()]) -> {[string()], [string()]}.
released(Directory, Tables) ->
    case written(Directory, Tables) of
        [] ->
            {[], Tables};
        Written ->
            Release = made(filename:join(Directory, ?RELEASE)),
            lists:foreach(fun(Table) ->
                              {ok, _} = file:copy(filename:join(Directory, Table),
                                                  filename:join(Release, Table))
                          end, Written),
            {Written, Tables -- Written}
    end.

%% The tables of the list that are in Directory.
written(Directory, Tables) ->
    [Table || Table <- Tables, filelib:is_regular(filename:join(Directory, Table))].

%% The directory, made where it is not there.
made(Directory) ->
    ok = filelib:ensure_path(Directory),
    Directory.

%% The comparison's text: the run's tables, those of the list that are in
%% Directory; and against each reference the rows of those it holds that
%% moved, under their file and table's title, or that none did, and the
%% tables it does not hold.
-spec compared(string(), [string()]) -> iolist().
compared(Directory, Tables) ->
    Written = written(Directory, Tables),
    [io_lib:format("The tables of this run: ~ts.~n", [lists:join(", ", Written)]),
     against("the last run", filename:join(Directory, ?LAST), Directory, Written,
             "No last run of ~ts in ~s; the next run is compared with this one.~n"),
     against("the release's run", filename:join(Directory, ?RELEASE), Directory, Written,
             "No release's run of ~ts in ~s; make bench-release keeps this run's tables "
             "as the release's.~n")].

against(Reference, Kept, Directory, Written, None) ->
    {Held, Unheld} = lists:partition(
                       fun(Table) -> filelib:is_regular(filename:join(Kept, Table)) end, Written),
    [compared_with(Reference, Kept, Directory, Held),
     [io_lib:format(None, [lists:join(", ", Unheld), Kept]) || Unheld =/= []]].

compared_with(_, _, _, []) ->
    [];
compared_with(Reference, Kept, Directory, Held) ->
    Moved = [{Table, Blocks}
             || Table <- Held,
                Blocks <- [moved(read(filename:join(Kept, Table)),
                                 read(filename:join(Directory, Table)))],
                Blocks =/= []],
    case Moved of
        [] ->
            io_lib:format("No row moved by more than a fifth since ~s, in ~s.~n",
                          [Reference, Kept]);
        _ ->
            [io_lib:format("Moved by more than a fifth since ~s, in ~s:~n", [Reference, Kept]),
             [moved_text(Table, Blocks) || {Table, Blocks} <- Moved]]
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
%% the same rows of the text Before, under their table's title: each moved
%% number by its name, with its value and its text in both.
-spec moved(string(), string()) ->
          [{string(), [{string(), {number(), string()}, {number(), string()}}]}].
moved(Before, Now) ->
    Last = maps:from_list([{Key, Values} || {Key, _, Values} <- rows(Before)]),
    joined([{Title, Moved}
            || {Key, Title, Values} <- rows(Now),
               {ok, LastValues} <- [maps:find(Key, Last)],
               Moved <- [moved_values(LastValues, Values)], Moved =/= []]).

moved_values(LastValues, Values) ->
    [{Name, {Old, Before}, {New, Now}}
     || {{Old, Before, _}, {New, Now, Name}} <- lists:zip(LastValues, Values),
        is_moved(Old, New)].

is_moved(Old, New) when Old == 0 -> New /= 0;
is_moved(Old, New) -> abs(New - Old) > ?NOISE * abs(Old).

%% The moved rows of one table under its title once.
joined([{Title, Moved}, {Title, More} | Rest]) -> joined([{Title, Moved ++ More} | Rest]);
joined([Block | Rest]) -> [Block | joined(Rest)];
joined([]) -> [].

%% Each row of the text: its key, its table's title and shape, its own
%% shape with its place among the rows of that shape in the table, and
%% whether the table is compared by its ratios; the title as it reads; and
%% its numbers compared, each in its unit's base, as it reads, and named.
-spec rows(string()) -> [{{string(), string(), pos_integer(), ratios | numbers}, string(),
                          [{number(), string(), string()}]}].
rows(Text) ->
    lists:append([table_rows(Block) || Block <- blocks(string:split(Text, "\n", all), [], [])]).

%% The text's tables, each its lines' words, a row's with whether the line
%% is indented.
blocks([], Block, Blocks) ->
    lists:reverse([lists:reverse(Block) || Block =/= []] ++ Blocks);
blocks([Line | Lines], Block, Blocks) ->
    Words = words(Line),
    case {Words, Block} of
        {[], []} -> blocks(Lines, [], Blocks);
        {[], _} -> blocks(Lines, [], [lists:reverse(Block) | Blocks]);
        _ ->
            case is_load(Words) of
                true -> blocks(Lines, Block, Blocks);
                false -> blocks(Lines, [{is_indented(Line), Words} | Block], Blocks)
            end
    end.

table_rows([{_, Title} | Rows]) ->
    TitleShape = shape(items(Title)),
    Items = [{Indented, items(Words)} || {Indented, Words} <- Rows],
    Compared = case lists:any(fun({_, Row}) -> lists:keymember(ratio, 1, Row) end, Items) of
                   true -> ratios;
                   false -> numbers
               end,
    {Read, _} = lists:mapfoldl(
                  fun({Indented, Row}, {Seen, Above}) ->
                          Shape = shape(Row),
                          Place = maps:get(Shape, Seen, 0) + 1,
                          Parent = case Indented of
                                       true -> Above;
                                       false -> []
                                   end,
                          Next = case Indented of
                                     true -> Above;
                                     false -> [Name || Name <- [name(Row, length(Row) + 1)],
                                                       Name =/= ""]
                                 end,
                          {{{TitleShape, Shape, Place, Compared}, string:join(Title, " "),
                            compared_numbers(Compared, Parent, Row)},
                           {Seen#{Shape => Place}, Next}}
                  end, {#{}, []}, Items),
    Read.

words(Line) ->
    string:lexemes(Line, " \t\r").

is_indented(Line) ->
    lists:member(hd(Line), " \t").

is_load(Words) ->
    string:find(string:lowercase(string:join(Words, " ")), "load average") =/= nomatch.

%%
%% A row's items
%%

%% A row's words read as items, each its kind, its text as a value shows
%% it, its value, and its words as the row has them: a `word`, a label
%% such as `10:` among them, a `number`, one before a unit in the unit's
%% base, a `range` of two, a `ratio` and a `difference`.
items([]) ->
    [];
items([Word | Rest]) ->
    case {number(Word), Rest} of
        {{plain, _}, ["to", End | After]} ->
            case number(End) of
                {plain, _} -> [{range, Word ++ " to " ++ shown(End), none,
                                Word ++ " to " ++ End} | items(After)];
                _ -> plain(Word, Rest)
            end;
        {{plain, _}, _} -> plain(Word, Rest);
        {{ratio, Value}, _} -> [{ratio, shown(Word), Value, Word} | items(Rest)];
        {difference, _} -> [{difference, Word, none, Word} | items(Rest)];
        {word, _} -> [{word, Word, none, Word} | items(Rest)]
    end.

%% A plain number, and its unit where one follows.
plain(Word, Rest) ->
    {plain, Value} = number(Word),
    case unit(Rest) of
        {Kind, Factor, Unit, After} ->
            [{{number, Kind}, shown(Word) ++ " " ++ shown(Unit), Value * Factor,
              Word ++ " " ++ Unit} | items(After)];
        none ->
            [{{number, plain}, shown(Word), Value, Word} | items(Rest)]
    end.

%% A row's shape: its words, each number a `#`, followed by its unit's
%% kind where it has one.
shape(Items) ->
    string:join([case Kind of
                      {number, plain} -> "#";
                      {number, Unit} -> "#" ++ Unit;
                      range -> "# to #";
                      ratio -> "#x";
                      difference -> "+#";
                      _ -> Text
                  end || {Kind, Text, _, _} <- Items], " ").

%% The numbers a row's table compares it by, each with its value, its text
%% and its name: the name of the row's part it is, an indented row being a
%% part of the row above it that is not, and then its words before the
%% number.
compared_numbers(Compared, Parent, Row) ->
    Kind = case Compared of
               ratios -> ratio;
               numbers -> number
           end,
    [{Value, Text, lists:flatten(lists:join(", ", Parent ++ [name(Row, Index)]))}
     || {Index, {Of, Text, Value, _}} <- lists:enumerate(Row), kind(Of) =:= Kind].

kind({number, _}) -> number;
kind(Kind) -> Kind.

%% A number's name: its row's words before it, but for the measures just
%% before it, a ratio, a difference, a number with a fraction or a unit, a
%% range and the median before it, so that a ratio is named by its row's
%% words and not by the times it is the ratio of, `Address.call` for
%% `Address.call 2000.0 1900.0 to 2100.0 2.00x`. A whole number that names
%% the row stays, `depth 8 111626.7`.
name(Row, Index) ->
    Before = lists:reverse(lists:sublist(Row, Index - 1)),
    string:join([Words || {_, _, _, Words} <- lists:reverse(unmeasured(Before))], " ").

unmeasured([{range, _, _, _}, {{number, plain}, _, Value, _} | Rest]) when is_integer(Value) ->
    unmeasured(Rest);
unmeasured([{Kind, _, Value, _} | Rest] = Items) ->
    case Kind of
        word -> Items;
        {number, plain} when is_integer(Value) -> Items;
        _ -> unmeasured(Rest)
    end;
unmeasured([]) ->
    [].

%% A number or a unit as the row shows it, without the punctuation after it.
shown(Word) ->
    string:trim(Word, trailing, ",;)").

%% A word read as a number: a plain one; a ratio, `5.41x`; a difference,
%% which follows from the plain ones; or a word, a label such as `10:`
%% among them.
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
                {match, [[], Number, "x"]} -> {ratio, value(Number)};
                {match, [_, _, _]} -> difference;
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
