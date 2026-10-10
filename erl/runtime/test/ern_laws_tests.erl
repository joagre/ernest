%% The standard library's laws as properties (plan, MVP 2.99c item 2): what
%% each module's section of report Appendix E and its doc blocks state of
%% every value, checked on cases drawn at random, for the modules whose
%% contracts state such laws: List, String, Map, Set, OrderedSet, OrderedMap,
%% Bytes, Int, Float, Char, Optional, Either and Path. A law is the
%% contract's own words: a model in Erlang where the contract describes the
%% result, an equation between the module's functions where it relates them.
%% Unicode's segmentation is `String.graphemes`, a primitive, and White_Space
%% is `Char.isSpace`, so the laws of text hold what is written over them to
%% what they say. The modules are called as compiled, a requirement's member
%% after the arguments the program writes (report §4.9).
%%
%% Each law draws its cases from a seed of its own, fresh each run and named
%% in a failure; ERN_SEED draws the same cases again. A case grows with its
%% number, so the first that breaks a law is a small one.
-module(ern_laws_tests).

-include_lib("eunit/include/eunit.hrl").

-define(CASES, 200).

-define(LIST, 'ern@list').
-define(STRING, 'ern@string').
-define(MAP, 'ern@map').
-define(SET, 'ern@set').
-define(ORDERED_SET, 'ern@ordered_set').
-define(ORDERED_MAP, 'ern@ordered_map').
-define(BYTES, 'ern@bytes').
-define(INT, 'ern@int').
-define(FLOAT, 'ern@float').
-define(CHAR, 'ern@char').
-define(OPTIONAL, 'ern@optional').
-define(EITHER, 'ern@either').
-define(PATH, 'ern@path').

%%
%% List
%%

%% report Appendix E.2: the list's operations against Erlang's own on lists,
%% `sort` stable, `take` and `drop` splitting a list, the first `Left` ending
%% `tryMap` and `tryFold`
list_laws_test_() ->
    laws([{"size and isEmpty", fun ints/1, fun list_size/1},
          {"contains", fun ints_and_int/1, fun list_contains/1},
          {"get by index from 0", fun ints_and_int/1, fun list_get/1},
          {"removeAt the element at the index, none outside the list", fun ints_and_int/1,
           fun list_remove_at/1},
          {"map, filter, filterMap", fun ints_and_int/1, fun list_map_filter/1},
          {"foldLeft from the left, foldRight from the right", fun ints/1, fun list_folds/1},
          {"forEach meets the elements in order", fun ints/1, fun list_for_each/1},
          {"any, all, find the first", fun ints_and_int/1, fun list_search/1},
          {"last", fun ints/1, fun list_last/1},
          {"take and drop split the list, below 0 being 0", fun ints_and_int/1,
           fun list_take_drop/1},
          {"dropLast keeps all but the last n", fun ints_and_int/1, fun list_drop_last/1},
          {"takeLast keeps the last n, and dropLast the rest", fun ints_and_int/1,
           fun list_take_last/1},
          {"span: the longest prefix that satisfies, and the rest", fun ints_and_int/1,
           fun list_span/1},
          {"partition: each in order", fun ints_and_int/1, fun list_partition/1},
          {"unique: the first occurrence of each, in order", fun ints/1, fun list_unique/1},
          {"indexed from 0", fun ints/1, fun list_indexed/1},
          {"repeat: n copies, below 0 none", fun two_small/1, fun list_repeat/1},
          {"reverse", fun ints/1, fun list_reverse/1},
          {"sort is stable", fun keyed_pairs/1, fun list_sort/1},
          {"zip to the shorter length, and unzip", fun two_ints/1, fun list_zip/1},
          {"flatMap", fun ints/1, fun list_flat_map/1},
          {"range inclusive, empty when the first is greater", fun two_small/1,
           fun list_range/1},
          {"tryMap and tryFold end at the first Left", fun ints_and_int/1, fun list_tries/1},
          {"<> appends", fun two_ints/1, fun list_append/1}]).

list_size(List) ->
    ?LIST:size(List) =:= length(List) andalso ?LIST:isEmpty(List) =:= (List =:= []).

list_contains({List, X}) ->
    ?LIST:contains(List, X) =:= lists:member(X, List).

list_get({List, Index}) ->
    Expected = case Index >= 0 andalso Index < length(List) of
                   true -> {'Some', lists:nth(Index + 1, List)};
                   false -> 'None'
               end,
    ?LIST:get(List, Index) =:= Expected.

list_remove_at({List, Index}) when Index >= 0, Index < length(List) ->
    {Before, [_ | After]} = lists:split(Index, List),
    ?LIST:removeAt(List, Index) =:= Before ++ After;
list_remove_at({List, Index}) ->
    ?LIST:removeAt(List, Index) =:= List.

list_map_filter({List, Pivot}) ->
    Keep = above(Pivot),
    Tenfold = fun(X) -> kept(Keep(X), X * 10) end,
    ?LIST:map(List, fun(X) -> X * 2 end) =:= [X * 2 || X <- List]
        andalso ?LIST:filter(List, Keep) =:= lists:filter(Keep, List)
        andalso ?LIST:filterMap(List, Tenfold) =:= [X * 10 || X <- List, Keep(X)].

list_folds(List) ->
    ?LIST:foldLeft(List, [], fun(Acc, X) -> [X | Acc] end) =:= lists:reverse(List)
        andalso ?LIST:foldRight(List, [], fun(Acc, X) -> [X | Acc] end) =:= List.

list_for_each(List) ->
    met(fun(Visit) -> ?LIST:forEach(List, Visit) end) =:= List.

list_search({List, Pivot}) ->
    Keep = above(Pivot),
    ?LIST:any(List, Keep) =:= lists:any(Keep, List)
        andalso ?LIST:all(List, Keep) =:= lists:all(Keep, List)
        andalso ?LIST:find(List, Keep) =:= first(lists:filter(Keep, List)).

list_last(List) ->
    ?LIST:last(List) =:= first(lists:reverse(List)).

list_take_drop({List, Count}) ->
    Taken = ?LIST:take(List, Count),
    Taken ++ ?LIST:drop(List, Count) =:= List
        andalso length(Taken) =:= min(max(Count, 0), length(List)).

list_drop_last({List, Count}) ->
    Kept = max(length(List) - max(Count, 0), 0),
    ?LIST:dropLast(List, Count) =:= lists:sublist(List, Kept).

list_take_last({List, Count}) ->
    Taken = ?LIST:takeLast(List, Count),
    ?LIST:dropLast(List, Count) ++ Taken =:= List
        andalso length(Taken) =:= min(max(Count, 0), length(List)).

list_span({List, Pivot}) ->
    ?LIST:span(List, above(Pivot)) =:= lists:splitwith(above(Pivot), List).

list_partition({List, Pivot}) ->
    ?LIST:partition(List, above(Pivot)) =:= lists:partition(above(Pivot), List).

list_unique(List) ->
    ?LIST:unique(List) =:= first_occurrences(fun(X) -> X end, List).

list_indexed(List) ->
    ?LIST:indexed(List) =:= lists:zip(lists:seq(0, length(List) - 1), List).

list_repeat({X, Count}) ->
    ?LIST:repeat(X, Count) =:= lists:duplicate(max(Count, 0), X).

list_reverse(List) ->
    ?LIST:reverse(List) =:= lists:reverse(List).

%% Erlang's merge sort keeps equal elements in order where the ordering
%% says true of two equal ones.
list_sort(Pairs) ->
    ByKey = fun({Key, _}, {Other, _}) -> ?INT:compare(Key, Other) end,
    Stable = lists:sort(fun({Key, _}, {Other, _}) -> Key =< Other end, Pairs),
    ?LIST:sort(Pairs, ByKey) =:= Stable.

list_zip({First, Second}) ->
    Count = min(length(First), length(Second)),
    {Firsts, Seconds} = {lists:sublist(First, Count), lists:sublist(Second, Count)},
    Zipped = ?LIST:zip(First, Second),
    Zipped =:= lists:zip(Firsts, Seconds) andalso ?LIST:unzip(Zipped) =:= {Firsts, Seconds}.

list_flat_map(List) ->
    Twice = fun(X) -> [X, X] end,
    ?LIST:flatMap(List, Twice) =:= lists:flatmap(Twice, List).

list_range({From, To}) when From > To -> ?LIST:range(From, To) =:= [];
list_range({From, To}) -> ?LIST:range(From, To) =:= lists:seq(From, To).

list_tries({List, Pivot}) ->
    Step = fun(X) ->
                   case X > Pivot of
                       true -> {'Left', X};
                       false -> {'Right', X * 2}
                   end
           end,
    Fold = fun(Acc, X) -> either_map(Step(X), fun(Doubled) -> Acc + Doubled end) end,
    Doubled = [X * 2 || X <- List],
    {Mapped, Folded} = case lists:search(above(Pivot), List) of
                           {value, Bad} -> {{'Left', Bad}, {'Left', Bad}};
                           false -> {{'Right', Doubled}, {'Right', lists:sum(Doubled)}}
                       end,
    ?LIST:tryMap(List, Step) =:= Mapped andalso ?LIST:tryFold(List, 0, Fold) =:= Folded.

list_append({First, Second}) ->
    ?LIST:'<>'(First, Second) =:= First ++ Second.

%%
%% Map
%%

%% report Appendix E.3: the map against Erlang's maps, a lookup after a put
%% or a remove, `merge` the second winning, `fromList` the later pair
map_laws_test_() ->
    laws([{"fromList: a later pair wins", fun entries/1, fun map_from_list/1},
          {"size, isEmpty, toList, keys, values", fun entries/1, fun map_contents/1},
          {"get after put, contains", fun map_and_key/1, fun map_put/1},
          {"remove, a key not present no error", fun map_and_key/1, fun map_remove/1},
          {"update: the entry, present or not, replaced", fun map_and_key/1, fun map_update/1},
          {"map, filter, filterMap, fold", fun map_and_key/1, fun map_traversals/1},
          {"any, all, find some entry that satisfies", fun map_and_key/1, fun map_search/1},
          {"merge: the second wins; mergeWith: the key, the first's value, the second's",
           fun two_maps/1, fun map_merge/1},
          {"forEach meets each entry once", fun entries/1, fun map_for_each/1}]).

