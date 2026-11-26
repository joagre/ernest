%% The helpers the tests share beside their waits (ern_waits): the run's
%% directory and a fresh one under it, a file written there; a module
%% compiled from text, loaded, and unloaded again, a unit out of the code
%% table among them; a compiled module's interface forged; the messages of
%% one tag a process's mailbox holds; the side of an Either; the options of
%% a run whose standard output is let go; what EUnit has captured; an I/O
%% server that keeps what it is given; a process of another node; a node's
%% certificate forged; and the record of the documents' blocks a test
%% checks.
-module(ern_helpers).

-export([run_dir/0, tmp/1, tmp/2, write/3, loaded/2, unloaded/1, forge/2, taken/1, side/1,
         quiet/0, quiet/1, silent/0, captured_output/0, device/0, device_bytes/1, far_process/0,
         forged_certificate/2, record_checked/3, record_of/1]).

-include_lib("public_key/include/public_key.hrl").

%% The directory a run of the tests makes what it needs under: the one
%% `make` makes for the run and removes when it ends (RUN_UNIT_TESTS), or
%% the host's temporary directory for a run of a test by itself.
-spec run_dir() -> file:filename().
run_dir() ->
    os:getenv("ERN_TEST_DIR", os:getenv("TMPDIR", "/tmp")).

