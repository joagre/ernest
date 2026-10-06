%% The primitives of Path (report Appendix E.14, E.0 rule 1): what only the
%% host knows of its path syntax, the separator and whether a path starts
%% at a root, by `filename`, and a path's parts between its separators or
%% its dots, read by code points as the runtime reads a path. The rest of
%% Path is Ernest over them and String.
-module(ern_path).

-export([separator/0, parts/2, last_part/2, is_absolute/1]).

%% The separator `filename:join/2` writes, `/`, or `\` on Windows.
-spec separator() -> binary().
separator() ->
    case os:type() of
        {win32, _} -> <<"\\">>;
        _ -> <<"/">>
    end.

%% Appendix E.14: the text's parts between each occurrence of the mark,
%% empty ones kept, by `binary:split/3`. It reads bytes, and UTF-8 never
%% holds one code point's bytes inside another's, so each match begins and
%% ends where code points do, and each part is UTF-8: a separator or a dot
%% is one though a combining mark follows it, as the runtime reads a path.
%% Its options are atoms, which Ernest makes only through `Erl.atom` at
%% each call, as `ern_list:zip/2` says.
-spec parts(binary(), binary()) -> [binary()].
parts(Text, Mark) -> binary:split(Text, pattern(Mark), [global]).

%% The mark's pattern as `binary:compile_pattern/1` makes it, made at its
%% first use and kept for the runtime's life: compiling it at each call
%% cost more than the split of a path, 140 ns of 330. Path asks for two
%% marks alone, the separator and the dot, so two are kept, and none goes.
pattern(Mark) ->
    case persistent_term:get({?MODULE, Mark}, none) of
        none ->
            Pattern = binary:compile_pattern(Mark),
            persistent_term:put({?MODULE, Mark}, Pattern),
            Pattern;
        Pattern ->
            Pattern
    end.

%% Appendix E.14: the text after the last occurrence of the mark, a
%% separator of one byte, found from the text's end, so that what it costs
%% is that part's length and not the path's; the whole text where the mark
%% is not there. The byte is ASCII, which UTF-8 holds in no other code
%% point, so the part is UTF-8.
-spec last_part(binary(), binary()) -> binary().
last_part(Text, <<Mark>>) -> last_part(Text, Mark, byte_size(Text) - 1).

last_part(Text, _, -1) ->
    Text;
last_part(Text, Mark, Offset) ->
    case binary:at(Text, Offset) of
        Mark -> binary:part(Text, Offset + 1, byte_size(Text) - Offset - 1);
        _ -> last_part(Text, Mark, Offset - 1)
    end.

%% A Path is Path(String), {'Path', Text} (report §8.4); filename:pathtype/1
%% answers absolute for a path that starts at a root.
-spec is_absolute({'Path', binary()}) -> boolean().
is_absolute({'Path', Path}) -> filename:pathtype(Path) =:= absolute.
