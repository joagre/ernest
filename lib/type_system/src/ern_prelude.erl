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

-include_lib("type_system/include/ern_types.hrl").

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
     ['Clock', now], ['Clock', alarm], ['Clock', alarmAt], ['Keys', subscribe],
     ['Tcp', listen], ['Tcp', accept],
     ['Tcp', connect], ['Tcp', read], ['Tcp', write], ['Tcp', close]].

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
     {['Sys', stdin], "Address(StdinMsg)"},
     {['Sys', keys], "Address(KeyMsg)"},
     {['Sys', clock], "Address(ClockMsg)"},
     {['Sys', fs], "Address(FsMsg)"},
     {['Sys', tcp], "Address(TcpMsg)"},
     %% Appendix E.1 Io
     %% E.2 List
     {['List', size], "(List(a)) -> Int"},
     {['List', isEmpty], "(List(a)) -> Bool"},
     {['List', get], "(List(a), Int) -> Optional(a)"},
     {['List', last], "(List(a)) -> Optional(a)"},
     {['List', reverse], "(List(a)) -> List(a)"},
     {['List', take], "(List(a), Int) -> List(a)"},
     {['List', drop], "(List(a), Int) -> List(a)"},
     {['List', dropLast], "(List(a)) -> List(a)"},
     {['List', contains], "(List(a), a) -> Bool"},
     {['List', find], "(List(a), (a) -> Bool with e) -> Optional(a) with e"},
     {['List', any], "(List(a), (a) -> Bool with e) -> Bool with e"},
     {['List', all], "(List(a), (a) -> Bool with e) -> Bool with e"},
     {['List', map], "(List(a), (a) -> b with e) -> List(b) with e"},
     {['List', filter], "(List(a), (a) -> Bool with e) -> List(a) with e"},
     {['List', filterMap], "(List(a), (a) -> Optional(b) with e) -> List(b) with e"},
     {['List', foldLeft], "(List(a), b, (b, a) -> b with e) -> b with e"},
     {['List', foreach], "(List(a), (a) -> Unit with e) -> Unit with e"},
     {['List', span], "(List(a), (a) -> Bool with e) -> #(List(a), List(a)) with e"},
     {['List', partition], "(List(a), (a) -> Bool with e) -> #(List(a), List(a)) with e"},
     {['List', unique], "(List(a)) -> List(a)"},
     {['List', indexed], "(List(a)) -> List(#(Int, a))"},
     {['List', repeat], "(a, Int) -> List(a)"},
     {['List', sort], "(List(a), (a, a) -> Ordering with e) -> List(a) with e"},
     {['List', remove], "(List(a), a) -> List(a)"},
     {['List', zip], "(List(a), List(b)) -> List(#(a, b))"},
     {['List', unzip], "(List(#(a, b))) -> #(List(a), List(b))"},
     {['List', flatMap], "(List(a), (a) -> List(b) with e) -> List(b) with e"},
     {['List', range], "(Int, Int) -> List(Int)"},
     {['List', tryMap], "(List(a), (a) -> Either(e, b) with x) -> Either(e, List(b)) with x"},
     {['List', tryFold], "(List(a), b, (b, a) -> Either(e, b) with x) -> Either(e, b) with x"},
     %% E.3 Map
     %% E.4 Set
     %% E.5 String
     %% E.6 Char
     %% E.7 Bool
     %% E.8 Int
     %% E.9 Float
     %% E.10 Optional
     %% E.11 Either
     %% E.12 Foreign
     %% E.13 Random
     %% E.14 Path
     %% E.15 Clock
     %% E.16 Keys
     {['Keys', subscribe], "((Key) -> m) -> Unit with m"},
     %% E.17 Fs
     %% E.18 Tcp
     {['Tcp', listen], "(Int) -> Either(IoError, Address(ListenerMsg)) with m"},
     {['Tcp', accept], "(Address(ListenerMsg), Int) -> Either(IoError, Address(SockMsg)) with m"},
     {['Tcp', connect], "(String, Int, Int) -> Either(IoError, Address(SockMsg)) with m"},
     {['Tcp', read], "(Address(SockMsg), Int) -> Either(IoError, Bytes) with m"},
     {['Tcp', write], "(Address(SockMsg), Bytes) -> Unit with m"},
     {['Tcp', close], "(Address(SockMsg)) -> Unit with m"}].

%% The interfaces of the standard library modules written in Ernest: every
%% ernest@*.beam in an ern_stdlib ebin directory on the code path that
%% carries an interface chunk (plan, MVP 2.5 step 2). A hand-written module
%% has no chunk and is skipped.
-spec stdlib_ifaces() -> [#iface{}].
stdlib_ifaces() ->
    Dirs = [D || D <- code:get_path(), filename:basename(filename:dirname(D)) =:= "ern_stdlib"],
    Files = lists:usort(lists:append([filelib:wildcard(filename:join(D, "ernest@*.beam"))
                                      || D <- Dirs])),
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