%% A fresh directory under the run's, named by Prefix, the operating
%% system's pid and a count, so that no earlier run's is read.
-spec tmp(string()) -> file:filename().
tmp(Prefix) ->
    Dir = filename:join(run_dir(), Prefix ++ os:getpid() ++ "_"
                                   ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(Dir),
    Dir.

%% What Test answers, run in a fresh directory (tmp/1), which goes when
%% Test ends, whatever its outcome, since the flake hunt runs a test again
%% in the same host.
-spec tmp(string(), fun((file:filename()) -> Result)) -> Result.
tmp(Prefix, Test) ->
    Dir = tmp(Prefix),
    try Test(Dir) after file:del_dir_r(Dir) end.

%% The path of Relative under Dir, written with Text, its directories made.
-spec write(file:filename(), file:filename(), iodata()) -> file:filename().
write(Dir, Relative, Text) ->
    Path = filename:join(Dir, Relative),
    ok = filelib:ensure_dir(Path),
    ok = file:write_file(Path, Text),
    Path.

%% Module compiled from Forms, each the text of one form, every function of
%% no argument exported, and loaded from memory, so that no file is
%% written; a test unloads it once it ends (unloaded/1), since the flake
%% hunt runs a test again in the same host.
-spec loaded(module(), [iodata()]) -> module().
loaded(Module, Forms) ->
    Texts = [io_lib:format("-module(~w).", [Module]),
             "-compile([export_all, nowarn_export_all])." | Forms],
    {ok, Module, Binary} = compile:forms([form(Text) || Text <- Texts]),
    {module, Module} = code:load_binary(Module, atom_to_list(Module) ++ ".erl", Binary),
    Module.

form(Text) ->
    {ok, Tokens, _} = erl_scan:string(lists:flatten(Text)),
    {ok, Form} = erl_parse:parse_form(Tokens),
    Form.

%% Report §8.7, §11.2: Module out of the code table, where it is a unit
%% there, and out of the host, its old code and its current purged; a
%% module the host does not hold is passed over.
-spec unloaded(module()) -> ok.
unloaded(Module) ->
    ok = ern_code:unloaded(Module),
    _ = code:purge(Module),
    _ = code:delete(Module),
    _ = code:purge(Module),
    ok.

%% A compiled module, Beam, with its interface chunk changed by Change.
-spec forge(binary() | file:filename(), fun((term()) -> term())) -> binary().
forge(Beam, Change) ->
    {ok, _, Chunks} = beam_lib:all_chunks(Beam),
    Rewritten = [case Id of
                     "ErnI" -> {Id, term_to_binary(Change(binary_to_term(Chunk)))};
                     _ -> {Id, Chunk}
                 end || {Id, Chunk} <- Chunks],
    {ok, Forged} = beam_lib:build_module(Rewritten),
    Forged.

%% What the calling process's mailbox holds under Tag, every `{Tag, Value}`
%% so far, taken, their values in the order they came.
-spec taken(term()) -> [term()].
taken(Tag) ->
    receive {Tag, Value} -> [Value | taken(Tag)] after 0 -> [] end.

%% Which side of an Either a result is, Left or Right.
-spec side({'Left' | 'Right', term()}) -> 'Left' | 'Right'.
side({Side, _}) -> Side.

%% A run's options, ern_rt:run_main/3's, its standard output let go.
-spec quiet() -> map().
quiet() ->
    #{stdout => fun(_) -> ok end}.

%% The same, with Options beside it.
-spec quiet(map()) -> map().
quiet(Options) ->
    maps:merge(quiet(), Options).

%% A run's options, its standard output and its standard error let go.
-spec silent() -> map().
silent() ->
    quiet(#{stderr => fun(_) -> ok end}).

%% What EUnit has captured of the test's output so far, as UTF-8, asked of
%% the test's group leader, which is EUnit's. EUnit's own ?capturedOutput
%% first asks whether it is by the function it is running, which under load
%% it can sample while that process runs another module's code, and then
%% answers "".
-spec captured_output() -> binary().
captured_output() ->
    group_leader() ! {get_output, self()},
    receive {output, Output} -> unicode:characters_to_binary(Output) end.

%% An I/O server that keeps what it is given, for a job's error device;
%% device_bytes/1 ends it.
-spec device() -> pid().
device() ->
    Owner = self(),
    spawn(fun() -> kept(Owner, []) end).

%% What Device was given, as bytes, Device then ended.
-spec device_bytes(pid()) -> binary().
device_bytes(Device) ->
    Device ! {done, self()},
    receive {kept, Device, Bytes} -> Bytes end.

kept(Owner, Acc) ->
    receive
        {io_request, From, ReplyAs, {put_chars, Encoding, Chars}} ->
            From ! {io_reply, ReplyAs, ok},
            kept(Owner, [bytes(Chars, Encoding) | Acc]);
        {io_request, From, ReplyAs, {put_chars, Encoding, Module, Function, Arguments}} ->
            From ! {io_reply, ReplyAs, ok},
            kept(Owner, [bytes(apply(Module, Function, Arguments), Encoding) | Acc]);
        {io_request, From, ReplyAs, _} ->
            From ! {io_reply, ReplyAs, {error, enotsup}},
            kept(Owner, Acc);
        {done, Owner} ->
            Owner ! {kept, self(), iolist_to_binary(lists:reverse(Acc))}
    end.

bytes(Chars, latin1) -> iolist_to_binary(Chars);
bytes(Chars, unicode) -> unicode:characters_to_binary(Chars).

%% Report §8.7: a process of another node, `other@node.er`, which no
%% connection names, read from its external term.
-spec far_process() -> pid().
far_process() ->
    binary_to_term(<<131, 88, 119, 13, "other@node.er", 0:32, 1:32, 1:32>>).

%% Report §12.5: a certificate signed with the key of the configuration
%% directory Dir that names the host given, its DER, for the rule to refuse
%% where the host is another node's or none a key gives.
-spec forged_certificate(file:filename(), string()) -> binary().
forged_certificate(Dir, Host) ->
    {ok, Pem} = file:read_file(filename:join(Dir, "private-key.pem")),
    [Entry] = public_key:pem_decode(Pem),
    {'ECPrivateKey', _, Private, _, _, _} = Key = public_key:pem_entry_decode(Entry),
    {Point, _} = crypto:generate_key(eddsa, ed25519, Private),
    Name = {rdnSequence, [[#'AttributeTypeAndValue'{type = ?'id-at-commonName',
                                                    value = {utf8String, <<"ernest">>}}]]},
    Tbs = #'OTPTBSCertificate'{
             version = v3, serialNumber = 1,
             signature = #'SignatureAlgorithm'{algorithm = ?'id-Ed25519'},
             issuer = Name, subject = Name,
             validity = #'Validity'{notBefore = {utcTime, "700101000000Z"},
                                    notAfter = {generalTime, "99991231235959Z"}},
             subjectPublicKeyInfo = #'OTPSubjectPublicKeyInfo'{
                                       algorithm = #'PublicKeyAlgorithm'{algorithm = ?'id-Ed25519'},
                                       subjectPublicKey = #'ECPoint'{point = Point}},
             extensions = [#'Extension'{extnID = ?'id-ce-subjectAltName', critical = false,
                                        extnValue = [{dNSName, Host}]}]},
    public_key:pkix_sign(Tbs, Key).

