%% The blocks the site offers the shell, each pasted into a bare `ern shell`
%% as the page's client pastes it (docs/design/site.md, *The
%% live shell*): every block given Paste or Load, and every transcript
%% input given Paste, through the pseudo-terminal harness (ern_pty). The
%% site is written by the generator from the checkout's own documents, as
%% they stand. A block runs where the shell answers it, and a Load's
%% `main()`, without a diagnostic or a fault and comes back to its prompt;
%% a transcript runs where the shell answers its inputs with as many
%% diagnostics and faults as the transcript shows.
%%
%% site/unrunnable.md lists each block that does not, by its page's address
%% and its first line, a transcript's by its first input, and the
%% generator gives those Copy alone; the test holds the file equal to what
%% it finds, running the blocks it lists as well as those offered, and
%% `make site-unrunnable` writes it again (write_unrunnable/0).
%%
%% The blocks a page offers run in one session, `:forget *` between them,
%% so that each finds the session's names as a bare shell has them; one
%% that does not run there, or never comes back to its prompt, is run
%% again in a shell of its own, which decides, so that a process an earlier
%% block left running cannot count against it. A transcript, and a block
%% the file lists, runs in a shell of its own; one that never comes back
%% holds its place for the harness's wait, so the listed blocks start
%% first. The homepage's example is left out: its session is a node's,
%% begun with `--config-dir a`, which ern_tour_tests runs on two nodes as
%% the page shows it. Written after the generator's rule, a regression test.
-module(ern_site_shell_tests).

-include_lib("eunit/include/eunit.hrl").

-export([write_unrunnable/0]).

-define(LISTED, "../site/unrunnable.md").
-define(OUT, "build/site/bare-out").

%% What the file says before its list.
-define(HEADER,
        <<"# The blocks a bare shell cannot run\n\nThe blocks of the site's pages that a bare `ern"
          " shell` cannot run, each by its page's address and its first line, a transcript's by"
          " its first input. The site's generator gives each Copy alone, as the site's"
          " design says in *The live shell*. The test `test/ern_site_shell_tests.erl` pastes"
          " every block the site offers the shell, and every block listed here, into a bare"
          " shell, and holds this list equal to what it finds; `make site-unrunnable` writes it"
          " again.\n">>).

%% A block a page holds: its page's address, the line it is known by, its
%% kind, its text, and, for a transcript, its inputs and the diagnostics and
%% faults it shows.
-record(block, {address :: string(), line :: binary(), kind :: paste | load | transcript,
                text :: binary(), inputs = [] :: [binary()], shown = 0 :: non_neg_integer()}).

%% docs/design/site.md *The live shell*: a test runs every
%% block given Paste or Load, and every transcript input given Paste, in a
%% bare shell; site/unrunnable.md lists those it cannot run, and nothing
%% else.
unrunnable_test_() ->
    {timeout, 900, fun() ->
                       Found = found(),
                       [io:format(user, "~s ~s: ~s~n", [Address, Line, Why])
                        || {{Address, Line}, Why} <- Found,
                           not lists:member({Address, Line}, listed())],
                       ?assertEqual(listed(), [Key || {Key, _} <- Found])
                   end}.

%% make site-unrunnable: site/unrunnable.md written again from what the
%% test finds, after a change to the documents that is meant.
-spec write_unrunnable() -> ok.
write_unrunnable() ->
    Found = found(),
    [io:format("~s ~s: ~s~n", [Address, Line, Why]) || {{Address, Line}, Why} <- Found],
    Items = [["- ", span(list_to_binary(Address)), " ", span(Line), "\n"]
             || {{Address, Line}, _} <- Found],
    ok = file:write_file(?LISTED, [?HEADER, [["\n", Items] || Items =/= []]]).

%% The blocks the file lists, by page and line, in order.
listed() ->
    {ok, Text} = file:read_file(?LISTED),
    Items = [Item || <<"- ", Item/binary>> <- binary:split(Text, <<"\n">>, [global])],
    lists:sort([listed_item(Item) || Item <- Items]).

