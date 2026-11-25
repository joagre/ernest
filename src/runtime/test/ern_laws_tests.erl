%% The standard library's laws as properties: what
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


%%
%% List
%%

%% report Appendix E.2: the list's operations against Erlang's own on lists,
%% `sort` stable, `take` and `drop` splitting a list, the first `Left` ending
%% `tryMap`, `tryFold` and `tryForEach`
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
          {"splitWhile: the longest prefix that satisfies, and the rest",
           fun ints_and_int/1, fun list_split_while/1},
          {"partition: each in order", fun ints_and_int/1, fun list_partition/1},
          {"unique: the first occurrence of each, in order", fun ints/1, fun list_unique/1},
          {"indexed from 0", fun ints/1, fun list_indexed/1},
          {"repeat: n copies, below 0 none", fun two_small/1, fun list_repeat/1},
          {"reverse", fun ints/1, fun list_reverse/1},
          {"sort is stable", fun keyed_pairs/1, fun list_sort/1},
          {"minimum and maximum: the first of the least and of the greatest",
           fun keyed_pairs/1, fun list_extremes/1},
          {"zip to the shorter length, and unzip", fun two_ints/1, fun list_zip/1},
          {"flatMap", fun ints/1, fun list_flat_map/1},
          {"range inclusive, empty when the first is greater", fun two_small/1,
           fun list_range/1},
          {"tryMap, tryFold and tryForEach end at the first Left", fun ints_and_int/1,
           fun list_tries/1},
          {"<> appends", fun two_ints/1, fun list_append/1}]).

list_size(Items) ->
    List = ern_named:functions('ern@list'),
    List(size)(Items) =:= length(Items) andalso List(isEmpty)(Items) =:= (Items =:= []).

list_contains({Items, X}) ->
    List = ern_named:functions('ern@list'),
    List(contains)(Items, X) =:= lists:member(X, Items).

list_get({Items, Index}) ->
    List = ern_named:functions('ern@list'),
    Expected = case Index >= 0 andalso Index < length(Items) of
                   true -> {'Some', lists:nth(Index + 1, Items)};
                   false -> 'None'
               end,
    List(get)(Items, Index) =:= Expected.

list_remove_at({Items, Index}) when Index >= 0, Index < length(Items) ->
    List = ern_named:functions('ern@list'),
    {Before, [_ | After]} = lists:split(Index, Items),
    List(removeAt)(Items, Index) =:= Before ++ After;
list_remove_at({Items, Index}) ->
    List = ern_named:functions('ern@list'),
    List(removeAt)(Items, Index) =:= Items.

list_map_filter({Items, Pivot}) ->
    List = ern_named:functions('ern@list'),
    Keep = above(Pivot),
    Tenfold = fun(X) -> kept(Keep(X), X * 10) end,
    List(map)(Items, fun(X) -> X * 2 end) =:= [X * 2 || X <- Items]
        andalso List(filter)(Items, Keep) =:= lists:filter(Keep, Items)
        andalso List(filterMap)(Items, Tenfold) =:= [X * 10 || X <- Items, Keep(X)].

list_folds(Items) ->
    List = ern_named:functions('ern@list'),
    List(foldLeft)(Items, [], fun(Acc, X) -> [X | Acc] end) =:= lists:reverse(Items)
        andalso List(foldRight)(Items, [], fun(Acc, X) -> [X | Acc] end) =:= Items.

list_for_each(Items) ->
    List = ern_named:functions('ern@list'),
    met(fun(Visit) -> List(forEach)(Items, Visit) end) =:= Items.

list_search({Items, Pivot}) ->
    List = ern_named:functions('ern@list'),
    Keep = above(Pivot),
    List(any)(Items, Keep) =:= lists:any(Keep, Items)
        andalso List(all)(Items, Keep) =:= lists:all(Keep, Items)
        andalso List(find)(Items, Keep) =:= first(lists:filter(Keep, Items)).

list_last(Items) ->
    List = ern_named:functions('ern@list'),
    List(last)(Items) =:= first(lists:reverse(Items)).

list_take_drop({Items, Count}) ->
    List = ern_named:functions('ern@list'),
    Taken = List(take)(Items, Count),
    Taken ++ List(drop)(Items, Count) =:= Items
        andalso length(Taken) =:= min(max(Count, 0), length(Items)).

list_drop_last({Items, Count}) ->
    List = ern_named:functions('ern@list'),
    Kept = max(length(Items) - max(Count, 0), 0),
    List(dropLast)(Items, Count) =:= lists:sublist(Items, Kept).

list_take_last({Items, Count}) ->
    List = ern_named:functions('ern@list'),
    Taken = List(takeLast)(Items, Count),
    List(dropLast)(Items, Count) ++ Taken =:= Items
        andalso length(Taken) =:= min(max(Count, 0), length(Items)).

list_split_while({Items, Pivot}) ->
    List = ern_named:functions('ern@list'),
    List(splitWhile)(Items, above(Pivot)) =:= lists:splitwith(above(Pivot), Items).

list_partition({Items, Pivot}) ->
    List = ern_named:functions('ern@list'),
    List(partition)(Items, above(Pivot)) =:= lists:partition(above(Pivot), Items).

list_unique(Items) ->
    List = ern_named:functions('ern@list'),
    List(unique)(Items) =:= first_occurrences(fun(X) -> X end, Items).

list_indexed(Items) ->
    List = ern_named:functions('ern@list'),
    List(indexed)(Items) =:= lists:zip(lists:seq(0, length(Items) - 1), Items).

list_repeat({X, Count}) ->
    List = ern_named:functions('ern@list'),
    List(repeat)(X, Count) =:= lists:duplicate(max(Count, 0), X).

list_reverse(Items) ->
    List = ern_named:functions('ern@list'),
    List(reverse)(Items) =:= lists:reverse(Items).

%% Erlang's merge sort keeps equal elements in order where the ordering
%% says true of two equal ones.
list_sort(Pairs) ->
    List = ern_named:functions('ern@list'),
    Int = ern_named:functions('ern@int'),
    ByKey = fun({Key, _}, {Other, _}) -> Int(compare)(Key, Other) end,
    Stable = lists:sort(fun({Key, _}, {Other, _}) -> Key =< Other end, Pairs),
    List(sort)(Pairs, ByKey) =:= Stable.

%% The order reads the key alone, so that two elements it calls Equal
%% differ, and the first of them is the one answered.
list_extremes(Pairs) ->
    List = ern_named:functions('ern@list'),
    Int = ern_named:functions('ern@int'),
    ByKey = fun({Key, _}, {Other, _}) -> Int(compare)(Key, Other) end,
    Keys = [Key || {Key, _} <- Pairs],
    Expected = case Pairs of
                   [] -> {'None', 'None'};
                   _ -> {{'Some', lists:keyfind(lists:min(Keys), 1, Pairs)},
                         {'Some', lists:keyfind(lists:max(Keys), 1, Pairs)}}
               end,
    {List(minimum)(Pairs, ByKey), List(maximum)(Pairs, ByKey)} =:= Expected.

list_zip({First, Second}) ->
    List = ern_named:functions('ern@list'),
    Count = min(length(First), length(Second)),
    {Firsts, Seconds} = {lists:sublist(First, Count), lists:sublist(Second, Count)},
    Zipped = List(zip)(First, Second),
    Zipped =:= lists:zip(Firsts, Seconds) andalso List(unzip)(Zipped) =:= {Firsts, Seconds}.

list_flat_map(Items) ->
    List = ern_named:functions('ern@list'),
    Twice = fun(X) -> [X, X] end,
    List(flatMap)(Items, Twice) =:= lists:flatmap(Twice, Items).

