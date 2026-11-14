%% Report §11.9: a job's root package read, the directory whose manifest,
%% `package.conf`, the job reads: the manifest held to its form, the paths
%% every user may write, each entry's namespace, and each named package
%% under the root package's `lib`, every fault said, a line each, in the
%% order §11.9 gives them, before the job does anything else. It gives the
%% job its named packages, as its load path holds them, and what
%% `--verbose` says of them.
%%
%% Whether a directory holds a manifest, the look, is the job's
%% (ern_cli:root_package/3), so that a job started where there is none
%% loads nothing of this module.
-module(ern_package).

-export([read/2, packages/1, said/1]).

-include_lib("kernel/include/file.hrl").
-include_lib("cli/include/ern_build.hrl").

-define(FIELDS, [<<"ernest">>, <<"packages">>]).
-define(ENTRY_FIELDS, [<<"name">>, <<"version">>, <<"url">>, <<"sha256">>]).

%% Report §11.9: the root package as the job read it: its manifest and its
%% `lib`, as the job reached them, its named packages, each the name and
%% the version of an entry of its form, in the manifest's order, and each
%% as the job's load path holds it.
-record(package, {manifest :: file:filename(),
                  lib :: file:filename(),
                  named :: [{string(), string()}],
                  packages :: [#named_package{}]}).

-opaque package() :: #package{}.
-type use() :: builds | builds_and_ebins.
-export_type([package/0, use/0]).

%% Report §11.9: the root package Dir, which holds a manifest, read by a
%% job whose load path takes each named package's build, and its `ebin`
%% too where Use is `builds_and_ebins`. A job that cannot read the manifest
%% has one fault of its form, and the other groups are said all the same.
%% Every fault is thrown, a line each, as `{cli_errors, Lines}`, which the
%% job writes after its name.
-spec read(file:filename(), use()) -> package().
read(Dir, Use) ->
    Manifest = filename:join(Dir, "package.conf"),
    Lib = filename:join(Dir, "lib"),
    {Form, Named} = case text(Manifest) of
                        {ok, Text} -> form(Text);
                        {fault, Fault} -> {[Fault], []}
                    end,
    Shown = ern_build:shown(Manifest),
    Packages = [{Name, Version, filename:join(Lib, Name)} || {Name, Version} <- Named],
    %% report §11.9: the paths at fault, the root package's first and then
    %% each named package's, in the manifest's order
    Open = [ern_build:shown(Path) ++ ": may be written by every user"
            || Path <- [Manifest, Dir, Lib | lists:append([package_paths(Package)
                                                           || {_, _, Package} <- Packages])],
               is_open(Path)],
    Taken = case Named of
                [] -> [];
                _ -> taken(Named, Shown)
            end,
    Absent = [lists:flatten([Shown, ": ", Name, " ", Version, " is not under ",
                             ern_build:shown(Lib), "; ern unpack puts it there"])
              || {Name, Version, Package} <- Packages, not filelib:is_dir(Package)],
    case [Shown ++ ": " ++ Fault || Fault <- Form] ++ Open ++ Taken ++ Absent of
        [] -> #package{manifest = Manifest, lib = Lib, named = Named,
                       packages = named_packages(Manifest, Packages, Use)};
        Lines -> throw({cli_errors, Lines})
    end.

%% Report §11.9: the manifest's text, or the one fault of its form that
%% keeps it from being read: a link to nothing names nothing, a name that
%% reaches no regular file, a directory or a FIFO among them, is refused
%% before it is read, so that no read waits on it, and a file that cannot
%% be read is refused with the host's reason.
text(Manifest) ->
    case file:read_file_info(Manifest) of
        {ok, #file_info{type = regular}} ->
            case file:read_file(Manifest) of
                {ok, Text} -> {ok, Text};
                {error, Error} -> {fault, file:format_error(Error)}
            end;
        {ok, _} ->
            {fault, "is no regular file"};
        {error, enoent} ->
            {fault, "no such file"};
        {error, Error} ->
            {fault, file:format_error(Error)}
    end.

%% Report §11.9: the paths of a named package that are tested, in the
%% order they are said.
package_paths(Package) ->
    [Package | [filename:join(Package, Directory) || Directory <- ["src", "build", "ebin"]]].

%% Report §11.9: a path every user may write, by its mode or by the mode of
%% the directory that holds what a link reaches, the ownership test's with
%% no owner tested (§11.2); a path that is not there is not tested.
is_open(Path) ->
    case file:read_file_info(Path) of
        {ok, Info} -> ern_ownership:failure(Path, Info, any) =:= every_user_may_write;
        {error, _} -> false
    end.

%% Report §11.9, §11.1, §11.2: each named package, in the manifest's
%% order, with its build and its `src`, absolute, and the directories it
%% puts on the job's load path: its build, and its `ebin` where the job runs
%% code, each that is there.
named_packages(Manifest, Packages, Use) ->
    Directories = case Use of
                      builds -> ["build"];
                      builds_and_ebins -> ["build", "ebin"]
                  end,
    [#named_package{name = Name,
                    build = ern_build:absolute(filename:join(Package, "build")),
                    src = ern_build:absolute(filename:join(Package, "src")),
                    roots = [Root || Directory <- Directories,
                                     Root <- [ern_build:absolute(filename:join(Package,
                                                                               Directory))],
                                     filelib:is_dir(Root)],
                    manifest = ern_build:absolute(Manifest)}
     || {Name, _, Package} <- Packages].

%% The named packages, which the job's options carry as `{named_package,
%% Package}` to its load path, after the options' directories and before
%% the toolchain's libraries (ern_build:load_path/1).
-spec packages(package()) -> [#named_package{}].
packages(#package{packages = Packages}) ->
    Packages.

%% Report §11.1, §11.2, §11.4: the lines `--verbose` says of the root
%% package: the manifest, and each named package with the version its
%% `VERSION` holds, which is read for this line alone, and, where its
%% directory under `lib` is a link, the link's target, taken from `lib` with
%% no further link followed. The job's options carry them as
%% `{package_said, Line}`.
-spec said(package()) -> [string()].
said(#package{manifest = Manifest, lib = Lib, named = Named}) ->
    ["manifest " ++ ern_build:shown(Manifest)
     | [lists:flatten(["package ", Name, " ", version_of(Package), linked_from(Lib, Package)])
        || {Name, _} <- Named, Package <- [filename:join(Lib, Name)]]].

%% Report §11.9: a package's version, its `VERSION`'s one line, which ends
%% in a line feed; any other gives it no version.
version_of(Package) ->
    case file:read_file(filename:join(Package, "VERSION")) of
        {ok, Text} ->
            case binary:split(Text, <<"\n">>) of
                [Version, <<>>] ->
                    case is_version(Version) of
                        true -> binary_to_list(Version);
                        false -> "no version"
                    end;
                _ ->
                    "no version"
            end;
        {error, _} ->
            "no version"
    end.

%% Report §11.1, §11.5: where a named package's directory is a link, its
%% target taken from `lib`, written as a path is; a target that is not
%% UTF-8 has each byte past ASCII written `\xHH`, segment by segment, and is
%% then written as a path is, its `.` and `..` resolved.
linked_from(Lib, Package) ->
    case file:read_link_all(Package) of
        {ok, Target} when is_list(Target) ->
            [" at ", ern_build:shown(filename:join(Lib, Target))];
        {ok, Target} ->
            Segments = [ern_build:bytes_text(Segment) || Segment <- filename:split(Target)],
            [" at ", ern_build:shown(filename:join([Lib | Segments]))];
        {error, _} ->
            []
    end.

%%
%% The manifest's form
%%

%% Report §11.9: the manifest's faults of form, in the order of where each
%% stands, and its entries of their form, each a name and a version, the
%% first of each name.
form(Text) ->
    case ern_conf:decoded(Text) of
        {ok, Decoded} ->
            case ern_conf:pairs("the file", Decoded, ?FIELDS) of
                not_object ->
                    {["the file is not a JSON object"], []};
                Said ->
                    Judged = [field(Item) || Item <- Said],
                    Given = [Name || {field, Name, _} <- Said],
                    Absent = [Fault || {Field, Fault} <- [{<<"ernest">>, "names no ernest"},
                                                          {<<"packages">>, "names no packages"}],
                                       not lists:member(Field, Given)],
                    {lists:append([Faults || {Faults, _} <- Judged]) ++ Absent,
                     lists:append([Named || {_, Named} <- Judged])}
            end;
        {fault, Fault} ->
            {[Fault], []}
    end.

field({fault, Fault}) -> {[Fault], []};
field({field, <<"ernest">>, Value}) -> {version_faults("ernest", Value), []};
field({field, <<"packages">>, Entries}) when is_list(Entries) -> entries(Entries);
field({field, <<"packages">>, _}) -> {["packages is not a JSON array"], []}.

%% Report §11.9: each entry's faults, and the entries of their form; an
%% entry that names a package an earlier entry names has that fault too,
%% after its own.
entries(Items) ->
    {Judged, _} = lists:mapfoldl(fun entry/2, [], Items),
    {lists:append([Faults || {Faults, _} <- Judged]),
     lists:append([Named || {_, Named} <- Judged])}.

%% One entry judged, Earlier holding the names the entries before it give;
%% an entry is named by its name where that is of its form, and is `an
%% entry` otherwise.
entry(Item, Earlier) ->
    Name = name_of(Item),
    What = case Name of
               none -> "an entry";
               _ -> "the entry for " ++ Name
           end,
    case ern_conf:pairs(What, Item, ?ENTRY_FIELDS) of
        not_object ->
            {{["an entry is not a JSON object"], []}, Earlier};
        Said ->
            Version = version_given(Said),
            Given = [Field || {field, Field, _} <- Said],
            Faults = lists:append([entry_faults(What, Name, Version, Pair) || Pair <- Said])
                ++ [What ++ " has no name" || not lists:member(<<"name">>, Given)]
                ++ [What ++ " has no version" || not lists:member(<<"version">>, Given)]
                ++ ["two entries name " ++ Name || Name =/= none, lists:member(Name, Earlier)],
            {{Faults, [{Name, Version} || Faults =:= []]}, [Name || Name =/= none] ++ Earlier}
    end.

%% The name an entry's first `name` gives, where it is of its form.
name_of({object, Pairs}) ->
    case lists:keyfind(<<"name">>, 1, Pairs) of
        {_, Name} when is_binary(Name) ->
            case is_name(Name) of
                true -> binary_to_list(Name);
                false -> none
            end;
        _ ->
            none
    end;
name_of(_) ->
    none.

%% The version an entry's first `version` gives, where it is of its form.
version_given(Said) ->
    case lists:keyfind(<<"version">>, 2, Said) of
        {field, _, Version} when is_binary(Version) ->
            case is_version(Version) of
                true -> binary_to_list(Version);
                false -> none
            end;
        _ ->
            none
    end.

%% Report §11.9: a field of an entry held to its form. A `url` is held to
%% the entry's name and version where both are of their form.
entry_faults(_What, _Name, _Version, {fault, Fault}) ->
    [Fault];
entry_faults(What, _Name, _Version, {field, <<"name">>, Value}) ->
    case is_binary(Value) of
        false -> [What ++ "'s name is not a string"];
        true ->
            [What ++ "'s name is not words joined by `_`, each a lowercase letter, then"
             " lowercase letters and digits: " ++ ern_conf:quoted(Value) || not is_name(Value)]
    end;
entry_faults(What, _Name, _Version, {field, <<"version">>, Value}) ->
    version_faults(What ++ "'s version", Value);
entry_faults(What, Name, Version, {field, <<"url">>, Value}) ->
    case is_binary(Value) of
        false -> [What ++ "'s url is not a string"];
        true when Name =:= none; Version =:= none -> [];
        true ->
            Archive = Name ++ "-" ++ Version ++ ".tar.gz",
            [What ++ "'s url is not an https URL whose path's last segment is " ++ Archive ++ ": "
             ++ ern_conf:quoted(Value) || not is_url(Value, Archive)]
    end;
entry_faults(What, _Name, _Version, {field, <<"sha256">>, Value}) ->
    case is_binary(Value) of
        false -> [What ++ "'s sha256 is not a string"];
        true ->
            [What ++ "'s sha256 is not 64 hexadecimal digits, their letters lowercase: "
             ++ ern_conf:quoted(Value) || not is_digest(Value)]
    end.

version_faults(What, Value) when is_binary(Value) ->
    [What ++ " is not three numbers joined by `.`, none written with a leading zero: "
     ++ ern_conf:quoted(Value) || not is_version(Value)];
version_faults(What, _Value) ->
    [What ++ " is not a string"].

%% Report §11.9, §11.1: a name is written as a file's name is.
is_name(Name) ->
    ern_namespace:is_component(unicode:characters_to_list(Name)).

%% Report §11.9: three numbers joined by `.`, none written with a leading
%% zero.
is_version(Text) ->
    case binary:split(Text, <<".">>, [global]) of
        [_, _, _] = Numbers -> lists:all(fun is_numeral/1, Numbers);
        _ -> false
    end.

is_numeral(<<"0">>) -> true;
is_numeral(<<First, Rest/binary>>) when First >= $1, First =< $9 ->
    lists:all(fun(Digit) -> Digit >= $0 andalso Digit =< $9 end, binary_to_list(Rest));
is_numeral(_) -> false.

%% Report §11.9: an https URL, its scheme read as RFC 3986 reads one, with
%% no regard to case, whose path's last segment is Archive.
is_url(Text, Archive) ->
    case uri_string:parse(Text) of
        #{scheme := Scheme, host := Host, path := Path} when Host =/= <<>> ->
            string:lowercase(Scheme) =:= <<"https">>
                andalso lists:last(binary:split(Path, <<"/">>, [global]))
                        =:= list_to_binary(Archive);
        _ ->
            false
    end.

%% Report §11.9: 64 hexadecimal digits, their letters lowercase.
is_digest(Text) ->
    byte_size(Text) =:= 64
        andalso lists:all(fun(Digit) -> (Digit >= $0 andalso Digit =< $9)
                                            orelse (Digit >= $a andalso Digit =< $f)
                          end, binary_to_list(Text)).

%%
%% The namespaces
%%

%% Report §11.9, §4.2: each entry whose namespace §4.2 takes, or a library
%% of the toolchain's own provides, refused in the manifest's order.
taken(Named, Shown) ->
    Taken = [atom_to_list(Namespace) || Namespace <- ern_build:taken_namespaces()],
    Libraries = [ern_build:library_name(Library) || Library <- ern_tree:libraries()],
    [lists:flatten([Shown, ": the entry for ", Name, " names ", Segment, Whose])
     || {Name, _} <- Named, {ok, Segment} <- [ern_namespace:segment(Name)],
        Whose <- case {lists:member(Segment, Taken), lists:member(Segment, Libraries)} of
                     {true, _} -> [", which no package may take"];
                     {false, true} -> [", which a library of the toolchain's own provides"];
                     {false, false} -> []
                 end].