%% Report Appendix E.3: forEach meets each entry once, in unspecified order.
map_for_each(Pairs) ->
    Map = ?MAP:fromList(Pairs),
    Met = met(fun(Visit) -> ?MAP:forEach(Map, fun(Key, Value) -> Visit({Key, Value}) end) end),
    lists:sort(Met) =:= lists:sort(maps:to_list(Map)).

map_from_list(Pairs) ->
    ?MAP:fromList(Pairs) =:= maps:from_list(Pairs).

map_contents(Pairs) ->
    Map = ?MAP:fromList(Pairs),
    Model = maps:from_list(Pairs),
    ?MAP:size(Map) =:= maps:size(Model)
        andalso ?MAP:isEmpty(Map) =:= (maps:size(Model) =:= 0)
        andalso lists:sort(?MAP:toList(Map)) =:= lists:sort(maps:to_list(Model))
        andalso lists:sort(?MAP:keys(Map)) =:= lists:sort(maps:keys(Model))
        andalso lists:sort(?MAP:values(Map)) =:= lists:sort(maps:values(Model)).

map_put({Map, Key, Value}) ->
    Put = ?MAP:put(Map, Key, Value),
    ?MAP:get(Put, Key) =:= {'Some', Value}
        andalso maps:remove(Key, Put) =:= maps:remove(Key, Map)
        andalso ?MAP:contains(Map, Key) =:= maps:is_key(Key, Map).

map_remove({Map, Key, _}) ->
    Removed = ?MAP:remove(Map, Key),
    ?MAP:get(Removed, Key) =:= 'None' andalso Removed =:= maps:remove(Key, Map).

map_update({Map, Key, _}) ->
    Old = case Map of
              #{Key := Value} -> {'Some', Value};
              _ -> 'None'
          end,
    ?MAP:update(Map, Key, fun count/1) =:= Map#{Key => count(Old)}.

map_traversals({Map, Pivot, _}) ->
    Keep = fun(Key, _) -> Key > Pivot end,
    Sum = fun(Key, Value) -> Key + Value end,
    Negated = fun(Key, Value) -> kept(Keep(Key, Value), -Value) end,
    Weighted = fun(Key, Value, Acc) -> Acc + Key * Value end,
    ?MAP:map(Map, Sum) =:= maps:map(Sum, Map)
        andalso ?MAP:filter(Map, Keep) =:= maps:filter(Keep, Map)
        andalso ?MAP:filterMap(Map, Negated)
                =:= maps:map(fun(_, Value) -> -Value end, maps:filter(Keep, Map))
        andalso ?MAP:fold(Map, 0, fun(Acc, Key, Value) -> Weighted(Key, Value, Acc) end)
                =:= maps:fold(Weighted, 0, Map).

map_search({Map, Pivot, _}) ->
    Keep = fun(Key, _) -> Key > Pivot end,
    Satisfying = maps:filter(Keep, Map),
    Found = case ?MAP:find(Map, Keep) of
                'None' -> maps:size(Satisfying) =:= 0;
                {'Some', {Key, Value}} -> maps:get(Key, Satisfying, none) =:= Value
            end,
    ?MAP:any(Map, Keep) =:= (maps:size(Satisfying) > 0)
        andalso ?MAP:all(Map, Keep) =:= (maps:size(Satisfying) =:= maps:size(Map))
        andalso Found.

map_merge({First, Second}) ->
    Shared = maps:intersect_with(fun combined/3, First, Second),
    ?MAP:merge(First, Second) =:= maps:merge(First, Second)
        andalso ?MAP:mergeWith(First, Second, fun combined/3)
                =:= maps:merge(maps:merge(First, Second), Shared).

%%
%% Set
%%

%% report Appendix E.4: the set against ordered lists, put and remove no
%% error, the set operations
set_laws_test_() ->
    laws([{"fromList and toList, size, isEmpty", fun elements/1, fun set_contents/1},
          {"contains, put, remove", fun elements_and_one/1, fun set_put_remove/1},
          {"union, intersection, difference, isSubset", fun two_element_lists/1,
           fun set_operations/1},
          {"map, filter, filterMap, fold, any, all, find", fun elements_and_one/1,
           fun set_traversals/1},
          {"forEach meets each element once", fun elements/1, fun set_for_each/1}]).

%% Report Appendix E.4: forEach meets each element once, in unspecified order.
set_for_each(List) ->
    Set = ?SET:fromList(List),
    lists:sort(met(fun(Visit) -> ?SET:forEach(Set, Visit) end)) =:= lists:usort(List).

set_contents(List) ->
    Set = ?SET:fromList(List),
    members(Set) =:= lists:usort(List)
        andalso ?SET:size(Set) =:= length(lists:usort(List))
        andalso ?SET:isEmpty(Set) =:= (List =:= []).

set_put_remove({List, X}) ->
    Set = ?SET:fromList(List),
    ?SET:contains(Set, X) =:= lists:member(X, List)
        andalso members(?SET:put(Set, X)) =:= lists:usort([X | List])
        andalso members(?SET:remove(Set, X)) =:= lists:usort(List) -- [X]
        andalso ?SET:put(?SET:put(Set, X), X) =:= ?SET:put(Set, X).

set_operations({Left, Right}) ->
    {First, Second} = {?SET:fromList(Left), ?SET:fromList(Right)},
    {Ordered, Other} = {lists:usort(Left), lists:usort(Right)},
    members(?SET:union(First, Second)) =:= ordsets:union(Ordered, Other)
        andalso members(?SET:intersection(First, Second)) =:= ordsets:intersection(Ordered, Other)
        andalso members(?SET:difference(First, Second)) =:= ordsets:subtract(Ordered, Other)
        andalso ?SET:isSubset(First, Second) =:= ordsets:is_subset(Ordered, Other).

set_traversals({List, Pivot}) ->
    Set = ?SET:fromList(List),
    Ordered = lists:usort(List),
    Keep = above(Pivot),
    Tripled = fun(X) -> kept(Keep(X), X * 3) end,
    Found = case ?SET:find(Set, Keep) of
                'None' -> not lists:any(Keep, Ordered);
                {'Some', X} -> Keep(X) andalso lists:member(X, Ordered)
            end,
    members(?SET:map(Set, fun(X) -> X div 2 end)) =:= lists:usort([X div 2 || X <- Ordered])
        andalso members(?SET:filter(Set, Keep)) =:= lists:filter(Keep, Ordered)
        andalso members(?SET:filterMap(Set, Tripled)) =:= [X * 3 || X <- Ordered, Keep(X)]
        andalso ?SET:fold(Set, 0, fun(Acc, X) -> Acc + X end) =:= lists:sum(Ordered)
        andalso ?SET:any(Set, Keep) =:= lists:any(Keep, Ordered)
        andalso ?SET:all(Set, Keep) =:= lists:all(Keep, Ordered)
        andalso Found.

members(Set) ->
    lists:sort(?SET:toList(Set)).

%%
%% String
%%

%% report Appendix E.5: text, every search matching whole graphemes of the
%% string searched, `split` then `join` giving the string back, `replace` as
%% `split` and `join`, the slices and the pads counted in graphemes
string_laws_test_() ->
    laws([{"fromList of toList", fun text/1, fun string_chars/1},
          {"the graphemes make the string, size counts them", fun text/1,
           fun string_graphemes/1},
          {"indexOf, lastIndexOf, contains as whole graphemes", fun text_and_part/1,
           fun string_index_of/1},
          {"startsWith and endsWith as whole graphemes", fun text_and_part/1,
           fun string_starts_ends/1},
          {"split at each occurrence, join gives the string back", fun text_and_part/1,
           fun string_split/1},
          {"join puts the second between the parts", fun texts_and_text/1, fun string_join/1},
          {"replace every occurrence, an empty second changing nothing", fun text_part_text/1,
           fun string_replace/1},
          {"slice: graphemes from the index up to the end index, clipped, below 0 being 0",
           fun text_and_two/1, fun string_slice/1},
          {"padStart and padEnd: the pad's copies cut to fit, the string kept",
           fun text_count_pad/1, fun string_pads/1},
          {"repeat n times, below 0 none", fun text_and_one/1, fun string_repeat/1},
          {"trim, trimStart, trimEnd: graphemes whose first code point is White_Space",
           fun text/1, fun string_trims/1},
          {"toLower and toUpper: each code point's full mapping, no rule of a context",
           fun text/1, fun string_cases/1},
          {"lines at each line feed and carriage return with line feed", fun text/1,
           fun string_lines/1},
          {"words: the parts between runs of the graphemes trim removes, none empty", fun text/1,
           fun string_words/1},
          {"toInt: the digits 0 to 9, an optional leading -", fun numeral/1,
           fun string_to_int/1},
          {"toInt reads what Int.toString writes", fun int/1, fun string_int_back/1},
          {"toIntBase: a base from 2 to 36, either case, an optional leading -",
           fun numeral_and_base/1, fun string_to_int_base/1},
          {"toBool: true or false", fun boolean_text/1, fun string_to_bool/1},
          {"toFloat: §2.5's float without _, an optional leading -", fun float_numeral/1,
           fun string_to_float/1},
          {"fromUtf8 of toUtf8", fun text/1, fun string_utf8/1},
          {"fromUtf8: None when the bytes are not UTF-8", fun bytes/1,
           fun string_from_utf8/1},
          {"compare by code point, <> appends", fun two_texts/1, fun string_compare/1}]).

string_chars(Whole) ->
    ?STRING:toList(Whole) =:= unicode:characters_to_list(Whole)
        andalso ?STRING:fromList(?STRING:toList(Whole)) =:= Whole.