list_range({From, To}) when From > To ->
    List = ern_named:functions('ern@list'),
    List(range)(From, To) =:= [];
list_range({From, To}) ->
    List = ern_named:functions('ern@list'),
    List(range)(From, To) =:= lists:seq(From, To).

list_tries({Items, Pivot}) ->
    List = ern_named:functions('ern@list'),
    Step = fun(X) ->
                   case X > Pivot of
                       true -> {'Left', X};
                       false -> {'Right', X * 2}
                   end
           end,
    Fold = fun(Acc, X) -> either_map(Step(X), fun(Doubled) -> Acc + Doubled end) end,
    Doubled = [X * 2 || X <- Items],
    {Mapped, Folded, Walked} =
        case lists:search(above(Pivot), Items) of
            {value, Bad} -> {{'Left', Bad}, {'Left', Bad}, {'Left', Bad}};
            false -> {{'Right', Doubled}, {'Right', lists:sum(Doubled)}, {'Right', 'Unit'}}
        end,
    %% the elements tryForEach's step sees are those before the first Left, in order
    put(seen, []),
    Visit = fun(X) -> either_map(Step(X), fun(_) -> put(seen, [X | get(seen)]), 'Unit' end) end,
    Seen = lists:takewhile(fun(X) -> X =< Pivot end, Items),
    List(tryMap)(Items, Step) =:= Mapped andalso List(tryFold)(Items, 0, Fold) =:= Folded
        andalso List(tryForEach)(Items, Visit) =:= Walked andalso lists:reverse(get(seen)) =:= Seen.

list_append({First, Second}) ->
    List = ern_named:functions('ern@list'),
    List('<>')(First, Second) =:= First ++ Second.

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
    Map = ern_named:functions('ern@map'),
    Entries = Map(fromList)(Pairs),
    Met = met(fun(Visit) -> Map(forEach)(Entries, fun(Key, Value) -> Visit({Key, Value}) end) end),
    lists:sort(Met) =:= lists:sort(maps:to_list(Entries)).

map_from_list(Pairs) ->
    Map = ern_named:functions('ern@map'),
    Map(fromList)(Pairs) =:= maps:from_list(Pairs).

map_contents(Pairs) ->
    Map = ern_named:functions('ern@map'),
    Entries = Map(fromList)(Pairs),
    Model = maps:from_list(Pairs),
    Map(size)(Entries) =:= maps:size(Model)
        andalso Map(isEmpty)(Entries) =:= (maps:size(Model) =:= 0)
        andalso lists:sort(Map(toList)(Entries)) =:= lists:sort(maps:to_list(Model))
        andalso lists:sort(Map(keys)(Entries)) =:= lists:sort(maps:keys(Model))
        andalso lists:sort(Map(values)(Entries)) =:= lists:sort(maps:values(Model)).

map_put({Entries, Key, Value}) ->
    Map = ern_named:functions('ern@map'),
    Put = Map(put)(Entries, Key, Value),
    Map(get)(Put, Key) =:= {'Some', Value}
        andalso maps:remove(Key, Put) =:= maps:remove(Key, Entries)
        andalso Map(contains)(Entries, Key) =:= maps:is_key(Key, Entries).

map_remove({Entries, Key, _}) ->
    Map = ern_named:functions('ern@map'),
    Removed = Map(remove)(Entries, Key),
    Map(get)(Removed, Key) =:= 'None' andalso Removed =:= maps:remove(Key, Entries).

map_update({Entries, Key, _}) ->
    Map = ern_named:functions('ern@map'),
    Old = case Entries of
              #{Key := Value} -> {'Some', Value};
              _ -> 'None'
          end,
    Map(update)(Entries, Key, fun count/1) =:= Entries#{Key => count(Old)}.

map_traversals({Entries, Pivot, _}) ->
    Map = ern_named:functions('ern@map'),
    Keep = fun(Key, _) -> Key > Pivot end,
    Sum = fun(Key, Value) -> Key + Value end,
    Negated = fun(Key, Value) -> kept(Keep(Key, Value), -Value) end,
    Weighted = fun(Key, Value, Acc) -> Acc + Key * Value end,
    Map(map)(Entries, Sum) =:= maps:map(Sum, Entries)
        andalso Map(filter)(Entries, Keep) =:= maps:filter(Keep, Entries)
        andalso Map(filterMap)(Entries, Negated)
                =:= maps:map(fun(_, Value) -> -Value end, maps:filter(Keep, Entries))
        andalso Map(fold)(Entries, 0, fun(Acc, Key, Value) -> Weighted(Key, Value, Acc) end)
                =:= maps:fold(Weighted, 0, Entries).

map_search({Entries, Pivot, _}) ->
    Map = ern_named:functions('ern@map'),
    Keep = fun(Key, _) -> Key > Pivot end,
    Satisfying = maps:filter(Keep, Entries),
    Found = case Map(find)(Entries, Keep) of
                'None' -> maps:size(Satisfying) =:= 0;
                {'Some', {Key, Value}} -> maps:get(Key, Satisfying, none) =:= Value
            end,
    Map(any)(Entries, Keep) =:= (maps:size(Satisfying) > 0)
        andalso Map(all)(Entries, Keep) =:= (maps:size(Satisfying) =:= maps:size(Entries))
        andalso Found.

map_merge({First, Second}) ->
    Map = ern_named:functions('ern@map'),
    Shared = maps:intersect_with(fun combined/3, First, Second),
    Map(merge)(First, Second) =:= maps:merge(First, Second)
        andalso Map(mergeWith)(First, Second, fun combined/3)
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
    Set = ern_named:functions('ern@set'),
    Members = Set(fromList)(List),
    lists:sort(met(fun(Visit) -> Set(forEach)(Members, Visit) end)) =:= lists:usort(List).

set_contents(List) ->
    Set = ern_named:functions('ern@set'),
    Members = Set(fromList)(List),
    members(Members) =:= lists:usort(List)
        andalso Set(size)(Members) =:= length(lists:usort(List))
        andalso Set(isEmpty)(Members) =:= (List =:= []).

set_put_remove({List, X}) ->
    Set = ern_named:functions('ern@set'),
    Members = Set(fromList)(List),
    Set(contains)(Members, X) =:= lists:member(X, List)
        andalso members(Set(put)(Members, X)) =:= lists:usort([X | List])
        andalso members(Set(remove)(Members, X)) =:= lists:usort(List) -- [X]
        andalso Set(put)(Set(put)(Members, X), X) =:= Set(put)(Members, X).

set_operations({Left, Right}) ->
    Set = ern_named:functions('ern@set'),
    {First, Second} = {Set(fromList)(Left), Set(fromList)(Right)},
    {LeftSet, RightSet} = {lists:usort(Left), lists:usort(Right)},
    members(Set(union)(First, Second)) =:= ordsets:union(LeftSet, RightSet)
        andalso members(Set(intersection)(First, Second))
                =:= ordsets:intersection(LeftSet, RightSet)
        andalso members(Set(difference)(First, Second)) =:= ordsets:subtract(LeftSet, RightSet)
        andalso Set(isSubset)(First, Second) =:= ordsets:is_subset(LeftSet, RightSet).

set_traversals({List, Pivot}) ->
    Set = ern_named:functions('ern@set'),
    Members = Set(fromList)(List),
    Ordered = lists:usort(List),
    Keep = above(Pivot),
    Tripled = fun(X) -> kept(Keep(X), X * 3) end,
    Found = case Set(find)(Members, Keep) of
                'None' -> not lists:any(Keep, Ordered);
                {'Some', X} -> Keep(X) andalso lists:member(X, Ordered)
            end,
    members(Set(map)(Members, fun(X) -> X div 2 end)) =:= lists:usort([X div 2 || X <- Ordered])
        andalso members(Set(filter)(Members, Keep)) =:= lists:filter(Keep, Ordered)
        andalso members(Set(filterMap)(Members, Tripled)) =:= [X * 3 || X <- Ordered, Keep(X)]
        andalso Set(fold)(Members, 0, fun(Acc, X) -> Acc + X end) =:= lists:sum(Ordered)
        andalso Set(any)(Members, Keep) =:= lists:any(Keep, Ordered)
        andalso Set(all)(Members, Keep) =:= lists:all(Keep, Ordered)
        andalso Found.

