%% The prelude, report section 9, and the standard library signatures of
%% Appendix E, as data. Types are Ernest source, the standard library's
%% under their namespaces; values are name and type text, parsed by
%% ern_parser:parse_type/1 and converted by the checker.
%% A standard library module leaves these tables when it is rewritten in
%% Ernest (plan, MVP 2.5 step 3); its signatures then come from its compiled
%% interface, stdlib_ifaces/0.
-module(ern_prelude).

-export([builtin_types/0, declared_types/0, stdlib_types/0, values/0, process_only/0,
         eq_vars/1, stdlib_ifaces/0]).

-include_lib("typer/include/ern_types.hrl").

%% Types the runtime provides with no Ernest declaration: name and arity.
-spec builtin_types() -> [{atom(), non_neg_integer()}].
builtin_types() ->
    [{'Int', 0}, {'Float', 0}, {'Char', 0}, {'String', 0}, {'Bytes', 0}, {'Bool', 0},
     {'Address', 1}, {'Reply', 1}, {'Never', 0}, {'Foreign', 0},
     {'List', 1}, {'Map', 2}, {'Set', 1}].

%% Report §9.3.
-spec declared_types() -> string().
declared_types() ->
    "type Unit = Unit\n"
    "type Optional(a) = None | Some(a)\n"
    "type Either(e, a) = Left(e) | Right(a)\n"
    "type Ordering = Less | Equal | Greater\n"
    "type Down = Down(reason : Reason, function : String)\n"
    "type Reason = Returned | Killed | ProgramEnd | Fault(String)\n"
    "type ClockMsg = After(ms : Int, to : Address(Unit)) | At(at : Int, to : Address(Unit))"
    " | Now(reply : Reply(Int))\n"
    "type RemoteError = NoRemotePeer | PeerLost\n"
    "type Where = Local | Peer(String)\n"
    "type Key = Char(Char) | ArrowUp | ArrowDown | ArrowLeft | ArrowRight | Enter | Escape\n"
    "         | Interrupt\n"
    "type KeyMsg = Subscribe(Address(Key))\n"
    "type StdinMsg = ReadLine(reply : Reply(Optional(String)))\n"
    "type Path = Path(String)\n"
    "type Entry = Entry(path : Path, mtime : Int, size : Int, isDir : Bool)\n"
    "type IoError = NotFound | Denied | Refused | Closed | Timeout | Other(String)\n"
    "type FsMsg = ReadFile(path : Path, reply : Reply(Either(IoError, Bytes)))"
    " | WriteFile(path : Path, bytes : Bytes, reply : Reply(Either(IoError, Unit)))"
    " | AppendFile(path : Path, bytes : Bytes, reply : Reply(Either(IoError, Unit)))"
    " | ListDir(path : Path, reply : Reply(Either(IoError, List(Entry))))"
    " | Stat(path : Path, reply : Reply(Either(IoError, Entry)))"
    " | MakeDir(path : Path, reply : Reply(Either(IoError, Unit)))"
    " | Remove(path : Path, reply : Reply(Either(IoError, Unit)))"
    " | Rename(from : Path, to : Path, reply : Reply(Either(IoError, Unit)))"
    " | Copy(from : Path, to : Path, reply : Reply(Either(IoError, Unit)))\n"
    "type TcpMsg = Listen(port : Int, reply : Reply(Either(IoError, Address(ListenerMsg))))"
    " | Connect(host : String, port : Int, reply : Reply(Either(IoError, Address(SockMsg))))\n"
    "type ListenerMsg = Accept(reply : Reply(Either(IoError, Address(SockMsg))))\n"
    "type SockMsg = Recv(reply : Reply(Either(IoError, Bytes))) | Send(Bytes) | Close\n"
    "type Test = Test(name : String, run : () -> TestResult with Never)\n"
    "type TestResult = Passed | Failed(String)\n".

%% Types the standard library declares, by namespace (Appendix E.13).
%% Report Appendix E: a type a standard library module declares, for the
%% modules not yet written in Ernest; each leaves as its module moves.
-spec stdlib_types() -> [{[atom()], string()}].
stdlib_types() ->
    [].

%% Primitives whose effect variables are process-only (report §3.9), and the
%% Io functions, which are built on send.
-spec process_only() -> [[atom()]].
process_only() ->
    [[send], [spawn], ['Address', call], ['Address', callForever], [answer], [monitor],
     [kill], [remote], [parallelRemote],
     ['Clock', now], ['Clock', alarm], ['Clock', alarmAt]].

