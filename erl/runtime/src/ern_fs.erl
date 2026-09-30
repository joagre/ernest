%% Report §8.2, Appendix E.17: the process behind Fs's reference. It answers
%% each of Fs's messages with Either(Io.Error, a), doing the work in a process of its own so
%% that one slow file does not hold up the rest. The work that opens a file
%% goes around the host's file server, which does one request at a time:
%% raw, as the host calls it. A Path is {'Path', Bin} and an Entry's fields
%% are in canonical order (report §3.5): kind, mtime, path, size.
-module(ern_fs).

-export([loop/0]).

-include_lib("kernel/include/file.hrl").

-spec loop() -> no_return().
loop() ->
    receive
        Msg ->
            erlang:spawn(fun() -> serve(Msg) end),
            loop()
    end.

%% Report Appendix E.17: a path that holds U+0000 names no file, and the
%% request is answered so before any work.
serve(Msg) ->
    Fields = tuple_to_list(Msg),
    case [B || {'Path', B} <- Fields, binary:match(B, <<0>>) =/= nomatch] of
        [] ->
            handle(Msg);
        _ ->
            [Reply] = [R || R <- Fields, is_reference(R)],
            ern_rt:answer(Reply, {'Left', {'Other', <<"a path holds U+0000">>}})
    end.

handle({'ReadFile', Path, Reply}) ->
    Name = text(Path),
    answer(Reply, regular(Name, fun() -> file:read_file(Name, [raw]) end));
%% Report Appendix E.17: a part of a file, read where it lies, without
%% holding the rest; fewer bytes at its end, and none past it.
handle({'ReadRange', Count, Offset, _Path, Reply}) when Count < 0; Offset < 0 ->
    ern_rt:answer(Reply, {'Left', {'Other', <<"a negative offset or count">>}});
handle({'ReadRange', Count, Offset, Path, Reply}) ->
    Name = text(Path),
    answer(Reply, regular(Name, fun() -> range(Name, Offset, Count) end));
handle({'WriteFile', Bytes, Path, Reply}) ->
    Name = text(Path),
    answer(Reply, regular_or_none(Name, fun() -> unit(file:write_file(Name, Bytes, [raw])) end));
