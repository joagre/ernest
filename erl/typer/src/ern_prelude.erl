%% The prelude, report section 9, as data, with its documentation beside
%% each entry (report §9, Appendix E.0 rule 6). Types are Ernest source;
%% values are name, type text, and documentation, the type parsed by
%% ern_parser:parse_type/1 and converted by the checker. An operation a
%% type's standard library module provides is documented there, and its
%% entry says `module`. The standard library's own signatures come from its
%% compiled interfaces, stdlib_ifaces/0.
-module(ern_prelude).

-export([builtin_types/0, equality_params/1, declared_types/0, process_only/0, values/0, docs/0,
         stdlib_ifaces/0]).

-include_lib("typer/include/ern_types.hrl").
-include_lib("parser/include/ern_ast.hrl").

%% Report §9.2: which parameters of a built-in type require equality, as
%% `Map(k=, v)` and `Set(a=)` write it.
-spec equality_params(atom()) -> [boolean()].
equality_params('Map') -> [true, false];
equality_params('Set') -> [true];
equality_params(_) -> [].

%% Types the runtime provides with no Ernest declaration: name, arity, and
%% documentation.
-spec builtin_types() -> [{atom(), non_neg_integer(), binary()}].
builtin_types() ->
    [{'Int', 0,
      <<"""
      An integer of any size, on which arithmetic is exact (report §3.1).

      ### Examples

      ```ernest
      1_000_000 * 1_000_000
      // => 1000000000000
      ```
      """/utf8>>},
     {'Float', 0,
      <<"""
      A finite IEEE 754 double. An operation whose result would not be finite
      faults (report §3.1).

      ### Examples

      ```ernest
      1.5 * 2.0
      // => 3.0
      ```
      """/utf8>>},
     {'Char', 0,
      <<"""
      One Unicode scalar value, written `'a'`.

      ### Examples

      ```ernest
      Char.toUpper('a')
      // => 'A'
      ```
      """/utf8>>},
     {'String', 0,
      <<"""
      Unicode text, whose unit is the grapheme (report Appendix E.5).

      ### Examples

      ```ernest
      "ab" <> "c"
      // => "abc"
      ```
      """/utf8>>},
     {'Bytes', 0,
      <<"""
      A sequence of octets, built and matched with bitstrings (report §5.11).

      ### Examples

      ```ernest
      Bytes.size(<<1, 2, 3>>)
      // => 3
      ```
      """/utf8>>},
     {'Bool', 0,
      <<"""
      `true` or `false`.

      ### Examples

      ```ernest
      !(1 < 2)
      // => false
      ```
      """/utf8>>},
     {'Address', 1,
      <<"""
      Where messages of type `m` are sent: a process, or one seen through a
      function with `via`. Addresses have no equality.

      ### Examples

      ```ernest
      {
          let a : Address(Int) = spawn(Local, fn() = receive { _ -> Unit });
          send(a, 1)
      }
      ```
      """/utf8>>},
     {'Reply', 1,
      <<"""
      The address a request carries for its answer, answered exactly once on
      every path by `answer` (report §6.6).

      ### Examples

      ```ernest
      {
          let echo = spawn(Local, fn() = receive { #(n, r) -> answer(r, n) });
          Address.call(echo, fn(r) = #(7, r), 1000)
      }
      ```
      """/utf8>>},
     {'Never', 0,
      <<"""
      The type with no values: a process whose mailbox is `Never` receives
      nothing.

      ### Examples

      ```ernest
      spawn(Local, fn() -> Unit with Never = Io.println("hello"))
      ```
      """/utf8>>},
     {'Foreign', 0,
      <<"""
      A value foreign code made, which Ernest does not inspect; the `Foreign`
      module reads it (report Appendix E.12).

      ### Examples

      ```ernest
      Foreign.toInt(Foreign.from(3))
      // => Some(3)
      ```
      """/utf8>>},
     {'List', 1,
      <<"""
      A list of values of type `a`: `[]`, or `x :: rest`.

      ### Examples

      ```ernest
      1 :: [2, 3]
      // => [1, 2, 3]
      ```
      """/utf8>>},
     {'Map', 2,
      <<"""
      A map from keys of type `k`, which need equality, to values of type `v`.

      ### Examples

      ```ernest
      Map.get(Map.fromList([#("a", 1)]), "a")
      // => Some(1)
      ```
      """/utf8>>},
     {'Set', 1,
      <<"""
      A set of values of type `a`, which need equality.

      ### Examples

      ```ernest
      Set.contains(Set.fromList([1, 2]), 2)
      // => true
      ```
      """/utf8>>}].