string_graphemes(Whole) ->
    Graphemes = ?STRING:graphemes(Whole),
    iolist_to_binary(Graphemes) =:= Whole
        andalso ?STRING:size(Whole) =:= length(Graphemes)
        andalso lists:all(fun(Grapheme) -> ?STRING:size(Grapheme) =:= 1 end, Graphemes)
        andalso ?STRING:isEmpty(Whole) =:= (Whole =:= <<>>).

%% An empty second is at 0 and last at the size.
string_index_of({Whole, Part}) ->
    Found = [Index || {Index, _} <- occurrences(Whole, Part)],
    {First, Last} = case {Part, Found} of
                        {<<>>, _} -> {{'Some', 0}, {'Some', ?STRING:size(Whole)}};
                        _ -> {first(Found), first(lists:reverse(Found))}
                    end,
    ?STRING:indexOf(Whole, Part) =:= First
        andalso ?STRING:lastIndexOf(Whole, Part) =:= Last
        andalso ?STRING:contains(Whole, Part) =:= (First =/= 'None').

string_starts_ends({Whole, Part}) ->
    Bounds = boundaries(Whole),
    Starts = binary:longest_common_prefix([Whole, Part]) =:= byte_size(Part)
        andalso lists:member(byte_size(Part), Bounds),
    Ends = binary:longest_common_suffix([Whole, Part]) =:= byte_size(Part)
        andalso lists:member(byte_size(Whole) - byte_size(Part), Bounds),
    ?STRING:startsWith(Whole, Part) =:= Starts andalso ?STRING:endsWith(Whole, Part) =:= Ends.

string_split({Whole, Separator}) ->
    Parts = ?STRING:split(Whole, Separator),
    Parts =:= split_model(Whole, Separator) andalso ?STRING:join(Parts, Separator) =:= Whole.

string_join({Parts, Separator}) ->
    ?STRING:join(Parts, Separator) =:= iolist_to_binary(lists:join(Separator, Parts)).

string_replace({Whole, Old, New}) ->
    Expected = case Old of
                   <<>> -> Whole;
                   _ -> iolist_to_binary(lists:join(New, split_model(Whole, Old)))
               end,
    ?STRING:replace(Whole, Old, New) =:= Expected.

string_slice({Whole, Index, End}) ->
    Graphemes = ?STRING:graphemes(Whole),
    From = min(max(Index, 0), length(Graphemes)),
    To = min(max(End, From), length(Graphemes)),
    Expected = iolist_to_binary(lists:sublist(lists:nthtail(From, Graphemes), To - From)),
    ?STRING:slice(Whole, Index, End) =:= Expected.

%% The pad stands before or after the string as written, a prefix of its
%% copies; where nothing is missing or the pad is empty, the string alone;
%% and a pad of letters and digits, which joins no grapheme, makes the size
%% asked for.
string_pads({Whole, Count, Pad}) ->
    Missing = Count - ?STRING:size(Whole),
    Copies = binary:copy(Pad, max(Missing, 0) + 1),
    Started = ?STRING:padStart(Whole, Count, Pad),
    Ended = ?STRING:padEnd(Whole, Count, Pad),
    Front = binary:part(Started, 0, byte_size(Started) - byte_size(Whole)),
    Back = binary:part(Ended, byte_size(Whole), byte_size(Ended) - byte_size(Whole)),
    Padded = Missing > 0 andalso Pad =/= <<>>,
    binary:longest_common_suffix([Started, Whole]) =:= byte_size(Whole)
        andalso binary:longest_common_prefix([Ended, Whole]) =:= byte_size(Whole)
        andalso binary:longest_common_prefix([Copies, Front]) =:= byte_size(Front)
        andalso binary:longest_common_prefix([Copies, Back]) =:= byte_size(Back)
        andalso (Padded orelse Started =:= Whole andalso Ended =:= Whole)
        andalso (not Padded orelse not plain(Pad) orelse ?STRING:size(Front) =:= Missing).

string_repeat({Whole, Count}) ->
    ?STRING:repeat(Whole, Count) =:= binary:copy(Whole, max(Count, 0)).

string_trims(Whole) ->
    Graphemes = ?STRING:graphemes(Whole),
    Spaces = fun is_space_grapheme/1,
    Started = lists:dropwhile(Spaces, Graphemes),
    Ended = lists:reverse(lists:dropwhile(Spaces, lists:reverse(Graphemes))),
    Both = lists:reverse(lists:dropwhile(Spaces, lists:reverse(Started))),
    ?STRING:trimStart(Whole) =:= iolist_to_binary(Started)
        andalso ?STRING:trimEnd(Whole) =:= iolist_to_binary(Ended)
        andalso ?STRING:trim(Whole) =:= iolist_to_binary(Both).

%% Each code point mapped alone, where no context can apply: a final sigma
%% lowers as any sigma does.
string_cases(Whole) ->
    Chars = unicode:characters_to_list(Whole),
    Lower = unicode:characters_to_binary([string:lowercase([Char]) || Char <- Chars]),
    Upper = unicode:characters_to_binary([string:uppercase([Char]) || Char <- Chars]),
    ?STRING:toLower(Whole) =:= Lower andalso ?STRING:toUpper(Whole) =:= Upper.

string_lines(Whole) ->
    ?STRING:lines(Whole) =:= lines_model(Whole).

string_words(Whole) ->
    ?STRING:words(Whole) =:= words_model(Whole).

string_to_int(Numeral) ->
    ?STRING:toInt(Numeral) =:= int_model(Numeral, 10).

string_int_back(Int) ->
    ?STRING:toInt(?INT:toString(Int)) =:= {'Some', Int}.

string_to_int_base({Numeral, Base}) ->
    ?STRING:toIntBase(Numeral, Base) =:= int_model(Numeral, Base).

string_to_bool(<<"true">>) -> ?STRING:toBool(<<"true">>) =:= {'Some', true};
string_to_bool(<<"false">>) -> ?STRING:toBool(<<"false">>) =:= {'Some', false};
string_to_bool(Other) -> ?STRING:toBool(Other) =:= 'None'.

string_to_float(Numeral) ->
    ?STRING:toFloat(Numeral) =:= float_model(Numeral).

string_utf8(Whole) ->
    ?STRING:fromUtf8(?STRING:toUtf8(Whole)) =:= {'Some', Whole}.

string_from_utf8(Octets) ->
    Expected = case unicode:characters_to_binary(Octets) of
                   Octets -> {'Some', Octets};
                   _ -> 'None'
               end,
    ?STRING:fromUtf8(Octets) =:= Expected.

string_compare({First, Second}) ->
    Order = ordering(unicode:characters_to_list(First), unicode:characters_to_list(Second)),
    ?STRING:compare(First, Second) =:= Order
        andalso ?STRING:'<>'(First, Second) =:= <<First/binary, Second/binary>>.

%%
%% Char
%%

%% report Appendix E.6: a character's code point and back, the ASCII digits,
%% a digit's value in a base, the classes, the single case forms, the order
%% by code point
char_laws_test_() ->
    laws([{"fromCodePoint of toCodePoint, toString", fun one_char/1, fun char_code/1},
          {"fromCodePoint: None outside U+0000 to U+10FFFF and for a surrogate",
           fun code_point/1, fun char_from_code_point/1},
          {"isAsciiDigit: 0 to 9 alone, each a digit", fun one_char/1, fun char_ascii_digit/1},
          {"digitValue: 0 to 9, then a letter of either case, under a base of 2 to 36",
           fun char_and_base/1, fun char_digit_value/1},
          {"the classes: a letter of a case a letter, a digit or a space none", fun one_char/1,
           fun char_classes/1},
          {"toUpper and toLower: itself where there is no single form", fun one_char/1,
           fun char_cases/1},
          {"compare by code point", fun two_chars/1, fun char_compare/1}]).

char_code(Char) ->
    ?CHAR:fromCodePoint(?CHAR:toCodePoint(Char)) =:= {'Some', Char}
        andalso ?CHAR:toString(Char) =:= unicode:characters_to_binary([Char]).

char_from_code_point(Code) ->
    Surrogate = Code >= 16#D800 andalso Code =< 16#DFFF,
    Valid = Code >= 0 andalso Code =< 16#10FFFF andalso not Surrogate,
    ?CHAR:fromCodePoint(Code) =:= kept(Valid, Code).

char_ascii_digit(Char) ->
    Ascii = Char >= $0 andalso Char =< $9,
    ?CHAR:isAsciiDigit(Char) =:= Ascii andalso (not Ascii orelse ?CHAR:isDigit(Char)).

char_digit_value({Char, Base}) ->
    Place = if
                Char >= $0, Char =< $9 -> Char - $0;
                Char >= $a, Char =< $z -> Char - $a + 10;
                Char >= $A, Char =< $Z -> Char - $A + 10;
                true -> none
            end,
    InBase = Place =/= none andalso Base >= 2 andalso Base =< 36 andalso Place < Base,
    ?CHAR:digitValue(Char, Base) =:= kept(InBase, Place).

char_classes(Char) ->
    Alpha = ?CHAR:isAlpha(Char),
    (not ?CHAR:isUpper(Char) orelse Alpha)
        andalso (not ?CHAR:isLower(Char) orelse Alpha)
        andalso not (?CHAR:isDigit(Char) andalso Alpha)
        andalso not (?CHAR:isSpace(Char) andalso (Alpha orelse ?CHAR:isDigit(Char))).

char_cases(Char) ->
    Single = fun(Mapped) ->
                     case unicode:characters_to_list(Mapped) of
                         [One] -> One;
                         _ -> Char
                     end
             end,
    ?CHAR:toUpper(Char) =:= Single(string:uppercase([Char]))
        andalso ?CHAR:toLower(Char) =:= Single(string:lowercase([Char])).

char_compare({First, Second}) ->
    ?CHAR:compare(First, Second) =:= ordering(First, Second).

%%
%% Int
%%

