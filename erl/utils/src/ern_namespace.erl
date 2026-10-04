%% Report §4.2, §11.1: the one mapping between a path's components and a
%% namespace's segments, both ways, which the build, the emitter and the
%% shell share. A component is words joined by single `_`, a word a
%% lowercase letter then lowercase letters and digits; its segment is each
%% word with its first letter uppercased and the `_` dropped. A word begins
%% with a letter, so a segment's words begin at its uppercase letters and
%% the mapping is one-to-one: `ordered_set` is `OrderedSet` and nothing else.
%% Also a qualified name as the source writes it, which every stage prints.
-module(ern_namespace).

-export([is_component/1, segment/1, component/1, namespace/1, module_path/1, path/1,
         erlang_module/1, text/1]).

%% Whether a path component has the shape §11.1 asks of a module's file.
-spec is_component(string()) -> boolean().
is_component(Component) ->
    lists:all(fun is_word/1, string:split(Component, "_", all)).

is_word([First | Rest]) when First >= $a, First =< $z ->
    lists:all(fun is_lower_or_digit/1, Rest);
is_word(_) ->
    false.

is_lower_or_digit(Char) ->
    (Char >= $a andalso Char =< $z) orelse (Char >= $0 andalso Char =< $9).

%% The namespace segment a component names, or error where it is no
%% component.
-spec segment(string()) -> {ok, string()} | error.
segment(Component) ->
    case is_component(Component) of
        true -> {ok, lists:append([string:titlecase(Word)
                                   || Word <- string:split(Component, "_", all)])};
        false -> error
    end.

%% The component a namespace segment names, or error where the segment is
%% not words each beginning with an uppercase letter, the image of a
%% component.
-spec component(string()) -> {ok, string()} | error.
component(Segment) ->
    case words(Segment) of
        error -> error;
        Words -> {ok, lists:flatten(lists:join("_", [string:lowercase(Word) || Word <- Words]))}
    end.

%% A segment's words, each begun by an uppercase letter and continued by
%% lowercase letters and digits; error where a character is anything else
%% or the segment does not begin with an uppercase letter.
words([First | Rest]) when First >= $A, First =< $Z ->
    words(Rest, [First], []);
words(_) ->
    error.

words([], Word, Acc) ->
    lists:reverse([lists:reverse(Word) | Acc]);
words([Char | Rest], Word, Acc) when Char >= $A, Char =< $Z ->
    words(Rest, [Char], [lists:reverse(Word) | Acc]);
words([Char | Rest], Word, Acc) when Char >= $a, Char =< $z; Char >= $0, Char =< $9 ->
    words(Rest, [Char | Word], Acc);
words(_, _, _) ->
    error.

%% Report §4.2: the namespace a path's components name. A component that is
%% no module's, as the shell's own `$input` is, keeps its spelling but for
%% its first letter.
-spec namespace([string()]) -> [atom()].
namespace(Components) ->
    [list_to_atom(segment_or_titled(Component)) || Component <- Components].

segment_or_titled(Component) ->
    case segment(Component) of
        {ok, Segment} -> Segment;
        error -> string:titlecase(Component)
    end.

%% Report §11.2: a namespace as its module's relative path, without
%% extension, each segment written as its file's name is.
-spec module_path([atom()]) -> string().
module_path(Namespace) ->
    path([atom_to_list(Segment) || Segment <- Namespace]).

%% The same from segments as text, for a name read from a page's title,
%% which may be no module's and is never made an atom.
-spec path([string()]) -> string().
path(Segments) ->
    filename:join([component_or_lowered(Segment) || Segment <- Segments]).

%% The Erlang module a namespace compiles to, `ern@` and the path with `@`
%% for `/`, `ern@ordered_set` and `ern@net@http_client`, as docs/style.md
%% names it (the log's *One Token for the Project*).
-spec erlang_module([atom()]) -> atom().
erlang_module(Namespace) ->
    list_to_atom(lists:flatten(["ern" | ["@" ++ component_or_lowered(atom_to_list(Segment))
                                         || Segment <- Namespace]])).

component_or_lowered(Segment) ->
    case component(Segment) of
        {ok, Component} -> Component;
        error -> string:lowercase(Segment)
    end.

%% Report §4.2: a namespace or a qualified name as the source writes it,
%% its segments joined by `.`, `Net.Http.get`.
-spec text([atom()]) -> string().
text(QualifiedName) ->
    lists:flatten(lists:join(".", [atom_to_list(Part) || Part <- QualifiedName])).
