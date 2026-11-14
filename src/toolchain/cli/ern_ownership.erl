%% Report §11.2: the ownership test, which a node applies to its
%% configuration directory and the files of it that it reads (§12.5). The
%% shell's startup files are tested the same way in its own Ernest, and a
%% node's ernest.pid, at which no link is followed, by the runtime's
%% helper alone.
-module(ern_ownership).

-export([failure/3]).

-include_lib("kernel/include/file.hrl").

%% The most links the host follows in one path, Linux's.
-define(MOST_LINKS, 40).

%% Report §11.2: how Path fails the test, Info being what it reaches, a
%% link followed, and User the user it is tested for: `passes`;
%% `another_users`, where what it reaches, or the directory that holds
%% what a link followed from it reaches, is neither User's own nor the
%% superuser's; or `every_user_may_write`, where every user may write one
%% of them. Each is judged by its owner before its mode, and what the path
%% reaches before its links, in the order they are followed.
-spec failure(file:filename_all(), #file_info{}, non_neg_integer()) ->
          passes | another_users | every_user_may_write.
failure(Path, Info, User) ->
    case judged(Info, User) of
        passes -> chain_failure(filename:join([Path]), User, 0);
        Failure -> Failure
    end.

%% Report §11.2: what one path reaches judged by its owner, then by the
%% bit of its mode for the users who are neither its owner nor of its
%% group. The bits for its group are not read.
judged(Info, User) ->
    case lists:member(Info#file_info.uid, [User, 0]) of
        false -> another_users;
        true when Info#file_info.mode band 8#002 =/= 0 -> every_user_may_write;
        true -> passes
    end.

%% Report §11.2: each link followed from the path in turn, its target read
%% from the directory the link stands in, as the host reads it, and the
%% directory that holds what the target reaches judged as what it is, links
%% followed; nothing above that directory is tested. A path that is no
%% link, or no longer there, ends the walk.
%%
%% The path was given without its trailing separators, at which the host
%% would follow the link and not read it. The host followed the chain to
%% reach what the path reaches, and follows no more than its limit of links
%% in one path, so a walk past the limit meets a chain changed since, which
%% the read after the test meets as well.
chain_failure(Path, User, Followed) when Followed < ?MOST_LINKS ->
    case file:read_link_all(Path) of
        {ok, Text} ->
            Target = filename:join(filename:dirname(Path), Text),
            case held_failure(Target, User) of
                passes -> chain_failure(Target, User, Followed + 1);
                Failure -> Failure
            end;
        {error, _} ->
            passes
    end;
chain_failure(_Path, _User, _Followed) ->
    passes.

%% Report §11.2: the directory that holds what a target reaches judged,
%% which is not tested where it is not there.
held_failure(Target, User) ->
    case file:read_file_info(holding_directory(Target)) of
        {ok, Info} -> judged(Info, User);
        {error, _} -> passes
    end.

%% Report §11.2: the directory that holds what a target reaches: the one
%% its last name stands in, or, for a target that ends in `.` or `..` or is
%% the root, the directory above the one it reaches, which the host finds
%% by its `..`, the root's being the root.
holding_directory(Target) ->
    case lists:member(filename:basename(Target), ["", ".", "..", <<>>, <<".">>, <<"..">>]) of
        true -> filename:join(Target, "..");
        false -> filename:dirname(Target)
    end.