members(Members) ->
    Set = ern_named:functions('ern@set'),
    lists:sort(Set(toList)(Members)).

%%
%% String
%%

%% report Appendix E.5: text, every search matching whole graphemes of the
%% string searched, `split` then `join` giving the string back, `replace` as
%% `split` and `join`, the slices and the pads counted in graphemes, the
%% ASCII case
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
          {"toAsciiLower and toAsciiUpper: A to Z and a to z alone, each code point else kept",
           fun text/1, fun string_ascii_cases/1},
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
    String = ern_named:functions('ern@string'),
    String(toList)(Whole) =:= unicode:characters_to_list(Whole)
        andalso String(fromList)(String(toList)(Whole)) =:= Whole.

string_graphemes(Whole) ->
    String = ern_named:functions('ern@string'),
    Graphemes = String(graphemes)(Whole),
    iolist_to_binary(Graphemes) =:= Whole
        andalso String(size)(Whole) =:= length(Graphemes)
        andalso lists:all(fun(Grapheme) -> String(size)(Grapheme) =:= 1 end, Graphemes)
        andalso String(isEmpty)(Whole) =:= (Whole =:= <<>>).

%% An empty second is at 0 and last at the size.
string_index_of({Whole, Part}) ->
    String = ern_named:functions('ern@string'),
    Found = [Index || {Index, _} <- occurrences(Whole, Part)],
    {First, Last} = case {Part, Found} of
                        {<<>>, _} -> {{'Some', 0}, {'Some', String(size)(Whole)}};
                        _ -> {first(Found), first(lists:reverse(Found))}
                    end,
    String(indexOf)(Whole, Part) =:= First
        andalso String(lastIndexOf)(Whole, Part) =:= Last
        andalso String(contains)(Whole, Part) =:= (First =/= 'None').

string_starts_ends({Whole, Part}) ->
    String = ern_named:functions('ern@string'),
    Bounds = boundaries(Whole),
    Starts = binary:longest_common_prefix([Whole, Part]) =:= byte_size(Part)
        andalso lists:member(byte_size(Part), Bounds),
    Ends = binary:longest_common_suffix([Whole, Part]) =:= byte_size(Part)
        andalso lists:member(byte_size(Whole) - byte_size(Part), Bounds),
    String(startsWith)(Whole, Part) =:= Starts andalso String(endsWith)(Whole, Part) =:= Ends.

string_split({Whole, Separator}) ->
    String = ern_named:functions('ern@string'),
    Parts = String(split)(Whole, Separator),
    Parts =:= split_model(Whole, Separator) andalso String(join)(Parts, Separator) =:= Whole.

string_join({Parts, Separator}) ->
    String = ern_named:functions('ern@string'),
    String(join)(Parts, Separator) =:= iolist_to_binary(lists:join(Separator, Parts)).

string_replace({Whole, Old, New}) ->
    String = ern_named:functions('ern@string'),
    Expected = case Old of
                   <<>> -> Whole;
                   _ -> iolist_to_binary(lists:join(New, split_model(Whole, Old)))
               end,
    String(replace)(Whole, Old, New) =:= Expected.

string_slice({Whole, Index, End}) ->
    String = ern_named:functions('ern@string'),
    Graphemes = String(graphemes)(Whole),
    From = min(max(Index, 0), length(Graphemes)),
    To = min(max(End, From), length(Graphemes)),
    Expected = iolist_to_binary(lists:sublist(lists:nthtail(From, Graphemes), To - From)),
    String(slice)(Whole, Index, End) =:= Expected.

%% The pad stands before or after the string as written, a prefix of its
%% copies; where nothing is missing or the pad is empty, the string alone;
%% and a pad of letters and digits, which joins no grapheme, makes the size
%% asked for.
string_pads({Whole, Count, Pad}) ->
    String = ern_named:functions('ern@string'),
    Missing = Count - String(size)(Whole),
    Copies = binary:copy(Pad, max(Missing, 0) + 1),
    Started = String(padStart)(Whole, Count, Pad),
    Ended = String(padEnd)(Whole, Count, Pad),
    Front = binary:part(Started, 0, byte_size(Started) - byte_size(Whole)),
    Back = binary:part(Ended, byte_size(Whole), byte_size(Ended) - byte_size(Whole)),
    Padded = Missing > 0 andalso Pad =/= <<>>,
    binary:longest_common_suffix([Started, Whole]) =:= byte_size(Whole)
        andalso binary:longest_common_prefix([Ended, Whole]) =:= byte_size(Whole)
        andalso binary:longest_common_prefix([Copies, Front]) =:= byte_size(Front)
        andalso binary:longest_common_prefix([Copies, Back]) =:= byte_size(Back)
        andalso (Padded orelse Started =:= Whole andalso Ended =:= Whole)
        andalso (not Padded orelse not plain(Pad) orelse String(size)(Front) =:= Missing).

string_repeat({Whole, Count}) ->
    String = ern_named:functions('ern@string'),
    String(repeat)(Whole, Count) =:= binary:copy(Whole, max(Count, 0)).

string_trims(Whole) ->
    String = ern_named:functions('ern@string'),
    Graphemes = String(graphemes)(Whole),
    Spaces = fun is_space_grapheme/1,
    Started = lists:dropwhile(Spaces, Graphemes),
    Ended = lists:reverse(lists:dropwhile(Spaces, lists:reverse(Graphemes))),
    Both = lists:reverse(lists:dropwhile(Spaces, lists:reverse(Started))),
    String(trimStart)(Whole) =:= iolist_to_binary(Started)
        andalso String(trimEnd)(Whole) =:= iolist_to_binary(Ended)
        andalso String(trim)(Whole) =:= iolist_to_binary(Both).

%% Each code point mapped alone, where no context can apply: a final sigma
%% lowers as any sigma does.
string_cases(Whole) ->
    String = ern_named:functions('ern@string'),
    Chars = unicode:characters_to_list(Whole),
    Lower = unicode:characters_to_binary([string:lowercase([Char]) || Char <- Chars]),
    Upper = unicode:characters_to_binary([string:uppercase([Char]) || Char <- Chars]),
    String(toLower)(Whole) =:= Lower andalso String(toUpper)(Whole) =:= Upper.

string_ascii_cases(Whole) ->
    String = ern_named:functions('ern@string'),
    Chars = unicode:characters_to_list(Whole),
    String(toAsciiLower)(Whole) =:= unicode:characters_to_binary([ascii_lower(C) || C <- Chars])
        andalso String(toAsciiUpper)(Whole)
                    =:= unicode:characters_to_binary([ascii_upper(C) || C <- Chars]).

ascii_lower(Char) when Char >= $A, Char =< $Z -> Char - $A + $a;
ascii_lower(Char) -> Char.

ascii_upper(Char) when Char >= $a, Char =< $z -> Char - $a + $A;
ascii_upper(Char) -> Char.

string_lines(Whole) ->
    String = ern_named:functions('ern@string'),
    String(lines)(Whole) =:= lines_model(Whole).

string_words(Whole) ->
    String = ern_named:functions('ern@string'),
    String(words)(Whole) =:= words_model(Whole).

