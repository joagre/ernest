%% Report §8.2, Appendix E.17: the process behind Fs's reference. It answers
%% each of Fs's messages with Either(Io.Error, a), doing the work in a process of its own so
%% that one slow file does not hold up the rest. The work that opens a file
%% goes around the host's file server, which does one request at a time:
%% raw, as the host calls it. A Path is {'Path', Bytes} and an Entry's fields
%% are in declared order (report §3.5): path, mtime, size, kind.
-module(ern_fs).

-export([loop/0]).

-include_lib("kernel/include/file.hrl").

-spec loop() -> no_return().
loop() ->
    receive
        Message ->
            erlang:spawn(fun() -> serve(Message) end),
            loop()
    end.

%% Report Appendix E.17: a path that holds U+0000 names no file, and the
%% request is answered so before any work.
serve(Message) ->
    Fields = tuple_to_list(Message),
    case [Bytes || {'Path', Bytes} <- Fields, binary:match(Bytes, <<0>>) =/= nomatch] of
        [] ->
            handle(Message);
        _ ->
            [Reply] = [Field || Field <- Fields, is_reference(Field)],
            ern_rt:answer(Reply, {'Left', 'Invalid'})
    end.

handle({'Read', Path, Reply}) ->
    Name = text(Path),
    answer(Reply, regular(Name, fun() -> file:read_file(Name, [raw]) end));
%% Report Appendix E.17: a part of a file, read where it lies, without
%% holding the rest; fewer bytes at its end, and none past it. Report §7.4:
%% an offset or a count below 0 is none.
handle({'ReadRange', Path, Offset, Count, Reply}) ->
    Name = text(Path),
    answer(Reply, regular(Name, fun() -> range(Name, max(Offset, 0), max(Count, 0)) end));
handle({'Write', Path, Bytes, Reply}) ->
    Name = text(Path),
    answer(Reply, regular_or_none(Name, fun() -> unit(file:write_file(Name, Bytes, [raw])) end));
handle({'Append', Path, Bytes, Reply}) ->
    Name = text(Path),
    answer(Reply, regular_or_none(Name, fun() ->
                                            unit(file:write_file(Name, Bytes, [raw, append]))
                                        end));
handle({'List', Path, Reply}) ->
    Dir = text(Path),
    answer(Reply, case file:list_dir_all(Dir) of
                      {ok, Names} ->
                          named_entries(Dir, lists:sort(lists:map(fun name_bytes/1, Names)));
                      Error -> Error
                  end);
handle({'Stat', Path, Reply}) ->
    answer(Reply, entry(text(Path)));
handle({'MakeDir', Path, Reply}) ->
    answer(Reply, unit(filelib:ensure_path(text(Path))));
%% Report Appendix E.17: the permission bits as the host writes them; a
%% mode beyond them is an argument the host cannot take.
handle({'SetMode', _Path, Mode, Reply}) when Mode < 0; Mode > 8#7777 ->
    ern_rt:answer(Reply, {'Left', 'Invalid'});
handle({'SetMode', Path, Mode, Reply}) ->
    answer(Reply, unit(file:change_mode(text(Path), Mode)));
