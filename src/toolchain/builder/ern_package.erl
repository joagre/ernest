%% Report §11.9: a job's root package read, the directory whose manifest,
%% `package.conf`, the job reads: the manifest held to its form, the
%% directory every user may write, each entry's namespace, each named
%% package under the root package's `lib`, a path given under `lib`, and, in
%% `ern build`, the named packages' manifests and `VERSION`s held to the
%% root package's by the build's rules, every fault said, a line each, in
%% the order §11.9 gives them, before the job does anything else. It gives
%% the job its named packages, as its load path holds them, and what
%% `--verbose` says of them.
%%
%% Whether a directory holds a manifest, the look, is the job's
%% (ern_cli:root_package/3), so that a job started where there is none
%% loads nothing of this module.
-module(ern_package).

-export([read/4, packages/1, entries/1, built_order/1, said/1, version_held/1, version_of/1]).

-include_lib("kernel/include/file.hrl").
-include_lib("builder/include/ern_build.hrl").

-define(FIELDS, [<<"ernest">>, <<"packages">>]).
-define(ENTRY_FIELDS, [<<"name">>, <<"version">>, <<"url">>, <<"sha256">>]).

%% Report §11.9: the root package as the job read it: its manifest and its
%% `lib`, as the job reached them, its named packages, each the name and
%% the version of an entry of its form, in the manifest's order, each as
%% the job's load path holds it, its entries with their `url` and their
%% `sha256`, and, in `ern build`, their names in the order it builds them.
-record(package, {manifest :: file:filename(),
                  lib :: file:filename(),
                  named :: [{string(), string()}],
                  packages :: [#named_package{}],
                  entries = [] :: [entry()],
                  order = [] :: [string()]}).

%% Report §11.9: an entry of its form (ern_build.hrl).
-type entry() :: #package_entry{}.

%% Report §11.9: a manifest as it was read: its faults of form, in the
%% order of where each stands; its `ernest` where that is of its form, and
%% none otherwise; its entries of their form, each a name and a version,
%% the first of each name, and the same entries with their `url` and their
%% `sha256`; and every name an entry gives that is of its form, the entry's
%% or not.
-record(form, {faults = [] :: [string()],
               ernest = none :: string() | none,
               named = [] :: [{string(), string()}],
               entries = [] :: [entry()],
               names = [] :: [string()]}).

%% Report §11.9: a named package placed under `lib`, as `ern build` reads
%% it: its entry's name and version, its directory under `lib`, and its
%% manifest as read, the lines of its faults of form, each naming its file,
%% and the #form{}.
-record(placed_package, {name :: string(),
                         version :: string(),
                         directory :: file:filename(),
                         form_lines :: [string()],
                         form :: #form{}}).

-opaque package() :: #package{}.
-export_type([package/0, entry/0]).

%% Report §11.9: the root package Dir, which holds a manifest, Place being
%% where it is, the `working_directory` the job was started in or the
%% `package_dir` its `--package-dir` names, read by the job Job, `"build"`,
%% `"doc"`, `"run"`, `"test"`, `"shell"` or `"unpack"`, given the paths
%% Given, as resolved (§11), each an `{argument, Path}`, the `{build_root,
%% Path}` its `--build-root` names or the `{doc_root, Path}` its
%% `--doc-root` names. The job's load path takes each named
%% package's build, and its `ebin` too where the job runs code.
%%
%% `ern unpack` refuses no named package that is not under `lib`, which it
%% puts there. `ern build` and `ern doc` refuse a path given under `lib`,
%% and `ern build` alone holds the build's rules. A job that cannot read the
%% manifest has one fault of its form, and the other groups are said all
%% the same. Every fault is thrown, a line each, as `{cli_errors, Lines}`,
%% which the job writes after its name, each holding no control character
%% (ern_build:control_free/1).
-spec read(file:filename(), working_directory | package_dir, string(),
           [{argument | build_root | doc_root, file:filename()}]) -> package().
read(Dir, Place, Job, Given) ->
    Manifest = filename:join(Dir, "package.conf"),
    Lib = filename:join(Dir, "lib"),
    #form{faults = Form, named = Named, entries = Entries} = RootForm = manifest(Manifest),
    Shown = ern_build:shown(Manifest),
    Packages = [{Name, Version, filename:join(Lib, Name)} || {Name, Version} <- Named],
    Open = [ern_build:shown(Dir) ++ ": may be written by every user"
            || Place =:= working_directory, is_sticky_open(Dir)],
    Taken = case Named of
                [] -> [];
                _ -> taken(Named, Shown)
            end,
    {Placed, Unplaced} = lists:partition(fun({_, _, Package}) -> filelib:is_dir(Package) end,
                                         Packages),
    Absent = [lists:flatten([Shown, ": ", Name, " ", Version, " is not under ",
                             ern_build:shown(Lib), "; ern unpack puts it there"])
              || Job =/= "unpack", {Name, Version, _} <- Unplaced],
    Under = [Line || Job =:= "build" orelse Job =:= "doc", GivenPath <- Given,
                     Line <- given_under_lib(Job, GivenPath, Lib, Named)],
    %% report §11.9: `ern build` alone reads the named packages' manifests,
    %% each under `lib`, which its rules hold and its builds follow
    Manifests = [#placed_package{name = Name, version = Version, directory = Package,
                                 form_lines = FormLines, form = PackageForm}
                 || Job =:= "build", {Name, Version, Package} <- Placed,
                    {FormLines, PackageForm} <- [named_manifest(Shown, Package)]],
    Rules = case Job of
                "build" -> rules(Shown, RootForm, Manifests);
                _ -> []
            end,
    case [Shown ++ ": " ++ Fault || Fault <- Form] ++ Open ++ Taken ++ Absent ++ Under ++ Rules of
        [] -> #package{manifest = Manifest, lib = Lib, named = Named,
                       packages = named_packages(Manifest, Packages, Job, Manifests),
                       entries = Entries, order = in_built_order(Manifests)};
        Lines -> throw({cli_errors, [ern_build:control_free(Line) || Line <- Lines]})
    end.

%% Report §11.9: a manifest's faults of form, read where it is a file the
%% job can read, its fault otherwise.
manifest(Manifest) ->
    case text(Manifest) of
        {ok, Text} -> form(Text);
        {fault, Fault} -> #form{faults = [Fault]}
    end.

%% Report §11.9, §11: the manifest's text, or the one fault of its form
%% that keeps it from being read: a link to nothing names nothing, and any
%% other file the job cannot read, a name that reaches no regular file
%% among them (ern_build:regular_bytes/1), is refused with its reason.
text(Manifest) ->
    case ern_build:regular_bytes(Manifest) of
        {ok, Text} -> {ok, Text};
        {error, enoent} -> {fault, file:format_error(enoent)};
        {error, Error} -> {fault, ern_build:reason(Error)}
    end.

%% Report §11.9: whether every user may write the working directory, Dir,
%% and it has the sticky bit: its mode lets those write it who are neither
%% its owner nor of its group, and its owner is not tested. One stat, made
%% only where the job has a root package there. A directory whose mode the
%% host will not give refuses the job with the host's reason, as one whose
%% manifest's name cannot be looked for does: only a directory changed
%% since that look gives it.
is_sticky_open(Dir) ->
    case file:read_file_info(Dir) of
        {ok, #file_info{mode = Mode}} -> Mode band 8#1002 =:= 8#1002;
        {error, Error} -> ern_build:refused(Dir, Error)
    end.

%% Report §11.9, §11.1, §11.2: each named package, in the manifest's
%% order, with its build and its `src`, absolute, and the directories it
%% puts on the job's load path: its build, and its `ebin` where the job runs
%% code, `ern run`, `ern test` and `ern shell`, each that is there; and
%% under `ern build`, which makes it, its build whether it is there or not,
%% and the named packages its own manifest names, as Manifests read it.
named_packages(Manifest, Packages, Job, Manifests) ->
    Directories = case Job of
                      "build" -> ["build"];
                      "doc" -> ["build"];
                      _ -> ["build", "ebin"]
                  end,
    [#named_package{name = Name,
                    build = ern_build:absolute(filename:join(Package, "build")),
                    src = ern_build:absolute(filename:join(Package, "src")),
                    roots = [Root || Directory <- Directories,
                                     Root <- [ern_build:absolute(filename:join(Package,
                                                                               Directory))],
                                     Job =:= "build" orelse filelib:is_dir(Root)],
                    manifest = ern_build:absolute(Manifest),
                    uses = [Used || #placed_package{form = #form{named = Uses}}
                                        <- [lists:keyfind(Name, #placed_package.name, Manifests)],
                                    {Used, _} <- Uses, lists:keymember(Used, 1, Packages)]}
     || {Name, _, Package} <- Packages].

%% The named packages, which the job's options carry as `{named_package,
%% Package}` to its load path, after the options' directories and before
%% the toolchain's libraries (ern_build:load_path/1).
-spec packages(package()) -> [#named_package{}].
packages(#package{packages = Packages}) ->
    Packages.

%% Report §11.9: the root package's entries of their form, in the
%% manifest's order, the first of each name, each with its `url` and its
%% `sha256` where it has them, which `ern unpack` reads.
-spec entries(package()) -> [entry()].
entries(#package{entries = Entries}) ->
    Entries.

%% Report §11.9: the names of the named packages in the order `ern build`
%% builds them, which its options carry as `{package_order, Names}`
%% (ern_build:compile/4); none for any other job.
-spec built_order(package()) -> [string()].
built_order(#package{order = Order}) ->
    Order.

%% Report §11.9: the named packages under `lib`, Manifests, each after the
%% packages its manifest names and otherwise in the root package's order,
%% as a directory's modules are ordered (§11.1); the rules have refused a
%% cycle among them.
in_built_order(Manifests) ->
    Order = [Name || #placed_package{name = Name} <- Manifests],
    Uses = maps:from_list([{Name, [Used || Used <- Order, lists:keymember(Used, 1, Named)]}
                           || #placed_package{name = Name, form = #form{named = Named}}
                                  <- Manifests]),
    {Built, _} = lists:foldl(fun(Name, Acc) -> ordered(Name, Uses, Acc) end, {[], #{}}, Order),
    lists:reverse(Built).

ordered(Name, _Uses, {_, Seen} = Acc) when is_map_key(Name, Seen) ->
    Acc;
ordered(Name, Uses, {Built, Seen}) ->
    {Built1, Seen1} = lists:foldl(fun(Used, Acc) -> ordered(Used, Uses, Acc) end,
                                  {Built, Seen#{Name => true}}, maps:get(Name, Uses)),
    {[Name | Built1], Seen1}.

%% Report §11.1, §11.2, §11.4: the lines `--verbose` says of the root
%% package: the manifest, and each named package with the version its
%% `VERSION` holds, read for this line, which `ern build` says once its
%% rules have held the `VERSION` to its entry, and, where its
%% directory under `lib` is a link, the link's target, taken from `lib` with
%% no further link followed. The job's options carry them as
%% `{package_said, Line}`.
-spec said(package()) -> [string()].
said(#package{manifest = Manifest, lib = Lib, named = Named}) ->
    ["manifest " ++ ern_build:shown(Manifest)
     | [lists:flatten(["package ", Name, " ", version_said(Package), linked_from(Lib, Package)])
        || {Name, _} <- Named, Package <- [filename:join(Lib, Name)]]].

version_said(Package) ->
    case version_held(Package) of
        {version, Version} -> Version;
        _ -> "no version"
    end.

%% Report §11.9: a package's version, its `VERSION`'s one line, which holds
%% a version and ends in a line feed; `absent` where the package holds no
%% name `VERSION`, and `not_of_form` for any other, which gives it no
%% version. A file the job cannot read, a name that reaches no regular file
%% among them (report §11), is one of no form. `ern unpack` asks it of what
%% stands under `lib` (ern_unpack:held_version/1).
-spec version_held(file:filename()) -> absent | not_of_form | {version, string()}.
version_held(Package) ->
    File = filename:join(Package, "VERSION"),
    case file:read_link_info(File, [raw]) of
        {error, enoent} ->
            absent;
        _ ->
            case ern_build:regular_bytes(File) of
                {ok, Text} -> version_of(Text);
                {error, _} -> not_of_form
            end
    end.

%% Report §11.9: the version a `VERSION`'s bytes, Text, hold, one line that
%% holds a version and ends in a line feed, and `not_of_form` for any
%% other; the one test, which `ern unpack` asks of an archive's `VERSION`
%% too (ern_unpack:version_of/1).
-spec version_of(binary()) -> not_of_form | {version, string()}.
version_of(Text) ->
    version_line(binary:split(Text, <<"\n">>)).

version_line([Version, <<>>]) ->
    case is_version(Version) of
        true -> {version, binary_to_list(Version)};
        false -> not_of_form
    end;
version_line(_) ->
    not_of_form.

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

%% Report §11.9: the manifest read from its text, a #form{}.
form(Text) ->
    case ern_conf:decoded(Text) of
        {ok, Decoded} ->
            case ern_conf:pairs("the file", Decoded, ?FIELDS) of
                not_object ->
                    #form{faults = ["the file is not a JSON object"]};
                Said ->
                    Judged = [field(Item) || Item <- Said],
                    Given = [Name || {field, Name, _} <- Said],
                    Absent = [Fault || {Field, Fault} <- [{<<"ernest">>, "names no ernest"},
                                                          {<<"packages">>, "names no packages"}],
                                       not lists:member(Field, Given)],
                    #form{faults = lists:append([Faults || #form{faults = Faults} <- Judged])
                              ++ Absent,
                          ernest = version_given(<<"ernest">>, Said),
                          named = lists:append([Named || #form{named = Named} <- Judged]),
                          entries = lists:append([Listed || #form{entries = Listed} <- Judged]),
                          names = lists:append([Names || #form{names = Names} <- Judged])}
            end;
        {fault, Fault} ->
            #form{faults = [Fault]}
    end.

field({fault, Fault}) -> #form{faults = [Fault]};
field({field, <<"ernest">>, Value}) -> #form{faults = version_faults("ernest", Value)};
field({field, <<"packages">>, Entries}) when is_list(Entries) -> entries_judged(Entries);
field({field, <<"packages">>, _}) -> #form{faults = ["packages is not a JSON array"]}.

%% Report §11.9: each entry's faults, the entries of their form, and the
%% names the entries give; an entry that names a package an earlier entry
%% names has that fault too, after its own.
entries_judged(Items) ->
    {Judged, Names} = lists:mapfoldl(fun entry/2, [], Items),
    #form{faults = lists:append([Faults || {Faults, _} <- Judged]),
          named = [{Name, Version} || {_, Entry} <- Judged,
                                      #package_entry{name = Name, version = Version} <- Entry],
          entries = lists:append([Entry || {_, Entry} <- Judged]),
          names = Names}.

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
            Version = version_given(<<"version">>, Said),
            Given = [Field || {field, Field, _} <- Said],
            Faults = lists:append([entry_faults(What, Name, Version, Pair) || Pair <- Said])
                ++ [What ++ " has no name" || not lists:member(<<"name">>, Given)]
                ++ [What ++ " has no version" || not lists:member(<<"version">>, Given)]
                ++ ["two entries name " ++ Name || Name =/= none, lists:member(Name, Earlier)],
            Entry = [#package_entry{name = Name, version = Version,
                                    url = string_given(<<"url">>, Said),
                                    sha256 = string_given(<<"sha256">>, Said)} || Faults =:= []],
            {{Faults, Entry}, [Name || Name =/= none] ++ Earlier}
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

%% The version the first Field of an object gives, an entry's `version` or
%% a manifest's `ernest`, where it is of its form.
version_given(Field, Said) ->
    case lists:keyfind(Field, 2, Said) of
        {field, _, Version} when is_binary(Version) ->
            case is_version(Version) of
                true -> binary_to_list(Version);
                false -> none
            end;
        _ ->
            none
    end.

%% The string the first Field of an entry gives, its `url` or its `sha256`,
%% or none where it gives none; called where the entry is of its form.
string_given(Field, Said) ->
    case lists:keyfind(Field, 2, Said) of
        {field, _, Value} -> Value;
        false -> none
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

%%
%% A path given under `lib`
%%

%% Report §11.9, §11: the refusal of Path, a path the job was given, an
%% argument, its `--build-root` or its `--doc-root`, as resolved, where it
%% is the root package's `lib`, a named package's directory or a path under
%% one, compared by its segments: `ern build` refuses every such path, and
%% `ern doc` every one but a compiled module given as its argument, which
%% it reads (§11.4). A path under `lib` and under no named package's
%% directory has the text of `lib`.
given_under_lib(Job, {How, Path}, Lib, Named) ->
    case ern_build:relative(Path, Lib) of
        outside ->
            [];
        Relative ->
            IsRead = Job =:= "doc" andalso How =:= argument
                andalso filename:extension(Path) =:= ".erc" andalso not filelib:is_dir(Path),
            [First | _] = filename:split(Relative),
            case {IsRead, lists:keymember(First, 1, Named)} of
                {true, _} ->
                    [];
                {false, true} ->
                    [lists:flatten([ern_build:shown(Path), " is the package ", First,
                                    "'s, which ern build builds"])];
                {false, false} ->
                    [ern_build:shown(Lib) ++ " holds the named packages, which ern build builds"]
            end
    end.

%%
%% The build's rules
%%

%% Report §11.9: the build's rules broken, a line each: the running `ern`'s
%% first, then the lines of each named package under `lib`, Manifests, each
%% with its manifest as read, in the order of the root package's entries,
%% and each cycle's last. Shown names the root package's manifest, read as
%% RootForm.
rules(Shown, #form{ernest = Ernest} = RootForm, Manifests) ->
    Running = running(),
    written_for(Shown ++ ": written for ern from ", Ernest, Running)
        ++ lists:append([package_rules(Shown, RootForm, PlacedPackage, Running)
                         || PlacedPackage <- Manifests])
        ++ cycles(Shown, Manifests).

%% Report §11.7: the running `ern`'s release, the three numbers of its
%% version text, and the text whole.
running() ->
    Text = ern_release:version_text(),
    {ern_release:release(lists:takewhile(fun(Char) -> Char =/= $- andalso Char =/= $+ end,
                                         Text)),
     Text}.

%% Report §11.9: the line of a manifest whose `ernest` names a later release
%% than the running `ern`'s, after Said; none where it names none of its form.
written_for(_Said, none, _Running) ->
    [];
written_for(Said, Ernest, {Release, Text}) ->
    [lists:flatten([Said, Ernest, ", and this is ern ", Text])
     || ern_release:release(Ernest) > Release].

%% Report §11.9: a named package's lines: its manifest's form first, then
%% the rules in the report's order, its `VERSION`, its `ernest`, its entries
%% in its manifest's order, and its modules, each by its path.
package_rules(Shown, RootForm, #placed_package{name = Name, version = Version, directory = Package,
                                               form_lines = FormLines, form = Form},
              Running) ->
    Said = lists:flatten([Shown, ": ", Name, " ", Version]),
    FormLines
        ++ version_rule(Shown, Name, Version, Package)
        ++ written_for(Said ++ " is written for ern from ", Form#form.ernest, Running)
        ++ [lists:flatten([Said, " needs ", Needed, " from ", Least, ", and ", Unmet])
            || {Needed, Least} <- Form#form.named, Unmet <- unmet(Needed, Least, RootForm)]
        ++ modules_outside(Name, Package).

%% Report §11.9: a named package's manifest read as the root package's is,
%% each fault of its form naming its file, and the manifest as read; a
%% package that holds no name `package.conf` holds no manifest.
named_manifest(Shown, Package) ->
    Manifest = filename:join(Package, "package.conf"),
    case file:read_link_info(Manifest, [raw]) of
        {error, enoent} ->
            {[Shown ++ ": " ++ ern_build:shown(Package) ++ " holds no package.conf"], #form{}};
        _ ->
            #form{faults = Faults} = Form = manifest(Manifest),
            {[ern_build:shown(Manifest) ++ ": " ++ Fault || Fault <- Faults], Form}
    end.

%% Report §11.9: a named package's `VERSION` of its form, which says its
%% entry's version; where the package's directory under `lib` is a link,
%% the version line does not ask for it to be removed.
version_rule(Shown, Name, Version, Package) ->
    case version_held(Package) of
        absent ->
            [Shown ++ ": " ++ ern_build:shown(Package) ++ " holds no VERSION"];
        not_of_form ->
            [Shown ++ ": " ++ ern_build:shown(filename:join(Package, "VERSION"))
             ++ " is not one line that holds a version"];
        {version, Version} ->
            [];
        {version, Held} ->
            Removed = case file:read_link_info(Package, [raw]) of
                          {ok, #file_info{type = symlink}} -> "";
                          _ -> "remove it, and "
                      end,
            [lists:flatten([Shown, ": the entry for ", Name, " says ", Version, ", and ",
                            ern_build:shown(Package), " holds ", Held, "; ", Removed,
                            "ern unpack puts ", Version, " there"])]
    end.

%% Report §11.9: what the root package's manifest, RootForm, lacks of an
%% entry of a named package's that names Needed from the version Least: an
%% entry of that name whose version is Least or a later one. An entry of
%% the name whose version is not of its form lacks nothing here, since its
%% own fault is said.
unmet(Needed, Least, #form{named = Named, names = Names}) ->
    case lists:keyfind(Needed, 1, Named) of
        {_, Given} ->
            ["the entry for " ++ Needed ++ " says " ++ Given
             || ern_release:release(Given) < ern_release:release(Least)];
        false ->
            ["no entry names " ++ Needed || not lists:member(Needed, Names)]
    end.

%% Report §11.9, §11.1: each module under a named package's `src` that does
%% not stand at the namespace of the package's name or under it, by its
%% path, found as directory mode finds the modules under a directory; its
%% namespace is its path's, and no source is parsed: a `.ern` the job
%% cannot read, one whose name reaches no regular file among them (§11), is
%% held to the rule as any other. A file whose path is not of a module's
%% shape stands at no namespace, and the package's build refuses it
%% (§11.1). A walk that cannot be made is said as its refusal, which names
%% its path as §11.5 writes one. A package that holds no name `src` has no
%% module, and a `src` that reaches no directory is refused in their place.
modules_outside(Name, Package) ->
    Src = ern_build:shown(filename:join(Package, "src")),
    {ok, Provided} = ern_namespace:segment(Name),
    case {file:read_link_info(Src, [raw]), file:read_file_info(Src)} of
        {{error, enoent}, _} ->
            [];
        {_, {ok, #file_info{type = directory}}} ->
            try ern_build:sources(Src) of
                Sources ->
                    [lists:flatten([ern_build:shown(Source), ": the package ", Name, " provides ",
                                    Provided, " and what stands under it"])
                     || Found <- Sources, Source <- [ern_build:found_path(Found)],
                        not is_provided(Source, Src, Name)]
            catch
                throw:{cli_error, Refusal} -> [Refusal]
            end;
        {{ok, _}, _} ->
            [Src ++ ": not a directory"];
        {{error, Error}, _} ->
            [Src ++ ": " ++ file:format_error(Error)]
    end.

is_provided(Source, Src, Name) ->
    [First | _] = Components = filename:split(filename:rootname(ern_build:relative(Source, Src))),
    First =:= Name orelse not lists:all(fun ern_namespace:is_component/1, Components).

%% Report §11.9: a line for each cycle among the named packages Manifests,
%% each with the packages its manifest names among them, a package that
%% names itself among the cycles, its packages in the order of the root
%% package's entries, the lines in the order of their first packages.
cycles(Shown, Manifests) ->
    Order = [Name || #placed_package{name = Name} <- Manifests],
    Graph = digraph:new(),
    try
        [digraph:add_vertex(Graph, Name) || Name <- Order],
        [digraph:add_edge(Graph, Name, Needed)
         || #placed_package{name = Name, form = #form{named = Named}} <- Manifests,
            {Needed, _} <- Named, lists:member(Needed, Order)],
        Cycles = [[Name || Name <- Order, lists:member(Name, Component)]
                  || Component <- digraph_utils:cyclic_strong_components(Graph)],
        [lists:flatten([Shown, ": a cycle among the packages: ", lists:join(", ", Cycle)])
         || Name <- Order, [First | _] = Cycle <- Cycles, First =:= Name]
    after
        digraph:delete(Graph)
    end.