%% Report §9.3, each type with its doc block.
-spec declared_types() -> string().
declared_types() ->
    """
    /// The type of a value that says nothing: the result of a function whose
    /// work is its effect. Its one value is written `Unit`.
    ///
    /// ### Examples
    ///
    /// ```ernest
    /// Unit
    /// // => Unit
    /// ```
    type Unit = Unit
    /// A value that may be absent, `None`, or present, `Some(v)`: the result of
    /// a partial operation (report Appendix E.0 rule 4), and a chain of `<-`
    /// (report §5.5).
    ///
    /// ### Examples
    ///
    /// ```ernest
    /// List.get([1, 2], 5)
    /// // => None
    /// ```
    type Optional(a) = None | Some(a)
    /// A result, `Right(v)`, or the reason there is none, `Left(e)`: the result
    /// of an operation that fails for a cause, and a chain of `<-` (report §5.5).
    ///
    /// ### Examples
    ///
    /// ```ernest
    /// Either.fromOptional(String.toInt("x"), "not a number")
    /// // => Left("not a number")
    /// ```
    type Either(e, a) = Left(e) | Right(a)
    /// What a `compare` answers, which `<` and the other comparisons read
    /// (report §3.10).
    ///
    /// ### Examples
    ///
    /// ```ernest
    /// Int.compare(2, 1)
    /// // => Greater
    /// ```
    type Ordering = Less | Equal | Greater
    /// What `monitor` delivers when a process ends: how it ended, and where
    /// it was spawned, the top-level declaration and the line of the spawn,
    /// `Counter.main:19` (report §6.9).
    ///
    /// ### Examples
    ///
    /// ```ernest
    /// {
    ///     let worker = spawn(Local, fn() -> Unit with Never = Unit);
    ///     monitor(worker, fn(d : Down) = d);
    ///     receive { Down(reason = r, site = _) -> r }
    /// }
    /// ```
    type Down = Down(reason : Reason, site : String)
    /// How a process ended: its function returned, `kill` ended it, the program
    /// ended while it ran, or it faulted with a cause. Only `Fault` is a fault.
    ///
    /// ### Examples
    ///
    /// ```ernest
    /// match Fault("division by zero") {
    ///     Fault(cause) -> cause
    ///   | _ -> "not a fault"
    /// }
    /// // => "division by zero"
    /// ```
    type Reason = Returned | Killed | ProgramEnd | Fault(String) | Unknown
    /// The messages `Sys.clock` takes. A program uses the `Clock` module and
    /// never sends to the clock itself (report Appendix E.0 rule 8).
    type ClockMsg = After(ms : Int, to : Address(Int)) | At(at : Int, to : Address(Int))
      | Now(reply : Reply(Int))
    /// Why `remote` has no answer: no peer takes remote computation, or the peer
    /// was lost before it answered (report §6.7).
    ///
    /// ### Examples
    ///
    /// ```ernest
    /// match remote(fn() = 6 * 7) {
    ///     Right(n) -> Some(n)
    ///   | Left(NoRemotePeer) or Left(PeerLost) -> None
    /// }
    /// ```
    type RemoteError = NoRemotePeer | PeerLost
    /// Where `spawn` starts a process: on this node, or on the peer of that name
    /// in the configuration (report §6.2).
    ///
    /// ### Examples
    ///
    /// ```ernest
    /// spawn(Local, fn() -> Unit with Never = Unit)
    /// ```
    type Where = Local | Peer(String)
    /// How often `restarting` restarts: at most `restarts` times within
    /// `within` milliseconds, the next fault ending the process (report
    /// §6.9). A count or a time below 0 is 0.
    ///
    /// ### Examples
    ///
    /// ```ernest
    /// RestartLimit(restarts = 3, within = 5000)
    /// ```
    type RestartLimit = RestartLimit(restarts : Int, within : Int)
    /// The terminal's window, in rows and columns, as the terminal reports it
    /// (report §8.2).
    type Size = Size(rows : Int, columns : Int)
    /// What the terminal delivers to its subscriber: a key, an arrow, `Enter`,
    /// `Escape`, the interrupt, a paste, or a new size (report §8.2).
    type Event = Key(Char) | ArrowUp | ArrowDown | ArrowLeft | ArrowRight | Enter
               | Escape | Interrupt | Pasted(String) | Resized(Size)
    /// The messages `Sys.terminal` takes. A program uses the `Terminal` module
    /// (report Appendix E.0 rule 8).
    type TerminalMsg = Subscribe(to : Address(Event), reply : Reply(Unit))
                     | Measure(reply : Reply(Optional(Size)))
    /// The messages `Sys.stdin` takes. A program reads a line with
    /// `Io.readLine` (report Appendix E.0 rule 8).
    type StdinMsg = ReadLine(reply : Reply(Optional(String)))
    /// A file system path, in the runtime's syntax; the `Path` module takes it
    /// apart (report Appendix E.14).
    ///
    /// ### Examples
    ///
    /// ```ernest
    /// Path.name(Path("/tmp/a.txt"))
    /// // => "a.txt"
    /// ```
    type Path = Path(String)
    /// What `Fs.stat` and `Fs.list` tell of a file: its path, its modification
    /// time, its size in bytes, and whether it is a directory.
    type Entry = Entry(path : Path, mtime : Int, size : Int, isDir : Bool)
    /// Why an operation of `Fs` or `Tcp` failed. `Other` carries the runtime's
    /// own account.
    type IoError = NotFound | Denied | Refused | Closed | Timeout | Other(String)
    /// The messages `Sys.fs` takes. A program uses the `Fs` module (report
    /// Appendix E.0 rule 8).
    type FsMsg =
        ReadFile(path : Path, reply : Reply(Either(IoError, Bytes)))
      | WriteFile(path : Path, bytes : Bytes, reply : Reply(Either(IoError, Unit)))
      | AppendFile(path : Path, bytes : Bytes, reply : Reply(Either(IoError, Unit)))
      | ListDir(path : Path, reply : Reply(Either(IoError, List(Entry))))
      | Stat(path : Path, reply : Reply(Either(IoError, Entry)))
      | MakeDir(path : Path, reply : Reply(Either(IoError, Unit)))
      | Remove(path : Path, reply : Reply(Either(IoError, Unit)))
      | Rename(from : Path, to : Path, reply : Reply(Either(IoError, Unit)))
      | Copy(from : Path, to : Path, reply : Reply(Either(IoError, Unit)))
    /// The messages `Sys.tcp` takes. A program uses the `Tcp` module (report
    /// Appendix E.0 rule 8).
    type TcpMsg =
        Listen(port : Int, reply : Reply(Either(IoError, Address(ListenerMsg))))
      | Connect(host : String, port : Int, reply : Reply(Either(IoError, Address(SockMsg))))
    /// The messages a listening socket takes. A program uses `Tcp.accept`
    /// (report Appendix E.0 rule 8).
    type ListenerMsg = Accept(reply : Reply(Either(IoError, Address(SockMsg))))
    /// The messages a connected socket takes. A program uses `Tcp.read`,
    /// `Tcp.write`, and `Tcp.close` (report Appendix E.0 rule 8).
    type SockMsg = Recv(reply : Reply(Either(IoError, Bytes))) | Send(Bytes) | Close
    /// A test that `ern test` runs: its name, and a function that answers
    /// whether it passed (report §9.3, §11.2).
    ///
    /// ### Examples
    ///
    /// ```ernest
    /// Test(name = "adds", run = fn() -> TestResult with Never =
    ///     if 1 + 1 == 2 then Passed else Failed("1 + 1 is not 2"))
    /// ```
    type Test = Test(name : String, run : () -> TestResult with Never)
    /// A test's answer: `Passed`, or `Failed` with what went wrong.
    ///
    /// ### Examples
    ///
    /// ```ernest
    /// if 1 + 1 == 2 then Passed else Failed("1 + 1 is not 2")
    /// // => Passed
    /// ```
    type TestResult = Passed | Failed(String)
    """.