%% report Appendix E.8, §3.1: integer arithmetic exact, `div` and `rem`
%% truncating with the sign of the first, the bits, the shifts, the writing
%% in a base read back
int_laws_test_() ->
    laws([{"abs, min, max, negate, compare", fun two_ints_any/1, fun int_order/1},
          {"div and rem: a / b * b + a % b is a, the sign of a, None where b is 0",
           fun two_ints_any/1, fun int_division/1},
          {"the bits", fun two_ints_any/1, fun int_bits/1},
          {"shifts: by a power of two, arithmetic, below 0 none", fun int_and_shift/1,
           fun int_shifts/1},
          {"pow exact, None for a negative exponent, 0 to 0 is 1", fun two_small/1,
           fun int_pow/1},
          {"toString and toStringBase, read back by String", fun int_and_base/1,
           fun int_written/1},
          {"toFloat: the nearest Float", fun int/1, fun int_to_float/1}]).

int_order({First, Second}) ->
    ?INT:abs(First) =:= abs(First)
        andalso ?INT:min(First, Second) =:= min(First, Second)
        andalso ?INT:max(First, Second) =:= max(First, Second)
        andalso ?INT:negate(First) =:= -First
        andalso ?INT:compare(First, Second) =:= ordering(First, Second).

int_division({_, 0}) ->
    ?INT:'div'(1, 0) =:= 'None' andalso ?INT:'rem'(1, 0) =:= 'None';
int_division({First, Second}) ->
    {'Some', Quotient} = ?INT:'div'(First, Second),
    {'Some', Remainder} = ?INT:'rem'(First, Second),
    Quotient * Second + Remainder =:= First andalso abs(Remainder) < abs(Second)
        andalso (Remainder =:= 0 orelse (Remainder > 0) =:= (First > 0))
        andalso Quotient =:= ?INT:'/'(First, Second)
        andalso Remainder =:= ?INT:'%'(First, Second).

int_bits({First, Second}) ->
    ?INT:bitAnd(First, Second) =:= First band Second
        andalso ?INT:bitOr(First, Second) =:= First bor Second
        andalso ?INT:bitXor(First, Second) =:= First bxor Second
        andalso ?INT:bitNot(First) =:= bnot First.

int_shifts({Int, Count}) ->
    Power = 1 bsl max(Count, 0),
    ?INT:shiftLeft(Int, Count) =:= Int * Power
        andalso ?INT:shiftRight(Int, Count) =:= floor_div(Int, Power).

int_pow({Base, Exponent}) when Exponent < 0 -> ?INT:pow(Base, Exponent) =:= 'None';
int_pow({Base, Exponent}) -> ?INT:pow(Base, Exponent) =:= {'Some', power(Base, Exponent)}.

int_written({Int, Base}) when Base < 2; Base > 36 ->
    ?INT:toString(Int) =:= integer_to_binary(Int) andalso ?INT:toStringBase(Int, Base) =:= 'None';
int_written({Int, Base}) ->
    Written = integer_to_binary(Int, Base),
    ?INT:toString(Int) =:= integer_to_binary(Int)
        andalso ?INT:toStringBase(Int, Base) =:= {'Some', Written}
        andalso ?STRING:toIntBase(Written, Base) =:= {'Some', Int}.

int_to_float(Int) ->
    ?INT:toFloat(Int) =:= erlang:float(Int).

%%
%% Float
%%

%% report Appendix E.9, §3.1: the roundings, the domains where an answer is
%% None, `toString` the shortest digits that read back, plain or with an
%% exponent
float_laws_test_() ->
    laws([{"abs, min, max, negate, compare", fun two_floats/1, fun float_order/1},
          {"round to the nearest, ties to even; truncate, floor, ceil", fun finite/1,
           fun float_roundings/1},
          {"sqrt, log, asin, acos: None outside their domains", fun finite/1,
           fun float_domains/1},
          {"pow: None for a negative base to a fraction and for 0 to a negative power",
           fun float_and_exponent/1, fun float_pow/1},
          {"toString: the shortest digits that read back, plain from 0.0001 to below 1e16",
           fun finite/1, fun float_written/1},
          {"exp and the trigonometric functions: the host's, a fault beyond the range, no -0.0",
           fun two_floats/1, fun float_host_functions/1}]).

%% Report Appendix E.9, §3.1: `exp`, `sin`, `cos`, `tan`, `atan` and `atan2`
%% are the host's floating-point library's, `exp` faulting beyond the finite
%% range, and none answers a negative zero, which Ernest has not.
float_host_functions({X, Y}) ->
    Pairs = [{?FLOAT:sin(X), math:sin(X)}, {?FLOAT:cos(X), math:cos(X)},
             {?FLOAT:tan(X), math:tan(X)}, {?FLOAT:atan(X), math:atan(X)},
             {?FLOAT:atan2(Y, X), math:atan2(Y, X)}],
    Exp = try math:exp(X) of
              Host -> ?FLOAT:exp(X) == Host
          catch
              error:badarith ->
                  try ?FLOAT:exp(X) of _ -> false
                  catch throw:{ern, fault, <<"float arithmetic error">>} -> true
                  end
          end,
    Exp andalso lists:all(fun({Ernest, Host}) -> Ernest == Host andalso Ernest =/= -0.0 end, Pairs).

float_order({First, Second}) ->
    ?FLOAT:abs(First) =:= abs(First)
        andalso ?FLOAT:min(First, Second) == min(First, Second)
        andalso ?FLOAT:max(First, Second) == max(First, Second)
        andalso ?FLOAT:negate(First) == -First
        andalso ?FLOAT:compare(First, Second) =:= ordering(First, Second).

float_roundings(Float) ->
    ?FLOAT:round(Float) =:= round_even(Float) andalso ?FLOAT:truncate(Float) =:= trunc(Float)
        andalso ?FLOAT:floor(Float) =:= floor(Float) andalso ?FLOAT:ceil(Float) =:= ceil(Float).

float_domains(Float) ->
    is_tuple(?FLOAT:sqrt(Float)) =:= (Float >= 0)
        andalso is_tuple(?FLOAT:log(Float)) =:= (Float > 0)
        andalso is_tuple(?FLOAT:asin(Float)) =:= (abs(Float) =< 1)
        andalso is_tuple(?FLOAT:acos(Float)) =:= (abs(Float) =< 1).

float_pow({Base, Exponent}) ->
    Fractional = Exponent /= erlang:float(trunc(Exponent)),
    Undefined = Base < 0 andalso Fractional orelse Base == 0 andalso Exponent < 0,
    is_tuple(?FLOAT:pow(Base, Exponent)) =:= not Undefined.

float_written(Float) ->
    Written = ?FLOAT:toString(Float),
    Plain = Float == 0 orelse abs(Float) >= 0.0001 andalso abs(Float) < 1.0e16,
    Shape = case Plain of
                true -> "^-?[0-9]+\\.[0-9]+$";
                false -> "^-?[0-9]\\.[0-9]+e-?[0-9]+$"
            end,
    re:run(Written, Shape) =/= nomatch
        andalso ?STRING:toFloat(Written) =:= {'Some', Float}
        andalso significant(Written) =:= significant(float_to_binary(Float, [short])).

%%
%% Optional and Either
%%

%% report Appendix E.10, E.11: the sum types' operations, and the two
%% conversions between them
optional_and_either_laws_test_() ->
    laws([{"Optional: isSome, isNone, withDefault, map, andThen", fun optional/1,
           fun optional_operations/1},
          {"Either: isLeft, isRight, withDefault, map, mapLeft, andThen", fun either/1,
           fun either_operations/1},
          {"toOptional of fromOptional", fun optional/1, fun either_from_optional/1}]).

optional_operations({Value, Default}) ->
    Some = Value =/= 'None',
    Step = fun(X) -> kept(X > 0, X - 1) end,
    Double = fun(X) -> X * 2 end,
    ?OPTIONAL:isSome(Value) =:= Some andalso ?OPTIONAL:isNone(Value) =:= not Some
        andalso ?OPTIONAL:withDefault(Value, Default) =:= on_some(Value, fun(X) -> X end, Default)
        andalso ?OPTIONAL:map(Value, Double) =:= on_some(Value, fun(X) -> {'Some', Double(X)} end)
        andalso ?OPTIONAL:andThen(Value, Step) =:= on_some(Value, Step).

either_operations({{Tag, Held} = Value, Default}) ->
    Right = Tag =:= 'Right',
    Then = fun(X) when X > 0 -> {'Right', X}; (X) -> {'Left', X} end,
    Next = fun(X) -> X + 1 end,
    {OnRight, OnLeft, Withheld} = case Right of
                                      true -> {fun(Result) -> Result end, fun(_) -> Value end,
                                               Held};
                                      false -> {fun(_) -> Value end, fun(Result) -> Result end,
                                                Default}
                                  end,
    ?EITHER:isLeft(Value) =:= not Right andalso ?EITHER:isRight(Value) =:= Right
        andalso ?EITHER:withDefault(Value, Default) =:= Withheld
        andalso ?EITHER:map(Value, Next) =:= OnRight({Tag, Next(Held)})
        andalso ?EITHER:mapLeft(Value, Next) =:= OnLeft({Tag, Next(Held)})
        andalso ?EITHER:andThen(Value, Then) =:= OnRight(Then(Held)).

either_from_optional({Value, Cause}) ->
    ?EITHER:toOptional(?EITHER:fromOptional(Value, Cause)) =:= Value
        andalso ?EITHER:fromOptional('None', Cause) =:= {'Left', Cause}.

%%
%% Path
%%

%% report Appendix E.14: a path's segments and back, its parent and its
%% name, its extension replaced and removed, one path under another, each
%% read by code points
path_laws_test_() ->
    laws([{"join of split, one separator between the segments", fun path_text/1,
           fun path_join_split/1},
          {"split of join, a root first staying a root", fun segments/1, fun path_split_join/1},
          {"parent and name: the path without its last segment, and that segment",
           fun segments/1, fun path_parent_name/1},
          {"extension: after the name's last dot, the dots that begin it beginning none",
           fun segments/1, fun path_extension/1},
          {"withExtension then extension, withoutExtension of both",
           fun segments_and_extension/1, fun path_with_extension/1},
          {"<>: the second under the first, an absolute second alone", fun two_segments/1,
           fun path_joined/1},
          {"under: the second under the first, but an absolute second or one that steps",
           fun two_segments/1, fun path_under/1},
          {"isAbsolute, toString", fun segments/1, fun path_text_of/1},
          {"the empty path: no segments, and nothing under a root", fun segments/1,
           fun path_empty/1}]).

