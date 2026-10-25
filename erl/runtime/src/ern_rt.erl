%% The Ernest runtime, report sections 6, 7, 8, and 10, for one node. What
%% generated code calls, and the runner.
%%
%% Values follow the ABI of report §8.4: Unit is 'Unit', a nullary constructor
%% is its quoted name, Some(v) is {'Some', V}, Down(process, reason, site) is
%% {'Down', Pid, Reason, Site} in declared field order.
%%
%% An Address is a pid, or {adapted, Function, Target, Maker, Launch} for an
%% address seen through a function (report §6.5), which send/2 applies in
%% the sender where Maker, the process that made it, is of the sender's
%% node, and otherwise the process Maker's node keeps for the address and
%% the sending node applies (kept/1, §8.7), Launch being the reference of
%% the launch that made it, or
%% {foreign, Pid, Descriptor, Bound} for an address foreign code gave
%% (report §8.4), whose messages cross into foreign code. A Reply(a) is
%% {Alias, Pid}: the alias of the call's monitor of its callee, as
%% gen_server's call makes one, which deactivates when the call is over and
%% so drops a late answer (report §6.6), and the caller's process, which
%% Reply.process answers (reply_process/1). The answer goes to the alias:
%% Ernest answers {Alias, answered, Value}, or, on the node that keeps a
%% remote call's note, {Alias, unnoted, Value}, which says the note is gone
%% (§8.7); foreign code {Alias, Value}, so that a call checks the second
%% only, as §8.4 says; a Reply foreign code gave back is {foreign_reply,
%% Reply, Descriptor, Bound}, answered in the second form with the answer
%% exposed. Beside an answer, a call's wait takes {Alias, restarted, How}
%% from a callee that restarts, and {Alias, fault, Cause} from a system
%% process that refuses.
%% Every process body runs under run/1, which turns an exception into an
%% exit reason that Down reports as a Fault. All spawns go through the
%% reaper process, which spawn_monitors each process; a monitor placed
%% after the death reports Unknown (report §6.9), and every monitor is the
%% reaper's. The reaper also detects deadlock (report §8.6): every live
%% process blocked in an untimed receive or in a wait for a call's answer,
%% no timed receive or clock alarm pending, no process inside foreign code,
%% and no source held that can still deliver, a subscription to the
%% program's end among them. What it needs of a process the process keeps
%% in its own dictionary, under the look's keys, and no operation writes a
%% shared row for it (look/0).
%%
%% Twelve tables hold a launch's state, each described where it is
%% defined. `ern_processes` has a row per process the runtime started or
%% adopted, #process_row{} (ern_rt.hrl). `ern_callees` holds the pending
%% calls by their callee, `ern_faults` the subscriptions to
%% faults, `ern_terminating` the subscriptions to the program's end,
%% `ern_held` the sources and the processes the system modules opened,
%% `ern_deliveries` the deliveries in flight, each with the process whose
%% `Down` it carries or none, `ern_checkers` the checkers
%% of §8.4, and `ern_launch` the launch itself, its runner, its reaper and
%% what its options give it (#launch{}), the way the terminal is read, the
%% process a deadlock faults and whether the end waits for its
%% subscribers, and the utilization the program set (§8.7). A node's (§8.7):
%% `ern_offers` and `ern_offered` hold the offers, `ern_initialized` the
%% modules whose initializers have run, whose bindings a peer's spawn asks
%% for, and `ern_notes` the notes of calls from other nodes, a compute's
%% among them.
-module(ern_rt).

-export([send/2, kept/1, acting_for/1, launch_reaper/0, process_of/1, held/3, is_never_given/1,
         is_started/1, is_address/1, spawn/2, spawn_monitored/3, spawn_root/3, spawn_root/2, self/0,
         current/0, adapted/2, call/3, call/4, call_forever/2, call_forever/3, compute/4, answer/2,
         refuse/2, reply_process/1, is_reply/1, monitor/2, monitor_service/2, demonitor/1, kill/1,
         killed/2, reason/1, left_waiting/1, wait_for_deliveries/0, started_by/1, kill_started/1,
         kill_all/1, rooting/0, rooted/2, processes/0, status/1, faults/1, termination/1,
         expected/1, checker_for/3, checker_forget/2, source_begin/0, source_begin/1, source_end/0,
         opened/3, forget_opened/1, timed/0, untimed/0, deadline/1, remaining/1, now/0, monotonic/0,
         monotonic_micros/0, entered_foreign/0, left_foreign/0, undefined_function/3,
         undefined_lambda/3, met/3, fault/1, fault/2, trace/1, failure_trace/1,
         system_process/1, hold_terminal/1, terminal_holder/0, shell_holds/0, own_terminal/1,
         input_not_utf8/0, by_input/1, read_input/1, run_main/3, say/2, say_later/2,
         wait_for_later/0, tables/0, arguments/0,
         exit_program/1, deadlock_victim/1, entry_process/0, signal/1, initializing/1, site/0,
         binding/1, binding_value/2, is_initialized/1, restarting/2, restart_now/0, ask_restart/1,
         start_cause/0, is_restarting/0, on_this_node/1, spawn_order/1, gateway/0, init_stdlib/0,
         stdlib_modules/0, init_modules/1, initialized/1, offer/2, offered/2, set_utilization/1,
         program_utilization/0, asked_of_run/1, note_call/3, drop_note/1, note_compute/2,
         computed/2, is_launched/0, drop_notes/1, ordered/1]).

-export_type([address/0]).

-include("ern_rt.hrl").

-compile({no_auto_import, [spawn/2, self/0, monitor/2, demonitor/1, now/0]}).

%% Report §8.6: each receive that can wait, by its kind (docs/style.md).
-receives({foreign_wait, [computed_answer/3, exit_program/1, fresh_run/0, end_with_program/0,
                          waited_deliveries/1, tell_service_monitors/0, say/2]}).
-receives({ernest_wait, [waited_answer/3, call_forever/3]}).
-receives({answered_at_once, [spawn_with_monitors/4, ask_monitor/2, demonitor/1, spawned/7,
                              kill_all/1, rooted/2, opened/3, asked_of_run/1]}).
-receives({own_process, [said_later/0, wait_for_later/0, kept_loop/2, reaper_loop/2,
                         wait_for_ends/1, ended_program/0, counted_link/3, delivery_ended/1,
                         write_loop/1, stream_loop/2, dropping/0, stdin_loop/2, read_input/1,
                         clock_loop/1, waited/5, told_how/3, entry_end/2, end_program/4,
                         sink_flushed/1, stop/1, stopped_in_order/1]}).

-define(UNIT, 'Unit').
%% Report §8.6: the look's keys, which a process keeps in its own
%% dictionary for the deadlock look, so that no operation writes a shared
%% row for it (look/0). FOREIGN while the process is inside foreign code
%% where its stack cannot show it, called back from foreign code or waiting
%% on what the runtime cannot see deliver, a peer, a port or the program's
%% end (entered_foreign/0); TIMED while it waits in a receive with a
%% deadline (timed/0); CALL while it makes a call, {Callee, Reply}, its
%% callee, or for a compute the peer's gateway, and the reply (pending/2).
%% Report §6.6, §6.9, §8.7: CALL is the call's record in the caller too,
%% which its end of the call reads (uncalled/0), Process.status reads
%% (status/1), and a kill reads before it kills (killed/2); a process makes
%% one call at a time, since a call that a request or an adapted address's
%% function makes ends before the call it is made for is noted (call/4).
-define(FOREIGN, '$ern_foreign').
-define(TIMED, '$ern_timed').
-define(CALL, '$ern_call').
%% Report §6.9, Appendix E.22: while a restarting function runs, its
%% outermost's start cause and the alias a supervisor asks it to restart
%% through, {Cause, Alias}, kept in the process's own dictionary, which the
%% process reads (start_cause/0, is_restarting/0) and a supervisor reads of
%% it, a process_info at its ask (ask_restart/1), so that no row is written
%% for a reader that asks seldom (restartable/0).
-define(START, '$ern_start').
%% Report §8.7, §11.2: the registered name of the process that says the
%% lines given it to say later, in order (say_later/2).
-define(SAY_LATER, ern_say_later).
-define(PROCESSES, ern_processes).
%% report §6.6, §6.9, §8.7: each pending call, {{Callee, Caller}, Reply},
%% Callee a process of this node or another, or for a compute the peer's
%% gateway, ordered, so that a restart reads its own callers and no other
%% process's calls (restarted/1); every call writes one, so the table is
%% made with the host's write concurrency (table_options/1). A caller the
%% host ends while it waits, which keeps its CALL key no longer, is found
%% here, its call dropped and the peer told (left_call/1).
-define(CALLEES, ern_callees).
%% Appendix E.21: each subscription to faults, {Subscriber, Address}, in a table
%% of its own, so that a fault reads the subscriptions and not every
%% process's row
-define(FAULTS, ern_faults).
%% Appendix E.23: each subscription to the program's end, {Subscriber,
%% Address, Told}, by the subscriber, the latest of each, which the end
%% reads; Told says whether the end has told the subscriber's run, and goes
%% with the row at a restart (report §6.9)
-define(TERMINATING, ern_terminating).
%% report §8.6: what a system process, a listener, a socket or a running
%% program holds that can still deliver, {{source, Holder}, Count}, and the
%% processes the system modules opened, {{opened, Pid}}: few rows, so that
%% the deadlock check reads them without reading every process's
-define(HELD, ern_held).
%% report §6.9: each delivery a process started to a recipient,
%% {{Recipient, Starter, Pid}}, ordered, so that a restart of the recipient
%% reads its own deliveries and no other process's
-define(DELIVERIES, ern_deliveries).
%% report §8.4: each checker, {{checker, Key}, Checker}, and what it
%% stands in front of, {{behind, Checker}, Pid, Address, Key}
-define(CHECKERS, ern_checkers).
%% report §8.2, §8.6: the launch, #launch{}, the way the terminal is read,
%% {reading, Kind}, the entry process, {entry_process, Pid}, the process a
%% deadlock faults, {deadlock_victim, Pid}, while the end looks for its
%% subscribers and waits for them, the runner that tells them, {ending,
%% Runner, Launch}, once the wait is over, {wait_over}, and the utilization
%% the program set with `Peer.setUtilization`, {utilization, Utilization}
%% (§8.7)
-define(LAUNCH, ern_launch).
%% Report §8.7: the offers of the node, {{Name, Hash}, Address, Process} by
%% the service's name and its type's hash, ordered so that one name's are
%% read together
-define(OFFERS, ern_offers).
%% report §8.7: each process's own services, {Process, Service}, by the
%% process, so that its end ends its offers
-define(OFFERED, ern_offered).
%% report §8.7: the modules whose initializers have run, {ErlangModule},
%% whose bindings a spawn from a peer asks for
-define(INITIALIZED, ern_initialized).
%% Report §8.7: the notes of calls from other nodes on this node's
%% processes, {{CallerNode, Reply}, Callee, Caller}, by the caller's node,
%% so that a loss drops a peer's together; each beside its row of CALLEES,
%% which a restart reads. A compute's note, its frame, is {{CallerNode,
%% Alias}, none, Caller} until its process is started, and then names the
%% process, whose row of CALLEES, {{Callee, Caller}, {compute, Alias}},
%% says it is a compute's, which a restart does not end and whose end its
%% caller is told of.
-define(NOTES, ern_notes).
%% Report §9.3: the descriptor of the prelude's Reason, by which a
%% compute's answer writes the Reason of a process that ended before it
%% answered as `Io.show` writes it (§8.7).
-define(REASON, {con, [{'Returned', []}, {'Killed', []}, {'ProgramEnd', []}, {'Fault', [string]},
                       {'Unknown', []}, {'Unreachable', []}, {'Restarted', []}]}).
