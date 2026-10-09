%% A chunk of a compiled module as a term, report §11.1. A `.erc` may come
%% from anywhere, and the host's decoder makes an atom of every name it
%% meets, for ever, and a function or a process of what says it is one. So
%% a chunk is read as bytes first: it holds data alone, the terms the
%% compiler writes, and no more names new to the host than half of what the
%% host has room left for, so that no one chunk can be what fills it. A
%% compressed chunk, as the canonical forms are written (§11.1), is
%% inflated first and its bytes read the same way.
-module(ern_chunk).

-export([term/1]).

%% Deflate's own greatest ratio of inflated to compressed bytes: a match
%% copies at most 258 bytes and is coded in no fewer than two bits, so no
%% stream inflates past 1032 times its size. The bound is the format's, not
%% a number chosen here.
-define(DEFLATE_RATIO, 1032).

-spec term(binary()) -> {ok, term()} | error.
term(<<131, 80, Size:32, Compressed/binary>>) ->
    %% the host's compressed term: its inflated size, then the zlib stream;
    %% a size past deflate's ratio is a lie, refused before anything is
    %% inflated, and an inflated term is never inflated again
    case Size =< ?DEFLATE_RATIO * byte_size(Compressed) of
        true -> inflated(Size, Compressed);
        false -> error
    end;
term(<<131, Body/binary>>) ->
    plain(Body);
term(_) ->
    error.

%% What deflate inflates is bounded by its ratio whatever the size claims,
%% so the stream is inflated whole and must be the size it claimed.
inflated(Size, Compressed) ->
    try zlib:uncompress(Compressed) of
        Body when byte_size(Body) =:= Size -> plain(Body);
        _ -> error
    catch
        error:_ -> error
    end.

plain(Body) ->
    try names(Body, #{}) of
        {Names, <<>>} ->
            case fits(Names) of
                true -> {ok, binary_to_term(<<131, Body/binary>>)};
                false -> error
            end;
        _ ->
            error
    catch
        error:function_clause -> error
    end.

%% The names in the term that begins Bytes, and the bytes after it. Each
%% clause is a tag of the host's external term format; a tag the compiler
%% does not write, a function's, a process's, a compressed term's, matches
%% none, and neither does a term cut short.
names(<<97, _, Rest/binary>>, Names) -> {Names, Rest};
names(<<98, _:32, Rest/binary>>, Names) -> {Names, Rest};
names(<<70, _:64, Rest/binary>>, Names) -> {Names, Rest};
names(<<110, Size, _Sign, _:Size/binary, Rest/binary>>, Names) -> {Names, Rest};
names(<<111, Size:32, _Sign, _:Size/binary, Rest/binary>>, Names) -> {Names, Rest};
names(<<106, Rest/binary>>, Names) -> {Names, Rest};
names(<<107, Size:16, _:Size/binary, Rest/binary>>, Names) -> {Names, Rest};
names(<<109, Size:32, _:Size/binary, Rest/binary>>, Names) -> {Names, Rest};
names(<<119, Size, Name:Size/binary, Rest/binary>>, Names) -> {Names#{Name => utf8}, Rest};
names(<<118, Size:16, Name:Size/binary, Rest/binary>>, Names) -> {Names#{Name => utf8}, Rest};
names(<<115, Size, Name:Size/binary, Rest/binary>>, Names) -> {Names#{Name => latin1}, Rest};
names(<<100, Size:16, Name:Size/binary, Rest/binary>>, Names) -> {Names#{Name => latin1}, Rest};
names(<<104, Arity, Rest/binary>>, Names) -> elements(Arity, Rest, Names);
names(<<105, Arity:32, Rest/binary>>, Names) -> elements(Arity, Rest, Names);
names(<<108, Length:32, Rest/binary>>, Names) -> elements(Length + 1, Rest, Names);
names(<<116, Arity:32, Rest/binary>>, Names) -> elements(2 * Arity, Rest, Names).

elements(0, Rest, Names) ->
    {Names, Rest};
elements(Count, Bytes, Names) ->
    {Names1, Rest} = names(Bytes, Names),
    elements(Count - 1, Rest, Names1).

%% Whether the names the host has not met are few enough for it: at most
%% half of what it has room left for. A chunk with no more names than that
%% fits whatever the host has met; one with more has its new names
%% counted, up to the one too many.
fits(Names) ->
    Room = (erlang:system_info(atom_limit) - erlang:system_info(atom_count)) div 2,
    map_size(Names) =< Room orelse has_room(maps:to_list(Names), Room).

has_room([], _Room) ->
    true;
has_room([{Name, Encoding} | Rest], Room) ->
    try binary_to_existing_atom(Name, Encoding) of
        _ -> has_room(Rest, Room)
    catch
        error:badarg -> Room > 0 andalso has_room(Rest, Room - 1)
    end.