%% Test checked the fenced blocks of Document, a path from the working
%% directory, whose fences open at Lines, each counted from 1, which
%% tools/documents.ern's listing `unchecked` reads. The record is a line a
%% fact: first the run that wrote it, its host's number and the moment the
%% host started; then a `checked` line for each block, its document's path
%% from the repository's root and its line, and a `covers` line for each
%% document Test chose blocks from. A run's first record replaces the
%% earlier run's, so that the record is the last run's, and the test's
%% processes write it one at a time. A line that opens no block fails the
%% test that counted it.
-spec record_checked(module(), file:filename(), [pos_integer()]) -> ok.
record_checked(Test, Document, Lines) ->
    {ok, Text} = file:read_file(Document),
    Relative = from_tree(Document),
    Opening = opening(binary:split(Text, <<"\n">>, [global]), 1, false),
    [lists:member(Line, Opening) orelse error({opens_no_block, Relative, Line})
     || Line <- Lines],
    Facts = [<<"covers ", Relative/binary>>
             | [<<"checked ", Relative/binary, ":", (integer_to_binary(Line))/binary>>
                || Line <- Lines]],
    Run = iolist_to_binary(["run ", os:getpid(), " ", integer_to_list(host_started())]),
    true = global:trans({{record_checked, Test}, self()},
                        fun() -> recorded(record_of(Test), Run, Facts) end, [node()]),
    ok.

%% The numbers of the lines that open a fenced block, a line that begins
%% with three backticks opening one or closing the one open, as the
%% listing reads a fence.
opening([], _, _) ->
    [];
opening([<<"```", _/binary>> | Lines], Number, false) ->
    [Number | opening(Lines, Number + 1, true)];
opening([<<"```", _/binary>> | Lines], Number, true) ->
    opening(Lines, Number + 1, false);
opening([_ | Lines], Number, Fenced) ->
    opening(Lines, Number + 1, Fenced).

%% The record of the blocks Test checks, build/checked/Test.txt.
-spec record_of(module()) -> file:filename().
record_of(Test) ->
    filename:join(ern_tree:build("checked"), atom_to_list(Test) ++ ".txt").

%% The record with Facts beside those Run wrote before, written whole.
recorded(Record, Run, Facts) ->
    Earlier = case file:read_file(Record) of
                  {ok, Bytes} ->
                      case binary:split(Bytes, <<"\n">>, [global, trim_all]) of
                          [Run | Kept] -> Kept;
                          _ -> []
                      end;
                  {error, enoent} ->
                      []
              end,
    ok = filelib:ensure_dir(Record),
    Written = Record ++ "." ++ os:getpid(),
    ok = file:write_file(Written, [[Line, <<"\n">>]
                                   || Line <- [Run | lists:usort(Earlier ++ Facts)]]),
    ok = file:rename(Written, Record),
    true.

%% The moment this host started, in milliseconds since the epoch.
host_started() ->
    erlang:convert_time_unit(erlang:system_info(start_time) + erlang:time_offset(), native,
                             millisecond).

%% Path, from the working directory, as a path from the toolchain's tree,
%% the repository's root.
from_tree(Path) ->
    Tree = filename:split(ern_tree:tree()),
    Segments = normalized(filename:split(filename:absname(Path)), []),
    {Tree, Relative} = lists:split(length(Tree), Segments),
    unicode:characters_to_binary(filename:join(Relative)).

normalized([], Acc) -> lists:reverse(Acc);
normalized(["." | Rest], Acc) -> normalized(Rest, Acc);
normalized([".." | Rest], [_ | Acc]) -> normalized(Rest, Acc);
normalized([Segment | Rest], Acc) -> normalized(Rest, [Segment | Acc]).