%% Type variables that carry the equality constraint (report §3.10): Map
%% keys, Set elements, and the List functions that compare elements.
-spec eq_vars([atom()]) -> [atom()].
eq_vars(['Map' | _]) -> [k];
eq_vars(['Set', map]) -> [a, b];
eq_vars(['Set', filterMap]) -> [a, b];
eq_vars(['Set' | _]) -> [a];
eq_vars(['List', contains]) -> [a];
eq_vars(['List', remove]) -> [a];
eq_vars(['List', unique]) -> [a];
eq_vars(_) -> [].

%% Qualified name and type text.
-spec values() -> [{[atom()], string()}].
values() ->
    [%% §9.4 built-in functions
     {[self], "() -> Address(m) with m"},
     {[send], "(Address(a), a) -> Unit with m"},
     {[spawn], "(Where, () -> Unit with n) -> Address(n) with m"},
     %% §9.5 process functions
     {[via], "((a) -> b, Address(b)) -> Address(a)"},
     {['Address', call], "(Address(m), (Reply(a)) -> m, Int) -> Optional(a) with n"},
     {['Address', callForever], "(Address(m), (Reply(a)) -> m) -> a with n"},
     {[answer], "(Reply(a), a) -> Unit with m"},
     {[remote], "(() -> a) -> Either(RemoteError, a) with m"},
     {[parallelRemote], "(List(() -> a)) -> List(Either(RemoteError, a)) with m"},
     {[monitor], "(Address(a), (Down) -> m) -> Unit with m"},
     {[kill], "(Address(a)) -> Unit with m"},
     %% §9.6 operations required by the language
     {['Int', '+'], "(Int, Int) -> Int"},
     {['Int', '-'], "(Int, Int) -> Int"},
     {['Int', '*'], "(Int, Int) -> Int"},
     {['Int', '/'], "(Int, Int) -> Int"},
     {['Int', '%'], "(Int, Int) -> Int"},
     {['Int', negate], "(Int) -> Int"},
     {['Float', '+'], "(Float, Float) -> Float"},
     {['Float', '-'], "(Float, Float) -> Float"},
     {['Float', '*'], "(Float, Float) -> Float"},
     {['Float', '/'], "(Float, Float) -> Float"},
     {['Float', negate], "(Float) -> Float"},
     {['String', '<>'], "(String, String) -> String"},
     {['List', '<>'], "(List(a), List(a)) -> List(a)"},
     {['Bytes', '<>'], "(Bytes, Bytes) -> Bytes"},
     {['Int', 'div'], "(Int, Int) -> Optional(Int)"},
     {['Int', 'mod'], "(Int, Int) -> Optional(Int)"},
     {['Int', compare], "(Int, Int) -> Ordering"},
     {['Float', compare], "(Float, Float) -> Ordering"},
     {['Char', compare], "(Char, Char) -> Ordering"},
     {[todo], "(String) -> a"},
     %% §9.7 system references
     {['Sys', stdout], "Address(String)"},
     {['Sys', stderr], "Address(String)"},
     {['Sys', stdin], "Address(StdinMsg)"},
     {['Sys', keys], "Address(KeyMsg)"},
     {['Sys', clock], "Address(ClockMsg)"},
     {['Sys', fs], "Address(FsMsg)"},
     %% every module of Appendix E is written in Ernest and read from its
     %% compiled interface (stdlib_ifaces/0); what stays in this table is
     %% section 9 alone
     {['Sys', tcp], "Address(TcpMsg)"}].

%% The interfaces of the standard library modules written in Ernest: every
%% ern@*.beam on the code path that carries an interface chunk (plan,
%% MVP 2.5 step 2). The compiled library is build output, so it is found by
%% what it holds rather than by an application's name.
-spec stdlib_ifaces() -> [#iface{}].
stdlib_ifaces() ->
    Files = lists:usort(lists:append([filelib:wildcard(filename:join(D, "ern@*.beam"))
                                      || D <- code:get_path()])),
    lists:append([stdlib_iface(F) || F <- Files]).

stdlib_iface(File) ->
    case beam_lib:chunks(File, ["ErnI"]) of
        {ok, {_, [{_, Chunk}]}} ->
            case catch binary_to_term(Chunk) of
                #{iface := {iface, Ns, Types, Values}} ->
                    [#iface{namespace = Ns, types = maps:from_list(Types),
                            values = maps:from_list(Values)}];
                _ ->
                    []
            end;
        _ ->
            []
    end.