string_to_int(Numeral) ->
    String = ern_named:functions('ern@string'),
    String(toInt)(Numeral) =:= int_model(Numeral, 10).

string_int_back(Integer) ->
    String = ern_named:functions('ern@string'),
    Int = ern_named:functions('ern@int'),
    String(toInt)(Int(toString)(Integer)) =:= {'Some', Integer}.

string_to_int_base({Numeral, Base}) ->
    String = ern_named:functions('ern@string'),
    String(toIntBase)(Numeral, Base) =:= int_model(Numeral, Base).

string_to_bool(<<"true">>) ->
    String = ern_named:functions('ern@string'),
    String(toBool)(<<"true">>) =:= {'Some', true};
string_to_bool(<<"false">>) ->
    String = ern_named:functions('ern@string'),
    String(toBool)(<<"false">>) =:= {'Some', false};
string_to_bool(Other) ->
    String = ern_named:functions('ern@string'),
    String(toBool)(Other) =:= 'None'.

string_to_float(Numeral) ->
    String = ern_named:functions('ern@string'),
    String(toFloat)(Numeral) =:= float_model(Numeral).

string_utf8(Whole) ->
    String = ern_named:functions('ern@string'),
    String(fromUtf8)(String(toUtf8)(Whole)) =:= {'Some', Whole}.

string_from_utf8(Octets) ->
    String = ern_named:functions('ern@string'),
    Expected = case unicode:characters_to_binary(Octets) of
                   Octets -> {'Some', Octets};
                   _ -> 'None'
               end,
    String(fromUtf8)(Octets) =:= Expected.

string_compare({First, Second}) ->
    String = ern_named:functions('ern@string'),
    Order = ordering(unicode:characters_to_list(First), unicode:characters_to_list(Second)),
    String(compare)(First, Second) =:= Order
        andalso String('<>')(First, Second) =:= <<First/binary, Second/binary>>.

%%
%% Char
%%

%% report Appendix E.6: a character's code point and back, the ASCII digits,
%% a digit's value in a base, the classes, the single case forms, the ASCII
%% case, the order by code point
char_laws_test_() ->
    laws([{"fromCodePoint of toCodePoint, toString", fun one_char/1, fun char_code/1},
          {"fromCodePoint: None outside U+0000 to U+10FFFF and for a surrogate",
           fun code_point/1, fun char_from_code_point/1},
          {"isAsciiDigit: 0 to 9 alone, each a digit", fun one_char/1, fun char_ascii_digit/1},
          {"digitValue: 0 to 9, then a letter of either case, under a base of 2 to 36",
           fun char_and_base/1, fun char_digit_value/1},
          {"the classes: a letter of a case a letter, a digit a number and a separator a space,"
           " and at most one of the seven categories", fun one_char/1, fun char_classes/1},
          {"toUpper and toLower: itself where there is no single form", fun one_char/1,
           fun char_cases/1},
          {"toAsciiLower and toAsciiUpper: A to Z and a to z alone, itself otherwise",
           fun one_char/1, fun char_ascii_cases/1},
          {"compare by code point", fun two_chars/1, fun char_compare/1}]).

char_code(CodePoint) ->
    Char = ern_named:functions('ern@char'),
    Char(fromCodePoint)(Char(toCodePoint)(CodePoint)) =:= {'Some', CodePoint}
        andalso Char(toString)(CodePoint) =:= unicode:characters_to_binary([CodePoint]).

char_from_code_point(Code) ->
    Char = ern_named:functions('ern@char'),
    Surrogate = Code >= 16#D800 andalso Code =< 16#DFFF,
    Valid = Code >= 0 andalso Code =< 16#10FFFF andalso not Surrogate,
    Char(fromCodePoint)(Code) =:= kept(Valid, Code).

char_ascii_digit(CodePoint) ->
    Char = ern_named:functions('ern@char'),
    Ascii = CodePoint >= $0 andalso CodePoint =< $9,
    Char(isAsciiDigit)(CodePoint) =:= Ascii andalso (not Ascii orelse Char(isDigit)(CodePoint)).

char_digit_value({CodePoint, Base}) ->
    Char = ern_named:functions('ern@char'),
    Place = if
                CodePoint >= $0, CodePoint =< $9 -> CodePoint - $0;
                CodePoint >= $a, CodePoint =< $z -> CodePoint - $a + 10;
                CodePoint >= $A, CodePoint =< $Z -> CodePoint - $A + 10;
                true -> none
            end,
    InBase = Place =/= none andalso Base >= 2 andalso Base =< 36 andalso Place < Base,
    Char(digitValue)(CodePoint, Base) =:= kept(InBase, Place).

char_classes(CodePoint) ->
    Char = ern_named:functions('ern@char'),
    Alpha = Char(isAlpha)(CodePoint),
    Categories = [Char(Predicate)(CodePoint)
                  || Predicate <- [isAlpha, isMark, isNumber, isPunctuation, isSymbol,
                                   isSeparator, isControl]],
    (not Char(isUpper)(CodePoint) orelse Alpha)
        andalso (not Char(isLower)(CodePoint) orelse Alpha)
        andalso (not Char(isDigit)(CodePoint) orelse Char(isNumber)(CodePoint))
        andalso (not Char(isSeparator)(CodePoint) orelse Char(isSpace)(CodePoint))
        andalso not (Char(isSpace)(CodePoint) andalso (Alpha orelse Char(isDigit)(CodePoint)))
        andalso length([true || true <- Categories]) =< 1.

char_cases(CodePoint) ->
    Char = ern_named:functions('ern@char'),
    Single = fun(Mapped) ->
                     case unicode:characters_to_list(Mapped) of
                         [One] -> One;
                         _ -> CodePoint
                     end
             end,
    Char(toUpper)(CodePoint) =:= Single(string:uppercase([CodePoint]))
        andalso Char(toLower)(CodePoint) =:= Single(string:lowercase([CodePoint])).

char_ascii_cases(CodePoint) ->
    Char = ern_named:functions('ern@char'),
    Char(toAsciiLower)(CodePoint) =:= ascii_lower(CodePoint)
        andalso Char(toAsciiUpper)(CodePoint) =:= ascii_upper(CodePoint).

char_compare({First, Second}) ->
    Char = ern_named:functions('ern@char'),
    Char(compare)(First, Second) =:= ordering(First, Second).

%%
%% Int
%%

%% report Appendix E.8, §3.1, §7.4: integer arithmetic exact, `div` and
%% `rem` truncating with the sign of the first, the bits, the shifts, the
%% writing in a base read back, a base outside 2 to 36 a fault
int_laws_test_() ->
    laws([{"abs, min, max, negate, compare", fun two_ints_any/1, fun int_order/1},
          {"div and rem: a / b * b + a % b is a, the sign of a, None where b is 0",
           fun two_ints_any/1, fun int_division/1},
          {"the bits", fun two_ints_any/1, fun int_bits/1},
          {"shifts: by a power of two, arithmetic, below 0 none", fun int_and_shift/1,
           fun int_shifts/1},
          {"pow exact, None for a negative exponent, 0 to 0 is 1", fun two_small/1,
           fun int_pow/1},
          {"toString and toStringBase, read back by String, faulting outside 2 to 36",
           fun int_and_base/1,
           fun int_written/1},
          {"toFloat: the nearest Float", fun int/1, fun int_to_float/1}]).

int_order({First, Second}) ->
    Int = ern_named:functions('ern@int'),
    Int(abs)(First) =:= abs(First)
        andalso Int(min)(First, Second) =:= min(First, Second)
        andalso Int(max)(First, Second) =:= max(First, Second)
        andalso Int(negate)(First) =:= -First
        andalso Int(compare)(First, Second) =:= ordering(First, Second).

