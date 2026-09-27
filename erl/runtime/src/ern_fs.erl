%% Report §8.2, Appendix E.17: the process behind Fs's reference. It answers
%% each of Fs's messages with Either(Io.Error, a), doing the work in a process of its own so
%% that one slow file does not hold up the rest. A Path is {'Path', Bin}
%% and an Entry's fields are in canonical order (report §3.5): isDir,
%% mtime, path, size.
-module(ern_fs).

-export([loop/0]).

-include_lib("kernel/include/file.hrl").

-spec loop() -> no_return().
loop() ->
    receive
        Msg ->
            erlang:spawn(fun() -> guarded(Msg) end),
            loop()
    end.

%% Report Appendix E.17: a path that holds U+0000 names no file, and the
%% request is answered so before any work.
guarded(Msg) ->
    Fields = tuple_to_list(Msg),
    case [B || {'Path', B} <- Fields, binary:match(B, <<0>>) =/= nomatch] of
        [] ->
            handle(Msg);
        _ ->
            [Reply] = [R || R <- Fields, is_reference(R)],
            ern_rt:answer(Reply, {'Left', {'Other', <<"a path holds U+0000">>}})
    end.

handle({'ReadFile', Path, Reply}) ->
    answer(Reply, file:read_file(text(Path)));
handle({'WriteFile', Bytes, Path, Reply}) ->
    answer(Reply, unit(file:write_file(text(Path), Bytes)));
handle({'AppendFile', Bytes, Path, Reply}) ->
    answer(Reply, unit(file:write_file(text(Path), Bytes, [append])));
handle({'ListDir', Path, Reply}) ->
    Dir = text(Path),
    answer(Reply, case file:list_dir_all(Dir) of
                      {ok, Names} -> entries(Dir, lists:sort(utf8_names(Names)));
                      Error -> Error
                  end);
handle({'Stat', Path, Reply}) ->
    answer(Reply, entry(text(Path)));
handle({'MakeDir', Path, Reply}) ->
    answer(Reply, unit(filelib:ensure_path(text(Path))));
handle({'Remove', Path, Reply}) ->
    Name = text(Path),
    answer(Reply, unit(case filelib:is_dir(Name) of
                           true -> file:del_dir(Name);
                           false -> file:delete(Name)
                       end));
handle({'Rename', From, Reply, To}) ->
    answer(Reply, unit(file:rename(text(From), text(To))));
handle({'Copy', From, Reply, To}) ->
    answer(Reply, case file:copy(text(From), text(To)) of
                      {ok, _} -> {ok, 'Unit'};
                      Error -> Error
                  end).

%% Every answer is Right(v) or Left(Io.Error).
answer(Reply, {ok, Value}) ->
    ern_rt:answer(Reply, {'Right', Value});
answer(Reply, {error, Reason}) ->
    ern_rt:answer(Reply, {'Left', io_error(Reason)}).

unit(ok) -> {ok, 'Unit'};
unit(Other) -> Other.

text({'Path', Bin}) -> Bin.

%% Report Appendix E.17: a name that is not UTF-8 is left out. The host
%% gives a name decoded where its names are UTF-8, and one that is not as
%% its bytes; where they are not, it gives every name's bytes.
utf8_names(Names) ->
    [Bytes || Bytes <- lists:map(fun name_bytes/1, Names),
              is_binary(unicode:characters_to_binary(Bytes, utf8, utf8))].

name_bytes(Name) when is_binary(Name) -> Name;
name_bytes(Name) ->
    case file:native_name_encoding() of
        utf8 -> unicode:characters_to_binary(Name);
        latin1 -> list_to_binary(Name)
    end.

entries(Dir, Names) ->
    lists:foldl(fun(_, {error, _} = Error) ->
                        Error;
                   (Name, {ok, Acc}) ->
                        case entry(filename:join(Dir, Name)) of
                            {ok, Entry} -> {ok, [Entry | Acc]};
                            Error -> Error
                        end
                end, {ok, []}, lists:reverse(Names)).

%% report Appendix E.17: Fs.Entry(isDir, mtime, path, size), mtime in milliseconds
entry(Name) ->
    case file:read_file_info(Name, [{time, posix}]) of
        {ok, #file_info{type = Type, mtime = Mtime, size = Size}} ->
            {ok, {'Entry', Type =:= directory, Mtime * 1000, {'Path', Name}, Size}};
        Error ->
            Error
    end.

%% report Appendix E.1: Io.Error = NotFound | Denied | Refused | Closed | Timeout
%% | Other(String)
io_error(enoent) -> 'NotFound';
io_error(eacces) -> 'Denied';
io_error(eperm) -> 'Denied';
io_error(econnrefused) -> 'Refused';
io_error(Reason) -> {'Other', unicode:characters_to_binary(io_lib:format("~p", [Reason]))}.