%% The empty path, which no other draw makes: no segments, no parent, name
%% or extension, its extension left as it is, and `under` refusing it.
path_empty(Segments) ->
    Empty = {'Path', <<>>},
    ?PATH:split(Empty) =:= [] andalso ?PATH:join([]) =:= Empty
        andalso ?PATH:parent(Empty) =:= 'None' andalso ?PATH:name(Empty) =:= 'None'
        andalso ?PATH:extension(Empty) =:= 'None'
        andalso ?PATH:withExtension(Empty, <<"md">>) =:= Empty
        andalso ?PATH:withoutExtension(Empty) =:= Empty
        andalso ?PATH:under(?PATH:join(Segments), Empty) =:= 'None'
        andalso ?PATH:'<>'(?PATH:join(Segments), Empty) =:= ?PATH:join(Segments).

path_join_split(Text) ->
    ?PATH:join(?PATH:split({'Path', Text})) =:= {'Path', normal_path(Text)}.

path_split_join(Segments) ->
    ?PATH:split(?PATH:join(Segments)) =:= Segments.

path_parent_name([<<"/">>] = Segments) ->
    Path = ?PATH:join(Segments),
    ?PATH:parent(Path) =:= 'None' andalso ?PATH:name(Path) =:= 'None';
path_parent_name([Name]) ->
    Path = ?PATH:join([Name]),
    ?PATH:parent(Path) =:= 'None' andalso ?PATH:name(Path) =:= {'Some', Name};
path_parent_name(Segments) ->
    Path = ?PATH:join(Segments),
    ?PATH:parent(Path) =:= {'Some', ?PATH:join(lists:droplast(Segments))}
        andalso ?PATH:name(Path) =:= {'Some', lists:last(Segments)}.

path_extension(Segments) ->
    ?PATH:extension(?PATH:join(Segments)) =:= extension_model(lists:last(Segments)).

%% The root, `.` and `..` have no name to extend and are left as they are.
path_with_extension({Segments, Extension}) ->
    Path = ?PATH:join(Segments),
    With = ?PATH:withExtension(Path, Extension),
    Name = lists:last(Segments),
    case has_name(Name) of
        true ->
            ?PATH:extension(With) =:= {'Some', Extension}
                andalso ?PATH:withoutExtension(With) =:= ?PATH:withoutExtension(Path)
                andalso ?PATH:extension(?PATH:withoutExtension(Path))
                        =:= extension_model(stem(Name));
        false ->
            With =:= Path andalso ?PATH:withoutExtension(Path) =:= Path
    end.

path_joined({First, Second}) ->
    Expected = case hd(Second) of
                   <<"/">> -> ?PATH:join(Second);
                   _ -> ?PATH:join(First ++ Second)
               end,
    ?PATH:'<>'(?PATH:join(First), ?PATH:join(Second)) =:= Expected.

%% The second under the first where it is relative and each of its segments
%% names an entry, and None where it is absolute or has a `.` or `..`.
path_under({First, Second}) ->
    Root = ?PATH:join(First),
    Path = ?PATH:join(Second),
    Steps = hd(Second) =:= <<"/">>
        orelse lists:any(fun(Segment) -> lists:member(Segment, [<<".">>, <<"..">>]) end, Second),
    Expected = case Steps of
                   true -> 'None';
                   false -> {'Some', ?PATH:'<>'(Root, Path)}
               end,
    ?PATH:under(Root, Path) =:= Expected.

path_text_of(Segments) ->
    Path = ?PATH:join(Segments),
    ?PATH:isAbsolute(Path) =:= (hd(Segments) =:= <<"/">>)
        andalso ?PATH:toString(Path) =:= element(2, Path).

%%
%% Bytes
%%

%% report Appendix E.20: octets, the searches by octet, `split` then `join`
%% giving the bytes back, hexadecimal both ways
bytes_laws_test_() ->
    laws([{"size, isEmpty, get, toList, fromList", fun bytes_and_one/1, fun bytes_contents/1},
          {"fromList: None for a value outside 0 to 255", fun octet_values/1,
           fun bytes_from_list/1},
          {"slice from the index up to the end index, clipped, below 0 being 0",
           fun bytes_and_two/1, fun bytes_slice/1},
          {"indexOf, lastIndexOf, contains, startsWith, endsWith by octet",
           fun bytes_and_part/1, fun bytes_searches/1},
          {"split then join gives the bytes back; replace as split and join",
           fun bytes_part_bytes/1, fun bytes_split/1},
          {"repeat, <>", fun two_bytes_and_one/1, fun bytes_repeat/1},
          {"toHex upper-case, fromHex either case, None for an odd count or another digit",
           fun bytes/1, fun bytes_hex/1}]).

bytes_contents({Octets, Index}) ->
    List = binary_to_list(Octets),
    At = case Index >= 0 andalso Index < byte_size(Octets) of
             true -> {'Some', binary:at(Octets, Index)};
             false -> 'None'
         end,
    ?BYTES:size(Octets) =:= byte_size(Octets) andalso ?BYTES:isEmpty(Octets) =:= (Octets =:= <<>>)
        andalso ?BYTES:toList(Octets) =:= List
        andalso ?BYTES:fromList(List) =:= {'Some', Octets}
        andalso ?BYTES:get(Octets, Index) =:= At.

bytes_from_list(List) ->
    Expected = case lists:all(fun(X) -> X >= 0 andalso X =< 255 end, List) of
                   true -> {'Some', list_to_binary(List)};
                   false -> 'None'
               end,
    ?BYTES:fromList(List) =:= Expected.

bytes_slice({Octets, Index, End}) ->
    From = min(max(Index, 0), byte_size(Octets)),
    To = min(max(End, From), byte_size(Octets)),
    ?BYTES:slice(Octets, Index, End) =:= binary:part(Octets, From, To - From).

%% An empty second is at 0 and last at the size.
bytes_searches({Octets, Part}) ->
    Offsets = lists:seq(0, max(byte_size(Octets) - byte_size(Part), -1)),
    Found = [Offset || Offset <- Offsets, binary:part(Octets, Offset, byte_size(Part)) =:= Part],
    {First, Last} = case Part of
                        <<>> -> {{'Some', 0}, {'Some', byte_size(Octets)}};
                        _ -> {first(Found), first(lists:reverse(Found))}
                    end,
    Starts = binary:longest_common_prefix([Octets, Part]) =:= byte_size(Part),
    Ends = binary:longest_common_suffix([Octets, Part]) =:= byte_size(Part),
    ?BYTES:indexOf(Octets, Part) =:= First andalso ?BYTES:lastIndexOf(Octets, Part) =:= Last
        andalso ?BYTES:contains(Octets, Part) =:= (First =/= 'None')
        andalso ?BYTES:startsWith(Octets, Part) =:= Starts
        andalso ?BYTES:endsWith(Octets, Part) =:= Ends.

bytes_split({Octets, Separator, New}) ->
    {Parts, Replaced} = case Separator of
                            <<>> ->
                                {[Octets], Octets};
                            _ ->
                                Split = binary:split(Octets, Separator, [global]),
                                {Split, iolist_to_binary(lists:join(New, Split))}
                        end,
    ?BYTES:split(Octets, Separator) =:= Parts
        andalso ?BYTES:join(Parts, Separator) =:= Octets
        andalso ?BYTES:replace(Octets, Separator, New) =:= Replaced.

bytes_repeat({First, Second, Count}) ->
    ?BYTES:repeat(First, Count) =:= binary:copy(First, max(Count, 0))
        andalso ?BYTES:'<>'(First, Second) =:= <<First/binary, Second/binary>>.

bytes_hex(Octets) ->
    Hex = ?BYTES:toHex(Octets),
    Hex =:= binary:encode_hex(Octets)
        andalso ?BYTES:fromHex(Hex) =:= {'Some', Octets}
        andalso ?BYTES:fromHex(string:lowercase(Hex)) =:= {'Some', Octets}
        andalso ?BYTES:fromHex(<<Hex/binary, "A">>) =:= 'None'
        andalso ?BYTES:fromHex(<<Hex/binary, "G0">>) =:= 'None'.

%%
%% OrderedSet
%%

%% report Appendix E.25: the ordered set against a sorted list without
%% repeats, in its compare's order, two elements it calls Equal one, `put`
%% and `fromList` keeping the one already there
ordered_set_laws_test_() ->
    laws([{"fromList in order, toList, size, isEmpty, min, max", fun elements/1,
           fun ordered_set_contents/1},
          {"two elements the order calls Equal are one, the first kept", fun keyed_pairs/1,
           fun ordered_set_equal/1},
          {"contains, put, remove", fun elements_and_one/1, fun ordered_set_put_remove/1},
          {"union, intersection, difference, isSubset", fun two_element_lists/1,
           fun ordered_set_operations/1},
          {"map, filter, filterMap, foldLeft, forEach, any, all, find in order",
           fun elements_and_one/1, fun ordered_set_traversals/1}]).

ordered_set_contents(List) ->
    Set = ?ORDERED_SET:fromList(List, fun ?INT:compare/2),
    Ordered = lists:usort(List),
    ?ORDERED_SET:toList(Set) =:= Ordered
        andalso ?ORDERED_SET:size(Set) =:= length(Ordered)
        andalso ?ORDERED_SET:isEmpty(Set) =:= (Ordered =:= [])
        andalso ?ORDERED_SET:min(Set) =:= first(Ordered)
        andalso ?ORDERED_SET:max(Set) =:= first(lists:reverse(Ordered)).

ordered_set_equal(Pairs) ->
    ByKey = fun({Key, _}, {Other, _}) -> ?INT:compare(Key, Other) end,
    Set = ?ORDERED_SET:fromList(Pairs, ByKey),
    Kept = first_occurrences(fun({Key, _}) -> Key end, Pairs),
    Again = fun({Key, _}) -> ?ORDERED_SET:put(Set, {Key, again}, ByKey) =:= Set end,
    ?ORDERED_SET:toList(Set) =:= lists:keysort(1, Kept) andalso lists:all(Again, Kept).