%% The primitives among values/0 whose effect variables are process-only
%% (report §3.9).
-spec process_only() -> [[atom()]].
process_only() ->
    [[send], [spawn], [spawnMonitored], ['Address', call], ['Address', callForever], [answer],
     [monitor], [kill], [remote]].

%% Qualified name, type text, and documentation, or `module` for an
%% operation its type's module documents (report §9).
-spec values() -> [{[atom()], string(), binary() | module}].
values() ->
    [%% §9.4 built-in functions
     {[self], "() -> Address(m) with m",
      <<"""
      The address of the calling process.

      ### Examples

      ```ernest
      {
          let me = self();
          let _ = spawn(Local, fn() -> Unit with Never = send(me, "ready"));
          receive { s -> s }
      }
      ```
      """/utf8>>},
     {[send], "(Address(a), a) -> Unit with m",
      <<"""
      Puts `v` in the mailbox of the process at `a`, and returns at once.
      Messages from one sender arrive in the order they were sent (report
      §6.4).

      ### Examples

      ```ernest
      send(Sys.stdout, "hello\n")
      ```
      """/utf8>>},
     {[spawn], "(Where, () -> Unit with n) -> Address(n) with m",
      <<"""
      Starts a process that runs `f`, on this node or on a peer, and answers
      its address. The function's mailbox type is the address's (report
      §6.2).

      ### Errors

      `Fault("peer unreachable")` when the peer is unknown or cannot be
      reached.

      ### Examples

      ```ernest
      spawn(Local, fn() = receive { n -> Io.println(Int.toString(n)) })
      ```
      """/utf8>>},
     {[spawnMonitored], "(Where, () -> Unit with n, (Down) -> m) -> Address(n) with m",
      <<"""
      Starts a process as `spawn` does, monitored by the caller from its
      start: `wrap(d)` is put in the caller's mailbox when it ends, with its
      reason, however soon that is (report §6.2, §6.9).

      ### Errors

      `Fault("peer unreachable")` when the peer is unknown or cannot be
      reached.

      ### Examples

      ```ernest
      spawnMonitored(Local, fn() -> Unit with Never = Unit, fn(d : Down) = d)
      ```
      """/utf8>>},
     %% §9.5 process functions
     {[via], "((a) -> b, Address(b)) -> Address(a)",
      <<"""
      An address that delivers what is sent to it to `target`, turned by `f`.
      It is not a process. A fault in `f` ends the process behind `target`,
      not the sender (report §6.5).

      ### Examples

      ```ernest
      {
          let lines = via(fn(n) = Int.toString(n) <> "\n", Sys.stdout);
          send(lines, 42)
      }
      ```
      """/utf8>>},
     {['Address', call], "(Address(m), (Reply(a)) -> m, Int) -> Optional(a) with n",
      <<"""
      Sends the request `mk(r)`, with a fresh reply `r`, and waits up to `ms`
      milliseconds for the answer: `Some` of it, or `None` when none came. An
      answer that comes late is dropped, and the recipient's work is not
      cancelled (report §6.6).

      ### Examples

      ```ernest
      {
          let echo = spawn(Local, fn() = receive { #(n, r) -> answer(r, n) });
          Address.call(echo, fn(r) = #(7, r), 1000)
      }
      ```
      """/utf8>>},
     {['Address', callForever], "(Address(m), (Reply(a)) -> m) -> a with n",
      <<"""
      As `Address.call`, but waits without a deadline and answers the answer
      itself; if none comes, the caller waits for ever.

      ### Examples

      ```ernest
      {
          let echo = spawn(Local, fn() = receive { #(n, r) -> answer(r, n) });
          Address.callForever(echo, fn(r) = #(7, r))
      }
      ```
      """/utf8>>},
     {[answer], "(Reply(a), a) -> Unit with m",
      <<"""
      Puts `v` in the reply `r`, which consumes it. A second answer to one reply
      is dropped (report §6.6).

      ### Examples

      ```ernest
      spawn(Local, fn() = receive { #(n, r) -> answer(r, n * 2) })
      ```
      """/utf8>>},
     {[restarting], "(RestartLimit, () -> Unit with n) -> () -> Unit with n",
      <<"""
      A function that runs `f()` and, when `f` faults, runs it again in the
      same process: the process keeps its address and its mailbox, the
      message being handled is lost, and every call waiting for its answer
      ends (report §6.9). A restart is not a death; no `monitor` is told.

      ### Errors

      The fault of `f` after the limit's restarts within its time, with that
      fault's cause.

      ### Examples

      ```ernest
      spawn(Local, restarting(RestartLimit(restarts = 3, within = 5000),
          fn() -> Unit with Never = Unit))
      ```
      """/utf8>>},
     {[remote], "(() -> a) -> Either(RemoteError, a) with m",
      <<"""
      Runs the pure function `f` on a peer the runtime chooses, and answers its
      value, or why there is none (report §6.7). The toolchain runs one node
      until peers are built, and answers `Left(NoRemotePeer)`.

      ### Errors

      The fault of `f`, with the same cause, as a call of `f` here would.

      ### Examples

      ```ernest
      remote(fn() = 6 * 7)
      ```
      """/utf8>>},
     {[monitor], "(Address(a), (Down) -> m) -> Unit with m",
      <<"""
      Puts `wrap(d)` in the caller's mailbox when the process at `a` ends, or at
      once, with the reason `Unknown`, if it has ended. Each call gives one
      message (report §6.9). A process one starts is watched from its start
      with `spawnMonitored`.

      ### Examples

      ```ernest
      {
          let worker : Address(Int) = spawn(Local, fn() = receive { _ -> Unit });
          monitor(worker, fn(d : Down) = d)
      }
      ```
      """/utf8>>},
     {[kill], "(Address(a)) -> Unit with m",
      <<"""
      Ends the process at `a`, which its monitors see as `Killed`. The process
      may run a little before it stops (report §6.9).

      ### Examples

      ```ernest
      kill(spawn(Local, fn() = receive { _ -> Unit }))
      ```
      """/utf8>>},
     %% §9.6 operations required by the language, documented by their modules
     {['Int', '+'], "(Int, Int) -> Int", module},
     {['Int', '-'], "(Int, Int) -> Int", module},
     {['Int', '*'], "(Int, Int) -> Int", module},
     {['Int', '/'], "(Int, Int) -> Int", module},
     {['Int', '%'], "(Int, Int) -> Int", module},
     {['Int', negate], "(Int) -> Int", module},
     {['Float', '+'], "(Float, Float) -> Float", module},
     {['Float', '-'], "(Float, Float) -> Float", module},
     {['Float', '*'], "(Float, Float) -> Float", module},
     {['Float', '/'], "(Float, Float) -> Float", module},
     {['Float', negate], "(Float) -> Float", module},
     {['String', '<>'], "(String, String) -> String", module},
     {['List', '<>'], "(List(a), List(a)) -> List(a)", module},
     {['Bytes', '<>'], "(Bytes, Bytes) -> Bytes", module},
     {['Int', 'div'], "(Int, Int) -> Optional(Int)", module},
     {['Int', 'mod'], "(Int, Int) -> Optional(Int)", module},
     {['Int', compare], "(Int, Int) -> Ordering", module},
     {['Float', compare], "(Float, Float) -> Ordering", module},
     {['Char', compare], "(Char, Char) -> Ordering", module},
     {[fault], "(String) -> a",
      <<"""
      Ends the process with the cause given: it has every type, and nothing
      catches the fault (report §7.3, §7.4). It is for an invariant broken
      beyond recovery; a failure the caller can handle is an `Optional` or an
      `Either`. Code not written yet is `fault("todo: ...")`.

      ### Errors

      `Fault(text)`.

      ### Examples

      ```ernest
      fn(xs : List(Int)) -> Int = match xs { x :: _ -> x | [] -> fault("never empty here") }
      ```
      """/utf8>>},
     %% §9.7 system references; a program uses them through their modules
     {['Sys', stdout], "Address(String)",
      <<"The process that writes a program's output; `Io.println` sends to it.">>},
     {['Sys', stderr], "Address(String)",
      <<"The process that writes a program's diagnostics; `Io.printlnError` sends to it.">>},
     {['Sys', stdin], "Address(StdinMsg)",
      <<"The process that reads standard input a line at a time; `Io.readLine` asks it.">>},
     {['Sys', terminal], "Address(TerminalMsg)",
      <<"The process that holds the terminal for one subscriber; the `Terminal` module "
        "speaks to it.">>},
     {['Sys', clock], "Address(ClockMsg)",
      <<"The process that tells the time and sets alarms; the `Clock` module speaks to it.">>},
     {['Sys', fs], "Address(FsMsg)",
      <<"The process that reads and writes files; the `Fs` module speaks to it.">>},
     {['Sys', tcp], "Address(TcpMsg)",
      <<"The process that opens sockets; the `Tcp` module speaks to it.">>}].