listed_item(Item) ->
    {match, [Address, Line]} =
        re:run(Item, "^(`+) ?(.*?) ?\\1 (`+) ?(.*?) ?\\3$",
               [{capture, [2, 4], binary}]),
    {binary_to_list(Address), Line}.

%% A code span of the text, its fence longer than any run of backticks it
%% holds, and a space inside it where the text begins or ends with one.
span(Text) ->
    Runs = [byte_size(Run) || [Run] <- matches(Text, "(`+)")],
    Fence = binary:copy(<<"`">>, lists:max([0 | Runs]) + 1),
    Pad = case Text of
              <<"`", _/binary>> -> <<" ">>;
              _ -> case binary:last(Text) of $` -> <<" ">>; _ -> <<>> end
          end,
    [Fence, Pad, Text, Pad, Fence].

%% The blocks a bare shell cannot run, by page and line, in order, each
%% with what the shell answered it: the site written, each page's blocks
%% offered and those the file lists, and each judged.
found() ->
    _ = file:del_dir_r(?OUT),
    ok = filelib:ensure_dir(?OUT),
    Commit = string:trim(ern_integration_tests:succeed("git rev-parse HEAD")),
    ern_integration_tests:succeed("../bin/ern run ../build/tools/site.erc .. " ++ ?OUT
                                  ++ " 9.9.9 " ++ binary_to_list(Commit)
                                  ++ " fixtures/site/config.json"),
    Listed = listed(),
    Pages = [{address(File), read(File)} || File <- pages(), address(File) =/= "/"],
    {Offered, Named} =
        lists:foldl(fun({Address, Page}, {Shared, Alone}) ->
                        {Own, Kept} = blocks(Address, Page, Listed),
                        {[Own | Shared], Kept ++ Alone}
                    end, {[], []}, Pages),
    Code = [[Block || #block{kind = Kind} = Block <- Own, Kind =/= transcript] || Own <- Offered],
    Transcripts = [Block || Own <- Offered, #block{kind = transcript} = Block <- Own],
    %% the blocks the file lists first, since one that never comes back
    %% holds its place for a whole wait, which the others then share
    Jobs = [{alone, Block} || Block <- Named]
           ++ [{shared, Blocks} || Blocks <- Code, Blocks =/= []]
           ++ [{alone, Block} || Block <- Transcripts],
    Failed = lists:append(parallel(fun judged/1, Jobs)),
    lists:ukeysort(1, [{{Address, Line}, Why}
                       || {#block{address = Address, line = Line}, Why} <- Failed]).

%% A page's blocks offered to the shell, and those of its blocks the file
%% lists, which it does not offer.
blocks(Address, Page, Listed) ->
    Pres = matches(Page, "<pre class=\"([a-z ]+)\"([^>]*)><code>(.*?)</code></pre>"),
    All = [block(Address, Class, Attributes, Body) || [Class, Attributes, Body] <- Pres],
    Offered = [Block || {true, Block} <- All],
    Named = [Block || {false, #block{line = Line} = Block} <- All,
                      lists:member({Address, Line}, Listed)],
    {Offered, Named}.

block(Address, Class, Attributes, Body) ->
    Offered = binary:match(Attributes, [<<"data-shell=\"paste\"">>,
                                         <<"data-shell=\"load\"">>]) =/= nomatch,
    Text = text(Body),
    Lines = binary:split(Text, <<"\n">>, [global]),
    case binary:match(Class, <<"transcript">>) of
        nomatch ->
            Kind = case [Line || <<"export fn main(", _/binary>> = Line <- Lines] of
                       [] -> paste;
                       _ -> load
                   end,
            {Offered, #block{address = Address, line = hd(Lines), kind = Kind, text = Text}};
        _ ->
            Inputs = [Input || <<"> ", Input/binary>> <- Lines],
            Shown = length([Line || Line <- Lines, is_trouble(Line)]),
            {Offered, #block{address = Address, line = first(Inputs), kind = transcript,
                             text = Text, inputs = Inputs, shown = Shown}}
    end.

first([Input | _]) -> Input;
first([]) -> <<>>.

%% The blocks of a job the shell could not run. A page's blocks share a
%% session, and one that fails there, or never comes back to its prompt,
%% is judged again alone; the blocks after one that never came back run in
%% a session of their own.
judged({alone, Block}) ->
    case alone(Block) of
        ran -> [];
        {failed, Why} -> [{Block, Why}]
    end;
judged({shared, []}) ->
    [];
judged({shared, Blocks}) ->
    Numbered = lists:enumerate(Blocks),
    Steps = [{expect, "> "}]
            ++ lists:append([pasted(Block) ++ [{send, hex(":forget *\r")}] ++ done(N)
                             || {N, Block} <- Numbered])
            ++ [{send, "04"}],
    {_, Output, _} = ern_pty:tried(shell(), Steps, []),
    Segments = segments(plain(Output), length(Blocks)),
    Answered = length(Segments),
    Judged = [Block || {Segment, Block} <- lists:zip(Segments, lists:sublist(Blocks, Answered)),
                       is_failed(Segment)],
    Confirmed = [{Block, Why} || Block <- Judged, {failed, Why} <- [alone(Block)]],
    case Answered < length(Blocks) of
        true ->
            Hung = [{Block, Why} || Block <- [lists:nth(Answered + 1, Blocks)],
                                    {failed, Why} <- [alone(Block)]],
            Confirmed ++ Hung ++ judged({shared, lists:nthtail(Answered + 1, Blocks)});
        false ->
            Confirmed
    end.

%% One block in a bare shell of its own: whether the shell ran it, and
%% where it did not, what it answered.
alone(Block) ->
    Steps = [{expect, "> "}] ++ pasted(Block) ++ done(1) ++ [{send, "04"}],
    {_, Output, Unmet} = ern_pty:tried(shell(), Steps, []),
    case {Unmet, segments(plain(Output), 1)} of
        {[], [Segment]} -> verdict(Block, Segment);
        _ -> {failed, <<"no prompt came back: ", (last(plain(Output)))/binary>>}
    end.

verdict(#block{kind = transcript, shown = Shown}, Segment) ->
    case troubles(Segment) =:= Shown of
        true -> ran;
        false -> {failed, trouble_lines(Segment)}
    end;
verdict(_, Segment) ->
    case is_failed(Segment) of
        true -> {failed, trouble_lines(Segment)};
        false -> ran
    end.

trouble_lines(Text) ->
    lists:join(<<" / ">>, [Line || Line <- binary:split(Text, <<"\n">>, [global]),
                                   is_trouble(Line)]).

last(Text) ->
    binary:part(Text, max(0, byte_size(Text) - 200), min(200, byte_size(Text))).

is_failed(Segment) ->
    troubles(Segment) > 0.

%% The keys the client sends for a block: each input a paste, as the
%% terminal brackets one, and Enter; a Load's `main()` after it, entered.
pasted(#block{kind = transcript, inputs = Inputs}) ->
    [{send, bracketed(Input) ++ "0d"} || Input <- Inputs];
pasted(#block{kind = load, text = Text}) ->
    [{send, bracketed(Text) ++ "0d" ++ hex("main()\r")}];
pasted(#block{text = Text}) ->
    [{send, bracketed(Text) ++ "0d"}].

bracketed(Text) ->
    Typed = binary:replace(string:trim(Text, trailing), <<"\n">>, <<"\r">>, [global]),
    "1b5b3230307e" ++ hex(binary_to_list(Typed)) ++ "1b5b3230317e".

%% An input after a block that the shell answers only once the block's own
%% inputs have run, and the answer waited for.
done(N) ->
    [{send, hex(marker(N) ++ "\r")}, {expect, marker(N) ++ " : String"}].

marker(N) ->
    "\"ern-bare-shell-" ++ integer_to_list(N) ++ "\"".

%% The text before each marker's answer, the first N of them that came.
segments(Text, N) ->
    segments(Text, 1, N).

segments(_, Index, N) when Index > N ->
    [];
segments(Text, Index, N) ->
    case binary:split(Text, list_to_binary(marker(Index) ++ " : String")) of
        [Before, After] -> [Before | segments(After, Index + 1, N)];
        [_] -> []
    end.

%% The diagnostics and the faults a text holds, each a line of its own.
troubles(Text) ->
    length([Line || Line <- binary:split(Text, <<"\n">>, [global]), is_trouble(Line)]).

is_trouble(Line) ->
    re:run(Line, "^(input [0-9]+:[0-9]+:[0-9]+: |fault: )") =/= nomatch.

%% What the terminal was written, as text: its escape sequences left out,
%% and a carriage return, by which the shell goes back to a line's start to
%% draw it again, a line's end, so that what it writes there stands on a
%% line of its own.
plain(Output) ->
    Uncolored = re:replace(Output, "\e\\[[0-9;?]*[A-Za-z]", "", [global, {return, binary}]),
    binary:replace(Uncolored, <<"\r">>, <<"\n">>, [global]).

%% A bare shell in a directory of its own, its home and its working
%% directory, where a block that writes a file writes it, which a run
%% makes and removes.
shell() ->
    Home = filename:join(ern_pty:run_dir(),
                         "ern_bare_" ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_dir(Home ++ "/"),
    Ern = filename:absname("../bin/ern"),
    "cd " ++ Home ++ " && HOME=" ++ Home ++ " NO_COLOR=1 " ++ Ern ++ " shell; rm -rf " ++ Home.

%% Each job's answer, the jobs run side by side, twice as many at once as
%% the host has schedulers, since a job waits on its shell as much as it
%% runs.
parallel(F, Jobs) ->
    Width = 2 * erlang:system_info(schedulers_online),
    parallel(F, Jobs, Width, #{}, 0, []).

parallel(_, [], _, Running, _, Done) when map_size(Running) =:= 0 ->
    [Answer || {_, Answer} <- lists:sort(Done)];
parallel(F, [Job | Rest], Width, Running, Index, Done) when map_size(Running) < Width ->
    Self = self(),
    {Pid, Ref} = spawn_monitor(fun() -> Self ! {self(), F(Job)} end),
    parallel(F, Rest, Width, Running#{Pid => {Index, Ref}}, Index + 1, Done);
parallel(F, Jobs, Width, Running, Index, Done) ->
    receive
        {Pid, Answer} when is_map_key(Pid, Running) ->
            {Order, Ref} = maps:get(Pid, Running),
            erlang:demonitor(Ref, [flush]),
            parallel(F, Jobs, Width, maps:remove(Pid, Running), Index, [{Order, Answer} | Done]);
        {'DOWN', _, process, Pid, Reason} when is_map_key(Pid, Running) ->
            erlang:error({job_failed, Reason})
    end.

%% A block's text as the page shows it: its tags left out and its
%% characters unescaped.
text(Html) ->
    Plain = re:replace(Html, "<[^>]*>", "", [global, {return, binary}]),
    lists:foldl(fun({Entity, Char}, Acc) -> binary:replace(Acc, Entity, Char, [global]) end,
                Plain, [{<<"&lt;">>, <<"<">>}, {<<"&gt;">>, <<">">>}, {<<"&quot;">>, <<"\"">>},
                        {<<"&#39;">>, <<"'">>}, {<<"&amp;">>, <<"&">>}]).

%% The site's pages, by their paths under the site's directory.
pages() ->
    lists:sort([File || File <- filelib:wildcard("**/*.html", ?OUT)]).

%% A page's address, a directory's page by the directory, `/why/`.
address(File) ->
    case filename:basename(File) of
        "index.html" ->
            case filename:dirname(File) of
                "." -> "/";
                Directory -> "/" ++ Directory ++ "/"
            end;
        _ ->
            "/" ++ File
    end.

read(File) ->
    {ok, Bytes} = file:read_file(filename:join(?OUT, File)),
    Bytes.

matches(Text, Pattern) ->
    case re:run(Text, Pattern, [global, dotall, {capture, all_but_first, binary}]) of
        {match, Found} -> Found;
        nomatch -> []
    end.

hex(Text) ->
    lists:flatten([io_lib:format("~2.16.0b", [Char]) || Char <- Text]).
