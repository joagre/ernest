%% The prelude, report section 9, as data, with its documentation beside
%% each entry (report §9, Appendix E.0 shape rule 6). Types are Ernest source;
%% values are name, type text, and documentation, the type parsed by
%% ern_parser:parse_type/1 and converted by the checker. An operation a
%% type's standard library module provides is documented there, and its
%% entry says `module`. The standard library's own signatures come from its
%% compiled interfaces, stdlib_interfaces/0.
-module(ern_prelude).

-export([equality_params/1, builtin_types/0, declared_types/0, process_only/0, values/0,
         parameters/1, member_types/0, docs/0, stdlib_interfaces/0]).

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
      function with `via`. Addresses have no equality; the process behind
      one has, `Process.fromAddress(a)`.

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
      The address a request carries for its answer, answered exactly once on
      every path by `answer` (report §6.6).

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
      The type with no values: a process whose mailbox is `Never` receives
      nothing.

      ### Examples

      ```ernest
      spawn(fn() : Unit with Never = Io.println("hello"))
      ```
      """/utf8>>},
     {'Process', 0,
      <<"""
      The identity of a process, with equality and no ordering; nothing can
      be sent to it. `Process.fromAddress` gives the process behind an
      address (report Appendix E.21).

      ### Examples

      ```ernest
      Process.fromAddress(self()) == Process.fromAddress(via(self(), fn(x) = x))
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
    /// What `monitor` delivers when a process ends: which process it was,
    /// how it ended, and where it was spawned, the top-level declaration and
    /// the line of the spawn, `Counter.main:19` (report §6.9).
    ///
    /// ### Examples
    ///
    /// ```ernest
    /// {
    ///     let worker = spawn(fn() : Unit with Never = Unit);
    ///     monitor(Process.fromAddress(worker), fn(d : Down) = d);
    ///     receive { Down(reason = r, site = _) -> r }
    /// }
    /// ```
    type Down = Down(process : Process, reason : Reason, site : String)
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
    /// How often `restarting` restarts: at most `restarts` times within
    /// `within` milliseconds, the next fault ending the process, or after
    /// every fault where it is `Unlimited` (report §6.9). A count below 0 is
    /// 0, and a time below 1 is 1.
    ///
    /// ### Examples
    ///
    /// ```ernest
    /// RestartLimit(restarts = 3, within = 5000)
    /// ```
    type RestartLimit = RestartLimit(restarts : Int, within : Int) | Unlimited
    /// A file system path, in the runtime's syntax; the `Path` module takes it
    /// apart (report Appendix E.14).
    ///
    /// ### Examples
    ///
    /// ```ernest
    /// Path.name(Path("/tmp/a.txt"))
    /// // => Some("a.txt")
    /// ```
    type Path = Path(String)
    """.

%% The primitives among values/0 whose effect variable is process-only and
%% stands in no value position (report §3.9); one that stands in a value
%% position, `self`'s, `monitor`'s and `spawnMonitored`'s, is process-only
%% by that alone, which signature_scheme marks.
-spec process_only() -> [[atom()]].
process_only() ->
    [[send], [spawn], ['Address', call], ['Address', callForever], [answer], [kill],
     [restarting]].

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
          let _ = spawn(fn() : Unit with Never = send(me, "ready"));
          receive { s -> s }
      }
      ```
      """/utf8>>},
     {[send], "(Address(a), a) -> Unit with m",
      <<"""
      Puts `message` in the mailbox of the process at `address`, and returns
      at once. Messages from one sender arrive in the order they were sent
      (report §6.4).

      ### Examples

      ```ernest
      send(self(), 42)
      ```
      """/utf8>>},
     {[spawn], "(() -> Unit with n) -> Address(n) with m",
      <<"""
      Starts a process on this node that runs `f`, and answers its address.
      The function's mailbox type is the address's (report §6.2).

      ### Examples

      ```ernest
      spawn(fn() = receive { n -> Io.println(Int.toString(n)) })
      ```
      """/utf8>>},
     {[spawnMonitored], "(() -> Unit with n, (Down) -> m) -> Address(n) with m",
      <<"""
      Starts a process as `spawn` does, monitored by the caller from its
      start: `wrap` of its `Down` is put in the caller's mailbox when it ends,
      with its reason, however soon that is (report §6.2, §6.9).

      ### Examples

      ```ernest
      spawnMonitored(fn() : Unit with Never = Unit, fn(d : Down) = d)
      ```
      """/utf8>>},
     %% §9.5 process functions
     {[via], "(Address(b), (a) -> b) -> Address(a)",
      <<"""
      An address that delivers what is sent to it to `target`, turned by
      `wrap`. It is not a process. A fault in `wrap` ends the process behind
      `target`, not the sender (report §6.5).

      ### Examples

      ```ernest
      {
          let texts = via(self(), fn(n) = Int.toString(n));
          send(texts, 42)
      }
      ```
      """/utf8>>},
     {['Address', call], "(Address(m), (Reply(a)) -> m, Int) -> Optional(a) with n",
      <<"""
      Sends `request` of a fresh reply to the process at `address`, and waits
      up to `ms` milliseconds for the answer: `Some` of it, or `None` when
      none came. An answer that comes late is dropped, and the recipient's
      work is not cancelled (report §6.6).

      ### Examples

      ```ernest
      {
          let echo = spawn(fn() = receive { #(n, r) -> answer(r, n) });
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
          let echo = spawn(fn() = receive { #(n, r) -> answer(r, n) });
          Address.callForever(echo, fn(r) = #(7, r))
      }
      ```
      """/utf8>>},
     {[answer], "(Reply(a), a) -> Unit with m",
      <<"""
      Puts `value` in `reply`, which consumes it. A second answer to one reply
      is dropped (report §6.6).

      ### Examples

      ```ernest
      spawn(fn() = receive { #(n, r) -> answer(r, n * 2) })
      ```
      """/utf8>>},
     {[restarting], "(RestartLimit, () -> Unit with n) -> () -> Unit with n",
      <<"""
      A function that runs `f()` and, when `f` faults, runs it again in the
      same process: the process keeps its address, its mailbox is emptied,
      every call waiting for its answer ends, and what the process asked the
      runtime for, its alarms, monitors and subscriptions, is cancelled
      (report §6.9). A restart is not a death; no `monitor` is told. With
      `Unlimited`, `f` runs again after every fault.

      ### Errors

      Under `RestartLimit`, the fault of `f` after the limit's restarts within
      its time, with that fault's cause.

      ### Examples

      ```ernest
      spawn(restarting(RestartLimit(restarts = 3, within = 5000), fn() : Unit with Never = Unit))
      ```
      """/utf8>>},
     {[monitor], "(Process, (Down) -> m) -> Unit with m",
      <<"""
      Puts `wrap` of a `Down` in the caller's mailbox when `process` ends, or
      at once, with the reason `Unknown`, if it has ended. Each call gives one
      message (report §6.9). `Process.fromAddress` gives the process behind an
      address, and a process one starts is watched from its start with
      `spawnMonitored`.

      ### Examples

      ```ernest
      {
          let worker : Address(Int) = spawn(fn() = receive { _ -> Unit });
          monitor(Process.fromAddress(worker), fn(d : Down) = d)
      }
      ```
      """/utf8>>},
     {[kill], "(Address(a)) -> Unit with m",
      <<"""
      Ends the process at `address`, which its monitors see as `Killed`. The
      process may run a little before it stops (report §6.9).

      ### Examples

      ```ernest
      kill(spawn(fn() = receive { _ -> Unit }))
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
     {[fault], "(String) -> a",
      <<"""
      Ends the process with `cause`: it has every type, and nothing
      catches the fault (report §7.3, §7.4). It is for an invariant broken
      beyond recovery; a failure the caller can handle is an `Optional` or an
      `Either`. Code not written yet is `fault("todo: ...")`.

      ### Errors

      `Fault(cause)`.

      ### Examples

      ```ernest
      fn(xs : List(Int)) : Int = match xs { x :: _ -> x | [] -> fault("never empty here") }
      ```
      """/utf8>>}].

%% Report §9.4, §9.5, §11.4: the parameters of the prelude's functions, named
%% for their roles as the report's §6 names them, which their pages and
%% `Shift-Tab` show; none for a value that is no function the prelude
%% documents.
-spec parameters([atom()]) -> [atom()] | none.
parameters([self]) -> [];
parameters([send]) -> [address, message];
parameters([spawn]) -> [f];
parameters([spawnMonitored]) -> [f, wrap];
parameters([via]) -> [target, wrap];
parameters(['Address', call]) -> [address, request, ms];
parameters(['Address', callForever]) -> [address, request];
parameters([answer]) -> [reply, value];
parameters([restarting]) -> [limit, f];
parameters([monitor]) -> [process, wrap];
parameters([kill]) -> [address];
parameters([fault]) -> [cause];
parameters(_) -> none.

%% Report §4.2, §9.5, §9.6: the prelude's types that have members, each a
%% namespace of the prelude beside `Prelude`; a prelude type without
%% members takes none.
-spec member_types() -> [atom()].
member_types() ->
    lists:usort([hd(QualifiedName) || {QualifiedName, _, _} <- values(),
                                      length(QualifiedName) > 1]).

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
    case ern_parser:parse_type(Text) of
        {ok, #t_fn{params = Params}} -> length(Params);
        _ -> 0
    end.

%% The prelude page's own doc block.
prelude_doc() ->
    <<"""
    The names every module has without writing a module's name: the built-in
    types, the types the language's rules name and those whose module is named
    after them, the process functions, and `fault` (report §9). An
    operation in a type's namespace, `Int.compare`, is documented by that
    type's module.

    ## Examples

    ```ernest
    {
        let counter = spawn(fn() = receive { n -> Io.println(Int.toString(n)) });
        send(counter, 1)
    }
    ```

    since 0.1.0
    """/utf8>>.

%% The interfaces of the standard library modules written in Ernest: every
%% ern@*.beam in a `stdlib` directory on the code path that carries an
%% interface chunk (report §11.1). The compiled library is build output,
%% so it is found by where it is installed rather than by an application's
%% name; taking every ern@ module on the path instead would make the
%% shell's own module, which lives in `build/shell` and is on the same
%% path, a standard library namespace (report §4.2, §11.2).
-spec stdlib_interfaces() -> [#interface{}].
stdlib_interfaces() ->
    Files = lists:usort(lists:append([filelib:wildcard(filename:join(Dir, "ern@*.beam"))
                                      || Dir <- code:get_path(),
                                         filename:basename(Dir) =:= "stdlib"])),
    lists:append([stdlib_interface(File) || File <- Files]).

%% A standard library module whose interface cannot be read is a broken
%% build of the toolchain, said as such, never a namespace left out.
stdlib_interface(File) ->
    case ern_interface:read(File) of
        {ok, #{interface := Interface}} ->
            [Interface];
        {error, Error} ->
            error({broken_standard_library, File, Error, "rebuild it with make"})
    end.