int_division({_, 0}) ->
    Int = ern_named:functions('ern@int'),
    Int('div')(1, 0) =:= 'None' andalso Int('rem')(1, 0) =:= 'None';
int_division({First, Second}) ->
    Int = ern_named:functions('ern@int'),
    {'Some', Quotient} = Int('div')(First, Second),
    {'Some', Remainder} = Int('rem')(First, Second),
    Quotient * Second + Remainder =:= First andalso abs(Remainder) < abs(Second)
        andalso (Remainder =:= 0 orelse (Remainder > 0) =:= (First > 0))
        andalso Quotient =:= Int('/')(First, Second)
        andalso Remainder =:= Int('%')(First, Second).

int_bits({First, Second}) ->
    Int = ern_named:functions('ern@int'),
    Int(bitAnd)(First, Second) =:= First band Second
        andalso Int(bitOr)(First, Second) =:= First bor Second
        andalso Int(bitXor)(First, Second) =:= First bxor Second
        andalso Int(bitNot)(First) =:= bnot First.

int_shifts({Integer, Count}) ->
    Int = ern_named:functions('ern@int'),
    Power = 1 bsl max(Count, 0),
    Int(shiftLeft)(Integer, Count) =:= Integer * Power
        andalso Int(shiftRight)(Integer, Count) =:= floor_div(Integer, Power).

int_pow({Base, Exponent}) when Exponent < 0 ->
    Int = ern_named:functions('ern@int'),
    Int(pow)(Base, Exponent) =:= 'None';
int_pow({Base, Exponent}) ->
    Int = ern_named:functions('ern@int'),
    Int(pow)(Base, Exponent) =:= {'Some', power(Base, Exponent)}.

int_written({Integer, Base}) when Base < 2; Base > 36 ->
    Int = ern_named:functions('ern@int'),
    Int(toString)(Integer) =:= integer_to_binary(Integer)
        andalso (try Int(toStringBase)(Integer, Base) catch throw:Fault -> Fault end)
                =:= {ern, fault, <<"a base is from 2 to 36">>};
int_written({Integer, Base}) ->
    String = ern_named:functions('ern@string'),
    Int = ern_named:functions('ern@int'),
    Written = integer_to_binary(Integer, Base),
    Int(toString)(Integer) =:= integer_to_binary(Integer)
        andalso Int(toStringBase)(Integer, Base) =:= Written
        andalso String(toIntBase)(Written, Base) =:= {'Some', Integer}.

int_to_float(Integer) ->
    Int = ern_named:functions('ern@int'),
    Int(toFloat)(Integer) =:= erlang:float(Integer).

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
    Float = ern_named:functions('ern@float'),
    Pairs = [{Float(sin)(X), math:sin(X)}, {Float(cos)(X), math:cos(X)},
             {Float(tan)(X), math:tan(X)}, {Float(atan)(X), math:atan(X)},
             {Float(atan2)(Y, X), math:atan2(Y, X)}],
    Exp = try math:exp(X) of
              Host -> Float(exp)(X) == Host
          catch
              error:badarith ->
                  try Float(exp)(X) of _ -> false
                  catch throw:{ern, fault, <<"float arithmetic error">>} -> true
                  end
          end,
    Exp andalso lists:all(fun({Ernest, Host}) -> Ernest == Host andalso Ernest =/= -0.0 end, Pairs).

float_order({First, Second}) ->
    Float = ern_named:functions('ern@float'),
    Float(abs)(First) =:= abs(First)
        andalso Float(min)(First, Second) == min(First, Second)
        andalso Float(max)(First, Second) == max(First, Second)
        andalso Float(negate)(First) == -First
        andalso Float(compare)(First, Second) =:= ordering(First, Second).

float_roundings(Real) ->
    Float = ern_named:functions('ern@float'),
    Float(round)(Real) =:= round_even(Real) andalso Float(truncate)(Real) =:= trunc(Real)
        andalso Float(floor)(Real) =:= floor(Real) andalso Float(ceil)(Real) =:= ceil(Real).

float_domains(Real) ->
    Float = ern_named:functions('ern@float'),
    is_tuple(Float(sqrt)(Real)) =:= (Real >= 0)
        andalso is_tuple(Float(log)(Real)) =:= (Real > 0)
        andalso is_tuple(Float(asin)(Real)) =:= (abs(Real) =< 1)
        andalso is_tuple(Float(acos)(Real)) =:= (abs(Real) =< 1).

float_pow({Base, Exponent}) ->
    Float = ern_named:functions('ern@float'),
    Fractional = Exponent /= erlang:float(trunc(Exponent)),
    Undefined = Base < 0 andalso Fractional orelse Base == 0 andalso Exponent < 0,
    is_tuple(Float(pow)(Base, Exponent)) =:= not Undefined.

float_written(Real) ->
    String = ern_named:functions('ern@string'),
    Float = ern_named:functions('ern@float'),
    Written = Float(toString)(Real),
    Plain = Real == 0 orelse abs(Real) >= 0.0001 andalso abs(Real) < 1.0e16,
    Shape = case Plain of
                true -> "^-?[0-9]+\\.[0-9]+$";
                false -> "^-?[0-9]\\.[0-9]+e-?[0-9]+$"
            end,
    re:run(Written, Shape) =/= nomatch
        andalso String(toFloat)(Written) =:= {'Some', Real}
        andalso significant(Written) =:= significant(float_to_binary(Real, [short])).

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
    Optional = ern_named:functions('ern@optional'),
    Some = Value =/= 'None',
    Step = fun(X) -> kept(X > 0, X - 1) end,
    Double = fun(X) -> X * 2 end,
    Optional(isSome)(Value) =:= Some andalso Optional(isNone)(Value) =:= not Some
        andalso Optional(withDefault)(Value, Default) =:= on_some(Value, fun(X) -> X end, Default)
        andalso Optional(map)(Value, Double) =:= on_some(Value, fun(X) -> {'Some', Double(X)} end)
        andalso Optional(andThen)(Value, Step) =:= on_some(Value, Step).

either_operations({{Tag, Held} = Value, Default}) ->
    Either = ern_named:functions('ern@either'),
    Right = Tag =:= 'Right',
    Then = fun(X) when X > 0 -> {'Right', X}; (X) -> {'Left', X} end,
    Next = fun(X) -> X + 1 end,
    {OnRight, OnLeft, Withheld} = case Right of
                                      true -> {fun(Result) -> Result end, fun(_) -> Value end,
                                               Held};
                                      false -> {fun(_) -> Value end, fun(Result) -> Result end,
                                                Default}
                                  end,
    Either(isLeft)(Value) =:= not Right andalso Either(isRight)(Value) =:= Right
        andalso Either(withDefault)(Value, Default) =:= Withheld
        andalso Either(map)(Value, Next) =:= OnRight({Tag, Next(Held)})
        andalso Either(mapLeft)(Value, Next) =:= OnLeft({Tag, Next(Held)})
        andalso Either(andThen)(Value, Then) =:= OnRight(Then(Held)).

either_from_optional({Value, Cause}) ->
    Either = ern_named:functions('ern@either'),
    Either(toOptional)(Either(fromOptional)(Value, Cause)) =:= Value
        andalso Either(fromOptional)('None', Cause) =:= {'Left', Cause}.

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
          {"from: under's inverse, both ways", fun two_segments/1, fun path_from/1},
          {"isAbsolute, toString", fun segments/1, fun path_text_of/1},
          {"the empty path: no segments, and nothing under a root", fun segments/1,
           fun path_empty/1}]).

