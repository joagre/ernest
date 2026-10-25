%% The runtime's records that more than one module reads: a process's row in
%% the table of the processes it started or adopted, `ern_processes`, which
%% ern_rt keeps and the tests read (report §6.9, §8.7, §11.2); and a fault
%% as the runtime holds it from where it is met to its report (§7.3, §11.2,
%% Appendix E.21).

-ifndef(ERN_RT_HRL).
-define(ERN_RT_HRL, true).

-record(process_row, {pid, site, spawn_order, root, peer = none, expected = false,
                      fault = none}).
%% pid: the process, the table's key; site: its spawn site (§6.9), which
%% an initializer's evaluation names (ern_rt:initializing/1); spawn_order:
%% its place in the order of spawns; root: the process at the head of its
%% spawn chain (ern_rt:started_by/1), or the mark a Code.load called in
%% its chain evaluates under (ern_rt:rooting/0, Appendix E.28); peer: the
%% node of the peer whose spawn started it, which its fault's line names
%% (§11.2), or none; expected: whether its fault is expected, a process
%% `Test.faults` started, which no job reports and no subscriber is told
%% of (ern_rt:expected/1, Appendix E.24); fault: the #fault{} it ended
%% with, written as it ends (ern_rt:ended_with/2), which the reaper reports
%% beside the host's term of its end (§8.4); `carried` for a compute's
%% process whose fault went to its caller, which no one here is told of
%% (§8.7); or none.

-record(fault, {cause, trace = none, callee = none, peer = none, time = none}).
%% cause: the text of §7.4, which a Down carries (§6.9); trace: the fault's
%% trace (§7.3, Appendix E.21); callee: the site of the callee whose fault
%% a callForever carried to its caller (§6.6), or none; peer: the name of
%% the peer whose compute carried it to its caller (§8.7), or none; time:
%% the moment it was met, in milliseconds since the epoch as Clock.now
%% counts them (Appendix E.15). A fault thrown with its trace or its time
%% none takes the stack and the moment where it is met (ern_rt:met/3).

-endif.
