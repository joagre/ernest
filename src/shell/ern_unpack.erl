%% Report §11.9: the host half of `ern unpack`, the foreign functions of
%% `Ernest.Unpack` (src/shell/ernest/unpack.ern), the job's Ernest, which
%% does the rest over `Fs` and `Crypto`: the root package's entries, which
%% the command read (ern_cli:unpack/3); an archive's members and its regular
%% files' bytes, as the host's `erl_tar` reads them; the job's lock on
%% `lib/.unpack`, held by the helper (ern_os:job_locked/1); whether a `.beam`
%% is named as a module §11.2 finds first; and a `VERSION`'s form, by the
%% one test `ern build` holds a named package to (ern_package).
-module(ern_unpack).

-export([given/1, entries/0, members/1, files/1, hold/1, is_found_first/1, held_version/1,
         version_of/1]).

%% Report §11.9: the root package's entries, each of its form and the first
%% of its name, in the manifest's order, which the job reads once its run
%% has begun. Set once a job, as every persistent term is set at a launch
%% (docs/design/runtime.md).
-spec given([ern_package:entry()]) -> ok.
given(Entries) ->
    persistent_term:put({?MODULE, entries}, Entries).

%% Report §11.9: the entries as `Ernest.Unpack.Entry` values, each its name,
%% its version, and its `url` and its `sha256` where it has them.
-spec entries() -> [{'Entry', binary(), binary(), optional(binary()), optional(binary())}].
entries() ->
    [{'Entry', list_to_binary(Name), list_to_binary(Version), optional(Url), optional(Sha256)}
     || {Name, Version, Url, Sha256} <- persistent_term:get({?MODULE, entries}, [])].

-type optional(Value) :: {'Some', Value} | 'None'.

optional(none) -> 'None';
optional(Value) -> {'Some', Value}.

%% Report §11.9: the members of the archive Bytes, a tar archive compressed
%% by gzip, as `erl_tar` lists them, in the archive's order, each its name,
%% its kind and its mode: a directory, a regular file, tar's contiguous file
%% among them, one of a kind the host does not know, a pax global header
%% among them, and any other. An archive the host cannot read is answered
%% with the host's reason, and so is one that holds a name the host could
%% not decode, a pax record's that is not UTF-8, in the words of the
%% header's that the host refuses (erl_tar:format_error/1).
-spec members(binary()) ->
          {'Right', [{'Member', binary(), atom(), integer()}]} | {'Left', binary()}.
members(Bytes) ->
    case erl_tar:table({binary, Bytes}, [verbose, compressed]) of
        {ok, Listed} ->
            named(2, [{'Member', Name, kind(Kind), Mode}
                      || {Name, Kind, _Size, _MTime, Mode, _Uid, _Gid} <- Listed]);
        {error, Reason} ->
            {'Left', reason(Reason)}
    end.

kind(directory) -> 'Directory';
kind(regular) -> 'Regular';
kind(unknown) -> 'Unknown';
kind(_) -> 'Other'.

%% Report §11.9: the names and the bytes of the archive's regular files, as
%% `erl_tar` extracts them into memory, in the archive's order, a name given
%% twice given twice; a reason as members/1 answers one.
-spec files(binary()) -> {'Right', [{binary(), binary()}]} | {'Left', binary()}.
files(Bytes) ->
    case erl_tar:extract({binary, Bytes}, [memory, compressed]) of
        {ok, Files} -> named(1, Files);
        {error, Reason} -> {'Left', reason(Reason)}
    end.

%% Items, each a tuple whose element at Position is a name as `erl_tar`
%% gives one, with each name as UTF-8; where the host could not decode a
%% name it gives what it decoded and the rest, and the answer is the reason
%% a header's name gives.
named(Position, Items) ->
    case lists:any(fun(Item) -> is_tuple(element(Position, Item)) end, Items) of
        true ->
            {'Left', reason({bad_header, invalid_string})};
        false ->
            {'Right', [setelement(Position, Item,
                                  unicode:characters_to_binary(element(Position, Item)))
                       || Item <- Items]}
    end.

reason(Reason) ->
    unicode:characters_to_binary(erl_tar:format_error(Reason)).

%% Report §11.9, §11: the job's lock on the file at Path, held by the
%% calling process, which the job's own is, until it ends
%% (ern_os:job_locked/1); a name that reaches no regular file, which is not
%% opened, in §11's words, and any other failure in the host's.
-spec hold(binary()) -> {'Right', 'Unit'} | {'Left', binary()}.
hold(Path) ->
    case ern_os:job_locked(Path) of
        locked -> {'Right', 'Unit'};
        unopened -> {'Left', <<"is no regular file">>};
        {failed, Text} -> {'Left', unicode:characters_to_binary(Text)}
    end.

%% Report §11.9, §11.2: whether the `.beam` File names a module the host
%% finds before a package's: one of the host's own, preloaded or of an
%% application its installation holds, or of the toolchain's own Erlang or
%% a library's shim, each a module on the host's code path, which the run
%% has given the libraries' directories (ern_code:load_runtime/0). No atom
%% is made of the name.
-spec is_found_first(binary()) -> boolean().
is_found_first(File) ->
    Name = unicode:characters_to_list(File),
    lists:member(filename:rootname(Name), [atom_to_list(Module) || Module <- erlang:pre_loaded()])
        orelse code:where_is_file(Name) =/= non_existing.

%% Report §11.9: what the package's directory Package under `lib` holds of
%% its `VERSION` (ern_package:version_held/1), as `Ernest.Unpack.Held`.
-spec held_version(binary()) -> 'NoVersion' | 'NotOfForm' | {'Version', binary()}.
held_version(Package) ->
    case ern_package:version_held(unicode:characters_to_list(Package)) of
        absent -> 'NoVersion';
        not_of_form -> 'NotOfForm';
        {version, Version} -> {'Version', list_to_binary(Version)}
    end.

%% Report §11.9: the version an archive's `VERSION`, Bytes, holds, where it
%% is of its form (ern_package:version_of/1).
-spec version_of(binary()) -> optional(binary()).
version_of(Bytes) ->
    case ern_package:version_of(Bytes) of
        {version, Version} -> {'Some', list_to_binary(Version)};
        not_of_form -> 'None'
    end.