%% The empty path, which no other draw makes: no segments, no parent, name
%% or extension, its extension left as it is, `under` refusing it, `from`
%% naming nothing from a directory with it, and every path from it as
%% `under` places the path under it.
path_empty(Segments) ->
    Path = ern_named:functions('ern@path'),
    Empty = {'Path', <<>>},
    PathText = Path(join)(Segments),
    Path(split)(Empty) =:= [] andalso Path(join)([]) =:= Empty
        andalso Path(parent)(Empty) =:= 'None' andalso Path(name)(Empty) =:= 'None'
        andalso Path(extension)(Empty) =:= 'None'
        andalso Path(withExtension)(Empty, <<"md">>) =:= Empty
        andalso Path(withoutExtension)(Empty) =:= Empty
        andalso Path(under)(PathText, Empty) =:= 'None'
        andalso Path('<>')(PathText, Empty) =:= PathText
        andalso Path(from)(Empty, PathText) =:= 'None' andalso Path(from)(Empty, Empty) =:= 'None'
        andalso Path(from)(PathText, Empty) =:= Path(under)(Empty, PathText).

path_join_split(Text) ->
    Path = ern_named:functions('ern@path'),
    Path(join)(Path(split)({'Path', Text})) =:= {'Path', normal_path(Text)}.

path_split_join(Segments) ->
    Path = ern_named:functions('ern@path'),
    Path(split)(Path(join)(Segments)) =:= Segments.

path_parent_name([<<"/">>] = Segments) ->
    Path = ern_named:functions('ern@path'),
    PathText = Path(join)(Segments),
    Path(parent)(PathText) =:= 'None' andalso Path(name)(PathText) =:= 'None';
path_parent_name([Name]) ->
    Path = ern_named:functions('ern@path'),
    PathText = Path(join)([Name]),
    Path(parent)(PathText) =:= 'None' andalso Path(name)(PathText) =:= {'Some', Name};
path_parent_name(Segments) ->
    Path = ern_named:functions('ern@path'),
    PathText = Path(join)(Segments),
    Path(parent)(PathText) =:= {'Some', Path(join)(lists:droplast(Segments))}
        andalso Path(name)(PathText) =:= {'Some', lists:last(Segments)}.

path_extension(Segments) ->
    Path = ern_named:functions('ern@path'),
    Path(extension)(Path(join)(Segments)) =:= extension_model(lists:last(Segments)).

%% The root, `.` and `..` have no name to extend and are left as they are.
path_with_extension({Segments, Extension}) ->
    Path = ern_named:functions('ern@path'),
    PathText = Path(join)(Segments),
    With = Path(withExtension)(PathText, Extension),
    Name = lists:last(Segments),
    case has_name(Name) of
        true ->
            Path(extension)(With) =:= {'Some', Extension}
                andalso Path(withoutExtension)(With) =:= Path(withoutExtension)(PathText)
                andalso Path(extension)(Path(withoutExtension)(PathText))
                        =:= extension_model(stem(Name));
        false ->
            With =:= PathText andalso Path(withoutExtension)(PathText) =:= PathText
    end.

path_joined({First, Second}) ->
    Path = ern_named:functions('ern@path'),
    Expected = case hd(Second) of
                   <<"/">> -> Path(join)(Second);
                   _ -> Path(join)(First ++ Second)
               end,
    Path('<>')(Path(join)(First), Path(join)(Second)) =:= Expected.

%% The second under the first where it is relative and each of its segments
%% names an entry, and None where it is absolute or has a `.` or `..`.
path_under({First, Second}) ->
    Path = ern_named:functions('ern@path'),
    Root = Path(join)(First),
    PathText = Path(join)(Second),
    Steps = hd(Second) =:= <<"/">>
        orelse lists:any(fun(Segment) -> lists:member(Segment, [<<".">>, <<"..">>]) end, Second),
    Expected = case Steps of
                   true -> 'None';
                   false -> {'Some', Path('<>')(Root, PathText)}
               end,
    Path(under)(Root, PathText) =:= Expected.

%% `from` undoes `under`: a path placed under a root is named from it as it
%% was, and a path named from a directory is placed under it as the first,
%% each up to `join` of `split`. The pairs asked of `from` are the draws
%% either way round and the two joined, so that some begin with the other.
path_from({First, Second}) ->
    Path = ern_named:functions('ern@path'),
    Root = Path(join)(First),
    PathText = Path(join)(Second),
    Normal = fun(Of) -> Path(join)(Path(split)(Of)) end,
    Inverse = case Path(under)(Root, PathText) of
                  {'Some', Placed} -> Path(from)(Placed, Root) =:= {'Some', Normal(PathText)};
                  'None' -> true
              end,
    Pairs = [{Root, PathText}, {PathText, Root}, {Path(join)(First ++ Second), Root}],
    Undone = fun({Whole, Directory}) ->
                     case Path(from)(Whole, Directory) of
                         {'Some', Rest} ->
                             case Path(under)(Directory, Rest) of
                                 {'Some', Back} -> Normal(Back) =:= Normal(Whole);
                                 'None' -> false
                             end;
                         'None' -> true
                     end
             end,
    Inverse andalso lists:all(Undone, Pairs).

path_text_of(Segments) ->
    Path = ern_named:functions('ern@path'),
    PathText = Path(join)(Segments),
    Path(isAbsolute)(PathText) =:= (hd(Segments) =:= <<"/">>)
        andalso Path(toString)(PathText) =:= element(2, PathText).

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
          {"toHex lower-case, fromHex either case, None for an odd count or another digit",
           fun bytes/1, fun bytes_hex/1}]).

bytes_contents({Octets, Index}) ->
    Bytes = ern_named:functions('ern@bytes'),
    List = binary_to_list(Octets),
    At = case Index >= 0 andalso Index < byte_size(Octets) of
             true -> {'Some', binary:at(Octets, Index)};
             false -> 'None'
         end,
    Bytes(size)(Octets) =:= byte_size(Octets) andalso Bytes(isEmpty)(Octets) =:= (Octets =:= <<>>)
        andalso Bytes(toList)(Octets) =:= List
        andalso Bytes(fromList)(List) =:= {'Some', Octets}
        andalso Bytes(get)(Octets, Index) =:= At.

bytes_from_list(List) ->
    Bytes = ern_named:functions('ern@bytes'),
    Expected = case lists:all(fun(X) -> X >= 0 andalso X =< 255 end, List) of
                   true -> {'Some', list_to_binary(List)};
                   false -> 'None'
               end,
    Bytes(fromList)(List) =:= Expected.

bytes_slice({Octets, Index, End}) ->
    Bytes = ern_named:functions('ern@bytes'),
    From = min(max(Index, 0), byte_size(Octets)),
    To = min(max(End, From), byte_size(Octets)),
    Bytes(slice)(Octets, Index, End) =:= binary:part(Octets, From, To - From).

%% An empty second is at 0 and last at the size.
bytes_searches({Octets, Part}) ->
    Bytes = ern_named:functions('ern@bytes'),
    Offsets = lists:seq(0, max(byte_size(Octets) - byte_size(Part), -1)),
    Found = [Offset || Offset <- Offsets, binary:part(Octets, Offset, byte_size(Part)) =:= Part],
    {First, Last} = case Part of
                        <<>> -> {{'Some', 0}, {'Some', byte_size(Octets)}};
                        _ -> {first(Found), first(lists:reverse(Found))}
                    end,
    Starts = binary:longest_common_prefix([Octets, Part]) =:= byte_size(Part),
    Ends = binary:longest_common_suffix([Octets, Part]) =:= byte_size(Part),
    Bytes(indexOf)(Octets, Part) =:= First andalso Bytes(lastIndexOf)(Octets, Part) =:= Last
        andalso Bytes(contains)(Octets, Part) =:= (First =/= 'None')
        andalso Bytes(startsWith)(Octets, Part) =:= Starts
        andalso Bytes(endsWith)(Octets, Part) =:= Ends.

