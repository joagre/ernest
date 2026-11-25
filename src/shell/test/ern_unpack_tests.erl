%% `ern unpack` (report §11.9): the job run whole, `Ernest.Unpack` over its
%% host half `src/shell/ern_unpack.erl`, in a root package of the test's
%% own, over archives the tests write themselves, header by header, so that
%% a hostile one needs no tool.
-module(ern_unpack_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("kernel/include/file.hrl").

%%
%% What is unpacked
%%

%% report §11.9, Appendix E.17: an archive unpacked as `lib/leaf`: its
%% files, a directory a member stands in that is no member, an empty
%% directory, a file its owner may run, which whoever may read it may run,
%% and one it may not, a set-ID bit that reaches no file, each made with the
%% bits the mask leaves, a name given twice of which the last stands, a
%% leading `./` and an empty and a `.` segment, which name nothing, and a pax
%% global header, passed over as `git archive` writes one. The job says
%% nothing, leaves `lib/.unpack` and nothing beside `lib/leaf`, and a second
%% run does nothing and says nothing.
unpacks_test() ->
    in_root(fun() ->
        Archive = archive([global_header(),
                           {<<"./leaf-1.2.0/">>, $5, 8#755, <<>>},
                           {<<"leaf-1.2.0/package.conf">>, $0, 8#644, manifest_text([])},
                           {<<"./leaf-1.2.0//VERSION">>, $0, 8#644, <<"1.2.0\n">>},
                           {<<"leaf-1.2.0/a/./b">>, $0, 8#644, <<"b">>},
                           {<<"leaf-1.2.0/empty/">>, $5, 8#700, <<>>},
                           {<<"leaf-1.2.0/run.sh">>, $0, 8#744, <<"#!/bin/sh\n">>},
                           {<<"leaf-1.2.0/setid">>, $0, 8#6755, <<"s">>},
                           {<<"leaf-1.2.0/contiguous">>, $7, 8#644, <<"c">>},
                           {<<"leaf-1.2.0/twice">>, $0, 8#755, <<"one">>},
                           {<<"leaf-1.2.0/twice">>, $0, 8#644, <<"two">>}]),
        put_archive("leaf", "1.2.0", Archive),
        manifest([{"leaf", "1.2.0", none, digest(Archive)}]),
        ?assertEqual({0, <<>>}, unpack()),
        Mask = ern_os:umask(),
        Plain = 8#666 band bnot Mask,
        Runnable = Plain bor ((Plain band 8#444) bsr 2),
        Directory = 8#777 band bnot Mask,
        ?assertEqual([{"lib/leaf", directory, Directory, none},
                      {"lib/leaf/VERSION", regular, Plain, <<"1.2.0\n">>},
                      {"lib/leaf/a", directory, Directory, none},
                      {"lib/leaf/a/b", regular, Plain, <<"b">>},
                      {"lib/leaf/contiguous", regular, Plain, <<"c">>},
                      {"lib/leaf/empty", directory, Directory, none},
                      {"lib/leaf/package.conf", regular, Plain, manifest_text([])},
                      {"lib/leaf/run.sh", regular, Runnable, <<"#!/bin/sh\n">>},
                      {"lib/leaf/setid", regular, Runnable, <<"s">>},
                      {"lib/leaf/twice", regular, Plain, <<"two">>}],
                     tree("lib/leaf")),
        ?assertEqual([".unpack", "leaf", "leaf-1.2.0.tar.gz"], names("lib")),
        Before = held("lib"),
        ?assertEqual({0, <<>>}, unpack()),
        ?assertEqual(Before, held("lib"))
    end).

%% report §11.9, §11.2: a package's `ebin` and its `priv`, unpacked by `ern
%% unpack`, stand where a run finds them: its `ebin` on the load path, as an
%% application's, and its `priv` beside it, which the host's `code:priv_dir`
%% finds by the package's name, through a module of the package's that a
%% program over it calls
priv_test() ->
    in_root(fun() ->
        Archive = archive([{<<"leaf-1.2.0/package.conf">>, $0, 8#644, manifest_text([])},
                           {<<"leaf-1.2.0/VERSION">>, $0, 8#644, <<"1.2.0\n">>},
                           {<<"leaf-1.2.0/ebin/ern_leaf_priv.beam">>, $0, 8#644, priv_beam()},
                           {<<"leaf-1.2.0/priv/greeting.txt">>, $0, 8#644, <<"from priv">>}]),
        put_archive("leaf", "1.2.0", Archive),
        manifest([{"leaf", "1.2.0", none, digest(Archive)}]),
        ?assertEqual({0, <<>>}, unpack()),
        write("given.ern", <<"foreign fn greeting() : String =\n"
                             "    \"ern_leaf_priv:greeting/0\"\n\n"
                             "export fn main() : Unit = Io.println(greeting())\n">>),
        ?assertEqual({0, <<>>}, printed(["build", "given.ern"])),
        ?assertEqual({0, <<"from priv\n">>}, printed(["run", "given.erc"]))
    end).

%% A job's status, and what it wrote on standard output and standard error,
%% both EUnit's group leader, which keeps what it is given, asked of it
%% before and after.
printed(Args) ->
    Before = captured(),
    Status = ern_cli:ern(Args, group_leader()),
    After = captured(),
    {Status, binary:part(After, byte_size(Before), byte_size(After) - byte_size(Before))}.

captured() ->
    group_leader() ! {get_output, self()},
    receive {output, Output} -> unicode:characters_to_binary(Output) end.

%% The module of the package's own: the text of its `priv`'s file, which
%% the host finds by the application's name, the package's.
priv_beam() ->
    Forms = [{attribute, 1, module, ern_leaf_priv},
             {attribute, 1, export, [{greeting, 0}]},
             {function, 1, greeting, 0,
              [{clause, 1, [], [],
                [{match, 1, {tuple, 1, [{atom, 1, ok}, {var, 1, 'Text'}]},
                  {call, 1, {remote, 1, {atom, 1, file}, {atom, 1, read_file}},
                   [{call, 1, {remote, 1, {atom, 1, filename}, {atom, 1, join}},
                     [{call, 1, {remote, 1, {atom, 1, code}, {atom, 1, priv_dir}},
                       [{atom, 1, leaf}]},
                      {string, 1, "greeting.txt"}]}]}},
                 {var, 1, 'Text'}]}]}],
    {ok, ern_leaf_priv, Beam} = compile:forms(Forms, []),
    Beam.

%%
%% The refusals
%%

%% report §11.9, §11: started where there is no manifest the job is
%% refused, and given an argument it is refused as taking none, with its
%% usage, before it reads its root package
no_manifest_test() ->
    in_root(fun() ->
        ?assertEqual({1, <<"ern unpack: package.conf: no such file\n">>}, unpack()),
        write("package.conf", <<"{">>),
        {Status, Said} = said(["unpack", "x"]),
        ?assertMatch({1, {0, _}},
                     {Status, binary:match(Said, <<"ern unpack: unpack takes no argument\n"
                                                   "Usage: ern unpack\n">>)})
    end).

%% report §11.9: an entry with no `sha256`, its archive's SHA-256 given where
%% the archive is there, and an archive that is not there, said with where to
%% put it and, where the entry has a `url`, what to download; a line each, in
%% the manifest's order, and a refusal of one stops no other
no_digest_and_no_archive_test() ->
    in_root(fun() ->
        Archive = package_archive("leaf", "1.2.0", []),
        put_archive("leaf", "1.2.0", Archive),
        put_archive("whole", "1.0.0", package_archive("whole", "1.0.0", [])),
        Url = "https://example.org/epx/epx-0.2.1.tar.gz",
        manifest([{"leaf", "1.2.0", none, none},
                  {"bare", "0.1.0", none, none},
                  {"epx", "0.2.1", Url, digest(<<"x">>)},
                  {"mid", "0.4.0", none, digest(<<"x">>)},
                  {"whole", "1.0.0", none,
                   digest(package_archive("whole", "1.0.0", []))}]),
        ?assertEqual({1, lines(["package.conf: the entry for leaf has no sha256;"
                                " lib/leaf-1.2.0.tar.gz has " ++ digest(Archive),
                                "package.conf: the entry for bare has no sha256",
                                "package.conf: bare 0.1.0 is not under lib; put"
                                " bare-0.1.0.tar.gz in lib",
                                "package.conf: epx 0.2.1 is not under lib; download " ++ Url
                                ++ " to lib/epx-0.2.1.tar.gz",
                                "package.conf: mid 0.4.0 is not under lib; put"
                                " mid-0.4.0.tar.gz in lib"])},
                     unpack()),
        ?assertEqual(["VERSION", "package.conf"], names("lib/whole")),
        ?assertNot(filelib:is_file("lib/leaf"))
    end).

%% report §11.9: an archive whose SHA-256 is not the entry's, written whole
%% where the report cuts it short, and read no further, the host's reason for
%% one it cannot read, a truncated one's and one that holds a name that is
%% not UTF-8, in a header or in a pax record, which the host gives the words
%% of a header's; and one that reaches no regular file
digest_and_unreadable_test() ->
    in_root(fun() ->
        Good = package_archive("leaf", "1.2.0", []),
        Wrong = digest(<<"another">>),
        put_archive("leaf", "1.2.0", Good),
        Truncated = binary:part(package_archive("cut", "1.0.0", []), 0, 40),
        put_archive("cut", "1.0.0", Truncated),
        Header = archive([{<<"named-1.0.0/", 255>>, $0, 8#644, <<"x">>}]),
        put_archive("named", "1.0.0", Header),
        Pax = archive([pax_name(<<"paxed-1.0.0/", 255>>),
                       {<<"paxed-1.0.0/x">>, $0, 8#644, <<"x">>}]),
        put_archive("paxed", "1.0.0", Pax),
        ok = file:make_dir("lib/dir-1.0.0.tar.gz"),
        manifest([{"leaf", "1.2.0", none, Wrong},
                  {"cut", "1.0.0", none, digest(Truncated)},
                  {"named", "1.0.0", none, digest(Header)},
                  {"paxed", "1.0.0", none, digest(Pax)},
                  {"dir", "1.0.0", none, Wrong}]),
        ?assertEqual({1, lines(["lib/leaf-1.2.0.tar.gz: its sha256 is " ++ digest(Good)
                                ++ ", and the entry for leaf says " ++ Wrong,
                                "lib/cut-1.0.0.tar.gz: Unexpected end of file",
                                "lib/named-1.0.0.tar.gz: Unrecognized tar header format:"
                                " invalid_string",
                                "lib/paxed-1.0.0.tar.gz: Unrecognized tar header format:"
                                " invalid_string",
                                "lib/dir-1.0.0.tar.gz: is no regular file"])},
                     unpack()),
        ?assertEqual([".unpack", "cut-1.0.0.tar.gz", "dir-1.0.0.tar.gz", "leaf-1.2.0.tar.gz",
                      "named-1.0.0.tar.gz", "paxed-1.0.0.tar.gz"],
                     names("lib"))
    end).

%% report §11.9, §11: a member of each kind refused, a symbolic link, a hard
%% link, a named pipe and the two devices, a name outside the archive's
%% directory, one with a `..` and one that names nothing, `./`, which the
%% host gives as `.`, each a line in the archive's order, a control
%% character in a name written `\xHH`; nothing of the archive is unpacked
members_test() ->
    in_root(fun() ->
        Kinds = [{<<"leaf-1.2.0/", Name/binary>>, Type, 8#644, <<>>}
                 || {Name, Type} <- [{<<"symlink">>, $2}, {<<"hard">>, $1}, {<<"fifo">>, $6},
                                     {<<"char">>, $3}, {<<"block">>, $4}]],
        Archive = archive([{<<"leaf-1.2.0/package.conf">>, $0, 8#644, manifest_text([])},
                           {<<"leaf-1.2.0/VERSION">>, $0, 8#644, <<"1.2.0\n">>}
                           | Kinds]
                          ++ [{<<"other-1.0/x">>, $0, 8#644, <<>>},
                              {<<"leaf-1.2.0/a/../b">>, $0, 8#644, <<>>},
                              {<<"./">>, $5, 8#755, <<>>},
                              {<<"leaf-1.2.0/e\esc">>, $6, 8#644, <<>>}]),
        put_archive("leaf", "1.2.0", Archive),
        manifest([{"leaf", "1.2.0", none, digest(Archive)}]),
        Neither = " is neither a directory nor a regular file",
        ?assertEqual({1, lines([["lib/leaf-1.2.0.tar.gz: leaf-1.2.0/", Name, Neither]
                                || Name <- ["symlink", "hard", "fifo", "char", "block"]]
                               ++ ["lib/leaf-1.2.0.tar.gz: other-1.0/x stands outside leaf-1.2.0",
                                   "lib/leaf-1.2.0.tar.gz: leaf-1.2.0/a/../b is no member's name",
                                   "lib/leaf-1.2.0.tar.gz: . is no member's name",
                                   "lib/leaf-1.2.0.tar.gz: leaf-1.2.0/e\\x1Bsc" ++ Neither])},
                     unpack()),
        ?assertEqual([".unpack", "leaf-1.2.0.tar.gz"], names("lib"))
    end).

%% report §11.9: an archive that holds no manifest, one that holds no
%% `VERSION`, one whose `VERSION` is not of its form, and one whose `VERSION`
%% says another version; a directory named `VERSION` is none
package_test() ->
    in_root(fun() ->
        Conf = fun(Dir) -> {<<Dir/binary, "/package.conf">>, $0, 8#644, manifest_text([])} end,
        Version = fun(Dir, Text) -> {<<Dir/binary, "/VERSION">>, $0, 8#644, Text} end,
        Archives = [{"noconf", archive([Version(<<"noconf-1.0.0">>, <<"1.0.0\n">>)])},
                    {"nover", archive([Conf(<<"nover-1.0.0">>),
                                       {<<"nover-1.0.0/VERSION/">>, $5, 8#755, <<>>}])},
                    {"form", archive([Conf(<<"form-1.0.0">>),
                                      Version(<<"form-1.0.0">>, <<"1.0.0">>)])},
                    {"other", archive([Conf(<<"other-1.0.0">>),
                                       Version(<<"other-1.0.0">>, <<"1.3.0\n">>)])}],
        [put_archive(Name, "1.0.0", Archive) || {Name, Archive} <- Archives],
        manifest([{Name, "1.0.0", none, digest(Archive)} || {Name, Archive} <- Archives]),
        ?assertEqual({1, lines(["lib/noconf-1.0.0.tar.gz: holds no package.conf",
                                "lib/nover-1.0.0.tar.gz: holds no VERSION",
                                "lib/form-1.0.0.tar.gz: form-1.0.0/VERSION is not one line that"
                                " holds a version",
                                "lib/other-1.0.0.tar.gz: holds other 1.3.0, and the entry for"
                                " other says 1.0.0"])},
                     unpack())
    end).

%% report §11.9: what stands at an entry's name under `lib` and is not its
%% package at its version, a directory of another version, of no version
%% and of a `VERSION` not of its form, and a file, refused and left as it
%% is, its archive staying where it is, and `lib/.unpack` as it was; the
%% archive of a package refused so is judged all the same, its refusals
%% said after what stands, here a digest that is not its entry's; a
%% package at its entry's version, one linked by hand among them, is held
%% to nothing, its archive not read
standing_test() ->
    in_root(fun() ->
        Wrong = digest(<<"another">>),
        whole("other", "0.2.0"),
        ok = filelib:ensure_path("lib/none"),
        whole("form", "1.0.0"),
        write("lib/form/VERSION", <<"one\n">>),
        write("lib/file", <<"a file\n">>),
        write("lib/.unpack", <<>>),
        whole("held", "1.0.0"),
        Elsewhere = filename:absname("elsewhere"),
        ok = filelib:ensure_path(Elsewhere),
        write("elsewhere/VERSION", <<"1.0.0\n">>),
        ok = file:make_symlink(Elsewhere, "lib/linked"),
        [put_archive(Name, Version, package_archive(Name, Version, []))
         || {Name, Version} <- [{"other", "0.2.1"}, {"none", "1.0.0"}, {"form", "1.0.0"},
                                {"file", "1.0.0"}]],
        manifest([{"other", "0.2.1", none, digest(package_archive("other", "0.2.1", []))},
                  {"none", "1.0.0", none, Wrong},
                  {"form", "1.0.0", none, digest(package_archive("form", "1.0.0", []))},
                  {"file", "1.0.0", none, digest(package_archive("file", "1.0.0", []))},
                  {"held", "1.0.0", none, none},
                  {"linked", "1.0.0", none, none}]),
        Before = held("lib"),
        Remove = "; remove it, and ern unpack puts ",
        Digest = digest(package_archive("none", "1.0.0", [])),
        ?assertEqual({1, lines(["package.conf: the entry for other says 0.2.1, and lib/other holds"
                                " 0.2.0" ++ Remove ++ "0.2.1 there",
                                "package.conf: the entry for none says 1.0.0, and lib/none holds"
                                " no VERSION" ++ Remove ++ "1.0.0 there",
                                "lib/none-1.0.0.tar.gz: its sha256 is " ++ Digest
                                ++ ", and the entry for none says " ++ Wrong,
                                "package.conf: the entry for form says 1.0.0, and lib/form/VERSION"
                                " is not one line that holds a version" ++ Remove ++ "1.0.0 there",
                                "package.conf: the entry for file says 1.0.0, and lib/file is no"
                                " directory" ++ Remove ++ "1.0.0 there"])},
                     unpack()),
        ?assertEqual(Before, held("lib"))
    end).

%% report §11.9: the three `.beam` refusals: a name another named package's
%% `ebin` holds, that of its archive where it does not stand at its entry's
%% version, both archives refused, and that under `lib` where it does; a
%% name of the host's own module, and one named as a unit is. A package
%% under `lib` is held to none of them
beams_test() ->
    in_root(fun() ->
        Beam = fun(Dir, Name) -> {<<Dir/binary, "/ebin/", Name/binary>>, $0, 8#644, <<>>} end,
        Leaf = package_archive("leaf", "1.2.0", [Beam(<<"leaf-1.2.0">>, <<"util.beam">>),
                                                 Beam(<<"leaf-1.2.0">>, <<"lists.beam">>),
                                                 Beam(<<"leaf-1.2.0">>, <<"ern@leaf.beam">>),
                                                 Beam(<<"leaf-1.2.0">>, <<"own.beam">>)]),
        Mid = package_archive("mid", "0.4.0", [Beam(<<"mid-0.4.0">>, <<"util.beam">>)]),
        whole("under", "1.0.0"),
        write("lib/under/ebin/own.beam", <<>>),
        write("lib/under/ebin/lists.beam", <<>>),
        put_archive("leaf", "1.2.0", Leaf),
        put_archive("mid", "0.4.0", Mid),
        manifest([{"leaf", "1.2.0", none, digest(Leaf)},
                  {"mid", "0.4.0", none, digest(Mid)},
                  {"under", "1.0.0", none, none}]),
        ?assertEqual({1, lines(["lib/leaf-1.2.0.tar.gz: lists.beam is the host's own module,"
                                " which is found first",
                                "lib/leaf-1.2.0.tar.gz: ern@leaf.beam is named as a unit is",
                                "lib/leaf-1.2.0.tar.gz: util.beam is mid's too, and the host"
                                " loads one",
                                "lib/leaf-1.2.0.tar.gz: lists.beam is under's too, and the host"
                                " loads one",
                                "lib/leaf-1.2.0.tar.gz: own.beam is under's too, and the host"
                                " loads one",
                                "lib/mid-0.4.0.tar.gz: util.beam is leaf's too, and the host"
                                " loads one"])},
                     unpack()),
        ?assertEqual([".unpack", "leaf-1.2.0.tar.gz", "mid-0.4.0.tar.gz", "under"], names("lib"))
    end).

%%
%% What a run leaves
%%

%% report §11.9: a link at the entry's name is removed and not followed once
%% the archive has passed every check, and left by a refused archive; what an
%% earlier run left beside the name is removed, a link among it removed and
%% not followed, and nothing beside another name; nothing of a refused
%% archive is unpacked, and its refusal stops no other package
leaves_test() ->
    in_root(fun() ->
        ok = filelib:ensure_path("target/kept"),
        Target = filename:absname("target"),
        ok = file:make_symlink(Target, "lib/leaf"),
        ok = file:make_symlink(Target, "lib/mid"),
        write("lib/.leaf-1.2.0/half/written", <<"x">>),
        ok = file:make_symlink(Target, "lib/.leaf-0.9.0"),
        write("lib/.leafy-1.0.0", <<"another's">>),
        Leaf = package_archive("leaf", "1.2.0", []),
        Mid = package_archive("mid", "0.4.0", [{<<"mid-0.4.0/fifo">>, $6, 8#644, <<>>}]),
        put_archive("leaf", "1.2.0", Leaf),
        put_archive("mid", "0.4.0", Mid),
        manifest([{"mid", "0.4.0", none, digest(Mid)}, {"leaf", "1.2.0", none, digest(Leaf)}]),
        ?assertEqual({1, lines(["lib/mid-0.4.0.tar.gz: mid-0.4.0/fifo is neither a directory nor"
                                " a regular file"])},
                     unpack()),
        ?assertMatch({ok, #file_info{type = directory}}, file:read_link_info("lib/leaf")),
        ?assertEqual(["VERSION", "package.conf"], names("lib/leaf")),
        ?assertEqual({ok, Target}, file:read_link("lib/mid")),
        ?assertEqual(["kept"], names("target")),
        ?assertEqual([".leafy-1.0.0", ".unpack", "leaf", "leaf-1.2.0.tar.gz", "mid",
                      "mid-0.4.0.tar.gz"],
                     names("lib"))
    end).

%% report §11.9: a root package with no `lib` has nothing to unpack, takes
%% no lock and makes no `lib`, and each entry it must unpack is refused
no_lib_test() ->
    in_root(fun() ->
        ok = file:del_dir("lib"),
        manifest([{"leaf", "1.2.0", none, none}]),
        ?assertEqual({1, lines(["package.conf: the entry for leaf has no sha256",
                                "package.conf: leaf 1.2.0 is not under lib; put"
                                " leaf-1.2.0.tar.gz in lib"])},
                     unpack()),
        ?assertNot(filelib:is_file("lib"))
    end).

%%
%% The lock
%%

%% report §11.9: a run started while another holds `lib/.unpack` ends once
%% the other lets it go, and unpacks. The wait is shown by order, and no
%% wait is timed: before the holder lets go, the run's answer is looked for
%% once without waiting, a weak check, since the run may not yet have asked
%% for the lock. A `lib/.unpack` that reaches no regular file is not
%% opened, and is refused
lock_test() ->
    in_root(fun() ->
        Archive = package_archive("leaf", "1.2.0", []),
        put_archive("leaf", "1.2.0", Archive),
        manifest([{"leaf", "1.2.0", none, digest(Archive)}]),
        Self = self(),
        Holder = spawn(fun() ->
                           Self ! {held, ern_os:job_locked("lib/.unpack")},
                           receive stop -> ok end
                       end),
        ?assertEqual(locked, receive {held, Held} -> Held end),
        spawn(fun() -> Self ! {run, unpack()} end),
        Early = receive {run, Answer} -> {early, Answer} after 0 -> waiting end,
        Holder ! stop,
        ?assertEqual({waiting, {0, <<>>}}, {Early, receive {run, Said} -> Said end}),
        ?assertEqual(["VERSION", "package.conf"], names("lib/leaf")),
        ok = file:delete("lib/.unpack"),
        ok = file:make_dir("lib/.unpack"),
        ?assertEqual({1, <<"ern unpack: lib/.unpack: is no regular file\n">>}, unpack())
    end).

%% report §11.9: a link at `lib/.unpack` is refused with the host's reason,
%% as one at `ernest.pid` is, whether it leads to a regular file or to
%% nothing, and nothing is made where it leads
lock_link_test() ->
    in_root(fun() ->
        Archive = package_archive("leaf", "1.2.0", []),
        put_archive("leaf", "1.2.0", Archive),
        manifest([{"leaf", "1.2.0", none, digest(Archive)}]),
        Refused = {1, <<"ern unpack: lib/.unpack: too many levels of symbolic links\n">>},
        write("held", <<>>),
        ok = file:make_symlink("../held", "lib/.unpack"),
        ?assertEqual(Refused, unpack()),
        ok = file:delete("lib/.unpack"),
        ok = file:make_symlink("../nowhere", "lib/.unpack"),
        ?assertEqual(Refused, unpack()),
        ?assertEqual({error, enoent}, file:read_link_info("nowhere")),
        ?assertEqual(["leaf-1.2.0.tar.gz"], [Name || Name <- names("lib"), Name =/= ".unpack"])
    end).

%%
%% The archives
%%

%% A tar archive compressed by gzip of Members, each its name, its type
%% flag, its mode and its bytes, in order, each written as a ustar header
%% and its blocks.
archive(Members) ->
    Tar = << <<(member(Name, Type, Mode, Bytes))/binary>>
             || {Name, Type, Mode, Bytes} <- Members >>,
    zlib:gzip(<<Tar/binary, 0:(1024 * 8)>>).

member(Name, Type, Mode, Bytes) ->
    Blank = <<Name/binary, (zeros(100 - byte_size(Name)))/binary, (octal(Mode, 8))/binary,
              (octal(0, 8))/binary, (octal(0, 8))/binary, (octal(byte_size(Bytes), 12))/binary,
              (octal(0, 12))/binary, "        ", Type, (zeros(100))/binary, "ustar", 0, "00",
              (zeros(32))/binary, (zeros(32))/binary, (octal(0, 8))/binary, (octal(0, 8))/binary,
              (zeros(155 + 12))/binary>>,
    <<Before:148/binary, _:8/binary, After/binary>> = Blank,
    Sum = list_to_binary(io_lib:format("~6.8.0B", [lists:sum(binary_to_list(Blank))])),
    <<Before/binary, Sum/binary, 0, " ", After/binary, Bytes/binary,
      (zeros((512 - byte_size(Bytes) rem 512) rem 512))/binary>>.

octal(Value, Width) ->
    <<(list_to_binary(io_lib:format("~*.8.0B", [Width - 1, Value])))/binary, 0>>.

zeros(Count) ->
    binary:copy(<<0>>, Count).

%% A pax global header, as `git archive` writes one.
global_header() ->
    {<<"pax_global_header">>, $g, 8#666, pax_record(<<"comment">>, <<"0123abcd">>)}.

%% A pax extended header that names the member after it Name.
pax_name(Name) ->
    {<<"PaxHeader/x">>, $x, 8#644, pax_record(<<"path">>, Name)}.

%% A pax record, its length counting its own digits.
pax_record(Key, Value) ->
    Body = <<" ", Key/binary, "=", Value/binary, "\n">>,
    Length = byte_size(Body) + byte_size(integer_to_binary(byte_size(Body) + 2)),
    <<(integer_to_binary(Length))/binary, Body/binary>>.

%% The archive of the package Name at Version, its manifest naming none and
%% its `VERSION`, with Members after them.
package_archive(Name, Version, Members) ->
    Dir = list_to_binary([Name, "-", Version]),
    archive([{<<Dir/binary, "/package.conf">>, $0, 8#644, manifest_text([])},
             {<<Dir/binary, "/VERSION">>, $0, 8#644, list_to_binary([Version, "\n"])}
             | Members]).

put_archive(Name, Version, Bytes) ->
    write(["lib/", Name, "-", Version, ".tar.gz"], Bytes).

%% Report §11.9: an archive's SHA-256 as a manifest writes one.
digest(Bytes) ->
    binary_to_list(binary:encode_hex(crypto:hash(sha256, Bytes), lowercase)).

%%
%% The root package
%%

%% Run Run in a root package of its own, the working directory, which holds
%% an empty `lib`.
in_root(Run) ->
    Base = os:getenv("ERN_TEST_DIR", os:getenv("TMPDIR", "/tmp")),
    Dir = filename:join(Base, "ern_unpack_" ++ os:getpid() ++ "_"
                              ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(filename:join(Dir, "lib")),
    {ok, Cwd} = file:get_cwd(),
    ok = file:set_cwd(Dir),
    try Run() after file:set_cwd(Cwd) end.

%% The root package's manifest, naming Entries, each a name, a version, and
%% a `url` and a `sha256` or none.
manifest(Entries) ->
    write("package.conf", manifest_text(Entries)).

manifest_text(Entries) ->
    {Release, _} = lists:splitwith(fun(Char) -> Char =/= $- andalso Char =/= $+ end,
                                   ern_release:version_text()),
    iolist_to_binary(["{\"ernest\": \"", Release, "\", \"packages\": [",
                      lists:join(", ", [["{\"name\": \"", Name, "\", \"version\": \"", Version,
                                         "\"", given("url", Url), given("sha256", Sha256), "}"]
                                        || {Name, Version, Url, Sha256} <- Entries]),
                      "]}\n"]).

given(_Field, none) -> [];
given(Field, Value) -> [", \"", Field, "\": \"", Value, "\""].

%% Under `lib`, the package Name at Version as one stands there.
whole(Name, Version) ->
    write(["lib/", Name, "/package.conf"], manifest_text([])),
    write(["lib/", Name, "/VERSION"], [Version, "\n"]).

write(Path, Bytes) ->
    ok = filelib:ensure_dir(Path),
    ok = file:write_file(Path, Bytes).

%%
%% What a run says and leaves
%%

%% The job run in the working directory: its status, and what it wrote on
%% standard error.
unpack() ->
    said(["unpack"]).

said(Args) ->
    Self = self(),
    Device = spawn(fun() -> capture(Self, []) end),
    Status = ern_cli:ern(Args, Device),
    Device ! {done, Self},
    receive {captured, Bytes} -> {Status, Bytes} end.

%% An I/O server that keeps what it is given, as bytes.
capture(Owner, Acc) ->
    receive
        {io_request, From, ReplyAs, {put_chars, Encoding, Chars}} ->
            From ! {io_reply, ReplyAs, ok},
            capture(Owner, [bytes(Chars, Encoding) | Acc]);
        {io_request, From, ReplyAs, {put_chars, Encoding, Module, Function, Args}} ->
            From ! {io_reply, ReplyAs, ok},
            capture(Owner, [bytes(apply(Module, Function, Args), Encoding) | Acc]);
        {io_request, From, ReplyAs, _} ->
            From ! {io_reply, ReplyAs, {error, request}},
            capture(Owner, Acc);
        {done, Owner} ->
            Owner ! {captured, iolist_to_binary(lists:reverse(Acc))}
    end.

bytes(Chars, latin1) -> iolist_to_binary(Chars);
bytes(Chars, unicode) -> unicode:characters_to_binary(Chars).

%% Refusals as the job writes them, each after its name.
lines(Lines) ->
    iolist_to_binary([["ern unpack: ", Line, "\n"] || Line <- Lines]).

%% The names in Dir, sorted.
names(Dir) ->
    {ok, Names} = file:list_dir(Dir),
    lists:sort(Names).

%% Every name at and under Path, sorted, each with its kind, its permission
%% bits and a regular file's bytes, no link followed.
tree(Path) ->
    {ok, #file_info{type = Type, mode = Mode}} = file:read_link_info(Path),
    Below = case Type of
                directory -> lists:append([tree(filename:join(Path, Name)) || Name <- names(Path)]);
                _ -> []
            end,
    Bytes = case Type of
                regular -> {ok, Read} = file:read_file(Path), Read;
                _ -> none
            end,
    [{Path, Type, Mode band 8#7777, Bytes} | Below].

%% Every name at and under Path with its kind, its mode, its inode, and a
%% regular file's bytes or a link's target: what a run that writes nothing
%% leaves as it was.
held(Path) ->
    {ok, #file_info{type = Type, mode = Mode, inode = Inode}} = file:read_link_info(Path),
    Below = case Type of
                directory -> lists:append([held(filename:join(Path, Name)) || Name <- names(Path)]);
                _ -> []
            end,
    Contents = case Type of
                   regular -> file:read_file(Path);
                   symlink -> file:read_link(Path);
                   _ -> none
               end,
    [{Path, Type, Mode, Inode, Contents} | Below].
