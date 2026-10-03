%% erl/utils/src/ern_chunk.erl: a compiled module's chunk read as data alone.
-module(ern_chunk_tests).

-include_lib("eunit/include/eunit.hrl").

%% report §11.1: what the compiler writes is read back as it was written
plain_data_test() ->
    Term = {interface, ['Net', 'Http'], [{[parse], {scheme, [{1, []}], {tcon, ['Int'], []}}}],
            #{format => 4, deps => [{['List'], <<1, 2, 3>>}], text => "abc", none => [],
              big => 1 bsl 80, small => -7, float => 1.5, wide => lists:seq(1, 300)}},
    ?assertEqual({ok, Term}, ern_chunk:term(term_to_binary(Term))).

%% report §11.1: a chunk that holds a function, a process, or a term the
%% compiler does not write is refused, and so is one cut short or one that
%% is no term. A regression test: the host's decoder took each
%% (findings.md's C3-29)
not_data_test() ->
    ?assertEqual(error, ern_chunk:term(term_to_binary(fun erlang:halt/0))),
    ?assertEqual(error, ern_chunk:term(term_to_binary({ok, self()}))),
    ?assertEqual(error, ern_chunk:term(term_to_binary(make_ref()))),
    ?assertEqual(error, ern_chunk:term(term_to_binary(lists:duplicate(1000, a), [compressed]))),
    Whole = term_to_binary({a, [1, 2, 3]}),
    ?assertEqual(error, ern_chunk:term(binary:part(Whole, 0, byte_size(Whole) - 1))),
    ?assertEqual(error, ern_chunk:term(<<Whole/binary, 0>>)),
    ?assertEqual(error, ern_chunk:term(<<"not a term">>)),
    ?assertEqual(error, ern_chunk:term(<<>>)).

%% report §11.1: a chunk with more names new to the host than the host has
%% room for makes none of them. A regression test: reading one filled the
%% host's table of names, which ends the host (findings.md's C3-29)
too_many_names_test_() ->
    {timeout, 120, fun too_many_names/0}.

too_many_names() ->
    Before = erlang:system_info(atom_count),
    Left = erlang:system_info(atom_limit) - Before,
    Names = [<<"ern_chunk_test_name_", (integer_to_binary(Number))/binary>>
             || Number <- lists:seq(1, Left div 2 + 1)],
    Chunk = iolist_to_binary([131, 108, <<(length(Names)):32>>,
                              [[119, byte_size(Name), Name] || Name <- Names], 106]),
    ?assertEqual(error, ern_chunk:term(Chunk)),
    ?assertEqual(Before, erlang:system_info(atom_count)).
