%% Report §8.2, Appendix E.17: the process behind Fs's reference. It answers
%% each of Fs's messages with Either(Io.Error, a), doing the work in a process of its own so
%% that one slow file does not hold up the rest. The work that opens a file
%% goes around the host's file server, which does one request at a time:
%% raw, as the host calls it. A Path is {'Path', Bytes} and an Entry's fields
%% are in declared order (report §3.5): path, modified, size, kind, mode and
%% user, as entry/2 builds them.
-module(ern_fs).

-export([loop/0, is_utf8/1, name_bytes/1, private/1]).

-include_lib("kernel/include/file.hrl").

%% Report §8.6: each receive that can wait, by its kind (docs/code_style.md).
-receives({own_process, [loop/0]}).

-spec loop() -> no_return().
loop() ->
    receive
        Message ->
            try erlang:spawn(fun() -> serve(Message) end)
            catch error:system_limit -> answered_limited(Message)
            end,
            loop()
    end.

%% Report §7.4, §12.5: a request whose process the host's full table of
%% processes keeps from being made answers `Left(Other("error:system_limit"))`,
%% this process living on.
answered_limited(Message) ->
    ern_rt:answer(reply_of(Message), {'Left', ern_io:limited()}).

%% The reply a request carries among its fields.
reply_of(Message) ->
    [Reply] = [Field || Field <- tuple_to_list(Message), ern_rt:is_reply(Field)],
    Reply.

%% Report Appendix E.17: a path that holds U+0000 names no file, and the
%% request is answered so before any work.
serve(Message) ->
    Fields = tuple_to_list(Message),
    case [Bytes || {'Path', Bytes} <- Fields, binary:match(Bytes, <<0>>) =/= nomatch] of
        [] -> handle(Message);
        _ -> ern_rt:answer(reply_of(Message), {'Left', 'Invalid'})
    end.

handle({'Read', Path, Reply}) ->
    Text = text(Path),
    answer(Reply, regular(Text, fun(_) -> file:read_file(Text, [raw]) end));
%% Report Appendix E.17: a part of a file, read where it lies, without
%% holding the rest; fewer bytes at its end, and none past it. Report §7.4:
%% an offset or a count below 0 is none.
handle({'ReadRange', Path, Offset, Count, Reply}) ->
    Text = text(Path),
    answer(Reply, regular(Text, fun(_) -> range(Text, max(Offset, 0), max(Count, 0)) end));
handle({'Write', Path, Bytes, Reply}) ->
    Text = text(Path),
    answer(Reply, regular_or_none(Text, fun(_) -> unit(file:write_file(Text, Bytes, [raw])) end));
handle({'Append', Path, Bytes, Reply}) ->
    Text = text(Path),
    answer(Reply, appendable(Text, fun(_) ->
                                       unit(file:write_file(Text, Bytes, [raw, append]))
                                   end));
handle({'ListEntries', Path, Reply}) ->
    Directory = text(Path),
    answer(Reply, case file:list_dir_all(Directory) of
                      {ok, Names} ->
                          named_entries(Directory, lists:sort(lists:map(fun name_bytes/1, Names)));
                      {error, enotdir} -> not_directory(Directory);
                      Error -> Error
                  end);
handle({'Stat', Path, Reply}) ->
    answer(Reply, entry(text(Path)));
handle({'MakeDir', Path, Reply}) ->
    answer(Reply, unit(filelib:ensure_path(text(Path))));
%% Report Appendix E.17: the permission bits as the host writes them; a
%% mode beyond them, or with the bit 0o1000, which file:change_mode/2 drops
%% and answers ok, is an argument the host cannot take whole.
handle({'SetMode', _Path, Mode, Reply}) when Mode < 0; Mode > 8#7777; Mode band 8#1000 =/= 0 ->
    ern_rt:answer(Reply, {'Left', 'Invalid'});