bytes_split({Octets, Separator, New}) ->
    Bytes = ern_named:functions('ern@bytes'),
    {Parts, Replaced} = case Separator of
                            <<>> ->
                                {[Octets], Octets};
                            _ ->
                                Split = binary:split(Octets, Separator, [global]),
                                {Split, iolist_to_binary(lists:join(New, Split))}
                        end,
    Bytes(split)(Octets, Separator) =:= Parts
        andalso Bytes(join)(Parts, Separator) =:= Octets
        andalso Bytes(replace)(Octets, Separator, New) =:= Replaced.

bytes_repeat({First, Second, Count}) ->
    Bytes = ern_named:functions('ern@bytes'),
    Bytes(repeat)(First, Count) =:= binary:copy(First, max(Count, 0))
        andalso Bytes('<>')(First, Second) =:= <<First/binary, Second/binary>>.

bytes_hex(Octets) ->
    Bytes = ern_named:functions('ern@bytes'),
    Hex = Bytes(toHex)(Octets),
    Hex =:= binary:encode_hex(Octets, lowercase)
        andalso Bytes(fromHex)(Hex) =:= {'Some', Octets}
        andalso Bytes(fromHex)(string:uppercase(Hex)) =:= {'Some', Octets}
        andalso Bytes(fromHex)(<<Hex/binary, "A">>) =:= 'None'
        andalso Bytes(fromHex)(<<Hex/binary, "G0">>) =:= 'None'.

%%
%% OrderedSet
%%

%% report Appendix E.25: the ordered set against a sorted list without
%% repeats, in its compare's order, two elements it calls Equal one, `put`
%% and `fromList` keeping the one already there
ordered_set_laws_test_() ->
    laws([{"fromList in order, toList, size, isEmpty, minimum, maximum", fun elements/1,
           fun ordered_set_contents/1},
          {"two elements the order calls Equal are one, the first kept", fun keyed_pairs/1,
           fun ordered_set_equal/1},
          {"contains, put, remove", fun elements_and_one/1, fun ordered_set_put_remove/1},
          {"union, intersection, difference, isSubset", fun two_element_lists/1,
           fun ordered_set_operations/1},
          {"map, filter, filterMap, foldLeft, forEach, any, all, find in order",
           fun elements_and_one/1, fun ordered_set_traversals/1}]).

ordered_set_contents(List) ->
    OrderedSet = ern_named:functions('ern@ordered_set'),
    Int = ern_named:functions('ern@int'),
    Set = OrderedSet(fromList)(List, Int(compare)),
    Ordered = lists:usort(List),
    OrderedSet(toList)(Set) =:= Ordered
        andalso OrderedSet(size)(Set) =:= length(Ordered)
        andalso OrderedSet(isEmpty)(Set) =:= (Ordered =:= [])
        andalso OrderedSet(minimum)(Set) =:= first(Ordered)
        andalso OrderedSet(maximum)(Set) =:= first(lists:reverse(Ordered)).

ordered_set_equal(Pairs) ->
    OrderedSet = ern_named:functions('ern@ordered_set'),
    Int = ern_named:functions('ern@int'),
    ByKey = fun({Key, _}, {Other, _}) -> Int(compare)(Key, Other) end,
    Set = OrderedSet(fromList)(Pairs, ByKey),
    Kept = first_occurrences(fun({Key, _}) -> Key end, Pairs),
    Again = fun({Key, _}) -> OrderedSet(put)(Set, {Key, again}, ByKey) =:= Set end,
    OrderedSet(toList)(Set) =:= lists:keysort(1, Kept) andalso lists:all(Again, Kept).

ordered_set_put_remove({List, X}) ->
    OrderedSet = ern_named:functions('ern@ordered_set'),
    Int = ern_named:functions('ern@int'),
    Compare = Int(compare),
    Set = OrderedSet(fromList)(List, Compare),
    OrderedSet(contains)(Set, X, Compare) =:= lists:member(X, List)
        andalso OrderedSet(toList)(OrderedSet(put)(Set, X, Compare)) =:= lists:usort([X | List])
        andalso OrderedSet(toList)(OrderedSet(remove)(Set, X, Compare))
                =:= lists:usort(List) -- [X].

ordered_set_operations({Left, Right}) ->
    OrderedSet = ern_named:functions('ern@ordered_set'),
    Int = ern_named:functions('ern@int'),
    Compare = Int(compare),
    First = OrderedSet(fromList)(Left, Compare),
    Second = OrderedSet(fromList)(Right, Compare),
    {LeftSet, RightSet} = {lists:usort(Left), lists:usort(Right)},
    Elements = fun(Set) -> OrderedSet(toList)(Set) end,
    Elements(OrderedSet(union)(First, Second, Compare)) =:= ordsets:union(LeftSet, RightSet)
        andalso Elements(OrderedSet(intersection)(First, Second, Compare))
                =:= ordsets:intersection(LeftSet, RightSet)
        andalso Elements(OrderedSet(difference)(First, Second, Compare))
                =:= ordsets:subtract(LeftSet, RightSet)
        andalso OrderedSet(isSubset)(First, Second, Compare)
                =:= ordsets:is_subset(LeftSet, RightSet).

ordered_set_traversals({List, Pivot}) ->
    OrderedSet = ern_named:functions('ern@ordered_set'),
    Int = ern_named:functions('ern@int'),
    Compare = Int(compare),
    Set = OrderedSet(fromList)(List, Compare),
    Ordered = lists:usort(List),
    Keep = above(Pivot),
    Halved = fun(X) -> kept(Keep(X), X rem 2) end,
    OrderedSet(toList)(OrderedSet(map)(Set, fun(X) -> -X end, Compare))
        =:= lists:usort([-X || X <- Ordered])
        andalso OrderedSet(toList)(OrderedSet(filter)(Set, Keep))
                =:= lists:filter(Keep, Ordered)
        andalso OrderedSet(toList)(OrderedSet(filterMap)(Set, Halved, Compare))
                =:= lists:usort([X rem 2 || X <- Ordered, Keep(X)])
        andalso OrderedSet(foldLeft)(Set, [], fun(Acc, X) -> [X | Acc] end)
                =:= lists:reverse(Ordered)
        andalso met(fun(Visit) -> OrderedSet(forEach)(Set, Visit) end) =:= Ordered
        andalso OrderedSet(any)(Set, Keep) =:= lists:any(Keep, Ordered)
        andalso OrderedSet(all)(Set, Keep) =:= lists:all(Keep, Ordered)
        andalso OrderedSet(find)(Set, Keep) =:= first(lists:filter(Keep, Ordered)).

%%
%% OrderedMap
%%

