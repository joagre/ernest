%% src/shared/ern_chunk.erl: a compiled module's chunk read as data alone.
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
not_data_test() ->
    ?assertEqual(error, ern_chunk:term(term_to_binary(fun erlang:halt/0))),
    ?assertEqual(error, ern_chunk:term(term_to_binary({ok, self()}))),
    ?assertEqual(error, ern_chunk:term(term_to_binary(make_ref()))),
    ?assertEqual(error, ern_chunk:term(term_to_binary({lists:duplicate(1000, a), fun erlang:halt/0},
                                                      [compressed]))),
    Whole = term_to_binary({a, [1, 2, 3]}),
    ?assertEqual(error, ern_chunk:term(binary:part(Whole, 0, byte_size(Whole) - 1))),
    ?assertEqual(error, ern_chunk:term(<<Whole/binary, 0>>)),
    ?assertEqual(error, ern_chunk:term(<<"not a term">>)),
    ?assertEqual(error, ern_chunk:term(<<>>)).

%% report §11.1: a chunk with more names new to the host than the host has
%% room for makes none of them. A regression test: reading one filled the
%% host's table of names, which ends the host
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

%% report §11.1: a compressed chunk, as the canonical forms are written, is
%% read as data as a plain one is
compressed_data_test() ->
    Term = {1, [{definition, ['T', f], function, <<0:256>>, {literal, int, 42}, none}
                || _ <- lists:seq(1, 50)]},
    Chunk = term_to_binary(Term, [compressed]),
    ?assertMatch(<<131, 80, _/binary>>, Chunk),
    ?assertEqual({ok, Term}, ern_chunk:term(Chunk)).

%% report §11.1: a compressed chunk whose inflated size is past deflate's own
%% ratio, 1032 to 1, is refused before it is inflated, and one that inflates
%% to another size than it claims, or within itself to a second compressed
%% term, is refused too. A regression test, written with the compressed
%% chunk: nothing else bounds what an inflated chunk may take of memory
compressed_bound_test() ->
    <<131, 80, Size:32, Compressed/binary>> =
        term_to_binary(lists:duplicate(100000, 0), [compressed]),
    Past = 1032 * byte_size(Compressed) + 1,
    ?assertEqual(error, ern_chunk:term(<<131, 80, Past:32, Compressed/binary>>)),
    ?assertEqual(error, ern_chunk:term(<<131, 80, (Size - 1):32, Compressed/binary>>)),
    ?assertMatch({ok, _}, ern_chunk:term(<<131, 80, Size:32, Compressed/binary>>)),
    <<131, Inner/binary>> = term_to_binary(lists:duplicate(1000, 0), [compressed]),
    Nested = zlib:compress(Inner),
    ?assertEqual(error, ern_chunk:term(<<131, 80, (byte_size(Inner)):32, Nested/binary>>)).

%% report §11: a compiled module whose atoms the host cannot read, its atom
%% chunk empty, a name in it not UTF-8, or a name running past the chunk, is
%% no compiled module to a chunk's read and to the host's digest alike, as
%% bytes that are no module are; a module's chunk is read, and a chunk it
%% does not hold is missing. A regression test: the host's reader raised
%% and its digest answered the raise as a value (docs/otp_bugs.md, 18)
unreadable_atoms_test() ->
    lists:foreach(fun(Atoms) ->
                      Module = module(Atoms),
                      ?assertEqual({Atoms, error}, {Atoms, ern_chunk:read(Module, <<"ErnI">>)}),
                      ?assertEqual({Atoms, error}, {Atoms, ern_chunk:md5(Module)})
                  end, [<<>>, <<1:32, 1, 16#FF>>, <<-1:32/signed, 16#50, "ab">>]),
    ?assertEqual(error, ern_chunk:read(<<"not a module">>, <<"ErnI">>)),
    ?assertEqual(error, ern_chunk:md5(<<"not a module">>)),
    {ok, Host} = file:read_file(code:which(lists)),
    ?assertMatch({ok, <<_:32/signed, _/binary>>}, ern_chunk:read(Host, <<"AtU8">>)),
    ?assertEqual(missing, ern_chunk:read(Host, <<"ErnI">>)),
    ?assertEqual({ok, lists:module_info(md5)}, ern_chunk:md5(Host)).

%% A compiled module of one chunk, the atoms Atoms, padded as the host pads
%% a chunk.
module(Atoms) ->
    Padding = (4 - byte_size(Atoms) rem 4) rem 4,
    Chunk = <<"AtU8", (byte_size(Atoms)):32, Atoms/binary, 0:(8 * Padding)>>,
    <<"FOR1", (4 + byte_size(Chunk)):32, "BEAM", Chunk/binary>>.
