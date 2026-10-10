%% Report §8.7, §11: the toolchain's version text, which `ern --version`
%% and the shell's start line print, and which marks a build of `ern` that
%% is no release: VERSION's text in a release, and VERSION's text and the
%% mark `-dev` in every other build. The repository's build compiles this
%% module with DEVELOPMENT defined (erl/app.mk), and the release archive's
%% compiles it again without (tools/install.sh). A node's floor reads the
%% mark (ern_carrier:cookie/0).
-module(ern_release).

-export([version_text/0]).

-ifdef(DEVELOPMENT).
-define(MARK, "-dev").
-else.
-define(MARK, "").
-endif.

-spec version_text() -> string().
version_text() ->
    ?VERSION ++ ?MARK.
