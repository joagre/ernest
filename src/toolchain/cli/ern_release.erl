%% Report §11.7, §12.5: the toolchain's version text, which `ern --version`
%% and the shell's start line print, and which marks a build of `ern` that
%% is no release: VERSION's text in a release; VERSION's text and the mark
%% `-dev` in the repository's own build; and VERSION's text, `+` and the
%% commit in an archive made from a checkout that does not stand at the
%% release's tag, `.dirty` after the commit where the tree had uncommitted
%% changes. The repository's build compiles this module with DEVELOPMENT
%% defined (the Makefile's ERLC_FLAGS), and an archive's compiles it again
%% with MARK given, empty for a release (tools/install.sh). A node's floor reads
%% which it is, and a release's numbers (release/0, ern_carrier:cookie/0).
-module(ern_release).

-export([version_text/0, release/0, release/1]).

-ifdef(DEVELOPMENT).
-define(MARK, "-dev").
-endif.

-spec version_text() -> string().
version_text() ->
    ?VERSION ++ ?MARK.

%% Report §12.5: what the build stands on, which the floor names:
%% development for a build that is no release, whose version text is
%% VERSION's marked, and for a release the three whole numbers of VERSION.
-spec release() -> development | {non_neg_integer(), non_neg_integer(), non_neg_integer()}.
release() ->
    case version_text() =:= ?VERSION of
        true -> release(?VERSION);
        false -> development
    end.

%% A release's major, minor and patch, of the three whole numbers its
%% version writes, `0.4.0`, each part its digits alone; a version of
%% another shape, which no release of `ern` has, is refused, naming it.
-spec release(string()) -> {non_neg_integer(), non_neg_integer(), non_neg_integer()}.
release(Version) ->
    Parts = string:split(Version, ".", all),
    case length(Parts) =:= 3 andalso lists:all(fun is_digits/1, Parts) of
        true -> list_to_tuple([list_to_integer(Part) || Part <- Parts]);
        false -> ern_build:fail("the version " ++ Version ++ " is not a release's, three whole"
                                " numbers")
    end.

is_digits(Part) ->
    Part =/= [] andalso lists:all(fun(Char) -> Char >= $0 andalso Char =< $9 end, Part).