%% report Appendix E.26: the ordered map against a sorted list of pairs, a
%% later pair winning in `fromList`, `put` replacing the value, the entries
%% met in the keys' order
ordered_map_laws_test_() ->
    laws([{"fromList: a later pair wins, toList, keys, values, minimum and maximum in order",
           fun entries/1, fun ordered_map_contents/1},
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
ordered_map_held_key({Pairs, Given, Value}) ->
    OrderedMap = ern_named:functions('ern@ordered_map'),
    Int = ern_named:functions('ern@int'),
    ByKey = fun({Left, _}, {Right, _}) -> Int(compare)(Left, Right) end,
    Map = OrderedMap(fromList)(Pairs, ByKey),
    Model = held_model(Pairs),
    Put = OrderedMap(put)(Map, Given, Value, ByKey),
    Updated = OrderedMap(update)(Map, Given, fun(_) -> Value end, ByKey),
    Other = OrderedMap(fromList)([{Given, Value}], ByKey),
    Merged = OrderedMap(merge)(Map, Other, ByKey),
    MergedWith = OrderedMap(mergeWith)(Map, Other, fun(_, _, Second) -> Second end, ByKey),
    Expected = held_model(Pairs ++ [{Given, Value}]),
    OrderedMap(toList)(Map) =:= Model
        andalso OrderedMap(toList)(Put) =:= Expected
        andalso OrderedMap(toList)(Updated) =:= Expected
        andalso OrderedMap(toList)(Merged) =:= Expected
        andalso OrderedMap(toList)(MergedWith) =:= Expected.

%% The entries in order of Key, each with the first key of its Key and the
%% last value.
held_model(Pairs) ->
    Firsts = lists:foldl(fun({{Key, _} = Tagged, _}, Acc) ->
                             maps:update_with(Key, fun(Held) -> Held end, Tagged, Acc)
                         end, #{}, Pairs),
    Lasts = maps:from_list([{Key, Value} || {{Key, _}, Value} <- Pairs]),
    [{maps:get(Key, Firsts), Value} || {Key, Value} <- lists:sort(maps:to_list(Lasts))].

ordered_map_contents(Pairs) ->
    OrderedMap = ern_named:functions('ern@ordered_map'),
    Int = ern_named:functions('ern@int'),
    Map = OrderedMap(fromList)(Pairs, Int(compare)),
    Expected = entries_model(Pairs),
    OrderedMap(toList)(Map) =:= Expected
        andalso OrderedMap(keys)(Map) =:= [Key || {Key, _} <- Expected]
        andalso OrderedMap(values)(Map) =:= [Value || {_, Value} <- Expected]
        andalso OrderedMap(size)(Map) =:= length(Expected)
        andalso OrderedMap(isEmpty)(Map) =:= (Expected =:= [])
        andalso OrderedMap(minimum)(Map) =:= first(Expected)
        andalso OrderedMap(maximum)(Map) =:= first(lists:reverse(Expected)).

ordered_map_put({Pairs, Key, Value}) ->
    OrderedMap = ern_named:functions('ern@ordered_map'),
    Int = ern_named:functions('ern@int'),
    Compare = Int(compare),
    Map = OrderedMap(fromList)(Pairs, Compare),
    Old = case lists:keyfind(Key, 1, entries_model(Pairs)) of
              {Key, Held} -> {'Some', Held};
              false -> 'None'
          end,
    Put = OrderedMap(put)(Map, Key, Value, Compare),
    OrderedMap(get)(Put, Key, Compare) =:= {'Some', Value}
        andalso OrderedMap(toList)(Put) =:= entries_model(Pairs ++ [{Key, Value}])
        andalso OrderedMap(toList)(OrderedMap(remove)(Map, Key, Compare))
                =:= lists:keydelete(Key, 1, entries_model(Pairs))
        andalso OrderedMap(contains)(Map, Key, Compare) =:= (Old =/= 'None')
        andalso OrderedMap(toList)(OrderedMap(update)(Map, Key, fun count/1, Compare))
                =:= entries_model(Pairs ++ [{Key, count(Old)}]).

ordered_map_merge({Left, Right}) ->
    OrderedMap = ern_named:functions('ern@ordered_map'),
    Int = ern_named:functions('ern@int'),
    Compare = Int(compare),
    First = OrderedMap(fromList)(Left, Compare),
    Second = OrderedMap(fromList)(Right, Compare),
    {Mine, Theirs} = {maps:from_list(Left), maps:from_list(Right)},
    Shared = maps:intersect_with(fun combined/3, Mine, Theirs),
    Merged = lists:sort(maps:to_list(maps:merge(maps:merge(Mine, Theirs), Shared))),
    OrderedMap(toList)(OrderedMap(merge)(First, Second, Compare))
        =:= entries_model(Left ++ Right)
        andalso OrderedMap(toList)(OrderedMap(mergeWith)(First, Second, fun combined/3,
                                                             Compare))
                =:= Merged.

ordered_map_traversals({Pairs, Pivot}) ->
    OrderedMap = ern_named:functions('ern@ordered_map'),
    Int = ern_named:functions('ern@int'),
    Map = OrderedMap(fromList)(Pairs, Int(compare)),
    Expected = entries_model(Pairs),
    Keep = fun(Key, _) -> Key > Pivot end,
    Kept = [{Key, Value} || {Key, Value} <- Expected, Key > Pivot],
    Negated = fun(Key, Value) -> kept(Keep(Key, Value), -Value) end,
    Visits = fun(Visit) ->
                     OrderedMap(forEach)(Map, fun(Key, Value) -> Visit({Key, Value}) end)
             end,
    OrderedMap(toList)(OrderedMap(map)(Map, fun(Key, Value) -> Key + Value end))
        =:= [{Key, Key + Value} || {Key, Value} <- Expected]
        andalso OrderedMap(toList)(OrderedMap(filter)(Map, Keep)) =:= Kept
        andalso OrderedMap(toList)(OrderedMap(filterMap)(Map, Negated))
                =:= [{Key, -Value} || {Key, Value} <- Kept]
        andalso OrderedMap(foldLeft)(Map, [], fun(Acc, Key, _) -> [Key | Acc] end)
                =:= lists:reverse([Key || {Key, _} <- Expected])
        andalso met(Visits) =:= Expected
        andalso OrderedMap(any)(Map, Keep) =:= (Kept =/= [])
        andalso OrderedMap(all)(Map, Keep) =:= (length(Kept) =:= length(Expected))
        andalso OrderedMap(find)(Map, Keep) =:= first(Kept).

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
    ern_rt:init_modules(['ern@list', 'ern@string', 'ern@map', 'ern@set', 'ern@ordered_set',
                         'ern@ordered_map', 'ern@bytes', 'ern@int', 'ern@float', 'ern@char',
                         'ern@optional', 'ern@either', 'ern@path']),
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
map_and_key(Size) ->
    Map = ern_named:functions('ern@map'),
    {Map(fromList)(entries(Size)), small(Size) rem 7, small(Size)}.
two_maps(Size) ->
    Map = ern_named:functions('ern@map'),
    {Map(fromList)(entries(Size)), Map(fromList)(entries(Size))}.
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
    Float = ern_named:functions('ern@float'),
    Digits = fun() -> [pick("0123456789") || _ <- lists:seq(1, rand:uniform(3))] end,
    Exponent = fun() -> [pick(["e", "E"]), pick(["", "-", "+"]), Digits()] end,
    Forms = [[Digits(), ".", Digits()], [Digits(), ".", Digits(), Exponent()],
             [Digits(), Exponent()], [Digits()], [".", Digits()], [Digits(), "."],
             [Digits(), "_", Digits(), ".", Digits()], ["1.0e400"], ["1.0e-400"],
             [Float(toString)(finite(Size))]],
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
    ern_helpers:taken(Tag).

%% The byte offsets at which the string's graphemes begin, and its end.
boundaries(Whole) ->
    String = ern_named:functions('ern@string'),
    Step = fun(Grapheme, Offset) -> {Offset, Offset + byte_size(Grapheme)} end,
    {Offsets, _} = lists:mapfoldl(Step, 0, String(graphemes)(Whole)),
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
    Char = ern_named:functions('ern@char'),
    [First | _] = unicode:characters_to_list(Grapheme),
    Char(isSpace)(First).

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
    String = ern_named:functions('ern@string'),
    Split = fun(Grapheme, [Word | Rest]) ->
                    case is_space_grapheme(Grapheme) of
                        true -> [[], Word | Rest];
                        false -> [[Grapheme | Word] | Rest]
                    end
            end,
    Words = lists:foldr(Split, [[]], String(graphemes)(Whole)),
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