handle({'AppendFile', Bytes, Path, Reply}) ->
    Name = text(Path),
    answer(Reply, regular_or_none(Name, fun() ->
                                            unit(file:write_file(Name, Bytes, [raw, append]))
                                        end));
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
%% Report Appendix E.17: its owner's alone, the group's and others' bits of
%% its mode cleared and the owner's kept, as `chmod go-rwx` does.
handle({'MakePrivate', Path, Reply}) ->
    Name = text(Path),
    answer(Reply, case file:read_file_info(Name, [raw]) of
                      {ok, #file_info{mode = Mode}} ->
                          unit(file:write_file_info(Name, #file_info{mode = Mode band bnot 8#077},
                                                    [raw]));
                      Error ->
                          Error
                  end);
%% Report Appendix E.17: a link is removed, not what it leads to.
handle({'Remove', Path, Reply}) ->
    Name = text(Path),
    answer(Reply, unit(case file:read_link_info(Name, [raw]) of
                           {ok, #file_info{type = directory}} -> file:del_dir(Name);
                           _ -> file:delete(Name, [raw])
                       end));
handle({'Rename', From, Reply, To}) ->
    answer(Reply, unit(file:rename(text(From), text(To))));
%% Report Appendix E.17: the link at the path, holding the target as it is
%% written, which may name nothing.
handle({'MakeLink', Path, Reply, Target}) ->
    answer(Reply, unit(file:make_symlink(text(Target), text(Path))));
%% Report Appendix E.17: None for a path that names anything but a link.
handle({'ReadLink', Path, Reply}) ->
    answer(Reply, case file:read_link_all(text(Path)) of
                      {ok, Target} -> utf8_target(name_bytes(Target));
                      {error, einval} -> {ok, 'None'};
                      Error -> Error
                  end);
%% Report Appendix E.17: a new file, claimed by its name at once, or none:
%% one whose write fails is removed.
handle({'Create', Bytes, Path, Reply}) ->
    Name = text(Path),
    answer(Reply, case file:open(Name, [write, exclusive, raw, binary]) of
                      {ok, File} ->
                          Written = file:write(File, Bytes),
                          Closed = file:close(File),
                          case {Written, Closed} of
                              {ok, ok} -> {ok, 'Unit'};
                              {ok, Error} -> gone(Name, Error);
                              {Error, _} -> gone(Name, Error)
                          end;
                      Error ->
                          Error
                  end);
%% Report Appendix E.17: the modification time, kept to the second, as the
%% host sets it; the access time is left as it was.
handle({'SetModified', Mtime, Path, Reply}) ->
    Name = text(Path),
    answer(Reply, case file:read_file_info(Name, [raw, {time, posix}]) of
                      {ok, #file_info{atime = Atime}} ->
                          Info = #file_info{atime = Atime,
                                            mtime = floor_div(Mtime, 1000)},
                          unit(file:write_file_info(Name, Info, [raw, {time, posix}]));
                      Error ->
                          Error
                  end);
handle({'Copy', From, Reply, To}) ->
    {Source, Target} = {text(From), text(To)},
    answer(Reply, regular(Source, fun() ->
                                      regular_or_none(Target, fun() -> copy(Source, Target) end)
                                  end)).

range(Name, Offset, Count) ->
    case file:open(Name, [read, raw, binary]) of
        {ok, File} ->
            %% the host makes room for the count before it reads, so the
            %% count asked for is what the file holds from the offset
            Read = case file:position(File, eof) of
                       {ok, Size} when Offset >= Size -> eof;
                       {ok, Size} -> file:pread(File, Offset, min(Count, Size - Offset));
                       Failed -> Failed
                   end,
            ok = file:close(File),
            case Read of
                {ok, Bytes} -> {ok, Bytes};
                eof -> {ok, <<>>};
                Error -> Error
            end;
        Error ->
            Error
    end.

copy(Source, Target) ->
    case file:copy({Source, [raw]}, {Target, [raw]}) of
        {ok, _} -> {ok, 'Unit'};
        Error -> Error
    end.

%% Report Appendix E.17: read, write, append and copy work on regular
%% files, since a named pipe waits for a writer that may never come and a
%% device may never end; a path that names nothing may be written.
regular(Name, Then) ->
    case file:read_file_info(Name, [raw]) of
        {ok, #file_info{type = regular}} -> Then();
        {ok, _} -> {error, not_regular};
        Error -> Error
    end.

regular_or_none(Name, Then) ->
    case file:read_file_info(Name, [raw]) of
        {error, enoent} -> Then();
        _ -> regular(Name, Then)
    end.

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

%% Report Appendix E.17: each entry described as it is, a link as a link,
%% and one gone by the time it is described left out.
entries(Dir, Names) ->
    lists:foldl(fun(_, {error, _} = Error) ->
                        Error;
                   (Name, {ok, Acc}) ->
                        Path = filename:join(Dir, Name),
                        case entry(Path, file:read_link_info(Path, [raw, {time, posix}])) of
                            {ok, Entry} -> {ok, [Entry | Acc]};
                            {error, enoent} -> {ok, Acc};
                            Error -> Error
                        end
                end, {ok, []}, lists:reverse(Names)).

%% Report Appendix E.17: Fs.Entry(kind, mtime, path, size), mtime in
%% milliseconds; stat describes what the path leads to.
entry(Name) ->
    entry(Name, file:read_file_info(Name, [raw, {time, posix}])).

entry(Name, {ok, #file_info{type = Type, mtime = Mtime, size = Size}}) ->
    {ok, {'Entry', kind(Type), Mtime * 1000, {'Path', Name}, Size}};
entry(_, Error) ->
    Error.

%% Report Appendix E.17: Fs.Kind.
kind(regular) -> 'File';
kind(directory) -> 'Directory';
kind(symlink) -> 'Link';
kind(_) -> 'Other'.

%% Report Appendix E.17: a link's target is a Path, whose text is UTF-8.
utf8_target(Bytes) ->
    case unicode:characters_to_binary(Bytes, utf8, utf8) of
        Text when is_binary(Text) -> {ok, {'Some', {'Path', Text}}};
        _ -> {error, target_not_utf8}
    end.

%% A file created whose write failed is removed, so that none is left.
gone(Name, Error) ->
    _ = file:delete(Name, [raw]),
    Error.

%% Seconds from milliseconds, rounded down, a time before the epoch too.
floor_div(A, B) when A >= 0 -> A div B;
floor_div(A, B) -> -((-A + B - 1) div B).

%% report Appendix E.1: Io.Error = NotFound | Denied | Refused | Closed | Timeout
%% | Other(String)
io_error(enoent) -> 'NotFound';
io_error(eacces) -> 'Denied';
io_error(eperm) -> 'Denied';
io_error(econnrefused) -> 'Refused';
io_error(not_regular) -> {'Other', <<"not a regular file">>};
io_error(eexist) -> {'Other', <<"exists">>};
io_error(target_not_utf8) -> {'Other', <<"the target is not UTF-8">>};
io_error(Reason) -> ern_io:other(Reason, fun file:format_error/1).