ordered_set_put_remove({List, X}) ->
    Compare = fun ?INT:compare/2,
    Set = ?ORDERED_SET:fromList(List, Compare),
    ?ORDERED_SET:contains(Set, X, Compare) =:= lists:member(X, List)
        andalso ?ORDERED_SET:toList(?ORDERED_SET:put(Set, X, Compare)) =:= lists:usort([X | List])
        andalso ?ORDERED_SET:toList(?ORDERED_SET:remove(Set, X, Compare))
                =:= lists:usort(List) -- [X].

ordered_set_operations({Left, Right}) ->
    Compare = fun ?INT:compare/2,
    First = ?ORDERED_SET:fromList(Left, Compare),
    Second = ?ORDERED_SET:fromList(Right, Compare),
    {Ordered, Other} = {lists:usort(Left), lists:usort(Right)},
    Elements = fun(Set) -> ?ORDERED_SET:toList(Set) end,
    Elements(?ORDERED_SET:union(First, Second, Compare)) =:= ordsets:union(Ordered, Other)
        andalso Elements(?ORDERED_SET:intersection(First, Second, Compare))
                =:= ordsets:intersection(Ordered, Other)
        andalso Elements(?ORDERED_SET:difference(First, Second, Compare))
                =:= ordsets:subtract(Ordered, Other)
        andalso ?ORDERED_SET:isSubset(First, Second, Compare)
                =:= ordsets:is_subset(Ordered, Other).

ordered_set_traversals({List, Pivot}) ->
    Compare = fun ?INT:compare/2,
    Set = ?ORDERED_SET:fromList(List, Compare),
    Ordered = lists:usort(List),
    Keep = above(Pivot),
    Halved = fun(X) -> kept(Keep(X), X rem 2) end,
    ?ORDERED_SET:toList(?ORDERED_SET:map(Set, fun(X) -> -X end, Compare))
        =:= lists:usort([-X || X <- Ordered])
        andalso ?ORDERED_SET:toList(?ORDERED_SET:filter(Set, Keep)) =:= lists:filter(Keep, Ordered)
        andalso ?ORDERED_SET:toList(?ORDERED_SET:filterMap(Set, Halved, Compare))
                =:= lists:usort([X rem 2 || X <- Ordered, Keep(X)])
        andalso ?ORDERED_SET:foldLeft(Set, [], fun(Acc, X) -> [X | Acc] end)
                =:= lists:reverse(Ordered)
        andalso met(fun(Visit) -> ?ORDERED_SET:forEach(Set, Visit) end) =:= Ordered
        andalso ?ORDERED_SET:any(Set, Keep) =:= lists:any(Keep, Ordered)
        andalso ?ORDERED_SET:all(Set, Keep) =:= lists:all(Keep, Ordered)
        andalso ?ORDERED_SET:find(Set, Keep) =:= first(lists:filter(Keep, Ordered)).

%%
%% OrderedMap
%%

%% report Appendix E.26: the ordered map against a sorted list of pairs, a
%% later pair winning in `fromList`, `put` replacing the value, the entries
%% met in the keys' order
ordered_map_laws_test_() ->
    laws([{"fromList: a later pair wins, toList, keys and values in order", fun entries/1,
           fun ordered_map_contents/1},
          {"get after put, remove, contains, update", fun entries_and_entry/1,
           fun ordered_map_put/1},
          {"merge: the second wins; mergeWith: the key, the first's value, the second's",
           fun two_entry_lists/1, fun ordered_map_merge/1},
          {"map, filter, filterMap, foldLeft, forEach, any, all, find in order",
           fun entries_and_one/1, fun ordered_map_traversals/1},
          {"keys the order calls Equal: the key the map holds stays", fun tagged_entries/1,
           fun ordered_map_held_key/1}]).

%% Report Appendix E.26: two keys the order calls `Equal` are one key, and
%% the key the map holds stays; `put`, `update`, `merge` and `mergeWith`
%% replace its value, and `fromList`, putting each pair in turn, keeps the
%% first pair's key with the last pair's value. Keys are {Key, Tag}, the
%% order reading Key alone, so that a held key and a given one differ.
ordered_map_held_key({Pairs, {Key, _} = Given, Value}) ->
    ByKey = fun({Left, _}, {Right, _}) -> ?INT:compare(Left, Right) end,
    Map = ?ORDERED_MAP:fromList(Pairs, ByKey),
    Model = held_model(Pairs),
    Put = ?ORDERED_MAP:put(Map, Given, Value, ByKey),
    Updated = ?ORDERED_MAP:update(Map, Given, fun(_) -> Value end, ByKey),
    Merged = ?ORDERED_MAP:merge(Map, ?ORDERED_MAP:fromList([{Given, Value}], ByKey), ByKey),
    Expected = held_model(Pairs ++ [{Given, Value}]),
    ?ORDERED_MAP:toList(Map) =:= Model
        andalso ?ORDERED_MAP:toList(Put) =:= Expected
        andalso ?ORDERED_MAP:toList(Updated) =:= Expected
        andalso ?ORDERED_MAP:toList(Merged) =:= Expected
        andalso lists:keymember(Key, 1, [K || {K, _} <- Expected]).