handle({'SetMode', Path, Mode, Reply}) ->
    answer(Reply, unit(file:change_mode(text(Path), Mode)));
%% Report Appendix E.17: a link is removed, not what it leads to.
handle({'Remove', Path, Reply}) ->
    Text = text(Path),
    answer(Reply, unit(case file:read_link_info(Text, [raw]) of
                           {ok, #file_info{type = directory}} -> file:del_dir(Text);
                           _ -> file:delete(Text, [raw])
                       end));
handle({'Rename', Source, Destination, Reply}) ->
    answer(Reply, unit(file:rename(text(Source), text(Destination))));
%% Report Appendix E.17: the link at the path, holding the target as it is
%% written, which may name nothing.
handle({'MakeSymlink', Path, Target, Reply}) ->
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
    Text = text(Path),
    answer(Reply, case file:open(Text, [write, exclusive, raw, binary]) of
                      {ok, File} ->
                          Written = file:write(File, Bytes),
                          Closed = file:close(File),
                          case {Written, Closed} of
                              {ok, ok} -> {ok, 'Unit'};
                              {ok, Error} -> gone(Text, Error);
                              {Error, _} -> gone(Text, Error)
                          end;
                      Error ->
                          Error
                  end);
%% Report Appendix E.17: a directory of a new name in the parent, made as
%% makeDir makes one and so under the program's mask; its mode is set, and
%% it is seen to hold nothing, before its path is answered (temp_dir/1).
handle({'MakeTempDir', Parent, Reply}) ->
    answer(Reply, temp_dir(text(Parent)));
%% Report Appendix E.17: the modification time, kept to the second, as the
%% host sets it; the access time is left as it was.
handle({'SetModified', Path, ModifiedMs, Reply}) ->
    Text = text(Path),
    answer(Reply, case file:read_file_info(Text, [raw, {time, posix}]) of
                      {ok, #file_info{atime = Atime}} ->
                          Info = #file_info{atime = Atime,
                                            mtime = floor_div(ModifiedMs, 1000)},
                          unit(file:write_file_info(Text, Info, [raw, {time, posix}]));
                      Error ->
                          Error
                  end);
handle({'Copy', SourcePath, DestinationPath, Reply}) ->
    Source = text(SourcePath),
    Destination = text(DestinationPath),
    answer(Reply, regular(Source, fun(Read) ->
                                      regular_or_none(Destination,
                                                      fun(Found) ->
                                                          copy(Source, Read, Destination, Found)
                                                      end)
                                  end)).

range(Text, Offset, Count) ->
    case file:open(Text, [read, raw, binary]) of
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

%% Report Appendix E.17: the source copied into the destination between two
%% handles of this process's, as every file here is opened, the source
%% first, so that one that cannot be read leaves the destination as it was.
%% A destination the stat found missing is made with the source's
%% permission bits less the program's mask, as cp(1) makes it, set before a
%% byte is written; one it found keeps its own.
%%
%% The destination is not emptied before the copy: it is opened for
%% reading and writing, which cuts nothing (written_over/1), copied into
%% from its start, and cut where the copy ended (cut/2). A file copied onto
%% itself, by one path or by two, has each byte written over itself, and
%% keeps its content. A copy that fails midway leaves the source's bytes up
%% to where it failed and the destination's old bytes past them, but for a
%% destination that may not be read, whose open cut it.
copy(Source, #file_info{mode = Mode}, Destination, Found) ->
    case file:open(Source, [read, raw, binary]) of
        {ok, From} ->
            Copied = case written_over(Destination) of
                         {ok, To} ->
                             Written = case made_mode(Destination, Mode, Found) of
                                           ok -> cut(file:copy(From, To), To);
                                           Refused -> Refused
                                       end,
                             closed(Written, file:close(To));
                         Error ->
                             Error
                     end,
            ok = file:close(From),
            Copied;
        Error ->
            Error
    end.

%% The destination opened to be written over from its start. The host
%% refuses an open for reading and writing of a file that may not be read
%% and of one that may not be written alike; the open for writing alone
%% then decides, which cuts a file that may be written and refuses one
%% that may not, cutting nothing. A destination that may not be read is no
%% file of the source's, which was just opened for reading, so the cut
%% loses none of the source.
written_over(Destination) ->
    case file:open(Destination, [read, write, raw, binary]) of
        {error, eacces} -> file:open(Destination, [write, raw, binary]);
        Opened -> Opened
    end.

%% A copy's answer, the destination cut where the copy ended, at the
%% position the copy left its handle at, where the copy was whole.
cut({ok, _} = Copied, To) ->
    case file:truncate(To) of
        ok -> Copied;
        Error -> Error
    end;
cut(Error, _) ->
    Error.

made_mode(Destination, Mode, none) ->
    file:change_mode(Destination, Mode band 8#777 band bnot ern_os:umask());
made_mode(_, _, #file_info{}) ->
    ok.

%% A write's answer, and the close's where the write was whole, since the
%% host may report a write's failure at the close.
closed({ok, _}, ok) -> {ok, 'Unit'};
closed({ok, _}, Error) -> Error;
closed(Error, _) -> Error.

%% Report Appendix E.17: read, write and copy work on regular files, since
%% a named pipe waits for a writer that may never come and a device may
%% never end; a path that names nothing may be written.
regular(Text, Then) ->
    of_kind(Text, [regular], Then).

regular_or_none(Text, Then) ->
    of_kind(Text, [regular, none], Then).

%% Report Appendix E.17: append writes a device as well, a terminal among
%% them, since a write to it ends; a named pipe's open waits for a reader
%% that may never come.
appendable(Text, Then) ->
    of_kind(Text, [regular, device, none], Then).

%% Report Appendix E.17: the work Then does, given the path's stat, where
%% the path names a file of one of the Kinds, `none` for a path that names
%% nothing, which Then is given as `none`. One stat decides, and the work
%% takes what it answered, so that no second answer of the host's can
%% disagree with the first.
of_kind(Text, Kinds, Then) ->
    case file:read_file_info(Text, [raw]) of
        {ok, #file_info{type = Type} = Info} ->
            case lists:member(Type, Kinds) of
                true -> Then(Info);
                false -> {error, not_regular}
            end;
        {error, enoent} = Missing ->
            case lists:member(none, Kinds) of
                true -> Then(none);
                false -> Missing
            end;
        Error ->
            Error
    end.

%% Report Appendix E.17: the host says "not a directory" of a path that
%% names a regular file and of one that leads through it; the first names
%% something list does not work on, the second leads to nothing.
not_directory(Directory) ->
    case file:read_file_info(Directory, [raw]) of
        {ok, _} -> {error, not_regular};
        _ -> {error, enotdir}
    end.

%% Every answer is Right(v) or Left(Io.Error).
answer(Reply, {ok, Value}) ->
    ern_rt:answer(Reply, {'Right', Value});
answer(Reply, {error, Error}) ->
    ern_rt:answer(Reply, {'Left', io_error(Error)}).

unit(ok) -> {ok, 'Unit'};
unit(Other) -> Other.

text({'Path', Bytes}) -> Bytes.

%% Report Appendix E.17, §12.1: a name that is not UTF-8 is no Path, so the
%% list answers NotUtf8 with the first such, in the order of their bytes.
named_entries(Directory, Names) ->
    case [Bytes || Bytes <- Names, not is_utf8(Bytes)] of
        [] -> entries(Directory, Names);
        [First | _] -> {error, {not_utf8, First}}
    end.

%% Whether the bytes are UTF-8, as a Path's and a String's are.
-spec is_utf8(binary()) -> boolean().
is_utf8(Bytes) ->
    is_binary(unicode:characters_to_binary(Bytes, utf8, utf8)).

%% A name the host gives as its bytes. The host gives a name decoded where
%% its names are UTF-8, and one that is not as its bytes; where they are
%% not, it gives every name's bytes.
-spec name_bytes(file:filename_all()) -> binary().
name_bytes(Name) when is_binary(Name) -> Name;
name_bytes(Name) ->
    case file:native_name_encoding() of
        utf8 -> unicode:characters_to_binary(Name);
        latin1 -> list_to_binary(Name)
    end.

%% Report Appendix E.17: each entry described as it is, a link as a link,
%% and one gone by the time it is described left out.
entries(Directory, Names) ->
    lists:foldl(fun(_, {error, _} = Error) ->
                        Error;
                   (EntryName, {ok, Acc}) ->
                        EntryText = filename:join(Directory, EntryName),
                        Info = file:read_link_info(EntryText, [raw, {time, posix}]),
                        case entry(EntryText, Info) of
                            {ok, Entry} -> {ok, [Entry | Acc]};
                            {error, enoent} -> {ok, Acc};
                            Error -> Error
                        end
                end, {ok, []}, lists:reverse(Names)).

%% Report Appendix E.17: Fs.Entry(path, modified, size, kind, mode, user),
%% modified in milliseconds and mode the permission bits alone, as setMode
%% takes them, where the host's mode holds the file's type too; stat
%% describes what the path leads to.
entry(Text) ->
    entry(Text, file:read_file_info(Text, [raw, {time, posix}])).

entry(Text, {ok, #file_info{type = Type, mtime = Seconds, size = Size, mode = Mode, uid = User}}) ->
    {ok, {'Entry', {'Path', Text}, Seconds * 1000, Size, kind(Type), Mode band 8#7777, User}};
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

%% Report Appendix E.17: `ern-` and sixteen hexadecimal digits drawn at
%% random, drawn again where an entry has the name, and drawn again where
%% the directory made holds something once its mode is set (private/1); a
%% directory whose mode cannot be set, or that cannot be read, is removed,
%% so that none is left.
temp_dir(Parent) ->
    Name = <<"ern-", (binary:encode_hex(rand:bytes(8), lowercase))/binary>>,
    Directory = filename:join(Parent, Name),
    case file:make_dir(Directory) of
        ok ->
            case private(Directory) of
                ok ->
                    {ok, {'Path', Directory}};
                held ->
                    temp_dir(Parent);
                Error ->
                    _ = file:del_dir(Directory),
                    Error
            end;
        {error, eexist} ->
            temp_dir(Parent);
        Error ->
            Error
    end.

%% Report Appendix E.17: Directory's mode set to 0o700, its owner's alone,
%% and `ok` where it holds nothing then, as ern_build:make_private_dir/1
%% checks; `held` where another put an entry in it while its mode let them,
%% a link a later write would follow among them, the entry left where it
%% stands; or the host's reason where its mode could not be set or it could
%% not be read.
-spec private(binary()) -> ok | held | {error, file:posix()}.
private(Directory) ->
    case file:change_mode(Directory, 8#700) of
        ok ->
            case file:list_dir_all(Directory) of
                {ok, []} -> ok;
                {ok, _} -> held;
                Error -> Error
            end;
        Error ->
            Error
    end.

%% A file created whose write failed is removed, so that none is left.
gone(Text, Error) ->
    _ = file:delete(Text, [raw]),
    Error.

%% Seconds from milliseconds, rounded down, a time before the epoch too.
floor_div(Dividend, Divisor) when Dividend >= 0 -> Dividend div Divisor;
floor_div(Dividend, Divisor) -> -((-Dividend + Divisor - 1) div Divisor).

%% Report Appendix E.1: Io.Error for what the file module answers, the
%% runtime's own words for a file that is not regular and a name that is
%% not UTF-8 among them.
io_error(not_regular) -> 'NotAFile';
io_error({not_utf8, Bytes}) -> {'NotUtf8', Bytes};
io_error(Error) -> ern_io:host_error(Error, fun file:format_error/1).