%% Report Appendix E.17: a link is removed, not what it leads to.
handle({'Remove', Path, Reply}) ->
    Name = text(Path),
    answer(Reply, unit(case file:read_link_info(Name, [raw]) of
                           {ok, #file_info{type = directory}} -> file:del_dir(Name);
                           _ -> file:delete(Name, [raw])
                       end));
%% Report Appendix E.17: a tree removed by the runtime's helper, which walks
%% a directory by the directories it has opened and never by a path, so
%% that a directory replaced by a link while it runs leads it nowhere else;
%% Erlang's file module has no operation relative to an open directory.
handle({'RemoveAll', Path, Reply}) ->
    case removed_by_helper(text(Path)) of
        {fault, Cause} -> ern_rt:refuse(Reply, Cause);
        Answer -> ern_rt:answer(Reply, Answer)
    end;
handle({'Rename', Source, Destination, Reply}) ->
    answer(Reply, unit(file:rename(text(Source), text(Destination))));
%% Report Appendix E.17: the link at the path, holding the target as it is
%% written, which may name nothing.
handle({'MakeLink', Path, Target, Reply}) ->
    answer(Reply, unit(file:make_symlink(text(Target), text(Path))));
%% Report Appendix E.17: a second name for a regular file. The target's
%% own entry is read, no link followed, since the host links a link's
%% name and not the file it leads to.
handle({'MakeHardLink', Path, Target, Reply}) ->
    Existing = text(Target),
    answer(Reply, case file:read_link_info(Existing, [raw]) of
                      {ok, #file_info{type = regular}} ->
                          unit(file:make_link(Existing, text(Path)));
                      {ok, _} ->
                          {error, not_regular};
                      Error ->
                          Error
                  end);
%% Report Appendix E.17: None for a path that names anything but a link.
handle({'ReadLink', Path, Reply}) ->
    answer(Reply, case file:read_link_all(text(Path)) of
                      {ok, Target} -> utf8_target(name_bytes(Target));
                      {error, einval} -> {ok, 'None'};
                      Error -> Error
                  end);
%% Report Appendix E.17: a new file, claimed by its name at once, or none:
%% one whose write fails is removed.
handle({'MakeFile', Path, Bytes, Reply}) ->
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
handle({'SetModified', Path, Mtime, Reply}) ->
    Name = text(Path),
    answer(Reply, case file:read_file_info(Name, [raw, {time, posix}]) of
                      {ok, #file_info{atime = Atime}} ->
                          Info = #file_info{atime = Atime,
                                            mtime = floor_div(Mtime, 1000)},
                          unit(file:write_file_info(Name, Info, [raw, {time, posix}]));
                      Error ->
                          Error
                  end);
handle({'Copy', SourcePath, DestinationPath, Reply}) ->
    Source = text(SourcePath),
    Destination = text(DestinationPath),
    answer(Reply, regular(Source, fun() ->
                                      regular_or_none(Destination,
                                                      fun() -> copy(Source, Destination) end)
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

copy(Source, Destination) ->
    case file:copy({Source, [raw]}, {Destination, [raw]}) of
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
answer(Reply, {error, Error}) ->
    ern_rt:answer(Reply, {'Left', io_error(Error)}).

unit(ok) -> {ok, 'Unit'};
unit(Other) -> Other.

text({'Path', Bytes}) -> Bytes.

%% Report Appendix E.17, §8.2: a name that is not UTF-8 is no Path, so the
%% list answers NotUtf8 with the first such, in the order of their bytes.
named_entries(Dir, Names) ->
    case [Bytes || Bytes <- Names, not is_utf8(Bytes)] of
        [] -> entries(Dir, Names);
        [First | _] -> {error, {not_utf8, First}}
    end.

is_utf8(Bytes) ->
    is_binary(unicode:characters_to_binary(Bytes, utf8, utf8)).

%% The host gives a name decoded where its names are UTF-8, and one that is
%% not as its bytes; where they are not, it gives every name's bytes.
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

%% Report Appendix E.17: Fs.Entry(path, mtime, size, kind), mtime in
%% milliseconds; stat describes what the path leads to.
entry(Name) ->
    entry(Name, file:read_file_info(Name, [raw, {time, posix}])).

entry(Name, {ok, #file_info{type = Type, mtime = Mtime, size = Size}}) ->
    {ok, {'Entry', {'Path', Name}, Mtime * 1000, Size, kind(Type)}};
entry(_, Error) ->
    Error.

%% Report Appendix E.17: Fs.Kind.
kind(regular) -> 'File';
kind(directory) -> 'Directory';
kind(symlink) -> 'Link';
kind(_) -> 'Other'.

%% Report Appendix E.17: a link's target is a Path, whose text is UTF-8.
utf8_target(Bytes) ->
    case is_utf8(Bytes) of
        true -> {ok, {'Some', {'Path', Bytes}}};
        false -> {error, {not_utf8, Bytes}}
    end.

%% A file created whose write failed is removed, so that none is left.
gone(Name, Error) ->
    _ = file:delete(Name, [raw]),
    Error.

%% Seconds from milliseconds, rounded down, a time before the epoch too.
floor_div(Dividend, Divisor) when Dividend >= 0 -> Dividend div Divisor;
floor_div(Dividend, Divisor) -> -((-Dividend + Divisor - 1) div Divisor).

%% The helper's job `remove` run on the path: Right(Unit) once it is gone,
%% and the runtime's own failure, which faults the caller, where the helper
%% fails (report §7.4, Appendix E.17).
removed_by_helper(Name) ->
    try erlang:open_port({spawn_executable, ern_os:helper()},
                         [{args, ["remove"]}, {packet, 4}, binary, exit_status]) of
        Helper ->
            erlang:port_command(Helper, <<"p", Name/binary>>),
            receive
                {Helper, {data, <<"d">>}} -> {'Right', 'Unit'};
                {Helper, {data, <<"f", ErrorName/binary>>}} -> {'Left', removal_error(ErrorName)};
                {Helper, {exit_status, _}} -> ern_os:helper_failed()
            end
    catch
        error:_ -> ern_os:helper_failed()
    end.

%% The helper's name for an error, described as the file module's errors
%% are, and its host's words where it has no name.
removal_error(Name) ->
    try binary_to_existing_atom(Name) of
        Error -> io_error(Error)
    catch
        error:badarg -> {'Other', Name}
    end.

io_error(enoent) -> 'NotFound';
io_error(eacces) -> 'Denied';
io_error(eperm) -> 'Denied';
io_error(econnrefused) -> 'Refused';
%% Report Appendix E.1: Io.Error's constructors for what the host names
io_error(not_regular) -> 'NotAFile';
io_error(eexist) -> 'Exists';
io_error({not_utf8, Bytes}) -> {'NotUtf8', Bytes};
io_error(Error) -> ern_io:other(Error, fun file:format_error/1).
