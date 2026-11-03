%% The primitive behind Base64.decode (report Appendix G.8), from the
%% Erlang side: what it reads and what it refuses. Regression tests,
%% written with the code; libs/base64's own cases run the same refusals
%% through the module's foreign function.
-module(ern_base64_tests).

-include_lib("eunit/include/eunit.hrl").

%% report Appendix G.8: RFC 4648's test vectors (§10), and the empty text
vectors_test() ->
    ?assertEqual([{'Some', Bytes} || Bytes <- [<<>>, <<"f">>, <<"fo">>, <<"foo">>, <<"foob">>,
                                                <<"fooba">>, <<"foobar">>]],
                 [ern_base64:decode(Text)
                  || Text <- [<<>>, <<"Zg==">>, <<"Zm8=">>, <<"Zm9v">>, <<"Zm9vYg==">>,
                              <<"Zm9vYmE=">>, <<"Zm9vYmFy">>]]).

%% report Appendix G.8: each of the four characters the host's decoder
%% skips, in a text whose count is a multiple of four, which the host
%% reads
white_space_test() ->
    ?assertEqual([], refused_by_host([<<"Zm9v    ">>, <<"Zm\t\t\t\t9v">>, <<"Zg==\r\n\r\n">>,
                                      <<"Z  g=  =">>])).

%% report Appendix G.8: a character outside the standard alphabet
outside_alphabet_test() ->
    ?assertEqual([], read([<<"Zm-v">>, <<"Zm_v">>, <<"Zm9", 16#e9/utf8>>, <<"Zm9v\v\v\v\v">>])).

%% report Appendix G.8: a count of characters that is no multiple of four
count_test() ->
    ?assertEqual([], read([<<"Z">>, <<"Zg">>, <<"Zg=">>, <<"Zm9vY">>])).

%% report Appendix G.8: a `=` anywhere but as the last one or two
%% characters
padding_test() ->
    ?assertEqual([], read([<<"Zg===">>, <<"Z===">>, <<"====">>, <<"Zm=v">>, <<"=Zm9">>,
                           <<"Zg==Zg==">>])).

%% report Appendix G.8: a last character before a `=` that sets a bit the
%% bytes do not use, which the host reads as the text `encode` writes
unused_bits_test() ->
    ?assertEqual([], refused_by_host([<<"Zh==">>, <<"Zm9=">>])).

%% report Appendix G.8: of every text of four characters that begins with
%% `Q`, its other three each a character of the alphabet, `=` or a space,
%% those `encode` writes are read, 64^3 of three bytes, 64 * 16 of two and
%% 4 of one, and every other is refused
exactly_written_test_() ->
    {timeout, 60, fun exactly_written/0}.

exactly_written() ->
    Characters = <<"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/= ">>,
    Texts = [<<"Q", X, Y, Z>> || <<X>> <= Characters, <<Y>> <= Characters, <<Z>> <= Characters],
    %% a fold, whose stack does not grow with the texts, since the host's
    %% raise on a refused text costs time as the stack is deep
    Read = lists:foldl(fun(Text, Acc) ->
                           case ern_base64:decode(Text) of
                               {'Some', Bytes} -> [{Text, Bytes} | Acc];
                               'None' -> Acc
                           end
                       end, [], Texts),
    ?assertEqual(64 * 64 * 64 + 64 * 16 + 4, length(Read)),
    ?assertEqual([], [Text || {Text, Bytes} <- Read, base64:encode(Bytes) =/= Text]).

%% report Appendix G.8: decode reads what encode writes as the bytes it
%% was written from, for every count from 0 to 256 of every byte's value
read_back_test() ->
    All = list_to_binary(lists:seq(0, 255)),
    ?assertEqual([], [Count || Count <- lists:seq(0, 256),
                               Bytes <- [binary:part(All, 0, min(Count, 256))],
                               ern_base64:decode(base64:encode(Bytes)) =/= {'Some', Bytes}]).

%% The texts of Texts that decode reads, which should be none.
read(Texts) ->
    [Text || Text <- Texts, ern_base64:decode(Text) =/= 'None'].

%% The texts of Texts that the host reads and decode does not refuse, which
%% should be none: each is a text the host reads that encode does not
%% write.
refused_by_host(Texts) ->
    [Text || Text <- Texts, is_binary(base64:decode(Text)), ern_base64:decode(Text) =/= 'None'].