%% The entries in order of Key, each with the first key of its Key and the
%% last value.
held_model(Pairs) ->
    Firsts = lists:foldl(fun({{Key, _} = Tagged, _}, Acc) ->
                             maps:update_with(Key, fun(Held) -> Held end, Tagged, Acc)
                         end, #{}, Pairs),
    Lasts = maps:from_list([{Key, Value} || {{Key, _}, Value} <- Pairs]),
    [{maps:get(Key, Firsts), Value} || {Key, Value} <- lists:sort(maps:to_list(Lasts))].

ordered_map_contents(Pairs) ->
    Map = ?ORDERED_MAP:fromList(Pairs, fun ?INT:compare/2),
    Expected = entries_model(Pairs),
    ?ORDERED_MAP:toList(Map) =:= Expected
        andalso ?ORDERED_MAP:keys(Map) =:= [Key || {Key, _} <- Expected]
        andalso ?ORDERED_MAP:values(Map) =:= [Value || {_, Value} <- Expected]
        andalso ?ORDERED_MAP:size(Map) =:= length(Expected)
        andalso ?ORDERED_MAP:isEmpty(Map) =:= (Expected =:= []).

ordered_map_put({Pairs, Key, Value}) ->
    Compare = fun ?INT:compare/2,
    Map = ?ORDERED_MAP:fromList(Pairs, Compare),
    Old = case lists:keyfind(Key, 1, entries_model(Pairs)) of
              {Key, Held} -> {'Some', Held};
              false -> 'None'
          end,
    Put = ?ORDERED_MAP:put(Map, Key, Value, Compare),
    ?ORDERED_MAP:get(Put, Key, Compare) =:= {'Some', Value}
        andalso ?ORDERED_MAP:toList(Put) =:= entries_model(Pairs ++ [{Key, Value}])
        andalso ?ORDERED_MAP:toList(?ORDERED_MAP:remove(Map, Key, Compare))
                =:= lists:keydelete(Key, 1, entries_model(Pairs))
        andalso ?ORDERED_MAP:contains(Map, Key, Compare) =:= (Old =/= 'None')
        andalso ?ORDERED_MAP:toList(?ORDERED_MAP:update(Map, Key, fun count/1, Compare))
                =:= entries_model(Pairs ++ [{Key, count(Old)}]).

ordered_map_merge({Left, Right}) ->
    Compare = fun ?INT:compare/2,
    First = ?ORDERED_MAP:fromList(Left, Compare),
    Second = ?ORDERED_MAP:fromList(Right, Compare),
    {Mine, Theirs} = {maps:from_list(Left), maps:from_list(Right)},
    Shared = maps:intersect_with(fun combined/3, Mine, Theirs),
    Merged = lists:sort(maps:to_list(maps:merge(maps:merge(Mine, Theirs), Shared))),
    ?ORDERED_MAP:toList(?ORDERED_MAP:merge(First, Second, Compare)) =:= entries_model(Left ++ Right)
        andalso ?ORDERED_MAP:toList(?ORDERED_MAP:mergeWith(First, Second, fun combined/3, Compare))
                =:= Merged.

ordered_map_traversals({Pairs, Pivot}) ->
    Map = ?ORDERED_MAP:fromList(Pairs, fun ?INT:compare/2),
    Expected = entries_model(Pairs),
    Keep = fun(Key, _) -> Key > Pivot end,
    Kept = [{Key, Value} || {Key, Value} <- Expected, Key > Pivot],
    Negated = fun(Key, Value) -> kept(Keep(Key, Value), -Value) end,
    Visits = fun(Visit) ->
                     ?ORDERED_MAP:forEach(Map, fun(Key, Value) -> Visit({Key, Value}) end)
             end,
    ?ORDERED_MAP:toList(?ORDERED_MAP:map(Map, fun(Key, Value) -> Key + Value end))
        =:= [{Key, Key + Value} || {Key, Value} <- Expected]
        andalso ?ORDERED_MAP:toList(?ORDERED_MAP:filter(Map, Keep)) =:= Kept
        andalso ?ORDERED_MAP:toList(?ORDERED_MAP:filterMap(Map, Negated))
                =:= [{Key, -Value} || {Key, Value} <- Kept]
        andalso ?ORDERED_MAP:foldLeft(Map, [], fun(Acc, Key, _) -> [Key | Acc] end)
                =:= lists:reverse([Key || {Key, _} <- Expected])
        andalso met(Visits) =:= Expected
        andalso ?ORDERED_MAP:any(Map, Keep) =:= (Kept =/= [])
        andalso ?ORDERED_MAP:all(Map, Keep) =:= (length(Kept) =:= length(Expected))
        andalso ?ORDERED_MAP:find(Map, Keep) =:= first(Kept).

%%
%% The runner
%%

%% Each law an EUnit test of its own, named for what it says.
laws(Laws) ->
    [{Name, {timeout, 60, fun() -> holds(Name, Draw, Law) end}} || {Name, Draw, Law} <- Laws].

%% The law on ?CASES cases from a seed of its own; the first case that
%% breaks it, with the seed.
holds(Name, Draw, Law) ->
    Seed = case os:getenv("ERN_SEED") of
               false -> erlang:phash2({erlang:monotonic_time(), self(), Name});
               Given -> list_to_integer(Given)
           end,
    rand:seed(exsss, Seed),
    %% report §8.5: the modules' top-level bindings, `Map.empty` among them,
    %% and those of the modules they build on
    ern_rt:init_modules([?LIST, ?STRING, ?MAP, ?SET, ?ORDERED_SET, ?ORDERED_MAP, ?BYTES, ?INT,
                         ?FLOAT, ?CHAR, ?OPTIONAL, ?EITHER, ?PATH]),
    ?assertEqual(none, broken(Draw, Law, Seed, 1)).

broken(_, _, _, Number) when Number > ?CASES ->
    none;
broken(Draw, Law, Seed, Number) ->
    Drawn = Draw(1 + Number div 10),
    Outcome = try Law(Drawn)
              catch Class:Error:Trace -> {Class, Error, lists:sublist(Trace, 2)}
              end,
    case Outcome of
        true -> broken(Draw, Law, Seed, Number + 1);
        _ -> #{seed => Seed, drawn => Drawn, outcome => Outcome}
    end.

%%
%% The generators: each takes a size and draws a case of about it
%%

%% A small integer, a negative among them, for counts, indexes and keys.
small(Size) -> rand:uniform(2 * Size + 5) - Size - 3.

%% An integer of any size, beyond a machine word too.
int(Size) ->
    case rand:uniform(4) of
        1 -> small(Size);
        2 -> rand:uniform(2001) - 1001;
        3 -> rand:uniform(1 bsl 64) - (1 bsl 63);
        _ -> rand:uniform(1 bsl 200) - (1 bsl 199)
    end.

%% A finite float: small and whole, a half for the ties, a fraction, the
%% very large and the very small.
finite(Size) ->
    case rand:uniform(6) of
        1 -> erlang:float(small(Size));
        2 -> small(Size) + 0.5;
        3 -> (rand:uniform() - 0.5) * 2000;
        4 -> (rand:uniform() - 0.5) * 1.0e20;
        5 -> (rand:uniform() - 0.5) * 1.0e-10;
        _ -> pick([0.0, 1.0, -1.0, 0.0001, 1.0e16, 9.999999999999998e15, 1.0e300, 5.0e-324])
    end.

list(Size, Draw) ->
    [Draw(Size) || _ <- lists:seq(1, rand:uniform(Size + 1) - 1)].

pick(Choices) ->
    lists:nth(rand:uniform(length(Choices)), Choices).

ints(Size) -> list(Size, fun small/1).
ints_and_int(Size) -> {ints(Size), small(Size)}.
two_ints(Size) -> {ints(Size), ints(Size)}.
two_small(Size) -> {small(Size), small(Size)}.
two_ints_any(Size) -> {int(Size), int(Size)}.
int_and_shift(Size) -> {int(Size), small(Size) * 3}.
int_and_base(Size) -> {int(Size), small(Size) + 18}.
two_floats(Size) -> {finite(Size), finite(Size)}.
float_and_exponent(Size) ->
    {pick([0.0, -2.0, 2.0, erlang:float(small(Size))]), pick([-1.0, 0.5, 2.0, -0.5, 3.0])}.
keyed_pairs(Size) -> list(Size, fun(Inner) -> {small(Inner) rem 5, small(Inner)} end).
entries(Size) -> list(Size, fun(Inner) -> {small(Inner) rem 7, small(Inner)} end).
entries_and_entry(Size) -> {entries(Size), small(Size) rem 7, small(Size)}.
entries_and_one(Size) -> {entries(Size), small(Size) rem 7}.
two_entry_lists(Size) -> {entries(Size), entries(Size)}.
map_and_key(Size) -> {?MAP:fromList(entries(Size)), small(Size) rem 7, small(Size)}.
two_maps(Size) -> {?MAP:fromList(entries(Size)), ?MAP:fromList(entries(Size))}.
elements(Size) -> list(Size, fun(Inner) -> small(Inner) rem 9 end).
elements_and_one(Size) -> {elements(Size), small(Size) rem 9}.
two_element_lists(Size) -> {elements(Size), elements(Size)}.
optional(Size) -> {pick(['None', {'Some', small(Size)}]), small(Size)}.
either(Size) -> {pick([{'Left', small(Size)}, {'Right', small(Size)}]), small(Size)}.
one_char(_) -> char().
two_chars(_) -> {char(), char()}.
%% A character and a base, one past each end of 2 to 36 among them.
char_and_base(_) -> {char(), rand:uniform(40) - 2}.
code_point(Size) ->
    pick([int(Size), 16#D800 + rand:uniform(16#800) - 1, 16#10FFFF + rand:uniform(3) - 1,
          rand:uniform(16#110000) - 1]).
two_texts(Size) -> {text(Size), text(Size)}.
text_and_one(Size) -> {text(Size), small(Size)}.
text_and_two(Size) -> {text(Size), small(Size), small(Size)}.
text_count_pad(Size) -> {text(Size), small(Size) + 3, text(2)}.
texts_and_text(Size) -> {list(Size, fun text/1), text(Size)}.
text_and_part(Size) -> Whole = text(Size), {Whole, part_of(Whole, Size)}.
text_part_text(Size) -> Whole = text(Size), {Whole, part_of(Whole, Size), text(Size)}.
numeral_and_base(Size) -> {numeral(Size), small(Size) + 18}.
boolean_text(Size) -> pick([<<"true">>, <<"false">>, <<"True">>, <<" true">>, text(Size)]).
bytes_and_one(Size) -> {bytes(Size), small(Size)}.
bytes_and_two(Size) -> {bytes(Size), small(Size), small(Size)}.
two_bytes_and_one(Size) -> {bytes(Size), bytes(Size), small(Size)}.
octet_values(Size) -> list(Size, fun(Inner) -> small(Inner) * 40 end).
bytes_and_part(Size) -> Whole = bytes(Size), {Whole, byte_part(Whole, Size)}.
bytes_part_bytes(Size) -> Whole = bytes(Size), {Whole, byte_part(Whole, Size), bytes(Size)}.
segments_and_extension(Size) -> {segments(Size), pick([<<"md">>, <<"tar">>, <<"x1">>])}.
two_segments(Size) -> {segments(Size), segments(Size)}.

%% A character from the places text is hard: letters, digits, whitespace,
%% line ends, combining marks, regional indicators, emoji with joiners and
%% modifiers, Hangul, a prepended mark, a virama, cased letters whose case
%% maps to more than one.
char() ->
    Draw = pick([fun() -> $a + rand:uniform(26) - 1 end,
                 fun() -> $A + rand:uniform(26) - 1 end,
                 fun() -> pick("0123456789-.") end,
                 fun() -> pick(" \t\n\r\n\r") end,
                 fun() -> pick([16#00A0, 16#2028, 16#3000, 16#0085, 16#200B, 16#FEFF, 16#1680]) end,
                 fun() -> 16#0300 + rand:uniform(16#6F) - 1 end,
                 fun() -> 16#1F1E6 + rand:uniform(4) - 1 end,
                 fun() -> pick([16#1F600, 16#1F468, 16#200D, 16#2764, 16#FE0F, 16#1F3FB]) end,
                 fun() -> pick([16#AC00, 16#1100, 16#1161, 16#11A8]) end,
                 fun() -> pick([16#0600, 16#0915, 16#094D, 16#0660]) end,
                 fun() -> pick([16#DF, 16#130, 16#131, 16#3A3, 16#3C3, 16#3C2, 16#E9]) end]),
    Draw().

text(Size) ->
    unicode:characters_to_binary(list(Size, fun(_) -> char() end)).

%% A part of a string to search for: as often as not characters that stand
%% in it, which may begin or end inside a grapheme, else a string of its own.
part_of(Whole, Size) ->
    Chars = unicode:characters_to_list(Whole),
    case Chars =/= [] andalso rand:uniform(2) =:= 1 of
        true ->
            From = rand:uniform(length(Chars)),
            unicode:characters_to_binary(lists:sublist(Chars, From, rand:uniform(3)));
        false ->
            text(Size div 3)
    end.

bytes(Size) ->
    list_to_binary(list(Size, fun(_) -> pick([0, 1, 10, 13, 255, rand:uniform(256) - 1]) end)).

byte_part(Whole, Size) ->
    case Whole =/= <<>> andalso rand:uniform(2) =:= 1 of
        true ->
            From = rand:uniform(byte_size(Whole)) - 1,
            binary:part(Whole, From, min(rand:uniform(3), byte_size(Whole) - From));
        false ->
            bytes(Size div 3)
    end.

%% A numeral, mostly well formed, in a base up to 36.
numeral(Size) ->
    Digits = list(Size, fun(_) -> pick("0123456789abcxyzABCXYZ") end),
    Sign = pick(["", "", "-", "+", " "]),
    Odd = pick(["", "", "", "_", " ", [16#0660], "-"]),
    unicode:characters_to_binary([Sign, Digits, Odd]).

%% A float numeral, mostly well formed by §2.5, the forms it does not read
%% among it.
float_numeral(Size) ->
    Digits = fun() -> [pick("0123456789") || _ <- lists:seq(1, rand:uniform(3))] end,
    Exponent = fun() -> [pick(["e", "E"]), pick(["", "-", "+"]), Digits()] end,
    Forms = [[Digits(), ".", Digits()], [Digits(), ".", Digits(), Exponent()],
             [Digits(), Exponent()], [Digits()], [".", Digits()], [Digits(), "."],
             [Digits(), "_", Digits(), ".", Digits()], ["1.0e400"], ["1.0e-400"],
             [?FLOAT:toString(finite(Size))]],
    iolist_to_binary([pick(["", "", "-", "+"]), pick(Forms)]).

%% A path in the runtime's syntax, a root or not, separators doubled and
%% trailing, segments with dots.
path_text(Size) ->
    Segments = [pick(["a", "b.txt", ".rc", "c.d.e", "f.", "..", ".", marked()])
                || _ <- lists:seq(1, rand:uniform(Size + 2))],
    Body = lists:append([[pick(["/", "/", "//"]), Segment] || Segment <- Segments]),
    Text = case rand:uniform(2) of
               1 -> Body;
               _ -> tl(Body)
           end,
    unicode:characters_to_binary([Text, pick(["", "", "/"])]).

%% Report Appendix E.14: a name where graphemes and code points part, a
%% combining mark after a dot or at a name's start, which joins the
%% separator before it, and a prepended mark at a name's end, which joins
%% the separator after it.
marked() ->
    pick([[$a, $., 16#301], [16#301, $x], [$b, 16#600], [$., 16#301, $y]]).

%% A path's segments as split gives them.
segments(Size) ->
    Names = [pick([<<"a">>, <<"b.txt">>, <<".rc">>, <<"c.d.e">>, <<"f.">>, <<"..">>, <<".">>,
                   <<"x.tar.gz">>, unicode:characters_to_binary(marked())])
             || _ <- lists:seq(1, rand:uniform(Size + 1))],
    case rand:uniform(3) of
        1 -> [<<"/">> | Names];
        2 -> pick([[<<"/">>], Names]);
        _ -> Names
    end.

%%
%% The models
%%

first([]) -> 'None';
first([X | _]) -> {'Some', X}.

kept(true, X) -> {'Some', X};
kept(false, _) -> 'None'.

on_some(Value, Then) -> on_some(Value, Then, 'None').

on_some({'Some', X}, Then, _) -> Then(X);
on_some('None', _, Otherwise) -> Otherwise.

either_map({'Right', X}, F) -> {'Right', F(X)};
either_map(Left, _) -> Left.

above(Pivot) -> fun(Element) -> Element > Pivot end.

count('None') -> 1;
count({'Some', Count}) -> Count + 1.

combined(Key, Mine, Theirs) -> Key * 100 + Mine * 10 + Theirs.

ordering(First, Second) when First < Second -> 'Less';
ordering(First, Second) when First > Second -> 'Greater';
ordering(_, _) -> 'Equal'.

first_occurrences(Key, List) ->
    {Kept, _} = lists:foldl(fun(X, {Acc, Seen}) ->
                                case maps:is_key(Key(X), Seen) of
                                    true -> {Acc, Seen};
                                    false -> {[X | Acc], Seen#{Key(X) => true}}
                                end
                            end, {[], #{}}, List),
    lists:reverse(Kept).

%% Entries whose keys are {Key, Tag}, keys the order calls `Equal` drawn
%% with other tags, and an entry to put among them.
tagged_entries(Size) ->
    Tagged = fun(Inner) -> {small(Inner) rem 5, pick([first, second, third])} end,
    {list(Size, fun(Inner) -> {Tagged(Inner), small(Inner)} end), Tagged(Size), small(Size)}.

entries_model(Pairs) ->
    lists:sort(maps:to_list(maps:from_list(Pairs))).

%% What a forEach met, in the order it met it.
met(Run) ->
    Self = self(),
    Tag = make_ref(),
    'Unit' = Run(fun(Element) -> Self ! {Tag, Element}, 'Unit' end),
    collect(Tag).

collect(Tag) ->
    receive
        {Tag, Element} -> [Element | collect(Tag)]
    after 0 -> []
    end.

%% The byte offsets at which the string's graphemes begin, and its end.
boundaries(Whole) ->
    Step = fun(Grapheme, Offset) -> {Offset, Offset + byte_size(Grapheme)} end,
    {Offsets, _} = lists:mapfoldl(Step, 0, ?STRING:graphemes(Whole)),
    Offsets ++ [byte_size(Whole)].

%% Where the part stands in the string as whole graphemes, beginning and
%% ending where the string's graphemes do: each the graphemes before it and
%% its offset, first to last.
occurrences(_, <<>>) ->
    [];
occurrences(Whole, Part) ->
    Bounds = boundaries(Whole),
    [{Index, Offset} || {Index, Offset} <- lists:enumerate(0, Bounds),
                        Offset + byte_size(Part) =< byte_size(Whole),
                        binary:part(Whole, Offset, byte_size(Part)) =:= Part,
                        lists:member(Offset + byte_size(Part), Bounds)].

split_model(Whole, <<>>) ->
    [Whole];
split_model(Whole, Separator) ->
    case occurrences(Whole, Separator) of
        [] -> [Whole];
        [{_, Offset} | _] ->
            After = Offset + byte_size(Separator),
            [binary:part(Whole, 0, Offset)
             | split_model(binary:part(Whole, After, byte_size(Whole) - After), Separator)]
    end.

is_space_grapheme(Grapheme) ->
    [First | _] = unicode:characters_to_list(Grapheme),
    ?CHAR:isSpace(First).

%% Whether a pad's graphemes stay its own beside any text: letters, digits
%% and the like alone.
plain(Pad) ->
    lists:all(fun(Char) -> Char >= $0 andalso Char =< $z end, unicode:characters_to_list(Pad)).

lines_model(<<>>) ->
    [];
lines_model(Whole) ->
    Parts = lists:append([binary:split(Part, <<"\n">>, [global])
                          || Part <- binary:split(Whole, <<"\r\n">>, [global])]),
    case lists:last(Parts) of
        <<>> -> lists:droplast(Parts);
        _ -> Parts
    end.

words_model(Whole) ->
    Split = fun(Grapheme, [Word | Rest]) ->
                    case is_space_grapheme(Grapheme) of
                        true -> [[], Word | Rest];
                        false -> [[Grapheme | Word] | Rest]
                    end
            end,
    Words = lists:foldr(Split, [[]], ?STRING:graphemes(Whole)),
    [iolist_to_binary(Word) || Word <- Words, Word =/= []].

%% A numeral in a base from 2 to 36: an optional leading -, then at least
%% one digit or letter, either case, below the base.
int_model(_, Base) when Base < 2; Base > 36 ->
    'None';
int_model(Numeral, Base) ->
    {Negative, Digits} = case unicode:characters_to_list(Numeral) of
                             [$- | Rest] -> {true, Rest};
                             Chars -> {false, Chars}
                         end,
    Values = [digit_value(Char) || Char <- Digits],
    Valid = Values =/= [] andalso lists:all(fun(Value) -> Value < Base end, Values),
    Value = lists:foldl(fun(Digit, Acc) -> Acc * Base + Digit end, 0, Values),
    kept(Valid, case Negative of true -> -Value; false -> Value end).

digit_value(Char) when Char >= $0, Char =< $9 -> Char - $0;
digit_value(Char) when Char >= $a, Char =< $z -> Char - $a + 10;
digit_value(Char) when Char >= $A, Char =< $Z -> Char - $A + 10;
digit_value(_) -> 99.

%% §2.5's float without `_`, an optional leading -: digits and a point and
%% digits with an exponent after or not, or digits and an exponent; the
%% nearest Float, None beyond the finite range.
float_model(Numeral) ->
    Shape = "^-?[0-9]+(\\.[0-9]+([eE][-+]?[0-9]+)?|[eE][-+]?[0-9]+)$",
    case re:run(Numeral, Shape) of
        nomatch ->
            'None';
        _ ->
            Pointed = case binary:match(Numeral, <<".">>) of
                          nomatch -> re:replace(Numeral, "[eE]", ".0e", [{return, binary}]);
                          _ -> Numeral
                      end,
            %% report §3.1: there is no negative zero
            try {'Some', binary_to_float(Pointed) + 0.0}
            catch error:badarg -> 'None'
            end
    end.

%% A numeral's significant digits, its sign, point, exponent and the zeros
%% around them aside: the shortest that read back are those of the host's
%% `short` form.
significant(Numeral) ->
    [Mantissa | _] = string:split(string:lowercase(binary_to_list(Numeral)), "e"),
    string:trim([Char || Char <- Mantissa, Char >= $0, Char =< $9], both, "0").

round_even(Float) ->
    Floor = floor(Float),
    case Float - Floor of
        Half when Half == 0.5 ->
            case Floor rem 2 of
                0 -> Floor;
                _ -> Floor + 1
            end;
        Fraction when Fraction < 0.5 ->
            Floor;
        _ ->
            Floor + 1
    end.

floor_div(Int, Power) when Int >= 0 -> Int div Power;
floor_div(Int, Power) -> -((-Int + Power - 1) div Power).

power(_, 0) -> 1;
power(Base, Exponent) -> Base * power(Base, Exponent - 1).

%% The path as split and join write it: one separator between segments, a
%% root kept, none trailing, empty segments gone.
normal_path(Text) ->
    Segments = [Segment || Segment <- binary:split(Text, <<"/">>, [global]), Segment =/= <<>>],
    Root = case Text of
               <<"/", _/binary>> -> <<"/">>;
               _ -> <<>>
           end,
    iolist_to_binary([Root, lists:join(<<"/">>, Segments)]).

%% A name's extension: after its last dot, the dots that begin it beginning
%% none, read by bytes as the runtime reads a path; the root has no name.
extension_model(<<"/">>) ->
    'None';
extension_model(Name) ->
    Rest = without_leading_dots(Name),
    case binary:matches(Rest, <<".">>) of
        [] -> 'None';
        Dots ->
            {Offset, _} = lists:last(Dots),
            {'Some', binary:part(Rest, Offset + 1, byte_size(Rest) - Offset - 1)}
    end.

without_leading_dots(<<".", Rest/binary>>) -> without_leading_dots(Rest);
without_leading_dots(Name) -> Name.

has_name(Name) ->
    not lists:member(Name, [<<"/">>, <<".">>, <<"..">>]).

%% The name without its extension.
stem(Name) ->
    case extension_model(Name) of
        'None' -> Name;
        {'Some', Extension} ->
            binary:part(Name, 0, byte_size(Name) - byte_size(Extension) - 1)
    end.