%% The longest wait the host's `receive ... after` takes, in milliseconds.
-define(SLICE, 16#FFFFFFFF).
%% How long the reaper waits without a message before it looks for a
%% deadlock, in milliseconds (report §8.6): soon after a message and while
%% nothing can deliver but a process still runs, which may be about to
%% wait; later while something can still deliver, since a deadlock can
%% begin only once that has ended. A program at rest pays for each look
%% with a wake-up of the host, so there the look comes seldom.
-define(LOOK_SOON, 100).
-define(LOOK_LATER, 1000).

%% Report §6.9, §6.5, Appendix E.18, E.21, E.23, E.28: what stands for a
%% row in a process of the runtime's own that runs a program's function for
%% another process, a delivery, the terminal's courier and the process kept
%% for an adapted address whose target is on this node, held in its
%% dictionary under ?ACTING
%% (acting_for/1): the process it acts for, its recipient, which
%% Process.current answers, whose address self answers, whose monitor a
%% monitor there is, and which owns what the function opens; the
%% marks the Code.loads called in it evaluate under, the innermost first,
%% the first of which its spawns take for their root in place of the
%% recipient's (rooting/0); and the site of the binding such a load
%% evaluates (initializing/1).
-record(acting, {recipient, marks = [], site = <<>>}).
-define(ACTING, '$ern_acting').

%% An adapted address holds the process that made it, whose node is the
%% one its function runs on (report §6.5), and the reference of the launch
%% that made it, which is dead once that launch has ended, by an earlier
%% start of the node or as an earlier run of `ern test` over a directory
%% (§8.7, §11.2), or none where no launch was in progress.
-type address() :: pid()
                 | {adapted, fun((term()) -> term()), address(), pid(), reference() | none}
                 | {foreign, pid(), term(), map()}.

%% Report §8.2: the system processes, by the names the runtime keeps them
%% under.
-type system() :: stdout | stderr | stdin | clock | fs | terminal | tcp | os.
-type reply() :: {reference(), pid()} | {foreign_reply, {reference(), pid()}, term(), map()}.
%% What a program's answer from foreign code is checked by: its descriptor
%% and the fault's cause, or none for the runtime's own calls.
-type check() :: none | {term(), binary()}.

%% Report §6.9: a monitor as the reaper holds it. wrap: Wrap, whose
%% Wrap(Down) is sent to the caller, or for the runner, whose monitor is
%% made with the spawn so that no race can take the entry process's cause,
%% {raw, Tag}, which sends {Tag, Site, ExitReason}; asker: the process of
%% the runtime's own that asked for it for the process it acts for, or
%% none (monitor_asked/5); service: whether it is a service monitor, which
%% a restart of the process tells too (delivered_restart/2).
-record(monitor, {wrap, asker = none, service = false}).

%% The reaper's state. monitors: #{Pid => #{Caller => [#monitor{}]}}, the
%% monitors of each process by the process that made them.
%% monitoring: #{Caller => #{Pid => true}}, the processes each caller
%% monitors, so that a caller's death takes its monitors with it: nothing
%% is left to deliver them to. Each is read and written by its key alone,
%% so that a monitor, an end and a caller's death cost the same however
%% many monitors other processes hold.
%%
%% monitor_refs: #{Pid => MonitorRef}, a process the runtime did not
%% start, monitored here only while a monitor of it stands. watched:
%% #{Pid => true}, a process the runtime did not start that holds an offer
%% or a call's note (report §8.7), watched once until it ends, so that
%% they end with it.
%%
%% askers: #{Asker => {MonitorRef, [{Pid, Caller}]}}, a process of the
%% runtime's own that asked for a monitor for the process it acts for, a
%% delivery among them, monitored here until it ends, so that one that
%% ends otherwise than it returns, ended with its recipient's run
%% (abandoned/1), takes the monitors it asked for with it (asker_ended/3).
-record(reaper, {monitors = #{}, monitoring = #{}, monitor_refs = #{}, watched = #{},
                 askers = #{}}).

%% Report §8.5, §8.6, §11.2: the launch in progress, a row of its own
%% table, made as it begins and gone with the table at its end
%% (launched/1, end_program/4): its runner; the reference that tags it,
%% which the runner's messages carry; its reaper, none until it is started;
%% its standard error process while it takes the toolchain's own lines,
%% none before it starts and once the end has written the program's output
%% (say/2, §8.7); and what the options give the run, among it the
%% function a shell's launch gives that answers the processes of its own
%% beside its chain, which Process.live() leaves out (processes/0). A row
%% and not a
%% persistent term, since each update of one waits for every scheduler of
%% the host, and the end's erase of one of more than a word sets every
%% process scanning its heap, which the next launch's updates wait for (the
%% log's *The Sitting on §8.6's Bookkeeping*, its *Measured* paragraphs on
%% the launch's start).
-record(launch, {runner, tag, reaper = none, stderr = none, reporter = none, arguments = [],
                 exit = program, node = false, own = none}).

%% A subscriber the end has told and waits for (report §8.6): its spawn
%% order and its spawn site, which the end's lines name it by (§11.2), its
%% teller, and the runner's monitor of the teller.
-record(waited_for, {order, site, teller, monitor_ref}).

%%
%% Report §6.2, §9.4
%%

-spec send(address(), term()) -> 'Unit'.
send(Address, Message) ->
    deliver(Address, Message),
    ?UNIT.

%% Report §6.5: an address seen through a function is the target and the
%% function, not a process of its own, so sending applies the function here
%% and the message goes straight into the target's mailbox. A fault in the
%% function is the target's, on one node and across nodes alike: it takes
%% the message's place in the target's mailbox, and the target faults at
%% the wait that reaches it, as at a bad message's fault (§8.4), which
%% `restarting` restarts (§6.9); a target of this node the runtime did not
%% start, a foreign process, has no wait of Ernest's and is ended by the
%% fault as an exit signal (sent/1); the sender goes on. Report §8.7,
%% §11.2: one made by an earlier start of this node, or by an earlier run
%% of `ern test` over a directory, is dead, and a message to it is
%% dropped, its function not applied, wherever the function would be
%% applied: a send here, and a peer's frame as it arrives (kept/1).
deliver(Address, Message) ->
    sent(adapted_way(Address, Message)).

%% The way a message goes, an adapted address's functions of this node
%% applied first, in the sender, so that a call that one of them makes ends
%% before the call it is applied for begins (call/4): the address and the
%% message that reach it, a fault for the target, or nothing where the
%% address is of a launch that has ended. Report §8.7, §11.2: such an
%% address reaches the node again inside a peer's message, and a process
%% here may then send to it, so the send compares too. A maker that lives
%% is of the launch in progress, since every process the runtime started
%% ended with its launch (§8.6), so the common send pays the host's
%% liveness check alone, and only a dead maker's address compares its
%% launch (is_of_this_launch/1). The one exception is a process the
%% runtime did not start that outlives its launch, which keeps its
%% addresses alive while it lives, and which only an Erlang test can be.
adapted_way({adapted, Function, Target, Maker, Launch}, Message) when node(Maker) =:= node() ->
    case erlang:is_process_alive(Maker) orelse is_of_this_launch(Launch) of
        true ->
            try Function(Message) of
                Adapted -> adapted_way(Target, Adapted)
            catch
                Class:Error:Stack ->
                    %% report §7.3: the trace is where the fault was met,
                    %% here, though the target faults
                    {fault, process_of(Target), met(Class, Error, Stack)}
            end;
        false ->
            dropped
    end;
adapted_way(Address, Message) ->
    {Address, Message}.

sent(dropped) ->
    ok;
%% report §6.5: a process the runtime started, on this node or another,
%% takes the fault at its next wait, its trace and its moment the fault's;
%% a process of this node it did not start, which has no row, is ended by
%% it, with the host's term of a fault's end (§8.4)
sent({fault, Pid, #fault{cause = Cause, trace = Trace} = Fault}) when node(Pid) =:= node() ->
    case ets_lookup(?PROCESSES, Pid) of
        [_] -> Pid ! {'$ern_fault', {ern, Fault}};
        [] -> exit(Pid, {ern, fault, Cause, Trace})
    end;
sent({fault, Pid, Fault}) ->
    Pid ! {'$ern_fault', {ern, Fault}};
%% report §6.5, §8.7: a message to an adapted address made on another node
%% is carried, unconverted, to that node's gateway, where the process kept
%% for the address and this node applies the function (kept/1)
sent({{adapted, _, _, Maker, _} = Address, Message}) ->
    erlang:send({ern_gateway, node(Maker)},
                {ern_frame, erlang:self(), {adapted, Address, Message}});
%% report §8.4: a message to a foreign address crosses into foreign code
sent({{foreign, Pid, Descriptor, Bound}, Message}) ->
    Pid ! ern_boundary:expose(Descriptor, Message, Bound);
sent({Pid, Message}) ->
    Pid ! Message.

%% Report §6.5, §8.7: the process this node keeps for an adapted address it
%% made and a peer that sends to it, started by the gateway's worker for
%% the peer, the caller, as a message to the address arrives
%% (ern_gateway:work/2), so that a function that calls, or never finishes,
%% holds the peer's messages to that address and nothing else. It applies
%% each message handed to it, {apply, Message}, in the order handed, as a
%% send here applies it (deliver/2), a fault in the function being the
%% target's, and tells the worker {applied, Pid} after each; it ends when
%% the worker tells it to, `stop`, which the worker does once none waits,
%% so that no message handed to it is lost, a loss of the peer's
%% connection ending nothing (§8.7). The process is the runtime's, as a
%% Down's delivery is (wrapped/3), and has no row, since Process.live
%% lists what a program spawned and what a system module opened (Appendix
%% E.21); the reaper holds it (reaper_held/2). Report §6.5: it acts for the
%% address's target where the target is on this node, so that what the
%% function opens, spawns or asks of the runtime is the target's, as a
%% wrap's is its recipient's (acting_for/1). It is no delivery to its
%% target, and the target's end does not end it (abandoned/1). None where
%% no run is in progress to apply the function in, between two runs of
%% `ern test` over a directory, in one host, and before the first, and
%% report §8.7, §11.2: where the address is of a launch that has ended, an
%% earlier start's of the node or an earlier run's (is_of_this_launch/1);
%% the message is dropped then, its function not applied. A process whose
%% run ends as it starts ends at once, the messages handed to it dropped
%% so.
-spec kept(address()) -> pid() | none.
kept({adapted, _, _, _, Launch} = Address) ->
    Worker = erlang:self(),
    Reaper = launch_reaper(),
    case is_pid(Reaper) andalso erlang:is_process_alive(Reaper)
         andalso is_of_this_launch(Launch) of
        false ->
            none;
        true ->
            reaper_held(Reaper, fun() ->
                                    acting_for(process_of(Address)),
                                    kept_loop(Address, Worker)
                                end)
    end.

%% Report §6.5, §6.9, §8.6: a process of the runtime's own that runs Work,
%% held by the reaper as its deliveries are: linked to it, which lives as
%% long as the run, so that the process ends with the program as the
%% reaper is stopped (end_program/4), and which traps its exit, so that its
%% end, however it comes, ends nothing else (reaper/0). It runs nothing
%% where the reaper has gone. Its error handler is this module, as every
%% process's the runtime starts is (run/1).
reaper_held(Reaper, Work) ->
    erlang:spawn(fun() ->
                     try link(Reaper) of
                         true ->
                             erlang:process_flag(error_handler, ?MODULE),
                             Work()
                     catch
                         error:noproc -> ok
                     end
                 end).

kept_loop(Address, Worker) ->
    receive
        {apply, Message} ->
            deliver(Address, Message),
            Worker ! {applied, erlang:self()},
            kept_loop(Address, Worker);
        stop ->
            ok
    end.

%% Report §6.9, §6.5: the calling process of the runtime's own, a delivery,
%% the terminal's courier (ern_tty) or a process kept for an adapted
%% address, made to act for Recipient, the process it delivers to, where
%% Recipient is on this node: what the function it runs opens, spawns or
%% asks of the runtime is Recipient's, as if Recipient had done it itself
%% (#acting{}). Where Recipient is on another node, as an adapted address's
%% target may be, it acts for none, as §6.5 says: a resource the function
%% opens is the calling process's and ends with it, and a process it spawns
%% heads a chain of its own.
-spec acting_for(pid()) -> ok.
acting_for(Recipient) when node(Recipient) =:= node() ->
    _ = erlang:put(?ACTING, #acting{recipient = Recipient}),
    ok;
acting_for(_Recipient) ->
    ok.

%% Report §8.7, §11.2: the launch in progress, which tags the adapted
%% addresses its processes make, or none between two launches, while
%% none runs (launched/1).
launch() ->
    launch_field(#launch.tag, none).

%% A field of the launch in progress (#launch{}), or Default between two
%% launches and before the first.
launch_field(Position, Default) ->
    try ets:lookup_element(?LAUNCH, launch, Position)
    catch error:badarg -> Default
    end.

%% The launch's runner and the reference that tags it, which the runner's
%% messages carry.
launch_runner() ->
    [#launch{runner = Runner, tag = Launch}] = ets:lookup(?LAUNCH, launch),
    {Runner, Launch}.

%% The launch's reaper, or none before it is started and between two
%% launches.
-spec launch_reaper() -> pid() | none.
launch_reaper() ->
    launch_field(#launch.reaper, none).

%% Report §8.7, §11.2: whether an adapted address's launch is the one in
%% progress, asked of an address a frame names as it arrives (kept/1) and
%% of a dead maker's as it is sent here (adapted_way/2). A launch's
%% reference holds its node's start, which the host tells apart
%% (erlang:system_info(creation)), so one of an earlier start is never this
%% one, and neither is one of an earlier run of `ern test` over a
%% directory.
is_of_this_launch(Launch) ->
    Launch =:= launch().

%% The process an address names, through any number of adaptations and
%% through the checker of §8.4: an address that has crossed into
%% foreign code comes back as the checker in front of it, and what the
%% runtime holds of a process, its terminal, its monitors, its death,
%% must be the process itself.
-spec process_of(address()) -> pid().
process_of({adapted, _, Target, _, _}) -> process_of(Target);
process_of({foreign, Pid, _, _}) -> Pid;
process_of(Pid) -> behind(Pid).

behind(Pid) ->
    case ets_lookup(?CHECKERS, {behind, Pid}) of
        [{_, Real, _, _}] -> Real;
        _ -> Pid
    end.

%% Report §8.4: an address foreign code gave, whose messages Descriptor
%% describes inside the mu bindings Bound, as the program holds it: where
%% it is the checker in front of one of the program's processes, the address
%% that went out, the checker undone and an adapted address kept (§6.5),
%% and otherwise foreign. A checker comes back as the address that went out
%% only at the type it went out at; at another it stays foreign, so that
%% what is sent through it is checked against the process's own type. A
%% process of the program's with no checker in front of it reaches here only
%% as an `Address(Never)`, the check refusing it at any other type
%% (is_never_given/1), and is held foreign, nothing passing through it.
-spec held(pid(), term(), map()) -> address().
held(Pid, Descriptor, Bound) ->
    case ets_lookup(?CHECKERS, {behind, Pid}) of
        [{_, Real, Exposed, {_, Descriptor, Bound}}] ->
            case ets_lookup(?PROCESSES, Real) of
                [_] -> Exposed;
                [] -> {foreign, Pid, Descriptor, Bound}
            end;
        _ ->
            {foreign, Pid, Descriptor, Bound}
    end.

%% Report §8.4: whether foreign code gives as an address a process of the
%% program's whose address it was never given: one the program runs, with
%% no checker, which every address that crossed into foreign code has.
-spec is_never_given(term()) -> boolean().
is_never_given(Pid) when is_pid(Pid) ->
    ets_lookup(?CHECKERS, {behind, Pid}) =:= [] andalso ets_lookup(?PROCESSES, Pid) =/= [];
is_never_given(_) ->
    false.

%% Report §6.9, §8.7: whether the runtime started or adopted a process of
%% this node, one with a row, which a peer's kill frame alone reaches
%% (ern_peer:frame/2); a process of the runtime's own, a foreign one and
%% one that has ended have none.
-spec is_started(pid()) -> boolean().
is_started(Pid) ->
    ets_lookup(?PROCESSES, Pid) =/= [].

%% Whether a term is an address in one of the forms the runtime holds.
-spec is_address(term()) -> boolean().
is_address(Pid) when is_pid(Pid) -> true;
is_address({adapted, Function, Target, Maker, Launch})
  when is_function(Function, 1), is_pid(Maker), is_reference(Launch) ->
    is_address(Target);
is_address({foreign, Pid, _, _}) -> is_pid(Pid);
is_address(_) -> false.

%% Site names the spawning function for Down (report §6.9); the compiler
%% supplies it, so this is spawn/2 where the report's spawn takes one.
-spec spawn(fun(() -> term()), binary()) -> address().
spawn(Function, Site) ->
    spawn_with_monitors(Function, Site, [], chained).

%% Report §6.2, §6.9: a process monitored by the caller from its start, the
%% wait made with the spawn, so that no end comes before it; the caller is
%% the process a process of the runtime's own acts for (current/0).
-spec spawn_monitored(fun(() -> term()), fun((term()) -> term()), binary()) -> pid().
spawn_monitored(Function, Wrap, Site) ->
    spawn_with_monitors(Function, Site, [{current(), #monitor{wrap = Wrap}}], chained).

%% Report §11.2: the same, the process the head of a spawn chain of its
%% own, so that the processes it starts, directly or through one it
%% started, are known by it (started_by/1): the shell's load evaluates a
%% module's bindings in one.
-spec spawn_root(fun(() -> term()), fun((term()) -> term()), binary()) -> pid().
spawn_root(Function, Wrap, Site) ->
    spawn_with_monitors(Function, Site, [{erlang:self(), #monitor{wrap = Wrap}}], root).

%% Report §11.2: a process the head of a spawn chain of its own, monitored
%% by none: the shell runs each input in one, and its file's entry point,
%% so that what they start is no process of the shell's own (processes/0).
-spec spawn_root(fun(() -> term()), binary()) -> pid().
spawn_root(Function, Site) ->
    spawn_with_monitors(Function, Site, [], root).

%% Chain: chained, where the process's root is its spawner's, sent with the
%% process or the mark the root is read from (parent/0), or root, where it
%% is its own.
spawn_with_monitors(Function, Site, Monitors, chained) ->
    spawn_with_monitors(Function, Site, Monitors, {chained, parent()});
spawn_with_monitors(Function, Site, Monitors, Chain) ->
    Ref = make_ref(),
    launch_reaper() ! {spawn, erlang:self(), Ref, Function, Site, Monitors, Chain},
    receive
        {Ref, Pid} -> Pid
    end.

%% Report §6.9, §11.2, Appendix E.28: what a spawn's root is read from
%% (root/2): the spawner, or for a process of the runtime's own that acts
%% for another (acting_for/1), that process, or the mark a Code.load called
%% in it evaluates under (rooting/0).
parent() ->
    case erlang:get(?ACTING) of
        undefined -> erlang:self();
        #acting{recipient = Recipient, marks = []} -> Recipient;
        #acting{marks = [Mark | _]} -> Mark
    end.

%% Report §6.5, §6.9: the prelude's self, the address of the running
%% process, or of the process a process of the runtime's own acts for, a
%% delivery's recipient or an adapted address's target (acting_for/1), as
%% Process.current reads it.
-spec self() -> address().
self() ->
    current().

%% Appendix E.21, report §6.9: Process.current, the running process, or the
%% process a delivery or a process kept for an adapted address acts for
%% (acting_for/1).
-spec current() -> pid().
current() ->
    case erlang:get(?ACTING) of
        undefined -> erlang:self();
        #acting{recipient = Recipient} -> Recipient
    end.

%%
%% Report §6.5, §9.5
%%

%% Report §6.5, §8.7, §11.2: the address holds the calling process, its
%% maker, whose node applies its function, and the launch in progress,
%% whose end ends the address (adapted_way/2, kept/1).
-spec adapted(address(), fun((term()) -> term())) -> address().
adapted(Target, Function) ->
    {adapted, Function, Target, erlang:self(), launch()}.

%%
%% Report §6.6
%%

%% Report §6.6: the runtime's own call, whose answer is not checked (§8.4).
-spec call(address(), fun((reply()) -> term()), integer()) -> 'None' | {'Some', term()}.
call(Address, Request, Ms) ->
    call(Address, Request, Ms, none).

%% Report §6.6, §8.4: a program's call, whose answer from foreign code is
%% checked by Check.
-spec call(address(), fun((reply()) -> term()), integer(), check()) ->
          'None' | {'Some', term()}.
call(Address, Request, Ms, Check) ->
    %% report §6.6: the clock starts at the call, before the request is
    %% made and delivered
    Deadline = deadline(Ms),
    line_guard(Address),
    {Callee, Reply} = watched(Address),
    %% settled however the call ends, a fault of the message's function or
    %% of the callee among the ways, which a process restarted in place
    %% outlives (§6.9); report §6.6, §6.5: the request is made, and the
    %% adapted address's functions applied, before the call is noted, so
    %% that a call either makes, printing among them, ends first
    Answer = try
                 Way = adapted_way(Address, Request({Reply, current()})),
                 pending(Callee, Reply),
                 sent(Way),
                 timed(),
                 try waited_answer(Reply, Deadline, Check) after untimed() end
             after
                 settled(Reply)
             end,
    case Answer of
        %% report §6.9: a restart asked for is taken at a call's wait
        '$ern_restart' -> restart_now();
        _ -> Answer
    end.

%% Report §6.6: the answer, or None after the deadline, or at once when the
%% callee ends or restarts before it answers.
waited_answer(Reply, Deadline, Check) ->
    receive
        {Reply, answered, Value} -> {'Some', Value};
        {Reply, unnoted, Value} -> closed(), {'Some', Value};
        {Reply, Value} -> {'Some', foreign_answer(Check, Value)};
        {Reply, restarted, _} -> closed(), 'None';
        {Reply, fault, Cause} -> fault(Cause);
        {'DOWN', Reply, process, _, _} -> closed(), 'None';
        '$ern_restart' -> '$ern_restart';
        %% report §8.4, §6.5: a foreign message's fault, or one met on a
        %% message's way, taken at a call's wait
        {'$ern_fault', Fault} -> throw(Fault)
    after remaining(Deadline) ->
        case remaining(Deadline) of
            0 -> 'None';
            _ -> waited_answer(Reply, Deadline, Check)
        end
    end.

%% Report §6.6: the runtime's own callForever (§8.4).
-spec call_forever(address(), fun((reply()) -> term())) -> term().
call_forever(Address, Request) ->
    call_forever(Address, Request, none).

%% Report §6.6, §8.4: a program's callForever, whose answer from foreign
%% code is checked by Check. Report §6.6, §7.4: the callee's site, as a
%% Down names it (§6.9), is read as the call begins, while the callee's
%% row stands, so that the fault of the callee's it carries names it.
-spec call_forever(address(), fun((reply()) -> term()), check()) -> term().
call_forever(Address, Request, Check) ->
    line_guard(Address),
    {Callee, Reply} = watched(Address),
    Site = callee_site(Callee),
    %% settled however the call ends, and noted once its request is made,
    %% as call/4's is
    Answer = try
                 Way = adapted_way(Address, Request({Reply, current()})),
                 pending(Callee, Reply),
                 sent(Way),
                 receive
                     {Reply, answered, Value} -> {answered, Value};
                     {Reply, unnoted, Value} -> closed(), {answered, Value};
                     {Reply, Value} -> {answered, foreign_answer(Check, Value)};
                     {Reply, restarted, How} ->
                         closed(),
                         {restarted, How};
                     %% report §8.2: a system process faults the caller it
                     %% answers
                     {Reply, fault, SystemCause} -> {fault, SystemCause};
                     {'DOWN', Reply, process, _, CalleeExitReason} ->
                         closed(),
                         {ended, CalleeExitReason};
                     %% report §6.9: a restart asked for is taken at a call's
                     %% wait
                     '$ern_restart' -> restart;
                     %% report §8.4, §6.5: a foreign message's fault, or one
                     %% met on a message's way, taken there too
                     {'$ern_fault', ForeignFault} -> {thrown, ForeignFault}
                 end
             after
                 settled(Reply)
             end,
    case Answer of
        {answered, Answered} -> Answered;
        {fault, Cause} -> fault(Cause);
        {thrown, Fault} -> throw(Fault);
        {restarted, asked} -> fault(<<"callee was restarted">>);
        {restarted, {fault, Cause}} -> callee_fault(Cause, Site);
        %% report §6.6, Appendix E.18: a socket or a listener the program
        %% closed ended as a function returns, and its caller learns why
        {ended, {ern, closed}} -> fault(<<"callee was closed">>);
        {ended, ExitReason} -> ended(Callee, Site, reason(ExitReason));
        restart -> restart_now()
    end.

%% Report §6.9: the spawn site of a process the runtime started, as its
%% Down names it, and the empty text for any other, a process of another
%% node among them.
callee_site(Callee) ->
    case ets_lookup(?PROCESSES, Callee) of
        [#process_row{site = Site}] -> Site;
        _ -> <<>>
    end.

%% Report §6.6, §7.4, §11.2: a callee's fault carried to its caller, which
%% faults with the callee's cause unchanged, the callee's site beside it
%% for its report's line, `, the fault of the callee Ledger.start:6`, and
%% none where the site is not known; its trace the caller's stack (met/3).
-spec callee_fault(binary(), binary()) -> no_return().
callee_fault(Cause, <<>>) -> fault(Cause);
callee_fault(Cause, Site) -> throw({ern, #fault{cause = Cause, callee = Site}}).

%% Report §8.4: an answer foreign code gave, checked against the reply's
%% type as a foreign function's return is.
foreign_answer(none, Value) -> Value;
foreign_answer({Descriptor, Cause}, Value) -> ern_boundary:value(Descriptor, Value, Cause).

%% Report §6.6, §7.4: a callForever whose callee ended faults the caller with
%% the callee's cause, its site beside it, or says how it ended; with the
%% program the caller ends too.
-spec ended(pid(), binary(), term()) -> no_return().
ended(_Callee, Site, {'Fault', Cause}) -> callee_fault(Cause, Site);
ended(_Callee, _, 'Killed') -> fault(<<"callee was killed">>);
ended(_Callee, _, 'Returned') -> fault(<<"callee returned without answering">>);
ended(_Callee, _, 'Unknown') -> fault(<<"callee had ended">>);
%% report §8.7: the callee's node was lost, and the callee may live on
ended(_Callee, _, 'Unreachable') -> fault(<<"callee is unreachable">>);
ended(Callee, _, 'ProgramEnd') when node(Callee) =:= node() ->
    end_with_program();
%% report §6.6, §8.7: a callee of another node ended with its program, its
%% node stopping in order, and the caller's program runs on
ended(_Callee, _, 'ProgramEnd') ->
    fault(<<"callee ended with its program">>).

%% Report §8.6: the caller ended with the program, by a signal, not an
%% exception, which run/1 would take for a fault. The signal ends a process
%% that traps no exits before exit/2 returns; one that traps them takes it
%% as a message, and waits for the end the program brings, inside foreign
%% code for the look, as exit_program/1's caller does.
-spec end_with_program() -> no_return().
end_with_program() ->
    exit(erlang:self(), {ern, program_end}),
    entered_foreign(),
    receive after infinity -> ok end.

%% A call's monitor of the process behind the address, whose alias is the
%% reply's (watched/1); and, once the request is made, the call noted
%% against that process (pending/2): the caller's CALL key put first, so
%% that whatever row or note the call has, a kill finds by it (killed/2);
%% then the callee's row, by which a restart of a callee of this node ends
%% the call, and by which the reaper finds the call of a caller the host
%% ends (left_call/1); and report §8.7: for a process of another node, a
%% note to its gateway, which that node keeps beside its own row of the
%% callee, sent before the request so that it arrives first.
watched(Address) ->
    Callee = process_of(Address),
    {Callee, erlang:monitor(process, Callee, [{alias, demonitor}])}.

pending(Callee, Reply) ->
    called(Callee, Reply),
    case node(Callee) =:= node() of
        true ->
            true;
        false ->
            erlang:send({ern_gateway, node(Callee)},
                        {ern_frame, erlang:self(), {call_waits, Callee, Reply}})
    end.

%% The calling process's CALL key, and then its row of the callees, Callee a
%% process or, for a compute, the peer's gateway (compute/4).
called(Callee, Reply) ->
    _ = erlang:put(?CALL, {Callee, Reply}),
    ets:insert(?CALLEES, {{Callee, erlang:self()}, Reply}).

%% The call is over: its records go (uncalled/0), its monitor and with it
%% the alias go, and every answer that came before them, after a restart's
%% word, say, is not left in the caller's mailbox.
settled(Reply) ->
    uncalled(),
    erlang:demonitor(Reply, [flush]),
    flushed(Reply).

%% The calling process's call, if it has one, over: its records dropped
%% (uncalled/2), and then its CALL key, so that a kill that finds the key
%% finds what the call has left (killed/2).
uncalled() ->
    case erlang:get(?CALL) of
        undefined ->
            true;
        Call ->
            uncalled(erlang:self(), Call),
            erlang:erase(?CALL)
    end.

%% Report §6.6, §8.7: the records of Caller's call, Call its CALL key,
%% dropped: the callee's row; and where its callee is of another node,
%% whose note no answer there, restart or end has let go, the second note
%% tells that node the call is over, and so it tells the peer a compute
%% waits on. A row dropped twice, or a second note for a note let go, does
%% nothing, since a kill may read the key between the two (killed/2). The
%% table goes with the program's end, which a kill under way may meet.
uncalled(_Caller, undefined) ->
    true;
uncalled(Caller, {Callee, Reply}) ->
    try ets:delete(?CALLEES, {Callee, Caller}) catch error:badarg -> true end,
    case gateway_of(Callee) of
        none -> true;
        Gateway -> erlang:send(Gateway, {ern_frame, Caller, {call_over, Reply}})
    end.

%% Report §6.6, §6.9, §8.7: the call of a process the host ended while it
%% waited, killed by foreign code or by the end of a process it was linked
%% to, which ran no `after` and keeps its CALL key no longer: its rows,
%% found among every pending call's, a read that such an end alone pays,
%% dropped as its own end of the call drops them (uncalled/2), the peer
%% told where its callee is of another node. An end the runtime gives
%% dropped them first (killed/2), and a fault or a restart ended the call
%% as the process left its wait.
left_call(Pid) ->
    lists:foreach(fun({{Callee, _}, Reply}) -> uncalled(Pid, {Callee, Reply}) end,
                  matching_rows(?CALLEES, {{'_', Pid}, '_'})).

%% Whether an end is the host's, none the runtime gives and not the
%% process's own: a return, a fault, a kill, the program's end and a close
%% are the runtime's, and any other reason the host gave (§6.9).
is_host_end(normal) -> false;
is_host_end({ern, _}) -> false;
is_host_end({ern, _, _, _}) -> false;
is_host_end(_) -> true.

%% The gateway a call's second note goes to: the peer's a compute waits on
%% (compute/4), the node's of a callee of another node, or none.
gateway_of({ern_gateway, _} = Gateway) -> Gateway;
gateway_of(Callee) when node(Callee) =:= node() -> none;
gateway_of(Callee) -> {ern_gateway, node(Callee)}.

%% Report §8.7, §6.6: a compute on a peer, whose wait is a call's: the
%% caller's CALL key and its row, its callee the peer's gateway, so that
%% the call's second note follows where its time runs out, where it is
%% asked to restart, where it is killed while it waits (killed/2), and
%% where the host ends it (left_call/1); an alias, which takes one answer
%% and drops a late one; and a watch of the peer's gateway, as a find
%% keeps one, whose end is a loss, which drops the peer's notes, so that no
%% second note follows it. The frame, which Frame makes of the alias, is
%% the call's first note. The answer is the value, the caller's fault with
%% the cause, the trace and the callee's site that crossed, the peer's name
%% beside them and the trace followed by the compute's site, {Peer, Site}
%% being the two (§8.7, §11.2), `Other` with the Reason of a process that
%% ended before it answered, or the failure the peer answered or the wait
%% met.
-spec compute(node(), fun((reference()) -> term()), integer(), {binary(), binary()}) ->
          {'Right', term()} | {'Left', term()}.
compute(Node, Frame, Deadline, {Peer, Site}) ->
    Gateway = {ern_gateway, Node},
    MonitorRef = erlang:monitor(process, Gateway),
    Alias = erlang:alias([reply]),
    called(Gateway, Alias),
    erlang:send(Gateway, {ern_frame, erlang:self(), Frame(Alias)}),
    %% report §8.6: a peer's answer is none the look sees coming
    entered_foreign(),
    Answer = try computed_answer(Alias, MonitorRef, Deadline) after left_foreign() end,
    erlang:demonitor(MonitorRef, [flush]),
    case Answer of
        {'Right', _} = Value -> Value;
        {'Left', _} = Failure -> Failure;
        {faulted, Cause, Trace, Callee} ->
            throw({ern, #fault{cause = Cause, trace = <<Trace/binary, Site/binary, "\n">>,
                               callee = Callee, peer = Peer}});
        {ended, Reason} -> {'Left', {'Other', ern_show:show(?REASON, Reason)}};
        {thrown, Fault} -> throw(Fault);
        '$ern_restart' -> restart_now()
    end.

%% The compute's answer through the alias, which lets the caller's key go
%% with no second note, the peer having let its note go; a loss, after
%% which none comes; a restart asked for or a foreign message's fault,
%% taken at a call's wait, which end the compute with its second note; or
%% the time run out, after which an answer that came first is taken, and
%% otherwise the second note sent.
computed_answer(Alias, MonitorRef, Deadline) ->
    receive
        {Alias, _, _} = Message -> answer_taken(Message);
        {'DOWN', MonitorRef, process, _, _} ->
            erlang:unalias(Alias),
            closed(),
            {'Left', 'Unreachable'};
        '$ern_restart' ->
            over(Alias),
            '$ern_restart';
        {'$ern_fault', Fault} ->
            over(Alias),
            {thrown, Fault}
    after remaining(Deadline) ->
        case remaining(Deadline) of
            0 ->
                erlang:unalias(Alias),
                receive
                    {Alias, _, _} = Message -> answer_taken(Message)
                after 0 ->
                    uncalled(),
                    {'Left', 'Timeout'}
                end;
            _ ->
                computed_answer(Alias, MonitorRef, Deadline)
        end
    end.

%% Report §8.7: the peer's answer as the caller takes it. A fault crosses
%% as the peer's #fault{}, of which the caller takes the cause, the trace
%% and the callee's site, each text, and only where each is UTF-8, since
%% the caller's fault is reported as text (§11.2); an answer of another
%% shape, or a fault that is not text, is none a peer's runtime writes,
%% and answers `Other` with this node's reason. The answer comes through the
%% caller's alias and not through the gateway, which ends the connection
%% of a peer whose frame it cannot read.
answer_taken(Message) ->
    closed(),
    case Message of
        {_, computed, Value} ->
            {'Right', Value};
        {_, failed, Error} ->
            {'Left', Error};
        {_, ended, Reason} ->
            {ended, Reason};
        {_, faulted, #fault{cause = Cause, trace = Trace, callee = Callee}} ->
            case is_text(Cause) andalso is_text(Trace)
                 andalso (Callee =:= none orelse is_text(Callee)) of
                true -> {faulted, Cause, Trace, Callee};
                false -> unreadable_answer()
            end;
        _ ->
            unreadable_answer()
    end.

unreadable_answer() ->
    {'Left', {'Other', <<"the peer's answer could not be read">>}}.

is_text(Text) ->
    is_binary(Text) andalso ern_fs:is_utf8(Text).

%% The compute given up before its answer: the alias goes, and the second
%% note tells the peer.
over(Alias) ->
    erlang:unalias(Alias),
    uncalled().

%% Report §8.7: the calling process's call over where its callee's node has
%% already let its note go: by an answer given there, by the restart it
%% told, or by the callee's end or the connection's, so that no second note
%% follows; the callee's row, which a callee's end leaves to its callers,
%% goes, and then the CALL key (uncalled/0).
closed() ->
    case erlang:get(?CALL) of
        {Callee, _} -> ets:delete(?CALLEES, {Callee, erlang:self()});
        undefined -> true
    end,
    erlang:erase(?CALL).

flushed(Reply) ->
    receive
        {Reply, _} -> flushed(Reply);
        {Reply, _, _} -> flushed(Reply)
    after 0 ->
        ok
    end.

%% Report §6.6, §8.4: an answer in Ernest's form, or in foreign code's for a
%% Reply foreign code gave back, which the caller checks and which crosses
%% into foreign code.
-spec answer(reply(), term()) -> 'Unit'.
answer({foreign_reply, {Alias, _}, Descriptor, Bound}, Value) ->
    Alias ! {Alias, ern_boundary:expose(Descriptor, Value, Bound)},
    ?UNIT;
answer({Alias, _}, Value) when node(Alias) =:= node() ->
    Alias ! {Alias, answered, Value},
    ?UNIT;
%% report §8.7: a reply of a call from another node, whose note this node may
%% keep: an answer given here lets it go, and tells the caller so
answer({Alias, _}, Value) ->
    case dropped_note(Alias) of
        true -> Alias ! {Alias, unnoted, Value};
        false -> Alias ! {Alias, answered, Value}
    end,
    ?UNIT.

%% Report §8.2, §7.4: a system process faults the caller it answers.
-spec refuse(reply(), binary()) -> 'Unit'.
refuse({foreign_reply, Reply, _, _}, Cause) ->
    refuse(Reply, Cause);
refuse({Alias, _}, Cause) ->
    Alias ! {Alias, fault, Cause},
    ?UNIT.

%% Report §6.6, §9.5: the prelude's Reply.process, the caller's process
%% the reply carries beside its alias, or the one foreign code put in a
%% reply it made (§8.4).
-spec reply_process(reply()) -> pid().
reply_process({foreign_reply, {_, Pid}, _, _}) -> Pid;
reply_process({_, Pid}) -> Pid.

%% Report §8.4: whether a term has a Reply's shape, an alias and a process.
-spec is_reply(term()) -> boolean().
is_reply({Alias, Pid}) -> is_reference(Alias) andalso is_pid(Pid);
is_reply(_) -> false.

%%
%% Report §6.9
%%

%% Every monitor is the reaper's: it holds the wrap and delivers the cause,
%% at once if the process is already dead. A process the runtime did not
%% start, a system process, a socket or a running program, is monitored from
%% there too, so a monitor costs no process of its own (report §6.9). The
%% monitor is made when the reaper says so, so that a process killed just
%% after it is seen to die rather than found already ended. Report §6.5,
%% §6.9: the monitor is the caller's, or that of the process a process of
%% the runtime's own acts for (current/0), which the wrap delivers to and
%% whose restart and end cancel it; the calling process is told it is made.
-spec monitor(pid(), fun((term()) -> term())) -> 'Unit'.
monitor(Process, Wrap) ->
    ask_monitor(Process, #monitor{wrap = Wrap}).

%% Report §6.9: the prelude's monitorService, a monitor the reaper keeps
%% marked, which a restart of the process tells as well as its end
%% (delivered_restart/2).
-spec monitor_service(pid(), fun((term()) -> term())) -> 'Unit'.
monitor_service(Process, Wrap) ->
    ask_monitor(Process, #monitor{wrap = Wrap, service = true}).

ask_monitor(Process, Monitor) ->
    Ref = make_ref(),
    Reaper = launch_reaper(),
    %% a Process foreign code gave back may be the checker before the process
    Reaper ! {monitor, process_of(Process), current(), erlang:self(), Monitor, Ref},
    receive {Ref, monitored} -> ?UNIT end.

%% Report §6.9: the prelude's demonitor, every monitor the caller holds on
%% the process ended by the reaper, which answers once none can deliver
%% (demonitored/5); the caller is the process a process of the runtime's
%% own acts for, as at a monitor (current/0).
-spec demonitor(pid()) -> 'Unit'.
demonitor(Process) ->
    Ref = make_ref(),
    launch_reaper() ! {demonitor, process_of(Process), current(), erlang:self(), Ref},
    receive {Ref, demonitored} -> ?UNIT end.

%% Report §6.9, §8.7: the prelude's kill, which a peer's frame asks of this
%% node too (ern_peer:frame/2). A process of this node is ended by
%% killed/2; one of another node by its own node, asked by a frame to that
%% node's gateway, which is sent as a send is and vanishes where the node
%% is out of reach. Report §6.9, §6.5: a process of the runtime's own that
%% kills the process it acts for ends there, as that process would had it
%% killed itself, so that nothing its function does after the kill is
%% done, a delivery's message delivered among it; it ends as one that
%% returned, so that what it is linked to goes on, and the recipient's end
%% takes what it held (abandoned/1).
-spec kill(address()) -> 'Unit'.
kill(Address) ->
    %% report §8.2: no program can name a system process, whose reference is
    %% private to its module, so an address a program gives here is a
    %% program's; report §8.7: a peer's frame is carried out only for a
    %% process the runtime started (ern_peer:frame/2)
    case process_of(Address) of
        Pid when node(Pid) =:= node() ->
            killed(Pid, {ern, killed}),
            case erlang:get(?ACTING) of
                #acting{recipient = Pid} -> exit(erlang:self(), normal);
                _ -> ok
            end;
        Pid ->
            erlang:send({ern_gateway, node(Pid)}, {ern_frame, erlang:self(), {kill, Pid}})
    end,
    ?UNIT.

%% Report §6.9, §6.6, §8.6, §8.7: Pid, a process of this node, ended from
%% outside it, How its exit reason, or {found, Cause}, a fault the runtime
%% finds in it, whose trace is its stack as it is found (§7.3). Every end
%% the runtime gives from outside to a process that may be in a call comes
%% here but the program's end, which ends every process and the tables with
%% them: the prelude's kill and a peer's (kill/1), a delivery ended with
%% its recipient (abandoned/1), an end's teller cut short (cut_short/2), a
%% compute's process its second note ends (drop_note/1), the terminal's
%% courier (ern_tty), and a deadlock's fault or a system process's given to
%% the entry process (found_fault/2).
%%
%% A process ended so runs no `after`, so the call it waits in is ended
%% here: it is suspended, so that it cannot end its call and begin another
%% meanwhile, its CALL key is read, the call's records are dropped as its
%% own end of the call drops them (uncalled/2), and then it is ended. A
%% process of its own does that, which no process can name, and so none can
%% suspend: two processes that kill each other at once would otherwise each
%% be suspended by the other for ever, a hang the look cannot see, and a
%% process of the runtime's own would wait on each process it suspends.
%% The suspension ends with that process. Report §8.6: it is a source while
%% it works, since the look sees neither it nor the end it brings.
%%
%% A process that kills itself, by the prelude's kill, waits in no call as
%% it kills, since a call's request and an adapted address's functions are
%% made before the call is noted (call/4), so it ends at once; any other
%% end, a fault found among them, comes from a process of its own.
-spec killed(pid(), term()) -> ok.
killed(Pid, {ern, killed} = ExitReason) when Pid =:= erlang:self() ->
    exit(Pid, ExitReason),
    ok;
killed(Pid, How) ->
    %% report §6.9: a kill of a process that has ended does nothing
    case erlang:is_process_alive(Pid) of
        true ->
            Kill = make_ref(),
            source_begin(Kill),
            _ = erlang:spawn(fun() -> try killing(Pid, How) after source_end(Kill) end end),
            ok;
        false ->
            ok
    end.

killing(Pid, How) ->
    try erlang:suspend_process(Pid) of
        true ->
            case erlang:process_info(Pid, [{dictionary, ?CALL} | stack_asked(How)]) of
                [{_, Call} | Stack] ->
                    uncalled(Pid, Call),
                    exit(Pid, exit_reason(Pid, How, Stack));
                undefined ->
                    ok
            end
    catch
        %% it had ended, or ended as it was being suspended, killed by
        %% another kill among the ways
        error:badarg -> ok;
        error:exited -> ok
    end.

stack_asked({found, _}) -> [current_stacktrace];
stack_asked(_) -> [].

exit_reason(Pid, {found, Cause}, [{current_stacktrace, Stack}]) ->
    ended_with(Pid, #fault{cause = Cause, trace = trace(Stack), time = now()});
exit_reason(_Pid, ExitReason, []) ->
    ExitReason.

-spec reason(term()) -> term().
reason(normal) -> 'Returned';
%% report §6.9, Appendix E.18: a socket or a listener the program closed
%% returned, for a monitor; its caller faults with its own cause
reason({ern, closed}) -> 'Returned';
reason({ern, killed}) -> 'Killed';
reason({ern, program_end}) -> 'ProgramEnd';
%% report §7.3, §11.2: the trace is the fault's report's, never the cause's
reason({ern, fault, Cause, _Trace}) -> {'Fault', Cause};
%% report §6.9: a monitor made after the end cannot say how it ended
reason(noproc) -> 'Unknown';
%% report §6.9, §8.7: the process's node went out of reach, and the process
%% may live on
reason(noconnection) -> 'Unreachable';
reason(Other) -> {'Fault', format("~p", [Other])}.

%% The reaper: spawns on request with a monitor of its own, keeps each live
%% process's row, and tells each process that monitors another how it
%% ended. Report §6.9: of a process that has ended it keeps nothing, so a
%% monitor made after the end answers Unknown, and the deliveries to it
%% end with it (abandoned/1). Report §6.5, §6.9, §8.6, §8.7: it holds the
%% runtime's own processes, each delivery it starts, each process kept for
%% an adapted address (kept/1) and each of the end's tellers (tell_all/3),
%% linked to it, so that each ends with the run as the reaper is stopped
%% (end_program/4); it traps their exits, so that one that ends otherwise
%% than it returns, killed from foreign code among the ways, ends nothing
%% but itself (held_ended/3).
reaper() ->
    erlang:process_flag(trap_exit, true),
    reaper_loop(#reaper{}).

reaper_loop(Reaper) ->
    reaper_loop(Reaper, ?LOOK_SOON).

reaper_loop(Reaper, Wait) ->
    receive
        {spawn, From, Ref, Function, Site, SpawnMonitors, Chain} ->
            reaper_loop(spawned(From, Ref, Function, Site, SpawnMonitors, Chain, Reaper));
        %% report §8.7: a peer's question, answered while the run's tables
        %% are there (asked_of_run/1): a spawn starts where every binding
        %% its function's reach names has its value, as the code of the
        %% unit that runs it reads it (ern_code:absent_binding/2)
        {asked, From, Ref, {spawn, Function, Unit, Bindings, Site, Peer}} ->
            case ern_code:absent_binding(Unit, Bindings) of
                none ->
                    reaper_loop(spawned(From, Ref, Function, Site, [], {peer, Peer}, Reaper));
                Absent ->
                    From ! {Ref, {absent, Absent}},
                    reaper_loop(Reaper)
            end;
        %% report §8.7: a compute starts as a spawn does, its process
        %% running the function for its caller (computing/2)
        {asked, From, Ref, {compute, Function, Unit, Bindings, Site, Peer, Caller, Alias}} ->
            case ern_code:absent_binding(Unit, Bindings) of
                none ->
                    reaper_loop(spawned(From, Ref, computing(Function, Alias), Site, [],
                                        {compute, Peer, Caller, Alias}, Reaper));
                Absent ->
                    From ! {Ref, {absent, Absent}},
                    reaper_loop(Reaper)
            end;
        {asked, From, Ref, Question} ->
            From ! {Ref, answer_of_run(Question)},
            reaper_loop(Reaper);
        {adopt, Pid, Site, Owner, From, Ref} ->
            adopted(Pid, Site, Owner, From, Ref),
            reaper_loop(Reaper);
        %% Appendix E.28: the processes a load's evaluation started given
        %% their caller's root, between two spawns (rooted/2)
        {rooted, From, Ref, Mark, Root} ->
            reroot(Mark, Root),
            From ! {Ref, rooted},
            reaper_loop(Reaper);
        {monitor, Pid, Caller, From, Monitor, Ref} ->
            reaper_loop(monitored(Pid, Caller, From, Monitor, Ref, Reaper));
        {demonitor, Pid, Caller, From, Ref} ->
            reaper_loop(demonitored(Pid, Caller, From, Ref, Reaper));
        {report, Pid, Site, #fault{} = Fault} ->
            case ets:lookup(?PROCESSES, Pid) of
                [#process_row{peer = Peer, expected = false}] ->
                    report(Pid, Site, Peer, Fault, true);
                [#process_row{expected = true}] -> ok;
                [] -> report(Pid, Site, none, Fault, true)
            end,
            reaper_loop(Reaper);
        {new_run, Pid, Ref} ->
            reaper_loop(new_run(Pid, Ref, Reaper));
        {tell_service_monitors, Pid, Ref} ->
            Pid ! {Ref, told, delivered_restart(Pid, Reaper)},
            reaper_loop(Reaper);
        {end_program, From, Ref} ->
            ended_program(From, Ref);
        {'DOWN', _MonitorRef, process, Pid, ExitReason} ->
            reaper_loop(down(Pid, ExitReason, Reaper));
        %% report §8.7: an offer of a process the runtime does not watch,
        %% a foreign one, and a call's note on it end with it as any other
        %% process's do
        {watch, Pid} ->
            reaper_loop(watched(Pid, Reaper));
        {'ASKER_DOWN', _MonitorRef, process, Asker, ExitReason} ->
            reaper_loop(asker_ended(Asker, ExitReason, Reaper));
        {'WATCHED_DOWN', _MonitorRef, process, Pid, ExitReason} ->
            unoffered(Pid),
            drop_callee_notes(Pid, ExitReason),
            abandoned(Pid),
            reaper_loop(Reaper#reaper{watched = maps:remove(Pid, Reaper#reaper.watched)});
        {'EXIT', Pid, ExitReason} ->
            reaper_loop(held_ended(Pid, ExitReason, Reaper))
    after Wait ->
        case look() of
            deadlock ->
                deadlock(),
                reaper_loop(Reaper);
            running ->
                reaper_loop(Reaper);
            delivering ->
                reaper_loop(Reaper, ?LOOK_LATER)
        end
    end.

%% Appendix E.28: the rows whose root is Mark given Root, in one pass of the
%% host's over the table, each row's other fields kept.
reroot(Mark, Root) ->
    _ = ets:select_replace(?PROCESSES, [{rooted_row(Mark), [], [{rooted_row({const, Root})}]}]),
    ok.

%% A row of a match specification whose root is Root, its other fields the
%% specification's variables.
rooted_row(Root) ->
    #process_row{pid = '$1', site = '$2', spawn_order = '$3', root = Root, peer = '$4',
                 expected = '$5', fault = '$6'}.

%% A process the runtime did not start, watched from here until it ends,
%% once however many offers and notes it holds.
watched(Pid, #reaper{watched = Watched} = Reaper) when is_map_key(Pid, Watched) ->
    Reaper;
watched(Pid, #reaper{watched = Watched} = Reaper) ->
    _ = erlang:monitor(process, Pid, [{tag, 'WATCHED_DOWN'}]),
    Reaper#reaper{watched = Watched#{Pid => true}}.

%% A process spawned on request, which starts once its row is in the
%% table, since what it does first may write its row, its site
%% (initializing/1) and its root (rooting/0) among it. A monitor made with
%% the spawn, spawnMonitored's, stands as
%% monitor's does. Its root is its spawner's, where Chain says so and the
%% spawner is a process of the runtime's or acts for one, and else itself
%% (parent/0); a peer's spawn,
%% {peer, Node}, heads a chain of its own, and its row keeps the peer's
%% node, which its fault's line names (§11.2), and so does a peer's
%% compute, {compute, Node, Caller, Alias}, whose process starts only once
%% its note names it (is_noted/2), and otherwise never runs, answered
%% `over`.
spawned(From, Ref, Function, Site, SpawnMonitors, Chain, Reaper) ->
    Started = fun() -> receive Ref -> run(Function) end end,
    {Pid, _MonitorRef} = erlang:spawn_monitor(Started),
    {Root, Peer} = case Chain of
                       {chained, Parent} -> {root(Parent, Pid), none};
                       root -> {Pid, none};
                       {peer, Node} -> {Pid, Node};
                       {compute, Node, _, _} -> {Pid, Node}
                   end,
    ets:insert(?PROCESSES, #process_row{pid = Pid, site = Site, spawn_order = next_spawn_order(),
                                        root = Root, peer = Peer}),
    case is_noted(Chain, Pid) of
        true ->
            Pid ! Ref,
            From ! {Ref, Pid};
        false ->
            exit(Pid, {ern, killed}),
            From ! {Ref, over}
    end,
    lists:foldl(fun({Caller, Monitor}, Acc) -> monitor_asked(Pid, Caller, From, Monitor, Acc) end,
                Reaper, SpawnMonitors).

%% Report Appendix E.18, E.23: a listener, a socket or a running program,
%% which its system process starts, is a process of the program's as one
%% spawned is, monitored here and listed, its root its owner's, the
%% process that opened it.
adopted(Pid, Site, Owner, From, Ref) ->
    _ = erlang:monitor(process, Pid),
    ets:insert(?PROCESSES, #process_row{pid = Pid, site = Site, spawn_order = next_spawn_order(),
                                        root = root(Owner, Pid)}),
    From ! {Ref, adopted}.

%% The root of Pid, started by Parent: Parent's where the runtime started
%% or adopted Parent, and else Pid itself, the head of its chain; or the
%% mark Parent is, which a Code.load in a process acting for another
%% evaluates under (parent/0).
root(Mark, _Pid) when is_reference(Mark) ->
    Mark;
root(Parent, Pid) ->
    case ets:lookup(?PROCESSES, Parent) of
        [#process_row{root = Root}] -> Root;
        [] -> Pid
    end.

%% A monitor of Pid that Caller made, From the process told it is made, a
%% process of the runtime's own where it acts for Caller (monitor/2).
monitored(Pid, Caller, From, Monitor, Ref, Reaper) ->
    Reaper1 = monitor_asked(Pid, Caller, From, Monitor, Reaper),
    From ! {Ref, monitored},
    Reaper1.

%% Report §6.9: a monitor of Pid that From asked for Caller, by monitor or
%% with a spawn, standing where the ask is live. A process asks for its
%% own, and its end comes after its ask. A process of the runtime's own
%% that acts for Caller asks for Caller's (current/0), and Caller's end or
%% restart has no order with that ask: a delivery the restart or the end
%% has ended (abandoned/1), or a Caller that has ended, asks for none;
%% otherwise Caller's restart or end, which the reaper learns of after the
%% ask, cancels the monitor as it cancels Caller's own.
%%
%% The asker is kept beside the monitor, and one that ends otherwise than
%% it returns, a delivery ended with its recipient's run by the clock after
%% the reaper has taken the restart among them, takes the monitor with it
%% (asker_ended/3). A delivery that returns before its starter has taken
%% the restart leaves its monitor standing into the new run: the reaper,
%% the clock and the terminal take a restart each in its own order
%% (fresh_run/0).
monitor_asked(Pid, Caller, Caller, Monitor, Reaper) ->
    monitor_stood(Pid, Caller, Monitor, Reaper);
monitor_asked(Pid, Caller, From, Monitor, Reaper) ->
    case erlang:is_process_alive(From) andalso erlang:is_process_alive(Caller) of
        true ->
            Reaper1 = monitor_stood(Pid, Caller, Monitor#monitor{asker = From}, Reaper),
            asked_by(From, Pid, Caller, Reaper1);
        false ->
            Reaper
    end.

%% Caller's monitor of Pid standing, beside those it made of Pid before:
%% each monitor call is one message (report §6.9). A process the runtime
%% did not start is monitored from here; report §8.6: its death would
%% deliver a message, which is a source while a monitor of it stands.
monitor_stood(Pid, Caller, Monitor, #reaper{monitors = Monitors, monitoring = Monitoring,
                                            monitor_refs = MonitorRefs} = Reaper) ->
    MonitorRefs1 = case ets:lookup(?PROCESSES, Pid) of
                       [] when not is_map_key(Pid, MonitorRefs) ->
                           source_begin(),
                           MonitorRefs#{Pid => erlang:monitor(process, Pid)};
                       _ ->
                           MonitorRefs
                   end,
    Monitors1 = case Monitors of
                    #{Pid := #{Caller := Stood} = ByCaller} ->
                        Monitors#{Pid := ByCaller#{Caller := [Monitor | Stood]}};
                    #{Pid := ByCaller} ->
                        Monitors#{Pid := ByCaller#{Caller => [Monitor]}};
                    #{} ->
                        Monitors#{Pid => #{Caller => [Monitor]}}
                end,
    Reaper#reaper{monitors = Monitors1, monitoring = added(Caller, Pid, Monitoring),
                  monitor_refs = MonitorRefs1}.

%% The asker of a monitor for Caller noted, and monitored from here until
%% it ends, once however many it asks for.
asked_by(Asker, Pid, Caller, #reaper{askers = Askers} = Reaper) ->
    Askers1 = case Askers of
                  #{Asker := {MonitorRef, Asked}} ->
                      Askers#{Asker := {MonitorRef, [{Pid, Caller} | Asked]}};
                  #{} ->
                      MonitorRef = erlang:monitor(process, Asker, [{tag, 'ASKER_DOWN'}]),
                      Askers#{Asker => {MonitorRef, [{Pid, Caller}]}}
              end,
    Reaper#reaper{askers = Askers1}.

%% Report §6.9: an asker that ended. One that returned leaves the monitors
%% it asked for standing, which are Caller's; one that ended otherwise
%% delivered nothing, and the monitors it asked for go, each that still
%% stands, as a caller's go at its end (unmonitored/4).
asker_ended(Asker, normal, #reaper{askers = Askers} = Reaper) ->
    Reaper#reaper{askers = maps:remove(Asker, Askers)};
asker_ended(Asker, _ExitReason, #reaper{askers = Askers} = Reaper) ->
    {_, Asked} = maps:get(Asker, Askers),
    lists:foldl(fun({Pid, Caller}, Acc) -> withdrawn(Pid, Caller, Asker, Acc) end,
                Reaper#reaper{askers = maps:remove(Asker, Askers)}, Asked).

%% Caller's monitors of Pid without those Asker asked for.
withdrawn(Pid, Caller, Asker, #reaper{monitors = Monitors, monitoring = Monitoring,
                                      monitor_refs = MonitorRefs} = Reaper) ->
    case Monitors of
        #{Pid := #{Caller := Stood} = ByCaller} ->
            case [Monitor || #monitor{asker = Asked} = Monitor <- Stood, Asked =/= Asker] of
                [] ->
                    {Monitors1, MonitorRefs1} = unmonitored(Caller, [Pid], Monitors, MonitorRefs),
                    Reaper#reaper{monitors = Monitors1,
                                  monitoring = forgotten(Caller, Pid, Monitoring),
                                  monitor_refs = MonitorRefs1};
                Left ->
                    Reaper#reaper{monitors = Monitors#{Pid := ByCaller#{Caller := Left}}}
            end;
        #{} ->
            Reaper
    end.

%% Report §6.9: Caller's monitors of Pid ended, its service monitors and
%% those asked for it among them, the host's monitor of a process the
%% runtime did not start, of another node among them, demonitored where no
%% other stands; and each Down of Pid on its way to Caller ended before it
%% is placed, waited for, so that none comes after the answer, and one
%% placed already stays: but the delivery that asks, whose wrap is the
%% caller's own code at work, which places its message as it returns. A
%% process Caller does not monitor changes nothing.
demonitored(Pid, Caller, From, Ref, #reaper{monitors = Monitors, monitoring = Monitoring,
                                             monitor_refs = MonitorRefs} = Reaper) ->
    Reaper1 = case Monitors of
                  #{Pid := #{Caller := _}} ->
                      {Monitors1, MonitorRefs1} = unmonitored(Caller, [Pid], Monitors,
                                                              MonitorRefs),
                      Reaper#reaper{monitors = Monitors1,
                                    monitoring = forgotten(Caller, Pid, Monitoring),
                                    monitor_refs = MonitorRefs1};
                  #{} ->
                      Reaper
              end,
    lists:foreach(fun delivery_ended/1,
                  [Key || {_, _, Delivery} = Key <- deliveries({{Caller, '_', '_'}, Pid}),
                          Delivery =/= From]),
    From ! {Ref, demonitored},
    Reaper1.

%% Report §6.9: a restarted process's monitors and its subscriptions to
%% faults and to the program's end are canceled, with what is on its way
%% to it; the monitors of it stand, since a restart is not a death. The
%% process is answered, and once it has emptied its mailbox and ended the
%% calls waiting on it, it asks for its service monitors to be told
%% (tell_service_monitors/0). A subscription to the end its new run makes
%% is a new one, which the end tells if it waits (told/3).
new_run(Pid, Ref, Reaper) ->
    ets:delete(?FAULTS, Pid),
    ets:delete(?TERMINATING, Pid),
    Reaper1 = monitors_canceled(Pid, Reaper),
    abandoned(Pid),
    Pid ! {Ref, fresh},
    Reaper1.

%% Report §6.9: each service monitor of a process that restarts told, the
%% reason Restarted and the site the process's spawn site, as at its end,
%% and left standing, the delivery of each answered, which the process
%% asks for once its mailbox is emptied (tell_service_monitors/0), its own
%% monitors canceled before (new_run/3); a monitor that is no service
%% monitor is told nothing. Report §8.7: a monitor of a process of
%% another node is the host's, made by the watcher's node, which no restart
%% here reaches.
delivered_restart(Pid, #reaper{monitors = Monitors}) ->
    case service_monitors_of(Pid, Monitors) of
        [] ->
            [];
        ServiceMonitors ->
            Site = case ets:lookup(?PROCESSES, Pid) of
                       [#process_row{site = SpawnSite}] -> SpawnSite;
                       [] -> <<>>
                   end,
            Down = {'Down', Pid, 'Restarted', Site},
            [wrapped(Caller, Wrap, Down) || {Caller, Wrap} <- ServiceMonitors]
    end.

%% A caller's own monitors canceled, taken from the processes it
%% monitored: at its restart (new_run/3), and at the end of a process of
%% the runtime's own the reaper holds, a teller's (held_ended/3).
monitors_canceled(Caller, #reaper{monitors = Monitors, monitoring = Monitoring,
                                  monitor_refs = MonitorRefs} = Reaper) ->
    {Monitors1, MonitorRefs1} = unmonitored(Caller, maps:keys(maps:get(Caller, Monitoring, #{})),
                                            Monitors, MonitorRefs),
    Reaper#reaper{monitors = Monitors1, monitoring = maps:remove(Caller, Monitoring),
                  monitor_refs = MonitorRefs1}.

%% A process that ended: each monitor of it told, the monitors of it, and
%% its own, gone, and the deliveries to it ended (abandoned/1).
down(Pid, ExitReason, #reaper{monitors = Monitors, monitoring = Monitoring,
                              monitor_refs = MonitorRefs} = Reaper) ->
    unoffered(Pid),
    drop_callee_notes(Pid, ExitReason),
    delivered_down(Pid, ExitReason, Reaper),
    abandoned(Pid),
    case is_map_key(Pid, Monitors) orelse is_map_key(Pid, Monitoring)
        orelse is_map_key(Pid, MonitorRefs) of
        false ->
            %% nothing monitored it, and it monitored nothing
            Reaper;
        true ->
            Monitoring1 = lists:foldl(fun(Caller, Acc) -> forgotten(Caller, Pid, Acc) end,
                                      maps:remove(Pid, Monitoring),
                                      maps:keys(maps:get(Pid, Monitors, #{}))),
            {Monitors1, MonitorRefs1} = unmonitored(Pid, maps:keys(maps:get(Pid, Monitoring, #{})),
                                                    maps:remove(Pid, Monitors),
                                                    maps:remove(Pid, MonitorRefs)),
            Reaper#reaper{monitors = Monitors1, monitoring = Monitoring1,
                          monitor_refs = MonitorRefs1}
    end.

%% Each monitor of a process that ended told how. A process that ended
%% leaves no call: one that faulted or restarted while it waited ended its
%% call as it left the wait, one the runtime killed had it ended first
%% (killed/2), and one the host ended has it ended here (left_call/1); a
%% caller learns of a callee's end by its own monitor, and removes its own.
%% Report §6.9: the spawn site of a process the runtime did not start, or
%% of one that had ended, is not known.
delivered_down(Pid, ExitReason, #reaper{monitors = Monitors, monitor_refs = MonitorRefs}) ->
    case ets:take(?PROCESSES, Pid) of
        [#process_row{site = Site, peer = Peer, expected = Expected, fault = Fault}] ->
            is_host_end(ExitReason) andalso left_call(Pid),
            died(Pid, Site, Peer, Expected, ExitReason, Fault),
            Down = {'Down', Pid, reason(ExitReason), Site},
            lists:foreach(fun({Caller, {raw, Tag}}) -> Caller ! {Tag, Site, ExitReason};
                             ({Caller, Wrap}) -> wrapped(Caller, Wrap, Down)
                          end, monitors_of(Pid, Monitors));
        [] ->
            Down = {'Down', Pid, reason(ExitReason), <<>>},
            lists:foreach(fun({Caller, Wrap}) -> wrapped(Caller, Wrap, Down) end,
                          monitors_of(Pid, Monitors)),
            is_map_key(Pid, MonitorRefs) andalso source_end()
    end.

%% Report §8.6: "Once the wait is over, and from the entry process's death
%% where no subscriber waits", a process that faults before it is ended
%% dies with the reason ProgramEnd, and its fault is not reported (§11.2);
%% while the end waits, a fault is the process's own. Whether a fault of
%% Pid is so: the entry process's own fault is its own; the runner marks
%% the wait over once the end's wait has returned (run_main/3); and a
%% subscription's row stands while its subscriber's run lives (died/6,
%% new_run/3), so that with none standing no subscriber waits. The process
%% that faults asks it as it meets the fault, so that the answer is the
%% fault's moment's: a process's body (run/1), a restarting process before
%% it restarts (restarts/4) and a compute's process before it answers
%% (answered_compute/2). Report §11.2: a fault met before the entry's end
%% is reported however late the reaper learns of it, behind the entry's
%% end among them, and one the entry's end causes is met after it.
is_program_ending(Pid) ->
    case ets_lookup(?LAUNCH, entry_process) of
        [{_, Pid}] ->
            false;
        [{_, Entry}] ->
            is_wait_over() orelse
                (ets:info(?TERMINATING, size) =:= 0 andalso not erlang:is_process_alive(Entry));
        [] ->
            is_wait_over()
    end.

is_wait_over() ->
    ets_lookup(?LAUNCH, wait_over) =/= [].

%% Report §8.6, §11.2: a deadlock is the entry process's fault, or under
%% `ern test` the fault of the test that runs; the processes it leaves
%% waiting are kept for its report beside it (left_waiting/1).
deadlock() ->
    case ets:take(?LAUNCH, deadlock_victim) of
        [{_, Victim}] ->
            ets:insert(?LAUNCH, {{left_waiting, Victim}, left_waiting_lines(Victim)}),
            found_fault(Victim, <<"deadlock">>);
        [] ->
            Entry = entry_process(),
            ets:insert(?LAUNCH, {{left_waiting, Entry}, left_waiting_lines(Entry)}),
            {Runner, Launch} = launch_runner(),
            Runner ! {deadlock, Launch}
    end.

%% Report §8.6, §11.2: the processes a deadlock leaves waiting but the one
%% it faults, whose trace says where it waits, and the entry process,
%% which under `ern test` is the toolchain's own and runs the tests, the
%% one faulted being a test's: a line for each group with
%% one spawn site and one waiting frame, with their count, ordered by
%% their sites and then by their frames, each by its name's code points and
%% then by its line as a number (by_line/1), `3 processes of
%% Dinner.table:40 wait in Dinner.take:112`, the frame the first of the
%% program's in the process's stack, as its trace would begin (trace/1).
%% The stacks are read once the look has found the deadlock, while every
%% process still waits, so that nothing is added to any operation's path;
%% who waits for whom is not read.
left_waiting_lines(Victim) ->
    Entry = entry_process(),
    Waiting = [{Site, waiting_frame(Pid)} || #process_row{pid = Pid, site = Site} <- live_rows(),
                                            Pid =/= Victim, Pid =/= Entry],
    Counted = lists:foldl(fun(Group, Acc) -> maps:update_with(Group, fun(Count) -> Count + 1 end,
                                                             1, Acc)
                          end, #{}, Waiting),
    Ordered = lists:sort(fun(Group, Other) -> by_line(Group) =< by_line(Other) end,
                         maps:keys(Counted)),
    [left_waiting_line(maps:get(Group, Counted), Site, Frame) || {Site, Frame} = Group <- Ordered].

%% Report §8.6: a group of a site and a frame as the lines are ordered by
%% it, each by its name, whose bytes are in the order of its code points,
%% and then by its line as a number; one without a line, and no frame,
%% first.
by_line({Site, Frame}) ->
    {numbered(Site), numbered(Frame)}.

numbered(none) ->
    {<<>>, 0};
numbered(Text) ->
    case string:split(Text, ":", trailing) of
        [Name, Line] when Line =/= <<>> ->
            case lists:all(fun(Char) -> Char >= $0 andalso Char =< $9 end, binary_to_list(Line)) of
                true -> {Name, binary_to_integer(Line)};
                false -> {Text, 0}
            end;
        _ ->
            {Text, 0}
    end.

waiting_frame(Pid) ->
    case erlang:process_info(Pid, current_stacktrace) of
        {current_stacktrace, Stack} ->
            case binary:split(trace(Stack), <<"\n">>) of
                [<<>> | _] -> none;
                [Frame | _] -> Frame
            end;
        undefined ->
            none
    end.

left_waiting_line(Count, Site, Frame) ->
    Waits = case Count of
                1 -> [<<"1 process of ">>, Site, <<" waits">>];
                _ -> [integer_to_binary(Count), <<" processes of ">>, Site, <<" wait">>]
            end,
    In = case Frame of
             none -> [];
             _ -> [<<" in ">>, Frame]
         end,
    ern_show:controls(iolist_to_binary([Waits, In]), line).

%% Report §8.6, §11.2: the lines of the processes the deadlock that faulted
%% Pid left waiting, taken, which its report writes beneath its trace; none
%% for any other fault.
-spec left_waiting(pid()) -> [binary()].
left_waiting(Pid) ->
    try ets:take(?LAUNCH, {left_waiting, Pid}) of
        [{_, Lines}] -> Lines;
        [] -> []
    catch error:badarg ->
        []
    end.

%% Appendix E.22: the spawn order of the next process the reaper starts or
%% adopts, which grows with each, so that processes are in the order they
%% were spawned.
next_spawn_order() ->
    erlang:unique_integer([monotonic, positive]).

%% Report §8.6: the program's end ends every process the runtime started.
%% The reaper spawns each, so it ends them: every one it has spawned, and
%% none after, since a spawn it is asked for then was asked by a process
%% that is itself ending. It answers nothing more until it is stopped.
ended_program(From, Ref) ->
    Ended = [Pid || #process_row{pid = Pid} <- live_rows()],
    lists:foreach(fun(Pid) -> exit(Pid, {ern, program_end}) end, Ended),
    %% report §8.6, §8.7: the end waits for the deaths of every process
    %% but those that trap exits, the runtime's own resources, so that no
    %% process of this launch faults, restarts or reports into the next
    %% one, and on a node every Down already on its way crosses before its
    %% connections close, the deaths its peers may watch among them (§3.11)
    wait_for_ends(maps:from_keys([Pid || Pid <- Ended, not traps_exits(Pid)], true)),
    From ! {Ref, ended},
    ended_program().

traps_exits(Pid) ->
    erlang:process_info(Pid, trap_exit) =:= {trap_exit, true}.

%% The deaths of the processes still waited for, each a Down the reaper's
%% monitor gives, in the order they come: a compute's told to its caller
%% (§8.7). A process already dead has its Down in the mailbox or on its way.
wait_for_ends(Waiting) when map_size(Waiting) =:= 0 ->
    ok;
wait_for_ends(Waiting) ->
    receive
        {'DOWN', _, process, Pid, ExitReason} when is_map_key(Pid, Waiting) ->
            drop_callee_notes(Pid, ExitReason),
            wait_for_ends(maps:remove(Pid, Waiting))
    end.

ended_program() ->
    receive _ -> ended_program() end.

%% Sets, a map to sets, each a map to true, with Value put in Key's set:
%% a process a caller monitors, among the processes it monitors; the
%% clock's timer, among its recipient's.
added(Key, Value, Sets) ->
    case Sets of
        #{Key := Set} -> Sets#{Key := Set#{Value => true}};
        #{} -> Sets#{Key => #{Value => true}}
    end.

%% Sets, with Gone taken from Key's set, and Key gone with the set's last:
%% a process that ended, from the processes its caller monitors; the
%% clock's timer that fired, from its recipient's.
forgotten(Key, Gone, Sets) ->
    case Sets of
        #{Key := #{Gone := _} = Set} when map_size(Set) =:= 1 -> maps:remove(Key, Sets);
        #{Key := Set} -> Sets#{Key := maps:remove(Gone, Set)};
        #{} -> Sets
    end.

%% The monitors of Pid, each {Caller, Wrap}.
monitors_of(Pid, Monitors) ->
    [{Caller, Wrap} || Caller := Stood <- maps:get(Pid, Monitors, #{}),
                       #monitor{wrap = Wrap} <- Stood].

%% The service monitors of Pid, each {Caller, Wrap}.
service_monitors_of(Pid, Monitors) ->
    [{Caller, Wrap} || Caller := Stood <- maps:get(Pid, Monitors, #{}),
                       #monitor{wrap = Wrap, service = true} <- Stood].

%% The monitors of a caller that died, taken from the processes it
%% monitored. A process the runtime did not start that no monitor stands of
%% any longer is no longer monitored, and no longer a source (report
%% §8.6).
unmonitored(_Caller, [], Monitors, MonitorRefs) ->
    {Monitors, MonitorRefs};
unmonitored(Caller, [Pid | Rest], Monitors, MonitorRefs) ->
    Left = maps:remove(Caller, maps:get(Pid, Monitors, #{})),
    case map_size(Left) of
        0 when is_map_key(Pid, MonitorRefs) ->
            erlang:demonitor(maps:get(Pid, MonitorRefs), [flush]),
            source_end(),
            unmonitored(Caller, Rest, maps:remove(Pid, Monitors), maps:remove(Pid, MonitorRefs));
        0 ->
            unmonitored(Caller, Rest, maps:remove(Pid, Monitors), MonitorRefs);
        _ ->
            unmonitored(Caller, Rest, Monitors#{Pid => Left}, MonitorRefs)
    end.

%% Report §6.9, §6.5: a monitor's wrap is applied as `adapted`'s function is, a
%% fault in it being the fault of the process it delivers to, and in a
%% process of its own, so that a wrap that does not finish holds up no
%% other delivery. The message counts as a source until it is delivered
%% (§8.6). Linked, so that one that never finishes ends with the program.
wrapped(Caller, Wrap, {'Down', Of, _, _} = Down) ->
    counted_link(Caller, fun() -> deliver(adapted(Caller, Wrap), Down) end, Of).

%% Report §8.6: a process that will deliver a message to the process behind
%% Address, counted as a source from before it starts until its work is done,
%% and linked, so that one that never finishes ends with the process that
%% started it, the reaper, the clock or the end's teller, each of which
%% traps its exit (reaper/0, clock/1, tell/4), and the first two of which
%% live the run long. Report §6.9: it acts for its recipient (acting_for/1),
%% so that what the function it applies opens, spawns or asks of the
%% runtime is the recipient's, and Process.current there is the recipient.
%% It is noted against its recipient and the process that started it, and
%% ended when the recipient restarts or ends (abandoned/1); one whose
%% recipient has ended already, an alarm's that fires after its process's
%% end among them, ends before it starts with every delivery to that
%% recipient, the row written first, so that an end the reaper learns of
%% after the look finds it. A delivery of a Down names the process that
%% ended or restarted, Of, which a demonitor reads (demonitored/5), and
%% any other none.
counted_link(Address, Work) ->
    counted_link(Address, Work, none).

counted_link(Address, Work, Of) ->
    Recipient = process_of(Address),
    Starter = erlang:self(),
    Pid = erlang:spawn_link(fun() ->
                                acting_for(Recipient),
                                receive go -> Work(), delivered(Recipient, Starter) end
                            end),
    try ets:insert(?DELIVERIES, {{Recipient, Starter, Pid}, Of}) catch _:_ -> true end,
    source_begin(Pid),
    case node(Recipient) =:= node() andalso not erlang:is_process_alive(Recipient) of
        true -> abandoned(Recipient);
        false -> Pid ! go
    end,
    Pid.

delivered(Recipient, Starter) ->
    try ets:delete(?DELIVERIES, {Recipient, Starter, erlang:self()}) catch _:_ -> true end,
    source_end().

%% Report §8.6: a process of the runtime's own that the calling process
%% holds, ended, and whether it was a delivery that delivered nothing. One
%% that returned, a delivery done, a process kept for an address told to
%% stop or a teller with its word, has taken its own rows. One that ended
%% otherwise, killed from foreign code, delivered nothing: it is no source
%% any more, and its row of deliveries goes. The row is found by a read of
%% the deliveries on their way, which an end of this kind alone pays; one a
%% delivery's recipient ended, or a restart of it, has had its rows taken
%% already (abandoned/1), and one that is no delivery has none, which its
%% source's row says. Report §6.6, §8.7: a call its function was making
%% where the host ended it goes with it, as a call of a program's process
%% the host ends does (left_call/1); one the runtime ended, a delivery
%% ended with its recipient among them, had its call dropped first
%% (killed/2).
undelivered(_Pid, normal) ->
    false;
undelivered(Pid, ExitReason) ->
    is_host_end(ExitReason) andalso left_call(Pid),
    try ets:take(?HELD, {source, Pid}) of
        [] ->
            false;
        _ ->
            ets:match_delete(?DELIVERIES, {{'_', erlang:self(), Pid}, '_'}),
            true
    catch _:_ ->
        false
    end.

%% Report §6.9, §8.6: a process of the runtime's own the reaper holds that
%% ended (reaper_held/2): what it delivered nothing of is no source any
%% more (undelivered/2), the deliveries to it end with it, and the monitors
%% it made go, as a caller's go at its end, a teller's of its subscriber. A
%% call it was making the runtime ended as it killed it (killed/2), or ends
%% here where the host ended it (undelivered/2).
held_ended(Pid, ExitReason, Reaper) ->
    _ = undelivered(Pid, ExitReason),
    abandoned(Pid),
    monitors_canceled(Pid, Reaper).

%% Report §6.9: every delivery to Recipient, whichever process started it,
%% the reaper, the clock or one of the end's tellers, ended, each waited
%% for: once Recipient has ended, since a delivery to a process that has
%% ended ends with it, one whose wrap does not finish among them, and when
%% it restarts, so that none reaches the new run. The reaper ends them where
%% it learns of an end, of a process it started, adopted, monitors or
%% watches, or holds, and where it is asked at a restart (new_run/3); the
%% clock ends them too where it is asked, so that a delivery it started as
%% the reaper was asked is ended (alarms_canceled/2). A process kept for an
%% adapted address (kept/1) is no delivery to its target, and runs on.
%% Their rows are read by their key's prefix, the recipient, which the
%% ordered table reads as one range, and each delivery's rows are taken
%% first, so that the process that started it, told of its end, finds none
%% to take (undelivered/2); it is unlinked first where this process
%% started it, so that it is told nothing. Report §6.6: a call the
%% delivery's function was making ends with it, as a killed process's does
%% (killed/2).
abandoned(Recipient) ->
    lists:foreach(fun delivery_ended/1, deliveries({{Recipient, '_', '_'}, '_'})).

%% The keys of the deliveries whose rows match Pattern, which names their
%% recipient, so that the ordered table reads them as one range.
deliveries(Pattern) ->
    try ets:select(?DELIVERIES, [{Pattern, [], [{element, 1, '$_'}]}])
    catch _:_ -> []
    end.

%% A delivery ended and waited for, its rows taken first, by the runtime's
%% kill, which drops the call it was making (killed/2), so that the process
%% that started it, told of the end, reads no call of it (undelivered/2).
delivery_ended({_, Starter, Pid} = Delivery) ->
    try
        ets:delete(?DELIVERIES, Delivery),
        ets:delete(?HELD, {source, Pid})
    catch _:_ ->
        true
    end,
    MonitorRef = erlang:monitor(process, Pid),
    Starter =:= erlang:self() andalso erlang:unlink(Pid),
    killed(Pid, {ern, killed}),
    receive {'DOWN', MonitorRef, process, Pid, _} -> ok end.

%% Report §11.2: the shell writes, before it ends, every fault reported to
%% it until then, which a delivery of the runtime's own carries to it
%% (report/5). The calling process waits until each delivery to it on its
%% way as the wait begins has ended: each its rows name then is monitored
%% and its end waited for. A delivery sends its message before it takes its
%% row and ends, so that every message one carried is in the caller's
%% mailbox when the wait returns (§6.4). One started after the wait began
%% is not waited for, so that a process faulting again and again as the
%% shell ends, under `restarting(Unlimited, f)`, does not hold up its end.
%% Report §8.6: the caller waits on what the look cannot see deliver, a
%% process of the runtime's own, and is marked so (entered_foreign/0).
-spec wait_for_deliveries() -> ok.
wait_for_deliveries() ->
    entered_foreign(),
    try waited_deliveries(deliveries({{erlang:self(), '_', '_'}, '_'})) after left_foreign() end.

waited_deliveries(Deliveries) ->
    lists:foreach(fun({_, _, Pid}) ->
                      MonitorRef = erlang:monitor(process, Pid),
                      receive {'DOWN', MonitorRef, process, Pid, _} -> ok end
                  end, Deliveries).

%% The live processes the runtime started or adopted, with their spawn
%% sites.
live() ->
    try [{Pid, Site} || #process_row{pid = Pid, site = Site} <- live_rows()]
    catch _:_ -> []
    end.

%% Report §11.2, §6.9: the live processes Root started, directly or through
%% one it started, whether that one lives or not, each with its spawn site,
%% in the order they were spawned: those whose root is Root, which the
%% shell's refused load kills. Root itself is not among them.
-spec started_by(pid() | reference()) -> [{pid(), binary()}].
started_by(Root) ->
    Rows = try ets:match_object(?PROCESSES, #process_row{root = Root, _ = '_'})
           catch error:badarg -> []
           end,
    [{Pid, Site} || {_, Pid, Site} <- lists:sort([{Order, Pid, Site}
                                                  || #process_row{pid = Pid, site = Site,
                                                                  spawn_order = Order} <- Rows]),
                    Pid =/= Root, erlang:is_process_alive(Pid)].

%% Report §11.2, §6.9, Appendix E.28: the processes each of Roots started,
%% directly or through one it started (started_by/1), killed and waited for,
%% each root's in the order they were spawned, and their spawn sites; asked
%% again once they have ended, since one may start another before its kill
%% reaches it, until none is left. A refused load of the shell's and of
%% Code.load undoes what its evaluation started so; the caller, which
%% Code.load's evaluation ran in under the mark, is not among them.
-spec kill_started([pid() | reference()]) -> [binary()].
kill_started(Roots) ->
    case [Process || Root <- Roots, {Pid, _} = Process <- started_by(Root),
                     Pid =/= erlang:self()] of
        [] ->
            [];
        Started ->
            kill_all([Pid || {Pid, _} <- Started]),
            [Site || {_, Site} <- Started] ++ kill_started(Roots)
    end.

%% Report §6.9: each process killed, and waited for, so that a refused
%% load answers once what it killed has ended (§11.2).
-spec kill_all([pid()]) -> ok.
kill_all(Pids) ->
    MonitorRefs = [erlang:monitor(process, Pid) || Pid <- Pids],
    lists:foreach(fun(Pid) -> killed(Pid, {ern, killed}) end, Pids),
    lists:foreach(fun(MonitorRef) -> receive {'DOWN', MonitorRef, process, _, _} -> ok end end,
                  MonitorRefs).

%% Appendix E.28, report §11.2: the calling process made the head of a
%% spawn chain of its own while Code.load evaluates bindings in it, under a
%% mark, so that what the evaluation starts, directly or through a process
%% it started, is known by the mark (started_by/1) and not mixed with what
%% the caller started before; the mark and the root the caller had, which
%% rooted/2 gives back. A process the runtime did not start heads no chain,
%% and is given none. Report §6.9: a process of the runtime's own that acts
%% for another (acting_for/1) heads it in what stands for its row, and not
%% the process it acts for, which runs on beside it: its own spawns take the
%% mark (parent/0), and the root it had is the mark of the load it was
%% evaluating, or else the root of the process it acts for, which a load of
%% that process's own may give back meanwhile; one that acts for a process
%% the runtime did not start heads no chain either.
-spec rooting() -> {reference(), pid() | reference() | none}.
rooting() ->
    Mark = make_ref(),
    case erlang:get(?ACTING) of
        undefined ->
            case ets_lookup(?PROCESSES, erlang:self()) of
                [#process_row{root = Root}] ->
                    true = ets:update_element(?PROCESSES, erlang:self(),
                                              {#process_row.root, Mark}),
                    {Mark, Root};
                _ ->
                    {Mark, none}
            end;
        #acting{recipient = Recipient, marks = Marks} = Acting ->
            case {Marks, ets_lookup(?PROCESSES, Recipient)} of
                {[Inner | _], _} ->
                    _ = erlang:put(?ACTING, Acting#acting{marks = [Mark | Marks]}),
                    {Mark, Inner};
                {[], [#process_row{root = Root}]} ->
                    _ = erlang:put(?ACTING, Acting#acting{marks = [Mark]}),
                    {Mark, Root};
                {[], _} ->
                    {Mark, none}
            end
    end.

%% Appendix E.28, report §11.2: the root the calling process had given back
%% once a load's evaluation is over, to it and to every process the
%% evaluation started that lives, so that a root the caller belongs to,
%% the shell's load's among them, knows them as its own (started_by/1). The
%% reaper rewrites their rows between two spawns, so that no process started
%% meanwhile keeps the mark.
-spec rooted(reference(), pid() | reference() | none) -> ok.
rooted(_Mark, none) ->
    ok;
rooted(Mark, Root) ->
    case erlang:get(?ACTING) of
        undefined ->
            true = ets:update_element(?PROCESSES, erlang:self(), {#process_row.root, Root});
        #acting{marks = [Mark | Marks]} = Acting ->
            _ = erlang:put(?ACTING, Acting#acting{marks = Marks})
    end,
    Ref = make_ref(),
    launch_reaper() ! {rooted, erlang:self(), Ref, Mark, Root},
    receive
        {Ref, rooted} -> ok
    end.

%% Appendix E.21: Process.live, the live processes the runtime started or
%% adopted, the system processes excepted, which are the runtime's.
%% Report §11.2: in a launch with processes of its own, the shell's, those
%% are left out: the entry process's chain, and the processes the launch's
%% function answers, the evaluators and the process of the input that
%% asks.
-spec processes() -> [pid()].
processes() ->
    case launch_field(#launch.own, none) of
        none ->
            [Pid || {Pid, _} <- live()];
        Own ->
            Entry = entry_process(),
            Owned = Own(),
            [Pid || #process_row{pid = Pid, root = Root} <- live_rows(), Root =/= Entry,
                    not lists:member(Pid, Owned)]
    end.

%% Appendix E.21: Process.status, a snapshot of a live process, None once it
%% has ended and for a process on another node. A process waiting for a
%% call's answer is Calling, which the host's status does not tell from a
%% receive: it keeps its call under its CALL key (§6.6).
-spec status(pid()) -> 'None' | {'Some', {'Status', binary(), non_neg_integer(), atom()}}.
status(Pid) when node(Pid) =:= node() ->
    case {ets_lookup(?PROCESSES, Pid),
          erlang:process_info(Pid, [status, message_queue_len, {dictionary, ?CALL}])} of
        {[#process_row{site = Site}],
         [{status, HostStatus}, {message_queue_len, Queued}, {_, Call}]} ->
            Activity = case {HostStatus, Call} of
                           {waiting, undefined} -> 'Receiving';
                           {waiting, _} -> 'Calling';
                           _ -> 'Running'
                       end,
            {'Some', {'Status', Site, Queued, Activity}};
        _ ->
            'None'
    end;
status(_) ->
    'None'.

ets_lookup(Table, Key) ->
    try ets:lookup(Table, Key) catch _:_ -> [] end.

%% The rows of Table that match Pattern, none where the table has gone.
matching_rows(Table, Pattern) ->
    try ets:match_object(Table, Pattern) catch _:_ -> [] end.

%% Appendix E.21: Process.faults, the caller subscribed to every fault of
%% every process the runtime started, Address being the caller seen through its
%% wrap. A process holds one subscription, the latest, which ends when it
%% dies (the reaper's DOWN).
-spec faults(address()) -> 'Unit'.
faults(Address) ->
    try ets:insert(?FAULTS, {process_of(Address), Address}) catch _:_ -> true end,
    ?UNIT.

%% Appendix E.23, report §8.6: Os.termination, the caller subscribed to the
%% program's end, Address being the caller seen through its wrap. A process
%% holds one subscription, the latest, which ends when it dies or restarts
%% (died/6, new_run/3); a later one in the same run takes the place of the
%% first and keeps whether the end has told the run. One made while the end
%% waits is told at once: the runner that waits is told of it, and tells it.
-spec termination(address()) -> 'Unit'.
termination(Address) ->
    Subscriber = process_of(Address),
    try ets:update_element(?TERMINATING, Subscriber, {2, Address})
            orelse ets:insert(?TERMINATING, {Subscriber, Address, false})
    catch _:_ -> true
    end,
    case ets_lookup(?LAUNCH, ending) of
        [{ending, Runner, Launch}] -> Runner ! {subscribed, Launch, Subscriber};
        [] -> ok
    end,
    ?UNIT.

%% Report §11.2, Appendix E.21: a fault, which each subscriber is sent as a
%% FaultReport, each delivery a process of its own as a monitor's is, and
%% which `ern run`'s reporter, the runtime's own subscriber, is given as it
%% happens, before the process's end reaches anyone who waits on it, with
%% the node of the peer whose spawn started the process, which its line
%% names (§8.7), or none. The fields are in declared order: process, site,
%% cause, restarted, trace, the peer's name as the configuration lists it
%% (§8.7), the site of the callee whose fault a call carried (§6.6), the
%% name of the peer a compute carried it from (§8.7), and the moment it
%% was met (Appendix E.15). The reaper reports, so that a delivery is
%% linked to a process that lives as long as the run; a process that
%% restarts sends it its fault.
report(Pid, Site, Peer, #fault{cause = Cause, trace = Trace, callee = Callee, peer = From,
                               time = Time}, Restarted) ->
    Report = {'FaultReport', Pid, Site, Cause, Restarted, Trace, ern_peer:name(Peer),
              optional(Callee), optional(From), Time},
    case launch_field(#launch.reporter, none) of
        none -> ok;
        Reporter -> Reporter(Report, Peer)
    end,
    Subscribers = [Address || {_, Address} <- matching_rows(?FAULTS, '_')],
    lists:foreach(fun(Address) ->
                      counted_link(Address, fun() -> deliver(Address, Report) end)
                  end, Subscribers).

optional(none) -> 'None';
optional(Value) -> {'Some', Value}.

%% The live processes' rows (#process_row{}).
live_rows() ->
    ets:tab2list(?PROCESSES).

%% Report §8.7: a compute's process named by its note before it runs, its
%% row of CALLEES first, so that the call's second note, which the gateway
%% may read meanwhile, finds the process by the note and kills it; where
%% the note has gone, the second note read or the connection lost, or was
%% never written, the compute having come between two launches, the
%% process does not run. Any other process runs.
is_noted({compute, _, Caller, Alias}, Pid) ->
    ets:insert(?CALLEES, {{Pid, Caller}, {compute, Alias}}),
    case ets:update_element(?NOTES, {node(Alias), Alias}, {2, Pid}) of
        true ->
            true;
        false ->
            ets:delete(?CALLEES, {Pid, Caller}),
            false
    end;
is_noted(_, _) ->
    true.

%% Report §8.7: what a compute's process runs: the function, whose value
%% goes to the caller through its alias once the process has let its note
%% go, as an answer given here does; a fault in it goes there too, its
%% #fault{}, and the process dies of it, its row marking the fault carried,
%% so that this node reports nothing of it (died/6). Where the
%% note has gone already, the call over or the connection lost, no caller
%% waits: nothing is answered, and a fault is this node's, reported as any
%% process's is. Report §8.6: a fault as the program ends ends the process
%% with the program, whose end tells the caller (ended_program/2).
computing(Function, Alias) ->
    fun() ->
        Answer = try {computed, Function()}
                 catch Class:Error:Stack -> {faulted, met(Class, Error, Stack)}
                 end,
        answered_compute(Answer, Alias)
    end.

answered_compute({computed, Value}, Alias) ->
    dropped_note(Alias) andalso erlang:send(Alias, {Alias, computed, Value}),
    ok;
answered_compute({faulted, Fault}, Alias) ->
    is_program_ending(erlang:self()) andalso end_with_program(),
    case dropped_note(Alias) of
        true ->
            Alias ! {Alias, faulted, Fault},
            throw({ern, carried, Fault});
        false ->
            throw({ern, Fault})
    end.

%% Report §6.9, §11.2: a process that ended faulting is reported, and a
%% subscription to faults or to the program's end it held ends with it.
%% Report Appendix E.24: a process `Test.faults` started, whose fault is
%% expected, is reported to no job and told no subscriber, since the
%% test's answer carries it.
died(Pid, Site, Peer, Expected, ExitReason, Fault) ->
    ets:delete(?FAULTS, Pid),
    ets:delete(?TERMINATING, Pid),
    case {Fault, reason(ExitReason), Expected} of
        %% report §8.7: a fault a compute carried to its caller is reported
        %% once, on the caller's node, and told no subscriber here
        {carried, _, _} -> ok;
        {_, {'Fault', Cause}, false} -> report(Pid, Site, Peer, ended_fault(Fault, Cause), false);
        _ -> ok
    end.

%% The fault a process ended with, its row's, written as it ended
%% (ended_with/2); and report §6.9: one the host ended met no fault, its
%% cause the host's reason, its trace empty, and its moment the reaper's.
ended_fault(#fault{} = Fault, _) -> Fault;
ended_fault(none, Cause) -> #fault{cause = Cause, trace = <<>>, time = now()}.

%% Report Appendix E.24: the function a process `Test.faults` starts runs,
%% which marks the process's row expected before it runs Function, so
%% that its fault reaches no job's report and no subscriber (died/6): the
%% mark the runtime's, set as the process begins, and no text of its site.
-spec expected(fun(() -> term())) -> fun(() -> term()).
expected(Function) ->
    fun() ->
        true = ets:update_element(?PROCESSES, erlang:self(), {#process_row.expected, true}),
        Function()
    end.

%% Report §8.6. Two reads of every live process's status and reduction
%% count, equal, with every status waiting, prove that nothing ran between
%% them; what can still deliver is read between them, so that it is what
%% held while nothing ran, and not what held before a process ran on. A
%% source held by a system process, a subscription to the program's end, a
%% call waiting on a system process, and a process that waits where Ernest
%% does not are what can still deliver.
%%
%% The check runs when the reaper has been idle a while, and what can still
%% deliver is read first, the cheapest first: an idle program that waits on
%% something, a socket or an alarm, is answered from a few rows; then each
%% process's status and reductions, which the host reads without asking the
%% process; and only where every process waits is each process asked where
%% it waits and what it keeps under the look's keys (still/1). The host
%% counts that question as a reduction of the process once it has answered
%% it, so it is the second read, and its reductions are compared with the
%% first's.
%%
%% A system process is not in the table, so its mailbox and status are read
%% as well: between taking a message out and counting the source it holds,
%% it is running rather than waiting, and the check sees that. A request a
%% program sends to it is a call, which the sender keys before it sends the
%% request (calling_the_system/2), since a request still in transit is not
%% seen at its receiver. The reaper is the process making the check, so its
%% own mailbox is what is read of it. §8.6 leaves a foreign process that
%% can deliver to the runtime. Report §11.2: nothing is a deadlock while a
%% shell holds the terminal; and report §8.6, nothing on a node, which can
%% be reached from outside. Report §8.6, Appendix E.23: a subscription to
%% the program's end can still deliver while it stands, since a termination
%% tells it, as a system process's subscription can; while the end waits
%% for a subscriber, that subscriber's stands, so nothing is a deadlock
%% then either.
%%
%% What the look finds: `delivering`, where something can still deliver, a
%% shell holds the terminal, or the program is a node, so that no deadlock
%% can begin before that ends; `running`, where nothing can and a process
%% is not waiting, or none is left; `deadlock`, where nothing can and every
%% process waits as Ernest waits.
look() ->
    case terminal_holder() =:= undefined andalso not launch_field(#launch.node, false)
         andalso nothing_delivers() of
        false ->
            delivering;
        true ->
            First = snapshot([Pid || #process_row{pid = Pid} <- live_rows()]),
            Waits = First =/= []
                andalso lists:all(fun({_, Status, _}) -> Status =:= waiting end, First)
                andalso nothing_delivers(),
            case Waits of
                true -> still(First);
                false -> running
            end
    end.

nothing_delivers() ->
    sources() =:= 0
        andalso ets:info(?TERMINATING, size) =:= 0
        andalso quiet_system().

%% Report §8.6, §6.3, §6.6, §8.4: each process asked, the second read,
%% whether it still waits as the first read found it and waits as Ernest
%% waits: in a function of Ernest's own code (is_ernest/1), with nothing
%% under the look's keys that can still deliver, no deadline, no foreign
%% code and no call to a system process, a listener, a socket or a running
%% program (calling_the_system/2), whose processes are read once for the
%% look; a key read here held between the two reads, since the process has
%% not run since the first. A function of the host's on top is a receive
%% inside foreign code. The first that cannot be a deadlock's answers for
%% the look.
still(First) ->
    still(First, system_pids() ++ opened()).

still([], _) ->
    deadlock;
still([{Pid, _, Reductions} | First], Held) ->
    case erlang:process_info(Pid, [status, reductions, current_function, {dictionary, ?FOREIGN},
                                   {dictionary, ?TIMED}, {dictionary, ?CALL}]) of
        [{status, waiting}, {reductions, Reductions}, {current_function, {Module, _, _}},
         {_, undefined}, {_, undefined}, {_, Call}] ->
            case not calling_the_system(Call, Held) andalso is_ernest(Module) of
                true -> still(First, Held);
                false -> delivering
            end;
        [{status, waiting}, {reductions, Reductions} | _] ->
            delivering;
        _ ->
            running
    end.

%% Report §8.6: whether a module is Ernest's own code: a unit, which exports
%% '$code'/0 as every unit the toolchain makes does, and by which the code
%% table takes one (ern_code:loaded/3), or a module of the toolchain's own
%% Erlang (own_modules/0). Every other module is the host's, foreign code's
%% and a standard library function's host work among them.
is_ernest(Module) ->
    erlang:function_exported(Module, '$code', 0) orelse is_map_key(Module, own_modules()).

%% The modules of the toolchain's own Erlang, found once in a host's life:
%% each beam of its applications' ebin directories (ern_tree) but a test's,
%% one whose source its application's test directory holds, which
%% tools/install.sh leaves out of a release, so that a test's own module
%% is the host's, as a program's foreign module is.
own_modules() ->
    case persistent_term:get({?MODULE, own_modules}, none) of
        none ->
            Ebin = filename:join([ern_tree:tree(), "erl", "*", "ebin"]),
            Beams = filelib:wildcard(filename:join(Ebin, "*.beam")),
            Own = maps:from_keys([list_to_atom(filename:basename(Beam, ".beam"))
                                  || Beam <- Beams, not is_test(Beam)], true),
            persistent_term:put({?MODULE, own_modules}, Own),
            Own;
        Own ->
            Own
    end.

is_test(Beam) ->
    Application = filename:dirname(filename:dirname(Beam)),
    filelib:is_regular(filename:join([Application, "test",
                                      filename:basename(Beam, ".beam") ++ ".erl"])).

%% A call waiting on a system process, a listener, a socket or a running
%% program, Held, is a pending I/O from before its request is sent, as the
%% caller's CALL key is (pending/2): signals from two senders are not
%% ordered, so a request still in transit is not seen at its receiver.
calling_the_system(undefined, _Held) ->
    false;
calling_the_system({Callee, _}, Held) ->
    lists:member(Callee, Held).

quiet_system() ->
    erlang:process_info(erlang:self(), message_queue_len) =:= {message_queue_len, 0}
        andalso lists:all(fun quiet/1, system_pids() ++ opened()).

%% Report §8.2: the run's system processes that have been started.
system_pids() ->
    [Pid || Name <- [stdout, stderr, stdin, clock, fs, terminal, tcp, os],
            Pid <- [persistent_term:get({?MODULE, Name}, undefined)], Pid =/= undefined].

%% A system process that has died can deliver nothing.
quiet(Pid) ->
    case erlang:process_info(Pid, [status, message_queue_len]) of
        [{status, waiting}, {message_queue_len, 0}] -> true;
        undefined -> true;
        _ -> false
    end.

snapshot(Pids) ->
    [case erlang:process_info(Pid, [status, reductions]) of
         [{status, Status}, {reductions, Reductions}] -> {Pid, Status, Reductions};
         undefined -> {Pid, dead, 0}
     end || Pid <- Pids].

%% Report §8.4: the checker in front of an address exposed to
%% foreign code is one per address and mailbox type, not one per call: two
%% checkers checking the same messages for the same process are two of the
%% same thing. The loser of a race is killed and the winner used.
-spec checker_for(term(), address(), fun(() -> pid())) -> pid().
checker_for(Key, Behind, Start) ->
    case ets:lookup(?CHECKERS, {checker, Key}) of
        [{_, Pid}] ->
            Pid;
        [] ->
            Pid = Start(),
            case ets:insert_new(?CHECKERS, {{checker, Key}, Pid}) of
                true ->
                    %% what the checker stands before, and the key, which
                    %% holds the type it checks (ern_boundary:checker/4)
                    ets:insert(?CHECKERS, {{behind, Pid}, process_of(Behind), Behind, Key}),
                    Pid;
                false ->
                    exit(Pid, kill),
                    [{_, Winner}] = ets:lookup(?CHECKERS, {checker, Key}),
                    Winner
            end
    end.

-spec checker_forget(term(), pid()) -> ok.
checker_forget(Key, Checker) ->
    %% the table is gone once the program has ended (report §8.6)
    try
        ets:delete(?CHECKERS, {checker, Key}),
        ets:delete(?CHECKERS, {behind, Checker})
    catch _:_ -> true
    end,
    ok.

%% Report §8.6: what a system process, a listener, or a socket holds that
%% can still deliver, a timer, a subscription, or a request in progress.
%% Each is counted while it is held, since a process that is inside a read
%% cannot answer a question, and counted against its holder, whose row goes
%% when its count is 0 or when it is forgotten (forget_opened/1). A holder
%% may be counted by the process that starts it, before it runs, so that
%% no answer comes before its count.
-spec source_begin() -> ok.
source_begin() ->
    source_begin(erlang:self()).

%% Holder is the process that holds the source, or a reference for one no
%% process holds, a kill under way (killed/2).
-spec source_begin(pid() | reference()) -> ok.
source_begin(Holder) ->
    Key = {source, Holder},
    try ets:update_counter(?HELD, Key, {2, 1}, {Key, 0}) catch _:_ -> 0 end,
    ok.

-spec source_end() -> ok.
source_end() ->
    source_end(erlang:self()).

source_end(Holder) ->
    Key = {source, Holder},
    %% the delete inside the try with the count, since the table goes with
    %% the node's end at any moment between the two
    try
        case ets:update_counter(?HELD, Key, {2, -1}) of
            0 -> ets:delete_object(?HELD, {Key, 0});
            _ -> true
        end
    catch _:_ ->
        true
    end,
    ok.

sources() ->
    try
        lists:sum([Count || [Count] <- ets:match(?HELD, {{source, '_'}, '$1'})])
    catch _:_ ->
        1
    end.

%% Report §8.6, Appendix E.18, E.23: a listener, a socket or a running
%% program, which a system module's functions open, is checked as a system
%% process is, a request in its mailbox being a message in flight. It is
%% recorded by the process that starts it, before its address is given out,
%% and forgotten with its sources when it ends, which the process it is
%% linked to learns. Report Appendix E.21: it is a process of the program's
%% too, listed by Process.live, known to Process.status and reported by
%% Process.faults, under Site, the function that opened it, and started by
%% Owner, the process that asked for it (started_by/1).
-spec opened(pid(), binary(), pid()) -> ok.
opened(Pid, Site, Owner) ->
    try ets:insert(?HELD, {{opened, Pid}}) catch _:_ -> true end,
    case launch_reaper() of
        none ->
            ok;
        Reaper ->
            Ref = make_ref(),
            Reaper ! {adopt, Pid, Site, Owner, erlang:self(), Ref},
            receive {Ref, adopted} -> ok end
    end.

-spec forget_opened(pid()) -> ok.
forget_opened(Pid) ->
    try
        ets:delete(?HELD, {opened, Pid}),
        ets:delete(?HELD, {source, Pid})
    catch _:_ ->
        true
    end,
    ok.

opened() ->
    try [Pid || [Pid] <- ets:match(?HELD, {{opened, '$1'}})] catch _:_ -> [] end.

%% Report §8.6, §6.3: a receive with a deadline, the compiler's and a
%% call's, puts TIMED in the process's dictionary before it waits and
%% takes it away first in every body, so tail position holds; the compiler
%% emits the calls. Two never nest, since nothing runs while one waits.
-spec timed() -> ok.
timed() ->
    _ = erlang:put(?TIMED, true),
    ok.

-spec untimed() -> ok.
untimed() ->
    _ = erlang:erase(?TIMED),
    ok.

%% Report §6.3, §6.6, Appendix E.0 rule 8: a time has no upper bound, and a
%% time below 0 is 0. The host waits at most ?SLICE at once, so a wait is
%% made against the moment its time ends, on the monotonic clock, in waits
%% of at most ?SLICE each; the compiler emits the same loop for `after`.
-spec deadline(integer()) -> integer().
deadline(Ms) ->
    erlang:monotonic_time(millisecond) + max(0, Ms).

%% The next wait towards the deadline; 0 once it has passed.
-spec remaining(integer()) -> 0..?SLICE.
remaining(Deadline) ->
    min(?SLICE, max(0, Deadline - erlang:monotonic_time(millisecond))).

%% Appendix E.15: Clock.now, milliseconds since the epoch by the host's
%% clock, read here and not through the clock's process, which an operation
%% the host makes without a message needs no more than this.
-spec now() -> integer().
now() ->
    erlang:system_time(millisecond).

%% Appendix E.15: Clock.monotonic, milliseconds since a moment the runtime
%% chose, which never go back.
-spec monotonic() -> integer().
monotonic() ->
    erlang:monotonic_time(millisecond).

%% Appendix E.15: Clock.monotonicMicros, the same clock in microseconds.
-spec monotonic_micros() -> integer().
monotonic_micros() ->
    erlang:monotonic_time(microsecond).

%% Report §8.6, §8.4: a process inside foreign code is not waiting, and
%% where its stack cannot show it, it says so under FOREIGN: while a
%% function given to foreign code runs, called by foreign code through the
%% wrapper the compiler writes around it (ern_emitter's called/2), which a
%% tail call of foreign code leaves alone on the stack; and while the
%% runtime waits for the process on what the look cannot see deliver, a
%% peer, a port, the code table's holder, a restart's answers, Code.load's
%% placing and evaluation (ern_code_load:load/1) or the program's end. One
%% may come inside another, a callback that calls foreign code that calls
%% back, so the key counts them, and the last to leave takes it away.
-spec entered_foreign() -> ok.
entered_foreign() ->
    _ = erlang:put(?FOREIGN, case erlang:get(?FOREIGN) of
                                 undefined -> 1;
                                 Count -> Count + 1
                             end),
    ok.

-spec left_foreign() -> ok.
left_foreign() ->
    _ = case erlang:get(?FOREIGN) of
            1 -> erlang:erase(?FOREIGN);
            Count -> erlang:put(?FOREIGN, Count - 1)
        end,
    ok.

%% Report §8.6: the host loads a module at the first call into it, and the
%% caller waits on the code server meanwhile, which is the host's work and
%% not a receive of the caller's: the host's function on top of its stack
%% says so to the look (still/1). Every process the runtime starts has this
%% module as its error handler (run/1), and so does the one each of ern's
%% jobs runs in (ern_cli:start/0), which leaves the call itself to the
%% host's handler. Report §11.2: a unit of the toolchain's own is loaded
%% from its `.erc` at that first call, as the host loads a module of its
%% own (load/1).
-spec undefined_function(module(), atom(), [term()]) -> term().
undefined_function(ErlangModule, Function, Args) ->
    load(ErlangModule),
    error_handler:undefined_function(ErlangModule, Function, Args).

-spec undefined_lambda(module(), fun(), [term()]) -> term().
undefined_lambda(ErlangModule, Function, Args) ->
    load(ErlangModule),
    error_handler:undefined_lambda(ErlangModule, Function, Args).

%% Report §8.7, §11.2: a module loaded on demand, a unit of the
%% toolchain's own from its `.erc` and in the code table as it loads, any
%% other as the host loads it (ern_code:ensure_loaded/1), the host's work
%% as the load is. The code table's own module the host loads, since its
%% first call would come back here.
load(ErlangModule) ->
    {module, ern_code} = code:ensure_loaded(ern_code),
    ern_code:ensure_loaded(ErlangModule).

%%
%% Report §7: a process body; an exception is a fault
%%

run(Function) ->
    erlang:process_flag(error_handler, ?MODULE),
    try
        Function()
    catch
        %% report §8.7: a compute's process ends with the fault it carried
        %% to its caller (answered_compute/2), its row saying so
        throw:{ern, carried, Fault} ->
            exit(ended_as(erlang:self(), carried, Fault));
        Class:Error:Stack ->
            Fault = met(Class, Error, Stack),
            %% report §8.6, §11.2: a fault met as the program ends ends the
            %% process with the program, and is not reported
            is_program_ending(erlang:self()) andalso end_with_program(),
            exit(ended_with(erlang:self(), Fault))
    end.

%% Report §8.4, §11.2: the host's term of the end of Pid, which met Fault,
%% its cause and its trace, and the fault whole in Pid's row, which the
%% reaper reports (died/6); a row gone with the program's end holds
%% nothing.
ended_with(Pid, Fault) ->
    ended_as(Pid, Fault, Fault).

%% The host's term of a fault's end, its row holding Held: the fault, or
%% report §8.7: `carried` for one a compute carried to its caller.
ended_as(Pid, Held, #fault{cause = Cause, trace = Trace}) ->
    _ = try ets:update_element(?PROCESSES, Pid, {#process_row.fault, Held})
        catch error:badarg -> false
        end,
    {ern, fault, Cause, Trace}.

%% Report §7.3, §7.4: what a host error is as an Ernest fault, with its
%% trace, the host's stack where it was met (Appendix E.21): a fault a
%% process meets in its own code has the stack the raise kept, a throw of
%% the prelude's `fault` and the runtime's among them, whose stack is the
%% throw's, and the host's badarith, whose cause the stack tells
%% (arithmetic_cause/1); one raised with its trace, a foreign function's
%% raise and a fault met on a message's way (§6.5), keeps it, and one a
%% compute carried keeps the peer's (§8.7); one a call carried from its
%% callee (§6.6) takes the stack where it is raised. A failure of the
%% runtime is the host's class and reason, its trace a failure's
%% (failure_trace/1). Every place a host error becomes a fault reads it
%% here, as a #fault{} met then, at the moment it is met, which a fault
%% raised again keeps.
-spec met(error | exit | throw, term(), list()) -> #fault{}.
met(error, badarith, Stack) ->
    case arithmetic_cause(Stack) of
        failure -> failure_met(error, badarith, Stack);
        Cause -> #fault{cause = Cause, trace = trace(Stack), time = now()}
    end;
met(throw, {ern, fault, Cause}, Stack) ->
    #fault{cause = Cause, trace = trace(Stack), time = now()};
met(throw, {ern, #fault{trace = none} = Fault}, Stack) ->
    met(throw, {ern, Fault#fault{trace = trace(Stack)}}, Stack);
met(throw, {ern, #fault{time = none} = Fault}, _) ->
    Fault#fault{time = now()};
met(throw, {ern, #fault{} = Fault}, _) ->
    Fault;
met(Class, Error, Stack) ->
    failure_met(Class, Error, Stack).

failure_met(Class, Error, Stack) ->
    #fault{cause = host_cause(Class, Error), trace = failure_trace(Stack), time = now()}.

%% Report §3.1, §7.4: the cause of the host's badarith, read from its stack
%% where it was met. An Int `/` or `%` by zero is the host's `div` or `rem`,
%% whose frame holds its integer operands. A Float operation whose result
%% is not finite is the host's operation on floats: its frame holds them
%% where the host's compiler did not know they were floats, and where it
%% knew, the host computed in its float registers and raised in the
%% program's own frame, with no frame of its own. Any other badarith is no
%% operation of the program's, a failure of the runtime.
arithmetic_cause([{erlang, Operator, [Left, Right], _} | _])
  when is_integer(Left), is_integer(Right), (Operator =:= 'div' orelse Operator =:= 'rem') ->
    <<"division by zero">>;
arithmetic_cause([{erlang, Operator, [Left, Right], _} | _])
  when is_float(Left), is_float(Right),
       (Operator =:= '+' orelse Operator =:= '-' orelse Operator =:= '*' orelse Operator =:= '/') ->
    <<"float arithmetic error">>;
arithmetic_cause([Frame | _]) ->
    case is_program_frame(Frame) of
        true -> <<"float arithmetic error">>;
        false -> failure
    end;
arithmetic_cause([]) ->
    failure.

%% A failure of the runtime's as a cause, the host's class and reason.
host_cause(Class, Error) ->
    format("~p:~p", [Class, Error]).

%% Report §7.4, §9.6: a fault with the cause given, every fault the
%% runtime raises and the prelude's `fault` taken as a value, whose trace
%% is the stack of the throw (met/3); a call of `fault` the
%% code raises in place as this does (ern_emitter:raised/1).
-spec fault(binary()) -> no_return().
fault(Cause) ->
    throw({ern, fault, Cause}).

%% A fault with the trace of where it was met beside its cause, a foreign
%% function's raise (§7.4).
-spec fault(binary(), binary()) -> no_return().
fault(Cause, Trace) ->
    throw({ern, #fault{cause = Cause, trace = Trace}}).

%% Report §7.3, §8.6, §8.2: a fault the runtime gives a process from
%% outside it, a deadlock, or the end a system process asks for, the
%% process's end, its trace the process's stack where the runtime finds it
%% waiting (killed/2).
found_fault(Pid, Cause) ->
    killed(Pid, {found, Cause}).

%% Appendix E.21: the trace of a fault the runtime raises by design, a
%% cause of §7.4's or a library function's, the deadlock and a failed
%% check among them: a frame of the runtime's is left out wherever it
%% stands, the twelve counted without it, and a frame of the host's above
%% the program's stays. A frame of the runtime's is one of the toolchain's
%% own Erlang (own_modules/0), or one of a unit that names no definition
%% of the program's, a helper the compiler writes into the unit, the
%% boundary's wrapper, a spawn's entry or an arrival's lacked function
%% among them (ern_code:function_text/3).
-spec trace([tuple()]) -> binary().
trace(Stack) ->
    Own = own_modules(),
    traced([Entry || {ErlangModule, _, _, _} = Entry <- Stack, not is_map_key(ErlangModule, Own),
                     not is_helper_frame(Entry)]).

%% Appendix E.21, report §7.4: the trace of a fault whose cause names a
%% host error, a failure in the runtime or a foreign function's raise,
%% which keeps the runtime's frames above the program's outermost frame,
%% where the host error was met in the runtime's own code.
-spec failure_trace([tuple()]) -> binary().
failure_trace(Stack) ->
    traced(Stack).

%% Appendix E.21: a trace, the innermost twelve frames of the stack given,
%% the innermost first, a frame a line, ending with the outermost frame of
%% the program's code: the frames beneath it are left out, and a stack with
%% no frame of the program's has an empty trace. A frame of Ernest code is
%% written as a spawn site is (§6.9), by the name the unit's sites write
%% its function by (ern_code:function_text/3) and its line,
%% `Counter.worker:23`; a frame of the host's or the runtime's by the
%% function as the host writes it, quoted where the host quotes it, and its
%% line, `lists:nth/2:213`, `erlang:'div'/2` (ern_namespace:host_function_text/3);
%% either without a line where the host gives none. Report §11.2: the
%% printer indents it.
traced(Stack) ->
    Program = lists:reverse(lists:dropwhile(fun(Entry) -> not is_program_frame(Entry) end,
                                            lists:reverse(Stack))),
    unicode:characters_to_binary([[trace_line(Entry), $\n]
                                  || {_, _, _, _} = Entry <- lists:sublist(Program, 12)]).

%% Whether a frame of the host's stack is of a unit of Ernest code.
is_program_frame({ErlangModule, Function, _, Info}) ->
    ern_code:function_text(ErlangModule, Function, proplists:get_value(line, Info, none)) =/= none;
is_program_frame(_) ->
    false.

%% Whether a frame is of a unit, which exports '$code'/0 as every unit
%% does (is_ernest/1), and names no definition of the program's.
is_helper_frame({ErlangModule, _, _, _} = Entry) ->
    erlang:function_exported(ErlangModule, '$code', 0) andalso not is_program_frame(Entry).

%% Report §8.7, §11.2: a frame's line, its name written with each control
%% character as its escape, since a unit an exchange made names its
%% definitions by a peer's text, which may hold any (ern_code:function_text/3),
%% and a line feed in one would forge a frame.
trace_line({ErlangModule, Function, Arguments, Info}) ->
    Line = proplists:get_value(line, Info, none),
    Name = case ern_code:function_text(ErlangModule, Function, Line) of
               none -> ern_namespace:host_function_text(ErlangModule, Function, arity(Arguments));
               Text -> Text
           end,
    ern_show:controls(ern_namespace:site_text([Name], Line), line).

arity(Arguments) when is_list(Arguments) -> length(Arguments);
arity(Arguments) -> Arguments.

%%
%% Report §8.2, §9.7: system references
%%

-spec system_process(system()) -> address().
system_process(Name) ->
    persistent_term:get({?MODULE, Name}).

%% Report §8.2: stdout and stderr each write what they receive, as bytes,
%% through the function a run was given, or to a file descriptor through a
%% port of their own, which says when the stream can no longer be written:
%% the program then ends (§8.6), and the stream's process with it. A
%% program's write, Io.OutMsg's Write(bytes, reply), is answered once the
%% bytes are taken, the port holding this process while it is busy, so that
%% the writer waits while the stream is behind; the runtime's own lines, a
%% fault's report and a test's, are bytes alone. The port is busy while it
%% holds a byte it has not written, its limits one byte, and the host holds
%% a writer to a busy port until it is not, so that a write waits until
%% the stream has taken everything before it, and a write of nothing
%% returns once the port has written all it was given (drained/1).
stream({fd, Fd}, Name) ->
    process_flag(trap_exit, true),
    stream_loop(erlang:open_port({fd, 0, Fd}, [out, binary, {busy_limits_port, {1, 1}}]), Name);
stream(Write, _Name) ->
    write_loop(Write).

write_loop(Write) ->
    receive
        {flush, From, Ref} ->
            From ! {Ref, flushed},
            write_loop(Write);
        stop ->
            ok;
        {'Write', Bytes, Reply} ->
            Write(Bytes),
            answer(Reply, ?UNIT),
            write_loop(Write);
        Bytes when is_binary(Bytes) ->
            Write(Bytes),
            write_loop(Write)
    end.

stream_loop(Stream, Name) ->
    receive
        stop ->
            ok;
        {flush, From, Ref} ->
            case drained(Stream) of
                ok ->
                    From ! {Ref, flushed},
                    stream_loop(Stream, Name);
                gone ->
                    %% report §8.6: the flush is told, so that it neither
                    %% waits nor takes what was lost for written
                    From ! {Ref, gone},
                    gone(Name)
            end;
        {'Write', Bytes, Reply} ->
            case written(Stream, Bytes) of
                ok -> answer(Reply, ?UNIT), stream_loop(Stream, Name);
                gone -> gone(Name)
            end;
        Bytes when is_binary(Bytes) ->
            case written(Stream, Bytes) of
                ok -> stream_loop(Stream, Name);
                gone -> gone(Name)
            end;
        {'EXIT', Stream, _} ->
            gone(Name)
    end.

written(Stream, Bytes) ->
    try erlang:port_command(Stream, Bytes) of
        true -> ok
    catch
        error:badarg -> gone
    end.

%% What the port was given is written, or the stream has gone: a write of
%% nothing returns once the port is not busy, which it is while it holds
%% anything (stream/2), and fails where the port has ended.
drained(Stream) ->
    written(Stream, <<>>).

gone(Name) ->
    {Runner, Launch} = launch_runner(),
    Runner ! {gone, Launch, Name},
    dropping().

%% Report §11: a stream that has gone writes nothing more, and the program
%% ends at once. Until it has, what is written to the stream is dropped and
%% its writer goes on, so that no writer faults for a stream that ended.
dropping() ->
    receive
        stop -> ok;
        {flush, From, Ref} -> From ! {Ref, gone}, dropping();
        {'Write', _, Reply} -> answer(Reply, ?UNIT), dropping();
        _ -> dropping()
    end.

%% Report §8.2: keys and lines are the same terminal, so a program does one
%% or the other; doing both ends the program with a fault, as Deadlock ends
%% it, since neither side can answer for the other.
%% Report §11.2: the terminal is the shell's, and the process that reads it
%% for the shell is recorded as its holder; §8.2's case then faults anything
%% else that asks for keys. The shell claims it before it runs any input.
-spec hold_terminal(address()) -> 'Unit'.
hold_terminal(Address) ->
    persistent_term:put({?MODULE, holder}, process_of(Address)),
    ?UNIT.

-spec terminal_holder() -> pid() | undefined.
terminal_holder() ->
    persistent_term:get({?MODULE, holder}, undefined).

%% Report §7.4, §11.2: the cause of a process that asks for the terminal
%% while a shell holds it, a subscriber or a reader of lines alike.
-spec shell_holds() -> binary().
shell_holds() ->
    <<"the shell holds the terminal; run the program with ern run to give it the keyboard">>.

%% Report §11.2: while a shell holds the terminal, a line is read by the
%% holder alone. Anything else that asks faults, in its own process, before
%% the request reaches stdin, where it would take the shell's next line.
line_guard(Address) ->
    case terminal_holder() of
        undefined -> ok;
        Holder ->
            Stdin = persistent_term:get({?MODULE, stdin}, undefined),
            case process_of(Address) =:= Stdin andalso erlang:self() =/= Holder of
                true -> fault(shell_holds());
                false -> ok
            end
    end.

%% Report §8.2: which way the terminal is being read, keys or lines; a
%% program does one or the other, and the second to ask faults, with the
%% cause returned here. The first to ask claims it in one step, so two that
%% ask at once are one claim.
-spec own_terminal(lines | keys) -> ok | {taken, binary()}.
own_terminal(Kind) ->
    case ets:insert_new(?LAUNCH, {reading, Kind}) of
        true ->
            ok;
        false ->
            case ets:lookup(?LAUNCH, reading) of
                [{reading, Kind}] ->
                    ok;
                [{reading, Other}] ->
                    {taken, format("the terminal is already read as ~s", [Other])}
            end
    end.

%% Report §7.3, §8.2: a system process ends the program with a fault of
%% the entry process, the runner's to report.
end_with_fault(Cause) ->
    {Runner, Launch} = launch_runner(),
    Runner ! {fault, Launch, Cause},
    ok.

%% Report §8.2: standard input, read as UTF-8 whatever the host's locale,
%% as lines and as bytes from one stream, each request taking up where the
%% one before it stopped. Open is the input (open_input/0, or fed/1 in a
%% test), opened for a request and closed once it is answered, so that no
%% more is read than a request needs and a program slower than what writes
%% to it holds the writer back. Report §7.3: a read that fails is a failure
%% of the runtime, and ends the program with a fault that names it.
stdin_loop(Open) ->
    erlang:process_flag(trap_exit, true),
    stdin_loop(Open, <<>>).

stdin_loop(Open, Buffer) ->
    receive
        %% report §8.2: a claim the terminal refuses faults the process that
        %% asked, and nothing is read for it
        {'ReadLine', Reply} ->
            case own_terminal(lines) of
                ok -> stdin_loop(Open, read_line(Reply, Open, Buffer));
                {taken, Cause} -> refuse(Reply, Cause), stdin_loop(Open, Buffer)
            end;
        {'Read', Reply} ->
            case own_terminal(lines) of
                ok -> stdin_loop(Open, read_bytes(Reply, Open, Buffer));
                {taken, Cause} -> refuse(Reply, Cause), stdin_loop(Open, Buffer)
            end;
        {'EXIT', _, _} ->
            %% an input closed after its answer came
            stdin_loop(Open, Buffer)
    end.

%% Report §8.2: the next line answered, a source while it is read, and
%% what is left after it.
read_line(Reply, Open, Buffer) ->
    source_begin(),
    Rest = case line(Open, Buffer, 0) of
               {eof, Left} -> answer(Reply, 'None'), Left;
               {{line, Line}, Left} -> answer_line(Reply, without_return(Line)), Left;
               {{last, Line}, Left} -> answer_line(Reply, Line), Left;
               {{error, Error}, Left} -> unreadable(Error), Left
           end,
    source_end(),
    Rest.

%% Report §8.2: the bytes that have arrived answered, a source while they
%% are read; none is left.
read_bytes(Reply, Open, Buffer) ->
    source_begin(),
    case Buffer of
        <<>> -> bytes(Reply, read_input(Open));
        _ -> answer(Reply, {'Some', Buffer})
    end,
    source_end(),
    <<>>.

%% The next line and the bytes after it: the bytes before the first line
%% feed at or after Offset, reading more while there is none. A last line
%% without a line feed is a line, `last`.
line(Open, Buffer, Offset) ->
    case binary:match(Buffer, <<"\n">>, [{scope, {Offset, byte_size(Buffer) - Offset}}]) of
        {Index, 1} ->
            <<Line:Index/binary, $\n, Rest/binary>> = Buffer,
            {{line, Line}, Rest};
        nomatch ->
            case read_input(Open) of
                {data, Bytes} -> line(Open, <<Buffer/binary, Bytes/binary>>, byte_size(Buffer));
                eof when Buffer =:= <<>> -> {eof, <<>>};
                eof -> {{last, Buffer}, <<>>};
                {error, Error} -> {{error, Error}, Buffer}
            end
    end.

%% Report §8.2: a line that a line feed ended, without one carriage return
%% before the line feed; a last line keeps its own.
without_return(Line) ->
    case Line of
        <<Head:(byte_size(Line) - 1)/binary, $\r>> -> Head;
        _ -> Line
    end.

%% Report §8.2, §7.4: the line, or the fault of the process that asked,
%% when it is not UTF-8.
answer_line(Reply, Text) ->
    case unicode:characters_to_binary(Text, utf8, utf8) of
        Text -> answer(Reply, {'Some', Text});
        _ -> refuse(Reply, not_utf8())
    end.

%% Report §8.2: what has arrived, at least one byte, or None at the end.
bytes(Reply, {data, Bytes}) -> answer(Reply, {'Some', Bytes});
bytes(Reply, eof) -> answer(Reply, 'None');
bytes(_, {error, Error}) -> unreadable(Error).

unreadable(Error) ->
    end_with_fault(<<(unreadable())/binary, (format("~p", [Error]))/binary>>).

unreadable() ->
    <<"the standard input could not be read: ">>.

not_utf8() ->
    <<"the standard input is not UTF-8">>.

%% Report §8.2, §7.4: keys that are not UTF-8 end the program with the
%% fault of its entry process, since no process asked for them.
-spec input_not_utf8() -> ok.
input_not_utf8() ->
    end_with_fault(not_utf8()).

%% Report §8.2, §11.8: whether a fault's cause is one of standard input's,
%% which ends a shell as it ends a run, by its input and not by a defect.
-spec by_input(binary()) -> boolean().
by_input(Cause) ->
    Prefix = unreadable(),
    case Cause of
        <<Prefix:(byte_size(Prefix))/binary, _/binary>> -> true;
        _ -> Cause =:= not_utf8()
    end.

%% The input as it arrives, for one request: at least one byte, eof, or
%% {error, Error}. The input is open from the request to its first answer,
%% and what arrived with that answer is taken with it. An exit from a link
%% other than the input's own is the end of the process that reads.
-spec read_input(fun(() -> port() | pid())) -> {data, binary()} | eof | {error, term()}.
read_input(Open) ->
    Input = Open(),
    First = receive
                {Input, {data, Bytes}} -> {data, Bytes};
                {Input, eof} -> eof;
                {Input, {error, Error}} -> {error, Error};
                {'EXIT', Input, Error} -> {error, Error};
                {'EXIT', _, ExitReason} -> close_input(Input), exit(ExitReason)
            end,
    close_input(Input),
    case First of
        {data, Head} -> {data, arrived(Input, Head)};
        _ -> First
    end.

arrived(Input, Acc) ->
    receive
        {Input, {data, Bytes}} -> arrived(Input, <<Acc/binary, Bytes/binary>>)
    after 0 ->
        Acc
    end.

close_input(Input) when is_port(Input) ->
    erlang:unlink(Input),
    try erlang:port_close(Input) catch error:badarg -> true end,
    flush_exit(Input);
close_input(Input) ->
    erlang:unlink(Input),
    exit(Input, kill),
    flush_exit(Input).

flush_exit(Input) ->
    receive {'EXIT', Input, _} -> ok after 0 -> ok end.

%% The host's standard input, a port on its descriptor. `bin/ern` starts
%% the host with -noinput, so that the descriptor is the runtime's alone.
open_input() ->
    erlang:open_port({fd, 0, 1}, [in, binary, eof, stream]).

%% A test's input: Next is called once for each opening and answers what
%% arrives then, characters, bytes as they are, eof, or {error, Error}.
fed(Next) ->
    fun() ->
        Owner = erlang:self(),
        erlang:spawn_link(fun() -> Owner ! {erlang:self(), fed_message(Next())} end)
    end.

fed_message(eof) -> eof;
fed_message({error, Error}) -> {error, Error};
fed_message(Bytes) when is_binary(Bytes) -> {data, Bytes};
fed_message(Chars) -> {data, unicode:characters_to_binary(Chars)}.

%% Clock's messages, clock.ern's (report Appendix E.15): Alarm(ms,
%% address, reply) and AlarmAt(time, address, reply); `now` reads the
%% host's clock without them, and a test's `time` moves the alarms alone.
%% Alarms are delivered through the clock itself, so each is counted as a
%% source while it is pending (report §8.6). The clock holds each pending alarm by
%% its timer, with its moment, where it goes and the process behind that,
%% and each process's timers, so that a restart of that process cancels its
%% own and reads no other's (report §6.9), and its monitor of each process
%% it holds an alarm of, one for each, so that the end of that process
%% forgets its alarms too (alarms_canceled/2). An alarm after milliseconds is
%% held by its deadline on the monotonic clock, `{monotonic, Deadline}`,
%% which a clock that is set does not move; one at a time by the time,
%% `{time, Time}`, which the host's clock is read against. The host's
%% timers count monotonic time, so the clock asks the host to be told of
%% each change of its time offset, and sets every alarm at a time again
%% then. `read_time` reads the host's clock, or a test's.
-record(clock, {alarms = #{}, by_recipient = #{}, monitor_refs = #{}, read_time}).

%% Report §6.5, E.15: the clock holds each alarm's delivery, a process of
%% its own linked to it (fired/2), and traps their exits, as the reaper
%% does its own (reaper/0).
clock(ReadTime) ->
    erlang:process_flag(trap_exit, true),
    %% Report §10: its mailbox kept off its heap, so that no collection of the
    %% heap copies a burst of the alarms' messages that wait in it (the log's
    %% *The Rows That Grew*).
    erlang:process_flag(message_queue_data, off_heap),
    _ = erlang:monitor(time_offset, clock_service),
    clock_loop(#clock{read_time = ReadTime}).

clock_loop(Clock) ->
    receive
        {'Alarm', Ms, Address, Reply} ->
            clock_loop(alarm({monotonic, deadline(Ms)}, Address, Reply, Clock));
        {'AlarmAt', At, Address, Reply} ->
            clock_loop(alarm({time, At}, Address, Reply, Clock));
        {timeout, Timer, deadline} ->
            clock_loop(fired(Timer, Clock));
        {'CHANGE', _, time_offset, clock_service, _} ->
            clock_loop(set_again(Clock));
        {new_run, Pid, Ref} ->
            Clock1 = alarms_canceled(Pid, Clock),
            Pid ! {Ref, fresh},
            clock_loop(Clock1);
        {'DOWN', _MonitorRef, process, Pid, _} ->
            clock_loop(alarms_canceled(Pid, Clock));
        {'EXIT', Pid, ExitReason} ->
            _ = undelivered(Pid, ExitReason),
            clock_loop(Clock)
    end.

%% An alarm, answered once it is counted, so that the caller goes on
%% waiting only on what is counted (report §8.6).
alarm(Moment, Address, Reply, Clock) ->
    source_begin(),
    Armed = armed(Moment, Address, Clock),
    answer(Reply, ?UNIT),
    Armed.

%% A timer that fired: its alarm delivered once its moment has come, and
%% set again before; one a restart canceled as it fired, or a change of
%% the clock set again, is gone.
%% Report §6.5, E.15: the alarm's address may be an address seen through a
%% function, and it is sent the time it fired, from a process of its own,
%% so that a function that does not finish holds up no other alarm; the
%% alarm is a source until it is delivered.
fired(Timer, #clock{alarms = Alarms, read_time = ReadTime} = Clock) ->
    case Alarms of
        #{Timer := {Moment, Address, Recipient}} ->
            case wait(Moment, ReadTime) of
                0 ->
                    Now = ReadTime(),
                    counted_link(Address, fun() -> deliver(Address, Now) end),
                    source_end(),
                    without_alarm(Timer, Recipient, Clock);
                _ ->
                    without_alarm(Timer, Recipient, armed(Moment, Address, Clock))
            end;
        #{} ->
            Clock
    end.

%% Appendix E.15: the host's clock was set. An alarm at a time is set again
%% against the clock as it now reads: one whose time has come fires at
%% once, and one whose time is further off waits the longer.
set_again(#clock{alarms = Alarms} = Clock) ->
    maps:fold(fun(Timer, {{time, _} = Moment, Address, Recipient}, Acc) ->
                      erlang:cancel_timer(Timer),
                      without_alarm(Timer, Recipient, armed(Moment, Address, Acc));
                 (_Timer, {{monotonic, _}, _, _}, Acc) ->
                      Acc
              end, Clock, Alarms).

%% Report §6.9: a restart cancels the process's alarms, and those on their
%% way to it. Report §8.6, Appendix E.15: so does its end, which the
%% clock's monitor of it tells, since an alarm that fires after its process
%% has ended delivers nothing, so that none is a source the deadlock count
%% waits on.
alarms_canceled(Pid, #clock{alarms = Alarms, by_recipient = ByRecipient,
                            monitor_refs = MonitorRefs} = Clock) ->
    {Timers, ByRecipient1} = case maps:take(Pid, ByRecipient) of
                                 {Own, Others} -> {maps:keys(Own), Others};
                                 error -> {[], ByRecipient}
                             end,
    lists:foreach(fun(Timer) -> erlang:cancel_timer(Timer), source_end() end, Timers),
    abandoned(Pid),
    Clock#clock{alarms = maps:without(Timers, Alarms), by_recipient = ByRecipient1,
                monitor_refs = without_monitor(Pid, MonitorRefs)}.

%% Appendix E.0 rule 8: a time has no upper bound, and the host's timers
%% have one, so an alarm is set again until its moment has come. The
%% process it goes to is monitored from its first alarm.
armed(Moment, Address, #clock{alarms = Alarms, by_recipient = ByRecipient,
                              monitor_refs = MonitorRefs, read_time = ReadTime} = Clock) ->
    Timer = erlang:start_timer(wait(Moment, ReadTime), erlang:self(), deadline),
    Recipient = process_of(Address),
    MonitorRefs1 = case MonitorRefs of
                       #{Recipient := _} -> MonitorRefs;
                       #{} -> MonitorRefs#{Recipient => erlang:monitor(process, Recipient)}
                   end,
    Clock#clock{alarms = Alarms#{Timer => {Moment, Address, Recipient}},
                by_recipient = added(Recipient, Timer, ByRecipient), monitor_refs = MonitorRefs1}.

%% An alarm forgotten, and the monitor of its process with its last.
without_alarm(Timer, Recipient, #clock{alarms = Alarms, by_recipient = ByRecipient,
                                       monitor_refs = MonitorRefs} = Clock) ->
    ByRecipient1 = forgotten(Recipient, Timer, ByRecipient),
    MonitorRefs1 = case ByRecipient1 of
                       #{Recipient := _} -> MonitorRefs;
                       #{} -> without_monitor(Recipient, MonitorRefs)
                   end,
    Clock#clock{alarms = maps:remove(Timer, Alarms), by_recipient = ByRecipient1,
                monitor_refs = MonitorRefs1}.

%% The clock's monitor of Pid gone, and a DOWN it sent with it.
without_monitor(Pid, MonitorRefs) ->
    case maps:take(Pid, MonitorRefs) of
        {MonitorRef, MonitorRefs1} ->
            erlang:demonitor(MonitorRef, [flush]),
            MonitorRefs1;
        error ->
            MonitorRefs
    end.

%% The next wait towards an alarm's moment, at most ?SLICE; 0 once it has
%% come.
wait({monotonic, Deadline}, _Time) -> remaining(Deadline);
wait({time, At}, ReadTime) -> min(?SLICE, max(0, At - ReadTime())).

%%
%% Report §8.1, §8.6: the runner
%%

-type outcome() :: ok | killed | {fault, binary(), binary()}
                 | {initializer_fault, binary(), binary(), binary()}
                 | {exit, 0..255} | {gone, stdout | stderr} | {signal, sigterm | sighup}.

%% Runs EntryPoint as the entry process. It returns ok where the entry
%% process returned, killed where it was killed, {fault, Cause, Trace}
%% where it faulted, the trace the fault's (Appendix E.21): a deadlock and
%% a system process's fault among the faults, whose trace is the process's
%% stack where the runtime found it (report §8.6: the entry process faults
%% with `Fault("deadlock")`), and an end the host gave it otherwise,
%% Cause its reason and Trace empty
%% (§6.9); {initializer_fault, Site, Cause, Trace} where a top-level
%% binding faulted so before EntryPoint ran, Site naming the binding
%% (report §8.5); {exit, Status} where a process called
%% Os.exit, {gone, Stream} where standard output or standard error could
%% no longer be written, or {signal, Signal} where the host's termination
%% or hangup ended the program (entry_end/2). Every local process is then
%% ended with ProgramEnd, and standard output and standard error are
%% flushed, however the run ended.
%%
%% Options: init => a function run in the entry process before EntryPoint,
%% after the system references are bound and the standard library's lets
%% evaluated, for the program's own top-level lets (report §8.5);
%% arguments => the program's arguments, Os.arguments, none by default;
%% exit => fault, where Os.exit faults its caller rather than ending the
%% program, as in the shell and under `ern test` (report §11.2); faults =>
%% fun((FaultReport, Peer) -> any()), given every fault as it happens with
%% the node of the peer whose spawn started the process, or none (report
%% §11.2, §8.7); stdout, stderr => fun((binary()) -> any()), or {fd, N} to write
%% to the file descriptor through a port, which learns when the stream has
%% gone (§8.2); stdin => fun(() -> eof | {error, term()} |
%% unicode:chardata()), called for each read, and keys => the same for the
%% terminal's keys, for tests (fed/1); time => fun(() -> integer()), the
%% clock the Clock process reads in place of the host's, for tests; node =>
%% fun(() -> ok), run in the entry process after `init`, which starts a
%% node's carrier once the bindings have their values, a node detecting no
%% deadlock (report §8.6, §8.7); say => fun((iodata()) -> any()), which
%% writes the runtime's own line on standard error, ern_carrier:say/1 for
%% `ern run` and `ern test`, and by default the line through stderr
%% (say/2, report §11.2); flush => fun(() -> any()), the shell's,
%% run once the end's wait is over and stdout and stderr have taken what
%% was sent them, which writes what they passed on to its screen
%% (passed_on/2, §8.6). Report §8.2: the standard streams carry bytes for
%% the run, whatever the host's locale.
-spec run_main(fun(() -> term()), binary(), map()) -> outcome().
run_main(EntryPoint, Site, Options) ->
    make_tables(),
    %% Appendix E.28, E.21, report §10: the host keeps at most the innermost
    %% 64 frames of a stack, which Code.running reads (ern_code:running/1),
    %% where its backtrace depth names as many, eight by default; each raise
    %% saves that many, a fraction of its cost, and a fault's trace shows
    %% the innermost twelve (trace/1)
    _ = erlang:system_flag(backtrace_depth, 64),
    Launch = launched(Options),
    Reaper = erlang:spawn(fun reaper/0),
    true = ets:update_element(?LAUNCH, launch, {#launch.reaper, Reaper}),
    System = started_system(Options),
    Encodings = bytes_out(),
    %% report §11.2: the runner's own lines, through standard error's process
    %% where the run was given no function to say them with (say/2)
    Say = maps:get(say, Options,
                   fun(Text) ->
                       say(iolist_to_binary([Text, "\n"]),
                           fun(Line) -> io:put_chars(standard_error, Line) end)
                   end),
    Ended = try
                Told = told(entry_outcome(EntryPoint, Site, Options, Launch), Launch, Say),
                %% report §8.6: from here a fault is the program's end's
                %% (is_program_ending/1)
                true = ets:insert(?LAUNCH, {wait_over}),
                passed_on(System, Options),
                {ended, Told}
            catch
                Class:Error:Stack -> {raised, Class, Error, Stack}
            end,
    outcome_flushed(Ended, end_program(Launch, Reaper, System, Encodings)).

%% Report §8.6: before the program ends, each subscriber of Os.termination
%% is told (Appendix E.23), and the end waits until each has answered,
%% ended or restarted, nothing of the runtime's own timing the wait. While
%% it waits, what began the end stands, but for an Os.exit, which ends the
%% program at once with its status, and a second termination, which ends
%% it at once; no deadlock is found, a subscriber's subscription standing
%% (look/0), and a fault is the process's own (is_program_ending/1). A
%% subscription made while it waits is told at once (termination/1), a
%% restarted run's among them, since a restart ends the subscription with
%% the run (§6.9, new_run/3). Report §11.2: the wait is said by Say, the
%% runner's own line on standard error: once, with how many it waits for
%% and which; each subscriber told later as it is told; each as it
%% answers, ends or restarts; and a wait cut short. A subscriber is named
%% by its spawn site, several in the order their processes were spawned
%% (Appendix E.22), so that a line is the same from run to run. The
%% outcome the program ends with.
told(Outcome, Launch, Say) ->
    true = ets:insert(?LAUNCH, {ending, erlang:self(), Launch}),
    case untold(subscriptions(), #{}) of
        [] ->
            case last_read() of
                [] -> Outcome;
                _ -> told(Outcome, Launch, Say)
            end;
        Untold ->
            Sites = [Site || {_, _, _, Site} <- Untold],
            Say(["the end waits for ", counted(Sites), ": ", lists:join(", ", Sites)]),
            waited(Outcome, Launch, Say, tell_all(Launch, Untold, #{}), terminations(Outcome))
    end.

%% The terminations the program has had: one where one began the end.
terminations({signal, _}) -> 1;
terminations(_) -> 0.

%% The end's wait, Waiting holding each subscriber told and not yet heard
%% of (#waited_for{}). A word, a teller's or a new subscription's, reads
%% its subscriber's row alone, so that what a word costs does not grow with
%% the subscribers. A subscriber that restarted while it was waited for may
%% subscribe again in its new run before its teller's word comes; that
%% subscription is told once the word has come, so that the old run's line
%% is said before the new run's. A teller that ends before its word, which
%% a kill of its delivery from foreign code before it arrives makes it do,
%% its wrap's fault being the subscriber's, ends the wait for its
%% subscriber, whose answer would reach no one, and the end goes on
%% without it. Where none is waited for, the
%% wait is over once a last read finds no one to tell.
waited(Outcome, Launch, Say, Waiting, Terminations) when map_size(Waiting) =:= 0 ->
    case last_read() of
        [] ->
            Outcome;
        Untold ->
            true = ets:insert(?LAUNCH, {ending, erlang:self(), Launch}),
            waited(Outcome, Launch, Say, tell_late(Launch, Say, Untold, Waiting), Terminations)
    end;
waited(Outcome, Launch, Say, Waiting, Terminations) ->
    receive
        {said, Launch, Subscriber, How} ->
            #waited_for{site = Site, monitor_ref = MonitorRef} = maps:get(Subscriber, Waiting),
            erlang:demonitor(MonitorRef, [flush]),
            Say(["the subscriber ", Site, " ", How]),
            Waiting1 = maps:remove(Subscriber, Waiting),
            Untold = untold(subscription(Subscriber), Waiting1),
            waited(Outcome, Launch, Say, tell_late(Launch, Say, Untold, Waiting1), Terminations);
        {{teller, Launch, Subscriber}, _, process, _, _} ->
            #waited_for{site = Site} = maps:get(Subscriber, Waiting),
            Say(["the subscriber ", Site, " is no longer waited for"]),
            Waiting1 = maps:remove(Subscriber, Waiting),
            Untold = untold(subscription(Subscriber), Waiting1),
            waited(Outcome, Launch, Say, tell_late(Launch, Say, Untold, Waiting1), Terminations);
        {subscribed, Launch, Subscriber} ->
            Untold = untold(subscription(Subscriber), Waiting),
            waited(Outcome, Launch, Say, tell_late(Launch, Say, Untold, Waiting), Terminations);
        {exit, Launch, Status} ->
            cut_short(Say, Waiting),
            {exit, Status};
        {signal, Launch, _} when Terminations >= 1 ->
            cut_short(Say, Waiting),
            Outcome;
        {signal, Launch, _} ->
            waited(Outcome, Launch, Say, Waiting, Terminations + 1)
    end.

%% The subscribers a last read finds, the mark gone first: a process that
%% subscribed after the runner's last read, while the mark stood, told a
%% runner that waits for no word, so the table is read once more now that
%% the mark has gone, and what it finds is told; a subscription made after
%% that read is too late, as a monitor made at a process's end is.
last_read() ->
    ets:delete(?LAUNCH, ending),
    untold(subscriptions(), #{}).

%% Every subscription to the end, and one subscriber's, none where it has
%% none.
subscriptions() ->
    ets:tab2list(?TERMINATING).

subscription(Subscriber) ->
    ets:lookup(?TERMINATING, Subscriber).

%% The subscribers of Subscriptions not told yet: each live process the
%% runtime started whose run the end has not told and that is not waited
%% for, with its spawn order, its address and its spawn site, in the order
%% the processes were spawned.
untold(Subscriptions, Waiting) ->
    lists:sort([{Order, Subscriber, Address, Site}
                || {Subscriber, Address, false} <- Subscriptions,
                   not is_map_key(Subscriber, Waiting),
                   [#process_row{site = Site, spawn_order = Order}]
                       <- [ets_lookup(?PROCESSES, Subscriber)]]).

%% Each of them told, by a teller of its own, and its run marked told, so
%% that no later read tells it again. A row gone since the read, by its
%% process's end or restart, is told all the same, the teller's call ending
%% as any call to that process would. Report §6.9, §8.6: a teller has the
%% subscriber's wrap applied by a delivery of its own (tell/4), and the
%% reaper holds it as it holds a delivery (reaper_held/2), so that its end
%% ends nothing else and it ends with the program; the runner monitors it,
%% so that a teller that ends before its word holds up no end (waited/5).
tell_all(Launch, Untold, Waiting) ->
    Runner = erlang:self(),
    Reaper = launch_reaper(),
    lists:foldl(fun({Order, Subscriber, Address, Site}, Acc) ->
                    _ = ets:update_element(?TERMINATING, Subscriber, {3, true}),
                    Teller = reaper_held(Reaper, fun() ->
                                                     tell(Runner, Launch, Subscriber, Address)
                                                 end),
                    MonitorRef = erlang:monitor(process, Teller,
                                                [{tag, {teller, Launch, Subscriber}}]),
                    Acc#{Subscriber => #waited_for{order = Order, site = Site, teller = Teller,
                                                   monitor_ref = MonitorRef}}
                end, Waiting, Untold).

%% Report §11.2: subscribers told once the wait has been said, each said
%% as it is told.
tell_late(Launch, Say, Untold, Waiting) ->
    lists:foreach(fun({_, _, _, Site}) -> Say(["the end waits for ", Site, " too"]) end, Untold),
    tell_all(Launch, Untold, Waiting).

%% Report §11.2: how many subscribers the sites name.
counted([_]) -> "1 subscriber";
counted(Sites) -> [integer_to_list(length(Sites)), " subscribers"].

%% Report §8.6: a subscriber told, `wrap(reply)` delivered to it as a
%% monitor's Down is, the reply's process the teller, which waits on it
%% (§6.6), by a delivery of its own that the teller starts and
%% holds (counted_link/2), a fault in the wrap the subscriber's (§6.5); the
%% call noted first, since the wrap's own calls are the delivery's. The
%% answer is waited for as a caller waits for its callee's, which the
%% subscriber's end or its restart ends (§6.6, §6.9), and either ends the
%% delivery (abandoned/1), one whose wrap does not finish among them.
%% Report §11.2: its end is learned by the runtime's monitor, whose Down the
%% reaper gives once it has reported the subscriber's fault, so that the
%% fault's line comes before the line that it ended without answering; a
%% restart reports its fault before it ends the calls waiting on it
%% (restarts/4). A delivery foreign code kills before it arrives gives no
%% word: the teller ends without one, and the runner, which monitors it,
%% waits for the subscriber no longer (waited/5). Once it has its word it
%% ends, and its monitor goes with it, as the reaper that holds it sees it
%% end (held_ended/3), so that a subscriber that restarts at each telling
%% is told by a teller each time.
tell(Runner, Launch, Subscriber, Address) ->
    {Callee, Reply} = watched(Address),
    Ended = make_ref(),
    monitor(Subscriber, fun(_Down) -> Ended end),
    pending(Callee, Reply),
    %% the delivery's end a message, as the reaper and the clock take their
    %% deliveries' (undelivered/2)
    erlang:process_flag(trap_exit, true),
    Teller = erlang:self(),
    Delivery = counted_link(Address, fun() -> deliver(Address, {Reply, Teller}) end),
    How = told_how(Reply, Ended, Delivery),
    settled(Reply),
    case How of
        none -> ok;
        _ -> Runner ! {said, Launch, Subscriber, How}
    end.

%% How the subscriber was told, or none where its delivery was killed
%% before it arrived. A delivery that ended as it delivered, or that the
%% subscriber's end or restart ended, is followed by the word. The
%% reaper's end, which ends the run, ends the teller.
told_how(Reply, Ended, Delivery) ->
    receive
        {Reply, answered, _} -> <<"answered">>;
        {Reply, _} -> <<"answered">>;
        {Reply, restarted, _} -> <<"restarted without answering">>;
        Ended -> <<"ended without answering">>;
        {'EXIT', Delivery, ExitReason} ->
            case undelivered(Delivery, ExitReason) of
                true -> none;
                false -> told_how(Reply, Ended, Delivery)
            end;
        {'EXIT', _Reaper, ExitReason} ->
            exit(ExitReason)
    end.

%% Where an Os.exit or a second termination cuts the wait short: the
%% subscribers still waited for said, in the order their processes were
%% spawned (report §11.2), their tellers ended, and the mark gone. The
%% host's interrupt cuts it short too, but halts the host at once (bin/ern
%% starts it with +B), so no word of it reaches the runner and nothing is
%% said.
cut_short(Say, Waiting) ->
    Unanswered = lists:sort(maps:values(Waiting)),
    Sites = [Site || #waited_for{site = Site} <- Unanswered],
    Say(["the end was cut short, ", counted(Sites), " unanswered: ", lists:join(", ", Sites)]),
    ets:delete(?LAUNCH, ending),
    lists:foreach(fun(#waited_for{teller = Teller, monitor_ref = MonitorRef}) ->
                      erlang:demonitor(MonitorRef, [flush]),
                      killed(Teller, kill)
                  end, Unanswered).

%% Report §8.6, §11.2: where the sinks pass what they are given to a
%% process of the program's, as the shell's pass it to its screen, what
%% the program wrote while the end waited is written before the end ends
%% that process: standard output and standard error first take what was
%% sent them, and then the runner's `flush` writes what they passed on.
passed_on(System, #{flush := Flush}) ->
    lists:foreach(fun(Name) -> sink_flushed(proplists:get_value(Name, System)) end,
                  [stdout, stderr]),
    Flush();
passed_on(_System, _Options) ->
    ok.

%% Report §8.2, §8.7, §11.2: a line of the toolchain's own on standard
%% error, Line, its line feed ending it. While a launch's standard error
%% process runs, from its start until its launch's end has written the
%% program's output (end_program/4), the line is written by it, as a
%% fault's line is, so that it keeps its place among what the program wrote
%% there: a write the process answers once it has taken the line, under a
%% monitor, so that a line the process never took, the end having stopped
%% it first, is written by Outside. The end stops the process in order
%% (stopped_in_order/1), so that a line it took it has answered, and none
%% is written twice. Before the first launch, between two and after the
%% last, Outside writes it on the job's own. Report §8.6: the wait is on
%% standard error's port, which the look cannot see take the line, and may
%% be a program's process's, an entry process's as its initializers end
%% among them (ern_cli:say_limits/0).
-spec say(binary(), fun((binary()) -> term())) -> ok.
say(Line, Outside) ->
    case launch_field(#launch.stderr, none) of
        none ->
            Outside(Line);
        Stderr ->
            Reply = erlang:monitor(process, Stderr, [{alias, demonitor}]),
            Stderr ! {'Write', Line, {Reply, erlang:self()}},
            entered_foreign(),
            Taken = try
                        receive
                            {Reply, answered, _} -> erlang:demonitor(Reply, [flush]);
                            {'DOWN', Reply, process, _, _} -> false
                        end
                    after
                        left_foreign()
                    end,
            Taken orelse Outside(Line)
    end,
    ok.

%% Report §8.7, §11.2: a line of the toolchain's own said by a process
%% that must not wait for standard error to take it, one of the runtime's
%% own that routes frames or checks a peer, the gateway, the check of a
%% certificate and the port map, or one of the host's: the line goes, in
%% the order its caller says its lines, to a process of the runtime's own,
%% `ern_say_later`, which says each as say/2 says it, so that a slow reader
%% of standard error holds up that process alone. It is started by the
%% first such line and lives the host's life; a launch's end, and the
%% job's, wait for it to have said what it was given (wait_for_later/0).
-spec say_later(binary(), fun((binary()) -> term())) -> ok.
say_later(Line, Outside) ->
    erlang:send(later_sayer(), {say, Line, Outside}),
    ok.

later_sayer() ->
    case erlang:whereis(?SAY_LATER) of
        undefined ->
            Started = erlang:spawn(fun said_later/0),
            try erlang:register(?SAY_LATER, Started) of
                true -> Started
            catch
                %% another caller started it first, and that one stays
                error:badarg -> exit(Started, kill), later_sayer()
            end;
        Sayer ->
            Sayer
    end.

said_later() ->
    receive
        {say, Line, Outside} -> say(Line, Outside);
        {said, From, Ref} -> From ! {Ref, said}
    end,
    said_later().

%% Report §8.7, §11.2: every line given say_later/2 before the call said,
%% or none to wait for where no such line was ever given.
-spec wait_for_later() -> ok.
wait_for_later() ->
    case erlang:whereis(?SAY_LATER) of
        undefined ->
            ok;
        Sayer ->
            MonitorRef = erlang:monitor(process, Sayer),
            Sayer ! {said, erlang:self(), MonitorRef},
            receive
                {MonitorRef, said} -> erlang:demonitor(MonitorRef, [flush]), ok;
                {'DOWN', MonitorRef, process, _, _} -> ok
            end
    end.

%% Report §8.6: a stream that could not be written as the program's output
%% was flushed is what ended the program, in place of what ended it.
outcome_flushed({raised, Class, Error, Stack}, _Gone) -> erlang:raise(Class, Error, Stack);
outcome_flushed({ended, Outcome}, []) -> Outcome;
outcome_flushed({ended, _}, [Stream | _]) -> {gone, Stream}.

%% The tables that hold a launch's state, which the module's header
%% describes and `make load` counts the rows of (docs/memory.md).
-spec tables() -> [atom()].
tables() ->
    [?PROCESSES, ?CALLEES, ?FAULTS, ?TERMINATING, ?HELD, ?DELIVERIES, ?CHECKERS, ?LAUNCH,
     ?OFFERS, ?OFFERED, ?INITIALIZED, ?NOTES].

make_tables() ->
    lists:foreach(fun(Table) -> ets:new(Table, [named_table, public | table_options(Table)]) end,
                  tables()).

%% The callees' and the deliveries' rows are ordered, so that a process
%% reads its own by their key's prefix. Every call writes a callee's row
%% and deletes it (pending/2, uncalled/2), so its table takes the host's
%% write concurrency, which lets calls on one node write it at once. A bag
%% by the callee, which a restart would read by one lookup, walks the
%% callee's rows at each write and delete, so that a crowd of callers
%% makes each call to it many times the host's (the log's *The Sitting on
%% §8.6's Bookkeeping*, its *Measured* paragraphs).
table_options(?CALLEES) -> [ordered_set, {write_concurrency, true}];
table_options(?DELIVERIES) -> [ordered_set];
table_options(?OFFERS) -> [ordered_set];
table_options(?OFFERED) -> [bag];
table_options(?NOTES) -> [ordered_set];
table_options(?PROCESSES) -> [set, {keypos, #process_row.pid}];
table_options(_) -> [set].

%% The reference that tags this launch, under which the runner is known,
%% and which tags the adapted addresses the launch's processes make
%% (launch/0), written with the runner and what the options give the run
%% in the launch's row (#launch{}). Report §11.2: `ern run` reports every
%% fault, the runtime's own subscriber, given here as a function. Report
%% §8.6: a node can be reached from outside, and detects no deadlock.
launched(Options) ->
    persistent_term:erase({?MODULE, holder}),
    Launch = make_ref(),
    true = ets:insert(?LAUNCH, #launch{runner = erlang:self(), tag = Launch,
                                       reporter = maps:get(faults, Options, none),
                                       arguments = maps:get(arguments, Options, []),
                                       exit = maps:get(exit, Options, program),
                                       node = is_map_key(node, Options),
                                       own = maps:get(own, Options, none)}),
    Launch.

%% Report §8.2: the system processes, each bound under its name. Keys come
%% where standard input is a terminal, and from a test's keys.
started_system(Options) ->
    Stdout = maps:get(stdout, Options, fun(Bytes) -> file:write(standard_io, Bytes) end),
    Stderr = maps:get(stderr, Options, fun(Bytes) -> file:write(standard_error, Bytes) end),
    OpenStdin = input(stdin, Options),
    OpenKeys = input(keys, Options),
    KeysCome = maps:is_key(keys, Options) orelse ern_tty:is_terminal(stdin),
    ReadTime = maps:get(time, Options, fun() -> erlang:system_time(millisecond) end),
    System = [{stdout, erlang:spawn(fun() -> stream(Stdout, stdout) end)},
              {stderr, erlang:spawn(fun() -> stream(Stderr, stderr) end)},
              {stdin, erlang:spawn(fun() -> stdin_loop(OpenStdin) end)},
              {fs, erlang:spawn(fun ern_fs:loop/0)},
              {terminal, erlang:spawn(fun() -> ern_tty:loop(OpenKeys, KeysCome) end)},
              {tcp, erlang:spawn(fun ern_tcp:loop/0)},
              {os, erlang:spawn(fun ern_os:loop/0)},
              {clock, erlang:spawn(fun() -> clock(ReadTime) end)}],
    lists:foreach(fun({Name, Pid}) -> persistent_term:put({?MODULE, Name}, Pid) end, System),
    true = ets:update_element(?LAUNCH, launch,
                              {#launch.stderr, proplists:get_value(stderr, System)}),
    System.

%% The entry process's outcome. Report §8.5: the initializers, the
%% standard library's first, run in main's process, so one that faults is
%% the program's fault; its modules are loaded here, where their order is
%% read from them. Report §6.9: the runner's monitor is made with the
%% spawn, so the entry process's cause, and the trace beside a fault
%% (§7.3, §11.2), reach it however soon the process ends.
%% Report §8.5, §11.2: an initializer's fault is reported under its
%% binding, and main's under main's site again once they have run.
entry_outcome(EntryPoint, Site, Options, Launch) ->
    Stdlib = stdlib_modules(),
    Init = maps:get(init, Options, fun() -> ok end),
    Node = maps:get(node, Options, fun() -> ok end),
    Entry = fun() ->
                %% report §8.6: the reaper asks whether it has died
                ets:insert(?LAUNCH, {entry_process, erlang:self()}),
                run_inits(Stdlib),
                Init(),
                %% report §8.7, §7.4: a node listens once its bindings
                %% have their values, a carrier that cannot start faulting
                %% the entry process, under its own site (§6.9)
                initializing(Site),
                Node(),
                EntryPoint()
            end,
    EntryProcess = spawn_with_monitors(Entry, Site,
                                       [{erlang:self(),
                                         #monitor{wrap = {raw, {entry_down, Launch}}}}], chained),
    case entry_end(EntryProcess, Launch) of
        {{fault, Cause, Trace}, FaultSite} when FaultSite =/= Site ->
            {initializer_fault, FaultSite, Cause, Trace};
        {Outcome, _} ->
            Outcome
    end.

%% The entry process's end, and its site then. Report §8.6, §8.2: a
%% deadlock, and a fault the runtime finds in a system process's work, fault
%% the entry process, whose end then comes as any process's does, reported
%% as every fault is (§11.2).
entry_end(EntryProcess, Launch) ->
    receive
        {{entry_down, Launch}, Site, ExitReason} ->
            {case {reason(ExitReason), ExitReason} of
                 {'Returned', _} -> ok;
                 {'Killed', _} -> killed;
                 {{'Fault', Cause}, {ern, fault, _, Trace}} -> {fault, Cause, Trace};
                 %% report §6.9: the host ended it, and no trace was kept
                 {{'Fault', Cause}, _} -> {fault, Cause, <<>>};
                 {Other, _} -> {fault, format("~p", [Other]), <<>>}
             end, Site};
        {deadlock, Launch} ->
            found_fault(EntryProcess, <<"deadlock">>),
            entry_end(EntryProcess, Launch);
        {fault, Launch, Cause} ->
            found_fault(EntryProcess, Cause),
            entry_end(EntryProcess, Launch);
        {exit, Launch, Status} ->
            {{exit, Status}, none};
        {gone, Launch, Stream} ->
            {{gone, Stream}, none};
        {signal, Launch, Signal} ->
            {{signal, Signal}, none}
    end.

%% Report Appendix E.23: the words after the module on `ern run`'s command
%% line, which the runner was given; none in the shell and under `ern
%% test` (§11.2).
-spec arguments() -> [binary()].
arguments() ->
    launch_field(#launch.arguments, []).

%% Report §8.6, Appendix E.23: Os.exit ends the program with its status,
%% the runner ending every process as it does at the entry process's end;
%% the caller waits for its own end there, inside foreign code for the
%% look, since the runner brings it (entered_foreign/0). In the shell and
%% under `ern test` it faults the caller instead (§11.2).
-spec exit_program(integer()) -> no_return().
exit_program(Status) ->
    case Status >= 0 andalso Status =< 255 of
        true -> ok;
        false -> fault(<<"an exit status is from 0 to 255">>)
    end,
    case launch_field(#launch.exit, program) of
        fault ->
            fault(format("exited with status ~B", [Status]));
        program ->
            {Runner, Launch} = launch_runner(),
            Runner ! {exit, Launch, Status},
            entered_foreign(),
            receive after infinity -> ok end
    end.

input(Key, Options) ->
    case maps:find(Key, Options) of
        {ok, Next} -> fed(Next);
        error -> fun open_input/0
    end.

%% Report §8.2: standard output and standard error are written as the
%% bytes a program sends, UTF-8 text among them, so the host's streams take
%% bytes as they are while the program's streams run, from their start
%% until what was sent them is written; what they took before is put back
%% then (end_program/4).
bytes_out() ->
    lists:foldr(fun(Device, Taken) ->
                    case encoding(Device) of
                        none -> Taken;
                        Encoding ->
                            case io:setopts(Device, [{encoding, latin1}]) of
                                ok -> [{Device, Encoding} | Taken];
                                _ -> Taken
                            end
                    end
                end, [], [standard_io, standard_error]).

encoding(Device) ->
    try proplists:get_value(encoding, io:getopts(Device), none)
    catch _:_ -> none
    end.

restore_encodings(Encodings) ->
    lists:foreach(fun({Device, Encoding}) -> io:setopts(Device, [{encoding, Encoding}]) end,
                  Encodings).

%% Report §11.2: under `ern test` a deadlock is the fault of the test that
%% runs, not of the entry process; none after the test has ended.
-spec deadlock_victim(pid() | none) -> ok.
deadlock_victim(none) ->
    ets:delete(?LAUNCH, deadlock_victim),
    ok;
deadlock_victim(Pid) ->
    ets:insert(?LAUNCH, {deadlock_victim, Pid}),
    ok.

%% Report §11.2: the entry process of the launch in progress, by which
%% `ern test` knows its fault in a doc example's launch, where the
%% example's line carries it; none outside a launch.
-spec entry_process() -> pid() | none.
entry_process() ->
    case ets_lookup(?LAUNCH, entry_process) of
        [{_, Pid}] -> Pid;
        [] -> none
    end.

%% Report §8.6: the host's termination or hangup ends the run in progress
%% as the end of its entry process does; none when no run is in progress.
-spec signal(sigterm | sighup) -> ok | none.
signal(Signal) ->
    case ets_lookup(?LAUNCH, launch) of
        [#launch{runner = Runner, tag = Launch}] ->
            case erlang:is_process_alive(Runner) of
                true -> Runner ! {signal, Launch, Signal}, ok;
                false -> none
            end;
        [] ->
            none
    end.

%% Report §8.5, §11.2: the binding the calling process evaluates now, whose
%% site a fault while it does is reported under, as a spawn's is; a process
%% the runtime did not start has no site to change. Report §6.9: a process
%% of the runtime's own that acts for another keeps it in what stands for
%% its row (#acting{}), since a Code.load called in it evaluates there, and
%% the row of the process it acts for is that process's own.
-spec initializing(binary()) -> 'Unit'.
initializing(Site) ->
    case erlang:get(?ACTING) of
        undefined ->
            try ets:update_element(?PROCESSES, erlang:self(), {#process_row.site, Site}) of
                _ -> ?UNIT
            catch
                error:badarg -> ?UNIT
            end;
        Acting ->
            _ = erlang:put(?ACTING, Acting#acting{site = Site}),
            ?UNIT
    end.

%% The calling process's site, empty for one the runtime did not start.
-spec site() -> binary().
site() ->
    case erlang:get(?ACTING) of
        undefined ->
            case ets_lookup(?PROCESSES, erlang:self()) of
                [#process_row{site = Site}] -> Site;
                _ -> <<>>
            end;
        #acting{site = Site} ->
            Site
    end.

%% Report §8.5, §11.2: a top-level binding's value, which '$init'/0 put.
%% One that has none, since a binding before it faulted when the shell
%% loaded its module, faults its reader (§7.4).
-spec binding(term()) -> term().
binding(Key) ->
    case persistent_term:get(Key, '$unevaluated') of
        '$unevaluated' -> fault(<<"the binding has no value, since one before it faulted">>);
        Value -> Value
    end.

%% Report §8.7: a top-level binding's value, kept under Key, in the run in
%% progress, as a peer's spawn finds it (ern_code:absent_binding/2): its
%% value where the initializers of its unit have run, and absent where they
%% have not, or where a binding before it faulted (§8.5, §11.2).
-spec binding_value(module(), term()) -> {value, term()} | absent.
binding_value(Unit, Key) ->
    case is_initialized(Unit) of
        true ->
            case persistent_term:get(Key, '$unevaluated') of
                '$unevaluated' -> absent;
                Value -> {value, Value}
            end;
        false ->
            absent
    end.

%% Report §8.7, §11.2: whether a unit's initializers have run in the run in
%% progress, by the run's start or the shell's load or reload, so that the
%% code table answers a peer from a unit whose bindings have their values
%% (ern_code). Outside a run there is no table, and none has.
-spec is_initialized(module()) -> boolean().
is_initialized(Unit) ->
    try ets:member(?INITIALIZED, Unit) catch error:badarg -> false end.

%% Report §6.9: a function that runs F, and on a fault runs it again in the
%% same process, until the limit's restarts within its milliseconds have
%% happened, when the next fault ends the process with its cause, or after
%% every fault where the limit is Unlimited. Only a fault restarts, or a
%% restart asked for (restartable/0): a kill and the program's end are exit
%% signals, which no try catches, and F returning ends it as any process
%% ends.
-spec restarting({'RestartLimit', integer(), integer()} | 'Unlimited', fun(() -> term())) ->
          fun(() -> term()).
restarting(Limit, F) ->
    Allowed = case Limit of
                  'Unlimited' -> unlimited;
                  {'RestartLimit', Restarts, Within} -> {max(Restarts, 0), max(Within, 1)}
              end,
    fun() ->
        Level = restartable(),
        try
            restarts(F, Allowed, [], Level)
        after
            Level =:= outer andalso unrestartable()
        end
    end.

%% Report §6.9, Appendix E.22: a restarting process can be asked to restart,
%% by a priority message to an alias of its own, taken before its other
%% messages at its next wait. The outermost restarting function of the
%% process is the one asked, and the one whose start start_cause/0 tells;
%% one nested in it is neither. The outermost puts its start cause and the
%% alias in the process's own dictionary (?START), where the process reads
%% whether a restarting function runs and a supervisor finds the alias
%% (ask_restart/1).
restartable() ->
    case get(?START) of
        undefined ->
            _ = put(?START, {'First', erlang:alias([priority])}),
            outer;
        _ ->
            inner
    end.

%% The outermost restarting function begins again, for Cause.
started_again(Cause) ->
    {_, Alias} = get(?START),
    _ = put(?START, {Cause, Alias}),
    ok.

%% The outermost restarting function has ended: the process is no longer
%% asked to restart.
unrestartable() ->
    {_, Alias} = erase(?START),
    erlang:unalias(Alias),
    %% a request that came as the function returned is not taken later
    receive '$ern_restart' -> ok after 0 -> ok end.

%% Report §6.9: the clause every wait has for a restart asked for.
-spec restart_now() -> no_return().
restart_now() ->
    throw('$ern_restart').

%% Appendix E.22: the supervisor's request that a child restart, and
%% whether it was made; a process that has ended, or has not yet begun to
%% run what restarts, is not asked, and the supervisor waits for none such.
%% The alias is read of the child's dictionary (restartable/0), a question
%% the supervisor asks only as a group restarts. A child runs on its
%% supervisor's node (§8.7).
-spec ask_restart(pid()) -> boolean().
ask_restart(Pid) when node(Pid) =:= node() ->
    case erlang:process_info(Pid, {dictionary, ?START}) of
        {_, {_, Alias}} ->
            erlang:send(Alias, '$ern_restart', [priority]),
            true;
        _ ->
            false
    end.

%% Appendix E.22: why the restarting function the caller runs in began:
%% the first time, after a fault, or because it was asked.
-spec start_cause() -> 'First' | 'AfterFault' | 'Asked'.
start_cause() ->
    case get(?START) of
        undefined -> 'First';
        {Cause, _} -> Cause
    end.

%% Appendix E.22: whether a restarting function already runs in the calling
%% process, its outermost one, which a child's function would nest in: the
%% outermost's start cause stands while it runs (restartable/0).
-spec is_restarting() -> boolean().
is_restarting() ->
    get(?START) =/= undefined.

%% Appendix E.22: whether a process runs on the caller's node, where a
%% supervisor and its children run (§8.7).
-spec on_this_node(pid()) -> boolean().
on_this_node(Pid) ->
    node(Pid) =:= node().

%% Appendix E.22: where a process stands in the order the runtime spawned
%% its processes, 0 for one it did not start, which stands first.
-spec spawn_order(pid()) -> non_neg_integer().
spawn_order(Pid) ->
    case ets_lookup(?PROCESSES, Pid) of
        [#process_row{spawn_order = SpawnOrder}] -> SpawnOrder;
        _ -> 0
    end.

restarts(F, Allowed, Times, Level) ->
    try
        F()
    catch
        throw:'$ern_restart' when Level =:= outer ->
            %% report §6.9: a restart asked for is no fault, counts against
            %% no limit, and is not reported; the calls waiting on the
            %% process end as at a fault
            started_again('Asked'),
            fresh_run(),
            restarted(asked),
            tell_service_monitors(),
            restarts(F, Allowed, Times, Level);
        throw:'$ern_restart' ->
            throw('$ern_restart');
        Class:Error:Stack ->
            Fault = met(Class, Error, Stack),
            %% report §8.6: a fault as the program ends is not restarted
            %% and not reported; the process ends with the program
            is_program_ending(erlang:self()) andalso end_with_program(),
            case within_limit(Allowed, Times) of
                {true, Recent} ->
                    %% report §11.2: a fault after which the process
                    %% restarts is reported as one
                    launch_reaper() ! {report, erlang:self(), site(), Fault},
                    fresh_run(),
                    restarted({fault, Fault#fault.cause}),
                    tell_service_monitors(),
                    Level =:= outer andalso started_again('AfterFault'),
                    restarts(F, Allowed, Recent, Level);
                false ->
                    %% raised again as the fault it is, for run/1 to end the
                    %% process with, its trace and its moment kept
                    throw({ern, Fault})
            end
    end.

%% Report §6.9: a restart begins a new run with nothing of the old. What
%% the process asked the runtime for is canceled, with what is on its way
%% to it: its monitors and its subscriptions to faults and to the program's
%% end by the reaper, its alarms by the clock, its keys by the terminal;
%% then its mailbox is emptied, before the calls waiting on it are told
%% they have ended (restarted/1), so that the request of an ended call is
%% not taken by the new run, and before its service monitors are told
%% (tell_service_monitors/0), so that what a watcher sends once it has its
%% Restarted is the new run's. The three and the gateway are asked at
%% once, and each is monitored, so that one that has died holds up no
%% restart. Each takes the restart in its own order: a delivery the clock
%% starts after the reaper has taken it, an alarm of the old run's, may
%% ask for a monitor the reaper makes; the clock's end of the delivery
%% takes the monitor with it, and one the delivery made and returned from
%% before the clock took the restart stands into the new run
%% (monitor_asked/5).
fresh_run() ->
    Self = erlang:self(),
    Asked = [begin
                 MonitorRef = erlang:monitor(process, Pid),
                 Pid ! {new_run, Self, MonitorRef},
                 MonitorRef
             end || Pid <- [launch_reaper(), system_process(clock), system_process(terminal)]
                            ++ gateway()],
    %% report §8.6: an answer on its way from a system process is no
    %% message the look sees in flight, and a delivery waited for is a
    %% source until it ends
    entered_foreign(),
    try
        lists:foreach(fun(MonitorRef) ->
                          receive
                              {MonitorRef, fresh} -> erlang:demonitor(MonitorRef, [flush]);
                              {'DOWN', MonitorRef, process, _, _} -> true
                          end
                      end, Asked),
        emptied()
    after
        left_foreign()
    end.

%% Report §6.9: the restarting process's service monitors told, once its
%% mailbox is emptied and the calls waiting on it have ended: the reaper
%% places each one's Restarted through a delivery of its own
%% (delivered_restart/2), and the process waits until each has ended before
%% the new run begins, so that the Restarted reaches its watcher before
%% anything the new run sends; a wrap that does not finish holds up the
%% restart. The reaper is monitored, so that one that has died holds up no
%% restart. Report §8.6: a delivery waited for is a source until it ends.
tell_service_monitors() ->
    Reaper = launch_reaper(),
    ReaperRef = erlang:monitor(process, Reaper),
    Reaper ! {tell_service_monitors, erlang:self(), ReaperRef},
    entered_foreign(),
    try
        Told = receive
                   {ReaperRef, told, Deliveries} ->
                       erlang:demonitor(ReaperRef, [flush]),
                       Deliveries;
                   {'DOWN', ReaperRef, process, _, _} ->
                       []
               end,
        lists:foreach(fun(Delivery) ->
                          MonitorRef = erlang:monitor(process, Delivery),
                          receive {'DOWN', MonitorRef, process, _, _} -> ok end
                      end, Told)
    after
        left_foreign()
    end.

emptied() ->
    receive
        _ -> emptied()
    after 0 -> ok
    end.

%% Report §8.7: a node's gateway, by the name it registers (ern_gateway),
%% or none before it starts and in a program that is no node, the one
%% place its process is found; a restart asks it too, so that every call's
%% note that came before it is recorded when the restart reads them.
-spec gateway() -> [pid()].
gateway() ->
    case erlang:whereis(ern_gateway) of
        undefined -> [];
        Gateway -> [Gateway]
    end.

%% Report §6.9: whether a fault now is restarted, and the times of the
%% restarts within the window then; Unlimited keeps no time.
within_limit(unlimited, _) ->
    {true, []};
within_limit({Restarts, Within}, Times) ->
    Now = erlang:monotonic_time(millisecond),
    Recent = [Time || Time <- Times, Now - Time < Within],
    case length(Recent) < Restarts of
        true -> {true, [Now | Recent]};
        false -> false
    end.

%% Report §6.6, §6.9: a restart ends every call waiting on the process, each
%% caller told how, `asked` or `{fault, Cause}`, which a callForever faults
%% with as it says (call_forever/3). Report §8.7: a compute's process that
%% restarts runs its function again, and its caller waits on for the value,
%% so its row is no call the restart ends.
restarted(How) ->
    Self = erlang:self(),
    Callers = try ets:select(?CALLEES, [{{{Self, '$1'}, '$2'}, [{is_reference, '$2'}],
                                         [{{'$1', '$2'}}]}])
              catch _:_ -> []
              end,
    lists:foreach(fun({Caller, Reply}) ->
                      ets:delete(?CALLEES, {Self, Caller}),
                      %% report §8.7: a caller of another node's note, used
                      ets:delete(?NOTES, {node(Reply), Reply}),
                      Reply ! {Reply, restarted, How}
                  end, Callers).

%% Report §8.6: every local process ends with ProgramEnd, the sinks' output
%% is flushed, the system processes and the reaper are stopped, and the
%% terminal goes back as the program found it (§8.2). The answer is the
%% streams that could not be flushed, standard output's first.
end_program(Launch, Reaper, System, Encodings) ->
    Ref = make_ref(),
    MonitorRef = erlang:monitor(process, Reaper),
    Reaper ! {end_program, erlang:self(), Ref},
    receive
        {Ref, ended} ->
            ok;
        {'DOWN', MonitorRef, process, _, _} ->
            lists:foreach(fun(#process_row{pid = Pid}) -> exit(Pid, {ern, program_end}) end,
                          live_rows())
    end,
    erlang:demonitor(MonitorRef, [flush]),
    Gone = [Name || Name <- [stdout, stderr],
                    sink_flushed(proplists:get_value(Name, System)) =:= gone],
    %% report §8.2, §8.7, §11.2: the program's output written, and the
    %% lines said later during the launch (say_later/2), the host's streams
    %% take text again, and a line of the toolchain's own said from here on
    %% goes to the job's own standard error (say/2); the streams are
    %% stopped in order, so that a line sent the moment before is written
    %% by standard error's process where it came before the stop, and by
    %% its sayer where it came after
    wait_for_later(),
    restore_encodings(Encodings),
    true = ets:update_element(?LAUNCH, launch, {#launch.stderr, none}),
    {Streams, Others} = lists:partition(fun({Name, _}) -> lists:member(Name, [stdout, stderr]) end,
                                        System),
    lists:foreach(fun({_, Pid}) -> stopped_in_order(Pid) end, Streams),
    %% each ended before the table goes, which the reaper reads
    lists:foreach(fun stop/1, [Pid || {_, Pid} <- Others] ++ [Reaper]),
    case ets:lookup(?LAUNCH, reading) of
        [{reading, keys}] -> ern_tty:restore();
        _ -> ok
    end,
    %% the launch's row goes with its table, so that a signal after the run
    %% has nothing to end (signal/1), and an adapted address the run made
    %% is dead (adapted_way/2)
    lists:foreach(fun ets:delete/1, tables()),
    flush_launch(Launch),
    Gone.

%% A sink's pending output written, or the stream gone (stream/2).
sink_flushed(Sink) ->
    Ref = make_ref(),
    MonitorRef = erlang:monitor(process, Sink),
    Sink ! {flush, erlang:self(), Ref},
    %% a sink that died has nothing left to flush, and waiting for it would
    %% hold the program open
    Flushed = receive
                  {Ref, Answer} -> Answer;
                  {'DOWN', MonitorRef, process, _, _} -> flushed
              end,
    erlang:demonitor(MonitorRef, [flush]),
    Flushed.

%% Report §8.5: a standard library module's top-level lets, `Map.empty`
%% among them, are evaluated once at program start like any other module's;
%% the runner initializes the program's own modules, the runtime these,
%% which are build output beside the toolchain rather than modules of the
%% load path.
-spec init_stdlib() -> ok.
init_stdlib() ->
    run_inits(stdlib_modules()).

%% The standard library's modules, loaded, in the order their initializers
%% run: one for every `.erc` of the library's directory, as the checker
%% finds them (ern_prelude:stdlib_files/0), by the Erlang name its file's
%% name gives it (report §11.1), each where the host holds none of it
%% loaded from its file and put in the code table as it loads (§8.7), so
%% that a node holds every definition of the library. The shell's modules
%% are not the standard library's; the shell initializes them as a
%% program's own (init_modules/1). A test that calls the library outside a
%% run loads it so.
-spec stdlib_modules() -> [module()].
stdlib_modules() ->
    ordered([stdlib_module(File) || File <- ern_prelude:stdlib_files()]).

%% A module of the standard library, loaded; one that cannot be loaded is a
%% broken build of the toolchain, said as such.
stdlib_module(File) ->
    ErlangModule = ern_namespace:erlang_module(
                     ern_namespace:namespace([filename:basename(File, ".erc")])),
    case ern_code:ensure_loaded(ErlangModule) of
        {module, ErlangModule} -> ErlangModule;
        {error, Error} -> error({broken_standard_library, File, Error, "rebuild it with make"})
    end.

%% Report §8.5: the top-level lets of the modules given and of the modules
%% they depend on through `'$deps'/0`, dependencies first, each module once;
%% the order of the list is kept where no dependency decides it. Report
%% §8.5, §11.2: a fault while a binding is evaluated is reported under the
%% binding's site, so the caller's own site is put back once the bindings
%% have their values; the measuring machine's deadlock was once reported
%% under the last library binding's, a Test.Case that waits on nothing.
-spec init_modules([module()]) -> ok.
init_modules(ErlangModules) ->
    {Order, _} = lists:foldl(fun(ErlangModule, Acc) ->
                                 visit(ErlangModule, all, Acc)
                             end, {[], #{}}, ErlangModules),
    Site = site(),
    run_inits(lists:reverse(Order)),
    _ = initializing(Site),
    ok.

run_inits(ErlangModules) ->
    lists:foreach(fun(ErlangModule) ->
                      case erlang:function_exported(ErlangModule, '$init', 0) of
                          true -> ErlangModule:'$init'();
                          false -> ok
                      end,
                      initialized(ErlangModule)
                  end, ErlangModules).

%% Report §8.7, §11.2: a unit whose top-level bindings have been
%% evaluated, by a run's start or the shell's load, so that a peer's spawn
%% finds their values. A caller outside a run, a test's, has no table.
-spec initialized(module()) -> ok.
initialized(Unit) ->
    try ets:insert(?INITIALIZED, {Unit}) catch error:badarg -> true end,
    ok.

declared_dependencies(ErlangModule) ->
    case erlang:function_exported(ErlangModule, '$deps', 0) of
        true -> ErlangModule:'$deps'();
        false -> []
    end.

%% Report §8.7: an offer of a service, its name and its type's hash, of an
%% address of this node's, for as long as its process lives: `Right(Unit)`
%% where it took the service, and `Left(Holder)`, the process whose address
%% is offered as it, where that process lives; an address of another node's
%% process faults the caller. The row of a holder that has ended stands
%% until the reaper learns of the end, and is taken by one offer alone, so
%% that two offers never both take a service.
-spec offer({binary(), binary()}, address()) -> {'Right', 'Unit'} | {'Left', pid()}.
offer(Service, Address) ->
    Process = process_of(Address),
    node(Process) =:= node() orelse fault(<<"a node offers only its own processes">>),
    case ets:insert_new(?OFFERS, {Service, Address, Process}) of
        true ->
            held_while_alive(Service, Process),
            {'Right', ?UNIT};
        false ->
            case ets:lookup(?OFFERS, Service) of
                [{_, _, Holder} = Row] ->
                    case erlang:is_process_alive(Holder) of
                        true ->
                            {'Left', Holder};
                        false ->
                            ets:delete_object(?OFFERS, Row),
                            offer(Service, Address)
                    end;
                [] ->
                    offer(Service, Address)
            end
    end.

%% Report §8.7: the offer's process holds the service while it lives, its
%% end ending the offer (unoffered/1). A process that ended before its row
%% of services was written may have been read by the reaper already, so its
%% offer goes here.
held_while_alive(Service, Process) ->
    ets:insert(?OFFERED, {Process, Service}),
    watch(Process),
    erlang:is_process_alive(Process) orelse unoffered(Process).

%% The reaper watches every process the runtime started or opened, and is
%% asked to watch any other that holds an offer or a call's note, so that
%% they end with it.
watch(Pid) ->
    case {ets:member(?PROCESSES, Pid), launch_reaper()} of
        {false, Reaper} when is_pid(Reaper) -> Reaper ! {watch, Pid};
        _ -> ok
    end.

%% Report §8.7: what this node offers under a name at a type's hash: the
%% address, or `OtherType` where it offers the name at a type of another
%% hash only, or `NotOffered`.
-spec offered(binary(), binary()) -> {found, address()} | 'OtherType' | 'NotOffered'.
offered(Name, Hash) ->
    case ets:lookup(?OFFERS, {Name, Hash}) of
        [{_, Address, _}] ->
            {found, Address};
        [] ->
            case ets:select(?OFFERS, [{{{Name, '_'}, '_', '_'}, [], [true]}], 1) of
                {[_], _} -> 'OtherType';
                '$end_of_table' -> 'NotOffered'
            end
    end.

%% Report §8.7, Appendix E.27: the utilization a program set with
%% `Peer.setUtilization`, which its node tells its peers and answers them
%% until the program sets it again or its run ends: a row of the launch's,
%% so that each launch begins with none, and its node tells the measure its
%% configuration names before the first and between two runs (§11.2).
-spec set_utilization(float()) -> ok.
set_utilization(Utilization) ->
    true = ets:insert(?LAUNCH, {utilization, Utilization}),
    ok.

%% The utilization the program set, or none: none set, or no launch in
%% progress, between two launches of `ern test` over a directory, in one
%% host.
-spec program_utilization() -> float() | none.
program_utilization() ->
    case ets_lookup(?LAUNCH, utilization) of
        [{utilization, Utilization}] -> Utilization;
        [] -> none
    end.

%% Report §8.7: what a peer's frame asks of the run in progress, answered
%% by its reaper, which ends before the run's tables go (end_program/4), so
%% that no answer reads a table that is gone: what this node offers under a
%% name at a type's hash (offered/2), or a process started on this node for
%% the peer of node Peer, as spawn/2 starts one but heading a chain of its
%% own, where every binding of the function's reach, each by its identity,
%% has its value here as the code of the unit that runs it reads it, else
%% `{absent, Binding}`, the first that has none; or a process started so
%% for a compute, which runs the function for its caller, or `over` where
%% its note has gone (is_noted/2). None where
%% no run is in progress, its reaper ended or not yet begun: as a run ends,
%% and between two runs of `ern test` over a directory, in one host. The
%% gateway's worker that asks waits on the reaper's end as well as on its
%% answer, since a frame comes at any time.
-spec asked_of_run({offered, binary(), binary()}
                   | {spawn, fun(() -> term()), module(), [{[atom()], binary()}], binary(),
                      node()}
                   | {compute, fun(() -> term()), module(), [{[atom()], binary()}], binary(),
                      node(), pid(), reference()}) ->
          {answered, term()} | none.
asked_of_run(Question) ->
    case launch_reaper() of
        none ->
            none;
        Reaper ->
            MonitorRef = erlang:monitor(process, Reaper),
            Ref = make_ref(),
            Reaper ! {asked, erlang:self(), Ref, Question},
            receive
                {Ref, Answer} ->
                    erlang:demonitor(MonitorRef, [flush]),
                    {answered, Answer};
                {'DOWN', MonitorRef, process, _, _} ->
                    none
            end
    end.

answer_of_run({offered, Name, Hash}) -> offered(Name, Hash).

%% Report §8.7: a process's offers end with it.
unoffered(Pid) ->
    lists:foreach(fun({_, Service}) ->
                      ets:select_delete(?OFFERS, [{{Service, '_', Pid}, [], [true]}])
                  end, ets:take(?OFFERED, Pid)).

%% Report §8.7: a call's note, which the gateway records as it comes: the
%% caller of another node waits on a process of this one, with the reply,
%% beside its row of CALLEES, which a restart reads. A callee that has
%% already ended takes none, since its end, which drops its notes, came
%% before; one that ends after the row is written finds it, a process the
%% runtime did not start among them, which the reaper is asked to watch.
-spec note_call(pid(), pid(), reference()) -> ok.
note_call(Callee, Caller, Reply) ->
    ets:insert(?CALLEES, {{Callee, Caller}, Reply}),
    ets:insert(?NOTES, {{node(Reply), Reply}, Callee, Caller}),
    case erlang:is_process_alive(Callee) of
        true -> watch(Callee);
        false -> dropped_note(Reply)
    end,
    ok.

%% Report §8.7: the second note, that the call is over; a compute's
%% process is killed by it where it still runs.
-spec drop_note(reference()) -> ok.
drop_note(Reply) ->
    case ets:take(?NOTES, {node(Reply), Reply}) of
        [{_, Callee, Caller}] ->
            case ets:take(?CALLEES, {Callee, Caller}) of
                [{_, {compute, _}}] -> killed(Callee, {ern, killed});
                _ -> true
            end;
        [] ->
            true
    end,
    ok.

%% Report §8.7: a compute's frame, which the gateway records as it comes,
%% in the order the call's notes came, as the call's first note: the caller
%% of another node waits with the alias, and the process that runs the
%% function is not yet started (is_noted/2).
-spec note_compute(pid(), reference()) -> ok.
note_compute(Caller, Alias) ->
    ets:insert(?NOTES, {{node(Alias), Alias}, none, Caller}),
    ok.

%% Report §8.7: a compute this node starts no process for answered, its
%% note let go as an answer given here lets it go: `NotLoaded`,
%% `Other(text)` with this node's reason where the exchange brought its
%% function and it did not run it, or `Unreachable` where no launch is in
%% progress to start it. Between two launches there is no table, and no
%% note.
-spec computed(reference(), 'NotLoaded' | 'Unreachable' | {'Other', binary()}) -> ok.
computed(Alias, Error) ->
    try dropped_note(Alias) catch error:badarg -> false end,
    Alias ! {Alias, failed, Error},
    ok.

%% Report §8.7, §11.2: whether a launch is in progress, its reaper living,
%% which a peer's question asks of: between two launches of `ern test` over
%% a directory, in one host, none is.
-spec is_launched() -> boolean().
is_launched() ->
    case launch_reaper() of
        none -> false;
        Reaper -> erlang:is_process_alive(Reaper)
    end.

%% Report §8.7: a loss drops every note of the peer.
-spec drop_notes(node()) -> ok.
drop_notes(Node) ->
    lists:foreach(fun({_, Callee, Caller}) -> ets:delete(?CALLEES, {Callee, Caller}) end,
                  ets:select(?NOTES, [{{{Node, '_'}, '_', '_'}, [], ['$_']}])),
    ets:select_delete(?NOTES, [{{{Node, '_'}, '_', '_'}, [], [true]}]),
    ok.

%% Whether the reply's note was here, and is gone with its row.
dropped_note(Reply) ->
    case ets:take(?NOTES, {node(Reply), Reply}) of
        [{_, Callee, Caller}] -> ets:delete(?CALLEES, {Callee, Caller});
        [] -> false
    end.

%% Report §8.7: a callee's end drops the notes of its callers of other
%% nodes, whose monitors tell them; its own node's callers drop their rows.
%% A compute's process that ends before it answers, killed or with the
%% program, tells its caller how through the note, since the caller
%% watches no process of this node, whichever node the caller's is; one
%% whose note has gone tells no one. The callee's rows are read by their
%% key's prefix alone and told apart here, a read the host makes in less
%% time than one that tests each row (the log's *The Numbers Across Machines*).
drop_callee_notes(Pid, ExitReason) ->
    Callers = ets:select(?CALLEES, [{{{Pid, '$1'}, '$2'}, [], [{{'$1', '$2'}}]}]),
    lists:foreach(fun({Caller, {compute, Alias}}) ->
                          ets:delete(?CALLEES, {Pid, Caller}),
                          case ets:take(?NOTES, {node(Alias), Alias}) of
                              [_] -> Alias ! {Alias, ended, reason(ExitReason)};
                              [] -> ok
                          end;
                     ({Caller, Reply}) when node(Caller) =/= node() ->
                          ets:delete(?CALLEES, {Pid, Caller}),
                          ets:delete(?NOTES, {node(Reply), Reply});
                     ({_, _}) ->
                          ok
                  end, Callers).

%% Report §8.5: dependency order, which each compiled module declares as
%% `'$deps'/0`; the order within an independent set is unspecified, and
%% is the order given, for the standard library its files' alphabetical
%% one (ern_prelude:stdlib_files/0).
-spec ordered([module()]) -> [module()].
ordered(ErlangModules) ->
    {Order, _} = lists:foldl(fun(ErlangModule, Acc) ->
                                 visit(ErlangModule, ErlangModules, Acc)
                             end, {[], #{}}, ErlangModules),
    lists:reverse(Order).

visit(ErlangModule, ErlangModules, {Order, Seen}) ->
    case Seen of
        #{ErlangModule := _} ->
            {Order, Seen};
        _ ->
            Dependencies = [Dependency || Dependency <- dependencies_of(ErlangModule),
                                          ErlangModules =:= all
                                              orelse lists:member(Dependency, ErlangModules)],
            {Order1, Seen1} = lists:foldl(fun(Dependency, Acc) ->
                                              visit(Dependency, ErlangModules, Acc)
                                          end,
                                          {Order, Seen#{ErlangModule => true}}, Dependencies),
            {[ErlangModule | Order1], Seen1}
    end.

%% A module, loaded as the error handler loads one (load/1), the host's
%% work, which the look reads on top of the stack of the entry process
%% that init_modules/1 runs in (report §8.6).
dependencies_of(ErlangModule) ->
    load(ErlangModule),
    declared_dependencies(ErlangModule).

stop(Pid) ->
    MonitorRef = erlang:monitor(process, Pid),
    exit(Pid, kill),
    receive {'DOWN', MonitorRef, process, Pid, _} -> ok end.

%% A stream stopped after what was sent it before the stop, which it has
%% written or, where its stream has gone, dropped (stream/2): a write it
%% takes it answers, and one that comes after the stop finds it ended.
stopped_in_order(Pid) ->
    MonitorRef = erlang:monitor(process, Pid),
    Pid ! stop,
    receive {'DOWN', MonitorRef, process, Pid, _} -> ok end.

%% What the reaper, the system processes and a signal may still send about
%% this run after it ended.
flush_launch(Launch) ->
    receive
        {{entry_down, Launch}, _, _} -> flush_launch(Launch);
        {deadlock, Launch} -> flush_launch(Launch);
        {fault, Launch, _} -> flush_launch(Launch);
        {exit, Launch, _} -> flush_launch(Launch);
        {gone, Launch, _} -> flush_launch(Launch);
        {signal, Launch, _} -> flush_launch(Launch);
        {subscribed, Launch, _} -> flush_launch(Launch);
        {said, Launch, _, _} -> flush_launch(Launch)
    after 0 ->
        ok
    end.

format(Format, Args) ->
    unicode:characters_to_binary(io_lib:format(Format, Args)).
