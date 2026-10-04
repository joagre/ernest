%% Report Appendix E.1: a value as Ernest writes it, by the descriptor of
%% its type (ern_boundary); where the type is a variable, the descriptor is
%% `any` and the value is read by its runtime representation (§8.4).
%%
%% Report §11.2: the shell prints to a depth and a length and shows what it
%% cut as `...`; `Io.debug` prints the value whole, which is show/2, the
%% same printer with neither bound.
-module(ern_show).

-export([show/2, show/4, controls/2]).

%% The depth left, and how many elements of a list, map, or set are
%% printed; `unbounded` is neither.
-record(limits, {depth = unbounded, length = unbounded}).

-spec show(ern_descriptor:descriptor(), term()) -> binary().
show(Descriptor, Value) ->
    show(Descriptor, Value, unbounded, unbounded).

-spec show(ern_descriptor:descriptor(), term(), non_neg_integer() | unbounded,
           non_neg_integer() | unbounded) -> binary().
show(Descriptor, Value, Depth, Length) ->
    Limits = #limits{depth = Depth, length = Length},
    unicode:characters_to_binary(by_type(Descriptor, Value, #{}, Limits)).

%% Report §11.2: below the depth a value is `...`, whatever it is. A value
%% written without nesting, a number or a string, is not below it: depth
%% counts the brackets a reader would have to open, and a depth of 0 is
%% where by_type/4 and represented/2 stop at the first bracket.
deeper(#limits{depth = unbounded} = Limits) -> Limits;
deeper(#limits{depth = Depth} = Limits) -> Limits#limits{depth = Depth - 1}.

%% The items the length allows, and whether any were left.
limited(Items, #limits{length = unbounded}) -> {Items, false};
limited(Items, #limits{length = Length}) ->
    case length(Items) > Length of
        true -> {lists:sublist(Items, Length), true};
        false -> {Items, false}
    end.

%% The items each shown, with `...` last when something was cut.
parts(Items, Limits, Show) ->
    {Kept, Cut} = limited(Items, Limits),
    [Show(Item) || Item <- Kept] ++ ["..." || Cut].

by_type(any, Value, _, Limits) -> represented(Value, Limits);
%% report Appendix E.1: a foreign type's value is the host's own term
by_type(foreign, _, _, _) -> "<foreign>";
by_type(int, Value, _, _) -> integer_to_list(Value);
by_type(float, Value, _, _) -> float_text(Value);
by_type(bool, Value, _, _) -> atom_to_list(Value);
by_type(char, Value, _, _) -> [$', char_body(Value), $'];
by_type(string, Value, _, _) -> string(Value);
by_type(bytes, Value, _, Limits) -> bytes(Value, Limits);
by_type({address, _, _}, Value, _, _) -> address(Value);
by_type(process, Value, _, _) -> ["<process ", number(Value), ">"];
by_type({reply, _, _}, _, _, _) -> "<reply>";
by_type({function, _, _, _, _, _}, _, _, _) -> "<function>";
by_type({abstract, _}, _, _, _) -> "<abstract>";
by_type({mu, Id, Descriptor}, Value, Bound, Limits) ->
    by_type(Descriptor, Value, Bound#{Id => Descriptor}, Limits);
by_type({ref, Id}, Value, Bound, Limits) -> by_type(maps:get(Id, Bound), Value, Bound, Limits);
by_type({con, _}, Value, _, _) when is_atom(Value) -> atom_to_list(Value);
by_type(_, _, _, #limits{depth = 0}) -> "...";
by_type({list, ElementDescriptor}, Value, Bound, Limits) ->
    Show = fun(Item) -> by_type(ElementDescriptor, Item, Bound, deeper(Limits)) end,
    ["[", join(parts(Value, Limits, Show)), "]"];
by_type({tuple, ElementDescriptors}, Value, Bound, Limits) ->
    Shown = [by_type(ElementDescriptor, Item, Bound, deeper(Limits))
             || {ElementDescriptor, Item} <- lists:zip(ElementDescriptors, tuple_to_list(Value))],
    ["#(", join(Shown), ")"];
by_type({map, KeyDescriptor, ValueDescriptor}, Value, Bound, Limits) ->
    Pair = fun({Key, Item}) ->
               ["#(", by_type(KeyDescriptor, Key, Bound, deeper(Limits)), ", ",
                by_type(ValueDescriptor, Item, Bound, deeper(Limits)), ")"]
           end,
    ["Map.fromList([", join(parts(lists:sort(maps:to_list(Value)), Limits, Pair)), "])"];
by_type({set, ElementDescriptor}, {set, Members}, Bound, Limits) ->
    Show = fun(Item) -> by_type(ElementDescriptor, Item, Bound, deeper(Limits)) end,
    ["Set.fromList([", join(parts(lists:sort(maps:keys(Members)), Limits, Show)), "])"];
by_type({con, Constructors}, Value, Bound, Limits) when is_tuple(Value) ->
    [Tag | Fields] = tuple_to_list(Value),
    Parts = case lists:keyfind(Tag, 1, Constructors) of
                {_, Descriptors} ->
                    [by_type(FieldDescriptor, Item, Bound, deeper(Limits))
                     || {FieldDescriptor, Item} <- lists:zip(Descriptors, Fields)];
                {_, Descriptors, Names} ->
                    [[atom_to_list(Name), " = ",
                      by_type(FieldDescriptor, Item, Bound, deeper(Limits))]
                     || {Name, FieldDescriptor, Item} <- lists:zip3(Names, Descriptors, Fields)]
            end,
    [atom_to_list(Tag), "(", join(Parts), ")"].

%% Report Appendix E.1: an address by the process behind it, which grants
%% nothing, and a process by the number the host gives it.
address(Address) ->
    ["<address ", number(ern_rt:process_of(Address)), ">"].

number(Pid) ->
    [_, Number, _] = string:split(string:trim(pid_to_list(Pid), both, "<>"), ".", all),
    Number.

%% By the runtime's representation alone.
represented(Value, _) when is_integer(Value) -> integer_to_list(Value);
represented(Value, _) when is_float(Value) -> float_text(Value);
represented(Value, _) when is_atom(Value) -> atom_to_list(Value);
represented(Value, Limits) when is_binary(Value) ->
    case unicode:characters_to_list(Value) of
        Chars when is_list(Chars) -> string(Value);
        _ -> bytes(Value, Limits)
    end;
represented(Pid, _) when is_pid(Pid) -> address(Pid);
%% a Reply and an address foreign code gave (ern_rt)
represented({foreign_reply, Reply, _, _}, _) when is_reference(Reply) -> "<reply>";
represented({foreign, Pid, _, _} = Address, _) when is_pid(Pid) -> address(Address);
represented(Function, _) when is_function(Function) -> "<function>";
represented(Value, #limits{depth = 0}) when is_list(Value); is_tuple(Value); is_map(Value) ->
    "...";
represented(List, Limits) when is_list(List) ->
    %% a foreign value may be an improper list, which Ernest has no form for
    case proper(List) of
        true ->
            Show = fun(Item) -> represented(Item, deeper(Limits)) end,
            ["[", join(parts(List, Limits, Show)), "]"];
        false ->
            "<foreign>"
    end;
represented({set, Members}, Limits) when is_map(Members) ->
    Show = fun(Item) -> represented(Item, deeper(Limits)) end,
    ["Set.fromList([", join(parts(lists:sort(maps:keys(Members)), Limits, Show)), "])"];
%% an address seen through `via` is the runtime's own term (report §6.5),
%% and is written as every address is, by the process behind it
represented({via, Function, _} = Address, _) when is_function(Function, 1) -> address(Address);
represented(Tuple, Limits) when is_tuple(Tuple), tuple_size(Tuple) > 0,
                                is_atom(element(1, Tuple)) ->
    %% report §8.4: a constructor's atom is its source spelling, capitalized;
    %% any other first atom, `true` among them, begins a tuple
    [Tag | Fields] = tuple_to_list(Tuple),
    case atom_to_list(Tag) of
        [First | _] when First >= $A, First =< $Z ->
            [atom_to_list(Tag), "(",
             join([represented(Field, deeper(Limits)) || Field <- Fields]), ")"];
        _ ->
            ["#(", join([represented(Item, deeper(Limits)) || Item <- tuple_to_list(Tuple)]), ")"]
    end;
represented(Tuple, Limits) when is_tuple(Tuple) ->
    ["#(", join([represented(Item, deeper(Limits)) || Item <- tuple_to_list(Tuple)]), ")"];
represented(Map, Limits) when is_map(Map) ->
    Pair = fun({Key, Item}) ->
               ["#(", represented(Key, deeper(Limits)), ", ",
                represented(Item, deeper(Limits)), ")"]
           end,
    ["Map.fromList([", join(parts(lists:sort(maps:to_list(Map)), Limits, Pair)), "])"];
represented(_, _) -> "<foreign>".

proper([]) -> true;
proper([_ | Tail]) -> proper(Tail);
proper(_) -> false.

float_text(Float) -> ern_float:text(Float).

string(Text) -> [$", [escape(Char, $") || Char <- unicode:characters_to_list(Text)], $"].

bytes(Bytes, Limits) ->
    Shown = parts([Byte || <<Byte>> <= Bytes], Limits, fun integer_to_list/1),
    ["<<", join(Shown), ">>"].

char_body(Char) -> escape(Char, $').

%% Report §2.5: the escapes a literal needs, the quote being the literal's own.
escape(Quote, Quote) -> [$\\, Quote];
escape($\\, _) -> "\\\\";
escape($\n, _) -> "\\n";
escape($\t, _) -> "\\t";
escape($\r, _) -> "\\r";
escape(Char, _) when Char < 16#20; Char >= 16#7F, Char =< 16#9F ->
    ["\\u{", integer_to_list(Char, 16), "}"];
escape(Char, _) -> [Char].

%% Report §11.2: a text the toolchain writes on a line of its own, a fault's
%% cause, with each control character as the escape a literal writes for
%% it, so that no control character of a program's reaches the terminal as
%% itself. With `lines`, a line feed stays, for the host's stack; with
%% `line`, it is `\n`, so that a fault is one line.
-spec controls(unicode:unicode_binary(), line | lines) -> unicode:unicode_binary().
controls(Text, Keep) ->
    unicode:characters_to_binary([control(Char, Keep) || Char <- unicode:characters_to_list(Text)]).

control($\n, lines) -> $\n;
control(Char, _) when Char < 16#20; Char >= 16#7F, Char =< 16#9F -> escape(Char, none);
control(Char, _) -> Char.

join(Parts) -> lists:join(", ", Parts).
