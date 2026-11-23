%% Report §11.2, §12.5: a line of the toolchain's own on the job's own
%% standard error, a node's or a fault's: the device it goes to while no
%% launch's standard error takes it, and whether it begins with its time.
%% The command line sets both as the job starts (ern_cli), beneath the
%% nodes and the shell, which write such lines.
-module(ern_job_line).

-export([set_error_device/1, error_line/1, set_stamped/1, is_stamped/0, stamp/1, stamp/2]).

%% Report §12.5, §11.2: the job's own standard error, the device the job
%% writes its own lines on, put as the job starts.
-spec set_error_device(io:device()) -> ok.
set_error_device(ErrorDevice) ->
    persistent_term:put({?MODULE, error_device}, ErrorDevice).

%% Report §12.5, §11.2: a line of the toolchain's own written on the job's
%% own standard error, where no launch's standard error process takes it
%% (ern_rt:say/2): before a node's first launch, between two and after its
%% last.
-spec error_line(binary()) -> ok.
error_line(Line) ->
    io:put_chars(persistent_term:get({?MODULE, error_device}, standard_error), Line).

%% Report §11.2, §12.5: whether a line on standard error begins with its
%% time, which the job decides once as it starts (§11.8).
-spec set_stamped(boolean()) -> ok.
set_stamped(Stamped) ->
    persistent_term:put({?MODULE, stamped}, Stamped).

%% Report §11.2, §12.5: whether a line on standard error begins with its
%% time: where the program writes to the process's own standard error, and
%% that was neither a terminal nor a journal as the job started (§11.8).
-spec is_stamped() -> boolean().
is_stamped() ->
    persistent_term:get({?MODULE, stamped}, false).

%% Report §11.2, §12.5: what a line on standard error begins with, a fault's
%% or a node's: its time, in UTC as RFC 3339 writes it, where the lines are
%% stamped, and nothing where they are not; the time now, or a fault's,
%% the moment it was met (Appendix E.21).
-spec stamp(boolean()) -> iolist().
stamp(Stamped) ->
    stamp(Stamped, erlang:system_time(millisecond)).

-spec stamp(boolean(), integer()) -> iolist().
stamp(true, Time) ->
    [calendar:system_time_to_rfc3339(Time, [{unit, millisecond}, {offset, "Z"}]), " "];
stamp(false, _) ->
    [].
