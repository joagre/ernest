%% The shell's front end (report §11.2): the toolchain behind the foreign
%% interface the shell in `src/shell/` calls. An input is a module of its
%% own, `$Input<s>_<n>`, checked against the node's modules and the session,
%% compiled, and run in a process of its own; the value is printed by E.1's
%% printer, which `Io.debug` uses, over the descriptor of the input's type.
%% An expression and a `let` are the module's entry point, and what the
%% input declares is the module's declarations.
%%
%% Sessions are many on a node, each with the number the node gives it once
%% in its life (report §11.2), which every host name an input makes carries:
%% what is a session's is kept under the root of its processes, and the
%% modules the sessions load are the node's, which each session's next input
%% is checked against. A session reads its source root's files through its
%% shell's local half, which holds the operator's files (source_access/1).
%%
%% The shape is docs/design/shell.md's.
-module(ern_shell).

-export([loaded/1, start/6, number/1, reloaded_by/3, spawn_program/0, config_startup/0,
         given_source_root/0, attach_to/0, say_end/1, is_same_file/2, needs_more/1,
         opening/1, check/3, check_type/3,
         is_unit/1, type_text/1, spawn_input/4, going/0, let_go/0, show/3, bindings/1, slot/1,
         names/0,
         session_names/0, session_texts/0, source_root/0, segment/1, component/1, forget/2,
         browse/2, doc/2,
         documentation/1, fields/1, signature/1, declared_type/2, load/2, reload/1, version/0,
         write/1, node_screen/1, to_screen/1, flush_screen/0, leaves_it_unchanged/1,
         collect/1, collect/3, own/1, detach/0, input_site/2, is_expression/1, declared/2]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("checker/include/ern_types.hrl").
-include_lib("shared/include/ern_diagnostic.hrl").
-include_lib("cli/include/ern_build.hrl").
-include_lib("nodes/include/ern_node.hrl").
-include_lib("runtime/include/ern_rt.hrl").
-include_lib("kernel/include/file.hrl").

%% Report §8.6: each receive that can wait, by its kind (docs/code_style.md): the
%% wait for the table's holder, a process of the toolchain's own the look
%% does not read, and the holder's own.
-receives({ernest_wait, [bound_lives/1]}).
-receives({foreign_wait, [made_table/0]}).
-receives({own_process, [flush_screen/0, hold_table/1]}).

-define(UNIT, {tcon, ['Unit'], []}).

%% The function an expression input is wrapped in. No Ernest identifier is
%% spelled so, so the wrapper never shadows a name the session declares,
%% `main` among them (report §11.2's scope), and the emitter knows a site
%% inside it for the input's own.
-define(ENTRY, '$input').

%% The parameter the entry point of a `let` with `<-` takes, the block's
%% rest the session stands for (report §11.2, §5.5), spelled as no Ernest
%% identifier is.
-define(REST, '$rest').

%% How long a session waits for its local half to answer for a file of the
%% source root, as long as the shell waits for its file system (shell.ern's
%% `fileMs`).
-define(FILE_MS, 5000).

%% The session so far: its number on the node, the load path, the source
%% root, the interfaces of the modules behind the session, and the scope
%% those modules make (report §11.2), which the checker takes as its fourth
%% argument.
-record(session, {number = 1, namespace = ['$Session1'], load_path = [], source_root = ".",
                  last_input = 0, moved = [],
                  last_holder = 0, free = [], interfaces = [],
                  scope = #{}, beams = #{}, source_hashes = #{}, source_expected = #{},
                  units = #{}, versions = #{}, previous = [],
                  local, working_directory = ".", attached = false, synced = none,
                  env = none, input_names = #{}}).
%% number: the session's number on its node, given once in the node's life,
%% which its namespace and every host name its inputs make carry (report
%% §11.2, Appendix H); namespace: the session's namespace in the forms,
%% which carries the node's key where the program is a node
%% (session_namespace/1); moved: the lines that name the session's bindings
%% another session's reload moved to a previous version, said with that
%% reload's line (reloaded_by/3)
%% local: the address of the shell's local half, which holds the terminal
%% and the operator's files (report §11.2); working_directory: the local
%% half's, which a file of the source root is named from (§11.5); attached:
%% whether the session is attached to its node from another, which takes a
%% compiled form from the node's load path alone
%%
%% scope: what an input may name, `values`, `types` and `constructors`, each
%% name to its qualified name
%% last_input: the highest input number given, and last_holder the highest
%% `$Bindings` number; free: the namespaces of the inputs and the holders
%% whose units the session let go, given again first (given/3), each taken
%% out as it is given, in the session the check or the collection answers,
%% so that a check the session does not keep gives none (report §2.3)
%%
%% source_hashes: the namespace of a module the session has loaded, to the hash
%% of the source it was compiled from, which `:reload` compares (§11.2);
%% source_expected: the namespace of each whose source the session looks
%% for under the source root, to true: one it compiled from its source,
%% and one of the program the runner loaded for the file the shell was
%% started with; never a library's, whose source is elsewhere
%% beams: the namespace of an input that declared, and of a module `:load`
%% or `:reload` compiled, to its compiled module, its latest version's,
%% which `:doc` reads the documentation of (report §11.2, §11.4) and a
%% reload what its forms reference (recorded/2)
%%
%% units: the unit each namespace runs as where it is not the module's
%% Erlang name: a version a reload brought, `ern@counter$2`, of a module or
%% of a declaring input, and a previous version's namespace, its unit
%% (§8.7, §11.2); versions: each reloaded module's version, and each
%% declaring input's a reload compiled again, counted from 1, its first
%% load or its input; previous: the interfaces of previous versions,
%% `Counter$1`, of the types a reload changed, which what the session held
%% before it names, and which the checker is given beside the loaded
%% modules' (§11.2)
%%
%% synced: the version of the node's modules the session last took, which
%% a load or a reload by any session moves (synced/1); env: the checker's
%% environment over the interfaces, kept between inputs and made again
%% where they change, with the interfaces and the previous versions' it was
%% made over, `{Interfaces, Previous, Env}`, or none, the session's row
%% holding none (session_env/1, keep_session/1); input_names: the name each
%% declaring input prints with, by its namespace (input_names/1)
%%
%% Report §11.2: the node's modules, which every session has in scope beside
%% its own and which a load or a reload by any session changes: of the
%% session's fields of these names, the parts of the modules the node holds,
%% none of an input's or a holder's (synced/1, published/1).
-record(modules, {interfaces = [], beams = #{}, source_hashes = #{}, source_expected = #{},
                  units = #{}, versions = #{}}).
%%
%% A checked input: the namespace of the module it became, its typed tree,
%% the declarations it was checked as, the module's interface, the
%% checker's environment, its type, what it binds, and its site, the name
%% and the line offset its spawn sites are written with (site/1); and its
%% text and where it came from, which a reload compiles a declaring input
%% again from (input_text/2).
-record(checked, {namespace, typed, declarations, interface, env, type, binds, site,
                  printed_name, text, origin}).
%% A declaring input as a reload compiles it again (report §11.2): its
%% text, where it came from, the session's names as they stood at it,
%% those of them its text names, and the name it prints with.
-record(input_text, {text, origin, scope, printed_name}).
%% binds: `{name, Name}` for the name a `let` binds, `{lambda, Name,
%% Scheme}` for a `let` of a lambda, generalized, `{names, Names}` for the
%% names a `let` with a pattern binds, `{arrow, Names, Type, Constructor}`
%% for those a `let` with `<-` binds, of the type Type together, under its
%% sum type's Constructor, `'Right'` or `'Some'`, `it` for an expression,
%% or `declarations`; a name is tagged, so that no name stands for a tag.
%% type: the value's, which is the value of `e` for a `let p <- e`, shown
%% where it binds nothing.
%% printed_name: the name the input's module prints with (input_names/0).
%%
%% A module a load or a reload brings: its namespace, the unit it is, its
%% compiled form, the hash of the source it was compiled from (§11.2),
%% whether its source is the session's, the session compiling it or taking
%% its current compiled form, or it is a library's, whose form alone the
%% session has; how its unit comes as it is installed, `file`, its
%% compiled form loaded as it is, `forms`, made from that form's forms, or
%% `held`, a unit the node holds already (ern_code:placement/4); and the
%% file of the current compiled form `:load` took in place of compiling
%% its source, or none.
-record(compiled, {namespace, unit, beam, source_hash, from_source = false, made = file,
                   erc = none}).
%% A load's modules as it places them, each after the modules it uses
%% (report §8.7, §11.2): the interfaces a module is compiled against, the
%% session's and those of the modules the load placed before it; the unit
%% each runs as where it is not its Erlang name, which a module is compiled
%% to call; the modules of its source set not placed yet, by namespace;
%% what came of each it placed of them, compiled or why not, the last
%% first; the modules that did not compile; the unit of each module the
%% load has placed, by namespace; the modules it takes from their
%% compiled forms on the load path, in the order placed; and the modules
%% whose placing waits on what they use, the latest first, each using the
%% one before it, so that a module that uses one of them in turn is a
%% cycle (report §11.1).
-record(placing, {interfaces, units, sources = #{}, compiled = [], failed = [], placed = #{},
                  needed = [], waiting = []}).
%% A value with the descriptor of its type, so it prints as E.1 prints it.
-record(value, {term, descriptor}).
%% Report §11.2: what an input bound, which its outcome carries beside its
%% value, and which the session binds by in its own process once the input
%% has answered (collect/3): its binding, made in the session's process
%% before the spawn (binding/6), and the input's process where it is the
%% binder of the holder the session makes of what it bound, or none. The
%% input's process writes nothing of the session's, so that one an
%% interrupt kills leaves nothing half made.
-record(bound, {binding = none, binder = none}).
%% What the session's scope takes of what an input bound, which the session
%% joins (joined_bound/2): the interface of what it declared, of the names
%% its holder holds, or of the value its own unit holds, `it`, or none
%% where it bound nothing; and for
%% an input that declared, its namespace, its compiled module, which `:doc`
%% reads, and the name it prints with.
-record(scoped, {interface = none, declared = none}).
%% Report §11.2: a unit of the session's, a row by its Erlang name (unit/1):
%% its namespace; the session's units it needs, those its code calls and
%% whose definitions its forms name where the session keeps it, whose types
%% its interface names and whose functions its values hold; the keys its
%% values are kept under, and the qualified names in scope that reach
%% them; whether the session keeps its code while it runs, an input's that
%% declares or builds a function value; and whether the node keeps it for
%% its life once the session has detached, an input's that declares a
%% function or builds a function value (lasting/3).
-record(session_unit, {namespace, needs = [], keys = [], names = [], kept = false,
                       lasting = false}).
%% Where an input from a startup file came from: the file, the line it
%% stands on, and the column it begins in (report §11.2); a typed input's
%% origin is `{typed, Name}`.
-record(startup_input, {file, line, column}).

%% Report §11.2: what the runner loaded before a plain shell started, which
%% the node's modules begin from, a persistent term, since it is set once
%% and a read does not copy it. A plain shell's launch is its node's life:
%% the front end's table is emptied, and its session is the node's first.
%%
%% A binding's value is §8.5's store, a persistent term, as a module's is,
%% so that a later input reads it as it reads another module's value; its
%% release when it is replaced, `it` at almost every input, scans every
%% process, a cost that grows with the processes the session has (the
%% log's *The Hardening Built*).
-spec loaded(#loaded{}) -> ok.
loaded(Loaded) ->
    persistent_term:put({?MODULE, loaded}, Loaded),
    table(),
    true = ets:delete_all_objects(?MODULE),
    ok.

%% Report §11.2: the prelude's environment, the standard library's
%% interfaces among it, which every input is checked against and
%% completion, `:browse` and `:doc` read: built at the host's first
%% session and held for the host's life, a persistent term set once, since
%% the toolchain's tree does not change under a running host. No session
%% carries it: a read, a spawn and a message do not copy a persistent term,
%% and a row of the table, which would copy it at each input, holds the
%% session alone (the log's *A Line-Mode Input's Cost*).
prelude() ->
    case persistent_term:get({?MODULE, prelude}, none) of
        none ->
            Prelude = ern_typecheck:prelude_env(),
            %% two sessions that start at once build one environment, and
            %% the second put of an equal term changes nothing
            persistent_term:put({?MODULE, prelude}, Prelude),
            Prelude;
        Prelude ->
            Prelude
    end.

%% Report §11.2: the front end's table, of the node's sessions, a row of it
%% where what it holds changes as inputs run, since the host scans every
%% process when a persistent term is replaced. Each session's rows stand
%% under the root of its processes (kept/2), and the session's own process
%% alone writes them, but the root's at a session's end that was no leave
%% (detach/0).
%%
%% A session's rows: the session as it stands (keep_session/1), each of its
%% units with what it needs (unit/1), those a collection may let go and those of
%% them a kept unit needs (held_units/0), each declaring input's text,
%% which a reload compiles it again from (input_text/2), each input's
%% printed name, the modules whose `:load` was refused (refusal_kept/2),
%% the processes of the inputs that bound what the scope still names
%% (binders/0), and the session's own processes and the input that runs
%% (own/1). The node's rows
%% are the number the next session is given, the node's modules
%% (node_modules/0), each session's address by its root, which another's
%% reload is said at (reload_said/2), each input unit's name, which its spawn
%% sites read for as long as the unit lives, a session's end among it
%% (input_site/2), and what detached sessions left (collect_detached/0).
%%
%% The table is made at its first need by a process of its own that holds
%% it for the host's life, since sessions come and go on a node.
table() ->
    case ets:whereis(?MODULE) of
        undefined -> made_table();
        _ -> ok
    end.

made_table() ->
    Caller = erlang:self(),
    {Holder, MonitorRef} = erlang:spawn_monitor(fun() -> hold_table(Caller) end),
    %% report §8.6: the holder is no process the look reads, so the wait
    %% is inside foreign code for it
    ern_rt:entered_foreign(),
    try
        receive
            {Holder, made} -> erlang:demonitor(MonitorRef, [flush]), ok;
            %% another session made it first
            {'DOWN', MonitorRef, process, Holder, _} -> ok
        end
    after
        ern_rt:left_foreign()
    end.

%% The holder waits for nothing: the table is its owner's, and lives as
%% long as it does, which is the host's life.
hold_table(Caller) ->
    try ets:new(?MODULE, [named_table, public]) of
        ?MODULE ->
            Caller ! {erlang:self(), made},
            receive after infinity -> ok end
    catch
        error:badarg -> ok
    end.

%% A row of the session the calling process acts in, by the root of its
%% processes (ern_rt:root_of/1), and Default where there is none.
kept(Key, Default) ->
    node_kept({session_root(), Key}, Default).

keep(Key, Value) ->
    node_keep({session_root(), Key}, Value).

%% A row of the node's, and Default where there is none, or no table,
%% nothing having been loaded.
node_kept(Key, Default) ->
    try ets:lookup(?MODULE, Key) of
        [{_, Value}] -> Value;
        [] -> Default
    catch
        error:badarg -> Default
    end.

node_keep(Key, Value) ->
    table(),
    ets:insert(?MODULE, {Key, Value}),
    Value.

forgotten(Key) ->
    ets:delete(?MODULE, {session_root(), Key}).

%% Report §11.2: the root of the calling process's spawn chain, which is
%% the session's root for the session, its reader, its screen and each
%% input, chained to it: a plain shell's session, the entry process, is its
%% own, and an attached session's is the process its shell's spawn started
%% on the node, which starts it.
session_root() ->
    ern_rt:root_of(erlang:self()).

%% Report §11.2, Appendix H: the session's namespace on its node, under
%% which a form and a unit's '$code'/0 name what the session declares, a
%% type, a function, a foreign declaration or what a `let` at the prompt
%% binds, whatever input or holder declares it, so that one declaration is
%% one definition at every input of the session, `$Session3`. It is the
%% forms' and the code table's alone: the checker, the unit and what prints
%% name a declaration under its input's namespace, and a binding's value is
%% kept under its holder's. No `.erc` holds a session type, which only an
%% input's unit, compiled in memory, declares.
session_namespace(#session{namespace = Namespace}) ->
    Namespace.

%% Report Appendix H: the session's namespace as its form holds it, made as
%% the session starts: where the program is a node (§8.2), its atom
%% carries the node's public key after the number, `$Session3@` and the
%% base64 of the key's PEM, as `ern config` prints it (§12.5), so that two
%% nodes' sessions of one number declare two names; a printed name leaves
%% the key out (ern_namespace:segment_text/1).
form_namespace(Number) ->
    Name = "$Session" ++ integer_to_list(Number),
    case ern_carrier:is_node() of
        true ->
            #configuration{public_key = PublicKey} = ern_carrier:configuration(),
            [list_to_atom(Name ++ "@" ++ base64:encode_to_string(ern_node:public_pem(PublicKey)))];
        false ->
            [list_to_atom(Name)]
    end.

%% Report §11.2 *Faults*: the session's namespace as a name prints it, which
%% its spawn sites carry, `$Session3`, the node's key left out.
printed_namespace(#session{number = Number}) ->
    [list_to_atom("$Session" ++ integer_to_list(Number))].

%% Report §11.2: a session of its node, given the node's next number: its
%% local half's address, which holds the terminal and the operator's files;
%% its screen's process, which what its processes write to standard output
%% and standard error goes to (§12.1); the operator's source root and
%% working directory; whether it is attached to the node from another; and
%% its own address, which another session's reload is said at (reload_said/2).
%% Its screen's row is written for the root of its processes, so that a
%% process it starts, directly or through one it started, writes there, and
%% its load path and modules are the node's.
-spec start(term(), pid(), binary(), binary(), boolean(), ern_rt:address()) -> #session{}.
start(Local, Screen, SourceRoot, WorkingDirectory, Attached, Shell) ->
    table(),
    collect_detached(),
    Number = ets:update_counter(?MODULE, next_session, 1, {next_session, 0}),
    'Unit' = ern_rt:screen(session_root(), sink(Screen)),
    keep(screen, Screen),
    Root = session_root(),
    node_locked(fun() -> node_keep(sessions, (node_kept(sessions, #{}))#{Root => Shell}) end),
    LoadPath = case persistent_term:get({?MODULE, loaded}, none) of
                   #loaded{load_path = Given} -> Given;
                   none -> ern_cli:load_path()
               end,
    %% built as the host's first session starts, so that its first input
    %% does not wait for it
    prelude(),
    keep_session(synced(#session{number = Number, namespace = form_namespace(Number),
                                 load_path = LoadPath,
                                 source_root = unicode:characters_to_list(SourceRoot),
                                 local = Local, working_directory =
                                     unicode:characters_to_list(WorkingDirectory),
                                 attached = Attached})).

%% Report §11.2 *Startup and history*: the number the session's on its
%% node, which the shell's greeting says.
-spec number(#session{}) -> pos_integer().
number(#session{number = Number}) ->
    Number.

%% Report §11.2 *The attached shell*: what the session says of a reload by
%% the session numbered By, which compiled Modules again: a line for each,
%% `Counter compiled again by session 3`, and each of the session's
%% bindings whose type the reload moved to a previous version named as the
%% session's own reload names it, once the session has taken the node's
%% modules as they stand, the moves of an input checked meanwhile among
%% what it names (synced/1).
-spec reloaded_by(#session{}, pos_integer(), [binary()]) -> {#session{}, [binary()]}.
reloaded_by(Session, By, Modules) ->
    #session{moved = Moved} = Synced = synced(Session),
    Lines = [<<Module/binary, " compiled again by session ", (integer_to_binary(By))/binary>>
             || Module <- Modules] ++ Moved,
    {keep_session(Synced#session{moved = []}), Lines}.

%% Report §12.1, §11.2: what the session's processes write to standard
%% output and standard error, sent to its screen as it comes, the bytes as
%% they are: the screen keeps a character cut across two writes until its
%% end comes (`String.fromUtf8Piece`).
%%
%% Report §4.7, §8.4: the bytes go to the screen's process by its host
%% identity, `Wrote(bytes)`, as the drains' `Flush` goes, and not to an
%% address of it, which the check's process in front of it would stand
%% between: so a write's bytes are in the screen's mailbox once the stream
%% has taken them, before any drain that follows the write, the end's
%% among them (flush_screen/0).
sink(Screen) ->
    fun(Bytes) -> send_wrote(Screen, Bytes) end.

send_wrote(Screen, Bytes) ->
    Screen ! {'Wrote', Bytes},
    ok.

%% Report §11.2: the node's modules, which every session has in scope: at a
%% node's first session, those the runner loaded for a plain shell, or the
%% modules of the node's load path, which a node reads whole at its start
%% (§8.7); from then on, as the sessions' loads and reloads left them.
node_modules() ->
    case node_kept(modules, none) of
        none -> node_keep(modules, first_modules());
        Modules -> Modules
    end.

first_modules() ->
    Interfaces = case persistent_term:get({?MODULE, loaded}, none) of
                     #loaded{interfaces = Loaded} -> Loaded;
                     none -> load_path_interfaces(ern_cli:load_path())
                 end,
    Program = case persistent_term:get({?MODULE, loaded}, none) of
                  #loaded{program = Given} -> Given;
                  none -> []
              end,
    #modules{interfaces = [Interface || {Interface, _} <- Interfaces],
             source_hashes = #{Interface#interface.namespace => Hash
                               || {Interface, Hash} <- Interfaces},
             source_expected = #{Namespace => true || Namespace <- Program}}.

%% Report §8.7, §11.2: the interface of each module of a node's load path,
%% with the hash of the source it was compiled from, as the `.erc` the node
%% read at its start recorded them and its runner loaded them, and not as
%% the files hold them now, which a build may have written again since: an
%% input is checked against the code the node runs. The standard library's
%% units, which the prelude's environment holds, are not among them.
load_path_interfaces(LoadPath) ->
    Roots = [filename:join(ern_build:absolute(Root), "") ++ "/" || Root <- LoadPath],
    lists:sort([{Interface, Hash}
                || {Unit, #{interface := Interface, source_hash := Hash}} <- ern_code:chunks(),
                   File <- [code:which(Unit)], is_list(File),
                   lists:any(fun(Root) -> lists:prefix(Root, ern_build:absolute(File)) end,
                             Roots)]).

%% Report §11.2: the session with the node's modules as they stand, which
%% another session's load or reload may have changed since the session's
%% last look: their interfaces, forms, hashes, units and versions in place
%% of the session's own view of them, its inputs' and holders' kept; and
%% each type of a module another session reloaded that the session's own
%% inputs name made the previous version's, as the session's own reload
%% makes it (versioned/3). The node's row is read only where its version
%% has moved since the session's last look, so that an input reads one
%% number of the node's and not every module it holds.
synced(#session{synced = Synced} = Session) ->
    case node_kept(modules_version, 0) of
        Synced -> Session;
        Version -> (synced_with(Session, node_modules()))#session{synced = Version}
    end.

synced_with(#session{versions = Versions} = Session,
            #modules{interfaces = Interfaces, beams = Beams, source_hashes = SourceHashes,
                     source_expected = Expected, units = Units, versions = NodeVersions}) ->
    Own = fun(Namespace, _) -> is_session_namespace(Namespace) end,
    Viewed = Session#session{
               interfaces = Interfaces
                   ++ [Interface || #interface{namespace = Namespace} = Interface
                                        <- Session#session.interfaces,
                                    is_session_namespace(Namespace)],
               beams = maps:merge(maps:filter(Own, Session#session.beams), Beams),
               source_hashes = SourceHashes, source_expected = Expected,
               units = maps:merge(maps:filter(Own, Session#session.units), Units),
               versions = maps:merge(maps:filter(Own, Versions), NodeVersions)},
    Reloaded = [Namespace || Namespace := Version <- NodeVersions,
                             not is_session_namespace(Namespace),
                             maps:get(Namespace, Versions, 1) =/= Version,
                             lists:keymember(Namespace, #interface.namespace,
                                             Session#session.interfaces)],
    case Reloaded of
        [] ->
            Viewed;
        _ ->
            %% the versions as the session saw them, which the moves count
            %% from, and then the node's; the bindings moved are named once
            %% the reload is said (reloaded_by/3)
            {Moved, Previous} = versioned(Session, Viewed#session{versions = Versions}, Reloaded),
            Moved#session{versions = Viewed#session.versions,
                          moved = Session#session.moved ++ previous_lines(Moved, Previous)}
    end.

%% Report §11.2: the node's modules as the session's load or reload left
%% them, which every session's next input is checked against, and their
%% version moved, which tells each session to read them (synced/1).
published(#session{interfaces = Interfaces, beams = Beams, source_hashes = SourceHashes,
                   source_expected = Expected, units = Units, versions = Versions} = Session) ->
    Node = fun(Namespace, _) -> not is_session_namespace(Namespace) end,
    node_keep(modules,
              #modules{interfaces = [Interface
                                     || #interface{namespace = Namespace} = Interface
                                            <- Interfaces,
                                        not is_session_namespace(Namespace)],
                       beams = maps:filter(Node, Beams), source_hashes = SourceHashes,
                       source_expected = Expected, units = maps:filter(Node, Units),
                       versions = maps:filter(Node, Versions)}),
    _ = ets:update_counter(?MODULE, modules_version, 1, {modules_version, 0}),
    Session.

%% Report §11.2: a load or a reload of the node's, one at a time on the
%% node, so that two sessions' loads do not each publish what the other
%% did not see (node_locked/1).
node_load(Session, Load) ->
    node_locked(fun() -> Load(synced(Session)) end).

%% Report §11.2: what is done to the node's rows that every session writes,
%% one at a time on the node: the host's lock on the node, each process its
%% own requester.
node_locked(Work) ->
    global:trans({?MODULE, erlang:self()}, Work, [node()]).

%% Report §11.2: the session as it stands, which completion reads. The
%% reader asks for the names while an input runs, when the session is busy
%% answering nothing, so it cannot be a message to the session; the front
%% end keeps the latest, as it keeps what the runner loaded. An input's
%% declarations join the session when it has run, not when it is checked,
%% so this is set as it has run, once an input. The row holds no checker's
%% environment, which a row would copy at each write and read (session_env/1).
keep_session(Session) ->
    keep(session, Session#session{env = none}),
    Session.

kept_session() ->
    kept(session, #session{}).

%% Report §11.2: the session as the reader checks a line against it, for
%% completion after a `.` and for `Shift-Tab`'s signature: the front end's
%% copy with the checker's environment over its interfaces, made where they
%% changed since the reader's last question and taken as it is where they
%% did not (session_env/1). The environment is kept in the reader's own
%% process, where it reads it, for its life, and is replaced when the
%% interfaces change, so that a question adds no interface again; a
%% session's row holds none (keep_session/1).
reader_session() ->
    Kept = case erlang:get({?MODULE, env}) of
               undefined -> kept_session();
               Env -> (kept_session())#session{env = Env}
           end,
    {Session, _} = session_env(Kept),
    _ = erlang:put({?MODULE, env}, Session#session.env),
    Session.

%% Report §11.2, §8.1: the file's entry point, spawned beside the prompt and
%% not entered, and nothing where the shell was started with no file. A
%% fault in it reaches the session through Process.faults, to which the
%% session subscribed before (E.21).
-spec spawn_program() -> 'Unit'.
spawn_program() ->
    case persistent_term:get({?MODULE, loaded}, #loaded{}) of
        #loaded{entry = #entry_point{erlang_module = ErlangModule, function = Function,
                                     site = Site}} ->
            _ = ern_rt:spawn_root(fun() -> ErlangModule:Function() end, Site),
            'Unit';
        _ ->
            'Unit'
    end.

%% Report §11.2: the startup file of the configuration directory
%% `--config-dir` names, named from the working directory as §11.5 names a
%% file, or none. The person's the shell finds itself, in Ernest, from the
%% environment, and it reads both, whether they are there and whose they
%% are among it.
-spec config_startup() -> {'Some', binary()} | 'None'.
config_startup() ->
    case persistent_term:get({?MODULE, loaded}, #loaded{}) of
        #loaded{config_startup = none} -> 'None';
        #loaded{config_startup = File} ->
            {'Some', unicode:characters_to_binary(ern_build:shown(File))}
    end.

%% Report §11.2: the source root the runner gave the shell, `--source-root`
%% or the working directory, absolute, which the local half gives its
%% session.
-spec given_source_root() -> binary().
given_source_root() ->
    #loaded{source_root = SourceRoot} = persistent_term:get({?MODULE, loaded}, #loaded{}),
    unicode:characters_to_binary(ern_build:absolute(SourceRoot)).

%% Report §11.2: the listed peer `--attach` names, which the local half
%% attaches its shell to, or none for a plain shell.
-spec attach_to() -> {'Some', binary()} | 'None'.
attach_to() ->
    case persistent_term:get({?MODULE, loaded}, #loaded{}) of
        #loaded{attach = none} -> 'None';
        #loaded{attach = Name} -> {'Some', unicode:characters_to_binary(Name)}
    end.

%% Report §11.2, §11.8: the line an attached shell's end says, on the job's
%% own standard error, where the job's lines go (ern_cli:error_line/1),
%% before its local half ends the shell by Os.exit with its status.
-spec say_end(binary()) -> 'Unit'.
say_end(Line) ->
    ern_cli:error_line(<<Line/binary, "\n">>),
    'Unit'.

%% Report §11.2: whether two paths name one file, both there, on one device,
%% with one node, which a file's entry in Ernest does not hold.
-spec is_same_file(binary(), binary()) -> boolean().
is_same_file(First, Second) ->
    case {file:read_file_info(First), file:read_file_info(Second)} of
        {{ok, #file_info{major_device = Device, inode = Inode}},
         {ok, #file_info{major_device = Device, inode = Inode}}} -> true;
        _ -> false
    end.

%% Report §11.2: at a terminal the shell takes another line where the
%% parser cannot finish the input. Every reading is tried, the expression,
%% the declarations and a `let` with a pattern, as `input/1` tries them: an
%% input that could still become any of them is unfinished.
-spec needs_more(binary()) -> boolean().
needs_more(Text) ->
    unfinished(ern_parser:parse_expr(Text)) orelse unfinished(ern_parser:parse_string(Text))
        orelse unfinished(ern_parser:parse_statement(Text)).

unfinished({error, #diagnostic{incomplete = Incomplete}}) -> Incomplete;
unfinished(_) -> false.

%% Report §11.2: where the bracket that ends the text, a `)`, `]` or `}`
%% just typed, was opened, as the compiler's lexer reads the text: the
%% index of its `(`, `[` or `{` in graphemes, as the editor counts, the `(`
%% of a `#(` among them. From the closing bracket back, the brackets
%% between the two are passed over in pairs. None where the text's last
%% token is no closing bracket, a comment or a string holding it; where a
%% bracket of another kind stands in the way, or none opens it; and where
%% the lexer cannot read the text, a string or a comment left open.
-spec opening(binary()) -> {'Some', non_neg_integer()} | 'None'.
opening(Before) ->
    case ern_lexer:tokenize(Before, [comments, no_new_names]) of
        {ok, Tokens} ->
            case lists:reverse(Tokens) of
                [{eof, _}, {Symbol, _} | Earlier] -> closed(bracket(Symbol), Earlier, Before);
                _ -> 'None'
            end;
        {error, _} ->
            'None'
    end.

closed({close, Kind}, Earlier, Before) -> opened(Earlier, [Kind], Before);
closed(_, _, _) -> 'None'.

%% Each closing bracket met waits for one of its kind; an opening one
%% answers the latest that waits, and where that is the first, it is the
%% one sought.
opened([], _, _) ->
    'None';
opened([{Symbol, Position} | Earlier], [Kind | Waiting] = Stack, Before) ->
    case bracket(Symbol) of
        {close, Closing} -> opened(Earlier, [Closing | Stack], Before);
        {open, Kind} when Waiting =:= [] -> {'Some', grapheme_index(Position, Symbol, Before)};
        {open, Kind} -> opened(Earlier, Waiting, Before);
        {open, _} -> 'None';
        none -> opened(Earlier, Stack, Before)
    end;
opened([_ | Earlier], Stack, Before) ->
    opened(Earlier, Stack, Before).

bracket('(') -> {open, round};
bracket('#(') -> {open, round};
bracket('[') -> {open, square};
bracket('{') -> {open, curly};
bracket(')') -> {close, round};
bracket(']') -> {close, square};
bracket('}') -> {close, curly};
bracket(_) -> none.

%% The lexer's line and column, in code points after a byte order mark it
%% passes over, as the graphemes before them in the text; the `(` of a
%% `#(` is a code point past where the token begins.
grapheme_index({Line, Column, _, _}, Symbol, Before) ->
    Chars = unicode:characters_to_list(Before),
    Mark = case Chars of
               [16#FEFF | _] -> 1;
               _ -> 0
           end,
    Hash = case Symbol of
               '#(' -> 1;
               _ -> 0
           end,
    Offset = Mark + code_points_before(lists:nthtail(Mark, Chars), Line, Column) + Hash,
    string:length(lists:sublist(Chars, Offset)).

code_points_before(_, 1, Column) -> Column - 1;
code_points_before([$\n | Rest], Line, Column) -> 1 + code_points_before(Rest, Line - 1, Column);
code_points_before([_ | Rest], Line, Column) -> 1 + code_points_before(Rest, Line, Column).

%% Report §11.2: an input is checked before it is run; a failure is §11.5's
%% text, as `ern build` shows it, under the name of where the input came from:
%% `input 3` for the third thing entered at the prompt, the file's path for
%% an input from a startup file. The shell's `Origin` says which:
%% `Prompt(n)`, or `Startup(file, line, column)`, its fields in declared
%% order, the column where the input begins on the line.
-spec check(#session{}, {'Prompt', pos_integer()}
                        | {'Startup', binary(), pos_integer(), pos_integer()}, binary()) ->
          {'Left', binary()} | {'Right', {#session{}, #checked{}}}.
check(Session, Origin, Input) ->
    %% report §11.2: every input is checked against the node's modules as
    %% they stand, a reload by any session among what made them so; an
    %% input takes the number of one whose module was unloaded, whose name
    %% is an atom already, before a new one (report §2.3)
    {Namespace, Numbered} = given_input(synced(Session)),
    without_line_feed(checked(checked_as(Numbered, Namespace, Origin, Input),
                              printed_name(Origin))).

%% Report §11.2: `:type`'s expression, checked as an input is and not run,
%% in a namespace of its own that no input is given, `$Type`, as the
%% reader's lines are in `$Fields` (fields/1): it takes no input's number,
%% so that no `:type` makes a name of the host's, and the session it
%% answers keeps only the checker's environment it was checked in.
-spec check_type(#session{}, {'Prompt', pos_integer()}
                             | {'Startup', binary(), pos_integer(), pos_integer()}, binary()) ->
          {'Left', binary()} | {'Right', {#session{}, #checked{}}}.
check_type(Session, Origin, Input) ->
    without_line_feed(checked_as(synced(Session), ['$Type'], Origin, Input)).

checked_as(Session, Namespace, Origin, Input) ->
    InputOrigin = case Origin of
                 {'Prompt', Number} -> {typed, <<"input ", (integer_to_binary(Number))/binary>>};
                 {'Startup', File, Line, Column} ->
                     #startup_input{file = File, line = Line, column = Column}
             end,
    case input(Input) of
        {ok, Binds, Expr} ->
            check_module(Session, Namespace, InputOrigin, Input, input_entry(Binds, Expr),
                         Binds);
        {declarations, Declarations} ->
            check_module(Session, Namespace, InputOrigin, Input, Declarations, declarations);
        {error, Diagnostic} ->
            {'Left', diagnostic(Session, InputOrigin, Input, [Diagnostic])}
    end.

%% Report §11.2: the name a session type a later input shadows prints
%% under, the input that declared it: `$Input4` for the fourth input typed,
%% as its diagnostics count it, and `$Startup2` for the second input
%% checked from the startup files, which the session does not count. The
%% module's own name is another, a slot a later input reuses (§2.3).
printed_name({'Prompt', Number}) ->
    "$Input" ++ integer_to_list(Number);
printed_name({'Startup', _, _, _}) ->
    "$Startup" ++ integer_to_list(keep(startup_inputs, kept(startup_inputs, 0) + 1)).

%% The name each declaring input of the session prints with, a type it
%% declares that a later input shadows printing under it, and each previous
%% version of a declaring input's types, as the input prints with the
%% version's number (named_versions/2).
input_names(#session{input_names = InputNames}) ->
    maps:merge(InputNames, kept(version_names, #{})).

%% Report §2.3: the modules the session makes are named as no Ernest name
%% is spelled, since an identifier holds no `$`: the module an input
%% becomes, `$Input<s>_<n>`, and the one that holds what a `let` at the
%% prompt binds, `$Bindings<s>_<n>`, each with the session's number on its
%% node, `s`, and its own, `n` (report §11.2); and the ones the reader checks
%% a line in for completion and `Shift-Tab`, `$Fields` and `$Signature`,
%% which load no module and so make no host name. No input reaches them by
%% name, and a module spelled as one would be otherwise, `Input1`, is a
%% module like any other.
input_namespace(#session{number = Session}, Number) ->
    session_module("$Input", Session, Number).

holder_namespace(Session, Number) ->
    session_module("$Bindings", Session, Number).

session_module(Kind, Session, Number) ->
    [list_to_atom(Kind ++ integer_to_list(Session) ++ "_" ++ integer_to_list(Number))].

checked({'Right', {Session, Checked}}, PrintedName) ->
    {'Right', {Session, Checked#checked{printed_name = PrintedName}}};
checked(Other, _PrintedName) ->
    Other.

%% Report §2.3, §11.2: the namespace of the session's next input, one the
%% session let go given again first, and the session with it taken, or
%% with its highest number moved; and the same for its next holder.
given_input(#session{last_input = LastInput} = Session) ->
    given(input, Session, fun() ->
                              {input_namespace(Session, LastInput + 1),
                               Session#session{last_input = LastInput + 1}}
                          end).

given_holder(#session{number = Number, last_holder = LastHolder} = Session) ->
    given(holder, Session, fun() ->
                               {holder_namespace(Number, LastHolder + 1),
                                Session#session{last_holder = LastHolder + 1}}
                           end).

given(Kind, #session{free = Free} = Session, Fresh) ->
    case lists:splitwith(fun(Namespace) -> kind_of_namespace(Namespace) =/= Kind end, Free) of
        {Before, [Namespace | After]} -> {Namespace, Session#session{free = Before ++ After}};
        {_, []} -> Fresh()
    end.

%% Report §11.2: an input is an expression, whose value is `it`; a `let`,
%% whose value is the name it binds; or declarations. A `let` at the prompt
%% is a block `let` (§4.6 is for a module's), so it is the entry point's
%% body and the name is bound to what the input answers.
input(Text) ->
    input(Text, []).

%% The same, read under the lexer's options: text that is read and not
%% run, a line being typed, is read with `no_new_names`.
input(Text, Read) ->
    case ern_parser:parse_expr(Text, Read) of
        {ok, Expr} ->
            {ok, it, Expr};
        {error, Diagnostic} ->
            case ern_parser:parse_string(Text, Read) of
                {ok, [#let_declaration{name = Name, body = Body} = Declaration]} ->
                    {ok, let_binds(Name, Body), named_let(Declaration)};
                {ok, Declarations} -> declarations(Declarations);
                {error, DeclarationDiagnostic} ->
                    case pattern_let(Text, Read) of
                        none ->
                            {error, reported_diagnostic(Text, Read, Diagnostic,
                                                        DeclarationDiagnostic)};
                        Parsed -> Parsed
                    end
            end
    end.

%% Report §11.2: a `let` whose pattern is not a name binds each name the
%% pattern binds. It is the block `{ let p = e; #(names) }`, whose value
%% holds the names in the order the pattern has them; `let _ = e` binds
%% none. Report §5.5: a `let` with `<-` is the block `{ let p <- e;
%% rest(#(names)) }`, the session standing for the block's rest: the entry
%% point takes it as its parameter (input_entry/2), and the shell gives it
%% the sum type's own constructor at run (value/2), so the block answers
%% the names under `Right` or `Some`, or else the `Left` or the `None` that
%% binds nothing.
pattern_let(Text, Read) ->
    case ern_parser:parse_statement(Text, Read) of
        {ok, #binding{span = Span, pattern = Pattern, operator = Operator} = Binding} ->
            Names = [Name || {Name, _} <- ern_ast:pattern_bindings(Pattern)],
            Variables = [#e_var{span = Span, name = Name} || Name <- Names],
            Bound = case Variables of
                        [] -> #e_constructor{span = Span, name = 'Unit'};
                        [Variable] -> Variable;
                        _ -> #e_tuple{span = Span, elements = Variables}
                    end,
            case Operator of
                '=' ->
                    {ok, {names, Names}, #e_block{span = Span, statements = [Binding, Bound]}};
                '<-' ->
                    Rest = #e_call{span = Span, callee = #e_var{span = Span, name = ?REST},
                                   args = [Bound]},
                    {ok, {arrow, Names}, #e_block{span = Span, statements = [Binding, Rest]}}
            end;
        _ ->
            none
    end.

%% Report §11.5: an input that begins where only a declaration may begin is
%% a declaration a person got wrong, and the declaration parser's error is
%% the one that names what is wrong; anything else is an expression, whose
%% error names it. `fn` begins a lambda as well, and begins a declaration
%% only when a name follows it, a member's type name among them (§4.8).
reported_diagnostic(Text, Read, Diagnostic, DeclarationDiagnostic) ->
    case ern_lexer:tokenize(Text, Read) of
        {ok, Tokens} ->
            case declaration_start(Tokens) of
                true -> DeclarationDiagnostic;
                false -> Diagnostic
            end;
        _ ->
            Diagnostic
    end.

declaration_start([{'fn', _}, {ident, _, _} | _]) -> true;
declaration_start([{'fn', _}, {typename, _, _} | _]) -> true;
declaration_start([{Word, _} | _]) -> lists:member(Word, [type, abstract, foreign, export, 'let']);
declaration_start(_) -> false.

%% Report §11.2: what an input declares is the session's from then on, so
%% every declaration of an input is exported; a later input reaches it as it
%% reaches another module's declaration (§4.3). A declaring input holds no
%% `let`, which is refused here, so it has no top-level values to compute or
%% keep.
declarations(Declarations) ->
    case [Span || #let_declaration{span = Span} <- Declarations] of
        [] -> {declarations, [exported(Declaration) || Declaration <- Declarations]};
        [_, Second | _] -> {error, one_let(Second)};
        [Span] -> {error, one_let(Span)}
    end.

%% Report §11.2: a `let` at the prompt is a block `let`, and a block has one
%% of them per input; a `let` beside a declaration would be a top-level
%% `let`, which §4.6 generalizes where its initializer is a value.
one_let(Span) ->
    #diagnostic{span = ern_diagnostic:span(Span),
                message = "a `let` at the prompt is an input of its own",
                help = "run this `let` on an input of its own, or make it a `let`"
                       " inside a declaration's body"}.

exported(#type_declaration{} = Declaration) ->
    Declaration#type_declaration{export = true};
exported(#abstract_declaration{} = Declaration) ->
    Declaration#abstract_declaration{export = true};
exported(#foreign_type_declaration{} = Declaration) ->
    Declaration#foreign_type_declaration{export = true};
exported(#fn_declaration{} = Declaration) ->
    Declaration#fn_declaration{export = true};
exported(#foreign_fn_declaration{} = Declaration) ->
    Declaration#foreign_fn_declaration{export = true};
exported(Declaration) ->
    Declaration.

%% Report §4.6, §11.2: a `let` that binds a name to a lambda is generalized,
%% as in a block; its scheme is known once the input is checked.
let_binds(Name, #e_lambda{}) -> {lambda, Name};
let_binds(Name, _) -> {name, Name}.

%% Report §11.2: a `let` at the prompt binds as a block's `let` does, so
%% the input is `{ let x = e; x }`, or `{ let x : T = e; x }`, which the
%% checker holds to its annotation; report §5: and an initializer that
%% names x, where no earlier input bound it, depends on itself.
named_let(#let_declaration{span = Span, name = Name, annotation = Annotation, body = Body}) ->
    #e_block{span = Span,
             statements = [#binding{span = Span, pattern = #p_var{span = Span, name = Name},
                                    annotation = Annotation, operator = '=', expr = Body},
                           #e_var{span = Span, name = Name}]}.

%% `export fn '$input'() = <the input>`, the entry point of §8.1; for a
%% `let` with `<-`, `export fn '$input'('$rest') = <the input>`, the rest
%% the session stands for (pattern_let/2).
input_entry({arrow, _}, Expr) ->
    Span = {1, 1, {1, 1}},
    [#fn_declaration{span = Span, export = true, name = ?ENTRY,
                     params = [#param{span = Span, pattern = #p_var{span = Span, name = ?REST}}],
                     body = Expr}];
input_entry(_Binds, Expr) ->
    [#fn_declaration{span = {1, 1, {1, 1}}, export = true, name = ?ENTRY, params = [],
                     body = Expr}].

check_module(#session{scope = Scope} = Given, Namespace, InputOrigin, Input, Declarations,
             Binds) ->
    {Session, Seeded} = session_env(Given),
    case ern_typecheck:check(Namespace, Declarations, [],
                             Scope#{input_names => input_names(Session)}, Seeded) of
        {ok, Typed, Interface, Env} ->
            Type = settled_input_type(input_type(Typed, Binds), Binds, Env),
            Binds1 = generalized(Binds, Typed, Env),
            case undetermined(Type, Env, Binds1, Typed) of
                none ->
                    Checked = #checked{namespace = Namespace, typed = Typed,
                                       declarations = Declarations, interface = Interface,
                                       env = Env, type = Type, binds = Binds1,
                                       site = site(Session, InputOrigin), text = Input,
                                       origin = InputOrigin},
                    {'Right', {Session, Checked}};
                {refused, Diagnostic} ->
                    {'Left', diagnostic(Session, InputOrigin, Input, [Diagnostic])}
            end;
        {error, Diagnostics} ->
            {'Left', diagnostic(Session, InputOrigin, Input,
                                [previous_hinted(Session, load_hinted(Session, Diagnostic))
                                 || Diagnostic <- Diagnostics])}
    end.

%% Report §11.2: the interfaces the checker is given in the session: the
%% loaded modules', the inputs' and the holders', and the previous
%% versions' of the types a reload changed, which what the session held
%% before it names.
checked_interfaces(#session{interfaces = Interfaces, previous = Previous}) ->
    Interfaces ++ Previous.

%% Report §11.2: the session with the checker's environment over its
%% interfaces, and that environment, the prelude's with each interface
%% added (ern_typecheck:seeded/2), which an input is checked in. The
%% session keeps it between inputs, so that an input's check adds no
%% interface again: where the interfaces are those it was made over it is
%% taken as it is; where the session's own inputs and holders alone came
%% or went, whose names no other interface holds, those gone are taken out
%% and those come added; and where any other interface changed, a load's,
%% a reload's or another session's, it is made again. It holds what those
%% interfaces fix, and goes with them, or with the session; the session's
%% row holds none (keep_session/1). The reader's sessions are its row's,
%% and make one for each check.
session_env(#session{interfaces = Interfaces, previous = Previous, env = Kept} = Session) ->
    Env = case Kept of
              {Interfaces, Previous, Same} ->
                  Same;
              {Built, Previous, Earlier} ->
                  case own_changes(Built, Interfaces, []) of
                      {Gone, Come} ->
                          Without = lists:foldl(fun ern_typecheck:without_interface/2, Earlier,
                                                Gone),
                          ern_typecheck:seeded(Come, Without);
                      changed ->
                          ern_typecheck:seeded(checked_interfaces(Session), prelude())
                  end;
              _ ->
                  ern_typecheck:seeded(checked_interfaces(Session), prelude())
          end,
    {Session#session{env = {Interfaces, Previous, Env}}, Env}.

%% How the interfaces Built became New, where each that went is one of the
%% session's own and each that came, after those that stayed, is one too:
%% those gone and those come; changed where any other went, came or moved.
own_changes([Same | Built], [Same | New], Gone) ->
    own_changes(Built, New, Gone);
own_changes([#interface{namespace = Namespace} = Went | Built], New, Gone) ->
    case is_session_namespace(Namespace) of
        true -> own_changes(Built, New, [Went | Gone]);
        false -> changed
    end;
own_changes([], Come, Gone) ->
    case lists:all(fun(#interface{namespace = Namespace}) -> is_session_namespace(Namespace) end,
                   Come) of
        true -> {Gone, Come};
        false -> changed
    end.

%% Report §11.2: what a reload needs of a declaring input to compile it
%% again: its text, where it came from, the name it prints with, and the
%% session's names as they stand at it, under which it was checked, so that
%% a later declaration of a name changes nothing the input meant: those its
%% text writes, since a name it does not write is none it meant, and every
%% member of a type, which an operator or a requirement's supply reaches
%% unwritten (§4.8, §4.9).
input_text(#checked{text = Text, origin = Origin, printed_name = PrintedName},
           #session{scope = Scope}) ->
    {ok, Tokens} = ern_lexer:tokenize(Text),
    Names = #{Name => true || {Category, _, Name} <- Tokens,
                              Category =:= ident orelse Category =:= typename},
    IsWritten = fun({_MemberOf, _Name}, _) -> true;
                   (Name, _) -> is_map_key(Name, Names)
                end,
    Written = #{Which => maps:filter(IsWritten, maps:get(Which, Scope, #{}))
                || Which <- [values, types, constructors]},
    #input_text{text = Text, origin = Origin, scope = Written, printed_name = PrintedName}.

%% Report §11.2, §4.6: the type an input gives a name, `it` among them,
%% closed as a top-level `let` that is not generalized closes its own, its
%% effect variables none or Never (ern_typecheck:settled/2); a `let` of a
%% lambda is generalized as in a block, and a declaring input gives no name
%% a type.
settled_input_type(Type, {lambda, _}, _Env) -> Type;
settled_input_type(Type, declarations, _Env) -> Type;
settled_input_type(Type, _Binds, Env) -> ern_typecheck:settled(Type, Env).

%% Report §4.6: the scheme a `let` of a lambda binds its name to, the
%% input's entry point's own over its result, the variables it quantifies
%% kept with their restrictions. Report §5.5, §11.2: of a `let` with `<-`,
%% the type of the names it binds, which its rest is called with, closed as
%% any other binding's, and the constructor of its sum type's value side.
generalized({arrow, Names}, Typed, Env) ->
    #e_block{statements = [_, #e_call{args = [Bound]}]} = entry_body(Typed),
    Constructor = case ern_typecheck:resolve_type(input_type(Typed, {arrow, Names}), Env) of
                      {tcon, ['Either'], _} -> 'Right';
                      {tcon, ['Optional'], _} -> 'Some'
                  end,
    {arrow, Names, ern_typecheck:settled(ern_typecheck:node_type(Bound), Env), Constructor};
generalized({lambda, Name}, Typed, Env) ->
    [#scheme{quantified = Quantified} = Scheme] =
        [EntryScheme || #fn_declaration{name = ?ENTRY, scheme = EntryScheme} <- Typed],
    Result = result_type(Scheme),
    TypeState = ern_typecheck:type_state(Env),
    Free = ern_types:free_variables(ern_types:substitute(Result, TypeState), TypeState),
    Kept = [Variable || {Id, _} = Variable <- Quantified, lists:member(Id, Free)],
    {lambda, Name, Scheme#scheme{quantified = Kept, type = Result}};
generalized(Binds, _Typed, _Env) ->
    Binds.

%% Report §11.2 *Faults*: the name and the line offset a spawn site in the
%% input is written with: the session's namespace as it prints and the
%% file the input's diagnostics name, `$Session2.input 3` or the startup
%% file's, and the lines as they count them.
site(Session, {typed, Name}) ->
    {site_name(Session, Name), 0};
site(Session, #startup_input{file = File, line = Line}) ->
    {site_name(Session, ern_build:shown(binary_to_list(File))), Line - 1}.

site_name(Session, File) ->
    unicode:characters_to_binary([ern_namespace:text(printed_namespace(Session)), ".", File]).

%% Report §11.2: an input is compiled and run on its own, so what it
%% binds must have a type by the time it runs; a later input cannot
%% settle it, as a later statement of a block would. A binding whose
%% type is still open is refused with the annotation that would settle
%% it, rather than entering the session as a scheme whose variables mean
%% nothing to the inputs after it.
undetermined(_Type, _Env, declarations, _Typed) ->
    none;
undetermined(_Type, _Env, it, _Typed) ->
    %% a bare expression runs and prints whatever its type; what it
    %% cannot do is bind `it`, which `declared/1` says
    none;
undetermined(_Type, _Env, {names, []}, _Typed) ->
    none;
undetermined(_Type, _Env, {lambda, _, _}, _Typed) ->
    %% its variables are its scheme's, quantified (report §4.6)
    none;
undetermined(_Type, Env, {arrow, _, NamesType, _} = Binds, Typed) ->
    %% report §5.5: what it binds is the value inside, whose type its names
    %% have; the value of `e`, shown where it binds nothing, may stay open
    unsettled(NamesType, Env, Binds, Typed);
undetermined(Type, Env, Binds, Typed) ->
    unsettled(Type, Env, Binds, Typed).

unsettled(Type, Env, Binds, Typed) ->
    TypeState = ern_typecheck:type_state(Env),
    case ern_types:free_variables(ern_types:substitute(Type, TypeState), TypeState) of
        [] ->
            none;
        _ ->
            Text = ern_types:format(Type, TypeState),
            {refused, #diagnostic{span = input_span(Typed),
                                  message = lists:flatten(
                                              io_lib:format(undetermined_text(Binds),
                                                            [bound_names(Binds), Text])),
                                  help = undetermined_help(ern_types:resolve(Type, TypeState),
                                                           Binds)}}
    end.

%% Report §11.2, §6.1: an address whose mailbox type is open is settled by
%% its annotation or by the mailbox type the spawned function declares;
%% any other type by an annotation.
undetermined_help({tcon, ['Address'], _}, {name, Name}) ->
    address_help(Name, "=");
undetermined_help({tcon, ['Address'], _}, {arrow, [Name], _, _}) ->
    address_help(Name, "<-");
undetermined_help(_, _) ->
    "bind it with an annotation that settles the variable, as in `let xs : List(Int) = []`, or"
    " declare a function with `fn`".

address_help(Name, Operator) ->
    "annotate the binding, `let " ++ atom_to_list(Name) ++ " : Address(T) " ++ Operator
    ++ " ...`, or give the spawned function its mailbox type, `fn() : Unit receiving T = ...`".

undetermined_text({arrow, Names, _, _}) ->
    undetermined_text({names, Names});
undetermined_text({names, [_, _ | _]}) ->
    "the types of ~s are not determined by this input; together they are ~ts";
undetermined_text(_) ->
    "the type of ~s is not determined by this input; it is ~ts".

bound_names({arrow, Names, _, _}) -> bound_names({names, Names});
bound_names({names, Names}) -> lists:join(", ", [atom_to_list(Name) || Name <- Names]);
bound_names({name, Name}) -> atom_to_list(Name).

%% Report §11.5: the input's binding whole, from its start to the end of its
%% value, as `ern build` underlines a top-level `let`.
input_span([#fn_declaration{name = ?ENTRY, body = Body} | _]) ->
    {_, _, End} = ern_diagnostic:span(ern_ast:span(Body)),
    {1, 1, End};
input_span([#fn_declaration{span = Span} | _]) -> ern_diagnostic:span(Span);
input_span(_) -> {1, 1, {1, 2}}.

%% An input that declares has no value; report §11.2 prints what it
%% declared, as an input of type Unit prints nothing.
input_type(_Typed, declarations) ->
    ?UNIT;
input_type(Typed, {arrow, _}) ->
    %% report §5.5: the value of `e` in `let p <- e`
    #e_block{statements = [#binding{expr = Expr} | _]} = entry_body(Typed),
    ern_typecheck:node_type(Expr);
input_type(Typed, _Binds) ->
    [Scheme] = [Scheme || #fn_declaration{name = ?ENTRY, scheme = Scheme} <- Typed],
    result_type(Scheme).

result_type(#scheme{type = {tfn, [], _, Result}}) -> Result;
result_type(#scheme{type = Type}) -> Type.

%% Report §11.2: a value of type `Unit` prints nothing.
-spec is_unit(#checked{}) -> boolean().
is_unit(#checked{type = Type, env = Env}) ->
    ern_typecheck:resolve_type(Type, Env) =:= ?UNIT.

%% Report §11.5: the type as the checker prints it.
-spec type_text(#checked{}) -> binary().
type_text(#checked{typed = Typed, type = Type, env = Env}) ->
    TypeState = ern_typecheck:type_state(Env),
    Text = case one_name(Typed) of
               {Namespace, Name} ->
                   case ern_typecheck:declared_scheme(Namespace, Name, Env) of
                       {ok, Scheme} -> ern_types:format_scheme(Scheme, TypeState);
                       error -> ern_types:format(Type, TypeState)
                   end;
               none ->
                   ern_types:format(Type, TypeState)
           end,
    unicode:characters_to_binary(Text).

%% Report §11.2: an input that is one name is printed with the name's
%% declared type, its variables named as the declaration names them.
one_name(Typed) ->
    case [Body || #fn_declaration{name = ?ENTRY, body = Body} <- Typed] of
        [#e_var{namespace = Namespace, name = Name}] -> {Namespace, Name};
        _ -> none
    end.

%% The input's own expression, the body of the entry point of an input
%% that does not declare.
entry_body(Typed) ->
    [Body] = [Body || #fn_declaration{name = ?ENTRY, body = Body} <- Typed],
    Body.

%% Report §11.2: the input runs in a process of its own, chained to the
%% session, so that what it starts writes to the session's screen through
%% the session's row (start/5) and is the node's once the session detaches;
%% the outcome goes to `Address`, so the shell's reader stays live and the
%% address is what an interruption kills.
%%
%% The unit is compiled, loaded and recorded here, in the session's
%% process, and the input's process is given what it needs to compute its
%% value, and not the session: it answers its value with its binding, by
%% which the session binds it in its own process once the answer is in
%% (collect/3), and writes nothing of the session's itself. An expression's
%% unit holds the value `it` names. The process of an input that binds a
%% name lives on while a name it bound is in scope, so that what the
%% binding opened stays open (binders/0).
%%
%% Report §11.2, §7.4: a full table of processes, which leaves no room for
%% the compiler's process or the input's own, answers the input's fault,
%% `error:system_limit`, with no trace, and the session goes on. The input
%% has then made nothing, and the session it answers beside the fault has
%% its number to give again, as a collection gives an unloaded input's
%% (collected/1, report §2.3), so that a full table costs no atoms.
-spec spawn_input(#session{}, #checked{}, integer(), term()) ->
          {'Right', ern_rt:address()} | {'Left', {#session{}, binary()}}.
spawn_input(Session, #checked{namespace = Namespace} = Checked, Serial, Address) ->
    try {'Right', input_spawned(Session, Checked, Serial, Address)}
    catch
        error:system_limit ->
            {'Left', {Session#session{free = Session#session.free ++ [Namespace]},
                      ern_rt:host_cause(error, system_limit)}}
    end.

input_spawned(Session, #checked{namespace = Namespace, typed = Typed, interface = Interface,
                              env = Env, type = Type, binds = Binds,
                              site = {InputName, Offset}} = Checked,
            Serial, Address) ->
    Descriptor = ern_descriptor:describe(Type, Env, []),
    Plan = binding_plan(Binds, Type, Env),
    Build = (build_holding(Plan, Namespace))#{source_hash => <<>>, deps => [],
                                              session_offset => Offset,
                                              form_namespace => session_namespace(Session),
                                              site_namespace => printed_namespace(Session),
                                              units => Session#session.units,
                                              input_name => InputName},
    {ok, ErlangModule, Beam} = ern_compile:compile(Namespace, Typed, Interface, Env, Build),
    %% report §11.1: the interface as compiled, with the hash of each of its
    %% definitions, by which a later input's forms name them; whether the
    %% input's code builds a function value, which the emitter says; and
    %% the other units' definitions its forms name (record_uses/5)
    {ok, #{interface := Compiled} = Chunk} = ern_interface:read(Beam),
    {module, ErlangModule} = code:load_binary(ErlangModule, atom_to_list(ErlangModule), Beam),
    unit_loaded(ErlangModule, Beam),
    Binding = binding(Plan, Session, Checked, ErlangModule, Beam, Compiled),
    KeptNeeds = kept_needs(),
    record_uses(ErlangModule, Beam, Checked, Chunk, held_value(Binding)),
    %% report §11.2: an input that declares keeps its text, to be compiled
    %% again as a new version of its input where a reload changes what it
    %% references (reached_inputs/2)
    Binds =:= declarations andalso keep({input_text, Namespace}, input_text(Checked, Session)),
    Entry = entry(Session, ErlangModule, Binds),
    Body = fun() ->
               %% report §11.2, Appendix E.21: the session's own while it
               %% runs, which Process.live() leaves out, marked before
               %% anything of the input's runs
               ern_rt:own_input(self()),
               %% report §11.2: the input's own fault is its answer, caught
               %% here, so that its process does not end with a fault; its
               %% cause, its trace, a frame a line (Appendix E.21), and the
               %% callee's site and the peer's name a call or a compute
               %% carried it with (§6.6, §8.7). An input that binds a name
               %% is the binder of its holder, which the session lets go
               %% once nothing in scope names it (binders/0).
               {Outcome, Binder} =
                   try value(ErlangModule, Entry, Binds) of
                       Value ->
                           Holding = binder(Binding, Value),
                           {{'Ok', #bound{binding = Binding, binder = Holding}, Serial,
                             #value{term = Value, descriptor = Descriptor}}, Holding}
                   catch
                       Class:Error:Stack ->
                           {Cause, Trace, Callee, Peer} = caught_fault(Class, Error, Stack),
                           {{'Faulted', Cause, Trace, Callee, Peer, Serial}, none}
                   end,
               ern_rt:send(Address, Outcome),
               Binder =:= none orelse bound_lives(ern_rt:process_of(Address))
           end,
    Site = <<InputName/binary, ":", (integer_to_binary(1 + Offset))/binary>>,
    Input = try ern_rt:spawn(Body, Site)
            catch
                error:system_limit:Stack ->
                    unspawned(ErlangModule, Namespace, KeptNeeds),
                    erlang:raise(error, system_limit, Stack)
            end,
    %% report §11.2: the input that runs, which the session's end ends
    %% where it runs still (detach/0)
    keep(input, ern_rt:process_of(Input)),
    Input.

%% Report §11.2, §7.4: an input whose own process a full table leaves no
%% room for ran nothing, and what its unit made is undone: its text goes,
%% the needs the session keeps are as they were before it was recorded,
%% and its unit is deleted, out of the code table, and forgotten, as a
%% collection lets an input's go (collected/1); its number goes back with
%% the session spawn_input/4 answers.
unspawned(ErlangModule, Namespace, KeptNeeds) ->
    forgotten({input_text, Namespace}),
    keep(kept_needs, KeptNeeds),
    unload(ErlangModule),
    forget_units([ErlangModule]).

%% Report §11.2: what an input binds, with the scheme each name takes, made
%% in the session's process from the input's type as it is spawned, so that
%% its answer carries what the session binds its value by and the session
%% keeps no checker's environment for it: the value `it` names, where the
%% input settles its type; the names a `let` binds, each a component of its
%% value's tuple where it binds several, and for a `let` with `<-` the
%% constructor of its sum type's value side that holds them (§5.5), with
%% `it` for the `Left` or the `None` it shows, where the input settles the
%% type of `e`, as an expression's value is bound; what it declares; or
%% nothing, `let _ = e` among it.
binding_plan(declarations, _Type, _Env) ->
    declarations;
binding_plan(it, Type, Env) ->
    case is_open(Type, Env) of
        true -> none;
        false -> {it, binding_scheme(Type, ern_typecheck:type_state(Env))}
    end;
binding_plan({names, Names}, Type, Env) ->
    named(Names, Type, Env);
binding_plan({arrow, Names, NamesType, Constructor}, Type, Env) ->
    Named = case named(Names, NamesType, Env) of
                none -> [];
                {names, Given} -> Given
            end,
    case {Named, binding_plan(it, Type, Env)} of
        {[], none} -> none;
        {_, Shown} -> {arrow, Constructor, Named, Shown}
    end;
binding_plan({lambda, Name, Scheme}, _Type, _Env) ->
    {names, [{Name, Scheme}]};
binding_plan({name, Name}, Type, Env) ->
    named([Name], Type, Env).

%% Each name a pattern binds with its scheme: the value's type for one
%% name, a component of its tuple's for each of several; none for none.
named([], _Type, _Env) ->
    none;
named([Name], Type, Env) ->
    {names, [{Name, binding_scheme(Type, ern_typecheck:type_state(Env))}]};
named(Names, Type, Env) ->
    TypeState = ern_typecheck:type_state(Env),
    {ttuple, Types} = ern_types:substitute(Type, TypeState),
    {names, [{Name, binding_scheme(Component, TypeState)}
             || {Name, Component} <- lists:zip(Names, Types)]}.

%% Report §11.2: the build of an expression that binds `it`, and of a `let`
%% with `<-` that binds it to the `Left` or the `None` it shows, whose unit
%% holds the value under a getter of its own, as a binding of the input's
%% entry (ern_compile).
build_holding({it, _}, Namespace) ->
    #{held => {it, Namespace ++ [?ENTRY]}};
build_holding({arrow, _Constructor, _Named, {it, _} = Shown}, Namespace) ->
    build_holding(Shown, Namespace);
build_holding(_Plan, _Namespace) ->
    #{}.

%% Report §11.2, §8.7, Appendix H: what the session binds the input's value
%% by once it has answered (collect/3), made from its plan in the session's
%% process before the spawn, so that the binding needs no checker's
%% environment: for `it`, the key the unit's getter reads, at the position
%% the compiled interface gives it, and the interface of `it` the session
%% joins; for a `let`, its names with their schemes, the constructor that
%% holds them for a `<-`, with what binds `it` to the other side, and what
%% its holder's forms name it by, the session's namespace and the input's
%% entry's hash, each name a binding of it; for declarations, what the
%% session joins.
binding(none, _Session, _Checked, _ErlangModule, _Beam, _Compiled) ->
    none;
binding(declarations, _Session, #checked{namespace = Namespace, printed_name = PrintedName},
        _ErlangModule, Beam, Compiled) ->
    {declared, #scoped{interface = Compiled, declared = {Namespace, Beam, PrintedName}}};
binding({it, Scheme}, _Session, #checked{namespace = Namespace}, ErlangModule, _Beam,
        #interface{identities = Identities, positions = Positions}) ->
    It = Namespace ++ [it],
    Position = maps:get(It, Positions),
    Interface = #interface{namespace = Namespace, values = #{It => Scheme}, lets = [It],
                           identities = #{It => maps:get(Namespace ++ [?ENTRY], Identities)},
                           positions = #{It => Position}},
    {held, {ErlangModule, ern_emitter:function_name(Position)}, #scoped{interface = Interface}};
binding({names, Named}, Session, #checked{namespace = Namespace}, _ErlangModule, _Beam,
        Compiled) ->
    {holder, Named, holding(Session, Namespace, Compiled)};
binding({arrow, Constructor, Named, Shown}, Session, #checked{namespace = Namespace} = Checked,
        ErlangModule, Beam, Compiled) ->
    {holder_under, Constructor, Named, holding(Session, Namespace, Compiled),
     binding(Shown, Session, Checked, ErlangModule, Beam, Compiled)}.

holding(Session, Namespace, Compiled) ->
    {session_namespace(Session), entry_hash(Namespace, Compiled)}.

%% The keys the input's unit keeps a value under, `it`'s, with the name in
%% scope that reaches it, or none.
held_value({held, Key, #scoped{interface = #interface{lets = Names}}}) -> {[Key], Names};
held_value({holder_under, _Constructor, _Named, _Holding, Shown}) -> held_value(Shown);
held_value(_Binding) -> {[], []}.

%% Report §11.2: the input's own process where the session makes a holder
%% of what its value binds, a `let`'s names, whose binder it is; none for
%% every other binding, a `<-` whose value is a `Left` or a `None` among
%% them, which binds no name (§5.5).
binder({holder, _Named, _Holding}, _Value) -> erlang:self();
binder({holder_under, Constructor, [_ | _], _Holding, _Shown}, {Constructor, _}) ->
    erlang:self();
binder(_Binding, _Value) -> none.

%% Report §11.2: what the input bound of its value, in the session's own
%% process, the session with it, and the holder that holds it, or none:
%% `it` kept under its unit's getter, needing the session's units whose
%% functions it holds; a `let`'s names kept by a holder of their own, given
%% a namespace of the session's; and a `<-` whose value is a `Left` or a
%% `None` binding no name, and that value to `it`, kept as an expression's
%% is (§5.5). Neither unit is marked as one whose bindings have their
%% values (ern_rt:initialized/1), which only a peer's spawn reads, since no
%% peer can name a session's binding (Appendix H).
bound_value(none, _Value, Session) ->
    {#scoped{}, none, Session};
bound_value({declared, Scoped}, _Value, Session) ->
    {Scoped, none, Session};
bound_value({held, {ErlangModule, _} = Key, Scoped}, Value, Session) ->
    persistent_term:put(Key, Value),
    case held_functions(Value, []) -- [ErlangModule] of
        [] -> ok;
        Held -> needs_added(ErlangModule, Held)
    end,
    {Scoped, none, Session};
bound_value({holder, Named, Holding}, Value, Session) ->
    holder_bound(paired(Named, Value), Holding, Session);
bound_value({holder_under, Constructor, [], _Holding, _Shown}, {Constructor, _}, Session) ->
    {#scoped{}, none, Session};
bound_value({holder_under, Constructor, Named, Holding, _Shown}, {Constructor, Bound}, Session) ->
    holder_bound(paired(Named, Bound), Holding, Session);
bound_value({holder_under, _Constructor, _Named, _Holding, Shown}, Value, Session) ->
    bound_value(Shown, Value, Session).

%% Each name a pattern bound with its value and its scheme: the whole value
%% for one name, a component of its tuple for each of several.
paired([{Name, Scheme}], Value) ->
    [{Name, Value, Scheme}];
paired(Named, Value) ->
    [{Name, Component, Scheme} || {{Name, Scheme}, Component} <- lists:zip(Named,
                                                                            tuple_to_list(Value))].

%% Report §11.2: the process of an input that bound a name, which lives
%% while a name it bound is in scope: until the session lets the last of
%% them go, by `:forget` or a later input that binds or declares the name
%% (leaving/2, let_go/0), or the session ends.
bound_lives(SessionProcess) ->
    MonitorRef = erlang:monitor(process, SessionProcess),
    receive
        {?MODULE, let_go} -> erlang:demonitor(MonitorRef, [flush]), ok;
        {'DOWN', MonitorRef, process, SessionProcess, _} -> ok
    end.

%% Report §11.2: the processes of the inputs that bound names, each by the
%% holder of what it bound.
binders() ->
    kept(binders, #{}).

%% Report §11.2 *Inputs*: each binder none of whose names is in the
%% session's scope any more set to go, with the names its holder held,
%% Units holding the holder, so that the session asks what it owned while
%% it lives (going/0) and then lets it go (let_go/0); Named holds each
%% holder a name in scope reaches (collected/1).
leaving(Named, Units) ->
    {Live, Gone} = lists:partition(fun({Holder, _}) ->
                                       is_map_key(ern_namespace:erlang_module(Holder), Named)
                                   end, maps:to_list(binders())),
    Gone =:= [] orelse
        begin
            keep(binders, maps:from_list(Live)),
            keep(going, going() ++ [{Pid, holder_names(Holder, Units)} || {Holder, Pid} <- Gone])
        end,
    ok.

%% The names a holder held, each as the session writes it.
holder_names(Holder, Units) ->
    case maps:find(ern_namespace:erlang_module(Holder), Units) of
        {ok, #session_unit{names = Names}} -> [atom_to_binary(lists:last(Name)) || Name <- Names];
        error -> []
    end.

%% Report §11.2 *Inputs*: the processes of the inputs the session's
%% collections set to go, each with the names its holder held, which the
%% session asks what each owned of before it lets them go (let_go/0).
-spec going() -> [{pid(), [binary()]}].
going() ->
    kept(going, []).

%% Report §11.2 *Inputs*: the processes the session's collections set to
%% go let go, each ending, and what it owned with it (E.18, E.23, G.1).
-spec let_go() -> 'Unit'.
let_go() ->
    lists:foreach(fun({Pid, _}) -> Pid ! {?MODULE, let_go} end, going()),
    keep(going, []),
    'Unit'.

%% Report §11.2: what the input's unit needs of the session's units, kept
%% while it is (collected/1): where the session keeps it, those its code
%% calls, since its code may run again, and those whose definitions its
%% forms name, a type its body alone names among them, as a peer's spawn
%% of its function ships them (§8.7), which the chunk's `references` holds,
%% each definition by the qualified name its declaring input's interface
%% gives it and its hash; and where it declares or holds a
%% value, those whose types its interface names.
%%
%% Then the keys it keeps a value under, and the names in scope that reach
%% them; whether the session keeps its code while it runs, and whether the
%% node keeps it for its life once the session has detached; and the name
%% its spawn sites are written with. A unit that holds `it` and that the session does not
%% keep needs none of what its code called, which runs no more. Chunk is
%% the unit's interface chunk as read.
record_uses(ErlangModule, Beam, Checked, Chunk) ->
    record_uses(ErlangModule, Beam, Checked, Chunk, {[], []}).

record_uses(ErlangModule, Beam, #checked{namespace = Namespace, interface = Interface,
                                         binds = Binds, site = {InputName, _}},
            #{builds_functions := BuildsFunctions, references := References}, {Keys, Names}) ->
    Kept = is_kept(Binds, BuildsFunctions),
    {ok, {_, [{imports, Imports}]}} = beam_lib:chunks(Beam, [imports]),
    Calls = [Imported || Kept, {Imported, _, _} <- Imports, is_session_module(Imported),
                         Imported =/= ErlangModule],
    Referenced = case Kept of
                     true -> mentions(References, Namespace);
                     false -> []
                 end,
    Named = case Binds =:= declarations orelse Keys =/= [] of
                true -> mentions(Interface, Namespace);
                false -> []
            end,
    unit_recorded(ErlangModule, #session_unit{namespace = Namespace,
                                              needs = lists:usort(Calls ++ Referenced ++ Named),
                                              keys = Keys, names = Names, kept = Kept,
                                              lasting = lasting(ErlangModule, Binds,
                                                                BuildsFunctions)}),
    node_keep({input_name, ErlangModule}, InputName),
    ok.

%% Report §11.2: whether the session keeps an input's code while it runs:
%% one that declares, or whose code builds a function value, a lambda, an
%% adapted address's function, a function taken as a value, which may then
%% be held anywhere, as a program's modules are, and past an attached
%% session's detach where it declares a function or builds one (lasting/3);
%% the emitter marks which builds one (ern_emitter's function_value/2), and
%% the interface chunk records it, `builds_functions`. An expression's that
%% binds `it` holds its value, and is kept while a name reaches it. Any
%% other is done with its module once its answer is in, whether it faulted
%% or not: no process runs its code then, and no value holds a function of
%% it, so the collection that follows the answer deletes and purges it,
%% and gives its number, and so its name's atoms, to the next input
%% (collected/1, report §2.3).
is_kept(Binds, BuildsFunctions) ->
    Binds =:= declarations orelse BuildsFunctions.

%% Report §11.2: whether the node keeps an input's unit for its life once
%% the session has detached, as a load's are: one whose code builds a
%% function value, and one that declares a function, a function or a
%% foreign function its '$code'/0 lists, a member a type derives among
%% them, since a process may hold a function of it anywhere and the host
%% cannot tell which: erlang:check_process_code/2 counts no function value
%% as code a process holds. An input that declares types alone, or that
%% declares nothing, makes no function a value may hold.
lasting(_ErlangModule, _Binds, true) ->
    true;
lasting(ErlangModule, declarations, false) ->
    lists:any(fun({_, {function, _, _, _, _, _}}) -> true;
                 ({_, {foreign, _, _, _, _}}) -> true;
                 (_) -> false
              end, ErlangModule:'$code'());
lasting(_ErlangModule, _Binds, false) ->
    false.

%% Whether a namespace the session let go is an input's or a holder's.
kind_of_namespace([Segment]) ->
    case is_holder_segment(Segment) of
        false -> input;
        true -> holder
    end.

%% Report §8.7, §11.2: a module the session loaded, in the code table as it
%% loads, and each of the host's limits the load has brought near said. A
%% holder of values holds no definition. A unit the session compiled or
%% read, which it loads from no file, has what its compiled form records of
%% its definitions kept beside its code in the table, their canonical
%% forms with their names and their source's lines, so that a spawn on a
%% peer that lacks one of them ships it, as the build's ship theirs from
%% its `.erc` (§12.7, §11.2); they go with the unit's rows when it is
%% deleted (unload/1).
unit_loaded(Unit, Beam) ->
    {ok, Recorded} = ern_canonical:read(Beam),
    ern_code:loaded(Unit, Beam, Recorded),
    ern_cli:say_limits().

%% A holder of values, which holds no definition and records none.
holder_loaded(ErlangModule, Beam) ->
    ern_code:loaded(ErlangModule, Beam),
    ern_cli:say_limits().

%% A module of the session's that no process runs and nothing reaches,
%% deleted, out of the code table, and purged.
unload(ErlangModule) ->
    code:delete(ErlangModule),
    ern_code:unloaded(ErlangModule),
    code:purge(ErlangModule),
    ok.

%% Report §11.1: the input's entry, the function its unit names by its
%% position, which its '$code'/0 names under the session's namespace; none
%% for an input that declares, which has none.
entry(_Session, _ErlangModule, declarations) ->
    none;
entry(Session, ErlangModule, _Binds) ->
    {Entry, _} = ern_code:function(ErlangModule, session_namespace(Session) ++ [?ENTRY]),
    Entry.

%% An input that declares runs nothing, having no top-level value to
%% compute (declarations/1). Its value is Unit, which prints nothing (report
%% §11.2).
value(_ErlangModule, none, declarations) ->
    'Unit';
value(ErlangModule, Entry, {arrow, _, _, Constructor}) ->
    %% report §5.5, §11.2: the session stands for the block's rest, which
    %% answers what the pattern bound under the sum type's value side; the
    %% session binds the names it holds and prints them, and binds to `it`
    %% and prints a `Left` or a `None` (declared/2): the outcome's
    %% descriptor is the type of `e`, which describes a `Left` or a `None`
    %% and not the names
    ErlangModule:Entry(fun(Bound) -> {Constructor, Bound} end);
value(ErlangModule, Entry, _Binds) ->
    ErlangModule:Entry().

%% Report §7.3, §7.4: the cause of a fault the shell catches in a process
%% of its own, an input's, its trace (Appendix E.21), and
%% report §6.6, §8.7: the callee's site and the peer's name a call or a
%% compute carried it with, each `None` or `Some`, as the runtime gives a
%% process's (ern_rt:met/3). What such a catch meets is a fault of the
%% process's own: the one other end a process of the runtime's meets,
%% `carried`, is a compute's process's, which throws it after its
%% function's catch once its caller has the fault (report §8.7), and so
%% runs no input and no binding.
caught_fault(Class, Error, Stack) ->
    #fault{cause = Cause, trace = Trace, callee = Callee, peer = Peer} =
        ern_rt:met(Class, Error, Stack),
    {Cause, Trace, optional(Callee), optional(Peer)}.

optional(none) -> 'None';
optional(Text) -> {'Some', Text}.

%% Appendix E.1: the value as Ernest writes it, by the descriptor of its
%% type; report §11.2: to the depth and the length the session is set to,
%% where 0 is neither.
-spec show(#value{}, integer(), integer()) -> binary().
show(#value{term = Value, descriptor = Descriptor}, Depth, Length) ->
    ern_show:show(Descriptor, Value, limit(Depth), limit(Length)).

limit(Count) when Count =< 0 -> unbounded;
limit(Count) -> Count.

%% Report §11.2: what the session declares, a line for each as an input's
%% own declarations print, its types first and then its values by name.
-spec bindings(#session{}) -> [binary()].
bindings(#session{scope = Scope} = Session) ->
    Types = [unicode:characters_to_binary(type_line(Name, QualifiedName, Session))
             || {Name, QualifiedName} <- lists:sort(maps:to_list(maps:get(types, Scope, #{})))],
    TypeState = session_type_state(Session),
    Schemes = [{name_text(Key), Scheme}
               || {Key, QualifiedName} <- maps:to_list(maps:get(values, Scope, #{})),
                  {ok, Scheme} <- [scheme(QualifiedName, Session)]],
    Values = [unicode:characters_to_binary(
                [Text, " : ", ern_types:format_scheme(Scheme, TypeState)])
              || {Text, Scheme} <- lists:sort(Schemes)],
    Types ++ Values.

%% Report §11.2: what may stand where the cursor is, which the parser
%% knows and nothing else does: it says what it wanted where it stopped
%% (§11.5's diagnostic carries the tag). Both readings are tried, as
%% `input/1` tries them. Completion decides for itself which kinds of
%% name a slot admits; this only answers the slot, an
%% `Ernest.Shell.Complete.Slot`.
-spec slot(binary()) -> atom() | {'Fields', [{'Name', binary(), atom(), binary()}]}.
slot(Before) ->
    %% a line being typed is read and not run, so reading it makes no name:
    %% the host keeps a name for ever, and a `Tab` is pressed at every word
    ok = stdlib_met(),
    Read = [no_new_names],
    case [What || {true, What} <- [wanted(ern_parser:parse_expr(Before, Read)),
                                   wanted(ern_parser:parse_string(Before, Read))],
                  What =/= undefined] of
        [What | _] -> slot_for(What);
        [] -> 'Expression'
    end.

wanted({error, #diagnostic{incomplete = Incomplete, expected = What}}) -> {Incomplete, What};
wanted(_) -> {false, undefined}.

%% A name that names something has been met: the session's, when its input
%% ran, a loaded module's, when its interface was read, and the standard
%% library's once its interfaces are read, which is done here, once, before
%% a line is first read without making names.
stdlib_met() ->
    case persistent_term:get({?MODULE, stdlib_met}, false) of
        true ->
            ok;
        false ->
            _ = ern_prelude:stdlib_interfaces(),
            persistent_term:put({?MODULE, stdlib_met}, true)
    end.

slot_for(expression) -> 'Expression';
slot_for(typename) -> 'TypeName';
slot_for(pattern) -> 'Pattern';
slot_for(declaration) -> 'Declaration';
slot_for(#expected_field{kind = field, namespace = Namespace, constructor_name = ConstructorName,
                         segments = Segments}) ->
    {'Fields', fields_of(Namespace, ConstructorName, Segments)};
%% the parser could not tell a field's name from a value; the
%% constructor's type can, and only a named constructor has fields
slot_for(#expected_field{kind = field_or_value, namespace = Namespace,
                         constructor_name = ConstructorName}) ->
    case fields_of(Namespace, ConstructorName, []) of
        [] -> 'Expression';
        Fields -> {'Fields', Fields}
    end;
slot_for(#expected_field{kind = field_or_pattern, namespace = Namespace,
                         constructor_name = ConstructorName}) ->
    case fields_of(Namespace, ConstructorName, []) of
        [] -> 'Pattern';
        Fields -> {'Fields', Fields}
    end.

%% The fields of the constructor as it is written, found as the checker
%% finds it (report §4.2): unqualified, the session's or the prelude's, and
%% qualified, its module's; after a path's segments (report §5.6), the
%% fields of the type the path has reached.
%% Report §11.2: each as an `Ernest.Shell.Complete.Name`, listed with its
%% type, the constructor's parameter in the field's place, both in declared
%% order.
fields_of(Namespace, ConstructorName, Segments) ->
    Session = kept_session(),
    Written = named_constructor(Session, Namespace, ConstructorName),
    case along_path(Written, Segments, Session) of
        {ok, #constructor_info{fields = {named, Fields},
                               scheme = #scheme{type = {tfn, Params, _, _}}}} ->
            TypeState = session_type_state(Session),
            [name('Value', atom_to_list(Field),
                  atom_to_list(Field) ++ " : " ++ ern_types:format(Param, TypeState))
             || {Field, Param} <- lists:zip(Fields, Params)];
        _ ->
            []
    end.

%% Report §5.6, §11.2: the constructor a path's segments reach from one,
%% each segment a named field whose type has one constructor; none where
%% a segment is no such field.
along_path({ok, ConstructorInfo}, [], _Session) ->
    {ok, ConstructorInfo};
along_path({ok, #constructor_info{fields = {named, Fields},
                                  scheme = #scheme{type = {tfn, Params, _, _}}}},
           [Segment | Rest], Session) ->
    case field_index(Segment, Fields, none) of
        none -> none;
        Index ->
            case lists:nth(Index + 1, Params) of
                {tcon, QualifiedName, _} ->
                    along_path(one_constructor(QualifiedName, Session), Rest, Session);
                _ -> none
            end
    end;
along_path(_, _, _) ->
    none.

%% The one constructor of a type in scope, or none.
one_constructor(QualifiedName, #session{interfaces = Interfaces}) ->
    Found = [TypeInfo || #interface{types = #{QualifiedName := TypeInfo}} <- Interfaces]
        ++ [TypeInfo || TypeInfo <- [ern_typecheck:lookup_type(QualifiedName, prelude())],
                        TypeInfo =/= undefined],
    case Found of
        [#type_info{constructors = [ConstructorInfo]} | _] -> {ok, ConstructorInfo};
        _ -> none
    end.

%% Report §11.2: every name completion may reach — the session's, the
%% prelude's, and each module in scope with its exports — as
%% `Ernest.Shell.Complete.Name`, whose fields are in declared order (§3.5):
%% the text as it is typed, its kind, the line a listing shows. Only the
%% reading of the interfaces is the host's; the matching is Ernest's.
-spec names() -> [{'Name', binary(), atom(), binary()}].
names() ->
    names(kept_session()).

names(#session{interfaces = Interfaces, scope = Scope} = Session) ->
    Prelude = prelude(),
    TypeState = session_type_state(Session),
    %% report §4.5: a member is no name an expression writes, the session's
    %% `T.f` and a prelude type's alike, and does not complete
    Declared = [name('Value', name_text(Key),
                     scheme_line(name_text(Key), QualifiedName, Session, TypeState))
                || {Key, QualifiedName} <- maps:to_list(maps:get(values, Scope, #{})),
                   is_atom(Key)]
        ++ [name('Type', atom_to_list(Name), type_line(Name, QualifiedName, Session))
            || {Name, QualifiedName} <- maps:to_list(maps:get(types, Scope, #{}))]
        ++ [name('Constructor', atom_to_list(Name),
                 constructor_line(atom_to_list(Name),
                                  constructor_scheme(QualifiedName, Session), TypeState))
            || {Name, QualifiedName} <- maps:to_list(maps:get(constructors, Scope, #{}))],
    {PreludeTypes, _} = ern_typecheck:prelude_names(Prelude),
    %% report §11.5: a prelude value's type as `:type` prints it, its marks
    %% with it
    PreludeState = ern_typecheck:type_state(Prelude),
    PreludeNames = [name('Value', Text, Text ++ " : " ++ ern_types:format_scheme(Scheme,
                                                                                PreludeState))
                    || {QualifiedName, Scheme} <- ern_typecheck:prelude_values(Prelude),
                       not ern_prelude:is_member(QualifiedName),
                       Text <- [ern_namespace:text(QualifiedName)]]
        ++ [name('Type', Text, "type " ++ Text)
            || QualifiedName <- PreludeTypes,
               Text <- [ern_namespace:text(QualifiedName)]]
        ++ [name('Constructor', Text, constructor_line(Text, {ok, Scheme}, TypeState))
            || {QualifiedName, #constructor_info{scheme = Scheme}}
                   <- maps:to_list(ern_typecheck:prelude_constructors(Prelude)),
               Text <- [ern_namespace:text(QualifiedName)]],
    ModuleNames = lists:append([module_names(Interface, TypeState)
                            || Interface <- Interfaces ++ ern_prelude:stdlib_interfaces()]),
    %% report §11.2: an operator is no name, and does not complete, and
    %% neither does a module the session made, which is spelled as no name
    lists:usort([Name || {'Name', Text, _, _} = Name <- Declared ++ PreludeNames ++ ModuleNames,
                         is_name_text(Text)]).

%% Every segment of a text begins with a letter or `_`, as a name's does.
is_name_text(Text) ->
    lists:all(fun(<<Char, _/binary>>) ->
                      Char =:= $_ orelse (Char >= $a andalso Char =< $z)
                          orelse (Char >= $A andalso Char =< $Z);
                 (_) ->
                      false
              end, binary:split(Text, <<".">>, [global])).

%% Report §11.2: a constructor is listed with its type, as a value is.
constructor_line(Text, {ok, Scheme}, TypeState) ->
    Text ++ " : " ++ ern_types:format_scheme(Scheme, TypeState);
constructor_line(Text, none, _) -> Text.

constructor_scheme(QualifiedName, #session{interfaces = Interfaces}) ->
    case constructor_info(QualifiedName, Interfaces) of
        {ok, #constructor_info{scheme = Scheme}} -> {ok, Scheme};
        none -> none
    end.

%% Report §11.2: the names `:forget` takes, the values and the types the
%% session declares; a member goes with its type.
-spec session_names() -> [{'Name', binary(), atom(), binary()}].
session_names() ->
    #session{scope = Scope} = Session = kept_session(),
    TypeState = session_type_state(Session),
    lists:usort([name('Value', name_text(Key),
                      scheme_line(name_text(Key), QualifiedName, Session, TypeState))
                 || {Key, QualifiedName} <- maps:to_list(maps:get(values, Scope, #{})),
                    is_atom(Key)]
                ++ [name('Type', atom_to_list(Name), type_line(Name, QualifiedName, Session))
                    || {Name, QualifiedName} <- maps:to_list(maps:get(types, Scope, #{}))]).

%% Report §11.2: every name the session declares, as it is written, its
%% values, members among them, its types, and its constructors: with
%% nothing typed, these and the modules are what completion lists.
-spec session_texts() -> [binary()].
session_texts() ->
    #session{scope = Scope} = kept_session(),
    lists:usort([unicode:characters_to_binary(name_text(Key))
                 || Which <- [values, types, constructors],
                    Key <- maps:keys(maps:get(Which, Scope, #{}))]).

%% Report §11.2: where `:load` finds a module's source, `--source-root`.
-spec source_root() -> binary().
source_root() ->
    #session{source_root = SourceRoot} = kept_session(),
    unicode:characters_to_binary(SourceRoot).

%% Report §11.1, §4.2: the namespace segment a file or directory of the
%% source root names, by the compiler's own rule, or None where it names
%% no module.
-spec segment(binary()) -> 'None' | {'Some', binary()}.
segment(Name) ->
    case ern_namespace:segment(unicode:characters_to_list(Name)) of
        {ok, Segment} -> {'Some', unicode:characters_to_binary(Segment)};
        error -> 'None'
    end.

%% Report §11.1, §4.2: the path component a namespace segment names, where
%% it is one, `kv_parser` for `KvParser`; the inverse of segment/1, asked of
%% the same owner.
-spec component(binary()) -> {'Some', binary()} | 'None'.
component(Segment) ->
    case ern_namespace:component(unicode:characters_to_list(Segment)) of
        {ok, Component} -> {'Some', unicode:characters_to_binary(Component)};
        error -> 'None'
    end.

%% A module in scope: the module itself, its exported values and types,
%% and the constructors of those types, each by the name a person types.
module_names(#interface{namespace = Namespace, types = Types, values = Values}, TypeState) ->
    ModuleText = ern_namespace:text(Namespace),
    %% report §4.5: a member of the module's type, `M.T.f`, or of the
    %% prelude type the module provides, `Int.compare`, is no name
    [name('Module', ModuleText, "module " ++ ModuleText)]
        ++ [name('Value', Text, Text ++ " : " ++ ern_types:format_scheme(Scheme, TypeState))
            || {QualifiedName, Scheme} <- maps:to_list(Values),
               length(QualifiedName) =:= length(Namespace) + 1,
               not ern_prelude:is_member(QualifiedName),
               Text <- [ern_namespace:text(QualifiedName)]]
        ++ lists:append([type_names(QualifiedName, TypeInfo, TypeState)
                         || {QualifiedName, TypeInfo} <- maps:to_list(Types)]).

%% A type in scope and, unless it is abstract, its constructors, each named
%% in the type's namespace.
type_names(QualifiedName, #type_info{constructors = Constructors} = TypeInfo, TypeState) ->
    Text = ern_namespace:text(QualifiedName),
    Namespace = lists:droplast(QualifiedName),
    [name('Type', Text, type_keyword(TypeInfo) ++ "type " ++ Text)
     | [name('Constructor', ConstructorText,
             constructor_line(ConstructorText, {ok, Scheme}, TypeState))
        || not TypeInfo#type_info.abstract,
           #constructor_info{name = ConstructorName, scheme = Scheme} <- Constructors,
           ConstructorText <- [ern_namespace:text(Namespace ++ [ConstructorName])]]].

name(Kind, Text, Shown) ->
    {'Name', unicode:characters_to_binary(Text), Kind, unicode:characters_to_binary(Shown)}.

scheme_line(Text, QualifiedName, Session, TypeState) ->
    case scheme(QualifiedName, Session) of
        {ok, Scheme} -> Text ++ " : " ++ ern_types:format_scheme(Scheme, TypeState);
        none -> Text
    end.

type_info(QualifiedName, #session{interfaces = Interfaces}) ->
    case [TypeInfo || #interface{types = Types} <- Interfaces,
                      #{QualifiedName := TypeInfo} <- [Types]] of
        [] -> none;
        TypeInfos -> lists:last(TypeInfos)
    end.

name_text({MemberOf, Name}) -> atom_to_list(MemberOf) ++ "." ++ atom_to_list(Name);
name_text(Name) -> atom_to_list(Name).

scheme(QualifiedName, #session{interfaces = Interfaces}) ->
    case [Scheme || #interface{values = Values} <- Interfaces,
                    #{QualifiedName := Scheme} <- [Values]] of
        [] -> none;
        Schemes -> {ok, lists:last(Schemes)}
    end.

%% The state a session name's type is printed under: the session's types
%% print unqualified, as they do in an input (report §11.2).
session_type_state(#session{scope = Scope} = Session) ->
    TypeState = ern_typecheck:scope_state(checked_interfaces(Session), prelude()),
    ern_types:set_scope([], maps:values(maps:get(types, Scope, #{})), [], input_names(Session),
                        TypeState).

%% Report §11.2: `:forget` removes a name the session declared, and `*`
%% every one of them. A type is forgotten with its constructors. A holder
%% the session then no longer reaches collected/1 lets go; an input that
%% declared keeps its code while the session runs, since a function or a
%% value made before may hold it (is_kept/2).
-spec forget(#session{}, binary()) -> {'Left', binary()} | {'Right', #session{}}.
forget(Session, <<"*">>) ->
    {'Right', keep_session(collected(Session#session{scope = #{}}))};
forget(#session{scope = Scope} = Session, Text) ->
    Values = maps:get(values, Scope, #{}),
    Types = maps:get(types, Scope, #{}),
    Constructors = maps:get(constructors, Scope, #{}),
    case segments(Session, Text) of
        {ok, [Name]} when is_map_key(Name, Values); is_map_key(Name, Types) ->
            Members = [{MemberOf, Member} || {MemberOf, Member} <- maps:keys(Values),
                                             MemberOf =:= Name],
            Gone = constructors(maps:get(Name, Types, none), Constructors, Session),
            %% remembered, since completion and `Shift-Tab` read the
            %% session from where the front end keeps it; what nothing
            %% reaches any longer is let go
            Scope1 = Scope#{values => maps:without([Name | Members], Values),
                            types => maps:remove(Name, Types),
                            constructors => maps:without(Gone, Constructors)},
            {'Right', keep_session(collected(Session#session{scope = Scope1}))};
        _ ->
            {'Left', <<"the session declares no ", Text/binary>>}
    end.

%% The constructors of the type being forgotten that still stand for it; one
%% whose name a later type took belongs to that type now.
constructors(none, _, _) ->
    [];
constructors(QualifiedName, ScopeConstructors, #session{interfaces = Interfaces}) ->
    [Name || #interface{types = Types} <- Interfaces,
             #{QualifiedName := #type_info{constructors = Constructors}} <- [Types],
             #constructor_info{qualified_name = ConstructorQualifiedName} <- Constructors,
             Name <- [lists:last(ConstructorQualifiedName)],
             maps:get(Name, ScopeConstructors, none) =:= ConstructorQualifiedName].

%% Report §11.2, §4.2: the exports of a module in scope, its types and then
%% its values, each with its type as §11.5 prints it; the prelude's, and
%% the prelude's functions under a namespace that is no module's, `Address`
%% (§9).
-spec browse(#session{}, binary()) -> {'Left', binary()} | {'Right', [binary()]}.
browse(Given, Text) ->
    %% report §11.2: the node's modules as they stand
    Session = synced(Given),
    case module_name(Session, Text) of
        {ok, ['Prelude']} -> {'Right', prelude_listing(Session)};
        {ok, Namespace} -> browse(Text, Namespace, Session);
        unmet -> {'Left', <<"no module ", (without_dot(Text))/binary, " is in scope",
                            (load_suffix(Session, Text))/binary>>};
        {error, Refusal} -> {'Left', Refusal}
    end.

%% Report §11.2, §9: the prelude's types and values, as `:browse` lists a
%% module's, since `Prelude` names its namespace (§4.2).
prelude_listing(Session) ->
    Env = prelude(),
    TypeState = ern_typecheck:type_state(Env),
    {Types, _} = ern_typecheck:prelude_names(Env),
    %% report §9.4: `Io.show` and `Io.debug` are the prelude's, typed by
    %% `io.ern`'s interface, since the table's text has no place for their
    %% requirement
    Shown = [{['Io', Name], Scheme} || Name <- [show, debug],
                                      {ok, Scheme} <- [ern_typecheck:declared_scheme(['Io'], Name,
                                                                                     Env)]],
    %% the environment holds the standard library's types too, each under
    %% its module's name; the prelude's own are unqualified
    Values = ern_typecheck:prelude_values(Env) ++ Shown,
    [unicode:characters_to_binary(["type ", ern_namespace:text(QualifiedName)])
     || [_] = QualifiedName <- lists:sort(Types)]
        ++ value_lines(Values, #{}, prelude_parameters(Session, Values), TypeState).

%% Report §11.2, §9: the prelude's functions under a namespace no module
%% of the session's or the standard library's has, `Address.call` and
%% `Address.callForever`, each with its type, as `:browse Prelude` lists
%% them; none for any other namespace.
prelude_namespace_listing(Namespace, Session) ->
    Env = prelude(),
    Values = [Value || {QualifiedName, _} = Value <- ern_typecheck:prelude_values(Env),
                       lists:droplast(QualifiedName) =:= Namespace],
    value_lines(Values, #{}, prelude_parameters(Session, Values), ern_typecheck:type_state(Env)).

%% Report §11.2, §11.4, §11.5: values as `:browse` lists them, each by its
%% qualified name: a function as its page's code block writes it, each
%% parameter's name beside its type and its requirement after its result,
%% where Parameters names its parameters, and any other value with its
%% type; then, after the functions, each type's members, Types being the
%% types the listed module declares, under a line naming the type as the
%% members' first parameter writes it, `Optional(a)`, each indented by
%% four spaces in the form a program writes at the type, in its page's
%% order (ern_docs:member_form/4, ern_page:member_order/1).
value_lines(Values, Types, Parameters, TypeState) ->
    Listed = [{QualifiedName, Scheme, listed_member(QualifiedName, Types)}
              || {QualifiedName, Scheme} <- lists:sort(Values)],
    Functions = [unicode:characters_to_binary(
                   value_line(QualifiedName, Scheme, Parameters(QualifiedName), TypeState))
                 || {QualifiedName, Scheme, none} <- Listed],
    Members = [{Type, ern_page:member_order(atom_to_list(Member)),
                member_form(Member, Parameters(QualifiedName), Scheme, TypeState)}
               || {QualifiedName, Scheme, {Type, Member}} <- Listed],
    Functions ++ lists:append([member_lines(lists:sort([{Order, Form}
                                                        || {Of, Order, Form} <- Members,
                                                           Of =:= Type]))
                               || Type <- lists:usort([Type || {Type, _, _} <- Members])]).

value_line(QualifiedName, #scheme{type = {tfn, _, _, _}} = Scheme, Params, TypeState)
  when is_list(Params) ->
    {Head, Marked, Rest} = ern_types:format_call(Scheme, Params, length(Params), TypeState),
    [ern_namespace:text(QualifiedName), Head, Marked, Rest];
value_line(QualifiedName, Scheme, _, TypeState) ->
    [ern_namespace:text(QualifiedName), " : ", ern_types:format_scheme(Scheme, TypeState)].

%% Report §11.4: a member's type and its form, as the shell prints types,
%% its parameters named as its declaration names them; a derived compare,
%% which no declaration names, has those Appendix H gives it.
member_form(Member, none, Scheme, TypeState) ->
    member_form(Member, [left, right], Scheme, TypeState);
member_form(Member, Params, Scheme, TypeState) ->
    ern_docs:member_form(Member, Params, Scheme, TypeState).

member_lines([{_, {Type, _}} | _] = Ordered) ->
    [unicode:characters_to_binary(Type)
     | [unicode:characters_to_binary(["    ", Form]) || {_, {_, Form}} <- Ordered]].

%% Report §4.5: the type a listed value is a member of, by its qualified
%% name, and the member: of a type of Types, the listed module's,
%% `Shape.Point.compare`, or of a prelude type, which its module declares,
%% `Int.+`; none for any other value.
listed_member(QualifiedName, Types) ->
    Name = lists:last(QualifiedName),
    Type = lists:droplast(QualifiedName),
    case lists:member(Name, [compare, negate | ?USEROPS])
         andalso (is_map_key(Type, Types) orelse ern_prelude:is_member(QualifiedName)) of
        true -> {Type, Name};
        false -> none
    end.

%% Report §11.2: the parameters' names of the prelude's listed values, as
%% the module of a type's operation documents them, each module's
%% documentation read once, and else as the prelude names them
%% (ern_prelude:parameters/1).
prelude_parameters(Session, Values) ->
    Modules = maps:from_list([{Namespace, module_parameters(Session, Namespace)}
                              || Namespace <- lists:usort([lists:droplast(QualifiedName)
                                                           || {[_, _ | _] = QualifiedName, _}
                                                                  <- Values])]),
    fun([_] = QualifiedName) ->
            ern_prelude:parameters(QualifiedName);
       (QualifiedName) ->
            Documented = maps:get(lists:droplast(QualifiedName), Modules),
            maps:get(atom_to_binary(lists:last(QualifiedName)), Documented,
                     ern_prelude:parameters(QualifiedName))
    end.

%% The parameters' names each function of the module of Namespace has in
%% its documentation, by the entry's name, `map` or `Point.compare`; none
%% where the session can name no compiled module there.
module_parameters(Session, Namespace) ->
    case beam_of(Session, Namespace) of
        none ->
            #{};
        Beam ->
            {ok, {docs_v1, _, _, _, _, _, Entries}} = ern_docs:read(Beam),
            maps:from_list([{atom_to_binary(Key), Params}
                            || {{function, Key, _}, _, _, _, #{params := Params}} <- Entries])
    end.

%% Report §11.5: each name and each type as the session writes it, the
%% names qualified and another module's types too.
browse(Text, Namespace, #session{interfaces = Interfaces, scope = Scope} = Session) ->
    InScope = Interfaces ++ ern_prelude:stdlib_interfaces(),
    case [Interface || #interface{namespace = Found} = Interface <- InScope, Found =:= Namespace] of
        [] ->
            case prelude_namespace_listing(Namespace, Session) of
                [] ->
                    {'Left', <<"no module ", (without_dot(Text))/binary, " is in scope",
                               (load_suffix(Session, Text))/binary>>};
                Lines ->
                    {'Right', Lines}
            end;
        Found ->
            #interface{types = InterfaceTypes, values = InterfaceValues} = Last = lists:last(Found),
            ScopeState = ern_typecheck:scope_state(checked_interfaces(Session) ++ [Last],
                                                   prelude()),
            TypeState = ern_types:set_scope([], maps:values(maps:get(types, Scope, #{})), [],
                                            input_names(Session), ScopeState),
            Types = [unicode:characters_to_binary([type_keyword(TypeInfo), "type ",
                                                   ern_namespace:text(QualifiedName)])
                     || {QualifiedName, TypeInfo} <- lists:sort(maps:to_list(InterfaceTypes))],
            %% report §11.2: each value's parameters as its module's
            %% documentation names them, read once
            Documented = module_parameters(Session, Namespace),
            Parameters = fun(QualifiedName) ->
                                 Written = lists:nthtail(length(Namespace), QualifiedName),
                                 maps:get(entry_name(Written), Documented, none)
                         end,
            {'Right', Types ++ value_lines(maps:to_list(InterfaceValues), InterfaceTypes,
                                           Parameters, TypeState)}
    end.

%% A type the session declares, as its declaration writes it.
type_line(Name, QualifiedName, Session) ->
    type_keyword(type_info(QualifiedName, Session)) ++ "type " ++ atom_to_list(Name).

%% Report §11.2: the word a type's declaration begins with before `type`,
%% as its declaration writes it; a built-in type, which the checker holds
%% as foreign under a name of one segment, is the prelude's and has none.
type_keyword(#type_info{abstract = true}) -> "abstract ";
type_keyword(#type_info{foreign = true, qualified_name = [_, _ | _]}) -> "foreign ";
type_keyword(_) -> "".

%% Report §2.3: a name as it is written, its segments between the dots,
%% or `none` for text that is no name: an empty segment, or one longer than
%% the host holds in a name, 255 characters. A trailing dot, which
%% completion leaves after a namespace, names the namespace. The host keeps
%% a name it has met for ever, so a name typed to a command is made one
%% only where it can name something: each segment met before, or the text,
%% or what stands before its last segments, a module there is a file of.
%% Otherwise it is `{unmet, Parts}`, its segments as they were typed.
segments(Session, Text) ->
    Parts = binary:split(without_dot(Text), <<".">>, [global]),
    case lists:all(fun(Part) -> Part =/= <<>> andalso byte_size(Part) =< 255 end, Parts) of
        true ->
            case lists:all(fun is_met/1, Parts) orelse names_a_module(Session, Parts) of
                true -> {ok, [binary_to_atom(Part) || Part <- Parts]};
                false -> {unmet, Parts}
            end;
        false ->
            none
    end.

is_met(Part) ->
    try binary_to_existing_atom(Part) of
        _ -> true
    catch
        error:badarg -> false
    end.

%% Whether the name, or what stands before its last segments, is a module
%% the host may not have met: one whose source the source root holds, or
%% one compiled, in the standard library's directory or on the load path.
names_a_module(Session, Parts) ->
    lists:any(fun(Length) ->
                  is_module_file(Session, [binary_to_list(Part)
                                           || Part <- lists:sublist(Parts, Length)])
              end, lists:seq(length(Parts), 1, -1)).

is_module_file(#session{source_root = SourceRoot} = Session, Segments) ->
    case lists:all(fun(Segment) -> ern_namespace:component(Segment) =/= error end, Segments) of
        true ->
            Relative = ern_namespace:path(Segments),
            is_source(Session, filename:join(SourceRoot, Relative ++ ".ern"))
                orelse lists:any(fun(Root) ->
                                     filelib:is_regular(filename:join(Root, Relative ++ ".erc"))
                                 end, [ern_prelude:stdlib_directory() | load_path(Session)]);
        false ->
            false
    end.

%% Report §11.2: every refusal the front end answers, a diagnostic among
%% them, ends with no line feed, and the shell ends each with one as it
%% says it.
without_line_feed({'Left', Text}) -> {'Left', string:trim(Text, trailing, "\n")};
without_line_feed(Answer) -> Answer.

without_dot(<<>>) ->
    <<>>;
without_dot(Text) ->
    case binary:last(Text) of
        $. -> binary:part(Text, 0, byte_size(Text) - 1);
        _ -> Text
    end.

%% Report §4.2: a module is named by its namespace, each segment of which
%% is words each beginning with a capital letter, `Http.Parser` for
%% `http/parser.ern` and `OrderedSet` for `ordered_set.ern`; a name that
%% is not one is refused rather than looked for.
module_name(Session, Text) ->
    case segments(Session, Text) of
        {ok, Namespace} ->
            case lists:all(fun(Segment) -> is_segment(atom_to_list(Segment)) end, Namespace) of
                true -> {ok, Namespace};
                false -> not_module(Text)
            end;
        %% a module's name in form, of no module there is a file of
        {unmet, Parts} ->
            case lists:all(fun(Part) -> is_segment(binary_to_list(Part)) end, Parts) of
                true -> unmet;
                false -> not_module(Text)
            end;
        none ->
            not_module(Text)
    end.

is_segment(Segment) ->
    ern_namespace:component(Segment) =/= error.

not_module(Text) ->
    {error, <<Text/binary, " is not a module name: each segment of one is words beginning with"
              " a capital letter, as in Http.Parser or OrderedSet">>}.

%% Report §11.2, §11.4: the documentation of one declaration, as
%% `ern doc` renders it, read from the module that declares it: an input
%% of this session, or a module on the load path.
-spec doc(#session{}, binary()) -> {'Left', binary()} | {'Right', binary()}.
doc(Given, Text) ->
    Session = synced(Given),
    case page(Session, Text) of
        {ok, Page, _} -> {'Right', unicode:characters_to_binary(Page)};
        {refused, Refusal} -> {'Left', unicode:characters_to_binary(Refusal)};
        none ->
            {'Left', <<"no documentation for ", Text/binary, (load_suffix(Session, Text))/binary>>}
    end.

%% Report §11.2: a name of a module the session has not loaded, but the
%% source root or the load path holds, is answered with the `:load` that
%% puts it in scope: the module the name is, or the longest that begins it;
%% or, where the session's last `:load` of that module was refused, with
%% the refusal (refusal_kept/2).
load_suffix(Session, Text) ->
    Parts = [binary_to_list(Part) || Part <- binary:split(without_dot(Text), <<".">>, [global])],
    case load_help(Session, Parts) of
        {ok, Help} -> unicode:characters_to_binary(["; ", Help]);
        none -> <<>>
    end.

load_help(Session, Segments) ->
    Modules = [lists:sublist(Segments, Length) || Length <- lists:seq(length(Segments), 1, -1)],
    case lists:search(fun(Module) -> is_unloaded_module(Session, Module) end, Modules) of
        {value, Module} ->
            Name = lists:join(".", Module),
            case kept({refused, unicode:characters_to_binary(Name)}, none) of
                none -> {ok, [":load ", Name, " puts it in scope"]};
                Refusal -> {ok, [":load ", Name, " was refused: ", Refusal]}
            end;
        false ->
            none
    end.

%% Whether a module of these segments is not loaded and could be: its
%% source under the source root, or its compiled form on the load path,
%% the first there, a compiled form of the module whose code the host will
%% load (§11), which a load makes a unit of its own where the host holds
%% another unit of its name (compiled_unit/3).
is_unloaded_module(#session{source_root = SourceRoot, interfaces = Interfaces} = Session,
                   Segments) ->
    Name = lists:flatten(lists:join(".", Segments)),
    Loaded = [ern_namespace:text(Namespace)
              || #interface{namespace = Namespace} <- Interfaces
                     ++ ern_prelude:stdlib_interfaces()],
    lists:all(fun(Segment) -> ern_namespace:component(Segment) =/= error end, Segments)
        andalso not lists:member(Name, Loaded)
        andalso begin
                    Relative = ern_namespace:path(Segments),
                    is_source(Session, filename:join(SourceRoot, Relative ++ ".ern"))
                        orelse is_form_loadable(Session, Segments)
                end.

%% Whether the load path's compiled form of the module the segments name
%% is one `:load` takes, holding that module and loadable (compiled_of/2).
%% The name is made a namespace only where a compiled form is at its path,
%% as segments/2 makes no atom of a name no file holds.
is_form_loadable(Session, Segments) ->
    Relative = ern_namespace:path(Segments) ++ ".erc",
    lists:any(fun(Dir) -> filelib:is_regular(filename:join(Dir, Relative)) end, load_path(Session))
        andalso case compiled_of(Session, ern_namespace:namespace(Segments)) of
                    {ok, _, _, _} -> true;
                    _ -> false
                end.

%% The documentation of a name as it is written, with its segments; the
%% refusal of a name the checker refuses as written; none for text that is
%% no name.
page(Session, Text) ->
    case segments(Session, Text) of
        {ok, Segments} ->
            case doc_of(Session, Segments) of
                {ok, Page} -> {ok, Page, Segments};
                Other -> Other
            end;
        _ ->
            none
    end.

%% Report §11.2: the page for a name, as the session stands, for
%% `Shift-Tab`, the one `:doc` shows, and the version the name appeared in,
%% which the brief shows. The reader asks while an input runs, so it reads
%% the session the front end keeps rather than asking the session.
-spec documentation(binary()) -> 'None' | {'Some', {binary(), 'None' | {'Some', binary()}}}.
documentation(Text) ->
    Session = kept_session(),
    case page(Session, Text) of
        {ok, Page, Segments} ->
            {'Some', {unicode:characters_to_binary(Page), appeared(Session, Segments)}};
        _ ->
            'None'
    end.

%% Appendix E.0 shape rule 6, report §11.2: the version a declaration
%% appeared in, its own `since` or, without one, its module's. Whether it
%% has one is its documentation entry's to say, not its text's.
appeared(Session, Segments) ->
    case declaring(Session, Segments) of
        {Declaring, Name} ->
            case {ern_page:declared_since(Declaring, Name), ern_page:since(Declaring)} of
                {undefined, undefined} -> 'None';
                {undefined, Since} -> {'Some', unicode:characters_to_binary(Since)};
                {Since, _} -> {'Some', unicode:characters_to_binary(Since)}
            end;
        none ->
            'None'
    end.

%% The compiled module, or the prelude, whose documentation entry a
%% documented name is, and the entry's name: a module's (declared_entry/2),
%% or else the prelude's name.
declaring(Session, Segments) ->
    case declared_entry(Session, Segments) of
        none -> prelude_entry(Segments);
        Found -> Found
    end.

%% Report §4.2: the documentation entry a qualified name is in a module the
%% session can name, the compiled module and the entry's name, or none. A
%% member of a module's type comes first, `Point.compare` in the module
%% `Shape` for `Shape.Point.compare`, as a qualified name is the member
%% where the type has one; then the module's value, `map` in `List` for
%% `List.map`. `:doc`, `Shift-Tab`'s brief and a signature's parameters
%% each find a module's declaration here.
declared_entry(Session, Segments) when length(Segments) >= 2 ->
    Namespace = lists:droplast(Segments),
    %% the namespace of the module that declares the type, `Shape`
    TypeNamespace = lists:droplast(Namespace),
    Member = [{TypeNamespace, lists:nthtail(length(Segments) - 2, Segments)}
              || TypeNamespace =/= []],
    first_entry(Session, Member ++ [{Namespace, [lists:last(Segments)]}]);
declared_entry(_, _) ->
    none.

%% The first of the places, each a module's namespace and the name an entry
%% of it would be written, whose module has the entry.
first_entry(_, []) ->
    none;
first_entry(Session, [{Namespace, Written} | Rest]) ->
    Name = entry_name(Written),
    case beam_of(Session, Namespace) of
        none -> first_entry(Session, Rest);
        Beam ->
            case ern_page:declaration(Beam, Name, entry) of
                {ok, _} -> {Beam, Name};
                none -> first_entry(Session, Rest)
            end
    end.

prelude_entry(Segments) ->
    case prelude_doc(Segments) of
        {ok, _} -> {prelude, entry_name(Segments)};
        none -> none
    end.

%% Report §11.2, §3.5: what a `.` after a value completes to. The text
%% before the last `.` is checked as an input in a module of its own that
%% does not enter the session, as `Shift-Tab`'s callee is, so a chain of
%% selections is the checker's, and a name the unfinished input binds is
%% not in scope; the fields its type selects are then the checker's too,
%% each listed with its type. A namespace checks as no value and has none.
-spec fields(binary()) -> [{'Name', binary(), 'Value', binary()}].
fields(Before) ->
    case string:split(Before, ".", trailing) of
        [Head, _] when Head =/= <<>> ->
            maybe
                %% a line being typed makes no name, as slot/1 says
                ok = stdlib_met(),
                {ok, Binds, Expr} ?= input(Head, [no_new_names]),
                {'Right', {_, #checked{type = Type, env = Env}}} ?=
                    check_module(reader_session(), ['$Fields'], {typed, <<"fields">>}, Head,
                                 input_entry(Binds, Expr), Binds),
                TypeState = ern_typecheck:type_state(Env),
                [name('Value', [Head, ".", atom_to_list(Field)],
                      [Head, ".", atom_to_list(Field), " : ",
                       ern_types:format(FieldType, TypeState)])
                 || {Field, FieldType} <- ern_typecheck:fields(Type, Env)]
            else
                _ -> []
            end;
        _ ->
            []
    end.

%% Report §11.2: inside a call, `Shift-Tab` shows the callee's signature
%% with its parameters as declared and the one at the cursor marked, which
%% the shell does, in three parts: before, the parameter, after. The
%% parser says which call the unfinished input stops inside; the callee is
%% checked as an input of one name, without entering the session, and its
%% declared type is printed with the parameter names its documentation
%% carries.
-spec signature(binary()) -> 'None' | {'Some', {binary(), binary(), binary()}}.
signature(Before) ->
    case enclosing_call(Before) of
        #enclosing{namespace = Namespace, name = Name, argument = Argument} ->
            %% a constructor's name begins with a capital (report §2.3)
            [First | _] = atom_to_list(Name),
            case not is_integer(Argument) orelse (First >= $A andalso First =< $Z) of
                true -> constructor_signature(Namespace, Name, Argument);
                false -> call_signature(Namespace, Name, Argument)
            end;
        none ->
            'None'
    end.

call_signature(Namespace, Name, Argument) ->
    Session = reader_session(),
    Text = unicode:characters_to_binary(ern_namespace:text(Namespace ++ [Name])),
    %% a callee that does not check, a name not in scope, has none, and
    %% neither has one whose declaration the checker does not hold or whose
    %% type is not a function's
    case scheme_of(Session, Text) of
        {ok, Scheme, Env} ->
            Params = parameters(Session, Namespace, Name),
            {Head, Marked, Rest} = ern_types:format_call(Scheme, Params, Argument,
                                                         ern_typecheck:type_state(Env)),
            {'Some', {unicode:characters_to_binary([Text, Head]),
                      unicode:characters_to_binary(Marked), unicode:characters_to_binary(Rest)}};
        none ->
            'None'
    end.

%% The declared type of a function's name, for its signature.
scheme_of(Session, Text) ->
    case declared_scheme(Session, Text) of
        {ok, #scheme{type = {tfn, _, _, _}}, _} = Found -> Found;
        _ -> none
    end.

%% Report §11.2, §4.9: the type of an input that is one name, as its
%% declaration writes it, which `:type` shows; any other input is checked,
%% a member's name among them, which stands in no expression and is
%% refused as one (§4.5).
-spec declared_type(#session{}, binary()) -> {'Some', binary()} | 'None'.
declared_type(Session, Input) ->
    case one_name_declared(Session, Input) of
        {ok, Namespace, Name, Scheme, Env} ->
            case ern_typecheck:is_member_name(Namespace, Name, Env) of
                true ->
                    'None';
                false ->
                    Text = ern_types:format_scheme(Scheme, ern_typecheck:type_state(Env)),
                    {'Some', unicode:characters_to_binary(Text)}
            end;
        none ->
            'None'
    end.

%% The declared scheme of an input that is one name, read in the session's
%% scope in a module of its own that does not enter the session, and not
%% taken as a value, which a declaration with a requirement is not without
%% a type for its variable (report §4.9).
declared_scheme(Session, Text) ->
    case one_name_declared(Session, Text) of
        {ok, _, _, Scheme, Env} -> {ok, Scheme, Env};
        none -> none
    end.

%% The name of an input that is one name, its declared scheme, and the
%% environment it is read in, or none.
one_name_declared(#session{scope = Scope} = Session, Text) ->
    maybe
        {ok, it, #e_var{namespace = Namespace, name = Name}} ?= input(Text),
        %% report §11.2: a type a later input shadows prints under the input
        %% that declared it, as the input's own check prints it; the
        %% interfaces are those the session's environment holds already
        {_, Seeded} = session_env(Session),
        {ok, _, _, Env} ?= ern_typecheck:check(['$Signature'], [], [],
                                               Scope#{input_names => input_names(Session)},
                                               Seeded),
        {ok, Scheme} ?= ern_typecheck:declared_scheme(Namespace, Name, Env),
        {ok, Namespace, Name, Scheme, Env}
    else
        _ -> none
    end.

%% Report §11.2: a constructor's fields, as a signature, the one whose
%% value is at the cursor marked, and none where a field's name stands.
constructor_signature(Namespace, Name, Argument) ->
    Session = kept_session(),
    case named_constructor(Session, Namespace, Name) of
        {ok, #constructor_info{fields = Fields,
                               scheme = #scheme{type = {tfn, Params, _, _}} = Scheme}} ->
            %% a constructor is declared, so its signature is a head's
            Names = case Fields of
                        {named, Named} -> Named;
                        _ -> lists:duplicate(length(Params), '_')
                    end,
            MarkedIndex = case Argument of
                              {field, Field} -> field_index(Field, Names, length(Params));
                              none -> length(Params);
                              Index -> Index
                          end,
            {Head, Marked, Rest} = ern_types:format_call(Scheme, Names, MarkedIndex,
                                                         session_type_state(Session)),
            Text = ern_namespace:text(Namespace ++ [Name]),
            {'Some', {unicode:characters_to_binary([Text, Head]),
                      unicode:characters_to_binary(Marked), unicode:characters_to_binary(Rest)}};
        _ ->
            'None'
    end.

field_index(Field, Names, Otherwise) ->
    Indexed = lists:zip(lists:seq(0, length(Names) - 1), Names),
    case lists:search(fun({_, Name}) -> Name =:= Field end, Indexed) of
        {value, {Index, _}} -> Index;
        false -> Otherwise
    end.

%% A constructor by the name written: the session's, the prelude's, or a
%% module's.
named_constructor(#session{scope = Scope, interfaces = Interfaces}, [], Name) ->
    case maps:get(Name, maps:get(constructors, Scope, #{}), none) of
        none -> ern_typecheck:prelude_constructor(Name, prelude());
        QualifiedName -> constructor_info(QualifiedName, Interfaces)
    end;
named_constructor(#session{interfaces = Interfaces}, Namespace, Name) ->
    constructor_info(Namespace ++ [Name], Interfaces ++ ern_prelude:stdlib_interfaces()).

constructor_info(QualifiedName, Interfaces) ->
    case [ConstructorInfo || #interface{types = Types} <- Interfaces,
                             {_, #type_info{constructors = Constructors}} <- maps:to_list(Types),
                             #constructor_info{qualified_name = Found} = ConstructorInfo
                                 <- Constructors,
                             Found =:= QualifiedName] of
        [ConstructorInfo | _] -> {ok, ConstructorInfo};
        [] -> none
    end.

%% Report §11.2: the call is found wherever the input stands, so the text
%% is read as an expression, as a block's statement, a `let`, and as
%% declarations, the first that stops inside a call answering.
enclosing_call(Before) ->
    %% read and not run, so no name is made of it (slot/1)
    ok = stdlib_met(),
    Parsers = [fun ern_parser:parse_expr/2, fun ern_parser:parse_statement/2,
               fun ern_parser:parse_string/2],
    case [Enclosing || Parse <- Parsers,
                       {error, #diagnostic{incomplete = true, within = Enclosing}}
                           <- [Parse(Before, [no_new_names])],
                       Enclosing =/= undefined] of
        [Enclosing | _] -> Enclosing;
        [] -> none
    end.

%% The parameter names a function's documentation entry carries: a name
%% the session declares, in scope before a module's and the prelude's
%% (report §11.2), from the input that declares it, under the name as the
%% session writes it, a member as `Point.compare`; any other from the
%% module that declares it (declared_entry/2), or else the prelude's. None
%% where no declaration carries them, a function value's and what a `let`
%% at the prompt binds.
parameters(Session, Namespace, Name) ->
    case session_beam(Session, Namespace, Name) of
        not_session ->
            case declared_entry(Session, Namespace ++ [Name]) of
                {Beam, EntryName} ->
                    entry_parameters(Beam, EntryName);
                none ->
                    %% report §9.4, §9.5: a prelude function's parameters,
                    %% named for their roles
                    ern_prelude:parameters(Namespace ++ [Name])
            end;
        none ->
            none;
        Beam ->
            entry_parameters(Beam, entry_name(Namespace ++ [Name]))
    end.

entry_parameters(Beam, EntryName) ->
    {ok, {docs_v1, _, _, _, _, _, Entries}} = ern_docs:read(Beam),
    case [Params || {{function, Key, _}, _, _, _, #{params := Params}} <- Entries,
                    atom_to_binary(Key) =:= EntryName] of
        [Params | _] -> Params;
        [] -> none
    end.

%% The compiled input that declares a name the session declares, none for
%% one no input holds, what a `let` binds, and not_session for a name the
%% session does not declare.
session_beam(#session{scope = Scope, beams = Beams}, Namespace, Name) ->
    Key = case Namespace of
              [] -> Name;
              [MemberOf] -> {MemberOf, Name};
              _ -> none
          end,
    case maps:get(Key, maps:get(values, Scope, #{}), none) of
        none -> not_session;
        QualifiedName -> declaring_beam(QualifiedName, Namespace ++ [Name], Beams)
    end.

%% The session's own names first, then a module's, then the prelude's,
%% which is where a name no module declares is documented (report §9);
%% then a constructor, whose documentation is its type's, and a module,
%% whose documentation is the head of its page (report §11.2).
%% A name that is a type and a module too, `List`, shows the type's section
%% and then the module's head; a namespace that is neither lists what it
%% holds.
doc_of(_Session, ['Prelude']) ->
    %% report §11.2, §4.2: `Prelude` names the prelude, whose page it is
    {ok, ern_page:prelude_page()};
doc_of(_Session, ['Prelude', _, _ | _] = Segments) ->
    %% report §11.2, §4.2: `Prelude.` takes one prelude name and no
    %% namespace, refused in the checker's words
    {Message, Help} = ern_typecheck:prelude_one_text(lists:droplast(Segments),
                                                     lists:last(Segments)),
    {refused, Message ++ "; " ++ Help};
doc_of(Session, ['Prelude' | Segments]) ->
    %% the prelude's name, past one the session declares; an operation of a
    %% built-in type is documented by its type's module (§9.6)
    first([fun() -> prelude_doc(Segments) end, fun() -> module_doc(Session, Segments) end]);
doc_of(Session, Segments) ->
    case first([fun() -> session_doc(Session, Segments) end,
                fun() -> module_doc(Session, Segments) end,
                fun() -> prelude_doc(Segments) end,
                fun() -> constructor_doc(Session, Segments) end]) of
        {ok, Page} ->
            case module_head(Session, Segments) of
                {ok, Head} -> {ok, [Page, "\n", Head]};
                none -> {ok, Page}
            end;
        none ->
            first([fun() -> module_head(Session, Segments) end,
                   fun() -> namespace_doc(Session, Segments) end])
    end.

%% Report §11.2: a namespace that is no module and no documented type,
%% `Net` where only `net/http.ern` is, is documented by what it holds, each
%% name with its type.
namespace_doc(_, []) ->
    none;
namespace_doc(Session, Segments) ->
    Prefix = unicode:characters_to_binary(ern_namespace:text(Segments) ++ "."),
    case [Shown || {'Name', Text, _, Shown} <- names(Session),
                   binary:match(Text, Prefix) =:= {0, byte_size(Prefix)}] of
        [] -> none;
        Listed -> {ok, ["# namespace ", ern_namespace:text(Segments), "\n\n",
                      [["- `", Shown, "`\n"] || Shown <- Listed]]}
    end.

first([]) ->
    none;
first([Find | Rest]) ->
    case Find() of
        {ok, Page} -> {ok, Page};
        none -> first(Rest)
    end.

%% Report §11.4: a constructor is documented in its type's section, so its
%% documentation is its type's: a session constructor's the session's type,
%% a module's its module's type, and an unqualified one the prelude's.
constructor_doc(#session{scope = Scope, beams = Beams} = Session, [Name]) ->
    case maps:get(Name, maps:get(constructors, Scope, #{}), none) of
        none ->
            case ern_typecheck:prelude_constructor(Name, prelude()) of
                {ok, #constructor_info{type_qualified_name = TypeQualifiedName}} ->
                    prelude_doc(TypeQualifiedName);
                none -> none
            end;
        QualifiedName ->
            case constructor_type(QualifiedName, Session) of
                {ok, TypeQualifiedName} ->
                    TypeName = lists:last(TypeQualifiedName),
                    Beam = declaring_beam(TypeQualifiedName, [TypeName], Beams),
                    {ok, ern_page:session_declaration(Beam, entry_name([TypeName]), entry)};
                none ->
                    none
            end
    end;
constructor_doc(Session, Segments) ->
    case constructor_type(Segments, Session) of
        {ok, TypeQualifiedName} -> module_doc(Session, TypeQualifiedName);
        none -> none
    end.

%% The type a constructor belongs to, from the interfaces in scope.
constructor_type(QualifiedName, #session{interfaces = Interfaces}) ->
    Namespace = lists:droplast(QualifiedName),
    Constructor = lists:last(QualifiedName),
    InScope = Interfaces ++ ern_prelude:stdlib_interfaces(),
    case [TypeQualifiedName
          || #interface{types = Types} <- InScope,
             {TypeQualifiedName, #type_info{constructors = Constructors, abstract = false}}
                 <- maps:to_list(Types),
             lists:droplast(TypeQualifiedName) =:= Namespace,
             #constructor_info{name = Name} <- Constructors, Name =:= Constructor] of
        [TypeQualifiedName | _] -> {ok, TypeQualifiedName};
        [] -> none
    end.

%% Report §11.2: a module's documentation is the head of its page.
module_head(Session, Segments) ->
    case beam_of(Session, Segments) of
        none -> none;
        Beam -> {ok, ern_page:module_head(Beam)}
    end.

prelude_doc([]) ->
    none;
prelude_doc(Segments) ->
    ern_page:prelude_declaration(entry_name(Segments)).

%% A name the session declared: the beam of the input that declared it, and
%% the entry under its unqualified name, a member under `Type.name`, shown
%% under the name as the session writes it and with the type the shell
%% prints (report §11.2).
session_doc(#session{scope = Scope, beams = Beams} = Session, Segments) ->
    Key = case Segments of
              [Name] -> Name;
              [MemberOf, Name] -> {MemberOf, Name};
              _ -> none
          end,
    Values = maps:get(values, Scope, #{}),
    Types = maps:get(types, Scope, #{}),
    case {maps:get(Key, Values, none), maps:get(Key, Types, none)} of
        {none, none} ->
            none;
        {none, QualifiedName} ->
            TypeName = lists:last(QualifiedName),
            Beam = declaring_beam(QualifiedName, [TypeName], Beams),
            {ok, ern_page:session_declaration(Beam, entry_name([TypeName]), entry)};
        {QualifiedName, _} ->
            Line = session_line(Key, QualifiedName, Session),
            Beam = declaring_beam(QualifiedName, Segments, Beams),
            {ok, ern_page:session_declaration(Beam, entry_name(Segments), [Line])}
    end.

%% Report §11.2, §11.4: a function the session declares is shown as a
%% module's page shows it, its declaration as a caller names it, in the
%% session's names; a `let`'s name has its type.
session_line(Key, QualifiedName, Session) ->
    TypeState = session_type_state(Session),
    {Namespace, Name} = case Key of
                            {MemberOf, Member} -> {[MemberOf], Member};
                            _ -> {[], Key}
                        end,
    IsMember = Namespace =/= [] andalso lists:member(Name, [compare, negate | ?USEROPS]),
    case {scheme(QualifiedName, Session), parameters(Session, Namespace, Name)} of
        %% report §11.4: a member the session declares, `fn Coin.+`, in its
        %% form
        {{ok, Scheme}, Params} when IsMember ->
            {_, Form} = member_form(Name, Params, Scheme, TypeState),
            Form;
        {{ok, Scheme}, Params} when is_list(Params) ->
            {Head, Marked, Rest} = ern_types:format_call(Scheme, Params, length(Params),
                                                         TypeState),
            unicode:characters_to_list([name_text(Key), Head, Marked, Rest]);
        _ ->
            scheme_line(name_text(Key), QualifiedName, Session, TypeState)
    end.

%% The input that declared the name: the qualified name without the
%% segments the name itself is written with.
declaring_beam(QualifiedName, Segments, Beams) ->
    Namespace = lists:sublist(QualifiedName, length(QualifiedName) - length(Segments)),
    maps:get(Namespace, Beams, none).

%% The name a documentation entry is under, as it is written: `map`, a
%% member as `Point.compare`, and a prelude name as `Address.call`.
entry_name(Segments) ->
    unicode:characters_to_binary(ern_namespace:text(Segments)).

%% A module's declaration on the load path, a member of its type,
%% `Shape.Point.compare`, or its value, `List.map`, found as
%% declared_entry/2 finds it. Report §11.2: a value's declaration shows the
%% type the shell prints, `Fs.Entry` and not the page's `Entry`, and a
%% type's its own.
module_doc(Session, Segments) ->
    case declared_entry(Session, Segments) of
        {Beam, EntryName} ->
            ern_page:declaration(Beam, EntryName, module_signature(Session, Segments));
        none ->
            none
    end.

%% The signature a module's value is shown with, its parameters as its
%% documentation names them and its type as `:type` prints it, a member's
%% in its form (report §11.4); a type's entry keeps its own.
module_signature(Session, QualifiedName) ->
    Text = unicode:characters_to_binary(ern_namespace:text(QualifiedName)),
    case declared_scheme(Session, Text) of
        {ok, Scheme, Env} ->
            TypeState = ern_typecheck:type_state(Env),
            Namespace = lists:droplast(QualifiedName),
            Name = lists:last(QualifiedName),
            Params = parameters(Session, Namespace, Name),
            Line = case ern_typecheck:is_member_name(Namespace, Name, Env) of
                       true ->
                           {_, Form} = member_form(Name, Params, Scheme, TypeState),
                           Form;
                       false when is_list(Params) ->
                           {Head, Marked, Rest} =
                               ern_types:format_call(Scheme, Params, length(Params), TypeState),
                           [Text, Head, Marked, Rest];
                       _ ->
                           [Text, " : ", ern_types:format_scheme(Scheme, TypeState)]
                   end,
            [unicode:characters_to_list(Line)];
        none ->
            entry
    end.

%% The compiled module behind a namespace the session can name, as bytes:
%% the one `:load` or `:reload` compiled, which is loaded from memory and
%% has no file; else, for one the runner loaded, its interface and its
%% documentation as the runner loaded them, which the code table keeps
%% (ern_code:documented/1), never its file, which a build may have written
%% again or taken away; or the standard library's `.erc`. `beam_lib` takes
%% either as a binary. A module the session cannot name, the shell's own
%% and its libraries among them, has none (report §11.2).
beam_of(#session{beams = Beams, interfaces = Interfaces}, Namespace) ->
    case Beams of
        #{Namespace := Beam} -> Beam;
        _ ->
            IsLoaded = lists:any(fun(#interface{namespace = Known}) -> Known =:= Namespace end,
                                 Interfaces),
            file_beam(Namespace, IsLoaded)
    end.

%% A module's name is made an atom only where it is one already, so that a
%% name `:doc` or `Shift-Tab` is asked of, `List.filter` taken for a module,
%% makes none (report §11.2). One the session has not loaded is the
%% standard library's where the library's directory holds its file, as
%% ern_prelude:stdlib_interfaces/0 finds the library.
file_beam(Namespace, true) ->
    Text = ern_namespace:erlang_module_text(Namespace),
    Unit = try list_to_existing_atom(Text) catch error:badarg -> none end,
    case Unit =/= none andalso ern_code:documented(Unit) of
        {ok, Documented} -> Documented;
        _ -> read_beam(try code:which(Unit) catch error:badarg -> non_existing end)
    end;
file_beam(Namespace, false) ->
    Path = ern_namespace:path([ern_namespace:segment_text(Segment) || Segment <- Namespace]),
    read_beam(filename:join(ern_prelude:stdlib_directory(), Path ++ ".erc")).

read_beam(File) ->
    case is_list(File) andalso file:read_file(File) of
        {ok, Beam} -> Beam;
        _ -> none
    end.

%% Report §11.2: a qualified name that names nothing in scope, of a module
%% the session could load, has the `:load` that puts it there as its help.
load_hinted(Session, #diagnostic{unknown_namespace = [_ | _] = Namespace,
                                 help = undefined} = Diagnostic) ->
    case load_help(Session, [atom_to_list(Segment) || Segment <- Namespace]) of
        {ok, Help} -> Diagnostic#diagnostic{help = unicode:characters_to_list(Help)};
        none -> Diagnostic
    end;
load_hinted(_Session, Diagnostic) ->
    Diagnostic.

%% Report §11.2: a typed input is the file `input`; an input from a startup
%% file is named by the file, its positions moved to the line it stands on
%% there and, on its first line, to the column it begins in, and its lines
%% quoted from the file, which the shell's own node holds and its local
%% half reads, as it read the inputs (§11.2 *The attached shell*); the
%% input alone where the file can no longer be read.
diagnostic(_Session, {typed, Name}, Input, Diagnostics) ->
    unicode:characters_to_binary([ern_diagnostic:format(binary_to_list(Name), Input, Diagnostic)
                                  || Diagnostic <- Diagnostics]);
diagnostic(Session, #startup_input{file = File, line = Line, column = Column}, Input,
           Diagnostics) ->
    SourceText = case source_read(Session, binary_to_list(File)) of
                     {ok, Read} -> Read;
                     {error, _} -> Input
                 end,
    unicode:characters_to_binary(
      [ern_diagnostic:format(ern_build:shown(binary_to_list(File)), SourceText,
                             moved(Diagnostic, Line - 1, Column - 1))
       || Diagnostic <- Diagnostics]).

%% A diagnostic's positions, a number of lines further down, and on the
%% input's first line a number of columns further right.
moved(#diagnostic{span = Span, labels = Labels} = Diagnostic, Lines, Columns) ->
    Moved = fun(Spanned) -> moved_span(ern_diagnostic:span(Spanned), Lines, Columns) end,
    Diagnostic#diagnostic{span = Moved(Span),
                          labels = [{Moved(LabelSpan), Text} || {LabelSpan, Text} <- Labels]}.

moved_span({Line, Column, {EndLine, EndColumn}}, Lines, Columns) ->
    {Line + Lines, moved_column(Line, Column, Columns),
     {EndLine + Lines, moved_column(EndLine, EndColumn, Columns)}}.

moved_column(1, Column, Columns) -> Column + Columns;
moved_column(_, Column, _) -> Column.

%% Report §11.2: `:load` takes a module by its namespace. Its source under
%% the source root is compiled as `ern build` would compile it and nothing is
%% written; a module with no source there is loaded from its compiled
%% form, on the load path. Afterwards it is in scope by its qualified
%% name, as every loaded module is (§4.2). A module the session has loaded
%% is refused: `:reload` alone brings another version of it.
-spec load(#session{}, binary()) -> {'Left', binary()} | {'Right', {#session{}, binary()}}.
load(Session, Text) ->
    without_line_feed(nodes_load(Session, fun(Synced) -> load_named(Synced, Text) end)).

%% Report §11.2: a load or a reload is the node's: made one at a time on
%% the node, over the node's modules as they stand, its sources the
%% operator's, read through the session's local half, and what it loaded
%% the node's modules from then on, which every session's next input is
%% checked against.
nodes_load(Session, Load) ->
    node_load(Session,
              fun(Synced) ->
                  case ern_build:read_through(source_access(Synced), fun() -> Load(Synced) end) of
                      {'Right', {Loaded, Answer}} ->
                          Published = published(Loaded),
                          reload_said(Synced, Published),
                          {'Right', {Published, Answer}};
                      Refused ->
                          Refused
                  end
              end).

%% Report §11.2 *The attached shell*: a reload by any session is said at
%% every other session's prompt, as a fault is: each module whose version
%% the load moved, by its name, with this session's number, sent to every
%% other session of the node by the address it started with (start/6),
%% once the node's modules are published, so that what it moved is there
%% to read (reloaded_by/3).
reload_said(#session{versions = Before}, #session{number = Number, versions = After}) ->
    case lists:sort([unicode:characters_to_binary(ern_namespace:text(Namespace))
                     || Namespace := Version <- After, not is_session_namespace(Namespace),
                        maps:get(Namespace, Before, 1) =/= Version]) of
        [] ->
            ok;
        Reloaded ->
            Root = session_root(),
            _ = [ern_rt:send(Shell, {'Reloaded', Number, Reloaded})
                 || Other := Shell <- node_kept(sessions, #{}), Other =/= Root],
            ok
    end.

load_named(#session{source_hashes = SourceHashes} = Session, Text) ->
    case module_name(Session, Text) of
        unmet ->
            {'Left', <<"no module ", (without_dot(Text))/binary,
                       " under the source root or on the load path\n">>};
        {ok, Namespace} ->
            Name = unicode:characters_to_binary(ern_namespace:text(Namespace)),
            Standard = [Found || #interface{namespace = Found} <- ern_prelude:stdlib_interfaces()],
            case lists:member(Namespace, Standard) of
                %% report §4.2, §11.2: a standard library namespace is taken,
                %% and the module, in scope since the session began, is one
                %% the session has loaded, which is refused
                true ->
                    {'Left', <<Name/binary, " is the standard library's, in scope from the"
                               " start\n">>};
                false when is_map_key(Namespace, SourceHashes) ->
                    {'Left', <<Name/binary, " is loaded already; :reload compiles it again"
                               " when its source has changed\n">>};
                false ->
                    refusal_kept(Name, load(Session, Name, Namespace))
            end;
        {error, Refusal} ->
            {'Left', <<Refusal/binary, "\n">>}
    end.

%% Report §11.2: a module whose `:load` was refused is named so by the
%% help a name of it is answered with (load_help/2), with the refusal's
%% first line, until a `:load` of it is not refused. A row of the front
%% end's table for each such module, by its name, which the help reads
%% from what was typed and so makes no atom; one never loaded again keeps
%% its row while the session runs, a row for each module there is to load.
refusal_kept(Name, {'Left', Refusal} = Refused) ->
    [First | _] = binary:split(Refusal, <<"\n">>),
    keep({refused, Name}, First),
    Refused;
refusal_kept(Name, Loaded) ->
    forgotten({refused, Name}),
    Loaded.

%% A refusal ends in a line feed, as a diagnostic the compiler gives does,
%% since the shell prints both alike. What is loaded is kept, since
%% completion and `Shift-Tab` read the session from where it is kept.
load(#session{source_root = SourceRoot} = Session, Name, Namespace) ->
    case source_of(Session, Namespace) of
        {ok, File} ->
            #build_module{namespace = Declared} =
                ern_build:module_of(ern_build:absolute(File), SourceRoot),
            case Declared of
                Namespace ->
                    %% report §11.2: what it uses that the session has not
                    %% loaded and whose source the root holds is compiled too
                    Sources = with_sources(Session, [{Namespace, File}], []),
                    case compile_in_order(Session, Sources) of
                        {ok, Needed, CompiledModules} ->
                            Lines = [loaded_line(Session, Compiled)
                                     || {Loaded, _} <- lists:reverse(Sources),
                                        Compiled <- [lists:keyfind(Loaded, #compiled.namespace,
                                                                   CompiledModules)]],
                            loaded_with(Session, Needed ++ CompiledModules,
                                        unicode:characters_to_binary(lists:join("\n", Lines)));
                        {error, Failed} ->
                            {'Left', iolist_to_binary(Failed)}
                    end;
                _ ->
                    {'Left', <<(unicode:characters_to_binary(ern_namespace:text(Declared)))/binary,
                               " is declared in ",
                               (unicode:characters_to_binary(ern_build:shown(File)))/binary,
                               ", which is not where ", Name/binary, " belongs\n">>}
            end;
        none ->
            case compiled_of(Session, Namespace) of
                {ok, File, Beam, Hash} ->
                    %% report §11.2: what it uses that the session has not
                    %% loaded is placed before it, and it last
                    case compiled_placed(Session, Namespace, Beam, Hash, placing(Session)) of
                        {ok, #placing{needed = All}} ->
                            loaded_with(Session, All,
                                        <<Name/binary, ", from ",
                                          (unicode:characters_to_binary(
                                             ern_build:shown(File)))/binary>>);
                        {_, Refusal} ->
                            {'Left', Refusal}
                    end;
                {error, Refusal} ->
                    {'Left', <<Refusal/binary, "\n">>};
                none ->
                    {'Left', <<"no module ", Name/binary, " under the source root or on the"
                               " load path\n">>}
            end
    end.

%% Report §11.2: the modules to compile for `:load`, each with its source:
%% the one named, and each it uses, directly or through another, that the
%% session has not loaded and whose source the source root holds. A module
%% that does not parse uses nothing here; compiling it reports why.
with_sources(_Session, [], Acc) ->
    Acc;
with_sources(#session{source_root = SourceRoot, source_hashes = Loaded} = Session,
             [{Namespace, File} | Rest], Acc) ->
    case lists:keymember(Namespace, 1, Acc) of
        true ->
            with_sources(Session, Rest, Acc);
        false ->
            Dependencies =
                try ern_build:compile_order([ern_build:module_of(ern_build:absolute(File),
                                                                 SourceRoot)],
                                            SourceRoot, load_path(Session)) of
                    [#build_module{dependencies = Found}] -> Found
                catch
                    throw:_ -> []
                end,
            More = [{Dependency, SourceFile} || Dependency <- Dependencies,
                                            not is_map_key(Dependency, Loaded),
                                            {ok, SourceFile} <- [source_of(Session, Dependency)]],
            with_sources(Session, Rest ++ More, Acc ++ [{Namespace, File}])
    end.

%% The modules of a `:load` loaded, what they use that the session had not
%% loaded among them, and `:load`'s answer.
loaded_with(Session, All, Answer) ->
    case refused_compiled(Session, All) of
        none -> installed(Session, All, Answer);
        Refusal -> {'Left', <<(unicode:characters_to_binary(Refusal))/binary, "\n">>}
    end.

%% Report §11.2: a compiled module is refused as `ern run` refuses one: a
%% module compiled against another interface of a module it uses, or of the
%% standard library, than the session holds; none, or the refusal. A file
%% that holds another module than its path names is refused as it is found
%% (compiled_of/2).
refused_compiled(Session, All) ->
    StdlibHash = ern_build:stdlib_hash(),
    Interfaces = [Interface || #compiled{beam = Beam} <- All,
                               {ok, #{interface := Interface}} <- [ern_interface:read(Beam)]]
        ++ Session#session.interfaces ++ ern_prelude:stdlib_interfaces(),
    Refusals = lists:append([compiled_refusals(Namespace, Beam, Interfaces, StdlibHash)
                             || #compiled{namespace = Namespace, beam = Beam} <- All]),
    case Refusals of
        [] -> none;
        [First | _] -> First
    end.

compiled_refusals(Namespace, Beam, Interfaces, StdlibHash) ->
    {ok, #{deps := DependencyHashes} = Chunk} = ern_interface:read(Beam),
    Name = ern_namespace:text(Namespace),
    [Name ++ " was compiled against another standard library; build " ++ Name ++ " again"
     || not lists:member(maps:get(stdlib, Chunk, none), [none, StdlibHash])]
        ++ [Name ++ " was compiled against another " ++ ern_namespace:text(Dependency)
            ++ "; build " ++ Name ++ " again"
            || {Dependency, Hash} <- DependencyHashes,
               [Interface | _] <- [held_interfaces(Dependency, Interfaces)],
               ern_interface:hash(Interface) =/= Hash].

held_interfaces(Namespace, Interfaces) ->
    [Interface || #interface{namespace = Found} = Interface <- Interfaces, Found =:= Namespace].

%% Report §11.2: the modules installed and their bindings evaluated, and
%% `:load`'s answer; a binding that faults leaves nothing loaded.
installed(Session, All, Answer) ->
    Session1 = install(Session, All),
    case initialize(in_order(All)) of
        {ok, _} ->
            initialized(All),
            {'Right', {keep_session(Session1), Answer}};
        {fault, _, Site, How, _, Evaluators} ->
            Killed = withdraw(All, Evaluators),
            {'Left', <<(binding_end(Site, How))/binary, "; nothing was loaded",
                       (killed_text(Killed))/binary, "\n">>}
    end.

%% Report §8.5, §11.2: the modules in the order their bindings are
%% evaluated, each after those it depends on, by the units they are.
in_order(CompiledModules) ->
    ByUnit = maps:from_list([{Unit, Compiled}
                             || #compiled{unit = Unit} = Compiled <- CompiledModules]),
    [maps:get(Unit, ByUnit)
     || Unit <- ern_rt:ordered([Unit || #compiled{unit = Unit} <- CompiledModules])].

%% Report §11.2: a refused `:load` or `:reload` undone, so that the session
%% is as it was: every process its evaluation started, directly or
%% through one it started, is killed (§6.9) and waited for, each of them
%% started by one of Evaluators, a process of a unit the node held among
%% them, and then each of Evaluators that lives on, which nothing names;
%% and the values the bindings of every unit it evaluated stored go, so
%% that a unit the node held, which the session had not evaluated, is
%% without them as before (ern_rt:withdraw_load/2).
%%
%% The units the load brought stay loaded and in the code table, as any
%% unit does, out of the session's scope, since a process running before
%% the load may have been handed a function of one, as an input's code is
%% kept; the module loaded again, unchanged, makes no unit (compile_unit/5,
%% compiled_unit/5). Code.load undoes a load so too (Appendix E.28). The
%% spawn sites of the processes killed.
withdraw(All, Evaluators) ->
    ern_rt:withdraw_load(Evaluators, [Unit || #compiled{unit = Unit} <- All]).

%% Report §11.2: the refusal names the processes it killed by their spawn
%% sites.
killed_text([]) ->
    <<>>;
killed_text(Sites) ->
    unicode:characters_to_binary([", and ", processes_at(Sites), counted(Sites, " was", " were"),
                                  " killed"]).

%% Report §8.5, §8.7: a unit's top-level bindings, each by its qualified
%% name, with its hash and the key its value is kept under, as its
%% '$code'/0 lists them.
unit_bindings(Unit) ->
    case erlang:function_exported(Unit, '$code', 0) of
        true -> maps:from_list([{QualifiedName, {Hash, Key}}
                                || {QualifiedName, {binding, Hash, Key}} <- Unit:'$code'()]);
        false -> #{}
    end.

%% Report §11.2, §8.5: the top-level bindings of each module, dependencies
%% first, each module's evaluated in an evaluator of its own, at `Never`,
%% while the session waits (ern_rt:evaluate/2): its fault is this answer's
%% and not a fault report's, and a kill, which nothing catches, is no fault
%% (§6.9), each named by the binding's site, which '$init' gave the
%% evaluator. `{ok, Evaluators}`, or the module whose binding faulted or
%% whose evaluator was killed, the binding's site, how it ended, `{faulted,
%% Cause}` or `killed`, the modules after it, and Evaluators, those the
%% modules were evaluated in, in order, each the root of the processes its
%% evaluation started. Evaluators: those so far, the last first.
%%
%% Report §11.2: once the bindings have their values the evaluator lives on
%% while it owns what a binding opened, a listener or a running program, so
%% that it stays open as it does under `ern run` (Appendix E.18, E.28), and
%% on a node a session detaches from, after the session, as the node's
%% (detach/0). No deadlock is found in the wait, since a session holds the
%% terminal, waits on its next line or is a node (ern_rt's look).
initialize(CompiledModules) ->
    initialize(CompiledModules, []).

initialize([], Evaluators) ->
    {ok, lists:reverse(Evaluators)};
initialize([#compiled{unit = Unit} = Compiled | Rest], Evaluators) ->
    case erlang:function_exported(Unit, '$init', 0) of
        true -> evaluate(Compiled, Rest, Evaluators);
        false -> initialize(Rest, Evaluators)
    end.

evaluate(#compiled{unit = Unit} = Compiled, Rest, Evaluators) ->
    case ern_rt:evaluate([Unit], <<"Ernest.Shell.load">>) of
        {evaluated, Evaluator} ->
            initialize(Rest, [Evaluator | Evaluators]);
        {ended, Evaluator, Site, How} ->
            {fault, Compiled, Site, How, Rest, lists:reverse([Evaluator | Evaluators])}
    end.

%% Report §8.7: the units whose bindings a load evaluated, so that a peer's
%% spawn finds their values, as it finds a run's.
initialized(CompiledModules) ->
    lists:foreach(fun(#compiled{unit = Unit}) -> ern_rt:initialized(Unit) end, CompiledModules).

%% Report §11.2: a binding that faulted, with its cause, or whose process
%% was killed, by its site.
binding_end(Site, {faulted, Cause}) ->
    <<Site/binary, " faulted: ", (ern_show:controls(Cause, line))/binary>>;
binding_end(Site, killed) ->
    <<Site/binary, " was killed">>.

%% Report §11.2: what a module uses placed before it, so that it is linked
%% to their units: a module the session has loaded is placed already; one
%% of the load's source set is compiled first, where the order of the set
%% has not placed it yet, as for a module of the load path that uses one;
%% and any other is found as the runner finds it, by its namespace on the
%% load path, and placed after the modules it uses. The placing, or why
%% one cannot be loaded, a cycle among them (report §11.1).
needed_placed(_Session, [], Placing) ->
    {ok, Placing};
needed_placed(Session, [Dependency | Rest], Placing) ->
    case dependency_placed(Session, Dependency, Placing) of
        {ok, Placing1} -> needed_placed(Session, Rest, Placing1);
        Error -> Error
    end.

%% One module a module uses placed: one whose placing waits on it is a
%% cycle, refused as `ern build` refuses one (report §11.1, §11.2); one of
%% the source set compiled now, where the set's order has not reached it;
%% one the session has loaded, or the load has placed or could not
%% compile, as it is; and any other found on the load path.
dependency_placed(#session{source_hashes = Loaded} = Session, Dependency,
                  #placing{sources = Sources, placed = Placed, waiting = Waiting} = Placing) ->
    case lists:member(Dependency, Waiting) of
        true ->
            {Cycle, _} = lists:splitwith(fun(Namespace) -> Namespace =/= Dependency end, Waiting),
            {cycle, unicode:characters_to_binary([ern_build:module_cycle([Dependency | Cycle]),
                                                  "\n"])};
        false ->
            case Sources of
                #{Dependency := Module} -> {ok, compiled_in_order(Session, Module, Placing)};
                _ when is_map_key(Dependency, Loaded); is_map_key(Dependency, Placed) ->
                    {ok, Placing};
                _ -> needed_one(Session, Dependency, Placing)
            end
    end.

needed_one(Session, Namespace, Placing) ->
    case compiled_of(Session, Namespace) of
        {ok, _, Beam, Hash} ->
            compiled_placed(Session, Namespace, Beam, Hash, Placing);
        {error, Refusal} ->
            {error, <<Refusal/binary, "\n">>};
        none ->
            Name = unicode:characters_to_binary(ern_namespace:text(Namespace)),
            {error, <<"no module ", Name/binary, " on the load path\n">>}
    end.

%% A module the load takes from its compiled form Beam placed, after what
%% it uses, among the load's modules from the load path.
compiled_placed(Session, Namespace, Beam, Hash, #placing{waiting = Waiting} = Placing) ->
    {ok, #{deps := DependencyHashes}} = ern_interface:read(Beam),
    case needed_placed(Session, [Dependency || {Dependency, _} <- DependencyHashes],
                       Placing#placing{waiting = [Namespace | Waiting]}) of
        {ok, Used} ->
            Placing1 = Used#placing{waiting = Waiting},
            case compiled_unit(Session, Namespace, Beam, Hash, Placing1) of
                {ok, Compiled} ->
                    #placing{needed = Needed} = Placing2 = placed(Compiled, Placing1),
                    {ok, Placing2#placing{needed = Needed ++ [Compiled]}};
                Error ->
                    Error
            end;
        Error ->
            Error
    end.

%% A load's placing as it begins: the session's interfaces and units.
placing(#session{units = Units} = Session) ->
    #placing{interfaces = loaded_interfaces(Session), units = Units}.

%% The placing with a module the load placed, which those after it are
%% compiled against and call.
placed(#compiled{namespace = Namespace, unit = Unit, beam = Beam},
       #placing{interfaces = Interfaces, units = Units, placed = Placed} = Placing) ->
    {ok, #{interface := Interface}} = ern_interface:read(Beam),
    Placing#placing{interfaces = Interfaces#{Namespace => Interface},
                    units = with_unit(Namespace, Unit, Units), placed = Placed#{Namespace => Unit}}.

%% The unit a module of the session's or of the load runs as, or unknown
%% for one the load could not compile.
placed_unit(#session{source_hashes = Loaded} = Session, Namespace, #placing{placed = Placed}) ->
    case Placed of
        #{Namespace := Unit} -> Unit;
        _ when is_map_key(Namespace, Loaded) -> unit(Session, Namespace);
        _ -> unknown
    end.

%%
%% Units, report §8.7, §11.2
%%

%% Report §8.7, §11.2: a module loaded from its compiled form is placed as
%% Code.load places one (ern_code:placement/4), linked to the units of the
%% modules it uses, the session's and those the load placed before it.
%%
%% The module is the unit of its Erlang name where the host holds this very
%% code there, or none, and each module it uses is under its own Erlang
%% name, its compiled form loaded as it is, as a node holds its build's.
%% Else it is a unit made from its forms by the back end as it is
%% installed, once the modules it uses are (install/2), of its Erlang name
%% where the host holds no code of it and of a name of its own beside it
%% otherwise, as a reload's version is. Or it is a unit an earlier load
%% made of these very forms, a refused load's, which stays loaded
%% (withdraw/2), so that a module loaded again, unchanged, makes no unit. A
%% module it uses that the load could not compile has no unit, and the load
%% is refused (compile_in_order/2).
compiled_unit(Session, Namespace, Beam, Hash, Placing) ->
    {ok, #{deps := DependencyHashes}} = ern_interface:read(Beam),
    {ok, Recorded} = ern_canonical:read(Beam),
    Dependencies = [{Dependency, placed_unit(Session, Dependency, Placing)}
                    || {Dependency, _} <- DependencyHashes],
    case ern_code:placement(Namespace, Beam, Recorded, Dependencies) of
        {error, Text} ->
            {error, <<Text/binary, "\n">>};
        {Made, Unit} ->
            {ok, #compiled{namespace = Namespace, unit = Unit, beam = Beam, source_hash = Hash,
                           made = Made}}
    end.

%% Report §8.7, §11.2: a module compiled from its source as a unit no other
%% code has taken, since a unit never takes a second version. A module the
%% session has loaded is a unit of a name of its own (fresh_unit/1), its
%% version's, whose spawn sites carry the version's number (site_namespace/2);
%% any other the unit of its Erlang name where the node holds no code of it,
%% or holds this very code, as a node holds its build's, and else one of a
%% name of its own.
compile_unit(#session{source_hashes = Loaded} = Session, Namespace, File, Interfaces, Units) ->
    Plain = ern_namespace:erlang_module(Namespace),
    case {is_map_key(Namespace, Loaded), ern_code:is_free(Plain)} of
        {true, _} ->
            fresh_compiled(Session, Namespace, File, {Interfaces, Units},
                           site_namespace(Session, Namespace));
        {false, true} ->
            compiled_as(Session, Namespace, Plain, File, {Interfaces, Units}, own);
        {false, false} ->
            case compiled_as(Session, Namespace, Plain, File, {Interfaces, Units}, own) of
                {ok, #compiled{beam = Beam}} = Compiled ->
                    case ern_code:is_held(Plain, Beam) of
                        true -> Compiled;
                        false -> fresh_compiled(Session, Namespace, File, {Interfaces, Units}, own)
                    end;
                Error ->
                    Error
            end
    end.

%% Report §11.2, Appendix E.28: a module compiled as a unit of a name of
%% its own beside its Erlang name: the first name the host holds no code
%% of, or a unit beside it that an earlier load of the session made of
%% this very code and kept when the load was refused (withdraw/2), whose
%% bindings have no value, so that a module loaded again, unchanged, makes
%% no unit. A unit beside it that holds the module's forms is compiled
%% again as that unit, and taken where the host holds this very code there,
%% as the unit of its Erlang name is (compile_unit/5).
fresh_compiled(Session, Namespace, File, Against, SiteNamespace) ->
    case fresh_unit(Namespace) of
        {ok, Unit} ->
            case compiled_as(Session, Namespace, Unit, File, Against, SiteNamespace) of
                {ok, Fresh} -> {ok, kept_or_fresh(Session, Fresh, File, Against, SiteNamespace)};
                Error -> Error
            end;
        {error, _} = Error ->
            Error
    end.

kept_or_fresh(Session, #compiled{namespace = Namespace, beam = Beam} = Fresh, File, Against,
              SiteNamespace) ->
    {ok, Recorded} = ern_canonical:read(Beam),
    IsKept = fun(Unit) ->
                     not ern_rt:is_initialized(Unit) andalso ern_code:forms(Unit) =:= {ok, Recorded}
             end,
    case ern_code:unit_beside(Namespace, IsKept) of
        {held, Unit} ->
            case compiled_as(Session, Namespace, Unit, File, Against, SiteNamespace) of
                {ok, #compiled{beam = KeptBeam} = Kept} ->
                    case ern_code:is_held(Unit, KeptBeam) of
                        true -> Kept;
                        false -> Fresh
                    end;
                {error, _} ->
                    Fresh
            end;
        _ ->
            Fresh
    end.

%% Report §11.2: the namespace a reload's version of a loaded module names
%% its spawn sites under, the module's and its version's number,
%% `Counter$2`, as the version's unit is named; the first version's are the
%% module's own.
site_namespace(#session{versions = Versions}, Namespace) ->
    [list_to_atom(ern_namespace:text(Namespace) ++ "$"
                  ++ integer_to_list(maps:get(Namespace, Versions, 1) + 1))].

%% A module compiled from File as Unit, against Interfaces, calling each
%% module of the session by the unit Units names, its spawn sites named
%% under SiteNamespace.
compiled_as(Session, Namespace, Unit, File, {Interfaces, Units}, SiteNamespace) ->
    case compile_source(Session, File, Interfaces, with_unit(Namespace, Unit, Units),
                        SiteNamespace) of
        {ok, _, Beam, Hash} ->
            {ok, #compiled{namespace = Namespace, unit = Unit, beam = Beam, source_hash = Hash,
                           from_source = true}};
        {error, _} = Error ->
            Error
    end.

%% Report §11.2: a unit of a name of its own, for a module whose Erlang name
%% the node holds code of (ern_code:fresh_unit/1), or the refusal of a name
%% the host does not hold, a line of the shell's.
fresh_unit(Namespace) ->
    case ern_code:fresh_unit(Namespace) of
        {ok, Unit} -> {ok, Unit};
        {error, Text} -> {error, <<Text/binary, "\n">>}
    end.

%% The unit map with a module's unit, which names it only where it is not
%% the module's Erlang name.
with_unit(Namespace, Unit, Units) ->
    case ern_namespace:erlang_module(Namespace) of
        Unit -> maps:remove(Namespace, Units);
        _ -> Units#{Namespace => Unit}
    end.

%% The unit a namespace of the session runs as: its current version's, or
%% for a previous version's namespace, that version's (report §11.2).
unit(#session{units = Units}, Namespace) ->
    case Units of
        #{Namespace := Unit} -> Unit;
        _ -> ern_namespace:erlang_module(Namespace)
    end.

%%
%% Reloading, report §11.2
%%

%% Report §11.2: every module the session loaded whose source has changed,
%% or one of whose qualified names would now resolve elsewhere (§11.1),
%% compiled and loaded as a version of its own, a unit beside the previous
%% version's, which a process still running it and a binding that holds a
%% function of it keep. Every changed module is compiled before any is
%% loaded, and where one does not compile none is, so the session goes on
%% with every module as it was.
-spec reload(#session{}) -> {'Left', binary()} | {'Right', {#session{}, [binary()]}}.
reload(Session) ->
    without_line_feed(nodes_load(Session, fun reload_changed/1)).

reload_changed(#session{source_hashes = SourceHashes, source_expected = Expected} = Session) ->
    Sources = [{Namespace, LoadedHash, source_of(Session, Namespace)}
               || {Namespace, LoadedHash} <- lists:sort(maps:to_list(SourceHashes))],
    ChangedSources = [{Namespace, File}
               || {Namespace, LoadedHash, {ok, File}} <- Sources,
                  {ok, Hash} <- [source_hash(Session, File)],
                  Hash =/= LoadedHash orelse is_resolved_otherwise(Session, Namespace)],
    SourcelessLines = sourceless(Session, [Namespace || {Namespace, _, none} <- Sources,
                                                        is_map_key(Namespace, Expected)]),
    case ChangedSources of
        [] ->
            {'Right', {Session, [<<"no source has changed">> | SourcelessLines]}};
        _ ->
            case compile_all(Session, ChangedSources) of
                {ok, Needed, Compiled} -> reloaded(Session, Needed, Compiled, SourcelessLines);
                {error, Text} -> {'Left', iolist_to_binary([Text, "nothing was reloaded\n"])}
            end
    end.

%% Report §11.1, §11.2: whether a qualified name of a loaded module would
%% now resolve to another namespace than its compiled form records, a
%% module added or gone beside it, where `ern build` recompiles it (§4.2).
is_resolved_otherwise(#session{source_root = SourceRoot} = Session, Namespace) ->
    case recorded(Session, Namespace) of
        #{resolved := Resolved} ->
            IsNamespace = ern_build:namespace_test(hd(Namespace), SourceRoot, load_path(Session)),
            ern_resolve:qualifiers([Written || {Written, _} <- Resolved], Namespace, IsNamespace)
                =/= Resolved;
        #{} ->
            false
    end.

%% Report §11.2: the modules loaded, what the changed ones have come to
%% use that the session had not loaded among them, and their bindings
%% evaluated, dependencies first. Where a binding of a module loaded for the
%% first time faults, or is not evaluated since one before it faulted,
%% nothing is reloaded; where one of a new version faults, it and the
%% bindings after it keep the previous version's values, each where the
%% previous version has it of one hash.
reloaded(#session{source_hashes = Loaded} = Session, Needed, Compiled, SourcelessLines) ->
    All = Needed ++ Compiled,
    Session1 = install(Session, All),
    IsFirst = fun(#compiled{namespace = Namespace}) -> not is_map_key(Namespace, Loaded) end,
    case initialize(in_order(All)) of
        {ok, _} ->
            reload_done(Session, Session1, {All, Compiled}, [], SourcelessLines);
        {fault, Faulted, Site, How, Rest, Evaluators} ->
            case lists:any(IsFirst, [Faulted | Rest]) of
                false ->
                    lists:foreach(fun(Kept) -> kept_values(Session, Kept) end, [Faulted | Rest]),
                    %% the bindings before the fault keep their values, and
                    %% their processes live on
                    reload_done(Session, Session1, {All, Compiled},
                                [kept_values_line(Site, How)], SourcelessLines);
                true ->
                    Killed = withdraw(All, Evaluators),
                    {'Left', <<(binding_end(Site, How))/binary, "; nothing was reloaded",
                               (killed_text(Killed))/binary, "\n">>}
            end
    end.

%% Report §11.2: the reload's answer: a line for each module it compiled,
%% each of the session's declarations it compiled again or let go
%% (reached_inputs/2), the bindings it leaves of a previous version, a
%% binding's fault, and the modules without a source; and the session with
%% each version counted. Every unit it loaded, All, was evaluated; Compiled
%% were compiled from their sources, or are a module loaded for the first
%% time whose current compiled form the reload took, as `:load` takes it.
reload_done(Before, After, {All, Compiled}, Faulted, SourcelessLines) ->
    Lines = [compiled_line(Before, Module) || Module <- Compiled],
    Reloaded = [Namespace || #compiled{namespace = Namespace} <- Compiled,
                             is_map_key(Namespace, Before#session.source_hashes)],
    {Versioned, Previous} = versioned(Before, After, Reloaded),
    initialized(All),
    {Reached, InputLines, InputsPrevious} = reached_inputs(Versioned, Compiled),
    {'Right', {keep_session(Reached),
               Lines ++ InputLines ++ previous_lines(Reached, maps:merge(Previous, InputsPrevious))
               ++ Faulted ++ SourcelessLines}}.

%% Report §11.2: a module the session had loaded, compiled again, and one it
%% had not, which a changed module has come to use, loaded as `:load` loads
%% it.
compiled_line(#session{source_hashes = Loaded}, #compiled{namespace = Namespace})
  when is_map_key(Namespace, Loaded) ->
    unicode:characters_to_binary([ern_namespace:text(Namespace), ", compiled again"]);
compiled_line(Session, Compiled) ->
    unicode:characters_to_binary(loaded_line(Session, Compiled)).

%% Report §11.2: what `:load` says of a module whose source it holds: the
%% file of the current compiled form it took, `Greet, from greet.erc`, or
%% the source it compiled, `Greet, compiled from greet.ern`, each named from
%% the working directory as §11.5 names a file (ern_build:shown/1).
loaded_line(Session, #compiled{namespace = Namespace, erc = none}) ->
    {ok, File} = source_of(Session, Namespace),
    [ern_namespace:text(Namespace), ", compiled from ", ern_build:shown(File)];
loaded_line(_Session, #compiled{namespace = Namespace, erc = Erc}) ->
    [ern_namespace:text(Namespace), ", from ", ern_build:shown(Erc)].

%% Report §11.2: a reloaded module's binding that faulted, after which the
%% bindings the reload left as they were keep what the previous version
%% gave them, one compiled to its value has it (§11.1), and the rest have
%% no value (kept_values/2).
kept_values_line(Site, How) ->
    <<(binding_end(Site, How))/binary, "; it and the bindings after it whose hash changed, or"
      " which are new, are without a value, but one compiled to its value has it, and the rest"
      " keep the values of the previous version">>.

%% Report §11.2, §8.5: each binding of a new version the reload's fault left
%% without a value takes the value the previous version gave it, where the
%% previous version has the binding of one hash, which writes its type out,
%% so that the value is of the binding's type; any other stays without one.
kept_values(Before, #compiled{namespace = Namespace, unit = Unit}) ->
    Previous = unit_bindings(unit(Before, Namespace)),
    Missing = make_ref(),
    [persistent_term:put(Key, Value)
     || {QualifiedName, {Hash, Key}} <- maps:to_list(unit_bindings(Unit)),
        persistent_term:get(Key, Missing) =:= Missing,
        #{QualifiedName := {PreviousHash, PreviousKey}} <- [Previous], PreviousHash =:= Hash,
        Value <- [persistent_term:get(PreviousKey, Missing)], Value =/= Missing],
    ok.

%% Report §11.2: the changed modules compiled in the order they use one
%% another, each against the session's modules and those compiled before
%% it, with each they have come to use that the session has not loaded and
%% whose source the source root holds, as `:load` compiles it; and, while
%% one changes what a loaded module uses, that module compiled again with
%% them, from its source, as `ern build` would compile it again (§11.1).
%% The modules compiled, with what they use that the session has not loaded
%% and the source root does not hold; or why they cannot all be.
compile_all(Session, ChangedSources) ->
    case compile_in_order(Session, with_sources(Session, ChangedSources, [])) of
        {ok, Needed, CompiledModules} ->
            case stale_users(Session, ChangedSources, CompiledModules) of
                [] ->
                    {ok, Needed, CompiledModules};
                Users ->
                    Sources = [{Namespace, source_of(Session, Namespace)} || Namespace <- Users],
                    case [Namespace || {Namespace, none} <- Sources] of
                        [] ->
                            More = [{Namespace, File} || {Namespace, {ok, File}} <- Sources],
                            compile_all(Session, ChangedSources ++ More);
                        SourcelessUsers ->
                            {error, [unicode:characters_to_binary(
                                       [ern_namespace:text(Namespace),
                                        " uses what the reload changes,"
                                        " and the source root holds no source of it\n"])
                                     || Namespace <- SourcelessUsers]}
                    end
            end;
        Error ->
            Error
    end.

%% Each module compiled, a module after those it uses, against the
%% interfaces of the session and of the modules compiled before it, and as
%% the unit compile_unit/5 gives it, which those after it call; what each
%% uses placed before it (needed_placed/3). What the modules use from the
%% load path and the modules, in the order placed, or why they cannot all
%% be compiled.
compile_in_order(#session{source_root = SourceRoot} = Session, Set) ->
    try ern_build:compile_order([ern_build:module_of(ern_build:absolute(File), SourceRoot)
                                 || {_, File} <- Set], SourceRoot, load_path(Session)) of
        Ordered ->
            Sources = #{Namespace => Module
                        || #build_module{namespace = Namespace} = Module <- Ordered},
            #placing{compiled = Compiled, needed = Needed} =
                lists:foldl(fun(#build_module{namespace = Namespace}, Placing) ->
                                    source_placed(Session, Namespace, Placing)
                            end, (placing(Session))#placing{sources = Sources}, Ordered),
            case [Text || {_, {error, Text}} <- lists:reverse(Compiled)] of
                [] -> {ok, Needed, [Module || {_, {ok, Module}} <- lists:reverse(Compiled)]};
                Texts -> {error, Texts}
            end
    catch
        throw:{cli_error, Message} ->
            {error, [unicode:characters_to_binary([Message, "\n"])]};
        throw:{errors, FailedFile, Diagnostics} ->
            {error, [diagnosed(Session, FailedFile, Diagnostics)]}
    end.

%% A module of the source set compiled, where it is not placed yet.
source_placed(Session, Namespace, #placing{sources = Sources} = Placing) ->
    case Sources of
        #{Namespace := Module} -> compiled_in_order(Session, Module, Placing);
        _ -> Placing
    end.

%% Report §11.2: one module of a `:load`, its current compiled form taken
%% or the module compiled, where every module it uses did, and said not to
%% be loaded where one did not; the build's advice to compile that one
%% first does not apply in the shell.
compiled_in_order(Session, #build_module{namespace = Namespace,
                                         dependencies = Dependencies} = Module,
                  #placing{sources = Sources, placed = Placed, waiting = Waiting} = Placing) ->
    %% placed, its unit unknown until it is compiled, and waiting on what
    %% it uses, so that a module it uses that uses it in turn is a cycle
    Placing1 = Placing#placing{sources = maps:remove(Namespace, Sources),
                               placed = Placed#{Namespace => unknown},
                               waiting = [Namespace | Waiting]},
    case needed_placed(Session, Dependencies, Placing1) of
        {ok, #placing{failed = Failed} = Used} ->
            Placing2 = Used#placing{waiting = Waiting},
            case [Dependency || Dependency <- Dependencies, lists:member(Dependency, Failed)] of
                [Dependency | _] ->
                    failed(Namespace,
                           unicode:characters_to_binary([ern_namespace:text(Namespace),
                                                         " is not loaded, since ",
                                                         ern_namespace:text(Dependency),
                                                         " does not compile\n"]),
                           Placing2);
                [] ->
                    case taken_or_compiled(Session, Module, Placing2) of
                        {ok, Compiled} = Ok ->
                            #placing{compiled = Done} = Placing3 = placed(Compiled, Placing2),
                            Placing3#placing{compiled = [{Namespace, Ok} | Done]};
                        {error, Text} ->
                            failed(Namespace, Text, Placing2)
                    end
            end;
        {cycle, Text} ->
            failed(Namespace, Text, Placing1#placing{waiting = Waiting});
        {error, Text} ->
            %% report §11.2, §11.5: its own diagnostic or refusal first,
            %% where its compile gives one, a module it uses that the load
            %% path lacks among the causes
            Unplaced = Placing1#placing{waiting = Waiting},
            case taken_or_compiled(Session, Module, Unplaced) of
                {error, Diagnostic} -> failed(Namespace, Diagnostic, Unplaced);
                {ok, _} -> failed(Namespace, Text, Unplaced)
            end
    end.

%% The placing with a module of the source set that was not compiled, and
%% why.
failed(Namespace, Text, #placing{compiled = Done, failed = Failed} = Placing) ->
    Placing#placing{compiled = [{Namespace, {error, Text}} | Done], failed = [Namespace | Failed]}.

%% Report §11.2: a module the session has not loaded is its current
%% compiled form where one qualifies (current_form/4), the unit
%% compiled_unit/5 gives a compiled form, and else compiled from its
%% source. A module it has loaded, which a reload compiles again, is
%% compiled.
taken_or_compiled(#session{source_hashes = Loaded} = Session,
                  #build_module{namespace = Namespace, file = File} = Module,
                  #placing{interfaces = Interfaces, units = Units} = Placing) ->
    Taken = case is_map_key(Namespace, Loaded) of
                true -> none;
                false -> current_form(Session, Module, Interfaces, Units)
            end,
    case Taken of
        {ok, Erc, Beam, Hash} ->
            case compiled_unit(Session, Namespace, Beam, Hash, Placing) of
                {ok, Compiled} -> {ok, Compiled#compiled{from_source = true, erc = Erc}};
                Error -> Error
            end;
        _ ->
            compile_unit(Session, Namespace, File, Interfaces, Units)
    end.

%% Report §11.2: a compiled form of the module, beside its source or on the
%% load path, compiled from that source, whose digest it records, by this
%% build of `ern`, against the interfaces the session holds, and calling no module
%% the session holds at a unit of another name than its own, a reload's
%% version among them, since the form calls each module it uses by its
%% own; the candidates are tried under the source root first and then in
%% the load path's order (load_path/1), and the first that qualifies is
%% taken, with its file and the hash of the source it records.
%%
%% The interfaces it is held to are those a compile would check it against:
%% Interfaces, and for a module it uses that the session has not loaded,
%% the one its compiled form on the load path holds. None where none
%% qualifies, or where a module it uses is found nowhere, which compiling
%% it reports.
current_form(#session{source_root = SourceRoot} = Session,
             #build_module{namespace = Namespace, dependencies = Dependencies} = Module,
             Interfaces, Units) ->
    try ern_build:dependency_interfaces(Namespace, Dependencies, Interfaces,
                                        load_path(Session), SourceRoot) of
        DependencyInterfaces ->
            Against = {lists:sort([{Dependency, ern_interface:hash(Interface)}
                                   || {Dependency, Interface} <- DependencyInterfaces]),
                       [Interface || {_, Interface} <- DependencyInterfaces],
                       #{stdlib => ern_build:stdlib_hash(),
                         compiler => ern_build:compiler_build()}},
            Candidates = [{Root, Erc}
                          || Root <- load_path(Session),
                             Erc <- [filename:join(Root, ern_namespace:module_path(Namespace)
                                                   ++ ".erc")],
                             filelib:is_regular(Erc)],
            case [Dependency || {Dependency, _} <- DependencyInterfaces,
                                is_map_key(Dependency, Units)] of
                [] when Candidates =/= [] ->
                    first_current_form(Session, Candidates, Module, Against);
                _ ->
                    none
            end
    catch
        throw:{cli_error, _} -> none
    end.

%% The first of the candidates that qualifies, against the digest of the
%% source as the session reads it, through its local half (§11.2 *The
%% attached shell*), read once and only where a candidate is there.
first_current_form(Session, Candidates, #build_module{file = File} = Module, Against) ->
    case source_hash(Session, File) of
        {ok, Digest} -> first_qualified(Candidates, Module, Digest, Against);
        none -> none
    end.

first_qualified([], _Module, _Digest, _Against) ->
    none;
first_qualified([{Root, Erc} | Candidates], Module, Digest, Against) ->
    case qualified_form(Root, Erc, Module, Digest, Against) of
        {ok, _, _, _} = Found -> Found;
        none -> first_qualified(Candidates, Module, Digest, Against)
    end.

%% The compiled form Erc at the module's path under Root, where it
%% qualifies: of this module, compiled from this source by the path it
%% records from Root, the source's digest the one it records, never a
%% time, which two machines keep by two clocks, each qualifier resolving
%% to the namespace it records (§4.2); and compiled against the
%% interfaces and the standard library of Against, by the build of `ern`
%% it holds, as the build's own recompile rule compares them (§11.1), so
%% that a form another build of `ern` wrote keeps no defect this one has
%% fixed; and code the host will load as the module's unit, as the build's
%% rule asks it too (§11). A file that cannot be read is none, and the
%% module is compiled from its source.
qualified_form(Root, Erc, Module, Digest, Against) ->
    case file:read_file(Erc) of
        {ok, Beam} -> compiled_against(Root, Erc, Beam, Module, Digest, Against);
        {error, _} -> none
    end.

compiled_against(Root, Erc, Beam,
                 #build_module{namespace = Namespace, file = File, resolved = Resolved}, Digest,
                 {DependencyHashes, DependencyInterfaces,
                  #{stdlib := StdlibHash, compiler := CompilerBuild}}) ->
    case ern_interface:read(Beam) of
        {ok, #{interface := #interface{namespace = Namespace}, source_path := SourcePath,
               source_hash := Digest, resolved := Resolved, compiler := CompilerBuild} = Chunk} ->
            Source = filename:join(Root, unicode:characters_to_list(SourcePath)),
            case ern_build:absolute(Source) =:= ern_build:absolute(File)
                andalso ern_build:is_compiled_against(Chunk, DependencyHashes,
                                                      DependencyInterfaces, StdlibHash)
                andalso ern_chunk:is_loadable(ern_namespace:erlang_module(Namespace), Beam) of
                true -> {ok, Erc, Beam, Digest};
                false -> none
            end;
        _ ->
            none
    end.

%% Report §11.2, §11.1: the loaded modules, outside those compiled, that
%% `ern build` would compile again for them: one that uses a compiled
%% module whose interface is not the one the session holds, or whose forms
%% reference a definition of one whose hash the compiled module changed.
stale_users(#session{source_hashes = Loaded} = Session, Set, CompiledModules) ->
    LoadedInterfaces = loaded_interfaces(Session),
    Compiled = [{Namespace, Interface}
                || #compiled{namespace = Namespace, beam = Beam} <- CompiledModules,
                   {ok, #{interface := Interface}} <- [ern_interface:read(Beam)]],
    InterfaceChanged = [Namespace || {Namespace, Interface} <- Compiled,
                            not is_map_key(Namespace, LoadedInterfaces)
                                orelse ern_interface:hash(maps:get(Namespace, LoadedInterfaces))
                                       =/= ern_interface:hash(Interface)],
    Identities = maps:from_list([{QualifiedName, Hash}
                                 || {_, #interface{identities = Held}} <- Compiled,
                                    {QualifiedName, Hash} <- maps:to_list(Held)]),
    IsChanged = fun({QualifiedName, Hash}) ->
                        lists:any(fun({Namespace, _}) -> lists:prefix(Namespace, QualifiedName)
                                  end, Compiled)
                            andalso maps:get(QualifiedName, Identities, none) =/= Hash
                end,
    IsStale = fun(Namespace) ->
                      #{deps := DependencyHashes} = Recorded = recorded(Session, Namespace),
                      References = maps:get(references, Recorded, []),
                      lists:any(fun({Dependency, _}) -> lists:member(Dependency, InterfaceChanged)
                                end, DependencyHashes)
                          orelse lists:any(IsChanged, References)
              end,
    [Namespace || Namespace <- lists:sort(maps:keys(Loaded)),
                  not lists:keymember(Namespace, 1, Set), IsStale(Namespace)].

%% What a loaded module's compiled form records (§11.1), the dependencies'
%% interfaces' hashes and the definitions its forms reference among it: the
%% compiled module the session holds, or, for a module its node's runner
%% loaded, the chunk as the runner loaded it (ern_code:chunk/1), never the
%% file, which a build may have written again or taken away since.
recorded(#session{beams = Beams} = Session, Namespace) ->
    case Beams of
        #{Namespace := Beam} ->
            {ok, Chunk} = ern_interface:read(Beam),
            Chunk;
        _ ->
            {ok, Chunk} = ern_code:chunk(unit(Session, Namespace)),
            Chunk
    end.

%% The interfaces of the modules the session has loaded, by namespace.
loaded_interfaces(#session{interfaces = Interfaces, source_hashes = SourceHashes}) ->
    maps:from_list([{Namespace, Interface}
                    || #interface{namespace = Namespace} = Interface <- Interfaces,
                       is_map_key(Namespace, SourceHashes)]).

%% Each module installed as its unit, loaded where the node does not hold
%% it already, and in scope by its namespace in place of its previous
%% version, each after the modules it uses (in_dependency_order/1).
install(Session, CompiledModules) ->
    lists:foldl(fun install_one/2, Session, in_dependency_order(CompiledModules)).

install_one(#compiled{namespace = Namespace, unit = Unit, beam = Compiled, source_hash = Hash,
                      from_source = FromSource, made = Made},
            #session{interfaces = Interfaces, source_hashes = SourceHashes, beams = Beams,
                     units = Units, source_expected = Expected} = Session) ->
    %% report §11.2: a compiled module that is not loaded as it is made a
    %% unit from its forms, linked to the units the session holds of the
    %% modules it uses, which are installed before it
    Beam = case Made of
               forms ->
                   {ok, Built} = ern_compile:from_compiled(Compiled, Unit, Interfaces, prelude(),
                                                          with_unit(Namespace, Unit, Units)),
                   Built;
               _ ->
                   Compiled
           end,
    case Made =:= held orelse ern_code:is_held(Unit, Beam) of
        true -> ok;
        false -> {module, Unit} = code:load_binary(Unit, atom_to_list(Unit), Beam)
    end,
    unit_loaded(Unit, Beam),
    {ok, #{interface := Interface}} = ern_interface:read(Beam),
    Others = [Other || #interface{namespace = Found} = Other <- Interfaces, Found =/= Namespace],
    Session#session{interfaces = Others ++ [Interface],
                    source_hashes = SourceHashes#{Namespace => Hash},
                    source_expected = case FromSource of
                                          true -> Expected#{Namespace => true};
                                          false -> Expected
                                      end,
                    beams = Beams#{Namespace => Beam},
                    units = with_unit(Namespace, Unit, Units)}.

%% The modules of a load in an order where each follows those it uses, by
%% what their compiled forms record, so that one made from its forms is
%% linked to the units the session holds of them as it is installed; the
%% order of the list is kept where no dependency decides it.
in_dependency_order(CompiledModules) ->
    ByNamespace = #{Namespace => Compiled
                    || #compiled{namespace = Namespace} = Compiled <- CompiledModules},
    {Order, _} = lists:foldl(fun(#compiled{namespace = Namespace}, Acc) ->
                                     with_dependencies(Namespace, ByNamespace, Acc)
                             end, {[], #{}}, CompiledModules),
    lists:reverse(Order).

%% Order, the modules visited so far, the last first, with the module of
%% Namespace after the modules of the load it uses; Seen by namespace.
with_dependencies(Namespace, ByNamespace, {Order, Seen} = Acc) ->
    case ByNamespace of
        #{Namespace := #compiled{beam = Beam} = Compiled} when not is_map_key(Namespace, Seen) ->
            {ok, #{deps := DependencyHashes}} = ern_interface:read(Beam),
            {Order1, Seen1} = lists:foldl(fun({Dependency, _}, DependencyAcc) ->
                                                  with_dependencies(Dependency, ByNamespace,
                                                                    DependencyAcc)
                                          end, {Order, Seen#{Namespace => true}},
                                          DependencyHashes),
            {[Compiled | Order1], Seen1};
        _ ->
            Acc
    end.

%%
%% The session's declarations at a reload, report §11.2
%%

%% Report §11.2: the session's declarations in scope whose forms reference a
%% definition the reload changes, each input that made them compiled again
%% as a new version of its input, in the order the inputs were entered, so
%% that one compiled again with a changed hash changes in turn what a later
%% one references, as `ern build` compiles a dependent again (§11.1). An
%% input none of whose declarations is in scope, every one shadowed, is
%% left alone, and a `let` keeps its value. Compiled: the modules the
%% reload compiled. The session with each new version, the lines that say
%% each, and each type a new version made the previous version's, by its
%% new name, with the name it had.
reached_inputs(#session{beams = Beams, scope = Scope} = Session, Compiled) ->
    Changed = [{Namespace, Identities}
               || #compiled{namespace = Namespace, beam = Beam} <- Compiled,
                  {ok, #{interface := #interface{identities = Identities}}}
                      <- [ern_interface:read(Beam)]],
    InScope = #{Segment => true || Which <- [values, types, constructors],
                                   [Segment | _] <- maps:values(maps:get(Which, Scope, #{}))},
    Inputs = lists:sort([{Number, [Segment]}
                         || [Segment] := _ <- Beams, is_map_key(Segment, InScope),
                            Number <- [input_number(Segment)], Number =/= none]),
    {Reached, _, Lines, Previous} =
        lists:foldl(fun({_, Namespace}, Acc) -> reached_input(Namespace, Acc) end,
                    {Session, Changed, [], #{}}, Inputs),
    {Reached, Lines, Previous}.

%% The number of an input's namespace segment, the `n` of `$Input<s>_<n>`,
%% or none.
input_number(Segment) ->
    case string:split(atom_to_list(Segment), "_") of
        ["$Input" ++ _, Digits] -> list_to_integer(Digits);
        _ -> none
    end.

%% One declaring input compiled again where its forms reference a definition
%% whose hash Changed, each namespace's new identities, no longer holds,
%% its namespace the longest of Changed that its qualified name begins
%% with, which is the module or the input that declares it.
reached_input(Namespace, {Session, Changed, _, _} = Acc) ->
    References = maps:get(references, recorded(Session, Namespace), []),
    IsChanged = fun({QualifiedName, Hash}) ->
                        case [{length(Changing), Identities}
                              || {Changing, Identities} <- Changed,
                                 lists:prefix(Changing, QualifiedName)] of
                            [] -> false;
                            Owners -> maps:get(QualifiedName, element(2, lists:max(Owners)),
                                               none) =/= Hash
                        end
                end,
    case lists:any(IsChanged, References) of
        true -> compiled_again(Namespace, Acc);
        false -> Acc
    end.

%% Report §11.2: a declaring input compiled again as `:load` compiles a
%% module, against the modules at their new versions and the session's
%% names as they stood at the input, beside the interface of its previous
%% version, which its own declarations shadow and its new one replaces: a
%% unit of its own beside the previous version's, as a module's version is,
%% which a process of the previous version still runs, the prompt using the
%% new from then on. One that no longer compiles is reported with its
%% diagnostic, which names its input, and its declarations go from scope;
%% the reload goes on.
compiled_again(Namespace, {Session, Changed, Lines, Previous}) ->
    #input_text{text = Text, origin = Origin, scope = Scope} = InputText =
        kept({input_text, Namespace}, none),
    {declarations, Declarations} = input(Text),
    case ern_typecheck:check(Namespace, Declarations, checked_interfaces(Session),
                             Scope#{input_names => input_names(Session)}, prelude()) of
        {ok, Typed, Interface, Env} ->
            case fresh_unit(Namespace) of
                {ok, Unit} ->
                    {Versioned, Identities, Moved} =
                        new_version(Session, Namespace, Unit, InputText,
                                    {Typed, Interface, Env}),
                    Line = unicode:characters_to_binary([input_name(Origin), ", compiled again"]),
                    {Versioned, [{Namespace, Identities} | Changed], Lines ++ [Line],
                     maps:merge(Previous, Moved)};
                {error, Refusal} ->
                    gone(Namespace, Origin, Refusal, {Session, Changed, Lines, Previous})
            end;
        {error, Diagnostics} ->
            Shown = diagnostic(Session, Origin, Text,
                               [previous_hinted(Session, load_hinted(Session, D))
                                || D <- Diagnostics]),
            gone(Namespace, Origin, Shown, {Session, Changed, Lines, Previous})
    end.

%% A declaring input that no longer compiles, said with Why, gone from scope.
gone(Namespace, Origin, Why, {Session, Changed, Lines, Previous}) ->
    {Gone, Went} = out_of_scope(Session, Namespace, Origin),
    {Gone, Changed, Lines ++ [string:trim(Why, trailing, "\n"), Went], Previous}.

%% The new version of a declaring input compiled as Unit, loaded and in the
%% session in place of the previous one, which a type it changed names
%% from then on (versioned/3); and the new version's identities, and the
%% types it made the previous version's.
new_version(#session{interfaces = Interfaces, beams = Beams, units = Units} = Session, Namespace,
            Unit, #input_text{origin = Origin, printed_name = PrintedName},
            {Typed, Interface, Env}) ->
    {InputName, Offset} = Site = site(Session, Origin),
    Build = #{source_hash => <<>>, deps => [], session_offset => Offset,
              form_namespace => session_namespace(Session),
              site_namespace => printed_namespace(Session), units => Units#{Namespace => Unit},
              input_name => InputName},
    {ok, Unit, Beam} = ern_compile:compile(Namespace, Typed, Interface, Env, Build),
    {ok, #{interface := #interface{identities = Identities} = Compiled} = Chunk} =
        ern_interface:read(Beam),
    {module, Unit} = code:load_binary(Unit, atom_to_list(Unit), Beam),
    unit_loaded(Unit, Beam),
    record_uses(Unit, Beam, #checked{namespace = Namespace, interface = Compiled,
                                     binds = declarations, site = Site,
                                     printed_name = PrintedName},
                Chunk),
    Others = [Other || #interface{namespace = Found} = Other <- Interfaces, Found =/= Namespace],
    {Own, _} = redeclared(Compiled, Others),
    After = Session#session{interfaces = [case Found of
                                              Namespace -> Own;
                                              _ -> Held
                                          end || #interface{namespace = Found} = Held
                                                     <- Interfaces],
                            beams = Beams#{Namespace => Beam},
                            units = with_unit(Namespace, Unit, Units)},
    {Versioned, Moved} = versioned(Session, After, [Namespace]),
    named_versions(PrintedName, Moved),
    {Versioned, Identities, Moved}.

%% Report §11.2: each previous version a declaring input's new version made
%% of its types named as the input prints, with the version's number,
%% `$Input3$1` for the input typed third, PrintedName, which input_names/1
%% gives the printer. Moved: each type moved, by its new name.
named_versions(PrintedName, Moved) ->
    Named = #{[Segment] => PrintedName ++ "$" ++ Number
              || [Segment, _] := _ <- Moved,
                 [_, Number] <- [string:split(atom_to_list(Segment), "$", trailing)]},
    keep(version_names, maps:merge(kept(version_names, #{}), Named)).

%% Report §11.2: a declaring input that no longer compiles gone from scope,
%% each of its declarations the scope names, and the line that says so,
%% `viaFn went: input 3 no longer compiles`, as a type the new version
%% lacks is said to have gone. Its module and its interface stay, which a
%% function or a binding made before the reload may hold.
out_of_scope(#session{scope = Scope} = Session, [Segment], Origin) ->
    IsOwn = fun(_, [Found | _]) -> Found =:= Segment end,
    Own = #{Which => maps:filter(IsOwn, maps:get(Which, Scope, #{}))
            || Which <- [values, types, constructors]},
    Names = lists:usort([name_text(Key) || Which <- [types, values, constructors],
                                            Key := _ <- maps:get(Which, Own)]),
    Kept = #{Which => maps:filter(fun(Key, QualifiedName) -> not IsOwn(Key, QualifiedName) end,
                                  maps:get(Which, Scope, #{}))
             || Which <- [values, types, constructors]},
    {Session#session{scope = maps:merge(Scope, Kept)},
     unicode:characters_to_binary([listed(Names), " went: ", input_name(Origin),
                                   " no longer compiles"])}.

%% Report §11.2, §11.5: an input as its diagnostics name it, `input 3`, or
%% the startup file's path and the line it stands on.
input_name({typed, Name}) ->
    Name;
input_name(#startup_input{file = File, line = Line}) ->
    unicode:characters_to_binary([ern_build:shown(binary_to_list(File)), ":",
                                  integer_to_list(Line)]).

%%
%% Previous versions, report §11.2
%%

%% Report §11.2: each module the reload brought a version of counted, an
%% input of the session's among them (reached_inputs/2), and each type of
%% its previous version that the new one does not hold of one hash made the
%% previous version's wherever the session held it: renamed to the
%% version's namespace, `Counter$1`, in the session's own interfaces but
%% the new versions', and the previous versions', which the checker is
%% given beside the loaded modules' and which reach that version's unit. A
%% previous version's type whose hash the new version declares again is the
%% current version's again (returned/3), renamed back in the same places at
%% the same time. The session, and each type renamed to a previous version,
%% by its new name, with the name it had.
versioned(Before, After, Reloaded) ->
    {Renames, Previous, Units, Versions} =
        lists:foldl(fun(Namespace, Acc) -> previous_version(Before, After, Namespace, Acc) end,
                    {#{}, [], After#session.units, After#session.versions}, Reloaded),
    {Returns, Kept, Units1} = returned(After, Reloaded, Units),
    Moves = maps:merge(Renames, Returns),
    Renamed = fun(#interface{namespace = [Segment] = Namespace} = Interface) ->
                      case is_session_segment(Segment) andalso
                          not lists:member(Namespace, Reloaded) of
                          true -> renamed(Interface, Moves);
                          false -> Interface
                      end;
                 (Interface) ->
                      Interface
              end,
    Session = After#session{interfaces = lists:map(Renamed, After#session.interfaces),
                            previous = renamed(Kept ++ Previous, Moves),
                            units = Units1, versions = Versions},
    {Session, #{To => From || From := To <- Renames}}.

%% Report §11.2, §8.7: the previous versions' types whose hashes a reloaded
%% module's new version declares, each the current version's again, since
%% a type is its hash: each renamed back to the name the new version gives
%% it, Returns; the previous versions' interfaces without them, their
%% constructors and their members, Kept, one left with no type gone; and
%% the units without the namespace of an interface gone. One hash is one
%% canonical form, so the constructors are the same terms, and a process of
%% the previous version reads a message of the current one as its own.
returned(#session{interfaces = Interfaces, previous = PreviousInterfaces}, Reloaded, Units) ->
    Declared = maps:from_list([{Hash, QualifiedName}
                               || Namespace <- Reloaded,
                                  #interface{identities = Identities} = Interface
                                      <- [interface_of(Namespace, Interfaces)],
                                  QualifiedName <- declared_types(Interface),
                                  #{QualifiedName := Hash} <- [Identities]]),
    Returns = maps:from_list([{QualifiedName, Current}
                              || #interface{identities = Identities} = Interface
                                     <- PreviousInterfaces,
                                 QualifiedName <- declared_types(Interface),
                                 #{QualifiedName := Hash} <- [Identities],
                                 #{Hash := Current} <- [Declared]]),
    Without = [without_types(Interface, Returns) || Interface <- PreviousInterfaces],
    {Kept, Gone} = lists:partition(fun(Interface) -> declared_types(Interface) =/= [] end,
                                   Without),
    {Returns, Kept, maps:without([Namespace || #interface{namespace = Namespace} <- Gone], Units)}.

%% The types an interface declares, public and private, by their qualified
%% names.
declared_types(#interface{types = Types, private_types = PrivateTypes}) ->
    maps:keys(Types) ++ maps:keys(PrivateTypes).

%% An interface without the types Gone names, their constructors, which
%% their records hold, their members, and their hashes.
without_types(#interface{types = Types, private_types = PrivateTypes, values = Values,
                         identities = Identities} = Interface, Gone) ->
    IsGone = fun(QualifiedName, _) ->
                     is_map_key(QualifiedName, Gone)
                         orelse is_map_key(lists:droplast(QualifiedName), Gone)
             end,
    Interface#interface{types = maps:without(maps:keys(Gone), Types),
                        private_types = maps:without(maps:keys(Gone), PrivateTypes),
                        values = maps:filter(fun(Name, Scheme) -> not IsGone(Name, Scheme) end,
                                             Values),
                        identities = maps:filter(fun(Name, Hash) -> not IsGone(Name, Hash) end,
                                                 Identities)}.

%% A previous version's interface, of the types the new version does not
%% hold of one hash, their constructors and their members, under the
%% version's namespace; the types' renames, the unit it reaches, and the
%% module's version counted.
previous_version(Before, After, Namespace, {Renames, Previous, Units, Versions}) ->
    Version = maps:get(Namespace, Versions, 1),
    #interface{types = Types, private_types = PrivateTypes, values = Values,
               identities = Identities} = interface_of(Namespace, Before#session.interfaces),
    #interface{types = NewTypes, private_types = NewPrivateTypes, identities = NewIdentities} =
        interface_of(Namespace, After#session.interfaces),
    Held = maps:merge(NewTypes, NewPrivateTypes),
    IsGone = fun(QualifiedName, _) ->
                     not is_map_key(QualifiedName, Held)
                         orelse maps:get(QualifiedName, NewIdentities, none)
                                =/= maps:get(QualifiedName, Identities, none)
             end,
    Gone = maps:filter(IsGone, maps:merge(Types, PrivateTypes)),
    Versions1 = Versions#{Namespace => Version + 1},
    case maps:size(Gone) of
        0 ->
            {Renames, Previous, Units, Versions1};
        _ ->
            VersionNamespace = [list_to_atom(ern_namespace:text(Namespace) ++ "$"
                                             ++ integer_to_list(Version))],
            In = fun(QualifiedName) ->
                         VersionNamespace ++ lists:nthtail(length(Namespace), QualifiedName)
                 end,
            Members = maps:filter(fun(QualifiedName, _) ->
                                          is_map_key(lists:droplast(QualifiedName), Gone)
                                  end, Values),
            Moved = fun(Declared) ->
                            #{In(QualifiedName) => moved_constructors(TypeInfo, In)
                              || QualifiedName := TypeInfo <- maps:with(maps:keys(Declared), Gone)}
                    end,
            Moving = maps:merge(Gone, Members),
            Interface = #interface{namespace = VersionNamespace, types = Moved(Types),
                                   private_types = Moved(PrivateTypes),
                                   values = #{In(QualifiedName) => Scheme
                                              || QualifiedName := Scheme <- Members},
                                   identities = #{In(QualifiedName) => Hash
                                                  || QualifiedName := Hash <- Identities,
                                                     is_map_key(QualifiedName, Moving)}},
            {maps:merge(Renames, #{QualifiedName => In(QualifiedName)
                                   || QualifiedName := _ <- Gone}),
             [Interface | Previous], Units#{VersionNamespace => unit(Before, Namespace)},
             Versions1}
    end.

%% A type's constructors under the previous version's namespace, so that the
%% current version's constructors of one name are not taken for them.
moved_constructors(#type_info{constructors = Constructors} = TypeInfo, In) ->
    TypeInfo#type_info{
      constructors = [Constructor#constructor_info{qualified_name = In(QualifiedName)}
                      || #constructor_info{qualified_name = QualifiedName} = Constructor
                             <- Constructors]}.

interface_of(Namespace, Interfaces) ->
    lists:last([Interface || #interface{namespace = Found} = Interface <- Interfaces,
                             Found =:= Namespace]).

%% A term with each type Renames moves written under its new name, wherever
%% a type is named: a type, a type's own record and a constructor's type.
renamed({tcon, QualifiedName, Args}, Renames) ->
    {tcon, maps:get(QualifiedName, Renames, QualifiedName), renamed(Args, Renames)};
renamed(#type_info{qualified_name = QualifiedName} = TypeInfo, Renames) ->
    (renamed_elements(TypeInfo, Renames))#type_info{
      qualified_name = maps:get(QualifiedName, Renames, QualifiedName)};
renamed(#constructor_info{type_qualified_name = TypeName} = Constructor, Renames) ->
    (renamed_elements(Constructor, Renames))#constructor_info{
      type_qualified_name = maps:get(TypeName, Renames, TypeName)};
renamed(Tuple, Renames) when is_tuple(Tuple) ->
    renamed_elements(Tuple, Renames);
renamed(List, Renames) when is_list(List) ->
    [renamed(Element, Renames) || Element <- List];
renamed(Map, Renames) when is_map(Map) ->
    #{Key => renamed(Value, Renames) || Key := Value <- Map};
renamed(Term, _Renames) ->
    Term.

renamed_elements(Tuple, Renames) ->
    list_to_tuple([renamed(Element, Renames) || Element <- tuple_to_list(Tuple)]).

%% Report §11.2: the reload names each binding whose type it left of a
%% previous version, under the first such type the type names, `Counter.Msg
%% changed: the binding c is of its previous version, Counter$1.Msg`, and
%% `went` for a type the new version does not declare.
previous_lines(_Session, Previous) when map_size(Previous) =:= 0 ->
    [];
previous_lines(#session{scope = Scope} = Session, Previous) ->
    Held = [{Key, Renamed}
            || {Key, QualifiedName} <- lists:sort(maps:to_list(maps:get(values, Scope, #{}))),
               {ok, #scheme{type = Type}} <- [scheme(QualifiedName, Session)],
               [Renamed | _] <- [[Name || Name <- type_names(Type),
                                          is_map_key(Name, Previous)]]],
    TypeState = session_type_state(Session),
    [unicode:characters_to_binary(
       [type_name(Was, TypeState), changed_or_went(Was, Session), bindings_named(Names),
        counted(Names, " is", " are"), " of its previous version, ",
        type_name(Renamed, TypeState)])
     || Renamed <- lists:usort([Found || {_, Found} <- Held]),
        Was <- [maps:get(Renamed, Previous)],
        Names <- [[name_text(Key) || {Key, Found} <- Held, Found =:= Renamed]]].

%% Whether the module's current version declares a type of the name it had.
changed_or_went(QualifiedName, #session{interfaces = Interfaces}) ->
    #interface{types = Types, private_types = PrivateTypes} =
        interface_of(lists:droplast(QualifiedName), Interfaces),
    case is_map_key(QualifiedName, Types) orelse is_map_key(QualifiedName, PrivateTypes) of
        true -> " changed: ";
        false -> " went: "
    end.

%% Report §11.2: a type error that names a type of a previous version says
%% so in its help, `Counter$1.Msg is of a previous version of Counter, which
%% a reload replaced`, after the help the checker gave it, where it gave one.
%% A session with no previous version has none to name, the session a
%% command checks a fragment under among them (fields/1), which has no
%% prelude to make a type state from.
previous_hinted(#session{previous = []}, Diagnostic) ->
    Diagnostic;
previous_hinted(#session{previous = Previous} = Session,
                #diagnostic{message = Message, labels = Labels, help = Help} = Diagnostic) ->
    Given = case Help of
                undefined -> [];
                _ -> [Help]
            end,
    %% the parts apart, so that a name at the end of one is whole
    Text = unicode:characters_to_binary(
             lists:join("\n", [Message] ++ [Label || {_, Label} <- Labels] ++ Given)),
    TypeState = session_type_state(Session),
    Named = [Shown
             || #interface{types = Types, private_types = PrivateTypes} <- Previous,
                QualifiedName <- maps:keys(Types) ++ maps:keys(PrivateTypes),
                Shown <- [type_name(QualifiedName, TypeState)],
                is_named(Text, unicode:characters_to_binary(Shown))],
    case lists:sort(Named) of
        [] ->
            Diagnostic;
        [Shown | _] ->
            %% the version's namespace is the name but its last segment, and
            %% the module's or the input's the version's but its number
            [Version, _] = string:split(Shown, ".", trailing),
            [Module, _] = string:split(Version, "$", trailing),
            Said = [Shown, " is of a previous version of ", Module, ", which a reload replaced"],
            Diagnostic#diagnostic{help = lists:flatten(lists:join("; ", Given ++ [Said]))}
    end.

%% Report §11.2: a type's name as the session prints it, a module's type
%% qualified, the session's own by its name, and one a later declaration
%% shadowed, or a previous version's of an input's, under the input.
type_name(QualifiedName, TypeState) ->
    ern_types:format({tcon, QualifiedName, []}, TypeState).

%% Whether Text names Name whole, where it stands no name going on before
%% it or after it: `C$1.Msg` does not name `C$1.M`.
is_named(Text, Name) ->
    lists:any(fun({Start, Length}) ->
                      not goes_on(Text, Start - 1, -1) andalso not goes_on(Text, Start + Length, 1)
              end, binary:matches(Text, Name)).

%% Whether a name goes on at Position, read in Direction away from it: a
%% name's character stands there, or a dot with one beyond it.
goes_on(Text, Position, Direction) ->
    case byte_at(Text, Position) of
        $. -> is_name_byte(byte_at(Text, Position + Direction));
        Byte -> is_name_byte(Byte)
    end.

byte_at(Text, Position) when Position >= 0, Position < byte_size(Text) ->
    binary:at(Text, Position);
byte_at(_, _) ->
    none.

is_name_byte(Byte) when is_integer(Byte) ->
    (Byte >= $a andalso Byte =< $z) orelse (Byte >= $A andalso Byte =< $Z)
        orelse (Byte >= $0 andalso Byte =< $9) orelse Byte =:= $_ orelse Byte =:= $$;
is_name_byte(none) ->
    false.

%% The declared types a type is made of, each by its qualified name.
type_names({tcon, QualifiedName, Args}) ->
    [QualifiedName | lists:append([type_names(Arg) || Arg <- Args])];
type_names({ttuple, Types}) ->
    lists:append([type_names(Type) || Type <- Types]);
type_names({tfn, Args, Effect, Result}) ->
    lists:append([type_names(Type) || Type <- Args ++ [Result]]) ++ effect_names(Effect);
type_names({tvar, _}) ->
    [].

effect_names(none) -> [];
effect_names(Type) -> type_names(Type).

%% Processes by their spawn sites (§6.9) and bindings by their names, the
%% last two of a list joined by `and`.
processes_at(Sites) ->
    [counted(Sites, "the process", "the processes"), " spawned at ", listed(Sites)].

bindings_named(Names) ->
    [counted(Names, "the binding", "the bindings"), " ", listed(Names)].

counted([_], One, _) -> One;
counted(_, _, Many) -> Many.

listed([Item]) -> Item;
listed(Items) -> [lists:join(", ", lists:droplast(Items)), " and ", lists:last(Items)].

%% A module whose source the session expects under the source root, which
%% the root does not hold, is named, since `:reload` cannot compile it
%% again: one it compiled from its source, and one of the program it was
%% started over; a library's, loaded from its compiled form on the load
%% path, has its source elsewhere, and is not.
sourceless(_Session, []) ->
    [];
sourceless(#session{source_root = SourceRoot}, Names) ->
    Text = lists:join(", ", [ern_namespace:text(Namespace) || Namespace <- Names]),
    [unicode:characters_to_binary(["the source root ", ern_build:shown(SourceRoot),
                                   " holds no source of ", Text])].

%% Report §11.2: a module compiled against the modules the session has
%% loaded, as Interfaces holds them, a dependency `:load` compiled in
%% memory among them, each called as the unit Units names, its spawn sites
%% named under SiteNamespace (site_namespace/2), or its own namespace where
%% `own`.
compile_source(#session{source_root = SourceRoot} = Session, File, Interfaces, Units,
               SiteNamespace) ->
    case ern_build:compile_source(File, SourceRoot, load_path(Session), Interfaces, Units,
                                  SiteNamespace) of
        {ok, Namespace, Beam, Hash} ->
            {ok, Namespace, Beam, Hash};
        {refused, Text} ->
            {error, unicode:characters_to_binary([Text, "\n"])};
        {error, FailedFile, Diagnostics} ->
            {error, diagnosed(Session, FailedFile, Diagnostics)}
    end.

%% Report §11.5: a source's diagnostics as the build renders them, the file
%% named from the operator's working directory, its source read where the
%% operator's files are.
diagnosed(Session, File, Diagnostics) ->
    SourceText = case source_read(Session, File) of
                     {ok, Bytes} -> Bytes;
                     {error, _} -> <<>>
                 end,
    Shown = ern_build:read_through(source_access(Session), fun() -> ern_build:shown(File) end),
    unicode:characters_to_binary([ern_diagnostic:format(Shown, SourceText, Diagnostic)
                                  || Diagnostic <- Diagnostics]).

%% Report §11.2, §11.1, §4.2: where a compiled module is found by its
%% namespace, one `:load` names or one a module uses: the source root, which
%% is where `ern build` writes by default and which stands first at the
%% root, and then the load path, as `ern build` and `ern run` in the same
%% tree find it; the source root is the build root of a module the session
%% compiles (ern_build:dependency_interfaces/5). For a session attached to
%% its node, the node's load path alone, since the source root is another
%% node's (§11.2 *The attached shell*).
load_path(#session{load_path = LoadPath, attached = true}) ->
    LoadPath;
load_path(#session{load_path = LoadPath, source_root = SourceRoot}) ->
    lists:uniq([filename:absname(SourceRoot) | LoadPath]).

source_of(#session{source_root = SourceRoot} = Session, Namespace) ->
    File = filename:join(SourceRoot, ern_namespace:module_path(Namespace) ++ ".ern"),
    case is_source(Session, File) of
        true -> {ok, File};
        false -> none
    end.

%% Report §11.2, §11.8: a module's compiled form, the first under the
%% source root and then on the load path (load_path/1), or none; one that
%% cannot be read is refused with the file and the host's
%% reason, as the build refuses a file it cannot read, one that holds
%% another module as `ern run` refuses it, and one whose code the host
%% will not load as `ern run` refuses a dependency so (§11), the file
%% named from the working directory (§11.5).
compiled_of(Session, Namespace) ->
    Relative = ern_namespace:module_path(Namespace) ++ ".erc",
    case [Candidate || Dir <- load_path(Session), Candidate <- [filename:join(Dir, Relative)],
                       filelib:is_regular(Candidate)] of
        [File | _] ->
            case file:read_file(File) of
                {ok, Beam} ->
                    case ern_interface:read(Beam) of
                        {ok, #{interface := #interface{namespace = Namespace},
                               source_hash := Hash}} ->
                            case ern_chunk:is_loadable(ern_namespace:erlang_module(Namespace),
                                                       Beam) of
                                true ->
                                    {ok, File, Beam, Hash};
                                false ->
                                    {error, unicode:characters_to_binary(
                                              [ern_build:shown(File),
                                               ": not a compiled module"])}
                            end;
                        {ok, #{interface := #interface{namespace = Held}}} ->
                            {error, unicode:characters_to_binary(
                                      ern_build:held_another(File, Held, Namespace, rebuild))};
                        {error, _} ->
                            none
                    end;
                {error, Error} ->
                    {error, unicode:characters_to_binary([ern_build:bytes_text(File), ": ",
                                                          file:format_error(Error)])}
            end;
        [] ->
            none
    end.

source_hash(Session, File) ->
    case source_read(Session, File) of
        {ok, SourceText} -> {ok, crypto:hash(sha256, SourceText)};
        {error, _} -> none
    end.

%%
%% The source root, report §11.2
%%

%% Report §11.2: the session's source root is its operator's, whose files
%% its shell's local half holds on the shell's own node and reads for it,
%% shipping a source as text: the access a load's work reads them by
%% (ern_build:read_through/2), each read a call to the local half, and the
%% local half's working directory, which a file is named from (§11.5). A
%% plain shell's local half is on the session's own node, and its files
%% are read the same way.
source_access(#session{working_directory = Cwd} = Session) ->
    #{read => fun(File) -> source_read(Session, File) end,
      is_regular => fun(File) -> is_source(Session, File) end,
      is_directory => fun(Dir) -> is_source_directory(Session, Dir) end,
      entries => fun(Dir) -> source_entries(Session, Dir) end,
      working_directory => Cwd}.

%% A source's bytes as the local half reads them, as `Fs.read` answers, or
%% the reason it could not be read.
source_read(#session{local = Local}, File) ->
    case asked(Local, fun(Reply) -> {'Read', path(File), Reply} end) of
        {'Right', Bytes} -> {ok, Bytes};
        {'Left', Error} -> {error, file_error(Error)}
    end.

%% Whether a regular file is there, as `Fs.stat` answers, its links
%% followed. One the stat cannot tell of, refused or at a full table of
%% the shell's own node (report §12.5), is taken as there, so that its
%% read says why it could not be read rather than that no module is there.
is_source(#session{local = Local}, File) ->
    case asked(Local, fun(Reply) -> {'Stat', path(File), Reply} end) of
        {'Right', {'Entry', _, _, _, 'File', _, _}} -> true;
        {'Right', _} -> false;
        {'Left', 'NotFound'} -> false;
        {'Left', 'NotAFile'} -> false;
        {'Left', _} -> true
    end.

%% Report §4.2: whether a directory is there, as `Fs.stat` answers, by
%% which the build finds the namespaces a module's names may resolve in.
is_source_directory(#session{local = Local}, Dir) ->
    case asked(Local, fun(Reply) -> {'Stat', path(Dir), Reply} end) of
        {'Right', {'Entry', _, _, _, 'Directory', _, _}} -> true;
        _ -> false
    end.

%% Report §4.2, §11.1: a directory's files and directories, each by its
%% name, as `Fs.list` answers: a link read as the file it leads to, and a
%% link to a directory passed over, as a build passes it over; none where
%% the directory cannot be listed.
source_entries(#session{local = Local} = Session, Dir) ->
    case asked(Local, fun(Reply) -> {'ListEntries', path(Dir), Reply} end) of
        {'Right', Entries} ->
            [{Name, Kind} || {'Entry', {'Path', Path}, _, _, EntryKind, _, _} <- Entries,
                             Name <- [filename:basename(unicode:characters_to_list(Path))],
                             Kind <- entry_kind(Session, filename:join(Dir, Name), EntryKind)];
        _ ->
            []
    end.

entry_kind(_Session, _Path, 'File') -> [file];
entry_kind(_Session, _Path, 'Directory') -> [directory];
entry_kind(Session, Path, 'Link') ->
    case is_source(Session, Path) of
        true -> [file];
        false -> []
    end;
entry_kind(_Session, _Path, _) -> [].

%% Report §11.2: the local half's answer to Request, a call it answers
%% once the file system has, or `Left(Timeout)`: it waits as long as the
%% local half waits for its file system and a dial beside it, the carrier's
%% longest wait to reach the shell's own node (§8.7).
asked(undefined, _Request) ->
    %% no session, whose front end's copy is empty, has no source root
    {'Left', 'NotFound'};
asked(Local, Request) ->
    case ern_rt:call(Local, Request, ?FILE_MS + ern_carrier:dial_ms()) of
        {'Some', Answer} -> Answer;
        'None' -> {'Left', 'Timeout'}
    end.

path(File) ->
    {'Path', unicode:characters_to_binary(File)}.

%% An Io.Error as the build gives a file's reason, the host's where it has
%% one.
file_error('NotFound') -> enoent;
file_error('Denied') -> eacces;
file_error('NotAFile') -> {text, "is not a regular file"};
file_error('Invalid') -> einval;
file_error('Timeout') -> {text, "the shell's own node did not answer"};
file_error({'Other', Text}) -> {text, unicode:characters_to_list(Text)};
file_error(Error) when is_atom(Error) -> {text, atom_to_list(Error)}.

%% The toolchain's version text (ern_release), which the start line names
%% (report §11.2).
-spec version() -> binary().
version() ->
    list_to_binary(ern_release:version_text()).

%% The screen writes to the job's own standard output, ern_out's, whose
%% stream that can no longer be written ends the shell through its run
%% (report §12.1): the program's standard output is the screen's, so a
%% screen that printed through it would print to itself.
-spec write(binary()) -> 'Unit'.
write(Text) ->
    file:write(standard_io, unicode:characters_to_binary(Text)),
    'Unit'.

%% Report §11.2, §12.1: the runner binds the sinks of a shell's own node to
%% the screen of the session its local half serves, which the local half
%% names, by its process, once the session has one, so that what the node's
%% own processes write is shown there, a plain shell's program among them,
%% sent as the session's sinks send it (sink/1); what is written before
%% then goes straight out, and so does what is written once an attached
%% session has ended, whose screen has gone with it or with its node, which
%% the end's drain then asks nothing of (flush_screen/0). A persistent term,
%% put once and taken away once in the shell's life.
-spec node_screen({'Some', pid()} | 'None') -> 'Unit'.
node_screen({'Some', Screen}) ->
    persistent_term:put({?MODULE, screen}, Screen),
    'Unit';
node_screen('None') ->
    _ = persistent_term:erase({?MODULE, screen}),
    'Unit'.

-spec to_screen(binary()) -> ok | {error, term()}.
to_screen(Bytes) ->
    case persistent_term:get({?MODULE, screen}, undefined) of
        undefined -> file:write(standard_io, Bytes);
        Screen -> send_wrote(Screen, Bytes)
    end.

%% Report §8.6, §11.2: what the screen has been sent, written before the
%% program ends, since a program the session ran may write while the end
%% waits for its subscribers, after the session has ended, and the end's
%% own lines are said then; the screen answers Flush once it has written
%% what came before it, which the sinks put in its mailbox as standard
%% output and standard error took it (sink/1). The runner asks it, which is
%% no program's process, by the screen's process, and under a monitor, as
%% ern_rt:say/2 asks standard error's process, since a screen that has
%% ended, with the program among the ways, has nothing left to write.
-spec flush_screen() -> ok.
flush_screen() ->
    case persistent_term:get({?MODULE, screen}, undefined) of
        undefined ->
            ok;
        Screen ->
            Reply = erlang:monitor(process, Screen, [{alias, demonitor}]),
            Screen ! {'Flush', {Reply, erlang:self()}},
            receive
                {Reply, answered, _} -> erlang:demonitor(Reply, [flush]), ok;
                {'DOWN', Reply, process, _, _} -> ok
            end
    end.

%% Report §8.7, Appendix H: a name the session binds is a binding, whose
%% definition is the input that computed it.
entry_hash(Namespace, #interface{identities = Identities}) ->
    maps:get(Namespace ++ [?ENTRY], Identities).

%% Report §11.2: whether the input leaves `it` as it was, its value's type
%% not being determined by the input itself: an expression's, or the type
%% of `e` in a `let p <- e` that shows a `Left` or a `None`, as the
%% session asks only where it shows one.
-spec leaves_it_unchanged(#checked{}) -> boolean().
leaves_it_unchanged(#checked{binds = it, type = Type, env = Env}) -> is_open(Type, Env);
leaves_it_unchanged(#checked{binds = {arrow, _, _, _}, type = Type, env = Env}) ->
    is_open(Type, Env);
leaves_it_unchanged(#checked{}) -> false.

%% Report §11.2: a value whose type its own input did not settle is
%% printed but not bound, since a scheme with a variable of that input's
%% type state means nothing to the inputs after it. A named binding is
%% refused outright when it is checked; `it` is the one this can still
%% reach, and `declared/1` says that it was not bound.
is_open(Type, Env) ->
    TypeState = ern_typecheck:type_state(Env),
    ern_types:free_variables(ern_types:substitute(Type, TypeState), TypeState) =/= [].

%% Report §11.2: the names a `let` bound, each with its value and its
%% scheme, held by a module of their own, a getter for each, which needs the
%% session's modules whose types their types name and whose functions their
%% values hold; each a binding of the input's entry's hash under the
%% session's namespace, Holding giving that namespace and the hash, the
%% holder's own namespace the session's to give. What the session joins, the holder's interface, the
%% holder, whose binder the input's process is, and the session with the
%% holder's namespace given.
holder_bound(Bindings, {SessionNamespace, Hash}, Session) ->
    {HolderNamespace, Session1} = given_holder(Session),
    ErlangModule = ern_namespace:erlang_module(HolderNamespace),
    %% report §11.1: the holder is a unit, its getters named by their
    %% number, each binding's value kept under its unit and its getter
    Numbered = lists:enumerate(Bindings),
    Names = [Name || {Name, _, _} <- Bindings],
    Interface = #interface{namespace = HolderNamespace,
                           values = #{HolderNamespace ++ [Name] => Scheme
                                      || {Name, _, Scheme} <- Bindings},
                           lets = [HolderNamespace ++ [Name] || Name <- Names],
                           identities = #{HolderNamespace ++ [Name] => Hash || Name <- Names},
                           positions = #{HolderNamespace ++ [Name] => Position
                                         || {Position, {Name, _, _}} <- Numbered}},
    Keys = [{ErlangModule, ern_emitter:function_name(Position)} || {Position, _} <- Numbered],
    %% report Appendix H, §8.7: each by its identity as a form names it, its
    %% name under the session's one namespace, whatever holder holds it
    Code = [{SessionNamespace ++ [Name], {binding, Hash, Key}}
            || {Key, {Name, _, _}} <- lists:zip(Keys, Bindings)],
    %% report §11.2, §7.4: compiled before anything of it is recorded, so
    %% that a full table of processes, which leaves the compiler no room,
    %% leaves the session as it was (collect/3)
    Beam = holder(ErlangModule, Names, Code),
    unit_recorded(ErlangModule,
                  #session_unit{namespace = HolderNamespace, keys = Keys,
                                names = Interface#interface.lets,
                                needs = lists:usort(mentions(Interface, HolderNamespace)
                                                    ++ held_functions([Value
                                                                       || {_, Value, _}
                                                                              <- Bindings],
                                                                      []))}),
    [persistent_term:put(Key, Value) || {Key, {_, Value, _}} <- lists:zip(Keys, Bindings)],
    {module, ErlangModule} = code:load_binary(ErlangModule, atom_to_list(ErlangModule), Beam),
    holder_loaded(ErlangModule, Beam),
    {#scoped{interface = Interface}, HolderNamespace, Session1}.

%% Report §11.2: the session's modules whose functions a term holds, a
%% fun's own and those the funs it captured hold, so that a holder of a
%% function a session module made needs that module while it lives.
held_functions(Fun, Acc) when is_function(Fun) ->
    {module, Module} = erlang:fun_info(Fun, module),
    Held = case is_session_module(Module) of
               true -> [Module | Acc];
               false -> Acc
           end,
    case erlang:fun_info(Fun, env) of
        {env, Captured} -> held_functions(Captured, Held);
        _ -> Held
    end;
held_functions(Tuple, Acc) when is_tuple(Tuple) ->
    held_functions(tuple_to_list(Tuple), Acc);
held_functions([Head | Rest], Acc) ->
    held_functions(Rest, held_functions(Head, Acc));
held_functions(Map, Acc) when is_map(Map) ->
    held_functions(maps:to_list(Map), Acc);
held_functions(_, Acc) ->
    Acc.

%% A bound name's scheme: a generalized `let`'s own, or its type alone.
binding_scheme(#scheme{} = Scheme, _TypeState) -> Scheme;
binding_scheme(Type, TypeState) -> ern_types:monomorphic(ern_types:substitute(Type, TypeState)).

%% Report §11.2: the session after an input has answered, its value and
%% what it bound, or its fault: what it bound bound by the session, in the
%% session's own process, and joined, its binder recorded, and then what
%% nothing reaches any more let go, the input's own unit where nothing
%% keeps it, and the process of each input that bound a name the scope
%% names no more (collected/1); and the session's row written, once an
%% input. The session alone writes its rows and binds what its inputs
%% bound, so that two processes never write one row.
-spec collect(#session{}) -> #session{}.
collect(Session) ->
    collect_detached(),
    keep_session(collected(Session)).

%% Report §11.2, §7.4: an answer whose binding a full table of processes
%% leaves no room to make, its holder's compiler unstarted, answers the
%% input's fault, `error:system_limit`, the session as it was and its
%% binder let go, so that what the input opened ends with it as a faulted
%% input's does.
-spec collect(#session{}, #bound{}, #value{}) -> {'Right', #session{}} | {'Left', binary()}.
collect(Session, #bound{binding = Binding, binder = Binder}, #value{term = Value}) ->
    collect_detached(),
    try bound_value(Binding, Value, Session) of
        {Scoped, Holder, Session1} ->
            Binder =:= none orelse keep(binders, (binders())#{Holder => Binder}),
            {'Right', keep_session(collected(joined_bound(Session1, Scoped)))}
    catch
        error:system_limit ->
            Binder =:= none orelse (Binder ! {?MODULE, let_go}),
            {'Left', ern_rt:host_cause(error, system_limit)}
    end.

%% Report §11.2: the session with what an input bound: what it declared,
%% its compiled module kept for `:doc` and the name it prints with, the
%% names its holder holds, or the value its unit holds, `it`.
joined_bound(Session, #scoped{interface = none}) ->
    Session;
joined_bound(Session, #scoped{interface = Interface, declared = none}) ->
    joined(Session, Interface);
joined_bound(#session{beams = Beams, input_names = InputNames} = Session,
             #scoped{interface = Interface, declared = {Namespace, Beam, PrintedName}}) ->
    joined(Session#session{beams = Beams#{Namespace => Beam},
                           input_names = InputNames#{Namespace => PrintedName}},
           Interface).

%% Report §11.2: the session's units are the inputs it keeps while it runs,
%% each that declared or built a function value (is_kept/2), the inputs
%% whose units hold the value `it` names, and the holders of what `let`s
%% bound. A unit's values live while the session can reach it, and its
%% code too, or while the session keeps it: what reaches a unit is a name
%% in the session's scope, and a unit the session keeps, whose code may read
%% it, and, from either, what that unit needs. A unit none of this reaches
%% is let go: its values, its code, its interface, and its number, which a
%% later input or holder takes (report §2.3); no process runs its code then,
%% so it is purged at once, and then its values let go. A unit the session
%% keeps whose values nothing reaches keeps its code, its values let go.
%%
%% The collection reads only the units it may let go, those that hold a
%% value or that the session does not keep (held_units/0), each reached by
%% a name of its own in scope or by a unit the session keeps
%% (kept_needs/0), and not every unit and every name, so that its cost
%% follows what an input made and not what the session holds. The session
%% collects in its own process, once an input has answered (collect/1,
%% collect/3), so that an input killed while it runs has let nothing go
%% that the session still names; the binders go by the same reading
%% (leaving/2).
collected(#session{interfaces = Interfaces, scope = Scope} = Session) ->
    Values = maps:get(values, Scope, #{}),
    Units = #{ErlangModule => Unit || ErlangModule := _ <- held_units(),
                                      #session_unit{} = Unit <- [unit(ErlangModule)]},
    Named = #{ErlangModule => true
              || ErlangModule := #session_unit{namespace = Namespace, names = Names} <- Units,
                 lists:any(fun(Name) -> is_named(Name, Namespace, Values) end, Names)},
    leaving(Named, Units),
    Reached = reached(maps:keys(Named) ++ maps:keys(kept_needs()), Units, #{}),
    Dead = [ErlangModule || ErlangModule := #session_unit{kept = false} <- Units,
                            not is_map_key(ErlangModule, Reached)],
    Unvalued = [ErlangModule || ErlangModule := #session_unit{kept = true} <- Units,
                                not is_map_key(ErlangModule, Reached)],
    case Dead ++ Unvalued of
        [] ->
            Session;
        Gone ->
            lists:foreach(fun unload/1, Dead),
            [persistent_term:erase(Key)
             || ErlangModule <- Gone, Key <- (maps:get(ErlangModule, Units))#session_unit.keys],
            [keep({unit, ErlangModule}, (maps:get(ErlangModule, Units))#session_unit{keys = [],
                                                                                    names = []})
             || ErlangModule <- Unvalued],
            forget_units(Dead),
            keep(held_units, maps:without(Unvalued, held_units())),
            Namespaces = [(maps:get(ErlangModule, Units))#session_unit.namespace
                          || ErlangModule <- Gone],
            Session#session{interfaces = [Interface
                                          || #interface{namespace = Namespace} = Interface
                                                 <- Interfaces,
                                             not lists:member(Namespace, Namespaces)],
                            free = Session#session.free
                                ++ [(maps:get(ErlangModule, Units))#session_unit.namespace
                                    || ErlangModule <- Dead]}
    end.

%% Whether the scope's name of a unit's value, Name of the unit's
%% Namespace, still reaches it.
is_named(Name, Namespace, Values) ->
    maps:get(value_key(Namespace, Name), Values, none) =:= Name.

%% The session's units the given ones reach, through what each of Units
%% needs.
reached([], _Units, Live) ->
    Live;
reached([ErlangModule | Rest], Units, Live) when is_map_key(ErlangModule, Live) ->
    reached(Rest, Units, Live);
reached([ErlangModule | Rest], Units, Live) ->
    Needs = case Units of
                #{ErlangModule := #session_unit{needs = Needed}} -> Needed;
                _ -> []
            end,
    reached(Needs ++ Rest, Units, Live#{ErlangModule => true}).

%% The session's modules whose names a term mentions, but its own: a type an
%% interface names is such a mention.
mentions(Term, [Own]) ->
    lists:usort([ern_namespace:erlang_module([Atom]) || Atom <- atoms(Term, []), Atom =/= Own,
                                                      is_session_segment(Atom)]).

atoms(Atom, Acc) when is_atom(Atom) -> [Atom | Acc];
atoms(Tuple, Acc) when is_tuple(Tuple) -> atoms(tuple_to_list(Tuple), Acc);
atoms([Head | Rest], Acc) -> atoms(Rest, atoms(Head, Acc));
atoms(Map, Acc) when is_map(Map) -> atoms(maps:to_list(Map), Acc);
atoms(_, Acc) -> Acc.

%% Whether a namespace segment is a holder's, `$Bindings<s>_<n>`.
is_holder_segment(Segment) ->
    lists:prefix("$Bindings", atom_to_list(Segment)).

%% Whether a namespace is one a session made, an input's or a holder's, or
%% a previous version of a declaring input's (report §2.3, §11.2).
is_session_namespace([Segment | _]) -> is_session_segment(Segment);
is_session_namespace(_) -> false.

%% Whether a namespace segment is one the session made (report §2.3).
is_session_segment(Segment) ->
    case atom_to_list(Segment) of
        "$Bindings" ++ _ -> true;
        "$Input" ++ _ -> true;
        _ -> false
    end.

%% Whether an Erlang module is a session module, its name the one
%% ern_namespace gives a holder's or an input's namespace.
is_session_module(ErlangModule) ->
    Name = atom_to_list(ErlangModule),
    lists:any(fun(Segment) -> lists:prefix(ern_namespace:erlang_module_text([Segment]), Name) end,
              ['$Bindings', '$Input']).

%% Report §11.2: a unit of the session's, its row by its Erlang name, or
%% none; and every unit of the session's, by its name, which its detach
%% reads.
unit(ErlangModule) ->
    kept({unit, ErlangModule}, none).

units() ->
    #{ErlangModule => Unit
      || {{_, {unit, ErlangModule}}, Unit} <- ets:match_object(?MODULE, {{session_root(),
                                                                          {unit, '_'}}, '_'})}.

%% Report §11.2: the units the collection may let go, each that holds a
%% value or that the session does not keep; and of them, those a unit the
%% session keeps needs, which it never lets go while the session runs, its
%% code reading them (collected/1). Both are rows of their own, small, so
%% that a collection reads what it may let go and not every unit.
held_units() ->
    kept(held_units, #{}).

kept_needs() ->
    kept(kept_needs, #{}).

%% A unit recorded, among those the collection may let go where it is
%% one, and, where the session keeps it, what it needs of them among those
%% no collection lets go.
unit_recorded(ErlangModule, #session_unit{keys = Keys, kept = Kept, needs = Needs} = Unit) ->
    keep({unit, ErlangModule}, Unit),
    Held = case Kept andalso Keys =:= [] of
               true -> held_units();
               false -> keep(held_units, (held_units())#{ErlangModule => true})
           end,
    kept_need(Kept, Needs, Held).

kept_need(true, Needs, Held) ->
    case [Need || Need <- Needs, is_map_key(Need, Held)] of
        [] -> ok;
        More -> keep(kept_needs, maps:merge(kept_needs(), maps:from_keys(More, true)))
    end;
kept_need(false, _Needs, _Held) ->
    ok.

%% A unit needing, beside what it needed, More.
needs_added(ErlangModule, More) ->
    case unit(ErlangModule) of
        #session_unit{needs = Needs, kept = Kept} = Unit ->
            keep({unit, ErlangModule}, Unit#session_unit{needs = lists:usort(Needs ++ More)}),
            kept_need(Kept, More, held_units()),
            ok;
        none ->
            ok
    end.

%% The units let go: each row, its place among those the collection reads,
%% and an input's name, which goes with it.
forget_units(ErlangModules) ->
    lists:foreach(fun(ErlangModule) ->
                      forgotten({unit, ErlangModule}),
                      ets:delete(?MODULE, {input_name, ErlangModule})
                  end, ErlangModules),
    ErlangModules =:= [] orelse keep(held_units, maps:without(ErlangModules, held_units())),
    ok.

%% Report §11.2, Appendix E.21: processes of the session's own, which
%% Process.live() leaves out (ern_rt:own/1), and which the session's end
%% ends (detach/0): the session, its screen, its reader, the root of an
%% attached session's chain, and the local half and its reader of lines on
%% the shell's own node, each recorded under its session's root.
-spec own([pid()]) -> 'Unit'.
own(Processes) ->
    keep(own, Processes ++ kept(own, [])),
    ern_rt:own(Processes).

%% Report §11.2: the session detached from its node, by `:quit`, `C-d` or
%% the end of its input, or by its local half's end or loss, as it leaves,
%% and at any other end of the session's, a fault among them, by the root
%% of its chain, which learns of the end (shell.ern's `attached`).
%%
%% The session's own processes are ended, its screen, its reader and an
%% input that runs, but the calling process; each input that bound a name
%% is let go; the evaluators of its loads that live on, and what they and
%% the evaluators that ended started, and every process an input spawned,
%% are left to the node, writing to the node's standard output and
%% standard error from then on, the rows of the session's screen dropped,
%% each evaluator's among them.
%%
%% Its units that declare a function or build a function value are kept
%% for the node's life, with what they need (kept_for_life/1); and the rest
%% let go as an input's is, but one a process still runs, kept while it
%% does (released/4), under the node's lock, since every session's
%% collection reads what it leaves (collect_detached/0), and its address
%% leaves the node's, so that no reload is said to it (reload_said/2). Its
%% rows go with it, so that a second detach finds nothing to do.
-spec detach() -> 'Unit'.
detach() ->
    Root = session_root(),
    Binders = maps:values(binders()) ++ [Pid || {Pid, _} <- going()],
    lists:foreach(fun(Pid) -> Pid ! {?MODULE, let_go} end, Binders),
    [ern_rt:killed(Pid, {ern, killed}) || Pid <- [kept(input, none) | kept(own, [])],
                                          is_pid(Pid), Pid =/= self(), Pid =/= Root,
                                          not lists:member(Pid, Binders)],
    'Unit' = ern_rt:drop_screens(sink(kept(screen, none))),
    Units = units(),
    Uses = maps:without(maps:keys(kept_for_life(Units)), Units),
    node_locked(fun() ->
                    node_keep(sessions, maps:remove(Root, node_kept(sessions, #{}))),
                    case released(in_users_order(Uses), Uses, #{}, []) of
                        [] -> ok;
                        Remaining ->
                            node_keep(detached, (node_kept(detached, #{}))#{Root => maps:with(
                                                                                       Remaining,
                                                                                       Uses)})
                    end
                end),
    true = ets:match_delete(?MODULE, {{Root, '_'}, '_'}),
    'Unit'.

%% Report §11.2: the session's units the node keeps for its life once the
%% session has detached, as it keeps a load's: each that declares a
%% function or builds a function value (lasting/3), its code, its values
%% and its name, which a spawn site of it reads, and every unit one of
%% them needs, its code calling it or its forms or its interface naming
%% its definitions, and onward. The values of such a unit that none of
%% them needs are let go here, since no code that stays reads them, `it`
%% the last expression gave among them.
kept_for_life(Units) ->
    Needed = reached(lists:append([Needs || _ := #session_unit{lasting = true, needs = Needs}
                                                <- Units]),
                     Units, #{}),
    Lasting = [ErlangModule || ErlangModule := #session_unit{lasting = true} <- Units],
    [persistent_term:erase(Key)
     || ErlangModule <- Lasting, not is_map_key(ErlangModule, Needed),
        Key <- (maps:get(ErlangModule, Units))#session_unit.keys],
    maps:merge(Needed, maps:from_keys(Lasting, true)).

%% Report §11.2: each of a session's units let go once the session has
%% ended, a unit after every unit that uses it: deleted and purged where no
%% process runs it, its values, its code and its name, which a spawn site
%% of it reads, gone with it; and where one does, left as the old code it
%% then is, and each unit it uses kept as it is, since that code calls
%% them. The units that remain, to purge at a later collection of any
%% session's (collect_detached/0). A unit of which a process may hold a
%% function stays for the node's life and comes to none of this
%% (kept_for_life/1).
released([], _Uses, _Kept, Remaining) ->
    Remaining;
released([ErlangModule | Rest], Uses, Kept, Remaining) when is_map_key(ErlangModule, Kept) ->
    released(Rest, Uses, Kept, [ErlangModule | Remaining]);
released([ErlangModule | Rest], Uses, Kept, Remaining) ->
    _ = erlang:module_loaded(ErlangModule) andalso code:delete(ErlangModule),
    case code:soft_purge(ErlangModule) of
        true ->
            %% its rows of the code table, which name its definitions while
            %% a process runs its old code, go once none does
            ern_code:unloaded(ErlangModule),
            #session_unit{keys = Keys} = maps:get(ErlangModule, Uses),
            lists:foreach(fun persistent_term:erase/1, Keys),
            ets:delete(?MODULE, {input_name, ErlangModule}),
            released(Rest, Uses, Kept, Remaining);
        false ->
            #session_unit{needs = Needs} = maps:get(ErlangModule, Uses),
            released(Rest, Uses, reached(Needs, Uses, Kept), [ErlangModule | Remaining])
    end.

%% The session's units, each after every unit that needs it: inputs need
%% only earlier inputs and holders, so the needs hold no cycle.
in_users_order(Uses) ->
    Needed = lists:append([Needs || _ := #session_unit{needs = Needs} <- Uses]),
    case [ErlangModule || ErlangModule := _ <- Uses, not lists:member(ErlangModule, Needed)] of
        [] -> maps:keys(Uses);
        Unneeded -> Unneeded ++ in_users_order(maps:without(Unneeded, Uses))
    end.

%% Report §11.2: the units each detached session left for a process that
%% ran them, by its root, purged as their processes end, at each session's
%% start and each collection, so that such a unit is let go once the
%% process no longer runs it; one row of the node's, read once, which
%% holds nothing but after a session left a unit a process ran, and which
%% is written under the node's lock, read again there, since two sessions
%% and a detach may write it at once.
collect_detached() ->
    case node_kept(detached, #{}) of
        Detached when map_size(Detached) =:= 0 -> ok;
        _ -> node_locked(fun released_detached/0)
    end.

released_detached() ->
    Left = #{Root => maps:with(Remaining, Uses)
             || Root := Uses <- node_kept(detached, #{}),
                Remaining <- [released(in_users_order(Uses), Uses, #{}, [])],
                Remaining =/= []},
    node_keep(detached, Left),
    ok.

%% Report §6.9, §11.2: the site of a spawn an input's expression makes, the
%% input's name, the session's namespace and the file its diagnostics name,
%% `$Session2.input 3`, and the line. The
%% name is kept beside the module's uses and goes with them, since the
%% module's number is given to a later input once it is purged. It is a
%% row of its own, since every spawn of the input reads it, and the node's,
%% by the unit, since a process the input spawned may run its code after
%% the session has ended.
-spec input_site(atom(), pos_integer()) -> binary().
input_site(ErlangModule, Line) ->
    InputName = ets:lookup_element(?MODULE, {input_name, ErlangModule}, 2),
    <<InputName/binary, ":", (integer_to_binary(Line))/binary>>.

%% Report §11.2: the session is a scope of its own. The interface behind an
%% input joins the ones the checker is given, and what it declares joins the
%% scope under the unqualified name, which a later declaration of that name
%% overwrites. A type declared again with its hash unchanged is the type it
%% was (redeclared/2): its name names that type again.
joined(#session{interfaces = Interfaces, scope = Scope} = Session, #interface{} = Declaring) ->
    {Interface, Again} = redeclared(Declaring, Interfaces),
    #interface{namespace = Namespace, types = InterfaceTypes, values = InterfaceValues} = Interface,
    SessionTypes = maps:get(types, Scope, #{}),
    Named = [TypeInfo#type_info.qualified_name || TypeInfo <- Again]
        ++ maps:keys(InterfaceTypes),
    %% a type declared again starts with no members: the earlier type's
    %% belong to it, and its name now names another; a type of the same
    %% hash that its name named already keeps them
    Declared = [lists:last(QualifiedName) || QualifiedName <- Named,
                                             maps:get(lists:last(QualifiedName), SessionTypes,
                                                      none) =/= QualifiedName],
    Kept = case Declared of
               [] -> maps:get(values, Scope, #{});
               _ -> maps:filter(fun({MemberOf, _}, _) -> not lists:member(MemberOf, Declared);
                                   (_, _) -> true
                                end, maps:get(values, Scope, #{}))
           end,
    Values = maps:merge(Kept, maps:from_list([{value_key(Namespace, QualifiedName), QualifiedName}
                                              || QualifiedName <- maps:keys(InterfaceValues)])),
    Types = maps:merge(SessionTypes, maps:from_list([{lists:last(QualifiedName), QualifiedName}
                                                     || QualifiedName <- Named])),
    NewConstructors = [{lists:last(QualifiedName), QualifiedName}
                       || #type_info{constructors = TypeConstructors}
                              <- Again ++ maps:values(InterfaceTypes),
                          #constructor_info{qualified_name = QualifiedName} <- TypeConstructors],
    Constructors = maps:merge(maps:get(constructors, Scope, #{}), maps:from_list(NewConstructors)),
    Session#session{interfaces = Interfaces ++ [Interface],
                    scope = Scope#{values => Values, types => Types,
                                   constructors => Constructors}}.

%% Report §11.2, Appendix H: an input's interface where a type it declares
%% has the hash of a type an earlier input of the session declared, which
%% it is: renamed to the earlier type wherever the interface names it, and
%% no longer the input's own; with the earlier types' records. The input's
%% module needs the earlier input's from then on, as a module whose
%% interface names its type does (record_uses/3).
redeclared(#interface{types = Declared} = Interface, _Interfaces)
  when map_size(Declared) =:= 0 ->
    {Interface, []};
redeclared(#interface{namespace = [Own] = Namespace, types = Declared,
                      identities = Identities} = Interface,
           Interfaces) ->
    Held = maps:from_list([{Hash, TypeInfo}
                           || #interface{namespace = [Segment], types = Types,
                                         identities = HeldIdentities} <- Interfaces,
                              Segment =/= Own, is_session_segment(Segment),
                              QualifiedName := TypeInfo <- Types,
                              #{QualifiedName := Hash} <- [HeldIdentities]]),
    Again = #{QualifiedName => maps:get(Hash, Held)
              || QualifiedName := _ <- Declared, #{QualifiedName := Hash} <- [Identities],
                 is_map_key(Hash, Held)},
    case maps:size(Again) of
        0 ->
            {Interface, []};
        _ ->
            Renames = #{QualifiedName => Earlier#type_info.qualified_name
                        || QualifiedName := Earlier <- Again},
            Renamed = renamed(Interface, Renames),
            needs_named(Namespace, Renamed),
            {Renamed#interface{types = maps:without(maps:keys(Renames), Renamed#interface.types),
                               identities = maps:without(maps:keys(Renames), Identities)},
             maps:values(Again)}
    end.

%% A session module's needs, the session's modules Term names among them.
needs_named(Namespace, Term) ->
    needs_added(ern_namespace:erlang_module(Namespace), mentions(Term, Namespace)).

%% A name as an input after this one writes it: a type's member under the
%% type it is a member of, its MemberOf (report §4.2), anything else under
%% its own name.
value_key(Namespace, QualifiedName) ->
    case lists:nthtail(length(Namespace), QualifiedName) of
        [Name] -> Name;
        [MemberOf, Name] -> {MemberOf, Name}
    end.

%% The getter the emitter emits for a module's own value (§8.5). A binding
%% is a `let`, so a later input reaches it as it reaches any other module's
%% value, and calls it by applying what the getter answers (§4.6).
%%
%% Report §8.7: each name's getter, named by its position as a unit's
%% functions are (§11.1), and what the module holds, each binding by its
%% identity with the key its value is kept under, which the code table
%% reads as it loads, as it reads a compiled unit's (ern_emitter).
holder(ErlangModule, Names, Code) ->
    Getters = [ern_emitter:function_name(Number) || {Number, _} <- lists:enumerate(Names)],
    Get = fun(Getter) ->
              erl_syntax:application(
                erl_syntax:module_qualifier(erl_syntax:atom(persistent_term),
                                            erl_syntax:atom(get)),
                [erl_syntax:tuple([erl_syntax:atom(ErlangModule), erl_syntax:atom(Getter)])])
          end,
    Forms = [erl_syntax:attribute(erl_syntax:atom(module), [erl_syntax:atom(ErlangModule)]),
             erl_syntax:attribute(erl_syntax:atom(export),
                                  [erl_syntax:list(
                                     [erl_syntax:arity_qualifier(erl_syntax:atom(Function),
                                                                 erl_syntax:integer(0))
                                      || Function <- Getters ++ ['$code']])]),
             erl_syntax:function(erl_syntax:atom('$code'),
                                 [erl_syntax:clause([], none, [erl_syntax:abstract(Code)])])
             | [erl_syntax:function(erl_syntax:atom(Getter),
                                    [erl_syntax:clause([], none, [Get(Getter)])])
                || Getter <- Getters]],
    %% report §11: the host's compiler takes nothing from the environment
    {ok, _, Beam} = compile:noenv_forms([erl_syntax:revert(Form) || Form <- Forms],
                                        [return_errors]),
    Beam.

%% Report §11.2: whether the input is an expression, which binds `it`, and
%% not a `let` or declarations, which `:type` refuses.
-spec is_expression(#checked{}) -> boolean().
is_expression(#checked{binds = Binds}) ->
    Binds =:= it.

%% Report §11.2: what an input declares, a line for each, in the order they
%% were written, or none where the input shows its value instead: an
%% expression, and a `let` with `<-` whose value is a `Left` or a `None`,
%% which binds no name and binds that value to `it` (§5.5). A value is its
%% name and its type, a type its keyword and its name.
-spec declared(#checked{}, #value{}) -> {'Some', [binary()]} | 'None'.
declared(#checked{binds = it}, _Value) ->
    'None';
declared(#checked{binds = {arrow, Names, NamesType, Constructor}, env = Env},
         #value{term = Term}) ->
    case Term of
        {Constructor, _} -> {'Some', name_lines(Names, NamesType, Env)};
        _ -> 'None'
    end;
declared(Checked, _Value) ->
    {'Some', declared(Checked)}.

declared(#checked{binds = declarations, namespace = Namespace, declarations = Declarations,
                  interface = Interface, env = Env}) ->
    [line(Declaration, Namespace, Interface, Env) || Declaration <- Declarations,
                                                     kind(Declaration) =/= other];
declared(#checked{binds = {names, Names}, type = Type, env = Env}) ->
    name_lines(Names, Type, Env);
declared(#checked{binds = {lambda, Name, Scheme}, env = Env}) ->
    TypeState = ern_typecheck:type_state(Env),
    [unicode:characters_to_binary([atom_to_list(Name), " : ",
                                   ern_types:format_scheme(Scheme, TypeState)])];
declared(#checked{binds = {name, Name}} = Checked) ->
    [<<(atom_to_binary(Name))/binary, " : ", (type_text(Checked))/binary>>].

%% The names a pattern bound, each with its type: the whole of Type for
%% one name, a component of its tuple for more, and none for none.
name_lines([], _Type, _Env) ->
    [];
name_lines(Names, Type, Env) ->
    TypeState = ern_typecheck:type_state(Env),
    Types = case Names of
                [_] ->
                    [Type];
                _ ->
                    {ttuple, Components} = ern_types:substitute(Type, TypeState),
                    Components
            end,
    [unicode:characters_to_binary([atom_to_list(BoundName), " : ",
                                   ern_types:format(BoundType, TypeState)])
     || {BoundName, BoundType} <- lists:zip(Names, Types)].

kind(#type_declaration{}) -> <<"type">>;
kind(#abstract_declaration{}) -> <<"abstract type">>;
kind(#foreign_type_declaration{}) -> <<"foreign type">>;
kind(#fn_declaration{}) -> value;
kind(#foreign_fn_declaration{}) -> value;
kind(_) -> other.

line(Declaration, Namespace, #interface{values = Values}, Env) ->
    case kind(Declaration) of
        value ->
            {MemberOf, Name} = declared_name(Declaration),
            Scheme = maps:get(Namespace ++ MemberOf ++ [Name], Values),
            Text = ern_types:format_scheme(Scheme, ern_typecheck:type_state(Env)),
            unicode:characters_to_binary([local_name(MemberOf, Name), " : ", Text]);
        Keyword ->
            {_, Name} = declared_name(Declaration),
            <<Keyword/binary, " ", (atom_to_binary(Name))/binary>>
    end.

declared_name(#fn_declaration{member_of = undefined, name = Name}) -> {[], Name};
declared_name(#fn_declaration{member_of = MemberOf, name = Name}) -> {[MemberOf], Name};
declared_name(#foreign_fn_declaration{member_of = undefined, name = Name}) -> {[], Name};
declared_name(#foreign_fn_declaration{member_of = MemberOf, name = Name}) -> {[MemberOf], Name};
declared_name(#type_declaration{name = Name}) -> {[], Name};
declared_name(#abstract_declaration{declaration = #type_declaration{name = Name}}) -> {[], Name};
declared_name(#foreign_type_declaration{name = Name}) -> {[], Name}.

local_name([], Name) -> atom_to_list(Name);
local_name([MemberOf], Name) -> [atom_to_list(MemberOf), ".", atom_to_list(Name)].