%% Report §9, §11.4: the prelude's documentation, as an EEP 48 chunk of the
%% shape ern_docs:build/4 builds for a module, so that one renderer serves
%% both. An operation its type's module documents is not repeated here.
-spec docs() -> tuple().
docs() ->
    {ok, Decls} = ern_parser:parse_string(declared_types()),
    Texts = declaration_texts(declared_types()),
    Types = [entry({type, N, A}, [type_signature(N, A)], D) || {N, A, D} <- builtin_types()]
        ++ [entry({type, N, length(Ps)}, maps:get(N, Texts), D)
            || #type_decl{name = N, params = Ps, doc = D} <- Decls],
    Values = [entry({function, dotted(Q), arity(T)}, [iolist_to_binary([dotted_text(Q), " : ", T])],
                    D)
              || {Q, T, D} <- values(), D =/= module],
    {docs_v1, erl_anno:new(0), ernest, <<"text/markdown">>, #{<<"en">> => prelude_doc()},
     #{source => <<"the prelude, report §9"/utf8>>}, Types ++ Values}.

entry(Key, Signature, Doc) ->
    {Key, erl_anno:new(0), Signature, #{<<"en">> => iolist_to_binary(Doc)}, #{}}.

%% A built-in type as the report's §9.1 and §9.2 write it.
type_signature('Address', 1) -> <<"type Address(m)">>;
type_signature('Map', 2) -> <<"type Map(k=, v)">>;
type_signature('Set', 1) -> <<"type Set(a=)">>;
type_signature(N, 1) -> <<"type ", (atom_to_binary(N))/binary, "(a)">>;
type_signature(N, 0) -> <<"type ", (atom_to_binary(N))/binary>>.

%% Each declared type's source lines, without its doc block, by name.
declaration_texts(Source) ->
    Lines = [L || L <- string:split(Source, "\n", all), not lists:prefix("///", L), L =/= ""],
    group_texts(Lines, #{}).

group_texts([], Acc) ->
    Acc;
group_texts(["type " ++ Rest = L | Ls], Acc) ->
    {Cont, Others} = lists:splitwith(fun(C) -> lists:prefix(" ", C) end, Ls),
    Key = list_to_atom(hd(string:lexemes(Rest, " ("))),
    group_texts(Others, Acc#{Key => [unicode:characters_to_binary(X) || X <- [L | Cont]]});
group_texts([_ | Ls], Acc) ->
    group_texts(Ls, Acc).

dotted(Q) -> list_to_atom(dotted_text(Q)).

dotted_text(Q) -> lists:flatten(lists:join(".", [atom_to_list(S) || S <- Q])).

arity(Text) ->
    case ern_parser:parse_type(Text) of
        {ok, #t_fn{params = Ps}} -> length(Ps);
        _ -> 0
    end.

%% The prelude page's own doc block.
prelude_doc() ->
    <<"""
    The names every module has without writing a module's name: the built-in
    types, the types the language's rules and the system references speak, the
    process functions, `fault`, and the system references (report §9). An
    operation in a type's namespace, `Int.compare`, is documented by that
    type's module.

    ## Examples

    ```ernest
    {
        let counter = spawn(Local, fn() = receive { n -> Io.println(Int.toString(n)) });
        send(counter, 1)
    }
    ```

    since 0.1.0
    """/utf8>>.

%% The interfaces of the standard library modules written in Ernest: every
%% ern@*.beam in a `stdlib` directory on the code path that carries an
%% interface chunk (plan, MVP 2.5). The compiled library is build
%% output, so it is found by where it is installed rather than by an
%% application's name; taking every ern@ module on the path instead would
%% make the shell's own module, which lives in `build/shell` and is on the
%% same path, a standard library namespace (report §4.2, §11.2).
-spec stdlib_ifaces() -> [#iface{}].
stdlib_ifaces() ->
    Files = lists:usort(lists:append([filelib:wildcard(filename:join(D, "ern@*.beam"))
                                      || D <- code:get_path(),
                                         filename:basename(D) =:= "stdlib"])),
    lists:append([stdlib_iface(F) || F <- Files]).

%% A standard library module whose interface cannot be read is a broken
%% build of the toolchain, said as such, never a namespace left out.
stdlib_iface(File) ->
    case ern_iface:read(File) of
        {ok, #{iface := Iface}} ->
            [Iface];
        {error, Reason} ->
            error({broken_standard_library, File, Reason, "rebuild it with make"})
    end.
