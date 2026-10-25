%% The prelude, report section 9, as data, with its documentation beside
%% each entry (report §9, Appendix E.0 shape rule 6). Types are Ernest source;
%% values are name, type text, and documentation, the type parsed by
%% ern_parser:parse_type/1 and converted by the checker. An operation a
%% type's standard library module provides is documented there, and its
%% entry says `module`. The standard library's own signatures come from its
%% compiled interfaces, stdlib_interfaces/0.
-module(ern_prelude).

-export([equality_params/1, builtin_types/0, is_builtin/1, declared_types/0, values/0,
         signature/1, parameters/1, member_types/0, is_member/1, docs/0, stdlib_interfaces/0,
         stdlib_files/0, stdlib_directory/0, set_stdlib_directory/1]).

-include_lib("checker/include/ern_types.hrl").
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
      1_000_000_000_000 * 1_000_000_000_000
      // => 1000000000000000000000000
      ```
      """/utf8>>},
     {'Float', 0,
      <<"""
      A double-precision floating-point number, always finite. An operation
      whose result would not be, an overflow or a division by zero, faults with
      the cause `float arithmetic error`. There is no infinity, no NaN and no
      negative zero (report §3.1).

      ### Examples

      ```ernest
      1.5 * 2.0
      // => 3.0
      ```
      """/utf8>>},
     {'Char', 0,
      <<"""
      One Unicode scalar value, written `'a'`. A letter as a reader sees it may
      be several, a letter and its accent; `String.graphemes` gives those
      whole.

      ### Examples

      ```ernest
      Char.toUpper('a')
      // => 'A'
      ```
      """/utf8>>},
     {'String', 0,
      <<"""
      Unicode text, held as UTF-8. Its length and positions count graphemes,
      what a reader sees as one letter, so `"é"` has size 1 however its accent
      is encoded (report Appendix E.5).

      ### Examples

      ```ernest
      "ab" <> "c"
      // => "abc"
      ```
      """/utf8>>},
     {'Bytes', 0,
      <<"""
      A sequence of bytes, as a file or a socket holds them. Bitstrings build
      it and take it apart: `<<1, 2, 3>>`, and `<<length:size(16), rest:bytes>>`
      in a pattern (report §5.11).

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
      Where messages of type `m` are sent: a process, or a process seen through
      a function with `adapted`. Holding an address is the permission to send to
      the process and to kill it. Addresses have no equality; the process
      behind one has, `Process.fromAddress(a)`.

      ### Examples

      ```ernest
      {
          let a : Address(Int) = spawn(fn() = receive { _ -> Unit });
          send(a, 1)
      }
      ```
      """/utf8>>},
     {'Reply', 1,
      <<"""
      Where the answer to a request goes. `Address.call` makes one and puts it
      in the request, and the process that receives the request answers it with
      `answer`. A process that cannot answer yet keeps the reply as it keeps
      any value, in a list or a map, and answers it when it can (report §6.6).

      ### Examples

      ```ernest
      {
          let echo = spawn(fn() = receive { #(n, r) -> answer(r, n) });
          Address.call(echo, fn(r) = #(7, r), 1000)
      }
      ```
      """/utf8>>},
     {'Never', 0,
      <<"""
      The type with no values. A process whose mailbox type is `Never`
      receives nothing, and nothing can be sent to its address.

      ### Examples

      ```ernest
      {
          let silent : Address(Never) = spawn(fn() = Io.println("hello"));
          kill(silent)
      }
      ```
      """/utf8>>},
     {'Process', 0,
      <<"""
      The identity of a process, with equality and no ordering; nothing can
      be sent to it. `Process.fromAddress` gives the process behind an
      address (report Appendix E.21).

      ### Examples

      ```ernest
      Process.fromAddress(self()) == Process.fromAddress(adapted(self(), fn(x) = x))
      // => true
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
      A map from keys of type `k` to values of type `v`. The `=` in `k=` says
      that the key type needs equality. A map is a value, and the module `Map`
      holds its operations.

      ### Examples

      ```ernest
      Map.get(Map.fromList([#("a", 1)]), "a")
      // => Some(1)
      ```
      """/utf8>>},
     {'Set', 1,
      <<"""
      A set of values of type `a`. The `=` in `a=` says that the element type
      needs equality. A set is a value, and the module `Set` holds its
      operations.

      ### Examples

      ```ernest
      Set.contains(Set.fromList([1, 2]), 2)
      // => true
      ```
      """/utf8>>}].

%% Report §3.1, §9.1, §9.2: a type of the prelude's own, which the checker
%% keeps as a foreign one and which is no foreign type of §3.8.
-spec is_builtin(ern_types:qualified_name()) -> boolean().
is_builtin([Name]) -> lists:keymember(Name, 1, builtin_types());
is_builtin(_) -> false.

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
    /// A value that may be absent, `None`, or present, `Some(v)`. A function
    /// that may have no answer answers one, `List.get` past the end among them
    /// (report Appendix E.0 rule 4). In a block, `let x <- e` takes the value
    /// out of a `Some`, and the block answers `None` at the first `None` (report
    /// §5.5).
    ///
    /// ### Examples
    ///
    /// ```ernest
    /// List.get([1, 2], 5)
    /// // => None
    /// ```
    type Optional(a) = None | Some(a)
    /// A result, `Right(v)`, or the reason there is none, `Left(e)`. An
    /// operation that can fail for a cause answers one. In a block, `let x <- e`
    /// takes the value out of a `Right`, and the block answers the first `Left`
    /// (report §5.5).
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
    /// compare(2, 1)
    /// // => Greater
    /// ```
    type Ordering = Less | Equal | Greater
    /// What `monitor` delivers when a process ends, and `monitorService` when
    /// it restarts too: which process it was, its reason, and where it was
    /// spawned, the top-level declaration and the line of the spawn,
    /// `Counter.main:19` (report §6.9).
    ///
    /// ### Examples
    ///
    /// ```ernest
    /// {
    ///     let worker = spawn(fn() = Unit);
    ///     monitor(Process.fromAddress(worker), fn(d : Down) = d);
    ///     receive { Down(reason = r, site = _) -> r }
    /// }
    /// ```
    type Down = Down(process : Process, reason : Reason, site : String)
    /// How a process ended, as `Down` says it.
    ///
    /// - `Returned`: its function returned, or, for a socket or a listener, the
    ///   program closed it.
    /// - `Killed`: `kill` ended it, or its owner's death, for a socket, a
    ///   listener or a running program.
    /// - `ProgramEnd`: the program ended while it ran.
    /// - `Fault(cause)`: it faulted, with that cause.
    /// - `Unknown`: it had ended before `monitor` was called, and how is not
    ///   known.
    /// - `Unreachable`: its node went out of reach, and it may live on; a
    ///   monitor on a process of another node alone gives it (report §8.7).
    /// - `Restarted`: it restarted in place, and lives on; a service monitor
    ///   alone gives it, at each restart (report §6.9).
    ///
    /// Only `Fault` counts as a fault: `ern run` reports it, and `restarting`
    /// restarts after it.
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
    type Reason = Returned | Killed | ProgramEnd | Fault(String) | Unknown | Unreachable | Restarted
    /// How often a process restarts, which `restarting` and `Supervisor.group`
    /// take (report §6.9). `RestartLimit(restarts, within)` restarts at most
    /// `restarts` times within `within` milliseconds, and the next fault then
    /// ends the process. `Unlimited` restarts after every fault. A count below 0
    /// is 0, and a time below 1 is 1.
    ///
    /// ### Examples
    ///
    /// ```ernest
    /// RestartLimit(restarts = 3, within = 5000)
    /// ```
    type RestartLimit = RestartLimit(restarts : Int, within : Int) | Unlimited
    /// A file system path, as the operating system writes it, `/tmp/a.txt`. The
    /// `Path` module joins paths and takes them apart (report Appendix E.14).
    ///
    /// ### Examples
    ///
    /// ```ernest
    /// Path.name(Path("/tmp/a.txt"))
    /// // => Some("a.txt")
    /// ```
    type Path = Path(String)
    """.

%% Qualified name, type text, and documentation, or `module` for an
%% operation its type's module documents (report §9).
-spec values() -> [{[atom()], string(), binary() | module}].
values() ->
    [%% §9.4 built-in functions
     {[self], "() -> Address(m) receiving m",
      <<"""
      The address of the calling process. A process gives it to another that
      is to answer or tell it something: `let me = self()`, then
      `spawn(fn() = worker(me))`.

      ### Examples

      ```ernest
      {
          let me = self();
          let _ = spawn(fn() = send(me, "ready"));
          receive { s -> s }
      }
      ```
      """/utf8>>},
     {[send], "(Address(a), a) -> Unit",
      <<"""
      Puts `message` in the mailbox of the process at `address`, and returns at
      once, without waiting for it to be received.

      Messages from one sender arrive in the order they were sent; between two
      senders there is no order (report §6.4). Sending to a process that has
      ended does nothing.

      ### Examples

      ```ernest
      send(self(), 42)
      ```
      """/utf8>>},
     {[spawn], "(() -> Unit receiving n) -> Address(n)",
      <<"""
      Starts a process that runs `f`, and answers its address. The process
      runs beside the caller, on this node, and `spawn` returns at once.

      The address takes the messages `f`'s mailbox type names. A function that
      receives nothing is spawned as any other, and what is sent to its address
      waits unread. Where nothing fixes the mailbox type by the end of the
      definition the spawn is written in, it is `Never`:
      `spawn(fn() = Io.println("hi"))` alone answers an `Address(Never)`
      (report §6.2). The process ends when `f` returns, faults, or is killed.

      ### Examples

      A process that receives an `Int`, so that its address is an
      `Address(Int)`:

      ```ernest
      spawn(fn() = receive { n -> Io.println(Int.toString(n)) })
      ```
      """/utf8>>},
     {[spawnMonitored], "(() -> Unit receiving n, (Down) -> m) -> Address(n) receiving m",
      <<"""
      Starts a process as `spawn` does, and watches it from its first moment:
      `wrap(d)` is put in the caller's mailbox when it ends, `d` the `Down`
      that says how. Unlike `spawn` followed by `monitor`, no end of the
      process can come before the watch (report §6.2, §6.9).

      ### Examples

      ```ernest
      spawnMonitored(fn() = Unit, fn(d : Down) = d)
      ```
      """/utf8>>},
     %% §9.5 process functions
     {[adapted], "(Address(b), (a) -> b) -> Address(a)",
      <<"""
      An adapted address of `target`, which turns each message with `wrap` and
      delivers it to `target`. It is no process of its own.

      A process whose mailbox takes `Msg` hands out `adapted(self(), Wrap)` to take
      a message of another type as one of its own, wrapped in its constructor
      `Wrap`. A fault in `wrap` ends the process behind `target`, not the
      sender (report §6.5).

      ### Examples

      ```ernest
      {
          let texts = adapted(self(), fn(n) = Int.toString(n));
          send(texts, 42)
      }
      ```

      since 0.4.0
      """/utf8>>},
     {['Address', call], "(Address(m), (Reply(a)) -> m, Int) -> Optional(a)",
      <<"""
      Asks the process at `address` and waits for its answer: `Some(answer)`,
      or `None` where none came within `ms` milliseconds.

      `request` is given a fresh `Reply` and builds the message that carries
      it: a constructor whose one field is the reply, `Get`, or a lambda,
      `fn(reply) = Add(amount = 5, reply = reply)`. The process that receives
      the message answers it with `answer`.

      `None` does not cancel the work: the process asked may still do it, and
      an answer that comes late is dropped. Where that process has ended, or
      ends or restarts before it answers, the call answers `None` at once.
      The clock starts at the call. The request is made and sent whatever the
      time, and `ms` bounds only the wait for the answer, which ends at once
      where the time has already passed (report §6.6).

      ### Examples

      ```ernest
      {
          let echo = spawn(fn() = receive { #(n, r) -> answer(r, n) });
          Address.call(echo, fn(r) = #(7, r), 1000)
      }
      ```
      """/utf8>>},
     {['Address', callForever], "(Address(m), (Reply(a)) -> m) -> a",
      <<"""
      Asks as `Address.call` does, and waits for the answer without a deadline,
      answering the answer itself. A process asked that lives and never
      answers keeps the caller waiting for ever.

      ### Errors

      Faults where the process asked has ended, or ends or restarts before it
      answers (report §6.6):

      - with that process's own cause, where it faulted;
      - `callee was killed`, where `kill` or its owner's death ended it;
      - `callee returned without answering`, where its function returned;
      - `callee was closed`, where the program closed it, a socket or a
        listener;
      - `callee was restarted`, where a supervisor asked it to restart;
      - `callee had ended`, where it had ended before the call.

      ### Examples

      ```ernest
      {
          let echo = spawn(fn() = receive { #(n, r) -> answer(r, n) });
          Address.callForever(echo, fn(r) = #(7, r))
      }
      ```
      """/utf8>>},
     {[answer], "(Reply(a), a) -> Unit",
      <<"""
      Answers a request: sends `value` to the caller waiting on `reply`.

      A second answer to a reply is dropped, and a caller that has stopped
      waiting, after its deadline or its end, never sees the answer; the
      process that answers is not told (report §6.6).

      ### Examples

      ```ernest
      spawn(fn() = receive { #(n, r) -> answer(r, n * 2) })
      ```
      """/utf8>>},
     {['Reply', process], "(Reply(a)) -> Process",
      <<"""
      The caller waiting on `reply`, as a `Process`: the callee may watch it
      with `monitor`, or compare it with another (report §6.6).

      It gives no address, so nothing is sent through it; the answer goes
      through the reply alone.

      ### Examples

      ```ernest
      {
          let echo = spawn(fn() = receive {
              r -> answer(r, Reply.process(r) == Process.current())
          });
          Address.callForever(echo, fn(r) = r)
      }
      ```

      since 0.5.0
      """/utf8>>},
     {[restarting], "(RestartLimit, () -> Unit receiving n) -> () -> Unit receiving n",
      <<"""
      A function that runs `f`, and runs it again in the same process each time
      it faults. A program spawns what it answers: `spawn(restarting(limit, f))`.

      The process keeps its address across a restart, so whoever holds it keeps
      it. Everything else starts afresh: the mailbox is emptied, every call
      waiting for the process's answer ends, and what the process asked the
      runtime for, its alarms, monitors and subscriptions, is canceled. What
      `f` held is gone (report §6.9).

      A restart is not a death: no `monitor` is told, and its `Down` comes only
      when the process ends for good; a service monitor, `monitorService`, is
      told of each restart too. `RestartLimit(restarts = n, within = t)`
      allows `n` restarts within `t` milliseconds, and `Unlimited` restarts
      after every fault.

      ### Errors

      Under `RestartLimit`, the fault past the limit ends the process, with
      that fault's cause.

      ### Examples

      A worker that faults on `0`, and runs again, at most three times in five
      seconds:

      ```ernest
      {
          let limit = RestartLimit(restarts = 3, within = 5000);
          spawn(restarting(limit, fn() : Unit receiving Int = receive {
              n -> Io.println(Int.toString(100 / n))
          }))
      }
      ```
      """/utf8>>},
     {[monitor], "(Process, (Down) -> m) -> Unit receiving m",
      <<"""
      Watches a process: `wrap(d)` is put in the caller's mailbox when
      `process` ends, `d` the `Down` that says how.

      A process that has already ended is reported at once, with the reason
      `Unknown`. Each call watches once and gives one message (report §6.9).
      `Process.fromAddress(a)` gives the process behind an address, and a
      process the caller starts itself is watched from its start with
      `spawnMonitored`. A restart in place is no end, and `monitor` is not told
      of it; `monitorService` is.

      ### Examples

      ```ernest
      {
          let worker : Address(Int) = spawn(fn() = receive { _ -> Unit });
          monitor(Process.fromAddress(worker), fn(d : Down) = d)
      }
      ```
      """/utf8>>},
     {[monitorService], "(Process, (Down) -> m) -> Unit receiving m",
      <<"""
      Watches a process as `monitor` does, and is told of its restarts too:
      `wrap(d)` is put in the caller's mailbox at each restart of `process`,
      with the reason `Restarted`, and when it ends, the watch ending then.

      A restart keeps the process's address and drops what its run held, so a
      process that keeps something for it, a lock it was granted, lets that
      go at `Restarted`. A process that has already ended is reported at once, with
      the reason `Unknown`, and each restart gives one message (report §6.9).
      A service monitor of a process of another node is told of its end
      alone, not of its restarts (report §8.7).

      ### Examples

      ```ernest
      {
          let holder : Address(Int) =
              spawn(restarting(Unlimited, fn() = receive { _ -> Unit }));
          monitorService(Process.fromAddress(holder), fn(d : Down) = d)
      }
      ```

      since 0.5.0
      """/utf8>>},
     {[demonitor], "(Process) -> Unit",
      <<"""
      Ends every watch the caller holds on `process`, those `monitor`,
      `monitorService` and `spawnMonitored` made alike (report §6.9).

      A `Down` already in the caller's mailbox stays, and none comes after.
      On a process the caller does not watch it does nothing.

      ### Examples

      ```ernest
      {
          let worker : Address(Int) = spawn(fn() = receive { _ -> Unit });
          monitor(Process.fromAddress(worker), fn(d : Down) = d);
          demonitor(Process.fromAddress(worker))
      }
      ```

      since 0.5.0
      """/utf8>>},
     {[kill], "(Address(a)) -> Unit",
      <<"""
      Ends the process at `address`. Its monitors see the reason `Killed`.

      `kill` returns at once, and the process may run a little before it stops.
      Killing a process that has ended does nothing (report §6.9).

      ### Examples

      ```ernest
      {
          let worker : Address(Int) = spawn(fn() = receive { _ -> Unit });
          kill(worker)
      }
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
     {['Path', '<>'], "(Path, Path) -> Path", module},
     {['Int', compare], "(Int, Int) -> Ordering", module},
     {['Float', compare], "(Float, Float) -> Ordering", module},
     {['String', compare], "(String, String) -> Ordering", module},
     {['Char', compare], "(Char, Char) -> Ordering", module},
     {['List', compare], "(List(a), List(a)) -> Ordering needs a.compare", module},
     {['Optional', compare], "(Optional(a), Optional(a)) -> Ordering needs a.compare", module},
     {['Either', compare], "(Either(e, a), Either(e, a)) -> Ordering needs e.compare, a.compare",
      module},
     {[fault], "(String) -> a",
      <<"""
      Ends the calling process with `cause`. It has every type, so it stands
      wherever a value is expected, and nothing catches the fault (report
      §7.3).

      Use it for an invariant broken beyond recovery. A failure the caller can
      handle is an `Optional` or an `Either`. Code not written yet is
      `fault("todo: ...")`.

      ### Errors

      Always faults, with `cause` as the cause.

      ### Examples

      ```ernest
      fn(xs : List(Int)) : Int = match xs { x :: _ -> x | [] -> fault("never empty here") }
      ```
      """/utf8>>},
     {[compare], "(a, a) -> Ordering needs a.compare",
      <<"""
      Compares `left` with `right` by the order of their type: `Less`, `Equal`
      or `Greater`. It is the type's own `compare`, `Int.compare` for two
      `Int`s, chosen as `<` chooses it, and reaches every order `<` reaches, a
      tuple's among them, and under `needs a.compare` the requirement's
      (report §3.10, §4.9).

      A type without an order has no `compare`: `compare(true, false)` is
      refused, as `true < false` is.

      ### Examples

      ```ernest
      #(compare(2, 1), compare(#("pear", 2), #("pear", 3)))
      // => #(Greater, Less)
      ```

      since 0.5.0
      """/utf8>>}].

%% Report §9.6, §4.9: a signature of the table apart: its type's text,
%% which ern_parser:parse_type/1 reads, and its requirement, each member
%% by its type variable's name, as `needs a.compare` writes it.
-spec signature(string()) -> {string(), [{atom(), atom()}]}.
signature(Text) ->
    case string:split(Text, " needs ") of
        [TypeText] ->
            {TypeText, []};
        [TypeText, Members] ->
            {TypeText, [{list_to_atom(Variable), list_to_atom(Member)}
                        || Written <- string:split(Members, ", ", all),
                           [Variable, Member] <- [string:split(Written, ".")]]}
    end.

%% Report §9.4, §9.5, §11.4: the parameters of the prelude's functions, named
%% for their roles as the report's §6 names them, which their pages and
%% `Shift-Tab` show; none for a value that is no function the prelude
%% documents.
-spec parameters([atom()]) -> [atom()] | none.
parameters([self]) -> [];
parameters([send]) -> [address, message];
parameters([spawn]) -> [f];
parameters([spawnMonitored]) -> [f, wrap];
parameters([adapted]) -> [target, wrap];
parameters(['Address', call]) -> [address, request, ms];
parameters(['Address', callForever]) -> [address, request];
parameters([answer]) -> [reply, value];
parameters(['Reply', process]) -> [reply];
parameters([restarting]) -> [limit, f];
parameters([monitor]) -> [process, wrap];
parameters([monitorService]) -> [process, wrap];
parameters([demonitor]) -> [process];
parameters([kill]) -> [address];
parameters([fault]) -> [cause];
parameters([compare]) -> [left, right];
parameters(_) -> none.

%% Report §4.2, §9.5, §9.6: the prelude's types whose namespace the
%% prelude fills, with their members or, `Address` and `Reply`, functions
%% of their own, each a namespace of the prelude beside `Prelude`; any
%% other prelude type takes none.
-spec member_types() -> [atom()].
member_types() ->
    lists:usort([hd(QualifiedName) || {QualifiedName, _, _} <- values(),
                                      length(QualifiedName) > 1]).

%% Report §4.2, §4.5: whether a qualified name is a member a prelude type
%% has, its compare, its negate or an operator, which its module declares
%% and no expression names: `Int.compare`, and not `Address.compare`.
-spec is_member([atom()]) -> boolean().
is_member([_, Name] = QualifiedName) ->
    lists:member(Name, [compare, negate | ?USEROPS])
        andalso lists:keymember(QualifiedName, 1, values());
is_member(_) ->
    false.

%% Report §9, §11.4: the prelude's documentation, as an EEP 48 chunk of the
%% shape ern_docs:build/4 builds for a module, so that one renderer serves
%% both. An operation its type's module documents is not repeated here.
-spec docs() -> tuple().
docs() ->
    {ok, Declarations} = ern_parser:parse_string(declared_types()),
    Texts = declaration_texts(declared_types()),
    Types = [entry({type, Name, Arity}, [type_signature(Name, Arity)], Doc)
             || {Name, Arity, Doc} <- builtin_types()]
        ++ [entry({type, Name, length(Params)}, maps:get(Name, Texts), Doc)
            || #type_declaration{name = Name, params = Params, doc = Doc} <- Declarations],
    Env = ern_typecheck:prelude_env(),
    Values = [entry({function, dotted(QualifiedName), arity(Signature)},
                    [declaration(QualifiedName, Env)], Doc,
                    #{params => parameters(QualifiedName)})
              || {QualifiedName, Signature, Doc} <- values(), Doc =/= module],
    {docs_v1, erl_anno:new(0), ernest, <<"text/markdown">>, #{<<"en">> => prelude_doc()},
     #{source => <<"the prelude, report §9"/utf8>>}, Types ++ Values}.

entry(Key, Signature, Doc) ->
    entry(Key, Signature, Doc, #{}).

entry(Key, Signature, Doc, Meta) ->
    {Key, erl_anno:new(0), Signature, #{<<"en">> => iolist_to_binary(Doc)}, Meta}.

%% Report §11.4: a function's declaration as its page shows it, its
%% parameters named and its restrictions marked (§11.5).
declaration(QualifiedName, Env) ->
    {ok, Scheme} = ern_typecheck:declared_scheme(lists:droplast(QualifiedName),
                                                 lists:last(QualifiedName), Env),
    Params = parameters(QualifiedName),
    {Head, Marked, Rest} = ern_types:format_call(Scheme, Params, length(Params),
                                                 ern_typecheck:type_state(Env)),
    unicode:characters_to_binary([ern_namespace:text(QualifiedName), Head, Marked, Rest]).

%% A built-in type as the report's §9.1 and §9.2 write it.
type_signature('Address', 1) -> <<"type Address(m)">>;
type_signature('Map', 2) -> <<"type Map(k=, v)">>;
type_signature('Set', 1) -> <<"type Set(a=)">>;
type_signature(Name, 1) -> <<"type ", (atom_to_binary(Name))/binary, "(a)">>;
type_signature(Name, 0) -> <<"type ", (atom_to_binary(Name))/binary>>.

%% Each declared type's source lines, without its doc block, by name.
declaration_texts(Source) ->
    Lines = [Line || Line <- string:split(Source, "\n", all), not lists:prefix("///", Line),
                     Line =/= ""],
    group_texts(Lines, #{}).

group_texts([], Acc) ->
    Acc;
group_texts(["type " ++ Rest = Line | Lines], Acc) ->
    {Continued, Others} = lists:splitwith(fun(Next) -> lists:prefix(" ", Next) end, Lines),
    Key = list_to_atom(hd(string:lexemes(Rest, " ("))),
    Texts = [unicode:characters_to_binary(Text) || Text <- [Line | Continued]],
    group_texts(Others, Acc#{Key => Texts});
group_texts([_ | Lines], Acc) ->
    group_texts(Lines, Acc).

dotted(QualifiedName) -> list_to_atom(ern_namespace:text(QualifiedName)).

arity(Text) ->
    {TypeText, _} = signature(Text),
    case ern_parser:parse_type(TypeText) of
        {ok, #t_fn{params = Params}} -> length(Params);
        _ -> 0
    end.

%% The prelude page's own doc block.
prelude_doc() ->
    <<"""
    The names every module has without writing a module's name.

    The prelude holds the types every program meets, `Int`, `String`, `List`,
    `Optional`, `Either` and the rest; the types the language's own rules
    name, `Down`, `Reason` and `RestartLimit`; the functions that start
    processes and talk to them, `spawn`, `send`, `Address.call` and the rest;
    `fault`; and `compare`, which compares two values of any type with an
    order (report §9).

    An operation in a type's namespace, `Int.compare` or `String.<>`, belongs to
    that type's module, and is documented on its page.

    ## Examples

    A process started, and a number sent to it:

    ```ernest
    {
        let counter = spawn(fn() = receive { n -> Io.println(Int.toString(n)) });
        send(counter, 1)
    }
    ```

    since 0.1.0
    """/utf8>>.

%% The interfaces of the standard library modules written in Ernest: one
%% for each of its files (stdlib_files/0), each of which carries an
%% interface chunk (report §11.1).
%%
%% Every check asks for them, and a build several times for each module,
%% and decoding a chunk, which reads each of its bytes as data first
%% (ern_chunk), costs about ten times reading the file. So the host holds, for
%% each file, the bytes of its interface chunk and the interface they
%% decode to, and decodes a chunk again only where its bytes differ from
%% those held: what is answered is always the files' own. What is held is
%% replaced whole where a file is added, removed or changed, and is never
%% more than the files the library's directory held at the last call.
-spec stdlib_interfaces() -> [#interface{}].
stdlib_interfaces() ->
    Files = stdlib_files(),
    Held = persistent_term:get({?MODULE, stdlib_interfaces}, #{}),
    Read = maps:from_list([{File, stdlib_interface(File, Held)} || File <- Files]),
    Read =:= Held orelse persistent_term:put({?MODULE, stdlib_interfaces}, Read),
    [Interface || File <- Files, {_, Interface} <- [maps:get(File, Read)]].

%% Report §11.1: the standard library's compiled modules, every `.erc` of
%% its directory, in the order of their names; none while the directory is
%% set aside. The compiled library is build output, so it is found where
%% it is built rather than by an application's name.
-spec stdlib_files() -> [file:filename()].
stdlib_files() ->
    case stdlib_directory() of
        none -> [];
        Directory -> [filename:join(Directory, Name)
                      || Name <- lists:sort(filelib:wildcard("*.erc", Directory))]
    end.

%% Report §11.1: the directory of the standard library's compiled modules,
%% `build/stdlib` beside the toolchain, where the library's own build
%% writes them, held once found; none while the library's own source root
%% builds, which takes the library's namespaces from that build's `.erc`
%% files alone (ern_build).
-spec stdlib_directory() -> file:filename() | none.
stdlib_directory() ->
    case persistent_term:get({?MODULE, stdlib_directory}, unfound) of
        unfound ->
            Directory = ern_tree:build("stdlib"),
            persistent_term:put({?MODULE, stdlib_directory}, Directory),
            Directory;
        Directory ->
            Directory
    end.

%% The standard library's directory replaced by Directory, or set aside by
%% none, and the one it replaces, which the caller puts back: the library's
%% own build sets it aside while it builds, and a test names a library of
%% its own.
-spec set_stdlib_directory(file:filename() | none) -> file:filename() | none.
set_stdlib_directory(Directory) ->
    Replaced = stdlib_directory(),
    persistent_term:put({?MODULE, stdlib_directory}, Directory),
    Replaced.

%% A file's interface chunk, its bytes copied out of the file's, and its
%% interface: the one held where the bytes are those held, else the one they
%% decode to. A standard library module whose interface cannot be read is
%% a broken build of the toolchain, said as such, never a namespace left
%% out.
stdlib_interface(File, Held) ->
    %% read raw, as the host's beam_lib reads, and not through its file
    %% server, which a process of a started runtime that asks, laying out
    %% the prelude's manual page (ern_cli), would wait on for each file
    Beam = case file:read_file(File, [raw]) of
               {ok, Bytes} -> Bytes;
               {error, Reason} -> broken(File, file:format_error(Reason))
           end,
    Chunk = case beam_lib:chunks(Beam, [binary_to_list(ern_interface:chunk_name())]) of
                {ok, {_, [{_, Found}]}} -> binary:copy(Found);
                {error, beam_lib, _} -> broken(File, "not a compiled module")
            end,
    case Held of
        #{File := {Chunk, _} = Same} ->
            Same;
        _ ->
            case ern_interface:read(Beam) of
                {ok, #{interface := Interface}} -> {Chunk, Interface};
                {error, Error} -> broken(File, Error)
            end
    end.

-spec broken(file:filename(), string()) -> no_return().
broken(File, Error) ->
    error({broken_standard_library, File, Error, "rebuild it with make"}).
