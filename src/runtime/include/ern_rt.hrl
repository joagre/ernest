%% The runtime's records that more than one module reads: a process's row in
%% the table of the processes it started or adopted, `ern_processes`, which
%% ern_rt keeps and the tests read (report §6.9, §8.7, §11.2); a fault as
%% the runtime holds it from where it is met to its report (§7.3, §11.2,
%% Appendix E.21); and a function a unit of this node holds, as the code
%% table answers it (§8.7, ern_code:spawnable/1, ern_code:linkable/1).

-ifndef(ERN_RT_HRL).
-define(ERN_RT_HRL, true).

-record(process_row, {pid, site, spawn_order, root, peer = none, expected = false,
                      fault = none, own = none}).
%% pid: the process, the table's key; site: its spawn site (§6.9), which
%% an initializer's evaluation names (ern_rt:initializing/1); spawn_order:
%% its place in the order of spawns; root: the process at the head of its
%% spawn chain (ern_rt:started_by/1); peer: the node of the peer whose
%% spawn started it, which its fault's line names (§11.2), or none;
%% expected: whether its fault is expected, which no job reports and no
%% subscriber is told of: {asked, Cause} for a process `Test.faults`
%% started, asking for the fault of Cause, whose fault of another cause
%% gives its trace to the case's line (ern_rt:expected/2, Appendix E.24),
%% true for a load's evaluator, whose fault the load answers
%% (ern_rt:evaluate/2, Appendix E.28), or false; fault: the #fault{} it ended
%% with, written as it ends (ern_rt:ended_with/2), which the reaper reports
%% beside the host's term of its end (§12.2); `carried` for a compute's
%% process whose fault went to its caller, which no one here is told of
%% (§8.7); or none; own: whose own it is, `session` for a process of the
%% shell's own, the session, its reader, its screen or its local half,
%% which the session marks, `input` for an input's process, which marks
%% itself, `evaluator` for a load's evaluator, the runtime's own,
%% marked as it is spawned, which Process.status knows not, or none; and
%% Process.live() leaves out each (ern_rt:own/1, ern_rt:evaluate/2,
%% Appendix E.21, E.28, §11.2).

-record(fault, {cause, trace = none, callee = none, peer = none, time = none}).
%% cause: the cause's text (§7.3), which a Down carries (§6.9); trace: the fault's
%% trace (§7.3, Appendix E.21); callee: the site of the callee whose fault
%% a callForever carried to its caller (§6.6), or none; peer: the name of
%% the peer whose compute, or whose process a callForever called, carried
%% it to its caller (§6.6, §8.7), or none; time:
%% the moment it was met, in milliseconds since the epoch as Clock.now
%% counts them (Appendix E.15). A fault thrown with its trace or its time
%% none takes the stack and the moment where it is met (ern_rt:met/3).

-record(held_function, {unit, function, arity, reach}).
%% unit: the unit that holds it; function: its function there, named by
%% its number (§11.1); arity: how many values it takes, a lambda's the
%% values it captured; reach: the bindings and the foreign declarations it
%% names, {[{QualifiedName, Hash}], [QualifiedName]} (ern_code:reach()).

-endif.
